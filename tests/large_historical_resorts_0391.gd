extends SceneTree
## A checksum-valid legacy resort with more than sixty buildings must not be
## mistaken for an invalid save. Works on isolated CI user:// only.
const Resort=preload("res://src/core/resort.gd")
const Saves=preload("res://src/core/save_store.gd")
const Manager=preload("res://src/core/save_management_038.gd")
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)

func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-large-resorts-0391"):
		push_error("Refusing to touch player saves");quit(1);return
	var template:=Resort.new()
	template.new_game(true,20261107,"sonnenhang")
	check(template.buildings.size()>=2,"Original career supplies real initialized building payloads")
	if template.buildings.size()<2:quit(1);return
	for mode in ["career","free"]:
		var model:=Resort.new()
		model.new_game(mode=="career",20261107,"sonnenhang")
		var offered:Dictionary=template.buildings[-1].duplicate(true)
		for i in range(70):
			var asset:Dictionary=offered.duplicate(true)
			asset.id=model.next_id
			model.next_id+=1
			asset.name="Historical rental %d" % i
			asset.point=offered.point.duplicate(true)
			model.buildings.append(asset)
		model.day=8
		var slot:int=3 if mode=="career" else 0
		var free:int=1 if mode=="career" else 2
		var path:String=Saves.path_for_map("sonnenhang",slot,free)
		for filename in [path,path+".bak"]:
			if FileAccess.file_exists(filename):DirAccess.remove_absolute(ProjectSettings.globalize_path(filename))
		var saved:Dictionary=Saves.save_game(model,path)
		check(saved.ok,mode+" large original serializes safely")
		var checksum:String=FileAccess.get_sha256(path)
		var report:Dictionary=Manager.inspect("sonnenhang",slot,free)
		check(report.verified==1 and report.loadable+report.recoverable>=1,
			mode+" 70+ building save is not rejected by obsolete capacity limit")
		var restored:=Resort.new()
		var load:Dictionary=Saves.load_game(restored,path)
		check(load.ok,mode+" large resort is actually loadable")
		if load.ok:
			check(restored.buildings.size()==model.buildings.size() and restored.day==8,
				mode+" restores all original buildings and calendar without deletion")
			check(FileAccess.get_sha256(path)==checksum,
				mode+" original save stays byte-for-byte intact after loading")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
