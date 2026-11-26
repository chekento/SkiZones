extends SceneTree
const Depth = preload("res://src/world/perceptual_depth.gd")
const Mountain = preload("res://src/core/mountain.gd")
const View = preload("res://src/world/resort_view.gd")
const SnowRender = preload("res://src/world/snow_render.gd")
var passed := 0
var failed := 0

func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ", label)
	else: failed += 1; push_error("FAIL " + label)

func transforms(depth: RefCounted) -> Array:
	return depth.anchors.duplicate()

func free_orphans(owner: Object, seen: Dictionary) -> void:
	if seen.has(owner.get_instance_id()): return
	seen[owner.get_instance_id()] = true
	for property in owner.get_property_list():
		if int(property.type) != TYPE_OBJECT: continue
		var value: Variant = owner.get(property.name)
		if not is_instance_valid(value): continue
		if value is Node and value.get_parent() == null: value.free()
		elif value is RefCounted and not value is Resource: free_orphans(value, seen)

func run() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var mountain := Mountain.new()
	var depth := Depth.new()
	depth.build(parent, mountain)
	check(depth.layers.size() == 3 and depth.root.get_child_count() == 3, "Three spatial strata use just three batched scene nodes")
	var anchored := transforms(depth)
	check(anchored.size() == 24, "Atmospheric geometry has a hard 24-instance budget")
	for layer in range(3):
		for i in range(8):
			var at: Vector3 = depth.anchors[layer * 8 + i].origin
			var point := Vector2(at.x, at.z)
			check(mountain.contains(point) and is_equal_approx(at.y - mountain.height(point), Depth.HEIGHTS[layer]), "Stratum %d / %d is height-locked to its actual terrain location" % [layer, i])
	depth.configure(Color.WHITE, 1.0, 2, 1, true)
	check(depth.layers.all(func(node): return node.multimesh.visible_instance_count == 4), "Balanced quality draws twelve mist volumes")
	depth.configure(Color.WHITE, 1.0, 2, 2, true)
	check(depth.layers.all(func(node): return node.multimesh.visible_instance_count == 8), "High quality stays within 24 fixed volumes")
	depth.configure(Color.WHITE, 1.0, 2, 0, true)
	check(depth.layers.all(func(node): return node.multimesh.visible_instance_count == 0), "Economy has no extra atmospheric instances")
	depth.configure(Color.WHITE, 1.0, 2, 2, false)
	check(depth.layers.all(func(node): return node.multimesh.visible_instance_count == 0), "Effects off suppresses the complete additional atmosphere")
	depth.set_camera_context(true, false, true, 2)
	check(depth.root.visible, "Perspective exploration enables layered depth")
	for context in [[false,false,true,2], [true,true,true,2], [true,false,false,2], [true,false,true,0]]:
		depth.set_camera_context(context[0], context[1], context[2], context[3])
		check(not depth.root.visible, "Planning, orthographic views and reduced effects remain clear")
	check(transforms(depth) == anchored, "Weather, quality and camera context never scroll any world anchor")
	depth.build(parent, mountain)
	check(transforms(depth) == anchored and parent.get_child_count() == 1 and depth.root.get_child_count() == 3, "Rebuilding produces identical placement without accumulating layers")
	# Large real mountain maps retain the same count and height anchoring;
	# only horizontal world-space silhouettes become progressively broader.
	var compact := Rect2(-750,-950,1500,1900)
	var broad := Rect2(-6000,-6000,12000,12000)
	check(Depth.horizontal_scale(compact,0)==1.0 and Depth.horizontal_scale(compact,2)==1.0, "Compact map atmospheric art is unchanged")
	check(Depth.horizontal_scale(broad,0)>1.0 and Depth.horizontal_scale(broad,2)>Depth.horizontal_scale(broad,0), "Distant ridges receive broader silhouettes than foreground strata")
	check(Depth.horizontal_scale(Rect2(0,0,50000,50000),2)<=1.8, "Large-map horizontal spread has a hard fill budget")
	var old_bounds := mountain.bounds
	mountain.bounds = broad
	depth.build(parent,mountain)
	check(depth.anchors.size()==24 and depth.layers.size()==3, "Expanded panorama adds neither instances nor draw groups")
	for layer in range(3):
		var expected: float = Depth.STRATA[layer].x * 0.8 * Depth.horizontal_scale(broad,layer)
		var anchor: Transform3D = depth.anchors[layer*8]
		check(is_equal_approx(anchor.basis.x.length(),expected), "Large-map stratum %d uses its intended horizontal extent" % layer)
		check(is_equal_approx(anchor.basis.y.length(),Depth.STRATA[layer].y*0.8), "Large-map stratum %d preserves vertical extent" % layer)
		check(is_equal_approx(anchor.origin.y-mountain.height(Vector2(anchor.origin.x,anchor.origin.z)),Depth.HEIGHTS[layer]), "Large-map stratum %d preserves terrain height lock" % layer)
	mountain.bounds = old_bounds
	depth.build(parent,mountain)
	check(transforms(depth)==anchored, "Switching back to a compact map restores deterministic original anchors")
	var view := View.new()
	parent.add_child(view)
	view.terrain = mountain
	view.add_child(view.camera)
	view.perceptual_depth.build(view, mountain)
	view.set_process(false)
	view._update_camera()
	var camera_before := view.camera.global_transform
	var ray_before := view.camera.project_ray_normal(Vector2(640, 450))
	view.effects_enabled = false
	view._update_depth_context()
	check(view.camera.global_transform == camera_before and view.camera.project_ray_normal(Vector2(640,450)) == ray_before, "Depth toggling preserves the exact gameplay camera and picking rays")
	check(not view.perceptual_depth.root.visible and not view.snow_renderer.depth_detail_enabled, "Actual resort integration disables atmosphere and snow cues together")
	view.effects_enabled = true
	view._update_depth_context()
	check(view.perceptual_depth.root.visible and view.snow_renderer.depth_detail_enabled, "Actual resort integration restores depth effects")
	view.camera_mode = 2; view._update_camera()
	check(not view.perceptual_depth.root.visible, "Actual construction camera hides atmospheric strata")
	view.camera_mode = 3; view._update_camera()
	check(not view.perceptual_depth.root.visible, "Actual top-down camera retains an unobstructed plan")
	view.camera_mode = 0; view.visual_style = "monochrome"; view._update_camera()
	check(not view.perceptual_depth.root.visible and not view.snow_renderer.depth_detail_enabled, "Monochrome keeps its clean line-art style")
	view.visual_style = "piste_map"; view._update_camera()
	check(not view.perceptual_depth.root.visible and not view.snow_renderer.depth_detail_enabled, "Piste atlas remains clear and orthographic")
	free_orphans(view, {})
	parent.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
