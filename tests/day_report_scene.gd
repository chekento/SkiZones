extends SceneTree
const Main = preload("res://src/main.gd")
var passed := 0
var failed := 0
func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var game := Main.new()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.paused = true
	game.model.minute = game.model.CLOSING - 1
	game.model.advance_minute(false)
	game.hud.show_report()
	await process_frame
	await process_frame
	var dialog: Control = game.hud.daily_dialog
	check(dialog.visible and dialog.is_visible_in_tree() and not dialog.is_class("Window"), "The day report is a visible in-scene modal, never an Android subwindow")
	check(dialog.body.get_parsed_text().contains("Tageskarten:") and dialog.body.get_parsed_text().contains("Betriebskosten:") and dialog.body.get_parsed_text().contains("Ergebnis nach Investitionen:"), "The actual report renders all daily finance fields")
	check(dialog.body.size.x > 200 and dialog.body.size.y > 200 and dialog.body.get_theme_color("default_color").a > 0.9, "The report has laid-out, opaque readable text rather than an empty gray rectangle")
	check(game.hud.blocks_map(Vector2(5,5)) and not game.simulation_running(), "The day report blocks map actions and simulation behind it")
	for viewport_size in [Vector2i(1536,710), Vector2i(1280,800), Vector2i(960,540)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await process_frame
		await process_frame
		var bounds: Rect2 = dialog.get_global_rect()
		check(bounds.encloses(dialog.panel.get_global_rect()) and bounds.encloses(dialog.next_button.get_global_rect()), "Report and next-day button fit landscape viewport %s" % viewport_size)
		check(dialog.scroll.size.y > 80 and dialog.body.size.y > dialog.scroll.size.y, "Long report scrolls while its next-day button stays visible at %s" % viewport_size)
		# Test genuine touch scrolling through the report body.
		var point: Vector2 = dialog.scroll.get_global_rect().get_center()
		var touch := InputEventScreenTouch.new(); touch.index=0; touch.position=point; touch.pressed=true
		Input.parse_input_event(touch)
		await process_frame
		var drag := InputEventScreenDrag.new();drag.index=0;drag.position=point-Vector2(0,100);drag.relative=Vector2(0,-100)
		Input.parse_input_event(drag)
		await process_frame
		touch.pressed=false;touch.position=drag.position;Input.parse_input_event(touch)
		await process_frame
		check(dialog.scroll.scroll_vertical > 0, "Finger drag scrolls the real daily report at %s" % viewport_size)
	# Capture actual renderer output in CI; headless layout runs skip only the image.
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://build/qa")
		root.get_texture().get_image().save_png("res://build/qa/day-report-080.png")
	await create_timer(0.15).timeout
	var day: int = game.model.day
	dialog.next_button.pressed.emit()
	await process_frame
	check(game.model.day == day+1 and not dialog.visible, "The visible next-day button advances one morning and dismisses the report")
	game.model.minute = game.model.CLOSING
	game.model.last_report.clear()
	game.paused = false
	check(game.simulation_running(), "Closing-time return journeys keep running instead of freezing at 18:00")
	game.queue_free()
	await process_frame
	print("DAY REPORT SCENE: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
