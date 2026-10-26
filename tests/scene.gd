extends SceneTree
## Integration checks use the real scene, projection and input handlers.

const Terrain = preload("res://src/core/terrain.gd")
var game: Node
var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func touch(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	game._input(event)

func drag(index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = relative
	game._input(event)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	check(game.hud.menu.visible and not game.has_game, "Main menu opens before the simulation starts")
	var clock: int = game.model.minute
	game._process(1.0)
	check(game.model.minute == clock, "Opening menu does not advance simulation time")
	game.start_game(true)
	game.paused = true
	await process_frame
	check(not game.hud.menu.visible and game.has_game, "Starting a scenario opens the map and HUD")
	var map_position := Vector2(740, 390)
	check(not game.hud.blocks_map(map_position), "Map has a usable input region between the panels")
	var hit: Vector2 = game.view.map_point(map_position)
	var roundtrip: Vector2 = game.view.camera.unproject_position(Terrain.world(hit))
	check(Terrain.contains(hit) and roundtrip.distance_to(map_position) < 1.0, "Camera-to-terrain picking roundtrips within one pixel")
	var blue_button_position: Vector2 = game.hud.tool_buttons.blue.get_global_rect().get_center()
	var ui_touch := InputEventScreenTouch.new()
	# Input.parse_input_event expects window pixels; the headless window is 64x64.
	ui_touch.position = root.get_screen_transform() * blue_button_position
	ui_touch.index = 0
	ui_touch.pressed = true
	Input.parse_input_event(ui_touch)
	await process_frame
	ui_touch.pressed = false
	Input.parse_input_event(ui_touch)
	await process_frame
	check(game.tool == "blue", "Actual Godot touch-to-mouse emulation activates a GUI build button")
	touch(0, map_position, true)
	touch(0, map_position, false)
	check(game.points.size() == 1, "A single map tap adds exactly one waypoint")
	var synthetic := InputEventMouseButton.new()
	synthetic.device = InputEvent.DEVICE_ID_EMULATION
	synthetic.position = map_position
	synthetic.button_index = MOUSE_BUTTON_LEFT
	synthetic.pressed = true
	game._input(synthetic)
	synthetic.pressed = false
	game._input(synthetic)
	check(game.points.size() == 1, "Emulated mouse events cannot duplicate a touch waypoint")
	touch(0, Vector2(750, 410), true)
	touch(1, Vector2(850, 410), true)
	var zoom: float = game.view.zoom
	drag(1, Vector2(900, 410), Vector2(50, 0))
	touch(1, Vector2(900, 410), false)
	touch(0, Vector2(750, 410), false)
	check(game.view.zoom < zoom and game.points.size() == 1, "Pinch zoom changes the camera without committing a waypoint")
	check(game._touches.is_empty(), "Released pinch contacts do not remain active")
	touch(0, map_position, true)
	touch(0, map_position, false, true)
	check(game.points.size() == 1 and game._touches.is_empty(), "Canceled touches neither build nor remain active")
	var focus: Vector2 = game.view.focus
	touch(0, map_position, true)
	drag(0, map_position + Vector2(70, 20), Vector2(70, 20))
	touch(0, map_position + Vector2(70, 20), false)
	check(game.view.focus != focus and game.points.size() == 1, "Dragging the map keeps the current build plan intact")
	var ui_position: Vector2 = game.hud.tool_buttons.blue.get_global_rect().get_center()
	touch(0, ui_position, true)
	touch(0, ui_position, false)
	check(game.points.size() == 1, "Touches over UI panels cannot place map objects")
	game.points = [[245, -130], [305, 0], [200, 205]]
	game._update_plan()
	check(not game.hud.confirm_button.disabled, "Valid affordable build plans can be confirmed")
	var count: int = game.model.pistes.size()
	var balance: float = game.model.money
	game.confirm_plan()
	check(game.model.pistes.size() == count + 1 and game.model.money < balance and game.points.is_empty(), "Build confirmation creates the piste and charges its displayed cost")
	game.points = [[-170, -235], [-160, -50], [-80, 90], [100, 190]]
	game._update_plan()
	check(game.hud.confirm_button.disabled, "Steep blue plans stay blocked in the real HUD")
	game.set_tool("inspect")
	game.show_menu()
	check(game.hud.blocks_map(map_position), "Main menu blocks world input")
	game.continue_game()
	check(not game.hud.menu.visible and game.model.pistes.size() == count + 1, "Continue preserves the current unsaved resort")
	game.hud.show_help()
	check(game.hud.blocks_map(map_position), "Help dialog blocks world input")
	game.hud.help_dialog.hide()
	var bounds := root.get_visible_rect()
	var inside := true
	for button in game.hud.tool_buttons.values():
		inside = inside and bounds.encloses(button.get_global_rect())
	check(inside, "Every build tool remains within the viewport")
	# Release the complete scene before checking process exit, including its fonts.
	game.queue_free()
	await process_frame
	await process_frame
	print("SCENE RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
