# 0.42 skier contact and climbing

## Visible correction

The old render sampler let climbing guests follow a personal carving wave even though the simulation had placed them on the piste centerline. It also used the guest's ski ability when adding park height during a climb. Downhill tilt sampled only terrain and module height, omitted local snow relief, and reused the central lateral coordinate for the front/rear samples of rotated obstacles.

`src/world/skier_pose_042.gd` now samples all three contact points against the actual triangulated ground, snow height and skill-appropriate park height. Each point uses its own lateral coordinate. Climbers follow the simulated centerline, without carving lean, side-to-side heading or park elevation. Empty personal profiles correctly fall back to the leg's legacy motion data. The view uses the same climb-state decision for its mesh/equipment bucket. Samples near split-leg endpoints remain inside that leg.

The renderer still uses its staggered 0.12-unit interpolation cache. No new nodes, meshes, physics, random draws or save fields are introduced. The helper is intentionally rendering-only; it does not change NPC routes or award module usage.

## Reproduction and local validation

Pinned official Godot 4.5.2 Linux binary, checked against the official SHA-512 manifest, 15 November 2026:

- The first 22 assertions against the extracted old shipping sampler produced **12 passes and 10 failures**. The fix passed all 22; extended regression now passes **29/29**.
- `skier_surface_pose_042.gd`: 29/29, actual triangulated plane, all three sports, hiking, legacy fallback, snow-only gradient, rotated module contact, beginner bypass, split endpoints, pause determinism and unchanged snapshots.
- `winter_sports.gd`: 16/16, mixed sports and deterministic actual save/reload. Run with `--language de`, as in CI; its existing localized style-name assertion expects German text.
- `snowpark_modules_042.gd`: 202/202, actual installation of twenty models, safe bypass, usage, wear, accounting and saves.
- `ski_traffic.gd`: 16/16, lane separation and congestion.
- `lift_reentry_042.gd`: 11/11, real scene graph, MultiMesh and camera reentry. This compiles and constructs the view that calls the new sampler.
- `crowd_stress_042.gd`: 8/8, 250 actual concurrent visitors, 104 ticks over 1x/4x/8x. Local simulation mean 13.115 ms per tick, worst 30.398 ms. These are simulation CPU values, not renderer or Samsung FPS.

Total: **282 local assertions passed**. Tests with strict engine-error rejection were used throughout.

## Cost and remaining acceptance

A local same-process comparison of 250 uncached pose calculations was slower with the more accurate snow/contact sampling: after warmup the old sampler took 16.3–19.7 ms per batch, the new sampler 20.1–22.2 ms. This small synthetic probe has no release threshold and is not a complete frame-time measurement. Retained staggered caching reduces how often exact samples are calculated, but physical Android performance still needs acceptance.

Focused CI and the mandatory full Android pipeline include the new regression. Their final-head results remain required. This change does not establish visual quality or performance on Samsung, fix the separate native OpenSL/shader-cache problems, or publish a 0.42 APK.
