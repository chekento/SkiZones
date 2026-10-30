extends PanelContainer
const L = preload("res://src/core/i18n.gd")
const Agenda = preload("res://src/core/guest_agenda.gd")
const DragScroll = preload("res://src/ui/drag_scroll.gd")
var hud: CanvasLayer
var body: VBoxContainer
var target_choice := OptionButton.new()
var needs_label: Label
var cards: VBoxContainer

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
	hud._label(header, L.text("GÄSTE & WÜNSCHE"), 26, hud.ACCENT)
	hud._spacer(header, false)
	hud._button(header, L.text("Zurück zum Berg"), hide, true)
	hud._label(body, L.text("Passende Pisten und erreichbare Pausenangebote ziehen dein Publikum an. Tatsächliche Erlebnisse bestimmen Rückmeldungen, Nachfrage und Erlöse."), 17, hud.MUTED, true)
	needs_label = hud._label(body, "", 18, hud.TEAL, true)
	var row := HBoxContainer.new()
	body.add_child(row)
	hud._label(row, L.text("Werbung ausrichten:"), 17, hud.INK)
	row.add_child(target_choice)
	target_choice.custom_minimum_size.y = 46
	target_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_choice.add_item(L.text("Ausgewogen · keine Zusatzkosten"))
	for kind in Agenda.TYPES: target_choice.add_item(L.text(Agenda.TYPES[kind].name) + L.text(" · 250 €/Tag"))
	target_choice.item_selected.connect(func(index: int):
		hud.game.model.audience.target = "balanced" if index == 0 else Agenda.TYPES.keys()[index - 1]
		hud.toast(L.text("Werbung aktualisiert. Die Ausrichtung verändert die Gästemischung; laufende Kosten sind im Betrieb enthalten."))
	)
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	cards = hud._vbox(scroll, 12)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hide()

func open() -> void:
	hud.game._clear_input()
	refresh()
	show()

func refresh() -> void:
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	var model: RefCounted = hud.game.model
	var current: Dictionary = {}
	var hunger := 0
	var cold := 0
	var tired := 0
	for kind in Agenda.TYPES: current[kind] = {"people": 0, "score": 0.0}
	for guest in model.guests:
		if guest.phase == "leaving": continue
		Agenda.ensure(model, guest)
		var count: int = guest.get("group_size", 1)
		current[guest.agenda.kind].people += count
		current[guest.agenda.kind].score += Agenda.satisfaction(model, guest) * count
		if guest.has("family"):
			for member in guest.family:
				hunger += int(member.needs.hunger > 70)
				cold += int(member.needs.warmth < 35)
				tired += int(member.needs.energy < 25)
		else:
			hunger += count * int(guest.needs.hunger > 70)
			cold += count * int(guest.needs.warmth < 35)
			tired += count * int(guest.needs.energy < 25)
	needs_label.text = L.text("Ungedeckte Bedürfnisse · Hunger: %d · Kälte: %d · Erschöpfung: %d Personen") % [hunger, cold, tired]
	target_choice.select(0 if model.audience.target == "balanced" else Agenda.TYPES.keys().find(model.audience.target) + 1)
	var supply := Agenda.offer(model)
	for kind in Agenda.TYPES:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", hud._style(Color("edf3ec"), 12, 16))
		cards.add_child(panel)
		var card: VBoxContainer = hud._vbox(panel, 7)
		hud._label(card, L.text(Agenda.TYPES[kind].name), 22, hud.TEAL, true)
		hud._label(card, L.text(Agenda.TYPES[kind].wish), 17, hud.INK, true)
		var row: Dictionary = model.audience.segments[kind]
		var present: Dictionary = current[kind]
		hud._label(card, L.text("%d Personen vor Ort · Passung des erreichbaren Angebots: %.0f %%") % [present.people, Agenda.fit(kind, supply) * 100], 17, hud.INK, true)
		if present.people > 0: hud._label(card, L.text("Aktuelles Tagesgefühl: %.0f %%") % (present.score / present.people), 17, hud.TEAL)
		var review: String = L.text("Noch keine Rückmeldungen nach der Abreise.") if row.departures == 0 else L.text("%d Abreisen · durchschnittlich %.0f %% zufrieden") % [row.departures, row.satisfaction / row.departures]
		hud._label(card, review + "\n" + L.text("Erfasste Erlöse: %s € Tageskarten · %s € Besuche") % [hud.money_text(row.tickets), hud.money_text(row.services)], 16, hud.MUTED, true)
	hud._label(cards, L.text("Familien entscheiden gemeinsam nach der niedrigsten Komfortgrenze und dem dringendsten Bedürfnis. Sammler zählen nur tatsächlich abgeschlossene Fahrten; Teilstücke werden zur vollständigen Piste zusammengesetzt."), 17, hud.MUTED, true)
