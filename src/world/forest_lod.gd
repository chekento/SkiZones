extends RefCounted
## Independent forest chunks can be culled; distant trees keep their silhouette.
const Terrain = preload("res://src/core/terrain.gd")
const Maps = preload("res://src/core/maps.gd")
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

func _disk(blocked: Dictionary, point: Vector2, radius: float) -> void:
	for x in range(floori((point.x - radius) / CELL), ceili((point.x + radius) / CELL) + 1):
		for y in range(floori((point.y - radius) / CELL), ceili((point.y + radius) / CELL) + 1):
			if (Vector2(x, y) * CELL + Vector2.ONE * CELL * 0.5).distance_to(point) < radius + CELL:
				blocked[Vector2i(x, y)] = true

func _line(blocked: Dictionary, a: Vector2, b: Vector2, width: float) -> void:
	var count := maxi(1, ceili(a.distance_to(b) / CELL))
	for i in range(count + 1):
		_disk(blocked, a.lerp(b, float(i) / count), width)

func build(view: Node3D) -> void:
	if not root.is_inside_tree():
		view.add_child(root)
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	groups.clear()
	if detailed == null:
		detailed = Art.new().pine()
		distant = Art.new().pine_distant()
		detailed.surface_set_material(0, view._solid)
		distant.surface_set_material(0, view._solid)
	var mountain: RefCounted = view.terrain
	var map_id: String = view.model.map_id
	var id := "%s/%d" % [map_id, mountain.generation]
	if not candidates.has(id):
		var entries: Array = []
		var random := RandomNumberGenerator.new()
		random.seed = 73628
		for i in range(11000):
			var point := Vector2(random.randf_range(mountain.bounds.position.x + 10, mountain.bounds.end.x - 10), random.randf_range(mountain.bounds.position.y + 10, mountain.bounds.end.y - 10))
			if i < 2400:
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
	_line(blocked, Vector2(185, 490), Terrain.BASE, 12)
	for area in view._pedestrian_snapshot.areas:
		_disk(blocked, area.center, area.radius + 3)
	for path in view._pedestrian_snapshot.links:
		for i in range(1, path.points.size()):
			_line(blocked, Terrain.unpack(path.points[i - 1]), Terrain.unpack(path.points[i]), 7)
	for piste in view.model.pistes:
		for i in range(1, piste.points.size()):
			_line(blocked, Terrain.unpack(piste.points[i - 1]), Terrain.unpack(piste.points[i]), Snow.piste_width(piste) * 0.5 + 8)
	for lift in view.model.lifts:
		_line(blocked, Terrain.unpack(lift.bottom), Terrain.unpack(lift.top), maxf(16, Fleet.rope_offset(lift) + 15))
	for building in view.model.buildings:
		_disk(blocked, Terrain.unpack(building.point), 29 if building.kind == "hotel" else 23)
	var chunks: Dictionary = {}
	var rocks: Array = []
	var used := 0
	for entry in candidates[id]:
		if blocked.has(Vector2i((entry.point / CELL).floor())):
			continue
		if entry.grade > 47 and rocks.size() < 90:
			rocks.append(entry)
			continue
		if entry.grade > 65 or entry.height > (620 if map_id == "fichtenkamm" else 360) or used >= int(3200 * Maps.spec(map_id).forest) or absf(sin(entry.point.x * 0.031) * cos(entry.point.y * 0.023)) < 0.18:
			continue
		var key := Vector2i((entry.point / CHUNK).floor())
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(entry)
		used += 1
	for key in chunks:
		var entries: Array = chunks[key]
		var node := MultiMeshInstance3D.new()
		node.multimesh = view._multimesh(distant, entries.size())
		for i in range(entries.size()):
			node.multimesh.set_instance_transform(i, entries[i].transform)
			node.multimesh.set_instance_color(i, entries[i].color * Color(Maps.spec(map_id).trees).lerp(Color.WHITE, 0.72))
		root.add_child(node)
		groups.append({"node": node, "center": (Vector2(key) + Vector2.ONE * 0.5) * CHUNK, "detail": false})
	if not groups.is_empty():
		view.trees = groups[0].node
	var mesh := Art.new().rock()
	mesh.surface_set_material(0, view._solid)
	view.rocks.multimesh = view._multimesh(mesh, rocks.size())
	for i in range(rocks.size()):
		view.rocks.multimesh.set_instance_transform(i, rocks[i].transform)
		view.rocks.multimesh.set_instance_color(i, Color.WHITE)
	view.rocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	update(view.focus, view.zoom, 1)

func update(focus: Vector2, zoom: float, tier: int) -> void:
	for group in groups:
		var distance: float = group.center.distance_to(focus)
		group.node.visible = distance < maxf(zoom * 2.5, 360) + CHUNK
		var detail: bool = tier > 0 and zoom < 700 and distance < (360 if tier == 2 else 210)
		if detail != group.detail:
			group.detail = detail
			group.node.multimesh.mesh = detailed if detail else distant
		group.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if detail and tier == 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
