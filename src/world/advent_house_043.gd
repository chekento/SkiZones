extends RefCounted
## A real, numbered, touch-selectable 24-door Advent building.
## World art is cosmetic; annual_festival.gd owns the single persistent reward
## ledger, so selecting the same door from UI and 3D cannot pay twice.
const Art=preload("res://src/world/alpine_art.gd")
const Styles=preload("res://src/core/visual_styles.gd")
const DOOR_COUNT:=24
const COLUMNS:=4
const DOOR_WIDTH:=4.9
const DOOR_HEIGHT:=2.55
const STEP_X:=6.15
const STEP_Y:=3.35
const FRONT_Z:=8.35

static func door_center(number:int)->Vector3:
	if number<1 or number>DOOR_COUNT:return Vector3.INF
	var column:int=(number-1)%COLUMNS
	var row:int=(number-1)/COLUMNS
	return Vector3((float(column)-1.5)*STEP_X,22.3-float(row)*STEP_Y,FRONT_Z)

static func door_at(local:Vector3)->int:
	if not local.is_finite() or absf(local.z-FRONT_Z)>0.45:return 0
	for number in range(1,DOOR_COUNT+1):
		var pos:Vector3=door_center(number)
		if absf(local.x-pos.x)<=DOOR_WIDTH*0.5 and absf(local.y-pos.y)<=DOOR_HEIGHT*0.5:
			return number
	return 0

static func pick(house:Node3D,camera:Camera3D,screen:Vector2)->int:
	if not is_instance_valid(house) or not is_instance_valid(camera):return 0
	var front:Vector3=house.to_global(Vector3(0,0,FRONT_Z))
	var normal:Vector3=house.global_transform.basis.z.normalized()
	var plane:=Plane(normal,normal.dot(front))
	var hit:Variant=plane.intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
	if hit==null:return 0
	return door_at(house.to_local(hit))

static func _door_material(style:String,opened:bool,special:bool)->StandardMaterial3D:
	var material:=StandardMaterial3D.new()
	material.roughness=0.7
	material.albedo_color=Color("73999c") if opened else Color("c79a5e") if special else Color("8b5849")
	if style=="monochrome":material.albedo_color=Color("b5b5b5") if opened else Color("777777")
	elif style=="piste_map":material.albedo_color=material.albedo_color.darkened(0.22)
	return material

static func create(style:String,claimed:Array,solid:Material)->Node3D:
	var root:=Node3D.new()
	root.name="advent_house_24"
	root.set_meta("festival_kind","advent_house")
	var tone:Dictionary=Styles.detail_tints(style)
	var accent:Color=Color(str(Styles.ui_palette(style).accent))
	var snow:Color=Color(str(tone.snow))
	var wood:Color=Color(str(tone.wood))
	var a:=Art.new()
	# Tall timber facade, contrasting cornices, snow-covered roof and steps.
	a.box(Vector3(0,13.9,0),Vector3(29.1,27.8,16.5),wood.lightened(0.20))
	a.box(Vector3(0,27.9,0),Vector3(31.5,1.5,18.0),snow)
	a.roof(33.0,31.0,19.0)
	for level in range(7):
		a.box(Vector3(0,float(level)*3.35+2.1,8.35),Vector3(28.5,0.23,0.32),accent.darkened(0.35))
	for x in [-13.7,13.7]:
		a.box(Vector3(x,13.9,8.35),Vector3(0.42,26.8,0.7),accent)
	a.box(Vector3(0,1.0,10.4),Vector3(19.0,2.0,5.4),snow)
	for x in [-11.8,11.8]:
		a.cone(Vector3(x,31.8,1.1),1.1,3.2,accent,0.35)
	var model:=MeshInstance3D.new()
	model.name="advent_timber_roof"
	model.mesh=a.finish()
	model.mesh.surface_set_material(0,solid)
	model.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(model)
	for number in range(1,DOOR_COUNT+1):
		var center:Vector3=door_center(number)
		var pivot:=Node3D.new()
		pivot.name="door_"+str(number)
		pivot.set_meta("advent_door_number",number)
		pivot.position=center-Vector3(DOOR_WIDTH*0.5,0,0)
		root.add_child(pivot)
		var leaf:=MeshInstance3D.new()
		leaf.name="advent_door_leaf"
		var box:=BoxMesh.new()
		box.size=Vector3(DOOR_WIDTH,DOOR_HEIGHT,0.28)
		leaf.mesh=box
		leaf.position=Vector3(DOOR_WIDTH*0.5,0,0)
		leaf.material_override=_door_material(style,claimed.has(number),number in [6,24])
		leaf.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(leaf)
		var number_plate:=Label3D.new()
		number_plate.name="advent_number_"+str(number)
		number_plate.text=str(number)
		number_plate.font_size=50
		number_plate.pixel_size=0.012
		number_plate.outline_size=7
		number_plate.modulate=Color("e5e5e5") if style=="monochrome" else Color("f8f7e7")
		number_plate.position=Vector3(DOOR_WIDTH*0.5,0,0.19)
		pivot.add_child(number_plate)
		if claimed.has(number):pivot.rotation.y=-1.15
	return root

static func reveal(house:Node3D,number:int)->void:
	if number<1 or number>DOOR_COUNT or not is_instance_valid(house):return
	var pivot:Node3D=house.get_node_or_null("door_"+str(number))
	if pivot==null or pivot.rotation.y< -1.0:return
	var leaf:=pivot.get_node_or_null("advent_door_leaf") as MeshInstance3D
	if leaf!=null:leaf.material_override=_door_material("alpine",true,number in [6,24])
	if pivot.is_inside_tree():
		var tween:Tween=pivot.create_tween()
		tween.tween_property(pivot,"rotation:y",-1.15,0.45).set_trans(Tween.TRANS_SINE)
	else:
		pivot.rotation.y=-1.15
