extends Node3D
## Visual-only snow wear derived from REAL walking guests. Repeated passage
## gradually changes distinct footprints into compressed snow, an icy groove,
## and finally a broad trodden path. Never changes routing, collisions, saves,
## economy or guest movement. Bounded CPU work / GPU-instanced rendering.
const CELL := 2.0
const MAX_CELLS := 6000
const MAX_VISIBLE := 1800
const COLOURS := [
	Color(0.55, 0.67, 0.73, 0.54),
	Color(0.69, 0.76, 0.80, 0.59),
	Color(0.51, 0.65, 0.73, 0.71),
	Color(0.72, 0.73, 0.67, 0.80),
]
const WIDTHS := [0.34, 0.90, 1.32, 2.15]
const LENGTHS := [0.63, 1.55, 1.98, 2.35]
var _cells: Dictionary = {}
var _last: Dictionary = {}
var _layers: Array[MultiMeshInstance3D] = []
var _dirty := true
var _refresh := 0.0
var _last_focus := Vector2.INF

static func wear_stage(passages: int) -> int:
	if passages < 3: return 0
	if passages < 12: return 1
	if passages < 32: return 2
	return 3

## Stable, bounded per-resort data for save format 17.
## No transient guest IDs or GPU/Node objects are persisted.
static func valid_state(rows: Variant) -> bool:
	if not rows is Array or rows.size() > MAX_CELLS: return false
	var seen: Dictionary = {}
	for row in rows:
		if not row is Array or row.size() != 5: return false
		for index in range(5):
			if not (row[index] is int or row[index] is float) or not is_finite(float(row[index])): return false
		for index in range(3):
			if float(row[index]) != floorf(float(row[index])): return false
		if absi(int(row[0])) > 16384 or absi(int(row[1])) > 16384 or int(row[2]) < 1 or int(row[2]) > 1000: return false
		var direction := Vector2(float(row[3]),float(row[4]))
		if direction.length_squared() < 0.5 or direction.length_squared() > 1.5: return false
		var key := Vector2i(int(row[0]),int(row[1]))
		if seen.has(key): return false
		seen[key] = true
	return true

func export_state() -> Array:
	var output: Array = []
	var keys: Array = _cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x or a.x == b.x and a.y < b.y
	)
	for key in keys:
		var cell: Dictionary = _cells[key]
		var direction: Vector2 = cell.direction.normalized()
		output.append([key.x,key.y,int(cell.hits),direction.x,direction.y])
	return output

func import_state(rows: Variant) -> bool:
	if not valid_state(rows): return false
	reset()
	for row in rows:
		var key := Vector2i(int(row[0]),int(row[1]))
		_cells[key] = {"hits":int(row[2]),"direction":Vector2(float(row[3]),float(row[4])).normalized()}
	_dirty = true
	return true

func setup() -> void:
	if not _layers.is_empty(): return
	for level in range(4):
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.WHITE
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		plane.material = mat
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = plane
		multi.instance_count = MAX_VISIBLE * (2 if level == 0 else 1)
		multi.visible_instance_count = 0
		var node := MultiMeshInstance3D.new()
		node.name = "walk_wear_%d" % level
		node.multimesh = multi
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_layers.append(node)

func reset() -> void:
	_cells.clear()
	_last.clear()
	_dirty = true
	_last_focus = Vector2.INF
	for layer in _layers:
		layer.multimesh.visible_instance_count = 0

func sample_guest(id: int, world: Vector3, tick: int, leg: int, people: int = 1) -> void:
	if not world.is_finite(): return
	var at := Vector2(world.x, world.z)
	var before: Dictionary = _last.get(id, {})
	if not before.is_empty() and int(before.tick) == tick: return
	_last[id] = {"point": at, "tick": tick, "leg": leg}
	if before.is_empty() or int(before.leg) != leg: return
	var from: Vector2 = before.point
	var distance: float = from.distance_to(at)
	# Ignore standing in place and teleport-like jumps after a new route.
	if distance < 0.85 or distance > 48.0: return
	var direction: Vector2 = (at - from) / distance
	var steps := mini(30, maxi(1, ceili(distance / CELL)))
	var last_key := Vector2i(1000000, 1000000)
	for i in range(steps + 1):
		var point: Vector2 = from.lerp(at, float(i) / steps)
		var key := Vector2i(floori(point.x / CELL), floori(point.y / CELL))
		if key == last_key: continue
		last_key = key
		if not _cells.has(key) and _cells.size() >= MAX_CELLS: continue
		var old: Dictionary = _cells.get(key, {"hits": 0, "direction": direction})
		var old_stage := wear_stage(int(old.hits))
		old.hits = mini(1000, int(old.hits) + clampi(people, 1, 6))
		old.direction = Vector2(old.direction).lerp(direction, 0.17).normalized()
		_cells[key] = old
		if int(old.hits) <= 6 or old_stage != wear_stage(int(old.hits)): _dirty = true

func update_visuals(view: Node3D, delta: float) -> void:
	if _layers.is_empty(): return
	_refresh += maxf(0, delta)
	if _refresh < 1.0: return
	_refresh = 0
	if not _dirty and _last_focus.distance_to(view.focus) < 30.0: return
	_last_focus = view.focus
	_dirty = false
	var counts := [0, 0, 0, 0]
	var radius: float = clampf(view.zoom * 1.4, 180.0, 1100.0)
	var cap := 540 if view.quality_tier == 0 else 1100 if view.quality_tier == 1 else MAX_VISIBLE
	for key in _cells:
		var point := (Vector2(key) + Vector2.ONE * 0.5) * CELL
		if point.distance_to(view.focus) > radius: continue
		var data: Dictionary = _cells[key]
		var level := wear_stage(int(data.hits))
		if counts[level] >= cap * (2 if level == 0 else 1): continue
		var direction: Vector2 = data.direction
		var bearing := atan2(direction.x, direction.y)
		var many := 2 if level == 0 else 1
		for side_index in range(many):
			var offset := Vector2.ZERO
			if level == 0:
				offset = direction.orthogonal() * (0.22 if side_index == 0 else -0.22) + direction * (0.30 if side_index == 0 else -0.30)
			var pos: Vector3 = view.ground_position(point + offset, 0.12 + level * 0.025)
			var basis := Basis(Vector3.UP, bearing).scaled(Vector3(WIDTHS[level], 1, LENGTHS[level]))
			var multi: MultiMesh = _layers[level].multimesh
			multi.set_instance_transform(counts[level], Transform3D(basis, pos))
			multi.set_instance_color(counts[level], COLOURS[level])
			counts[level] += 1
	for level in range(4):
		_layers[level].multimesh.visible_instance_count = counts[level]
