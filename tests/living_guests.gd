extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Life=preload("res://src/core/guest_life.gd")
const School=preload("res://src/core/ski_school.gd")
const Ops=preload("res://src/core/operations.gd")
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func run() -> void:
	var model:=Resort.new();model.new_game(true);Ops.enable(model);model.enable_runtime_rules();model.enable_life_rules();model.money=3000000
	check(model.build_building("school",Vector2(155,300)).ok,"A real ski school fits the connected village")
	var school: Dictionary=model.buildings[-1]
	check(Ops.fill_building(model,int(school.id)).ok and Ops.building_open(model,school),"The school's own instructor works the actual day shift")
	for i in range(3):
		check(model.admit_guest(0,"blue"),"Real individual pupil admitted")
		var guest: Dictionary=model.guests[-1];Life.ensure(guest);guest.life.wallet=80;guest.stay=1000;guest.needs.lesson=true;guest.needs.hunger=0;guest.needs.warmth=95;guest.needs.energy=95
		var route: Dictionary=guest.route if School.enrolled(guest) else model.service_route(guest)
		check(not route.is_empty() and School.enrolled(guest),"Pupil books a shared scheduled group through an actual route")
		if not route.is_empty():guest.route=route;guest.leg=0;model._start_leg(guest)
	check(model.school_state.courses.size()==1 and model.school_state.courses[0].students.size()==3,"Three reservations share one daily group and meeting point")
	if model.school_state.courses.is_empty():quit(1);return
	for i in range(90*24):model.advance_minute(false)
	var item: Dictionary=model.school_state.courses[0]
	check(item.status=="active" and item.teacher>0,"The course starts at 09:30 with an actual instructor actor")
	check(model.guests.any(func(g):return g.get("school_teacher",false) and int(g.years)>=18),"The instructor is an adult individual riding in the same physical world")
	check(school.revenue==180 and model.school_state.income==180,"Only the three present pupils pay the quoted group tuition")
	for i in range(265*24):model.advance_minute(false)
	check(item.status=="completed","The group finishes at a real network node after its four-hour course")
	check(model.guests.filter(func(g):return not g.get("school_teacher",false)).all(func(g):return g.life.tuition_minutes>0 and g.life.skill_xp>0),"Actual skiing and instruction create persistent skill progress")
	var saved:=model.snapshot()
	FileAccess.open("res://build/living-save.json",FileAccess.WRITE).store_string(JSON.stringify(saved))
	var copy:=Resort.new();var restored:=copy.restore(JSON.parse_string(JSON.stringify(saved)))
	check(restored.ok,"Lessons and guest learning survive JSON save validation: "+restored.message)
	var pupil: Dictionary={"id":81,"ability":1,"phase":"moving","needs":{"energy":95},"sport":"snowboard","loops":0};Life.ensure(pupil)
	for kind in Life.STAYS:
		var range_value: Array=Life.STAYS[kind];var value:=Life.visit_minutes(pupil,{"id":42,"kind":kind})
		check(value>=range_value[0] and value<=range_value[1],kind+" uses the requested personal calendar stay")
	var switched:=false
	for id in range(1,40):
		pupil.id=id;pupil.erase("life");Life.ensure(pupil)
		for percent in range(12,89):switched=switched or Life.pose(pupil,{"grade":15},percent/100.0,false).switch
	check(switched,"Experienced guests sometimes ride switch on a suitable gentle descent")
	check(not Life.pose(pupil,{"grade":65},0.5,false).switch and not Life.pose(pupil,{"grade":15},0.5,true).switch,"Steep slopes and hiking suppress switch tricks")
	print("LIVING GUESTS: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
