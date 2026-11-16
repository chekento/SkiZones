extends SceneTree
## Exercise the shipping render sampler against an actual triangulated ground
## plane, snow relief and rotated park modules, without a viewport or UI.
const Resort = preload("res://src/core/resort.gd")
const Ground = preload("res://src/world/ground_surface.gd")
const SnowRender = preload("res://src/world/snow_render.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const Motion = preload("res://src/core/ski_motion.gd")
const Features = preload("res://src/core/piste_features.gd")
const Pose = preload("res://src/world/skier_pose_042.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("PASS ", label)
	else: failed += 1; push_error("FAIL " + label)

func _init() -> void: call_deferred("run")

func run() -> void:
	var model := Resort.new()
	var ground := Ground.new()
	var builder := SurfaceTool.new(); builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(-100,10,-300),Vector3(100,10,-300),Vector3(-100,10,300),Vector3(100,10,-300),Vector3(100,10,300),Vector3(-100,10,300)]:
		builder.add_vertex(point)
	ground.configure(builder.commit())
	var snow := SnowRender.new()
	var piste := {"id":991,"points":[[0,-200],[0,200]],"length":0.0,"width":28.0,"level":1,"features":[]}
	piste.length = model.terrain.polyline_length(piste.points)
	Snow.ensure(piste)
	snow.configure([piste])
	var leg := {"kind":"ski","id":991,"start_fraction":0.0,"end_fraction":1.0}
	var guest := {"id":7,"ability":2,"loops":0,"duration":10.0,"sport":"ski","ski_motion":[[0.0,0.0,1,0.0],[1.0,1.0,1,0.0]],"walk_ranges":[],"traffic_lateral":4.0}
	var fraction := 0.5
	var center: Vector2 = model.terrain.point_on_path(piste.points,fraction)
	# Put a rail directly over the climbing centerline: hikers must stay on
	# the snow rather than acquiring the rail's elevation or carving style.
	piste.features = [{"kind":"rail","fraction":fraction,"lateral":0.0}]
	for sport in Motion.SPORTS:
		guest.sport = sport
		var pose := Pose.frame(model,ground,snow,piste,guest,leg,5.0)
		check(Vector2(pose.position.x,pose.position.z).distance_to(center)<0.00001,"Hiking follows the simulated centerline: "+sport)
		check(is_zero_approx(pose.lean) and is_zero_approx(pose.yaw),"Hiking has no carving lean or side-to-side yaw: "+sport)
		check(is_equal_approx(pose.position.y,10.0+Snow.mesh_height(piste,fraction,0.0)-0.05),"Hiking stays below the rail on actual ground/snow: "+sport)
	guest.ski_motion = []
	leg.motion = [[0.0,0.0,1,0.0],[1.0,1.0,1,0.0]]
	var fallback := Pose.frame(model,ground,snow,piste,guest,leg,5.0)
	check(Pose.hiking(guest,leg,5.0) and Vector2(fallback.position.x,fallback.position.z).distance_to(center)<0.00001,"Legacy leg motion also selects the climbing pose when the personal profile is empty")
	leg.erase("motion")
	check(not Pose.hiking(guest,leg,5.0),"An ordinary downhill run keeps its personal carving style")
	guest.traffic_lateral = 0.0
	# Snow-only slope on flat triangulated ground. The old renderer sampled
	# terrain alone for orientation and left the skis level across this ridge.
	piste.features = []
	for row in range(Snow.rows(piste)):
		for lane in range(Snow.LANES+1):
			piste.surface[row*(Snow.LANES+1)+lane] = float(row)/float(Snow.rows(piste)-1)*0.55
	var snow_pose := Pose.frame(model,ground,snow,piste,guest,leg,5.0)
	check(snow_pose.pitch < -0.0002,"Skis pitch into real snow relief even when triangulated ground is flat")
	# A rotated module crossed with a curved personal lane: compare to three
	# independently sampled visible heights, each with its own lateral offset.
	piste.features = [{"kind":"ramp","fraction":0.5,"lateral":0.0,"rotation":30.0,"scale":1.0}]
	for sport in Motion.SPORTS:
		guest.sport = sport
		var expected := Motion.frame(model.terrain,piste,guest.id,guest.ability,0.5,guest.loops,0.0,1.0,[],sport,0.0)
		var heights: Array[Vector3] = []
		for i in range(3):
			var f: float = [0.497,0.5,0.503][i]
			var point: Vector2 = [expected.before,expected.point,expected.ahead][i]
			var path: Dictionary = model.terrain.path_frame(piste.points,f,piste.length)
			var lateral: float = (point-path.point).dot(path.direction.normalized().orthogonal())
			heights.append(Vector3(point.x,10.0+snow.height_offset(piste,point,f,lateral)-0.05+Features.height_offset(piste,f,lateral,guest.ability),point.y))
		var actual := Pose.frame(model,ground,snow,piste,guest,leg,5.0)
		var pitch := atan2(heights[0].y-heights[2].y,Vector2(heights[2].x-heights[0].x,heights[2].z-heights[0].z).length())
		check(actual.position.distance_to(heights[1])<0.00001,"Personal equipment remains on the sampled rotated module: "+sport)
		check(absf(actual.pitch-pitch)<0.00001,"Ramp tilt follows the personal line and snow at both ends: "+sport)
	guest.ability = 0
	var beginner := Pose.frame(model,ground,snow,piste,guest,leg,5.0)
	var beginner_point := Vector2(beginner.position.x,beginner.position.z)
	piste.features = []
	check(beginner.position.distance_to(Pose.surface(model.terrain,ground,snow,piste,beginner_point,0.5,0))<0.00001,"A beginner gains no jump height from an unsuitable module while taking its real bypass")
	guest.ability = 2
	# Endpoints and split-route endpoints must stay on the actual leg, even
	# when the sampling cache asks for a time just outside its interval.
	leg.start_fraction = 0.2; leg.end_fraction = 0.7
	for elapsed in [-0.12,0.0,10.0,10.12]:
		var actual := Pose.frame(model,ground,snow,piste,guest,leg,elapsed)
		var endpoint: Vector2 = model.terrain.point_on_path(piste.points,0.2 if elapsed<=0.0 else 0.7)
		check(Vector2(actual.position.x,actual.position.z).distance_to(endpoint)<0.00001,"Split-leg position stays at its own endpoint at elapsed %.2f" % elapsed)
		check(actual.position.is_finite() and is_finite(actual.pitch) and is_finite(actual.yaw),"Finite endpoint pose at elapsed %.2f" % elapsed)
	# Pure render sampling must never change persisted state or RNG.
	var snapshot: String = JSON.stringify([piste,guest,leg,model.snapshot()])
	var repeated := Pose.frame(model,ground,snow,piste,guest,leg,4.5)
	check(repeated==Pose.frame(model,ground,snow,piste,guest,leg,4.5),"A paused scene produces the identical pose on repeated frames")
	check(snapshot==JSON.stringify([piste,guest,leg,model.snapshot()]),"Render sampling leaves guest, piste, finances and save data unchanged")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
