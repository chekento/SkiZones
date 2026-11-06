extends SceneTree
## 0.38 real inspector, staffing, hotel-entry and fullscreen career QA.
const Saves=preload("res://src/core/save_store.gd")
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok:bool,name:String) -> void:
	if ok:passed+=1;print("PASS ",name)
	else:failed+=1;push_error("FAIL "+name)
func settle() -> void:
	for i in range(4):await process_frame
func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-ui-038"):
		push_error("Isolated GUI test data dir required")
		quit(1);return
	var game:Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.start_game(true)
	game.set_process(false)
	game.view.set_process(false)
	game.view.hide()
	game.paused=true
	game.model.campaign.mode="free"
	game.model.money=2000000
	var hotel:Dictionary={}
	for z in range(160,420,34):
		for x in range(70,430,34):
			if game.model.build_building("hotel",Vector2(x,z)).ok:hotel=game.model.buildings[-1];break
		if not hotel.is_empty():break
	check(not hotel.is_empty(),"Test resort builds a real hotel")
	if hotel.is_empty():quit(1);return
	game.hud.show_context("inspect",int(hotel.id))
	var actions:Control=game.hud.inspector_actions
	var stats:Control=game.hud.inspector_text
	check(actions.get_parent()==stats.get_parent() and actions.get_index()<stats.get_index(),"Inspector actions appear before long statistics and notes")
	check(stats.text.contains("UMSATZ") and stats.text.contains("KOSTEN"),"Building inspector displays actual sales and operating costs")
	var crew:Control=game.hud.lift_staff
	crew.open(int(hotel.id))
	await settle()
	check(crew.visible,"Building team opens with live hotel statistics")
	var crew_tabs:TabContainer=crew.tabs
	for index in range(crew_tabs.get_tab_count()):
		if crew_tabs.get_tab_title(index)==game.hud.L.text("Personal"):crew_tabs.current_tab=index
	await settle()
	check(crew.find_child("optional_hotel",true,false)!=null and crew.find_child("optional_security",true,false)!=null,"Optional hotel staff have direct hire buttons separate from mandatory team")
	for index in range(crew_tabs.get_tab_count()):
		if crew_tabs.get_tab_title(index)==game.hud.L.text("Gestalten"):crew_tabs.current_tab=index
	await settle()
	var entry:Button=crew.find_child("open_hotel_simulator",true,false) as Button
	check(entry!=null and entry.visible,"Design tab offers direct hotel simulator entry")
	if entry!=null:entry.pressed.emit()
	await settle()
	check(game.hud.experience.visible and not crew.visible,"Hotel simulator entry really opens the room/hygiene management interface")
	game.hud.experience.close()
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	for viewport in [Vector2i(1440,900),Vector2i(420,860),Vector2i(740,360)]:
		root.size=viewport
		await settle()
		game.hud.career_slots.open()
		await settle()
		var career:Control=game.hud.career_slots
		var rect:Rect2=career.get_global_rect()
		check(rect.position.x>=-1 and rect.position.y>=-1 and rect.end.x<=float(viewport.x)+1 and rect.end.y<=float(viewport.y)+1,"Career manager is full-screen, with no exposed main-menu band at "+str(viewport))
		check(career.visible and career.cards.get_child_count()==4,"Career manager still shows four separated career cards")
		career.hide()
	game.queue_free()
	await settle()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
