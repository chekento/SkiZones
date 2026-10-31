extends RefCounted
## Open-map context uses the exact projection of each existing real resort.
const Terrain=preload("res://src/core/terrain.gd")
const Geo=preload("res://src/core/real_resorts.gd")
const Catalog=preload("res://src/core/catalog.gd")
const Foot=preload("res://src/core/foot_network.gd")
const L=preload("res://src/core/i18n.gd")
static var _cache: Dictionary={}
static var _mutex:=Mutex.new()
const CAR_ROADS=["primary","primary_link","secondary","secondary_link","tertiary","tertiary_link","unclassified","residential","living_street","service"]
static func data(id: String) -> Dictionary:
	if id not in Geo.IDS:return {}
	_mutex.lock()
	if not _cache.has(id):
		var bytes:=FileAccess.get_file_as_bytes("res://assets/places/%s.bin" % id)
		var value: Variant=JSON.parse_string(bytes.decompress_dynamic(67108864,FileAccess.COMPRESSION_GZIP).get_string_from_utf8()) if not bytes.is_empty() else null
		_cache.clear()
		_cache[id]=value if value is Dictionary and value.get("schema")==1 else {}
	var result: Dictionary=_cache[id]
	_mutex.unlock()
	return result
static func _grid_key(point: Vector2) -> Vector2i:return Vector2i((point/256).floor())
static func index(id: String) -> Dictionary:
	var context:=data(id)
	if context.is_empty():return {}
	if context.has("spatial"):return context.spatial
	var cells: Dictionary={}
	for category in ["buildings","roads","pois","stops"]:
		for i in range(context[category].size()):
			var item: Dictionary=context[category][i]
			var polygon: Array=item.get("outline",item.get("points",[item.point] if item.has("point") else []))
			if polygon.is_empty():continue
			var bounds:=Rect2(Terrain.unpack(polygon[0]),Vector2.ZERO)
			for point in polygon:bounds=bounds.expand(Terrain.unpack(point))
			for x in range(floori(bounds.position.x/256),floori(bounds.end.x/256)+1):
				for y in range(floori(bounds.position.y/256),floori(bounds.end.y/256)+1):
					var key:=Vector2i(x,y)
					if not cells.has(key):cells[key]={"buildings":[],"roads":[],"pois":[],"stops":[]}
					cells[key][category].append(i)
	context.spatial=cells
	return cells
static func near(id: String,point: Vector2,category: String,radius: int=0) -> Array:
	var cells:=index(id);var cell:=_grid_key(point);var found: Dictionary={}
	for x in range(cell.x-radius,cell.x+radius+1):
		for y in range(cell.y-radius,cell.y+radius+1):
			for n in cells.get(Vector2i(x,y),{}).get(category,[]):found[n]=true
	return found.keys()
static func occupied(id: String,point: Vector2,margin: float=0) -> bool:
	var context:=data(id)
	for n in near(id,point,"buildings",1 if margin>0 else 0):
		var polygon:=PackedVector2Array()
		for p in context.buildings[n].outline:polygon.append(Terrain.unpack(p))
		if Geometry2D.is_point_in_polygon(point,polygon):return true
		if margin>0:
			for i in range(1,polygon.size()):
				if Geometry2D.get_closest_point_to_segment(point,polygon[i-1],polygon[i]).distance_to(point)<margin:return true
	return false
static func clear_ground(id: String,point: Vector2,margin: float) -> bool:
	if id not in Geo.IDS:return true
	if occupied(id,point,margin):return false
	var context:=data(id)
	for n in near(id,point,"roads",1):
		var road: Dictionary=context.roads[n];var radius:=4.0 if road.kind in CAR_ROADS else 1.5
		for i in range(1,road.points.size()):
			if Geometry2D.get_closest_point_to_segment(point,Terrain.unpack(road.points[i-1]),Terrain.unpack(road.points[i])).distance_to(point)<radius+margin:return false
	return true
static func seed(model: RefCounted) -> void:
	if model.map_id not in Geo.IDS:return
	var context:=data(model.map_id)
	if context.is_empty():return
	var original: Array=model.buildings.duplicate()
	var selected: Array=[];var used: Dictionary={}
	for category in ["school","hotel","food"]:
		var candidates: Array=context.pois.filter(func(p):return p.category==category and p.name!="" and model.terrain.contains(Terrain.unpack(p.point)))
		candidates.sort_custom(func(a,b):return Terrain.unpack(a.point).distance_squared_to(Terrain.BASE)<Terrain.unpack(b.point).distance_squared_to(Terrain.BASE))
		for poi in candidates.slice(0,2 if category=="school" else 5 if category=="hotel" else 14):
			var key: String="%s:%d" % [poi.osm_type,int(poi.osm_id)]
			if used.has(key):continue
			used[key]=true
			selected.append(poi)
	if selected.is_empty():return
	# This is called only for a newly started scenario; existing saves keep assets.
	model.buildings.clear()
	model.operations.staff=model.operations.staff.filter(func(p):return not str(p.assignment).begins_with("building:"))
	for poi in selected:
		var kind: String="school" if poi.category=="school" else "hotel" if poi.category=="hotel" else "pub" if poi.subtype in ["pub","bar"] else "pizzeria" if str(poi.cuisine).contains("pizza") else "cocoa" if poi.subtype=="cafe" else "kiosk" if poi.subtype=="fast_food" else "restaurant"
		if not Catalog.BUILDINGS.has(kind):kind="restaurant"
		var item: Dictionary={"id":model.next_id,"kind":kind,"point":poi.point.duplicate(),"cost":Catalog.BUILDINGS[kind].cost,"enabled":true,"level":1,"upgrade_total":0.0,"name":str(poi.name).left(100),"custom_name":true,"visits":0,"revenue":0.0,"rotation":0,"town_imported":true,"osm_id":poi.osm_id,"osm_type":poi.osm_type,"source_point":poi.point.duplicate(),"address":poi.address}
		model.buildings.append(item);model.next_id+=1
		model.Ops.fill_building(model,int(item.id),true)
	model._invalidate()
static func network(model: RefCounted,cars: bool=false) -> Dictionary:
	var context:=data(model.map_id)
	var cache_key: String="cars" if cars else "walking"
	if context.has(cache_key):return context[cache_key]
	var eligible: Array=context.roads.filter(func(r):return r.kind in CAR_ROADS and r.access not in ["private","no"] if cars else r.kind not in ["motorway","motorway_link","trunk","trunk_link","construction","proposed"] and r.access!="no")
	var degree: Dictionary={}
	for road in eligible:
		for n in road.nodes:degree[str(int(n))]=int(degree.get(str(int(n)),0))+1
	var graph: Dictionary={"nodes":{},"edges":{},"grid":{},"segments":[]}
	for road in eligible:
		var path: Array=[];var distance:=0.0
		for i in range(road.points.size()):
			var point: Array=road.points[i]
			if not path.is_empty():distance+=Terrain.unpack(path[-1]).distance_to(Terrain.unpack(point))
			path.append(point)
			var source_id: String=str(int(road.nodes[i])) if i<road.nodes.size() else "%d:%d" % [int(road.osm_id),i]
			if path.size()==1 or i==road.points.size()-1 or degree.get(source_id,0)>1 or distance>=100 or path.size()>=60:
				var key: String="r"+source_id
				if not graph.nodes.has(key):
					graph.nodes[key]=point;graph.edges[key]=[]
					var cell:=_grid_key(Terrain.unpack(point))
					if not graph.grid.has(cell):graph.grid[cell]=[]
					graph.grid[cell].append(key)
				if path.size()>1:
					var previous_id: String=str(int(road.nodes[i-path.size()+1])) if i-path.size()+1<road.nodes.size() else "%d:%d" % [int(road.osm_id),i-path.size()+1]
					var from: String="r"+previous_id
					var cost: float=maxf(0.15,distance*(0.035 if cars else 0.16))
					var edge: Dictionary={"from":from,"to":key,"kind":"walk","id":0,"points":path.duplicate(),"minutes":cost}
					graph.edges[from].append(edge);graph.segments.append(edge)
					var reverse: Array=path.duplicate();reverse.reverse()
					if not cars or road.oneway!="yes":graph.edges[key].append({"from":key,"to":from,"kind":"walk","id":0,"points":reverse,"minutes":cost})
				path=[point];distance=0.0
	context[cache_key]=graph
	return graph
static func nearest(graph: Dictionary,point: Vector2,radius: float=180) -> String:
	var found: String="";var cell:=_grid_key(point);var reach:=ceili(radius/256)
	for x in range(cell.x-reach,cell.x+reach+1):
		for y in range(cell.y-reach,cell.y+reach+1):
			for key in graph.grid.get(Vector2i(x,y),[]):
				var distance:=point.distance_to(Terrain.unpack(graph.nodes[key]))
				if distance<radius:radius=distance;found=key
	return found
static func path(model: RefCounted,a: Vector2,b: Vector2,cars: bool=false) -> Array:
	var graph:=network(model,cars)
	var start:=nearest(graph,a,350 if cars else 180);var end:=nearest(graph,b,350 if cars else 180)
	if start=="" or end=="":return []
	var route: Dictionary=model._shortest(graph,start,end)
	if not route.ok:return []
	var points: Array=[Terrain.pack(a)]
	for leg in route.legs:
		for p in leg.points:
			if Terrain.unpack(points[-1]).distance_to(Terrain.unpack(p))>0.05:points.append(p)
	if Terrain.unpack(points[-1]).distance_to(b)>0.05:points.append(Terrain.pack(b))
	return points
static func extend_graph(model: RefCounted,nodes: Dictionary,edges: Dictionary) -> void:
	if not model.life_enabled or model.map_id not in Geo.IDS:return
	var targets: Array=[]
	for key in nodes.keys():
		if key.begins_with("d") or key.begins_with("l") and key.ends_with("b"):targets.append(key)
	for target in targets:
		var points:=path(model,Terrain.unpack(nodes.base),Terrain.unpack(nodes[target]))
		if points.size()<2:continue
		var previous: String="base"
		var offset:=0
		while offset<points.size()-1:
			var part: Array=points.slice(offset,mini(points.size(),offset+64))
			offset+=part.size()-1
			var next: String=target if offset>=points.size()-1 else "tw:%s:%d" % [target,offset]
			if not nodes.has(next):nodes[next]=part[-1];edges[next]=[]
			var duration: float=Foot.walk_minutes(model.terrain,part)
			var leg: Dictionary=model._edge(previous,next,"walk",0,part,duration);leg.town_walk=true;edges[previous].append(leg)
			var reverse: Array=part.duplicate(true);reverse.reverse()
			var back: Dictionary=model._edge(next,previous,"walk",0,reverse,duration);back.town_walk=true;edges[next].append(back)
			previous=next
static func checked_walk(model: RefCounted,leg: Dictionary) -> bool:
	if not model.life_enabled or model.map_id not in Geo.IDS or not leg.get("town_walk",false):return false
	var graph: Dictionary=model.pedestrian_graph()
	for expected in graph.edges.get(leg.from,[]):
		if expected.get("town_walk",false) and expected.to==leg.to and expected.points==leg.points:return true
	return false
