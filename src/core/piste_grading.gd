extends RefCounted
## Small cut/fill benches, never a replacement for route planning or a cliff tunnel.
const Terrain = preload("res://src/core/terrain.gd")
const CELL := 32.0
const MAX_CHANGE := 1.2
const SHOULDER := 6.0
var buckets: Dictionary = {}
var segments: Array = []
var signature := 0

func configure(pistes: Array) -> bool:
	var geometry: Array = []
	for piste in pistes:
		geometry.append([piste.get("points", []), piste.get("width", 20), piste.get("level", 1), piste.get("grading", false)])
	var next := hash(geometry)
	if next == signature: return false
	signature = next
	buckets.clear()
	segments.clear()
	var seen: Dictionary = {}
	for piste in pistes:
		var points: Variant = piste.get("points", [])
		if not points is Array or points.size() < 2 or points.size() > 64: continue
		if not Terrain.number(piste.get("width", 20)) or not Terrain.number(piste.get("level", 1)): continue
		var width := float(piste.get("width", 20)) + (int(piste.get("level", 1)) - 1) * 4
		if width < 14 or width > 44: continue
		var valid := true
		for point in points: valid = valid and Terrain.unpack(point).is_finite()
		if not valid: continue
		var key := hash([points, width, piste.get("grading", false)])
		if seen.has(key): continue
		seen[key] = true
		var length := 0.0
		for i in range(1, points.size()): length += Terrain.unpack(points[i - 1]).distance_to(Terrain.unpack(points[i]))
		var along := 0.0
		for i in range(1, points.size()):
			var a := Terrain.unpack(points[i - 1])
			var b := Terrain.unpack(points[i])
			var span := a.distance_to(b)
			if span < 0.01: continue
			var segment := {"a": a, "b": b, "span": span, "along": along, "length": length, "radius": width * 0.5, "graded": piste.get("grading", false) == true}
			segments.append(segment)
			var rect := Rect2(a, Vector2.ZERO).expand(b).grow(width * 0.5 + SHOULDER)
			for x in range(floori(rect.position.x / CELL), floori(rect.end.x / CELL) + 1):
				for y in range(floori(rect.position.y / CELL), floori(rect.end.y / CELL) + 1):
					var cell := Vector2i(x, y)
					if not buckets.has(cell): buckets[cell] = []
					buckets[cell].append(segment)
			along += span
	return true

func offset(mountain: RefCounted, point: Vector2, natural: float) -> float:
	var best: Dictionary = {}
	var nearest := INF
	var closest := Vector2.ZERO
	for segment in buckets.get(Vector2i((point / CELL).floor()), []):
		var at := Geometry2D.get_closest_point_to_segment(point, segment.a, segment.b)
		var distance := at.distance_to(point)
		# Keep all route centerlines and their exact connection heights intact.
		if distance < 0.01: return 0.0
		if segment.graded and distance < nearest and distance < segment.radius + SHOULDER:
			nearest = distance
			closest = at
			best = segment
	if best.is_empty(): return 0.0
	var along: float = best.along + best.a.distance_to(closest)
	var end_blend := smoothstep(8, 22, minf(along, best.length - along))
	var edge_blend := 1.0 - smoothstep(best.radius - 1.5, best.radius + SHOULDER, nearest)
	var center_blend := smoothstep(0, 1.5, nearest)
	var center: float = mountain.natural_height(closest)
	var target := center + clampf(natural - center, -nearest * 0.12, nearest * 0.12)
	return clampf(target - natural, -MAX_CHANGE, MAX_CHANGE) * end_blend * edge_blend * center_blend

func refined_cells(bounds: Rect2, step: float) -> Dictionary:
	var cells: Dictionary = {}
	for segment in segments:
		if not segment.graded: continue
		var count := maxi(1, ceili(segment.span / step))
		var radius := ceili((segment.radius + SHOULDER) / step) + 2
		for i in range(count + 1):
			var at: Vector2 = segment.a.lerp(segment.b, float(i) / count)
			var center := Vector2i(((at - bounds.position) / step).floor())
			for x in range(-radius, radius + 1):
				for y in range(-radius, radius + 1): cells[center + Vector2i(x, y)] = true
	return cells
