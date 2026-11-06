extends SceneTree
## 0.35: real pedestrian snow wear survives a checksum-verified save and reload.
## All destructive test writes use an isolated GitHub Actions data directory.
const Wear = preload("res://src/world/foot_wear.gd")
const Resort = preload("res://src/core/resort.gd")
const Saves = preload("res://src/core/save_store.gd")
var passed := 0
var failed := 0

func _init() -> void: call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok: passed += 1;print("PASS ",title)
	else: failed += 1;push_error("FAIL "+title)

## JSON roundtrips finite float directions at bounded precision.
## The semantic cell grid, hit count, and direction are what must survive.
func equivalent_cells(left: Variant, right: Variant) -> bool:
	if not left is Array or not right is Array or left.size() != right.size(): return false
	for i in range(left.size()):
		if not left[i] is Array or not right[i] is Array or left[i].size() != 5 or right[i].size() != 5: return false
		for field in range(3):
			if int(left[i][field]) != int(right[i][field]): return false
		var a := Vector2(float(left[i][3]),float(left[i][4]))
		var b := Vector2(float(right[i][3]),float(right[i][4]))
		if a.distance_to(b) > 0.00005: return false
	return true

func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test"):
		push_error("Require isolated skizones-test XDG_DATA_HOME")
		quit(1);return
	var paved := Wear.new()
	paved.cover_layout({"links":[{"points":[[0.0,0.0],[20.0,0.0]],"width":8.0}],"areas":[]})
	check(paved.covered_by_path(Vector2(8,0)) and not paved.covered_by_path(Vector2(8,7)), "Path-coverage lookup distinguishes built walkway corridors from natural snow")
	for step in range(30):
		paved.sample_guest(44,Vector3(3.0 if step%2==0 else 4.5,0,0),step,0)
	check(paved.export_state().is_empty(), "Footprints do not accumulate across a prepared path")
	paved.cover_layout({"links":[],"areas":[]})
	for step in range(30,60):
		paved.sample_guest(44,Vector3(3.0 if step%2==0 else 4.5,0,0),step,0)
	check(not paved.export_state().is_empty(), "Natural snow can accumulate footprints after its built path is removed")
	var wear := Wear.new()
	for i in range(45):
		wear.sample_guest(12,Vector3(0.1 if i%2==0 else 1.6,0,0.1),i,0)
	var frozen: Array=wear.export_state()
	check(frozen.size()>0 and Wear.valid_state(frozen), "Actual repeated pedestrian motion produces bounded serializable wear")
	check(Wear.wear_stage(int(frozen[0][2]))==3,"Repeated footsteps become a broad trodden trail")
	var clone := Wear.new()
	check(clone.import_state(frozen) and clone.export_state()==frozen,"Stable serialized snow state survives import with identical cell values")
	var poisoned: Array=frozen.duplicate(true)
	poisoned[0][2]=999999
	check(not clone.import_state(poisoned) and clone.export_state()==frozen,"Invalid wear is rejected without changing the already loaded scene")
	var duplicated: Array=frozen.duplicate(true)
	duplicated.append(frozen[0].duplicate())
	check(not Wear.valid_state(duplicated),"Duplicate snow cells are rejected")
	var invalid_direction: Array=frozen.duplicate(true)
	invalid_direction[0][3]=0.0
	invalid_direction[0][4]=0.0
	check(not Wear.valid_state(invalid_direction),"Zero and malformed direction vectors are rejected")
	var resort := Resort.new()
	resort.new_game(true,20261105,"sonnenhang",true)
	resort.foot_wear_cells=frozen.duplicate(true)
	var path: String = "user://skizones-test-footwear-035.json"
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	check(Saves.save_game(resort,path).ok,"Model and visual snow wear are atomically saved together")
	var read: Dictionary=Saves._read(path)
	check(read.ok and read.data.version==17 and Wear.valid_state(read.data.foot_wear) and equivalent_cells(read.data.foot_wear,frozen),"Checksum-protected v17 payload contains the unchanged footprints")
	var loaded := Resort.new()
	var loaded_result: Dictionary=Saves.load_game(loaded,path)
	check(loaded_result.ok and equivalent_cells(loaded.foot_wear_cells,frozen),"Full old resort geometry plus footprints reopen without losing snow")
	if not loaded_result.ok: print("DIAGNOSTIC LOAD ",loaded_result)
	var old: Dictionary=resort.snapshot()
	old.version=16
	old.erase("foot_wear")
	var migrated := Resort.new()
	check(migrated.restore(old).ok and migrated.foot_wear_cells.is_empty(),"Existing v16 saves remain valid and migrate to clean pedestrian snow")
	var bad: Dictionary=read.data.duplicate(true)
	bad.foot_wear[0][2]=-2
	var state_before: Dictionary=loaded.snapshot()
	check(not loaded.restore(bad).ok and loaded.snapshot()==state_before,"Malformed v17 wear cannot mutate an already active career")
	loaded.new_game(true,20261105,"sonnenhang",true)
	check(loaded.foot_wear_cells.is_empty(),"Starting a new resort cannot inherit the old slot's trail")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
