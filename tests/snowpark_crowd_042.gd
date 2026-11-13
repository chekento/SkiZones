extends SceneTree
## Same crowded, occupied park checkpoint at 1x/4x/8x update batching.
## CPU simulation evidence only; this does not measure Android rendering FPS.
const Resort=preload("res://src/core/resort.gd")
const Features=preload("res://src/core/piste_features.gd")
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func run()->void:
	var initial:=Resort.new();initial.new_game(true,20261113);initial.campaign.mode="free";initial.Ops.enable(initial)
	initial.operations.auto_groom=false;initial.party_mode=false;initial.edge_entries=false
	var piste:Dictionary=initial.pistes[0]
	var kinds:Array=["box","kicker_medium","table_jump","whoops"]
	var built:=0
	for index in range(kinds.size()):
		for fraction in [0.14+index*0.2,0.17+index*0.2,0.20+index*0.2]:
			if Features.install(initial,int(piste.id),str(kinds[index]),fraction,0).ok:built+=1;break
	check(built==4,"Crowded test contains four independently installed new modules")
	for index in range(180):initial.admit_guest(2,"expert")
	check(initial.guests.size()==180,"All 180 park guests are admitted by actual routing and ticket sales")
	var start:Dictionary=JSON.parse_string(JSON.stringify(initial.snapshot()))
	var reference:=""
	for speed in [1,4,8]:
		var model:=Resort.new()
		check(model.restore(start.duplicate(true)).ok,"Occupied park starts from the same valid save at %dx" % speed)
		var timer:=Time.get_ticks_msec()
		for frame in range(720/speed):
			for tick in range(speed):model.advance_minute(false)
		var elapsed:int=Time.get_ticks_msec()-timer
		var count:=0
		var valid_wear:=true
		for feature in model.pistes[0].features:
			count+=int(feature.get("uses",0))
			valid_wear=valid_wear and is_finite(float(feature.get("condition",100))) and float(feature.get("condition",100))>=0 and float(feature.get("condition",100))<=100
		check(count>0 and valid_wear,"Crowd physically uses and wears maintained park modules at %dx" % speed)
		check(model.minute==1200 and model.day==1,"Crowded park advances exactly 720 calendar minutes at %dx" % speed)
		var checkpoint:Dictionary=model.snapshot()
		check(Resort.new().restore(JSON.parse_string(JSON.stringify(checkpoint))).ok,"Crowded end checkpoint and module wear reload at %dx" % speed)
		var encoded:=JSON.stringify(checkpoint)
		if reference=="":reference=encoded
		else:check(encoded==reference,"Crowd, finance, incidents and module state are identical across %dx batching" % speed)
		print("PARK_CROWD_DIAG speed=%d guests=%d uses=%d elapsed_ms=%d" % [speed,model.guests.size(),count,elapsed])
	print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
