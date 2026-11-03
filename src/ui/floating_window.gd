extends Control
## One touch-friendly frame shared by catalog, piste workshop and businesses.
const L = preload("res://src/core/i18n.gd")
signal close_requested
var body := VBoxContainer.new()
var title := Label.new()
var fullscreen := true
var restore_rect := Rect2(70,70,900,610)
var toggle := Button.new()
var _dragging := false
var _resizing := false
var _pointer := -2

func setup(hud: CanvasLayer, caption: String) -> void:
	z_index=30
	mouse_filter=Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel",hud._style(Color("f5f2e9"),16,16,Color("b4c9bf")))
	panel.mouse_filter=Control.MOUSE_FILTER_PASS
	panel.add_child(body)
	body.add_theme_constant_override("separation",10)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y=48
	header.mouse_filter=Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape=Control.CURSOR_MOVE
	header.gui_input.connect(_header_input)
	body.add_child(header)
	title.text=caption
	title.clip_text=true
	title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size",24)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	header.add_child(title)
	header.add_child(toggle)
	toggle.custom_minimum_size=Vector2(140,46)
	toggle.pressed.connect(toggle_fullscreen)
	var close: Button = hud._button(header,L.text("Schließen"),func(): close_requested.emit())
	close.custom_minimum_size.x=120
	var grip := Control.new()
	add_child(grip)
	grip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	grip.position=Vector2(-34,-34)
	grip.size=Vector2(34,34)
	grip.mouse_default_cursor_shape=Control.CURSOR_FDIAGSIZE
	grip.gui_input.connect(_resize_input)
	grip.draw.connect(func():
		for offset in [10,17,24]: grip.draw_line(Vector2(offset,28),Vector2(28,offset),Color("74968c"),2,true)
	)
	get_viewport().size_changed.connect(_fit)
	call_deferred("_fit")

func _bounds() -> Vector2:
	var parent := get_parent() as Control
	return parent.size if parent!=null and parent.size.x>0 else get_viewport_rect().size

func _fit() -> void:
	if not is_inside_tree(): return
	var bounds := _bounds()
	var minimum := Vector2(minf(620,bounds.x-16),minf(420,bounds.y-16))
	if fullscreen:
		position=Vector2(8,8)
		size=bounds-Vector2(16,16)
	else:
		size=size.clamp(minimum,bounds-Vector2(16,16))
		position=position.clamp(Vector2(8,8),bounds-size-Vector2(8,8))
	toggle.text=L.text("Verkleinern") if fullscreen else L.text("Vollbild")
	queue_redraw()

func toggle_fullscreen() -> void:
	if fullscreen:
		fullscreen=false
		position=restore_rect.position
		size=restore_rect.size
	else:
		restore_rect=Rect2(position,size)
		fullscreen=true
	_fit()

func _header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		_dragging=event.pressed
		_pointer=-1
		accept_event()
	elif event is InputEventScreenTouch:
		_dragging=event.pressed
		_pointer=event.index
		accept_event()
	elif _dragging and ((event is InputEventMouseMotion and _pointer==-1) or (event is InputEventScreenDrag and event.index==_pointer)):
		if fullscreen: toggle_fullscreen()
		position+=event.relative
		_fit()
		accept_event()

func _resize_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		_resizing=event.pressed
		_pointer=-1
		accept_event()
	elif event is InputEventScreenTouch:
		_resizing=event.pressed
		_pointer=event.index
		accept_event()
	elif _resizing and ((event is InputEventMouseMotion and _pointer==-1) or (event is InputEventScreenDrag and event.index==_pointer)):
		if fullscreen: toggle_fullscreen()
		size+=event.relative
		_fit()
		accept_event()

func _notification(what: int) -> void:
	if what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_dragging=false
		_resizing=false
