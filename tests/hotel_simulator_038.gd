extends SceneTree
## Hotel Simulator, restroom manager and research tree compatibility.
const Resort=preload("res://src/core/resort.gd")
const Simulator=preload("res://src/core/hotel_simulator.gd")
const Rooms=preload("res://src/core/hotel_rooms.gd")
const Progression=preload("res://src/core/progression.gd")
var passed:=0
var failed:=0
func _init() -> void: call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func run() -> void:
	var model:=Resort.new()
	model.new_game(true,20261106)
	model.campaign.mode="free"
	model.money=5000000
	var hotel:Dictionary={}
	for z in range(160,420,34):
		for x in range(70,430,34):
			if model.build_building("hotel",Vector2(x,z)).ok:hotel=model.buildings[-1];break
		if not hotel.is_empty():break
	check(not hotel.is_empty(),"Real hotel built in resort")
	if hotel.is_empty():quit(1);return
	var before:=JSON.stringify(model.snapshot())
	var preview:Dictionary=Simulator.overview(model,hotel)
	check(JSON.stringify(model.snapshot())==before and preview.rooms.ready>0,"Inspecting simulator cannot change existing hotel saves")
	check(not Simulator.valid({"kind":"kiosk","sanitation":{"version":1}}),"Non-hotel cannot forge sanitary service state")
	var started:Dictionary=Simulator.begin(model,int(hotel.id))
	check(started.ok and hotel.has("room_operations") and hotel.has("sanitation"),"Interactive shift activates real bookings and restroom service without changing guests")
	check(not Simulator.sanitation_action(model,int(hotel.id),"activate").ok,"Sanitation activation idempotent")
	check(Progression.BRANCHES.size()==4 and Progression.branch_for("sanitation").id=="hospitality","Sanitation research belongs to hotel development tree")
	for stage in range(5):
		var scene:Dictionary=Simulator.situation(model,hotel,stage)
		check(scene.choices.size()==3 and not str(scene.prompt).is_empty(),"Real stage %d has actionable decisions" % stage)
		var result:Dictionary=Simulator.choose(model,started,1 if stage in [1,3] else 0)
		check(result.ok and int(started.step)==stage+1,"Stage %d commits one real decision" % stage)
		if stage==1:
			var resumed:Dictionary=Simulator.begin(model,int(hotel.id))
			check(resumed.ok and int(resumed.step)==2 and int(resumed.score)==int(started.score),"Closing and reopening resumes saved shift at the correct stage")
			var stale:Dictionary=started.duplicate(true)
			stale.step=1
			check(not Simulator.choose(model,stale,0).ok,"Stale copied shift cannot replay a paid decision")
			var snapshot_partial:Dictionary=JSON.parse_string(JSON.stringify(model.snapshot()))
			var restored_partial:=Resort.new()
			check(restored_partial.restore(snapshot_partial).ok and int(restored_partial.asset(int(hotel.id)).activity.hotel_shift.steps)==2,"Half-finished hotel shift survives checksum-compatible save restore")
	check(Simulator.overview(model,hotel).shift_done and hotel.sanitation.extra_units==1,"Completed shift persists and restroom capacity grows in free build")
	check(not Simulator.choose(model,started,0).ok and not Simulator.begin(model,int(hotel.id)).ok,"Shift cannot be rewarded twice in the same resort day")
	var state:Dictionary=JSON.parse_string(JSON.stringify(model.snapshot()))
	var restored:=Resort.new()
	check(restored.restore(state).ok and Simulator.overview(restored,restored.asset(int(hotel.id))).shift_done,"Save/restore preserves hotel state, restrooms and shift progress")
	var invalid:Dictionary=state.duplicate(true)
	for b in invalid.buildings:
		if int(b.id)==int(hotel.id):b.sanitation.extra_units=900;break
	var fresh:=Resort.new()
	check(not fresh.restore(invalid).ok,"Corrupted restroom capacity is rejected before save restore")
	model.day+=1
	Simulator.daily(model,hotel)
	check(float(hotel.sanitation.hygiene)<100.0 and not Simulator.overview(model,hotel).shift_done,"Next day has actual restroom wear and new hotel shift")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
