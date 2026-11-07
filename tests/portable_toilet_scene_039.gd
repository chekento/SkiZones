extends SceneTree
const Development=preload("res://src/core/wc_development.gd")
var passed:=0
var failed:=0
var game:Node
func _init() -> void:call_deferred("run")
func check(ok:bool,title:String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func settle() -> void:
	for i in range(8):await process_frame
func capture(name:String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/"+name+".png")
func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-portable-ui-039"):quit(1);return
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await settle()
	game.start_game(true);game.set_process(false);game.view.set_process(false);game.view.hide();game.paused=true
	game.model.money=2000000;game.model.campaign.mode="career";game.model.campaign.points=500
	check(game.model.build_building("wc_dixi",Vector2(155,300)).ok,"Actual GUI test constructs the sole Portable Toilet")
	var facility:Dictionary=game.model.buildings[-1]
	var id:int=int(facility.id)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
	for language in ["de","en"]:
		game.apply_language(language);await settle()
		var types:Array=[]
		for card in game.hud.building_browser.cards:
			if game.model.PublicWC.is_public(str(card.kind)):types.append(card.kind)
		check(types==["wc_dixi"],"Building browser has one purchasable toilet in "+language)
		# Old IDs remain restorable, but must be ABSENT from all buy menus.
		var hidden:=true
		var sole_count:=0
		for index in range(game.hud.building_choice.item_count):
			var label_text:String=game.hud.building_choice.get_item_text(index)
			if label_text==game.hud.L.text("Portable Toilet"):sole_count+=1
			for kind in ["wc_cabin","wc_module","wc_house","wc_luxury"]:
				hidden=hidden and label_text!=game.hud.L.text(game.model.Catalog.BUILDINGS[kind].name)
		check(hidden and sole_count==1,"All buy menus list exactly one Portable Toilet; four legacy IDs stay save-readable only")
		for viewport in [Vector2i(1536,864),Vector2i(360,740),Vector2i(420,860),Vector2i(740,360)]:
			root.size=viewport;await settle()
			var manager:Control=game.hud.experience
			manager.open(id);await settle()
			check(manager.heading.text=="Portable Toilet","Default toilet title is unbranded after language rebuild")
			var toolbar:Control=manager.primary_actions
			check(toolbar.get_child_count()==4 and toolbar.get_global_rect().end.x<=viewport.x and toolbar.get_global_rect().end.y<=viewport.y,"Cleaning, disposal, expansion and development are directly reachable: %s" % viewport)
			manager.find_child("public_wc_development_open",true,false).pressed.emit();await settle()
			check(manager.tabs.get_tab_title(manager.tabs.current_tab)==game.hud.L.text("Entwicklung"),"Direct development action opens the actual research tab")
			var choice:OptionButton=manager.find_child("wc_research_group",true,false)
			check(choice.item_count==10,"All ten research branches can be selected")
			if viewport.y>=600:check(choice.get_global_rect().end.y<=viewport.y,"Research selector is visible without scrolling past building previews")
			var branches:Array=range(10) if language=="de" and viewport.x==1536 else [0,9]
			for branch in branches:
				choice=manager.find_child("wc_research_group",true,false)
				choice.item_selected.emit(branch);await settle()
				var body:Control=manager.find_child("wc_development_tree",true,false)
				var buttons:Array=body.find_children("wc_research_*","Button",true,false).filter(func(button):return button is Button and not button is OptionButton)
				var fits:bool=buttons.size()==10
				for button in buttons:
					fits=fits and not button.text.is_empty() and button.size.y>=50 and button.get_global_rect().position.x>=0 and button.get_global_rect().end.x<=viewport.x
				check(fits,"Ten actual research actions fit branch %d in %s %s" % [branch,language,viewport])
			choice=manager.find_child("wc_research_group",true,false);choice.item_selected.emit(0);await settle()
			if language=="de" and viewport.x==1536:
				manager.find_child("wc_research_wc_logistics",true,false).pressed.emit();await settle()
				check(game.model.campaign.project.get("id","")=="wc_logistics","Actual research button starts the persisted project")
				if game.model.Ops.continuous(game.model):
					var target_day:int=game.model.day+1
					game.model.minute=1439
					for tick in range(32):
						if game.model.day>=target_day:break
						game.model.advance_minute(false)
				else:
					game.model.minute=game.model.CLOSING-1
					for tick in range(32):
						if game.model.day_finished():break
						game.model.advance_minute(false)
					game.model.next_day()
				manager._rebuild();await settle()
				manager.find_child("public_wc_upgrade",true,false).pressed.emit();await settle()
				check(int(facility.level)==2 and game.model.service_capacity(facility)==2,"Actual expansion button upgrades the same built facility")
			game.hud.refresh();await settle()
			check(not game.hud.achievement_overlay.visible,"Achievement notices wait while management controls are open")
			await capture("portable-tree-039-%s-%dx%d" % [language,viewport.x,viewport.y])
			manager.close()
	game.queue_free();await settle()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
