extends SceneTree
## Regression: a complete drag/delete/smoothing transaction is one reversible
## route action, with no mutation of committed resort assets until confirmation.
const History = preload("res://src/core/plan_history_042.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)

func run() -> void:
	var history := History.new()
	var blank: Array = []
	var first: Array = [[310,-150]]
	var full: Array = [[310,-150],[310,-50],[310,100]]
	var dragged: Array = [[310,-150],[325,-35],[310,100]]
	check(not history.can_undo() and not history.can_redo(), "New planning session has no phantom actions")
	history.record(blank, first)
	history.record(first, full)
	history.record(full, dragged)
	check(history.can_undo() and not history.can_redo(), "Placement and drag become undoable steps")
	check(history.undo(dragged) == full, "Undo a moved waypoint restores the exact prior geometry")
	check(history.undo(full) == first, "Undo after drag removes the preceding placement step")
	check(history.redo(first) == full, "Redo restores the preceding placement")
	history.record(full, full)
	check(history.can_redo(), "No-op selection cannot clear redo history")
	history.record(full, dragged)
	check(not history.can_redo(), "A new confirmed drag invalidates stale redo steps")
	var returned := history.undo(dragged)
	returned[1][0] = 900
	check(history.redo(full) == dragged, "History snapshots are deep copies, not aliased nested coordinates")
	history.clear()
	check(not history.can_undo() and not history.can_redo(), "Clearing a plan isolates the next edit session")
	for i in range(History.LIMIT + 13):
		history.record([[i,0]], [[i+1,0]])
	check(history._undo.size() == History.LIMIT, "Very long sessions retain a bounded 64-step budget")

	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.paused = true
	game.set_tool("piste")
	game.points = full.duplicate(true)
	game.plan_history.clear()
	var cash: float = game.model.money
	var pistes: Array = game.model.pistes.duplicate(true)
	game._begin_waypoint_drag(1)
	game.points[1] = dragged[1].duplicate()
	game._drag_has_moved = true
	game._end_waypoint_drag()
	check(game.plan_history.can_undo(), "Real game records a completed touch drag as one action")
	game.undo_point()
	check(game.points == full, "Real route editor undo restores the dragged point and its neighbours")
	game.redo_point()
	check(game.points == dragged, "Real route editor redo restores the exact dragged coordinates")
	game.select_waypoint(1)
	game.delete_waypoint()
	check(game.points.size() == 2, "Selected waypoint deletion changes only the active plan")
	game.undo_point()
	check(game.points == dragged, "Deleted waypoint is restored at its original index")
	game.redo_point()
	check(game.points.size() == 2, "Deletion may be redone without deleting any committed pistes")
	game.undo_point()
	game._begin_waypoint_drag(1)
	game.points[1] = [330,-20]
	game._drag_has_moved = true
	game._end_waypoint_drag(true)
	check(game.points == dragged and game.plan_history.can_redo(), "Cancelled gesture restores geometry without losing redo")
	check(game.model.money == cash and game.model.pistes == pistes, "Undo/redo and canceled gestures never charge money or modify completed pistes")
	game.clear_plan()
	check(not game.plan_history.can_undo() and not game.plan_history.can_redo(), "Aborting construction clears its in-memory history")

	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _init() -> void:
	call_deferred("run")
