extends RefCounted
## Non-persistent presentation for employed resort workers. Actual roster,
## shifts, repair incidents and groomer tasks remain sourced from Operations.
const Assets=preload("res://src/world/style_assets.gd")
const Lines=preload("res://src/world/line_art.gd")
const Ops=preload("res://src/core/operations.gd")
const Terrain=preload("res://src/core/terrain.gd")
const Foot=preload("res://src/core/foot_network.gd")
const Art=preload("res://src/world/alpine_art.gd")
const Styles=preload("res://src/core/visual_styles.gd")
const MAX_VISIBLE_STAFF := 224
const CREW_GROUPS := ["service","hospitality","slope","medical","technical","security"]
const MAX_VISIBLE_RESCUE := 12
var root: Node3D
var lodge_point := Vector2.INF
var staff_mesh: MultiMeshInstance3D
var staff_meshes: Dictionary={}
var snowmobile_mesh: MultiMeshInstance3D
var snowmobile_patient_mesh: MultiMeshInstance3D
var staff_labels:Array=[]
var emergency_mesh: MultiMeshInstance3D
var stretcher_mesh: MultiMeshInstance3D
var casualty_mesh: MultiMeshInstance3D
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

static func group_for_role(role:String)->String:
	if role in ["rescue","medic","lifeguard","therapist"]:return "medical"
	if role in ["operator","ski_instructor"]:return "slope"
	if role in ["hotel","housekeeper","receptionist","chef","waiter","barista","bartender"]:return "hospitality"
	if role in ["technician","electrician","driver","snow","sanitation","artisan","printer","watchmaker"]:return "technical"
	if role=="security":return "security"
	return "service"

## Each professional has distinctive workwear rather than a shared placeholder.
## These are vertex-coloured meshes, instanced without per-employee draw calls.
static func human_mesh(style:String,group:String="service")->ArrayMesh:
	if style=="monochrome":
		var lines:=Lines.new()
		lines.circle(Vector3(0,3.3,0),0.6)
		lines.line(Vector3(0,1.2,0),Vector3(0,2.8,0))
		for side in [-1,1]:
			lines.line(Vector3(0,1.2,0),Vector3(float(side)*0.6,0,0))
			lines.line(Vector3(0,2.3,0),Vector3(float(side)*0.9,1.5,0))
		if group=="medical":lines.box(Vector3(0,2.35,-0.52),Vector3(0.8,0.8,0.15))
		if group=="technical":lines.box(Vector3(0,3.85,0),Vector3(1.7,0.3,1.3))
		return lines.finish()
	var art:=Art.new()
	var uniforms:Dictionary={
		"service":Color("4778a4"),"hospitality":Color("e1c6a0"),
		"slope":Color("267eaf"),"medical":Color("e55437"),
		"technical":Color("f1a331"),"security":Color("384653")}
	var coat:Color=uniforms.get(group,uniforms.service)
	if style=="piste_map":coat=coat.darkened(0.16)
	var trousers:=Color("344452")
	var boots:=Color("1f2e3c")
	for side in [-1,1]:
		var s:float=float(side)
		art.box(Vector3(s*0.40,0.73,0),Vector3(0.42,1.45,0.55),trousers)
		art.box(Vector3(s*0.40,0.18,-0.14),Vector3(0.55,0.35,0.93),boots)
		art.link(Vector3(s*0.73,2.70,0),Vector3(s*0.92,1.68,-0.20),0.24,coat.darkened(0.08))
		art.sphere(Vector3(s*0.92,1.62,-0.21),0.17,Color("edc9ac"))
	art.cone(Vector3(0,2.10,0),0.75,1.65,coat,0.85)
	art.box(Vector3(0,1.36,0),Vector3(1.38,0.21,0.92),trousers)
	art.sphere(Vector3(0,3.27,0),0.59,Color("edc9ac"))
	art.box(Vector3(0,3.76,0),Vector3(1.25,0.36,1.07),coat.darkened(0.20))
	# Visually readable helmet, apron, cross, radio or insignia by occupation.
	match group:
		"medical":
			art.box(Vector3(0,2.33,-0.69),Vector3(0.22,0.74,0.13),Color.WHITE)
			art.box(Vector3(0,2.33,-0.72),Vector3(0.72,0.20,0.15),Color.WHITE)
			art.box(Vector3(0,3.90,0),Vector3(1.55,0.26,1.28),Color("ecf2ef"))
		"technical":
			art.box(Vector3(0,3.94,0),Vector3(1.62,0.34,1.22),Color("eac43d"))
			art.box(Vector3(0,2.20,-0.65),Vector3(1.05,0.20,0.12),Color("f6e27b"))
			art.box(Vector3(0.73,1.92,-0.44),Vector3(0.21,0.68,0.28),Color("59686e"))
		"hospitality":
			art.box(Vector3(0,1.94,-0.64),Vector3(1.15,1.36,0.16),Color("f3f0e9"))
			art.box(Vector3(0,2.62,-0.76),Vector3(0.25,0.29,0.10),Color("897064"))
		"slope":
			art.box(Vector3(0,3.90,0),Vector3(1.66,0.30,1.35),Color("e8e7d5"))
			art.box(Vector3(0,3.26,-0.53),Vector3(1.18,0.20,0.17),Color("273a55"))
		"security":
			art.box(Vector3(-0.40,2.45,-0.65),Vector3(0.30,0.31,0.12),Color("e8d18f"))
			art.box(Vector3(0.72,2.50,-0.23),Vector3(0.20,0.44,0.21),Color("7b8990"))
		_:
			art.box(Vector3(0,2.55,-0.65),Vector3(0.46,0.21,0.14),Color("eff3f6"))
	return art.finish()

## Purpose-built vehicle with a loaded rescue sled, recognisable in both
## outward and return phases. It never changes incident routing/save physics.
static func snowmobile_art(style:String,loaded:bool=false)->ArrayMesh:
	if style=="monochrome":
		var lines:=Lines.new()
		lines.box(Vector3(0,1.0,0),Vector3(2.5,1.0,4.8))
		for side in [-1,1]:lines.line(Vector3(float(side)*1.1,0.3,-2.4),Vector3(float(side)*1.1,0.3,2.6))
		if loaded:lines.box(Vector3(0,1.0,3.1),Vector3(1.8,0.5,3.0))
		return lines.finish()
	var art:=Art.new()
	for side in [-1,1]:
		var s:float=float(side)
		art.box(Vector3(s*0.92,0.25,-0.35),Vector3(0.22,0.23,5.1),Color("25343d"))
		art.link(Vector3(s*0.78,0.35,1.9),Vector3(s*0.6,1.1,1.3),0.12,Color("cbd6dc"))
	art.box(Vector3(0,0.85,0),Vector3(2.0,0.85,3.4),Color("d94532"))
	art.box(Vector3(0,1.25,-0.65),Vector3(1.35,0.30,1.6),Color("333f49"))
	art.box(Vector3(0,1.0,1.45),Vector3(1.9,0.45,1.5),Color("e1e8ec"))
	art.link(Vector3(-0.8,1.8,-1.3),Vector3(0.8,1.8,-1.3),0.12,Color("364e61"))
	art.sphere(Vector3(0,2.57,-0.62),0.43,Color("ead3ac"))
	art.box(Vector3(0,2.93,-0.62),Vector3(1.00,0.26,0.96),Color("e95436"))
	if loaded:
		for side in [-1,1]:
			art.box(Vector3(float(side)*0.86,0.46,3.13),Vector3(0.13,0.18,3.0),Color("cbd6dc"))
		art.box(Vector3(0,0.72,3.1),Vector3(1.64,0.30,3.0),Color("eac564"))
		art.box(Vector3(0,1.03,3.22),Vector3(1.22,0.43,1.72),Color("548db1"))
		art.sphere(Vector3(0,1.13,2.16),0.38,Color("e8c5ad"))
	return art.finish()

## Two visibly separate alpine rescuers on skis, not the old red
## snowmobile. The return mesh carries a patient on the unfolded stretcher.
static func rescue_mesh(style:String,loaded:bool=false)->ArrayMesh:
	if style=="monochrome":
		var lines:=Lines.new()
		for side in [-1,1]:
			lines.circle(Vector3(side*1.55,3.2,0),0.55)
			lines.line(Vector3(side*1.55,0.6,-3.2),Vector3(side*1.55,0.6,3.2))
			lines.line(Vector3(side*1.55,1.0,0),Vector3(side*1.55,2.8,0))
		lines.box(Vector3(0,1.35,0),Vector3(2.1,0.35,5.3 if loaded else 3.1))
		if loaded:lines.circle(Vector3(0,2.1,-0.7),0.55)
		return lines.finish()
	var art:=Art.new()
	var jacket:=Color("e9623b") if style!="piste_map" else Color("c14b34")
	var ski:=Color("394851")
	var rail:=Color("c2ccd4")
	for side in [-1,1]:
		var x:float=float(side)*1.6
		# Each worker has independent skis, boots, arms and a helmet.
		for offset in [-0.40,0.40]:
			art.box(Vector3(x+offset,0.35,0),Vector3(0.22,0.22,6.4),ski)
			art.box(Vector3(x+offset,0.67,-0.05),Vector3(0.40,0.7,0.8),Color("374855"))
		art.cone(Vector3(x,2.0,0),0.68,1.8,jacket,0.70)
		art.sphere(Vector3(x,3.20,0),0.55,Color("ecd0ae"))
		art.box(Vector3(x,3.63,0),Vector3(1.25,0.43,1.15),Color("e74a38"))
		art.box(Vector3(x,3.26,-0.43),Vector3(1.05,0.20,0.20),Color("303e4c"))
		art.link(Vector3(x,2.70,0),Vector3(x-float(side)*0.55,1.55,-0.5),0.23,jacket)
		art.link(Vector3(x-float(side)*0.55,1.55,-0.5),Vector3(float(side)*0.92,1.40,-0.5),0.16,Color("5c6570"))
	var length_value:=5.0 if loaded else 3.2
	for side in [-1,1]:
		art.box(Vector3(float(side)*0.97,1.22,0),Vector3(0.16,0.17,length_value),rail)
	art.box(Vector3(0,1.18,0),Vector3(1.90,0.18,length_value-0.4),Color("e7b750"))
	if loaded:
		# The injured skier is lying on the return stretcher, never on
		# the empty outward trip.
		art.box(Vector3(0,1.72,-0.15),Vector3(1.25,0.65,2.7),Color("417c9e"))
		art.sphere(Vector3(0,1.90,-1.9),0.47,Color("e1b795"))
		art.box(Vector3(0,2.11,-1.93),Vector3(1.00,0.27,0.85),Color("cfd9e5"))
	return art.finish()

## A skier lies at the real collision position until the pair arrives;
## the same patient is then drawn only on the return stretcher.
static func casualty_mesh_geometry(style:String)->ArrayMesh:
	if style=="monochrome":
		var lines:=Lines.new()
		lines.box(Vector3(0,0.38,0),Vector3(1.35,0.40,2.9))
		lines.circle(Vector3(0,0.50,-1.65),0.45)
		return lines.finish()
	var art:=Art.new()
	art.box(Vector3(0,0.48,0.1),Vector3(1.25,0.58,2.5),Color("4783ae"))
	art.sphere(Vector3(0,0.59,-1.50),0.48,Color("e5c5ad"))
	art.box(Vector3(0,0.86,-1.53),Vector3(1.1,0.24,0.92),Color("db5039"))
	for x in [-0.40,0.40]:
		art.box(Vector3(x,0.18,2.1),Vector3(0.24,0.18,3.5),Color("354955"))
	return art.finish()

static func lodge_mesh(style: String) -> ArrayMesh:
	if style!="alpine":return Assets.building("hotel",1,Color(str(Styles.detail_tints(style).wood)),style)
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
	staff_meshes.clear()
	for group in CREW_GROUPS:
		var crew: ArrayMesh=human_mesh(view.visual_style,group)
		crew.surface_set_material(0,view._solid)
		var node:=MultiMeshInstance3D.new()
		node.name="Crew "+group
		node.multimesh=view._multimesh(crew,MAX_VISIBLE_STAFF)
		node.multimesh.visible_instance_count=0
		root.add_child(node)
		staff_meshes[group]=node
	staff_mesh=staff_meshes["service"]
	staff_labels.clear()
	for i in range(12):
		var tag:=Label3D.new()
		tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size=24
		tag.pixel_size=0.018
		tag.modulate=Color("e9f3fa")
		tag.visible=false
		root.add_child(tag)
		staff_labels.append(tag)
	var rescue:=rescue_mesh(view.visual_style,false)
	rescue.surface_set_material(0,view._solid)
	emergency_mesh=MultiMeshInstance3D.new()
	emergency_mesh.multimesh=view._multimesh(rescue,MAX_VISIBLE_RESCUE)
	emergency_mesh.multimesh.visible_instance_count=0
	root.add_child(emergency_mesh)
	var return_scene:=rescue_mesh(view.visual_style,true)
	return_scene.surface_set_material(0,view._solid)
	stretcher_mesh=MultiMeshInstance3D.new()
	stretcher_mesh.multimesh=view._multimesh(return_scene,MAX_VISIBLE_RESCUE)
	stretcher_mesh.multimesh.visible_instance_count=0
	root.add_child(stretcher_mesh)
	var mobile_art:=snowmobile_art(view.visual_style,false)
	mobile_art.surface_set_material(0,view._solid)
	snowmobile_mesh=MultiMeshInstance3D.new()
	snowmobile_mesh.multimesh=view._multimesh(mobile_art,MAX_VISIBLE_RESCUE)
	snowmobile_mesh.multimesh.visible_instance_count=0
	root.add_child(snowmobile_mesh)
	var patient_art:=snowmobile_art(view.visual_style,true)
	patient_art.surface_set_material(0,view._solid)
	snowmobile_patient_mesh=MultiMeshInstance3D.new()
	snowmobile_patient_mesh.multimesh=view._multimesh(patient_art,MAX_VISIBLE_RESCUE)
	snowmobile_patient_mesh.multimesh.visible_instance_count=0
	root.add_child(snowmobile_patient_mesh)
	var casualty_art:=casualty_mesh_geometry(view.visual_style)
	casualty_art.surface_set_material(0,view._solid)
	casualty_mesh=MultiMeshInstance3D.new()
	casualty_mesh.multimesh=view._multimesh(casualty_art,MAX_VISIBLE_RESCUE)
	casualty_mesh.multimesh.visible_instance_count=0
	root.add_child(casualty_mesh)

func _person_pos(view: Node3D, staff: Dictionary) -> Vector2:
	var destination_value:Vector2=destination(view.model,staff)
	var progress_value:float=progress(view.model,staff)
	if progress_value>=0.99 and Ops.on_duty(view.model,staff):
		# On-site colleagues stay distinct and perform short forecourt patrols.
		var phase:float=(float(view.model.minute)+float(view.model.clock_fraction))*0.11+float(int(staff.id))*2.399
		var radius:float=1.8+float(int(staff.id)%5)*0.55
		var candidate:=destination_value+Vector2(cos(phase),sin(phase))*radius
		if view.terrain.contains(candidate) and Foot.free_of_buildings(candidate,view.model.buildings,0.8):return candidate
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
	var counts:Dictionary={}
	for group in CREW_GROUPS:counts[group]=0
	var amount:=0
	var label_count:=0
	if lodge_point.is_finite():
		for worker in view.model.operations.staff:
			if amount>=MAX_VISIBLE_STAFF:break
			# Responders are drawn at their real case position, not at their office.
			if Ops._assigned_active_rescue(view.model,worker):continue
			var pos:=_person_pos(view,worker)
			if pos.distance_to(view.focus)>maxf(view.zoom*1.6,190.0):continue
			var group:String=group_for_role(str(worker.role))
			var index:int=int(counts[group])
			var node:MultiMeshInstance3D=staff_meshes[group]
			var rotation:float=sin((float(view.model.minute)+int(worker.id))*0.08)*0.30
			node.multimesh.set_instance_transform(index,Transform3D(Basis(Vector3.UP,rotation),view.terrain.world(pos,0.6)))
			node.multimesh.set_instance_color(index,Color.WHITE)
			counts[group]=index+1
			amount+=1
			if label_count<staff_labels.size() and view.zoom<220.0:
				var tag:Label3D=staff_labels[label_count]
				tag.text=str(worker.get("name","Crew"))+" · "+str(Ops.ROLES.get(str(worker.role),{}).get("name",worker.role))
				tag.position=view.terrain.world(pos,4.8)
				tag.visible=true
				label_count+=1
	for group in CREW_GROUPS:
		var node:MultiMeshInstance3D=staff_meshes[group]
		node.multimesh.visible_instance_count=int(counts[group])
	for index in range(staff_labels.size()):staff_labels[index].visible=index<label_count
	var stranded_count:=0
	for case in view.model.operations.incidents:
		if str(case.get("status","")) not in ["waiting","responding"]:continue
		if stranded_count>=MAX_VISIBLE_RESCUE:break
		var stranded:Vector2=Terrain.unpack(case.point)
		if stranded.distance_to(view.focus)>maxf(view.zoom*2.0,240.0):continue
		casualty_mesh.multimesh.set_instance_transform(stranded_count,Transform3D(Basis.IDENTITY,view.terrain.world(stranded,0.12)))
		casualty_mesh.multimesh.set_instance_color(stranded_count,Color.WHITE)
		stranded_count+=1
	casualty_mesh.multimesh.visible_instance_count=stranded_count
	var outbound_count:=0
	var transport_count:=0
	var mobile_count:=0
	var mobile_patient_count:=0
	for incident in view.model.operations.incidents:
		var stage:String=str(incident.get("status",""))
		if stage not in ["responding","returning"]:continue
		if outbound_count>=MAX_VISIBLE_RESCUE and transport_count>=MAX_VISIBLE_RESCUE:break
		var station:Dictionary=view.model.asset(int(incident.get("station",-1)))
		if station.is_empty():continue
		var visual_minute_fraction:float=view.model.clock_fraction+view.simulation_fraction/float(view.model.time_divisor)
		var pos:Vector2=Ops.rescue_location(view.model,incident,visual_minute_fraction)
		if pos.distance_to(view.focus)>maxf(view.zoom*2.0,240):continue
		var forward:Vector2=Terrain.unpack(incident.point)-Terrain.unpack(station.point)
		var path:Array=Ops.rescue_active_path(incident)
		if path.size()>=2:
			var fraction:float=Ops.rescue_fraction(incident,visual_minute_fraction)
			var forward_path:bool=stage=="responding" or incident.has("return_route_points")
			var next_fraction:float=clampf(fraction+(0.015 if forward_path else -0.015),0,1)
			forward=Ops.rescue_path_point(path,next_fraction)-pos
		var heading:float=atan2(forward.x,forward.y) if forward.length_squared()>0.001 else 0.0
		var transform_value:=Transform3D(Basis(Vector3.UP,heading),view.terrain.world(pos,0.45))
		if str(incident.get("vehicle","skis"))=="snowmobile":
			if stage=="responding" and mobile_count<MAX_VISIBLE_RESCUE:
				snowmobile_mesh.multimesh.set_instance_transform(mobile_count,transform_value)
				snowmobile_mesh.multimesh.set_instance_color(mobile_count,Color.WHITE)
				mobile_count+=1
			elif stage=="returning" and mobile_patient_count<MAX_VISIBLE_RESCUE:
				snowmobile_patient_mesh.multimesh.set_instance_transform(mobile_patient_count,transform_value)
				snowmobile_patient_mesh.multimesh.set_instance_color(mobile_patient_count,Color.WHITE)
				mobile_patient_count+=1
		elif stage=="responding" and outbound_count<MAX_VISIBLE_RESCUE:
			emergency_mesh.multimesh.set_instance_transform(outbound_count,transform_value)
			emergency_mesh.multimesh.set_instance_color(outbound_count,Color.WHITE)
			outbound_count+=1
		elif stage=="returning" and transport_count<MAX_VISIBLE_RESCUE:
			stretcher_mesh.multimesh.set_instance_transform(transport_count,transform_value)
			stretcher_mesh.multimesh.set_instance_color(transport_count,Color.WHITE)
			transport_count+=1
	emergency_mesh.multimesh.visible_instance_count=outbound_count
	stretcher_mesh.multimesh.visible_instance_count=transport_count
	snowmobile_mesh.multimesh.visible_instance_count=mobile_count
	snowmobile_patient_mesh.multimesh.visible_instance_count=mobile_patient_count
