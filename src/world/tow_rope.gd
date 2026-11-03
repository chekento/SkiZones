extends RefCounted
const Fleet = preload("res://src/core/lift_fleet.gd")
## The carrier schedule stays authoritative; only its reeled tow is articulated.
static func frame(mountain: RefCounted, pose: Dictionary, occupied: bool, clock: float) -> Dictionary:
	var loaded: bool=occupied and pose.outbound
	var transform_value: Transform3D=pose.transform
	if loaded:
		transform_value.origin=Fleet.tow_point(mountain,pose)+Vector3.UP
	else:
		var swing := sin(clock*0.12+float(pose.carrier)*1.7)*0.30
		transform_value.origin=pose.grip-Vector3.UP*2.4+transform_value.basis.x*swing
		transform_value.basis=transform_value.basis*Basis(Vector3.FORWARD,swing*0.20)
	var end: Vector3=transform_value.origin+Vector3.UP*0.55
	var middle: Vector3=pose.grip.lerp(end,0.50)-Vector3.UP*(0.04 if loaded else 0.28)
	if not loaded: middle+=transform_value.basis.z*0.30
	return {"transform":transform_value,"points":[pose.grip,middle,end],"loaded":loaded}
