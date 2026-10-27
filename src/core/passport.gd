extends RefCounted
## Small independent metaprogression file; each area has a separate resort save.
const Maps = preload("res://src/core/maps.gd")
const PATH := "user://skizones_passport.json"
var data := {"version": 1, "last_map": "sonnenhang", "records": {}}

func record(model: RefCounted) -> void:
	var previous: Dictionary = data.records.get(model.map_id, {"rank": 1, "guests": 0, "contracts": 0})
	data.records[model.map_id] = {"rank": maxi(previous.rank, model.campaign.rank), "guests": maxi(previous.guests, model.total_guests), "contracts": maxi(previous.contracts, model.campaign.completed)}
	data.last_map = model.map_id

func totals() -> Dictionary:
	var result := {"rank": 1, "guests": 0, "contracts": 0}
	for entry in data.records.values():
		result.rank = maxi(result.rank, entry.rank)
		result.guests += entry.guests
		result.contracts += entry.contracts
	return result

func unlocked(id: String) -> bool:
	if not Maps.MAPS.has(id):
		return false
	var current := totals()
	var needed := Maps.spec(id)
	return current.rank >= needed.rank and current.guests >= needed.guests and current.contracts >= needed.contracts

func requirement(id: String) -> String:
	var needed := Maps.spec(id)
	var current := totals()
	return "Resort-Sterne %d / %d   ·   Gäste %d / %d   ·   Aufträge %d / %d" % [mini(current.rank, needed.rank), needed.rank, mini(current.guests, needed.guests), needed.guests, mini(current.contracts, needed.contracts), needed.contracts]

func save_to(path: String = PATH) -> bool:
	var payload := JSON.stringify(data)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"payload": payload, "sha": payload.sha256_text()}))
	file.close()
	if FileAccess.file_exists(path) and not _read_from(path).is_empty():
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak")) != OK:
			return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

func _read_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 10000:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or not envelope.get("payload") is String or envelope.get("sha") != envelope.payload.sha256_text():
		return {}
	if parser.parse(envelope.payload) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary or parsed.get("version") != 1 or not Maps.MAPS.has(parsed.get("last_map")) or not parsed.get("records") is Dictionary:
		return {}
	if parsed.records.size() > Maps.MAPS.size():
		return {}
	for id in parsed.records:
		if not Maps.MAPS.has(id) or not parsed.records[id] is Dictionary:
			return {}
		for key in ["rank", "guests", "contracts"]:
			var value: Variant = parsed.records[id].get(key)
			if not (value is int or value is float) or not is_finite(value) or value < 0 or value > (5 if key == "rank" else 1000000000) or value != floorf(value):
				return {}
			parsed.records[id][key] = int(value)
	return parsed

func load_from(path: String = PATH) -> void:
	for candidate in [path, path + ".bak"]:
		var parsed := _read_from(candidate)
		if not parsed.is_empty():
			data = parsed
			return
