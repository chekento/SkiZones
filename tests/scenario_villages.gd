extends SceneTree
## Four Alpine careers need a compact staffed hospitality village, not a city.
const Resort = preload("res://src/core/resort.gd")
const Geo = preload("res://src/core/real_resorts.gd")
const Ops = preload("res://src/core/operations.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Scenery = preload("res://src/world/compact_village.gd")
var passed := 0
var failed := 0

func check(condition: bool, why: String) -> void:
	if condition:
		passed += 1
		print("PASS ", why)
	else:
		failed += 1
		push_error("FAIL " + why)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	for id in Geo.IDS:
		var model := Resort.new()
		model.new_game(true, 20261027, id)
		var counts := {}
		var reserved := 0
		for building in model.buildings:
			counts[building.kind] = int(counts.get(building.kind, 0)) + 1
			if building.kind == "hotel": reserved += 24 * int(building.get("level", 1))
		check(int(counts.get("hotel", 0)) >= 2 and reserved >= 48, id + " has a genuine playable overnight hotel capacity")
		check(int(counts.get("restaurant", 0)) >= 1, id + " has a real usable restaurant")
		check(int(counts.get("kiosk", 0)) >= 1, id + " has a player-run snack stall")
		check(int(counts.get("school", 0)) >= 1, id + " has a staffed ski school")
		check(int(counts.get("disco", 0)) >= 1, id + " has night-time and après-ski trade")
		check(model.buildings.size() <= 12, id + " keeps core businesses deliberately small")
		check(model.buildings.all(func(b): return model.terrain.contains(Terrain.unpack(b.point))), id + " businesses fit the terrain")
		var room: Array = model.buildings.filter(func(b): return b.kind == "hotel")
		check(not room.is_empty() and Ops.building_team(model, room[0]).size() >= 3, id + " hotel staffing tracks real simulated shifts")
		# The town overlay has its own OSM source integrity checks; this
		# scene validates *playable businesses* and does not invent POI data.
		check(model.operations.scenario == id and model.operations.staff.size() > 0, id + " retains independent career and employees")
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
