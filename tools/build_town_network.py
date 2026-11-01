#!/usr/bin/env python3
"""Build an honest, deterministic candidate street graph from pinned OSM towns.

This is NOT an official ski-bus network and makes no timetable claims.
Bus-capable streets and pedestrian links stay distinguishable, disconnected
components stay disconnected, and stops are never teleported to remote roads.
"""
from __future__ import annotations

import argparse
import hashlib
import heapq
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "geodata" / "towns"
BUS_STREETS = {"primary", "secondary", "tertiary", "residential",
               "unclassified", "living_street", "service"}
WALK_STREETS = BUS_STREETS | {"pedestrian", "footway", "path", "track"}
STOP_KINDS = {"bus_stop", "transit_stop"}
MAX_STOP_ACCESS_METRES = 120.0


def _point(value):
    if not isinstance(value, (list, tuple)) or len(value) != 2:
        raise ValueError("A geographic point must be an [x, z] pair")
    x, z = float(value[0]), float(value[1])
    if not math.isfinite(x) or not math.isfinite(z):
        raise ValueError("Non-finite geographic coordinate")
    return [round(x, 2), round(z, 2)]


def _distance(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def _key(feature, index):
    nodes = feature.get("nodes", [])
    if len(nodes) == len(feature["points"]) and isinstance(nodes[index], int):
        return "osm:" + str(nodes[index])
    # Some imported geometries lack original node IDs. Do not invent
    # connectivity for near-but-distinct points: exact 1cm keys only.
    point = _point(feature["points"][index])
    return f"xy:{point[0]:.2f}:{point[1]:.2f}"


def build_network(data: dict) -> dict:
    if data.get("schema") != 1 or not isinstance(data.get("features"), list):
        raise ValueError("Expected a schema-1 pinned town extract")
    vertex = {}
    edges = {}
    source_ids = set()
    stops = []
    poi = []
    for feature in data["features"]:
        kind = feature.get("kind")
        identifier = (feature.get("osm_type"), feature.get("osm_id"))
        if identifier in source_ids:
            continue
        source_ids.add(identifier)
        points = feature.get("points", [])
        tags = feature.get("tags", {})
        if not isinstance(tags, dict) or not isinstance(points, list):
            continue
        if kind == "road" and len(points) >= 2:
            highway = tags.get("highway", "")
            if highway not in WALK_STREETS:
                continue
            for i in range(1, len(points)):
                a, b = _key(feature, i - 1), _key(feature, i)
                pa, pb = _point(points[i - 1]), _point(points[i])
                distance = _distance(pa, pb)
                if distance < 0.01 or distance > 10000:
                    continue
                if a in vertex and _distance(vertex[a], pa) > 0.02:
                    raise ValueError(f"OSM road node {a} has conflicting coordinates")
                if b in vertex and _distance(vertex[b], pb) > 0.02:
                    raise ValueError(f"OSM road node {b} has conflicting coordinates")
                vertex[a], vertex[b] = pa, pb
                modes = ["walk", "bus"] if highway in BUS_STREETS else ["walk"]
                # Honor mapped one-way car roads; walkers may reverse.
                oneway = str(tags.get("oneway", "no")).lower()
                for mode in modes:
                    allowed = [(a, b)] if mode == "bus" and oneway in ("yes", "1", "true") else (
                        [(b, a)] if mode == "bus" and oneway == "-1" else [(a, b), (b, a)])
                    for src, dst in allowed:
                        edges[(src, dst, mode)] = min(distance, edges.get((src, dst, mode), math.inf))
        elif kind in STOP_KINDS and points:
            stops.append({"osm_type": identifier[0], "osm_id": identifier[1],
                          "kind": kind, "name": str(tags.get("name", "")),
                          "point": _point(points[0])})
        elif kind in ("food", "lodging") and points:
            poi.append({"osm_type": identifier[0], "osm_id": identifier[1],
                        "kind": kind, "name": str(tags.get("name", "")),
                        "point": _point(points[0])})
    # Attach to the nearest *existing vertex* only; unmatched stops remain
    # explicit, never fabricate buses or an off-road station connection.
    bus_vertices = set()
    for (a, b, mode) in edges:
        if mode == "bus":
            bus_vertices.add(a)
            bus_vertices.add(b)
    for stop in stops:
        nearest = min(bus_vertices, key=lambda key: (_distance(vertex[key], stop["point"]), key)) if bus_vertices else None
        distance = _distance(vertex[nearest], stop["point"]) if nearest is not None else math.inf
        stop["access_node"] = nearest if distance <= MAX_STOP_ACCESS_METRES else None
        stop["access_metres"] = round(distance, 2) if nearest is not None else None
        stop["connected"] = stop["access_node"] is not None
    ordered_edges = [{"from": a, "to": b, "mode": mode, "metres": round(length, 2)}
                     for (a, b, mode), length in sorted(edges.items())]
    return {"schema": 1, "region": data.get("region"), "origin": data.get("origin"),
            "source_sha256": data.get("source_sha256"), "vertices": dict(sorted(vertex.items())),
            "edges": ordered_edges,
            "stops": sorted(stops, key=lambda p: (str(p["osm_type"]), int(p["osm_id"]))),
            "poi": sorted(poi, key=lambda p: (str(p["osm_type"]), int(p["osm_id"])))}


def route(network: dict, first: str, last: str, mode: str = "bus") -> dict:
    """Shortest connected route. No path means no supposed service."""
    if mode not in ("bus", "walk"):
        raise ValueError("Unsupported transport mode")
    nodes = network["vertices"]
    if first not in nodes or last not in nodes:
        return {}
    if first == last:
        return {"nodes": [first], "points": [nodes[first]], "metres": 0.0}
    neighbors = {}
    for edge in network["edges"]:
        if edge["mode"] == mode:
            neighbors.setdefault(edge["from"], []).append((edge["metres"], edge["to"]))
    queue = [(0.0, first)]
    costs = {first: 0.0}
    previous = {}
    while queue:
        cost, node = heapq.heappop(queue)
        if cost > costs[node] + 1e-9:
            continue
        if node == last:
            seq = [last]
            while seq[-1] != first:
                seq.append(previous[seq[-1]])
            seq.reverse()
            return {"nodes": seq, "points": [nodes[x] for x in seq],
                    "metres": round(cost, 2)}
        for metres, target in neighbors.get(node, []):
            candidate = cost + metres
            if candidate < costs.get(target, math.inf) - 1e-9:
                costs[target], previous[target] = candidate, node
                heapq.heappush(queue, (candidate, target))
    return {}


def choose_game_shuttle(network: dict) -> dict:
    """Optional *fictional SkiZones shuttle* on verified, bus-capable OSM roads.

    This is intentionally not a claim that an operator or timetable exists.
    Never draw a line to disconnected bus stops, across one-way streets or
    beyond the road source. Skip completely where no defensible path exists.
    """
    origin = [185.0, 230.0]
    stops = [stop for stop in network["stops"]
             if stop.get("kind") == "bus_stop" and stop.get("connected")]
    if len(stops) < 2:
        return {}
    stops.sort(key=lambda stop: (_distance(stop["point"], origin),
                                 stop["osm_id"]))
    start = stops[0]
    if _distance(start["point"], origin) > 550.0:
        return {}
    possibilities = []
    for end in stops[1:]:
        if end["access_node"] == start["access_node"]:
            continue
        direct = route(network, start["access_node"], end["access_node"])
        if not 280.0 <= direct.get("metres", -1.0) <= 3400.0:
            continue
        reverse = route(network, end["access_node"], start["access_node"])
        if not 280.0 <= reverse.get("metres", -1.0) <= 4000.0:
            continue
        # A plausible local shuttle: typically 1.2km from the village
        # gateway, deterministic OSM-ID tie break, not a fictional ski
        # operator's published connection.
        score = (abs(direct["metres"] - 1200.0), end["osm_id"])
        possibilities.append((score, end, direct, reverse))
    if not possibilities:
        return {}
    _, end, out, back = min(possibilities, key=lambda candidate: candidate[0])
    return {
        "name": "SkiZones-Spielbus (fiktive Simulation)",
        "official_route": False,
        "from_stop": {"osm_type": start["osm_type"], "osm_id": start["osm_id"],
                      "name": start["name"], "point": start["point"]},
        "to_stop": {"osm_type": end["osm_type"], "osm_id": end["osm_id"],
                    "name": end["name"], "point": end["point"]},
        "outbound": out["points"], "return": back["points"],
        "outbound_metres": out["metres"],
        "return_metres": back["metres"],
    }


def choose_hotel_gondola_shuttle(network: dict, resort: dict) -> dict:
    """Select a fictional shuttle connecting a *mapped hotel* to a gondola.

    Only real OSM street vertices and real extracted accommodation locations
    are used; any walking distance to the source site remains explicit.
    Where no legal bidirectional road route exists, return {}.
    """
    origin = [185.0, 230.0]
    bus_nodes = set()
    for edge in network["edges"]:
        if edge["mode"] == "bus":
            bus_nodes.add(edge["from"])
            bus_nodes.add(edge["to"])
    if not bus_nodes:
        return {}

    def access(point, maximum=160.0):
        closest = min(bus_nodes, key=lambda key: (_distance(network["vertices"][key], point), key))
        distance = _distance(network["vertices"][closest], point)
        return (closest, round(distance, 2)) if distance <= maximum else (None, None)

    hotels = sorted(
        (p for p in network["poi"]
         if p["kind"] == "lodging" and _distance(p["point"], origin) < 2100),
        key=lambda p: (_distance(p["point"], origin), p["osm_id"]))[:25]
    lifts = sorted(
        (lift for lift in resort.get("lifts", []) if lift.get("kind") == "gondola"),
        key=lambda p: (_distance(p["bottom"], origin), p["id"]))[:12]
    # A resort without any gondola does not acquire a fictional gondola.
    if not lifts:
        return {}
    candidates = []
    for lift in lifts:
        station_point = lift["bottom"]
        station_node, station_walk = access(station_point, 200.0)
        if station_node is None:
            continue
        for hotel in hotels:
            hotel_node, hotel_walk = access(hotel["point"], 140.0)
            if hotel_node is None or hotel_node == station_node:
                continue
            to_station = route(network, hotel_node, station_node)
            if not 180 <= to_station.get("metres", -1) <= 6500:
                continue
            to_hotel = route(network, station_node, hotel_node)
            if not 180 <= to_hotel.get("metres", -1) <= 7000:
                continue
            # Reward a useful connection, not a 20km sightseeing loop.
            score = (hotel_walk + station_walk +
                     abs(to_station["metres"] - 1050) * 0.25 +
                     _distance(station_point, origin) * 0.12)
            candidates.append((round(score, 2), hotel["osm_id"], lift["id"],
                               hotel, lift, hotel_walk, station_walk, to_station, to_hotel))
    if not candidates:
        return {}
    _, _, _, hotel, lift, hotel_walk, station_walk, outbound, returning = min(
        candidates, key=lambda row: row[:3])
    return {
        "name": "SkiZones Hotel-Gondelbus · fiktive Simulation",
        "official_route": False,
        "from_hotel": {"osm_type": hotel["osm_type"], "osm_id": hotel["osm_id"],
                       "point": hotel["point"], "access_metres": hotel_walk},
        "to_lift": {"id": int(lift["id"]), "kind": "gondola",
                    "point": lift["bottom"], "access_metres": station_walk},
        "outbound": outbound["points"],
        "return": returning["points"],
        "outbound_metres": outbound["metres"],
        "return_metres": returning["metres"],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--region", choices=("braunlage", "filzmoos", "kitzbuehel", "seiseralm"))
    args = parser.parse_args()
    for region in ([args.region] if args.region else
                   ("braunlage", "filzmoos", "kitzbuehel", "seiseralm")):
        source = SOURCE / f"{region}.json"
        if not source.is_file():
            raise SystemExit(f"Missing pinned OSM town source: {source}")
        data = json.loads(source.read_text(encoding="utf-8"))
        output = build_network(data)
        output["game_shuttle_preview"] = choose_game_shuttle(output)
        seed_file = ROOT / "assets" / "geodata" / f"{region}-seed.json"
        if seed_file.is_file():
            seed = json.loads(seed_file.read_text(encoding="utf-8"))
            output["hotel_gondola_shuttle"] = choose_hotel_gondola_shuttle(output, seed)
        if not output["edges"]:
            raise SystemExit(f"No routable OSM streets for {region}")
        target = SOURCE / f"{region}-network.json"
        target.write_text(json.dumps(output, ensure_ascii=False,
                                     separators=(",", ":"), sort_keys=True) + "\n",
                          encoding="utf-8")
        print(f"{region}: {len(output['vertices'])} nodes, "
              f"{len(output['edges'])} directed connections, "
              f"{sum(s['connected'] for s in output['stops'])}/"
              f"{len(output['stops'])} nearby transit platforms")


if __name__ == "__main__":
    main()
