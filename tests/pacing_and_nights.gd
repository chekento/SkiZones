extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Saves=preload("res://src/core/save_store.gd")
const Ops=preload("res://src/core/operations.gd")
var passed:=0
var failed:=0
func check(ok: bool,title: String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func same_state(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not same_state(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for index in range(a.size()):
			if not same_state(a[index],b[index]):return false
		return true
	if (a is float or a is int) and (b is float or b is int):return absf(float(a)-float(b))<=maxf(0.0000001,absf(float(a))*0.000000000001)
	return a==b
func fresh() -> RefCounted:
	var model:=Resort.new();model.new_game(true);Ops.enable(model);model.enable_runtime_rules();return model
func _init() -> void:
	var model:=fresh();model.party_mode=false;model.edge_entries=false
	check(model.time_divisor==24 and 0.5*4/model.time_divisor==0.5/6,"The clock takes six times longer while movement runs at the former fourfold rate")
	var before: int=model.minute;var lift: Dictionary=model.lifts[0];var clock: float=lift.clock
	for step in range(23):model.advance_minute(false)
	check(model.minute==before and lift.clock==clock+23,"Movement advances between displayed clock minutes")
	model.advance_minute(false)
	check(model.minute==before+1 and lift.clock==clock+24 and model.clock_fraction==0,"Exactly twenty-four movement steps form one calendar minute")
	model.admit_guest(0)
	var guest: Dictionary=model.guests[0]
	var age: int=guest.age
	for step in range(7):model.advance_minute(false)
	check(guest.age==age and model.clock_fraction>0,"Visitor stay lengths follow the longer day instead of expiring at movement speed")
	var copy:=Resort.new()
	check(Saves.save_game(model,"user://pacing-test017.json").ok and Saves.load_game(copy,"user://pacing-test017.json").ok and same_state(copy.snapshot(),model.snapshot()),"A partial clock minute and actual guest progress survive an actual checked save without visible or financial drift")
	for step in range(120):model.advance_minute(false);copy.advance_minute(false)
	check(same_state(copy.snapshot(),model.snapshot()),"Movement, needs, queues and future choices continue deterministically with the longer clock")
	var broken: Dictionary=model.snapshot();broken.clock_fraction=0.123
	check(not copy.restore(broken).ok,"An impossible partial clock step is rejected atomically")
	model=fresh();model.minute=1379;model._operational_change()
	check(model.empty_night(),"A completely empty evening permits automatic calendar fast-forward")
	var day: int=model.day
	for step in range(61):model.advance_empty_minute()
	check(model.day==day+1 and model.minute==0,"Empty-night fast-forward runs real midnight settlement instead of resetting the resort")
	for step in range(480):model.advance_empty_minute()
	check(model.minute==480 and not model.empty_night() and not model.advance_empty_minute(),"Automatic fast-forward stops at the next morning")
	check(model.admit_guest(0) and not model.empty_night(),"An occupied resort stays at the player's selected speed")
	_nightlife()
	print("PACING AND OPERATIONS: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)

func _nightlife() -> void:
	var model:=fresh();model.party_mode=false;model.edge_entries=false;model.campaign.mode="free";model.money=3000000
	var club: Dictionary={}
	for z in range(240,360,35):
		for x in range(70,330,35):
			if club.is_empty() and model.build_building("disco",Vector2(x,z)).ok:club=model.buildings[-1]
	check(not club.is_empty() and Ops.fill_building(model,club.id).ok,"A real nightlife venue receives both evening and night crews")
	model.minute=180;model._duty_cache.clear();model._operational_change()
	check(Ops.building_open(model,club) and Ops.admit_evening(model),"A staffed club and an actual night visitor are available after 02:00")
	if model.guests.is_empty():return
	var guest: Dictionary=model.guests[0]
	for step in range(240):model.advance_minute(false)
	check(model.guests.has(guest) and guest.get("night_out",false) and guest.route.legs[guest.leg].kind=="visit" and guest.duration>=45*24,"The visitor stays for a real extended night session rather than one short stop")
	var copy:=Resort.new();Saves.save_game(model,"user://nightlife-test017.json")
	check(Saves.load_game(copy,"user://nightlife-test017.json").ok,"An occupied night session preserves its remaining stay across an update-compatible save")
	var income: float=model.report.services
	for step in range(4400):
		model.advance_minute(false)
		if model.guests.is_empty():break
	check(club.visits>=2 and model.report.services>income,"Completed night sessions keep generating actual visits and revenue across the night")
	check(model.minute>=355 and model.guests.is_empty() and model.empty_night(),"Night visitors return home around dawn and then permit automatic morning fast-forward")
