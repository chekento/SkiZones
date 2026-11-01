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
func same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int): return absf(float(a)-float(b)) < 0.000001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not same(a[i],b[i]): return false
		return true
	return a==b
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
		if not same(model.campaign,old.campaign): print("CAREER_DIFF ",id," OLD=",JSON.stringify(old.campaign)," NEW=",JSON.stringify(model.campaign))
		check(same(model.money,old.money) and model.day == old.day and model.minute == old.minute and same(model.campaign,old.campaign), id + " money, day, missions and research remain unchanged")
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

