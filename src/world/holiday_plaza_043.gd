extends RefCounted
## A calendar-driven visual celebration anchored to an existing, collision-safe
## market decoration. Show it only when real simulated pedestrians approach.
## Decorative hosts are never counted as visitors or added to game saves.
const Art=preload("res://src/world/alpine_art.gd")
const Styles=preload("res://src/core/visual_styles.gd")
const Holidays=preload("res://src/core/holiday_guest_rhythm_043.gd")
const AUDIENCE_RADIUS:=95.0

static func event_for(date:Dictionary)->String:
	return Holidays.event_for(date)

static func nearby_visitors(guests:Array,positions:Dictionary,site:Vector3,radius:float=AUDIENCE_RADIUS)->int:
	if not site.is_finite() or not is_finite(radius) or radius<=0.0:return 0
	var visitors:int=0
	for guest in guests:
		if not guest is Dictionary:continue
		if str(guest.get("phase",""))!="moving" or int(guest.get("incident",-1))>=0:continue
		var legs:Array=guest.get("route",{}).get("legs",[])
		var step:int=int(guest.get("leg",-1))
		if step<0 or step>=legs.size():continue
		var kind:String=str(legs[step].get("kind",""))
		if kind not in ["walk","visit"]:continue
		var point:Variant=positions.get(int(guest.get("id",-1)))
		if not point is Vector3 or not point.is_finite():continue
		if Vector2(point.x,point.z).distance_to(Vector2(site.x,site.z))<=radius:
			visitors+=1
	return visitors

static func make(style:String,event:String,solid:Material)->Node3D:
	var node:=Node3D.new()
	node.name="holiday_market_celebration_043"
	node.set_meta("festival_kind","holiday_market_celebration")
	node.set_meta("festival_event",event)
	var art:=Art.new()
	var snow:=Color(str(Styles.detail_tints(style).snow))
	var wood:=Color(str(Styles.detail_tints(style).wood))
	var accent:=Color(str(Styles.ui_palette(style).accent))
	var red:=Color("929292") if style=="monochrome" else Color("ba4354")
	var gold:=Color("d6d6d6") if style=="monochrome" else Color("e8c883")
	if event=="nikolaus":
		# A non-interactive Nikolaus host, not an artificial resort guest.
		# Boots, beard, large coat, festive cap, sack and staff are all original.
		for side in [-1.0,1.0]:
			art.box(Vector3(side*0.55,0.45,0),Vector3(0.68,0.9,0.98),wood.darkened(0.35))
			art.link(Vector3(side*1.1,3.2,0),Vector3(side*1.55,1.7,0.2),0.34,red)
		art.sphere(Vector3(0,2.7,0),1.45,red,Vector3(0.85,1.10,0.68))
		art.box(Vector3(0,2.1,1.05),Vector3(2.25,0.28,0.35),gold)
		art.sphere(Vector3(0,4.25,0.25),0.76,Color("e7c5a5"))
		art.sphere(Vector3(0,3.9,0.85),0.67,snow,Vector3(0.93,0.84,0.48))
		art.cone(Vector3(-0.15,5.0,0.05),0.93,1.7,red,0.27)
		art.sphere(Vector3(-0.45,5.8,0.05),0.25,snow)
		art.sphere(Vector3(-1.52,2.2,-0.85),0.84,wood.lightened(0.22))
		art.link(Vector3(1.58,0,0.45),Vector3(1.58,5.7,0.45),0.12,gold)
		art.sphere(Vector3(1.58,5.7,0.45),0.26,gold)
	else:
		# Christmas family gathering: lit star, small gift stacks, warm trim.
		art.link(Vector3(0,0,0),Vector3(0,6.2,0),0.28,wood)
		for i in range(10):
			var angle:float=float(i)*TAU/10.0
			var distance:float=1.7 if i%2==0 else 0.83
			art.link(Vector3(0,6.3,0),Vector3(cos(angle)*distance,6.3+sin(angle)*distance,0),0.15,gold)
		art.sphere(Vector3(0,6.3,0),0.45,accent)
		for i in range(3):
			var x:float=-1.9+float(i)*1.9
			art.box(Vector3(x,0.65,0),Vector3(1.55,1.3,1.3),red if i%2==0 else wood)
			art.box(Vector3(x,0.65,0),Vector3(0.20,1.44,1.44),gold)
			art.box(Vector3(x,0.65,0),Vector3(1.69,1.44,0.22),gold)
	var model:=MeshInstance3D.new()
	model.name="celebration_sculpture"
	model.mesh=art.finish()
	model.mesh.surface_set_material(0,solid)
	model.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(model)
	node.visible=false
	return node

static func animate(node:Node3D,visible:bool,elapsed:float)->void:
	if not is_instance_valid(node):return
	node.visible=visible
	if not visible:return
	# Small idle sway for parallax while the actual visiting guests walk by.
	node.rotation.y=sin(elapsed*0.45)*0.11
	node.scale=Vector3.ONE*(1.0+0.025*sin(elapsed*1.3))
