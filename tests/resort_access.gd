extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Maps=preload("res://src/core/maps.gd")
const Terrain=preload("res://src/core/terrain.gd")
const Foot=preload("res://src/core/foot_network.gd")
const Access=preload("res://src/core/resort_access.gd")
const Ops=preload("res://src/core/operations.gd")
const Saves=preload("res://src/core/save_store.gd")
var passed:=0
var failed:=0
func check(ok: bool,title: String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func _init() -> void:
	for map_id in Maps.MAPS:
		var model:=Resort.new();model.new_game(true,20261027,map_id);model.enable_runtime_rules()
		check(Access.valid(model,model.portal_path),"A public access road leads outside the map in "+map_id)
		check(Foot.gentle(model.terrain,model.portal_path),"The public approach follows a walkable gradient in "+map_id)
		check(Foot.clear_walk(model.portal_path,model.buildings,model.lifts),"The actual entrance road clears buildings and lift machinery in "+map_id)
	var model:=Resort.new();model.new_game(true);Ops.enable(model);model.enable_runtime_rules();model.party_mode=false
	check(model.admit_guest(0),"A new guest can enter through the edge access road")
	var guest: Dictionary=model.guests[0];var gate:=Terrain.unpack(model.portal_path[-1])
	check(Vector2(model.guest_position(guest).x,model.guest_position(guest).z).distance_to(gate)<0.01 and not model.terrain.contains(gate),"The guest actually appears outside the map rather than in the village")
	check(guest.route.origin==model.portal_path[-1] and guest.route.legs[0].to=="base","A real continuous walking leg connects the outside entrance to the resort network")
	for i in range(5):model.advance_minute(false)
	var copy:=Resort.new()
	check(Saves.save_game(model,"user://edge017.json").ok and Saves.load_game(copy,"user://edge017.json").ok,"An arrival in progress and the public road survive a checked save")
	var previous: Vector3=model.guest_position(guest)
	model.advance_minute(false)
	check(previous.distance_to(model.guest_position(guest))>0 and previous.distance_to(model.guest_position(guest))<12,"The arriving guest walks continuously toward the village")
	# Start a departure at its real valley node; the road must be traversed.
	guest.route={"target":0,"origin":Terrain.pack(Terrain.BASE),"legs":[]}
	Access.depart(model,guest)
	check(guest.phase=="moving" and guest.get("portal_departing",false) and guest.route.legs[0].to=="outside","Leaving starts a physical walk to the edge instead of deleting the guest in the village")
	for i in range(1000):
		model.advance_minute(false)
		if guest.phase=="leaving":break
	check(guest.phase=="leaving" and Vector2(model.guest_position(guest).x,model.guest_position(guest).z).distance_to(gate)<0.01,"Departure reaches the outside edge before removing the guest")
	model=Resort.new();model.new_game(false);model.enable_runtime_rules();model.money=3000000
	var bottom:=Vector2(-210,150);var top:=Vector2(-270,-200)
	var preview:=model.preview_lift("chair2",bottom,top)
	check(preview.ok and not preview.get("foot_connection",{}).is_empty() and preview.message.contains("Fußweg zur Talstation"),"The lift preview quotes its actual access path and cost")
	var before: float=model.money
	check(model.build_lift("chair2",bottom,top).ok and model.walk_areas.size()==1 and model.money==before-preview.cost,"Confirming builds the lift and quoted path together with one exact charge")
	var graph: Dictionary=model.pedestrian_graph()
	check(model._shortest(graph,"base","l%db"%int(model.lifts[0].id)).ok,"The new lift boarding point is truly reachable through the walking graph")
	check(Foot.valid_walk(model.pedestrian_layout(),model.walk_areas[0].points,model.buildings),"The visible automatic access path is also a valid pedestrian surface")
	check(Saves.save_game(model,"user://lift-access017.json").ok and Saves.load_game(copy,"user://lift-access017.json").ok,"The automatic access path and its lift survive save validation")
	var lift: Dictionary=model.lifts[0]
	var moved: Array=[Terrain.pack(bottom+Vector2(-90,0)),Terrain.pack(top+Vector2(-90,0))]
	var change:=model.preview_change(lift.id,moved)
	check(change.ok and not change.get("foot_connection",{}).is_empty(),"Moving a lift previews an actual replacement access connection")
	var funds: float=model.money
	var changed:=model.change_asset(lift.id,moved,"Moved lift","",0,20)
	check(changed.ok and model.walk_areas.size()==2 and model.money==funds-change.cost and model._shortest(model.pedestrian_graph(),"base","l%db"%int(lift.id)).ok,"The confirmed lift move builds the quoted footpath and keeps its boarding point connected")
	check(Saves.save_game(model,"user://moved-lift017.json").ok and Saves.load_game(copy,"user://moved-lift017.json").ok,"A moved lift and both actual paths remain a valid saved resort")
	check(model.build_building("shelter",Vector2(280,300)).ok and not model.preview_change(model.buildings[-1].id,[[185,390]]).ok,"Moving a building cannot obstruct the public edge access road")
	check(not model.preview_lift("chair2",Vector2(185,400),Vector2(240,-300)).ok,"A proposed lift cannot block the public entrance with its machinery")
	var state: Dictionary=model.snapshot();state.portal_path[0]=[999999,999999]
	check(not copy.restore(state).ok,"An invalid public access path is rejected atomically")
	print("RESORT ACCESS OPERATIONS: %d passed; %d failed"%[passed,failed]);quit(1 if failed else 0)
