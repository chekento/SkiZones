#!/usr/bin/env python3
"""Fetch reproducible OSM town features WITHOUT touching the live resort map.

Phase 1 of issue #10: streets, accommodation, food, and transit stops.
This data is deliberately separate from the existing piste/lift/terrain sets.
It must be reviewed and integrated into the game before appearing in an APK.
OpenStreetMap data is ODbL 1.0: © OpenStreetMap contributors.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
GEO = ROOT / "assets" / "geodata"
TOWNS = GEO / "towns"
API = "https://overpass-api.de/api/interpreter"
USER_AGENT = "SkiZones-geodata/0.19 (+https://github.com/chekento/SkiZones)"
ROAD_CLASSES = ("primary", "secondary", "tertiary", "residential",
                "living_street", "unclassified", "service", "pedestrian",
                "footway", "path", "track")
FOOD_CLASSES = ("restaurant", "cafe", "fast_food")
LODGING_CLASSES = ("hotel", "guest_house", "hostel", "apartment", "chalet")

def town_bbox(lat: float, lon: float, radius_m: float) -> list[float]:
    if not (500 <= radius_m <= 10000):
        raise ValueError("Town coverage radius must be 500–10000 metres")
    dlat = radius_m / 111320.0
    dlon = radius_m / (111320.0 * math.cos(math.radians(lat)))
    return [round(lat - dlat, 7), round(lon - dlon, 7),
            round(lat + dlat, 7), round(lon + dlon, 7)]

def overpass_query(bbox: list[float]) -> str:
    box = ",".join(map(str, bbox))
    roads = "|".join(ROAD_CLASSES)
    foods = "|".join(FOOD_CLASSES)
    lodging = "|".join(LODGING_CLASSES)
    terms = [
        f'way["highway"~"^({roads})$"]({box});',
        f'node["amenity"~"^({foods})$"]({box});',
        f'way["amenity"~"^({foods})$"]({box});',
        f'node["tourism"~"^({lodging})$"]({box});',
        f'way["tourism"~"^({lodging})$"]({box});',
        f'node["highway"="bus_stop"]({box});',
        f'node["public_transport"~"^(platform|station)$"]({box});',
        f'way["public_transport"="platform"]({box});',
        f'node["amenity"="bus_station"]({box});',
        f'way["amenity"="bus_station"]({box});',
    ]
    return "[out:json][timeout:90];(" + "".join(terms) + ");out body geom;"

def project(lat: float, lon: float, origin: list[float]) -> list[float]:
    lat0, lon0 = origin
    return [round((lon - lon0) * 111320 * math.cos(math.radians(lat0)) + 185, 2),
            round(-(lat - lat0) * 111320 + 230, 2)]

def feature_kind(tags: dict) -> str | None:
    if tags.get("highway") == "bus_stop" or tags.get("amenity") == "bus_station":
        return "bus_stop"
    if tags.get("public_transport") in ("station", "platform"):
        return "transit_stop"
    if tags.get("tourism") in LODGING_CLASSES:
        return "lodging"
    if tags.get("amenity") in FOOD_CLASSES:
        return "food"
    if tags.get("highway") in ROAD_CLASSES:
        return "road"
    return None

def convert_elements(elements: list, origin: list[float]) -> list[dict]:
    output = []
    known = set()
    for element in elements:
        if not isinstance(element, dict):
            continue
        obj_type, obj_id = element.get("type"), element.get("id")
        if obj_type not in ("node", "way") or not isinstance(obj_id, int):
            continue
        identity = (obj_type, obj_id)
        if identity in known:
            continue
        tags = element.get("tags", {})
        if not isinstance(tags, dict):
            continue
        kind = feature_kind(tags)
        if kind is None:
            continue
        if obj_type == "node":
            if "lat" not in element or "lon" not in element:
                continue
            coords = [{"lat": element["lat"], "lon": element["lon"]}]
        else:
            coords = element.get("geometry", [])
            if not isinstance(coords, list) or len(coords) < 2:
                continue
        if not all(isinstance(p, dict) and
                   isinstance(p.get("lat"), (int, float)) and
                   isinstance(p.get("lon"), (int, float)) for p in coords):
            continue
        points = [project(p["lat"], p["lon"], origin) for p in coords]
        record = {"osm_type": obj_type, "osm_id": obj_id, "kind": kind,
                  "tags": tags, "points": points}
        if obj_type == "way":
            record["nodes"] = element.get("nodes", [])
        output.append(record)
        known.add(identity)
    return sorted(output, key=lambda obj: (obj["osm_type"], obj["osm_id"]))

def prepare(region: str, radius_m: float, offline: bool, refresh: bool) -> Path:
    original = json.loads((GEO / f"{region}.json").read_text(encoding="utf-8"))
    origin = original["origin"]
    bbox = town_bbox(origin[0], origin[1], radius_m)
    query = overpass_query(bbox)
    source_dir = TOWNS / "source"
    source_dir.mkdir(parents=True, exist_ok=True)
    raw_file = source_dir / f"{region}-osm.json"
    if raw_file.exists() and not refresh:
        raw = raw_file.read_bytes()
        data = json.loads(raw)
        # A cached extract can only be reused for its exact query.
        source_query = source_dir / f"{region}-query.txt"
        if not source_query.is_file() or source_query.read_text(encoding="utf-8") != query:
            raise RuntimeError(f"{region}: source query changed; explicitly use --refresh")
    else:
        if offline:
            raise FileNotFoundError(f"No matching cached source for {region}")
        request = urllib.request.Request(
            API, data=query.encode("utf-8"),
            headers={"User-Agent": USER_AGENT, "Content-Type": "text/plain; charset=utf-8"})
        with urllib.request.urlopen(request, timeout=120) as response:
            raw = response.read(40 * 1024 * 1024 + 1)
        if len(raw) > 40 * 1024 * 1024:
            raise RuntimeError(f"{region}: unexpected large response")
        data = json.loads(raw)
        if data.get("remark"):
            raise RuntimeError(str(data["remark"]))
        if not isinstance(data.get("elements"), list):
            raise RuntimeError("OSM result has no elements")
        raw_file.write_bytes(raw)
        (source_dir / f"{region}-query.txt").write_text(query, encoding="utf-8")
    if not isinstance(data.get("elements"), list):
        raise RuntimeError("Invalid Overpass source data")
    features = convert_elements(data["elements"], origin)
    counts = {kind: sum(f["kind"] == kind for f in features)
              for kind in ("road", "lodging", "food", "bus_stop", "transit_stop")}
    if not counts["road"]:
        raise RuntimeError(f"{region}: not a usable village road extract")
    result = {
        "schema": 1, "region": region, "origin": origin, "bbox": bbox,
        "radius_m": radius_m, "query": query,
        "source": "OpenStreetMap", "license": "ODbL-1.0",
        "copyright": "© OpenStreetMap contributors",
        "osm_timestamp": data.get("osm3s", {}).get("timestamp_osm_base"),
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "feature_counts": counts, "features": features,
    }
    TOWNS.mkdir(parents=True, exist_ok=True)
    result_path = TOWNS / f"{region}.json"
    result_path.write_text(json.dumps(result, ensure_ascii=False,
                                      separators=(",", ":"), sort_keys=True) + "\n",
                           encoding="utf-8")
    print(f"{region}: {len(features)} OSM elements; {counts}")
    return result_path

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--region", choices=("braunlage", "filzmoos",
                                             "kitzbuehel", "seiseralm"))
    parser.add_argument("--radius-m", type=float, default=2400,
                        help="Town-centre radius (500–10000 metres)")
    parser.add_argument("--offline", action="store_true",
                        help="Rebuild only from matching pinned source files")
    parser.add_argument("--refresh", action="store_true",
                        help="Explicitly replace pinned source files from OSM")
    args = parser.parse_args()
    if args.offline and args.refresh:
        parser.error("--offline cannot be combined with --refresh")
    for region in ([args.region] if args.region else
                   ["braunlage", "filzmoos", "kitzbuehel", "seiseralm"]):
        prepare(region, args.radius_m, args.offline, args.refresh)

if __name__ == "__main__":
    main()
