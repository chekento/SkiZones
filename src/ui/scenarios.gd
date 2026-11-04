extends PanelContainer
const L = preload("res://src/core/i18n.gd")
const Geo = preload("res://src/core/real_resorts.gd")
const Maps = preload("res://src/core/maps.gd")
const Ops = preload("res://src/core/operations.gd")
const DragScroll = preload("res://src/ui/drag_scroll.gd")
const Minimap = preload("res://src/ui/minimap.gd")
var hud: CanvasLayer
var grid: GridContainer

func setup(interface: CanvasLayer) -> void:
	hud = interface
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 38
	offset_right = -38
	offset_top = 34
	offset_bottom = -34
	add_theme_stylebox_override("panel", hud._style(Color("fffaf2"), 18, 22))
	var body: VBoxContainer = hud._vbox(self, 12)
	var header := HBoxContainer.new()
	body.add_child(header)
	hud._label(header, L.text("ECHTE BERGE · DEIN BETRIEB"), 27, hud.ACCENT)
	hud._spacer(header, false)
	hud._button(header, L.text("Zurück"), hide)
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
	hud._label(body, "© OpenStreetMap contributors · ODbL 1.0 · Mapzen Terrain Tiles", 13, hud.MUTED, true)
	resized.connect(_fit_grid)
	_fit_grid()
	hide()

func _fit_grid() -> void:
	if grid!=null: grid.columns=1 if size.x<930 else 2

func open() -> void:
	hud.game._clear_input()
	show()
