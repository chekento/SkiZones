extends RefCounted
const L = preload("res://src/core/i18n.gd")
## Deterministic 20 x 50 achievement catalogue: no thousand static save objects.
## IDs 0..3 are the historic achievements and remain unchanged.
const TIERS := 50
const START_ID := 4
const TRACKS := [
	{"key": "rides", "name": "Schwung für Schwung", "unit": "Abfahrten", "step": 80, "curve": 1.75},
	{"key": "guests", "name": "Beliebter Berg", "unit": "Gäste", "step": 120, "curve": 1.75},
	{"key": "pistes", "name": "Pistenarchitekt", "unit": "Pisten", "step": 1, "curve": 1.0},
	{"key": "lifts", "name": "Gipfelverbinder", "unit": "Lifte", "step": 1, "curve": 1.0},
	{"key": "buildings", "name": "Alpendorf", "unit": "Gebäude", "step": 1, "curve": 1.0},
	{"key": "paths", "name": "Wegebauer", "unit": "Wege & Plätze", "step": 1, "curve": 1.0},
	{"key": "reputation", "name": "Lieblingsresort", "unit": "% Ruf", "step": 2, "curve": 1.0},
	{"key": "cash", "name": "Finanzgenie", "unit": "€ Kontostand", "step": 100000, "curve": 1.45},
	{"key": "contracts", "name": "Auftragsprofi", "unit": "Aufträge", "step": 2, "curve": 1.25},
	{"key": "xp", "name": "Resort-Legende", "unit": "XP", "step": 1000, "curve": 1.8},
	{"key": "days", "name": "Winter für Winter", "unit": "Betriebstage", "step": 4, "curve": 1.3},
	{"key": "satisfaction", "name": "Glückliche Gäste", "unit": "% Zufriedenheit", "step": 2, "curve": 1.0},
	{"key": "turnover", "name": "Umsatzwunder", "unit": "€ Gesamtumsatz", "step": 25000, "curve": 1.7},
	{"key": "profit", "name": "Solide Kasse", "unit": "€ Überschuss", "step": 12000, "curve": 1.6},
	{"key": "hotel", "name": "Gastgeber", "unit": "Hotels", "step": 1, "curve": 1.0},
	{"key": "restaurants", "name": "Genussgipfel", "unit": "Gastronomie", "step": 1, "curve": 1.0},
	{"key": "ski_length", "name": "Schneeband", "unit": "Pistenmeter", "step": 450, "curve": 1.6},
	{"key": "lift_length", "name": "Höhenmeterjäger", "unit": "Liftmeter", "step": 400, "curve": 1.6},
	{"key": "upgrades", "name": "Feinschliff", "unit": "Ausbaustufen", "step": 1, "curve": 1.0},
	{"key": "boarded", "name": "Bergwärts", "unit": "Liftfahrten", "step": 100, "curve": 1.6}
]
const TOTAL := 1000
const MAX_RANK := 500
const MASTERY_XP_FACTOR := 5.0

static func target(track: int, tier: int) -> int:
	if track < 0 or track >= TRACKS.size() or tier < 1 or tier > TIERS:
		return -1
	var spec: Dictionary = TRACKS[track]
	return maxi(1, roundi(float(spec.step) * pow(float(tier), float(spec.curve))))

static func entry(id: int) -> Dictionary:
	if id < START_ID or id >= START_ID + TOTAL: return {}
	var track: int = (id - START_ID) / TIERS
	var tier: int = (id - START_ID) % TIERS + 1
	var spec: Dictionary = TRACKS[track]
	return {"id": id, "track": track, "tier": tier, "name": L.text("%s · %02d") % L.args([L.text(spec.name), tier]),
		"goal": L.text("%d %s") % L.args([target(track,tier), L.text(spec.unit)]), "reward": 350 + tier * 90}

static func mastery_for_xp(xp: float) -> int:
	return clampi(1 + floori(sqrt(maxf(0.0,xp) / MASTERY_XP_FACTOR)),1,MAX_RANK)

static func xp_for_rank(rank: int) -> int:
	var n: int = clampi(rank,1,MAX_RANK)-1
	return roundi(MASTERY_XP_FACTOR*float(n)*float(n))

static func values(model: RefCounted) -> Array:
	var hotel := 0
	var restaurants := 0
	var ski_length := 0.0
	var lift_length := 0.0
	var upgrades := 0
	var boarded := 0
	for piste in model.pistes:
		ski_length += float(piste.get("length", 0.0))
		upgrades += maxi(0,int(piste.get("level",1))-1)
	for lift in model.lifts:
		lift_length += float(lift.get("length", 0.0))
		boarded += int(lift.get("boarded",0))
		upgrades += maxi(0,int(lift.get("level",1))-1)
	for building in model.buildings:
		hotel += int(building.kind == "hotel")
		restaurants += int(building.kind in ["kiosk","cocoa","schmarrn","pizzeria","restaurant"])
		upgrades += maxi(0,int(building.get("level",1))-1)
	var state: Dictionary = model.campaign
	var satisfaction := 0.0
	if int(model.report.get("departures",0)) > 0:
		satisfaction = float(model.report.get("satisfaction",0.0)) / float(model.report.departures)
	return [model.total_rides,model.total_guests,model.pistes.size(),model.lifts.size(),
		model.buildings.size(),model.walk_areas.size(),model.reputation,model.money,
		int(state.get("completed",0)),float(state.get("xp",0.0)),model.day,
		satisfaction,float(state.get("turnover",0.0)),maxf(0.0,float(state.get("profit",0.0))),
		hotel,restaurants,ski_length,lift_length,upgrades,boarded]

static func unlock(model: RefCounted) -> Array:
	# Called on the regular simulation tick. At most 20x50 integer comparisons.
	# Only newly earned IDs are returned; no payout or popup is repeated.
	var unlocked: Array = []
	var values_now: Array = values(model)
	var earned: Dictionary = {}
	for id in model.achievements: earned[int(id)] = true
	for track in range(TRACKS.size()):
		for tier in range(1,TIERS+1):
			if float(values_now[track]) < float(target(track,tier)):
				break
			var id: int = START_ID + track*TIERS + tier-1
			if earned.has(id): continue
			var achievement: Dictionary = entry(id)
			model.achievements.append(id)
			earned[id] = true
			unlocked.append(achievement)
			var reward: float = float(achievement.reward)
			model.money += reward
			model.report.rewards += reward
	return unlocked
