extends SceneTree
## Run with the CURRENT code against actual free/mission bytes produced by
## pinned unmodified SkiZones releases; never touch personal Android data.
const Resort = preload("res://src/core/resort.gd")
const Saves = preload("res://src/core/save_store.gd")
const Manager = preload("res://src/core/save_management_038.gd")

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func copy_original(source: String, target: String) -> bool:
	if not FileAccess.file_exists(source):
		check(false, "Missing original fixture " + source.get_file())
		return false
	var status: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(target))
	var intact: bool = status == OK and FileAccess.get_sha256(source) == FileAccess.get_sha256(target)
	check(intact, "Exact original-byte fixture " + source.get_file())
	return intact

func inspect_mode(map_id: String, slot: int, free_slot: int, source: String, label: String) -> void:
	var target: String = Saves.path_for_map(map_id,slot,free_slot)
	# Clean only this deliberately isolated CI test directory.
	for file in [target,target+".bak"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	if not copy_original(source,target) or not copy_original(source+".bak",target+".bak"):
		return
	var primary_hash: String = FileAccess.get_sha256(target)
	var backup_hash: String = FileAccess.get_sha256(target+".bak")
	var first: Dictionary = Saves._read(source)
	var second: Dictionary = Saves._read(source+".bak")
	check(first.ok and second.ok,label+" both original payloads pass checksum")
	if not first.ok or not second.ok:return
	var report: Dictionary = Manager.inspect(map_id,slot,free_slot)
	if report.loadable != 2:
		for entry in report.files:
			print("DIAGNOSTIC ",label," ",entry.name," checksum=",entry.checksum," loadable=",entry.loadable," recoverable=",entry.recoverable," ",entry.message)
	check(report.verified == 2 and report.loadable == 2 and report.recoverable == 0,label+" two source files are semantically loadable (not merely checksum-valid)")
	var model: RefCounted = Resort.new()
	var result: Dictionary = Saves.load_game(model,target)
	check(result.ok,label+" normal Continue uses the historical primary save")
	if result.ok:
		check(model.map_id == map_id and model.day == int(first.data.day),label+" map and play day remain the original values")
		check(model.pistes.size() == first.data.pistes.size() and model.lifts.size() == first.data.lifts.size() and model.buildings.size() == first.data.buildings.size(),label+" all old pistes, lifts and buildings survive")
		if slot == 0:
			check(str(model.campaign.get("mode","")) == "free",label+" preserves unlimited free-build access")
		else:
			check(model.operations is Dictionary,label+" preserves scenario operations")
	check(primary_hash == FileAccess.get_sha256(target) and backup_hash == FileAccess.get_sha256(target+".bak"),label+" inspection and normal loading never mutate either source")
	# Simulate a device with a damaged primary and its genuine older backup.
	# The original fixtures remain read-only; this is a disposable copy.
	var file: FileAccess = FileAccess.open(target,FileAccess.WRITE)
	if file != null:
		file.store_string("{truncated")
		file.close()
		var rescue_report: Dictionary = Manager.inspect(map_id,slot,free_slot)
		check(rescue_report.loadable == 1 and rescue_report.verified == 1,label+" healthy historical backup found despite damaged primary")
		var repaired: Dictionary = Manager.repair(map_id,slot,free_slot)
		check(repaired.ok and FileAccess.get_sha256(target) == backup_hash,label+" recovery installs the exact original backup")
		var restored: RefCounted = Resort.new()
		check(Saves.load_game(restored,target).ok,label+" repaired save actually resumes")
	check(primary_hash == FileAccess.get_sha256(source) and backup_hash == FileAccess.get_sha256(source+".bak"),label+" original release fixture is byte-identical after repair test")

func run() -> void:
	var folder: String = OS.get_environment("SKIZONES_EARLY_FIXTURES")
	var release: String = OS.get_environment("SKIZONES_FIXTURE_RELEASE")
	if folder.is_empty() or not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-historical"):
		push_error("Refusing to run restoration outside an isolated CI fixture directory")
		quit(1)
		return
	Saves.active_slot=0
	for index in [1,2]:
		inspect_mode("sonnenhang",0,index,folder.path_join(release+"-free-"+str(index)+".json"),release+" sandbox slot "+str(index))
	Saves.active_slot=1
	inspect_mode("braunlage",1,1,folder.path_join(release+"-mission.json"),release+" Braunlage mission")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
