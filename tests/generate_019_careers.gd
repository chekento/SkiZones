extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Ops = preload("res://src/core/operations.gd")
const Maps = preload("res://src/core/maps.gd")
var passed := 0
var failed := 0
func _init() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ", label)
	else: failed += 1; push_error("FAIL " + label)
func run() -> void:
	var folder := OS.get_environment("SKIZONES_LEGACY_FIXTURES")
	DirAccess.make_dir_recursive_absolute(folder)
	for id in Maps.FANTASY_MAPS:
		var model := Resort.new()
		model.new_game(true, 20261027, id)
		Ops.enable(model)
		model.enable_runtime_rules()
		model.money = 912345.25
		for index in range(12): model.admit_guest(2, "mixed")
		if not model.routes_for(0).is_empty(): model.admit_guest(0, "family", 5)
		for step in range(240): model.advance_minute(false)
		var payload: String = JSON.stringify(model.snapshot(), "", true, true)
		var copy := Resort.new()
		check(copy.restore(JSON.parse_string(payload)).ok, id + " is a valid save under the original 0.19 release")
		var file := FileAccess.open(folder.path_join(id + ".json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"format":"SkiZones","checksum":payload.sha256_text(),"payload":payload}))
		file.close()
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
