# SkiZones 0.42 integration candidate

This branch combines rescue routing (#110), piste-side NPC visits and habits (#111), twenty-module snowparks (#112), the interactive employee academy and arcade (#113), and Android error evidence (#114).

## Verified evidence

- Academy final head d2b6335e: 476 targeted checks passed under Godot 4.5.2; 24 UI captures reviewed.
- Full Android run 43441167535 passed model, historic-save, recovery, export/signing and Android API 30 and 36 lifecycle jobs. This was not a physical Samsung acceptance.
- Subsequent full run 43442632998 failed Android API 36. The recorded engine failure was in OpenSL audio startup. Therefore the preceding success is insufficient evidence of a fixed startup problem.
- Native startup is still a release blocker. Keep the strict engine-error acceptance condition; do not suppress the audio error or describe it as fixed.

## Integration

The latest main branch at 6467c85e contains two newer download-information blobs. Both are preserved verbatim in this integration merge, alongside all implementation changes. This branch is a single reviewable candidate against main; the existing component pull requests remain intact.

## Remaining release conditions

- Reproduce and fix the intermittent Android 36 audio initialization failure.
- Run the complete final-head pipeline on this integration branch.
- Verify version name/code and upgrade compatibility before producing a 0.42 public release; current inherited application version is still 0.41.1.
- Physical Samsung touch/audio/resume and sustained performance acceptance remain outstanding.
- No stable-release or overall completion-percentage claim follows from this integration.
