# 0.32 route coverage audit — 4 November 2026

This is a diagnostic inventory, not a completed all-pistes release gate.

Reproduce with `godot --language de --headless --script tools/audit_scenario_routes.gd`. Use `-- --map=braunlage` to inspect one map. Every map starts from the existing seed, at 10:00 in calm weather, with all lift stations staffed and lift faults repaired. No source geometry or player files are changed.

The count requires a route from the actual resort entrance to the **start of the full piste**, the complete descent, and a return to the entrance. A missing full circuit does not prove that every segment of that piste is unusable: parts may occur in another circuit.

| Seed | Pistes | Full return circuits | Closed in source seed | No full circuit |
| --- | ---: | ---: | ---: | ---: |
| Eight normal starting resorts combined | 8 | 8 | 0 | 0 |
| Braunlage | 26 | 21 | 0 | 5 |
| Filzmoos | 25 | 12 | 0 | 13 |
| Kitzbühel | 448 | 219 | 2 | 227 |
| Seiser Alm | 146 | 96 | 0 | 50 |

These results use the unchanged imported geometry in commit 57a63fc. The existing scenario checks establish playable circuits for all three guest abilities; they do **not** establish full imported-piste coverage. Complete real-scenario connectivity remains open. Further work must identify separate sectors, source gaps, station access and genuine short transitions, then verify each added connection against terrain and machinery.

An experimental 10 m centerline join increased Braunlage to 23 circuits, but its two new connections failed the existing pedestrian obstacle checks. That experiment was discarded. The source geometry and routing tolerance remain unchanged.

Before describing all real pistes as fully connected, repeat this inventory and add regression coverage for every repaired connection. The two originally disabled Kitzbühel seed runs also require an individual geometry/dynamics review.
