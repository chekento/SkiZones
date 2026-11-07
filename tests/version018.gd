extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Terrain=preload("res://src/core/terrain.gd")
const Foot=preload("res://src/core/foot_network.gd")
const Access=preload("res://src/core/resort_access.gd")
const Catalog=preload("res://src/core/catalog.gd")
const Ops=preload("res://src/core/operations.gd")
const L=preload("res://src/core/i18n.gd")
var passed:=0
var failed:=0
class FlatMountain extends "res://src/core/mountain.gd":
	func height(_point: Vector2) -> float:return 80
class SlopedMountain extends "res://src/core/mountain.gd":
	func height(point: Vector2) -> float:return 300-point.y*0.2
func check(ok: bool, title: String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func _init() -> void:
	L.configure("de")
	var model:=Resort.new();model.new_game(false);model.terrain=FlatMountain.new();model.money=3000000
	check(model.preview_lift("chair2",Vector2(-200,0),Vector2(-60,0)).ok,"A flat transfer lift is buildable")
	check(model.preview_lift("carpet",Vector2(50,0),Vector2(80,0)).ok,"A compact 30 m carpet fits its actual machinery")
	var short:=model.preview_lift("chair2",Vector2(50,0),Vector2(60,0))
	check(not short.ok and short.message.contains("10 m") and short.message.contains("mindestens"),"A short lift reports measured and required distances")
	var snapshot:=model.snapshot()
	check(not model.build_lift("chair2",Vector2(50,0),Vector2(60,0)).ok and snapshot==model.snapshot(),"An invalid plan spends no money and changes no assets")
	model.terrain=SlopedMountain.new()
	var high:=Vector2(-200,-100);var low:=Vector2(-200,200)
	var reversed:=model.preview_lift("chair2",high,low)
	check(reversed.ok and reversed.reversed_ends and Terrain.unpack(reversed.bottom)==low and Terrain.unpack(reversed.top)==high,"Reverse clicks are assigned to valley and summit automatically")
	check(model.build_lift("chair2",high,low).ok and Terrain.unpack(model.lifts[-1].bottom)==low,"The confirmed lift uses the preview's canonical station order")
	var anchors:=model.lift_build_anchors("chair2")
	check(anchors.size()>=2,"Existing stations expose separate adjacent lift sites")
	var clear:=true
	for anchor in anchors:
		for lift in model.lifts:
			for end in [lift.bottom,lift.top]:clear=clear and anchor.point.distance_to(Terrain.unpack(end))>=Foot.machine_radius(lift)+Foot.machine_radius({"kind":"chair2"})+4
	check(clear,"Every docking site preserves machinery clearance")
	check(not anchors.is_empty() and model.snap_lift_station(anchors[0].point+Vector2(3,0),"chair2",10).point==anchors[0].point,"Nearby clicks snap exactly to the indicated safe site")
	check(model.snap_lift_station(Vector2(900,900),"chair2",10).is_empty(),"Distant clicks are never magnetised to unrelated stations")
	model=Resort.new();model.new_game(true);model.enable_runtime_rules()
	var lift: Dictionary=model.lifts[0];var summit:=Terrain.unpack(lift.top)
	var connected:=false
	for anchor in model.lift_build_anchors("drag"):
		if anchor.point.distance_to(summit)>80:continue
		var proposed: Dictionary={"kind":"drag","bottom":Terrain.pack(anchor.point),"top":Terrain.pack(anchor.point+Vector2(50,-180))}
		var path:=Access.lift_connection(model,proposed)
		connected=connected or not path.is_empty() and path.length<180 and Foot.clear_walk(path.points,model.buildings,model.lifts+[proposed])
	check(connected,"An upper extension has a real short pedestrian connection from the existing summit")
	var order:=Catalog.building_order()
	check(order.has("kiosk") and order.find("kiosk")<order.find("cocoa") and order.find("cocoa")<order.find("hotel") and order.find("pizzeria")<order.find("repair_office"),"Affordable food services precede larger hospitality and repair investments")
	var complete:=order.size()==Catalog.BUILDINGS.keys().filter(func(kind):return Catalog.purchasable(str(kind))).size()
	for kind in Catalog.BUILDINGS:complete=complete and order.count(kind)==int(Catalog.purchasable(kind))
	check(complete,"The price-sorted village catalog contains every service exactly once, including new businesses")
	var sorted:=true
	for i in range(1,order.size()):sorted=sorted and Catalog.BUILDINGS[order[i-1]].cost<=Catalog.BUILDINGS[order[i]].cost
	check(sorted,"Village prices are consistently ascending")
	for kind in ["cocoa","schmarrn","pizzeria"]:_food(kind)
	model=Resort.new();model.new_game(true,20261031,"braunlage");model.money=3000000
	var sections: Array=model.lifts.filter(func(part):return int(part.get("sections",1))>1)
	var upper: Dictionary=sections[-1]
	model.operations.staff.clear();model._duty_cache.clear()
	var rows:=Ops.line_station_team(model,upper)
	check(rows.size()==3 and rows[0].name=="Talstation" and rows[1].name=="Mittelstation" and rows[2].name=="Bergstation","Opening the upper section exposes all three unique stations")
	var needed:=0
	for row in rows:needed+=row.minimum
	var budget: float=model.money
	check(Ops.fill_line(model,int(upper.id)).ok and model.operations.staff.size()==needed and model.money==budget-needed*180,"Whole-line hiring charges each unique vacancy once")
	check(Ops.line_lifts(model,upper).all(func(part):return Ops.staffing(model,part).ok),"One middle-station team operates both adjoining sections")
	budget=model.money
	check(Ops.fill_line(model,int(upper.id)).ok and model.money==budget and model.operations.staff.size()==needed,"Repeated whole-line hiring cannot duplicate teams")
	rows=Ops.line_station_team(model,upper);var person: Dictionary=rows[1].people[0]
	person.break_until=Ops.clock(model)+30;model._duty_cache.clear()
	check(Ops.line_station_team(model,upper)[1].missing==0 and not Ops.on_duty(model,person),"A break changes attendance while retaining the planned post")
	model.operations.staff.clear();model._duty_cache.clear();model.money=100
	check(not Ops.fill_line(model,int(upper.id)).ok and model.operations.staff.is_empty() and model.money==100,"Unaffordable whole-line recruitment is atomic")
	print("VERSION018: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
func _food(kind: String) -> void:
	var model:=Resort.new();model.new_game(true);model.money=3000000;Ops.enable(model)
	for existing in model.buildings:model.set_enabled(int(existing.id),false)
	var built:=model.build_building(kind,Vector2(155,300))
	check(built.ok,kind+" builds at a real connected village site")
	if not built.ok:return
	var food: Dictionary=model.buildings[-1]
	check(Ops.building_roles(kind)==["catering"] and not Ops.building_open(model,food),kind+" needs a real catering employee")
	check(Ops.fill_building(model,int(food.id)).ok and Ops.building_open(model,food),kind+" opens after its own team is hired")
	var budget: float=model.money
	check(Ops.fill_building(model,int(food.id)).ok and model.money==budget,kind+" repeated hiring costs nothing")
	check(model.admit_guest(0),kind+" has an actual admitted visitor")
	var guest: Dictionary=model.guests[-1]
	guest.needs={"hunger":90.0,"warmth":12.0,"energy":40.0,"joy":70.0,"rental":false,"lesson":false};guest.service_history={}
	var expected_sale: Dictionary=model.Hospitality.pizza_sale(food,guest) if kind=="pizzeria" else model.BuildingOffers.visit_sale(food,guest)
	var trip:=model.service_route(guest)
	check(trip.get("legs",[]).any(func(leg):return leg.kind=="visit" and int(leg.id)==int(food.id)),kind+" attracts a hungry cold guest through the real route graph")
	if not trip.is_empty():
		guest.route=trip;guest.leg=0;model._start_leg(guest)
		for i in range(350):
			model.advance_minute(false)
			if food.get("visits",0)>0:break
	check(food.get("visits",0)==1 and is_equal_approx(float(food.get("revenue",0)),float(expected_sale.revenue)),kind+" charges exactly the selected completed-visit product without a second flat fee")
	check(is_equal_approx(float(model.operations.cost_centres.get("supplies:%d" % int(food.id),0)),float(expected_sale.cost)),kind+" records the actual ingredients once, separately from payroll")
	check(guest.needs.hunger<90 and guest.needs.warmth>12,kind+" really fulfils hunger and warmth needs")
	var copy:=Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok and copy.buildings.any(func(b):return b.kind==kind),kind+" and its staff and guest visits survive save format 16")
