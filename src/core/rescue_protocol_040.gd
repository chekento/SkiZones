extends RefCounted
## 0.40 rescue timeline: crews travel as two skiers on the actual route,
## bring a folded stretcher, transport injuries back and treat for 1–2h.
## Fear of a difficult descent is guidance, NOT a stretcher evacuation.
const Terrain=preload("res://src/core/terrain.gd")
const MOBILE_STAGES:=["responding","transporting","guiding"]
const ACTIVE_STAGES:=["waiting","responding","transporting","guiding","treating"]

static func needs_stretcher(reason: String) -> bool:
	return reason!="navigation"

static func treatment_minutes(event: Dictionary) -> int:
	# Stable after save/load and independent of wall clock and frame rate.
	return 60+(int(event.get("id",0))*17+int(event.get("guest",0))*31)%61

static func return_minutes(event: Dictionary) -> float:
	var response:float=maxf(1.0,float(event.get("response_duration",10.0)))
	return maxf(5.0,response*(0.80 if event.get("transport_mode","skis")=="snowcat" else 1.14))

static func start_after_arrival(event: Dictionary) -> void:
	if not needs_stretcher(str(event.get("reason","fatigue"))):
		event.status="guiding"
		event.stage_duration=maxf(8.0,float(event.get("response_duration",10.0))*1.1)
	else:
		event.status="transporting"
		event.stage_duration=return_minutes(event)
	event.remaining=float(event.stage_duration)

## Returns true only once when the patient is fully released.
static func tick(event: Dictionary) -> bool:
	if event.get("status","") not in ["responding","transporting","guiding","treating"]:return false
	event.remaining=maxf(0.0,float(event.remaining)-1.0)
	if event.remaining>0.0:return false
	match str(event.status):
		"responding":
			start_after_arrival(event)
			return false
		"transporting":
			event.status="treating"
			event.stage_duration=float(treatment_minutes(event))
			event.remaining=float(event.stage_duration)
			return false
		"guiding","treating":
			event.status="resolved"
			event.remaining=0.0
			return true
	return false

static func route_position(event: Dictionary) -> Vector2:
	var points: Array=event.get("route_points",[])
	if points.size()<2:return Terrain.unpack(event.get("point",[0.0,0.0]))
	var total:=0.0
	for i in range(1,points.size()):
		total+=Terrain.unpack(points[i-1]).distance_to(Terrain.unpack(points[i]))
	if total<=0.001:return Terrain.unpack(points[0])
	var stage: String=str(event.get("status","waiting"))
	var length_fraction:=0.0
	if stage=="responding":
		length_fraction=1.0-clampf(float(event.get("remaining",0.0))/maxf(1.0,float(event.get("response_duration",1.0))),0.0,1.0)
	elif stage in ["transporting","guiding"]:
		length_fraction=clampf(float(event.get("remaining",0.0))/maxf(1.0,float(event.get("stage_duration",1.0))),0.0,1.0)
	else:
		length_fraction=1.0
	var left:=total*length_fraction
	for i in range(1,points.size()):
		var a:Vector2=Terrain.unpack(points[i-1])
		var b:Vector2=Terrain.unpack(points[i])
		var d:=a.distance_to(b)
		if left<=d:return a.lerp(b,left/maxf(d,0.001))
		left-=d
	return Terrain.unpack(points.back())

static func route_points_from_legs(start_point: Array, legs: Array, goal_point: Array) -> Array:
	var result:Array=[start_point.duplicate(true)]
	for leg in legs:
		if not leg is Dictionary:continue
		for waypoint in leg.get("points",[]):
			if not Terrain.unpack(waypoint).is_finite():continue
			if result.size()<127 and Terrain.unpack(waypoint).distance_to(Terrain.unpack(result.back()))>=3.0:
				result.append(Terrain.pack(Terrain.unpack(waypoint)))
	if Terrain.unpack(goal_point).is_finite() and Terrain.unpack(goal_point).distance_to(Terrain.unpack(result.back()))>0.01:
		result.append(goal_point.duplicate(true))
	return result
