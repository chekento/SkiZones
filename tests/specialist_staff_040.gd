extends SceneTree
const Specialists=preload("res://src/core/specialist_staff_040.gd")
const Ops=preload("res://src/core/operations.gd")
const Resort=preload("res://src/core/resort.gd")
var passed:=0
var failed:=0

func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS "+label)
	else:failed+=1;push_error("FAIL "+label)

func _init()->void:
	check(Specialists.optional_roles("restaurant")==["chef","waiter"],"Restaurant offers chefs and waiters only")
	check(Specialists.optional_roles("hotel")==["receptionist","housekeeper"],"Hotel specialists use reception and housekeeping")
	check(not Specialists.allowed("receptionist","restaurant"),"Hotel reception is not restaurant work")
	check(not Specialists.allowed("chef","hotel"),"Kitchen staff cannot be assigned to hotel reception")
	var chef:Dictionary={"role":"chef","qualification":4,"motivation":95.0,"fatigue":0.0}
	var improved:Dictionary=Specialists.metrics("restaurant",[chef])
	check(float(improved.throughput)>1.0 and float(improved.quality)>1.0,"Qualified chef improves actual service statistics")
	var tired:Dictionary=chef.duplicate(true)
	tired.fatigue=95.0
	check(float(Specialists.metrics("restaurant",[tired]).throughput)<float(improved.throughput),"Fatigue reduces productivity")
	check(Specialists.metrics("restaurant",[{"role":"housekeeper","qualification":5,"motivation":100,"fatigue":0}]).throughput==1.0,"Wrong profession has no performance bonus")
	var model:=Resort.new()
	model.new_game(false)
	var building:Dictionary={"id":905,"kind":"restaurant","enabled":true,"level":1,"point":[145,205]}
	model.buildings.append(building)
	var baseline:int=model.service_capacity(building)
	check(not Ops.hire(model,"receptionist","building:905","day",true).ok,"Unqualified cross-sector assignment rejected")
	check(Ops.hire(model,"chef","building:905","day",true).ok,"Professional chef can work in restaurant")
	check(Ops.hire(model,"waiter","building:905","day",true).ok,"Professional waiter can work in restaurant")
	var metrics:Dictionary=Ops.specialist_metrics(model,building)
	check(float(metrics.throughput)>1.1 and float(metrics.capacity)>1.05,"On-duty specialists improve speed and places")
	check(model.service_capacity(building)>baseline,"Real guest service capacity rises with specialists")
	var employee:Dictionary=model.operations.staff[0]
	check(not Ops.assign(model,int(employee.id),"building:999","day").ok,"Nonexistent building cannot accept specialist")
	check(Ops.assign(model,int(employee.id),"reserve","day").ok,"Professional can return to reserves")
	check(float(Ops.specialist_metrics(model,building).throughput)<float(metrics.throughput),"Reserves stop affecting building performance")
	check(Ops.ROLES.has("catering") and Ops.ROLES.has("hotel"),"Legacy generic roles remain loadable")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
