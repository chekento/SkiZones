#!/usr/bin/env python3
"""Offline routing and provenance checks for the town transport graph."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from build_town_network import build_network, route, choose_game_shuttle


def street(osm_id, highway, nodes, points, oneway=None):
    tags = {"highway": highway}
    if oneway:
        tags["oneway"] = oneway
    return {"osm_type": "way", "osm_id": osm_id, "kind": "road",
            "nodes": nodes, "tags": tags, "points": points}


def stop(osm_id, point, name="Talstation"):
    return {"osm_type": "node", "osm_id": osm_id, "kind": "bus_stop",
            "tags": {"highway": "bus_stop", "name": name},
            "points": [point]}


class RoadGraphTests(unittest.TestCase):
    def setUp(self):
        self.data = {
            "schema": 1, "region": "example", "origin": [47.4, 12.3],
            "source_sha256": "fixture-not-an-osm-extract",
            "features": [
                street(1, "residential", [10, 20, 30],
                       [[0, 0], [100, 0], [200, 0]]),
                street(2, "service", [20, 40], [[100, 0], [100, 80]], "yes"),
                street(3, "footway", [30, 50], [[200, 0], [250, 0]]),
                street(4, "residential", [80, 90], [[900, 0], [1000, 0]]),
                stop(101, [4, 5]),
                stop(102, [98, 75], "Bergstation"),
                stop(103, [5000, 5000], "Not connected"),
                {"osm_type": "node", "osm_id": 200, "kind": "food",
                 "points": [[100, 10]], "tags": {"amenity": "restaurant", "name": "Alpenstube"}},
            ]}

    def test_actual_road_nodes_merged_and_sorted(self):
        model = build_network(self.data)
        self.assertEqual(model["region"], "example")
        self.assertEqual(len(model["vertices"]), 7)
        self.assertEqual(model["source_sha256"], "fixture-not-an-osm-extract")
        self.assertIn("osm:20", model["vertices"])
        self.assertEqual(len(model["poi"]), 1)
        self.assertEqual(model["poi"][0]["name"], "Alpenstube")

    def test_connected_bus_route_but_no_footway_drive(self):
        model = build_network(self.data)
        direct = route(model, "osm:10", "osm:30")
        self.assertEqual(direct["nodes"], ["osm:10", "osm:20", "osm:30"])
        self.assertAlmostEqual(direct["metres"], 200)
        self.assertEqual(route(model, "osm:30", "osm:50"), {})
        self.assertEqual(route(model, "osm:30", "osm:50", "walk")["nodes"], ["osm:30", "osm:50"])

    def test_oneway_is_respected_for_buses_but_not_walkers(self):
        model = build_network(self.data)
        self.assertEqual(route(model, "osm:20", "osm:40")["nodes"], ["osm:20", "osm:40"])
        self.assertEqual(route(model, "osm:40", "osm:20"), {})
        self.assertEqual(route(model, "osm:40", "osm:20", "walk")["nodes"], ["osm:40", "osm:20"])

    def test_isolated_streets_are_not_mysteriously_connected(self):
        model = build_network(self.data)
        self.assertEqual(route(model, "osm:10", "osm:90"), {})
        self.assertEqual(route(model, "osm:10", "osm:unknown"), {})

    def test_stop_access_uses_distance_cap_not_fake_service(self):
        model = build_network(self.data)
        stops = {s["osm_id"]: s for s in model["stops"]}
        self.assertTrue(stops[101]["connected"])
        self.assertEqual(stops[101]["access_node"], "osm:10")
        self.assertTrue(stops[102]["connected"])
        self.assertEqual(stops[102]["access_node"], "osm:40")
        self.assertFalse(stops[103]["connected"])
        self.assertIsNone(stops[103]["access_node"])

    def test_fictional_shuttle_uses_only_real_connected_stops(self):
        data = {"schema": 1, "region": "test", "origin": [47.4, 12.3],
                "features": [
                    street(1, "residential", [10, 20, 30],
                           [[185, 230], [785, 230], [1385, 230]]),
                    stop(101, [190, 230], "Talstation"),
                    stop(102, [1380, 230], "Ortsmitte"),
                    stop(103, [5000, 5000], "Disconnected"),
                ]}
        network = build_network(data)
        result = choose_game_shuttle(network)
        self.assertFalse(result["official_route"])
        self.assertIn("fiktive", result["name"])
        self.assertEqual(result["from_stop"]["osm_id"], 101)
        self.assertEqual(result["to_stop"]["osm_id"], 102)
        self.assertEqual(result["outbound"], [[185.0, 230.0], [785.0, 230.0], [1385.0, 230.0]])
        self.assertEqual(result["return"][0], [1385.0, 230.0])
        self.assertAlmostEqual(result["outbound_metres"], 1200)

    def test_shuttle_refuses_oneway_without_real_return_path(self):
        data = {"schema": 1, "features": [
            street(1, "residential", [10, 20, 30],
                   [[185, 230], [785, 230], [1385, 230]], oneway="yes"),
            stop(101, [185, 230]),
            stop(102, [1385, 230]),
        ]}
        self.assertEqual(choose_game_shuttle(build_network(data)), {})

    def test_no_official_route_claim_from_osm_bus_stop_proximity(self):
        data = {"schema": 1, "features": [
            street(1, "residential", [10, 20], [[185, 230], [1385, 230]]),
            stop(1, [185, 230]),
            stop(2, [5000, 5000]),
        ]}
        self.assertEqual(choose_game_shuttle(build_network(data)), {})

    def test_invalid_input_and_source_duplicates(self):
        with self.assertRaises(ValueError):
            build_network({"schema": 999, "features": []})
        data = dict(self.data)
        data["features"] = self.data["features"] + [self.data["features"][0]]
        self.assertEqual(build_network(data), build_network(self.data))
        with self.assertRaises(ValueError):
            route(build_network(self.data), "osm:10", "osm:30", "plane")

    def test_no_fabricated_road_to_distant_stop(self):
        data = {"schema": 1, "features": [stop(500, [0, 0])]}
        network = build_network(data)
        self.assertEqual(network["edges"], [])
        self.assertFalse(network["stops"][0]["connected"])
        self.assertEqual(route(network, "osm:1", "osm:2"), {})


if __name__ == "__main__":
    unittest.main()
