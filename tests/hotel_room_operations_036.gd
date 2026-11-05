extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Rooms = preload("res://src/core/hotel_rooms.gd")
const Ops = preload("res://src/core/operations.gd")
var passed := 0
var failed := 0
func _init() -> void:call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func run() -> void:
	var model := Resort.new()
	model.new_game(true,20261105)
	model.campaign.mode="free"
	model.money=5000000
	var hotel: Dictionary={}
	for z in range(160,420,34):
		for x in range(70,430,34):
			if model.build_building("hotel",Vector2(x,z)).ok:hotel=model.buildings[-1];break
		if not hotel.is_empty():break
	check(not hotel.is_empty(),"A genuine connected hotel is constructed on the original resort")
	if hotel.is_empty():quit(1);return
	model.campaign.mode="career"
	Ops.enable(model)
	Ops.refresh_duty(model)
	var id: int=int(hotel.id)
	var original := JSON.stringify(model.snapshot())
	check(Rooms.view(model,hotel).rooms.size()==24 and JSON.stringify(model.snapshot())==original,"Reading a legacy hotel never creates or mutates room save fields")
	var money: float=model.money
	check(Rooms.enable(model,id).ok and model.money==money and not Rooms.enable(model,id).ok,"Optional activation is idempotent and never charges a hotel purchase again")
	check(model.admit_guest(0,"family",5) and int(model.guests[0].lodging_id)==id,"An actual five-person family reserves this reachable hotel")
	var view := Rooms.view(model,hotel)
	check(view.occupied==3 and view.ready==21,"Five actual residents share three real fixed rooms")
	var occupied: Dictionary=hotel.room_operations.rooms.filter(func(r):return r.reservation!="")[0]
	check(not Rooms.set_closed(model,id,int(occupied.id),true).ok and not Rooms.move_room(model,id,int(occupied.id),8,3).ok,"Occupied rooms cannot be closed or moved out from under guests")
	var ownership: Array=hotel.room_operations.rooms.map(func(r):return r.reservation)
	model.party_mode=true
	model.Parties.expand(model,model.guests[0])
	Rooms.reconcile(model,hotel)
	check(Rooms.view(model,hotel).occupied==3 and Rooms.view(model,hotel).dirty==0 and hotel.room_operations.rooms.slice(0,3).all(func(r):return str(r.reservation).begins_with("party:")),"Expanding a visible family preserves its existing rooms without false checkouts")
	var snapshot: Dictionary=JSON.parse_string(JSON.stringify(model.snapshot()))
	var copy := Resort.new()
	var restored_result: Dictionary=copy.restore(snapshot)
	check(restored_result.ok and copy.asset(id).room_operations==JSON.parse_string(JSON.stringify(hotel.room_operations)),"Actual family, route and individual room reservations survive a full save roundtrip")
	var before: String=JSON.stringify(copy.snapshot())
	var bad: Dictionary=snapshot.duplicate(true)
	var source: Dictionary=bad.buildings.filter(func(b):return int(b.id)==id)[0]
	source.room_operations.rooms[1].floor=source.room_operations.rooms[0].floor
	source.room_operations.rooms[1].slot=source.room_operations.rooms[0].slot
	check(not copy.restore(bad).ok and JSON.stringify(copy.snapshot())==before,"Duplicate floor coordinates are rejected without changing the live resort")
	bad=snapshot.duplicate(true);source=bad.buildings.filter(func(b):return int(b.id)==id)[0]
	source.room_operations.rooms[0].reservation="party:-3"
	check(not copy.restore(bad).ok,"Forged reservation identifiers fail save validation")
	bad=snapshot.duplicate(true);source=bad.buildings.filter(func(b):return int(b.id)==id)[0]
	source.room_operations.last_service=Ops.clock(model)+1
	check(not copy.restore(bad).ok,"A future cleaning clock cannot freeze housekeeping after loading")
	for guest in model.guests:guest.phase="leaving"
	Rooms.reconcile(model,hotel)
	view=Rooms.view(model,hotel)
	check(view.occupied==0 and view.dirty==3 and Rooms.available(model,hotel)==21,"A real family checkout leaves three dirty rooms unavailable to the next booking")
	var dirty: Array=hotel.room_operations.rooms.filter(func(r):return not r.clean)
	money=model.money
	check(Rooms.clean_room(model,id,int(dirty[0].id)).ok and is_equal_approx(money-model.money,8),"Manual cleaning charges exactly eight euros for one dirty room")
	money=model.money
	check(not Rooms.clean_room(model,id,int(dirty[0].id)).ok and model.money==money,"Repeated cleaning cannot charge a clean room again")
	var free: Dictionary=hotel.room_operations.rooms[-1]
	check(Rooms.set_closed(model,id,int(free.id),true).ok and Rooms.available(model,hotel)==21,"Closing one clean room immediately removes its bookable capacity")
	check(Rooms.set_closed(model,id,int(free.id),false).ok and Rooms.available(model,hotel)==22,"Reopening restores capacity without fabricating additional rooms")
	money=model.money
	check(Rooms.move_room(model,id,int(free.id),8,3).ok and is_equal_approx(money-model.money,250) and free.floor==8,"Moving a free room updates its saved floorplan for the exact quoted price")
	money=model.money
	check(not Rooms.move_room(model,id,int(free.id),8,3).ok and model.money==money,"Repeated remodeling cannot double-charge an unchanged position")
	check(not Rooms.move_room(model,id,int(free.id),0,0).ok,"Two physical rooms cannot occupy the same floorplan position")
	model.operations.staff.clear();Ops.refresh_duty(model)
	hotel.room_operations.last_service=Ops.clock(model)-15
	Rooms.tick(model)
	check(Rooms.view(model,hotel).dirty==2,"An unstaffed hotel cannot silently perform automatic cleaning")
	Ops.fill_building(model,id,true);Ops.refresh_duty(model)
	hotel.room_operations.last_service=Ops.clock(model)-15
	money=model.money
	Rooms.tick(model)
	check(Rooms.view(model,hotel).dirty==0 and model.money==money,"Actual on-duty team cleans within its capacity under the existing cleaning subscription")
	check(Rooms.valid(hotel),"Used room state still satisfies the strict persistent schema")
	for r in hotel.room_operations.rooms.slice(0,2):r.clean=false
	money=model.money
	model.money=0
	var dirty_state: String=JSON.stringify(hotel.room_operations)
	check(not model.Hospitality.housekeeping(model,id).ok and model.money==0 and JSON.stringify(hotel.room_operations)==dirty_state,"An unaffordable group cleaning is rejected atomically without cleaning any rooms")
	model.money=money
	money=model.money
	check(model.Hospitality.housekeeping(model,id).ok and is_equal_approx(money-model.money,16) and Rooms.view(model,hotel).dirty==0,"Existing Clean All action charges only the two genuinely dirty rooms")
	money=model.money
	check(not model.Hospitality.housekeeping(model,id).ok and model.money==money,"Clean All is idempotent when no room needs service")
	model.campaign.mode="free"
	check(model.upgrade_asset(id).ok,"A real hotel upgrade expands the building rather than granting beds through the floorplan editor")
	Rooms.reconcile(model,hotel)
	check(hotel.room_operations.rooms.size()==48 and free.floor==8 and Rooms.valid(hotel),"Actual building upgrade adds valid unique rooms and preserves a moved room")
	var old_hotel: Dictionary=hotel.duplicate(true);old_hotel.erase("room_operations")
	check(Rooms.valid(old_hotel),"Old hotels remain valid without adopting new room operations")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
