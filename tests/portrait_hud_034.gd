extends SceneTree
## The real canvas must never stack the palette over an open inspector
## on portrait phones. No button-only visibility mocks, no save edits.
var passed := 0
var failed := 0
var game: Node

func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: passed += 1; print("PASS ", message)
	else: failed += 1; push_error("FAIL " + message)

func settle() -> void:
	for i in range(6): await process_frame

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	check(root.get_texture().get_image().save_png("res://build/qa/"+name+".png")==OK, "Captured "+name)

func no_overlay_collision(hud: CanvasLayer, message: String) -> void:
	var tool: Control = hud.tools_panel
	var inspector: Control = hud.inspector_panel
	check(not (tool.visible and inspector.visible and tool.get_global_rect().intersects(inspector.get_global_rect())),message)

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.paused = true
	game.set_process(false)
	game.view.set_process(false)
	game.hud.achievement_overlay.hide()
	game.hud.achievement_overlay.set_process(false)
	var hud: CanvasLayer = game.hud
	var target: Dictionary = game.model.buildings[0]
	var original: String = JSON.stringify(game.model.snapshot())
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	for language in ["de","en"]:
		game.apply_language(language)
		hud = game.hud
		for resolution in [Vector2i(360,740),Vector2i(420,860),Vector2i(740,360)]:
			root.size=resolution
			await settle()
			hud._update_safe_area()
			hud.hide_menu()
			await settle()
			var portrait: bool = resolution.y > resolution.x
			hud.show_context("inspect")
			if portrait:
				hud.inspector_collapsed = true
				hud._apply_panel_visibility()
				await settle()
				check(hud.tools_panel.visible and not hud.inspector_panel.visible, "%s %s: building palette is available by default" % [language,str(resolution)])
				no_overlay_collision(hud,"%s %s: palette state has no overlapping drawers" % [language,str(resolution)])
				await capture("portrait-034-tools-%s-%d" % [language,resolution.x])
			hud.show_context("inspect",int(target.id))
			await settle()
			check(hud.inspector_panel.visible, "%s %s: selecting an existing building opens inspector" % [language,str(resolution)])
			if portrait:
				check(not hud.tools_panel.visible, "%s %s: building palette closes without erasing a plan" % [language,str(resolution)])
			no_overlay_collision(hud,"%s %s: inspector never obscures build tools" % [language,str(resolution)])
			if portrait:
				await capture("portrait-034-inspector-%s-%d" % [language,resolution.x])
				hud.toggle_inspector()
				await settle()
				check(hud.tools_panel.visible and not hud.inspector_panel.visible, "%s %s: toggling Info restores construction palette" % [language,str(resolution)])
				hud.toggle_inspector()
				await settle()
				check(not hud.tools_panel.visible and hud.inspector_panel.visible, "%s %s: Info can reopen without switching tools" % [language,str(resolution)])
				hud.show_context("building")
				await settle()
				check(hud.tools_panel.visible and not hud.inspector_panel.visible, "%s %s: an active build tool restores palette" % [language,str(resolution)])
				no_overlay_collision(hud,"%s %s: build mode has no overlapping side drawers" % [language,str(resolution)])
				await capture("portrait-034-build-%s-%d" % [language,resolution.x])
			check(JSON.stringify(game.model.snapshot()) == original, "%s %s: view transitions preserve the entire career" % [language,str(resolution)])
	game.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
