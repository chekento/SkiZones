extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Tour=preload("res://src/world/cinematic_tour.gd")
const Preferences=preload("res://src/core/preferences.gd")
var passed:=0
var failed:=0
func check(value: bool, label_text: String) -> void:
	if value: passed+=1; print("PASS ",label_text)
	else: failed+=1; push_error("FAIL "+label_text)
func _init() -> void: call_deferred("run")
func run() -> void:
	var model:=Resort.new()
	model.new_game(true)
	check(not model.lifts.is_empty(),"Real starter resort has a lift")
	model.lifts[0].fault="mechanical"
	var before: String=JSON.stringify(model.snapshot())
	var panorama: Array=Tour.build_hotspots(model,null,0)
	var operations: Array=Tour.build_hotspots(model,null,1)
	check(panorama[0].kind=="overview" and not panorama.any(func(shot): return shot.kind=="attention"),"Zero attention shows scenic shots only")
	check(operations[0].kind=="attention" and int(operations[0].asset_id)==int(model.lifts[0].id),"Maximum attention puts a real faulty lift before scenery")
	check(operations.size()<=18 and panorama.size()<=18,"Tour remains bounded on every cycle")
	var peaks: Array=panorama.filter(func(shot): return shot.kind=="peak")
	check(not peaks.is_empty() and peaks.all(func(shot): return is_equal_approx(shot.hold,1.8)),"Genuine summit close-ups hold for 1.8 seconds")
	check(panorama.any(func(shot): return shot.kind=="hill") and panorama.any(func(shot): return float(shot.pitch)<30),"Tour includes relief and varied viewing elevations")
	check(Tour.crowd_points(model,null).is_empty(),"No visitor clusters are invented without actual visible guests")
	check(JSON.stringify(model.snapshot())==before,"Director planning does not mutate the resort or saves")
	var pref:=Preferences.new()
	pref.path="user://cinema-director-032.cfg"
	pref.cinematic_attention=0.85
	pref.save_to()
	var restored:=Preferences.new()
	restored.path=pref.path
	restored.load_from()
	check(is_equal_approx(restored.cinematic_attention,0.85),"Attention setting persists across sessions")
	var config:=ConfigFile.new()
	config.set_value("display","cinematic_attention","bad")
	config.save(pref.path)
	restored.load_from()
	check(is_equal_approx(restored.cinematic_attention,0.55),"Malformed attention preference safely uses its default")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pref.path))
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
