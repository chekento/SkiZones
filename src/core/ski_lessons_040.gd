extends RefCounted
## v0.40 – real, employed ski instructors accompany the next descent.
## Optional lesson field inside each existing guest dictionary; no save format
## bump and no phantom employed staff. Only a qualified, on-duty instructor
## assigned to the actual ski school can be booked, never hotel personnel.
const Ops=preload("res://src/core/operations.gd")
const MAX_GROUP:=6

static func students(guest: Dictionary) -> int:
	return maxi(1,int(guest.get("group_size",1)))

static func mode(guest: Dictionary) -> String:
	return "Einzelunterricht" if students(guest)==1 else "Gruppenkurs"

static func valid(lesson: Variant) -> bool:
	return lesson is Dictionary and int(lesson.get("school",0))>0 and int(lesson.get("staff",0))>0 and int(lesson.get("students",0))>=1 and int(lesson.get("students",0))<=MAX_GROUP and str(lesson.get("mode","")) in ["single","group"] and int(lesson.get("remaining",0))==1 and lesson.get("school") is int and lesson.get("staff") is int and lesson.get("students") is int and lesson.get("remaining") is int

static func qualified(model: RefCounted, school: Dictionary) -> Array:
	if school.is_empty() or str(school.get("kind",""))!="school" or not school.get("enabled",false):return []
	var result: Array=[]
	var assignment:String="building:%d" % int(school.id)
	for person in model.operations.staff:
		if str(person.get("role",""))=="instructor" and str(person.get("assignment",""))==assignment and Ops.on_duty(model,person):
			result.append(person)
	result.sort_custom(func(a:Dictionary,b:Dictionary):return int(a.id)<int(b.id))
	return result

static func _engaged(model: RefCounted, staff_id: int, visitor_id: int) -> bool:
	for guest in model.guests:
		if int(guest.get("id",-1))==visitor_id:continue
		var lesson:Variant=guest.get("ski_lesson",{})
		if valid(lesson) and int(lesson.staff)==staff_id:return true
	return false

static func available(model: RefCounted, school: Dictionary, guest: Dictionary={}) -> Array:
	var result: Array=[]
	var id:int=int(guest.get("id",-1))
	for person in qualified(model,school):
		if not _engaged(model,int(person.id),id):result.append(person)
	return result

static func book(model: RefCounted, guest: Dictionary, school: Dictionary) -> Dictionary:
	var count:int=students(guest)
	if count>MAX_GROUP:return {"ok":false,"code":"group_too_large"}
	var existing:Variant=guest.get("ski_lesson",{})
	if valid(existing):return {"ok":false,"code":"already_booked"}
	var teachers:Array=available(model,school,guest)
	if teachers.is_empty():return {"ok":false,"code":"no_available_instructor"}
	var instructor:Dictionary=teachers[0]
	var lesson:Dictionary={
		"school":int(school.id),"staff":int(instructor.id),
		"students":count,"mode":"single" if count==1 else "group","remaining":1
	}
	guest["ski_lesson"]=lesson
	return {"ok":true,"lesson":lesson,"staff_name":str(instructor.get("name","Skilehrer"))}

static func active(model: RefCounted, guest: Dictionary) -> Dictionary:
	var lesson:Variant=guest.get("ski_lesson",{})
	if not valid(lesson):return {}
	# If the teacher is fired, reassigned, off shift, or the school closes,
	# no duplicate phantom skier may appear on the piste.
	var school:Dictionary=model.asset(int(lesson.school))
	for person in qualified(model,school):
		if int(person.id)==int(lesson.staff):
			return {"staff":person,"lesson":lesson}
	return {}

static func finish_descent(guest: Dictionary) -> void:
	# A lesson includes exactly the next real run, then frees the teacher for
	# another individual or group. No repeated fees or eternal escort.
	guest.erase("ski_lesson")
