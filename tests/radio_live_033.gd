extends SceneTree
const Program = preload("res://src/core/radio_program.gd")
const Radio = preload("res://src/world/resort_audio.gd")
const Preferences = preload("res://src/core/preferences.gd")
var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)

func run() -> void:
	var timing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/music/cc0/durations.json")).seconds
	for path in timing:
		var stream: AudioStream = load(path) as AudioStream
		check(stream != null and absf(stream.get_length() - float(timing[path])) < 0.001, "Timing index matches the actual bundled recording: " + str(path))
	var clock: Array = [1793822400.345]
	var prefs := Preferences.new()
	prefs.music_genre = "alpine"
	prefs.music_volume = 0.6
	var radio := Radio.new()
	root.add_child(radio)
	radio.clock_source = func(): return clock[0]
	radio.setup(null, prefs)
	await process_frame
	check(radio._tune_offset > 0.1 and radio.players.music.playing, "First tuning seeks into the real current recording, not its beginning")
	check(absf(radio.players.music.get_playback_position() - radio._tune_offset) < 0.3, "The actual audio player starts at the scheduled offset")
	var first: Dictionary = radio.programme_position("alpine")
	var second := Radio.new()
	root.add_child(second)
	second.clock_source = func(): return clock[0]
	second.setup(null, prefs)
	check(second.programme_position("alpine") == first and is_equal_approx(second._tune_offset, radio._tune_offset), "A fresh receiver at the same time joins the identical station position")
	radio.set_genre("techno")
	clock[0] += 7.0
	radio.set_genre("alpine")
	check(is_equal_approx(radio._tune_offset, float(radio.programme_position("alpine").offset)) and radio.programme_position("alpine") != first, "A switched-away station advances while only the other station plays")
	var current: Dictionary = radio.programme_position("alpine")
	clock[0] += float(current.remaining) + 0.4
	radio._mix(2.0)
	radio._maybe_advance_song()
	check(int(radio.programme_position("alpine").index) != int(current.index) and absf(radio._tune_offset - 0.4) < 0.01, "Real airtime crossing advances to the next recording and correct offset")
	prefs.sound_enabled = false
	radio.sync()
	check(radio.players.values().all(func(p): return not p.playing or p.stream_paused), "Mute silences both primary and retiring audio immediately")
	clock[0] += 600.0
	prefs.sound_enabled = true
	radio.sync()
	check(absf(radio._tune_offset - float(radio.programme_position("alpine").offset)) < 0.01, "Unmuting rejoins the advanced live programme instead of resuming stale audio")
	radio.set_active(false)
	clock[0] += 2700.0
	radio.set_active(true)
	check(absf(radio._tune_offset - float(radio.programme_position("alpine").offset)) < 0.01, "App resume follows the hypothetical clock after 45 minutes away")
	radio._mix(2.0)
	var before_skip: Dictionary = radio.programme_position("alpine")
	var other_station: Dictionary = radio.programme_position("punk")
	radio.next_track()
	check(radio.programme_position("alpine").index != before_skip.index and radio._tune_offset < 0.01, "Manual next-title action still works")
	check(radio.programme_position("punk") == other_station, "Skipping one station does not disturb another station's clock")
	prefs.music_genre = "off"
	radio.set_context_station("hotel_lobby")
	check(radio.current_genre == "off" and radio.players.values().all(func(p): return not p.playing or p.stream_paused), "An explicit music-off choice also silences temporary hotel radio")
	var program := Program.new()
	var entries: Array = [{"file":"a"},{"file":"b"},{"file":"c"}]
	program.register("test", entries, {"a":20.0,"b":30.0,"c":40.0}, 1.0)
	check(program.position("test", 100.0) == program.position("test", 187.0), "A complete hypothetical programme loops with exact measured airtime")
	check(program.position("missing", 0.0).is_empty() and program.position("test", NAN).is_empty(), "Unknown stations and invalid clock values cannot create an invalid seek")
	radio.queue_free()
	second.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
