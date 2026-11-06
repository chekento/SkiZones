extends RefCounted
## All surfaces share the same eight-metre accessible corridor and routing rules.
## A stroke becomes editable waypoints only after the pointer is released.
const SURFACES := {
	"snow": {"name":"Schneeweg", "per_m":18, "color":"b1cbd4"},
	"gravel": {"name":"Kiesweg", "per_m":24, "color":"ad9575"},
	"timber": {"name":"Holzsteg", "per_m":38, "color":"927052"},
	"paved": {"name":"Pflasterweg", "per_m":32, "color":"81949c"}
}

static func simplify(stroke: Array, tolerance: float = 1.5) -> Array:
	if stroke.size() < 3: return stroke.duplicate(true)
	var a := Vector2(float(stroke[0][0]), float(stroke[0][1]))
	var b := Vector2(float(stroke[-1][0]), float(stroke[-1][1]))
	var furthest := 0
	var distance := tolerance
	for index in range(1, stroke.size() - 1):
		var point := Vector2(float(stroke[index][0]), float(stroke[index][1]))
		var error := point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b))
		if error > distance:
			distance = error
			furthest = index
	if furthest == 0: return [stroke[0].duplicate(), stroke[-1].duplicate()]
	var left := simplify(stroke.slice(0, furthest + 1), tolerance)
	left.append_array(simplify(stroke.slice(furthest), tolerance).slice(1))
	return left

static func waypoints(stroke: Array) -> Array:
	var clean: Array = []
	for row in stroke:
		if not row is Array or row.size() != 2: return []
		if not (row[0] is int or row[0] is float) or not (row[1] is int or row[1] is float): return []
		var at := Vector2(float(row[0]), float(row[1]))
		if not at.is_finite(): return []
		if clean.is_empty() or at.distance_to(Vector2(clean[-1][0],clean[-1][1])) >= 2.0:
			clean.append([at.x,at.y])
	if clean.size() < 2: return []
	# Reject an over-complex stroke instead of silently cutting off its end.
	var result := simplify(clean)
	return result if result.size() <= 64 else []
