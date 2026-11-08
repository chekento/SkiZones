extends RefCounted
## 0.40: explicit rescue lifecycle. Never classify a frightened skier as injured.
## Travel uses graph-supplied route points; this module contains only bounded,
## platform-independent decisions so the simulation can be regression tested.
const INJURY_REASONS := ["collision","fatigue","evacuation"]
const ROUTE_LIMIT := 512

static func needs_stretcher(reason:String)->bool:
	return reason in INJURY_REASONS

static func treatment_minutes(reason:String,seed:int)->int:
	if reason=="navigation":return 0
	var base:=120 if reason=="collision" else 90 if reason=="evacuation" else 60
	return clampi(base+posmod(seed*31,31)-15,60,120)

static func transport_mode(distance:float,night:bool,has_snowcat:bool)->String:
	return "snowcat" if has_snowcat and (distance>=650.0 or night) else "ski_stretcher"

static func active_status(status:String)->bool:
	return status in ["responding","returning","treating"]

static func available_team(staff:Array,incidents:Array,target:String,now:Callable)->Array:
	var busy:Dictionary={}
	for event in incidents:
		if not active_status(str(event.get("status",""))):continue
		for worker in event.get("rescue_team",[]):busy[int(worker)]=true
	var candidates:Array=[]
	for person in staff:
		if not person is Dictionary:continue
		if str(person.get("assignment",""))!=target or str(person.get("role",""))!="rescue":continue
		if busy.has(int(person.get("id",-1))) or not now.call(person):continue
		candidates.append(int(person.id))
	candidates.sort()
	return candidates.slice(0,2) if candidates.size()>=2 else []

static func route_points(origin:Array,legs:Array,destination:Array)->Array:
	var points:Array=[origin.duplicate()]
	for leg in legs:
		for raw in leg.get("points",[]):
			if not raw is Array or raw.size()!=2:continue
			if points[-1]!=raw:points.append(raw.duplicate())
	if points[-1]!=destination:points.append(destination.duplicate())
	if points.size()>ROUTE_LIMIT:
		var sampled:Array=[]
		for i in range(ROUTE_LIMIT):
			sampled.append(points[roundi(float(i)*(points.size()-1)/(ROUTE_LIMIT-1))].duplicate())
		return sampled
	return points

static func position_on_route(points:Array,ratio:float)->Vector2:
	if points.is_empty():return Vector2.ZERO
	if points.size()==1:return Vector2(float(points[0][0]),float(points[0][1]))
	var fraction:=clampf(ratio,0.0,1.0)*float(points.size()-1)
	var index:=mini(floori(fraction),points.size()-2)
	var a:=Vector2(float(points[index][0]),float(points[index][1]))
	var b:=Vector2(float(points[index+1][0]),float(points[index+1][1]))
	return a.lerp(b,fraction-float(index))
