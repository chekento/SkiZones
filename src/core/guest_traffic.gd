extends RefCounted
## Conservative headway on a shared descent, evaluated once per simulated minute.
## The same progress is consumed by snow, renderer, selection and persistence.
const Motion = preload("res://src/core/ski_motion.gd")
const Snow = preload("res://src/core/snow_surface.gd")

static func _time_at(samples: Array, fraction: float) -> float:
	if samples.is_empty(): return fraction
	for i in range(1, samples.size()):
		if samples[i][1] >= fraction:
			return lerpf(samples[i - 1][0], samples[i][0], clampf((fraction - samples[i - 1][1]) / maxf(0.000001, samples[i][1] - samples[i - 1][1]), 0, 1))
	return 1.0

static func steps(model: RefCounted) -> Dictionary:
	var groups: Dictionary = {}
	for guest in model.guests:
		if guest.phase != "moving": continue
		var leg: Dictionary = guest.route.legs[guest.leg]
		if leg.kind != "ski": continue
		var piste: Dictionary = model.asset(leg.id)
		var lanes := clampi(floori(Snow.piste_width(piste) / 10), 1, 3)
		var key := "%d/%d" % [int(leg.id), posmod(int(guest.id), lanes)]
		if not groups.has(key): groups[key] = []
		groups[key].append({"guest": guest, "leg": leg, "at": model.ski_fraction(leg, guest.elapsed / guest.duration, guest.get("ski_motion", []))})
	var result: Dictionary = {}
	for group in groups.values():
		group.sort_custom(func(a, b): return a.at > b.at if not is_equal_approx(a.at, b.at) else int(a.guest.id) < int(b.guest.id))
		var ahead := INF
		for entry in group:
			var guest: Dictionary = entry.guest
			var leg: Dictionary = entry.leg
			var length: float = model.asset(leg.id).length
			var samples: Array = guest.get("ski_motion", leg.get("motion", []))
			var desired: float = model.ski_fraction(leg, (guest.elapsed + 1) / guest.duration, samples)
			var allowed := maxf(entry.at, minf(desired, ahead - 5 / maxf(length, 1)))
			var local := inverse_lerp(leg.get("start_fraction", 0.0), leg.get("end_fraction", 1.0), allowed)
			var elapsed: float = _time_at(samples, clampf(local, 0, 1)) * guest.duration
			result[int(guest.id)] = clampf(elapsed - guest.elapsed, 0, 1)
			ahead = allowed
	return result
