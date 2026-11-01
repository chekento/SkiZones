extends SceneTree
const Saves = preload("res://src/core/save_store.gd")
const Resort = preload("res://src/core/resort.gd")
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1;print("PASS ",title)
	else: failed+=1;push_error("FAIL " + title)
func run() -> void:
	var game := load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for frame in range(5): await process_frame
	Saves.active_slot=4
	game.has_game=false
	var path: String=Saves.path_for_map("sonnenhang",4)
	var source:=OS.get_environment("SKIZONES_LEGACY_FIXTURES").path_join("sonnenhang.json")
	var imported:=Resort.new()
	check(Saves.load_game(imported,source).ok and Saves.save_game(imported,path).ok,"A real 0.19 career is staged in an independent test slot")
	game.hud.root.offset_left=63
	game.hud.root.offset_right=-19
	game.hud.loading.show()
	game.hud.set_loading_progress(12.3,"Test")
	await process_frame
	var full:=Rect2(Vector2.ZERO,root.get_visible_rect().size)
	check(game.hud.loading.get_global_rect().position.distance_to(full.position)<0.1 and game.hud.loading.size.distance_to(full.size)<0.1,"PMDD loading art covers the full display even with asymmetric HUD safe insets")
	var activity:=game.hud.loading_activity.text
	await create_timer(0.55).timeout
	check(game.hud.loading_activity.text!=activity and is_equal_approx(game.hud.loading_progress.value,12.3),"A live activity indicator animates without faking completed progress")
	game.hud.loading.hide()
	var done:=[false]
	var start:=func():
		await game.enter_area("sonnenhang")
		game.paused=true
		done[0]=true
	start.call_deferred()
	var deadline:=Time.get_ticks_msec()+120000
	var frames:=0
	var stages:={}
	var captured:=false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/qa"))
	while not done[0] and Time.get_ticks_msec()<deadline:
		await process_frame
		if game.hud.loading.visible:
			frames+=1
			stages[game.hud.loading_stage.text]=true
			if not captured and game.hud.loading_progress.value>=84.0 and game.hud.loading_progress.value<99.0:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://build/qa/loading-progress-0201.png")
				captured=true
	check(done[0] and game.has_game and not game.hud.loading.visible,"The main-game Continue path finishes loading the original career")
	check(frames>=5 and stages.size()>=4,"The actual worker and world build keep rendering frames across detailed loading stages")
	check(game.model.pistes.size()==imported.pistes.size() and game.model.lifts.size()==imported.lifts.size() and absf(game.model.money-imported.money)<0.000001,"Continue retains the old pistes, lift infrastructure and career budget")
	check(game.view.get_viewport().scaling_3d_scale==1.0,"Improved lighting and antialiasing preserve full render resolution")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/qa/recovered-career-0201.png")
	game.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)

