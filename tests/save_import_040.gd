extends SceneTree
## Isolated 0.40 import safety: no production data and no Android file picker.
const Saves=preload("res://src/core/save_store.gd")
const Importer=preload("res://src/core/save_import_040.gd")
const Resort=preload("res://src/core/resort.gd")
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)

func run() -> void:
	if OS.get_environment("SKIZONES_SAFE_IMPORT_TEST")!="1" or not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-import-040"):
		push_error("Refusing save-import fixture outside isolated test user data")
		quit(1);return
	var token:String="0123456789abcdef0123456789abcdef"
	var folder:String="user://import-inbox/"+token
	check(Importer.valid_token(token) and not Importer.valid_token("../foo"),"Inbox token cannot be a path")
	check(Importer._safe_entry(token,{"name":"../../career_1_sonnenhang.json"})=="","Archive metadata cannot traverse private save paths")
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))==OK,"Private import staging is available")
	var original:RefCounted=Resort.new()
	original.new_game(true,20261108)
	original.money=38721.0
	var target:String=Saves.path_for_map("sonnenhang",2)
	check(Saves.save_game(original,target).ok,"An existing career is written before the import")
	var old_primary:String=FileAccess.get_sha256(target)
	check(Saves.save_game(original,target).ok,"A last-good target backup exists")
	var old_backup:String=FileAccess.get_sha256(target+".bak")
	var candidate:RefCounted=Resort.new()
	candidate.new_game(true,20261109)
	candidate.money=234565.0
	candidate.day=9
	var source:String=folder+"/00.json"
	check(Saves.save_game(candidate,source).ok,"Source career is staged outside the real slot")
	var source_sha:String=FileAccess.get_sha256(source)
	var entry:Dictionary={"name":"00.json","source":"00-career_3_sonnenhang.json","bytes":FileAccess.get_length(source),"sha256":source_sha}
	var meta:Dictionary={"token":token,"status":"ready","files":[entry]}
	var preview:Dictionary=Importer.inspect(token,meta,2)
	check(preview.ok and preview.verified==1 and preview.selected.map=="sonnenhang","Validated preview recognizes exact career mode and map")
	check(int(preview.selected.day)==9 and int(preview.selected.money)==234565,"Import preview shows real day and money, not assumed defaults")
	check(FileAccess.get_sha256(target)==old_primary and FileAccess.get_sha256(target+".bak")==old_backup,"Read-only preview cannot modify an existing career or backup")
	var wrong_slot:Dictionary=Importer.inspect(token,meta,0,1)
	check(not wrong_slot.ok,"Career data never silently becomes a free-build save")
	check(not Importer.inspect("../evil",meta,2).ok,"A forged token is refused before file inspection")
	var activated:Dictionary=Importer.activate(preview.selected)
	check(activated.ok,"Explicitly confirmed compatible career is committed safely")
	var loaded:RefCounted=Resort.new()
	check(Saves.load_game(loaded,target).ok and int(loaded.money)==234565 and loaded.day==9,"Imported career remains playable after a complete independent load")
	check(FileAccess.get_sha256(source)==source_sha,"Original selected import file survives activation byte-for-byte")
	var folder_name:String=str(activated.get("archive",""))
	check(not folder_name.is_empty() and FileAccess.get_sha256(folder_name+"/"+target.get_file())==old_primary,"Overwritten target primary is archived with its exact checksum")
	check(FileAccess.get_sha256(folder_name+"/"+(target+".bak").get_file())==old_backup,"Previous backup is archived independently before import")
	var current:String=FileAccess.get_sha256(target)
	var damaged:FileAccess=FileAccess.open(source,FileAccess.WRITE)
	damaged.store_string("{corrupt after preview");damaged.close()
	check(not Importer.activate(preview.selected).ok,"An import source changed after preview is rejected")
	check(FileAccess.get_sha256(target)==current,"Invalid import cannot overwrite an already playable resort")
	var incompatible:Dictionary=Importer.inspect(token,meta,2)
	check(not incompatible.ok,"Previously verified SHA cannot authorize replaced bytes")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
