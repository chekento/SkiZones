extends SceneTree
const Goals=preload("res://src/core/long_goals_042.gd")
const L=preload("res://src/core/i18n.gd")
var passed:=0
var failed:=0
var game:Node
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func settle()->void:
	for i in range(4):await process_frame
func tap(button:Control,page:ScrollContainer)->void:
	page.ensure_control_visible(button);await settle()
	check(root.get_visible_rect().grow(1).encloses(button.get_global_rect()),"Actual goal action fits the phone's visible touch area")
	var point:Vector2=root.get_screen_transform()*button.get_global_rect().get_center()
	var event:=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=true
	Input.parse_input_event(event);await process_frame
	event=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=false
	Input.parse_input_event(event);await settle()
func capture(name_value:String)->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	check(root.get_texture().get_image().save_png("res://build/qa/goal-feedback-042-"+name_value+".png")==OK,"Actual bilingual goal UI screenshot saved")
func run()->void:
	var orphan_baseline := Node.get_orphan_node_ids()
	root.disable_3d=true
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await settle()
	game.start_game(true);game.set_process(false);game.view.set_process(false)
	game.model.Ops.enable(game.model)
	# The real save callback is guarded; this UI test never writes a user's career.
	game.has_game=false
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
	for language in ["de","en"]:
		game.apply_language(language);await settle()
		game.set_process(false);game.view.set_process(false)
		for dims in [Vector2i(360,740),Vector2i(420,860),Vector2i(740,360)]:
			root.size=dims;await settle()
			game.hud.hide_menu();game.hud.management.hide()
			game.model.total_guests=0;game.model.total_rides=0
			game.model.campaign.long_goal_claims=["visitors","rides","team","winters"]
			game.model.campaign.long_goal_profit_days=1;game.model.campaign.happy=500
			game.model.minute=game.model.CLOSING
			game.model.report.day=game.model.day
			game.model.last_report=game.model.report.duplicate(true)
			var cash:float=game.model.money
			game.hud.show_report();await settle()
			var report:Control=game.hud.daily_dialog
			check(report.goal_claim.visible and report.goal_summary.visible,"Day report exposes earned goals before starting another day")
			check(root.get_visible_rect().grow(1).encloses(report.next_button.get_global_rect()),"Next-day action remains reachable")
			await capture("report-%s-%dx%d" % [language,dims.x,dims.y])
			await tap(report.goal_claim,report.scroll)
			check(game.model.money==cash+4000 and Goals.pending(game.model).is_empty(),"Real finger action collects only the two earned prizes")
			check(not report.goal_claim.visible and report.visible,"Collection refreshes the same day report and removes the settled action")
			var settled:float=game.model.money
			report._claim_goals();await settle()
			check(game.model.money==settled,"Repeated day-report activation cannot pay twice")
			report.hide()
			game.model.campaign.long_goal_claims=["happy","first_profit","rides","team","winters"]
			game.model.campaign.long_goal_profit_days=3;game.model.total_guests=1000
			game.hud.show_management_page(L.text("Karriere"));await settle()
			var office:Control=game.hud.management
			check(office.tabs.get_tab_title(7)==L.text("Betrieb") and office.tabs.get_tab_title(12)==L.text("Meldungen"),"Existing office tab positions are preserved")
			var page:ScrollContainer=office.tabs.get_current_tab_control()
			await tap(office.find_child("open_goals",true,false),page)
			check(office.tabs.get_tab_title(office.tabs.current_tab)==L.text("Ziele"),"Career shortcut opens the dedicated Goals page through touch")
			page=office.tabs.get_current_tab_control()
			var collect:Button=page.find_child("claim_all_goals",true,false)
			check(collect!=null and not collect.disabled,"Dedicated Goals page has a ready collection action")
			await capture("office-%s-%dx%d" % [language,dims.x,dims.y])
			cash=game.model.money
			await tap(collect,page)
			check(game.model.money==cash+4000 and Goals.pending(game.model).is_empty(),"Office bulk claim obeys partial prior claims and the original economic budget")
			collect=page.find_child("claim_all_goals",true,false)
			check(collect.disabled,"Settled office collection action is disabled")
			office.hide()
	game.queue_free();await settle()
	var leaked: Array = []
	for id in Node.get_orphan_node_ids():
		if id not in orphan_baseline: leaked.append(id)
	check(leaked.is_empty(),"Language changes and closing the resort leave no orphaned UI controls")
	print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
