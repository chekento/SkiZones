extends RefCounted
## SkiZones 0.40: read-only operational intelligence from the real simulation.
## This is intentionally NOT added to the save schema. Every result is rebuilt
## from current guests, installed lifts and staffed operations when requested.
const Ops = preload("res://src/core/operations.gd")

static func inspect(model: RefCounted) -> Dictionary:
	var active: bool=Ops.active(model)
	var visitors: int=model.present_guests()
	var waiting: int=model.queue_size()
	var lift_rows: Array=[]
	var alerts: Array=[]
	var fault_count:=0
	var crew_gaps:=0
	var running:=0
	for lift in model.lifts:
		var id: int=int(lift.id)
		var queued: int=model.queue_size(id)
		var fault: bool=str(lift.get("fault",""))!=""
		var crew: Dictionary=Ops.staffing(model,lift) if active else {"ok":true,"present":0,"needed":0}
		var shortage: int=maxi(0,int(crew.needed)-int(crew.present)) if active else 0
		var open: bool=model.lift_running(lift)
		var severity:=0
		if fault:
			fault_count+=1
			severity=3
		elif shortage>0:
			crew_gaps+=1
			severity=2
		elif queued>=12:
			severity=2
		elif queued>=6:
			severity=1
		if open:running+=1
		var row: Dictionary={"id":id,"name":str(lift.get("name","Lift %d"%id)),"queue":queued,"fault":fault,"missing":shortage,"present":int(crew.present),"needed":int(crew.needed),"running":open,"severity":severity}
		lift_rows.append(row)
		if fault:
			alerts.append({"severity":3,"kind":"fault","asset":id,"title":"Liftstörung","detail":row.name})
		elif shortage>0:
			alerts.append({"severity":2,"kind":"crew","asset":id,"title":"Liftpersonal fehlt","detail":row.name+" · %d unbesetzt"%shortage})
		if queued>=12:
			alerts.append({"severity":2 if queued>=24 else 1,"kind":"queue","asset":id,"title":"Warteschlange am Lift","detail":row.name+" · %d Personen"%queued})
	var cold:=0
	var hungry:=0
	var bathroom:=0
	var low_energy:=0
	for guest in model.guests:
		if str(guest.get("phase",""))=="leaving":continue
		var number: int=maxi(1,int(guest.get("group_size",1)))
		var needs: Dictionary=guest.get("needs",{})
		if needs.is_empty():continue
		if float(needs.get("warmth",100))<35:cold+=number
		if float(needs.get("hunger",100))<30:hungry+=number
		if float(needs.get("bladder",0))>=75:bathroom+=number
		if float(needs.get("energy",100))<25:low_energy+=number
	var threshold: int=maxi(3,ceili(float(visitors)*0.2))
	if cold>=threshold:
		alerts.append({"severity":2,"kind":"warmth","asset":-1,"title":"Gäste frieren","detail":"%d Personen brauchen Wärme"%cold})
	if hungry>=threshold:
		alerts.append({"severity":2,"kind":"food","asset":-1,"title":"Gäste brauchen Verpflegung","detail":"%d Personen sind hungrig"%hungry})
	if bathroom>=threshold:
		alerts.append({"severity":2,"kind":"wc","asset":-1,"title":"Sanitäre Versorgung gefragt","detail":"%d Personen suchen eine Toilette"%bathroom})
	if active and fault_count>0 and int(model.operations.get("parts",0))<=0:
		alerts.append({"severity":3,"kind":"parts","asset":-1,"title":"Ersatzteile fehlen","detail":"Defekte Lifte benötigen Ersatzteile"})
	alerts.sort_custom(func(a,b):return int(a.severity)>int(b.severity) if int(a.severity)!=int(b.severity) else str(a.title)<str(b.title))
	lift_rows.sort_custom(func(a,b):return int(a.severity)>int(b.severity) if int(a.severity)!=int(b.severity) else int(a.queue)>int(b.queue))
	return {"visitors":visitors,"waiting":waiting,"running_lifts":running,"total_lifts":model.lifts.size(),"faults":fault_count,"crew_gaps":crew_gaps,"cold":cold,"hungry":hungry,"bathroom":bathroom,"low_energy":low_energy,"reputation":float(model.reputation),"money":float(model.money),"temperature":float(model.weather().get("temperature",0)),"wind":float(model.weather().get("wind",0)),"active":active,"lifts":lift_rows,"alerts":alerts}
