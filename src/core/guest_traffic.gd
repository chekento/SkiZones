extends RefCounted
## Bounded per-piste overtaking: guests can change to a free snow lane
## rather than stopping every skier assigned to one permanent ID lane.
## Progress is deterministic; rendered skiing follows the same lane index.
const Motion = preload("res://src/core/ski_motion.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const MAX_LANES := 3
const LANE_METRES := 7.0
const HEADWAY_METRES := 3.5
const MIN_OVERTAKE_GAIN_METRES := 0.9

static func _time_at(samples: Array, fraction: float) -> float:
	if samples.is_empty(): return fraction
	for i in range(1, samples.size()):
		if samples[i][1] >= fraction:
			return lerpf(samples[i - 1][0], samples[i][0], clampf((fraction - samples[i - 1][1]) / maxf(0.000001, samples[i][1] - samples[i - 1][1]), 0, 1))
	return 1.0

static func lane_count(piste: Dictionary) -> int:
	# Every skier still requires sufficient side room to pass safely.
	return clampi(floori(Snow.piste_width(piste) / LANE_METRES), 1, MAX_LANES)

static func steps(model: RefCounted) -> Dictionary:
	var groups: Dictionary = {}
	var pistes: Dictionary = {}
	for guest in model.guests:
		if guest.phase != "moving" or guest.leg >= guest.route.legs.size(): continue
		var leg: Dictionary = guest.route.legs[guest.leg]
		if leg.kind != "ski": continue
		var piste: Dictionary = model.asset(int(leg.id))
		if piste.is_empty(): continue
		var key := int(leg.id)
		pistes[key] = piste
		if not groups.has(key): groups[key] = []
		groups[key].append({"guest": guest, "leg": leg, "at": model.ski_fraction(leg, guest.elapsed / maxf(guest.duration, 0.001), guest.get("ski_motion", []))})
	var result: Dictionary = {}
	for piste_id in groups:
		var piste: Dictionary = pistes[piste_id]
		var width: float = maxf(float(piste.get("length", 1)), 1.0)
		var number := lane_count(piste)
		var fronts: Array = []
		for lane in range(number): fronts.append(INF)
		var group: Array = groups[piste_id]
		group.sort_custom(func(a, b): return a.at > b.at if not is_equal_approx(a.at, b.at) else int(a.guest.id) < int(b.guest.id))
		for entry in group:
			var guest: Dictionary = entry.guest
			var leg: Dictionary = entry.leg
			var samples: Array = guest.get("ski_motion", leg.get("motion", []))
			var duration: float = maxf(float(guest.duration), 0.001)
			var current: float = clampf(float(entry.at), 0.0, 1.0)
			var desired: float = clampf(model.ski_fraction(leg, (float(guest.elapsed) + 1.0) / duration, samples), current, 1.0)
			var existing: int = int(guest.get("traffic_lane", posmod(int(guest.id), number)))
			if existing < 0 or existing >= number: existing = posmod(int(guest.id), number)
			var best_lane := existing
			var best_limit := maxf(current, minf(desired, float(fronts[existing]) - HEADWAY_METRES / width))
			# Two riders may advance abreast. Change lanes only for a meaningful
			# gain; a tiny distance difference must not oscillate the skier.
			for lane in range(number):
				if lane == existing: continue
				var allowed := maxf(current, minf(desired, float(fronts[lane]) - HEADWAY_METRES / width))
				if (allowed - best_limit) * width > MIN_OVERTAKE_GAIN_METRES:
					best_limit = allowed
					best_lane = lane
			# The render and save pipeline use metres of lateral separation.
			# Keep this consistent with ski_motion.gd and the Android picker.
			guest.traffic_lane = best_lane
			var width_metres: float = Snow.piste_width(piste)
			var lane_ratio: float = 0.0 if number <= 1 else (2.0 * float(best_lane) / float(number - 1) - 1.0)
			guest.traffic_lateral = clampf(lane_ratio * width_metres * 0.30, -24.0, 24.0)
			var local := inverse_lerp(float(leg.get("start_fraction", 0.0)), float(leg.get("end_fraction", 1.0)), best_limit)
			var elapsed: float = _time_at(samples, clampf(local, 0.0, 1.0)) * duration
			result[int(guest.id)] = clampf(elapsed - float(guest.elapsed), 0.0, 1.0)
			fronts[best_lane] = best_limit
	return result
