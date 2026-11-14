extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Progression = preload("res://src/core/progression.gd")
const Goals = preload("res://src/core/long_goals_042.gd")
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ", label)
	else: failed += 1; push_error("FAIL " + label)

func close_day(model: RefCounted, day: int, profitable: bool, visitors: int = 20) -> void:
	model.day = day; model.minute = model.CLOSING
	model.report = {"day":day,"tickets":1000.0,"services":0.0,"costs":900.0 if profitable else 1100.0,"guests":visitors,"rides":0,"departures":0,"satisfaction":0.0,"rewards":0.0,"investments":0.0}
	Progression.finish_day(model)

func run() -> void:
	var model := Resort.new(); model.new_game(true); model.campaign.mode = "career"
	close_day(model, 1, true)
	check(Goals.progress(model,"profit") == 1 and Goals.ready(model,"first_profit"), "First profitable day is recorded permanently")
	var settled: Dictionary = model.snapshot()
	Progression.finish_day(model)
	check(model.snapshot() == settled, "Repeated day finalization cannot inflate profit goals or rewards")
	for day in range(2,32): close_day(model,day,false)
	check(model.campaign.history.size() == 28 and model.campaign.history.all(func(row):return row.income <= row.costs), "The finance chart has discarded the original profitable report")
	check(Goals.ready(model,"first_profit") and Goals.progress(model,"profit") == 1, "Earned first-day goal survives thirty subsequent loss-making days")
	close_day(model,32,true)
	for day in range(33,63): close_day(model,day,false)
	check(Goals.progress(model,"profit") == 2 and not Goals.ready(model,"profit"), "Widely separated profitable days accumulate across report windows")
	close_day(model,63,true)
	for day in range(64,95): close_day(model,day,false)
	check(Goals.ready(model,"profit") and Goals.progress(model,"profit") == 3, "Third profitable day remains earned even after all qualifying reports expire")
	var restored := Resort.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok and Goals.ready(restored,"profit"), "Lifetime goal progress survives a checked JSON save and reload")
	var money: float = restored.money
	check(Goals.claim(restored,"profit").ok and restored.money == money+2500, "Late collection still pays exactly the original two-stage 2500-euro budget")
	var rewarded: Dictionary = restored.snapshot()
	check(not Goals.claim(restored,"profit").ok and not Goals.claim(restored,"first_profit").ok and restored.snapshot() == rewarded, "Permanent progress cannot bypass either claim guard")
	for bad in [-1,4,1.5,"3",true,null,INF,NAN]:
		var broken: Dictionary = rewarded.duplicate(true); broken.campaign.long_goal_profit_days = bad
		check(not restored.restore(broken).ok and restored.snapshot() == rewarded, "Malformed permanent counters reject atomically: " + str(bad))
	var old: Dictionary = model.snapshot(); old.campaign.erase("long_goal_profit_days")
	var legacy := Resort.new()
	check(legacy.restore(old).ok and not legacy.campaign.has("long_goal_profit_days"), "Old careers without the optional counter retain their existing campaign data on load")
	# Migration uses only surviving evidence, never invented historical profits.
	close_day(legacy,95,true)
	check(Goals.progress(legacy,"profit") == 1, "Legacy initialization does not invent profitable days missing from old reports")
	var known := Resort.new(); known.new_game(true); known.campaign.mode = "career"
	close_day(known,1,true); known.campaign.erase("long_goal_profit_days")
	close_day(known,2,true)
	check(known.campaign.long_goal_profit_days == 2, "Old careers seed accumulated progress from their surviving report history")
	var empty := Resort.new(); empty.new_game(true)
	close_day(empty,1,true,0)
	check(Goals.progress(empty,"profit") == 0, "Profit without actual guests does not advance the operating goal")
	var duplicate := Resort.new(); duplicate.new_game(true)
	close_day(duplicate,1,true); duplicate.campaign.finalized_day = 0
	close_day(duplicate,1,true)
	check(Goals.progress(duplicate,"profit") == 1, "An existing report date cannot add a second permanent profitable day")
	var capped := Resort.new(); capped.new_game(true)
	for day in range(1,12): close_day(capped,day,true)
	check(capped.campaign.long_goal_profit_days == 3, "Permanent storage is bounded to the largest economic target")
	print("RESULT: %d passed; %d failed" % [passed,failed]); quit(1 if failed else 0)
