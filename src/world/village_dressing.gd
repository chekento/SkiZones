extends RefCounted
## Purely visual auto-dressing along already generated real pedestrian links.
## No new gameplay routes, fake roads or collisions are created.
const Lines=preload("res://src/world/line_art.gd")
const Art=preload("res://src/world/alpine_art.gd")
const Terrain=preload("res://src/core/terrain.gd")
const Foot=preload("res://src/core/foot_network.gd")
const Styles=preload("res://src/core/visual_styles.gd")
const MAX_PROPS := 34
var root: Node3D

static func prop_mesh(kind: String, style: String) -> ArrayMesh:
	if style=="monochrome":return Lines.new().prop(kind)
	var a:=Art.new()
	var c: Dictionary=Styles.detail_tints(style)
	var metal:=Color(str(c.metal))
	var wood:=Color(str(c.wood))
	var snow:=Color(str(c.snow))
	var accent:=Color(str(Styles.ui_palette(style).accent))
	match kind:
		"bench":
			for x in [-1.8,1.8]:
				a.box(Vector3(x,0.7,0),Vector3(.45,1.4,1.0),wood)
			a.box(Vector3(0,1.5,0),Vector3(4.5,.4,1.35),wood)
			a.box(Vector3(0,2.4,-.55),Vector3(4.5,1.6,.4),wood)
			a.box(Vector3(0,1.79,0),Vector3(4.7,.15,1.4),snow)
		"lamp":
			a.link(Vector3.ZERO,Vector3(0,8,0),.18,metal)
			a.box(Vector3(0,7.55,0),Vector3(2.8,.35,1.0),wood)
			for x in [-1.15,1.15]:
				a.sphere(Vector3(x,7.12,.5),.65,accent)
		"sculpture":
			a.box(Vector3(0,.65,0),Vector3(4.5,1.3,4.5),snow)
			for n in range(3):
				var angle: float=float(n)*TAU/3.0
				var at:=Vector3(cos(angle)*1.8,2.1+float(n)*1.8,sin(angle)*1.8)
				a.box(at,Vector3(1.8,3.5,1.3),accent if n%2==0 else metal,Vector3(0,angle,.12))
			a.sphere(Vector3(0,6.2,0),1.1,accent)
		"arch":
			for x in [-2.6,2.6]:
				a.box(Vector3(x,2.5,0),Vector3(.65,5,0.75),wood)
				a.box(Vector3(0,5.2,0),Vector3(6.5,.72,1.3),metal)
				a.box(Vector3(0,5.65,0),Vector3(6.8,.22,1.4),snow)
			for x in [-1.5,0,1.5]: a.sphere(Vector3(x,4.75,.85),.34,accent)
	return a.finish()

static func can_place(view: Node3D, at: Vector2) -> bool:
	if not view.terrain.contains(at):return false
	if not Foot.free_of_buildings(at,view.model.buildings,8):return false
	if not view.piste_clear(at,10):return false
	for lift in view.model.lifts:
		if Geometry2D.get_closest_point_to_segment(at,Terrain.unpack(lift.bottom),Terrain.unpack(lift.top)).distance_to(at)<12.0: return false
	return true

func build(view: Node3D) -> void:
	if is_instance_valid(root):
		root.queue_free()
	root=Node3D.new()
	root.name="Automatic Village Dressing (non-colliding)"
	view.add_child(root)
	var meshes: Dictionary={}
	var used: Dictionary={}
	var placed:=0
	var links: Array=view._pedestrian_snapshot.get("links",[])
	# Existing path placement is authoritative. We decorate its edges, never
	# invent movement links or change the guest navigation graph.
	for link in links:
		if placed>=MAX_PROPS: break
		var points: Array=link.get("points",[])
		if points.size()<2:continue
		var a: Vector2=Terrain.unpack(points[0])
		var b: Vector2=Terrain.unpack(points[-1])
		if a.distance_to(b)<20.0 or a.distance_to(b)>180.0:continue
		var mid: Vector2=Terrain.unpack(points[int(points.size()/2)])
		var side: Vector2=(b-a).normalized().orthogonal()
		var at: Vector2=mid+side*(float(link.get("width",7.0))*0.5+7.0)
		var cell: Vector2i=Vector2i(roundi(at.x/25.0),roundi(at.y/25.0))
		if used.has(cell) or not can_place(view,at):continue
		used[cell]=true
		var kind: String=["bench","lamp","arch","sculpture"][placed%4]
		if not meshes.has(kind):
			var baked: ArrayMesh=prop_mesh(kind,view.visual_style)
			baked.surface_set_material(0,view._solid)
			meshes[kind]=baked
		var model:=MeshInstance3D.new()
		model.mesh=meshes[kind]
		model.position=view.terrain.world(at,0.28)
		model.rotation.y=(b-a).angle()
		model.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(model)
		placed+=1
	# An art sculpture by the civic building indicates that every new village
	# really has a distinguishable historic centre.
	for building in view.model.buildings:
		if str(building.kind)!="town_hall":continue
		var center: Vector2=Terrain.unpack(building.point)
		for offset in [Vector2(25,20),Vector2(-25,20)]:
			var at: Vector2=center+offset
			if not can_place(view,at):continue
			if not meshes.has("sculpture"):
				var decor: ArrayMesh=prop_mesh("sculpture",view.visual_style)
				decor.surface_set_material(0,view._solid)
				meshes["sculpture"]=decor
			var node:=MeshInstance3D.new()
			node.mesh=meshes["sculpture"]
			node.position=view.terrain.world(at,0.28)
			root.add_child(node)

