extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Ops = preload("res://src/core/operations.gd")
const Terrain = preload("res://src/core/terrain.gd")
var passed := 0
var failed := 0
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error("FAIL " + message)
func place(model: RefCounted, kind: String) -> Dictionary:
	for z in range(240, 360, 35):
		for x in range(70, 330, 35):
			if model.build_building(kind, Vector2(x, z)).ok: return model.buildings[-1]
	return {}
func _init() -> void:
	var model := Resort.new()
	model.new_game(true)
	model.money = 3000000
	model.campaign.mode = "free"
	Ops.enable(model)
	model.operations.auto_groom = false
	var garage := place(model, "maintenance")
	var patrol := place(model, "first_aid")
	var hotel := place(model, "hotel")
	check(not garage.is_empty() and not patrol.is_empty() and not hotel.is_empty(), "place garage, patrol and hotel at actual accessible lots")
	if garage.is_empty() or patrol.is_empty() or hotel.is_empty():
		print("OPERATIONS: %d passed; %d failed" % [passed, failed])
		quit(1)
		return
	check(Ops.fill_building(model, int(garage.id)).ok and Ops.fill_building(model, int(patrol.id)).ok and Ops.fill_building(model, int(hotel.id)).ok, "hire qualified service teams")
	check(Ops.buy_groomer(model, int(garage.id)).ok and Ops.buy_groomer(model, int(garage.id)).ok, "purchase distinct vehicles")
	check(model.operations.vehicles[0].id != model.operations.vehicles[1].id, "vehicle identities are unique")
	model.minute = 1080
	var piste: Dictionary = model.pistes[0]
	piste.condition = 30.0
	check(Ops.groom(model, int(piste.id)).ok and not model.piste_open(piste), "grooming closes an empty piste at night")
	check(not Ops.groom(model, int(piste.id)).ok, "one driver cannot run two machines concurrently")
	var copy := Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "an active night work order survives JSON save validation")
	var stalled: Dictionary = model.operations.vehicles[0]
	stalled.fuel = 0.0
	var remaining: float = stalled.remaining
	model.advance_minute(false)
	check(stalled.remaining == remaining and not model.piste_open(piste), "an empty fuel tank stops actual work without reopening the piste")
	check(Ops.service_vehicle(model, int(stalled.id)).ok and stalled.fuel == 100, "a stalled working machine can be refuelled and resumed")
	var before: float = model.operations.vehicles[0].fuel
	for i in range(40): model.advance_minute(false)
	check(piste.condition == 100 and model.operations.groomed == 1, "only completed actual work restores piste condition")
	check(model.operations.vehicles[0].fuel < before and model.operations.vehicles[0].hours > 0, "groomer consumes energy and accumulates hours")
	model.minute = 8 * 60
	model._duty_cache.clear()
	model._operational_change()
	check(model.admit_guest(0), "a staffed daytime circuit admits a real guest")
	if not model.guests.is_empty():
		var guest: Dictionary = model.guests[0]
		for i in range(guest.route.legs.size()):
			if guest.route.legs[i].kind == "lift":
				guest.leg = i
				model._start_leg(guest)
				break
		check(guest.phase == "queue" and Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "a populated 24-hour lift queue saves with the continuous clock")
		for i in range(guest.route.legs.size()):
			if guest.route.legs[i].kind == "ski":
				guest.leg = i
				model._start_leg(guest)
				guest.elapsed = guest.duration * 0.45
				break
		Ops.incident(model, guest)
		var position: Vector3 = model.guest_position(guest)
		model.advance_minute(false)
		check(model.guest_position(guest).distance_to(position) < 0.01, "a guest awaiting rescue remains at the incident location")
		var event: Dictionary = model.operations.incidents[-1]
		check(Ops.dispatch(model, int(event.id)).ok, "staffed patrol dispatches via the actual route graph")
		for i in range(250):
			model.advance_minute(false)
			if event.status == "resolved": break
		check(event.status == "resolved" and int(guest.incident) == -1 and guest.get("assisted", false), "patrol reaches and assists the actual guest")
		check(Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "populated rescue state saves and reloads")
	model.guests.clear()
	model.minute = 1319
	model.advance_minute(false)
	model._duty_cache.clear()
	model._operational_change()
	check(Ops.building_open(model, hotel), "hotel is staffed at 22:00")
	check(Ops.admit_evening(model), "a real evening guest walks to an available service")
	check(not model.guests.is_empty() and model.guests[0].route.legs.any(func(l): return l.kind == "visit" and int(l.id) == int(hotel.id) and l.minutes >= 480), "overnight stay reserves an actual hotel visit")
	var day: int = model.day
	var ids: Array = model.guests.map(func(g): return g.id)
	for i in range(125): model.advance_minute(false)
	check(model.day == day + 1 and model.minute == 5 and not model.day_finished(), "the clock crosses midnight while the hotel is occupied")
	check(ids == model.guests.map(func(g): return g.id), "midnight preserves overnight guest identities")
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "populated overnight state survives save validation")
	model.operations.staff[0].break_until = Ops.clock(model) + 30
	model._duty_cache.clear()
	check(not Ops.on_duty(model, model.operations.staff[0]), "scheduled breaks release employees from duty")
	check(Ops.order_parts(model).ok and not Ops.order_parts(model).ok, "only one spare-parts delivery can be outstanding")
	var parts: int = model.operations.parts
	for i in range(120): model.advance_minute(false)
	check(model.operations.parts == parts + 6, "parts arrive after their actual two-hour lead time")
	var bad: Dictionary = model.snapshot()
	bad.operations.room_price = NAN
	check(not Resort.new().restore(bad).ok, "non-finite finance values are rejected atomically")
	var cable := Resort.new()
	cable.new_game(false)
	cable.build_lift("gondola", Vector2(210, 170), Vector2(200, -190))
	Ops.enable(cable)
	var lift: Dictionary = cable.lifts[0]
	var graph: Dictionary = cable._routing_graph(0)
	var top_key := "l%dt" % int(lift.id)
	var bottom_key := "l%db" % int(lift.id)
	var down: Array = graph.edges[top_key].filter(func(e): return e.kind == "lift" and e.get("reverse", false))
	check(down.size() == 1, "gondolas support an actual downhill service")
	if down.size() == 1 and not model.guests.is_empty():
		var guest: Dictionary = model.guests[0].duplicate(true)
		guest.id = 1
		guest.age = 0
		guest.stay = 900
		guest.elapsed = 0.0
		guest.wait = 0
		guest.total_wait = 0
		guest.loops = 0
		guest.runs = 0
		guest.service_history = {}
		guest.erase("heading_home")
		guest.erase("replan")
		guest.route = {"target": 0, "origin": graph.nodes[top_key], "legs": [down[0]] + cable._shortest(graph, bottom_key, "base").legs}
		guest.leg = 0
		cable.guests.append(guest)
		cable.guest_id = 2
		cable._start_leg(guest)
		for i in range(25):
			cable.advance_minute(false)
			if guest.phase == "moving": break
		check(guest.phase == "moving" and guest.route.legs[guest.leg].get("reverse", false), "a passenger boards the descending side at the upper station")
		check(Resort.new().restore(JSON.parse_string(JSON.stringify(cable.snapshot()))).ok, "downhill carrier, departure offset and assigned seat survive a populated save")
	print("OPERATIONS: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
