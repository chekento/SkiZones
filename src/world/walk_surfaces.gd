extends RefCounted
## A single rounded union replaces overlapping strips of different widths.
## The walking graph is unchanged; picking uses this same visible mesh.
const Design = preload("res://src/core/walkway_design.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Styles = preload("res://src/core/visual_styles.gd")
const Calendar = preload("res://src/core/annual_festival.gd")
var step := 4.0
var cells: Dictionary = {}
var buckets: Dictionary = {}
var corners: Dictionary = {}
const BUCKET := 32.0
var bucket_size := BUCKET
const EDGE := 3.2
var edge := EDGE
var visual_style := "alpine"
var festival_season := ""
var _tint: Dictionary = {}
const MAX_CELLS := 90000

func _primitive(shape: Dictionary, low: Vector2, high: Vector2) -> void:
	for x in range(floori(low.x/bucket_size),floori(high.x/bucket_size)+1):
		for y in range(floori(low.y/bucket_size),floori(high.y/bucket_size)+1):
			var key := Vector2i(x,y)
			if not buckets.has(key): buckets[key]=[]
			buckets[key].append(shape)

func _disk(point: Vector2, radius: float) -> void:
	if cells.size()>=MAX_CELLS: return
	for x in range(floori((point.x-radius)/step),ceili((point.x+radius)/step)+1):
		for y in range(floori((point.y-radius)/step),ceili((point.y+radius)/step)+1):
			var key := Vector2i(x,y)
			if (Vector2(key)*step+Vector2.ONE*step*0.5).distance_to(point)<=radius+step: cells[key]=true

func _sample(point: Vector2) -> Dictionary:
	var d := INF
	var tone := 0.0
	var surface := "snow"
	var priority := INF
	var grain := Vector2.ZERO
	for shape in buckets.get(Vector2i((point/bucket_size).floor()),[]):
		var distance: float=point.distance_to(shape.a)-float(shape.radius) if shape.circle else point.distance_to(Geometry2D.get_closest_point_to_segment(point,shape.a,shape.b))-float(shape.radius)
		if shape.get("surface", "snow") != "snow" and distance < 0 and distance < priority:
			priority = distance
			surface = shape.surface
			var direction: Vector2 = (shape.b - shape.a).normalized()
			grain = Vector2((point - shape.a).dot(direction), (point - shape.a).dot(direction.orthogonal()))
		if distance<d:
			tone=shape.tone
			var h := maxf(1.5-absf(d-distance),0)/1.5
			d=distance-h*h*0.375
	return {"point":point,"d":d,"tone":tone,"surface":surface,"grain":grain}

var _layout: Dictionary = {}
var _wear := false
var _phase := 4
var _cursor := 0
var _keys: Array = []
var _mesh_tool: SurfaceTool
var _finished_mesh := ArrayMesh.new()

func start(layout: Dictionary, wear: bool = false) -> void:
	cells.clear()
	buckets.clear()
	corners.clear()
	_layout = layout
	_wear = wear
	_tint = Styles.detail_tints(visual_style)
	_phase = 0
	_cursor = 0
	_keys.clear()
	edge = 0.28 if wear else EDGE
	bucket_size = 4.0 if wear else BUCKET
	step=1.0 if wear else 8.0 if layout.links.size()>800 else 6.0 if layout.links.size()>350 else 2.5
	_mesh_tool = SurfaceTool.new()
	_mesh_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if wear: _mesh_tool.set_normal(Vector3.UP)
	_finished_mesh = ArrayMesh.new()

## A small main-thread slice keeps moving snow wear from stalling the resort.
## The static world builder drains the same implementation synchronously.
func advance(view: Node3D, budget_usec: int = 2500) -> bool:
	var started := Time.get_ticks_usec()
	while _phase < 4:
		if _phase == 0:
			if _cursor >= _layout.areas.size():
				_phase=1; _cursor=0
			else:
				_add_area(_layout.areas[_cursor]); _cursor+=1
		elif _phase == 1:
			if _cursor >= _layout.links.size():
				_phase=2; _cursor=0; _keys=cells.keys()
			else:
				_add_link(_layout.links[_cursor]); _cursor+=1
		elif _phase == 2:
			if _cursor >= _keys.size(): _phase=3
			else:
				_add_cell(view,_keys[_cursor]); _cursor+=1
		else:
			_finish(); _phase=4
		if budget_usec > 0 and Time.get_ticks_usec()-started >= budget_usec: return _phase == 4
	return true

func result() -> ArrayMesh:
	return _finished_mesh

func build(view: Node3D, override_layout: Dictionary = {}, wear: bool = false) -> ArrayMesh:
	visual_style = Styles.valid(str(view.get("visual_style")))
	festival_season = Calendar.season(Calendar.device_now())
	start(view._pedestrian_snapshot if override_layout.is_empty() else override_layout,wear)
	advance(view,0)
	return result()

func _add_area(area: Dictionary) -> void:
	var radius: float=area.radius
	var center: Vector2=area.center
	_primitive({"circle":true,"a":center,"radius":radius,"tone":0.0},center-Vector2.ONE*(radius+edge+step),center+Vector2.ONE*(radius+edge+step))
	_disk(center,radius+edge)

func _add_link(link: Dictionary) -> void:
	var radius: float=float(link.get("width",7))*0.5
	var tone := 1.0 if link.get("promenade",false) or link.get("public_entry",false) else 0.0
	for index in range(1,link.points.size()):
		var a := Terrain.unpack(link.points[index-1])
		var b := Terrain.unpack(link.points[index])
		_primitive({"circle":false,"a":a,"b":b,"radius":radius,"tone":tone,"surface":link.get("surface", "snow")},a.min(b)-Vector2.ONE*(radius+edge+step),a.max(b)+Vector2.ONE*(radius+edge+step))
		var count := maxi(1,ceili(a.distance_to(b)/step))
		for sample in range(count+1): _disk(a.lerp(b,float(sample)/count),radius+edge)

func _add_cell(view: Node3D, cell: Vector2i) -> void:
	var vertices: Array=[]
	for offset in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:
		var key: Vector2i=cell+offset
		if not corners.has(key): corners[key]=_sample(Vector2(key)*step)
		vertices.append(corners[key])
	for triangle in [[vertices[0],vertices[1],vertices[2]],[vertices[1],vertices[3],vertices[2]]]:
		var clipped: Array=[]
		for index in range(3):
			var a: Dictionary=triangle[index]
			var b: Dictionary=triangle[(index+1)%3]
			if a.d<=edge: clipped.append(a)
			if (a.d<edge and b.d>edge) or (b.d<edge and a.d>edge):
				var t := clampf((edge-float(a.d))/(float(b.d)-float(a.d)),0,1)
				clipped.append({"point":Vector2(a.point).lerp(b.point,t),"d":edge,"tone":lerpf(a.tone,b.tone,t),"surface":a.surface if t < 0.5 else b.surface,"grain":Vector2(a.grain).lerp(b.grain,t)})
		for index in range(1,clipped.size()-1):
			for vertex in [clipped[0],clipped[index],clipped[index+1]]:
				var bank := clampf(float(vertex.d)/edge,0,1)
				var at: Vector3=view.surface_position(vertex.point) + Vector3.UP * 0.045 if _wear else view.ground_position(vertex.point,0.095+sin(bank*PI)*0.018)
				var tint: Dictionary = _tint
				var color := Color(tint.snow).lerp(Color(tint.wood),vertex.tone*0.22)
				if vertex.surface != "snow": color = Color(Design.SURFACES[vertex.surface].color).lerp(Color(tint.stone),0.20)
				if visual_style == "monochrome": color = Color("eeeeee") if vertex.surface == "snow" else Color("bcbcbc")
				if festival_season in ["advent","christmas"]: color=color.lerp(Color("c5e2d4"),0.18)
				if festival_season in ["new_year_eve","new_year"]: color=color.lerp(Color("bcdaed"),0.24)
				if _wear: color = Color("a8c5d0").lerp(Color("dae7ed"),smoothstep(-0.4,edge,float(vertex.d)))
				else: color=color.lerp(Color(tint.snow),smoothstep(-0.8,edge,float(vertex.d)))
				_mesh_tool.set_uv(vertex.grain)
				_mesh_tool.set_uv2(Vector2(Design.SURFACES.keys().find(vertex.surface), 1.0-smoothstep(-0.8,edge,float(vertex.d))))
				_mesh_tool.set_color(color)
				_mesh_tool.add_vertex(at)

func _finish() -> void:
	if not _wear:
		_mesh_tool.index()
		_mesh_tool.generate_normals()
	var mesh := _mesh_tool.commit()
	if mesh==null: mesh=ArrayMesh.new()
	mesh.set_meta("walk_union",true)
	mesh.set_meta("border_width",edge)
	mesh.set_meta("cells",cells.size())
	_finished_mesh = mesh
