extends PanelContainer
const OperatingPages = preload("res://src/ui/operating_pages.gd")
const Ops = preload("res://src/core/operations.gd")
const L = preload("res://src/core/i18n.gd")
const DragScroll = preload("res://src/ui/drag_scroll.gd")
## The resort office is a paused planning space with real simulation actions.

const Progression = preload("res://src/core/progression.gd")
const AchievementBook = preload("res://src/core/achievement_book.gd")
const Sponsorship = preload("res://src/core/sponsorship.gd")
const LoanOptions = preload("res://src/core/loan_options_035.gd")
const StartTiers = preload("res://src/core/start_tiers.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Chart = preload("res://src/ui/finance_chart.gd")
const StatusBanner = preload("res://src/ui/achievement_toast.gd")

var game: Node
var hud: CanvasLayer
var tabs := TabContainer.new()
var title: Label
var guest_button: Button
var compact_layout := false
var feedback: Label
var _feedback := ""
var staff_role := ""
var staff_target := ""
var staff_page := 0
var candidate_page := 0
var selected_achievement_track := 0
var notification_filter := "all"
var _page_bodies: Dictionary={}
var _operating_layout := false
var _page_language := ""
var _building_tabs := false
var _rendering_page := false

func setup(controller: Node, interface: CanvasLayer) -> void:
	game = controller
	hud = interface
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 48
	offset_right = -48
	offset_top = 124
	offset_bottom = -28
	add_theme_stylebox_override("panel", hud._style(Color("fffaf2"), 18, 22))
	var layout: VBoxContainer = hud._vbox(self, 12)
	var header := HBoxContainer.new()
	layout.add_child(header)
	title = hud._label(header, L.text("RESORT-BÜRO"), 27, hud.ACCENT)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guest_button = hud._button(header, L.text("Gäste & Wünsche"), func():
		hide()
		hud.audience.open()
	)
	hud._button(header, L.text("Zurück zum Berg"), hide, true)
	feedback = hud._label(layout, "", 17, hud.TEAL, true)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 19)
	tabs.add_theme_stylebox_override("panel", hud._style(Color("f5f5ed"), 10, 0))
	var tab_bar := tabs.get_tab_bar()
	for control in [tabs, tab_bar]:
		control.add_theme_stylebox_override("tab_selected", hud._style(Color("d3e7dc"), 7, 13))
		control.add_theme_stylebox_override("tab_unselected", hud._style(Color("edf3ec"), 7, 13))
		control.add_theme_stylebox_override("tab_hovered", hud._style(Color("e2eee6"), 7, 13))
		control.add_theme_color_override("font_selected_color", hud.ACCENT)
		control.add_theme_color_override("font_unselected_color", hud.MUTED)
	layout.add_child(tabs)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_apply_responsive_layout(get_viewport().get_visible_rect().size.x)
	tabs.tab_changed.connect(_tab_selected)
	hide()

func _on_viewport_size_changed() -> void:
	if not is_inside_tree(): return
	_apply_responsive_layout(get_viewport().get_visible_rect().size.x)

func _apply_responsive_layout(available_width: float) -> void:
	# A compact office must remain usable with one hand and limited Android
	# safe area. The guest action keeps the same callback in both layouts.
	compact_layout = available_width < 1160.0
	offset_left = 12 if compact_layout else 48
	offset_right = -12 if compact_layout else -48
	offset_top = 104 if compact_layout else 124
	offset_bottom = -12 if compact_layout else -28
	if is_instance_valid(title):
		title.add_theme_font_size_override("font_size", 21 if compact_layout else 27)
	if is_instance_valid(guest_button):
		guest_button.text = L.text("Gäste") if compact_layout else L.text("Gäste & Wünsche")
		guest_button.tooltip_text = L.text("Gäste & Wünsche")

func open() -> void:
	game._clear_input()
	_feedback = ""
	Progression.refresh(game.model)
	_ensure_pages()
	show()
	refresh()

## Page shells are cheap. Building all thirteen panels (including hundreds of
## research/staffing controls) was blocking the Android UI on every opening.
func _ensure_pages() -> void:
	var operating: bool=Ops.active(game.model)
	# Language changes invalidate translated tab keys. Recreate only the
	# inexpensive empty shells, not their expensive research/staff content.
	if not _page_bodies.is_empty() and _operating_layout==operating and _page_language==L.language:return
	var desired: int=clampi(tabs.current_tab,0,12)
	_building_tabs=true
	for child in tabs.get_children():
		tabs.remove_child(child)
		child.queue_free()
	_page_bodies.clear()
	_operating_layout=operating
	_page_language=L.language
	for title_value in ["Karriere","Erfolge","Aufträge","Forschung","Ausbau","Finanzen","Sponsoring"]:
		_page(L.text(title_value))
	if operating:
		for title_value in ["Betrieb","Personal","Bewerbermarkt","Technik & Rettung","Kostenstellen"]:
			_page(L.text(title_value))
	_page(L.text("Meldungen"))
	tabs.current_tab=mini(desired,tabs.get_tab_count()-1)
	_building_tabs=false

func _tab_selected(_index: int) -> void:
	if not _building_tabs:refresh()

func _page(name_value: String) -> VBoxContainer:
	if _page_bodies.has(name_value) and is_instance_valid(_page_bodies[name_value]):
		return _page_bodies[name_value]
	var scroll := DragScroll.new()
	scroll.name = name_value
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 15)
	scroll.add_child(margin)
	var body: VBoxContainer=hud._vbox(margin,14)
	_page_bodies[name_value]=body
	return body

func _card(parent: Node, heading: String, text_value: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", hud._style(Color("edf3ec"), 12, 16))
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

## Only the selected office tab is rebuilt. Open and tab switches do not
## recreate hidden financial, staffing, research and achievement catalogues.
func refresh() -> void:
	if _rendering_page:return
	_ensure_pages()
	var current: int=maxi(0,tabs.current_tab)
	if current>=tabs.get_tab_count():return
	_rendering_page=true
	var state: Dictionary=game.model.campaign
	title.text = L.text("RESORT-BÜRO  ·  %s  ·  %d FP") % L.args(["★".repeat(state.rank), state.points])
	feedback.text = _feedback if _feedback != "" else Progression.notice_text(state)
	var scroll: ScrollContainer=tabs.get_child(current) as ScrollContainer
	var page: VBoxContainer=_page_bodies[str(scroll.name)]
	var old_offset: int=scroll.scroll_vertical
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	match current:
		0: _career(page)
		1: _achievements(page)
		2: _contracts(page)
		3: _research(page)
		4: _upgrades(page)
		5: _finances(page)
		6: _sponsoring(page)
		_:
			if _operating_layout and current>=7 and current<12:
				OperatingPages.add(self,current-7)
			else:
				_notifications(page)
	scroll.set_deferred("scroll_vertical",old_offset)
	_rendering_page=false

## The user's session notification center: safe to open and filter by type.
## Only transient UI history is stored here; financial and mission truth remains
## in the canonical campaign/operations save state.
func _notification_entries(parent: VBoxContainer) -> void:
	var messages: Array=hud.achievement_overlay.history
	var matches := 0
	for event in messages:
		var kind: String=str(event.get("kind",""))
		if notification_filter != "all" and kind != notification_filter and not (notification_filter == "achievement" and kind in ["rank","medal"]): continue
		matches+=1
		var title_text: String=str(event.get("title",""))
		var detail_text: String=str(event.get("detail",""))
		if int(event.get("reward",0))>0: detail_text+=" · +%d €" % int(event.reward)
		var item: VBoxContainer=_card(parent,StatusBanner.caption(kind)+"  ·  "+title_text,detail_text)
		if kind=="music":
			hud._button(item,L.text("Zum Radio"),func(): hide(); hud.jukebox.open())
		elif kind=="mission" or kind=="medal":
			hud._button(item,L.text("Missionsübersicht öffnen"),func(): hud.show_management_page(L.text("Betrieb")))
		elif kind in ["achievement","rank"]:
			hud._button(item,L.text("Zu den Erfolgen"),func(): hud.show_management_page(L.text("Erfolge")))
		elif kind in ["warning","finance"]:
			hud._button(item,L.text("Finanzen prüfen"),func(): hud.show_management_page(L.text("Finanzen")))
	if matches == 0:
		hud._label(parent,L.text("Noch keine Meldungen in dieser Spielsitzung."),17,hud.MUTED,true)

func _notifications(page: VBoxContainer) -> void:
	_card(page,L.text("Deine Resort-Meldungen"),L.text("Songs, Szenariomissionen, Erfolge und wichtige Betriebswarnungen erscheinen im selben transparenten Banner. Hier kannst du die letzten 40 Meldungen dieser Spielsitzung nach Themen sortieren. Die Erfolgs- und Missionsstände selbst bleiben selbstverständlich im Spielstand erhalten."))
	var filters := {"all":"Alle","achievement":"Erfolge & Medaillen","mission":"Missionen","music":"Radio","warning":"Warnungen","finance":"Finanzen","repair":"Reparaturen"}
	var picker := OptionButton.new()
	picker.custom_minimum_size.y=52
	for key in filters:
		picker.add_item(L.text(str(filters[key])))
		picker.set_item_metadata(picker.item_count-1,key)
		if str(key)==notification_filter:picker.select(picker.item_count-1)
	page.add_child(picker)
	var list_box: VBoxContainer=hud._vbox(page,10)
	_notification_entries(list_box)
	picker.item_selected.connect(func(index: int):
		notification_filter=str(picker.get_item_metadata(index))
		for child in list_box.get_children():
			list_box.remove_child(child)
			child.queue_free()
		_notification_entries(list_box)
	)

func _career(page: VBoxContainer) -> void:
	var model: RefCounted = game.model
	var state: Dictionary = model.campaign
	var summary := _card(page, L.text("%s  ·  %s") % L.args(["★".repeat(state.rank), Progression.RANK_NAMES[state.rank - 1]]), L.text("Winter %d · Tag %d von 28\n%.0f Erfahrung · %d abgeschlossene Aufträge · %s € Budget") % L.args([Progression.season_number(model), Progression.season_day(model), state.xp, state.completed, hud.money_text(model.money)]))
	if state.has("starting_tier"):
		var starting: Dictionary = StartTiers.choice(int(state.starting_tier))
		hud._label(summary,L.text("Karriereprofil: ") + L.text(str(starting.name)) + " · " + L.text("Startkapital") + " " + hud.money_text(starting.money) + " €",16,hud.ACCENT,true)
	hud._label(summary, Progression.next_goal(model), 18, hud.TEAL, true)
	if state.rank < 5:
		var bar := ProgressBar.new()
		bar.max_value = Progression.XP_STEPS[state.rank]
		bar.value = minf(state.xp, bar.max_value)
		bar.custom_minimum_size.y = 22
		bar.show_percentage = false
		summary.add_child(bar)
	var mastery: int = int(state.get("mastery_rank",AchievementBook.mastery_for_xp(float(state.xp))))
	var needed: int = AchievementBook.xp_for_rank(mini(500,mastery+1))
	var mastery_card := _card(page,L.text("MEISTERSCHAFT · RANG %d / 500") % L.args(mastery),
		L.text("Resort-Level unabhängig von den fünf Sternen. Erfahrung: %.0f XP · nächster Rang bei %d XP.") % L.args([state.xp,needed]))
	var mastery_progress := ProgressBar.new()
	mastery_progress.min_value = AchievementBook.xp_for_rank(mastery)
	mastery_progress.max_value = maxi(mastery_progress.min_value+1,needed)
	mastery_progress.value = clampf(float(state.xp),mastery_progress.min_value,mastery_progress.max_value)
	mastery_progress.custom_minimum_size.y = 26
	mastery_progress.show_percentage = false
	mastery_card.add_child(mastery_progress)
	var event := Progression.event(model)
	_card(page, L.text("Heute: ") + event.name, event.description)
	if not state.project.is_empty():
		_card(page, L.text("In Arbeit: ") + L.text(Progression.RESEARCH[state.project.id].name), L.text("Fertig an Tag %d. Dein Resort kann während der Forschung normal weiterlaufen.") % L.args(state.project.due_day))
	if Progression.has(model, "meteo"):
		var weather := _card(page, L.text("Wetterplanung"), L.text("Die Vorschau entspricht dem Wetter der nächsten Betriebstage."))
		for offset in range(1, 7):
			var prediction: Dictionary = Catalog.WEATHER[Progression.weather_for_day(model.rng.seed, model.day + offset)]
			hud._label(weather, L.text("Tag %d · %s · %.0f °C · Wind %.0f km/h") % L.args([model.day + offset, prediction.name, prediction.temperature, prediction.wind]), 17)
	else:
		_card(page, L.text("Den nächsten Wintertag vorbereiten"), L.text("Erforsche die Bergwetterstation für eine Wettervorschau. Jeden Tag erscheinen neue Auftragsangebote. Am Ende eines 28-tägigen Winters erhältst du eine Wertung und eine Saisonprämie; dein Resort bleibt bestehen."))
	_card(page, L.text("Karriere und freier Aufbau"), L.text("Karriere: Forschung schaltet neue Technik und Ausbaustufen frei. Im freien Aufbau sind die Anlagen direkt verfügbar; Aufträge, Forschungseffekte und Winterwertung bleiben nutzbar. Im Resort-Büro pausiert die Zeit, damit du in Ruhe planen kannst."))

func _achievements(page: VBoxContainer) -> void:
	# A virtual catalogue: show the chosen theme in detail instead of
	# creating 1,000 UI cards every time the resort office opens.
	var model: RefCounted = game.model
	var earned: Dictionary = {}
	for id in model.achievements: earned[int(id)] = true
	var expanded := 0
	for id in model.achievements:
		if int(id) >= AchievementBook.START_ID: expanded += 1
	_card(page, L.text("1.000 ERFOLGE · %d / 1.000 FREIGESCHALTET") % L.args(expanded),
		L.text("20 Themen mit jeweils 50 echten Zielen. Jeder neue Erfolg bringt eine kleine Bauprämie. Alle Errungenschaften bleiben im Spielstand erhalten."))
	var picker := OptionButton.new()
	picker.custom_minimum_size.y = 52
	for track in AchievementBook.TRACKS:
		picker.add_item(L.text(str(track.name)))
	picker.select(clampi(selected_achievement_track,0,AchievementBook.TRACKS.size()-1))
	page.add_child(picker)
	picker.item_selected.connect(func(index: int):
		selected_achievement_track = index
		refresh()
	)
	var selected: int = clampi(selected_achievement_track,0,AchievementBook.TRACKS.size()-1)
	var current := 0
	for tier in range(1,AchievementBook.TIERS+1):
		var id: int = AchievementBook.START_ID+selected*AchievementBook.TIERS+tier-1
		if earned.has(id): current += 1
	var progress_card := _card(page,L.text("%s · %d / 50") % L.args([L.text(AchievementBook.TRACKS[selected].name),current]),
		L.text("Wähle oben einen Bereich, um alle 50 Meilensteine zu sehen."))
	var bar := ProgressBar.new()
	bar.max_value = AchievementBook.TIERS
	bar.value = current
	bar.custom_minimum_size.y = 22
	progress_card.add_child(bar)
	for tier in range(1,AchievementBook.TIERS+1):
		var id: int = AchievementBook.START_ID+selected*AchievementBook.TIERS+tier-1
		var goal: Dictionary = AchievementBook.entry(id)
		var done: bool = earned.has(id)
		hud._label(page,("%s " % ("✦" if done else "○")) + str(goal.name) +
			"   ·   " + str(goal.goal) + ("  ✓" if done else ""),
			16,hud.TEAL if done else hud.MUTED,true)

func _contracts(page: VBoxContainer) -> void:
	var model: RefCounted = game.model
	var state: Dictionary = model.campaign
	hud._label(page, L.text("Bis zu drei laufende Aufträge. Pro Betriebstag kannst du zwei neue annehmen."), 18, hud.MUTED, true)
	var running := 0
	for contract in state.contracts:
		running += int(contract.status in ["active", "ready"])
	for contract in state.contracts:
		var spec: Dictionary = Progression.CONTRACTS[contract.kind]
		var status: String = {"active": L.text("Läuft"), "ready": L.text("Erfüllt"), "claimed": L.text("Belohnung abgeholt"), "failed": L.text("Frist abgelaufen")}[contract.status]
		var body := _card(page, L.text("%s · %s") % L.args([spec.name, status]), L.text("%s\n%.0f / %d · Frist: Ende Tag %d\nBelohnung: %s € und %d FP") % L.args([spec.text, minf(contract.progress, contract.target), contract.target, contract.deadline, hud.money_text(contract.reward), contract.points]))
		if contract.status in ["active", "ready"]:
			var bar := ProgressBar.new()
			bar.max_value = contract.target
			bar.value = minf(contract.progress, contract.target)
			bar.custom_minimum_size.y = 20
			body.add_child(bar)
			var id: String = contract.id
			_action(body, L.text("Belohnung abholen"), func(): return model.claim_contract(id), contract.status == "ready")
	hud._label(page, L.text("NEUE ANGEBOTE"), 16, hud.ACCENT)
	for offer in state.offers:
		var spec: Dictionary = Progression.CONTRACTS[offer.kind]
		var body := _card(page, spec.name, L.text("%s Ziel: %d.\nFrist: Ende Tag %d · %s € + %d FP") % L.args([spec.text, offer.target, offer.deadline, hud.money_text(offer.reward), offer.points]))
		var id: String = offer.id
		var available: bool = not state.accepted_today.has(id) and state.accepted_today.size() < 2 and running < 3
		_action(body, L.text("Auftrag annehmen") if not state.accepted_today.has(id) else L.text("Bereits angenommen"), func(): return model.accept_contract(id), available)

func _research(page: VBoxContainer) -> void:
	var model: RefCounted = game.model
	var state: Dictionary = model.campaign
	_card(page,L.text("Forschungspunkte: %d  ·  ein Projekt gleichzeitig") % int(state.points),L.text("Entwicklungszweige mit echten Voraussetzungen. Erforschte Projekte aus früheren Versionen bleiben erhalten."))
	for branch in Progression.BRANCHES:
		var progress: Dictionary=Progression.branch_progress(model,str(branch.id))
		var group:=_card(page,str(branch.icon)+"  "+L.text(str(branch.name)),L.text(str(branch.description)))
		var bar:=ProgressBar.new()
		bar.name="research_branch_"+str(branch.id)
		bar.custom_minimum_size.y=20
		bar.min_value=0
		bar.max_value=int(progress.total)
		bar.value=int(progress.done)
		bar.show_percentage=false
		group.add_child(bar)
		hud._label(group,L.text("%d / %d abgeschlossen") % [int(progress.done),int(progress.total)],15,hud.TEAL,true)
		var flow:=HFlowContainer.new()
		flow.add_theme_constant_override("h_separation",10)
		flow.add_theme_constant_override("v_separation",10)
		group.add_child(flow)
		for id_value in branch.nodes:
			var id: String=str(id_value)
			var spec: Dictionary=Progression.RESEARCH[id]
			var done: bool=Progression.has(model,id)
			var active: bool=not state.project.is_empty() and str(state.project.id)==id
			var tile:=_card(flow,("✓ " if done else "◉ " if active else "◇ ")+L.text(str(spec.name)),"")
			tile.custom_minimum_size.x=245
			var need: Array=[]
			for prerequisite in spec.requires:
				need.append(L.text(str(Progression.RESEARCH[prerequisite].name)))
			if not need.is_empty():hud._label(tile,L.text("Benötigt: %s") % ", ".join(need),14,hud.MUTED,true)
			hud._label(tile,L.text("%s € · %d FP · %d Tage") % [hud.money_text(spec.cost),int(spec.points),int(spec.days)],15,hud.TEAL,true)
			hud._label(tile,L.text(str(spec.effect)),14,hud.MUTED,true)
			var check: Dictionary=Progression.research_check(model,id)
			if active:hud._label(tile,L.text("Fertig an Tag %d") % int(state.project.due_day),15,hud.TEAL,true)
			var action:Button=_action(tile,L.text("Abgeschlossen") if done else L.text("In Arbeit") if active else L.text("Forschung starten"),func():return model.start_research(id),check.ok)
			action.name="research_node_"+id

func _upgrades(page: VBoxContainer) -> void:
	var model: RefCounted = game.model
	_card(page, L.text("Dein Bestand kann mitwachsen"), L.text("Pisten-Upgrades verbreitern die Abfahrt und mindern Verschleiß. Lift-Upgrades steigern Kapazität und Tempo. Gebäude-Upgrades verbessern Komfort und Erlöse. Höhere Stufen erhöhen auch Betriebskosten. Bestehende Gäste werden nach dem Ausbau neu geleitet."))
	for collection in [model.pistes, model.lifts, model.buildings]:
		for item in collection:
			var details := ""
			if item.has("bottom"):
				details = L.text("%d Gäste/h · %.0f m Strecke") % L.args([model.lift_capacity(item), item.length])
			elif item.has("difficulty"):
				details = L.text("%.0f %% Zustand · %.0f cm Schnee · %.0f m Strecke") % L.args([item.condition, item.snow, item.length])
			else:
				details = Catalog.BUILDINGS[item.kind].description
			var body := _card(page, L.text("%s · Stufe %d / 3") % L.args([L.verbatim(L.asset_name(item)), item.get("level", 1)]), details)
			var id: int = item.id
			var check: Dictionary = model.upgrade_check(id)
			hud._label(body, check.message, 16, hud.TEAL, true)
			_action(body, L.text("Ausbauen"), func(): return model.upgrade_asset(id), check.ok)

func _sponsoring(page: VBoxContainer) -> void:
	var model: RefCounted = game.model
	var state: Dictionary = model.campaign
	var contract: Dictionary = state.get("sponsor",{})
	_card(page,L.text("PARTNER FÜR DEIN RESORT"),
		L.text("Sponsoren unterstützen den Bau neuer Anlagen mit sieben Tage lang begrenzten Einnahmen. Gute Gästezufriedenheit erhöht die Auszahlung. Nur ein Vertrag gleichzeitig."))
	if not contract.is_empty():
		var spec: Dictionary = Sponsorship.OFFERS.get(str(contract.id),{})
		var label: String = L.text("Aktiv") if Sponsorship.active(state,model.day) else L.text("Abgeschlossen")
		_card(page,L.text("%s · %s") % L.args([L.text(spec.name),label]),
			L.text("Bis Tag %d · bisher %s € erhalten") % L.args([int(contract.end),hud.money_text(float(contract.earned))]))
	hud._label(page,L.text("VERFÜGBARE SPONSOREN"),18,hud.ACCENT)
	for id_value in Sponsorship.OFFERS:
		var id: String = id_value
		var offer: Dictionary = Sponsorship.OFFERS[id]
		var overview := _card(page,L.text(offer.name), L.text(offer.detail) + "\n" +
			L.text("%s €/Tag für %d Tage · ab %d %% Ruf und %d Lift(en)") % L.args([
				hud.money_text(float(offer.daily)),Sponsorship.CONTRACT_DAYS,int(offer.rep),int(offer.lifts)]))
		# Sponsor brand art is a small theme-compatible on-screen emblem,
		# never an externally licensed logo or a claim of real partnership.
		var insignia := PanelContainer.new()
		insignia.custom_minimum_size.y = 42
		insignia.add_theme_stylebox_override("panel",hud._style(Color(str(offer.get("mark_color","486780"))),8,10))
		overview.add_child(insignia)
		hud._label(insignia,str(offer.get("symbol","◆"))+"  "+L.text("ALPINE PARTNERSCHAFT"),17,Color("ffffff"),true)
		if offer.has("business"):
			var business_name: String = str(model.Catalog.BUILDINGS[str(offer.business)].name)
			hud._label(overview,L.text("Fiktiver Markenpartner · benötigt: %s") % L.args(L.text(business_name)),14,hud.MUTED,true)
		var eligibility: Dictionary = Sponsorship.check(model,id)
		_action(overview,L.text("Sponsorvertrag abschließen"),func(): return Sponsorship.sign(model,id),eligibility.ok)
		if not eligibility.ok: hud._label(overview,eligibility.message,14,hud.MUTED,true)

func _credit_confirmation(quote: Dictionary) -> void:
	if not bool(quote.get("ok",false)): return
	var preview := ConfirmationDialog.new()
	preview.title = L.text("Kreditvertrag bestätigen")
	preview.dialog_text = L.text("Dieses fiktive Spielangebot verpflichtet dein Resort zu Raten.\nBetrag: %d € · Laufzeit: %d Tage · Jahreszins: %.2f %%\nGesamtzinsen: %.2f € · Höchste Tagesrate: %.2f €\nDie Auszahlung ist kein Umsatz. Die Raten können dein Konto ins Minus bringen.") % [int(quote.principal),int(quote.days),float(quote.annual_rate)*100.0,float(quote.total_interest),float(quote.max_payment)]
	add_child(preview)
	preview.confirmed.connect(func():
		var model: RefCounted = game.model
		var result: Dictionary = model.take_credit(str(quote.id),int(quote.principal),int(quote.days),str(quote.mode),int(quote.grace))
		hud.toast(str(result.get("message","")))
		preview.queue_free()
		refresh()
	)
	preview.canceled.connect(func(): preview.queue_free())
	var bounds: Vector2 = get_viewport().get_visible_rect().size
	var width: int = mini(680,maxi(200,int(bounds.x)-24))
	preview.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.get_label().custom_minimum_size.x = width-48
	preview.get_label().add_theme_font_size_override("font_size",15)
	preview.get_ok_button().custom_minimum_size.y=48
	preview.get_cancel_button().custom_minimum_size.y=48
	preview.popup_centered(Vector2i(width,mini(360,maxi(180,int(bounds.y)-32))))

func _credit_cards(page: VBoxContainer) -> void:
	var model: RefCounted = game.model
	var state: Dictionary = model.campaign
	var tier: int = clampi(int(state.get("starting_tier",2)),0,4)
	var current: Dictionary = state.get("credit_contract",{})
	if model.loan > 0:
		if not current.is_empty():
			var remain: int = int(current.days)-int(current.paid_days)
			var info: VBoxContainer = _card(page,L.text("Aktiver Resortkredit"),
				L.text("Restschuld %s € · %d Raten noch offen · Zinsen bisher %.2f €") % [hud.money_text(model.loan),remain,float(current.paid_interest)])
			var button: Button = hud._button(info,L.text("Restschuld vollständig vorzeitig tilgen"),func():
				var paid: bool = model.repay_loan()
				hud.toast(L.text("Kredit getilgt.") if paid else L.text("Nicht genügend Geld für Sondertilgung."))
				refresh()
			)
			button.disabled = model.money < float(current.balance)
		else:
			var old := _card(page,L.text("Bestehender Kredit aus einer älteren Spielversion"),
				L.text("Die bisherigen Kreditregeln bleiben erhalten. 450 € pauschale Tageslast; vollständige Tilgung jederzeit möglich."))
			var old_btn: Button = hud._button(old,L.text("Altkredit vollständig tilgen"),func():
				var paid: bool = model.repay_loan()
				hud.toast(L.text("Kredit getilgt.") if paid else L.text("Nicht genügend Geld."))
				refresh()
			)
			old_btn.disabled = model.money < float(model.loan)
		return
	_card(page,L.text("Finanzierung: sechs Kreditmodelle"),
		L.text("Fiktive Spielbank · Kredite sind keine Betriebserlöse. Zinssätze berücksichtigen die gewählte Startstufe; bei fehlender Deckung droht ein negatives Konto. Nach dem Abschluss erscheinen Raten und Restschuld."))
	var free_cash: float = float(model.last_report.get("tickets",0.0)) + float(model.last_report.get("services",0.0)) - float(model.last_report.get("costs",0.0))
	for spec in LoanOptions.FIXED:
		var quote: Dictionary = LoanOptions.offer(str(spec.id),tier)
		if not bool(quote.get("ok",false)): continue
		var card: VBoxContainer = _card(page,L.text(str(quote.name)),
			L.text("%s € · %d Tage · %.2f %% Jahreszins\nGesamtzins %s € · maximal %.2f € pro Tag\n%s") % [hud.money_text(float(quote.principal)),int(quote.days),float(quote.annual_rate)*100.0,hud.money_text(float(quote.total_interest)),float(quote.max_payment),L.text(LoanOptions.risk_hint(quote,free_cash))])
		hud._button(card,L.text("Kreditbedingungen prüfen"),func(q=quote): _credit_confirmation(q))
	var mine: VBoxContainer = _card(page,L.text("Wunschkredit frei kalkulieren"),
		L.text("Betrag, Laufzeit, Rückzahlungsart und maximal 14 Tage Stundung selbst wählen; die Bank kalkuliert den Risikozins."))
	var amount := SpinBox.new()
	amount.min_value = LoanOptions.MIN_PRINCIPAL
	amount.max_value = LoanOptions.MAX_PRINCIPAL
	amount.step = 1000
	amount.value = 100000
	amount.custom_minimum_size.y = 48
	hud._label(mine,L.text("Kreditsumme in €"),16,hud.INK)
	mine.add_child(amount)
	var duration := SpinBox.new()
	duration.min_value=7
	duration.max_value=LoanOptions.MAX_DAYS
	duration.step=7
	duration.value=84
	duration.custom_minimum_size.y=48
	hud._label(mine,L.text("Laufzeit in Betriebstagen"),16,hud.INK)
	mine.add_child(duration)
	var grace := SpinBox.new()
	grace.min_value=0
	grace.max_value=LoanOptions.MAX_GRACE
	grace.step=1
	grace.value=0
	grace.custom_minimum_size.y=48
	hud._label(mine,L.text("Anfängliche Stundung in Tagen"),16,hud.INK)
	mine.add_child(grace)
	var modes := OptionButton.new()
	modes.custom_minimum_size.y = 48
	for mode in LoanOptions.REPAYMENT_MODES: modes.add_item(L.text(str(mode)))
	hud._label(mine,L.text("Rückzahlungsart: Annuität / lineare Tilgung / endfällig"),16,hud.INK)
	mine.add_child(modes)
	hud._button(mine,L.text("Wunschkredit berechnen und prüfen"),func():
		var mode: String = str(LoanOptions.REPAYMENT_MODES[modes.selected])
		var quote: Dictionary = LoanOptions.offer("custom",tier,int(amount.value),int(duration.value),mode,int(grace.value))
		if not bool(quote.get("ok",false)):
			hud.toast(str(quote.get("message","")))
			return
		_credit_confirmation(quote)
	)

func _finances(page: VBoxContainer) -> void:
	var model: RefCounted = game.model
	var state: Dictionary = model.campaign
	_card(page, L.text("Deine wirtschaftliche Entwicklung"), L.text("Budget: %s €\nTicket- und Serviceerlöse insgesamt: %s €\nBetriebliche Überschüsse seit Beginn: %s €\nAktueller Betrieb: ca. %s €/Tag\nKredit: %s €") % L.args([hud.money_text(model.money), hud.money_text(state.turnover), hud.money_text(state.profit), hud.money_text(model.operating_costs()), hud.money_text(model.loan)]))
	_credit_cards(page)
	var graph := _card(page, L.text("Ergebnis nach Investitionen · letzte 28 Betriebstage"), L.text("Grün: positives Ergebnis. Rot: Ausgaben für Betrieb und Investitionen übersteigen Einnahmen und Prämien. Kreditaufnahme und Tilgung sind keine Erlöse oder Betriebskosten."))
	var chart := Chart.new()
	chart.rows = state.history
	graph.add_child(chart)
	for i in range(state.history.size() - 1, -1, -1):
		var row: Dictionary = state.history[i]
		_card(page, L.text("Tag %d · %s € Ergebnis") % L.args([row.day, hud.money_text(row.net)]), L.text("%d Gäste · %d Abfahrten · %.0f %% Zufriedenheit\nErlöse %s € · Betrieb %s € · Investitionen %s € · Prämien %s €") % L.args([row.guests, row.rides, row.satisfaction, hud.money_text(row.income), hud.money_text(row.costs), hud.money_text(row.investments), hud.money_text(row.rewards)]))
