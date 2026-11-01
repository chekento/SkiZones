#!/usr/bin/env python3
"""Pin only verified hospitality locations close to *real mapped ski runs*.

This is intentionally NOT a town/city import. Names, branding and operator
information are never imported into the game presentation. OSM © contributors;
ODbL 1.0. Source query and raw HTTP response are archived for reproducibility.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from time import sleep

ROOT = Path(__file__).resolve().parents[1]
GEO = ROOT / "assets" / "geodata"
OUT = GEO / "mountain-venues"
ENDPOINTS = (
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.nchc.org.tw/api/interpreter",
)
REGIONS = ("braunlage", "filzmoos", "kitzbuehel", "seiseralm")
MAX_DISTANCE_METRES = 165.0


def _world_coords(lat, lon, origin):
    return [round((lon - origin[1]) * 111320.0 * math.cos(math.radians(origin[0])) + 185, 2),
            round(-(lat - origin[0]) * 111320.0 + 230, 2)]


def _latlon(x, z, origin):
    return [origin[0] - (z - 230.0) / 111320.0,
            origin[1] + (x - 185.0) / (111320.0 * math.cos(math.radians(origin[0])))]


def query_for(geo):
    bounds = geo["bounds"]
    a = _latlon(bounds[0] - 250, bounds[1] - 250, geo["origin"])
    b = _latlon(bounds[0] + bounds[2] + 250,
                bounds[1] + bounds[3] + 250, geo["origin"])
    box = ",".join(f"{n:.7f}" for n in
                   (min(a[0], b[0]), min(a[1], b[1]),
                    max(a[0], b[0]), max(a[1], b[1])))
    food = "restaurant|cafe|fast_food|bar"
    stay = "alpine_hut|hotel|guest_house|hostel|chalet"
    return (f'[out:json][timeout:120];('
            f'node["amenity"~"^({food})$"]({box});'
            f'way["amenity"~"^({food})$"]({box});'
            f'node["tourism"~"^({stay})$"]({box});'
            f'way["tourism"~"^({stay})$"]({box});'
            ');out body geom;')


def _distance_segment(p, a, b):
    x, y = p[0] - a[0], p[1] - a[1]
    dx, dy = b[0] - a[0], b[1] - a[1]
    dot = dx*dx + dy*dy
    t = max(0., min(1., (x*dx+y*dy)/dot)) if dot else 0.
    return math.hypot(p[0] - (a[0] + t*dx), p[1] - (a[1] + t*dy))


def _corridors(geo):
    segments = []
    station_points = []
    for item in geo["features"]:
        tags = item.get("tags", {})
        if tags.get("piste:type") == "downhill":
            points = item.get("points", [])
            for i in range(1, len(points)):
                segments.append((points[i-1], points[i]))
        if tags.get("aerialway") in ("gondola", "cable_car", "chair_lift", "drag_lift", "t-bar"):
            points = item.get("points", [])
            if len(points) >= 2:
                station_points.extend([points[0], points[-1]])
    return segments, station_points


def _convert(element, origin, segments, stations):
    tags = element.get("tags", {})
    family = "food" if tags.get("amenity") in ("restaurant", "cafe", "fast_food", "bar") else (
        "lodging" if tags.get("tourism") in ("alpine_hut", "hotel", "guest_house", "hostel", "chalet") else "")
    if not family or element.get("type") not in ("node", "way") or not isinstance(element.get("id"), int):
        return None
    if element["type"] == "node":
        if "lat" not in element or "lon" not in element: return None
        points = [{"lat": element["lat"], "lon": element["lon"]}]
    else:
        points = element.get("geometry", [])
    if not isinstance(points, list) or not points or len(points) > 512:
        return None
    try:
        shape = [_world_coords(float(p["lat"]), float(p["lon"]), origin) for p in points]
    except (ValueError, TypeError, KeyError):
        return None
    centre = [sum(p[0] for p in shape) / len(shape),
              sum(p[1] for p in shape) / len(shape)]
    if math.hypot(centre[0] - 185, centre[1] - 230) < 360:
        return None
    piste = min((_distance_segment(centre, a, b) for a, b in segments), default=math.inf)
    station = min((math.dist(centre, p) for p in stations), default=math.inf)
    nearest = min(piste, station)
    if nearest > MAX_DISTANCE_METRES:
        return None
    return {"osm_type": element["type"], "osm_id": element["id"], "kind": family,
            "point": [round(centre[0], 2), round(centre[1], 2)],
            "piste_metres": round(piste, 2) if math.isfinite(piste) else None,
            "station_metres": round(station, 2) if math.isfinite(station) else None,
            "tags": {k: v for k, v in tags.items()
                     if k in ("amenity", "tourism", "cuisine") and isinstance(v, str)}}


def prepare(region, *, offline=False):
    geo = json.loads((GEO / f"{region}.json").read_text(encoding="utf-8"))
    query = query_for(geo)
    source = OUT / "source"
    source.mkdir(parents=True, exist_ok=True)
    raw_path = source / f"{region}-osm.json"
    query_path = source / f"{region}-query.txt"
    source_path = raw_path
    source_query = query_path
    source_scope = "resort_bbox"
    if raw_path.is_file():
        if not query_path.is_file() or query_path.read_text(encoding="utf-8") != query:
            raise ValueError("Cached OSM source has different query: " + region)
        raw = raw_path.read_bytes()
    elif offline:
        # The larger OSM Overpass bounding boxes can fail with HTTP 502/504.
        # Use only the genuine, already-pinned town source as a *limited*
        # fallback. It does NOT claim to cover every high-altitude hut.
        source_path = GEO / "towns" / "source" / f"{region}-osm.json"
        source_query = GEO / "towns" / "source" / f"{region}-query.txt"
        town_extract = GEO / "towns" / f"{region}.json"
        if not source_path.is_file() or not source_query.is_file() or not town_extract.is_file():
            raise FileNotFoundError("Missing authentic offline OSM town source: " + region)
        raw = source_path.read_bytes()
        town = json.loads(town_extract.read_text(encoding="utf-8"))
        if hashlib.sha256(raw).hexdigest() != town.get("source_sha256"):
            raise ValueError("Pinned town source checksum mismatch: " + region)
        if source_query.read_text(encoding="utf-8") != town.get("query"):
            raise ValueError("Pinned town OSM query mismatch: " + region)
        if town.get("region") != region or town.get("source") != "OpenStreetMap":
            raise ValueError("Pinned town source attribution mismatch: " + region)
        source_scope = "partial_town_extract"
    else:
        raw = b""
        exceptions = []
        for index, endpoint in enumerate(ENDPOINTS * 2):
            request = Request(endpoint, data=query.encode("utf-8"),
                              headers={"User-Agent": "SkiZones/0.20 (+https://github.com/chekento/SkiZones)",
                                       "Content-Type": "text/plain; charset=utf-8"})
            try:
                with urlopen(request, timeout=100) as response:
                    raw = response.read(20 * 1024 * 1024 + 1)
                # An unavailable mirror may return HTML with HTTP 200.
                if b'"elements"' not in raw:
                    raise ValueError("Overpass returned no elements collection")
                break
            except (HTTPError, URLError, TimeoutError, ValueError) as error:
                exceptions.append(str(error))
                print(region, "Overpass attempt", index + 1, endpoint,
                      "unavailable:", str(error), flush=True)
                if index < len(ENDPOINTS) * 2 - 1:
                    sleep(3 + index * 2)
        if not raw or b'"elements"' not in raw:
            raise RuntimeError(region + ": no verifiable real OSM hospitality data: " +
                               "; ".join(exceptions[-3:]))
        if len(raw) > 20 * 1024 * 1024:
            raise ValueError("OSM response exceeds hospitality-only limit")
        raw_path.write_bytes(raw)
        query_path.write_text(query, encoding="utf-8")
    dataset = json.loads(raw)
    if not isinstance(dataset.get("elements"), list) or dataset.get("remark"):
        raise ValueError("OSM did not return valid hospitality source: " + region)
    segments, stations = _corridors(geo)
    selected = []
    seen = set()
    for element in dataset["elements"]:
        site = _convert(element, geo["origin"], segments, stations)
        if site is None: continue
        key = (site["osm_type"], site["osm_id"])
        if key not in seen: selected.append(site); seen.add(key)
    selected.sort(key=lambda s: (s["piste_metres"] if s["piste_metres"] is not None else 100000,
                                 s["osm_type"], s["osm_id"]))
    record = {"schema": 1, "region": region, "source": "OpenStreetMap",
              "license": "ODbL-1.0", "source_sha256": hashlib.sha256(raw).hexdigest(),
              "source_file": source_path.relative_to(ROOT).as_posix(),
              "source_query_file": source_query.relative_to(ROOT).as_posix(),
              "coverage": source_scope,
              "coverage_complete": False,
              "osm_timestamp": dataset.get("osm3s", {}).get("timestamp_osm_base"),
              "max_distance_metres": MAX_DISTANCE_METRES, "features": selected}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f"{region}.json").write_text(json.dumps(record, ensure_ascii=False,
        sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
    print(region, len(selected), "verified mountainside hospitality POIs",
          "coverage", source_scope, "(limited)" if source_scope != "resort_bbox" else "(requested extent)",
          "piste-near",sum(s["piste_metres"] is not None and s["piste_metres"]<=MAX_DISTANCE_METRES for s in selected))
    return record


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--region", choices=REGIONS)
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args()
    for region in ([args.region] if args.region else REGIONS):
        prepare(region, offline=args.offline)


if __name__ == "__main__":
    main()
