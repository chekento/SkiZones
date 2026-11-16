extends Control
## Gesture state is transient. Only an explicitly confirmed finished room is billed.
const L = preload("res://src/core/i18n.gd")
const DragScroll = preload("res://src/ui/drag_scroll.gd")
const Rooms = preload("res://src/core/hotel_rooms.gd")
signal completed(result: Dictionary)
signal updated
var model: RefCounted
var hotel_id := -1
var room_id := -1
var stage := 0
var done: Array[int] = []
var pointer := -2
var dragging := -1
var last_point := Vector2.ZERO
var wiped := 0.0
var committed := false
var note := ""
const ITEMS := [Vector2(0.16,0.66),Vector2(0.76,0.72),Vector2(0.83,0.35)]
const LINEN := [Vector2(0.12,0.28),Vector2(0.12,0.45),Vector2(0.12,0.82)]
const TARGETS := [Vector2(0.48,0.24),Vector2(0.48,0.43),Vector2(0.48,0.62)]
const SPOTS := [Vector2(0.75,0.28),Vector2(0.73,0.50),Vector2(0.80,0.82)]
const HINTS := ["Tippe die drei herumliegenden Gegenstände an.","Ziehe die drei Wäschestücke links auf die markierten Bettflächen.","Wische mehrfach über jeden der drei Flecken.","Zimmer fertig: Reinigung bestätigen · 8 €"]

func setup(resort: RefCounted, hotel: int, room: int) -> void:
	model=resort;hotel_id=hotel;room_id=room
	custom_minimum_size=Vector2(0,390)
	mouse_filter=Control.MOUSE_FILTER_STOP
	name="housekeeping_canvas"
	var ancestor:Node=get_parent()
	while ancestor!=null:
		if ancestor is DragScroll:ancestor.gesture_exclusions.append(self)
		ancestor=ancestor.get_parent()

func valid_room() -> bool:
	if model==null:return false
	var building: Dictionary=model.asset(hotel_id)
	if not building.get("enabled",false) or not building.has("room_operations"):return false
	for room in Rooms.view(model,building).rooms:
		if int(room.id)==room_id:return room.reservation=="" and not bool(room.clean)
	return false

func cancel_gesture() -> void:
	pointer=-2;dragging=-1;wiped=0.0
	updated.emit()
	queue_redraw()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_VISIBILITY_CHANGED:
		cancel_gesture()

func _point(at: Vector2) -> Vector2:
	return Vector2(at.x/maxf(size.x,1.0),(at.y-88.0)/maxf(size.y-104.0,1.0))

func _gui_input(event: InputEvent) -> void:
	if committed:return
	if event is InputEventScreenTouch:
		if event.canceled:cancel_gesture();return
		if event.pressed:_press(event.position,event.index)
		else:_release(event.position,event.index)
	elif event is InputEventScreenDrag:
		_move(event.position,event.index)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:_press(event.position,-1)
		else:_release(event.position,-1)
	elif event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		_move(event.position,-1)
	accept_event()

func _press(at: Vector2, id: int) -> void:
	if pointer!=-2:return
	if stage==3:
		if Rect2(12,44,maxf(0,size.x-24),40).has_point(at):finish()
		return
	var p:=_point(at)
	if p.x<0 or p.x>1 or p.y<0 or p.y>1:return
	pointer=id;last_point=p;wiped=0.0
	var points: Array = ITEMS if stage==0 else LINEN if stage==1 else SPOTS
	for i in range(3):
		if not done.has(i) and p.distance_to(points[i])<0.12:
			dragging=i
			break
	queue_redraw()

func _move(at: Vector2, id: int) -> void:
	if id!=pointer:return
	var p:=_point(at)
	if stage==2 and dragging>=0:
		# Only short strokes actually on this stain count; off-canvas jumps do not.
		var distance:=p.distance_to(last_point)
		if p.distance_to(SPOTS[dragging])<0.13 and last_point.distance_to(SPOTS[dragging])<0.13 and distance<0.10:
			wiped+=distance
	last_point=p
	queue_redraw()

func _release(at: Vector2, id: int) -> void:
	if id!=pointer:return
	var p:=_point(at)
	if dragging>=0:
		if (stage==0 and p.distance_to(ITEMS[dragging])<0.12) or (stage==1 and p.distance_to(TARGETS[dragging])<0.13) or (stage==2 and wiped>=0.32 and p.distance_to(SPOTS[dragging])<0.13):
			done.append(dragging)
			if done.size()==3:stage+=1;done.clear()
	cancel_gesture()

func finish() -> Dictionary:
	if committed or stage!=3 or not valid_room():
		note=L.text("Nur ein vollständig bearbeitetes, freies und schmutziges Zimmer kann abgeschlossen werden.")
		updated.emit()
		queue_redraw()
		return {"ok":false}
	var result:=Rooms.clean_room(model,hotel_id,room_id)
	note=str(result.get("message",""))
	updated.emit()
	if result.ok:committed=true;completed.emit(result)
	queue_redraw()
	return result

func _draw() -> void:
	var font:=ThemeDB.fallback_font
	draw_style_box(_panel(Color("e9e3d8")),Rect2(Vector2.ZERO,size))
	draw_string(font,Vector2(14,25),L.text("HOUSEKEEPING · ZIMMER %d")%room_id,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("244e4b"))
	var hint: String=note if note!="" else L.text(HINTS[stage])
	# The parent supplies a wrapping instruction label; canvas text is short.
	draw_string(font,Vector2(14,76),L.text("Schritt %d / 3")%mini(3,stage+1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("244e4b"))
	if stage==3:
		draw_style_box(_panel(Color("285c53")),Rect2(12,44,maxf(0,size.x-24),40))
		draw_string(font,Vector2(20,70),L.text("Reinigung bestätigen · 8 €"),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
	var scale_value:=Vector2(size.x,maxf(1,size.y-104))
	var origin:=Vector2(0,88)
	for column in range(1,10):draw_line(origin+Vector2(column/10.0,0)*scale_value,origin+Vector2(column/10.0,1)*scale_value,Color("d7cbb9"),1)
	draw_rect(Rect2(origin+Vector2(0.30,0.08)*scale_value,Vector2(0.36,0.70)*scale_value),Color("715c4c"))
	for i in range(3):
		var rect:=Rect2(origin+(TARGETS[i]-Vector2(0.14,0.075))*scale_value,Vector2(0.28,0.15)*scale_value)
		draw_rect(rect,Color("faf8ed") if stage>1 or (stage==1 and done.has(i)) else Color("c5b6a8"))
		draw_rect(rect,Color("9aafaa"),false,2)
	# Window, bedside table and plant anchor the room as an interior.
	draw_rect(Rect2(origin+Vector2(0.70,0.02)*scale_value,Vector2(0.24,0.09)*scale_value),Color("92b9c0"))
	draw_rect(Rect2(origin+Vector2(0.17,0.10)*scale_value,Vector2(0.10,0.12)*scale_value),Color("b9956c"))
	draw_circle(origin+Vector2(0.91,0.15)*scale_value,10,Color("527962"))
	if stage==0:
		for i in range(3):
			if not done.has(i):
				var at:Vector2=origin+ITEMS[i]*scale_value
				if i==0:
					draw_circle(at,12,Color("e8f0e8"));draw_circle(at,7,Color("8c684a"));draw_arc(at+Vector2(12,0),5,-PI/2,PI/2,12,Color("e8f0e8"),4)
				elif i==1:
					draw_style_box(_panel(Color("7d9996")),Rect2(at-Vector2(17,8),Vector2(13,27)))
					draw_style_box(_panel(Color("7d9996")),Rect2(at+Vector2(2,-13),Vector2(13,27)))
				else:
					draw_rect(Rect2(at-Vector2(17,12),Vector2(34,24)),Color("d4a479"))
					draw_line(at-Vector2(14,6),at+Vector2(14,8),Color("b78056"),3)
	if stage==1:
		for i in range(3):
			if not done.has(i):
				var point: Vector2=last_point if dragging==i else LINEN[i]
				draw_rect(Rect2(origin+point*scale_value-Vector2(18,13),Vector2(36,26)),Color("f9fbf8"))
	if stage==2:
		for i in range(3):
			if not done.has(i):
				draw_circle(origin+SPOTS[i]*scale_value,16,Color("a99a84"))
				if dragging==i:draw_arc(origin+SPOTS[i]*scale_value,20,0,minf(TAU,wiped/0.32*TAU),24,Color("2d766a"),4)
	tooltip_text=hint

func _panel(color: Color) -> StyleBoxFlat:
	var panel:=StyleBoxFlat.new();panel.bg_color=color
	panel.set_corner_radius_all(12)
	return panel
