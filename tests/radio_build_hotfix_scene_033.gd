extends SceneTree
const Design = preload("res://src/core/audio_design.gd")
const Preferences = preload("res://src/core/preferences.gd")
const Catalog = preload("res://src/core/catalog.gd")
var game: Node
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)
func settle() -> void:
	for frame in range(4): await process_frame
func capture(stem: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	check(root.get_texture().get_image().save_png("res://build/qa/" + stem + ".png") == OK, "Captured " + stem)
func saved() -> RefCounted:
	var prefs := Preferences.new()
	prefs.path = game.preferences.path
	prefs.load_from()
	return prefs
func choose_radio(station: String) -> void:
	var index: int = Design.GENRES.find(station)
	game.hud.jukebox.genre_choice.select(index)
	game.hud.jukebox.genre_choice.item_selected.emit(index)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.set_process(false)
	game.view.set_process(false)
	game.preferences.path = "user://radio-build-hotfix033.cfg"
	game.preferences.music_genre = "alpine"
	game.preferences.sound_enabled = true
	game.audio.sync()
	game.hud.achievement_overlay.hide()
	game.hud.achievement_overlay.set_process(false)
	var before: String = JSON.stringify(game.model.snapshot())
	var box: Control = game.hud.jukebox
	box.open()
	choose_radio("techno")
	check(game.audio.current_genre == "techno" and saved().music_genre == "techno", "Station selection takes effect and survives disk reload without an Apply button")
	box.music_slider.value = 0.65
	box.master_slider.value = 0.8
	check(is_equal_approx(saved().music_volume, 0.65) and is_equal_approx(saved().master_volume, 0.8), "Both volume sliders are immediately persisted")
	box.enabled.button_pressed = false
	check(not saved().sound_enabled and game.audio.players.values().all(func(p): return not p.playing or p.stream_paused), "Power off is immediately silent and durable")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not box.visible and not saved().sound_enabled, "Android Back retains radio off")
	box.open()
	check(not box.enabled.button_pressed and str(Design.GENRES[box.genre_choice.selected]) == "techno", "Reopening displays the saved station and power state")
	box.enabled.button_pressed = true
	choose_radio("punk")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	check(not box.visible and saved().sound_enabled and saved().music_genre == "punk" and game.audio.current_genre == "punk", "Escape retains the active new channel without reverting")
	check(JSON.stringify(game.model.snapshot()) == before, "Radio settings do not alter a resort save or its money")
	game.model.campaign.mode = "free"
	game.model.money = 3000000.0
	game.hud.building_choice.select(Catalog.BUILDINGS.keys().find("restaurant"))
	var site: Vector2 = Vector2.INF
	for z in range(240, 390, 35):
		for x in range(70, 420, 35):
			if site == Vector2.INF and game.model.preview_building("restaurant", Vector2(x,z)).ok: site = Vector2(x,z)
	check(site != Vector2.INF, "A real legal connected restaurant lot is available")
	if site != Vector2.INF:
		game.set_tool("building")
		game.points = [[site.x,site.y]]
		game._update_plan()
		var id: int = game.model.next_id
		game.hud.confirm_button.pressed.emit()
		await settle()
		check(game.tool == "inspect" and game.hud.selected_id == id and game.model.asset(id).kind == "restaurant", "Confirming a real building selects its completed inspector immediately")
		check(not game.hud.plan_panel.visible and game.hud.inspector_panel.visible and game.points.is_empty(), "The completed building replaces the bottom construction bar")
		check(root.get_visible_rect().encloses(game.hud.inspector_panel.get_global_rect()), "Completed-building inspector actions wrap inside the viewport")
		var paid: float = game.model.money
		game.confirm_plan()
		check(game.model.money == paid and game.model.next_id == id + 1, "A second confirmation cannot duplicate or charge the completed building")
		await capture("completed-building-033")
	game.set_tool("piste")
	game.points = [[900,-1000],[1000,-500]]
	game._update_plan()
	check(game.last_plan_check.ok and game.hud.plan_panel.visible, "Starting the next route makes the construction controls available again")
	var piste_id: int = game.model.next_id
	game.hud.confirm_button.pressed.emit()
	await settle()
	check(game.tool == "inspect" and game.hud.selected_id == piste_id and game.model.asset(piste_id).has("number"), "Finishing a piste selects the actual new descent")
	check(not game.hud.plan_panel.visible and game.hud.inspector_panel.visible and game.points.is_empty(), "Finished piste shows its inspector without the bottom construction bar")
	check(root.get_visible_rect().encloses(game.hud.inspector_panel.get_global_rect()), "Completed-piste inspector actions stay inside the viewport")
	await capture("completed-piste-033")
	game.set_tool("building")
	game.points = [[999999,999999]]
	game._update_plan()
	var budget: float = game.model.money
	game.confirm_plan()
	check(game.tool == "building" and not game.points.is_empty() and game.hud.plan_panel.visible and game.model.money == budget, "Rejected construction keeps the editable plan, controls and budget")
	game.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
