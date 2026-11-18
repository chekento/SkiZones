# 0.43 development: mixing, ring toss and shift journal

Current candidate, not merged and not an APK release. Public release remains 0.42.0.

- Bar and disco: three ingredient drags, six sideways shakes, hold/release to pour, garnish drag, serving drag. Uses the actual mocktail offer unlock (bar level 2, disco level 3), the existing five-task shift, and its shared three rewarded shifts per day. No extra sales or save fields.
- Sweet stand: donut ring toss at the existing level-3 donut offer. Five ballistic throws, preview trajectory, descending peg hits and bounded points. Fixed 120 Hz simulation; no model reference, stakes or rewards. Focus loss cancels the unfinished throw without consuming it.
- Shared journal reads actual daily reward count, remaining rewarded shifts, best score and current service bonus. Stale daily figures are suppressed without mutating saves.
- Town Hall distinguishes the two integrated packages, these three locally tested candidates, and the unimplemented Google translation integration. German/English remain the current supported app languages.

46 new local Godot 4.5.2 assertions passed, including reward limits, real unlocks, failed/cancelled interactions, save restoration, fixed-step physics, exact real resort snapshot preservation, actual building UI and viewport-dispatched touch/drag inputs at 390×844 and 844×390. Rendered screenshots, final CI and integration are outstanding; headless tests alone do not prove appearance or physical Samsung acceptance.

Google Cloud Translation requirement: build/prepare validated language catalogs, preserve formatting placeholders and game terminology, store translations for offline use, expand device-language selection and manual fallback, then verify layout and language switching. No Google API connection or credentials configured. Official setup: https://docs.cloud.google.com/translate/docs/setup .

Progress reporting uses explicit status gates, not hours: open 0%, implementation 50%, local validation 75%, accepted and integrated 100%. These six currently tracked packages have two integrated completions (2/6 = 33% by package count). This is not the completion percentage of the entire historical Town Hall roadmap or the full 0.43 release.
