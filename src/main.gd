extends Node3D

const Resort = preload("res://src/core/resort.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Passport = preload("res://src/core/passport.gd")
const Maps = preload("res://src/core/maps.gd")
const SaveStore = preload("res://src/core/save_store.gd")
const ResortView = preload("res://src/world/resort_view.gd")
const ResortHUD = preload("res://src/ui/hud.gd")

var model := Resort.new()
var passport := Passport.new()
var view := ResortView.new()
var hud := ResortHUD.new()
var tool := "inspect"
var points: Array = []
var last_plan_check: Dictionary = {}
var selected_waypoint := -1
var _drag_waypoint := -1
var _drag_original: Array = []
var snap_target: Dictionary = {}
var paused := false
var speed := 1
var has_game := false
var _accumulator := 0.0
var _refresh_timer := 0.0
var _day_report_shown := false
var simulation_fraction := 0.0
var _mouse_down := false
var _mouse_origin := Vector2.ZERO
var _mouse_dragged := false
var _touches: Dictionary = {}
var _touch_origins: Dictionary = {}
var _touch_dragged := false
var _gesture_used := false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	passport.load_from()
	model.new_game(true, 20261027, passport.data.last_map)
	add_child(view)
	view.setup(model)
	add_child(hud)
	hud.setup(self)
	hud.show_menu()
	_update_plan()
	# Deterministic captures and boot checks are also used by CI.
	for argument in OS.get_cmdline_user_args():
		if argument == "--smoke-test":
			call_deferred("_smoke_test")
		elif argument.begins_with("--capture="):
			call_deferred("_capture", argument.trim_prefix("--capture="))

func _process(delta: float) -> void:
	if simulation_running():
		_accumulator += minf(delta, 0.25) * speed * Resort.MINUTES_PER_SECOND
		while _accumulator >= 1.0 and model.minute < Resort.CLOSING:
			_accumulator -= 1.0
			model.advance_minute()
	simulation_fraction = _accumulator
	view.simulation_fraction = simulation_fraction
	view.motion_running = simulation_running()
	if has_game and model.minute >= Resort.CLOSING and not _day_report_shown:
		_day_report_shown = true
		save_game()
		hud.show_report()
		_update_plan()
	_refresh_timer += delta
	if _refresh_timer >= 0.4:
		_refresh_timer = 0.0
		hud.refresh()

func simulation_running() -> bool:
	return has_game and not paused and not hud.menu.visible and not hud.camera_dialog.visible and not hud.help_dialog.visible and not hud.management.visible and not hud.atlas.visible and model.minute < Resort.CLOSING

func start_game(starter: bool, area: String = "sonnenhang") -> void:
	model.new_game(starter, 20261027, area)
	passport.record(model)
	has_game = true
	paused = false
	speed = 1
	_accumulator = 0
	_day_report_shown = false
	view.home()
	hud.hide_menu()
	hud.atlas.hide()
	hud.set_map_focus(false)
	set_tool("inspect")
	hud.toast("Willkommen am Berg. 1× ist bewusst ruhig; mit 4× entwickelst du schneller. Tippe einen Gast zum Beobachten an." if starter else "Freier Aufbau: Alle Anlagen sind verfügbar. Plane deinen ersten Rundweg.")
	hud.refresh()

func enter_area(area: String) -> void:
	if not passport.unlocked(area):
		hud.toast("Dieses Gebiet wird durch deinen Bergpass freigeschaltet.")
		return
	if has_game and model.map_id == area:
		hud.atlas.hide()
		hud.hide_menu()
		return
	if has_game and not save_game():
		return
	var path := SaveStore.path_for_map(area)
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak"):
		var loaded := SaveStore.load_game(model, path)
		if not loaded.ok:
			hud.toast(loaded.message)
			return
		has_game = true
		paused = false
		speed = 1
		_accumulator = 0
		_day_report_shown = false
		view.home()
		hud.atlas.hide()
		hud.hide_menu()
		set_tool("inspect")
	else:
		start_game(true, area)
	passport.record(model)
	passport.save_to()
	hud.toast("Willkommen in %s. Jedes Gebiet behält seinen eigenen Spielstand." % Maps.spec(area).name)
	hud.refresh()

func continue_game() -> void:
	if not has_game:
		var result := SaveStore.load_game(model, SaveStore.path_for_map(passport.data.last_map))
		if not result.ok:
			hud.toast(result.message)
			return
		has_game = true
		_day_report_shown = false
		hud.toast(result.message)
	hud.hide_menu()
	hud.atlas.hide()
	set_tool("inspect")
	hud.refresh()

func show_menu() -> void:
	_clear_input()
	hud.show_menu()

func save_game() -> bool:
	if has_game:
		passport.record(model)
		passport.save_to()
		var result := SaveStore.save_game(model, SaveStore.path_for_map(model.map_id))
		hud.toast(result.message)
		return result.ok
	return false

func toggle_pause() -> void:
	paused = not paused
	hud.refresh()

func set_speed(value: int) -> void:
	speed = value
	paused = false
	hud.refresh()

func next_day() -> void:
	if model.next_day():
		_day_report_shown = false
		_accumulator = 0
		_update_plan()
		hud.refresh()
		save_game()

func manage_loan() -> void:
	var success: bool = model.repay_loan() if model.loan > 0 else model.take_loan()
	hud.toast("Kredit aktualisiert. Laufende Zinsen: 450 €/Tag bei offenem Kredit." if success else "Zur Tilgung werden 150.000 € benötigt.")
	hud.show_context("inspect")
	hud.refresh()

func set_tool(value: String) -> void:
	if value in ["lift", "building"] and model.build_access_message(hud.lift_kind() if value == "lift" else hud.building_kind(), value == "lift") != "":
		return
	tool = "piste" if value in ["blue", "red", "black"] else value
	points.clear()
	selected_waypoint = -1
	_drag_waypoint = -1
	snap_target = {}
	hud.show_context(tool)
	_update_plan()

func clear_plan() -> void:
	points.clear()
	selected_waypoint = -1
	snap_target = {}
	_update_plan()

func undo_point() -> void:
	if not points.is_empty():
		points.pop_back()
	selected_waypoint = -1
	snap_target = {}
	_update_plan()

func delete_waypoint() -> void:
	if selected_waypoint >= 0 and selected_waypoint < points.size():
		points.remove_at(selected_waypoint)
	selected_waypoint = -1
	snap_target = {}
	_update_plan()

func _snap_point(point: Vector2) -> Vector2:
	snap_target = model.snap_anchor(point) if tool in ["piste", "lift"] else {}
	return snap_target.point if not snap_target.is_empty() else point

func _begin_waypoint_drag(index: int) -> void:
	_drag_waypoint = index
	selected_waypoint = index
	_drag_original = points[index].duplicate()
	_update_plan()

func _move_waypoint(screen_point: Vector2) -> void:
	if _drag_waypoint < 0 or _drag_waypoint >= points.size():
		return
	var point := view.map_point(screen_point)
	if model.terrain.contains(point):
		points[_drag_waypoint] = Terrain.pack(_snap_point(point))
		_update_plan()

func _end_waypoint_drag(canceled: bool = false) -> void:
	if canceled and _drag_waypoint >= 0 and _drag_waypoint < points.size():
		points[_drag_waypoint] = _drag_original.duplicate()
	_drag_waypoint = -1
	_drag_original = []
	_update_plan()

func _plan_check() -> Dictionary:
	if tool in ["lift", "building"]:
		var access: String = model.build_access_message(hud.lift_kind() if tool == "lift" else hud.building_kind(), tool == "lift")
		if access != "":
			return {"ok": false, "message": access, "cost": 0}
	if tool == "piste":
		return model.terrain.analyse(points)
	if tool == "lift" and points.size() == 2:
		return model.preview_lift(hud.lift_kind(), Terrain.unpack(points[0]), Terrain.unpack(points[1]))
	if tool == "building" and points.size() == 1:
		return model.preview_building(hud.building_kind(), Terrain.unpack(points[0]))
	return {"ok": false, "message": "Talstation, dann Bergstation antippen." if tool == "lift" else "Einen Bauplatz antippen.", "cost": 0}

func _update_plan() -> void:
	if tool == "inspect":
		hud.plan("Dein Berg. Dein Resort. Wähle links ein Bauwerkzeug oder tippe eine Anlage an.", false, 0)
		hud.palette.route_profile.update_profile({})
		last_plan_check = {}
		view.preview([], Color.WHITE)
		return
	var check := _plan_check()
	last_plan_check = check
	hud.palette.route_profile.update_profile(check if tool == "piste" else {})
	var cost: float = check.get("cost", 0)
	var affordable: bool = cost <= model.money
	var message: String = check.message
	if points.is_empty() and tool == "piste":
		message = "Abfahrt planen: Start am Berg setzen, danach weitere Wegpunkte bis ins Tal."
	elif points.size() == 1 and tool == "piste":
		message = "Start bei %.0f m. Wegpunkte bergab setzen; Farbe und Schilder entstehen automatisch." % model.terrain.height(Terrain.unpack(points[0]))
	if not snap_target.is_empty():
		message += " · Angedockt: %s" % snap_target.label
	if selected_waypoint >= 0 and snap_target.is_empty():
		message += " · Punkt %d ausgewählt: ziehen zum Verschieben." % (selected_waypoint + 1)
	if not affordable:
		message += "  Das Budget reicht noch nicht."
	hud.plan(message, check.ok and affordable, points.size(), cost)
	view.preview(points, Color("75cdc7") if check.ok else Color("efb17d"), hud.building_kind() if tool == "building" else "", check if tool == "piste" else {})
	hud._refresh_context_text()

func confirm_plan() -> void:
	if tool == "inspect":
		if model.minute >= Resort.CLOSING:
			hud.show_report()
		return
	var check := _plan_check()
	if not check.ok:
		hud.toast(check.message)
		return
	var result: Dictionary
	if tool == "piste":
		result = model.build_piste(points)
	elif tool == "lift":
		result = model.build_lift(hud.lift_kind(), Terrain.unpack(points[0]), Terrain.unpack(points[1]))
	else:
		result = model.build_building(hud.building_kind(), Terrain.unpack(points[0]))
	if result.ok:
		points.clear()
		selected_waypoint = -1
		snap_target = {}
	hud.toast(result.message)
	_update_plan()
	hud.refresh()

func toggle_asset(id: int) -> void:
	var item: Dictionary = model.asset(id)
	if not item.is_empty():
		model.set_enabled(id, not item.enabled)
		hud.show_context("inspect", id)
		hud.refresh()

func demolish_asset(id: int) -> void:
	var result: Dictionary = model.demolish(id)
	hud.toast(result.message)
	hud.show_context("inspect")
	hud.refresh()
	_update_plan()

func _map_tap(position_value: Vector2) -> void:
	var point := view.map_point(position_value)
	if not model.terrain.contains(point):
		return
	if tool == "inspect":
		var visitor: int = view.pick_guest(position_value)
		if visitor != -1:
			hud.show_guest(visitor)
		else:
			hud.show_context(tool, view.pick_asset(point))
		return
	point = _snap_point(point)
	if tool == "building":
		points = [Terrain.pack(point)]
	elif tool == "lift" and points.size() >= 2:
		points[1] = Terrain.pack(point)
	elif points.size() < 64:
		points.append(Terrain.pack(point))
	selected_waypoint = -1
	_update_plan()

func _clear_input() -> void:
	if _drag_waypoint >= 0:
		_end_waypoint_drag(true)
	_mouse_down = false
	_touches.clear()
	_touch_origins.clear()
	_gesture_used = false
	_touch_dragged = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch_event(event)
		return
	if event is InputEventScreenDrag:
		_touch_drag(event)
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				if hud.blocks_map(event.position):
					return
				var handle := hud.plan_overlay.pick_waypoint(event.position) if event.button_index == MOUSE_BUTTON_LEFT else -1
				if handle >= 0:
					_begin_waypoint_drag(handle)
				_mouse_down = true
				_mouse_origin = event.position
				_mouse_dragged = event.button_index == MOUSE_BUTTON_MIDDLE
			elif _mouse_down:
				_mouse_down = false
				if _drag_waypoint >= 0:
					_end_waypoint_drag()
				elif not _mouse_dragged and not hud.blocks_map(event.position):
					_map_tap(event.position)
		elif not hud.blocks_map(event.position) and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				view.change_zoom(0.9)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				view.change_zoom(1.11)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				set_tool("inspect")
	elif event is InputEventMouseMotion and _mouse_down:
		if event.position.distance_to(_mouse_origin) > 7:
			_mouse_dragged = true
		if _drag_waypoint >= 0:
			_move_waypoint(event.position)
		elif _mouse_dragged:
			view.pan(event.relative)
	elif event is InputEventMagnifyGesture and not hud.blocks_map(event.position):
		view.change_zoom(1.0 / event.factor)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if hud.camera_dialog.visible:
				hud.camera_dialog.hide()
			elif hud.atlas.visible:
				hud.atlas.hide()
			elif hud.management.visible:
				hud.management.hide()
			elif hud.help_dialog.visible:
				hud.help_dialog.hide()
			elif hud.daily_dialog.visible:
				hud.daily_dialog.hide()
			elif hud.menu.visible and has_game:
				hud.hide_menu()
			elif tool != "inspect":
				set_tool("inspect")
			else:
				show_menu()
		elif not hud.menu.visible and not hud.camera_dialog.visible and not hud.help_dialog.visible and not hud.daily_dialog.visible and not hud.management.visible and not hud.atlas.visible:
			match event.keycode:
				KEY_SPACE: toggle_pause()
				KEY_Q: view.rotate_view(-0.2)
				KEY_E: view.rotate_view(0.2)
				KEY_B: set_tool("piste")
				KEY_DELETE: delete_waypoint()
				KEY_R: set_tool("piste")
				KEY_K: set_tool("piste")
				KEY_L: set_tool("lift")
				KEY_G: set_tool("building")
				KEY_F1: hud.show_help()
				KEY_M: hud.show_management()
				KEY_C: view.set_camera_mode((view.camera_mode + 1) % view.CAMERA_MODES.size())
				KEY_TAB: hud.set_map_focus(not hud.map_focus)
				KEY_S:
					if event.ctrl_pressed:
						save_game()

func _touch_event(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if hud.blocks_map(event.position):
			return
		if _touches.is_empty():
			_gesture_used = false
			_touch_dragged = false
		_touches[event.index] = event.position
		_touch_origins[event.index] = event.position
		if _touches.size() > 1:
			if _drag_waypoint >= 0:
				_end_waypoint_drag(true)
			_gesture_used = true
		else:
			var handle := hud.plan_overlay.pick_waypoint(event.position, 28)
			if handle >= 0:
				_begin_waypoint_drag(handle)
	elif _touches.has(event.index):
		if _drag_waypoint >= 0:
			_end_waypoint_drag(event.canceled)
		elif not event.canceled and _touches.size() == 1 and not _gesture_used and not _touch_dragged and not hud.blocks_map(event.position):
			if event.position.distance_to(_touch_origins[event.index]) < 12:
				_map_tap(event.position)
		_touches.erase(event.index)
		_touch_origins.erase(event.index)

func _touch_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var before := _touches.values()
	_touches[event.index] = event.position
	if _touches.size() >= 2:
		_gesture_used = true
		var after := _touches.values()
		var old_center: Vector2 = (before[0] + before[1]) * 0.5
		var new_center: Vector2 = (after[0] + after[1]) * 0.5
		view.pan(new_center - old_center)
		var previous_distance: float = before[0].distance_to(before[1])
		var distance: float = after[0].distance_to(after[1])
		if distance > 10 and previous_distance > 10:
			view.change_zoom(previous_distance / distance)
	else:
		if _drag_waypoint >= 0:
			_move_waypoint(event.position)
			return
		if event.position.distance_to(_touch_origins[event.index]) > 8:
			_touch_dragged = true
		if _touch_dragged:
			view.pan(event.relative)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if is_instance_valid(hud) and has_game:
			save_game()
		_clear_input()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if hud.camera_dialog.visible:
			hud.camera_dialog.hide()
			return
		if hud.atlas.visible:
			hud.atlas.hide()
			return
		if hud.management.visible:
			hud.management.hide()
			return
		if has_game:
			save_game()
		show_menu()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if has_game:
			save_game()
		get_tree().quit()

func _smoke_test() -> void:
	start_game(true)
	for i in range(160):
		model.advance_minute()
	set_tool("piste")
	points = [[245, -130], [290, 0], [200, 205]]
	_update_plan()
	await get_tree().process_frame
	hud.refresh()
	print("SMOKE PASS: scene, terrain, HUD, simulation and build preview; guests=", model.guests.size())
	get_tree().quit()

func _showcase() -> void:
	# Reproducible QA resort; these options are only used by developer captures.
	model.money = 1200000
	model.campaign.mode = "free"
	model.campaign.research = Resort.Progression.RESEARCH.keys()
	model.campaign.xp = 4000.0
	model.build_lift("chair", Vector2(100, 200), Vector2(-170, -235))
	model.build_piste([[-170, -235], [-160, -50], [-80, 90], [100, 190]], 2)
	model.build_piste([[245, -130], [190, -55], [140, 30], [100, 190]], 1)
	for entry in [["hotel", Vector2(80, 235)], ["school", Vector2(75, 292)], ["restaurant", Vector2(235, 310)], ["first_aid", Vector2(285, 240)], ["maintenance", Vector2(15, 245)], ["snowmaker", Vector2(300, 80)]]:
		model.build_building(entry[0], entry[1])
	for lift in model.lifts:
		model.upgrade_asset(lift.id)
	for building in model.buildings:
		if building.kind == "hotel":
			model.upgrade_asset(building.id)
	for i in range(60):
		model.advance_minute()
	Resort.Progression.begin_day(model)
	set_tool("inspect")
	view.focus = Vector2(100, 95)
	view.zoom = 590
	view._update_camera()
	hud.refresh()

func _junction_showcase() -> void:
	# Developer capture, built through the normal automatic planning/network APIs.
	model.new_game(false)
	model.money = 1500000
	var blue := [[-170, -235], [-150, -225], [-140, -225], [-120, -235], [-50, -305], [-20, -325], [200, -265], [240, -245], [200, -125], [200, 205]]
	model.build_lift("chair", Vector2(200, 205), Vector2(-170, -235))
	model.build_piste(blue)
	model.build_piste([blue[4], blue[7]])
	model.build_piste([blue[3], blue[8]])
	model.build_building("lodge", Vector2(235, 252))
	model.build_building("rental", Vector2(145, 235))
	for i in range(40):
		model.admit_guest(i % 3)
	for i in range(260):
		model.advance_minute()
	view.rebuild()
	view.focus = Vector2(35, -140)
	view.zoom = 900
	view.yaw = 0
	view.set_camera_mode(3)
	set_tool("inspect")
	hud.refresh()

func _capture(path: String) -> void:
	if OS.get_cmdline_user_args().has("--capture-game"):
		start_game(true)
		paused = true
		for i in range(120):
			model.advance_minute()
		hud.refresh()
	if OS.get_cmdline_user_args().has("--capture-junctions"):
		_junction_showcase()
	if OS.get_cmdline_user_args().has("--capture-showcase"):
		_showcase()
	if OS.get_cmdline_user_args().has("--capture-ski"):
		for i in range(100):
			model.advance_minute()
		for guest in model.guests:
			if guest.phase == "moving" and guest.leg < guest.route.legs.size() and guest.route.legs[guest.leg].kind == "ski" and guest.elapsed / guest.duration > 0.25 and guest.elapsed / guest.duration < 0.75:
				var position_value: Vector3 = model.guest_position(guest)
				view.focus = Vector2(position_value.x, position_value.z)
				view.zoom = 70
				view.follow_guest = guest.id
				view._update_camera()
				hud.show_guest(guest.id)
				break
	if OS.get_cmdline_user_args().has("--capture-atlas"):
		hud.show_atlas()
	if OS.get_cmdline_user_args().has("--capture-catalogue"):
		hud.palette.select_category("village")
	if OS.get_cmdline_user_args().has("--capture-region"):
		model.new_game(true, 20261027, "dreigipfel")
		view.rebuild()
		view.overview()
		hud.hide_menu()
		hud.set_map_focus(true)
		hud.refresh()
	if OS.get_cmdline_user_args().has("--capture-office"):
		hud.show_management(0)
	if OS.get_cmdline_user_args().has("--capture-map"):
		hud.set_map_focus(true)
	if OS.get_cmdline_user_args().has("--capture-detail"):
		view.focus = Vector2(150, 220)
		view.zoom = 340
		view._update_camera()
	if OS.get_cmdline_user_args().has("--capture-slopes"):
		hud.toggle_slopes()
		hud.set_map_focus(true)
	if OS.get_cmdline_user_args().has("--capture-top"):
		view.set_camera_mode(3)
	if OS.get_cmdline_user_args().has("--capture-plan"):
		set_tool("piste")
		points = [[-170, -235], [-150, -225], [-140, -225], [-120, -235], [-50, -305], [-20, -325], [200, -265], [240, -245], [200, -125], [200, 205]]
		selected_waypoint = 6
		view.focus = Vector2(20, -100)
		view.zoom = 800
		view.yaw = 0
		view.set_camera_mode(3)
		_update_plan()
	if OS.get_cmdline_user_args().has("--capture-camera"):
		hud.show_camera()
	if OS.get_cmdline_user_args().has("--capture-signs"):
		view.focus = Vector2(255, -18)
		view.zoom = 48
		view.yaw = -0.15
		view.set_camera_mode(1)
		hud.set_map_focus(true)

	for i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("CAPTURE: ", path, " result=", error)
	get_tree().quit(error)
