extends RefCounted
## Small original 3D models, baked into one colored mesh per asset.
const Catalog = preload("res://src/core/catalog.gd")
const Fleet = preload("res://src/core/lift_fleet.gd")
const VisualStyles = preload("res://src/core/visual_styles.gd")

var surface := SurfaceTool.new()

func _init() -> void:
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

func add(mesh: Mesh, position_value: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO, size_value: Vector3 = Vector3.ONE, preserve_colors: bool = false) -> void:
	var basis := Basis.from_euler(rotation).scaled(size_value)
	var transform_value := Transform3D(basis, position_value)
	var normal_basis := basis.inverse().transposed()
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var count := indices.size() if not indices.is_empty() else vertices.size()
	for i in range(count):
		var index := indices[i] if not indices.is_empty() else i
		var normal := (normal_basis * normals[index]).normalized()
		var tint: Color = color * colors[index] if preserve_colors and not colors.is_empty() else color
		surface.set_color(tint if preserve_colors else _face_tint(tint, normal))
		surface.set_normal(normal)
		surface.add_vertex(transform_value * vertices[index])

func _face_tint(color: Color, normal: Vector3) -> Color:
	# Preserve the alpha clothing mask while carving out warm tops and cool sides.
	var light := clampf(0.78 + normal.dot(Vector3(-0.42,0.80,0.35).normalized()) * 0.22, 0.60, 1.0)
	var result := Color(color.r * light, color.g * light, color.b * light, color.a)
	return result

func box(position_value: Vector3, size_value: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	add(mesh, position_value, color, rotation)

func _facet(points: Array, normal: Vector3, color: Color) -> void:
	# Chamfers are baked into the same mesh, with no extra materials or nodes.
	for i in range(1, points.size() - 1):
		var triangle := [points[0], points[i], points[i + 1]]
		if (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).dot(normal) > 0:
			triangle.reverse()
		for point in triangle:
			surface.set_color(_face_tint(color, normal));surface.set_normal(normal);surface.add_vertex(point)

func soft_box(at: Vector3, size_value: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO, radius: float = 0.24) -> void:
	var half := size_value * 0.5
	var bevel := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.65)
	var core := half - Vector3.ONE * bevel
	var basis := Basis.from_euler(rotation)
	for axis in range(3):
		var a := (axis + 1) % 3;var b := (axis + 2) % 3
		for sign_value in [-1, 1]:
			var normal := Vector3.ZERO;normal[axis] = sign_value
			var points: Array = []
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var p := Vector3.ZERO;p[axis] = half[axis] * sign_value;p[a] = core[a] * corner.x;p[b] = core[b] * corner.y
				points.append(at + basis * p)
			_facet(points, basis * normal, color)
		for sa in [-1,1]:
			for sb in [-1,1]:
				var normal := Vector3.ZERO;normal[a] = sa;normal[b] = sb
				var points: Array = []
				for corner in [Vector2(-1,0),Vector2(1,0),Vector2(1,1),Vector2(-1,1)]:
					var p := Vector3.ZERO;p[axis] = core[axis] * corner.x
					p[a] = (half[a] if corner.y == 0 else core[a]) * sa
					p[b] = (core[b] if corner.y == 0 else half[b]) * sb
					points.append(at + basis * p)
				_facet(points, basis * normal.normalized(), color)
	for sx in [-1,1]:
		for sy in [-1,1]:
			for sz in [-1,1]:
				var normal := Vector3(sx,sy,sz);var points: Array = []
				for axis in range(3):
					var p := core * normal;p[axis] = half[axis] * normal[axis]
					points.append(at + basis * p)
				_facet(points, basis * normal.normalized(), color)

func cone(position_value: Vector3, radius: float, height_value: float, color: Color, top: float = 0.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = top
	mesh.height = height_value
	mesh.radial_segments = 8
	add(mesh, position_value, color)

func sphere(position_value: Vector3, radius: float, color: Color, size_value: Vector3 = Vector3.ONE) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 8
	mesh.rings = 3
	add(mesh, position_value, color, Vector3.ZERO, size_value)

func link(from: Vector3, to: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 6
	var basis := Basis(Quaternion(Vector3.UP, (to - from).normalized()))
	add(mesh, (from + to) * 0.5, color, basis.get_euler())

func finish() -> ArrayMesh:
	surface.index()
	return surface.commit()

func tree_variant(style_id: String, species: int, simplified: bool = false) -> ArrayMesh:
	if species == 0: return pine_painted(style_id, simplified)
	var bark := Color("79614d")
	var snow := Color("e7eef3")
	var tint := Color("69866a") if species == 1 else Color("7d8474")
	if style_id == "pastel": tint = tint.lerp(Color("c5bfc0"),0.38)
	if style_id == "comic": tint = tint.lightened(0.12)
	if style_id == "cinematic": tint = tint.darkened(0.18)
	cone(Vector3(0,7,0),0.55,14,bark,0.16)
	var spread: float={"alpine":1.0,"comic":1.12,"pastel":0.92,"cinematic":1.04,"crisp":0.98,"piste_map":0.86}.get(style_id,1.0)
	var layers := 3 if simplified else 6
	for i in range(layers):
		var y := 4.0 + i * 9.0 / layers
		var radius := 4.3 * spread * (1.0 - float(i) / (layers + 1))
		if species == 1:
			cone(Vector3(0,y+1,0),radius,3.4,tint.lightened(i*0.02),0.12)
			cone(Vector3(0,y+1.65,0),radius*0.88,2.4,snow,0.10)
		else:
			for side in [-1,1]:
				var end := Vector3(side*radius,y+1.2,side*radius*0.4)
				link(Vector3(0,y,0),end,0.12 if simplified else 0.18,bark)
				if not simplified:
					link(end*Vector3(0.7,1,0.7),end+Vector3(-side*0.6,1.4,1.0),0.09,bark)
				soft_box(end+Vector3(0,0.2,0),Vector3(radius*0.9,0.32,0.65),snow,Vector3(0,-side*0.3,side*0.17),0.12)
	return finish()

func landscape_detail(kind: int, style_id: String = "alpine") -> ArrayMesh:
	# The original six Alpine models and their colors remain unchanged.
	# Alternate styles intentionally change silhouettes and props, not just tint.
	var colors: Dictionary = VisualStyles.detail_tints(style_id)
	var snow := Color(str(colors.get("snow","eaf1f5")))
	var stone := Color(str(colors.get("stone","8a969b")))
	var wood := Color(str(colors.get("wood","79604c")))
	var flora := Color(str(colors.get("flora","768c7e")))
	var metal := Color(str(colors.get("metal","b7cbd0")))
	var sharp: bool = style_id in ["comic","cinematic","crisp"]
	match kind:
		0: # Small rock cluster: faceted chunks for graphic themes.
			for i in range(4):
				var at := Vector3(sin(i*2.4)*1.8,0.25,cos(i*2.4)*1.4)
				if sharp:
					box(at,Vector3(1.0+i*0.18,0.55+i*0.15,0.85+i*0.1),stone,Vector3(0,i*0.5,0.1*i))
					box(at+Vector3(0,0.40,0),Vector3(1.15+i*0.1,0.14,1.0),snow)
				else:
					sphere(at,0.7+i*0.12,stone,Vector3(1.2,0.6,0.85))
					sphere(at+Vector3(0,0.33,0),0.60+i*0.1,snow,Vector3(1.2,0.18,0.85))
		1: # Alpine shrubs, colorful geometric twigs for contrasting themes.
			for i in range(5):
				var tip := Vector3(sin(i*2.4)*1.5,1.5+i*0.17,cos(i*2.4))
				link(Vector3.ZERO,tip,0.09,wood if style_id != "alpine" else Color("826c55"))
				link(tip*0.62,tip+Vector3(0.5,0.3,0.4),0.06,flora if style_id != "alpine" else Color("826c55"))
				if style_id in ["comic","pastel"]: sphere(tip,0.33,flora)
		2: # Fallen log and freshly drifted snow.
			link(Vector3(-3,0.6,0),Vector3(3,0.8,0.5),0.65,wood)
			if sharp: box(Vector3(0,1.12,0.2),Vector3(5.5,0.4,1.05),snow,Vector3(0,-0.08,0))
			else: soft_box(Vector3(0,1.12,0.2),Vector3(5.5,0.5,1.05),snow,Vector3(0,-0.08,0),0.2)
			link(Vector3(0.8,0.9,0.2),Vector3(1.3,1.7,-1),0.18,wood)
		3: # Different dramatic snow bank profiles.
			if sharp:
				for i in range(3):
					cone(Vector3(-1.4+i*1.3,0.6+i*0.15,0),1.2+i*0.12,1.4+i*0.25,snow)
			else:
				sphere(Vector3(0,0.35,0),2.2,Color("d2dfe8") if style_id == "alpine" else stone.lightened(0.45),Vector3(2.6,0.40,1.0))
				sphere(Vector3(-0.6,0.7,0),1.9,snow,Vector3(2.4,0.30,0.8))
		4: # Cut stump.
			cone(Vector3(0,0.7,0),0.9,1.4,wood if style_id != "alpine" else Color("80624d"),0.7)
			cone(Vector3(0,1.42,0),0.72,0.16,snow,0.68)
			for side in [-1,1]: link(Vector3.ZERO,Vector3(side*1.5,0.1,0.6),0.25,wood if style_id != "alpine" else Color("80624d"))
		5: # Rock outcrop with a striking edge.
			if sharp:
				box(Vector3(0,1.2,0),Vector3(2.9,2.2,2.6),stone,Vector3(0,0.33,0.16))
				box(Vector3(-0.25,2.35,0),Vector3(3.1,0.22,2.4),snow,Vector3(0,0.33,0))
			else:
				sphere(Vector3(0,1.2,0),2.3,stone,Vector3(1.3,0.8,1.0))
				sphere(Vector3(-0.3,2.25,0),2.0,snow,Vector3(1.2,0.20,0.9))
			box(Vector3(0,1.2,1.65),Vector3(2.9,0.15,0.12),stone.darkened(0.25),Vector3(0,0,0.1))
		6: # Frost crystals / glittering low-poly shards.
			for i in range(5):
				var at := Vector3(sin(i*2.4)*1.4,0.72,cos(i*2.4)*1.4)
				cone(at,0.52,1.5+i*0.2,metal,0.02)
		7: # Shallow frozen pond with snow rim.
			sphere(Vector3.ZERO,2.7,stone.lightened(0.20),Vector3(1.4,0.10,0.85))
			sphere(Vector3(0,0.12,0),2.4,metal,Vector3(1.3,0.05,0.77))
			for i in range(3):
				box(Vector3(-1.8+i*1.6,0.16,0.4),Vector3(0.9,0.03,0.08),snow,Vector3(0,0.2*i,0))
		8: # Small trail sign, clear of paths because clearing is shared.
			link(Vector3.ZERO,Vector3(0,3.7,0),0.16,wood)
			box(Vector3(0.8,3.15,0),Vector3(2.3,0.65,0.20),metal)
			box(Vector3(-0.6,2.25,0),Vector3(1.8,0.42,0.20),wood)
			cone(Vector3(0,3.80,0),0.5,0.3,snow)
		9: # Snow-covered alpine flower and shrub patch.
			for i in range(6):
				var angle := i*TAU/6.0
				var tip := Vector3(cos(angle)*1.6,1.1, sin(angle)*1.6)
				link(Vector3.ZERO,tip,0.10,flora)
				sphere(tip,0.32,flora.lightened(0.28))
				sphere(tip+Vector3(0,0.17,0),0.22,snow)
		10: # Tiny snowbound boulder / cliff fragment.
			box(Vector3(0,0.85,0),Vector3(3.8,1.5,2.8),stone,Vector3(0,0.36,0.16))
			box(Vector3(0,1.75,0),Vector3(3.6,0.23,2.5),snow,Vector3(0,0.36,0))
			box(Vector3(1.0,0.6,1.2),Vector3(0.18,1.1,0.08),metal)
		11: # Lightly stylized ridge of crystalline ice.
			for i in range(3):
				var x := -1.35+i*1.4
				cone(Vector3(x,1.4+i*0.18,0),0.95,2.7+i*0.5,stone.lightened(0.16),0.02)
				cone(Vector3(x,2.65+i*0.18,0),0.50,1.15,snow,0.01)
		12: # Snow fence with hand-carved posts.
			for x in [-3,0,3]:
				link(Vector3(x,0,0),Vector3(x,2.7,0),0.16,wood)
				cone(Vector3(x,2.9,0),0.35,0.55,snow)
			for y in [0.8,1.9]:link(Vector3(-3,y,0),Vector3(3,y,0),0.12,wood)
		13: # Small alpine cairn.
			for i in range(4):
				var y:=0.45+i*0.59
				soft_box(Vector3(0,y,0),Vector3(2.6-i*0.48,0.72,1.8-i*0.23),stone,Vector3(0,i*0.34,0.08),0.15)
			soft_box(Vector3(0,2.91,0),Vector3(0.7,0.22,0.64),snow)
		14: # Snowy rest bench.
			for x in [-1.8,1.8]:
				box(Vector3(x,0.65,0),Vector3(0.25,1.3,0.35),wood)
				box(Vector3(x,1.7,-0.8),Vector3(0.24,2.0,0.3),wood)
			box(Vector3(0,1.45,0),Vector3(4.6,0.28,1.8),wood)
			box(Vector3(0,2.2,-0.87),Vector3(4.6,1.1,0.20),wood)
			box(Vector3(0,1.67,0),Vector3(4.3,0.18,1.5),snow)
		15: # Alpine wild-berry and alpine flower clump.
			for i in range(8):
				var angle:=i*TAU/8.0
				var tip:=Vector3(cos(angle)*1.6,1.4+sin(i)*0.4,sin(angle)*1.4)
				link(Vector3.ZERO,tip,0.12,flora)
				sphere(tip,0.26,Color("cb8d99") if i%2==0 else flora.lightened(0.32))
		16: # Bent snow branch.
			for i in range(4):
				var angle:=float(i)*0.82
				var tip:=Vector3(cos(angle)*2.7,0.5+float(i)*0.24,sin(angle)*1.8)
				link(Vector3(-1,0.2,0),tip,0.16,wood)
				sphere(tip,0.3,snow)
		17: # Small wedge of natural compacted snow.
			for i in range(4):
				var x:float=-2.0+i*1.30
				cone(Vector3(x,0.45+i*0.08,0),1.12,1.25,stone.lightened(0.3),0.04)
				cone(Vector3(x,1.05+i*0.08,0),0.68,0.42,snow,0.02)
		18: # Hiking direction stake.
			link(Vector3(0,0,0),Vector3(0,4.4,0),0.17,wood)
			box(Vector3(1.0,3.6,0),Vector3(2.8,0.7,0.24),metal)
			box(Vector3(-0.6,2.7,0),Vector3(1.9,0.53,0.23),snow)
		19: # Timber and rope barriers for snowdrifts.
			for x in [-2.0,2.0]:
				link(Vector3(x,0,0),Vector3(x,2.8,0),0.14,wood)
			for i in range(8):
				var x:float=-1.75+i*0.50
				var y:float=2.0-0.45*sin(float(i)*PI/7)
				link(Vector3(x,y,0),Vector3(x+0.5,2.0-0.45*sin(float(i+1)*PI/7),0),0.08,metal)
		20: # Stack of firewood / lumber.
			for row in range(3):
				for i in range(4-row):
					var x:float=(i-(3-row)*0.5)*1.0
					link(Vector3(x,0.42+row*0.75,-1.5),Vector3(x,0.42+row*0.75,1.5),0.43,wood)
			box(Vector3(0,2.85,0),Vector3(4.4,0.33,3.5),snow)
		21: # Small wooden mailbox / tourist sign.
			link(Vector3(0,0,0),Vector3(0,3.3,0),0.22,wood)
			soft_box(Vector3(0,3.5,0.2),Vector3(2.7,1.55,1.25),metal,Vector3.ZERO,0.17)
			box(Vector3(0,3.8,0.87),Vector3(1.65,0.2,0.13),wood)
		22: # Snow lantern / mountain light.
			link(Vector3(0,0,0),Vector3(0,3.4,0),0.12,wood)
			box(Vector3(0,3.8,0),Vector3(1.8,1.9,1.8),metal)
			box(Vector3(0,3.8,0.96),Vector3(1.4,1.4,0.1),Color("fff1bc"))
			cone(Vector3(0,4.9,0),1.4,0.7,snow)
		23: # Snow-dusted stone arch / scenic marker.
			for x in [-2,2]:
				box(Vector3(x,1.5,0),Vector3(1.0,3.0,1.4),stone)
				box(Vector3(x,3.2,0),Vector3(1.1,0.35,1.5),snow)
			box(Vector3(0,3.7,0),Vector3(5.6,1.0,1.55),stone)
			box(Vector3(0,4.25,0),Vector3(6.0,0.28,1.7),snow)
	return finish()

func wildlife(kind: int) -> ArrayMesh:
	var hare := kind == 2
	var fox := kind == 1
	var coat := Color("e4e7df") if hare else Color("b76535") if fox else Color("987451")
	var scale_value := 0.55 if hare else 0.85 if fox else 1.25
	sphere(Vector3(0,1.15,0)*scale_value,0.8,coat,Vector3(0.62,0.65,1.4)*scale_value)
	sphere(Vector3(0,1.62,0.92)*scale_value,0.47,coat,Vector3(0.8,1,1.15))
	for side in [-1,1]:
		for z in [-0.55,0.55]:
			link(Vector3(side*0.32,0.95,z)*scale_value,Vector3(side*0.32,0.10,z+0.12)*scale_value,0.09*scale_value,coat.darkened(0.25))
		cone(Vector3(side*0.25,2.0 if not hare else 2.25,0.85)*scale_value,0.14*scale_value,(0.45 if not hare else 0.85)*scale_value,coat)
		sphere(Vector3(side*0.29,1.72,1.20)*scale_value,0.065,Color("29353a"))
	if fox:
		link(Vector3(0,1.15,-0.8),Vector3(0.1,0.75,-1.8),0.25,coat)
		sphere(Vector3(0.1,0.75,-1.85),0.26,Color("eee7d7"))
	elif not hare:
		for side in [-1,1]:
			link(Vector3(side*0.22,2.0,0.9),Vector3(side*0.45,2.8,0.65),0.07,Color("67594a"))
			link(Vector3(side*0.36,2.5,0.75),Vector3(side*0.70,2.7,0.80),0.055,Color("67594a"))
	return finish()

func piste_feature(kind: String) -> ArrayMesh:
	if kind == "rail":
		for z in [-2.3,2.3]:
			for side in [-1,1]: link(Vector3(side*0.65,0,z),Vector3(side*0.45,0.85,z),0.09,Color("3f6771"))
		soft_box(Vector3(0,0.94,0),Vector3(1.1,0.30,6.4),Color("518e9b"),Vector3.ZERO,0.10)
		box(Vector3(0,1.105,0),Vector3(0.85,0.025,6.0),Color("dcecf1"))
	else:
		var length_value := 12.0 if kind == "roller" else 10.0
		var width := 4.8
		for i in range(10):
			var z0 := -length_value*0.5+i*length_value/10
			var z1 := z0+length_value/10
			var y0 := sin(float(i)/10*PI)*0.85 if kind == "roller" else _ramp_profile(float(i)/10)
			var y1 := sin(float(i+1)/10*PI)*0.85 if kind == "roller" else _ramp_profile(float(i+1)/10)
			_facet([Vector3(-width/2,y0,z0),Vector3(width/2,y0,z0),Vector3(width/2,y1,z1),Vector3(-width/2,y1,z1)],Vector3(0,1,(y0-y1)/(z1-z0)).normalized(),Color("edf5f8"))
			for side in [-1,1]:
				_facet([Vector3(side*width/2,0,z0),Vector3(side*width/2,y0,z0),Vector3(side*width/2,y1,z1),Vector3(side*width/2,0,z1)],Vector3(side,0,0),Color("b3cbd9"))
		for side in [-1,1]:
			link(Vector3(side*3,0,-4.4),Vector3(side*3,1.9,-4.4),0.06,Color("d99160"))
			box(Vector3(side*3,1.6,-4.4),Vector3(0.7,0.45,0.08),Color("e9ae70"))
	return finish()

func _ramp_profile(t: float) -> float:
	return smoothstep(0,0.70,t)*1.35 if t < 0.70 else (1.0-smoothstep(0.70,1.0,t))*1.35

func _facade_details(kind: String, width: float, depth: float, height_value: float, accent: Color) -> void:
	var timber := Color("725541")
	for side in [-1,1]:
		box(Vector3(side*(width*0.5-0.6),height_value/2,depth/2+0.3),Vector3(0.65,height_value,0.8),timber)
		soft_box(Vector3(side*(width*0.5-2),1.8,depth/2+2),Vector3(2.3,2.4,2),accent.darkened(0.2),Vector3.ZERO,0.2)
		cone(Vector3(side*(width*0.5-2),3.3,depth/2+2),1.25,1.3,Color("6b896a"))
	if Catalog.LODGING.has(kind):
		box(Vector3(0,height_value-0.8,depth/2+0.5),Vector3(width+1,0.45,0.5),timber)
		for side in [-1,1]:
			box(Vector3(side*3.4,3,depth/2+3),Vector3(0.4,6,0.4),timber)
		soft_box(Vector3(0,6.1,depth/2+2.7),Vector3(8.2,0.6,5.4),accent,Vector3.ZERO,0.2)
		soft_box(Vector3(0,6.55,depth/2+2.7),Vector3(8.5,0.45,5.7),Color("eff4f6"),Vector3.ZERO,0.2)
		if kind in ["hotel","grand_hotel"]:
			for x in range(-2,3): sphere(Vector3(x*1.4,9.4,depth/2+1.45),0.32,Color("ecc674"),Vector3(1,1,0.35))
	elif kind in ["restaurant","pizzeria","bar","disco"]:
		for side in [-1,1]:
			box(Vector3(side*(width/2-2),5,depth/2+1),Vector3(0.18,3,0.18),timber)
			sphere(Vector3(side*(width/2-2),5,depth/2+1.3),0.48,Color("f4cf88"),Vector3(0.65,1.2,0.65))
	elif kind in ["maintenance","repair_office"]:
		soft_box(Vector3(width/2-5,4,depth/2+0.5),Vector3(7,6,0.5),Color("59747c"))
		for y in range(2,7): box(Vector3(width/2-5,y,depth/2+0.8),Vector3(6.5,0.10,0.15),Color("8da4aa"))

func piste_sign(number: int, color: Color) -> ArrayMesh:
	# Round Alpine route marker: white rim, difficulty color, number on both faces.
	box(Vector3(0, 2.1, 0), Vector3(0.22, 4.2, 0.22), Color("8a9b9f"))
	var disc := CylinderMesh.new()
	disc.top_radius = 1.4
	disc.bottom_radius = 1.4
	disc.height = 0.16
	disc.radial_segments = 32
	add(disc, Vector3(0, 4.4, 0), Color("f5f6ec"), Vector3(PI / 2, 0, 0))
	var face := CylinderMesh.new()
	face.top_radius = 1.23
	face.bottom_radius = 1.23
	face.height = 0.18
	face.radial_segments = 32
	add(face, Vector3(0, 4.4, 0), color, Vector3(PI / 2, 0, 0))
	var text := TextMesh.new()
	text.font = ThemeDB.fallback_font
	text.text = str(number)
	text.font_size = 64
	text.pixel_size = minf(0.033, 2.0 / maxf(1, text.font.get_string_size(text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x))
	text.depth = 0.015
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for side in [-1, 1]:
		add(text, Vector3(0, 4.4, side * 0.12), Color("ffffff"), Vector3(0, PI if side == -1 else 0, 0))
	return finish()

func downhill_arrow() -> ArrayMesh:
	# Points along local -Z; the view aligns this with the terrain's downhill vector.
	box(Vector3(0, 0, 1.5), Vector3(1.4, 0.12, 8), Color("edf7ee"))
	for side in [-1, 1]:
		box(Vector3(side * 2, 0, -1.5), Vector3(1.4, 0.12, 6), Color("edf7ee"), Vector3(0, side * 0.72, 0))
	return finish()

func pine() -> ArrayMesh:
	cone(Vector3(0, 2.3, 0), 0.62, 4.6, Color("ad8b70"), 0.42)
	sphere(Vector3(0,0.55,0),2.3,Color("eef3fa"),Vector3(1,0.28,1))
	for index in range(4):
		var y := 3.6 + index * 2.9
		var radius := 4.8 - index * 1.02
		var shift := Vector3(sin(index*1.7)*0.24,0,cos(index*1.3)*0.24)
		cone(Vector3(0,y,0)+shift,radius,4.5,Color("467d75").lightened(index*0.025),radius*0.18)
		cone(Vector3(0,y+0.90,0)+shift,radius*0.94,3.6,Color("f2f6fc"),radius*0.09)
		for branch in range(4):
			var angle := index*0.9+branch*TAU/4
			var at := Vector3(cos(angle)*radius*0.58,y-0.05,sin(angle)*radius*0.58)+shift
			sphere(at,radius*0.46,Color("e8eff9"),Vector3(1,0.38,1))
	sphere(Vector3(0,14.7,0),0.46,Color("f5f7fc"),Vector3(0.8,1.4,0.8))
	return finish()

func pine_distant() -> ArrayMesh:
	cone(Vector3(0, 3, 0), 0.5, 6, Color("71583e"))
	for index in range(3):
		var y := 3.0 + index * 4
		var radius := 5.0 - index * 1.4
		cone(Vector3(0, y + 2, 0), radius, 6.5, Color("467d75"),radius*0.12)
		cone(Vector3(0, y + 3, 0), radius * 0.94, 5.2, Color("f2f6fc"),radius*0.06)
	return finish()

func pine_painted(style_id: String, simplified: bool = false) -> ArrayMesh:
	# Original silhouette variants; a visual style changes the tree's actual
	# geometry rather than simply tinting the same alpine conical pine.
	if style_id == "alpine":
		return pine_distant() if simplified else pine()
	var trunk := Color("826954")
	cone(Vector3(0, 2.6, 0), 0.66, 5.2, trunk, 0.36)
	match style_id:
		"comic":
			# Round, cute snow-puff tree with playful separate foliage balls.
			for tier in range(3 if simplified else 4):
				var y := 4.0 + tier * 3.2
				var radius := 4.8 - tier * 0.78
				sphere(Vector3(0, y, 0), radius, Color("43a7a1").lightened(tier*0.08), Vector3(1.06, 0.60, 1.06))
				sphere(Vector3(0, y + radius*0.42, 0), radius*0.76, Color("f8fcff"), Vector3(1.0, 0.35, 1.0))
			sphere(Vector3(0, 15.3, 0), 0.75, Color("fff2ae"))
		"pastel":
			# Impressionistic lavender clusters and delicate snowy light beads.
			for tier in range(3 if simplified else 5):
				var y := 3.8 + tier * 2.48
				var radius := 4.7 - tier * 0.56
				var main := Color("bca7d5") if tier % 2 == 0 else Color("8ebdb6")
				for cluster in range(3 if simplified else 5):
					var angle := tier*0.67 + cluster*TAU/(3.0 if simplified else 5.0)
					var at := Vector3(cos(angle)*radius*0.48, y + sin(angle*1.4)*0.30, sin(angle)*radius*0.48)
					sphere(at, radius*0.58, main.lightened(cluster*0.035), Vector3(1.0, 0.75, 1.0))
					if not simplified:
						sphere(at+Vector3(0,radius*0.33,0),radius*0.43,Color("fff1f9"),Vector3(1.0,0.35,1.0))
			sphere(Vector3(0,16.1,0),0.62,Color("ffe5ea"))
		"cinematic":
			# Tall dark forest trees: clearly separated branches and deep
			# shadow cones for a dramatic painterly mountain forest.
			for tier in range(4 if simplified else 6):
				var y := 3.0 + tier * 2.45
				var radius := 5.0 - tier * 0.68
				cone(Vector3(0,y,0),radius,3.5,Color("345451").lightened(tier*0.028),radius*0.07)
				if not simplified:
					for side in range(4):
						var angle := side*PI*0.5 + tier*0.39
						var tip := Vector3(cos(angle)*radius*0.78,y-0.65,sin(angle)*radius*0.78)
						link(Vector3(0,y+0.55,0),tip,0.22,Color("576b61"))
						sphere(tip,0.84,Color("d7e0df"),Vector3(1.45,0.34,1.0))
		"piste_map":
			# Flat editorial pines, blocky silhouette from a printed ski map.
			for tier in range(3 if simplified else 5):
				var y:=3.2+tier*2.6
				var radius:=5.0-tier*0.72
				cone(Vector3(0,y,0),radius,2.45,Color("62866c"),radius*0.08)
				box(Vector3(0,y+1.1,0),Vector3(radius*0.7,0.4,radius*0.7),Color("f2f0dc"))
			cone(Vector3(0,16,0),0.65,1.4,Color("739b77"),0.03)
		"crisp":
			# Sharp frosty layers and little facets, like paper-cut glass.
			for tier in range(4 if simplified else 6):
				var y := 3.15 + tier * 2.25
				var radius := 5.2 - tier * 0.74
				cone(Vector3(0,y,0),radius,3.85,Color("467f93").lightened(tier*0.035),0.10)
				cone(Vector3(0,y+0.84,0),radius*0.92,2.75,Color("eefaff"),0.02)
			cone(Vector3(0,16.45,0),0.75,1.9,Color("ffffff"),0.0)
		_:
			return pine_distant() if simplified else pine()
	return finish()

func plaza_details() -> ArrayMesh:
	# One batched set: timber seat, bin, warm lantern and a little route board.
	box(Vector3(0, 1.1, 0), Vector3(5.2, 0.38, 1.9), Color("b28b5b"))
	for side in [-1, 1]:
		box(Vector3(side * 1.85, 0.5, 0), Vector3(0.28, 1.1, 1.6), Color("48666a"))
		box(Vector3(side * 1.85, 1.8, -0.7), Vector3(0.24, 2.3, 0.24), Color("48666a"))
	box(Vector3(0, 2.0, -0.75), Vector3(5.2, 1.25, 0.25), Color("a67b4f"))
	soft_box(Vector3(0,2.67,-0.75),Vector3(5.4,0.26,0.75),Color("f0f4fc"))
	for x in [-1.8, -0.6, 0.6, 1.8]:
		box(Vector3(x, 1.31, 0), Vector3(0.06, 0.03, 1.8), Color("73583d"))
	box(Vector3(4.3, 1.1, 0), Vector3(1.4, 2.2, 1.4), Color("54756d"))
	box(Vector3(4.3, 2.3, 0), Vector3(1.65, 0.22, 1.65), Color("e4eef0"))
	cone(Vector3(-4, 3, 0), 0.15, 6, Color("475f66"), 0.15)
	box(Vector3(-4, 6.2, 0), Vector3(0.9, 1.25, 0.9), Color("ffe2aa"))
	box(Vector3(-4, 7, 0), Vector3(1.3, 0.25, 1.3), Color("4c6970"))
	sphere(Vector3(-4,7.22,0),0.85,Color("f0f4fc"),Vector3(1,0.35,1))
	for x in [-0.52, 0.52]:
		box(Vector3(-4 + x, 6.2, 0), Vector3(0.1, 1.4, 1.05), Color("4c6970"))
	box(Vector3(0, 3.8, -3), Vector3(4.2, 3.4, 0.3), Color("846649"))
	box(Vector3(0, 3.8, -2.8), Vector3(3.6, 2.8, 0.12), Color("c5dce1"))
	for side in [-1,1]:
		link(Vector3(side*0.7-0.5,3,-2.69),Vector3(side*0.7+0.2,4.5,-2.69),0.06,Color("f0f4fc"))
		link(Vector3(side*0.7+0.2,4.5,-2.69),Vector3(side*0.7+0.8,3.5,-2.69),0.06,Color("f0f4fc"))
	for x in [-1.7, 1.7]:
		box(Vector3(x, 1.9, -3), Vector3(0.22, 3.8, 0.22), Color("846649"))
	return finish()

func village_corner() -> ArrayMesh:
	# Compact street furniture, wholly outside every ski corridor.
	soft_box(Vector3(0, 0.7, 0), Vector3(3.8, 1.4, 3.8), Color("9e7961"), Vector3.ZERO, 0.3)
	soft_box(Vector3(0, 1.5, 0), Vector3(4.1, 0.35, 4.1), Color("f2f4f8"))
	cone(Vector3(0, 3.8, 0), 1.65, 5.2, Color("6f9582"), 0.15)
	cone(Vector3(0, 4.7, 0), 1.5, 3.8, Color("eaf2f2"), 0.1)
	for side in [-1, 1]:
		link(Vector3(side * 3, 0, 0), Vector3(side * 3, 6.5, 0), 0.16, Color("725d4f"))
		soft_box(Vector3(side * 3, 6.1, 0), Vector3(0.8, 1.25, 0.8), Color("ffe5b3"))
		soft_box(Vector3(side * 3, 6.9, 0), Vector3(1.3, 0.3, 1.3), Color("e9f0f6"))
	return finish()

func rock() -> ArrayMesh:
	soft_box(Vector3(0,1.8,0),Vector3(7.8,4.3,5.6),Color("89979e"),Vector3(0.12,0.25,0.12),0.9)
	soft_box(Vector3(-2.4,0.9,1.3),Vector3(4.4,2.6,4.2),Color("9aa7ad"),Vector3(-0.12,-0.3,-0.12),0.7)
	soft_box(Vector3(-0.2,3.65,0),Vector3(7.3,1.2,5.5),Color("edf4f7"),Vector3(0.12,0.25,0.12),0.6)
	for y in [1.1,1.9]: box(Vector3(0,y,2.85),Vector3(4.3,0.10,0.15),Color("6c7c85"),Vector3(0,0,0.1))
	return finish()

func roof(width: float, depth: float, wall_height: float) -> void:
	var angle := 0.42
	var rise := width * 0.5 * tan(angle)
	for side in [-1, 1]:
		var center := Vector3(side * width * 0.25, wall_height + rise * 0.5, 0)
		soft_box(center, Vector3(width*0.57,1.5,depth+5),Color("6f7b87"),Vector3(0,0,-side*angle),0.55)
		soft_box(center+Vector3(0,1.25,0),Vector3(width*0.57+1.1,1.6,depth+6.2),Color("f4f6fc"),Vector3(0,0,-side*angle),0.7)
		for index in range(5):
			var z := -depth*0.5-1.5+index*(depth+3)/4
			sphere(Vector3(side*width*0.51,wall_height+0.8,z),1.4,Color("ecf2fc"),Vector3(1.0,0.55,1.35))
	soft_box(Vector3(0,wall_height+rise+1.3,0),Vector3(2.1,1.6,depth+6.4),Color("f7f8fd"),Vector3.ZERO,0.65)

func _winter_decoration(width: float, depth: float, height_value: float, accent: Color) -> void:
	var front := depth * 0.5
	# Frosted porch, cedar corners, a hanging garland and a tiny friendly snowman.
	soft_box(Vector3(0,1.45,front+2.6),Vector3(9,0.8,5.2),Color("c9ae8b"),Vector3.ZERO,0.35)
	soft_box(Vector3(0,1.92,front+2.6),Vector3(9.3,0.24,5.3),Color("eff4fb"))
	for side in [-1,1]:
		box(Vector3(side*(width*0.5-0.6),height_value*0.5+1,front+0.25),Vector3(1.1,height_value,0.65),Color("c89e7d"))
		soft_box(Vector3(side*width*0.28,3.45,front+0.95),Vector3(5.4,1.1,1.5),accent.darkened(0.12))
		for x in [-1.3,0,1.3]:
			sphere(Vector3(side*width*0.28+x,4.2,front+1.15),0.65,Color("598b77"),Vector3(1,0.65,0.65))
	for i in range(9):
		var x := (float(i)/8-0.5)*width*0.82
		var y := height_value+0.5-1.0*sin(float(i)/8*PI)
		sphere(Vector3(x,y,front+0.75),0.53,Color("4c8272"),Vector3(1.6,0.65,0.65))
		if i%2==0:sphere(Vector3(x,y-0.35,front+1.0),0.24,Color("f0b28f") if i%4==0 else Color("f7dfac"))
	var at := Vector3(-width*0.5-3.4,0,front+3.7)
	sphere(at+Vector3(0,1.35,0),1.45,Color("f7f7fc"),Vector3(1,0.95,1))
	sphere(at+Vector3(0,3.15,0),1.0,Color("f7f8fd"))
	soft_box(at+Vector3(0,2.65,0.15),Vector3(2.05,0.4,1.7),accent)
	cone(at+Vector3(0,4.05,0),1.02,0.8,Color("617f83"),0.74)
	sphere(at+Vector3(0,4.7,0),0.32,Color("f2d3b1"))
	for side in [-1,1]:sphere(at+Vector3(side*0.32,3.43,0.86),0.10,Color("38525a"))
	sphere(at+Vector3(0,3.14,1.02),0.19,Color("e5a069"),Vector3(0.7,0.7,1.9))

## Landmark mesh: two historical wings, public arcade, clock tower and
## roof. Kept within a 32x26 m municipal lot with a front entrance at +Z.
func town_hall(accent: Color) -> ArrayMesh:
	var stone := Color("d9c5a4")
	var roof_color := accent.darkened(0.35)
	soft_box(Vector3(0,1.1,0),Vector3(34,2.2,26),Color("b4ae9e"),Vector3.ZERO,0.5)
	soft_box(Vector3(0,10,0),Vector3(31,18,23),stone,Vector3.ZERO,0.5)
	for x in [-12,-6,6,12]:
		for y in [6,14]:
			box(Vector3(x,y,11.8),Vector3(3.8,4.8,0.5),Color("6c7276"))
			box(Vector3(x,y,12.1),Vector3(2.8,3.9,0.3),Color("c5dfe9"))
			box(Vector3(x,y+2.4,12.3),Vector3(4.1,0.3,0.5),accent)
	for x in [-14,14]:
		soft_box(Vector3(x,10,12.3),Vector3(2.5,18,2.0),stone.lightened(0.07),Vector3.ZERO,0.4)
	box(Vector3(0,4.0,12.2),Vector3(5.2,7.2,0.6),Color("4b4144"))
	box(Vector3(0,20.2,0),Vector3(33,2.1,27),roof_color)
	for side in [-1,1]:
		box(Vector3(side*10,23.4,-2.0),Vector3(4,6,5),Color("b9aa97"))
		cone(Vector3(side*10,27.5,-2.0),3.6,2.5,roof_color,0.3)
	soft_box(Vector3(0,24.5,0),Vector3(10.5,9.0,9.0),stone,Vector3.ZERO,0.35)
	soft_box(Vector3(0,31,0),Vector3(9.5,4.5,9.2),roof_color,Vector3.ZERO,0.20)
	cone(Vector3(0,35.0,0),5.2,4.8,roof_color,0.15)
	box(Vector3(0,30.0,5.0),Vector3(6,6,0.45),Color("c9af8d"))
	# The clock face and hands form one original geometry-only ornament.
	sphere(Vector3(0,30,5.4),2.5,Color("f1ead5"),Vector3(1,1,0.09))
	link(Vector3(0,30,5.65),Vector3(0,31.7,5.65),0.13,Color("385266"))
	link(Vector3(0,30,5.68),Vector3(1.2,29.25,5.68),0.11,Color("385266"))
	box(Vector3(0,11.1,12.9),Vector3(10.0,1.8,1.1),accent)
	# Friendly civic forecourt steps, never on the actual foot navigation graph.
	for i in range(3):
		box(Vector3(0,0.32+i*0.25,13.8+i*.65),Vector3(12.5-i*1.0,0.5,1.1),Color("d8d7cf"))
	return finish()

func chalet(kind: String, level: int, accent: Color) -> ArrayMesh:
	if kind == "town_hall": return town_hall(accent)
	if kind == "pool": return outdoor_pool(accent)
	if kind == "snowmaker":
		return snow_cannon(level)
	if kind in ["viewpoint", "shelter", "snowpark", "bus", "kiosk"]:
		return amenity(kind, accent)
	var big := kind in ["hotel", "grand_hotel", "guesthouse"]
	var wide := kind in ["maintenance", "repair_office"]
	var width := 44.0 if kind == "grand_hotel" else 16.0 if kind == "cabin" else 35.0 if kind == "hotel" else 29.0 if wide else 22.0
	var depth := 32.0 if kind == "grand_hotel" else 14.0 if kind == "cabin" else 28.0 if kind == "hotel" else 24.0 if wide else 18.0
	var floors := 3 + int(level >= 2) if kind == "grand_hotel" else 2 + int(level >= 2) if big else 1 + int(level == 3)
	var height_value := floors * 8.0 + 3.0
	soft_box(Vector3(0, 1, 0), Vector3(width + 3, 2, depth + 3), Color("c9c5c1"),Vector3.ZERO,0.6)
	soft_box(Vector3(0, height_value / 2 + 1, 0),Vector3(width,height_value,depth),Color("e5cdb0") if big else Color("c79e7e"),Vector3.ZERO,0.65)
	for y in range(3, int(height_value), 2):
		box(Vector3(0, y, depth / 2 + 0.12), Vector3(width, 0.16, 0.25), Color("a77f62"))
		box(Vector3(width / 2 + 0.12, y, 0), Vector3(0.25, 0.16, depth), Color("a77f62"))
	for floor_index in range(floors):
		var y := 6.0 + floor_index * 8.0
		for x in range(-1, 2):
			var px: float = x * width * 0.28
			soft_box(Vector3(px, y, depth / 2 + 0.25), Vector3(4.6, 4.7, 0.5), Color("483d33"))
			box(Vector3(px, y, depth / 2 + 0.55), Vector3(3.6, 3.7, 0.25), Color("ffe0a6"))
			box(Vector3(px, y - 2.1, depth / 2 + 0.9), Vector3(5.0, 0.25, 1.0), Color("f4f6fc"))
			box(Vector3(px, y + 0.1, depth / 2 + 0.76), Vector3(3.6, 0.17, 0.23), Color("765b42"))
			box(Vector3(px, y, depth / 2 + 0.8), Vector3(0.22, 3.8, 0.2), Color("765b42"))
			for side in [-1, 1]:
				soft_box(Vector3(px + side * 2.9, y, depth / 2 + 0.4), Vector3(0.9, 4.4, 0.5), accent.darkened(0.15))
		for z in [-0.25, 0.25]:
			box(Vector3(width / 2 + 0.3, y, z * depth), Vector3(0.5, 3.5, 3.8), Color("ffe0a6"))
		if floor_index > 0:
			box(Vector3(0, y - 2.8, depth / 2 + 2), Vector3(width + 1, 0.8, 5.5), Color("74543d"))
			box(Vector3(0, y - 0.4, depth / 2 + 4.5), Vector3(width + 1, 0.45, 0.45), Color("6e503c"))
			for post in range(9):
				box(Vector3(-width / 2 + post * width / 8, y - 1.6, depth / 2 + 4.5), Vector3(0.4, 2.5, 0.4), Color("6e503c"))
	box(Vector3(0, 4, depth / 2 + 0.7), Vector3(3.3, 6, 0.9), Color("443a31"))
	box(Vector3(0, 8.5, depth / 2 + 1.0), Vector3(10, 1.6, 0.8), accent)
	box(Vector3(2.8, 7.0, depth / 2 + 1.1), Vector3(0.7, 0.9, 0.7), Color("ffe0a0"))
	if kind in ["rental", "school"]:
		for i in range(5):
			var x := -7.0 + i * 3.5
			box(Vector3(x, 4.2, depth * 0.5 + 2), Vector3(0.7, 7, 0.4), accent.lightened(i * 0.06), Vector3(0, 0, 0.1 if i % 2 else -0.1))
		box(Vector3(0, 3, depth * 0.5 + 2.3), Vector3(17, 0.6, 0.6), Color("715a4a"))
	if kind in ["restaurant", "lodge", "hotel", "cocoa", "schmarrn", "pizzeria"]:
		for i in range(8):
			var x := -width * 0.48 + (i + 0.5) * width * 0.12
			box(Vector3(x, 9.5, depth * 0.5 + 2), Vector3(width * 0.12, 0.4, 3.5), accent if i % 2 else Color("f7e9cf"), Vector3(-0.12, 0, 0))
	_facade_details(kind,width,depth,height_value,accent)
	_winter_decoration(width,depth,height_value,accent)
	# Gable timber and a round attic window are visible from both valley directions.
	var ridge := height_value+1+(width+2)*0.5*tan(0.42)
	for side in [-1,1]:
		_facet([Vector3(-width*0.5,height_value+1,side*depth*0.5),Vector3(width*0.5,height_value+1,side*depth*0.5),Vector3(0,ridge,side*depth*0.5)],Vector3(0,0,side),Color("d0ab87"))
		sphere(Vector3(0,height_value+3,side*(depth*0.5+0.18)),1.45,Color("846c5a"),Vector3(1,1,0.20))
		sphere(Vector3(0,height_value+3,side*(depth*0.5+0.45)),1.10,Color("ffe3ac"),Vector3(1,1,0.16))
	for x in [-0.28,0.28]:
		soft_box(Vector3(x*width,6,-depth*0.5-0.3),Vector3(4.8,4.6,0.5),accent)
		soft_box(Vector3(x*width,6,-depth*0.5-0.6),Vector3(3.6,3.5,0.25),Color("ffe0a6"))
	roof(width + 2, depth, height_value + 1)
	box(Vector3(-width * 0.28, height_value + 8, -depth * 0.15), Vector3(3.5, 8, 3.5), Color("b4a6a1"))
	box(Vector3(-width * 0.28, height_value + 12, -depth * 0.15), Vector3(5, 1, 5), Color("e8eeec"))
	if wide:
		box(Vector3(0, 5.3, depth / 2 + 1.1), Vector3(16, 8, 0.6), Color("384a4b"))
		box(Vector3(0, 2.0, depth / 2 + 5), Vector3(9, 3, 7), Color("bd6348"))
		for x in [-4.8, 4.8]:
			box(Vector3(x, 1.8, depth / 2 + 5), Vector3(1.2, 2.8, 8), Color("39433f"))
	if kind in ["restaurant", "lodge", "cocoa", "schmarrn", "pizzeria"]:
		for x in [-7, 7]:
			box(Vector3(x, 2, depth / 2 + 8), Vector3(5, 0.6, 3), Color("9b7550"))
			box(Vector3(x, 0.9, depth / 2 + 8), Vector3(0.6, 2, 0.6), Color("66513e"))
	if kind in ["cocoa", "schmarrn", "pizzeria"]:
		soft_box(Vector3(0,12,depth/2+1.4),Vector3(11,5.5,0.7),Color("fff0cf"))
		if kind == "pizzeria":
			sphere(Vector3(0,12,depth/2+2),2.3,Color("d9984e"),Vector3(1,1,0.15))
			sphere(Vector3(0,12,depth/2+2.4),1.9,Color("f1cf79"),Vector3(1,1,0.15))
			for x in [-0.9,0.9]: sphere(Vector3(x,12+x,depth/2+2.8),0.45,Color("b45342"),Vector3(1,1,0.2))
		elif kind == "cocoa":
			soft_box(Vector3(0,11.8,depth/2+2),Vector3(3.2,3,0.8),Color("fff9e9"))
			sphere(Vector3(1.9,11.8,depth/2+2),1.1,Color("fff9e9"),Vector3(0.8,1,0.25))
			sphere(Vector3(0,13.2,depth/2+2.2),1.3,Color("674337"),Vector3(1,0.25,0.2))
		else:
			for x in [-2,0,2]: soft_box(Vector3(x,11.8,depth/2+2),Vector3(1.6,1.5,0.9),Color("d4a64c"),Vector3(0,0,x*0.12))
			for x in [-1,1]: sphere(Vector3(x,12.8,depth/2+2.5),0.35,Color("fffaf2"))
	if kind in ["printing_press","newsstand"]:
		box(Vector3(0,12,depth/2+2),Vector3(13,5,0.8),Color("f5e7cf"))
		box(Vector3(0,13.2,depth/2+2.5),Vector3(10,0.35,0.3),accent)
		for row in range(3):
			for column in range(4):
				box(Vector3(-4.2+column*2.8,11.8-row*0.82,depth/2+2.55),Vector3(2,0.16,0.12),Color("43545b"))
	# Alpine craftsmanship is readable from the playable resort camera.
	if kind == "watchmaker":
		sphere(Vector3(0,12,depth/2+1.5),3.8,Color("b78c53"),Vector3(1,1,0.15))
		sphere(Vector3(0,12,depth/2+1.9),3.2,Color("fff3cf"),Vector3(1,1,0.15))
		for i in range(12):
			var angle := float(i)*TAU/12
			var at := Vector3(cos(angle)*2.55,12+sin(angle)*2.55,depth/2+2.1)
			sphere(at,0.18,Color("6e5d4c"))
		link(Vector3(0,12,depth/2+2.3),Vector3(0,14,depth/2+2.3),0.13,Color("374e5a"))
		link(Vector3(0,12,depth/2+2.3),Vector3(1.5,11.2,depth/2+2.3),0.11,Color("374e5a"))
	elif kind in ["souvenir","craftshop"]:
		for x in [-6.5,0.0,6.5]:
			box(Vector3(x,3,depth/2+2),Vector3(4.5,4.4,2.3),Color("907057"))
			for y in [3.0,4.6]:
				box(Vector3(x,y,depth/2+3.3),Vector3(3.8,0.2,0.7),Color("d7b78b"))
			sphere(Vector3(x,5.7,depth/2+3.4),0.8,accent)
		if kind == "craftshop":
			for x in [-2.5,2.5]:
				cone(Vector3(x,8.6,depth/2+2),0.95,2.6,Color("977358"),0.2)
	elif kind == "fitness":
		for x in [-6,6]:
			link(Vector3(x,2,depth/2+4),Vector3(x,9,depth/2+4),0.25,Color("6d7b84"))
		for y in [3.5,6.0,8.5]:
			link(Vector3(-7,y,depth/2+4),Vector3(7,y,depth/2+4),0.14,accent)
		for x in [-3.5,3.5]:
			sphere(Vector3(x,3.3,depth/2+4),1.4,Color("688f9b"))
	if kind == "first_aid":
		box(Vector3(0, height_value * 0.65, depth / 2 + 1.4), Vector3(6, 1.5, 0.6), Color("e9f2ec"))
		box(Vector3(0, height_value * 0.65, depth / 2 + 1.5), Vector3(1.5, 6, 0.6), Color("e9f2ec"))
	if kind == "spa" or kind == "pool":
		box(Vector3(0, 1.2, depth / 2 + 12), Vector3(23, 2.4, 17), Color("a8b5b6"))
		box(Vector3(0, 2.5, depth / 2 + 12), Vector3(19, 0.2, 13), Color("5cbbca"))
		for x in [-13, 13]:
			box(Vector3(x, 2, depth / 2 + 12), Vector3(2.5, 1, 6), Color("9d805c"))
	if kind == "disco":
		for x in [-7, 0, 7]:
			box(Vector3(x, 9.2, depth / 2 + 1.5), Vector3(4, 1.2, 1), Color("eb85ce") if x != 0 else Color("7bded6"))
			sphere(Vector3(x, 4.0, depth / 2 + 3), 1.3, Color("a9d7f7"))
	return finish()

func outdoor_pool(accent: Color) -> ArrayMesh:
	soft_box(Vector3(0, 0.6, 0), Vector3(32, 1.2, 42), Color("b8c6cc"), Vector3.ZERO, 0.5)
	soft_box(Vector3(0, 1.3, 3), Vector3(27, 1.4, 27), Color("d8e5e8"), Vector3.ZERO, 0.8)
	box(Vector3(0, 2.05, 3), Vector3(24, 0.22, 24), Color("65bfce"))
	for x in [-9, -3, 3, 9]: box(Vector3(x, 2.2, 3), Vector3(0.15, 0.1, 21), Color("b7e8e7"))
	soft_box(Vector3(0, 4.6, -16), Vector3(24, 8, 8), Color("caa485"), Vector3.ZERO, 0.5)
	box(Vector3(0, 9.0, -16), Vector3(27, 1.1, 11), Color("edf2fa"))
	for x in [-8, 0, 8]: box(Vector3(x, 5, -11.8), Vector3(5, 4, 0.4), Color("ffe0a6"))
	for x in [-14, 14]:
		for z in [-3, 9]: box(Vector3(x, 2.0, z), Vector3(2.3, 1, 6), Color("96765a"))
	for x in [-10, 10]:
		box(Vector3(x, 2.9, 16), Vector3(0.45, 3, 0.45), Color("d4dedf"))
		box(Vector3(x + 1.3, 2.9, 16), Vector3(0.45, 3, 0.45), Color("d4dedf"))
	box(Vector3(0, 3.4, 20), Vector3(8, 1.3, 0.8), accent)
	return finish()

func swimmer() -> ArrayMesh:
	soft_box(Vector3(0, 0.12, -0.4), Vector3(1.4, 0.7, 2.5), Color("60aebd"), Vector3.ZERO, 0.25)
	sphere(Vector3(0, 0.4, 1.25), 0.65, Color("edc6a5"))
	sphere(Vector3(0, 0.75, 1.18), 0.55, Color("775c47"), Vector3(1, 0.5, 1))
	for side in [-1, 1]:
		box(Vector3(side * 1.35, 0.18, 0.4), Vector3(1.8, 0.4, 0.45), Color("edc6a5"), Vector3(0, side * 0.45, 0))
		box(Vector3(side * 0.42, -0.05, -2.1), Vector3(0.5, 0.4, 1.8), Color("edc6a5"))
	return finish()

func amenity(kind: String, accent: Color) -> ArrayMesh:
	if kind == "snowpark":
		for x in [-8, 8]:
			box(Vector3(x, 1.2, 0), Vector3(8, 2.4, 14), Color("dfeaf2"), Vector3(0.13, 0, 0))
			box(Vector3(x, 3.8, 7), Vector3(0.5, 7.6, 0.5), Color("657d83"))
			box(Vector3(x + 1, 6, 7), Vector3(3, 2, 0.3), accent)
		box(Vector3(0, 2.3, -7), Vector3(18, 0.45, 0.6), Color("698794"))
		for x in [-7, 7]:
			box(Vector3(x, 1, -7), Vector3(0.5, 2, 0.5), Color("536c73"))
	elif kind == "bus":
		box(Vector3(0, 0.3, 0), Vector3(28, 0.6, 21), Color("97a3a5"))
		soft_box(Vector3(-1,4,0),Vector3(21,7,7),accent,Vector3.ZERO,0.8)
		soft_box(Vector3(-1,7.7,0),Vector3(21.5,0.9,7.5),Color("f2f5fc"),Vector3.ZERO,0.4)
		for x in [-7,-2,3]:
			soft_box(Vector3(x,5.4,3.6),Vector3(3.8,2.8,0.3),Color("acd2dc"))
		for x in [-8, 6]:
			for z in [-3.6, 3.6]:
				sphere(Vector3(x, 1.3, z), 1.5, Color("354348"))
		box(Vector3(12, 5, 6), Vector3(0.5, 10, 0.5), Color("687d81"))
		box(Vector3(12, 9, 6), Vector3(4, 3, 0.4), Color("d9b76e"))
	else:
		var kiosk := kind == "kiosk"
		box(Vector3(0, 0.6, 0), Vector3(23 if not kiosk else 16, 1.2, 18), Color("9b8061"))
		if kind == "viewpoint":
			for x in [-10, 10]:
				box(Vector3(x, 2.8, 0), Vector3(0.5, 4.5, 18), Color("7a6852"))
			box(Vector3(0, 2.8, -8), Vector3(23, 0.6, 0.6), Color("7a6852"))
			cone(Vector3(0, 2.8, -5), 0.4, 4.5, Color("627a82"), 0.4)
			box(Vector3(0, 5.2, -5), Vector3(1.4, 1.4, 4), Color("526a78"), Vector3(-0.3, 0, 0))
		else:
			for x in [-7, 7]:
				box(Vector3(x, 4, -6), Vector3(1, 8, 1), Color("806143"))
			box(Vector3(0, 4, -7), Vector3(16, 8, 0.8), Color("99734e"))
			roof(17, 16, 8)
			if kiosk:
				box(Vector3(0, 3.5, 3), Vector3(15, 6, 4), accent)
				for x in [-4, 0, 4]:
					cone(Vector3(x, 6.8, 3), 0.5, 0.9, Color("e5e5d8"), 0.6)
		for x in [-6, 6]:
			box(Vector3(x, 2, 4), Vector3(6, 0.6, 3), Color("b4956f"))
	return finish()

func snow_cannon(level: int) -> ArrayMesh:
	soft_box(Vector3(0,1.8,0),Vector3(8,2.5,6),Color("e8bf7f"),Vector3.ZERO,0.65)
	for x in [-3.8, 3.8]:
		for z in [-2.5, 2.5]:
			sphere(Vector3(x, 1.3, z), 1.2, Color("394848"))
	cone(Vector3(0, 5.0, 0), 0.7, 6, Color("69868d"), 0.7)
	var barrel := CylinderMesh.new()
	barrel.height = 8 + level
	barrel.bottom_radius = 3.0
	barrel.top_radius = 3.6
	barrel.radial_segments = 10
	add(barrel, Vector3(0, 9, 0), Color("487d99"), Vector3(1.15, 0, 0))
	soft_box(Vector3(0,5,-2),Vector3(4,4,3),Color("e8bf7f"),Vector3.ZERO,0.5)
	return finish()

func station(kind: String, level: int, livery: String = "") -> ArrayMesh:
	var lift := {"kind": kind, "level": level}
	var family := Fleet.family(lift)
	var r := Fleet.rope_offset(lift)
	if family == "drag":
		# Open drive tower and bullwheel, with a small wooden operator hut.
		box(Vector3(0, 3.4, 0), Vector3(0.75, 6.8, 0.75), Color("526a70"))
		cone(Vector3(0, 7.3, 0), r, 0.35, Color("c69745"), r)
		cone(Vector3(0, 7.6, 0), 0.8, 1.2, Color("3d535c"), 0.8)
		for side in [-1, 1]:
			link(Vector3(0, 7.3, 0), Vector3(side * r, 7.3, 0), 0.13, Color("435e65"))
		soft_box(Vector3(8.5,2.5,-4),Vector3(5,5,6),Color("c19b7b"),Vector3.ZERO,0.4)
		box(Vector3(8.5, 3, -0.95), Vector3(3.7, 2, 0.2), Color("ffe4b5"))
		soft_box(Vector3(8.5,5.5,-4),Vector3(7,1.5,7.8),Color("f4f6fc"),Vector3.ZERO,0.55)
		box(Vector3(1.8, 2, 0), Vector3(2, 2, 3), Color("ca9948"))
		return finish()
	var width := r * 2 + 5
	var accent := Color("657981") if Fleet.seats(lift) == 1 else (Color("4a998f") if Fleet.seats(lift) == 2 else Color("417e96"))
	if family == "gondola":
		accent = Color("cc7c4e")
	if livery != "": accent = Color(livery)
	box(Vector3(0, 0.15, 0), Vector3(width + 2, 0.3, 16), Color("abb1ac"))
	for side in [-1, 1]:
		box(Vector3(side * (r + 1.4), 3.65, 0), Vector3(0.65, 7.3, 0.9), Color("536f78"))
		box(Vector3(side * (r + 1.4), 3.65, -5), Vector3(0.65, 7.3, 0.9), Color("536f78"))
	cone(Vector3(0, 7.3, 0), r, 0.45, Color("475f67"), r)
	soft_box(Vector3(0,8.1,0),Vector3(width,1.5,14),accent,Vector3.ZERO,0.48)
	soft_box(Vector3(0,9.25,0),Vector3(width+2.0,1.2,15.8),Color("f4f6fc"),Vector3.ZERO,0.5)
	box(Vector3(r + 3, 2.5, -3), Vector3(4.5, 5, 7), Color("8b9c9c"))
	box(Vector3(r + 3, 3, 0.6), Vector3(3.7, 2.5, 0.2), Color("b4d3d2"))
	if family == "gondola":
		for side in [-1, 1]:
			box(Vector3(side * (r + 2), 1.8, 0), Vector3(0.4, 3.3, 14), accent)
			for z in [-6, -2, 2, 6]:
				box(Vector3(side * (r + 2), 4.2, z), Vector3(0.45, 5, 0.45), Color("d4ddda"))
	return finish()

func chair(kind: String, livery: String = "") -> ArrayMesh:
	var lift := {"kind": kind}
	var family := Fleet.family(lift)
	var count := Fleet.seats(lift)
	if family == "drag":
		# The telescopic tow rope is a separate instance with terrain-dependent length.
		cone(Vector3.ZERO, 0.6, 0.14, Color("c69745"), 0.6)
		box(Vector3(0, 0.35, 0), Vector3(0.16, 0.7, 0.16), Color("526870"))
	elif family == "gondola":
		soft_box(Vector3(0, -1.15, 0), Vector3(7.4, 0.3, 6.4), Color("c67e4b") if livery == "" else Color(livery))
		box(Vector3(0, -0.5, 0), Vector3(7.4, 1.0, 6.4), Color("417e96"))
		# Open window frames let the actual occupants remain visible through glass.
		for x in [-3.55, 3.55]:
			for z in [-3, 3]:
				box(Vector3(x, 1.8, z), Vector3(0.3, 3.6, 0.3), Color("b9c9ce"))
		for z in [-3, 3]:
			box(Vector3(0, 2.8, z), Vector3(7.2, 0.24, 0.24), Color("b9c9ce"))
		soft_box(Vector3(0,3.5,0),Vector3(7.8,0.7,6.8),Color("f4f6fc"))
		for z in [-1.35, 1.35]:
			box(Vector3(0, 0, z), Vector3(6.3, 0.35, 1.35), Color("51727e"))
			box(Vector3(0, 0.65, z * 1.55), Vector3(6.3, 1.15, 0.3), Color("51727e"))
		link(Vector3(0, 3.7, 0), Vector3(0, 6, 0), 0.25, Color("526870"))
		for x in [-2.7, -0.9, 0.9, 2.7]:
			box(Vector3(x, 0.4, 3.45), Vector3(0.28, 3.4, 0.14), Color("d5a85b"))
	else:
		var width := count * Fleet.SEAT_SPACING + 0.45
		box(Vector3(0, -0.22, 0), Vector3(width, 0.35, 1.8), Color("4b6872"))
		for seat in range(count):
			var x := (seat - (count - 1) * 0.5) * Fleet.SEAT_SPACING
			soft_box(Vector3(x, 0.0, 0.15), Vector3(1.5, 0.35, 1.55), Color("bd8b54") if livery == "" else Color(livery))
			soft_box(Vector3(x, 1.1, -0.8), Vector3(1.5, 2.0, 0.45), Color("517b8e") if livery == "" else Color(livery))
		for side in [-1, 1]:
			box(Vector3(side * width * 0.5, 0.5, 0), Vector3(0.15, 1.3, 1.7), Color("526b74"))
		link(Vector3(0, 1.9, -1.1), Vector3(0, 6, 0), 0.19, Color("526b74"))
		box(Vector3(0, 1, 1.3), Vector3(width, 0.18, 0.18), Color("84989d"))
		for side in [-1, 1]:
			link(Vector3(side * width * 0.5, 1, 1.3), Vector3(side * width * 0.5, 0.7, -0.8), 0.09, Color("84989d"))
	return finish()

func gondola_glass() -> ArrayMesh:
	for x in [-3.52, 3.52]:
		box(Vector3(x, 1.8, 0), Vector3(0.05, 2.4, 5.8), Color("a9d6e4"))
	for z in [-3.02, 3.02]:
		box(Vector3(0, 1.8, z), Vector3(6.9, 2.4, 0.05), Color("a9d6e4"))
	return finish()

func _fixed(hex: String) -> Color:
	var color := Color(hex);color.a = 0.0
	return color

func _guest_head(y: float) -> void:
	# Alpha is a cloth tint mask, consumed by the opaque guest material.
	sphere(Vector3(0,y,0.06),0.55,_fixed("f4cfaf"),Vector3(1,1,0.92))
	sphere(Vector3(0,y+0.22,-0.01),0.60,_fixed("f2f2ed"),Vector3(1.05,0.83,1.0))
	soft_box(Vector3(0,y+0.18,0.43),Vector3(1.08,0.34,0.28),_fixed("36515f"),Vector3.ZERO,0.12)
	soft_box(Vector3(0,y+0.20,0.59),Vector3(0.89,0.21,0.08),_fixed("a7dce6"),Vector3.ZERO,0.055)
	box(Vector3(-0.19,y+0.24,0.64),Vector3(0.30,0.035,0.02),_fixed("eff9fb"),Vector3(0,0,0.15))
	for side in [-1,1]:sphere(Vector3(side*0.33,y-0.08,0.49),0.11,_fixed("edb4a9"),Vector3(1,0.55,0.25))
	sphere(Vector3(0,y+0.80,-0.04),0.20,Color.WHITE)
	soft_box(Vector3(0,y-0.46,0.02),Vector3(0.82,0.18,0.62),_fixed("edc58f"),Vector3.ZERO,0.08)
	soft_box(Vector3(-0.28,y-0.70,-0.44),Vector3(0.25,0.45,0.14),_fixed("edc58f"),Vector3(0.15,0,-0.12),0.06)

func skier(on_skis: bool = true, uphill: bool = false) -> ArrayMesh:
	for side in [-1,1]:
		link(Vector3(side*0.30,0.32,0.10),Vector3(side*0.33,0.82,0.29),0.19,Color("344b59"))
		link(Vector3(side*0.33,0.82,0.29),Vector3(side*0.29,1.27,-0.02),0.22,Color("344b59"))
	sphere(Vector3(0, 1.55, 0), 0.63, Color("f8f9f6"), Vector3(0.9, 1.15, 0.65))
	_guest_head(2.48)
	soft_box(Vector3(0,1.65,-0.46),Vector3(0.76,0.86,0.32),_fixed("76939a"))
	box(Vector3(0,1.65,0.43),Vector3(0.07,0.85,0.06),_fixed("f5ece0"))
	soft_box(Vector3(0.3,1.40,0.39),Vector3(0.27,0.19,0.08),_fixed("edf1ef"),Vector3.ZERO,0.04)
	for side in [-1, 1]:
		sphere(Vector3(side * 0.68, 1.55, 0.15), 0.24, Color("f7f7f2"), Vector3(0.7, 1.7, 0.8))
		sphere(Vector3(side * 0.70, 1.22, 0.24), 0.20, _fixed("385260"))
		box(Vector3(side * 0.3, 0.25, 0.1), Vector3(0.4, 0.38, 0.7), Color("273e4b"))
		if on_skis:
			box(Vector3(side*(0.52 if uphill else 0.35),0.13,0.4),Vector3(0.24,0.16,3.4),Color("4f6670"),Vector3(0,side*0.38 if uphill else 0,0))
			box(Vector3(side * 0.75, 1.0, 0.4), Vector3(0.09, 1.8, 0.09), Color("73838a"), Vector3(-0.3, 0, side * 0.2))
	return finish()

func _deck(at: Vector3, length_value: float, width: float, color: Color, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var parts = get_script().new()
	parts.box(Vector3.ZERO, Vector3(width,0.10,length_value-width), Color("253c4b"))
	parts.box(Vector3(0,0.055,0), Vector3(width*0.89,0.055,length_value-width), color)
	for side in [-1,1]:
		parts.sphere(Vector3(0,0,side*(length_value-width)*0.5),width*0.5,color,Vector3(1,0.18,1))
	parts.box(Vector3(0,0.09,length_value*0.30),Vector3(width*0.90,0.025,0.12),Color("f2c98f"))
	add(parts.finish(),at,Color.WHITE,rotation_value,Vector3.ONE,true)

func equipment(sport: String, pose: String) -> ArrayMesh:
	var sitting := pose == "seated"
	var carrying := pose == "walk" or (pose == "hike" and sport == "snowboard")
	if carrying:
		if sport == "snowboard":
			_deck(Vector3(0.86,1.4,-0.10),2.7,0.76,Color("d3e8ed"),Vector3(PI*0.5,0,0.12))
		else:
			for side in [-1,1]:
				_deck(Vector3(0.77+side*0.11,1.55,-0.22),1.65 if sport == "snowblade" else 3.1,0.20,Color("e4edf0"),Vector3(PI*0.5,0,0.18))
	elif sport == "snowboard":
		var at := Vector3(0,-0.80,1.15) if sitting else Vector3(0,0.14,0)
		_deck(at,2.75,0.78,Color("dae8ef"))
		for side in [-1,1]:
			box(at+Vector3(0,0.13,side*0.43),Vector3(0.60,0.15,0.23),Color("324856"),Vector3(0,side*0.18,0))
	else:
		var short_skis := sport == "snowblade"
		for side in [-1,1]:
			var at := Vector3(side*0.35,-0.8,1.2) if sitting else Vector3(side*(0.52 if pose == "hike" else 0.35),0.13,0.4)
			var rotation_value := Vector3(0,side*0.38 if pose == "hike" else 0,0)
			_deck(at,1.65 if short_skis else (3.0 if sitting else 3.4),0.28 if short_skis else 0.24,Color("d3e4eb"),rotation_value)
			box(at+Vector3(0,0.13,-0.10),Vector3(0.24,0.13,0.46),Color("293e4e"),rotation_value)
			if not short_skis and not sitting:
				link(Vector3(side*0.75,0.05,0.68),Vector3(side*0.72,1.65,0.20),0.04,Color("748e9a"))
	return finish()

func seated_skier(on_skis: bool = true) -> ArrayMesh:
	box(Vector3(0, 0.35, 0.15), Vector3(0.8, 0.4, 0.8), Color("344b59"))
	sphere(Vector3(0, 1.1, 0), 0.6, Color("f8f9f6"), Vector3(0.9, 1.1, 0.65))
	_guest_head(1.96)
	for side in [-1,1]:sphere(Vector3(side*0.58,1.0,0.28),0.23,Color("f8f9f6"),Vector3(0.85,1.5,0.9))
	for side in [-1,1]:
		sphere(Vector3(side*0.56,0.60,0.58),0.16,Color("293e4d"))
	for side in [-1, 1]:
		box(Vector3(side * 0.3, 0.4, 0.5), Vector3(0.35, 0.4, 1.2), Color("344b59"))
		box(Vector3(side * 0.3, -0.2, 1.0), Vector3(0.35, 1.2, 0.4), Color("344b59"))
		if on_skis:
			box(Vector3(side * 0.35, -0.8, 1.2), Vector3(0.22, 0.15, 3), Color("4f6670"))
	return finish()

func groomer() -> ArrayMesh:
	for side in [-1, 1]:
		box(Vector3(side * 2.7, 0.7, 0), Vector3(1.2, 1.4, 6.8), Color("354a52"))
	soft_box(Vector3(0,1.7,0),Vector3(4.5,2.0,5.8),Color("dfaa8e"))
	soft_box(Vector3(0,3.0,1),Vector3(3.8,2.8,3),Color("8eb7c6"))
	soft_box(Vector3(0,4.6,1),Vector3(4.3,0.5,3.5),Color("f2f4fc"))
	box(Vector3(0, 0.7, 4.4), Vector3(9, 1.5, 1), Color("c5d4d7"))
	box(Vector3(0, 1.2, -4), Vector3(8, 0.7, 1.6), Color("486773"))
	sphere(Vector3(0, 5.1, 1), 0.4, Color("f3bb60"))
	return finish()



