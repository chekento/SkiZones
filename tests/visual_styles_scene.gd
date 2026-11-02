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

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(false)
	# Synchronize the view after the new resort replaces the bootstrap model.
	# Otherwise the first style swap also performs the outstanding terrain rebuild.
	game.view.rebuild()
	game.paused = true
	game.set_process(false)
	game.view.set_process(false)
	var preferences: RefCounted = game.preferences
	preferences.path = "user://021-visual-settings-test.cfg"
	var height_before: float = game.model.terrain.height(Vector2(240, -150))
	var map_before: String = game.model.map_id
	var revision_before: int = game.model.revision
	var original_vertices: PackedVector3Array = game.view.terrain_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
	var alpine_color: Color = game.view._ground_color(Vector2(300, -150), 400.0, 65.0)
	check(Styles.IDS.size() == 5 and game.hud.display_options.style_choice.item_count == 5, "Five selectable styles are offered in the real graphics screen")
	check(Styles.valid("not-a-style") == "alpine", "Unknown saved style falls back to classic alpine")
	var distinct: Dictionary = {}
	for id in Styles.IDS:
		preferences.visual_style = id
		preferences.apply(game.view)
		var sample: Color = game.view._ground_color(Vector2(300, -150), 400.0, 65.0)
		distinct[str(sample)] = true
		check(game.view.visual_style == id and game.view.terrain_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == original_vertices, "%s changes presentation while retaining rendered terrain geometry" % id)
	check(distinct.size() == Styles.IDS.size(), "All five styles produce different snow and rock colors")
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
