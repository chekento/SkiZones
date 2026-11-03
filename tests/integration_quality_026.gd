extends SceneTree
const Preferences=preload("res://src/core/preferences.gd")
const Features=preload("res://src/core/piste_features.gd")
const Motion=preload("res://src/core/ski_motion.gd")
const Terrain=preload("res://src/core/terrain.gd")
var passed := 0
var failed := 0
var game: Node

func _init() -> void:call_deferred("run")

func check(ok: bool, title: String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)

func capture(name_value: String) -> void:
	for frame in range(4):await process_frame
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	check(root.get_texture().get_image().save_png("res://build/qa/"+name_value+".png")==OK,"Capture "+name_value)

func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.paused=true
	game.set_process(false)
	game.view.set_process(false)
	game.apply_language("de")
	game.preferences.path="user://integration026-display.cfg"
	game.preferences.music_genre="off"
	game.preferences.sound_enabled=true
	game.preferences.master_volume=1.0
	game.audio.set_active(true)
	game.view._process(0)
	check(game.audio.players.size()==4,"One shared audio engine owns music, wind, crowd and machinery")
	check(game.audio.population(game.view.focus)==0,"An empty resort does not invent a crowd")
	game.audio._process(0.5)
	check(game.audio.players.crowd.stream_paused,"Empty places have no fake background conversations")
	var box: Control=game.hud.jukebox
	game.hud.show_radio()
	check(box.visible and not game.simulation_running() and game.hud.blocks_map(Vector2(10,10)),"Both radio entry points open the same input-blocking jukebox")
	var index: int=box.Design.GENRES.find("techno")
	box.genre_choice.select(index)
	box.genre_choice.item_selected.emit(index)
	game.audio._process(1.0)
	check(game.audio.current_genre=="techno" and game.preferences.music_genre=="off","Live genre preview survives polling without changing saved preferences")
	box.master_slider.value=0.0
	check(game.audio.players.values().all(func(player):return not player.playing or player.stream_paused),"A zero master slider gives exact silence on every channel")
	box.master_slider.value=0.8
	box.enabled.button_pressed=false
	check(game.audio.players.values().all(func(player):return not player.playing or player.stream_paused),"Global audio mute also silences music previews")
	box.enabled.button_pressed=true
	await capture("integration-026-jukebox")
	box.close()
	check(game.audio.current_genre=="off" and game.audio.preview_settings.is_empty() and game.preferences.master_volume==1.0,"Cancel restores the saved audio state")
	game.audio.set_active(false)
	game.audio._process(1.0)
	check(game.audio.players.values().all(func(player):return not player.playing or player.stream_paused),"Inactive application audio remains suspended across processing")
	game.audio.set_active(true)
	game.audio._process(1.0)
	check(not game.audio.players.wind.stream_paused,"Returning to the resort resumes the ambient mix")
	var prefs:=Preferences.new()
	prefs.path="user://integration026-legacy-radio.cfg"
	var old:=ConfigFile.new()
	old.set_value("audio","radio_station","piano")
	old.set_value("audio","sound_volume",40)
	old.set_value("audio","sound_enabled",false)
	old.save(prefs.path)
	prefs.load_from()
	check(prefs.music_genre=="classical" and is_equal_approx(prefs.master_volume,0.4) and not prefs.sound_enabled,"Previous prototype radio preferences migrate to the shared mixer")
	var home: Vector2=game.view.crew_life.lodge_point
	check(home.is_finite(),"The starter resort has a valid staff accommodation site")
	var clear := true
	if home.is_finite():
		for entry in game.view.forest.available:
			if Vector2(entry.point).distance_to(home)<30:clear=false
	check(clear and game.view._extra_clearings.size()==1,"Forest, wildlife and detail candidates leave staff housing free")
	var piste: Dictionary=game.model.pistes[0]
	piste.features=[{"kind":"ramp","fraction":0.5,"lateral":0.0}]
	var continuous := true
	for skier in range(1,9):
		var last: Vector2=Motion.position(game.model.terrain,piste,skier,0,0.5-18.0/piste.length)
		for sample in range(1,145):
			var fraction: float=0.5+(-18.0+sample*0.25)/piste.length
			var next: Vector2=Motion.position(game.model.terrain,piste,skier,0,fraction)
			continuous=continuous and next.distance_to(last)<1.0
			last=next
	check(continuous,"Novices bypass ramps continuously while their carving wave changes sides")
	piste.erase("features")
	game.hud.set_map_focus(true)
	var previous := {"focus":game.view.focus,"yaw":game.view.yaw,"pitch":game.view.pitch_degrees,"zoom":game.view.zoom}
	game.start_cinematic_tour()
	check(game.view.tour.active and game.hud.cinema_mode,"Cinematic tour starts in the same resort with its dedicated controls")
	game.view.tour.step(game.view,9.999)
	# The tour caps frame delta; set the clock near a boundary deliberately.
	game.view.tour.elapsed=9.999
	game.view.tour.step(game.view,0.0)
	var before: float=game.view.yaw
	game.view.tour.step(game.view,0.002)
	check(absf(game.view.yaw-before)<0.01,"Camera orientation remains continuous between hotspots")
	await capture("integration-026-cinematic-tour")
	game.stop_cinematic_tour()
	check(not game.hud.cinema_mode and not game.view.tour.active and game.view.focus==previous.focus and is_equal_approx(game.view.yaw,previous.yaw) and is_equal_approx(game.view.zoom,previous.zoom),"Leaving the tour restores the exact camera configuration")
	game.hud.medal_cabinet.open()
	check(game.hud.medal_cabinet.visible and game.hud.blocks_map(Vector2(10,10)),"The medal archive blocks construction and camera gestures")
	await capture("integration-026-medal-archive")
	game.hud.medal_cabinet.close()
	check(game.paused,"Closing the medal archive preserves an already paused resort")
	game.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d passed; %d failed"%[passed,failed])
	quit(1 if failed else 0)
