extends RefCounted
const L = preload("res://src/core/i18n.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const Modules=preload("res://src/core/park_modules_042.gd")
const KINDS := Modules.KINDS
const NAMES := Modules.NAMES
const COSTS := Modules.COSTS
const MAX_FEATURES := 24

static func valid(piste: Dictionary) -> bool:
	var features: Variant=piste.get("features",[])
	if not features is Array or features.size()>MAX_FEATURES: return false
	for index in range(features.size()):
		var feature: Variant=features[index]
		if not feature is Dictionary or feature.get("kind","") not in KINDS: return false
		if not Terrain.number(feature.get("fraction")) or not Terrain.number(feature.get("lateral")): return false
		if not Modules.valid_options(feature):return false
		if feature.has("condition") and (not Terrain.number(feature.condition) or feature.condition<0 or feature.condition>100):return false
		if feature.has("uses") and (not Terrain.number(feature.uses) or feature.uses<0 or feature.uses>1000000000 or feature.uses!=floorf(feature.uses)):return false
		if not placement(piste,str(feature.kind),float(feature.fraction),float(feature.lateral),index,feature).is_empty(): return false
	return true

static func placement(piste: Dictionary, kind: String, fraction: float, lateral: float, ignore: int = -1, options:Dictionary={}) -> String:
	if kind not in KINDS or not is_finite(fraction) or not is_finite(lateral): return L.text("Ungültiges Pistenmodul.")
	if not Modules.valid_options(options):return L.text("Drehung von −45 bis +45 Grad und Größe von 70 bis 140 % wählen.")
	var length_value: float=piste.get("length",0)
	var bounds:=Modules.footprint(kind,options)
	var legacy:bool=Modules.legacy(kind) and is_zero_approx(float(options.get("rotation",0))) and is_equal_approx(float(options.get("scale",1)),1.0)
	var end_margin:float=18.0 if legacy else maxf(18.0,bounds.y*0.5+12.0)
	if length_value<50 or fraction*length_value<end_margin or (1-fraction)*length_value<end_margin: return L.text("Anfahrt und Landebereich müssen frei bleiben.") if not legacy else L.text("Mindestens 18 m Abstand zu Anfang und Ende einhalten.")
	var half:float=Snow.piste_width(piste)*0.5
	if (legacy and absf(lateral)>half-3.5) or (not legacy and (absf(lateral)+bounds.x*0.5>half-1.0 or half+absf(lateral)-bounds.x*0.5<3.5)):return L.text("Das Modul braucht Platz innerhalb der Piste und eine freie Durchfahrt daneben.")
	var features: Array=piste.get("features",[])
	for index in range(features.size()):
		if index==ignore: continue
		var other: Variant=features[index]
		if not other is Dictionary or not Terrain.number(other.get("fraction")) or not Terrain.number(other.get("lateral")): return L.text("Ungültiges Pistenmodul.")
		var other_bounds:=Modules.footprint(str(other.get("kind","")),other)
		var old_pair:bool=legacy and Modules.legacy(str(other.get("kind",""))) and is_zero_approx(float(other.get("rotation",0))) and is_equal_approx(float(other.get("scale",1)),1.0)
		var along_margin:float=16.0 if old_pair else maxf(16.0,(bounds.y+other_bounds.y)*0.5+8.0)
		var side_margin:float=6.0 if old_pair else (bounds.x+other_bounds.x)*0.5+2.0
		if absf(float(other.fraction)-fraction)*length_value<along_margin and absf(float(other.lateral)-lateral)<side_margin:return L.text("Module brauchen freie Anfahrten und getrennte Landebereiche.")
	return ""

static func check(model: RefCounted, id: int, kind: String, fraction: float, lateral: float, index: int = -1, options:Dictionary={}) -> Dictionary:
	var piste: Dictionary=model.asset(id)
	if not piste.has("points") or not piste.has("difficulty"): return model._result(false,L.text("Bitte eine Piste auswählen."))
	var features: Array=piste.get("features",[])
	if index < -1 or index>=features.size(): return model._result(false,L.text("Dieses Modul gibt es nicht mehr."))
	if index<0 and features.size()>=MAX_FEATURES: return model._result(false,L.text("Höchstens 24 Module pro Piste."))
	var reason := placement(piste,kind,fraction,lateral,index,options)
	if reason!="": return model._result(false,reason)
	var point: Vector2=model.terrain.point_on_path(piste.points,fraction)
	var before: Vector2=model.terrain.point_on_path(piste.points,maxf(0,fraction-8.0/piste.length))
	var after: Vector2=model.terrain.point_on_path(piste.points,minf(1,fraction+8.0/piste.length))
	var grade: float=(model.terrain.height(before)-model.terrain.height(after))/maxf(0.1,before.distance_to(after))*100
	if grade<0 or grade>55: return model._result(false,L.text("Für Module einen gleichmäßig abfallenden Abschnitt bis 55 % wählen."))
	for waypoint in range(1,piste.points.size()-1):
		var at: Vector2=Terrain.unpack(piste.points[waypoint])
		var turn_margin:float=10.0 if Modules.legacy(kind) else Modules.footprint(kind,options).y*0.5+8.0
		if at.distance_to(point)<turn_margin:
			var inbound: Vector2=(at-Terrain.unpack(piste.points[waypoint-1])).normalized()
			var outbound: Vector2=(Terrain.unpack(piste.points[waypoint+1])-at).normalized()
			if inbound.dot(outbound)<0.85: return model._result(false,L.text("Module mit Abstand zu engen Kurven platzieren."))
	# Switching an existing small module to an expensive one must not buy
	# the entire larger object for the relocation fee.
	var cost:int=roundi(COSTS[KINDS.find(kind)]*pow(float(options.get("scale",1)),2))
	if index>=0:
		var old:Dictionary=features[index]
		var previous_cost:int=roundi(COSTS[KINDS.find(str(old.kind))]*pow(float(old.get("scale",1)),2))
		cost=120+maxi(0,cost-previous_cost)
	if not model.can_afford(cost): return model._result(false,L.text("Das Budget reicht für dieses Modul noch nicht."),{"cost":cost})
	return model._result(true,L.text("Freie Durchfahrt bleibt erhalten. Geübte Gäste nutzen das Modul auf ihrer Linie."),{"cost":cost})

static func install(model: RefCounted, id: int, kind: String, fraction: float, lateral: float, index: int = -1, options:Dictionary={}) -> Dictionary:
	var result := check(model,id,kind,fraction,lateral,index,options)
	if not result.ok: return result
	if not model._spend(result.cost): return model._result(false,L.text("Das Budget reicht für dieses Modul noch nicht."))
	var piste: Dictionary=model.asset(id)
	if not piste.has("features"): piste.features=[]
	var feature := {"kind":kind,"fraction":fraction,"lateral":lateral}
	if not options.is_empty() or not Modules.legacy(kind):
		feature.rotation=float(options.get("rotation",0));feature.scale=float(options.get("scale",1))
	if index>=0:
		for field in ["uses","condition"]:
			if piste.features[index].has(field):feature[field]=piste.features[index][field]
	if index<0: piste.features.append(feature)
	else: piste.features[index]=feature
	piste.upgrade_total=float(piste.get("upgrade_total",0))+result.cost
	model.revision+=1
	return model._result(true,L.text("Pistenmodul eingebaut."))

static func remove(model: RefCounted, id: int, index: int) -> Dictionary:
	var piste: Dictionary=model.asset(id)
	var features: Array=piste.get("features",[])
	if index<0 or index>=features.size(): return model._result(false,L.text("Dieses Modul gibt es nicht mehr."))
	features.remove_at(index)
	model.revision+=1
	return model._result(true,L.text("Pistenmodul entfernt."))

static func height_offset(piste: Dictionary, fraction: float, lateral: float, ability: int) -> float:
	if ability<1: return 0.0
	var result := 0.0
	for feature in piste.get("features",[]):
		var spec:Dictionary=Modules.spec(str(feature.kind))
		if ability<int(spec.skill) or float(feature.get("condition",100))<25:continue
		var local:=Modules.local_point((fraction-float(feature.fraction))*float(piste.length),lateral-float(feature.lateral),feature)
		var scale_value:float=feature.get("scale",1.0)
		if not Modules.legacy(str(feature.kind)):
			result=maxf(result,Modules.ride_height(str(feature.kind),local.y,local.x)*scale_value)
			continue
		var side_distance := absf(local.x)
		var half_width := 0.8 if feature.kind=="rail" else 2.4
		if side_distance>half_width: continue
		var along := local.y
		var height_value := 0.0
		if feature.kind=="rail":
			height_value=smoothstep(-4.2,-3.0,along)*(1-smoothstep(3.0,4.2,along))*1.1
		elif feature.kind=="roller":
			height_value=sin(clampf((along+6)/12,0,1)*PI)*0.85
		else:
			var t := clampf((along+5)/10,0,1)
			if along<=2:
				height_value=smoothstep(0,0.70,t)*1.35
			elif along<10:
				var flight := (along-2)/8
				height_value=(1-flight)*1.35+sin(flight*PI)*1.25
		result=maxf(result,height_value*scale_value*(1.0-smoothstep(half_width*0.65,half_width,side_distance)))
	return result

static func safe_lateral(piste: Dictionary, fraction: float, lateral: float, ability: int, reference_lane: float = 0.0) -> float:
	for feature in piste.get("features",[]):
		var spec:Dictionary=Modules.spec(str(feature.kind))
		if ability>=int(spec.skill) and float(feature.get("condition",100))>=25:continue
		var along := absf(fraction-float(feature.fraction))*float(piste.length)
		var footprint:=Modules.footprint(str(feature.kind),feature)
		var approach:float=maxf(24.0,footprint.y*0.5+14.0)
		if along>=approach:continue
		var clearance:float=(2.1 if feature.kind=="rail" else 3.6) if Modules.legacy(str(feature.kind)) else footprint.x*0.5+1.5
		var center: float=feature.lateral
		var edge := Snow.piste_width(piste)*0.43
		var left := center-clearance
		var right := center+clearance
		var use_left := reference_lane<=center
		if left < -edge:use_left=false
		if right > edge:use_left=true
		var target := minf(lateral,left) if use_left else maxf(lateral,right)
		lateral=lerpf(lateral,clampf(target,-edge,edge),1-smoothstep(maxf(8.0,footprint.y*0.5),approach,along))
	return lateral

static func upkeep(piste:Dictionary)->float:
	var amount:=0.0
	for feature in piste.get("features",[]):amount+=float(Modules.spec(str(feature.kind)).upkeep)*float(feature.get("scale",1))
	return amount

static func appeal(piste:Dictionary,ability:int)->float:
	var total:=0.0
	var kinds:Dictionary={}
	for feature in piste.get("features",[]):
		var spec:Dictionary=Modules.spec(str(feature.kind))
		if ability<int(spec.skill) or float(feature.get("condition",100))<25 or kinds.has(feature.kind):continue
		kinds[feature.kind]=true
		total+=float(spec.appeal)*float(feature.get("condition",100))/100.0
	return minf(60.0,total)

static func maintenance_cost(feature:Dictionary)->int:
	return ceili(20.0+(100.0-float(feature.get("condition",100)))*0.8+float(COSTS[KINDS.find(str(feature.kind))])*0.04)

static func maintain(model:RefCounted,id:int,index:int)->Dictionary:
	var piste:Dictionary=model.asset(id)
	var features:Array=piste.get("features",[])
	if index<0 or index>=features.size():return model._result(false,L.text("Dieses Modul gibt es nicht mehr."))
	var feature:Dictionary=features[index]
	var cost:=maintenance_cost(feature)
	if not model.can_afford(cost):return model._result(false,L.text("Das Budget reicht für dieses Modul noch nicht."))
	if model.campaign.get("mode","career")!="free" and not model.Ops._expense(model,cost,"snowpark:%d" % id):return model._result(false,L.text("Das Budget reicht für dieses Modul noch nicht."))
	feature.condition=100.0
	model.revision+=1
	return model._result(true,L.text("Snowpark-Modul gewartet."))

static func traverse(model:RefCounted,piste:Dictionary,guest:Dictionary,start:float,finish:float)->void:
	if guest.get("incident",-1)>=0:return
	for feature in piste.get("features",[]):
		if Modules.legacy(str(feature.kind)) or float(feature.fraction)<=start or float(feature.fraction)>finish:continue
		var spec:Dictionary=Modules.spec(str(feature.kind))
		if int(guest.ability)<int(spec.skill) or float(feature.get("condition",100))<25:continue
		var at:float=feature.fraction
		var center:Vector2=model.terrain.point_on_path(piste.points,at)
		var direction:Vector2=(model.terrain.point_on_path(piste.points,minf(1,at+0.005))-center).normalized()
		var point:Vector2=model.Motion.position(model.terrain,piste,int(guest.id),int(guest.ability),at,int(guest.loops),0,1,[],str(guest.get("sport","ski")),float(guest.get("traffic_lateral",INF)))
		var side:float=(point-center).dot(direction.orthogonal())-float(feature.lateral)
		var local:=Modules.local_point(0.0,side,feature)
		if absf(local.x)>float(spec.width)*0.5 or absf(local.y)>float(spec.length)*0.5:continue
		feature.uses=int(feature.get("uses",0))+int(guest.get("group_size",1))
		feature.condition=maxf(0.0,float(feature.get("condition",100))-(0.08+float(spec.risk)*0.04)*int(guest.get("group_size",1)))
		guest.needs.joy=minf(100.0,float(guest.needs.joy)+2.0)
		if guest.has("agenda"):guest.agenda.park_visits=int(guest.agenda.park_visits)+1
		if guest.has("family"):
			for member in guest.family:member.needs.joy=minf(100.0,float(member.needs.joy)+2.0)
			model.Needs.aggregate_family(guest)
		if float(feature.condition)<45.0 and model.Ops.active(model) and model.rng.randf()<0.001*float(spec.risk)*(45.0-float(feature.condition))/20.0:
			model.Ops.incident(model,guest,"collision")
