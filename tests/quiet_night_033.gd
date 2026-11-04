extends SceneTree
## 0.33 real night pacing: bank future interest without midnight NPC spawns;
## accelerate safe outdoor walking, never incidents/queues, preserve saves.
const Resort = preload("res://src/core/resort.gd")
const Ops = preload("res://src/core/operations.gd")
const DayRhythm = preload("res://src/core/day_rhythm.gd")
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed += 1; print("PASS ",title)
	else: failed += 1; push_error("FAIL "+title)

func fresh() -> RefCounted:
	var model: RefCounted = Resort.new()
	model.new_game(true, 20261104, "sonnenhang")
	Ops.enable(model)
	model.enable_runtime_rules()
	model.campaign.mode="free"
	model.money=1000000.0
	return model

func run() -> void:
	var model: RefCounted = fresh()
	model.minute=1320
	model._operational_change()
	check(model.empty_night(),"No visitors: quiet calendar starts at 22:00")
	var tickets: float=model.report.tickets
	var visitors: int=model.total_guests
	var old_day: int=model.day
	for i in range(1440 - 1320 + model.OPENING - 1):
		if not model.advance_empty_minute(): break
	check(model.day==old_day+1 and model.minute==model.OPENING-1,"Night skips to one minute before the actual lift opening without stalling")
	check(model.total_guests==visitors and model.report.tickets==tickets and model.guests.is_empty(),"Quiet-night demand creates no ghost guests and charges no imaginary ticket")
	check(int(model.operations.pending_arrivals)>=6 and int(model.operations.pending_arrivals)<=24,"Late-night interest is bounded until morning, never infinite arrivals")
	var pending: int=int(model.operations.pending_arrivals)
	var saved: Dictionary=JSON.parse_string(JSON.stringify(model.snapshot()))
	var copy: RefCounted=Resort.new()
	check(copy.restore(saved).ok and int(copy.operations.pending_arrivals)==pending,"Pending dawn arrivals survive an existing-career save and resume")
	var invalid: Dictionary=saved.duplicate(true)
	invalid.operations.pending_arrivals=25
	check(not Resort.new().restore(invalid).ok,"Oversized pending-arrivals injection is rejected atomically")
	invalid=saved.duplicate(true)
	invalid.operations.pending_arrivals=-1
	check(not Resort.new().restore(invalid).ok,"Negative pending-arrivals injection is rejected")
	var old_snapshot: Dictionary=saved.duplicate(true)
	old_snapshot.operations.erase("pending_arrivals")
	var old_copy: RefCounted=Resort.new()
	check(old_copy.restore(old_snapshot).ok and int(old_copy.operations.pending_arrivals)==0,"Legacy 0.32 operations without new field migrate to safe zero")
	var guest_count: int=model.total_guests
	model.advance_empty_minute()
	check(model.minute==model.OPENING and not model.empty_night(),"Morning at actual 08:00 lift opening resumes normal simulation")
	check(int(model.operations.pending_arrivals)<=pending and int(model.operations.pending_arrivals)>=0,"Morning demand is released only within bounded capacity")
	check(model.total_guests-guest_count>=pending-int(model.operations.pending_arrivals),"Every consumed dawn-interest slot corresponds to a real admitted visitor")
	# Actual staffed village: an existing guest walking to night service may
	# continue at calendar speed, but their route stays on physical footpaths.
	var village: RefCounted=fresh()
	var venue: Dictionary={}
	for z in range(240,360,35):
		for x in range(70,330,35):
			if venue.is_empty() and village.build_building("disco",Vector2(x,z)).ok: venue=village.buildings[-1]
	check(not venue.is_empty() and Ops.fill_building(village,int(venue.id)).ok,"A real staffed après-ski venue has a physical access path")
	village.minute=1320
	village._duty_cache.clear()
	village._operational_change()
	check(Ops.admit_evening(village),"Existing after-ski guest receives an actual route rather than a virtual removal")
	if not village.guests.is_empty():
		var guest: Dictionary=village.guests[0]
		var original_id: int=int(guest.id)
		check(guest.route.legs.size()>0 and guest.route.legs[0].kind in ["walk","visit"] and DayRhythm.indoors_only(village),"Foot-only after-ski route permits safe calendar acceleration")
		var ahead: float=guest.elapsed
		check(village.advance_empty_minute(),"Existing guest no longer blocks the night simply for walking to an indoor destination")
		check(village.minute==1321 and guest.elapsed>=ahead,"One accelerated minute moves the actual guest instead of teleporting or freezing")
		guest.incident=7
		check(not village.empty_night(),"A real rescue incident still prevents unsafe fast-forward")
		guest.incident=-1
		guest.phase="queue"
		check(not village.empty_night(),"A real lift queue still prevents unsafe fast-forward")
	_ten_nights()
	_morning_capacity()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)

func _ten_nights() -> void:
	var model: RefCounted = fresh()
	# This fixture isolates nights at a closed resort. No daytime service may
	# admit a guest at 08:00 and then be carried into a later test night.
	for lift in model.lifts: model.set_enabled(int(lift.id), false)
	# Ten consecutive real midnight settlements, including a save/load every
	# night. Daytime is outside this night-pacing fixture, never simulated away.
	for night in range(10):
		model.minute = DayRhythm.QUIET_FROM
		model._operational_change()
		var before_day: int = model.day
		var arrivals: int = model.total_guests
		var steps: int = 0
		while model.empty_night() and steps < 700:
			model.advance_empty_minute()
			steps += 1
		check(steps == 600 and model.day == before_day + 1 and model.minute == model.OPENING, "Night %d reaches opening through exactly one midnight settlement" % (night + 1))
		check(model.total_guests == arrivals and model.guests.is_empty() and model.report.tickets == 0, "Night %d never invents visitors or ticket income without a viable route" % (night + 1))
		check(int(model.operations.pending_arrivals) <= 24, "Night %d keeps unsatisfied demand bounded" % (night + 1))
		var restored: RefCounted = Resort.new()
		var snapshot: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
		check(restored.restore(snapshot).ok and restored.day == model.day and restored.operations.pending_arrivals == model.operations.pending_arrivals, "Night %d survives a morning save and restore" % (night + 1))
		model = restored
	check(model.operations.history.size() == 10, "Ten nights produce ten daily accounts, with no duplicate settlements")

func _morning_capacity() -> void:
	var model: RefCounted = fresh()
	# Seed known, valid demand to isolate the staggered admission from random
	# daytime arrivals; sun and a staffed starter provide an actual ski circuit.
	model.party_mode = false
	model.edge_entries = false
	model.weather_index = 0
	model.minute = model.OPENING - 1
	model.operations.pending_arrivals = 8
	model._operational_change()
	var seeded: int = model.total_guests
	model.advance_minute()
	# Runtime rules require 24 motion steps to advance a displayed minute.
	for step in range(23): model.advance_minute()
	check(not model.routes_for(0).is_empty(), "Morning capacity fixture has an actual usable ski circuit at opening")
	check(model.minute == model.OPENING and model.operations.pending_arrivals == 7 and model.total_guests > seeded, "Opening releases one real arrival rather than the entire morning wave")
	var waiting: int = model.operations.pending_arrivals
	for step in range(11 * model.time_divisor): model.advance_minute(false)
	check(model.operations.pending_arrivals == waiting, "Demand does not create arrivals while admission is disabled")
	model.minute = model.OPENING + 119
	model.clock_steps = 0
	model.clock_fraction = 0.0
	for step in range(model.time_divisor): model.advance_minute(false)
	check(model.operations.pending_arrivals == 0, "Unserved morning interest expires at 10:00 even when arrivals are disabled")
