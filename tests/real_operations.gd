extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Ops = preload("res://src/core/operations.gd")
const Geo = preload("res://src/core/real_resorts.gd")
const Maps = preload("res://src/core/maps.gd")
const Terrain = preload("res://src/core/terrain.gd")
var passed := 0
var failed := 0

func check(value: bool, message: String) -> void:
	if value: passed += 1
	else:
		failed += 1
		print("FAIL: ", message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	for id in Geo.IDS:
		var model := Resort.new()
		var started := Time.get_ticks_msec()
		model.new_game(true, 20261029, id)
		print("REAL_MAP ", id, " lifts=", model.lifts.size(), " pistes=", model.pistes.size(), " services=", model.buildings.size(), " staff=", model.operations.staff.size(), " ms=", Time.get_ticks_msec() - started)
		check(model.map_id == id and model.terrain.height(Terrain.BASE) > 400, id + " real elevations")
		check(model.lifts.size() >= 6 and model.pistes.size() >= 15, id + " imported inventory")
		check(model.buildings.size() >= 2, id + " playable base services")
		check(model.lifts.all(func(l): return Geo.exact_import(l, id, false)), id + " exact OSM provenance")
		check(model.pistes.all(func(p): return Geo.exact_import(p, id, true)), id + " exact piste provenance")
		check(Ops.continuous(model), id + " continuous simulation")
		check(not Ops.staffing(model, model.lifts[0]).ok, id + " actionable staffing problem")
		check(Ops.fill_stations(model, int(model.lifts[0].id)).ok, id + " hire station team")
		check(Ops.staffing(model, model.lifts[0]).ok, id + " station minimum enforced")
		var fault: Dictionary = model.lifts[1]
		check(not model.lift_open(fault), id + " failed plant is unavailable")
		check(not Ops.repair(model, int(fault.id)).ok, id + " repairs need staffed workshop")
		var budget: float = model.money
		model.advance_minute(false)
		check(model.report.costs > 0 and model.operations.payroll > 0, id + " minute payroll")
		model.minute = 1438
		var day: int = model.day
		model.advance_minute(false)
		model.advance_minute(false)
		check(model.day == day + 1 and model.minute == 0 and not model.day_finished(), id + " uninterrupted midnight")
		check(model.operations.history.size() == 1 and model.last_report.day == day, id + " automatic report")
		var loaded := Resort.new()
		var snapshot: Dictionary = model.snapshot()
		var restored: Dictionary = loaded.restore(snapshot)
		check(restored.ok, id + " geographic save restore: " + restored.message)
		if restored.ok:
			check(loaded.operations.staff.size() == model.operations.staff.size() and loaded.minute == model.minute, id + " staff and midnight preserved")
		if id == "braunlage":
			var sections := model.lifts.filter(func(l): return l.get("sections", 1) > 1)
			check(sections.size() >= 2, "Wurmberg middle station is split into rideable sections")
			var keys: Array = []
			for section in sections:
				for station in Ops.station_demands(section): keys.append(station.key)
			check(keys.size() > keys.reduce(func(sum_value, key): return sum_value + (1 if keys.count(key) == 1 else 0), 0), "middle station shares staffing")
		# Geographic data must yield complete playable circuits after the player
		# fixes the advertised staffing and repair problems.
		model.minute = model.OPENING
		model.weather_index = 0
		for lift in model.lifts:
			Ops.fill_stations(model, int(lift.id), true)
			lift.fault = ""
		Ops.refresh_duty(model)
		model._operational_change()
		for skill in [0, 1, 2]:
			check(not model.routes_for(skill).is_empty(), id + " complete circuits for ability " + str(skill))
			check(model.admit_guest(skill), id + " actual geographic day-trip admission for ability " + str(skill))
		check(Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, id + " populated geographic save roundtrip")
	# Test work orders in a controlled classic valley, independently of OSM
	# completeness, provider names or the shapes of a particular imported map.
	var model := Resort.new()
	model.new_game(false)
	model.money = 2000000
	check(model.build_lift("chair2", Vector2(210, 170), Vector2(200, -190)).ok, "work-order lift")
	Ops.enable(model)
	var victim: Dictionary = model.lifts[0]
	victim.fault = "electrical"
	var built := model.build_building("repair_office", Vector2(150, 265))
	check(built.ok, "build real workshop")
	if built.ok:
		var workshop: Dictionary = model.buildings[-1]
		check(Ops.fill_building(model, int(workshop.id)).ok, "hire technician and electrician")
		check(Ops.repair(model, int(victim.id)).ok, "start repair with parts")
		for i in range(50): model.advance_minute(false)
		check(victim.fault == "" and model.operations.repairs_done == 1, "repair completes only after actual work")
		var malformed: Dictionary = model.snapshot()
		malformed.operations.staff[0].wage = -2
		var other := Resort.new()
		check(not other.restore(malformed).ok, "reject corrupted operating state")
	var first := Resort.new()
	first.new_game(true)
	Ops.enable(first)
	var second := Resort.new()
	var start_snapshot := first.snapshot()
	check(second.restore(start_snapshot).ok, "save deterministic model")
	check(first.restore(start_snapshot).ok, "same restored starting state")
	for i in range(20): first.advance_minute(false)
	for batch in range(5):
		for i in range(4): second.advance_minute(false)
	check(first.snapshot() == second.snapshot(), "1x and 4x fixed-step operating results are identical")
	print("OPERATIONS: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
