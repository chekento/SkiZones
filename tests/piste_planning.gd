extends SceneTree
const Mountain = preload("res://src/core/mountain.gd")
const Resort = preload("res://src/core/resort.gd")
const Terrain = preload("res://src/core/terrain.gd")
var passed := 0
var failed := 0

class PlanarMountain extends "res://src/core/mountain.gd":
	func height(point: Vector2) -> float:
		return 200 - point.y * 0.8

class ShortSteepSection extends "res://src/core/mountain.gd":
	func height(point: Vector2) -> float:
		return 200 - minf(point.y, 50) * 0.8 - maxf(point.y - 50, 0) * 0.04

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func _init() -> void:
	var terrain := PlanarMountain.new()
	var direct := terrain.analyse([[0, 0], [0, 200]])
	var serpentine := terrain.analyse([[0, 0], [350, 50], [-350, 150], [0, 200]])
	check(direct.ok and direct.difficulty == 2 and is_equal_approx(direct.grade, 80), "A direct descent is automatically black")
	check(serpentine.ok and serpentine.difficulty == 0 and serpentine.grade < 12, "Serpentines on the same steep mountain are automatically blue")
	check(is_equal_approx(direct.drop, serpentine.drop) and serpentine.length > direct.length * 4, "The comparison has the same start, finish and elevation loss")
	check(terrain.slope_percent(Vector2(100, 100)) > 79 and serpentine.grade < 12, "Terrain fall line and the longitudinal route grade are different quantities")
	check(terrain.analyse([[0, 0], [0, 200]], 0).difficulty == 2, "Legacy color arguments cannot paint a steep piste blue")
	var red := terrain.analyse([[0, 0], [400, 200]])
	check(red.ok and red.difficulty == 1, "An intermediate diagonal route is automatically red")
	var short_steep := ShortSteepSection.new().analyse([[0, 0], [0, 450]])
	check(short_steep.ok and short_steep.average < 15 and short_steep.difficulty == 2, "A short black section cannot be hidden inside an easy average")
	check(not terrain.analyse([[0, 200], [0, 0]]).ok, "Uphill routes remain blocked in automatic mode")
	check(not terrain.analyse([[0, 0], [350, 80], [0, 70], [0, 200]]).ok, "An intermediate uphill section remains blocked")
	check(serpentine.profile.size() >= 4 and serpentine.profile.size() < 520 and is_equal_approx(serpentine.profile[-1].distance, serpentine.horizontal), "The live profile reaches the end and has bounded display samples")
	check(serpentine.segments.size() == 3 and serpentine.segments[0].difficulty == 0, "Every planned segment has a classification for the route preview")
	check(is_equal_approx(serpentine.average, serpentine.drop / serpentine.horizontal * 100), "Average grade uses horizontal distance, not the 3D path length")
	var model := Resort.new()
	model.new_game(true)
	model.money = 1000000
	var black := [[-170, -235], [-160, -50], [-80, 90], [100, 190]]
	check(model.build_piste(black, 0).ok and model.pistes[-1].difficulty == 2, "Construction uses automatic difficulty even for an old blue caller")
	check(model.pistes[0].number == 1 and model.pistes[1].number == 2 and model.pistes[0].id != model.pistes[0].number, "Piste numbers are independent of lift and building identifiers")
	var number: int = model.pistes[1].number
	model.demolish(model.pistes[0].id)
	check(model.pistes[0].number == number, "Demolishing another piste does not renumber existing signs")
	var copy := Resort.new()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	check(copy.restore(saved).ok and copy.pistes[0].number == number and copy.pistes[0].difficulty == 2, "Automatic class and sign number survive a JSON save round trip")
	saved.pistes[0].difficulty = 0
	var balance: float = copy.money
	check(not copy.restore(saved).ok and copy.money == balance, "A tampered new-format difficulty is rejected without altering the current game")
	model.new_game(true)
	model.build_piste([[245, -130], [305, 0], [200, 205]])
	saved = model.snapshot()
	saved.pistes[1].number = saved.pistes[0].number
	check(not copy.restore(saved).ok, "Duplicate piste numbers are rejected")
	saved = model.snapshot()
	saved.version = 3
	saved.pistes[0].erase("number")
	saved.pistes[1].erase("number")
	saved.pistes[1].difficulty = 1
	check(copy.restore(JSON.parse_string(JSON.stringify(saved))).ok and copy.pistes[1].number == 2 and copy.pistes[1].difficulty == 0, "Old manually colored pistes migrate to their route's actual class with numbered signs")
	check(Mountain.difficulty_for_grade(30) == 0 and Mountain.difficulty_for_grade(30.01) == 1 and Mountain.difficulty_for_grade(55) == 1 and Mountain.difficulty_for_grade(55.01) == 2, "Difficulty thresholds have deterministic inclusive boundaries")
	print("PISTE PLANNING: %d passed; %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
