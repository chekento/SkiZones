extends SceneTree
## 0.40 venue profession, instructor booking, single/group lessons and safe
## optional save fields. No Samsung player data are accessed by this test.
const Resort=preload("res://src/core/resort.gd")
const Ops=preload("res://src/core/operations.gd")
const Recruit=preload("res://src/core/recruitment.gd")
const Lessons=preload("res://src/core/ski_lessons_040.gd")
const Catalog=preload("res://src/core/catalog.gd")
var passed:=0
var failed:=0
func check(ok:bool,message:String)->void:
	if ok:passed+=1;print("PASS ",message)
	else:failed+=1;push_error("FAIL "+message)
func _init()->void:call_deferred("run")
func run()->void:
	var model:=Resort.new()
	model.new_game(false,20261109)
	Ops.enable(model)
	model.minute=600
	model.money=3000000.0
	var school:Dictionary={"id":987,"kind":"school","enabled":true,"point":[40,150],"level":1}
	var restaurant:Dictionary={"id":988,"kind":"restaurant","enabled":true,"point":[50,150],"level":1}
	var rental:Dictionary={"id":989,"kind":"rental","enabled":true,"point":[60,150],"level":1}
	model.buildings.append_array([school,restaurant,rental])
	check(Ops.optional_roles("school")==["instructor"],"Skischule only offers ski instructors, never hotel service")
	check(Ops.optional_roles("restaurant")==["chef","waiter"],"Restaurant only offers chefs and waiters")
	check(Ops.optional_roles("rental")==["equipment_fitter"],"Ski rental only offers qualified equipment fitters")
	check(Ops.optional_roles("fitness")==["trainer"],"Fitness only offers fitness trainers")
	var all_correct:=true
	for kind in Catalog.BUILDINGS:
		for role in Ops.optional_roles(kind):
			if not Ops.role_matches_building(role,kind):all_correct=false
	check(all_correct,"Every OPTIONAL position in the building catalogue is a valid role for its venue")
	check(Recruit.FACILITIES.instructor==["school"],"Instructor applicants require an actual ski school")
	check(not Ops.hire(model,"hotel","building:987").ok,"Cannot hire hotel staff into a ski school")
	check(not Ops.hire(model,"instructor","building:988").ok,"Cannot hire instructors as restaurant staff")
	check(Lessons.qualified(model,school).is_empty(),"An unstaffed school cannot invent instructors")
	var solo:Dictionary={"id":701,"group_size":1}
	var group:Dictionary={"id":702,"group_size":5}
	var too_many:Dictionary={"id":703,"group_size":7}
	model.guests.append_array([solo,group,too_many])
	check(not Lessons.book(model,solo,school).ok,"Course cannot start without an employed on-duty instructor")
	check(Ops.hire(model,"instructor","building:987").ok,"A trained ski instructor is hired at the right building")
	check(Lessons.available(model,school).size()==1,"One on-duty instructor provides one course capacity")
	var single:Dictionary=Lessons.book(model,solo,school)
	check(single.ok and single.lesson.mode=="single" and single.lesson.students==1,"One qualified teacher escorts one individual student")
	check(not Lessons.book(model,group,school).ok,"A busy instructor cannot be double-booked for a simultaneous group")
	check(not Lessons.book(model,too_many,school).ok,"One instructor may not supervise an unsafe group of seven")
	check(Ops.hire(model,"instructor","building:987").ok,"Second instructor increases real simultaneous course capacity")
	var group_booking:Dictionary=Lessons.book(model,group,school)
	check(group_booking.ok and group_booking.lesson.mode=="group" and group_booking.lesson.students==5,"One teacher supervises a real five-person group")
	check(group_booking.ok and int(group_booking.lesson.staff)!=int(single.lesson.staff),"Concurrent solo and group sessions use different actual employees")
	check(not Lessons.active(model,solo).is_empty() and not Lessons.active(model,group).is_empty(),"Booked instructors are retrieved from live assigned staff")
	check(Lessons.valid(solo.ski_lesson) and Lessons.valid(group.ski_lesson),"Lesson metadata is finite and safe for JSON saves")
	check(not Lessons.valid({"school":987,"staff":1,"mode":"group","students":700,"remaining":1}),"Malformed/overbooked historical lesson data is rejected without affecting save loads")
	Lessons.finish_descent(solo)
	check(not solo.has("ski_lesson") and Lessons.available(model,school).size()==1,"Completed downhill run releases its instructor immediately")
	var fired_id:int=int(group.ski_lesson.staff)
	check(Ops.dismiss(model,fired_id).ok and Lessons.active(model,group).is_empty(),"Dismissed employee cannot appear as a phantom instructor NPC")
	Lessons.finish_descent(group)
	check(not group.has("ski_lesson"),"Course finishes without charging repeated visits or perpetual escort")
	print("SKI INSTRUCTOR 040: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
