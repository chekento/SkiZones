extends Node3D
## Original, batched alpine scenery and a simulation-driven atmosphere.

const Terrain = preload("res://src/core/terrain.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Mountain = preload("res://src/core/mountain.gd")
const Maps = preload("res://src/core/maps.gd")
const Motion = preload("res://src/core/ski_motion.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const Art = preload("res://src/world/alpine_art.gd")
const PISTE_COLORS := [Color("368bcb"), Color("ce5660"), Color("202c39")]

var model: RefCounted
var terrain: Mountain
var landscape := Node3D.new()
var simulation_fraction := 0.0
var motion_running := false
var follow_guest := -1
var _terrain_id := ""
var _snow_timer := 0.0
var _snow_seen := -1
var _piste_meshes: Dictionary = {}
var _track_mesh := MeshInstance3D.new()
var _riders := MultiMeshInstance3D.new()
var _groomers := MultiMeshInstance3D.new()
var _track_timer := 0.0
var _track_seen := -1
var _track_focus := Vector2.INF
var _car_positions: Dictionary = {}
var _occluders: Array = []
var camera := Camera3D.new()
var focus := Vector2(15, -30)
var yaw := 0.46
var zoom := 620.0
const CAMERA_MODES := ["Resort", "Panorama", "Bauansicht", "Draufsicht"]
const CAMERA_PITCHES := [34.0, 22.0, 58.0, 90.0]
var camera_mode := 0
var pitch_degrees := 34.0
var topography: Node3D
var contour_mesh: MeshInstance3D
var downhill_arrows: MultiMeshInstance3D
var piste_markers: Array = []
var asset_root := Node3D.new()
var preview_root := Node3D.new()
var trees := MultiMeshInstance3D.new()
var rocks := MultiMeshInstance3D.new()
var visitor_mesh := MultiMeshInstance3D.new()
var chairs: Array = []
var slopes_visible := false
var slope_overlay: MeshInstance3D
var terrain_instance: MeshInstance3D
var scenery_instance: MeshInstance3D
var _sun := DirectionalLight3D.new()
var _environment := Environment.new()
var _snow := CPUParticles3D.new()
var _seen_revision := -1
var _guest_positions: Dictionary = {}
var _guest_targets: Dictionary = {}
var _guest_tick := ""
var _visual_minute := 480.0
var _atmosphere_tick := ""
var _solid: StandardMaterial3D
var _vehicles: Dictionary = {}
var _vehicle_counts: Dictionary = {}

func setup(resort: RefCounted) -> void:
	model = resort
	terrain = model.terrain
	_terrain_id = model.map_id
	add_child(landscape)
	_solid = _material(Color.WHITE, true)
	_build_environment()
	_build_terrain()
	_build_surroundings()
	for node in [trees, rocks, asset_root, preview_root, visitor_mesh, _riders, _groomers, _track_mesh]:
		add_child(node)
	visitor_mesh.multimesh = _multimesh(Art.new().skier(), model.MAX_GUESTS)
	visitor_mesh.multimesh.mesh.surface_set_material(0, _solid)
	visitor_mesh.multimesh.visible_instance_count = 0
	visitor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_riders.multimesh = _multimesh(Art.new().seated_skier(), model.MAX_GUESTS)
	_riders.multimesh.mesh.surface_set_material(0, _solid)
	_riders.multimesh.visible_instance_count = 0
	_groomers.multimesh = _multimesh(Art.new().groomer(), 80)
	_groomers.multimesh.mesh.surface_set_material(0, _solid)
	_groomers.multimesh.visible_instance_count = 0
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 42
	camera.near = 3.0
	camera.far = 20000
	camera.current = true
	_update_camera()
	rebuild()

func _material(color: Color, vertex_color: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.vertex_color_use_as_albedo = vertex_color
	material.vertex_color_is_srgb = true
	material.roughness = 0.92
	material.metallic_specular = 0.12
	return material

func _build_environment() -> void:
	_sun.rotation_degrees = Vector3(-48, -35, 0)
	_sun.light_color = Color("fffdf7")
	_sun.light_energy = 0.62
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 1500
	add_child(_sun)
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("6791b3")
	sky_material.sky_horizon_color = Color("dce7e9")
	sky_material.ground_horizon_color = Color("dce7e9")
	sky_material.ground_bottom_color = Color("8da8b8")
	var sky := Sky.new()
	sky.sky_material = sky_material
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("9fc9ef")
	_environment.ambient_light_energy = 0.18
	# Linear tone mapping keeps snow detail on the Android compatibility renderer.
	_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("c0d2dc")
	_environment.fog_light_energy = 0.45
	_environment.fog_density = 0.00008
	var environment_node := WorldEnvironment.new()
	environment_node.environment = _environment
	add_child(environment_node)
	_snow.amount = 140
	_snow.lifetime = 12
	_snow.preprocess = 6
	_snow.local_coords = false
	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(300, 130, 300)
	_snow.direction = Vector3(0.2, -1, 0)
	_snow.spread = 12
	_snow.gravity = Vector3(0, -2, 0)
	_snow.initial_velocity_min = 6
	_snow.initial_velocity_max = 11
	_snow.scale_amount_min = 0.4
	_snow.scale_amount_max = 1
	_snow.emitting = false
	var flake := SphereMesh.new()
	flake.radius = 0.5
	flake.height = 1
	flake.radial_segments = 4
	flake.rings = 1
	flake.material = _material(Color("eef5fa"))
	_snow.mesh = flake
	add_child(_snow)

func _ground_color(point: Vector2, height_value: float, grade: float = -1) -> Color:
	if grade < 0:
		grade = terrain.slope_percent(point)
	var snow := Color("d6e5f0").lerp(Color("e7eff5"), clampf(height_value / 420.0, 0, 1))
	if grade > 38:
		snow = snow.lerp(Color("526775"), clampf((grade - 38) / 65.0, 0, 0.84))
	return snow.darkened(0.018 + sin(point.x * 0.047 + point.y * 0.027) * 0.018)

func _land_mesh(bounds: Rect2, step_size: int, outside: bool = false) -> ArrayMesh:
	var nx := ceili(bounds.size.x / step_size) + 1
	var nz := ceili(bounds.size.y / step_size) + 1
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for z in range(nz):
		for x in range(nx):
			var point := bounds.position + Vector2(minf(x * step_size, bounds.size.x), minf(z * step_size, bounds.size.y))
			vertices.append(terrain.world(point, -0.1 if outside else 0))
	for z in range(nz):
		for x in range(nx):
			var i := z * nx + x
			var left := vertices[z * nx + maxi(0, x - 1)]
			var right := vertices[z * nx + mini(nx - 1, x + 1)]
			var near_value := vertices[maxi(0, z - 1) * nx + x]
			var far_value := vertices[mini(nz - 1, z + 1) * nx + x]
			var normal := (far_value - near_value).cross(right - left).normalized()
			normals.append(normal)
			var grade := Vector2(normal.x, normal.z).length() / maxf(normal.y, 0.01) * 100
			colors.append(_ground_color(Vector2(vertices[i].x, vertices[i].z), vertices[i].y, grade))
			if x == nx - 1 or z == nz - 1:
				continue
			var center := Vector2(vertices[i].x + step_size * 0.5, vertices[i].z + step_size * 0.5)
			if outside and terrain.bounds.has_point(center):
				continue
			indices.append_array(PackedInt32Array([i, i + 1, i + nx, i + 1, i + nx + 1, i + nx]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_terrain() -> void:
	terrain_instance = MeshInstance3D.new()
	terrain_instance.mesh = _land_mesh(terrain.bounds, 20)
	terrain_instance.material_override = _solid
	landscape.add_child(terrain_instance)
	var lake := CylinderMesh.new()
	lake.top_radius = 53
	lake.bottom_radius = 53
	lake.height = 0.6
	lake.radial_segments = 48
	var lake_node := _mesh(landscape, lake, Vector3(-260, 7, 255), Color("85aab9"))
	lake_node.scale.z = 0.62
	_ribbon(landscape, [[185, 490], [185, 335], [185, 230]], 11.0, Color("b5b5a9"), 0.25)
	_label(landscape, "TALZUGANG", terrain.world(Terrain.BASE + Vector2(0, 65), 8), Color("446774"))

func _build_surroundings() -> void:
	scenery_instance = MeshInstance3D.new()
	scenery_instance.mesh = _land_mesh(terrain.bounds.grow(1200), 80, true)
	scenery_instance.material_override = _solid
	scenery_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	landscape.add_child(scenery_instance)

func toggle_slopes() -> void:
	slopes_visible = not slopes_visible
	if slope_overlay == null:
		_build_slope_overlay()
	slope_overlay.visible = slopes_visible
	if topography == null:
		_build_topography()
	topography.visible = slopes_visible

func _build_slope_overlay() -> void:
	var arrays: Array = terrain_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors := PackedColorArray()
	for i in range(vertices.size()):
		vertices[i].y += 0.45
		var grade := Vector2(normals[i].x, normals[i].z).length() / maxf(normals[i].y, 0.01) * 100
		var color := Color("83bcaa") if grade < 8 else (Color("68a6d0") if grade <= 30 else (Color("d8777c") if grade <= 55 else Color("687381")))
		color.a = 0.68
		colors.append(color)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	slope_overlay = MeshInstance3D.new()
	slope_overlay.mesh = mesh
	var material := _material(Color.WHITE, true)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slope_overlay.material_override = material
	slope_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(slope_overlay)

func _build_topography() -> void:
	# Contours use the same indexed triangles as the visible ground: no floating
	# approximation to a separate height field and no per-frame mesh rebuilding.
	topography = Node3D.new()
	add_child(topography)
	var arrays: Array = terrain_instance.mesh.surface_get_arrays(0)
	var ground: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var lines := PackedVector3Array()
	var colors := PackedColorArray()
	var altitude_labels: Dictionary = {}
	for index in range(0, indices.size(), 3):
		var triangle := [ground[indices[index]], ground[indices[index + 1]], ground[indices[index + 2]]]
		var low: float = minf(triangle[0].y, minf(triangle[1].y, triangle[2].y))
		var high: float = maxf(triangle[0].y, maxf(triangle[1].y, triangle[2].y))
		for level in range((floori(low / 20) + 1) * 20, floori(high / 20) * 20 + 1, 20):
			var intersections: Array[Vector3] = []
			for edge in range(3):
				var a: Vector3 = triangle[edge]
				var b: Vector3 = triangle[(edge + 1) % 3]
				if (a.y < level and b.y >= level) or (b.y < level and a.y >= level):
					intersections.append(a.lerp(b, (level - a.y) / (b.y - a.y)) + Vector3.UP * 0.85)
			if intersections.size() != 2 or intersections[0].distance_to(intersections[1]) < 0.01:
				continue
			var color := Color("304e60") if level % 100 == 0 else Color("548087")
			lines.append_array(PackedVector3Array(intersections))
			colors.append_array(PackedColorArray([color, color]))
			if level % 100 == 0:
				var at := (intersections[0] + intersections[1]) * 0.5
				if not altitude_labels.has(level) or at.distance_to(Vector3(0, level, -100)) < altitude_labels[level].distance_to(Vector3(0, level, -100)):
					altitude_labels[level] = at
	var line_arrays := []
	line_arrays.resize(Mesh.ARRAY_MAX)
	line_arrays[Mesh.ARRAY_VERTEX] = lines
	line_arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	if not lines.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arrays)
	contour_mesh = MeshInstance3D.new()
	contour_mesh.mesh = mesh
	var material := _material(Color.WHITE, true)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	contour_mesh.material_override = material
	contour_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	topography.add_child(contour_mesh)
	for level in altitude_labels:
		var label := Label3D.new()
		label.text = "%d m" % level
		label.font_size = 44
		label.pixel_size = 0.15
		label.position = altitude_labels[level] + Vector3.UP * 6
		label.modulate = Color("f0f8eb")
		label.outline_modulate = Color("274854")
		label.outline_size = 12
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		topography.add_child(label)
	var arrow_mesh := Art.new().downhill_arrow()
	arrow_mesh.surface_set_material(0, material)
	var instances := _multimesh(arrow_mesh, ground.size() / 64 + 64)
	var nx := ceili(terrain.bounds.size.x / 20) + 1
	var used := 0
	for i in range(ground.size()):
		if i % nx % 8 != 4 or int(i / nx) % 8 != 4 or normals[i].y > 0.995:
			continue
		var down := Vector3(normals[i].x, 0, normals[i].z).slide(normals[i]).normalized()
		instances.set_instance_transform(used, Transform3D(Basis.looking_at(down, normals[i]).scaled(Vector3.ONE * 1.4), ground[i] + normals[i] * 1.2))
		instances.set_instance_color(used, Color.WHITE)
		used += 1
	instances.visible_instance_count = used
	downhill_arrows = MultiMeshInstance3D.new()
	downhill_arrows.multimesh = instances
	downhill_arrows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	topography.add_child(downhill_arrows)

func _mesh(parent: Node3D, mesh: Mesh, position_value: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance

func _baked(parent: Node3D, mesh: Mesh, position_value: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = _solid
	parent.add_child(instance)
	return instance

func _box(parent: Node3D, position_value: Vector3, size_value: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	return _mesh(parent, mesh, position_value, color)

func _link(parent: Node3D, from: Vector3, to: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 6
	var instance := _mesh(parent, mesh, (from + to) * 0.5, color)
	instance.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))

func _label(parent: Node3D, title: String, position_value: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = title
	label.font_size = 48
	label.pixel_size = 0.15
	label.position = position_value
	label.modulate = color
	label.outline_modulate = Color("eef5f5")
	label.outline_size = 10
	label.visibility_range_begin = 150
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)

func _multimesh(mesh: Mesh, count: int) -> MultiMesh:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = mesh
	instances.instance_count = count
	return instances

func _clear_ground(point: Vector2, margin: float) -> bool:
	for piste in model.pistes:
		for j in range(1, piste.points.size()):
			if Geometry2D.get_closest_point_to_segment(point, Terrain.unpack(piste.points[j - 1]), Terrain.unpack(piste.points[j])).distance_to(point) < margin:
				return false
	for lift in model.lifts:
		if Geometry2D.get_closest_point_to_segment(point, Terrain.unpack(lift.bottom), Terrain.unpack(lift.top)).distance_to(point) < 10:
			return false
	for building in model.buildings:
		if Terrain.unpack(building.point).distance_to(point) < (29 if building.kind == "hotel" else 23):
			return false
	return true

func _build_trees() -> void:
	var pine := Art.new().pine()
	pine.surface_set_material(0, _solid)
	var instances := _multimesh(pine, int(3200 * Maps.spec(model.map_id).forest))
	var rock_mesh := Art.new().rock()
	rock_mesh.surface_set_material(0, _solid)
	var stones := _multimesh(rock_mesh, 90)
	var random := RandomNumberGenerator.new()
	random.seed = 73628
	var used := 0
	var stone_count := 0
	for i in range(instances.instance_count * 4):
		var point := Vector2(random.randf_range(terrain.bounds.position.x + 10, terrain.bounds.end.x - 10), random.randf_range(terrain.bounds.position.y + 10, terrain.bounds.end.y - 10))
		if i < 2400:
			point = Vector2(random.randf_range(-500, 500), random.randf_range(-600, 450))
		if point.distance_to(Vector2(-260, 255)) < 62 or point.distance_to(Terrain.BASE) < 46 or not _clear_ground(point, 20):
			continue
		var grade := terrain.slope_percent(point)
		if grade > 47 and stone_count < stones.instance_count:
			var size_value := random.randf_range(0.8, 2.0)
			stones.set_instance_transform(stone_count, Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * size_value), terrain.world(point)))
			stones.set_instance_color(stone_count, Color.WHITE)
			stone_count += 1
			continue
		if grade > 65 or terrain.height(point) > (620 if model.map_id == "fichtenkamm" else 360) or used >= instances.instance_count or absf(sin(point.x * 0.031) * cos(point.y * 0.023)) < 0.18:
			continue
		var size_value := random.randf_range(0.65, 1.15)
		instances.set_instance_transform(used, Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * size_value), terrain.world(point)))
		var tint := random.randf_range(0.86, 1.0)
		instances.set_instance_color(used, Color(tint, tint, tint))
		used += 1
	instances.visible_instance_count = used
	stones.visible_instance_count = stone_count
	trees.multimesh = instances
	rocks.multimesh = stones
	trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	rocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func rebuild() -> void:
	terrain = model.terrain
	if _terrain_id != model.map_id:
		_terrain_id = model.map_id
		for child in landscape.get_children():
			landscape.remove_child(child)
			child.queue_free()
		if is_instance_valid(slope_overlay):
			slope_overlay.queue_free()
			slope_overlay = null
		if is_instance_valid(topography):
			topography.queue_free()
			topography = null
			contour_mesh = null
			downhill_arrows = null
		slopes_visible = false
		_build_terrain()
		_build_surroundings()
	_piste_meshes.clear()
	piste_markers.clear()
	_occluders.clear()
	_snow_seen = -1
	_track_seen = -1
	_guest_positions.clear()
	_seen_revision = model.revision
	for child in asset_root.get_children():
		asset_root.remove_child(child)
		child.queue_free()
	chairs.clear()
	_vehicles.clear()
	_vehicle_counts.clear()
	for piste in model.pistes:
		var color: Color = PISTE_COLORS[piste.difficulty]
		var width: float = 20 + (piste.get("level", 1) - 1) * 4
		var snow_mesh := MeshInstance3D.new()
		snow_mesh.material_override = _solid
		snow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		asset_root.add_child(snow_mesh)
		_piste_meshes[piste.id] = snow_mesh
		_draw_snow(piste)
		var sign_mesh := Art.new().piste_sign(piste.number, color)
		sign_mesh.surface_set_material(0, _solid)
		var sign_fractions: Array = []
		for index in range(piste.points.size()):
			sign_fractions.append(terrain.waypoint_fraction(piste.points, index))
		for i in range(1, ceili(piste.length / 60)):
			var fraction: float = float(i) * 60 / piste.length
			var near_waypoint := false
			for waypoint in sign_fractions:
				near_waypoint = near_waypoint or absf(waypoint - fraction) * piste.length < 12
			if not near_waypoint:
				sign_fractions.append(fraction)
		var signs := _multimesh(sign_mesh, sign_fractions.size() * 2)
		var sign_index := 0
		for fraction in sign_fractions:
			var point := terrain.point_on_path(piste.points, fraction)
			var direction := (terrain.point_on_path(piste.points, minf(fraction + 0.01, 1.0)) - terrain.point_on_path(piste.points, maxf(fraction - 0.01, 0))).normalized()
			var side := direction.orthogonal() * (width * 0.5 + 1.5)
			var angle := atan2(-direction.x, -direction.y)
			for edge in [-1, 1]:
				var at := terrain.world(point + side * edge, 0.25)
				signs.set_instance_transform(sign_index, Transform3D(Basis(Vector3.UP, angle), at))
				signs.set_instance_color(sign_index, Color.WHITE)
				sign_index += 1
				piste_markers.append({"id": piste.id, "number": piste.number, "difficulty": piste.difficulty, "position": at, "facing": -direction, "fraction": fraction})
		var marker_node := MultiMeshInstance3D.new()
		marker_node.multimesh = signs
		asset_root.add_child(marker_node)
		_label(asset_root, "%d · %s" % [piste.number, ["BLAU", "ROT", "SCHWARZ"][piste.difficulty]], terrain.world(Terrain.unpack(piste.points[0]), 24), color)
	for lift in model.lifts:
		_build_lift(lift)
	for building in model.buildings:
		_build_building(building)
	_build_trees()
	_guest_tick = ""

func _build_lift(lift: Dictionary) -> void:
	if lift.kind == "carpet":
		_ribbon(asset_root, [lift.bottom, lift.top], 4, Color("3f626b"), 0.7)
		for endpoint in [lift.bottom, lift.top]:
			_baked(asset_root, Art.new().chalet("shelter", 1, Color("769aa3")), terrain.world(Terrain.unpack(endpoint)))
		return
	if lift.kind == "drag":
		_ribbon(asset_root, [lift.bottom, lift.top], 4, Color("d9e6ef"), 0.2)
	var bottom := Terrain.unpack(lift.bottom)
	var top := Terrain.unpack(lift.top)
	var a := terrain.world(bottom, 15)
	var b := terrain.world(top, 15)
	var angle := atan2(top.x - bottom.x, top.y - bottom.y)
	var station_mesh := Art.new().station(lift.kind, int(lift.get("level", 1)))
	for point in [bottom, top]:
		var instance := _baked(asset_root, station_mesh, terrain.world(point))
		instance.rotation.y = angle
		_occluders.append(instance)
	var profile: Dictionary = model.cable_profile(lift)
	var steel := Art.new()
	for i in range(1, profile.points.size() - 1):
		var head: Vector3 = profile.points[i]
		var ground := Vector2(head.x, head.z)
		steel.link( terrain.world(ground), head, 0.9, Color("536c72"))
		steel.box( head, Vector3(11, 1.2, 2.5), Color("455d64"))
	for i in range(1, profile.points.size()):
		for offset in [-3.0, 3.0]:
			steel.link( profile.points[i - 1] + Vector3(offset, 0, 0), profile.points[i] + Vector3(offset, 0, 0), 0.19, Color("3c5159"))
	_baked(asset_root, steel.finish(), Vector3.ZERO)
	if not _vehicles.has(lift.kind):
		var vehicle_mesh := Art.new().chair(lift.kind)
		vehicle_mesh.surface_set_material(0, _solid)
		var group := MultiMeshInstance3D.new()
		group.multimesh = _multimesh(vehicle_mesh, 24 * 72)
		group.multimesh.visible_instance_count = 0
		asset_root.add_child(group)
		_vehicles[lift.kind] = group
		_vehicle_counts[lift.kind] = 0
	var count := clampi(ceili(lift.length / 18) * 2, 12, 72)
	for i in range(count):
		var index: int = _vehicle_counts[lift.kind]
		_vehicle_counts[lift.kind] += 1
		chairs.append({"kind": lift.kind, "index": index, "angle": angle, "a": a, "b": b, "offset": float(i) / count, "id": lift.id})
		_vehicles[lift.kind].multimesh.set_instance_color(index, Color.WHITE)
		_vehicles[lift.kind].multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.UP, angle), model.cable_position(lift, float(i) / count) + Vector3(-3, -4, 0)))
	_vehicles[lift.kind].multimesh.visible_instance_count = _vehicle_counts[lift.kind]

func _build_building(building: Dictionary) -> void:
	var point := Terrain.unpack(building.point)
	var instance := _baked(asset_root, Art.new().chalet(building.kind, int(building.get("level", 1)), Color(Catalog.BUILDINGS[building.kind].color)), terrain.world(point))
	_occluders.append(instance)
	if building.kind == "snowmaker":
		return
	var endpoint := Terrain.BASE
	var nearest := point.distance_to(endpoint)
	for lift in model.lifts:
		for station in [lift.bottom, lift.top]:
			if Terrain.unpack(station).distance_to(point) < nearest:
				nearest = Terrain.unpack(station).distance_to(point)
				endpoint = Terrain.unpack(station)
	if point.distance_to(endpoint) > 4:
		_ribbon(asset_root, [Terrain.pack(point), Terrain.pack(endpoint)], 3.5, Color("c3c4b9"), 0.21)

func _ribbon(parent: Node3D, points: Array, width: float, color: Color, offset: float) -> void:
	if points.size() < 2:
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, points.size()):
		var from := Terrain.unpack(points[i - 1])
		var to := Terrain.unpack(points[i])
		var side := (to - from).normalized().orthogonal() * width * 0.5
		var steps := maxi(1, ceili(from.distance_to(to) / 6.0))
		for j in range(steps):
			var a := from.lerp(to, float(j) / steps)
			var b := from.lerp(to, float(j + 1) / steps)
			var vertices := [a + side, b + side, a - side, b - side]
			for index in [0, 1, 2, 2, 1, 3]:
				surface.add_vertex(terrain.world(vertices[index], offset))
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	var material := _material(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func preview(points: Array, color: Color, building_kind: String = "", analysis: Dictionary = {}) -> void:
	for child in preview_root.get_children():
		preview_root.remove_child(child)
		child.queue_free()
	if points.is_empty():
		return
	if analysis.has("segments") and analysis.segments.size() == points.size() - 1:
		for i in range(analysis.segments.size()):
			var section_color: Color = PISTE_COLORS[analysis.segments[i].difficulty]
			if analysis.segments[i].drop < -1.5:
				section_color = Color("efb17d")
			_ribbon(preview_root, [points[i], points[i + 1]], 7, section_color, 1.2)
	else:
		_ribbon(preview_root, points, 7, color, 1.2)
	for point in points:
		var sphere := SphereMesh.new()
		sphere.radius = 3.5
		sphere.height = 7
		_mesh(preview_root, sphere, terrain.world(Terrain.unpack(point), 4), color)
	if analysis.has("segments"):
		for i in range(1, points.size()):
			var a := Terrain.unpack(points[i - 1])
			var b := Terrain.unpack(points[i])
			var direction := (b - a).normalized()
			var arrow := _baked(preview_root, Art.new().downhill_arrow(), terrain.world(a.lerp(b, 0.5), 2.5))
			arrow.rotation.y = atan2(-direction.x, -direction.y)
	if building_kind != "":
		_baked(preview_root, Art.new().chalet(building_kind, 1, color), terrain.world(Terrain.unpack(points.back())))

func _update_atmosphere() -> void:
	var key := "%d-%d-%d" % [model.day, model.minute, model.weather_index]
	if key == _atmosphere_tick:
		return
	_atmosphere_tick = key
	var daylight := sin(clampf(float(model.minute - 420) / 720.0, 0.05, 0.95) * PI)
	_sun.light_energy = (0.35 + daylight * 0.17) * (0.55 if model.weather_index in [2, 3] else 1.0)
	_sun.light_color = Color("f7e3ce").lerp(Color("fffdf7"), daylight)
	_sun.rotation_degrees.x = -25 - daylight * 32
	_environment.fog_density = 0.00065 if model.weather_index == 2 else (0.0004 if model.weather_index == 3 else 0.00008)
	_snow.emitting = model.weather_index in [1, 3]
	_snow.position = terrain.world(focus, 130)

func _process(delta: float) -> void:
	if model == null:
		return
	if model.revision != _seen_revision:
		rebuild()
	_update_atmosphere()
	_snow.position = terrain.world(focus, 130)
	_visual_minute = model.minute + simulation_fraction
	_car_positions.clear()
	for chair in chairs:
		var lift: Dictionary = model.asset(chair.id)
		var distance: float = (_visual_minute - model.OPENING) * model.lift_speed(lift) / model.TRANSPORT_SCALE
		var t := fposmod(distance / maxf(lift.length * 2, 1) + chair.offset, 1)
		var outbound := t < 0.5
		var position_value: Vector3 = model.cable_position(lift, t * 2 if outbound else (1 - t) * 2) + Vector3(-3 if outbound else 3, -4, 0)
		if not model.lift_open(lift):
			continue
		_vehicles[chair.kind].multimesh.set_instance_transform(chair.index, Transform3D(Basis(Vector3.UP, chair.angle + (0 if outbound else PI)), position_value))
		if outbound:
			if not _car_positions.has(lift.id):
				_car_positions[lift.id] = []
			_car_positions[lift.id].append({"fraction": t * 2, "point": position_value})
	var next_positions: Dictionary = {}
	var walking := 0
	var riding := 0
	for guest in model.guests:
		var position_value: Vector3 = model.guest_position(guest, simulation_fraction)
		var angle := 0.0
		var lean := 0.0
		var pitch := 0.0
		var seated := false
		if guest.phase != "leaving" and guest.leg < guest.route.legs.size():
			var leg: Dictionary = guest.route.legs[guest.leg]
			var fraction: float = clampf((guest.elapsed + simulation_fraction) / guest.get("duration", leg.minutes), 0, 1)
			if leg.kind == "ski":
				fraction = model.ski_fraction(leg, fraction)
				var piste: Dictionary = model.asset(leg.id)
				var personal := Motion.frame(terrain, piste, guest.id, guest.ability, fraction, guest.loops, leg.get("start_fraction", 0), leg.get("end_fraction", 1))
				angle = personal.yaw
				lean = personal.lean
				var before: Vector3 = terrain.world(Motion.position(terrain, piste, guest.id, guest.ability, maxf(0, fraction - 0.004), guest.loops, leg.get("start_fraction", 0), leg.get("end_fraction", 1)))
				var ahead: Vector3 = terrain.world(Motion.position(terrain, piste, guest.id, guest.ability, minf(1, fraction + 0.004), guest.loops, leg.get("start_fraction", 0), leg.get("end_fraction", 1)))
				pitch = atan2(before.y - ahead.y, Vector2(ahead.x - before.x, ahead.z - before.z).length())
			elif leg.kind == "lift" and guest.phase == "moving":
				var lift: Dictionary = model.asset(leg.id)
				var direction := Terrain.unpack(lift.top) - Terrain.unpack(lift.bottom)
				angle = atan2(direction.x, direction.y)
				if lift.kind in ["chair", "chair6", "gondola"]:
					seated = true
					var nearest := INF
					for car in _car_positions.get(lift.id, []):
						if absf(car.fraction - fraction) < nearest:
							nearest = absf(car.fraction - fraction)
							var seats := 6 if lift.kind == "chair6" else (8 if lift.kind == "gondola" else 4)
							var seat: int = int(guest.id) % seats
							var x: float = (seat % 4 - 1.5) if lift.kind == "gondola" else (seat - (seats - 1) * 0.5) * (0.7 if seats == 6 else 1.0)
							var z: float = (floori(seat / 4.0) - 0.5) * 1.6 if lift.kind == "gondola" else 0
							position_value = car.point + Basis(Vector3.UP, angle) * Vector3(x, 0.15, z)
			else:
				var a := Terrain.unpack(leg.points[0])
				var b := Terrain.unpack(leg.points.back())
				angle = atan2(b.x - a.x, b.y - a.y)
		var color := Color(Motion.COLORS[int(guest.id) % Motion.COLORS.size()])
		var transform_value := Transform3D(Basis.from_euler(Vector3(pitch, angle, lean)), position_value)
		if seated:
			_riders.multimesh.set_instance_transform(riding, transform_value)
			_riders.multimesh.set_instance_color(riding, color)
			riding += 1
		else:
			visitor_mesh.multimesh.set_instance_transform(walking, transform_value)
			visitor_mesh.multimesh.set_instance_color(walking, color)
			walking += 1
		next_positions[guest.id] = position_value
		if follow_guest == int(guest.id):
			focus = Vector2(position_value.x, position_value.z)
			_update_camera()
	_guest_positions = next_positions
	_update_occlusion(delta)
	visitor_mesh.multimesh.visible_instance_count = walking
	_riders.multimesh.visible_instance_count = riding
	var machines := 0
	for piste in model.pistes:
		if piste.get("grooming_until", 0) <= model.minute:
			continue
		var fraction: float = clampf(1 - (piste.grooming_until - model.minute - simulation_fraction) / 45.0, 0, 1)
		var point: Vector2 = terrain.point_on_path(piste.points, fraction)
		var ahead: Vector2 = terrain.point_on_path(piste.points, minf(1, fraction + 0.01))
		_groomers.multimesh.set_instance_transform(machines, Transform3D(Basis(Vector3.UP, atan2(ahead.x - point.x, ahead.y - point.y)), terrain.world(point, 1.5)))
		_groomers.multimesh.set_instance_color(machines, Color.WHITE)
		machines += 1
	_groomers.multimesh.visible_instance_count = machines
	_snow_timer += delta
	if _snow_timer > 1.2 and model.snow_revision != _snow_seen:
		_snow_timer = 0
		_snow_seen = model.snow_revision
		for piste in model.pistes:
			_draw_snow(piste)
	_track_timer += delta
	if _track_timer > 0.5 and (model.snow_revision != _track_seen or focus.distance_to(_track_focus) > 100 or (motion_running and zoom < 220)):
		_track_timer = 0
		_track_seen = model.snow_revision
		_track_focus = focus
		_draw_tracks()

func _update_occlusion(delta: float) -> void:
	var target := terrain.world(focus, 2.5)
	for instance in _occluders:
		var aabb: AABB = instance.get_aabb()
		var center: Vector3 = instance.global_transform * aabb.get_center()
		var near := Geometry3D.get_closest_point_to_segment(center, camera.global_position, target)
		var fade: bool = follow_guest != -1 and zoom < 180 and near.distance_to(center) < aabb.size.length() * 0.4
		if not fade and not instance.has_meta("fade_material"):
			continue
		if not instance.has_meta("fade_material"):
			var material: StandardMaterial3D = _solid.duplicate()
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			instance.material_override = material
			instance.set_meta("fade_material", material)
		var material: StandardMaterial3D = instance.get_meta("fade_material")
		material.albedo_color.a = lerpf(material.albedo_color.a, 0.18 if fade else 1.0, minf(1, delta * 8))

func pick_guest(point: Vector2) -> int:
	var best := 18.0
	var id := -1
	for guest in model.guests:
		var position_value: Vector3 = _guest_positions.get(guest.id, model.guest_position(guest))
		var distance: float = camera.unproject_position(position_value).distance_to(point)
		if distance < best:
			best = distance
			id = guest.id
	return id

func _draw_snow(piste: Dictionary) -> void:
	Snow.ensure(piste)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := ceili(piste.length / 4)
	var width: float = 20 + (piste.get("level", 1) - 1) * 4
	for row in range(count):
		var fractions := [float(row) / count, float(row + 1) / count]
		var vertices: Array = []
		var colors: Array = []
		for fraction in fractions:
			var center: Vector2 = terrain.point_on_path(piste.points, fraction)
			var before: Vector2 = terrain.point_on_path(piste.points, maxf(0, fraction - 0.004))
			var ahead: Vector2 = terrain.point_on_path(piste.points, minf(1, fraction + 0.004))
			var side := (ahead - before).normalized().orthogonal()
			for lane in range(Snow.LANES + 1):
				var lateral := (float(lane) / Snow.LANES - 0.5) * width
				var relief := Snow.relief(piste, fraction, lateral)
				vertices.append(terrain.world(center + side * lateral, 1.3 + relief))
				var color := Color("e4edf4").lerp(Color("b8cedc"), clampf(-relief, 0, 0.35))
				if lane in [0, Snow.LANES]:
					color = PISTE_COLORS[piste.difficulty].lightened(0.2)
				elif row % 3 == 0 and piste.tracks.is_empty():
					color = color.darkened(0.018)
				colors.append(color)
		for lane in range(Snow.LANES):
			for index in [lane, lane + 1, lane + Snow.LANES + 1, lane + 1, lane + Snow.LANES + 2, lane + Snow.LANES + 1]:
				surface.set_color(colors[index])
				surface.add_vertex(vertices[index])
	surface.index()
	surface.generate_normals()
	_piste_meshes[piste.id].mesh = surface.commit()

func _track_point(piste: Dictionary, id: int, ability: int, fraction: float, run: int, side_offset: float, range_start: float = 0, range_end: float = 1) -> Vector3:
	var frame := Motion.frame(terrain, piste, id, ability, fraction, run, range_start, range_end)
	var side: Vector2 = frame.direction.orthogonal()
	var point: Vector2 = frame.point + side * side_offset
	var center: Vector2 = terrain.point_on_path(piste.points, fraction)
	var road_side: Vector2 = (terrain.point_on_path(piste.points, minf(1, fraction + 0.005)) - terrain.point_on_path(piste.points, maxf(0, fraction - 0.005))).normalized().orthogonal()
	return terrain.world(point, 1.35 + Snow.mesh_relief(piste, fraction, (point - center).dot(road_side)))

func _trace_quad(surface: SurfaceTool, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var side := Vector3(b.z - a.z, 0, a.x - b.x).normalized() * width
	for point in [a + side, b + side, a - side, a - side, b + side, b - side]:
		surface.set_color(color)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(point)

func _draw_tracks() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 0
	var live: Dictionary = {}
	for guest in model.guests:
		if guest.has("track") and guest.phase == "moving" and guest.leg < guest.route.legs.size() and guest.route.legs[guest.leg].kind == "ski":
			live[guest.track] = model.ski_fraction(guest.route.legs[guest.leg], (guest.elapsed + simulation_fraction) / guest.duration)
	var visible: Array = []
	var followed_track := ""
	var followed_piste := -1
	var followed_record: Dictionary = {}
	for guest in model.guests:
		if int(guest.id) == follow_guest and guest.phase == "moving" and guest.leg < guest.route.legs.size() and guest.route.legs[guest.leg].kind == "ski":
			followed_piste = guest.route.legs[guest.leg].id
			followed_track = guest.get("track", "")
			followed_record = {"key": followed_track, "guest": int(guest.id), "ability": int(guest.ability), "run": int(guest.loops), "from": guest.route.legs[guest.leg].get("start_fraction", 0.0), "until": guest.route.legs[guest.leg].get("end_fraction", 1.0), "to": live.get(followed_track, 0.0)}
	for piste in model.pistes:
		if terrain.point_on_path(piste.points, 0.5).distance_to(focus) <= maxf(zoom * 2 + piste.length * 0.5, 600):
			visible.append(piste)
	visible.sort_custom(func(a, b):
		if int(a.id) == int(b.id):
			return false
		if int(a.id) == followed_piste:
			return true
		if int(b.id) == followed_piste:
			return false
		return terrain.point_on_path(a.points, 0.5).distance_to(focus) < terrain.point_on_path(b.points, 0.5).distance_to(focus)
	)
	var quota := maxi(256, floori(4000.0 / maxi(visible.size(), 1)))
	for piste in visible:
		var tracks: Array = piste.get("tracks", [])
		var ordered: Array = []
		for track in tracks:
			if track.key == followed_track:
				ordered.append(track)
		if ordered.is_empty() and int(piste.id) == followed_piste and not followed_record.is_empty():
			ordered.append(followed_record)
		for i in range(tracks.size() - 1, -1, -1):
			if live.has(tracks[i].key) and tracks[i].key != followed_track:
				ordered.append(tracks[i])
		for i in range(tracks.size() - 1, -1, -1):
			if not live.has(tracks[i].key) and tracks[i].key != followed_track and ordered.size() < 24:
				ordered.append(tracks[i])
		var piste_segments := 0
		for track in ordered:
			var end: float = maxf(track.to, live.get(track.key, 0.0))
			var start: float = track.get("from", 0.0)
			var count := ceili((end - start) * piste.length / 1.6)
			if count == 0:
				continue
			var available := mini(quota - piste_segments, 4000 - segments)
			for j in range(maxi(0, count - available), count):
				if segments >= 4000 or piste_segments >= quota:
					break
				for ski in [-0.28, 0.28]:
					var a := _track_point(piste, track.guest, track.ability, lerpf(start, end, float(j) / count), track.run, ski, start, track.get("until", 1.0))
					var b := _track_point(piste, track.guest, track.ability, lerpf(start, end, float(j + 1) / count), track.run, ski, start, track.get("until", 1.0))
					_trace_quad(surface, a, b, 0.10, Color("91adbf"))
					_trace_quad(surface, a + Vector3(0.1, 0.035, 0.1), b + Vector3(0.1, 0.035, 0.1), 0.04, Color("edf5f9"))
				segments += 1
				piste_segments += 1
	if segments == 0:
		_track_mesh.mesh = null
		return
	_track_mesh.mesh = surface.commit()
	_track_mesh.material_override = _solid
	_track_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_camera_mode(value: int) -> void:
	camera_mode = clampi(value, 0, CAMERA_MODES.size() - 1)
	pitch_degrees = CAMERA_PITCHES[camera_mode]
	_update_camera()

func set_camera_pitch(value: float) -> void:
	pitch_degrees = clampf(value, 20, 80)
	if camera_mode == 3:
		camera_mode = 2
	_update_camera()

func _update_camera() -> void:
	camera.size = zoom
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if camera_mode == 3 else Camera3D.PROJECTION_PERSPECTIVE
	var target := terrain.world(focus, clampf(zoom * 0.06, 3, 38))
	if camera_mode == 3:
		camera.position = target + Vector3.UP * maxf(zoom * 1.6, 1500)
		camera.look_at(target, Vector3(-sin(yaw), 0, -cos(yaw)))
	else:
		# Keep the apparent scale similar while changing the viewing angle.
		var distance := zoom * 1.22
		var pitch := deg_to_rad(pitch_degrees)
		camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
		camera.look_at(target)

func pan(relative: Vector2) -> void:
	follow_guest = -1
	var units := zoom / maxf(get_viewport().get_visible_rect().size.y, 1)
	var right := Vector2(camera.basis.x.x, camera.basis.x.z)
	var up := Vector2(camera.basis.y.x, camera.basis.y.z)
	focus += (-right * relative.x + up * relative.y * (1.0 if camera_mode == 3 else 1.7)) * units
	focus.x = clampf(focus.x, terrain.bounds.position.x + 20, terrain.bounds.end.x - 20)
	focus.y = clampf(focus.y, terrain.bounds.position.y + 20, terrain.bounds.end.y - 20)
	_update_camera()

func change_zoom(factor: float) -> void:
	zoom = clampf(zoom * factor, 48, maxf(terrain.bounds.size.x, terrain.bounds.size.y) * 1.25)
	_update_camera()

func rotate_view(amount: float) -> void:
	yaw += amount
	_update_camera()

func overview() -> void:
	follow_guest = -1
	focus = terrain.bounds.get_center()
	zoom = maxf(terrain.bounds.size.x, terrain.bounds.size.y) * 0.72
	_update_camera()

func home() -> void:
	terrain = model.terrain
	follow_guest = -1
	focus = Vector2(210, 10)
	zoom = 620
	yaw = 0.46
	_update_camera()

func map_point(screen_point: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(screen_point)
	var direction := camera.project_ray_normal(screen_point)
	var previous := 0.0
	for step in range(0, 20000, 20):
		var world_point := origin + direction * step
		var point := Vector2(world_point.x, world_point.z)
		if terrain.contains(point) and world_point.y <= terrain.height(point):
			var low := previous
			var high := float(step)
			for i in range(12):
				var middle := (low + high) * 0.5
				var sample := origin + direction * middle
				if sample.y <= terrain.height(Vector2(sample.x, sample.z)):
					high = middle
				else:
					low = middle
			var hit := origin + direction * high
			return Vector2(hit.x, hit.z)
		previous = step
	return Vector2.INF

func pick_asset(point: Vector2) -> int:
	var closest := 24.0
	var id := -1
	for building in model.buildings:
		var distance := point.distance_to(Terrain.unpack(building.point))
		if distance < closest:
			closest = distance
			id = building.id
	for lift in model.lifts:
		var distance := Geometry2D.get_closest_point_to_segment(point, Terrain.unpack(lift.bottom), Terrain.unpack(lift.top)).distance_to(point)
		if distance < closest:
			closest = distance
			id = lift.id
	for piste in model.pistes:
		for i in range(1, piste.points.size()):
			var distance := Geometry2D.get_closest_point_to_segment(point, Terrain.unpack(piste.points[i - 1]), Terrain.unpack(piste.points[i])).distance_to(point)
			if distance < closest:
				closest = distance
				id = piste.id
	return id
