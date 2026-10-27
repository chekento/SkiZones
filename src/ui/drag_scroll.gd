extends ScrollContainer
## Finger, pen and mouse drags scroll the entire card, never activate it on release.
static var dragging_any := false
static var last_drag_release := -1000
var _contact := -1
var _origin := Vector2.ZERO
var _last := Vector2.ZERO
var _dragging := false
var _velocity := 0.0

static func click_allowed() -> bool:
	return not dragging_any and Time.get_ticks_msec() - last_drag_release > 80

func _ready() -> void:
	scroll_deadzone = 12
	horizontal_scroll_mode = SCROLL_MODE_DISABLED
	get_v_scroll_bar().custom_minimum_size.x = 12

func _begin(at: Vector2, contact: int) -> void:
	last_drag_release = -1000
	if not is_visible_in_tree() or not get_global_rect().has_point(at):
		return
	_contact = contact
	_origin = at
	_last = at
	_dragging = false
	_velocity = 0

func _move(at: Vector2) -> void:
	if not _dragging and absf(at.y - _origin.y) > 12:
		_dragging = true
		dragging_any = true
		propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
	if _dragging:
		var movement := at.y - _last.y
		scroll_vertical -= roundi(movement)
		_velocity = clampf(-movement * 35, -1800, 1800)
		get_viewport().set_input_as_handled()
	_last = at

func _end() -> void:
	if _dragging:
		last_drag_release = Time.get_ticks_msec()
		dragging_any = false
		propagate_notification(Control.NOTIFICATION_SCROLL_END)
		get_viewport().set_input_as_handled()
	_contact = -1
	_dragging = false

func _input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _contact < 0:
			_begin(event.position, event.index)
		elif not event.pressed and event.index == _contact:
			_end()
	elif event is InputEventScreenDrag and event.index == _contact:
		_move(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(event.position, -2)
		elif _contact == -2:
			_end()
	elif event is InputEventMouseMotion and _contact == -2:
		_move(event.position)

func _process(delta: float) -> void:
	if _contact == -1 and absf(_velocity) > 5 and is_visible_in_tree():
		scroll_vertical += roundi(_velocity * delta)
		_velocity = move_toward(_velocity, 0, delta * 2800)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		if _dragging:
			dragging_any = false
		_contact = -1
		_dragging = false
		_velocity = 0
