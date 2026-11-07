extends SceneTree
## Reproduce user's checksum-valid yet unloadable "Anlagen" case without
## reading or requesting any private player save file.
const Resort=preload("res://src/core/resort.gd")
const Saves=preload("res://src/core/save_store.gd")
const Manager=preload("res://src/core/save_management_038.gd")
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok:bool,title:String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func write_save(path:String,world:Dictionary) -> void:
	var payload:String=JSON.stringify(world,"",true,true)
	var f:FileAccess=FileAccess.open(path,FileAccess.WRITE)
	f.store_string(JSON.stringify({"format":"SkiZones","checksum":payload.sha256_text(),"payload":payload}))
	f.close()
func same_assets(a:RefCounted,b:RefCounted) -> bool:
	if a.pistes.size()!=b.pistes.size() or a.lifts.size()!=b.lifts.size() or a.buildings.size()!=b.buildings.size():return false
	for i in range(a.pistes.size()):
		if a.pistes[i].id!=b.pistes[i].id or a.pistes[i].points!=b.pistes[i].points:return false
	for i in range(a.lifts.size()):
		if a.lifts[i].id!=b.lifts[i].id or a.lifts[i].bottom!=b.lifts[i].bottom or a.lifts[i].top!=b.lifts[i].top:return false
	for i in range(a.buildings.size()):
		if a.buildings[i].id!=b.buildings[i].id or a.buildings[i].kind!=b.buildings[i].kind or a.buildings[i].point!=b.buildings[i].point:return false
	return true
func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-asset-runtime-0391"):quit(1);return
	var path:String=Saves.path_for_map("sonnenhang",2)
	for suffix in ["",".bak"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	var model:=Resort.new()
	model.new_game(true,20261107,"sonnenhang")
	check(model.pistes.size()>0,"Original resort contains at least one piste")
	if model.pistes.is_empty():quit(1);return
	var broken:Dictionary=model.snapshot().duplicate(true)
	broken.pistes[0].grooming_until=5400
	write_save(path,broken)
	var original:String=FileAccess.get_sha256(path)
	var decoded:Dictionary=Saves._read(path)
	var strict:=Resort.new()
	check(decoded.ok and not strict.restore(decoded.data.duplicate(true)).ok,"Valid checksum with obsolete grooming deadline fails strict Anlagen restore")
	var report:Dictionary=Manager.inspect("sonnenhang",2)
	check(report.verified==1 and report.loadable==0 and report.recoverable==1,"Inspection now recognizes safe rescue of a checksum-valid Anlagen failure")
	var fixed:Dictionary=Manager.repair("sonnenhang",2)
	check(fixed.ok and fixed.changed,"In-game Repair button can normalize transient asset data")
	check(FileAccess.file_exists(str(fixed.get("archive",""))) and FileAccess.get_sha256(str(fixed.archive))==original,"Repair archives original bytes with verified SHA256")
	var restored:=Resort.new()
	check(Saves.load_game(restored,path).ok,"Repaired Anlagen resume on next launch")
	check(same_assets(restored,model),"All piste positions, lift endpoints, building IDs and kinds are preserved")
	check(restored.money==model.money and restored.day==model.day and restored.campaign==model.campaign,"Budget, day and career progression unchanged")
	check(Manager.inspect("sonnenhang",2).loadable==1,"Recovered primary passes the strict loader without a second rescue")
	# Both primary and .bak are checksum-valid but carry the same stale snow
	# track layout. This reproduces the reported "2 verified / 0 loadable".
	var old_snow:Dictionary=model.snapshot().duplicate(true)
	old_snow.pistes[0].tracks=[{"key":"legacy-ghost","sport":"ski","ability":0,"run":0,"guest":0,"from":0.0,"until":1.0,"to":1.4}]
	write_save(path,old_snow)
	var snow_hash:String=FileAccess.get_sha256(path)
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(path+".bak"))==OK,"Two checksum-valid copies of the same stale snow traces exist")
	report=Manager.inspect("sonnenhang",2)
	check(report.verified==2 and report.loadable==0 and report.recoverable==2,"Both unusable Anlagen saves become safely recoverable")
	fixed=Manager.repair("sonnenhang",2)
	restored=Resort.new()
	check(fixed.ok and Saves.load_game(restored,path).ok,"In-game repair activates a strict-loadable resort from two failing files")
	check(same_assets(restored,model) and restored.money==model.money,"Recovery discards only transient snow, preserving buildings and all pistes")
	check(FileAccess.get_sha256(path+".bak")==snow_hash,"Original .bak remains byte-for-byte intact")
	# A once-valid rail can predate new edge/spacing limits. Keep its authored
	# kind and fraction, marking the layout as historical rather than removing it.
	var old_feature:Dictionary=model.snapshot().duplicate(true)
	old_feature.pistes[0].features=[{"kind":"rail","fraction":0.01,"lateral":0.0}]
	write_save(path,old_feature)
	if FileAccess.file_exists(path+".bak"):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".bak"))
	report=Manager.inspect("sonnenhang",2)
	check(report.verified==1 and report.loadable==0 and report.recoverable==1,"Old Snowpark rail placement is recognized as historical geometry")
	fixed=Manager.repair("sonnenhang",2)
	restored=Resort.new()
	check(fixed.ok and Saves.load_game(restored,path).ok and restored.pistes[0].features==old_feature.pistes[0].features,"Legacy Snowpark rail is preserved in a normally reloadable resort")
	# Intentionally invalid permanent geometry must not be silently deleted.
	var invalid:Dictionary=model.snapshot().duplicate(true)
	invalid.pistes[0].points[0]=[99999999,99999999]
	write_save(path,invalid)
	original=FileAccess.get_sha256(path)
	report=Manager.inspect("sonnenhang",2)
	check(report.recoverable==0 and report.loadable==0,"Permanent invalid geometry cannot be guessed by rescue")
	var explanation:String=""
	for source in report.files:
		explanation+=str(source.message)
	check(explanation.contains("pistes") and explanation.contains("#"),"Anlagen diagnostic now names the offending saved piste ID")
	check(not Manager.repair("sonnenhang",2).ok and FileAccess.get_sha256(path)==original,"Unrecoverable original remains byte-identical")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
