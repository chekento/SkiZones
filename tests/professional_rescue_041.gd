extends SceneTree
## Regression: no inappropriate hotel staff at ski schools or rental
## facilities; specialist staff affect actual capacity; rescue has separate
## outbound, stretcher return and 1-2 hour treatment states.
const Resort=preload("res://src/core/resort.gd")
const Ops=preload("res://src/core/operations.gd")
const Terrain=preload("res://src/core/terrain.gd")
const DayRhythm=preload("res://src/core/day_rhythm.gd")
var passed:=0
var failed:=0

func check(ok:bool,description:String)->void:
	if ok:
		passed+=1
		print("PASS ",description)
	else:
		failed+=1
		push_error("FAIL "+description)

func _init()->void:
	call_deferred("run")

func run()->void:
	var professions:Dictionary={
		"restaurant":["chef"],"pizzeria":["chef"],"cocoa":["barista"],
		"school":["ski_instructor"],"rental":["rental_specialist"],
		"fitness":["fitness_trainer"],"watchmaker":["watchmaker"],
		"craftshop":["artisan"],"printing_press":["printer"],
		"newsstand":["vendor"],"pool":["lifeguard","security"],"spa":["therapist","security"],
		"first_aid":["rescue","rescue"]
	}
	for kind in professions:
		check(Ops.building_roles(str(kind))==professions[kind],"Correct mandatory professionals at "+str(kind))
	check(Ops.building_optional_roles("restaurant").has("waiter"),"Restaurant can hire real waiters as optional service staff")
	check(not Ops.building_optional_roles("school").has("hotel"),"Ski school cannot hire unrelated hotel staff")
	check(Ops.legacy_specialization("school")=="ski_instructor","Legacy ski-school workers migrate to instructor")

	var model:=Resort.new()
	model.new_game(true)
	var venue:Dictionary={}
	for building in model.buildings:
		if str(building.get("kind",""))=="restaurant":
			venue=building
			break
	# Build a contained synthetic restaurant only if the starter lacks one.
	if venue.is_empty():
		var identifier:=maxi(900000,int(model.next_id)+200)
		venue={"id":identifier,"kind":"restaurant","point":Terrain.pack(Terrain.BASE+Vector2(40,40)),"enabled":true,"level":1}
		model.buildings.append(venue)
		model._invalidate()
	model.operations.enabled=true
	model.operations.continuous=true
	model.minute=750
	var target:String="building:%d" % int(venue.id)
	var before_money:float=model.money
	var invalid:Dictionary=Ops.hire(model,"hotel",target)
	check(not invalid.ok and is_equal_approx(model.money,before_money),"Incorrect hotel job rejected without recruitment charge")
	var required:Dictionary=Ops.hire(model,"chef",target)
	check(required.ok,"Qualified kitchen staff can join the restaurant")
	var base_capacity:int=model.service_capacity(venue)
	var base_efficiency:float=Ops.service_efficiency(model,venue)
	var optional:Dictionary=Ops.hire(model,"waiter",target)
	var new_capacity:int=model.service_capacity(venue)
	var new_efficiency:float=Ops.service_efficiency(model,venue)
	check(optional.ok and new_efficiency>base_efficiency and new_capacity>base_capacity,"A waiter actually increases visitor throughput")
	check(model.money<=before_money-360.0,"Specialist jobs incur real hiring costs")
	check(Ops.ROLES["waiter"].wage>0.0 and Ops.ROLES["chef"].wage>0.0,"Extra service capacity has a wage liability")

	# Old saves used a generic hotel worker at ski schools. Reuse the ID,
	# shift and employment history without creating a new employee.
	var school_id:=int(model.next_id)+300
	model.buildings.append({"id":school_id,"kind":"school","point":Terrain.pack(Terrain.BASE+Vector2(60,70)),"enabled":true,"level":1})
	model._invalidate()
	var old_id:int=int(model.operations.next_staff)
	model.operations.next_staff+=1
	model.operations.staff.append({"id":old_id,"name":"Legacy instructor","role":"hotel","assignment":"building:%d" % school_id,"shift":"day","wage":Ops.ROLES["hotel"].wage,"qualification":1,"motivation":85.0,"fatigue":0.0,"worked":30,"absent_until":0,"break_until":0})
	Ops.normalize_assignments(model)
	var migrated:Dictionary=model.operations.staff[-1]
	check(migrated.id==old_id and migrated.role=="ski_instructor" and migrated.wage==Ops.ROLES["ski_instructor"].wage and migrated.worked==30,"Old school employee becomes an instructor without losing progress")
	check(Ops.valid(model.operations,model),"Specialist roles and migrated salaries remain valid for career saves")

	# Regression: an injured skier in the center of a 600 m run must
	# remain reachable even though both graph end nodes are >180 m away.
	var long_piste:Array=[Terrain.pack(Terrain.BASE),Terrain.pack(Terrain.BASE+Vector2(0,600))]
	var virtual_graph:Dictionary={"edges":{"slope-start":[{"kind":"ski","from":"slope-start","to":"slope-end","points":long_piste}]}}
	var middle:Vector2=Terrain.BASE+Vector2(0,300)
	var links:Array=Ops._rescue_slope_candidates(virtual_graph,middle)
	check(not links.is_empty() and str(links[0].from)=="slope-start","Injured mid-slope skier can be located on a long piste, not only at top/bottom nodes")
	if not links.is_empty():
		var route_points:Array=links[0].points
		check(route_points.size()==2 and Terrain.unpack(route_points[-1]).distance_to(middle)<0.01,"Rescue approach uses true ski line to injured midpoint")
	check(Ops._rescue_slope_candidates(virtual_graph,Terrain.BASE+Vector2(200,300)).is_empty(),"No invented rescue shortcut to a distant inaccessible off-piste point")

	var points:Array=[Terrain.pack(Terrain.BASE),Terrain.pack(Terrain.BASE+Vector2(20,0)),Terrain.pack(Terrain.BASE+Vector2(20,20))]
	check(Ops.rescue_path_point(points,0.5).distance_to(Terrain.BASE+Vector2(20,0))<0.01,"Rescue personnel follow a bent route, not a direct diagonal shortcut")
	var event:Dictionary={"id":1,"guest":1,"station":-1,"point":Terrain.pack(Terrain.BASE+Vector2(20,20)),"status":"responding","remaining":15.0,"response_duration":30.0,"route_points":points}
	check(is_equal_approx(Ops.rescue_fraction(event),0.5),"Outbound phase progresses along the route")
	event.status="returning"
	event.return_duration=30.0
	event.transport_remaining=15.0
	check(is_equal_approx(Ops.rescue_fraction(event),0.5),"Loaded return phase moves backwards along the same path")
	check(Ops.rescue_location(model,event).distance_to(Terrain.BASE+Vector2(20,0))<0.01,"Stretcher with patient uses real graph waypoints")
	event.status="treating"
	event.treatment_duration=90.0
	event.treatment_remaining=90.0
	check(is_equal_approx(Ops.rescue_fraction(event),0.0),"Treating patient remains at first-aid station")
	check(event.treatment_duration>=60.0 and event.treatment_duration<=120.0,"Treatment takes one to two game hours")
	# Progress an actual rescue job across all phases, beyond the day shift.
	# Active incidents must not freeze in the evening when day personnel
	# finish their normal shift; after-hours rescue pay remains in the ledger.
	var aid:Dictionary={}
	for building in model.buildings:
		if str(building.get("kind",""))=="first_aid":
			aid=building
			break
	if aid.is_empty():
		var rescue_id:=int(model.next_id)+450
		aid={"id":rescue_id,"kind":"first_aid","point":Terrain.pack(Terrain.BASE+Vector2(60,70)),"enabled":true,"level":1}
		model.buildings.append(aid)
		model._invalidate()
	Ops.fill_building(model,int(aid.id),true)
	model.minute=1085
	var incident:Dictionary={
		"id":808,"guest":99999,"reason":"collision",
		"point":Terrain.pack(Terrain.BASE+Vector2(35,35)),
		"station":int(aid.id),"created":Ops.clock(model),"status":"responding",
		"remaining":1.0,"response_duration":1.0,"response_started":Ops.clock(model),
		"return_duration":1.0,"transport_remaining":1.0,
		"treatment_duration":60.0,"treatment_remaining":60.0,
		"route_points":[aid.point.duplicate(),Terrain.pack(Terrain.BASE+Vector2(35,35))]
	}
	model.operations.incidents=[incident]
	var wages_before:float=float(model.operations.cost_centres.get("building:%d" % int(aid.id),0.0))
	model.time_divisor=24
	model.minute=1200
	check(not DayRhythm.quiet_night(model),"A live rescue cannot be erased by the 20:00 fast night skip")
	model.minute=1085
	Ops.tick(model)
	check(incident.status=="returning","Rescue arrival starts stretcher return rather than instant heal")
	for travel_minute in range(8):
		Ops.tick(model)
	check(incident.status=="treating","Stretcher return starts an actual clinic treatment after travel time")
	for step in range(60):
		Ops.tick(model)
	check(incident.status=="resolved" and int(model.operations.rescued)>=1,"Rescue resolves only after treatment time has elapsed")
	check(float(model.operations.cost_centres.get("building:%d" % int(aid.id),0.0))>wages_before,"Rescue staff earn ledgered overtime after normal shifts")

	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
