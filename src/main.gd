extends Node3D

const Resort = preload("res://src/core/resort.gd")
const Terrain = preload("res://src/core/terrain.gd")
const SaveStore = preload("res://src/core/save_store.gd")
const ResortView = preload("res://src/world/resort_view.gd")
const ResortHUD = preload("res://src/ui/hud.gd")

var model := Resort.new()
var view := ResortView.new()
var hud := ResortHUD.new()
var tool := "inspect"
var points: Array = []
var paused := false
var speed := 1
var has_game := false
var _accumulator := 0.0
var _refresh_timer := 0.0
var _day_report_shown := false
var _mouse_down := false
var _mouse_origin := Vector2.ZERO
var _mouse_dragged := false
var _touches: Dictionary = {}
var _touch_origins: Dictionary = {}
var _touch_dragged := false
var _gesture_used := false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	model.new_game(true)
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
	if has_game and not paused and not hud.menu.visible and not hud.help_dialog.visible and model.minute < Resort.CLOSING:
		_accumulator += minf(delta, 0.25) * speed * 2.0
		while _accumulator >= 1.0 and model.minute < Resort.CLOSING:
			_accumulator -= 1.0
			model.advance_minute()
	if has_game and model.minute >= Resort.CLOSING and not _day_report_shown:
		_day_report_shown = true
		save_game()
		hud.show_report()
		_update_plan()
	_refresh_timer += delta
	if _refresh_timer >= 0.4:
		_refresh_timer = 0.0
		hud.refresh()

func start_game(starter: bool) -> void:
	model.new_game(starter)
	has_game = true
	paused = false
	speed = 1
	_accumulator = 0
	_day_report_shown = false
	view.home()
	hud.hide_menu()
	hud.set_map_focus(false)
	set_tool("inspect")
	hud.toast("Dein Sonnenhang ist eröffnet. Der blaue Rundweg ist bereits in Betrieb." if starter else "Freies Gelände: Plane zuerst einen Lift und einen blauen Rundweg.")
	hud.refresh()

func continue_game() -> void:
	if not has_game:
		var result := SaveStore.load_game(model)
		if not result.ok:
			hud.toast(result.message)
			return
		has_game = true
		_day_report_shown = false
		hud.toast(result.message)
	hud.hide_menu()
	set_tool("inspect")
	hud.refresh()

func show_menu() -> void:
	_clear_input()
	hud.show_menu()

func save_game() -> void:
	if has_game:
		var result := SaveStore.save_game(model)
		hud.toast(result.message)

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
	tool = value
	points.clear()
	hud.show_context(tool)
	_update_plan()

func clear_plan() -> void:
	points.clear()
	_update_plan()

func undo_point() -> void:
	if not points.is_empty():
		points.pop_back()
	_update_plan()

func _plan_check() -> Dictionary:
	if tool in ["blue", "red", "black"]:
		return Terrain.analyse(points, {"blue": 0, "red": 1, "black": 2}[tool])
	if tool == "lift" and points.size() == 2:
		return model.preview_lift(hud.lift_kind(), Terrain.unpack(points[0]), Terrain.unpack(points[1]))
	if tool == "building" and points.size() == 1:
		return model.preview_building(hud.building_kind(), Terrain.unpack(points[0]))
	return {"ok": false, "message": "Talstation, dann Bergstation antippen." if tool == "lift" else "Einen Bauplatz antippen.", "cost": 0}

func _update_plan() -> void:
	if tool == "inspect":
		hud.plan("Dein Berg. Dein Resort. Wähle links ein Bauwerkzeug oder tippe eine Anlage an.", false, 0)
		view.preview([], Color.WHITE)
		return
	var check := _plan_check()
	var cost: float = check.get("cost", 0)
	var affordable: bool = cost <= model.money
	var message: String = check.message
	if points.is_empty() and tool in ["blue", "red", "black"]:
		message = "Abfahrt planen: Start am Berg setzen, danach weitere Wegpunkte bis ins Tal."
	elif points.size() == 1 and tool in ["blue", "red", "black"]:
		message = "Start gesetzt. Weitere Wegpunkte bergab setzen und anschließend Bauen wählen."
	if not affordable:
		message += "  Das Budget reicht noch nicht."
	hud.plan(message, check.ok and affordable, points.size(), cost)
	view.preview(points, Color("75cdc7") if check.ok else Color("efb17d"), hud.building_kind() if tool == "building" else "")

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
	if tool in ["blue", "red", "black"]:
		result = model.build_piste(points, {"blue": 0, "red": 1, "black": 2}[tool])
	elif tool == "lift":
		result = model.build_lift(hud.lift_kind(), Terrain.unpack(points[0]), Terrain.unpack(points[1]))
	else:
		result = model.build_building(hud.building_kind(), Terrain.unpack(points[0]))
	if result.ok:
		points.clear()
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
	if not Terrain.contains(point):
		return
	if tool == "inspect":
		hud.show_context(tool, view.pick_asset(point))
		return
	# Visible station snapping makes touch connections forgiving and exact.
	if tool != "building":
		var snap_distance := 22.0
		for lift in model.lifts:
			for station in [lift.bottom, lift.top]:
				var candidate := Terrain.unpack(station)
				if point.distance_to(candidate) < snap_distance:
					snap_distance = point.distance_to(candidate)
					point = candidate
	if tool == "building":
		points = [Terrain.pack(point)]
	elif tool == "lift" and points.size() >= 2:
		points[1] = Terrain.pack(point)
	elif points.size() < 64:
		points.append(Terrain.pack(point))
	_update_plan()

func _clear_input() -> void:
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
				_mouse_down = true
				_mouse_origin = event.position
				_mouse_dragged = event.button_index == MOUSE_BUTTON_MIDDLE
			elif _mouse_down:
				_mouse_down = false
				if not _mouse_dragged and not hud.blocks_map(event.position):
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
		if _mouse_dragged:
			view.pan(event.relative)
	elif event is InputEventMagnifyGesture and not hud.blocks_map(event.position):
		view.change_zoom(1.0 / event.factor)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if hud.menu.visible and has_game:
				hud.hide_menu()
			elif tool != "inspect":
				set_tool("inspect")
			else:
				show_menu()
		elif not hud.menu.visible and not hud.help_dialog.visible and not hud.daily_dialog.visible:
			match event.keycode:
				KEY_SPACE: toggle_pause()
				KEY_Q: view.rotate_view(-0.2)
				KEY_E: view.rotate_view(0.2)
				KEY_B: set_tool("blue")
				KEY_R: set_tool("red")
				KEY_K: set_tool("black")
				KEY_L: set_tool("lift")
				KEY_G: set_tool("building")
				KEY_F1: hud.show_help()
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
			_gesture_used = true
	elif _touches.has(event.index):
		if not event.canceled and _touches.size() == 1 and not _gesture_used and not _touch_dragged and not hud.blocks_map(event.position):
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
	set_tool("blue")
	points = [[245, -130], [290, 0], [200, 205]]
	_update_plan()
	await get_tree().process_frame
	hud.refresh()
	print("SMOKE PASS: scene, terrain, HUD, simulation and build preview; guests=", model.guests.size())
	get_tree().quit()

func _capture(path: String) -> void:
	if OS.get_cmdline_user_args().has("--capture-game"):
		start_game(true)
		paused = true
		for i in range(120):
			model.advance_minute()
		hud.refresh()
	if OS.get_cmdline_user_args().has("--capture-slopes"):
		hud.toggle_slopes()
		hud.set_map_focus(true)
	for i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("CAPTURE: ", path, " result=", error)
	get_tree().quit(error)
