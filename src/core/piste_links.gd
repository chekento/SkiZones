extends RefCounted
## Exact docks on a corridor's centreline, indexed independently of its vertices.
const Terrain = preload("res://src/core/terrain.gd")
const CELL := 96.0
var grid: Dictionary = {}
var items: Dictionary = {}

func _init(pistes: Array) -> void:
	for piste in pistes:
		items[piste.id] = piste
		for index in range(1, piste.points.size()):
			var a := Terrain.unpack(piste.points[index - 1])
			var b := Terrain.unpack(piste.points[index])
			var segment := {"a": a, "b": b, "id": piste.id, "index": index}
			var bounds := Rect2(a, Vector2.ZERO).expand(b).grow(0.03)
			for x in range(floori(bounds.position.x / CELL), floori(bounds.end.x / CELL) + 1):
				for y in range(floori(bounds.position.y / CELL), floori(bounds.end.y / CELL) + 1):
					var cell := Vector2i(x, y)
					if not grid.has(cell): grid[cell] = []
					grid[cell].append(segment)

func nearby(point: Vector2, radius: float) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for x in range(floori((point.x - radius) / CELL), floori((point.x + radius) / CELL) + 1):
		for y in range(floori((point.y - radius) / CELL), floori((point.y + radius) / CELL) + 1):
			for segment in grid.get(Vector2i(x, y), []):
				var key := Vector2i(segment.id, segment.index)
				if not seen.has(key): result.append(segment); seen[key] = true
	return result

func stitch(points: Array, ignore_id: int = -1) -> Dictionary:
	# Planning never edits the live neighbour. Confirmation inserts collinear
	# vertices so routing, editing and saved itineraries share the same junction.
	var cuts: Dictionary = {}
	for value in points:
		var point := Terrain.unpack(value)
		for segment in nearby(point, 0.03):
			if segment.id == ignore_id: continue
			var at := Geometry2D.get_closest_point_to_segment(point, segment.a, segment.b)
			if at.distance_to(point) > 0.02 or at.distance_to(segment.a) < 0.03 or at.distance_to(segment.b) < 0.03: continue
			if not cuts.has(segment.id): cuts[segment.id] = {}
			if not cuts[segment.id].has(segment.index): cuts[segment.id][segment.index] = []
			var projected: Array = value.duplicate() if at.distance_to(point) < 0.001 else Terrain.pack(at)
			if not cuts[segment.id][segment.index].has(projected): cuts[segment.id][segment.index].append(projected)
	var changes: Dictionary = {}
	for id in cuts:
		var source: Array = items[id].points
		var next: Array = [source[0].duplicate()]
		for index in range(1, source.size()):
			var start := Terrain.unpack(source[index - 1])
			var insert: Array = cuts[id].get(index, [])
			insert.sort_custom(func(a, b): return start.distance_squared_to(Terrain.unpack(a)) < start.distance_squared_to(Terrain.unpack(b)))
			for point in insert:
				if Terrain.unpack(next[-1]).distance_to(Terrain.unpack(point)) > 0.03: next.append(point)
			next.append(source[index].duplicate())
		if next.size() > 64: return {"ok": false, "changes": {}}
		changes[id] = next
	return {"ok": true, "changes": changes}

static func profile_points(points: Array) -> Array:
	# Topology cuts are collinear and may sit closer than the four-metre user
	# spacing. Analyse the unchanged physical line, retaining every real bend.
	var result: Array = []
	for point in points:
		while result.size() >= 2:
			var a := Terrain.unpack(result[-2])
			var b := Terrain.unpack(result[-1])
			var c := Terrain.unpack(point)
			if a.distance_to(c) < 0.01 or Geometry2D.get_closest_point_to_segment(b, a, c).distance_to(b) > 0.001: break
			result.pop_back()
		result.append(point)
	return result
