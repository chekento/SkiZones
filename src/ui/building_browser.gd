extends Control
const L = preload("res://src/core/i18n.gd")
const Catalog = preload("res://src/core/catalog.gd")
const FloatingFrame = preload("res://src/ui/floating_window.gd")
const Icon = preload("res://src/ui/building_icon.gd")
const DragScroll = preload("res://src/ui/drag_scroll.gd")
var hud: CanvasLayer
var window := FloatingFrame.new()
var search := LineEdit.new()
var category := OptionButton.new()
var grid := GridContainer.new()
var filters := GridContainer.new()
var sort_choice := OptionButton.new()
var ready_only := CheckButton.new()
var cards: Array = []
var groups := ["Alle Gebäude","Unterkünfte & Hotels","Verpflegung & Wärme","Sanitär & Infrastruktur","Service & Anreise","Freizeit & Erholung","Betrieb & Sicherheit"]
var selected_kind := "cabin"
var preview := Icon.new()
var detail: Label
var choose: Button
var _state := ""

func setup(owner_hud: CanvasLayer) -> void:
	hud=owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(window)
	window.setup(hud,L.text("Dein Dorf · Gebäudekatalog"))
	window.close_requested.connect(hide)
	var body: VBoxContainer=window.body
	hud._label(body,L.text("Gebäude entdecken, vergleichen und direkt am Berg platzieren. Fenster am Titel ziehen; unten rechts die Größe ändern."),15,hud.MUTED,true)
	filters.columns=2
	filters.add_theme_constant_override("h_separation",10)
	filters.add_theme_constant_override("v_separation",8)
	body.add_child(filters)
	for group in groups: category.add_item(L.text(group))
	category.custom_minimum_size=Vector2(0,46)
	category.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	filters.add_child(category)
	search.placeholder_text=L.text("Gebäude suchen …")
	search.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	filters.add_child(search)
	sort_choice.custom_minimum_size.y=46
	for label in ["Preis: günstig zuerst","Preis: teuer zuerst","Betriebskosten: günstig zuerst","Gebäude: A–Z"]:
		sort_choice.add_item(L.text(label))
	sort_choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	filters.add_child(sort_choice)
	ready_only.text=L.text("Nur jetzt baubare Gebäude")
	ready_only.custom_minimum_size.y=46
	filters.add_child(ready_only)
	sort_choice.item_selected.connect(func(_index: int):_refresh(true))
	ready_only.toggled.connect(func(_value: bool):_refresh(true))
	category.item_selected.connect(func(_index: int): _refresh(true))
	search.text_changed.connect(func(_text: String): _refresh(true))
	var scroll := DragScroll.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	grid.columns=3
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	scroll.add_child(grid)
	for kind in Catalog.building_order():
		var spec: Dictionary=Catalog.BUILDINGS[kind]
		var button := Button.new()
		button.custom_minimum_size=Vector2(220,158)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		grid.add_child(button)
		var content := VBoxContainer.new()
		button.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left=12
		content.offset_right=-12
		content.offset_top=8
		content.offset_bottom=-8
		content.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.mouse_filter=Control.MOUSE_FILTER_IGNORE
		content.add_child(row)
		var icon := Icon.new()
		icon.kind=kind
		icon.custom_minimum_size=Vector2(88,72)
		row.add_child(icon)
		var title: Label=hud._label(row,L.text(spec.name),17,hud.INK,true)
		title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		title.mouse_filter=Control.MOUSE_FILTER_IGNORE
		hud._label(content,L.text("%s € · %d €/Tag")%L.args([hud.money_text(spec.cost),spec.upkeep]),15,hud.TEAL).mouse_filter=Control.MOUSE_FILTER_IGNORE
		var status: Label=hud._label(content,"",13,hud.MUTED,true)
		status.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.pressed.connect(func():
			if not DragScroll.click_allowed(): return
			selected_kind=kind
			_refresh(true)
		)
		cards.append({"kind":kind,"button":button,"status":status})
	var footer := PanelContainer.new()
	footer.add_theme_stylebox_override("panel",hud._style(Color("e2eadf"),12,12))
	body.add_child(footer)
	var footer_body := VBoxContainer.new()
	footer_body.add_theme_constant_override("separation",8)
	footer.add_child(footer_body)
	var row := HBoxContainer.new()
	footer_body.add_child(row)
	preview.custom_minimum_size=Vector2(84,84)
	row.add_child(preview)
	detail=hud._label(row,"",15,hud.INK,true)
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	choose=hud._button(footer_body,L.text("Standort wählen"),_choose,true)
	choose.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hide()

func open() -> void:
	if not hud.game.points.is_empty():
		hud.toast(L.text("Zuerst die laufende Planung abschließen oder abbrechen."))
		return
	hud.game._clear_input()
	show()
	window._fit()
	_refresh(true)

func _refresh(force: bool = false) -> void:
	var model: RefCounted=hud.game.model
	var state := str(model.money)+str(model.campaign.research)+selected_kind+str(window.size)+str(hud.game.view.visual_style)+search.text+str(category.selected)+str(sort_choice.selected)+str(ready_only.button_pressed)
	if state==_state and not force: return
	_state=state
	filters.columns=1 if window.size.x<620 else 2
	grid.columns=clampi(floori((window.size.x-54)/235),1,4)
	cards.sort_custom(_comes_before)
	for i in range(cards.size()):grid.move_child(cards[i].button,i)
	var first_visible: String=""
	var selection_visible:=false
	var query := search.text.strip_edges().to_lower()
	for card in cards:
		var spec: Dictionary=Catalog.BUILDINGS[card.kind]
		var locked: String=model.build_access_message(card.kind,false)
		var matches: bool=(category.selected==0 or Catalog.building_group(card.kind)==groups[category.selected]) and (query.is_empty() or (L.text(spec.name)+" "+L.text(spec.description)).to_lower().contains(query))
		matches=matches and (not ready_only.button_pressed or (locked=="" and model.money>=spec.cost))
		card.button.visible=matches
		if matches:
			if first_visible=="": first_visible=card.kind
			if selected_kind==card.kind:selection_visible=true
		card.status.text=locked if locked!="" else L.text("Budget reicht noch nicht") if model.money<spec.cost else L.text(Catalog.building_group(card.kind))
		card.button.add_theme_stylebox_override("normal",hud._style(Color("d6e9dc") if card.kind==selected_kind else Color("fffaf0"),12,8,hud.TEAL if card.kind==selected_kind else Color("d3ded4")))
		card.button.modulate=Color(0.76,0.80,0.80) if locked!="" else Color.WHITE
	if not selection_visible and first_visible!="":selected_kind=first_visible
	for card in cards:
		card.button.add_theme_stylebox_override("normal",hud._style(Color("d6e9dc") if card.kind==selected_kind else Color("fffaf0"),12,8,hud.TEAL if card.kind==selected_kind else Color("d3ded4")))
	var spec: Dictionary=Catalog.BUILDINGS[selected_kind]
	var reason: String=model.build_access_message(selected_kind,false)
	preview.kind=selected_kind
	preview.queue_redraw()
	detail.text=L.text(spec.name)+" · "+hud.money_text(spec.cost)+" €\n"+L.text(spec.description)+(L.text("\nBetrieb: %d €/Tag")%L.args(spec.upkeep))
	if reason!="": detail.text+="\n"+reason
	choose.disabled=reason!="" or model.money<spec.cost or not hud.game.points.is_empty()

func _comes_before(a: Dictionary, b: Dictionary) -> bool:
	var first: Dictionary=Catalog.BUILDINGS[a.kind]
	var second: Dictionary=Catalog.BUILDINGS[b.kind]
	match sort_choice.selected:
		1:
			if first.cost!=second.cost:return first.cost>second.cost
		2:
			if first.upkeep!=second.upkeep:return first.upkeep<second.upkeep
		3:
			return L.text(str(first.name)).naturalnocasecmp_to(L.text(str(second.name)))<0
	return first.cost<second.cost if first.cost!=second.cost else str(a.kind)<str(b.kind)

func _choose() -> void:
	hud.building_choice.select(Catalog.BUILDINGS.keys().find(selected_kind))
	hud.game.set_tool("building")
	if window.fullscreen: hide()
	else: _refresh(true)

func blocks_map(point: Vector2) -> bool:
	return visible and window.get_global_rect().has_point(point)

func _process(_delta: float) -> void:
	if visible: _refresh()

