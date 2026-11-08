extends RefCounted
## Hotel capacity, persistent holiday visitors and a real walkway-based nightly
## return. Does not invent remote hotel travel or a bus boarding system.
const Catalog = preload("res://src/core/catalog.gd")
const Hospitality = preload("res://src/core/hospitality.gd")
const Foot = preload("res://src/core/foot_network.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Needs = preload("res://src/core/guest_needs.gd")
const Agenda = preload("res://src/core/guest_agenda.gd")
const Ops = preload("res://src/core/operations.gd")
const ROOMS_PER_LEVEL := 24
const MIN_HOLIDAY_MINUTES := 2880
const MAX_HOLIDAY_MINUTES := 6480

static func room_count(building: Dictionary) -> int:
	return int(Catalog.LODGING.get(building.get("kind", ""), {}).get("rooms", 0)) * maxi(1, int(building.get("level", 1))) if building.get("enabled", false) else 0

static func rooms_needed(guest: Dictionary) -> int:
	return maxi(1, ceili(float(guest.get("group_size", 1)) / 2.0))

static func _reservation(guest: Dictionary) -> String:
	return "party:%d" % int(guest.party_id) if guest.has("party_id") else "guest:%d" % int(guest.id)

static func rooms_used(model: RefCounted, id: int) -> int:
	var reservations := {}
	for guest in model.guests:
		if int(guest.get("lodging_id", 0)) != id or guest.phase == "leaving": continue
		var key := _reservation(guest)
		reservations[key] = int(reservations.get(key, 0)) + maxi(1, int(guest.get("group_size", 1)))
	var total := 0
	for people in reservations.values(): total += ceili(float(people) / 2.0)
	return total

static func billable_rooms(model: RefCounted, guest: Dictionary) -> float:
	if not guest.has("party_id") or not guest.has("lodging_id"): return float(rooms_needed(guest))
	var people := 0
	for person in model.guests:
		if person.get("party_id", 0) == guest.party_id and person.get("lodging_id", 0) == guest.lodging_id and person.phase != "leaving":
			people += 1
	return float(ceili(float(people) / 2.0)) / float(maxi(1, people))

static func assign(model: RefCounted, guest: Dictionary) -> bool:
	if not Ops.continuous(model) or guest.get("evening", false): return false
	var options: Array = []
	for hotel in model.buildings:
		if not Hospitality.lodging(str(hotel.kind)) or not Ops.building_open(model, hotel): continue
		var vacancies: int = model.HotelRooms.available(model,hotel)
		if vacancies < rooms_needed(guest): continue
		# Existing foot-network connects this hotel with actual resort
		# access: no teleport or fictional off-road bus connection.
		var graph: Dictionary = model._routing_graph(int(guest.ability))
		var to_hotel: Dictionary = model._shortest(graph, "base", "d%d" % int(hotel.id))
		var to_base: Dictionary = model._shortest(graph, "d%d" % int(hotel.id), "base")
		if not to_hotel.get("ok", false) or not to_base.get("ok", false): continue
		options.append(hotel)
	if options.is_empty(): return false
	options.sort_custom(func(a, b):
		var score_a: float = Hospitality.attraction(model, a, guest) - 4.0 * rooms_used(model, int(a.id)) / maxi(1, room_count(a))
		var score_b: float = Hospitality.attraction(model, b, guest) - 4.0 * rooms_used(model, int(b.id)) / maxi(1, room_count(b))
		return int(a.id) < int(b.id) if is_equal_approx(score_a, score_b) else score_a > score_b)
	var selected: Dictionary = options[0]
	guest.lodging_id = int(selected.id)
	guest.stay = maxi(int(guest.stay), model.rng.randi_range(MIN_HOLIDAY_MINUTES, MAX_HOLIDAY_MINUTES))
	if model.operations.get("weekly_enabled", false) and int(guest.id) % 4 == 0 and Hospitality.weekly_offer(model).available:
		guest.stay = maxi(int(guest.stay), 7 * 1440)
	return true

static func should_return(model: RefCounted, guest: Dictionary) -> bool:
	if not guest.has("lodging_id") or guest.get("hotel_night", false) or guest.get("heading_home", false): return false
	if guest.phase != "moving" or int(guest.age) >= int(guest.stay): return false
	if model.minute < 1000 and model.minute >= 420: return false
	var hotel: Dictionary = model.asset(int(guest.lodging_id))
	# Existing residents retain physical room access after reception closes.
	# Staff availability gates new bookings, not the return to a paid room.
	return not hotel.is_empty() and bool(hotel.get("enabled", false)) and Hospitality.lodging(str(hotel.get("kind", "")))

static func night_route(model: RefCounted, guest: Dictionary, source: String) -> Dictionary:
	var hotel: Dictionary = model.asset(int(guest.get("lodging_id", 0)))
	# An already-booked guest needs an enabled accommodation and a real walk,
	# not an on-duty receptionist or a daytime housekeeping shift. New room
	# reservations remain subject to Ops.building_open() in assign().
	if hotel.is_empty() or not hotel.get("enabled", false) or not Hospitality.lodging(str(hotel.get("kind", ""))): return {}
	# Night travel must use the real pedestrian network, not a ski routing
	# graph that can be disconnected by closed lifts/pistes after 22:00.
	# The cabin/guesthouse access was already verified when built; preserve
	# the existing paths and require a valid walk both ways.
	var graph: Dictionary = model.pedestrian_graph()
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

## Each hotel party gets a stable, evenly distributed 07:00–08:59 departure
## time on every day. Every member of one family shares the same clock.
## No new fields are needed in the original 0.19–0.34 save format.
static func morning_departure_minute(guest: Dictionary, day: int) -> int:
	var party: int = int(guest.get("party_id", guest.get("guardian_id", guest.get("id", 1))))
	var room: int = int(guest.get("lodging_id", 0))
	return 420 + posmod(party * 53 + room * 17 + day * 31, 120)

static func start_sleep(model: RefCounted, guest: Dictionary) -> void:
	var current := Ops.clock(model)
	var morning: int = ((int(model.day) - 1) if int(model.minute) < 420 else int(model.day)) * 1440 + 420
	guest.hotel_sleep_until = maxi(current + 1, morning)
	guest.phase = "waiting"
	guest.waiting_reason = "hotel"
	guest.waiting_node = "d%d" % int(guest.lodging_id)
	guest.waiting_since = current
	guest.wait = 0
	guest.heading_home = true

static func wake(model: RefCounted, guest: Dictionary) -> void:
	if guest.phase != "waiting" or guest.get("waiting_reason", "") != "hotel": return
	if Ops.clock(model) < int(guest.get("hotel_sleep_until", 0)): return
	# Preexisting snapshots may have a 07:00 wake timestamp. Respect it,
	# then spread actual departures across the whole 07:00–09:00 window.
	if Ops.clock(model) < (int(model.day) - 1) * 1440 + morning_departure_minute(guest, int(model.day)): return
	var guardian: Dictionary = {}
	if guest.has("guardian_id"):
		guardian = model.Parties.actor(model, int(guest.guardian_id))
		if guardian.is_empty() or guardian.get("waiting_reason", "") == "hotel": return
		if int(guardian.leg) != 0 or guardian.route.legs.is_empty() or guardian.route.legs[0].from != "d%d" % int(guest.lodging_id): return
	else:
		for child in model.Parties.cell(model, guest):
			if not child.has("guardian_id"): continue
			if child.get("waiting_reason", "") != "hotel" or Ops.clock(model) < int(child.get("hotel_sleep_until", 0)): return
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
	guest.erase("evening")
	var source := "d%d" % int(guest.lodging_id)
	var route: Dictionary
	if not guardian.is_empty():
		route = guardian.route.duplicate(true)
	else:
		route = model.choose_route(model.Parties.care_guest(model, guest), source)
	if route.is_empty():
		# A closure can temporarily isolate a hotel. Recheck later; never
		# teleport out or remove a paid-for holiday guest arbitrarily.
		guest.phase = "waiting"
		guest.waiting_reason = "hotel"
		guest.waiting_node = source
		# Early ski lifts typically start at 08:00. Retry soon, but never
		# teleport a guest or repeatedly sell tickets while routes are shut.
		guest.hotel_sleep_until = Ops.clock(model) + 10
		return
	# Real exit from the accommodation: only now is a fresh day ticket due.
	Hospitality.renew_day_ticket(model, guest)
	guest.route = route
	guest.leg = 0
	model._start_leg(guest)

