extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Activities=preload("res://src/core/building_activities.gd")
const Kitchen=preload("res://src/core/kitchen_043.gd")
const Work=preload("res://src/ui/kitchen_workbench_043.gd")
var passed:=0
var failed:=0
var delivered:Dictionary={}
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func place(model:RefCounted,kind:String)->Dictionary:
	for z in range(160,420,34):
		for x in range(70,430,34):
			if model.build_building(kind,Vector2(x,z)).ok:return model.buildings[-1]
	return {}
func proof(task:Dictionary)->Dictionary:return {"ingredients":task.ingredients.duplicate(),"prep":6,"heat":float(task.target),"served":true}
func shift(model:RefCounted,id:int,hands_on:bool)->Dictionary:
	var session:=Activities.start(model,id,hands_on)
	var result:Dictionary={}
	for i in range(5):
		var task:=Activities.challenge(model,session)
		var value:Variant=proof(task) if hands_on else int(task.answer) if task.has("answer") else float(task.target)
		result=Activities.answer(model,session,value)
	return result
func send(work:Control,p:Vector2,pressed:bool,index:int=0)->void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=p*work.size;event.pressed=pressed;work._gui_input(event)
func drag(work:Control,p:Vector2,index:int=0)->void:
	var event:=InputEventScreenDrag.new();event.index=index;event.position=p*work.size;work._gui_input(event)
func prepare(work:Control)->void:
	for p in Work.BOWLS:send(work,p,true);drag(work,Vector2(0.5,0.65));send(work,Vector2(0.5,0.65),false)
	for i in range(6):
		send(work,Vector2(0.4,0.25),true)
		if work.task.mix:
			for n in range(16):drag(work,Vector2(0.4+(0.04 if n%2==0 else -0.04),0.25))
		else:
			for n in range(3):drag(work,Vector2(0.4,0.25+(n+1)*0.08))
		send(work,work.last,false)
func viewport_touch(work:Control,p:Vector2,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.position=work.get_global_transform_with_canvas()*(p*work.size);event.index=0;event.pressed=pressed;Input.parse_input_event(event)
	await process_frame
func run()->void:
	RenderingServer.set_render_loop_enabled(DisplayServer.get_name()!="headless")
	var model:=Resort.new();model.new_game(true);model.campaign.mode="free";model.money=10000000
	var restaurant:=place(model,"restaurant");var schmarrn:=place(model,"schmarrn");var bar:=place(model,"bar")
	check(not restaurant.is_empty() and not schmarrn.is_empty() and not bar.is_empty(),"Real connected food businesses are built")
	if restaurant.is_empty() or schmarrn.is_empty() or bar.is_empty():quit(1);return
	check(not Activities.start(model,bar.id,true).ok,"Drink-only bar cannot open a cooking shift")
	var session:=Activities.start(model,restaurant.id,true)
	var task:=Activities.challenge(model,session)
	check(task.mode=="cooking" and not task.mix and Kitchen.recipe(schmarrn,model.day,0).mix,"Actual business type determines cutting versus batter mixing")
	var snapshot:String=JSON.stringify(model.snapshot())
	var bad:=proof(task);bad.ingredients[0]=bad.ingredients[1]
	check(not Activities.answer(model,session,bad).ok and session.step==0,"Duplicate or missing ingredients cannot submit a meal")
	bad=proof(task);bad.heat=NAN
	check(not Activities.answer(model,session,bad).ok,"Nonfinite heat cannot enter saved shift scores")
	bad=proof(task);bad.served=false
	check(not Activities.answer(model,session,bad).ok,"A prepared but unserved meal cannot advance the shift")
	check(JSON.stringify(model.snapshot())==snapshot,"Rejected and abandoned meal proof changes no money, XP or saves")
	check(Kitchen.score(task,proof(task))==100,"Correct recipe at its own target scores full quality")
	bad=proof(task);bad.heat=1.0
	check(Kitchen.score(task,bad)<50,"Overcooking has a real quality penalty")
	restaurant.enabled=false
	check(not Activities.answer(model,session,proof(task)).ok and session.step==0,"Closing the actual business rejects a stale meal")
	restaurant.enabled=true;model.day+=1
	check(not Activities.answer(model,session,proof(task)).ok,"An expired cooking day cannot pay a fresh daily reward")
	check(shift(model,restaurant.id,true).reward==250,"Five successful practical meals use the existing capped shift reward")
	check(shift(model,restaurant.id,false).reward==250 and restaurant.activity.plays==2,"Normal training shares the exact same daily counter")
	shift(model,restaurant.id,true)
	var money:float=model.money
	check(shift(model,restaurant.id,true).reward==0 and model.money==money,"Fourth shift is free practice without money farming")
	model.day+=1
	check(shift(model,restaurant.id,true).reward==250,"A new actual resort day restores the normal cap")
	check(Resort.new().restore(model.snapshot()).ok,"Completed practical shift uses the existing compatible save format")
	for building in [restaurant,schmarrn]:
		var work:=Work.new();root.add_child(work);work.setup(Kitchen.recipe(building,model.day,0));work.size=Vector2(282,340)
		work.completed.connect(func(value:Dictionary):delivered=value)
		var before:String=JSON.stringify(model.snapshot())
		send(work,Work.BOWLS[0],true);send(work,Vector2(0.02,0.02),false)
		check(work.ingredients.is_empty(),"Dropping outside the board adds no ingredient")
		send(work,Work.BOWLS[0],true);send(work,Vector2(0.5,0.65),false,1);work.cancel_gesture()
		check(work.ingredients.is_empty(),"Second finger cannot finish a cooking drag")
		prepare(work)
		check(work.stage==2 and work.prep==6,"Real ingredient drags and six preparation gestures unlock cooking")
		send(work,Vector2(0.5,0.8),true);send(work,Vector2(0.5,0.8),false)
		work._process(0.1);work._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(not work.heating and work.heat==0 and work.stage==2,"App switch clears unfinished heating without an automatic good result")
		send(work,Vector2(0.5,0.8),true);send(work,Vector2(0.5,0.8),false)
		for n in range(roundi(float(work.task.target)*70)):work._process(0.1)
		send(work,Vector2(0.5,0.8),true);send(work,Vector2(0.5,0.8),false)
		check(work.stage==3,"Stopping the actual moving heat meter unlocks plating")
		send(work,Work.PLATE,true);drag(work,Vector2(0.75,0.3));send(work,Vector2(0.75,0.3),false)
		check(work.submitted and Kitchen.score(work.task,delivered)>=98,"Dragging the finished plate to the pass emits a valid scored meal")
		check(JSON.stringify(model.snapshot())==before,"Workbench alone never invents guest sales, inventory or a money reward")
		work.queue_free();await process_frame
	var game:Node=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.start_game(true)
	for frame in range(180):
		if not game.view.loading_in_progress:break
		await process_frame
	game.set_process(false);game.view.set_process(false);game.view.hide();game.paused=true;game.model=model
	game.hud.experience.open(restaurant.id);await process_frame
	var button:Button=game.hud.experience.find_child("start_kitchen_shift",true,false)
	check(button!=null,"Shipping restaurant UI exposes a practical cooking shift")
	button.pressed.emit();await process_frame
	var canvas:Control=game.hud.experience.find_child("kitchen_workbench",true,false)
	check(canvas!=null and game.hud.experience.session.hands_on and game.paused,"Shipping shift uses the real selected restaurant while time stays paused")
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
	for i in range(game.hud.experience.tabs.get_tab_count()):
		if game.hud.experience.tabs.get_tab_title(i)=="Betriebstraining":game.hud.experience.tabs.current_tab=i
	for dimensions in [Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions;game.hud.experience.window._fit()
		for i in range(8):await process_frame
		var scroll:Node=canvas.get_parent()
		while scroll!=null and not scroll is ScrollContainer:scroll=scroll.get_parent()
		scroll.ensure_control_visible(canvas)
		for i in range(5):await process_frame
		check(canvas.size.x>200 and canvas.size.x<dimensions.x and canvas.size.y<=scroll.size.y,"Real kitchen canvas fits available mobile viewport "+str(dimensions))
		if dimensions.x==390:
			await viewport_touch(canvas,Work.BOWLS[0],true)
			await viewport_touch(canvas,Vector2(0.5,0.65),false)
			check(canvas.ingredients.size()==1 and scroll.gesture_exclusions.has(canvas),"Viewport touch drag reaches actual workbench without page-scroll capture")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw;DirAccess.make_dir_recursive_absolute("res://build/qa")
			check(root.get_texture().get_image().save_png("res://build/qa/kitchen-%d.png"%dimensions.x)==OK,"Actual kitchen view rendered")
	for i in range(5):
		var current:Control=game.hud.experience.find_child("kitchen_workbench",true,false)
		current.completed.emit(proof(current.task));await process_frame
	var restart:Button=game.hud.experience.find_child("restart_activity_shift",true,false)
	restart.pressed.emit();await process_frame
	check(game.hud.experience.session.hands_on and game.hud.experience.session.step==0,"Completing five meals and choosing another round keeps practical cooking mode")
	game.hud.experience.close();game.queue_free();await process_frame;await process_frame
	print("RESULT: %d passed; %d failed"%[passed,failed]);quit(1 if failed else 0)
