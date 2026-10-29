extends RefCounted
const L = preload("res://src/core/i18n.gd")
## Shared coordinates, validation constants and the compatible original valley.
## Coordinates are horizontal metres; negative Z points up the mountain.

const BOUNDS := Rect2(-360, -400, 720, 740)
const BASE := Vector2(185, 230)
const CONNECTION_RADIUS := 42.0
const SAMPLE_STEP := 3.0
const GRADE_LIMITS := [30.0, 55.0, 110.0]
const PISTE_NAMES := ["Blaue Piste", "Rote Piste", "Schwarze Piste"]

static func contains(point: Vector2) -> bool:
	return point.is_finite() and BOUNDS.has_point(point)

static func height(point: Vector2) -> float:
	var climb := maxf(210.0 - point.y, 0.0)
	var west_peak := 116.0 * exp(-pow((point.x + 170.0) / 132.0, 2.0) - pow((point.y + 235.0) / 150.0, 2.0))
	var north_peak := 54.0 * exp(-pow((point.x - 40.0) / 200.0, 2.0) - pow((point.y + 350.0) / 150.0, 2.0))
	var detail := sin(point.x * 0.018) * sin(climb * 0.012) * 2.8
	return 6.0 + climb * 0.205 + west_peak + north_peak + detail

static func world(point: Vector2, offset: float = 0.0) -> Vector3:
	return Vector3(point.x, height(point) + offset, point.y)

static func slope_percent(point: Vector2) -> float:
	# Steepest local inclination; a traverse may have a gentler downhill profile.
	if not point.is_finite():
		return INF
	var dx := (height(point + Vector2(3, 0)) - height(point - Vector2(3, 0))) / 6.0
	var dz := (height(point + Vector2(0, 3)) - height(point - Vector2(0, 3))) / 6.0
	return Vector2(dx, dz).length() * 100.0

static func unpack(value: Variant) -> Vector2:
	if value is Array and value.size() == 2 and number(value[0]) and number(value[1]):
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.INF

static func pack(point: Vector2) -> Array:
	return [point.x, point.y]

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func polyline_length(points: Array) -> float:
	var length := 0.0
	for i in range(1, points.size()):
		length += world(unpack(points[i - 1])).distance_to(world(unpack(points[i])))
	return length

static func point_on_path(points: Array, fraction: float) -> Vector2:
	if points.is_empty():
		return BASE
	var distance_left := polyline_length(points) * clampf(fraction, 0.0, 1.0)
	for i in range(1, points.size()):
		var a := unpack(points[i - 1])
		var b := unpack(points[i])
		var distance := world(a).distance_to(world(b))
		if distance_left <= distance:
			return a.lerp(b, distance_left / maxf(distance, 0.001))
		distance_left -= distance
	return unpack(points.back())

static func analyse(points: Array, difficulty: int) -> Dictionary:
	var result := {"ok": false, "message": L.text("Mindestens zwei Wegpunkte setzen."), "length": 0.0, "drop": 0.0, "grade": 0.0, "cost": 0, "difficulty": difficulty}
	if points.size() < 2 or points.size() > 64 or difficulty < 0 or difficulty > 2:
		return result
	for point in points:
		if not contains(unpack(point)):
			result.message = L.text("Die Strecke muss innerhalb des Baugebiets liegen.")
			return result
	var max_grade := 0.0
	var length := 0.0
	var uphill := 0.0
	for i in range(1, points.size()):
		var a := unpack(points[i - 1])
		var b := unpack(points[i])
		var horizontal := a.distance_to(b)
		if horizontal < 4.0:
			result.message = L.text("Wegpunkte müssen mindestens 4 m auseinanderliegen.")
			return result
		var samples := ceili(horizontal / SAMPLE_STEP)
		for j in range(samples):
			var p := a.lerp(b, float(j) / samples)
			var q := a.lerp(b, float(j + 1) / samples)
			var difference := height(p) - height(q)
			max_grade = maxf(max_grade, difference / p.distance_to(q) * 100.0)
			uphill += maxf(-difference, 0.0)
			length += world(p).distance_to(world(q))
	result.length = length
	result.grade = max_grade
	result.drop = height(unpack(points.front())) - height(unpack(points.back()))
	result.cost = roundi(length * [32.0, 44.0, 58.0][difficulty])
	if length < 40.0 or result.drop < 7.0:
		result.message = L.text("Mindestens 40 m Länge und 7 m Höhenverlust erforderlich.")
	elif uphill > 1.5 and not preload("res://src/core/ski_dynamics.gd").profile(new(),points,difficulty).ok:
		result.message = L.text("Gegenanstieg zu steil zum Stapfen. Mit weiteren Wegpunkten queren.")
	elif max_grade > GRADE_LIMITS[difficulty]:
		result.message = L.text("%.0f %% Gefälle: Für diese Farbe sind höchstens %.0f %% erlaubt.") % L.args([max_grade, GRADE_LIMITS[difficulty]])
	else:
		result.ok = true
		result.message = L.text("%s · %.0f m · %.0f m Abfahrt · max. %.0f %%") % L.args([PISTE_NAMES[difficulty], length, result.drop, max_grade])
	return result
