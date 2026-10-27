extends RefCounted
## Prepared plazas and paths are both visible ground and the pedestrian graph.
const Terrain = preload("res://src/core/terrain.gd")
const Fleet = preload("res://src/core/lift_fleet.gd")
const LINK_GAP := 40.0
const WALK_SPEED := 2.8

static func station_radius(lift: Dictionary, top: bool) -> float:
	if Fleet.family(lift) == "carpet":
		return 42
	if Fleet.family(lift) == "drag":
		return 66 if top else 84
	return (70 if top else 88) + maxf(0, Fleet.seats(lift) - 4) * 0.7

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

static func layout(mountain: RefCounted, lifts: Array, buildings: Array, walk_areas: Array = []) -> Dictionary:
	var areas: Array = [_area("base", Terrain.BASE, Terrain.BASE, 92, true)]
	for lift in lifts:
		for top in [false, true]:
			areas.append(_area("f%d%s" % [lift.id, "t" if top else "b"], Terrain.unpack(lift.top if top else lift.bottom), station_hub(lift, top, buildings), station_radius(lift, top), true, lift.id, "station"))
	for building in buildings:
		if building.kind != "snowmaker":
			var entrance := door(building)
			areas.append(_area("f%dg" % building.id, entrance + Vector2(0, 5), entrance + Vector2(0, 5), building_radius(building), false, building.id, "building"))
	for area in walk_areas:
		if area.enabled:
			areas.append(_area("w%d" % area.id, Terrain.unpack(area.point), Terrain.unpack(area.point), area.radius, true, area.id, "plaza"))
	var links: Array = []
	for i in range(areas.size()):
		for j in range(i + 1, areas.size()):
			var a: Dictionary = areas[i]
			var b: Dictionary = areas[j]
			if a.center.distance_to(b.center) > a.radius + b.radius + LINK_GAP:
				continue
			var path := path_between(a.point, b.point, buildings, lifts)
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
	return {"areas": areas, "links": links, "rooted": rooted, "lifts": lifts, "buildings": buildings}

static func attachments(layout_value: Dictionary, point: Vector2, rooted_only: bool = false, extra: float = 2) -> Array:
	var result: Array = []
	for area in layout_value.areas:
		if (not rooted_only or layout_value.rooted.has(area.key)) and area.center.distance_to(point) <= area.radius + extra:
			result.append(area)
	return result

static func contains(layout_value: Dictionary, point: Vector2) -> bool:
	for shape in obstacles(layout_value.get("buildings", []), layout_value.get("lifts", [])):
		if crosses_polygon(point, point, shape):
			return false
	if not attachments(layout_value, point).is_empty():
		return true
	for link in layout_value.links:
		for index in range(1, link.points.size()):
			if Geometry2D.get_closest_point_to_segment(point, Terrain.unpack(link.points[index - 1]), Terrain.unpack(link.points[index])).distance_to(point) <= 4:
				return true
	return false

static func valid_walk(layout_value: Dictionary, points: Array, buildings: Array) -> bool:
	if not clear_walk(points, buildings, layout_value.get("lifts", [])):
		return false
	if points.size() == 2 and Terrain.unpack(points[0]).distance_to(Terrain.unpack(points[1])) <= 2.01:
		return true # Exact piste junctions still have to clear the machinery.
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
		var path := path_between(area.point, entrance, buildings + [proposed], layout_value.get("lifts", []))
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

static var _obstacle_cache: Dictionary = {}
static var _inset_cache: Dictionary = {}

static func boarding_point(lift: Dictionary, top: bool) -> Vector2:
	var direction := (Terrain.unpack(lift.top) - Terrain.unpack(lift.bottom)).normalized()
	return Fleet.station_point(lift, top) + direction * (machine_radius(lift) + 7) * (1 if top else -1)

static func obstacles(buildings: Array, lifts: Array) -> Array:
	var fingerprint := [buildings.map(func(building): return [building.kind, building.point]), lifts.map(func(lift): return [lift.kind, lift.bottom, lift.top])].hash()
	if _obstacle_cache.has(fingerprint):
		return _obstacle_cache[fingerprint]
	var result: Array = []
	for building in buildings:
		if building.kind not in ["snowmaker", "viewpoint", "snowpark", "bus"]:
			var rect := Rect2(Terrain.unpack(building.point) - building_size(building) * 0.5, building_size(building)).grow(2.8)
			result.append(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]))
	for lift in lifts:
		for station in [lift.bottom, lift.top]:
			var center := Terrain.unpack(station)
			var r := machine_radius(lift) + 4.2
			# An octagon offers a close, visible detour around each machine.
			var polygon := PackedVector2Array()
			for i in range(8):
				polygon.append(center + Vector2.from_angle(i * TAU / 8) * r / cos(PI / 8))
			result.append(polygon)
		if Fleet.family(lift) in ["drag", "carpet"]:
			var a := Terrain.unpack(lift.bottom)
			var b := Terrain.unpack(lift.top)
			var side := (b - a).normalized().orthogonal() * (Fleet.rope_offset(lift) + 2.8 if Fleet.family(lift) == "drag" else 5.5)
			result.append(PackedVector2Array([a + side, b + side, b - side, a - side]))
	# Merge overlapping terminal and tow-track footprints before finding detours.
	var changed := true
	while changed:
		changed = false
		for i in range(result.size()):
			for j in range(i + 1, result.size()):
				var merged := Geometry2D.merge_polygons(result[i], result[j])
				if merged.size() == 1:
					result[i] = merged[0]
					result.remove_at(j)
					changed = true
					break
			if changed:
				break
	if _obstacle_cache.size() > 64:
		_obstacle_cache.clear()
	_obstacle_cache[fingerprint] = result
	return result

static func crosses_polygon(a: Vector2, b: Vector2, polygon: PackedVector2Array) -> bool:
	# A tiny inward offset allows visibility edges to follow obstacle boundaries.
	var key := hash(polygon)
	if not _inset_cache.has(key):
		if _inset_cache.size() > 512:
			_inset_cache.clear()
		_inset_cache[key] = Geometry2D.offset_polygon(polygon, -0.08)
	var inset: Array = _inset_cache[key]
	for shape in inset:
		if Geometry2D.is_point_in_polygon(a, shape) or Geometry2D.is_point_in_polygon(b, shape):
			return true
		for i in range(shape.size()):
			if Geometry2D.segment_intersects_segment(a, b, shape[i], shape[(i + 1) % shape.size()]) != null:
				return true
	return false

static func clear_walk(points: Array, buildings: Array, lifts: Array) -> bool:
	for shape in obstacles(buildings, lifts):
		for i in range(1, points.size()):
			if crosses_polygon(Terrain.unpack(points[i - 1]), Terrain.unpack(points[i]), shape):
				return false
	return true

static func path_between(from: Vector2, to: Vector2, buildings: Array, lifts: Array = []) -> Array:
	var shapes := obstacles(buildings, lifts)
	var blocked := false
	for shape in shapes:
		if Geometry2D.is_point_in_polygon(from, shape) or Geometry2D.is_point_in_polygon(to, shape):
			return []
		blocked = blocked or crosses_polygon(from, to, shape)
	if not blocked:
		return [Terrain.pack(from), Terrain.pack(to)]
	# Visibility graph around the actual merged obstacles, with no foot shortcuts
	# across a tow track. Only nearby obstacles need vertices in this local search.
	var bounds := Rect2(from, Vector2.ZERO).expand(to).grow(110)
	var vertices: Array[Vector2] = [from, to]
	for shape in shapes:
		var nearby := false
		for at in shape:
			nearby = nearby or bounds.has_point(at)
		if nearby or crosses_polygon(from, to, shape):
			for at in shape:
				vertices.append(at)
	var distance: Array[float] = []; distance.resize(vertices.size()); distance.fill(INF); distance[0] = 0
	var previous: Array[int] = []; previous.resize(vertices.size()); previous.fill(-1)
	var visited: Dictionary = {}
	for iteration in range(vertices.size()):
		var current := -1
		var best := INF
		for i in range(vertices.size()):
			if not visited.has(i) and distance[i] < best:
				current = i; best = distance[i]
		if current < 0:
			return []
		if current == 1:
			var path: Array = []
			while current >= 0:
				path.push_front(Terrain.pack(vertices[current])); current = previous[current]
			return path
		visited[current] = true
		for target in range(vertices.size()):
			if visited.has(target):
				continue
			var length := vertices[current].distance_to(vertices[target])
			if distance[current] + length >= distance[target]:
				continue
			var clear := true
			for shape in shapes:
				if crosses_polygon(vertices[current], vertices[target], shape):
					clear = false; break
			if clear:
				distance[target] = distance[current] + length; previous[target] = current
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
			var radius := machine_radius(lift) + 6.5
			for start in [true, false]:
				var index := 0 if start else result.size() - 1
				if Terrain.unpack(result[index]).distance_to(center) >= radius:
					continue
				while result.size() > 2:
					var next := 1 if start else result.size() - 2
					if Terrain.unpack(result[next]).distance_to(center) > radius + 4:
						break
					result.remove_at(next)
				index = 0 if start else result.size() - 1
				var neighbor := Terrain.unpack(result[1 if start else result.size() - 2])
				var direction := (neighbor - center).normalized()
				if direction.length() > 0.5:
					var at := center + direction * radius
					if Fleet.family(lift) in ["drag", "carpet"]:
						var right := Vector2(Fleet.basis(lift).x.x, Fleet.basis(lift).x.z)
						var lateral := (at - center).dot(right)
						var clearance := Fleet.rope_offset(lift) + 16
						if absf(lateral) < clearance:
							at += right * ((1 if lateral >= 0 else -1) * clearance - lateral)
					result[index] = Terrain.pack(at)
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
