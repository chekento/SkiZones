extends SceneTree
const Terrain = preload("res://src/core/terrain.gd")
const Foot = preload("res://src/core/foot_network.gd")
const Wear = preload("res://src/world/foot_wear.gd")
var game: Node
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("PASS ",message)
	else: failed+=1; push_error("FAIL "+message)
func settle() -> void:
	for i in range(6): await process_frame
func inside(control: Control, bounds: Rect2) -> bool:
	return bounds.grow(1).encloses(control.get_global_rect())
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	check(root.get_texture().get_image().save_png("res://build/qa/037-"+label+".png")==OK,"Rendered "+label)
func touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index=index; event.position=at; event.pressed=pressed
	game._input(event)
func drag(index: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index=index; event.position=at; event.relative=relative
	game._input(event)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.set_process(false); game.view.set_process(false); game.paused=true
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	for language in ["de","en"]:
		game.apply_language(language)
		game.hud.achievement_overlay.hide()
		game.hud.achievement_overlay.set_process(false)
		for resolution in [Vector2i(360,740),Vector2i(420,860),Vector2i(740,360)]:
			root.size=resolution
			game.clear_plan(); game.set_tool("piste")
			game.hud.hide_menu()
			game.points=[[0,0],[100,100],[200,205]]
			game._update_plan()
			await settle()
			game.hud._update_safe_area()
			await settle()
			var hud: CanvasLayer=game.hud
			var palette: Control=hud.palette
			var screen := Rect2(Vector2.ZERO,Vector2(resolution))
			check(palette.live_stats.is_visible_in_tree() and palette.live_stats.text.contains("°") and palette.live_stats.text.contains("%"),"Live percent and degree grades visible: "+language+str(resolution))
			check(not palette.scroll.visible and palette.route_profile.get_parent()==palette.fixed,"Profile uses no scroll container: "+language+str(resolution))
			check(inside(palette.live_stats,hud.tools_panel.get_global_rect()) and inside(palette.route_profile,hud.tools_panel.get_global_rect()),"All live statistics and profile fit fixed panel: "+language+str(resolution))
			check(inside(hud.tools_panel,screen) and inside(hud.plan_panel,screen) and not hud.tools_panel.get_global_rect().intersects(hud.plan_panel.get_global_rect()),"Construction panels fit without overlap: "+language+str(resolution))
			var actions_fit := true
			for button in [hud.confirm_button,hud.clear_button,hud.undo_button,hud.redo_button,hud.delete_point_button,hud.piste_width_choice,hud.suggest_route_button,hud.smooth_route_button,palette.reverse_button]:
				actions_fit=actions_fit and button.is_visible_in_tree() and inside(button,screen) and inside(button,hud.plan_panel.get_global_rect())
			check(actions_fit,"Every build, cancel, width and edit action fits: "+language+str(resolution))
			await capture("planning-%s-%dx%d" % [language,resolution.x,resolution.y])
			game.clear_plan()
			await settle()
			var create: Button=game.hud.tool_buttons.piste
			check((create.is_visible_in_tree() or hud.piste_quick_button.is_visible_in_tree()) and not palette.live_stats.visible,"Leaving planning restores a visible create-piste action")
	# The idle path catalogue is fixed as well, including a short landscape phone.
	for resolution in [Vector2i(360,740),Vector2i(740,360)]:
		root.size=resolution; game.clear_plan()
		game.hud.inspector_collapsed=true
		game.hud.palette.select_category("paths")
		game.hud._apply_panel_visibility()
		await settle(); game.hud._update_safe_area(); await settle()
		var all_fit := true
		for card in game.hud.palette.cards:
			if card.type == "plaza": all_fit=all_fit and card.button.is_visible_in_tree() and inside(card.button,Rect2(Vector2.ZERO,Vector2(resolution))) and inside(card.heading,card.button.get_global_rect())
		check(all_fit and not game.hud.palette.scroll.visible,"All path and plaza choices are visible without scrolling: "+str(resolution))
		await capture("path-catalogue-%dx%d" % [resolution.x,resolution.y])
	# A real screen gesture converts a curved stroke without panning the camera.
	root.size=Vector2i(1280,800)
	game.apply_language("de"); game.hud.hide_menu()
	game.clear_plan(); game.set_tool("walkway")
	game.view.focus=Vector2(280,200); game.view.zoom=190; game.view._update_camera()
	game.hud.set_map_focus(true)
	await settle()
	var coords: Array[Vector2]=[]
	for at in [Vector2(240,210),Vector2(260,200),Vector2(280,180),Vector2(300,190),Vector2(320,210)]:
		coords.append(game.view.camera.unproject_position(game.view.surface_position(at)))
	var focus: Vector2=game.view.focus
	touch(0,coords[0],true)
	for i in range(1,coords.size()): drag(0,coords[i],coords[i]-coords[i-1])
	touch(0,coords[-1],false)
	check(game.points.size()>=3 and game.view.focus.distance_to(focus)<0.01,"A real one-finger curved gesture creates editable waypoints without camera panning")
	var original: Array=game.points.duplicate(true)
	game.clear_plan(); game.set_tool("walkway")
	touch(0,coords[0],true); drag(0,coords[1],coords[1]-coords[0]); touch(1,coords[2],true)
	touch(0,coords[1],false); touch(1,coords[2],false)
	check(game.points.is_empty() and not game._stroke_active,"A second finger cancels the unfinished stroke before camera gestures")
	game.clear_plan(); game.set_tool("walkway"); game.hud.set_map_focus(true)
	game.view.focus=Vector2(280,120); game.view.zoom=500; game.view._update_camera()
	await settle()
	var drawn_route := [Terrain.pack(Terrain.BASE),[330,190],[340,-160],Terrain.pack(Foot.boarding_point(game.model.lifts[0],true))]
	coords.clear()
	for row in drawn_route: coords.append(game.view.camera.unproject_position(game.view.surface_position(Terrain.unpack(row))))
	touch(0,coords[0],true)
	for i in range(1,coords.size()): drag(0,coords[i],coords[i]-coords[i-1])
	touch(0,coords[-1],false)
	if not game.last_plan_check.get("ok",false): print("FREEHAND_DIAGNOSTIC ",game.points," ",coords," ",game.last_plan_check)
	check(game.last_plan_check.get("ok",false),"A real freehand stroke joining valley and station passes the actual build rules")
	await capture("freehand-path")
	game.clear_plan()
	for index in range(game.WalkwayDesign.SURFACES.size()):
		var surface: String=game.WalkwayDesign.SURFACES.keys()[index]
		game.walkway_surface=surface; game.set_tool("walkway")
		game.points=[Terrain.pack(Terrain.BASE),[330+index*18,190],[340+index*18,-160],Terrain.pack(Foot.boarding_point(game.model.lifts[0],true))]
		game._update_plan()
		if not game.last_plan_check.ok: print("PATH_DIAGNOSTIC ",surface," ",game.last_plan_check.message)
		check(game.last_plan_check.ok,"Actual controller accepts the "+surface+" path")
		game.confirm_plan()
		game.view._process(0)
		await settle()
		var found := false
		var mesh: Mesh=game.view.foot_mesh.mesh
		if mesh.get_surface_count()>0:
			var uv: PackedVector2Array=mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
			for value in uv: found=found or absf(value.x-float(index))<0.01
		check(found and game.model.walk_areas.any(func(area):return area.get("surface","")==surface),"Built "+surface+" surface has actual patterned world geometry")
	game.clear_plan(); game.hud.set_map_focus(true)
	game.view.focus=Vector2(310,40); game.view.zoom=330; game.view._update_camera()
	game.hud.achievement_overlay.hide()
	await capture("path-surfaces")
	# Every persisted wear stage is actually rendered ABOVE station surfaces.
	var snow: Node3D=game.view.foot_wear
	snow.reset()
	var rows: Array=[]
	for x in range(120,133): rows.append([x,110,40,1.0,0.0])
	for y in range(111,120): rows.append([126,y,20,0.0,1.0])
	rows.append([123,108,1,1.0,0.0])
	check(snow.import_state(rows),"Persistent traffic cells remain compatible with the new renderer")
	var wear_started := Time.get_ticks_usec()
	snow.update_visuals(game.view,1.1)
	while snow._trail_builder != null:
		snow.update_visuals(game.view,0)
		await process_frame
	print("WEAR_MESH_USEC ",Time.get_ticks_usec()-wear_started)
	check(snow._trail.mesh!=null and snow._trail.mesh.get_surface_count()>0,"Repeated traffic forms an actual continuous trail mesh")
	check(snow._layers[0].multimesh.visible_instance_count==2 and snow._layers[3].multimesh.visible_instance_count==0,"Separate boot soles replace rectangular accumulated splats")
	var above := true
	if snow._trail.mesh != null:
		for vertex in snow._trail.mesh.get_faces():
			var surface: Vector3=game.view.surface_position(Vector2(vertex.x,vertex.z))
			above=above and vertex.y>=surface.y+0.035
	check(above and snow._trail.mesh!=null,"Trails follow the rendered station/plaza surface rather than sinking into the terrain")
	game.view.focus=Vector2(252,220); game.view.zoom=95; game.view._update_camera()
	await capture("station-snow-trails")
	game.view.focus=Vector2(0,-400); game.view.zoom=1200; game.view._update_camera()
	await capture("landscape")
	game.clear_plan(); game.walkway_surface="timber"; game.walkway_freehand=false
	game.set_tool("walkway"); game.points=drawn_route.duplicate(true); game._update_plan()
	game.save_game()
	game.app_session.path="user://skizones-test-session-037.json"
	game.app_session.save(game)
	var state: Dictionary=game.app_session.read_state()
	check(state.get("walkway_surface","")=="timber" and state.get("walkway_freehand",true)==false,"Android UI checkpoint preserves path surface and drawing mode")
	game.clear_plan(); game.walkway_surface="snow"; game.walkway_freehand=true
	var restored_session: bool=game.app_session.restore(game,true,false)
	var same_points: bool=game.points.size()==drawn_route.size()
	if same_points:
		for index in range(drawn_route.size()): same_points=same_points and Terrain.unpack(game.points[index]).distance_to(Terrain.unpack(drawn_route[index]))<0.001
	check(restored_session and game.walkway_surface=="timber" and not game.walkway_freehand and same_points,"Restoring a verified Android session keeps the unbuilt path and its chosen cost/surface")
	state.erase("walkway_surface"); state.erase("walkway_freehand")
	var session_file:=FileAccess.open(game.app_session.path,FileAccess.WRITE)
	session_file.store_string(JSON.stringify(state)); session_file.close()
	check(not game.app_session.read_state().is_empty(),"Old Android checkpoints without the new optional settings remain valid")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.app_session.path))
	game.queue_free(); await settle()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
