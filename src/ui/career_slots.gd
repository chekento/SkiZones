extends PanelContainer
const L=preload("res://src/core/i18n.gd")
const Saves=preload("res://src/core/save_store.gd")
const Maps=preload("res://src/core/maps.gd")
const DragScroll=preload("res://src/ui/drag_scroll.gd")
const StartTiers=preload("res://src/core/start_tiers.gd")
var hud: CanvasLayer
var cards: GridContainer
var confirmation:=ConfirmationDialog.new()
var pending_slot:=1
var starting_tier:=OptionButton.new()
var tier_details:=Label.new()
var heading_label: Label
var close_button: Button
func setup(interface: CanvasLayer) -> void:
	hud=interface
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left=48;offset_right=-48;offset_top=110;offset_bottom=-28
	add_theme_stylebox_override("panel",hud._style(Color("fffaf2"),18,22))
	var body: VBoxContainer=hud._vbox(self,12)
	var row:=HBoxContainer.new();body.add_child(row)
	heading_label=hud._label(row,L.text("DEINE VIER KARRIEREN"),26,hud.ACCENT)
	heading_label.clip_text=true
	heading_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	heading_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	close_button=hud._button(row,L.text("Zurück"),hide)
	hud._label(body,L.text("Vier getrennte Karrieren mit eigenen Resorts und Freischaltungen. Freier Aufbau besitzt eigene Spielstände."),17,hud.MUTED,true)
	var tier_box:=PanelContainer.new();tier_box.add_theme_stylebox_override("panel",hud._style(Color("e1eeea"),12,12));body.add_child(tier_box)
	var controls: VBoxContainer=hud._vbox(tier_box,5)
	hud._label(controls,L.text("STARTKAPITAL · NUR FÜR NEUE KARRIEREN"),17,hud.ACCENT,true)
	for tier in StartTiers.LEVELS:
		starting_tier.add_item(L.text(str(tier.name)) + " · " + hud.money_text(tier.money) + " €")
	starting_tier.select(2)
	starting_tier.custom_minimum_size.y=46
	starting_tier.fit_to_longest_item=false
	starting_tier.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	controls.add_child(starting_tier)
	tier_details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	tier_details.add_theme_font_size_override("font_size",15)
	controls.add_child(tier_details)
	starting_tier.item_selected.connect(func(_index:int):_update_tier_hint())
	_update_tier_hint()
	var scroll:=DragScroll.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_child(scroll)
	cards=GridContainer.new();cards.columns=2;cards.add_theme_constant_override("h_separation",14);cards.add_theme_constant_override("v_separation",14)
	cards.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(cards)
	get_viewport().size_changed.connect(_fit)
	call_deferred("_fit")
	add_child(confirmation);confirmation.title=L.text("Karriere neu beginnen?")
	confirmation.dialog_text=L.text("Diese Karriere wird vor dem Neustart als Sicherung aufbewahrt. Die anderen drei Karrieren bleiben erhalten.")
	confirmation.ok_button_text=L.text("Sichern und neu beginnen")
	confirmation.cancel_button_text=L.text("Abbrechen")
	confirmation.confirmed.connect(func():hud.game.select_career_slot(pending_slot,true,starting_tier.selected))
	hide()
func open() -> void:
	hud.game._clear_input();_fit();refresh();show()
func refresh() -> void:
	for child in cards.get_children():cards.remove_child(child);child.queue_free()
	for number in range(1,5):
		var slot: int=number
		var summary:=Saves.summary(slot)
		var panel:=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.add_theme_stylebox_override("panel",hud._style(Color("edf3ec"),12,16));cards.add_child(panel)
		var body: VBoxContainer=hud._vbox(panel,8)
		hud._label(body,L.text("Karriere %d") % slot,23,hud.TEAL)
		if summary.occupied:
			var damaged: bool = summary.get("damaged", false)
			hud._label(body,L.text("Spielstand vorhanden – Wiederherstellung prüfen") if damaged else (L.text("%s · Tag %d · %d Sterne · %s €") % [L.text(Maps.spec(summary.map).name),summary.day,summary.rank,hud.money_text(summary.money)]),17,hud.INK,true)
			hud._button(body,L.text("Spielstand prüfen") if damaged else L.text("Diese Karriere fortsetzen"),func():hud.game.select_career_slot(slot,false),true)
			# Do not hide another old mountain behind a single last-map index.
			var entries: Array = Saves.saved_resorts(slot)
			if entries.size() > 1:
				hud._label(body,L.text("Weitere gespeicherte Gebiete"),16,hud.TEAL,true)
				for entry in entries:
					if entry.map == summary.map: continue
					var area: String = str(entry.map)
					var subtitle: String = L.text("Spielstand prüfen") if entry.damaged else L.text("Resort fortsetzen")
					hud._button(body,L.text(Maps.spec(area).name) + " · " + subtitle,func():hud.game.select_career_area(slot,area))
			hud._button(body,L.text("Neue Karriere auf diesem Platz"),func():pending_slot=slot;confirmation.popup_centered(Vector2i(620,230)))
		else:
			hud._label(body,L.text("Freier Karriereplatz"),17,hud.MUTED)
			hud._button(body,L.text("Neue Karriere starten"),func():hud.game.select_career_slot(slot,true,starting_tier.selected),true)

func _update_tier_hint() -> void:
	var tier: Dictionary = StartTiers.choice(starting_tier.selected)
	tier_details.text = L.text(str(tier.description)) + " · " + L.text("Die Wahl verändert nur neue Karrieren und niemals bestehende Spielstände.")

func _fit() -> void:
	if not is_inside_tree(): return
	var w: float = minf(get_viewport_rect().size.x, get_tree().root.size.x)
	var narrow: bool = w < 1050.0
	cards.columns = 1 if narrow else 2
	offset_left = 10 if narrow else 48
	offset_right = -10 if narrow else -48
	offset_top = 76 if w < 650.0 else 110
	offset_bottom = -10 if narrow else -28
	if is_instance_valid(heading_label):
		heading_label.add_theme_font_size_override("font_size",18 if w<650 else 22 if narrow else 26)
	if is_instance_valid(close_button):
		close_button.text="✕" if w<650 else L.text("Zurück")
		close_button.tooltip_text=L.text("Zurück")
		close_button.custom_minimum_size.x=48 if w<650 else 0
