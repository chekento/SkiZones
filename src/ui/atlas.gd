extends PanelContainer
const L = preload("res://src/core/i18n.gd")
const DragScroll = preload("res://src/ui/drag_scroll.gd")
const Maps = preload("res://src/core/maps.gd")
const Minimap = preload("res://src/ui/minimap.gd")
const Saves = preload("res://src/core/save_store.gd")
var hud: CanvasLayer
var game: Node
var body: VBoxContainer
var _cards: Array = []

func setup(interface: CanvasLayer) -> void:
	hud = interface
	game = hud.game
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 48
	offset_right = -48
	offset_top = 120
	offset_bottom = -28
	add_theme_stylebox_override("panel", hud._style(Color("fffaf2"), 18, 22))
	body = hud._vbox(self, 10)
	var header := HBoxContainer.new()
	body.add_child(header)
	hud._label(header, L.text("DEIN BERGPASS"), 27, hud.ACCENT)
	hud._spacer(header, false)
	hud._button(header, L.text("Zurück"), hide)
	hud._label(body, L.text("Acht Gebiete. Acht eigene Resorts. Dein Fortschritt öffnet neue Täler; jedes Resort bleibt separat gespeichert."), 17, hud.MUTED, true)
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for id_value in Maps.MAPS:
		var id: String = id_value
		var spec: Dictionary = Maps.spec(id)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", hud._style(Color("edf3ec"), 12, 15))
		grid.add_child(panel)
		var card: VBoxContainer = hud._vbox(panel, 6)
		hud._label(card, L.text("%s · %.1f km²") % L.args([spec.name, Maps.area(id)]), 22, Color(spec.color), true)
		hud._label(card, spec.subtitle, 15, hud.TEAL, true)
		var preview := HBoxContainer.new()
		preview.add_theme_constant_override("separation", 14)
		card.add_child(preview)
		var thumbnail := Minimap.new()
		thumbnail.map_id = id
		thumbnail.interactive = false
		thumbnail.custom_minimum_size = Vector2(150, 110)
		preview.add_child(thumbnail)
		var description: Label = hud._label(preview, spec.description, 14, hud.MUTED, true)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hud._label(card, L.text(spec.start), 14, hud.TEAL, true)
		var requirement: Label = hud._label(card, "", 14, hud.TEAL, true)
		var enter: Button = hud._button(card, "", func(): game.enter_area(id), true)
		_cards.append({"id": id, "requirement": requirement, "enter": enter})
	hide()

func open() -> void:
	game._clear_input()
	if game.has_game:
		game.passport.record(game.model)
	for card in _cards:
		var unlocked: bool = game.passport.unlocked(card.id)
		card.requirement.text = L.text("Gebiet freigeschaltet") if unlocked else game.passport.requirement(card.id)
		var saved := FileAccess.file_exists(Saves.path_for_map(card.id))
		card.enter.text = L.text("Zurück zu deinem Resort") if game.has_game and game.model.map_id == card.id else (L.text("Resort fortsetzen") if saved else L.text("Resort eröffnen"))
		if not unlocked:
			card.enter.text = L.text("Noch nicht freigeschaltet")
		card.enter.disabled = not unlocked
	show()
