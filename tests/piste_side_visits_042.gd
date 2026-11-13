extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Ops=preload("res://src/core/operations.gd")
const Terrain=preload("res://src/core/terrain.gd")
const Stops=preload("res://src/core/piste_stops_042.gd")
const Habits=preload("res://src/core/guest_habits_042.gd")
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func run()->void:
	var model:=Resort.new();model.new_game(true,20261113)
	model.campaign.mode="free"
	Ops.enable(model);model.enable_runtime_rules()
	model.operations.auto_groom=false
	var piste:Dictionary=model.pistes[0]
	var original:Array=piste.points.duplicate(true)
	var restaurant:Dictionary={}
	# Search an actual legal lot beside the middle of an actual descent.
	for fraction in [0.35,0.45,0.55,0.65]:
		var center:Vector2=model.terrain.point_on_path(piste.points,fraction)
		for offset in [Vector2(32,0),Vector2(-32,0),Vector2(40,0),Vector2(-40,0)]:
			for rotation in range(4):
				var site:Dictionary=model.preview_building("restaurant",center+offset,rotation)
				if site.ok and site.connection.has("piste"):
					if model.build_building("restaurant",center+offset,rotation).ok:restaurant=model.buildings[-1];break
			if not restaurant.is_empty():break
		if not restaurant.is_empty():break
	check(not restaurant.is_empty(),"A restaurant can be built beside the middle of a piste without a valley plaza")
	if restaurant.is_empty():finish();return
	check(piste.points==original,"Building the restaurant preserves the exact authored piste")
	check(Ops.fill_building(model,int(restaurant.id)).ok,"The real restaurant has its required professional team")
	check(model.admit_guest(0),"An actual skier enters the connected resort")
	var guest:Dictionary=model.guests[0]
	guest.needs={"hunger":92.0,"warmth":90.0,"energy":90.0,"joy":90.0,"rental":false,"lesson":false,"bladder":0.0,"bowel":0.0}
	guest.years=45;guest.stay=1000
	var source:Dictionary=model.routes_for(0)[0]
	var money:float=model.money
	var route:Dictionary=Stops.decorate(model,guest,source)
	check(route.legs.any(func(leg):return leg.kind=="visit" and int(leg.id)==int(restaurant.id)),"Hungry skier reserves a real mid-slope restaurant visit")
	check(model.money==money and restaurant.visits==0,"Planning a stop creates no revenue or fictional customers")
	var visit:= -1
	for i in range(route.legs.size()):
		if route.legs[i].kind=="visit":visit=i;break
	if visit<0:finish();return
	check(route.legs[visit-2].kind=="ski" and route.legs[visit+2].kind=="ski" and route.legs[visit-2].id==route.legs[visit+2].id,"The same piste is skied before and after the meal")
	check(is_equal_approx(float(route.legs[visit-2].end_fraction),float(route.legs[visit+2].start_fraction)),"Return joins the same exact piste fraction")
	check(model._checked_itinerary(route,0).size()>0,"The full itinerary passes geometry and save validation")
	guest.route=route;guest.leg=0;model._start_leg(guest)
	var detour_snapshot:Dictionary=model.snapshot()
	# Closed, unstaffed and full venues must not become phantom reservations.
	model.set_enabled(int(restaurant.id),false)
	check(not Stops.decorate(model,guest,source).legs.any(func(leg):return leg.kind=="visit" and int(leg.id)==int(restaurant.id)),"Closed piste-side restaurants are excluded")
	model.set_enabled(int(restaurant.id),true)
	for person in model.operations.staff:
		if person.assignment=="building:%d" % int(restaurant.id):person.absent_until=Ops.clock(model)+120
	model._duty_cache.clear();model._operational_change()
	check(not Stops.decorate(model,guest,source).legs.any(func(leg):return leg.kind=="visit" and int(leg.id)==int(restaurant.id)),"Missing kitchen staff prevents a booking")
	for person in model.operations.staff:person.absent_until=0
	model._duty_cache.clear();model._operational_change()
	var places:int=model.service_capacity(restaurant)
	guest.group_size=places+1
	check(not Stops.decorate(model,guest,source).legs.any(func(leg):return leg.kind=="visit" and int(leg.id)==int(restaurant.id)),"Groups exceeding actual seating capacity cannot reserve a stop")
	guest.group_size=1
	var phases:Dictionary={}
	var finished:=false
	var visit_count:=0
	var resumed:=false
	var previous:int=guest.leg
	for step in range(18000):
		var phase:Dictionary=guest.route.legs[guest.leg]
		var label:String="before" if guest.leg<visit else "meal" if guest.leg==visit else "after"
		if not phases.has(label) and (guest.leg==visit-1 or guest.leg==visit or guest.leg==visit+2):
			var copy:=Resort.new()
			phases[label]=copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok
			if phases[label]:
				check(copy.guest_position(copy.guests[0]).distance_to(model.guest_position(guest))<0.02,"Save/resume retains position "+label)
				model=copy;guest=model.guests[0];restaurant=model.asset(int(restaurant.id));piste=model.asset(int(piste.id))
		if guest.leg==visit+2:resumed=true
		model.advance_minute(false)
		if previous==visit and guest.leg!=visit:visit_count+=1
		previous=guest.leg
		if resumed and int(piste.rides)>0:finished=true;break
	check(phases.get("before",false) and phases.get("meal",false) and phases.get("after",false),"Approach, meal and resumed descent all save and continue")
	check(visit_count==1 and restaurant.visits==1 and float(restaurant.revenue)>0,"Only one physically completed visit charges the real restaurant sale")
	check(resumed and finished and int(piste.rides)==1,"Guest completes the same descent with exactly one counted run")
	check(guest.needs.hunger<40,"The actual meal satisfies hunger")
	var bad:Dictionary=detour_snapshot.duplicate(true)
	# Restore rejects an access path forged through the mountain.
	for itinerary in bad.itineraries:
		for leg in itinerary.legs:
			if leg.has("piste_access"):leg.points[0]=[0,0]
	check(not Resort.new().restore(bad).ok,"Forged piste-door access cannot bypass save geometry checks")
	bad=detour_snapshot.duplicate(true)
	for itinerary in bad.itineraries:
		for leg in itinerary.legs:
			if leg.get("partial",false):leg.end_fraction=leg.start_fraction
	check(not Resort.new().restore(bad).ok,"Invalid partial ski ranges cannot corrupt a valid save")
	var child:Dictionary={"id":2,"age":200,"years":10,"needs":guest.needs.duplicate(),"service_history":{}}
	var senior:Dictionary=child.duplicate(true);senior.years=70;senior.runs=2
	check(not Habits.allowed(child,"bar") and not Habits.allowed(child,"disco") and Habits.allowed(child,"cocoa"),"Children choose age-appropriate venues")
	check(Habits.bonus(senior,"viewpoint",750)>Habits.bonus(child,"viewpoint",750),"Older guests prefer a scenic rest after skiing")
	var shopper:Dictionary=senior.duplicate(true);shopper.years=35;shopper.id=3
	check(Habits.bonus(shopper,"souvenir",900)>0 and Habits.bonus(shopper,"watchmaker",900)==0,"Stable individual tastes diversify shopping destinations")
	shopper.service_history.souvenir=shopper.age
	check(Habits.bonus(shopper,"souvenir",900)==0,"Shopping habits obey a genuine visit cooldown")
	check(model.admit_guest(0),"A second guest starts a normal ski day")
	var skier:Dictionary=model.guests[-1]
	skier.needs=guest.needs.duplicate();skier.needs.hunger=85.0;skier.needs.warmth=90.0;skier.needs.energy=90.0
	skier.stay=1000;skier.route=source.duplicate(true)
	for index in range(skier.route.legs.size()):
		if skier.route.legs[index].kind=="ski":skier.leg=index;model._start_leg(skier);break
	skier.elapsed=skier.duration*0.10
	var position:Vector3=model.guest_position(skier)
	check(Stops.maybe_stop(model,skier),"Hunger arising during an existing descent triggers an upcoming stop")
	check(model.guest_position(skier).distance_to(position)<0.03,"Replanning a moving skier preserves their exact physical position")
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok,"A spontaneous mid-descent detour saves with valid progress")
	finish()
func finish()->void:
	print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
