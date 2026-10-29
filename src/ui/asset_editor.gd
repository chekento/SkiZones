extends Control
const L = preload("res://src/core/i18n.gd")
const COLORS := ["417e96", "4a998f", "cc7c4e", "a47baa", "c79e4e", "b85e6a"]
var hud: CanvasLayer
var id := -1
var name_field := LineEdit.new()
var orientation_choice := OptionButton.new()
var width_slider := HSlider.new()
var color := ""
var _colors: Array = []
var _color_row := HBoxContainer.new()
var _color_label: Label
var _rotation_label: Label
var _width_label: Label
var _width_value: Label

func setup(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.06, 0.09, 0.7)
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = hud._panel(self, -300, -320, 300, 320, 0.5, 0.5)
	var box: VBoxContainer = hud._vbox(panel, 12)
	hud._label(box, L.text("DEIN RESORT · DEIN STIL"), 13, hud.TEAL)
	hud._label(box, L.text("Gestalten & umplanen"), 27, hud.INK)
	hud._label(box, L.text("Name"), 15, hud.MUTED)
	name_field.max_length = 60
	name_field.custom_minimum_size.y = 46
	box.add_child(name_field)
	_color_label = hud._label(box, L.text("Akzentfarbe · Lifte und Gebäude"), 15, hud.MUTED)
	box.add_child(_color_row)
	for value in COLORS:
		var button: Button = hud._button(_color_row, "", func():
			color = value
			_sync_colors()
		)
		button.custom_minimum_size = Vector2(54, 46)
		button.add_theme_stylebox_override("normal", hud._style(Color(value), 9, 4))
		button.add_theme_stylebox_override("pressed", hud._style(Color(value).lightened(0.15), 9, 4))
		_colors.append({"button": button, "value": value})
	_rotation_label = hud._label(box, L.text("Gebäude drehen · Eingang und Fußwege folgen mit"), 15, hud.MUTED)
	for value in [L.text("0° · Eingang vorn"), L.text("90° · Eingang rechts"), L.text("180° · Eingang hinten"), L.text("270° · Eingang links")]:
		orientation_choice.add_item(value)
	orientation_choice.custom_minimum_size.y = 44
	box.add_child(orientation_choice)
	_width_label = hud._label(box, L.text("Pistenbreite"), 15, hud.MUTED)
	_width_value = hud._label(box, "20 m", 18)
	width_slider.min_value = 14
	width_slider.max_value = 36
	width_slider.step = 2
	width_slider.custom_minimum_size.y = 42
	width_slider.value_changed.connect(func(value): _width_value.text = L.text("%.0f m · Ausbau kommt hinzu") % L.args(value))
	box.add_child(width_slider)
	hud._label(box, L.text("Auf der Karte die nummerierten Punkte ziehen. Erst ‚Übernehmen‘ bestätigt und berechnet den Umbau. Mit ‚Abbrechen‘ bleibt die bestehende Anlage erhalten."), 16, hud.MUTED, true)
	hud._spacer(box)
	hud._button(box, L.text("Auf Karte bearbeiten"), func():
		var item: Dictionary=hud.game.model.asset(id)
		var title: String=item.name if name_field.text == L.asset_name(item) else name_field.text
		if hud.game.begin_edit(id, title, color, orientation_choice.selected, width_slider.value): hide()
	, true)
	hud._button(box, L.text("Zurück"), hide)
	hide()

func _sync_colors() -> void:
	for entry in _colors:
		entry.button.text = "✓" if entry.value == color else ""

func open(asset_id: int) -> void:
	if not hud.game.points.is_empty() and hud.game.editing_id != asset_id:
		hud.toast(L.text("Zuerst die laufende Planung abschließen oder abbrechen."))
		return
	var item: Dictionary = hud.game.model.asset(asset_id)
	if item.is_empty(): return
	id = asset_id
	var editing: bool = hud.game.editing_id == id
	name_field.auto_translate_mode=Node.AUTO_TRANSLATE_MODE_DISABLED
	name_field.text = hud.game.edit_title if editing and hud.game.edit_title != item.name else L.asset_name(item)
	color = hud.game.edit_color if editing else item.get("color", "")
	orientation_choice.select(hud.game.edit_rotation if editing else int(item.get("rotation", 0)))
	width_slider.value = hud.game.edit_width if editing else item.get("width", 20)
	var building: bool = item.has("point") and not item.has("radius")
	_rotation_label.visible = building
	orientation_choice.visible = building
	for control in [_width_label, _width_value, width_slider]: control.visible = item.has("difficulty")
	_color_row.visible = not item.has("difficulty") and not item.has("radius")
	_color_label.visible = _color_row.visible
	_sync_colors()
	show()
