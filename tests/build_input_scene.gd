extends SceneTree
const Terrain = preload("res://src/core/terrain.gd")
var game: Node
var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("run")

func check(value: bool, title: String) -> void:
	if value:
		passed += 1; print("PASS ", title)
	else:
		failed += 1; push_error("FAIL " + title)

func touch(index: int, point: Vector2, pressed: bool, parsed: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index; event.position = root.get_screen_transform() * point if parsed else point; event.pressed = pressed
	if parsed: Input.parse_input_event(event)
	else: game._input(event)

func drag(index: int, point: Vector2, relative: Vector2, parsed: bool = false) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index; event.position = root.get_screen_transform() * point if parsed else point; event.relative = relative
	if parsed: Input.parse_input_event(event)
	else: game._input(event)

func mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_screen_transform() * at; event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.start_game(true); game.paused = true
	game.set_tool("piste"); game.points = [[240,-190],[320,60]]; game._update_plan()
	await process_frame
	var original: Array = game.points.duplicate(true)
	var kind: String = game.hud.lift_kind()
	game.set_tool("lift"); game.hud.palette.select_category("lifts")
	check(game.tool == "piste" and game.points == original and game.hud.lift_kind() == kind, "An unfinished piste cannot be replaced by a lift tool")
	check(game.hud.palette.categories.lifts.disabled and game.hud.palette.category == "pistes", "The catalogue visibly locks other categories until build or cancel")
	game.hud.palette.refresh(true)
	check(game.hud.palette.categories.lifts.custom_minimum_size.y >= 54 and game.hud.palette.categories.village.custom_minimum_size.y >= 54, "The redesigned build categories have comfortable finger-sized targets")
	check(game.hud.palette.guidance.text.contains("PLAN IN ARBEIT") and game.hud.palette.guidance.text.contains(str(game.points.size())), "The build guide shows live pending point counts without discarding the plan")
	check(not game.hud.inspector_panel.visible and game.hud.plan_panel.visible, "Building leaves more map space while keeping the commit and cancel actions visible")
	game.paused = false
	var minute: int = game.model.minute
	game._process(2)
	check(not game.simulation_running() and game.model.minute == minute and not game.paused, "Pending construction pauses the operating clock without altering the user's pause setting")
	for i in range(20):
		game.hud.palette.categories.lifts.pressed.emit()
		game.set_tool("building")
	check(game.points == original and game.tool == "piste", "Repeated competing build actions cannot corrupt or lose a pending plan")
	var before: Vector2 = game.view.focus
	var zoom: float = game.view.zoom
	touch(0, Vector2(880,400), true); touch(1, Vector2(1000,400), true)
	drag(0, Vector2(940,430), Vector2(60,30)); drag(1, Vector2(1060,430), Vector2(60,30))
	touch(0, Vector2(940,430), false); touch(1, Vector2(1060,430), false)
	check(game.view.focus.distance_to(before) > 10 and absf(game.view.zoom-zoom) < 0.1, "Two fingers translate the camera without residual zoom")
	check(game.points == original and game._touches.is_empty(), "A two-finger gesture never adds points or leaves a contact active")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.tool == "inspect" and game.points.is_empty() and not game.hud.menu.visible, "Android Back cancels construction before opening the main menu")
	check(game.simulation_running(), "Canceling a plan resumes a previously running resort")
	game.paused = true
	check(game._drag_waypoint == -1 and not game._mouse_down and game._touches.is_empty(), "Cancel clears all transient drag and pointer state")
	game.set_tool("piste"); game.points = original.duplicate(true); game._update_plan()
	game.clear_plan(); game.set_tool("lift")
	check(game.tool == "lift" and game.points.is_empty() and not game.hud.palette.categories.village.disabled, "A new tool works normally after cancellation")
	game.clear_plan(); game.hud.palette.select_category("paths")
	await process_frame
	var plaza_card: Dictionary = {}
	for card in game.hud.palette.cards:
		if card.key == "plaza" and card.type == "plaza": plaza_card = card
	plaza_card.button.pressed.emit()
	check(game.tool == "plaza" and game.plaza_kind == "plaza", "Independent walking areas have a usable build card")
	game.points = [[340,300]]; game._update_plan()
	var money: float = game.model.money
	game.confirm_plan(); game.confirm_plan()
	check(game.model.walk_areas.size() == 1 and game.model.money == money - 7200, "Repeated confirmation cannot build or charge a plaza twice")
	game.clear_plan(); game.hud.palette.select_category("lifts")
	await process_frame; await process_frame
	var scroll: ScrollContainer
	for child in game.hud.palette.get_children():
		if child is ScrollContainer: scroll = child
	var at: Vector2 = scroll.get_global_rect().position + Vector2(100,110)
	mouse(at,true); await process_frame
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_screen_transform() * (at - Vector2(0,90)); motion.relative = Vector2(0,-90); motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion); await process_frame
	mouse(at - Vector2(0,90),false); await process_frame
	check(scroll.scroll_vertical > 50 and game.tool == "inspect", "Pen/mouse dragging over a lift card scrolls without choosing it")
	scroll.scroll_vertical = 0; await process_frame
	touch(0,at,true,true); await process_frame
	drag(0,at-Vector2(0,90),Vector2(0,-90),true); await process_frame
	touch(0,at-Vector2(0,90),false,true); await process_frame
	check(scroll.scroll_vertical > 50 and game.tool == "inspect", "Finger dragging over a lift card also scrolls without choosing it")
	check(game.points.is_empty() and game._touches.is_empty(), "Scrolling the GUI leaves no hidden map gesture or build point")
	game.hud._update_responsive_layout(920.0)
	check(game.hud.compact_layout and game.hud.compact_header_columns.all(func(node): return not node.visible), "Narrow Android HUD retains key indicators and hides secondary KPIs")
	check(game.hud.compact_camera_buttons.all(func(node): return not node.visible) and game.hud.map_focus_button.visible, "Narrow camera bar retains essential controls without overflowing")
	check(game.hud.piste_controls is HFlowContainer and game.hud.labels.status.visible and game.hud.undo_button.text == "↶" and game.hud.redo_button.text == "↷", "Compact build controls wrap into rows while retaining status, undo and redo")
	game.hud._update_responsive_layout(1440.0)
	check(not game.hud.compact_layout and game.hud.compact_header_columns.all(func(node): return node.visible) and game.hud.compact_camera_buttons.all(func(node): return node.visible), "Wide desktop HUD restores the full navigation and stats")
	check(game.hud.undo_button.text == "Letzten Punkt zurück" and game.hud.redo_button.text == "Punkt wiederholen", "Desktop restores readable full-size build action labels")
	game.clear_plan()
	game.set_tool("piste")
	game.points = [[220,-180],[260,30]]
	game._update_plan()
	var remembered: Array = game.points.duplicate(true)
	game.undo_point()
	check(game.points.size() == remembered.size() - 1 and game.undone_points.size() == 1 and not game.hud.redo_button.disabled, "Undo preserves a removed piste point for explicit redo")
	game.redo_point()
	check(game.points == remembered and game.undone_points.is_empty() and game.hud.redo_button.disabled, "Redo accurately restores the removed piste waypoint")
	# Tap jitter and interrupted multi-touch gestures must never shift a point.
	var start_at: Vector2 = game.view.camera.unproject_position(game.view.surface_position(Terrain.unpack(game.points[0])))
	var stable: Array = game.points.duplicate(true)
	game.undo_point()
	var previous_redo: Array = game.undone_points.duplicate(true)
	game._begin_waypoint_drag(0, start_at)
	game._drag_screen_offset = Vector2.ZERO
	game._move_waypoint(start_at + Vector2(3, 4))
	game._end_waypoint_drag()
	check(game.points.size() == 1 and game.points[0] == stable[0] and game.undone_points == previous_redo, "Touch jitter selects an existing waypoint without shifting coordinates or clearing redo")
	game._begin_waypoint_drag(0, start_at)
	game._drag_screen_offset = Vector2.ZERO
	game._move_waypoint(start_at + Vector2(28, 18))
	game._end_waypoint_drag(true)
	check(game.points[0] == stable[0] and game.undone_points == previous_redo, "Canceled two-finger drag restores original waypoint and retains redo history")
	game.redo_point()
	check(game.points == stable, "Redo remains available after canceled or tiny touch gestures")
	var key := InputEventKey.new()
	key.pressed = true
	key.ctrl_pressed = true
	key.keycode = KEY_Z
	game._input(key)
	check(game.points.size() == remembered.size() - 1 and game.undone_points.size() == 1, "Ctrl+Z removes the latest planned waypoint")
	key.keycode = KEY_Y
	game._input(key)
	check(game.points == remembered and game.undone_points.is_empty(), "Ctrl+Y redoes the last planned waypoint")
	game.undo_point()
	game.clear_plan()
	game.redo_point()
	check(game.tool == "inspect" and game.points.is_empty() and game.undone_points.is_empty(), "Canceling construction discards redo history without resurrecting a canceled plan")
	game.queue_free(); await process_frame; await process_frame
	print("BUILD INPUT SCENE: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
