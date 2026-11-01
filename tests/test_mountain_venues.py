#!/usr/bin/env python3
"""Pure offline tests: no guessed mountainside restaurant locations."""
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import import_mountain_venues as m


class MountainsideVenueTests(unittest.TestCase):
    def setUp(self):
        self.origin = [47.42, 12.39]
        self.segment = ([[90., -400.], [90., -100.]])
        self.segments = [self.segment]
        self.stations = [[135., -390.]]

    def sample(self, x, z, osm_id=12, tags=None):
        lat, lon = m._latlon(x, z, self.origin)
        return {"type": "node", "id": osm_id, "lat": lat, "lon": lon,
                "tags": tags or {"amenity": "restaurant", "name": "Private actual restaurant"}}

    def test_exact_coordinate_projection(self):
        for x, z in [(185, 230), (90, -180), (2100, -3100)]:
            lat, lon = m._latlon(x, z, self.origin)
            point = m._world_coords(lat, lon, self.origin)
            self.assertLess(math.dist(point, [x, z]), .02)

    def test_real_piste_restaurant_without_copied_name(self):
        item = m._convert(self.sample(110, -220), self.origin,
                          self.segments, self.stations)
        self.assertEqual(item["kind"], "food")
        self.assertEqual(item["osm_id"], 12)
        self.assertLess(item["piste_metres"], 22)
        self.assertNotIn("name", item["tags"])
        self.assertAlmostEqual(item["point"][0], 110, places=1)

    def test_remote_food_not_invented(self):
        remote = self.sample(1800, -4200)
        self.assertIsNone(m._convert(remote, self.origin, self.segments, self.stations))
        no_map = self.sample(90, -220)
        self.assertIsNone(m._convert(no_map, self.origin, [], []))

    def test_hut_near_lift_station(self):
        hut = m._convert(self.sample(140, -390, tags={
            "tourism": "alpine_hut", "name": "Do not copy"}), self.origin,
            [], self.stations)
        self.assertEqual(hut["kind"], "lodging")
        self.assertLess(hut["station_metres"], 6)
        self.assertNotIn("name", hut["tags"])

    def test_untagged_and_distant_town_service_rejected(self):
        self.assertIsNone(m._convert(self.sample(110, -220, tags={
            "amenity": "bank"}), self.origin, self.segments, self.stations))
        self.assertIsNone(m._convert(self.sample(185, 230), self.origin,
                                      self.segments, self.stations))

    def test_query_is_specific_to_hospitality_without_city_roads(self):
        geo = {"origin": self.origin, "bounds": [-100, -2000, 3500, 2600]}
        query = m.query_for(geo)
        self.assertIn('"tourism"', query)
        self.assertIn('"amenity"', query)
        self.assertIn('alpine_hut', query)
        self.assertNotIn('"highway"', query)


if __name__ == "__main__":
    unittest.main()
