extends SceneTree
## 0.27 regression: retain all 0.26 preview, consent, live crowd and Android audio behavior.
const Design=preload("res://src/core/audio_design.gd")
const Radio=preload("res://src/world/resort_audio.gd")
const Preferences=preload("res://src/core/preferences.gd")
var passed:=0
var failed:=0

func check(ok: bool, label: String) -> void:
	if ok:
		passed+=1
		print("PASS ",label)
	else:
		failed+=1
		push_error("FAIL "+label)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	check(is_zero_approx(Design.mix_step(0.0,1.0,0.0)),"Zero delta does not jump")
	check(Design.mix_step(0.0,1.0,0.1)>0.0 and Design.mix_step(0.0,1.0,0.1)<1.0,"Continuous transition")
	var sampled:=0.0
	for frame in range(20): sampled=Design.mix_step(sampled,1.0,0.05)
	check(sampled>0.35 and sampled<0.70,"Frame-rate independent sound interpolation")
	check(is_equal_approx(Design.mix_step(-2.0,10.0,100.0),1.0),"Gain always clamped")
	check(is_equal_approx(Design.mix_step(0.75,0.0,-1.0),0.75),"Invalid negative delta ignored")
	check(Design.SOUND_MIX.disco.music>Design.SOUND_MIX.hotel.music and Design.SOUND_MIX.hotel.music>Design.SOUND_MIX.piste.music,"Zone emphasis preserved")
	check(Design.ZONE_NAMES.has("hotel") and Design.ZONE_NAMES.has("rescue"),"Localized zone labels preserved")
	check(not Design.license_policy("suno") and not Design.license_policy("soundcloud"),"Unlicensed services remain disabled")
	var radio:=Radio.new()
	root.add_child(radio)
	var prefs:=Preferences.new()
	prefs.music_genre="off"
	prefs.sound_enabled=true
	prefs.music_volume=0.65
	prefs.ambient_volume=0.45
	prefs.master_volume=1.0
	radio.preferences=prefs
	for name in ["wind","crowd","machinery","music","music_alt"]:
		var player:=AudioStreamPlayer.new()
		player.name=name
		radio.add_child(player)
		radio.players[name]=player
	radio.set_preview({"genre":"punk"})
	check(radio.current_genre=="punk" and not radio.preview_settings.is_empty(),"Preview does not persist a station")
	check(float(radio._targets.music)>0.0 and prefs.music_genre=="off","Saved opt-out remains unchanged")
	radio._mix(0.2)
	radio.set_preview({"genre":"alpine"})
	check(radio.current_genre=="alpine" and is_instance_valid(radio._retiring_music),"Genre switch crossfades two active players")
	radio._mix(1.3)
	check(not is_instance_valid(radio._retiring_music) and is_equal_approx(radio._crossfade,1.0),"Finished fade cleans old player")
	radio.set_preview({"enabled":false})
	check(is_zero_approx(float(radio._targets.music)) and radio.players["music"].stream_paused,"Audio opt-out is immediate")
	radio.set_preview({"genre":"off","enabled":true})
	check(radio.current_genre=="off" and not radio.players["music"].playing,"Off stops all music")
	radio.clear_preview()
	check(radio.current_genre=="off" and radio.preview_settings.is_empty(),"Cancel restores saved station")
	prefs.music_genre="meditative"
	radio.sync()
	check(radio.current_genre=="meditative" and float(radio._targets.music)>0.0,"Persisted genre restores correctly")
	radio.set_active(false)
	check(radio.players["music"].stream_paused and radio.players["wind"].stream_paused,"Backgrounding pauses playback")
	radio.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
