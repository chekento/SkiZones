extends Control
## 0.40 interactive operational map: actual lift coordinates, live queues
## and staff/fault severity. Read-only drawing; no synthetic heat data.
signal lift_selected(asset_id: int)
const Terrain = preload("res://src/core/terrain.gd")
const L = preload("res://src/core/i18n.gd")
var model: RefCounted
var rows: Array=[]
var hot_spots: Array=[]
var selected_id: int=-1

func setup(model_value: RefCounted, lift_rows: Array) -> void:
	model=model_value
	rows=lift_rows
	custom_minimum_size=Vector2(0,265)
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	mouse_filter=Control.MOUSE_FILTER_STOP
	tooltip_text=L.text("Liftpunkt berühren: Anlage und Personal öffnen")
	queue_redraw()

func _map_rect() -> Rect2:
	return Rect2(16,30,maxf(1,size.x-32),maxf(1,size.y-64))

func _project(at: Vector2) -> Vector2:
	if model==null:return Vector2.ZERO
	var bounds: Rect2=model.terrain.bounds
	var area: Rect2=_map_rect()
	return area.position+((at-bounds.position)/bounds.size).clamp(Vector2.ZERO,Vector2.ONE)*area.size

func _draw() -> void:
	var bounds: Rect2=_map_rect()
	draw_rect(Rect2(Vector2.ZERO,size),Color("dfece7"))
	draw_rect(bounds,Color("d1e2df"),true)
	for stripe in range(1,11):
		var ratio: float=float(stripe)/11.0
		var y: float=bounds.position.y+bounds.size.y*ratio
		draw_line(Vector2(bounds.position.x,y),Vector2(bounds.end.x,y-9),Color(0.29,0.45,0.47,0.13),1.0,true)
	var font: Font=get_theme_default_font()
	draw_string(font,Vector2(16,21),L.text("BERGNETZ · WARTESCHLANGEN & STÖRUNGEN"),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("24454b"))
	hot_spots.clear()
	if model==null:return
	for row in rows:
		var lift: Dictionary=model.asset(int(row.id))
		if not lift.has("bottom") or not lift.has("top"):continue
		var a: Vector2=_project(Terrain.unpack(lift.bottom))
		var b: Vector2=_project(Terrain.unpack(lift.top))
		var centre: Vector2=(a+b)*0.5
		var queued: int=int(row.queue)
		var severity: int=int(row.severity)
		var tone: Color=Color("c95b48") if severity>=3 else Color("d38c4f") if severity>=2 else Color("4b9f99") if severity==1 else Color("477b82")
		draw_line(a,b,Color("f8f8f1"),6.0,true)
		draw_line(a,b,tone,3.0,true)
		draw_circle(a,3.5,tone)
		draw_circle(b,3.5,tone)
		var radius: float=clampf(11+sqrt(float(queued))*2.1,11,31)
		if queued>0:draw_circle(centre,radius+7,Color(tone,0.14))
		draw_circle(centre,radius+2,Color("fffaf0"))
		draw_circle(centre,radius,tone)
		draw_string(font,centre+Vector2(-16,5),str(queued) if queued>0 else "✓",HORIZONTAL_ALIGNMENT_CENTER,32,13,Color.WHITE)
		if int(row.id)==selected_id:draw_arc(centre,radius+5,0,TAU,28,Color("193e49"),3.0,true)
		hot_spots.append({"id":int(row.id),"at":centre,"radius":radius+8})
	draw_string(font,Vector2(16,size.y-13),L.text("● NORMAL       ● WARTEZEIT       ● STÖRUNG / PERSONAL"),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("365c5f"))

func _pick(at: Vector2) -> void:
	var closest_id: int=-1
	var closest_dist: float=INF
	for hit in hot_spots:
		var dist: float=at.distance_to(hit.at)
		if dist<=hit.radius and dist<closest_dist:
			closest_dist=dist
			closest_id=int(hit.id)
	if closest_id>=0:
		selected_id=closest_id
		queue_redraw()
		lift_selected.emit(closest_id)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		_pick(event.position)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_pick(event.position)
		accept_event()
