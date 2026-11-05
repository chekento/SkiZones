extends SceneTree
const Rooms = preload("res://src/core/hotel_rooms.gd")
var game: Node
var passed := 0
var failed := 0
func _init() -> void:call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func settle() -> void:
	for i in range(5):await process_frame
func find_control(name_value: String) -> Control:
	return game.hud.experience.find_child(name_value,true,false) as Control
func tap(control: Control) -> void:
	var ancestor: Node=control.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:ancestor.ensure_control_visible(control)
		ancestor=ancestor.get_parent()
	await settle()
	var at: Vector2=root.get_screen_transform()*control.get_global_rect().get_center()
	var event := InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=false
	Input.parse_input_event(event)
	await settle()
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.start_game(true)
	game.set_process(false);game.view.set_process(false);game.view.hide();game.paused=true
	game.model.campaign.mode="free";game.model.money=5000000
	var hotel: Dictionary={}
	for z in range(160,420,34):
		for x in range(70,430,34):
			if game.model.build_building("hotel",Vector2(x,z)).ok:hotel=game.model.buildings[-1];break
		if not hotel.is_empty():break
	check(not hotel.is_empty(),"The actual hotel interface has a constructed resort building")
	if hotel.is_empty():quit(1);return
	game.model.campaign.mode="career"
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
	for language in ["de","en"]:
		game.apply_language(language)
		game.hud.hide_menu()
		for dimensions in [Vector2i(360,740),Vector2i(420,860),Vector2i(740,360)]:
			root.size=dimensions
			await settle()
			var ui: Control=game.hud.experience
			ui.open(int(hotel.id))
			for i in range(ui.tabs.get_tab_count()):
				if ui.tabs.get_tab_title(i)==ui.L.text("Zimmer & Gäste"):ui.tabs.current_tab=i
			await settle()
			var before: String=JSON.stringify(game.model.snapshot())
			ui._rebuild();await settle()
			check(JSON.stringify(game.model.snapshot())==before,language+str(dimensions)+": reading room pages cannot mutate a save")
			if not hotel.has("room_operations"):
				var activate: Control=find_control("enable_room_operations")
				check(activate!=null and activate.size.x<=dimensions.x, "Activation is reachable in the real phone page")
				await tap(activate)
				check(hotel.has("room_operations"),"Actual phone touch activates persistent room management")
			var grid: GridContainer=find_control("hotel_room_grid") as GridContainer
			check(grid!=null and grid.size.x<=dimensions.x-16,language+str(dimensions)+": responsive room grid has no horizontal overflow")
			var bounds: Rect2=ui.window.get_global_rect()
			check(bounds.position.x>=-1 and bounds.end.x<=dimensions.x+1 and bounds.position.y>=-1 and bounds.end.y<=dimensions.y+1,language+str(dimensions)+": complete hotel window stays on screen")
			hotel.room_operations.rooms[0].clean=false
			ui._selected_room=1;ui._hotel_floor=0;ui._rebuild();await settle()
			var money: float=game.model.money
			await tap(find_control("clean_selected_room"))
			check(hotel.room_operations.rooms[0].clean and is_equal_approx(money-game.model.money,8),language+str(dimensions)+": real clean button charges once and updates the room")
			await tap(find_control("close_selected_room"))
			check(hotel.room_operations.rooms[0].closed,language+str(dimensions)+": real close-room button removes the room from bookings")
			await tap(find_control("close_selected_room"))
			check(not hotel.room_operations.rooms[0].closed,language+str(dimensions)+": the same control reopens the room")
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://build/qa")
			root.get_texture().get_image().save_png("res://build/qa/hotel-rooms-%s-%d-%d.png" % [language,dimensions.x,dimensions.y])
			ui.close()
	game.queue_free();await settle()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
