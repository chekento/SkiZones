extends SceneTree
## 0.40: Visual contrast for snow paths is tested independently of
## gameplay pathfinding and without requiring an Android emulator.
const Walk=preload("res://src/world/walk_surfaces.gd")
var failures:=0

func check(ok: bool, description: String) -> void:
	if ok: print("PASS ",description)
	else: failures+=1; push_error("FAIL "+description)

func _init() -> void:
	var tint: Dictionary={"snow":"e8f1f7","wood":"97765b","stone":"a1a5a7"}
	var snow:=Color(tint.snow)
	var inner:Color=Walk.surface_tint("snow",0.0,-3.0,3.2,tint,"alpine","")
	var edge:Color=Walk.surface_tint("snow",0.0,3.2,3.2,tint,"alpine","")
	check(inner.distance_to(snow)>0.12,"Snow path interior contrasts with surrounding white snow")
	check(edge.distance_to(snow)<0.001,"Snow path blends into snow at its bank edge")
	var gravel:Color=Walk.surface_tint("gravel",0.0,-3.0,3.2,tint,"alpine","")
	check(gravel.distance_to(inner)>0.08,"Gravel and snow paths remain visually distinguishable")
	var mono:Color=Walk.surface_tint("snow",0.0,-3.0,3.2,tint,"monochrome","")
	check(mono.distance_to(snow)>0.08,"Monochrome snow path is still readable")
	var winter:Color=Walk.surface_tint("snow",0.0,-3.0,3.2,tint,"alpine","christmas")
	check(winter.distance_to(snow)>0.08,"Holiday decoration does not erase snow paths")
	check(Walk.surface_tint("snow",0.0,-3.0,3.2,tint,"alpine","",true).distance_to(inner)>0.01,"Dynamic foot wear retains its own overlay")
	print("SNOW PATH VISIBILITY: ",failures," failures")
	quit(1 if failures else 0)
