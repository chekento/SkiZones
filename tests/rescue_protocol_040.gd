extends SceneTree
## A casualty needs a routed pickup, stretcher return and treatment. Fear gets
## a guided descent instead of lying down or occupying a hospital bed.
const Rescue=preload("res://src/core/rescue_protocol_040.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS "+label)
	else:failed+=1;push_error("FAIL "+label)

func _init()->void:
	var routes:Array=Rescue.route_points_from_legs([0,0],[{"points":[[10,0],[30,30],[60,30]]}],[90,60])
	check(routes.size()==5,"Rescue trajectory retains routed mountain waypoints")
	var injury:Dictionary={"id":8,"guest":21,"reason":"collision","point":[90,60],"status":"responding","remaining":2.0,"response_duration":2.0,"route_points":routes,"transport_mode":"skis"}
	check(Rescue.needs_stretcher("collision") and not Rescue.needs_stretcher("navigation"),"Accidents require a stretcher; navigation fear does not")
	check(Rescue.route_position(injury).distance_to(Vector2(0,0))<0.01,"Outbound rescue starts at station")
	check(not Rescue.tick(injury) and injury.status=="responding","Two-person response requires positive travel time")
	check(not Rescue.tick(injury) and injury.status=="transporting","On arrival the casualty is loaded for return")
	check(Rescue.route_position(injury).distance_to(Vector2(90,60))<0.01,"Transport starts at incident, not an invented shortcut")
	var return_count:=0
	while injury.status=="transporting" and return_count<200:
		Rescue.tick(injury)
		return_count+=1
	check(injury.status=="treating" and return_count>=5,"Patient travels on a stretcher before reaching station")
	check(Rescue.treatment_minutes(injury)>=60 and Rescue.treatment_minutes(injury)<=120,"Medical treatment lasts one to two in-game hours")
	var treatment_step:=0
	while injury.status=="treating" and treatment_step<140:
		Rescue.tick(injury)
		treatment_step+=1
	check(injury.status=="resolved" and treatment_step>=60,"Only completed treatment releases patient")
	var afraid:Dictionary={"id":9,"guest":22,"reason":"navigation","point":[90,60],"status":"responding","remaining":1.0,"response_duration":8.0,"route_points":routes}
	check(not Rescue.tick(afraid) and afraid.status=="guiding","Fearful skier is accompanied, never evacuated on a stretcher")
	check(Rescue.route_position(afraid).distance_to(Vector2(90,60))<0.01,"Guided descent starts at difficulty point")
	var guide_steps:=0
	while afraid.status=="guiding" and guide_steps<80:
		Rescue.tick(afraid)
		guide_steps+=1
	check(afraid.status=="resolved" and guide_steps>=8,"Guidance completes without treatment")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
