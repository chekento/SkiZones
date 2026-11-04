extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Rhythm = preload("res://src/core/day_rhythm.gd")
const Features = preload("res://src/core/piste_features.gd")
const Fleet = preload("res://src/core/lift_fleet.gd")
const Tow = preload("res://src/world/tow_rope.gd")
const Art = preload("res://src/world/alpine_art.gd")
const Preferences = preload("res://src/core/preferences.gd")
var passed := 0
var failed := 0

func check(value: bool, message: String) -> void:
	if value: passed+=1; print("PASS ",message)
	else: failed+=1; push_error("FAIL "+message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	check(Rhythm.playback(600)>1.5 and Rhythm.playback(1100)==1.0 and Rhythm.playback(1319)==1.0,"Ski days are shorter while the entire 17–22h evening retains its old pacing")
	check(Rhythm.playback(600,"compact")>Rhythm.playback(600) and Rhythm.playback(600,"cozy")<Rhythm.playback(600),"Three day-length preferences have distinct rates")
	var model := Resort.new()
	model.new_game(true)
	model.Ops.enable(model)
	model.enable_runtime_rules()
	model.campaign.mode="free"
	model.money=3000000
	model.party_mode=false
	model.edge_entries=false
	var piste: Dictionary=model.pistes[0]
	var id: int=piste.id
	var original_points: Array=piste.points.duplicate(true)
	var money: float=model.money
	check(Features.install(model,id,"ramp",0.35,0).ok and model.money==money-850,"A real modular ramp charges the construction ledger")
	check(Features.install(model,id,"rail",0.58,0).ok and Features.install(model,id,"roller",0.80,0).ok,"Rail and roller can be independently installed on two other sections")
	check(piste.points==original_points and Features.valid(piste),"Modules preserve the existing route and valid save data")
	money=model.money
	check(not Features.install(model,id,"ramp",0.35,0).ok and not Features.install(model,id,"rail",0.01,0).ok and not Features.install(model,id,"rail",0.5,100).ok and model.money==money,"Overlapping, terminal and out-of-width placements are rejected before charging")
	check(Features.install(model,id,"ramp",0.37,0,0).ok and model.money==money-120 and piste.features.size()==3,"Moving a selected module charges only the relocation fee")
	check(Features.height_offset(piste,0.37,0,2)>0.5 and Features.height_offset(piste,0.37,0,0)==0,"Only eligible skiers follow a feature's raised profile")
	check(Features.height_offset(piste,0.37+7.0/piste.length,0,2)>0.2 and Features.height_offset(piste,0.37+11.0/piste.length,0,2)==0,"Small ramps lift a skilled skier into a short flight and return them to the snow")
	check(absf(Features.safe_lateral(piste,0.37,0,0))>=3.5,"Novices get a clear bypass instead of skiing through the ramp")
	var snapshot := model.snapshot()
	var restored := Resort.new()
	check(restored.restore(snapshot).ok and restored.pistes[0].features==piste.features,"All feature positions survive an update-compatible checked save")
	var damaged: Dictionary=snapshot.duplicate(true)
	damaged.pistes[0].features[0].fraction=NAN
	check(not restored.restore(damaged).ok and restored.pistes[0].features==piste.features,"Non-finite imported feature coordinates are rejected atomically")
	damaged=snapshot.duplicate(true)
	damaged.pistes[0].features[0].kind="unknown"
	check(not restored.restore(damaged).ok,"Unknown feature kinds cannot enter a save")
	check(Features.remove(model,id,1).ok and piste.features.size()==2,"A single section's feature can be removed independently")
	var lift: Dictionary=model.lifts[0].duplicate(true)
	lift.kind="drag"
	lift.length=300
	var pose := {"transform":Transform3D(Fleet.basis(lift),Vector3(210,40,0)),"grip":Vector3(210,48,0),"fraction":0.5,"outbound":true,"carrier":3}
	var empty := Tow.frame(model.terrain,pose,false,30)
	var loaded := Tow.frame(model.terrain,pose,true,30)
	var loaded_at: Vector3=loaded.transform.origin
	check(empty.transform.origin.distance_to(pose.grip)<3 and absf(loaded_at.y-model.terrain.height(Vector2(loaded_at.x,loaded_at.z))-1.15)<0.001,"Empty tows retract at the cable; loaded tows reach the actual skier's waist")
	check(Vector2(loaded_at.x,loaded_at.z).distance_to(Vector2(pose.grip.x,pose.grip.z))>1 and loaded.points.size()==3,"Loaded ropes angle back while unloaded ropes can sag in two segments")
	pose.outbound=false
	check(not Tow.frame(model.terrain,pose,true,30).loaded,"A returning empty carrier cannot display a loaded tow")
	var types := {}
	for species in range(3): types[str(Art.new().tree_variant("alpine",species).get_aabb())]=true
	check(types.size()==3,"Evergreen, larch and bare alpine trees have different silhouettes")
	for kind in range(6): check(Art.new().landscape_detail(kind).get_surface_count()==1,"Landscape detail remains in a single batched surface: "+str(kind))
	var prefs := Preferences.new()
	prefs.path="user://landscape023-preferences.cfg"
	prefs.day_length="compact"
	prefs.wildlife=false
	prefs.contour_lines=false
	prefs.night_forward=false
	prefs.save_to()
	var copy := Preferences.new()
	copy.path=prefs.path
	copy.load_from()
	check(copy.day_length=="compact" and not copy.wildlife and not copy.contour_lines and not copy.night_forward,"Day length, contours, wildlife and night comfort preferences persist together")
	_night(model)
	print("RESULT: %d passed; %d failed"%[passed,failed])
	quit(1 if failed else 0)

func _night(model: RefCounted) -> void:
	model.guests.clear()
	var cabin: Dictionary={}
	for z in range(200,380,34):
		for x in range(100,380,34):
			if model.build_building("cabin",Vector2(x,z)).ok: cabin=model.buildings[-1]; break
		if not cabin.is_empty(): break
	check(not cabin.is_empty() and model.admit_guest(0,"blue"),"A real connected overnight property and tourist are available")
	if cabin.is_empty() or model.guests.is_empty(): return
	var guest: Dictionary=model.guests[0]
	var daytime_route: Dictionary=guest.route.duplicate(true)
	guest.lodging_id=cabin.id
	guest.stay=8000
	model.minute=1300
	model._operational_change()
	var route: Dictionary=model.Lodging.night_route(model,guest,"base")
	check(not route.is_empty(),"The overnight tourist has a real walking route into the cabin")
	if route.is_empty(): return
	guest.route=route
	for index in range(route.legs.size()):
		if route.legs[index].kind=="visit": guest.leg=index; break
	guest.hotel_night=true
	model.Lodging.start_sleep(model,guest)
	check(not model.empty_night(),"Sleeping guests do not skip the relaxed evening before 22h")
	model.minute=1320
	check(model.empty_night(),"A sleeping resident no longer prevents quiet-night forward")
	var day: int=model.day
	for tick in range(5000):
		if model.day>day: break
		if not model.advance_empty_minute(): model.advance_minute(false)
	check(model.day==day+1 and model.minute==0 and model.guests.has(guest),"Fast-forward settles midnight and keeps the actual resident")
	guest.phase="moving"
	guest.leg=0
	guest.erase("hotel_sleep_until")
	model._start_leg(guest)
	check(model.empty_night() and model.advance_empty_minute() and model.guests.has(guest),"A real safe cabin-bound pedestrian can keep walking during night forward")
	# A foot leg alone is insufficient: every remaining leg must be safe.
	# Reuse the visitor's actual daytime ski itinerary to retain the original
	# safety check for an outdoor walker with a lift/descent still ahead.
	guest.route=daytime_route
	guest.leg=0
	model._start_leg(guest)
	check(not model.empty_night() and not model.advance_empty_minute(),"A real outdoor itinerary with a lift or piste ahead stops night forward")
	for index in range(daytime_route.legs.size()):
		if daytime_route.legs[index].kind=="ski":
			guest.leg=index
			model._start_leg(guest)
			break
	check(not model.empty_night(),"An actual descent never receives pedestrian night acceleration")
	guest.phase="queue"
	check(not model.empty_night(),"A real lift queue still prevents automatic night skipping")
	guest.phase="waiting"
	guest.waiting_reason="hotel"
	guest.hotel_sleep_until=model.Ops.clock(model)+60
	guest.incident=9
	check(not model.empty_night(),"An unresolved incident prevents automatic night skipping")
