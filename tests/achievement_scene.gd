extends SceneTree
const Styles = preload("res://src/core/visual_styles.gd")
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
		"Embossed achievement popup never blocks finger interactions")
	for style_id in ["alpine","comic","pastel","cinematic","crisp"]:
		display.set_visual_style(style_id)
		check(display.style_id == style_id,"Achievement display follows the chosen theme: " + style_id)
	check(float(Styles.ui_palette("comic").letter_arc) < 0.2,"Reward lettering uses a subtle baseline instead of the original half-circle")
	display.announce({"kind":"achievement","title":"SCHWUNG FÜR SCHWUNG · 08","detail":"250 Abfahrten","reward":1350})
	check(display.visible and display.is_processing() and display.active.title.begins_with("SCHWUNG"),
		"A large, readable achievement popup starts immediately")
	display.announce({"kind":"rank","title":"MEISTERSCHAFTSRANG 45 / 500","detail":"+5 Ränge","reward":0})
	check(display.waiting.size() == 1,"A second milestone queues without overlapping the first")
	await process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://build/qa")
	DirAccess.make_dir_recursive_absolute(folder)
	var saved: Error = root.get_texture().get_image().save_png(folder.path_join("achievement-024-raised-hud.png"))
	check(saved == OK,"Embossed themed achievement UI has a rendered resort screenshot")
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
