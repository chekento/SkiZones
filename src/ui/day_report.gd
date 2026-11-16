extends Control
const L = preload("res://src/core/i18n.gd")
## In-scene modal: no platform Window/subwindow, including on Android.
const DragScroll = preload("res://src/ui/drag_scroll.gd")
const Goals = preload("res://src/core/long_goals_042.gd")
signal confirmed
var panel := PanelContainer.new()
var body := RichTextLabel.new()
var scroll := DragScroll.new()
var next_button: Button
var hud: CanvasLayer
var goal_summary := Label.new()
var goal_claim: Button

func setup(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0.015, 0.04, 0.06, 0.78)
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	panel.add_theme_stylebox_override("panel", hud._style(Color("fffaf2"), 18, 22, hud.TEAL))
	var box: VBoxContainer = hud._vbox(panel, 12)
	hud._label(box, L.text("FEIERABEND AM BERG"), 13, hud.TEAL)
	hud._label(box, L.text("Dein Tag im Schnee"), 26, hud.ACCENT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_theme_color_override("default_color", hud.INK)
	body.add_theme_font_size_override("normal_font_size", 18)
	var report_content: VBoxContainer = hud._vbox(scroll, 12)
	report_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal_summary.add_theme_color_override("font_color", hud.TEAL)
	report_content.add_child(goal_summary)
	goal_claim = hud._button(report_content, L.text("Alle verfügbaren Ziele abschließen"), func():_claim_goals.call_deferred(), true)
	goal_claim.name = "day_report_claim_goals"
	goal_claim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_content.add_child(body)
	next_button = hud._button(box, L.text("Nächsten Tag starten"), func():
		hide()
		confirmed.emit()
	, true)
	next_button.focus_mode = Control.FOCUS_ALL
	hud._button(box, L.text("Noch am Berg bleiben"), hide)
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
	var count: int = Goals.pending(hud.game.model).size()
	goal_summary.visible = count > 0
	goal_claim.visible = count > 0
	goal_summary.text = L.text("%d Ziele bereit · %d € verfügbar") % [count, Goals.pending_reward(hud.game.model)]
	show()
	move_to_front()
	_layout()
	scroll.scroll_vertical = 0
	next_button.grab_focus()

func _claim_goals() -> void:
	var result: Dictionary = Goals.claim_all(hud.game.model)
	hud.toast(result.message)
	if result.ok:
		hud.game.call_deferred("save_game", false)
		hud.show_report()
