extends SceneTree
## Real regression: broken 0.42.2/0.42.3 sequence with day 7 primary
## and day 9 .bak. Both are checksum-verified and semantically valid.
## All files live under test-only local user:// and are cleaned afterward.
const Resort=preload("res://src/core/resort.gd")
const Saves=preload("res://src/core/save_store.gd")
const Manager=preload("res://src/core/save_management_038.gd")
const PATH:="user://career_3_sonnenhang.json"
var passed:int=0
var failed:int=0

func _init()->void:call_deferred("run")

func check(ok:bool,message:String)->void:
	if ok:passed+=1;print("PASS ",message)
	else:failed+=1;push_error("FAIL "+message)

func create_day(day:int,minute:int)->RefCounted:
	var model:=Resort.new()
	model.new_game(true,20261121,"sonnenhang",true)
	model.day=day
	model.minute=minute
	return model

func purge()->void:
	for suffix in ["",".bak",".tmp",".bak.tmp",".swap.tmp"]:
		var name:String=PATH+suffix
		if FileAccess.file_exists(name):DirAccess.remove_absolute(ProjectSettings.globalize_path(name))

func write_checksum(path:String,world:Dictionary)->void:
	var body:String=JSON.stringify(world,"",true,true)
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:push_error("Fixture could not be written");return
	file.store_string(JSON.stringify({"format":"SkiZones","checksum":body.sha256_text(),"payload":body}))
	file.close()

func swap_primary_backup()->void:
	var staging:String=PATH+".swap.tmp"
	var source:String=ProjectSettings.globalize_path(PATH)
	var backup:String=ProjectSettings.globalize_path(PATH+".bak")
	var stage:String=ProjectSettings.globalize_path(staging)
	if DirAccess.copy_absolute(source,stage)!=OK:push_error("Fixture stage failed");return
	if DirAccess.copy_absolute(backup,source)!=OK:push_error("Fixture primary failed");return
	if DirAccess.copy_absolute(stage,backup)!=OK:push_error("Fixture backup failed");return
	DirAccess.remove_absolute(stage)

func seed_day7_primary_day9_backup()->void:
	purge()
	check(Saves.save_game(create_day(7,800),PATH).get("ok",false),"Create a verified day 7 checkpoint")
	check(Saves.save_game(create_day(9,1020),PATH).get("ok",false),"Create a verified day 9 checkpoint")
	swap_primary_backup()
	check(int(Saves._read(PATH).data.get("day",0))==7 and int(Saves._read(PATH+".bak").data.get("day",0))==9,"Reproduce real day 7 primary with newer day 9 backup")

func run()->void:
	# Reported Samsung screenshot: day 7 at 19:59, no outdoor guests and
	# a substantial operating resort. This must save and reload when no
	# newer archive is present; the red header must not be an unconditional
	# "after closing" false positive.
	purge()
	var late_world:RefCounted=create_day(7,1199)
	var late_saved:Dictionary=Saves.save_game(late_world,PATH)
	check(late_saved.get("ok",false),"Day 7 at 19:59 can still be saved when it is the latest valid career")
	if late_saved.get("ok",false):
		var late_reload:RefCounted=Resort.new()
		var loaded_late:Dictionary=Saves.load_game(late_reload,PATH)
		check(loaded_late.get("ok",false) and late_reload.day==7 and late_reload.minute==1199,"A fresh loader restores the exact day-7 19:59 checkpoint")
	seed_day7_primary_day9_backup()
	var original_day9:String=FileAccess.get_sha256(PATH+".bak")
	var original_day7:String=FileAccess.get_sha256(PATH)
	var listed:Array=Saves.saved_resorts(3).filter(func(x):return str(x.get("map",""))=="sonnenhang")
	check(not listed.is_empty() and int(listed[0].get("day",0))==9 and str(listed[0].get("source",""))==PATH+".bak","Saved-resort list shows the newest day 9 backup, not day 7")
	var refusal:Dictionary=Saves.save_game(create_day(7,900),PATH)
	check(not refusal.get("ok",false) and FileAccess.get_sha256(PATH)==original_day7 and FileAccess.get_sha256(PATH+".bak")==original_day9,"Older autosave cannot overwrite or rotate the only day 9 backup")
	var loaded:RefCounted=Resort.new()
	var result:Dictionary=Saves.load_game(loaded,PATH)
	check(result.get("ok",false) and int(loaded.day)==9 and int(loaded.minute)==1020,"Loading automatically selects day 9 from newer backup")
	check(result.get("recovered",false) and str(result.get("source",""))==PATH+".bak","Newest backup is promoted through verified recovery path")
	check(FileAccess.get_sha256(PATH)!=original_day7 and Saves.load_game(Resort.new(),PATH).get("ok",false),"Day 9 survives further restarts as new primary")
	# Manual repair must not tell users that a *loadable* day 7 is already
	# the newest version when an independently verifiable day 9 survives.
	seed_day7_primary_day9_backup()
	var manual:Dictionary=Manager.repair("sonnenhang",3)
	check(manual.get("ok",false) and manual.get("changed",false),"Repair button promotes day 9 even when day 7 primary is structurally valid")
	check(int(Saves._read(PATH).data.get("day",0))==9 and int(Saves._read(PATH+".bak").data.get("day",0))==9,"Manual repair archives old primary without deleting newer backup")
	# A checksum-correct but unrestorable day-9 backup must never trigger an
	# invisible day-7 rollback or destruction of the only day-9 bytes.
	seed_day7_primary_day9_backup()
	var impossible:Dictionary=Saves._read(PATH+".bak").data.duplicate(true)
	impossible.pistes[0].points[0]=[99999999,99999999]
	write_checksum(PATH+".bak",impossible)
	var protected:String=FileAccess.get_sha256(PATH+".bak")
	var refused_load:Dictionary=Saves.load_game(Resort.new(),PATH)
	check(not refused_load.get("ok",false) and int(refused_load.get("newer_backup_day",0))==9 and int(refused_load.get("primary_day",0))==7,"Unrepairable day 9 backup blocks silent day 7 fallback")
	check(FileAccess.get_sha256(PATH+".bak")==protected and FileAccess.get_sha256(PATH)==original_day7,"Corrupted newer backup and old primary remain byte-for-byte unchanged")
	var blocked_save:Dictionary=Saves.save_game(create_day(8,920),PATH)
	check(not blocked_save.get("ok",false) and FileAccess.get_sha256(PATH+".bak")==protected,"Even unrecoverable newer day 9 bytes cannot be rotated away by day 8")
	purge()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
