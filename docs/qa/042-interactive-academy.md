# 0.42 interactive staff academy and games

Stacked on PR #112, with NPC piste-side visits and rescue route fixes beneath it.
This is a development package, not a stable release or device acceptance.

## Implemented

- A dedicated scenario for each of the 28 existing employee professions,
  plus four contextual priority cases and a handover case. Each course has
  three decisions: professional practice, priorities and a shift handover.
- Select an actual assigned employee in building training or the new Academy
  tab of the building/lift team panel. The lift roster covers the real stations
  of its linked line. Empty teams receive an actionable hiring explanation.
- After each choice, read the appropriate action and its explanation before
  explicitly continuing. No automatic disappearance of the feedback.
- Persistent individual experience: correct decisions earn up to 36 XP/course;
  qualification 2 at 100 XP, qualification 3 at 240 XP. No cash prize, invented
  guest visit or sales event. Motivation receives a small bounded improvement.
- Two paid attempts per person/day, €90 charged at the start and recorded in
  an identified training cost centre. Free build pays no fee. Cancellation uses
  the disclosed attempt without awarding experience. Starting again supersedes
  the older session; settled serials prevent duplicate completion awards.
- Qualifications feed the existing real on-duty service ledger. Technical and
  electrical qualifications also speed actual workshop work orders, capped at
  15%. Required team presence still blocks work during breaks or absence.
  Lift physical capacity and rescue treatment deadlines are not increased.
- Optional bounded training fields validate atomically with saves. Old saves
  do not need these fields. Employee removal, reassignment, a changed day or
  a newer course invalidates an unfinished course.
- Training pauses resort time. Hiding the training cancels it and releases
  only the pause it owns; closing an enclosing building retains the correct
  parent pause behaviour. Active rescue workers cannot start a course.
- Arcade selector for tic-tac-toe, reaction and the new Mountain Pairs game.
  Pairs has 4/6/8 pairs, real shuffled boards, matching and mismatch feedback,
  local round bests, no third-card peeking, no wager and no time limit.
- Reaction timing reads monotonic time at the actual button press. Background
  notifications cancel an active timed round without recording a false score.
- Existing business decisions now retain their feedback until continued;
  timed tasks stop advancing while their tab is hidden.
- German/English messages and phone-oriented, wrapping touch controls.

## Verification

Godot 4.6.3 local model checks: 211 passed, 0 failed. Includes all professions,
real fee accounting, replay rejection, earned levels across days, actual
save/restore and atomic malformed-save rejection, service duty bonuses,
actual repair progression and absent-worker blocking, and pair game rules.
Existing professional rescue: 44 passed. Existing expansion UI: 28 passed.
Localization: 3,416 messages, complete placeholders and source coverage.

`interactive_academy_scene_042.gd` exercises actual screen-touch events and
the full scene in DE/EN at 360×740, 420×860 and 740×360. Renderer captures are
uploaded by `interactive-academy-042.yml` using pinned Godot 4.5.2.
Final-head CI and visual acceptance must be recorded in the pull request.
The existing HUD test harness emits shutdown RID warnings; these counts are
not evidence of long-running memory stability.

## Release work still open

- Physical Samsung touch, audio, resume and long-running performance checks.
- Full Android API 30/36 final-head validation; no release based solely on the
  training tests. The preceding full build's API 30 job passed, API 36 failed:
  https://github.com/chekento/SkiZones/actions/runs/43340092559
- The API 36 artifact identifies an OpenSL audio startup error, rather than
  a script assertion or a confirmed renderer fault. AudioFlinger reports
  `NPC::getPackagesForUid: uid not found: 10216` at 01:37:53.734, the Godot
  OpenSL `start` error follows, then `updatePackagesForUid` registers that UID
  at 01:37:53.743. A package/audio registration race is a hypothesis to verify;
  no engine-driver fix or blanket exception in the acceptance gate is claimed.
- More varied practical interactions beyond these decision courses, broader
  hotel/ski-school scenarios, economy balancing and the other 0.42 core work.
  These changes do not mean the whole 0.42 scope is complete.
