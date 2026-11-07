extends SceneTree
## Non-destructive per-resort copy, integrity check, backup and archive regression.
const Resort=preload("res://src/core/resort.gd")
const Saves=preload("res://src/core/save_store.gd")
const Manager=preload("res://src/core/save_management_038.gd")
var passed:=0
var failed:=0
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-save-manager-038"):
		push_error("Refusing to touch real user save directories")
		quit(1);return
	var model:=Resort.new()
	model.new_game(true,20261106,"sonnenhang")
	var from: String=Saves.path_for_map("sonnenhang",3)
	var dest: String=Saves.path_for_map("sonnenhang",4)
	var another: String=Saves.path_for_map("sonnenhang",2)
	for path in [from,from+".bak",dest,dest+".bak",another,another+".bak"]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(Saves.save_game(model,from).ok,"Real resort saved into isolated career slot")
	var report: Dictionary=Manager.inspect("sonnenhang",3)
	check(report.ok and report.loadable==1 and not report.damaged,"Checksum and complete semantic restore passed")
	check(Manager.copy("sonnenhang",3,4).ok and FileAccess.get_sha256(from)==FileAccess.get_sha256(dest),"Copy preserves exact source bytes")
	var original_dest_hash: String=FileAccess.get_sha256(dest)
	check(not Manager.copy("sonnenhang",3,4).ok and original_dest_hash==FileAccess.get_sha256(dest),"Copy cannot silently replace existing destination")
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(dest),ProjectSettings.globalize_path(dest+".bak"))==OK,"Healthy destination backup created")
	var damaged_dest:=FileAccess.open(dest,FileAccess.WRITE)
	damaged_dest.store_string("broken destination bytes")
	damaged_dest.close()
	var recovered:Dictionary=Manager.repair("sonnenhang",4)
	check(recovered.ok and recovered.changed and FileAccess.get_sha256(dest)==original_dest_hash,"Repair reconstructs primary from full-valid backup without inventing guests")
	var history:DirAccess=DirAccess.open("user://save-recovery")
	var preserved:=false
	if history!=null:
		for filename in history.get_files():
			if filename.contains("career_4_sonnenhang") and filename.ends_with(".before-repair"):preserved=true
	check(preserved,"Original corrupt bytes preserved before repair")
	check(not Manager.copy("sonnenhang",3,0).ok,"Cross-mode copying cannot relabel career into sandbox")
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(from),ProjectSettings.globalize_path(from+".bak"))==OK,"Verified previous-generation backup created")
	var corrupted:=FileAccess.open(from,FileAccess.WRITE)
	corrupted.store_string("{not-a-save")
	corrupted.close()
	report=Manager.inspect("sonnenhang",3)
	check(report.ok and report.loadable==1 and report.files.size()==2,"Corrupt primary exposed without hiding valid backup")
	check(Manager.copy("sonnenhang",3,2).ok and FileAccess.get_sha256(another)==FileAccess.get_sha256(from+".bak"),"Copy rescues verified backup, preserving damaged original")
	var archive: Dictionary=Manager.archive("sonnenhang",3)
	check(archive.ok and not FileAccess.file_exists(from) and not FileAccess.file_exists(from+".bak"),"Archive removes source only after verified copies")
	check(FileAccess.file_exists(str(archive.get("archive",""))+"/"+from.get_file()) and FileAccess.file_exists(str(archive.get("archive",""))+"/"+from.get_file()+".bak"),"Both damaged original and valid backup survive in archive")
	check(FileAccess.file_exists(dest) and FileAccess.file_exists(another),"Other career slots survive archiving")
	check(not Manager.inspect("sonnenhang",3).ok,"Archived source disappears from active slot")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
