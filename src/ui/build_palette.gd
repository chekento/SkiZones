extends VBoxContainer
const L = preload("res://src/core/i18n.gd")
const Catalog = preload("res://src/core/catalog.gd")
const RouteProfile = preload("res://src/ui/route_profile.gd")
const DragScroll = preload("res://src/ui/drag_scroll.gd")
const BuildingIcon = preload("res://src/ui/building_icon.gd")
const Design = preload("res://src/core/walkway_design.gd")
const LiftIcon = preload("res://src/ui/lift_icon.gd")
var hud: CanvasLayer
var game: Node
var category := "pistes"
var content: VBoxContainer
var categories: Dictionary = {}
var guidance: Label
var cards: Array = []
var _state := ""
var route_profile := RouteProfile.new()
var suggest_button: Button
var reverse_button: Button
var site_button: Button
var browser_button: Button
var live_stats: Label
var fixed := VBoxContainer.new()
var path_cards := GridContainer.new()
var path_options := VBoxContainer.new()
var surface_choice := OptionButton.new()
var draw_mode: Button
var category_bar: GridContainer
var category_choice := OptionButton.new()
var scroll: ScrollContainer
var headings: Array = []

func setup(interface: CanvasLayer) -> void:
	hud = interface
	game = hud.game
	add_theme_constant_override("separation", 9)
	headings.append(hud._label(self, L.text("BAUKATALOG"), 13, hud.TEAL))
	hud.tool_buttons.inspect = hud._button(self, L.text("Resort ansehen"), func(): game.clear_plan())
	# Two columns give every category a comfortable finger target on phones.
	# A horizontal four-button row squeezed important names below legibility.
	var bar := GridContainer.new()
	category_bar = bar
	bar.columns = 2
	bar.add_theme_constant_override("h_separation", 7)
	bar.add_theme_constant_override("v_separation", 7)
	add_child(bar)
	for entry in [["pistes", L.text("Pisten")], ["lifts", L.text("Lifte")], ["village", L.text("Dorf")], ["paths", L.text("Wege")]]:
		var key: String = entry[0]
		var button: Button = hud._button(bar, entry[1], func(): select_category(key))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.custom_minimum_size.y = 54
		categories[key] = button
	add_child(category_choice)
	category_choice.custom_minimum_size.y = 44
	for key in categories: category_choice.add_item(categories[key].text)
	category_choice.item_selected.connect(func(index): select_category(categories.keys()[index]))
	guidance = hud._label(self, "", 14, hud.MUTED, true)
	guidance.custom_minimum_size.y = 0
	guidance.add_theme_font_size_override("font_size", 13)
	guidance.tooltip_text = L.text("Wähle zuerst eine Anlage und platziere sie anschließend direkt auf dem Berg.")
	hud.tool_buttons.lift = categories.lifts
	hud.tool_buttons.building = categories.village
	add_child(fixed)
	fixed.add_theme_constant_override("separation", 6)
	live_stats = hud._label(fixed, "", 14, hud.TEAL, true)
	fixed.add_child(route_profile)
	fixed.add_child(path_options)
	path_options.add_theme_constant_override("separation", 6)
	surface_choice.custom_minimum_size.y = 44
	for spec in Design.SURFACES.values(): surface_choice.add_item(L.text(spec.name))
	surface_choice.item_selected.connect(func(index):
		game.walkway_surface = Design.SURFACES.keys()[index]
		game._update_plan()
	)
	path_options.add_child(surface_choice)
	draw_mode = hud._button(path_options, L.text("Freihand"), func():
		game.walkway_freehand = not game.walkway_freehand
		refresh(true)
	)
	draw_mode.toggle_mode = true
	draw_mode.add_theme_font_size_override("font_size",14)
	fixed.add_child(path_cards)
	path_cards.columns = 2
	path_cards.add_theme_constant_override("h_separation", 6)
	path_cards.add_theme_constant_override("v_separation", 6)
	scroll = DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = hud._vbox(scroll, 9)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser_button=hud._button(content,L.text("Gebäudekatalog mit Vorschau öffnen"),func(): hud.building_browser.open(),true)
	_make_cards()
	for card in cards:
		if card.type == "piste":
			card.button.reparent(fixed)
			card.button.custom_minimum_size.y = 94
		elif card.type == "plaza":
			card.button.reparent(path_cards)
			card.button.custom_minimum_size = Vector2(0,64)
			card.button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.detail.hide()
			card.status.hide()
			card.heading.add_theme_font_size_override("font_size",14)
	suggest_button=hud._button(content,L.text("Sanften Verlauf vorschlagen"),game.suggest_route,true)
	suggest_button.tooltip_text=L.text("Sucht einen sanfteren Verlauf zwischen deinen Punkten. Bauen wird separat bestätigt.")
	reverse_button=hud._button(content,L.text("Richtung umkehren"),game.reverse_route)
	site_button=hud._button(content,L.text("Passenden Bauplatz finden"),game.suggest_site,true)
	site_button.tooltip_text=L.text("Sucht einen nahen freien Standort und richtet den Eingang zum Zugang aus. Bauen wird separat bestätigt.")
	content.move_child(site_button, 0)
	content.move_child(suggest_button, 1)
	refresh(true)

func _card(key: String, title: String, description: String, cost: int, upkeep: int, type: String, color: Color) -> void:
	var button := Button.new()
	button.custom_minimum_size.y = 132 if type == "lift" else (142 if type == "plaza" else 122)
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(button)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 13
	body.offset_right = -10
	body.offset_top = 9
	body.offset_bottom = -7
	button.add_child(body)
	if type == "building":
		body.offset_left=80
		var icon := BuildingIcon.new()
		icon.kind=key
		icon.position=Vector2(6,12)
		icon.size=Vector2(68,80)
		button.add_child(icon)
	if type == "lift":
		body.offset_left = 61
		var icon := LiftIcon.new()
		icon.kind = key
		icon.position = Vector2(8, 9)
		icon.size = Vector2(44, 70)
		button.add_child(icon)
	var heading: Label = hud._label(body, title, 16, color, true)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var detail: Label = hud._label(body, description, 13, hud.MUTED, true)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var status: Label = hud._label(body, "", 12, hud.TEAL, true)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.tooltip_text = description + (L.text("\nBetrieb: %d €/Tag") % L.args(upkeep) if upkeep > 0 else "")
	button.pressed.connect(func():
		if not DragScroll.click_allowed():
			return
		if not game.points.is_empty():
			game.hud.toast(L.text("Erst Bauen oder Abbrechen wählen. Dein aktueller Plan bleibt erhalten."))
			return
		if type == "piste":
			game.set_tool(key)
		elif type == "plaza":
			game.plaza_kind = key
			game.set_tool("walkway" if key == "walkway" else "plaza")
		else:
			var choice: OptionButton = hud.lift_choice if type == "lift" else hud.building_choice
			choice.select((Catalog.LIFTS.keys() if type == "lift" else Catalog.BUILDINGS.keys()).find(key))
			game.set_tool(type)
		refresh(true)
	)
	cards.append({"key": key, "button": button, "heading": heading, "detail": detail, "status": status, "type": type, "cost": cost, "upkeep": upkeep, "color": color})
	if type == "piste":
		hud.tool_buttons[key] = button

func _make_cards() -> void:
	_card("piste", L.text("Abfahrt planen"), L.text("Farbe automatisch · ab 32 €/m"), 1280, 0, "piste", hud.TEAL)
	for key in Catalog.LIFTS:
		var spec: Dictionary = Catalog.LIFTS[key]
		_card(key, spec.name, L.text("%.1f m/s · max. %.0f m\n%s € + %d €/m") % L.args([spec.speed / 60, spec.max_length, hud.money_text(spec.cost), spec.per_m]), spec.cost, spec.upkeep, "lift", hud.ACCENT)
	for key in Catalog.building_order():
		var spec: Dictionary = Catalog.BUILDINGS[key]
		_card(key, spec.name, L.text(Catalog.building_group(key)) + "\n" + L.text("%s € · %d €/Tag") % L.args([hud.money_text(spec.cost), spec.upkeep]), spec.cost, spec.upkeep, "building", Color(spec.color).darkened(0.22))
	for key in Catalog.PLAZAS:
		var spec: Dictionary = Catalog.PLAZAS[key]
		if key == "walkway":
			_card(key,spec.name,L.text("8 m breit · 180 € + 18 €/m\n")+L.text(spec.description),252,0,"plaza",hud.TEAL)
			continue
		_card(key, spec.name, L.text("Ø %.0f m · %s €\n%s") % L.args([spec.radius * 2, hud.money_text(spec.cost), spec.description]), spec.cost, 0, "plaza", hud.TEAL)
func select_category(value: String, from_tool: bool = false) -> void:
	if not from_tool and not game.points.is_empty() and category != value:
		hud.toast(L.text("Erst Bauen oder Abbrechen wählen. Dein Plan bleibt erhalten."))
		return
	category = value
	refresh(true)
	if value=="village" and not from_tool: hud.building_browser.open()

func _update_planning() -> void:
	var count: int = game.points.size()
	var active: bool = game.tool in ["piste", "walkway"] and count > 0
	var short: bool = hud.root.size.y < 540
	var analysis: Dictionary = route_profile.analysis
	for heading in headings: heading.visible = not active and not short
	category_bar.visible = not active and not short
	category_choice.visible = not active and short
	category_choice.select(categories.keys().find(category))
	for card in cards:
		if card.type == "plaza": card.button.custom_minimum_size.y = 54 if short else 64
	hud.tool_buttons.inspect.visible = not active and category not in ["paths", "pistes"]
	live_stats.visible = active
	route_profile.visible = active and game.tool == "piste" and count > 1
	route_profile.compact = true
	route_profile.custom_minimum_size.y = 52 if short else 104
	live_stats.add_theme_font_size_override("font_size", 12 if short else 14)
	if active and game.tool == "piste":
		var start: float = game.model.terrain.height(game.model.Terrain.unpack(game.points[0]))
		if count == 1:
			live_stats.text = L.text("Start: %.0f m · nächster Punkt bergab") % start
		else:
			var grade: float = analysis.get("grade", 0)
			var average: float = analysis.get("average", 0)
			var sections: Array = analysis.get("segments", [])
			var segment: int = clampi(game.selected_waypoint - 1 if game.selected_waypoint > 0 else sections.size() - 1, 0, maxi(0,sections.size()-1))
			var section_points: Array = analysis.get("points",game.points)
			var slope := 0.0
			if not sections.is_empty() and segment+1 < section_points.size():
				var distance: float = game.model.Terrain.unpack(section_points[segment]).distance_to(game.model.Terrain.unpack(section_points[segment+1]))
				slope = sections[segment].drop / maxf(distance,0.001) * 100.0
			live_stats.text = L.text("%s · %.0f m · %.0f m breit\n↓ %.0f m · ↑ %.1f m\nØ %.1f %% / %.1f°\nMax. %.1f %% / %.1f°\nAbschnitt %d: %.1f %% / %.1f°\nBau: %s €") % [L.text(game.model.Terrain.PISTE_NAMES[int(analysis.get("difficulty",0))]), float(analysis.get("length",0)), float(analysis.get("width",game.chosen_piste_width())), float(analysis.get("drop",0)), float(analysis.get("uphill",0)), average, rad_to_deg(atan(average/100.0)), grade, rad_to_deg(atan(grade/100.0)), segment+1, slope, rad_to_deg(atan(slope/100.0)), hud.money_text(analysis.get("cost",0))]
	elif active and game.tool == "walkway":
		live_stats.text = L.text("%s · %.0f m\n8 m breit · Bau: %s €") % [L.text(Design.SURFACES[game.walkway_surface].name),float(analysis.get("length",0)),hud.money_text(analysis.get("cost",0))]
	path_cards.visible = category == "paths" and game.points.is_empty() and game.tool != "walkway"
	path_options.visible = category == "paths" and game.tool == "walkway" and game.editing_id == -1
	surface_choice.select(Design.SURFACES.keys().find(game.walkway_surface))
	draw_mode.text = L.text("Freihand") if game.walkway_freehand else L.text("Wegpunkte")
	draw_mode.set_pressed_no_signal(game.walkway_freehand)
	draw_mode.tooltip_text = L.text("Tippen setzt Punkte. Ziehen zeichnet den Weg; zwei Finger bewegen die Karte.")
	scroll.visible = category in ["lifts", "village"]

func refresh(force: bool = false) -> void:
	_update_planning()
	var fingerprint := "%s:%s:%d:%s:%s:%d" % [category, game.tool, game.model.money, str(game.model.campaign.research) + str(game.points.size()) + game.plaza_kind, game.model.campaign.mode + str(game.last_plan_check.get("message","")) + game.walkway_surface, hud.lift_choice.selected * 100 + hud.building_choice.selected]
	if fingerprint == _state and not force:
		return
	_state = fingerprint
	if not game.points.is_empty():
		guidance.text = L.text("PLAN IN ARBEIT · %d Punkte") % game.points.size()
		if game.tool == "piste":
			var check: Dictionary = game.last_plan_check
			guidance.text += "\n" + (L.text("Bauprüfung: gültig") if check.get("ok",false) else L.text("Bauprüfung: Verlauf ändern"))
			if check.has("connections"): guidance.text += "\n" + L.text("Anschluss: Einstieg %s · Tal %s") % ["✓" if check.connections.entry else "–", "✓" if check.connections.exit else "–"]
		elif game.tool == "walkway": guidance.text += "\n" + L.text("Ziehen zeichnet · Punkte sind verschiebbar")
	elif game.tool != "inspect":
		guidance.text = L.text("BAUMODUS · Setze die nächsten Punkte direkt am Hang.")
	else:
		guidance.text = {
			"pistes": L.text("1 · Abfahrt wählen  2 · Punkte setzen  3 · Bau prüfen"),
			"lifts": L.text("1 · Lift wählen  2 · Tal & Berg markieren  3 · Bauen"),
			"village": L.text("1 · Gebäude wählen  2 · Standort suchen  3 · Bauen"),
			"paths": L.text("1 · Wege & Plätze wählen  2 · Verbinden  3 · Bauen")
		}.get(category, "")
	browser_button.visible=category=="village"
	suggest_button.visible = false # The fixed plan bar already exposes the same action.
	suggest_button.text=L.text("Begehbaren Weg vorschlagen") if game.tool == "walkway" else L.text("Sanften Verlauf vorschlagen")
	reverse_button.visible = category == "pistes" and game.tool == "piste"
	site_button.visible=category == "village" and game.tool == "building" and game.points.size() == 1
	site_button.disabled=game.points.size() != 1
	suggest_button.disabled=game.points.size()<2
	reverse_button.disabled=game.points.size()<2
	hud.tool_buttons.inspect.text = L.text("Plan abbrechen") if game.tool != "inspect" else L.text("Resort ansehen")
	for key in categories:
		categories[key].disabled = not game.points.is_empty() and key != category
		categories[key].add_theme_stylebox_override("normal", hud._style(Color("c9e2d8") if key == category else Color("e1eeea"), 7, 7))
	for card in cards:
		var active_category: String = {"piste": "pistes", "lift": "lifts", "building": "village", "plaza": "paths"}[card.type]
		card.button.visible = category == active_category and (category != "pistes" or game.points.is_empty())
		var locked: String = "" if card.type in ["piste", "plaza"] else game.model.build_access_message(card.key, card.type == "lift")
		var affordable: bool = game.model.money >= card.cost
		card.button.disabled = locked != "" or not affordable or not game.points.is_empty()
		card.status.text = L.text("Plan läuft · Bauen / Abbrechen") if not game.points.is_empty() else locked if locked != "" else (L.text("Budget reicht noch nicht") if not affordable else (L.text("Standort wählen") if card.type in ["building", "plaza"] and card.key != "walkway" else L.text("Route planen")))
		card.heading.modulate = Color("718b94") if locked != "" else Color.WHITE
		var selected: bool = game.tool == card.key if card.type == "piste" else (game.tool in ["plaza","walkway"] and game.plaza_kind == card.key) if card.type == "plaza" else (game.tool == card.type and (hud.lift_kind() if card.type == "lift" else hud.building_kind()) == card.key)
		card.button.add_theme_stylebox_override("normal", hud._style(Color("dcece2") if selected else Color("eff4ed"), 10, 10, hud.TEAL if selected else Color.TRANSPARENT))
		if card.type in ["lift", "building"]:
			var choice: OptionButton = hud.lift_choice if card.type == "lift" else hud.building_choice
			var index: int = (Catalog.LIFTS.keys() if card.type == "lift" else Catalog.BUILDINGS.keys()).find(card.key)
			choice.set_item_disabled(index, card.button.disabled)
	hud._layout_construction()

