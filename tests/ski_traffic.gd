extends SceneTree
## Regression for dynamic passing lanes, small headways and long resort crowds.
const Traffic = preload("res://src/core/guest_traffic.gd")
class FakeResort extends RefCounted:
	var guests: Array = []
	var piste := {"id": 7, "length": 100.0, "width": 21.0, "level": 1}
	func asset(id: int) -> Dictionary:
		return piste if id == 7 else {}
	func ski_fraction(_leg: Dictionary, progress: float, _samples: Array = []) -> float:
		return clampf(progress, 0.0, 1.0)

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)

func skier(id: int, elapsed: float, phase: String = "moving") -> Dictionary:
	return {"id": id, "phase": phase, "elapsed": elapsed, "duration": 100.0,
		"route": {"legs": [{"kind": "ski", "id": 7, "start_fraction": 0.0, "end_fraction": 1.0}]},
		"leg": 0}

func run() -> void:
	var model := FakeResort.new()
	check(Traffic.lane_count(model.piste) == 3, "Wide piste provides three distinct passing lanes")
	var leader := skier(0, 21.0)
	var following := skier(3, 20.0)
	model.guests = [leader, following]
	var p: Dictionary = Traffic.steps(model)
	check(p.has(0) and p.has(3), "Both skiers receive deterministic progress")
	check(p[3] > 0.9, "Behind a slower skier, following skier overtakes rather than waiting")
	check(int(leader.traffic_lane) != int(following.traffic_lane), "Passing skiers use separate rendered channels")
	check(absf(float(following.traffic_lateral) - float(leader.traffic_lateral)) >= 3.0, "Lane separation is several real metres, not just another ID")
	check(absf(float(following.traffic_lateral)) <= model.piste.width * 0.43, "Passing stays safely inside piste boundaries")
	var first := JSON.stringify({"progress": p, "lanes": [leader.traffic_lane, following.traffic_lane]})
	var next := Traffic.steps(model)
	check(first == JSON.stringify({"progress": next, "lanes": [leader.traffic_lane, following.traffic_lane]}), "Same inputs yield stable traffic and lane assignments")
	model.guests = []
	for i in range(240):
		model.guests.append(skier(i, 10.0 + float(i % 40)))
	var large := Traffic.steps(model)
	check(large.size() == 240, "Large scenario crowd is processed without dropping visitors")
	check(large.values().all(func(step): return step >= 0.0 and step <= 1.0), "Crowded slope never reverses skiers or exceeds personal speed")
	var waiting := skier(999, 20.0, "waiting")
	model.guests = [waiting, skier(30, 19.0)]
	var moving := Traffic.steps(model)
	check(not moving.has(999) and moving[30] > 0.0, "One stopped group cannot freeze the entire piste")
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
