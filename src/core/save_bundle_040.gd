extends RefCounted
## Read-only evidence export for a broken Android career. Never repair, migrate
## or overwrite a source or .bak when collecting a support bundle.
const Saves = preload("res://src/core/save_store.gd")
const Manager = preload("res://src/core/save_management_038.gd")
const MAX_FILES := 12
const MAX_TOTAL_BYTES := 150000000
const EXPORT_DIR := "user://save-diagnostics"

static func share_slot_archive(path: String) -> Dictionary:
	# Godot 4.5 AndroidRuntime + JNI only exist on Android; do not reference
	# their global symbols on desktop, where GDScript still must compile.
	if not OS.has_feature("android"):
		return {"ok": false, "code": "android_only"}
	if not Engine.has_singleton("AndroidRuntime") or not Engine.has_singleton("JavaClassWrapper"):
		return {"ok": false, "code": "android_runtime_unavailable"}
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var jni: Object = Engine.get_singleton("JavaClassWrapper")
	var bridge: Object = jni.call("wrap", "cloud.kosch.skizones.AppInfoBridge")
	if bridge == null: return {"ok": false, "code": "android_bridge_unavailable"}
	var status: String = str(bridge.call("shareSaveBundle", runtime.call("getActivity"), ProjectSettings.globalize_path(path)))
	if jni.call("get_exception") != null:
		return {"ok": false, "code": "android_share_exception"}
	return {"ok": status == "ok", "code": status}

static func export_slot(map_id: String, slot: int, free_slot: int = 1) -> Dictionary:
	var candidates: Array = Manager.recovery_sources(map_id, slot, free_slot)
	if candidates.is_empty():
		return {"ok": false, "code": "invalid_slot"}
	var checked: Array = Manager.sources(map_id, slot, free_slot)
	# Always prioritize the exact primary and .bak before older archived saves.
	for source in candidates:
		if source not in checked: checked.append(source)
	var selected: Array = []
	var entries: Array = []
	var skipped: Array = []
	var total := 0
	for path in checked:
		if not FileAccess.file_exists(path): continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			skipped.append({"name": path.get_file(), "reason": "unreadable"})
			continue
		var length: int = file.get_length()
		if length > Saves.MAX_BYTES or total + length > MAX_TOTAL_BYTES or selected.size() >= MAX_FILES:
			skipped.append({"name": path.get_file(), "reason": "bundle_limit", "bytes": length})
			file.close()
			continue
		# Keep only file descriptors and short metadata in RAM. An Android
		# resort may be tens of MB; holding 12 whole JSON files and the
		# compressed ZIP at once risks an out-of-memory crash.
		file.close()
		var archive_name := "files/%02d-%s" % [selected.size(), path.get_file().replace("/", "_")]
		var read: Dictionary = Saves._read(path)
		selected.append({"archive": archive_name, "source": path, "bytes": length, "sha256": FileAccess.get_sha256(path)})
		entries.append({"name": path.get_file(), "archive": archive_name, "bytes": length, "sha256": FileAccess.get_sha256(path), "code": str(read.get("code", "unknown")), "schema_version": int(read.get("schema_version", -1)), "parse_line": int(read.get("parse_line", 0))})
		total += length
	if selected.is_empty():
		return {"ok": false, "code": "no_readable_source", "skipped": skipped}
	var inspection: Dictionary = Manager.inspect(map_id, slot, free_slot)
	var diagnostic: Array = []
	for item in inspection.get("files", []):
		diagnostic.append({"name": str(item.name), "reason": str(item.get("code", "")), "version": int(item.get("schema_version", -1)), "loadable": bool(item.get("loadable", false)), "recoverable": bool(item.get("recoverable", false)), "parse_line": int(item.get("parse_line", 0))})
	var report := {"app": "SkiZones", "support_format": 1, "map": map_id, "slot": slot, "free_slot": free_slot, "source_count": selected.size(), "files": entries, "diagnostics": diagnostic, "omitted": skipped}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EXPORT_DIR)) != OK:
		return {"ok": false, "code": "export_directory"}
	var base := "%s/skizones-support-%s-%d-%d-%d.zip" % [EXPORT_DIR, map_id, slot, Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	var staging := base + ".tmp"
	var zip := ZIPPacker.new()
	if zip.open(staging) != OK:
		return {"ok": false, "code": "zip_open"}
	var ok := zip.start_file("diagnostic.json") == OK
	if ok: ok = zip.write_file(JSON.stringify(report, "\t").to_utf8_buffer()) == OK
	if ok: ok = zip.close_file() == OK
	for item in selected:
		if not ok: break
		ok = zip.start_file(str(item.archive)) == OK
		if ok:
			var input := FileAccess.open(str(item.source), FileAccess.READ)
			if input == null:
				ok = false
			else:
				var left: int = int(item.bytes)
				while left > 0:
					var block: PackedByteArray = input.get_buffer(mini(65536, left))
					if block.is_empty() or zip.write_file(block) != OK:
						ok = false
						break
					left -= block.size()
				input.close()
		if ok: ok = zip.close_file() == OK
	zip.close()
	if not ok:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staging))
		return {"ok": false, "code": "zip_write"}
	var reader := ZIPReader.new()
	if reader.open(staging) != OK:
		return {"ok": false, "code": "zip_verification"}
	var verified := reader.get_files().size() == selected.size() + 1
	for item in selected:
		if not verified: break
		# Only one decompressed source is resident at a time; validate the
		# original checksum, not just the ZIP's file count.
		var digest := HashingContext.new()
		if digest.start(HashingContext.HASH_SHA256) != OK:
			verified = false
		else:
			var unpacked: PackedByteArray = reader.read_file(str(item.archive))
			verified = digest.update(unpacked) == OK and digest.finish().hex_encode() == str(item.sha256)
	reader.close()
	if not verified:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(staging))
		return {"ok": false, "code": "zip_verification"}
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(staging), ProjectSettings.globalize_path(base)) != OK:
		return {"ok": false, "code": "zip_commit"}
	return {"ok": true, "path": base, "files": selected.size(), "bytes": total, "omitted": skipped}
