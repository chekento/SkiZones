extends PanelContainer
const L=preload("res://src/core/i18n.gd")
const DragScroll=preload("res://src/ui/drag_scroll.gd")
var hud: CanvasLayer
var status: Label
var action: Button
var check_button: Button
var bar: ProgressBar
func setup(interface: CanvasLayer) -> void:
	hud=interface
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left=70;offset_right=-70;offset_top=110;offset_bottom=-50
	add_theme_stylebox_override("panel",hud._style(Color("fffaf2"),18,24))
	var scroll:=DragScroll.new();add_child(scroll)
	var body: VBoxContainer=hud._vbox(scroll,16);body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var row:=HBoxContainer.new();body.add_child(row)
	hud._label(row,L.text("SKIZONES AKTUALISIEREN"),26,hud.ACCENT);hud._spacer(row,false);hud._button(row,L.text("Zurück"),hide)
	hud._label(body,L.text("Updates kommen direkt aus dem SkiZones-Projekt auf GitHub. Deine Karrieren, Resorts und Einstellungen bleiben gespeichert."),19,hud.INK,true)
	status=hud._label(body,"",19,hud.TEAL,true)
	bar=ProgressBar.new();bar.custom_minimum_size.y=28;body.add_child(bar)
	action=hud._button(body,"",_act,true)
	check_button=hud._button(body,L.text("Nach Updates suchen"),func():hud.game.updater.check())
	hud._button(body,L.text("Veröffentlichungen auf GitHub ansehen"),func():OS.shell_open(hud.game.updater.Catalog.RELEASES))
	hud._label(body,L.text("Android fragt vor der Installation nach deiner Bestätigung. Behalte die vorhandene App installiert, damit dein Fortschritt erhalten bleibt."),16,hud.MUTED,true)
	hud.game.updater.changed.connect(refresh);refresh();hide()
func open() -> void:
	hud.game._clear_input();refresh();show()
	if hud.game.updater.state=="idle":hud.game.updater.check()
func refresh() -> void:
	var updater: Node=hud.game.updater
	if is_instance_valid(hud.updates_button):hud.updates_button.text=L.text("Updates · %s verfügbar") % updater.candidate.version if updater.state in ["available","ready","permission","downloading"] else L.text("Updates · Spielstände behalten")
	status.text=L.text("Installierte Version: %s") % updater.installed_version+"\n\n"+(updater.message if updater.message!="" else L.text("Suche nach einer neuen Version, wenn du verbunden bist."))
	bar.visible=updater.state=="downloading";bar.value=updater.progress
	action.visible=updater.state in ["available","ready","permission"]
	action.text=L.text("Update herunterladen") if updater.state=="available" else L.text("Installieren")
	check_button.disabled=updater.state in ["checking","downloading"]
func _act() -> void:
	if hud.game.updater.state=="available":hud.game.updater.download()
	else:hud.game.updater.install()
