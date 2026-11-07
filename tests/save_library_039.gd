extends SceneTree
## v0.39 save-library regression: mission saves use the same verified rescue
## without cross-contaminating free/career slots.
const Resort=preload("res://src/core/resort.gd")
const Saves=preload("res://src/core/save_store.gd")
const Manager=preload("res://src/core/save_management_038.gd")
const Geo=preload("res://src/core/real_resorts.gd")
var passed:=0
var failed:=0

func _init() -> void:call_deferred("run")
func check(ok:bool,title:String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)

func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-save-library-039"):
		push_error("Refusing to touch a non-test user save directory")
		quit(1);return
	var id:String=str(Geo.IDS[0])
	var scenario:String=Saves.path_for_map(id,1)
	var legacy:String=Saves.legacy_path(id)
	var career:String=Saves.path_for_map("sonnenhang",2)
	var sandbox:String=Saves.path_for_map("sonnenhang",0,3)
	var resort:=Resort.new()
	resort.new_game(true,20261107,id)
	check(Saves.save_game(resort,scenario).ok,"Mission save written to its own scenario filename")
	var original:String=FileAccess.get_sha256(scenario)
	var seen:Dictionary=Manager.inspect(id,1)
	check(seen.ok and seen.loadable==1 and seen.verified==1,"Mission data is semantically checked, not just checksum verified")
	check(Saves.load_game(Resort.new(),scenario).ok,"Mission save reloads through the same engine as careers")
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(scenario),ProjectSettings.globalize_path(scenario+".bak"))==OK,"Mission backup written")
	var bad:=FileAccess.open(scenario,FileAccess.WRITE)
	bad.store_string("{broken mission primary")
	bad.close()
	seen=Manager.inspect(id,1)
	check(seen.ok and seen.loadable==1 and seen.files.size()==2,"Damaged mission primary does not conceal healthy backup")
	var fixed:Dictionary=Manager.repair(id,1)
	check(fixed.ok and fixed.changed and FileAccess.get_sha256(scenario)==original,"Mission repair restores exactly verified backup bytes")
	check(Saves.load_game(Resort.new(),scenario).ok,"Repaired mission resumes normally")
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(scenario),ProjectSettings.globalize_path(legacy))==OK,"Historical scenario path preserved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scenario))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scenario+".bak"))
	Saves.active_slot=0
	check(Saves.has_any_save(id) and Saves.has_readable_save(id),"Historical mission remains discoverable even while free mode is active")
	check(Saves.load_game(Resort.new(),scenario).ok,"Historical mission filename remains loadable without moving original")
	check(Manager.inspect(id,1).loadable==1,"Historical mission filename is available to manual inspection")
	check(not FileAccess.file_exists(career) and not FileAccess.file_exists(sandbox),"Mission recovery does not create or overwrite unrelated careers or free slots")
	check(FileAccess.get_sha256(legacy)==original,"Historical mission source remains byte-identical")
	print("SAVE LIBRARY v0.39: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
