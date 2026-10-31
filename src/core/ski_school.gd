extends RefCounted
## Real scheduled lessons. Students travel, meet, ride lifts and learn on snow.
const L=preload("res://src/core/i18n.gd")
const Life=preload("res://src/core/guest_life.gd")
const Terrain=preload("res://src/core/terrain.gd")
const Foot=preload("res://src/core/foot_network.gd")
static func initial() -> Dictionary:return {"next_id":1,"courses":[],"settings":{},"completed":0,"income":0.0}
static func now(model: RefCounted) -> int:return (model.day-1)*1440+model.minute
static func course(model: RefCounted,id: int) -> Dictionary:
	for item in model.school_state.courses:
		if int(item.id)==id:return item
	return {}
static func actor(model: RefCounted,id: int) -> Dictionary:
	for guest in model.guests:
		if int(guest.id)==id:return guest
	return {}
static func enrolled(guest: Dictionary) -> bool:return int(guest.get("lesson_course",0))>0
static func settings(model: RefCounted,id: int) -> Dictionary:
	return model.school_state.settings.get(str(id),{"start":570,"minutes":240,"group_price":60.0,"private_hour":95.0})
static func configure(model: RefCounted,id: int,start: int,duration: int,price: float) -> Dictionary:
	if model.asset(id).get("kind")!="school" or start<510 or start>660 or duration not in [240,360] or price<30 or price>180:return model._result(false,L.text("Diese Kursplanung ist nicht möglich."))
	for item in model.school_state.courses:
		if int(item.school)==id and item.day==model.day and not item.students.is_empty() and item.status in ["booking","active"]:return model._result(false,L.text("Bereits gebuchte Kurse behalten ihre Zeit. Änderungen sind nach Kursende möglich."))
	model.school_state.settings[str(id)]={"start":start,"minutes":duration,"group_price":price,"private_hour":95.0}
	return model._result(true,L.text("Kursangebot aktualisiert. Treffpunkt und Startzeit stehen bei den Buchungen."))
static func _meeting(model: RefCounted,school: Dictionary,level: int) -> String:
	var graph: Dictionary=model._routing_graph(level,true)
	var origin: String="d%d" % int(school.id)
	var best:=INF;var result: String=""
	for lift in model.lifts:
		if not model.lift_open(lift):continue
		var key: String="l%db" % int(lift.id)
		var route: Dictionary=model._shortest(graph,origin,key)
		if not route.ok:continue
		var accessible: bool=model.routes_for(level).any(func(r):return r.legs.any(func(leg):return leg.kind=="lift" and int(leg.id)==int(lift.id)))
		if accessible and model.route_minutes(route)<best:best=model.route_minutes(route);result=key
	return result
static func _create(model: RefCounted,school: Dictionary,level: int,private_lesson: bool,guest: Dictionary) -> Dictionary:
	if model.school_state.courses.size()>=96:return {}
	var config:=settings(model,int(school.id));var time:=now(model)
	var start: int=(model.day-1)*1440+int(config.start)
	var duration: int=config.minutes
	var fee: float=config.group_price
	if private_lesson:
		start=ceili((time+15)/15.0)*15
		duration=60 if int(guest.id)%3!=0 else 240
		fee=float(config.private_hour)*(1.0 if duration==60 else 3.2)
	elif start<time+10:return {}
	if start+duration>(model.day-1)*1440+1020:return {}
	var meeting:=_meeting(model,school,level)
	if meeting=="":return {}
	var item: Dictionary={"id":model.school_state.next_id,"school":int(school.id),"day":model.day,"start":start,"end":start+duration,"minutes":duration,"price":fee,"private":private_lesson,"level":level,"meeting":meeting,"students":[],"present":{},"teacher":0,"employee":0,"status":"booking","node_since":start,"route":{},"active_minutes":0}
	model.school_state.next_id+=1;model.school_state.courses.append(item)
	return item
static func enrol_route(model: RefCounted,guest: Dictionary,source: String,school: Dictionary) -> Dictionary:
	if enrolled(guest) or guest.get("school_teacher",false) or not model.Ops.building_open(model,school):return {}
	Life.ensure(guest)
	if guest.life.lesson_count>0 and guest.life.skill_xp<60 and not guest.needs.lesson:return {}
	var level:=mini(1,int(guest.ability))
	var time:=now(model)
	var private_lesson: bool=guest.life.wallet>=200 and int(guest.id)%4==0 and guest.get("years",25)>=16
	var item: Dictionary={}
	if not private_lesson:
		for existing in model.school_state.courses:
			if existing.school==school.id and existing.day==model.day and not existing.private and existing.level==level and existing.status=="booking" and existing.students.size()<20 and existing.start>time+10:item=existing;break
	if item.is_empty():item=_create(model,school,level,private_lesson,guest)
	if item.is_empty() or guest.life.wallet<float(item.price):return {}
	var graph: Dictionary=model._routing_graph(model.Agenda.comfort(guest),true)
	var target: String="d%d" % int(school.id)
	var path: Dictionary=model._shortest(graph,source,target)
	var to_meeting: Dictionary=model._shortest(graph,target,item.meeting)
	if not path.ok or not to_meeting.ok:return {}
	var travel: float=model.route_minutes(path,guest)+model.route_minutes(to_meeting,guest)+5
	if now(model)+travel>item.start+5 or guest.age+travel+item.minutes>guest.stay:return {}
	var at: Array=Terrain.pack(Foot.door(school))
	var pause: Dictionary=model._edge(target,target,"visit",int(school.id),[at,at],5*model.time_divisor)
	pause.pause_only=true;pause.school_registration=int(item.id)
	guest.lesson_course=int(item.id);guest.school_stage="registration"
	if not item.students.has(int(guest.id)):item.students.append(int(guest.id))
	return {"target":0,"origin":graph.nodes[source],"legs":path.legs+[pause]}
static func _wait(model: RefCounted,guest: Dictionary,node: String,reason: String) -> void:
	guest.phase="waiting";guest.waiting_node=node;guest.waiting_reason=reason;guest.waiting_since=now(model)
static func arrive(model: RefCounted,guest: Dictionary,leg: Dictionary) -> bool:
	if not enrolled(guest):return false
	var item:=course(model,int(guest.lesson_course))
	if item.is_empty():guest.erase("lesson_course");return false
	if item.status=="booking":
		if guest.get("school_stage","")=="registration" and leg.get("school_registration",0)==item.id:
			var graph: Dictionary=model._routing_graph(model.Agenda.comfort(guest),true)
			var route: Dictionary=model._shortest(graph,leg.to,item.meeting)
			if not route.ok:cancel_student(model,guest,leg.to);return true
			guest.school_stage="meeting"
			if route.legs.is_empty():_wait(model,guest,item.meeting,"lesson_meeting")
			else:guest.route={"target":0,"origin":graph.nodes[leg.to],"legs":route.legs};guest.leg=0;model._start_leg(guest)
			return true
		if guest.get("school_stage","")=="meeting" and leg.to==item.meeting:
			_wait(model,guest,item.meeting,"lesson_meeting");item.present[str(int(guest.id))]=item.meeting;return true
		return false
	if item.status=="active":
		_wait(model,guest,leg.to,"lesson_group");item.present[str(int(guest.id))]=leg.to
		_release_node(model,item)
		return true
	return false
static func cancel_student(model: RefCounted,guest: Dictionary,node: String) -> void:
	var item:=course(model,int(guest.get("lesson_course",0)))
	if not item.is_empty():item.students.erase(int(guest.id));item.present.erase(str(int(guest.id)))
	guest.erase("lesson_course");guest.erase("school_stage")
	model._return_from_node(guest,node)
static func _members(model: RefCounted,item: Dictionary) -> Array:
	return model.guests.filter(func(g):return int(g.get("lesson_course",0))==int(item.id) and g.phase!="leaving")
static func _employee(model: RefCounted,item: Dictionary) -> int:
	for person in model.operations.staff:
		if person.role!="instructor" or person.assignment!="building:%d" % int(item.school) or not model.Ops.on_duty(model,person):continue
		if model.school_state.courses.any(func(c):return c.status=="active" and c.employee==person.id):continue
		return int(person.id)
	return 0
static func _teacher(model: RefCounted,item: Dictionary,pupil: Dictionary,employee: int) -> Dictionary:
	if model.guests.size()>=model.MAX_GUESTS:return {}
	var guide: Dictionary=pupil.duplicate(true)
	for key in ["party_id","guardian_id","party_comfort","party_step","school_rejoin"]:guide.erase(key)
	guide.id=model.guest_id;model.guest_id+=1;guide.school_teacher=true;guide.ability=item.level
	guide.years=27+employee%25
	guide.needs={"hunger":0.0,"warmth":95.0,"energy":95.0,"joy":95.0,"rental":false,"lesson":false}
	guide.person_name=L.text("Skilehrer · Team %d") % employee
	guide.ticket_paid=0.0;guide.spending=0.0;guide.life.wallet=1000.0;guide.sport=pupil.sport
	guide.group_size=1;guide.stay=maxi(int(guide.stay),int(guide.age)+600);guide.phase="waiting"
	guide.agenda.comfort=item.level;guide.lesson_course=item.id
	model.guests.append(guide);return guide
static func _route(model: RefCounted,item: Dictionary,node: String) -> bool:
	var guide:=actor(model,int(item.teacher))
	if guide.is_empty():return false
	var proxy: Dictionary=guide.duplicate(true)
	proxy.group_size=_members(model,item).size()
	for pupil in _members(model,item):
		proxy.needs.hunger=maxf(proxy.needs.hunger,pupil.needs.hunger)
		proxy.needs.warmth=minf(proxy.needs.warmth,pupil.needs.warmth)
		proxy.needs.energy=minf(proxy.needs.energy,pupil.needs.energy)
	var next: Dictionary=model.service_route(proxy,node) if model.Needs.urgent(proxy) else {}
	if not next.is_empty() and model.route_minutes(next,guide)>float(item.end-now(model))-15:next={}
	if next.is_empty():next=model.choose_route(guide,node)
	if next.is_empty():return false
	item.route=next;item.present.clear();item.node_since=now(model)
	for guest in _members(model,item):
		guest.route=next.duplicate(true);guest.leg=0;guest.school_stage="training";model._start_leg(guest)
	return true
static func _start(model: RefCounted,item: Dictionary) -> void:
	var ready: Array=[]
	for id in item.students:
		var guest:=actor(model,int(id))
		if guest.is_empty():continue
		if guest.phase=="waiting" and guest.get("waiting_node","")==item.meeting:ready.append(guest)
	if ready.is_empty():return
	var employee:=_employee(model,item)
	if employee==0:return
	var guide:=_teacher(model,item,ready[0],employee)
	if guide.is_empty():return
	item.teacher=int(guide.id);item.employee=employee;item.status="active"
	var accepted: Array=[]
	for guest in ready:
		if guest.life.wallet<item.price:guest.erase("lesson_course");continue
		accepted.append(int(guest.id));guest.life.wallet-=item.price;guest.life.lesson_count+=1
		guest.spending+=item.price;guest.needs.lesson=false;guest.school_fee=float(item.price)
		var building: Dictionary=model.asset(int(item.school));building.revenue+=item.price;building.visits+=1
		model.money+=item.price;model.report.services+=item.price;model.campaign.turnover+=item.price
		model.Agenda.record_service(model,guest,"school",item.price);model.school_state.income+=item.price
	for id in item.students.duplicate():
		if not accepted.has(int(id)):
			var missed:=actor(model,int(id))
			if not missed.is_empty():cancel_student(model,missed,str(missed.route.legs[missed.leg].to))
	item.students=accepted
	if not _route(model,item,item.meeting):_finish(model,item,item.meeting,true)
static func _release_node(model: RefCounted,item: Dictionary) -> void:
	var people:=_members(model,item)
	var guide:=actor(model,int(item.teacher))
	if people.is_empty() or guide.is_empty() or guide.phase!="waiting":return
	var node: String=guide.get("waiting_node","")
	if not people.all(func(g):return g.phase=="waiting" and g.get("waiting_node","")==node):return
	if now(model)>=int(item.end):_finish(model,item,node,false);return
	item.present.clear();item.node_since=now(model)
	if int(guide.leg)+1>=guide.route.legs.size():
		if not _route(model,item,node):_finish(model,item,node,true)
		return
	for guest in people:guest.leg+=1;model._start_leg(guest)
static func _finish(model: RefCounted,item: Dictionary,node: String,cancelled: bool) -> void:
	item.status="cancelled" if cancelled else "completed"
	if not cancelled:model.school_state.completed+=1
	for guest in _members(model,item):
		guest.erase("lesson_course");guest.erase("school_stage")
		if guest.get("school_teacher",false):
			guest.phase="leaving";continue
		guest.needs.joy=clampf(guest.needs.joy+(8 if not cancelled else -10),0,100)
		if cancelled and guest.has("school_fee"):
			var fraction:=clampf(float(item.end-now(model))/maxf(1,item.minutes),0,1)
			var refund: float=guest.school_fee*fraction;guest.life.wallet+=refund;guest.spending-=refund
			model.money-=refund;model.report.services=maxf(0,model.report.services-refund)
			var school: Dictionary=model.asset(int(item.school));school.revenue=maxf(0,school.revenue-refund)
		guest.erase("school_fee")
		if guest.has("party_id"):
			var party: Dictionary=model.Parties.group(model,guest)
			if not party.is_empty():party.meeting_at=now(model)+10
		model._return_from_node(guest,node)
static func tick(model: RefCounted,calendar_tick: bool) -> void:
	if not model.life_enabled:return
	var time:=now(model)
	for item in model.school_state.courses:
		if item.status=="booking":
			if time>=item.start and time<=item.start+15:_start(model,item)
			elif time>item.start+15:
				item.status="missed"
				for id in item.students.duplicate():
					var guest:=actor(model,int(id))
					if not guest.is_empty() and guest.phase=="waiting":cancel_student(model,guest,item.meeting)
		elif item.status=="active":
			var school: Dictionary=model.asset(int(item.school))
			var guide:=actor(model,int(item.teacher))
			if guide.is_empty():item.status="cancelled";continue
			var working: bool=model.Ops.building_open(model,school)
			if not working and guide.phase=="waiting":_finish(model,item,str(guide.waiting_node),true);continue
			if calendar_tick and working:
				for guest in _members(model,item):
					if guest.get("school_teacher",false) or guest.phase!="moving" or guest.route.legs[guest.leg].kind!="ski":continue
					guest.life.tuition_minutes+=1
					Life.learn(guest,1.5 if item.private else 0.55)
				item.active_minutes+=1
			_release_node(model,item)
	# Retain a bounded history. Future reservations and active courses stay intact.
	if model.school_state.courses.size()>80:
		model.school_state.courses=model.school_state.courses.filter(func(c):return c.status in ["booking","active"] or c.day>=model.day-2)
static func describe(model: RefCounted,guest: Dictionary) -> String:
	var item:=course(model,int(guest.get("lesson_course",0)))
	if item.is_empty():return ""
	return L.text("%s · %02d:%02d–%02d:%02d · Treffpunkt vor Lift %s") % [L.text("Einzelunterricht") if item.private else L.text("Gruppenkurs"),int(item.start)%1440/60,int(item.start)%60,int(item.end)%1440/60,int(item.end)%60,item.meeting.trim_prefix("l").trim_suffix("b")]
static func valid(model: RefCounted,value: Variant) -> bool:
	if not value is Dictionary or not value.get("courses") is Array or value.courses.size()>100 or not value.get("settings") is Dictionary:return false
	for key in ["next_id","completed","income"]:
		if not Terrain.number(value.get(key)) or value[key]<0 or value[key]>1000000000:return false
	if value.settings.size()>60:return false
	for key in value.settings:
		var config: Variant=value.settings[key]
		if not key is String or not key.is_valid_int() or model.asset(key.to_int()).get("kind")!="school" or not config is Dictionary:return false
		for field in ["start","minutes","group_price","private_hour"]:
			if not Terrain.number(config.get(field)):return false
		if config.start<510 or config.start>660 or config.minutes not in [240,360] or config.group_price<30 or config.group_price>180 or config.private_hour!=95:return false
	var ids: Array=[]
	for item in value.courses:
		if not item is Dictionary or not item.get("id") is float and not item.get("id") is int:return false
		if item.id<1 or item.id>=value.next_id or ids.has(item.id) or model.asset(int(item.get("school",0))).get("kind")!="school":return false
		ids.append(item.id)
		for key in ["day","start","end","minutes","price","level","teacher","employee","node_since","active_minutes"]:
			if not Terrain.number(item.get(key)) or item[key]<0 or item[key]>100000000:return false
		if item.level>1 or item.minutes not in [60,240,360] or item.end!=item.start+item.minutes or not item.get("private") is bool or item.get("status") not in ["booking","active","completed","cancelled","missed"]:return false
		if not item.get("meeting") is String or not item.meeting.begins_with("l") or not item.get("students") is Array or item.students.size()>(1 if item.private else 20) or not item.get("present") is Dictionary or not item.get("route") is Dictionary:return false
		for id in item.students:
			if not Terrain.number(id) or id<1 or id>=model.guest_id:return false
	return true
