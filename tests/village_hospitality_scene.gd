extends SceneTree
const Hospitality = preload("res://src/core/hospitality.gd")
var passed := 0
var failed := 0

func check(value: bool, message: String) -> void:
	if value: passed += 1; print("PASS ", message)
	else: failed += 1; push_error("FAIL " + message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.set_process(false)
	game.view.set_process(false)
	game.model.campaign.mode = "free"
	game.model.money = 1000000.0
	var placed := {}
	for kind in ["pizzeria", "hotel", "cabin"]:
		for z in range(180, 390, 34):
			for x in range(80, 430, 34):
				if game.model.build_building(kind, Vector2(x, z)).ok:
					placed[kind] = game.model.buildings[-1].id
					break
			if placed.has(kind): break
	check(placed.size() == 3, "Actual village lots support pizzeria, hotel and cabin")
	if placed.size() != 3:
		print("RESULT: %d passed; %d failed" % [passed, failed]); quit(1); return
	game.paused = false
	var experience: Control = game.hud.experience
	experience.open(int(placed.pizzeria))
	await process_frame
	check(experience.visible and game.paused and not game.simulation_running(), "Building visit pauses the resort clock")
	check(game.hud.blocks_map(Vector2(5, 5)), "The entire building overlay blocks map construction and camera gestures")
	check(experience.tabs.get_tab_count() == 3 and experience._recipe_names.size() == 3, "Pizzeria shows three editable recipes, activity and operations tabs")
	experience._recipe_names[0].text = "KoSch Pizza"
	experience._start_shift()
	check(experience.task.mode == "pizza", "Pizzeria activity uses the actual pizza topping mechanic")
	for index in range(5): experience._submit(experience.task.toppings.duplicate())
	check(experience.session.finished, "Five real UI submissions complete the shift")
	experience.close()
	check(not game.paused, "Leaving a building restores the previous running state")
	experience.open(int(placed.hotel))
	await process_frame
	check(experience.tabs.get_tab_count() == 5, "Hotel exposes management, rooms, chains, game and staffing")
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://build/qa/hotel-management-022.png")
	experience.close()
	experience.open(int(placed.pizzeria))
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://build/qa/pizza-workshop-022.png")
	game.paused = true
	experience.close()
	game.paused = true
	experience.open(int(placed.cabin))
	experience.close()
	check(game.paused, "An already paused resort stays paused after a cabin visit")
	game.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
