extends Control
## In-scene modal: no platform Window/subwindow, including on Android.
const DragScroll = preload("res://src/ui/drag_scroll.gd")
signal confirmed
var panel := PanelContainer.new()
var body := RichTextLabel.new()
var scroll := DragScroll.new()
var next_button: Button
var hud: CanvasLayer

func setup(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0.015, 0.04, 0.06, 0.78)
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	panel.add_theme_stylebox_override("panel", hud._style(Color("123342"), 18, 22, hud.TEAL))
	var box: VBoxContainer = hud._vbox(panel, 12)
	hud._label(box, "FEIERABEND AM BERG", 13, hud.TEAL)
	hud._label(box, "Dein Tag im Schnee", 26, hud.ACCENT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_theme_color_override("default_color", hud.INK)
	body.add_theme_font_size_override("normal_font_size", 18)
	scroll.add_child(body)
	next_button = hud._button(box, "Nächsten Tag starten", func():
		hide()
		confirmed.emit()
	, true)
	next_button.focus_mode = Control.FOCUS_ALL
	hud._button(box, "Noch am Berg bleiben", hide)
	resized.connect(_layout)
	hide()

func _layout() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	var extent := Vector2(minf(760, size.x - 32), minf(700, size.y - 24))
	panel.position = (size - extent) * 0.5
	panel.size = extent

func open(text_value: String) -> void:
	body.text = text_value
	show()
	move_to_front()
	_layout()
	scroll.scroll_vertical = 0
	next_button.grab_focus()
