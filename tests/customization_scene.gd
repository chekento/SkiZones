extends SceneTree
const Terrain = preload("res://src/core/terrain.gd")
const Snow = preload("res://src/core/snow_surface.gd")
var game: Node
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ",title)
	else: failed += 1; push_error("FAIL " + title)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.start_game(false); game.paused=true; game.set_process(false); game.view.set_process(false)
	game.preferences.path="user://display-scene-test.cfg"
	game.model.money=3000000
	game.model.build_plaza("plaza",Vector2(340,300));game.model.build_building("lodge",Vector2(400,290))
	game.view.rebuild()
	var item: Dictionary = game.model.buildings[0]
	game.hud.show_context("inspect",item.id);game.hud.asset_editor.open(item.id)
	await process_frame
	check(game.hud.asset_editor.visible and game.hud.blocks_map(Vector2(750,400)) and not game.simulation_running(), "The actual design dialog blocks world input and pauses the resort")
	check(root.get_visible_rect().encloses(game.hud.asset_editor.get_child(1).get_global_rect()), "The complete design dialog fits the viewport")
	game.hud.asset_editor.name_field.text="Bergblick";game.hud.asset_editor.orientation_choice.select(1)
	check(game.begin_edit(item.id,"Bergblick","4a998f",1,20) and game.editing_id == item.id and game.tool == "building", "The real editor enters the existing building into the construction planner")
	game.view.focus=Vector2(405,300);game.view.zoom=300;game.view.set_camera_mode(3)
	await process_frame
	var handle: Vector2 = game.view.camera.unproject_position(game.model.terrain.world(Terrain.unpack(game.points[0]),4))
	check(game.hud.plan_overlay.pick_waypoint(handle) == 0, "An existing building has a draggable screen-sized planning handle")
	game._begin_waypoint_drag(0)
	var target: Vector2 = game.view.camera.unproject_position(game.model.terrain.world(Vector2(405,300)))
	game._move_waypoint(target); game._end_waypoint_drag()
	check(Terrain.unpack(game.points[0]).distance_to(Vector2(405,300)) < 1 and Terrain.unpack(item.point).is_equal_approx(Vector2(400,290)), "Dragging a building edits the preview while preserving the live building")
	var balance: float = game.model.money
	game.clear_plan()
	check(game.editing_id == -1 and Terrain.unpack(item.point).is_equal_approx(Vector2(400,290)) and game.model.money == balance, "Canceling a remodeling plan leaves the old structure and budget unchanged")
	game.begin_edit(item.id,"Bergblick","4a998f",1,20);game.points=[[405,300]];game._update_plan()
	check(not game.hud.confirm_button.disabled and game.hud.confirm_button.text.begins_with("Übernehmen"), "The actual plan shows an enabled remodeling confirmation and its fee")
	var fee: float = game.last_plan_check.cost
	game.confirm_plan();game.confirm_plan()
	check(item.rotation == 1 and item.color == "4a998f" and item.point == [405,300] and game.model.money == balance-fee and game.editing_id == -1, "Repeated confirmation applies and charges a remodel exactly once")
	game.view.rebuild()
	var rendered := false
	for mesh in game.view._occluders:
		if mesh.position.distance_to(game.model.terrain.world(Vector2(405,300))) < 0.1:
			rendered = absf(mesh.rotation.y-PI*0.5) < 0.001
	check(rendered, "The saved quarter-turn is rendered on the actual chalet")
	game.hud.display_options.open()
	await process_frame
	check(game.hud.display_options.visible and game.hud.blocks_map(Vector2(750,400)), "Graphics options block accidental construction underneath")
	check(root.get_visible_rect().encloses(game.hud.display_options.get_child(1).get_global_rect()), "Graphics options fit inside the viewport")
	var escape := InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true;game._input(escape)
	check(not game.hud.display_options.visible and not game.hud.menu.visible, "Escape closes the new dialog before opening any other screen")
	game._junction_showcase();game.paused=true
	game.view.focus=Vector2(200,205);game.view.zoom=220;game.view.set_camera_mode(0)
	game.view.set_quality("high")
	var piste: Dictionary = game.model.pistes[0]
	var geometry: Mesh = game.view._piste_meshes[piste.id].mesh
	var builds: int = game.view.snow_renderer.mesh_builds
	var uploads: int = game.view.snow_renderer.uploads
	Snow.touch(game.model.terrain,piste,{"id":31,"ability":2,"loops":0},0.2,0.4)
	game.view._draw_snow(piste)
	check(game.view._piste_meshes[piste.id].mesh == geometry and game.view.snow_renderer.mesh_builds == builds and game.view.snow_renderer.uploads == uploads+1, "Traffic uploads only height data and never rebuilds the piste geometry")
	game.view._draw_snow(piste)
	check(game.view.snow_renderer.uploads == uploads+1, "Unchanged snow reuses the same texture without another upload")
	var texture: ImageTexture = game.view.snow_renderer.surfaces[piste.id].texture
	var height_image := texture.get_image()
	var accurate := true
	for row in range(Snow.rows(piste)):
		for lane in range(Snow.LANES+1):
			accurate = accurate and absf(height_image.get_pixel(lane,row).r*0.95-0.35-piste.surface[row*(Snow.LANES+1)+lane]) < 0.002
	check(accurate, "The GPU height texture represents all local snow values within two millimetres")
	game.view._trace_cache.clear();game.view._draw_tracks(false)
	check(game.view.trace_samples <= 48, "Automatic trace generation respects a fixed per-pass work budget")
	game.view._draw_tracks();game.view._draw_tracks()
	check(game.view.trace_samples == 0 and game.view._trace_cache.size() <= 6000, "Unchanged traces reuse cached path samples and keep bounded memory")
	for p in game.model.pistes: Snow.groom(p,1)
	game.model.guests.clear();game.view._draw_tracks()
	check(game.view._track_mesh.mesh == null, "Grooming removes visible historical traces")
	check(game.view.forest.groups.size() > 4 and game.view.forest.distant.get_surface_count() == 1 and game.view.forest.distant.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() < game.view.forest.detailed.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), "Forest chunks use a simpler distant model instead of drawing every detailed branch")
	game.view.forest.update(Vector2(200,205),90,0)
	var hidden := 0
	for group in game.view.forest.groups:
		if not group.node.visible: hidden += 1
	check(hidden > 0, "Offscreen forest chunks are actually hidden in a close camera view")
	var lift: Dictionary = game.model.lifts[0]
	var data: Dictionary = game.view._vehicle_sets[lift.id]
	check(data.node.multimesh.instance_count == game.model.fleet_layout(lift).count, "Each lift allocates exactly its own fleet rather than thousands of spare vehicles")
	game.view.focus=Vector2(2000,2000);game.view._process(0)
	var old_clock: float = data.clock
	game.view.simulation_fraction=0.5;game.view._process(0)
	check(not data.node.visible and data.clock == old_clock, "A distant lift skips vehicle updates while the model clock remains available")
	game.view.focus=Terrain.unpack(lift.bottom);game.view._process(0)
	check(data.node.visible and data.node.multimesh.get_instance_transform(0).origin.distance_to(game.model.carrier_pose(lift,0,0.5).transform.origin) < 0.002, "Returning to a lift restores its current physical position without slowing the simulation")
	game.model.admit_guest(0)
	var guest: Dictionary = game.model.guests[-1]
	for index in range(guest.route.legs.size()):
		if guest.route.legs[index].kind == "ski": guest.leg=index;game.model._start_leg(guest);break
	guest.elapsed=guest.duration*0.5
	game.view.focus=game.model.terrain.point_on_path(game.model.asset(guest.route.legs[guest.leg].id).points,0.5)
	game.view.simulation_fraction=0;game.view._process(0)
	var position: Vector3 = game.view._guest_positions[guest.id]
	var screen: Vector2 = game.view.camera.unproject_position(position)
	check(game.view.pick_guest(screen) == guest.id, "Picking uses the actual visible guest position")
	game.hud.set_map_focus(true);game.hud.show_guest(guest.id);game.view._process(0)
	check(game.hud.selected_guest == guest.id and game.hud.guest_face.visible and game.view._selection.visible and not game.hud.map_focus, "A guest tap opens the rich portrait profile and marks that visitor in the world")
	check(game.hud.inspector_text.text.contains("Energie") and game.hud.inspector_text.text.contains("Jahre") and game.hud.inspector_text.text.contains("Fahrstil"), "The actual guest inspector includes identity, needs and personal skiing style")
	var previous: Vector3 = position
	var smooth := true
	for i in range(1,31):
		game.view.simulation_fraction=i*0.004
		game.view._process(0)
		var next: Vector3 = game.view._guest_positions[guest.id]
		smooth = smooth and next.distance_to(previous) > 0 and next.distance_to(previous) < 1
		previous=next
	check(smooth, "Skier interpolation moves continuously through all intermediate display frames")
	game.view.follow_guest=guest.id;game.view._process(0)
	check(game.view._guest_positions[guest.id].distance_to(game.model.guest_position(guest,game.view.simulation_fraction)) < 0.002, "The followed skier uses the exact path and snow contact instead of a coarse approximation")
	var count: int = game.model.guests.size()
	game.preferences.quality="economy";game.preferences.snowfall=false;game.preferences.apply(game.view);game.view._process(0)
	check(game.view.quality_tier == 0 and not game.view._sun.shadow_enabled and not game.view._snow.emitting and game.model.guests.size() == count, "Economy settings reduce visual cost while retaining every simulated guest")
	game.preferences.quality="auto";game.preferences.target_fps=30;game.preferences.apply(game.view)
	var scale: float = root.scaling_3d_scale
	for i in range(60): game.view._adapt_quality(1.0/30)
	check(absf(game.view.frame_target-1.0/30) < 0.0001 and root.scaling_3d_scale >= scale, "Automatic quality honors a 30 FPS target without treating its frame interval as overload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.preferences.path))
	game.queue_free();await process_frame;await process_frame
	print("CUSTOMIZATION SCENE: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
