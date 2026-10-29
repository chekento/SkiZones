extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Needs=preload("res://src/core/guest_needs.gd")
const Terrain=preload("res://src/core/terrain.gd")
const L=preload("res://src/core/i18n.gd")
var passed:=0
var failed:=0
class SteepMountain extends "res://src/core/mountain.gd":
	func height(point: Vector2) -> float: return 300-point.y*0.7
func _init() -> void: call_deferred("run")
func check(ok: bool,title: String) -> void:
	if ok: passed+=1;print("PASS ",title)
	else: failed+=1;push_error("FAIL "+title)
func visit_id(route: Dictionary) -> int:
	for leg in route.get("legs",[]):
		if leg.kind=="visit": return int(leg.id)
	return -1
func ready_guest(model: RefCounted) -> Dictionary:
	model.admit_guest(0)
	var guest: Dictionary=model.guests[-1]
	guest.needs={"hunger":0.0,"warmth":85.0,"energy":90.0,"joy":90.0,"rental":false,"lesson":false}
	guest.service_history={}
	return guest
func restaurant(model: RefCounted) -> Dictionary:
	var built: Dictionary=model.build_building("restaurant",Vector2(155,300))
	check(built.ok,"A restaurant can be built on an actual connected forecourt")
	return model.buildings[-1]
func run() -> void:
	L.configure("de")
	_planning()
	_actual_visits()
	_availability()
	_capacity()
	_migration()
	print("ROUTES AND SERVICES: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
func _planning() -> void:
	var model:=Resort.new();model.new_game(false);model.terrain=SteepMountain.new()
	var points: Array=[[0,0],[0,160]]
	var before:=model.snapshot()
	var direct: Dictionary=model.preview_piste(points)
	var suggested: Dictionary=model.suggest_piste(points)
	check(direct.ok and direct.difficulty==2,"A steep direct descent has its actual automatic classification")
	check(suggested.ok and suggested.grade<=30.01 and suggested.points.size()>2,"The planner finds a genuinely gentler traverse on a steep hillside")
	if suggested.ok:
		check(Terrain.unpack(suggested.points[0])==Terrain.unpack(points[0]) and Terrain.unpack(suggested.points[-1])==Terrain.unpack(points[-1]),"A suggestion preserves the exact chosen endpoints")
		check(model.preview_piste(suggested.points).ok,"The suggested route passes the same construction validation as a manual plan")
	check(model.snapshot()==before,"Planning suggestions preserve money, assets, guests and simulation state")
	var stop: Array=[[0,0],[65,60],[0,160]]
	var with_stop: Dictionary=model.suggest_piste(stop)
	var retained:=false
	for point in with_stop.get("points",[]): retained=retained or Terrain.unpack(point)==Terrain.unpack(stop[1])
	check(with_stop.ok and retained,"A chosen intermediate waypoint remains a mandatory stop")
	check(not model.suggest_piste([[0,0]]).ok and not model.suggest_piste([[999999,0],[0,160]]).ok,"Incomplete and out-of-bounds proposals fail without mutating the plan")
	model=Resort.new();model.new_game(true)
	var connections: Dictionary=model.preview_piste(model.pistes[0].points).connections
	check(connections.entry and connections.exit,"The preview recognises the real starter lift access and valley return")
	model.set_enabled(int(model.lifts[0].id),false)
	connections=model.preview_piste(model.pistes[0].points).connections
	check(not connections.entry and connections.exit,"A closed lift removes summit access while preserving the valley return")
	check(model.preview_piste([[900,-1000],[1000,-500]]).ok,"A disconnected but valid piste can still be planned for later expansion")
	connections=model.preview_piste([[900,-1000],[1000,-500]]).connections
	check(not connections.entry and not connections.exit,"A remote preview clearly reports both missing connections")
func _actual_visits() -> void:
	var model:=Resort.new();model.new_game(true)
	var food:=restaurant(model)
	var guest:=ready_guest(model)
	check(model.service_route(guest).is_empty(),"A comfortable equipped guest does not make an arbitrary service purchase")
	guest.needs.hunger=85
	var trip:=model.service_route(guest)
	check(visit_id(trip)==int(food.id),"A hungry guest chooses the reachable restaurant instead of arbitrary equipment rental")
	check(not model._checked_itinerary(trip.duplicate(true),0).is_empty(),"The service itinerary contains a valid door visit and a complete real route home")
	var money: float=model.money
	guest.route=trip;guest.leg=0;model._start_leg(guest)
	var walked:=false
	for minute in range(180):
		if guest.phase=="moving" and guest.route.legs[guest.leg].kind=="walk": walked=true
		if food.visits>0: break
		model.advance_minute(false)
	check(walked and food.visits==1,"An unforced simulated guest physically walks to the door and completes the visit")
	check(model.money==money+7 and model.report.services==7 and food.revenue==7,"Only the completed restaurant visit earns its actual fee once")
	check(guest.needs.hunger<=15 and guest.needs.energy>90,"Eating restores the guest's actual hunger and energy")
	check(visit_id(model.service_route(guest))!=int(food.id),"A completed visit is not immediately booked again")
	guest.needs.hunger=85;guest.age+=60
	check(visit_id(model.service_route(guest))==int(food.id),"New hunger permits another visit after a genuine cooldown even if the guest spent money earlier")
	guest.needs.hunger=0;guest.needs.warmth=10
	var warmth:=model.service_route(guest)
	check(visit_id(warmth)==int(model.buildings[0].id),"A cold guest chooses the warming mountain lodge")
	var old_hunger: float=guest.needs.hunger
	Needs.complete(guest,"shelter")
	check(guest.needs.warmth>=65 and guest.needs.hunger==old_hunger,"A warming shelter restores warmth without pretending to serve food")
	guest.needs.rental=true;guest.needs.warmth=90
	check(visit_id(model.service_route(guest))==int(model.buildings[1].id),"A guest needing equipment specifically selects the rental shop")
	Needs.complete(guest,"rental")
	check(not guest.needs.rental,"The actual rental visit fulfils that guest's equipment need")
	guest.needs.energy=5;guest.needs.warmth=20
	Needs.complete(guest,"first_aid")
	check(guest.needs.energy>=60 and guest.needs.warmth>=55,"Mountain rescue offers a real warm recovery stop for exhausted guests")
	model.minute=1079;guest.needs.hunger=100
	check(model.service_route(guest).is_empty(),"Guests do not begin a service trip that cannot finish before closing")
func _availability() -> void:
	var model:=Resort.new();model.new_game(true)
	var food:=restaurant(model);var guest:=ready_guest(model);guest.needs.hunger=90
	model.set_enabled(int(food.id),false)
	check(visit_id(model.service_route(guest))!=int(food.id),"Closed buildings are excluded from need-based choices")
	# Make a separate, legitimately built service island connected by three plazas.
	model=Resort.new();model.new_game(true);model.money=1000000
	var ok:=true
	for at in [Vector2(20,230),Vector2(-90,230),Vector2(-200,230)]:
		ok=ok and model.build_plaza("plaza",at).ok
	var middle: Dictionary=model.walk_areas[1]
	ok=ok and model.build_building("restaurant",Vector2(-250,255)).ok
	check(ok,"A remote restaurant is legitimately connected by a chain of walking plazas")
	food=model.buildings[-1];guest=ready_guest(model);guest.needs.hunger=100
	check(visit_id(model.service_route(guest))==int(food.id),"A hungry guest can choose the connected remote restaurant")
	model.set_enabled(int(middle.id),false)
	check(visit_id(model.service_route(guest))!=int(food.id),"Closing the only foot connection excludes the now-unreachable restaurant")
func _capacity() -> void:
	var model:=Resort.new();model.new_game(true)
	var food:=restaurant(model)
	var capacity:=model.service_capacity(food)
	var overflow: Dictionary={}
	for index in range(capacity+1):
		var guest:=ready_guest(model);guest.needs.hunger=100
		var trip:=model.service_route(guest)
		if index<capacity and visit_id(trip)==int(food.id):
			guest.route=trip;guest.leg=0;model._start_leg(guest)
		else: overflow=trip
	check(model.service_load(int(food.id))==capacity,"Capacity includes actual visitors and guests already walking to the restaurant")
	check(visit_id(overflow)!=int(food.id),"Further guests choose alternatives rather than overbooking a full building")
func _migration() -> void:
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.10-starter.json"))
	var model:=Resort.new()
	check(old.version==10 and old.guests.size()>0 and model.restore(old).ok,"A real populated save from the published 0.10 source migrates successfully")
	var preserved: bool=model.guests.size()==old.guests.size() and model.money==old.money and model.minute==old.minute
	for index in range(model.guests.size()):
		var guest: Dictionary=model.guests[index]
		preserved=preserved and guest.id==old.guests[index].id and guest.sport==old.guests[index].sport and guest.elapsed==old.guests[index].elapsed and Needs.valid(guest)
	check(preserved,"Migration preserves identities, sports, progress, funds and clock while initialising valid needs")
	var copy:=Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok and copy.snapshot().version==12,"Needs, service history and real itineraries survive a format 12 JSON roundtrip")
	for minute in range(80): model.advance_minute(false);copy.advance_minute(false)
	check(model.money==copy.money and model.total_rides==copy.total_rides and model.guests.size()==copy.guests.size(),"Need-based visits continue deterministically after saving")
	var damaged:=model.snapshot()
	if not damaged.guests.is_empty():
		damaged.guests[0].needs.hunger=101
		check(not copy.restore(damaged).ok,"Out-of-range needs are rejected without replacing a working save")
		damaged=model.snapshot();damaged.guests[0].service_history={"restaurant":damaged.guests[0].age+1}
		check(not copy.restore(damaged).ok,"Impossible future service history is rejected during save validation")
