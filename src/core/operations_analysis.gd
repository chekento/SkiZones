extends RefCounted
## Read-only operating diagnostics for both fictional and licensed real-world scenarios.
## No artificial guest generation: every queue count comes from the live resort.
const Fleet = preload("res://src/core/lift_fleet.gd")

const WARN_WAIT := 8.0
const CRITICAL_WAIT := 15.0
const TARGET_WAIT := 5.0

static func lift_metrics(model: RefCounted) -> Array:
	var entries: Array = []
	for lift in model.lifts:
		var capacity := maxi(1, model.lift_capacity(lift))
		var queued: int = model.queue_size(int(lift.id))
		var running: bool = model.lift_open(lift)
		var wait_minutes := float(queued) * 60.0 / float(capacity)
		var load: Dictionary = model.lift_load(lift)
		var severity := "closed" if not running else ("critical" if wait_minutes >= CRITICAL_WAIT else ("warning" if wait_minutes >= WARN_WAIT else "normal"))
		entries.append({
			"id": int(lift.id),
			"name": String(lift.name),
			"kind": String(lift.kind),
			"queue": queued,
			"capacity_per_hour": capacity,
			"nominal_wait_minutes": wait_minutes,
			"observed_load": float(load.fill),
			"running": running,
			"severity": severity,
			"target_queue": floori(float(capacity) * TARGET_WAIT / 60.0)
		})
	entries.sort_custom(func(a, b):
		if not is_equal_approx(float(a.nominal_wait_minutes), float(b.nominal_wait_minutes)):
			return a.nominal_wait_minutes > b.nominal_wait_minutes
		return int(a.id) < int(b.id)
	)
	return entries

static func overview(model: RefCounted) -> Dictionary:
	var lifts := lift_metrics(model)
	var total_queue := 0
	var weighted_wait := 0.0
	var max_wait := 0.0
	var bottlenecks := 0
	for entry in lifts:
		total_queue += entry.queue
		weighted_wait += entry.nominal_wait_minutes * entry.queue
		max_wait = maxf(max_wait, entry.nominal_wait_minutes)
		bottlenecks += int(entry.severity == "warning" or entry.severity == "critical")
	return {
		"lifts": lifts,
		"queued": total_queue,
		"max_wait_minutes": max_wait,
		"queue_weighted_wait_minutes": weighted_wait / maxf(1, total_queue),
		"bottlenecks": bottlenecks,
		"reachable_pistes": model.reachable_piste_ids().size(),
		"reputation": float(model.reputation),
		"budget": float(model.money),
		"day": int(model.day)
	}

static func objective_value(metrics: Dictionary, key: String) -> float:
	match key:
		"max_wait_minutes": return float(metrics.max_wait_minutes)
		"queue_weighted_wait_minutes": return float(metrics.queue_weighted_wait_minutes)
		"bottlenecks": return float(metrics.bottlenecks)
		"reachable_pistes": return float(metrics.reachable_pistes)
		"reputation": return float(metrics.reputation)
		"budget": return float(metrics.budget)
	return NAN

static func evaluate(metrics: Dictionary, objectives: Array) -> Dictionary:
	var results: Array = []
	var completed := 0
	for objective in objectives:
		if not objective is Dictionary or not objective.has("key") or not objective.has("target") or not objective.has("direction"):
			return {"ok": false, "message": "Invalid objective", "complete": false, "results": []}
		var key := String(objective.key)
		var direction := String(objective.direction)
		var actual := objective_value(metrics, key)
		if not is_finite(actual) or not (direction in ["at_most", "at_least"]) or not objective.target is float and not objective.target is int:
			return {"ok": false, "message": "Unsupported objective", "complete": false, "results": []}
		var success := actual <= float(objective.target) if direction == "at_most" else actual >= float(objective.target)
		completed += int(success)
		results.append({"key": key, "actual": actual, "target": float(objective.target), "direction": direction, "complete": success})
	return {"ok": true, "complete": completed == objectives.size() and not objectives.is_empty(), "passed": completed, "total": objectives.size(), "results": results}
