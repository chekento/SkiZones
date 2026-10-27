extends RefCounted
## Simulation is independent of scenes, the camera, frame rate and platform.

const Terrain = preload("res://src/core/terrain.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Progression = preload("res://src/core/progression.gd")
const MAX_GUESTS := 360
const OPENING := 480
const CLOSING := 1080

var money := 400000.0
var day := 1
var minute := OPENING
var reputation := 48.0
var ticket_price := 42
var weather_index := 0
var loan := 0
var total_guests := 0
var total_rides := 0
var next_id := 1
var guest_id := 1
var pistes: Array = []
var lifts: Array = []
var buildings: Array = []
var guests: Array = []
var achievements: Array = []
var report: Dictionary = {}
var last_report: Dictionary = {}
var rng := RandomNumberGenerator.new()
var revision := 0
var _routes: Dictionary = {}
var campaign: Dictionary = {}

func new_game(starter: bool = true, game_seed: int = 20261027) -> void:
	money = 400000.0
	day = 1
	minute = OPENING
	reputation = 48.0
	ticket_price = 42
	weather_index = 0
	loan = 0
	total_guests = 0
	total_rides = 0
	next_id = 1
	guest_id = 1
	pistes.clear()
	lifts.clear()
	buildings.clear()
	guests.clear()
	achievements.clear()
	last_report.clear()
	rng.seed = game_seed
	campaign = Progression.new_state(self, not starter)
	_reset_report()
	_invalidate()
	if starter:
		build_lift("drag", Vector2(200, 205), Vector2(245, -130))
		build_piste([[245, -130], [275, -30], [255, 95], [200, 205]], 0)
		build_building("lodge", Vector2(235, 252))
		build_building("rental", Vector2(145, 235))
	Progression.begin_day(self)

func _reset_report() -> void:
	report = {"day": day, "tickets": 0.0, "services": 0.0, "costs": 0.0, "guests": 0, "rides": 0, "departures": 0, "satisfaction": 0.0, "rewards": 0.0, "investments": 0.0}

func _invalidate() -> void:
	revision += 1
	_routes.clear()

func weather() -> Dictionary:
	return Catalog.WEATHER[weather_index]

func _result(ok: bool, message: String, extra: Dictionary = {}) -> Dictionary:
	var value := {"ok": ok, "message": message}
	value.merge(extra)
	return value

func _spend(cost: float) -> bool:
	if cost > money:
		return false
	money -= cost
	if not report.is_empty():
		report.investments = report.get("investments", 0.0) + cost
		Progression.sync_finances(self)
	return true

func build_piste(points: Array, difficulty: int) -> Dictionary:
	if pistes.size() >= 80:
		return _result(false, "Maximal 80 Pisten in diesem Prototyp.")
	var check := Terrain.analyse(points, difficulty)
	if not check.ok:
		return check
	if not _spend(check.cost):
		return _result(false, "Das Budget reicht für diese Piste noch nicht.")
	pistes.append({"id": next_id, "name": "%s %d" % [Terrain.PISTE_NAMES[difficulty], next_id], "points": points.duplicate(true), "difficulty": difficulty, "length": check.length, "grade": check.grade, "cost": check.cost, "condition": 100.0, "snow": 55.0, "enabled": true, "rides": 0, "level": 1, "upgrade_total": 0.0})
	next_id += 1
	_invalidate()
	return _result(true, "Piste gebaut. Sie öffnet, sobald ein Rundweg mit Lift erreichbar ist.")

func preview_lift(kind: String, bottom: Vector2, top: Vector2) -> Dictionary:
	if not Catalog.LIFTS.has(kind) or not Terrain.contains(bottom) or not Terrain.contains(top):
		return _result(false, "Beide Stationen müssen im Baugebiet liegen.")
	var distance := Terrain.world(bottom).distance_to(Terrain.world(top))
	var rise := Terrain.height(top) - Terrain.height(bottom)
	var cost := roundi(Catalog.LIFTS[kind].cost + distance * Catalog.LIFTS[kind].per_m)
	if distance < 65.0 or distance > 780.0 or rise < 9.0:
		return _result(false, "Talstation zuerst: 65–780 m Länge und mindestens 9 m Höhengewinn.", {"cost": cost})
	# The cable must clear every part of the hill, not only its endpoints.
	var samples := ceili(distance / 4.0)
	for i in range(1, samples):
		var t := float(i) / samples
		if Terrain.height(bottom.lerp(top, t)) > lerpf(Terrain.height(bottom), Terrain.height(top), t) + 7.0:
			return _result(false, "Der Hang durchstößt die Seillinie. Eine andere Trasse wählen.", {"cost": cost})
	return _result(true, "%.0f m · +%.0f Höhenmeter · %d Gäste/h" % [distance, rise, Catalog.LIFTS[kind].capacity], {"cost": cost, "length": distance})

func build_lift(kind: String, bottom: Vector2, top: Vector2) -> Dictionary:
	var access := build_access_message(kind, true)
	if access != "":
		return _result(false, access)
	if lifts.size() >= 24:
		return _result(false, "Maximal 24 Lifte in diesem Prototyp.")
	var check := preview_lift(kind, bottom, top)
	if not check.ok:
		return check
	if not _spend(check.cost):
		return _result(false, "Das Budget reicht für diesen Lift noch nicht.")
	lifts.append({"id": next_id, "kind": kind, "bottom": Terrain.pack(bottom), "top": Terrain.pack(top), "length": check.length, "cost": check.cost, "enabled": true, "credit": 0.0, "boarded": 0, "level": 1, "upgrade_total": 0.0, "name": "%s %d" % [Catalog.LIFTS[kind].name, next_id]})
	next_id += 1
	_invalidate()
	return _result(true, "Lift gebaut. Eine passende Abfahrt mit Rückweg ins Tal ergänzen.")

func preview_building(kind: String, point: Vector2) -> Dictionary:
	if not Catalog.BUILDINGS.has(kind) or not Terrain.contains(point):
		return _result(false, "Einen Standort im Baugebiet wählen.")
	for building in buildings:
		if point.distance_to(Terrain.unpack(building.point)) < 32.0:
			return _result(false, "Hier steht bereits ein Gebäude. Mindestens 32 m Abstand halten.")
	var local_grade := 0.0
	for direction in [Vector2.RIGHT, Vector2.DOWN]:
		local_grade = maxf(local_grade, absf(Terrain.height(point + direction * 8) - Terrain.height(point - direction * 8)) / 16.0)
	if local_grade > 0.42:
		return _result(false, "Dieser Bauplatz ist zu steil. Einen flacheren Standort wählen.")
	var near_station := point.y >= 165
	for lift in lifts:
		near_station = near_station or point.distance_to(Terrain.unpack(lift.bottom)) < 70 or point.distance_to(Terrain.unpack(lift.top)) < 70
	if not near_station and kind != "snowmaker":
		return _result(false, "Im Tal oder höchstens 70 m von einer Liftstation bauen.")
	for piste in pistes:
		for i in range(1, piste.points.size()):
			var nearest := Geometry2D.get_closest_point_to_segment(point, Terrain.unpack(piste.points[i - 1]), Terrain.unpack(piste.points[i]))
			if nearest.distance_to(point) < 15.0:
				return _result(false, "Die Piste freihalten: Mindestens 15 m Abstand zur Mittellinie.")
	return _result(true, Catalog.BUILDINGS[kind].description, {"cost": Catalog.BUILDINGS[kind].cost})

func build_building(kind: String, point: Vector2) -> Dictionary:
	var access := build_access_message(kind, false)
	if access != "":
		return _result(false, access)
	if buildings.size() >= 60:
		return _result(false, "Maximal 60 Gebäude in diesem Prototyp.")
	var check := preview_building(kind, point)
	if not check.ok:
		return check
	if not _spend(check.cost):
		return _result(false, "Das Budget reicht für dieses Gebäude noch nicht.")
	buildings.append({"id": next_id, "kind": kind, "point": Terrain.pack(point), "cost": check.cost, "enabled": true, "level": 1, "upgrade_total": 0.0, "name": Catalog.BUILDINGS[kind].name})
	next_id += 1
	_invalidate()
	return _result(true, "%s gebaut." % Catalog.BUILDINGS[kind].name)

func asset(id: int) -> Dictionary:
	for collection in [pistes, lifts, buildings]:
		for item in collection:
			if item.id == id:
				return item
	return {}

func set_enabled(id: int, enabled: bool) -> void:
	var item := asset(id)
	if not item.is_empty():
		item.enabled = enabled
		_invalidate()
		_reroute_guests()

func demolish(id: int) -> Dictionary:
	for collection in [pistes, lifts, buildings]:
		for i in range(collection.size()):
			if collection[i].id == id:
				var refund := roundi((collection[i].cost + collection[i].get("upgrade_total", 0)) * 0.25)
				collection.remove_at(i)
				money += refund
				_invalidate()
				_reroute_guests()
				return _result(true, "Abgebaut. %d € Materialwert erstattet; Gäste werden neu geleitet." % refund)
	return _result(false, "Anlage nicht gefunden.")

func lift_open(lift: Dictionary) -> bool:
	return lift.enabled and weather().wind < Catalog.LIFTS[lift.kind].wind_limit

func piste_open(piste: Dictionary) -> bool:
	return piste.enabled and piste.snow >= 12.0 and piste.condition > 12.0

func building_count(kind: String) -> int:
	var count := 0
	for building in buildings:
		if building.enabled and building.kind == kind:
			count += 1
	return count

func building_power(kind: String) -> float:
	var power := 0.0
	for building in buildings:
		if building.enabled and building.kind == kind:
			power += building.get("level", 1)
	return power

func lift_capacity(lift: Dictionary) -> int:
	return roundi(Catalog.LIFTS[lift.kind].capacity * (1.0 + 0.25 * (lift.get("level", 1) - 1)))

func lift_speed(lift: Dictionary) -> float:
	return Catalog.LIFTS[lift.kind].speed * (1.0 + 0.1 * (lift.get("level", 1) - 1))

func build_access_message(kind: String, is_lift: bool) -> String:
	return Progression.access_message(self, kind, is_lift)

func start_research(id: String) -> Dictionary:
	return Progression.start_research(self, id)

func accept_contract(id: String) -> Dictionary:
	return Progression.accept_contract(self, id)

func claim_contract(id: String) -> Dictionary:
	return Progression.claim_contract(self, id)

func upgrade_check(id: int) -> Dictionary:
	return Progression.upgrade_check(self, id)

func upgrade_asset(id: int) -> Dictionary:
	return Progression.upgrade(self, id)

func _edge(from_key: String, to_key: String, kind: String, id: int, points: Array, minutes: float) -> Dictionary:
	return {"from": from_key, "to": to_key, "kind": kind, "id": id, "points": points, "minutes": maxf(minutes, 0.15)}

func _graph(skill: int) -> Dictionary:
	var nodes := {"base": Terrain.pack(Terrain.BASE)}
	var edges: Dictionary = {"base": []}
	for lift in lifts:
		if lift_open(lift):
			var b := "l%db" % lift.id
			var t := "l%dt" % lift.id
			nodes[b] = lift.bottom
			nodes[t] = lift.top
			edges[b] = [_edge(b, t, "lift", lift.id, [lift.bottom, lift.top], lift.length / lift_speed(lift))]
			edges[t] = []
	for piste in pistes:
		if piste.difficulty <= skill and piste_open(piste):
			var s := "p%ds" % piste.id
			var e := "p%de" % piste.id
			nodes[s] = piste.points.front()
			nodes[e] = piste.points.back()
			edges[s] = [_edge(s, e, "ski", piste.id, piste.points, piste.length / (140.0 + skill * 55))]
			edges[e] = []
	var keys := nodes.keys()
	for i in range(keys.size()):
		for j in range(i + 1, keys.size()):
			var a := Terrain.unpack(nodes[keys[i]])
			var b := Terrain.unpack(nodes[keys[j]])
			var distance := a.distance_to(b)
			var valley_walk := a.y >= 165.0 and b.y >= 165.0 and distance < 220.0
			if distance <= Terrain.CONNECTION_RADIUS or valley_walk:
				var time := distance / 75.0
				edges[keys[i]].append(_edge(keys[i], keys[j], "walk", 0, [nodes[keys[i]], nodes[keys[j]]], time))
				edges[keys[j]].append(_edge(keys[j], keys[i], "walk", 0, [nodes[keys[j]], nodes[keys[i]]], time))
	return {"nodes": nodes, "edges": edges}

func _shortest(graph: Dictionary, source: String, target: String) -> Dictionary:
	if not graph.nodes.has(source) or not graph.nodes.has(target):
		return {"ok": false, "legs": []}
	var distance := {source: 0.0}
	var previous: Dictionary = {}
	var pending: Array = [source]
	while not pending.is_empty():
		var current: String = pending[0]
		for key in pending:
			if distance[key] < distance[current]:
				current = key
		pending.erase(current)
		if current == target:
			var route: Array = []
			while current != source:
				var leg: Dictionary = previous[current]
				route.push_front(leg)
				current = leg.from
			return {"ok": true, "legs": route}
		for leg in graph.edges[current]:
			var new_cost: float = distance[current] + leg.minutes
			if new_cost < distance.get(leg.to, INF):
				distance[leg.to] = new_cost
				previous[leg.to] = leg
				if not pending.has(leg.to):
					pending.append(leg.to)
	return {"ok": false, "legs": []}

func routes_for(skill: int) -> Array:
	if _routes.has(skill):
		return _routes[skill]
	var result: Array = []
	var graph := _graph(skill)
	for piste in pistes:
		if piste.difficulty > skill or not piste_open(piste):
			continue
		var start := "p%ds" % piste.id
		var end := "p%de" % piste.id
		var outbound := _shortest(graph, "base", start)
		var inbound := _shortest(graph, end, "base")
		if not outbound.ok or not inbound.ok:
			continue
		var legs: Array = outbound.legs.duplicate()
		legs.append(graph.edges[start][0])
		legs.append_array(inbound.legs)
		var uses_lift := false
		for leg in legs:
			uses_lift = uses_lift or leg.kind == "lift"
		if uses_lift:
			result.append({"target": piste.id, "legs": legs})
	_routes[skill] = result
	return result

func reachable_piste_ids() -> Array:
	var ids: Array = []
	for route in routes_for(2):
		ids.append(route.target)
	return ids

func admit_guest(skill: int) -> bool:
	var routes := routes_for(skill)
	if guests.size() >= MAX_GUESTS or routes.is_empty() or minute >= CLOSING:
		return false
	var route: Dictionary = routes[rng.randi_range(0, routes.size() - 1)]
	var guest := {"id": guest_id, "ability": skill, "age": 0, "stay": rng.randi_range(100, 245), "loops": 0, "leg": 0, "elapsed": 0.0, "phase": "moving", "wait": 0, "total_wait": 0, "spent": false, "route": route}
	guest_id += 1
	guests.append(guest)
	_start_leg(guest)
	money += ticket_price
	report.tickets += ticket_price
	report.guests += 1
	total_guests += 1
	Progression.on_admission(self, skill, ticket_price)
	return true

func _start_leg(guest: Dictionary) -> void:
	guest.elapsed = 0.0
	guest.wait = 0
	guest.phase = "queue" if guest.route.legs[guest.leg].kind == "lift" else "moving"

func _finish_leg(guest: Dictionary) -> void:
	var leg: Dictionary = guest.route.legs[guest.leg]
	if leg.kind == "ski":
		var piste := asset(leg.id)
		if not piste.is_empty():
			piste.rides += 1
			var was_open := piste_open(piste)
			piste.condition = maxf(0.0, piste.condition - 0.016 / (1.0 + 0.45 * (piste.get("level", 1) - 1)))
			if was_open != piste_open(piste):
				_invalidate()
		total_rides += 1
		report.rides += 1
		campaign.xp += 1
	guest.leg += 1
	if guest.leg < guest.route.legs.size():
		_start_leg(guest)
		return
	guest.loops += 1
	if not guest.spent:
		var spending := 0.0
		for kind in Catalog.BUILDINGS:
			var best := 0
			for building in buildings:
				if building.enabled and building.kind == kind:
					best = maxi(best, building.get("level", 1))
			if best > 0:
				spending += Catalog.BUILDINGS[kind].income * (1.0 + (best - 1) * 0.35)
		if Progression.has(self, "service"):
			spending *= 1.15
		money += spending
		report.services += spending
		campaign.turnover += spending
		guest.spent = true
	if guest.age >= guest.stay or guest.total_wait > 80:
		guest.phase = "leaving"
	else:
		var routes := routes_for(guest.ability)
		if routes.is_empty():
			guest.phase = "leaving"
		else:
			guest.route = routes[rng.randi_range(0, routes.size() - 1)]
			guest.leg = 0
			_start_leg(guest)

func _depart(guest: Dictionary) -> void:
	var appeal := 0.0
	for kind in Catalog.BUILDINGS:
		appeal += minf(building_power(kind), 3) * Catalog.BUILDINGS[kind].appeal
	if Progression.has(self, "service"):
		appeal += 6
	var satisfaction := clampf(65.0 + appeal * 0.55 + minf(guest.loops, 5) * 3.0 - guest.total_wait * 0.45 - maxf(ticket_price - 48, 0) * 0.6, 5, 100)
	report.satisfaction += satisfaction
	report.departures += 1
	reputation = clampf(lerpf(reputation, satisfaction, 0.012), 10.0, 95.0)
	if satisfaction >= 80:
		campaign.happy += 1

func _reroute_guests() -> void:
	for guest in guests:
		var routes := routes_for(guest.ability)
		if routes.is_empty():
			guest.phase = "leaving"
		else:
			guest.route = routes[0]
			guest.leg = 0
			_start_leg(guest)

func advance_minute(arrivals: bool = true) -> void:
	if minute >= CLOSING:
		return
	minute += 1
	var changed_open := false
	for piste in pistes:
		var was_open := piste_open(piste)
		piste.snow = maxf(0.0, piste.snow - maxf(weather().temperature, 0.0) * 0.018)
		if weather().temperature <= -1:
			for building in buildings:
				if building.enabled and building.kind == "snowmaker":
					if Terrain.point_on_path(piste.points, 0.5).distance_to(Terrain.unpack(building.point)) <= 150 + 20 * (building.get("level", 1) - 1):
						piste.snow = minf(110.0, piste.snow + 0.035 * building.get("level", 1))
		changed_open = changed_open or was_open != piste_open(piste)
	if changed_open:
		_invalidate()
	if arrivals and minute < CLOSING - 85:
		var day_event := Progression.event(self)
		var campaign_bonus: float = 1.0 + (campaign.rank - 1) * 0.08 + (0.15 if Progression.has(self, "marketing") else 0.0)
		var demand: float = (0.7 + reputation / 90.0 + building_power("hotel") * 0.35) * weather().demand * pow(42.0 / ticket_price, 1.3) * day_event.demand * campaign_bonus
		var arrivals_count := floori(demand) + int(rng.randf() < fmod(demand, 1.0))
		for i in range(arrivals_count):
			var ability := 0 if rng.randf() < day_event.beginner_share else (1 if rng.randf() < 0.72 else 2)
			admit_guest(ability)
	var departures: Array = []
	for guest in guests:
		guest.age += 1
		if guest.phase == "leaving":
			_depart(guest)
			departures.append(guest)
		elif guest.phase == "queue":
			guest.wait += 1
			guest.total_wait += 1
			if guest.wait > 45:
				guest.phase = "leaving"
		else:
			guest.elapsed += 1.0
			if guest.elapsed >= guest.route.legs[guest.leg].minutes:
				_finish_leg(guest)
	for guest in departures:
		guests.erase(guest)
	# Capacity is consumed once per lift, shared by every piste and ability.
	for lift in lifts:
		if not lift_open(lift):
			continue
		var per_minute: float = lift_capacity(lift) / 60.0
		lift.credit = minf(lift.credit + per_minute, per_minute * 2.0)
		for guest in guests:
			if lift.credit < 1.0:
				break
			if guest.phase == "queue" and guest.route.legs[guest.leg].id == lift.id:
				guest.phase = "moving"
				guest.elapsed = 0.0
				lift.credit -= 1.0
				lift.boarded += 1
	_check_achievements()
	Progression.refresh(self)
	if minute >= CLOSING:
		_close_day()

func _check_achievements() -> void:
	var all_colors: Array = []
	for id in reachable_piste_ids():
		var difficulty: int = asset(id).difficulty
		if not all_colors.has(difficulty):
			all_colors.append(difficulty)
	var conditions := [total_rides >= 100, all_colors.size() == 3, total_guests >= 750, reputation >= 80.0]
	var rewards := [10000, 25000, 20000, 30000]
	for i in range(conditions.size()):
		if conditions[i] and not achievements.has(i):
			achievements.append(i)
			money += rewards[i]
			report.rewards += rewards[i]

func operating_costs() -> float:
	var amount := 900.0
	for lift in lifts:
		amount += Catalog.LIFTS[lift.kind].upkeep * (1.0 if lift.enabled else 0.25) * (1.0 + 0.18 * (lift.get("level", 1) - 1))
	for building in buildings:
		amount += Catalog.BUILDINGS[building.kind].upkeep * (1.0 if building.enabled else 0.2) * (1.0 + 0.2 * (building.get("level", 1) - 1))
	for piste in pistes:
		amount += piste.length * (0.4 if piste.enabled else 0.08)
	return amount * (0.85 if Progression.has(self, "efficient_snow") else 1.0) + (450.0 if loan > 0 else 0.0)

func _close_day() -> void:
	for guest in guests:
		_depart(guest)
	guests.clear()
	report.costs = operating_costs()
	money -= report.costs
	Progression.finish_day(self)
	last_report = report.duplicate(true)

func next_day() -> bool:
	if minute < CLOSING:
		return false
	for piste in pistes:
		piste.snow = minf(110.0, piste.snow + weather().snowfall)
		piste.condition = minf(100.0, piste.condition + 32.0 + building_power("maintenance") * 24 + (piste.get("level", 1) - 1) * 5 + (12 if Progression.has(self, "efficient_snow") else 0))
	day += 1
	minute = OPENING
	weather_index = Progression.weather_for_day(rng.seed, day)
	_reset_report()
	Progression.begin_day(self)
	_invalidate()
	return true

func take_loan() -> bool:
	if loan > 0:
		return false
	loan = 150000
	money += loan
	return true

func repay_loan() -> bool:
	if loan <= 0 or money < loan:
		return false
	money -= loan
	loan = 0
	return true

func queue_size(id: int = -1) -> int:
	var count := 0
	for guest in guests:
		if guest.phase == "queue" and (id == -1 or guest.route.legs[guest.leg].id == id):
			count += 1
	return count

func guest_position(guest: Dictionary) -> Vector3:
	if guest.phase == "leaving":
		return Terrain.world(Terrain.BASE)
	var leg: Dictionary = guest.route.legs[guest.leg]
	var fraction := clampf(guest.elapsed / leg.minutes, 0, 1)
	if guest.phase == "queue":
		var point := Terrain.unpack(leg.points[0]) + Vector2((guest.id % 5) * 2 - 5, (guest.id % 7) * 2)
		return Terrain.world(point, 2)
	var point := Terrain.point_on_path(leg.points, fraction)
	if leg.kind == "lift":
		var a := Terrain.world(Terrain.unpack(leg.points[0]), 11)
		var b := Terrain.world(Terrain.unpack(leg.points[1]), 11)
		return a.lerp(b, fraction)
	return Terrain.world(point, 2)

func snapshot() -> Dictionary:
	var visitor_data: Array = []
	for guest in guests:
		var copy: Dictionary = guest.duplicate()
		copy.erase("route")
		copy.target = guest.route.target
		visitor_data.append(copy)
	return {"version": 2, "campaign": campaign.duplicate(true), "money": money, "day": day, "minute": minute, "reputation": reputation, "ticket_price": ticket_price, "weather_index": weather_index, "loan": loan, "total_guests": total_guests, "total_rides": total_rides, "next_id": next_id, "guest_id": guest_id, "pistes": pistes.duplicate(true), "lifts": lifts.duplicate(true), "buildings": buildings.duplicate(true), "guests": visitor_data, "achievements": achievements.duplicate(), "report": report.duplicate(true), "last_report": last_report.duplicate(true), "rng_seed": str(rng.seed), "rng_state": str(rng.state)}

func restore(data: Dictionary) -> Dictionary:
	# Validate into a separate instance, so a failed load never damages this game.
	var candidate = get_script().new()
	var check: Dictionary = candidate._restore_checked(data)
	if not check.ok:
		return check
	for key in ["money", "day", "minute", "reputation", "ticket_price", "weather_index", "loan", "total_guests", "total_rides", "next_id", "guest_id", "pistes", "lifts", "buildings", "guests", "achievements", "report", "last_report", "campaign"]:
		set(key, candidate.get(key))
	rng.seed = candidate.rng.seed
	rng.state = candidate.rng.state
	_invalidate()
	return _result(true, "Spielstand geladen.")

func _restore_checked(data: Dictionary) -> Dictionary:
	var invalid := _result(false, "Der Spielstand ist unvollständig oder beschädigt.")
	if data.get("version") != 1 and data.get("version") != 2:
		return _result(false, "Diese Spielstand-Version wird nicht unterstützt.")
	var ranges := {"money": [-100000000, 1000000000], "day": [1, 100000], "minute": [OPENING, CLOSING], "reputation": [0, 100], "ticket_price": [20, 95], "weather_index": [0, Catalog.WEATHER.size() - 1], "loan": [0, 150000], "total_guests": [0, 1000000000], "total_rides": [0, 1000000000], "next_id": [1, 1000000], "guest_id": [1, 1000000000]}
	for key in ranges:
		var value: Variant = data.get(key)
		if not Terrain.number(value) or value < ranges[key][0] or value > ranges[key][1]:
			return invalid
		if key not in ["money", "reputation"] and float(value) != floorf(float(value)):
			return invalid
	for key in ["pistes", "lifts", "buildings", "guests", "achievements"]:
		if not data.get(key) is Array:
			return invalid
	if data.pistes.size() > 80 or data.lifts.size() > 24 or data.buildings.size() > 60 or data.guests.size() > MAX_GUESTS:
		return invalid
	var used_ids: Array = []
	for key in ["pistes", "lifts", "buildings"]:
		for item in data[key]:
			if not item is Dictionary or not Terrain.number(item.get("id")) or int(item.id) != item.id or item.id < 1 or item.id >= data.next_id or used_ids.has(item.id):
				return invalid
			used_ids.append(item.id)
			if not item.get("enabled") is bool or not item.get("name") is String or item.name.length() > 100:
				return invalid
			if not Terrain.number(item.get("cost")) or item.cost < 0 or item.cost > 10000000:
				return invalid
			var level: Variant = item.get("level", 1)
			var extra: Variant = item.get("upgrade_total", 0.0)
			if not Terrain.number(level) or level < 1 or level > 3 or level != floorf(level) or not Terrain.number(extra) or extra < 0 or extra > 100000000:
				return invalid
			item.level = int(level)
			item.upgrade_total = float(extra)
			if key == "pistes":
				if not item.get("points") is Array or not Terrain.number(item.get("difficulty")) or int(item.difficulty) != item.difficulty:
					return invalid
				var analysis := Terrain.analyse(item.points, int(item.difficulty))
				if not analysis.ok:
					return invalid
				for field in ["condition", "snow", "rides"]:
					if not Terrain.number(item.get(field)) or item[field] < 0 or item[field] > (1000000000 if field == "rides" else 110):
						return invalid
				item.length = analysis.length
				item.grade = analysis.grade
			elif key == "lifts":
				if not item.get("kind") is String or not preview_lift(item.kind, Terrain.unpack(item.get("bottom")), Terrain.unpack(item.get("top"))).ok:
					return invalid
				for field in ["credit", "boarded"]:
					if not Terrain.number(item.get(field)) or item[field] < 0 or item[field] > 1000000000:
						return invalid
				item.length = Terrain.world(Terrain.unpack(item.bottom)).distance_to(Terrain.world(Terrain.unpack(item.top)))
				item.credit = minf(item.credit, lift_capacity(item) / 30.0)
			else:
				if not item.get("kind") is String or not Catalog.BUILDINGS.has(item.kind) or not Terrain.contains(Terrain.unpack(item.get("point"))):
					return invalid
	for key in ["report", "last_report"]:
		if not data.get(key) is Dictionary:
			return invalid
		if data[key].has("investments") and (not Terrain.number(data[key].investments) or data[key].investments < 0):
			return invalid
		for field in ["day", "tickets", "services", "costs", "guests", "rides", "departures", "satisfaction", "rewards"]:
			if key == "last_report" and data[key].is_empty():
				break
			if not Terrain.number(data[key].get(field)) or data[key][field] < 0:
				return invalid
	for achievement in data.achievements:
		if not Terrain.number(achievement) or int(achievement) != achievement or achievement < 0 or achievement > 3:
			return invalid
	if not data.get("rng_seed") is String or not data.get("rng_state") is String or not data.rng_seed.is_valid_int() or not data.rng_state.is_valid_int():
		return invalid
	for key in ranges:
		set(key, data[key])
	pistes = data.pistes.duplicate(true)
	lifts = data.lifts.duplicate(true)
	buildings = data.buildings.duplicate(true)
	achievements.clear()
	for achievement in data.achievements:
		achievements.append(int(achievement))
	report = data.report.duplicate(true)
	report.investments = report.get("investments", 0.0)
	last_report = data.last_report.duplicate(true)
	_invalidate()
	var visitor_ids: Array = []
	for visitor in data.guests:
		if not visitor is Dictionary:
			return invalid
		for field in ["id", "ability", "age", "stay", "loops", "leg", "elapsed", "wait", "total_wait", "target"]:
			if not Terrain.number(visitor.get(field)) or visitor[field] < 0 or visitor[field] > 1000000000:
				return invalid
		if visitor.ability > 2 or int(visitor.ability) != visitor.ability or visitor.id >= guest_id or visitor_ids.has(visitor.id) or not visitor.get("spent") is bool or visitor.get("phase") not in ["moving", "queue", "leaving"]:
			return invalid
		visitor_ids.append(visitor.id)
		var route: Dictionary = {}
		for option in routes_for(int(visitor.ability)):
			if option.target == visitor.target:
				route = option
		if route.is_empty():
			continue # An exhausted piste may have closed while this guest was skiing.
		if int(visitor.leg) != visitor.leg or visitor.leg > route.legs.size() or (visitor.leg == route.legs.size() and visitor.phase != "leaving"):
			return invalid
		if visitor.phase == "queue" and route.legs[int(visitor.leg)].kind != "lift":
			return invalid
		var copy: Dictionary = visitor.duplicate(true)
		copy.route = route
		copy.erase("target")
		guests.append(copy)
	rng.seed = int(data.rng_seed)
	rng.state = int(data.rng_state)
	if not Progression.restore(self, data.get("campaign")):
		return invalid
	return _result(true, "Spielstand geprüft.")
