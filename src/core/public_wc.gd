extends RefCounted
## Independent PUBLIC sanitation manager. Hotels and restaurants have their
## own included restrooms; they do not acquire a public-WC module or state.
## All optional data is validated so older 0.19-0.37 saves load unchanged.
const L=preload("res://src/core/i18n.gd")
const Terrain=preload("res://src/core/terrain.gd")
const KINDS := ["wc_dixi","wc_cabin","wc_module","wc_house","wc_luxury"]
const PLACES := {"wc_dixi":1,"wc_cabin":2,"wc_module":4,"wc_house":8,"wc_luxury":16}
const VOLUME := {"wc_dixi":18.0,"wc_cabin":34.0,"wc_module":72.0,"wc_house":150.0,"wc_luxury":340.0}
const MAX_QUEUE_MINUTES := 18.0

static func specification(building: Dictionary) -> Dictionary:
	var level: int=clampi(int(building.get("level",1)),1,5)
	var units: int=int(PLACES[building.kind])*level
	return {"units":units,"volume":float(VOLUME[building.kind])*level*(1.3 if level>=3 else 1.0),
		"hygiene_use":0.65*(0.65 if level>=4 else 1.0),
		"service_factor":0.8 if level>=5 else 1.0,
		"aging_factor":0.75 if level>=5 else 1.0,
		"minutes":3.0 if building.kind in ["wc_dixi","wc_cabin","wc_module"] else 4.0}

static func initialize(model: RefCounted, building: Dictionary) -> void:
	if is_public(str(building.get("kind",""))) and not building.has("wc_public"):
		building.wc_public=_default(model)

static func visit_minutes(building: Dictionary, count: int) -> float:
	var spec: Dictionary=specification(building)
	return ceili(float(maxi(1,count))/int(spec.units))*float(spec.minutes)

static func reservation(model: RefCounted, building: Dictionary, guest: Dictionary) -> Dictionary:
	# Reserve finite waste/hygiene and queue time, rather than requiring an
	# entire family to fit in a single cabin simultaneously. Their service
	# duration includes successive batches; other parties retain their turn.
	var spec: Dictionary=specification(building)
	var count: int=maxi(1,int(guest.get("group_size",1)))
	var load: int=model.service_load(int(building.id),int(guest.id))
	var s: Dictionary=state(model,building)
	var minutes: float=visit_minutes(building,load+count)
	return {"ok":available(model,building) and minutes<=MAX_QUEUE_MINUTES and
		float(s.fill)+100.0*(load+count)/float(spec.volume)<96.0 and
		float(s.hygiene)-float(spec.hygiene_use)*(load+count)>=20.0,
		"minutes":visit_minutes(building,count),"wait":maxf(0,minutes-visit_minutes(building,count))}

static func steps(model: RefCounted) -> Dictionary:
	# Only current door visits consume physical stalls. Travelling guests
	# keep a reservation but do not block a cabin before arriving. A visitor
	# already in service finishes before a newcomer; arrival clock and ID
	# break ties reproducibly, including after save/load. Old saves without
	# the optional arrival clock receive the same deterministic ID fallback.
	var queues: Dictionary={}
	for guest in model.guests:
		if guest.phase!="moving" or int(guest.leg)>=guest.route.legs.size():continue
		var leg: Dictionary=guest.route.legs[int(guest.leg)]
		if leg.kind!="visit" or leg.get("pause_only",false):continue
		var building: Dictionary=model.asset(int(leg.id))
		if not is_public(str(building.get("kind",""))):continue
		if not queues.has(int(leg.id)):queues[int(leg.id)]=[]
		queues[int(leg.id)].append(guest)
	var allowed: Dictionary={}
	for id in queues:
		var capacity: int=int(specification(model.asset(id)).units)
		var slots: int=capacity
		queues[id].sort_custom(func(a,b):
			if (float(a.elapsed)>0)!=(float(b.elapsed)>0):return float(a.elapsed)>0
			var first: float=float(a.get("wc_queue_since",0))
			var second: float=float(b.get("wc_queue_since",0))
			if first!=second:return first<second
			return int(a.id)<int(b.id))
		for guest in queues[id]:
			# Large aggregate families occupy the full facility in batches.
			var needed: int=mini(capacity,maxi(1,int(guest.get("group_size",1))))
			allowed[int(guest.id)]=slots>=needed
			if slots>=needed:slots-=needed
	return allowed

static func is_public(kind: String) -> bool:
	return kind in KINDS

static func _default(model: RefCounted) -> Dictionary:
	return {"version":1,"hygiene":100.0,"fill":0.0,"visits":0,"emptied":0,"cleaned":0,"last_day":int(model.day),"winterized":false}

static func state(model: RefCounted,building: Dictionary) -> Dictionary:
	return building.get("wc_public",_default(model))

static func status(model: RefCounted,building: Dictionary) -> Dictionary:
	if not is_public(str(building.get("kind",""))):return {}
	var s: Dictionary=state(model,building)
	var spec: Dictionary=specification(building)
	var units: int=int(spec.units)
	var reserved: int=model.service_load(int(building.id))
	var present:=0
	for guest in model.guests:
		if guest.phase!="moving" or int(guest.leg)>=guest.route.legs.size():continue
		var leg: Dictionary=guest.route.legs[int(guest.leg)]
		if leg.kind=="visit" and int(leg.id)==int(building.id) and not leg.get("pause_only",false):present+=int(guest.get("group_size",1))
	var capacity: int=model.service_capacity(building)
	var cleaning: int=ceili((15+units*5)*float(spec.service_factor))
	var disposal: int=ceili((20+float(spec.volume)*0.3)*float(spec.service_factor))
	return {"hygiene":float(s.hygiene),"fill":float(s.fill),"capacity":capacity,
		"waiting":maxi(0,present-capacity),"reserved":reserved,"visits":int(s.visits),"units":units,
		"volume":float(spec.volume),"hygiene_use":float(spec.hygiene_use),"service_factor":float(spec.service_factor),
		"clean_cost":cleaning,"empty_cost":disposal,
		"winterized":bool(s.winterized),"winter_cost":100+units*45,
		"ready":bool(building.get("enabled",false)) and float(s.hygiene)>=20.0 and float(s.fill)<96.0}

static func available(model: RefCounted,building: Dictionary) -> bool:
	var info: Dictionary=status(model,building)
	return bool(info.get("ready",false))

static func visit(model: RefCounted,building: Dictionary,count: int=1) -> void:
	if not is_public(str(building.get("kind",""))) or count<1:return
	var s: Dictionary=state(model,building).duplicate(true)
	var spec: Dictionary=specification(building)
	var volume: float=float(spec.volume)
	s.fill=clampf(float(s.fill)+100.0*float(count)/volume,0.0,100.0)
	s.hygiene=clampf(float(s.hygiene)-float(spec.hygiene_use)*float(count),0.0,100.0)
	s.visits=int(s.visits)+count
	building.wc_public=s
	model._operational_change()

static func daily(model: RefCounted,building: Dictionary) -> void:
	if not is_public(str(building.get("kind",""))) or not building.has("wc_public"):return
	var s: Dictionary=building.wc_public
	var delta: int=maxi(0,int(model.day)-int(s.last_day))
	if delta==0:return
	var freezing:float=5.0 if not s.winterized and float(model.weather().temperature)<-8.0 else 0.0
	s.hygiene=clampf(float(s.hygiene)-float(mini(delta,10))*((0.75 if s.winterized else 2.0)+freezing)*float(specification(building).aging_factor),0.0,100.0)
	s.last_day=int(model.day)
	building.wc_public=s
	# Optional WC-service staff perform actual paid maintenance overnight.
	# Without a worker, players may still clean or empty the unit manually.
	var assigned:int=0
	for person in model.operations.staff:
		if str(person.get("assignment",""))=="building:%d" % int(building.id) and str(person.get("role",""))=="sanitation":assigned+=1
	if assigned>0:
		if float(s.fill)>=60.0:action(model,int(building.id),"empty")
		if float(s.hygiene)<=75.0:action(model,int(building.id),"clean")

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
			if model.campaign.get("mode","career")!="free" and not model.Progression.has(model,"wc_winter"):
				return model._result(false,L.text("Forschung Frostsichere Entsorgung ist erforderlich."))
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
