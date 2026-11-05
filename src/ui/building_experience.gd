extends Control
## Touch-friendly building interiors, pizza workshop and hotel management.
const FloatingFrame = preload("res://src/ui/floating_window.gd")
var window := FloatingFrame.new()
const L = preload("res://src/core/i18n.gd")
const Hospitality = preload("res://src/core/hospitality.gd")
const BuildingOffers = preload("res://src/core/building_offers_035.gd")
const ActivityArt = preload("res://src/ui/building_activity_art.gd")
const Activities = preload("res://src/core/building_activities.gd")
const TicTacToeBoard = preload("res://src/ui/tic_tac_toe_board.gd")
const HotelWorld = preload("res://src/core/hotel_microworld.gd")
const HotelComplex = preload("res://src/core/hotel_complex.gd")
const Newspaper = preload("res://src/core/newspaper.gd")
const TownHall = preload("res://src/core/town_hall.gd")
const NewspaperArt = preload("res://src/ui/newspaper_art.gd")
const AudioDesign = preload("res://src/core/audio_design.gd")
const RadioAdArt = preload("res://src/ui/radio_ad_art.gd")
const VisualStyles = preload("res://src/core/visual_styles.gd")
const HotelStoryArt = preload("res://src/ui/hotel_story_art.gd")
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
	veil.color = Color(0.02, 0.08, 0.12, 0.35)
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(window)
	window.setup(hud,L.text("Dein Betrieb"))
	window.close_requested.connect(close)
	var body: VBoxContainer=window.body
	heading=window.title
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
	# Entering the hotel's management interior activates exclusive lounge radio.
	# The player's normal station and volume preferences remain unchanged.
	if is_instance_valid(hud.game.audio):
		hud.game.audio.set_context_station("hotel_lobby" if Hospitality.lodging(str(building.kind)) else "")
	session.clear()
	_rebuild()
	show()
	window._fit()

func close() -> void:
	if visible: hud.game.paused = was_paused
	if hud != null and hud.game != null and is_instance_valid(hud.game.audio):
		hud.game.audio.set_context_station("")
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
		hud.toast(L.text(str(result.get("message", ""))))
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
	if str(building.kind)=="town_hall":
		_town_hall(building)
		_offers(building)
		_activity(building)
		return
	_offers(building)
	if Hospitality.lodging(str(building.kind)): _hotel(building)
	if building.kind == "pizzeria": _pizza(building)
	if building.kind in ["printing_press","newsstand"]: _newspaper(building)
	_mini_games(building)
	_activity(building)
	var operation := _page(L.text("Betrieb & Team"))
	var balance: Dictionary = model.Ops.business_balance(model, building)
	_card(operation, L.text("Dein Betriebsergebnis"), L.text("Umsatz %s € · Kosten %s € · Ergebnis %s €") % [hud.money_text(balance.sales), hud.money_text(balance.costs), hud.money_text(balance.net)])
	hud._button(operation, L.text("Personal, Status und Reparatur"), func(): close(); hud.lift_staff.open(asset_id), true)
	hud._label(operation, L.text("Minispiele sind freiwillig. Deine Betriebe arbeiten auch ohne manuelle Schichten weiter. Drei belohnte Schichten pro Gebäude und Tag; danach bleibt freies Üben möglich."), 16, hud.MUTED, true)


func _offers(building: Dictionary) -> void:
	# Preview only: no unshipped sale/inventory effect or changes to legacy
	# save data. The player sees genuine name-specific baseline services
	# and transparent future unlocks based on the EXISTING building level.
	var kind: String = str(building.get("kind",""))
	var level: int = int(building.get("level",1))
	var page: VBoxContainer = _page(L.text("Angebote & Ausbau"))
	var offered: Array = BuildingOffers.active(kind,level)
	var pending: Array = BuildingOffers.locked(kind,level)
	_card(page,L.text("Betrieb · Stufe %d") % maxi(1,level),
		L.text("Grundangebote stehen ab dem Bau bereit. Zusätzliche Speisen, Getränke, Kurse und Ausrüstung erscheinen nach einem Gebäudeausbau. Angezeigte Margen sind Kalkulationswerte je Artikel, keine bereits verbuchten Verkaufserlöse."))
	var current: VBoxContainer = _card(page,L.text("Bereits verfügbare Angebote"),
		L.text("%d Angebote und Leistungen für diesen Gebäudetyp.") % offered.size())
	for offer in offered:
		var unit_price: float = float(offer.price)
		var summary: String = L.text("Aktiv · Kategorie: %s") % str(offer.category)
		if unit_price > 0.0:
			summary += "\n" + L.text("Kalkulation je Einheit: %.2f € Verkauf · %.2f € Wareneinsatz · %.2f € Deckungsbeitrag vor Personal und Fixkosten.") % [unit_price,float(offer.cost),BuildingOffers.sale_margin(offer)]
		else:
			summary += "\n" + L.text("Im Grundbetrieb enthalten; Kosten und Kapazität werden weiterhin vom bestehenden Betriebssystem gesteuert.")
		_card(current,L.text(str(offer.name)),summary)
	if not pending.is_empty():
		var future: VBoxContainer = _card(page,L.text("Weitere Freischaltungen"),
			L.text("Geplante zusätzliche Inhalte. Stufen oberhalb der derzeit freigegebenen Gebäude-Upgrades werden erst in späteren Updates tatsächlich freischaltbar."))
		for offer in pending:
			_card(future,L.text(str(offer.name)),L.text("Benötigt Gebäudestufe %d · Kategorie: %s") % [int(offer.level),str(offer.category)])

func _newspaper(building: Dictionary) -> void:
	var model: RefCounted=hud.game.model
	var page: VBoxContainer=_page(L.text("Alpen-ExtraBlatt"))
	var edition: Dictionary=Newspaper.statistics(model)
	var style_name: String=VisualStyles.valid(hud.game.preferences.visual_style)
	var palette: Dictionary=VisualStyles.ui_palette(style_name)
	var accent: Color=Color(str(palette.accent))
	var night: bool=style_name in ["neon_noir","aurora_ink"]
	# The world accent can be pale gold; print ink needs contrast on cream paper.
	if not night: accent=accent.darkened(0.48)
	var ink: Color=Color("e9f7f4") if night else Color("303540")
	var muted: Color=Color("b9d7df") if night else Color("695f56")
	var paper: Color=Color("1d283e") if night else Color("faf2dd")
	var headline_art:=NewspaperArt.new()
	headline_art.setup(style_name,int(edition.issue),str(edition.district))
	page.add_child(headline_art)
	var intro:=PanelContainer.new()
	intro.add_theme_stylebox_override("panel",hud._style(paper,3,16,accent))
	page.add_child(intro)
	var inside: VBoxContainer=hud._vbox(intro,7)
	hud._label(inside,L.text("SONDERAUSGABE · NACHRICHTEN VOM BERG"),12,accent,true)
	hud._label(inside,L.text("Betriebstag %d · %d verkaufte Zeitungen · %s € Kioskerlös") % [int(edition.issue),int(edition.sold),hud.money_text(float(edition.revenue))],15,ink,true)
	hud._label(inside,L.text("Aus den echten Erfolgen und Betriebszahlen deines Skigebiets gesetzt. Die Redaktion erfindet keine Spielstände oder Verkaufsergebnisse."),14,muted,true)
	if not Newspaper.press_available(model):
		_card(page,L.text("Dorfredaktion noch geschlossen"),L.text("Mit einer eigenen Druckerei wird aus den erreichten Meilensteinen die nächste Ausgabe gedruckt."))
		return
	if building.kind=="newsstand":
		_card(page,L.text("Zeitungskiosk · Einzelverkauf"),L.text("%d Zeitungen verkauft · %.0f € tatsächlicher Umsatz") % [int(building.get("visits",0)),float(building.get("revenue",0.0))])
	var articles: Array=edition.edition
	var front:=PanelContainer.new()
	front.add_theme_stylebox_override("panel",hud._style(paper,3,14,accent))
	page.add_child(front)
	var columns:=GridContainer.new()
	columns.columns=2 if get_viewport_rect().size.x >= 990.0 else 1
	columns.add_theme_constant_override("h_separation",14)
	columns.add_theme_constant_override("v_separation",10)
	front.add_child(columns)
	if articles.is_empty():
		var note: VBoxContainer=hud._vbox(columns,9)
		hud._label(note,L.text("NOCH KEIN GROSSES TITELTHEMA"),19,accent,true)
		hud._label(note,L.text("Deine ersten Erfolge, Rennsiege und Meilensteine schreiben die nächste Ausgabe."),15,ink,true)
	for article in articles:
		var column:=PanelContainer.new()
		column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		column.add_theme_stylebox_override("panel",hud._style(paper,1,13,muted))
		columns.add_child(column)
		var content: VBoxContainer=hud._vbox(column,7)
		hud._label(content,L.text(str(article.rubric))+" · "+L.text(str(article.lead)),12,accent,true)
		hud._label(content,L.text(str(article.title)),25,ink,true)
		var divide:=ColorRect.new()
		divide.color=accent
		divide.custom_minimum_size.y=2
		divide.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.add_child(divide)
		hud._label(content,L.text(str(article.detail)),17,ink,true)
		hud._label(content,L.text("%s · %d Abfahrten · %d Gäste insgesamt") % [L.text(str(edition.district)),int(model.total_rides),int(model.total_guests)],13,muted,true)
		hud._label(content,L.text("Die Redaktion · Tag %d") % int(model.day)+" · #"+str(article.id),12,muted,true)
	hud._label(page,L.text("ANZEIGENTEIL · ALPINE RADIO"),19,accent,true)
	hud._label(page,L.text("Unsere Sender für Piste, Hütte, Hotellobby, Snowpark und lange Winterabende. Jede Ausgabe setzt andere Programmtipps."),14,hud.MUTED,true)
	var ads:=GridContainer.new()
	ads.columns=2 if get_viewport_rect().size.x >= 990.0 else 1
	ads.add_theme_constant_override("h_separation",12)
	ads.add_theme_constant_override("v_separation",12)
	page.add_child(ads)
	for advert in edition.ads:
		var panel:=PanelContainer.new()
		panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel",hud._style(paper,2,12,accent))
		ads.add_child(panel)
		var block: VBoxContainer=hud._vbox(panel,5)
		var art:=RadioAdArt.new()
		block.add_child(art)
		art.set_station(str(advert.id),style_name)
		hud._label(block,L.text(str(advert.name)).to_upper(),17,ink,true)
		hud._label(block,L.text(str(advert.copy)),14,muted,true)
		var condition:=L.text("Externes Künstleralbum · SoundCloud nur auf Klick") if bool(advert.external) else L.text("Exklusiv in der Hotelverwaltung") if bool(advert.exclusive) else L.text("Offline-Radio · CC0-Quellennachweise im Impressum")
		hud._label(block,condition,12,accent,true)
		hud._button(block,L.text("Sender im Radio ansehen"),_open_radio_ad.bind(str(advert.id)))


func _open_radio_ad(station_id: String) -> void:
	close()
	hud.jukebox.open()
	var index: int = AudioDesign.GENRES.find(station_id)
	if index >= 0:
		hud.jukebox.genre_choice.select(index)
		hud.jukebox.genre_choice.item_selected.emit(index)

func _town_hall(_building: Dictionary) -> void:
	var style_name: String=VisualStyles.valid(hud.game.preferences.visual_style)
	var colors: Dictionary=VisualStyles.ui_palette(style_name)
	var accent: Color=Color(str(colors.accent))
	var dark: bool=style_name in ["neon_noir","aurora_ink"]
	var paper: Color=Color("182b3b") if dark else Color("fbf2dc")
	var ink: Color=Color("e9f4f1") if dark else Color("344453")
	var archive: VBoxContainer=_page(L.text("Rathaus · Stadtchronik"))
	hud._label(archive,L.text("DAS BUCH DER WINTER"),28,accent,true)
	hud._label(archive,L.text("Hier spricht das Rathaus: Unser Dorf führt Buch darüber, wie es von der ersten Android-Bergwelt zum lebendigen Skiresort gewachsen ist."),16,ink,true)
	var museum:=PanelContainer.new()
	museum.add_theme_stylebox_override("panel",hud._style(paper,5,13,accent))
	archive.add_child(museum)
	var mu: VBoxContainer=hud._vbox(museum,6)
	hud._label(mu,L.text("BEGLAUBIGTES ARCHIV"),14,accent,true)
	hud._label(mu,L.text("Ausgewählte veröffentlichte Etappen bis 0.32.0 · älteste zuerst; die aktuelle APK steht bei GitHub."),14,ink,true)
	hud._label(mu,L.text(TownHall.DEVELOPMENT_NOTICE),13,ink,true)
	for event in TownHall.history(false):
		var row:=PanelContainer.new()
		row.add_theme_stylebox_override("panel",hud._style(paper,1,11,accent))
		archive.add_child(row)
		var inner: VBoxContainer=hud._vbox(row,5)
		hud._label(inner,L.text("RATHAUSAKTE · VERSION %s · %s") % [str(event.version),str(event.date)],12,accent,true)
		hud._label(inner,L.text(str(event.topic)),18,ink,true)
		hud._label(inner,L.text(str(event.story)),15,ink,true)
	var plans: VBoxContainer=_page(L.text("Rathaus · Bauplan bis Januar"))
	hud._label(plans,L.text("ZWEI MONATE ZUKUNFT · NOVEMBER BIS JANUAR"),22,accent,true)
	hud._label(plans,L.text("Planungsstand 04.11.2026 · Ziele sind keine Zusagen oder veröffentlichten Funktionen. Jede Phase erhält eigene Freigabetests."),15,ink,true)
	for phase in TownHall.roadmap():
		var chapter:=PanelContainer.new()
		chapter.add_theme_stylebox_override("panel",hud._style(paper,4,15,accent))
		plans.add_child(chapter)
		var details: VBoxContainer=hud._vbox(chapter,8)
		hud._label(details,str(phase.phase),22,accent,true)
		hud._label(details,L.text("%s bis %s") % [str(phase["from"]),str(phase["to"])],14,ink,true)
		hud._label(details,L.text("Release-Ziel: %s · %s") % [L.text(str(phase.target)),L.text(str(phase.status))],14,ink,true)
		for entry in phase.deliverables:
			hud._label(details,"• "+L.text(str(entry)),15,ink,true)
		hud._label(details,L.text("Abnahmekriterium: ")+L.text(str(phase.acceptance)),13,accent,true)
	hud._button(plans,L.text("Ausführlichen Zwei-Monats-Plan auf GitHub öffnen"),func(): OS.shell_open("https://github.com/chekento/SkiZones/blob/main/docs/ROADMAP_2026_11_2027_01.md"))
	var bulletin: VBoxContainer=_page(L.text("Rathaus · Bürgerinformation"))
	hud._label(bulletin,L.text("STADTANZEIGER UND BÜRGERSERVICE"),22,accent,true)
	hud._label(bulletin,L.text("Unsere Bauakten werden lokal aus dem Spiel gelesen; sie brauchen keinen GitHub-Login, keine Netzwerkverbindung und verändern keine bestehenden Spielstände."),15,ink,true)
	hud._button(bulletin,L.text("Offizielles GitHub-Changelog öffnen"),func(): OS.shell_open("https://github.com/chekento/SkiZones/blob/main/CHANGELOG.md"))
	hud._button(bulletin,L.text("Veröffentlichte APKs auf GitHub ansehen"),func(): OS.shell_open("https://github.com/chekento/SkiZones/releases"))
	hud._label(bulletin,L.text("Als Nächstes: stabile Android-APK und sichere Spielstände, weniger Dauersturm, ruhiger Nacht-Zeitraffer, echte Touch-Minispiele, verlässliche Szenarien und ein erwachsenes Alpine-Resort-Design."),15,ink,true)

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
	hud._label(page,L.text("HOTEL LOBBY FM · Lounge-Musik während der Hotelverwaltung"),16,hud.TEAL,true)
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
	var module_page := _page(L.text("Hotelkomplex & Module"))
	var modules: Array = HotelComplex.ordered(model.buildings,int(building.id))
	var overview := _card(module_page,L.text("Deine Hotelzeile"),L.text("Erweitere dein Hotel von links nach rechts. Bestehende, benachbarte Dorfgebäude können als eigenständig wirtschaftende Module an das Kettenende andocken."))
	var drawing := HBoxContainer.new()
	var strip := ScrollContainer.new()
	strip.custom_minimum_size.y=118
	strip.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	overview.add_child(strip)
	strip.add_child(drawing)
	hud._label(drawing,L.asset_name(building),18,hud.TEAL,true)
	for module in modules:
		hud._label(drawing," → "+L.asset_name(module),17,hud.INK,true)
	var summary := _card(module_page,L.text("Verbunden: %d / %d Module") % [modules.size(),HotelComplex.MAX_MODULES],L.text("Jeder Betrieb behält Personal, Umsatz und eigene Serviceaktivitäten. Die Verbindung kostet 4.500 €; die Gebäude werden nicht teleportiert."))
	if not modules.is_empty():
		var last: Dictionary = modules.back()
		var last_id: int=int(last.id)
		_action(summary,L.text("Letztes Modul lösen · %s") % L.args(L.asset_name(last)),func(): return HotelComplex.detach(model,int(building.id),last_id))
	var candidates := 0
	for other in model.buildings:
		var module_id: int=int(other.id)
		var check: Dictionary=HotelComplex.check(model,int(building.id),module_id)
		if not check.ok: continue
		candidates+=1
		_action(module_page,L.text("%s als nächstes Modul andocken · 4.500 €") % L.args(L.asset_name(other)),func(): return HotelComplex.attach(model,int(building.id),module_id))
	if candidates==0:
		hud._label(module_page,L.text("Noch kein freier Nachbarbau am Kettenende. Baue im Dorfkatalog einen Pool, Spa, Fitnessraum, Restaurant oder ein Handwerksgeschäft in direkter Nähe."),16,hud.MUTED,true)

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

func _mini_games(building: Dictionary) -> void:
	# Unlike the sector training shifts, the arcade contains genuine playable
	# local games. It does not pay cash and cannot alter operating balances.
	var kind: String = str(building.kind)
	if kind not in ["lodge","bar","disco"] and not Hospitality.lodging(kind): return
	var page: VBoxContainer = _page(L.text("Spielecke"))
	var requirement: int = 2 if kind=="disco" or Hospitality.lodging(kind) else 1
	var rank: int = int(hud.game.model.campaign.get("rank",1))
	if rank < requirement:
		_card(page,L.text("Noch gesperrt"),L.text("Wird ab Betreiber-Rang %d freigeschaltet.") % requirement)
		return
	var board := TicTacToeBoard.new()
	board.style_id = str(hud.game.preferences.visual_style)
	page.add_child(board)
	hud._label(page,L.text("Echtes Brettspiel gegen den Computer. Ohne Einsatz, Geldprämien oder Zeitdruck."),15,hud.MUTED,true)

func _activity(building: Dictionary) -> void:
	var page := _page(L.text("Betriebstraining"))
	var definition := Activities.spec(str(building.kind))
	if definition.is_empty(): return
	game_box = _card(page, L.text("Deine Hotelgeschichte") if Hospitality.lodging(str(building.kind)) else L.text(definition.title), L.text("Fünf bebilderte Kapitel mit unterschiedlichen Gästewünschen und Entscheidungen.") if Hospitality.lodging(str(building.kind)) else L.text(definition.hint))
	if Hospitality.lodging(str(building.kind)):
		var progress: Dictionary = HotelWorld.chapter_progress(building)
		hud._label(game_box,L.text("Hotel-Level %d / 20 · %d Geschichten · beste Schicht %d Punkte") % [int(progress.level),int(progress.visits),int(progress.best)],18,hud.TEAL,true)
		hud._label(game_box,L.text("Dein Haus, seine Zimmerbelegung und das gewählte Frühstück beeinflussen die Geschichten. Die echten Zimmer werden hier nicht doppelt gebucht."),16,hud.MUTED,true)
	hud._label(game_box, L.text("Die Resortzeit pausiert während deines Gebäudebesuchs."), 16, hud.MUTED, true)
	hud._button(game_box, L.text("Hotelgeschichte starten · fünf Kapitel") if Hospitality.lodging(str(building.kind)) else L.text("Schicht starten · fünf Aufgaben"), _start_shift, true)

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
	if task.mode == "decision":
		hud._label(game_box,L.text("BETRIEBSSIMULATION · ") + L.text(str(task.get("metric","Entscheidungsqualität"))),16,hud.TEAL,true)
		hud._label(game_box,L.text(str(task.get("context",""))),16,hud.MUTED,true)
	hud._label(game_box, L.text(str(task.prompt)), 24 if task.mode in ["hotel_story","decision"] else 32, hud.INK, true)
	if task.mode == "hotel_story":
		hud._label(game_box,L.text(str(task.title)),22,hud.TEAL,true)
		var story_art := HotelStoryArt.new()
		story_art.scene_id = str(task.scene)
		story_art.style_id = hud.game.preferences.visual_style
		story_art.custom_minimum_size = Vector2(0,240)
		game_box.add_child(story_art)
		hud._label(game_box, L.text(str(task.guest)) + " · " + L.text(str(task.intro)), 18, hud.TEAL, true)
		hud._label(game_box, L.text(str(task.wish)), 16, hud.MUTED, true)
		for choice_index in range(task.choices.size()):
			var chosen: int = choice_index
			hud._button(game_box,L.text(str(task.choices[choice_index])),func(): _submit(chosen),true)
		status = hud._label(game_box,L.text("Punkte bisher: %d") % int(session.score),18,hud.MUTED)
		return
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
		if Hospitality.lodging(str(hud.game.model.asset(asset_id).get("kind",""))):
			var progress: Dictionary = HotelWorld.chapter_progress(hud.game.model.asset(asset_id))
			hud._label(game_box,L.text("Hotelgeschichte Level %d · %d Erfahrung · beste Runde %d Punkte") % [int(progress.level),int(progress.xp),int(progress.best)],20,hud.TEAL,true)
		hud._button(game_box, L.text("Noch eine Runde"), _start_shift, true)
	else:
		if task.get("mode","") == "decision":
			hud.toast(L.text("Betriebsentscheidung · %d / 100 · %s") % [int(result.get("score",0)),L.text(str(task.get("metric","Service")))])
		_next_task()

func _process(delta: float) -> void:
	if not visible or not is_instance_valid(meter) or task.get("mode", "") != "timing": return
	elapsed += delta
	cursor = (sin(elapsed * 1.9 - PI * 0.5) + 1.0) * 0.5
	artwork.cursor = cursor
	meter.value = cursor * 100.0
	meter.modulate = Color("66b395") if absf(cursor - float(task.target)) <= 0.1 else Color("d6aa70")


