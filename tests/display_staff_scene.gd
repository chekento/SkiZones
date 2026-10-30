extends SceneTree
const Geo = preload("res://src/core/real_resorts.gd")
const Ops = preload("res://src/core/operations.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Snow = preload("res://src/core/snow_surface.gd")
var game: Node
var passed := 0
var failed := 0

func _init() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)

func button_named(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var result := button_named(child, title)
		if result != null: return result
	return null

func first_choice(node: Node) -> OptionButton:
	if node is OptionButton: return node
	for child in node.get_children():
		var result := first_choice(child)
		if result != null: return result
	return null

func capture(title: String) -> void:
	game.hud.refresh()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/" + title + ".png")

func run() -> void:
	create_timer(550).timeout.connect(func(): quit(1))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var career := button_named(game.hud.menu, "Karriere · Gebiete entdecken")
	var free := button_named(game.hud.menu, "Freier Aufbau · alle Anlagen")
	var extras := button_named(game.hud.menu, "Szenarien · echte Skigebiete")
	check(career != null and free != null and extras != null and career.get_global_rect().position.y < extras.get_global_rect().position.y and free.get_global_rect().position.y < extras.get_global_rect().position.y, "Career and free play appear above the optional scenarios")
	await capture("main-game-first-0150")
	game.start_game(true)
	game.paused = true
	game.view.set_process(false)
	game.set_tool("piste")
	game.points = [[320, -100], [350, -30]]
	game.view.focus = Vector2(330, -60)
	game.view.zoom = 180
	game.view.set_camera_mode(3)
	game._update_plan()
	var anchor: Vector2 = Terrain.unpack(game.points[1])
	var at: Vector2 = game.view.camera.unproject_position(game.view.surface_position(anchor))
	for mode in ["auto", "economy", "balanced", "high"]:
		game.view.set_quality(mode)
		check(root.scaling_3d_scale == 1.0, "Full-screen render target in " + mode)
		game.view.quality = "auto"
		for i in range(80): game.view._adapt_quality(0.1)
		for i in range(100): game.view._adapt_quality(0.005)
		check(root.scaling_3d_scale == 1.0 and game.view.camera.unproject_position(game.view.surface_position(anchor)).distance_to(at) < 0.01, "Overload and recovery never move the map or waypoint in " + mode)
	game.hud.root.offset_left = 80
	game.hud.root.offset_top = 20
	await process_frame
	var local: Vector2 = game.hud.plan_overlay.local_screen(at)
	check((game.hud.plan_overlay.get_global_transform_with_canvas() * local).distance_to(at) < 0.01 and game.hud.plan_overlay.pick_waypoint(at) == 1, "Phone safe-area drawing and hit testing share the same screen coordinate")
	var focus: Vector2 = game.view.focus
	game._begin_waypoint_drag(1)
	game._move_waypoint(at + Vector2(44, 32))
	game._end_waypoint_drag()
	check(game.view.focus == focus and game.hud.plan_overlay.pick_waypoint(game.view.camera.unproject_position(game.view.surface_position(Terrain.unpack(game.points[1])))) == 1, "Dragging a point preserves the camera and ends on its visible handle")
	await capture("stable-planning-0150")
	game.hud.root.offset_left = 0
	game.hud.root.offset_top = 0
	game.clear_plan()
	for id in Geo.IDS:
		game.model.new_game(true, 20261029, id)
		game.view.rebuild()
		game.has_game = true
		game.hud.hide_menu()
		game.set_tool("inspect")
		game.hud.refresh()
		check(game.hud.mission_panel.visible and game.hud.mission_title.text.contains("Missionen") and game.hud.inspector_text.text.contains("SZENARIOMISSIONEN"), id + " missions remain visible on the map")
		var checked := 0
		var gaps := 0
		var buried := 0
		for piste in game.model.pistes:
			var mesh: Mesh = game.view._piste_meshes[piste.id].mesh
			if mesh.get_surface_count() == 0: continue
			var faces: PackedVector3Array = mesh.get_faces()
			var frames: Array = game.view.snow_renderer.pick_frames[piste.id]
			var weights: PackedFloat32Array = game.view.snow_renderer.pick_weights[piste.id]
			var stride := maxi(1, faces.size() / 90) * 3
			for i in range(0, faces.size(), stride):
				var center := Vector3.ZERO
				for j in range(3):
					var vertex := faces[i + j]
					vertex.y += Snow.relief(piste, frames[i + j].x, frames[i + j].y) * weights[i + j]
					center += vertex / 3
				var ground: Vector3 = game.view.ground_position(Vector2(center.x, center.z))
				if center.y < ground.y + 0.2: buried += 1
				checked += 1
			for fraction in [0.1, 0.35, 0.6, 0.9]:
				var point: Vector2 = game.model.terrain.point_on_path(piste.points, fraction)
				var hit: Vector3 = game.view.surface_position(point)
				if hit.y < game.view.ground_position(point).y + 0.2: gaps += 1
		check(checked > 100 and buried == 0, id + " snow triangles stay above the actual rendered terrain; sampled=" + str(checked) + " buried=" + str(buried))
		check(gaps == 0, id + " imported centerlines have continuous visible snow coverage; gaps=" + str(gaps))
		var first: Dictionary = game.model.pistes[0]
		game.view.focus = game.model.terrain.point_on_path(first.points, 0.5)
		game.view.zoom = clampf(first.length * 0.9, 350, 1600)
		game.view.set_camera_mode(2)
		game.view._update_atmosphere()
		game.hud.set_map_focus(true)
		await capture(id + "-continuous-pistes-0150")
		game.hud.set_map_focus(false)
		var lift: Dictionary = game.model.lifts[0]
		game.hud.show_context("inspect", int(lift.id))
		check(game.hud.lift_staff_button.visible and game.hud.lift_staff_status.text.contains("im Dienst"), id + " selected lift exposes station staffing above its statistics")
		game.hud.lift_staff_button.pressed.emit()
		check(game.hud.lift_staff.visible and game.hud.blocks_map(Vector2(700, 400)) and not game.simulation_running(), id + " direct lift-team action opens a paused, input-blocking station editor")
		var team: Array = Ops.station_team(game.model, lift)
		var missing: int = team[0].missing
		var budget: float = game.model.money
		game.hud.lift_staff.cards[0].hire.pressed.emit()
		check(Ops.station_team(game.model, lift)[0].missing == 0 and game.model.money == budget - missing * 180, id + " actual station hire button fills only its quoted vacancies")
		budget = game.model.money
		Ops.fill_station(game.model, int(lift.id), team[0].key)
		check(game.model.money == budget, id + " repeated fill cannot duplicate a fully planned team")
		for station in Ops.station_team(game.model, lift): Ops.fill_station(game.model, int(lift.id), station.key)
		game.hud.lift_staff.rebuild()
		check(Ops.staffing(game.model, lift).ok, id + " both stations are staffed after their individual actions")
		if id == "braunlage":
			await capture("lift-team-stations-0150")
			var person: Dictionary = Ops.station_team(game.model, lift)[0].people[0]
			first_choice(game.hud.lift_staff.stations).item_selected.emit(2)
			check(person.shift == "night" and not Ops.on_duty(game.model, person) and not Ops.staffing(game.model, lift).ok, "Actual shift selector removes an off-shift person from the station's on-duty count")
			first_choice(game.hud.lift_staff.stations).item_selected.emit(0)
			check(person.shift == "day" and Ops.staffing(game.model, lift).ok, "Returning the same person to the day shift restores coverage without rehiring")
			Ops.assign(game.model, int(person.id), "reserve", "day")
			game.hud.lift_staff.rebuild()
			budget = game.model.money
			button_named(game.hud.lift_staff, "Reserve dieser Station zuweisen · kostenlos").pressed.emit()
			check(person.assignment == team[0].key and game.model.money == budget and Ops.staffing(game.model, lift).ok, "Actual reserve action fills the selected station without recruitment costs")
			var section: Dictionary = game.model.lifts.filter(func(l): return l.get("sections", 1) > 1)[0]
			check(Ops.station_team(game.model, section).any(func(s): return s.name == "Mittelstation"), "A shared gondola station is explicitly named as the middle station")
		game.hud.lift_staff.hide()
		game.hud.show_menu()
		check(game.main_game_area() not in Geo.IDS and not game.hud.continue_button.text.contains(game.model.Maps.spec(id).name), id + " scenario progress cannot replace the main-game Continue action")
		game.hud.hide_menu()
	game.hud.show_management_page("Personal")
	check(game.hud.management.tabs.get_tab_title(game.hud.management.tabs.current_tab) == "Personal", "Staff directory opens its actual page")
	await capture("staff-directory-0150")
	game.hud.management.hide()
	game.apply_language("en")
	game.hud.lift_staff.open(int(game.model.lifts[0].id))
	check(game.hud.lift_staff.summary.text.contains("on duty") and game.hud.lift_staff.cards[0].status.text.contains("Day shift"), "English station editor includes real staff and shift status")
	await capture("en-lift-team-0150")
	game.queue_free()
	await process_frame
	print("DISPLAY STAFF SCENE: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
