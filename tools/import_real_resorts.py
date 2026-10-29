#!/usr/bin/env python3
"""Reproduce the offline resort database from OSM and Mapzen Terrain Tiles.

The OSM-derived JSON is distributed under ODbL 1.0, separately from game code.
Elevations remain in their own dataset with the upstream attribution.
No official resort map artwork is copied. Rerunning is an explicit data update.
"""
import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import urllib.parse
import urllib.request
from PIL import Image

ROOT = Path(__file__).resolve().parents[1] / 'assets' / 'geodata'
REGIONS = {
    'braunlage': dict(name='Braunlage · Wurmberg', bbox=[51.72, 10.58, 51.78, 10.65], origin=[51.7328, 10.6159], difficulty=0),
    'filzmoos': dict(name='Filzmoos', bbox=[47.398, 13.44, 47.468, 13.55], origin=[47.4332, 13.5217], difficulty=1),
    'kitzbuehel': dict(name='Kitzbühel', bbox=[47.285, 12.255, 47.49, 12.49], origin=[47.4424, 12.3911], difficulty=2),
    'seiseralm': dict(name='Seiser Alm', bbox=[46.51, 11.55, 46.60, 11.73], origin=[46.5415, 11.5667], difficulty=3),
}


def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'SkiZones-offline-import/0.14 (https://github.com/chekento/SkiZones)'})
    with urllib.request.urlopen(req, timeout=65) as response:
        return response.read()


def tile_xy(lat, lon, zoom):
    n = 2 ** zoom
    return (lon + 180) / 360 * n, (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--region', choices=REGIONS)
    parser.add_argument('--offline', action='store_true', help='Rebuild using previously downloaded source files')
    args = parser.parse_args()
    ROOT.mkdir(parents=True, exist_ok=True)
    cache = ROOT / 'source'
    cache.mkdir(exist_ok=True)
    tile_cache = ROOT.parent.parent / 'build' / 'geo-tiles'
    tile_cache.mkdir(parents=True, exist_ok=True)
    for key, spec in REGIONS.items():
        if args.region and args.region != key:
            continue
        south, west, north, east = spec['bbox']
        box = ','.join(map(str, spec['bbox']))
        query = f'[out:json][timeout:55];(way["aerialway"]({box});way["piste:type"="downhill"]({box});node["aerialway"="station"]({box});node["natural"="peak"]({box}););out body geom;'
        raw_file = cache / (key + '-osm.json')
        if not raw_file.exists():
            if args.offline:
                raise FileNotFoundError(raw_file)
            print('Downloading OSM', key, flush=True)
            url = 'https://overpass-api.de/api/interpreter?' + urllib.parse.urlencode({'data': query})
            raw = fetch(url)
            data = json.loads(raw)
            if 'remark' in data:
                raise RuntimeError(data['remark'])
            raw_file.write_bytes(raw)
        data = json.loads(raw_file.read_text())
        entry_name = {'braunlage': 'Wurmbergseilbahn', 'filzmoos': 'Papagenobahn', 'kitzbuehel': 'Hahnenkammbahn', 'seiseralm': 'Seiseralmbahn'}[key]
        entry = next(e for e in data['elements'] if e.get('tags', {}).get('name') == entry_name and e['type'] == 'way')
        station = entry['geometry'][0]
        spec['origin'] = [station['lat'] - 65 / 111320, station['lon']]
        lat0, lon0 = spec['origin']
        sx, sy = 111320 * math.cos(math.radians(lat0)), 111320

        def project(lat, lon):
            return [round((lon - lon0) * sx + 185, 2), round(-(lat - lat0) * sy + 230, 2)]

        left, bottom = project(south, west)
        right, top = project(north, east)
        spec['bounds'] = [left, top, right - left, bottom - top]
        features = []
        for element in data['elements']:
            tags = element.get('tags', {})
            if 'geometry' in element:
                points = [project(p['lat'], p['lon']) for p in element['geometry'] if p is not None]
            else:
                points = [project(element['lat'], element['lon'])]
            if len(points) < 2 and element['type'] == 'way':
                continue
            features.append(dict(osm_id=element['id'], osm_type=element['type'], tags=tags, points=points, nodes=element.get('nodes', [])))
        # Overpass returns complete ways intersecting the query. Expand the
        # raster to include their endpoints instead of clipping real geometry.
        all_points = [p for f in features for p in f['points']]
        left = min(left, min(p[0] for p in all_points) - 80)
        right = max(right, max(p[0] for p in all_points) + 80)
        top = min(top, min(p[1] for p in all_points) - 80)
        bottom = max(bottom, max(p[1] for p in all_points) + 80)
        spec['bounds'] = [left, top, right - left, bottom - top]
        result = dict(**spec, schema=1, id=key, source='OpenStreetMap', license='ODbL-1.0',
                      copyright='© OpenStreetMap contributors', query=query,
                      osm_timestamp=data.get('osm3s', {}).get('timestamp_osm_base'),
                      source_sha256=hashlib.sha256(raw_file.read_bytes()).hexdigest(), features=features)
        (ROOT / (key + '.json')).write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
        print(key, len(features), 'OSM features', flush=True)
        # ~55 m grid, stored as little-endian float32 metres above sea level.
        step = 55
        width, depth = math.ceil((right - left) / step) + 1, math.ceil((bottom - top) / step) + 1
        zoom = 11
        tiles = {}

        def elevation(lat, lon):
            tx, ty = tile_xy(lat, lon, zoom)
            x, y = math.floor(tx), math.floor(ty)
            if (x, y) not in tiles:
                path = tile_cache / f'{zoom}-{x}-{y}.png'
                if not path.exists():
                    if args.offline:
                        raise FileNotFoundError(path)
                    path.write_bytes(fetch(f'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{zoom}/{x}/{y}.png'))
                tiles[x, y] = Image.open(path).convert('RGB')
            r, g, b = tiles[x, y].getpixel((min(255, int((tx - x) * 256)), min(255, int((ty - y) * 256))))
            return r * 256 + g + b / 256 - 32768

        heights = []
        for row in range(depth):
            z = top + row * step
            lat = lat0 - (z - 230) / sy
            for col in range(width):
                x = left + col * step
                heights.append(elevation(lat, lon0 + (x - 185) / sx))
        binary = struct.pack('<' + 'f' * len(heights), *heights)
        (ROOT / (key + '-heights.bin')).write_bytes(binary)
        meta = dict(step=step, width=width, depth=depth, left=left, top=top,
                    min=min(heights), max=max(heights), zoom=zoom, sha256=hashlib.sha256(binary).hexdigest(),
                    source='Mapzen Terrain Tiles', url='https://registry.opendata.aws/terrain-tiles/',
                    attribution_url='https://github.com/tilezen/joerd/blob/master/docs/attribution.md')
        (ROOT / (key + '-heights.json')).write_text(json.dumps(meta, indent=2) + '\n')
        print(key, width, depth, 'elevations', round(min(heights)), round(max(heights)), flush=True)


if __name__ == '__main__':
    main()
