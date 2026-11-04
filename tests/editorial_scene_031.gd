extends SceneTree
const Radio=preload("res://src/core/audio_design.gd")
const Newspaper=preload("res://src/core/newspaper.gd")
var passed:=0
var failed:=0
var game: Node
func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("PASS ",label)
	else: failed+=1; push_error("FAIL "+label)
func capture(label: String) -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	check(root.get_texture().get_image().save_png("res://build/qa/"+label+".png")==OK,"Rendered "+label)
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.set_process(false)
	game.paused=false
	var saved: Dictionary=game.model.snapshot()
	game.hud.show_seasonal_poster()
	await process_frame
	check(game.hud.seasonal_poster.visible and game.hud.blocks_map(Vector2(400,300)) and not game.simulation_running(),"Poster blocks gameplay and pauses simulation")
	var before: float=game.view.yaw
	var rotate:=InputEventKey.new()
	rotate.pressed=true; rotate.keycode=KEY_Q
	game._input(rotate)
	check(is_equal_approx(game.view.yaw,before),"Poster blocks camera shortcuts")
	await capture("winter-poster-031")
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not game.hud.seasonal_poster.visible and not game.hud.menu.visible,"Android Back closes poster and returns to resort")
	game.hud.show_seasonal_poster()
	var escape:=InputEventKey.new()
	escape.pressed=true; escape.keycode=KEY_ESCAPE
	game._input(escape)
	check(not game.hud.seasonal_poster.visible and game.model.snapshot()==saved,"Escape closes poster without changing career")
	var advertised: Dictionary={}
	for day in range(1,Radio.GENRES.size()+1):
		game.model.day=day
		for spot in Newspaper.radio_spots(game.model): advertised[str(spot.id)]=true
	check(advertised.size()==Radio.GENRES.size()-1+Radio.CONTEXT_STATIONS.size(),"Daily newspaper schedule promotes every registered channel")
	var press: Dictionary={"id":game.model.next_id,"kind":"printing_press","point":[60,300],"enabled":true,"name":"Druckerei","visits":0,"revenue":0.0,"level":1,"cost":0}
	game.model.next_id+=1; game.model.buildings.append(press); game.model.achievements=[4,5,8]
	game.model._invalidate()
	game.hud.experience.open(int(press.id))
	await process_frame
	check(game.hud.experience.visible and not game.simulation_running(),"Newspaper opens as a paused interior")
	await capture("editorial-newspaper-031")
	var stored_genre: String=game.preferences.music_genre
	game.hud.experience._open_radio_ad("techno")
	check(not game.hud.experience.visible and game.hud.jukebox.visible and game.audio.current_genre=="techno" and game.preferences.music_genre==stored_genre,"Radio advert previews its exact station without persisting settings")
	game.hud.jukebox.close()
	check(game.preferences.music_genre==stored_genre,"Closing advertised preview restores saved radio")
	game.queue_free()
	await process_frame
	await process_frame
	print("EDITORIAL SCENE: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
