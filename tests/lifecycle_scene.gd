extends SceneTree
const Terrain = preload("res://src/core/terrain.gd")
var game: Node
var passed := 0
var failed := 0
func _init() -> void:call_deferred("run")
func check(value: bool,title: String) -> void:
	if value:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func touch(index: int,at: Vector2,pressed: bool) -> void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=at;event.pressed=pressed;game._input(event)
func drag(index: int,at: Vector2,relative: Vector2) -> void:
	var event:=InputEventScreenDrag.new();event.index=index;event.position=at;event.relative=relative;game._input(event)
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":return
	game.hud.refresh()
	await process_frame;await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/"+name+".png")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.app_session.path="user://lifecycle-test-session.json"
	game.start_game(true);game.paused=true
	game.set_tool("piste");game.points=[[240,-190],[320,60]];game._update_plan()
	var plan: Array=game.points.duplicate(true)
	var yaw: float=game.view.yaw;var zoom: float=game.view.zoom
	var centre:=Vector2(800,350);var anchor:Vector2=game.view.map_point(centre)
	touch(0,Vector2(750,250),true);touch(1,Vector2(850,450),true)
	drag(0,Vector2(850,250),Vector2(100,0));drag(1,Vector2(750,450),Vector2(-100,0))
	touch(0,Vector2(850,250),false);touch(1,Vector2(750,450),false)
	check(absf(angle_difference(yaw,game.view.yaw)) > 0.8,"Opposite horizontal finger movements at different heights rotate the actual camera")
	check(absf(game.view.zoom-zoom) < 0.1,"A pure two-finger twist preserves the final camera scale")
	check(game.view.map_point(centre).distance_to(anchor) < 3,"Two-finger rotation keeps the touched terrain anchored")
	check(game.points == plan and game._touches.is_empty(),"Twisting never adds a waypoint or retains released contacts")
	game.view.set_camera_mode(3);yaw=game.view.yaw
	game.view.transform_gesture(centre,centre,Vector2(100,0),Vector2(0,100))
	check(absf(angle_difference(yaw,game.view.yaw)) > 1.5,"The top-down planning camera also supports twisting")
	game.view.set_camera_mode(0);zoom=game.view.zoom;yaw=game.view.yaw
	game.view.transform_gesture(centre,centre+Vector2(20,15),Vector2(100,0),Vector2(130,0).rotated(0.25))
	check(game.view.zoom < zoom and absf(angle_difference(yaw,game.view.yaw)) > 0.2,"One gesture can combine terrain pan, pinch and rotation")
	game.clear_plan();game.set_tool("inspect");game.view.home()
	game.model.lifts[0].kind="chair"
	game.model.lifts[0].length=game.model._lift_profile("chair",Terrain.unpack(game.model.lifts[0].bottom),Terrain.unpack(game.model.lifts[0].top)).length
	game.model._invalidate()
	for i in range(3):game.model.admit_guest(i)
	for guest in game.model.guests:
		for i in range(guest.route.legs.size()):
			if guest.route.legs[i].kind=="ski":guest.leg=i;game.model._start_leg(guest);guest.elapsed=guest.duration*0.38;break
	game.view._process(0)
	var equipment_ok:=true
	for sport in ["ski","snowboard","snowblade"]:
		equipment_ok=equipment_ok and game.view._equipment[sport+"/glide"].multimesh.visible_instance_count==1
	check(equipment_ok and game.view.visitor_mesh.multimesh.visible_instance_count==3,"The real renderer shows all three sports with one appropriate equipment model each")
	var board:Dictionary=game.model.guests[0]
	var piste:Dictionary=game.model.asset(board.route.legs[board.leg].id)
	var track:Dictionary=piste.tracks.filter(func(t):return t.guest==board.id)[0]
	check(game.view._trace_sample(piste,track,5,true,{}).points.size()==1,"A moving snowboarder produces one broad board track")
	var skier:Dictionary=game.model.guests[2]
	track=piste.tracks.filter(func(t):return t.guest==skier.id)[0]
	check(game.view._trace_sample(piste,track,5,true,{}).points.size()==2,"A skier retains two separate natural ski tracks")
	var at:Vector3=game.model.guest_position(board)
	game.view.focus=Vector2(at.x,at.z);game.view.zoom=54;game.view.set_camera_pitch(48)
	game.hud.show_guest(board.id);await capture("winter-sports-0100")
	for guest in game.model.guests:
		for i in range(guest.route.legs.size()):
			if guest.route.legs[i].kind=="lift":guest.leg=i;game.model._start_leg(guest);break
	for i in range(20):
		game.model.advance_minute(false)
		if game.model.guests.all(func(g):return g.phase=="moving" and g.route.legs[g.leg].kind=="lift"):break
	game.view._process(0)
	check(game.view._riders.multimesh.visible_instance_count==3,"Mixed-sport guests share actual assigned chairlift seats")
	var carried:=true
	for sport in ["ski","snowboard","snowblade"]:carried=carried and game.view._equipment[sport+"/seated"].multimesh.visible_instance_count==1
	check(carried,"Boards, short skis and long skis remain distinct while riding the lift")
	for i in range(24):
		if not game.model.admit_guest(i%3):continue
		var guest:Dictionary=game.model.guests[-1]
		for index in range(guest.route.legs.size()):
			if guest.route.legs[index].kind=="lift":guest.leg=index;game.model._start_leg(guest);break
	game.view._process(0)
	var station:Vector2=Terrain.unpack(game.model.lifts[0].bottom)
	game.view.focus=station;game.view.zoom=110;game.view.set_camera_pitch(48);await capture("station-without-rails-0100")
	var minute:int=game.model.minute;var focus:Vector2=game.view.focus;yaw=game.view.yaw
	touch(0,Vector2(700,300),true)
	game._suspend_application();var started:int=game._background_started;game._suspend_application()
	check(game._touches.is_empty() and game._app_background and game._background_started==started,"Repeated pause/focus events save once and release stale touch contacts")
	game._background_started-=10000
	game.view.camera.clear_current()
	RenderingServer.viewport_set_active(root.get_viewport_rid(),false)
	game._resume_application();game._resume_application()
	for i in range(5):await process_frame
	check(not game._app_background and game.view.camera.is_current() and not game._resume_scheduled,"Resume reactivates the rendering viewport and its actual camera")
	check(game.model.minute==minute and game.paused,"An explicitly paused game does not accrue background simulation")
	check(game.view.focus.distance_to(focus)<0.001 and is_equal_approx(game.view.yaw,yaw),"Resume preserves the player's exact camera and perspective")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image();image.resize(64,32)
		var visible_pixels:=0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var color:=image.get_pixel(x,y)
				if color.r+color.g+color.b>0.08:visible_pixels+=1
		check(visible_pixels>1600,"A real frame after surface/viewport recovery is visibly rendered instead of black")
	await capture("resumed-game-0100")
	game.hud.show_context("inspect");game.paused=false;game.speed=4;game._accumulator=0
	minute=game.model.minute;game._suspend_application();game._background_started-=10000;game._resume_application()
	for i in range(60):
		game._process(0)
		if game._accumulator<1:break
	check(game.model.minute>=minute+20 and game.model.minute<=minute+21,"Ten background seconds at 4× resume through twenty actual simulation minutes without double counting")
	game.paused=true;game.view.focus=Vector2(235,40);game.view.yaw=1.1;game.view.zoom=250;game.view._update_camera()
	game._suspend_application()
	var before:Dictionary=game.model.snapshot()
	var restored=load("res://scenes/main.tscn").instantiate();root.add_child(restored);await process_frame
	restored.set_process(false);restored.app_session.path=game.app_session.path
	check(restored.app_session.restore(restored),"A newly created game process restores its saved resort session")
	check(restored.has_game and not restored.hud.menu.visible and restored.paused and restored.speed==4,"Process restoration returns directly to the playable map with the player's pause and speed")
	check(restored.view.focus.distance_to(Vector2(235,40))<0.01 and is_equal_approx(restored.view.yaw,1.1) and is_equal_approx(restored.view.zoom,250),"Process restoration retains camera position, zoom and rotation")
	check(restored.model.minute==before.minute and restored.model.guests.map(func(g):return g.id)==game.model.guests.map(func(g):return g.id),"Process restoration keeps the actual operating time and guest identities")
	var invalid:=FileAccess.open(game.app_session.path,FileAccess.WRITE);invalid.store_string("{broken");invalid.close()
	check(not restored.app_session.restore(restored) and restored.has_game,"A damaged UI checkpoint cannot destroy the independently valid playable resort")
	game.queue_free();restored.queue_free();await process_frame
	print("LIFECYCLE SCENE: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
