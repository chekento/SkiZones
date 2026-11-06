extends SceneTree
const Surfaces = preload("res://src/world/walk_surfaces.gd")
const Wear = preload("res://src/world/foot_wear.gd")
var passed := 0
var failed := 0
class View:
	extends Node3D
	var focus := Vector2.ZERO
	var zoom := 100.0
	var quality_tier := 0
	var _pedestrian_snapshot := {}
	func ground_position(at: Vector2, offset: float = 0.0) -> Vector3:
		return Vector3(at.x,offset,at.y)
	func surface_position(at: Vector2) -> Vector3:
		return Vector3(at.x,0.8+at.y*0.03,at.y)
func check(ok: bool, label: String) -> void:
	if ok: passed+=1; print("PASS ",label)
	else: failed+=1; push_error("FAIL "+label)
func _init() -> void: call_deferred("run")
func run() -> void:
	var view:=View.new()
	root.add_child(view)
	var layout: Dictionary={"areas":[{"center":Vector2.ZERO,"radius":2.0},{"center":Vector2(12,0),"radius":1.2}],"links":[{"points":[[0,0],[6,3],[12,0]],"width":2.0}]}
	for wear in [false,true]:
		var immediate: ArrayMesh=Surfaces.new().build(view,layout,wear)
		var staged:=Surfaces.new()
		staged.start(layout,wear)
		var slices:=0
		while not staged.advance(view,1): slices+=1
		var mesh: ArrayMesh=staged.result()
		check(slices>10 and mesh.get_faces()==immediate.get_faces(),"Incremental and immediate meshes have identical geometry, wear="+str(wear))
		check(mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]==immediate.surface_get_arrays(0)[Mesh.ARRAY_COLOR],"Budgeted updates preserve snow edges and surface colours")
		if wear:
			var above:=true
			for vertex in mesh.get_faces(): above=above and absf(vertex.y-view.surface_position(Vector2(vertex.x,vertex.z)).y-0.045)<0.0001
			check(above,"Incremental trails follow every point of the raised, sloping plaza")
	var snow:=Wear.new()
	view.add_child(snow)
	snow.setup()
	check(snow.import_state([[0,0,40,1.0,0.0],[1,0,40,1.0,0.0]]),"Existing five-field persisted wear is accepted")
	snow.update_visuals(view,1.1)
	check(snow._trail_builder!=null and snow._trail.mesh==null,"New trail geometry is scheduled instead of blocking one full render frame")
	snow.reset()
	check(snow._trail_builder==null and snow._trail.mesh==null and snow.export_state().is_empty(),"Changing resorts cancels partial geometry and clears the previous snow")
	for tick in range(45): snow.sample_guest(1,Vector3(0 if tick%2 else 2,0,0),tick,0)
	check(Wear.valid_state(snow.export_state()),"Opposite walking directions never cancel into an invalid saved orientation")
	snow.free(); view.free()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
