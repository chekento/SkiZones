# 0.33 integration validation

Status: **candidate only**, not a published APK. Public version remains 0.32.0.
Local checks on 4 November 2026 use the official SHA-512-verified Godot 4.5.2
Linux editor. Rendered tests use Mesa software rendering, not an Android phone.

## Combined behavior checked locally

| Suite | Passed | Coverage |
|---|---:|---|
| `quiet_night_033.gd` | 63 | Safe walking, real visits, incident/queue exclusion, bounded dawn interest, ten consecutive midnight accounts and saves, morning staggering and expiry |
| `weather_distribution_033.gd` | 15 | 32,000 simulated days: 2,024 storms (6.325%), zero consecutive storms; existing weather and safety thresholds retained |
| `tic_tac_toe_033.gd` | 112 | Rules, legal AI moves, outcomes, new rounds and real button controls |
| `arcade_mobile_scene_033.gd` | 50 | Actual screen-touch events in the building at 360×740, 420×860 and 740×360; DE/EN, Android Back handler, pause, unchanged save/economy, actual interest shown in the office |
| `pacing_and_nights.gd` | 17 | Partial-minute saves, deterministic continuation, real extended nightclub visits and dawn departure |
| `operating_nights.gd` | 30 | Existing overnight operations regression |
| `family_holidays.gd` | 16 | Five actual family members, hotel capacity/billing, guardians, sleep, save/load and morning routes |
| `editorial_townhall_031.gd` | 43 | Published civic history, updated planning phases and editorial state |

Project import and compilation complete without script errors. The localization
checker verifies **2,312 messages**, placeholders and source coverage.

The phone test first exposed viewport resize callbacks firing on the old HUD
between language replacement and deferred deletion. Attached-tree guards and a
named office resize handler fix that case; the repeated rendered test has no
script errors and all 50 assertions pass. The rendered full-scene process still
reports renderer/resource allocations at shutdown; these are not evidence of a
clean memory profile and must not be described as an Android memory test.

Screenshots are produced in the workflow's `build/qa/` artifact, including
`arcade-033-de-360x740.png` and `arcade-033-en-420x860.png`.

## Required before publication

Run the full combined CI at the final candidate SHA, including original 0.19
and 0.27 career fixtures, all rendered/route/finance suites, signed APK export,
Android API 30/36 lifecycle and in-place update preservation, and signature and
download/manifest checks. Local test counts do not authorize a claim that these
device or release gates already passed. No physical ARM64 device was tested.
