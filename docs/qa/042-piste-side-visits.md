# 0.42: piste-side stops and personal venue choices

Development change; no 0.42 release or device acceptance is claimed.

Guests can reserve a short walk from a descent to an open, staffed building,
complete a real visit and return to the exact same piste fraction. A new
need during a solo descent can also trigger an upcoming stop. Replanning
retains the guest's current position using the actual travel profile.
Each complete descent counts once; only completed visits create sales.

Construction allows a legal site beside the middle of a piste without
requiring a valley plaza. The building footprint must still clear the
entire ski corridor. Its door must have a real, gentle, obstacle-free
access path no longer than 70 m. An occupied ski corridor cannot be
replaced by a restaurant footprint. Compacted-snow access geometry uses
the same path as the visitor itinerary and leaves the model layout intact.

## Visitor coverage

| Venues | Decisions |
| --- | --- |
| Restaurant, pizzeria, Kaiserschmarrn | Hunger, family needs and existing lunch rhythm |
| Cocoa, kiosk | Warmth, hunger and snack windows |
| Souvenir, watchmaker, craftshop | Stable personal shopping preference and afternoon window |
| Pool, spa, fitness | Age, personal preference, time and actual needs |
| Viewpoint, shelter, lodge | Rest, warmth, scenic interest; older guests favour rest stops |
| Rental, ski school, first aid | Existing equipment, lesson and recovery needs |
| Lodging | Existing reservation and overnight system remains authoritative |
| Newsstand, printing press, town hall | Morning newspaper, selected print-shop and afternoon civic visits |
| Bar, disco | Adult-only choice, evening preference and cooldown |
| Technical buildings, snowmaking, bus infrastructure | Existing operational staff/transit systems; no invented retail sales |

Town hall and printing-press visits use their existing zero income prices.
The new preference score uses the age shown by the existing guest profile,
including old solo visitors. No new age or random-state migration is needed.

## Boundaries still requiring wider 0.42 work

- Individual family parties keep their existing coordinated appointments.
  Spontaneous mid-descent replanning is currently for solo actors and legacy
  family units; independently skiing guardians/children are not split by it.
- Piste-side decisions initially reserve one service per circuit. Later
  circuits may choose another service after real needs/cooldowns change.
- Large crowds, whole-day venue distribution, physical Samsung performance,
  all themes, Android lifecycle/update and visual acceptance remain gates.
- The broader snowpark, piste-editing and Rathaus 2.0 feature sets remain open
  in #106, #107 and #109; this patch is not their completion.

## Local evidence

Godot 4.6.3, 2026-11-13; headless model checks:

- `piste_side_visits_042.gd`: 29 passed, 0 failed. Full trip, one sale/run,
  geometry, capacity/staffing/closure, save/resume in three phases, age/taste,
  and position-preserving spontaneous replanning during a descent.
- `guest_agendas.gd`: 72 passed, 0 failed.
- `routes_and_services.gd`: 40 passed, 0 failed.
- `individual_parties.gd` with `--language de`: 24 passed, 0 failed.
- `guest_daily_rhythm_041.gd`: 12 passed, 0 failed.
- `save_repair_0382.gd`: 23 passed, 0 failed.
- `rescue_routes_042.gd`: 23 passed, 0 failed.
- `busy_resort_0351.gd`: 6 passed, 0 failed; 240 actual guests, 54 runs,
  all guests departed, four traffic lanes. This is not an Android FPS claim.

The separate scene test checks matching world/access geometry and captures
a screenshot when run with a real renderer in CI. A headless mesh check is
not visual approval. CI runs pinned Godot 4.5.2 and the existing Android and
historical-save gates separately. The rescue prerequisite is PR #110.
