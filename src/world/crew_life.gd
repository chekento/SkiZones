extends RefCounted
## Non-persistent presentation for employed resort workers. Actual roster,
## shifts, repair incidents and groomer tasks remain sourced from Operations.
const Ops=preload("res://src/core/operations.gd")
const Terrain=preload("res://src/core/terrain.gd")
const Foot=preload("res://src/core/foot_network.gd")
const Art=preload("res://src/world/alpine_art.gd")
const Styles=preload("res://src/core/visual_styles.gd")
const StyleAssets=preload("res://src/world/style_assets.gd")
const MAX_VISIBLE_STAFF := 56
const MAX_VISIBLE_RESCUE := 12
var root: Node3D
var lodge_point := Vector2.INF
var staff_mesh: MultiMeshInstance3D
var emergency_mesh: MultiMeshInstance3D
var route_cache: Dictionary={}
var rescue_durations: Dictionary={}
var snapshot_revision := -1
var _tick := 0.0

static func staff_home(view: Node3D) -> Vector2:
	# Provided scenery on every resort map, without changing an old career save.
	for offset in [Vector2(-115,55),Vector2(-145,-40),Vector2(120,85),Vector2(-110,-95),Vector2(130,-110),Vector2(-210,90)]:
		var candidate:Vector2=Terrain.BASE+offset
		if not view.terrain.contains(candidate) or not view.piste_clear(candidate,40):continue
		if not Foot.free_of_buildings(candidate,view.model.buildings,42) or view.terrain.slope_percent(candidate)>28:continue
		var clear := true
		for area in view._pedestrian_snapshot.get("areas",[]):
			if candidate.distance_to(area.center)<float(area.radius)+30:clear=false
		for link in view._pedestrian_snapshot.get("links",[]):
			for i in range(1,link.points.size()):
				if Geometry2D.get_closest_point_to_segment(candidate,Terrain.unpack(link.points[i-1]),Terrain.unpack(link.points[i])).distance_to(candidate)<float(link.get("width",7))*0.5+30:clear=false
		if clear:return candidate
	return Vector2.INF

static func destination(model: RefCounted, staff: Dictionary) -> Vector2:
	var assignment: String=str(staff.get("assignment",""))
	if assignment.begins_with("building:"):
		var id_text:=assignment.trim_prefix("building:")
		if id_text.is_valid_int():
			var b:Dictionary=model.asset(int(id_text))
			if not b.is_empty() and b.has("point"):
				return Foot.forecourt(b)
	for lift in model.lifts:
		for station in Ops.station_demands(lift):
			if str(station.key)==assignment:
				return Terrain.unpack(station.point)
	return Terrain.BASE

static func progress(model: RefCounted, staff: Dictionary) -> float:
	var shift: String=str(staff.get("shift","day"))
	var values: Array=Ops.SHIFTS.get(shift,Ops.SHIFTS.day)
	var beginning:int=int(values[0])
	var end:int=int(values[1])
	var minute:int=int(model.minute)
	var since:int=posmod(minute-beginning,1440)
	var duration:int=posmod(end-beginning,1440)
	if not Ops.on_duty(model,staff):
		return 0.0
	if since<45:return clampf(float(since)/45.0,0,1)
	if duration-since<45:return clampf(float(duration-since)/45.0,0,1)
	return 1.0

static func human_mesh(style: String) -> ArrayMesh:
	var art:=Art.new()
	var tint:Dictionary=Styles.detail_tints(style)
	var coat:=Color(str(tint.metal))
	art.sphere(Vector3(0,3.15,0),0.70,Color("e6bf9e"))
	art.cone(Vector3(0,1.9,0),0.90,1.85,coat,0.72)
	art.box(Vector3(0,3.65,0),Vector3(1.5,0.50,1.2),coat.darkened(0.2))
	for side in [-1,1]:
		art.box(Vector3(side*0.45,0.75,0),Vector3(0.42,1.5,0.55),Color("394e59"))
		art.box(Vector3(side*1.05,2.15,0),Vector3(0.40,1.3,0.46),Color("d4dde0"))
	art.sphere(Vector3(0,3.75,0),0.12,Color("ffe19f"))
	return art.finish()

static func rescue_mesh(style: String) -> ArrayMesh:
	var art:=Art.new()
	var color:=Color("dd6c70") if style!="piste_map" else Color("c0504b")
	art.box(Vector3(0,1.1,0),Vector3(4.2,1.3,8.0),color)
	art.box(Vector3(0,2.25,0.1),Vector3(3.2,1.7,3.3),Color("fcfbec"))
	art.box(Vector3(0,3.2,0),Vector3(0.65,0.3,1.9),color)
	art.box(Vector3(0,3.2,0),Vector3(2.2,0.3,0.55),color)
	for side in [-1,1]:
		art.box(Vector3(side*1.8,0.3,0),Vector3(0.5,0.45,9.0),Color("5c6770"))
		art.link(Vector3(side*1.65,0.7,2.7),Vector3(side*1.65,2.2,1.0),0.22,Color("53646e"))
	return art.finish()

static func lodge_mesh(style: String) -> ArrayMesh:
	if style!="alpine":
		return StyleAssets.building("hotel",1,Color(str(Styles.detail_tints(style).wood)),style)
	var art:=Art.new()
	var p:Dictionary=Styles.detail_tints(style)
	var wood:=Color(str(p.wood))
	var snow:=Color(str(p.snow))
	var wall:=wood.lightened(0.27)
	art.soft_box(Vector3(0,8,0),Vector3(34,16,24),wall,Vector3.ZERO,0.6)
	for side in [-1,1]:
		art.box(Vector3(side*17.5,12,0),Vector3(1.0,3.5,24),wood)
	art.box(Vector3(0,17.0,0),Vector3(38,2.8,28),snow)
	art.box(Vector3(0,3.2,12.5),Vector3(5.0,6.2,0.7),wood.darkened(0.28))
	for floor in [5.7,12.0]:
		for x in [-11,-3,5,13]:
			art.box(Vector3(x,floor,12.55),Vector3(3.7,3.0,0.5),Color("ffedb0"))
			art.box(Vector3(x,floor,12.95),Vector3(0.25,3.0,0.6),wood)
	art.box(Vector3(0,19.1,12.7),Vector3(20.0,2.5,1.1),wood.darkened(0.2))
	for x in [-3.7,3.7]:
		art.box(Vector3(x,21.4,0),Vector3(3.0,4.4,3.0),Color("adbdc4"))
		art.box(Vector3(x,23.8,0),Vector3(3.8,1.3,3.8),snow)
	# Gear rack with actual boots, skis and colorful bags.
	for index in range(7):
		var x:float=-12.0+float(index)*3.9
		art.box(Vector3(x,3.5,16),Vector3(0.25,7.0,0.3),wood)
		art.box(Vector3(x+0.40,3.2,16),Vector3(0.18,6.3,0.30),Color("e49b54") if index%2==0 else Color("6799b0"))
		art.sphere(Vector3(x,0.8,15.4),0.8,wood.darkened(0.22))
	return art.finish()

func build(view: Node3D) -> void:
	if is_instance_valid(root):
		if root.get_parent()!=null:root.get_parent().remove_child(root)
		root.queue_free()
	root=Node3D.new()
	root.name="Mitarbeiterunterkunft & lebendige Crew"
	view.add_child(root)
	lodge_point=staff_home(view)
	route_cache.clear()
	rescue_durations.clear()
	snapshot_revision=view.model.revision
	if lodge_point.is_finite():
		var dorm:=MeshInstance3D.new()
		dorm.mesh=lodge_mesh(view.visual_style)
		dorm.mesh.surface_set_material(0,view._solid)
		dorm.position=view.terrain.world(lodge_point,0.3)
		root.add_child(dorm)
	var crew:=human_mesh(view.visual_style)
	crew.surface_set_material(0,view._solid)
	staff_mesh=MultiMeshInstance3D.new()
	staff_mesh.multimesh=view._multimesh(crew,MAX_VISIBLE_STAFF)
	staff_mesh.multimesh.visible_instance_count=0
	root.add_child(staff_mesh)
	var rescue:=rescue_mesh(view.visual_style)
	rescue.surface_set_material(0,view._solid)
	emergency_mesh=MultiMeshInstance3D.new()
	emergency_mesh.multimesh=view._multimesh(rescue,MAX_VISIBLE_RESCUE)
	emergency_mesh.multimesh.visible_instance_count=0
	root.add_child(emergency_mesh)

func _person_pos(view: Node3D, staff: Dictionary) -> Vector2:
	var destination_value:Vector2=destination(view.model,staff)
	var progress_value:float=progress(view.model,staff)
	if not lodge_point.is_finite() or lodge_point.distance_to(destination_value)<1:
		return destination_value
	var id:int=int(staff.id)
	var key: String=str(id)+":"+str(staff.assignment)+":"+str(view.model.revision)
	if not route_cache.has(key):
		var path:Array=Foot.path_between(lodge_point+Vector2(0,18),destination_value,view.model.buildings,view.model.lifts,view._pedestrian_snapshot.get("obstacles",[]))
		route_cache[key]=path
	var path:Array=route_cache[key]
	if path.size()<2:
		# No invented commute through slopes or buildings.
		return lodge_point
	var traveled:float=0
	var total:float=0
	for index in range(1,path.size()):
		total+=Terrain.unpack(path[index-1]).distance_to(Terrain.unpack(path[index]))
	var wanted:float=clampf(progress_value,0,1)*total
	for index in range(1,path.size()):
		var a:Vector2=Terrain.unpack(path[index-1])
		var b:Vector2=Terrain.unpack(path[index])
		var length_value:float=a.distance_to(b)
		if traveled+length_value>=wanted:
			return a.lerp(b,clampf((wanted-traveled)/maxf(0.001,length_value),0,1))
		traveled+=length_value
	return Terrain.unpack(path.back())

func update(view: Node3D,delta: float) -> void:
	if not is_instance_valid(root) or not is_instance_valid(staff_mesh):return
	if view.model.revision!=snapshot_revision:
		build(view)
		return
	_tick+=maxf(0,delta)
	if _tick<0.20:return
	_tick=0.0
	var amount:=0
	if lodge_point.is_finite():
		for worker in view.model.operations.staff:
			if amount>=MAX_VISIBLE_STAFF:break
			var pos:=_person_pos(view,worker)
			if pos.distance_to(view.focus)>maxf(view.zoom*1.6,190.0):continue
			var wobble:=Vector2(sin(float(view.model.minute+int(worker.id))*0.17),cos(float(view.model.minute+int(worker.id))*0.13))*0.8
			staff_mesh.multimesh.set_instance_transform(amount,Transform3D(Basis.IDENTITY,view.terrain.world(pos+wobble,0.6)))
			staff_mesh.multimesh.set_instance_color(amount,Color.WHITE)
			amount+=1
	staff_mesh.multimesh.visible_instance_count=amount
	var rescue_count:=0
	for incident in view.model.operations.incidents:
		if rescue_count>=MAX_VISIBLE_RESCUE:break
		if str(incident.get("status",""))!="responding":continue
		var station:Dictionary=view.model.asset(int(incident.get("station",-1)))
		if station.is_empty():continue
		var from:Vector2=Terrain.unpack(station.point)
		var to:Vector2=Terrain.unpack(incident.point)
		if minf(from.distance_to(view.focus),to.distance_to(view.focus))>maxf(view.zoom*2.0,240):continue
		# Visual travel progress based on response time. An exact path for rescue
		# vehicles is a separate future routing feature.
		var total: float=float(incident.get("response_duration",rescue_durations.get(incident.id,maxf(1,float(incident.get("remaining",1))))))
		rescue_durations[incident.id]=total
		var ratio:float=clampf(1.0-float(incident.get("remaining",0))/maxf(1,total),0,1)
		var pos:Vector2=from.lerp(to,ratio)
		var angle:float=atan2(to.x-from.x,to.y-from.y)
		emergency_mesh.multimesh.set_instance_transform(rescue_count,Transform3D(Basis(Vector3.UP,angle),view.terrain.world(pos,0.5)))
		emergency_mesh.multimesh.set_instance_color(rescue_count,Color.WHITE)
		rescue_count+=1
	emergency_mesh.multimesh.visible_instance_count=rescue_count
