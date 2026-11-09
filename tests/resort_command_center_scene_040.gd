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
	# Godot's project viewport may remain 1440x900 even when the process
	# is invoked with --resolution 420x860. Enforce a REAL portrait canvas,
	# otherwise the mobile QA artifact quietly contains only desktop images.
	var mobile:bool=OS.get_environment("SKIZONES_QA_PHONE")=="1"
	var intended:Vector2i=Vector2i(420,860) if mobile else Vector2i(1440,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	root.size=intended
	await process_frame
	check(root.get_visible_rect().size==Vector2(intended),"Real QA viewport is exactly %dx%d" % [intended.x,intended.y])
	var game: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.set_process(false)
	game.view.set_process(false)
	game.paused=true
	game.hud._update_safe_area()
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
		var shot:Image=root.get_texture().get_image()
		check(shot!=null and shot.get_width()==intended.x and shot.get_height()==intended.y,"Captured pixels match actual mobile/desktop canvas")
		check(shot.save_png("res://build/qa/040-command-center-%d.png"%width)==OK,"The 0.40 command center renders to a real screenshot")
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
	if root.get_visible_rect().size.x<=480:
		check(not browser.introduction.visible and browser.filters.columns==2,"Phone catalog saves vertical space with compact two-column filters")
		check(browser.category.custom_minimum_size.y>=46 and browser.sort_choice.custom_minimum_size.y>=46 and browser.ready_only.custom_minimum_size.y>=46,"Compact catalog retains accessible filter touch targets")
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
	# New 0.40 Android import controls must exist on every existing/empty
	# career and free-build card, including narrow 420px phone layouts.
	var slots:Control=game.hud.career_slots
	slots.open()
	await process_frame
	var career_imports:Array=slots.find_children("import_save_040","Button",true,false)
	check(career_imports.size()==4,"All four career slots expose the explicit secure JSON/ZIP importer")
	check(career_imports.all(func(button):return button.custom_minimum_size.y>=48),"Career import buttons retain touch-safe target height")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://build/qa/040-career-import-%d.png"%int(root.get_visible_rect().size.x))==OK,"Real responsive career import screenshot")
	slots.open_free()
	await process_frame
	var free_imports:Array=slots.find_children("import_save_040","Button",true,false)
	check(free_imports.size()==4,"All four independent free-play slots expose secure JSON/ZIP import")
	slots.hide()
	game.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed"%[passed,failed])
	quit(1 if failed else 0)
