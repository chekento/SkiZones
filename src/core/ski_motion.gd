extends RefCounted
## Stable personal styles. Drawing, tracks and local snow interaction use one path.
const Terrain = preload("res://src/core/terrain.gd")
const FIRST := ["Mila", "Jonas", "Lea", "Emil", "Nora", "Finn", "Lina", "Theo", "Ella", "Luis", "Amira", "Ben", "Sofia", "Paul", "Maja", "Noah"]
const COLORS := ["de8358", "438eaf", "bf6688", "d9b057", "6da490", "8d7eb3", "da605d", "77aaca"]
const SPORTS := ["ski", "snowboard", "snowblade"]
const SPORT_NAMES := {"ski":"Ski", "snowboard":"Snowboard", "snowblade":"Snowblades"}

static func sport_for(id: int) -> String:
	return SPORTS[posmod(id, SPORTS.size())]

static func name_for(id: int) -> String:
	return FIRST[(id * 7) % FIRST.size()] + " " + String.chr(65 + (id * 13) % 26) + "."

static var _styles: Dictionary = {}

static func style(id: int, ability: int, sport: String = "ski") -> Dictionary:
	var key := "%d/%s" % [(id % 2700) * 3 + ability, sport]
	if _styles.has(key):
		return _styles[key]
	var value := {"name": [["Sanfte Bögen", "Ruhige Linie", "Weite Schwünge"], ["Runde Schwünge", "Kurze Schwünge", "Weite Bögen"], ["Sportliches Carven", "Kurze Radien", "Dynamische Bögen"]][ability][id % 3], "speed": [5.2, 7.5, 10.0][ability] * (0.86 + float((id * 37) % 100) / 350), "wave": (38.0 if ability == 0 else 29.0) + (id * 11) % 27, "phase": float((id * 53) % 100) / 100 * TAU, "amplitude": 0.14 + ability * 0.04 + float((id * 17) % 100) / 800}

	if sport == "snowboard":
		value.name = ["Ruhige Boardbögen", "Flüssige Boardkurven", "Sportliches Boardcarven"][ability]
		value.speed *= 0.98
		value.wave *= 1.08
	elif sport == "snowblade":
		value.name = ["Kurze sanfte Bögen", "Wendige Kurzschwünge", "Dynamische Kurzski"][ability]
		value.speed *= 0.90
		value.wave *= 0.72
	_styles[key] = value
	return value

static func position(mountain: RefCounted, piste: Dictionary, id: int, ability: int, fraction: float, run: int = 0, range_start: float = 0.0, range_end: float = 1.0, walks: Array = [], sport: String = "ski") -> Vector2:
	var path: Dictionary = mountain.path_frame(piste.points, fraction, piste.length)
	var center: Vector2 = path.point
	var near: Vector2 = path.direction
	var personal := style(id, ability, sport)
	var distance: float = piste.length * fraction
	var taper := smoothstep(0, 18, distance - piste.length * range_start) * smoothstep(0, 18, piste.length * range_end - distance)
	taper *= path.taper
	for r in walks:
		var gap: float = maxf(maxf(r[0]-fraction,fraction-r[1]),0)*piste.length
		taper *= smoothstep(0,10,gap)
	var width := float(piste.get("width", 20)) + (int(piste.get("level", 1)) - 1) * 4
	var lane := sin(id * 2.39 + run) * width * 0.08
	var wave := sin(distance / personal.wave * TAU + personal.phase + run * 1.7)
	var secondary := sin(distance / (personal.wave * 2.3) * TAU + id) * 0.17
	var lateral: float = ((wave + secondary) * width * personal.amplitude + lane) * taper
	return center + near.normalized().orthogonal() * clampf(lateral, -width * 0.43, width * 0.43)

static func frame(mountain: RefCounted, piste: Dictionary, id: int, ability: int, fraction: float, run: int = 0, range_start: float = 0.0, range_end: float = 1.0, walks: Array = [], sport: String = "ski") -> Dictionary:
	var point := position(mountain, piste, id, ability, fraction, run, range_start, range_end, walks, sport)
	var before := position(mountain, piste, id, ability, maxf(0, fraction - 0.003), run, range_start, range_end, walks, sport)
	var ahead := position(mountain, piste, id, ability, minf(1, fraction + 0.003), run, range_start, range_end, walks, sport)
	var direction := (ahead - before).normalized()
	var personal := style(id, ability, sport)
	return {"point": point, "before": before, "ahead": ahead, "direction": direction, "yaw": atan2(direction.x, direction.y), "lean": sin(piste.length * fraction / personal.wave * TAU + personal.phase + run * 1.7) * (0.13 + ability * 0.07)}

const Dynamics = preload("res://src/core/ski_dynamics.gd")

static func travel_profile(mountain: RefCounted, points: Array, ability: int, personal: float = 1.0, roughness: float = 0.0) -> Dictionary:
	return Dynamics.profile(mountain,points,ability,personal,roughness)

static func hiking(samples: Array, progress: float) -> bool:
	if samples.is_empty(): return false
	var low := 1
	var high := samples.size()-1
	var time := clampf(progress,0,1)
	while low < high:
		var mid := (low+high)/2
		if samples[mid][0] < time: low = mid+1
		else: high = mid
	return samples[low].size() > 2 and samples[low][2] == 1

static func walk_ranges(samples: Array, start: float, finish: float) -> Array:
	var ranges: Array = []
	for i in range(1,samples.size()):
		if samples[i].size() < 3 or samples[i][2] != 1: continue
		var a := lerpf(start,finish,samples[i-1][1])
		var b := lerpf(start,finish,samples[i][1])
		if not ranges.is_empty() and is_equal_approx(ranges[-1][1],a): ranges[-1][1] = b
		else: ranges.append([a,b])
	return ranges

static func in_walk_range(ranges: Array, fraction: float) -> bool:
	for r in ranges:
		if fraction >= r[0] and fraction <= r[1]: return true
	return false

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
	if not value is Array or value.size() > 1025 or value.size() == 1:
		return false
	if value.is_empty():
		return true
	var previous := Vector2(-1, -1)
	for sample in value:
		if not sample is Array or sample.size() not in [2,4] or not Terrain.number(sample[0]) or not Terrain.number(sample[1]):
			return false
		if sample[0] < 0 or sample[0] > 1 or sample[1] < 0 or sample[1] > 1 or sample[0] <= previous.x or sample[1] <= previous.y:
			return false
		if sample.size() == 4 and (not Terrain.number(sample[2]) or (sample[2] != 0 and sample[2] != 1) or not Terrain.number(sample[3]) or sample[3] < 0 or sample[3] > 30): return false
		previous = Vector2(sample[0],sample[1])
	return value[0][0] == 0 and value[0][1] == 0 and value[-1][0] == 1 and value[-1][1] == 1
