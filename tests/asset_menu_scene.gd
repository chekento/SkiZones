extends SceneTree
const Ops=preload("res://src/core/operations.gd")
const Catalog=preload("res://src/core/catalog.gd")
const Terrain=preload("res://src/core/terrain.gd")
var game: Node
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix):return node
	for child in node.get_children():
		var found:=button(child,prefix)
		if found!=null:return found
	return null
func texts(node: Node) -> String:
	var result: String=node.text+"\n" if node is Label or node is Button else ""
	for child in node.get_children():result+=texts(child)
	return result
func hire_required(menu:Control) -> bool:
	# TabContainer applies page visibility on the next frame. Check the real
	# displayed action before activating it, rather than bypassing that state.
	await process_frame
	await process_frame
	var hire:Button=menu.find_child("fill_required_building_team",true,false) as Button
	check(hire!=null and hire.is_visible_in_tree() and not hire.disabled and hire.text.begins_with("Pflichtstellen besetzen"),"A visible enabled action explicitly fills mandatory building positions")
	if hire==null:return false
	hire.pressed.emit()
	return true
func capture(name_value: String) -> void:
	for frame in range(4):await process_frame
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/"+name_value+".png")
func setup_classic() -> void:
	game.clear_plan();game.hud.lift_staff.hide()
	game.model.new_game(true);Ops.enable(game.model);game.model.money=3000000;game.model.campaign.research.append("service");game.paused=true
	game.view.rebuild();game.hud.hide_menu();game.hud.refresh()
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.apply_language("de");game.start_game(true);game.paused=true;game.view.set_process(false)
	game.set_tool("piste")
	var lift: Dictionary=game.model.lifts[0]
	game.begin_edit(int(lift.id),lift.name,"",0,20)
	check(game.points.size()==2 and game.hud.palette.category=="lifts","Editing a populated lift plan selects the actual lift palette")
	game.clear_plan();game.model.money=3000000
	game.hud.lift_choice.select(Catalog.LIFTS.keys().find("chair2"));game.set_tool("lift")
	game.points=[[-270,-200],[-210,150]];game._update_plan()
	var preview: Dictionary=game.model.preview_lift("chair2",Vector2(-270,-200),Vector2(-210,150))
	check(preview.ok and preview.reversed_ends and game.hud.palette.category=="lifts","A reverse-clicked lift plan is valid and displays the matching tool")
	await capture("lift-docking-0180")
	game.clear_plan();game.model.new_game(true,20261031,"braunlage");game.model.money=3000000
	game.model.operations.staff.clear();game.model._duty_cache.clear();game.view.rebuild()
	var sections: Array=game.model.lifts.filter(func(part):return int(part.get("sections",1))>1)
	var upper: Dictionary=sections[-1]
	game.hud.show_context("inspect",int(upper.id));game.hud.refresh()
	check(game.hud.lift_staff_button.visible,"Selecting an upper lift exposes its direct operation menu")
	game.hud.lift_staff_button.pressed.emit()
	var menu: Control=game.hud.lift_staff
	check(menu.visible and not game.simulation_running() and game.hud.blocks_map(Vector2(700,400)),"The actual asset action opens a paused input-blocking dialog")
	check(menu.cards.size()==3 and texts(menu.stations).contains("Talstation") and texts(menu.stations).contains("Mittelstation") and texts(menu.stations).contains("Bergstation"),"One upper-section menu shows the valley, middle and summit teams")
	var rows:=Ops.line_station_team(game.model,upper);var needed:=0
	for row in rows:needed+=row.minimum
	var budget: float=game.model.money
	button(menu,"Alle Stationen besetzen").pressed.emit()
	check(game.model.operations.staff.size()==needed and game.model.money==budget-needed*180,"The real whole-line button hires each unique station vacancy exactly once")
	check(Ops.line_lifts(game.model,upper).all(func(part):return Ops.staffing(game.model,part).ok),"Both physical lift sections use the shared middle team")
	check(button(menu,"Alle Stationen besetzen").disabled,"Completed line hiring is clearly disabled")
	menu.tabs.current_tab=0
	check(texts(menu).contains("Abschnitt schließen") and texts(menu).contains("Verschleiß") and button(menu,"Anlage ausbauen")!=null,"The same dialog exposes section status, switching and upgrades")
	menu.tabs.current_tab=1
	await capture("three-stations-0180")
	button(menu,"Team & Schichten anzeigen").pressed.emit()
	check(button(menu,"In die Reserve versetzen").is_visible_in_tree(),"The actual team expander reveals employee and shift actions")
	setup_classic()
	var victim: Dictionary=game.model.lifts[0];victim.fault="electrical";game.model._operational_change()
	check(game.model.build_building("repair_office",Vector2(155,300)).ok,"A real connected workshop is available for the menu check")
	var workshop: Dictionary=game.model.buildings[-1]
	game.hud.show_context("inspect",int(workshop.id));game.hud.refresh()
	check(game.hud.lift_staff_button.visible and game.hud.lift_staff_button.text=="Betrieb & Gebäudeteam","Buildings expose the same direct entry point as lifts")
	game.hud.lift_staff_button.pressed.emit();menu=game.hud.lift_staff
	check(button(menu,"Von dieser Werkstatt reparieren").disabled,"The workshop explains that its own missing team prevents repair")
	menu.tabs.current_tab=1;budget=game.model.money
	if not await hire_required(menu):quit(1);return
	check(Ops.building_staffed(game.model,workshop) and game.model.money==budget-360,"The workshop's own button hires its technician and electrician")
	menu.tabs.current_tab=0
	budget=game.model.money;var parts: int=game.model.operations.parts
	button(menu,"Von dieser Werkstatt reparieren").pressed.emit()
	check(game.model.operations.repairs.size()==1 and int(game.model.operations.repairs[0].workshop)==int(workshop.id) and game.model.money==budget-900 and game.model.operations.parts==parts-1,"The actual workshop action dispatches its own paid repair with a spare part")
	check(texts(menu).contains("Arbeitsminuten"),"The repair progress stays visible in this workshop menu")
	var stock: int=game.model.operations.parts
	button(menu,"6 Ersatzteilpakete bestellen").pressed.emit()
	check(game.model.operations.delivery_at>=0 and game.model.operations.parts==stock and button(menu,"6 Ersatzteilpakete bestellen").disabled,"Ordering parts starts one real timed delivery without inventing immediate stock")
	await capture("asset-operations-0180")
	for kind in ["cocoa","schmarrn","pizzeria"]:
		setup_classic()
		check(game.model.build_building(kind,Vector2(155,300)).ok,kind+" is a genuinely placeable village shop")
		var food: Dictionary=game.model.buildings[-1]
		game.hud.show_context("inspect",int(food.id));game.hud.lift_staff_button.pressed.emit();menu=game.hud.lift_staff
		check(texts(menu).contains("Plätze belegt") and texts(menu).contains("Besuchserlöse"),kind+" shows its real occupancy and visit revenue")
		menu.tabs.current_tab=1
		if not await hire_required(menu):quit(1);return
		check(Ops.building_open(game.model,food),kind+" can hire its actual catering team directly")
		menu.tabs.current_tab=0;button(menu,"Schließen").pressed.emit()
		check(not food.enabled and not Ops.building_open(game.model,food),kind+" closes through its own operating action")
		button(menu,"Öffnen").pressed.emit()
		check(food.enabled and Ops.building_open(game.model,food),kind+" reopens without losing its assigned team")
		var level: int=food.level
		button(menu,"Anlage ausbauen").pressed.emit()
		check(int(food.level)==level+1,kind+" upgrades itself instead of redirecting to the resort office")
		if kind=="pizzeria":await capture("village-food-0180")
	menu.tabs.current_tab=1
	for screen in [Vector2i(960,540),Vector2i(560,360),Vector2i(1440,900),Vector2i(960,540)]:
		root.size=screen
		for frame in range(4):await process_frame
		var expected_columns: int=3 if screen.x>=1440 else 1
		check(root.get_visible_rect().encloses(menu.get_global_rect()) and menu.stations.columns==expected_columns,"The building dialog and staff columns adapt to actual screen "+str(screen))
	game.apply_language("en");game.hud.lift_staff.open(int(game.model.buildings[-1].id));menu=game.hud.lift_staff
	check(texts(menu).contains("BUILDING & TEAM") and menu.tabs.get_tab_title(0)=="Operations" and texts(menu).contains("Chef / Kitchen Manager"),"The English building menu uses the correct professional kitchen role")
	menu.hide();game.paused=true
	# This exercises the same strict handoff used on Android, with only the OS opener injected.
	# Simulate an installed 0.18 build: 0.19 cannot be an update to itself.
	var updater: Node=game.updater;updater.installed_version="0.18.0";updater.installed_code=23;var version: String="0.19.0";var filename: String="SkiZones-"+version+"-android-arm64.apk"
	var url: String=updater.Catalog.RELEASES+"/download/v"+version+"/"
	updater.candidate={"version":version,"file_name":filename,"apk":url+filename,"manifest":url+"manifest.json","release":updater.Catalog.RELEASES+"/tag/v"+version}
	updater.build={"sha256":"a".repeat(64),"size_bytes":33000000,"version_code":24,"version":version,"file_name":filename,"package":updater.Catalog.PACKAGE,"architecture":"arm64-v8a"}
	updater.link_opener=func(_url):return OK
	updater._set_status("available","");game.model.money=234567;updater.open_download()
	check(updater.state=="opened" and updater.last_opened_url==updater.candidate.release and FileAccess.file_exists(game.SaveStore.path_for_map(game.model.map_id)),"The browser handoff opens only the official release after saving the current resort")
	var last: String=updater.last_opened_url
	updater.candidate.release="https://example.com/untrusted";updater._set_status("available","");updater.open_download()
	check(updater.state=="error" and updater.last_opened_url==last,"A modified release link is rejected before a browser can open")
	game.queue_free();await process_frame;await process_frame
	print("ASSET MENU SCENE: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
