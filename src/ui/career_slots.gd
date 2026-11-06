extends PanelContainer
const L=preload("res://src/core/i18n.gd")
const Saves=preload("res://src/core/save_store.gd")
const SaveManager=preload("res://src/core/save_management_038.gd")
const Maps=preload("res://src/core/maps.gd")
const DragScroll=preload("res://src/ui/drag_scroll.gd")
const StartTiers=preload("res://src/core/start_tiers.gd")
var hud: CanvasLayer
var cards: GridContainer
var confirmation:=ConfirmationDialog.new()
var archive_confirmation:=ConfirmationDialog.new()
var pending_archive: Dictionary={}
var pending_slot:=1
var free_mode := false
var tier_panel: PanelContainer
var intro_label: Label
var starting_tier:=OptionButton.new()
var tier_details:=Label.new()
var heading_label: Label
var close_button: Button
func setup(interface: CanvasLayer) -> void:
	hud=interface
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left=0;offset_right=0;offset_top=0;offset_bottom=0
	z_index=55
	mouse_filter=Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",hud._style(Color("fffaf2"),0,24))
	var body: VBoxContainer=hud._vbox(self,12)
	var row:=HBoxContainer.new();body.add_child(row)
	heading_label=hud._label(row,L.text("DEINE VIER KARRIEREN"),26,hud.ACCENT)
	heading_label.clip_text=true
	heading_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	heading_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	close_button=hud._button(row,L.text("Zurück"),hide)
	intro_label=hud._label(body,L.text("Vier getrennte Karrieren mit eigenen Resorts und Freischaltungen. Freier Aufbau besitzt eigene Spielstände."),17,hud.MUTED,true)
	tier_panel=PanelContainer.new();tier_panel.add_theme_stylebox_override("panel",hud._style(Color("e1eeea"),12,12));body.add_child(tier_panel)
	var controls: VBoxContainer=hud._vbox(tier_panel,5)
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
	confirmation.confirmed.connect(func():
		if free_mode: hud.game.select_free_slot(pending_slot,true)
		else: hud.game.select_career_slot(pending_slot,true,starting_tier.selected)
	)
	add_child(archive_confirmation)
	archive_confirmation.title=L.text("Resort sicher archivieren?")
	archive_confirmation.ok_button_text=L.text("Archivieren und aus Platz entfernen")
	archive_confirmation.dialog_text=L.text("Original und Sicherung werden vor dem Entfernen vollständig kopiert und überprüft.")
	archive_confirmation.confirmed.connect(_archive_confirmed)
	hide()
func _archive_confirmed() -> void:
	if pending_archive.is_empty():return
	var slot:int=int(pending_archive.slot)
	var free:int=int(pending_archive.free_slot)
	var map_id:String=str(pending_archive.map)
	pending_archive.clear()
	# A loaded resort must never be deleted and then silently auto-saved
	# back into the just-archived slot. Change the active career first.
	if hud.game.has_game and Saves.active_slot==slot and (slot!=0 or Saves.active_free_slot==free) and hud.game.model.map_id==map_id:
		hud.toast(L.text("Aktives Resort: vor dem Archivieren einen anderen Spielstand laden."))
		return
	var result:Dictionary=SaveManager.archive(map_id,slot,free)
	hud.toast(L.text(str(result.message)))
	if result.ok: refresh()

func _request_archive(map_id:String,slot:int,free:int) -> void:
	pending_archive={"map":map_id,"slot":slot,"free_slot":free}
	archive_confirmation.popup_centered(Vector2i(620,220))

func _management_actions(parent:VBoxContainer,map_id:String,slot:int,free_slot:int=1) -> void:
	var section:=HBoxContainer.new()
	section.name="save_manager_actions"
	parent.add_child(section)
	var diagnostic:=hud._label(parent,"",14,hud.TEAL,true)
	diagnostic.name="save_diagnostics"
	var check:=hud._button(section,L.text("Prüfen & retten"),func():
		var report:Dictionary=SaveManager.inspect(map_id,slot,free_slot)
		if not report.ok:
			diagnostic.text=L.text("Keine Datei gefunden.")
		else:
			diagnostic.text=L.text("%d Dateien · %d geprüft · %d ladbar · %d wiederherstellbar") % [report.files.size(),int(report.verified),int(report.loadable),int(report.recoverable)]
			if bool(report.damaged):diagnostic.text+=" · "+L.text("Prüfung fehlgeschlagen: Originaldateien erhalten.")
	)
	check.name="check_save_038"
	check.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var target:=OptionButton.new()
	target.name="copy_target"
	target.custom_minimum_size=Vector2(95,46)
	section.add_child(target)
	for n in range(1,5):
		if n==(free_slot if slot==0 else slot):continue
		target.add_item(L.text("Platz %d") % n,n)
	var copy:=hud._button(section,L.text("Kopieren"),func():
		var dst:int=target.get_selected_id()
		var result:Dictionary=SaveManager.copy(map_id,slot,slot if slot==0 else dst,free_slot,dst if slot==0 else 1)
		hud.toast(L.text(str(result.message)))
		if result.ok:refresh()
	)
	copy.name="copy_save_038"
	var remove:=hud._button(section,L.text("Archivieren"),func():_request_archive(map_id,slot,free_slot))
	remove.name="archive_save_038"
	remove.tooltip_text=L.text("Mit geprüfter Sicherung aus diesem Platz entfernen.")
	for button in [check,copy,remove]:
		button.add_theme_font_size_override("font_size",14)
		button.custom_minimum_size.y=46
		button.clip_text=true
		button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS

func open() -> void:
	free_mode = false
	hud.game._clear_input();_fit();refresh();show()

func open_free() -> void:
	free_mode = true
	hud.game._clear_input();_fit();refresh();show()

func _refresh_free_cards() -> void:
	for number in range(1,5):
		var free_slot: int = number
		var summary: Dictionary = Saves.free_summary(free_slot)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", hud._style(Color("edf3ec"),12,16))
		cards.add_child(panel)
		var body: VBoxContainer = hud._vbox(panel,8)
		hud._label(body,L.text("Freier Aufbau · Platz %d") % free_slot,22,hud.TEAL)
		if summary.occupied:
			var damaged: bool = bool(summary.get("damaged", false))
			hud._label(body,L.text("Spielstand vorhanden – Wiederherstellung prüfen") if damaged else (L.text("%s · Tag %d · %d Sterne · %s €") % [L.text(Maps.spec(summary.map).name),summary.day,summary.rank,hud.money_text(summary.money)]),16,hud.INK,true)
			hud._button(body,L.text("Spielstand prüfen") if damaged else L.text("Freies Resort fortsetzen"),func():hud.game.select_free_slot(free_slot),true)
			_management_actions(body,str(summary.map),0,free_slot)
			var entries: Array = Saves.saved_resorts(0,free_slot)
			if entries.size() > 1:
				for entry in entries:
					if entry.map == summary.map: continue
					var area: String = str(entry.map)
					hud._button(body,L.text(Maps.spec(area).name) + " · " + L.text("Resort fortsetzen"),func():hud.game.select_free_area(free_slot,area))
					_management_actions(body,area,0,free_slot)
			hud._button(body,L.text("Diesen freien Platz neu beginnen"),func():
				pending_slot=free_slot
				confirmation.popup_centered(Vector2i(620,230))
			)
		else:
			hud._label(body,L.text("Leerer freier Spielstand"),16,hud.MUTED)
			hud._button(body,L.text("Freies Resort starten"),func():hud.game.select_free_slot(free_slot,true),true)

func refresh() -> void:
	heading_label.text=L.text("DEINE VIER FREIEN SPIELSTÄNDE") if free_mode else L.text("DEINE VIER KARRIEREN")
	intro_label.text=L.text("Vier unabhängige Plätze für freien Aufbau. Platz 1 enthält bisherige freie Spielstände.") if free_mode else L.text("Vier getrennte Karrieren mit eigenen Resorts und Freischaltungen. Freier Aufbau besitzt eigene Spielstände.")
	tier_panel.visible=not free_mode
	confirmation.title=L.text("Freien Spielstand neu beginnen?") if free_mode else L.text("Karriere neu beginnen?")
	confirmation.dialog_text=L.text("Der bisherige freie Spielstand wird zuerst archiviert. Die anderen freien Plätze und Karrieren bleiben erhalten.") if free_mode else L.text("Diese Karriere wird vor dem Neustart als Sicherung aufbewahrt. Die anderen drei Karrieren bleiben erhalten.")
	for child in cards.get_children():cards.remove_child(child);child.queue_free()
	if free_mode:
		_refresh_free_cards()
		return
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
			_management_actions(body,str(summary.map),slot)
			# Do not hide another old mountain behind a single last-map index.
			var entries: Array = Saves.saved_resorts(slot)
			if entries.size() > 1:
				hud._label(body,L.text("Weitere gespeicherte Gebiete"),16,hud.TEAL,true)
				for entry in entries:
					if entry.map == summary.map: continue
					var area: String = str(entry.map)
					var subtitle: String = L.text("Spielstand prüfen") if entry.damaged else L.text("Resort fortsetzen")
					hud._button(body,L.text(Maps.spec(area).name) + " · " + subtitle,func():hud.game.select_career_area(slot,area))
					_management_actions(body,area,slot)
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
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	if is_instance_valid(heading_label):
		heading_label.add_theme_font_size_override("font_size",18 if w<650 else 22 if narrow else 26)
	if is_instance_valid(close_button):
		close_button.text="✕" if w<650 else L.text("Zurück")
		close_button.tooltip_text=L.text("Zurück")
		close_button.custom_minimum_size.x=48 if w<650 else 0
