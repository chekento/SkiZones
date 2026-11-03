extends Control
const L = preload("res://src/core/i18n.gd")
const Features = preload("res://src/core/piste_features.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const FloatingFrame = preload("res://src/ui/floating_window.gd")
const DragScroll = preload("res://src/ui/drag_scroll.gd")
var hud: CanvasLayer
var window := FloatingFrame.new()
var asset_id := -1
var selected_index := -1
var kind := OptionButton.new()
var position_slider := HSlider.new()
var lateral_slider := HSlider.new()
var position_label: Label
var lateral_label: Label
var status: Label
var list: VBoxContainer
var install_button: Button
var diagram := Control.new()

func setup(owner_hud: CanvasLayer) -> void:
	hud=owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(window)
	window.setup(hud,L.text("Pistenwerkstatt · Rampen & Rails"))
	window.close_requested.connect(close)
	var body: VBoxContainer=window.body
	hud._label(body,L.text("Gestalte einzelne Abschnitte deiner Piste. Anfänger fahren auf einer freien Linie vorbei; geübte Gäste nutzen passende Module auf ihrer Fahrspur."),16,hud.MUTED,true)
	var scroll := DragScroll.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var content: VBoxContainer=hud._vbox(scroll,12)
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	diagram.custom_minimum_size.y=110
	content.add_child(diagram)
	diagram.draw.connect(_draw_plan)
	for index in range(Features.KINDS.size()): kind.add_item(L.text(Features.NAMES[index])+" · "+str(Features.COSTS[index])+" €")
	kind.custom_minimum_size.y=48
	content.add_child(kind)
	position_label=hud._label(content,"",17)
	position_slider.min_value=0
	position_slider.max_value=100
	position_slider.step=0.5
	position_slider.value=50
	position_slider.custom_minimum_size.y=48
	content.add_child(position_slider)
	lateral_label=hud._label(content,"",17)
	lateral_slider.step=0.25
	lateral_slider.custom_minimum_size.y=48
	content.add_child(lateral_slider)
	status=hud._label(content,"",16,hud.MUTED,true)
	var row := HBoxContainer.new()
	content.add_child(row)
	install_button=hud._button(row,L.text("Modul einbauen"),_install,true)
	hud._button(row,L.text("Neues Modul"),func(): selected_index=-1; _refresh())
	hud._label(content,L.text("Eingebaute Module · antippen zum Verschieben"),19,hud.TEAL)
	list=hud._vbox(content,8)
	for slider in [position_slider,lateral_slider]: slider.value_changed.connect(func(_value: float): _refresh())
	kind.item_selected.connect(func(_index: int): _refresh())
	hud._label(body,L.text("18 m Abstand zu den Enden, 16 m zwischen Modulen. Versetzen kostet 120 €; Entfernen ist kostenlos und erstattet keine Baukosten."),14,hud.MUTED,true)
	hide()

func open(id: int) -> void:
	if not hud.game.points.is_empty():
		hud.toast(L.text("Zuerst die laufende Planung abschließen oder abbrechen."))
		return
	asset_id=id
	selected_index=-1
	hud.game._clear_input()
	show()
	window._fit()
	_refresh()
	_rebuild_list()

func close() -> void:
	hide()
	hud.game.view.preview([],Color.WHITE)
	hud.refresh()

func _refresh() -> void:
	if asset_id<0: return
	var piste: Dictionary=hud.game.model.asset(asset_id)
	if piste.is_empty(): close(); return
	var margin: float=Snow.piste_width(piste)*0.5-3.5
	lateral_slider.min_value=-margin
	lateral_slider.max_value=margin
	position_label.text=L.text("Abschnitt: %.1f %% · %.0f m ab Pistenanfang")%L.args([position_slider.value,piste.length*position_slider.value/100])
	lateral_label.text=L.text("Seitlicher Abstand zur Mitte: %+.2f m")%L.args(lateral_slider.value)
	var result: Dictionary=Features.check(hud.game.model,asset_id,Features.KINDS[kind.selected],position_slider.value/100,lateral_slider.value,selected_index)
	status.text=result.message
	install_button.disabled=not result.ok
	install_button.text=(L.text("Modul versetzen") if selected_index>=0 else L.text("Modul einbauen"))+" · "+str(result.get("cost",0))+" €"
	diagram.queue_redraw()
	var at: Vector2=hud.game.model.terrain.point_on_path(piste.points,position_slider.value/100)
	var direction: Vector2=(hud.game.model.terrain.point_on_path(piste.points,minf(1,position_slider.value/100+0.01))-hud.game.model.terrain.point_on_path(piste.points,maxf(0,position_slider.value/100-0.01))).normalized()
	var point := at+direction.orthogonal()*lateral_slider.value
	hud.game.view.preview([[point.x,point.y]],Color("d3a16c"))

func _install() -> void:
	var result: Dictionary=Features.install(hud.game.model,asset_id,Features.KINDS[kind.selected],position_slider.value/100,lateral_slider.value,selected_index)
	hud.toast(result.message)
	if result.ok:
		selected_index=-1
		hud.game.view.rebuild()
		_rebuild_list()
	_refresh()

func _rebuild_list() -> void:
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	var piste: Dictionary=hud.game.model.asset(asset_id)
	var features: Array=piste.get("features",[])
	if features.is_empty(): hud._label(list,L.text("Diese Piste hat noch keine Module."),16,hud.MUTED)
	for index in range(features.size()):
		var feature: Dictionary=features[index]
		var row := HBoxContainer.new()
		list.add_child(row)
		var select: Button=hud._button(row,L.text(Features.NAMES[Features.KINDS.find(feature.kind)])+" · %.1f %% · %+.1f m"%[feature.fraction*100,feature.lateral],func():
			selected_index=index
			kind.select(Features.KINDS.find(feature.kind))
			position_slider.set_value_no_signal(feature.fraction*100)
			lateral_slider.set_value_no_signal(feature.lateral)
			_refresh()
		)
		select.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		hud._button(row,L.text("Entfernen"),func():
			var result: Dictionary=Features.remove(hud.game.model,asset_id,index)
			hud.toast(result.message)
			selected_index=-1
			hud.game.view.rebuild()
			_rebuild_list()
			_refresh()
		)

func _draw_plan() -> void:
	if asset_id<0: return
	var piste: Dictionary=hud.game.model.asset(asset_id)
	var rect := Rect2(20,14,maxf(80,diagram.size.x-40),78)
	diagram.draw_style_box(hud._style(Color("d4e4ed"),18,0),rect)
	for side in [-1,1]: diagram.draw_line(Vector2(rect.position.x,rect.get_center().y+side*28),Vector2(rect.end.x,rect.get_center().y+side*28),Color("f5f9fa"),3,true)
	for feature in piste.get("features",[]):
		var at := Vector2(lerpf(rect.position.x+12,rect.end.x-12,feature.fraction),rect.get_center().y+feature.lateral/maxf(1,Snow.piste_width(piste))*60)
		diagram.draw_circle(at,7,Color("5c8b91"))
	var selected := Vector2(lerpf(rect.position.x+12,rect.end.x-12,position_slider.value/100),rect.get_center().y+lateral_slider.value/maxf(1,Snow.piste_width(piste))*60)
	diagram.draw_circle(selected,10,Color("d29962"))
	diagram.draw_line(Vector2(rect.end.x-28,rect.get_center().y),Vector2(rect.end.x-10,rect.get_center().y),Color("577981"),3,true)
