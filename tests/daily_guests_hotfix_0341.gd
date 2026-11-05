extends SceneTree
## 0.34.1 regression: real guests after midnight and staggered hotel mornings.
## Runs exclusively in Godot; no dummy ticket or invisible visitor counter.
const Resort = preload("res://src/core/resort.gd")
const Ops = preload("res://src/core/operations.gd")
const Lodging = preload("res://src/core/guest_lodging.gd")
var passed := 0
var failed := 0

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ",message)
	else:
		failed += 1
		push_error("FAIL "+message)

func _init() -> void:
	call_deferred("run")

func starter() -> RefCounted:
	var model := Resort.new()
	model.new_game(true,20261105,"sonnenhang")
	Ops.enable(model)
	model.weather_index=0
	Ops.refresh_duty(model)
	model._operational_change()
	return model

func next_morning(model: RefCounted) -> void:
	model.minute=1440
	Ops.midnight(model)
	model.minute=model.OPENING-1
	model.weather_index=0
	Ops.refresh_duty(model)
	model._operational_change()

func run() -> void:
	var model := starter()
	check(model.routes_for(0).size()>0,"Operational first-day starter has at least one real blue route")
	var first_snow:float=float(model.pistes[0].snow)
	model.weather_index=4 # thaw at +4 C
	model.minute=610
	for i in range(120): model.advance_minute(false)
	var melt:float=first_snow-float(model.pistes[0].snow)
	check(melt>0.1 and melt<2.0,"+4 C thaws snow, but no longer destroys a whole resort within hours")
	model.weather_index=0
	next_morning(model)
	check(model.day==2 and model.report.guests==0,"Real day-two report starts empty rather than inheriting old guests")
	var money_before:float=model.money
	var total_before:int=model.total_guests
	model.advance_minute(true) # actual 08:00 first morning minute
	check(model.routes_for(0).size()>0,"Operational skiable access returns as scheduled at 08:00")
	check(int(model.report.guests)>0 and model.total_guests>total_before and model.guests.size()>0,"A real first visitor arrives at the start of day two")
	check(model.money>money_before and model.report.tickets>0.0,"Only admitted guests pay once for actual tickets")
	var day2:Dictionary=JSON.parse_string(JSON.stringify(model.snapshot()))
	var copy:=Resort.new()
	check(copy.restore(day2).ok and copy.total_guests==model.total_guests,"Hotfix visitor state survives a saved career roundtrip")
	next_morning(model)
	model.advance_minute(true)
	check(model.day==3 and model.report.guests>0,"A real visitor is admitted again on the third winter day")
	var closed:=starter()
	next_morning(closed)
	# A closed lift can still leave a legitimate walk-in route; an
	# explicitly closed PISTE cannot create a ski ticket and a false guest.
	for lift in closed.lifts: lift.enabled=false
	for piste in closed.pistes: piste.enabled=false
	closed._operational_change()
	closed._invalidate()
	var protected_cash:float=closed.money
	var old_total:int=closed.total_guests
	closed.advance_minute(true)
	print("CLOSED_SLOPES_DIAG guests=",closed.report.guests," total_delta=",closed.total_guests-old_total," tickets=",closed.report.tickets," cash_delta=",closed.money-protected_cash," slopes_open=",closed.pistes.filter(func(p):return closed.piste_open(p)).size()," route_count=",closed.routes_for(0).size())
	check(closed.report.guests==0 and closed.total_guests==old_total and is_zero_approx(float(closed.report.tickets)),"Closed slopes cannot generate visitors or ticket revenue")
	var times:Dictionary={}
	var hotel:Dictionary={"lodging_id":23}
	for i in range(1,33):
		var guest:Dictionary={"id":i,"lodging_id":23}
		var time:int=Lodging.morning_departure_minute(guest,2)
		check(time>=420 and time<=539,"Individual hotel departure stays in 07:00–08:59")
		times[time]=true
	check(times.size()>=22,"Individual guests leave across many different morning minutes")
	var adult:Dictionary={"id":12,"party_id":12,"lodging_id":23}
	var child:Dictionary={"id":87,"guardian_id":12,"party_id":12,"lodging_id":23}
	check(Lodging.morning_departure_minute(adult,2)==Lodging.morning_departure_minute(child,2),"Family members share an agreed morning departure time")
	var resort:=Resort.new()
	resort.new_game(true,20261105,"braunlage")
	for lift in resort.lifts:
		lift.fault=""
	for lift in resort.lifts.slice(0,mini(4,resort.lifts.size())): Ops.fill_stations(resort,int(lift.id),true)
	Ops.refresh_duty(resort)
	resort._operational_change()
	check(resort.admit_guest(0,"blue"),"Hotel test starts with one genuinely admitted real-resort visitor")
	if not resort.guests.is_empty():
		var occupant:Dictionary=resort.guests[0]
		check(occupant.has("lodging_id"),"Admitted tourist has a real connected accommodation")
		if occupant.has("lodging_id"):
			resort.minute=1080
			var route:Dictionary=Lodging.night_route(resort,occupant,"base")
			if not route.is_empty():
				occupant.route=route
				for ix in range(route.legs.size()):
					if route.legs[ix].kind=="visit":
						occupant.leg=ix
						occupant.hotel_night=true
						occupant.heading_home=true
						resort._start_leg(occupant)
						resort._continue_leg(occupant,route.legs[ix])
						break
				check(occupant.phase=="waiting" and occupant.get("waiting_reason","")=="hotel","Tourist sleeps inside the booked hotel")
				Ops.midnight(resort)
				var planned:int=Lodging.morning_departure_minute(occupant,resort.day)
				resort.minute=planned-1
				Lodging.wake(resort,occupant)
				check(occupant.phase=="waiting","Resident does not leave before assigned morning departure")
				resort.minute=planned
				resort.weather_index=0
				resort._operational_change()
				var cash_before:float=resort.money
				Lodging.wake(resort,occupant)
				if occupant.phase=="waiting":
					check(is_equal_approx(resort.money,cash_before),"Failed morning itinerary cannot sell a duplicate day ticket")
				var morning:Dictionary=JSON.parse_string(JSON.stringify(resort.snapshot()))
				check(Resort.new().restore(morning).ok,"Hotel sleeper or morning departure saves without corrupting accommodation")
	print("HOTFIX 0.34.1: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
