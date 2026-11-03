extends Control
const L = preload("res://src/core/i18n.gd")
const Annual = preload("res://src/core/annual_festival.gd")
const ScenarioMedals = preload("res://src/core/scenario_medals.gd")
const FloatingFrame = preload("res://src/ui/floating_window.gd")
const DragScroll = preload("res://src/ui/drag_scroll.gd")
var hud: CanvasLayer
var frame := FloatingFrame.new()
var content := VBoxContainer.new()
var old_pause := false

func setup(owner_hud: CanvasLayer) -> void:
	hud=owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var veil:=ColorRect.new()
	veil.color=Color(0.02,0.04,0.08,0.58)
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	frame.setup(hud,L.text("Deine Medaillensammlung"))
	frame.close_requested.connect(close)
	var scroll:=DragScroll.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	frame.body.add_child(scroll)
	scroll.add_child(content)
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",10)
	hide()

func _card(title: String, subtitle: String, tint: Color) -> void:
	var panel:=PanelContainer.new()
	panel.add_theme_stylebox_override("panel",hud._style(tint,13,16))
	content.add_child(panel)
	var box:=hud._vbox(panel,5)
	hud._label(box,title,22,hud.INK,true)
	hud._label(box,subtitle,15,hud.MUTED,true)

func open() -> void:
	if not visible:
		old_pause=hud.game.paused
		hud.game.paused=true
	for node in content.get_children():
		content.remove_child(node)
		node.queue_free()
	hud._label(content,L.text("Jedes Jahr eine neue Erinnerung"),26,hud.TEAL,true)
	hud._label(content,L.text("Die Jahresmedaillen liegen unabhängig vom aktuellen Karrierespielstand im dauerhaften Spielerarchiv."),16,hud.MUTED,true)
	var state: Dictionary=Annual.new().overview()
	var medals: Array=state.medals
	var scenario_medals: Array=ScenarioMedals.new().medals()
	if medals.is_empty() and scenario_medals.is_empty():
		_card(L.text("Noch keine Medaillen"),L.text("Nimm im Dezember an einem Adventstag teil oder meistere ein Szenario."),Color("e8f0eb"))
	for medal in medals:
		var event: String=str(medal.event)
		var head:=("🎄 " if event=="christmas" else "🎆 ")+L.text(str(medal.title))
		var detail:=L.text("Weihnachtsteilnahme") if event=="christmas" else L.text("Neujahrsfeier")
		if medal.get("special",false) and event=="christmas": detail+=" · "+L.text("Heiligabend-Goldstern")
		_card(head,detail,Color("f4e1c2") if event=="christmas" else Color("dce7f3"))
	for medal in scenario_medals:
		_card("🏅 "+L.text(str(medal.title)),L.text("Erfolgreich abgeschlossenes reales Resort-Szenario"),Color("f2e6cc"))
	hud._label(content,L.text("Aktuelle Karriere: %d freigeschaltete Achievements · 1000 mögliche Leistungserfolge.") % hud.game.model.achievements.size(),16,hud.MUTED,true)
	show()
	frame._fit()

func close() -> void:
	if visible: hud.game.paused=old_pause
	hide()
	hud.refresh()
