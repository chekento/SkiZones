extends SceneTree
## Verify atmospheric changes on the actual 3D resort scene without extra overlay.
const Styles = preload("res://src/core/visual_styles.gd")

var passed := 0
var failed := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	if ok: passed += 1; print("PASS ",title)
	else: failed += 1; push_error("FAIL "+title)

func capture(kind: String) -> void:
	if DisplayServer.get_name()=="headless":return
	for i in range(2): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/qa"))
	var png: Image=root.get_texture().get_image()
	check(png.save_png("res://build/qa/weather-033-"+kind+".png")==OK,"Rendered weather "+kind)

func run() -> void:
	var game: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.set_process(false)
	game.view.set_process(false)
	game.paused=true
	var view: Node3D=game.view
	var base: Array=[]
	var sky: Array=[]
	var weather_names: Array=["clear","snow","fog","storm","thaw"]
	for index in range(5):
		game.model.weather_index=index
		view._update_atmosphere()
		base.append(view._environment.fog_density)
		sky.append(str(view._environment.sky.sky_material.sky_top_color))
		check(view._environment.fog_density>0 and view._sun.light_energy>0,"All five conditions have visible light and limited positive fog")
		check(view._snow.emitting==(index in [1,3]),"Only snowfall and storm spawn snow particles: "+weather_names[index])
		await capture(weather_names[index])
	check(base[2]>base[3] and base[3]>base[1] and base[1]>base[4] and base[4]>base[0],"Fog, storm, snowfall, thaw and clear are distinctly ordered by atmospheric density")
	check(sky[0]!=sky[1] and sky[1]!=sky[2] and sky[2]!=sky[3] and sky[3]!=sky[4],"Every weather condition applies a different sky tint")
	game.model.weather_index=1
	view._update_atmosphere()
	var drifting: Vector3=view._snow.direction
	game.model.weather_index=3
	view._update_atmosphere()
	check(view._snow.direction.x>drifting.x+0.2 and view._snow.initial_velocity_max>10.0,"Storm snow visibly gusts faster and diagonally")
	view.set_quality("economy")
	check(view._snow.amount<=100,"Economy graphics cap CPU storm flakes to 100")
	view.effects_enabled=false
	view._update_atmosphere()
	check(not view._snow.emitting,"Effects-disabled mode keeps weather simulation while turning snow particles off")
	view.visual_style="monochrome"
	view._update_atmosphere()
	var grey: Color=view._environment.sky.sky_material.sky_top_color
	check(absf(grey.r-grey.g)<0.03 and absf(grey.g-grey.b)<0.03,"Monochrome sky remains neutral grey in storm")
	game.queue_free()
	await process_frame
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
