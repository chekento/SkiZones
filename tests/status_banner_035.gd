extends SceneTree
## 0.35 unified notifications: priority, real scenario milestones, legacy saves.
const Banner = preload("res://src/ui/achievement_toast.gd")
const Resort = preload("res://src/core/resort.gd")
const Ops = preload("res://src/core/operations.gd")
var passed := 0
var failed := 0

func check(ok: bool, reason: String) -> void:
	if ok:
		passed += 1
		print("PASS ", reason)
	else:
		failed += 1
		push_error("FAIL " + reason)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var banner: Control=Banner.new()
	root.add_child(banner)
	await process_frame
	check(banner.mouse_filter == Control.MOUSE_FILTER_IGNORE and banner.card.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Notification and background do not intercept map taps")
	banner.announce({"kind":"achievement","title":"First real achievement","detail":"A real milestone","reward":100})
	check(banner.active.kind=="achievement" and banner.history.size()==1,"Existing achievement uses one shared banner")
	banner.announce({"kind":"music","title":"Alpine Song","detail":"Actual offline programme"})
	banner.announce({"kind":"mission","title":"Repair a broken lift","detail":"Braunlage mission 3"})
	banner.announce({"kind":"rank","title":"Mastery rank 8","detail":"XP earned"})
	banner.announce({"kind":"warning","title":"Negative cash","detail":"Adjust finances"})
	check(banner.waiting.size()==4,"Different event types are queued, not stacked on screen")
	check(banner.waiting[0].kind=="warning" and banner.waiting[1].kind=="mission" and banner.waiting.back().kind=="music","Warnings and missions precede music but do not interrupt an active award")
	banner.announce({"kind":"music","title":"Alpine Song","detail":"Actual offline programme"})
	check(banner.waiting.size()==4,"Duplicate current song is suppressed")
	banner._process(Banner.DISPLAY_SECONDS+0.1)
	check(banner.active.kind=="warning" and banner._current_duration > Banner.DISPLAY_SECONDS,"Urgent finance notice remains clearly readable")
	banner._process(banner._current_duration+0.1)
	check(banner.active.kind=="mission" and "MISSION" in banner.kicker.text,"Mission is presented with a distinct but familiar headline")
	banner._process(banner._current_duration+0.1)
	check(banner.active.kind=="rank","Mastery milestone retains priority over song")
	banner._process(banner._current_duration+0.1)
	check(banner.active.kind=="music" and banner._current_duration<Banner.DISPLAY_SECONDS,"Music appears in the same banner but disappears sooner")
	banner._process(banner._current_duration+0.1)
	check(banner.active.is_empty() and not banner.visible,"Notification queue clears and hides cleanly")
	banner.announce({"kind":"music","title":"Same Song","detail":"Another station"})
	banner.announce({"kind":"achievement","title":"True achievement","detail":"Completed"})
	check(banner.history.size()>=6,"Short in-session notification archive stores distinct events")
	banner.clear_all()
	check(banner.active.is_empty() and banner.waiting.is_empty() and not banner.visible,"A menu transition can clear stale notifications safely")
	check(Banner.duration("music")<Banner.duration("mission") and Banner.priority("mission")>Banner.priority("music"),"Priority and dwell time have predictable category rules")
	var model := Resort.new()
	model.new_game(true,20261105,"braunlage")
	var existing: int=model.recent_unlocks.size()
	Ops.evaluate(model)
	model.recent_unlocks.clear()
	model.operations.repairs_done=1
	model.operations.groomed=1
	Ops.evaluate(model)
	var first: Array=model.recent_unlocks.filter(func(e):return e.kind=="mission")
	check(first.size()>=2 and model.operations.goal_notices.has(2) and model.operations.goal_notices.has(3),"Completed repair and grooming goals announce individually")
	var count: int=model.recent_unlocks.size()
	Ops.evaluate(model)
	check(model.recent_unlocks.size()==count,"Repeated scenario evaluation never repeats mission notifications")
	model.operations.groomed=0
	Ops.evaluate(model)
	model.operations.groomed=1
	Ops.evaluate(model)
	check(model.recent_unlocks.size()==count,"Fluctuating mission conditions cannot flood the banner")
	var snapshot: Dictionary=JSON.parse_string(JSON.stringify(model.snapshot()))
	var restored := Resort.new()
	check(restored.restore(snapshot).ok and restored.operations.goal_notices.has(2),"Per-goal notification ledger survives save/load")
	var legacy: Dictionary=snapshot.duplicate(true)
	legacy.operations.erase("goal_notices")
	var old := Resort.new()
	check(old.restore(legacy).ok and old.operations.goal_notices.has(2),"A 0.34 scenario save migrates completed goals without replaying banners")
	var before: int=old.recent_unlocks.size()
	Ops.evaluate(old)
	check(old.recent_unlocks.size()==before,"Previously completed legacy missions are not re-announced")
	var invalid: Dictionary=snapshot.duplicate(true)
	invalid.operations.goal_notices=[2,2]
	check(not Resort.new().restore(invalid).ok,"Duplicated mission notification indices cannot corrupt a saved career")
	banner.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
