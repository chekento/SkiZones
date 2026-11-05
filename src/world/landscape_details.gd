extends RefCounted
## Ground clutter is visual only and shares the forest's construction clearing.
const Art = preload("res://src/world/alpine_art.gd")
var root := Node3D.new()
var groups: Array = []
var wildlife_groups: Array = []
var animals: Array = []
var _shrub_wind: ShaderMaterial

func build(view: Node3D) -> void:
	if not root.is_inside_tree(): view.add_child(root)
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	groups.clear()
	animals.clear()
	wildlife_groups.clear()
	var buckets: Dictionary = {}
	# Give visible natural stones, shrubs and saplings more weight than furniture.
	const MIX := [0, 1, 5, 9, 10, 13, 15, 16, 17, 24, 25, 26, 27, 28, 29, 0, 1, 24, 25, 26, 27, 29, 2, 3, 4, 6, 7, 8, 11, 12, 14, 18, 19, 20, 21, 22, 23]
	var count := 0
	for entry in view.forest.available:
		if count >= 2400: break
		var point: Vector2 = entry.point
		if entry.grade > 58 or not view.terrain.bounds.has_point(point): continue
		var cell := Vector2i((point/192).floor())
		var kind: int = MIX[posmod(roundi(point.x*3+point.y*7), MIX.size())]
		var key := Vector3i(cell.x,cell.y,kind)
		if not buckets.has(key): buckets[key]=[]
		buckets[key].append(entry)
		count += 1
	var meshes: Array = []
	for kind in range(30):
		var mesh: ArrayMesh = Art.new().landscape_detail(kind,view.visual_style)
		mesh.surface_set_material(0,view._solid)
		meshes.append(mesh)
	if _shrub_wind == null:
		_shrub_wind = ShaderMaterial.new()
		_shrub_wind.shader = preload("res://src/shaders/alpine_wind.gdshader")
		_shrub_wind.set_shader_parameter("sway_metres", 0.15)
		_shrub_wind.set_shader_parameter("canopy_height", 3.5)
	for key in buckets:
		var entries: Array = buckets[key]
		var node := MultiMeshInstance3D.new()
		node.multimesh=view._multimesh(meshes[key.z],entries.size())
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if key.z in [1, 9, 15, 16, 24, 26, 27, 28]: node.material_override = _shrub_wind
		for index in range(entries.size()):
			var transform_value: Transform3D = entries[index].transform
			transform_value.origin=view.ground_position(entries[index].point)
			node.multimesh.set_instance_transform(index,transform_value)
			node.multimesh.set_instance_color(index,Color.WHITE)
		root.add_child(node)
		groups.append({"node":node,"center":(Vector2(key.x,key.y)+Vector2.ONE*0.5)*192})
	for kind in range(3):
		var node := MultiMeshInstance3D.new()
		var mesh: ArrayMesh = Art.new().wildlife(kind)
		mesh.surface_set_material(0,view._solid)
		node.multimesh=view._multimesh(mesh,8)
		node.multimesh.visible_instance_count=0
		root.add_child(node)
		wildlife_groups.append(node)
	var per_kind := [0,0,0]
	for entry in view.forest.available:
		if animals.size()>=24: break
		if entry.grade>30 or entry.height-view.terrain.height(view.Terrain.BASE)>480: continue
		var point: Vector2=entry.point
		var target := point + Vector2.from_angle(point.x*0.4)*14
		var valid := true
		for step in range(6):
			var at := point.lerp(target,float(step)/5)
			if not view.terrain.contains(at) or view.forest.clearing.has(Vector2i((at/view.forest.CELL).floor())): valid=false
		if not valid: continue
		var kind := animals.size()%3
		animals.append({"a":point,"b":target,"kind":kind,"index":per_kind[kind],"phase":animals.size()*1.7})
		per_kind[kind]+=1
	for kind in range(3): wildlife_groups[kind].multimesh.visible_instance_count=per_kind[kind]
	update(view)

func update(view: Node3D) -> void:
	for group in groups:
		group.node.visible=group.center.distance_to(view.focus)<maxf(260,view.zoom*1.6) and view.zoom<1500
		group.node.multimesh.visible_instance_count=int(group.node.multimesh.instance_count*(0.4 if view.quality_tier==0 else 0.75 if view.quality_tier==1 else 1.0))
	for node in wildlife_groups: node.visible=view.wildlife_enabled and view.zoom<1100
	if not view.wildlife_enabled: return
	var clock: float=view.model.movement_clock()+view.simulation_fraction
	for animal in animals:
		var phase: float=clock*0.025+animal.phase
		var t := 0.5-0.5*cos(phase)
		var point: Vector2=animal.a.lerp(animal.b,t)
		var direction: Vector2=(animal.b-animal.a).normalized()*(1 if sin(phase)>=0 else -1)
		var at: Vector3=view.ground_position(point,0.08)
		# Small ear/body movement follows simulation time, including pause.
		at.y += absf(sin(clock*0.8+animal.phase))*0.08
		var transform_value := Transform3D(Basis(Vector3.UP,atan2(direction.x,direction.y)),at)
		wildlife_groups[animal.kind].multimesh.set_instance_transform(animal.index,transform_value)
		wildlife_groups[animal.kind].multimesh.set_instance_color(animal.index,Color.WHITE)
