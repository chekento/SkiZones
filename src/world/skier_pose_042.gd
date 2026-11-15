extends RefCounted
## Rendering-only samples; simulation routes, clocks and saves remain authoritative.
const Motion = preload("res://src/core/ski_motion.gd")
const PisteFeatures = preload("res://src/core/piste_features.gd")

static func hiking(guest: Dictionary, leg: Dictionary, elapsed: float) -> bool:
	var samples: Array = guest.get("ski_motion", [])
	if samples.is_empty(): samples = leg.get("motion", [])
	return Motion.hiking(samples, elapsed / maxf(float(guest.duration), 0.001))

static func surface(terrain: RefCounted, ground: RefCounted, snow: RefCounted, piste: Dictionary, point: Vector2, fraction: float, ability: int) -> Vector3:
	# Each contact sample needs its own path normal and lateral coordinate:
	# a carving line can enter/leave a rotated narrow rail between samples.
	var path: Dictionary = terrain.path_frame(piste.points, fraction, piste.length)
	var lateral: float = (point - path.point).dot(path.direction.normalized().orthogonal())
	return ground.position(point, terrain.height(point), snow.height_offset(piste, point, fraction, lateral) - 0.05 + PisteFeatures.height_offset(piste, fraction, lateral, ability))

static func frame(model: RefCounted, ground: RefCounted, snow: RefCounted, piste: Dictionary, guest: Dictionary, leg: Dictionary, elapsed: float) -> Dictionary:
	var terrain: RefCounted = model.terrain
	var progress: float = clampf(elapsed / maxf(float(guest.duration), 0.001), 0, 1)
	var fraction: float = model.ski_fraction(leg, progress, guest.get("ski_motion", []))
	var start: float = leg.get("start_fraction", 0.0)
	var finish: float = leg.get("end_fraction", 1.0)
	var first: float = maxf(start, fraction - 0.003)
	var last: float = minf(finish, fraction + 0.003)
	var walking := hiking(guest, leg, elapsed)
	var sample: Dictionary
	if walking:
		# guest_position places a climbing guest on the piste centerline.
		# Never reuse a carving wave or park elevation in this state.
		sample = {"point":terrain.point_on_path(piste.points,fraction), "before":terrain.point_on_path(piste.points,first), "ahead":terrain.point_on_path(piste.points,last), "lean":0.0}
		var direction: Vector2 = sample.ahead - sample.before
		sample.yaw = atan2(direction.x,direction.y)
	else:
		sample = Motion.frame(terrain, piste, guest.id, guest.ability, fraction, guest.loops, start, finish, guest.get("walk_ranges", []), guest.get("sport", "ski"), float(guest.get("traffic_lateral", INF)))
		# Split piste legs must not tilt toward an untravelled adjoining part.
		if first > maxf(0.0,fraction-0.003): sample.before = Motion.position(terrain,piste,guest.id,guest.ability,first,guest.loops,start,finish,guest.get("walk_ranges",[]),guest.get("sport","ski"),float(guest.get("traffic_lateral",INF)))
		if last < minf(1.0,fraction+0.003): sample.ahead = Motion.position(terrain,piste,guest.id,guest.ability,last,guest.loops,start,finish,guest.get("walk_ranges",[]),guest.get("sport","ski"),float(guest.get("traffic_lateral",INF)))
		var direction: Vector2 = sample.ahead - sample.before
		sample.yaw = atan2(direction.x,direction.y)
	var skill: int = 0 if walking else int(guest.ability)
	var before := surface(terrain,ground,snow,piste,sample.before,first,skill)
	var ahead := surface(terrain,ground,snow,piste,sample.ahead,last,skill)
	return {"position":surface(terrain,ground,snow,piste,sample.point,fraction,skill), "yaw":sample.yaw, "lean":sample.lean, "pitch":atan2(before.y-ahead.y,Vector2(ahead.x-before.x,ahead.z-before.z).length())}
