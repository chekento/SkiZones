extends CanvasLayer
const DragScroll = preload("res://src/ui/drag_scroll.gd")

const Catalog = preload("res://src/core/catalog.gd")
const GuestProfile = preload("res://src/core/guest_profile.gd")
const GuestFace = preload("res://src/ui/guest_face.gd")
const AssetEditor = preload("res://src/ui/asset_editor.gd")
const DisplayOptions = preload("res://src/ui/display_options.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Progression = preload("res://src/core/progression.gd")
const Palette = preload("res://src/ui/build_palette.gd")
const PlanOverlay = preload("res://src/ui/plan_overlay.gd")
const Atlas = preload("res://src/ui/atlas.gd")
const Minimap = preload("res://src/ui/minimap.gd")
const Maps = preload("res://src/core/maps.gd")
const Saves = preload("res://src/core/save_store.gd")
const Motion = preload("res://src/core/ski_motion.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const Management = preload("res://src/ui/management.gd")
const MENU_PANORAMA = preload("res://assets/menu_panorama.png")
const INK := Color("e7f2f4")
const MUTED := Color("91b0bc")
const ACCENT := Color("efb17d")
const TEAL := Color("75cdc7")

var game: Node
var root := Control.new()
var menu := Control.new()
var map_panels: Array = []
var labels: Dictionary = {}
var tool_buttons: Dictionary = {}
var inspector_title := Label.new()
var inspector_text := RichTextLabel.new()
var inspector_actions := VBoxContainer.new()
var plan_text := Label.new()
var confirm_button: Button
var undo_button: Button
var clear_button: Button
var delete_point_button: Button
var plan_overlay := PlanOverlay.new()
var pause_button: Button
var speed_buttons: Array = []
var lift_choice := OptionButton.new()
var building_choice := OptionButton.new()
var continue_button: Button
var daily_dialog := AcceptDialog.new()
var help_dialog := AcceptDialog.new()
var camera_dialog := Control.new()
var camera_panel: PanelContainer
var camera_choice := OptionButton.new()
var pitch_slider := HSlider.new()
var pitch_label: Label
var selected_id := -1
var current_tool := "inspect"
var price_label: Label
var _toast := "Willkommen am Sonnenhang. Erweitere dein Resort."
var _toast_until := 0.0
var map_focus := false
var map_focus_button: Button
var slopes_button: Button
var tools_panel: PanelContainer
var inspector_panel: PanelContainer
var plan_panel: PanelContainer
var slope_legend: PanelContainer
var management := Management.new()
var atlas := Atlas.new()
var palette := Palette.new()
var selected_guest := -1
var guest_face := GuestFace.new()
var asset_editor := AssetEditor.new()
var display_options := DisplayOptions.new()
var design_button: Button
var grooming_button: Button
var grooming_label: Label

func setup(controller: Node) -> void:
	game = controller
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", INK)
	theme.set_color("default_color", "RichTextLabel", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color("6d8b98"))
	for kind in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", kind, _style(Color("244755"), 9, 10))
		theme.set_stylebox("hover", kind, _style(Color("355d6b"), 9, 10))
		theme.set_stylebox("pressed", kind, _style(Color("3d6b73"), 9, 10))
		theme.set_stylebox("disabled", kind, _style(Color("193743"), 9, 10))
		theme.set_stylebox("focus", kind, _style(Color(0, 0, 0, 0), 9, 10, TEAL))
	root.theme = theme
	plan_overlay.game = game
	root.add_child(plan_overlay)
	_build_header()
	_build_tools()
	_build_inspector()
	_build_plan_bar()
	_build_camera_bar()
	_build_slope_legend()
	_build_menu()
	_build_dialogs()
	_build_camera_dialog()
	root.add_child(management)
	management.setup(game, self)
	root.add_child(atlas)
	atlas.setup(self)
	root.add_child(asset_editor)
	asset_editor.setup(self)
	root.add_child(display_options)
	display_options.setup(self)
	show_context("inspect")
	refresh()
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()

static func safe_content_rect(display_size: Vector2, viewport_size: Vector2, safe_area: Rect2) -> Rect2:
	var full := Rect2(Vector2.ZERO, viewport_size)
	if display_size.x <= 0 or display_size.y <= 0 or viewport_size.x <= 0 or viewport_size.y <= 0:
		return full
	var clipped := safe_area.intersection(Rect2(Vector2.ZERO, display_size))
	if not clipped.has_area():
		return full
	var scale_value := viewport_size / display_size
	return Rect2(clipped.position * scale_value, clipped.size * scale_value)

func _update_safe_area() -> void:
	var size_value := get_viewport().get_visible_rect().size
	var content := Rect2(Vector2.ZERO, size_value)
	if OS.has_feature("android") or OS.has_feature("ios"):
		content = safe_content_rect(Vector2(DisplayServer.screen_get_size()), size_value, Rect2(DisplayServer.get_display_safe_area()))
	root.offset_left = content.position.x
	root.offset_top = content.position.y
	root.offset_right = content.end.x - size_value.x
	root.offset_bottom = content.end.y - size_value.y

func _style(color: Color, radius: int = 16, padding: int = 18, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0 else 0)
	return style

func _panel(parent: Node, left: float, top: float, right: float, bottom: float, anchor_right: float = 0, anchor_bottom: float = 0) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("123342")))
	parent.add_child(panel)
	panel.anchor_right = anchor_right
	panel.anchor_left = anchor_right if left < 0 else 0
	panel.anchor_bottom = anchor_bottom
	panel.anchor_top = anchor_bottom if top < 0 else 0
	panel.offset_left = left
	panel.offset_top = top
	panel.offset_right = right
	panel.offset_bottom = bottom
	map_panels.append(panel)
	return panel

func _label(parent: Node, text_value: String, font_size: int = 18, color: Color = INK, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text_value: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 50
	button.pressed.connect(func():
		if DragScroll.click_allowed():
			callback.call()
	)
	button.focus_mode = Control.FOCUS_NONE
	if primary:
		button.add_theme_stylebox_override("normal", _style(ACCENT, 9, 10))
		button.add_theme_stylebox_override("hover", _style(ACCENT.lightened(0.12), 9, 10))
		button.add_theme_stylebox_override("pressed", _style(ACCENT.darkened(0.1), 9, 10))
		button.add_theme_color_override("font_color", Color("16323d"))
		button.add_theme_color_override("font_hover_color", Color("16323d"))
	parent.add_child(button)
	return button

func _vbox(parent: Node, gap: int = 12) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	parent.add_child(box)
	return box

func _spacer(parent: Node, vertical: bool = true) -> Control:
	var control := Control.new()
	if vertical:
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(control)
	return control

func _build_header() -> void:
	var panel := _panel(root, 24, 20, -24, 96, 1)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	panel.add_child(box)
	_label(box, "SKI / ZONES", 25, ACCENT)
	for item in [["money", "BUDGET"], ["guests", "GÄSTE"], ["rep", "RUF"], ["rides", "ABFAHRTEN"], ["clock", "BETRIEBSTAG"]]:
		var column := _vbox(box, 0)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(column, item[1], 12, MUTED)
		labels[item[0]] = _label(column, "—", 22)
	_button(box, "Speichern", game.save_game)
	_button(box, "Menü", game.show_menu)

func _build_tools() -> void:
	var panel := _panel(root, 24, 170, 316, -24, 0, 1)
	tools_panel = panel
	var box := _vbox(panel, 8)
	root.add_child(lift_choice)
	lift_choice.hide()
	root.add_child(building_choice)
	building_choice.hide()
	for kind in Catalog.LIFTS:
		lift_choice.add_item(Catalog.LIFTS[kind].name)
	lift_choice.selected = Catalog.LIFTS.keys().find("drag")
	for kind in Catalog.BUILDINGS:
		building_choice.add_item(Catalog.BUILDINGS[kind].name)
	building_choice.selected = Catalog.BUILDINGS.keys().find("lodge")
	box.add_child(palette)
	palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette.setup(self)
	var overview := Minimap.new()
	overview.game = game
	box.add_child(overview)
	_label(box, "Gebietskarte: tippen zum Navigieren", 12, MUTED)
	var navigation := HBoxContainer.new()
	box.add_child(navigation)
	_button(navigation, "Übersicht", func(): game.view.overview()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(navigation, "Hilfe", show_help).size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _build_inspector() -> void:
	var panel := _panel(root, -304, 170, -24, -180, 1, 1)
	inspector_panel = panel
	var box := _vbox(panel, 12)
	_label(box, "RESORT-KOMPASS", 13, TEAL)
	box.add_child(inspector_title)
	inspector_title.add_theme_font_size_override("font_size", 23)
	inspector_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content := _vbox(scroll, 14)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guest_face.custom_minimum_size.y = 112
	guest_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(guest_face)
	guest_face.hide()
	content.add_child(inspector_text)
	inspector_text.bbcode_enabled = true
	inspector_text.fit_content = true
	inspector_text.scroll_active = false
	inspector_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_text.add_theme_font_size_override("normal_font_size", 17)
	content.add_child(inspector_actions)
	inspector_actions.add_theme_constant_override("separation", 10)

func _build_plan_bar() -> void:
	var panel := _panel(root, 340, -156, -24, -24, 1, 1)
	plan_panel = panel
	var box := _vbox(panel, 8)
	box.add_child(plan_text)
	plan_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plan_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	confirm_button = _button(actions, "Bauen", game.confirm_plan, true)
	confirm_button.custom_minimum_size.x = 165
	undo_button = _button(actions, "Letzten Punkt zurück", game.undo_point)
	delete_point_button = _button(actions, "Punkt löschen", game.delete_waypoint)
	design_button = _button(actions, "Gestaltung", func(): asset_editor.open(game.editing_id))
	clear_button = _button(actions, "Abbrechen", game.clear_plan)
	_spacer(actions, false)
	labels.status = _label(actions, "", 15, TEAL)
	labels.status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.status.custom_minimum_size = Vector2(120, 40)
	labels.status.max_lines_visible = 2
	labels.status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	labels.status.clip_text = true
	labels.status.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _build_camera_bar() -> void:
	var panel := _panel(root, 24, 108, -24, 156, 1)
	panel.add_theme_stylebox_override("panel", _style(Color("204657"), 12, 4))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	labels.weather = _label(box, "", 15, INK)
	labels.weather.clip_text = true
	labels.weather.custom_minimum_size.x = 145
	labels.weather.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(box, "Gebiete", show_atlas).custom_minimum_size.y = 40
	var development := _button(box, "Resort-Büro", show_management, true)
	development.custom_minimum_size.y = 40
	_button(box, "Kamera", show_camera).custom_minimum_size.y = 40
	slopes_button = _button(box, "Gelände", toggle_slopes)
	slopes_button.custom_minimum_size.y = 40
	slopes_button.tooltip_text = "Höhenlinien alle 20 m, Höhenangaben und Pfeile bergab. Hangneigung und Pistenverlauf sind verschieden."
	map_focus_button = _button(box, "Mehr Karte", func(): set_map_focus(not map_focus))
	map_focus_button.custom_minimum_size.y = 40
	pause_button = _button(box, "Pause", game.toggle_pause)
	for speed in [1, 4]:
		var speed_button := _button(box, "%d×" % speed, func(): game.set_speed(speed))
		speed_button.tooltip_text = "Ruhiges Normaltempo · ein Betriebstag dauert etwa 20 Minuten" if speed == 1 else "Zeitraffer · vierfaches Tempo für Bau und Entwicklung"
		speed_buttons.append(speed_button)
	for item in [["−", func(): game.view.change_zoom(1.16)], ["+", func(): game.view.change_zoom(0.86)], ["Tal", func(): game.view.home()]]:
		var button := _button(box, item[0], item[1])
		button.custom_minimum_size = Vector2(48, 40)
	for child in box.get_children():
		if child is Button:
			child.add_theme_font_size_override("font_size", 16)

func _build_camera_dialog() -> void:
	root.add_child(camera_dialog)
	camera_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.08, 0.12, 0.64)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	camera_dialog.add_child(shade)
	camera_panel = _panel(camera_dialog, -300, -245, 300, 245, 0.5, 0.5)
	camera_panel.add_theme_stylebox_override("panel", _style(Color("123847"), 18, 24, Color("3b7780")))
	var box := _vbox(camera_panel, 16)
	_label(box, "Dein Blick auf den Berg", 24, TEAL)
	_label(box, "Die Ansicht wechselt, deine Bauplanung bleibt erhalten.", 15, MUTED, true)
	box.add_child(camera_choice)
	camera_choice.custom_minimum_size.y = 44
	for mode in game.view.CAMERA_MODES:
		camera_choice.add_item(mode)
	camera_choice.item_selected.connect(func(index: int):
		game.view.set_camera_mode(index)
		_sync_camera_controls()
	)
	pitch_label = _label(box, "", 16)
	box.add_child(pitch_slider)
	pitch_slider.custom_minimum_size.y = 40
	pitch_slider.min_value = 20
	pitch_slider.max_value = 80
	pitch_slider.step = 1
	pitch_slider.value_changed.connect(func(value: float):
		game.view.set_camera_pitch(value)
		_sync_camera_controls()
	)
	var orbit := HBoxContainer.new()
	box.add_child(orbit)
	for entry in [["↶ Drehen", func(): game.view.rotate_view(-0.3)], ["Drehen ↷", func(): game.view.rotate_view(0.3)], ["Talansicht", func(): game.view.home()]]:
		_button(orbit, entry[0], entry[1]).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(box, "Draufsicht: präzise planen. Panorama: Gelände und Gäste beobachten. Q / E dreht, C wechselt die Perspektive.", 14, MUTED, true)
	_spacer(box)
	_button(box, "Zurück zum Berg", camera_dialog.hide, true)
	camera_dialog.hide()
	_sync_camera_controls()

func _sync_camera_controls() -> void:
	camera_choice.select(game.view.camera_mode)
	pitch_slider.set_value_no_signal(minf(game.view.pitch_degrees, 80))
	pitch_slider.editable = game.view.camera_mode != 3
	pitch_label.text = "Senkrechte Draufsicht · 90°" if game.view.camera_mode == 3 else "Blickwinkel: %.0f°" % game.view.pitch_degrees

func show_camera() -> void:
	game._clear_input()
	_sync_camera_controls()
	camera_dialog.show()

func _build_slope_legend() -> void:
	slope_legend = _panel(root, 340, 176, -328, 246, 1)
	slope_legend.add_theme_stylebox_override("panel", _style(Color("204657"), 9, 10))
	_label(slope_legend, "GELÄNDE · Linien: 20 m · Pfeile: bergab\nHangneigung: Grün <8 % · Blau ≤30 % · Rot ≤55 % · Grau >55 %\nDie Pistenfarbe folgt deiner Route, nicht dieser Flächenfarbe.", 13, INK, true)
	slope_legend.hide()

func toggle_slopes() -> void:
	game.view.toggle_slopes()
	slopes_button.modulate = ACCENT if game.view.slopes_visible else Color.WHITE
	_apply_panel_visibility()

func set_map_focus(enabled: bool) -> void:
	map_focus = enabled
	map_focus_button.text = "Werkzeuge" if map_focus else "Mehr Karte"
	_apply_panel_visibility()

func _apply_panel_visibility() -> void:
	var show_game := not menu.visible
	for panel in map_panels:
		if panel.get_parent() == root:
			panel.visible = show_game
	tools_panel.visible = show_game and not map_focus
	inspector_panel.visible = show_game and not map_focus and current_tool == "inspect"
	# Keep a pending plan and its confirmation available in the wider map view.
	plan_panel.visible = show_game and (not map_focus or current_tool != "inspect" or game.model.minute >= game.model.CLOSING)
	slope_legend.visible = show_game and game.view.slopes_visible
	slope_legend.offset_left = 24 if map_focus else 340
	slope_legend.offset_right = -24 if map_focus else -328

func _build_menu() -> void:
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var panorama := TextureRect.new()
	panorama.texture = MENU_PANORAMA
	panorama.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panorama.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	panorama.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(panorama)
	panorama.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0.025, 0.08, 0.12, 0.25)
	menu.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := _panel(menu, 72, 72, 570, -72, 0, 1)
	panel.add_theme_stylebox_override("panel", _style(Color(0.045, 0.135, 0.18, 0.97), 24, 32))
	var box := _vbox(panel, 16)
	_label(box, "DEIN BERG. DEINE REGELN.", 16, TEAL)
	_label(box, "SKI\nZONES", 83, Color("f0f5f0"))
	_label(box, "Vom ersten Lift zum\nlebendigen Ski-Resort.", 26, ACCENT)
	_label(box, "Plane Abfahrten, erschließe neue Hänge und schaffe einen Ort, an den deine Gäste zurückkehren wollen.", 18, MUTED, true)
	_spacer(box)
	continue_button = _button(box, "Fortsetzen", game.continue_game, true)
	_button(box, "Gebiete entdecken", show_atlas)
	_button(box, "Darstellung & Komfort", func(): display_options.open())
	_button(box, "Freier Aufbau · alle Anlagen", func(): game.start_game(false))
	_label(box, "Ski Resort Tycoon  /  Version 0.7.0\nEine eigenständige Spielwelt von KoSch", 13, MUTED, true)

func _build_dialogs() -> void:
	root.add_child(daily_dialog)
	daily_dialog.title = "Feierabend am Berg"
	daily_dialog.ok_button_text = "Nächsten Tag starten"
	daily_dialog.confirmed.connect(game.next_day)
	daily_dialog.close_requested.connect(func(): daily_dialog.hide())
	root.add_child(help_dialog)
	help_dialog.title = "SkiZones · So wächst dein Resort"
	help_dialog.ok_button_text = "Zurück zum Berg"
	help_dialog.get_label().hide()
	var help := RichTextLabel.new()
	help.custom_minimum_size = Vector2(760, 480)
	help.bbcode_enabled = true
	help.add_theme_font_size_override("normal_font_size", 18)
	help.text = "[b]BEOBACHTEN[/b]\nBei 1× dauert ein Betriebstag etwa 20 Minuten. Skifahrer und Lifte bewegen sich bewusst ruhig. 4× beschleunigt den gesamten Betrieb.\nTippe einen Gast an und wähle ‚Diesem Gast folgen‘. Ziehen löst die Kamera. Mit + kannst du sehr nah heranzoomen.\n\n[b]BAUEN[/b]\nIm Baukatalog Pisten, Lifte oder Dorfangebote wählen. Gesperrte und zu teure Anlagen sind nicht auswählbar; die Voraussetzung steht direkt dabei. ‚Abfahrt planen‘ wählen, Wegpunkte vom Berg ins Tal setzen und mit Bauen bestätigen. Die Farbe folgt automatisch dem steilsten Teilstück der tatsächlichen Route; Serpentinen können milder sein als die direkte Abfahrt. Das Höhenprofil zeigt Höhenverlust und Gefälle. Nummerierte Planungspunkte lassen sich mit Finger oder Maus verschieben. Antippen wählt einen Punkt zum Löschen aus. Kleine Kreise markieren Anschlüsse bestehender Pisten. Starte oder beende dort eine neue Verbindung; Farbe, Kosten und Höhenprofil passen sich sofort an. Runde Schilder erhalten automatisch Farbe und Pistennummer. Spielgrenzen: Blau bis 30 %, Rot bis 55 %, Schwarz bis 110 %. Beim Lift erst Talstation, dann Bergstation setzen.\n\n[b]VERBINDUNGEN[/b]\nBeide Liftstationen erhalten begehbare Stationsplätze. Pisten starten und enden auf diesen Plätzen, mit Abstand zur Lifttechnik. Kleine Anschlusskreise zeigen die Andockpunkte. Zwischen Pisten sind weiterhin direkte Verbindungen an Wegpunkten möglich. Angeschlossene Gebäude erweitern den Fußgängerbereich um Vorplätze und sichtbare Wege. Gäste gehen dort zu anderen Liften oder zu den Gebäudeeingängen. Gäste brauchen einen vollständigen geeigneten Rundweg vom Talzugang und zurück. Auch innere Wegpunkte sind Anschlüsse: Baue eine rote oder schwarze Abkürzung zwischen den Kehren einer blauen Piste. Anfänger bleiben auf Blau, Geübte können Rot und Profis auch Schwarz nehmen. Gäste fahren nur die nötigen Teilstücke der verbundenen Pisten. Alle Pisten teilen die tatsächliche Förderkapazität eines Lifts.\n\n[b]LIFTARTEN UND GÄSTE[/b]\nTeller-Schlepplifte sind langsamer und auf 700 m begrenzt. Einer-, Zweier- und Vierersessel sind eigenständige Anlagen; der Sechser braucht Fördertechnik, der Achter die Alpine Meisterklasse. Gondeln fassen acht Gäste.\nJeder mitfahrende Gast erhält einen konkreten Fahrzeug- und Sitzplatz. Am Schlepplift bleiben die Ski am Boden. Die sichtbare Schlange folgt der Ankunft am Lift. Wartezeit und tatsächliche Auslastung stehen am Platz und im Anlageninspektor.\nGebäude werden tatsächlich besucht. Gäste gehen zum Eingang und pausieren im Gebäude; Serviceerlöse entstehen nach dem Besuch.\n\n[b]SCHNEE[/b]\nJeder Gast zieht eigene Linien. Ski verdichten Spuren und schieben Schnee auf; Unebenheiten beeinflussen spätere Fahrten. Nachts wird präpariert. Mit Schneemanagement und geöffneter Garage kannst du eine Piste auch tagsüber präparieren lassen. Sie bleibt 45 Spielminuten für neue Routen geschlossen.\n\n[b]NEUE GEBIETE[/b]\nDer Bergpass unter ‚Gebiete‘ zeigt vier Karten und ihre Freischaltziele. Sterne, Gäste und Aufträge zählen über deine Resorts hinweg. Beim Gebietswechsel wird gespeichert; jedes Resort behält seinen eigenen Spielstand. Die kleine Gebietskarte navigiert direkt zum angetippten Ort. ‚Übersicht‘ zeigt das gesamte Gebiet, ‚Tal‘ den Einstieg.\n\n[b]KARRIERE[/b]\nIm Resort-Büro pausiert der Betrieb. Dort warten Aufträge, Forschung, Ausbau und Finanzen. Ein Winter hat 28 Betriebstage; dein Resort bleibt über mehrere Winter bestehen. Wetter, Wind, Schnee und Preise beeinflussen den Betrieb.\n\n[b]KAMERA UND GELÄNDE[/b]\nUnter ‚Kamera‘ zwischen Resort, Panorama, Bauansicht und senkrechter Draufsicht wählen; der Blickwinkel ist einstellbar. ‚Gelände‘ zeigt Höhenlinien alle 20 m, Höhenangaben alle 100 m und Pfeile bergab. Flächenfarben zeigen die Hangneigung, die Pistenfarbe dagegen das Gefälle deiner Route.\n\n[b]BEDIENUNG[/b]\nTippen setzt Punkte oder wählt Anlagen und Gäste aus. Ziehen an einer nummerierten Markierung verschiebt diesen Planungspunkt; Ziehen auf freier Karte bewegt die Ansicht; zwei Finger bewegen und zoomen. Am PC: Mausrad zoomt, Q/E dreht, C wechselt die Perspektive, B plant eine Piste, M öffnet das Büro, Tab vergrößert die Karte, Leertaste pausiert, Strg+S speichert. App-Pause und Tageswechsel sichern dein Resort.\n\nGodot Engine · godotengine.org/license"
	help_dialog.add_child(help)

func show_help() -> void:
	help_dialog.popup_centered(Vector2i(800, 630))

func show_menu() -> void:
	camera_dialog.hide()
	management.hide()
	atlas.hide()
	menu.show()
	_apply_panel_visibility()
	var area: String = game.model.map_id if game.has_game else game.passport.data.last_map
	var path := Saves.path_for_map(area)
	continue_button.text = "Fortsetzen · " + Maps.spec(area).name
	continue_button.disabled = not game.has_game and not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak")

func hide_menu() -> void:
	menu.hide()
	_apply_panel_visibility()

func blocks_map(point: Vector2) -> bool:
	if asset_editor.visible or display_options.visible or menu.visible or daily_dialog.visible or help_dialog.visible or camera_dialog.visible or management.visible or atlas.visible:
		return true
	for panel in map_panels:
		if is_instance_valid(panel) and panel.is_visible_in_tree() and panel.get_global_rect().has_point(point):
			return true
	return false

func lift_kind() -> String:
	return Catalog.LIFTS.keys()[lift_choice.selected]

func building_kind() -> String:
	return Catalog.BUILDINGS.keys()[building_choice.selected]

func show_atlas() -> void:
	camera_dialog.hide()
	management.hide()
	atlas.open()

func show_management(tab: int = 0) -> void:
	camera_dialog.hide()
	atlas.hide()
	management.open()
	management.tabs.current_tab = clampi(tab, 0, 4)

func show_context(tool: String, id: int = -1) -> void:
	current_tool = tool
	selected_guest = -1
	game.view.selected_guest = -1
	guest_face.hide()
	if tool == "piste":
		palette.select_category("pistes")
	elif tool == "plaza":
		palette.select_category("paths")
	elif tool in ["lift", "building"]:
		palette.select_category("lifts" if tool == "lift" else "village")
	selected_id = id
	if tool != "inspect" or id != -1:
		set_map_focus(false)
	price_label = null
	grooming_button = null
	grooming_label = null
	for child in inspector_actions.get_children():
		inspector_actions.remove_child(child)
		child.queue_free()
	for key in tool_buttons:
		tool_buttons[key].add_theme_stylebox_override("normal", _style(Color("345c68") if key == tool else Color("244755"), 9, 10, TEAL if key == tool else Color.TRANSPARENT))
	if id != -1:
		var item: Dictionary = game.model.asset(id)
		inspector_title.text = item.get("name", "Anlage")
		_button(inspector_actions, "Gestalten & umplanen", func(): asset_editor.open(id), true)
		_button(inspector_actions, "Schließen" if item.get("enabled", false) else "Öffnen", func(): game.toggle_asset(id))
		_button(inspector_actions, "Abbauen · 25 % Erstattung", func(): game.demolish_asset(id))
		if not item.has("radius"):
			_button(inspector_actions, "Anlage ausbauen", func(): show_management(3), true)
		if item.has("difficulty"):
			var check: Dictionary = game.model.groom_check(id)
			var groom := _button(inspector_actions, "Piste präparieren", func():
				var result: Dictionary = game.model.groom_piste(id)
				toast(result.message)
				show_context("inspect", id)
			)
			grooming_button = groom
			groom.disabled = not check.ok
			groom.tooltip_text = check.message
			grooming_label = _label(inspector_actions, check.message, 13, MUTED, true)
	elif tool == "inspect":
		inspector_title.text = Maps.spec(game.model.map_id).name
		price_label = _label(inspector_actions, "Tageskarte: %d €" % game.model.ticket_price, 18)
		var slider := HSlider.new()
		slider.min_value = 20
		slider.max_value = 95
		slider.step = 1
		slider.value = game.model.ticket_price
		slider.custom_minimum_size.y = 40
		inspector_actions.add_child(slider)
		slider.value_changed.connect(func(value):
			game.model.ticket_price = int(value)
			price_label.text = "Tageskarte: %d €" % int(value)
		)
		_button(inspector_actions, "Kredit tilgen · 150.000 €" if game.model.loan > 0 else "Aufbaukredit · 150.000 €", game.manage_loan)
	elif tool == "lift":
		inspector_title.text = lift_choice.get_item_text(lift_choice.selected)
	elif tool == "plaza":
		inspector_title.text = Catalog.PLAZAS[game.plaza_kind].name
	elif tool == "building":
		inspector_title.text = building_choice.get_item_text(building_choice.selected)
	else:
		inspector_title.text = "Abfahrt planen"
	_refresh_context_text()
	_apply_panel_visibility()

func show_guest(id: int) -> void:
	show_context("inspect")
	selected_guest = id
	game.view.selected_guest = id
	set_map_focus(false)
	for child in inspector_actions.get_children():
		inspector_actions.remove_child(child)
		child.queue_free()
	_button(inspector_actions, "Diesem Gast folgen", func():
		game.view.follow_guest = id
		game.view.zoom = 90
		game.view._update_camera()
	, true)
	_button(inspector_actions, "Kamera lösen", func(): game.view.follow_guest = -1)
	_refresh_context_text()

func _refresh_context_text() -> void:
	var model: RefCounted = game.model
	if selected_guest != -1:
		for guest in model.guests:
			if int(guest.id) != selected_guest:
				continue
			var profile := GuestProfile.describe(model, guest)
			inspector_title.text = profile.name
			guest_face.update_face(profile.mood, Color(Motion.COLORS[int(guest.id) % Motion.COLORS.size()]))
			inspector_text.text = "[color=#efb17d]%s[/color]\n%s\n\n[color=#75cdc7]%d Jahre · aus %s[/color]\n%s · %s\n\n%s\n\n[color=#efb17d]DEIN SKITAG[/color]\n%d %s · %d Runden\n%d Min. im Resort\n%d Min. insgesamt gewartet\nTagesgefühl: %.0f %%\n\nEnergie: %.0f %%\nHunger: %.0f %%\nWärmegefühl: %.0f %%\n\nFahrstil: %s\nTempo: %.1f m/s\nAusgaben: %s €" % [profile.emotion, profile.reason, profile.years, profile.home, ["Anfänger", "Geübt", "Profi"][guest.ability], profile.motive, profile.activity, guest.get("runs", 0), "Abfahrt" if guest.get("runs", 0) == 1 else "Abfahrten", guest.loops, guest.age, guest.total_wait, profile.score, profile.energy, profile.hunger, profile.warmth, profile.style, profile.speed, money_text(profile.spending)]
			return
		inspector_title.text = "Ein schöner Skitag geht zu Ende"
		inspector_text.text = "Dieser Gast hat das Resort verlassen. Wähle einen anderen Gast oder eine Anlage."
		return
	if selected_id != -1:
		var item: Dictionary = model.asset(selected_id)
		if item.is_empty():
			show_context("inspect")
			return
		var text_value := "[color=#75cdc7]%s · Stufe %d[/color]\n\n" % ["Geöffnet" if item.enabled else "Geschlossen", item.get("level", 1)]
		if item.has("difficulty"):
			if is_instance_valid(grooming_button):
				var grooming: Dictionary = model.groom_check(item.id)
				grooming_button.disabled = not grooming.ok
				grooming_button.tooltip_text = grooming.message
				grooming_label.text = grooming.message
			text_value += "Piste %d · %s\n%.0f m Länge · ↓ %.0f m\nØ %.0f %% · Max. %.0f %% Gefälle\nZustand: %.0f %%\nSchnee: %.0f cm\n%d Abfahrten\n\n%s" % [item.number, ["Blau · leicht", "Rot · mittel", "Schwarz · schwer"][item.difficulty], item.length, item.drop, item.average, item.grade, item.condition, item.snow, item.rides, "Mit Rundweg erreichbar" if model.reachable_piste_ids().has(item.id) else "Noch kein nutzbarer Rundweg"]
			text_value += "\nPistenbreite: %.0f m" % Snow.piste_width(item)
			text_value += "\nLokale Unebenheiten: %.0f %%\nNächtliche Präparierung glättet Spuren und Buckel." % (Snow.roughness(item) * 100)
		elif item.has("bottom"):
			var load: Dictionary = model.lift_load(item)
			var seat_text := "1 Zugplatz je Teller" if item.kind == "drag" else ("%d %s je Fahrzeug" % [load.seats, "Platz" if load.seats == 1 else "Plätze"])
			text_value += "%s\n%d Fahrzeuge im Umlauf\n%.1f m/s · %.1f Min. Fahrt\n%d Gäste pro Stunde\n\n%d warten · ca. %.1f Min. Wartezeit\n%d fahren gerade mit\n%.0f %% mittlere Auslastung\n%d Beförderungen\n\n%s" % [seat_text, load.carriers, model.lift_speed(item) / 60, item.length / model.lift_speed(item), model.lift_capacity(item), load.queue, load.wait, load.riders, load.fill * 100, item.boarded, "Betrieb möglich" if model.lift_open(item) else "Wegen Wind oder manuell geschlossen"]
		elif item.has("radius"):
			text_value += "Ø %.0f m · Begehbare Fläche\nPisten und Gebäude können hier anschließen.\nLifttechnik und Zugspuren bleiben gesperrt." % (item.radius * 2)
		else:
			text_value += "%s\n\nBetrieb: %d €/Tag\n%d tatsächliche Besuche\nServiceerlöse: %s €" % [Catalog.BUILDINGS[item.kind].description, Catalog.BUILDINGS[item.kind].upkeep, item.get("visits", 0), money_text(item.get("revenue", 0))]
		inspector_text.text = text_value
	elif current_tool == "inspect":
		var piste_word := "Piste" if model.pistes.size() == 1 else "Pisten"
		var lift_word := "Lift" if model.lifts.size() == 1 else "Lifte"
		inspector_text.text = "[color=#efb17d]%s[/color]\nWinter %d · Tag %d / 28\n%.0f Erfahrung · %d FP\n\n%d %s · %d %s\n%d erreichbare Abfahrten\n%d Gäste warten\n\n[color=#efb17d]DEIN NÄCHSTES ZIEL[/color]\n%s\n\n[color=#efb17d]HEUTE[/color]\nErlöse: %s €\nBetrieb: ~%s €/Tag\n\nAufträge, Forschung und Ausbau findest du im Resort-Büro." % ["★".repeat(model.campaign.rank), Progression.season_number(model), Progression.season_day(model), model.campaign.xp, model.campaign.points, model.pistes.size(), piste_word, model.lifts.size(), lift_word, model.reachable_piste_ids().size(), model.queue_size(), Progression.next_goal(model), money_text(model.report.tickets + model.report.services), money_text(model.operating_costs())]
	elif current_tool == "lift":
		var spec: Dictionary = Catalog.LIFTS[lift_kind()]
		inspector_text.text = "[color=#efb17d]%s € + %d €/m[/color]\n\n%d Plätze je Fahrzeug\n%.1f m/s · max. %.0f m Länge\n%d Gäste pro Stunde\n%d €/Tag Betrieb\nWindgrenze: %.0f km/h\n\n1. Talstation setzen\n2. Bergstation setzen\n3. Bau bestätigen\n\nBeide Stationen erhalten einen begehbaren Platz. Pisten docken am Platz an; Gebäude erweitern das Fußwegenetz. Der Achter wird durch Alpine Meisterklasse freigeschaltet." % [money_text(spec.cost), spec.per_m, spec.seats, spec.speed / 60, spec.max_length, spec.capacity, spec.upkeep, spec.wind_limit]
		var access: String = model.build_access_message(lift_kind(), true)
		if access != "":
			inspector_text.text = "[color=#efb17d]%s[/color]\nIm Resort-Büro freischalten.\n\n" % access + inspector_text.text
	elif current_tool == "plaza":
		var spec: Dictionary = Catalog.PLAZAS[game.plaza_kind]
		inspector_text.text = "[color=#efb17d]%s € · Ø %.0f m[/color]\n\n%s\n\n1. Freie Fläche antippen\n2. Anschluss prüfen\n3. Bauen bestätigen\n\nMit Abbrechen oder der Zurück-Taste verlässt du die Planung." % [money_text(spec.cost), spec.radius * 2, spec.description]
	elif current_tool == "building":
		var spec: Dictionary = Catalog.BUILDINGS[building_kind()]
		inspector_text.text = "[color=#efb17d]%s € Baukosten[/color]\n%d €/Tag Betrieb\n\n%s\n\nAuf einen freien Bauplatz tippen und den Bau bestätigen." % [money_text(spec.cost), spec.upkeep, spec.description]
		var access: String = model.build_access_message(building_kind(), false)
		if access != "":
			inspector_text.text = "[color=#efb17d]%s[/color]\nIm Resort-Büro freischalten.\n\n" % access + inspector_text.text
	else:
		inspector_text.text = "[color=#75cdc7]FARBE AUS DEINER ROUTE[/color]\nBlau, Rot oder Schwarz entstehen automatisch aus dem steilsten Teilstück deiner geplanten Abfahrt.\n\nSerpentinen verlängern die Strecke und können ihr Gefälle senken. Steile Abschnitte werden nicht durch einen niedrigen Durchschnitt versteckt.\n\n[color=#efb17d]BESSER PLANEN[/color]\n‚Gelände‘ zeigt Höhenlinien und Pfeile bergab. Die Draufsicht im Kameramenü hilft beim Setzen der Kurven. Links siehst du das Höhenprofil. Nummerierte Punkte lassen sich ziehen und einzeln löschen. Kleine Kreise sind Andockpunkte bestehender Pisten.\n\nBaue Abkürzungen von einem Andockpunkt zum nächsten. Die Gäste wählen passende Wege für ihr Können. Runde Schilder mit einer festen Pistennummer werden beim Bauen aufgestellt.\n\nSpielgrenzen: Blau ≤30 %, Rot ≤55 %, Schwarz ≤110 %. "
		var check: Dictionary = game.last_plan_check
		if check.has("profile") and check.profile.size() >= 2:
			inspector_text.text = "[color=#efb17d]DEINE ABFAHRT[/color]\n%.0f → %.0f m\n%.0f m Länge · ↓ %.0f m\nMax. %.0f %% · Ø %.0f %%\n\n" % [check.profile[0].height, check.profile[-1].height, check.length, check.drop, check.grade, check.average] + inspector_text.text

func money_text(amount: float) -> String:
	var source := str(roundi(amount))
	var output := ""
	var count := 0
	for i in range(source.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0 and source[i] != "-":
			output = "." + output
		output = source[i] + output
		count += 1
	return output

func refresh() -> void:
	var model: RefCounted = game.model
	labels.money.text = money_text(model.money) + " €"
	labels.guests.text = "%d / %d" % [model.guests.size(), model.total_guests]
	labels.rep.text = "%.0f %%" % model.reputation
	labels.rides.text = str(model.total_rides)
	labels.clock.text = "Tag %d · %02d:%02d" % [model.day, model.minute / 60, model.minute % 60]
	labels.weather.text = "%s   /   %.0f °C   /   Wind %.0f km/h" % [model.weather().name, model.weather().temperature, model.weather().wind]
	pause_button.text = "Weiter" if game.paused else "Pause"
	for i in range(speed_buttons.size()):
		speed_buttons[i].modulate = ACCENT if game.speed == [1, 4][i] else Color.WHITE
	_refresh_context_text()
	palette.refresh()
	if Time.get_ticks_msec() / 1000.0 < _toast_until:
		labels.status.text = _toast
	else:
		labels.status.text = "Baupause" if not game.points.is_empty() else "Simulation pausiert" if game.paused else "%d× · %d Gäste warten" % [game.speed, model.queue_size()]

func plan(message: String, can_build: bool, point_count: int, cost: float = 0) -> void:
	plan_text.text = message
	confirm_button.text = "Bauen · %s €" % money_text(cost) if cost > 0 else "Bauen"
	if game.editing_id != -1:
		confirm_button.text = "Übernehmen · %s €" % money_text(cost)
	design_button.visible = game.editing_id != -1
	confirm_button.disabled = not can_build
	confirm_button.visible = current_tool != "inspect"
	undo_button.visible = current_tool in ["piste", "lift"]
	undo_button.disabled = point_count == 0
	delete_point_button.visible = current_tool == "piste"
	delete_point_button.disabled = game.selected_waypoint < 0 or game.selected_waypoint >= point_count
	clear_button.visible = current_tool != "inspect"
	palette.refresh()
	if current_tool == "inspect" and game.model.minute >= game.model.CLOSING:
		confirm_button.visible = true
		confirm_button.disabled = false
		confirm_button.text = "Tagesbericht ansehen"

func toast(message: String) -> void:
	_toast = message
	_toast_until = Time.get_ticks_msec() / 1000.0 + 8.0
	labels.status.text = message
	labels.status.tooltip_text = message

func show_report() -> void:
	var report: Dictionary = game.model.last_report
	if report.is_empty():
		return
	var satisfaction: float = report.satisfaction / maxf(1, report.departures)
	var operating: float = report.tickets + report.services - report.costs
	daily_dialog.dialog_text = "Winter %d · Tag %d / 28\n%d Tagesgäste · %d Abfahrten · %.0f %% Zufriedenheit\n\nTageskarten: %s €\nServices: %s €\nBetriebskosten: −%s €\nBetriebliches Ergebnis: %s €\n\nInvestitionen und Forschung: −%s €\nPrämien: %s €\nErgebnis nach Investitionen: %s €\nVerfügbares Budget: %s €\n\n%d Resort-Sterne · %d Forschungspunkte\n%s\n\nAufträge und Ausbauten findest du im Resort-Büro.\nÜber Nacht werden die Pisten präpariert." % [Progression.season_number(game.model), Progression.season_day(game.model), report.guests, report.rides, satisfaction, money_text(report.tickets), money_text(report.services), money_text(report.costs), money_text(operating), money_text(report.get("investments", 0.0)), money_text(report.rewards), money_text(operating + report.rewards - report.get("investments", 0.0)), money_text(game.model.money), game.model.campaign.rank, game.model.campaign.points, game.model.campaign.notice]
	daily_dialog.get_label().add_theme_font_size_override("font_size", 20)
	daily_dialog.popup_centered(Vector2i(760, 640))
