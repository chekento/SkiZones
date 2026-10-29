extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Maps = preload("res://src/core/maps.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Mountain = preload("res://src/core/mountain.gd")
const Dynamics = preload("res://src/core/ski_dynamics.gd")
class TrainingSlope extends "res://src/core/mountain.gd":
	func height(point: Vector2) -> float: return 80 - point.y * 0.12

var passed := 0
var failed := 0

func check(value: bool, title: String) -> void:
	if value:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func equivalent(a: Variant, b: Variant) -> bool:
	if Terrain.number(a) and Terrain.number(b): return absf(float(a) - float(b)) < 0.0000001
	if typeof(a) != typeof(b): return false
	if a is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key], b[key]): return false
		return true
	if a is Array:
		if a.size() != b.size(): return false
		for i in range(a.size()):
			if not equivalent(a[i], b[i]): return false
		return true
	return a == b

func _init() -> void:
	call_deferred("run")

func run() -> void:
	check(Maps.MAPS.size() == 8, "Eight independently named unlockable resorts")
	var starts: Dictionary = {}
	var signatures: Dictionary = {}
	for id in Maps.MAPS:
		var model := Resort.new()
		model.new_game(true, 20261029, id)
		print("WORLD ", id, " lifts=", model.lifts.size(), " pistes=", model.pistes.size(), " buildings=", model.buildings.size(), " routes=", model.routes_for(0).size(), "/", model.routes_for(2).size(), " money=", model.money)
		check(model.lifts.size() == 1 and model.pistes.size() == 1 and model.money > 75000, id + " has a viable funded starter")
		check(not model.routes_for(0).is_empty(), id + " has a complete beginner-accessible starter circuit")
		if not model.lifts.is_empty(): starts[model.lifts[0].kind] = true
		var heights: Array = []
		for p in [Vector2(-800, -1100), Vector2(700, -2100), Vector2(-1200, -2900)]: heights.append(snappedf(model.terrain.height(p), 0.01))
		signatures[str(heights)] = true
		var copy := Resort.new()
		check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok and copy.terrain.generation == 2 and copy.terrain_generation == 2, id + " keeps its terrain generation on restore")
		var layout: Dictionary = model.pedestrian_layout()
		var streets: Array = layout.links.filter(func(link): return link.get("promenade", false))
		check(streets.size() >= 4 and streets.all(func(link): return model.Foot.clear_walk(link.points, model.buildings, model.lifts)), id + " has a continuous unobstructed main street")
	check(starts.size() == 8 and signatures.size() == 8, "Every resort has a distinct starting lift and landscape")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.11-starter.json"))
	var migrated := Resort.new()
	check(migrated.restore(old).ok and migrated.terrain_generation == 1, "Old populated save retains the original landscape")
	check(is_equal_approx(migrated.terrain.height(Vector2(700, -1400)), Mountain.new().height(Vector2(700, -1400))), "Legacy mountain elevations stay exact")
	var roundtrip := Resort.new()
	check(roundtrip.restore(JSON.parse_string(JSON.stringify(migrated.snapshot()))).ok and roundtrip.terrain_generation == 1, "Legacy terrain identity survives format 13 roundtrip")
	var m := Resort.new()
	m.new_game(false)
	var layout: Dictionary = m.pedestrian_layout()
	check(layout.links.any(func(link): return link.get("promenade", false)), "Empty free-build map includes its public village spine")
	check(m.build_walkway([[185, 290], [185, 410]]).ok, "A connected cul-de-sac can open a future building site")
	check(not m.preview_walkway([[900, 300], [940, 300]]).ok, "A detached strip still cannot become an unconnected path")
	check(m.snap_walkway(Vector2(185.8, 355), 10).point.distance_to(Vector2(185, 355)) < 0.01, "New branches snap to the middle of an existing path")
	var rotation_value := m.building_orientation("shelter", Vector2(222, 380))
	check(m.build_building("shelter", Vector2(222, 380), rotation_value).ok, "A building can join the middle of the new access path")
	var funds: float = m.money
	check(not m.build_building("shelter", Vector2(280, 390), 7).ok and m.money == funds, "An invalid entrance orientation never spends funds")
	var path: Array = [[0, 0], [0, 200]]
	var plane := TrainingSlope.new()
	var skis := Dynamics.profile(plane, path, 1, 1, 0, "ski")
	var board := Dynamics.profile(plane, path, 1, 1, 0, "snowboard")
	var blades := Dynamics.profile(plane, path, 1, 1, 0, "snowblade")
	check(skis.minutes < board.minutes and board.minutes < blades.minutes, "Identical slopes expose the actual equipment friction differences")
	check(Dynamics.profile(plane, path, 1, 1, 0.6).minutes > skis.minutes, "Rough snow increases physical resistance and journey time")
	var populated := Resort.new()
	populated.new_game(true)
	for i in range(8): populated.admit_guest(0)
	for guest in populated.guests:
		guest.route = populated.routes_for(0)[0].duplicate(true)
		for i in range(guest.route.legs.size()):
			if guest.route.legs[i].kind == "ski":
				guest.leg = i
				populated._start_leg(guest)
				guest.elapsed = populated.Traffic._time_at(guest.get("ski_motion", []), 0.45) * guest.duration
				break
	var steps: Dictionary = populated.Traffic.steps(populated)
	check(steps.size() == 8 and steps.values().any(func(value): return value < 0.1) and steps.values().all(func(value): return value >= 0 and value <= 1), "Crowded descent progress brakes behind other guests without moving backwards")
	for i in range(20): populated.advance_minute(false)
	var continued := Resort.new()
	check(continued.restore(JSON.parse_string(JSON.stringify(populated.snapshot()))).ok, "Active physical traffic and its progress survive a populated save")
	for i in range(80):
		populated.advance_minute(false)
		continued.advance_minute(false)
	check(equivalent(populated.snapshot(), continued.snapshot()), "Traffic, real services and routes continue deterministically after loading")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.12-starter.json"))
	var old_current := Resort.new()
	check(source.version == 12 and source.guests.size() == 18 and old_current.restore(source).ok and old_current.terrain_generation == 1, "A real populated published 0.12 resort migrates with exact legacy terrain")
	var invalid: Dictionary = old_current.snapshot()
	invalid.terrain_generation = 99
	var before := old_current.snapshot()
	check(not old_current.restore(invalid).ok and old_current.snapshot() == before, "Unknown landscape generations cannot replace the current resort")
	print("WORLDS: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
