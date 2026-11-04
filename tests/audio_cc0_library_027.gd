extends SceneTree
## Bundled open-music library QA. No network, no APK runtime download.
const Design = preload("res://src/core/audio_design.gd")
const Radio = preload("res://src/world/resort_audio.gd")
var passed := 0
var failed := 0

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ", message)
	else:
		failed += 1
		push_error("FAIL " + message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var radio := Radio.new()
	root.add_child(radio)
	radio._load_cc0_library()
	var total := 0
	var seen: Dictionary = {}
	var expected := {"alpine":16,"techno":16,"hiphop":16,"punk":16,"classical":16,"meditative":16,"freeride":16,"space":15,"apres":12,"glacier":12,"erg0sphere":0,"folk_alpine":7,"folk_swedish":7}
	for station in Design.GENRES:
		if station == "off":
			continue
		var amount: int = radio.station_track_count(station)
		check(amount == int(expected.get(station,-1)), station + " expected indexed station track count")
		total += amount
		for track in radio.track_credits(station):
			check(str(track.get("license", "")) == "CC0-1.0" and str(track.get("source_url","")).begins_with("https://"), "Rights and artist reference recorded")
			var path: String = str(track.get("file",""))
			check(ResourceLoader.exists(path), station + " actual Ogg asset")
			var mirror: Dictionary = track.get("mirror", {})
			check(str(mirror.get("git_blob_sha1","")).length() == 40 and int(mirror.get("bytes",0)) > 100000, station + " pinned source hash and size")
			check(not seen.has(path) or bool(track.get("playlist_reuse", false)) or station == "freeride", station + " repeats only cross-programme CC0 items")
			seen[path] = true
	check(radio.station_track_count("freeride") == 16, "Summit Rush has an expanded mountain journey")
	check(radio.station_track_count("erg0sphere") == 0 and "erg0sphere" in Design.EXTERNAL_STATIONS, "External album never claims bundled audio")
	var first: AudioStream = radio._radio_stream("alpine")
	check(first is AudioStreamOggVorbis and first.get_length() > 20.0, "Folk radio streams long-form music")
	var title_a: String = radio.current_track_title
	var second: AudioStream = radio._radio_stream("alpine", true)
	check(second is AudioStreamOggVorbis and radio.current_track_title != title_a, "Advancing playlist selects another real song")
	check(total == 165 and seen.size() == 72, "Twelve offline stations, 165 playlist positions, 72 verified underlying CC0 files")
	radio.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
