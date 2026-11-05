extends SceneTree
const Design=preload("res://src/core/audio_design.gd")
## Real radio + HUD integration, not just sample banner events.
var passed:=0
var failed:=0
func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("PASS ",label)
	else: failed+=1; push_error("FAIL "+label)
func _init() -> void: call_deferred("run")
func run() -> void:
	var game:Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.paused=true
	var hud:CanvasLayer=game.hud
	hud.hide_menu()
	var banner=hud.achievement_overlay
	banner.clear_all()
	banner.history.clear()
	game.preferences.sound_enabled=true
	game.preferences.master_volume=1.0
	game.preferences.music_volume=0.65
	game.preferences.music_genre="alpine"
	game.audio.sync()
	await process_frame
	var playing:Dictionary=game.audio.now_playing()
	hud._announce_radio_track()
	check(str(playing.genre)=="alpine" and not str(playing.title).is_empty(),"Radio reports actual Alpine track")
	check(banner.history.size()==1 and str(banner.history[0].title)==str(playing.title),"HUD announces actual recorded title")
	hud._announce_radio_track()
	check(banner.history.size()==1,"Repeated HUD refresh never duplicates current song")
	game.preferences.music_genre="techno"
	game.audio.sync()
	await process_frame
	hud._announce_radio_track()
	check(banner.history.size()==2 and banner.history[0].kind=="music","Station switch announces changed track once")
	game.preferences.sound_enabled=false
	game.audio.sync()
	hud._announce_radio_track()
	check(banner.history.size()==2 and hud._last_announced_song=="","Mute disables further notices")
	game.preferences.sound_enabled=true
	game.preferences.music_genre="off"
	game.audio.sync()
	hud._announce_radio_track()
	check(banner.history.size()==2,"Turned-off radio does not notify")
	# Removed SoundCloud channel IDs migrate to a playable offline neighbor.
	# Never reintroduce the external account as a selectable radio station.
	# An obsolete SoundCloud ID is a migration input, not an actual in-game
	# station. Preferences tests verify restore, while this one verifies the
	# unavailable remote ID can never be selected as an online broadcaster.
	game.preferences.music_genre="erg0sphere"
	game.audio.sync()
	await process_frame
	hud._announce_radio_track()
	check(Design.genre_valid("erg0sphere")=="space" and Design.EXTERNAL_STATIONS.is_empty(),
		"Removed SoundCloud IDs only resolve to an offline station, never external playback")
	hud.management.open()
	var found:=false
	for i in range(hud.management.tabs.get_tab_count()):
		if hud.management.tabs.get_tab_title(i)=="Meldungen": found=true
	check(found,"Notification archive is discoverable from resort office")
	banner.set_visual_style("monochrome")
	banner.size=Vector2(420,860)
	banner.announce({"kind":"mission","title":"Lift reparieren","detail":"Braunlage"})
	banner.set_reserved_top(250.0)
	banner._reflow()
	check(banner.card.position.y>=240 and banner.card.position.y+banner.card.size.y<=860,"Mobile banner clears scenario status and stays on screen")
	check(banner.mouse_filter==Control.MOUSE_FILTER_IGNORE and banner.card.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Touch input passes through the message banner")
	game.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
