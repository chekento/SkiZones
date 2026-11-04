extends SceneTree
const Ops=preload("res://src/core/operations.gd")
const Recruit=preload("res://src/core/recruitment.gd")
const Resort=preload("res://src/core/resort.gd")
const Geo=preload("res://src/core/real_resorts.gd")
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
		if id=="seiseralm" and not garage.is_empty():
			var initial: int=scenario.operations.vehicles.size()
			var balance: float=scenario.money
			check(Ops.buy_groomers(scenario,int(garage.id),3).ok and scenario.operations.vehicles.size()==initial+3 and scenario.money==balance-195000,"Seiseralm supports three groomers atomically")
			var restored:=Resort.new()
			check(restored.restore(scenario.snapshot()).ok and restored.operations.vehicles.size()==scenario.operations.vehicles.size(),"Multi-groomer fleet survives save/restore")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
