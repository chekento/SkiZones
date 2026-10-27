extends PanelContainer
## The resort office is a paused planning space with real simulation actions.

const Progression = preload("res://src/core/progression.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Chart = preload("res://src/ui/finance_chart.gd")

var game: Node
var hud: CanvasLayer
var tabs := TabContainer.new()
var title: Label
var feedback: Label
var _feedback := ""

func setup(controller: Node, interface: CanvasLayer) -> void:
	game = controller
	hud = interface
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 48
	offset_right = -48
	offset_top = 124
	offset_bottom = -28
	add_theme_stylebox_override("panel", hud._style(Color("113340"), 18, 22))
	var layout: VBoxContainer = hud._vbox(self, 12)
	var header := HBoxContainer.new()
	layout.add_child(header)
	title = hud._label(header, "RESORT-BÜRO", 27, hud.ACCENT)
	hud._spacer(header, false)
	hud._button(header, "Zurück zum Berg", hide, true)
	feedback = hud._label(layout, "", 17, hud.TEAL, true)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 19)
	tabs.add_theme_stylebox_override("panel", hud._style(Color("163b47"), 10, 0))
	var tab_bar := tabs.get_tab_bar()
	for control in [tabs, tab_bar]:
		control.add_theme_stylebox_override("tab_selected", hud._style(Color("315965"), 7, 13))
		control.add_theme_stylebox_override("tab_unselected", hud._style(Color("1b414e"), 7, 13))
		control.add_theme_stylebox_override("tab_hovered", hud._style(Color("2b5360"), 7, 13))
		control.add_theme_color_override("font_selected_color", hud.ACCENT)
		control.add_theme_color_override("font_unselected_color", hud.MUTED)
	layout.add_child(tabs)
	hide()

func open() -> void:
	game._clear_input()
	_feedback = ""
	Progression.refresh(game.model)
	refresh()
	show()

func _page(name_value: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name_value
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 15)
	scroll.add_child(margin)
	return hud._vbox(margin, 14)

func _card(parent: Node, heading: String, text_value: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", hud._style(Color("204551"), 12, 16))
	parent.add_child(panel)
	var content: VBoxContainer = hud._vbox(panel, 9)
	hud._label(content, heading, 21, hud.INK, true)
	if text_value != "":
		hud._label(content, text_value, 17, hud.MUTED, true)
	return content

func _action(parent: Node, caption: String, callback: Callable, enabled: bool = true) -> Button:
	var button: Button = hud._button(parent, caption, func():
		var result: Dictionary = callback.call()
		_feedback = result.message
		hud.toast(result.message)
		hud.refresh()
		refresh()
	, enabled)
	button.disabled = not enabled
	return button

func refresh() -> void:
	var current := maxi(0, tabs.current_tab)
	var scroll_positions: Dictionary = {}
	for page in tabs.get_children():
		if page is ScrollContainer:
			scroll_positions[page.name] = page.scroll_vertical
		tabs.remove_child(page)
		page.queue_free()
	var state: Dictionary = game.model.campaign
	title.text = "RESORT-BÜRO  ·  %s  ·  %d FP" % ["★".repeat(state.rank), state.points]
	feedback.text = _feedback if _feedback != "" else state.notice
	_career(_page("Karriere"))
	_contracts(_page("Aufträge"))
	_research(_page("Forschung"))
	_upgrades(_page("Ausbau"))
	_finances(_page("Finanzen"))
	tabs.current_tab = mini(current, tabs.get_tab_count() - 1)
	for page in tabs.get_children():
		if page is ScrollContainer:
			page.set_deferred("scroll_vertical", scroll_positions.get(page.name, 0))

func _career(page: VBoxContainer) -> void:
	var model: RefCounted = game.model
	var state: Dictionary = model.campaign
	var summary := _card(page, "%s  ·  %s" % ["★".repeat(state.rank), Progression.RANK_NAMES[state.rank - 1]], "Winter %d · Tag %d von 28\n%.0f Erfahrung · %d abgeschlossene Aufträge · %s € Budget" % [Progression.season_number(model), Progression.season_day(model), state.xp, state.completed, hud.money_text(model.money)])
	hud._label(summary, Progression.next_goal(model), 18, hud.TEAL, true)
	if state.rank < 5:
		var bar := ProgressBar.new()
		bar.max_value = Progression.XP_STEPS[state.rank]
		bar.value = minf(state.xp, bar.max_value)
		bar.custom_minimum_size.y = 22
		bar.show_percentage = false
		summary.add_child(bar)
	var event := Progression.event(model)
	_card(page, "Heute: " + event.name, event.description)
	if not state.project.is_empty():
		_card(page, "In Arbeit: " + Progression.RESEARCH[state.project.id].name, "Fertig an Tag %d. Dein Resort kann während der Forschung normal weiterlaufen." % state.project.due_day)
	if Progression.has(model, "meteo"):
		var weather := _card(page, "Wetterplanung", "Die Vorschau entspricht dem Wetter der nächsten Betriebstage.")
		for offset in range(1, 7):
			var prediction: Dictionary = Catalog.WEATHER[Progression.weather_for_day(model.rng.seed, model.day + offset)]
			hud._label(weather, "Tag %d · %s · %.0f °C · Wind %.0f km/h" % [model.day + offset, prediction.name, prediction.temperature, prediction.wind], 17)
	else:
		_card(page, "Den nächsten Wintertag vorbereiten", "Erforsche die Bergwetterstation für eine Wettervorschau. Jeden Tag erscheinen neue Auftragsangebote. Am Ende eines 28-tägigen Winters erhältst du eine Wertung und eine Saisonprämie; dein Resort bleibt bestehen.")
	_card(page, "Karriere und freier Aufbau", "Karriere: Forschung schaltet neue Technik und Ausbaustufen frei. Im freien Aufbau sind die Anlagen direkt verfügbar; Aufträge, Forschungseffekte und Winterwertung bleiben nutzbar. Im Resort-Büro pausiert die Zeit, damit du in Ruhe planen kannst.")

func _contracts(page: VBoxContainer) -> void:
	var model: RefCounted = game.model
	var state: Dictionary = model.campaign
	hud._label(page, "Bis zu drei laufende Aufträge. Pro Betriebstag kannst du zwei neue annehmen.", 18, hud.MUTED, true)
	var running := 0
	for contract in state.contracts:
		running += int(contract.status in ["active", "ready"])
	for contract in state.contracts:
		var spec: Dictionary = Progression.CONTRACTS[contract.kind]
		var status: String = {"active": "Läuft", "ready": "Erfüllt", "claimed": "Belohnung abgeholt", "failed": "Frist abgelaufen"}[contract.status]
		var body := _card(page, "%s · %s" % [spec.name, status], "%s\n%.0f / %d · Frist: Ende Tag %d\nBelohnung: %s € und %d FP" % [spec.text, minf(contract.progress, contract.target), contract.target, contract.deadline, hud.money_text(contract.reward), contract.points])
		if contract.status in ["active", "ready"]:
			var bar := ProgressBar.new()
			bar.max_value = contract.target
			bar.value = minf(contract.progress, contract.target)
			bar.custom_minimum_size.y = 20
			body.add_child(bar)
			var id: String = contract.id
			_action(body, "Belohnung abholen", func(): return model.claim_contract(id), contract.status == "ready")
	hud._label(page, "NEUE ANGEBOTE", 16, hud.ACCENT)
	for offer in state.offers:
		var spec: Dictionary = Progression.CONTRACTS[offer.kind]
		var body := _card(page, spec.name, "%s Ziel: %d.\nFrist: Ende Tag %d · %s € + %d FP" % [spec.text, offer.target, offer.deadline, hud.money_text(offer.reward), offer.points])
		var id: String = offer.id
		var available: bool = not state.accepted_today.has(id) and state.accepted_today.size() < 2 and running < 3
		_action(body, "Auftrag annehmen" if not state.accepted_today.has(id) else "Bereits angenommen", func(): return model.accept_contract(id), available)

func _research(page: VBoxContainer) -> void:
	var model: RefCounted = game.model
	var state: Dictionary = model.campaign
	_card(page, "%d Forschungspunkte verfügbar" % state.points, "Forschungspunkte entstehen durch Erfahrung, abgeschlossene Aufträge und Betriebstage. Es kann immer nur ein Projekt laufen; danach kannst du das nächste starten. Kosten werden beim Start bezahlt.")
	for id_value in Progression.RESEARCH:
		var id: String = id_value
		var spec: Dictionary = Progression.RESEARCH[id]
		var done := Progression.has(model, id)
		var active: bool = not state.project.is_empty() and state.project.id == id
		var prefix := "✓ " if done else ("In Arbeit · " if active else "")
		var body := _card(page, prefix + spec.name, "%s\n%s € · %d FP · %d Betriebstag%s" % [spec.effect, hud.money_text(spec.cost), spec.points, spec.days, "e" if spec.days != 1 else ""])
		var check := Progression.research_check(model, id)
		hud._label(body, "Fertig an Tag %d" % state.project.due_day if active else check.message, 15, hud.TEAL, true)
		_action(body, "Abgeschlossen" if done else ("Wird erforscht" if active else "Forschung starten"), func(): return model.start_research(id), check.ok)

func _upgrades(page: VBoxContainer) -> void:
	var model: RefCounted = game.model
	_card(page, "Dein Bestand kann mitwachsen", "Pisten-Upgrades verbreitern die Abfahrt und mindern Verschleiß. Lift-Upgrades steigern Kapazität und Tempo. Gebäude-Upgrades verbessern Komfort und Erlöse. Höhere Stufen erhöhen auch Betriebskosten. Bestehende Gäste werden nach dem Ausbau neu geleitet.")
	for collection in [model.pistes, model.lifts, model.buildings]:
		for item in collection:
			var details := ""
			if item.has("bottom"):
				details = "%d Gäste/h · %.0f m Strecke" % [model.lift_capacity(item), item.length]
			elif item.has("difficulty"):
				details = "%.0f %% Zustand · %.0f cm Schnee · %.0f m Strecke" % [item.condition, item.snow, item.length]
			else:
				details = Catalog.BUILDINGS[item.kind].description
			var body := _card(page, "%s · Stufe %d / 3" % [item.name, item.get("level", 1)], details)
			var id: int = item.id
			var check: Dictionary = model.upgrade_check(id)
			hud._label(body, check.message, 16, hud.TEAL, true)
			_action(body, "Ausbauen", func(): return model.upgrade_asset(id), check.ok)

func _finances(page: VBoxContainer) -> void:
	var model: RefCounted = game.model
	var state: Dictionary = model.campaign
	_card(page, "Deine wirtschaftliche Entwicklung", "Budget: %s €\nTicket- und Serviceerlöse insgesamt: %s €\nBetriebliche Überschüsse seit Beginn: %s €\nAktueller Betrieb: ca. %s €/Tag\nKredit: %s €" % [hud.money_text(model.money), hud.money_text(state.turnover), hud.money_text(state.profit), hud.money_text(model.operating_costs()), hud.money_text(model.loan)])
	var graph := _card(page, "Ergebnis nach Investitionen · letzte 28 Betriebstage", "Grün: positives Ergebnis. Rot: Ausgaben für Betrieb und Investitionen übersteigen Einnahmen und Prämien. Kreditaufnahme und Tilgung sind keine Erlöse oder Betriebskosten.")
	var chart := Chart.new()
	chart.rows = state.history
	graph.add_child(chart)
	for i in range(state.history.size() - 1, -1, -1):
		var row: Dictionary = state.history[i]
		_card(page, "Tag %d · %s € Ergebnis" % [row.day, hud.money_text(row.net)], "%d Gäste · %d Abfahrten · %.0f %% Zufriedenheit\nErlöse %s € · Betrieb %s € · Investitionen %s € · Prämien %s €" % [row.guests, row.rides, row.satisfaction, hud.money_text(row.income), hud.money_text(row.costs), hud.money_text(row.investments), hud.money_text(row.rewards)])
