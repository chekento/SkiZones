extends RefCounted
## Persistent career: research choices, contracts, upgrades and winter ratings.

const Catalog = preload("res://src/core/catalog.gd")
const Terrain = preload("res://src/core/terrain.gd")
const XP_STEPS := [0, 800, 2400, 6000, 12000]
const RANK_NAMES := ["Berghütte", "Lokales Skigebiet", "Alpenresort", "Wintersportzentrum", "Alpine Destination"]
const RESEARCH := {
	"snowcraft": {"name": "Schneemanagement", "cost": 18000, "points": 3, "days": 1, "requires": [], "effect": "Beschneiung, Pistenraupengarage, Snowpark und Pistenstufe 2 werden verfügbar."},
	"service": {"name": "Gästekomfort", "cost": 24000, "points": 4, "days": 1, "requires": [], "effect": "15 % mehr Serviceerlöse, mehr Komfort und Gebäude-Upgrades auf Stufe 2."},
	"meteo": {"name": "Bergwetterstation", "cost": 12000, "points": 2, "days": 1, "requires": [], "effect": "Eine verlässliche Wettervorschau für die nächsten sechs Betriebstage."},
	"lifttech": {"name": "Fördertechnik", "cost": 36000, "points": 5, "days": 2, "requires": [], "effect": "Lifte auf Stufe 2 ausbauen: mehr Kapazität und kürzere Fahrzeiten."},
	"hospitality": {"name": "Alpine Hotellerie", "cost": 48000, "points": 6, "days": 2, "requires": ["service"], "effect": "Berghotels werden verfügbar. Sie steigern Nachfrage, Komfort und Erlöse."},
	"efficient_snow": {"name": "Effiziente Präparierung", "cost": 32000, "points": 4, "days": 2, "requires": ["snowcraft"], "effect": "15 % weniger Betriebskosten und 12 zusätzliche Zustandspunkte bei der Nachtpräparierung."},
	"gondola": {"name": "Gondeltechnik", "cost": 68000, "points": 8, "days": 3, "requires": ["lifttech"], "effect": "Windstabile Gondelbahnen mit hoher Förderleistung erschließen neue Hänge."},
	"marketing": {"name": "Destinationsmarketing", "cost": 35000, "points": 5, "days": 2, "requires": ["service"], "effect": "15 % mehr Nachfrage. Gute Pisten und kurze Wartezeiten bleiben entscheidend."},
	"mastercraft": {"name": "Alpine Meisterklasse", "cost": 90000, "points": 10, "days": 3, "requires": ["lifttech", "hospitality"], "effect": "8er-Sessel werden verfügbar; Pisten, Gebäude und Lifte können bis Stufe 3 ausgebaut werden."}
}
const CONTRACTS := {
	"visitors": {"name": "Der Berg ruft", "text": "Begrüße neue Tagesgäste.", "base": 80, "per_rank": 30, "money": 9000},
	"rides": {"name": "Spuren im Schnee", "text": "Ermögliche zusätzliche Abfahrten.", "base": 60, "per_rank": 40, "money": 11000},
	"beginners": {"name": "Der erste Schwung", "text": "Gewinne neue Anfänger für dein Resort.", "base": 45, "per_rank": 20, "money": 10000},
	"experts": {"name": "Gipfelstürmer", "text": "Begrüße neue erfahrene Skifahrer.", "base": 12, "per_rank": 8, "money": 12000},
	"turnover": {"name": "Ein guter Wintertag", "text": "Erziele zusätzliche Ticket- und Serviceerlöse.", "base": 4500, "per_rank": 2000, "money": 10000},
	"happy": {"name": "Lieblingsberg", "text": "Verabschiede Gäste mit mindestens 80 % Zufriedenheit.", "base": 18, "per_rank": 12, "money": 14000},
	"variety": {"name": "Neue Horizonte", "text": "Biete gleichzeitig mehrere erreichbare Abfahrten an.", "base": 1, "per_rank": 1, "money": 14000},
	"comfort": {"name": "Wohlfühlresort", "text": "Betreibe verschiedene Angebote für deine Gäste.", "base": 2, "per_rank": 1, "money": 12000}
}

static func new_state(model: RefCounted, free_build: bool = false) -> Dictionary:
	return {"version": 1, "mode": "free" if free_build else "career", "xp": float(model.total_rides + model.total_guests * 2), "xp_awarded": 0, "points": 6, "rank": 1, "research": [], "project": {}, "contracts": [], "offers": [], "accepted_today": [], "completed": 0, "turnover": float(model.total_guests * model.ticket_price), "happy": 0, "abilities": [0, 0, 0], "history": [], "profit": 0.0, "finalized_day": 0, "season_reward_day": 0, "notice": "Willkommen in deiner ersten Wintersaison."}

static func has(model: RefCounted, id: String) -> bool:
	return model.campaign.get("research", []).has(id)

static func season_day(model: RefCounted) -> int:
	return (model.day - 1) % 28 + 1

static func season_number(model: RefCounted) -> int:
	return floori(float(model.day - 1) / 28.0) + 1

static func event(model: RefCounted) -> Dictionary:
	match (model.day - 1) % 7:
		2: return {"name": "Schulgruppen", "demand": 1.12, "beginner_share": 0.72, "description": "Heute kommen besonders viele Anfänger. Blaue Rundwege und Verpflegung sind gefragt."}
		5: return {"name": "Familienwochenende", "demand": 1.28, "beginner_share": 0.66, "description": "Mehr Familien besuchen den Berg. Komfort und Liftkapazität zahlen sich aus."}
		6: return {"name": "Sportwochenende", "demand": 1.2, "beginner_share": 0.34, "description": "Heute reisen mehr sportliche Gäste an. Ein abwechslungsreiches Pistennetz lohnt sich."}
	return {"name": "Regulärer Betriebstag", "demand": 1.0, "beginner_share": 0.53, "description": "Zeit, dein Angebot auszubauen und die nächsten Aufträge vorzubereiten."}

static func weather_for_day(seed_value: int, day_number: int) -> int:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value ^ (day_number * 104729)
	return random.randi_range(0, Catalog.WEATHER.size() - 1)

static func access_message(model: RefCounted, kind: String, is_lift: bool) -> String:
	if model.campaign.get("mode", "free") == "free":
		return ""
	var needed := ""
	if is_lift and kind == "chair6":
		needed = "lifttech"
	elif is_lift and kind == "chair8":
		needed = "mastercraft"
	elif is_lift and kind == "gondola":
		needed = "gondola"
	elif not is_lift:
		needed = {"snowmaker": "snowcraft", "maintenance": "snowcraft", "snowpark": "snowcraft", "hotel": "hospitality", "spa": "hospitality"}.get(kind, "")
	return "Forschung „%s“ erforderlich." % RESEARCH[needed].name if needed != "" and not has(model, needed) else ""

static func research_check(model: RefCounted, id: String) -> Dictionary:
	if not RESEARCH.has(id):
		return {"ok": false, "message": "Forschungsprojekt nicht gefunden."}
	var spec: Dictionary = RESEARCH[id]
	if has(model, id):
		return {"ok": false, "message": "Bereits erforscht."}
	if not model.campaign.project.is_empty():
		return {"ok": false, "message": "Zuerst das laufende Projekt abschließen lassen."}
	for prerequisite in spec.requires:
		if not has(model, prerequisite):
			return {"ok": false, "message": "Voraussetzung: %s." % RESEARCH[prerequisite].name}
	if model.campaign.points < spec.points:
		return {"ok": false, "message": "Weitere Forschungspunkte aus Betriebstagen und Aufträgen sammeln."}
	if model.money < spec.cost:
		return {"ok": false, "message": "Das Forschungsbudget reicht noch nicht."}
	return {"ok": true, "message": "%d Betriebstage · %d FP · %d €" % [spec.days, spec.points, spec.cost]}

static func start_research(model: RefCounted, id: String) -> Dictionary:
	var check := research_check(model, id)
	if not check.ok:
		return check
	var spec: Dictionary = RESEARCH[id]
	model._spend(spec.cost)
	model.campaign.points -= spec.points
	model.campaign.project = {"id": id, "start_day": model.day, "due_day": model.day + spec.days}
	model.campaign.notice = "%s gestartet. Fertig an Tag %d." % [spec.name, model.day + spec.days]
	return {"ok": true, "message": model.campaign.notice}

static func upgrade_check(model: RefCounted, id: int) -> Dictionary:
	var item: Dictionary = model.asset(id)
	if item.is_empty():
		return {"ok": false, "message": "Anlage nicht gefunden."}
	var level: int = item.get("level", 1)
	if level >= 3:
		return {"ok": false, "message": "Maximale Ausbaustufe erreicht."}
	var needed := "mastercraft" if level == 2 else ("lifttech" if item.has("bottom") else ("snowcraft" if item.has("difficulty") else "service"))
	if model.campaign.get("mode", "free") != "free" and not has(model, needed):
		return {"ok": false, "message": "Forschung „%s“ erforderlich." % RESEARCH[needed].name}
	var cost := roundi(item.cost * (0.45 if level == 1 else 0.8))
	return {"ok": model.money >= cost, "message": "Stufe %d · %d €" % [level + 1, cost], "cost": cost}

static func upgrade(model: RefCounted, id: int) -> Dictionary:
	var check := upgrade_check(model, id)
	if not check.ok:
		return check
	var item: Dictionary = model.asset(id)
	model._spend(check.cost)
	item.level = int(item.get("level", 1)) + 1
	item.upgrade_total = item.get("upgrade_total", 0.0) + check.cost
	if item.has("condition"):
		item.condition = minf(100, item.condition + 25)
	model.campaign.xp += 120
	model._invalidate()
	model._reroute_guests()
	return {"ok": true, "message": "%s auf Stufe %d ausgebaut." % [item.name, item.level]}

static func on_admission(model: RefCounted, ability: int, revenue: float) -> void:
	model.campaign.xp += 2
	model.campaign.turnover += revenue
	model.campaign.abilities[ability] += 1

static func counter(model: RefCounted, kind: String) -> float:
	match kind:
		"visitors": return model.total_guests
		"rides": return model.total_rides
		"beginners": return model.campaign.abilities[0]
		"experts": return model.campaign.abilities[2]
		"turnover": return model.campaign.turnover
		"happy": return model.campaign.happy
		"variety": return model.reachable_piste_ids().size()
		"comfort":
			var count := 0
			for kind_id in Catalog.BUILDINGS:
				if Catalog.BUILDINGS[kind_id].appeal <= 2:
					continue
				count += int(model.building_count(kind_id) > 0)
			return count
	return 0

static func begin_day(model: RefCounted) -> void:
	var state: Dictionary = model.campaign
	if not state.project.is_empty() and model.day >= state.project.due_day:
		var id: String = state.project.id
		if not state.research.has(id):
			state.research.append(id)
		state.project = {}
		state.notice = "%s abgeschlossen." % RESEARCH[id].name
	state.accepted_today = []
	var random := RandomNumberGenerator.new()
	random.seed = model.rng.seed ^ (model.day * 65537)
	var pool: Array = CONTRACTS.keys()
	state.offers = []
	for i in range(3):
		var index := random.randi_range(0, pool.size() - 1)
		var kind: String = pool.pop_at(index)
		var spec: Dictionary = CONTRACTS[kind]
		var target: int = spec.base + spec.per_rank * state.rank
		if kind == "comfort":
			target = mini(target, 6)
		state.offers.append({"id": "%d-%d" % [model.day, i], "kind": kind, "target": target, "reward": spec.money + state.rank * 2500, "points": 2 + state.rank, "deadline": model.day + 2})
	refresh(model)

static func accept_contract(model: RefCounted, id: String) -> Dictionary:
	var state: Dictionary = model.campaign
	if state.accepted_today.has(id) or state.accepted_today.size() >= 2:
		return {"ok": false, "message": "Pro Tag sind zwei neue Aufträge möglich."}
	var running := 0
	for contract in state.contracts:
		running += int(contract.status in ["active", "ready"])
	if running >= 3:
		return {"ok": false, "message": "Zuerst einen deiner drei laufenden Aufträge abschließen."}
	for offer in state.offers:
		if offer.id == id:
			var contract: Dictionary = offer.duplicate(true)
			contract.baseline = 0.0 if offer.kind in ["variety", "comfort"] else counter(model, offer.kind)
			contract.progress = 0.0
			contract.status = "active"
			state.contracts.append(contract)
			while state.contracts.size() > 12:
				for i in range(state.contracts.size()):
					if state.contracts[i].status in ["claimed", "failed"]:
						state.contracts.remove_at(i)
						break
			state.accepted_today.append(id)
			refresh(model)
			return {"ok": true, "message": "Auftrag angenommen: %s." % CONTRACTS[offer.kind].name}
	return {"ok": false, "message": "Dieses Angebot ist nicht mehr verfügbar."}

static func claim_contract(model: RefCounted, id: String) -> Dictionary:
	refresh(model)
	for contract in model.campaign.contracts:
		if contract.id == id and contract.status == "ready":
			contract.status = "claimed"
			model.campaign.points += contract.points
			model.campaign.completed += 1
			model.campaign.xp += 400
			pay_reward(model, contract.reward)
			refresh(model)
			return {"ok": true, "message": "%d € und %d Forschungspunkte erhalten." % [contract.reward, contract.points]}
	return {"ok": false, "message": "Die Belohnung ist noch nicht verfügbar oder bereits abgeholt."}

static func refresh(model: RefCounted) -> void:
	var state: Dictionary = model.campaign
	if state.is_empty():
		return
	var buckets := floori(state.xp / 1000.0)
	if buckets > state.xp_awarded:
		state.points += (buckets - state.xp_awarded) * 2
		state.xp_awarded = buckets
	for contract in state.contracts:
		if contract.status != "active":
			continue
		if model.day > contract.deadline:
			contract.status = "failed"
			continue
		contract.progress = maxf(0, counter(model, contract.kind) - contract.baseline)
		if contract.progress >= contract.target:
			contract.status = "ready"
			state.notice = "Auftrag erfüllt: %s. Belohnung im Resort-Büro abholen." % CONTRACTS[contract.kind].name
	var colors: Array = []
	var reachable: Array = model.reachable_piste_ids()
	for id in reachable:
		var difficulty: int = model.asset(id).difficulty
		if not colors.has(difficulty):
			colors.append(difficulty)
	var rank: int = state.rank
	if rank < 2 and state.xp >= XP_STEPS[1] and reachable.size() >= 2:
		rank = 2
	if rank == 2 and state.xp >= XP_STEPS[2] and colors.size() >= 2 and model.lifts.size() >= 2 and counter(model, "comfort") >= 3:
		rank = 3
	if rank == 3 and state.xp >= XP_STEPS[3] and colors.size() == 3 and state.research.size() >= 3:
		rank = 4
	if rank == 4 and state.xp >= XP_STEPS[4] and model.reputation >= 75 and model.building_count("hotel") > 0 and reachable.size() >= 6 and model.lifts.size() >= 3 and state.completed >= 6:
		rank = 5
	while state.rank < rank:
		state.rank += 1
		state.points += 3
		pay_reward(model, state.rank * 7500)
		state.notice = "Resort-Stern %d erreicht: %s." % [state.rank, RANK_NAMES[state.rank - 1]]

static func next_goal(model: RefCounted) -> String:
	match int(model.campaign.rank):
		1: return "800 Erfahrung und zwei erreichbare Abfahrten für Stern 2."
		2: return "2.400 Erfahrung, zwei Pistenfarben, zwei Lifte und drei Komfortangebote für Stern 3."
		3: return "6.000 Erfahrung, alle Pistenfarben und drei abgeschlossene Forschungen für Stern 4."
		4: return "12.000 Erfahrung, 75 % Ruf, ein Hotel, sechs erreichbare Abfahrten, drei Lifte und sechs Aufträge für Stern 5."
	return "Verbessere deine Winterwertung, baue Anlagen aus und meistere neue Aufträge."

static func pay_reward(model: RefCounted, amount: float) -> void:
	model.money += amount
	model.report.rewards += amount
	sync_finances(model)

static func sync_finances(model: RefCounted) -> void:
	if model.minute < model.CLOSING or model.last_report.get("day", -1) != model.day:
		return
	model.last_report = model.report.duplicate(true)
	for row in model.campaign.get("history", []):
		if row.day == model.day:
			row.rewards = model.report.rewards
			row.investments = model.report.get("investments", 0.0)
			row.net = row.income + row.rewards - row.costs - row.investments

static func finish_day(model: RefCounted) -> void:
	var state: Dictionary = model.campaign
	if state.finalized_day == model.day:
		return
	state.finalized_day = model.day
	var satisfaction: float = model.report.satisfaction / maxf(model.report.departures, 1)
	state.xp += 50 + satisfaction
	state.points += 2 + mini(3, floori(model.report.guests / 150.0))
	refresh(model)
	if season_day(model) == 28 and state.season_reward_day < model.day:
		state.season_reward_day = model.day
		var prize: int = state.rank * 15000 + mini(state.completed, 20) * 1000
		pay_reward(model, prize)
		state.points += state.rank * 2
		state.notice = "Winter %d abgeschlossen: %d € Saisonprämie. Dein Resort bleibt für den nächsten Winter erhalten." % [season_number(model), prize]
	var income: float = model.report.tickets + model.report.services
	var investments: float = model.report.get("investments", 0.0)
	state.profit += income - model.report.costs
	state.history.append({"day": model.day, "income": income, "costs": model.report.costs, "rewards": model.report.rewards, "investments": investments, "net": income + model.report.rewards - model.report.costs - investments, "guests": model.report.guests, "rides": model.report.rides, "satisfaction": satisfaction})
	if state.history.size() > 28:
		state.history.pop_front()

static func restore(model: RefCounted, value: Variant) -> bool:
	if value == null:
		# Existing 0.1.x resorts retain access to all formerly available buildings.
		model.campaign = new_state(model, true)
		begin_day(model)
		return true
	if not value is Dictionary or value.get("version") != 1 or value.get("mode") not in ["career", "free"]:
		return false
	var state: Dictionary = value.duplicate(true)
	var ranges := {"xp": [0, 10000000000], "xp_awarded": [0, 10000000], "points": [0, 10000000], "rank": [1, 5], "completed": [0, 10000000], "turnover": [0, 100000000000], "happy": [0, 1000000000], "profit": [-100000000000, 100000000000], "finalized_day": [0, model.day], "season_reward_day": [0, model.day]}
	for key in ranges:
		if not Terrain.number(state.get(key)) or state[key] < ranges[key][0] or state[key] > ranges[key][1]:
			return false
		if key not in ["xp", "turnover", "profit"]:
			if state[key] != floorf(state[key]):
				return false
			state[key] = int(state[key])
	for key in ["research", "contracts", "offers", "accepted_today", "abilities", "history"]:
		if not state.get(key) is Array:
			return false
	if state.research.size() > RESEARCH.size() or state.contracts.size() > 12 or state.offers.size() > 3 or state.accepted_today.size() > 2 or state.history.size() > 28 or state.abilities.size() != 3:
		return false
	var seen: Array = []
	for id in state.research:
		if not id is String or not RESEARCH.has(id) or seen.has(id):
			return false
		seen.append(id)
	for i in range(3):
		if not Terrain.number(state.abilities[i]) or state.abilities[i] < 0 or state.abilities[i] > 1000000000 or state.abilities[i] != floorf(state.abilities[i]):
			return false
		state.abilities[i] = int(state.abilities[i])
	if not state.get("project") is Dictionary or not state.get("notice") is String or state.notice.length() > 500:
		return false
	if not state.project.is_empty():
		if not RESEARCH.has(state.project.get("id")):
			return false
		for key in ["start_day", "due_day"]:
			if not Terrain.number(state.project.get(key)) or state.project[key] < 1 or state.project[key] > 1000010 or state.project[key] != floorf(state.project[key]):
				return false
			state.project[key] = int(state.project[key])
		if state.project.due_day <= state.project.start_day or state.research.has(state.project.id):
			return false
	for accepted in state.accepted_today:
		if not accepted is String or accepted.length() > 50:
			return false
	seen = []
	for collection in [state.contracts, state.offers]:
		for contract in collection:
			if not contract is Dictionary or not contract.get("id") is String or contract.id.length() > 50 or not CONTRACTS.has(contract.get("kind")):
				return false
			for key in ["target", "reward", "points", "deadline"]:
				if not Terrain.number(contract.get(key)) or contract[key] < 1 or contract[key] > 10000000 or contract[key] != floorf(contract[key]):
					return false
				contract[key] = int(contract[key])
			if collection == state.contracts:
				if seen.has(contract.id) or contract.get("status") not in ["active", "ready", "claimed", "failed"]:
					return false
				seen.append(contract.id)
				for key in ["baseline", "progress"]:
					if not Terrain.number(contract.get(key)) or contract[key] < 0 or contract[key] > 100000000000:
						return false
	for row in state.history:
		if not row is Dictionary:
			return false
		for key in ["day", "income", "costs", "rewards", "investments", "net", "guests", "rides", "satisfaction"]:
			if not Terrain.number(row.get(key)) or absf(row[key]) > 100000000000 or (key != "net" and row[key] < 0):
				return false
	model.campaign = state
	return true
