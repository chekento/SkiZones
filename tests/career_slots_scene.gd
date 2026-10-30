extends SceneTree
const Saves=preload("res://src/core/save_store.gd")
var game: Node
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok: bool,title: String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func buttons(node: Node) -> Array:
	var result: Array=[]
	if node is Button:result.append(node)
	for child in node.get_children():result.append_array(buttons(child))
	return result
func capture(name: String) -> void:
	for frame in range(4):await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/"+name+".png")
func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test"):quit(1);return
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.apply_language("de");game.preferences.path="user://career-slots-ui.cfg"
	for slot in range(1,5):
		game.show_career_slots();await process_frame
		var card: Node=game.hud.career_slots.cards.get_child(slot-1)
		var actions:=buttons(card)
		check(actions.size()==1 and actions[0].text=="Neue Karriere starten","Empty career "+str(slot)+" has one clear start action")
		actions[0].pressed.emit();await process_frame
		game.paused=true;game.model.money=123450+slot;game.model.day=slot
		check(Saves.active_slot==slot and game.has_game and game.model.campaign.mode=="career" and game.save_game(),"The actual career card starts and saves independent slot "+str(slot))
	game.show_career_slots();await process_frame
	check(game.hud.career_slots.cards.get_child_count()==4 and game.hud.career_slots.cards.columns==2,"All four populated careers appear in a compact two-column grid")
	check(game.hud.blocks_map(Vector2(700,400)) and not game.simulation_running(),"The career selector blocks map input and pauses the resort")
	check(root.get_visible_rect().encloses(game.hud.career_slots.get_global_rect()),"The complete career selector fits the landscape viewport")
	await capture("career-slots-0170")
	var first: Array=buttons(game.hud.career_slots.cards.get_child(0))
	check(first.size()==2 and first[0].text=="Diese Karriere fortsetzen","Populated slots make continuation the primary action")
	first[0].pressed.emit()
	for frame in range(120):
		await process_frame
		if not game.hud.loading.visible:break
	check(Saves.active_slot==1 and game.model.money==123451 and game.model.day==1,"The real Continue button restores the selected career rather than the last open one")
	game.paused=true;game.save_game();game.show_career_slots()
	buttons(game.hud.career_slots.cards.get_child(0))[1].pressed.emit();await process_frame
	check(game.hud.career_slots.confirmation.visible and game.model.money==123451,"Restarting an occupied slot first explains its backup and preserves the current resort")
	game.hud.career_slots.confirmation.hide();game.hud.career_slots.hide()
	game.app_session.save(game);game.queue_free();await process_frame;await process_frame
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
	check(game.app_session.restore(game) and Saves.active_slot==1 and game.model.money==123451,"A cold application restoration returns to the exact saved career slot")
	game.hud.career_slots.open();root.size=Vector2i(960,540)
	for frame in range(4):await process_frame
	check(root.get_visible_rect().encloses(game.hud.career_slots.get_global_rect()),"All career controls remain within a small landscape screen")
	game.queue_free();await process_frame;await process_frame
	print("CAREER SLOT SCENE: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
