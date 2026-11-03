extends SceneTree
const Styles = preload("res://src/core/visual_styles.gd")
const Preferences = preload("res://src/core/preferences.gd")

var passed := 0
var failed := 0
var game: Node

func _init() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS ", description)
	else:
		failed += 1
		push_error("FAIL " + description)

func capture_style(style_id: String) -> void:
	# Visual release evidence uses the same 3D world and UI, not palette
	# swatches; capture after the renderer has presented the new materials.
	if DisplayServer.get_name() == "headless":
		return
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://build/qa")
	var created := DirAccess.make_dir_recursive_absolute(directory)
	if created != OK:
		check(false, "QA screenshot directory for " + style_id)
		return
	var file_path := directory.path_join("visual-021-" + style_id + ".png")
	var snapshot: Image = root.get_texture().get_image()
	check(snapshot != null and snapshot.get_width() >= 1200 and snapshot.get_height() >= 700 and snapshot.save_png(file_path) == OK, "Full-scene screenshot captured for " + style_id)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(false)
	# Synchronize the view after the new resort replaces the bootstrap model.
	# Otherwise the first style swap also performs the outstanding terrain rebuild.
	game.view.rebuild()
	# Use a low panoramic angle and a wide, unobstructed mountain view.
	# The QA snapshots must reveal real terrain and forest differences rather
	# than five near-identical overhead shots of the HUD.
	game.view.set_camera_mode(1)
	game.view.focus = Vector2(40, -120)
	game.view.zoom = 465.0
	game.view._update_camera()
	game.hud.set_map_focus(true)
	game.paused = true
	game.set_process(false)
	game.view.set_process(false)
	var preferences: RefCounted = game.preferences
	preferences.path = "user://021-visual-settings-test.cfg"
	var height_before: float = game.model.terrain.height(Vector2(240, -150))
	var map_before: String = game.model.map_id
	var revision_before: int = game.model.revision
	var original_vertices: PackedVector3Array = game.view.terrain_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
	var original_assets: Array = game.view.asset_root.get_children().duplicate()
	var original_forest_nodes: Array = game.view.forest.root.get_children().duplicate()
	var original_surface_picker: RefCounted = game.view.surface_picker
	var alpine_color: Color = game.view._ground_color(Vector2(300, -150), 400.0, 65.0)
	check(Styles.IDS.size() == 6 and game.hud.display_options.style_choice.item_count == 6, "Six selectable styles are offered in the real graphics screen")
	check(Styles.valid("not-a-style") == "alpine", "Unknown saved style falls back to classic alpine")
	var distinct: Dictionary = {}
	var distinct_foliage: Dictionary = {}
	var distinct_tree_shapes: Dictionary = {}
	for id in Styles.IDS:
		preferences.visual_style = id
		preferences.apply(game.view)
		var sample: Color = game.view._ground_color(Vector2(300, -150), 400.0, 65.0)
		distinct[str(sample)] = true
		if not game.view.forest.groups.is_empty():
			distinct_foliage[str(game.view.forest.groups[0].node.multimesh.get_instance_color(0))] = true
			var tree_mesh: Mesh = game.view.forest.groups[0].node.multimesh.mesh
			distinct_tree_shapes[str(tree_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])] = true
		check(game.view.visual_style == id and game.view.terrain_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == original_vertices, "%s changes presentation while retaining rendered terrain geometry" % id)
		await capture_style(id)
	check(distinct.size() == Styles.IDS.size(), "All six styles produce different snow and rock colors")
	check(distinct_foliage.size() == Styles.IDS.size(), "All six art directions visibly recolor existing trees without regenerating the forest")
	check(distinct_tree_shapes.size() == Styles.IDS.size(), "All five art directions use different modeled tree silhouettes rather than the same recolored pine")
	check(game.view.asset_root.get_children() == original_assets and game.view.forest.root.get_children() == original_forest_nodes and game.view.surface_picker == original_surface_picker, "Visual style changes preserve rendered assets, forest node identities and terrain picking without resort rebuild")
	preferences.visual_style = "alpine"
	preferences.apply(game.view)
	game.hud.display_options.open()
	var preview_index: int = Styles.IDS.find("comic")
	game.hud.display_options.style_choice.select(preview_index)
	game.hud.display_options.style_choice.item_selected.emit(preview_index)
	check(game.view.visual_style == "comic" and preferences.visual_style == "alpine", "Settings show an immediate temporary comic preview without changing saved preferences")
	game.hud.display_options.hide()
	check(game.view.visual_style == "alpine" and preferences.visual_style == "alpine", "Backing out of graphics settings restores the original look")
	check(game.model.map_id == map_before and is_equal_approx(game.model.terrain.height(Vector2(240, -150)), height_before) and game.model.revision == revision_before, "Switching styles does not change the mountain or game state")
	preferences.visual_style = "cinematic"
	check(preferences.save_to() == OK, "Visual style can be saved to display settings")
	var loaded := Preferences.new()
	loaded.path = preferences.path
	loaded.load_from()
	check(loaded.visual_style == "cinematic", "Visual style persists across settings reload")
	loaded.visual_style = "invalid"
	loaded.apply(game.view)
	check(game.view.visual_style == "alpine", "Invalid style cannot break the renderer")
	check(game.view._ground_color(Vector2(300, -150), 400.0, 65.0).is_equal_approx(alpine_color), "Returning to classic restores its terrain palette")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(preferences.path))
	game.queue_free()
	await process_frame
	await process_frame
	print("SCENE: %d passed; %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
