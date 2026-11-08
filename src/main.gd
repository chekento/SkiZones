extends Node3D

const Geo = preload("res://src/core/real_resorts.gd")
const Ops = preload("res://src/core/operations.gd")
const DayRhythm = preload("res://src/core/day_rhythm.gd")
const Resort = preload("res://src/core/resort.gd")
const ResortAudio=preload("res://src/world/resort_audio.gd")
const Progression = preload("res://src/core/progression.gd")
const L = preload("res://src/core/i18n.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Passport = preload("res://src/core/passport.gd")
const Maps = preload("res://src/core/maps.gd")
const CustomMaps040 = preload("res://src/core/custom_maps_040.gd")
const SaveStore = preload("res://src/core/save_store.gd")
const StartTiers = preload("res://src/core/start_tiers.gd")
const LoadProgress = preload("res://src/core/load_progress.gd")
const AppSession = preload("res://src/core/app_session.gd")
const ResortView = preload("res://src/world/resort_view.gd")
const Preferences = preload("res://src/core/preferences.gd")
const AppUpdater = preload("res://src/core/app_updater.gd")
const ResortHUD = preload("res://src/ui/hud.gd")

var updater := AppUpdater.new()
var preferences := Preferences.new()
var editing_id := -1
var edit_title := ""
var edit_color := ""
var edit_rotation := 0
var edit_width := 20.0
var plan_width := 20.0
var _drag_screen_offset := Vector2.ZERO
var _edit_original: Array = []
var model := Resort.new()
var passport := Passport.new()
var view := ResortView.new()
var hud := ResortHUD.new()
var tool := "inspect"
var plaza_kind := "plaza"
const WalkwayDesign = preload("res://src/core/walkway_design.gd")
var walkway_surface := "snow"
var walkway_freehand := true
var _stroke: Array = []
var _stroke_original: Array = []
var _stroke_active := false
var _stroke_drawn := false
var _stroke_too_long := false
var _committing := false
var _plan_dirty := false
var points: Array = []
var undone_points: Array = []
var last_plan_check: Dictionary = {}
var selected_waypoint := -1
var _drag_waypoint := -1
var _drag_original: Array = []
var _drag_press_position := Vector2.INF
var _drag_has_moved := false
var snap_target: Dictionary = {}
var paused := false
var speed := 1
var _lift_camera_auto := false
var _lift_camera_previous := 0
var _lift_camera_previous_pitch := 34.0
var _lift_slopes_previous := false
var _lift_camera_manual := false
var _lift_slopes_manual := false
var _last_saved_marker := ""
var _last_saved_at := 0
var _save_failed := false
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
var app_session := AppSession.new()
var _app_background := false
var _background_started := 0
var _background_running := false
var _background_speed := 1
var _resume_scheduled := false
var resume_count := 0
var _load_progress: RefCounted = null
var audio := ResortAudio.new()

func _ready() -> void:
	preferences.load_from()
	L.configure(preferences.language)
	if not CustomMaps040.install():push_warning("Custom map registry is damaged; original files preserved")
	SaveStore.active_free_slot = preferences.free_save_slot
	SaveStore.migrate_legacy()
	SaveStore.active_slot=0 if preferences.free_play else preferences.career_slot
	get_tree().auto_accept_quit = false
	passport.load_from(SaveStore.passport_path())
	model.new_game(true, 20261027, "sonnenhang")
	add_child(view)
	view.setup(model)
	add_child(updater)
	updater.setup(self)
	add_child(hud)
	hud.setup(self)
	preferences.apply(view)
	audio.set_active(false)
	add_child(audio)
	audio.setup(view,preferences)
	hud.show_menu()
	_update_plan()
	if OS.get_name() == "Android":
		await _restore_android_session()
	if OS.has_feature("android_lifecycle_test"):
		call_deferred("_start_android_lifecycle_test")
	# Deterministic captures and boot checks are also used by CI.
	for argument in OS.get_cmdline_user_args():
		if argument == "--smoke-test":
			call_deferred("_smoke_test")
		elif argument.begins_with("--capture="):
			call_deferred("_capture", argument.trim_prefix("--capture="))

func apply_language(value: String) -> void:
	if value not in ["system","de","en"]: return
	preferences.language=value
	_clear_input()
	var previous: CanvasLayer=hud
	var show_main: bool=previous.menu.visible
	var old_map_focus: bool=previous.map_focus
	var old_lift: int=previous.lift_choice.selected
	var old_building: int=previous.building_choice.selected
	var selected_asset: int=previous.selected_id
	var selected_guest: int=previous.selected_guest
	remove_child(previous)
	L.configure(value)
	view.relocalize()
	model._anchor_revision=-1
	hud=ResortHUD.new()
	add_child(hud)
	hud.setup(self)
	hud.lift_choice.select(old_lift)
	hud.building_choice.select(old_building)
	if show_main: hud.show_menu()
	else:
		hud.hide_menu()
		hud.show_context(tool,selected_asset)
		if selected_guest != -1: hud.show_guest(selected_guest)
		hud.set_map_focus(old_map_focus)
	_update_plan()
	previous.queue_free()
	hud.toast(L.text("Sprache angewendet."))

func _process(delta: float) -> void:
	audio.set_active(not _app_background and not hud.loading.visible and ((has_game and not hud.menu.visible) or hud.jukebox.visible))
	if _load_progress != null and hud.loading.visible:
		hud.apply_loading_state(_load_progress.snapshot())
		view.motion_running = false
		return
	if _app_background:
		view.motion_running = false
		return
	if _plan_dirty:
		_plan_dirty = false
		_update_plan()
	if simulation_running():
		_accumulator += minf(delta, 0.25) * speed * Resort.MINUTES_PER_SECOND * (4.0 if model.time_divisor>1 else 1.0) * DayRhythm.playback(model.minute, preferences.day_length)
		var budget_end := Time.get_ticks_usec() + 6000
		if preferences.night_forward and model.empty_night():
			var night_day: int=model.day
			for step in range(180):
				if Time.get_ticks_usec()>=budget_end or not model.advance_empty_minute(): break
			if model.day!=night_day: call_deferred("save_game")
		while _accumulator >= 1.0 and not model.day_finished() and Time.get_ticks_usec() < budget_end:
			_accumulator -= 1.0
			var previous_day: int = model.day
			model.advance_minute()
			if model.day != previous_day: call_deferred("save_game")
	simulation_fraction = fmod(_accumulator,1.0)
	view.simulation_fraction = simulation_fraction
	view.motion_running = simulation_running()
	view.motion_rate = float(speed)*(4.0 if model.time_divisor>1 else 1.0)*DayRhythm.playback(model.minute, preferences.day_length)
	if has_game and model.day_finished() and not _day_report_shown:
		_day_report_shown = true
		save_game()
		hud.show_report()
		_update_plan()
	_refresh_timer += delta
	if _refresh_timer >= 0.4:
		_refresh_timer = 0.0
		hud.refresh()

func simulation_running() -> bool:
	return has_game and not _app_background and not paused and points.is_empty() and not _stroke_drawn and not hud.piste_workshop.visible and not (hud.building_browser.visible and hud.building_browser.window.fullscreen) and not hud.experience.visible and not hud.winter_festival.visible and not hud.seasonal_poster.visible and not hud.piste_map_window.visible and not hud.jukebox.visible and not hud.medal_cabinet.visible and not hud.update_dialog.visible and not hud.career_slots.visible and not hud.audience.visible and not hud.lift_staff.visible and not hud.asset_editor.visible and not hud.display_options.visible and not hud.menu.visible and not hud.camera_dialog.visible and not hud.help_dialog.visible and not hud.daily_dialog.visible and not hud.management.visible and not hud.atlas.visible and not hud.scenarios.visible and not hud.credits.visible and not hud.loading.visible and not model.day_finished()

func start_cinematic_tour() -> void:
	if not has_game or hud.menu.visible or not points.is_empty() or hud.loading.visible: return
	view.tour.set_attention(preferences.cinematic_attention)
	if view.tour.begin(view):
		hud.set_cinema_mode(true)

func stop_cinematic_tour() -> void:
	if view.tour.active: view.tour.stop(view)
	hud.set_cinema_mode(false)

func start_game(starter: bool, area: String = "sonnenhang", prepared: RefCounted = null) -> void:
	stop_cinematic_tour()
	if not Maps.MAPS.has(area):
		hud.toast(L.text("Dieses Gebiet steht nicht zur Verfügung."))
		return
	if prepared != null:
		model = prepared
		view.model = model
		view._seen_revision = -1
	else:
		model.new_game(starter, 20261027, area, true)
		# The previous loaded resort may have the same revision counter.
		# Explicitly rebuild new free/career games instead of showing stale mesh.
		view._seen_revision = -1
		view.foot_wear.reset()
		view.rebuild()
	if not Ops.active(model): Ops.enable(model)
	if model.map_id in Geo.IDS and model.operations.get("completed",false):
		preload("res://src/core/scenario_medals.gd").new().record(model.map_id,str(model.operations.get("scenario_difficulty","normal")))
	model.enable_runtime_rules()
	hud.scenarios.hide()
	passport.record(model)
	has_game = true
	_last_saved_marker = _save_state_marker() if prepared != null else ""
	_save_failed = false
	paused = false
	speed = 1
	_accumulator = 0
	_day_report_shown = false
	view.home()
	hud.hide_menu()
	hud.atlas.hide()
	hud.set_map_focus(false)
	set_tool("inspect")
	hud.toast(L.text("Willkommen am Berg. Die Tage lassen dir mehr Zeit, die Gäste bewegen sich flotter. Mit 4× spulst du weiter vor. Tippe einen Gast zum Beobachten an.") if starter else L.text("Freier Aufbau: Alle Anlagen sind verfügbar. Plane deinen ersten Rundweg."))
	hud.refresh()

func _prepare_area(area: String, saved: bool, slot: int = -1) -> Dictionary:
	view.loading_in_progress = true
	_load_progress = LoadProgress.new()
	_load_progress.report(0.0, L.text("Dein Resort wird vorbereitet …"))
	hud.apply_loading_state(_load_progress.snapshot())
	hud.loading.show()
	await get_tree().process_frame
	# Shared immutable geodata stays initialized on the main thread; each
	# expensive worker owns its model and reports actual item counters.
	if area in Geo.IDS:
		_load_progress.report(1.0, L.text("Höhendaten des ausgewählten Gebiets laden …"))
		await get_tree().process_frame
		Geo.height(Terrain.BASE, area)
		_load_progress.report(4.0, L.text("Lifte und Pisten des Gebiets einlesen …"))
		await get_tree().process_frame
		Geo.baked(area)
	var worker := Thread.new()
	var status: RefCounted = _load_progress
	var selected_slot := SaveStore.active_slot if slot < 0 else slot
	var error := worker.start(func():
		var candidate := Resort.new()
		candidate.load_progress = status
		var result := {"ok": true, "message": ""}
		if saved:
			result = SaveStore.load_game(candidate, SaveStore.path_for_map(area,selected_slot), status)
		else:
			status.report(10.0, L.text("Resort und Startgebäude vorbereiten …"))
			candidate.new_game(selected_slot != 0 or area in Geo.IDS, 20261027, area, true)
		if result.ok:
			status.report(63.0, L.text("Personal und Betriebsabläufe vorbereiten …"))
			if not Ops.active(candidate): Ops.enable(candidate)
			candidate.enable_runtime_rules()
			Ops.refresh_duty(candidate)
			candidate._operating_signature = Ops.signature(candidate)
			for skill in [0, 1, 2]:
				status.report(65.0 + skill * 4.0, L.text("Gästerouten für alle Könnensstufen vorbereiten …"), skill, 3)
				candidate.routes_for(skill)
				candidate._routing_graph(skill, true)
			status.report(79.0, L.text("Gästerouten vorbereitet"), 3, 3)
		candidate.load_progress = null
		return {"model": candidate, "result": result}
	)
	if error != OK:
		view.loading_in_progress = false
		hud.loading.hide()
		return {"result": {"ok": false, "message": L.text("Das Resort konnte nicht vorbereitet werden.")}}
	while worker.is_alive():
		await get_tree().process_frame
	var prepared: Variant = worker.wait_to_finish()
	if not prepared is Dictionary or not prepared.get("result") is Dictionary:
		view.loading_in_progress = false
		hud.loading.hide()
		return {"result": {"ok": false, "message": L.text("Das Laden wurde unterbrochen. Der vorhandene Spielstand bleibt unverändert.")}}
	_load_progress.report(80.0, L.text("Bergwelt und Gelände anzeigen …"))
	return prepared

func _restore_android_session() -> void:
	var state := app_session.read_state()
	# Preserve dormant scenario saves without opening them on normal-mode startup.
	if state.is_empty() or not Maps.MAPS.has(state.map): return
	var slot:=SaveStore.slot_from_state(state)
	if slot == 0:
		SaveStore.active_free_slot = clampi(int(state.get("free_save_slot", 1)), 1, 4)
		preferences.free_save_slot = SaveStore.active_free_slot
	if not SaveStore.session_source_matches(state.map, slot, state.checksum): return
	var prepared := await _prepare_area(state.map, true,slot)
	if not prepared.result.ok:
		view.loading_in_progress = false
		hud.loading.hide()
		return
	model = prepared.model
	view.model = model
	view._seen_revision = -1
	await view.rebuild(_load_progress)
	if not app_session.restore(self, true, false):
		SaveStore.active_slot = slot
		preferences.free_play = slot == 0
		if slot > 0: preferences.career_slot = slot
		else: preferences.free_save_slot = SaveStore.active_free_slot
		passport.load_from(SaveStore.passport_path(slot))
		start_game(true, state.map, model)
	_load_progress.report(100.0, L.text("Bergwelt bereit"))
	await get_tree().process_frame
	hud.loading.hide()
	if prepared.result.get("recovered", false): hud.toast(prepared.result.message)

func enter_area(area: String, difficulty: String = "") -> void:
	if hud.loading.visible: return
	if not Maps.MAPS.has(area):
		hud.toast(L.text("Dieses Gebiet steht nicht zur Verfügung."))
		return
	# Existing, checksum-valid careers always remain accessible even when an
	# old passport was lost, not migrated, or out of sync with the resort.
	# Only brand-new mountain creation needs the unlock gate.
	var own_save_path: String = SaveStore.path_for_map(area)
	var has_saved_resort: bool = SaveStore.has_any_save(area)
	if SaveStore.active_slot != 0 and not passport.unlocked(area) and not has_saved_resort:
		hud.toast(L.text("Dieses Gebiet wird durch deinen Bergpass freigeschaltet."))
		return
	if has_game and model.map_id == area:
		if area in Geo.IDS and difficulty in ["relaxed","normal","expert"]: Ops.set_scenario_difficulty(model,difficulty)
		hud.atlas.hide()
		hud.scenarios.hide()
		hud.hide_menu()
		return
	if has_game and not save_game(): return
	var path := SaveStore.path_for_map(area)
	# The old installation may still own a legacy file without a new-slot copy.
	# Its migrations are retried idempotently and never overwrite player data.
	if not has_saved_resort: SaveStore.migrate_legacy()
	var prepared := await _prepare_area(area, has_saved_resort or SaveStore.has_any_save(area))
	if not prepared.result.ok:
		view.loading_in_progress = false
		hud.loading.hide()
		hud.toast(prepared.result.message)
		return
	start_game(true, area, prepared.model)
	if area in Geo.IDS and difficulty in ["relaxed","normal","expert"]:
		Ops.set_scenario_difficulty(model,difficulty)
	await view.rebuild(_load_progress)
	_load_progress.report(100.0, L.text("Bergwelt bereit"))
	await get_tree().process_frame
	hud.loading.hide()
	passport.record(model)
	passport.save_to(SaveStore.passport_path())
	hud.toast(prepared.result.message if prepared.result.get("recovered", false) else L.text("Willkommen in %s. Jedes Gebiet behält seinen eigenen Spielstand.") % L.args(Maps.spec(area).name))
	hud.refresh()

func continue_game() -> void:
	if not has_game:
		await enter_area(main_game_area())
		return
	hud.hide_menu()
	hud.atlas.hide()
	set_tool("inspect")
	hud.refresh()

func show_career_slots() -> void:
	if has_game and not save_game(): return
	hud.career_slots.open()

func _select_save_context(slot: int, free_slot: int = 1) -> void:
	SaveStore.active_slot=clampi(slot,0,4)
	if slot == 0: SaveStore.active_free_slot=clampi(free_slot,1,4)
	preferences.free_play=slot==0
	if slot>0: preferences.career_slot=slot
	else: preferences.free_save_slot=SaveStore.active_free_slot
	preferences.save_to()
	passport=Passport.new()
	passport.load_from(SaveStore.passport_path())
	has_game=false

func select_career_slot(slot: int, fresh: bool = false, tier: int = 2) -> void:
	if slot<1 or slot>4: return
	if has_game and not save_game(): return
	if fresh and (SaveStore.summary(slot).occupied or FileAccess.file_exists(SaveStore.passport_path(slot))) and not SaveStore.archive_slot(slot):
		hud.toast(L.text("Die Sicherung ist fehlgeschlagen. Die Karriere bleibt erhalten."))
		return
	_select_save_context(slot)
	hud.career_slots.hide()
	if fresh:
		start_game(true)
		StartTiers.apply(model, tier)
		hud.refresh()
		save_game()
	else:
		var saved:=SaveStore.summary(slot)
		await enter_area(saved.get("map","sonnenhang"))

func select_career_area(slot: int, area: String) -> void:
	if slot < 1 or slot > 4 or area not in Maps.FANTASY_MAPS: return
	if not SaveStore.has_any_save(area, slot): return
	if has_game and not save_game(): return
	_select_save_context(slot)
	hud.career_slots.hide()
	await enter_area(area)

## Open a custom resort in its own career/free game-save namespace.
## The terrain registry was loaded and checked before SaveStore initialization.
func open_custom_map(id: String) -> void:
	if not Maps.CUSTOM_MAPS.has(id):
		hud.toast(L.text("Diese eigene Karte ist nicht verfügbar."))
		return
	if hud.loading.visible:return
	hud.map_creator_040.hide()
	await enter_area(id)

func start_free_play() -> void:
	show_free_slots()

func show_free_slots() -> void:
	if has_game and not save_game(): return
	hud.career_slots.open_free()

func select_free_slot(free_slot: int, fresh: bool = false) -> void:
	if free_slot < 1 or free_slot > 4: return
	if has_game and not save_game(): return
	if fresh and SaveStore.free_summary(free_slot).occupied and not SaveStore.archive_free_slot(free_slot):
		hud.toast(L.text("Die Sicherung ist fehlgeschlagen. Die Karriere bleibt erhalten."))
		return
	_select_save_context(0, free_slot)
	hud.career_slots.hide()
	if fresh:
		start_game(false)
		save_game()
	else:
		var saved: Dictionary = SaveStore.free_summary(free_slot)
		if saved.occupied: await enter_area(str(saved.map))
		else:
			start_game(false)
			save_game()

func select_free_area(free_slot: int, area: String) -> void:
	if free_slot < 1 or free_slot > 4 or area not in Maps.FANTASY_MAPS: return
	if not SaveStore.has_any_save(area, 0, free_slot): return
	if has_game and not save_game(): return
	_select_save_context(0, free_slot)
	hud.career_slots.hide()
	await enter_area(area)

func main_game_area() -> String:
	if has_game and Maps.is_player_map(model.map_id): return model.map_id
	if Maps.is_player_map(passport.data.last_map) and SaveStore.has_readable_save(passport.data.last_map):
		return passport.data.last_map
	var saved: Array = SaveStore.saved_resorts(SaveStore.active_slot)
	if not saved.is_empty(): return str(saved[0].map)
	return "sonnenhang"

func continue_main_game() -> void:
	var area := main_game_area()
	if has_game and model.map_id == area: continue_game()
	else: await enter_area(area)

func show_menu() -> void:
	stop_cinematic_tour()
	hud.experience.close()
	_clear_input()
	hud.show_menu()

func _save_state_marker() -> String:
	# Lightweight change signature; never serialize the full mountain each frame.
	return "%d/%d/%d/%d/%d/%d/%d/%.2f/%d/%d/%d" % [model.revision, model.day, model.minute, model.clock_steps, model.motion_tick, model.total_guests, model.total_rides, float(model.money), model.pistes.size(), model.lifts.size(), model.buildings.size()]

func save_game() -> bool:
	if has_game:
		# Freeze only the bounded visible snow-wear state alongside the same
		# checksum-protected resort snapshot. Old versions remain readable.
		if view.model == model: model.foot_wear_cells = view.foot_wear.export_state()
		passport.record(model)
		if not passport.save_to(SaveStore.passport_path()):
			_save_failed = true
			hud.toast(L.text("Die Sicherung ist fehlgeschlagen. Die Karriere bleibt erhalten."))
			return false
		var result := SaveStore.save_game(model, SaveStore.path_for_map(model.map_id))
		if result.ok:
			_last_saved_marker = _save_state_marker()
			_last_saved_at = Time.get_ticks_msec()
			_save_failed = false
			app_session.save(self)
		else:
			_save_failed = true
		hud.toast(result.message)
		hud.refresh()
		return result.ok
	return false

func toggle_pause() -> void:
	paused = not paused
	hud.refresh()

## The internal fourfold movement baseline is independent of the player's
## selectable 1x/4x/8x clock rate. Clear any queued old-rate catch-up when
## downshifting, including after an Android resume or an empty-night skip.
func set_speed(value: int) -> void:
	if value not in [1, 4, 8]: return
	speed = value
	paused = false
	_accumulator = fmod(maxf(0.0, _accumulator), 1.0)
	hud.refresh()

func cycle_speed() -> void:
	var choices := [1, 4, 8]
	set_speed(choices[(choices.find(speed) + 1) % choices.size()])

func note_manual_camera_change() -> void:
	if _lift_camera_auto: _lift_camera_manual = true

func note_manual_slopes_change() -> void:
	if _lift_camera_auto: _lift_slopes_manual = true

## Lift planning is a temporary terrain-assisted camera mode, not a
## permanent preference. Individual manual changes take precedence.
func _begin_lift_camera() -> void:
	if _lift_camera_auto: return
	_lift_camera_auto = true
	_lift_camera_manual = false
	_lift_slopes_manual = false
	_lift_camera_previous = view.camera_mode
	_lift_camera_previous_pitch = view.pitch_degrees
	_lift_slopes_previous = view.slopes_visible
	view.set_camera_mode(2)
	if not view.slopes_visible: view.toggle_slopes()
	hud._sync_camera_controls()
	hud.slopes_button.modulate = hud.ACCENT if view.slopes_visible else Color.WHITE
	hud._apply_panel_visibility()

func _end_lift_camera() -> void:
	if not _lift_camera_auto: return
	_lift_camera_auto = false
	if not _lift_camera_manual:
		view.set_camera_mode(_lift_camera_previous)
		if _lift_camera_previous != 3:
			view.set_camera_pitch(_lift_camera_previous_pitch)
	if not _lift_slopes_manual and view.slopes_visible != _lift_slopes_previous:
		view.toggle_slopes()
	hud._sync_camera_controls()
	hud.slopes_button.modulate = hud.ACCENT if view.slopes_visible else Color.WHITE
	hud._apply_panel_visibility()

func next_day() -> void:
	if model.next_day():
		_day_report_shown = false
		_accumulator = 0
		_update_plan()
		hud.refresh()
		save_game()

func manage_loan() -> void:
	var success: bool = model.repay_loan() if model.loan > 0 else model.take_loan()
	hud.toast(L.text("Kredit aktualisiert. Laufende Zinsen: 450 €/Tag bei offenem Kredit.") if success else L.text("Zur Tilgung werden 150.000 € benötigt."))
	hud.show_context("inspect")
	hud.refresh()

func set_tool(value: String) -> void:
	value = "piste" if value in ["blue", "red", "black"] else value
	if not points.is_empty() and value != "inspect":
		hud.toast(L.text("Erst Bauen oder Abbrechen wählen. Dein Plan bleibt erhalten."))
		return
	_clear_input()
	if value in ["lift", "building"] and model.build_access_message(hud.lift_kind() if value == "lift" else hud.building_kind(), value == "lift") != "":
		return
	editing_id = -1
	edit_rotation = 0
	if tool == "lift" and value != "lift": _end_lift_camera()
	tool = "piste" if value in ["blue", "red", "black"] else value
	if tool == "lift": _begin_lift_camera()
	points.clear()
	undone_points.clear()
	selected_waypoint = -1
	_drag_waypoint = -1
	snap_target = {}
	hud.show_context(tool)
	_update_plan()

func clear_plan() -> void:
	_clear_input()
	points.clear()
	selected_waypoint = -1
	snap_target = {}
	set_tool("inspect")
	hud.toast(L.text("Planung beendet. Es wurde nichts ausgegeben."))

func undo_point() -> void:
	if tool not in ["piste", "lift", "walkway"] or points.is_empty():
		return
	undone_points.append(points.pop_back())
	selected_waypoint = -1
	snap_target = {}
	_update_plan()

func redo_point() -> void:
	if tool not in ["piste", "lift", "walkway"] or undone_points.is_empty():
		return
	if points.size() >= (2 if tool == "lift" else 64):
		return
	points.append(undone_points.pop_back())
	selected_waypoint = -1
	snap_target = {}
	_update_plan()

func delete_waypoint() -> void:
	if selected_waypoint >= 0 and selected_waypoint < points.size():
		points.remove_at(selected_waypoint)
		undone_points.clear()
	selected_waypoint = -1
	snap_target = {}
	_update_plan()

func select_waypoint(index: int) -> void:
	if index < 0 or index >= points.size(): return
	selected_waypoint = index
	view.focus = Terrain.unpack(points[index])
	view._update_camera()
	_update_plan()

func _snap_point(point: Vector2, screen_at: Vector2 = Vector2.INF) -> Vector2:
	var radius := 24.0
	if screen_at.is_finite():
		for offset in [Vector2(26, 0), Vector2(0, 26)]:
			var nearby := view.map_point(screen_at + offset)
			if nearby.is_finite(): radius = maxf(radius, minf(100, point.distance_to(nearby)))
	snap_target = model.snap_anchor(point, radius, _drag_waypoint == 0 or (_drag_waypoint < 0 and points.is_empty()), editing_id, _edit_original if editing_id != -1 else []) if tool == "piste" else model.snap_walkway(point,28,editing_id) if tool == "walkway" else model.snap_lift_station(point,hud.lift_kind(),radius,editing_id) if tool == "lift" else {}
	if not snap_target.is_empty() and screen_at.is_finite():
		var at: Vector2 = view.camera.unproject_position(view.surface_position(snap_target.point))
		if at.distance_to(screen_at) > 26: snap_target = {}
	return snap_target.point if not snap_target.is_empty() else point

func chosen_piste_width() -> float:
	return edit_width if editing_id != -1 else plan_width

func set_piste_width(value: float) -> void:
	if not is_finite(value) or value < 14 or value > 36: return
	if editing_id != -1: edit_width = value
	else: plan_width = value
	_update_plan()

func _begin_waypoint_drag(index: int, pressed_at: Vector2 = Vector2.INF) -> void:
	_drag_waypoint = index
	selected_waypoint = index
	_drag_original = points[index].duplicate()
	_drag_press_position = pressed_at
	_drag_has_moved = false
	_drag_screen_offset = Vector2.ZERO
	_update_plan()

func _move_waypoint(screen_point: Vector2) -> void:
	if _drag_waypoint < 0 or _drag_waypoint >= points.size():
		return
	# A finger can jitter on ACTION_UP. Merely selecting a numbered handle
	# must never shift the piste into a different triangle on the mountain.
	if _drag_press_position.is_finite() and screen_point.distance_to(_drag_press_position) < 8.0:
		return
	var cursor := screen_point - _drag_screen_offset
	var point := view.map_point(cursor)
	if model.terrain.contains(point):
		var moved_to: Array = Terrain.pack(_snap_point(point, cursor))
		if points[_drag_waypoint] != moved_to:
			points[_drag_waypoint] = moved_to
			_drag_has_moved = true
			_plan_dirty = true

func _end_waypoint_drag(canceled: bool = false) -> void:
	if canceled and _drag_waypoint >= 0 and _drag_waypoint < points.size():
		points[_drag_waypoint] = _drag_original.duplicate()
	elif _drag_has_moved:
		# Do not discard redo history when the user only selected the point,
		# or canceled a two-finger gesture halfway through a drag.
		undone_points.clear()
	_drag_waypoint = -1
	_drag_original = []
	_drag_press_position = Vector2.INF
	_drag_has_moved = false
	_update_plan()

func _plan_check() -> Dictionary:
	if editing_id != -1:
		var check: Dictionary = model.preview_change(editing_id, points, edit_rotation, edit_width, false)
		check.color = edit_color
		return check
	if tool in ["lift", "building"]:
		var access: String = model.build_access_message(hud.lift_kind() if tool == "lift" else hud.building_kind(), tool == "lift")
		if access != "":
			return {"ok": false, "message": access, "cost": 0}
	if tool == "walkway": return model.preview_walkway(points, walkway_surface)
	if tool == "piste":
		return model.preview_piste(points, plan_width, false)
	if tool == "lift" and points.size() == 2:
		return model.preview_lift(hud.lift_kind(), Terrain.unpack(points[0]), Terrain.unpack(points[1]))
	if tool == "plaza" and points.size() == 1:
		return model.preview_plaza(plaza_kind, Terrain.unpack(points[0]))
	if tool == "building" and points.size() == 1:
		var check := model.preview_building(hud.building_kind(), Terrain.unpack(points[0]), edit_rotation)
		check.rotation = edit_rotation
		return check
	return {"ok": false, "message": L.text("Talstation, dann Bergstation antippen.") if tool == "lift" else L.text("Einen Bauplatz antippen."), "cost": 0}

func suggest_route() -> void:
	if tool not in ["piste", "walkway"] or points.size() < 2: return
	var context: RefCounted=model if editing_id == -1 else model.Edit.context(model,editing_id)
	var result: Dictionary=context.Planner.suggest_walk(context, points) if tool == "walkway" else context.suggest_piste(points,chosen_piste_width())
	if result.ok:
		undone_points.clear()
		points=result.points.duplicate(true)
		selected_waypoint=-1
		snap_target={}
		_update_plan()
	hud.toast(result.message)

func suggest_site() -> void:
	if tool != "building" or points.size() != 1: return
	var context: RefCounted = model if editing_id == -1 else model.Edit.context(model, editing_id)
	var result: Dictionary = context.suggest_building(hud.building_kind() if editing_id == -1 else model.asset(editing_id).kind, Terrain.unpack(points[0]))
	if result.ok:
		undone_points.clear()
		points = [result.point]
		edit_rotation = int(result.rotation)
		snap_target = {}
		_update_plan()
	hud.toast(result.message)

func reverse_route() -> void:
	if tool != "piste" or points.size() < 2: return
	undone_points.clear()
	points.reverse()
	selected_waypoint=-1
	snap_target={}
	_update_plan()

func smooth_route() -> void:
	if tool != "piste" or points.size() < 3: return
	var context: RefCounted = model if editing_id == -1 else model.Edit.context(model, editing_id)
	var result: Dictionary = model.Planner.smooth(context, points, chosen_piste_width())
	if result.ok:
		undone_points.clear()
		points = result.points.duplicate(true)
		selected_waypoint = -1
		snap_target = {}
		_update_plan()
	hud.toast(result.message)

func _update_plan() -> void:
	_plan_dirty = false
	if tool == "inspect":
		hud.plan(L.text("Dein Berg. Dein Resort. Wähle links ein Bauwerkzeug oder tippe eine Anlage an."), false, 0)
		hud.palette.route_profile.update_profile({})
		last_plan_check = {}
		view.preview([], Color.WHITE)
		return
	var check := _plan_check()
	if tool == "piste" and check.has("points") and _drag_waypoint < 0:
		points = check.points.duplicate(true)
		if selected_waypoint >= points.size():
			selected_waypoint = -1
	last_plan_check = check
	hud.palette.route_profile.update_profile(check if tool in ["piste","building","plaza","walkway"] else {})
	var cost: float = check.get("cost", 0)
	var affordable: bool = cost <= model.money
	var message: String = check.message
	if check.has("connections"): message += " · " + check.connections.message
	if points.is_empty() and tool == "piste":
		message = L.text("Abfahrt planen: Start am Berg setzen, danach weitere Wegpunkte bis ins Tal.")
	elif points.size() == 1 and tool == "piste":
		message = L.text("Start bei %.0f m. Verlauf setzen; kurze Gegenanstiege sind mit Schwung oder zu Fuß möglich.") % L.args(model.terrain.height(Terrain.unpack(points[0])))
	if not snap_target.is_empty():
		message += L.text(" · Angedockt: %s") % L.args(snap_target.label)
	if selected_waypoint >= 0 and snap_target.is_empty():
		message += L.text(" · Punkt %d ausgewählt: ziehen zum Verschieben.") % L.args((selected_waypoint + 1))
	if not affordable:
		message += L.text("  Das Budget reicht noch nicht.")
	hud.plan(message, check.ok and affordable, points.size(), cost)
	view.preview(points, Color("75cdc7") if check.ok else Color("efb17d"), hud.building_kind() if tool == "building" else "", check if tool in ["piste","building","plaza","walkway"] else {})
	hud._refresh_context_text()

func confirm_plan() -> void:
	if _committing:
		return
	if tool == "inspect":
		if model.day_finished():
			hud.show_report()
		return
	var check := _plan_check()
	if not check.ok:
		hud.toast(check.message)
		return
	_committing = true
	var result: Dictionary
	var edited := editing_id
	# Auxiliary access paths may also allocate IDs (e.g. after a lift). The
	# first new ID belongs to the actual structure the player confirmed.
	var created_id: int = model.next_id
	if editing_id != -1:
		result = model.change_asset(editing_id, points, edit_title, edit_color, edit_rotation, edit_width, false)
	elif tool == "walkway":
		result = model.build_walkway(points, walkway_surface)
	elif tool == "plaza":
		result = model.build_plaza(plaza_kind, Terrain.unpack(points[0]))
	elif tool == "piste":
		result = model.build_piste(points, -1, plan_width, false)
	elif tool == "lift":
		result = model.build_lift(hud.lift_kind(), Terrain.unpack(points[0]), Terrain.unpack(points[1]))
	else:
		result = model.build_building(hud.building_kind(), Terrain.unpack(points[0]), edit_rotation)
	_committing = false
	if result.ok:
		model.campaign.xp += Progression.construction_xp(tool,edited != -1)
		# Immediate reward: construction milestones appear on screen without
		# waiting for the next simulated minute.
		model._check_achievements()
		Progression.refresh(model)
		_clear_input()
		points.clear()
		undone_points.clear()
		selected_waypoint = -1
		snap_target = {}
		editing_id = -1
		if tool == "lift": _end_lift_camera()
		tool = "inspect"
		hud.show_context("inspect", edited if edited != -1 else created_id)
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
		# November noticeboards are non-physical and do not alter the career.
		# A direct tap opens their original/fallback artwork at full screen.
		if view.festival_scene.hit_poster(point):
			hud.show_seasonal_poster()
			return
		var visitor: int = view.pick_guest(position_value)
		if visitor != -1:
			hud.show_guest(visitor)
		else:
			hud.show_context(tool, view.pick_asset(point))
		return
	point = _snap_point(point, position_value)
	undone_points.clear()
	if tool in ["building", "plaza"]:
		points = [Terrain.pack(point)]
		if tool == "building" and editing_id == -1: edit_rotation = model.building_orientation(hud.building_kind(), point)
	elif tool == "lift" and points.size() >= 2:
		points[1] = Terrain.pack(point)
	elif points.size() < 64:
		points.append(Terrain.pack(point))
	selected_waypoint = -1
	_update_plan()

func _begin_stroke(screen: Vector2) -> void:
	if tool != "walkway" or not walkway_freehand or editing_id != -1: return
	var at := view.map_point(screen)
	if not model.terrain.contains(at): return
	_stroke_original = points.duplicate(true)
	_stroke = [Terrain.pack(_snap_point(at, screen))]
	_stroke_active = true
	_stroke_drawn = false
	_stroke_too_long = false

func _move_stroke(screen: Vector2) -> void:
	if not _stroke_active or hud.blocks_map(screen): return
	var at := view.map_point(screen)
	if not model.terrain.contains(at): return
	if Terrain.unpack(_stroke[-1]).distance_to(at) < 2: return
	if _stroke.size() >= 512:
		_stroke_too_long = true
		return
	_stroke.append(Terrain.pack(at))
	_stroke_drawn = true
	# No repeated graph searches while a finger is moving. The actual obstacle,
	# slope and connection checks run once when this stroke becomes waypoints.
	view.preview(_stroke, Color("75cdc7"), "", {"walkway":true,"width":8.0,"points":_stroke})

func _end_stroke(screen: Vector2, canceled: bool = false) -> void:
	if not _stroke_active: return
	canceled = canceled or hud.blocks_map(screen)
	var drawn := _stroke_drawn
	if not canceled and drawn: _move_stroke(screen)
	if not canceled and drawn and not _stroke_too_long:
		var end := view.map_point(screen)
		if model.terrain.contains(end) and not hud.blocks_map(screen):
			_stroke[-1] = Terrain.pack(_snap_point(end, screen))
		var combined := _stroke_original.duplicate(true)
		if not combined.is_empty() and Terrain.unpack(combined[-1]).distance_to(Terrain.unpack(_stroke[0])) < 2:
			combined.pop_back()
		combined.append_array(_stroke)
		var generated := WalkwayDesign.waypoints(combined)
		if not generated.is_empty():
			points = generated
			undone_points.clear()
			selected_waypoint = -1
		else: hud.toast(L.text("Zeichnung zu dicht. Den Weg in kürzere Abschnitte teilen."))
	if _stroke_too_long and not canceled: hud.toast(L.text("Zeichnung zu dicht. Den Weg in kürzere Abschnitte teilen."))
	_stroke_active = false
	_stroke_drawn = false
	_stroke_too_long = false
	_stroke.clear()
	_stroke_original.clear()
	_update_plan()

func _clear_input() -> void:
	_stroke_too_long = false
	_stroke_active = false
	_stroke_drawn = false
	_stroke.clear()
	_stroke_original.clear()
	if _drag_waypoint >= 0:
		_end_waypoint_drag(true)
	_mouse_down = false
	_touches.clear()
	_touch_origins.clear()
	_gesture_used = false
	_touch_dragged = false

func _input(event: InputEvent) -> void:
	if view.tour.active:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and hud.cinema_overlay.get_global_rect().has_point(event.position):
			return
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE,KEY_SPACE,KEY_V] or event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed:
			stop_cinematic_tour()
		return
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
					_begin_waypoint_drag(handle, event.position)
					_drag_screen_offset = event.position - view.camera.unproject_position(view.surface_position(Terrain.unpack(points[handle])))
				_mouse_down = true
				_mouse_origin = event.position
				_mouse_dragged = event.button_index == MOUSE_BUTTON_MIDDLE
				if handle < 0 and event.button_index == MOUSE_BUTTON_LEFT: _begin_stroke(event.position)
			elif _mouse_down:
				_mouse_down = false
				if _drag_waypoint >= 0:
					_move_waypoint(event.position)
					_end_waypoint_drag()
				elif _stroke_active:
					var drawn := _stroke_drawn
					_end_stroke(event.position)
					if not drawn and not _mouse_dragged and not hud.blocks_map(event.position): _map_tap(event.position)
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
		elif _stroke_active and _mouse_dragged:
			_move_stroke(event.position)
		elif _mouse_dragged:
			view.pan(event.relative)
	elif event is InputEventMagnifyGesture and not hud.blocks_map(event.position):
		view.change_zoom(1.0 / event.factor)
	elif event is InputEventPanGesture and not hud.blocks_map(event.position):
		view.pan(event.delta * 24)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if hud.piste_map_window.visible:
				hud.piste_map_window.hide()
			elif hud.seasonal_poster.visible:
				hud.seasonal_poster.hide()
			elif hud.building_browser.visible:
				hud.building_browser.hide()
			elif hud.piste_workshop.visible:
				hud.piste_workshop.close()
			elif hud.experience.visible:
				hud.experience.close()
			elif hud.winter_festival.visible:
				hud.winter_festival.close()
			elif hud.jukebox.visible:
				hud.jukebox.close()
			elif hud.medal_cabinet.visible:
				hud.medal_cabinet.close()
			elif hud.update_dialog.visible:
				hud.update_dialog.hide()
			elif hud.career_slots.visible:
				hud.career_slots.hide()
			elif hud.audience.visible:
				hud.audience.hide()
			elif hud.lift_staff.visible:
				hud.lift_staff.hide()
			elif hud.asset_editor.visible:
				hud.asset_editor.hide()
			elif hud.display_options.visible:
				hud.display_options.hide()
			elif hud.camera_dialog.visible:
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
		elif not hud.building_browser.visible and not hud.piste_workshop.visible and not hud.experience.visible and not hud.winter_festival.visible and not hud.seasonal_poster.visible and not hud.piste_map_window.visible and not hud.jukebox.visible and not hud.medal_cabinet.visible and not hud.update_dialog.visible and not hud.career_slots.visible and not hud.audience.visible and not hud.lift_staff.visible and not hud.asset_editor.visible and not hud.display_options.visible and not hud.menu.visible and not hud.camera_dialog.visible and not hud.help_dialog.visible and not hud.daily_dialog.visible and not hud.management.visible and not hud.atlas.visible and not hud.scenarios.visible and not hud.credits.visible and not hud.loading.visible:
			match event.keycode:
				KEY_SPACE: toggle_pause()
				KEY_Q: view.rotate_view(-0.2)
				KEY_E: view.rotate_view(0.2)
				KEY_B: set_tool("piste")
				KEY_DELETE: delete_waypoint()
				KEY_Z:
					if event.ctrl_pressed:
						if event.shift_pressed: redo_point()
						else: undo_point()
				KEY_Y:
					if event.ctrl_pressed: redo_point()
				KEY_R: set_tool("piste")
				KEY_K: set_tool("piste")
				KEY_L: set_tool("lift")
				KEY_G: set_tool("building")
				KEY_F1: hud.show_help()
				KEY_M: hud.show_management()
				KEY_C:
					note_manual_camera_change()
					view.set_camera_mode((view.camera_mode + 1) % view.CAMERA_MODES.size())
				KEY_TAB: hud.set_map_focus(not hud.map_focus)
				KEY_S:
					if event.ctrl_pressed:
						save_game()

func _touch_event(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if hud.blocks_map(event.position) and _touches.is_empty():
			return
		if _touches.is_empty():
			_gesture_used = false
			_touch_dragged = false
		_touches[event.index] = event.position
		_touch_origins[event.index] = event.position
		if _touches.size() > 1:
			if _stroke_active: _end_stroke(event.position, true)
			if _drag_waypoint >= 0:
				_end_waypoint_drag(true)
			_gesture_used = true
		else:
			var handle := hud.plan_overlay.pick_waypoint(event.position, 34)
			if handle >= 0:
				_begin_waypoint_drag(handle, event.position)
				_drag_screen_offset = event.position - view.camera.unproject_position(view.surface_position(Terrain.unpack(points[handle])))
			if handle < 0: _begin_stroke(event.position)
	elif _touches.has(event.index):
		if _stroke_active:
			var drawn := _stroke_drawn
			_end_stroke(event.position, event.canceled)
			if not drawn and not event.canceled and not _touch_dragged and not hud.blocks_map(event.position): _map_tap(event.position)
		elif _drag_waypoint >= 0:
			# Android can send the final coordinate only with ACTION_UP, after
			# the last motion packet. Commit that coordinate before ending the drag.
			if not event.canceled: _move_waypoint(event.position)
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
		view.transform_gesture(old_center, new_center, before[1] - before[0], after[1] - after[0])
	else:
		if _drag_waypoint >= 0:
			_move_waypoint(event.position)
			return
		if event.position.distance_to(_touch_origins[event.index]) > 8:
			_touch_dragged = true
		if _touch_dragged:
			if _stroke_active: _move_stroke(event.position)
			else: view.pan(event.relative)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if is_node_ready(): call_deferred("_follow_system_language")
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_suspend_application()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_resume_application()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if hud.piste_map_window.visible:
			hud.piste_map_window.hide()
			return
		if hud.seasonal_poster.visible:
			hud.seasonal_poster.hide()
			return
		if hud.building_browser.visible:
			hud.building_browser.hide()
			return
		if hud.piste_workshop.visible:
			hud.piste_workshop.close()
			return
		if hud.experience.visible:
			hud.experience.close()
			return
		if hud.winter_festival.visible:
			hud.winter_festival.close()
			return
		if hud.jukebox.visible:
			hud.jukebox.close()
			return
		if hud.medal_cabinet.visible:
			hud.medal_cabinet.close()
			return
		if hud.update_dialog.visible:
			hud.update_dialog.hide()
			return
		if hud.career_slots.visible:
			hud.career_slots.hide()
			return
		if hud.audience.visible:
			hud.audience.hide()
			return
		if hud.lift_staff.visible:
			hud.lift_staff.hide()
			return
		if hud.asset_editor.visible:
			hud.asset_editor.hide()
			return
		if hud.display_options.visible:
			hud.display_options.hide()
			return
		if hud.camera_dialog.visible:
			hud.camera_dialog.hide()
			return
		if hud.atlas.visible:
			hud.atlas.hide()
			return
		if hud.management.visible:
			hud.management.hide()
			return
		if tool != "inspect":
			clear_plan()
			return
		if has_game:
			save_game()
		show_menu()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_suspend_application()
		get_tree().quit()

func _suspend_application() -> void:
	if not is_node_ready() or _app_background: return
	_background_running = simulation_running()
	_background_speed = speed
	_background_started = Time.get_ticks_msec()
	_app_background = true
	audio.set_active(false)
	_clear_input()
	if has_game: save_game()

func _queue_background_time(seconds: float, rate: int) -> void:
	# Operating days still await the player's next-morning confirmation.
	var remaining := maxf(0,Resort.CLOSING+1800-model.minute)
	_accumulator += minf(maxf(0,seconds)*rate*Resort.MINUTES_PER_SECOND*(4.0 if model.time_divisor>1 else 1.0)*DayRhythm.playback(model.minute,preferences.day_length),remaining*model.time_divisor)

func _resume_application() -> void:
	if not is_node_ready(): return
	if _app_background:
		var elapsed := maxf(0,(Time.get_ticks_msec()-_background_started)/1000.0)
		_app_background = false
		if _background_running: _queue_background_time(elapsed,_background_speed)
		_background_running = false
	_clear_input()
	if not _resume_scheduled:
		_resume_scheduled = true
		call_deferred("_restore_display")

func _restore_display() -> void:
	# Android may recreate its native surface after the resume notification.
	await get_tree().process_frame
	if _app_background:
		_resume_scheduled = false
		return
	RenderingServer.set_render_loop_enabled(true)
	var viewport := get_viewport()
	viewport.transparent_bg = false
	RenderingServer.viewport_set_update_mode(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	view.recover_after_resume()
	_follow_system_language()
	hud.refresh();hud.root.queue_redraw()
	await get_tree().process_frame
	resume_count += 1
	_resume_scheduled = false

func _follow_system_language() -> void:
	if preferences.language == "system" and hud.is_inside_tree() and L.language != L.locale_for(L.system_locale()):
		apply_language("system")

func _start_android_lifecycle_test() -> void:
	var driver = load("res://tests/android_lifecycle_driver.gd").new()
	add_child(driver)
	driver.setup(self)

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
	for i in range(60*model.time_divisor):
		model.advance_minute()
	while model.guests.size()<24:
		if not model.admit_guest(model.guests.size()%3):break
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

func _lift_showcase(kind: String) -> void:
	# Reproducible QA traffic: visitors use the real boarding/seat assignment.
	model.new_game(false)
	model.money = 3000000
	model.build_lift(kind, Vector2(200, 205), Vector2(245, -130))
	model.build_piste([[245, -130], [275, -30], [255, 95], [200, 205]])
	model.build_building("lodge", Vector2(235, 252))
	model.build_building("restaurant", Vector2(145, 235))
	model.build_building("kiosk", Vector2(80, 280))
	model.build_building("shelter", Vector2(18, 306))
	for i in range(80):
		model.admit_guest(i % 3)
		var guest: Dictionary = model.guests[-1]
		for index in range(guest.route.legs.size()):
			if guest.route.legs[index].kind == "lift":
				guest.leg = index
				break
		model._start_leg(guest)
	for i in range(30):
		model.advance_minute(false)
	view.rebuild()
	view.focus = Vector2(170, 220)
	view.zoom = 190
	view.yaw = 0.55
	view.set_camera_mode(2)
	set_tool("inspect")
	hud.show_context("inspect", model.lifts[0].id)
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
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-lift-kind="):
			_lift_showcase(argument.trim_prefix("--capture-lift-kind="))
	if OS.get_cmdline_user_args().has("--capture-lift-riders"):
		for guest in model.guests:
			if guest.phase == "moving" and guest.route.legs[guest.leg].kind == "lift":
				view.follow_guest = guest.id
				view._follow_position = model.guest_position(guest)
				view.focus = Vector2(view._follow_position.x, view._follow_position.z)
				view.zoom = 55
				var direction := Terrain.unpack(model.lifts[0].top) - Terrain.unpack(model.lifts[0].bottom)
				view.yaw = atan2(direction.x, direction.y) + 0.35
				view.set_camera_mode(1)
				hud.set_map_focus(true)
				break
	if OS.get_cmdline_user_args().has("--capture-lift-menu"):
		hud.palette.select_category("lifts")
		view.focus = Vector2(165, 190)
		view.zoom = 260
		view._update_camera()

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

	if OS.get_cmdline_user_args().has("--capture-comfort"):
		_junction_showcase()
		model.build_plaza("plaza", Vector2(300, 295))
		model.build_building("restaurant", Vector2(345, 265))
		view.rebuild()
		view.focus = Vector2(205, 205)
		view.zoom = 265
		view.yaw = 0.4
		view.set_camera_mode(0)
		hud.set_map_focus(true)
	if OS.get_cmdline_user_args().has("--capture-curves"):
		_junction_showcase()
		view.focus = Vector2(25, -240)
		view.zoom = 510
		view.yaw = 0
		view.set_camera_mode(2)
		hud.set_map_focus(true)
	if OS.get_cmdline_user_args().has("--capture-build-flow"):
		_junction_showcase()
		set_tool("piste")
		points = [[-90,-315],[-20,-330],[210,-270],[250,-235],[215,-120],[215,150]]
		selected_waypoint = 2
		view.focus = Vector2(65,-130)
		view.zoom = 750
		view.yaw = 0
		view.set_camera_mode(2)
		_update_plan()
	if OS.get_cmdline_user_args().has("--capture-walking-tool"):
		_junction_showcase()
		set_tool("plaza")
		points = [[310,290]]
		view.focus = Vector2(235,230)
		view.zoom = 340
		view.yaw = 0.3
		view.set_camera_mode(2)
		_update_plan()

	for i in range(12):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("CAPTURE: ", path, " result=", error)
	get_tree().quit(error)

func begin_edit(id: int, title: String, color: String, rotation_value: int, width: float) -> bool:
	if not points.is_empty() and editing_id != id:
		hud.toast(L.text("Zuerst die laufende Planung abschließen oder abbrechen."))
		return false
	var item: Dictionary = model.asset(id)
	if item.is_empty(): return false
	_clear_input()
	undone_points.clear()
	var continuing := editing_id == id
	editing_id = id
	edit_title = title
	edit_color = color
	edit_rotation = rotation_value
	edit_width = width
	if item.has("difficulty"):
		tool = "piste"
		_edit_original = item.points.duplicate(true)
	elif item.has("bottom"):
		tool = "lift"
		_edit_original = [item.bottom.duplicate(), item.top.duplicate()]
		hud.lift_choice.select(_catalog_index(item.kind, true))
	elif item.get("kind", "") == "walkway":
		tool = "walkway"
		plaza_kind = "walkway"
		_edit_original = item.points.duplicate(true)
	elif item.has("radius"):
		tool = "plaza"
		plaza_kind = item.kind
		_edit_original = [item.point.duplicate()]
	else:
		tool = "building"
		_edit_original = [item.point.duplicate()]
		hud.building_choice.select(_catalog_index(item.kind, false))
	if not continuing: points = _edit_original.duplicate(true)
	selected_waypoint = -1
	hud.show_context(tool)
	hud.asset_editor.hide()
	_update_plan()
	hud.toast(L.text("Nummerierte Punkte ziehen. Übernehmen bestätigt, Abbrechen verwirft die Änderung."))
	return true

func _catalog_index(kind: String, lift: bool) -> int:
	return hud.Catalog.LIFTS.keys().find(kind) if lift else hud.Catalog.BUILDINGS.keys().find(kind)





