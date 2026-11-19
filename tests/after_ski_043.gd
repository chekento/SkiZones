extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Activities=preload("res://src/core/building_activities.gd")
const Beverages=preload("res://src/core/beverages_043.gd")
const Bar=preload("res://src/ui/bar_workbench_043.gd")
const Toss=preload("res://src/ui/donut_ring_toss_043.gd")
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
func proof(task:Dictionary)->Dictionary:return {"ingredients":task.ingredients.duplicate(),"shakes":6,"fill":float(task.target),"garnish":task.garnish,"served":true}
func shift(model:RefCounted,id:int,practical:bool)->Dictionary:
	var session:=Activities.start(model,id,practical);var result:Dictionary={}
	for i in range(5):
		var task:=Activities.challenge(model,session)
		result=Activities.answer(model,session,proof(task) if practical else int(task.answer) if task.has("answer") else float(task.target))
	return result
func touch(work:Control,p:Vector2,pressed:bool,index:int=0)->void:
	var e:=InputEventScreenTouch.new();e.index=index;e.position=work.point(p);e.pressed=pressed;work._gui_input(e)
func drag(work:Control,p:Vector2,index:int=0)->void:
	var e:=InputEventScreenDrag.new();e.index=index;e.position=work.point(p);work._gui_input(e)
func prepare(work:Control)->void:
	for p in Bar.BOTTLES:touch(work,p,true);drag(work,Vector2(0.5,0.6));touch(work,Vector2(0.5,0.6),false)
	for i in range(6):
		touch(work,Vector2(0.4,0.45),true)
		for x in [0.48,0.56,0.64,0.56,0.48,0.4]:drag(work,Vector2(x,0.45))
		touch(work,Vector2(0.4,0.45),false)
func flight(work:Control,delta:float=0.1)->void:
	for i in range(300):
		if work.phase!="flight":break
		work._process(delta)
func throw_ring(work:Control,pull:Vector2)->void:
	touch(work,Toss.LAUNCH,true);drag(work,pull);touch(work,pull,false)
func viewport_touch(work:Control,p:Vector2,pressed:bool)->void:
	var e:=InputEventScreenTouch.new();e.position=work.get_global_transform_with_canvas()*work.point(p);e.index=0;e.pressed=pressed;Input.parse_input_event(e);await process_frame
func viewport_drag(work:Control,p:Vector2)->void:
	var e:=InputEventScreenDrag.new();e.position=work.get_global_transform_with_canvas()*work.point(p);e.index=0;Input.parse_input_event(e);await process_frame
func scroll_to(canvas:Control)->ScrollContainer:
	var node:Node=canvas.get_parent()
	while node!=null and not node is ScrollContainer:node=node.get_parent()
	if node!=null:node.ensure_control_visible(canvas)
	for i in range(5):await process_frame
	return node
func capture(file:String)->void:
	await RenderingServer.frame_post_draw;DirAccess.make_dir_recursive_absolute("res://build/qa")
	check(root.get_texture().get_image().save_png("res://build/qa/"+file)==OK,"Actual after-ski view rendered")
func run()->void:
	RenderingServer.set_render_loop_enabled(DisplayServer.get_name()!="headless")
	var model:=Resort.new();model.new_game(true);model.campaign.mode="free";model.money=10000000
	var bar:=place(model,"bar");var disco:=place(model,"disco");var sweets:=place(model,"schmarrn")
	check(not bar.is_empty() and not disco.is_empty() and not sweets.is_empty(),"Real connected after-ski businesses are built")
	if bar.is_empty() or disco.is_empty() or sweets.is_empty():quit(1);return
	check(not Activities.start(model,bar.id,true).ok and not Activities.start(model,disco.id,true).ok,"Practical mocktails cannot bypass real offer unlocks")
	check(not Toss.available(sweets),"Ring toss stays locked before the actual donut offer")
	bar.level=2;disco.level=3;sweets.level=3
	check(Beverages.available(bar) and Beverages.available(disco) and Toss.available(sweets),"Existing mocktail and donut offers unlock the matching activities")
	var session:=Activities.start(model,bar.id,true);var task:=Activities.challenge(model,session)
	check(task.mode=="mixing" and Beverages.recipe(disco,model.day,0).mode=="mixing","Bar and disco expose actual multi-step drink orders")
	var initial:String=JSON.stringify(model.snapshot())
	for field in ["garnish","served","shakes"]:
		var bad:=proof(task);bad.erase(field)
		check(not Activities.answer(model,session,bad).ok and session.step==0,"Incomplete drink cannot advance: "+field)
	var bad:=proof(task);bad.fill=NAN
	check(not Activities.answer(model,session,bad).ok,"Nonfinite drink volume cannot corrupt a score or save")
	bad=proof(task);bad.ingredients[0]=bad.ingredients[1]
	check(not Activities.answer(model,session,bad).ok,"Duplicate drink ingredients are rejected")
	check(JSON.stringify(model.snapshot())==initial,"Invalid or abandoned mixing changes no resort data")
	bad=proof(task);bad.fill=1.0
	check(Beverages.score(task,proof(task))==100 and Beverages.score(task,bad)<50,"Serving volume affects actual drink quality")
	bar.enabled=false
	check(not Activities.answer(model,session,proof(task)).ok,"Closed bar cannot complete a pending practical drink")
	bar.enabled=true;model.day+=1
	check(not Activities.answer(model,session,proof(task)).ok,"Old-day mixing cannot claim the fresh daily allowance")
	check(shift(model,bar.id,true).reward==250,"Five successful drinks use the existing shift reward")
	shift(model,bar.id,false);shift(model,bar.id,true)
	var money:float=model.money
	check(shift(model,bar.id,true).reward==0 and model.money==money,"Normal and practical bar shifts share the same three daily rewards")
	var before_journal:String=JSON.stringify(model.snapshot());var journal:=Activities.journal(model,bar.id)
	check(journal.plays==3 and journal.remaining==0 and journal.best==100 and journal.bonus==20,"Read-only journal reports the actual shared allowance and service bonus")
	check(JSON.stringify(model.snapshot())==before_journal,"Opening the journal does not mutate a save")
	model.day+=1;journal=Activities.journal(model,bar.id)
	check(journal.remaining==3 and journal.best==0 and journal.bonus==0,"Journal resets daily figures without stale service bonuses")
	check(Resort.new().restore(model.snapshot()).ok,"Practical bar progression keeps the existing save format")
	var work:=Bar.new();root.add_child(work);work.setup(Beverages.recipe(bar,model.day,0));work.size=Vector2(282,340)
	work.completed.connect(func(value:Dictionary):delivered=value)
	touch(work,Bar.BOTTLES[0],true);touch(work,Vector2(0.02,0.9),false)
	check(work.ingredients.is_empty(),"Dropping outside the shaker does not add an ingredient")
	prepare(work)
	check(work.stage==2 and work.prep==6,"Three real bottle drags and six sideways gestures unlock pouring")
	touch(work,Vector2(0.5,0.8),true);work._process(0.1);touch(work,Vector2(0.5,0.8),false,1)
	check(work.heating and work.stage==2,"A second finger cannot stop the active pour")
	work._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not work.heating and work.heat==0 and work.stage==2,"App switch cancels unfinished pour and permits a clean retry")
	touch(work,Vector2(0.5,0.8),true);work._process(0.1);drag(work,Vector2(0.02,0.1));touch(work,Vector2(0.02,0.1),false)
	check(not work.heating and work.stage==2 and work.heat==0,"Moving off the pour control cancels rather than serving invisibly")
	touch(work,Vector2(0.5,0.8),true)
	for i in range(roundi(float(work.task.target)*50)):work._process(0.1)
	touch(work,Vector2(0.5,0.8),false)
	check(work.stage==3 and work.heat>0.5,"Holding and releasing the actual pour stores its measured amount")
	touch(work,Bar.GARNISH,true);drag(work,Bar.GLASS);touch(work,Bar.GLASS,false)
	check(work.stage==4 and work.garnished,"Garnish must actually be dragged to the filled glass")
	touch(work,Bar.GLASS,true);drag(work,Vector2(0.75,0.3));touch(work,Vector2(0.75,0.3),false)
	check(work.submitted and Beverages.score(work.task,delivered)>=98,"Serving the completed glass emits one valid quality proof")
	var ring:=Toss.new();root.add_child(ring);ring.size=Vector2(282,340)
	touch(ring,Toss.LAUNCH,true);touch(ring,Toss.LAUNCH,false)
	check(ring.phase=="aim" and ring.attempts==0,"Tapping without a pull cannot consume a throw")
	throw_ring(ring,Vector2(0.5,0.98));flight(ring)
	check(ring.attempts==1 and ring.points==20,"A real ballistic throw lands on the centre peg")
	throw_ring(ring,Vector2(0.5,0.98));ring._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(ring.phase=="aim" and ring.attempts==1 and ring.points==20,"Backgrounding cancels an unfinished flight without consuming the throw")
	throw_ring(ring,Vector2(0.75,0.82));flight(ring)
	check(ring.attempts==2 and ring.points==20,"A real miss consumes one throw without inventing points")
	var comparison:=Toss.new();root.add_child(comparison);comparison.size=Vector2(736,183)
	throw_ring(comparison,Vector2(0.5,0.98));flight(comparison,1.0/120.0)
	check(comparison.points==20 and comparison.attempts==1,"Fixed-step trajectory gives the same result at phone, landscape and high frame rates")
	for i in range(3):throw_ring(ring,Vector2(0.5,0.98));flight(ring)
	check(ring.phase=="done" and ring.attempts==5 and ring.points==80,"Five real throws finish one bounded arcade round")
	touch(ring,Vector2(0.5,0.8),true);touch(ring,Vector2(0.5,0.8),false)
	check(ring.phase=="aim" and ring.attempts==0 and ring.points==0,"Replay clears only the transient ring-toss score")
	var unchanged:String=JSON.stringify(model.snapshot())
	work.queue_free();ring.queue_free();comparison.queue_free();await process_frame
	check(JSON.stringify(model.snapshot())==unchanged,"Neither arcade play nor an isolated bar workbench alters cash, XP or stock")
	var game:Node=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.start_game(true)
	for i in range(180):
		if not game.view.loading_in_progress:break
		await process_frame
	game.set_process(false);game.view.set_process(false);game.view.hide();game.paused=true;game.model=model
	game.hud.experience.open(bar.id);await process_frame
	var button:Button=game.hud.experience.find_child("start_mixing_shift",true,false)
	check(button!=null and not button.disabled,"Shipping bar UI exposes the unlocked practical shift")
	button.pressed.emit();await process_frame
	var canvas:Control=game.hud.experience.find_child("bar_workbench",true,false)
	check(canvas!=null and game.hud.experience.session.hands_on and game.paused,"Shipping bar window uses the real selected building while simulation stays paused")
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
	for i in range(game.hud.experience.tabs.get_tab_count()):
		if game.hud.experience.tabs.get_tab_title(i)=="Betriebstraining":game.hud.experience.tabs.current_tab=i
	for dimensions in [Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions;game.hud.experience.window._fit()
		for i in range(8):await process_frame
		var scroll:ScrollContainer=await scroll_to(canvas)
		check(canvas.size.x>200 and canvas.size.x<dimensions.x and canvas.size.y<=scroll.size.y,"Actual bar canvas fits mobile viewport "+str(dimensions))
		if dimensions.x==390:
			for p in Bar.BOTTLES:
				await viewport_touch(canvas,p,true);await viewport_drag(canvas,Vector2(0.5,0.6));await viewport_touch(canvas,Vector2(0.5,0.6),false)
			check(canvas.stage==1 and scroll.gesture_exclusions.has(canvas),"Real viewport bottle drags reach the shaker without page-scroll capture")
		if DisplayServer.get_name()!="headless":
			for phase in range(5):
				canvas.stage=phase;canvas.prep=3;canvas.heat=0.6;canvas.garnished=phase==4;canvas.queue_redraw();canvas.updated.emit()
				for i in range(5):await process_frame
				await capture("bar-%d-step-%d.png"%[dimensions.x,phase+1])
			canvas.stage=1;canvas.prep=0;canvas.garnished=false;canvas.updated.emit()
	game.hud.experience.open(sweets.id);await process_frame
	for i in range(game.hud.experience.tabs.get_tab_count()):
		if game.hud.experience.tabs.get_tab_title(i)=="Spielecke":game.hud.experience.tabs.current_tab=i
	var arcade:Control=game.hud.experience.find_child("donut_ring_toss",true,false)
	check(arcade!=null,"Actual sweet stand exposes ring toss with its real donut offer")
	var original_ring_state:String=JSON.stringify(model.snapshot())
	for dimensions in [Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions;game.hud.experience.window._fit()
		for i in range(8):await process_frame
		var scroll:ScrollContainer=await scroll_to(arcade)
		check(arcade.size.x>200 and arcade.size.y<=scroll.size.y,"Actual ring-toss canvas fits mobile viewport "+str(dimensions))
		if dimensions.x==390:
			await viewport_touch(arcade,Toss.LAUNCH,true);await viewport_drag(arcade,Vector2(0.5,0.98));await viewport_touch(arcade,Vector2(0.5,0.98),false);flight(arcade)
			check(arcade.attempts==1 and arcade.points==20 and scroll.gesture_exclusions.has(arcade),"Real viewport pull/release produces a scored throw through shipping UI")
		if DisplayServer.get_name()!="headless":await capture("ring-toss-%d.png"%dimensions.x)
	check(JSON.stringify(model.snapshot())==original_ring_state,"Shipping arcade gameplay leaves the real resort snapshot unchanged")
	game.hud.experience.close();game.queue_free();await process_frame;await process_frame
	print("RESULT: %d passed; %d failed"%[passed,failed]);quit(1 if failed else 0)
