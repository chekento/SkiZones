extends RefCounted
const L = preload("res://src/core/i18n.gd")
## Checksum, size bound, atomic replacement and one previous valid save.

const DEFAULT_PATH := "user://skizones_save.json"
const MAX_BYTES := 64000000
const Maps = preload("res://src/core/maps.gd")
static var active_slot := 1
## Slot 1 retains all original free_*.json files without migration.
static var active_free_slot := 1

static func legacy_path(id: String) -> String:
	return DEFAULT_PATH if id == "sonnenhang" else "user://skizones_%s.json" % id

static func path_for_map(id: String, slot: int = -1, free_slot: int = -1) -> String:
	if not Maps.is_player_map(id): return "user://scenario_%s.json" % id
	var selected: int = active_slot if slot < 0 else slot
	if selected == 0:
		var index: int = clampi(active_free_slot if free_slot < 0 else free_slot, 1, 4)
		return "user://free_%s.json" % id if index == 1 else "user://free_%d_%s.json" % [index,id]
	return "user://career_%d_%s.json" % [clampi(selected,1,4),id]

## A passport may be missing independently of its career save. A readable
## archive still owns its resort and must not be hidden behind unlock gates.
## Actual model validation always happens in load_game before the scene is used.
static func has_readable_save(id: String, slot: int = -1, free_slot: int = -1) -> bool:
	if id in Maps.MAPS and not Maps.is_player_map(id):
		# Scenario files were once stored under the common pre-slot prefix.
		for source in [path_for_map(id),path_for_map(id)+".bak",legacy_path(id),legacy_path(id)+".bak"]:
			var read:Dictionary=_read(source)
			if read.ok and str(read.data.get("map_id","sonnenhang"))==id:return true
		return false
	var selected: int = active_slot if slot < 0 else slot
	for source in [path_for_map(id, selected, free_slot),path_for_map(id, selected, free_slot)+".bak"]:
		var read: Dictionary = _read(source)
		if read.ok and str(read.data.get("map_id","sonnenhang")) == id and (not Maps.is_player_map(id) or _free_data(read.data) == (selected == 0)):
			return true
	if selected not in [0,1] or (selected == 0 and (active_free_slot if free_slot < 0 else free_slot) != 1) or not Maps.is_player_map(id): return false
	for source in [legacy_path(id),legacy_path(id)+".bak"]:
		var read: Dictionary = _read(source)
		if read.ok and str(read.data.get("map_id","sonnenhang")) == id and _free_data(read.data) == (selected==0):
			return true
	return false

# Existence is not the same as readability. A corrupt or newer-format save
# must NEVER silently become an empty new resort.
static func has_any_save(id: String, slot: int = -1, free_slot: int = -1) -> bool:
	if id in Maps.MAPS and not Maps.is_player_map(id):
		for source in [path_for_map(id),path_for_map(id)+".bak",legacy_path(id),legacy_path(id)+".bak"]:
			if FileAccess.file_exists(source) or FileAccess.file_exists(source + ".tmp"): return true
		return false
	var selected: int = active_slot if slot < 0 else slot
	var path: String = path_for_map(id, selected, free_slot)
	# After an Android process kill, the only remaining complete snapshot may
	# be an uncommitted .tmp/.bak.tmp. Never offer an empty new career over it.
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak") or FileAccess.file_exists(path + ".tmp") or FileAccess.file_exists(path + ".bak.tmp"): return true
	if selected not in [0, 1] or (selected == 0 and (active_free_slot if free_slot < 0 else free_slot) != 1) or not Maps.is_player_map(id): return false
	for old_path in [legacy_path(id), legacy_path(id) + ".bak"]:
		if not FileAccess.file_exists(old_path): continue
		var read: Dictionary = _read(old_path)
		# Unknown content is protected until explicitly inspected, not overwritten.
		if not read.ok: return true
		if str(read.data.get("map_id", "sonnenhang")) == id and (_free_data(read.data) == (selected == 0)):
			return true
	return false

# All distinct resorts in one career, including verified backups and pre-slot
# saves. The old single-map index is advisory only, never authoritative.
static func saved_resorts(slot: int = -1, free_slot: int = -1) -> Array:
	var selected: int = active_slot if slot < 0 else slot
	var result: Array = []
	for id in Maps.player_maps():
		var path: String = path_for_map(id, selected, free_slot)
		var sources: Array = [path, path + ".bak"]
		if selected == 1 or (selected == 0 and (active_free_slot if free_slot < 0 else free_slot) == 1):
			sources.append(legacy_path(id))
			sources.append(legacy_path(id) + ".bak")
		var entry: Dictionary = {}
		for source in sources:
			if not FileAccess.file_exists(source): continue
			var read: Dictionary = _read(source)
			if not read.ok or str(read.data.get("map_id", "sonnenhang")) != id: continue
			if _free_data(read.data) != (selected == 0): continue
			# Pre-career originals use the same free mode as the model loader.
			var progress: Dictionary = read.data.campaign if read.data.get("campaign") is Dictionary else {}
			var modified: int = FileAccess.get_modified_time(source)
			entry = {"occupied": true, "map": id, "day": read.data.get("day", 1), "money": read.data.get("money", 0), "rank": progress.get("rank", 1), "saved_at": modified, "source": source, "damaged": false}
			# The loader uses primary, backup, then pre-slot originals in this order.
			break
		if not entry.is_empty():
			result.append(entry)
		elif has_any_save(id, selected, free_slot):
			result.append({"occupied": true, "map": id, "day": 0, "money": 0, "rank": 0, "saved_at": FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0, "damaged": true})
	# A damaged file is visible but never outranks a healthy career.
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.damaged != b.damaged: return not a.damaged
		return int(a.saved_at) > int(b.saved_at)
	)
	return result

# Only a checksum-verified existing source can resume the exact old UI state.
# A valid primary must take precedence over any stale backup checkpoint.
static func session_source_matches(id: String, slot: int, checksum: String, free_slot: int = -1) -> bool:
	var path: String = path_for_map(id, slot, free_slot)
	var sources: Array = [path, path + ".bak"]
	if (slot == 1 or slot == 0 and (active_free_slot if free_slot < 0 else free_slot) == 1) and Maps.is_player_map(id):
		sources.append(legacy_path(id))
		sources.append(legacy_path(id) + ".bak")
	for source in sources:
		var read: Dictionary = _read(source)
		if not read.ok: continue
		if str(read.data.get("map_id", "sonnenhang")) != id: continue
		if Maps.is_player_map(id) and _free_data(read.data) != (slot == 0): continue
		return FileAccess.get_sha256(source) == checksum
	return false

static func passport_path(slot: int = -1, free_slot: int = -1) -> String:
	var selected: int = active_slot if slot < 0 else slot
	if selected == 0:
		var index: int = clampi(active_free_slot if free_slot < 0 else free_slot, 1, 4)
		return "user://free_passport.json" if index == 1 else "user://free_%d_passport.json" % index
	return "user://career_%d_passport.json" % clampi(selected,1,4)

static func index_path(slot: int, free_slot: int = -1) -> String:
	if slot == 0:
		var index: int = clampi(active_free_slot if free_slot < 0 else free_slot, 1, 4)
		return "user://free_index.json" if index == 1 else "user://free_%d_index.json" % index
	return "user://career_%d_index.json" % slot

static func _free_data(data: Dictionary) -> bool:
	# Match Progression.restore: a pre-career resort has no campaign and
	# restores with all former construction access as free play.
	return data.get("campaign") == null or data.get("campaign") is Dictionary and data.campaign.get("mode")=="free"

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

static func summary(slot: int, free_slot: int = -1) -> Dictionary:
	if slot < 0 or slot > 4: return {"occupied": false}
	var entries: Array = saved_resorts(slot, free_slot)
	return entries[0] if not entries.is_empty() else {"occupied": false}

static func free_summary(free_slot: int) -> Dictionary:
	return summary(0, free_slot)

static func migrate_legacy() -> bool:
	# Copy, never move, the previous files. A failed or repeated migration must
	# neither erase the old installation's files nor overwrite newer careers.
	var marker := "user://slots-migrated-017"
	# Do not short-circuit here: some old save files may appear after the
	# marker was first created, especially following APK upgrades and restores.
	# Every pass remains non-destructive and copies only missing destinations.
	for id in Maps.MAPS:
		for suffix in ["", ".bak"]:
			var old: String = legacy_path(id)+suffix
			if not FileAccess.file_exists(old): continue
			var read := _read(old)
			if not read.ok: continue
			var slot := 0 if _free_data(read.data) else 1
			var target := path_for_map(id,slot,1)
			if FileAccess.file_exists(target):
				if suffix==".bak": target+=".bak"
				else: continue
			if not FileAccess.file_exists(target) and DirAccess.copy_absolute(ProjectSettings.globalize_path(old),ProjectSettings.globalize_path(target))!=OK: return false
	# Earlier migrations could put a pre-career/free resort in career 1.
	# Recover readable misplaced sources into an empty first free slot only;
	# never move/delete the source or overwrite an existing free resort.
	for id in Maps.player_maps():
		var free_target: String=path_for_map(id,0,1)
		if FileAccess.file_exists(free_target):continue
		for suffix in ["", ".bak"]:
			var misplaced: String=path_for_map(id,1)+suffix
			var target: String=free_target+suffix
			if not FileAccess.file_exists(misplaced) or FileAccess.file_exists(target):continue
			var read := _read(misplaced)
			if read.ok and _free_data(read.data):
				if DirAccess.copy_absolute(ProjectSettings.globalize_path(misplaced),ProjectSettings.globalize_path(target))!=OK:return false
	var old_passport := "user://skizones_passport.json"
	if FileAccess.file_exists(old_passport) and not FileAccess.file_exists(passport_path(1)):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(old_passport),ProjectSettings.globalize_path(passport_path(1)))!=OK: return false
	if not FileAccess.file_exists(marker):
		var file := FileAccess.open(marker,FileAccess.WRITE)
		if file == null: return false
		file.store_string("1");file.close()
	return true

static func archive_free_slot(free_slot: int) -> bool:
	if free_slot < 1 or free_slot > 4: return false
	var folder := "user://free-archives/slot-%d-%d-%d" % [free_slot,Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK: return false
	var paths: Array = [passport_path(0, free_slot), passport_path(0, free_slot) + ".bak", index_path(0, free_slot)]
	for id in Maps.player_maps():
		var path := path_for_map(id, 0, free_slot)
		paths.append_array([path, path + ".bak"])
	# Complete and SHA-256-verify every archive file before removing ANY source.
	# A partial or interrupted archive must never erase the last original.
	for path in paths:
		if not FileAccess.file_exists(path):continue
		var copy_path:String=folder+"/"+path.get_file()
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(copy_path))!=OK or FileAccess.get_sha256(path)!=FileAccess.get_sha256(copy_path):return false
	for path in paths:
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK: return false
	return true

static func archive_slot(slot: int) -> bool:
	if slot < 1 or slot > 4: return false
	var folder := "user://career-archives/slot-%d-%d-%d" % [slot,Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))!=OK: return false
	var paths: Array=[passport_path(slot),passport_path(slot)+".bak",index_path(slot)]
	for id in Maps.player_maps(): paths.append_array([path_for_map(id,slot),path_for_map(id,slot)+".bak"])
	# Same two-phase, checksum-verified preservation for career restarts.
	for path in paths:
		if not FileAccess.file_exists(path):continue
		var copy_path:String=folder+"/"+path.get_file()
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(copy_path))!=OK or FileAccess.get_sha256(path)!=FileAccess.get_sha256(copy_path):return false
	for path in paths:
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path))!=OK:return false
	return true

static func save_game(model: RefCounted, path: String = DEFAULT_PATH) -> Dictionary:
	var payload := JSON.stringify(model.snapshot(),"",true,true)
	var envelope := JSON.stringify({"format": "SkiZones", "checksum": payload.sha256_text(), "payload": payload})
	if envelope.to_utf8_buffer().size() > MAX_BYTES:
		return {"ok": false, "message": L.text("Dieser Spielstand überschreitet die unterstützte Dateigröße. Das bisherige Resort bleibt gespeichert.")}
	var staging: String = path + ".tmp"
	# A previous process may have died after writing a complete staged save,
	# before the atomic rename. Preserve even unreadable bytes before opening
	# WRITE (which would truncate the only recoverable copy). Never remove it
	# based on parsing or checksum results.
	if FileAccess.file_exists(staging):
		var archive_dir: String = "user://save-recovery"
		if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(archive_dir)) != OK:
			return {"ok": false, "message": L.text("Die Sicherung des bisherigen Spielstands ist fehlgeschlagen.")}
		var archive_path: String = archive_dir + "/" + staging.get_file() + "-%d-%d.before-staging" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(staging), ProjectSettings.globalize_path(archive_path)) != OK or FileAccess.get_sha256(staging) != FileAccess.get_sha256(archive_path):
			return {"ok": false, "message": L.text("Die Sicherung des bisherigen Spielstands ist fehlgeschlagen.")}
	var file := FileAccess.open(staging, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": L.text("Spielstand konnte nicht geschrieben werden.")}
	file.store_string(envelope)
	file.flush()
	file.close()
	# A checksum-valid but semantically impossible snapshot is not a usable
	# backup. Prove that a *fresh* model can restore the bytes before either
	# the primary or the last-good .bak is modified.
	var staged_read: Dictionary = _read(staging)
	var staged_model: RefCounted = model.get_script().new()
	if not staged_read.ok or not staged_model.restore(staged_read.data.duplicate(true)).ok:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staging))
		return {"ok": false, "message": L.text("Reparaturprüfung fehlgeschlagen. Originaldateien bleiben unverändert.")}
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var previous: Dictionary = _read(path)
		var previous_model: RefCounted = model.get_script().new()
		if previous.ok and previous_model.restore(previous.data.duplicate(true)).ok:
			# Before rotating over an *unreadable* .bak, preserve those exact
			# bytes separately. It may hold the only forensic evidence of why
			# an Android upgrade failed, even if its checksum cannot be checked.
			var old_backup_path: String = path + ".bak"
			if FileAccess.file_exists(old_backup_path):
				var old_read: Dictionary = _read(old_backup_path)
				var old_exact: bool = false
				if old_read.ok:
					var old_probe: RefCounted = model.get_script().new()
					old_exact = bool(old_probe.restore(old_read.data.duplicate(true)).ok)
				if not old_exact:
					var folder: String = "user://save-recovery"
					if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
						return {"ok":false,"message":L.text("Die Sicherung des bisherigen Spielstands ist fehlgeschlagen.")}
					var archived: String = folder + "/" + old_backup_path.get_file() + "-%d-%d.before-backup" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()]
					if DirAccess.copy_absolute(ProjectSettings.globalize_path(old_backup_path),ProjectSettings.globalize_path(archived)) != OK or FileAccess.get_sha256(archived) != FileAccess.get_sha256(old_backup_path):
						return {"ok":false,"message":L.text("Die Sicherung des bisherigen Spielstands ist fehlgeschlagen.")}
			# Never stream directly over .bak: an interrupted copy must not
			# corrupt the only earlier checkpoint. Verify a staging copy first.
			var safe_copy: String = path + ".bak.tmp"
			if DirAccess.copy_absolute(absolute, ProjectSettings.globalize_path(safe_copy)) != OK or FileAccess.get_sha256(safe_copy) != FileAccess.get_sha256(path):
				return {"ok": false, "message": L.text("Die Sicherung des bisherigen Spielstands ist fehlgeschlagen.")}
			if DirAccess.rename_absolute(ProjectSettings.globalize_path(safe_copy), absolute + ".bak") != OK:
				return {"ok": false, "message": L.text("Die Sicherung des bisherigen Spielstands ist fehlgeschlagen.")}
		else:
			# Preserve checksum-valid but semantically broken originals as well.
			# Existing .bak is deliberately NOT rotated or overwritten.
			var rescue_dir := "user://save-recovery"
			if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(rescue_dir)) != OK:
				return {"ok": false, "message": L.text("Die Sicherung des bisherigen Spielstands ist fehlgeschlagen.")}
			var archive: String = rescue_dir + "/" + path.get_file() + "-%d-%d.broken" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
			if DirAccess.copy_absolute(absolute, ProjectSettings.globalize_path(archive)) != OK or FileAccess.get_sha256(archive) != FileAccess.get_sha256(path):
				return {"ok": false, "message": L.text("Die Sicherung des bisherigen Spielstands ist fehlgeschlagen.")}
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(staging), absolute) != OK:
		return {"ok": false, "message": L.text("Spielstand konnte nicht atomar ersetzt werden.")}
	if Maps.is_player_map(model.map_id) and path==path_for_map(model.map_id): _write_index(model,active_slot)
	return {"ok": true, "message": L.text("Resort gespeichert.")}

static func _read(path: String, progress: RefCounted = null) -> Dictionary:
	# Sanitized, read-only reason codes. Do not log user-authored payloads.
	if progress != null: progress.report(3.0, L.text("Spielstand lesen …"))
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "code": "missing_or_unreadable", "bytes": 0, "message": L.text("Kein gültiger Spielstand gefunden.")}
	var size: int = file.get_length()
	if size > MAX_BYTES:
		file.close()
		return {"ok": false, "code": "size_limit", "bytes": size, "message": L.text("Dieser Spielstand überschreitet die unterstützte Dateigröße. Das bisherige Resort bleibt gespeichert.")}
	var source: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(source) != OK:
		return {"ok": false, "code": "invalid_json", "bytes": size, "parse_line": parser.get_error_line(), "message": L.text("Beschädigte Spielstand-Datei.")}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {"ok": false, "code": "not_object", "bytes": size, "message": L.text("Beschädigte Spielstand-Datei.")}
	# Only actual pre-checksum schemas 1–6 may be unsigned.
	# Even a partially present envelope must never bypass validation.
	if not parsed.has("format") and not parsed.has("checksum") and not parsed.has("payload"):
		var version: Variant = parsed.get("version")
		if (version is int or version is float) and float(version) == floorf(float(version)) and version >= 1 and version <= 6 and parsed.get("pistes") is Array and parsed.get("lifts") is Array and parsed.get("buildings") is Array and parsed.get("guests") is Array and parsed.get("map_id", "sonnenhang") is String and parsed.get("money") != null and parsed.get("day") != null:
			return {"ok": true, "code": "ok_legacy", "bytes": size, "schema_version": int(version), "data": parsed, "legacy_raw": true}
		return {"ok": false, "code": "unsupported_raw_schema", "bytes": size, "schema_version": int(version) if version is int or version is float else -1, "message": L.text("Unbekanntes historisches Speicherformat. Originaldatei bleibt erhalten.")}
	if parsed.get("format") != "SkiZones" or not parsed.get("payload") is String or not parsed.get("checksum") is String:
		return {"ok": false, "code": "invalid_envelope", "bytes": size, "message": L.text("Beschädigte Spielstand-Datei.")}
	if progress != null: progress.report(7.0, L.text("Prüfsumme kontrollieren …"))
	if parsed.payload.sha256_text() != parsed.checksum:
		return {"ok": false, "code": "checksum_mismatch", "bytes": size, "message": L.text("Die Prüfsumme des Spielstands stimmt nicht.")}
	if parser.parse(parsed.payload) != OK:
		return {"ok": false, "code": "invalid_payload_json", "bytes": size, "parse_line": parser.get_error_line(), "message": L.text("Beschädigte Spielstand-Daten.")}
	var payload: Variant = parser.data
	if not payload is Dictionary:
		return {"ok": false, "code": "invalid_payload_shape", "bytes": size, "message": L.text("Beschädigte Spielstand-Daten.")}
	var schema: Variant = payload.get("version", -1)
	return {"ok": true, "code": "ok", "bytes": size, "schema_version": int(schema) if schema is int or schema is float else -1, "data": payload}

static func load_game(model: RefCounted, path: String = DEFAULT_PATH, progress: RefCounted = null) -> Dictionary:
	model.load_progress = progress
	var verified: Array = []
	var sources: Array = [path,path+".bak"]
	# Pre-slot saves remain a final, read-only fallback. Never load a former
	# career into slot 2–4, or a free-play career into a paid slot.
	var legacy_id := ""
	var expected_free := false
	var legacy_scenario := false
	if path.begins_with("user://career_1_") and path.ends_with(".json"):
		legacy_id = path.trim_prefix("user://career_1_").trim_suffix(".json")
	elif path.begins_with("user://free_") and path.ends_with(".json"):
		legacy_id = path.trim_prefix("user://free_").trim_suffix(".json")
		expected_free = true
	if path.begins_with("user://scenario_") and path.ends_with(".json"):
		# Old scenario files may predate career/free mode metadata entirely.
		legacy_id=path.trim_prefix("user://scenario_").trim_suffix(".json")
		legacy_scenario=true
	if Maps.MAPS.has(legacy_id):
		sources.append(legacy_path(legacy_id))
		sources.append(legacy_path(legacy_id)+".bak")
	for candidate in sources:
		if progress != null and candidate.ends_with(".bak"): progress.detail(L.text("Vorherige Sicherung prüfen …"))
		var read := _read(candidate, progress)
		if read.ok:
			if legacy_scenario and str(read.data.get("map_id","sonnenhang"))!=legacy_id:continue
			if candidate in sources.slice(2) and not legacy_scenario and (_free_data(read.data) != expected_free):
				continue
			verified.append({"path":candidate,"data":read.data})
			var restored: Dictionary = model.restore(read.data.duplicate(true))
			if restored.ok:
				return {"ok":true,"recovered":false,"source":candidate,"legacy":candidate in sources.slice(2) or read.get("legacy_raw", false),"message":L.text("Älterer Spielstand geladen.") if candidate in sources.slice(2) else L.text("Vorherige Sicherung geladen.") if candidate.ends_with(".bak") else L.text("Resort geladen.")}
	# First retain the exact old geometry and active guests even when modern
	# construction clearances have changed. This opt-in recovery never trusts
	# unchecked bytes: the envelope checksum and model validation still apply.
	# Any recovered original is archived BEFORE the loaded model is changed.
	for original in verified:
		var checked: Dictionary = probe_restore(original.data, model.get_script(), true, progress)
		if not checked.ok: continue
		var archive: String = original.path + ".recovery-%d-%d.json" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()]
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(original.path),ProjectSettings.globalize_path(archive)) != OK or FileAccess.get_sha256(original.path) != FileAccess.get_sha256(archive):
			return {"ok":false,"message":L.text("Die ursprüngliche Datei konnte nicht gesichert werden. Der Spielstand bleibt unverändert.")}
		if model.restore(checked.model.snapshot()).ok:
			return {"ok":true,"recovered":true,"source":original.path,"archive":archive,"message":L.text("Strecke und Karriere wiederhergestellt. Aktuelle Gastpositionen wurden zurückgesetzt; die ursprüngliche Datei bleibt gesichert.") if checked.reset_visitors else L.text("Strecke und Karriere wiederhergestellt; die ursprüngliche Datei bleibt gesichert.")}

	return {"ok": false, "message": L.text("Kein lesbarer Spielstand vorhanden. Das aktuelle Resort bleibt erhalten.")}


# Shared semantic validation for inspect, repair and load. The caller must
# verify the original checksum first. Only transient visitor data may reset;
# permanent assets, budget and progression still pass the full validator.
static func probe_restore(data: Dictionary, model_script: Script, recovery_only: bool = false, progress: RefCounted = null) -> Dictionary:
	# Preserve active guests with historical construction before resetting them.
	var first_error: String=""
	for attempt in ([2, 1, 3] if recovery_only else [0, 2, 1, 3]):
		var world: Dictionary = data.duplicate(true)
		var reset_visitors: bool = attempt in [1, 3]
		var old_geometry: bool = attempt >= 2
		if reset_visitors:
			if not world.get("guests") is Array or world.guests.is_empty(): continue
			world.guests=[];world.itineraries=[];world.parties=[]
		var probe: RefCounted = model_script.new()
		probe.load_progress=progress
		if progress!=null:progress.detail(L.text("Strecke und Karriere wiederherstellen …"))
		var result:Dictionary=probe.restore(world,old_geometry)
		if result.ok:
			return {"ok":true,"exact":attempt==0,"model":probe,"reset_visitors":reset_visitors,"legacy_geometry":old_geometry}
		if first_error.is_empty():first_error=str(result.get("message",L.text("Unbekannter Validierungsfehler")))
	return {"ok":false,"message":first_error}
