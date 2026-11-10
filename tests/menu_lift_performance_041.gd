extends SceneTree
## UI regression: a resort office with many buildings must not rebuild
## all hidden pages on every open, and the catalog must reuse style resources.
var passed:=0
var failed:=0
func check(ok:bool,detail:String)->void:
	if ok:passed+=1;print("PASS ",detail)
	else:failed+=1;push_error("FAIL "+detail)
func settle()->void:
	for i in range(3):await process_frame
func _init()->void:call_deferred("run")
func run()->void:
	var game:Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.start_game(true)
	game.set_process(false)
	game.view.set_process(false)
	game.paused=true
	game.hud.hide_menu()
	var office:Control=game.hud.management
	office.open()
	await settle()
	var count:int=office.tabs.get_tab_count()
	check(count>=8,"Resort office offers all expected tabs before any heavy page is built")
	var career:VBoxContainer=office._page_bodies[office.L.text("Karriere")]
	var research:VBoxContainer=office._page_bodies[office.L.text("Forschung")]
	var upgrades:VBoxContainer=office._page_bodies[office.L.text("Ausbau")]
	check(career.get_child_count()>0,"Career overview is built immediately")
	check(research.get_child_count()==0 and upgrades.get_child_count()==0,"Hidden research and construction pages stay unbuilt on opening")
	var initial_career:int=career.get_child_count()
	office.tabs.current_tab=3
	await settle()
	check(research.get_child_count()>0,"Research catalog builds on first selection only")
	check(career.get_child_count()==initial_career and upgrades.get_child_count()==0,"Opening a subtab leaves other page trees untouched")
	office.tabs.current_tab=4
	await settle()
	check(upgrades.get_child_count()>0,"Building upgrades page renders when requested")
	office.hide()
	office.open()
	await settle()
	check(career.get_child_count()==initial_career and research.get_child_count()>0,"Reopening the office refreshes only its current selected tab")
	office.tabs.current_tab=0
	await settle()
	check(career.get_child_count()>0,"Previously visited career page refreshes when selected again")
	office.hide()
	var browser:Control=game.hud.building_browser
	browser.open()
	await settle()
	var style_count:int=browser._style_cache.size()
	check(style_count==browser.cards.size() and style_count>0,"Catalog has one immutable cached style pair per building type")
	var style:StyleBox=browser._style_cache[browser.cards[0].kind].normal
	browser.hide()
	browser.open()
	await settle()
	check(browser._style_cache[browser.cards[0].kind].normal==style,"Reopening construction catalog does not allocate new style boxes")
	browser.hide()
	game.queue_free()
	await settle()
	print("RESULT: %d passed; %d failed"%[passed,failed])
	quit(1 if failed else 0)
