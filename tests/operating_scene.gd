extends SceneTree
const L = preload("res://src/core/i18n.gd")
const Ops = preload("res://src/core/operations.gd")
var game: Node
var passed := 0
var failed := 0
func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		push_error("FAIL " + message)
func _init() -> void:
	call_deferred("run")
func capture(name_value: String) -> void:
	game.hud.refresh()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/" + name_value + ".png")
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.hud.scenarios.open()
	await capture("real-scenarios-0140")
	check(game.hud.scenarios.visible, "main menu opens four real scenario cards")
	await game.enter_area("braunlage")
	game.paused = true
	await process_frame
	check(not game.hud.scenarios.visible and game.model.operations.scenario == "braunlage", "scenario starts through the actual controller")
	game.view.focus = Vector2(220, -900)
	game.view.zoom = 2900
	game.view._update_camera()
	await capture("braunlage-terrain-0140")
	check(game.view.terrain.height(Vector2(185, 230)) > 500, "rendered map uses real Wurmberg elevations")
	game.hud.management.open()
	game.hud.management.tabs.current_tab = 5
	await capture("operations-office-0140")
	check(game.hud.management.tabs.get_tab_count() == 9, "staffing, maintenance, rescue and cost-centre pages are reachable")
	game.hud.management.hide()
	game.model.minute = 1320
	Ops.tick(game.model)
	game.view._update_atmosphere()
	await capture("real-resort-night-0140")
	check(game.view._sun.light_energy < 0.2, "the continuous clock produces a night scene")
	var old_model: RefCounted = game.model
	var staff_count: int = game.model.operations.staff.size()
	game.show_menu()
	game.apply_language("en")
	await process_frame
	check(game.model == old_model and game.model.operations.staff.size() == staff_count and game.model.minute == 1320, "live language change preserves the populated operating model")
	await capture("en-main-menu-0140")
	game.hud.display_options.open()
	await capture("en-settings-0140")
	check(game.hud.display_options.language_choice.item_count == 3, "main-menu settings expose system, German and English")
	game.hud.display_options.hide()
	game.hud.credits.popup_centered(Vector2i(840, 560))
	await capture("en-data-credits-0140")
	check(game.hud.credits.visible, "main-menu credits are reachable")
	game.hud.credits.hide()
	# A visible pool visitor must follow the real walking / booking system.
	game.start_game(false)
	var pool: Dictionary = {}
	for z in range(250, 340, 30):
		if not pool.is_empty(): break
		for x in range(90, 300, 35):
			if game.model.build_building("pool", Vector2(x, z)).ok:
				pool = game.model.buildings[-1]
				break
	check(not pool.is_empty(), "an outdoor pool has a valid complete footprint")
	if not pool.is_empty():
		Ops.fill_building(game.model, int(pool.id))
		game.model.minute = 1200
		Ops.tick(game.model)
		for i in range(4): Ops.admit_evening(game.model)
		for i in range(120):
			if game.model.guests.any(func(g): return g.phase != "leaving" and g.route.legs[g.leg].kind == "visit"): break
			game.model.advance_minute(false)
		game.view.focus = Vector2(pool.point[0], pool.point[1])
		game.view.zoom = 105
		game.view.set_camera_mode(1)
		game.view._update_camera()
		game.hud.set_map_focus(true)
		await capture("en-evening-pool-0140")
		check(game.view._swimmers.multimesh.visible_instance_count > 0, "actual booked visitors swim visibly in the pool")
		check(game.hud.plan_text.text.contains("midnight"), "the evening HUD describes continuous operations and automatic midnight accounts")
	game.queue_free()
	await process_frame
	print("OPERATIONS SCENE: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
