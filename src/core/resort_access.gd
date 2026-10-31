extends RefCounted
## Public edge access and quoted, obstacle-aware lift footpaths.
const Terrain=preload("res://src/core/terrain.gd")
const Foot=preload("res://src/core/foot_network.gd")
static func entrance(model: RefCounted) -> Array:
	var bounds: Rect2=model.terrain.bounds
	var targets: Array=[]
	for offset in [0,-100,100,-240,240,-480,480]:
		var x:=clampf(Terrain.BASE.x+offset,bounds.position.x+30,bounds.end.x-30)
		var y:=clampf(Terrain.BASE.y+offset,bounds.position.y+30,bounds.end.y-30)
		targets.append(Vector2(x,bounds.end.y+18));targets.append(Vector2(bounds.position.x-18,y));targets.append(Vector2(bounds.end.x+18,y));targets.append(Vector2(x,bounds.position.y-18))
	targets.sort_custom(func(a,b):return a.distance_to(Terrain.BASE)<b.distance_to(Terrain.BASE))
	var best: Array=[];var cost:=INF
	for target in targets:
		if target.distance_to(Terrain.BASE)>cost:continue
		var path:=Foot.path_between(Terrain.BASE,target,model.buildings,model.lifts)
		if path.is_empty() or path.size()>64:continue
		var gentle:=Foot.gentle(model.terrain,path)
		var score: float=model.terrain.polyline_length(path)*(1 if gentle else 8)
		if score<cost:cost=score;best=path
	return best
static func valid(model: RefCounted,path: Variant) -> bool:
	if not path is Array or path.size()<2 or path.size()>64:return false
	if Terrain.unpack(path[0]).distance_to(Terrain.BASE)>0.01:return false
	var bounds: Rect2=model.terrain.bounds
	for i in range(path.size()):
		if not path[i] is Array or path[i].size()!=2:return false
		for number in path[i]:
			if not Terrain.number(number):return false
		var point:=Terrain.unpack(path[i])
		if not bounds.grow(24).has_point(point) or i<path.size()-1 and not bounds.has_point(point):return false
	var gate:=Terrain.unpack(path[-1]);var on_edge:=bounds.position+(gate-bounds.position).clamp(Vector2.ZERO,bounds.size)
	return not bounds.has_point(gate) and gate.distance_to(on_edge)>=12 and gate.distance_to(on_edge)<=24 and Foot.clear_walk(path,model.buildings,model.lifts)
static func arrive(model: RefCounted,guest: Dictionary) -> void:
	if not model.edge_entries or model.portal_path.is_empty():return
	var path: Array=model.portal_path.duplicate(true);path.reverse()
	guest.route=guest.route.duplicate(true);guest.route.origin=path[0]
	guest.route.legs.push_front(model._edge("outside","base","walk",0,path,Foot.walk_minutes(model.terrain,path)))
	guest.leg=0;model._start_leg(guest)
static func depart(model: RefCounted,guest: Dictionary) -> void:
	if not model.edge_entries or model.portal_path.is_empty() or guest.get("portal_departing",false):guest.phase="leaving";return
	var path: Array=model.portal_path.duplicate(true)
	guest.route={"target":0,"origin":path[0],"legs":[model._edge("base","outside","walk",0,path,Foot.walk_minutes(model.terrain,path))]}
	guest.leg=0;guest.portal_departing=true;guest.heading_home=true;model._start_leg(guest)
static func lift_connection(model: RefCounted,proposed: Dictionary) -> Dictionary:
	var graph: Dictionary=model.pedestrian_graph()
	var reachable: Dictionary={"base":true};var open: Array=["base"]
	while not open.is_empty():
		var key: String=open.pop_front()
		for leg in graph.edges.get(key,[]):
			if not reachable.has(leg.to):reachable[leg.to]=true;open.append(leg.to)
	var hub:=Foot.station_hub(proposed,false,model.buildings)
	var options: Array=[]
	for key in reachable:
		var at:=Terrain.unpack(graph.nodes[key])
		if model.terrain.contains(at):options.append({"point":at,"distance":at.distance_to(hub)})
	options.sort_custom(func(a,b):return a.distance<b.distance)
	var result: Dictionary={};var best:=INF
	for option in options.slice(0,24):
		if option.distance>=best:continue
		var path:=Foot.path_between(option.point,hub,model.buildings,model.lifts+[proposed])
		if path.is_empty() or not Foot.gentle(model.terrain,path):continue
		var length: float=model.terrain.polyline_length(path)
		if length<best:best=length;result={"points":path,"length":length,"cost":roundi(length*8)}
	return result
