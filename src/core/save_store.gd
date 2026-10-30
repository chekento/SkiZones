extends RefCounted
const L = preload("res://src/core/i18n.gd")
## Checksum, size bound, atomic replacement and one previous valid save.

const DEFAULT_PATH := "user://skizones_save.json"
const MAX_BYTES := 64000000
const Maps = preload("res://src/core/maps.gd")
static var active_slot := 1

static func legacy_path(id: String) -> String:
	return DEFAULT_PATH if id == "sonnenhang" else "user://skizones_%s.json" % id

static func path_for_map(id: String, slot: int = -1) -> String:
	if id not in Maps.FANTASY_MAPS: return "user://scenario_%s.json" % id
	var selected := active_slot if slot < 0 else slot
	return "user://free_%s.json" % id if selected == 0 else "user://career_%d_%s.json" % [clampi(selected,1,4),id]

static func passport_path(slot: int = -1) -> String:
	var selected := active_slot if slot < 0 else slot
	return "user://free_passport.json" if selected == 0 else "user://career_%d_passport.json" % clampi(selected,1,4)

static func index_path(slot: int) -> String:
	return "user://free_index.json" if slot == 0 else "user://career_%d_index.json" % slot

static func _free_data(data: Dictionary) -> bool:
	return data.get("campaign") is Dictionary and data.campaign.get("mode")=="free"

static func slot_from_state(state: Dictionary) -> int:
	if state.has("slot"): return clampi(int(state.slot),0,4)
	var old:=_read(legacy_path(state.get("map","sonnenhang")))
	return 0 if old.ok and _free_data(old.data) else 1

static func _write_index(model: RefCounted, slot: int) -> void:
	var data := {"version":1,"map":model.map_id,"day":model.day,"money":model.money,"rank":model.campaign.rank,"saved_at":Time.get_unix_time_from_system()}
	var path := index_path(slot)
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(data));file.flush();file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))

static func summary(slot: int) -> Dictionary:
	if slot < 0 or slot > 4: return {"occupied":false}
	var file := FileAccess.open(index_path(slot),FileAccess.READ)
	if file != null and file.get_length() < 4096:
		var data: Variant=JSON.parse_string(file.get_as_text())
		if data is Dictionary and data.get("version")==1 and data.get("map") in Maps.FANTASY_MAPS:
			if data.get("day") is float or data.get("day") is int:
				if data.get("money") is float or data.get("money") is int:
					if FileAccess.file_exists(path_for_map(data.map,slot)) or FileAccess.file_exists(path_for_map(data.map,slot)+".bak"):
						data.occupied=true
						return data
	var latest := -1
	var result := {"occupied":false}
	for id in Maps.FANTASY_MAPS:
		for path in [path_for_map(id,slot),path_for_map(id,slot)+".bak"]:
			if not FileAccess.file_exists(path): continue
			var modified := FileAccess.get_modified_time(path)
			if modified <= latest: continue
			var read := _read(path)
			if read.ok:
				latest=modified
				result={"occupied":true,"map":id,"day":read.data.get("day",1),"money":read.data.get("money",0),"rank":read.data.get("campaign",{}).get("rank",1),"saved_at":modified}
	return result

static func migrate_legacy() -> bool:
	# Copy, never move, the previous files. A failed or repeated migration must
	# neither erase the old installation's files nor overwrite newer careers.
	var marker := "user://slots-migrated-017"
	if FileAccess.file_exists(marker): return true
	for id in Maps.MAPS:
		for suffix in ["", ".bak"]:
			var old: String = legacy_path(id)+suffix
			if not FileAccess.file_exists(old): continue
			var read := _read(old)
			if not read.ok: continue
			var slot := 0 if _free_data(read.data) else 1
			var target := path_for_map(id,slot)
			if FileAccess.file_exists(target):
				if suffix==".bak": target+=".bak"
				else: continue
			if not FileAccess.file_exists(target) and DirAccess.copy_absolute(ProjectSettings.globalize_path(old),ProjectSettings.globalize_path(target))!=OK: return false
	var old_passport := "user://skizones_passport.json"
	if FileAccess.file_exists(old_passport) and not FileAccess.file_exists(passport_path(1)):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(old_passport),ProjectSettings.globalize_path(passport_path(1)))!=OK: return false
	var file := FileAccess.open(marker,FileAccess.WRITE)
	if file == null: return false
	file.store_string("1");file.close()
	return true

static func archive_slot(slot: int) -> bool:
	if slot < 1 or slot > 4: return false
	var folder := "user://career-archives/slot-%d-%d" % [slot,Time.get_unix_time_from_system()]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))!=OK: return false
	var paths: Array=[passport_path(slot),passport_path(slot)+".bak",index_path(slot)]
	for id in Maps.FANTASY_MAPS: paths.append_array([path_for_map(id,slot),path_for_map(id,slot)+".bak"])
	for path in paths:
		if FileAccess.file_exists(path) and DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(folder+"/"+path.get_file()))!=OK: return false
	for path in paths:
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path))!=OK: return false
	return true

static func save_game(model: RefCounted, path: String = DEFAULT_PATH) -> Dictionary:
	var payload := JSON.stringify(model.snapshot())
	var envelope := JSON.stringify({"format": "SkiZones", "checksum": payload.sha256_text(), "payload": payload})
	if envelope.to_utf8_buffer().size() > MAX_BYTES:
		return {"ok": false, "message": L.text("Dieser Spielstand überschreitet die unterstützte Dateigröße. Das bisherige Resort bleibt gespeichert.")}
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": L.text("Spielstand konnte nicht geschrieben werden.")}
	file.store_string(envelope)
	file.flush()
	file.close()
	var absolute := ProjectSettings.globalize_path(path)
	# Preserve an existing backup when the main file is already damaged.
	if FileAccess.file_exists(path) and _read(path).ok:
		var backup_error := DirAccess.copy_absolute(absolute, absolute + ".bak")
		if backup_error != OK:
			return {"ok": false, "message": L.text("Die Sicherung des bisherigen Spielstands ist fehlgeschlagen.")}
	if DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
		return {"ok": false, "message": L.text("Spielstand konnte nicht atomar ersetzt werden.")}
	if model.map_id in Maps.FANTASY_MAPS and path==path_for_map(model.map_id): _write_index(model,active_slot)
	return {"ok": true, "message": L.text("Resort gespeichert.")}

static func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {"ok": false, "message": L.text("Kein gültiger Spielstand gefunden.")}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"ok": false, "message": L.text("Beschädigte Spielstand-Datei.")}
	var parsed: Variant = parser.data
	if not parsed is Dictionary or parsed.get("format") != "SkiZones" or not parsed.get("payload") is String or not parsed.get("checksum") is String:
		return {"ok": false, "message": L.text("Beschädigte Spielstand-Datei.")}
	if parsed.payload.sha256_text() != parsed.checksum:
		return {"ok": false, "message": L.text("Die Prüfsumme des Spielstands stimmt nicht.")}
	if parser.parse(parsed.payload) != OK:
		return {"ok": false, "message": L.text("Beschädigte Spielstand-Daten.")}
	var payload: Variant = parser.data
	if not payload is Dictionary:
		return {"ok": false, "message": L.text("Beschädigte Spielstand-Daten.")}
	return {"ok": true, "data": payload}

static func load_game(model: RefCounted, path: String = DEFAULT_PATH) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		var read := _read(candidate)
		if read.ok:
			var restored: Dictionary = model.restore(read.data)
			if restored.ok:
				return {"ok": true, "message": L.text("Vorherige Sicherung geladen.") if candidate.ends_with(".bak") else L.text("Resort geladen.")}
	return {"ok": false, "message": L.text("Kein lesbarer Spielstand vorhanden. Das aktuelle Resort bleibt erhalten.")}
