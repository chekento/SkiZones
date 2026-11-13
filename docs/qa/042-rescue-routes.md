# 0.42 rescue routes — development evidence

New dispatches plan a complete round trip before charging consumables. The
loaded stretcher follows downhill ski and pedestrian edges to the clinic;
it no longer reverses an ascending tow lift. Travel uses the calendar clock
scale. Old rescue records without return geometry remain loadable.

Completed, unreferenced incident history can be recycled at the 100-record
limit without removing an active case or a legacy evacuation witness.
The station panel distinguishes response, transport, treatment and blocked
dispatch; a disconnected case can be retried after restoring its connection.

Local Godot 4.6.3 headless verification, 2026-11-13:

- `tests/rescue_routes_042.gd`: 23 passed, 0 failed. Actual full-duration
  dispatch and 120-minute treatment, continued from restored transport and
  treatment snapshots; bad geometry, blocked return, retry and history cap.
- `tests/professional_rescue_041.gd`: 44 passed, 0 failed.
- `tools/check_localization.py`: 3,180 source messages verified.

These results do not establish Android FPS, physical Samsung acceptance,
all historical-release save compatibility, or 0.42 release readiness.
Pinned Godot 4.5.2 CI, Android and physical-device checks remain required.
Related: #105 and #109. No version bump or APK publication in this patch.
