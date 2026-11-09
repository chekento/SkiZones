extends RefCounted
## v0.40 – real, employed ski instructors accompany the next descent.
## Optional lesson field inside each existing guest dictionary; no save format
## bump and no phantom employed staff. Only a qualified, on-duty instructor
## assigned to the actual ski school can be booked, never hotel personnel.
const Ops=preload("res://src/core/operations.gd")
const MAX_GROUP:=6

static func students(guest: Dictionary, model: RefCounted=null) -> int:
	var count:int=maxi(1,int(guest.get("group_size",1)))
	if guest.get("family",[]) is Array:count=maxi(count,guest.get("family",[]).size())
	# Party mode physically splits families into separate guests. Preserve
	# one grouped course for those real members, not five fake instructors.
	if model!=null and int(guest.get("party_id",-1))>0:
		for party in model.parties:
			if int(party.get("id",-1))==int(guest.party_id):
				count=maxi(count,party.get("members",[]).size())
				break
	return count

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

static func _engaged(model: RefCounted, staff_id: int, visitor_id: int, group_id: int=-1) -> bool:
	for guest in model.guests:
		if int(guest.get("id",-1))==visitor_id:continue
		var lesson:Variant=guest.get("ski_lesson",{})
		if not valid(lesson) or int(lesson.staff)!=staff_id:continue
		if group_id>0 and int(guest.get("party_id",-1))==group_id:continue
		return true
	return false

static func available(model: RefCounted, school: Dictionary, guest: Dictionary={}) -> Array:
	var result: Array=[]
	var id:int=int(guest.get("id",-1))
	for person in qualified(model,school):
			if not _engaged(model,int(person.id),id,int(guest.get("party_id",-1))):result.append(person)
	return result

static func book(model: RefCounted, guest: Dictionary, school: Dictionary) -> Dictionary:
	var count:int=students(guest,model)
	if count>MAX_GROUP:return {"ok":false,"code":"group_too_large"}
	var existing:Variant=guest.get("ski_lesson",{})
	if valid(existing):return {"ok":false,"code":"already_booked"}
	# Members of a previously admitted real family share ONE instructor and
	# one class booking. A party may pay for each actual student, but cannot
	# consume (or visually clone) multiple instructors for the same class.
	var group_id:int=int(guest.get("party_id",-1))
	if group_id>0:
		for teammate in model.guests:
			if int(teammate.get("party_id",-1))!=group_id:continue
			var previous:Variant=teammate.get("ski_lesson",{})
			if valid(previous) and int(previous.school)==int(school.id):
				guest["ski_lesson"]=previous.duplicate(true)
				return {"ok":true,"lesson":guest.ski_lesson,"staff_name":"Kursleitung"}
	var teachers:Array=available(model,school,guest)
	if teachers.is_empty():return {"ok":false,"code":"no_available_instructor"}
	var instructor:Dictionary=teachers[0]
	var lesson:Dictionary={
		"school":int(school.id),"staff":int(instructor.id),
		"students":count,"mode":"single" if count==1 else "group","remaining":1,"party":group_id
	}
	guest["ski_lesson"]=lesson
	return {"ok":true,"lesson":lesson,"staff_name":str(instructor.get("name","Skilehrer"))}

static func active(model: RefCounted, guest: Dictionary) -> Dictionary:
	var lesson:Variant=guest.get("ski_lesson",{})
	if not valid(lesson):return {}
	# If the teacher is fired, reassigned, off shift, or the school closes,
	# no duplicate phantom skier may appear on the piste.
	var school:Dictionary=model.asset(int(lesson.school))
	# Exactly one visible escort for each split family, following the
	# physically skiing member with the smallest current guest ID.
	var party_id:int=int(guest.get("party_id",-1))
	if party_id>0:
		for other in model.guests:
			if int(other.get("party_id",-1))!=party_id or int(other.get("id",-1))>=int(guest.id):continue
			var other_lesson:Variant=other.get("ski_lesson",{})
			if not valid(other_lesson) or int(other_lesson.staff)!=int(lesson.staff):continue
			if str(other.get("phase",""))=="moving" and int(other.get("leg",-1))<other.get("route",{}).get("legs",[]).size() and other.route.legs[int(other.leg)].kind=="ski":return {}
	for person in qualified(model,school):
		if int(person.id)==int(lesson.staff):
			return {"staff":person,"lesson":lesson}
	return {}

static func finish_descent(guest: Dictionary) -> void:
	# A lesson includes exactly the next real run, then frees the teacher for
	# another individual or group. No repeated fees or eternal escort.
	guest.erase("ski_lesson")
