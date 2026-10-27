extends Node3D
## Original, batched alpine scenery and a simulation-driven atmosphere.

const Terrain = preload("res://src/core/terrain.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Art = preload("res://src/world/alpine_art.gd")
const PISTE_COLORS := [Color("368bcb"), Color("ce5660"), Color("344859")]

var model: RefCounted
var camera := Camera3D.new()
var focus := Vector2(15, -30)
var yaw := 0.46
var zoom := 620.0
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
	_solid = _material(Color.WHITE, true)
	_build_environment()
	_build_terrain()
	_build_surroundings()
	for node in [trees, rocks, asset_root, preview_root, visitor_mesh]:
		add_child(node)
	visitor_mesh.multimesh = _multimesh(Art.new().skier(), model.MAX_GUESTS)
	visitor_mesh.multimesh.mesh.surface_set_material(0, _solid)
	visitor_mesh.multimesh.visible_instance_count = 0
	visitor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 42
	camera.near = 3.0
	camera.far = 7000
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

func _ground_color(point: Vector2, height_value: float) -> Color:
	var grade := Terrain.slope_percent(point)
	var snow := Color("d6e5f0").lerp(Color("e7eff5"), clampf(height_value / 420.0, 0, 1))
	if grade > 42:
		snow = snow.lerp(Color("7c8993"), clampf((grade - 42) / 80.0, 0, 0.67))
	return snow.darkened(0.018 + sin(point.x * 0.047 + point.y * 0.027) * 0.018)

func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-400, 340, 10):
		for x in range(-360, 360, 10):
			var corners := [Vector2(x, z), Vector2(x, z + 10), Vector2(x + 10, z), Vector2(x + 10, z + 10)]
			for index in [0, 2, 1, 2, 3, 1]:
				var point: Vector2 = corners[index]
				surface.set_color(_ground_color(point, Terrain.height(point)))
				surface.add_vertex(Terrain.world(point))
	surface.index()
	surface.generate_normals()
	terrain_instance = MeshInstance3D.new()
	terrain_instance.mesh = surface.commit()
	terrain_instance.material_override = _solid
	add_child(terrain_instance)
	var lake := CylinderMesh.new()
	lake.top_radius = 53
	lake.bottom_radius = 53
	lake.height = 0.6
	lake.radial_segments = 48
	var lake_node := _mesh(self, lake, Vector3(-260, 7, 255), Color("85aab9"))
	lake_node.scale.z = 0.62
	_ribbon(self, [[185, 335], [185, 280], [185, 230]], 11.0, Color("b5b5a9"), 0.25)
	_label(self, "TALZUGANG", Terrain.world(Terrain.BASE + Vector2(0, 65), 8), Color("446774"))

func _scenery_height(point: Vector2) -> float:
	var x_distance := maxf(absf(point.x) - 360, 0)
	var z_distance := maxf(maxf(-400 - point.y, point.y - 340), 0)
	var weight := clampf(Vector2(x_distance, z_distance).length() / 160.0, 0, 1)
	var peaks := 0.0
	for peak in [Vector3(-740, -890, 300), Vector3(-280, -1080, 420), Vector3(280, -1000, 370), Vector3(810, -820, 310)]:
		peaks += peak.z * exp(-pow((point.x - peak.x) / 205.0, 2.0) - pow((point.y - peak.y) / 240.0, 2.0))
	return Terrain.height(point) + weight * peaks

func _build_surroundings() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-1500, 1000, 20):
		for x in range(-1300, 1300, 20):
			if x >= -360 and x < 360 and z >= -400 and z < 340:
				continue
			var corners := [Vector2(x, z), Vector2(x, z + 20), Vector2(x + 20, z), Vector2(x + 20, z + 20)]
			for index in [0, 2, 1, 2, 3, 1]:
				var point: Vector2 = corners[index]
				var h := _scenery_height(point)
				var grade := absf(_scenery_height(point + Vector2(8, 0)) - h) + absf(_scenery_height(point + Vector2(0, 8)) - h)
				var color := _ground_color(point, h)
				if grade > 9:
					color = color.lerp(Color("7c8c9b"), minf(0.7, (grade - 9) * 0.07))
				surface.set_color(color)
				surface.add_vertex(Vector3(point.x, h, point.y))
	surface.index()
	surface.generate_normals()
	scenery_instance = MeshInstance3D.new()
	scenery_instance.mesh = surface.commit()
	scenery_instance.material_override = _solid
	scenery_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(scenery_instance)

func toggle_slopes() -> void:
	slopes_visible = not slopes_visible
	if slope_overlay == null:
		_build_slope_overlay()
	slope_overlay.visible = slopes_visible

func _build_slope_overlay() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-400, 340, 10):
		for x in range(-360, 360, 10):
			var corners := [Vector2(x, z), Vector2(x, z + 10), Vector2(x + 10, z), Vector2(x + 10, z + 10)]
			for index in [0, 2, 1, 2, 3, 1]:
				var point: Vector2 = corners[index]
				var grade := Terrain.slope_percent(point)
				var color := Color("83bcaa") if grade < 8 else (Color("68a6d0") if grade <= 30 else (Color("d8777c") if grade <= 55 else Color("687381")))
				color.a = 0.68
				surface.set_color(color)
				surface.add_vertex(Terrain.world(point, 0.16))
	surface.generate_normals()
	slope_overlay = MeshInstance3D.new()
	slope_overlay.mesh = surface.commit()
	var material := _material(Color.WHITE, true)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slope_overlay.material_override = material
	slope_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(slope_overlay)

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
	var instances := _multimesh(pine, 1000)
	var rock_mesh := Art.new().rock()
	rock_mesh.surface_set_material(0, _solid)
	var stones := _multimesh(rock_mesh, 90)
	var random := RandomNumberGenerator.new()
	random.seed = 73628
	var used := 0
	var stone_count := 0
	for i in range(3200):
		var point := Vector2(random.randf_range(-350, 350), random.randf_range(-385, 325))
		if point.distance_to(Vector2(-260, 255)) < 62 or point.distance_to(Terrain.BASE) < 46 or not _clear_ground(point, 20):
			continue
		var grade := Terrain.slope_percent(point)
		if grade > 47 and stone_count < stones.instance_count:
			var size_value := random.randf_range(0.8, 2.0)
			stones.set_instance_transform(stone_count, Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * size_value), Terrain.world(point)))
			stones.set_instance_color(stone_count, Color.WHITE)
			stone_count += 1
			continue
		if grade > 65 or Terrain.height(point) > 215 or used >= instances.instance_count or absf(sin(point.x * 0.031) * cos(point.y * 0.023)) < 0.18:
			continue
		var size_value := random.randf_range(0.65, 1.15)
		instances.set_instance_transform(used, Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * size_value), Terrain.world(point)))
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
		_ribbon(asset_root, piste.points, width, color.lightened(0.18), 0.45)
		_ribbon(asset_root, piste.points, width - 3.5, Color("e4eef5"), 0.7)
		var markers := Art.new()
		for i in range(ceili(piste.length / 40)):
			var fraction: float = float(i) * 40 / piste.length
			var point := Terrain.point_on_path(piste.points, fraction)
			var ahead := Terrain.point_on_path(piste.points, minf(fraction + 0.01, 1.0))
			var side := (ahead - point).normalized().orthogonal() * width * 0.5
			for sign_value in [-1, 1]:
				var flag := Terrain.world(point + side * sign_value, 2.5)
				markers.box(flag, Vector3(0.35, 5, 0.35), Color("a0afb0"))
				markers.box(flag + Vector3(0, 1.3, 0), Vector3(2.3, 1.6, 0.3), color)
		_baked(asset_root, markers.finish(), Vector3.ZERO)
		_label(asset_root, ["BLAU", "ROT", "SCHWARZ"][piste.difficulty], Terrain.world(Terrain.unpack(piste.points[0]), 24), color)
	for lift in model.lifts:
		_build_lift(lift)
	for building in model.buildings:
		_build_building(building)
	_build_trees()
	_guest_tick = ""

func _build_lift(lift: Dictionary) -> void:
	var bottom := Terrain.unpack(lift.bottom)
	var top := Terrain.unpack(lift.top)
	var a := Terrain.world(bottom, 13)
	var b := Terrain.world(top, 13)
	var angle := atan2(top.x - bottom.x, top.y - bottom.y)
	var station_mesh := Art.new().station(lift.kind, int(lift.get("level", 1)))
	for point in [bottom, top]:
		var instance := _baked(asset_root, station_mesh, Terrain.world(point))
		instance.rotation.y = angle
	var supports := maxi(2, ceili(lift.length / 85.0))
	for i in range(1, supports):
		var t := float(i) / supports
		var point := bottom.lerp(top, t)
		var head := a.lerp(b, t)
		_link(asset_root, Terrain.world(point), head, 0.9, Color("536c72"))
		_box(asset_root, head, Vector3(11, 1.2, 2.5), Color("455d64"))
	for offset in [-3.0, 3.0]:
		_link(asset_root, a + Vector3(offset, 0, 0), b + Vector3(offset, 0, 0), 0.25, Color("3c5159"))
	if not _vehicles.has(lift.kind):
		var vehicle_mesh := Art.new().chair(lift.kind)
		vehicle_mesh.surface_set_material(0, _solid)
		var group := MultiMeshInstance3D.new()
		group.multimesh = _multimesh(vehicle_mesh, 24 * 12)
		group.multimesh.visible_instance_count = 0
		asset_root.add_child(group)
		_vehicles[lift.kind] = group
		_vehicle_counts[lift.kind] = 0
	for i in range(12):
		var index: int = _vehicle_counts[lift.kind]
		_vehicle_counts[lift.kind] += 1
		chairs.append({"kind": lift.kind, "index": index, "angle": angle, "a": a, "b": b, "offset": float(i) / 12, "id": lift.id})
		_vehicles[lift.kind].multimesh.set_instance_color(index, Color.WHITE)
		_vehicles[lift.kind].multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.UP, angle), a.lerp(b, float(i) / 12) + Vector3(-3, -4, 0)))
	_vehicles[lift.kind].multimesh.visible_instance_count = _vehicle_counts[lift.kind]

func _build_building(building: Dictionary) -> void:
	var point := Terrain.unpack(building.point)
	_baked(asset_root, Art.new().chalet(building.kind, int(building.get("level", 1)), Color(Catalog.BUILDINGS[building.kind].color)), Terrain.world(point))
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
				surface.add_vertex(Terrain.world(vertices[index], offset))
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	var material := _material(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

func preview(points: Array, color: Color, building_kind: String = "") -> void:
	for child in preview_root.get_children():
		preview_root.remove_child(child)
		child.queue_free()
	if points.is_empty():
		return
	_ribbon(preview_root, points, 7, color, 1.2)
	for point in points:
		var sphere := SphereMesh.new()
		sphere.radius = 3.5
		sphere.height = 7
		_mesh(preview_root, sphere, Terrain.world(Terrain.unpack(point), 4), color)
	if building_kind != "":
		_baked(preview_root, Art.new().chalet(building_kind, 1, color), Terrain.world(Terrain.unpack(points.back())))

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
	_snow.position = Terrain.world(focus, 130)

func _process(delta: float) -> void:
	if model == null:
		return
	if model.revision != _seen_revision:
		rebuild()
	_update_atmosphere()
	_snow.position = Terrain.world(focus, 130)
	if absf(_visual_minute - model.minute) > 60:
		_visual_minute = model.minute
	_visual_minute = lerpf(_visual_minute, model.minute, minf(1, delta * 5))
	for chair in chairs:
		var lift: Dictionary = model.asset(chair.id)
		if not model.lift_open(lift):
			continue
		var t := fposmod(_visual_minute / 7.0 + chair.offset, 1.0)
		var outbound := t < 0.5
		var position_value: Vector3 = chair.a.lerp(chair.b, t * 2 if outbound else (1 - t) * 2) + Vector3(-3 if outbound else 3, -4, 0)
		_vehicles[chair.kind].multimesh.set_instance_transform(chair.index, Transform3D(Basis(Vector3.UP, chair.angle), position_value))
	var tick := "%d-%d-%d" % [model.day, model.minute, model.revision]
	var update_targets := tick != _guest_tick
	_guest_tick = tick
	var live_ids: Dictionary = {}
	for i in range(model.guests.size()):
		var guest: Dictionary = model.guests[i]
		if update_targets or not _guest_targets.has(guest.id):
			_guest_targets[guest.id] = model.guest_position(guest)
		var target: Vector3 = _guest_targets[guest.id]
		var position_value: Vector3 = _guest_positions.get(guest.id, target)
		var velocity := target - position_value
		position_value = position_value.lerp(target, minf(1, delta * 5))
		_guest_positions[guest.id] = position_value
		live_ids[guest.id] = true
		var angle := atan2(velocity.x, velocity.z) if velocity.length() > 0.1 else 0.0
		visitor_mesh.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, angle), position_value - Vector3(0, 2, 0)))
		visitor_mesh.multimesh.set_instance_color(i, [Color("d88e55"), Color("5396bb"), Color("b56a86")][guest.ability])
	visitor_mesh.multimesh.visible_instance_count = model.guests.size()
	for id in _guest_positions.keys():
		if not live_ids.has(id):
			_guest_positions.erase(id)
			_guest_targets.erase(id)

func _update_camera() -> void:
	camera.size = zoom
	var target := Terrain.world(focus, 38)
	var distance := zoom * 1.05
	camera.position = target + Vector3(sin(yaw) * distance, distance * 0.68, cos(yaw) * distance)
	camera.look_at(target)

func pan(relative: Vector2) -> void:
	var units := zoom / maxf(get_viewport().get_visible_rect().size.y, 1)
	var right := Vector2(camera.basis.x.x, camera.basis.x.z)
	var up := Vector2(camera.basis.y.x, camera.basis.y.z)
	focus += (-right * relative.x + up * relative.y * 1.7) * units
	focus.x = clampf(focus.x, -340, 340)
	focus.y = clampf(focus.y, -380, 320)
	_update_camera()

func change_zoom(factor: float) -> void:
	zoom = clampf(zoom * factor, 180, 1050)
	_update_camera()

func rotate_view(amount: float) -> void:
	yaw += amount
	_update_camera()

func home() -> void:
	focus = Vector2(210, 10)
	zoom = 620
	yaw = 0.46
	_update_camera()

func map_point(screen_point: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(screen_point)
	var direction := camera.project_ray_normal(screen_point)
	var previous := 0.0
	for step in range(0, 3500, 8):
		var world_point := origin + direction * step
		var point := Vector2(world_point.x, world_point.z)
		if Terrain.contains(point) and world_point.y <= Terrain.height(point):
			var low := previous
			var high := float(step)
			for i in range(12):
				var middle := (low + high) * 0.5
				var sample := origin + direction * middle
				if sample.y <= Terrain.height(Vector2(sample.x, sample.z)):
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
