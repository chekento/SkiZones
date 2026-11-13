extends SceneTree
const L=preload("res://src/core/i18n.gd")
const Training=preload("res://src/core/staff_training_042.gd")
const Reaction=preload("res://src/ui/reaction_game.gd")
var passed:=0
var failed:=0
var game:Node
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func settle()->void:
	for i in range(3):await process_frame
func tap(button:Control,page:ScrollContainer)->void:
	page.ensure_control_visible(button);await settle()
	check(root.get_visible_rect().grow(1).encloses(button.get_global_rect()),"Actual touch target is visible on the phone")
	var at:Vector2=root.get_screen_transform()*button.get_global_rect().get_center()
	var event:=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=true;Input.parse_input_event(event);await process_frame
	event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=false;Input.parse_input_event(event);await settle()
func page_named(ui:Control,caption:String)->ScrollContainer:
	for index in range(ui.tabs.get_tab_count()):
		if ui.tabs.get_tab_title(index)==L.text(caption):ui.tabs.current_tab=index;await settle();return ui.tabs.get_current_tab_control()
	return null
func capture(stem:String)->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	check(root.get_texture().get_image().save_png("res://build/qa/"+stem+".png")==OK,"Actual renderer capture saved")
func run()->void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await settle()
	game.start_game(true);game.set_process(false);game.view.set_process(false);game.model.Ops.enable(game.model)
	# Do not overwrite a real career slot from this UI harness. Save and replay
	# integration is independently exercised in staff_training_042.gd.
	game.has_game=false
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
	var lodge:Dictionary=game.model.buildings.filter(func(b):return b.kind=="lodge")[0]
	for language in ["de","en"]:
		game.apply_language(language)
		for dims in [Vector2i(360,740),Vector2i(420,860),Vector2i(740,360)]:
			root.size=dims;await settle();game.model.day+=1;game.paused=false;game.hud.hide_menu()
			var ui:Control=game.hud.experience;ui.open(int(lodge.id))
			var page:ScrollContainer=await page_named(ui,"Betriebstraining")
			var academy:Control=ui.find_child("staff_academy",true,false)
			check(academy!=null and not academy.employees.is_empty(),language+str(dims)+": real building team is selectable")
			check(root.get_visible_rect().grow(1).encloses(ui.window.close_button.get_global_rect()),"Building close action stays reachable")
			var employee_id:int=academy.employees[0].id
			var xp:int=Training.person(game.model,employee_id).get("training",{}).get("xp",0)
			await tap(academy.find_child("academy_start",true,false),page)
			check(not academy.session.is_empty() and game.paused,"Finger tap starts a pausing course")
			for step in range(3):
				var task:Dictionary=Training.challenge(game.model,academy.session)
				if task.is_empty():check(false,"Practical course still active");break
				await tap(academy.choices[int(task.answer)],page)
				check(int(academy.session.step)==step+1,"One actual finger choice advances exactly one practical case")
				if step<2:
					var next:Button=academy.find_child("academy_continue",true,false)
					check(next!=null,"Explanation waits for explicit continuation")
					if next!=null:await tap(next,page)
			check(Training.person(game.model,employee_id).training.xp==xp+36,"Actual touch answers earn experience for the chosen employee")
			check(game.paused,"Completing training preserves the containing building's pause")
			await capture("academy-042-%s-%dx%d" % [language,dims.x,dims.y])
			page=await page_named(ui,"Spielecke")
			var selector:OptionButton=ui.find_child("arcade_selector",true,false);selector.select(2);selector.item_selected.emit(2);await settle()
			var memory:Control=ui.find_child("memory_game",true,false);memory.set_process(false)
			check(memory.visible and memory.cells.size()==12,"Game selector opens a genuine twelve-card match")
			var snapshot:String=JSON.stringify(game.model.snapshot())
			var other:=-1
			for i in range(1,memory.state.deck.size()):
				if memory.state.deck[i]!=memory.state.deck[0]:other=i;break
			await tap(memory.cells[0],page);await tap(memory.cells[other],page)
			check(memory.state.moves==1 and memory.state.open.size()==2,"Two real finger taps reveal a mismatch and count one move")
			check(memory.cells.all(func(c):return c.disabled),"Mismatch blocks a third-card peek")
			selector.select(0);selector.item_selected.emit(0);var time_left:float=memory._remaining;memory._process(2.0)
			check(memory._remaining==time_left,"A hidden memory board cannot advance its reveal timer")
			selector.select(2);selector.item_selected.emit(2);memory._process(2.0);await settle()
			var partner:int=memory.state.deck.find(memory.state.deck[0],1)
			await tap(memory.cells[0],page);await tap(memory.cells[partner],page)
			check(memory.state.matched.size()==2 and memory.state.moves==2,"Matching real cards remain found")
			check(JSON.stringify(game.model.snapshot())==snapshot,"Arcade moves do not alter money, employee progress or resort state")
			await capture("memory-042-%s-%dx%d" % [language,dims.x,dims.y])
			ui.close();check(not game.paused,"Closing the building restores the original running state")
	game.model.day+=1;game.paused=false
	var experience:Control=game.hud.experience;experience.open(int(lodge.id))
	var training_page:ScrollContainer=await page_named(experience,"Betriebstraining")
	var academy:Control=experience.find_child("staff_academy",true,false)
	await tap(academy.find_child("academy_start",true,false),training_page)
	var trainee:Dictionary=Training.person(game.model,int(academy.session.person))
	var before_cancel:int=trainee.training.xp
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST);await settle()
	check(not experience.visible and not game.paused and trainee.training.xp==before_cancel,"Android Back cancels a partial building course without a stuck pause or unearned XP")
	game.hud.lift_staff.open(int(lodge.id));await settle()
	var staff_ui:Control=game.hud.lift_staff
	training_page=await page_named(staff_ui,"Akademie")
	academy=staff_ui.find_child("staff_academy",true,false)
	await tap(academy.find_child("academy_start",true,false),training_page)
	check(game.paused,"Team-panel course owns its temporary pause")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST);await settle()
	check(not staff_ui.visible and not game.paused,"Android Back releases the team course's own pause")
	var reaction:=Reaction.new();root.add_child(reaction);await settle();reaction.set_process(false)
	reaction.press();reaction._process(3.0);reaction._go_at=Time.get_ticks_usec()-220000;reaction.press()
	check(reaction.samples.size()==1 and reaction.samples[0]>=220 and reaction.samples[0]<400,"Reaction score uses the monotonic press time, not a stale frame delta")
	reaction.press();reaction._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(reaction.phase=="next" and reaction.samples.size()==1,"Backgrounding cancels a timed round without a false score")
	reaction.queue_free();game.queue_free();await settle()
	print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
