extends RefCounted
## Presentation pacing never changes the underlying save-game clock. When
## CPU work is over budget, keep the display at the end of the completed tick
## instead of wrapping to a younger fractional phase (visible lift rewind).
const MAX_FRAME_DELTA := 0.25
# Rebuilding procedural skies and changing particle budgets on every game-minute
# tick costs GPU time at 4x/8x. Update lighting at most five times per real
# second while retaining immediate weather/style/day changes.
const ATMOSPHERE_MIN_USEC := 200000

static func atmosphere_due(environment_changed: bool, last_usec: int, now_usec: int) -> bool:
	return environment_changed or last_usec <= 0 or now_usec < last_usec or now_usec - last_usec >= ATMOSPHERE_MIN_USEC

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

static func ski_sample_interval(motion_rate: float, time_divisor: int) -> float:
	# For off-camera skiers, interpolate every display frame but sample
	# expensive terrain/path geometry at approximately 30 Hz or less.
	# The old fixed 0.40-tick interval at 8x + compact days could advance
	# more than one cache cell PER FRAME and recompute two exact positions
	# for hundreds of visitors on budget Android phones.
	# The following tracked skier still uses the exact path on every frame.
	var base: float=4.0 if time_divisor>1 else 1.0
	var playback_speed: float=maxf(0.0,motion_rate)/base
	var minimum: float=0.40 if playback_speed>=6.0 else 0.24 if playback_speed>=2.0 else 0.12
	var ticks_per_30hz_sample: float=maxf(0.0,motion_rate)*0.5/30.0
	return maxf(minimum,ticks_per_30hz_sample)
