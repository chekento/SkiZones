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

func find_button(parent: Node, caption: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == caption:
			return child
		var result := find_button(child, caption)
		if result != null:
			return result
	return null

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
	game.hud.set_map_focus(true)
	check(not game.hud.tools_panel.visible and not game.hud.inspector_panel.visible and not game.hud.plan_panel.visible, "Expanded map hides the sidebars and idle plan bar")
	check(not game.hud.blocks_map(ui_position), "Expanded map gives the sidebar area back to world input")
	game.set_tool("blue")
	check(not game.hud.map_focus and game.hud.tools_panel.visible and game.hud.plan_panel.visible, "Selecting a build tool restores the controls")
	game.points = [[245, -130], [305, 0], [200, 205]]
	game._update_plan()
	game.hud.set_map_focus(true)
	check(game.points.size() == 3 and game.hud.plan_panel.visible, "Expanded map preserves a pending route and its confirmation")
	game.hud.toggle_slopes()
	var overlay: MeshInstance3D = game.view.slope_overlay
	check(game.view.slopes_visible and overlay.visible and game.hud.slope_legend.visible, "Slope overlay and legend open together")
	var terrain_normal: Vector3 = game.view.terrain_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0]
	var overlay_normal: Vector3 = overlay.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL][0]
	check(terrain_normal.y > 0 and overlay_normal.y > 0, "Terrain and slope faces point upward and are visible from the management camera")
	game.hud.toggle_slopes()
	game.hud.toggle_slopes()
	check(game.view.slope_overlay == overlay, "Repeated slope toggles reuse the existing geometry")
	game.show_menu()
	check(not game.hud.slope_legend.visible, "Slope legend stays hidden behind the main menu")
	game.continue_game()
	check(game.hud.slope_legend.visible, "Slope legend returns after continuing")
	var safe: Rect2 = game.hud.safe_content_rect(Vector2(2400, 1080), Vector2(2000, 900), Rect2(72, 0, 2328, 1056))
	check(safe.position.is_equal_approx(Vector2(60, 0)) and safe.size.is_equal_approx(Vector2(1940, 880)), "Android cutouts and navigation insets map to logical UI coordinates")
	check(game.hud.safe_content_rect(Vector2.ZERO, Vector2(1440, 900), Rect2()) == Rect2(0, 0, 1440, 900), "Missing display metrics leave the full UI usable")
	check(game.hud.safe_content_rect(Vector2(2400, 1080), Vector2(2000, 900), Rect2(-100, 0, 2600, 1200)) == Rect2(0, 0, 2000, 900), "Safe areas are clipped to the display bounds")
	game.hud.show_management(2)
	await process_frame
	var office: PanelContainer = game.hud.management
	check(office.visible and office.tabs.get_tab_count() == 5 and office.tabs.current_tab == 2, "The resort office opens the requested one of five management pages")
	check(game.hud.blocks_map(map_position) and bounds.encloses(office.get_global_rect()), "The complete office fits the viewport and blocks building underneath")
	clock = game.model.minute
	game.paused = false
	for i in range(8):
		game._process(0.25)
	check(game.model.minute == clock, "Office planning pauses the operating day without changing the user's pause setting")
	var research := find_button(office.tabs.get_child(2), "Forschung starten")
	check(research != null and not research.disabled, "Available research has an enabled action in the actual office")
	research.pressed.emit()
	await process_frame
	check(game.model.campaign.project.get("id") == "snowcraft" and office.tabs.current_tab == 2, "Office action starts the selected research and retains the current page")
	office.tabs.current_tab = 1
	var accept := find_button(office.tabs.get_child(1), "Auftrag annehmen")
	accept.pressed.emit()
	await process_frame
	check(game.model.campaign.contracts.size() == 1, "Accepting an office offer creates a persistent simulation contract")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	check(not office.visible and not game.hud.menu.visible and not game.paused, "Escape closes the office and returns to the operating map")
	check(game.view.camera.projection == Camera3D.PROJECTION_PERSPECTIVE and game.view.scenery_instance.mesh.get_surface_count() == 1, "The resort uses a perspective camera and a continuous alpine backdrop")
	check(game.view.trees.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() > 100 and game.view.visitor_mesh.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() > 100, "Batched pine and skier meshes contain modeled parts rather than single markers")
	game.hud.palette.select_category("lifts")
	await process_frame
	var gondola_locked := false
	for card in game.hud.palette.cards:
		if card.key == "gondola":
			gondola_locked = card.button.disabled and card.status.text.contains("Forschung")
	check(gondola_locked and game.hud.lift_choice.is_item_disabled(game.hud.Catalog.LIFTS.keys().find("gondola")), "Unresearched construction is disabled in both the visible card and selector")
	var previous_tool: String = game.tool
	game.hud.lift_choice.select(game.hud.Catalog.LIFTS.keys().find("gondola"))
	game.set_tool("lift")
	check(game.tool == previous_tool, "Keyboard and controller actions cannot select a locked lift")
	game.hud.lift_choice.select(game.hud.Catalog.LIFTS.keys().find("drag"))
	game.model.money = 0
	game.hud.palette.refresh(true)
	var unaffordable := true
	for card in game.hud.palette.cards:
		unaffordable = unaffordable and card.button.disabled
	check(unaffordable, "The build catalogue disables unaffordable assets")
	game.hud.show_atlas()
	await process_frame
	check(game.hud.atlas.visible and game.hud.atlas._cards.size() == 4 and game.hud.blocks_map(map_position), "The mountain passport presents four regions and blocks building underneath")
	var regions_locked := true
	for card in game.hud.atlas._cards:
		if card.id != "sonnenhang":
			regions_locked = regions_locked and card.enter.disabled
	check(regions_locked, "Unexplored regions cannot be entered before their unlock conditions")
	clock = game.model.minute
	for i in range(8):
		game._process(0.25)
	check(game.model.minute == clock, "Exploring the mountain passport pauses the current resort")
	game._input(escape)
	check(not game.hud.atlas.visible, "Escape returns from region selection to the current resort")
	game.view.change_zoom(0.001)
	check(game.view.zoom == 48, "The camera can zoom in far enough to observe individual skiers")
	game.view.overview()
	check(game.view.zoom > 1500 and game.view.terrain.bounds.has_point(game.view.focus), "The overview camera covers the expanded buildable region")
	game.model.minute = 600
	game.view.simulation_fraction = 0
	game.view._process(0)
	var chair: Dictionary = game.view.chairs[0]
	var before_chair: Vector3 = game.view._vehicles[chair.kind].multimesh.get_instance_transform(chair.index).origin
	game.view.simulation_fraction = 0.5
	game.view._process(0)
	var after_chair: Vector3 = game.view._vehicles[chair.kind].multimesh.get_instance_transform(chair.index).origin
	check(before_chair.distance_to(after_chair) > 1 and before_chair.distance_to(after_chair) < 4, "Actual rendered lift vehicles move only a few metres per normal-speed second")
	game.view._process(0)
	check(game.view._vehicles[chair.kind].multimesh.get_instance_transform(chair.index).origin == after_chair, "Lift animation holds still when the simulation clock is paused")
	game.model.money = 1000000
	game.model.campaign.mode = "free"
	game.model.build_lift("chair", Vector2(100, 200), Vector2(-170, -235))
	game.model.build_piste([[-170, -235], [-160, -50], [-80, 90], [100, 190]], 2)
	var black: Dictionary = game.model.pistes[-1]
	game.model.admit_guest(2)
	var skier: Dictionary = game.model.guests[-1]
	for route in game.model.routes_for(2):
		if route.target == black.id:
			skier.route = route
	for i in range(skier.route.legs.size()):
		if skier.route.legs[i].kind == "ski":
			skier.leg = i
			game.model._start_leg(skier)
	skier.elapsed = skier.duration * 0.5
	game.model.Snow.touch(game.model.terrain, black, skier, 0, 0.5)
	for i in range(64):
		var traffic := {"id": i + 10000, "ability": 0, "loops": 0, "leg": 0, "age": 0}
		game.model.Snow.start(game.model.pistes[0], traffic)
		game.model.Snow.touch(game.model.terrain, game.model.pistes[0], traffic, 0, 1)
	game.view.follow_guest = skier.id
	game.view.zoom = 70
	game.view._process(0)
	game.view._draw_tracks()
	var skier_position: Vector3 = game.model.guest_position(skier, game.view.simulation_fraction)
	var trace_near_guest := false
	for vertex in game.view._track_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if vertex.distance_to(skier_position) < 1.2:
			trace_near_guest = true
	check(trace_near_guest, "The observed skier keeps visible tracks even when another piste has used the track budget")
	check(Rect2(316, 166, 820, 578).has_point(game.view.camera.unproject_position(skier_position)), "The close follow camera keeps the actual skier inside the visible map")
	# Release the complete scene before checking process exit, including its fonts.
	game.queue_free()
	await process_frame
	await process_frame
	print("SCENE RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
