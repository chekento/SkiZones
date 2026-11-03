extends RefCounted
## A single rounded union replaces overlapping strips of different widths.
## The walking graph is unchanged; picking uses this same visible mesh.
const Terrain = preload("res://src/core/terrain.gd")
var step := 4.0
var cells: Dictionary = {}
var buckets: Dictionary = {}
var corners: Dictionary = {}
const BUCKET := 32.0
const EDGE := 3.2
const MAX_CELLS := 90000

func _primitive(shape: Dictionary, low: Vector2, high: Vector2) -> void:
	for x in range(floori(low.x/BUCKET),floori(high.x/BUCKET)+1):
		for y in range(floori(low.y/BUCKET),floori(high.y/BUCKET)+1):
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
	for shape in buckets.get(Vector2i((point/BUCKET).floor()),[]):
		var distance: float=point.distance_to(shape.a)-float(shape.radius) if shape.circle else point.distance_to(Geometry2D.get_closest_point_to_segment(point,shape.a,shape.b))-float(shape.radius)
		if distance<d:
			tone=shape.tone
			var h := maxf(1.5-absf(d-distance),0)/1.5
			d=distance-h*h*0.375
	return {"point":point,"d":d,"tone":tone}

func build(view: Node3D) -> ArrayMesh:
	cells.clear()
	buckets.clear()
	corners.clear()
	var layout: Dictionary=view._pedestrian_snapshot
	step=8.0 if layout.links.size()>800 else 6.0 if layout.links.size()>350 else 2.5
	for area in layout.areas:
		var radius: float=area.radius
		var center: Vector2=area.center
		_primitive({"circle":true,"a":center,"radius":radius,"tone":0.0},center-Vector2.ONE*(radius+EDGE+step),center+Vector2.ONE*(radius+EDGE+step))
		_disk(center,radius+EDGE)
	for link in layout.links:
		var radius: float=float(link.get("width",7))*0.5
		var tone := 1.0 if link.get("promenade",false) or link.get("public_entry",false) else 0.0
		for index in range(1,link.points.size()):
			var a := Terrain.unpack(link.points[index-1])
			var b := Terrain.unpack(link.points[index])
			_primitive({"circle":false,"a":a,"b":b,"radius":radius,"tone":tone},a.min(b)-Vector2.ONE*(radius+EDGE+step),a.max(b)+Vector2.ONE*(radius+EDGE+step))
			var count := maxi(1,ceili(a.distance_to(b)/step))
			for sample in range(count+1): _disk(a.lerp(b,float(sample)/count),radius+EDGE)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell in cells:
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
				if a.d<=EDGE: clipped.append(a)
				if (a.d<EDGE and b.d>EDGE) or (b.d<EDGE and a.d>EDGE):
					var t := clampf((EDGE-float(a.d))/(float(b.d)-float(a.d)),0,1)
					clipped.append({"point":Vector2(a.point).lerp(b.point,t),"d":EDGE,"tone":lerpf(a.tone,b.tone,t)})
			for index in range(1,clipped.size()-1):
				for vertex in [clipped[0],clipped[index],clipped[index+1]]:
					var bank := clampf(float(vertex.d)/EDGE,0,1)
					var at: Vector3=view.ground_position(vertex.point,0.38+sin(bank*PI)*0.55)
					var color := Color("cbdbe2").lerp(Color("cbbfa9"),vertex.tone)
					color=color.lerp(Color("eaf2f6"),smoothstep(-0.8,EDGE,float(vertex.d)))
					surface.set_color(color)
					surface.add_vertex(at)
	surface.index()
	surface.generate_normals()
	var mesh := surface.commit()
	if mesh==null: return ArrayMesh.new()
	mesh.set_meta("walk_union",true)
	mesh.set_meta("border_width",EDGE)
	mesh.set_meta("cells",cells.size())
	return mesh
