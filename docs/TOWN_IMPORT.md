# Real town and transit source extraction (issue #10)

This stage imports real town geometry and, starting with the 0.20 source,
renders streets and true OSM POI positions in a separate **decorative**
3D village layer. It also illustrates one fictional SkiZones shuttle
per area on connected roads. **It is not yet a passenger transport or
official bus service.** Earlier piste/lift/terrain extracts remain
separate and must not be modified.

## Reproducible execution

From the repository root:

```sh
python3 tools/import_town_geodata.py --region braunlage
python3 tools/import_town_geodata.py --region filzmoos
python3 tools/import_town_geodata.py --region kitzbuehel
python3 tools/import_town_geodata.py --region seiseralm
python3 tools/import_town_geodata.py --offline
python3 tools/build_town_network.py
python3 -m unittest discover -s tests -p 'test_town_*.py'
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
- The 0.20 development source renders street meshes, hotels/food/transit
  markers and limited real-name labels, while leaving construction,
  savegames and collision behaviour unchanged.
- The generated graph preserves one-way restrictions, bus-capable versus
  pedestrian edges and bounded nearest-stop access. It also describes a
  **fictional** bidirectional SkiZones shuttle, only if connected real
  streets and stops permit one. This is never an official route.
- The first visible SkiZones bus follows the simulation clock. Passenger
  boarding, realistic local bus timetables, staffing, economic effects,
  full guest itineraries, accurate building footprints and full town
  coverage still require separate implementation and Android QA.
- Never import external official logos, invent missing map features,
  or automatically refresh and change pinned map data at runtime.

**Licence:** © OpenStreetMap contributors; Open Database License 1.0
([ODbL](https://opendatacommons.org/licenses/odbl/1-0/)) and
[OpenStreetMap attribution](https://www.openstreetmap.org/copyright).
Additional upstream source restrictions must be reviewed for any future
non-OSM data.
