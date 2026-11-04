extends SceneTree
## In-place upgrade regression: multiple career mountains, missing files,
## damaged primaries, read-only fallbacks and new-format roundtrips.
const Saves = preload("res://src/core/save_store.gd")
const Resort = preload("res://src/core/resort.gd")
var passed := 0
var failed := 0
var clean: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed += 1;print("PASS ", title)
	else: failed += 1;push_error("FAIL " + title)
func remove_path(path: String) -> void:
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test"):
		push_error("Use an isolated skizones-test data directory");quit(1);return
	Saves.active_slot = 2
	for id in ["sonnenhang", "fichtenkamm"]:
		var path: String = Saves.path_for_map(id, 2)
		for suffix in ["", ".bak", ".tmp"]: remove_path(path + suffix)
		clean.append(path)
		var current := Resort.new()
		current.new_game(true, 20261027, id)
		current.money = 300000 if id == "sonnenhang" else 450000
		check(Saves.save_game(current,path).ok, "Write separate career resort " + id)
	var original: String = Saves.path_for_map("sonnenhang", 2)
	var second: String = Saves.path_for_map("fichtenkamm", 2)
	var original_hash: String = FileAccess.get_sha256(original)
	var entries: Array = Saves.saved_resorts(2)
	check(entries.size() == 2 and entries.any(func(v):return v.map=="sonnenhang") and entries.any(func(v):return v.map=="fichtenkamm"), "All independently saved mountains are visible in one career")
	var resumed := Resort.new()
	check(Saves.load_game(resumed,second).ok and resumed.money==450000,"Direct selection restores the second mountain, not the previous map")
	check(Saves.save_game(resumed,second).ok and Saves.load_game(Resort.new(),second).ok, "Resumed resort roundtrips in the current save format")
	check(FileAccess.get_sha256(original)==original_hash,"Loading another mountain never rewrites first mountain")
	Saves.active_slot = 3
	var damaged: String = Saves.path_for_map("sonnenhang", 3)
	for suffix in ["", ".bak", ".tmp"]: remove_path(damaged + suffix)
	clean.append(damaged)
	var broken := FileAccess.open(damaged, FileAccess.WRITE)
	broken.store_string("not-json but keep these bytes")
	broken.close()
	var invalid_hash: String = FileAccess.get_sha256(damaged)
	check(Saves.has_any_save("sonnenhang",3) and not Saves.has_readable_save("sonnenhang",3),"Unreadable primary is distinguished from an empty slot")
	check(Saves.summary(3).occupied and Saves.summary(3).damaged,"Damaged existing career is visible, never labelled new")
	check(not Saves.load_game(Resort.new(),damaged).ok and FileAccess.get_sha256(damaged)==invalid_hash,"Attempted loading does not overwrite an unreadable save")
	var old := Resort.new()
	old.new_game(true,20261027,"sonnenhang")
	check(Saves.save_game(old,damaged).ok,"A later explicit save can preserve corrupt bytes before replacing the slot")
	check(Saves.load_game(Resort.new(),damaged).ok,"New format save can be reopened after archiving damaged primary")
	Saves.active_slot = 2
	check(Saves.has_readable_save("sonnenhang",2) and not Saves.has_readable_save("sonnenhang",4),"No career cross-slot leakage")
	for path in clean:
		for suffix in ["", ".bak", ".tmp"]: remove_path(path + suffix)
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
