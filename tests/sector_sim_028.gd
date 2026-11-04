extends SceneTree
## SkiZones 0.28: sector-specific mini-simulations, responsive radio and opt-in album.
const SectorCases = preload("res://src/core/sector_decisions.gd")
const Design = preload("res://src/core/audio_design.gd")
const Audio = preload("res://src/world/resort_audio.gd")
const Preferences = preload("res://src/core/preferences.gd")
var failed := 0
var passed := 0

class FakeResort:
	extends RefCounted
	var queued := 32
	var visitors := 217
	func queue_size() -> int: return queued
	func present_guests() -> int: return visitors

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ",label)
	else:
		failed += 1
		push_error("FAIL "+label)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var model := FakeResort.new()
	var categories := {
		"bus":"transport","repair_office":"maintenance",
		"snowmaker":"snow","first_aid":"rescue","rental":"rental",
		"school":"school","snowpark":"park","restaurant":"hospitality",
		"disco":"nightlife","spa":"wellness","watchmaker":"retail"
	}
	for kind in categories:
		var group: String = SectorCases.group(kind)
		check(group==str(categories[kind]),kind+" assigned a real operational sector")
		for step in range(5):
			var case_data: Dictionary = SectorCases.challenge(model,{"kind":kind,"id":24},{"step":step,"day":1})
			check(case_data.get("mode","")=="decision" and (case_data.get("choices",[]) as Array).size()==3,kind+" scenario has three actual tradeoffs")
			check(int(case_data.get("answer",-1))>=0 and int(case_data.get("answer",-1))<3,kind+" scenario admits a valid decision")
			check(str(case_data.get("context","")).contains("32"),kind+" case uses actual live queue size")
	check(Design.GENRES.size()==18,"Seventeen programmes and silent mode")
	check("erg0sphere" in Design.EXTERNAL_STATIONS,"Own album is explicitly external")
	check(Design.genre_valid("folk_swedish")=="folk_swedish","Swedish folk genre is valid")
	check(Design.genre_valid("space")=="space","Deep Space genre stays separate")
	check(not Audio.AMBIENT_FX_ENABLED,"Piercing synthesized FX remain disabled")
	var radio := Audio.new()
	root.add_child(radio)
	check(radio.station_track_count("folk_alpine")>=10 and radio.station_track_count("folk_swedish")>=10,"Both acoustic folk programmes now have at least ten licensed local tracks")
	check(radio.station_track_count("space")>=15 and radio.station_track_count("erg0sphere")==0,"Deep Space is offline, own album must open explicitly")
	var prefs := Preferences.new()
	prefs.music_genre="erg0sphere"
	prefs.path="user://028-radio-preferences-test.cfg"
	check(prefs.save_to()==OK,"External station preference saves")
	var restored := Preferences.new()
	restored.path=prefs.path
	restored.load_from()
	check(restored.music_genre=="erg0sphere","Own album preference survives restart")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(prefs.path))
	var terms: String = FileAccess.get_file_as_string("res://assets/licenses/SoundCloud.txt")
	check("SoundCloud" in terms and "nicht automatisch" in terms and "IP-Adresse" in terms,"In-game source file includes SoundCloud privacy and opt-in detail")
	radio.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed>0 else 0)
