# Offline geographic database

The `*-osm.json` files in `source/` are the unmodified Overpass responses.
The four `<region>.json` files are a derived OpenStreetMap database licensed
under the Open Data Commons Open Database License 1.0 (ODbL).
© OpenStreetMap contributors, https://www.openstreetmap.org/copyright.
ODbL: https://opendatacommons.org/licenses/odbl/1-0/.

Each feature preserves its OSM type, ID, tags, original node IDs and geometry,
converted from WGS84 latitude/longitude to a local metre grid. The chosen
origin is recorded. Negative Z is north; X is east. Coordinates are not rotated
or compressed. The playable envelope includes complete ways returned by the
query. Raw responses preserve the dataset timestamp and query provenance.

`*-heights.bin` contains little-endian float32 terrain heights in metres above
sea level, in row-major order. The matching JSON records the grid dimensions,
origin, step and checksum. The grid is derived separately from Mapzen Terrain
Tiles (Terrarium), accessed 2026-10-29. Attribution and source licences:
https://github.com/tilezen/joerd/blob/master/docs/attribution.md.
Austria: © offene Daten Österreichs – DGM Österreich. Europe: produced using
Copernicus data and information funded by the European Union – EU-DEM layers.
Global GMTED2010/SRTM: courtesy of USGS. These elevation files are not an OSM
database; their upstream data licences apply independently.

Reproduce with `python tools/import_real_resorts.py` (Python + Pillow).
Use `--offline` after caching the tiles to reproduce without new requests.
Do not refresh extracts automatically on application launch: the APK works
entirely offline and pins its map versions. Update queries explicitly for a
new data release. Inspect the recorded SHA-256 hashes and upstream terms.

The application reconstructs 3D terrain and its own vector graphics. No resort
map artwork or logos are copied. Geographic completeness is limited to the
selected envelopes and features present in OpenStreetMap on the recorded date.

The committed `*-seed.json` files cache immutable source geometry and computed
profiles, keyed to the raw extract SHA-256. Rebuild them with Godot 4.5.2:
`godot --headless --script tools/bake_real_resorts.gd -- --fresh-geodata`.
Piste end points may move up to 25 m to dock outside terminal machinery;
`source_points` retains the unmodified contiguous original line. Runtime
network nodes are restricted to junctions and end points of imported ways;
the full line is retained for physical movement and rendering.
Generated pedestrian access, plazas and service buildings are game additions.
Imported piste difficulty uses OSM tags where available; missing values use
the terrain model. Inventory numbers are linked sections, not official totals.
