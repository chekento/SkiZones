extends SceneTree
## Deterministic frame-pacing checks for actual carrier transforms, not FPS claims.
const FramePacing=preload("res://src/core/frame_pacing_040.gd")
const Fleet=preload("res://src/core/lift_fleet.gd")
const Resort=preload("res://src/core/resort.gd")
var passed:=0
var failed:=0

func check(value: bool, description: String) -> void:
	if value:
		passed+=1
		print("PASS ",description)
	else:
		failed+=1
		push_error("FAIL "+description)

func _init() -> void:call_deferred("run")

func run() -> void:
	check(FramePacing.presentation_fraction(3.25)==1.0,"Frames with CPU tick debt never wrap their visible lift phases backwards")
	check(FramePacing.speed_change_debt(7.5)==1.0,"Downshifting discards excess catch-up without reversing the rendered tick")
	check(FramePacing.presentation_fraction(-2.0)==0.0,"Negative timing debt cannot affect visual transforms")
	check(FramePacing.add_debt(0.0,1.0,1,1,1.0,0.5)==0.125,"Slow frame delta is capped to avoid time jumps")
	check(FramePacing.rate(1,24,1.0)==4.0 and FramePacing.rate(4,24,1.0)==16.0 and FramePacing.rate(8,24,1.0)==32.0,"Runtime clock preserves 1x/4x/8x ratios")
	var model:=Resort.new()
	model.new_game(false)
	model.money=3000000.0
	var result: Dictionary=model.build_lift("chair",Vector2(200,205),Vector2(245,-130))
	check(result.ok and model.lifts.size()==1,"Real chairlift is available for smooth-motion regression")
	if model.lifts.is_empty():
		print("RESULT: %d passed; %d failed" % [passed,failed])
		quit(1)
		return
	var lift: Dictionary=model.lifts[0]
	var profile: Dictionary=model.cable_profile(lift)
	var schedule: Dictionary=model.fleet_layout(lift)
	for speed in [1,4,8]:
		var debt:=0.0
		var steps:=0
		var last_clock: float=-INF
		var max_jump:=0.0
		var last_position:=Vector3.INF
		for frame in range(240):
			debt=FramePacing.add_debt(debt,1.0/60.0,speed,24,1.0,0.5)
			while debt>=1.0:
				steps+=1
				debt-=1.0
			var visual_clock:float=float(steps)+FramePacing.presentation_fraction(debt)
			if visual_clock+0.00001<last_clock:check(false,"Clock monotonic 1x/4x/8x (%dx, frame %d)" % [speed,frame])
			last_clock=visual_clock
			var position:Vector3=Fleet.pose(model.terrain,lift,profile,visual_clock,0,schedule).transform.origin
			if last_position.is_finite():max_jump=maxf(max_jump,position.distance_to(last_position))
			last_position=position
		var expected: float=4.0*FramePacing.rate(speed,24,1.0)*0.5
		check(absf(last_clock-expected)<0.001,"Correct elapsed lift clock after 4s at %dx" % speed)
		check(max_jump<3.0,"Real chairlift motion remains continuous at %dx" % speed)
	# Force an overloaded main-thread budget: the rendered clock must wait at
	# the next completed simulation tick rather than jump backwards via fmod.
	for speed in [1,4,8]:
		var debt:=0.0
		var ticks:=0
		var previous:=0.0
		var monotonic:=true
		for frame in range(180):
			debt=FramePacing.add_debt(debt,1.0/60.0,speed,24,1.0,0.5)
			if frame%10==0 and debt>=1.0:
				ticks+=1
				debt-=1.0
			var displayed:float=float(ticks)+FramePacing.presentation_fraction(debt)
			monotonic=monotonic and displayed+0.00001>=previous
			previous=displayed
		check(monotonic,"Lift presentation stays monotonic through forced 6ms-budget stalls at %dx" % speed)
	var old:=2.25
	var new_clock:=2.0+FramePacing.presentation_fraction(FramePacing.speed_change_debt(old))
	check(new_clock>=3.0-0.00001,"High-speed to 1x transition retains last visible carrier position")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
