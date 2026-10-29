extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Fleet = preload("res://src/core/lift_fleet.gd")
const Foot = preload("res://src/core/foot_network.gd")
const BLUE := [[245, -130], [275, -30], [255, 95], [200, 205]]
var passed := 0
var failed := 0

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func fresh(kind: String = "chair"):
	var model := Resort.new()
	model.new_game(false)
	model.money = 3000000
	model.build_lift(kind, Vector2(200, 205), Vector2(245, -130))
	model.build_piste(BLUE)
	return model

func join_queue(model: RefCounted, count: int) -> void:
	var first: int = model.guests.size()
	for i in range(count):
		model.admit_guest(0)
	# Seed capacity stress independently of the live admission policy, which
	# correctly declines a visit that cannot finish before personal departure.
	for guest in model.guests.slice(first):
		for index in range(guest.route.legs.size()):
			if guest.route.legs[index].kind == "lift":
				guest.leg = index
				break
		model._start_leg(guest)

func _init() -> void:
	_types()
	_boarding()
	_areas()
	_visits()
	_saves()
	_legacy()
	print("LIFTS AND PLAZAS: %d passed; %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _types() -> void:
	check(Catalog.LIFTS.chair1.seats == 1 and Catalog.LIFTS.chair2.seats == 2 and Catalog.LIFTS.chair.seats == 4 and Catalog.LIFTS.chair8.seats == 8, "One-, two-, four- and eight-seat chair types are distinct")
	check(Catalog.LIFTS.drag.speed * 1.2 < Catalog.LIFTS.chair1.speed and Catalog.LIFTS.drag.max_length == 700, "The drag lift stays slower than a chairlift and is limited to 700 metres")
	var model = fresh("drag")
	check(not model.preview_lift("drag", Vector2(900, 200), Vector2(900, -900)).ok and model.preview_lift("chair", Vector2(900, 200), Vector2(900, -900)).ok, "A long route requires a suitable chairlift instead of a drag lift")
	model.new_game(true)
	check(model.build_access_message("chair1", true) == "" and model.build_access_message("chair2", true) == "" and model.build_access_message("chair8", true) != "", "Small chairlifts are available early while the eight-seater requires progression")
	model.campaign.research.append("mastercraft")
	check(model.build_access_message("chair8", true) == "", "Alpine Mastery unlocks the eight-seat chairlift")
	check(not model.preview_lift("chair2", Vector2(200, 205), Vector2(245, -130)).ok, "Two station machines cannot occupy the same site")

func _boarding() -> void:
	for kind in ["drag", "chair1", "chair2", "chair", "chair6", "chair8", "gondola"]:
		var model = fresh(kind)
		join_queue(model, 40)
		var lift: Dictionary = model.lifts[0]
		var schedule: Dictionary = model.fleet_layout(lift)
		for i in range(ceili(schedule.interval)):
			model.advance_minute(false)
		var riding: Array = []
		for guest in model.guests:
			if guest.phase == "moving" and guest.route.legs[guest.leg].kind == "lift":
				riding.append(guest)
		var unique: Dictionary = {}
		var valid := true
		for guest in riding:
			var key := "%d/%d" % [guest.ride_car, guest.ride_seat]
			valid = valid and not unique.has(key) and guest.ride_seat < schedule.seats
			unique[key] = true
		check(riding.size() == schedule.seats and valid and model.queue_size(lift.id) == 40 - schedule.seats, "%s boards one real vehicle with unique, bounded seats" % kind)
		if not riding.is_empty():
			var guest: Dictionary = riding[0]
			var pose: Dictionary = model.carrier_pose(lift, guest.ride_car)
			var local: Vector3 = pose.transform.affine_inverse() * model.guest_position(guest)
			var correct := local.distance_to(Fleet.seat_offset(lift, guest.ride_seat)) < 0.001 if Fleet.family(lift) != "drag" else absf(model.guest_position(guest).y - model.terrain.height(Vector2(model.guest_position(guest).x, model.guest_position(guest).z)) - 0.15) < 0.001
			check(correct, "%s guest position is attached to its actual carrier or tow track" % kind)
	var model = fresh("chair")
	join_queue(model, 24)
	var lift: Dictionary = model.lifts[0]
	for i in range(40):
		model.advance_minute(false)
	var clock: float = lift.clock
	model.weather_index = 3
	model._invalidate()
	var rider: Dictionary = {}
	for guest in model.guests:
		if guest.phase == "moving" and guest.route.legs[guest.leg].kind == "lift":
			rider = guest
			break
	var before: Vector3 = model.guest_position(rider)
	for i in range(4):
		model.advance_minute(false)
	check(lift.clock == clock and model.guest_position(rider).distance_to(before) < 0.001, "Wind closure freezes both the occupied chair and its passengers")
	model.weather_index = 0
	model._invalidate()
	model.advance_minute(false)
	check(lift.clock == clock + 1 and model.guest_position(rider).distance_to(before) > 1, "Restarting a lift resumes the same assigned chair")
	model = fresh("chair")
	join_queue(model, 3)
	# FIFO follows arrival at the lift, rather than original park admission.
	model.guests[0].queue_since = 8
	model.guests[1].queue_since = 4
	model.guests[2].queue_since = 2
	model._queue_cache.clear()
	check(model.queued_guests(model.lifts[0].id)[0].id == model.guests[2].id, "Lift queues are sorted by actual arrival at that lift")
	var positions: Array[Vector3] = []
	var distinct := true
	var covered := true
	for index in range(360):
		var position: Vector3 = model.queue_position(model.lifts[0], index)
		for previous in positions:
			distinct = distinct and position.distance_to(previous) > 1.5
		positions.append(position)
		covered = covered and Foot.contains(model.pedestrian_layout(), Vector2(position.x, position.z))
	check(distinct and covered, "Even a full stress queue has separate standing spaces on the pedestrian area")

func _areas() -> void:
	var model = fresh()
	var lift: Dictionary = model.lifts[0]
	var piste: Dictionary = model.pistes[0]
	check(Terrain.unpack(piste.points[0]).distance_to(Terrain.unpack(lift.top)) > Foot.machine_radius(lift) + 3 and Terrain.unpack(piste.points[-1]).distance_to(Terrain.unpack(lift.bottom)) > Foot.machine_radius(lift) + 3, "Pistes begin and end on the plaza with clearance from the lift machinery")
	check(Foot.contains(model.pedestrian_layout(), Terrain.unpack(piste.points[0])) and Foot.contains(model.pedestrian_layout(), Terrain.unpack(piste.points[-1])), "Both piste ends belong to a visible pedestrian area")
	var route: Dictionary = model.routes_for(0)[0]
	var separated := true
	for index in range(route.legs.size() - 1):
		separated = separated and not (route.legs[index].kind == "lift" and route.legs[index + 1].kind == "ski") and not (route.legs[index].kind == "ski" and route.legs[index + 1].kind == "lift")
	check(separated, "Guests walk across a station plaza between lift and piste")
	var top := Terrain.unpack(lift.top)
	var snap_start := model.snap_anchor(top, 18, true)
	check(snap_start.point.distance_to(top) > Foot.machine_radius(lift), "Tapping a station snaps to a plaza gate instead of the machine")
	check(not model.preview_piste([[top.x - 80, top.y], [top.x, top.y], [top.x + 80, top.y + 80]]).ok, "A piste cannot cut through the middle of a station")
	model.new_game(true)
	# Legacy courtyards have no public promenade; keep testing their disconnection.
	model.terrain_generation = 1
	model.terrain = model.Mountain.new()
	model._invalidate()
	check(not model.preview_building("shelter", Vector2(18, 306)).ok, "An isolated building cannot create a remote pedestrian area")
	check(model.build_building("kiosk", Vector2(80, 280)).ok and model.build_building("shelter", Vector2(18, 306)).ok, "Connected building forecourts can extend an area beyond the original station radius")
	var bridge: int = model.buildings[2].id
	var outer: int = model.buildings[3].id
	check(model.pedestrian_layout().rooted.has("f%dg" % outer), "The extended courtyard remains part of the pedestrian network")
	model.demolish(bridge)
	check(not model.pedestrian_layout().rooted.has("f%dg" % outer), "Removing the only connecting courtyard disconnects its extension")
	model = fresh()
	check(model.build_lift("chair2", Vector2(140, 210), Vector2(150, -140)).ok, "A nearby lift can have its own station alongside an existing one")
	var graph: Dictionary = model.pedestrian_graph()
	check(model._shortest(graph, "l%db" % model.lifts[0].id, "l%db" % model.lifts[1].id).ok, "Guests can transfer between nearby lifts entirely on foot")
	model.new_game(false)
	model.money = 1000000
	model.build_lift("chair", Vector2(100, 200), Vector2(-170, -235))
	var hotel := model.build_building("hotel", Vector2(80, 235))
	graph = model.pedestrian_graph()
	var clear := true
	for index in range(160):
		var at: Vector3 = model.queue_position(model.lifts[0], index)
		clear = clear and Foot.free_of_buildings(Vector2(at.x, at.z), model.buildings, 1.5)
	check(hotel.ok and model._shortest(graph, "base", "l%db" % model.lifts[0].id).ok and clear, "A nearby hotel preserves station access and keeps waiting guests out of its walls")

func _visits() -> void:
	var model = fresh()
	check(model.build_building("restaurant", Vector2(235, 252)).ok, "A restaurant attaches to the station's pedestrian network")
	model.admit_guest(0)
	var guest: Dictionary = model.guests[0]
	guest.needs.hunger = 80
	guest.route = model.choose_route(guest)
	var visit := -1
	for index in range(guest.route.legs.size()):
		if guest.route.legs[index].kind == "visit":
			visit = index
			break
	check(visit >= 0 and not model._checked_itinerary(guest.route.duplicate(true), 0).is_empty(), "The guest itinerary includes an actual door visit and valid walking paths")
	var money: float = model.money
	guest.leg = visit
	model._start_leg(guest)
	check(model.report.services == 0 and model.buildings[0].visits == 0, "A building does not earn service money before a guest visits")
	var duration: float = guest.duration
	for i in range(ceili(duration)):
		model.advance_minute(false)
	check(model.buildings[0].visits == 1 and model.report.services == 7 and model.money == money + 7 and guest.spent, "Completing the restaurant visit charges its actual service once")
	var checked := true
	for leg in guest.route.legs:
		if leg.kind == "walk":
			checked = checked and Foot.valid_walk(model.pedestrian_layout(), leg.points, model.buildings)
	check(checked, "Visitor walking paths avoid the building footprint")

func _saves() -> void:
	var model = fresh("chair")
	join_queue(model, 20)
	for i in range(18):
		model.advance_minute(false)
	var copy := Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "A moving fleet, seats and queue survive a JSON save")
	var matching: bool = model.guests.size() == copy.guests.size()
	for index in range(copy.guests.size()):
		matching = matching and copy.guest_position(copy.guests[index]).distance_to(model.guest_position(model.guests[index])) < 0.001
	check(matching, "Restored passengers and waiting guests keep the exact same positions")
	var broken: Dictionary = model.snapshot()
	var riders: Array = []
	for guest in broken.guests:
		if guest.has("ride_car"):
			riders.append(guest)
	if riders.size() >= 2:
		riders[1].ride_car = riders[0].ride_car
		riders[1].ride_seat = riders[0].ride_seat
		riders[1].ride_departure = riders[0].ride_departure
		riders[1].elapsed = riders[0].elapsed
	check(not copy.restore(broken).ok, "A save with duplicate occupants in one physical seat is rejected")
	for i in range(160):
		model.advance_minute(false)
		copy.advance_minute(false)
	check(model.total_rides == copy.total_rides and model.money == copy.money and model.lifts[0].boarded == copy.lifts[0].boarded, "Fleet dispatch and visitor activity remain deterministic after restoring")

func _legacy() -> void:
	for name in ["starter", "junctions"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.4-%s.json" % name))
		var model := Resort.new()
		check(model.restore(data.duplicate(true)).ok and model.pistes.size() == data.pistes.size() and model.guests.size() == data.guests.size(), "Real 0.4 %s save migrates its assets and visitors" % name)
		check(model.money == data.money and model.campaign.research == data.campaign.research and model.total_rides == data.total_rides, "Real 0.4 %s migration preserves money, research and completed rides" % name)
		var copy := Resort.new()
		check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "Migrated %s resort can be saved again in the new fleet format" % name)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.4-starter.json"))
	data.pistes = []
	data.guests = []
	data.lifts[0].top = [900, -1300]
	var model := Resort.new()
	check(model.restore(data).ok and model.lifts[0].kind == "chair", "An overlong legacy drag lift becomes a chairlift while retaining the investment")
