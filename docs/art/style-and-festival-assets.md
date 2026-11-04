# SkiZones – Theme architecture and winter festival assets

Status: VERIFIED for the theme/festival asset scope shipped in v0.32.0. Evidence checked 4 November 2026.

## Verification evidence

- PR #40 was integrated through PR #38; the published [v0.32.0 ARM64 APK](https://github.com/chekento/SkiZones/releases/tag/v0.32.0) remains available.
- [Release pipeline 41884145451](https://github.com/chekento/SkiZones/actions/runs/41884145451) completed successfully: Godot, original career recovery, Android API 30 and 36 lifecycle/in-place-update checks and APK publication.
- [Asset run 41856228685](https://github.com/chekento/SkiZones/actions/runs/41856228685) at 46c62b8 passed 71 model/catalogue/persistence, 71 rendered placement/festival/grayscale and 33 style/terrain/settings checks. Ten festive world views, three catalogue views and New Year were visually compared; monochrome and New Year were also viewed at original resolution.
- The same 71 + 71 + 33 assertions pass again in [0.33 asset run 41912800661](https://github.com/chekento/SkiZones/actions/runs/41912800661). This does not authorize publishing 0.33 before its complete release gates pass.
- Scope limits: the four purchased buildings are decorations, not simulated new businesses. Render test shutdown still reports resource allocations; this is not a clean Android memory profile. A separate 0.33 arcade label/background contrast defect is tracked in [#47](https://github.com/chekento/SkiZones/issues/47); it is not covered by these asset assertions.

## Scope and acceptance

- All ten named themes must produce distinct building and lift-station geometry, not palette swaps alone. Existing Alpine models remain the original reference.
- Monochrome uses sparse line houses, stations, trees and icon drawings; a reversible screen filter removes color hues from the remaining world and interface. It must remain selectable and persistent.
- Building and lift icons reuse actual theme meshes. Existing assets, terrain vertices, transforms, lift capacity and saved game state must survive style changes and cancelled previews.
- December adds original roof garlands, wreaths and stars to every real building without adding gameplay obstacles. November remains the advertisement preview. New Year uses the existing calendar and silent fireworks.
- Four new festive decoration buildings are purchasable with existing winter coins: gingerbread lodge, gift workshop, market stall and New Year stage. They are decorative seasonal architecture; they do not claim simulated production, restaurant service or staff jobs. December purchases persist; the stage appears at New Year.
- Seasonal placement must avoid real buildings, piste corridors, lifts and footpaths. Festival archive changes must not change career saves.
- Headless mesh/catalogue/persistence tests, rendered real-world tests, pixel grayscale checks, screenshot review, and existing visual-style compatibility tests must pass before integration.

## Follow-up runs

Read the latest repository and PR status before changing anything. A live PR with this scope indicates ongoing work; do not duplicate it or overwrite branch heads. Finish concrete defects first. Do not publish an APK before all release checks are green. Keep this document's VERIFIED status tied to the evidence above. The user has extended the ongoing release work to 0.33 weather, nights, touch games and the Town Hall roadmap; asset verification alone does not complete that broader task. Any later functional holiday businesses require their own NPC, staffing and balancing design; never relabel these decorative models as completed gameplay systems.
