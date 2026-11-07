extends SceneTree
const Saves=preload("res://src/core/save_store.gd")
const Resort=preload("res://src/core/resort.gd")
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
	check(not first.is_empty() and first[0].text=="Diese Karriere fortsetzen","Populated slots make continuation the primary action")
	var populated_card:Node=game.hud.career_slots.cards.get_child(0)
	var submenu:PanelContainer=populated_card.find_child("save_manager_submenu",true,false) as PanelContainer
	var toggle:Button=populated_card.find_child("toggle_save_manager",true,false) as Button
	check(submenu!=null and toggle!=null and not submenu.visible,"Save management is collapsed by default, not scattered across the slot card")
	check(game.hud.career_slots.get_parent()==game.hud and game.hud.career_slots.get_global_rect().size==root.get_visible_rect().size,"Save selector fills viewport instead of inheriting padded HUD safe area")
	if toggle!=null:toggle.pressed.emit()
	check(submenu!=null and submenu.visible,"Explicit Manage action reveals recovery, copy and archive controls")
	check(populated_card.find_child("check_save_038",true,false)!=null and populated_card.find_child("rescue_save_038",true,false)!=null and populated_card.find_child("copy_save_038",true,false)!=null and populated_card.find_child("archive_save_038",true,false)!=null,"Populated careers expose diagnostics, backup rescue, copy and archive in addition to continuation")
	first[0].pressed.emit()
	for frame in range(120):
		await process_frame
		if not game.hud.loading.visible:break
	check(Saves.active_slot==1 and game.model.money==123451 and game.model.day==1,"The real Continue button restores the selected career rather than the last open one")
	game.paused=true;game.save_game();game.show_career_slots()
	populated_card=game.hud.career_slots.cards.get_child(0)
	var source_path:String=Saves.path_for_map("sonnenhang",1)
	var source_hash:String=FileAccess.get_sha256(source_path)
	(populated_card.find_child("check_save_038",true,false) as Button).pressed.emit()
	var diagnostic:Label=populated_card.find_child("save_diagnostics",true,false) as Label
	check(diagnostic.text.contains("ladbar") and FileAccess.get_sha256(source_path)==source_hash,"The actual diagnostic action confirms loadability while preserving the original bytes")
	var target_path:String=Saves.path_for_map("sonnenhang",2)
	var target_hash:String=FileAccess.get_sha256(target_path)
	var copy_target:OptionButton=populated_card.find_child("copy_target",true,false) as OptionButton
	copy_target.select(copy_target.get_item_index(2))
	(populated_card.find_child("copy_save_038",true,false) as Button).pressed.emit()
	check(FileAccess.get_sha256(source_path)==source_hash and FileAccess.get_sha256(target_path)==target_hash,"Copying onto an occupied career through the real UI preserves both saved originals")
	(populated_card.find_child("archive_save_038",true,false) as Button).pressed.emit()
	check(game.hud.career_slots.archive_confirmation.visible and FileAccess.get_sha256(source_path)==source_hash,"Archive asks for confirmation before changing the actual saved career")
	game.hud.career_slots.archive_confirmation.confirmed.emit()
	game.hud.career_slots.archive_confirmation.hide()
	check(FileAccess.get_sha256(source_path)==source_hash and Saves.summary(1).occupied and game.model.money==123451,"An active resort cannot be archived then silently auto-saved back into its slot")
	var restart:Button=null
	for action in buttons(game.hud.career_slots.cards.get_child(0)):
		if action.text=="Neue Karriere auf diesem Platz":restart=action
	check(restart!=null,"Restart remains a separate explicit action beside save management")
	if restart==null:quit(1);return
	restart.pressed.emit();await process_frame
	check(game.hud.career_slots.confirmation.visible and game.model.money==123451,"Restarting an occupied slot first explains its backup and preserves the current resort")
	game.hud.career_slots.confirmation.hide();game.hud.career_slots.hide()
	game.app_session.save(game);game.queue_free();await process_frame;await process_frame
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame;game.set_process(false)
	check(game.app_session.restore(game) and Saves.active_slot==1 and game.model.money==123451,"A cold application restoration returns to the exact saved career slot")
	game.hud.career_slots.open();root.size=Vector2i(960,540)
	for frame in range(4):await process_frame
	check(root.get_visible_rect().encloses(game.hud.career_slots.get_global_rect()),"All career controls remain within a small landscape screen")
	# Regression for a real player having two separately saved mountains in
	# the SAME career. The additional mountain must be selectable, not hidden
	# behind the old single last-map index.
	Saves.active_slot=1
	var second_resort:=Resort.new()
	second_resort.new_game(true,20261027,"fichtenkamm")
	second_resort.money=654321
	check(Saves.save_game(second_resort,Saves.path_for_map("fichtenkamm",1)).ok,"A second mountain is saved in the same career slot")
	# The featured card may be either resort depending on filesystem mtime;
	# the OTHER resort must always be a separately clickable save.
	var featured: String=str(Saves.summary(1).map)
	var target: String="sonnenhang" if featured=="fichtenkamm" else "fichtenkamm"
	var target_name: String="Velvet Peaks" if target=="sonnenhang" else "Whisperpine Lodge"
	var expected_money: float=123451 if target=="sonnenhang" else 654321
	game.hud.career_slots.open();await process_frame
	var second_button: Button=null
	for action in buttons(game.hud.career_slots.cards.get_child(0)):
		if action.text.contains(target_name):second_button=action
	check(second_button!=null,"Career card offers the other saved mountain as its own load action")
	if second_button!=null:
		second_button.pressed.emit()
		for frame in range(240):
			await process_frame
			if not game.hud.loading.visible and game.model.map_id==target:break
		check(game.has_game and game.model.map_id==target and game.model.money==expected_money,"Additional mountain loads from actual career UI without replacing the first")
	game.queue_free();await process_frame;await process_frame
	print("CAREER SLOT SCENE: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
