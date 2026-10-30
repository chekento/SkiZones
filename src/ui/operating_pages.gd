extends RefCounted
const L = preload("res://src/core/i18n.gd")
const Ops = preload("res://src/core/operations.gd")
const Geo = preload("res://src/core/real_resorts.gd")

static func add(office: Control) -> void:
	var model: RefCounted = office.game.model
	if not Ops.active(model): return
	var hud: CanvasLayer = office.hud
	var page: VBoxContainer = office._page(L.text("Betrieb"))
	if model.operations.scenario != "":
		var scenario: String = model.operations.scenario
		var goals := Ops.evaluate(model)
		var card: VBoxContainer = office._card(page, L.text("Szenarioziele") + (" ✓" if model.operations.completed else ""), L.text("Alle Ziele erfüllen: 75.000 € und 30 Forschungspunkte. Der Betrieb geht anschließend weiter."))
		for i in range(goals.size()): hud._label(card, ("✓ " if goals[i] else "○ ") + L.text(Ops.GOALS[scenario][i]), 18, hud.TEAL if goals[i] else hud.INK, true)
	var summary: VBoxContainer = office._card(page, L.text("24-Stunden-Resort"), L.text("Lifte 08–17 Uhr. Hotels und Abendangebote haben eigene Schichten. Um Mitternacht wird automatisch abgerechnet; die Simulation läuft weiter."))
	hud._label(summary, L.text("Heute: %s € Personalkosten · Ersatzteile: %d · Pistenraupen: %d") % [hud.money_text(model.operations.payroll), int(model.operations.parts), model.operations.vehicles.size()], 18, hud.TEAL, true)
	hud._label(summary, L.text("Gäste pro sichtbarer Reisegruppe: %d. Tickets, Kapazitäten und Erlöse berücksichtigen die Gruppengröße.") % Ops.group_size(model), 16, hud.MUTED, true)
	if model.operations.event != "": hud._label(summary, L.text("Betriebsereignis: ") + L.text(model.operations.event), 17, hud.ACCENT, true)
	if model.operations.delivery_at >= 0: hud._label(summary, L.text("Ersatzteillieferung in %d Minuten") % maxi(0, int(model.operations.delivery_at) - Ops.clock(model)), 16)
	office._action(summary, L.text("6 Ersatzteilpakete bestellen · 1.800 €"), func(): return Ops.order_parts(model))
	var auto := CheckButton.new()
	auto.text = L.text("Pisten nachts automatisch präparieren")
	auto.button_pressed = model.operations.auto_groom
	auto.toggled.connect(func(value): model.operations.auto_groom = value)
	summary.add_child(auto)
	for lift in model.lifts:
		var crew := Ops.staffing(model, lift)
		var body: VBoxContainer = office._card(page, L.asset_name(lift), model.lift_status(lift))
		hud._button(body, L.text("Liftteam und einzelne Stationen öffnen"), func():
			office.hide()
			hud.lift_staff.open(int(lift.id))
		, true)
		hud._label(body, L.text("Besetzung %d / %d · %.0f %% Verschleiß · %d Wartende") % [crew.present, crew.needed, float(lift.get("wear", 0)), model.queue_size(int(lift.id))], 16, hud.MUTED, true)
		if int(lift.get("sections", 1)) > 1: hud._label(body, L.text("Durchgehende Seilbahn · Abschnitt %d / %d · gemeinsame Mittelstation") % [int(lift.section) + 1, int(lift.sections)], 16, hud.TEAL, true)
		office._action(body, L.text("Stationspersonal einstellen · 180 € pro Person"), func(): return Ops.fill_stations(model, int(lift.id)))
		if lift.get("fault", "") != "":
			office._action(body, L.text("Reparatur beauftragen · 900 € + Ersatzteil"), func(): return Ops.repair(model, int(lift.id)))
			if model.lift_load(lift).riders > 0: office._action(body, L.text("Evakuierung organisieren"), func(): return Ops.evacuate(model, int(lift.id)))
		for task in model.operations.repairs:
			if int(task.asset) == int(lift.id): hud._label(body, L.text("Reparatur: noch %.0f Arbeitsminuten") % float(task.remaining), 16, hud.TEAL)
	var people: VBoxContainer = office._page(L.text("Personal"))
	office._card(people, L.text("Einsatzorte und Schichten"), L.text("Mindestbesetzung und Löhne sind Spielparameter. Jede besetzte Station verursacht Kosten. Versetze Mitarbeiter zwischen Stationen oder Schichten; eine unbesetzte Anlage bleibt geschlossen."))
	var targets: Array = [{"key": "reserve", "name": L.text("Reserve / Pausenvertretung")}]
	var used: Dictionary = {}
	for lift in model.lifts:
		for station in Ops.station_demands(lift):
			if used.has(station.key): continue
			used[station.key] = true
			targets.append({"key": station.key, "name": "%s · %s" % [L.asset_name(lift), L.text("Berg / Mittel") if station.top else L.text("Tal / Mittel")]})
	for building in model.buildings: targets.append({"key": "building:%d" % int(building.id), "name": L.asset_name(building)})
	var hiring: VBoxContainer = office._card(people, L.text("Mitarbeiter einstellen"), L.text("180 € Einstellungskosten. Der Stundenlohn fällt nur während der eingeteilten Arbeitszeit an."))
	hud._label(hiring, L.text("1 · Aufgabe und Stundenlohn"), 16, hud.TEAL)
	var role_choice := OptionButton.new()
	role_choice.custom_minimum_size.y = 46
	for role in Ops.ROLES: role_choice.add_item(L.text(Ops.ROLES[role].name) + " · %.0f €/h" % float(Ops.ROLES[role].wage))
	hiring.add_child(role_choice)
	hud._label(hiring, L.text("2 · Einsatzort"), 16, hud.TEAL)
	var hire_target := _targets(hiring, targets)
	hud._label(hiring, L.text("3 · Arbeitszeit"), 16, hud.TEAL)
	var hire_shift := _shifts(hiring)
	office._action(hiring, L.text("Einstellen · 180 €"), func(): return Ops.hire(model, Ops.ROLES.keys()[role_choice.selected], targets[hire_target.selected].key, Ops.SHIFTS.keys()[hire_shift.selected]))
	var directory: VBoxContainer = office._card(people, L.text("Dein Team · Einsatzorte und Dienststatus"), L.text("Am Lift kannst du Tal-, Berg- und Mittelstation direkt besetzen. Hier filterst du das gesamte Team nach Aufgabe und Einsatzort."))
	var roles := OptionButton.new()
	roles.custom_minimum_size.y = 46
	roles.add_item(L.text("Alle Aufgaben"))
	for role in Ops.ROLES: roles.add_item(L.text(Ops.ROLES[role].name))
	roles.select(Ops.ROLES.keys().find(office.staff_role) + 1)
	directory.add_child(roles)
	roles.item_selected.connect(func(index: int):
		office.staff_role = "" if index == 0 else Ops.ROLES.keys()[index - 1]
		office.staff_page = 0
		office.refresh()
	)
	var locations: Array = [{"key": "", "name": L.text("Alle Einsatzorte")}]
	locations.append_array(targets)
	var location := _targets(directory, locations)
	for index in range(locations.size()):
		if locations[index].key == office.staff_target: location.select(index)
	location.item_selected.connect(func(index: int):
		office.staff_target = locations[index].key
		office.staff_page = 0
		office.refresh()
	)
	var filtered: Array = model.operations.staff.filter(func(p): return (office.staff_role == "" or p.role == office.staff_role) and (office.staff_target == "" or p.assignment == office.staff_target))
	var pages := maxi(1, ceili(filtered.size() / 12.0))
	office.staff_page = clampi(office.staff_page, 0, pages - 1)
	hud._label(directory, L.text("%d Mitarbeiter · Seite %d / %d") % [filtered.size(), office.staff_page + 1, pages], 17, hud.TEAL)
	var navigation := HBoxContainer.new()
	directory.add_child(navigation)
	hud._button(navigation, L.text("Vorherige Seite"), func():
		office.staff_page -= 1
		office.refresh()
	).disabled = office.staff_page == 0
	hud._button(navigation, L.text("Nächste Seite"), func():
		office.staff_page += 1
		office.refresh()
	).disabled = office.staff_page == pages - 1
	for person in filtered.slice(office.staff_page * 12, (office.staff_page + 1) * 12):
		var body: VBoxContainer = office._card(people, "%s · %s" % [person.name, L.text(Ops.ROLES[person.role].name)], L.text("%.0f €/h · Qualifikation %d · Motivation %.0f %% · Belastung %.0f %% · %d Arbeitsminuten") % [float(person.wage), int(person.qualification), float(person.motivation), float(person.fatigue), int(person.worked)])
		hud._label(body, L.text("Im Dienst") if Ops.on_duty(model, person) else L.text("Außer Dienst / Pause / Abwesenheit"), 16, hud.TEAL)
		var target := _targets(body, targets)
		for i in range(targets.size()):
			if targets[i].key == person.assignment: target.select(i)
		var shift := _shifts(body)
		shift.select(Ops.SHIFTS.keys().find(person.shift))
		office._action(body, L.text("Zuweisung übernehmen"), func(): return Ops.assign(model, int(person.id), targets[target.selected].key, Ops.SHIFTS.keys()[shift.selected]))
		office._action(body, L.text("30 Minuten Pause"), func():
			person.break_until = Ops.clock(model) + 30
			model._duty_cache.clear()
			model._invalidate()
			return model._result(true, L.text("Pause eingetragen. Eine Vertretung kann im Personalplan zugewiesen werden."))
		)
		office._action(body, L.text("Mitarbeiter freistellen"), func(): return Ops.dismiss(model, int(person.id)))
	var services: VBoxContainer = office._page(L.text("Technik & Rettung"))
	for building in model.buildings:
		var body: VBoxContainer = office._card(services, L.asset_name(building), L.text("Betriebsbereit") if Ops.building_open(model, building) else L.text("Geschlossen oder Personal fehlt"))
		office._action(body, L.text("Gebäudeteam einstellen"), func(): return Ops.fill_building(model, int(building.id)))
		if building.kind == "maintenance": office._action(body, L.text("Pistenraupe kaufen · 65.000 €"), func(): return Ops.buy_groomer(model, int(building.id)))
		if building.kind == "first_aid": hud._label(body, L.text("Einsatzradius: %.0f m · Reaktionszeit folgt den tatsächlichen Wegen und dem Wetter.") % (1800 * int(building.get("level", 1))), 16, hud.TEAL, true)
	for vehicle in model.operations.vehicles:
		var body: VBoxContainer = office._card(services, L.text("Pistenraupe %d") % int(vehicle.id), L.text("%.1f Betriebsstunden · %.0f %% Energie · %.0f %% Verschleiß") % [float(vehicle.hours), float(vehicle.fuel), float(vehicle.wear)])
		if vehicle.piste < 0 or vehicle.fuel <= 0 or vehicle.wear >= 100: office._action(body, L.text("Warten und auftanken · 800 €"), func(): return Ops.service_vehicle(model, int(vehicle.id)))
		else: hud._label(body, L.text("Präparierung: noch %.0f Minuten") % float(vehicle.remaining), 16, hud.TEAL)
	for piste in model.pistes:
		if piste.condition >= 85: continue
		var body: VBoxContainer = office._card(services, L.asset_name(piste), L.text("Zustand %.0f %% · Präparierung nur ohne Gäste auf der Piste") % float(piste.condition))
		office._action(body, L.text("Piste schließen / öffnen"), func():
			model.set_enabled(int(piste.id), not piste.enabled)
			return model._result(true, L.text("Pistenfreigabe aktualisiert."))
		)
		office._action(body, L.text("Präparieren · 220 €"), func(): return Ops.groom(model, int(piste.id)))
	for event in model.operations.incidents:
		if event.status == "resolved": continue
		var body: VBoxContainer = office._card(services, L.text("Hilferuf · Gast %d") % int(event.guest), L.text("Wartet auf Hilfe") if event.status == "waiting" else L.text("Rettung unterwegs · %.0f Minuten") % float(event.remaining))
		office._action(body, L.text("Rettung entsenden"), func(): return Ops.dispatch(model, int(event.id)))
	var finance: VBoxContainer = office._page(L.text("Kostenstellen"))
	office._card(finance, L.text("Laufende Kosten und Liquidität"), L.text("Personalkosten und Infrastruktur werden minutengenau abgezogen. Investitionen erscheinen separat. Der Mitternachtsbericht speichert Einnahmen, laufende Kosten und Ergebnis für 28 Tage."))
	var room := SpinBox.new()
	room.min_value = 40
	room.max_value = 250
	room.step = 5
	room.value = model.operations.room_price
	room.prefix = L.text("Zimmerpreis · ")
	room.suffix = " €"
	room.value_changed.connect(func(value): model.operations.room_price = int(value))
	finance.add_child(room)
	for centre in model.operations.cost_centres:
		var name_value: String = centre
		if str(centre).begins_with("building:"): name_value = L.asset_name(model.asset(str(centre).get_slice(":", 1).to_int()))
		for target in targets:
			if target.key == centre: name_value = target.name
		var names := {"infrastructure": "Infrastruktur", "recruitment": "Einstellungen", "spare_parts": "Ersatzteile", "repairs": "Reparaturen", "grooming": "Präparierung", "vehicle_service": "Fahrzeugwartung"}
		if names.has(centre): name_value = L.text(names[centre])
		office._card(finance, name_value, "%s €" % hud.money_text(model.operations.cost_centres[centre]))
	for i in range(model.operations.history.size() - 1, -1, -1):
		var row: Dictionary = model.operations.history[i]
		office._card(finance, L.text("Tag %d · %s € Betriebsergebnis") % [int(row.day), hud.money_text(row.tickets + row.services - row.costs)], L.text("Erlöse %s € · Betrieb %s € · Investitionen %s €") % [hud.money_text(row.tickets + row.services), hud.money_text(row.costs), hud.money_text(row.investments)])

static func _targets(parent: Node, targets: Array) -> OptionButton:
	var choice := OptionButton.new()
	choice.custom_minimum_size.y = 46
	for target in targets: choice.add_item(target.name)
	choice.fit_to_longest_item = false
	choice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(choice)
	return choice

static func _shifts(parent: Node) -> OptionButton:
	var choice := OptionButton.new()
	choice.custom_minimum_size.y = 46
	for shift in Ops.SHIFTS: choice.add_item(L.text(Ops.SHIFT_NAMES[shift]))
	parent.add_child(choice)
	return choice
