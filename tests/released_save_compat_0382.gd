extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Saves = preload("res://src/core/save_store.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Foot = preload("res://src/core/foot_network.gd")
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed+=1; print("PASS ",title)
	else: failed+=1; push_error("FAIL "+title)
func geometry(data: Dictionary) -> Array:
	var value: Array=[]
	for p in data.pistes: value.append([p.id,p.points,p.name])
	for l in data.lifts: value.append([l.id,l.bottom,l.top,l.kind])
	for b in data.buildings: value.append([b.id,b.point,b.kind])
	return value
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
	var folder:=OS.get_environment("SKIZONES_EARLY_FIXTURES")
	var releases:=OS.get_environment("SKIZONES_VERIFY_RELEASES").split(",",false)
	if folder.is_empty() or releases.is_empty():quit(1);return
	for release in releases:
		var path:String=folder.path_join(release+".json")
		var original:String=FileAccess.get_sha256(path)
		var read:Dictionary=Saves._read(path)
		check(read.ok,release+" original envelope and checksum")
		if not read.ok:continue
		var old:Dictionary=read.data
		var model:=Resort.new()
		var result:Dictionary=Saves.load_game(model,path)
		check(result.ok,release+" original release save loads")
		if not result.ok:continue
		check(model.guests.size()==old.guests.size(),release+" preserves all active guests")
		check(same(model.money,old.money) and model.day==old.day and model.minute==old.minute,release+" preserves money and calendar")
		var expected:Dictionary=old.duplicate(true)
		if int(old.version)<6:
			for i in range(expected.pistes.size()):
				expected.pistes[i].points=Foot.prepare_piste(old.pistes[i].points,old.lifts)
				expected.pistes[i].name=model.pistes[i].name
		check(same(geometry(model.snapshot()),geometry(expected)),release+" preserves all authored assets with established pre-v6 entrance migration")
		check(FileAccess.get_sha256(path)==original,release+" preserves original bytes")
		var copy:=Resort.new()
		check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok,release+" normal current-format round trip")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
