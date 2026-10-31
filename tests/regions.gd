extends SceneTree
const Main = preload("res://src/main.gd")
const Maps = preload("res://src/core/maps.gd")
const Passport = preload("res://src/core/passport.gd")
const Resort = preload("res://src/core/resort.gd")
const Saves = preload("res://src/core/save_store.gd")
var passed := 0
var failed := 0

func _init() -> void:
	# This test exercises real save slots; require a private runtime directory.
	var directory := OS.get_environment("XDG_DATA_HOME")
	if not directory.contains("skizones-test") or not OS.get_user_data_dir().begins_with(directory):
		push_error("Run with XDG_DATA_HOME=/tmp/skizones-test-regions to isolate test saves.")
		quit(1)
		return
	call_deferred("run")

func check(value: bool, title: String) -> void:
	if value:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func clean() -> void:
	var paths: Array = [Saves.passport_path()]
	for id in Maps.FANTASY_MAPS:
		paths.append(Saves.path_for_map(id))
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))

func run() -> void:
	clean()
	var game := Main.new()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.paused = true
	game.model.money = 222222
	game.model.build_piste([[245, -130], [305, 0], [200, 205]], 1)
	var balance: float = game.model.money
	game.model.total_guests = 800
	game.model.campaign.rank = 2
	game.model.campaign.completed = 2
	game.passport.record(game.model)
	await game.enter_area("fichtenkamm")
	game.paused = true
	await process_frame
	check(game.model.map_id == "fichtenkamm" and game.model.pistes.size() == 1, "Entering an unlocked area starts its own resort")
	check(game.view._terrain_id == "fichtenkamm" and game.view.terrain.bounds.size.x == 3600, "The live world rebuilds to the selected region")
	game.model.money = 111111
	await game.enter_area("sonnenhang")
	game.paused = true
	await process_frame
	check(game.model.map_id == "sonnenhang" and game.model.money == balance and game.model.pistes.size() == 2, "Returning to the first region restores its money and construction")
	await game.enter_area("fichtenkamm")
	game.paused = true
	await process_frame
	check(game.model.money == 111111 and game.model.pistes.size() == 1, "A second region also retains its independent progress")
	await game.enter_area("dreigipfel")
	check(game.model.map_id == "fichtenkamm" and game.model.money == 111111, "A locked destination cannot replace the active resort")
	var passport := Passport.new()
	passport.load_from(Saves.passport_path())
	check(passport.unlocked("fichtenkamm") and passport.data.last_map == "fichtenkamm", "Unlocks and the active area survive passport reloading")
	var copy := Resort.new()
	check(Saves.load_game(copy, Saves.path_for_map("sonnenhang")).ok and copy.map_id == "sonnenhang" and copy.pistes.size() == 2, "The first region save remains independently readable")
	check(Saves.load_game(copy, Saves.path_for_map("fichtenkamm")).ok and copy.map_id == "fichtenkamm" and copy.money == 111111, "The second region save remains independently readable")
	game.queue_free()
	await process_frame
	await process_frame
	clean()
	print("REGIONS: %d passed; %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
