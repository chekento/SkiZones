extends SceneTree
const Rescue=preload("res://src/core/rescue_response_040.gd")
const Ops=preload("res://src/core/operations.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS "+label)
	else:failed+=1;push_error("FAIL "+label)
func _init()->void:
	check(not Rescue.needs_stretcher("navigation"),"A fearful guest is guided, not stretchered")
	for reason in Rescue.INJURY_REASONS:
		check(Rescue.needs_stretcher(reason),"Injured passenger requires transport: "+reason)
		for id in [1,6,40,200]:
			check(Rescue.treatment_minutes(reason,id)>=60 and Rescue.treatment_minutes(reason,id)<=120,"Treatment stays inside 1–2 hours")
	check(Rescue.treatment_minutes("navigation",7)==0,"Fear never creates fake hospital treatment")
	check(Rescue.transport_mode(900.0,true,true)=="snowcat","Snowcat supports distant night rescues")
	check(Rescue.transport_mode(100.0,false,false)=="ski_stretcher","Two skiers and stretcher work without vehicle")
	var staff:Array=[
		{"id":7,"role":"rescue","assignment":"building:42"},
		{"id":8,"role":"rescue","assignment":"building:42"},
		{"id":9,"role":"rescue","assignment":"building:42"},
		{"id":10,"role":"hotel","assignment":"building:42"},
		{"id":11,"role":"rescue","assignment":"building:49"}]
	var available:Callable=func(person):return person.get("id")!=9
	check(Rescue.available_team(staff,[],"building:42",available)==[7,8],"Select two nearest available team members from correct station")
	var occupied:Array=[{"status":"responding","rescue_team":[7,8]}]
	check(Rescue.available_team(staff,occupied,"building:42",available).is_empty(),"Busy responders cannot serve second incident")
	var path:Array=Rescue.route_points([0,0],[{"points":[[0,0],[25,-25],[50,-25]]}],[75,-25])
	check(path.size()==4,"Graph route builds actual rescue travel path")
	check(Rescue.position_on_route(path,0.0)==Vector2.ZERO and Rescue.position_on_route(path,1.0)==Vector2(75,-25),"Rescue path preserves real endpoints")
	check(Rescue.position_on_route(path,0.5).distance_to(Vector2(37.5,-25.0))<0.001,"Rescue crew travel follows route legs instead of teleporting")
	var fake:=RefCounted.new()
	fake.set_meta("clock",480)
	# Building shifts are checked against the real operating model, not a visual mock.
	var model:=preload("res://src/core/resort.gd").new()
	model.new_game(false)
	check(Ops.building_shifts(model,"first_aid")==["day","evening","night"],"Piste rescue can staff night shifts")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
