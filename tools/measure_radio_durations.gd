extends SceneTree
## Rebuild the offline broadcast timing index from the actual bundled audio.
func _init() -> void:
	var library: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/cc0/library.json"))
	var durations: Dictionary = {}
	for entries in library.stations.values():
		for record in entries:
			var path: String = str(record.file)
			if durations.has(path): continue
			var stream: AudioStream = load(path) as AudioStream
			if stream == null or stream.get_length() <= 0.0:
				push_error("Missing playable recording: " + path)
				quit(1)
				return
			durations[path] = stream.get_length()
	var file := FileAccess.open("res://assets/music/cc0/durations.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1, "seconds":durations}, "  ", true) + "\n")
	print("Measured ", durations.size(), " actual recordings")
	quit(0)
