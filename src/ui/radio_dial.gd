extends Control
## A real touch/mouse/keyboard tuning wheel, drawn as reusable vector art.
## Swiping, spinning the mouse wheel, keyboard arrows and tapping the rim
## all trigger the SAME immediate station change without an Apply button.
signal tuned(direction: int)

var active := true
var _dragging := false
var _distance := 0.0
var _origin := Vector2.ZERO
var _moved := false
var _glint := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(112,108)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	resized.connect(queue_redraw)

func _turn(direction: int) -> void:
	if direction == 0:return
	_glint = float(direction)
	tuned.emit(direction)
	queue_redraw()

func _motion(relative: Vector2) -> void:
	if not _dragging:return
	_distance += relative.x - relative.y * 0.55
	if absf(_distance) > 10.0: _moved = true
	while absf(_distance) >= 33.0:
		var direction := 1 if _distance > 0.0 else -1
		_distance -= 33.0 * direction
		_turn(direction)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_dragging = true
			_origin = event.position
			_distance = 0.0
			_moved = false
			grab_focus()
		elif _dragging:
			if not _moved: _turn(1 if event.position.x >= size.x * 0.5 else -1)
			_dragging = false
		accept_event()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_turn(1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_turn(-1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_origin = event.position
				_distance = 0.0
				_moved = false
				grab_focus()
			else:
				if _dragging and not _moved:
					_turn(1 if event.position.x >= size.x * 0.5 else -1)
				_dragging = false
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_motion(event.relative)
		accept_event()
	elif event is InputEventScreenDrag:
		_motion(event.relative)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_RIGHT,KEY_UP]:
			_turn(1)
			accept_event()
		elif event.keycode in [KEY_LEFT,KEY_DOWN]:
			_turn(-1)
			accept_event()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x,size.y) * 0.40
	var rim := Color("4b7882") if active else Color("42545a")
	draw_circle(center, radius + 9.0, Color("061621"))
	draw_arc(center,radius + 6.0,0.0,TAU,80,Color("8bbac0"),3.5,true)
	draw_circle(center,radius - 1.0,Color("254958") if active else Color("344046"))
	draw_arc(center,radius - 4.0,0.15,TAU * 0.88,64,Color("a5e9d7") if active else rim,2.8,true)
	for tick in range(22):
		var theta := TAU * float(tick)/22.0
		var unit := Vector2(cos(theta),sin(theta))
		var big := tick % 3 == 0
		draw_line(center + unit * (radius + 2.0),center + unit * (radius + (11.0 if big else 7.0)),Color("aee5e0") if active else Color("6b828b"),2.0 if big else 1.0,true)
	draw_circle(center,radius*0.57,Color("081e2b"))
	draw_circle(center,radius*0.47,Color("163a49") if active else Color("33464f"))
	# No plus symbol: this is the station-tuning wheel, NOT volume +.
	# The rotary marking now shows its actual purpose.
	var font:Font=ThemeDB.fallback_font
	var size_value:int=maxi(9,mini(13,roundi(radius*.21)))
	draw_string(font,center+Vector2(0,4),"TUNE",HORIZONTAL_ALIGNMENT_CENTER,radius*.77,size_value,Color("d1f9eb"))
	draw_line(center+Vector2(0,-radius*.27),center+Vector2(0,-radius*.41),Color("d7f3d9"),2.6,true)
	draw_circle(center+Vector2(radius*.16,-radius*.26),2.5,Color("fff1c9"))
