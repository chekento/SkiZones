extends SceneTree
const Terrain = preload("res://src/core/terrain.gd")
var game: Node
var passed := 0
var failed := 0

func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)

func screen(point: Vector2) -> Vector2:
	return game.view.camera.unproject_position(game.view.surface_position(point))

func touch(at: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0; event.position = at; event.pressed = pressed; event.canceled = canceled
	game._input(event)

func move(at: Vector2, delta: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0; event.position = at; event.relative = delta
	game._input(event)

func capture(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	image.save_png("res://build/qa/" + name + ".png")
	return image

func run() -> void:
	create_timer(160).timeout.connect(func(): quit(1))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.paused = true
	game.set_process(false)
	game.set_tool("piste")
	game.hud.set_map_focus(true)
	# Reproduce a landscape phone's camera cutout/status-bar insets on desktop.
	game.hud.root.offset_left = 88
	game.hud.root.offset_top = 32
	game.hud.root.offset_right = -24
	game.hud.root.offset_bottom = -18
	await process_frame
	var target := Vector2(310, -40)
	var exact_clicks := true
	var exact_draws := true
	for mode in range(4):
		game.points.clear()
		game.selected_waypoint = -1
		game.view.focus = target
		game.view.zoom = 125
		game.view.yaw = [0.6, 1.8, -1.1, 2.7][mode]
		game.view.set_camera_mode(mode)
		game._update_plan()
		var at := screen(target)
		touch(at, true); touch(at, false)
		exact_clicks = exact_clicks and game.points.size() == 1 and Terrain.unpack(game.points[0]).distance_to(target) < 0.03
		var handles: Array = game.hud.plan_overlay.displayed_waypoints()
		if handles.size() != 1:
			exact_draws = false
			continue
		var local: Vector2 = game.hud.plan_overlay.local_screen(handles[0].at)
		var actual: Vector2 = game.hud.plan_overlay.get_global_transform_with_canvas() * local
		exact_draws = exact_draws and actual.distance_to(at) < 0.03 and local.distance_to(at) > 80
	check(exact_clicks, "Touch placement stays under the finger in all camera modes with asymmetric phone safe-area insets")
	check(exact_draws, "Drawn waypoint centres undo the canvas inset exactly once")
	var image := await capture("piste-touch-insets-0142")
	var at := screen(target)
	var pixel := Vector2i((at + Vector2(-5, -4)) * Vector2(image.get_size()) / root.get_visible_rect().size)
	var drawn := image.get_pixelv(pixel)
	check(Vector3(drawn.r, drawn.g, drawn.b).distance_to(Vector3(0.09, 0.216, 0.267)) < 0.12, "The captured phone-inset frame draws the numbered handle at the actual touch position")
	game.points = [[310, -80], [310, -65], [310, -50], [310, 75]]
	game.view.focus = Vector2(310, -60)
	game.view.zoom = 500
	game.view.set_camera_mode(3)
	game._update_plan()
	check(game.hud.plan_overlay.displayed_waypoints().size() == 4, "Densely spaced intermediate points retain their own handles")
	game.hud.waypoint_choice.item_selected.emit(1)
	check(game.selected_waypoint == 1 and game.view.focus.distance_to(Vector2(310, -65)) < 0.01, "The point selector centres and selects an individual point")
	game.view.zoom = 150
	game.view._update_camera()
	var original: Array = game.points.duplicate(true)
	at = screen(Terrain.unpack(game.points[1]))
	var destination := screen(Vector2(340, -60))
	touch(at, true); move(destination, destination - at); touch(destination, false)
	check(game.points.size() == 4 and Terrain.unpack(game.points[1]).distance_to(Vector2(340, -60)) < 0.05 and game.points[0] == original[0] and game.points[2] == original[2], "A selected touch handle moves only its own point with safe-area insets active")
	var moved: Array = game.points.duplicate(true)
	at = screen(Terrain.unpack(game.points[1]))
	touch(at, true); move(at + Vector2(24, 14), Vector2(24, 14)); touch(at + Vector2(24, 14), false, true)
	check(game.points == moved, "Android cancellation restores a dragged point without changing its neighbours")
	var perspective_drags := true
	for mode in range(4):
		game.points = [[310, -150], [310, -50], [310, 100]]
		game.view.focus = Vector2(310, -50)
		game.view.zoom = 130
		game.view.set_camera_mode(mode)
		game._update_plan()
		at = screen(Vector2(310, -50))
		destination = screen(Vector2(335, -20))
		touch(at, true); move(destination, destination - at); touch(destination, false)
		perspective_drags = perspective_drags and game.points.size() == 3 and Terrain.unpack(game.points[1]).distance_to(Vector2(335, -20)) < 0.05
	check(perspective_drags, "Individual touch dragging follows the visible slope in all four camera perspectives")
	game.clear_plan()
	var existing: Dictionary = game.model.pistes[0]
	game.hud.show_context("inspect", existing.id)
	var button: Button
	for child in game.hud.inspector_actions.get_children():
		if child is Button and child.text == "Pistenpunkte bearbeiten": button = child
	check(button != null, "Built pistes expose a direct point-editing action in the inspector")
	if button != null: button.pressed.emit()
	check(game.editing_id == existing.id and game.points == existing.points and not game.hud.asset_editor.visible, "The direct action opens actual editable piste points without another dialog")
	game.clear_plan()
	game.set_tool("piste")
	game.hud.set_map_focus(true)
	game.view.focus = Vector2(200, 190)
	game.view.zoom = 48
	game.view.set_camera_mode(2)
	target = Vector2(213, 200)
	at = screen(target)
	touch(at, true); touch(at, false)
	check(game.points.size() == 1 and Terrain.unpack(game.points[0]).distance_to(target) < 0.03, "A close-up click near a lift does not jump to an automatically prepared endpoint")
	# Real model construction and rendered snow at a new Y junction.
	game.clear_plan()
	game.model.new_game(false)
	game.model.money = 2000000
	game.model.build_lift("chair", Vector2(200, 235), Vector2(200, -230))
	game.model.build_piste([[200, -200], [200, 200]])
	game.model.build_piste([[200, -125], [285, -10], [200, 100]], -1, 24, false)
	game.view.rebuild()
	game.view.focus = Vector2(210, -10)
	game.view.zoom = 420
	game.view.yaw = -0.3
	game.view.set_camera_mode(2)
	game.hud._update_safe_area()
	game.hud.show_context("inspect")
	game.hud.set_map_focus(true)
	game.hud.refresh()
	await capture("piste-junction-0142")
	check(game.model.pistes.size() == 2 and game.view._piste_meshes.size() == 2 and game.view.snow_renderer.exclusions[game.model.pistes[1].id].size() > 0, "The actual resort renders a joined Y branch using partitioned snow meshes")
	var branch: Dictionary = game.model.pistes[1]
	game.begin_edit(branch.id, branch.name, "", 0, 24)
	game.select_waypoint(1)
	game.hud.set_map_focus(true)
	await capture("piste-editor-0142")
	print("SCENE: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _init() -> void: call_deferred("run")
