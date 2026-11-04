extends SceneTree
const Ops=preload("res://src/core/operations.gd")
const Recruit=preload("res://src/core/recruitment.gd")
const Resort=preload("res://src/core/resort.gd")
const Geo=preload("res://src/core/real_resorts.gd")
const Terrain=preload("res://src/core/terrain.gd")
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok:bool,name:String)->void:
	if ok:passed+=1;print("PASS ",name)
	else:failed+=1;push_error("FAIL "+name)
func run()->void:
	var model:=Resort.new();model.new_game(true,20261027,"sonnenhang")
	var candidates: Array=Recruit.market(model)
	check(candidates.size()>=18,"Applicant board offers distinct profiles")
	var entry: Dictionary=candidates[0]
	check(entry.available and entry.experience>0 and entry.qualification==1,"Entry-level candidate has valid profile")
	var hired: Dictionary=Recruit.hire_candidate(model,str(entry.id),"reserve","day")
	check(hired.ok and model.operations.staff.any(func(p):return p.get("applicant_id","")==entry.id),"Named candidate retains identity when hired")
	check(not Recruit.hire_candidate(model,str(entry.id),"reserve","day").ok,"One candidate cannot be hired twice")
	check(Recruit.market(model).any(func(c):return c.qualification>=2 and not c.available),"Advanced specialists locked until rank unlock")
	for id in Geo.IDS:
		var scenario:=Resort.new();scenario.new_game(true,20261027,id)
		check(Ops.GOALS[id].size()==5 and scenario.operations.scenario==id,"Scenario "+id+" has five tracked mission goals")
		var garage: Dictionary={}
		var workshop: Dictionary={}
		var aid: Dictionary={}
		for building in scenario.buildings:
			if building.kind=="maintenance":garage=building
			if building.kind=="repair_office":workshop=building
			if building.kind=="first_aid":aid=building
		check(not garage.is_empty() and not workshop.is_empty() and not aid.is_empty(),"Scenario "+id+" provides garage, repair office and rescue facility")
		if not workshop.is_empty():
			check(not Ops.building_staffed(scenario,workshop),"Scenario "+id+" leaves the advertised repair-team mission actionable")
			var budget: float=scenario.money
			check(Ops.fill_building(scenario,int(workshop.id)).ok and scenario.money==budget-360,"Scenario "+id+" recruits its two repair specialists for the quoted cost")
			check(Ops.building_staffed(scenario,workshop),"Scenario "+id+" workshop becomes operational after recruitment")
		if id=="seiseralm" and not garage.is_empty():
			var initial: int=scenario.operations.vehicles.size()
			var balance: float=scenario.money
			check(Ops.buy_groomers(scenario,int(garage.id),3).ok and scenario.operations.vehicles.size()==initial+3 and scenario.money==balance-195000,"Seiseralm supports three groomers atomically")
			var restored:=Resort.new()
			check(restored.restore(scenario.snapshot()).ok and restored.operations.vehicles.size()==scenario.operations.vehicles.size(),"Multi-groomer fleet survives save/restore")
	# Exercise the accelerated real-geodata placement using a missing first-aid
	# building. Test in memory only; no player save or imported slope is changed.
	var clearance_model := Resort.new()
	clearance_model.new_game(true,20261027,"braunlage")
	clearance_model.buildings = clearance_model.buildings.filter(func(b):return str(b.kind)!="first_aid")
	var old_ids: Dictionary = {}
	for building in clearance_model.buildings:old_ids[int(building.id)] = true
	Geo.ensure_operations_facilities(clearance_model)
	var fresh_aid: Array = clearance_model.buildings.filter(func(b):return str(b.kind)=="first_aid" and not old_ids.has(int(b.id)))
	check(fresh_aid.size()==1,"Missing Braunlage rescue facility can be re-sited on real terrain")
	if fresh_aid.size()==1:
		var site: Vector2 = Terrain.unpack(fresh_aid[0].point)
		var cleared: bool = clearance_model.terrain.contains(site) and clearance_model.terrain.slope_percent(site)<=40.0
		for building in clearance_model.buildings:
			if int(building.id)!=int(fresh_aid[0].id) and Terrain.unpack(building.point).distance_to(site)<50.0:cleared=false
		for lift in clearance_model.lifts:
			if Terrain.unpack(lift.bottom).distance_to(site)<60.0 or Terrain.unpack(lift.top).distance_to(site)<60.0:cleared=false
		for piste in clearance_model.pistes:
			for point_index in range(1,piste.points.size()):
				var a: Vector2 = Terrain.unpack(piste.points[point_index-1])
				var b: Vector2 = Terrain.unpack(piste.points[point_index])
				if Geometry2D.get_closest_point_to_segment(site,a,b).distance_to(site)<30.0:cleared=false
		check(cleared,"Cached segment placement keeps original 30/50/60 metre safety clearances")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
