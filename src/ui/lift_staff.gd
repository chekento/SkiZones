extends PanelContainer
## The selected asset owns its complete operating and staffing controls.
const L = preload("res://src/core/i18n.gd")
const Ops = preload("res://src/core/operations.gd")
const Catalog = preload("res://src/core/catalog.gd")
const DragScroll = preload("res://src/ui/drag_scroll.gd")
var hud: CanvasLayer
var lift_id := -1
var body: VBoxContainer
var title: Label
var summary: Label
var stations: GridContainer
var tabs: TabContainer
var cards: Array = []
var feedback: Label
var expanded: Dictionary = {}
func setup(interface: CanvasLayer) -> void:
	hud = interface
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left=42;offset_right=-42;offset_top=116;offset_bottom=-24
	add_theme_stylebox_override("panel",hud._style(Color("fffaf2"),18,20))
	get_viewport().size_changed.connect(func():
		if is_instance_valid(stations):stations.columns=_columns())
	body=hud._vbox(self,10)
	var header:=HBoxContainer.new();body.add_child(header)
	title=hud._label(header,L.text("ANLAGE & BETRIEB"),24,hud.ACCENT)
	hud._spacer(header,false)
	hud._button(header,L.text("Zurück zur Anlage"),hide,true)
	summary=hud._label(body,"",19,hud.INK,true)
	feedback=hud._label(body,"",16,hud.TEAL,true)
	tabs=TabContainer.new();tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size",19)
	tabs.add_theme_stylebox_override("panel",hud._style(Color("f5f5ed"),10,8))
	for control in [tabs,tabs.get_tab_bar()]:
		control.add_theme_stylebox_override("tab_selected",hud._style(Color("d3e7dc"),7,13))
		control.add_theme_stylebox_override("tab_unselected",hud._style(Color("edf3ec"),7,13))
		control.add_theme_stylebox_override("tab_hovered",hud._style(Color("e2eee6"),7,13))
		control.add_theme_color_override("font_selected_color",hud.ACCENT)
		control.add_theme_color_override("font_unselected_color",hud.MUTED)
	body.add_child(tabs)
	hud._label(body,L.text("Nach dem Schließen läuft die Zeit weiter. Reparaturen und Einsätze brauchen Arbeitszeit."),15,hud.MUTED,true)
	hide()
func _page(caption: String) -> VBoxContainer:
	var scroll:=DragScroll.new();scroll.name=caption
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
	var box: VBoxContainer=hud._vbox(scroll,14);box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return box
func _card(parent: Node, caption: String, note: String="") -> VBoxContainer:
	var panel:=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",hud._style(Color("edf3ec"),12,15));parent.add_child(panel)
	var box: VBoxContainer=hud._vbox(panel,9)
	hud._label(box,caption,21,hud.TEAL,true)
	if note!="":hud._label(box,note,16,hud.MUTED,true)
	return box
func _button(parent: Node, caption: String, callback: Callable, enabled: bool=true) -> Button:
	var button: Button=hud._button(parent,caption,func():action(callback))
	button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;button.disabled=not enabled
	return button
func _choice(parent: Node, labels: Array) -> OptionButton:
	var choice:=OptionButton.new();choice.custom_minimum_size.y=44
	choice.fit_to_longest_item=false;choice.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	for caption in labels:choice.add_item(caption)
	parent.add_child(choice);return choice
func open(id: int) -> void:
	hud.game._clear_input()
	if lift_id != id: expanded.clear()
	lift_id=id;feedback.text="";rebuild()
	tabs.current_tab=1 if hud.game.model.asset(id).has("bottom") else 0
	show()
func action(callback: Callable) -> void:
	var result: Dictionary=callback.call()
	feedback.text=result.message;hud.toast(result.message);rebuild();hud.refresh()
	if result.ok and hud.game.has_game:hud.game.save_game()
func _toggle(id: int) -> Dictionary:
	var model: RefCounted=hud.game.model
	model.set_enabled(id,not model.asset(id).enabled)
	return model._result(true,L.text("Betriebsfreigabe aktualisiert."))
func _toggle_line() -> Dictionary:
	var model: RefCounted=hud.game.model
	var parts:=Ops.line_lifts(model,model.asset(lift_id))
	var enabled: bool=not parts.any(func(part):return part.enabled)
	for part in parts:model.set_enabled(int(part.id),enabled)
	return model._result(true,L.text("Betriebsfreigabe aktualisiert."))
func _demolish() -> void:
	var dialog:=ConfirmationDialog.new();dialog.title=L.text("Anlage abbauen?")
	dialog.dialog_text=L.text("Beim Abbau erhältst du 25 % der Investition zurück.")
	add_child(dialog)
	dialog.confirmed.connect(func():hud.game.demolish_asset(lift_id);hide();dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free);dialog.popup_centered(Vector2i(500,190))
func rebuild() -> void:
	var previous:=tabs.current_tab
	for child in tabs.get_children():tabs.remove_child(child);child.queue_free()
	cards.clear()
	var model: RefCounted=hud.game.model
	var item: Dictionary=model.asset(lift_id)
	if not item.has("bottom") and not Catalog.BUILDINGS.has(item.get("kind","")):hide();return
	title.text=L.text("LIFTBETRIEB & STATIONEN") if item.has("bottom") else L.text("GEBÄUDE & TEAM")
	_build_operation(_page(L.text("Betrieb")),item)
	var people:=_page(L.text("Personal"))
	if Ops.active(model):
		if item.has("bottom"):_lift_people(people,item)
		else:_building_people(people,item)
	else:_card(people,L.text("Personal"),L.text("In diesem Spielstand wird der Betrieb ohne einzelne Mitarbeiter simuliert."))
	var design:=_card(_page(L.text("Gestalten")),L.asset_name(item),L.text("Name, Farbe und Standort direkt an dieser Anlage ändern."))
	hud._button(design,L.text("Gestalten & umplanen"),func():hide();hud.asset_editor.open(lift_id),true)
	hud._button(design,L.text("Abbauen · 25 % Erstattung"),_demolish,true)
	tabs.current_tab=clampi(previous,0,tabs.get_tab_count()-1);refresh_status()
func _build_operation(parent: Node, item: Dictionary) -> void:
	var model: RefCounted=hud.game.model
	var general:=_card(parent,L.asset_name(item),L.text("Betrieb, Team und Gestaltung dieser Anlage."))
	if item.has("bottom"):
		var parts:=Ops.line_lifts(model,item)
		_button(general,L.text("Liftverbund schließen") if parts.any(func(part):return part.enabled) else L.text("Liftverbund öffnen"),_toggle_line)
	else:_button(general,L.text("Schließen") if item.enabled else L.text("Öffnen"),func():return _toggle(lift_id))
	var upgrade: Dictionary=model.upgrade_check(lift_id)
	_button(general,L.text("Anlage ausbauen")+" · "+hud.money_text(upgrade.get("cost",0))+" €",func():return model.upgrade_asset(lift_id),upgrade.ok)
	hud._label(general,upgrade.message,16,hud.MUTED,true)
	if item.has("bottom"):
		for part in Ops.line_lifts(model,item):
			var box:=_card(parent,L.asset_name(part),model.lift_status(part))
			hud._label(box,L.text("%.0f %% Verschleiß · %d Wartende") % [float(part.get("wear",0)),model.queue_size(int(part.id))],16,hud.MUTED,true)
			_button(box,L.text("Abschnitt schließen") if part.enabled else L.text("Abschnitt öffnen"),func():return _toggle(int(part.id)))
			if part.get("fault","")!="":
				var check:=Ops.repair_check(model,int(part.id))
				_button(box,L.text("Reparatur beauftragen · 900 € + Ersatzteil"),func():return Ops.repair(model,int(part.id)),check.ok)
				hud._label(box,check.message,16,hud.ACCENT,true)
				if model.lift_load(part).riders>0:_button(box,L.text("Evakuierung organisieren"),func():return Ops.evacuate(model,int(part.id)))
			for job in model.operations.repairs:
				if int(job.asset)==int(part.id):hud._label(box,L.text("Reparatur: noch %.0f Arbeitsminuten") % float(job.remaining),16,hud.TEAL)
		if Ops.active(model):_parts(parent)
		return
	var visits:=_card(parent,L.text("Besuche & Betriebskosten"),L.text(Catalog.BUILDINGS[item.kind].description))
	hud._label(visits,L.text("%d €/Tag · %d Besuche · %s € Besuchserlöse") % [int(Catalog.BUILDINGS[item.kind].upkeep),int(item.get("visits",0)),hud.money_text(item.get("revenue",0))],17,hud.TEAL,true)
	if model.Needs.SERVICES.has(item.kind):hud._label(visits,L.text("%d / %d Plätze belegt") % [model.service_load(lift_id),model.service_capacity(item)],16,hud.MUTED)
	if not Ops.active(model):return
	if item.kind=="repair_office":
		_parts(parent)
		for lift in model.lifts:
			if lift.get("fault","")=="":continue
			var check:=Ops.repair_check(model,int(lift.id),lift_id)
			var box:=_card(parent,L.asset_name(lift),check.message)
			_button(box,L.text("Von dieser Werkstatt reparieren · 900 € + Ersatzteil"),func():return Ops.repair(model,int(lift.id),lift_id),check.ok)
		for job in model.operations.repairs:
			if int(job.workshop)==lift_id:_card(parent,L.asset_name(model.asset(int(job.asset))),L.text("Reparatur: noch %.0f Arbeitsminuten") % float(job.remaining))
	if item.kind=="maintenance":
		var garage:=_card(parent,L.text("Fahrzeuge & Präparierung"))
		_button(garage,L.text("Pistenraupe kaufen · 65.000 €"),func():return Ops.buy_groomer(model,lift_id),item.enabled and model.money>=65000 and model.operations.vehicles.size()<24)
		var auto:=CheckButton.new();auto.text=L.text("Pisten nachts automatisch präparieren");auto.button_pressed=model.operations.auto_groom
		auto.toggled.connect(func(value):model.operations.auto_groom=value);garage.add_child(auto)
		for vehicle in model.operations.vehicles:
			if int(vehicle.garage)!=lift_id:continue
			var box:=_card(parent,L.text("Pistenraupe %d") % int(vehicle.id),L.text("%.1f Betriebsstunden · %.0f %% Energie · %.0f %% Verschleiß") % [float(vehicle.hours),float(vehicle.fuel),float(vehicle.wear)])
			_button(box,L.text("Warten und auftanken · 800 €"),func():return Ops.service_vehicle(model,int(vehicle.id)),model.money>=800 and (vehicle.piste<0 or vehicle.fuel<=0 or vehicle.wear>=100))
			if vehicle.piste>=0:hud._label(box,L.text("Präparierung: noch %.0f Minuten") % float(vehicle.remaining),16,hud.TEAL)
		if not model.pistes.is_empty():
			var labels: Array=[]
			for piste in model.pistes:labels.append(L.asset_name(piste))
			var choice:=_choice(garage,labels)
			_button(garage,L.text("Präparieren · 220 €"),func():return Ops.groom(model,int(model.pistes[choice.selected].id),lift_id))
	if item.kind=="first_aid":
		_card(parent,L.text("Bergwacht"),L.text("Einsatzradius: %.0f m · Reaktionszeit folgt den tatsächlichen Wegen und dem Wetter.") % (1800*int(item.get("level",1))))
		for event in model.operations.incidents:
			if event.status=="resolved":continue
			var box:=_card(parent,L.text("Hilferuf · Gast %d") % int(event.guest),L.text("Wartet auf Hilfe") if event.status=="waiting" else L.text("Rettung unterwegs · %.0f Minuten") % float(event.remaining))
			if event.status=="waiting":_button(box,L.text("Von hier Rettung entsenden"),func():return Ops.dispatch(model,int(event.id),lift_id))
	if model.Hospitality.lodging(str(item.kind)):
		var box := _card(parent, L.text("Unterkunft verwalten"))
		hud._button(box, L.text("Hotel, Zimmer und Ketten öffnen"), func(): hide(); hud.experience.open(lift_id), true)

func _parts(parent: Node) -> void:
	var model: RefCounted=hud.game.model
	var box:=_card(parent,L.text("Ersatzteile"),L.text("Resortbestand: %d Ersatzteilpakete") % int(model.operations.parts))
	if model.operations.delivery_at>=0:hud._label(box,L.text("Ersatzteillieferung in %d Minuten") % maxi(0,int(model.operations.delivery_at)-Ops.clock(model)),16)
	_button(box,L.text("6 Ersatzteilpakete bestellen · 1.800 €"),func():return Ops.order_parts(model),model.operations.delivery_at<0 and model.money>=1800)
func _columns() -> int:
	return 3 if get_window().size.x >= 1250 else 2 if get_window().size.x >= 1100 else 1
func _team_details(parent: Node, key: String) -> VBoxContainer:
	var details: VBoxContainer=hud._vbox(parent,8)
	var toggle: Button=hud._button(parent,L.text("Team & Schichten anzeigen"),func():
		details.visible=not details.visible
		expanded[key]=details.visible)
	parent.move_child(toggle,parent.get_child_count()-2)
	details.visible=expanded.get(key,false)
	return details
func _grid(parent: Node) -> void:
	stations=GridContainer.new();stations.columns=_columns()
	stations.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stations.add_theme_constant_override("h_separation",14);stations.add_theme_constant_override("v_separation",14);parent.add_child(stations)
func _lift_people(parent: Node, item: Dictionary) -> void:
	var model: RefCounted=hud.game.model
	var rows:=Ops.line_station_team(model,item)
	var missing:=0
	for row in rows:missing+=row.missing
	_button(parent,L.text("Alle Stationen besetzen · %d Personen · %d €") % [missing,missing*180],func():return Ops.fill_line(model,lift_id),missing>0 and model.money>=missing*180)
	hud._label(parent,L.text("Gemeinsame Mittelstationen teilen sich ein Team. Pausen ändern den Dienststatus, nicht die geplante Besetzung."),16,hud.MUTED,true)
	_grid(parent)
	for row in rows:
		var box:=_card(stations,row.name)
		var status: Label=hud._label(box,"",17,hud.INK,true)
		var hire:=_button(box,"",func():return Ops.fill_line_station(model,lift_id,row.key))
		cards.append({"key":row.key,"status":status,"hire":hire})
		if row.people.is_empty():hud._label(box,L.text("Noch niemand eingeplant."),16,hud.ACCENT,true)
		var details:=_team_details(box,row.key)
		_people(details,row.people,row.key)
		_reserve(details,"operator",row.key,"day")
func _building_people(parent: Node, item: Dictionary) -> void:
	var model: RefCounted=hud.game.model
	var rows:=Ops.building_team(model,item)
	var missing:=0
	for row in rows:missing+=row.missing
	if rows.is_empty():_card(parent,L.text("Personal"),L.text("Diese Anlage benötigt kein eigenes Personal."));return
	_button(parent,L.text("Alle Schichten besetzen · %d Personen · %d €") % [missing,missing*180],func():return Ops.fill_building(model,lift_id),missing>0 and model.money>=missing*180)
	_grid(parent)
	var shown: Array=[]
	for row in rows:
		var box:=_card(stations,L.text(Ops.ROLES[row.role].name)+" · "+L.text(Ops.SHIFT_NAMES[row.shift]))
		hud._label(box,L.text("%d / %d eingeplant · %d im Dienst") % [row.planned,row.minimum,row.present],17,hud.TEAL,true)
		_button(box,L.text("%d fehlende Person(en) einstellen · %d €") % [row.missing,row.missing*180],func():return _fill_role(row.role,row.shift),row.missing>0 and model.money>=row.missing*180)
		var details:=_team_details(box,row.key+":"+row.role+":"+row.shift)
		_people(details,row.people,row.key)
		_reserve(details,row.role,row.key,row.shift)
		for person in row.people:shown.append(person.id)
	var others: Array=model.operations.staff.filter(func(p):return p.assignment=="building:%d" % lift_id and not shown.has(p.id))
	if not others.is_empty():_people(_card(parent,L.text("Weitere Zuweisungen")),others,"building:%d" % lift_id)
func _fill_role(role: String, shift: String) -> Dictionary:
	var model: RefCounted=hud.game.model
	for row in Ops.building_team(model,model.asset(lift_id)):
		if row.role!=role or row.shift!=shift:continue
		if model.money<row.missing*180 or model.operations.staff.size()+row.missing>1200:return model._result(false,L.text("Das Budget oder der Personalplatz reicht für dieses Team noch nicht."))
		for i in range(row.missing):Ops.hire(model,role,row.key,shift)
		return model._result(true,L.text("Einsatzort und Schicht aktualisiert."))
	return model._result(false,L.text("Diese Personalzuweisung ist nicht möglich."))
func _people(parent: Node, people: Array, target: String) -> void:
	var model: RefCounted=hud.game.model
	for person in people:
		hud._label(parent,person.name+" · "+L.text(Ops.ROLES[person.role].name),17,hud.TEAL,true)
		hud._label(parent,L.text("Im Dienst") if Ops.on_duty(model,person) else L.text("Außer Dienst / Pause / Abwesenheit"),16,hud.MUTED,true)
		hud._label(parent,L.text("Qualifikation %d · Motivation %.0f %% · Erschöpfung %.0f %% · %.0f Arbeitsminuten · %.0f €/h") % [int(person.get("qualification",1)),float(person.get("motivation",85)),float(person.get("fatigue",0)),float(person.get("worked",0)),float(person.get("wage",0))],14,hud.MUTED,true)
		var labels: Array=[]
		for key in Ops.SHIFTS:labels.append(L.text(Ops.SHIFT_NAMES[key]))
		var shift:=_choice(parent,labels);shift.select(Ops.SHIFTS.keys().find(person.shift))
		shift.item_selected.connect(func(index: int):action(func():return Ops.assign(model,int(person.id),target,Ops.SHIFTS.keys()[index])))
		_button(parent,L.text("In die Reserve versetzen"),func():return Ops.assign(model,int(person.id),"reserve",person.shift))
		_button(parent,L.text("30 Minuten Pause"),func():
			person.break_until=Ops.clock(model)+30;model._duty_cache.clear();model._operational_change()
			return model._result(true,L.text("Pause eingetragen. Eine Vertretung kann im Personalplan zugewiesen werden.")))
		_button(parent,L.text("Mitarbeiter freistellen"),func():return Ops.dismiss(model,int(person.id)))
func _reserve(parent: Node, role: String, target: String, shift: String) -> void:
	var model: RefCounted=hud.game.model
	var people: Array=model.operations.staff.filter(func(p):return p.role==role and p.assignment=="reserve")
	if people.is_empty():return
	hud._label(parent,L.text("Oder vorhandene Reserve einsetzen:"),16,hud.MUTED,true)
	var labels: Array=[]
	for person in people:labels.append(person.name+" · "+L.text(Ops.SHIFT_NAMES[person.shift]))
	var choice:=_choice(parent,labels)
	_button(parent,L.text("Reserve dieser Station zuweisen · kostenlos") if role=="operator" else L.text("Reserve diesem Gebäude zuweisen · kostenlos"),func():return Ops.assign(model,int(people[choice.selected].id),target,shift))
func refresh_status() -> void:
	var model: RefCounted=hud.game.model
	var item: Dictionary=model.asset(lift_id)
	if item.has("bottom"):
		var rows:=Ops.line_station_team(model,item)
		var present:=0;var needed:=0
		for row in rows:
			present+=mini(row.present,row.minimum);needed+=row.minimum
			for card in cards:
				if card.key!=row.key:continue
				card.status.text=L.text("%d / %d im Dienst · %d Personen eingeplant\nTagschicht: %d / %d besetzt") % [row.present,row.minimum,row.people.size(),row.planned,row.minimum]
				card.hire.text=L.text("Tagschicht vollständig besetzt") if row.missing==0 else L.text("%d fehlende Person(en) einstellen · %d €") % [row.missing,row.missing*180]
				card.hire.disabled=row.missing==0 or model.money<row.missing*180
		var parts:=Ops.line_lifts(model,item)
		summary.text=L.text("%s · %d / %d im Dienst · %d / %d Abschnitte in Betrieb") % [L.asset_name(item),present,needed,parts.filter(func(p):return model.lift_open(p)).size(),parts.size()]
	elif Catalog.BUILDINGS.has(item.get("kind","")):
		summary.text=L.asset_name(item)+" · "+(L.text("Betriebsbereit") if Ops.building_open(model,item) else L.text("Geschlossen oder Personal fehlt"))

