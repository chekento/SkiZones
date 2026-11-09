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
	# The capacity improvement is NOT free. Actual minute ticks pay the
	# specialists and allocate their wages to the correct venue's P&L.
	var empty_sales:float=float(restaurant.get("daily_revenue",0))
	var expected_minute_wages:float=(float(Ops.ROLES.chef.wage)+float(Ops.ROLES.waiter.wage))/60.0
	var before_wages:float=float(model.operations.cost_centres.get("building:987",0.0))
	Ops.tick(model)
	var booked_wages:float=float(model.operations.cost_centres.get("building:987",0.0))-before_wages
	check(absf(booked_wages-expected_minute_wages)<0.0001,"Qualified chef and waiter have real per-minute wage costs")
	var loss:Dictionary=Ops.business_balance(model,restaurant)
	check(empty_sales==0.0 and loss.wages>0.0 and loss.net<0.0,"A restaurant with employees but no customers actually loses money")
	check(absf(loss.costs-(loss.wages+loss.supplies+loss.overhead))<0.001,"P&L includes building wages, supplies and operating costs without duplicates")
	var first_capacity:int=model.service_capacity(restaurant)
	check(Ops.hire(model,"waiter","building:987").ok,"A venue can hire an additional correctly qualified waiter")
	Ops.refresh_duty(model)
	check(model.service_capacity(restaurant)>first_capacity,"Extra on-duty specialist increases the number of concurrent customers")
	var previous_wages:float=float(model.operations.cost_centres.get("building:987",0))
	Ops.tick(model)
	check(float(model.operations.cost_centres.get("building:987",0))-previous_wages>expected_minute_wages,"Adding a waiter increases recurring wage costs, not just capacity")
	check(not Ops.role_matches_building("hotel","school") and Ops.optional_roles("school")==["instructor"],"Skischule never offers the legacy hotel role to new employees")
	check(Recruit.FACILITIES.chef.has("restaurant") and not Recruit.FACILITIES.chef.has("hotel"),"Applicant gate matches required workplace")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
