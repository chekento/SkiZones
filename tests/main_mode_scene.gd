extends SceneTree
## Main-mode release gate: career/free build only; old scenarios remain archived.
const Maps = preload("res://src/core/maps.gd")
const Saves = preload("res://src/core/save_store.gd")
var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func collect_buttons(node: Node) -> Array:
	var result: Array = []
	if node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(collect_buttons(child))
	return result

func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.view.set_process(false)
	var labels: Array = collect_buttons(game.hud.menu).map(func(button): return button.text)
	check(not Maps.SCENARIOS_ENABLED, "Real scenarios are disabled for this release")
	check(not game.hud.scenarios.visible and game.hud.scenarios.get_parent() == null, "Scenario selection is neither built nor shown")
	check(not labels.has("Szenarien · echte Skigebiete") and labels.has("Karriere · vier Spielstände") and labels.has("Freier Aufbau · alle Anlagen"), "Normal career and free build remain the only play modes")
	var original_map: String = game.model.map_id
	var old_path: String = Saves.path_for_map("braunlage")
	await game.enter_area("braunlage")
	check(game.model.map_id == original_map and not game.has_game, "Disabled scenario selection cannot replace a main game")
	check(Saves.path_for_map("braunlage") == old_path, "Historical scenario save path is preserved")
	game.start_game(true)
	game.paused = true
	check(game.has_game and game.model.map_id == "sonnenhang" and not game.hud.menu.visible, "Normal career opens unchanged")
	game.show_menu()
	game.continue_main_game()
	check(game.has_game and not game.hud.menu.visible and game.model.map_id == "sonnenhang", "Continue returns to same normal mountain")
	game.queue_free()
	await process_frame
	print("MAIN MODE: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
