extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Analysis = preload("res://src/core/operations_analysis.gd")
const Catalog = preload("res://src/core/scenario_catalog.gd")
var passed := 0
var failed := 0

func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("PASS ", description)
	else:
		failed += 1
		push_error("FAIL " + description)

func _init() -> void:
	var specs: Array = Catalog.specs()
	check(specs.size() == 3, "Three distinct real-resort scenario concepts are catalogued")
	for entry in specs:
		check(not Catalog.playable(entry.id) and entry.data_status == "pending_licensed_import", "Unlicensed terrain data never becomes a playable real resort: " + entry.name)
		check(not entry.objectives.is_empty() and entry.premise_de.begins_with("Fiktives Planspiel"), "Scenario challenges are explicitly fictional and measurable: " + entry.name)
	check(Catalog.spec("unknown").is_empty() and not Catalog.playable("unknown"), "Unknown scenarios cannot be started")
	var model := Resort.new()
	model.new_game(true)
	var baseline: Dictionary = Analysis.overview(model)
	check(baseline.lifts.size() == 1 and baseline.queued == 0 and baseline.bottlenecks == 0, "Empty starter resort has no phantom queue pressure")
	var expected: Dictionary = Analysis.evaluate(baseline, [{"key": "max_wait_minutes", "direction": "at_most", "target": 0.0}])
	check(expected.ok and expected.complete and expected.passed == 1, "An already satisfied measured objective completes")
	check(not Analysis.evaluate(baseline, [{"key": "fictional_metric", "direction": "at_most", "target": 1.0}]).ok, "Unknown objective metrics are rejected")
	var route: Dictionary = model.routes_for(1)[0]
	for i in range(60):
		model.admit_guest(1)
	for guest in model.guests:
		guest.route = route
		for index in range(route.legs.size()):
			if route.legs[index].kind == "lift":
				guest.leg = index
				break
		model._start_leg(guest)
	var stressed: Dictionary = Analysis.overview(model)
	var nominal: float = 60.0 * 60.0 / float(model.lift_capacity(model.lifts[0]))
	check(stressed.queued == 60 and is_equal_approx(stressed.max_wait_minutes, nominal), "Actual guest queues and nominal transport throughput yield a reproducible waiting-time estimate")
	check(stressed.bottlenecks > 0 and stressed.lifts[0].severity == "warning", "Queue pressure is classified from measured guests and nominal hourly capacity")
	var objectives := [{"key": "max_wait_minutes", "direction": "at_most", "target": 6.0}, {"key": "reachable_pistes", "direction": "at_least", "target": 1.0}]
	var result: Dictionary = Analysis.evaluate(stressed, objectives)
	check(result.ok and not result.complete and result.passed == 1, "Scenario evaluation preserves partial success without claiming completion")
	check(Analysis.overview(model).queued == 60, "Diagnostics cannot modify the guest simulation")
	print("SCENARIO ANALYSIS: %d passed; %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
