extends RefCounted
## Independent forest chunks can be culled; distant trees keep their silhouette.
const Terrain = preload("res://src/core/terrain.gd")
const Maps = preload("res://src/core/maps.gd")
const VisualStyles = preload("res://src/core/visual_styles.gd")
const Fleet = preload("res://src/core/lift_fleet.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const Art = preload("res://src/world/alpine_art.gd")
const CELL := 16.0
const CHUNK := 192.0
var groups: Array = []
var root := Node3D.new()
var candidates: Dictionary = {}
var detailed: ArrayMesh
var distant: ArrayMesh
var style_meshes: Dictionary = {}
var variants: Array = []
var available: Array = []
var clearing: Dictionary = {}
var wind_material: ShaderMaterial
var _wind_tier := -1

func _disk(blocked: Dictionary, point: Vector2, radius: float) -> void:
	for x in range(floori((point.x - radius) / CELL), ceili((point.x + radius) / CELL) + 1):
		for y in range(floori((point.y - radius) / CELL), ceili((point.y + radius) / CELL) + 1):
			if (Vector2(x, y) * CELL + Vector2.ONE * CELL * 0.5).distance_to(point) < radius + CELL:
				blocked[Vector2i(x, y)] = true

func _line(blocked: Dictionary, a: Vector2, b: Vector2, width: float) -> void:
	var count := maxi(1, ceili(a.distance_to(b) / CELL))
	for i in range(count + 1):
		_disk(blocked, a.lerp(b, float(i) / count), width)

func _choose_meshes(view: Node3D) -> void:
	var id: String = VisualStyles.valid(view.visual_style)
	if wind_material == null:
		wind_material = ShaderMaterial.new()
		wind_material.shader = preload("res://src/shaders/alpine_wind.gdshader")
		wind_material.set_shader_parameter("canopy_height", 16.0)
	if not style_meshes.has(id):
		var meshes: Array = []
		for species in range(5):
			var near_mesh: ArrayMesh = Art.new().tree_variant(id,species,false)
			var far_mesh: ArrayMesh = Art.new().tree_variant(id,species,true)
			near_mesh.surface_set_material(0,wind_material)
			far_mesh.surface_set_material(0,wind_material)
			meshes.append({"near":near_mesh,"far":far_mesh})
		style_meshes[id] = meshes
	variants = style_meshes[id]
	detailed = variants[0].near
	distant = variants[0].far

func build(view: Node3D) -> void:
	if not root.is_inside_tree():
		view.add_child(root)
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	groups.clear()
	_choose_meshes(view)
	var mountain: RefCounted = view.terrain
	var map_id: String = view.model.map_id
	var id := "%s/%d" % [map_id, mountain.generation]
	if not candidates.has(id):
		var entries: Array = []
		var random := RandomNumberGenerator.new()
		random.seed = 73628
		for i in range(15000):
			var point := Vector2(random.randf_range(mountain.bounds.position.x + 10, mountain.bounds.end.x - 10), random.randf_range(mountain.bounds.position.y + 10, mountain.bounds.end.y - 10))
			if i < 3600:
				point = Vector2(random.randf_range(-500, 500), random.randf_range(-600, 450))
			var grade: float = mountain.slope_percent(point)
			var height: float = mountain.height(point)
			var scale := random.randf_range(0.65, 1.15)
			var transform_value := Transform3D(Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale), Vector3(point.x, height, point.y))
			var tint := random.randf_range(0.86, 1)
			if point.distance_to(Vector2(-260, 255)) < 62 or point.distance_to(Terrain.BASE) < 46:
				continue
			entries.append({"point": point, "grade": grade, "height": height, "transform": transform_value, "color": Color(tint, tint, tint)})
		candidates[id] = entries
	var blocked: Dictionary = {}
	available.clear()
	_line(blocked, Vector2(185, 490), Terrain.BASE, 12)
	for area in view._pedestrian_snapshot.areas:
		_disk(blocked, area.center, area.radius + 3)
	for path in view._pedestrian_snapshot.links:
		for i in range(1, path.points.size()):
			_line(blocked, Terrain.unpack(path.points[i - 1]), Terrain.unpack(path.points[i]), float(path.get("width",7))*0.5+4)
	for piste in view.model.pistes:
		for i in range(1, piste.points.size()):
			_line(blocked, Terrain.unpack(piste.points[i - 1]), Terrain.unpack(piste.points[i]), Snow.piste_width(piste) * 0.5 + 8)
	for lift in view.model.lifts:
		_line(blocked, Terrain.unpack(lift.bottom), Terrain.unpack(lift.top), maxf(16, Fleet.rope_offset(lift) + 15))
	for building in view.model.buildings:
		_disk(blocked, Terrain.unpack(building.point), 36 if building.kind == "grand_hotel" else 29 if building.kind == "hotel" else 23)
	for reserve in view._extra_clearings: _disk(blocked,reserve.point,reserve.radius)
	clearing = blocked
	var style: Dictionary = VisualStyles.palette(view.visual_style)
	var foliage_tint: Color = Color(style.get("foliage", style.ambient)).lerp(Color.WHITE, 0.46)
	var rock_tint: Color = Color(style.rock).lerp(Color.WHITE, 0.55)
	var chunks: Dictionary = {}
	var rocks: Array = []
	var used := 0
	for entry in candidates[id]:
		if blocked.has(Vector2i((entry.point / CELL).floor())):
			continue
		available.append(entry)
		if entry.grade > 47 and rocks.size() < 150:
			rocks.append(entry)
			continue
		if entry.grade > 65 or entry.height > float(Maps.spec(map_id).get("tree_line", 620 if map_id == "fichtenkamm" else 360)) or used >= int(5400 * Maps.spec(map_id).forest) or absf(sin(entry.point.x * 0.031) * cos(entry.point.y * 0.023)) < 0.12:
			continue
		var cell := Vector2i((entry.point / CHUNK).floor())
		var species := 1 if absf(sin(entry.point.x*0.17+entry.point.y*0.07)) > 0.90 else 2 if absf(cos(entry.point.y*0.19)) > 0.97 else 3 if absf(sin(entry.point.x*0.067-entry.point.y*0.071)) > 0.89 else 4 if absf(cos(entry.point.y*0.091+entry.point.x*0.019)) > 0.92 else 0
		var key := Vector3i(cell.x,cell.y,species)
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(entry)
		used += 1
	for key in chunks:
		var entries: Array = chunks[key]
		var node := MultiMeshInstance3D.new()
		node.multimesh = view._multimesh(variants[key.z].far, entries.size())
		for i in range(entries.size()):
			node.multimesh.set_instance_transform(i, entries[i].transform)
			node.multimesh.set_instance_color(i, entries[i].color * Color(Maps.spec(map_id).trees).lerp(Color.WHITE, 0.52) * foliage_tint)
		root.add_child(node)
		groups.append({"node": node, "center": (Vector2(key.x,key.y) + Vector2.ONE * 0.5) * CHUNK, "detail": false, "species": key.z, "base_tints": entries.map(func(entry): return entry.color)})
	if not groups.is_empty():
		view.trees = groups[0].node
	var mesh := Art.new().rock()
	mesh.surface_set_material(0, view._solid)
	view.rocks.multimesh = view._multimesh(mesh, rocks.size())
	for i in range(rocks.size()):
		view.rocks.multimesh.set_instance_transform(i, rocks[i].transform)
		view.rocks.multimesh.set_instance_color(i, rock_tint)
	view.rocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	update(view.focus, view.zoom, 1)

func apply_style(view: Node3D) -> void:
	# Switch prebuilt models and colors without regenerating 11,000 forest
	# candidates, changing their transforms or touching terrain geometry.
	_choose_meshes(view)
	var style: Dictionary = VisualStyles.palette(view.visual_style)
	var foliage: Color = Color(style.get("foliage", style.ambient)).lerp(Color.WHITE, 0.46)
	var tree_base: Color = Color(Maps.spec(view.model.map_id).trees).lerp(Color.WHITE, 0.52)
	for group in groups:
		var mesh: MultiMesh = group.node.multimesh
		mesh.mesh = variants[group.species].near if group.detail else variants[group.species].far
		var tints: Array = group.base_tints
		for i in range(tints.size()):
			mesh.set_instance_color(i, Color(tints[i]) * tree_base * foliage)
	if view.rocks.multimesh != null:
		var tint: Color = Color(style.rock).lerp(Color.WHITE, 0.55)
		for i in range(view.rocks.multimesh.instance_count):
			view.rocks.multimesh.set_instance_color(i, tint)

func update(focus: Vector2, zoom: float, tier: int) -> void:
	if wind_material != null and _wind_tier != tier:
		_wind_tier = tier
		# Vertex-only gusts; reduced on low-end phones, no per-tree CPU updates.
		wind_material.set_shader_parameter("sway_metres", [0.14, 0.27, 0.38][clampi(tier, 0, 2)])
	for group in groups:
		var distance: float = group.center.distance_to(focus)
		group.node.visible = distance < maxf(zoom * 2.5, 360) + CHUNK
		var detail: bool = tier > 0 and zoom < 700 and distance < (360 if tier == 2 else 210)
		if detail != group.detail:
			group.detail = detail
			group.node.multimesh.mesh = variants[group.species].near if detail else variants[group.species].far
		group.node.multimesh.visible_instance_count = int(group.node.multimesh.instance_count * (0.65 if tier == 0 else 1.0))
		group.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if detail and tier == 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


