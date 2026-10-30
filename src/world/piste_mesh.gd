extends RefCounted
## A clipped terrain grid fills the whole rounded corridor, including hairpins.
## It never rotates a wide strip across a sharp corner or joins inverted rows.
const Terrain = preload("res://src/core/terrain.gd")

static func nearest(mountain: RefCounted, points: Array, point: Vector2) -> Dictionary:
	var distance := INF
	var result := {"fraction": 0.0, "lateral": 0.0, "distance": INF}
	for index in range(1, points.size()):
		var a := Terrain.unpack(points[index - 1])
		var b := Terrain.unpack(points[index])
		var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
		var delta := closest.distance_to(point)
		if delta < distance:
			distance = delta
			var weight := a.distance_to(closest) / maxf(a.distance_to(b), 0.001)
			result = {"fraction": lerpf(mountain.waypoint_fraction(points, index - 1), mountain.waypoint_fraction(points, index), weight), "lateral": (point - closest).dot((b - a).normalized().orthogonal()), "distance": delta}
	return result

static func outlines(points: Array, width: float) -> Array:
	var line := PackedVector2Array()
	for point in points: line.append(Terrain.unpack(point))
	return Geometry2D.offset_polyline(line, width * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_BUTT)

static func polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	return bounds

static func shared_boundary(polygon: PackedVector2Array) -> PackedVector2Array:
	# Imported corridors use larger interior cells. Keep their boundary vertices
	# on the same four-metre lattice as a player-built neighbour, preventing
	# cracks where a fine edge would otherwise meet one long coarse edge.
	var result := PackedVector2Array()
	for index in range(polygon.size()):
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var cuts: Array = [0.0]
		for axis in range(2):
			if absf(b[axis] - a[axis]) < 0.00001: continue
			for line in range(floori(minf(a[axis], b[axis]) / 4) + 1, ceili(maxf(a[axis], b[axis]) / 4)):
				var t: float = (line * 4.0 - a[axis]) / (b[axis] - a[axis])
				if t > 0.00001 and t < 0.99999: cuts.append(t)
		cuts.sort()
		for t in cuts:
			var point := a.lerp(b, t)
			if result.is_empty() or result[-1].distance_to(point) > 0.0001: result.append(point)
	return result

static func samples(mountain: RefCounted, points: Array, width: float, step: float = 4.0, exclusions: Array = []) -> Array:
	if points.size() < 2:
		return []
	var corridors := outlines(points, width)
	var cells: Dictionary = {}
	# Only visit cells near a centerline segment, rather than the large bounding box.
	for index in range(1, points.size()):
		var a := Terrain.unpack(points[index - 1])
		var b := Terrain.unpack(points[index])
		var count := maxi(1, ceili(a.distance_to(b) / step))
		var radius := ceili(width * 0.5 / step) + 1
		for i in range(count + 1):
			var cell := Vector2i((a.lerp(b, float(i) / count) / step).floor())
			for x in range(-radius, radius + 1):
				for y in range(-radius, radius + 1):
					cells[cell + Vector2i(x, y)] = true
	var result: Array = []
	var frames: Dictionary = {}
	for cell in cells:
		var p := Vector2(cell) * step
		var square := PackedVector2Array([p, p + Vector2(step, 0), p + Vector2(step, step), p + Vector2(0, step)])
		for outline in corridors:
			var polygons: Array = Geometry2D.intersect_polygons(square, outline)
			for exclusion in exclusions:
				if not exclusion.bounds.intersects(Rect2(p, Vector2.ONE * step), true): continue
				var remaining: Array = []
				for polygon in polygons: remaining.append_array(Geometry2D.clip_polygons(polygon, exclusion.polygon))
				polygons = remaining
			for polygon in polygons:
				if step > 4: polygon = shared_boundary(polygon)
				var indices := Geometry2D.triangulate_polygon(polygon)
				for i in range(0, indices.size(), 3):
					var a: Vector2 = polygon[indices[i]]
					var b: Vector2 = polygon[indices[i + 1]]
					var c: Vector2 = polygon[indices[i + 2]]
					if absf((b - a).cross(c - a)) < 0.0001:
						continue
					# Keep all triangles facing upwards; clipped polygons may have either winding.
					var triangle := [a, b, c] if (b - a).cross(c - a) > 0 else [a, c, b]
					for at in triangle:
						if not frames.has(at):
							var frame := nearest(mountain, points, at)
							frame.point = at
							frames[at] = frame
						result.append(frames[at])
	return result
