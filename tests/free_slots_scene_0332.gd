extends SceneTree
## Real free-build menu and header save-button regression (rendered Godot).
const Saves = preload("res://src/core/save_store.gd")
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1;print("PASS ",label)
	else: failed += 1;push_error("FAIL "+label)

func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test"):
		push_error("Use isolated skizones-test data directory")
		quit(1)
		return
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.view.set_process(false)
	game.hud.career_slots.open_free()
	check(game.hud.career_slots.free_mode and game.hud.career_slots.cards.get_child_count() == 4, "Free build opens a real four-slot UI")
	check(game.hud.career_slots.heading_label.text.contains("FREIEN"), "Free build does not show a career-only heading")
	game.select_free_slot(2,true)
	await process_frame
	check(game.has_game and Saves.active_slot == 0 and Saves.active_free_slot == 2 and game.model.campaign.mode == "free", "Starting free slot 2 opens a playable unrestricted game")
	check(not game.hud.menu.visible and not game.hud.career_slots.visible and game.view.terrain == game.model.terrain, "Fresh free build regenerates the correct mountain and leaves menus")
	check(Saves._read(Saves.path_for_map("sonnenhang",0,2)).ok, "New free-build game immediately writes its own loadable save")
	game.hud.refresh()
	check(game.hud.header_save_button.modulate == Color("4aa897") and not game.hud.header_save_button.disabled, "Saved state is visibly green")
	game.model.money += 100
	game.hud.refresh()
	check(game.hud.header_save_button.modulate == Color("e4a548"), "Unsaved game-state changes visibly turn the button amber")
	check(game.save_game() and game.hud.header_save_button.modulate == Color("4aa897"), "Successful save immediately returns the button to saved green")
	game._save_failed = true
	game.hud.refresh()
	check(game.hud.header_save_button.modulate == Color("d65a4c"), "A failed save is visibly red rather than falsely claiming success")
	game._save_failed = false
	game.hud._update_responsive_layout(380)
	game.hud.refresh()
	check(game.hud.header_save_button.text == "✓" and not game.hud.header_save_button.tooltip_text.is_empty(), "Phone-sized save indicator remains readable with explanatory tooltip")
	var free_path: String = Saves.path_for_map("sonnenhang",0,2)
	game.queue_free()
	await process_frame
	for path in [free_path,free_path+".bak",Saves.index_path(0,2),Saves.passport_path(0,2),"user://app-session.json","user://display.cfg"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
