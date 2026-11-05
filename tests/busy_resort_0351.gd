extends SceneTree
## Actual admission, lift dispatch, ski traffic and return paths under load.
const Resort = preload("res://src/core/resort.gd")
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("PASS ",title)
	else: failed+=1; push_error("FAIL "+title)
func run() -> void:
	var model := Resort.new()
	model.new_game(true,20261105)
	model.weather_index=0
	model.party_mode=false
	model.edge_entries=false
	var admitted := 0
	for i in range(240):
		if model.admit_guest(i%3): admitted+=1
	check(admitted==240 and model.guests.size()==240,"All 240 crowd members enter through actual admission and routing")
	var first: Dictionary=model.guests[0] if not model.guests.is_empty() else {}
	var saw_skier := false
	var actual_skiers: Dictionary={}
	var used_lanes: Dictionary={}
	for tick in range(1400):
		model.advance_minute(false)
		for guest in model.guests:
			if guest.phase=="moving" and int(guest.leg)<guest.route.legs.size() and guest.route.legs[guest.leg].kind=="ski":
				saw_skier=true
				actual_skiers[int(guest.id)]=guest
				if guest.has("traffic_lane"): used_lanes[int(guest.traffic_lane)]=true
		if model.guests.is_empty(): break
	check(saw_skier and used_lanes.size()>=3,"Real dispatched skiers occupy several rendered snow lanes")
	check(not actual_skiers.is_empty() and actual_skiers.values().all(func(g):return int(g.runs)>0),"Every guest who actually enters a descent finishes it; queues respect real lift capacity")
	check(model.guests.is_empty(),"The original 240-person crowd eventually returns home without a frozen tail")
	check(model.pistes[0].rides>0 and model.lifts[0].boarded>0,"The pre-existing piste and pre-existing lift are both actually used")
	check(first.get("phase","")=="leaving","The first real visitor also finishes their itinerary")
	print("CROWD_DIAG rides=",model.total_rides," remaining=",model.guests.size()," lanes=",used_lanes.keys())
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
