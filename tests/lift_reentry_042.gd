extends SceneTree
## Rendering regression: a lift hidden by camera culling must advance its
## simulation clock without updating meshes, then rebuild its poses on reentry.
const Terrain = preload("res://src/core/terrain.gd")
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
	# ResortView.rebuild can yield while mounting scenery/materials. Do not
	# assert camera culling against its in-progress state.
	for frame in range(180):
		if not game.view.loading_in_progress: break
		await process_frame
	check(not game.view.loading_in_progress,"Starter 3D world completes its asynchronous asset rebuild")
	game.set_process(false)
	game.view.set_process(false)
	game.paused = true
	# Use the real starter installation rather than destroying/recreating a
	# second OpenGL world in the same scene. This also exercises default assets.
	check(game.model.lifts.size() > 0,"Starter resort supplies a genuine built chairlift")
	if game.model.lifts.is_empty():
		quit(1)
		return
	var lift: Dictionary = game.model.lifts[0]
	# The resort may invalidate its geometry after the starter scene's first
	# draw. Let the view reconcile its revision before retaining the live
	# per-lift dictionary used by the rendering loop.
	game.view._process(0.0)
	var data: Dictionary = game.view._vehicle_sets.get(lift.id,{})
	check(game.view._seen_revision == game.model.revision,"View and resort use the same final revision before offscreen checks")
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
	var current: Dictionary = game.view._vehicle_sets.get(lift.id,{})
	check(not data.node.visible and bool(data.get("resync",false)),"Offscreen lift is hidden and marked for one-time pose reconstruction")
	check(is_equal_approx(float(data.clock),600.0),"Offscreen carriers keep up with the simulation clock")
	lift.clock = 1200.0
	game.view._process(0.016)
	check(is_equal_approx(float(data.clock),1200.0),"Long hidden intervals never accumulate old visual time")
	game.view.focus = (Terrain.unpack(lift.bottom) + Terrain.unpack(lift.top)) * 0.5
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
	# Explicitly release transient sky GPU resources before the OpenGL
	# compatibility driver's shutdown. The test created this scene solely
	# for QA and must not leave a viewport sky live at process termination.
	for child in game.view.get_children():
		if child is WorldEnvironment:
			child.environment = null
	game.view._environment.background_mode = Environment.BG_COLOR
	game.view._environment.sky = null
	await process_frame
	game.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)

func _init() -> void:
	call_deferred("run")
