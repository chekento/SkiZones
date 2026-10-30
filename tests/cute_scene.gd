extends SceneTree
## Review actual game geometry and batching, then capture its winter diorama.
const Art = preload("res://src/world/alpine_art.gd")
var passed := 0
var failed := 0
func _init() -> void:call_deferred("run")
func check(ok: bool,title: String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func capture(game: Node,name_value: String) -> void:
	for i in range(5):await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/"+name_value+".png")
func run() -> void:
	var builder := Art.new();builder.soft_box(Vector3.ZERO,Vector3(4,3,2),Color.WHITE)
	var mesh := builder.finish();var arrays := mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL];var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var valid := true
	for i in range(0,indices.size(),3):
		var a:Vector3=vertices[indices[i]];var b:Vector3=vertices[indices[i+1]];var c:Vector3=vertices[indices[i+2]]
		valid=valid and a.is_finite() and (b-a).cross(c-a).dot(normals[indices[i]]) < -0.0001
	check(valid and indices.size()==132,"Rounded assets have closed, consistently outward-facing chamfers in one surface")
	check(Art.new().pine_distant().get_faces().size()<Art.new().pine().get_faces().size()*0.4,"Distant snowy firs retain inexpensive geometry instead of drawing close-up snow pillows")
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.start_game(true);game._showcase();game.paused=true;game.view.set_quality("high");game.hud.set_map_focus(true)
	game.view.focus=Vector2(80,90);game.view.zoom=580;game.view.yaw=0.30;game.view.set_camera_pitch(38)
	await capture(game,"cute-resort-0100")
	check(game.view._walkers.multimesh.use_custom_data and game.view.visitor_mesh.material_override==game.view._people_material,"All real visitors keep one shared material with individual cloth tint and neutral faces")
	var bounded:=true
	# One decision group can now contain up to five independently drawn people.
	# Keep the memory bound, and require that visible instances fit its buffer.
	for node in [game.view.visitor_mesh,game.view._walkers,game.view._riders,game.view._cabin_riders,game.view._climbers]:
		var batch: MultiMesh=node.multimesh
		bounded=bounded and batch.instance_count>=game.model.MAX_GUESTS and batch.instance_count<=game.model.MAX_GUESTS*5 and batch.visible_instance_count>=0 and batch.visible_instance_count<=batch.instance_count
	check(bounded and game.model.guests.size()>20,"The decorated populated resort preserves every guest within fixed-size instance batches")
	game.view.focus=Vector2(165,275);game.view.zoom=245;game.view.yaw=0.38;game.view.set_camera_pitch(42)
	await capture(game,"cute-village-0100")
	game.hud.root.hide();game.view.focus=Vector2(90,190);game.view.zoom=420;game.view.yaw=0.40;game.view.set_camera_pitch(30)
	await capture(game,"cute-menu-panorama-0100")
	game.hud.root.show();game.hud.show_menu();await capture(game,"cute-menu-0100")
	game.queue_free();await process_frame
	print("CUTE SCENE: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
