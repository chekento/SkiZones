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
var action_grids: Array[GridContainer] = []
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
	heading_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
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
	archive_confirmation.ok_button_text=L.text("Löschen & sichern")
	archive_confirmation.cancel_button_text=L.text("Abbrechen")
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
	hud.present_dialog(archive_confirmation,Vector2i(620,240))

func _slot_summary(parent: VBoxContainer, summary: Dictionary, damaged: bool) -> void:
	if damaged:
		hud._label(parent,L.text("Spielstand vorhanden – Wiederherstellung prüfen"),16,hud.ACCENT,true)
		return
	hud._label(parent,L.text(Maps.spec(summary.map).name),18,hud.INK,true)
	var stats:=HBoxContainer.new()
	stats.add_theme_constant_override("separation",8)
	parent.add_child(stats)
	for entry in [[L.text("Tag"),str(int(summary.day))],[L.text("Sterne"),str(int(summary.rank))],[L.text("Guthaben"),"∞" if free_mode else hud.money_text(summary.money)+" €"]]:
		var tile:=PanelContainer.new()
		tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		tile.add_theme_stylebox_override("panel",hud._style(Color("edf3f0"),8,8))
		stats.add_child(tile)
		var column:VBoxContainer=hud._vbox(tile,2)
		hud._label(column,str(entry[0]),13,hud.MUTED,true)
		hud._label(column,str(entry[1]),14 if entry[0]==L.text("Guthaben") else 16,hud.INK,true)

func _management_actions(parent:VBoxContainer,map_id:String,slot:int,free_slot:int=1) -> void:
	# Keep recovery and destructive actions behind a deliberate disclosure.
	# The resort card itself shows only play/new and this compact manager.
	var drawer:=PanelContainer.new()
	drawer.name="save_manager_submenu"
	drawer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	drawer.add_theme_stylebox_override("panel",hud._style(Color("edf3f0"),10,12))
	var toggle:Button=hud._button(parent,L.text("Verwalten  ▾"),func():drawer.visible=not drawer.visible)
	toggle.name="toggle_save_manager"
	toggle.tooltip_text=L.text("Prüfen, reparieren, kopieren oder sicher archivieren")
	toggle.custom_minimum_size.y=42
	parent.add_child(drawer)
	var content:VBoxContainer=hud._vbox(drawer,8)
	hud._label(content,L.text("SPIELSTANDVERWALTUNG"),14,hud.TEAL,true)
	drawer.hide()
	var section:=GridContainer.new()
	section.columns=2
	section.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("h_separation",8)
	section.add_theme_constant_override("v_separation",8)
	action_grids.append(section)
	section.name="save_manager_actions"
	section.resized.connect(_fit_actions)
	content.add_child(section)
	var diagnostic: Label=hud._label(content,"",14,hud.TEAL,true)
	diagnostic.name="save_diagnostics"
	diagnostic.hide()
	var check: Button=hud._button(section,L.text("Prüfen"),func():
		diagnostic.show()
		var report:Dictionary=SaveManager.inspect(map_id,slot,free_slot)
		if not report.ok:
			diagnostic.text=L.text("Keine Datei gefunden.")
		else:
			diagnostic.text=L.text("%d Dateien · %d geprüft · %d ladbar · %d wiederherstellbar") % [report.files.size(),int(report.verified),int(report.loadable),int(report.recoverable)]
			if bool(report.damaged):
				diagnostic.text+=" · "+L.text("Prüfung fehlgeschlagen: Originaldateien erhalten.")
			for entry in report.files:
				var state: String = L.text("Ladbar") if bool(entry.loadable) else L.text("Rettbar") if bool(entry.recoverable) else L.text("Nicht ladbar")
				var reason: String = str(entry.get("reason", "unknown"))
				var version: int = int(entry.get("version", -1))
				var size_kib: int = ceili(float(entry.get("bytes", 0)) / 1024.0)
				diagnostic.text += "\n%s · %s · %d KiB · v%d · %s" % [str(entry.name),state,size_kib,version,reason]
				if not bool(entry.loadable) and not bool(entry.recoverable) and str(entry.message)!="":
					diagnostic.text+="\n"+str(entry.message)
	)
	check.name="check_save_038"
	check.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var rescue: Button=hud._button(section,L.text("Reparieren"),func():
		if hud.game.has_game and Saves.active_slot==slot and (slot!=0 or Saves.active_free_slot==free_slot) and hud.game.model.map_id==map_id:
			hud.toast(L.text("Aktives Resort: zuerst einen anderen Spielstand laden."))
			return
		var result:Dictionary=SaveManager.repair(map_id,slot,free_slot)
		hud.toast(L.text(str(result.message)))
		if result.ok:refresh()
	)
	rescue.name="rescue_save_038"
	var destination:=HBoxContainer.new()
	destination.add_theme_constant_override("separation",10)
	content.add_child(destination)
	hud._label(destination,L.text("Kopie nach"),16,hud.MUTED)
	var target:=OptionButton.new()
	target.name="copy_target"
	target.custom_minimum_size=Vector2(140,48)
	target.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	destination.add_child(target)
	for n in range(1,5):
		if n==(free_slot if slot==0 else slot):continue
		target.add_item(L.text("Platz %d") % n,n)
	var copy: Button=hud._button(section,L.text("Kopie erstellen"),func():
		var dst:int=target.get_selected_id()
		var result:Dictionary=SaveManager.copy(map_id,slot,slot if slot==0 else dst,free_slot,dst if slot==0 else 1)
		hud.toast(L.text(str(result.message)))
		if result.ok:refresh()
	)
	copy.name="copy_save_038"
	var remove: Button=hud._button(section,L.text("Löschen & sichern"),func():_request_archive(map_id,slot,free_slot))
	remove.name="archive_save_038"
	remove.add_theme_stylebox_override("normal",hud._style(Color("f4d5cc"),9,10))
	remove.add_theme_stylebox_override("hover",hud._style(Color("edbcb0"),9,10))
	remove.add_theme_stylebox_override("pressed",hud._style(Color("e9ad9e"),9,10))
	remove.tooltip_text=L.text("Mit geprüfter Sicherung aus diesem Platz entfernen.")
	for button in [check,rescue,copy,remove]:
		button.add_theme_font_size_override("font_size",16)
		button.custom_minimum_size=Vector2(144,50)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

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
		panel.add_theme_stylebox_override("panel", hud._style(Color("ffffff"),12,16))
		cards.add_child(panel)
		var body: VBoxContainer = hud._vbox(panel,8)
		hud._label(body,L.text("Freier Aufbau · Platz %d") % free_slot,22,hud.TEAL)
		if summary.occupied:
			var damaged: bool = bool(summary.get("damaged", false))
			_slot_summary(body,summary,damaged)
			hud._button(body,L.text("Freies Resort fortsetzen"),func():hud.game.select_free_slot(free_slot),true)
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
				hud.present_dialog(confirmation,Vector2i(620,240))
			)
		else:
			hud._label(body,L.text("Leerer freier Spielstand"),16,hud.MUTED)
			hud._button(body,L.text("Freies Resort starten"),func():hud.game.select_free_slot(free_slot,true),true)

func refresh() -> void:
	action_grids.clear()
	heading_label.text=L.text("DEINE VIER FREIEN SPIELSTÄNDE") if free_mode else L.text("DEINE VIER KARRIEREN")
	intro_label.text=L.text("Vier unabhängige Plätze für freien Aufbau. Platz 1 enthält bisherige freie Spielstände.") if free_mode else L.text("Vier getrennte Karrieren mit eigenen Resorts und Freischaltungen. Freier Aufbau besitzt eigene Spielstände.")
	tier_panel.visible=not free_mode
	confirmation.title=L.text("Freien Spielstand neu beginnen?") if free_mode else L.text("Karriere neu beginnen?")
	confirmation.dialog_text=L.text("Der bisherige freie Spielstand wird zuerst archiviert. Die anderen freien Plätze und Karrieren bleiben erhalten.") if free_mode else L.text("Diese Karriere wird vor dem Neustart als Sicherung aufbewahrt. Die anderen drei Karrieren bleiben erhalten.")
	for child in cards.get_children():cards.remove_child(child);child.queue_free()
	if free_mode:
		_refresh_free_cards()
		call_deferred("_fit_actions")
		return
	for child in cards.get_children():cards.remove_child(child);child.queue_free()
	for number in range(1,5):
		var slot: int=number
		var summary:=Saves.summary(slot)
		var panel:=PanelContainer.new();panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.add_theme_stylebox_override("panel",hud._style(Color("ffffff"),12,16));cards.add_child(panel)
		var body: VBoxContainer=hud._vbox(panel,8)
		hud._label(body,L.text("Karriere %d") % slot,23,hud.TEAL)
		if summary.occupied:
			var damaged: bool = summary.get("damaged", false)
			_slot_summary(body,summary,damaged)
			hud._button(body,L.text("Diese Karriere fortsetzen"),func():hud.game.select_career_slot(slot,false),true)
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
			hud._button(body,L.text("Neue Karriere auf diesem Platz"),func():pending_slot=slot;hud.present_dialog(confirmation,Vector2i(620,240)))
		else:
			hud._label(body,L.text("Freier Karriereplatz"),17,hud.MUTED)
			hud._button(body,L.text("Neue Karriere starten"),func():hud.game.select_career_slot(slot,true,starting_tier.selected),true)

	call_deferred("_fit_actions")

func _fit_actions() -> void:
	for button in cards.find_children("*","Button",true,false):
		if not button is OptionButton:button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for grid in action_grids:
		if is_instance_valid(grid):grid.columns=2 if grid.size.x>=310 else 1

func _update_tier_hint() -> void:
	var tier: Dictionary = StartTiers.choice(starting_tier.selected)
	tier_details.text = L.text(str(tier.description)) + " · " + L.text("Die Wahl verändert nur neue Karrieren und niemals bestehende Spielstände.")

func _fit() -> void:
	if not is_inside_tree(): return
	var w: float = minf(get_viewport_rect().size.x, get_tree().root.size.x)
	var h: float = minf(get_viewport_rect().size.y, get_tree().root.size.y)
	intro_label.visible=w>=650 and h>=520
	tier_details.visible=w>=1000 and h>=600
	var narrow: bool = w < 1050.0
	cards.columns = 1 if narrow else 2
	call_deferred("_fit_actions")
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	if is_instance_valid(heading_label):
		heading_label.add_theme_font_size_override("font_size",18 if w<650 else 22 if narrow else 26)
	if is_instance_valid(close_button):
		close_button.text=L.text("Zurück")
		close_button.tooltip_text=L.text("Zurück")
		close_button.custom_minimum_size.x=48 if w<650 else 0
