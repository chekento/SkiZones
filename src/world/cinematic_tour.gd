extends RefCounted
## Read-only cinematic route over existing lifts, pistes and village hotspots.
## Never modifies camera modes, model data or guest paths while touring.
const Terrain = preload("res://src/core/terrain.gd")
const SEGMENT_SECONDS := 10.0
const MAX_HOTSPOTS := 18
var active := false
var elapsed := 0.0
var hotspots: Array = []
var previous: Dictionary = {}

static func build_hotspots(model: RefCounted) -> Array:
	var result: Array = []
	for lift in model.lifts:
		if result.size()>=12: break
		var a: Vector2=Terrain.unpack(lift.bottom)
		var b: Vector2=Terrain.unpack(lift.top)
		result.append({"point":a,"label":"Talstation · "+str(lift.name),"zoom":230.0,"pitch":33.0})
		result.append({"point":b,"label":"Bergstation · "+str(lift.name),"zoom":300.0,"pitch":26.0})
	for piste in model.pistes:
		if result.size()>=MAX_HOTSPOTS-3: break
		if not piste.enabled or piste.points.size()<2: continue
		result.append({"point":Terrain.unpack(piste.points[int(piste.points.size()/2)]),"label":"Piste · "+str(piste.name),"zoom":250.0,"pitch":34.0})
	for building in model.buildings:
		if result.size()>=MAX_HOTSPOTS: break
		if not building.enabled: continue
		result.append({"point":Terrain.unpack(building.point),"label":str(building.name),"zoom":185.0,"pitch":32.0})
	if result.is_empty():
		result.append({"point":Terrain.BASE,"label":"Talpanorama","zoom":350.0,"pitch":38.0})
		result.append({"point":model.terrain.bounds.get_center(),"label":"Bergpanorama","zoom":750.0,"pitch":33.0})
	return result

func begin(view: Node3D) -> bool:
	if view.model==null or view.loading_in_progress: return false
	hotspots=build_hotspots(view.model)
	if hotspots.is_empty(): return false
	previous={"focus":view.focus,"zoom":view.zoom,"yaw":view.yaw,"pitch":view.pitch_degrees,"mode":view.camera_mode,"follow":view.follow_guest}
	elapsed=0.0
	active=true
	view.follow_guest=-1
	view.camera_mode=1
	return true

func stop(view: Node3D) -> void:
	if not active: return
	active=false
	if previous.is_empty(): return
	view.follow_guest=int(previous.follow)
	view.focus=previous.focus
	view.zoom=previous.zoom
	view.yaw=previous.yaw
	view.pitch_degrees=previous.pitch
	view.camera_mode=previous.mode
	view._update_camera()
	previous.clear()

func label() -> String:
	if hotspots.is_empty(): return ""
	return str(hotspots[mini(hotspots.size()-1,int(elapsed/SEGMENT_SECONDS)%hotspots.size())].label)

func step(view: Node3D, delta: float) -> void:
	if not active or hotspots.is_empty() or view.loading_in_progress: return
	elapsed+=minf(maxf(delta,0.0),0.25)
	var index:=int(elapsed/SEGMENT_SECONDS)%hotspots.size()
	var next_index: int=(index+1)%hotspots.size()
	var at: Dictionary=hotspots[index]
	var target: Dictionary=hotspots[next_index]
	var fraction:=fmod(elapsed,SEGMENT_SECONDS)/SEGMENT_SECONDS
	# A gentle, continuous drone-like translation between real POIs while
	# always keeping the chosen destination near the frame center.
	var easing:=fraction*fraction*(3.0-2.0*fraction)
	view.follow_guest=-1
	view.camera_mode=1
	var from: Vector2=at.point
	var to: Vector2=target.point
	view.focus=from.lerp(to,easing).clamp(view.terrain.bounds.position+Vector2(10,10),view.terrain.bounds.end-Vector2(10,10))
	view.yaw=0.38+sin(elapsed*0.12)*0.17+float(index%3)*0.2
	view.pitch_degrees=lerpf(float(at.pitch),float(target.pitch),easing)
	view.zoom=lerpf(float(at.zoom),float(target.zoom),easing)
	view._update_camera()
