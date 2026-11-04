extends VBoxContainer
## Real touch-driven mini board. The resort simulation is paused by its parent
## building interior; a match never creates revenue or edits a career save.
const Rules = preload("res://src/core/tic_tac_toe.gd")
const Styles = preload("res://src/core/visual_styles.gd")
const L = preload("res://src/core/i18n.gd")

var style_id: String = "alpine"
var _match: Dictionary = {}
var _cells: Array[Button] = []
var _message: Label
var _results: Label
var _wins := 0
var _draws := 0
var _losses := 0
var _round := 0

## WCAG-style text contrast against the *actual* in-game backdrop, not
## against the light surrounding building window. UI colours are sRGB.
static func contrast_ratio(foreground: Color, background: Color) -> float:
	var a: Color = foreground.srgb_to_linear()
	var b: Color = background.srgb_to_linear()
	var light_a: float = 0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b
	var light_b: float = 0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b
	return (maxf(light_a, light_b) + 0.05) / (minf(light_a, light_b) + 0.05)

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var palette: Dictionary = Styles.ui_palette(style_id)
	var ink: Color = Color(str(palette.ink))
	var accent: Color = Color(str(palette.accent))
	var base: Color = Color(str(palette.panel))
	var outline: Color = Color(str(palette.outline))
	var highlight: Color = Color(str(palette.highlight))
	var corner: int = clampi(int(palette.corner), 0, 18)
	var title_color: Color = accent if contrast_ratio(accent, base) >= 4.5 else ink
	# The page hosting this game can be bright even when its chosen visual
	# theme expects light type on a dark surface. Keep board and labels together
	# on their real themed background, with safe interior padding.
	var surface := PanelContainer.new()
	surface.name = "arcade_surface"
	surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var surface_style := StyleBoxFlat.new()
	surface_style.bg_color = base
	surface_style.border_color = outline
	surface_style.set_border_width_all(2)
	surface_style.set_corner_radius_all(corner)
	surface_style.set_content_margin_all(15.0)
	surface_style.shadow_color = Color(str(palette.shadow))
	surface_style.shadow_size = clampi(int(palette.depth), 0, 9)
	surface_style.shadow_offset = Vector2(0, 2)
	surface.add_theme_stylebox_override("panel", surface_style)
	add_child(surface)
	var content := VBoxContainer.new()
	content.name = "arcade_content"
	content.add_theme_constant_override("separation", 11)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface.add_child(content)

	var caption := Label.new()
	caption.name = "arcade_title"
	caption.text = L.text("TIC-TAC-TOE · DU GEGEN DEN COMPUTER")
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_color_override("font_color", title_color)
	caption.add_theme_font_size_override("font_size", 19)
	content.add_child(caption)
	_message = Label.new()
	_message.name = "arcade_instructions"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", ink)
	_message.add_theme_font_size_override("font_size", 18)
	content.add_child(_message)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(grid)
	for index in range(9):
		var square := Button.new()
		square.name = "square_%d" % index
		square.custom_minimum_size = Vector2(76,76)
		square.focus_mode = Control.FOCUS_NONE
		square.add_theme_font_size_override("font_size", 38)
		square.add_theme_color_override("font_color", title_color)
		var hover_ink: Color = ink if contrast_ratio(ink, highlight) >= 4.5 else Color.BLACK if contrast_ratio(Color.BLACK, highlight) > contrast_ratio(Color.WHITE, highlight) else Color.WHITE
		square.add_theme_color_override("font_hover_color", hover_ink)
		var rest := StyleBoxFlat.new()
		rest.bg_color = base
		rest.border_color = outline
		rest.set_border_width_all(2)
		rest.set_corner_radius_all(corner)
		square.add_theme_stylebox_override("normal", rest)
		var hover: StyleBoxFlat = rest.duplicate() as StyleBoxFlat
		hover.bg_color = highlight
		square.add_theme_stylebox_override("hover", hover)
		square.add_theme_stylebox_override("pressed", hover)
		var blocked: StyleBoxFlat = rest.duplicate() as StyleBoxFlat
		blocked.bg_color = base
		square.add_theme_stylebox_override("disabled", blocked)
		square.add_theme_color_override("font_disabled_color", title_color)
		square.pressed.connect(_play.bind(index))
		grid.add_child(square)
		_cells.append(square)

	_results = Label.new()
	_results.name = "arcade_score"
	_results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_results.add_theme_color_override("font_color", ink)
	_results.add_theme_font_size_override("font_size", 16)
	content.add_child(_results)
	var retry := Button.new()
	retry.name = "arcade_replay"
	retry.text = L.text("Neue Runde")
	retry.custom_minimum_size.y = 52
	retry.pressed.connect(restart)
	content.add_child(retry)
	restart()

func restart() -> void:
	_round += 1
	_match = Rules.fresh(_round * 11 + 3)
	_refresh()

func _play(index: int) -> void:
	if not Rules.play(_match,index).ok: return
	if bool(_match.finished):
		match str(_match.winner):
			"X": _wins += 1
			"O": _losses += 1
			"draw": _draws += 1
	_refresh()

func _refresh() -> void:
	for i in range(_cells.size()):
		var mark: String = str(_match.cells[i])
		_cells[i].text = "✕" if mark=="X" else "◯" if mark=="O" else ""
		_cells[i].disabled = mark!="" or bool(_match.finished)
	match str(_match.winner):
		"X": _message.text = L.text("Gewonnen! Du hast drei Zeichen in einer Reihe.")
		"O": _message.text = L.text("Der Computer gewinnt. Noch eine Runde?")
		"draw": _message.text = L.text("Unentschieden! Das Spielfeld ist voll.")
		_: _message.text = L.text("Setze dein X. Drei in einer Reihe gewinnen.")
	_results.text = L.text("Siege %d · Remis %d · Niederlagen %d") % [_wins, _draws, _losses]
