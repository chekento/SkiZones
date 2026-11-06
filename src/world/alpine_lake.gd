extends RefCounted
## Purely visual alpine water: shoreline follows the existing terrain.
## No collision, resort coordinates, navigation or save schema changes.
const Styles = preload("res://src/core/visual_styles.gd")
const CENTER := Vector2(-260.0, 255.0)
const X_RADIUS := 53.0
const Z_RADIUS := 32.86
const WATER_Y := 7.38
const SIDES := 96

static func _point(angle: float, radius: float) -> Vector2:
	return CENTER + Vector2(cos(angle) * X_RADIUS, sin(angle) * Z_RADIUS) * radius

static func _vertex(tool: SurfaceTool, at: Vector3, uv: Vector2, color: Color) -> void:
	tool.set_uv(uv)
	tool.set_color(color)
	tool.add_vertex(at)

static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, au: Vector2, bu: Vector2, cu: Vector2, color: Color) -> void:
	# A clockwise XZ winding faces upward, keeping the water visible from above.
	_vertex(tool,a,au,color)
	_vertex(tool,c,cu,color)
	_vertex(tool,b,bu,color)

static func _disc() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(4):
		var inner: float=float(ring)/4.0
		var outer: float=float(ring+1)/4.0
		for segment in range(SIDES):
			var aa := float(segment)*TAU/SIDES
			var ab := float(segment+1)*TAU/SIDES
			var a := _point(aa,inner)
			var b := _point(ab,inner)
			var c := _point(aa,outer)
			var d := _point(ab,outer)
			var origin := Vector3(a.x,WATER_Y,a.y)
			var next := Vector3(b.x,WATER_Y,b.y)
			var edge := Vector3(c.x,WATER_Y,c.y)
			var edge_next := Vector3(d.x,WATER_Y,d.y)
			var ua := Vector2(0.5 + cos(aa)*inner*0.5,0.5 + sin(aa)*inner*0.5)
			var ub := Vector2(0.5 + cos(ab)*inner*0.5,0.5 + sin(ab)*inner*0.5)
			var uc := Vector2(0.5 + cos(aa)*outer*0.5,0.5 + sin(aa)*outer*0.5)
			var ud := Vector2(0.5 + cos(ab)*outer*0.5,0.5 + sin(ab)*outer*0.5)
			_triangle(tool,origin,next,edge,ua,ub,uc,Color.WHITE)
			_triangle(tool,edge,next,edge_next,uc,ub,ud,Color.WHITE)
	tool.generate_normals()
	return tool.commit()

static func _shore(view: Node3D) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Gentle shallow-water shelf, white snow lip and a thin, irregular bank.
	var radii := [0.975,1.005,1.045,1.13]
	var tones := [Color("acdbe0"),Color("f8fbfa"),Color("e5eef0"),Color("d3dee1")]
	for band in range(radii.size()-1):
		for index in range(SIDES):
			var t0 := float(index)*TAU/SIDES
			var t1 := float(index+1)*TAU/SIDES
			var points: Array[Vector3] = []
			for side in [t0,t1]:
				for rr in [float(radii[band]),float(radii[band+1])]:
					var planar := _point(side,rr * (1.0 + 0.007 * sin(side * 17.0)))
					var terrain_y: float=view.ground_position(planar,0.10).y
					var t := smoothstep(1.005,1.13,rr)
					var y := lerpf(WATER_Y+0.025, terrain_y, t)
					points.append(Vector3(planar.x,y,planar.y))
			_triangle(tool,points[0],points[2],points[1],Vector2.ZERO,Vector2.RIGHT,Vector2.UP,tones[band])
			_triangle(tool,points[1],points[2],points[3],Vector2.ZERO,Vector2.RIGHT,Vector2.UP,tones[band])
	tool.generate_normals()
	return tool.commit()

static func build(view: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "Alpine Lake"
	var water := MeshInstance3D.new()
	water.name = "Water"
	water.mesh = _disc()
	var water_shader := ShaderMaterial.new()
	water_shader.shader = preload("res://src/shaders/alpine_lake.gdshader")
	water.material_override = water_shader
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(water)
	var bank := MeshInstance3D.new()
	bank.name = "Shoreline"
	bank.mesh = _shore(view)
	var shore_material := StandardMaterial3D.new()
	shore_material.vertex_color_use_as_albedo = true
	shore_material.vertex_color_is_srgb = true
	shore_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shore_material.roughness = 0.85
	bank.material_override = shore_material
	bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bank)
	apply_style(root,str(view.visual_style))
	return root

static func apply_style(root: Node3D, id: String) -> void:
	if not is_instance_valid(root): return
	var water: MeshInstance3D = root.get_node_or_null("Water")
	if water == null:return
	var palette: Dictionary=Styles.palette(id)
	var deep := Color("275a70").lerp(Color(str(palette.rock)),0.24)
	var shallow := Color("82b9c4").lerp(Color(str(palette.snow)),0.35)
	if id == "monochrome":
		deep = Color("bbbbbb")
		shallow = Color("f0f0f0")
	elif id == "neon_noir":
		deep = Color("245276")
		shallow = Color("83d4e9")
	water.material_override.set_shader_parameter("deep_color",deep)
	water.material_override.set_shader_parameter("edge_color",shallow)
