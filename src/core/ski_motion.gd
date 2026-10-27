extends RefCounted
## Stable personal styles. Drawing, tracks and local snow interaction use one path.
const Terrain = preload("res://src/core/terrain.gd")
const FIRST := ["Mila", "Jonas", "Lea", "Emil", "Nora", "Finn", "Lina", "Theo", "Ella", "Luis", "Amira", "Ben", "Sofia", "Paul", "Maja", "Noah"]
const COLORS := ["de8358", "438eaf", "bf6688", "d9b057", "6da490", "8d7eb3", "da605d", "77aaca"]

static func name_for(id: int) -> String:
	return FIRST[(id * 7) % FIRST.size()] + " " + String.chr(65 + (id * 13) % 26) + "."

static func style(id: int, ability: int) -> Dictionary:
	return {"name": [["Sanfte Bögen", "Ruhige Linie", "Weite Schwünge"], ["Runde Schwünge", "Kurze Schwünge", "Weite Bögen"], ["Sportliches Carven", "Kurze Radien", "Dynamische Bögen"]][ability][id % 3], "speed": [5.2, 7.5, 10.0][ability] * (0.86 + float((id * 37) % 100) / 350), "wave": (38.0 if ability == 0 else 29.0) + (id * 11) % 27, "phase": float((id * 53) % 100) / 100 * TAU, "amplitude": 0.14 + ability * 0.04 + float((id * 17) % 100) / 800}

static func position(mountain: RefCounted, piste: Dictionary, id: int, ability: int, fraction: float, run: int = 0, range_start: float = 0.0, range_end: float = 1.0) -> Vector2:
	var center: Vector2 = mountain.point_on_path(piste.points, fraction)
	var near: Vector2 = mountain.point_on_path(piste.points, minf(1, fraction + 0.006)) - mountain.point_on_path(piste.points, maxf(0, fraction - 0.006))
	var personal := style(id, ability)
	var distance: float = piste.length * fraction
	var taper := smoothstep(0, 18, distance - piste.length * range_start) * smoothstep(0, 18, piste.length * range_end - distance)
	taper *= mountain.corner_taper(piste.points, fraction, piste.length)
	var width := 20.0 + (int(piste.get("level", 1)) - 1) * 4
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
	return {"point": point, "direction": direction, "yaw": atan2(direction.x, direction.y), "lean": sin(piste.length * fraction / personal.wave * TAU + personal.phase + run * 1.7) * (0.13 + ability * 0.07)}
