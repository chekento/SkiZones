extends RefCounted
## Small original 3D models, baked into one colored mesh per asset.
const Catalog = preload("res://src/core/catalog.gd")
const Fleet = preload("res://src/core/lift_fleet.gd")

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
		surface.set_color(color * colors[index] if preserve_colors and not colors.is_empty() else color)
		surface.set_normal((normal_basis * normals[index]).normalized())
		surface.add_vertex(transform_value * vertices[index])

func box(position_value: Vector3, size_value: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	add(mesh, position_value, color, rotation)

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
	cone(Vector3(0, 3, 0), 0.55, 6, Color("71583e"), 0.38)
	for index in range(5):
		var y := 2.8 + index * 2.45
		var radius := 5.0 - index * 0.82
		var shift := Vector3(sin(index * 2.4) * 0.3, 0, cos(index * 1.7) * 0.3)
		cone(Vector3(0, y + 2.6, 0) + shift, radius, 5.8, Color("315746").lightened(index * 0.018))
		cone(Vector3(0, y + 3.5, 0) + shift, radius * 0.91, 4.7, Color("edf3f4"))
		for branch in range(3):
			var angle := index * 1.3 + branch * TAU / 3
			var at := Vector3(cos(angle) * radius * 0.55, y + 1.6, sin(angle) * radius * 0.55)
			cone(at, radius * 0.48, 2.5, Color("e3eef1"))
	return finish()

func pine_distant() -> ArrayMesh:
	cone(Vector3(0, 3, 0), 0.5, 6, Color("71583e"))
	for index in range(3):
		var y := 3.0 + index * 4
		var radius := 5.0 - index * 1.4
		cone(Vector3(0, y + 2, 0), radius, 6.5, Color("315746"))
		cone(Vector3(0, y + 3, 0), radius * 0.91, 5.2, Color("edf3f4"))
	return finish()

func plaza_details() -> ArrayMesh:
	# One batched set: timber seat, bin, warm lantern and a little route board.
	box(Vector3(0, 1.1, 0), Vector3(5.2, 0.38, 1.9), Color("b28b5b"))
	for side in [-1, 1]:
		box(Vector3(side * 1.85, 0.5, 0), Vector3(0.28, 1.1, 1.6), Color("48666a"))
		box(Vector3(side * 1.85, 1.8, -0.7), Vector3(0.24, 2.3, 0.24), Color("48666a"))
	box(Vector3(0, 2.0, -0.75), Vector3(5.2, 1.25, 0.25), Color("a67b4f"))
	for x in [-1.8, -0.6, 0.6, 1.8]:
		box(Vector3(x, 1.31, 0), Vector3(0.06, 0.03, 1.8), Color("73583d"))
	box(Vector3(4.3, 1.1, 0), Vector3(1.4, 2.2, 1.4), Color("54756d"))
	box(Vector3(4.3, 2.3, 0), Vector3(1.65, 0.22, 1.65), Color("e4eef0"))
	cone(Vector3(-4, 3, 0), 0.15, 6, Color("475f66"), 0.15)
	box(Vector3(-4, 6.2, 0), Vector3(0.9, 1.25, 0.9), Color("ffe2aa"))
	box(Vector3(-4, 7, 0), Vector3(1.3, 0.25, 1.3), Color("4c6970"))
	for x in [-0.52, 0.52]:
		box(Vector3(-4 + x, 6.2, 0), Vector3(0.1, 1.4, 1.05), Color("4c6970"))
	box(Vector3(0, 3.8, -3), Vector3(4.2, 3.4, 0.3), Color("846649"))
	box(Vector3(0, 3.8, -2.8), Vector3(3.6, 2.8, 0.12), Color("c5dce1"))
	for x in [-1.7, 1.7]:
		box(Vector3(x, 1.9, -3), Vector3(0.22, 3.8, 0.22), Color("846649"))
	return finish()

func rock() -> ArrayMesh:
	sphere(Vector3(0, 2, 0), 4, Color("6f7b83"), Vector3(1.2, 0.7, 0.85))
	sphere(Vector3(-0.5, 3.8, 0), 3.5, Color("dce5e9"), Vector3(1.1, 0.3, 0.75))
	return finish()

func roof(width: float, depth: float, wall_height: float) -> void:
	var angle := 0.42
	var rise := width * 0.5 * tan(angle)
	for side in [-1, 1]:
		var center := Vector3(side * width * 0.25, wall_height + rise * 0.5, 0)
		box(center, Vector3(width * 0.57, 1.4, depth + 5), Color("4b4b48"), Vector3(0, 0, -side * angle))
		box(center + Vector3(0, 1, 0), Vector3(width * 0.57 + 0.6, 0.85, depth + 5.6), Color("edf0ed"), Vector3(0, 0, -side * angle))

func chalet(kind: String, level: int, accent: Color) -> ArrayMesh:
	if kind == "snowmaker":
		return snow_cannon(level)
	if kind in ["viewpoint", "shelter", "snowpark", "bus", "kiosk"]:
		return amenity(kind, accent)
	var big := kind == "hotel"
	var wide := kind == "maintenance"
	var width := 35.0 if big else (29.0 if wide else 22.0)
	var depth := 28.0 if big else (24.0 if wide else 18.0)
	var floors := 2 + int(level >= 2) if big else 1 + int(level == 3)
	var height_value := floors * 8.0 + 3.0
	box(Vector3(0, 1, 0), Vector3(width + 3, 2, depth + 3), Color("8f9697"))
	box(Vector3(0, height_value / 2 + 1, 0), Vector3(width, height_value, depth), Color("b6a186") if big else Color("966a48"))
	for y in range(3, int(height_value), 2):
		box(Vector3(0, y, depth / 2 + 0.12), Vector3(width, 0.16, 0.25), Color("70513c"))
		box(Vector3(width / 2 + 0.12, y, 0), Vector3(0.25, 0.16, depth), Color("70513c"))
	for floor_index in range(floors):
		var y := 6.0 + floor_index * 8.0
		for x in range(-1, 2):
			var px: float = x * width * 0.28
			box(Vector3(px, y, depth / 2 + 0.25), Vector3(4.6, 4.7, 0.5), Color("483d33"))
			box(Vector3(px, y, depth / 2 + 0.55), Vector3(3.6, 3.7, 0.25), Color("dcba7e"))
			box(Vector3(px, y - 2.1, depth / 2 + 0.9), Vector3(5.0, 0.25, 1.0), Color("eeeede"))
			box(Vector3(px, y + 0.1, depth / 2 + 0.76), Vector3(3.6, 0.17, 0.23), Color("765b42"))
			box(Vector3(px, y, depth / 2 + 0.8), Vector3(0.22, 3.8, 0.2), Color("765b42"))
			for side in [-1, 1]:
				box(Vector3(px + side * 2.9, y, depth / 2 + 0.4), Vector3(0.9, 4.4, 0.5), accent.darkened(0.15))
		for z in [-0.25, 0.25]:
			box(Vector3(width / 2 + 0.3, y, z * depth), Vector3(0.5, 3.5, 3.8), Color("dcba7e"))
		if floor_index > 0:
			box(Vector3(0, y - 2.8, depth / 2 + 2), Vector3(width + 1, 0.8, 5.5), Color("74543d"))
			box(Vector3(0, y - 0.4, depth / 2 + 4.5), Vector3(width + 1, 0.45, 0.45), Color("6e503c"))
			for post in range(9):
				box(Vector3(-width / 2 + post * width / 8, y - 1.6, depth / 2 + 4.5), Vector3(0.4, 2.5, 0.4), Color("6e503c"))
	box(Vector3(0, 4, depth / 2 + 0.7), Vector3(3.3, 6, 0.9), Color("443a31"))
	box(Vector3(0, 8.5, depth / 2 + 1.0), Vector3(10, 1.6, 0.8), accent)
	box(Vector3(2.8, 7.0, depth / 2 + 1.1), Vector3(0.7, 0.9, 0.7), Color("ffe0a0"))
	roof(width + 2, depth, height_value + 1)
	box(Vector3(-width * 0.28, height_value + 8, -depth * 0.15), Vector3(3.5, 8, 3.5), Color("a59c8d"))
	box(Vector3(-width * 0.28, height_value + 12, -depth * 0.15), Vector3(5, 1, 5), Color("e8eeec"))
	if wide:
		box(Vector3(0, 5.3, depth / 2 + 1.1), Vector3(16, 8, 0.6), Color("384a4b"))
		box(Vector3(0, 2.0, depth / 2 + 5), Vector3(9, 3, 7), Color("bd6348"))
		for x in [-4.8, 4.8]:
			box(Vector3(x, 1.8, depth / 2 + 5), Vector3(1.2, 2.8, 8), Color("39433f"))
	if kind == "restaurant" or kind == "lodge":
		for x in [-7, 7]:
			box(Vector3(x, 2, depth / 2 + 8), Vector3(5, 0.6, 3), Color("9b7550"))
			box(Vector3(x, 0.9, depth / 2 + 8), Vector3(0.6, 2, 0.6), Color("66513e"))
	if kind == "first_aid":
		box(Vector3(0, height_value * 0.65, depth / 2 + 1.4), Vector3(6, 1.5, 0.6), Color("e9f2ec"))
		box(Vector3(0, height_value * 0.65, depth / 2 + 1.5), Vector3(1.5, 6, 0.6), Color("e9f2ec"))
	if kind == "spa":
		box(Vector3(0, 1.2, depth / 2 + 12), Vector3(23, 2.4, 17), Color("a8b5b6"))
		box(Vector3(0, 2.5, depth / 2 + 12), Vector3(19, 0.2, 13), Color("5cbbca"))
		for x in [-13, 13]:
			box(Vector3(x, 2, depth / 2 + 12), Vector3(2.5, 1, 6), Color("9d805c"))
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
		box(Vector3(-1, 4, 0), Vector3(21, 7, 7), accent)
		box(Vector3(-1, 5.4, 3.6), Vector3(18, 3, 0.2), Color("344e5b"))
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
	box(Vector3(0, 1.8, 0), Vector3(8, 2.5, 6), Color("d7ad5b"))
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
	box(Vector3(0, 5, -2), Vector3(4, 4, 3), Color("d4b25b"))
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
		box(Vector3(8.5, 2.5, -4), Vector3(5, 5, 6), Color("a67c50"))
		box(Vector3(8.5, 3, -0.95), Vector3(3.7, 2, 0.2), Color("a6c8ca"))
		box(Vector3(8.5, 5.2, -4), Vector3(6.5, 0.9, 7.3), Color("edf2ed"))
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
	box(Vector3(0, 8.1, 0), Vector3(width, 1.5, 14), accent)
	box(Vector3(0, 9.0, 0), Vector3(width + 1.6, 0.8, 15.4), Color("eaf0ed"))
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
		box(Vector3(0, -1.15, 0), Vector3(7.4, 0.3, 6.4), Color("c67e4b") if livery == "" else Color(livery))
		box(Vector3(0, -0.5, 0), Vector3(7.4, 1.0, 6.4), Color("417e96"))
		# Open window frames let the actual occupants remain visible through glass.
		for x in [-3.55, 3.55]:
			for z in [-3, 3]:
				box(Vector3(x, 1.8, z), Vector3(0.3, 3.6, 0.3), Color("b9c9ce"))
		for z in [-3, 3]:
			box(Vector3(0, 2.8, z), Vector3(7.2, 0.24, 0.24), Color("b9c9ce"))
		box(Vector3(0, 3.5, 0), Vector3(7.7, 0.5, 6.7), Color("e9efed"))
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
			box(Vector3(x, 0.0, 0.15), Vector3(1.5, 0.35, 1.55), Color("bd8b54") if livery == "" else Color(livery))
			box(Vector3(x, 1.1, -0.8), Vector3(1.5, 2.0, 0.45), Color("517b8e") if livery == "" else Color(livery))
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

func skier(on_skis: bool = true) -> ArrayMesh:
	box(Vector3(-0.3, 0.7, 0), Vector3(0.35, 1.25, 0.45), Color("344b59"))
	box(Vector3(0.3, 0.7, 0), Vector3(0.35, 1.25, 0.45), Color("344b59"))
	sphere(Vector3(0, 1.55, 0), 0.63, Color("f8f9f6"), Vector3(0.9, 1.15, 0.65))
	sphere(Vector3(0, 2.55, 0), 0.46, Color("d9e1dd"))
	box(Vector3(0, 2.55, 0.4), Vector3(0.75, 0.22, 0.15), Color("273e4b"))
	box(Vector3(0, 1.9, -0.48), Vector3(0.8, 0.9, 0.25), Color("647983"))
	box(Vector3(0, 1.7, 0.42), Vector3(0.12, 1.0, 0.08), Color("e3e9e4"))
	for side in [-1, 1]:
		sphere(Vector3(side * 0.68, 1.55, 0.15), 0.24, Color("f7f7f2"), Vector3(0.7, 1.7, 0.8))
		box(Vector3(side * 0.3, 0.25, 0.1), Vector3(0.4, 0.38, 0.7), Color("273e4b"))
		if on_skis:
			box(Vector3(side * 0.35, 0.13, 0.4), Vector3(0.24, 0.16, 3.4), Color("4f6670"))
			box(Vector3(side * 0.75, 1.0, 0.4), Vector3(0.09, 1.8, 0.09), Color("73838a"), Vector3(-0.3, 0, side * 0.2))
	return finish()

func seated_skier(on_skis: bool = true) -> ArrayMesh:
	box(Vector3(0, 0.35, 0.15), Vector3(0.8, 0.4, 0.8), Color("344b59"))
	sphere(Vector3(0, 1.1, 0), 0.6, Color("f8f9f6"), Vector3(0.9, 1.1, 0.65))
	sphere(Vector3(0, 2.0, 0), 0.43, Color("d9e1dd"))
	box(Vector3(0, 2.0, 0.4), Vector3(0.7, 0.2, 0.15), Color("273e4b"))
	for side in [-1, 1]:
		box(Vector3(side * 0.3, 0.4, 0.5), Vector3(0.35, 0.4, 1.2), Color("344b59"))
		box(Vector3(side * 0.3, -0.2, 1.0), Vector3(0.35, 1.2, 0.4), Color("344b59"))
		if on_skis:
			box(Vector3(side * 0.35, -0.8, 1.2), Vector3(0.22, 0.15, 3), Color("4f6670"))
	return finish()

func groomer() -> ArrayMesh:
	for side in [-1, 1]:
		box(Vector3(side * 2.7, 0.7, 0), Vector3(1.2, 1.4, 6.8), Color("354a52"))
	box(Vector3(0, 1.7, 0), Vector3(4.5, 2.0, 5.8), Color("cf7950"))
	box(Vector3(0, 3.0, 1), Vector3(3.8, 2.8, 3), Color("628996"))
	box(Vector3(0, 4.6, 1), Vector3(4.3, 0.4, 3.5), Color("e5ebea"))
	box(Vector3(0, 0.7, 4.4), Vector3(9, 1.5, 1), Color("c5d4d7"))
	box(Vector3(0, 1.2, -4), Vector3(8, 0.7, 1.6), Color("486773"))
	sphere(Vector3(0, 5.1, 1), 0.4, Color("f3bb60"))
	return finish()
