extends SceneTree
## Main-mode release gate: career stays primary; optional scenarios remain separate.
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
	check(Maps.SCENARIOS_ENABLED, "Real scenarios are restored as an optional mode")
	check(not game.hud.scenarios.visible and game.hud.scenarios.get_parent() != null, "Scenario selection is available without covering the main menu")
	check(labels.has("Szenarien · vier echte Skigebiete") and labels.find("Karriere · vier Spielstände") < labels.find("Szenarien · vier echte Skigebiete") and labels.has("Freier Aufbau · alle Anlagen"), "Career and free build stay above optional real scenarios")
	var original_map: String = game.model.map_id
	var old_path: String = Saves.path_for_map("braunlage")
	await game.enter_area("not-a-resort")
	check(game.model.map_id == original_map and not game.has_game, "An invalid area cannot replace the main game")
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
