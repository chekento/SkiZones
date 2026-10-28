extends RefCounted
## Stable personal styles. Drawing, tracks and local snow interaction use one path.
const Terrain = preload("res://src/core/terrain.gd")
const FIRST := ["Mila", "Jonas", "Lea", "Emil", "Nora", "Finn", "Lina", "Theo", "Ella", "Luis", "Amira", "Ben", "Sofia", "Paul", "Maja", "Noah"]
const COLORS := ["de8358", "438eaf", "bf6688", "d9b057", "6da490", "8d7eb3", "da605d", "77aaca"]

static func name_for(id: int) -> String:
	return FIRST[(id * 7) % FIRST.size()] + " " + String.chr(65 + (id * 13) % 26) + "."

static var _styles: Dictionary = {}

static func style(id: int, ability: int) -> Dictionary:
	var key := (id % 2700) * 3 + ability
	if _styles.has(key):
		return _styles[key]
	var value := {"name": [["Sanfte Bögen", "Ruhige Linie", "Weite Schwünge"], ["Runde Schwünge", "Kurze Schwünge", "Weite Bögen"], ["Sportliches Carven", "Kurze Radien", "Dynamische Bögen"]][ability][id % 3], "speed": [5.2, 7.5, 10.0][ability] * (0.86 + float((id * 37) % 100) / 350), "wave": (38.0 if ability == 0 else 29.0) + (id * 11) % 27, "phase": float((id * 53) % 100) / 100 * TAU, "amplitude": 0.14 + ability * 0.04 + float((id * 17) % 100) / 800}

	_styles[key] = value
	return value

static func position(mountain: RefCounted, piste: Dictionary, id: int, ability: int, fraction: float, run: int = 0, range_start: float = 0.0, range_end: float = 1.0) -> Vector2:
	var path: Dictionary = mountain.path_frame(piste.points, fraction, piste.length)
	var center: Vector2 = path.point
	var near: Vector2 = path.direction
	var personal := style(id, ability)
	var distance: float = piste.length * fraction
	var taper := smoothstep(0, 18, distance - piste.length * range_start) * smoothstep(0, 18, piste.length * range_end - distance)
	taper *= path.taper
	var width := float(piste.get("width", 20)) + (int(piste.get("level", 1)) - 1) * 4
	var lane := sin(id * 2.39 + run) * width * 0.08
	var wave := sin(distance / personal.wave * TAU + personal.phase + run * 1.7)
	var secondary := sin(distance / (personal.wave * 2.3) * TAU + id) * 0.17
	var lateral: float = ((wave + secondary) * width * personal.amplitude + lane) * taper
	return center + near.normalized().orthogonal() * clampf(lateral, -width * 0.43, width * 0.43)

static func frame(mountain: RefCounted, piste: Dictionary, id: int, ability: int, fraction: float, run: int = 0, range_start: float = 0.0, range_end: float = 1.0) -> Dictionary:
	var point := position(mountain, piste, id, ability, fraction, run, range_start, range_end)
	var before := position(mountain, piste, id, ability, maxf(0, fraction - 0.003), run, range_start, range_end)
	var ahead := position(mountain, piste, id, ability, minf(1, fraction + 0.003), run, range_start, range_end)
	var direction := (ahead - before).normalized()
	var personal := style(id, ability)
	return {"point": point, "before": before, "ahead": ahead, "direction": direction, "yaw": atan2(direction.x, direction.y), "lean": sin(piste.length * fraction / personal.wave * TAU + personal.phase + run * 1.7) * (0.13 + ability * 0.07)}

static func travel_profile(mountain: RefCounted, points: Array, ability: int) -> Dictionary:
	# A small deterministic longitudinal model: gravity and rolling resistance,
	# aerodynamic drag, skill-limited speed and braking before tight corners.
	# Speeds are metres per real second; one simulation minute takes two seconds.
	var length: float = mountain.polyline_length(points)
	var count := clampi(ceili(length / 8.0), 8, 128)
	var positions: Array[Vector3] = []
	var limits: Array[float] = []
	var caps := [7.5, 11.5, 15.0]
	for i in range(count + 1):
		var at: Vector2 = mountain.point_on_path(points, float(i) / count)
		positions.append(mountain.world(at))
		limits.append(caps[ability])
	for i in range(1, count):
		var incoming := (positions[i] - positions[i - 1]).normalized()
		var outgoing := (positions[i + 1] - positions[i]).normalized()
		var angle := acos(clampf(incoming.dot(outgoing), -1, 1))
		if angle > 0.035:
			var radius := positions[i].distance_to(positions[i - 1]) / maxf(angle, 0.01)
			limits[i] = minf(limits[i], maxf(2.0, sqrt(radius * [1.5, 2.2, 3.0][ability])))
	limits[-1] = minf(limits[-1], 3.0) # controlled arrival at a junction/plaza
	# Backward braking pass avoids reaching a hairpin at the straight-line cap.
	for i in range(count - 1, -1, -1):
		var distance := positions[i].distance_to(positions[i + 1])
		limits[i] = minf(limits[i], sqrt(limits[i + 1] * limits[i + 1] + 2 * 1.8 * distance))
	var speed := minf(2.5, limits[0])
	var seconds := 0.0
	var samples: Array = [[0.0, 0.0]]
	for i in range(1, count + 1):
		var delta := positions[i] - positions[i - 1]
		var distance := maxf(delta.length(), 0.01)
		var slope := -delta.y / distance
		var acceleration := 9.81 * slope - 0.20 - 0.012 * speed * speed
		# Skating keeps shallow traverses moving; there is no negative velocity.
		var next_speed := clampf(sqrt(maxf(4.0, speed * speed + 2 * acceleration * distance)), 2.0, limits[i])
		seconds += 2 * distance / maxf(speed + next_speed, 0.5)
		samples.append([seconds, float(i) / count])
		speed = next_speed
	for sample in samples:
		sample[0] /= maxf(seconds, 0.001)
	return {"minutes": maxf(0.15, seconds * 0.5), "samples": samples}

static func distance_progress(samples: Array, progress: float) -> float:
	var time := clampf(progress, 0, 1)
	if samples.is_empty():
		return time # existing 0.7 journeys retain their saved progression
	var low := 1
	var high := samples.size() - 1
	while low < high:
		var middle := (low + high) / 2
		if samples[middle][0] < time:
			low = middle + 1
		else:
			high = middle
	var a: Array = samples[low - 1]
	var b: Array = samples[low]
	return lerpf(a[1], b[1], clampf((time - a[0]) / maxf(b[0] - a[0], 0.000001), 0, 1))

static func valid_profile(value: Variant) -> bool:
	if not value is Array or value.size() > 129 or value.size() == 1:
		return false
	if value.is_empty():
		return true
	var previous := Vector2(-1, -1)
	for sample in value:
		if not sample is Array or sample.size() != 2 or not Terrain.number(sample[0]) or not Terrain.number(sample[1]):
			return false
		if sample[0] < 0 or sample[0] > 1 or sample[1] < 0 or sample[1] > 1 or sample[0] <= previous.x or sample[1] <= previous.y:
			return false
		previous = Vector2(sample[0], sample[1])
	return value[0] == [0.0, 0.0] and value[-1] == [1.0, 1.0]
