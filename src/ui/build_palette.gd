extends VBoxContainer
const Catalog = preload("res://src/core/catalog.gd")
var hud: CanvasLayer
var game: Node
var category := "pistes"
var content: VBoxContainer
var categories: Dictionary = {}
var cards: Array = []
var _state := ""

func setup(interface: CanvasLayer) -> void:
	hud = interface
	game = hud.game
	add_theme_constant_override("separation", 9)
	hud._label(self, "BAUKATALOG", 13, hud.TEAL)
	hud._label(self, "Dein nächster Ausbau", 20)
	hud.tool_buttons.inspect = hud._button(self, "Resort ansehen", func(): game.set_tool("inspect"))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 5)
	add_child(bar)
	for entry in [["pistes", "Pisten"], ["lifts", "Lifte"], ["village", "Dorf"]]:
		var key: String = entry[0]
		var button: Button = hud._button(bar, entry[1], func(): select_category(key))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		categories[key] = button
	hud.tool_buttons.lift = categories.lifts
	hud.tool_buttons.building = categories.village
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = hud._vbox(scroll, 9)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_cards()

func _card(key: String, title: String, description: String, cost: int, upkeep: int, type: String, color: Color) -> void:
	var button := Button.new()
	button.custom_minimum_size.y = 86
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
	var heading: Label = hud._label(body, title, 16, color, true)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var detail: Label = hud._label(body, description, 13, hud.MUTED, true)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var status: Label = hud._label(body, "", 12, hud.TEAL, true)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.tooltip_text = description + ("\nBetrieb: %d €/Tag" % upkeep if upkeep > 0 else "")
	button.pressed.connect(func():
		if type == "piste":
			game.set_tool(key)
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
	for entry in [["blue", "Blaue Piste", "Bis 30 % Gefälle · 32 €/m", 1280, Color("8dc9f2")], ["red", "Rote Piste", "Bis 55 % Gefälle · 44 €/m", 1760, Color("efa0a5")], ["black", "Schwarze Piste", "Bis 110 % Gefälle · 58 €/m", 2320, Color("c2b4db")]]:
		_card(entry[0], entry[1], entry[2], entry[3], 0, "piste", entry[4])
	for key in Catalog.LIFTS:
		var spec: Dictionary = Catalog.LIFTS[key]
		_card(key, spec.name, "%s € + %d €/m · %d Gäste/h" % [hud.money_text(spec.cost), spec.per_m, spec.capacity], spec.cost, spec.upkeep, "lift", hud.ACCENT)
	for key in Catalog.BUILDINGS:
		var spec: Dictionary = Catalog.BUILDINGS[key]
		_card(key, spec.name, "%s € · %d €/Tag" % [hud.money_text(spec.cost), spec.upkeep], spec.cost, spec.upkeep, "building", Color(spec.color).lightened(0.2))
	refresh(true)

func select_category(value: String) -> void:
	category = value
	refresh(true)

func refresh(force: bool = false) -> void:
	var fingerprint := "%s:%s:%d:%s:%s:%d" % [category, game.tool, game.model.money, str(game.model.campaign.research), game.model.campaign.mode, hud.lift_choice.selected * 100 + hud.building_choice.selected]
	if fingerprint == _state and not force:
		return
	_state = fingerprint
	for key in categories:
		categories[key].add_theme_stylebox_override("normal", hud._style(Color("3d6671") if key == category else Color("244755"), 7, 7))
	for card in cards:
		var active_category: String = {"piste": "pistes", "lift": "lifts", "building": "village"}[card.type]
		card.button.visible = category == active_category
		var locked: String = "" if card.type == "piste" else game.model.build_access_message(card.key, card.type == "lift")
		var affordable: bool = game.model.money >= card.cost
		card.button.disabled = locked != "" or not affordable
		card.status.text = locked if locked != "" else ("Budget reicht noch nicht" if not affordable else ("Standort wählen" if card.type == "building" else "Route planen"))
		card.heading.modulate = Color("718b94") if locked != "" else Color.WHITE
		var selected: bool = game.tool == card.key if card.type == "piste" else (game.tool == card.type and (hud.lift_kind() if card.type == "lift" else hud.building_kind()) == card.key)
		card.button.add_theme_stylebox_override("normal", hud._style(Color("315c68") if selected else Color("20424f"), 10, 10, hud.TEAL if selected else Color.TRANSPARENT))
		if card.type != "piste":
			var choice: OptionButton = hud.lift_choice if card.type == "lift" else hud.building_choice
			var index: int = (Catalog.LIFTS.keys() if card.type == "lift" else Catalog.BUILDINGS.keys()).find(card.key)
			choice.set_item_disabled(index, card.button.disabled)
