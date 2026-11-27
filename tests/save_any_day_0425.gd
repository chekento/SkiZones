extends SceneTree
## 0.42.5 regression: save and reload at ANY valid game day, including
## branches backwards from an existing future primary or .bak checkpoint.
const Resort=preload("res://src/core/resort.gd")
const Saves=preload("res://src/core/save_store.gd")
const PATH:="user://regression_save_any_day_0425.json"
var passed:int=0
var failed:int=0

func _init()->void:call_deferred("run")

func check(value:bool,description:String)->void:
	if value:passed+=1;print("PASS ",description)
	else:failed+=1;push_error("FAIL "+description)

func make_world(day:int,minute:int)->RefCounted:
	var model:RefCounted=Resort.new()
	model.new_game(true,20261122,"sonnenhang",true)
	model.day=day
	model.minute=minute
	return model

func make_career_world(day:int,minute:int)->RefCounted:
	var model:RefCounted=Resort.new()
	# Starter infrastructure is seeded only for career mode. Free build is false.
	model.new_game(true,20261122,"sonnenhang",true)
	model.day=day
	model.minute=minute
	return model

func clear_files()->void:
	for suffix in ["",".tmp",".bak",".bak.tmp"]:
		var path:String=PATH+suffix
		if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func reload_is(day:int,minute:int)->bool:
	var world:RefCounted=Resort.new()
	var result:Dictionary=Saves.load_game(world,PATH)
	return bool(result.get("ok",false)) and int(world.day)==day and int(world.minute)==minute

func archived_sha(path:String,checksum:String)->bool:
	var folder:DirAccess=DirAccess.open("user://save-recovery")
	if folder==null:return false
	for entry in folder.get_files():
		if entry.begins_with(path.get_file()+"-") and entry.ends_with(".before-rewind") and FileAccess.get_sha256("user://save-recovery/"+entry)==checksum:
			return true
	return false

func run()->void:
	clear_files()
	for day in [1,7,9,10,30,100,365]:
		var minute:int=480+day%500
		var result:Dictionary=Saves.save_game(make_world(day,minute),PATH)
		check(result.get("ok",false),"Write at any valid day %d" % day)
		check(reload_is(day,minute),"New process reloads exact day %d and clock" % day)
	# Deliberately save an earlier day even though the primary and backup
	# hold a later day. The old bytes remain recoverable, not overwritten.
	var original_sha:String=FileAccess.get_sha256(PATH)
	var backward:Dictionary=Saves.save_game(make_world(5,890),PATH)
	check(backward.get("ok",false),"Explicit day 5 save succeeds after day 365")
	check(reload_is(5,890),"Day 5 is authoritative after save, not silently day 365")
	check(archived_sha(PATH,original_sha),"Prior day-365 primary preserved as exact archived bytes")
	var forward:Dictionary=Saves.save_game(make_world(5,980),PATH)
	check(forward.get("ok",false) and reload_is(5,980),"Saving the same day at a later minute always works")
	# Reload is a read action, never a reason to lock subsequent saves.
	var after_load:RefCounted=Resort.new()
	check(Saves.load_game(after_load,PATH).get("ok",false),"Explicit reload works without restarting the process")
	after_load.day=8
	after_load.minute=1000
	check(Saves.save_game(after_load,PATH).get("ok",false) and reload_is(8,1000),"A loaded career can be saved again on a later day")
	var good_sha:String=FileAccess.get_sha256(PATH)
	var invalid:RefCounted=make_world(12,900)
	invalid.pistes[0].points[0]=[99999999,99999999]
	check(not Saves.save_game(invalid,PATH).get("ok",false),"Unrestorable permanent geometry is rejected safely")
	check(FileAccess.get_sha256(PATH)==good_sha and reload_is(8,1000),"An invalid attempted write does not damage the playable career")
	# Resume handoff: UI checkpoints can be tied to a known-good backup,
	# even when the newer primary is also checksum-valid.
	var career_path:String=Saves.path_for_map("sonnenhang",2)
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(career_path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(career_path+suffix))
	check(Saves.save_game(make_career_world(7,810),career_path).get("ok",false),"Career slot 2 saves day 7")
	var saved_session_sha:String=FileAccess.get_sha256(career_path)
	check(Saves.save_game(make_career_world(9,1000),career_path).get("ok",false),"Career slot 2 saves day 9")
	check(Saves.session_source_matches("sonnenhang",2,saved_session_sha),"Session checksum matching checks older backup after newer primary")
	check(Saves.session_source_matches("sonnenhang",2,FileAccess.get_sha256(career_path)),"Session checksum also accepts current primary")
	check(not Saves.session_source_matches("sonnenhang",2,"invalid-checksum"),"Unmatched session checksum is safely rejected")
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		if FileAccess.file_exists(career_path+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(career_path+suffix))
	clear_files()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
