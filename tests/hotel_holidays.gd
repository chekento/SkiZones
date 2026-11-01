extends SceneTree
## Full-simulation offline checks: occupants persist, nights have actual stays
## and resort rooms never exceed capacity.
const Resort = preload("res://src/core/resort.gd")
const Lodging = preload("res://src/core/guest_lodging.gd")
const Ops = preload("res://src/core/operations.gd")
var passed := 0
var failed := 0

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var model := Resort.new()
	model.new_game(true, 20261027, "braunlage")
	# The career intentionally opens with a broken lift. This test is about
	# accommodation, not repair-office gameplay: bring the run into service.
	for lift in model.lifts:
		lift.fault = ""
	for lift in model.lifts.slice(0, mini(4, model.lifts.size())):
		Ops.fill_stations(model, int(lift.id), true)
	Ops.refresh_duty(model)
	model._operational_change()
	check(not model.routes_for(0).is_empty(), "Hotel fixture has a serviced beginner route")
	var hotels: Array = model.buildings.filter(func(b): return b.kind == "hotel")
	check(hotels.size() >= 1, "A real ski scenario opens with a player-operated hotel")
	if hotels.is_empty():
		print("RESULT: %d passed; %d failed" % [passed, failed])
		quit(1)
		return
	var hotel: Dictionary = hotels[0]
	check(model.admit_guest(0, "blue"), "A morning visitor enters the real resort")
	if model.guests.is_empty():
		print("RESULT: %d passed; %d failed" % [passed, failed])
		quit(1)
		return
	var guest: Dictionary = model.guests[0]
	check(guest.get("lodging_id", 0) == int(hotel.id), "An available connected alpine hotel assigns the real guest a room")
	check(guest.stay >= Lodging.MIN_HOLIDAY_MINUTES and guest.stay <= Lodging.MAX_HOLIDAY_MINUTES, "Resident plans a multi-day skiing holiday rather than daily arrivals")
	check(Lodging.rooms_used(model, int(hotel.id)) <= Lodging.room_count(hotel), "Hotel reservations respect the actual room capacity")
	var id: int = int(guest.id)
	var baseline_copy := Resort.new()
	check(baseline_copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "A normally admitted real-scenario hotel guest has a valid baseline save")
	model.minute = 1080
	model._duty_cache.clear()
	var night: Dictionary = Lodging.night_route(model, guest, "base")
	check(not night.is_empty(), "The hotel can be reached by the actual pedestrian/transport routing network")
	if night.is_empty():
		print("RESULT: %d passed; %d failed" % [passed, failed])
		quit(1)
		return
	guest.route = night
	var reached := false
	for index in range(guest.route.legs.size()):
		if guest.route.legs[index].kind == "visit":
			guest.leg = index
			guest.hotel_night = true
			guest.heading_home = true
			model._start_leg(guest)
			model._continue_leg(guest, guest.route.legs[index])
			reached = true
			break
	check(reached and guest.phase == "waiting" and guest.get("waiting_reason", "") == "hotel" and guest.hotel_sleep_until > Ops.clock(model), "At night guest enters hotel rather than continuing to ski")
	print("HOTEL_DIAG route_valid=", not model._checked_itinerary(guest.route, int(guest.ability)).is_empty(),
		" route_legs=", guest.route.legs.size(), " target=", guest.route.target,
		" visiting_leg=", guest.leg, " sleeping_until=", guest.get("hotel_sleep_until"),
		" phase=", guest.phase, " assigned=", guest.get("lodging_id"))
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	var copy := Resort.new()
	check(copy.restore(snapshot).ok, "Active multi-day hotel residence survives saved game validation")
	if not copy.guests.is_empty():
		check(copy.guests[0].get("lodging_id") == int(hotel.id) and int(copy.guests[0].id) == id and copy.guests[0].phase == "waiting", "Identical hotel room and sleeping guest are preserved after restoration")
	var existing: int = model.total_guests
	var before: int = model.guests.size()
	Ops.midnight(model)
	check(model.day == 2 and model.guests.size() == before and model.total_guests == existing, "Midnight advances the resort without checking out hotel visitors or creating artificial arrivals")
	model.minute = 420
	Lodging.wake(model, guest)
	check(guest.phase == "moving" or guest.get("waiting_reason", "") == "hotel", "Resident wakes and plans a real route, or waits for temporarily unavailable routes")
	check(model.guests.has(guest) and model.total_guests == existing, "The same visitor remains for the next ski day")
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
