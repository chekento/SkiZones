# Migration fixtures

These deterministic snapshots were written by the unmodified SkiZones 0.4.0
simulation at commit `cc360c5304058b9060c434fa86f1063b567bde69`.
They contain generated test visitors, no player data.

- `v0.4-starter.json`: the starter resort after 100 operating minutes.
- `v0.4-junctions.json`: the blue route and red/black shortcuts used by the 0.4
  rendered showcase, after 40 initial visitors and 180 operating minutes.

The fleet/plaza suite checks migration of existing investments and visitors,
followed by a new-format save round trip. Test files are excluded from APKs.
