extends SceneTree
## Release gate: true archived 0.27 careers, lost passport, stale indexes,
## corrupted latest file, repeated 0.17 migration and read-only rescue.
const Saves=preload("res://src/core/save_store.gd")
const Resort=preload("res://src/core/resort.gd")
const Maps=preload("res://src/core/maps.gd")
var passed:=0
var failed:=0
var created: Array[String]=[]

func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS ",label)
	else:
		failed+=1
		push_error("FAIL " + label)

func copy_to(source: String, destination: String) -> bool:
	created.append(destination)
	return DirAccess.copy_absolute(ProjectSettings.globalize_path(source),ProjectSettings.globalize_path(destination)) == OK

func put(path: String, body: String) -> void:
	created.append(path)
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file!=null:
		file.store_string(body)
		file.close()

func signature(model: RefCounted) -> Array:
	var data: Dictionary=model.snapshot()
	return [data.get("map_id"),data.get("money"),data.get("day"),data.get("minute"),
		data.get("pistes",[]).size(),data.get("lifts",[]).size(),data.get("buildings",[]).size(),data.get("campaign",{}).get("rank",0),
		data.get("guests",[]).size()]

func _init()->void:
	call_deferred("run")

func run()->void:
	Saves.active_slot=1
	var folder:=OS.get_environment("SKIZONES_LEGACY_FIXTURES")
	check(not folder.is_empty(),"Real prior-release save fixtures supplied")
	if folder.is_empty():quit(1);return
	var originals: Dictionary={}
	var restored_count:=0
	for area in Maps.FANTASY_MAPS:
		var fixture: String=folder.path_join(area+".json")
		check(Saves._read(fixture).ok,area+" previously released file passes checksum verification")
		if not Saves._read(fixture).ok: continue
		originals[area]=FileAccess.get_sha256(fixture)
		var restored:=Resort.new()
		var loaded:=Saves.load_game(restored,fixture)
		check(loaded.ok and signature(restored)[0]==area,area+" opens directly in new gameplay")
		if loaded.ok: restored_count+=1
		check(FileAccess.get_sha256(fixture)==originals[area],area+" original source file remains unchanged")
	check(restored_count==Maps.FANTASY_MAPS.size(),"All eight older resorts are restorable")
	var source: String=folder.path_join("sonnenhang.json")
	var legacy: String=Saves.legacy_path("sonnenhang")
	put("user://slots-migrated-017","1") # old migration marker is already present
	check(copy_to(source,legacy),"Original old-style career restored after marker")
	var oldhash:=FileAccess.get_sha256(legacy)
	var slot_path:=Saves.path_for_map("sonnenhang",1)
	check(not FileAccess.file_exists(slot_path),"Former source initially has no slot-specific copy")
	check(Saves.migrate_legacy(),"Migration rescans even when original marker exists")
	check(Saves._read(slot_path).ok and FileAccess.get_sha256(slot_path)==oldhash,"New career path contains exact copy, not destructive migration")
	created.append(slot_path)
	var copyhash:=FileAccess.get_sha256(slot_path)
	check(Saves.migrate_legacy() and FileAccess.get_sha256(slot_path)==copyhash,"Repeated migrations never overwrite migrated careers")
	check(Saves.has_readable_save("sonnenhang",1),"Lost passport cannot conceal a checksum-valid saved resort")
	check(not Saves.has_readable_save("sonnenhang",2),"Old slot 1 data never leaks into unrelated career 2")
	var visible: Dictionary=Saves.summary(1)
	check(visible.occupied and str(visible.map)=="sonnenhang","Career overview lists migrated resort without a passport/index")
	var model:=Resort.new()
	var result:=Saves.load_game(model,slot_path)
	check(result.ok and model.map_id=="sonnenhang" and model.pistes.size()>0,"Migrated career resumes with original pistes")
	var malformed_index:=Saves.index_path(1)
	put(malformed_index,JSON.stringify({"version":1,"map":"fichtenkamm","day":1,"money":0,"rank":1,"saved_at":1}))
	check(str(Saves.summary(1).get("map",""))=="sonnenhang","Stale career index never hides a still-valid mountain")
	var secondary:=Saves.path_for_map("fichtenkamm",1)
	put(secondary,"invalid-json")
	check(copy_to(folder.path_join("fichtenkamm.json"),secondary+".bak"),"Valid former save backup available")
	var secondary_sha:=FileAccess.get_sha256(secondary)
	var backup_sha:=FileAccess.get_sha256(secondary+".bak")
	var from_backup:=Resort.new()
	var bak_result:=Saves.load_game(from_backup,secondary)
	check(bak_result.ok and str(bak_result.source).ends_with(".bak") and from_backup.map_id=="fichtenkamm","Corrupt latest save recovers from complete original backup")
	check(FileAccess.get_sha256(secondary)==secondary_sha and FileAccess.get_sha256(secondary+".bak")==backup_sha,"Backup recovery never writes either source")
	var third_legacy:=Saves.legacy_path("gletscherwelt")
	check(copy_to(folder.path_join("gletscherwelt.json"),third_legacy),"Unmigrated original 0.27 save present")
	var third_sha:=FileAccess.get_sha256(third_legacy)
	var third_path:=Saves.path_for_map("gletscherwelt",1)
	put(third_path,"corrupt - do not overwrite")
	check(Saves.has_readable_save("gletscherwelt",1),"Read-only old save fallback remains visible even with broken new slot copy")
	var from_legacy:=Resort.new()
	var older:=Saves.load_game(from_legacy,third_path)
	check(older.ok and older.get("legacy",false) and from_legacy.map_id=="gletscherwelt","Restore old original when new career file cannot be parsed")
	check(FileAccess.get_sha256(third_legacy)==third_sha and FileAccess.get_file_as_string(third_path).begins_with("corrupt"),"Fallback never overwrites original or corrupted data")
	var fourth:=Saves.path_for_map("dreigipfel",1)
	var new_model:=Resort.new()
	new_model.new_game(true,20261027,"dreigipfel")
	check(Saves.save_game(new_model,fourth).ok,"New save uses original atomic-and-backup writer")
	created.append(fourth)
	var verify:=Resort.new()
	check(Saves.load_game(verify,fourth).ok and signature(verify)==signature(new_model),"New version round-trip preserves all permanent and transient state")
	for target in created:
		if FileAccess.file_exists(target):DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
	for path in [slot_path+".bak",third_path+".bak",fourth+".bak"]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed>0 else 0)
