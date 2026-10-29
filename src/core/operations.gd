extends RefCounted
## One deterministic operating clock: staffing, failures, work orders and nights.
const L = preload("res://src/core/i18n.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Foot = preload("res://src/core/foot_network.gd")
const Needs = preload("res://src/core/guest_needs.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const Progression = preload("res://src/core/progression.gd")
const Geo = preload("res://src/core/real_resorts.gd")
const ROLES := {
	"operator": {"name": "Liftbedienung", "wage": 18.0},
	"technician": {"name": "Seilbahntechnik", "wage": 27.0},
	"electrician": {"name": "Elektrik", "wage": 26.0},
	"driver": {"name": "Pistenraupenfahrer", "wage": 23.0},
	"rescue": {"name": "Pistenrettung", "wage": 25.0},
	"snow": {"name": "Schneemeister", "wage": 23.0},
	"hotel": {"name": "Hotelpersonal", "wage": 18.0},
	"catering": {"name": "Gastronomiepersonal", "wage": 18.0},
	"security": {"name": "Reinigung & Sicherheit", "wage": 19.0}
}
const SHIFTS := {"day": [420, 1080], "evening": [960, 120], "night": [0, 480], "early": [420, 900], "late": [900, 1380]}
const SHIFT_NAMES := {"day": "Tag · 07–18 Uhr", "evening": "Abend · 16–02 Uhr", "night": "Nacht · 00–08 Uhr", "early": "Früh · 07–15 Uhr", "late": "Spät · 15–23 Uhr"}
const GOALS := {
	"braunlage": ["Stationspersonal einstellen", "Technikzentrale und Reparaturteam aufbauen", "Defekten Lift reparieren", "Pistenraupe kaufen und Pisten präparieren", "100 zufriedene Gäste begrüßen"],
	"filzmoos": ["Alle geöffneten Stationen besetzen", "Bergrettung einsatzbereit machen", "Pisten präparieren", "Wartezeiten unter 12 Minuten halten", "Zwei wirtschaftliche Betriebstage"],
	"kitzbuehel": ["Verbindungslift reparieren", "Mittelstationen vollständig besetzen", "Ersatzteile vorrätig halten", "Wartezeiten unter 15 Minuten halten", "300 Gäste und positives Betriebsergebnis"],
	"seiseralm": ["Rettung und Technik koordinieren", "Drei Pistenraupen einsetzen", "Hotel und Abendangebot betreiben", "Alle geöffneten Stationen besetzen", "Drei wirtschaftliche Betriebstage"]
}

static func initial() -> Dictionary:
	return {"enabled": false, "continuous": false, "staff": [], "next_staff": 1, "vehicles": [], "next_vehicle": 1, "repairs": [], "incidents": [], "next_incident": 1, "parts": 2, "delivery_at": -1, "history": [], "goals": [], "completed": false, "repairs_done": 0, "groomed": 0, "rescued": 0, "scenario": "", "scenario_day": 1, "payroll": 0.0, "cost_centres": {}, "event_day": 0, "event": "", "room_price": 140, "auto_groom": true}

static func group_size(model: RefCounted) -> int:
	return [1, 2, 8, 5][Geo.IDS.find(model.map_id)] if model.map_id in Geo.IDS else 1

static func clock(model: RefCounted) -> int:
	return (model.day - 1) * 1440 + model.minute

static func enable(model: RefCounted, scenario: String = "") -> void:
	model.operations = initial()
	model._topology.clear()
	model.operations.enabled = true
	model.operations.continuous = true
	model.operations.scenario = scenario
	model._duty_cache.clear()
	# A classic starter inherits a working team. Scenarios deliberately begin
	# with missing assignments; the briefing names the first actionable problem.
	if scenario == "":
		for lift in model.lifts: fill_stations(model, lift.id, true)
		for building in model.buildings: fill_building(model, building.id, true)
	else:
		for lift in model.lifts:
			if lift.id != model.lifts[0].id: fill_stations(model, lift.id, true)
		for building in model.buildings: fill_building(model, building.id, true)
		var victim: Dictionary = model.lifts[mini(1, model.lifts.size() - 1)] if not model.lifts.is_empty() else {}
		if not victim.is_empty():
			victim.fault = "mechanical"
			victim.wear = 78.0
		if scenario == "filzmoos" and not model.pistes.is_empty(): model.pistes[0].condition = 24.0
		model.operations.parts = 0 if scenario in ["kitzbuehel", "seiseralm"] else 2
	refresh_duty(model)
	model._operating_signature = signature(model)
	model._operational_change()

static func active(model: RefCounted) -> bool:
	return model.operations.get("enabled", false)

static func admit_evening(model: RefCounted) -> bool:
	if model.guests.size() >= model.MAX_GUESTS: return false
	var guest := {"id": model.guest_id, "sport": "ski", "ability": 0, "age": 0, "stay": 900, "runs": 0, "loops": 0, "leg": 0, "elapsed": 0.0, "phase": "moving", "wait": 0, "total_wait": 0, "spent": false, "ticket_paid": 0, "spending": 0.0, "route": {}, "evening": true}
	Needs.ensure(guest, model.weather().temperature)
	guest.needs.joy = 8.0
	guest.needs.energy = 15.0
	guest.needs.hunger = 60.0
	var route: Dictionary = model.service_route(guest)
	if route.is_empty(): return false
	guest.route = route
	model.guests.append(guest)
	model.guest_id += 1
	model.total_guests += 1
	model.report.guests += 1
	model._start_leg(guest)
	return true

static func continuous(model: RefCounted) -> bool:
	return model.operations.get("continuous", false)

static func shift_active(shift: String, minute: int) -> bool:
	var times: Array = SHIFTS.get(shift, SHIFTS.day)
	return minute >= times[0] and minute < times[1] if times[0] < times[1] else minute >= times[0] or minute < times[1]

static func on_duty(model: RefCounted, person: Dictionary) -> bool:
	return shift_active(person.shift, model.minute) and int(person.get("absent_until", 0)) <= clock(model) and int(person.get("break_until", 0)) <= clock(model)

static func refresh_duty(model: RefCounted) -> void:
	model._duty_cache = {"_complete": true}
	for person in model.operations.staff:
		if not on_duty(model, person): continue
		var key: String = person.role + ":" + person.assignment
		var role_key: String = person.role + ":"
		model._duty_cache[key] = int(model._duty_cache.get(key, 0)) + 1
		model._duty_cache[role_key] = int(model._duty_cache.get(role_key, 0)) + 1

static func signature(model: RefCounted) -> String:
	var result := "%d/" % int(model.minute >= 480 and model.minute < 1020)
	for lift in model.lifts: result += "%d:%d/" % [int(lift.id), int(lift.enabled and lift_available(model, lift))]
	return result

static func duty(model: RefCounted, role: String, target: String = "") -> int:
	var key := role + ":" + target
	if model._duty_cache.get("_complete", false): return int(model._duty_cache.get(key, 0))
	if not model._duty_cache.has(key):
		var count := 0
		for person in model.operations.staff:
			if person.role == role and (target == "" or person.assignment == target) and on_duty(model, person): count += 1
		model._duty_cache[key] = count
	return int(model._duty_cache[key])

static func station_demands(lift: Dictionary) -> Array:
	var family: String = Catalog.LIFTS[lift.kind].family
	var minimum := 3 if int(lift.get("occupancy", 8)) > 16 else (2 if family == "gondola" or lift.kind in ["chair6", "chair8"] else 1)
	var result: Array = []
	for top in [false, true]:
		var point: Array = lift.top if top else lift.bottom
		var key := "station:%s:%.1f:%.1f" % [str(lift.get("line", lift.id)), point[0], point[1]]
		result.append({"key": key, "minimum": minimum, "top": top, "point": point})
	return result

static func staffing(model: RefCounted, lift: Dictionary) -> Dictionary:
	var present := 0
	var needed := 0
	var safe := true
	for station in station_demands(lift):
		var count := duty(model, "operator", station.key)
		present += mini(count, station.minimum)
		needed += station.minimum
		safe = safe and count >= station.minimum
	return {"ok": safe, "present": present, "needed": needed}

static func lift_available(model: RefCounted, lift: Dictionary) -> bool:
	if not active(model): return true
	if lift.get("fault", "") != "" or not staffing(model, lift).ok: return false
	return model.minute >= 480 and model.minute < 1020

static func hire(model: RefCounted, role: String, assignment: String, shift: String = "day", free: bool = false) -> Dictionary:
	if not ROLES.has(role) or not SHIFTS.has(shift) or assignment.length() > 100 or model.operations.staff.size() >= 1200: return model._result(false, L.text("Diese Personalzuweisung ist nicht möglich."))
	if not free and not _expense(model, 180, "recruitment"): return model._result(false, L.text("Das Budget reicht für die Einstellung noch nicht."))
	var id: int = model.operations.next_staff
	model.operations.next_staff += 1
	var names := ["Alex", "Kim", "Robin", "Sam", "Mika", "Toni", "Sascha", "Jules", "Niki", "Charlie"]
	model.operations.staff.append({"id": id, "name": "%s %d" % [names[id % names.size()], id], "role": role, "assignment": assignment, "shift": shift, "wage": ROLES[role].wage, "qualification": 1, "motivation": 85.0, "fatigue": 0.0, "worked": 0, "absent_until": 0, "break_until": 0})
	model._duty_cache.clear()
	model._operational_change()
	return model._result(true, L.text("Mitarbeiter eingestellt. Stundenlohn und Schicht sind im Personalplan sichtbar."))

static func assign(model: RefCounted, id: int, target: String, shift: String) -> Dictionary:
	if not SHIFTS.has(shift) or target.length() > 100: return model._result(false, L.text("Diese Personalzuweisung ist nicht möglich."))
	for person in model.operations.staff:
		if int(person.id) == id:
			person.assignment = target
			person.shift = shift
			model._duty_cache.clear()
			model._operational_change()
			return model._result(true, L.text("Einsatzort und Schicht aktualisiert."))
	return model._result(false, L.text("Mitarbeiter nicht gefunden."))

static func dismiss(model: RefCounted, id: int) -> Dictionary:
	for person in model.operations.staff:
		if int(person.id) == id:
			model.operations.staff.erase(person)
			model._duty_cache.clear()
			model._operational_change()
			return model._result(true, L.text("Mitarbeiter aus dem Personalplan entfernt."))
	return model._result(false, L.text("Mitarbeiter nicht gefunden."))

static func fill_stations(model: RefCounted, id: int, free: bool = false) -> Dictionary:
	var lift: Dictionary = model.asset(id)
	if not lift.has("bottom"): return model._result(false, L.text("Einen Lift wählen."))
	var additions: Array = []
	for station in station_demands(lift):
		var assigned := 0
		for person in model.operations.staff:
			if person.role == "operator" and person.assignment == station.key and person.shift == "day" and int(person.absent_until) <= clock(model) and int(person.break_until) <= clock(model): assigned += 1
		for i in range(maxi(0, station.minimum - assigned)): additions.append(station.key)
	if not free and model.money < additions.size() * 180: return model._result(false, L.text("Das Budget reicht für die Einstellung noch nicht."))
	for target in additions: hire(model, "operator", target, "day", free)
	return model._result(true, L.text("Stationsplan besetzt. Zusätzliche Schichten und Pausenvertretung lassen sich einzeln einteilen."))

static func building_roles(kind: String) -> Array:
	match kind:
		"repair_office": return ["technician", "electrician"]
		"first_aid": return ["rescue", "rescue"]
		"maintenance": return ["driver"]
		"snowmaker": return ["snow"]
		"hotel": return ["hotel", "hotel", "security"]
		"disco": return ["catering", "security"]
		"pool", "spa": return ["hotel", "security"]
		"restaurant", "lodge", "kiosk": return ["catering"]
		"rental", "school": return ["hotel"]
	return []

static func fill_building(model: RefCounted, id: int, free: bool = false) -> Dictionary:
	var building: Dictionary = model.asset(id)
	if not building.has("point"): return model._result(false, L.text("Ein Gebäude wählen."))
	var target := "building:%d" % id
	var shift := "evening" if building.kind in ["disco", "pool", "spa", "maintenance"] else "day"
	var missing: Array = []
	var shifts: Array = ["day", "evening", "night"] if building.kind == "hotel" else (["day", "evening"] if building.kind in ["pool", "spa"] else [shift])
	for shift_value in shifts:
		var counts: Dictionary = {}
		for person in model.operations.staff:
			if person.assignment == target and person.shift == shift_value: counts[person.role] = int(counts.get(person.role, 0)) + 1
		for role in building_roles(building.kind):
			if int(counts.get(role, 0)) > 0: counts[role] -= 1
			else: missing.append([role, shift_value])
	if not free and model.money < missing.size() * 180: return model._result(false, L.text("Das Budget reicht für die Einstellung noch nicht."))
	for entry in missing: hire(model, entry[0], target, entry[1], free)
	return model._result(true, L.text("Gebäudeteam eingestellt. Im Personalplan sind weitere Schichten möglich."))

static func building_staffed(model: RefCounted, building: Dictionary) -> bool:
	if not active(model): return true
	var required: Dictionary = {}
	for role in building_roles(building.kind): required[role] = int(required.get(role, 0)) + 1
	for role in required:
		if duty(model, role, "building:%d" % int(building.id)) < required[role]: return false
	return true

static func building_open(model: RefCounted, building: Dictionary) -> bool:
	if not building.enabled or not building_staffed(model, building): return false
	if not continuous(model): return true
	if building.kind == "disco": return model.minute >= 1080 or model.minute < 120
	if building.kind in ["pool", "spa"]: return model.minute >= 600 and model.minute < 1380
	return true

static func order_parts(model: RefCounted) -> Dictionary:
	if model.operations.delivery_at >= 0: return model._result(false, L.text("Eine Ersatzteillieferung ist bereits unterwegs."))
	if not _expense(model, 1800, "spare_parts"): return model._result(false, L.text("Das Budget reicht für die Ersatzteile noch nicht."))
	model.operations.delivery_at = clock(model) + 120
	return model._result(true, L.text("Sechs Ersatzteilpakete bestellt. Lieferung in zwei Spielstunden."))

static func repair(model: RefCounted, id: int) -> Dictionary:
	var lift: Dictionary = model.asset(id)
	if not lift.has("bottom") or lift.get("fault", "") == "": return model._result(false, L.text("Diese Anlage benötigt keine Störungsreparatur."))
	for task in model.operations.repairs:
		if int(task.asset) == id: return model._result(false, L.text("Die Reparatur ist bereits eingeplant."))
	if model.operations.parts <= 0: return model._result(false, L.text("Zuerst Ersatzteile bestellen."))
	var workshop := -1
	for building in model.buildings:
		if building.kind == "repair_office" and building_open(model, building):
			var busy := false
			for task in model.operations.repairs:
				if int(task.workshop) == int(building.id): busy = true
			if not busy: workshop = int(building.id)
	if workshop < 0: return model._result(false, L.text("Eine freie Technikzentrale mit Techniker und Elektriker wird benötigt."))
	if not _expense(model, 900, "repairs"): return model._result(false, L.text("Das Budget reicht für die Reparatur noch nicht."))
	model.operations.parts -= 1
	var distance := Terrain.unpack(lift.bottom).distance_to(Terrain.unpack(model.asset(workshop).point))
	model.operations.repairs.append({"asset": id, "workshop": workshop, "remaining": 35.0 + distance / 180, "started": clock(model)})
	return model._result(true, L.text("Reparatur gestartet. Die Anlage bleibt bis zur Fertigstellung gesperrt."))

static func buy_groomer(model: RefCounted, garage: int) -> Dictionary:
	var building: Dictionary = model.asset(garage)
	if building.get("kind") != "maintenance" or not building.enabled: return model._result(false, L.text("Eine geöffnete Pistenraupengarage wählen."))
	if model.operations.vehicles.size() >= 24 or not model._spend(65000): return model._result(false, L.text("Für eine Pistenraupe werden 65.000 € benötigt. Maximal 24 Fahrzeuge."))
	model.operations.vehicles.append({"id": model.operations.next_vehicle, "garage": garage, "piste": -1, "remaining": 0.0, "total": 0.0, "hours": 0.0, "fuel": 100.0, "wear": 0.0, "point": building.point.duplicate()})
	model.operations.next_vehicle += 1
	return model._result(true, L.text("Pistenraupe gekauft. Fahrer einstellen und eine Piste zuweisen oder Nachtpräparierung aktivieren."))

static func groom(model: RefCounted, id: int) -> Dictionary:
	var piste: Dictionary = model.asset(id)
	if not piste.has("difficulty"): return model._result(false, L.text("Eine Piste wählen."))
	for vehicle in model.operations.vehicles:
		var garage: Dictionary = model.asset(int(vehicle.garage))
		if vehicle.piste >= 0 or garage.is_empty() or not building_open(model, garage): continue
		var busy_count := 0
		for other in model.operations.vehicles:
			if int(other.garage) == int(vehicle.garage) and int(other.piste) >= 0: busy_count += 1
		if duty(model, "driver", "building:%d" % int(vehicle.garage)) <= busy_count: continue
		var occupied: bool = model.guests.any(func(g): return g.phase != "leaving" and g.leg < g.route.legs.size() and g.route.legs[g.leg].kind == "ski" and int(g.route.legs[g.leg].id) == id)
		if occupied: return model._result(false, L.text("Die Piste zuerst schließen und die letzten Gäste ausfahren lassen."))
		if not _expense(model, 220, "grooming"): return model._result(false, L.text("Das Budget reicht für Energie und Präparierung noch nicht."))
		vehicle.piste = id
		vehicle.total = maxf(15.0, piste.length / 60.0)
		vehicle.remaining = vehicle.total
		piste.grooming_until = model.minute + ceili(vehicle.total)
		model._operational_change()
		return model._result(true, L.text("Präparierung läuft. Verbrauch, Verschleiß und Fahrfortschritt werden berechnet."))
	return model._result(false, L.text("Eine freie Pistenraupe und ein Fahrer im Dienst werden benötigt."))

static func service_vehicle(model: RefCounted, id: int) -> Dictionary:
	for vehicle in model.operations.vehicles:
		if int(vehicle.id) == id and (vehicle.piste < 0 or vehicle.fuel <= 0 or vehicle.wear >= 100):
			if not _expense(model, 800, "vehicle_service"): break
			vehicle.fuel = 100.0
			vehicle.wear = 0.0
			return model._result(true, L.text("Pistenraupe gewartet und aufgetankt."))
	return model._result(false, L.text("Fahrzeug ist beschäftigt oder das Budget reicht noch nicht."))

static func incident(model: RefCounted, guest: Dictionary, reason: String = "fatigue") -> void:
	if guest.get("incident", -1) >= 0 or model.operations.incidents.size() >= 100: return
	var point3: Vector3 = model.guest_position(guest)
	var id: int = model.operations.next_incident
	model.operations.next_incident += 1
	guest.incident = id
	model.operations.incidents.append({"id": id, "guest": int(guest.id), "reason": reason, "point": [point3.x, point3.z], "created": clock(model), "station": -1, "remaining": -1.0, "status": "waiting"})

static func evacuate(model: RefCounted, id: int) -> Dictionary:
	var count := 0
	for guest in model.guests:
		if guest.phase == "leaving" or guest.leg >= guest.route.legs.size(): continue
		var leg: Dictionary = guest.route.legs[guest.leg]
		if leg.kind == "lift" and int(leg.id) == id and guest.phase != "queue":
			incident(model, guest, "evacuation")
			count += 1
	return model._result(count > 0, L.text("Hilferufe für %d Passagiere angelegt. Rettungsteams werden nach Erreichbarkeit entsandt.") % count)

static func dispatch(model: RefCounted, id: int) -> Dictionary:
	for event in model.operations.incidents:
		if int(event.id) != id or event.status != "waiting": continue
		var best := INF
		var station := -1
		for building in model.buildings:
			if building.kind != "first_aid" or not building_open(model, building): continue
			var busy: bool = model.operations.incidents.any(func(e): return e.status == "responding" and int(e.station) == int(building.id))
			if busy: continue
			var position := Terrain.unpack(event.point)
			var distance := Terrain.unpack(building.point).distance_to(position)
			if distance > 1800 * int(building.get("level", 1)): continue
			# Dispatch needs a route in the actual lift / piste / foot graph.
			var graph: Dictionary = model._routing_graph(2)
			var nearest := ""
			var delta := INF
			for key in graph.nodes:
				var value := Terrain.unpack(graph.nodes[key]).distance_to(position)
				if value < delta:
					delta = value
					nearest = key
			if delta > 180 or nearest == "": continue
			var route: Dictionary = model._shortest(graph, "d%d" % int(building.id), nearest)
			if not route.ok: continue
			var time := 4.0 + delta / 60 + absf(model.terrain.height(Terrain.unpack(building.point)) - model.terrain.height(position)) / 100
			for leg in route.legs: time += float(leg.minutes)
			time *= 1.5 if model.weather_index in [2, 3] else 1.0
			if time < best:
				best = time
				station = int(building.id)
		if station < 0: return model._result(false, L.text("Kein freies, besetztes Rettungsteam erreicht diesen Ort innerhalb seines Einsatzradius."))
		event.station = station
		event.remaining = best
		event.status = "responding"
		return model._result(true, L.text("Rettung unterwegs. Wege, Höhenunterschied und Wetter bestimmen die Reaktionszeit."))
	return model._result(false, L.text("Kein offener Hilferuf gefunden."))

static func _expense(model: RefCounted, amount: float, centre: String) -> bool:
	if model.money < amount: return false
	_charge(model, amount, centre)
	return true

static func _charge(model: RefCounted, amount: float, centre: String) -> void:
	model.money -= amount
	model.report.costs += amount
	model.operations.cost_centres[centre] = float(model.operations.cost_centres.get(centre, 0.0)) + amount

static func tick(model: RefCounted) -> void:
	if not active(model): return
	refresh_duty(model)
	var now := clock(model)
	if model.operations.scenario != "" and model.minute == 510 and int(model.operations.event_day) != model.day:
		model.operations.event_day = model.day
		model.operations.event = ["Personalengpass", "Ferienansturm", "Schneemangel", "Abendveranstaltung"][(model.day - 1) % 4]
		if model.operations.event == "Personalengpass" and model.operations.scenario != "braunlage":
			for person in model.operations.staff:
				if person.role == "operator":
					person.absent_until = now + 180
					break
		if model.operations.event == "Schneemangel":
			for piste in model.pistes: piste.snow = maxf(12, piste.snow - 18)
		refresh_duty(model)
	var previous_signature: String = model._operating_signature
	var current_signature := signature(model)
	for person in model.operations.staff:
		if on_duty(model, person):
			var pay: float = person.wage / 60.0
			_charge(model, pay, person.assignment)
			model.operations.payroll += pay
			person.worked += 1
			person.fatigue = minf(100, person.fatigue + 0.05)
			person.motivation = maxf(15, person.motivation - (0.008 if person.fatigue > 60 else 0.001))
		else:
			person.fatigue = maxf(0, person.fatigue - 0.12)
			person.motivation = minf(100, person.motivation + 0.002)
	for lift in model.lifts:
		if model.minute % 30 == 0 and lift.get("fault", "") == "" and lift.enabled and lift_available(model, lift):
			lift.wear = float(lift.get("wear", 0.0)) + 0.10
			if float(lift.wear) > 60 and model.rng.randf() < 0.008: lift.fault = "electrical" if model.rng.randf() < 0.4 else "mechanical"
	if previous_signature != current_signature:
		model._operating_signature = current_signature
		model._operational_change()
		model._reroute_guests(true)
	if model.operations.delivery_at >= 0 and now >= int(model.operations.delivery_at):
		model.operations.parts += 6
		model.operations.delivery_at = -1
	var finished: Array = []
	for task in model.operations.repairs:
		var workshop: Dictionary = model.asset(int(task.workshop))
		if workshop.is_empty():
			for replacement in model.buildings:
				if replacement.kind == "repair_office" and building_open(model, replacement):
					task.workshop = int(replacement.id)
					workshop = replacement
					break
		if workshop.is_empty() or not building_open(model, workshop): continue
		task.remaining -= 1
		if task.remaining <= 0:
			var lift: Dictionary = model.asset(int(task.asset))
			if not lift.is_empty():
				lift.fault = ""
				lift.wear = 0.0
				model.operations.repairs_done += 1
			finished.append(task)
			model._operational_change()
	for task in finished: model.operations.repairs.erase(task)
	for vehicle in model.operations.vehicles:
		var garage: Dictionary = model.asset(int(vehicle.garage))
		if garage.is_empty():
			if vehicle.piste >= 0:
				var unfinished: Dictionary = model.asset(int(vehicle.piste))
				if not unfinished.is_empty(): unfinished.grooming_until = 0
				vehicle.piste = -1
				model._operational_change()
			for replacement in model.buildings:
				if replacement.kind == "maintenance" and replacement.enabled:
					vehicle.garage = int(replacement.id)
					vehicle.point = replacement.point.duplicate()
					garage = replacement
					break
		if garage.is_empty() or not building_open(model, garage): continue
		if vehicle.piste < 0:
			if model.operations.auto_groom and (model.minute >= 1080 or model.minute < 420) and model.minute % 15 == 0:
				for piste in model.pistes:
					if piste.condition < 85 and groom(model, int(piste.id)).ok: break
			continue
		var piste: Dictionary = model.asset(int(vehicle.piste))
		if piste.is_empty():
			vehicle.piste = -1
			continue
		if vehicle.fuel <= 0 or vehicle.wear >= 100: continue
		vehicle.remaining -= 1
		vehicle.hours += 1.0 / 60
		vehicle.fuel = maxf(0, vehicle.fuel - 0.15)
		vehicle.wear += 0.025
		vehicle.point = Terrain.pack(model.terrain.point_on_path(piste.points, clampf(1 - vehicle.remaining / vehicle.total, 0, 1)))
		# The deadline follows actual work; a shift interruption cannot silently
		# reopen a half-finished piste.
		piste.grooming_until = model.minute + ceili(vehicle.remaining) + 1
		if vehicle.remaining <= 0:
			Snow.groom(piste, 1.0)
			piste.condition = 100.0
			piste.grooming_until = 0
			vehicle.piste = -1
			model.operations.groomed += 1
			model.snow_revision += 1
			model._operational_change()
	for event in model.operations.incidents:
		if event.status == "waiting" and model.minute % 5 == 0: dispatch(model, int(event.id))
		elif event.status == "responding":
			var station: Dictionary = model.asset(int(event.station))
			if station.is_empty() or not building_open(model, station): continue
			event.remaining -= 1
			if event.remaining <= 0:
				event.status = "resolved"
				model.operations.rescued += 1
				for guest in model.guests:
					if int(guest.id) == int(event.guest):
						guest.incident = -1
						guest.assisted = true
						guest.needs.energy = maxf(60, guest.needs.energy)
						if event.reason == "evacuation":
							# Recovery uses the real graph after lowering the passenger to the ground.
							var graph: Dictionary = model._routing_graph(int(guest.ability))
							var home_paths: Dictionary = model._distances(graph, "base", true)
							var nearest := "base"
							var distance := INF
							for key in graph.nodes:
								var delta := Terrain.unpack(graph.nodes[key]).distance_to(Terrain.unpack(event.point))
								if home_paths.distance.has(key) and delta < distance:
									distance = delta
									nearest = key
							var home: Dictionary = model._shortest(graph, nearest, "base")
							var walk: Dictionary = model._edge("rescue", nearest, "walk", 0, [event.point, graph.nodes[nearest]], maxf(0.15, distance / 45))
							walk.rescue = true
							guest.route = {"target": 0, "origin": event.point, "legs": [walk] + home.legs}
							guest.heading_home = true
							guest.leg = 0
							model._start_leg(guest)
				model.reputation = minf(95, model.reputation + 0.3)
	if model.minute % 10 == 0:
		for guest in model.guests:
			if guest.phase == "leaving" or guest.get("incident", -1) >= 0 or guest.get("assisted", false) or guest.leg >= guest.route.legs.size(): continue
			var leg: Dictionary = guest.route.legs[guest.leg]
			if leg.kind == "ski" and guest.get("navigation_error", false) and model.asset(int(leg.id)).difficulty > guest.ability and guest.elapsed > guest.duration * 0.35:
				incident(model, guest, "navigation")
			elif leg.kind == "ski" and guest.needs.energy < 24 and model.rng.randf() < 0.015: incident(model, guest)
	if model.minute % 5 == 0:
		var nearby: Dictionary = {}
		for guest in model.guests:
			if guest.phase != "moving" or guest.get("incident", -1) >= 0 or guest.leg >= guest.route.legs.size() or guest.route.legs[guest.leg].kind != "ski": continue
			var point3: Vector3 = model.guest_position(guest)
			var cell := Vector2i(floori(point3.x / 8), floori(point3.z / 8))
			if nearby.has(cell):
				var other: Dictionary = nearby[cell]
				if point3.distance_to(model.guest_position(other)) < 2.5 and model.rng.randf() < 0.01:
					incident(model, guest, "collision")
					incident(model, other, "collision")
			nearby[cell] = guest
	if continuous(model): _charge(model, model.operating_costs(false) / 1440.0, "infrastructure")
	if model.minute % 30 == 0: evaluate(model)
	if continuous(model) and model.minute >= 1440: midnight(model)

static func midnight(model: RefCounted) -> void:
	Progression.finish_day(model)
	model.report.closed_at = 1440
	model.last_report = model.report.duplicate(true)
	model.operations.history.append(model.last_report.duplicate(true))
	if model.operations.history.size() > 28: model.operations.history.pop_front()
	model.day += 1
	model.minute = 0
	model.weather_index = Progression.weather_for_day(model.rng.seed, model.day)
	for piste in model.pistes:
		piste.snow = minf(110, piste.snow + model.weather().snowfall)
		if piste.get("grooming_until", 0) >= 1440: piste.grooming_until -= 1440
	model._reset_report()
	model.operations.payroll = 0.0
	model.operations.cost_centres = {}
	Progression.begin_day(model)
	model._duty_cache.clear()
	model._operational_change()
	evaluate(model)

static func max_wait(model: RefCounted) -> float:
	var result := 0.0
	for lift in model.lifts:
		if model.lift_open(lift): result = maxf(result, model.queue_size(lift.id) * model.fleet_layout(lift).interval / model.Fleet.seats(lift))
	return result

static func evaluate(model: RefCounted) -> Array:
	var scenario: String = model.operations.scenario
	if scenario == "": return []
	var staffed := true
	for lift in model.lifts:
		if lift.enabled:
			for station in station_demands(lift):
				var assigned := 0
				for person in model.operations.staff:
					if person.role == "operator" and person.assignment == station.key and person.shift == "day" and int(person.absent_until) <= clock(model): assigned += 1
				staffed = staffed and assigned >= station.minimum
	var rescue_ready := false
	var workshop_ready := false
	var evening_ready := false
	for building in model.buildings:
		var assignments: Array = []
		for person in model.operations.staff:
			if person.assignment == "building:%d" % int(building.id): assignments.append(person.role)
		if building.enabled and building.kind == "first_aid" and assignments.count("rescue") >= 2: rescue_ready = true
		if building.enabled and building.kind == "repair_office" and "technician" in assignments and "electrician" in assignments: workshop_ready = true
		if building.enabled and building.kind in ["pool", "spa", "disco"] and not assignments.is_empty() and model.building_count("hotel") > 0: evening_ready = true
	var profitable := 0
	for day_report in model.operations.history:
		if day_report.tickets + day_report.services > day_report.costs: profitable += 1
	var values: Array
	match scenario:
		"braunlage": values = [staffed, workshop_ready, model.operations.repairs_done > 0, model.operations.groomed > 0, model.total_guests >= 100 and model.reputation >= 50]
		"filzmoos": values = [staffed, rescue_ready, model.operations.groomed >= 3, model.total_guests >= 100 and max_wait(model) < 12, profitable >= 2]
		"kitzbuehel": values = [model.operations.repairs_done > 0, staffed, model.operations.parts >= 2, model.total_guests >= 200 and max_wait(model) < 15, model.total_guests >= 300 and profitable >= 1]
		_: values = [rescue_ready and workshop_ready, model.operations.vehicles.size() >= 3 and model.operations.groomed >= 3, evening_ready, staffed, profitable >= 3]
	model.operations.goals = values
	if not model.operations.completed and values.all(func(v): return v):
		model.operations.completed = true
		model.money += 75000
		model.report.rewards += 75000
		model.campaign.points += 30
	return values

static func valid(state: Variant, model: RefCounted) -> bool:
	if not state is Dictionary: return false
	var defaults := initial()
	for key in defaults:
		if not state.has(key) or typeof(state[key]) != typeof(defaults[key]) and not (defaults[key] is float and Terrain.number(state[key])) and not (defaults[key] is int and Terrain.number(state[key])): return false
		if defaults[key] is int or defaults[key] is float:
			if not Terrain.number(state[key]) or absf(state[key]) > 1000000000 or state[key] < (-1 if key == "delivery_at" else 0): return false
			if defaults[key] is int and state[key] != floorf(state[key]): return false
	if state.parts > 10000 or state.room_price < 40 or state.room_price > 250: return false
	if state.scenario != "" and state.scenario not in Geo.IDS: return false
	if state.staff.size() > 1200 or state.vehicles.size() > 24 or state.repairs.size() > 160 or state.incidents.size() > 100 or state.history.size() > 28: return false
	var ids: Dictionary = {}
	for person in state.staff:
		if not person is Dictionary: return false
		for key in ["id", "wage", "qualification", "motivation", "fatigue", "worked", "absent_until", "break_until"]:
			if not Terrain.number(person.get(key)) or person[key] < 0 or person[key] > 1000000000: return false
		if not person.get("name") is String or not ROLES.has(person.get("role")) or not SHIFTS.has(person.get("shift")) or not person.get("assignment") is String or ids.has(int(person.id)): return false
		ids[int(person.id)] = true
		if person.wage != ROLES[person.role].wage or person.motivation > 100 or person.fatigue > 100 or person.id >= state.next_staff: return false
	for vehicle in state.vehicles:
		if not vehicle is Dictionary: return false
		for key in ["id", "garage", "piste", "remaining", "total", "hours", "fuel", "wear"]:
			if not Terrain.number(vehicle.get(key)) or vehicle[key] < (-1 if key == "piste" else 0) or vehicle[key] > 1000000000: return false
		if not model.terrain.contains(Terrain.unpack(vehicle.get("point"))): return false
	for task in state.repairs:
		if not task is Dictionary or not Terrain.number(task.get("asset")) or not Terrain.number(task.get("workshop")) or not Terrain.number(task.get("remaining")) or task.remaining < 0 or task.remaining > 100000: return false
	for event in state.incidents:
		if not event is Dictionary or event.get("status") not in ["waiting", "responding", "resolved"]: return false
		for key in ["id", "guest", "created", "station", "remaining"]:
			if not Terrain.number(event.get(key)) or event[key] < -1 or event[key] > 1000000000: return false
		if not model.terrain.contains(Terrain.unpack(event.get("point"))): return false
		if event.get("reason") not in ["fatigue", "collision", "evacuation", "navigation"]: return false
	for centre in state.cost_centres:
		if not centre is String or centre.length() > 100 or not Terrain.number(state.cost_centres[centre]) or state.cost_centres[centre] < 0: return false
	for row in state.history:
		if not row is Dictionary: return false
		for key in ["day", "tickets", "services", "costs", "guests", "rides", "investments", "departures", "satisfaction", "rewards"]:
			if not Terrain.number(row.get(key)) or row[key] < 0: return false
	if state.goals.size() > 5 or not state.goals.all(func(v): return v is bool): return false
	# JSON numbers are floats in Godot. Canonical integers keep a migrated
	# populated save bit-for-bit deterministic after the next snapshot.
	for key in defaults:
		if defaults[key] is int: state[key] = int(state[key])
	for person in state.staff:
		for key in ["id", "qualification", "worked", "absent_until", "break_until"]: person[key] = int(person[key])
	return true
