# 0.42 modular snowpark — implementation and acceptance

Development package stacked on the piste-side NPC visits in PR #111.
No stable release, physical Samsung approval or Android FPS claim.

## Implemented and locally verified

- [x] 20 distinct meshes and surface profiles, up from the original three:
  small ramp, beginner rail, roller, medium/pro kicker, table, step-up/down,
  down/kink/rainbow rail, box, tube, funbox, wallride, whoops, quarterpipe,
  halfpipe, spine and transfer. Original three IDs remain valid.
- [x] Shared dimensions for world geometry, riding height and placement.
  New modules fit within measured footprints; each uses one baked surface.
- [x] Rotation from −45° to +45° and uniform size from 70% to 140%, persisted
  with the module. This is not independent width/height/pitch editing.
- [x] Longer approach/landing clearances, footprint-based spacing, clear
  bypass, existing terrain-grade and bend validation. Full physical collider
  and swept-volume validation remain separate work.
- [x] Skill-specific bypasses, including intermediates avoiding pro modules.
  Worn-out modules are avoided; poorly maintained modules add a small actual
  incident chance on use. Meshes use the game's existing kinematic movement.
- [x] Actual skier traversal increments use, wears the module, improves joy
  and advances an expert's park experience. Drawing does not duplicate usage.
  Expert route preference and real accessible park supply use module appeal.
- [x] Daily upkeep is included in actual resort operating expenses. Service
  restores condition with a real, labelled piste cost-centre expense.
  Changing a cheap module to a costly one pays the price difference.
- [x] Real finger/mouse positioning in the mini-plan, rotation/size previews,
  selection, relocation, duplication preview and confirmed independent copy.
  Parent scrolling cannot steal a drag begun in the mini-plan.
- [x] German/English workshop at 360×740, 420×860 and 740×360; long German
  labels wrap so the close button remains reachable.
- [x] All 20 kinds survive checked JSON saves; malformed size, rotation, wear
  and coordinates reject atomically. No rewriting authored piste points.

## Still open before release acceptance

- [ ] Final-head pinned Godot 4.5.2 CI and Android API 30/36 update/lifecycle.
- [ ] Review real renderer captures, every theme, physical Samsung touch/FPS.
- [ ] Multi-day/winter crowd benchmark with many occupied new modules,
  explicit per-device CPU/GPU/memory budget and any required LOD/batching.
- [ ] Remaining #106 editor scope: grid/snap, independent dimensions/pitch,
  full swept obstacle/landing validation, undo/redo and broader park balancing.

The checked implementation items above are not an overall percentage of 0.42.
The main release blockers in #105 and the complete scope of #109 stay open.

## Local evidence

Godot 4.6.3, 2026-11-13:

| Check | Result |
| --- | --- |
| `snowpark_modules_042.gd` — real installation, distinct geometry, profiles, saves, costs, traversal and maintenance | 202 passed, 0 failed |
| `snowpark_workshop_042.gd` — real touches, six phone/language layouts, world preview and confirmed duplication | 52 passed, 0 failed |
| `landscape_rhythm.gd` — original three modules, old saves, pacing and night safety | 37 passed, 0 failed |
| `compile_sensitive_032.gd` — main/controller/UI dependency graph | 8 passed, 0 failed |
| `snowpark_crowd_042.gd` — 180 admitted guests, four real modules, 720 calendar minutes at 1×/4×/8× batching | 16 passed, 0 failed |
| Translation placeholders and source coverage | 3,210 messages verified |

The crowd checkpoints were identical across all three playback batches:
66 actual module uses, all 180 guests departed. Simulation work took about
2.1–2.4 seconds per twelve-hour run on this executor; this is not a per-frame
or Android GPU benchmark. Far-away module profiles are rejected before
surface calculations; rotation trig is cached outside persisted game state.

`snowpark_gallery_042.gd` builds a labelled synthetic comparison display from
the actual meshes. CI captures it and the six real workshop screens in
`snowpark-042-visual-QA`. Headless geometry/input tests are not visual review.
The GUI harness also exposes pre-existing HUD shutdown resource warnings;
no clean long-running-memory acceptance is inferred from its pass count.

Tests are part of `.github/workflows/snowpark-042.yml`; model and mobile
workshop checks also run before Android export in `validate-and-build.yml`.
