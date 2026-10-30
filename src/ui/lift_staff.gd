extends PanelContainer
const L = preload("res://src/core/i18n.gd")
const Ops = preload("res://src/core/operations.gd")
const DragScroll = preload("res://src/ui/drag_scroll.gd")
var hud: CanvasLayer
var lift_id := -1
var body: VBoxContainer
var summary: Label
var stations: HBoxContainer
var cards: Array = []
var feedback: Label

func setup(interface: CanvasLayer) -> void:
	hud = interface
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 48
	offset_right = -48
	offset_top = 120
	offset_bottom = -28
	add_theme_stylebox_override("panel", hud._style(Color("fffaf2"), 18, 22))
	body = hud._vbox(self, 12)
	var header := HBoxContainer.new()
	body.add_child(header)
	hud._label(header, L.text("LIFTTEAM & STATIONEN"), 26, hud.ACCENT)
	hud._spacer(header, false)
	hud._button(header, L.text("Zurück zum Lift"), hide, true)
	summary = hud._label(body, "", 20, hud.INK, true)
	hud._label(body, L.text("1. Station wählen · 2. Fehlende Tagschicht besetzen · 3. Dienststatus prüfen\n180 € je Einstellung · 18 €/h je Person im Dienst. Mittelstationen teilen sich ein Team."), 16, hud.MUTED, true)
	feedback = hud._label(body, "", 16, hud.TEAL, true)
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	stations = HBoxContainer.new()
	stations.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stations.add_theme_constant_override("separation", 18)
	scroll.add_child(stations)
	hud._button(body, L.text("Alle Mitarbeiter und Schichten verwalten"), func():
		hide()
		hud.show_management_page(L.text("Personal"))
	)
	hide()

func open(id: int) -> void:
	hud.game._clear_input()
	lift_id = id
	feedback.text = ""
	rebuild()
	show()

func action(callback: Callable) -> void:
	var result: Dictionary = callback.call()
	feedback.text = result.message
	hud.toast(result.message)
	rebuild()
	hud.refresh()

func rebuild() -> void:
	for child in stations.get_children():
		stations.remove_child(child)
		child.queue_free()
	cards.clear()
	var model: RefCounted = hud.game.model
	var lift: Dictionary = model.asset(lift_id)
	if not lift.has("bottom"):
		hide()
		return
	for station in Ops.station_team(model, lift):
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", hud._style(Color("edf3ec"), 12, 18))
		stations.add_child(panel)
		var card: VBoxContainer = hud._vbox(panel, 10)
		hud._label(card, station.name, 24, hud.TEAL)
		var status: Label = hud._label(card, "", 19, hud.INK, true)
		var hire: Button = hud._button(card, "", func(): action(func(): return Ops.fill_station(model, lift_id, station.key)), true)
		hire.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cards.append({"key": station.key, "status": status, "hire": hire})
		if station.people.is_empty(): hud._label(card, L.text("Noch niemand eingeplant."), 17, hud.ACCENT, true)
		for person in station.people:
			hud._label(card, person.name + " · " + (L.text("Im Dienst") if Ops.on_duty(model, person) else L.text("Außer Dienst / Pause / Abwesenheit")), 17, hud.TEAL if Ops.on_duty(model, person) else hud.ACCENT, true)
			var shift := OptionButton.new()
			shift.custom_minimum_size.y = 46
			for key in Ops.SHIFTS: shift.add_item(L.text(Ops.SHIFT_NAMES[key]))
			shift.select(Ops.SHIFTS.keys().find(person.shift))
			card.add_child(shift)
			shift.item_selected.connect(func(index: int): action(func(): return Ops.assign(model, int(person.id), station.key, Ops.SHIFTS.keys()[index])))
		var reserves: Array = model.operations.staff.filter(func(p): return p.role == "operator" and p.assignment == "reserve")
		if not reserves.is_empty():
			hud._label(card, L.text("Oder vorhandene Reserve einsetzen:"), 16, hud.MUTED, true)
			var choice := OptionButton.new()
			choice.custom_minimum_size.y = 46
			for person in reserves: choice.add_item(person.name + " · " + L.text(Ops.SHIFT_NAMES[person.shift]))
			card.add_child(choice)
			hud._button(card, L.text("Reserve dieser Station zuweisen · kostenlos"), func(): action(func(): return Ops.assign(model, int(reserves[choice.selected].id), station.key, "day")))
	refresh_status()

func refresh_status() -> void:
	var model: RefCounted = hud.game.model
	var lift: Dictionary = model.asset(lift_id)
	if not lift.has("bottom"): return
	var crew := Ops.staffing(model, lift)
	summary.text = L.text("%s · %d / %d im Dienst · %s") % [L.asset_name(lift), crew.present, crew.needed, model.lift_status(lift)]
	for station in Ops.station_team(model, lift):
		for card in cards:
			if card.key != station.key: continue
			card.status.text = L.text("%d / %d im Dienst · %d Personen eingeplant\nTagschicht: %d / %d besetzt") % [station.present, station.minimum, station.people.size(), station.planned, station.minimum]
			card.hire.text = L.text("Tagschicht vollständig besetzt") if station.missing == 0 else L.text("%d fehlende Person(en) einstellen · %d €") % [station.missing, station.missing * 180]
			card.hire.disabled = station.missing == 0 or model.money < station.missing * 180
