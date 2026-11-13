extends SceneTree
const Terrain=preload("res://src/core/terrain.gd")
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func run()->void:
	var model:RefCounted=load("res://src/core/resort.gd").new()
	model.new_game(true);model.campaign.mode="free"
	var view:Node3D=load("res://src/world/resort_view.gd").new()
	root.add_child(view);view.setup(model);view.set_process(false)
	var piste:Dictionary=model.pistes[0]
	var building:Dictionary={}
	for fraction in [0.35,0.45,0.55,0.65]:
		var center:Vector2=model.terrain.point_on_path(piste.points,fraction)
		for offset in [Vector2(32,0),Vector2(-32,0),Vector2(40,0),Vector2(-40,0)]:
			for rotation in range(4):
				var site:Dictionary=model.preview_building("restaurant",center+offset,rotation)
				if site.ok and site.connection.has("piste"):
					if model.build_building("restaurant",center+offset,rotation).ok:building=model.buildings[-1];break
			if not building.is_empty():break
		if not building.is_empty():break
	check(not building.is_empty(),"World fixture has an actual legal piste-side restaurant")
	if not building.is_empty():
		var original:Dictionary=model.pedestrian_layout()
		var count:int=original.links.size()
		view.rebuild()
		check(original.links.size()==count,"Rendering paths never mutates the model's routing layout")
		var links:Array=view._pedestrian_snapshot.links.filter(func(link):return str(link.from)=="piste-stop-%d" % int(building.id))
		check(links.size()==1,"A real compacted-snow access path is included in the rendered world")
		if links.size()==1:
			var stop:Dictionary=model.PisteStops.connection(model,building)
			check(links[0].points==stop.points,"Rendered access matches the exact visitor walking route")
			check(view.foot_mesh.mesh.get_surface_count()>0,"Access layout produces actual ground mesh geometry")
		view.focus=Terrain.unpack(building.point);view.zoom=135;view.set_camera_mode(1);view._update_camera()
		for i in range(3):await process_frame
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://build/qa")
			check(root.get_texture().get_image().save_png("res://build/qa/piste-restaurant-access-042.png")==OK,"Rendered piste restaurant screenshot is available for review")
	view.queue_free();await process_frame
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
