extends SceneTree
## Regression for real checksum-valid but invalid Android save snapshots.
## Never touch files outside the isolated test-user directory.
const Resort = preload("res://src/core/resort.gd")
const Saves = preload("res://src/core/save_store.gd")
const Manager = preload("res://src/core/save_management_038.gd")
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ", label)
	else: failed += 1; push_error("FAIL " + label)
func write_envelope(path: String, data: Dictionary, valid_checksum: bool = true) -> void:
	var payload: String = JSON.stringify(data, "", true, true)
	var output: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify({"format": "SkiZones", "checksum": payload.sha256_text() if valid_checksum else "wrong-checksum", "payload": payload}))
	output.close()
func run() -> void:
	if OS.get_environment("SKIZONES_SAFE_SAVE_TEST") != "1" or not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-integrity-040"):
		push_error("Never run this regression on real player files"); quit(1); return
	var path: String = Saves.path_for_map("sonnenhang", 3)
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	var model: RefCounted = Resort.new()
	model.new_game(true, 20261108)
	check(Saves.save_game(model, path).ok, "Validated initial career is safely written")
	var first_sha: String = FileAccess.get_sha256(path)
	check(Saves.save_game(model, path).ok, "A subsequent valid save rotates a verified checkpoint")
	var good_backup: String = FileAccess.get_sha256(path + ".bak")
	check(good_backup == first_sha, "Backup bytes equal the preceding good primary")
	var broken: Dictionary = model.snapshot().duplicate(true)
	broken.pistes[0].points[0] = [99999999, 99999999]
	write_envelope(path, broken)
	var broken_sha: String = FileAccess.get_sha256(path)
	check(Saves._read(path).ok, "Semantically corrupt saved terrain still has a correct envelope checksum")
	var report: Dictionary = Manager.inspect("sonnenhang", 3)
	check(report.files.any(func(e): return str(e.get("code", "")) == "semantic_incompatible"), "Diagnostic distinguishes semantic corruption from a checksum problem")
	check(Saves.save_game(model, path).ok, "A good snapshot can replace corrupt primary after non-destructive archival")
	check(FileAccess.get_sha256(path + ".bak") == good_backup, "An invalid primary cannot destroy the last good backup")
	var archived := false
	var directory: DirAccess = DirAccess.open("user://save-recovery")
	if directory != null:
		for name in directory.get_files():
			if name.begins_with(path.get_file() + "-") and name.ends_with(".broken"):
				archived = archived or FileAccess.get_sha256("user://save-recovery/" + name) == broken_sha
	check(archived, "Original invalid bytes are preserved in the recovery archive")
	var valid_primary: String = FileAccess.get_sha256(path)
	var invalid_model: RefCounted = Resort.new()
	invalid_model.new_game(true, 20261108)
	invalid_model.pistes[0].points[0] = [99999999, 99999999]
	check(not Saves.save_game(invalid_model, path).ok, "An impossible new snapshot is rejected without activation")
	check(FileAccess.get_sha256(path) == valid_primary and FileAccess.get_sha256(path + ".bak") == good_backup, "Rejected save preserves both playable source files")
	check(not FileAccess.file_exists(path + ".tmp"), "Staging remnants do not replace a good save")
	var damaged: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	damaged.store_string("{truncated"); damaged.close()
	check(str(Saves._read(path).get("code", "")) == "invalid_json", "Truncated JSON has a specific diagnostic code")
	write_envelope(path, model.snapshot(), false)
	check(str(Saves._read(path).get("code", "")) == "checksum_mismatch", "Checksum corruption has a distinct diagnostic code")
	check(Saves.load_game(Resort.new(), path).ok, "Last good backup remains loadable after both primary-file failures")
	# A killed Android process can leave only the fully written .tmp. Its
	# valid bytes must be discoverable without ever guessing an invalid JSON.
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	write_envelope(path + ".tmp", model.snapshot())
	var orphan_sha: String=FileAccess.get_sha256(path + ".tmp")
	check(Saves.has_any_save("sonnenhang", 3), "A staged-only interrupted save keeps the career slot occupied")
	var direct_stage: Dictionary=Saves.load_game(Resort.new(),path)
	check(direct_stage.ok and direct_stage.recovered and direct_stage.source==path+".tmp", "The game can resume a verified interrupted save without first overwriting committed files")
	check(FileAccess.get_sha256(path+".tmp")==orphan_sha and not FileAccess.file_exists(path), "Read-only interrupted-save loading leaves the original stage untouched")
	var orphan_report: Dictionary=Manager.inspect("sonnenhang", 3)
	check(orphan_report.files.any(func(item): return str(item.get("source", "")) == path + ".tmp" and bool(item.get("loadable", false))), "Read-only diagnostics discover a verified interrupted write")
	var staged_repair: Dictionary=Manager.repair("sonnenhang", 3)
	check(staged_repair.ok and Saves.load_game(Resort.new(), path).ok, "Explicit recovery activates a verified staged save without inventing new data")
	check(FileAccess.get_sha256(path + ".tmp") == orphan_sha, "Recovery does not alter the original interrupted staging bytes")
	# The next normal save must archive that orphan before truncating its name.
	model.money += 7.0
	check(Saves.save_game(model, path).ok, "A new save does not erase the prior interrupted write without an archive")
	var staged_archived := false
	var archive_dir: DirAccess=DirAccess.open("user://save-recovery")
	if archive_dir != null:
		for name in archive_dir.get_files():
			if name.begins_with((path + ".tmp").get_file() + "-") and name.ends_with(".before-staging"):
				staged_archived=staged_archived or FileAccess.get_sha256("user://save-recovery/" + name) == orphan_sha
	check(staged_archived, "The unfinished original survives a normal save byte-for-byte in a separate archive")
	check(Saves.load_game(Resort.new(), path).ok, "A replaced valid stage remains playable after recovery")
	# Even a truncated .tmp is forensic evidence and must not be hidden as
	# though the slot contained no files.
	var damaged_stage: FileAccess=FileAccess.open(path + ".tmp", FileAccess.WRITE)
	damaged_stage.store_string("{unfinished android write"); damaged_stage.close()
	var damaged_stage_sha: String=FileAccess.get_sha256(path + ".tmp")
	var forensic: Dictionary=Manager.inspect("sonnenhang", 3)
	check(forensic.files.any(func(item): return str(item.get("source","")) == path + ".tmp" and str(item.get("code","")) == "invalid_json"), "Malformed staged save is reported with its actual parser-error classification")
	check(FileAccess.get_sha256(path + ".tmp") == damaged_stage_sha, "Read-only diagnostics preserve malformed staging bytes")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
