extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Rooms=preload("res://src/core/hotel_rooms.gd")
const Work=preload("res://src/ui/housekeeping_043.gd")
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func at(work:Control,p:Vector2)->Vector2:return Vector2(p.x*work.size.x,88+p.y*(work.size.y-104))
func touch(work:Control,p:Vector2,pressed:bool,index:int=0)->void:
	var event:=InputEventScreenTouch.new();event.position=at(work,p);event.pressed=pressed;event.index=index
	work._gui_input(event)
func drag(work:Control,p:Vector2,index:int=0)->void:
	var event:=InputEventScreenDrag.new();event.position=at(work,p);event.index=index
	work._gui_input(event)
func mouse(work:Control,p:Vector2,pressed:bool)->void:
	var event:=InputEventMouseButton.new();event.position=at(work,p);event.pressed=pressed;event.button_index=MOUSE_BUTTON_LEFT
	work._gui_input(event)
func complete(work:Control)->void:
	for p in Work.ITEMS:touch(work,p,true);touch(work,p,false)
	for i in range(3):touch(work,Work.LINEN[i],true);drag(work,Work.TARGETS[i]);touch(work,Work.TARGETS[i],false)
	for p in Work.SPOTS:
		touch(work,p,true)
		for i in range(12):drag(work,p+Vector2(0.035 if i%2==0 else -0.035,0))
		touch(work,p,false)
func run()->void:
	RenderingServer.set_render_loop_enabled(DisplayServer.get_name()!="headless")
	var model:=Resort.new();model.new_game(true);model.campaign.mode="free";model.money=5000000
	var hotel:Dictionary={}
	for z in range(160,420,34):
		for x in range(70,430,34):
			if model.build_building("hotel",Vector2(x,z)).ok:hotel=model.buildings[-1];break
		if not hotel.is_empty():break
	check(not hotel.is_empty(),"A real connected hotel is built")
	if hotel.is_empty():quit(1);return
	model.campaign.mode="career"
	Rooms.enable(model,hotel.id)
	var room:Dictionary=hotel.room_operations.rooms[0];room.clean=false
	var original: String=JSON.stringify(model.snapshot())
	var work:=Work.new();root.add_child(work);work.setup(model,hotel.id,room.id);work.size=Vector2(340,390)
	check(work.valid_room(),"Actual dirty room can be serviced")
	check(not work.finish().get("ok",false) and JSON.stringify(model.snapshot())==original,"Early confirmation neither bills nor cleans")
	work.note=""
	touch(work,Work.ITEMS[0],true);touch(work,Work.ITEMS[0],false,1)
	check(work.done.is_empty(),"A second finger cannot finish the active gesture")
	work.cancel_gesture()
	mouse(work,Work.ITEMS[0],true);mouse(work,Work.ITEMS[0],false)
	check(work.done==[0],"Mouse clicks collect the actual selected item")
	touch(work,Work.ITEMS[0],true);touch(work,Work.ITEMS[0],false)
	check(work.done==[0],"Collected items cannot count twice")
	for i in [1,2]:touch(work,Work.ITEMS[i],true);touch(work,Work.ITEMS[i],false)
	check(work.stage==1,"Three actual pickups unlock bed making")
	touch(work,Work.LINEN[0],true);drag(work,Vector2(0.95,0.95));touch(work,Vector2(0.95,0.95),false)
	check(work.stage==1 and work.done.is_empty(),"Dropping linen away from its bed target is rejected")
	touch(work,Work.LINEN[0],true);work._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT);touch(work,Work.TARGETS[0],false)
	check(work.done.is_empty(),"Backgrounding cancels an unfinished bed gesture")
	for i in range(3):touch(work,Work.LINEN[i],true);drag(work,Work.TARGETS[i]);touch(work,Work.TARGETS[i],false)
	check(work.stage==2,"Three matching linen drops unlock wiping")
	touch(work,Work.SPOTS[0],true);drag(work,Vector2(-2,-2));drag(work,Work.SPOTS[0]);touch(work,Work.SPOTS[0],false)
	check(work.done.is_empty(),"Off-canvas jumps cannot clean a stain")
	touch(work,Work.SPOTS[0],true);touch(work,Work.SPOTS[0],false)
	check(work.done.is_empty(),"A tap cannot replace real wiping strokes")
	for p in Work.SPOTS:
		touch(work,p,true)
		for i in range(12):drag(work,p+Vector2(0.035 if i%2==0 else -0.035,0))
		touch(work,p,false)
	check(work.stage==3 and JSON.stringify(model.snapshot())==original,"All nine hand actions are side-effect free until confirmation")
	var money:float=model.money
	model.money=0
	check(not work.finish().ok and not room.clean and not work.committed,"Insufficient budget leaves room dirty and allows retry")
	model.money=money
	check(work.finish().ok and room.clean and model.money==money-8,"Confirmation cleans the real room and charges exactly eight euros")
	var after:String=JSON.stringify(model.snapshot())
	check(not work.finish().get("ok",false) and JSON.stringify(model.snapshot())==after,"Duplicate confirmation cannot charge or reward again")
	check(Resort.new().restore(JSON.parse_string(after)).ok,"Serviced room remains compatible with existing save format")
	room.clean=false
	var other:=Work.new();root.add_child(other);other.setup(model,hotel.id,room.id);other.size=Vector2(700,390)
	complete(other)
	hotel.enabled=false
	check(not other.finish().get("ok",false) and not room.clean,"Closing the actual hotel before confirmation rejects completion")
	hotel.enabled=true
	room.clean=true
	check(not other.finish().get("ok",false),"A room cleaned elsewhere cannot be billed again")
	room.clean=false
	var interrupted:String=JSON.stringify(model.snapshot())
	other.queue_free();work.queue_free();await process_frame
	check(JSON.stringify(model.snapshot())==interrupted,"Abandoning the view changes no save, room, money or reward data")
	var game:Node=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.start_game(true)
	for frame in range(180):
		if not game.view.loading_in_progress:break
		await process_frame
	game.set_process(false);game.view.set_process(false);game.view.hide();game.paused=true
	game.model=model
	game.hud.experience.open(hotel.id)
	await process_frame
	var canvas:Control=game.hud.experience.find_child("housekeeping_canvas",true,false)
	check(canvas!=null and canvas.model==model and canvas.hotel_id==hotel.id and canvas.room_id==room.id,"Actual shipping hotel UI exposes the selected real room workbench")
	check(game.paused,"Room interaction keeps resort simulation paused")
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
	for i in range(game.hud.experience.tabs.get_tab_count()):
		if game.hud.experience.tabs.get_tab_title(i)=="Zimmer & Gäste":game.hud.experience.tabs.current_tab=i
	for dimensions in [Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions
		game.hud.experience.window._fit()
		for i in range(5):await process_frame
		if canvas!=null:
			print("LAYOUT ",dimensions," canvas=",canvas.size)
			check(canvas.size.x<=dimensions.x and canvas.size.x>200,"Workbench fits actual mobile layout "+str(dimensions))
			if DisplayServer.get_name()!="headless":
				var ancestor:Node=canvas.get_parent()
				while ancestor!=null:
					if ancestor is ScrollContainer:ancestor.ensure_control_visible(canvas)
					ancestor=ancestor.get_parent()
				for i in range(5):await process_frame
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://build/qa")
				check(root.get_texture().get_image().save_png("res://build/qa/housekeeping-%d.png"%dimensions.x)==OK,"Actual room-management rendering saved")
	game.hud.experience.close()
	game.queue_free();await process_frame;await process_frame
	print("RESULT: %d passed; %d failed"%[passed,failed]);quit(1 if failed else 0)
