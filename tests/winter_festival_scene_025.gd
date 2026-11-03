extends SceneTree
## Capture actual Godot renderer snapshots for the festive world, rather than
## claiming artwork quality from an untested procedural model definition.
const Terrain = preload("res://src/core/terrain.gd")
const VisualStyles = preload("res://src/core/visual_styles.gd")
const FestivalArt = preload("res://src/world/festival_art.gd")
const Calendar = preload("res://src/core/annual_festival.gd")
var passed := 0
var failed := 0

class CalendarWindow extends "res://src/ui/winter_festival.gd":
	var today := {"year":2026,"month":12,"day":5,"hour":23,"minute":59,"second":59}
	func current_date() -> Dictionary:
		return today.duplicate()

func find_button(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix): return node
	for child in node.get_children():
		var found:=find_button(child,prefix)
		if found!=null: return found
	return null

func check(ok: bool, message: String) -> void:
	if ok: passed+=1; print("PASS ",message)
	else: failed+=1; push_error("FAIL "+message)

func _init() -> void:
	call_deferred("run")

func capture(stem: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	var folder:=ProjectSettings.globalize_path("res://build/qa")
	DirAccess.make_dir_recursive_absolute(folder)
	var img:=root.get_texture().get_image()
	check(img!=null and img.get_width()>=1000 and img.save_png(folder.path_join(stem+".png"))==OK,"Actual rendered holiday screenshot: "+stem)

func run() -> void:
	for kind in ["tree","gifts","snowman","lanterns","star","garlands","clock","market","bell","firework"]:
		for style_id in VisualStyles.IDS:
			var mesh: ArrayMesh=FestivalArt.make(kind,style_id)
			check(mesh.get_surface_count()>0 and mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()>12,"Nonempty original 3D mesh: "+kind+"/"+style_id)
	var game: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.view.rebuild()
	game.paused=true
	game.set_process(false)
	game.view.set_process(false)
	game.view.set_camera_mode(1)
	game.view.focus=Terrain.BASE
	game.view.zoom=265
	game.view._update_camera()
	var festive=game.view.festival_scene
	festive.store.path="user://winter25_render_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(festive.store.path))
	check(festive.store.claim(24,{"year":2026,"month":12,"day":24}).ok,"Visual fixture earns winter coins for a purchasable countdown sign")
	check(festive.store.buy_decoration("clock").ok,"Visual fixture actually buys a countdown board before displaying it")
	festive.qa_date_override={"year":2026,"month":12,"day":24,"hour":16,"minute":0,"second":0}
	for style_id in VisualStyles.IDS:
		game.view.set_visual_style(style_id)
		# set_visual_style skips when unchanged; always inject the test date.
		festive.build(game.view)
		check(festive.root.get_child_count()>=1,"December places winter decorations in real "+style_id+" world")
		await capture("winter25-christmas-"+style_id)
	festive.qa_date_override={"year":2026,"month":12,"day":31,"hour":23,"minute":59,"second":55}
	festive.build(game.view)
	check(festive.clock_label!=null and festive.clock_label.text=="00:00:05","New Year's countdown board displays actual remaining five seconds")
	check(festive.firework_nodes.size()==3,"New Year's Eve depicts 3 low-cost fireworks with theme lighting")
	await capture("winter25-new-year-countdown")
	festive.qa_date_override={"year":2027,"month":1,"day":2,"hour":13,"minute":0,"second":0}
	festive.build(game.view)
	check(festive.root.get_child_count()==0,"All event-only decor automatically retires after January 1")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(festive.store.path))
	game.apply_language("en")
	var panel:=CalendarWindow.new()
	game.hud.root.add_child(panel)
	panel.setup(game.hud)
	panel.archive.path="user://winter25_calendar_ui_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(panel.archive.path))
	panel.open()
	check(panel.visible and find_button(panel,"★ 6").disabled,"An open December 5 calendar keeps tomorrow's bonus door locked")
	panel.today={"year":2026,"month":12,"day":6,"hour":0,"minute":0,"second":0}
	panel._process(0.1)
	var door:=find_button(panel,"★ 6")
	check(door!=null and not door.disabled,"A calendar left open over midnight unlocks the actual new day's door")
	door.pressed.emit()
	check(panel.archive.overview(panel.today).claimed.has(6) and game.hud.labels.status.text=="Door 6 opened · +12 Winter Coins!","The real door action saves one reward and shows its English numbered confirmation")
	var decoration:=find_button(panel,"Wooden stars")
	check(decoration!=null and decoration.text.ends_with("Winter Coins"),"Decoration prices use the selected language")
	decoration.pressed.emit()
	check(panel.archive.overview(panel.today).owned.has("star") and game.hud.labels.status.text=="Decoration permanently unlocked: Wooden stars","Buying decoration translates both the action and the item name")
	await capture("winter25-calendar-en")
	panel.today={"year":2026,"month":12,"day":31,"hour":23,"minute":54,"second":59}
	panel._process(0.1)
	check(find_button(panel,"Celebrate New Year").disabled,"The real celebration button stays locked before 23:55")
	panel.today.minute=55
	panel.today.second=0
	panel._process(0.1)
	check(not find_button(panel,"Celebrate New Year").disabled,"The open celebration button unlocks at 23:55 using the shared rule")
	panel.today={"year":2027,"month":1,"day":1,"hour":0,"minute":0,"second":0}
	panel._process(0.1)
	find_button(panel,"Celebrate New Year").pressed.emit()
	check(panel.archive.overview(panel.today).new_year_done and find_button(panel,"Celebrate New Year").disabled,"The real New Year action archives the correct winter and disables duplicate claims")
	panel.today.hour=1
	panel._process(0.1)
	check(find_button(panel,"Celebrate New Year").disabled,"A calendar kept open past 01:00 no longer offers the expired celebration")
	panel.today.day=2
	panel._process(0.1)
	check(not panel.visible and game.paused,"The calendar closes after the season and preserves a previously paused game")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(panel.archive.path))
	game.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
