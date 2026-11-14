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
- Verify version name/code and upgrade compatibility before producing a 0.42 public release.
- Physical Samsung touch/audio/resume and sustained performance acceptance remain outstanding.
- No stable-release or overall completion-percentage claim follows from this integration.


## Integration update, 2026-11-14

Early goals and the NPC personality update from #117 are now included, as is unlimited free academy practice from #116. Economic bonuses arrive after the first and third profitable day. Ready goals are listed first, early active goals next and settled goals last.

Full run 43509601663 on the previous goals head passed, including Android API 30 and 36. This does not prove that the earlier intermittent OpenSL startup failure is fixed. The standalone snowpark UI run 43509602022 timed out while rendering the background resort; the UI script now disables background 3D rendering, just like academy UI QA. It still checks actual touch events and preview transforms. The separate twenty-model gallery retains real 3D rendering. Final-head validation is required again.

The latest two download-information blobs from main are preserved. No public release is performed by this integration.

## Versioned candidate, 2026-11-14

Full integration run 43610431287 on 530109e9383a12378d5b51f3d15e3c25785c8fc7 passed all required jobs, including historic saves, career recovery and Android API 30/36. Separate goals/NPC and snowpark runs passed 144 and 357 targeted checks. These successful runs do not demonstrate that the intermittent OpenSL failure is fixed.

The project and both Android presets now declare 0.42.0 / code 57. A shared pre-export and pre-package guard rejects stale lifecycle version names, divergent codes and invalid Android version codes. Eleven regression tests cover source consistency and compiled APK identity, including stale APKs, wrong package names and incorrect architectures. Before copying the APK into release downloads, aapt2 must confirm its actual package, version name, version code and ARM64-only architecture. The private lifecycle update fixture remains allowed to increase its code after source validation.

The final versioned head must pass the full pipeline again. Release notes are prepared in docs/releases/0.42.0.md and explicitly describe an unpublished candidate. Public download files and banners still point to the published version; do not advertise a nonexistent 0.42 download. Native audio startup and physical Samsung acceptance remain open.
