# Real town and transit source extraction (issue #10)

This is a **development-only data ingestion step**, not a finished bus service
or populated town in the Android game. The current releases use separate pinned
piste/lift/terrain extracts under `assets/geodata/`; do not alter those files.

## Reproducible execution

From the repository root:

```sh
python3 tools/import_town_geodata.py --region braunlage
python3 tools/import_town_geodata.py --region filzmoos
python3 tools/import_town_geodata.py --region kitzbuehel
python3 tools/import_town_geodata.py --region seiseralm
python3 tools/import_town_geodata.py --offline
python3 -m unittest discover -s tests -p test_town_geodata.py
```

- Default coverage is a **2.4 km radius around the existing entry-station
  coordinate**. It is an initial town centre, not the whole municipality or
  the entire ski area. Specify `--radius-m N` for a broader, reviewed area.
- External Overpass requests occur only if the pinned source is missing,
  or when `--refresh` is explicitly requested. An existing cached response
  with a different query fails rather than silently mislabelling provenance.
- Results retain OSM type, ID, tags, nodes and metre-coordinate geometry,
  plus timestamp, SHA-256, query and ODbL attribution.
- A real road or bus stop is **not** evidence of an official bus route,
  timetable, active operator, or permission to use an operator's logos.
- `towns/source/` holds raw source responses and exact queries; top-level
  `towns/<region>.json` contains derived, reproducible features.
- The extractor does not generate fictional hotels or restaurants.
  Missing information is reported as missing.
- Data is not bundled into gameplay yet. Before shipping, create an
  appropriately licensed rendered street/POI layer, route graph, sensible
  walkability and bus agent, LOD, real collision avoidance, migration tests,
  Android performance tests and updated in-game credits.

**Licence:** © OpenStreetMap contributors; Open Database License 1.0
([ODbL](https://opendatacommons.org/licenses/odbl/1-0/)) and
[OpenStreetMap attribution](https://www.openstreetmap.org/copyright).
Additional upstream source restrictions must be reviewed for any future
non-OSM data.
