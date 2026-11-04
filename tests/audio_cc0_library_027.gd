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
	for station in Design.GENRES:
		if station == "off":
			continue
		var amount: int = radio.station_track_count(station)
		check(amount >= 2, station + " has at least two real tracks")
		total += amount
		for track in radio.track_credits(station):
			check(str(track.get("license", "")) == "CC0-1.0" and str(track.get("source_url","")).begins_with("https://"), "Rights and artist reference recorded")
			check(ResourceLoader.exists(str(track.get("file",""))), station + " actual Ogg asset")
	var first: AudioStream = radio._radio_stream("alpine")
	check(first is AudioStreamOggVorbis and first.get_length() > 20.0, "Folk radio streams long-form music")
	var title_a: String = radio.current_track_title
	var second: AudioStream = radio._radio_stream("alpine", true)
	check(second is AudioStreamOggVorbis and radio.current_track_title != title_a, "Advancing playlist selects another real song")
	check(total == 13, "Complete 13-song CC0 pack available")
	radio.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
