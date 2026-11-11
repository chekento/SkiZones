extends SceneTree
## The same lift schedule drives the simulated vehicle and every draw frame.
## Test a day-two 8x -> 1x downshift and recovery from long Android frames.
const Fleet=preload("res://src/core/lift_fleet.gd")
const DayRhythm=preload("res://src/core/day_rhythm.gd")
const Resort=preload("res://src/core/resort.gd")
const Ops=preload("res://src/core/operations.gd")
var passed:=0
var failed:=0

func _init()->void:call_deferred("run")
func check(ok: bool,name: String)->void:
	if ok:passed+=1;print("PASS ",name)
	else:failed+=1;push_error("FAIL "+name)

func _linear_cable(profile: Dictionary,fraction: float)->Vector3:
	var distance:float=float(profile.length)*clampf(fraction,0,1)
	for index in range(1,profile.points.size()):
		if distance<=profile.lengths[index]:
			return profile.points[index-1].lerp(profile.points[index],(distance-profile.lengths[index-1])/maxf(profile.lengths[index]-profile.lengths[index-1],0.001))
	return profile.points[-1]

func run()->void:
	var points:Array=[Vector3(0,9,0),Vector3(80,21,15),Vector3(180,40,32),Vector3(280,37,53),Vector3(390,52,91),Vector3(520,83,133)]
	var lengths:Array=[0.0]
	for i in range(1,points.size()):lengths.append(float(lengths[-1])+points[i].distance_to(points[i-1]))
	var profile:Dictionary={"points":points,"lengths":lengths,"length":lengths[-1]}
	var exact:=true
	for i in range(1001):
		var fraction:float=float(i)/1000.0
		exact=exact and Fleet._on_cable(profile,fraction).distance_to(_linear_cable(profile,fraction))<0.00001
	check(exact,"Binary cable search matches the old physical cable interpolation at every point")
	var target:float=2560.0 # Second day, same independent motion clock
	var previous:float=target
	var monotonic:=true
	var bounded:=true
	var attached:=true
	for frame in range(240):
		var speed:float=8.0 if frame<60 else 1.0
		var rate:float=speed*4.0*DayRhythm.playback(720,"balanced")*Resort.MINUTES_PER_SECOND
		var delta:float=0.50 if frame==80 else 1.0/60.0
		target+=rate*delta
		var next:float=Fleet.visual_clock(previous,target,delta,rate)
		monotonic=monotonic and next>=previous and next<=target+0.000001
		bounded=bounded and next-previous <= maxf(0.02,minf(delta,0.1)*rate*1.8)+0.000001
		attached=attached and is_finite(next)
		previous=next
	check(monotonic and attached,"Day-two 8x -> 1x lift phase remains monotonic with no overshoot")
	check(bounded,"Dropped Android frames cannot generate a multi-step vehicle teleport")
	check(absf(Fleet.visual_clock(1.0,8.0,0.1,4.0,false)-8.0)<0.000001,"Stopped cable synchronizes exactly without animation drift")
	check(absf(Fleet.visual_clock(20.0,19.75,0.016,4.0)-19.75)<0.000001,"Loading an older save resets animation without invalid forward extrapolation")
	check(Fleet.visual_clock(-1.0,2450.0,0.016,4.0)==2450.0,"Android resume sentinel immediately restores the actual vehicle positions")
	var model:=Resort.new()
	model.new_game(true,20261110,"sonnenhang")
	Ops.enable(model)
	model.enable_runtime_rules()
	model.minute=DayRhythm.QUIET_FROM-1
	check(not model.empty_night(),"19:59 never triggers the safe overnight skip")
	model.minute=DayRhythm.QUIET_FROM
	check(model.empty_night(),"20:00 starts the safe overnight skip on an empty resort")
	var snapshot:Dictionary=model.snapshot()
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(snapshot))).ok,"20:00 checkpoint preserves a valid legacy-compatible save format")
	print("RESULT: %d passed; %d failed"%[passed,failed])
	quit(1 if failed else 0)
