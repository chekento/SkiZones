extends SceneTree
## 0.42 release diagnostic: a live resort graph with 250 simultaneous skiers.
## Normal visitor admission may correctly cap demand; remaining riders are
## isolated stress-only copies of an admitted itinerary, never persisted.
const Resort = preload("res://src/core/resort.gd")
const Ops = preload("res://src/core/operations.gd")
const Traffic = preload("res://src/core/guest_traffic.gd")
const TARGET := 250
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ",label)
	else:
		failed += 1
		push_error("FAIL " + label)

func run() -> void:
	var model := Resort.new()
	model.new_game(true, 20261115, "sonnenhang", true)
	Ops.enable(model)
	model.enable_runtime_rules()
	model.operations.auto_groom = false
	model.money = 2000000.0
	var admitted := 0
	for index in range(TARGET):
		if not model.admit_guest(index % 3):
			break
		admitted += 1
	check(admitted >= 1 and not model.pistes.is_empty() and not model.lifts.is_empty(),
		"Stress fixture has real admitted visitors, ski slopes and lifts")
	if admitted == 0:
		finish()
		return
	var initial: Array = model.guests.duplicate(true)
	var next_id: int = int(model.guest_id)
	while model.guests.size() < TARGET:
		var visitor: Dictionary = initial[model.guests.size() % initial.size()].duplicate(true)
		visitor.id = next_id
		next_id += 1
		visitor.erase("family")
		visitor.erase("party_id")
		visitor.erase("lodging_id")
		visitor.group_size = 1
		visitor.age = 30
		visitor.stay = 720
		visitor.heading_home = false
		visitor.incident = -1
		model.guests.append(visitor)
	model.guest_id = next_id
	# An admitted tourist may choose only food or walking. For the dedicated
	# piste-crowding worst case use one *actual* reachable ski itinerary from
	# the current resort topology, never inventing a virtual piste ID.
	var downhill_route: Dictionary = {}
	for candidate in model.routes_for(0):
		for segment in candidate.get("legs",[]):
			if str(segment.get("kind","")) == "ski":
				downhill_route = candidate.duplicate(true)
				break
		if not downhill_route.is_empty(): break
	check(not downhill_route.is_empty(), "The live resort graph offers a reachable actual ski descent")
	if downhill_route.is_empty():
		finish()
		return
	# All riders are on actual available graph legs, rather than a fake piste.
	var on_piste := 0
	for visitor in model.guests:
		var ski_leg := -1
		for index in range(visitor.route.legs.size()):
			if visitor.route.legs[index].kind == "ski":
				ski_leg = index
				break
		if ski_leg < 0:
			visitor.route = downhill_route.duplicate(true)
			for index in range(visitor.route.legs.size()):
				if visitor.route.legs[index].kind == "ski":
					ski_leg = index
					break
		if ski_leg >= 0:
			visitor.leg = ski_leg
			model._start_leg(visitor)
			visitor.elapsed = float(visitor.duration) * float(int(visitor.id) % 41) / 100.0
			on_piste += 1
	check(model.guests.size() == TARGET and on_piste == TARGET,
		"250 active guests have uniquely identified real resort ski routes")
	model.day = 2
	model.minute = 600
	var movement: Dictionary = Traffic.steps(model)
	check(movement.size() == TARGET and movement.values().all(func(v):return is_finite(float(v)) and float(v) >= 0.0 and float(v) <= 1.0),
		"250 concurrent visitors obtain bounded, finite movement increments")
	var lateral_ok := true
	for visitor in model.guests:
		lateral_ok = lateral_ok and is_finite(float(visitor.get("traffic_lateral",INF))) and absf(float(visitor.get("traffic_lateral",INF))) <= 18.0
	check(lateral_ok, "Large-crowd passing lanes stay within real metre-based slope boundaries")
	var first_tick: int = int(model.motion_tick)
	var max_tick_us: int = 0
	var total_tick_us: int = 0
	var count := 0
	var maximum_resident := 0
	var monotonic := true
	for multiplier in [1,4,8]:
		# An 8x frame runs eight authoritative motion ticks; record actual CPU
		# costs without pretending a headless CI runner measures phone FPS.
		for frame in range(8):
			for tick in range(multiplier):
				var before: int = Time.get_ticks_usec()
				var prior: int = int(model.motion_tick)
				model.advance_minute(false)
				var elapsed_us: int = Time.get_ticks_usec() - before
				max_tick_us = maxi(max_tick_us, elapsed_us)
				total_tick_us += elapsed_us
				count += 1
				monotonic = monotonic and int(model.motion_tick) == prior + 1
				maximum_resident = maxi(maximum_resident, model.guests.size())
	check(monotonic and int(model.motion_tick) == first_tick + count,
		"1x/4x/8x simulated steps never duplicate or skip the motion clock")
	check(model.guests.size() <= TARGET and model.guests.size() >= 1,
		"High-density resort does not duplicate visitors or clear the live world")
	var sane := true
	for visitor in model.guests:
		var route: Dictionary = visitor.get("route",{})
		sane = sane and route.get("legs",[]) is Array
		sane = sane and is_finite(float(visitor.get("elapsed",0))) and float(visitor.get("elapsed",0)) >= 0
	check(sane, "All remaining visitors have finite progress and well-formed routes")
	print("CROWD PERF: source=real_sonnenhang_graph admitted=",admitted,
		" concurrent=",TARGET," ticks=",count,
		" mean_tick_ms=",snappedf(float(total_tick_us)/maxf(count,1)/1000.0,0.001),
		" worst_tick_ms=",snappedf(float(max_tick_us)/1000.0,0.001),
		" remaining=",model.guests.size()," peak=",maximum_resident)
	finish()

func finish() -> void:
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)

func _init() -> void:
	call_deferred("run")
