extends RefCounted
## Individuals share appointments, never a position, vehicle or movement timer.
const Terrain=preload("res://src/core/terrain.gd")
const Foot=preload("res://src/core/foot_network.gd")
const Agenda=preload("res://src/core/guest_agenda.gd")
const Needs=preload("res://src/core/guest_needs.gd")
static func now(model: RefCounted) -> int:return (model.day-1)*1440+model.minute
static func actor(model: RefCounted,id: int) -> Dictionary:
	for guest in model.guests:
		if int(guest.id)==id:return guest
	return {}
static func group(model: RefCounted,guest: Dictionary) -> Dictionary:
	for party in model.parties:
		if int(party.id)==int(guest.get("party_id",0)):return party
	return {}
static func members(model: RefCounted,party: Dictionary) -> Array:
	return model.guests.filter(func(g):return int(g.get("party_id",0))==int(party.id) and g.phase!="leaving")
static func cell(model: RefCounted,guest: Dictionary) -> Array:
	var guardian: int=int(guest.get("guardian_id",guest.id))
	return model.guests.filter(func(g):return int(g.get("party_id",0))==int(guest.get("party_id",-1)) and (int(g.id)==guardian or int(g.get("guardian_id",0))==guardian) and g.phase!="leaving")
static func care_guest(model: RefCounted,guest: Dictionary) -> Dictionary:
	if not guest.has("party_id"):return guest
	var copy:=guest.duplicate(true)
	var care:=cell(model,guest)
	copy.group_size=care.size()
	for person in care:
		copy.needs.hunger=maxf(copy.needs.hunger,person.needs.hunger)
		copy.needs.warmth=minf(copy.needs.warmth,person.needs.warmth)
		copy.needs.energy=minf(copy.needs.energy,person.needs.energy)
	return copy
static func expand(model: RefCounted,root: Dictionary,node: String="base") -> void:
	if not root.has("family") or root.has("party_id") or model.guests.size()+root.family.size()-1>model.MAX_GUESTS:return
	var people: Array=root.family.duplicate(true)
	# Guardians enter the actor list first, so their actual routes are available.
	people.sort_custom(func(a,b):return a.years>=16 and b.years<16)
	var id: int=int(root.id)
	var party: Dictionary={"id":id,"members":[],"meeting_at":(model.day-1)*1440+735,"node":"base","venue":0,"status":"free","round":0}
	if party.meeting_at<now(model)+30:party.meeting_at=now(model)+90
	var original:=root.duplicate(true);original.erase("family")
	var adults: Array=[];var additions: Array=[]
	for index in range(people.size()):
		var person: Dictionary=people[index]
		var guest: Dictionary=root if index==0 else original.duplicate(true)
		if index>0:guest.id=model.guest_id;model.guest_id+=1;additions.append(guest)
		guest.erase("family");guest.party_id=id;guest.person_name=person.name;guest.years=int(person.years)
		guest.ability=int(person.ability);guest.sport=model.Motion.sport_for(int(guest.id));guest.needs=person.needs.duplicate(true);guest.group_size=1
		guest.ticket_paid=float(original.get("ticket_paid",0))/people.size();guest.spending=float(original.get("spending",0))/people.size()
		guest.agenda=original.agenda.duplicate(true);guest.agenda.comfort=guest.ability
		guest.erase("ride_manifest");guest.erase("boarding_remaining");guest.erase("ride_car");guest.erase("ride_seat");guest.erase("ride_departure")
		if guest.years>=16:adults.append(int(guest.id))
		else:guest.guardian_id=adults[0]
		party.members.append(int(guest.id))
	model.guests.append_array(additions);model.parties.append(party)
	var all:=members(model,party)
	for parent in all:
		if parent.has("guardian_id"):continue
		parent.party_comfort=int(parent.ability)
		for child in cell(model,parent):parent.party_comfort=mini(parent.party_comfort,int(child.ability))
		var route: Dictionary=model.choose_route(care_guest(model,parent),node)
		if route.is_empty():model._return_from_node(parent,node)
		else:parent.route=route;parent.leg=0;model._start_leg(parent)
		for child in cell(model,parent):
			if int(child.id)==int(parent.id):continue
			child.party_comfort=parent.party_comfort;child.route=parent.route.duplicate(true);child.leg=int(parent.leg);model._start_leg(child)
static func pace(model: RefCounted,guest: Dictionary) -> float:
	if not guest.has("party_id") or guest.phase!="moving":return 1.0
	var leg: Dictionary=guest.route.legs[int(guest.leg)]
	if leg.kind not in ["walk","ski"]:return 1.0
	var factor:=1.0
	var position: Vector3=model.guest_position(guest)
	var next: Vector3=model.guest_position(guest,1.0,true)
	for other in cell(model,guest):
		if int(other.id)==int(guest.id) or other.phase!="moving":continue
		if guest.has("guardian_id") and int(other.id)!=int(guest.guardian_id):continue
		if not guest.has("guardian_id") and not other.has("guardian_id"):continue
		var other_leg: Dictionary=other.route.legs[int(other.leg)]
		if leg.from!=other_leg.from or leg.to!=other_leg.to or guest.elapsed/guest.duration<=other.elapsed/other.duration:continue
		var other_position: Vector3=model.guest_position(other)
		var gap: float=position.distance_to(other_position)
		var future: float=next.distance_to(other_position)
		if future>18:factor=minf(factor,clampf((18-gap)/maxf(0.01,future-gap),0,1))
	return factor
static func _meeting_route(model: RefCounted,guest: Dictionary,source: String,party: Dictionary) -> Dictionary:
	var graph: Dictionary=model._routing_graph(Agenda.comfort(guest),true)
	var outward: Dictionary=model._shortest(graph,source,party.node)
	var home: Dictionary=model._shortest(graph,party.node,"base")
	if not outward.ok or not home.ok:return {}
	var legs: Array=outward.legs.duplicate(true)
	if int(party.venue)>0:
		var door: Array=graph.nodes[party.node]
		legs.append(model._edge(party.node,party.node,"visit",int(party.venue),[door,door],20*model.time_divisor))
	legs.append_array(home.legs)
	if legs.is_empty():return {}
	return {"target":0,"origin":graph.nodes[source],"legs":legs}
static func _select_meeting(model: RefCounted,party: Dictionary) -> void:
	party.status="gather";party.node="base";party.venue=0
	if int(party.round)>0:return
	var graph: Dictionary=model._routing_graph(0,true)
	var best:=INF
	for building in model.buildings:
		if building.kind not in ["restaurant","kiosk"] or not model.Ops.building_open(model,building) or model.service_load(int(building.id))+members(model,party).size()>model.service_capacity(building):continue
		var door: String="d%d"%int(building.id)
		var outward: Dictionary=model._shortest(graph,"base",door)
		var home: Dictionary=model._shortest(graph,door,"base")
		if not outward.ok or not home.ok:continue
		var distance:=0.0
		for leg in outward.legs:distance+=float(leg.minutes)
		if distance<best:best=distance;party.node=door;party.venue=int(building.id)
static func arrive(model: RefCounted,guest: Dictionary,leg: Dictionary) -> bool:
	if not guest.has("party_id"):return false
	var party:=group(model,guest)
	if party.is_empty():return false
	if guest.get("heading_home",false):
		# The care cell still rejoins at every station and piste junction.
		pass
	elif party.status=="gather":
		if leg.to!=party.node:
			var route:=_meeting_route(model,guest,leg.to,party)
			if not route.is_empty():guest.route=route;guest.leg=0;model._start_leg(guest);return true
		else:
			guest.phase="waiting";guest.waiting_reason="meeting";guest.waiting_node=leg.to;guest.waiting_since=now(model);return true
	elif party.status=="meal" and leg.kind=="visit" and int(leg.id)==int(party.venue):
		guest.phase="waiting";guest.waiting_reason="meal";guest.waiting_node=leg.to;guest.waiting_since=now(model);return true
	var companions:=members(model,party) if party.status=="outing" else cell(model,guest)
	if companions.size()>1:
		guest.phase="waiting";guest.waiting_reason="care";guest.waiting_node=leg.to;guest.waiting_since=now(model);return true
	return false
static func _together(people: Array,reason: String="") -> bool:
	if people.is_empty():return false
	var node: String=str(people[0].get("waiting_node",""))
	return people.all(func(g):return g.phase=="waiting" and g.get("waiting_node","")==node and (reason=="" or g.get("waiting_reason","")==reason))
static func _release(model: RefCounted,people: Array) -> void:
	people.sort_custom(func(a,b):return not a.has("guardian_id") and b.has("guardian_id"))
	var leader: Dictionary=people[0]
	var party:=group(model,leader)
	for guest in people:
		var leg: Dictionary=guest.route.legs[int(guest.leg)]
		guest.phase="moving"
		for key in ["waiting_node","waiting_reason","waiting_since"]:guest.erase(key)
		if int(guest.id)!=int(leader.id) and (party.get("status")=="outing" or guest.get("guardian_id",0)==leader.id):
			guest.route=leader.route.duplicate(true);guest.leg=int(leader.leg)
			for flag in ["heading_home","portal_departing"]:
				if leader.get(flag,false):guest[flag]=true
			if leader.phase=="leaving":guest.phase="leaving"
			else: model._start_leg(guest)
		else:model._continue_leg(guest,leg)
static func tick(model: RefCounted) -> void:
	if not model.party_mode:return
	for party in model.parties.duplicate():
		var people:=members(model,party)
		if people.is_empty():model.parties.erase(party);continue
		if party.status=="free" and now(model)>=int(party.meeting_at):_select_meeting(model,party)
		if party.status=="gather":
			if int(party.venue)>0 and not model.Ops.building_open(model,model.asset(int(party.venue))):party.node="base";party.venue=0
			for guest in people:
				if guest.phase=="waiting" and guest.waiting_node==party.node:guest.waiting_reason="meeting"
				if guest.phase=="waiting" and guest.waiting_node!=party.node:
					var route:=_meeting_route(model,guest,guest.waiting_node,party)
					if not route.is_empty():guest.route=route;guest.leg=0;guest.phase="moving";model._start_leg(guest)
			if _together(people,"meeting"):
				if int(party.venue)>0:
					party.status="meal"
					for guest in people:
						var route:=_meeting_route(model,guest,party.node,party)
						guest.route=route;guest.leg=0;model._start_leg(guest)
				else:
					party.status="outing"
					var leader: Dictionary=people[0];var route: Dictionary=model.choose_route(care_guest(model,leader),party.node)
					if route.is_empty():party.status="free";party.meeting_at=now(model)+90;party.round+=1;_release(model,people)
					else:
						for guest in people:guest.route=route.duplicate(true);guest.leg=0;model._start_leg(guest)
		elif party.status=="meal" and _together(people,"meal"):
			party.status="free";party.meeting_at=now(model)+90;party.round+=1;_release(model,people)
		elif party.status=="outing" and _together(people):
			var leg: Dictionary=people[0].route.legs[int(people[0].leg)]
			if leg.kind=="ski" and int(leg.id)==int(people[0].route.target):party.status="free";party.meeting_at=now(model)+120;party.round+=1
			_release(model,people)
		elif party.status=="free":
			for guest in people:
				if guest.has("guardian_id"):continue
				var care:=cell(model,guest)
				if care.size()>1 and _together(care):_release(model,care)
static func valid(model: RefCounted,value: Variant) -> bool:
	if not value is Array or value.size()>model.MAX_GUESTS:return false
	var ids: Array=[]
	for party in value:
		if not party is Dictionary or not Terrain.number(party.get("id")) or party.id!=floorf(party.id) or party.id<1 or party.id>=model.guest_id or ids.has(int(party.id)):return false
		party.id=int(party.id);ids.append(party.id)
		if not party.get("members") is Array or party.members.size()<2 or party.members.size()>5:return false
		if party.get("status") not in ["free","gather","meal","outing"] or not party.get("node") is String:return false
		for key in ["meeting_at","venue","round"]:
			if not Terrain.number(party.get(key)) or party[key]!=floorf(party[key]) or party[key]<0 or party[key]>1000000000:return false
		if party.node!="base" and party.node!="d%d"%int(party.venue):return false
		if party.venue>0 and model.asset(int(party.venue)).get("kind","") not in ["restaurant","kiosk"]:return false
		var seen: Array=[]
		for member in party.members:
			if not Terrain.number(member) or member!=floorf(member) or member<1 or member>=model.guest_id or seen.has(int(member)):return false
			seen.append(int(member))
		for id in seen:
			var present:=actor(model,id)
			if not present.is_empty() and present.get("party_id",0)!=party.id:return false
		party.members=seen
	for guest in model.guests:
		if not guest.has("party_id"):continue
		if not Terrain.number(guest.party_id) or guest.party_id!=floorf(guest.party_id) or not ids.has(int(guest.party_id)) or guest.get("group_size")!=1 or guest.has("family"):return false
		var party:=group(model,guest)
		if not party.members.has(guest.id) or not guest.get("person_name") is String or guest.person_name.length()>80:return false
		if not Terrain.number(guest.get("years")) or guest.years!=floorf(guest.years) or guest.years<3 or guest.years>100:return false
		if not Terrain.number(guest.get("party_comfort")) or guest.party_comfort!=floorf(guest.party_comfort) or guest.party_comfort<0 or guest.party_comfort>2:return false
		if guest.years>=16 and guest.has("guardian_id"):return false
		if guest.years<16:
			if not Terrain.number(guest.get("guardian_id")) or guest.guardian_id!=floorf(guest.guardian_id):return false
			var parent:=actor(model,int(guest.get("guardian_id",0)))
			if parent.is_empty() or parent.get("years",0)<16 or parent.get("party_id",-1)!=guest.party_id:return false
		if guest.phase=="waiting":
			if guest.get("waiting_reason") not in ["care","meeting","meal"] or guest.get("waiting_node")!=guest.route.legs[int(guest.leg)].to:return false
			if not Terrain.number(guest.get("waiting_since")) or guest.waiting_since<0 or guest.waiting_since>now(model):return false
		for field in ["party_id","years","party_comfort","guardian_id"]:
			if guest.has(field):guest[field]=int(guest[field])
	return true
