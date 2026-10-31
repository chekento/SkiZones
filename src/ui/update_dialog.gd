extends PanelContainer
const L=preload("res://src/core/i18n.gd")
const DragScroll=preload("res://src/ui/drag_scroll.gd")
var hud: CanvasLayer
var status: Label
var action: Button
var check_button: Button
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
	action=hud._button(body,"",_act,true)
	check_button=hud._button(body,L.text("Nach Updates suchen"),func():hud.game.updater.check())
	hud._button(body,L.text("Veröffentlichungen auf GitHub ansehen"),func():OS.shell_open(hud.game.updater.Catalog.RELEASES))
	hud._label(body,L.text("SkiZones prüft nur die Versionsinformationen. Download und Installation erfolgen über deinen Browser und Android. Die vorhandene App installiert lassen, damit dein Fortschritt erhalten bleibt."),16,hud.MUTED,true)
	hud.game.updater.changed.connect(refresh);refresh();hide()
func open() -> void:
	hud.game._clear_input();refresh();show()
	if hud.game.updater.state=="idle":hud.game.updater.check()
func refresh() -> void:
	var updater: Node=hud.game.updater
	if is_instance_valid(hud.updates_button):hud.updates_button.text=L.text("Updates · %s verfügbar") % updater.candidate.version if updater.state in ["available","opened"] else L.text("Updates · Spielstände behalten")
	status.text=L.text("Installierte Version: %s") % updater.installed_version+"\n\n"+(updater.message if updater.message!="" else L.text("Suche nach einer neuen Version, wenn du verbunden bist."))
	action.visible=updater.state in ["available","opened"]
	action.text=L.text("GitHub-Download im Browser öffnen")
	check_button.disabled=updater.state=="checking"
func _act() -> void:
	hud.game.updater.open_download()
