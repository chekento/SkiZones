extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Saves = preload("res://src/core/save_store.gd")
const Maps = preload("res://src/core/maps.gd")
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ", label)
	else: failed += 1; push_error("FAIL " + label)
func geometry(model: RefCounted) -> Array:
	var result := []
	for piste in model.pistes: result.append(["p",piste.id,piste.points,piste.name,piste.get("width",20)])
	for lift in model.lifts: result.append(["l",lift.id,lift.bottom,lift.top,lift.kind])
	for building in model.buildings: result.append(["b",building.id,building.point,building.kind])
	return result
func run() -> void:
	var folder := OS.get_environment("SKIZONES_LEGACY_FIXTURES")
	for id in Maps.FANTASY_MAPS:
		var path := folder.path_join(id + ".json")
		var before := FileAccess.get_sha256(path)
		var model := Resort.new()
		var result := Saves.load_game(model,path)
		check(result.ok, id + " original 0.19 career loads in the current version")
		if not result.ok: continue
		var old: Dictionary = Saves._read(path).data
		check(model.money == old.money and model.day == old.day and model.minute == old.minute and model.campaign == old.campaign, id + " money, day, missions and research remain unchanged")
		check(model.pistes.size() == old.pistes.size() and model.lifts.size() == old.lifts.size() and model.guests.size() == old.guests.size(), id + " construction and all active guests remain")
		var expected := geometry(model)
		var worker := Thread.new()
		var error := worker.start(func():
			var restored := Resort.new()
			var loaded := Saves.load_game(restored,path)
			return {"model":restored,"result":loaded}
		)
		check(error == OK,id + " background loader starts")
		while worker.is_alive(): await process_frame
		var loaded: Variant = worker.wait_to_finish()
		check(loaded is Dictionary and loaded.result.ok and geometry(loaded.model) == expected,id + " background restoration keeps every piste, lift and building")
		check(FileAccess.get_sha256(path) == before,id + " original save is never overwritten by loading")
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
