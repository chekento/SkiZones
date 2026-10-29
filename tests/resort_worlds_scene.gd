extends SceneTree
const Maps = preload("res://src/core/maps.gd")
const Terrain = preload("res://src/core/terrain.gd")
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)
func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/" + name + ".png")
func run() -> void:
	create_timer(160).timeout.connect(func(): quit(1))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for id in Maps.MAPS:
		game.start_game(true, id)
		game.paused = true
		await process_frame
		await process_frame
		check(game.view._terrain_id == id and game.view.terrain.generation == 2 and game.model.routes_for(0).size() == 1, id + " renders its own playable start")
		game.hud.set_map_focus(true)
		game.view.focus = Vector2(0, -Maps.spec(id).bounds.size.y * 0.36)
		game.view.zoom = Maps.spec(id).bounds.size.x * 0.92
		game.view.yaw = 0.25
		game.view.set_camera_pitch(42)
		await capture("resort-" + id + "-0130")
	game.start_game(false)
	game.model.money = 1000000
	game.hud.building_choice.select(game.model.Catalog.BUILDINGS.keys().find("restaurant"))
	game.set_tool("building")
	game.points = [[70, 243]]
	game.edit_rotation = game.model.building_orientation("restaurant", Vector2(70, 243))
	game._update_plan()
	check(game.hud.rotate_building_button.visible and game.last_plan_check.rotation == game.edit_rotation and game.last_plan_check.ok, "The new building preview exposes a valid street-facing entrance")
	var old: int = game.edit_rotation
	game.hud.rotate_building_button.pressed.emit()
	check(game.edit_rotation == (old + 1) % 4 and game.last_plan_check.rotation == game.edit_rotation and game.model.buildings.is_empty(), "The real entrance button rotates the preview without spending or building")
	game.hud.rotate_building_button.pressed.emit()
	game.hud.rotate_building_button.pressed.emit()
	game.hud.rotate_building_button.pressed.emit()
	game.confirm_plan()
	check(game.model.buildings.size() == 1 and game.model.buildings[0].rotation == old, "Confirmation retains the chosen entrance orientation in the live chalet")
	game.start_game(true)
	game._showcase()
	game.paused = true
	game.hud.set_map_focus(true)
	game.view.focus = Vector2(65, 235)
	game.view.zoom = 440
	game.view.yaw = 0.38
	game.view.set_camera_pitch(42)
	await process_frame
	await capture("village-promenade-0130")
	check(game.view.piste_furniture.any(func(node): return node.has_meta("village_detail")) and game.view.piste_furniture.size() < 80, "Village planters and lanterns remain bounded and visible")
	var clear := true
	for instance in game.view.piste_furniture:
		for vertex in instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var at: Vector3 = instance.transform * vertex
			clear = clear and game.view.piste_clear(Vector2(at.x, at.z))
	check(clear, "All new street furniture vertices stay outside actual full-width pistes")
	game.apply_language("en")
	game.hud.atlas.open()
	await capture("resort-pass-en-0130")
	check(game.hud.atlas._cards.size() == 8 and game.hud.atlas.visible, "The real bilingual mountain pass presents all eight resort cards")
	game.queue_free()
	await process_frame
	print("WORLDS SCENE: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
