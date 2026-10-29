extends VBoxContainer
const L = preload("res://src/core/i18n.gd")
const Catalog = preload("res://src/core/catalog.gd")
const RouteProfile = preload("res://src/ui/route_profile.gd")
const DragScroll = preload("res://src/ui/drag_scroll.gd")
const LiftIcon = preload("res://src/ui/lift_icon.gd")
var hud: CanvasLayer
var game: Node
var category := "pistes"
var content: VBoxContainer
var categories: Dictionary = {}
var cards: Array = []
var _state := ""
var route_profile := RouteProfile.new()
var suggest_button: Button
var reverse_button: Button

func setup(interface: CanvasLayer) -> void:
	hud = interface
	game = hud.game
	add_theme_constant_override("separation", 9)
	hud._label(self, L.text("BAUKATALOG"), 13, hud.TEAL)
	hud._label(self, L.text("Dein nächster Ausbau"), 20)
	hud.tool_buttons.inspect = hud._button(self, L.text("Resort ansehen"), func(): game.clear_plan())
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 5)
	add_child(bar)
	for entry in [["pistes", L.text("Pisten")], ["lifts", L.text("Lifte")], ["village", L.text("Dorf")], ["paths", L.text("Wege")]]:
		var key: String = entry[0]
		var button: Button = hud._button(bar, entry[1], func(): select_category(key))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		categories[key] = button
	hud.tool_buttons.lift = categories.lifts
	hud.tool_buttons.building = categories.village
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = hud._vbox(scroll, 9)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_cards()
	content.add_child(route_profile)
	suggest_button=hud._button(content,L.text("Sanften Verlauf vorschlagen"),game.suggest_route,true)
	suggest_button.tooltip_text=L.text("Sucht einen sanfteren Verlauf zwischen deinen Punkten. Bauen wird separat bestätigt.")
	reverse_button=hud._button(content,L.text("Richtung umkehren"),game.reverse_route)

func _card(key: String, title: String, description: String, cost: int, upkeep: int, type: String, color: Color) -> void:
	var button := Button.new()
	button.custom_minimum_size.y = 132 if type == "lift" else (142 if type == "plaza" else 98)
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
	for key in Catalog.BUILDINGS:
		var spec: Dictionary = Catalog.BUILDINGS[key]
		_card(key, spec.name, L.text("%s € · %d €/Tag") % L.args([hud.money_text(spec.cost), spec.upkeep]), spec.cost, spec.upkeep, "building", Color(spec.color).darkened(0.22))
	for key in Catalog.PLAZAS:
		var spec: Dictionary = Catalog.PLAZAS[key]
		if key == "walkway":
			_card(key,spec.name,L.text("8 m breit · 180 € + 18 €/m\n")+spec.description,252,0,"plaza",hud.TEAL)
			continue
		_card(key, spec.name, L.text("Ø %.0f m · %s €\n%s") % L.args([spec.radius * 2, hud.money_text(spec.cost), spec.description]), spec.cost, 0, "plaza", hud.TEAL)
	refresh(true)

func select_category(value: String) -> void:
	if not game.points.is_empty() and category != value:
		hud.toast(L.text("Erst Bauen oder Abbrechen wählen. Dein Plan bleibt erhalten."))
		return
	category = value
	refresh(true)

func refresh(force: bool = false) -> void:
	var fingerprint := "%s:%s:%d:%s:%s:%d" % [category, game.tool, game.model.money, str(game.model.campaign.research) + str(game.points.is_empty()) + game.plaza_kind, game.model.campaign.mode, hud.lift_choice.selected * 100 + hud.building_choice.selected]
	if fingerprint == _state and not force:
		return
	_state = fingerprint
	route_profile.visible = category == "pistes"
	suggest_button.visible=category == "pistes" and game.tool == "piste"
	reverse_button.visible=suggest_button.visible
	suggest_button.disabled=game.points.size()<2
	reverse_button.disabled=game.points.size()<2
	hud.tool_buttons.inspect.text = L.text("Plan abbrechen") if game.tool != "inspect" else L.text("Resort ansehen")
	for key in categories:
		categories[key].disabled = not game.points.is_empty() and key != category
		categories[key].add_theme_stylebox_override("normal", hud._style(Color("c9e2d8") if key == category else Color("e1eeea"), 7, 7))
	for card in cards:
		var active_category: String = {"piste": "pistes", "lift": "lifts", "building": "village", "plaza": "paths"}[card.type]
		card.button.visible = category == active_category
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
