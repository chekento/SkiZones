extends RefCounted
## Per-piste collision avoidance with passing lanes. Progress remains monotonic;
## an individual guest who pauses cannot freeze all skiers behind them.
const Motion = preload("res://src/core/ski_motion.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const HEADWAY_METRES := 5.5
const PASS_ADVANTAGE_METRES := 1.8

static func _time_at(samples: Array, fraction: float) -> float:
	if samples.is_empty(): return fraction
	for i in range(1, samples.size()):
		if samples[i][1] >= fraction:
			return lerpf(samples[i - 1][0], samples[i][0], clampf((fraction - samples[i - 1][1]) / maxf(0.000001, samples[i][1] - samples[i - 1][1]), 0, 1))
	return 1.0

static func _lanes(piste: Dictionary) -> int:
	var width: float = Snow.piste_width(piste)
	return 1 if width < 14.0 else clampi(floori(width / 8.0), 2, 3)

static func _lateral(width: float, lanes: int, lane: int) -> float:
	if lanes <= 1: return 0.0
	return (float(lane) - float(lanes - 1) * 0.5) * minf(5.5, width * 0.24)

static func steps(model: RefCounted) -> Dictionary:
	var groups: Dictionary = {}
	for guest in model.guests:
		if guest.phase != "moving" or guest.get("incident", -1) >= 0: continue
		if guest.leg >= guest.route.legs.size(): continue
		var leg: Dictionary = guest.route.legs[guest.leg]
		if leg.kind != "ski": continue
		var piste: Dictionary = model.asset(int(leg.id))
		if piste.is_empty(): continue
		var key := int(leg.id)
		if not groups.has(key): groups[key] = []
		var duration: float = maxf(float(guest.get("duration", leg.minutes)), 0.001)
		var samples: Array = guest.get("ski_motion", leg.get("motion", []))
		groups[key].append({"guest": guest, "leg": leg, "samples": samples, "duration": duration,
			"at": model.ski_fraction(leg, guest.elapsed / duration, samples)})
	var result: Dictionary = {}
	for piste_id in groups:
		var piste: Dictionary = model.asset(int(piste_id))
		var length: float = maxf(float(piste.length), 1.0)
		var width: float = Snow.piste_width(piste)
		var lane_count: int = _lanes(piste)
		var lane_front: Array = []
		for lane in range(lane_count): lane_front.append(2.0)
		var group: Array = groups[piste_id]
		group.sort_custom(func(a, b): return a.at > b.at if not is_equal_approx(a.at, b.at) else int(a.guest.id) < int(b.guest.id))
		for entry in group:
			var guest: Dictionary = entry.guest
			var leg: Dictionary = entry.leg
			var samples: Array = entry.samples
			var at: float = entry.at
			var desired: float = model.ski_fraction(leg, (guest.elapsed + 1.0) / entry.duration, samples)
			var preferred: int = posmod(int(guest.id), lane_count)
			var current: int = clampi(int(guest.get("traffic_lane", preferred)), 0, lane_count - 1)
			var selected: int = current
			var safe: float = maxf(at, minf(desired, float(lane_front[current]) - HEADWAY_METRES / length))
			for candidate in range(lane_count):
				if candidate == current: continue
				var alternate: float = maxf(at, minf(desired, float(lane_front[candidate]) - HEADWAY_METRES / length))
				# Change lanes only when actually useful; avoid frame-to-frame
				# weaving between neighbors whose headways differ by centimetres.
				if (alternate - safe) * length > PASS_ADVANTAGE_METRES:
					selected = candidate
					safe = alternate
			# A waiting group occupies one lane, never the entire ski run.
			lane_front[selected] = safe
			var local: float = inverse_lerp(float(leg.get("start_fraction", 0.0)), float(leg.get("end_fraction", 1.0)), safe)
			var elapsed: float = _time_at(samples, clampf(local, 0.0, 1.0)) * entry.duration
			result[int(guest.id)] = clampf(elapsed - guest.elapsed, 0.0, 1.0)
			guest.traffic_lane = selected
			var goal: float = _lateral(width, lane_count, selected)
			# Smooth lateral motion is a visual/physical lane shift, not a
			# teleport across the piste in a single simulation tick.
			guest.traffic_lateral = move_toward(float(guest.get("traffic_lateral", goal)), goal, 1.35)
	return result
