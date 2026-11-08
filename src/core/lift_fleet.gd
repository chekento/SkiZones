extends RefCounted
## One physical vehicle/seat schedule is shared by simulation and rendering.
const Catalog = preload("res://src/core/catalog.gd")
const Terrain = preload("res://src/core/terrain.gd")
const TIME_SCALE := 30.0
const MAX_CARRIERS := 240
const SEAT_SPACING := 1.65

static func family(lift: Dictionary) -> String:
	return Catalog.LIFTS[lift.kind].family

static func seats(lift: Dictionary) -> int:
	return clampi(int(lift.get("occupancy", Catalog.LIFTS[lift.kind].seats)), 1, 64)

static func speed(lift: Dictionary) -> float:
	return Catalog.LIFTS[lift.kind].speed * (1.0 + 0.1 * (lift.get("level", 1) - 1))

static func capacity(lift: Dictionary) -> int:
	return roundi(float(lift.get("source_capacity", Catalog.LIFTS[lift.kind].capacity)) * (1.0 + 0.25 * (lift.get("level", 1) - 1)))

static func rope_offset(lift: Dictionary) -> float:
	if family(lift) == "drag":
		return 3.0
	if family(lift) == "gondola":
		return 5.5
	return maxf(3.5, seats(lift) * SEAT_SPACING * 0.5 + 2)

static func basis(lift: Dictionary) -> Basis:
	var direction := Terrain.unpack(lift.top) - Terrain.unpack(lift.bottom)
	return Basis(Vector3.UP, atan2(direction.x, direction.y))

static func layout(lift: Dictionary, time_scale: float = TIME_SCALE) -> Dictionary:
	var interval := 60.0 * time_scale * seats(lift) / capacity(lift)
	var ride: float = lift.length / speed(lift) * time_scale
	var turn := PI * rope_offset(lift) / speed(lift) * time_scale
	var travel := ride * 2 + turn * 2
	var count := clampi(ceili(travel / interval), 2, MAX_CARRIERS)
	return {"basis": basis(lift), "offset": rope_offset(lift), "interval": interval, "ride": ride, "turn": turn, "travel": travel, "count": count, "cycle": maxf(travel, count * interval), "seats": seats(lift)}

static func station_point(lift: Dictionary, top: bool) -> Vector2:
	var offset := basis(lift) * Vector3(-rope_offset(lift), 0, 0)
	return Terrain.unpack(lift.top if top else lift.bottom) + Vector2(offset.x, offset.z)

static func seat_offset(lift: Dictionary, seat: int) -> Vector3:
	if family(lift) == "gondola":
		if seats(lift) > 8:
			var rows := ceili(float(seats(lift)) / 6)
			return Vector3((seat % 6 - 2.5), 0.03, (int(seat / 6) - (rows - 1) * 0.5) * 2.6 / maxf(1, rows - 1))
		return Vector3((seat % 4 - 1.5) * 1.5, 0.03, -1.35 if seat < 4 else 1.35)
	return Vector3((seat - (seats(lift) - 1) * 0.5) * SEAT_SPACING, 0.03, 0)

static func pose(mountain: RefCounted, lift: Dictionary, profile: Dictionary, clock: float, carrier: int, prepared: Dictionary = {}) -> Dictionary:
	var schedule := layout(lift) if prepared.is_empty() else prepared
	var lift_family: String=family(lift)
	var phase := fposmod(clock - carrier * schedule.interval, schedule.cycle)
	if lift_family == "carpet":
		# A conveyor is an endless loop. The old clamped progress parked each
		# belt segment at the top for the entire return phase, then teleported
		# it to the bottom on wrap. At 4x/8x this looked like a stuck lift.
		# Keep the passenger-carrying uphill interval exactly unchanged; the
		# return travels below the terrain over rounded, continuous rollers.
		var bottom: Vector2 = Terrain.unpack(lift.bottom)
		var top: Vector2 = Terrain.unpack(lift.top)
		var travel: Vector2 = top - bottom
		var forward: Vector2 = travel.normalized()
		var radius: float = float(schedule.offset)
		var at: Vector2
		var height_offset := 0.65
		var belt_fraction := 0.0
		if phase < schedule.ride:
			belt_fraction = phase / schedule.ride
			at = bottom.lerp(top, belt_fraction)
		elif phase < schedule.ride + schedule.turn:
			belt_fraction = 1.0
			var angle: float = (phase - schedule.ride) / schedule.turn * PI
			at = top + forward * radius * sin(angle)
			height_offset -= radius * (1.0 - cos(angle))
		elif phase < schedule.cycle - schedule.turn:
			var return_duration: float = maxf(schedule.cycle - schedule.ride - schedule.turn * 2.0, 0.001)
			belt_fraction = 1.0 - clampf((phase - schedule.ride - schedule.turn) / return_duration, 0.0, 1.0)
			at = bottom.lerp(top, belt_fraction)
			height_offset -= 2.0 * radius
		else:
			var angle: float = (phase - schedule.cycle + schedule.turn) / schedule.turn * PI
			at = bottom - forward * radius * sin(angle)
			height_offset -= radius * (1.0 + cos(angle))
		var grip: Vector3 = mountain.world(at, height_offset)
		return {"transform": Transform3D(schedule.basis, grip), "grip": grip, "fraction": belt_fraction, "outbound": phase < schedule.ride, "phase": phase, "carrier": carrier}
	var r: float = schedule.offset
	var orientation: Basis = schedule.basis
	var direction := orientation * Vector3.FORWARD * -1
	var right := orientation.x
	var fraction := 0.0
	var outbound: bool = phase < schedule.ride
	var tangent := direction
	var grip: Vector3
	if phase < schedule.ride:
		fraction = phase / schedule.ride
		grip = _on_cable(profile, fraction) - right * r
	elif phase < schedule.ride + schedule.turn:
		fraction = 1
		var angle: float = (phase - schedule.ride) / schedule.turn * PI
		grip = profile.points[-1] + right * (-r * cos(angle)) + direction * (r * sin(angle))
		tangent = right * sin(angle) + direction * cos(angle)
	elif phase < schedule.ride * 2 + schedule.turn:
		fraction = 1 - (phase - schedule.ride - schedule.turn) / schedule.ride
		grip = _on_cable(profile, fraction) + right * r
		tangent = -direction
	else:
		var angle: float = clampf((phase - schedule.ride * 2 - schedule.turn) / schedule.turn, 0, 1) * PI
		grip = profile.points[0] + right * (r * cos(angle)) - direction * (r * sin(angle))
		tangent = -right * sin(angle) - direction * cos(angle)
	var yaw := atan2(tangent.x, tangent.z)
	var origin := grip - Vector3.UP * 6
	if lift_family == "drag":
		origin = mountain.world(Vector2(grip.x, grip.z), 1.15) if outbound else grip - Vector3.UP * 2.4
	elif lift_family == "carpet":
		origin = mountain.world(Vector2(grip.x, grip.z), 0.65)
	var body_basis := Basis(Vector3.UP, yaw)
	if lift_family == "gondola" and seats(lift) > 8: body_basis = body_basis.scaled(Vector3(1.15, 1, maxf(1, ceilf(float(seats(lift)) / 6) / 4)))
	return {"transform": Transform3D(body_basis, origin), "grip": grip, "fraction": fraction, "outbound": outbound, "phase": phase, "carrier": carrier}

static func _on_cable(profile: Dictionary, fraction: float) -> Vector3:
	var distance: float=profile.length*clampf(fraction,0.0,1.0)
	var last: int=profile.lengths.size()-1
	if last<=0:return profile.points[0]
	# All cumulative lengths are sorted. Binary interval search preserves the
	# exact original segment lerp but avoids scanning every tower span for every
	# moving chair/gondola at 1x, 4x and 8x.
	var low:=1
	var high: int=last
	while low<high:
		var mid: int=(low+high)/2
		if distance<=float(profile.lengths[mid]):high=mid
		else:low=mid+1
	return profile.points[low-1].lerp(profile.points[low],(distance-profile.lengths[low-1])/maxf(profile.lengths[low]-profile.lengths[low-1],0.001))


static func tow_point(mountain: RefCounted, pose: Dictionary) -> Vector3:
	var transform_value: Transform3D=pose.transform
	var taper := smoothstep(0,0.02,float(pose.fraction))*(1-smoothstep(0.98,1.0,float(pose.fraction)))
	var at: Vector3=transform_value.origin-transform_value.basis.z*(1.4*taper)
	return mountain.world(Vector2(at.x,at.z),0.15)
