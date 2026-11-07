extends SceneTree
const Resort=preload("res://src/core/resort.gd")
const Saves=preload("res://src/core/save_store.gd")
const Manager=preload("res://src/core/save_management_038.gd")
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok:bool,title:String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func write(path:String,data:Dictionary,checksum:bool=true) -> void:
	var payload:=JSON.stringify(data,"",true,true)
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"format":"SkiZones","checksum":payload.sha256_text() if checksum else "invalid","payload":payload}))
	file.close()
func geometry(model: RefCounted) -> Array:
	var result := []
	for piste in model.pistes: result.append(["p",piste.id,piste.points,piste.name,piste.get("width",20)])
	for lift in model.lifts: result.append(["l",lift.id,lift.bottom,lift.top,lift.kind])
	for building in model.buildings: result.append(["b",building.id,building.point,building.kind])
	return result
func same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int): return absf(float(a)-float(b)) < 0.000001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not same(a[i],b[i]): return false
		return true
	return a==b
func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-repair-0382"):quit(1);return
	var model:=Resort.new()
	model.new_game(true,20261107)
	for i in range(12):model.admit_guest(2)
	var data:Dictionary=model.snapshot()
	check(not data.guests.is_empty(),"Real visitor state exists before corruption")
	var path:String=Saves.path_for_map("sonnenhang",3)
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	var broken:Dictionary=data.duplicate(true)
	broken.guests[0].route_index=999999
	write(path,broken)
	var original:String=FileAccess.get_sha256(path)
	var report:Dictionary=Manager.inspect("sonnenhang",3)
	check(report.recoverable==1 and report.loadable==0,"Inspection identifies the recoverable primary without a backup")
	var fixed:Dictionary=Manager.repair("sonnenhang",3)
	check(fixed.ok and fixed.get("changed",false) and fixed.get("reset_visitors",false),"Repair button now recovers that same primary")
	check(FileAccess.get_sha256(str(fixed.get("archive","")))==original,"Before-repair archive preserves every original byte")
	var restored:=Resort.new()
	var result:Dictionary=Saves.load_game(restored,path)
	check(result.ok and not result.get("recovered",false),"Repaired primary loads normally on the next launch")
	check(restored.guests.is_empty() and same(geometry(restored),geometry(model)),"Visitor repair retains all permanent construction exactly")
	check(restored.money==model.money and restored.day==model.day and same(restored.campaign,model.campaign),"Visitor repair retains budget, calendar and career progression")
	check(Manager.inspect("sonnenhang",3).loadable==1 and not Manager.repair("sonnenhang",3).changed,"Repeated inspection and repair are consistent and idempotent")
	# A historical construction is accepted only by the existing geometry
	# recovery validator. Its marker must survive normalization and reloading.
	var historical:Dictionary=data.duplicate(true)
	historical.pistes[0].difficulty=(int(historical.pistes[0].difficulty)+1)%3
	var strict:=Resort.new()
	var legacy:=Resort.new()
	check(not strict.restore(historical.duplicate(true)).ok and legacy.restore(historical.duplicate(true),true).ok,"Fixture reproduces changed slope-classification rules")
	write(path,historical)
	original=FileAccess.get_sha256(path)
	fixed=Manager.repair("sonnenhang",3)
	restored=Resort.new()
	result=Saves.load_game(restored,path)
	check(fixed.ok and result.ok and not result.get("recovered",false) and restored.compatibility_geometry,"Historical geometry remains normally loadable after repair")
	check(restored.guests.size()==data.guests.size() and same(restored.pistes[0].points,historical.pistes[0].points),"Historical repair preserves guests and authored waypoints")
	check(FileAccess.get_sha256(str(fixed.get("archive","")))==original,"Historical repair also archives the exact original")
	# Negative fixtures must have no salvageable earlier archive: an actual
	# prior valid snapshot SHOULD be recovered, not rejected with the bad primary.
	var positive_archives:DirAccess=DirAccess.open("user://save-recovery")
	if positive_archives!=null:
		for filename in positive_archives.get_files():
			if filename.begins_with(path.get_file()+"-"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save-recovery/"+filename))
	var invalid:Dictionary=data.duplicate(true)
	invalid.pistes[0].points[0]=[99999999,99999999]
	write(path,invalid)
	original=FileAccess.get_sha256(path)
	check(not Manager.repair("sonnenhang",3).ok and FileAccess.get_sha256(path)==original,"Invalid permanent coordinates are rejected without modifying the source")
	write(path,data,false)
	original=FileAccess.get_sha256(path)
	check(not Manager.repair("sonnenhang",3).ok and FileAccess.get_sha256(path)==original,"Failed checksums never enter geometry or visitor recovery")
	# Archives from older builds are read-only candidates. The corrupt primary
	# remains byte-for-byte available even if an archived copy is recovered.
	var recovery_folder: String="user://save-recovery"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(recovery_folder))
	var recovered_file: String=recovery_folder+"/"+path.get_file()+"-historical.before-repair"
	write(recovered_file,data)
	check(Manager.inspect("sonnenhang",3).loadable>=1,"Inspection discovers old archived copies even when the current primary has a bad checksum")
	var rescued_from_archive:Dictionary=Manager.repair("sonnenhang",3)
	check(rescued_from_archive.ok and rescued_from_archive.changed and FileAccess.get_sha256(path)==FileAccess.get_sha256(recovered_file),"Archived copy restores into occupied slot without changing original archive")
	var raw_file:FileAccess=FileAccess.open(path,FileAccess.WRITE)
	raw_file.store_string(JSON.stringify(data))
	raw_file.close()
	check(Saves._read(path).ok and Saves.load_game(Resort.new(),path).ok,"Versioned unwrapped historic snapshots pass full restore validation")

	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
