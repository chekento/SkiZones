extends SceneTree
## Actual bounded toilet queues, family batches, costs and save continuation.
const Resort=preload("res://src/core/resort.gd")
const WC=preload("res://src/core/public_wc.gd")
const Needs=preload("res://src/core/guest_needs.gd")
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func visit_id(route:Dictionary) -> int:
	for leg in route.get("legs",[]):
		if leg.kind=="visit":return int(leg.id)
	return -1
func urgent(guest:Dictionary) -> void:
	Needs.ensure(guest,0)
	for state in guest.family.map(func(member):return member.needs) if guest.has("family") else [guest.needs]:
		state.hunger=0.0;state.warmth=95.0;state.energy=95.0;state.joy=95.0
		state.rental=false;state.lesson=false;state.bladder=90.0;state.bowel=10.0
	Needs.aggregate_family(guest)
	guest.service_history={}
func flow(scale:int) -> void:
	var model:=Resort.new();model.new_game(true,20261106)
	model.campaign.mode="free";model.money=2500000
	# Keep aggregate families so the same test also covers historical saves.
	model.time_divisor=scale
	check(model.build_building("wc_dixi",Vector2(155,300)).ok,"Connected Dixi physically built at clock scale %d" % scale)
	var bathroom:Dictionary=model.buildings[-1]
	check(bathroom.has("wc_public"),"Unused new cabin records its construction day for aging")
	# Isolate the public queue: otherwise guests correctly prefer the free
	# included indoor WC at the starter lodge when its queue is shorter.
	for building in model.buildings:
		if str(building.kind) in Needs.INDOOR_WCS:model.set_enabled(int(building.id),false)
	check(model.admit_guest(0,"family",3),"Real three-person family admitted")
	var family:Dictionary=model.guests[-1];urgent(family)
	var trip:Dictionary=model.service_route(family)
	check(visit_id(trip)==int(bathroom.id),"Family selects one real cabin instead of being rejected for three seats")
	if trip.is_empty():return
	check(not model._checked_itinerary(trip.duplicate(true),0).is_empty(),"Batched service itinerary passes unchanged terrain and return validation")
	family.route=trip;family.leg=0;model._start_leg(family)
	check(model.admit_guest(0),"Second real visitor admitted")
	var other:Dictionary=model.guests[-1];urgent(other)
	other.group_size=1
	trip=model.service_route(other)
	check(visit_id(trip)==int(bathroom.id),"Second visitor can reserve a bounded turn behind the family")
	if trip.is_empty():return
	other.route=trip;other.leg=0;model._start_leg(other)
	var saw_queue:=false
	var continuation:=false
	var exclusive:=true
	var waiting_still:=true
	for tick in range(180*scale):
		var steps:Dictionary=WC.steps(model)
		if steps.size()==2:
			exclusive=exclusive and steps.values().count(true)==1
			var before:Dictionary={int(family.id):family.elapsed,int(other.id):other.elapsed}
			if not saw_queue:
				var copy:=Resort.new()
				var saved:Dictionary=JSON.parse_string(JSON.stringify(model.snapshot()))
				check(copy.restore(saved).ok,"Actual active and waiting WC visitors survive JSON save/restore")
				continuation=WC.steps(copy)==steps
				check(continuation,"Restored cabin queue keeps the same serving party")
				var bad:Dictionary=saved.duplicate(true)
				bad.guests[0].wc_queue_since=-1
				check(not Resort.new().restore(bad).ok,"Invalid optional queue arrival clock is rejected")
			model.advance_minute(false)
			for person in [family,other]:
				if not steps.get(int(person.id),true):waiting_still=waiting_still and is_equal_approx(float(person.elapsed),float(before[int(person.id)]))
			saw_queue=true
		else:model.advance_minute(false)
		if int(bathroom.get("visits",0))>=4:break
	check(saw_queue and continuation,"Real approach produces a finite reproducible door queue")
	check(saw_queue and exclusive,"One physical Dixi never serves two visitor parties at once")
	check(saw_queue and waiting_still,"Waiting visitor makes no service progress")
	check(int(bathroom.get("visits",0))==4 and int(WC.status(model,bathroom).visits)==4,"Four people complete exactly four real toilet visits")
	check(float(family.needs.bladder)<10 and float(other.needs.bladder)<10,"Both actual completed parties resolve bladder pressure")
	check(float(WC.status(model,bathroom).fill)>20 and float(WC.status(model,bathroom).fill)<23,"Exactly four uses fill the finite 18-use Dixi tank")
	check(not family.has("wc_queue_since") and not other.has("wc_queue_since"),"Queue timestamps are removed on leaving the toilet leg")
func run() -> void:
	var model:=Resort.new();model.new_game(true)
	var item:Dictionary={"id":999,"kind":"wc_dixi","level":1,"enabled":true}
	var previous_volume:=0.0
	for level in range(1,6):
		item.level=level
		var info:Dictionary=WC.status(model,item)
		check(int(info.units)==int(pow(2,level-1)) and model.service_capacity(item)==int(pow(2,level-1)),"Displayed and routable physical cabins agree at level %d" % level)
		check(float(info.volume)>previous_volume,"Each expansion adds real finite tank capacity at level %d" % level)
		previous_volume=float(info.volume)
		if level==3:check(is_equal_approx(float(info.volume),72.0),"Level-three module has its actual 72-use tank")
		if level==4:check(float(info.hygiene_use)<0.65,"Level-four equipment reduces hygiene consumed per use")
		if level==5:check(int(info.clean_cost)==76 and is_equal_approx(float(info.service_factor),0.8),"Level-five maintenance is actually discounted by twenty percent")
	item.level=1
	var guest:Dictionary={"id":55,"group_size":7}
	check(not WC.reservation(model,item,guest).ok,"Bookings exceeding eighteen real service minutes are rejected")
	item.wc_public={"version":1,"hygiene":100.0,"fill":90.0,"visits":0,"emptied":0,"cleaned":0,"last_day":model.day,"winterized":false}
	guest.group_size=2
	check(not WC.reservation(model,item,guest).ok,"A nearly full tank does not accept impossible future visits")
	check(model.build_building("wc_dixi",Vector2(155,300)).ok,"Career upgrade test uses a physically constructed public WC")
	var facility:Dictionary=model.buildings[-1]
	model.campaign.mode="career";model.money=2500000
	for research in ["wc_logistics","sanitation","wc_hygiene","wc_comfort"]:
		check(not model.upgrade_check(int(facility.id)).ok,"Next public WC expansion waits for its own sanitation research")
		model.campaign.research.append(research)
		check(model.upgrade_asset(int(facility.id)).ok,"Public WC expansion uses its own research without hotel mastery: "+research)
	check(int(facility.level)==5 and not model.campaign.research.has("hospitality") and not model.campaign.research.has("mastercraft"),"Dixi reaches maximum level through independent public sanitation development")
	var party_model:=Resort.new();party_model.new_game(true,20261106)
	party_model.enable_runtime_rules()
	check(party_model.admit_guest(0,"family",3),"Current runtime admits a family as separate real people")
	var child:Dictionary={}
	for person in party_model.guests:
		person.needs.bladder=0.0;person.needs.bowel=0.0
		if person.has("guardian_id"):child=person
	check(not child.is_empty(),"Runtime family includes a child with an actual guardian")
	if not child.is_empty():
		child.needs.bladder=95.0
		var parent:Dictionary=party_model.Parties.actor(party_model,int(child.guardian_id))
		var care:Dictionary=party_model.Parties.care_guest(party_model,parent)
		check(float(parent.needs.bladder)==0.0 and float(care.needs.bladder)==95.0,"A child's urgent toilet need reaches guardian route selection without changing the parent's own need")
	flow(1)
	flow(24)
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
