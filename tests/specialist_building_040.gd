extends SceneTree
## Staff have specialist assignments and affect real throughput, not just payroll.
const Resort=preload("res://src/core/resort.gd")
const Ops=preload("res://src/core/operations.gd")
const Needs=preload("res://src/core/guest_needs.gd")
const Recruit=preload("res://src/core/recruitment.gd")
var passed:=0
var failed:=0
func check(ok:bool,message:String)->void:
	if ok:passed+=1;print("PASS "+message)
	else:failed+=1;push_error("FAIL "+message)

func _init()->void:
	var model:=Resort.new()
	model.new_game(false,20261108,"sonnenhang")
	Ops.enable(model)
	model.minute=600
	var restaurant:Dictionary={"id":987,"kind":"restaurant","enabled":true,"point":[30,150],"level":1}
	var hotel:Dictionary={"id":988,"kind":"hotel","enabled":true,"point":[40,150],"level":1}
	model.buildings.append(restaurant)
	model.buildings.append(hotel)
	check(Ops.building_roles("restaurant")==["chef","waiter"],"Restaurant hires chef and waiter, not hotel roles")
	check(Ops.building_roles("hotel").has("reception") and Ops.building_roles("hotel").has("housekeeping"),"Hotel requires relevant qualified employees")
	check(not Ops.role_matches_building("hotel","restaurant"),"Wrong venue specialist cannot be assigned")
	check(not Ops.hire(model,"hotel","building:987").ok,"Hiring hotel staff into restaurant is rejected")
	check(not Ops.hire(model,"chef","building:988").ok,"Hiring chef into hotel reception is rejected")
	check(Ops.hire(model,"chef","building:987").ok,"Chef can join a restaurant")
	check(Ops.hire(model,"waiter","building:987").ok,"Waiter can join a restaurant")
	Ops.refresh_duty(model)
	check(Ops.building_staffed(model,restaurant),"Matching specialist team runs its restaurant")
	check(Ops.building_efficiency(model,restaurant)>1.1,"Active specialist team raises real service efficiency")
	check(model.service_capacity(restaurant)>int(Needs.SERVICES.restaurant.places),"Specialists increase concurrent visitor capacity")
	check(Ops.building_efficiency(model,hotel)==1.0,"Unstaffed hotel has no invented efficiency bonus")
	check(Recruit.FACILITIES.chef.has("restaurant") and not Recruit.FACILITIES.chef.has("hotel"),"Applicant gate matches required workplace")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
