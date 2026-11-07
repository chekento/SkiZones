extends RefCounted
## Bounded per-piste overtaking: guests can change to a free snow lane
## rather than stopping every skier assigned to one permanent ID lane.
## Progress is deterministic; rendered skiing follows the same lane index.
const Motion = preload("res://src/core/ski_motion.gd")
const Snow = preload("res://src/core/snow_surface.gd")
# Use the actual piste width: broad snow corridors support parallel tracks.
# The 0.21 three-lane cap made long, visible columns in popular resorts.
const MAX_LANES := 8
const LANE_METRES := 3.7 # clear physical passing corridors, including 10m narrow pistes
const EDGE_BUFFER_METRES := 1.0
const HEADWAY_METRES := 2.4
const MIN_OVERTAKE_GAIN_METRES := 0.55

static func _time_at(samples: Array, fraction: float) -> float:
	if samples.is_empty(): return fraction
	for i in range(1, samples.size()):
		if samples[i][1] >= fraction:
			return lerpf(samples[i - 1][0], samples[i][0], clampf((fraction - samples[i - 1][1]) / maxf(0.000001, samples[i][1] - samples[i - 1][1]), 0, 1))
	return 1.0

static func lane_count(piste: Dictionary) -> int:
	# Every skier still requires sufficient side room to pass safely.
	return clampi(floori(maxf(0.0, Snow.piste_width(piste)-2.0*EDGE_BUFFER_METRES) / LANE_METRES), 1, MAX_LANES)

static func load_by_piste(model: RefCounted) -> Dictionary:
	# Count users currently on each descent and those about to start it.
	# Route choice uses this to spread guests over alternative runs without
	# ever rejecting the sole accessible route.
	var load: Dictionary = {}
	for guest in model.guests:
		if guest.phase == "leaving" or not guest.has("route"): continue
		var plan: Array = guest.route.get("legs", [])
		for index in range(int(guest.get("leg",0)),plan.size()):
			var leg: Dictionary = plan[index]
			if leg.kind == "ski":
				var key: int = int(leg.id)
				load[key] = int(load.get(key,0)) + int(guest.get("group_size",1))
				break
	return load

static func route_pressure(model: RefCounted, piste: Dictionary, counts: Dictionary) -> float:
	if piste.is_empty(): return 1.0
	var lanes := lane_count(piste)
	var metres := maxf(float(piste.get("length",1.0)),30.0)
	var capacity: float = maxf(1.0, lanes * metres / 17.0)
	var density: float = float(counts.get(int(piste.id),0)) / capacity
	# Modest penalty below capacity, strong diversion when critically loaded.
	# Keep minimum weight for isolated routes and returning guests.
	return clampf(1.0 / (1.0 + 3.4 * density * density),0.07,1.0)

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
			# Fixed metre-based corridors match overtaking safety requirements.
			# Proportional offsets previously squeezed many wide-piste lanes
			# into the same few visible metres, forming stacked rows.
			guest.traffic_lateral = clampf((float(best_lane) - float(number - 1) * 0.5) * LANE_METRES, -width_metres * 0.43, width_metres * 0.43)
			var local := inverse_lerp(float(leg.get("start_fraction", 0.0)), float(leg.get("end_fraction", 1.0)), best_limit)
			var elapsed: float = _time_at(samples, clampf(local, 0.0, 1.0)) * duration
			result[int(guest.id)] = clampf(elapsed - float(guest.elapsed), 0.0, 1.0)
			fronts[best_lane] = best_limit
	return result
