extends RefCounted
## Self-contained save operations for the 0.38 career UI.
## All filesystem access is derived from validated map IDs and slot numbers.
const L=preload("res://src/core/i18n.gd")
const Saves=preload("res://src/core/save_store.gd")
const Maps=preload("res://src/core/maps.gd")

static func sources(id: String, slot: int, free_slot: int = 1) -> Array:
	if id not in Maps.MAPS or slot<0 or slot>4 or (slot==0 and (free_slot<1 or free_slot>4)):return []
	var path: String=Saves.path_for_map(id,slot,free_slot)
	var result: Array=[path,path+".bak"]
	if id not in Maps.FANTASY_MAPS or (slot==1 or (slot==0 and free_slot==1)):
		result.append(Saves.legacy_path(id))
		result.append(Saves.legacy_path(id)+".bak")
	# Return ONLY active slot files. Archived backups are recovery candidates,
	# not owned slot files: never recursively archive/delete them and never
	# prevent a new resort from being copied into a formerly occupied slot.
	return result

static func recovery_sources(id: String,slot: int,free_slot: int = 1) -> Array:
	var active: Array=sources(id,slot,free_slot)
	if active.is_empty():return []
	var result: Array=active.duplicate()
	# Unfinished primary or backup renames are read-only recovery candidates.
	# Never add these to sources(): archive/delete/copy operations must not
	# sweep them up as if they were committed saves.
	for source in active:
		var staged: String=source+".tmp"
		if FileAccess.file_exists(staged) and staged not in result:result.append(staged)
	for archived in _archived_sources(id,slot,free_slot):
		if archived not in result:result.append(archived)
	return result

static func _archived_sources(id: String,slot: int,free_slot: int) -> Array:
	var result: Array=[]
	var target: String=Saves.path_for_map(id,slot,free_slot)
	var names: Array=[target.get_file(),target.get_file()+".bak"]
	var roots: Array=[]
	var index:int=free_slot if slot==0 else slot
	roots.append(["user://free-archives" if slot==0 else "user://career-archives","slot-%d-" % index])
	roots.append(["user://save-archives","%s-%d-%d-" % [id,slot,free_slot]])
	for spec in roots:
		var root: String=str(spec[0])
		var listing: DirAccess=DirAccess.open(root)
		if listing==null:continue
		for dirname in listing.get_directories():
			if not dirname.begins_with(str(spec[1])):continue
			for filename in names:
				var file: String=root+"/"+dirname+"/"+filename
				if FileAccess.file_exists(file):result.append(file)
				if result.size()>=96:return result
	var recovery: DirAccess=DirAccess.open("user://save-recovery")
	if recovery!=null:
		for filename in recovery.get_files():
			if filename.begins_with(str(names[0])+"-") or filename.begins_with(str(names[1])+"-"):
				result.append("user://save-recovery/"+filename)
			if result.size()>=96:return result
	# Load-game rescue snapshots were saved alongside the former source.
	var top: DirAccess=DirAccess.open("user://")
	if top!=null:
		for filename in top.get_files():
			if filename.begins_with(str(names[0])+".recovery-") and filename.ends_with(".json"):
				result.append("user://"+filename)
			if result.size()>=96:return result
	return result

static func correct_mode(read: Dictionary,id: String,slot: int) -> bool:
	if not read.ok or str(read.data.get("map_id","sonnenhang"))!=id:return false
	# Mission saves are map-scoped, not part of the four career/free slots.
	return id not in Maps.FANTASY_MAPS or Saves._free_data(read.data)==(slot==0)

static func inspect(id: String,slot: int,free_slot: int = 1) -> Dictionary:
	var list: Array=[]
	var exact:=0
	var recovery:=0
	var good:=0
	var owned: String=Saves.path_for_map(id,slot,free_slot)
	var model_script: Script=load("res://src/core/resort.gd")
	var active: Array=sources(id,slot,free_slot)
	# An intentionally archived/deleted slot is empty in the active manager.
	# If it still holds damaged files, include read-only historic backups
	# in diagnostics so the player can restore that occupied slot.
	var occupied: bool=false
	for candidate in active:
		if FileAccess.file_exists(candidate) or FileAccess.file_exists(candidate+".tmp"):
			occupied=true
			break
	var paths: Array=recovery_sources(id,slot,free_slot) if occupied else active
	for source in paths:
		if not FileAccess.file_exists(source):continue
		var read: Dictionary=Saves._read(source)
		var valid: bool=correct_mode(read,id,slot)
		if source!=owned and source!=owned+".bak" and not valid:continue
		var normal:=false
		var salvage:=false
		var detail: String=str(read.get("message",""))
		var code: String=str(read.get("code","unknown"))
		if read.ok and not valid:code="wrong_slot_or_map"
		if valid:
			good+=1
			var probe: Dictionary = Saves.probe_restore(read.data,model_script)
			normal=bool(probe.ok and probe.get("exact",false))
			salvage=bool(probe.ok and not probe.get("exact",false))
			if not probe.ok:
				code="semantic_incompatible"
				detail=str(probe.get("message",L.text("Datei ist lesbar, der Weltzustand ist jedoch nicht kompatibel.")))
		if normal:exact+=1
		elif salvage:recovery+=1
		list.append({"name":source.get_file(),"source":source,"checksum":valid,"loadable":normal,"recoverable":salvage,"code":code,"bytes":int(read.get("bytes",0)),"schema_version":int(read.get("schema_version",-1)),"parse_line":int(read.get("parse_line",0)),"message":detail})
	return {"ok":not list.is_empty(),"files":list,"verified":good,"loadable":exact,"recoverable":recovery,"damaged":not list.is_empty() and exact==0 and recovery==0}

## Prefer intact backups, then normalize a recoverable checksum-verified source.
## Every replacement must pass a complete normal restore before activation.
static func repair(id: String,slot: int,free_slot: int = 1) -> Dictionary:
	var paths: Array=recovery_sources(id,slot,free_slot)
	if paths.is_empty():return {"ok":false,"message":L.text("Ungültiger Spielstand.")}
	var target: String=Saves.path_for_map(id,slot,free_slot)
	var existing: Dictionary=Saves._read(target) if FileAccess.file_exists(target) else {"ok":false}
	var probe_script: Script=load("res://src/core/resort.gd")
	if correct_mode(existing,id,slot):
		var current: RefCounted=probe_script.new()
		if current.restore(existing.data.duplicate(true)).ok:
			return {"ok":true,"changed":false,"message":L.text("Hauptspielstand vollständig ladbar. Keine Reparatur nötig.")}
	for candidate in paths:
		if candidate==target or not FileAccess.file_exists(candidate):continue
		var read: Dictionary=Saves._read(candidate)
		if not correct_mode(read,id,slot):continue
		var check: RefCounted=probe_script.new()
		if not check.restore(read.data.duplicate(true)).ok:continue
		var staged: String=target+".rescue.tmp"
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(candidate),ProjectSettings.globalize_path(staged))!=OK:
			return {"ok":false,"message":L.text("Rettungskopie konnte nicht geschrieben werden.")}
		if FileAccess.get_sha256(staged)!=FileAccess.get_sha256(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(staged))
			return {"ok":false,"message":L.text("Rettungskopie ist beschädigt; Original bleibt bestehen.")}
		if FileAccess.file_exists(target):
			var folder: String="user://save-recovery"
			if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))!=OK:
				return {"ok":false,"message":L.text("Original konnte nicht gesichert werden.")}
			var safe: String=folder+"/"+target.get_file()+"-%d-%d.before-repair" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()]
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(target),ProjectSettings.globalize_path(safe))!=OK or FileAccess.get_sha256(target)!=FileAccess.get_sha256(safe):
				return {"ok":false,"message":L.text("Original konnte nicht gesichert werden.")}
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(staged),ProjectSettings.globalize_path(target))!=OK:
			return {"ok":false,"message":L.text("Rettung konnte nicht aktiviert werden. Sicherung bleibt erhalten.")}
		return {"ok":true,"changed":true,"message":L.text("Spielstand aus geprüfter Sicherung wiederhergestellt. Original wurde archiviert.")}
	# Without an intact backup, recover the checksum-verified world itself.
	# Stage a normalized save, re-read it and prove a normal load BEFORE
	# archiving/replacing anything. Unknown/corrupt bytes are never guessed.
	for candidate in paths:
		if not FileAccess.file_exists(candidate):continue
		var read:Dictionary=Saves._read(candidate)
		if not correct_mode(read,id,slot):continue
		var recovered:Dictionary=Saves.probe_restore(read.data,probe_script,true)
		if not recovered.ok:continue
		var staged:String=target+".repair-%d.tmp" % Time.get_ticks_usec()
		var written:Dictionary=Saves.save_game(recovered.model,staged)
		if not written.ok:return written
		var verified:Dictionary=Saves._read(staged)
		var native:RefCounted=probe_script.new()
		if not correct_mode(verified,id,slot) or not native.restore(verified.data).ok:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(staged))
			return {"ok":false,"message":L.text("Reparaturprüfung fehlgeschlagen. Originaldateien bleiben unverändert.")}
		var archive:String="user://save-recovery"
		if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(archive))!=OK:
			return {"ok":false,"message":L.text("Original konnte nicht gesichert werden.")}
		var original_path:String=target if FileAccess.file_exists(target) else candidate
		archive+="/"+original_path.get_file()+"-%d-%d.before-repair" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()]
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(original_path),ProjectSettings.globalize_path(archive))!=OK or FileAccess.get_sha256(original_path)!=FileAccess.get_sha256(archive):
			return {"ok":false,"message":L.text("Original konnte nicht gesichert werden.")}
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(staged),ProjectSettings.globalize_path(target))!=OK:
			return {"ok":false,"message":L.text("Rettung konnte nicht aktiviert werden. Sicherung bleibt erhalten.")}
		return {"ok":true,"changed":true,"archive":archive,"reset_visitors":recovered.reset_visitors,"message":L.text("Spielstand repariert und geprüft. Das unveränderte Original wurde gesichert.")}
	return {"ok":false,"message":L.text("Keine vollständig ladbare Sicherung gefunden. Dateien bleiben unverändert.")}

static func copy(id: String,from_slot: int,to_slot: int,from_free: int = 1,to_free: int = 1) -> Dictionary:
	var originals: Array=sources(id,from_slot,from_free)
	var targets: Array=sources(id,to_slot,to_free)
	if originals.is_empty() or targets.is_empty() or (from_slot==0)!=(to_slot==0) or (from_slot==to_slot and (from_slot!=0 or from_free==to_free)):
		return {"ok":false,"message":L.text("Nur auf einen anderen Platz desselben Spielmodus kopieren.")}
	var dest: String=Saves.path_for_map(id,to_slot,to_free)
	for entry in targets:
		if not FileAccess.file_exists(entry):continue
		if entry==dest or entry==dest+".bak" or correct_mode(Saves._read(entry),id,to_slot):
			return {"ok":false,"message":L.text("Das Resort ist auf dem Zielplatz bereits vorhanden.")}
	var model_script: Script=load("res://src/core/resort.gd")
	for entry in originals:
		if not FileAccess.file_exists(entry):continue
		var read: Dictionary=Saves._read(entry)
		if not correct_mode(read,id,from_slot):continue
		var probe: RefCounted=model_script.new()
		if not probe.restore(read.data.duplicate(true)).ok:continue
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(entry),ProjectSettings.globalize_path(dest))!=OK:
			return {"ok":false,"message":L.text("Kopieren fehlgeschlagen. Original unverändert.")}
		var copied: Dictionary=Saves._read(dest)
		if not copied.ok or FileAccess.get_sha256(dest)!=FileAccess.get_sha256(entry):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dest))
			return {"ok":false,"message":L.text("Kopie nicht lesbar. Ziel zurückgesetzt.")}
		return {"ok":true,"message":L.text("Resort kopiert. Beide Spielstände bleiben erhalten.")}
	return {"ok":false,"message":L.text("Keine vollständig ladbare Quelle. Original bleibt erhalten.")}

static func archive(id: String,slot: int,free_slot: int = 1) -> Dictionary:
	var paths: Array=sources(id,slot,free_slot)
	if paths.is_empty():return {"ok":false,"message":L.text("Ungültiger Spielstand.")}
	var base: String=Saves.path_for_map(id,slot,free_slot)
	var selected: Array=[]
	for entry in paths:
		if not FileAccess.file_exists(entry):continue
		if entry==base or entry==base+".bak" or correct_mode(Saves._read(entry),id,slot):selected.append(entry)
	if selected.is_empty():return {"ok":false,"message":L.text("Keine Dateien zum Archivieren vorhanden.")}
	var folder: String="user://save-archives/%s-%d-%d-%d-%d" % [id,slot,free_slot,Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))!=OK:
		return {"ok":false,"message":L.text("Archiv konnte nicht erstellt werden.")}
	for entry in selected:
		var to: String=folder+"/"+entry.get_file()
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(entry),ProjectSettings.globalize_path(to))!=OK or FileAccess.get_sha256(entry)!=FileAccess.get_sha256(to):
			return {"ok":false,"message":L.text("Archivprüfung fehlgeschlagen. Original bleibt bestehen.")}
	for entry in selected:
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(entry))!=OK:
			return {"ok":false,"message":L.text("Archiv angelegt, eine Quelldatei konnte nicht entfernt werden.")}
	return {"ok":true,"archive":folder,"message":L.text("Resort entfernt und Originaldateien vollständig archiviert.")}
