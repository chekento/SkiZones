extends Node3D
## Original procedural scenery: no external game assets or plugins required.

const Terrain = preload("res://src/core/terrain.gd")
const Catalog = preload("res://src/core/catalog.gd")
const PISTE_COLORS := [Color("368bcb"), Color("ce5660"), Color("344859")]

var model: RefCounted
var camera := Camera3D.new()
var focus := Vector2(15, -30)
var yaw := 0.46
var zoom := 680.0
var asset_root := Node3D.new()
var preview_root := Node3D.new()
var trees := MultiMeshInstance3D.new()
var visitor_mesh := MultiMeshInstance3D.new()
var chairs: Array = []
var _seen_revision := -1
var _guest_positions: Dictionary = {}
var _clock := 0.0
var _last_guest_ids: Array = []
var slopes_visible := false
var slope_overlay: MeshInstance3D
var terrain_instance: MeshInstance3D

func setup(resort: RefCounted) -> void:
	model = resort
	_build_environment()
	_build_terrain()
	add_child(trees)
	add_child(asset_root)
	add_child(preview_root)
	add_child(visitor_mesh)
	var mesh := CapsuleMesh.new()
	mesh.radius = 1.0
	mesh.height = 4.5
	mesh.radial_segments = 5
	mesh.rings = 1
	visitor_mesh.multimesh = _multimesh(mesh, 240)
	visitor_mesh.multimesh.visible_instance_count = 0
	visitor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.far = 4000
	camera.current = true
	_update_camera()
	rebuild()

func _material(color: Color, vertex_color: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.vertex_color_use_as_albedo = vertex_color
	material.roughness = 0.9
	return material

func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color("fff0db")
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 1600
	add_child(sun)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("b5cdd5")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("bfdce7")
	settings.ambient_light_energy = 0.42
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)

func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-400, 340, 10):
		for x in range(-360, 360, 10):
			var points := [Vector2(x, z), Vector2(x, z + 10), Vector2(x + 10, z), Vector2(x + 10, z + 10)]
			for index in [0, 2, 1, 2, 3, 1]:
				var p: Vector2 = points[index]
				var h := Terrain.height(p)
				var grade := absf(Terrain.height(p + Vector2(3, 0)) - h) + absf(Terrain.height(p + Vector2(0, 3)) - h)
				var snow := Color("e2edf0").lerp(Color("f7faf7"), clampf(h / 260.0, 0, 1))
				if grade > 2.2:
					snow = snow.lerp(Color("889da7"), clampf((grade - 2.2) * 0.27, 0, 0.7))
				var variation := sin(x * 0.09 + z * 0.05) * 0.016
				surface.set_color(snow.darkened(variation + 0.012))
				surface.add_vertex(Terrain.world(p))
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = _material(Color.WHITE, true)
	terrain_instance = instance
	add_child(instance)
	_box(self, Vector3(0, -8, -30), Vector3(720, 25, 740), Color("7295a4"))
	# A small frozen lake and the valley access path anchor the resort entrance.
	var lake := CylinderMesh.new()
	lake.top_radius = 53
	lake.bottom_radius = 53
	lake.height = 0.6
	lake.radial_segments = 48
	var lake_node := _mesh(self, lake, Vector3(-260, 7, 255), Color("81b6c5"))
	lake_node.scale.z = 0.62
	_ribbon(self, [[185, 335], [185, 280], [185, 230]], 18.0, Color("a0abb3"), 0.25)
	_label(self, "TALZUGANG", Terrain.world(Terrain.BASE + Vector2(0, 65), 9), Color("36647a"))

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
				var color := Color("83bcaa")
				if grade >= 8.0:
					color = Color("68a6d0") if grade <= 30.0 else (Color("d8777c") if grade <= 55.0 else Color("687381"))
				color.a = 0.68
				surface.set_color(color)
				# Keep the overlay below built piste ribbons and above the snow.
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

func _build_trees() -> void:
	var pine := CylinderMesh.new()
	pine.top_radius = 0
	pine.bottom_radius = 6.2
	pine.height = 23
	pine.radial_segments = 5
	var pine_surface := SurfaceTool.new()
	pine_surface.append_from(pine, 0, Transform3D.IDENTITY)
	var tree_material := _material(Color.WHITE, true)
	var instances := _multimesh(pine_surface.commit(), 1500)
	instances.mesh.surface_set_material(0, tree_material)
	var random := RandomNumberGenerator.new()
	random.seed = 73628
	var used := 0
	for i in range(2600):
		var point := Vector2(random.randf_range(-350, 350), random.randf_range(-370, 325))
		if Terrain.height(point) > 200 or point.distance_to(Vector2(-260, 255)) < 62 or point.distance_to(Terrain.BASE) < 53:
			continue
		var clear := true
		for piste in model.pistes:
			for j in range(1, piste.points.size()):
				if Geometry2D.get_closest_point_to_segment(point, Terrain.unpack(piste.points[j - 1]), Terrain.unpack(piste.points[j])).distance_to(point) < 20:
					clear = false
		for lift in model.lifts:
			if Geometry2D.get_closest_point_to_segment(point, Terrain.unpack(lift.bottom), Terrain.unpack(lift.top)).distance_to(point) < 12:
				clear = false
		for building in model.buildings:
			if Terrain.unpack(building.point).distance_to(point) < 23:
				clear = false
		if not clear:
			continue
		var size_value := random.randf_range(0.65, 1.25)
		var transform_value := Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * size_value), Terrain.world(point, 10 * size_value))
		instances.set_instance_transform(used, transform_value)
		instances.set_instance_color(used, Color("407778").lerp(Color("83aaa1"), random.randf() * 0.65))
		used += 1
		if used == instances.instance_count:
			break
	instances.visible_instance_count = used
	trees.multimesh = instances
	trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func rebuild() -> void:
	_seen_revision = model.revision
	for child in asset_root.get_children():
		asset_root.remove_child(child)
		child.queue_free()
	chairs.clear()
	for piste in model.pistes:
		var color: Color = PISTE_COLORS[piste.difficulty]
		_ribbon(asset_root, piste.points, 20, color.lightened(0.25), 0.35)
		_ribbon(asset_root, piste.points, 16, Color("eff8fa"), 0.5)
		var length: float = piste.length
		for i in range(ceili(length / 40)):
			var fraction := float(i) * 40 / length
			var point := Terrain.point_on_path(piste.points, fraction)
			var ahead := Terrain.point_on_path(piste.points, minf(fraction + 0.01, 1.0))
			var side := (ahead - point).normalized().orthogonal() * 10
			for sign_value in [-1, 1]:
				var flag := Terrain.world(point + side * sign_value, 3.0)
				_box(asset_root, flag, Vector3(0.65, 6, 0.65), Color("c2d5dc"))
				_box(asset_root, flag + Vector3(0, 1.6, 0), Vector3(3, 2, 0.8), color)
		_label(asset_root, ["BLAU", "ROT", "SCHWARZ"][piste.difficulty], Terrain.world(Terrain.unpack(piste.points[0]), 21), color)
	for lift in model.lifts:
		_build_lift(lift)
	for building in model.buildings:
		_build_building(building)
	_build_trees()

func _build_lift(lift: Dictionary) -> void:
	var bottom := Terrain.unpack(lift.bottom)
	var top := Terrain.unpack(lift.top)
	var a := Terrain.world(bottom, 13)
	var b := Terrain.world(top, 13)
	for point in [bottom, top]:
		var base := Terrain.world(point)
		_box(asset_root, base + Vector3(0, 5, 0), Vector3(19, 10, 16), Color("254a5a"))
		_box(asset_root, base + Vector3(0, 11, 0), Vector3(24, 3, 20), Color("ebac77"))
	var supports := maxi(2, ceili(lift.length / 85.0))
	for i in range(1, supports):
		var t := float(i) / supports
		var point := bottom.lerp(top, t)
		var head := a.lerp(b, t)
		_link(asset_root, Terrain.world(point), head, 1.25, Color("506979"))
		_box(asset_root, head, Vector3(12, 1.5, 3), Color("3e5665"))
	for offset in [-3.0, 3.0]:
		_link(asset_root, a + Vector3(offset, 0, 0), b + Vector3(offset, 0, 0), 0.38, Color("3b5967"))
	for i in range(12):
		var chair := _box(asset_root, a, Vector3(5, 3, 4), Color("e8ad7c") if lift.kind != "gondola" else Color("4796ad"))
		chairs.append({"node": chair, "a": a, "b": b, "offset": float(i) / 12, "id": lift.id})

func _build_building(building: Dictionary) -> void:
	var point := Terrain.world(Terrain.unpack(building.point))
	var color := Color(Catalog.BUILDINGS[building.kind].color)
	var big: bool = building.kind == "hotel"
	var dimensions := Vector3(25, 20, 22) if big else Vector3(20, 10, 16)
	_box(asset_root, point + Vector3(0, dimensions.y / 2, 0), dimensions, color)
	_box(asset_root, point + Vector3(0, dimensions.y + 1.5, 0), Vector3(dimensions.x + 5, 3, dimensions.z + 5), Color("f4f6f0"))
	for i in [-1, 0, 1]:
		_box(asset_root, point + Vector3(i * 6, 6, dimensions.z / 2 + 0.2), Vector3(3.3, 4, 0.6), Color("315b6b"))
	_box(asset_root, point + Vector3(-4, 4, dimensions.z / 2 + 0.5), Vector3(3, 7, 0.8), Color("254552"))
	if building.kind == "first_aid":
		_box(asset_root, point + Vector3(0, dimensions.y + 3.2, 0), Vector3(12, 0.5, 3), Color("dc6570"))
		_box(asset_root, point + Vector3(0, dimensions.y + 3.3, 0), Vector3(3, 0.5, 12), Color("dc6570"))

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
	parent.add_child(instance)

func preview(points: Array, color: Color, building_kind: String = "") -> void:
	for child in preview_root.get_children():
		preview_root.remove_child(child)
		child.queue_free()
	if points.is_empty():
		return
	_ribbon(preview_root, points, 9, color, 1.2)
	for point in points:
		var sphere := SphereMesh.new()
		sphere.radius = 4.5
		sphere.height = 9
		_mesh(preview_root, sphere, Terrain.world(Terrain.unpack(point), 5), color)
	if building_kind != "":
		_box(preview_root, Terrain.world(Terrain.unpack(points.back()), 7), Vector3(22, 14, 18), color)

func _process(delta: float) -> void:
	if model == null:
		return
	if model.revision != _seen_revision:
		rebuild()
	_clock += delta
	for chair in chairs:
		var lift: Dictionary = model.asset(chair.id)
		var time := float(model.minute) / 7.0 if model.lift_open(lift) else 0.0
		var t := fposmod(time + chair.offset, 1.0)
		var outbound := t < 0.5
		chair.node.position = chair.a.lerp(chair.b, t * 2 if outbound else (1 - t) * 2) + Vector3(-3 if outbound else 3, -4, 0)
	var live_ids: Array = []
	for i in range(model.guests.size()):
		var guest: Dictionary = model.guests[i]
		var target: Vector3 = model.guest_position(guest)
		var position_value: Vector3 = _guest_positions.get(guest.id, target)
		position_value = position_value.lerp(target, minf(1, delta * 4))
		_guest_positions[guest.id] = position_value
		live_ids.append(guest.id)
		visitor_mesh.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, position_value))
		visitor_mesh.multimesh.set_instance_color(i, [Color("ee9666"), Color("2986b0"), Color("a25a8e")][guest.ability])
	visitor_mesh.multimesh.visible_instance_count = model.guests.size()
	for id in _last_guest_ids:
		if not live_ids.has(id):
			_guest_positions.erase(id)
	_last_guest_ids = live_ids

func _update_camera() -> void:
	camera.size = zoom
	var target := Terrain.world(focus, 38)
	camera.position = target + Vector3(sin(yaw) * 960, 760, cos(yaw) * 960)
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
	zoom = 680
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
