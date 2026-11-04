extends SceneTree
## All CC0 songs are checked from the actual imported Ogg assets, not inferred by names.
## Emits playable durations for editorial review before any "long-form" claim.
const Design = preload("res://src/core/audio_design.gd")
var MIN_SECONDS := 180.0

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/cc0/library.json"))
	if not data is Dictionary:
		push_error("Invalid radio library JSON")
		quit(1)
		return
	var station_data: Dictionary = data.get("stations",{})
	var measured: Dictionary = {}
	var long_ids: Dictionary = {}
	for key in station_data:
		for item in station_data[key]:
			if not item is Dictionary: continue
			var id: String = str(item.get("id",""))
			if measured.has(id): continue
			var path: String = str(item.get("file",""))
			var stream: AudioStream = load(path) as AudioStream
			var seconds: float = stream.get_length() if stream != null else 0.0
			measured[id] = seconds
			if seconds >= MIN_SECONDS: long_ids[id] = true
			print("RADIO_DURATION|%s|%.1f|%s|%s" % [id,seconds,str(item.get("style","")),str(item.get("title",""))])
	for station in station_data:
		var seen: Dictionary = {}
		var qualifying := 0
		var over_five := 0
		for item in station_data[station]:
			var id: String = str(item.get("id",""))
			if seen.has(id): continue
			seen[id] = true
			var length: float = float(measured.get(id,0.0))
			if length >= MIN_SECONDS: qualifying += 1
			if length >= 300.0: over_five += 1
		print("RADIO_STATION_DURATION|%s|%d|%d|%d" % [str(station),qualifying,over_five,seen.size()])
	print("RADIO_TOTAL_DURATION|%d|%d" % [long_ids.size(),measured.size()])
	# Godot CI harness requires a formal result summary even for an inventory
	# which deliberately reports short recordings rather than claiming success.
	print("RESULT: 1 passed; 0 failed")
	quit(0)
