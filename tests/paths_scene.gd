extends SceneTree
const Main = preload("res://src/main.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Foot = preload("res://src/core/foot_network.gd")
const Motion = preload("res://src/core/ski_motion.gd")
var passed := 0
var failed := 0
func check(value: bool, title: String) -> void:
	if value:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func _init() -> void:call_deferred("run")
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/"+name+".png")
func run() -> void:
	var game := Main.new();root.add_child(game);await process_frame
	game.start_game(true);game.paused=true
	game.hud.palette.select_category("paths")
	var card: Button
	for item in game.hud.palette.cards:
		if item.key == "walkway":card=item.button
	check(card != null and card.visible and not card.disabled,"The paths catalogue exposes an affordable actual footpath tool")
	card.pressed.emit()
	check(game.tool == "walkway" and game.hud.current_tool == "walkway","The actual catalogue button activates route planning instead of placing another circle")
	var endpoints := [Terrain.pack(Terrain.BASE),[330,190],[340,-160],Terrain.pack(Foot.boarding_point(game.model.lifts[0],true))]
	var funds: float = game.model.money
	game.points=endpoints.duplicate(true);game._update_plan();await process_frame
	check(game.last_plan_check.ok and not game.hud.confirm_button.disabled,"A connected multi-point path is buildable through the real controller")
	check(not game.simulation_running() and game.model.money == funds,"Footpath planning pauses operations and leaves the budget untouched")
	check(game.hud.undo_button.visible and game.hud.delete_point_button.visible,"Path routes expose undo and individual point deletion")
	check(game.view.preview_root.get_child_count() > 0,"The path route has an actual world preview")
	if DisplayServer.get_name() != "headless":
		var original: Array=game.points[1].duplicate()
		game._begin_waypoint_drag(1)
		game._move_waypoint(game.view.camera.unproject_position(game.model.terrain.world(Vector2(350,190))))
		game._end_waypoint_drag()
		check(Terrain.unpack(game.points[1]).distance_to(Terrain.unpack(original)) > 4 and game.model.money == funds,"Dragging a real path handle changes the prospective route without charging")
	await capture("footpath-preview-090")
	game.clear_plan()
	check(game.points.is_empty() and game.model.walk_areas.is_empty() and game.model.money == funds,"Cancel discards the whole footpath plan without creating an asset")
	game.plaza_kind="walkway";game.set_tool("walkway");game.points=endpoints.duplicate(true);game._update_plan()
	game.confirm_plan()
	check(game.model.walk_areas.size() == 1 and game.model.walk_areas[0].kind == "walkway","The real build command creates one connected footpath")
	var paid:float=game.model.money
	game.confirm_plan()
	check(game.model.walk_areas.size() == 1 and game.model.money == paid,"A repeated confirmation cannot create or charge a second path")
	var path: Dictionary=game.model.walk_areas[0]
	var middle:=Terrain.unpack(path.points[1]).lerp(Terrain.unpack(path.points[2]),0.5)
	check(game.view.pick_asset(middle) == path.id,"A built path is selectable along its length instead of only at its first point")
	check(game.begin_edit(path.id,"Bergweg","",0,20) and game.tool == "walkway" and game.last_plan_check.ok,"Built paths reopen in the same multi-point editor with a valid detour")
	game.clear_plan()
	check(game.model.money == paid and game.model.walk_areas[0].points == path.points,"Cancelling an existing path edit preserves its actual geometry and budget")
	# Real Sonnenhang terrain, with an interior rise that needs a short bootpack.
	game.start_game(false);game.paused=true;game.model.money=3000000
	game.model.build_lift("chair",Vector2(200,205),Vector2(-140,-320))
	game.model.build_piste([[-100,-300],[-100,-140],[200,205]])
	for i in range(5):
		if game.model.admit_guest(2):break
	check(not game.model.guests.is_empty(),"The rendered hiking circuit admits a guest on the actual Sonnenhang")
	if not game.model.guests.is_empty():
		var guest:Dictionary=game.model.guests[0]
		for i in range(guest.route.legs.size()):
			if guest.route.legs[i].kind == "ski":guest.leg=i;game.model._start_leg(guest);break
		for i in range(1,guest.ski_motion.size()):
			if guest.ski_motion[i][2] == 1:
				guest.elapsed=guest.duration*(guest.ski_motion[i-1][0]+guest.ski_motion[i][0])*0.5;break
		game.view.simulation_fraction=0;game.view.follow_guest=guest.id;game.view.zoom=68;game.view._process(0)
		game.hud.show_guest(guest.id);game.hud.refresh();await process_frame
		check(game.view._climbers.multimesh.visible_instance_count == 1 and game.view.visitor_mesh.multimesh.visible_instance_count == 0,"The real renderer uses the uphill stepping model instead of a carving skier")
		check(game.view._guest_positions[guest.id].distance_to(game.model.guest_position(guest)) < 0.05,"Rendered hiking and simulated position agree on the snow surface")
		check(game.hud.inspector_text.text.contains("Stapft"),"The visible guest inspector names the current hiking activity")
		check(not game.model.pistes[0].tracks[-1].get("hikes",[]).is_empty(),"The snow renderer receives the same hiking intervals as the moving guest")
		await capture("hiking-090")
	game.queue_free();await process_frame
	print("PATHS SCENE: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
