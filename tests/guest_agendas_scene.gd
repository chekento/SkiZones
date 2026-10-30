extends SceneTree
const Needs=preload("res://src/core/guest_needs.gd")
var game: Node
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok: bool,title: String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func capture(name: String) -> void:
	game.hud.refresh()
	for i in range(4):await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/"+name+".png")
func texts(node: Node) -> String:
	var value: String=str(node.text)+"\n" if node is Label or node is RichTextLabel or node is Button else ""
	for child in node.get_children():value+=texts(child)
	return value
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.apply_language("de");game.start_game(false);game.paused=true;game.set_process(false);game.view.set_process(false)
	game.preferences.path="user://guest-agendas-scene.cfg"
	game.model.money=3000000
	check(game.model.build_lift("chair2",Vector2(200,205),Vector2(245,-130)).ok and game.model.build_piste([[245,-130],[275,-30],[255,95],[200,205]]).ok,"The visual test uses a real two-seat lift and connected piste")
	check(game.Ops.fill_stations(game.model,game.model.lifts[0].id).ok,"The visible family uses a lift with actual employees at its stations")
	check(game.model.admit_guest(0,"family",5),"Admit a visible family with five actual members")
	var guest: Dictionary=game.model.guests[0]
	for member in guest.family:member.needs={"hunger":0.0,"warmth":90.0,"energy":90.0,"joy":90.0,"rental":false,"lesson":false}
	Needs.aggregate_family(guest)
	for index in range(guest.route.legs.size()):
		if guest.route.legs[index].kind=="ski":guest.leg=index;game.model._start_leg(guest);guest.elapsed=guest.duration*0.5;break
	var center: Vector3=game.model.guest_position(guest)
	game.view.rebuild();game.view.focus=Vector2(center.x,center.z);game.view.zoom=55;game.view.set_camera_mode(0);game.view.simulation_fraction=0
	game.view._process(0)
	check(game.view._family_positions.get(guest.id,[]).size()==4,"The renderer draws four individual relatives beside the selected parent")
	var near:=true
	for position in game.view._family_positions.get(guest.id,[]):near=near and position.distance_to(game.view._guest_positions[guest.id])<8
	check(near,"The family descends together in a compact visible group")
	var separate:=true
	var relatives: Array=game.view._family_positions[guest.id]
	for first in range(relatives.size()):
		for second in range(first):separate=separate and relatives[first].distance_to(relatives[second])>2
	check(separate,"Individual relatives occupy distinct rows instead of overlapping every second child")
	var child: Vector3=game.view._family_positions[guest.id][0]
	check(game.view.pick_guest(game.view.camera.unproject_position(child))==guest.id,"Tapping a visible child opens the shared family's profile")
	game.hud.set_map_focus(true)
	await capture("family-group-0160")
	game.hud.show_guest(guest.id);game.hud.refresh()
	check(game.hud.inspector_text.text.contains("FAMILIE · 5") and game.hud.inspector_text.text.contains("WÜNSCHE & URLAUBSZIELE") and game.hud.inspector_text.text.contains(guest.family[0].name),"The real profile explains wishes and lists named family members and their individual needs")
	check(texts(game.hud.inspector_panel).contains("Gäste & Wünsche"),"The selected guest provides a direct route to audience management")
	await capture("guest-wishes-0160")
	game.paused=false;game.hud.audience.open();await process_frame
	check(game.hud.audience.visible and game.hud.blocks_map(Vector2(750,400)) and not game.simulation_running(),"Audience management pauses the game and blocks map gestures")
	check(game.hud.audience.cards.get_child_count()==7 and game.hud.audience.target_choice.item_count==7,"All six audience cards and all transparent advertising choices appear")
	check(root.get_visible_rect().encloses(game.hud.audience.get_global_rect()),"The audience panel fits the actual landscape viewport")
	var tool: String=game.tool
	var key:=InputEventKey.new();key.pressed=true;key.keycode=KEY_P;game._input(key)
	check(game.tool==tool,"Construction shortcuts cannot operate beneath the audience modal")
	var cost: float=game.model.operating_costs(false)
	game.hud.audience.target_choice.select(6);game.hud.audience.target_choice.item_selected.emit(6)
	check(game.model.audience.target=="family" and game.model.operating_costs(false)==cost+250,"The actual advertising control selects families and applies its displayed daily price")
	await capture("audience-0160")
	key.keycode=KEY_ESCAPE;game._input(key)
	check(not game.hud.audience.visible and not game.hud.menu.visible,"Escape returns directly from audience management to the mountain")
	game.apply_language("en");game.hud.audience.open();await process_frame
	var content:=texts(game.hud.audience)
	check(content.contains("GUESTS & WISHES") and content.contains("Families together") and content.contains("Run and lift collectors") and not content.contains("Rückmeldungen"),"The audience and all motives have complete English text")
	await capture("en-audience-0160")
	root.size=Vector2i(960,540)
	for i in range(4):await process_frame
	check(root.get_visible_rect().encloses(game.hud.audience.get_global_rect()) and game.hud.audience.cards.get_parent().size.y>70,"On a small landscape screen the audience list remains scrollable inside the viewport")
	game.hud.audience.hide();game.view.focus=Vector2(245,-130);game.view.zoom=140
	for index in range(guest.route.legs.size()):
		if guest.route.legs[index].kind=="lift":guest.leg=index;game.model._start_leg(guest);break
	var lift: Dictionary=game.model.lifts[0]
	lift.clock=game.model.fleet_layout(lift).interval;game.model._board_direction(lift,false);game.view._process(0)
	var body: Vector3=game.view._family_positions[guest.id][0]
	check(body.distance_to(game.model.family_pose(guest,0).position)<0.01,"The rendered child uses its actual assigned lift seat")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.preferences.path))
	game.queue_free();await process_frame;await process_frame
	print("GUEST AGENDA SCENE: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
