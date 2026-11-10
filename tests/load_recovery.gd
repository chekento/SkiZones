extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Saves = preload("res://src/core/save_store.gd")
const Progress = preload("res://src/core/load_progress.gd")
var passed := 0
var failed := 0
var cleanup: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed += 1; print("PASS ",title)
	else: failed += 1; push_error("FAIL " + title)
func write_data(path: String, data: Dictionary, bad_checksum: bool = false) -> void:
	var payload := JSON.stringify(data,"",true,true)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"format":"SkiZones","checksum":"wrong" if bad_checksum else payload.sha256_text(),"payload":payload}))
	file.close()
	cleanup.append(path)
func run() -> void:
	var source := OS.get_environment("SKIZONES_LEGACY_FIXTURES").path_join("sonnenhang.json")
	var data: Dictionary = Saves._read(source).data
	check(not data.guests.is_empty(),"Original 0.19 recovery fixture has active guests")
	var broken: Dictionary = data.duplicate(true)
	broken.guests[0].route_index = 999999
	var strict := Resort.new()
	check(not strict.restore(broken.duplicate(true)).ok,"A broken transient route is rejected by normal validation")
	var path := "user://recovery0201-guests.json"
	write_data(path,broken)
	write_data(path+".bak",data)
	var original_hash := FileAccess.get_sha256(path)
	var backup_hash := FileAccess.get_sha256(path+".bak")
	var full := Resort.new()
	var full_result := Saves.load_game(full,path)
	check(full_result.ok and full_result.recovered and full_result.get("auto_saved",false) and full_result.source.ends_with(".bak") and full.guests.size()==data.guests.size(),"A complete verified backup is promoted automatically without dropping visitors")
	if full_result.get("auto_saved",false):
		cleanup.append(str(full_result.archive))
	check(FileAccess.get_sha256(str(full_result.get("archive","")))==original_hash and FileAccess.get_sha256(path+".bak")==backup_hash and Saves._read(path).ok,"Corrupt primary is archived exactly; verified backup and repaired primary remain readable")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".bak"))
	write_data(path,broken)
	var recovered := Resort.new()
	var result := Saves.load_game(recovered,path)
	check(result.ok and result.get("recovered",false),"A damaged transient guest cannot block recovery of a valid resort")
	if result.ok and result.get("recovered",false):
		cleanup.append(result.archive)
		check(FileAccess.file_exists(result.archive) and FileAccess.get_sha256(result.archive)==original_hash and FileAccess.get_sha256(path)!=original_hash and Saves._read(path).ok,"The complete original is archived byte-for-byte, then replaced only by a tested repair")
		check(recovered.pistes.size()==data.pistes.size() and recovered.lifts.size()==data.lifts.size() and recovered.buildings.size()==data.buildings.size(),"Recovery retains all pistes, lifts and buildings")
		var intact := true
		for index in range(data.pistes.size()): intact = intact and recovered.pistes[index].points==data.pistes[index].points and recovered.pistes[index].name==data.pistes[index].name
		check(intact and absf(recovered.money-float(data.money))<0.000001 and recovered.day==data.day,"Recovery keeps exact piste geometry, names, money and operating day")
		check(recovered.guests.is_empty() and recovered.parties.is_empty(),"Recovery explicitly resets only transient visitor state")
		check(result.get("auto_saved",false) and Saves.load_game(Resort.new(),path).ok,"Recovered construction was automatically saved and reloads on the next launch")
	var structure: Dictionary = data.duplicate(true)
	structure.pistes[0].points[0]=[99999999,99999999]
	var unsafe := "user://recovery0201-unsafe.json"
	write_data(unsafe,structure)
	var unchanged := Resort.new();unchanged.new_game(true)
	var money: float = unchanged.money
	check(not Saves.load_game(unchanged,unsafe).ok and unchanged.money==money,"Invalid permanent construction is not accepted by the recovery path")
	var checksum := "user://recovery0201-checksum.json"
	write_data(checksum,data,true)
	check(not Saves.load_game(Resort.new(),checksum).ok,"Recovery never bypasses a failed file checksum")
	var progress := Progress.new()
	var worker := Thread.new()
	worker.start(func():
		for index in range(101): progress.report(float(index), "work", index, 100)
	)
	while worker.is_alive(): await process_frame
	worker.wait_to_finish()
	var state := progress.snapshot()
	check(state.percent==100.0 and state.done==100 and state.total==100,"Worker progress reports completed work through a synchronized snapshot")
	progress.report(50.0,"next",2,4)
	check(progress.snapshot().percent==100.0 and progress.snapshot().done==2,"Activity details can update without inventing or regressing percentage")
	for file in cleanup:
		if FileAccess.file_exists(file): DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	for suffix in [".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)

