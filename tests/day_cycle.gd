extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Motion = preload("res://src/core/ski_motion.gd")
const Terrain = preload("res://src/core/terrain.gd")
var passed := 0
var failed := 0

class FlatMountain extends "res://src/core/mountain.gd":
	func height(at: Vector2) -> float:
		return 200 - at.y * 0.015
class SteepMountain extends "res://src/core/mountain.gd":
	func height(at: Vector2) -> float:
		return 200 - at.y * 0.3

func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)

func fresh() -> RefCounted:
	var model := Resort.new()
	model.new_game(true)
	return model

func at_leg(model: RefCounted, kind: String) -> Dictionary:
	model.admit_guest(0)
	var guest: Dictionary = model.guests[-1]
	for i in range(guest.route.legs.size()):
		if guest.route.legs[i].kind == kind:
			guest.leg = i
			model._start_leg(guest)
			return guest
	return {}

func drain(model: RefCounted, limit: int = 1800) -> int:
	var steps := 0
	while not model.day_finished() and steps < limit:
		model.advance_minute(false)
		steps += 1
	return steps

func _init() -> void:
	_late_skier()
	_chair_restart()
	_route_choices()
	_queue_choices()
	_closed_return_lift()
	_rebuild_save()
	_motion()
	_migration()
	print("DAY CYCLE: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _late_skier() -> void:
	var model := fresh()
	var guest := at_leg(model, "ski")
	guest.elapsed = guest.duration * 0.42
	model.minute = model.CLOSING - 1
	var before: Vector3 = model.guest_position(guest)
	var age: int = guest.age
	var paid: float = model.money
	model.advance_minute(false)
	check(model.is_closing() and model.guests.size() == 1 and model.guests[0].id == guest.id, "18:00 preserves the identity of a skier halfway down a piste")
	check(guest.elapsed > 0 and guest.age == age + 1 and model.guest_position(guest).distance_to(before) < 40, "Closing advances actual progress instead of teleporting the skier")
	check(model.last_report.is_empty() and model.money == paid and not model.next_day(), "Report, operating costs and next morning wait for the last guest")
	check(not model.admit_guest(0), "No new tickets are sold during the return phase")
	var copy := Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "An after-hours skier can be saved and loaded")
	check(copy.guest_position(copy.guests[0]).distance_to(model.guest_position(guest)) < 0.001, "Loading preserves the exact after-hours piste position")
	var steps := drain(model)
	drain(copy)
	check(steps < 1800 and model.guests.is_empty() and model.last_report.departures == 1, "The late skier completes the descent and physically returns to the valley")
	check(model.last_report.rides == 1 and model.last_report.closed_at > model.CLOSING, "Final report includes the descent completed after admission closes")
	check(copy.total_rides == model.total_rides and is_equal_approx(copy.money, model.money) and copy.minute == model.minute, "Saved after-hours journeys finish deterministically")
	paid = model.money
	model.advance_minute(false)
	model._close_day()
	check(is_equal_approx(model.money, paid), "Closing and report reopening never charge daily costs twice")
	check(model.next_day() and model.day == 2 and model.minute == model.OPENING, "The next morning begins only after all guests have returned")

func _chair_restart() -> void:
	var model := fresh()
	model.lifts[0].kind = "chair2"
	model._invalidate()
	var guest := at_leg(model, "lift")
	for i in range(10):
		model.advance_minute(false)
		if guest.phase == "moving": break
	check(guest.phase == "moving" and guest.has("ride_car"), "A real two-seater carrier boards a specific guest")
	var carrier: int = guest.ride_car
	var seat: int = guest.ride_seat
	var clock: float = model.lifts[0].clock
	model.minute = model.CLOSING - 1
	model.advance_minute(false)
	check(guest.ride_car == carrier and guest.ride_seat == seat and model.lifts[0].clock > clock, "The occupied two-seater keeps its carrier, seat and running clock across 18:00")
	check(drain(model) < 1800 and model.next_day(), "A two-seater finishes its last passengers before the morning restart")
	check(model.lift_load(model.lifts[0]).fill == 0, "Yesterday's carrier loads do not masquerade as today's occupancy")
	model.weather_index = 3
	model._invalidate()
	clock = model.lifts[0].clock
	model.advance_minute(false)
	check(not model.lift_open(model.lifts[0]) and model.lifts[0].clock == clock, "58 km/h storm correctly stops the two-seater without resetting it")
	check("Sturmpause" in model.lift_status(model.lifts[0]) and "Grenze" in model.lift_status(model.lifts[0]), "The inspector explains wind, threshold and automatic reopening")
	model.weather_index = 0
	model._invalidate()
	guest = at_leg(model, "lift")
	for i in range(12): model.advance_minute(false)
	check(model.lifts[0].clock > clock and model.lifts[0].boarded >= 2, "The same two-seater resumes and boards again in suitable weather")
	var at: Vector3 = model.guest_position(guest)
	model.set_enabled(model.lifts[0].id, false)
	check(model.guest_position(guest).distance_to(at) < 0.001 and guest.phase == "moving", "Manual closure preserves a seated passenger's exact position")
	check(model.lift_running(model.lifts[0]) and not model.lift_open(model.lifts[0]), "A manually closed lift unloads existing riders without taking new ones")

func _route_choices() -> void:
	var model := fresh()
	model.money = 3000000
	model.build_lift("chair2", Vector2(115,205), Vector2(160,-130))
	model.build_piste([[160,-130],[190,-30],[160,95],[115,205]])
	var guest := {"id": 102, "ability": 0, "age": 100, "stay": 500, "spent": true, "last_piste": model.pistes[0].id}
	var choices: Dictionary = {}
	for i in range(160):
		var route: Dictionary = model.choose_route(guest)
		if not route.is_empty(): choices[route.target] = choices.get(route.target, 0) + 1
	check(choices.size() == 2 and choices.get(model.pistes[1].id, 0) > choices.get(model.pistes[0].id, 0), "Repeated choices favor variety while retaining both usable descents")
	var g := at_leg(model, "ski")
	var leg: Dictionary = g.route.legs[g.leg]
	g.elapsed = g.duration
	var end: Vector3 = model.guest_position(g)
	model._finish_leg(g)
	var next: Vector3 = model.guest_position(g)
	check(Vector2(next.x, next.z).distance_to(Vector2(end.x, end.z)) < 0.01 and absf(next.y - end.y) < 1, "An onward route starts at the actual piste endpoint instead of the valley entrance")
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "A personal onward itinerary survives save validation")
	guest.age = 498
	check(model.choose_route(guest).is_empty(), "A guest close to departure does not start an impossible new circuit")
	guest.age = 100
	model.minute = model.CLOSING - 2
	check(model.choose_route(guest).is_empty(), "Remaining operating time prevents a predictable last-minute long circuit")
	model.minute = model.OPENING
	model.set_enabled(model.lifts[1].id, false)
	check(model.choose_route(guest).target == model.pistes[0].id, "Route choices exclude a lift that is manually closed")

func _queue_choices() -> void:
	var model := fresh()
	model.money = 3000000
	model.build_lift("chair2", Vector2(115,205), Vector2(160,-130))
	model.build_piste([[160,-130],[190,-30],[160,95],[115,205]])
	var visitor := {"id": 103, "ability": 0, "age": 0, "stay": 520, "spent": true}
	var quiet: Dictionary = model.choose_route(visitor)
	# Each piste now has its own direct landing approach. Inspect the quiet
	# chair-served circuit, then seed that exact queue for congestion testing.
	for route in model._routes_from(0,"base",true):
		if route.target == model.pistes[1].id: quiet = route
	var used_fast := false
	for leg in quiet.legs:
		used_fast = used_fast or (leg.kind == "lift" and leg.id == model.lifts[1].id)
	check(used_fast, "A quiet alternative chairlift provides the quicker uphill route")
	for i in range(40): model.admit_guest(0)
	for guest in model.guests:
		guest.route = quiet.duplicate(true)
		for index in range(guest.route.legs.size()):
			var leg: Dictionary = guest.route.legs[index]
			if leg.kind == "lift" and leg.id == model.lifts[1].id:
				guest.leg = index
				model._start_leg(guest)
				break
	var load: Dictionary = model.lift_load(model.lifts[1])
	check(load.queue == 40 and is_equal_approx(load.wait, 120.0), "Forty guests in a two-seat queue mean 120 simulation minutes, not four")
	var crowded: Dictionary = model.choose_route(visitor)
	var used_slow := false
	var used_crowded := false
	for leg in crowded.legs:
		used_slow = used_slow or (leg.kind == "lift" and leg.id == model.lifts[0].id)
		used_crowded = used_crowded or (leg.kind == "lift" and leg.id == model.lifts[1].id)
	check(used_slow and not used_crowded, "Pathfinding changes the actual lift approach when the faster lift has a long queue")
	check(model.routes_for(0).size() == 2, "Congestion changes choices without falsely disconnecting reachable pistes")
	var guest: Dictionary = model.guests[0]
	var before: Vector3 = model.guest_position(guest)
	model.set_enabled(model.lifts[1].id, false)
	check(guest.phase == "moving" and model.guest_position(guest).distance_to(before) < 0.5, "A closed queue is left on foot from the real standing place")
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "Walking out of a closed queue survives an exact save roundtrip")

func _closed_return_lift() -> void:
	var model := fresh()
	model.money = 10000000
	var built: bool = model.build_lift("chair2", Vector2(500,-60), Vector2(270,-300)).ok
	built = model.build_piste([[270,-300],[300,-180],[400,-100],[500,-60]]).ok and built
	var basin_id: int = model.pistes[-1].id
	built = model.build_piste([[280,-290],[300,-180],[275,-30],[255,95],[200,205]]).ok and built
	check(built, "A real Sonnenhang basin has a return lift and an onward descent to the valley")
	var route: Dictionary = {}
	for option in model.routes_for(0):
		if option.target == basin_id: route = option
	check(not route.is_empty() and model.admit_guest(0), "The basin is accessible to an actual admitted beginner")
	if route.is_empty() or model.guests.is_empty(): return
	var guest: Dictionary = model.guests[0]
	guest.route = route.duplicate(true)
	var lift: Dictionary = model.lifts[-1]
	for i in range(guest.route.legs.size()):
		if guest.route.legs[i].kind == "lift" and guest.route.legs[i].id == lift.id:
			guest.leg = i; model._start_leg(guest); break
	model.minute = model.CLOSING - 1
	var before: Vector3 = model.guest_position(guest)
	model.set_enabled(lift.id, false)
	check(guest.get("heading_home", false) and guest.phase == "moving", "Closing the only return lift starts an explicit recovery from the actual queue")
	check(model.guest_position(guest).distance_to(before) < 0.01, "Recovery preserves the stranded guest's exact position")
	var new_trip_uses_closed := false
	for option in model.routes_for(0):
		for leg in option.legs:
			new_trip_uses_closed = new_trip_uses_closed or (leg.kind == "lift" and leg.id == lift.id)
	check(not lift.enabled and not model.lift_open(lift) and not new_trip_uses_closed, "Recovery does not reopen the lift to new recreational circuits")
	for i in range(30):
		if guest.route.legs[guest.leg].kind == "lift": break
		model.advance_minute(false)
	check(guest.route.legs[guest.leg].kind == "lift" and model.lift_running(lift) and model.lift_status(lift).contains("Rückholbetrieb"), "Only homebound guests start a clearly labelled return service")
	model.weather_index = 3; model._invalidate()
	var clock: float = lift.clock
	model.advance_minute(false)
	check(not model.lift_running(lift) and lift.clock == clock, "Return service never bypasses the lift's storm safety limit")
	model.weather_index = 0; model._invalidate()
	var copy := Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "A homebound recovery queue survives an actual save roundtrip")
	var steps := drain(model)
	drain(copy)
	check(steps < 1800 and model.guests.is_empty() and lift.boarded > 0, "A manually closed return lift carries the stranded guest out instead of retaining an infinite queue")
	check(model.day_finished() and model.last_report.departures == 1 and model.next_day(), "Recovery unblocks the final report and next morning exactly once")
	check(copy.last_report.get("departures", 0) == 1 and copy.minute > copy.CLOSING and not copy.lifts[-1].enabled, "A restored recovery finishes while preserving the player's manual closure")

func _rebuild_save() -> void:
	var model := fresh()
	model.money = 3000000
	at_leg(model, "ski")
	var piste: Dictionary = model.pistes[0]
	var points: Array = piste.points.duplicate(true)
	points[1][0] += 8
	var changed: Dictionary = model.change_asset(piste.id, points, piste.name, "", 0, 20)
	check(changed.ok, "A structural piste rebuild remains available with an active resort")
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "Structural rebuilding never leaves an obsolete itinerary in the saved game")

func _motion() -> void:
	var flat := Motion.travel_profile(FlatMountain.new(), [[0,0],[0,250]], 0)
	var steep := Motion.travel_profile(SteepMountain.new(), [[0,0],[0,250]], 0)
	check(Motion.valid_profile(flat.samples) and Motion.valid_profile(steep.samples), "Physics profiles are finite, bounded and strictly chronological")
	check(steep.minutes < flat.minutes, "Gravity makes a continuous downhill run faster than a shallow traverse")
	check(not is_equal_approx(Motion.distance_progress(steep.samples, 0.25), 0.25), "Distance progresses through acceleration and braking rather than a constant-speed slide")
	check(Motion.distance_progress(steep.samples, -1) == 0 and Motion.distance_progress(steep.samples, 2) == 1, "Interpolated physics clamps exactly to the real route endpoints")
	var corner := Motion.travel_profile(SteepMountain.new(), [[0,0],[0,100],[12,100],[12,250]], 0)
	check(corner.minutes > steep.minutes, "Tight turns require braking instead of retaining straight-line speed")
	check(not Motion.valid_profile([[0.0,0.0],[0.8,0.7],[0.6,0.9],[1.0,1.0]]), "A corrupted backwards-running physics timeline is rejected")

func _migration() -> void:
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.7-closing.json"))
	var copy := Resort.new()
	check(copy.restore(old).ok and copy.guests.size() == old.guests.size(), "A populated actual 0.7 save at closing migrates without replacing guests")
	var before: Vector3 = copy.guest_position(copy.guests[0])
	copy.advance_minute(false)
	check(copy.is_closing() and copy.guest_position(copy.guests[0]).distance_to(before) < 40, "Migrated 0.7 skiers continue their saved old motion without snapping")
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(copy.snapshot()))).ok, "Migrated journeys can immediately be saved again in format 9")
