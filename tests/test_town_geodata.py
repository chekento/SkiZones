#!/usr/bin/env python3
"""Offline, deterministic test of the town-source transformation (#10)."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import import_town_geodata as town


class TownImportTests(unittest.TestCase):
    def test_bbox_is_bounded_and_centred(self):
        lat, lon = 47.4426, 12.3893
        box = town.town_bbox(lat, lon, 2400)
        self.assertLess(box[0], lat)
        self.assertLess(box[1], lon)
        self.assertGreater(box[2], lat)
        self.assertGreater(box[3], lon)
        with self.assertRaises(ValueError):
            town.town_bbox(lat, lon, 20000)

    def test_query_covers_real_world_requirements(self):
        query = town.overpass_query([47.41, 12.36, 47.46, 12.41])
        for term in ('"highway"', '"tourism"', '"amenity"',
                     '"bus_stop"', '"public_transport"', 'out body geom'):
            self.assertIn(term, query)

    def test_transform_and_dedupe_without_making_up_pois(self):
        raw = [
            {"type": "way", "id": 100, "tags": {"highway": "residential", "name": "Teststraße"},
             "nodes": [1, 2],
             "geometry": [{"lat": 47.44, "lon": 12.38}, {"lat": 47.441, "lon": 12.381}]},
            {"type": "node", "id": 101, "lat": 47.44, "lon": 12.38,
             "tags": {"amenity": "restaurant", "name": "Testgasthof"}},
            {"type": "node", "id": 102, "lat": 47.44, "lon": 12.38,
             "tags": {"tourism": "hotel", "name": "Testhotel"}},
            {"type": "node", "id": 103, "lat": 47.44, "lon": 12.38,
             "tags": {"highway": "bus_stop", "name": "Talstation"}},
            {"type": "node", "id": 103, "lat": 47.44, "lon": 12.38,
             "tags": {"highway": "bus_stop", "name": "Talstation"}},
            {"type": "node", "id": 104, "lat": 47.44, "lon": 12.38,
             "tags": {"natural": "peak", "name": "Unrelated"}},
            {"type": "way", "id": 105, "tags": {"highway": "service"}, "geometry": []},
        ]
        features = town.convert_elements(raw, [47.4426, 12.3893])
        self.assertEqual(len(features), 4)
        self.assertEqual({f["kind"] for f in features},
                         {"road", "food", "lodging", "bus_stop"})
        self.assertEqual([f["osm_id"] for f in features], [101, 102, 103, 100])
        self.assertEqual(features[3]["nodes"], [1, 2])
        self.assertEqual(len(features[3]["points"]), 2)
        self.assertEqual(features[0]["tags"]["name"], "Testgasthof")

    def test_project_uses_same_metre_grid_as_resort_sources(self):
        origin = [47.4426, 12.3893]
        self.assertEqual(town.project(*origin, origin), [185.0, 230.0])
        self.assertGreater(town.project(origin[0], origin[1] + 0.001, origin)[0], 185)
        self.assertLess(town.project(origin[0] + 0.001, origin[1], origin)[1], 230)


if __name__ == "__main__":
    unittest.main()
