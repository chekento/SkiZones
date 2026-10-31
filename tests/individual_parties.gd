extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Ops=preload("res://src/core/operations.gd")
const Parties=preload("res://src/core/guest_parties.gd")
const Saves=preload("res://src/core/save_store.gd")
const Profile=preload("res://src/core/guest_profile.gd")
var passed:=0
var failed:=0
func check(ok: bool,title: String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func _init() -> void:
	var model:=Resort.new();model.new_game(true);Ops.enable(model);model.enable_runtime_rules();model.edge_entries=false
	var income: float=model.money;var admitted: int=model.report.guests
	check(model.admit_guest(0,"family",5),"A family is admitted through the actual ticket and route logic")
	check(model.guests.size()==5 and model.parties.size()==1 and model.guests.all(func(g):return g.group_size==1 and not g.has("family")),"The family consists of five independent actors rather than a shared moving block")
	check(model.money-income==model.ticket_price*5 and model.report.guests-admitted==5,"Individual actors preserve the exact number of paid tickets and visitors")
	var children: Array=model.guests.filter(func(g):return g.years<16)
	check(children.size()==3 and children.all(func(g):return not Parties.actor(model,g.guardian_id).is_empty()),"Every child has a real adult guardian")
	check(model.guests.all(func(g):return g.route.legs.all(func(leg):return leg.kind!="ski" or model.asset(leg.id).difficulty<=g.party_comfort)),"The care cell chooses slopes within its children's abilities")
	var party: Dictionary=model.parties[0]
	for guest in model.guests:
		guest.stay=1000;guest.needs={"hunger":0.0,"warmth":95.0,"energy":95.0,"joy":95.0,"rental":false,"lesson":false}
	var split:=false;var own_seats:=false;var regroup:=false
	for step in range(900):
		model.advance_minute(false)
		var parents: Array=model.guests.filter(func(g):return g.years>=16)
		if parents.size()==2 and model.guest_position(parents[0]).distance_to(model.guest_position(parents[1]))>18:split=true
		if model.guests.any(func(g):return g.phase=="waiting"):regroup=true
		var riders: Array=model.guests.filter(func(g):return g.phase=="moving" and g.route.legs[g.leg].kind=="lift")
		if riders.size()>=2:own_seats=riders[0].ride_car!=riders[1].ride_car or riders[0].ride_seat!=riders[1].ride_seat
	check(split,"Adults may explore separately with genuinely different positions and progress")
	check(own_seats,"Individuals occupy their own actual lift seats and may ride different carriers")
	check(regroup,"Guardians wait at real route nodes for the children to catch up")
	var state:=model.snapshot();var copy:=Resort.new()
	check(Saves.save_game(model,"user://individuals017.json").ok and Saves.load_game(copy,"user://individuals017.json").ok,"Personal movement, guardians and future appointments survive a checked save")
	check(copy.guests.size()==5 and copy.parties[0].members==party.members,"Restoration retains each person and party membership")
	var broken: Dictionary=state.duplicate(true);broken.guests[0].party_id=9999
	check(not copy.restore(broken).ok,"A broken party reference is rejected without damaging the current game")
	broken=state.duplicate(true)
	for guest in broken.guests:
		if guest.years<16:guest.guardian_id=9999;break
	check(not copy.restore(broken).ok,"A child without their saved guardian is rejected")
	var food: Dictionary={};model.campaign.mode="free";model.money=3000000
	for z in range(240,345,35):
		for x in range(70,330,35):
			if food.is_empty() and model.build_building("restaurant",Vector2(x,z)).ok:food=model.buildings[-1]
	check(not food.is_empty() and Ops.fill_building(model,food.id).ok,"A reachable restaurant is built and staffed for the lunch appointment")
	party.meeting_at=Parties.now(model)
	var meal:=false;var returned:=false
	for step in range(6000):
		model.advance_minute(false)
		if party.status=="meal":meal=true
		if meal and party.status=="free" and party.round>0:returned=true;break
	check(meal,"Separated members travel to their common lunch venue and start dining together")
	check(returned and food.get("visits",0)>=5,"The actual meal finishes for all five people and creates five real paid visits")
	check(model.guests.all(func(g):return g.runs>0),"Every individual participates in actual ski descents")
	var detail: Dictionary=Profile.describe(model,model.guests[0])
	check(detail.name==model.guests[0].person_name and detail.agenda.contains("GEMEINSAM IM RESORT"),"The personal profile identifies the selected person and explains the next group appointment")
	print("INDIVIDUAL PARTIES: %d passed; %d failed"%[passed,failed]);quit(1 if failed else 0)
