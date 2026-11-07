extends SceneTree
## Real rendering regression for the 0.39 radio redesign. No endless preset
## strip is allowed to widen the receiver or hide power/transport controls.
const Design=preload("res://src/core/audio_design.gd")
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	if ok:passed+=1;print("PASS ",message)
	else:failed+=1;push_error("FAIL "+message)
func settle() -> void:
	for i in range(4):await process_frame
func run() -> void:
	var game:Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.start_game(true)
	game.set_process(false)
	game.view.set_process(false)
	game.view.hide()
	game.preferences.path="user://radio-responsive-039.cfg"
	game.preferences.sound_enabled=true
	game.preferences.music_genre="alpine"
	game.audio.sync()
	var radio:Control=game.hud.jukebox
	radio.open()
	await settle()
	check(radio.preset_buttons.size()==15 and radio.preset_grid.get_child_count()==15,
		"Every offline station is inside the actual wrapped grid")
	check(radio.preset_grid is GridContainer and radio.preset_grid.columns>=1,
		"The station strip has become a genuine layout container")
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	for resolution in [Vector2i(360,740),Vector2i(420,860),Vector2i(740,360),Vector2i(1280,800),Vector2i(1536,864)]:
		root.content_scale_size=Vector2i.ZERO
		root.size=resolution
		await settle()
		radio.window._fit()
		radio._fit_radio()
		await settle()
		var width:float=float(resolution.x)
		var frame:Rect2=radio.window.get_global_rect()
		check(frame.position.x>=0 and frame.end.x<=width+1,
			"Radio fits viewport horizontally: "+str(resolution))
		var power:Rect2=radio.power_button.get_global_rect()
		check(radio.power_button.is_visible_in_tree() and power.size.x>=60.0 and power.position.x>=0.0 and power.end.x<=width+1.0,
			"The real power switch remains visible in header: "+str(resolution))
		check(radio.preset_grid.columns<15 and radio.preset_grid.columns>=1,
			"Preset buttons wrap to multiple rows: "+str(resolution))
		var horizontal_fits:=true
		for station in Design.GENRES:
			if station=="off":continue
			var button:Button=radio.preset_buttons[str(station)]
			var rect:Rect2=button.get_global_rect()
			horizontal_fits=horizontal_fits and rect.position.x>=-1 and rect.end.x<=width+1
			horizontal_fits=horizontal_fits and button.custom_minimum_size.y>=68.0
		check(horizontal_fits,"All station logos fit the available width and retain touch targets: "+str(resolution))
		var left:Rect2=radio.station_left.get_global_rect()
		var right:Rect2=radio.station_right.get_global_rect()
		var channel:Rect2=radio.station_counter.get_global_rect()
		check(radio.station_left.is_visible_in_tree() and radio.station_right.is_visible_in_tree() and radio.window.close_button.is_visible_in_tree()
			and left.position.x>=0 and right.end.x<=width+1 and channel.end.x<=width+1,
			"Forward, backward, readout and close controls stay within viewport: "+str(resolution))
		var same_mixer:=true
		for channel in ["master","music","ambient"]:
			var meter:ProgressBar=radio.volume_meters[channel]
			var buttons:Array=meter.get_parent().get_children().filter(func(child):return child is Button)
			same_mixer=same_mixer and buttons.size()==2
			if buttons.size()==2:
				same_mixer=same_mixer and buttons[0].custom_minimum_size==buttons[1].custom_minimum_size
		check(same_mixer,"Volume minus and plus match in size and layout: "+str(resolution))
		var image_path:String="res://build/qa/radio-responsive-039-%dx%d.png"%[resolution.x,resolution.y]
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(image_path)==OK,
			"Rendered real radio screenshot for "+str(resolution))
	# Changing channel never affects game construction, saves or career money.
	var before:String=JSON.stringify(game.model.snapshot())
	radio.preset_buttons["space"].pressed.emit()
	check(game.preferences.music_genre=="space","Reflowed station logos still tune instantly")
	radio.power_button.pressed.emit()
	check(not game.preferences.sound_enabled,"Visible power button immediately switches off the radio")
	radio.power_button.pressed.emit()
	check(game.preferences.sound_enabled,"Visible power button restores the radio")
	check(JSON.stringify(game.model.snapshot())==before,
		"Changing radio power/station does not mutate career saves")
	game.queue_free()
	await settle()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
