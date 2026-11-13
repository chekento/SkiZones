extends SceneTree
## Synthetic comparison display of the actual shipping meshes, not a playable
## resort or evidence of a physical Android frame-rate measurement.
const Modules=preload("res://src/core/park_modules_042.gd")
const Art=preload("res://src/world/alpine_art.gd")
var passed:=0
var failed:=0
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func run()->void:
	var scene:=Node3D.new();root.add_child(scene)
	var world:=WorldEnvironment.new();scene.add_child(world)
	world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("cedfe9")
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=0.7
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-25,0);scene.add_child(light)
	var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(65,115,115);camera.look_at(Vector3(0,0,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=145;camera.far=500;camera.current=true
	var ground:=MeshInstance3D.new();scene.add_child(ground)
	var plane:=PlaneMesh.new();plane.size=Vector2(150,180);ground.mesh=plane
	var snow:=StandardMaterial3D.new();snow.albedo_color=Color("e7eff4");ground.material_override=snow
	var material:=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=0.9
	for index in range(Modules.KINDS.size()):
		var node:=MeshInstance3D.new();scene.add_child(node);node.mesh=Art.new().piste_feature(str(Modules.KINDS[index]));node.material_override=material
		node.position=Vector3((index%4-1.5)*25,0.1,(index/4-2)*31)
		check(node.mesh.get_surface_count()==1 and node.mesh.get_aabb().size.y>0,"Gallery contains the real 3D model: "+str(Modules.KINDS[index]))
		var label:=Label3D.new();scene.add_child(label);label.text=str(Modules.NAMES[index]);label.position=node.position+Vector3(0,0.2,14);label.rotation_degrees.x=-70;label.font_size=48;label.pixel_size=0.035;label.modulate=Color("243b4d");label.no_depth_test=true
	for i in range(4):await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://build/qa")
		check(root.get_texture().get_image().save_png("res://build/qa/snowpark-twenty-modules-042.png")==OK,"Rendered comparison of twenty real meshes is saved")
	scene.queue_free();await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
