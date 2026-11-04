extends SceneTree
const Terrain=preload("res://src/core/terrain.gd")
const Preferences=preload("res://src/core/preferences.gd")
var passed:=0
var failed:=0
var game: Node
func _init() -> void: call_deferred("run")
func check(value: bool, label_text: String) -> void:
	if value: passed+=1; print("PASS ",label_text)
	else: failed+=1; push_error("FAIL "+label_text)
func settle() -> void:
	for frame in range(5): await process_frame
func capture(name_value: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	check(root.get_texture().get_image().save_png("res://build/qa/"+name_value+".png")==OK,"Capture "+name_value)
func inside(node: Control) -> bool:
	var rect: Rect2=node.get_global_rect()
	return Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(rect)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.paused=true
	game.set_process(false)
	game.view.set_process(false)
	game.preferences.path="user://cinematic-map-032.cfg"
	game.apply_language("de")
	game._showcase()
	game.view.rebuild()
	await settle()
	game.view._process(0)
	var before: String=JSON.stringify(game.model.snapshot())
	var pose: Dictionary={"focus":game.view.focus,"zoom":game.view.zoom,"yaw":game.view.yaw,"pitch":game.view.pitch_degrees,"fov":game.view.camera.fov,"mode":game.view.camera_mode}
	game.start_cinematic_tour()
	check(game.view.tour.active and game.hud.cinema_mode,"Director starts in the actual resort scene")
	var clock:=0.0
	for shot in game.view.tour.hotspots:
		clock+=float(shot.travel)+float(shot.hold)
		if clock>=game.view.tour.duration(): break
		game.view.tour.elapsed=clock-0.001
		game.view.tour.step(game.view,0)
		var yaw_before: float=game.view.yaw
		var focus_before: Vector2=game.view.focus
		game.view.tour.step(game.view,0.002)
		check(absf(angle_difference(yaw_before,game.view.yaw))<0.01 and focus_before.distance_to(game.view.focus)<0.2,"Smooth transition at "+str(shot.kind)+" boundary")
	var slider: HSlider=game.hud.attention_sliders[-1]
	var touch:=InputEventScreenTouch.new()
	touch.pressed=true
	touch.position=slider.get_global_rect().get_center()
	game._input(touch)
	slider.value=100
	check(game.view.tour.active and is_equal_approx(game.view.tour.attention,1),"Live attention slider remains usable during the tour")
	var restored:=Preferences.new()
	restored.path=game.preferences.path
	restored.load_from()
	check(is_equal_approx(restored.cinematic_attention,1),"Live slider saves its setting")
	var peak: Dictionary={}
	for shot in game.view.tour.hotspots:
		if shot.kind=="peak": peak=shot; break
	if not peak.is_empty():
		var peak_clock:=0.0
		for shot in game.view.tour.hotspots:
			if shot==peak: break
			peak_clock+=float(shot.travel)+float(shot.hold)
		game.view.tour.elapsed=peak_clock+float(peak.travel)+0.8
		game.view.tour.step(game.view,0)
		var point:=Vector2(game.view.camera.position.x,game.view.camera.position.z)
		check(not game.view.terrain.contains(point) or game.view.camera.position.y>=game.view.terrain.height(point)+11.9,"Summit camera stays above actual terrain")
		await capture("cinematic-032-summit")
	game.stop_cinematic_tour()
	check(game.view.focus==pose.focus and is_equal_approx(game.view.zoom,pose.zoom) and is_equal_approx(game.view.yaw,pose.yaw) and is_equal_approx(game.view.pitch_degrees,pose.pitch) and is_equal_approx(game.view.camera.fov,pose.fov) and game.view.camera_mode==pose.mode,"Leaving the tour restores every camera setting")
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	var plan: Control=game.hud.piste_map_full
	for resolution in [Vector2i(1440,900),Vector2i(960,540),Vector2i(420,860)]:
		root.size=resolution
		game.hud._update_safe_area()
		await settle()
		game.hud.show_camera()
		await settle()
		check(inside(game.hud.camera_panel),"Camera controls fit "+str(resolution))
		game.hud.camera_dialog.hide()
		game.hud.show_piste_map()
		await settle()
		check(inside(plan) and plan.size.y>100,"Full piste map fits "+str(resolution))
		var bounds: Rect2=game.model.terrain.bounds
		for uv in [Vector2(0.1,0.1),Vector2(0.5,0.5),Vector2(0.9,0.9)]:
			var point: Vector2=bounds.position+bounds.size*uv
			check(plan.world_at(plan._point(point)).distance_to(point)<0.01,"World/map inverse at "+str(uv))
		var anchor: Vector2=plan.map_rect().get_center()+Vector2(15,10)
		var world_before: Vector2=plan.world_at(anchor)
		plan.zoom_by(1.3,anchor)
		check(plan.world_at(anchor).distance_to(world_before)<0.01,"Zoom preserves location under pointer")
		plan.reset_plan()
		for style in ["piste_map","neon_noir","bauhaus"]:
			game.view.visual_style=style
			plan.queue_redraw()
			await capture("piste-map-032-"+str(resolution.x)+"-"+style)
		game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		check(not game.hud.piste_map_window.visible and game.paused,"Android Back closes only the map and preserves pause")
	game.hud.show_piste_map()
	await settle()
	var lift: Dictionary=game.model.lifts[0]
	var midpoint: Vector2=(Terrain.unpack(lift.bottom)+Terrain.unpack(lift.top))*0.5
	var pixel: Vector2=plan._point(midpoint)
	var actual_id: int=plan.asset_at(pixel)
	check(actual_id>=0,"Real lift or piste is selectable from the plan")
	plan._navigate(pixel)
	check(game.view.focus.distance_to(midpoint)<0.01 and not game.hud.piste_map_window.visible,"Map tap navigates and opens the actual asset inspector")
	check(JSON.stringify(game.model.snapshot())==before,"Camera and map interactions preserve all gameplay state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.preferences.path))
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
