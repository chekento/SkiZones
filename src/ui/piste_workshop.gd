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
var rotation_slider := HSlider.new()
var scale_slider := HSlider.new()
var rotation_label:Label
var scale_label:Label
var _diagram_contact := -1
var position_label: Label
var lateral_label: Label
var status: Label
var list: VBoxContainer
var install_button: Button
var duplicate_button:Button
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
	diagram.mouse_filter=Control.MOUSE_FILTER_STOP
	diagram.gui_input.connect(_on_diagram_input)
	scroll.gesture_exclusions.append(diagram)
	for index in range(Features.KINDS.size()): kind.add_item(L.text(Features.NAMES[index])+" · "+str(Features.COSTS[index])+" €")
	kind.fit_to_longest_item=false;kind.clip_text=true;kind.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
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
	rotation_label=hud._label(content,"",17)
	rotation_slider.min_value=-45;rotation_slider.max_value=45;rotation_slider.step=1
	rotation_slider.custom_minimum_size.y=48;content.add_child(rotation_slider)
	scale_label=hud._label(content,"",17)
	scale_slider.min_value=70;scale_slider.max_value=140;scale_slider.step=5;scale_slider.value=100
	scale_slider.custom_minimum_size.y=48;content.add_child(scale_slider)
	for label in [position_label,lateral_label,rotation_label,scale_label]:label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status=hud._label(content,"",16,hud.MUTED,true)
	var row := HFlowContainer.new()
	content.add_child(row)
	install_button=hud._button(row,L.text("Modul einbauen"),_install,true)
	duplicate_button=hud._button(row,L.text("Modul duplizieren"),_duplicate)
	hud._button(row,L.text("Neues Modul"),func(): selected_index=-1; _refresh())
	hud._button(row,L.text("Modul am Hang ansehen"),_show_on_slope)
	hud._label(content,L.text("Pistenplan: Modul mit Finger oder Maus direkt positionieren; Feineinstellung über die Regler."),15,hud.MUTED,true)
	hud._label(content,L.text("Eingebaute Module · antippen zum Verschieben"),19,hud.TEAL,true)
	list=hud._vbox(content,8)
	for slider in [position_slider,lateral_slider,rotation_slider,scale_slider]: slider.value_changed.connect(func(_value: float): _refresh())
	kind.item_selected.connect(func(_index: int): _refresh())
	hud._label(body,L.text("Freie Anfahrt, Landebereich und Umfahrung beachten. Versetzen kostet 120 €; größere Module zusätzlich den Preisunterschied. Entfernen erstattet keine Baukosten."),14,hud.MUTED,true)
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
	var was_visible := visible
	_diagram_contact=-1
	hide()
	if was_visible: hud.game.view.preview([],Color.WHITE)
	hud.refresh()

func _refresh() -> void:
	if asset_id<0: return
	var piste: Dictionary=hud.game.model.asset(asset_id)
	if piste.is_empty(): close(); return
	var options:=_options()
	var feature_kind:String=Features.KINDS[kind.selected]
	var footprint:=Features.Modules.footprint(feature_kind,options)
	var margin:float=maxf(0.0,Snow.piste_width(piste)*0.5-footprint.x*0.5-1.0)
	if Features.Modules.legacy(feature_kind) and is_zero_approx(rotation_slider.value) and is_equal_approx(scale_slider.value,100):margin=Snow.piste_width(piste)*0.5-3.5
	lateral_slider.min_value=-margin
	lateral_slider.max_value=margin
	position_label.text=L.text("Abschnitt: %.1f %% · %.0f m ab Pistenanfang")%L.args([position_slider.value,piste.length*position_slider.value/100])
	lateral_label.text=L.text("Seitlicher Abstand zur Mitte: %+.2f m")%L.args(lateral_slider.value)
	rotation_label.text=L.text("Drehung zur Piste: %+.0f°") % rotation_slider.value
	scale_label.text=L.text("Größe: %.0f %%") % scale_slider.value
	var result: Dictionary=Features.check(hud.game.model,asset_id,feature_kind,position_slider.value/100,lateral_slider.value,selected_index,options)
	var spec:Dictionary=Features.Modules.spec(feature_kind)
	status.text=result.message+"\n"+L.text("Niveau %d · %.1f × %.1f m · Unterhalt %.0f €/Tag") % [int(spec.skill)+1,footprint.x,footprint.y,float(spec.upkeep)*scale_slider.value/100.0]
	install_button.disabled=not result.ok
	duplicate_button.disabled=selected_index<0 or piste.get("features",[]).size()>=Features.MAX_FEATURES
	install_button.text=(L.text("Modul versetzen") if selected_index>=0 else L.text("Modul einbauen"))+" · "+str(result.get("cost",0))+" €"
	diagram.queue_redraw()
	var preview:Dictionary={"kind":feature_kind,"fraction":position_slider.value/100,"lateral":lateral_slider.value}
	preview.merge(options)
	hud.game.view.preview_piste_feature(piste,preview)

func _options()->Dictionary:
	return {"rotation":rotation_slider.value,"scale":scale_slider.value/100.0}

func _duplicate()->void:
	if selected_index<0:return
	var piste:Dictionary=hud.game.model.asset(asset_id)
	var footprint:=Features.Modules.footprint(Features.KINDS[kind.selected],_options())
	selected_index=-1
	position_slider.set_value_no_signal(clampf(position_slider.value+(footprint.y+12.0)/float(piste.length)*100.0,0,100))
	_refresh()

func _show_on_slope() -> void:
	if window.fullscreen: window.toggle_fullscreen()
	window.position=Vector2(12,175)
	window.size=Vector2(620,510)
	window._fit()
	var piste: Dictionary=hud.game.model.asset(asset_id)
	hud.game.view.focus=hud.game.model.terrain.point_on_path(piste.points,position_slider.value/100)
	hud.game.view.zoom=100
	hud.game.view._update_camera()

func blocks_map(point: Vector2) -> bool:
	return visible and window.get_global_rect().has_point(point)

func _install() -> void:
	var result: Dictionary=Features.install(hud.game.model,asset_id,Features.KINDS[kind.selected],position_slider.value/100,lateral_slider.value,selected_index,_options())
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
		var group:VBoxContainer=hud._vbox(list,4)
		var row := HBoxContainer.new()
		group.add_child(row)
		var select: Button=hud._button(row,L.text(Features.NAMES[Features.KINDS.find(feature.kind)])+" · %.1f %% · %+.1f m"%[feature.fraction*100,feature.lateral],func():
			selected_index=index
			kind.select(Features.KINDS.find(feature.kind))
			position_slider.set_value_no_signal(feature.fraction*100)
			lateral_slider.set_value_no_signal(feature.lateral)
			rotation_slider.set_value_no_signal(float(feature.get("rotation",0)))
			scale_slider.set_value_no_signal(float(feature.get("scale",1))*100.0)
			_refresh()
		)
		select.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		select.clip_text=true
		select.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		hud._label(group,L.text("Zustand %.0f %% · Nutzungen %d") % [float(feature.get("condition",100)),int(feature.get("uses",0))],14,hud.MUTED)
		hud._button(row,L.text("Warten · %d €") % Features.maintenance_cost(feature),func():
			var result:Dictionary=Features.maintain(hud.game.model,asset_id,index)
			hud.toast(result.message);_rebuild_list();_refresh()
		)
		hud._button(row,L.text("Entfernen"),func():
			var result: Dictionary=Features.remove(hud.game.model,asset_id,index)
			hud.toast(result.message)
			selected_index=-1
			hud.game.view.rebuild()
			_rebuild_list()
			_refresh()
		)

func _on_diagram_input(event:InputEvent)->void:
	if asset_id<0:return
	if event is InputEventScreenTouch:
		if event.pressed:_diagram_contact=event.index
		elif event.index==_diagram_contact:_diagram_contact=-1
		else:return
	elif event is InputEventScreenDrag:
		if event.index!=_diagram_contact:return
	elif event is InputEventMouseButton:
		if event.button_index!=MOUSE_BUTTON_LEFT:return
		_diagram_contact=-2 if event.pressed else -1
	elif event is InputEventMouseMotion:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):return
	else:return
	diagram.accept_event()
	if _diagram_contact==-1:return
	var rect:=Rect2(20,14,maxf(80,diagram.size.x-40),78)
	var p:Vector2=event.position
	position_slider.set_value_no_signal(clampf((p.x-rect.position.x-12)/maxf(1.0,rect.size.x-24),0,1)*100.0)
	var piste:Dictionary=hud.game.model.asset(asset_id)
	if piste.is_empty():return
	lateral_slider.set_value_no_signal(clampf((p.y-rect.get_center().y)*Snow.piste_width(piste)/60.0,lateral_slider.min_value,lateral_slider.max_value))
	_refresh()

func _draw_plan() -> void:
	if asset_id<0: return
	var piste: Dictionary=hud.game.model.asset(asset_id)
	var rect := Rect2(20,14,maxf(80,diagram.size.x-40),78)
	diagram.draw_style_box(hud._style(Color("d4e4ed"),18,0),rect)
	for side in [-1,1]: diagram.draw_line(Vector2(rect.position.x,rect.get_center().y+side*28),Vector2(rect.end.x,rect.get_center().y+side*28),Color("f5f9fa"),3,true)
	for feature in piste.get("features",[]):
		var at := Vector2(lerpf(rect.position.x+12,rect.end.x-12,feature.fraction),rect.get_center().y+feature.lateral/maxf(1,Snow.piste_width(piste))*60)
		_draw_symbol(feature.kind,at,Color("5c8b91"))
	var selected := Vector2(lerpf(rect.position.x+12,rect.end.x-12,position_slider.value/100),rect.get_center().y+lateral_slider.value/maxf(1,Snow.piste_width(piste))*60)
	diagram.draw_circle(selected,13,Color("f1d5ae"))
	_draw_symbol(Features.KINDS[kind.selected],selected,Color("ae764c"))
	diagram.draw_line(Vector2(rect.end.x-28,rect.get_center().y),Vector2(rect.end.x-10,rect.get_center().y),Color("577981"),3,true)

func _draw_symbol(feature_kind: String, at: Vector2, color: Color) -> void:
	var shape:String=Features.Modules.spec(feature_kind).get("shape","")
	if shape in ["kicker","table","up","down","spine","transfer"]:
		diagram.draw_colored_polygon(PackedVector2Array([at+Vector2(-8,6),at+Vector2(8,6),at+Vector2(6,-7)]),color)
	elif feature_kind=="rail" or shape in ["downrail","kink","rainbow","box","tube"]:
		diagram.draw_line(at+Vector2(-10,-3),at+Vector2(10,-3),color,4,true)
		for side in [-1,1]: diagram.draw_line(at+Vector2(side*7,-3),at+Vector2(side*7,6),color,2,true)
	else: diagram.draw_arc(at+Vector2(0,5),9,PI,TAU,16,color,4,true)
