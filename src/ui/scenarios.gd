extends PanelContainer
const L = preload("res://src/core/i18n.gd")
const Geo = preload("res://src/core/real_resorts.gd")
const Maps = preload("res://src/core/maps.gd")
const Ops = preload("res://src/core/operations.gd")
const DragScroll = preload("res://src/ui/drag_scroll.gd")
const Minimap = preload("res://src/ui/minimap.gd")
const Saves = preload("res://src/core/save_store.gd")
const SaveManager = preload("res://src/core/save_management_038.gd")
var hud: CanvasLayer
var grid: GridContainer
var title_label: Label
var close_button: Button
var previews: Array = []

func setup(interface: CanvasLayer) -> void:
	hud = interface
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	add_theme_stylebox_override("panel", hud._style(Color("fffaf2"), 18, 22))
	var body: VBoxContainer = hud._vbox(self, 12)
	var header := HBoxContainer.new()
	body.add_child(header)
	title_label=hud._label(header, L.text("ECHTE BERGE · DEIN BETRIEB"), 27, hud.ACCENT)
	title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title_label.clip_text=true
	title_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	hud._spacer(header, false)
	close_button=hud._button(header, L.text("Zurück"), hide)
	hud._label(body, L.text("Vier reale Gebiete mit jeweils drei wählbaren Betriebsintensitäten. Geografie aus offenen Daten, Missionsereignisse sind spielerisch erfunden."), 17, hud.MUTED, true)
	var scroll := DragScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(grid)
	for id in Geo.IDS:
		var spec := Maps.spec(id)
		var geo := Geo.data(id)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", hud._style(Color("edf3ec"), 12, 15))
		grid.add_child(panel)
		var card: VBoxContainer = hud._vbox(panel, 8)
		hud._label(card, spec.name, 26, Color(spec.color))
		hud._label(card, L.text(["Sehr leicht", "Leicht", "Mittel", "Schwer"][Geo.IDS.find(id)]) + " · " + L.text(spec.subtitle), 18, hud.ACCENT, true)
		var preview := Minimap.new()
		preview.map_id = id
		preview.interactive = false
		preview.custom_minimum_size = Vector2(260, 140)
		card.add_child(preview)
		previews.append(preview)
		var tasks := ""
		for goal in Ops.GOALS[id]: tasks += "• " + L.text(goal) + "\n"
		hud._label(card, tasks.strip_edges(), 16, hud.INK, true)
		hud._label(card, L.text("%.1f km² · Datenstand %s · eigener Spielstand") % [Maps.area(id), str(geo.osm_timestamp).get_slice("T", 0)], 14, hud.MUTED, true)
		hud._label(card, L.text("24 Stunden · Personal & Schichten · Technik · Rettung · Abendgäste"), 14, hud.TEAL, true)
		hud._label(card, L.text("Maßstäbliche Berge · verkürzte Reisezeiten"), 14, hud.MUTED, true)
		var seed: Dictionary=Geo.baked(id)
		if not seed.is_empty():
			var pistes: Array=seed.get("pistes",[])
			var enabled: int=pistes.filter(func(p): return p.get("enabled",false)).size()
			hud._label(card,L.text("Geodatenprüfung: %d / %d importierte Pistenabschnitte als befahrbar markiert.") % [enabled,pistes.size()],14,hud.MUTED,true)
		var difficulty := OptionButton.new()
		for label in [L.text("Entspannt · weniger Ansturm"),L.text("Normal · klassischer Betrieb"),L.text("Experte · höhere Nachfrage")]:
			difficulty.add_item(label)
		difficulty.select(1)
		difficulty.custom_minimum_size.y=48
		card.add_child(difficulty)
		hud._button(card, L.text("Szenario öffnen / fortsetzen"), func():
			hud.game.enter_area(id,["relaxed","normal","expert"][difficulty.selected])
			hide()
		, true)
		if Saves.has_any_save(id):
			var drawer:=PanelContainer.new()
			drawer.add_theme_stylebox_override("panel",hud._style(Color("ffffff"),8,12))
			hud._button(card,L.text("Spielstand verwalten  ▾"),func():drawer.visible=not drawer.visible)
			card.add_child(drawer)
			var actions:VBoxContainer=hud._vbox(drawer,8)
			var report:Label=hud._label(actions,"",14,hud.TEAL,true)
			report.hide()
			hud._button(actions,L.text("Spielstand prüfen"),func():
				var result:Dictionary=SaveManager.inspect(id,1)
				report.show()
				report.text=L.text("%d Dateien · %d geprüft · %d ladbar · %d wiederherstellbar") % [result.files.size(),int(result.verified),int(result.loadable),int(result.recoverable)]
				if result.damaged:
					for entry in result.files:
						if str(entry.message)!="":report.text+="\n"+str(entry.name)+": "+str(entry.message)
			)
			hud._button(actions,L.text("Spielstand reparieren"),func():
				if hud.game.has_game and hud.game.model.map_id==id:
					hud.toast(L.text("Aktives Szenario: zuerst ein anderes Gebiet öffnen."))
					return
				var fixed:Dictionary=SaveManager.repair(id,1)
				hud.toast(str(fixed.message))
				if fixed.ok:report.hide()
			)
			drawer.hide()
	hud._label(body, "© OpenStreetMap contributors · ODbL 1.0 · Mapzen Terrain Tiles", 13, hud.MUTED, true)
	resized.connect(_fit_grid)
	_fit_grid()
	hide()

func _fit_grid() -> void:
	if grid==null:return
	var available: float=minf(get_viewport_rect().size.x,get_tree().root.size.x)
	var compact: bool=available<1060.0
	grid.columns=1 if compact else 2
	# The background must be opaque across the entire viewport, including
	# the mobile safe-area band; content padding lives inside the panel.
	offset_left=0
	offset_right=0
	offset_top=0
	offset_bottom=0
	if is_instance_valid(title_label):
		title_label.add_theme_font_size_override("font_size",18 if available<650.0 else 24 if compact else 27)
	if is_instance_valid(close_button):
		close_button.text="✕" if available<650.0 else L.text("Zurück")
		close_button.tooltip_text=L.text("Zurück")
		close_button.custom_minimum_size.x=48 if available<650.0 else 0
	for preview in previews:
		if is_instance_valid(preview):
			preview.custom_minimum_size=Vector2(minf(260.0,maxf(140.0,available-96.0)),110 if available<650.0 else 140)

func open() -> void:
	hud.game._clear_input()
	_fit_grid()
	show()
