extends SceneTree
## Controlled real-renderer scene using shipping terrain/snow shaders and assets.
## It verifies spatial behaviour, not full-resort FPS or physical-display perception.
const Depth = preload("res://src/world/perceptual_depth.gd")
const Mountain = preload("res://src/core/mountain.gd")
const Relief = preload("res://src/world/terrain_relief.gd")
const Art = preload("res://src/world/alpine_art.gd")
const Assets = preload("res://src/world/style_assets.gd")
const SnowRender = preload("res://src/world/snow_render.gd")
var passed := 0
var failed := 0

func _init() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ", label)
	else: failed += 1; push_error("FAIL " + label)

func capture(name_value: String) -> Image:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png("res://build/qa/pmdd-042-" + name_value + ".png") == OK, "Real renderer capture: " + name_value)
	return image

func run() -> void:
	check(DisplayServer.get_name() != "headless", "Visual acceptance requires a real rendering surface")
	if DisplayServer.get_name() == "headless": quit(1); return
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	var scene := Node3D.new(); root.add_child(scene)
	var mountain := Mountain.new()
	# Compact QA crop; production uses the complete actual map bounds.
	mountain.bounds = Rect2(-750,-1500,1500,1900)
	var environment := WorldEnvironment.new(); scene.add_child(environment)
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("bdcfdf")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dcebf7")
	environment.environment.ambient_light_energy = 0.72
	var light := DirectionalLight3D.new(); scene.add_child(light)
	light.rotation_degrees = Vector3(-48,-35,0); light.light_energy = 0.9
	var builder := SurfaceTool.new(); builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-800, 800, 40):
		for z in range(-1800, 500, 40):
			for offset in [Vector2(0,0),Vector2(0,40),Vector2(40,0),Vector2(40,0),Vector2(0,40),Vector2(40,40)]:
				builder.set_color(Color("e5eff7"))
				builder.add_vertex(mountain.world(Vector2(x,z)+offset))
	builder.generate_normals()
	var ground := MeshInstance3D.new(); ground.mesh = builder.commit(); scene.add_child(ground)
	var relief := Relief.material(); relief.set_shader_parameter("contours", false)
	ground.material_override = relief
	var material := StandardMaterial3D.new(); material.vertex_color_use_as_albedo = true
	for i in range(30):
		var tree := MeshInstance3D.new(); scene.add_child(tree)
		tree.mesh = Art.new().tree_variant("alpine", i%5)
		tree.material_override = material
		tree.position = mountain.world(Vector2(-240 + (i%6)*85, 180 - (i/6)*170))
	for i in range(3):
		var house := MeshInstance3D.new(); scene.add_child(house)
		house.mesh = Assets.building("restaurant", 1, Color("bd624a"), "alpine")
		house.material_override = material
		house.position = mountain.world(Vector2(-75 + i*70, -90 - i*85))
	var snow := SnowRender.new()
	var piste := {"id":990,"points":[[-110,-600],[-90,-300],[-130,40]],"length":650.0,"width":30.0}
	snow.configure([piste])
	var piste_node := MeshInstance3D.new(); scene.add_child(piste_node)
	piste_node.mesh = snow.build(mountain,piste)
	piste_node.material_override = snow.update(piste).material
	var depth := Depth.new(); depth.build(scene,mountain)
	depth.configure(Color("cfdfed"),1.0,2,2,true)
	depth.set_camera_context(true,false,true,2)
	var camera := Camera3D.new(); scene.add_child(camera)
	camera.fov = 46; camera.near = 0.5; camera.far = 15000; camera.current = true
	var target := mountain.world(Vector2(0,-350),40)
	camera.position = mountain.world(Vector2(220,350),170); camera.look_at(target)
	for frame in range(8): await process_frame
	for layer in range(3):
		check(depth.layers[layer].multimesh.get_instance_transform(3).is_equal_approx(depth.anchors[layer*8+3]), "GPU-side layer %d retains its intended world transform" % layer)
	var camera_before := camera.transform
	var anchored: Array[Transform3D] = depth.anchors.duplicate()
	var image := await capture("depth-before-pan")
	var still := await capture("depth-still")
	check(image.get_data() == still.get_data(), "Static camera has stable pixels without automatic drift or pulsing")
	var points: Array[Vector3] = []
	var screens: Array[Vector2] = []
	for distance_value in [300,600,1200]:
		var point: Vector3 = camera.global_position - camera.global_basis.z * distance_value
		points.append(point); screens.append(camera.unproject_position(point))
	camera.position += camera.basis.x * 25.0
	var movement: Array[float] = []
	for i in range(points.size()): movement.append(camera.unproject_position(points[i]).distance_to(screens[i]))
	check(movement[0] > movement[1]*1.8 and movement[1] > movement[2]*1.8, "Actual camera translation produces stronger parallax at nearer depths")
	await capture("depth-after-pan")
	check(depth.anchors == anchored and depth.builds == 1, "Moving the viewer neither moves nor rebuilds a depth anchor")
	camera.transform = camera_before
	depth.set_camera_context(true,true,true,2)
	await capture("planning-clear")
	check(not depth.root.visible, "Construction view can remove atmospheric strata")
	camera.position = mountain.world(Vector2(-105,35),18) + Vector3(10,0,24)
	camera.look_at(mountain.world(Vector2(-120,0),0.5))
	var detailed := await capture("snow-detail")
	relief.set_shader_parameter("perceptual_snow",false); snow.set_depth_detail(false)
	var plain := await capture("snow-detail-off")
	check(detailed.get_data() != plain.get_data(), "Shipping terrain and piste shaders expose camera-dependent snow facets")
	var hidden := MeshInstance3D.new(); scene.add_child(hidden)
	hidden.mesh = SphereMesh.new(); hidden.material_override = depth.layers[0].material_override
	hidden.position = mountain.world(Vector2(-120,0),-100)
	hidden.scale = Vector3(50,10,50)
	var occluded := await capture("terrain-occlusion")
	check(plain.get_data() == occluded.get_data(), "Terrain depth testing completely occludes an atmospheric volume below the ground")
	scene.queue_free(); await process_frame; await process_frame
	print("RESULT: %d passed; %d failed" % [passed,failed]); quit(1 if failed else 0)
