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
func run() -> void:
	var folder := OS.get_environment("SKIZONES_EARLY_FIXTURES")
	if folder.is_empty(): quit(1); return
	for release in ["0.1.1","0.6.0"]:
		var path := folder.path_join(release+".json")
		var original := FileAccess.get_sha256(path)
		var read := Saves._read(path)
		check(read.ok,release+" original envelope passes its actual checksum")
		if not read.ok: continue
		var old: Dictionary=read.data
		var model := Resort.new()
		var result: Dictionary=Saves.load_game(model,path)
		check(result.ok,release+" original resort loads")
		if not result.ok: print(result); continue
		check(not result.get("recovered",false) and model.guests.size()==old.guests.size(),release+" keeps all actual active guests without fallback reset")
		check(is_equal_approx(model.money,float(old.money)) and model.day==old.day and model.minute==old.minute,release+" preserves money and calendar exactly")
		var expected: Dictionary=old.duplicate(true)
		if int(old.version)<6:
			for i in range(expected.pistes.size()):
				# Existing pre-v6 migration moves only station entrances out of
				# machinery and assigns piste numbers; interior waypoints survive.
				expected.pistes[i].points=Foot.prepare_piste(old.pistes[i].points,old.lifts)
				expected.pistes[i].name=model.pistes[i].name
		check(geometry(model.snapshot())==geometry(expected),release+" retains every asset with only the established station-clearance migration")
		check(FileAccess.get_sha256(path)==original,release+" loading leaves the source file byte-for-byte unchanged")
		var copy := Resort.new()
		check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok,release+" migration produces a valid current save")
		var rides: int=model.total_rides
		for i in range(300): model.advance_minute(false)
		check(model.total_rides>rides,release+" original guests actually ski the original runs after restoration")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
