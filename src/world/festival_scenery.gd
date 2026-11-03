extends RefCounted
## Seasonal, non-colliding 3D village ambience tied to the OS date, not game time.
## The first art pass is deliberately lightweight and never edits world geometry.
const Calendar = preload("res://src/core/annual_festival.gd")
const FestivalArt = preload("res://src/world/festival_art.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Foot = preload("res://src/core/foot_network.gd")
var store := Calendar.new()
var root: Node3D
var clock_label: Label3D
var _world_key := ""
var _poll := 0.0
var _seconds := 0.0
var firework_nodes: Array = []

func _valid_place(view: Node3D, at: Vector2) -> bool:
	if not view.terrain.contains(at) or not Foot.free_of_buildings(at,view.model.buildings,8): return false
	if not view.piste_clear(at,9): return false
	for lift in view.model.lifts:
		var a:=Terrain.unpack(lift.bottom)
		var b:=Terrain.unpack(lift.top)
		if Geometry2D.get_closest_point_to_segment(at,a,b).distance_to(at)<15.0: return false
	return true

func build(view: Node3D) -> void:
	if is_instance_valid(root): root.queue_free()
	root=Node3D.new()
	root.name="Winterfest Ambient Art"
	view.asset_root.add_child(root)
	clock_label=null
	firework_nodes.clear()
	var now:=Calendar.device_now()
	var stage:=Calendar.season(now)
	_world_key="%d:%s" % [int(now.get("year",0)),stage]
	if stage=="": return
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
	var extra: Dictionary={"tree":"tree","gifts":"gifts","star":"star","lanterns":"lanterns","garlands":"garlands","clock":"clock"}
	var k:=0
	for kind in owned:
		if not extra.has(kind): continue
		schedule.append({"kind":extra[kind],"angle":(float(k)+0.4)*TAU/6.0,"radius":91.0+float(k%2)*9.0})
		k+=1
	var meshes: Dictionary={}
	for item in schedule:
		var kind: String=item.kind
		# The countdown board is meaningful only at the year change.
		if kind=="clock" and stage not in ["new_year_eve","new_year"]: continue
		var center: Vector2=Terrain.BASE+Vector2.from_angle(float(item.angle))*float(item.radius)
		if not _valid_place(view,center): continue
		if not meshes.has(kind):
			var mesh: ArrayMesh=FestivalArt.make(kind,view.visual_style)
			mesh.surface_set_material(0,view._solid)
			meshes[kind]=mesh
		var node:=MeshInstance3D.new()
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
		_update_clock(Calendar.device_now())
		for i in range(firework_nodes.size()):
			if is_instance_valid(firework_nodes[i]):
				firework_nodes[i].rotation.z+=0.06
				firework_nodes[i].scale=Vector3.ONE*(1.45+0.2*sin(Time.get_ticks_msec()*0.003+i))
	if _poll>=12.0:
		_poll=0.0
		var date:=Calendar.device_now()
		var key:="%d:%s" % [int(date.get("year",0)),Calendar.season(date)]
		if key!=_world_key: build(view)
