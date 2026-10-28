extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Foot = preload("res://src/core/foot_network.gd")
const Corridor = preload("res://src/world/piste_mesh.gd")
var passed := 0
var failed := 0

func check(value: bool, title: String) -> void:
	if value:
		passed += 1; print("PASS ", title)
	else:
		failed += 1; push_error("FAIL " + title)

func _init() -> void:
	var model := Resort.new(); model.new_game(true); model.money = 1000000
	var lift: Dictionary = model.lifts[0]
	check(Foot.station_radius(lift, true) >= 66 and Foot.station_radius(lift, false) >= 84, "Both stations have generous walking areas")
	var a := Terrain.unpack(lift.bottom) + Vector2(-45, 0)
	var b := Terrain.unpack(lift.bottom) + Vector2(45, 0)
	var detour := Foot.path_between(a, b, model.buildings, model.lifts)
	check(detour.size() > 2 and Foot.clear_walk(detour, model.buildings, model.lifts), "Crossing the drag lift requires a real detour around its terminal")
	check(not Foot.valid_walk(model.pedestrian_layout(), [Terrain.pack(a), Terrain.pack(b)], model.buildings), "The direct shortcut through the drag lift is not walkable")
	var safe := true
	for skill in range(3):
		for route in model.routes_for(skill):
			for leg in route.legs:
				if leg.kind == "walk":
					safe = safe and Foot.valid_walk(model.pedestrian_layout(), leg.points, model.buildings)
	check(safe and not model.routes_for(0).is_empty(), "Every actual guest walking leg clears buildings and lift machinery")
	var queues_safe := true
	for i in range(360):
		var point := model.queue_position(lift, i)
		queues_safe = queues_safe and Foot.contains(model.pedestrian_layout(), Vector2(point.x, point.z))
	check(queues_safe, "All 360 queue slots stay outside the lift footprint")
	check(not model.preview_plaza("plaza", Terrain.unpack(lift.bottom)).ok, "A manually placed plaza cannot be centered inside lift machinery")
	model.new_game(false); model.money = 1000000
	var money: float = model.money
	check(model.build_plaza("path", Vector2(260, 300)).ok and model.build_plaza("plaza", Vector2(340, 300)).ok, "Walking areas can be built independently and chained")
	check(model.walk_areas.size() == 2 and model.money < money, "Independent walking areas have actual construction costs")
	check(Foot.contains(model.pedestrian_layout(), Vector2(340, 300)), "The newly built plaza is part of the actual navigation surface")
	check(model.preview_building("lodge", Vector2(400, 290)).ok, "Buildings attach to an independently built plaza")
	var copy := Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok and copy.walk_areas.size() == 2, "Manually built areas survive a validated JSON save round trip")
	var broken := model.snapshot(); broken.walk_areas[0].radius = 9000
	check(not copy.restore(broken).ok and copy.walk_areas.size() == 2, "A corrupt plaza radius cannot replace the current resort")
	check(model.demolish(model.walk_areas[0].id).ok and model.walk_areas.size() == 1, "Walking areas can also be demolished")
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.5-starter.json"))
	var old_money: float = previous.money
	var old_visitors: int = previous.guests.size()
	check(copy.restore(previous).ok and copy.guests.size() == old_visitors and copy.money == old_money, "An actual populated 0.5 save migrates without losing visitors or money")
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(copy.snapshot()))).ok, "The migrated 0.5 resort can be saved again in format 6")
	_geometry(model)
	_balance()
	print("BUILD COMFORT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _geometry(model: RefCounted) -> void:
	for points in [ [[0,0],[120,0],[40,30],[160,60]], [[0,0],[100,0],[0,18],[100,36]], [[0,0],[60,0],[60,60],[120,60]] ]:
		var samples := Corridor.samples(model.terrain, points, 20)
		var winding := true
		var valid := true
		for i in range(0, samples.size(), 3):
			var a: Vector2 = samples[i].point; var b: Vector2 = samples[i+1].point; var c: Vector2 = samples[i+2].point
			winding = winding and (b-a).cross(c-a) > 0
			valid = valid and a.is_finite() and b.is_finite() and c.is_finite()
		var covered := true
		for step in range(1, 30):
			var at: Vector2 = model.terrain.point_on_path(points, float(step) / 30)
			var hit := false
			for i in range(0, samples.size(), 3):
				var a: Vector2 = samples[i].point; var b: Vector2 = samples[i+1].point; var c: Vector2 = samples[i+2].point
				if (b-a).cross(at-a) >= -0.001 and (c-b).cross(at-b) >= -0.001 and (a-c).cross(at-c) >= -0.001:
					hit = true; break
			covered = covered and hit
		check(not samples.is_empty() and winding and valid, "Tight curve mesh has finite, consistently facing triangles")
		check(covered, "The whole centerline, including hairpins, has continuous snow beneath it")

func _balance() -> void:
	var model := Resort.new(); model.new_game(true)
	check(model.operating_costs() < 2400 and model.money > 150000, "A starter resort has modest overhead and retains expansion money")
	var baseline: float = model.arrival_capacity_factor()
	for i in range(80):
		model.admit_guest(0)
	for guest in model.guests:
		for index in range(guest.route.legs.size()):
			if guest.route.legs[index].kind == "lift": guest.leg = index; break
		model._start_leg(guest)
	check(model.arrival_capacity_factor() < baseline and model.arrival_capacity_factor() >= 0.35, "High queues reduce arrivals without switching demand off")
	model.new_game(true)
	var start: float = model.money
	var peak := 0
	var income := 0.0
	var costs := 0.0
	for day in range(7):
		while not model.day_finished():
			model.advance_minute(); peak = maxi(peak, model.queue_size())
		income += model.last_report.tickets + model.last_report.services
		costs += model.last_report.costs
		if day < 6: model.next_day()
	print("WEEK METRICS guests=%d rides=%d peak_queue=%d income=%.0f costs=%.0f cash=%.0f" % [model.total_guests,model.total_rides,peak,income,costs,model.money])
	check(model.total_guests > 250 and model.total_rides > 250 and peak < 100, "A full starter week has actual skiing and bounded queues")
	check(income > costs and model.money >= start, "An unchanged starter resort can cover its operating costs across a full week")
