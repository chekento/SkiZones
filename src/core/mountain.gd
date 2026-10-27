extends RefCounted
## An instance prevents one open/test resort from changing another map's terrain.
const Terrain = preload("res://src/core/terrain.gd")
const Maps = preload("res://src/core/maps.gd")
var id := "sonnenhang"
var bounds: Rect2
var base := Terrain.BASE
var _paths: Dictionary = {}

func _init(map_id: String = "sonnenhang") -> void:
	id = map_id
	bounds = Maps.spec(id).bounds

func contains(point: Vector2) -> bool:
	return point.is_finite() and bounds.has_point(point)

func height(point: Vector2) -> float:
	return Terrain.height(point) + Maps.extra_height(point, id)

func world(point: Vector2, offset: float = 0.0) -> Vector3:
	return Vector3(point.x, height(point) + offset, point.y)

func slope_percent(point: Vector2) -> float:
	return Vector2(height(point + Vector2(3, 0)) - height(point - Vector2(3, 0)), height(point + Vector2(0, 3)) - height(point - Vector2(0, 3))).length() / 6.0 * 100.0

func cable_profile(bottom: Vector2, top: Vector2) -> Dictionary:
	var points: Array = []
	var lengths: Array = [0.0]
	var count := ceili(bottom.distance_to(top) / 50)
	for i in range(count + 1):
		points.append(world(bottom.lerp(top, float(i) / count), 15))
	for iteration in range(2):
		var refined: Array = [points[0]]
		for i in range(1, points.size()):
			var a: Vector3 = points[i - 1]
			var b: Vector3 = points[i]
			var split := false
			for fraction in [0.25, 0.5, 0.75]:
				var sample := a.lerp(b, fraction)
				split = split or sample.y < height(Vector2(sample.x, sample.z)) + 9
			if split:
				var midpoint := (a + b) * 0.5
				refined.append(world(Vector2(midpoint.x, midpoint.z), 15))
			refined.append(b)
		points = refined
	for i in range(1, points.size()):
		lengths.append(lengths[-1] + points[i - 1].distance_to(points[i]))
	return {"points": points, "lengths": lengths, "length": lengths[-1]}

func _path(points: Array) -> Dictionary:
	var key := points.hash()
	for entry in _paths.get(key, []):
		if entry.points == points:
			return entry
	var lengths: Array = [0.0]
	for i in range(1, points.size()):
		lengths.append(lengths[-1] + world(Terrain.unpack(points[i - 1])).distance_to(world(Terrain.unpack(points[i]))))
	var entry := {"points": points.duplicate(true), "lengths": lengths, "length": lengths[-1]}
	if _paths.size() > 2048:
		_paths.clear()
	if not _paths.has(key):
		_paths[key] = []
	_paths[key].append(entry)
	return entry

func polyline_length(points: Array) -> float:
	return _path(points).length

func point_on_path(points: Array, fraction: float) -> Vector2:
	if points.is_empty():
		return base
	var path := _path(points)
	var distance: float = path.length * clampf(fraction, 0, 1)
	for i in range(1, points.size()):
		if distance <= path.lengths[i]:
			var a := Terrain.unpack(points[i - 1])
			var b := Terrain.unpack(points[i])
			return a.lerp(b, (distance - path.lengths[i - 1]) / maxf(path.lengths[i] - path.lengths[i - 1], 0.001))
	return Terrain.unpack(points.back())

func analyse(points: Array, difficulty: int) -> Dictionary:
	var result := {"ok": false, "message": "Mindestens zwei Wegpunkte setzen.", "length": 0.0, "drop": 0.0, "grade": 0.0, "cost": 0, "difficulty": difficulty}
	if points.size() < 2 or points.size() > 64 or difficulty < 0 or difficulty > 2:
		return result
	for point in points:
		if not contains(Terrain.unpack(point)):
			result.message = "Die Strecke muss innerhalb des Baugebiets liegen."
			return result
	var uphill := 0.0
	for i in range(1, points.size()):
		var a := Terrain.unpack(points[i - 1])
		var b := Terrain.unpack(points[i])
		if a.distance_to(b) < 4:
			result.message = "Wegpunkte müssen mindestens 4 m auseinanderliegen."
			return result
		var steps := ceili(a.distance_to(b) / Terrain.SAMPLE_STEP)
		for j in range(steps):
			var p := a.lerp(b, float(j) / steps)
			var q := a.lerp(b, float(j + 1) / steps)
			var drop := height(p) - height(q)
			result.grade = maxf(result.grade, drop / p.distance_to(q) * 100)
			uphill += maxf(-drop, 0)
			result.length += world(p).distance_to(world(q))
	result.drop = height(Terrain.unpack(points.front())) - height(Terrain.unpack(points.back()))
	result.cost = roundi(result.length * [32, 44, 58][difficulty])
	if result.length < 40 or result.drop < 7:
		result.message = "Mindestens 40 m Länge und 7 m Höhenverlust erforderlich."
	elif uphill > 1.5:
		result.message = "Die Abfahrt führt bergauf. Wegpunkte vom Berg ins Tal setzen."
	elif result.grade > Terrain.GRADE_LIMITS[difficulty]:
		result.message = "%.0f %% Gefälle: Für diese Farbe sind höchstens %.0f %% erlaubt." % [result.grade, Terrain.GRADE_LIMITS[difficulty]]
	else:
		result.ok = true
		result.message = "%s · %.0f m · %.0f m Abfahrt · max. %.0f %%" % [Terrain.PISTE_NAMES[difficulty], result.length, result.drop, result.grade]
	return result
