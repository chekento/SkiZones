extends RefCounted
## Purely visual Santa hats on real walking/visiting guests and actual family
## poses. No seasonal guest spawns, simulation changes or save-schema fields.
const Art=preload("res://src/world/alpine_art.gd")
const Holidays=preload("res://src/core/holiday_guest_rhythm_043.gd")
const MAX_VISIBLE:=96
var node:=MultiMeshInstance3D.new()

static func eligible(guest:Dictionary,positions:Dictionary,event:String)->bool:
	if event not in ["nikolaus","christmas_eve","christmas_day","boxing_day"]:return false
	if not positions.has(int(guest.get("id",-1))):return false
	if str(guest.get("phase","")) not in ["moving","queue"]:return false
	if int(guest.get("incident",-1))>=0:return false
	var itinerary:Dictionary=guest.get("route",{})
	var legs:Array=itinerary.get("legs",[])
	var current:int=int(guest.get("leg",-1))
	if current<0 or current>=legs.size():return false
	var step:Dictionary=legs[current]
	# Hats follow real pedestrians, never skiers in motion, lift seats,
	# rescue stretchers, hotel sleepers or a guest behind a facade.
	return str(step.get("kind","")) in ["walk","visit"]

static func collect(guests:Array,positions:Dictionary,families:Dictionary,event:String,limit:int=MAX_VISIBLE)->Array:
	var result:Array=[]
	if event=="":return result
	for guest in guests:
		if not guest is Dictionary or not eligible(guest,positions,event):continue
		var id:int=int(guest.id)
		var location:Variant=positions[id]
		if not location is Vector3 or not location.is_finite():continue
		var scale:float=0.72 if int(guest.get("years",18))<16 else 1.0
		result.append({"id":id,"point":location,"scale":scale})
		if result.size()>=limit:break
		var rendered:Array=families.get(id,[])
		var relatives:Array=guest.get("family",[])
		for index in range(mini(rendered.size(),maxi(0,relatives.size()-1))):
			var at:Variant=rendered[index]
			if not at is Vector3 or not at.is_finite():continue
			var small:bool=int(relatives[index].get("years",18))<16
			result.append({"id":id*5+index+1,"point":at,"scale":0.72 if small else 1.0})
			if result.size()>=limit:break
		if result.size()>=limit:break
	return result

func setup(parent:Node3D,solid:Material)->void:
	var art:=Art.new()
	# Original low-poly silhouette: snowy brim, festive cap and pompom.
	art.box(Vector3(0,0.11,0),Vector3(1.10,0.20,1.10),Color("f2ede2"))
	art.cone(Vector3(-0.10,0.52,0),0.53,0.76,Color("bc414e"),0.25)
	art.sphere(Vector3(-0.36,0.89,0.05),0.24,Color("f2ede2"))
	var mesh:ArrayMesh=art.finish()
	mesh.surface_set_material(0,solid)
	var instance:=MultiMesh.new()
	instance.transform_format=MultiMesh.TRANSFORM_3D
	instance.mesh=mesh
	instance.instance_count=MAX_VISIBLE
	instance.visible_instance_count=0
	node.name="holiday_guest_hats_043"
	node.multimesh=instance
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

func update(view:Node3D,positions:Dictionary,families:Dictionary)->void:
	if node.multimesh==null:return
	if not view.effects_enabled or view.quality_tier<=0 or view.zoom>900.0:
		node.multimesh.visible_instance_count=0
		return
	var event:String=Holidays.event_for(view.festival_scene.date_now())
	var people:Array=collect(view.model.guests,positions,families,event)
	var count:int=mini(people.size(),MAX_VISIBLE)
	for index in range(count):
		var person:Dictionary=people[index]
		var size:float=float(person.scale)
		var anchor:Vector3=person.point+Vector3.UP*(2.82*size)
		var bob:float=sin(float(Time.get_ticks_msec())*0.002+float(int(person.id)%31))*0.055
		anchor.y+=bob
		var basis:=Basis(Vector3.UP,float(int(person.id)%11)*0.45).scaled(Vector3.ONE*size)
		node.multimesh.set_instance_transform(index,Transform3D(basis,anchor))
	node.multimesh.visible_instance_count=count
