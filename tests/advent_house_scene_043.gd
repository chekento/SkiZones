extends SceneTree
## This exercises an actual rendered mountain and touch-screen camera ray,
## not just AdventHouse's mathematical door index.
const AdventHouse=preload("res://src/world/advent_house_043.gd")
const Terrain=preload("res://src/core/terrain.gd")
var game:Node
var passed:int=0
var failed:int=0
func _init()->void:call_deferred("run")
func check(ok:bool,msg:String)->void:
	if ok:passed+=1;print("PASS ",msg)
	else:failed+=1;push_error("FAIL "+msg)

func capture(style:String)->void:
	if DisplayServer.get_name()=="headless":return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	var img:Image=root.get_texture().get_image()
	check(img!=null and img.save_png("res://build/qa/advent-house-043-"+style+".png")==OK,"Actual Advent house screenshot: "+style)

func run()->void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.paused=true
	game.set_process(false)
	game.view.set_process(false)
	var scene=game.view.festival_scene
	scene.store.path="user://advent_house_043_scene.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.store.path))
	scene.qa_date_override={"year":2026,"month":11,"day":30,"hour":12,"minute":0,"second":0}
	scene.build(game.view)
	check(scene.advent_house==null,"No Advent house before December 1")
	scene.qa_date_override={"year":2026,"month":12,"day":6,"hour":12,"minute":0,"second":0}
	for style in ["alpine","comic","monochrome"]:
		game.view.set_visual_style(style)
		scene.build(game.view)
		var house:Node3D=scene.advent_house
		check(is_instance_valid(house),style+" generates an actual 24-door resort building")
		if not is_instance_valid(house):continue
		check(house.get_meta("festival_clearance",0.0)==20.0 and house.get_meta("festival_kind","")=="advent_house",style+" records a non-overlapping holiday building footprint")
		var camera:Camera3D=game.view.camera
		# Move the actual game camera to the front, then project individual
		# door centers onto the phone screen and pick them with screen rays.
		camera.global_position=house.to_global(Vector3(0,17,96))
		camera.look_at(house.to_global(Vector3(0,15,0)),Vector3.UP)
		for number in [1,6,12,24]:
			var surface:Vector3=house.to_global(AdventHouse.door_center(number))
			var tap:Vector2=camera.unproject_position(surface)
			check(scene.pick_advent_door(camera,tap)==number,style+" camera touch selects numbered door "+str(number))
		await capture(style)
	check(scene.store.claim(6,{"year":2026,"month":12,"day":6}).ok,"December 6 door opens in real annual archive")
	scene.build(game.view)
	check(scene.advent_house!=null and (scene.advent_house.get_node("door_6") as Node3D).rotation.y< -1.0,"Rebuilding the real resort leaves a claimed 3D door open")
	scene.qa_date_override={"year":2027,"month":1,"day":2}
	scene.build(game.view)
	check(scene.advent_house==null,"Advent house disappears after January 1 without modifying the career")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.store.path))
	game.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
