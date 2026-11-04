extends SceneTree
const Tiers=preload("res://src/core/start_tiers.gd")
const Resort=preload("res://src/core/resort.gd")
const Progression=preload("res://src/core/progression.gd")
var passed:=0
var failed:=0
func _init() -> void: call_deferred("run")
func check(ok: bool, name: String) -> void:
	if ok:passed+=1;print("PASS ",name)
	else:failed+=1;push_error("FAIL "+name)
func run() -> void:
	check(Tiers.LEVELS.size()==5 and Tiers.LEVELS[0].money<Tiers.LEVELS[1].money and Tiers.LEVELS[1].money<Tiers.LEVELS[2].money and Tiers.LEVELS[2].money<Tiers.LEVELS[3].money and Tiers.LEVELS[3].money<Tiers.LEVELS[4].money,"Five distinct ordered wealth levels")
	for i in range(5):
		var model:=Resort.new()
		model.new_game(true,20261027,"sonnenhang")
		Tiers.apply(model,i)
		check(model.money==float(Tiers.LEVELS[i].money) and int(model.campaign.starting_tier)==i,"New starter budget and profile "+str(i))
		var snapshot: Dictionary=model.snapshot()
		var restored:=Resort.new()
		check(restored.restore(snapshot).ok and restored.money==model.money and int(restored.campaign.starting_tier)==i,"Tier "+str(i)+" roundtrips in current save format")
	var old:=Resort.new()
	old.new_game(true)
	var old_data: Dictionary=old.snapshot()
	var another:=Resort.new()
	check(another.restore(old_data).ok and not another.campaign.has("starting_tier"),"Old career without tier field stays compatible")
	var free:=Resort.new()
	free.new_game(false)
	var before: float=free.money
	Tiers.apply(free,0)
	check(free.money==before and not free.campaign.has("starting_tier"),"Free build is never constrained by career difficulty")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
