extends RefCounted
var journey_scale := 30.0
const L = preload("res://src/core/i18n.gd")
## An instance prevents one open/test resort from changing another map's terrain.
const Terrain = preload("res://src/core/terrain.gd")
const Dynamics = preload("res://src/core/ski_dynamics.gd")
const Maps = preload("res://src/core/maps.gd")
const Grading = preload("res://src/core/piste_grading.gd")
var id := "sonnenhang"
var generation := 1
var bounds: Rect2
var base := Terrain.BASE
var _paths: Dictionary = {}
var grading := Grading.new()

func _init(map_id: String = "sonnenhang", terrain_generation: int = 1) -> void:
	id = map_id
	generation = terrain_generation
	bounds = Maps.spec(id).bounds

func contains(point: Vector2) -> bool:
	return point.is_finite() and bounds.has_point(point)

func height(point: Vector2) -> float:
	var natural := natural_height(point)
	return natural + grading.offset(self, point, natural)

func natural_height(point: Vector2) -> float:
	return Maps.base_height(point, id, generation) + Maps.extra_height(point, id, generation)

func configure_pistes(pistes: Array) -> void:
	if grading.configure(pistes, bounds): _paths.clear()

func world(point: Vector2, offset: float = 0.0) -> Vector3:
	return Vector3(point.x, height(point) + offset, point.y)

func slope_percent(point: Vector2) -> float:
	return Vector2(height(point + Vector2(3, 0)) - height(point - Vector2(3, 0)), height(point + Vector2(0, 3)) - height(point - Vector2(0, 3))).length() / 6.0 * 100.0

func cable_profile(bottom: Vector2, top: Vector2, rope_height: float = 15, station_height: float = 15, clearance: float = 9) -> Dictionary:
	var points: Array = []
	var lengths: Array = [0.0]
	var count := maxi(1, ceili(bottom.distance_to(top) / 50))
	for i in range(count + 1):
		points.append(world(bottom.lerp(top, float(i) / count), station_height if i == 0 or i == count else rope_height))
	for iteration in range(2):
		var refined: Array = [points[0]]
		for i in range(1, points.size()):
			var a: Vector3 = points[i - 1]
			var b: Vector3 = points[i]
			var split := false
			for fraction in [0.25, 0.5, 0.75]:
				var sample := a.lerp(b, fraction)
				split = split or sample.y < height(Vector2(sample.x, sample.z)) + clearance
			if split:
				var midpoint := (a + b) * 0.5
				refined.append(world(Vector2(midpoint.x, midpoint.z), rope_height))
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

func waypoint_fraction(points: Array, index: int) -> float:
	var path := _path(points)
	return path.lengths[clampi(index, 0, points.size() - 1)] / maxf(path.length, 0.001)

func corner_taper(points: Array, fraction: float, length: float) -> float:
	# Cache lookup once per position, not once for every node in a long route.
	var path := _path(points)
	var taper := 1.0
	for index in range(1, points.size() - 1):
		var distance: float = absf(fraction - path.lengths[index] / maxf(path.length, 0.001)) * length
		if distance >= 18:
			continue
		var incoming := (Terrain.unpack(points[index]) - Terrain.unpack(points[index - 1])).normalized()
		var outgoing := (Terrain.unpack(points[index + 1]) - Terrain.unpack(points[index])).normalized()
		var sharpness := clampf((1.0 - incoming.dot(outgoing)) * 0.7, 0, 1)
		taper *= lerpf(1.0, smoothstep(0, 18, distance), sharpness)
	return taper

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

static func difficulty_for_grade(grade: float) -> int:
	# Longitudinal route grade, not the steepest direction of the mountain.
	# These are deliberately the existing game limits, not a real-world certification.
	return 0 if grade <= Terrain.GRADE_LIMITS[0] else (1 if grade <= Terrain.GRADE_LIMITS[1] else 2)

func analyse(points: Array, _legacy_choice: int = -1, imported: bool = false) -> Dictionary:
	# The optional argument keeps old callers compatible; colors can no longer be painted.
	var result := {"ok": false, "message": L.text("Mindestens zwei Wegpunkte setzen."), "length": 0.0, "horizontal": 0.0, "drop": 0.0, "grade": 0.0, "average": 0.0, "uphill": 0.0, "cost": 0, "difficulty": 0, "profile": [], "segments": []}
	if points.size() < 2 or points.size() > 64:
		return result
	for point in points:
		if not contains(Terrain.unpack(point)):
			result.message = L.text("Die Strecke muss innerhalb des Baugebiets liegen.")
			return result
	var planned_length := 0.0
	for i in range(1, points.size()):
		planned_length += Terrain.unpack(points[i - 1]).distance_to(Terrain.unpack(points[i]))
	var profile_step := maxf(8, planned_length / 512)
	var next_sample := profile_step
	result.profile.append({"distance": 0.0, "height": height(Terrain.unpack(points[0])), "grade": 0.0})
	for i in range(1, points.size()):
		var a := Terrain.unpack(points[i - 1])
		var b := Terrain.unpack(points[i])
		if a.distance_to(b) < (0.005 if imported else 4):
			result.message = L.text("Wegpunkte müssen mindestens 4 m auseinanderliegen.")
			return result
		var steps := ceili(a.distance_to(b) / Terrain.SAMPLE_STEP)
		var segment_grade := 0.0
		for j in range(steps):
			var p := a.lerp(b, float(j) / steps)
			var q := a.lerp(b, float(j + 1) / steps)
			var drop := height(p) - height(q)
			var grade := drop / p.distance_to(q) * 100
			result.grade = maxf(result.grade, grade)
			segment_grade = maxf(segment_grade, grade)
			result.uphill += maxf(-drop, 0)
			result.horizontal += p.distance_to(q)
			result.length += world(p).distance_to(world(q))
			if result.horizontal >= next_sample or j == steps - 1:
				result.profile.append({"distance": result.horizontal, "height": height(q), "grade": grade})
				next_sample = result.horizontal + profile_step
		result.segments.append({"grade": segment_grade, "drop": height(a) - height(b), "difficulty": difficulty_for_grade(segment_grade)})
	result.drop = height(Terrain.unpack(points.front())) - height(Terrain.unpack(points.back()))
	result.average = result.drop / maxf(result.horizontal, 0.001) * 100
	result.difficulty = difficulty_for_grade(result.grade)
	result.cost = roundi(result.length * [32, 44, 58][result.difficulty])
	if imported and result.length >= 1:
		var motion := Dynamics.profile(self, points, result.difficulty, 0.86)
		result.ok = motion.ok and result.grade < 180
		result.hike_meters = motion.hike_meters
		result.carry_rise = motion.carry_rise
		return result
	if result.length < 40 or result.drop < 7:
		result.message = L.text("Mindestens 40 m Länge und 7 m Höhenverlust erforderlich.")
	elif result.grade > Terrain.GRADE_LIMITS[2]:
		result.message = L.text("Max. %.0f %%: zu steil. Mit weiteren Wegpunkten quer zum Hang planen.") % L.args(result.grade)
	else:
		var motion := Dynamics.profile(self,points,result.difficulty,0.86)
		if not motion.ok:
			result.message = motion.message
			return result
		result.hike_meters = motion.hike_meters
		result.carry_rise = motion.carry_rise
		result.ok = true
		result.message = L.text("%s · %.0f m · ↓ %.0f m · max. %.0f %%") % L.args([Terrain.PISTE_NAMES[result.difficulty], result.length, result.drop, result.grade])
		if result.uphill > 0.2:
			result.message += L.text(" · ↑ %.1f m Gegenanstieg: %s") % L.args([result.uphill,L.text("ca. %.0f m stapfen") % L.args(result.hike_meters) if result.hike_meters > 0.5 else L.text("mit Schwung fahrbar")])
	return result

func _path_point(path: Dictionary, distance: float) -> Vector2:
	var lower := 1
	var upper: int = path.lengths.size() - 1
	while lower < upper:
		var middle := (lower + upper) / 2
		if path.lengths[middle] < distance:
			lower = middle + 1
		else:
			upper = middle
	return path.unpacked[lower - 1].lerp(path.unpacked[lower], clampf((distance - path.lengths[lower - 1]) / maxf(path.lengths[lower] - path.lengths[lower - 1], 0.001), 0, 1))

func path_frame(points: Array, fraction: float, length: float) -> Dictionary:
	var path := _path(points)
	if not path.has("unpacked"):
		path.unpacked = []
		path.corners = []
		for point in points:
			path.unpacked.append(Terrain.unpack(point))
		for i in range(1, points.size() - 1):
			var incoming: Vector2 = (path.unpacked[i] - path.unpacked[i - 1]).normalized()
			var outgoing: Vector2 = (path.unpacked[i + 1] - path.unpacked[i]).normalized()
			path.corners.append(Vector2(path.lengths[i] / maxf(path.length, 0.001) * length, clampf((1 - incoming.dot(outgoing)) * 0.7, 0, 1)))
	var distance: float = clampf(fraction, 0, 1) * path.length
	var direction := (_path_point(path, minf(path.length, distance + path.length * 0.006)) - _path_point(path, maxf(0, distance - path.length * 0.006))).normalized()
	var taper := 1.0
	for corner in path.corners:
		var gap: float = absf(fraction * length - corner.x)
		if corner.x > fraction * length + 18: break
		if gap < 18:
			taper *= lerpf(1, smoothstep(0, 18, gap), corner.y)
	return {"point": _path_point(path, distance), "direction": direction, "taper": taper}
