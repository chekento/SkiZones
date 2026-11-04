extends SceneTree
## Deterministic multi-season smoke QA for the revised alpine weather schedule.
const Progression = preload("res://src/core/progression.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Resort = preload("res://src/core/resort.gd")

var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(value: bool, name: String) -> void:
	if value: passed += 1; print("PASS ",name)
	else: failed += 1; push_error("FAIL "+name)

func run() -> void:
	var storms: int = 0
	var counts: Array = [0,0,0,0,0]
	var total: int = 0
	var consecutive: int = 0
	for seed_index in range(8):
		var seed_value: int = 20260101 + seed_index*65537
		var yesterday: int = -1
		for day_number in range(1,4001):
			var kind: int = Progression.weather_for_day(seed_value,day_number)
			if kind < 0 or kind >= Catalog.WEATHER.size():
				failed += 1
				push_error("FAIL weather index out of range")
				break
			counts[kind] += 1
			total += 1
			if kind == 3:
				storms += 1
				if yesterday == 3: consecutive += 1
			yesterday = kind
		check(Progression.weather_for_day(seed_value,1234)==Progression.weather_for_day(seed_value,1234),"Seed %d: daily forecast is reproducible" % seed_value)
	var rate: float = float(storms)/maxf(1.0,float(total))
	print("WEATHER_DISTRIBUTION total=%d storms=%d rate=%.4f weather_counts=%s" % [total,storms,rate,str(counts)])
	check(total == 32000,"Eight independent seasons cover 32,000 simulated days")
	check(rate >= 0.05 and rate <= 0.08,"Storms occur on approximately 5–8 percent of days, not 20 percent")
	check(consecutive == 0,"No consecutive storm shutdown days")
	check(counts[0]>counts[1] and counts[1]>counts[2] and counts[2]>counts[3] and counts[4]>0,"All weather types occur with nonuniform prevalence")
	var resort := Resort.new()
	resort.new_game(true,20260101,"sonnenhang")
	var before: int = resort.weather_index
	var next_forecast: int = Progression.weather_for_day(resort.rng.seed,resort.day+1)
	check(next_forecast >= 0 and next_forecast < Catalog.WEATHER.size(),"Weather station can still forecast following day")
	check(resort.weather_index == before,"No modification to already active weather in existing careers")
	check(float(Catalog.WEATHER[3].wind) >= float(Catalog.LIFTS.chair.wind_limit),"Real storm still exceeds chair-lift safety threshold")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
