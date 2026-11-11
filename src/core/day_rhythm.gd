extends RefCounted
## Wall-clock pacing scales the entire simulation together, preserving trips,
## needs, queues and wages per game minute in existing saves.
const PRESETS := ["balanced", "compact", "cozy"]
const DAY_SPEED := {"balanced":1.8, "compact":2.2, "cozy":1.35}
const QUIET_FROM := 1200 # 20:00, but only after every visible outdoor trip is safely complete
const INDOOR := ["hotel", "grand_hotel", "guesthouse", "cabin", "apartment", "chalet", "restaurant", "pizzeria", "lodge", "cocoa", "schmarrn", "disco", "bar", "rental", "souvenir", "watchmaker", "craftshop", "fitness", "printing_press", "newsstand", "first_aid"]

static func playback(minute: int, preset: String = "balanced") -> float:
	# Keep an unhurried 17–22h evening after the shorter skiing day.
	return 1.0 if minute >= 1020 and minute < QUIET_FROM else float(DAY_SPEED.get(preset, 1.8))

## Only foot traffic to a real exit/overnight/after-ski destination can be
## safely accelerated. Every remaining leg must be a walk or indoor visit:
## never fast-forward a skier, lift rider, queue, rescue or lost NPC.
## Starting the safe-night check at 20:00 does NOT force those trips to finish.
static func _safe_foot_destination(model: RefCounted, guest: Dictionary) -> bool:
	if not guest.has("route") or not guest.route is Dictionary: return false
	var legs: Array = guest.route.get("legs", [])
	var index: int = int(guest.get("leg", -1))
	if index < 0 or index >= legs.size(): return false
	var last: Dictionary = legs.back()
	var going_home: bool = str(last.get("to", "")) == "base"
	var going_to_service: bool = bool(guest.get("evening", false)) or bool(guest.get("hotel_night", false)) or bool(guest.get("night_out", false))
	if not (going_home or going_to_service or bool(guest.get("heading_home", false))): return false
	for i in range(index, legs.size()):
		var leg: Dictionary = legs[i]
		if leg.get("kind", "") == "walk": continue
		if leg.get("kind", "") != "visit": return false
		if str(model.asset(int(leg.get("id", 0))).get("kind", "")) not in INDOOR: return false
	return true

static func indoors_only(model: RefCounted) -> bool:
	# A casualty cannot be silently fast-forwarded simply because the
	# associated visitor was temporarily removed during a save migration.
	if model.operations.get("incidents",[]).any(func(e):return str(e.get("status",""))!="resolved"):return false
	var now: int = model.Ops.clock(model)
	for guest in model.guests:
		if int(guest.get("incident", -1)) >= 0: return false
		if guest.phase == "leaving": continue
		if guest.phase == "waiting" and guest.get("waiting_reason", "") == "hotel" and int(guest.get("hotel_sleep_until", 0)) > now: continue
		if guest.phase != "moving" or int(guest.leg) >= guest.route.legs.size(): return false
		var leg: Dictionary = guest.route.legs[int(guest.leg)]
		if leg.kind == "visit" and str(model.asset(int(leg.id)).get("kind", "")) in INDOOR: continue
		if leg.kind == "walk" and _safe_foot_destination(model, guest): continue
		return false
	return true

static func quiet_night(model: RefCounted) -> bool:
	return model.time_divisor > 1 and model.Ops.continuous(model) and (int(model.minute) < int(model.OPENING) or int(model.minute) >= QUIET_FROM) and indoors_only(model)

