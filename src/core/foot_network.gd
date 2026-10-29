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
	var size := base_building_size(building)
	return Vector2(size.y, size.x) if int(building.get("rotation", 0)) % 2 == 1 else size

static func base_building_size(building: Dictionary) -> Vector2:
	if building.kind == "pool": return Vector2(32, 42)
	return Vector2(35, 28) if building.kind == "hotel" else (Vector2(29, 24) if building.kind in ["maintenance", "repair_office"] else Vector2(22, 18))

static func door(building: Dictionary) -> Vector2:
	return Terrain.unpack(building.point) + front(building) * (base_building_size(building).y * 0.5 + 3)

static func front(building: Dictionary) -> Vector2:
	var angle := int(building.get("rotation", 0)) * PI * 0.5
	return Vector2(sin(angle), cos(angle))

static func forecourt(building: Dictionary) -> Vector2:
	return door(building) + front(building) * 5

static func entrance_bounds(building: Dictionary) -> Rect2:
	var center := door(building) + front(building) * 5
	var size := Vector2(12, 8) if int(building.get("rotation", 0)) % 2 == 1 else Vector2(8, 12)
	return Rect2(center - size * 0.5, size)

static func building_radius(building: Dictionary) -> float:
	return 16.0 if building.kind == "kiosk" else (30.0 if building.kind in ["hotel", "spa"] else 26.0)

static func _area(key: String, center: Vector2, point: Vector2, radius: float, root: bool, id: int = 0, kind: String = "base") -> Dictionary:
	return {"key": key, "center": center, "point": point, "radius": radius, "root": root, "id": id, "kind": kind}

static func layout(mountain: RefCounted, lifts: Array, buildings: Array, walk_areas: Array = [], pistes: Array = [], dense: bool = false) -> Dictionary:
	var areas: Array = [_area("base",Terrain.BASE,Terrain.BASE,92,true)]
	var fixed: Array = []
	for lift in lifts:
		for top in [false,true]:
			areas.append(_area("f%d%s" % [lift.id,"t" if top else "b"],Terrain.unpack(lift.top if top else lift.bottom),station_hub(lift,top,buildings),station_radius(lift,top),true,lift.id,"station"))
	for building in buildings:
		if building.kind != "snowmaker": areas.append(_area("f%dg" % building.id,forecourt(building),forecourt(building),building_radius(building),false,building.id,"building"))
	for area in walk_areas:
		if not area.enabled and area.kind != "walkway": continue
		if area.kind == "walkway":
			for i in range(area.points.size()):
				var key := "w%dv%d" % [area.id,i]
				var at := Terrain.unpack(area.points[i])
				areas.append(_area(key,at,at,4,false,area.id,"walkway"))
				if i > 0:
					var a := Terrain.unpack(area.points[i - 1])
					var segments := maxi(1, ceili(a.distance_to(at) / 40))
					var previous := "w%dv%d" % [area.id, i - 1]
					for j in range(1, segments + 1):
						var next := key if j == segments else "w%dm%d_%d" % [area.id, i, j]
						var point := a.lerp(at, float(j) / segments)
						if j < segments: areas.append(_area(next, point, point, 4, false, area.id, "walkway"))
						var previous_point := a.lerp(at, float(j - 1) / segments)
						fixed.append({"from": previous, "to": next, "points": [Terrain.pack(previous_point), Terrain.pack(point)], "width": 8.0, "manual": true, "closed": not area.enabled})
						previous = next
		else: areas.append(_area("w%d" % area.id,Terrain.unpack(area.point),Terrain.unpack(area.point),area.radius,dense,area.id,"plaza"))
	for piste in pistes:
		for top in [true,false]:
			var at := Terrain.unpack(piste.points[0] if top else piste.points[-1])
			areas.append(_area("g%d%s" % [piste.id,"s" if top else "e"],at,at,4,false,piste.id,"piste_gate"))
	var nodes: Dictionary = {}
	for area in areas: nodes[area.key] = Terrain.pack(area.point)
	var shapes := obstacles(buildings,lifts)
	for lift in lifts:
		for top in [false,true]:
			var key := "l%d%s" % [lift.id,"t" if top else "b"]
			var hub := "f%d%s" % [lift.id,"t" if top else "b"]
			nodes[key] = Terrain.pack(boarding_point(lift,top))
			var path := path_between(Terrain.unpack(nodes[hub]),Terrain.unpack(nodes[key]),buildings,lifts,shapes)
			if not path.is_empty(): fixed.append({"from":hub,"to":key,"points":path,"width":7.0,"access":true})
	for building in buildings:
		if building.kind == "snowmaker": continue
		var key := "d%d" % building.id
		var hub := "f%dg" % building.id
		nodes[key] = Terrain.pack(door(building))
		fixed.append({"from":hub,"to":key,"points":[nodes[hub],nodes[key]],"width":6.0,"access":true})
	# Every piste gate keeps its own direct approach to the nearest real landing
	# or forecourt. A spanning-tree shortcut must never replace this access.
	for gate in areas:
		if gate.kind != "piste_gate": continue
		var best: Dictionary = {}
		var score := INF
		for area in areas:
			if area.kind in ["piste_gate","walkway"] or gate.center.distance_to(area.center) > area.radius+LINK_GAP: continue
			var target: String = area.key
			if area.kind == "station": target = "l"+area.key.substr(1)
			var path := path_between(gate.point,Terrain.unpack(nodes[target]),buildings,lifts,shapes)
			if path.is_empty(): continue
			if not gentle(mountain,path) and gate.center.distance_to(area.center) > area.radius: continue
			var time := walk_minutes(mountain,path)
			if time < score:
				score = time
				best = {"from":gate.key,"to":target,"points":path,"width":7.0,"piste_access":true}
		if not best.is_empty(): fixed.append(best)
	if mountain.get("generation") != null and mountain.generation >= 2:
		fixed.append_array(_village(mountain, areas, nodes, buildings, lifts, shapes))
	# Imported towns receive shared, terrain-checked access promenades between
	# nearby valley stations. These are game infrastructure, not OSM roads.
	if mountain.get("id") in ["braunlage", "filzmoos", "kitzbuehel", "seiseralm"]:
		var connected: Array = [{"key": "base", "point": Terrain.BASE}]
		var pending: Array = []
		for area in areas:
			if area.kind == "station" and area.key.ends_with("b") and area.center.distance_to(Terrain.BASE) < 1000 and mountain.height(area.center) < mountain.height(Terrain.BASE) + 150: pending.append(area)
		pending.sort_custom(func(a, b): return a.center.distance_to(Terrain.BASE) < b.center.distance_to(Terrain.BASE))
		for area in pending:
			if connected.size() >= 6: break
			var best: Array = []
			var source := ""
			var length := INF
			for other in connected:
				if area.point.distance_to(other.point) > 550: continue
				var path := path_between(other.point, area.point, buildings, lifts, shapes)
				if not path.is_empty() and gentle(mountain, path) and mountain.polyline_length(path) < length:
					best = path
					source = other.key
					length = mountain.polyline_length(path)
			if not best.is_empty():
				fixed.append({"from": source, "to": area.key, "points": best, "width": 8.0, "promenade": true})
				connected.append({"key": area.key, "point": area.point})
	var candidates: Array = []
	for i in range(areas.size()):
		for j in range(i+1,areas.size()):
			var a: Dictionary = areas[i]
			var b: Dictionary = areas[j]
			var landing_gap: float = 350.0 if mountain.get("id") in ["braunlage", "filzmoos", "kitzbuehel", "seiseralm"] and a.kind == "station" and b.kind == "station" and absf(mountain.height(a.center) - mountain.height(b.center)) < 70 else a.radius + b.radius + LINK_GAP
			if a.center.distance_to(b.center) > landing_gap: continue
			if a.id == b.id and a.kind == "walkway" and b.kind == "walkway": continue
			var path := path_between(a.point,b.point,buildings,lifts,shapes)
			if not path.is_empty() and gentle(mountain,path): candidates.append({"from":a.key,"to":b.key,"points":path,"length":mountain.polyline_length(path),"width":7.0})
	candidates.sort_custom(func(a,b): return a.length < b.length if not is_equal_approx(a.length,b.length) else str(a.from)+str(a.to) < str(b.from)+str(b.to))
	var components: Dictionary = {}
	for key in nodes: components[key] = key
	var links: Array = []
	for link in fixed+candidates:
		if link.get("closed",false):
			links.append(link)
			continue
		var a := _component(components,link.from)
		var b := _component(components,link.to)
		if link in fixed or dense or a != b:
			links.append(link)
			components[a] = b
	var rooted: Array = []
	var roots: Dictionary = {}
	for area in areas:
		if area.root: roots[_component(components,area.key)] = true
	for key in nodes:
		if roots.has(_component(components,key)): rooted.append(key)
	return {"areas":areas,"nodes":nodes,"links":links,"rooted":rooted,"lifts":lifts,"buildings":buildings,"obstacles":shapes}

static func _village(mountain: RefCounted, areas: Array, nodes: Dictionary, buildings: Array, lifts: Array, shapes: Array) -> Array:
	# A real shared street graph: every forecourt joins the same spine, rather
	# than drawing independent diagonal shortcuts between neighbouring buildings.
	var route: Array = [Terrain.pack(Terrain.BASE)]
	for target in [Vector2(185, 292), Vector2(95, 294), Vector2(-25, 277), Vector2(-150, 250)]:
		var part := path_between(Terrain.unpack(route[-1]), target, buildings, lifts, shapes)
		if not part.is_empty() and gentle(mountain, part): route.append_array(part.slice(1))
	route = smooth_walk(mountain, route, buildings, lifts)
	var links: Array = []
	var joins: Dictionary = {}
	for i in range(1, route.size()): joins[i] = []
	for area in areas.duplicate():
		if area.key == "base" or area.kind == "piste_gate": continue
		var best: Dictionary = {}
		var distance := INF
		for i in range(1, route.size()):
			var a := Terrain.unpack(route[i - 1])
			var b := Terrain.unpack(route[i])
			var at := Geometry2D.get_closest_point_to_segment(area.point, a, b)
			var gap: float = at.distance_to(area.point)
			if gap >= distance or gap > area.radius + 60: continue
			var part := path_between(area.point, at, buildings, lifts, shapes)
			if part.is_empty() or not gentle(mountain, part): continue
			distance = gap
			best = {"index": i, "point": at, "path": part, "along": a.distance_to(at)}
		if best.is_empty(): continue
		var key: String = "street_" + area.key
		nodes[key] = Terrain.pack(best.point)
		areas.append(_area(key, best.point, best.point, 7, false, 0, "street"))
		joins[best.index].append({"key": key, "along": best.along})
		links.append({"from": area.key, "to": key, "points": best.path, "width": 7.0, "village_branch": true})
	var previous := "base"
	for i in range(1, route.size()):
		joins[i].sort_custom(func(a, b): return a.along < b.along)
		var key := "street_v%d" % i
		nodes[key] = route[i]
		areas.append(_area(key, Terrain.unpack(route[i]), Terrain.unpack(route[i]), 7, false, 0, "street"))
		var entries: Array = joins[i] + [{"key": key}]
		for entry in entries:
			links.append({"from": previous, "to": entry.key, "points": [nodes[previous], nodes[entry.key]], "width": 12.0, "promenade": true})
			previous = entry.key
	return links

static func smooth_walk(mountain: RefCounted, points: Array, buildings: Array, lifts: Array) -> Array:
	if points.size() < 3: return points
	var handles: Array[Vector2] = []
	for i in range(points.size()):
		var at := Terrain.unpack(points[i])
		var before := Terrain.unpack(points[maxi(0, i - 1)])
		var after := Terrain.unpack(points[mini(points.size() - 1, i + 1)])
		var distance := minf(at.distance_to(before) if i > 0 else INF, at.distance_to(after) if i < points.size() - 1 else INF)
		handles.append((after - before).normalized() * minf(12, distance * 0.2))
	var result: Array = [points[0]]
	for i in range(1, points.size()):
		var a := Terrain.unpack(points[i - 1])
		var b := Terrain.unpack(points[i])
		var steps := maxi(1, ceili(a.distance_to(b) / 16))
		if result.size() + steps + points.size() - i > 64: return points
		for j in range(1, steps):
			var at := a.bezier_interpolate(a + handles[i - 1], b - handles[i], b, float(j) / steps)
			if at.distance_to(Terrain.unpack(result[-1])) >= 2 and at.distance_to(b) >= 2: result.append(Terrain.pack(at))
		result.append(points[i])
	return result if clear_walk(result, buildings, lifts) and gentle(mountain, result) else points

static func _component(components: Dictionary, key: String) -> String:
	var current := key
	while components[current] != current: current = components[current]
	var at := key
	while components[at] != at:
		var next: String = components[at]
		components[at] = current
		at = next
	return current

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

static func connection(mountain: RefCounted, layout_value: Dictionary, buildings: Array, kind: String, point: Vector2, rotation_value: int = 0) -> Dictionary:
	var proposed := {"kind": kind, "point": Terrain.pack(point), "rotation": rotation_value}
	var entrance := forecourt(proposed)
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

static func walk_minutes(mountain: RefCounted, points: Array) -> float:
	var seconds := 0.0
	for i in range(1,points.size()):
		var a := Terrain.unpack(points[i-1])
		var b := Terrain.unpack(points[i])
		var steps := maxi(1,ceili(a.distance_to(b)/8))
		for step in range(steps):
			var p := a.lerp(b,float(step)/steps)
			var q := a.lerp(b,float(step+1)/steps)
			var grade: float = (mountain.height(q)-mountain.height(p))/maxf(p.distance_to(q),0.01)
			var speed := clampf(1.4*exp(-3.5*maxf(grade,0)-1.2*maxf(-grade-0.12,0)),0.35,1.4)
			seconds += mountain.world(p).distance_to(mountain.world(q))/speed
	return seconds*0.5

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

static var _cache_mutex := Mutex.new()
static var _obstacle_cache: Dictionary = {}
static var _inset_cache: Dictionary = {}

static func boarding_point(lift: Dictionary, top: bool) -> Vector2:
	var direction := (Terrain.unpack(lift.top) - Terrain.unpack(lift.bottom)).normalized()
	return Fleet.station_point(lift, top) + direction * (machine_radius(lift) + 7) * (1 if top else -1)

static func obstacles(buildings: Array, lifts: Array) -> Array:
	var fingerprint := [buildings.map(func(building): return [building.kind, building.point, building.get("rotation", 0)]), lifts.map(func(lift): return [lift.kind, lift.bottom, lift.top])].hash()
	_cache_mutex.lock()
	var cached: Array = _obstacle_cache.get(fingerprint, [])
	var known := _obstacle_cache.has(fingerprint)
	_cache_mutex.unlock()
	if known: return cached
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
	_cache_mutex.lock()
	if _obstacle_cache.size() > 64:
		_obstacle_cache.clear()
	_obstacle_cache[fingerprint] = result
	_cache_mutex.unlock()
	return result

static func crosses_polygon(a: Vector2, b: Vector2, polygon: PackedVector2Array) -> bool:
	# A tiny inward offset allows visibility edges to follow obstacle boundaries.
	var key := hash(polygon)
	_cache_mutex.lock()
	if not _inset_cache.has(key):
		if _inset_cache.size() > 512:
			_inset_cache.clear()
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			bounds = bounds.expand(point)
		_inset_cache[key] = {"bounds": bounds, "shapes": Geometry2D.offset_polygon(polygon, -0.08)}
	var data: Dictionary = _inset_cache[key]
	_cache_mutex.unlock()
	var segment_bounds := Rect2(a, Vector2.ZERO).expand(b).grow(0.001)
	if not data.bounds.intersects(segment_bounds, true):
		return false
	var inset: Array = data.shapes
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

static func path_between(from: Vector2, to: Vector2, buildings: Array, lifts: Array = [], prepared: Array = []) -> Array:
	var shapes := obstacles(buildings, lifts) if prepared.is_empty() else prepared
	var blocked := false
	for shape in shapes:
		if crosses_polygon(from,from,shape) or crosses_polygon(to,to,shape):
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
