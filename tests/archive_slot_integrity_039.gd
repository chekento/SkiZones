extends SceneTree
## Career and free-build archive deletion is allowed only after complete
## SHA-256 verification. All fixtures live in an isolated user:// root.
const Saves = preload("res://src/core/save_store.gd")
const Resort = preload("res://src/core/resort.gd")
var passed := 0
var failed := 0

func _init() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ", message)
	else:
		failed += 1
		push_error("FAIL " + message)

func write_file(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(content)
	file.close()
	return true

func latest_archive(path: String, prefix: String) -> String:
	var dir := DirAccess.open(path)
	if dir == null: return ""
	var results: Array = []
	for name in dir.get_directories():
		if name.begins_with(prefix): results.append(path + "/" + name)
	results.sort()
	return str(results.back()) if not results.is_empty() else ""

func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-archive-integrity-039"):
		push_error("Never touch actual player saves")
		quit(1)
		return

	var career := Resort.new()
	career.new_game(true, 20261107, "sonnenhang")
	var career_path: String = Saves.path_for_map("sonnenhang", 2)
	check(Saves.save_game(career, career_path).ok, "Isolated career fixture saved")
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(career_path), ProjectSettings.globalize_path(career_path + ".bak")) == OK, "Career backup fixture exists")
	var passport: String = Saves.passport_path(2)
	var index: String = Saves.index_path(2)
	check(write_file(passport, "{\"version\":1,\"slot\":2}"), "Career passport fixture exists")
	check(write_file(index, "{\"version\":1,\"map\":\"sonnenhang\"}"), "Career index fixture exists")
	var career_files: Array = [career_path, career_path + ".bak", passport, index]
	var career_hashes: Dictionary = {}
	for path in career_files: career_hashes[path.get_file()] = FileAccess.get_sha256(path)
	check(Saves.archive_slot(2), "Career archiving verifies copied members")
	var career_archive: String = latest_archive("user://career-archives", "slot-2-")
	check(not career_archive.is_empty(), "Career archive created")
	var career_integrity := true
	for path in career_files:
		career_integrity = career_integrity and not FileAccess.file_exists(path)
		career_integrity = career_integrity and FileAccess.file_exists(career_archive + "/" + path.get_file())
		career_integrity = career_integrity and FileAccess.get_sha256(career_archive + "/" + path.get_file()) == str(career_hashes[path.get_file()])
	check(career_integrity, "Career primary, backup, passport and index retained byte-for-byte")
	var restored := Resort.new()
	check(Saves.load_game(restored, career_archive + "/" + career_path.get_file()).ok, "Archived career remains readable with the same map and mode")

	var free := Resort.new()
	free.new_game(false, 20261107, "sonnenhang")
	free.campaign.mode = "free"
	var free_path: String = Saves.path_for_map("sonnenhang", 0, 3)
	check(Saves.save_game(free, free_path).ok, "Isolated free-build fixture saved")
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(free_path), ProjectSettings.globalize_path(free_path + ".bak")) == OK, "Free-build backup fixture exists")
	var free_passport: String = Saves.passport_path(0, 3)
	check(write_file(free_passport, "{\"version\":1,\"slot\":3}"), "Free-build passport fixture exists")
	var free_files: Array = [free_path, free_path + ".bak", free_passport]
	var free_hashes: Dictionary = {}
	for path in free_files: free_hashes[path.get_file()] = FileAccess.get_sha256(path)
	check(Saves.archive_free_slot(3), "Free-build archiving verifies copied members")
	var free_archive: String = latest_archive("user://free-archives", "slot-3-")
	var free_integrity := not free_archive.is_empty()
	for path in free_files:
		free_integrity = free_integrity and not FileAccess.file_exists(path)
		free_integrity = free_integrity and FileAccess.file_exists(free_archive + "/" + path.get_file())
		free_integrity = free_integrity and FileAccess.get_sha256(free_archive + "/" + path.get_file()) == str(free_hashes[path.get_file()])
	check(free_integrity, "Free-build primary, backup and passport retained byte-for-byte")
	restored = Resort.new()
	check(Saves.load_game(restored, free_archive + "/" + free_path.get_file()).ok and Saves._free_data(restored.snapshot()), "Archived free-play world remains loadable")

	# Force a failed copy by putting a directory at the would-be archive
	# file destination. The helper must refuse deletion of the source.
	var blocked_source: String = "user://blocked-archive-fixture.json"
	var blocked_folder: String = "user://blocked-archive"
	check(write_file(blocked_source, "UNTOUCHED ORIGINAL"), "Failed-copy source fixture exists")
	var before: String = FileAccess.get_sha256(blocked_source)
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_folder + "/" + blocked_source.get_file())) == OK, "Unwritable destination fixture exists")
	check(not Saves._archive_slot_files(blocked_folder, [blocked_source]), "Copy collision prevents archiving")
	check(FileAccess.file_exists(blocked_source) and FileAccess.get_sha256(blocked_source) == before, "Failed archival preserves every original byte")
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
