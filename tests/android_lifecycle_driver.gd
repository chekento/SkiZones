extends Node
## Included only by the emulator test export, never by the public ARM64 APK.
var game: Node
var timer := 0.0
var boot := ""
var pick_nonce := -1
var picking: Dictionary = {}
var pick_at := Vector2.ZERO
var scenario_state := ""
func setup(controller: Node) -> void:
	game=controller;boot=str(Time.get_unix_time_from_system())
	if not game.has_game:
		game.start_game(true)
		for i in range(9):game.model.admit_guest(i%3)
		for i in range(80):game.model.advance_minute(false)
		game.speed=4
		game.view.zoom=250;game.view._update_camera()
	if game.model.map_id == "braunlage": scenario_state = "ready"
	write_health()
func _process(delta: float) -> void:
	if game == null: return
	timer += delta
	if timer >= 0.5:
		timer=0
		read_pick_request()
		if scenario_state == "" and FileAccess.file_exists("user://scenario-ci.json"):
			scenario_state = "loading"
			call_deferred("_test_real_scenario")
		write_health()

func _test_real_scenario() -> void:
	game.hud._update_safe_area()
	game.clear_plan()
	game.set_tool("inspect")
	await game.enter_area("braunlage")
	game.paused = true
	for lift in game.model.lifts:
		game.Ops.fill_stations(game.model, int(lift.id), true)
		lift.fault = ""
	game.Ops.refresh_duty(game.model)
	game.model._operational_change()
	for i in range(9): game.model.admit_guest(i % 3)
	for i in range(5): game.model.advance_minute(false)
	game.view.zoom = 950
	game.view._update_camera()
	game.hud.refresh()
	game.save_game()
	for i in range(3): await get_tree().process_frame
	scenario_state = "ready"
	write_health()

func read_pick_request() -> void:
	if not FileAccess.file_exists("user://picking-ci.json"): return
	var request: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://picking-ci.json"))
	if not request is Dictionary: return
	if not request.get("mode") is float and not request.get("mode") is int: return
	var mode := int(request.mode)
	if mode not in [0, 1, 2, 3] or mode != request.mode: return
	if pick_nonce == mode: return
	pick_nonce = mode
	game.clear_plan()
	game.set_tool("piste")
	game.paused = true
	# Exercise a camera cutout even when this emulator exposes a rectangular
	# display. This fixture is included only in the x86-64 CI test export.
	game.hud.root.offset_left = maxf(48, game.hud.root.offset_left)
	game.hud.root.offset_top = maxf(24, game.hud.root.offset_top)
	game.view.follow_guest = -1
	var vertices: PackedVector3Array = game.view.terrain_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var target := Vector3.ZERO
	var nearest := INF
	for vertex in vertices:
		var distance := Vector2(vertex.x, vertex.z).distance_to(Vector2(350, -40))
		if distance < nearest: nearest = distance; target = vertex
	game.view.focus = Vector2(target.x, target.z)
	game.view.yaw = [0.6, 1.8, -1.1, 2.7][mode]
	game.view.zoom = [110, 160, 230, 360][mode]
	game.view.set_camera_mode(mode)
	game._update_plan()
	pick_at = game.view.camera.unproject_position(target)
	var physical: Vector2 = get_viewport().get_screen_transform() * pick_at
	var destination := Vector2(target.x - 28, target.z + 24)
	var destination_screen: Vector2 = get_viewport().get_screen_transform() * game.view.camera.unproject_position(game.view.surface_position(destination))
	picking = {"mode": mode, "screen": [physical.x, physical.y], "target": [target.x, target.z], "destination": [destination.x, destination.y], "destination_screen": [destination_screen.x, destination_screen.y]}
func write_health() -> void:
	if not picking.is_empty():
		picking.point = game.points[0] if game.points.size() == 1 else []
		picking.handle_hit = game.hud.plan_overlay.pick_waypoint(pick_at, 2) == 0
	var file:=FileAccess.open("user://lifecycle-ci.json.tmp",FileAccess.WRITE)
	if file == null:return
	file.store_string(JSON.stringify({"boot":boot,"map":game.model.map_id,"minute":game.model.minute,"day":game.model.day,"guests":game.model.guests.map(func(g):return g.id),"sports":game.model.guests.map(func(g):return g.get("sport","ski")),"frames":Engine.get_frames_drawn(),"resumes":game.resume_count,"background":game._app_background,"camera":game.view.camera.is_current(),"paused":game.paused,"size":[get_viewport().size.x,get_viewport().size.y],"picking":picking,"scenario":scenario_state,"elevation":game.model.terrain.height(Vector2(185,230)),"lifts":game.model.lifts.size(),"pistes":game.model.pistes.size(),"staff":game.model.operations.staff.size()}))
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path("user://lifecycle-ci.json.tmp"),ProjectSettings.globalize_path("user://lifecycle-ci.json"))
