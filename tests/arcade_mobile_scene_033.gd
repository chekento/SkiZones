extends SceneTree
## Real phone-sized building navigation and screen-touch input, not direct
## signal emission. Playing never changes the resort's economy or save.
const L = preload("res://src/core/i18n.gd")
const Board = preload("res://src/ui/tic_tac_toe_board.gd")
var passed := 0
var failed := 0
var game: Node

func _init() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)
func settle() -> void:
	for frame in range(5): await process_frame
func inside(control: Control) -> bool:
	return root.get_visible_rect().grow(1).encloses(control.get_global_rect())
func tap(control: Control) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await settle()
func capture(stem: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	check(root.get_texture().get_image().save_png("res://build/qa/" + stem + ".png") == OK, "Captured " + stem)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.set_process(false)
	game.view.set_process(false)
	game.preferences.path = "user://arcade-033-test.cfg"
	game.hud.achievement_overlay.hide()
	game.hud.achievement_overlay.set_process(false)
	var lodge: Dictionary = game.model.buildings.filter(func(b): return b.kind == "lodge")[0]
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	for language in ["de", "en"]:
		game.apply_language(language)
		for dims in [Vector2i(360,740), Vector2i(420,860), Vector2i(740,360)]:
			root.size = dims
			await settle()
			game.hud.hide_menu()
			game.preferences.visual_style = "monochrome" if dims.x == 360 else "cinematic"
			game.paused = false
			var saved: String = JSON.stringify(game.model.snapshot())
			var experience: Control = game.hud.experience
			experience.open(int(lodge.id))
			for index in range(experience.tabs.get_tab_count()):
				if experience.tabs.get_tab_title(index) == L.text("Spielecke"):
					experience.tabs.current_tab = index
			await settle()
			var buttons: Array = experience.find_children("square_*", "Button", true, false)
			check(buttons.size() == 9, "%s %s: lodge unlocks a genuine nine-square game" % [language, str(dims)])
			var surface := experience.find_child("arcade_surface", true, false) as PanelContainer
			var title := experience.find_child("arcade_title", true, false) as Label
			var instructions := experience.find_child("arcade_instructions", true, false) as Label
			var score := experience.find_child("arcade_score", true, false) as Label
			check(surface != null and title != null and instructions != null and score != null,
				"%s %s: arcade presents a complete themed text surface" % [language, str(dims)])
			if surface != null and title != null and instructions != null and score != null:
				var backdrop := surface.get_theme_stylebox("panel") as StyleBoxFlat
				if backdrop != null:
					for label in [title,instructions,score]:
						check(Board.contrast_ratio(label.get_theme_color("font_color"), backdrop.bg_color) >= 4.5,
							"%s %s: %s is legible above its real backdrop" % [language,str(dims),label.name])
					check(surface.get_global_rect().grow(1).encloses(title.get_global_rect())
						and surface.get_global_rect().grow(1).encloses(instructions.get_global_rect()),
						"%s %s: title and instructions stay inside the painted panel" % [language,str(dims)])
			check(inside(experience.window.close_button), "%s %s: close action stays on screen" % [language, str(dims)])
			if buttons.size() == 9:
				var page: ScrollContainer = experience.tabs.get_current_tab_control()
				page.ensure_control_visible(buttons[0])
				await settle()
				check(inside(buttons[0]) and buttons[0].size.x >= 70, "%s %s: first square has a visible phone-sized target" % [language, str(dims)])
				await tap(buttons[0])
				check(buttons[0].text == "✕" and buttons[0].disabled and buttons.filter(func(b): return not b.text.is_empty()).size() == 2, "%s %s: real finger tap plays X and receives a legal computer reply" % [language, str(dims)])
			check(game.paused and not game.simulation_running(), "Building game pauses resort time")
			check(JSON.stringify(game.model.snapshot()) == saved, "Playing changes no money, guests, routes or saved career data")
			await capture("arcade-033-%s-%dx%d" % [language, dims.x, dims.y])
			game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
			check(not experience.visible and not game.paused, "Android Back closes the game and restores running state")
		game.model.operations.pending_arrivals = 8
		game.hud.management.open()
		await settle()
		var interest: Label = game.hud.management.find_child("morning_interest", true, false)
		check(interest != null and interest.text == L.text("Morgeninteresse: %d · Ankünfte 08–10 Uhr nach freien Plätzen. Noch keine Gäste oder Einnahmen.") % 8, "%s: operations page shows actual interest and its capacity limit" % language)
		game.hud.management.hide()
	game.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
