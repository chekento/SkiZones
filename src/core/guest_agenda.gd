extends RefCounted
## Personal intentions and actual experiences, independent of drawing and RNG.
const Terrain = preload("res://src/core/terrain.gd")
const Needs = preload("res://src/core/guest_needs.gd")
const Motion = preload("res://src/core/ski_motion.gd")
const L = preload("res://src/core/i18n.gd")
const TYPES := {
	"blue": {"name": "Genuss auf Blau", "comfort": 0, "share": 0.24, "wish": "Nur blaue Pisten, sichere Wege und entspannte Pausen."},
	"mixed": {"name": "Blau & Rot", "comfort": 1, "share": 0.24, "wish": "Abwechslung auf blauen und roten Abfahrten."},
	"alpine": {"name": "Alle Schwierigkeitsgrade", "comfort": 2, "share": 0.16, "wish": "Blaue, rote und schwarze Abfahrten entdecken."},
	"collector": {"name": "Pisten- und Liftsammler", "comfort": 2, "share": 0.10, "wish": "Im Urlaub jede Piste fahren und jeden Lift benutzen."},
	"expert": {"name": "Schwarz & Snowpark", "comfort": 2, "share": 0.10, "wish": "Sportliche schwarze Pisten und regelmäßige Snowpark-Besuche."},
	"family": {"name": "Familien gemeinsam", "comfort": 0, "share": 0.16, "wish": "Zusammenbleiben, kindgerechte Pisten, Essen und Wärme."}
}

static func initial() -> Dictionary:
	var state := {"version": 1, "target": "balanced", "segments": {}}
	for kind in TYPES: state.segments[kind] = {"rating": 48.0, "visitors": 0, "departures": 0, "satisfaction": 0.0, "tickets": 0.0, "services": 0.0}
	return state

static func ensure(model: RefCounted, guest: Dictionary, requested: String = "") -> void:
	Needs.ensure(guest, model.weather().temperature)
	if guest.has("agenda"): return
	var kind := requested
	if not TYPES.has(kind): kind = "blue" if guest.ability == 0 else "mixed" if guest.ability == 1 else ["alpine", "collector", "expert"][posmod(int(guest.id), 3)]
	guest.agenda = {"version": 1, "kind": kind, "comfort": mini(int(guest.ability), int(TYPES[kind].comfort)), "piste_goal": [], "lift_goal": [], "pistes": [], "lifts": [], "coverage": {}, "black_runs": 0, "park_visits": 0, "hungry_minutes": 0, "cold_minutes": 0, "tired_minutes": 0}
	if kind == "family": guest.agenda.comfort = int(guest.ability)
	if kind == "collector":
		for piste in model.pistes:
			if piste.enabled: guest.agenda.piste_goal.append(int(piste.id))
		for lift in model.lifts:
			if lift.enabled: guest.agenda.lift_goal.append(int(lift.id))

static func make_family(model: RefCounted, guest: Dictionary, count: int) -> void:
	guest.group_size = clampi(count, 2, 5)
	guest.family = []
	for index in range(guest.group_size):
		var child: bool = index < maxi(1, guest.group_size - 2)
		var age := 6 + posmod(int(guest.id) * 7 + index * 3, 10) if child else 28 + posmod(int(guest.id) * 11 + index * 7, 27)
		var proxy: Dictionary = guest.duplicate()
		proxy.erase("needs")
		var state := Needs.legacy(proxy, model.weather().temperature)
		state.rental = guest.needs.rental
		state.lesson = guest.needs.lesson
		guest.family.append({"years": age, "ability": int(guest.ability) if child else 2, "name": Motion.name_for(int(guest.id) * 5 + index), "needs": state})
	Needs.aggregate_family(guest)

static func comfort(guest: Dictionary) -> int:
	var limit := mini(int(guest.ability), int(guest.get("agenda", {}).get("comfort", guest.ability)))
	for member in guest.get("family", []): limit = mini(limit, int(member.ability))
	return limit

static func record_piste(guest: Dictionary, piste: Dictionary, leg: Dictionary) -> void:
	if not guest.has("agenda") or piste.is_empty(): return
	var agenda: Dictionary = guest.agenda
	var key := str(int(piste.id))
	var ranges: Array = agenda.coverage.get(key, []).duplicate(true)
	ranges.append([float(leg.get("start_fraction", 0)), float(leg.get("end_fraction", 1))])
	ranges.sort_custom(func(a, b): return a[0] < b[0])
	var merged: Array = []
	for interval in ranges:
		if merged.is_empty() or float(merged[-1][1]) < float(interval[0]) - 0.00001: merged.append(interval.duplicate())
		else: merged[-1][1] = maxf(merged[-1][1], interval[1])
	agenda.coverage[key] = merged
	if merged.size() == 1 and merged[0][0] <= 0.00001 and merged[0][1] >= 0.99999 and not agenda.pistes.has(int(piste.id)):
		agenda.pistes.append(int(piste.id))
	if piste.difficulty == 2 and float(leg.get("end_fraction", 1)) - float(leg.get("start_fraction", 0)) > 0.1: agenda.black_runs += 1

static func record_lift(guest: Dictionary, id: int) -> void:
	if guest.has("agenda") and not guest.agenda.lifts.has(id): guest.agenda.lifts.append(id)

static func record_service(model: RefCounted, guest: Dictionary, kind: String, revenue: float) -> void:
	if not guest.has("agenda"): return
	if kind == "snowpark": guest.agenda.park_visits += 1
	model.audience.segments[guest.agenda.kind].services += revenue

static func advance(guest: Dictionary) -> void:
	if not guest.has("agenda") or guest.phase == "leaving": return
	var state: Dictionary = guest.needs
	if state.hunger > 70: guest.agenda.hungry_minutes += 1
	if state.warmth < 35: guest.agenda.cold_minutes += 1
	if state.energy < 25: guest.agenda.tired_minutes += 1

static func route_weight(model: RefCounted, guest: Dictionary, route: Dictionary) -> float:
	var agenda: Dictionary = guest.agenda
	var weight := 1.0
	var fresh_pistes: Dictionary = {}
	var fresh_lifts: Dictionary = {}
	var black := false
	for leg in route.legs:
		if leg.kind == "ski":
			var piste: Dictionary = model.asset(int(leg.id))
			if not piste.is_empty():
				if piste.difficulty > comfort(guest): return 0
				black = black or piste.difficulty == 2
			if not agenda.pistes.has(int(leg.id)): fresh_pistes[int(leg.id)] = true
		elif leg.kind == "lift" and not agenda.lifts.has(int(leg.id)): fresh_lifts[int(leg.id)] = true
	if agenda.kind == "collector": weight = 1 + fresh_pistes.size() * 12 + fresh_lifts.size() * 16
	elif agenda.kind == "expert": weight = 7.0 if black else 0.12
	elif agenda.kind in ["mixed", "alpine"]: weight += minf(2, fresh_pistes.size()) * 0.7
	elif agenda.kind == "family": weight = 1.5 if model.asset(int(route.get("target", 0))).get("difficulty", 0) == 0 else 0.8
	return weight

static func park_utility(guest: Dictionary) -> float:
	if not guest.has("agenda") or guest.get("evening", false): return 0
	if guest.agenda.kind != "expert" or guest.needs.energy < 35 or guest.needs.warmth < 35 or guest.needs.hunger > 70: return 0
	return 115.0 if guest.agenda.park_visits == 0 else 65.0

static func achievement(model: RefCounted, guest: Dictionary) -> float:
	if not guest.has("agenda"): return 0.5
	var agenda: Dictionary = guest.agenda
	if guest.get("evening", false): return clampf(guest.needs.joy / 100.0, 0, 1)
	if agenda.kind == "collector":
		var wanted := 0
		var done := 0
		for pair in [[agenda.piste_goal, agenda.pistes], [agenda.lift_goal, agenda.lifts]]:
			for id in pair[0]:
				if model.asset(int(id)).is_empty(): continue
				wanted += 1
				if pair[1].has(int(id)): done += 1
		return float(done) / maxi(1, wanted)
	if agenda.kind == "expert": return minf(1, agenda.black_runs / 3.0) * 0.65 + minf(1, agenda.park_visits / 2.0) * 0.35
	if guest.get("runs", 0) == 0: return 0.55 if guest.age < 45 else 0.1
	if agenda.kind == "family": return clampf((guest.needs.energy + guest.needs.warmth + 100 - guest.needs.hunger) / 300, 0, 1)
	var colors: Dictionary = {}
	for id in agenda.pistes:
		var piste: Dictionary = model.asset(int(id))
		if not piste.is_empty(): colors[int(piste.difficulty)] = true
	var desired := 1 if agenda.kind == "blue" else 2 if agenda.kind == "mixed" else 3
	return 0.65 + 0.35 * minf(1, float(colors.size()) / desired)

static func satisfaction(model: RefCounted, guest: Dictionary) -> float:
	var appeal := 0.0
	for kind in guest.get("service_history", {}): appeal += model.Catalog.BUILDINGS[kind].appeal
	if model.Progression.has(model, "service"): appeal += 6
	var needs := Needs.values(guest, model.weather().temperature)
	var runs: int = guest.get("runs", guest.get("loops", 0))
	var discomfort := maxf(0, needs.hunger - 70) * 0.16 + maxf(0, 35 - needs.warmth) * 0.25 + maxf(0, 25 - needs.energy) * 0.15
	var base: float = 62 + minf(appeal, 40) * 0.5 + mini(runs, 4) * 4 - (12 if runs == 0 else 0) - guest.total_wait * 0.085 - maxf(model.ticket_price - 48, 0) * 0.6 - discomfort
	var history := 0.0
	if guest.has("agenda"): history = minf(22, guest.agenda.hungry_minutes * 0.035 + guest.agenda.cold_minutes * 0.07 + guest.agenda.tired_minutes * 0.04)
	return clampf(base * 0.72 + achievement(model, guest) * 28 - history, 5, 100)

static func feedback(model: RefCounted, guest: Dictionary, score: float) -> void:
	if not guest.has("agenda"): return
	var row: Dictionary = model.audience.segments[guest.agenda.kind]
	var count: int = guest.get("group_size", 1)
	row.departures += count
	row.satisfaction += score * count
	row.rating = clampf(lerpf(row.rating, score, 0.08), 5, 100)

static func offer(model: RefCounted) -> Dictionary:
	var key := "%d/%d/%d" % [model.revision, model.day, model.minute / 15]
	if model._audience_offer.get("key", "") == key: return model._audience_offer
	var counts := [0, 0, 0]
	var used: Dictionary = {}
	for route in model.routes_for(2):
		counts[int(model.asset(int(route.target)).difficulty)] += 1
		for leg in route.legs:
			if leg.kind == "lift": used[int(leg.id)] = true
	var park := false
	var food := false
	var warm := false
	for building in model.buildings:
		if not model.Ops.building_open(model, building) or not Needs.SERVICES.has(building.kind): continue
		var graph: Dictionary = model._routing_graph(2)
		var door := "d%d" % int(building.id)
		if not model._shortest(graph, "base", door).ok or not model._shortest(graph, door, "base").ok: continue
		park = park or building.kind == "snowpark"
		food = food or Needs.SERVICES[building.kind].hunger >= 35
		warm = warm or Needs.SERVICES[building.kind].warmth >= 35
	model._audience_offer = {"key": key, "colors": counts, "lifts": used.size(), "park": park, "food": food, "warm": warm}
	return model._audience_offer

static func fit(kind: String, supply: Dictionary) -> float:
	var colors: Array = supply.colors
	match kind:
		"blue": return 0.25 + minf(1, colors[0] / 3.0) * 0.75
		"mixed": return 0.2 + minf(1, colors[0] / 2.0) * 0.25 + minf(1, colors[1] / 2.0) * 0.55
		"alpine": return 0.2 + colors.filter(func(n): return n > 0).size() / 3.0 * 0.8
		"collector": return 0.2 + minf(1, (colors[0] + colors[1] + colors[2] + supply.lifts) / 12.0) * 0.8
		"expert": return 0.1 + minf(1, colors[2] / 2.0) * 0.6 + (0.3 if supply.park else 0)
		_: return 0.2 + minf(1, colors[0] / 2.0) * 0.5 + (0.15 if supply.food else 0) + (0.15 if supply.warm else 0)

static func market_factor(model: RefCounted) -> float:
	var total := 0.0
	var supply := offer(model)
	for kind in TYPES: total += TYPES[kind].share * fit(kind, supply) * (0.75 + model.audience.segments[kind].rating / 100.0)
	return clampf(0.75 + total * 0.3, 0.75, 1.15)

static func sample(model: RefCounted) -> String:
	var supply := offer(model)
	var beginner_share: float = model.Progression.event(model).beginner_share
	var weights: Dictionary = {}
	var total := 0.0
	for kind in TYPES:
		if model.routes_for(int(TYPES[kind].comfort)).is_empty(): continue
		var weight: float = TYPES[kind].share * fit(kind, supply) * (0.5 + model.audience.segments[kind].rating / 100.0)
		weight *= beginner_share / 0.53 if int(TYPES[kind].comfort) == 0 else (1.0 - beginner_share) / 0.47
		if model.audience.target == kind: weight *= 1.8
		weights[kind] = weight
		total += weight
	if total <= 0: return ""
	var draw: float = model.rng.randf() * total
	for kind in weights:
		draw -= weights[kind]
		if draw <= 0: return kind
	return weights.keys()[-1]

static func valid_state(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1 or value.get("target") not in ["balanced"] + TYPES.keys() or not value.get("segments") is Dictionary: return false
	for kind in TYPES:
		if not value.segments.get(kind) is Dictionary: return false
		for field in ["rating", "visitors", "departures", "satisfaction", "tickets", "services"]:
			var number: Variant = value.segments[kind].get(field)
			if not Terrain.number(number) or number < 0 or number > 1000000000000: return false
		if value.segments[kind].rating > 100: return false
	return true

static func valid_guest(guest: Dictionary, next_id: int) -> bool:
	if not guest.has("agenda"): return not guest.has("family")
	var a: Variant = guest.agenda
	if not a is Dictionary or a.get("version") != 1 or not TYPES.has(a.get("kind")): return false
	if not Terrain.number(a.get("comfort")) or a.comfort != floorf(a.comfort) or a.comfort < 0 or a.comfort > guest.ability: return false
	for field in ["black_runs", "park_visits", "hungry_minutes", "cold_minutes", "tired_minutes"]:
		if not Terrain.number(a.get(field)) or a[field] < 0 or a[field] != floorf(a[field]) or a[field] > 1000000000: return false
	for field in ["piste_goal", "lift_goal", "pistes", "lifts"]:
		if not a.get(field) is Array or a[field].size() > 8192: return false
		var seen: Dictionary = {}
		for id in a[field]:
			if not Terrain.number(id) or id <= 0 or id >= next_id or id != floorf(id) or seen.has(int(id)): return false
			seen[int(id)] = true
	if not a.get("coverage") is Dictionary or a.coverage.size() > 8192: return false
	for id in a.coverage:
		if not id is String or not id.is_valid_int() or int(id) <= 0 or int(id) >= next_id or not a.coverage[id] is Array or a.coverage[id].size() > 64: return false
		var end := -1.0
		for interval in a.coverage[id]:
			if not interval is Array or interval.size() != 2 or not Terrain.number(interval[0]) or not Terrain.number(interval[1]) or interval[0] < 0 or interval[1] > 1 or interval[0] < end or interval[0] >= interval[1]: return false
			end = interval[1]
	if guest.has("family"):
		if a.kind != "family" or not guest.family is Array or guest.family.size() != guest.get("group_size") or guest.family.size() < 2 or guest.family.size() > 5: return false
		for member in guest.family:
			if not member is Dictionary or not member.get("name") is String or member.name.length() > 80: return false
			if not Terrain.number(member.get("years")) or member.years < 6 or member.years > 90 or not Terrain.number(member.get("ability")) or member.ability < a.comfort or member.ability > 2: return false
			var proxy := {"age": guest.age, "needs": member.get("needs"), "service_history": {}}
			if not Needs.valid(proxy): return false
	return true
