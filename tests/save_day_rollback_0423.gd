extends SceneTree
## Repro: Android player has saved day 9, older .bak is day 7.
## A checksum-valid primary can fail semantic restore: NEVER silently load
## day 7, and NEVER claim success for a new save that cannot be reloaded.
const Resort=preload("res://src/core/resort.gd")
const Saves=preload("res://src/core/save_store.gd")
var passed:int=0
var failed:int=0
const PATH:="user://regression_save_day_rollback_0423.json"

func _init()->void:call_deferred("run")

func check(ok:bool,description:String)->void:
	if ok:passed+=1;print("PASS ",description)
	else:failed+=1;push_error("FAIL "+description)

func snapshot_at(day:int,minute:int=900)->RefCounted:
	var model:=Resort.new()
	model.new_game(true,20261121,"sonnenhang",true)
	model.day=day
	model.minute=minute
	return model

func write_verified(path:String,data:Dictionary)->void:
	var payload:String=JSON.stringify(data,"",true,true)
	var file:FileAccess=FileAccess.open(path,FileAccess.WRITE)
	if file==null:push_error("Could not write the controlled test fixture");return
	file.store_string(JSON.stringify({"format":"SkiZones","checksum":payload.sha256_text(),"payload":payload}))
	file.flush()
	file.close()

func clear_files()->void:
	for p in [PATH,PATH+".tmp",PATH+".bak",PATH+".bak.tmp"]:
		if FileAccess.file_exists(p):DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func run()->void:
	clear_files()
	var base:RefCounted=snapshot_at(7,880)
	var first:Dictionary=Saves.save_game(base,PATH)
	check(bool(first.get("ok",false)),"Day 7 creates a round-trip verified checkpoint")
	var current:RefCounted=snapshot_at(9,1020)
	var second:Dictionary=Saves.save_game(current,PATH)
	check(bool(second.get("ok",false)),"Day 9 overwrites only after semantic restore succeeded")
	var main_read:Dictionary=Saves._read(PATH)
	var backup_read:Dictionary=Saves._read(PATH+".bak")
	check(main_read.get("ok",false) and int(main_read.data.day)==9 and backup_read.get("ok",false) and int(backup_read.data.day)==7,"Day 9 is primary while day 7 remains a valid backup")
	var from_disk:RefCounted=Resort.new()
	var loaded:Dictionary=Saves.load_game(from_disk,PATH)
	check(loaded.get("ok",false) and int(from_disk.day)==9 and int(from_disk.minute)==1020,"Normal fresh-process loader resumes exact day 9 progress")
	var main_sha:String=FileAccess.get_sha256(PATH)
	var earlier:RefCounted=snapshot_at(8)
	var refused:Dictionary=Saves.save_game(earlier,PATH)
	check(not refused.get("ok",false) and FileAccess.get_sha256(PATH)==main_sha,"Stale in-memory day 8 can never overwrite verified day 9")
	# A semantically impossible fresh snapshot must be refused even if its
	# JSON and SHA-256 checksum are internally consistent.
	var invalid_live:RefCounted=snapshot_at(10)
	for attempt in range(8):
		if invalid_live.admit_guest(2):break
	if not invalid_live.guests.is_empty():
		invalid_live.guests[0].route_index=999999
		var bad_restore:Dictionary=Resort.new().restore(invalid_live.snapshot())
		check(not bad_restore.get("ok",false),"Fixture really is semantically unrestorable, despite well-formed JSON")
		var invalid_write:Dictionary=Saves.save_game(invalid_live,PATH)
		check(not invalid_write.get("ok",false) and FileAccess.get_sha256(PATH)==main_sha,"Invalid day 10 cannot replace valid day 9 or poison its backup")
	else:
		check(false,"Fixture needs at least one real skier with a route")
	# The exact user bug: a valid checksum on day 9 but a construction
	# rule from the prior version rejects a strict restore. Recovery must
	# first preserve day 9, before consulting the older day 7 .bak.
	var malformed:Dictionary=main_read.data.duplicate(true)
	if malformed.get("pistes",[]).is_empty():
		check(false,"Starter resort must provide a piste for the legacy geometry fixture")
	else:
		malformed.pistes[0].difficulty=(int(malformed.pistes[0].difficulty)+1)%3
		var strict:RefCounted=Resort.new()
		var compatible:RefCounted=Resort.new()
		check(not strict.restore(malformed.duplicate(true)).ok and compatible.restore(malformed.duplicate(true),true).ok,"Primary day 9 needs safe historical geometry repair")
		write_verified(PATH,malformed)
		var malformed_sha:String=FileAccess.get_sha256(PATH)
		var rescued:RefCounted=Resort.new()
		var load_result:Dictionary=Saves.load_game(rescued,PATH)
		check(load_result.get("ok",false) and rescued.day==9 and rescued.minute==1020,"Loader repairs the newer day 9 instead of reverting to day 7")
		check(str(load_result.get("source",""))==PATH,"Recovery explicitly selects the newest verified primary")
		check(load_result.get("auto_saved",false) and FileAccess.get_sha256(PATH)!=malformed_sha,"Recovered day 9 was semantically verified and activated")
		check(str(load_result.get("archive",""))!="" and FileAccess.get_sha256(str(load_result.get("archive","")))==malformed_sha,"Every original day 9 byte was preserved before repair")
		check(Saves.load_game(Resort.new(),PATH).ok,"Repaired day 9 is normally loadable on the next restart")
		# Truly invalid permanent geometry must not be 'fixed' by dropping
		# back to a 2-days-old checkpoint without user consent.
		var impossible:Dictionary=main_read.data.duplicate(true)
		impossible.pistes[0].points[0]=[99999999,99999999]
		write_verified(PATH,impossible)
		var protected_sha:String=FileAccess.get_sha256(PATH)
		var blocked:Dictionary=Saves.load_game(Resort.new(),PATH)
		check(not blocked.get("ok",false) and int(blocked.get("newer_primary_day",0))==9 and int(blocked.get("backup_day",0))==7,"Unrepairable day 9 is protected from silent day 7 fallback")
		check(FileAccess.get_sha256(PATH)==protected_sha,"Failed recovery does not overwrite the newer primary")
	clear_files()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
