extends RefCounted
## A playable alpine-village starter: not an entire real municipality.
## These are deliberately fictional, player-managed game buildings.
const Catalog = preload("res://src/core/catalog.gd")
const Terrain = preload("res://src/core/terrain.gd")
const KINDS := ["hotel", "school", "kiosk", "disco"]
const MAX_STARTER_BUILDINGS := 12

static func _near_existing(model: RefCounted, point: Vector2, margin: float) -> bool:
	for building in model.buildings:
		if Terrain.unpack(building.point).distance_to(point) < margin: return true
	return false

static func _lot(model: RefCounted, kind: String) -> Vector2:
	var stations: Array = []
	var corridors: Array = []
	for lift in model.lifts:
		for value in [lift.bottom, lift.top]:
			var at := Terrain.unpack(value)
			if at.distance_to(Terrain.BASE) < 470: stations.append(at)
	for piste in model.pistes:
		for index in range(1, piste.points.size()):
			var a := Terrain.unpack(piste.points[index - 1])
			var b := Terrain.unpack(piste.points[index])
			if minf(a.distance_to(Terrain.BASE), b.distance_to(Terrain.BASE)) < 470:
				corridors.append([a,b])
	var kind_index: int = KINDS.find(kind)
	for ring in range(2, 14):
		var radius: float = 38 + ring * 24.0
		for turn in range(24):
			var radians: float = TAU * float((turn + kind_index * 5) % 24) / 24.0
			var point: Vector2 = Terrain.BASE + Vector2(cos(radians), sin(radians)) * radius
			if not model.terrain.contains(point) or model.terrain.slope_percent(point) > 39: continue
			if _near_existing(model, point, 52.0 if kind=="hotel" else 41.0): continue
			if stations.any(func(station): return point.distance_to(station) < 65.0): continue
			if corridors.any(func(segment): return Geometry2D.get_closest_point_to_segment(point, segment[0], segment[1]).distance_to(point) < 31.0): continue
			return point
	return Vector2.INF

static func add(model: RefCounted) -> int:
	var added := 0
	for kind in KINDS:
		if model.buildings.size() >= MAX_STARTER_BUILDINGS: break
		var existing: Array = model.buildings.filter(func(b): return b.kind == kind)
		if kind == "hotel":
			if existing.size() >= 2: continue
		elif not existing.is_empty():
			continue
		var point := _lot(model, kind)
		if not point.is_finite(): continue
		var spec: Dictionary = Catalog.BUILDINGS[kind]
		model.buildings.append({
			"id": model.next_id, "kind": kind, "point": Terrain.pack(point),
			"cost": spec.cost, "enabled": true, "level": 1,
			"upgrade_total": 0.0, "rotation": 0,
			"name": spec.name, "visits": 0, "revenue": 0.0,
			"scenario_seeded": true
		})
		model.next_id += 1
		added += 1
	return added
