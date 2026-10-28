extends RefCounted
## Simulation is independent of scenes, the camera, frame rate and platform.

const Terrain = preload("res://src/core/terrain.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Progression = preload("res://src/core/progression.gd")
const Mountain = preload("res://src/core/mountain.gd")
const Maps = preload("res://src/core/maps.gd")
const Motion = preload("res://src/core/ski_motion.gd")
const Fleet = preload("res://src/core/lift_fleet.gd")
const Foot = preload("res://src/core/foot_network.gd")
const Edit = preload("res://src/core/resort_edit.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const MINUTES_PER_SECOND := 0.5
const TRANSPORT_SCALE := 30.0
const MAX_GUESTS := 360
const OPENING := 480
const CLOSING := 1080

var map_id := "sonnenhang"
var terrain := Mountain.new()
var snow_revision := 0

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
var walk_areas: Array = []
var guests: Array = []
var achievements: Array = []
var report: Dictionary = {}
var last_report: Dictionary = {}
var rng := RandomNumberGenerator.new()
var revision := 0
var _routes: Dictionary = {}
var _graphs: Dictionary = {}
var _ski_legs: Dictionary = {}
var _asset_index: Dictionary = {}
var _edit_context: Dictionary = {}
var _anchor_revision := -1
var _anchors: Array = []
var _cable_profiles: Dictionary = {}
var _foot_revision := -1
var _foot_layout: Dictionary = {}
var _foot_graph: Dictionary = {}
var _fleet_layouts: Dictionary = {}
var _queue_cache: Dictionary = {}
var _queue_slots: Dictionary = {}
var campaign: Dictionary = {}

func new_game(starter: bool = true, game_seed: int = 20261027, area_id: String = "sonnenhang") -> void:
	map_id = area_id if Maps.MAPS.has(area_id) else "sonnenhang"
	terrain = Mountain.new(map_id)
	snow_revision += 1
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
	walk_areas.clear()
	guests.clear()
	achievements.clear()
	last_report.clear()
	rng.seed = game_seed + Maps.MAPS.keys().find(map_id) * 7919
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
	_asset_index.clear()
	_edit_context.clear()
	_routes.clear()
	_graphs.clear()
	_ski_legs.clear()
	_cable_profiles.clear()
	_fleet_layouts.clear()
	_queue_slots.clear()
	_queue_cache.clear()

func cable_profile(lift: Dictionary) -> Dictionary:
	if not _cable_profiles.has(lift.id):
		_cable_profiles[lift.id] = _lift_profile(lift.kind, Terrain.unpack(lift.bottom), Terrain.unpack(lift.top))
	return _cable_profiles[lift.id]

func _lift_profile(kind: String, bottom: Vector2, top: Vector2) -> Dictionary:
	var ground_lift: bool = Catalog.LIFTS[kind].family in ["drag", "carpet"]
	return terrain.cable_profile(bottom, top, 8.0 if ground_lift else 16.0, 7.3, 5.0 if ground_lift else 7.0)

func fleet_layout(lift: Dictionary) -> Dictionary:
	if not _fleet_layouts.has(lift.id):
		_fleet_layouts[lift.id] = Fleet.layout(lift)
	return _fleet_layouts[lift.id]

func carrier_pose(lift: Dictionary, carrier: int, fraction_tick: float = 0.0) -> Dictionary:
	return Fleet.pose(terrain, lift, cable_profile(lift), lift.get("clock", 0.0) + (fraction_tick if lift_running(lift) else 0.0), carrier, fleet_layout(lift))

func rider_pose(guest: Dictionary, fraction_tick: float = 0.0) -> Dictionary:
	var leg: Dictionary = guest.route.legs[guest.leg]
	var lift := asset(leg.id)
	var pose := carrier_pose(lift, int(guest.get("ride_car", 0)), fraction_tick)
	var transform_value: Transform3D = pose.transform
	if Fleet.family(lift) in ["drag", "carpet"]:
		transform_value.origin = terrain.world(Vector2(transform_value.origin.x, transform_value.origin.z), 0.15 if Fleet.family(lift) == "drag" else 0.65)
	else:
		var seat: int = guest.get("ride_seat", 0)
		transform_value.origin += transform_value.basis * Fleet.seat_offset(lift, seat)
		if Fleet.family(lift) == "gondola" and seat >= 4:
			transform_value.basis = transform_value.basis.rotated(Vector3.UP, PI)
	return {"transform": transform_value, "carrier": guest.get("ride_car", 0), "seat": guest.get("ride_seat", 0), "seated": Fleet.family(lift) in ["chair", "gondola"]}

func cable_position(lift: Dictionary, fraction: float) -> Vector3:
	var profile := cable_profile(lift)
	var distance: float = profile.length * clampf(fraction, 0, 1)
	for i in range(1, profile.points.size()):
		if distance <= profile.lengths[i]:
			return profile.points[i - 1].lerp(profile.points[i], (distance - profile.lengths[i - 1]) / maxf(profile.lengths[i] - profile.lengths[i - 1], 0.001))
	return profile.points[-1]

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

func preview_piste(points: Array, width: float = 20) -> Dictionary:
	var prepared := Foot.prepare_piste(points, lifts)
	var check := terrain.analyse(prepared)
	check.points = prepared
	check.width = width
	if width < 14 or width > 44 or not is_finite(width):
		return _result(false, "Pistenbreite außerhalb des erlaubten Bereichs.")
	if check.has("cost"):
		check.cost = roundi(check.cost * width / 20)
	if check.ok and not Foot.clear_piste(prepared, lifts, width * 0.5):
		check.ok = false
		check.message = "Die Liftanlage freihalten. Die Piste am Stationsplatz anschließen."
	if check.ok:
		for building in buildings:
			if building.kind == "snowmaker":
				continue
			var footprint := Foot.building_size(building)
			for index in range(1, prepared.size()):
				if Foot._crosses(Terrain.unpack(prepared[index - 1]), Terrain.unpack(prepared[index]), Rect2(Terrain.unpack(building.point) - footprint * 0.5, footprint).grow(3)):
					check.ok = false
					check.message = "Das Gebäude freihalten. Die Piste auf dem Vorplatz anschließen."
	return check

func build_piste(points: Array, _legacy_choice: int = -1) -> Dictionary:
	if pistes.size() >= 80:
		return _result(false, "Maximal 80 Pisten in diesem Prototyp.")
	var check := preview_piste(points)
	if not check.ok:
		return check
	if not _spend(check.cost):
		return _result(false, "Das Budget reicht für diese Piste noch nicht.")
	var number := 1
	for piste in pistes:
		number = maxi(number, int(piste.number) + 1)
	var difficulty: int = check.difficulty
	pistes.append({"id": next_id, "number": number, "name": "%s %d" % [Terrain.PISTE_NAMES[difficulty], number], "points": check.points.duplicate(true), "difficulty": difficulty, "length": check.length, "horizontal": check.horizontal, "drop": check.drop, "average": check.average, "grade": check.grade, "cost": check.cost, "condition": 100.0, "snow": 55.0 * Maps.spec(map_id).snow, "enabled": true, "rides": 0, "level": 1, "upgrade_total": 0.0})
	next_id += 1
	_invalidate()
	return _result(true, "%s %d gebaut und beschildert. Öffnet mit einem erreichbaren Lift-Rundweg." % [Terrain.PISTE_NAMES[difficulty], number])

func preview_lift(kind: String, bottom: Vector2, top: Vector2, check_spacing: bool = true) -> Dictionary:
	if not Catalog.LIFTS.has(kind) or not terrain.contains(bottom) or not terrain.contains(top):
		return _result(false, "Beide Stationen müssen im Baugebiet liegen.")
	var distance: float = _lift_profile(kind, bottom, top).length
	var spec: Dictionary = Catalog.LIFTS[kind]
	var rise := terrain.height(top) - terrain.height(bottom)
	var cost := roundi(spec.cost + distance * spec.per_m)
	if distance < 65 or distance > spec.max_length or rise < 9:
		return _result(false, "%s: 65–%.0f m und mindestens 9 m Höhengewinn. Talstation zuerst setzen." % [spec.name, spec.max_length], {"cost": cost})
	if check_spacing:
		var proposed := {"kind": kind, "bottom": Terrain.pack(bottom), "top": Terrain.pack(top)}
		for lift in lifts:
			for a in [bottom, top]:
				for b in [lift.bottom, lift.top]:
					if a.distance_to(Terrain.unpack(b)) < Foot.machine_radius(lift) + Foot.machine_radius(proposed) + 4:
						return _result(false, "Die Station braucht einen eigenen Standort neben der bestehenden Anlage. Die Plätze verbinden sich zu Fuß.", {"cost": cost})
		for piste in pistes:
			var adjusted := Foot.prepare_piste(piste.points, [proposed])
			if not terrain.analyse(adjusted).ok or not Foot.clear_piste(adjusted, [proposed]):
				return _result(false, "Die Lifttechnik neben die Piste setzen. Pistenenden werden am Stationsplatz angeschlossen.", {"cost": cost})

	for building in buildings:
		if building.kind == "snowmaker": continue
		var size := Foot.building_size(building)
		var rect := Rect2(Terrain.unpack(building.point) - size * 0.5, size)
		for at in [bottom, top]:
			var closest: Vector2 = rect.position + (at - rect.position).clamp(Vector2.ZERO, rect.size)
			if closest.distance_to(at) < Foot.machine_radius({"kind": kind}) + 3:
				return _result(false, "Die Liftstation neben das Gebäude setzen und den Vorplatz freihalten.", {"cost": cost})

	return _result(true, "%.0f m · %.1f m/s · %.1f Min. Fahrt · %d Pers./Fahrzeug · %d Gäste/h" % [distance, spec.speed / 60, distance / spec.speed, spec.seats, spec.capacity], {"cost": cost, "length": distance})

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
	lifts.append({"id": next_id, "kind": kind, "bottom": Terrain.pack(bottom), "top": Terrain.pack(top), "length": check.length, "cost": check.cost, "enabled": true, "credit": 0.0, "clock": 0.0, "boarded": 0, "last_load": 0, "recent_departures": [], "level": 1, "upgrade_total": 0.0, "name": "%s %d" % [Catalog.LIFTS[kind].name, next_id]})
	var changed_pistes := false
	for piste in pistes:
		var prepared := Foot.prepare_piste(piste.points, [lifts[-1]])
		if prepared != piste.points:
			var analysis := terrain.analyse(prepared)
			if analysis.ok:
				changed_pistes = true
				Snow.migrate_length(piste, analysis.length)
				piste.points = prepared
				if piste.name.begins_with(Terrain.PISTE_NAMES[int(piste.difficulty)]):
					piste.name = "%s %d" % [Terrain.PISTE_NAMES[analysis.difficulty], piste.number]
				piste.difficulty = analysis.difficulty
				piste.grade = analysis.grade
				piste.drop = analysis.drop
				piste.average = analysis.average
				piste.horizontal = analysis.horizontal

	next_id += 1
	_invalidate()
	if changed_pistes:
		_reroute_guests()
	return _result(true, "Lift und Stationsplätze gebaut. Pisten an die Plätze anschließen; Gebäude erweitern das Fußwegenetz.")

func preview_building(kind: String, point: Vector2, rotation_value: int = 0) -> Dictionary:
	if not Catalog.BUILDINGS.has(kind) or not terrain.contains(point):
		return _result(false, "Einen Standort im Baugebiet wählen.")
	for building in buildings:
		if point.distance_to(Terrain.unpack(building.point)) < 32.0:
			return _result(false, "Hier steht bereits ein Gebäude. Mindestens 32 m Abstand halten.")
	if kind == "bus" and point.y < 165:
		return _result(false, "Den Skibus-Terminal im Tal bauen.")
	var proposed := {"kind": kind, "point": Terrain.pack(point), "rotation": rotation_value}
	var footprint := Foot.building_size(proposed)
	var rect := Rect2(point - footprint * 0.5, footprint).grow(2)
	var entrance := Foot.entrance_bounds(proposed)
	for building in buildings:
		var size := Foot.building_size(building)
		var previous := Rect2(Terrain.unpack(building.point) - size * 0.5, size)
		var previous_entrance := Foot.entrance_bounds(building)
		if rect.intersects(previous.grow(2)) or rect.intersects(previous_entrance) or entrance.intersects(previous.grow(2)):
			return _result(false, "Gebäude und Eingangsvorplatz freihalten. Einen Standort mit freiem Zugang wählen.")

	for lift in lifts:
		for station in [lift.bottom, lift.top]:
			var center := Terrain.unpack(station)
			var closest := rect.position + (center - rect.position).clamp(Vector2.ZERO, rect.size)
			if closest.distance_to(center) < Foot.machine_radius(lift) + 3:
				return _result(false, "Die Lifttechnik und den Einstieg freihalten. Das Gebäude am Rand des Stationsplatzes anschließen.")

	var local_grade := 0.0
	for direction in [Vector2.RIGHT, Vector2.DOWN]:
		local_grade = maxf(local_grade, absf(terrain.height(point + direction * 8) - terrain.height(point - direction * 8)) / 16.0)
	if local_grade > 0.42:
		return _result(false, "Dieser Bauplatz ist zu steil. Einen flacheren Standort wählen.")
	var connection: Dictionary = {} if kind == "snowmaker" else Foot.connection(terrain, pedestrian_layout(), buildings, kind, point, rotation_value)
	if kind != "snowmaker" and connection.is_empty():
		return _result(false, "An einen Stationsplatz, den Talzugang oder einen bereits angeschlossenen Gebäudeplatz bauen.")
	for piste in pistes:
		for i in range(1, piste.points.size()):
			var nearest := Geometry2D.get_closest_point_to_segment(point, Terrain.unpack(piste.points[i - 1]), Terrain.unpack(piste.points[i]))
			if nearest.distance_to(point) < 15.0:
				return _result(false, "Die Piste freihalten: Mindestens 15 m Abstand zur Mittellinie.")
	return _result(true, Catalog.BUILDINGS[kind].description + (" · Fußweg wird angeschlossen." if not connection.is_empty() else ""), {"cost": Catalog.BUILDINGS[kind].cost, "connection": connection})

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
	buildings.append({"id": next_id, "kind": kind, "point": Terrain.pack(point), "cost": check.cost, "enabled": true, "level": 1, "upgrade_total": 0.0, "name": Catalog.BUILDINGS[kind].name, "visits": 0, "revenue": 0.0})
	next_id += 1
	_invalidate()
	return _result(true, "%s gebaut." % Catalog.BUILDINGS[kind].name)

func preview_plaza(kind: String, point: Vector2) -> Dictionary:
	if not Catalog.PLAZAS.has(kind) or not terrain.contains(point):
		return _result(false, "Eine Gehfläche innerhalb des Baugebiets wählen.")
	var spec: Dictionary = Catalog.PLAZAS[kind]
	for direction in [Vector2.RIGHT, Vector2.DOWN]:
		if absf(terrain.height(point + direction * 8) - terrain.height(point - direction * 8)) / 16 > 0.55:
			return _result(false, "Hier ist es zum Gehen zu steil. Einen flacheren Bereich wählen.")
	for shape in Foot.obstacles(buildings, lifts):
		if Geometry2D.is_point_in_polygon(point, shape):
			return _result(false, "Lifttrassen und Gebäude freihalten. Die Gehfläche daneben setzen.")
	for area in walk_areas:
		if Terrain.unpack(area.point).distance_to(point) < 12:
			return _result(false, "Die neue Gehfläche etwas versetzt anlegen.")
	return _result(true, "%s · Ø %.0f m · verbindet Plätze, Pisten und Gebäude" % [spec.name, spec.radius * 2], {"cost": spec.cost, "radius": spec.radius})

func build_plaza(kind: String, point: Vector2) -> Dictionary:
	if walk_areas.size() >= 80:
		return _result(false, "Maximal 80 zusätzliche Gehflächen.")
	var check := preview_plaza(kind, point)
	if not check.ok:
		return check
	if not _spend(check.cost):
		return _result(false, "Das Budget reicht für diese Gehfläche noch nicht.")
	walk_areas.append({"id": next_id, "kind": kind, "point": Terrain.pack(point), "radius": check.radius, "cost": check.cost, "enabled": true, "name": Catalog.PLAZAS[kind].name})
	next_id += 1
	_invalidate()
	return _result(true, "Gehfläche angelegt. Benachbarte Plätze und Gebäude verbinden sich automatisch.")

func asset(id: int) -> Dictionary:
	if _asset_index.is_empty():
		for collection in [pistes, lifts, buildings, walk_areas]:
			for item in collection:
				_asset_index[int(item.id)] = item
	return _asset_index.get(id, {})

func set_enabled(id: int, enabled: bool) -> void:
	var item := asset(id)
	if not item.is_empty():
		item.enabled = enabled
		_invalidate()
		_reroute_guests()

func demolish(id: int) -> Dictionary:
	for collection in [pistes, lifts, buildings, walk_areas]:
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

func lift_running(lift: Dictionary) -> bool:
	if lift_open(lift):
		return true
	# A manually closed lift can unload its already seated passengers. Storm
	# safety still stops the machinery; reopening resumes the same carrier clock.
	return weather().wind < Catalog.LIFTS[lift.kind].wind_limit and lift_load(lift).riders > 0

func lift_status(lift: Dictionary) -> String:
	if weather().wind >= Catalog.LIFTS[lift.kind].wind_limit:
		return "Sturmpause: %.0f km/h Wind, Grenze %.0f km/h. Startet bei geeignetem Wetter automatisch wieder." % [weather().wind, Catalog.LIFTS[lift.kind].wind_limit]
	if not lift.enabled:
		return "Manuell geschlossen · Mitfahrende werden noch ausgeladen." if lift_running(lift) else "Manuell geschlossen · Über Öffnen wieder freigeben."
	if is_closing():
		return "Feierabendbetrieb · laufende Rückwege werden noch bedient."
	return "In Betrieb · Wind unter %.0f km/h." % Catalog.LIFTS[lift.kind].wind_limit

func day_finished() -> bool:
	return minute >= CLOSING and int(last_report.get("day", -1)) == day

func is_closing() -> bool:
	return minute >= CLOSING and not day_finished()

func piste_open(piste: Dictionary) -> bool:
	return piste.enabled and piste.snow >= 12.0 and piste.condition > 12.0 and piste.get("grooming_until", 0) <= minute

func groom_check(id: int) -> Dictionary:
	var piste := asset(id)
	if not piste.has("difficulty"):
		return _result(false, "Eine Piste wählen.")
	if campaign.mode != "free" and not Progression.has(self, "snowcraft"):
		return _result(false, "Schneemanagement erforschen.")
	if building_count("maintenance") == 0:
		return _result(false, "Eine geöffnete Pistenraupengarage ist erforderlich.")
	if piste.get("grooming_until", 0) > minute:
		return _result(false, "Die Pistenraupe ist bereits unterwegs.")
	if minute > CLOSING - 45:
		return _result(false, "Bald ist Feierabend; nachts wird automatisch präpariert.")
	var cost := roundi(piste.length * 1.5)
	return _result(money >= cost, "45 Spielminuten geschlossen · %d €" % cost if money >= cost else "Das Budget reicht für die Präparierung noch nicht.", {"cost": cost})

func groom_piste(id: int) -> Dictionary:
	var check := groom_check(id)
	if not check.ok:
		return check
	_spend(check.cost)
	asset(id).grooming_until = minute + 45
	_invalidate()
	return _result(true, "Piste für neue Routen geschlossen. Die Pistenraupe glättet Spuren und Buckel.")

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
	return Fleet.capacity(lift)

func lift_speed(lift: Dictionary) -> float:
	return Fleet.speed(lift)

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

func pedestrian_layout() -> Dictionary:
	if _foot_revision != revision:
		_foot_revision = revision
		_foot_layout = Foot.layout(terrain, lifts, buildings, walk_areas)
		for piste in pistes:
			piste.plaza_start = not Foot.attachments(_foot_layout, Terrain.unpack(piste.points[0])).is_empty()
			piste.plaza_end = not Foot.attachments(_foot_layout, Terrain.unpack(piste.points[-1])).is_empty()
		_foot_graph = {}
	return _foot_layout

func pedestrian_graph() -> Dictionary:
	var layout_value := pedestrian_layout()
	if not _foot_graph.is_empty():
		return _foot_graph
	var nodes: Dictionary = {}
	var edges: Dictionary = {}
	for area in layout_value.areas:
		nodes[area.key] = Terrain.pack(area.point)
		edges[area.key] = []
	for link in layout_value.links:
		_foot_link(edges, link.from, link.to, link.points)
	for building in buildings:
		if building.kind == "snowmaker":
			continue
		var key := "d%d" % building.id
		var hub := "f%dg" % building.id
		nodes[key] = Terrain.pack(Foot.door(building))
		edges[key] = []
		_foot_link(edges, hub, key, [nodes[hub], nodes[key]])
	for lift in lifts:
		for top in [false, true]:
			var key := "l%d%s" % [lift.id, "t" if top else "b"]
			var hub := "f%d%s" % [lift.id, "t" if top else "b"]
			nodes[key] = Terrain.pack(Foot.boarding_point(lift, top))
			edges[key] = []
			var path := Foot.path_between(Terrain.unpack(nodes[key]), Terrain.unpack(nodes[hub]), buildings, lifts)
			_foot_link(edges, key, hub, path)
	_foot_graph = {"nodes": nodes, "edges": edges}
	return _foot_graph

func _foot_link(edges: Dictionary, from: String, to: String, points: Array) -> void:
	if points.size() < 2:
		return
	var time := terrain.polyline_length(points) / Foot.WALK_SPEED
	edges[from].append(_edge(from, to, "walk", 0, points.duplicate(true), time))
	var reversed := points.duplicate(true)
	reversed.reverse()
	edges[to].append(_edge(to, from, "walk", 0, reversed, time))

func connection_anchors() -> Array:
	if _anchor_revision == revision:
		return _anchors
	var result: Array = []
	for piste in pistes:
		for index in range(piste.points.size()):
			result.append({"point": Terrain.unpack(piste.points[index]), "id": piste.id, "waypoint": index, "difficulty": piste.difficulty, "label": "Piste %d · Wegpunkt %d" % [piste.number, index + 1]})
	for lift in lifts:
		for index in range(2):
			var center := Terrain.unpack(lift.bottom if index == 0 else lift.top)
			var downhill := Vector2(terrain.height(center - Vector2(3, 0)) - terrain.height(center + Vector2(3, 0)), terrain.height(center - Vector2(0, 3)) - terrain.height(center + Vector2(0, 3))).normalized()
			if downhill.length() < 0.5:
				downhill = (Terrain.unpack(lift.bottom) - Terrain.unpack(lift.top)).normalized()
			for side in [-1, 1]:
				result.append({"point": center + downhill * side * (Foot.machine_radius(lift) + 14), "id": lift.id, "waypoint": index, "difficulty": -1, "label": "Stationsplatz · %s" % ("Tal" if index == 0 else "Berg"), "gate": "downhill" if side == 1 else "uphill", "station": center, "machine_radius": Foot.machine_radius(lift)})
	for building in buildings:
		if building.kind != "snowmaker":
			result.append({"point": Foot.forecourt(building), "id": building.id, "waypoint": 0, "difficulty": -1, "label": "Vorplatz · %s" % building.name})
	for area in walk_areas:
		result.append({"point": Terrain.unpack(area.point), "id": area.id, "waypoint": 0, "difficulty": -1, "label": area.name})
	_anchor_revision = revision
	_anchors = result
	return result

func snap_anchor(point: Vector2, radius: float = 18, start: bool = false, ignore_id: int = -1, old_points: Array = []) -> Dictionary:
	var best: Dictionary = {}
	var distance := radius
	for anchor in connection_anchors():
		if anchor.id == ignore_id: continue
		var previous := false
		for old in old_points:
			previous = previous or Terrain.unpack(old).distance_to(anchor.point) < 2
		if previous: continue
		var candidate: float = point.distance_to(anchor.point)
		if anchor.has("gate"):
			if point.distance_to(anchor.station) < anchor.machine_radius + 3:
				candidate -= 14
			if anchor.gate != ("downhill" if start else "uphill"):
				candidate += 0.75
		if candidate < distance:
			distance = candidate
			best = anchor
	return best

func _piste_node(piste: Dictionary, index: int) -> String:
	return "p%ds" % piste.id if index == 0 else ("p%de" % piste.id if index == piste.points.size() - 1 else "p%dw%d" % [piste.id, index])

func _ski_edge(piste: Dictionary, first: int, last: int, skill: int) -> Dictionary:
	var key := "%d:%d:%d:%d" % [piste.id, first, last, skill]
	if _ski_legs.has(key):
		return _ski_legs[key]
	var start := terrain.waypoint_fraction(piste.points, first)
	var end := terrain.waypoint_fraction(piste.points, last)
	var points: Array = piste.points.slice(first, last + 1)
	var motion := Motion.travel_profile(terrain, points, skill)
	var leg := _edge(_piste_node(piste, first), _piste_node(piste, last), "ski", piste.id, points, motion.minutes)
	leg.merge({"first": first, "last": last, "start_fraction": start, "end_fraction": end, "motion": motion.samples, "skill": skill})
	_ski_legs[key] = leg
	return leg

static func ski_fraction(leg: Dictionary, progress: float) -> float:
	var along := Motion.distance_progress(leg.get("motion", []), progress)
	return lerpf(leg.get("start_fraction", 0.0), leg.get("end_fraction", 1.0), along)

func _routing_graph(skill: int) -> Dictionary:
	if not _graphs.has(skill):
		_graphs[skill] = _graph(skill)
	return _graphs[skill]

func _graph(skill: int) -> Dictionary:
	var foot := pedestrian_graph()
	var nodes: Dictionary = foot.nodes.duplicate(true)
	var edges: Dictionary = foot.edges.duplicate(true)
	for lift in lifts:
		if lift_open(lift):
			var b := "l%db" % lift.id
			var t := "l%dt" % lift.id
			edges[b].push_front(_edge(b, t, "lift", lift.id, [nodes[b], nodes[t]], fleet_layout(lift).ride))
	var piste_nodes: Array = []
	for piste in pistes:
		if piste.difficulty <= skill and piste_open(piste):
			for index in range(piste.points.size()):
				var key := _piste_node(piste, index)
				nodes[key] = piste.points[index]
				piste_nodes.append(key)
				edges[key] = [_ski_edge(piste, index, index + 1, skill)] if index < piste.points.size() - 1 else []
				if index == 0 or index == piste.points.size() - 1:
					var point := Terrain.unpack(piste.points[index])
					for area in Foot.attachments(pedestrian_layout(), point):
						var path := Foot.path_between(point, area.point, buildings, lifts)
						if not path.is_empty():
							_foot_link(edges, key, area.key, path)
	# Direct piste-to-piste junctions remain exact, including internal waypoints.
	var docks: Dictionary = {}
	for key in piste_nodes:
		var point := Terrain.unpack(nodes[key])
		var cell := Vector2i(floori(point.x / 2), floori(point.y / 2))
		for x in range(-1, 2):
			for y in range(-1, 2):
				for other in docks.get(cell + Vector2i(x, y), []):
					var distance := point.distance_to(Terrain.unpack(nodes[other]))
					if distance <= 2:
						_walk_link(nodes, edges, key, other, distance)
		if not docks.has(cell):
			docks[cell] = []
		docks[cell].append(key)
	return {"nodes": nodes, "edges": edges}

func _walk_link(nodes: Dictionary, edges: Dictionary, a: String, b: String, distance: float) -> void:
	edges[a].append(_edge(a, b, "walk", 0, [nodes[a], nodes[b]], distance / 2.8))
	edges[b].append(_edge(b, a, "walk", 0, [nodes[b], nodes[a]], distance / 2.8))

func _merge_ski_legs(source: Array) -> Array:
	var result: Array = []
	for item in source:
		var leg: Dictionary = item.duplicate(true)
		if not result.is_empty() and leg.kind == "walk" and result[-1].kind == "walk" and result[-1].points.size() + leg.points.size() - 1 <= 64:
			result[-1].points.append_array(leg.points.slice(1))
			result[-1].to = leg.to
			result[-1].minutes += leg.minutes
		elif not result.is_empty() and leg.kind == "ski" and result[-1].kind == "ski" and leg.id == result[-1].id and leg.get("first", 0) == result[-1].get("last", -1):
			result[-1].points.append_array(leg.points.slice(1))
			result[-1].last = leg.last
			result[-1].end_fraction = leg.end_fraction
			result[-1].to = leg.to
			var combined := Motion.travel_profile(terrain, result[-1].points, int(leg.get("skill", 0)))
			result[-1].minutes = combined.minutes
			result[-1].motion = combined.samples
		else:
			result.append(leg)
	return result

func _heap_push(heap: Array, entry: Array) -> void:
	heap.append(entry)
	var index := heap.size() - 1
	while index > 0:
		var parent := int((index - 1) / 2)
		if heap[parent][0] <= entry[0]:
			break
		heap[index] = heap[parent]
		index = parent
	heap[index] = entry

func _heap_pop(heap: Array) -> Array:
	var first: Array = heap[0]
	var last: Array = heap.pop_back()
	if not heap.is_empty():
		var index := 0
		while index * 2 + 1 < heap.size():
			var child := index * 2 + 1
			if child + 1 < heap.size() and heap[child + 1][0] < heap[child][0]:
				child += 1
			if last[0] <= heap[child][0]:
				break
			heap[index] = heap[child]
			index = child
		heap[index] = last
	return first

func _distances(graph: Dictionary, source: String, reverse: bool) -> Dictionary:
	var edges: Dictionary = graph.edges
	if reverse:
		edges = {}
		for key in graph.nodes:
			edges[key] = []
		for key in graph.edges:
			for leg in graph.edges[key]:
				edges[leg.to].append(leg)
	var distance := {source: 0.0}
	var previous: Dictionary = {}
	var heap: Array = [[0.0, source]]
	while not heap.is_empty():
		var entry := _heap_pop(heap)
		var current: String = entry[1]
		if entry[0] > distance[current]:
			continue
		for leg in edges[current]:
			var neighbor: String = leg.from if reverse else leg.to
			var cost: float = entry[0] + leg.minutes
			if cost < distance.get(neighbor, INF):
				distance[neighbor] = cost
				previous[neighbor] = leg
				_heap_push(heap, [cost, neighbor])
	return {"distance": distance, "previous": previous}

func _shortest(graph: Dictionary, source: String, target: String) -> Dictionary:
	if not graph.nodes.has(source) or not graph.nodes.has(target):
		return {"ok": false, "legs": []}
	# All resort circuits share the valley. Two searches per ability serve every
	# destination, including thousands of internal waypoints and their branches.
	var reverse := target == "base"
	var origin := target if reverse else source
	var cache_key := "reverse:" + origin if reverse else "forward:" + origin
	if not graph.has(cache_key):
		graph[cache_key] = _distances(graph, origin, reverse)
	var paths: Dictionary = graph[cache_key]
	var current := source if reverse else target
	if not paths.distance.has(current):
		return {"ok": false, "legs": []}
	var route: Array = []
	while current != origin:
		var leg: Dictionary = paths.previous[current]
		if reverse:
			route.append(leg)
			current = leg.to
		else:
			route.push_front(leg)
			current = leg.from
	return {"ok": true, "legs": route}

func routes_for(skill: int) -> Array:
	return _routes_from(skill, "base")

func _routes_from(skill: int, source: String) -> Array:
	var key := "%d/%s" % [skill, source]
	if _routes.has(key):
		return _routes[key]
	var result: Array = []
	var graph := _routing_graph(skill)
	for piste in pistes:
		if piste.difficulty > skill or not piste_open(piste):
			continue
		var outbound := _shortest(graph, source, "p%ds" % piste.id)
		var inbound := _shortest(graph, "p%de" % piste.id, "base")
		if not outbound.ok or not inbound.ok:
			continue
		var legs: Array = outbound.legs.duplicate()
		legs.append(_ski_edge(piste, 0, piste.points.size() - 1, skill))
		legs.append_array(inbound.legs)
		var uses_lift := false
		for leg in legs:
			uses_lift = uses_lift or leg.kind == "lift"
		if uses_lift or source != "base":
			result.append({"target": piste.id, "origin": graph.nodes[source], "legs": _merge_ski_legs(legs)})
	_routes[key] = result
	return result

func route_minutes(route: Dictionary, guest: Dictionary) -> float:
	var cost := 0.0
	for leg in route.legs:
		var time: float = leg.minutes
		if leg.kind == "lift":
			var lift := asset(leg.id)
			if lift.is_empty() or not lift_open(lift):
				return INF
			time += queue_size(lift.id) * fleet_layout(lift).interval / Fleet.seats(lift) + fleet_layout(lift).interval * 0.5
		elif leg.kind == "ski":
			time *= [5.2, 7.5, 10.0][guest.ability] / Motion.style(guest.id, guest.ability).speed
		cost += time
	return cost

func choose_route(guest: Dictionary, source: String = "base") -> Dictionary:
	var choices: Array = []
	var total := 0.0
	for route in _routes_from(int(guest.ability), source):
		var time := route_minutes(route, guest)
		# No new circuit that predictably carries the guest far past closing or
		# their personal departure time. A later queue increase never teleports them.
		if minute + time > CLOSING or guest.age + time > guest.stay:
			continue
		var weight := 1.0 / (12.0 + time)
		if int(guest.get("last_piste", -1)) == int(route.target):
			weight *= 0.28
		var piste := asset(route.target)
		weight *= 1.4 if piste.difficulty == guest.ability else 1.0
		choices.append({"route": route, "weight": weight})
		total += weight
	if choices.is_empty():
		return {}
	var draw := rng.randf() * total
	for choice in choices:
		draw -= choice.weight
		if draw <= 0:
			return _with_service(choice.route, guest.id, guest.spent)
	return _with_service(choices[-1].route, guest.id, guest.spent)

func _return_from_node(guest: Dictionary, source: String) -> bool:
	var graph := _routing_graph(int(guest.ability))
	var home := _shortest(graph, source, "base")
	if not home.ok:
		return false
	if home.legs.is_empty():
		guest.phase = "leaving"
		return true
	guest.route = {"target": 0, "origin": graph.nodes[source], "legs": _merge_ski_legs(home.legs)}
	guest.leg = 0
	guest.heading_home = true
	_start_leg(guest)
	return true

func reachable_piste_ids() -> Array:
	var ids: Array = []
	for route in routes_for(2):
		ids.append(route.target)
	return ids

func _with_service(source: Dictionary, visitor_id: int, spent: bool) -> Dictionary:
	if spent:
		return source
	var graph := pedestrian_graph()
	var candidates: Array = []
	var anchors: Dictionary = {}
	for index in range(source.legs.size()):
		var leg: Dictionary = source.legs[index]
		if leg.kind == "walk" and graph.nodes.has(leg.to) and not anchors.has(leg.to):
			anchors[leg.to] = index
	for building in buildings:
		if not building.enabled or building.kind in ["snowmaker", "maintenance", "first_aid", "bus"]:
			continue
		var door_key := "d%d" % building.id
		for anchor in anchors:
			var outward := _shortest(graph, anchor, door_key)
			var back := _shortest(graph, door_key, anchor)
			if not outward.ok or not back.ok:
				continue
			var walk_time := 0.0
			for leg in outward.legs:
				walk_time += leg.minutes
			if walk_time > 65:
				continue
			var score := walk_time + float((visitor_id * 37 + int(building.id) * 23) % 80)
			candidates.append({"index": anchors[anchor], "building": building, "outward": outward.legs, "back": back.legs, "score": score})
	if candidates.is_empty():
		return source
	candidates.sort_custom(func(a, b): return a.score < b.score)
	var choice: Dictionary = candidates[0]
	var result := source.duplicate(true)
	var building: Dictionary = choice.building
	var entrance := Terrain.pack(Foot.door(building))
	var pause := _edge("d%d" % building.id, "d%d" % building.id, "visit", building.id, [entrance, entrance], 12 + visitor_id % 9)
	result.legs = source.legs.slice(0, choice.index + 1).duplicate(true) + choice.outward.duplicate(true) + [pause] + choice.back.duplicate(true) + source.legs.slice(choice.index + 1).duplicate(true)
	return result

func admit_guest(skill: int) -> bool:
	var routes := routes_for(skill)
	if guests.size() >= MAX_GUESTS or routes.is_empty() or minute >= CLOSING:
		return false
	var guest := {"id": guest_id, "ability": skill, "age": 0, "stay": rng.randi_range(300, 520), "runs": 0, "loops": 0, "leg": 0, "elapsed": 0.0, "phase": "moving", "wait": 0, "total_wait": 0, "spent": false, "ticket_paid": ticket_price, "spending": float(ticket_price), "route": {}}
	var route := choose_route(guest)
	if route.is_empty():
		return false
	guest.route = route
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
	for key in ["ride_car", "ride_seat", "ride_departure", "queue_since"]:
		guest.erase(key)
	_queue_cache.clear()
	var leg: Dictionary = guest.route.legs[guest.leg]
	guest.duration = leg.minutes
	if leg.kind == "ski":
		var piste := asset(leg.id)
		guest.duration *= [5.2, 7.5, 10.0][guest.ability] / Motion.style(guest.id, guest.ability).speed * (1.0 + Snow.roughness(piste) * 0.35)
		Snow.start(piste, guest, leg.get("start_fraction", 0), leg.get("end_fraction", 1))
	elif leg.kind == "walk":
		guest.duration *= 0.9 + float((int(guest.id) * 23) % 100) / 500
	guest.phase = "queue" if leg.kind == "lift" else "moving"
	if leg.kind == "lift":
		guest.queue_since = (day - 1) * 600 + minute - OPENING

func _finish_leg(guest: Dictionary) -> void:
	var leg: Dictionary = guest.route.legs[guest.leg]
	if leg.kind == "ski":
		var piste := asset(leg.id)
		var complete_descent: bool = leg.id == guest.route.target or (is_zero_approx(leg.get("start_fraction", 0.0)) and is_equal_approx(leg.get("end_fraction", 1.0), 1.0))
		if not piste.is_empty():
			if complete_descent:
				piste.rides += 1
			var was_open := piste_open(piste)
			piste.condition = maxf(0.0, piste.condition - 0.016 * (leg.get("end_fraction", 1.0) - leg.get("start_fraction", 0.0)) / (1.0 + 0.45 * (piste.get("level", 1) - 1)) * 20 / float(piste.get("width", 20)))
			if was_open != piste_open(piste):
				_invalidate()
		if complete_descent:
			guest.runs = guest.get("runs", 0) + 1
			total_rides += 1
			report.rides += 1
			campaign.xp += 1
	if leg.kind == "visit":
		var building := asset(leg.id)
		if not building.is_empty() and building.enabled and not guest.spent:
			var revenue: float = Catalog.BUILDINGS[building.kind].income * (1.0 + (building.get("level", 1) - 1) * 0.35) * (1.15 if Progression.has(self, "service") else 1.0)
			building.visits = building.get("visits", 0) + 1
			building.revenue = building.get("revenue", 0.0) + revenue
			money += revenue
			report.services += revenue
			campaign.turnover += revenue
			guest.spent = true
			guest.spending = float(guest.get("spending", guest.get("ticket_paid", 0))) + revenue

	if leg.kind == "ski" and int(leg.id) == int(guest.route.target):
		guest.last_piste = int(leg.id)
		guest.loops += 1
		if minute < CLOSING and not guest.get("heading_home", false):
			var onward := choose_route(guest, leg.to)
			if not onward.is_empty():
				guest.route = onward
				guest.leg = 0
				_start_leg(guest)
				return
		if _return_from_node(guest, leg.to):
			return
	if (minute >= CLOSING or guest.get("replan", false)) and not guest.get("heading_home", false):
		guest.erase("replan")
		if _return_from_node(guest, leg.to):
			return

	guest.leg += 1
	if guest.leg < guest.route.legs.size():
		_start_leg(guest)
		return
	if minute >= CLOSING or guest.get("heading_home", false) or guest.age >= guest.stay or guest.total_wait > 240:
		guest.phase = "leaving"
	else:
		var onward := choose_route(guest)
		if onward.is_empty():
			guest.phase = "leaving"
		else:
			guest.route = onward
			guest.leg = 0
			_start_leg(guest)

func _depart(guest: Dictionary) -> void:
	var appeal := 0.0
	for kind in Catalog.BUILDINGS:
		appeal += minf(building_power(kind), 3) * Catalog.BUILDINGS[kind].appeal
	if Progression.has(self, "service"):
		appeal += 6
	var satisfaction := clampf(62.0 + appeal * 0.5 + minf(guest.get("runs", guest.loops), 4) * 4.0 - (12.0 if guest.get("runs", guest.loops) == 0 else 0.0) - guest.total_wait * 0.085 - maxf(ticket_price - 48, 0) * 0.6, 5, 100)
	report.satisfaction += satisfaction
	report.departures += 1
	reputation = clampf(lerpf(reputation, satisfaction, 0.012), 10.0, 95.0)
	if satisfaction >= 80:
		campaign.happy += 1

func _reroute_guests() -> void:
	for guest in guests:
		if guest.phase == "leaving":
			continue
		var leg: Dictionary = guest.route.legs[guest.leg]
		if leg.kind != "walk" and asset(leg.id).is_empty():
			guest.phase = "leaving" # The occupied asset itself was demolished.
		elif guest.phase == "queue" and not lift_open(asset(leg.id)):
			_leave_queue(guest)
		else:
			guest.replan = true # Keep position, elapsed time and assigned vehicle.

func _leave_queue(guest: Dictionary) -> void:
	var leg: Dictionary = guest.route.legs[guest.leg]
	var lift := asset(leg.id)
	var at := guest_position(guest)
	if not _return_from_node(guest, leg.from):
		return
	# Walk out of the actual standing place instead of popping to the queue gate.
	var path := Foot.path_between(Vector2(at.x, at.z), Terrain.unpack(leg.points[0]), buildings, lifts)
	if not path.is_empty() and guest.phase != "leaving":
		guest.route.origin = path[0]
		guest.route.legs.push_front(_edge("queue", leg.from, "walk", 0, path, terrain.polyline_length(path) / Foot.WALK_SPEED))
		guest.leg = 0
		_start_leg(guest)

func arrival_capacity_factor() -> float:
	# Queues remain a visible signal to expand, without unbounded new arrivals.
	var worst_wait := 0.0
	for lift in lifts:
		if lift_open(lift):
			worst_wait = maxf(worst_wait, queue_size(lift.id) * fleet_layout(lift).interval / Fleet.seats(lift) / Fleet.TIME_SCALE)
	return clampf(1.0 / (1.0 + maxf(0, worst_wait - 2.0) * 0.23), 0.35, 1.0)

func advance_minute(arrivals: bool = true) -> void:
	if day_finished():
		return
	minute += 1
	_queue_cache.clear()
	for lift in lifts:
		if lift_running(lift):
			lift.clock = lift.get("clock", 0.0) + 1.0
	var changed_open := false
	for piste in pistes:
		if piste.get("grooming_until", 0) > 0 and minute >= piste.grooming_until:
			piste.grooming_until = 0
			Snow.groom(piste, 1.0)
			piste.condition = 100.0
			snow_revision += 1
			changed_open = true
		var was_open := piste_open(piste)
		piste.snow = maxf(0.0, piste.snow - maxf(weather().temperature, 0.0) * 0.018)
		if weather().temperature <= -1:
			for building in buildings:
				if building.enabled and building.kind == "snowmaker":
					if terrain.point_on_path(piste.points, 0.5).distance_to(Terrain.unpack(building.point)) <= 150 + 20 * (building.get("level", 1) - 1):
						piste.snow = minf(110.0, piste.snow + 0.035 * building.get("level", 1))
		changed_open = changed_open or was_open != piste_open(piste)
	if changed_open:
		_invalidate()
	if arrivals and minute < CLOSING - 85:
		var day_event := Progression.event(self)
		var campaign_bonus: float = 1.0 + (campaign.rank - 1) * 0.08 + (0.15 if Progression.has(self, "marketing") else 0.0)
		var demand: float = 0.20 * (0.7 + reputation / 90.0 + building_power("hotel") * 0.35) * weather().demand * pow(42.0 / ticket_price, 1.3) * day_event.demand * campaign_bonus * (1.1 if building_count("bus") > 0 else 1.0)
		demand *= arrival_capacity_factor()
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
			if guest.wait > 180 or not lift_open(asset(guest.route.legs[guest.leg].id)):
				_leave_queue(guest)
		else:
			var leg: Dictionary = guest.route.legs[guest.leg]
			var duration: float = guest.get("duration", leg.minutes)
			var previous: float = guest.elapsed / duration
			if leg.kind == "lift":
				guest.elapsed = maxf(0, asset(leg.id).get("clock", 0.0) - guest.get("ride_departure", 0.0))
			else:
				guest.elapsed += 1.0
			if leg.kind == "ski":
				Snow.touch(terrain, asset(leg.id), guest, ski_fraction(leg, previous), ski_fraction(leg, guest.elapsed / duration))
				snow_revision += 1
			if guest.elapsed >= duration:
				_finish_leg(guest)
	for guest in departures:
		guests.erase(guest)
	# Board the real vehicle that crossed the loading point, with unique seats.
	for lift in lifts:
		if lift_open(lift):
			_board_lift(lift)
	_queue_cache.clear()
	_check_achievements()
	Progression.refresh(self)
	if minute >= CLOSING and guests.is_empty():
		_close_day()

func queued_guests(id: int) -> Array:
	if _queue_cache.has(id):
		return _queue_cache[id]
	var result: Array = []
	for guest in guests:
		if guest.phase == "queue" and guest.route.legs[guest.leg].id == id:
			result.append(guest)
	result.sort_custom(func(a, b):
		var a_time: float = a.get("queue_since", a.age - a.wait)
		var b_time: float = b.get("queue_since", b.age - b.wait)
		return a.id < b.id if is_equal_approx(a_time, b_time) else a_time < b_time
	)
	_queue_cache[id] = result
	var ranks: Dictionary = {}
	for index in range(result.size()):
		ranks[int(result[index].id)] = index
	_queue_cache["rank:%d" % id] = ranks
	return result

func _board_lift(lift: Dictionary) -> void:
	var schedule := fleet_layout(lift)
	var clock: float = lift.clock
	var first := floori((clock - 1.0 + 0.000001) / schedule.interval) + 1
	var last := floori((clock + 0.000001) / schedule.interval)
	var queue := queued_guests(lift.id).duplicate()
	for serial in range(first, last + 1):
		var boarded := 0
		var departure: float = serial * schedule.interval
		for seat in range(schedule.seats):
			if queue.is_empty():
				break
			var departed_at: float = (day - 1) * 600 + minute - OPENING - (clock - departure)
			if queue[0].get("queue_since", 0) > departed_at + 0.000001:
				break
			var guest: Dictionary = queue.pop_front()
			guest.phase = "moving"
			guest.ride_car = serial % schedule.count
			guest.ride_seat = seat
			guest.ride_departure = departure
			guest.duration = schedule.ride
			guest.elapsed = clock - departure
			lift.boarded += 1
			boarded += 1
		lift.last_load = boarded
		lift.recent_departures.append({"clock": departure, "load": boarded})
		while lift.recent_departures.size() > 24:
			lift.recent_departures.pop_front()

func queue_position(lift: Dictionary, index: int) -> Vector3:
	if not _queue_slots.has(lift.id):
		var slots: Array[Vector2] = []
		var r := Fleet.rope_offset(lift)
		var front := Foot.machine_radius(lift) + 9
		for i in range(5):
			var point := Vector2(-r, -front - 2.3 * i)
			if _queue_local_free(lift, point):
				slots.append(point)
		for row in range(7):
			for i in range(16):
				var col := i if row % 2 == 0 else 15 - i
				var point := Vector2(-r + col * 1.8, -front - 12 - row * 2.4)
				if point.length() < Foot.station_radius(lift, false) - 1 and _queue_local_free(lift, point):
					slots.append(point)
		# Overflow uses the remaining plaza surface, keeping even stress queues
		# out of the machinery and giving every visitor a distinct standing place.
		var radius := Foot.station_radius(lift, false)
		for row in range(-18, 19):
			for column in range(-18, 19):
				if slots.size() >= MAX_GUESTS:
					break
				var point := Vector2(column * 2.4, row * 2.4)
				if point.length() > radius - 1 or point.length() < Foot.machine_radius(lift) + 3 or not _queue_local_free(lift, point):
					continue
				var clear := true
				for previous in slots:
					if previous.distance_to(point) < 1.65:
						clear = false
						break
				if clear:
					slots.append(point)
		_queue_slots[lift.id] = slots
	var slots: Array = _queue_slots[lift.id]
	var local: Vector2 = slots[clampi(index, 0, slots.size() - 1)]
	var offset := Fleet.basis(lift) * Vector3(local.x, 0, local.y)
	return terrain.world(Terrain.unpack(lift.bottom) + Vector2(offset.x, offset.z), 0.3)

func _queue_local_free(lift: Dictionary, point: Vector2) -> bool:
	var offset := Fleet.basis(lift) * Vector3(point.x, 0, point.y)
	var at := Terrain.unpack(lift.bottom) + Vector2(offset.x, offset.z)
	if not Foot.contains(pedestrian_layout(), at) or not Foot.free_of_buildings(at, buildings, 2):
		return false
	for other in lifts:
		if other.id == lift.id:
			continue
		for station in [other.bottom, other.top]:
			if at.distance_to(Terrain.unpack(station)) < Foot.machine_radius(other) + 2:
				return false
	return true

func lift_load(lift: Dictionary) -> Dictionary:
	if not _queue_cache.has("loads"):
		var loads: Dictionary = {}
		for guest in guests:
			if guest.phase == "moving" and guest.leg < guest.route.legs.size() and guest.route.legs[guest.leg].kind == "lift":
				var id: int = guest.route.legs[guest.leg].id
				loads[id] = loads.get(id, 0) + 1
		_queue_cache["loads"] = loads
	var occupied: int = _queue_cache.loads.get(int(lift.id), 0)
	var loaded := 0
	for departure in lift.get("recent_departures", []):
		loaded += departure.load
	var count: int = lift.get("recent_departures", []).size()
	return {"riders": occupied, "queue": queue_size(lift.id), "fill": float(loaded) / maxf(count * Fleet.seats(lift), 1), "wait": queue_size(lift.id) * fleet_layout(lift).interval / Fleet.seats(lift), "seats": Fleet.seats(lift), "carriers": fleet_layout(lift).count}

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
	var amount := 450.0 + lifts.size() * 80 + buildings.size() * 35
	for area in walk_areas:
		amount += area.radius * (0.35 if area.enabled else 0.08)
	for lift in lifts:
		amount += Catalog.LIFTS[lift.kind].upkeep * (1.0 if lift.enabled else 0.25) * (1.0 + 0.18 * (lift.get("level", 1) - 1))
	for building in buildings:
		amount += Catalog.BUILDINGS[building.kind].upkeep * (1.0 if building.enabled else 0.2) * (1.0 + 0.2 * (building.get("level", 1) - 1))
	for piste in pistes:
		amount += piste.length * (0.4 if piste.enabled else 0.08) * float(piste.get("width", 20)) / 20
	return amount * (0.85 if Progression.has(self, "efficient_snow") else 1.0) + (450.0 if loan > 0 else 0.0)

func _close_day() -> void:
	if day_finished() or not guests.is_empty():
		return
	report.costs = operating_costs()
	money -= report.costs
	Progression.finish_day(self)
	report.closed_at = minute
	last_report = report.duplicate(true)

func next_day() -> bool:
	if not day_finished():
		return false
	for piste in pistes:
		piste.snow = minf(110.0, piste.snow + weather().snowfall * Maps.spec(map_id).snow)
		piste.grooming_until = 0
		Snow.groom(piste, 0.94 if building_count("maintenance") > 0 else 0.72)
		piste.condition = minf(100.0, piste.condition + 32.0 + building_power("maintenance") * 24 + (piste.get("level", 1) - 1) * 5 + (12 if Progression.has(self, "efficient_snow") else 0))
	for lift in lifts:
		lift.recent_departures.clear()
		lift.last_load = 0
	snow_revision += 1
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

func guest_position(guest: Dictionary, fraction_tick: float = 0.0) -> Vector3:
	if guest.phase == "leaving":
		return terrain.world(Terrain.BASE)
	var leg: Dictionary = guest.route.legs[guest.leg]
	var fraction := clampf((guest.elapsed + fraction_tick) / guest.get("duration", leg.minutes), 0, 1)
	if guest.phase == "queue":
		var lift := asset(leg.id)
		queued_guests(lift.id)
		return queue_position(lift, _queue_cache["rank:%d" % int(lift.id)].get(int(guest.id), 0))
	var point := terrain.point_on_path(leg.points, fraction)
	if leg.kind == "visit":
		return terrain.world(Foot.door(asset(leg.id)))
	if leg.kind == "lift":
		return rider_pose(guest, fraction_tick).transform.origin
	if leg.kind == "ski":
		var piste := asset(leg.id)
		fraction = ski_fraction(leg, fraction)
		point = Motion.position(terrain, piste, guest.id, guest.ability, fraction, guest.loops, leg.get("start_fraction", 0), leg.get("end_fraction", 1))
		var center: Vector2 = terrain.point_on_path(piste.points, fraction)
		var side: Vector2 = (terrain.point_on_path(piste.points, minf(1, fraction + 0.005)) - center).normalized().orthogonal()
		return terrain.world(point, Snow.mesh_height(piste, fraction, (point - center).dot(side)) - 0.05)
	return terrain.world(point, 0.3)

func snapshot() -> Dictionary:
	pedestrian_layout()
	var visitor_data: Array = []
	var itineraries: Array = []
	var route_ids: Dictionary = {}
	for guest in guests:
		var copy: Dictionary = guest.duplicate()
		copy.erase("route")
		copy.target = guest.route.target
		copy.route_index = -1
		if guest.phase != "leaving":
			var signature := JSON.stringify(guest.route)
			if not route_ids.has(signature):
				route_ids[signature] = itineraries.size()
				itineraries.append(guest.route.duplicate(true))
			copy.route_index = route_ids[signature]
		else:
			copy.leg = 0
		visitor_data.append(copy)
	return {"version": 8, "map_id": map_id, "campaign": campaign.duplicate(true), "money": money, "day": day, "minute": minute, "reputation": reputation, "ticket_price": ticket_price, "weather_index": weather_index, "loan": loan, "total_guests": total_guests, "total_rides": total_rides, "next_id": next_id, "guest_id": guest_id, "pistes": pistes.duplicate(true), "lifts": lifts.duplicate(true), "buildings": buildings.duplicate(true), "walk_areas": walk_areas.duplicate(true), "guests": visitor_data, "itineraries": itineraries, "achievements": achievements.duplicate(), "report": report.duplicate(true), "last_report": last_report.duplicate(true), "rng_seed": str(rng.seed), "rng_state": str(rng.state)}

func _checked_itinerary(value: Variant, skill: int) -> Dictionary:
	if not value is Dictionary or not Terrain.number(value.get("target")) or not value.get("legs") is Array or value.legs.is_empty() or value.legs.size() > 220:
		return {}
	var previous := Terrain.unpack(value.get("origin", Terrain.pack(Terrain.BASE)))
	if not terrain.contains(previous):
		return {}
	var has_lift := false
	var has_target := false
	for leg in value.legs:
		if not leg is Dictionary or leg.get("kind") not in ["walk", "lift", "ski", "visit"] or not Terrain.number(leg.get("id")) or leg.id != floorf(leg.id) or leg.id < 0 or not leg.get("points") is Array or leg.points.size() < 2 or leg.points.size() > 64 or not Terrain.number(leg.get("minutes")) or leg.minutes < 0.15 or leg.minutes > 1000000:
			return {}
		for point in leg.points:
			if not terrain.contains(Terrain.unpack(point)):
				return {}
		if previous.distance_to(Terrain.unpack(leg.points[0])) > 0.01:
			return {}
		previous = Terrain.unpack(leg.points.back())
		if leg.kind == "walk":
			if leg.id != 0 or not Foot.valid_walk(pedestrian_layout(), leg.points, buildings):
				return {}
		else:
			var item := asset(int(leg.id))
			if item.is_empty():
				return {}
			var expected: Array
			if leg.kind == "lift":
				if not item.has("bottom"):
					return {}
				expected = [Terrain.pack(Foot.boarding_point(item, false)), Terrain.pack(Foot.boarding_point(item, true))]
				has_lift = true
			elif leg.kind == "visit":
				if not item.has("kind") or not Catalog.BUILDINGS.has(item.kind) or item.has("bottom") or item.kind == "snowmaker":
					return {}
				var entrance := Terrain.pack(Foot.door(item))
				expected = [entrance, entrance]
			else:
				if not item.has("difficulty") or item.difficulty > skill:
					return {}
				var first: Variant = leg.get("first", 0)
				var last: Variant = leg.get("last", item.points.size() - 1)
				if not Terrain.number(first) or not Terrain.number(last) or first != floorf(first) or last != floorf(last) or first < 0 or last >= item.points.size() or first >= last:
					return {}
				expected = item.points.slice(int(first), int(last) + 1)
				var start_fraction := terrain.waypoint_fraction(item.points, int(first))
				var end_fraction := terrain.waypoint_fraction(item.points, int(last))
				if not Terrain.number(leg.get("start_fraction", start_fraction)) or not Terrain.number(leg.get("end_fraction", end_fraction)) or absf(leg.get("start_fraction", start_fraction) - start_fraction) > 0.00001 or absf(leg.get("end_fraction", end_fraction) - end_fraction) > 0.00001:
					return {}
				if not Motion.valid_profile(leg.get("motion", [])):
					return {}
				leg.start_fraction = start_fraction
				leg.end_fraction = end_fraction
				has_target = has_target or item.id == value.target
			if expected.size() != leg.points.size():
				return {}
			for i in range(expected.size()):
				if Terrain.unpack(expected[i]).distance_to(Terrain.unpack(leg.points[i])) > 0.01:
					return {}
	return value.duplicate(true) if (has_target or int(value.target) == 0) and previous.distance_to(Terrain.BASE) < 0.01 else {}

func restore(data: Dictionary) -> Dictionary:
	# Validate into a separate instance, so a failed load never damages this game.
	var candidate = get_script().new()
	var check: Dictionary = candidate._restore_checked(data)
	if not check.ok:
		return check
	for key in ["map_id", "terrain", "money", "day", "minute", "reputation", "ticket_price", "weather_index", "loan", "total_guests", "total_rides", "next_id", "guest_id", "pistes", "lifts", "buildings", "walk_areas", "guests", "achievements", "report", "last_report", "campaign"]:
		set(key, candidate.get(key))
	snow_revision += 1
	rng.seed = candidate.rng.seed
	rng.state = candidate.rng.state
	_invalidate()
	return _result(true, "Spielstand geladen.")

func _restore_checked(data: Dictionary) -> Dictionary:
	var invalid := _result(false, "Der Spielstand ist unvollständig oder beschädigt.")
	if data.get("version") != 1 and data.get("version") != 2 and data.get("version") != 3 and data.get("version") != 4 and data.get("version") != 5 and data.get("version") != 6 and data.get("version") != 7 and data.get("version") != 8:
		return _result(false, "Diese Spielstand-Version wird nicht unterstützt.")
	var area: Variant = data.get("map_id", "sonnenhang")
	if not area is String or not Maps.MAPS.has(area):
		return invalid
	map_id = area
	terrain = Mountain.new(map_id)
	var ranges := {"money": [-100000000, 1000000000], "day": [1, 100000], "minute": [OPENING, 1000000], "reputation": [0, 100], "ticket_price": [20, 95], "weather_index": [0, Catalog.WEATHER.size() - 1], "loan": [0, 150000], "total_guests": [0, 1000000000], "total_rides": [0, 1000000000], "next_id": [1, 1000000], "guest_id": [1, 1000000000]}
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
	for lift in data.lifts:
		if not lift is Dictionary or not Terrain.number(lift.get("id")) or not lift.get("name") is String or not lift.get("kind") is String or not Catalog.LIFTS.has(lift.kind) or not terrain.contains(Terrain.unpack(lift.get("bottom"))) or not terrain.contains(Terrain.unpack(lift.get("top"))):
			return invalid
		if data.version < 5 and lift.kind == "drag" and _lift_profile("drag", Terrain.unpack(lift.bottom), Terrain.unpack(lift.top)).length > Catalog.LIFTS.drag.max_length:
			lift.kind = "chair"
			lift.name = "4er-Sessellift %d" % lift.id

	if data.version < 6:
		data.walk_areas = []
	if not data.get("walk_areas") is Array or data.walk_areas.size() > 80:
		return invalid
	var used_ids: Array = []
	var piste_numbers: Array = []
	for key in ["pistes", "lifts", "buildings", "walk_areas"]:
		for item in data[key]:
			if not item is Dictionary or not Terrain.number(item.get("id")) or int(item.id) != item.id or item.id < 1 or item.id >= data.next_id or used_ids.has(item.id):
				return invalid
			used_ids.append(item.id)
			if not Edit.valid_color(item.get("color", "")) or not Terrain.number(item.get("rotation", 0)) or item.get("rotation", 0) != floorf(item.get("rotation", 0)) or item.get("rotation", 0) < 0 or item.get("rotation", 0) > 3:
				return invalid
			if not Terrain.number(item.get("width", 20)) or item.get("width", 20) < 14 or item.get("width", 20) > 36:
				return invalid
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
			if key == "walk_areas":
				if not item.get("kind") is String or not Catalog.PLAZAS.has(item.kind) or not terrain.contains(Terrain.unpack(item.get("point"))) or not Terrain.number(item.get("radius")) or item.radius != Catalog.PLAZAS[item.kind].radius:
					return invalid
			elif key == "pistes":
				if not item.get("points") is Array or not Terrain.number(item.get("difficulty")) or int(item.difficulty) != item.difficulty or item.difficulty < 0 or item.difficulty > 2:
					return invalid
				if data.version < 6:
					item.points = Foot.prepare_piste(item.points, data.lifts)
				var analysis := terrain.analyse(item.points)
				if not analysis.ok:
					return invalid
				for field in ["condition", "snow", "rides"]:
					if not Terrain.number(item.get(field)) or item[field] < 0 or item[field] > (1000000000 if field == "rides" else 110):
						return invalid
				if data.version >= 4:
					if not Terrain.number(item.get("number")) or item.number != floorf(item.number) or item.number < 1 or item.number > 1000000 or piste_numbers.has(int(item.number)) or (data.version >= 6 and item.difficulty != analysis.difficulty):
						return invalid
				else:
					item.number = piste_numbers.size() + 1
					if item.name.begins_with(Terrain.PISTE_NAMES[int(item.difficulty)]):
						item.name = "%s %d" % [Terrain.PISTE_NAMES[analysis.difficulty], item.number]
				if data.version < 5 and item.name.begins_with(Terrain.PISTE_NAMES[int(item.difficulty)]):
					item.name = "%s %d" % [Terrain.PISTE_NAMES[analysis.difficulty], item.number]
				piste_numbers.append(int(item.number))
				item.difficulty = analysis.difficulty
				item.horizontal = analysis.horizontal
				item.drop = analysis.drop
				item.average = analysis.average
				if data.version < 6 and not Snow.migrate_length(item, analysis.length):
					return invalid
				item.length = analysis.length
				if not Terrain.number(item.get("grooming_until", 0)) or item.get("grooming_until", 0) < 0 or item.get("grooming_until", 0) > CLOSING:
					return invalid
				if not Snow.validate(item):
					return invalid
				item.grade = analysis.grade
			elif key == "lifts":
				if not item.get("kind") is String or not preview_lift(item.kind, Terrain.unpack(item.get("bottom")), Terrain.unpack(item.get("top")), false).ok:
					return invalid
				for field in ["credit", "boarded"]:
					if not Terrain.number(item.get(field)) or item[field] < 0 or item[field] > 1000000000:
						return invalid
				item.length = _lift_profile(item.kind, Terrain.unpack(item.bottom), Terrain.unpack(item.top)).length
				if data.version >= 5:
					if not Terrain.number(item.get("clock")) or item.clock < 0 or item.clock > 60000000 or not item.get("recent_departures") is Array or item.recent_departures.size() > 24:
						return invalid
					for departure in item.recent_departures:
						if not departure is Dictionary or not Terrain.number(departure.get("clock")) or departure.clock < 0 or departure.clock > item.clock or not Terrain.number(departure.get("load")) or departure.load < 0 or departure.load > Fleet.seats(item) or departure.load != floorf(departure.load):
							return invalid
				else:
					item.clock = 0.0
					item.last_load = 0
					item.recent_departures = []
				item.credit = 0.0
			else:
				if not item.get("kind") is String or not Catalog.BUILDINGS.has(item.kind) or not terrain.contains(Terrain.unpack(item.get("point"))):
					return invalid
				for field in ["visits", "revenue"]:
					if not Terrain.number(item.get(field, 0)) or item.get(field, 0) < 0 or item.get(field, 0) > 1000000000:
						return invalid
				item.visits = item.get("visits", 0)
				item.revenue = item.get("revenue", 0.0)
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
	walk_areas = data.walk_areas.duplicate(true)
	achievements.clear()
	for achievement in data.achievements:
		achievements.append(int(achievement))
	report = data.report.duplicate(true)
	report.investments = report.get("investments", 0.0)
	last_report = data.last_report.duplicate(true)
	_invalidate()
	if not Progression.restore(self, data.get("campaign")):
		return invalid
	var occupied_seats: Dictionary = {}
	var saved_routes: Variant = data.get("itineraries", [])
	if not saved_routes is Array or saved_routes.size() > MAX_GUESTS:
		return invalid
	var route_cache: Dictionary = {}
	var visitor_ids: Array = []
	for visitor in data.guests:
		if not visitor is Dictionary:
			return invalid
		for field in ["id", "ability", "age", "stay", "loops", "leg", "elapsed", "wait", "total_wait", "target"]:
			if not Terrain.number(visitor.get(field)) or visitor[field] < 0 or visitor[field] > 1000000000:
				return invalid
		if visitor.ability > 2 or int(visitor.ability) != visitor.ability or visitor.id >= guest_id or visitor_ids.has(visitor.id) or not visitor.get("spent") is bool or visitor.get("phase") not in ["moving", "queue", "leaving"]:
			return invalid
		if not Terrain.number(visitor.get("runs", 0)) or visitor.get("runs", 0) < 0 or visitor.get("runs", 0) > 1000000000 or visitor.get("runs", 0) != floorf(visitor.get("runs", 0)):
			return invalid
		for field in ["ticket_paid", "spending"]:
			if visitor.has(field) and (not Terrain.number(visitor[field]) or visitor[field] < 0 or visitor[field] > 1000000000):
				return invalid
		for field in ["heading_home", "replan"]:
			if visitor.has(field) and not visitor[field] is bool:
				return invalid
		if visitor.has("last_piste") and (not Terrain.number(visitor.last_piste) or visitor.last_piste < 0 or visitor.last_piste != floorf(visitor.last_piste)):
			return invalid
		visitor_ids.append(visitor.id)
		var route: Dictionary = {}
		if data.version >= 6:
			var index: Variant = visitor.get("route_index")
			if not Terrain.number(index) or index != floorf(index):
				return invalid
			if visitor.phase == "leaving":
				route = {"target": 0, "legs": []}
			else:
				if index < 0 or index >= saved_routes.size():
					return invalid
				var key := "%d/%d" % [index, visitor.ability]
				if not route_cache.has(key):
					route_cache[key] = _checked_itinerary(saved_routes[int(index)], int(visitor.ability))
				route = route_cache[key]
				if route.is_empty() or route.target != visitor.target:
					return invalid
		else:
			for option in routes_for(int(visitor.ability)):
				if option.target == visitor.target:
					route = option
			if route.is_empty():
				continue # Legacy visitors are reassigned after terminals gain plazas.
		if data.version < 6:
			var migrated: Dictionary = visitor.duplicate(true)
			migrated.route = _with_service(route, int(visitor.id), visitor.spent)
			migrated.leg = 0
			migrated.erase("target")
			_start_leg(migrated)
			guests.append(migrated)
			continue

		if int(visitor.leg) != visitor.leg or visitor.leg > route.legs.size() or (visitor.leg == route.legs.size() and visitor.phase != "leaving"):
			return invalid
		if visitor.phase == "queue" and route.legs[int(visitor.leg)].kind != "lift":
			return invalid
		var copy: Dictionary = visitor.duplicate(true)
		copy.route = route
		if data.version >= 3:
			if not Terrain.number(copy.get("duration", 1.0) if copy.phase == "leaving" else copy.get("duration")) or copy.get("duration", 1.0) < 0.15 or copy.get("duration", 1.0) > 1000000 or (copy.has("track") and (not copy.track is String or copy.track.length() > 80)):
				return invalid
		elif copy.phase != "leaving":
			var leg: Dictionary = route.legs[int(copy.leg)]
			var scale: float = TRANSPORT_SCALE if leg.kind == "lift" else ((140.0 + copy.ability * 55) / ([5.2, 7.5, 10.0][copy.ability] * 2) if leg.kind == "ski" else 75.0 / 2.8)
			copy.duration = leg.minutes
			copy.elapsed = minf(copy.duration, copy.elapsed * scale)
			if leg.kind == "ski":
				Snow.start(asset(leg.id), copy)
		if copy.phase == "queue":
			if not Terrain.number(copy.get("queue_since")) or copy.queue_since < 0 or copy.queue_since > (day - 1) * 600 + minute - OPENING:
				return invalid
		elif copy.phase == "moving" and route.legs[int(copy.leg)].kind == "lift":
			var lift := asset(int(route.legs[int(copy.leg)].id))
			var schedule := fleet_layout(lift)
			for field in ["ride_car", "ride_seat", "ride_departure"]:
				if not Terrain.number(copy.get(field)) or copy[field] < 0:
					return invalid
			if copy.ride_car != floorf(copy.ride_car) or copy.ride_seat != floorf(copy.ride_seat) or copy.ride_car >= schedule.count or copy.ride_seat >= schedule.seats or copy.ride_departure > lift.clock or absf(copy.elapsed - (lift.clock - copy.ride_departure)) > 0.001 or copy.elapsed >= schedule.ride + 0.001 or absf(copy.duration - schedule.ride) > 0.001:
				return invalid
			var serial := roundi(copy.ride_departure / schedule.interval)
			if absf(copy.ride_departure - serial * schedule.interval) > 0.001 or int(copy.ride_car) != serial % schedule.count:
				return invalid
			var seat_key := "%d/%d/%d" % [lift.id, copy.ride_car, copy.ride_seat]
			if occupied_seats.has(seat_key):
				return invalid
			occupied_seats[seat_key] = true

		copy.erase("target")
		guests.append(copy)
	rng.seed = int(data.rng_seed)
	rng.state = int(data.rng_state)
	if not Progression.restore(self, data.get("campaign")):
		return invalid
	return _result(true, "Spielstand geprüft.")

func preview_change(id: int, points: Array, rotation_value: int = 0, width: float = 20) -> Dictionary:
	return Edit.preview(self, id, points, rotation_value, width)

func change_asset(id: int, points: Array, title: String, color: String, rotation_value: int = 0, width: float = 20) -> Dictionary:
	return Edit.apply(self, id, points, title, color, rotation_value, width)
