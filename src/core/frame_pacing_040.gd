extends RefCounted
## Presentation pacing never changes the underlying save-game clock. When
## CPU work is over budget, keep the display at the end of the completed tick
## instead of wrapping to a younger fractional phase (visible lift rewind).
const MAX_FRAME_DELTA := 0.25

static func rate(speed: int, time_divisor: int, daylight_factor: float) -> float:
	if speed not in [1,4,8] or not is_finite(daylight_factor):
		return 0.0
	return float(speed) * (4.0 if time_divisor>1 else 1.0) * maxf(0.0,daylight_factor)

static func add_debt(debt: float, frame_delta: float, speed: int, time_divisor: int, daylight_factor: float, minutes_per_second: float) -> float:
	var safe_delta: float=clampf(frame_delta,0.0,MAX_FRAME_DELTA) if is_finite(frame_delta) else 0.0
	return maxf(0.0,debt)+safe_delta*rate(speed,time_divisor,daylight_factor)*maxf(0.0,minutes_per_second)

static func presentation_fraction(debt: float) -> float:
	# fmod(debt, 1) causes a visible backward leap when >1 tick is owed
	# and the 6ms simulation budget was exhausted. Clamp, don't wrap.
	return clampf(debt,0.0,1.0) if is_finite(debt) else 0.0

static func speed_change_debt(debt: float) -> float:
	# Discard stale catch-up, but never reverse an already-rendered frame.
	return minf(presentation_fraction(debt),1.0-0.000001)
