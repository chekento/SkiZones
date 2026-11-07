extends SceneTree
## Actual Godot radio UI interaction and 16 SVG asset smoke test.
const Branding = preload("res://src/core/radio_branding.gd")
const Design = preload("res://src/core/audio_design.gd")
const Preferences = preload("res://src/core/preferences.gd")
var passed := 0
var failed := 0
func check(ok: bool, what: String) -> void:
	if ok: passed += 1; print("PASS ",what)
	else: failed += 1; push_error("FAIL "+what)

func _init() -> void: call_deferred("run")

func saved(path: String) -> RefCounted:
	var prefs:=Preferences.new()
	prefs.path=path
	prefs.load_from()
	return prefs

func run() -> void:
	check(Branding.valid_catalog(),"Every station has complete SVG branding and accurate metadata")
	check(Branding.BRANDS.size()==16 and Design.GENRES.size()==16,"15 offline presets plus hotel lobby asset, no duplicate SoundCloud preset")
	var identities:Dictionary={}
	for id in Branding.BRANDS:
		var spec:Dictionary=Branding.spec(str(id))
		var texture:Texture2D=Branding.logo(str(id))
		check(texture!=null and texture.get_width()>0 and texture.get_height()>0,"Imported station logo is a real usable texture: "+str(id))
		check(not identities.has(str(spec.logo)),"Brand icon path unique: "+str(id))
		identities[str(spec.logo)]=true
	var game:Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.paused=true
	game.set_process(false)
	game.view.set_process(false)
	# This suite renders the real radio UI; world rendering is covered separately.
	game.view.hide()
	game.preferences.path="user://radio-frontpanel-035.cfg"
	game.preferences.music_genre="alpine"
	game.preferences.sound_enabled=true
	game.preferences.master_volume=0.55
	game.preferences.music_volume=0.50
	game.audio.sync()
	var radio:Control=game.hud.jukebox
	radio.open()
	await process_frame
	check(radio.visible and radio.preset_buttons.size()==15,"All fifteen playable presets are actual in-radio buttons")
	check(radio.find_child("radio_station_grid",true,false) is HFlowContainer,"Station buttons wrap into accessible rows instead of clipping horizontally on Android")
	check(not radio.enabled.visible and not radio.genre_choice.visible and not radio.music_slider.visible,"No separate checkbox or duplicate tuner form is visible")
	check(radio.face.logo_texture!=null and radio.face.station_id=="alpine","Physical radio face displays first station artwork")
	check(radio.playing_label.custom_minimum_size.y>=60 and not radio.playing_label.text.is_empty(),"Current title retains readable height when phone labels wrap")
	check(radio.power_button.visible and radio.station_left.visible and radio.station_right.visible and radio.skip_button.visible,"All physical power, tuning and transport buttons are available")
	check(radio.power_button.icon != null and radio.station_left.icon != null and radio.station_right.icon != null and radio.skip_button.icon != null and radio.credits_button.icon != null, "Radio hardware uses imported, large original SVG control icons")
	check(radio.dial.custom_minimum_size.x >= 100 and radio.dial.focus_mode == Control.FOCUS_ALL, "Tuning wheel is a touch/keyboard accessible real UI control")
	var techno:Button=radio.preset_buttons["techno"]
	techno.pressed.emit()
	check(game.preferences.music_genre=="techno" and saved(game.preferences.path).music_genre=="techno","Tapping SnowBeat logo tunes radio and persists instantly")
	check(radio.face.station_id=="techno","Display switches to selected logo without another action")
	var previous:String=str(game.preferences.music_genre)
	radio.station_right.pressed.emit()
	check(game.preferences.music_genre!=previous and game.preferences.music_genre!="off","Forward tuning button changes to a different real station")
	radio.station_left.pressed.emit()
	check(game.preferences.music_genre==previous,"Backward tuning returns to original station")
	radio.dial._turn(1)
	check(game.preferences.music_genre!=previous,"Turning the real tuning wheel immediately selects another station")
	radio.dial._turn(-1)
	check(game.preferences.music_genre==previous,"Reverse tuning restores original station")
	var parent:Control=radio.volume_meters["master"].get_parent()
	var adjust:Button=parent.get_children().filter(func(v): return v is Button).back()
	var old_volume:float=game.preferences.master_volume
	adjust.pressed.emit()
	check(game.preferences.master_volume>old_volume and saved(game.preferences.path).master_volume==game.preferences.master_volume,"Master + button adjusts immediate, durable playback level")
	for key in ["music","ambient"]:
		var volume_row:Control=radio.volume_meters[key].get_parent()
		var minus:Button=volume_row.get_children().filter(func(v): return v is Button).front()
		var old:float=radio.music_slider.value if key=="music" else radio.ambience_slider.value
		minus.pressed.emit()
		var current:float=radio.music_slider.value if key=="music" else radio.ambience_slider.value
		check(current<old,"Real radio hardware adjusts "+key+" level without external controls")
	check(radio.volume_meters.size()==3 and radio.volume_readouts.size()==3,"All three mixer levels render on the radio")
	check(not radio.credits_label.visible,"Licence information is folded away by default")
	radio.credits_button.pressed.emit()
	check(radio.credits_label.visible and radio.credits_label.text.length()>10,"In-radio credit button opens actual track source inventory")
	radio.credits_button.pressed.emit()
	check(not radio.credits_label.visible,"Credits button closes the source inventory")
	radio.power_button.pressed.emit()
	check(not game.preferences.sound_enabled and not saved(game.preferences.path).sound_enabled and radio.skip_button.disabled,"Power off immediately saves, mutes and disables the skip key")
	radio.power_button.pressed.emit()
	check(game.preferences.sound_enabled and saved(game.preferences.path).sound_enabled,"Power on restores persistent radio power")
	game.audio._crossfade=1.0
	var index_before:Variant=game.audio.programme_position("techno").get("index",-1)
	radio.preset_buttons["techno"].pressed.emit()
	game.audio._crossfade=1.0
	var title_before:String=str(game.audio.now_playing().get("title",""))
	radio.skip_button.pressed.emit()
	check(str(game.audio.now_playing().get("title",""))!=title_before or int(game.audio.programme_position("techno").get("index",-1))!=int(index_before),"Skip button advances a real channel rather than being decorative")
	var after:String=JSON.stringify(game.model.snapshot())
	radio.close()
	radio.open()
	check(radio.face.station_id=="techno" and radio.enabled.button_pressed,"Reopening restores selected sender and power with no confirmation button")
	check(radio.face.track_title == str(game.audio.now_playing().get("title","")), "Hardware LCD uses real live programme title, not placeholder visual art")
	check(JSON.stringify(game.model.snapshot())==after,"Radio choices do not mutate career files or resort cash")
	# The complete radio belongs to a scrollable window on small phones.
	# The frame, close action and active art may never be outside a safe viewport.
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	for resolution in [Vector2i(360,740),Vector2i(420,860),Vector2i(740,360)]:
		root.content_scale_size=Vector2i.ZERO
		root.size=resolution
		await process_frame
		await process_frame
		radio.window._fit()
		await process_frame
		var window_rect:Rect2=radio.window.get_global_rect()
		check(window_rect.position.x>=0 and window_rect.position.y>=0 and window_rect.end.x<=float(resolution.x)+1 and window_rect.end.y<=float(resolution.y)+1,
			"Radio hardware frame stays on-screen at "+str(resolution))
		check(radio.window.close_button.is_visible_in_tree() and radio.window.size.x>200 and radio.window.size.y>250,
			"Compact radio retains reachable close action and scrollable controls at "+str(resolution))
		var screenshot:String="res://build/qa/radio-035-%dx%d.png" % [resolution.x,resolution.y]
		var capture:Error=root.get_texture().get_image().save_png(screenshot)
		check(capture==OK,"Radio UI visual QA screenshot saved: "+str(resolution))
	game.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
