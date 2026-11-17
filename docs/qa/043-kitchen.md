# Practical kitchen and current Town Hall

Implemented for the next update; public APK remains 0.42.0.

Restaurant and Kaiserschmarrn → Betriebstraining → Kochschicht starten. Three ingredient drags, six downward chopping gestures (restaurant) or short stirring gestures (batter), actual moving heat meter, and plate drag to serving pass. Restaurant rotates three recipes; the batter recipe is business-specific. Five meals form one shift. Other buildings retain their current training.

Uses the existing Activities ledger: same three rewarded shifts per building/day across normal and practical modes, same €250 maximum per perfect shift, existing service and sector effects, unpaid fourth round. No invented guest sales, stock consumption, additional save fields or money per meal. Abandoning a workbench changes nothing; focus loss resets unfinished heating. Closed buildings, old days and invalid/nonfinite proofs are rejected. Repeat button retains cooking mode.

Town Hall marks the fully Android-tested, merged housekeeping package completed; cooking is marked complete for the tested development package on integration; drink mixing remains separately open. A completion check is a development milestone, not a claim that a new APK has shipped.

Local pinned Godot 4.5.2: 37 new kitchen assertions; 67 existing hospitality, 186 sector training, 27 housekeeping and 44 Town Hall assertions (361 overall). Real shipping UI exercised at 390×844 and 844×390; viewport-dispatched touch and drag-scroll exclusion checked. Full rendered phone/landscape evidence is produced by kitchen-043.yml and inspected before closing the work package. The full Android pipeline also runs the new regression.

Visual refinement after initial rendering: distinct ingredient drawings remain visible on the board; every stage retains a short instruction inside the canvas for landscape use. All four stages are rendered at both sizes. Preparation is additionally tested through actual viewport touch/drag events.

Focused CI on ee1f028 (44107207465) produced all four real stages at both phone sizes, reviewed visually. The final text uses a shorter cooking caption to keep it fully readable on portrait screens. Final-head CI is repeated; full Android/release acceptance remains separate.
