extends Node3D
const L = preload("res://src/core/i18n.gd")
## Original, batched alpine scenery and a simulation-driven atmosphere.

const Terrain = preload("res://src/core/terrain.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Mountain = preload("res://src/core/mountain.gd")
const Maps = preload("res://src/core/maps.gd")
const Motion = preload("res://src/core/ski_motion.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const Fleet = preload("res://src/core/lift_fleet.gd")
const Foot = preload("res://src/core/foot_network.gd")
const PisteMesh = preload("res://src/world/piste_mesh.gd")
const SnowRender = preload("res://src/world/snow_render.gd")
const SurfacePicker = preload("res://src/world/surface_picker.gd")
const ForestLOD = preload("res://src/world/forest_lod.gd")
const Art = preload("res://src/world/alpine_art.gd")
const PISTE_COLORS := [Color("368bcb"), Color("ce5660"), Color("202c39")]

var snow_renderer := SnowRender.new()
var surface_picker := SurfacePicker.new()
var _terrain_grading := -1
var piste_furniture: Array = []
var forest := ForestLOD.new()
var _art_cache: Dictionary = {}
var _vehicle_sets: Dictionary = {}
var _label_tick := -1
var _trace_cache: Dictionary = {}
var trace_samples := 0
var _tracks_pending := false
var trace_budget := 1200
var _motion_cache: Dictionary = {}
var quality := "auto"
var quality_tier := 1
var effects_enabled := true
var camera_smoothing := true
var frame_target := 1.0 / 60
var _frame_average := 1.0 / 60
var _quality_timer := 0.0
var selected_guest := -1
var _selection := MeshInstance3D.new()

var model: RefCounted
var terrain: Mountain
var landscape := Node3D.new()
var simulation_fraction := 0.0
var motion_running := false
var motion_rate := 1.0
var follow_guest := -1
var _follow_position := Vector3.INF
var _terrain_id := ""
var _snow_timer := 0.0
var _snow_seen := -1
var _piste_meshes: Dictionary = {}
var _snow_geometry: Dictionary = {}
var _track_mesh := MeshInstance3D.new()
var _riders := MultiMeshInstance3D.new()
var _cabin_riders := MultiMeshInstance3D.new()
var _walkers := MultiMeshInstance3D.new()
var _climbers := MultiMeshInstance3D.new()
var _equipment: Dictionary = {}
var _tow_lines := MultiMeshInstance3D.new()
var _vehicle_glass: Dictionary = {}
var _queue_labels: Dictionary = {}
var _pedestrian_snapshot: Dictionary = {}
var foot_mesh: MeshInstance3D
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
var _queue_paths: Dictionary = {}
var _visual_minute := 480.0
var _atmosphere_tick := ""
var _solid: StandardMaterial3D
var _people_material := ShaderMaterial.new()
var _vehicles: Dictionary = {}
var _vehicle_counts: Dictionary = {}

func setup(resort: RefCounted) -> void:
	model = resort
	terrain = model.terrain
	_terrain_id = model.map_id
	add_child(landscape)
	_solid = _material(Color.WHITE, true)
	var people_shader := Shader.new()
	people_shader.code = """
shader_type spatial;
void vertex() {
 COLOR.rgb *= mix(vec3(1.0), INSTANCE_CUSTOM.rgb, COLOR.a);
 COLOR.a = 1.0;
}
void fragment() {
 ALBEDO = COLOR.rgb;
 ROUGHNESS = 0.94;
 SPECULAR = 0.12;
}
"""
	_people_material.shader = people_shader
	_build_environment()
	_build_terrain()
	_build_surroundings()
	for node in [trees, rocks, asset_root, preview_root, visitor_mesh, _riders, _cabin_riders, _walkers, _climbers, _tow_lines, _groomers, _track_mesh]:
		add_child(node)
	visitor_mesh.multimesh = _multimesh(Art.new().skier(false), model.MAX_GUESTS,true)
	visitor_mesh.material_override = _people_material
	visitor_mesh.multimesh.visible_instance_count = 0
	visitor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_riders.multimesh = _multimesh(Art.new().seated_skier(false), model.MAX_GUESTS,true)
	_riders.material_override = _people_material
	_riders.multimesh.visible_instance_count = 0
	_cabin_riders.multimesh = _multimesh(Art.new().seated_skier(false), model.MAX_GUESTS,true)
	_cabin_riders.material_override = _people_material
	_cabin_riders.multimesh.visible_instance_count = 0
	_walkers.multimesh = _multimesh(Art.new().skier(false), model.MAX_GUESTS,true)
	_walkers.material_override = _people_material
	_walkers.multimesh.visible_instance_count = 0
	_climbers.multimesh = _multimesh(Art.new().skier(false,true),model.MAX_GUESTS,true)
	_climbers.material_override = _people_material
	_climbers.multimesh.visible_instance_count = 0
	for sport in Motion.SPORTS:
		for pose in ["glide", "seated", "walk", "hike"]:
			var node := MultiMeshInstance3D.new()
			node.name = "Equipment_" + sport + "_" + pose
			node.multimesh = _multimesh(Art.new().equipment(sport, pose), model.MAX_GUESTS)
			node.material_override = _solid
			node.multimesh.visible_instance_count = 0
			add_child(node)
			_equipment[sport + "/" + pose] = node
	var tow := CylinderMesh.new()
	tow.height = 1
	tow.top_radius = 0.055
	tow.bottom_radius = 0.055
	tow.radial_segments = 5
	_tow_lines.multimesh = _multimesh(tow, 24 * Fleet.MAX_CARRIERS)
	_tow_lines.material_override = _material(Color("495c60"))
	_tow_lines.multimesh.visible_instance_count = 0
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
	var ring := TorusMesh.new()
	ring.inner_radius = 2.3
	ring.outer_radius = 2.7
	ring.rings = 16
	ring.ring_segments = 6
	_selection.mesh = ring
	_selection.material_override = _material(Color("efb17d"))
	_selection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_selection.visible = false
	add_child(_selection)
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
	_sun.light_color = Color("fff0da")
	_sun.light_energy = 0.76
	_sun.light_angular_distance = 1.5
	_sun.shadow_blur = 1.6
	_sun.shadow_opacity = 0.55
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 1500
	add_child(_sun)
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("a9cddd")
	sky_material.sky_horizon_color = Color("f3e8df")
	sky_material.ground_horizon_color = Color("f3e8df")
	sky_material.ground_bottom_color = Color("b9c8dc")
	var sky := Sky.new()
	sky.sky_material = sky_material
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("c7d9e9")
	_environment.ambient_light_energy = 0.26
	# Linear tone mapping keeps snow detail on the Android compatibility renderer.
	_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("d7e2f0")
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
	var snow := Color("e5eaf6").lerp(Color("f4f5fc"), clampf(height_value / 420.0, 0, 1))
	if grade > 38:
		snow = snow.lerp(Color("929cb3"), clampf((grade - 38) / 65.0, 0, 0.74))
	return snow.darkened(0.018 + sin(point.x * 0.047 + point.y * 0.027) * 0.018)

func _land_mesh(bounds: Rect2, step_size: int, outside: bool = false) -> ArrayMesh:
	var nx := ceili(bounds.size.x / step_size) + 1
	var nz := ceili(bounds.size.y / step_size) + 1
	var refined: Dictionary = {} if outside else terrain.grading.refined_cells(bounds, step_size)
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
			if not refined.has(Vector2i(x, z)):
				indices.append_array(PackedInt32Array([i, i + 1, i + nx, i + 1, i + nx + 1, i + nx]))
	# Only the built corridors and a shoulder are refined to four-metre cells.
	# Boundary heights interpolate the adjacent coarse edge, preventing cracks.
	for cell: Vector2i in refined:
		if cell.x < 0 or cell.y < 0 or cell.x >= nx - 1 or cell.y >= nz - 1: continue
		var first := vertices.size()
		var corner := cell.y * nx + cell.x
		var a := vertices[corner]
		var b := vertices[corner + 1]
		var c := vertices[corner + nx]
		var d := vertices[corner + nx + 1]
		for z in range(6):
			for x in range(6):
				var u := float(x) / 5
				var v := float(z) / 5
				var at := a.lerp(b, u).lerp(c.lerp(d, u), v)
				var boundary: bool = (x == 0 and not refined.has(cell + Vector2i.LEFT)) or (x == 5 and not refined.has(cell + Vector2i.RIGHT)) or (z == 0 and not refined.has(cell + Vector2i.UP)) or (z == 5 and not refined.has(cell + Vector2i.DOWN))
				if not boundary: at.y = terrain.height(Vector2(at.x, at.z))
				vertices.append(at)
				normals.append(normals[corner].lerp(normals[corner + 1], u).lerp(normals[corner + nx].lerp(normals[corner + nx + 1], u), v).normalized())
				colors.append(colors[corner].lerp(colors[corner + 1], u).lerp(colors[corner + nx].lerp(colors[corner + nx + 1], u), v))
				if x < 5 and z < 5:
					var i := first + z * 6 + x
					indices.append_array(PackedInt32Array([i, i + 1, i + 6, i + 1, i + 7, i + 6]))
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

func _label(parent: Node3D, title: String, position_value: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = L.text(title)
	label.set_meta("source_text",title)
	label.font_size = 34
	label.pixel_size = 0.15
	label.position = position_value
	label.modulate = color
	label.outline_modulate = Color("eef5f5")
	label.outline_size = 10
	label.visibility_range_begin = 150
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)
	return label

func relocalize() -> void:
	var pending: Array=[self]
	while not pending.is_empty():
		var node: Node=pending.pop_back()
		pending.append_array(node.get_children())
		if node is Label3D and node.has_meta("source_text"):
			if node.has_meta("piste_id"):
				var piste: Dictionary=model.asset(node.get_meta("piste_id"))
				node.text=L.format_message("%d · %s",[piste.number,["BLAU","ROT","SCHWARZ"][int(piste.difficulty)]])
			else: node.text=L.text(node.get_meta("source_text"))
	_label_tick=-1

func _multimesh(mesh: Mesh, count: int, personal: bool = false) -> MultiMesh:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.use_custom_data = personal
	instances.mesh = mesh
	instances.instance_count = count
	return instances

func _clear_ground(point: Vector2, margin: float) -> bool:
	for area in _pedestrian_snapshot.get("areas", []):
		if point.distance_to(area.center) < area.radius + 3:
			return false
	for path in _pedestrian_snapshot.get("links", []):
		for j in range(1, path.points.size()):
			if Geometry2D.get_closest_point_to_segment(point, Terrain.unpack(path.points[j - 1]), Terrain.unpack(path.points[j])).distance_to(point) < 7:
				return false
	for piste in model.pistes:
		for j in range(1, piste.points.size()):
			if Geometry2D.get_closest_point_to_segment(point, Terrain.unpack(piste.points[j - 1]), Terrain.unpack(piste.points[j])).distance_to(point) < margin:
				return false
	for lift in model.lifts:
		if Geometry2D.get_closest_point_to_segment(point, Terrain.unpack(lift.bottom), Terrain.unpack(lift.top)).distance_to(point) < maxf(12, Fleet.rope_offset(lift) + (3.8 if Fleet.family(lift) == "gondola" else Fleet.seats(lift) * Fleet.SEAT_SPACING * 0.5) + 10):
			return false
	for building in model.buildings:
		if Terrain.unpack(building.point).distance_to(point) < (29 if building.kind == "hotel" else 23):
			return false
	return true

func _build_trees() -> void:
	forest.build(self)

func rebuild() -> void:
	terrain = model.terrain
	surface_picker.reset()
	piste_furniture.clear()
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
	if _terrain_grading != terrain.grading.signature:
		_terrain_grading = terrain.grading.signature
		terrain_instance.mesh = _land_mesh(terrain.bounds, 20)
		if is_instance_valid(slope_overlay):
			slope_overlay.queue_free()
			slope_overlay = null
		if is_instance_valid(topography):
			topography.queue_free()
			topography = null
		if slopes_visible:
			_build_slope_overlay()
			_build_topography()
	surface_picker.add_mesh("ground", terrain_instance.mesh)
	for child in landscape.get_children():
		if child.has_meta("walk_surface"): surface_picker.add_mesh("floor_%d" % child.get_instance_id(), child.mesh)
	_queue_paths.clear()
	_motion_cache.clear()
	_trace_cache.clear()
	_track_mesh.mesh = null
	_tracks_pending = false
	snow_renderer.reset()
	_vehicle_sets.clear()
	_label_tick = -1
	_piste_meshes.clear()
	_snow_geometry.clear()
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
	_vehicle_glass.clear()
	_queue_labels.clear()
	_pedestrian_snapshot = model.pedestrian_layout()
	_build_foot_areas()
	var title_positions: Array[Vector2] = []
	var junctions: Dictionary = {}
	for piste in model.pistes:
		for point in piste.points:
			var key := Terrain.unpack(point).snapped(Vector2.ONE * 0.5)
			junctions[key] = junctions.get(key, 0) + 1
	for piste in model.pistes:
		var color: Color = PISTE_COLORS[piste.difficulty]
		var width: float = Snow.piste_width(piste)
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
			var point := Terrain.unpack(piste.points[index]).snapped(Vector2.ONE * 0.5)
			if index == 0 or index == piste.points.size() - 1 or junctions.get(point, 0) > 1:
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
				if not piste_clear(Vector2(at.x, at.z), 1.2): continue
				signs.set_instance_transform(sign_index, Transform3D(Basis(Vector3.UP, angle), at))
				signs.set_instance_color(sign_index, Color.WHITE)
				sign_index += 1
				piste_markers.append({"id": piste.id, "number": piste.number, "difficulty": piste.difficulty, "position": at, "facing": -direction, "fraction": fraction})
		var marker_node := MultiMeshInstance3D.new()
		signs.visible_instance_count = sign_index
		marker_node.multimesh = signs
		asset_root.add_child(marker_node)
		var start := Terrain.unpack(piste.points[0])
		var show_title := true
		for previous in title_positions:
			show_title = show_title and start.distance_to(previous) > 80
		if show_title:
			title_positions.append(start)
			var marker:=_label(asset_root,L.format_message("%d · %s",[piste.number,["BLAU","ROT","SCHWARZ"][piste.difficulty]]),terrain.world(start,24),color)
			marker.set_meta("piste_id",int(piste.id))
	for lift in model.lifts:
		_build_lift(lift)
	for building in model.buildings:
		_build_building(building)
	_build_trees()
	_guest_tick = ""

func _build_foot_areas() -> void:
	# One shared grid avoids z-fighting where plazas grow into one another.
	var cells: Dictionary = {}
	var corners: Dictionary = {}
	const STEP := 4
	for area in _pedestrian_snapshot.areas:
		var center: Vector2 = area.center
		var radius: float = area.radius
		for x in range(floori((center.x - radius) / STEP), ceili((center.x + radius) / STEP)):
			for z in range(floori((center.y - radius) / STEP), ceili((center.y + radius) / STEP)):
				var cell := Vector2i(x, z)
				if (Vector2(cell) * STEP + Vector2.ONE * STEP * 0.5).distance_to(center) > radius:
					continue
				cells[cell] = true
				for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
					var key: Vector2i = cell + offset
					var edge := clampf((radius - (Vector2(key) * STEP).distance_to(center)) / 6, 0, 1)
					corners[key] = maxf(corners.get(key, 0), edge)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices: Dictionary = {}
	for key in corners:
		var at := Vector2(key) * STEP
		var point := terrain.world(at, 0.32)
		vertices[key] = {"point": point, "color": _ground_color(at, point.y).lerp(Color("d2dce8"),corners[key]*0.75)}
	for cell in cells:
		for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
			var vertex: Dictionary = vertices[cell + offset]
			surface.set_color(vertex.color)
			surface.add_vertex(vertex.point)
	surface.index()
	surface.generate_normals()
	foot_mesh = _baked(asset_root, surface.commit(), Vector3.ZERO)
	surface_picker.add_mesh("plazas", foot_mesh.mesh)
	foot_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for link in _pedestrian_snapshot.links:
		_ribbon(asset_root,link.points,link.get("width",7),Color("d4dfe8"),0.39)
		_ribbon(asset_root,link.points,link.get("width",7)*0.66,Color("cbd8e1"),0.42)
	var furniture_mesh := Art.new().plaza_details()
	for area in _pedestrian_snapshot.areas:
		if area.kind not in ["station", "plaza"]:
			continue
		for index in range(3):
			var at: Vector2 = area.center + Vector2.from_angle(index * TAU / 3 + 0.4) * area.radius * 0.78
			if not Foot.contains(_pedestrian_snapshot, at) or not Foot.free_of_buildings(at, model.buildings, 9):
				continue
			var near_path := false
			for link in _pedestrian_snapshot.links:
				for i in range(1, link.points.size()):
					near_path = near_path or Geometry2D.get_closest_point_to_segment(at, Terrain.unpack(link.points[i - 1]), Terrain.unpack(link.points[i])).distance_to(at) < 9
			if not near_path and piste_clear(at, 8):
				var instance := _baked(asset_root, furniture_mesh, terrain.world(at, 0.35))
				instance.rotation.y = -index * TAU / 3
				piste_furniture.append(instance)

func piste_clear(point: Vector2, radius: float = 0) -> bool:
	for piste in model.pistes:
		for i in range(1, piste.points.size()):
			var at := Geometry2D.get_closest_point_to_segment(point, Terrain.unpack(piste.points[i - 1]), Terrain.unpack(piste.points[i]))
			if point.distance_to(at) < Snow.piste_width(piste) * 0.5 + radius: return false
	return true

func _build_lift(lift: Dictionary) -> void:
	var bottom := Terrain.unpack(lift.bottom)
	var top := Terrain.unpack(lift.top)
	var orientation := Fleet.basis(lift)
	var angle := orientation.get_euler().y
	var r := Fleet.rope_offset(lift)
	if Fleet.family(lift) == "carpet":
		_ribbon(asset_root, [lift.bottom, lift.top], 4, Color("3f626b"), 0.7)
		for endpoint in [lift.bottom, lift.top]:
			_baked(asset_root, Art.new().chalet("shelter", 1, Color("769aa3")), terrain.world(Terrain.unpack(endpoint)))
	else:
		if Fleet.family(lift) == "drag":
			var track_a := bottom - Vector2(orientation.x.x, orientation.x.z) * r
			var track_b := top - Vector2(orientation.x.x, orientation.x.z) * r
			_ribbon(asset_root, [Terrain.pack(track_a), Terrain.pack(track_b)], 3.2, Color("e4edf0"), 0.22)
		var station_mesh := _lift_art(lift, "station")
		for point in [bottom, top]:
			var instance := _baked(asset_root, station_mesh, terrain.world(point))
			instance.rotation.y = angle
			_occluders.append(instance)
		var profile: Dictionary = model.cable_profile(lift)
		var steel := Art.new()
		for i in range(1, profile.points.size() - 1):
			var head: Vector3 = profile.points[i]
			var ground := Vector2(head.x, head.z)
			steel.link(terrain.world(ground), head, 0.3 if Fleet.family(lift) == "drag" else 0.65, Color("536c72"))
			steel.box(head, Vector3(r * 2 + 2, 0.6, 1.5), Color("455d64"), Vector3(0, angle, 0))
			for side in [-1, 1]:
				var wheel: Vector3 = head + orientation.x * (r * side)
				steel.box(wheel, Vector3(0.7, 0.7, 2.0), Color("a5b6b9"), Vector3(0, angle, 0))
		for i in range(1, profile.points.size()):
			for side in [-1, 1]:
				steel.link(profile.points[i - 1] + orientation.x * (r * side), profile.points[i] + orientation.x * (r * side), 0.09, Color("3c5159"))
		_baked(asset_root, steel.finish(), Vector3.ZERO)
		var vehicle_mesh := _lift_art(lift, "chair")
		vehicle_mesh.surface_set_material(0, _solid)
		var group := MultiMeshInstance3D.new()
		var count: int = model.fleet_layout(lift).count
		group.multimesh = _multimesh(vehicle_mesh, count)
		group.multimesh.visible_instance_count = count
		asset_root.add_child(group)
		var data := {"node": group, "glass": null, "poses": [], "clock": -INF}
		if not _vehicles.has(lift.kind):
			_vehicles[lift.kind] = group
		if Fleet.family(lift) == "gondola":
			var glass := MultiMeshInstance3D.new()
			glass.multimesh = _multimesh(Art.new().gondola_glass(), count)
			glass.multimesh.visible_instance_count = count
			var material := _material(Color(0.88, 0.96, 1.0, 0.08), true)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			glass.material_override = material
			glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			asset_root.add_child(glass)
			data.glass = glass
			if not _vehicle_glass.has(lift.kind):
				_vehicle_glass[lift.kind] = glass
		for carrier in range(count):
			chairs.append({"kind": lift.kind, "index": carrier, "carrier": carrier, "angle": angle, "id": lift.id})
			var pose: Dictionary = model.carrier_pose(lift, carrier)
			data.poses.append(pose)
			group.multimesh.set_instance_transform(carrier, pose.transform)
			group.multimesh.set_instance_color(carrier, Color.WHITE)
			if data.glass != null:
				data.glass.multimesh.set_instance_color(carrier, Color.WHITE)
		_vehicle_sets[lift.id] = data
	var queue_sign := Label3D.new()
	queue_sign.position = terrain.world(Foot.station_hub(lift, false, model.buildings), 6)
	queue_sign.font_size = 36
	queue_sign.pixel_size = 0.045
	queue_sign.outline_size = 9
	queue_sign.outline_modulate = Color("193843")
	queue_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	queue_sign.visibility_range_end = 1100
	asset_root.add_child(queue_sign)
	_queue_labels[lift.id] = queue_sign
	# Queue positions remain simulated; the four floating parallel rope rails
	# are intentionally omitted from the station artwork.

func _build_building(building: Dictionary) -> void:
	var point := Terrain.unpack(building.point)
	var instance := _baked(asset_root, Art.new().chalet(building.kind, int(building.get("level", 1)), Color(building.get("color", "") if building.get("color", "") != "" else Catalog.BUILDINGS[building.kind].color)), terrain.world(point))
	instance.rotation.y = int(building.get("rotation", 0)) * PI * 0.5
	_occluders.append(instance)
	if building.kind == "snowmaker":
		return
	var entrance := Foot.door(building)
	var hub := Foot.forecourt(building)
	_ribbon(asset_root, [Terrain.pack(entrance), Terrain.pack(hub)], 4.5, Color("bbc7c6"), 0.4)

func _ribbon(parent: Node3D, points: Array, width: float, color: Color, offset: float) -> void:
	if points.size() < 2:
		return
	var samples := PisteMesh.samples(terrain, points, width, 10 if parent == preview_root else 6)
	if samples.is_empty():
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	for sample in samples:
		surface.add_vertex(surface_position(sample.point) + Vector3.UP * 0.08 if parent == preview_root else terrain.world(sample.point, offset))
	surface.index()
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	var material := _material(color)
	if parent == preview_root:
		material.albedo_color.a = 0.48
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	if parent == asset_root or parent == landscape:
		instance.set_meta("walk_surface", true)
		surface_picker.add_mesh("floor_%d" % instance.get_instance_id(), instance.mesh)

func preview(points: Array, color: Color, building_kind: String = "", analysis: Dictionary = {}) -> void:
	for child in preview_root.get_children():
		preview_root.remove_child(child)
		child.queue_free()
	if points.is_empty():
		return
	_ribbon(preview_root,analysis.get("points",points) if analysis.get("walkway",false) else points,analysis.get("width",20) if analysis.has("segments") or analysis.get("walkway",false) else 7,color,1.55)
	if analysis.has("radius"):
		var center := Terrain.unpack(points[-1])
		var radius: float = analysis.radius
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings := ceili(radius / 4)
		for ring in range(rings):
			var inner := radius * ring / rings
			var outer := radius * (ring + 1) / rings
			for index in range(64):
				var a := Vector2.from_angle(index * TAU / 64)
				var b := Vector2.from_angle((index + 1) * TAU / 64)
				var vertices := [center+a*inner,center+b*inner,center+a*outer,center+b*outer]
				for triangle in [[0,2,1],[1,2,3]]:
					if ring == 0 and triangle[0] == 0:
						continue
					for vertex in triangle:
						surface.add_vertex(terrain.world(vertices[vertex],0.85))
		surface.generate_normals()
		_mesh(preview_root, surface.commit(), Vector3.ZERO, color)
	if analysis.has("segments"):
		for i in range(1, points.size()):
			var a := Terrain.unpack(points[i - 1])
			var b := Terrain.unpack(points[i])
			var direction := (b - a).normalized()
			var middle := a.lerp(b, 0.5)
			var forward := (surface_position(middle + direction * 2) - surface_position(middle - direction * 2)).normalized()
			var arrow := _baked(preview_root, Art.new().downhill_arrow(), surface_position(middle) + Vector3.UP * 0.18)
			arrow.basis = Basis.looking_at(forward, Vector3.UP)
	if building_kind != "":
		if not analysis.get("connection", {}).is_empty():
			_ribbon(preview_root, analysis.connection.points, 6, Color("75cdc7"), 0.6)
		var livery: String = analysis.get("color", "")
		var ghost := _baked(preview_root, Art.new().chalet(building_kind, 1, Color(livery) if livery != "" else color), terrain.world(Terrain.unpack(points.back())))
		ghost.rotation.y = int(analysis.get("rotation", 0)) * PI * 0.5

func _update_atmosphere() -> void:
	var key := "%d-%d-%d" % [model.day, model.minute, model.weather_index]
	if key == _atmosphere_tick:
		return
	_atmosphere_tick = key
	var daylight := sin(clampf(float(model.minute - 420) / 720.0, 0.05, 0.95) * PI)
	_sun.light_energy = (0.35 + daylight * 0.17) * (0.65 if model.weather_index in [2, 3] else 1.0)
	_sun.light_color = Color("f5d7cc").lerp(Color("fff1dc"), daylight)
	_sun.rotation_degrees.x = -25 - daylight * 32
	_environment.fog_density = 0.00065 if model.weather_index == 2 else (0.0004 if model.weather_index == 3 else 0.00008)
	_snow.emitting = effects_enabled and model.weather_index in [1, 3]
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
	var tows := 0
	for lift in model.lifts:
		if not _vehicle_sets.has(lift.id):
			continue
		var data: Dictionary = _vehicle_sets[lift.id]
		var near := Geometry2D.get_closest_point_to_segment(focus, Terrain.unpack(lift.bottom), Terrain.unpack(lift.top))
		var shown := near.distance_to(focus) < maxf(zoom * 1.8, 260)
		data.node.visible = shown
		if data.glass != null:
			data.glass.visible = shown
		if not shown:
			continue
		var clock: float = lift.get("clock", 0.0) + (simulation_fraction if model.lift_running(lift) else 0.0)
		var changed: bool = not is_equal_approx(data.clock, clock)
		for carrier in range(data.poses.size()):
			if changed:
				data.poses[carrier] = model.carrier_pose(lift, carrier, simulation_fraction)
				data.node.multimesh.set_instance_transform(carrier, data.poses[carrier].transform)
				if data.glass != null:
					data.glass.multimesh.set_instance_transform(carrier, data.poses[carrier].transform)
			if Fleet.family(lift) == "drag":
				var pose: Dictionary = data.poses[carrier]
				var from: Vector3 = pose.transform.origin + Vector3.UP * 0.55
				var to: Vector3 = pose.grip
				var line_basis := Basis(Quaternion(Vector3.UP, (to - from).normalized())).scaled(Vector3(1, from.distance_to(to), 1))
				_tow_lines.multimesh.set_instance_transform(tows, Transform3D(line_basis, (from + to) * 0.5))
				_tow_lines.multimesh.set_instance_color(tows, Color.WHITE)
				tows += 1
		data.clock = clock
	_tow_lines.multimesh.visible_instance_count = tows
	if _label_tick != model.minute or delta == 0:
		_label_tick = model.minute
		for lift in model.lifts:
			if _queue_labels.has(lift.id):
				var load: Dictionary = model.lift_load(lift)
				_queue_labels[lift.id].text = L.text("%d warten · %.0f %% belegt") % L.args([load.queue, load.fill * 100])
				_queue_labels[lift.id].modulate = Color("edb77c") if load.queue > load.seats * 4 else Color("d8ece2")
	forest.update(focus, zoom, quality_tier)
	_adapt_quality(delta)
	var next_positions: Dictionary = {}
	var walking := 0
	var riding := 0
	var cabin_riding := 0
	var foot_visitors := 0
	var climbers := 0
	var equipment_counts: Dictionary = {}
	for key in _equipment: equipment_counts[key] = 0
	for guest in model.guests:
		if guest.phase == "leaving":
			continue
		var position_value := Vector3.ZERO
		var angle := 0.0
		var lean := 0.0
		var pitch := 0.0
		var seated := false
		var in_cabin := false
		var hiking := false
		var on_foot: bool = guest.phase == "queue"
		if guest.phase != "leaving" and guest.leg < guest.route.legs.size():
			var leg: Dictionary = guest.route.legs[guest.leg]
			var fraction: float = clampf((guest.elapsed + simulation_fraction) / guest.get("duration", leg.minutes), 0, 1)
			if leg.kind == "ski":
				var piste: Dictionary = model.asset(leg.id)
				var personal := _ski_pose(piste, guest, leg)
				position_value = personal.position
				angle = personal.yaw
				lean = personal.lean
				pitch = personal.pitch
				hiking = Motion.hiking(guest.get("ski_motion",leg.get("motion",[])),fraction)
			elif leg.kind == "lift" and guest.phase == "moving":
				var pose: Dictionary = _rider_pose(guest)
				position_value = pose.transform.origin
				angle = pose.transform.basis.get_euler().y
				seated = pose.seated
				in_cabin = Fleet.family(model.asset(leg.id)) == "gondola"
			elif leg.kind == "visit":
				position_value = model.guest_position(guest, simulation_fraction)
				if follow_guest == int(guest.id):
					focus = Vector2(position_value.x, position_value.z)
					_follow_position = position_value
					_update_camera()
				continue
			else:
				on_foot = true
				position_value = model.guest_position(guest, simulation_fraction)
				var a := Terrain.unpack(leg.points[0])
				var b := Terrain.unpack(leg.points.back())
				angle = atan2(b.x - a.x, b.y - a.y)
		if guest.phase == "queue":
			position_value = model.guest_position(guest, simulation_fraction)
			angle = Fleet.basis(model.asset(guest.route.legs[guest.leg].id)).get_euler().y
			if _guest_positions.has(guest.id) and delta > 0:
				position_value = _queue_step(guest.id, _guest_positions[guest.id], position_value, delta * 1.6 * motion_rate if motion_running else 0)
		var color := Color(Motion.COLORS[int(guest.id) % Motion.COLORS.size()])
		var transform_value := Transform3D(Basis.from_euler(Vector3(pitch, angle, lean)), position_value)
		var sport: String = guest.get("sport", "ski")
		var equipment_pose := "seated" if seated else ("hike" if hiking else ("walk" if on_foot else "glide"))
		if not in_cabin:
			var equipment_key := sport + "/" + equipment_pose
			var gear: MultiMesh = _equipment[equipment_key].multimesh
			gear.set_instance_transform(equipment_counts[equipment_key], transform_value)
			gear.set_instance_color(equipment_counts[equipment_key], color)
			equipment_counts[equipment_key] += 1
		if sport == "snowboard" and not on_foot and not hiking and not seated and not in_cabin:
			transform_value.basis = transform_value.basis * Basis(Vector3.UP, PI * 0.5)
		if in_cabin:
			_cabin_riders.multimesh.set_instance_transform(cabin_riding, transform_value)
			_cabin_riders.multimesh.set_instance_color(cabin_riding,Color.WHITE)
			_cabin_riders.multimesh.set_instance_custom_data(cabin_riding,color)
			cabin_riding += 1
		elif seated:
			_riders.multimesh.set_instance_transform(riding, transform_value)
			_riders.multimesh.set_instance_color(riding,Color.WHITE)
			_riders.multimesh.set_instance_custom_data(riding,color)
			riding += 1
		elif hiking:
			transform_value.basis = transform_value.basis.rotated(Vector3.FORWARD,sin((guest.elapsed+simulation_fraction)*8)*0.035)
			_climbers.multimesh.set_instance_transform(climbers,transform_value)
			_climbers.multimesh.set_instance_color(climbers,Color.WHITE)
			_climbers.multimesh.set_instance_custom_data(climbers,color)
			climbers += 1
		elif on_foot:
			_walkers.multimesh.set_instance_transform(foot_visitors, transform_value)
			_walkers.multimesh.set_instance_color(foot_visitors,Color.WHITE)
			_walkers.multimesh.set_instance_custom_data(foot_visitors,color)
			foot_visitors += 1
		else:
			visitor_mesh.multimesh.set_instance_transform(walking, transform_value)
			visitor_mesh.multimesh.set_instance_color(walking,Color.WHITE)
			visitor_mesh.multimesh.set_instance_custom_data(walking,color)
			walking += 1
		next_positions[guest.id] = position_value
		if follow_guest == int(guest.id):
			_follow_position = _follow_position.lerp(position_value, minf(1, delta * 7)) if camera_smoothing and delta > 0 and _follow_position.is_finite() else position_value
			focus = Vector2(_follow_position.x, _follow_position.z)
			_update_camera()
	_guest_positions = next_positions
	_selection.visible = next_positions.has(selected_guest)
	if _selection.visible:
		_selection.position = next_positions[selected_guest] + Vector3.UP * 0.2
	for id in _motion_cache.keys():
		if not next_positions.has(id):
			_motion_cache.erase(id)
	for id in _queue_paths.keys():
		if not next_positions.has(id):
			_queue_paths.erase(id)
	_update_occlusion(delta)
	visitor_mesh.multimesh.visible_instance_count = walking
	_riders.multimesh.visible_instance_count = riding
	_cabin_riders.multimesh.visible_instance_count = cabin_riding
	_walkers.multimesh.visible_instance_count = foot_visitors
	_climbers.multimesh.visible_instance_count = climbers
	for key in _equipment:
		_equipment[key].multimesh.visible_instance_count = equipment_counts[key]
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
	if _track_timer > (0.1 if _tracks_pending else 0.5) and (_tracks_pending or model.snow_revision != _track_seen or focus.distance_to(_track_focus) > 100 or (motion_running and zoom < 220)):
		_track_timer = 0
		_track_seen = model.snow_revision
		_track_focus = focus
		_draw_tracks(false)

func _queue_step(id: int, current: Vector3, target: Vector3, distance: float) -> Vector3:
	if not _queue_paths.has(id) or _queue_paths[id].target.distance_to(target) > 0.1:
		var path := Foot.path_between(Vector2(current.x, current.z), Vector2(target.x, target.z), model.buildings, model.lifts, _pedestrian_snapshot.get("obstacles", []))
		_queue_paths[id] = {"target": target, "points": path, "next": 1}
	var state: Dictionary = _queue_paths[id]
	while distance > 0 and state.next < state.points.size():
		var at := terrain.world(Terrain.unpack(state.points[state.next]), 0.3)
		var step := minf(distance, current.distance_to(at))
		current = current.move_toward(at, step)
		distance -= step
		if current.distance_to(at) < 0.01:
			state.next += 1
		else:
			break
	return current

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
	var best := 27.0
	var id := -1
	for guest in model.guests:
		if guest.phase == "leaving" or not _guest_positions.has(guest.id):
			continue
		var position_value: Vector3 = _guest_positions[guest.id]
		if camera.is_position_behind(position_value):
			continue
		var distance: float = camera.unproject_position(position_value).distance_to(point)
		if distance < best:
			best = distance
			id = guest.id
	return id

func _draw_snow(piste: Dictionary) -> void:
	var data := snow_renderer.update(piste)
	if _piste_meshes[piste.id].mesh == null:
		_piste_meshes[piste.id].mesh = snow_renderer.build(terrain, piste)
	surface_picker.add_mesh("piste_%d" % piste.id, _piste_meshes[piste.id].mesh, piste, snow_renderer.pick_frames[piste.id])
	_piste_meshes[piste.id].material_override = data.material

func _track_point(piste: Dictionary, id: int, ability: int, fraction: float, run: int, side_offset: float, range_start: float = 0, range_end: float = 1) -> Vector3:
	var frame := Motion.frame(terrain, piste, id, ability, fraction, run, range_start, range_end)
	var side: Vector2 = frame.direction.orthogonal()
	var point: Vector2 = frame.point + side * side_offset
	var center: Vector2 = terrain.point_on_path(piste.points, fraction)
	var road_side: Vector2 = (terrain.point_on_path(piste.points, minf(1, fraction + 0.005)) - terrain.point_on_path(piste.points, maxf(0, fraction - 0.005))).normalized().orthogonal()
	return terrain.world(point, Snow.mesh_height(piste, fraction, (point - center).dot(road_side)) + 0.05)

func _trace_quad(surface: SurfaceTool, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var side := Vector3(b.z - a.z, 0, a.x - b.x).normalized() * width
	for point in [a + side, b + side, a - side, a - side, b + side, b - side]:
		surface.set_color(color)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(point)

func _trace_sample(piste: Dictionary, track: Dictionary, index: int, blocking: bool, used: Dictionary) -> Dictionary:
	var key := "%d/%s/%d" % [piste.id, track.key, index]
	used[key] = true
	if _trace_cache.has(key):
		return _trace_cache[key]
	if not blocking and trace_samples >= 48:
		_tracks_pending = true
		return {}
	trace_samples += 1
	var start: float = track.get("from", 0.0)
	var fraction := minf(track.get("until", 1.0), start + index * 2.0 / piste.length)
	var frame := Motion.frame(terrain, piste, track.guest, track.ability, fraction, track.run,start,track.get("until",1.0),track.get("hikes",[]),track.get("sport","ski"))
	var center: Vector2 = terrain.point_on_path(piste.points, fraction)
	var road_side := (terrain.point_on_path(piste.points, minf(1, fraction + 0.005)) - terrain.point_on_path(piste.points, maxf(0, fraction - 0.005))).normalized().orthogonal()
	var hiking := Motion.in_walk_range(track.get("hikes",[]),fraction)
	var sport: String = track.get("sport", "ski")
	var data := {"points":[],"uvs":[],"hiking":hiking,"sport":sport}
	var offsets: Array = [0.0] if sport == "snowboard" and not hiking else ([-0.22,0.22] if sport == "snowblade" else [-0.28,0.28])
	for offset in offsets:
		var point: Vector2 = frame.point + frame.direction.orthogonal() * offset
		data.points.append(terrain.world(point, Snow.base_height(piste, fraction) + 0.05))
		data.uvs.append(snow_renderer.uv(piste, fraction, (point - center).dot(road_side)))
	_trace_cache[key] = data
	return data

func _draw_tracks(blocking: bool = true) -> void:
	trace_samples = 0
	_tracks_pending = false
	var live: Dictionary = {}
	var followed := ""
	var followed_piste := -1
	var record: Dictionary = {}
	for guest in model.guests:
		if guest.phase != "moving" or guest.leg >= guest.route.legs.size() or guest.route.legs[guest.leg].kind != "ski":
			continue
		var leg: Dictionary = guest.route.legs[guest.leg]
		var key: String = guest.get("track", "")
		live[key] = model.ski_fraction(leg,(guest.elapsed+simulation_fraction)/guest.duration,guest.get("ski_motion",[]))
		if int(guest.id) == follow_guest:
			followed = key
			followed_piste = leg.id
			record = {"key": key, "guest": int(guest.id), "ability": int(guest.ability), "sport":guest.get("sport","ski"), "run": int(guest.loops), "hikes":guest.get("walk_ranges",[]),"from":leg.get("start_fraction",0.0),"until": leg.get("end_fraction", 1.0), "to": live[key]}
	var visible: Array = []
	for piste in model.pistes:
		if terrain.point_on_path(piste.points, 0.5).distance_to(focus) < maxf(zoom * 2 + piste.length * 0.5, 600):
			visible.append(piste)
	visible.sort_custom(func(a, b):
		if int(a.id) == int(b.id): return false
		if int(a.id) == followed_piste: return true
		if int(b.id) == followed_piste: return false
		return terrain.point_on_path(a.points, 0.5).distance_to(focus) < terrain.point_on_path(b.points, 0.5).distance_to(focus)
	)
	var mesh := ArrayMesh.new()
	var segments := 0
	var used: Dictionary = {}
	var quota := maxi(128, trace_budget / maxi(visible.size(), 1))
	for piste in visible:
		var tracks: Array = piste.get("tracks", [])
		var ordered: Array = []
		if piste.id == followed_piste and not record.is_empty():
			ordered.append(record)
		for active in [true, false]:
			for i in range(tracks.size() - 1, -1, -1):
				if tracks[i].key != followed and live.has(tracks[i].key) == active and ordered.size() < 24:
					ordered.append(tracks[i])
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var local := 0
		for track in ordered:
			var end: float = maxf(track.to, live.get(track.key, 0.0))
			var count := ceili((end - track.get("from", 0.0)) * piste.length / 2)
			var available := mini(quota - local, trace_budget - segments)
			# Show the most recent part of each run first, around its skier.
			for index in range(maxi(0, count - available), count):
				if local >= quota or segments >= trace_budget: break
				var a := _trace_sample(piste, track, index, blocking, used)
				var b := _trace_sample(piste, track, index + 1, blocking, used)
				if a.is_empty() or b.is_empty(): break
				for ski in range(mini(a.points.size(), b.points.size())):
					for bright in [false, true]:
						surface.set_uv(a.uvs[ski])
						var pa: Vector3 = a.points[ski]
						var pb: Vector3 = b.points[ski]
						if a.get("hiking",false) or b.get("hiking",false):
							var step := pb-pa
							pa = pa.lerp(pb,0.2 if ski == index%2 else 0.65)
							pb = pa+step.normalized()*0.45
						if bright:
							pa += Vector3(0.1, 0.035, 0.1); pb += Vector3(0.1, 0.035, 0.1)
						var width := 0.32 if a.sport == "snowboard" and not a.hiking else 0.10
						_trace_quad(surface, pa, pb, 0.04 if bright else width, Color("edf5f9") if bright else Color("91adbf"))
				segments += 1
				local += 1
		if local > 0:
			surface.set_material(snow_renderer.update(piste).trace)
			surface.commit(mesh)
	if segments > 0:
		_track_mesh.mesh = mesh
		_track_mesh.material_override = null
	elif not _tracks_pending:
		_track_mesh.mesh = null
	_track_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not _tracks_pending or _trace_cache.size() > 6000:
		for key in _trace_cache.keys():
			if not used.has(key): _trace_cache.erase(key)

func set_camera_mode(value: int) -> void:
	camera_mode = clampi(value, 0, CAMERA_MODES.size() - 1)
	pitch_degrees = CAMERA_PITCHES[camera_mode]
	_update_camera()

func recover_after_resume() -> void:
	camera.make_current()
	_update_camera()
	_motion_cache.clear()
	_label_tick = -1
	_atmosphere_tick = ""
	_snow_seen = -1
	_track_seen = -1
	for data in _vehicle_sets.values(): data.clock = -1.0
	_process(0)

func set_camera_pitch(value: float) -> void:
	pitch_degrees = clampf(value, 20, 80)
	if camera_mode == 3:
		camera_mode = 2
	_update_camera()

func _update_camera() -> void:
	camera.size = zoom
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if camera_mode == 3 else Camera3D.PROJECTION_PERSPECTIVE
	var target := terrain.world(focus, clampf(zoom * 0.06, 3, 38))
	if follow_guest != -1 and _follow_position.is_finite():
		target = _follow_position + Vector3.UP
	if camera_mode == 3:
		camera.position = target + Vector3.UP * maxf(zoom * 1.6, 1500)
		camera.look_at(target, Vector3(-sin(yaw), 0, -cos(yaw)))
	else:
		# Keep the apparent scale similar while changing the viewing angle.
		var distance := zoom * 1.22
		var pitch := deg_to_rad(pitch_degrees)
		camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
		camera.look_at(target)

func pan_between(previous: Vector2, current: Vector2) -> void:
	follow_guest = -1
	var from := map_point(previous)
	var to := map_point(current)
	if from.is_finite() and to.is_finite():
		focus += from - to
	focus.x = clampf(focus.x, terrain.bounds.position.x + 20, terrain.bounds.end.x - 20)
	focus.y = clampf(focus.y, terrain.bounds.position.y + 20, terrain.bounds.end.y - 20)
	_update_camera()

func transform_gesture(previous: Vector2, current: Vector2, old_span: Vector2, new_span: Vector2) -> void:
	follow_guest = -1
	var anchor := map_point(previous)
	if old_span.length() > 24 and new_span.length() > 24:
		yaw = wrapf(yaw - old_span.angle_to(new_span), -PI, PI)
		zoom = clampf(zoom * old_span.length() / new_span.length(), 48, maxf(terrain.bounds.size.x, terrain.bounds.size.y) * 1.25)
	_update_camera()
	# Focus changes its terrain elevation on a mountain. Reproject a few times
	# so a combined twist/pinch does not slide off the touched slope.
	for iteration in range(4):
		var after := map_point(current)
		if not anchor.is_finite() or not after.is_finite() or anchor.distance_to(after) < 0.02: break
		focus += anchor - after
		focus = focus.clamp(terrain.bounds.position + Vector2(20, 20), terrain.bounds.end - Vector2(20, 20))
		_update_camera()

func pan(relative: Vector2) -> void:
	var center := get_viewport().get_visible_rect().size * 0.5
	pan_between(center, center + relative)

func zoom_at(factor: float, screen_point: Vector2) -> void:
	var before := map_point(screen_point)
	change_zoom(factor)
	var after := map_point(screen_point)
	if before.is_finite() and after.is_finite():
		focus += before - after
		focus = focus.clamp(terrain.bounds.position + Vector2(20, 20), terrain.bounds.end - Vector2(20, 20))
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

func surface_position(point: Vector2) -> Vector3:
	var at := surface_picker.position(point)
	return at if at.is_finite() else terrain.world(point)

func map_point(screen_point: Vector2) -> Vector2:
	if not get_viewport().get_visible_rect().has_point(screen_point): return Vector2.INF
	var hit := surface_picker.intersect(camera.project_ray_origin(screen_point), camera.project_ray_normal(screen_point))
	if hit.is_empty(): return Vector2.INF
	return Vector2(hit.position.x, hit.position.z)

func pick_asset(point: Vector2) -> int:
	var closest := 24.0
	var id := -1
	for building in model.buildings + model.walk_areas:
		var distance := point.distance_to(Terrain.unpack(building.point))
		if building.get("kind", "") == "walkway":
			for i in range(1,building.points.size()):
				distance = minf(distance,Geometry2D.get_closest_point_to_segment(point,Terrain.unpack(building.points[i-1]),Terrain.unpack(building.points[i])).distance_to(point))
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

func _exact_ski_pose(piste: Dictionary, guest: Dictionary, leg: Dictionary, elapsed: float) -> Dictionary:
	var fraction: float = model.ski_fraction(leg,clampf(elapsed/guest.duration,0,1),guest.get("ski_motion",[]))
	var frame := Motion.frame(terrain, piste, guest.id, guest.ability, fraction, guest.loops,leg.get("start_fraction",0),leg.get("end_fraction",1),guest.get("walk_ranges",[]),guest.get("sport","ski"))
	if Motion.hiking(guest.get("ski_motion",leg.get("motion",[])),elapsed/guest.duration): frame.lean = 0.0
	var center: Vector2 = terrain.point_on_path(piste.points, fraction)
	var side: Vector2 = (terrain.point_on_path(piste.points, minf(1, fraction + 0.005)) - terrain.point_on_path(piste.points, maxf(0, fraction - 0.005))).normalized().orthogonal()
	var before: Vector3 = terrain.world(frame.before)
	var ahead: Vector3 = terrain.world(frame.ahead)
	return {"position": terrain.world(frame.point, Snow.mesh_height(piste, fraction, (frame.point - center).dot(side)) - 0.05), "yaw": frame.yaw, "lean": frame.lean, "pitch": atan2(before.y - ahead.y, Vector2(ahead.x - before.x, ahead.z - before.z).length())}

func _ski_pose(piste: Dictionary, guest: Dictionary, leg: Dictionary) -> Dictionary:
	var elapsed: float = guest.elapsed + simulation_fraction
	if follow_guest == int(guest.id):
			return _exact_ski_pose(piste, guest, leg, elapsed)
	# Stagger expensive terrain/path samples. Every display frame still interpolates.
	const QUANTUM := 0.12
	var offset := float(int(guest.id) % 17) * QUANTUM / 17
	var index := floori((elapsed + offset) / QUANTUM)
	var key := "%d:%d:%d:%d" % [piste.id, guest.leg, guest.loops, index]
	if not _motion_cache.has(guest.id) or _motion_cache[guest.id].key != key:
		var at := index * QUANTUM - offset
		var previous_key := "%d:%d:%d:%d" % [piste.id, guest.leg, guest.loops, index - 1]
		var first: Dictionary = _motion_cache[guest.id].b if _motion_cache.has(guest.id) and _motion_cache[guest.id].key == previous_key else _exact_ski_pose(piste, guest, leg, at)
		_motion_cache[guest.id] = {"key": key, "a": first, "b": _exact_ski_pose(piste, guest, leg, at + QUANTUM)}
	var data: Dictionary = _motion_cache[guest.id]
	var weight := fposmod(elapsed + offset, QUANTUM) / QUANTUM
	return {"position": data.a.position.lerp(data.b.position, weight), "yaw": lerp_angle(data.a.yaw, data.b.yaw, weight), "lean": lerpf(data.a.lean, data.b.lean, weight), "pitch": lerp_angle(data.a.pitch, data.b.pitch, weight)}

func _rider_pose(guest: Dictionary) -> Dictionary:
	var lift: Dictionary = model.asset(guest.route.legs[guest.leg].id)
	var data: Dictionary = _vehicle_sets.get(lift.id, {})
	if data.is_empty() or not data.node.visible:
		return model.rider_pose(guest, simulation_fraction)
	var pose: Dictionary = data.poses[int(guest.get("ride_car", 0))]
	var transform_value: Transform3D = pose.transform
	if Fleet.family(lift) in ["drag", "carpet"]:
		transform_value.origin = terrain.world(Vector2(transform_value.origin.x, transform_value.origin.z), 0.15 if Fleet.family(lift) == "drag" else 0.65)
	else:
		var seat: int = guest.get("ride_seat", 0)
		transform_value.origin += transform_value.basis * Fleet.seat_offset(lift, seat)
		if Fleet.family(lift) == "gondola" and seat >= 4:
			transform_value.basis = transform_value.basis.rotated(Vector3.UP, PI)
	return {"transform": transform_value, "seated": Fleet.family(lift) in ["chair", "gondola"]}

func set_quality(mode: String) -> void:
	quality = mode if mode in ["auto", "economy", "balanced", "high"] else "auto"
	quality_tier = {"auto": 1, "economy": 0, "balanced": 1, "high": 2}[quality]
	trace_budget = [700, 1200, 2000][quality_tier]
	get_viewport().scaling_3d_scale = [0.65, 0.85, 1.0][quality_tier]
	_sun.shadow_enabled = quality_tier > 0
	forest.update(focus, zoom, quality_tier)

func _adapt_quality(delta: float) -> void:
	if quality != "auto" or delta <= 0:
		return
	_frame_average = lerpf(_frame_average, minf(delta, 0.1), 0.04)
	_quality_timer += delta
	if _quality_timer < 1.5:
		return
	_quality_timer = 0
	var viewport := get_viewport()
	if _frame_average > frame_target * 1.4:
		viewport.scaling_3d_scale = maxf(0.6, viewport.scaling_3d_scale - 0.07)
		quality_tier = 0 if viewport.scaling_3d_scale < 0.7 else 1
	elif _frame_average < frame_target * 1.05:
		viewport.scaling_3d_scale = minf(0.92, viewport.scaling_3d_scale + 0.02)
		quality_tier = 1
	_sun.shadow_enabled = quality_tier > 0

func _lift_art(lift: Dictionary, type: String) -> ArrayMesh:
	var key := "%s/%s/%d/%s" % [type, lift.kind, lift.get("level", 1), lift.get("color", "")]
	if not _art_cache.has(key):
		if _art_cache.size() > 128: _art_cache.clear()
		_art_cache[key] = Art.new().station(lift.kind, int(lift.get("level", 1)), lift.get("color", "")) if type == "station" else Art.new().chair(lift.kind, lift.get("color", ""))
	return _art_cache[key]
