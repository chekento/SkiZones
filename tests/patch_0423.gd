extends SceneTree
## Regression coverage for the 0.42.3 crew, economy and safe-night patch.
const Resort=preload("res://src/core/resort.gd")
const Ops=preload("res://src/core/operations.gd")
const Crew=preload("res://src/world/crew_life.gd")
const DayRhythm=preload("res://src/core/day_rhythm.gd")
const Terrain=preload("res://src/core/terrain.gd")
const SceneBoard=preload("res://src/ui/staff_training_scene_0423.gd")
const ResortView=preload("res://src/world/resort_view.gd")
var passed:int=0
var failed:int=0

func _init()->void:call_deferred("run")
func check(ok:bool,detail:String)->void:
	if ok:passed+=1;print("PASS ",detail)
	else:failed+=1;push_error("FAIL "+detail)

func fresh()->RefCounted:
	var model:RefCounted=Resort.new()
	model.new_game(true,20261120,"sonnenhang",true)
	Ops.enable(model)
	model.enable_runtime_rules()
	model.campaign.mode="free"
	model.money=1000000.0
	return model

func place(model:RefCounted,kind:String)->Dictionary:
	for z in range(240,410,35):
		for x in range(70,340,35):
			if model.build_building(kind,Vector2(x,z)).ok:return model.buildings[-1]
	return {}

func run()->void:
	var model:RefCounted=fresh()
	model.minute=DayRhythm.QUIET_FROM-1
	check(not model.empty_night(),"Fast-forward is not forced before 19:00")
	model.minute=DayRhythm.QUIET_FROM
	check(model.empty_night(),"Empty pistes may safely fast-forward at 19:00")
	model.operations.incidents.append({"id":30,"guest":-1,"status":"treating"})
	check(model.empty_night(),"Indoor patient treatment need not stall a deserted resort")
	model.operations.incidents.back().status="returning"
	check(not model.empty_night(),"Outdoor rescue sled blocks accelerated time")
	model.operations.incidents.clear()
	var day:int=model.day
	var visits:int=model.total_guests
	for i in range(1440-DayRhythm.QUIET_FROM+model.OPENING-1):
		if not model.advance_empty_minute():break
	check(model.day==day+1 and model.minute==model.OPENING-1 and model.total_guests==visits,"Overnight travel is genuinely visitor-free until 07:59")
	check(model.advance_empty_minute() and model.minute==model.OPENING,"Safe forwarding stops at 08:00 and lets real morning demand resume")
	var restaurant:Dictionary=place(model,"restaurant")
	check(not restaurant.is_empty(),"Place a working restaurant")
	if restaurant.is_empty():finish();return
	# Keep the service team in the day shift while evaluating a new day.
	model.minute=660
	model._duty_cache.clear()
	check(Ops.fill_building(model,int(restaurant.id),true).ok,"Kitchen obtains a real qualified cook")
	var target:String="building:%d" % int(restaurant.id)
	var without_waiter:float=Ops.service_efficiency(model,restaurant)
	var without_capacity:int=model.service_capacity(restaurant)
	check(without_waiter<1.0,"An unserved kitchen is a lower-throughput self-service venue")
	check(Ops.hire(model,"waiter",target,"day",true).ok,"A dedicated waiter can be hired")
	var with_waiter:float=Ops.service_efficiency(model,restaurant)
	check(with_waiter>without_waiter and model.service_capacity(restaurant)>without_capacity,"Front-of-house staffing improves actual bookable capacity")
	check(Ops.hire(model,"chef",target,"day",true).ok and Ops.hire(model,"waiter",target,"day",true).ok,"Both production and service teams can grow")
	var with_team:float=Ops.service_efficiency(model,restaurant)
	check(with_team>with_waiter,"A second chef and waiter raise throughput beyond a single pair")
	model.minute=1140;model._duty_cache.clear()
	check(not Ops.building_open(model,restaurant) and is_equal_approx(Ops.service_efficiency(model,restaurant),1.0),"Off-duty kitchen is closed, with neutral accounting baseline")
	model.minute=420
	var staff:Dictionary={"shift":"day"}
	var morning:Dictionary=Crew._commute_phase(model,staff,20.0)
	check(not morning.travel and not morning.returning,"A team member is present at the workplace when shift starts")
	model.minute=405
	var inbound:Dictionary=Crew._commute_phase(model,staff,20.0)
	check(inbound.travel and not inbound.returning and inbound.fraction>0.0 and inbound.fraction<1.0,"Inbound staff travels before the shift")
	model.minute=1090
	var outbound:Dictionary=Crew._commute_phase(model,staff,20.0)
	check(outbound.travel and outbound.returning and outbound.fraction>0.0,"Employees actually return toward their dorm after the shift")
	check(Crew.group_for_role("chef")=="chef" and Crew.group_for_role("waiter")=="waiter","Chef and service uniforms are distinct")
	var pts:Array=[Terrain.pack(Vector2(20,20)),Terrain.pack(Vector2(320,20))]
	check(Crew._travel_time([{"kind":"ski","points":pts}])<Crew._travel_time([{"kind":"walk","points":pts}]),"Skis can shorten the real return commute")
	var board:Control=SceneBoard.new()
	board.configure("chef",1)
	check(board.custom_minimum_size.y>=200 and board.profession=="chef","Interactive vocational training board can display the cooking station")
	board.free()
	# The actual employee commute must be a chain of existing connected
	# public graph segments, not the old straight line across slopes.
	var view:Node3D=ResortView.new()
	view.model=model
	view.terrain=model.terrain
	var crew:Crew=Crew.new()
	crew.lodge_point=Terrain.BASE
	var resort_lodges:Array=model.buildings.filter(func(z):return str(z.kind)=="lodge")
	check(not resort_lodges.is_empty(),"Starter resort has an actual staffed, walkable service building")
	if not resort_lodges.is_empty():
		var lodge:Dictionary=resort_lodges[0]
		var workers:Array=model.operations.staff.filter(func(p):return str(p.assignment)=="building:%d" % int(lodge.id))
		check(not workers.is_empty(),"Starter lodge contains named real employees")
		if not workers.is_empty():
			var foot_legs:Array=crew._route(view,workers[0],false)
			check(not foot_legs.is_empty(),"A worker can commute along a connected resort graph")
			check(foot_legs.all(func(leg):return str(leg.get("kind","")) in ["walk","ski","lift"] and leg.get("points",[]).size()>=2),"Commute contains only real walking, skiing and lift sections")
			if not foot_legs.is_empty():
				var final_leg:Dictionary=foot_legs.back()
				var endpoint:Vector2=Terrain.unpack(final_leg.points.back())
				check(endpoint.distance_to(Terrain.unpack(model.pedestrian_graph().nodes["d%d" % int(lodge.id)]))<0.1,"Commute terminates at the actual workplace door")
	view.free()
	var snap:Dictionary=JSON.parse_string(JSON.stringify(model.snapshot()))
	check(Resort.new().restore(snap).ok,"New staffing policy preserves existing career save schema")
	finish()

func finish()->void:
	print("SkiZones 0.42.3 operational regressions")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
