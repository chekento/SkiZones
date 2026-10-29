extends RefCounted
## Persisted personal needs, changed by activity and completed visits.
const Terrain = preload("res://src/core/terrain.gd")
const SERVICES := {
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
	return true

static func advance(guest: Dictionary, temperature: float) -> void:
	ensure(guest,temperature)
	var state: Dictionary=guest.needs
	var kind := ""
	if guest.phase!="leaving" and guest.leg<guest.route.legs.size(): kind=guest.route.legs[guest.leg].kind
	state.hunger=minf(100,state.hunger+0.20)
	state.warmth=maxf(0,state.warmth-(maxf(0,2-temperature)*0.012 if kind!="visit" else 0))
	state.energy=clampf(state.energy+(0.07 if kind=="lift" else -0.12 if kind=="ski" else -0.055),0,100)
	state.joy=maxf(0,state.joy-(0.18 if guest.phase=="queue" else 0.07))

static func utility(guest: Dictionary, kind: String) -> float:
	if not SERVICES.has(kind): return 0
	var state: Dictionary=guest.needs
	var service: Dictionary=SERVICES[kind]
	if guest.age-guest.service_history.get(kind,-10000)<55: return 0
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
	for key in FIELDS:
		var change: float=-SERVICES[kind][key] if key=="hunger" else SERVICES[kind][key]
		guest.needs[key]=clampf(guest.needs[key]+change,0,100)
	if kind=="rental": guest.needs.rental=false
	if kind=="school": guest.needs.lesson=false
	guest.service_history[kind]=guest.age
	guest.spent=true
