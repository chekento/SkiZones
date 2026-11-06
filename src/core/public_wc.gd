extends RefCounted
## Independent PUBLIC sanitation manager. Hotels and restaurants have their
## own included restrooms; they do not acquire a public-WC module or state.
## All optional data is validated so older 0.19-0.37 saves load unchanged.
const L=preload("res://src/core/i18n.gd")
const Terrain=preload("res://src/core/terrain.gd")
const KINDS := ["wc_dixi","wc_cabin","wc_module","wc_house","wc_luxury"]
const PLACES := {"wc_dixi":1,"wc_cabin":2,"wc_module":4,"wc_house":8,"wc_luxury":16}
const VOLUME := {"wc_dixi":18.0,"wc_cabin":34.0,"wc_module":72.0,"wc_house":150.0,"wc_luxury":340.0}

static func is_public(kind: String) -> bool:
	return kind in KINDS

static func _default(model: RefCounted) -> Dictionary:
	return {"version":1,"hygiene":100.0,"fill":0.0,"visits":0,"emptied":0,"cleaned":0,"last_day":int(model.day),"winterized":false}

static func state(model: RefCounted,building: Dictionary) -> Dictionary:
	return building.get("wc_public",_default(model))

static func status(model: RefCounted,building: Dictionary) -> Dictionary:
	if not is_public(str(building.get("kind",""))):return {}
	var s: Dictionary=state(model,building)
	var units: int=int(PLACES[building.kind])*maxi(1,int(building.get("level",1)))
	var waiting: int=model.service_load(int(building.id)) if model!=null else 0
	var capacity: int=model.service_capacity(building)
	var cleaning: int=15+units*5
	var disposal: int=20+ceili(float(VOLUME[building.kind])*0.3)
	return {"hygiene":float(s.hygiene),"fill":float(s.fill),"capacity":capacity,
		"waiting":waiting,"visits":int(s.visits),"units":units,
		"clean_cost":cleaning,"empty_cost":disposal,
		"winterized":bool(s.winterized),"winter_cost":100+units*45,
		"ready":bool(building.get("enabled",false)) and float(s.hygiene)>=20.0 and float(s.fill)<96.0}

static func available(model: RefCounted,building: Dictionary) -> bool:
	var info: Dictionary=status(model,building)
	return bool(info.get("ready",false))

static func visit(model: RefCounted,building: Dictionary,count: int=1) -> void:
	if not is_public(str(building.get("kind",""))) or count<1:return
	var s: Dictionary=state(model,building).duplicate(true)
	var volume: float=float(VOLUME[building.kind]) * float(maxi(1,int(building.get("level",1))))
	s.fill=clampf(float(s.fill)+100.0*float(count)/volume,0.0,100.0)
	s.hygiene=clampf(float(s.hygiene)-0.65*float(count),0.0,100.0)
	s.visits=int(s.visits)+count
	building.wc_public=s
	model._operational_change()

static func daily(model: RefCounted,building: Dictionary) -> void:
	if not is_public(str(building.get("kind",""))) or not building.has("wc_public"):return
	var s: Dictionary=building.wc_public
	var delta: int=maxi(0,int(model.day)-int(s.last_day))
	if delta==0:return
	s.hygiene=clampf(float(s.hygiene)-float(mini(delta,10))*(0.75 if s.winterized else 2.0),0.0,100.0)
	s.last_day=int(model.day)
	building.wc_public=s

static func action(model: RefCounted,id: int,command: String) -> Dictionary:
	var item: Dictionary=model.asset(id)
	if not is_public(str(item.get("kind",""))):return model._result(false,L.text("Eine öffentliche WC-Anlage auswählen."))
	var s: Dictionary=state(model,item).duplicate(true)
	var info: Dictionary=status(model,item)
	var cost:=0
	match command:
		"clean":
			if float(s.hygiene)>=99.95:return model._result(false,L.text("Die öffentlichen Toiletten sind bereits sauber."))
			cost=int(info.clean_cost)
		"empty":
			if float(s.fill)<=0.01:return model._result(false,L.text("Der Fäkalientank ist bereits leer."))
			cost=int(info.empty_cost)
		"winterize":
			if bool(s.winterized):return model._result(false,L.text("Frostschutz ist bereits installiert."))
			cost=int(info.winter_cost)
		_:return model._result(false,L.text("Unbekannte Toilettenaktion."))
	if not model.Ops._expense(model,cost,"sanitation:%d"%id):
		return model._result(false,L.text("Das Budget reicht für diesen WC-Service nicht."))
	if command=="clean":
		s.hygiene=100.0;s.cleaned=int(s.cleaned)+1
	elif command=="empty":
		s.fill=0.0;s.emptied=int(s.emptied)+1
	else:s.winterized=true
	s.last_day=int(model.day)
	item.wc_public=s
	model._operational_change()
	return model._result(true,L.text("Öffentlicher Toilettenservice ausgeführt · %d €.") % cost)

static func valid(building: Dictionary) -> bool:
	var public: bool=is_public(str(building.get("kind","")))
	if not building.has("wc_public"):return true
	if not public or not building.wc_public is Dictionary:return false
	var s: Dictionary=building.wc_public
	if s.size()!=8:return false
	if not Terrain.number(s.get("version")) or s.version!=1:return false
	for key in ["visits","emptied","cleaned","last_day"]:
		var n: Variant=s.get(key)
		if not Terrain.number(n) or n!=floorf(float(n)) or n<0 or n>100000000:return false
	for key in ["hygiene","fill"]:
		var n: Variant=s.get(key)
		if not Terrain.number(n) or n<0 or n>100:return false
	return s.get("winterized") is bool
