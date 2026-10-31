extends PanelContainer
const L=preload("res://src/core/i18n.gd")
const Saves=preload("res://src/core/save_store.gd")
const Maps=preload("res://src/core/maps.gd")
const DragScroll=preload("res://src/ui/drag_scroll.gd")
var hud: CanvasLayer
var cards: GridContainer
var confirmation:=ConfirmationDialog.new()
var pending_slot:=1
func setup(interface: CanvasLayer) -> void:
	hud=interface
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left=48;offset_right=-48;offset_top=110;offset_bottom=-28
	add_theme_stylebox_override("panel",hud._style(Color("fffaf2"),18,22))
	var body: VBoxContainer=hud._vbox(self,12)
	var row:=HBoxContainer.new();body.add_child(row)
	hud._label(row,L.text("DEINE VIER KARRIEREN"),26,hud.ACCENT)
	hud._spacer(row,false);hud._button(row,L.text("Zurück"),hide)
	hud._label(body,L.text("Vier getrennte Karrieren mit eigenen Resorts und Freischaltungen. Freier Aufbau und Szenarien behalten eigene Spielstände."),17,hud.MUTED,true)
	var scroll:=DragScroll.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
	cards=GridContainer.new();cards.columns=2;cards.add_theme_constant_override("h_separation",14);cards.add_theme_constant_override("v_separation",14)
	cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(cards)
	add_child(confirmation);confirmation.title=L.text("Karriere neu beginnen?")
	confirmation.dialog_text=L.text("Diese Karriere wird vor dem Neustart als Sicherung aufbewahrt. Die anderen drei Karrieren bleiben erhalten.")
	confirmation.ok_button_text=L.text("Sichern und neu beginnen")
	confirmation.cancel_button_text=L.text("Abbrechen")
	confirmation.confirmed.connect(func():hud.game.select_career_slot(pending_slot,true))
	hide()
func open() -> void:
	hud.game._clear_input();refresh();show()
func refresh() -> void:
	for child in cards.get_children():cards.remove_child(child);child.queue_free()
	for number in range(1,5):
		var slot: int=number
		var summary:=Saves.summary(slot)
		var panel:=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.add_theme_stylebox_override("panel",hud._style(Color("edf3ec"),12,16));cards.add_child(panel)
		var body: VBoxContainer=hud._vbox(panel,8)
		hud._label(body,L.text("Karriere %d") % slot,23,hud.TEAL)
		if summary.occupied:
			hud._label(body,L.text("%s · Tag %d · %d Sterne · %s €") % [L.text(Maps.spec(summary.map).name),summary.day,summary.rank,hud.money_text(summary.money)],17,hud.INK,true)
			hud._button(body,L.text("Diese Karriere fortsetzen"),func():hud.game.select_career_slot(slot,false),true)
			hud._button(body,L.text("Neue Karriere auf diesem Platz"),func():pending_slot=slot;confirmation.popup_centered(Vector2i(620,230)))
		else:
			hud._label(body,L.text("Freier Karriereplatz"),17,hud.MUTED)
			hud._button(body,L.text("Neue Karriere starten"),func():hud.game.select_career_slot(slot,true),true)
