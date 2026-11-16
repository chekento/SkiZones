# Hands-on housekeeping and current Town Hall

Implemented for the next update, not part of the published 0.42 APK.

Hotel → Rooms & Guests → select a vacant dirty room. Three pickups, three matching linen drags and three actual wiping gestures prepare the room. The confirmation button calls the existing room-cleaning operation. It costs exactly €8 in career mode, changes the actual selected room and adds no reward, experience or new save fields. Existing free-build semantics remain. A closed room remains closed after cleaning.

Wrong drops, taps without wiping, off-canvas jumps, secondary fingers and backgrounded unfinished gestures cannot complete a task. Closing/rebuilding the page discards transient progress without charges. Before committing, current hotel availability and room occupancy/cleanliness are rechecked. Existing reservation and affordability safeguards remain authoritative.

Town Hall: published 0.42 chronicle added, current progress shown before historical phases, calendar phases explicitly cease to be earliest implementation dates. Cooking and mixing remain open. The new room interaction is labelled implemented/testing for the next update, not already released.

Pinned Godot 4.5.2 local checks: 26 housekeeping/actual UI assertions, 28 existing room-operation checks, 24 hotel simulator checks and 44 editorial/Town Hall checks passed (122). Includes phone widths 390/844, real room cost, duplicate confirmation, budget failure, stale-room rejection, save restoration and cancellation. Translation coverage: 3,471 messages. No claim of rendered screenshot or physical Samsung acceptance follows from headless tests.

Focused workflow additionally renders the actual room page at phone and landscape dimensions, uploads screenshots, and retains existing hotel/Town Hall regressions. Full Android pipeline includes housekeeping as a mandatory test. Final CI and rendered inspection remain required before integration/release.

The shipping viewport dispatch is tested through the real room page. The housekeeping canvas registers as a gesture exclusion in ancestor drag-scroll containers, so bed-making and wiping are not stolen by page scrolling.
