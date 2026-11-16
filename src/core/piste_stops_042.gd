extends RefCounted
## A real, reversible detour from a descent to a nearby building door.
## Neither construction nor trip planning alters the authored piste geometry.
const Terrain=preload("res://src/core/terrain.gd")
const Foot=preload("res://src/core/foot_network.gd")
const Snow=preload("res://src/core/snow_surface.gd")
const Needs=preload("res://src/core/guest_needs.gd")
const Motion=preload("res://src/core/ski_motion.gd")

static func connection(model:RefCounted,building:Dictionary)->Dictionary:
	if not Needs.SERVICES.has(str(building.kind)):return {}
	var entrance:=Foot.door(building)
	var best:Dictionary={}
	var distance:=INF
	for segment in model.piste_links().nearby(entrance,70):
		var piste:Dictionary=model.asset(int(segment.id))
		var at:=Geometry2D.get_closest_point_to_segment(entrance,segment.a,segment.b)
		var gap:=at.distance_to(entrance)
		if gap>Snow.piste_width(piste)*0.5+30 or gap>=distance:continue
		var first:float=model.terrain.waypoint_fraction(piste.points,int(segment.index)-1)
		var last:float=model.terrain.waypoint_fraction(piste.points,int(segment.index))
		var fraction:=lerpf(first,last,segment.a.distance_to(at)/maxf(0.001,segment.a.distance_to(segment.b)))
		if fraction*float(piste.length)<18 or (1-fraction)*float(piste.length)<18:continue
		# The door may need a short bend around the building or lift machinery.
		var structures:Array=model.buildings.duplicate()
		if not structures.has(building):structures.append(building)
		var path:=Foot.path_between(at,entrance,structures,model.lifts)
		if path.size()<2 or path.size()>16 or not Foot.gentle(model.terrain,path):continue
		var length:float=model.terrain.polyline_length(path)
		if length>70:continue
		distance=gap
		best={"piste":int(piste.id),"fraction":fraction,"points":path,"length":length,"building":int(building.get("id",-1))}
	return best

static func stops(model:RefCounted)->Array:
	if model._piste_stops_revision==model.revision:return model._piste_stops
	model._piste_stops_revision=model.revision
	model._piste_stops=[]
	for building in model.buildings:
		var link:=connection(model,building)
		if not link.is_empty():model._piste_stops.append(link)
	return model._piste_stops

static func slice_points(model:RefCounted,piste:Dictionary,start:float,finish:float)->Array:
	var points:Array=[Terrain.pack(model.terrain.point_on_path(piste.points,start))]
	for index in range(1,piste.points.size()-1):
		var fraction:float=model.terrain.waypoint_fraction(piste.points,index)
		if fraction>start+0.000001 and fraction<finish-0.000001:points.append(piste.points[index].duplicate())
	points.append(Terrain.pack(model.terrain.point_on_path(piste.points,finish)))
	return points

static func ski_leg(model:RefCounted,piste:Dictionary,source:String,target:String,start:float,finish:float,skill:int)->Dictionary:
	var points:=slice_points(model,piste,start,finish)
	var profile:=Motion.travel_profile(model.terrain,points,skill)
	var leg:Dictionary=model._edge(source,target,"ski",int(piste.id),points,float(profile.minutes))
	leg.merge({"partial":true,"start_fraction":start,"end_fraction":finish,"motion":profile.samples,"motion_version":2,"skill":skill})
	return leg

static func valid_access(model:RefCounted,leg:Dictionary)->bool:
	var id:Variant=leg.get("piste_access")
	if not Terrain.number(id) or id!=floorf(id):return false
	var building:Dictionary=model.asset(int(id))
	if building.is_empty():return false
	var link:=connection(model,building)
	if link.is_empty():return false
	var expected:Array=link.points.duplicate(true)
	if Terrain.unpack(leg.points[0]).distance_to(Foot.door(building))<0.01:expected.reverse()
	if expected.size()!=leg.points.size():return false
	for index in range(expected.size()):
		if Terrain.unpack(expected[index]).distance_to(Terrain.unpack(leg.points[index]))>0.01:return false
	return true

static func decorate(model:RefCounted,guest:Dictionary,route:Dictionary,active_fraction:float=-1.0)->Dictionary:
	if route.is_empty() or route.legs.size()>214 or guest.get("heading_home",false) or guest.get("hotel_night",false) or guest.has("guardian_id"):return route
	if route.legs.any(func(leg):return leg.kind=="visit"):return route
	var best:Dictionary={}
	var score:=0.0
	for link in stops(model):
		var building:Dictionary=model.asset(int(link.building))
		if not model.Ops.building_open(model,building) or model.PublicWC.is_public(str(building.kind)):continue
		var utility:float=model.service_utility(guest,str(building.kind))
		if utility<=0:continue
		if model.service_load(int(building.id),int(guest.id))+int(guest.get("group_size",1))>model.service_capacity(building):continue
		for index in range(route.legs.size()):
			var leg:Dictionary=route.legs[index]
			if leg.kind!="ski" or int(leg.id)!=int(link.piste):continue
			var fraction:float=link.fraction
			if active_fraction>=0 and (index!=0 or (fraction-active_fraction)*float(model.asset(int(leg.id)).length)<24.0):continue
			if fraction<=float(leg.get("start_fraction",0))+0.01 or fraction>=float(leg.get("end_fraction",1))-0.01:continue
			var value:=utility/(1.0+float(link.length)/25.0)
			if value>score:score=value;best={"link":link,"index":index}
	if best.is_empty():return route
	var link:Dictionary=best.link
	var building:Dictionary=model.asset(int(link.building))
	var index:int=best.index
	var original:Dictionary=route.legs[index]
	var piste:Dictionary=model.asset(int(original.id))
	var stop:="p%d-stop-%d" % [piste.id,building.id]
	var door:="d%d" % int(building.id)
	var prefix:=ski_leg(model,piste,str(original.from),stop,float(original.get("start_fraction",0)),float(link.fraction),int(guest.ability))
	var suffix:=ski_leg(model,piste,stop,str(original.to),float(link.fraction),float(original.get("end_fraction",1)),int(guest.ability))
	var outward:Dictionary=model._edge(stop,door,"walk",0,link.points.duplicate(true),Foot.walk_minutes(model.terrain,link.points))
	outward.piste_access=int(building.id)
	var reverse:Array=link.points.duplicate(true);reverse.reverse()
	var back:Dictionary=model._edge(door,stop,"walk",0,reverse,Foot.walk_minutes(model.terrain,reverse))
	back.piste_access=int(building.id)
	var entrance:=Terrain.pack(Foot.door(building))
	var pause:Dictionary=model._edge(door,door,"visit",int(building.id),[entrance,entrance],float(Needs.SERVICES[building.kind].minutes)/model.Ops.service_efficiency(model,building))
	pause.resume_piste=true
	var result:Dictionary=route.duplicate(true)
	result.legs=route.legs.slice(0,index)+[prefix,outward,pause,back,suffix]+route.legs.slice(index+1)
	var minutes:float=model.route_minutes(result,guest,1020 if model.Ops.continuous(model) else INF)
	if not is_finite(minutes) or float(guest.age)+minutes>float(guest.stay) or (not model.Ops.continuous(model) and model.minute+minutes>model.CLOSING):return route
	return result

## Reconsider a need arising during an existing descent. Retain the actual
## position by inverting the new travel profile, not by restarting the trip.
static func maybe_stop(model:RefCounted,guest:Dictionary)->bool:
	if guest.phase!="moving" or guest.get("incident",-1)>=0 or guest.has("party_id") or guest.get("heading_home",false):return false
	if int(guest.leg)>=guest.route.legs.size():return false
	var leg:Dictionary=guest.route.legs[int(guest.leg)]
	if leg.kind!="ski":return false
	if guest.route.legs.slice(int(guest.leg)).any(func(item):return item.kind=="visit"):return false
	var fraction:float=model.ski_fraction(leg,float(guest.elapsed)/maxf(0.001,float(guest.duration)),guest.get("ski_motion",[]))
	var remaining:Dictionary={"target":guest.route.target,"origin":leg.points[0].duplicate(),"legs":guest.route.legs.slice(int(guest.leg))}
	var planned:=decorate(model,guest,remaining,fraction)
	if not planned.legs.any(func(item):return item.get("resume_piste",false)):return false
	var lanes:Dictionary={}
	for key in ["traffic_lateral","traffic_lane","traffic_step","party_step"]:
		if guest.has(key):lanes[key]=guest[key]
	guest.route=planned;guest.leg=0
	model._start_leg(guest)
	var prefix:Dictionary=planned.legs[0]
	var wanted:float=(fraction-float(prefix.start_fraction))/maxf(0.000001,float(prefix.end_fraction)-float(prefix.start_fraction))
	var low:=0.0
	var high:=1.0
	for iteration in range(28):
		var middle:float=(low+high)*0.5
		if Motion.distance_progress(guest.get("ski_motion",[]),middle)<wanted:low=middle
		else:high=middle
	guest.elapsed=float(guest.duration)*(low+high)*0.5
	for key in lanes:guest[key]=lanes[key]
	return true
