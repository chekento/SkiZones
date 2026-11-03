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
var cards: Array = []
var groups := ["Alle Gebäude","Unterkünfte & Hotels","Verpflegung & Wärme","Service & Anreise","Freizeit & Erholung","Betrieb & Sicherheit"]
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
	var filters := HBoxContainer.new()
	body.add_child(filters)
	for group in groups: category.add_item(L.text(group))
	category.custom_minimum_size=Vector2(255,46)
	filters.add_child(category)
	search.placeholder_text=L.text("Gebäude suchen …")
	search.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	filters.add_child(search)
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
	var row := HBoxContainer.new()
	footer.add_child(row)
	preview.custom_minimum_size=Vector2(115,100)
	row.add_child(preview)
	detail=hud._label(row,"",15,hud.INK,true)
	detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	choose=hud._button(row,L.text("Standort wählen"),_choose,true)
	choose.custom_minimum_size.x=170
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
	var state := str(model.money)+str(model.campaign.research)+selected_kind+str(window.size)
	if state==_state and not force: return
	_state=state
	grid.columns=clampi(floori((window.size.x-38)/255),2,4)
	var query := search.text.strip_edges().to_lower()
	for card in cards:
		var spec: Dictionary=Catalog.BUILDINGS[card.kind]
		var matches: bool=(category.selected==0 or Catalog.building_group(card.kind)==groups[category.selected]) and (query.is_empty() or (L.text(spec.name)+" "+L.text(spec.description)).to_lower().contains(query))
		card.button.visible=matches
		var locked: String=model.build_access_message(card.kind,false)
		card.status.text=locked if locked!="" else L.text("Budget reicht noch nicht") if model.money<spec.cost else L.text(Catalog.building_group(card.kind))
		card.button.add_theme_stylebox_override("normal",hud._style(Color("d6e9dc") if card.kind==selected_kind else Color("fffaf0"),12,8,hud.TEAL if card.kind==selected_kind else Color("d3ded4")))
		card.button.modulate=Color(0.76,0.80,0.80) if locked!="" else Color.WHITE
	var spec: Dictionary=Catalog.BUILDINGS[selected_kind]
	var reason: String=model.build_access_message(selected_kind,false)
	preview.kind=selected_kind
	preview.queue_redraw()
	detail.text=L.text(spec.name)+" · "+hud.money_text(spec.cost)+" €\n"+L.text(spec.description)+(L.text("\nBetrieb: %d €/Tag")%L.args(spec.upkeep))
	if reason!="": detail.text+="\n"+reason
	choose.disabled=reason!="" or model.money<spec.cost or not hud.game.points.is_empty()

func _choose() -> void:
	hud.building_choice.select(Catalog.BUILDINGS.keys().find(selected_kind))
	hud.game.set_tool("building")
	if window.fullscreen: hide()
	else: _refresh(true)

func blocks_map(point: Vector2) -> bool:
	return visible and window.get_global_rect().has_point(point)

func _process(_delta: float) -> void:
	if visible: _refresh()
