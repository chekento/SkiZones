extends Control
## Touch-friendly building interiors, pizza workshop and hotel management.
const L = preload("res://src/core/i18n.gd")
const Hospitality = preload("res://src/core/hospitality.gd")
const ActivityArt = preload("res://src/ui/building_activity_art.gd")
const Activities = preload("res://src/core/building_activities.gd")
var hud: CanvasLayer
var asset_id := -1
var tabs := TabContainer.new()
var heading: Label
var session: Dictionary = {}
var game_box: VBoxContainer
var task: Dictionary = {}
var artwork: Control
var meter: ProgressBar
var cursor := 0.0
var elapsed := 0.0
var picked: Array = []
var status: Label
var was_paused := false
var _recipes: Array = []
var _recipe_names: Array = []
var _pizza_checks: Array = []

func setup(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.08, 0.12, 0.82)
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_anchor_and_offset(SIDE_LEFT, 0.08, 0)
	panel.set_anchor_and_offset(SIDE_RIGHT, 0.92, 0)
	panel.set_anchor_and_offset(SIDE_TOP, 0.06, 0)
	panel.set_anchor_and_offset(SIDE_BOTTOM, 0.94, 0)
	panel.add_theme_stylebox_override("panel", hud._style(Color("f6f2e8"), 22, 20))
	var body: VBoxContainer = hud._vbox(panel, 12)
	var row := HBoxContainer.new()
	body.add_child(row)
	heading = hud._label(row, "", 28, hud.INK)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud._button(row, L.text("Zurück ins Dorf"), close)
	hud._label(body, L.text("DEIN BETRIEB · DEINE IDEEN"), 14, hud.TEAL)
	tabs.add_theme_stylebox_override("panel", hud._style(Color("f6f2e8"), 10, 10))
	tabs.add_theme_stylebox_override("tab_selected", hud._style(Color("bddccd"), 10, 12))
	tabs.add_theme_stylebox_override("tab_unselected", hud._style(Color("e2e8db"), 10, 12))
	tabs.add_theme_color_override("font_selected_color", hud.INK)
	tabs.add_theme_color_override("font_unselected_color", hud.MUTED)
	body.add_child(tabs)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hide()

func open(id: int) -> void:
	if not hud.game.points.is_empty():
		hud.toast(L.text("Zuerst die laufende Planung abschließen oder abbrechen."))
		return
	var building: Dictionary = hud.game.model.asset(id)
	if not hud.Catalog.BUILDINGS.has(building.get("kind", "")): return
	if not visible:
		was_paused = hud.game.paused
		hud.game.paused = true
	asset_id = id
	session.clear()
	_rebuild()
	show()

func close() -> void:
	if visible: hud.game.paused = was_paused
	session.clear()
	hide()
	hud.refresh()

func _page(title: String) -> VBoxContainer:
	var scroll: ScrollContainer = hud.DragScroll.new()
	scroll.name = title
	tabs.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	return body

func _card(parent: Node, title: String, description: String = "") -> VBoxContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.add_theme_stylebox_override("panel", hud._style(Color("e6eee8"), 14, 16))
	var body: VBoxContainer = hud._vbox(panel, 10)
	hud._label(body, title, 22, hud.INK, true)
	if description != "": hud._label(body, description, 17, hud.MUTED, true)
	return body

func _action(parent: Node, label_text: String, action: Callable) -> Button:
	return hud._button(parent, label_text, func():
		var result: Dictionary = action.call()
		hud.toast(result.get("message", ""))
		_rebuild()
	, true)

func _spin(parent: Node, label_text: String, value: int, low: int, high: int, step_value: int = 5) -> SpinBox:
	hud._label(parent, label_text, 17, hud.INK)
	var field := SpinBox.new()
	field.min_value = low
	field.max_value = high
	field.step = step_value
	field.value = value
	field.custom_minimum_size.y = 48
	parent.add_child(field)
	return field

func _check(parent: Node, label_text: String, value: bool) -> CheckButton:
	var field := CheckButton.new()
	field.text = label_text
	field.button_pressed = value
	field.custom_minimum_size.y = 48
	parent.add_child(field)
	return field

func _rebuild() -> void:
	for child in tabs.get_children():
		tabs.remove_child(child)
		child.queue_free()
	meter = null
	var model: RefCounted = hud.game.model
	var building: Dictionary = model.asset(asset_id)
	if building.is_empty(): close(); return
	heading.text = L.asset_name(building)
	if Hospitality.lodging(str(building.kind)): _hotel(building)
	if building.kind == "pizzeria": _pizza(building)
	_activity(building)
	var operation := _page(L.text("Betrieb & Team"))
	var balance: Dictionary = model.Ops.business_balance(model, building)
	_card(operation, L.text("Dein Betriebsergebnis"), L.text("Umsatz %s € · Kosten %s € · Ergebnis %s €") % [hud.money_text(balance.sales), hud.money_text(balance.costs), hud.money_text(balance.net)])
	hud._button(operation, L.text("Personal, Status und Reparatur"), func(): close(); hud.lift_staff.open(asset_id), true)
	hud._label(operation, L.text("Minispiele sind freiwillig. Deine Betriebe arbeiten auch ohne manuelle Schichten weiter. Drei belohnte Schichten pro Gebäude und Tag; danach bleibt freies Üben möglich."), 16, hud.MUTED, true)

func _pizza(building: Dictionary) -> void:
	var page := _page(L.text("Meine Pizzakarte"))
	_recipes = Hospitality.menu(building)
	_recipe_names.clear()
	_pizza_checks.clear()
	hud._label(page, L.text("Drei eigene Pizzen · zwei bis sechs Zutaten pro Pizza"), 23, hud.TEAL, true)
	for index in range(3):
		var recipe: Dictionary = _recipes[index]
		var card := _card(page, L.text("Pizza %d") % (index + 1))
		var name_field := LineEdit.new()
		name_field.max_length = 32
		name_field.text = recipe.name
		name_field.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		name_field.custom_minimum_size.y = 48
		card.add_child(name_field)
		_recipe_names.append(name_field)
		var preview := ActivityArt.new()
		preview.custom_minimum_size = Vector2(0, 145)
		preview.toppings = recipe.toppings.duplicate()
		card.add_child(preview)
		var toppings := HFlowContainer.new()
		card.add_child(toppings)
		var checks := {}
		for key in Hospitality.TOPPINGS:
			checks[key] = _check(toppings, L.text(Hospitality.TOPPINGS[key]), recipe.toppings.has(key))
			checks[key].toggled.connect(func(value):
				if value: preview.toppings.append(key)
				else: preview.toppings.erase(key)
				preview.queue_redraw())
		_pizza_checks.append(checks)
	hud._button(page, L.text("Drei Pizzen auf die Karte setzen"), func():
		var recipes: Array = []
		for index in range(3):
			var toppings: Array = []
			for key in _pizza_checks[index]:
				if _pizza_checks[index][key].button_pressed: toppings.append(key)
			recipes.append({"name":_recipe_names[index].text.strip_edges(), "toppings":toppings})
		var result: Dictionary = Hospitality.set_menu(hud.game.model, asset_id, recipes)
		hud.toast(result.message)
		if result.ok: _rebuild()
	, true)

func _hotel(building: Dictionary) -> void:
	var model: RefCounted = hud.game.model
	var settings := Hospitality.config(building)
	var dashboard := Hospitality.dashboard(model, building)
	var page := _page(L.text("Hotelverwaltung"))
	_card(page, L.text("Deine Gäste bleiben länger"), L.text("%d / %d Zimmer belegt · %.0f %% Auslastung\nBewertung %.1f / 5 · Sauberkeit %.0f %%\nGeplante Kosten %s €/Tag · Kostendeckung ab %d belegten Zimmern") % [int(dashboard.occupied), int(dashboard.capacity), float(dashboard.occupancy) * 100.0, float(settings.rating), float(settings.cleanliness), hud.money_text(dashboard.cost), int(dashboard.break_even)])
	var forecast := _card(page, L.text("Übernachtung und Ertrag"), L.text("Vorsichtige Zimmerprognose bei aktueller Belegung: %s €/Tag nach geplanten Kosten. Tatsächliche Abrechnung erfolgt je Übernachtung; Tagesbesuche sind keine Zimmerbuchung.") % hud.money_text(dashboard.forecast))
	var price := _spin(forecast, L.text("Zimmerpreis je Nacht · €"), int(dashboard.price), 45, 350)
	var family := _spin(forecast, L.text("Familienzimmer · Anteil in Prozent"), int(settings.family_share), 0, 80, 10)
	var premium := _spin(forecast, L.text("Premiumzimmer · Anteil in Prozent"), int(settings.premium_share), 0, 80, 10)
	var breakfast := _check(forecast, L.text("Frühstück anbieten"), settings.breakfast)
	var cleaning := _check(forecast, L.text("Automatischer Reinigungsservice"), settings.auto_clean)
	var marketing := _spin(forecast, L.text("Hotelmarketing · Stufe 0 bis 3"), int(settings.marketing), 0, 3, 1)
	_action(forecast, L.text("Hoteleinstellungen übernehmen"), func(): return Hospitality.configure(model, asset_id, {"price":int(price.value), "family_share":int(family.value), "premium_share":int(premium.value), "breakfast":breakfast.button_pressed, "auto_clean":cleaning.button_pressed, "marketing":int(marketing.value)}))
	var comfort := _card(page, L.text("Zimmerkomfort · Stufe %d / 5") % int(settings.comfort))
	_action(comfort, L.text("Komfort ausbauen · %s €") % hud.money_text(1600 * int(model.Catalog.LODGING[building.kind].rooms) * int(settings.comfort)), func(): return Hospitality.upgrade(model, asset_id)).disabled = int(settings.comfort) >= 5
	_action(comfort, L.text("Alle Zimmer reinigen · %s €") % hud.money_text(8 * int(dashboard.capacity)), func(): return Hospitality.housekeeping(model, asset_id))
	var room_page := _page(L.text("Zimmer & Gäste"))
	var grid := GridContainer.new()
	grid.columns = 6
	room_page.add_child(grid)
	for index in range(int(dashboard.capacity)):
		var room := PanelContainer.new()
		room.custom_minimum_size = Vector2(98, 68)
		grid.add_child(room)
		room.add_theme_stylebox_override("panel", hud._style(Color("bbdccb") if index < int(dashboard.occupied) else Color("e4ded0"), 9, 7))
		hud._label(room, L.text("Zimmer %d\n%s") % [index + 1, L.text("Belegt") if index < int(dashboard.occupied) else L.text("Frei")], 15, hud.INK)
	var residents := _card(room_page, L.text("Aktuelle Übernachtungsgäste"))
	for guest in model.guests:
		if int(guest.get("lodging_id", 0)) != asset_id or guest.phase == "leaving": continue
		hud._label(residents, L.text("Gast %d · noch %d Urlaubstage · %s") % [int(guest.id), ceili(float(guest.stay - guest.age) / 1440.0), L.text("Wochenkarte") if guest.get("ticket_type", "day") == "week" else L.text("Tageskarte")], 16, hud.INK, true)
	var chains := _page(L.text("Hotelketten"))
	var chain_card := _card(chains, L.text("Deinen Hotelverbund aufbauen"), L.text("Gib mehreren eigenen Unterkünften denselben Kettennamen. Gemeinsames Marketing verbessert ihre Attraktivität. Gäste werden auf verfügbare, erreichbare Häuser verteilt."))
	var chain_name := LineEdit.new()
	chain_name.max_length = 40
	chain_name.text = settings.chain
	chain_name.placeholder_text = L.text("Name deiner Hotelkette")
	chain_name.custom_minimum_size.y = 48
	chain_card.add_child(chain_name)
	_action(chain_card, L.text("Hotelkette speichern"), func(): return Hospitality.configure(model, asset_id, {"chain":chain_name.text.strip_edges()}))
	_action(chain_card, L.text("Hotelverbund verlassen"), func(): return Hospitality.configure(model, asset_id, {"chain":""}))
	for member in Hospitality.chain_members(model, building):
		var data := Hospitality.dashboard(model, member)
		var body := _card(chains, L.asset_name(member), L.text("%d / %d Zimmer · %.0f € je Nacht") % [int(data.occupied), int(data.capacity), float(data.price)])
		hud._button(body, L.text("Dieses Haus verwalten"), func(): open(int(member.id)))
	_weekly(chains)

func _weekly(page: Node) -> void:
	var model: RefCounted = hud.game.model
	var offer := Hospitality.weekly_offer(model)
	var body := _card(page, L.text("Wochenkarten für Urlaubsgäste"), L.text("Sieben aufeinanderfolgende Tage · %d € statt %.0f € · %.1f %% Ersparnis. Eine Kostenuntergrenze mit 20 %% Deckungsaufschlag begrenzt den Rabatt.") % [int(offer.price), float(offer.full), float(offer.discount)])
	if not offer.available: hud._label(body, L.text("Die aktuelle Kostenuntergrenze lässt noch keinen Wochenrabatt zu. Mehr Gäste oder ein höherer Tagespreis machen das Angebot möglich."), 16, hud.ACCENT, true)
	var enabled := _check(body, L.text("Wochenkarten anbieten"), offer.enabled)
	var discount := _spin(body, L.text("Gewünschter Wochenrabatt · Prozent"), int(model.operations.get("weekly_discount", 12)), 5, 20, 1)
	hud._button(body, L.text("Ticketangebot übernehmen"), func():
		model.operations.weekly_enabled = enabled.button_pressed
		model.operations.weekly_discount = int(discount.value)
		_rebuild()
	, true)

func _activity(building: Dictionary) -> void:
	var page := _page(L.text("Selber spielen"))
	var definition := Activities.spec(str(building.kind))
	if definition.is_empty(): return
	game_box = _card(page, L.text(definition.title), L.text(definition.hint))
	hud._label(game_box, L.text("Die Resortzeit pausiert während deines Gebäudebesuchs."), 16, hud.MUTED, true)
	hud._button(game_box, L.text("Schicht starten · fünf Aufgaben"), _start_shift, true)

func _start_shift() -> void:
	session = Activities.start(hud.game.model, asset_id)
	if not session.get("ok", false): hud.toast(session.get("message", "")); return
	_next_task()

func _next_task() -> void:
	for child in game_box.get_children():
		game_box.remove_child(child)
		child.queue_free()
	meter = null
	task = Activities.challenge(hud.game.model, session)
	if task.is_empty(): return
	picked.clear()
	elapsed = 0.0
	hud._label(game_box, L.text("Aufgabe %d / 5") % (int(session.step) + 1), 23, hud.TEAL)
	hud._label(game_box, task.prompt, 32, hud.INK, true)
	artwork = ActivityArt.new()
	artwork.kind = str(hud.game.model.asset(asset_id).kind)
	artwork.mode = str(task.mode)
	artwork.target = float(task.target)
	artwork.gate = int(task.get("answer", 1))
	artwork.custom_minimum_size.y = 190
	game_box.add_child(artwork)
	if task.mode == "timing":
		hud._label(game_box, L.text("Ziel: %.0f %% · grüner Bereich ± 10 %%") % (float(task.target) * 100.0), 18, hud.TEAL)
		meter = ProgressBar.new()
		meter.custom_minimum_size.y = 60
		meter.show_percentage = false
		game_box.add_child(meter)
		hud._button(game_box, L.text("Jetzt stoppen"), func(): _submit(cursor), true)
	elif task.mode == "pizza":
		var wanted: Array = []
		for key in task.toppings: wanted.append(L.text(Hospitality.TOPPINGS[key]))
		hud._label(game_box, L.text("Bestellung: %s") % ", ".join(wanted), 20, hud.MUTED, true)
		var row := HFlowContainer.new()
		game_box.add_child(row)
		for key in task.choices:
			var check := _check(row, L.text(Hospitality.TOPPINGS[key]), false)
			check.toggled.connect(func(value):
				if value: picked.append(key)
				else: picked.erase(key)
				artwork.toppings = picked.duplicate()
				artwork.queue_redraw())
		hud._button(game_box, L.text("Pizza backen und servieren"), func(): _submit(picked.duplicate()), true)
	else:
		var row := HFlowContainer.new()
		game_box.add_child(row)
		for index in range(task.choices.size()):
			hud._button(row, L.text(task.choices[index]), func(): _submit(index), true)
	status = hud._label(game_box, L.text("Punkte bisher: %d") % int(session.score), 18, hud.MUTED)

func _submit(value: Variant) -> void:
	var result := Activities.answer(hud.game.model, session, value)
	if not result.get("ok", false): return
	if result.get("finished", false):
		meter = null
		for child in game_box.get_children():
			game_box.remove_child(child)
			child.queue_free()
		hud._label(game_box, L.text("Deine Schicht ist geschafft!"), 30, hud.TEAL)
		hud._label(game_box, result.message, 22, hud.INK, true)
		hud._button(game_box, L.text("Noch eine Runde"), _start_shift, true)
	else:
		_next_task()

func _process(delta: float) -> void:
	if not visible or not is_instance_valid(meter) or task.get("mode", "") != "timing": return
	elapsed += delta
	cursor = (sin(elapsed * 1.9 - PI * 0.5) + 1.0) * 0.5
	artwork.cursor = cursor
	meter.value = cursor * 100.0
	meter.modulate = Color("66b395") if absf(cursor - float(task.target)) <= 0.1 else Color("d6aa70")
