extends RefCounted
## Bounded local deformation: skis compact troughs and push snow into shoulders.
const Terrain = preload("res://src/core/terrain.gd")
const Motion = preload("res://src/core/ski_motion.gd")
const LANES := 8
const STEP := 8.0
const MAX_TRACKS := 64

static func piste_width(piste: Dictionary) -> float:
	return float(piste.get("width", 20)) + (int(piste.get("level", 1)) - 1) * 4

static func base_height(piste: Dictionary, fraction: float) -> float:
	var blend := 1.0
	if piste.get("plaza_start", false):
		blend *= smoothstep(0, 20, fraction * piste.length)
	if piste.get("plaza_end", false):
		blend *= smoothstep(0, 20, (1 - fraction) * piste.length)
	return lerpf(0.37, 1.3, blend)

static func mesh_height(piste: Dictionary, fraction: float, lateral: float) -> float:
	var count := ceili(piste.length / 4)
	var at := clampf(fraction, 0, 1) * count
	var lower := mini(count - 1, floori(at))
	return lerpf(base_height(piste, float(lower) / count), base_height(piste, float(lower + 1) / count), at - lower) + mesh_relief(piste, fraction, lateral)

static func rows(piste: Dictionary) -> int:
	return ceili(piste.length / STEP) + 1

static func ensure(piste: Dictionary) -> void:
	var size_value := rows(piste) * (LANES + 1)
	if not piste.has("surface") or piste.surface.size() != size_value:
		piste.surface = []
		piste.surface.resize(size_value)
		piste.surface.fill(0.0)
	if not piste.has("tracks"):
		piste.tracks = []

static func migrate_length(piste: Dictionary, new_length: float) -> bool:
	# Moving old endpoints out of a terminal preserves the local snow history.
	if not piste.has("surface"):
		piste.length = new_length
		return true
	if not piste.surface is Array or piste.surface.size() % (LANES + 1) != 0 or piste.surface.size() < (LANES + 1) * 2:
		return false
	for value in piste.surface:
		if not Terrain.number(value) or value < -0.35 or value > 0.6:
			return false
	var previous: Array = piste.surface
	var old_rows := previous.size() / (LANES + 1)
	piste.length = new_length
	var result: Array = []
	var count := rows(piste)
	for row in range(count):
		var at := float(row) / maxf(1, count - 1) * (old_rows - 1)
		var lower := floori(at)
		var upper := mini(old_rows - 1, lower + 1)
		for lane in range(LANES + 1):
			result.append(lerpf(previous[lower * (LANES + 1) + lane], previous[upper * (LANES + 1) + lane], at - lower))
	piste.surface = result
	return true

static func start(piste: Dictionary, guest: Dictionary, from_fraction: float = 0.0, end_fraction: float = 1.0) -> void:
	ensure(piste)
	var key := "%d:%d:%d:%d" % [guest.id, guest.loops, guest.leg, guest.age]
	guest.track = key
	piste.tracks.append({"key": key, "guest": int(guest.id), "ability": int(guest.ability), "run": int(guest.loops), "from": from_fraction, "until": end_fraction, "to": from_fraction})
	if piste.tracks.size() > MAX_TRACKS:
		piste.tracks.pop_front()

static func touch(mountain: RefCounted, piste: Dictionary, guest: Dictionary, from_fraction: float, to_fraction: float) -> void:
	ensure(piste)
	piste.surface_revision = int(piste.get("surface_revision", 0)) + 1
	var range_start := 0.0
	var range_end := 1.0
	for track in piste.tracks:
		if track.key == guest.get("track", ""):
			range_start = track.get("from", 0.0)
			range_end = track.get("until", 1.0)
			track.to = maxf(track.to, to_fraction)
	var first := floori(from_fraction * piste.length / STEP)
	var last := floori(to_fraction * piste.length / STEP)
	var width := piste_width(piste)
	for row in range(first + 1, mini(last + 1, rows(piste))):
		var fraction: float = row * STEP / piste.length
		var center: Vector2 = mountain.point_on_path(piste.points, fraction)
		var ahead: Vector2 = mountain.point_on_path(piste.points, minf(1, fraction + 0.005))
		var point := Motion.position(mountain, piste, guest.id, guest.ability, fraction, guest.loops, range_start, range_end)
		var lateral := (point - center).dot((ahead - center).normalized().orthogonal())
		var lane := clampi(roundi((lateral / width + 0.5) * LANES), 1, LANES - 1)
		var index := row * (LANES + 1) + lane
		var amount: float = 0.024 + guest.ability * 0.009
		piste.surface[index] = maxf(-0.34, piste.surface[index] - amount)
		for side in [-1, 1]:
			piste.surface[index + side] = minf(0.58, piste.surface[index + side] + amount * 0.65)
		piste.snow = maxf(0, piste.snow - 0.0008)

static func relief(piste: Dictionary, fraction: float, lateral: float) -> float:
	if not piste.has("surface") or piste.surface.is_empty():
		return 0
	var width := piste_width(piste)
	var r := clampf(fraction * piste.length / STEP, 0, rows(piste) - 1.001)
	var l := clampf((lateral / width + 0.5) * LANES, 0, LANES - 0.001)
	var row := floori(r)
	var lane := floori(l)
	var a: float = lerpf(piste.surface[row * (LANES + 1) + lane], piste.surface[row * (LANES + 1) + lane + 1], fmod(l, 1))
	var b: float = lerpf(piste.surface[(row + 1) * (LANES + 1) + lane], piste.surface[(row + 1) * (LANES + 1) + lane + 1], fmod(l, 1))
	return lerpf(a, b, fmod(r, 1))

static func roughness(piste: Dictionary) -> float:
	if not piste.has("surface") or piste.surface.is_empty():
		return 0
	var total := 0.0
	for value in piste.surface:
		total += absf(value)
	return clampf(total / piste.surface.size() * 5, 0, 1)

static func mesh_relief(piste: Dictionary, fraction: float, lateral: float) -> float:
	# Match the triangles used by the visible snow, keeping skis and traces in contact.
	var count := ceili(piste.length / 4)
	var width := piste_width(piste)
	var r := clampf(fraction * count, 0, count - 0.0001)
	var l := clampf((lateral / width + 0.5) * LANES, 0, LANES - 0.0001)
	var row := floori(r)
	var lane := floori(l)
	var u := fmod(l, 1)
	var v := fmod(r, 1)
	var x0 := (float(lane) / LANES - 0.5) * width
	var x1 := (float(lane + 1) / LANES - 0.5) * width
	var a := relief(piste, float(row) / count, x0)
	var b := relief(piste, float(row) / count, x1)
	var c := relief(piste, float(row + 1) / count, x0)
	var d := relief(piste, float(row + 1) / count, x1)
	return a * (1 - u - v) + b * u + c * v if u + v <= 1 else d * (u + v - 1) + c * (1 - u) + b * (1 - v)

static func groom(piste: Dictionary, strength: float) -> void:
	ensure(piste)
	piste.surface_revision = int(piste.get("surface_revision", 0)) + 1
	for i in range(piste.surface.size()):
		piste.surface[i] *= 1.0 - clampf(strength, 0, 1)
	piste.tracks.clear()

static func validate(piste: Dictionary) -> bool:
	if not piste.has("surface"):
		ensure(piste)
	if not piste.surface is Array or piste.surface.size() != rows(piste) * (LANES + 1) or not piste.get("tracks") is Array or piste.tracks.size() > MAX_TRACKS:
		return false
	for value in piste.surface:
		if not (value is int or value is float) or not is_finite(value) or value < -0.35 or value > 0.6:
			return false
	for track in piste.tracks:
		if not track is Dictionary or not track.get("key") is String or track.key.length() > 80:
			return false
		if not Terrain.number(track.get("to")):
			return false
		if not Terrain.number(track.get("from", 0)) or track.get("from", 0) < 0 or track.get("from", 0) > track.get("to", -1):
			return false
		if not Terrain.number(track.get("until", 1)) or track.get("until", 1) > 1 or track.get("until", 1) < track.get("to", -1):
			return false
		for key in ["guest", "ability", "run", "to"]:
			var value: Variant = track.get(key)
			if not (value is int or value is float) or not is_finite(value) or value < 0 or value > (1 if key == "to" else (2 if key == "ability" else 1000000000)):
				return false
			if key != "to":
				if value != floorf(value):
					return false
				track[key] = int(value)
	return true
