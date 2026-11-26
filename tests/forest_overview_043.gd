extends SceneTree
const Forest = preload("res://src/world/forest_lod.gd")
var failed := 0
var passed := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	if ok:
		passed += 1
		print("PASS ", detail)
	else:
		failed += 1
		push_error("FAIL " + detail)

func run() -> void:
	for tier in range(3):
		var last := 1.0
		for zoom in [48.0, 620.0, 1000.0, 1800.0, 3400.0, 12000.0]:
			var density := Forest.overview_density(zoom, tier)
			check(density > 0.0 and density <= last, "Density bounded and monotonic at tier %d zoom %.0f" % [tier, zoom])
			last = density
			check(Forest.visible_tree_count(1, zoom, tier) == 1, "Singleton forest group never disappears")
		check(Forest.visible_tree_count(0, 620.0, tier) == 0, "Empty group stays empty")
		check(Forest.visible_tree_count(100, 12000.0, tier) < Forest.visible_tree_count(100, 620.0, tier), "Wide view reduces instance count")
	var forest := Forest.new()
	var node := MultiMeshInstance3D.new()
	var mesh := MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.mesh = BoxMesh.new()
	mesh.instance_count = 100
	node.multimesh = mesh
	root.add_child(node)
	forest.groups = [{"node": node, "center": Vector2.ZERO, "detail": false, "species": 0}]
	forest.update(Vector2.ZERO, 12000.0, 1)
	check(node.visible and mesh.visible_instance_count == 50, "Actual wide view uses medium density budget")
	forest.update(Vector2.ZERO, 900.0, 1)
	check(mesh.visible_instance_count == 100, "Zooming in restores every instance")
	forest.update(Vector2(10000, 10000), 900.0, 1)
	check(not node.visible, "Far chunks are culled")
	forest.update(Vector2.ZERO, 900.0, 0)
	check(node.visible and mesh.visible_instance_count == 65, "Returning chunk adopts the current quality tier")
	check(mesh.instance_count == 100, "Rendering never deletes forest transforms")
	node.free()
	forest.root.free()
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
