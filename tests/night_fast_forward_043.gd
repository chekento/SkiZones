extends SceneTree
## v0.43 release gate: the night advances to 06:50 at all selectable
## UI speeds without altering the actual world clock, resort ledger,
## backup checksum, overnight visitor demand or next-morning state.
const Resort=preload("res://src/core/resort.gd")
const Ops=preload("res://src/core/operations.gd")
const Rhythm=preload("res://src/core/day_rhythm.gd")
const Saves=preload("res://src/core/save_store.gd")
var passed:int=0
var failed:int=0

func _init()->void:call_deferred("run")

func check(ok:bool,description:String)->void:
	if ok:passed+=1;print("PASS ",description)
	else:failed+=1;push_error("FAIL "+description)

func make_resort()->RefCounted:
	var model:RefCounted=Resort.new()
	model.new_game(true,20261122,"sonnenhang",true)
	Ops.enable(model)
	model.enable_runtime_rules()
	model.guests.clear()
	return model

func run()->void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-night-043"):
		push_error("Night tests may use only an isolated test save directory")
		quit(1);return
	check(Rhythm.MORNING_READY==410 and Rhythm.QUIET_FROM==1140,"Night window ends at 06:50 and is mandatory from 19:00")
	var reference_clock:int=-1
	var reference_steps:int=-1
	for speed in [1,4,8]:
		var model:RefCounted=make_resort()
		var old_day:int=model.day
		model.minute=Rhythm.QUIET_FROM
		check(model.empty_night(),"The empty-night predicate works on player speed %dx" % speed)
		var advanced:int=0
		for i in range(1000):
			if not model.advance_empty_minute():break
			advanced+=1
		var expected:int=1440-Rhythm.QUIET_FROM+Rhythm.MORNING_READY
		check(advanced==expected and model.day==old_day+1 and model.minute==410,"Speed %dx advances exactly %d calendar minutes to 06:50" % [speed,expected])
		check(not model.empty_night() and not model.advance_empty_minute() and model.minute==410,"Speed %dx cannot skip a single minute beyond 06:50" % speed)
		check(model.guests.is_empty() and model.total_guests==0,"Speed %dx introduces no phantom overnight guest" % speed)
		check(int(model.operations.get("pending_arrivals",0))>0,"Speed %dx accumulates bounded morning demand" % speed)
		var now:int=Ops.clock(model)
		if reference_clock<0:
			reference_clock=now
			reference_steps=advanced
		check(now==reference_clock and advanced==reference_steps,"The night clock is identical at 1x, 4x and 8x")
		var save_path:String="user://night-043-%d.json" % speed
		check(Saves.save_game(model,save_path).get("ok",false),"Speed %dx has a fully verified 06:50 save" % speed)
		var loaded:RefCounted=Resort.new()
		check(Saves.load_game(loaded,save_path).get("ok",false) and loaded.day==model.day and loaded.minute==410 and loaded.operations.get("pending_arrivals",0)==model.operations.get("pending_arrivals",0),"Speed %dx reloads 06:50, pending arrivals and all overnight operations" % speed)
		for suffix in ["",".bak",".tmp",".bak.tmp"]:
			var p:String=save_path+suffix
			if FileAccess.file_exists(p):DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	var blocked:RefCounted=make_resort()
	blocked.minute=Rhythm.QUIET_FROM
	blocked.operations.incidents.append({"id":91,"guest":-1,"status":"returning"})
	check(Rhythm.night_window(blocked) and not blocked.empty_night(),"A live rescue blocks unsafe calendar skipping but not night cleanup")
	blocked.operations.incidents.clear()
	check(blocked.empty_night(),"The safe fast-forward resumes immediately after rescuers return")
	var early:RefCounted=make_resort()
	early.minute=Rhythm.EMPTY_EVENING_FROM-1
	check(not early.empty_night(),"Pre-17:00 normal clock is preserved")
	early.minute=Rhythm.EMPTY_EVENING_FROM
	check(early.empty_night(),"A completely deserted resort can skip from 17:00")
	print("NIGHT 0.43: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
