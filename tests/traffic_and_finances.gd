extends SceneTree
## Regression: a slow/resting skier cannot block an entire piste.
## Shops show net sales less their own incurred wages and overhead.
const Traffic = preload("res://src/core/guest_traffic.gd")
const Motion = preload("res://src/core/ski_motion.gd")
const Ops = preload("res://src/core/operations.gd")
const Resort = preload("res://src/core/resort.gd")
var passed := 0
var failed := 0

class MockTraffic extends RefCounted:
	var guests: Array = []
	var slope := {"id": 81, "length": 1200.0, "width": 24.0, "level": 1}
	func asset(_id: int) -> Dictionary:
		return slope
	func ski_fraction(_leg: Dictionary, progress: float, _samples: Array = []) -> float:
		return clampf(progress, 0, 1)

func check(ok: bool, title: String) -> void:
	if ok: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)

func skier(id: int, progress: float, duration: float) -> Dictionary:
	var leg := {"kind": "ski", "id": 81, "minutes": duration, "start_fraction": 0.0, "end_fraction": 1.0}
	return {"id": id, "phase": "moving", "incident": -1, "leg": 0,
		"route": {"legs": [leg]}, "elapsed": progress * duration,
		"duration": duration, "ski_motion": []}

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var mock := MockTraffic.new()
	var stopped := skier(2, 0.501, 1000000.0)
	var overtaking := skier(5, 0.498, 100.0)
	var another := skier(8, 0.492, 100.0)
	mock.guests = [stopped, overtaking, another]
	var first := Traffic.steps(mock)
	check(float(first[2]) * float(mock.slope.length) / float(stopped.duration) < 0.02, "Resting guest advances less than two centimetres per simulation tick")
	check(float(first[5]) > 0.9 and int(overtaking.traffic_lane) != int(stopped.traffic_lane), "Fast guest overtakes a stopped guest on a free lane")
	check(float(first[8]) > 0.0, "Third guest keeps moving instead of freezing in an entire queue")
	check(absf(float(overtaking.traffic_lateral) - float(stopped.traffic_lateral)) > 2.0, "Passing uses physical separation from the slower skier")
	var subsequent := Traffic.steps(mock)
	check(float(subsequent[5]) > 0.9, "Passing choice stays stable across successive traffic calculations")
	var narrow := MockTraffic.new()
	narrow.slope.width = 9.0
	narrow.guests = [skier(2, 0.501, 1000000.0), skier(4, 0.499, 100.0)]
	var slowed := Traffic.steps(narrow)
	check(float(slowed[4]) < 0.5, "A genuinely narrow single lane preserves safe headway")
	var model := Resort.new()
	model.new_game(true, 20261027, "sonnenhang")
	if not Ops.active(model): Ops.enable(model)
	var building: Dictionary = model.buildings[0]
	model.minute = 720
	building.daily_revenue = 420.0
	model.operations.cost_centres["building:%d" % int(building.id)] = 62.0
	var positive: Dictionary = Ops.business_balance(model, building)
	check(positive.sales == 420.0 and positive.wages == 62.0 and positive.net > 0, "Restaurant or shop can earn a black positive result")
	check(positive.overhead > 0 and positive.costs == positive.wages + positive.overhead, "Own building upkeep is accounted separately from real payroll")
	building.daily_revenue = 0.0
	var negative: Dictionary = Ops.business_balance(model, building)
	check(negative.net < 0 and negative.sales == 0.0, "Unvisited shop displays red negative operating result")
	model.operations.cost_centres["infrastructure"] = 1000000.0
	check(is_equal_approx(Ops.business_balance(model, building).net, negative.net), "Shop result does not absorb unrelated lift and piste costs")
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
