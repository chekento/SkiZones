extends SceneTree
## Full dispatch, transport, treatment and save/resume on real resort routes.
const Resort=preload("res://src/core/resort.gd")
const Ops=preload("res://src/core/operations.gd")
const Foot=preload("res://src/core/foot_network.gd")
const Terrain=preload("res://src/core/terrain.gd")
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func fixture()->Dictionary:
	var model:=Resort.new()
	model.new_game(true,20261112,"sonnenhang",true)
	Ops.enable(model)
	model.enable_runtime_rules()
	model.operations.auto_groom=false
	var aid:Dictionary={}
	for z in range(240,330,35):
		for x in range(70,330,35):
			if model.build_building("first_aid",Vector2(x,z)).ok:aid=model.buildings[-1];break
		if not aid.is_empty():break
	if aid.is_empty() or not Ops.fill_building(model,int(aid.id)).ok or not model.admit_guest(0):return {}
	var guest:Dictionary=model.guests[0]
	for index in range(guest.route.legs.size()):
		if guest.route.legs[index].kind=="ski":
			guest.leg=index;model._start_leg(guest);guest.elapsed=guest.duration*0.45;break
	Ops.incident(model,guest,"collision")
	return {"model":model,"aid":aid,"guest":guest,"event":model.operations.incidents[-1]}
func run()->void:
	var state:=fixture()
	check(not state.is_empty(),"Actual casualty and staffed clinic exist")
	if state.is_empty():finish();return
	var model:RefCounted=state.model
	var event:Dictionary=state.event
	var guest:Dictionary=state.guest
	check(Ops.dispatch(model,int(event.id)).ok,"Both legs of the rescue are reachable")
	var returning:Array=event.get("return_route_points",[])
	check(returning.size()>=2,"Patient has a separate downhill return route")
	if returning.size()>=2:
		check(Terrain.unpack(returning[0]).distance_to(Terrain.unpack(event.point))<0.01,"Return starts at the patient")
		check(Terrain.unpack(returning[-1]).distance_to(Foot.door(state.aid))<0.01,"Return ends at the clinic door")
		var height:float=model.terrain.height(Terrain.unpack(event.point))
		var highest:float=height
		for point in returning:highest=maxf(highest,model.terrain.height(Terrain.unpack(point)))
		check(highest<=height+3,"Valley stretcher never climbs back to the tow summit")
	var saved:Dictionary={}
	var treatment:=0
	var deadline:=ceili(float(event.get("response_duration",0))+float(event.get("return_duration",0))+float(event.get("treatment_duration",0)))+3
	for step in range(deadline):
		if not saved.has(str(event.status)):
			var restored:=Resort.new()
			saved[str(event.status)]=restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok
			if saved[str(event.status)] and event.status in ["returning","treating"]:
				check(restored.guest_position(restored.guests[0]).distance_to(model.guest_position(guest))<0.01,"Patient position survives "+str(event.status)+" save")
				model=restored;event=model.operations.incidents[-1];guest=model.guests[0]
		if event.status=="treating":treatment+=1
		for tick in range(model.time_divisor):model.advance_minute(false)
		if event.status=="resolved":break
	check(saved.get("responding",false) and saved.get("returning",false) and saved.get("treating",false),"Every phase reloads and the restored world actually continues")
	check(treatment==120,"Actual collision treatment lasts 120 calendar minutes")
	check(event.status=="resolved" and guest.incident==-1 and guest.get("assisted",false),"Actual patient is discharged after the full unshortened round trip")
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok,"Discharged guest home route reloads")
	for invalid in [[],"invalid",[[0,0],[NAN,0]],[[0,0],[999999,0]]]:
		var broken:Dictionary=model.snapshot();broken.operations.incidents[0].return_route_points=invalid
		check(not Resort.new().restore(broken).ok,"Malformed return route rejected atomically")
	var legacy:Dictionary=model.snapshot();legacy.operations.incidents[0].erase("return_route_points")
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(legacy))).ok,"Legacy rescue records without return geometry still load")
	var history:Array=[]
	for id in range(1,101):
		var old:Dictionary=event.duplicate(true);old.id=id;old.status="resolved";history.append(old)
	model.operations.incidents=history;model.operations.next_incident=101;guest.incident=-1
	Ops.incident(model,guest)
	check(guest.incident==101 and model.operations.incidents.size()==100 and model.operations.incidents[-1].status=="waiting","Completed history cannot disable future accidents")
	for record in model.operations.incidents:record.status="waiting"
	guest.incident=-1
	var next:int=model.operations.next_incident
	Ops.incident(model,guest)
	check(guest.incident==-1 and model.operations.next_incident==next,"No active case is recycled")
	var blocked:=fixture()
	var blocked_model:RefCounted=blocked.model
	var graph:Dictionary=blocked_model._routing_graph(2)
	for key in graph.edges:graph.edges[key]=graph.edges[key].filter(func(leg):return str(leg.to)!="d%d" % int(blocked.aid.id))
	var cash:float=blocked_model.money
	check(not Ops.dispatch(blocked_model,int(blocked.event.id)).ok and blocked.event.status=="waiting" and blocked_model.money==cash,"No dispatch or material charge without a safe return")
	check(blocked.event.get("dispatch_blocked",false),"Blocked dispatch remains visible and retryable")
	blocked_model._graphs.clear()
	check(Ops.dispatch(blocked_model,int(blocked.event.id)).ok and not blocked.event.has("dispatch_blocked"),"Restored connection permits retry of the same case")
	var response:float=blocked.event.response_duration
	blocked_model.time_divisor=1;blocked.event.status="waiting"
	check(Ops.dispatch(blocked_model,int(blocked.event.id)).ok and float(blocked.event.response_duration)>response,"Travel follows calendar-to-movement scaling")
	finish()
func finish()->void:
	print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
