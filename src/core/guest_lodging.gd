extends RefCounted
## Hotel capacity, persistent holiday visitors and a real walkway-based nightly
## return. Does not invent remote hotel travel or a bus boarding system.
const Geo = preload("res://src/core/real_resorts.gd")
const Foot = preload("res://src/core/foot_network.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Needs = preload("res://src/core/guest_needs.gd")
const Agenda = preload("res://src/core/guest_agenda.gd")
const Ops = preload("res://src/core/operations.gd")
const ROOMS_PER_LEVEL := 24
const MIN_HOLIDAY_MINUTES := 2880
const MAX_HOLIDAY_MINUTES := 6480

static func room_count(building: Dictionary) -> int:
	return ROOMS_PER_LEVEL * maxi(1, int(building.get("level", 1))) if building.get("kind", "") == "hotel" and building.get("enabled", false) else 0

static func rooms_needed(guest: Dictionary) -> int:
	return maxi(1, ceili(float(guest.get("group_size", 1)) / 2.0))

static func rooms_used(model: RefCounted, id: int) -> int:
	var total := 0
	for guest in model.guests:
		if int(guest.get("lodging_id", 0)) == id and guest.phase != "leaving":
			total += rooms_needed(guest)
	return total

static func assign(model: RefCounted, guest: Dictionary) -> bool:
	if model.map_id not in Geo.IDS or guest.get("evening", false): return false
	var options: Array = []
	for hotel in model.buildings:
		if hotel.kind != "hotel" or not Ops.building_open(model, hotel): continue
		var vacancies := room_count(hotel) - rooms_used(model, int(hotel.id))
		if vacancies < rooms_needed(guest): continue
		# Existing foot-network connects this hotel with actual resort
		# access: no teleport or fictional off-road bus connection.
		var graph: Dictionary = model._routing_graph(int(guest.ability))
		var to_hotel: Dictionary = model._shortest(graph, "base", "d%d" % int(hotel.id))
		var to_base: Dictionary = model._shortest(graph, "d%d" % int(hotel.id), "base")
		if not to_hotel.get("ok", false) or not to_base.get("ok", false): continue
		options.append(hotel)
	if options.is_empty(): return false
	options.sort_custom(func(a, b): return rooms_used(model, int(a.id)) < rooms_used(model, int(b.id)) if rooms_used(model, int(a.id)) != rooms_used(model, int(b.id)) else int(a.id) < int(b.id))
	var selected: Dictionary = options[0]
	guest.lodging_id = int(selected.id)
	guest.stay = maxi(int(guest.stay), model.rng.randi_range(MIN_HOLIDAY_MINUTES, MAX_HOLIDAY_MINUTES))
	return true

static func should_return(model: RefCounted, guest: Dictionary) -> bool:
	if not guest.has("lodging_id") or guest.has("party_id") or guest.get("hotel_night", false) or guest.get("heading_home", false): return false
	if guest.phase != "moving" or int(guest.age) >= int(guest.stay): return false
	if model.minute < 1000 and model.minute >= 420: return false
	var hotel: Dictionary = model.asset(int(guest.lodging_id))
	return not hotel.is_empty() and Ops.building_open(model, hotel)

static func night_route(model: RefCounted, guest: Dictionary, source: String) -> Dictionary:
	var hotel: Dictionary = model.asset(int(guest.get("lodging_id", 0)))
	if hotel.is_empty() or not Ops.building_open(model, hotel): return {}
	var graph: Dictionary = model._routing_graph(Agenda.comfort(guest))
	var destination := "d%d" % int(hotel.id)
	var outbound: Dictionary = model._shortest(graph, source, destination)
	var home: Dictionary = model._shortest(graph, destination, "base")
	if not outbound.get("ok", false) or not home.get("ok", false): return {}
	var doorway := Terrain.pack(Foot.door(hotel))
	var stop: Dictionary = model._edge(destination, destination, "visit", int(hotel.id),
		[doorway, doorway], 20.0 * model.time_divisor)
	# Keep the complete return-to-base path attached. Even while sleeping,
	# the existing secure save validator checks the full connected itinerary.
	var legs: Array = outbound.legs.duplicate(true)
	legs.append(stop)
	legs.append_array(home.legs)
	if legs.is_empty(): return {}
	return {"target": 0, "origin": graph.nodes[source], "legs": legs}

static func start_sleep(model: RefCounted, guest: Dictionary) -> void:
	var current := Ops.clock(model)
	var morning := ((model.day - 1) if model.minute < 420 else model.day) * 1440 + 420
	guest.hotel_sleep_until = maxi(current + 1, morning)
	guest.phase = "waiting"
	guest.waiting_reason = "hotel"
	guest.waiting_node = "d%d" % int(guest.lodging_id)
	guest.wait = 0
	guest.heading_home = true

static func wake(model: RefCounted, guest: Dictionary) -> void:
	if guest.phase != "waiting" or guest.get("waiting_reason", "") != "hotel": return
	if Ops.clock(model) < int(guest.get("hotel_sleep_until", 0)): return
	guest.erase("hotel_sleep_until")
	guest.erase("hotel_night")
	guest.erase("heading_home")
	guest.erase("waiting_reason")
	guest.erase("waiting_node")
	Needs.ensure(guest, model.weather().temperature)
	guest.needs.energy = maxf(guest.needs.energy, 92.0)
	guest.needs.warmth = maxf(guest.needs.warmth, 85.0)
	guest.needs.hunger = minf(guest.needs.hunger, 30.0)
	guest.needs.joy = minf(100.0, guest.needs.joy + 9.0)
	if guest.has("family"): Needs.aggregate_family(guest)
	if guest.age >= guest.stay:
		model.Access.depart(model, guest)
		return
	var source := "d%d" % int(guest.lodging_id)
	var route: Dictionary = model.choose_route(guest, source)
	if route.is_empty():
		# A closure can temporarily isolate a hotel. Recheck later; never
		# teleport out or remove a paid-for holiday guest arbitrarily.
		guest.phase = "waiting"
		guest.waiting_reason = "hotel"
		guest.waiting_node = source
		guest.hotel_sleep_until = Ops.clock(model) + 60
		return
	guest.route = route
	guest.leg = 0
	model._start_leg(guest)
