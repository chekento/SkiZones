extends SceneTree
## Release gate for 0.33.2. Use a dedicated data directory. Never modify
## user accounts or shipped historical files during the integration test.
const Saves = preload("res://src/core/save_store.gd")
const Resort = preload("res://src/core/resort.gd")
const Maps = preload("res://src/core/maps.gd")
var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed += 1;print("PASS ", label)
	else: failed += 1;push_error("FAIL " + label)

func remove_file(path: String) -> void:
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func put_state(path: String, snapshot: Dictionary) -> void:
	var payload := JSON.stringify(snapshot, "", true, true)
	var envelope := JSON.stringify({"format": "SkiZones", "checksum": payload.sha256_text(), "payload": payload})
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(envelope)
	file.close()

func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test"):
		push_error("Isolated skizones-test data home is required")
		quit(1)
		return
	Saves.active_slot = 0
	var old_free_path := Saves.path_for_map("sonnenhang",0,1)
	check(old_free_path == "user://free_sonnenhang.json" and Saves.passport_path(0,1) == "user://free_passport.json", "Original free-build files are preserved as slot 1")
	for slot in range(1,5):
		Saves.active_free_slot = slot
		var path := Saves.path_for_map("sonnenhang")
		for suffix in ["",".bak",".tmp"]: remove_file(path + suffix)
		var model := Resort.new()
		model.new_game(false,20261105,"sonnenhang",true)
		model.money = 700000 + slot * 1000
		check(model.campaign.mode == "free" and Saves.save_game(model,path).ok, "Free slot %d can create and save a new resort" % slot)
		check(Saves.free_summary(slot).occupied and Saves.free_summary(slot).map == "sonnenhang", "Free slot %d is visible in the proper library card" % slot)
		var loaded := Resort.new()
		check(Saves.load_game(loaded,path).ok and int(loaded.money) == int(model.money) and loaded.campaign.mode == "free", "Free slot %d opens with its own money and mode" % slot)
	check(Saves.path_for_map("sonnenhang",0,2) != Saves.path_for_map("sonnenhang",0,3), "Additional free slots are genuinely independent files")
	check(Saves.free_summary(1).occupied and Saves.free_summary(4).occupied, "Selecting another free slot cannot hide or destroy existing slot 1")
	Saves.active_free_slot = 4
	check(Saves.archive_free_slot(4) and not Saves.free_summary(4).occupied and Saves.free_summary(1).occupied, "Explicitly restarted slot is archived, other slots untouched")
	for slot in range(1,5):
		var path := Saves.path_for_map("sonnenhang",0,slot)
		for suffix in ["",".bak",".tmp"]: remove_file(path + suffix)
		remove_file(Saves.index_path(0,slot))
	Saves.active_free_slot = 1
	Saves.active_slot = 1
	var rescue_path := "user://skizones-test-legacy-lift-0332.json"
	remove_file(rescue_path)
	var old_model := Resort.new()
	old_model.new_game(true,20261027,"sonnenhang",true)
	var state: Dictionary = old_model.snapshot()
	check(state.lifts.size()>0, "Compatibility fixture has an original lift")
	if not state.lifts.is_empty():
		var first: Dictionary=state.lifts[0]
		var bottom: Vector2=Vector2(float(first.bottom[0]),float(first.bottom[1]))
		first.top=[bottom.x+18.0,bottom.y-9.0]
		put_state(rescue_path,state)
		var original_checksum := FileAccess.get_sha256(rescue_path)
		var incompatible := Resort.new()
		check(not incompatible.restore(state.duplicate(true)).ok, "Current build placement would reject the old shortened lift")
		var loaded_old := Resort.new()
		var result: Dictionary=Saves.load_game(loaded_old,rescue_path)
		check(result.ok and result.get("recovered",false) and loaded_old.lifts.size()==state.lifts.size(), "Legacy geometry recovery keeps all lifts instead of deleting the resort")
		check(result.ok and int(loaded_old.money)==int(state.money) and loaded_old.day==state.day and loaded_old.pistes.size()==state.pistes.size(), "Old money, calendar and pistes remain intact")
		check(FileAccess.get_sha256(rescue_path)==original_checksum and FileAccess.file_exists(str(result.get("archive",""))), "Recovery archives the original and never modifies the source")
	remove_file(rescue_path)
	print("SAVE-RESCUE-0332: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
