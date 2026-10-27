extends SceneTree
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

func screen_point(point: Array) -> Vector2:
	return game.view.camera.unproject_position(game.model.terrain.world(Terrain.unpack(point), 4))

func touch(at: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	game._input(event)

func drag(at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = at
	event.relative = relative
	game._input(event)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.paused = true
	game.set_tool("piste")
	var piste_cards := 0
	for card in game.hud.palette.cards:
		if card.type == "piste":
			piste_cards += 1
	check(piste_cards == 1 and game.hud.tool_buttons.has("piste"), "One automatic piste tool replaces the three manual paint colors")
	game.view.focus = Vector2(250, 0)
	game.view.yaw = 0
	game.view.zoom = 600
	game.view.set_camera_mode(3)
	game.points = [[200, -200], [300, -50], [250, 160]]
	game._update_plan()
	await process_frame
	var original: Array = game.points.duplicate(true)
	var at := screen_point(game.points[1])
	var destination := screen_point([350, -20])
	var focus: Vector2 = game.view.focus
	var money: float = game.model.money
	var quote: int = game.last_plan_check.cost
	check(not game.hud.blocks_map(at) and game.hud.plan_overlay.pick_waypoint(at) == 1, "The middle waypoint has a usable screen-sized handle")
	touch(at, true)
	drag(destination, destination - at)
	touch(destination, false)
	check(game.points.size() == 3 and Terrain.unpack(game.points[1]).distance_to(Vector2(350, -20)) < 0.1 and game.points[0] == original[0] and game.points[2] == original[2], "Touch dragging moves only the selected planning waypoint")
	check(game.view.focus == focus and game.model.money == money and game.last_plan_check.cost != quote, "Moving a waypoint updates the quote without panning or spending money")
	check(root.get_visible_rect().encloses(game.hud.confirm_button.get_global_rect()) and root.get_visible_rect().encloses(game.hud.delete_point_button.get_global_rect()) and game.hud.labels.status.size.y >= 40 and game.hud.labels.status.size.y <= 50, "Build and point actions stay inside the screen even with long status text")
	check(game.selected_waypoint == 1 and not game.hud.delete_point_button.disabled, "The selected point can be deleted through the real build bar")
	at = screen_point(game.points[1])
	touch(at, true)
	drag(at + Vector2(40, 20), Vector2(40, 20))
	touch(at + Vector2(40, 20), false, true)
	check(Terrain.unpack(game.points[1]).distance_to(Vector2(350, -20)) < 0.1 and game._drag_waypoint == -1, "A canceled drag restores the waypoint and clears the gesture")
	game.delete_waypoint()
	check(game.points.size() == 2 and game.selected_waypoint == -1 and game.hud.delete_point_button.disabled, "Deleting a selected middle point preserves the remaining endpoints")
	game.points = [[200, -200], [300, -50], [250, 160]]
	game._update_plan()
	at = screen_point(game.points[1])
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = at
	mouse.pressed = true
	game._input(mouse)
	var motion := InputEventMouseMotion.new()
	motion.position = destination
	motion.relative = destination - at
	game._input(motion)
	mouse.position = destination
	mouse.pressed = false
	game._input(mouse)
	check(Terrain.unpack(game.points[1]).distance_to(Vector2(350, -20)) < 0.1 and game.points.size() == 3, "Mouse dragging edits the same waypoint without appending another")
	var anchor: Dictionary = game.model.connection_anchors()[1]
	var snapped: Vector2 = game._snap_point(anchor.point + Vector2(3, 1))
	check(snapped == anchor.point and not game.snap_target.is_empty(), "Planning can dock exactly at an existing interior waypoint")
	var source: Array = game.points.duplicate(true)
	game.hud.show_camera()
	await process_frame
	check(game.hud.camera_dialog.visible and root.get_visible_rect().encloses(game.hud.camera_panel.get_global_rect()) and game.hud.blocks_map(at) and not game.simulation_running(), "The camera chooser blocks map edits and pauses simulation")
	var camera_ok := true
	for mode in range(4):
		game.hud.camera_choice.item_selected.emit(mode)
		var terrain_point: Vector2 = game.view.focus
		var screen: Vector2 = game.view.camera.unproject_position(game.model.terrain.world(terrain_point))
		var hit: Vector2 = game.view.map_point(screen)
		camera_ok = camera_ok and hit.distance_to(terrain_point) < 0.1 and game.view.camera_mode == mode
	check(camera_ok, "Terrain picking stays accurate in all four camera perspectives")
	check(game.view.camera.projection == Camera3D.PROJECTION_ORTHOGONAL and not game.hud.pitch_slider.editable, "The top view is truly orthographic with a fixed vertical angle")
	game.hud.camera_choice.item_selected.emit(2)
	game.hud.pitch_slider.value = 71
	check(game.view.pitch_degrees == 71 and game.view.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "The pitch slider changes the actual perspective camera")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	check(not game.hud.camera_dialog.visible and game.points == source, "Escape closes camera controls without losing the pending route")
	game.hud.toggle_slopes()
	var topography: Node3D = game.view.topography
	check(topography != null and topography.visible and game.view.contour_mesh.mesh.get_surface_count() == 1, "Terrain help includes actual contour geometry")
	var contour_ok := true
	for vertex in game.view.contour_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var remainder := fposmod(vertex.y - 0.85, 20)
		contour_ok = contour_ok and minf(remainder, 20 - remainder) < 0.002
	check(contour_ok, "Contour geometry follows exact 20-metre height levels")
	var arrows: MultiMesh = game.view.downhill_arrows.multimesh
	var downhill := 0
	var inspected := mini(arrows.visible_instance_count, 30)
	for index in range(inspected):
		var transform_value := arrows.get_instance_transform(index)
		var point := Vector2(transform_value.origin.x, transform_value.origin.z)
		var heading := Vector2(-transform_value.basis.z.x, -transform_value.basis.z.z).normalized()
		if game.model.terrain.height(point + heading * 4) < game.model.terrain.height(point):
			downhill += 1
	check(inspected > 10 and downhill >= inspected * 0.9, "Rendered relief arrows point downhill on the actual mountain")
	game.hud.toggle_slopes()
	game.hud.toggle_slopes()
	check(game.view.topography == topography, "Repeated terrain toggles reuse contours and arrow instances")
	var markers_ok: bool = not game.view.piste_markers.is_empty()
	for marker in game.view.piste_markers:
		var piste: Dictionary = game.model.asset(marker.id)
		markers_ok = markers_ok and marker.number == piste.number and marker.difficulty == piste.difficulty
	check(markers_ok, "Automatic round markers keep their piste's number and difficulty")
	var has_start := false
	var has_end := false
	for marker in game.view.piste_markers:
		has_start = has_start or is_zero_approx(marker.fraction)
		has_end = has_end or is_equal_approx(marker.fraction, 1)
	check(has_start and has_end, "Piste markers include both route ends")
	game.view.set_camera_mode(0)
	game.queue_free()
	await process_frame
	await process_frame
	print("PLANNING SCENE: %d passed; %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
