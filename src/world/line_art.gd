extends RefCounted
## Deliberately sparse, original line models. No triangle wireframes or diagonals.
var vertices:=PackedVector3Array()
func line(a: Vector3,b: Vector3) -> void: vertices.append_array([a,b])
func box(at: Vector3,extent: Vector3) -> void:
	var half:=extent*0.5
	for axis in range(3):
		for first in [-1,1]:
			for second in [-1,1]:
				var a:=Vector3.ZERO
				a[(axis+1)%3]=half[(axis+1)%3]*first
				a[(axis+2)%3]=half[(axis+2)%3]*second
				a[axis]=-half[axis]
				var b:=a;b[axis]=half[axis]
				line(at+a,at+b)
func roof(width: float,depth: float,height_value: float) -> void:
	for z in [-depth*0.5,depth*0.5]:
		line(Vector3(-width*0.5,height_value,z),Vector3(0,height_value+width*0.25,z))
		line(Vector3(width*0.5,height_value,z),Vector3(0,height_value+width*0.25,z))
	line(Vector3(0,height_value+width*0.25,-depth*0.5),Vector3(0,height_value+width*0.25,depth*0.5))
func tree(species: int) -> ArrayMesh:
	line(Vector3.ZERO,Vector3(0,16,0))
	for layer in range(3):
		var y:=4.0+layer*3.5
		var r:float=(2.8-layer*0.6) if species==3 else (6.2-layer*1.4) if species==4 else (5.0-layer*1.3)
		for direction in [Vector3.RIGHT,Vector3.FORWARD]:
			line(Vector3(0,y+4,0),Vector3(0,y,0)+direction*r)
			line(Vector3(0,y+4,0),Vector3(0,y,0)-direction*r)
			if species!=2: line(Vector3(0,y,0)-direction*r,Vector3(0,y,0)+direction*r)
	if species==3: line(Vector3(0,16,0),Vector3(0,19,0))
	return finish()
func circle(at: Vector3,radius: float) -> void:
	for index in range(16):
		var a: float=TAU*index/16.0
		var b: float=TAU*(index+1)/16.0
		line(at+Vector3(cos(a),sin(a),0)*radius,at+Vector3(cos(b),sin(b),0)*radius)
func prop(kind: String) -> ArrayMesh:
	match kind:
		"tree":return tree(0)
		"snowman":circle(Vector3(0,2,0),2);circle(Vector3(0,5,0),1.4);line(Vector3(-3,4,0),Vector3(3,4,0))
		"gifts":
			for x in [-2,2]:box(Vector3(x,1,0),Vector3(3,2,3));line(Vector3(x,0,1.6),Vector3(x,2,1.6))
		"garlands":
			line(Vector3(-6,0,0),Vector3(-6,6,0));line(Vector3(6,0,0),Vector3(6,6,0))
			for i in range(8):line(Vector3(-6+i*1.5,5,0),Vector3(-4.5+i*1.5,5,0))
		"firework","star":
			for index in range(10):
				var angle: float=TAU*index/10.0
				line(Vector3.ZERO,Vector3(cos(angle),sin(angle),0)*4)
		"clock":
			line(Vector3(0,0,0),Vector3(0,8,0));circle(Vector3(0,10,0),2.5)
			line(Vector3(0,10,0),Vector3(0,12,0));line(Vector3(0,10,0),Vector3(1.5,10,0))
		"bench":box(Vector3(0,1.2,0),Vector3(5,.3,2));box(Vector3(0,2.1,-.8),Vector3(5,1.5,.2))
		"lamp":line(Vector3.ZERO,Vector3(0,8,0));box(Vector3(0,7.5,0),Vector3(2,1,1))
		"arch":line(Vector3(-3,0,0),Vector3(-3,6,0));line(Vector3(3,0,0),Vector3(3,6,0));line(Vector3(-3,6,0),Vector3(3,6,0))
		"sculpture":box(Vector3(0,1,0),Vector3(4,2,4));line(Vector3(0,1,0),Vector3(0,7,0));circle(Vector3(0,6,0),1.5)
		"market":box(Vector3(0,2,0),Vector3(10,4,7));roof(12,8,7)
		_:box(Vector3(0,5,0),Vector3(5,8,1));line(Vector3(0,0,0),Vector3(0,10,0))
	return finish()
func finish() -> ArrayMesh:
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var colors:=PackedColorArray();colors.resize(vertices.size());colors.fill(Color.BLACK)
	arrays[Mesh.ARRAY_COLOR]=colors
	var normals:=PackedVector3Array();normals.resize(vertices.size());normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL]=normals
	var mesh:=ArrayMesh.new()
	if not vertices.is_empty():mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES,arrays)
	return mesh
static func bounds_model(source: Mesh) -> ArrayMesh:
	var art=load("res://src/world/line_art.gd").new()
	var rect: AABB=source.get_aabb()
	art.box(rect.get_center(),rect.size)
	return art.finish()
