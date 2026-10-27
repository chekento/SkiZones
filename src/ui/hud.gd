extends CanvasLayer

const Catalog = preload("res://src/core/catalog.gd")
const Terrain = preload("res://src/core/terrain.gd")
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
var pause_button: Button
var speed_buttons: Array = []
var lift_choice := OptionButton.new()
var building_choice := OptionButton.new()
var continue_button: Button
var daily_dialog := AcceptDialog.new()
var help_dialog := AcceptDialog.new()
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
	_build_header()
	_build_tools()
	_build_inspector()
	_build_plan_bar()
	_build_camera_bar()
	_build_slope_legend()
	_build_menu()
	_build_dialogs()
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
	button.pressed.connect(callback)
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
	var panel := _panel(root, 24, 170, 268, -24, 0, 1)
	tools_panel = panel
	var box := _vbox(panel, 10)
	_label(box, "BAUPLANUNG", 13, TEAL)
	_label(box, "Dein Resort wächst.", 21)
	var names := [["inspect", "Resort ansehen"], ["blue", "●   Blaue Piste"], ["red", "●   Rote Piste"], ["black", "●   Schwarze Piste"], ["lift", "Lift planen"]]
	for item in names:
		var button := _button(box, item[1], func(): game.set_tool(item[0]))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tool_buttons[item[0]] = button
	tool_buttons.blue.add_theme_color_override("font_color", Color("8dc9f2"))
	tool_buttons.red.add_theme_color_override("font_color", Color("efa0a5"))
	tool_buttons.black.add_theme_color_override("font_color", Color("ced7df"))
	box.add_child(lift_choice)
	lift_choice.custom_minimum_size.y = 48
	for kind in Catalog.LIFTS:
		lift_choice.add_item(Catalog.LIFTS[kind].name)
	lift_choice.selected = 1
	lift_choice.item_selected.connect(func(_index): game.set_tool("lift"))
	tool_buttons.building = _button(box, "Gebäude platzieren", func(): game.set_tool("building"))
	box.add_child(building_choice)
	building_choice.custom_minimum_size.y = 48
	for kind in Catalog.BUILDINGS:
		building_choice.add_item(Catalog.BUILDINGS[kind].name)
	building_choice.item_selected.connect(func(_index): game.set_tool("building"))
	_spacer(box)
	_label(box, "Ziehen: Karte bewegen\n2 Finger: bewegen & zoomen", 14, MUTED, true)
	_button(box, "Hilfe & Spielregeln", show_help)

func _build_inspector() -> void:
	var panel := _panel(root, -304, 170, -24, -180, 1, 1)
	inspector_panel = panel
	var box := _vbox(panel, 12)
	_label(box, "RESORT-KOMPASS", 13, TEAL)
	box.add_child(inspector_title)
	inspector_title.add_theme_font_size_override("font_size", 23)
	inspector_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content := _vbox(scroll, 14)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(inspector_text)
	inspector_text.bbcode_enabled = true
	inspector_text.fit_content = true
	inspector_text.scroll_active = false
	inspector_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_text.add_theme_font_size_override("normal_font_size", 17)
	content.add_child(inspector_actions)
	inspector_actions.add_theme_constant_override("separation", 10)

func _build_plan_bar() -> void:
	var panel := _panel(root, 292, -156, -24, -24, 1, 1)
	plan_panel = panel
	var box := _vbox(panel, 8)
	box.add_child(plan_text)
	plan_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plan_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	confirm_button = _button(actions, "Bauen", game.confirm_plan, true)
	confirm_button.custom_minimum_size.x = 190
	undo_button = _button(actions, "Letzten Punkt zurück", game.undo_point)
	clear_button = _button(actions, "Plan verwerfen", game.clear_plan)
	_spacer(actions, false)
	labels.status = _label(actions, "", 15, TEAL)
	labels.status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_camera_bar() -> void:
	var panel := _panel(root, 24, 108, -24, 156, 1)
	panel.add_theme_stylebox_override("panel", _style(Color("204657"), 12, 4))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	labels.weather = _label(box, "", 16, INK)
	_spacer(box, false)
	slopes_button = _button(box, "Gefälle", toggle_slopes)
	slopes_button.custom_minimum_size.y = 40
	slopes_button.tooltip_text = "Zeigt die stärkste Neigung am Bauplatz. Serpentinen können mildere Abfahrten ermöglichen."
	map_focus_button = _button(box, "Mehr Karte", func(): set_map_focus(not map_focus))
	map_focus_button.custom_minimum_size.y = 40
	pause_button = _button(box, "Pause", game.toggle_pause)
	for speed in [1, 4]:
		speed_buttons.append(_button(box, "%d×" % speed, func(): game.set_speed(speed)))
	for item in [["−", func(): game.view.change_zoom(1.16)], ["+", func(): game.view.change_zoom(0.86)], ["↶", func(): game.view.rotate_view(-0.2)], ["↷", func(): game.view.rotate_view(0.2)], ["Zentrieren", func(): game.view.home()]]:
		var button := _button(box, item[0], item[1])
		button.custom_minimum_size = Vector2(48, 40)

func _build_slope_legend() -> void:
	slope_legend = _panel(root, 292, 176, -328, 224, 1)
	slope_legend.add_theme_stylebox_override("panel", _style(Color("204657"), 9, 10))
	_label(slope_legend, "Hanggefälle: Grün <8 % · Blau ≤30 % · Rot ≤55 % · Grau >55 %", 15, INK, true)
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
	inspector_panel.visible = show_game and not map_focus
	# Keep a pending plan and its confirmation available in the wider map view.
	plan_panel.visible = show_game and (not map_focus or current_tool != "inspect" or game.model.minute >= game.model.CLOSING)
	slope_legend.visible = show_game and game.view.slopes_visible
	slope_legend.offset_left = 24 if map_focus else 292
	slope_legend.offset_right = -24 if map_focus else -328

func _build_menu() -> void:
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_button(box, "Neues Resort · Sonnenhang", func(): game.start_game(true))
	_button(box, "Freier Aufbau · leeres Gelände", func(): game.start_game(false))
	_label(box, "Ski Resort Tycoon  /  Version 0.1.1\nEine eigenständige Spielwelt von KoSch", 13, MUTED, true)

func _build_dialogs() -> void:
	root.add_child(daily_dialog)
	daily_dialog.title = "Feierabend am Berg"
	daily_dialog.ok_button_text = "Nächsten Tag starten"
	daily_dialog.confirmed.connect(game.next_day)
	daily_dialog.close_requested.connect(func(): daily_dialog.hide())
	root.add_child(help_dialog)
	help_dialog.title = "SkiZones · So wächst dein Resort"
	help_dialog.ok_button_text = "Zurück zum Berg"
	help_dialog.dialog_text = "PISTEN: Vom Berg ins Tal mehrere Wegpunkte setzen und mit Bauen bestätigen.\nBlau: bis 30 %, Rot: bis 55 %, Schwarz: bis 110 % Gefälle.\nDas sind Spielregeln; das gesamte Streckenprofil wird geprüft.\n\nLIFTE: Erst die Talstation, dann die Bergstation setzen.\nStationen und Pistenenden verbinden sich im Umkreis von 42 m.\nIm Tal können Gäste zwischen Anlagen bis 220 m zu Fuß gehen.\nEin nutzbarer Rundweg vom Talzugang und zurück ist erforderlich.\n\nGÄSTE: Anfänger fahren blau, Geübte zusätzlich rot, Profis alle Farben.\nAlle Abfahrten teilen die Kapazität des jeweiligen Lifts.\n\nBETRIEB: Ein Tag läuft von 08:00 bis 18:00. Starker Wind stoppt\nempfindliche Lifte, Tauwetter reduziert Schnee, Gäste verschleißen Pisten.\nNachts wird präpariert. Gebäude erhöhen Komfort oder Einnahmen.\n\nBEDIENUNG: Tippen setzt Wegpunkte oder wählt eine Anlage aus.\nZiehen bewegt die Karte, zwei Finger bewegen und zoomen.\nAm PC: Mausrad zoomt, Q/E dreht, Leertaste pausiert, Strg+S speichert.\nSpeichern, Tageswechsel und App-Pause sichern dein Resort.\n\nGodot Engine · godotengine.org/license"
	help_dialog.get_label().add_theme_font_size_override("font_size", 18)

func show_help() -> void:
	help_dialog.popup_centered(Vector2i(800, 630))

func show_menu() -> void:
	menu.show()
	_apply_panel_visibility()
	continue_button.disabled = not game.has_game and not FileAccess.file_exists("user://skizones_save.json") and not FileAccess.file_exists("user://skizones_save.json.bak")

func hide_menu() -> void:
	menu.hide()
	_apply_panel_visibility()

func blocks_map(point: Vector2) -> bool:
	if menu.visible or daily_dialog.visible or help_dialog.visible:
		return true
	for panel in map_panels:
		if is_instance_valid(panel) and panel.is_visible_in_tree() and panel.get_global_rect().has_point(point):
			return true
	return false

func lift_kind() -> String:
	return Catalog.LIFTS.keys()[lift_choice.selected]

func building_kind() -> String:
	return Catalog.BUILDINGS.keys()[building_choice.selected]

func show_context(tool: String, id: int = -1) -> void:
	current_tool = tool
	selected_id = id
	if tool != "inspect" or id != -1:
		set_map_focus(false)
	price_label = null
	for child in inspector_actions.get_children():
		inspector_actions.remove_child(child)
		child.queue_free()
	for key in tool_buttons:
		tool_buttons[key].add_theme_stylebox_override("normal", _style(Color("345c68") if key == tool else Color("244755"), 9, 10, TEAL if key == tool else Color.TRANSPARENT))
	if id != -1:
		var item: Dictionary = game.model.asset(id)
		inspector_title.text = item.get("name", "Anlage")
		_button(inspector_actions, "Schließen" if item.get("enabled", false) else "Öffnen", func(): game.toggle_asset(id))
		_button(inspector_actions, "Abbauen · 25 % Erstattung", func(): game.demolish_asset(id))
	elif tool == "inspect":
		inspector_title.text = "Sonnenhang"
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
	elif tool == "building":
		inspector_title.text = building_choice.get_item_text(building_choice.selected)
	else:
		inspector_title.text = {"blue": "Blaue Piste", "red": "Rote Piste", "black": "Schwarze Piste"}.get(tool, "Bauplanung")
	_refresh_context_text()

func _refresh_context_text() -> void:
	var model: RefCounted = game.model
	if selected_id != -1:
		var item: Dictionary = model.asset(selected_id)
		if item.is_empty():
			show_context("inspect")
			return
		var text_value := "[color=#75cdc7]%s[/color]\n\n" % ("Geöffnet" if item.enabled else "Geschlossen")
		if item.has("difficulty"):
			text_value += "%.0f m Länge\nMax. %.0f %% Gefälle\nZustand: %.0f %%\nSchnee: %.0f cm\n%d Abfahrten\n\n%s" % [item.length, item.grade, item.condition, item.snow, item.rides, "Mit Rundweg erreichbar" if model.reachable_piste_ids().has(item.id) else "Noch kein nutzbarer Rundweg"]
		elif item.has("bottom"):
			text_value += "%d Gäste pro Stunde\n%d Gäste warten\n%d Beförderungen\n\n%s" % [Catalog.LIFTS[item.kind].capacity, model.queue_size(item.id), item.boarded, "Betrieb möglich" if model.lift_open(item) else "Wegen Wind oder manuell geschlossen"]
		else:
			text_value += "%s\n\nBetrieb: %d €/Tag" % [Catalog.BUILDINGS[item.kind].description, Catalog.BUILDINGS[item.kind].upkeep]
		inspector_text.text = text_value
	elif current_tool == "inspect":
		var goals := ["100 Abfahrten", "Alle 3 Pistenfarben erreichbar", "750 Tagesgäste", "80 % Resort-Ruf"]
		var goal_text := ""
		for i in range(goals.size()):
			goal_text += ("[color=#75cdc7]✓ " if model.achievements.has(i) else "[color=#91b0bc]○ ") + goals[i] + "[/color]\n"
		var piste_word := "Piste" if model.pistes.size() == 1 else "Pisten"
		var lift_word := "Lift" if model.lifts.size() == 1 else "Lifte"
		inspector_text.text = "[b]%d %s · %d %s[/b]\n%d erreichbare Abfahrten\n%d Gäste in Warteschlangen\n\n[color=#efb17d]HEUTE[/color]\nEintritte: %s €\nServices: %s €\nBetrieb: ~%s €/Tag\n\n[color=#efb17d]DEINE MEILENSTEINE[/color]\n%s\nAnlagen antippen, um den Betrieb zu prüfen. Gefälle blendet die Hangneigung ein; Mehr Karte vergrößert die freie Ansicht." % [model.pistes.size(), piste_word, model.lifts.size(), lift_word, model.reachable_piste_ids().size(), model.queue_size(), money_text(model.report.tickets), money_text(model.report.services), money_text(model.operating_costs()), goal_text]
	elif current_tool == "lift":
		var spec: Dictionary = Catalog.LIFTS[lift_kind()]
		inspector_text.text = "[color=#efb17d]%s € + %d €/m[/color]\n\n%d Gäste pro Stunde\n%d €/Tag Betrieb\nWindgrenze: %.0f km/h\n\n1. Talstation setzen\n2. Bergstation setzen\n3. Bau bestätigen\n\nDie Abfahrt muss von der Bergstation erreichbar sein und wieder ins Tal führen." % [money_text(spec.cost), spec.per_m, spec.capacity, spec.upkeep, spec.wind_limit]
	elif current_tool == "building":
		var spec: Dictionary = Catalog.BUILDINGS[building_kind()]
		inspector_text.text = "[color=#efb17d]%s € Baukosten[/color]\n%d €/Tag Betrieb\n\n%s\n\nAuf einen freien Bauplatz tippen und den Bau bestätigen." % [money_text(spec.cost), spec.upkeep, spec.description]
	else:
		var difficulty: int = {"blue": 0, "red": 1, "black": 2}.get(current_tool, 0)
		inspector_text.text = "[color=#efb17d]Bis %.0f %% Gefälle[/color]\n%d € pro Streckenmeter\n\nWegpunkte vom Berg ins Tal setzen. Kurven und Serpentinen helfen, steile Hänge zu erschließen.\n\nDer gesamte Streckenverlauf zählt. Bergauf führende Abschnitte sind nicht als Abfahrt nutzbar.\n\nPistenenden und Stationen verbinden sich innerhalb von 42 m." % [Terrain.GRADE_LIMITS[difficulty], [32, 44, 58][difficulty]]

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
	if Time.get_ticks_msec() / 1000.0 < _toast_until:
		labels.status.text = _toast
	else:
		labels.status.text = "Simulation pausiert" if game.paused else "%d× · %d Gäste warten" % [game.speed, model.queue_size()]

func plan(message: String, can_build: bool, point_count: int, cost: float = 0) -> void:
	plan_text.text = message
	confirm_button.text = "Bauen · %s €" % money_text(cost) if cost > 0 else "Bauen"
	confirm_button.disabled = not can_build
	confirm_button.visible = current_tool != "inspect"
	undo_button.visible = current_tool in ["blue", "red", "black", "lift"]
	undo_button.disabled = point_count == 0
	clear_button.visible = current_tool != "inspect"
	if current_tool == "inspect" and game.model.minute >= game.model.CLOSING:
		confirm_button.visible = true
		confirm_button.disabled = false
		confirm_button.text = "Tagesbericht ansehen"

func toast(message: String) -> void:
	_toast = message
	_toast_until = Time.get_ticks_msec() / 1000.0 + 8.0
	labels.status.text = message

func show_report() -> void:
	var report: Dictionary = game.model.last_report
	if report.is_empty():
		return
	var satisfaction: float = report.satisfaction / maxf(1, report.departures)
	daily_dialog.dialog_text = "Tag %d · Dein Berg in Zahlen\n\n%d Tagesgäste · %d Abfahrten\n%.0f %% Gästezufriedenheit\n\nTageskarten: %s €\nServices: %s €\nBetriebskosten: −%s €\nMeilenstein-Prämien: %s €\n\nTagesergebnis: %s €\nVerfügbares Budget: %s €\n\nÜber Nacht werden die Pisten präpariert.\nMorgen kann sich das Wetter ändern." % [report.day, report.guests, report.rides, satisfaction, money_text(report.tickets), money_text(report.services), money_text(report.costs), money_text(report.rewards), money_text(report.tickets + report.services - report.costs + report.rewards), money_text(game.model.money)]
	daily_dialog.get_label().add_theme_font_size_override("font_size", 22)
	daily_dialog.popup_centered(Vector2i(650, 560))
