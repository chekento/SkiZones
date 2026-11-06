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
	check(Traffic.lane_count(model.piste) == 5, "A normal 21m piste supports five safe real-metre passing corridors")
	model.piste.width = 30.0
	check(Traffic.lane_count(model.piste) == 7, "Wide upgraded pistes keep seven real-metre passing corridors")
	model.piste.width = 10.0
	check(Traffic.lane_count(model.piste) == 2, "Narrow 10m pistes support two distinct safe passing corridors")
	model.piste.width = 9.0
	check(Traffic.lane_count(model.piste) == 1, "A truly narrow piste never fabricates unsafe passing width")
	model.piste.width = 21.0
	var leader := skier(0, 21.0)
	var following := skier(4, 20.0)
	model.guests = [leader, following]
	var p: Dictionary = Traffic.steps(model)
	check(p.has(0) and p.has(4), "Both skiers receive deterministic progress")
	check(p[4] > 0.9, "Behind a slower skier, following skier overtakes rather than waiting")
	check(int(leader.traffic_lane) != int(following.traffic_lane), "Passing skiers use separate rendered channels")
	check(absf(float(following.traffic_lateral) - float(leader.traffic_lateral)) >= 3.0, "Lane separation is several real metres, not just another ID")
	check(absf(float(following.traffic_lateral)) <= model.piste.width * 0.43, "Passing stays safely inside piste boundaries")
	var pressure: Dictionary = Traffic.load_by_piste(model)
	check(int(pressure.get(7,0)) == 2, "Route congestion counts active skiers without counting each leg twice")
	check(Traffic.route_pressure(model, model.piste, pressure) < 1.0 and Traffic.route_pressure(model, model.piste, {7:100}) < Traffic.route_pressure(model, model.piste, pressure), "Overcrowding reduces destination preference without zeroing usable routes")
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
	# Reproduce a busy resort that formerly formed immobile human chains:
	# release all riders using only their permitted lane movements.
	model.guests.clear()
	for i in range(180):
		model.guests.append(skier(i, 8.0 + float(i % 30)))
	var last_count: int = model.guests.size()
	var gone := 0
	for tick in range(320):
		var advances: Dictionary = Traffic.steps(model)
		for guest in model.guests.duplicate():
			guest.elapsed += float(advances.get(int(guest.id),0.0))
			if guest.elapsed >= guest.duration - 0.001:
				model.guests.erase(guest)
				gone += 1
		last_count = mini(last_count,model.guests.size())
		if model.guests.is_empty(): break
	check(gone == 180 and model.guests.is_empty(), "Dense crowd clears the piste rather than forming a permanent frozen line")
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
