extends SceneTree
## Rendered 0.40 phone layout + actionable control-room integration.
const L=preload("res://src/core/i18n.gd")
const Map=preload("res://src/ui/resort_operations_map_040.gd")
const Catalog=preload("res://src/core/catalog.gd")
var passed:=0
var failed:=0

func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)

func _init() -> void:call_deferred("run")

func run() -> void:
	var game: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.set_process(false)
	game.view.set_process(false)
	game.paused=true
	game.hud.show_management()
	await process_frame
	var office: Control=game.hud.management
	check(office.visible and office.tabs.get_tab_count()>=9,"The 0.40 command center opens in the actual resort office")
	var index: int=-1
	for i in range(office.tabs.get_tab_count()):
		if office.tabs.get_tab_title(i)==L.text("Leitstand"):index=i
	check(index>=0,"The command center has its own clearly named office tab")
	if index>=0:
		office.tabs.current_tab=index
		await process_frame
		var maps: Array=office.find_children("*","Control",true,false).filter(func(node):return node.get_script()==Map)
		check(maps.size()==1 and maps[0].model==game.model,"The live queue map is embedded and bound to the actual resort")
		if not maps.is_empty():
			check(maps[0].custom_minimum_size.y>=250 and maps[0].mouse_filter==Control.MOUSE_FILTER_STOP,"The queue map has usable Android touch targets")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://build/qa")
		var width: int=int(root.get_visible_rect().size.x)
		check(root.get_texture().get_image().save_png("res://build/qa/040-command-center-%d.png"%width)==OK,"The 0.40 command center renders to a real screenshot")
		if index>=0:
			var command_page: ScrollContainer=office.tabs.get_child(index)
			command_page.scroll_vertical=1400
			for frame in range(3):await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://build/qa/040-bottleneck-map-%d.png"%width)==OK,"The operational bottleneck map renders and can be inspected independently")
	office.hide()
	var browser: Control=game.hud.building_browser
	browser.open()
	await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://build/qa/040-building-catalog-%d.png"%int(root.get_visible_rect().size.x))==OK,"The responsive building catalog has a captured phone/desktop layout")
	check(browser.sort_choice.item_count==4 and browser.ready_only!=null,"The new catalog exposes four sorts and a practical buildability filter")
	check(browser.grid.columns>=1 and browser.grid.columns<=4,"The catalog grid has a safe responsive column count")
	check(browser.cards.size()==Catalog.building_order().size(),"Every purchasable building has a real interactive card")
	check(browser.cards.filter(func(card):return card.kind=="wc_dixi").size()==1 and browser.cards.all(func(card):return card.kind not in ["wc_cabin","wc_module","wc_house","wc_luxury"]),"Only one upgradeable toilet is offered without discarding historical types")
	browser.search.text="Portable Toilet"
	browser._refresh(true)
	check(browser.cards.filter(func(card):return card.button.visible).size()==1,"The building finder isolates the Portable Toilet")
	browser.search.text=""
	browser.sort_choice.select(1)
	browser._refresh(true)
	var descending:=true
	for i in range(1,browser.cards.size()):
		descending=descending and Catalog.BUILDINGS[browser.cards[i-1].kind].cost>=Catalog.BUILDINGS[browser.cards[i].kind].cost
	check(descending,"Price sorting actually changes the catalog order from expensive to affordable")
	game.model.money=0
	browser.ready_only.button_pressed=true
	browser._refresh(true)
	var expected:=0
	for kind in Catalog.building_order():
		if Catalog.BUILDINGS[kind].cost<=game.model.money and game.model.build_access_message(kind,false)=="":expected+=1
	check(browser.cards.filter(func(card):return card.button.visible).size()==expected,"The availability filter excludes unaffordable and inaccessible buildings")
	browser.hide()
	game.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed"%[passed,failed])
	quit(1 if failed else 0)
