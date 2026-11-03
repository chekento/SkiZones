extends RefCounted
## Wall-clock pacing scales the entire simulation together, preserving trips,
## needs, queues and wages per game minute in existing saves.
const PRESETS := ["balanced", "compact", "cozy"]
const DAY_SPEED := {"balanced":1.8, "compact":2.2, "cozy":1.35}
const QUIET_FROM := 1320
const INDOOR := ["hotel", "grand_hotel", "guesthouse", "cabin", "apartment", "chalet", "restaurant", "pizzeria", "lodge", "cocoa", "schmarrn", "disco", "bar", "rental"]

static func playback(minute: int, preset: String = "balanced") -> float:
	# Keep an unhurried 17–22h evening after the shorter skiing day.
	return 1.0 if minute >= 1020 and minute < QUIET_FROM else float(DAY_SPEED.get(preset, 1.8))

static func indoors_only(model: RefCounted) -> bool:
	var now: int = model.Ops.clock(model)
	for guest in model.guests:
		if int(guest.get("incident", -1)) >= 0: return false
		if guest.phase == "leaving": continue
		if guest.phase == "waiting" and guest.get("waiting_reason", "") == "hotel" and int(guest.get("hotel_sleep_until", 0)) > now: continue
		if guest.phase != "moving" or int(guest.leg) >= guest.route.legs.size(): return false
		var leg: Dictionary = guest.route.legs[int(guest.leg)]
		if leg.kind != "visit" or str(model.asset(int(leg.id)).get("kind", "")) not in INDOOR: return false
	return true

static func quiet_night(model: RefCounted) -> bool:
	return model.time_divisor > 1 and model.Ops.continuous(model) and (int(model.minute) < int(model.OPENING) or int(model.minute) >= QUIET_FROM) and indoors_only(model)
