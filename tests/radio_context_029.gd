extends SceneTree
## SkiZones 0.34: privacy-friendly offline hotel radio and mobile-safe achievements.
const Radio=preload("res://src/world/resort_audio.gd")
const Design=preload("res://src/core/audio_design.gd")
const Preferences=preload("res://src/core/preferences.gd")
const Toast=preload("res://src/ui/achievement_toast.gd")
var passed:=0
var failed:=0

func check(ok: bool, name: String) -> void:
	if ok:
		passed+=1
		print("PASS ",name)
	else:
		failed+=1
		push_error("FAIL "+name)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	check(Design.GENRES.size()==16,"Fifteen genuine offline radio channels plus off")
	check(Design.CONTEXT_STATIONS==["hotel_lobby"],"Exclusive Hotel Lobby channel has an isolated context")
	check(Design.EXTERNAL_STATIONS.is_empty() and "ska_album" not in Design.GENRES and "erg0sphere" not in Design.GENRES,"Both external artist placeholders are removed from station selection")
	check(Design.genre_valid("ska_album")=="apres" and Design.genre_valid("erg0sphere")=="space","Legacy saved artist selections migrate to suitable working offline stations")
	var radio:=Radio.new()
	root.add_child(radio)
	var prefs:=Preferences.new()
	prefs.music_genre="alpine"
	prefs.sound_enabled=true
	prefs.music_volume=0.7
	prefs.master_volume=1.0
	radio.setup(null,prefs)
	check(radio.station_track_count("hotel_lobby")>=16,"Hotel Lobby has sixteen indexed Ogg titles")
	check(radio.station_track_count("atmospherics")>=15,"Atmospherics has fifteen indexed and documented CC0 titles")
	check(radio.station_track_count("mountain_sunrise")>=15 and radio.station_track_count("lodge_lofi")>=15,"Two new mountain-oriented mood channels")
	check(radio.current_genre=="alpine","Player starts with saved station")
	radio.set_context_station("hotel_lobby")
	check(radio.current_genre=="hotel_lobby" and radio.now_playing().context=="hotel_lobby","Hotel UI overrides radio without altering preferences")
	check(prefs.music_genre=="alpine","Hotel context does not persist to saved station")
	radio.set_context_station("")
	check(radio.current_genre=="alpine" and radio.now_playing().context=="","Hotel exit restores original soundtrack")
	prefs.sound_enabled=false
	radio.set_context_station("hotel_lobby")
	check(is_zero_approx(float(radio._targets.music)),"Hotel music respects global mute")
	radio.set_context_station("")
	prefs.sound_enabled=true
	prefs.music_genre="ska_album"
	radio.sync()
	check(radio.current_genre=="apres" and float(radio._targets.music)>0.0,"Old Ska preset retunes to real offline Après-Ski music")
	prefs.music_genre="erg0sphere"
	radio.sync()
	check(radio.current_genre=="space","Old ERG0SPHERE preset retunes to genuine local Cosmic Drift")
	check(radio.station_track_count("ska_album")==0 and radio.station_track_count("erg0sphere")==0,"Deleted stations never expose phantom or external tracks")
	var toast:=Toast.new()
	root.add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var headline: String = "MEIN ENORM LANGES ACHIEVEMENT MIT WICHTIGEN INFORMATIONEN, DIE NIEMALS ABGESCHNITTEN WERDEN DÜRFEN"
	toast.announce({"kind":"achievement","title":headline,"detail":"Lange Beschreibung und Rangfortschritt müssen vollständig lesbar bleiben","reward":250})
	for resolution in [Vector2(320,320),Vector2(480,320),Vector2(640,360),Vector2(720,450),Vector2(1280,720),Vector2(360,780)]:
		toast.size=resolution
		toast._reflow()
		var r: Rect2=toast.card.get_rect()
		print("UI_BOUNDS|%s|%s|minimum=%s|anchor=%s" % [resolution,r,toast.card.get_combined_minimum_size(),toast.card.anchor_right])
		check(r.position.x>=0 and r.end.x<=resolution.x+1.0 and r.position.y>=0 and r.end.y<=resolution.y+1.0,"Achievement card remains inside %s" % resolution)
	check(toast.headline.text.replace("\n"," ")==headline and toast.headline.autowrap_mode==TextServer.AUTOWRAP_OFF,"Achievement title is reflowed without losing any words")
	check(toast.mouse_filter==Control.MOUSE_FILTER_IGNORE and toast.card.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Digital milestone does not block gameplay taps")
	toast.queue_free()
	radio.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed>0 else 0)
