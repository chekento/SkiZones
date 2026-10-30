extends SceneTree
const Terrain = preload("res://src/core/terrain.gd")
var game: Node
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)
func tap(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = true
	game._input(event)
	event.pressed = false
	game._input(event)
func capture(name: String) -> void:
	game.hud.refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/" + name + ".png")
func run() -> void:
	create_timer(80).timeout.connect(func(): quit(1))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.set_process(false)
	game.paused = true
	game.set_tool("piste")
	await process_frame
	check(game.hud.piste_controls.visible and root.get_visible_rect().encloses(game.hud.piste_width_choice.get_global_rect()), "Width selection is visible inside the actual construction bar")
	game.hud.piste_width_choice.item_selected.emit(game.hud.piste_width_choice.get_item_index(36))
	check(game.plan_width == 36 and game.last_plan_check.width == 36 and game.model.pistes[0].get("width", 20) == 20, "The real width control updates the quote without editing a live piste")
	var ground: PackedVector3Array = game.view.terrain_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var target := Vector3.ZERO
	var nearest := INF
	for vertex in ground:
		var distance := Vector2(vertex.x, vertex.z).distance_to(Vector2(350, -40))
		if distance < nearest: nearest = distance; target = vertex
	for mode in range(4):
		var accurate := true
		var anchored := true
		for angle in [0.0, 0.75, 1.9, -2.4, 3.4]:
			for scale in [80, 260, 620]:
				game.points = []
				game.selected_waypoint = -1
				game.view.focus = Vector2(target.x, target.z)
				game.view.yaw = angle
				game.view.zoom = scale
				game.view.set_camera_mode(mode)
				game._update_plan()
				var at: Vector2 = game.view.camera.unproject_position(target)
				tap(at)
				accurate = accurate and game.points.size() == 1 and Terrain.unpack(game.points[0]).distance_to(Vector2(target.x, target.z)) < 0.025
				anchored = anchored and game.hud.plan_overlay.pick_waypoint(at) == 0
		check(accurate, "Actual mouse taps hit the visible ground at five rotations and three zoom levels in camera mode %d" % mode)
		check(anchored, "Waypoint handles stay under the cursor in camera mode %d" % mode)
	game.points = []
	game._update_plan()
	game.view.focus = Vector2(-170, -235)
	game.view.zoom = 160
	game.view.yaw = 1.1
	game.view.set_camera_mode(2)
	var faces: PackedVector3Array = game.view.terrain_instance.mesh.get_faces()
	nearest = INF
	for i in range(0, faces.size(), 3):
		var center := (faces[i] + faces[i + 1] + faces[i + 2]) / 3
		var distance := Vector2(center.x, center.z).distance_to(game.view.focus)
		if distance < nearest: nearest = distance; target = center
	var at: Vector2 = game.view.camera.unproject_position(target)
	var hit: Vector2 = game.view.map_point(at)
	check(hit.distance_to(Vector2(target.x, target.z)) < 0.01, "Picking follows the real steep terrain triangle rather than a different analytic height")
	check(absf(target.y - game.model.terrain.height(Vector2(target.x, target.z))) > 0.02, "The steep picking regression covers a genuinely different mesh and analytic surface")
	game.clear_plan()
	game.set_tool("piste")
	game.view.focus = Vector2(269, -72)
	game.view.zoom = 140
	game.view.yaw = -0.8
	game.view.set_camera_mode(2)
	var piste: Dictionary = game.model.pistes[0]
	for i in range(piste.surface.size()): piste.surface[i] = 0.4
	piste.surface_revision = piste.get("surface_revision", 0) + 1
	game.view._draw_snow(piste)
	faces = game.view._piste_meshes[piste.id].mesh.get_faces()
	var frames: Array = game.view.snow_renderer.pick_frames[piste.id]
	nearest = INF
	for i in range(0, faces.size(), 3):
		var center := Vector3.ZERO
		for j in range(3):
			var vertex := faces[i + j]
			vertex.y += game.model.Snow.relief(piste, frames[i + j].x, frames[i + j].y)
			center += vertex / 3
		var distance := Vector2(center.x, center.z).distance_to(Vector2(269, -72))
		if distance < nearest: nearest = distance; target = center
	at = game.view.camera.unproject_position(target)
	hit = game.view.map_point(at)
	check(hit.distance_to(Vector2(target.x, target.z)) < 0.025, "A click on raised local snow lands on its actual displaced triangle")
	var builds: int = game.view.surface_picker.builds
	game.view.map_point(at)
	check(game.view.surface_picker.builds == builds, "Repeated clicks reuse cached triangle queries")
	game.points = []
	game._update_plan()
	tap(at)
	check(game.points.size() == 1 and (Terrain.unpack(game.points[0]).distance_to(hit) < 0.025 or not game.snap_target.is_empty() and game.view.camera.unproject_position(game.view.surface_position(Terrain.unpack(game.points[0]))).distance_to(at) <= 18.01), "Construction uses the visible snow hit or an explicitly indicated nearby junction")
	var station: Vector2 = Terrain.unpack(game.model.pistes[0].points[-1])
	game.view.focus = station
	game.view.zoom = 48
	game.view.set_camera_mode(2)
	var offset := station + Vector2(-8, -5)
	at = game.view.camera.unproject_position(game.view.surface_position(offset))
	var snapped: Vector2 = game._snap_point(offset, at)
	check(snapped == offset or game.view.camera.unproject_position(game.view.surface_position(snapped)).distance_to(at) <= 18.01, "Close zoom never snaps a click to a distant screen position")
	game.clear_plan()
	game.set_tool("piste")
	game.points = [[360, -340], [420, -160], [350, 70]]
	game.view.focus = Vector2(350, -130)
	game.view.zoom = 470
	game.view.yaw = 0.7
	game.view.set_camera_mode(2)
	game._update_plan()
	var original: Array = game.points.duplicate(true)
	var money: float = game.model.money
	game.hud.smooth_route_button.pressed.emit()
	check(game.points.size() > 3 and original.all(func(p): return game.points.any(func(q): return Terrain.unpack(q).distance_to(Terrain.unpack(p)) < 0.01)) and game.model.money == money, "The visible bend action preserves waypoints and funds until confirmation")
	check(game.last_plan_check.ok and game.last_plan_check.width == 36, "The smoothed preview retains the selected full width")
	game.hud.set_map_focus(true)
	await process_frame
	check(game.hud.piste_controls.visible and game.hud.plan_panel.visible and not game.hud.tools_panel.visible, "Width and smoothing remain available in the wider map view")
	check(game.hud.plan_overlay.displayed_waypoints().size() == game.points.size() and game.hud.waypoint_choice.item_count == game.points.size(), "Every dense route point retains a handle and an individual selector entry")
	await capture("piste-width-curves-0120")
	var route: Array = game.points.duplicate(true)
	game.confirm_plan()
	check(game.model.pistes[-1].width == 36 and game.model.pistes[-1].points == route, "Confirmation builds the actual smooth route at the quoted width")
	game.view.rebuild()
	var center: Vector2 = game.model.terrain.point_on_path(game.model.pistes[0].points, 0.65)
	game.model.build_plaza("plaza", center)
	game.view.rebuild()
	var clear := true
	for item in game.view.piste_furniture:
		for vertex in item.mesh.get_faces():
			var world: Vector3 = item.transform * vertex
			clear = clear and game.view.piste_clear(Vector2(world.x, world.z))
	check(clear and not game.view.piste_furniture.is_empty(), "Actual bench, lamp, bin and sign vertices stay outside every piste")
	var refined_count: int = game.view.terrain_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	check(refined_count > 21000 and refined_count < 120000, "Ground is refined locally around built corridors with a bounded mesh")
	game.clear_plan()
	game.model.campaign.mode = "free"
	game.model.upgrade_asset(piste.id)
	game.begin_edit(piste.id, piste.name, "", 0, 20)
	check(game.last_plan_check.width == 24 and game.hud.piste_width_total.visible and game.hud.piste_width_total.text.contains("24"), "Remodeling clearly displays the actual width including the existing upgrade")
	game.set_piste_width(14)
	check(game.last_plan_check.width == 18 and piste.width == 20 and game.hud.piste_width_total.text.contains("18"), "Changing a remodeling width updates the total without changing the live piste")
	game.clear_plan()
	game.view.focus = Vector2(385, -130)
	game.view.zoom = 290
	game.view.yaw = -0.65
	game.view.set_camera_pitch(44)
	game.apply_language("en")
	check(game.plan_width == 36, "Language switching retains the chosen construction width")
	await capture("graded-piste-en-0120")
	print("PISTE SURFACES SCENE: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
