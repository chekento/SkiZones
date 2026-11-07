extends SceneTree
## Never silently attach another mountain or sandbox data to a career.
## Runs in an isolated user:// directory; historical save tests remain intact.
const Saves=preload("res://src/core/save_store.gd")
const Resort=preload("res://src/core/resort.gd")
const Manager=preload("res://src/core/save_management_038.gd")
var passed:=0
var failed:=0

func _init() -> void:call_deferred("run")
func check(ok:bool,title:String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)

func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-slot-safety-039"):
		push_error("Tests must never touch real player saves");quit(1);return
	check(Saves.expected_slot("user://career_3_sonnenhang.json")=={"map":"sonnenhang","free":false},"Career filename determines exact mode and map")
	check(Saves.expected_slot("user://free_2_sonnenhang.json")=={"map":"sonnenhang","free":true},"Second sandbox save identifies its own slot")
	check(Saves.expected_slot("user://free_sonnenhang.json")=={"map":"sonnenhang","free":true},"Original sandbox filenames remain supported")
	check(Saves.expected_slot("user://old_fixture.json").is_empty(),"Historical test imports remain unrestricted")
	var original:=Resort.new()
	original.new_game(true,20261107,"sonnenhang")
	original.money=707070
	var different:=Resort.new()
	different.new_game(true,20261107,"fichtenkamm")
	var target:String=Saves.path_for_map("sonnenhang",3)
	check(Saves.save_game(different,target).ok,"Fixture: valid checksum but wrong resort in career slot")
	var hash:String=FileAccess.get_sha256(target)
	var loaded:=Resort.new()
	loaded.new_game(true,20261107,"sonnenhang")
	var before:float=loaded.money
	check(not Saves.load_game(loaded,target).ok and loaded.map_id=="sonnenhang" and loaded.money==before,
		"Wrong-mountain primary cannot replace the selected career")
	check(FileAccess.get_sha256(target)==hash,"Failed load never modifies misfiled primary")
	var diagnosed:Dictionary=Manager.inspect("sonnenhang",3)
	check(diagnosed.damaged and diagnosed.loadable==0 and not Manager.repair("sonnenhang",3).ok,
		"Inspection and repair reject wrong-mountain primary, preserving its bytes")
	check(FileAccess.get_sha256(target)==hash,"Refused repair keeps invalid ownership untouched")
	check(Saves.save_game(original,target+".bak").ok,"Fixture: older valid career backup")
	loaded=Resort.new()
	var result:Dictionary=Saves.load_game(loaded,target)
	check(result.ok and result.source==target+".bak" and loaded.money==707070,
		"Valid same-mountain backup still restores the existing career")
	var free:=Resort.new()
	free.new_game(false,20261107,"sonnenhang")
	var unsafe:String=Saves.path_for_map("sonnenhang",4)
	check(Saves.save_game(free,unsafe).ok,"Fixture: full valid free build written under a career filename")
	loaded=Resort.new();loaded.new_game(true,20261107,"sonnenhang")
	before=loaded.money
	check(not Saves.load_game(loaded,unsafe).ok and loaded.money==before,
		"Career slot never silently opens free-mode save")
	var free_target:String=Saves.path_for_map("sonnenhang",0,2)
	check(Saves.save_game(original,free_target).ok,"Fixture: valid career inside free slot")
	check(not Saves.load_game(Resort.new(),free_target).ok,
		"Free-mode slot never silently opens career data")
	check(Saves.save_game(free,free_target+".bak").ok,"Fixture: correct free-mode fallback")
	loaded=Resort.new()
	result=Saves.load_game(loaded,free_target)
	check(result.ok and result.source==free_target+".bak" and Saves._free_data(loaded.snapshot()),
		"Second free slot restores the proper sandbox backup")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
