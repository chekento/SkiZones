extends RefCounted
## Optional persistent room operations. Reading a legacy hotel never mutates it.
const Catalog = preload("res://src/core/catalog.gd")
const Terrain = preload("res://src/core/terrain.gd")
const L = preload("res://src/core/i18n.gd")
const MAX_ROOMS := 240
const CLEAN_COST := 8
const MOVE_COST := 250
static func capacity(building: Dictionary) -> int:
	return int(Catalog.LODGING.get(str(building.get("kind","")),{}).get("rooms",0))*int(building.get("level",1))
static func _extend(state: Dictionary, building: Dictionary) -> void:
	while state.rooms.size()<capacity(building):
		var position := 0
		while state.rooms.any(func(r):return int(r.floor)==position/12 and int(r.slot)==position%12): position+=1
		state.rooms.append({"id":state.rooms.size()+1,"floor":position/12,"slot":position%12,"clean":true,"closed":false,"reservation":""})
static func _state(model: RefCounted, building: Dictionary) -> Dictionary:
	var state: Dictionary=building.get("room_operations",{"version":1,"rooms":[],"last_service":model.Ops.clock(model)}).duplicate(true)
	_extend(state,building)
	return state
static func _people(model: RefCounted, id: int) -> Dictionary:
	var people: Dictionary={}
	for guest in model.guests:
		if int(guest.get("lodging_id",0))!=id or guest.phase=="leaving" or guest.get("portal_departing",false): continue
		var key: String=("party:%d"%int(guest.party_id)) if guest.has("party_id") else ("guest:%d"%int(guest.id))
		people[key]=int(people.get(key,0))+maxi(1,int(guest.get("group_size",1)))
	return people
static func _reconcile(model: RefCounted, building: Dictionary, state: Dictionary) -> int:
	_extend(state,building)
	var people: Dictionary=_people(model,int(building.id))
	var remaining: Dictionary={}
	for key in people: remaining[key]=ceili(float(people[key])/2.0)
	for room in state.rooms:
		var owner: String=str(room.reservation)
		if owner.begins_with("guest:") and people.has(owner.replace("guest:","party:")) and not people.has(owner):
			owner=owner.replace("guest:","party:"); room.reservation=owner
		if owner=="": continue
		if int(remaining.get(owner,0))>0:
			remaining[owner]-=1
		else:
			room.reservation="";room.clean=false
	var owners: Array=remaining.keys();owners.sort()
	for owner in owners:
		for room in state.rooms:
			if int(remaining[owner])<=0: break
			if room.reservation=="" and room.clean and not room.closed:
				room.reservation=owner;remaining[owner]-=1
	var shortage := 0
	for count in remaining.values():shortage+=int(count)
	return shortage
static func view(model: RefCounted, building: Dictionary) -> Dictionary:
	var state := _state(model,building)
	var shortage := _reconcile(model,building,state)
	var result := {"enabled":building.has("room_operations"),"rooms":state.rooms,"occupied":0,"ready":0,"dirty":0,"closed":0,"unassigned":shortage}
	for room in state.rooms:
		if room.reservation!="": result.occupied+=1
		elif room.closed: result.closed+=1
		elif not room.clean: result.dirty+=1
		else: result.ready+=1
	return result
static func enable(model: RefCounted, id: int) -> Dictionary:
	var building: Dictionary=model.asset(id)
	if capacity(building)<=0:return model._result(false,L.text("Eine eigene Unterkunft wählen."))
	if building.has("room_operations"):return model._result(false,L.text("Die Einzelzimmerverwaltung ist bereits aktiv."))
	building.room_operations=_state(model,building)
	_reconcile(model,building,building.room_operations)
	return model._result(true,L.text("Einzelzimmerverwaltung aktiviert. Vorhandene Urlaubsgäste behalten ihre Buchung."))
static func reconcile(model: RefCounted, building: Dictionary) -> void:
	if building.has("room_operations"):_reconcile(model,building,building.room_operations)
static func available(model: RefCounted, building: Dictionary) -> int:
	if not building.get("enabled",false):return 0
	return int(view(model,building).ready) if building.has("room_operations") else model.Lodging.room_count(building)-model.Lodging.rooms_used(model,int(building.id))
static func _room(model: RefCounted, building: Dictionary, id: int) -> Dictionary:
	if not building.has("room_operations"):return {}
	reconcile(model,building)
	for room in building.room_operations.rooms:
		if int(room.id)==id:return room
	return {}
static func clean_room(model: RefCounted, id: int, room_id: int) -> Dictionary:
	var room := _room(model,model.asset(id),room_id)
	if room.is_empty():return model._result(false,L.text("Zimmer nicht gefunden."))
	if room.reservation!="":return model._result(false,L.text("Das Zimmer ist noch belegt. Die Buchung bleibt erhalten."))
	if room.clean:return model._result(false,L.text("Dieses Zimmer ist bereits sauber."))
	if not model.Ops._expense(model,CLEAN_COST,"supplies:%d"%id):return model._result(false,L.text("Das Budget reicht für die Zimmerreinigung noch nicht."))
	room.clean=true
	return model._result(true,L.text("Zimmer gereinigt. Freigegebene Zimmer sind wieder buchbar."))
static func cleaning_quote(model: RefCounted, building: Dictionary) -> int:
	var quote := 0
	for room in view(model,building).rooms:
		if room.reservation=="" and not room.clean:quote+=CLEAN_COST
	return quote
static func clean_all(model: RefCounted, id: int) -> Dictionary:
	var building: Dictionary=model.asset(id)
	if not building.has("room_operations"):return model._result(false,L.text("Einzelzimmerverwaltung zuerst aktivieren."))
	reconcile(model,building)
	var cost := cleaning_quote(model,building)
	if cost==0:return model._result(false,L.text("Alle freien Zimmer sind bereits sauber."))
	if not model.Ops._expense(model,cost,"supplies:%d"%id):return model._result(false,L.text("Das Budget reicht für die Zimmerreinigung noch nicht."))
	for room in building.room_operations.rooms:
		if room.reservation=="":room.clean=true
	var settings: Dictionary=model.Hospitality.config(building);settings.cleanliness=100.0;building.hotel=settings
	return model._result(true,L.text("Freie Zimmer gereinigt; belegte Zimmer bleiben unverändert."))
static func set_closed(model: RefCounted, id: int, room_id: int, closed: bool) -> Dictionary:
	var room := _room(model,model.asset(id),room_id)
	if room.is_empty():return model._result(false,L.text("Zimmer nicht gefunden."))
	if room.reservation!="":return model._result(false,L.text("Das Zimmer ist noch belegt. Die Buchung bleibt erhalten."))
	room.closed=closed
	return model._result(true,L.text("Zimmersperre aktualisiert."))
static func move_room(model: RefCounted, id: int, room_id: int, floor_value: int, slot: int) -> Dictionary:
	var building: Dictionary=model.asset(id)
	var room := _room(model,building,room_id)
	if room.is_empty():return model._result(false,L.text("Zimmer nicht gefunden."))
	if room.reservation!="":return model._result(false,L.text("Das Zimmer ist noch belegt. Die Buchung bleibt erhalten."))
	if floor_value<0 or floor_value>19 or slot<0 or slot>35:return model._result(false,L.text("Ungültige Zimmerposition."))
	if int(room.floor)==floor_value and int(room.slot)==slot:return model._result(false,L.text("Das Zimmer liegt bereits an dieser Position."))
	if building.room_operations.rooms.any(func(r):return int(r.floor)==floor_value and int(r.slot)==slot):return model._result(false,L.text("An dieser Position liegt bereits ein Zimmer."))
	if not model._spend(MOVE_COST):return model._result(false,L.text("Für den internen Umbau fehlen 250 €."))
	room.floor=floor_value;room.slot=slot
	return model._result(true,L.text("Zimmer im internen Etagenplan versetzt."))
static func tick(model: RefCounted) -> void:
	for building in model.buildings:
		if not building.has("room_operations"):continue
		reconcile(model,building)
		var state: Dictionary=building.room_operations
		var now: int=model.Ops.clock(model)
		if now-int(state.last_service)<15:continue
		state.last_service=now
		if not building.enabled or not model.Hospitality.config(building).auto_clean or not model.Ops.building_staffed(model,building):continue
		var team := 0
		for person in model.operations.staff:
			if person.assignment=="building:%d"%int(building.id) and person.role in ["hotel","security","housekeeping"] and model.Ops.on_duty(model,person):team+=1
		# Self-check-in units use the contracted cleaning already in upkeep.
		if model.Ops.building_roles(str(building.kind)).is_empty():team=1
		for room in state.rooms:
			if team<=0:break
			if room.reservation=="" and not room.clean:room.clean=true;team-=1
static func _integer(value: Variant, low: int, high: int) -> bool:
	return Terrain.number(value) and value==floorf(float(value)) and value>=low and value<=high
static func valid(building: Dictionary) -> bool:
	if not building.has("room_operations"):return true
	var state: Variant=building.room_operations
	if capacity(building)<=0 or not state is Dictionary or state.size()!=3 or not _integer(state.get("version"),1,1) or not _integer(state.get("last_service"),0,144001440):return false
	if not state.get("rooms") is Array or state.rooms.is_empty() or state.rooms.size()>mini(MAX_ROOMS,capacity(building)):return false
	var positions: Dictionary={}
	for i in range(state.rooms.size()):
		var room: Variant=state.rooms[i]
		if not room is Dictionary or room.size()!=6 or not _integer(room.get("id"),i+1,i+1) or not _integer(room.get("floor"),0,19) or not _integer(room.get("slot"),0,35):return false
		if not room.get("clean") is bool or not room.get("closed") is bool or not room.get("reservation") is String:return false
		var owner: String=room.reservation
		if owner!="":
			var parts := owner.split(":")
			if parts.size()!=2 or parts[0] not in ["guest","party"] or not parts[1].is_valid_int() or str(int(parts[1]))!=parts[1] or int(parts[1])<1 or int(parts[1])>1000000000 or not room.clean or room.closed:return false
		var position: int=int(room.floor)*36+int(room.slot)
		if positions.has(position):return false
		positions[position]=true
	return true
