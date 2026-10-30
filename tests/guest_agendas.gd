extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Agenda = preload("res://src/core/guest_agenda.gd")
const Needs = preload("res://src/core/guest_needs.gd")
const Ops = preload("res://src/core/operations.gd")
const BLUE := [[0,0],[350,35],[-350,100],[350,165],[200,205]]
const FAMILY_BLUE := [[245,-130],[275,-30],[255,95],[200,205]]
var passed := 0
var failed := 0
class PlanarMountain extends "res://src/core/mountain.gd":
	func height(point: Vector2) -> float: return 200-point.y*0.8
func check(ok: bool, title: String) -> void:
	if ok: passed += 1; print("PASS ",title)
	else: failed += 1; push_error("FAIL "+title)
func healthy(guest: Dictionary) -> void:
	guest.needs={"hunger":0.0,"warmth":90.0,"energy":90.0,"joy":90.0,"rental":false,"lesson":false}
	guest.service_history={}
	for member in guest.get("family",[]): member.needs=guest.needs.duplicate()
func fixture() -> RefCounted:
	var model:=Resort.new();model.new_game(false);model.terrain=PlanarMountain.new();model.money=5000000
	model.build_lift("drag",Vector2(200,205),Vector2(0,0));model.build_piste(BLUE)
	model.build_piste([[350,35],[350,165]]);model.build_piste([[350,35],[480,100],[350,165]])
	return model
func visit_id(route: Dictionary) -> int:
	for leg in route.get("legs",[]):
		if leg.kind=="visit": return int(leg.id)
	return -1
func save(model: RefCounted) -> Dictionary: return JSON.parse_string(JSON.stringify(model.snapshot()))
func _init() -> void:
	_preferences();_collectors();_park();_families();_needs();_economy();_overnight()
	print("GUEST SERVICES: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
func _preferences() -> void:
	var model:=fixture()
	check(model.pistes.size()==3 and model.pistes[0].difficulty==0 and model.pistes[1].difficulty==2 and model.pistes[2].difficulty==1,"The audience fixture offers genuinely connected blue, red and black runs")
	for kind in ["blue","mixed","alpine","expert"]:
		check(model.admit_guest(2,kind),"Admit an explicit "+kind+" visitor")
		var guest: Dictionary=model.guests[-1];healthy(guest)
		var safe:=true;var red:=0;var black:=0
		for i in range(80):
			var route: Dictionary=model.choose_route(guest)
			safe=safe and not route.is_empty()
			for leg in route.get("legs",[]):
				if leg.kind=="ski": safe=safe and model.asset(leg.id).difficulty<=Agenda.comfort(guest)
			var color: int=model.asset(route.get("target",0)).get("difficulty",-1)
			red+=int(color==1);black+=int(color==2)
		check(safe,kind+" respects its comfort on every leg, including access and return")
		if kind=="mixed": check(red>20 and black==0,"Blue-and-red guests actually choose red alternatives and avoid black")
		if kind=="expert": check(black>55,"Sport visitors actively prefer real black circuits")
		check(guest.agenda.pistes.is_empty() and guest.agenda.lifts.is_empty(),"Selecting a route never fabricates completed experiences")
	var supply:=Agenda.offer(model)
	check(supply.colors==[1,1,1] and supply.lifts==1,"Audience fit counts only actual reachable circuits")
	model.set_enabled(model.lifts[0].id,false)
	check(Agenda.offer(model).colors==[0,0,0],"An access closure removes unavailable pistes from the advertised offer")
func _collectors() -> void:
	var model:=fixture();model.admit_guest(2,"collector")
	var guest: Dictionary=model.guests[0];healthy(guest)
	var piste: Dictionary=model.pistes[0]
	Agenda.record_piste(guest,piste,{"start_fraction":0.0,"end_fraction":0.4})
	check(guest.agenda.pistes.is_empty(),"A partial descent cannot complete the collector's whole-piste goal")
	Agenda.record_piste(guest,piste,{"start_fraction":0.6,"end_fraction":1.0})
	check(guest.agenda.pistes.is_empty(),"Disconnected partial descents keep the missing middle unfulfilled")
	Agenda.record_piste(guest,piste,{"start_fraction":0.4,"end_fraction":0.6})
	check(guest.agenda.pistes==[int(piste.id)] and guest.agenda.coverage[str(int(piste.id))]==[[0.0,1.0]],"Real complementary sections merge into exactly one completed piste")
	Agenda.record_piste(guest,piste,{"start_fraction":0.0,"end_fraction":1.0})
	check(guest.agenda.pistes.size()==1,"Repeating a piste never inflates unique holiday goals")
	guest.agenda.pistes.clear();guest.agenda.coverage.clear()
	var route: Dictionary=model.routes_for(2)[0]
	check(Agenda.route_weight(model,guest,route)>1,"Collectors favor genuinely unvisited pistes and lifts")
	for leg in route.legs:
		if leg.kind=="lift": Agenda.record_lift(guest,leg.id)
		elif leg.kind=="ski": Agenda.record_piste(guest,model.asset(leg.id),leg)
	check(Agenda.route_weight(model,guest,route)==1,"An already completed circuit loses its discovery bonus")
	check(model.build_lift("chair",Vector2(80,205),Vector2(-170,-235)).ok and model.build_piste([[-170,-235],[0,0]]).ok,"A second accessible lift joins an existing descent")
	guest.agenda.lifts=[int(model.lifts[0].id)]
	var unused: Array=model._collector_lift_routes(guest,"base")
	check(unused.any(func(option):return option.legs.any(func(leg):return leg.kind=="lift" and int(leg.id)==int(model.lifts[1].id))),"A collector can intentionally use an otherwise unvisited lift")
	model=Resort.new();model.new_game(true);model.admit_guest(2,"collector");guest=model.guests[0];healthy(guest)
	var reached:=false
	for i in range(300):
		model.advance_minute(false)
		if guest.agenda.pistes.size()>0: reached=true;break
	check(reached and guest.agenda.lifts.size()>0,"An autonomous collector earns goals through actual boarded and completed trips")
	check(Agenda.achievement(model,guest)==1,"A collector can really complete the starter resort holiday list")
func _park() -> void:
	var model:=Resort.new();model.new_game(true);model.campaign.mode="free";model.money=3000000
	var park: Dictionary={}
	for z in range(240,360,35):
		for x in range(70,330,35):
			if park.is_empty() and model.build_building("snowpark",Vector2(x,z)).ok:park=model.buildings[-1]
	check(not park.is_empty(),"Sport visitors have an actual reachable snowpark")
	model.admit_guest(2,"expert");var guest: Dictionary=model.guests[0];healthy(guest)
	var trip: Dictionary=model.service_route(guest)
	check(visit_id(trip)==int(park.id),"A comfortable sport visitor deliberately chooses a real snowpark session")
	guest.route=trip;guest.leg=0;model._start_leg(guest)
	var balance: float=model.money
	for i in range(100):
		if guest.agenda.park_visits>0:break
		model.advance_minute(false)
	check(guest.agenda.park_visits==1 and park.visits==1 and model.money>balance,"Only the physically completed park visit counts and earns the actual fee")
	check(visit_id(model.service_route(guest))!=int(park.id),"A sport visitor observes the real park cooldown")
func _families() -> void:
	var model:=Resort.new();model.new_game(false);model.money=3000000
	model.build_lift("chair2",Vector2(200,205),Vector2(245,-130));model.build_piste(FAMILY_BLUE)
	var balance: float=model.money
	check(model.admit_guest(0,"family",5),"A five-person family enters as one decision group")
	var guest: Dictionary=model.guests[0];healthy(guest)
	check(guest.family.size()==5 and guest.family[0].years<16 and guest.family[-1].years>=28,"The family has individual children and adults with personal needs")
	check(model.money==balance+5*model.ticket_price and model.report.guests==5,"Family admission charges and reports five real day tickets")
	for index in range(guest.route.legs.size()):
		if guest.route.legs[index].kind=="lift":guest.leg=index;model._start_leg(guest);break
	var lift: Dictionary=model.lifts[0]
	# Cross one carrier loading boundary at a time, independently of minute batching.
	var interval: float=model.fleet_layout(lift).interval
	lift.clock=interval;model._board_direction(lift,false)
	check(guest.phase=="queue" and guest.ride_manifest.size()==2 and guest.boarding_remaining==3,"Two real seats board two family members while the others wait")
	check(model.lift_load(lift).riders==2,"Lift occupancy includes already boarded members of a waiting family")
	var first: Dictionary=guest.ride_manifest[0];var proxy: Dictionary=guest.duplicate()
	for field in first:proxy[field]=first[field]
	check(model.family_pose(guest,0).position.distance_to(model.rider_pose(proxy).transform.origin)<0.001,"A boarded child is attached to its own actual carrier and seat")
	var saved:=save(model);var restored:=Resort.new()
	check(restored.restore(saved).ok,"A partially boarded family survives a real JSON save")
	var continued:=Resort.new();continued.restore(saved)
	for minute in range(80):restored.advance_minute(false);continued.advance_minute(false)
	check(restored.snapshot()==continued.snapshot(),"A saved partly boarded family continues deterministically through regrouping and later trips")
	var bad:=saved.duplicate(true);bad.guests[0].ride_manifest[1]=bad.guests[0].ride_manifest[0].duplicate()
	check(not restored.restore(bad).ok,"Two family members cannot claim the same saved carrier seat")
	model.set_enabled(lift.id,false)
	check(guest.phase=="queue" and guest.ride_manifest.size()==2 and model._return_service(lift),"Closing during boarding retains passengers and safely completes the family")
	lift.clock=interval*2;model._board_direction(lift,false)
	lift.clock=interval*3;model._board_direction(lift,false)
	check(guest.phase=="moving" and guest.ride_manifest.size()==5 and not guest.has("boarding_remaining"),"All five family members board without exceeding two seats per carrier")
	lift.clock=first.ride_departure+model.fleet_layout(lift).ride+0.01
	guest.elapsed=lift.clock-guest.ride_departure
	check(model.family_pose(guest,0).waiting and not model.family_pose(guest,4).waiting,"Early arrivals wait at the summit for the family's last carrier")
	check(guest.agenda.lifts.is_empty(),"The shared next trip waits until the entire family has arrived")
	check(Resort.new().restore(save(model)).ok,"Separate carrier assignments remain valid while early members regroup")
	model.set_enabled(lift.id,true)
	for i in range(90):
		model.advance_minute(false)
		if not guest.agenda.lifts.is_empty():break
	check(guest.agenda.lifts==[int(lift.id)],"The family completes a shared lift experience after its last arrival")
func _needs() -> void:
	var model:=Resort.new();model.new_game(true);model.money=3000000
	check(model.build_building("restaurant",Vector2(155,300)).ok,"Food fixture uses a genuinely reachable restaurant")
	var food: Dictionary=model.buildings[-1]
	model.admit_guest(0,"family",4);var guest: Dictionary=model.guests[0];healthy(guest)
	guest.family[0].needs.hunger=95;Needs.aggregate_family(guest)
	check(guest.needs.hunger==95 and visit_id(model.service_route(guest))==int(food.id),"One hungry child sends the whole family to actual food")
	var trip: Dictionary=model.service_route(guest);guest.route=trip;guest.leg=0;model._start_leg(guest)
	var balance: float=model.money;var midpoint:=false
	for i in range(100):
		if guest.route.legs[guest.leg].kind=="visit" and guest.elapsed>3 and food.visits==0:midpoint=guest.family[0].needs.hunger<95
		if food.visits>0:break
		model.advance_minute(false)
	check(midpoint,"Eating improves individual hunger progressively during the actual visit")
	check(food.visits==4 and model.money==balance+28 and model.report.services==28,"The completed family meal accounts for four visits and four actual fees once")
	check(guest.family[0].needs.hunger<25 and guest.family[-1].needs.hunger<5,"Children and parents receive the meal without losing their individual needs")
	healthy(guest);guest.family[1].needs.warmth=5;Needs.aggregate_family(guest)
	check(visit_id(model.service_route(guest))==int(model.buildings[0].id),"The coldest child triggers a shared reachable warm shelter")
	var hunger: float=guest.family[1].needs.hunger;Needs.complete(guest,"shelter")
	check(guest.family[1].needs.warmth==60 and guest.family[1].needs.hunger==hunger,"Warming helps the individual child and does not invent a meal")
	healthy(guest);guest.family[0].needs.hunger=100;Needs.aggregate_family(guest)
	model.set_enabled(food.id,false)
	check(visit_id(model.service_route(guest))!=int(food.id),"A family does not fulfil hunger at a closed restaurant")
	model.set_enabled(food.id,true)
	for i in range(model.service_capacity(food)-2):
		model.admit_guest(0,"blue");var other: Dictionary=model.guests[-1];healthy(other);other.needs.hunger=95
		other.route=model.service_route(other);other.leg=0;model._start_leg(other)
	check(visit_id(model.service_route(guest))!=int(food.id),"A party stays together when only two restaurant seats remain")
func _economy() -> void:
	var published: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.11-starter.json"))
	var legacy:=Resort.new();legacy.restore(published)
	var again:=Resort.new();again.restore(save(legacy))
	for minute in range(120):legacy.advance_minute(false);again.advance_minute(false)
	check(legacy.snapshot()==again.snapshot(),"Migrated guests preserve exact future choices and audience feedback across another JSON save")
	var model:=Resort.new();model.new_game(true);model.admit_guest(2,"expert")
	var guest: Dictionary=model.guests[0];healthy(guest);guest.runs=4;guest.age=200
	var disappointed: float=Agenda.satisfaction(model,guest)
	guest.agenda.black_runs=3;guest.agenda.park_visits=2
	check(Agenda.satisfaction(model,guest)>disappointed+25,"Actual black runs and park sessions determine sport visitor satisfaction")
	var content: float=Agenda.satisfaction(model,guest)
	guest.agenda.cold_minutes=180
	check(Agenda.satisfaction(model,guest)<content-10,"Long unfulfilled needs remain in the holiday review after warming up")
	var factor:=Agenda.market_factor(model);var reputation: float=model.reputation
	model._depart(guest)
	check(model.audience.segments.expert.departures==1 and model.report.departures==1 and model.reputation!=reputation,"Departure feedback updates both audience history and resort reputation")
	for kind in Agenda.TYPES:model.audience.segments[kind].rating=95
	check(Agenda.market_factor(model)>factor,"Audience recommendations alter real market demand")
	var costs: float=model.operating_costs(false);model.audience.target="family"
	check(model.operating_costs(false)==costs+250,"Targeted audience advertising has an explicit daily operating cost")
	var saved:=save(model);var restored:=Resort.new()
	check(restored.restore(saved).ok and restored.audience.target=="family" and restored.audience.segments.expert.departures==1 and is_equal_approx(restored.audience.segments.expert.rating,model.audience.segments.expert.rating),"Audience feedback and advertising survive save/load")
	var bad:=saved.duplicate(true);bad.audience="invalid"
	var before:=restored.snapshot()
	check(not restored.restore(bad).ok and restored.snapshot()==before,"Malformed audience data is rejected atomically")
	bad=saved.duplicate(true);bad.guests[0].agenda.coverage={"1":[[0.7,0.2]]}
	check(not restored.restore(bad).ok,"Impossible collector coverage is rejected on load")
	bad=saved.duplicate(true);bad.guests[0].agenda.kind="unknown"
	check(not restored.restore(bad).ok,"Unknown visitor motives cannot corrupt a saved game")
	guest.agenda.cold_minutes+=1
	check(saved.guests[0].agenda.cold_minutes!=guest.agenda.cold_minutes,"A saved snapshot freezes nested goals and needs without live aliases")
func _overnight() -> void:
	var model:=Resort.new();model.new_game(true);model.money=3000000;model.campaign.mode="free";Ops.enable(model)
	var hotel: Dictionary={}
	for z in range(240,360,35):
		for x in range(70,330,35):
			if hotel.is_empty() and model.build_building("hotel",Vector2(x,z)).ok:hotel=model.buildings[-1]
	check(not hotel.is_empty() and Ops.fill_building(model,hotel.id).ok,"Holiday collectors can access a staffed real hotel")
	check(model.admit_guest(2,"collector"),"A holiday collector joins the continuous resort")
	var guest: Dictionary=model.guests[0];healthy(guest);guest.agenda.lifts=[int(model.lifts[0].id)]
	check(guest.stay>=2880,"Holiday collectors have a genuine multiple-day stay")
	model.minute=1320;model._duty_cache.clear();model._operational_change()
	var lodging: Dictionary=model.service_route(guest)
	check(visit_id(lodging)==int(hotel.id),"A collector deliberately books reachable overnight accommodation")
	guest.route=lodging;guest.leg=0;model._start_leg(guest)
	for i in range(125):model.advance_minute(false)
	check(model.day==2 and model.minute==5 and model.guests.has(guest) and guest.agenda.lifts.size()==1,"The same holiday guest and completed lift list persist across midnight")
	check(Resort.new().restore(save(model)).ok,"An occupied collector hotel stay survives a populated save")
