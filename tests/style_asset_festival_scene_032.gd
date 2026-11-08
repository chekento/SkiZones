extends SceneTree
const Catalog=preload("res://src/core/catalog.gd")
const Festival=preload("res://src/world/festive_buildings.gd")
const Icon=preload("res://src/ui/building_icon.gd")
var game: Node
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(value: bool,label_text: String) -> void:
	if value:passed+=1;print("PASS ",label_text)
	else:failed+=1;push_error("FAIL "+label_text)
func capture(stem: String,gray: bool=false) -> void:
	for frame in range(4):await process_frame
	await RenderingServer.frame_post_draw
	var img: Image=root.get_texture().get_image()
	if gray:
		var chroma:=0.0
		for y in range(0,img.get_height(),11):
			for x in range(0,img.get_width(),11):
				var color: Color=img.get_pixel(x,y)
				chroma=maxf(chroma,maxf(absf(color.r-color.g),absf(color.g-color.b)))
		check(chroma<0.018,"Actual monochrome frame, including symbols, has no color hues")
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	check(img.save_png("res://build/qa/"+stem+".png")==OK,"Capture "+stem)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.start_game(true);game.paused=true;game.set_process(false);game.view.set_process(false)
	game.model.money=500000
	game.model.build_building("hotel",Vector2(70,270))
	game.view.rebuild()
	game.preferences.path="user://asset-style-scene-032.cfg"
	game.view.set_camera_mode(1);game.view.focus=Vector2(145,200);game.view.zoom=265;game.view.pitch_degrees=45;game.view._update_camera()
	game.hud.set_map_focus(true);game.hud.achievement_overlay.hide();game.hud.achievement_overlay.set_process(false)
	var festive=game.view.festival_scene
	festive.store.path="user://festival-scene-assets-032.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(festive.store.path))
	for day in range(1,25):festive.store.claim(day,{"year":2026,"month":12,"day":24})
	for kind in Festival.KINDS:festive.store.buy_decoration(kind)
	festive.qa_date_override={"year":2026,"month":12,"day":24,"hour":18,"minute":0,"second":0}
	var before: String=JSON.stringify(game.model.snapshot())
	var original_nodes: Array=game.view.asset_root.get_children().duplicate()
	var terrain_vertices: PackedVector3Array=game.view.terrain_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].duplicate()
	for style in ["alpine","comic","pastel","cinematic","crisp","piste_map","neon_noir","aurora_ink","bauhaus","monochrome"]:
		game.view.set_visual_style(style);festive.build(game.view)
		var dressed: int=festive.root.get_children().filter(func(node):return node.has_meta("festive_building")).size()
		var festive_types: Array=festive.root.get_children().map(func(node):return node.get_meta("festival_kind",""))
		check(["gingerbread_lodge","gift_workshop","market_stall"].all(func(kind):return kind in festive_types),style+" actually places the three purchased Christmas buildings")
		check(dressed==game.model.buildings.size(),style+" dresses every actual resort building")
		if style=="alpine":
			check(festive.root.get_children().any(func(node):return node.get_meta("poster_campaign","")=="christmas"),"Christmas billboards physically appear during December beside decorations")
			check(festive.poster_sites.size()>0,"Christmas billboards use real nonblocking terrain sites")
		check(game.view.asset_root.get_children()==original_nodes,style+" preserves building, lift and vehicle nodes")
		check(game.view.terrain_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==terrain_vertices,style+" preserves terrain geometry")
		var decorations: Array=festive.root.get_children().filter(func(node):return node.has_meta("festival_kind"))
		var spaced:=true
		for i in range(decorations.size()):
			for j in range(i):
				var separation: float=decorations[i].position.distance_to(decorations[j].position)
				spaced=spaced and separation>=float(decorations[i].get_meta("festival_clearance"))+float(decorations[j].get_meta("festival_clearance"))-.01
		check(spaced,style+" purchased festive buildings and props do not overlap each other")
		await capture("assets-032-christmas-"+style,style=="monochrome")
		if style in ["pastel","bauhaus","monochrome"]:
			game.hud.building_browser.open()
			await capture("assets-032-catalog-"+style,style=="monochrome")
			game.hud.building_browser.hide()
	game.view.set_visual_style("bauhaus")
	festive.qa_date_override={"year":2026,"month":12,"day":31,"hour":23,"minute":59,"second":56}
	festive.build(game.view)
	await capture("assets-032-new-year-bauhaus")
	check(festive.root.get_children().any(func(node):return node.get_meta("festival_kind","")=="winter_stage"),"Purchased stage is actually present at New Year")
	check(not festive.firework_nodes.is_empty(),"New Year fireworks still use the actual seasonal clock")
	check(festive.root.get_children().any(func(node):return node.get_meta("poster_campaign","")=="new_year"),"New Year billboards visibly replace Christmas signs after December 26")
	festive.qa_date_override={"year":2026,"month":12,"day":26};festive.build(game.view)
	check(festive.root.get_children().any(func(node):return node.get_meta("poster_campaign","")=="christmas"),"Last Christmas poster day is December 26")
	festive.qa_date_override={"year":2026,"month":12,"day":27};festive.build(game.view)
	check(festive.root.get_children().any(func(node):return node.get_meta("poster_campaign","")=="new_year"),"New Year campaign begins exactly on December 27")
	festive.qa_date_override={"year":2027,"month":1,"day":1};festive.build(game.view)
	check(festive.root.get_children().any(func(node):return node.get_meta("poster_campaign","")=="new_year"),"New Year posters survive rollover to January 1")
	festive.qa_date_override={"year":2027,"month":1,"day":2};festive.build(game.view)
	check(festive.poster_sites.is_empty(),"Posters disappear after January 1")
	festive.qa_date_override={"year":2026,"month":11,"day":15};festive.build(game.view)
	check(not festive.root.get_children().any(func(node):return node.has_meta("festive_building")),"November advertising does not prematurely enable December roof dressing")
	check(festive.root.get_children().any(func(node):return node.get_meta("poster_campaign","")=="christmas"),"Christmas posters are already visible throughout November")
	check(JSON.stringify(game.model.snapshot())==before,"Theme and annual dressing leave the career completely unchanged")
	game.view.set_visual_style("alpine");check(not game.view._ink_layer.visible,"Leaving monochrome removes its screen filter")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(festive.store.path))
	game.queue_free();await process_frame;await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)

