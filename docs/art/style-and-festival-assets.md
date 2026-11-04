# SkiZones – Theme architecture and winter festival assets

Status: IMPLEMENTED_PENDING_VALIDATION. Target: 0.32 feature branch.

## Scope and acceptance

- All ten named themes must produce distinct building and lift-station geometry, not palette swaps alone. Existing Alpine models remain the original reference.
- Monochrome uses sparse line houses, stations, trees and icon drawings; a reversible screen filter removes color hues from the remaining world and interface. It must remain selectable and persistent.
- Building and lift icons reuse actual theme meshes. Existing assets, terrain vertices, transforms, lift capacity and saved game state must survive style changes and cancelled previews.
- December adds original roof garlands, wreaths and stars to every real building without adding gameplay obstacles. November remains the advertisement preview. New Year uses the existing calendar and silent fireworks.
- Four new festive decoration buildings are purchasable with existing winter coins: gingerbread lodge, gift workshop, market stall and New Year stage. They are decorative seasonal architecture; they do not claim simulated production, restaurant service or staff jobs. December purchases persist; the stage appears at New Year.
- Seasonal placement must avoid real buildings, piste corridors, lifts and footpaths. Festival archive changes must not change career saves.
- Headless mesh/catalogue/persistence tests, rendered real-world tests, pixel grayscale checks, screenshot review, and existing visual-style compatibility tests must pass before integration.

## Follow-up runs

Read the latest repository and PR status before changing anything. A live PR with this scope indicates ongoing work; do not duplicate it or overwrite branch heads. Finish concrete defects first. Do not publish an APK before all release checks are green. After the scope above is integrated and verified, mark this document VERIFIED with evidence and pause the festive-assets automation. Any later functional holiday businesses require their own NPC, staffing and balancing design; never relabel these decorative models as completed gameplay systems.
