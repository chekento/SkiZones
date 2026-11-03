extends SceneTree
## Radio crossfade must be deterministic and never load third-party music.
const Design=preload("res://src/core/audio_design.gd")
const Radio=preload("res://src/world/resort_audio.gd")
const Preferences=preload("res://src/core/preferences.gd")
var passed:=0
var failed:=0

func check(ok: bool, description: String) -> void:
	if ok:
		passed+=1
		print("PASS ",description)
	else:
		failed+=1
		push_error("FAIL "+description)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	check(is_equal_approx(Design.mix_step(0,1,0),0),"Zero elapsed time does not alter audio volume")
	check(Design.mix_step(0,1,0.05)>0 and Design.mix_step(0,1,0.05)<1,"Crossfade starts gradually without instantaneous jumps")
	var one_second:=0.0
	for i in range(20):
		one_second=Design.mix_step(one_second,1,0.05)
	check(one_second>0.35 and one_second<0.7,"Sound zone transitions approach the target smoothly")
	var two_seconds:=one_second
	for i in range(20):
		two_seconds=Design.mix_step(two_seconds,1,0.05)
	check(two_seconds>one_second and two_seconds<1,"Crossfades approach target without overshoot")
	check(is_equal_approx(Design.mix_step(-20,200,100),1),"Invalid audio volume inputs remain clamped")
	check(is_equal_approx(Design.mix_step(0.75,0,-2),0.75),"Negative frame delta does not cause instability")
	var hotel:Dictionary=Design.zone_levels("hotel",0.7,0.6,true)
	var disco:Dictionary=Design.zone_levels("disco",0.7,0.6,true)
	var piste:Dictionary=Design.zone_levels("piste",0.7,0.6,true)
	check(float(disco.music)>float(hotel.music) and float(hotel.music)>float(piste.music),"Music adapts to disco, hotel and piste zones")
	check(float(disco.crowd)>float(hotel.crowd) and float(piste.wind)>float(hotel.wind),"NPC and wind layer emphasis follows the camera location")
	check(is_zero_approx(float(Design.zone_levels("disco",1,1,false).music)),"Turning off the radio mutes it even within loud nightlife zones")
	check(float(Design.zone_levels("unknown",1,1,true).wind)>0.0,"Unknown zones safely fall back to natural mountain ambience")
	check(not Design.license_policy("suno") and not Design.license_policy("soundcloud"),"External radio remains disabled without verified game rights")
	var radio:=Radio.new()
	root.add_child(radio)
	var prefs:=Preferences.new()
	prefs.music_genre="off"
	prefs.music_volume=0.65
	prefs.ambient_volume=0.45
	radio.preferences=prefs
	for name in ["music","music_alt"]:
		var p:=AudioStreamPlayer.new()
		p.name=name
		radio.add_child(p)
		radio.players[name]=p
	radio.set_genre("punk",true)
	check(radio.current_genre=="punk" and radio.preview_genre,"Jukebox can audition original punk synth sound without saving")
	radio.sync()
	check(radio.current_genre=="punk" and float(radio._level_targets.music)>0,"Preview does not get overwritten by the saved off preference")
	radio.set_genre("alpine",true)
	check(radio.current_genre=="alpine" and radio.preview_genre and radio._retiring_music!=null,"Choosing another genre starts music crossfade between dedicated players")
	radio.set_genre("off",false)
	check(radio.current_genre=="off" and not radio.preview_genre and is_zero_approx(float(radio._level_targets.music)),"Canceling preview restores actual saved radio silence immediately")
	prefs.music_genre="meditative"
	radio.sync()
	check(radio.current_genre=="meditative" and not radio.preview_genre,"Saving a station makes it the active normal playback mode")
	radio.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed>0 else 0)
