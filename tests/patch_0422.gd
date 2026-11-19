extends SceneTree
## 0.42.2 regression: real shift staffing, concurrent 2-person rescue crews,
## treatment releases the crew, snowmobile geometry, and legacy snapshots.
const Resort=preload("res://src/core/resort.gd")
const Ops=preload("res://src/core/operations.gd")
const Terrain=preload("res://src/core/terrain.gd")
const Crew=preload("res://src/world/crew_life.gd")
var passed:=0
var failed:=0

func _init()->void:
	call_deferred("run")

func check(ok:bool,description:String)->void:
	if ok:
		passed+=1
		print("PASS ",description)
	else:
		failed+=1
		push_error("FAIL "+description)

func clinic(model:RefCounted)->Dictionary:
	for z in range(240,330,35):
		for x in range(70,330,35):
			if model.build_building("first_aid",Vector2(x,z)).ok:
				return model.buildings[-1]
	return {}

func accident(model:RefCounted)->Dictionary:
	if not model.admit_guest(0):return {}
	var guest:Dictionary=model.guests[-1]
	for index in range(guest.route.legs.size()):
		if str(guest.route.legs[index].kind)=="ski":
			guest.leg=index
			model._start_leg(guest)
			guest.elapsed=float(guest.duration)*0.45
			break
	Ops.incident(model,guest,"collision")
	return model.operations.incidents[-1]

func run()->void:
	var model:=Resort.new()
	model.new_game(true,20261119,"sonnenhang",true)
	Ops.enable(model)
	model.enable_runtime_rules()
	model.operations.auto_groom=false
	var aid:Dictionary=clinic(model)
	check(not aid.is_empty(),"Real rescue building can be placed")
	if aid.is_empty():finish();return
	var station_id:int=int(aid.id)
	var target:String="building:%d" % station_id
	check(Ops.fill_building(model,station_id).ok,"Two regular rescuers fill the Bergwacht")
	check(Ops.hire(model,"rescue",target,"day",true).ok and Ops.hire(model,"rescue",target,"day",true).ok,"Two additional responders exist as actual employees")
	check(Ops.free_rescue_crew(model,station_id).size()==4,"All four on-duty employees are eligible for dispatch")
	var offshift:Dictionary=Ops.hire(model,"rescue",target,"night",true)
	check(offshift.ok and Ops.free_rescue_crew(model,station_id).size()==4,"Night-shift responder does not count during daytime")
	var a:Dictionary=accident(model)
	var b:Dictionary=accident(model)
	var c:Dictionary=accident(model)
	check(not a.is_empty() and not b.is_empty() and not c.is_empty(),"Three real, separately injured visitors exist")
	if a.is_empty() or b.is_empty() or c.is_empty():finish();return
	check(Ops.dispatch(model,int(a.id)).ok,"First two-person rescue team dispatched")
	check(Ops.dispatch(model,int(b.id)).ok,"Second two-person team dispatched concurrently")
	check(a.get("crew_ids",[]).size()==2 and b.get("crew_ids",[]).size()==2,"Both dispatches reserve individual employee IDs")
	var overlap:bool=false
	for id in a.get("crew_ids",[]):
		if b.get("crew_ids",[]).has(id):overlap=true
	check(not overlap,"Concurrent teams never duplicate an employee")
	check(Ops.free_rescue_crew(model,station_id).is_empty(),"No fifth daytime rescuer invented")
	check(not Ops.dispatch(model,int(c.id)).ok and c.status=="waiting","Third incident waits for an actual available team")
	var busy_id:int=int(a.crew_ids[0])
	check(not Ops.dismiss(model,busy_id).ok,"Busy responder cannot be dismissed mid-transport")
	a.status="treating"
	a.remaining=0.0
	a.transport_remaining=0.0
	check(Ops.free_rescue_crew(model,station_id).size()==2,"Team returns to duty as soon as treatment begins")
	check(Ops.dispatch(model,int(c.id)).ok,"New incident can dispatch before previous patient is cured")
	check(int(a.get("treatment_remaining",0))>0 and a.status=="treating","Treating patient remains in clinic during further dispatch")
	check(c.get("crew_ids",[])==a.get("crew_ids",[]),"New rescue reuses only the released pair")
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok,"Parallel dispatch and treatment survive JSON save/restore")
	check(Ops._mobile_climb_safe(model,[Terrain.pack(Terrain.BASE),Terrain.pack(Terrain.BASE+Vector2(10,0))]) is bool,"Snowmobile uphill safety checker executes")
	check(is_finite(Ops.snowmobile_travel_minutes(model,[Terrain.pack(Terrain.BASE),Terrain.pack(Terrain.BASE+Vector2(10,0))])),"Snowmobile has a finite road travel profile on permissible terrain")
	var graph:Dictionary=model._routing_graph(2)
	var mobile:Dictionary=Ops._mobile_graph(model,graph)
	check(mobile.nodes.size()==graph.nodes.size() and mobile.edges.size()==graph.edges.size(),"Snowmobile routing reuses real resort route nodes")
	for group in Crew.CREW_GROUPS:
		check(Crew.human_mesh("alpine",str(group)).get_surface_count()>0,"Recognisable staff asset: "+str(group))
	check(Crew.snowmobile_art("alpine",false).get_surface_count()>0 and Crew.snowmobile_art("alpine",true).get_surface_count()>0,"Snowmobile geometry supports outward and patient transport")
	# No new scene data is required in an existing career snapshot.
	var legacy:Dictionary=model.snapshot()
	for incident in legacy.operations.incidents:
		incident.erase("crew_ids")
		incident.erase("vehicle")
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(legacy))).ok,"0.42.1 rescue snapshots remain valid")
	finish()

func finish()->void:
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
