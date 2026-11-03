extends RefCounted
const L = preload("res://src/core/i18n.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const KINDS := ["ramp","rail","roller"]
const NAMES := ["Kleine Sprungrampe","Breite Anfänger-Rail","Sanfte Schneewelle"]
const COSTS := [850,1200,600]
const MAX_FEATURES := 24

static func valid(piste: Dictionary) -> bool:
	var features: Variant=piste.get("features",[])
	if not features is Array or features.size()>MAX_FEATURES: return false
	for index in range(features.size()):
		var feature: Variant=features[index]
		if not feature is Dictionary or feature.get("kind","") not in KINDS: return false
		if not Terrain.number(feature.get("fraction")) or not Terrain.number(feature.get("lateral")): return false
		if not placement(piste,str(feature.kind),float(feature.fraction),float(feature.lateral),index).is_empty(): return false
	return true

static func placement(piste: Dictionary, kind: String, fraction: float, lateral: float, ignore: int = -1) -> String:
	if kind not in KINDS or not is_finite(fraction) or not is_finite(lateral): return L.text("Ungültiges Pistenmodul.")
	var length_value: float=piste.get("length",0)
	if length_value<50 or fraction*length_value<18 or (1-fraction)*length_value<18: return L.text("Mindestens 18 m Abstand zu Anfang und Ende einhalten.")
	if absf(lateral)>Snow.piste_width(piste)*0.5-3.5: return L.text("Das Modul braucht Platz innerhalb der Piste und eine freie Durchfahrt daneben.")
	var features: Array=piste.get("features",[])
	for index in range(features.size()):
		if index==ignore: continue
		var other: Variant=features[index]
		if not other is Dictionary or not Terrain.number(other.get("fraction")) or not Terrain.number(other.get("lateral")): return L.text("Ungültiges Pistenmodul.")
		if absf(float(other.fraction)-fraction)*length_value<16 and absf(float(other.lateral)-lateral)<6: return L.text("Module brauchen mindestens 16 m Abstand in Fahrtrichtung.")
	return ""

static func check(model: RefCounted, id: int, kind: String, fraction: float, lateral: float, index: int = -1) -> Dictionary:
	var piste: Dictionary=model.asset(id)
	if not piste.has("points") or not piste.has("difficulty"): return model._result(false,L.text("Bitte eine Piste auswählen."))
	var features: Array=piste.get("features",[])
	if index < -1 or index>=features.size(): return model._result(false,L.text("Dieses Modul gibt es nicht mehr."))
	if index<0 and features.size()>=MAX_FEATURES: return model._result(false,L.text("Höchstens 24 Module pro Piste."))
	var reason := placement(piste,kind,fraction,lateral,index)
	if reason!="": return model._result(false,reason)
	var point: Vector2=model.terrain.point_on_path(piste.points,fraction)
	var before: Vector2=model.terrain.point_on_path(piste.points,maxf(0,fraction-8.0/piste.length))
	var after: Vector2=model.terrain.point_on_path(piste.points,minf(1,fraction+8.0/piste.length))
	var grade: float=(model.terrain.height(before)-model.terrain.height(after))/maxf(0.1,before.distance_to(after))*100
	if grade<0 or grade>55: return model._result(false,L.text("Für Module einen gleichmäßig abfallenden Abschnitt bis 55 % wählen."))
	for waypoint in range(1,piste.points.size()-1):
		var at: Vector2=Terrain.unpack(piste.points[waypoint])
		if at.distance_to(point)<10:
			var inbound: Vector2=(at-Terrain.unpack(piste.points[waypoint-1])).normalized()
			var outbound: Vector2=(Terrain.unpack(piste.points[waypoint+1])-at).normalized()
			if inbound.dot(outbound)<0.85: return model._result(false,L.text("Module mit Abstand zu engen Kurven platzieren."))
	var cost: int = COSTS[KINDS.find(kind)] if index<0 else 120
	if model.money<cost: return model._result(false,L.text("Das Budget reicht für dieses Modul noch nicht."),{"cost":cost})
	return model._result(true,L.text("Freie Durchfahrt bleibt erhalten. Geübte Gäste nutzen das Modul auf ihrer Linie."),{"cost":cost})

static func install(model: RefCounted, id: int, kind: String, fraction: float, lateral: float, index: int = -1) -> Dictionary:
	var result := check(model,id,kind,fraction,lateral,index)
	if not result.ok: return result
	if not model._spend(result.cost): return model._result(false,L.text("Das Budget reicht für dieses Modul noch nicht."))
	var piste: Dictionary=model.asset(id)
	if not piste.has("features"): piste.features=[]
	var feature := {"kind":kind,"fraction":fraction,"lateral":lateral}
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
		var side_distance := absf(lateral-float(feature.lateral))
		var half_width := 0.8 if feature.kind=="rail" else 2.4
		if side_distance>half_width: continue
		var along := (fraction-float(feature.fraction))*float(piste.length)
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
		result=maxf(result,height_value*(1.0-smoothstep(half_width*0.65,half_width,side_distance)))
	return result

static func safe_lateral(piste: Dictionary, fraction: float, lateral: float, ability: int) -> float:
	if ability>=1: return lateral
	for feature in piste.get("features",[]):
		var along := absf(fraction-float(feature.fraction))*float(piste.length)
		if along>=16: continue
		var clearance := 2.1 if feature.kind=="rail" else 3.6
		var center: float=feature.lateral
		if absf(lateral-center)>=clearance: continue
		var edge := Snow.piste_width(piste)*0.43
		var left := center-clearance
		var right := center+clearance
		var target := left if absf(lateral-left)<absf(lateral-right) else right
		if target < -edge: target=right
		if target > edge: target=left
		lateral=lerpf(lateral,clampf(target,-edge,edge),1-smoothstep(8,16,along))
	return lateral
