extends RefCounted
## Prepared plazas and paths are both visible ground and the pedestrian graph.
const Terrain = preload("res://src/core/terrain.gd")
const Fleet = preload("res://src/core/lift_fleet.gd")
const LINK_GAP := 40.0
const WALK_SPEED := 2.8

static func station_radius(lift: Dictionary, top: bool) -> float:
	if Fleet.family(lift) == "carpet":
		return 20
	if Fleet.family(lift) == "drag":
		return 28 if top else 40
	return (34 if top else 44) + maxf(0, Fleet.seats(lift) - 4) * 0.7

static func machine_radius(lift: Dictionary) -> float:
	return 8.0 if Fleet.family(lift) in ["drag", "carpet"] else Fleet.rope_offset(lift) + 6

static func station_hub(lift: Dictionary, top: bool, buildings: Array = []) -> Vector2:
	var center := Terrain.unpack(lift.top if top else lift.bottom)
	var radius := station_radius(lift, top)
	for local in [Vector3(0.45, 0, -0.55), Vector3(-0.45, 0, -0.55), Vector3(0.7, 0, 0), Vector3(-0.7, 0, 0), Vector3(0, 0, 0.7)]:
		var offset: Vector3 = Fleet.basis(lift) * (local * radius)
		var point := center + Vector2(offset.x, offset.z)
		if free_of_buildings(point, buildings, 3):
			return point
	return center + Vector2(0, radius * 0.7)

static func free_of_buildings(point: Vector2, buildings: Array, margin: float = 2) -> bool:
	for building in buildings:
		if building.kind not in ["snowmaker", "viewpoint", "snowpark", "bus"]:
			var size := building_size(building)
			if Rect2(Terrain.unpack(building.point) - size * 0.5, size).grow(margin).has_point(point):
				return false
	return true

static func building_size(building: Dictionary) -> Vector2:
	return Vector2(35, 28) if building.kind == "hotel" else (Vector2(29, 24) if building.kind == "maintenance" else Vector2(22, 18))

static func door(building: Dictionary) -> Vector2:
	return Terrain.unpack(building.point) + Vector2(0, building_size(building).y * 0.5 + 3)

static func building_radius(building: Dictionary) -> float:
	return 16.0 if building.kind == "kiosk" else (30.0 if building.kind in ["hotel", "spa"] else 26.0)

static func _area(key: String, center: Vector2, point: Vector2, radius: float, root: bool, id: int = 0, kind: String = "base") -> Dictionary:
	return {"key": key, "center": center, "point": point, "radius": radius, "root": root, "id": id, "kind": kind}

static func layout(mountain: RefCounted, lifts: Array, buildings: Array) -> Dictionary:
	var areas: Array = [_area("base", Terrain.BASE, Terrain.BASE, 65, true)]
	for lift in lifts:
		for top in [false, true]:
			areas.append(_area("f%d%s" % [lift.id, "t" if top else "b"], Terrain.unpack(lift.top if top else lift.bottom), station_hub(lift, top, buildings), station_radius(lift, top), true, lift.id, "station"))
	for building in buildings:
		if building.kind != "snowmaker":
			var entrance := door(building)
			areas.append(_area("f%dg" % building.id, entrance + Vector2(0, 5), entrance + Vector2(0, 5), building_radius(building), false, building.id, "building"))
	var links: Array = []
	for i in range(areas.size()):
		for j in range(i + 1, areas.size()):
			var a: Dictionary = areas[i]
			var b: Dictionary = areas[j]
			if a.center.distance_to(b.center) > a.radius + b.radius + LINK_GAP:
				continue
			var path := path_between(a.point, b.point, buildings)
			if not path.is_empty() and gentle(mountain, path):
				links.append({"from": a.key, "to": b.key, "points": path})
	var rooted: Array = []
	for area in areas:
		if area.root:
			rooted.append(area.key)
	var changed := true
	while changed:
		changed = false
		for link in links:
			for pair in [[link.from, link.to], [link.to, link.from]]:
				if rooted.has(pair[0]) and not rooted.has(pair[1]):
					rooted.append(pair[1])
					changed = true
	return {"areas": areas, "links": links, "rooted": rooted}

static func attachments(layout_value: Dictionary, point: Vector2, rooted_only: bool = false, extra: float = 2) -> Array:
	var result: Array = []
	for area in layout_value.areas:
		if (not rooted_only or layout_value.rooted.has(area.key)) and area.center.distance_to(point) <= area.radius + extra:
			result.append(area)
	return result

static func contains(layout_value: Dictionary, point: Vector2) -> bool:
	if not attachments(layout_value, point).is_empty():
		return true
	for link in layout_value.links:
		for index in range(1, link.points.size()):
			if Geometry2D.get_closest_point_to_segment(point, Terrain.unpack(link.points[index - 1]), Terrain.unpack(link.points[index])).distance_to(point) <= 4:
				return true
	return false

static func valid_walk(layout_value: Dictionary, points: Array, buildings: Array) -> bool:
	if points.size() == 2 and Terrain.unpack(points[0]).distance_to(Terrain.unpack(points[1])) <= 2.01:
		return true # An exact piste junction can lie outside a prepared plaza.
	for index in range(1, points.size()):
		var a := Terrain.unpack(points[index - 1])
		var b := Terrain.unpack(points[index])
		for building in buildings:
			if building.kind not in ["snowmaker", "viewpoint", "snowpark", "bus"]:
				var size := building_size(building)
				if _crosses(a, b, Rect2(Terrain.unpack(building.point) - size * 0.5, size).grow(1.8)):
					return false
		var steps := maxi(1, ceili(a.distance_to(b) / 6))
		for step in range(steps + 1):
			if not contains(layout_value, a.lerp(b, float(step) / steps)):
				return false
	return true

static func connection(mountain: RefCounted, layout_value: Dictionary, buildings: Array, kind: String, point: Vector2) -> Dictionary:
	var proposed := {"kind": kind, "point": Terrain.pack(point)}
	var entrance := door(proposed) + Vector2(0, 5)
	var nearest: Dictionary = {}
	var distance := INF
	for area in layout_value.areas:
		if not layout_value.rooted.has(area.key):
			continue
		var length: float = entrance.distance_to(area.point)
		if area.center.distance_to(entrance) > area.radius + building_radius(proposed) + LINK_GAP:
			continue
		var path := path_between(area.point, entrance, buildings + [proposed])
		if length < distance and not path.is_empty() and gentle(mountain, path):
			distance = length
			nearest = {"area": area.key, "points": path, "length": length}
	return nearest

static func gentle(mountain: RefCounted, points: Array) -> bool:
	for index in range(1, points.size()):
		var a := Terrain.unpack(points[index - 1])
		var b := Terrain.unpack(points[index])
		var steps := maxi(1, ceili(a.distance_to(b) / 8))
		for step in range(steps):
			var p := a.lerp(b, float(step) / steps)
			var q := a.lerp(b, float(step + 1) / steps)
			if absf(mountain.height(p) - mountain.height(q)) / maxf(p.distance_to(q), 0.1) > 0.55:
				return false
	return true

static func _crosses(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	# Detour corners lie just outside the tested footprint, avoiding edge loops.
	var inside := rect.grow(-0.15)
	if inside.has_point(a) or inside.has_point(b):
		return true
	var corners := [inside.position, Vector2(inside.end.x, inside.position.y), inside.end, Vector2(inside.position.x, inside.end.y)]
	for index in range(4):
		if Geometry2D.segment_intersects_segment(a, b, corners[index], corners[(index + 1) % 4]) != null:
			return true
	return false

static func path_between(from: Vector2, to: Vector2, buildings: Array) -> Array:
	var obstacles: Array[Rect2] = []
	for building in buildings:
		if building.kind not in ["snowmaker", "viewpoint", "snowpark", "bus"]:
			var size := building_size(building)
			obstacles.append(Rect2(Terrain.unpack(building.point) - size * 0.5, size).grow(2))
	var path: Array = [from, to]
	for iteration in range(16):
		var changed := false
		for index in range(1, path.size()):
			var a: Vector2 = path[index - 1]
			var b: Vector2 = path[index]
			for rect in obstacles:
				if not _crosses(a, b, rect):
					continue
				var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
				var best: Array = []
				var distance := INF
				for c in range(4):
					for d in range(4):
						if c != d and (c - d + 4) % 4 == 2:
							continue
						var p: Vector2 = corners[c]
						var q: Vector2 = corners[d]
						if _crosses(a, p, rect) or _crosses(p, q, rect) or _crosses(q, b, rect):
							continue
						var length := a.distance_to(p) + p.distance_to(q) + q.distance_to(b)
						if length < distance:
							distance = length
							best = [p] if c == d else [p, q]
				if best.is_empty():
					return []
				path = path.slice(0, index) + best + path.slice(index)
				changed = true
				break
			if changed:
				break
		if not changed:
			var packed: Array = []
			for point in path:
				packed.append(Terrain.pack(point))
			return packed
	return []

static func prepare_piste(points: Array, lifts: Array) -> Array:
	var result := points.duplicate(true)
	if result.size() < 2:
		return result
	for point in result:
		if not Terrain.unpack(point).is_finite():
			return result
	for lift in lifts:
		for station in [lift.bottom, lift.top]:
			var center := Terrain.unpack(station)
			var radius := machine_radius(lift) + 5
			for start in [true, false]:
				var index := 0 if start else result.size() - 1
				if Terrain.unpack(result[index]).distance_to(center) >= radius:
					continue
				while result.size() > 2:
					var next := 1 if start else result.size() - 2
					if Terrain.unpack(result[next]).distance_to(center) > radius + 5:
						break
					result.remove_at(next)
				index = 0 if start else result.size() - 1
				var neighbor := Terrain.unpack(result[1 if start else result.size() - 2])
				var direction := (neighbor - center).normalized()
				if direction.length() > 0.5:
					result[index] = Terrain.pack(center + direction * radius)
	return result

static func clear_piste(points: Array, lifts: Array, half_width: float = 10) -> bool:
	for lift in lifts:
		for station in [lift.bottom, lift.top]:
			var center := Terrain.unpack(station)
			for index in range(1, points.size()):
				var a := Terrain.unpack(points[index - 1])
				var b := Terrain.unpack(points[index])
				var length := a.distance_to(b)
				if length < 0.01:
					continue
				var direction := (b - a) / length
				var along := (center - a).dot(direction)
				var across := (center - a).dot(direction.orthogonal())
				var longitudinal := maxf(maxf(-along, along - length), 0)
				var lateral := maxf(absf(across) - half_width, 0)
				if Vector2(longitudinal, lateral).length() < machine_radius(lift):
					return false
	return true
