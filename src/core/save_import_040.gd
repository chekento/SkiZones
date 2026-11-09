extends RefCounted
## 0.40 Android JSON/diagnostic-ZIP import: entirely opt-in.
## Android's SAF picker writes only to user://import-inbox/<token>.
## This class NEVER activates data until the user confirms a validated preview.
const Saves=preload("res://src/core/save_store.gd")
const Maps=preload("res://src/core/maps.gd")
const Resort=preload("res://src/core/resort.gd")
const INBOX: String="user://import-inbox"
const MAX_FILES: int=12

static func valid_token(token: String) -> bool:
	if token.length()!=32:return false
	for char in token:
		if char not in "0123456789abcdef":return false
	return true

static func begin_android() -> String:
	if not OS.has_feature("android"):return ""
	if not Engine.has_singleton("AndroidRuntime") or not Engine.has_singleton("JavaClassWrapper"):return ""
	var java: Object=Engine.get_singleton("JavaClassWrapper")
	var runtime: Object=Engine.get_singleton("AndroidRuntime")
	var bridge: Object=java.call("wrap","cloud.kosch.skizones.AppInfoBridge")
	if bridge==null:return ""
	var token:String=str(bridge.call("selectSaveImport",runtime.call("getActivity")))
	if java.call("get_exception")!=null or not valid_token(token):return ""
	return token

static func poll(token: String) -> Dictionary:
	if not valid_token(token):return {"status":"invalid_token"}
	var file:=FileAccess.open(INBOX+"/latest.json",FileAccess.READ)
	if file==null:return {"status":"pending"}
	if file.get_length()>32000:return {"status":"bad_metadata"}
	var data:Variant=JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary or str(data.get("token",""))!=token:return {"status":"pending"}
	if int(data.get("version",-1))!=1 or not data.get("files") is Array:return {"status":"bad_metadata"}
	return data

static func _safe_entry(token: String, entry: Dictionary) -> String:
	if not valid_token(token):return ""
	var filename: String=str(entry.get("name",""))
	if filename=="source.json":return INBOX+"/"+token+"/"+filename
	if filename.length()!=7 or not filename.ends_with(".json"):return ""
	var number: String=filename.substr(0,2)
	if not number.is_valid_int() or int(number)<0 or int(number)>=MAX_FILES:return ""
	return INBOX+"/"+token+"/"+filename

static func inspect(token: String, metadata: Dictionary, slot: int, free_slot: int=1) -> Dictionary:
	if not valid_token(token) or slot<0 or slot>4 or slot==0 and (free_slot<1 or free_slot>4):
		return {"ok":false,"code":"invalid_context"}
	if str(metadata.get("token",""))!=token or str(metadata.get("status",""))!="ready":
		return {"ok":false,"code":"not_ready"}
	var entries:Variant=metadata.get("files")
	if not entries is Array or entries.is_empty() or entries.size()>MAX_FILES:
		return {"ok":false,"code":"invalid_manifest"}
	var variants: Array=[]
	var verified: int=0
	var best: Dictionary={}
	for entry in entries:
		if not entry is Dictionary:continue
		var source: String=_safe_entry(token,entry)
		if source.is_empty() or not FileAccess.file_exists(source):continue
		if FileAccess.get_sha256(source)!=str(entry.get("sha256","")):continue
		var read:Dictionary=Saves._read(source)
		var report:Dictionary={"name":str(entry.get("source","Imported JSON")).substr(0,100),"code":str(read.get("code","unknown")),"bytes":int(read.get("bytes",0)),"schema":int(read.get("schema_version",-1)),"loadable":false,"recoverable":false}
		if read.ok:
			verified+=1
			var area:String=str(read.data.get("map_id","sonnenhang"))
			var correct:bool=Maps.is_player_map(area) and Saves._free_data(read.data)==(slot==0)
			if correct:
				var restored:Dictionary=Saves.probe_restore(read.data,Resort)
				if restored.ok:
					report.loadable=true
					report.recoverable=not bool(restored.get("exact",false))
					report["map"]=area
					report["day"]=int(restored.model.day)
					report["money"]=int(restored.model.money)
					var candidate:Dictionary=report.duplicate(true)
					candidate["source_path"]=source
					candidate["sha256"]=str(entry.sha256)
					candidate["slot"]=slot
					candidate["free_slot"]=free_slot
					candidate["token"]=token
					if best.is_empty() or (bool(restored.get("exact",false)) and bool(best.get("recoverable",false))):
						best=candidate
			else:
				report.code="wrong_map_or_mode"
		variants.append(report)
	return {"ok":not best.is_empty(),"code":"ok" if not best.is_empty() else "no_compatible_save","files":variants,"verified":verified,"selected":best}

static func _archive_destination(target: String,token: String) -> Dictionary:
	var candidates: Array=[]
	for suffix in ["",".bak",".tmp",".bak.tmp"]:
		var path:String=target+suffix
		if FileAccess.file_exists(path):candidates.append(path)
	if candidates.is_empty():return {"ok":true,"directory":""}
	var folder:String="user://save-recovery/import-%s-%d-%d" % [token,Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))!=OK:
		return {"ok":false,"code":"archive_directory"}
	for path in candidates:
		var backup:String=folder+"/"+str(path).get_file()
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(backup))!=OK or FileAccess.get_sha256(path)!=FileAccess.get_sha256(backup):
			return {"ok":false,"code":"archive_verification"}
	return {"ok":true,"directory":folder}

static func activate(preview: Dictionary) -> Dictionary:
	var token:String=str(preview.get("token",""))
	var slot:int=int(preview.get("slot",-1))
	var free_slot:int=int(preview.get("free_slot",1))
	var path:String=str(preview.get("source_path",""))
	if slot<0 or slot>4 or slot==0 and (free_slot<1 or free_slot>4):
		return {"ok":false,"code":"invalid_slot"}
	if not valid_token(token) or not path.begins_with(INBOX+"/"+token+"/") or path!=_safe_entry(token,{"name":path.get_file()}):
		return {"ok":false,"code":"invalid_source"}
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=str(preview.get("sha256","")):
		return {"ok":false,"code":"source_changed"}
	var read:Dictionary=Saves._read(path)
	if not read.ok:return {"ok":false,"code":"invalid_source"}
	var area:String=str(read.data.get("map_id","sonnenhang"))
	if not Maps.is_player_map(area) or Saves._free_data(read.data)!=(slot==0) or str(preview.get("map",""))!=area:
		return {"ok":false,"code":"wrong_map_or_mode"}
	var restored:Dictionary=Saves.probe_restore(read.data,Resort)
	if not restored.ok:return {"ok":false,"code":"incompatible"}
	var target:String=Saves.path_for_map(area,slot,free_slot)
	var archived:Dictionary=_archive_destination(target,token)
	if not archived.ok:return archived
	var committed:Dictionary=Saves.save_game(restored.model,target)
	if not committed.ok:return {"ok":false,"code":"commit_failed","archive":str(archived.directory)}
	# Re-open from disk using the same independent model validation as gameplay.
	var verify:Dictionary=Saves.load_game(Resort.new(),target)
	if not verify.ok:return {"ok":false,"code":"post_commit_validation","archive":str(archived.directory)}
	return {"ok":true,"map":area,"slot":slot,"free_slot":free_slot,"archive":str(archived.directory),"original_import":path}
