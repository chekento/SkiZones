extends RefCounted
const L = preload("res://src/core/i18n.gd")
## Bounded terrain search; every user waypoint remains a mandatory stop.
const Terrain=preload("res://src/core/terrain.gd")
const Foot=preload("res://src/core/foot_network.gd")
const MAX_SEARCH:=24000

static func _clear(model: RefCounted,a: Vector2,b: Vector2,width: float,shapes: Array) -> bool:
	if not model.terrain.contains(a) or not model.terrain.contains(b): return false
	for shape in shapes:
		if Foot.crosses_polygon(a,b,shape): return false
	var count:=maxi(1,ceili(a.distance_to(b)/6))
	for index in range(count):
		var p:=a.lerp(b,float(index)/count)
		var q:=a.lerp(b,float(index+1)/count)
		var grade: float=(model.terrain.height(p)-model.terrain.height(q))/maxf(p.distance_to(q),0.01)
		if grade>0.30 or grade< -0.35: return false
	return Foot.clear_piste([Terrain.pack(a),Terrain.pack(b)],model.lifts,width*0.5)

static func _between(model: RefCounted,start: Vector2,finish: Vector2,width: float,shapes: Array,budget: Dictionary) -> Array:
	if _clear(model,start,finish,width,shapes): return [Terrain.pack(start),Terrain.pack(finish)]
	var step:=clampf(start.distance_to(finish)/55,10,32)
	var margin:=clampf(start.distance_to(finish)*0.4,90,360)
	var region:=Rect2(start,Vector2.ZERO).expand(finish).grow(margin).intersection(model.terrain.bounds.grow(-0.1))
	var grid:=Vector2i(ceili(region.size.x/step),ceili(region.size.y/step))
	var begin:=Vector2i(roundi((start.x-region.position.x)/step),roundi((start.y-region.position.y)/step))
	var heap: Array=[[0.0,begin]]
	var costs: Dictionary={begin:0.0}
	var previous: Dictionary={}
	var positions: Dictionary={begin:start}
	var visited: Dictionary={}
	var terminal:=Vector2i(-99999,-99999)
	var iterations:=0
	while not heap.is_empty() and budget.remaining>0 and Time.get_ticks_usec()<budget.deadline:
		var entry: Array=model._heap_pop(heap)
		var cell: Vector2i=entry[1]
		if visited.has(cell): continue
		visited[cell]=true
		iterations+=1
		budget.remaining-=1
		if cell==terminal: break
		var at: Vector2=positions[cell]
		var candidates: Array=[]
		if at.distance_to(finish)<=step*2.1: candidates.append(terminal)
		for x in range(-1,2):
			for y in range(-1,2):
				if x!=0 or y!=0: candidates.append(cell+Vector2i(x,y))
		for side in [-1,1]:
			for forward in [-1,1]:
				for span in [2,3]:
					candidates.append(cell+Vector2i(side*span,forward))
					candidates.append(cell+Vector2i(side,forward*span))
		for next: Vector2i in candidates:
			if visited.has(next): continue
			if next!=terminal and (next.x<0 or next.y<0 or next.x>grid.x or next.y>grid.y): continue
			var point:=finish if next==terminal else region.position+Vector2(next)*step
			if not _clear(model,at,point,width,shapes): continue
			var rise:=maxf(0,model.terrain.height(point)-model.terrain.height(at))
			var cost: float=costs[cell]+at.distance_to(point)+rise*14
			if previous.has(cell):
				var incoming: Vector2=(at-positions[previous[cell]]).normalized()
				cost+=(1-incoming.dot((point-at).normalized()))*step*0.8
			if cost<costs.get(next,INF):
				costs[next]=cost
				previous[next]=cell
				positions[next]=point
				model._heap_push(heap,[cost+point.distance_to(finish),next])
	if not previous.has(terminal): return []
	var path: Array=[Terrain.pack(finish)]
	var current:=terminal
	while current!=begin:
		current=previous[current]
		path.push_front(Terrain.pack(positions[current]))
	var result: Array=[path[0]]
	var index:=0
	while index<path.size()-1:
		var next:=path.size()-1
		while next>index+1 and not _clear(model,Terrain.unpack(path[index]),Terrain.unpack(path[next]),width,shapes): next-=1
		result.append(path[next])
		index=next
	return result

static func suggest(model: RefCounted,points: Array,width: float=20) -> Dictionary:
	if points.size()<2 or points.size()>64: return {"ok":false,"message":L.text("Zuerst Start und Ziel setzen."),"points":[]}
	for point in points:
		if not model.terrain.contains(Terrain.unpack(point)): return {"ok":false,"message":L.text("Alle Wegpunkte müssen im Baugebiet liegen."),"points":[]}
	var shapes: Array=[]
	for building in model.buildings:
		var size:=Foot.building_size(building)
		var rect:=Rect2(Terrain.unpack(building.point)-size*0.5,size).grow(width * 0.5 + 3)
		shapes.append(PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]))
	var result: Array=[points[0]]
	var budget: Dictionary={"remaining":MAX_SEARCH,"deadline":Time.get_ticks_usec()+1000000}
	for index in range(1,points.size()):
		var part:=_between(model,Terrain.unpack(points[index-1]),Terrain.unpack(points[index]),width,shapes,budget)
		if part.is_empty() or result.size()+part.size()-1>64: return {"ok":false,"message":L.text("Kein sanfter Verlauf gefunden. Weitere Zwischenpunkte quer zum Hang setzen."),"points":[]}
		result.append_array(part.slice(1))
	var check: Dictionary=model.preview_piste(result,width)
	if not check.ok: return {"ok":false,"message":check.message,"points":[]}
	check.message=L.text("Verlauf vorgeschlagen. Höhenprofil und Anschlüsse prüfen; erst Bauen bestätigt den Plan.")
	return check
