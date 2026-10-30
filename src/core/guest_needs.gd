extends RefCounted
## Persisted personal needs, changed by activity and completed visits.
const Terrain = preload("res://src/core/terrain.gd")
const SERVICES := {
	"disco": {"hunger":25,"warmth":50,"energy":-5,"joy":90,"minutes":60,"places":40},
	"pool": {"hunger":0,"warmth":80,"energy":75,"joy":65,"minutes":45,"places":24},
	"kiosk": {"hunger":40,"warmth":20,"energy":8,"joy":5,"minutes":7,"places":8},
	"restaurant": {"hunger":85,"warmth":35,"energy":28,"joy":15,"minutes":20,"places":24},
	"lodge": {"hunger":20,"warmth":60,"energy":48,"joy":15,"minutes":16,"places":18},
	"shelter": {"hunger":0,"warmth":55,"energy":32,"joy":5,"minutes":10,"places":12},
	"viewpoint": {"hunger":0,"warmth":0,"energy":35,"joy":55,"minutes":10,"places":12},
	"spa": {"hunger":0,"warmth":75,"energy":70,"joy":45,"minutes":25,"places":14},
	"hotel": {"hunger":35,"warmth":65,"energy":60,"joy":30,"minutes":24,"places":24},
	"rental": {"hunger":0,"warmth":0,"energy":0,"joy":5,"minutes":9,"places":10},
	"school": {"hunger":0,"warmth":0,"energy":0,"joy":30,"minutes":22,"places":10},
	"first_aid": {"hunger":0,"warmth":35,"energy":55,"joy":10,"minutes":12,"places":6},
	"snowpark": {"hunger":0,"warmth":0,"energy":-8,"joy":65,"minutes":14,"places":16}
}
const FIELDS := ["hunger","warmth","energy","joy"]

static func legacy(guest: Dictionary, temperature: float) -> Dictionary:
	var fed: bool = guest.get("spent",false)
	return {"hunger":clampf(guest.age*0.25-(65 if fed else 0),0,100),
		"warmth":clampf(85+temperature*2-guest.age*0.055+(20 if fed else 0),0,100),
		"energy":clampf(100-guest.get("runs",0)*4.5-guest.age*0.045+(15 if fed else 0),5,100),
		"joy":clampf(85-guest.age*0.08,10,100),
		"rental":not fed and int(guest.id)%4==0,
		"lesson":not fed and int(guest.ability)==0 and int(guest.id)%3==0}

static func values(guest: Dictionary, temperature: float) -> Dictionary:
	return guest.get("needs",legacy(guest,temperature))

static func ensure(guest: Dictionary, temperature: float) -> void:
	if not guest.has("needs"): guest.needs=legacy(guest,temperature)
	if not guest.has("service_history"): guest.service_history={}

static func valid(guest: Dictionary) -> bool:
	if not guest.get("needs") is Dictionary or not guest.get("service_history") is Dictionary: return false
	for key in FIELDS:
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

static func advance(guest: Dictionary, temperature: float) -> void:
	ensure(guest,temperature)
	var kind := ""
	if guest.phase!="leaving" and guest.leg<guest.route.legs.size(): kind=guest.route.legs[guest.leg].kind
	var dose: Dictionary = {}
	if kind == "visit" and SERVICES.has(guest.get("visit_kind", "")):
		if not guest.has("visit_benefits"): guest.visit_benefits = {}
		for field in FIELDS:
			var total: float = SERVICES[guest.visit_kind][field]
			var given: float = guest.visit_benefits.get(field, 0.0)
			dose[field] = minf(maxf(0, total - given), maxf(0, total) / maxf(1, guest.get("duration", 1)))
			guest.visit_benefits[field] = given + dose[field]
	if guest.has("family"):
		for member in guest.family: _advance_values(member.needs, kind, guest.phase == "queue", temperature, member.years < 16, dose)
		aggregate_family(guest)
	else: _advance_values(guest.needs, kind, guest.phase == "queue", temperature, false, dose)

static func _advance_values(state: Dictionary, kind: String, queue: bool, temperature: float, child: bool, dose: Dictionary) -> void:
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
		for field in ["rental", "lesson"]: summary[field] = summary[field] or member.needs[field]
	guest.needs = summary

static func urgent(guest: Dictionary) -> bool:
	return guest.needs.hunger >= 70 or guest.needs.warmth < 35 or guest.needs.energy < 25

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
	if kind=="rental" and state.rental: score+=75
	if kind=="school" and state.lesson: score+=65
	return score

static func complete(guest: Dictionary, kind: String) -> void:
	if not SERVICES.has(kind): return
	var states: Array = guest.family.map(func(member): return member.needs) if guest.has("family") else [guest.needs]
	for state in states:
		for key in FIELDS:
			var amount: float = SERVICES[kind][key]
			if guest.get("visit_kind", "") == kind and amount > 0: amount = maxf(0, amount - guest.get("visit_benefits", {}).get(key, 0))
			state[key]=clampf(state[key] + (-amount if key=="hunger" else amount),0,100)
		if kind=="rental": state.rental=false
		if kind=="school": state.lesson=false
	aggregate_family(guest)
	guest.service_history[kind]=guest.age
	guest.spent=true
