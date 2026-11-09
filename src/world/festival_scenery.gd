extends RefCounted
## Seasonal, non-colliding 3D village ambience tied to the OS date, not game time.
## The first art pass is deliberately lightweight and never edits world geometry.
const FestiveBuildings=preload("res://src/world/festive_buildings.gd")
const Calendar = preload("res://src/core/annual_festival.gd")
const Posters = preload("res://src/core/holiday_poster_catalog.gd")
const FestivalArt = preload("res://src/world/festival_art.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Foot = preload("res://src/core/foot_network.gd")
var store := Calendar.new()
var qa_date_override: Dictionary = {} # Only used by explicit visual QA tests.

func date_now() -> Dictionary:
	return qa_date_override if not qa_date_override.is_empty() else Calendar.device_now()
var root: Node3D
var clock_label: Label3D
var _world_key := ""
var _poll := 0.0
var _seconds := 0.0
var firework_nodes: Array = []
var poster_sites: Array = []
var poster_paths: Array = []

func hit_poster(at: Vector2) -> bool:
	if not at.is_finite():return false
	for site in poster_sites:
		if at.distance_to(site)<17.0:return true
	return false

## The on-screen preview must show the EXACT image on the tapped roadside board.
func poster_art_at(at: Vector2) -> String:
	if not at.is_finite():return ""
	for i in range(poster_sites.size()):
		if at.distance_to(poster_sites[i])<17.0:
			return str(poster_paths[i]) if i<poster_paths.size() else ""
	return ""

func _valid_place(view: Node3D, at: Vector2,clearance: float=9.0) -> bool:
	if not view.terrain.contains(at) or not Foot.free_of_buildings(at,view.model.buildings,clearance): return false
	if not view.piste_clear(at,clearance): return false
	for lift in view.model.lifts:
		var a:=Terrain.unpack(lift.bottom)
		var b:=Terrain.unpack(lift.top)
		if Geometry2D.get_closest_point_to_segment(at,a,b).distance_to(at)<15.0: return false
	for path in view._pedestrian_snapshot.get("links",[]):
		for index in range(1,path.points.size()):
			var distance: float=Geometry2D.get_closest_point_to_segment(at,Terrain.unpack(path.points[index-1]),Terrain.unpack(path.points[index])).distance_to(at)
			if distance<float(path.get("width",7))*.5+clearance:return false
	return true

func _free_decoration_site(view: Node3D, at: Vector2, clearance: float, occupied: Array) -> bool:
	if not _valid_place(view,at,clearance):return false
	for site in occupied:
		if at.distance_to(site.point)<clearance+float(site.radius):return false
	return true

func build(view: Node3D) -> void:
	if is_instance_valid(root): root.queue_free()
	root=Node3D.new()
	root.name="Winterfest Ambient Art"
	view.add_child(root)
	clock_label=null
	firework_nodes.clear()
	poster_sites.clear()
	poster_paths.clear()
	var now:=date_now()
	var stage:=Calendar.season(now)
	if Calendar.preview_poster(now): stage="november_poster"
	_world_key="%d:%s" % [int(now.get("year",0)),stage]
	if stage=="": return
	# Poster boards are visible throughout the corresponding campaign;
	# the Advent reward system itself remains disabled before December 1.
	_spawn_posters(view,stage)
	if stage=="november_poster":return
	_decorate_buildings(view,stage)
	var owned: Array=store.overview(now).owned
	# Central free seasonal ambience. Bought decors are additional objects.
	var schedule: Array=[
		{"kind":"tree","angle":0.0,"radius":62.0},
		{"kind":"snowman","angle":0.85,"radius":58.0},
		{"kind":"gifts","angle":1.7,"radius":67.0},
		{"kind":"lanterns","angle":2.5,"radius":62.0},
		{"kind":"market","angle":3.2,"radius":71.0},
		{"kind":"bell","angle":4.1,"radius":66.0},
		{"kind":"garlands","angle":4.8,"radius":60.0}
	]
	var extra: Dictionary={"gingerbread_lodge":"gingerbread_lodge","gift_workshop":"gift_workshop","winter_stage":"winter_stage","market_stall":"market_stall","tree":"tree","gifts":"gifts","star":"star","lanterns":"lanterns","garlands":"garlands","clock":"clock"}
	var k:=0
	for kind in owned:
		if not extra.has(kind): continue
		schedule.append({"kind":extra[kind],"angle":(float(k)+0.4)*TAU/6.0,"radius":91.0+float(k%2)*9.0})
		k+=1
	var meshes: Dictionary={}
	var occupied: Array=[]
	for item in schedule:
		var kind: String=item.kind
		# The countdown board is meaningful only at the year change.
		if kind in ["clock","winter_stage"] and stage not in ["new_year_eve","new_year"]: continue
		var center: Vector2=Terrain.BASE+Vector2.from_angle(float(item.angle))*float(item.radius)
		var clearance:=15.0 if kind in FestiveBuildings.KINDS else 9.0
		if not _free_decoration_site(view,center,clearance,occupied):
			var found:=false
			for attempt in range(64):
				var candidate: Vector2=Terrain.BASE+Vector2.from_angle(float(item.angle)+attempt*.23)*(float(item.radius)+20+float(attempt%6)*16)
				if _free_decoration_site(view,candidate,clearance,occupied):center=candidate;found=true;break
			if not found:continue
		occupied.append({"point":center,"radius":clearance})
		if not meshes.has(kind):
			var mesh: ArrayMesh=FestivalArt.make(kind,view.visual_style)
			mesh.surface_set_material(0,view._solid)
			meshes[kind]=mesh
		var node:=MeshInstance3D.new()
		node.set_meta("festival_kind",kind)
		node.set_meta("festival_clearance",clearance)
		node.mesh=meshes[kind]
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position=view.terrain.world(center,0.4)
		node.rotation.y=float(item.angle)
		root.add_child(node)
		if kind=="clock":
			clock_label=Label3D.new()
			clock_label.text="00:00:00"
			clock_label.font_size=42
			clock_label.pixel_size=0.016
			clock_label.outline_size=6
			clock_label.position=Vector3(0,9.7,0.85)
			node.add_child(clock_label)
	if stage in ["new_year_eve","new_year"] and int(now.get("hour",0))>=23 or stage=="new_year":
		var fx := FestivalArt.make("firework",view.visual_style)
		fx.surface_set_material(0,view._solid)
		for i in range(3):
			var obj:=MeshInstance3D.new()
			obj.mesh=fx
			obj.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			obj.position=view.terrain.world(Terrain.BASE+Vector2(i*24-24,-24),30.0+i*5)
			obj.scale=Vector3.ONE*1.7
			root.add_child(obj)
			firework_nodes.append(obj)
	_update_clock(now)

func _update_clock(now: Dictionary) -> void:
	if not is_instance_valid(clock_label): return
	var seconds:=Calendar.countdown(now)
	clock_label.text="%02d:%02d:%02d" % [seconds/3600,(seconds%3600)/60,seconds%60] if seconds>=0 else "00:00:00"

func update(view: Node3D, delta: float) -> void:
	_seconds+=maxf(0.0,delta)
	_poll+=maxf(0.0,delta)
	if _seconds>=1.0:
		_seconds=0.0
		_update_clock(date_now())
		for i in range(firework_nodes.size()):
			if is_instance_valid(firework_nodes[i]):
				firework_nodes[i].rotation.z+=0.06
				firework_nodes[i].scale=Vector3.ONE*(1.45+0.2*sin(Time.get_ticks_msec()*0.003+i))
	if _poll>=12.0:
		_poll=0.0
		var date:=date_now()
		var key:="%d:%s" % [int(date.get("year",0)),"november_poster" if Calendar.preview_poster(date) else Calendar.season(date)]
		if key!=_world_key: build(view)


## Ten static, compact PMDD images, with every word drawn in the current
## Godot language. No baked-in language, forced phone permissions or video.
func _poster_artworks(stage: String) -> Array:
	var available: Array=Posters.available(stage)
	available.shuffle()
	return available

func _spawn_posters(view: Node3D,stage: String) -> void:
	var originals: Array=_poster_artworks(stage)
	var art_mesh: ArrayMesh=FestivalArt.make("poster",view.visual_style)
	art_mesh.surface_set_material(0,view._solid)
	# Six roadside sites make a varied collection visible across a resort.
	for index in range(6):
		var at: Vector2=Vector2.INF
		for step in range(20):
			var angle: float=float(index)*TAU/6.0+float(step)*0.31
			var candidate: Vector2=Terrain.BASE+Vector2.from_angle(angle)*(73.0+float(step%6)*22.0)
			if _valid_place(view,candidate):
				at=candidate
				break
		if not at.is_finite():continue
		var artwork: String=str(originals[index%originals.size()]) if not originals.is_empty() else ""
		poster_sites.append(at)
		poster_paths.append(artwork)
		var board:=MeshInstance3D.new()
		board.mesh=art_mesh
		board.position=view.terrain.world(at,0.25)
		board.rotation.y=float(index)*TAU/6.0
		board.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(board)
		if not artwork.is_empty():
			var texture: Texture2D=load(artwork) as Texture2D
			if texture!=null:
				# Rigid, non-billboard 16:9 plane sits INSIDE the picture frame.
				# Neither source texture nor full-screen display is distorted.
				var quad:=QuadMesh.new()
				quad.size=Vector2(12.8,7.2)
				var material:=StandardMaterial3D.new()
				material.albedo_texture=texture
				material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
				material.cull_mode=BaseMaterial3D.CULL_DISABLED
				var picture:=MeshInstance3D.new()
				picture.mesh=quad
				picture.material_override=material
				picture.position=Vector3(0,4.4,0.48)
				picture.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				board.add_child(picture)
		# Language-dependent overlay remains above the artwork, never baked
		# into WebP. A thick dark outline keeps it readable on winter skies.
		var sign:=Label3D.new()
		sign.text=Posters.headline(stage,artwork)
		sign.set_meta("source_text",Posters.source_headline(stage,artwork))
		sign.font_size=39
		sign.pixel_size=0.016
		sign.outline_size=10
		sign.modulate=Color("fff4df")
		sign.outline_modulate=Color("12223b")
		sign.position=Vector3(0,6.60,0.60)
		sign.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		board.add_child(sign)

func _decorate_buildings(view: Node3D,stage: String) -> void:
	for building in view.model.buildings:
		var node:=MeshInstance3D.new()
		node.name="festive_building_"+str(building.id)
		node.set_meta("festive_building",int(building.id))
		node.mesh=FestiveBuildings.dressing(building.kind,int(building.get("level",1)),view.visual_style,stage)
		node.material_override=view._ink_material if view.visual_style=="monochrome" else view._solid
		node.position=view.terrain.world(Terrain.unpack(building.point))
		node.rotation.y=int(building.get("rotation",0))*PI*.5
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)

	if view.crew_life.lodge_point.is_finite():
		var staff_dressing:=MeshInstance3D.new()
		staff_dressing.mesh=FestiveBuildings.dressing("hotel",1,view.visual_style,stage)
		staff_dressing.material_override=view._ink_material if view.visual_style=="monochrome" else view._solid
		staff_dressing.position=view.terrain.world(view.crew_life.lodge_point)
		staff_dressing.set_meta("festive_staff_lodge",true)
		root.add_child(staff_dressing)
