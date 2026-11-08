extends Node
## Included only by the emulator test export, never by the public ARM64 APK.
const SupportBundle = preload("res://src/core/save_bundle_040.gd")
var game: Node
var timer := 0.0
var boot := ""
var pick_nonce := -1
var picking: Dictionary = {}
var pick_at := Vector2.ZERO
var scenario_state := ""
var update_test_state:=""
var update_native_validation:=""
var update_action:=""
var support_status := ""
var support_archive := ""
var support_bytes_preserved := false
func setup(controller: Node) -> void:
	game=controller;boot=str(Time.get_unix_time_from_system())
	if not game.has_game:
		game.start_game(true)
		game.model.minute=565
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
		if FileAccess.file_exists("user://support-ci.json"):
			var support: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://support-ci.json"))
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://support-ci.json"))
			if support is Dictionary and str(support.get("action", "")) == "export":
				call_deferred("_export_support_fixture")
		if FileAccess.file_exists("user://update-ci.json"):
			var request: Variant=JSON.parse_string(FileAccess.get_file_as_string("user://update-ci.json"))
			if request is Dictionary and request.get("action","")!=update_action:
				update_action=str(request.get("action",""))
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://update-ci.json"))
				if update_action=="prepare":call_deferred("_prepare_update_test")
				elif update_action=="open-browser":call_deferred("_open_update_test",request)
		if scenario_state == "" and FileAccess.file_exists("user://scenario-ci.json"):
			scenario_state = "loading"
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://scenario-ci.json"))
			call_deferred("_test_real_scenario")
		write_health()

func _export_support_fixture() -> void:
	# Emulator-only exercise of the real Android ZIP/JNI/share path. The host
	# creates a deliberately malformed primary in its isolated test user://.
	# Never modify or auto-repair any source during export.
	support_status = "preparing"
	var primary: String = game.SaveStore.path_for_map("sonnenhang", 3)
	var backup: String = primary + ".bak"
	if not FileAccess.file_exists(primary) or not FileAccess.file_exists(backup):
		support_status = "missing_fixture"
		write_health()
		return
	var primary_sha: String = FileAccess.get_sha256(primary)
	var backup_sha: String = FileAccess.get_sha256(backup)
	var bundle: Dictionary = SupportBundle.export_slot("sonnenhang", 3)
	support_bytes_preserved = primary_sha == FileAccess.get_sha256(primary) and backup_sha == FileAccess.get_sha256(backup)
	if not bundle.ok:
		support_status = "export_" + str(bundle.get("code", "unknown"))
		write_health()
		return
	support_archive = str(bundle.path)
	if int(bundle.files) < 2 or not support_bytes_preserved:
		support_status = "incomplete"
		write_health()
		return
	var shared: Dictionary = SupportBundle.share_slot_archive(support_archive)
	support_status = "shared" if shared.ok else "share_" + str(shared.get("code", "unknown"))
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
	game.view.set_quality(["economy", "balanced", "auto", "high"][mode])
	if mode == 2:
		for i in range(60): game.view._adapt_quality(0.1)
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
	file.store_string(JSON.stringify({"boot":boot,"update_test":update_test_state,"update_validation":update_native_validation,"support_status":support_status,"support_archive":support_archive,"support_preserved":support_bytes_preserved,"installed_code":game.updater.installed_code,"updater_state":game.updater.state,"update_url":game.updater.last_opened_url,"slot":game.SaveStore.active_slot,"money":game.model.money,"map":game.model.map_id,"minute":game.model.minute,"day":game.model.day,"guests":game.model.guests.map(func(g):return g.id),"sports":game.model.guests.map(func(g):return g.get("sport","ski")),"frames":Engine.get_frames_drawn(),"resumes":game.resume_count,"background":game._app_background,"camera":game.view.camera.is_current(),"render_scale":get_viewport().scaling_3d_scale,"paused":game.paused,"size":[get_viewport().size.x,get_viewport().size.y],"picking":picking,"scenario":scenario_state,"elevation":game.model.terrain.height(Vector2(185,230)),"lifts":game.model.lifts.size(),"pistes":game.model.pistes.size(),"staff":game.model.operations.staff.size()}))
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path("user://lifecycle-ci.json.tmp"),ProjectSettings.globalize_path("user://lifecycle-ci.json"))

func _prepare_update_test() -> void:
	update_test_state="preparing"
	for slot in range(1,5):
		game.select_career_slot(slot,true)
		game.paused=true;game.model.day=slot+10;game.model.money=234560+slot;game.save_game()
	await game.select_career_slot(3,false)
	game.paused=true;game.save_game()
	update_test_state="prepared";write_health()

func _open_update_test(request: Dictionary) -> void:
	var updater: Node=game.updater
	var current_parts: Array=updater.Catalog.version_parts(updater.installed_version)
	if current_parts.size()!=3:
		update_test_state="invalid_version";write_health();return
	# Synthetic next-patch version: fixture only, not a claimed public release.
	var version: String="%d.%d.%d" % [int(current_parts[0]),int(current_parts[1]),int(current_parts[2])+1]
	var filename: String="SkiZones-%s-android-arm64.apk"%version
	var root: String=updater.Catalog.RELEASES+"/download/v"+version+"/"
	updater.candidate={"version":version,"file_name":filename,"apk":root+filename,"manifest":root+"manifest.json","release":updater.Catalog.RELEASES+"/tag/v"+version}
	updater.build={"sha256":str(request.sha256),"size_bytes":int(request.size),"version_code":updater.installed_code+1,"version":version,"file_name":filename,"package":updater.Catalog.PACKAGE,"architecture":"arm64-v8a"}
	updater._set_status("available","")
	updater.open_download()
	update_test_state="browser_"+updater.state;write_health()
