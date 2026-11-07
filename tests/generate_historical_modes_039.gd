extends SceneTree
## Generate authentic free-build and mission saves inside an unchanged release.
## The original tag supplies Resort, Maps, Terrain and SaveStore; no current
## serializer is involved until the next separate verification process.
const Resort = preload("res://src/core/resort.gd")
const Saves = preload("res://src/core/save_store.gd")
const Maps = preload("res://src/core/maps.gd")
const Terrain = preload("res://src/core/terrain.gd")

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, name: String) -> void:
	if ok:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		push_error("FAIL " + name)

func save_with_backup(model: RefCounted, path: String) -> void:
	var result: Dictionary = Saves.save_game(model, path)
	check(bool(result.get("ok", false)), "Original release writes " + path.get_file())
	if not result.get("ok", false):
		return
	var first_hash: String = FileAccess.get_sha256(path)
	# Make a second genuinely saved checkpoint through the ORIGINAL code:
	# this must generate the original version's real .bak file.
	for i in range(2):
		model.advance_minute(false)
	result = Saves.save_game(model, path)
	check(bool(result.get("ok", false)) and FileAccess.file_exists(path + ".bak"), "Original version makes .bak " + path.get_file())
	check(FileAccess.get_sha256(path + ".bak") == first_hash, "Original .bak holds the first verified checkpoint " + path.get_file())
	var old: RefCounted = Resort.new()
	var round_trip: Dictionary = Saves.load_game(old, path)
	check(round_trip.ok and str(old.map_id) == str(model.map_id), "Original release itself reloads " + path.get_file())

func run() -> void:
	var folder: String = OS.get_environment("SKIZONES_EARLY_FIXTURES")
	var release: String = OS.get_environment("SKIZONES_FIXTURE_RELEASE")
	if folder.is_empty() or release != str(ProjectSettings.get_setting("application/config/version")):
		push_error("Fixture generation must run in a pinned historical release only")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	for index in [1, 2]:
		var free: RefCounted = Resort.new()
		free.new_game(false, 20261107 + index, "sonnenhang")
		var campaign: Variant = free.snapshot().get("campaign")
		check(campaign is Dictionary and campaign.get("mode") == "free", "Original free-build rules slot " + str(index))
		if not campaign is Dictionary or campaign.get("mode") != "free":
			continue
		# Build actual player-created infrastructure through the old APIs,
		# rather than merely changing a modern snapshot's version number.
		var start: Dictionary = Maps.spec("sonnenhang")
		var lift: Dictionary = free.build_lift(str(start.start_lift), Terrain.unpack(start.start_bottom), Terrain.unpack(start.start_top))
		var piste: Dictionary = free.build_piste([[245,-130],[275,-30],[255,95],[200,205]],0)
		check(bool(lift.get("ok", false)) and bool(piste.get("ok", false)), "Old sandbox accepts lift and piste construction " + str(index))
		var building: Dictionary = free.build_building("rental", Vector2(145,235))
		check(bool(building.get("ok", false)), "Old sandbox accepts a player-built venue " + str(index))
		free.day = 3 if index == 1 else 1
		for i in range(12):
			free.advance_minute(false)
		save_with_backup(free, folder.path_join(release + "-free-" + str(index) + ".json"))
	# The first four real-world mission maps have had dedicated saves since
	# early releases. Keep the original real mission state and operations.
	var mission: RefCounted = Resort.new()
	mission.new_game(true, 20261107, "braunlage")
	check(mission.map_id == "braunlage", "Original release creates the Braunlage scenario")
	check(mission.snapshot().get("operations") is Dictionary, "Original mission contains live operations")
	save_with_backup(mission, folder.path_join(release + "-mission.json"))
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
