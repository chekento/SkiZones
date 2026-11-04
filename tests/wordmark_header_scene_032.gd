extends SceneTree
var game: Node
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(value: bool,label_text: String) -> void:
	if value:passed+=1;print("PASS ",label_text)
	else:failed+=1;push_error("FAIL "+label_text)
func settle() -> void:
	for frame in range(5):await process_frame
func inside(node: Control) -> bool:
	return Rect2(Vector2.ZERO,Vector2(root.size)).grow(1).encloses(node.get_global_rect())
func capture(stem: String) -> void:
	await settle();await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	check(root.get_texture().get_image().save_png("res://build/qa/"+stem+".png")==OK,"Capture "+stem)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.start_game(true);game.paused=true;game.set_process(false);game.view.set_process(false)
	game.preferences.path="user://wordmark032.cfg";game.apply_language("de")
	game.hud.achievement_overlay.hide();game.hud.achievement_overlay.set_process(false)
	var hud: CanvasLayer=game.hud
	var wordmark: Texture2D=hud.header_logo.texture
	check(wordmark!=null and wordmark.get_width()==2172 and wordmark.get_height()==724,"Header uses the original wide generated wordmark")
	check(hud.menu_logo.texture==wordmark and wordmark.resource_path.ends_with("skizones_wordmark.png"),"Menu and header share the exact wordmark instead of an app icon")
	check(FileAccess.get_sha256("res://assets/branding/skizones_wordmark.png")=="ebcb97e2436a499083912bed2b4e45cc79b4fb1f041befcc89faeb5560f65b19","Wordmark bytes match the original requested artwork")
	check(wordmark.get_image().get_format()==Image.FORMAT_RGBA8 and wordmark.get_image().get_pixel(2171,723).a<0.1,"Original transparent background is retained")
	game.model.report.tickets=100;game.model.report.services=50;game.model.report.costs=30
	hud.refresh()
	check(hud.header_details.money.text=="Heute: 120 €","Operating detail reflects actual tickets, service income and costs")
	check(hud.header_details.guests.text=="0 warten" and hud.header_details.clock.text=="Pause","Queue and pause details reflect real operating state")
	var before: String=JSON.stringify(game.model.snapshot())
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
	for resolution in [Vector2i(1440,900),Vector2i(960,540),Vector2i(420,860),Vector2i(560,360)]:
		root.size=resolution;await settle();hud._update_safe_area();hud.refresh();await settle()
		check(inside(hud.header_panel) and inside(hud.header_logo),"Header and wordmark fit "+str(resolution))
		check(inside(hud.header_save_button) and inside(hud.header_menu_button),"Save and menu remain reachable at "+str(resolution))
		check(hud.header_logo.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED and hud.header_logo.size.x>hud.header_logo.size.y*1.7,"Header wordmark stays wide and undistorted at "+str(resolution))
		check(hud.header_details.money.visible==(resolution.x>=1080),"Extra details adapt to available screen width at "+str(resolution))
		hud.hide_menu();await capture("wordmark-032-header-"+str(resolution.x))
		hud.show_menu();await settle()
		check(inside(hud.menu_panel) and inside(hud.menu_logo),"Main-menu wordmark fits "+str(resolution))
		check(hud.menu_logo.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,"Menu preserves original wordmark proportions")
		await capture("wordmark-032-menu-"+str(resolution.x))
		hud.hide_menu()
	check(JSON.stringify(game.model.snapshot())==before,"Branding and header presentation do not alter career state")
	# Repeat a small window with the game's normal large canvas stretch.
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_size=Vector2i(1440,900)
	root.size=Vector2i(560,360);await settle();hud._update_safe_area();await settle()
	check(hud._header_micro and not hud.header_details.money.visible,"Phone header density follows real pixels on a stretched canvas")
	await capture("wordmark-032-stretched-phone")
	game.queue_free();await process_frame;await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
