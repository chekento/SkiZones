extends RefCounted
## 0.40 operational command center – real numbers, not invented dashboard KPIs.
const L = preload("res://src/core/i18n.gd")
const Pulse = preload("res://src/core/resort_pulse_040.gd")
const ResortMap = preload("res://src/ui/resort_operations_map_040.gd")

static func add(office: Control) -> void:
	var hud: CanvasLayer=office.hud
	var report: Dictionary=Pulse.inspect(office.game.model)
	var page: VBoxContainer=office._page(L.text("Leitstand"))
	var lead: VBoxContainer=office._card(page,L.text("BERGLEITSTAND · LIVE"),L.text("Entscheidungen nach echten Warteschlangen, Gästebedürfnissen und Anlagenzustand – ohne den Spielstand zu verändern."))
	var topline:=HBoxContainer.new()
	topline.add_theme_constant_override("separation",10)
	lead.add_child(topline)
	var lead_text: Label=hud._label(topline,L.text("Wind %.0f km/h · %.0f °C · %d offene Hinweise") % [report.wind,report.temperature,report.alerts.size()],17,hud.TEAL,true)
	lead_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hud._button(topline,L.text("Aktualisieren"),func():office.refresh(),true)

	var tiles:=HFlowContainer.new()
	tiles.add_theme_constant_override("h_separation",12)
	tiles.add_theme_constant_override("v_separation",12)
	page.add_child(tiles)
	_metric(hud,tiles,L.text("Gäste am Berg"),str(report.visitors),L.text("Aktuell anwesend"),hud.TEAL)
	_metric(hud,tiles,L.text("Anstehende Gäste"),str(report.waiting),L.text("Aktuelle Liftwarteschlangen"),Color("c37e45") if report.waiting>0 else hud.TEAL)
	_metric(hud,tiles,L.text("Aktive Lifte"),"%d / %d"%[report.running_lifts,report.total_lifts],L.text("Tatsächlich fahrbereit"),Color("c37e45") if report.faults>0 else hud.TEAL)
	_metric(hud,tiles,L.text("Resort-Ruf"),"%.0f / 100"%report.reputation,L.text("Gespeicherter Rufwert"),hud.TEAL)

	var next: VBoxContainer=office._card(page,L.text("Schnellzugriff"),L.text("Die wichtigsten Bereiche direkt öffnen, ohne lange in Untermenüs zu suchen."))
	var nav:=HFlowContainer.new()
	nav.add_theme_constant_override("h_separation",10)
	nav.add_theme_constant_override("v_separation",8)
	next.add_child(nav)
	for name in ["Betrieb","Personal","Finanzen","Gäste & Wünsche"]:
		var target: String=name
		hud._button(nav,L.text(name),func():
			if target=="Gäste & Wünsche":
				office.hide()
				hud.audience.open()
			else:_jump_to_tab(office,target)
		,true)
	hud._button(nav,L.text("Gebäude planen"),func():
		office.hide()
		hud.building_browser.open()
	)

	var issues: VBoxContainer=office._card(page,L.text("Handlungsbedarf · %d Hinweise")%report.alerts.size(),L.text("Kritische Störungen stehen oben. Berühre einen betroffenen Lift, um seine Stationssteuerung zu öffnen."))
	if report.alerts.is_empty():
		hud._label(issues,L.text("Keine kritischen Engpässe erkannt. Prüfe die Situation nach dem nächsten Betriebstag erneut."),17,hud.TEAL,true)
	for alert in report.alerts.slice(0,8):
		var item:=PanelContainer.new()
		item.add_theme_stylebox_override("panel",hud._style(Color("f3ddcf") if int(alert.severity)==3 else Color("fbefd9") if int(alert.severity)==2 else Color("e3eee8"),12,10))
		issues.add_child(item)
		var row:=HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		item.add_child(row)
		var copy:=VBoxContainer.new()
		copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		hud._label(copy,L.text(str(alert.title)),17,hud.INK,true)
		hud._label(copy,L.text(str(alert.detail)),15,hud.MUTED,true)
		if int(alert.asset)>=0:
			var id: int=int(alert.asset)
			hud._button(row,L.text("Anlage öffnen"),func():
				office.hide()
				hud.lift_staff.open(id)
			,true)
		else:
			hud._button(row,L.text("Zum Betrieb"),func():_jump_to_tab(office,"Betrieb"),true)

	var needs: VBoxContainer=office._card(page,L.text("Gästeversorgung"),L.text("Momentaufnahmen der tatsächlich simulierten Bedürfnisse; ein Gast kann mehrere Bedürfnisse gleichzeitig haben."))
	_meter(hud,needs,L.text("Kälte"),report.cold,report.visitors,Color("4c91af"))
	_meter(hud,needs,L.text("Hunger"),report.hungry,report.visitors,Color("d28e4d"))
	_meter(hud,needs,L.text("Toilettenbedarf"),report.bathroom,report.visitors,Color("8d7dbb"))
	_meter(hud,needs,L.text("Erschöpfung"),report.low_energy,report.visitors,Color("ac6f7e"))

	var map_box: VBoxContainer=office._card(page,L.text("Bergnetz · interaktive Engpasskarte"),L.text("Jeder Punkt gehört zu einem echten Lift. Farbe und Größe zeigen Warteschlangen, Personaldefizite und Störungen. Antippen öffnet die Anlage."))
	var map: Control=ResortMap.new()
	map.setup(office.game.model,report.lifts)
	map_box.add_child(map)
	map.lift_selected.connect(func(id: int):
		office.hide()
		hud.lift_staff.open(id)
	)

	var routes: VBoxContainer=office._card(page,L.text("Liftmonitor · nach Handlungsbedarf sortiert"),L.text("Live-Warteschlangen und Stationsbesetzung. Die Zahlen sind keine geschätzten Prognosen."))
	if report.lifts.is_empty():
		hud._label(routes,L.text("Noch keine Liftanlagen vorhanden."),16,hud.MUTED)
	for lift in report.lifts.slice(0,12):
		var row:=HBoxContainer.new()
		routes.add_child(row)
		var description:=VBoxContainer.new()
		description.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(description)
		hud._label(description,L.text(str(lift.name)),16,hud.INK,true)
		var caption: String=L.text("%d Wartende")%int(lift.queue)
		if int(lift.missing)>0:caption+=" · "+(L.text("%d Personal fehlt")%int(lift.missing))
		if bool(lift.fault):caption+=" · "+L.text("Störung")
		hud._label(description,caption,14,hud.MUTED,true)
		var id: int=int(lift.id)
		hud._button(row,L.text("Details"),func():
			office.hide()
			hud.lift_staff.open(id)
		)
		hud._label(routes,"",4,hud.MUTED)

static func _metric(hud: CanvasLayer, parent: Node, heading: String, value: String, note: String, accent: Color) -> void:
	var panel:=PanelContainer.new()
	panel.custom_minimum_size=Vector2(164,110)
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",hud._style(Color("e8f0e8"),14,13,accent))
	parent.add_child(panel)
	var group:=VBoxContainer.new()
	panel.add_child(group)
	hud._label(group,heading,14,hud.MUTED,true)
	hud._label(group,value,29,accent,true)
	hud._label(group,note,12,hud.MUTED,true)

static func _meter(hud: CanvasLayer, parent: VBoxContainer, caption: String, count: int, total: int, accent: Color) -> void:
	var headline:=HBoxContainer.new()
	parent.add_child(headline)
	var label: Label=hud._label(headline,caption,16,hud.INK)
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hud._label(headline,"%d / %d"%[count,total],15,hud.MUTED)
	var bar:=ProgressBar.new()
	bar.custom_minimum_size.y=15
	bar.show_percentage=false
	bar.max_value=maxi(1,total)
	bar.value=clampi(count,0,maxi(1,total))
	bar.add_theme_stylebox_override("background",hud._style(Color("d7e3df"),8,0))
	bar.add_theme_stylebox_override("fill",hud._style(accent,8,0))
	parent.add_child(bar)

static func _jump_to_tab(office: Control, title: String) -> void:
	var translated: String=L.text(title)
	for index in range(office.tabs.get_tab_count()):
		if office.tabs.get_tab_title(index)==translated:
			office.tabs.current_tab=index
			return
