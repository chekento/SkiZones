extends SceneTree
## Rendering regression: a lift hidden by camera culling must advance its
## simulation clock without updating meshes, then rebuild its poses on reentry.
var passed := 0
var failed := 0

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS ",description)
	else:
		failed += 1
		push_error("FAIL ",description)

func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.set_process(false)
	game.view.set_process(false)
	game.paused = true
	game.model.new_game(false)
	game.model.money = 2000000
	var build: Dictionary = game.model.build_lift("chair",Vector2(200,235),Vector2(200,-230))
	check(bool(build.get("ok",false)),"Physical chairlift builds for offscreen camera regression")
	if not build.get("ok",false):
		quit(1)
		return
	game.view.rebuild()
	var lift: Dictionary = game.model.lifts[-1]
	var data: Dictionary = game.view._vehicle_sets.get(lift.id,{})
	check(not data.is_empty() and data.poses.size() > 0,"Actual Multimesh lift carriages are initialized")
	if data.is_empty():
		quit(1)
		return
	# Move the camera far outside the visible range. Hidden meshes must not
	# consume per-frame pose rebuilds, while the clock remains authoritative.
	game.view.focus = Vector2(-3000,-3000)
	game.view.zoom = 90
	lift.clock = 600.0
	game.view._process(0.016)
	check(not data.node.visible and bool(data.get("resync",false)),"Offscreen lift is hidden and marked for one-time pose reconstruction")
	check(is_equal_approx(float(data.clock),600.0),"Offscreen carriers keep up with the simulation clock")
	lift.clock = 1200.0
	game.view._process(0.016)
	check(is_equal_approx(float(data.clock),1200.0),"Long hidden intervals never accumulate old visual time")
	game.view.focus = Vector2(200,0)
	game.view._process(0.016)
	check(data.node.visible and not bool(data.get("resync",true)),"Returning camera redraws the carrier poses and clears the resync marker")
	check(is_equal_approx(float(data.clock),1200.0),"First visible frame uses the latest cable position without catch-up lag")
	var pose: Dictionary = data.poses[0]
	check(pose.has("transform") and pose.transform is Transform3D,"Visible lift has a valid newly calculated carriage transform")
	# Repeated visible frames resume the existing smoothing path, not a forced
	# full geometry rebuild at a constant clock.
	lift.clock = 1210.0
	game.view._process(0.016)
	# The scene is intentionally paused, and the lift has no hired operators.
	# A stopped cable must snap to its authoritative clock; smoothing during
	# real operation is separately asserted in lift_frame_pacing_041.gd.
	check(is_equal_approx(float(data.clock),1210.0),"Paused or unstaffed lift synchronizes immediately, without phantom animation")
	game.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)

func _init() -> void:
	call_deferred("run")
