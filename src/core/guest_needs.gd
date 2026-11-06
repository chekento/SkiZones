extends RefCounted
## Persisted personal needs, changed by activity and completed visits.
const Terrain = preload("res://src/core/terrain.gd")
const SERVICES := {
	# Public toilets are standalone service visits. Hotel and restaurant
	# bathrooms are included with those buildings, without a WC upgrade tab.
	"wc_dixi":{"hunger":0,"warmth":0,"energy":0,"joy":0,"minutes":3,"places":1},
	"wc_cabin":{"hunger":0,"warmth":0,"energy":0,"joy":0,"minutes":3,"places":2},
	"wc_module":{"hunger":0,"warmth":0,"energy":0,"joy":0,"minutes":3,"places":4},
	"wc_house":{"hunger":0,"warmth":5,"energy":0,"joy":3,"minutes":4,"places":8},
	"wc_luxury":{"hunger":0,"warmth":8,"energy":0,"joy":7,"minutes":4,"places":16},
	"cocoa": {"hunger":20,"warmth":65,"energy":15,"joy":12,"minutes":8,"places":10},
	"schmarrn": {"hunger":65,"warmth":35,"energy":22,"joy":20,"minutes":13,"places":14},
	"pizzeria": {"hunger":90,"warmth":30,"energy":24,"joy":18,"minutes":22,"places":20},
	"disco": {"hunger":25,"warmth":50,"energy":-5,"joy":90,"minutes":60,"places":40},
	"pool": {"hunger":0,"warmth":80,"energy":75,"joy":65,"minutes":45,"places":24},
	"kiosk": {"hunger":40,"warmth":20,"energy":8,"joy":5,"minutes":7,"places":8},
	"restaurant": {"hunger":85,"warmth":35,"energy":28,"joy":15,"minutes":20,"places":24},
	"lodge": {"hunger":20,"warmth":60,"energy":48,"joy":15,"minutes":16,"places":18},
	"shelter": {"hunger":0,"warmth":55,"energy":32,"joy":5,"minutes":10,"places":12},
	"viewpoint": {"hunger":0,"warmth":0,"energy":35,"joy":55,"minutes":10,"places":12},
	"spa": {"hunger":0,"warmth":75,"energy":70,"joy":45,"minutes":25,"places":14},
	"hotel": {"hunger":35,"warmth":65,"energy":60,"joy":30,"minutes":24,"places":24},
	"cabin":{"hunger":0,"warmth":65,"energy":70,"joy":25,"minutes":16,"places":4},
	"apartment":{"hunger":15,"warmth":65,"energy":70,"joy":30,"minutes":18,"places":8},
	"chalet":{"hunger":25,"warmth":70,"energy":75,"joy":40,"minutes":20,"places":12},
	"guesthouse":{"hunger":35,"warmth":65,"energy":65,"joy":30,"minutes":22,"places":20},
	"grand_hotel":{"hunger":45,"warmth":75,"energy":80,"joy":45,"minutes":24,"places":48},
	"bar":{"hunger":10,"warmth":45,"energy":8,"joy":70,"minutes":30,"places":20},
	"newsstand": {"hunger":0,"warmth":8,"energy":0,"joy":18,"minutes":6,"places":8},
	"fitness": {"hunger":0,"warmth":36,"energy":12,"joy":38,"minutes":30,"places":18},
	"souvenir": {"hunger":0,"warmth":20,"energy":2,"joy":36,"minutes":12,"places":12},
	"watchmaker": {"hunger":0,"warmth":20,"energy":1,"joy":30,"minutes":16,"places":8},
	"craftshop": {"hunger":0,"warmth":20,"energy":2,"joy":40,"minutes":18,"places":12},
	"rental": {"hunger":0,"warmth":0,"energy":0,"joy":5,"minutes":9,"places":10},
	"school": {"hunger":0,"warmth":0,"energy":0,"joy":30,"minutes":22,"places":10},
	"first_aid": {"hunger":0,"warmth":35,"energy":55,"joy":10,"minutes":12,"places":6},
	"snowpark": {"hunger":0,"warmth":0,"energy":-8,"joy":65,"minutes":14,"places":16}
}
const FIELDS := ["hunger","warmth","energy","joy"]
const BATHROOM_FIELDS := ["bladder","bowel"]
const INDOOR_WCS := ["hotel","grand_hotel","guesthouse","cabin","apartment","chalet","restaurant","pizzeria","lodge","bar","disco","schmarrn","cocoa"]

static func legacy(guest: Dictionary, temperature: float) -> Dictionary:
	var fed: bool = guest.get("spent",false)
	return {"hunger":clampf(guest.age*0.25-(65 if fed else 0),0,100),
		"warmth":clampf(85+temperature*2-guest.age*0.055+(20 if fed else 0),0,100),
		"energy":clampf(100-guest.get("runs",0)*4.5-guest.age*0.045+(15 if fed else 0),5,100),
		"joy":clampf(85-guest.age*0.08,10,100),
		"rental":not fed and int(guest.id)%4==0,
		"lesson":not fed and int(guest.ability)==0 and int(guest.id)%3==0,
		"bladder":clampf(12.0+float(guest.get("age",0))*0.13,0,100),
		"bowel":clampf(3.0+float(guest.get("age",0))*0.018,0,100)}

static func values(guest: Dictionary, temperature: float) -> Dictionary:
	return guest.get("needs",legacy(guest,temperature))

static func ensure(guest: Dictionary, temperature: float) -> void:
	if not guest.has("needs"):guest.needs=legacy(guest,temperature)
	# Optional keys: legacy saves need no destructive version migration.
	if not guest.needs.has("bladder"):guest.needs.bladder=15.0
	if not guest.needs.has("bowel"):guest.needs.bowel=4.0
	if guest.has("family"):
		for member in guest.family:
			if not member.needs.has("bladder"):member.needs.bladder=15.0
			if not member.needs.has("bowel"):member.needs.bowel=4.0
	if not guest.has("service_history"):guest.service_history={}

static func valid(guest: Dictionary) -> bool:
	if not guest.get("needs") is Dictionary or not guest.get("service_history") is Dictionary: return false
	for key in FIELDS + BATHROOM_FIELDS:
		if key in BATHROOM_FIELDS and not guest.needs.has(key):continue
		if not Terrain.number(guest.needs.get(key)) or guest.needs[key]<0 or guest.needs[key]>100: return false
	for key in ["rental","lesson"]:
		if not guest.needs.get(key) is bool: return false
	for kind in guest.service_history:
		if not SERVICES.has(kind) or not Terrain.number(guest.service_history[kind]) or guest.service_history[kind]<0 or guest.service_history[kind]>guest.age: return false
	if guest.has("visit_kind") and not SERVICES.has(guest.visit_kind): return false
	if guest.has("visit_benefits"):
		if not guest.get("visit_kind") is String or not SERVICES.has(guest.visit_kind) or not guest.visit_benefits is Dictionary: return false
		for field in guest.visit_benefits:
			if field not in FIELDS or not Terrain.number(guest.visit_benefits[field]) or guest.visit_benefits[field] < 0 or guest.visit_benefits[field] > maxf(0, SERVICES[guest.visit_kind][field]) + 0.001: return false
	return true

static func advance(guest: Dictionary, temperature: float, natural: bool = true) -> void:
	ensure(guest,temperature)
	# Hotel residents rest safely indoors; needs recover when they wake.
	if guest.phase == "waiting" and guest.get("waiting_reason", "") == "hotel": return
	var kind := ""
	if guest.phase!="leaving" and guest.leg<guest.route.legs.size(): kind=guest.route.legs[guest.leg].kind
	if guest.phase=="waiting": kind=""
	if not natural and kind!="visit": return
	var dose: Dictionary = {}
	if kind == "visit" and not guest.route.legs[guest.leg].get("pause_only",false) and SERVICES.has(guest.get("visit_kind", "")):
		if not guest.has("visit_benefits"): guest.visit_benefits = {}
		for field in FIELDS:
			var total: float = SERVICES[guest.visit_kind][field]
			var given: float = guest.visit_benefits.get(field, 0.0)
			dose[field] = minf(maxf(0, total - given), maxf(0, total) / maxf(1, guest.get("duration", 1)))
			guest.visit_benefits[field] = given + dose[field]
	if guest.has("family"):
		for member in guest.family: _advance_values(member.needs, kind, guest.phase == "queue", temperature, member.years < 16, dose, natural)
		aggregate_family(guest)
	else: _advance_values(guest.needs, kind, guest.phase == "queue", temperature, guest.get("years",18)<16, dose, natural)

static func _advance_values(state: Dictionary, kind: String, queue: bool, temperature: float, child: bool, dose: Dictionary, natural: bool) -> void:
	if natural:
		# Liquid intake produces more frequent urination than bowel movements.
		state.bladder=minf(100,float(state.get("bladder",15))+ (0.19 if child else 0.26))
		state.bowel=minf(100,float(state.get("bowel",4))+0.028)
		state.hunger=minf(100,state.hunger+(0.25 if child else 0.20))
		state.warmth=maxf(0,state.warmth-(maxf(0,2-temperature)*0.012*(1.3 if child else 1.0) if kind!="visit" else 0))
		state.energy=clampf(state.energy+(0.07 if kind=="lift" else -0.14 if kind=="ski" and child else -0.12 if kind=="ski" else -0.055),0,100)
		state.joy=maxf(0,state.joy-(0.18 if queue else 0.07))
	for field in dose: state[field] = clampf(state[field] + dose[field] * (-1 if field == "hunger" else 1), 0, 100)

static func aggregate_family(guest: Dictionary) -> void:
	if not guest.has("family") or guest.family.is_empty(): return
	var summary: Dictionary = guest.family[0].needs.duplicate()
	for member in guest.family:
		summary.hunger = maxf(summary.hunger, member.needs.hunger)
		for field in ["energy", "warmth", "joy"]: summary[field] = minf(summary[field], member.needs[field])
		for field in BATHROOM_FIELDS:summary[field]=maxf(float(summary.get(field,0)),float(member.needs.get(field,0)))
		for field in ["rental", "lesson"]: summary[field] = summary[field] or member.needs[field]
	guest.needs = summary

static func urgent(guest: Dictionary) -> bool:
	return guest.needs.hunger >= 70 or guest.needs.warmth < 35 or guest.needs.energy < 25 or float(guest.needs.get("bladder",0))>=72 or float(guest.needs.get("bowel",0))>=85

static func utility(guest: Dictionary, kind: String) -> float:
	if not SERVICES.has(kind): return 0
	var state: Dictionary=guest.needs
	var service: Dictionary=SERVICES[kind]
	if guest.age-guest.service_history.get(kind,-10000)<55 and not (state.hunger > 90 and service.hunger > 0 or state.warmth < 20 and service.warmth > 0 or state.energy < 10 and service.energy > 0): return 0
	var score:=0.0
	if state.hunger>=45: score+=minf(service.hunger,state.hunger)*(1.3 if state.hunger>=70 else 0.8)
	if state.warmth<58: score+=minf(service.warmth,100-state.warmth)*(1.6 if state.warmth<35 else 1.0)
	if state.energy<55: score+=maxf(0,minf(service.energy,100-state.energy))*(1.4 if state.energy<30 else 0.85)
	if state.joy<45: score+=minf(service.joy,100-state.joy)*0.7
	if kind=="rental" and state.rental:score+=75
	if kind=="school" and state.lesson:score+=65
	var urgency:float=maxf(float(state.get("bladder",0)),float(state.get("bowel",0)))
	if kind.begins_with("wc_"):
		# Do not route low-urgency guests to every available toilet.
		if urgency<48:return 0.0
		score+=urgency*1.8 + (25 if urgency>=78 else 0)
	elif kind in INDOOR_WCS and urgency>=65:
		# Restaurants and hotels already contain normal, free-to-use toilets.
		score+=urgency*0.95
	return score

static func complete(guest: Dictionary, kind: String) -> void:
	if not SERVICES.has(kind): return
	var states: Array = guest.family.map(func(member): return member.needs) if guest.has("family") else [guest.needs]
	for state in states:
		for key in FIELDS:
			var amount: float = SERVICES[kind][key]
			if guest.get("visit_kind", "") == kind and amount > 0: amount = maxf(0, amount - guest.get("visit_benefits", {}).get(key, 0))
			state[key]=clampf(state[key] + (-amount if key=="hunger" else amount),0,100)
		if kind=="rental":state.rental=false
		if kind=="school":state.lesson=false
		if kind.begins_with("wc_") or kind in INDOOR_WCS:
			state.bladder=0.0
			state.bowel=0.0
		# Drinks accelerate toilet demand without treating every meal as a drink.
		elif kind in ["bar","cocoa","kiosk","disco"]:
			state.bladder=minf(100.0,float(state.get("bladder",0))+ (16.0 if kind=="bar" else 12.0))
	aggregate_family(guest)
	guest.service_history[kind]=guest.age
	guest.spent=true


