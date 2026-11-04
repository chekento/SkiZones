extends RefCounted
## A bounded, read-only director. The tour only changes the presentation camera.
const L = preload("res://src/core/i18n.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Ops = preload("res://src/core/operations.gd")
const SEGMENT_SECONDS := 10.0
const MAX_HOTSPOTS := 18
const PEAK_HOLD_SECONDS := 1.8
var active := false
var elapsed := 0.0
var hotspots: Array = []
var previous: Dictionary = {}
var attention := 0.55
var _origin: Dictionary = {}

static func _shot(point: Vector2, label_text: String, kind: String, zoom: float, pitch: float, yaw: float, hold: float = 4.2) -> Dictionary:
	return {"point":point,"label":label_text,"kind":kind,"zoom":zoom,"pitch":pitch,"yaw":yaw,"fov":38.0 if kind=="peak" else 48.0 if kind=="overview" else 42.0,"hold":hold,"travel":3.6,"priority":0.0}

static func attention_points(model: RefCounted) -> Array:
	var points: Array = []
	for event in model.operations.get("incidents",[]):
		if str(event.get("status","")) not in ["waiting","responding"]: continue
		var at: Vector2=Terrain.unpack(event.get("point",[]))
		if not at.is_finite(): continue
		var shot: Dictionary=_shot(at,L.text("Bergrettung · Einsatz"),"attention",150,37,0.65)
		shot.priority=100.0
		points.append(shot)
	for lift in model.lifts:
		var reason := ""
		var urgency := 0.0
		if not str(lift.get("fault","")).is_empty():
			reason=L.text("Störung · ")
			urgency=95.0
		elif bool(lift.get("enabled",true)) and Ops.active(model) and not Ops.staffing(model,lift).ok:
			reason=L.text("Personal fehlt · ")
			urgency=65.0
		var waiting: int=model.queue_size(int(lift.id))
		if waiting>=8 and urgency<55.0:
			reason=L.text("Warteschlange · ")
			urgency=minf(90.0,45.0+waiting*0.6)
		if urgency<=0: continue
		var shot: Dictionary=_shot(Terrain.unpack(lift.bottom),reason+str(lift.get("name","")),"attention",165,43,-0.8)
		shot.priority=urgency
		shot.asset_id=int(lift.id)
		points.append(shot)
	for piste in model.pistes:
		if not bool(piste.get("enabled",true)) or piste.points.size()<2: continue
		if float(piste.get("condition",100))>=28 and float(piste.get("snow",100))>=10: continue
		var shot: Dictionary=_shot(Terrain.unpack(piste.points[int(piste.points.size()/2)]),L.text("Piste braucht Pflege · ")+str(piste.get("name","")),"attention",240,48,1.1)
		shot.priority=60.0
		shot.asset_id=int(piste.id)
		points.append(shot)
	points.sort_custom(func(a,b): return float(a.priority)>float(b.priority))
	return points.slice(0,6)

static func landscape_points(model: RefCounted) -> Array:
	var terrain: RefCounted=model.terrain
	var bounds: Rect2=terrain.bounds
	var samples: Array=[]
	var count := 17
	for y in range(count):
		for x in range(count):
			var at: Vector2=bounds.position+bounds.size*Vector2((x+0.5)/count,(y+0.5)/count)
			samples.append({"point":at,"height":terrain.height(at),"x":x,"y":y})
	var peaks: Array=[]
	for sample in samples:
		var highest := true
		for offset in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
			var nx: int=sample.x+offset.x
			var ny: int=sample.y+offset.y
			if nx<0 or ny<0 or nx>=count or ny>=count: continue
			if float(samples[ny*count+nx].height)>float(sample.height): highest=false
		if highest: peaks.append(sample)
	peaks.sort_custom(func(a,b): return float(a.height)>float(b.height))
	var selected: Array=[]
	for sample in peaks:
		if selected.size()>=3: break
		if selected.any(func(other): return (other.point as Vector2).distance_to(sample.point)<bounds.size.length()*0.12): continue
		var at: Vector2=sample.point
		var step_size: Vector2=bounds.size/float(count)
		for refinement in range(3):
			var best: Vector2=at
			var height: float=terrain.height(at)
			for dy in [-1,0,1]:
				for dx in [-1,0,1]:
					var candidate: Vector2=(at+Vector2(dx,dy)*step_size*0.25).clamp(bounds.position+Vector2(8,8),bounds.end-Vector2(8,8))
					if terrain.height(candidate)>height:
						height=terrain.height(candidate)
						best=candidate
			at=best
			step_size*=0.5
		selected.append({"point":at,"height":terrain.height(at)})
	return selected

static func crowd_points(model: RefCounted, view: Node3D) -> Array:
	if view==null: return []
	var cells: Dictionary={}
	var checked := 0
	for guest in model.guests:
		if checked>=512: break
		checked+=1
		if not view._guest_positions.has(guest.id): continue
		if str(guest.get("waiting_reason",""))=="hotel": continue
		var legs: Array=guest.get("route",{}).get("legs",[])
		var index: int=int(guest.get("leg",0))
		if index>=0 and index<legs.size():
			var leg_kind: String=str(legs[index].get("kind",""))
			if leg_kind=="visit" or leg_kind=="lift" and str(guest.get("phase",""))=="moving": continue
		var world: Vector3=view._guest_positions[guest.id]
		if not world.is_finite(): continue
		var at := Vector2(world.x,world.z)
		var key := Vector2i((at/60.0).floor())
		if not cells.has(key): cells[key]={"sum":Vector2.ZERO,"count":0}
		cells[key].sum+=at
		cells[key].count+=1
	var result: Array=[]
	for cell in cells.values():
		if int(cell.count)<3: continue
		var shot: Dictionary=_shot(cell.sum/float(cell.count),L.text("Besucherleben · %d Gäste") % int(cell.count),"crowd",100,47,-0.55,3.4)
		shot.count=int(cell.count)
		result.append(shot)
	result.sort_custom(func(a,b): return int(a.count)>int(b.count))
	return result.slice(0,2)

static func build_hotspots(model: RefCounted, view: Node3D = null, weight: float = 0.55) -> Array:
	var result: Array=[]
	var bounds: Rect2=model.terrain.bounds
	var center: Vector2=bounds.get_center()
	result.append(_shot(center,L.text("Resort-Panorama"),"overview",clampf(bounds.size.length()*0.30,450,1900),47,0.7,5.5))
	var peaks: Array=landscape_points(model)
	for i in range(peaks.size()):
		var peak: Dictionary=peaks[i]
		result.append(_shot(peak.point,L.text("Gipfel · %.0f m") % float(peak.height),"peak",115.0+float(i)*28.0,24.0+float(i)*9.0,-1.1+float(i)*1.7,PEAK_HOLD_SECONDS))
		if i==0:
			result.append(_shot(peak.point,L.text("Hügel und Hangrelief"),"hill",420,57,1.6,4.5))
	result.append_array(crowd_points(model,view))
	for i in range(mini(3,model.lifts.size())):
		var lift: Dictionary=model.lifts[i]
		result.append(_shot(Terrain.unpack(lift.bottom),L.text("Talstation · ")+str(lift.get("name","")),"lift",185,35,-0.8+float(i)*0.9))
		result.append(_shot(Terrain.unpack(lift.top),L.text("Bergstation · ")+str(lift.get("name","")),"lift",250,29,1.2+float(i)*0.8))
	for piste in model.pistes:
		if result.size()>=14: break
		if not piste.enabled or piste.points.size()<2: continue
		result.append(_shot(Terrain.unpack(piste.points[int(piste.points.size()/2)]),L.text("Piste · ")+str(piste.get("name","")),"piste",250,51,-1.7))
	for building in model.buildings:
		if result.size()>=16: break
		if not bool(building.get("enabled",true)): continue
		result.append(_shot(Terrain.unpack(building.point),str(building.get("name","")),"village",165,39,2.4))
	for i in range(result.size()): result[i].score=70.0-float(i)
	if is_finite(weight) and weight>0:
		for shot in attention_points(model):
			shot.score=20.0+float(shot.priority)*clampf(weight,0,1)*1.5
			result.append(shot)
	result.sort_custom(func(a,b): return float(a.score)>float(b.score))
	return result.slice(0,MAX_HOTSPOTS)

func set_attention(value: float, view: Node3D = null) -> void:
	attention=clampf(value,0,1) if is_finite(value) else 0.55
	if active and view!=null:
		_origin=_camera_pose(view)
		hotspots=build_hotspots(view.model,view,attention)
		elapsed=0.0

func _camera_pose(view: Node3D) -> Dictionary:
	return {"point":view.focus,"zoom":view.zoom,"yaw":view.yaw,"pitch":view.pitch_degrees,"fov":view.camera.fov}

func begin(view: Node3D) -> bool:
	if view.model==null or view.loading_in_progress: return false
	hotspots=build_hotspots(view.model,view,attention)
	if hotspots.is_empty(): return false
	previous={"focus":view.focus,"zoom":view.zoom,"yaw":view.yaw,"pitch":view.pitch_degrees,"mode":view.camera_mode,"follow":view.follow_guest,"fov":view.camera.fov}
	_origin=_camera_pose(view)
	elapsed=0.0
	active=true
	view.follow_guest=-1
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
	view.camera.fov=float(previous.fov)
	view._update_camera()
	previous.clear()

func duration() -> float:
	var total := 0.0
	for shot in hotspots: total+=float(shot.travel)+float(shot.hold)
	return total

func current_shot() -> Dictionary:
	if hotspots.is_empty(): return {}
	var clock: float=fposmod(elapsed,maxf(0.001,duration()))
	for shot in hotspots:
		var length: float=float(shot.travel)+float(shot.hold)
		if clock<length: return shot
		clock-=length
	return hotspots[-1]

func label() -> String:
	return str(current_shot().get("label",""))

func _held_pose(shot: Dictionary, fraction: float) -> Dictionary:
	var pose: Dictionary=shot.duplicate()
	pose.yaw=float(shot.yaw)+0.045*fraction
	pose.zoom=float(shot.zoom)*lerpf(1.02,0.98,fraction)
	return pose

func step(view: Node3D, delta: float) -> void:
	if not active or hotspots.is_empty() or view.loading_in_progress: return
	var cycle: float=duration()
	elapsed+=minf(maxf(delta,0.0),0.25)
	if elapsed>=cycle:
		_origin=_held_pose(hotspots[-1],1.0)
		elapsed=fposmod(elapsed,cycle)
		hotspots=build_hotspots(view.model,view,attention)
	var clock: float=elapsed
	var from: Dictionary=_origin
	var pose: Dictionary={}
	for shot in hotspots:
		var travel: float=float(shot.travel)
		var hold: float=float(shot.hold)
		if clock<travel:
			var t: float=clampf(clock/travel,0,1)
			t=t*t*(3.0-2.0*t)
			var target: Dictionary=_held_pose(shot,0.0)
			pose={"point":(from.point as Vector2).lerp(target.point,t),"zoom":lerpf(float(from.zoom),float(target.zoom),t),"pitch":lerpf(float(from.pitch),float(target.pitch),t),"yaw":lerp_angle(float(from.yaw),float(target.yaw),t),"fov":lerpf(float(from.fov),float(target.fov),t)}
			break
		if clock<travel+hold:
			pose=_held_pose(shot,(clock-travel)/hold)
			break
		clock-=travel+hold
		from=_held_pose(shot,1.0)
	if pose.is_empty(): return
	view.follow_guest=-1
	view.camera_mode=1
	view.focus=(pose.point as Vector2).clamp(view.terrain.bounds.position+Vector2(8,8),view.terrain.bounds.end-Vector2(8,8))
	view.yaw=float(pose.yaw)
	view.pitch_degrees=float(pose.pitch)
	view.zoom=float(pose.zoom)
	view.camera.fov=float(pose.fov)
	view._update_camera()
	var camera_point := Vector2(view.camera.position.x,view.camera.position.z)
	if view.terrain.contains(camera_point):
		var minimum: float=view.terrain.height(camera_point)+12.0
		if view.camera.position.y<minimum:
			view.camera.position.y=minimum
			view.camera.look_at(view.terrain.world(view.focus,clampf(view.zoom*0.06,3,38)),Vector3.UP)
