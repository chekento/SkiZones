extends SceneTree
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ",label)
	else:
		failed += 1
		push_error("FAIL "+label)
func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.view.rebuild()
	game.paused = true
	var display: Control = game.hud.achievement_overlay
	check(display.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Curved achievement popup never blocks finger interactions")
	display.announce({"kind":"achievement","title":"SCHWUNG FÜR SCHWUNG · 08","detail":"250 Abfahrten","reward":1350})
	check(display.visible and display.is_processing() and display.active.title.begins_with("SCHWUNG"),
		"A large, curved achievement popup starts immediately")
	display.announce({"kind":"rank","title":"MEISTERSCHAFTSRANG 45 / 500","detail":"+5 Ränge","reward":0})
	check(display.waiting.size() == 1,"A second milestone queues without overlapping the first")
	await process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://build/qa")
	DirAccess.make_dir_recursive_absolute(folder)
	var saved: Error = root.get_texture().get_image().save_png(folder.path_join("achievement-022-curved-hud.png"))
	check(saved == OK,"Curved translucent achievement UI can be reviewed from a real rendered resort screenshot")
	display._process(display.DISPLAY_SECONDS+0.1)
	check(display.active.kind == "rank" and display.visible,
		"A queued mastery rank animates after the preceding achievement")
	display._process(display.DISPLAY_SECONDS+0.1)
	check(display.active.is_empty() and not display.visible,
		"Popup ends cleanly and releases HUD rendering work")
	game.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
