extends SceneTree
const Profile=preload("res://src/core/guest_profile.gd")
const Catalog=preload("res://src/core/update_catalog.gd")
var game: Node
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok: bool,title: String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func texts(node: Node) -> String:
	var result: String=node.text+"\n" if node is Label or node is Button or node is RichTextLabel else ""
	for child in node.get_children():result+=texts(child)
	return result
func capture(name: String) -> void:
	for frame in range(4):await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/"+name+".png")
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.apply_language("de");game.start_game(true);game.paused=true;game.view.set_process(false)
	check(game.model.admit_guest(0,"family",5),"The current game admits a real family through its outside entrance")
	for guest in game.model.guests:
		guest.needs={"hunger":0.0,"warmth":95.0,"energy":95.0,"joy":95.0,"rental":false,"lesson":false}
	for step in range(320):game.model.advance_minute(false)
	game.view.rebuild();game.view.focus=Vector2(185,200);game.view.zoom=190;game.view._update_camera();game.view._process(0)
	check(game.view._guest_positions.size()==5 and game.view._family_positions.is_empty(),"The scene draws five independently simulated people instead of four copies of one root")
	var one: Dictionary=game.model.guests[0];var other: Dictionary=game.model.guests[1]
	check(game.view._guest_positions[one.id].distance_to(game.view._guest_positions[other.id])>10,"Separate family adults are visibly at different actual positions")
	game.hud.show_guest(one.id);game.hud.refresh()
	check(game.hud.inspector_title.text==one.person_name and game.hud.inspector_text.text.contains("Nächster Treffpunkt"),"Selecting one actor opens their own named profile and their shared appointment")
	await capture("individual-families-0170")
	check(game.view._pedestrian_snapshot.links.any(func(link):return link.get("public_entry",false)),"The public entrance is drawn from the same path data used by arriving people")
	game.updater.candidate={"version":"0.18.0","release":Catalog.RELEASES+"/tag/v0.18.0"}
	game.updater._set_status("available",game.L.text("Version %s ist verfügbar. Deine vier Karrieren und die anderen Spielstände bleiben erhalten.")%"0.18.0")
	game.hud.update_dialog.open();await process_frame
	check(game.hud.update_dialog.visible and game.hud.blocks_map(Vector2(700,400)) and not game.simulation_running(),"The update panel pauses the resort and blocks map gestures")
	check(game.hud.update_dialog.action.visible and game.hud.update_dialog.action.text=="Update herunterladen","A verified available version exposes one clear download action")
	var old_tool: String=game.tool;var key:=InputEventKey.new();key.pressed=true;key.keycode=KEY_B;game._input(key)
	check(game.tool==old_tool,"Construction shortcuts cannot operate beneath the update panel")
	await capture("github-updates-0170")
	key.keycode=KEY_ESCAPE;game._input(key)
	check(not game.hud.update_dialog.visible,"Escape returns from the updater to the resort")
	game.apply_language("en");game.hud.update_dialog.open();await process_frame
	check(texts(game.hud.update_dialog).contains("UPDATE SKIZONES") and texts(game.hud.update_dialog).contains("Download update"),"The career update controls have a complete English interface")
	root.size=Vector2i(960,540)
	for frame in range(4):await process_frame
	check(root.get_visible_rect().encloses(game.hud.update_dialog.get_global_rect()),"The update panel remains contained and scrollable on small landscape screens")
	game.queue_free();await process_frame;await process_frame
	print("INDIVIDUAL PARTIES SCENE: %d passed; %d failed"%[passed,failed]);quit(1 if failed else 0)
