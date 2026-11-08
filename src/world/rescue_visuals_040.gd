extends Node3D
## 0.40 piste rescue: batched pair of fast skiers, folded/outbound litter,
## carried return patient, compact snowcat and persistent attention markers.
## All positions follow simulation-owned route waypoints and rescue stages.
const Rescue=preload("res://src/core/rescue_protocol_040.gd")
const Terrain=preload("res://src/core/terrain.gd")
const MAX_EVENTS:=100
var rescuers:=MultiMeshInstance3D.new()
var litter:=MultiMeshInstance3D.new()
var patients:=MultiMeshInstance3D.new()
var snowcats:=MultiMeshInstance3D.new()
var alerts:Array=[]

func _material(color:Color)->StandardMaterial3D:
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=0.78
	return mat

func _batch(mesh:Mesh,material:Material,count:int)->MultiMeshInstance3D:
	var node:=MultiMeshInstance3D.new()
	var multimesh:=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.instance_count=count
	multimesh.visible_instance_count=0
	multimesh.mesh=mesh
	node.multimesh=multimesh
	node.material_override=material
	add_child(node)
	return node

func setup() -> void:
	var skier:=CapsuleMesh.new()
	skier.radius=0.28
	skier.height=1.75
	rescuers=_batch(skier,_material(Color("cc3d31")),MAX_EVENTS*2)
	var frame:=BoxMesh.new()
	frame.size=Vector3(0.8,0.16,2.3)
	litter=_batch(frame,_material(Color("f4ba63")),MAX_EVENTS)
	var person:=CapsuleMesh.new()
	person.radius=0.25
	person.height=1.6
	patients=_batch(person,_material(Color("f0b9a1")),MAX_EVENTS)
	var cat:=BoxMesh.new()
	cat.size=Vector3(2.25,1.15,3.0)
	snowcats=_batch(cat,_material(Color("df4e3a")),MAX_EVENTS)
	for _i in range(MAX_EVENTS):
		var sign:=Label3D.new()
		sign.text="!"
		sign.font_size=56
		sign.pixel_size=0.015
		sign.modulate=Color("ffb45a")
		sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		sign.visible=false
		add_child(sign)
		alerts.append(sign)

func update_patrol(view:Node3D) -> void:
	if view.model==null:return
	var skier_count:=0
	var litter_count:=0
	var patient_count:=0
	var cat_count:=0
	var mark_count:=0
	for event in view.model.operations.incidents:
		var status:String=str(event.get("status","waiting"))
		if status in ["resolved","treating"]:continue
		var incident:Vector2=Terrain.unpack(event.get("point",[0.0,0.0]))
		if not incident.is_finite():continue
		var is_fear:bool=not Rescue.needs_stretcher(str(event.get("reason","fatigue")))
		var location:Vector2=Rescue.route_position(event) if status in Rescue.MOBILE_STAGES else incident
		var active:bool=status in Rescue.MOBILE_STAGES
		var centre:Vector3=view.ground_position(location,0.12)
		var rotation:=Basis.IDENTITY
		var path:Array=event.get("route_points",[])
		if path.size()>1:
			var direction:Vector2=Terrain.unpack(path[-1])-Terrain.unpack(path[0])
			if status in ["transporting","guiding"]:direction=-direction
			if direction.length_squared()>0.01:rotation=Basis(Vector3.UP,atan2(direction.x,direction.y))
		if active:
			if event.get("transport_mode","skis")=="snowcat":
				if cat_count<MAX_EVENTS:
					snowcats.multimesh.set_instance_transform(cat_count,Transform3D(rotation,centre+Vector3.UP*0.7))
					cat_count+=1
			else:
				for side in [-1.0,1.0]:
					if skier_count>=MAX_EVENTS*2:break
					var offset:Vector3=rotation*Vector3(side*0.85,0.95,0.0)
					rescuers.multimesh.set_instance_transform(skier_count,Transform3D(rotation,centre+offset))
					skier_count+=1
			if not is_fear and litter_count<MAX_EVENTS:
				var carried:bool=status=="transporting"
				var position:Vector3=centre+rotation*Vector3(0.0,0.45 if carried else 0.70,0.0)
				var scale:Vector3=Vector3(1.0,1.0,1.0) if carried else Vector3(0.3,1.0,0.55)
				litter.multimesh.set_instance_transform(litter_count,Transform3D(rotation.scaled(scale),position))
				litter_count+=1
		if not is_fear and status in ["waiting","responding","transporting"] and patient_count<MAX_EVENTS:
			var at:Vector3=centre if status=="transporting" else view.ground_position(incident,0.12)
			var patient_basis:Basis=rotation*Basis(Vector3.RIGHT,PI*0.5)
			var height:float=0.60 if status=="transporting" else 0.35
			patients.multimesh.set_instance_transform(patient_count,Transform3D(patient_basis,at+Vector3.UP*height))
			patient_count+=1
		if status in ["waiting","responding","guiding"] and mark_count<alerts.size():
			var alert:Label3D=alerts[mark_count]
			alert.position=view.ground_position(incident,4.0)
			alert.text="?" if is_fear else "!"
			alert.modulate=Color("ffd68e") if is_fear else Color("f04d4d")
			alert.visible=true
			mark_count+=1
	for index in range(mark_count,alerts.size()):alerts[index].visible=false
	rescuers.multimesh.visible_instance_count=skier_count
	litter.multimesh.visible_instance_count=litter_count
	patients.multimesh.visible_instance_count=patient_count
	snowcats.multimesh.visible_instance_count=cat_count
