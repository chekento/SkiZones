# Motion performance refinement after the 0.32 release candidate

Implementation is prepared for review; it is not part of the currently running 0.32 release candidate until this branch is integrated and its rendered/Android checks succeed.

- Ground triangle coordinates and height planes are prepared once per mesh. Query points use local triangle coordinates to preserve precision on real maps tens of kilometres from the origin. No triangle polygons are allocated for moving-guest height queries.
- Lift rendering evaluates cable geometry, vehicle schedule and running state once per visible lift per frame. Each carrier still uses the same Fleet.pose function as simulation and passenger seating.
- 19 exactness checks pass: both triangle windings, interior points, shared edges and vertices, independent cached offsets, fallback, clipped snow geometry, distant map coordinates and mesh replacement.
- A paired headless comparison over 6,000 uncached points returned approximately 79 ms for the previous height lookup and 30 ms for the new lookup; maximum positional discrepancy was 0.000004 m. This measures one CPU routine, not Android FPS.
- The existing full scene and Android gates remain mandatory. Dummy headless rendering does not preserve MultiMesh vehicle transform reads, so the rendered vehicle-motion assertion must run with the CI virtual display.
- The diagnostic route inventory in 032-route-coverage.md records the remaining full-circuit gaps in imported real scenarios. It is not an all-pistes pass.
