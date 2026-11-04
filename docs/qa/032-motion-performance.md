# Motion performance refinement after the 0.32 release candidate

Implementation is prepared for review; it is not part of the currently running 0.32 release candidate until this branch is integrated and its rendered/Android checks succeed.

- Ground triangle coordinates and height planes are prepared once per mesh. Query points use local triangle coordinates to preserve precision on real maps tens of kilometres from the origin. No triangle polygons are allocated for moving-guest height queries.
- Lift rendering evaluates cable geometry, vehicle schedule and running state once per visible lift per frame. Each carrier still uses the same Fleet.pose function as simulation and passenger seating.
- 19 exactness checks pass: both triangle windings, interior points, shared edges and vertices, independent cached offsets, fallback, clipped snow geometry, distant map coordinates and mesh replacement.
- A paired headless comparison over 6,000 uncached points returned approximately 79 ms for the previous height lookup and 30 ms for the new lookup; maximum positional discrepancy was 0.000004 m. This measures one CPU routine, not Android FPS.
- Imported real-scenario starter facilities now cache the unmodified lift stations and piste segment endpoints once and use a conservative ±30 m rectangular broad phase before their original precise 30 m segment-distance check. This avoids repeated geodata point unpacking while preserving the previous site-ordering and 30/50/60 m setbacks. The new Braunlage in-memory re-siting regression checks actual terrain slope, building spacing, lift station spacing and exact segment distance. No save is rewritten. CI timing is still pending; no startup-speed or Android-FPS improvement is claimed yet.
- The existing full scene and Android gates remain mandatory. Dummy headless rendering does not preserve MultiMesh vehicle transform reads, so the rendered vehicle-motion assertion must run with the CI virtual display.
- The diagnostic route inventory in 032-route-coverage.md records the remaining full-circuit gaps in imported real scenarios. It is not an all-pistes pass.
