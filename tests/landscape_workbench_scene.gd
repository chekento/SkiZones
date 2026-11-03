extends SceneTree
const Features = preload("res://src/core/piste_features.gd")
var game: Node
var passed := 0
var failed := 0

func _init() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	if value: passed+=1; print("PASS ",message)
	else: failed+=1; push_error("FAIL "+message)

func capture(file_name: String) -> void:
	for frame in range(4): await process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	check(root.get_texture().get_image().save_png("res://build/qa/"+file_name+".png")==OK,"Capture "+file_name)

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.set_process(false)
	game.view.set_process(false)
	game.paused=true
	game.apply_language("de")
	game.model.campaign.mode="free"
	game.model.money=3000000
	var view: Node3D=game.view
	var piste: Dictionary=game.model.pistes[0]
	Features.install(game.model,piste.id,"ramp",0.35,0)
	Features.install(game.model,piste.id,"rail",0.58,-3)
	Features.install(game.model,piste.id,"roller",0.80,2)
	game.model.build_building("cabin",Vector2(155,300))
	view.rebuild()
	view._process(0)
	check(view.contours_enabled and view.terrain_instance.material_override.get_shader_parameter("contours"),"Height contours are enabled in the real ground material by default")
	var vertices: PackedVector3Array=view.terrain_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
	view.set_contours(false)
	check(not view._height_labels.visible and view.terrain_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==vertices,"Contour preference hides elevation labels without changing playable geometry")
	view.set_contours(true)
	check(view.forest.groups.any(func(group):return group.species==1) and view.forest.groups.any(func(group):return group.species==2),"The live forest contains multiple actual tree species")
	check(view.landscape_details.groups.size()>0 and view.landscape_details.animals.size()>0,"The landscape contains batched details and bounded wildlife")
	check(view.foot_mesh.mesh.get_meta("walk_union",false) and view.foot_mesh.mesh.get_meta("border_width",0)>0,"Connected paths and plazas share a single rounded surface and snow banks")
	check(view.asset_root.get_children().filter(func(node):return node.has_meta("piste_module")).size()==3,"All three independently installed features have actual 3D assets")
	var clear := true
	for animal in view.landscape_details.animals:
		for fraction in [0.0,0.5,1.0]:
			var at: Vector2=animal.a.lerp(animal.b,fraction)
			clear=clear and not view.forest.clearing.has(Vector2i((at/view.forest.CELL).floor()))
	check(clear,"Wildlife patrols stay clear of planned ski and village corridors")
	view.focus=Vector2(150,-20)
	view.zoom=500
	view.yaw=0.40
	view.set_camera_pitch(36)
	game.hud.set_map_focus(true)
	await capture("landscape-023-mountain")
	view.focus=Vector2(155,230)
	view.zoom=270
	view.set_camera_pitch(42)
	await capture("landscape-023-village")
	var browser: Control=game.hud.building_browser
	browser.open()
	await process_frame
	check(browser.visible and browser.cards.size()==game.model.Catalog.BUILDINGS.size() and not game.simulation_running(),"The full-screen catalog covers every available village building")
	check(game.hud.blocks_map(browser.window.get_global_rect().get_center()),"The catalog frame captures map input")
	await capture("landscape-023-catalog")
	browser.search.text="Ferienhütte"
	browser.search.text_changed.emit(browser.search.text)
	check(browser.cards.filter(func(card):return card.button.visible).size()==1,"Catalog search narrows the real building cards")
	browser.window.toggle_fullscreen()
	browser.window.position=Vector2(15,90)
	browser.window.size=Vector2(660,600)
	browser.window._fit()
	await process_frame
	check(not browser.window.fullscreen and browser.window.size.x<game.hud.root.size.x and not browser.blocks_map(game.hud.root.size-Vector2(10,10)),"A resized floating catalog leaves the map outside its own rectangle usable")
	await capture("landscape-023-floating-catalog")
	browser.selected_kind="cabin"
	browser._refresh(true)
	browser.choose.pressed.emit()
	check(game.tool=="building" and game.hud.building_kind()=="cabin" and browser.visible,"A floating catalog selects the real construction tool and can stay open")
	browser.hide()
	game.clear_plan()
	var workshop: Control=game.hud.piste_workshop
	workshop.open(piste.id)
	await process_frame
	check(workshop.visible and not game.simulation_running() and workshop.list.get_child_count()==3,"The piste editor lists all existing independent sections and pauses simulation")
	workshop.kind.select(2)
	workshop.position_slider.value=65
	workshop.lateral_slider.value=3
	workshop._refresh()
	await capture("landscape-023-piste-workshop")
	workshop.close()
	var options: Control=game.hud.display_options
	options.open()
	check(options.day_choice.item_count==3 and options.contours.button_pressed==game.preferences.contour_lines,"Actual settings expose pacing, contours and wildlife")
	options.hide()
	game.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d passed; %d failed"%[passed,failed])
	quit(1 if failed else 0)
