extends SceneTree
## Execute against an unchanged historical checkout, never the current model.
const Resort = preload("res://src/core/resort.gd")
const Saves = preload("res://src/core/save_store.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	var folder := OS.get_environment("SKIZONES_EARLY_FIXTURES")
	var release := OS.get_environment("SKIZONES_FIXTURE_RELEASE")
	if folder.is_empty() or release not in ["0.1.1","0.2.0","0.3.0","0.4.0","0.5.0","0.6.0","0.7.0","0.8.0","0.9.0","0.10.0","0.11.0","0.12.0","0.13.0","0.14.0","0.15.0","0.16.0"]:
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var model := Resort.new()
	model.new_game(true,20261027)
	model.money=912345.25
	for i in range(18): model.admit_guest(2)
	for i in range(80): model.advance_minute(false)
	var copy := Resort.new()
	var valid: bool=copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok
	var saved: bool=Saves.save_game(model,folder.path_join(release+".json")).ok
	print("ORIGINAL ",release," version=",model.snapshot().version," guests=",model.guests.size())
	var ok := valid and saved and not model.guests.is_empty() and not model.pistes.is_empty()
	print("RESULT: %d passed; %d failed" % [1 if ok else 0,0 if ok else 1])
	quit(0 if ok else 1)
