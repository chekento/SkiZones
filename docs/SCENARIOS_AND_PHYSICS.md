# SkiZones · Real Resort Scenario Lab (design + first diagnostic implementation)

## Scope

Real resorts are **not shipped** with this change. Filzmoos, Seiser Alm and
Kitzbühel exist as `pending_licensed_import` concepts only. The scenarios are
explicitly fictional **what-if simulations**, not statements about actual lift
reliability, visitor queues or management at the named real resorts.

The first implementation adds read-only operating analysis to the Resort Office:
actual simulated queue lengths, nominal hourly capacities, a calculated
queue-clearance time, ranked bottlenecks and reachable pistes. These numbers use
the guests and assets already in the simulation; no queue is invented.

## Scenario engine blueprint

Each scenario requires:

1. A licensed elevation raster with horizontal/vertical reference, datum,
   geographic extent, resolution and full attribution.
2. Independent lift/piste geometry, junctions, lift type, direction,
   usable access and source timestamps. Preserve original OSM identifiers.
3. A coverage audit against separately accessible official inventories **for
   reference only**. Do not reproduce copyrighted piste-map artwork.
4. An import pipeline that projects data into stable game metres, produces
   simplified Android LOD meshes, caches route graphs and validates ski/lift
   topology without changing native terrain heights.
5. A **fictional** initial operating condition, budget, objective thresholds,
   time limit, severity, initial queues, configuration and deterministic seed.
6. Save format supporting scenario ID, source manifest checksum, objective
   progress, completion timestamp and independent scenario save slots.

Rules: no official endorsement, no fabricated claims of real-world operational
failures; provide clear geographic-data attribution and link to source licences.

## Diagnostics and units

The Resort Office shows:

- Live number of waiting guests by lift.
- Manufacturer/catalogue **nominal** lift capacity (persons/hour), which is a
  theoretical figure, **not measured throughput**.
- Nominal queue clearance estimate = waiting guests / (nominal persons/minute).
  It excludes new arrivals, wind stoppage, carrier seat occupancy and access
  restrictions; this is explicitly not a promise of actual wait.
- A threshold warning at 8 minutes and an urgent signal at 15 minutes.
- Actual recent carrier fill from model data and reachable piste count.

**Important physics debt:** `Fleet.TIME_SCALE = 30` currently stretches
internal carrier phases and `advance_minute` increases `lift.clock` by only
one unit per game minute. Hence observed game-clock clearance, ride times and
nominal lift capacities cannot yet be treated as physically consistent.
Correct this in a dedicated save-migration + deterministic regression task;
do not silently alter published save timing. Similarly skier physics uses
specific energy and snow/turn speed caps but has not been independently
calibrated against realistic descent times. Neither should be advertised as
verified original-physics yet.

## Next implementation milestones

- Import Filzmoos as first topology/elevation fixture using approved geodata.
- Align skier, lift and pedestrian motion with a documented **single simulation
  timebase**, then interpolate rendered movement independently from simulation
  ticks; test 1x and 4x for identical simulated outcomes.
- Replace the provisional queue-clearance formula with rolling actual boarded
  passengers/minute, effective operating time and a queue forecast, retaining
  the nominal estimate separately.
- Add editable scenario objectives with sliding windows (e.g. keep peak wait
  below threshold for 3 consecutive ski days), savings independent of career,
  fair scoring and before/after metrics.
- Add skier-specific fall risk, braking and safe lateral separation, conditional
  on snow state, visibility, fatigue, piste crowding and individual skill.
- Add independent congestion heatmaps at lift entry, footpaths, junctions and
  piste exits, with a scalable, deterministic spatial occupancy grid.

## Sources and licensing checkpoints

- OpenStreetMap ODbL: https://www.openstreetmap.org/copyright
- OpenSnowMap OSM extracts: https://www.opensnowmap.org/iframes/data.html
- OpenSkiData: https://www.openskidata.org/
- Copernicus DEM terms / national elevation-source terms to verify before use.

Do not package official piste-plan images or blindly import a third-party
combined dataset without separately checking every upstream source's rights.
