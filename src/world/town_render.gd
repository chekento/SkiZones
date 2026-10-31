extends Node3D
## Original footprints and streets, batched in bounded 256 m chunks.
const Town=preload("res://src/core/town_context.gd")
const Terrain=preload("res://src/core/terrain.gd")
var view: Node
var context: Dictionary={}
var map_id:=""
var cells: Dictionary={}
var pending: Array=[]
var _state:=""
var _material:=StandardMaterial3D.new()
var _window_material:=StandardMaterial3D.new()
var _labels: Node3D
var _bus_nodes: Dictionary={}
var _bus_mesh: Mesh
func setup(controller: Node) -> void:
	view=controller
	_material.vertex_color_use_as_albedo=true;_material.roughness=0.95
	_window_material.vertex_color_use_as_albedo=true;_window_material.roughness=0.35
	_window_material.emission_enabled=true;_window_material.emission=Color("efb983");_window_material.emission_energy_multiplier=0.25
	_labels=Node3D.new();add_child(_labels)
func reset() -> void:
	for child in get_children():child.queue_free()
	cells.clear();pending.clear();_bus_nodes.clear();_state="";map_id="";context={}
	_labels=Node3D.new();add_child(_labels)
func _process(_delta: float) -> void:
	if view==null or not view.model.life_enabled or view.model.map_id not in view.model.Geo.IDS:
		if map_id!="":reset()
		return
	if map_id!=view.model.map_id:
		reset();map_id=view.model.map_id;context=Town.data(map_id)
	var cell:=Vector2i((view.focus/256).floor())
	var radius:=clampi(ceili(view.zoom/300),1,3)
	var detail: bool=view.zoom<850
	var state: String="%s:%s:%d:%s" % [map_id,str(cell),radius,str(detail)]
	if state!=_state:
		_state=state;pending.clear()
		var desired: Dictionary={}
		for x in range(cell.x-radius,cell.x+radius+1):
			for y in range(cell.y-radius,cell.y+radius+1):
				var key:=Vector2i(x,y)
				if not Town.index(map_id).has(key):continue
				desired[key]=true
				if not cells.has(key) or cells[key].detail!=detail:pending.append(key)
		for key in cells.keys():
			if not desired.has(key):cells[key].node.queue_free();cells.erase(key)
		pending.sort_custom(func(a,b):return Vector2(a-cell).length_squared()<Vector2(b-cell).length_squared())
		_relabel(detail)
	if not pending.is_empty():_build_cell(pending.pop_front(),detail)
	_window_material.emission_energy_multiplier=0.65 if view.model.minute<420 or view.model.minute>1080 else 0.08
	_update_buses()
func _vertex(tool: SurfaceTool,point: Vector3,color: Color) -> void:
	tool.set_color(color);tool.add_vertex(point)
func _triangle(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,color: Color) -> void:
	_vertex(tool,a,color);_vertex(tool,b,color);_vertex(tool,c,color)
func _quad(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color) -> void:
	_triangle(tool,a,b,c,color);_triangle(tool,a,c,d,color)
func _build_cell(key: Vector2i,detail: bool) -> void:
	if cells.has(key):cells[key].node.queue_free();cells.erase(key)
	var cell: Dictionary=Town.index(map_id).get(key,{})
	var body:=SurfaceTool.new();body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glass:=SurfaceTool.new();glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var total:=0;var windows:=0
	for n in cell.get("buildings",[]):
		var building: Dictionary=context.buildings[n]
		if Vector2i((Terrain.unpack(building.point)/256).floor())!=key:continue
		var polygon:=PackedVector2Array()
		for p in building.outline.slice(0,-1):polygon.append(Terrain.unpack(p))
		if polygon.size()<3:continue
		var triangles:=Geometry2D.triangulate_polygon(polygon)
		if triangles.is_empty():continue
		var floor_height: float=-INF
		for p in polygon:floor_height=maxf(floor_height,view.ground_position(p).y)
		var height: float=building.height
		var tint:=Color("cfbda4").lerp(Color("e7dcc8"),float(int(building.osm_id)%11)/10)
		if building.tourism!="" or building.amenity!="":tint=Color("d7c4a5")
		for i in range(polygon.size()):
			var a: Vector2=polygon[i];var b: Vector2=polygon[(i+1)%polygon.size()]
			var low_a: Vector3=view.ground_position(a,-0.15);var low_b: Vector3=view.ground_position(b,-0.15)
			var high_a:=Vector3(a.x,floor_height+height,a.y);var high_b:=Vector3(b.x,floor_height+height,b.y)
			_quad(body,low_a,low_b,high_b,high_a,tint);total+=6
			if detail and a.distance_to(b)>4:
				var along: Vector2=(b-a).normalized();var normal:=along.orthogonal()*0.05
				var count:=clampi(floori(a.distance_to(b)/4),1,8)
				for floor_index in range(clampi(floori(height/3),1,5)):
					for index in range(count):
						var point: Vector2=a.lerp(b,float(index+1)/(count+1))+normal
						var side: Vector2=along*0.58;var y: float=floor_height+1.6+floor_index*2.8
						_quad(glass,Vector3(point.x-side.x,y,point.y-side.y),Vector3(point.x+side.x,y,point.y+side.y),Vector3(point.x+side.x,y+1.2,point.y+side.y),Vector3(point.x-side.x,y+1.2,point.y-side.y),Color("879eaa"));windows+=6
		for i in range(0,triangles.size(),3):
			var a: Vector2=polygon[triangles[i]];var b: Vector2=polygon[triangles[i+1]];var c: Vector2=polygon[triangles[i+2]]
			_triangle(body,Vector3(a.x,floor_height+height+0.16,a.y),Vector3(b.x,floor_height+height+0.16,b.y),Vector3(c.x,floor_height+height+0.16,c.y),Color("f4f5f1"));total+=3
	for n in cell.get("roads",[]):
		var road: Dictionary=context.roads[n]
		var width:=7.0 if road.kind in ["primary","secondary","tertiary"] else 5.0 if road.kind in Town.CAR_ROADS else 2.4
		var color:=Color("697774") if road.kind in Town.CAR_ROADS else Color("c8b997")
		var points: Array=[]
		for i in range(1,road.points.size()):
			var a:=Terrain.unpack(road.points[i-1]);var b:=Terrain.unpack(road.points[i])
			var steps:=maxi(1,ceili(a.distance_to(b)/18))
			for j in range(steps):points.append(a.lerp(b,float(j)/steps))
		points.append(Terrain.unpack(road.points[-1]))
		for i in range(1,points.size()):
			var a: Vector2=points[i-1];var b: Vector2=points[i]
			if Vector2i(((a+b)*0.5/256).floor())!=key:continue
			var side_a: Vector2=(points[mini(points.size()-1,i)]-points[maxi(0,i-2)]).normalized().orthogonal()*width*0.5
			var side_b: Vector2=(points[mini(points.size()-1,i+1)]-points[i-1]).normalized().orthogonal()*width*0.5
			_quad(body,view.ground_position(a-side_a,0.23),view.ground_position(b-side_b,0.23),view.ground_position(b+side_b,0.23),view.ground_position(a+side_a,0.23),color);total+=6
	var root:=Node3D.new();add_child(root)
	if total>0:
		body.generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=body.commit();mesh.material_override=_material;root.add_child(mesh)
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if detail else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if windows>0:
		glass.generate_normals();var mesh:=MeshInstance3D.new();mesh.mesh=glass.commit();mesh.material_override=_window_material;root.add_child(mesh)
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cells[key]={"node":root,"detail":detail}
func _relabel(detail: bool) -> void:
	for node in _labels.get_children():node.queue_free()
	if not detail:return
	var candidates: Array=[]
	for poi in context.get("pois",[]):
		var distance: float=Terrain.unpack(poi.point).distance_to(view.focus)
		if poi.name!="" and distance<maxf(240,view.zoom):candidates.append({"poi":poi,"distance":distance})
	candidates.sort_custom(func(a,b):return a.distance<b.distance)
	for item in candidates.slice(0,22):
		var poi: Dictionary=item.poi
		view._label(_labels,poi.name,view.ground_position(Terrain.unpack(poi.point),14),Color("355764"))
	for stop in context.get("stops",[]):
		if Terrain.unpack(stop.point).distance_to(view.focus)>view.zoom:continue
		view._label(_labels,"H · "+str(stop.name),view.ground_position(Terrain.unpack(stop.point),5),Color("467d64"))
func _update_buses() -> void:
	if not view.model.has_method("bus_poses"):return
	for pose in view.model.bus_poses(view.simulation_fraction):
		if not _bus_nodes.has(pose.id):
			var node:=MeshInstance3D.new();node.mesh=_make_bus();node.material_override=_material;add_child(node);_bus_nodes[pose.id]=node
		var node: MeshInstance3D=_bus_nodes[pose.id]
		node.transform=Transform3D(Basis(Vector3.UP,pose.yaw),view.ground_position(pose.point,0.15))
func _make_bus() -> Mesh:
	if _bus_mesh!=null:return _bus_mesh
	var art: RefCounted=load("res://src/world/alpine_art.gd").new()
	_bus_mesh=art.bus_vehicle()
	return _bus_mesh
