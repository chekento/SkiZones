extends RefCounted
## Self-contained save operations for the 0.38 career UI.
## All filesystem access is derived from validated map IDs and slot numbers.
const L=preload("res://src/core/i18n.gd")
const Saves=preload("res://src/core/save_store.gd")
const Maps=preload("res://src/core/maps.gd")

static func sources(id: String, slot: int, free_slot: int = 1) -> Array:
	if id not in Maps.FANTASY_MAPS or slot<0 or slot>4 or (slot==0 and (free_slot<1 or free_slot>4)):return []
	var path: String=Saves.path_for_map(id,slot,free_slot)
	var result: Array=[path,path+".bak"]
	if slot==1 or (slot==0 and free_slot==1):
		result.append(Saves.legacy_path(id))
		result.append(Saves.legacy_path(id)+".bak")
	return result

static func correct_mode(read: Dictionary,id: String,slot: int) -> bool:
	return read.ok and str(read.data.get("map_id","sonnenhang"))==id and Saves._free_data(read.data)==(slot==0)

static func inspect(id: String,slot: int,free_slot: int = 1) -> Dictionary:
	var list: Array=[]
	var exact:=0
	var recovery:=0
	var good:=0
	var owned: String=Saves.path_for_map(id,slot,free_slot)
	var model_script: Script=load("res://src/core/resort.gd")
	for source in sources(id,slot,free_slot):
		if not FileAccess.file_exists(source):continue
		var read: Dictionary=Saves._read(source)
		var valid: bool=correct_mode(read,id,slot)
		if source!=owned and source!=owned+".bak" and not valid:continue
		var normal:=false
		var salvage:=false
		if valid:
			good+=1
			var probe: RefCounted=model_script.new()
			normal=bool(probe.restore(read.data.duplicate(true)).ok)
			if not normal:
				for attempt in range(2):
					var data: Dictionary=read.data.duplicate(true)
					if attempt==1:
						data.guests=[]
						data.itineraries=[]
						data.parties=[]
					var fallback: RefCounted=model_script.new()
					if fallback.restore(data,true).ok:
						salvage=true
						break
		if normal:exact+=1
		elif salvage:recovery+=1
		list.append({"name":source.get_file(),"source":source,"checksum":valid,"loadable":normal,"recoverable":salvage})
	return {"ok":not list.is_empty(),"files":list,"verified":good,"loadable":exact,"recoverable":recovery,"damaged":not list.is_empty() and exact==0 and recovery==0}

## Recover from an intact backup without losing the malformed original.
## The source must pass the full Resort.restore validator, not just a checksum.
static func repair(id: String,slot: int,free_slot: int = 1) -> Dictionary:
	var paths: Array=sources(id,slot,free_slot)
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
