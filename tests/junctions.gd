extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Motion = preload("res://src/core/ski_motion.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const BLUE := [[0, 0], [350, 35], [-350, 100], [350, 165], [200, 205]]
const REAL_BLUE := [[-170, -235], [-150, -225], [-140, -225], [-120, -235], [-50, -305], [-20, -325], [200, -265], [240, -245], [200, -125], [200, 205]]
var passed := 0
var failed := 0

class PlanarMountain extends "res://src/core/mountain.gd":
	func height(point: Vector2) -> float:
		return 200 - point.y * 0.8

class GentleMountain extends "res://src/core/mountain.gd":
	func height(point: Vector2) -> float:
		return 300 - point.y * 0.2

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func target_route(model: RefCounted, skill: int, id: int) -> Dictionary:
	for route in model.routes_for(skill):
		if route.target == id:
			return route
	return {}

func skiing_ids(route: Dictionary) -> Array:
	var result: Array = []
	for leg in route.get("legs", []):
		if leg.kind == "ski":
			result.append(int(leg.id))
	return result

func _init() -> void:
	var model := Resort.new()
	model.new_game(false)
	model.terrain = PlanarMountain.new()
	model.money = 1000000
	check(model.build_lift("drag", Vector2(200, 205), Vector2(0, 0)).ok and model.build_piste(BLUE).ok, "A serpentine circuit can be built on a steep test mountain")
	var blue: Dictionary = model.pistes[0]
	check(blue.difficulty == 0 and model.routes_for(0).size() == 1, "Beginners can complete the full blue serpentine")
	check(model.build_piste([[350, 35], [350, 165]]).ok, "A steep shortcut can dock at two interior blue waypoints")
	var black: Dictionary = model.pistes[1]
	check(black.difficulty == 2 and model.routes_for(0).size() == 1 and model.routes_for(1).size() == 1, "Beginner and intermediate guests cannot take the black shortcut")
	var expert := target_route(model, 2, black.id)
	check(skiing_ids(expert) == [blue.id, black.id, blue.id], "An expert skis the blue approach, black shortcut and blue exit in one circuit")
	check(expert.legs.size() < 12, "Adjacent sections of one piste merge into continuous skiing legs")
	var prefix: Dictionary = {}
	var suffix: Dictionary = {}
	for leg in expert.get("legs", []):
		if leg.kind == "ski" and leg.id == blue.id:
			if prefix.is_empty():
				prefix = leg
			else:
				suffix = leg
	check(prefix.get("first") == 0 and prefix.get("last") == 1 and suffix.get("first") == 3 and suffix.get("last") == 4, "The guest only travels the required portions of the blue piste")
	check(is_equal_approx(Resort.ski_fraction(suffix, 0), model.terrain.waypoint_fraction(blue.points, 3)) and is_equal_approx(Resort.ski_fraction(suffix, 1), 1), "Partial leg progress maps to the correct whole-piste coordinates")
	check(model.build_piste([[350, 35], [480, 100], [350, 165]]).ok, "A second, red alternative can dock at the same junctions")
	var red: Dictionary = model.pistes[2]
	check(red.difficulty == 1 and model.routes_for(0).size() == 1 and model.routes_for(1).size() == 2 and model.routes_for(2).size() == 3, "Every ability gets exactly the compatible alternatives")
	check(skiing_ids(target_route(model, 1, red.id)) == [blue.id, red.id, blue.id], "Intermediate guests can branch onto red and rejoin blue")
	var anchor := model.snap_anchor(Vector2(353, 36))
	check(not anchor.is_empty() and anchor.point == Vector2(350, 35), "Planning snaps exactly onto an interior waypoint")
	check(model.snap_anchor(Vector2(-900, 350)).is_empty(), "Empty snow does not claim to be a junction")
	var graph := model._graph(2)
	var false_transfer := false
	for leg in graph.edges[model._piste_node(blue, 1)]:
		false_transfer = false_transfer or (leg.kind == "walk" and leg.to == model._piste_node(blue, 2))
	check(not false_transfer, "Nearby sections of a serpentine do not create broad walking shortcuts")
	model.admit_guest(2)
	var guest: Dictionary = model.guests[0]
	guest.route = expert
	for index in range(expert.legs.size()):
		if expert.legs[index] == suffix:
			guest.leg = index
	model._start_leg(guest)
	var start: float = suffix.start_fraction
	var finish: float = suffix.end_fraction
	var at_start := model.guest_position(guest)
	check(Vector2(at_start.x, at_start.z).distance_to(Vector2(350, 165)) < 0.01, "Rejoining a piste starts at the junction, not at its summit")
	guest.elapsed = guest.duration
	var at_end := model.guest_position(guest)
	check(Vector2(at_end.x, at_end.z).distance_to(Terrain.unpack(blue.points.back())) < 0.01, "The partial skiing leg ends at its actual plaza exit")
	Snow.touch(model.terrain, blue, guest, start, finish)
	var track: Dictionary = blue.tracks[-1]
	check(is_equal_approx(track.from, start) and is_equal_approx(track.to, finish), "A returning skier records tracks only on the ridden portion")
	var untouched := true
	for row in range(floori(start * blue.length / Snow.STEP)):
		for lane in range(Snow.LANES + 1):
			untouched = untouched and blue.surface[row * (Snow.LANES + 1) + lane] == 0
	check(untouched and Snow.roughness(blue) > 0, "A partial descent changes local snow without deforming the unused upper piste")
	# A save contains real, contiguous slices; the validator also works while closed.
	check(not model._checked_itinerary(expert.duplicate(true), 2).is_empty(), "A junction itinerary validates against the actual waypoint slices")
	var broken := expert.duplicate(true)
	for leg in broken.legs:
		if leg.kind == "ski" and leg.id == blue.id:
			leg.start_fraction = 0.99
			break
	check(model._checked_itinerary(broken, 2).is_empty(), "A corrupted slice fraction is rejected")
	model.set_enabled(black.id, false)
	check(target_route(model, 2, black.id).is_empty() and not target_route(model, 1, red.id).is_empty(), "Closing one shortcut preserves the remaining compatible routes")
	model.demolish(blue.id)
	check(model.routes_for(2).is_empty(), "Removing the shared approach disconnects the shortcuts")
	_real_mountain()
	_large_network()
	print("JUNCTIONS: %d passed; %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _real_mountain() -> void:
	var model := Resort.new()
	model.new_game(false)
	model.money = 1500000
	model.build_lift("chair", Vector2(200, 205), Vector2(-170, -235))
	var built := model.build_piste(REAL_BLUE)
	check(built.ok and model.pistes[0].difficulty == 0, "A longer blue route also works on the actual Sonnenhang terrain")
	model.build_piste([REAL_BLUE[4], REAL_BLUE[7]])
	model.build_piste([REAL_BLUE[3], REAL_BLUE[8]])
	check(model.pistes.size() == 3 and model.pistes[1].difficulty == 1 and model.pistes[2].difficulty == 2, "Red and black shortcuts are classified correctly on the real mountain")
	check(model.routes_for(0).size() == 1 and model.routes_for(1).size() == 2 and model.routes_for(2).size() == 3, "Skill-specific junction routing works on the real map")
	model.admit_guest(2)
	var guest: Dictionary = model.guests[0]
	guest.route = target_route(model, 2, model.pistes[2].id)
	for index in range(guest.route.legs.size()):
		var leg: Dictionary = guest.route.legs[index]
		if leg.kind == "ski" and leg.get("start_fraction", 0) > 0:
			guest.leg = index
	model._start_leg(guest)
	guest.elapsed = guest.duration * 0.35
	var before := model.guest_position(guest)
	var copy := Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "A guest on a partial descent can be saved and restored on the real mountain")
	if not copy.guests.is_empty():
		check(copy.guest_position(copy.guests[0]).distance_to(before) < 0.001, "The saved guest resumes at the same position after rejoining a piste")
	for i in range(140):
		model.advance_minute(false)
		copy.advance_minute(false)
	check(model.total_rides == copy.total_rides and model.money == copy.money and model.guests.size() == copy.guests.size(), "Junction routes continue deterministically after a save")

func _large_network() -> void:
	var model := Resort.new()
	model.new_game(false)
	model.terrain = GentleMountain.new()
	model.money = 10000000
	model.build_lift("chair", Vector2(200, 205), Vector2(200, -299))
	for index in range(36):
		var points: Array = []
		for step in range(64):
			points.append([200 if step == 0 or step == 63 else 176 + index * 1.3 + sin(step * 0.1) * 5, -278 + step * (462.0 / 63)])
		model.build_piste(points)
	var started := Time.get_ticks_msec()
	var beginners: Array = model.routes_for(0)
	var experts: Array = model.routes_for(2)
	check(model.pistes.size() == 36 and beginners.size() == 36 and experts.size() == 36, "A network with 2,304 waypoints retains every reachable destination")
	var complete := true
	for route in beginners:
		complete = complete and not model._checked_itinerary(route.duplicate(true), 0).is_empty()
	check(complete, "Large-network routes still form valid complete circuits")
	print("LARGE NETWORK: 2304 waypoints; routes and validation ", Time.get_ticks_msec() - started, " ms")
