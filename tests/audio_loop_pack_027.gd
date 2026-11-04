extends SceneTree
## 0.27 original radio-loop pack: assets must be real multi-bar audio, imported and loopable.
const Radio = preload("res://src/world/resort_audio.gd")
const Design = preload("res://src/core/audio_design.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var radio := Radio.new()
	root.add_child(radio)
	check(Design.GENRES.size() == 8, "Seven music stations and off")
	for station in Design.GENRES:
		if station in ["off", "freeride"]:
			continue
		var track: AudioStream = radio._music_stream(station)
		check(track is AudioStreamWAV, station + " has a WAV track")
		if track is AudioStreamWAV:
			var wav := track as AudioStreamWAV
			check(wav.mix_rate == 22050, station + " sample rate")
			check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD, station + " loops")
			check(wav.get_length() > 10.0, station + " has an extended musical arrangement")
			check(wav.data.size() > 10000, station + " has imported audio payload")
			check(wav.loop_end > 200000, station + " has valid loop bounds")
	check(radio._music_stream("freeride") is AudioStreamWAV, "Mixed station has original offline synthesizer fallback")
	radio.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
