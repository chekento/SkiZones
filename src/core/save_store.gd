extends RefCounted
## Checksum, size bound, atomic replacement and one previous valid save.

const DEFAULT_PATH := "user://skizones_save.json"
const MAX_BYTES := 4000000

static func save_game(model: RefCounted, path: String = DEFAULT_PATH) -> Dictionary:
	var payload := JSON.stringify(model.snapshot())
	var envelope := JSON.stringify({"format": "SkiZones", "checksum": payload.sha256_text(), "payload": payload})
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "Spielstand konnte nicht geschrieben werden."}
	file.store_string(envelope)
	file.flush()
	file.close()
	var absolute := ProjectSettings.globalize_path(path)
	# Preserve an existing backup when the main file is already damaged.
	if FileAccess.file_exists(path) and _read(path).ok:
		var backup_error := DirAccess.copy_absolute(absolute, absolute + ".bak")
		if backup_error != OK:
			return {"ok": false, "message": "Die Sicherung des bisherigen Spielstands ist fehlgeschlagen."}
	if DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
		return {"ok": false, "message": "Spielstand konnte nicht atomar ersetzt werden."}
	return {"ok": true, "message": "Resort gespeichert."}

static func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {"ok": false, "message": "Kein gültiger Spielstand gefunden."}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"ok": false, "message": "Beschädigte Spielstand-Datei."}
	var parsed: Variant = parser.data
	if not parsed is Dictionary or parsed.get("format") != "SkiZones" or not parsed.get("payload") is String or not parsed.get("checksum") is String:
		return {"ok": false, "message": "Beschädigte Spielstand-Datei."}
	if parsed.payload.sha256_text() != parsed.checksum:
		return {"ok": false, "message": "Die Prüfsumme des Spielstands stimmt nicht."}
	if parser.parse(parsed.payload) != OK:
		return {"ok": false, "message": "Beschädigte Spielstand-Daten."}
	var payload: Variant = parser.data
	if not payload is Dictionary:
		return {"ok": false, "message": "Beschädigte Spielstand-Daten."}
	return {"ok": true, "data": payload}

static func load_game(model: RefCounted, path: String = DEFAULT_PATH) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		var read := _read(candidate)
		if read.ok:
			var restored: Dictionary = model.restore(read.data)
			if restored.ok:
				return {"ok": true, "message": "Vorherige Sicherung geladen." if candidate.ends_with(".bak") else "Resort geladen."}
	return {"ok": false, "message": "Kein lesbarer Spielstand vorhanden. Das aktuelle Resort bleibt erhalten."}
