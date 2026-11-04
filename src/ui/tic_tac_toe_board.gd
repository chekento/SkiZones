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

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	var palette: Dictionary = Styles.ui_palette(style_id)
	var ink: Color = Color(str(palette.ink))
	var accent: Color = Color(str(palette.accent))
	var base: Color = Color(str(palette.panel))
	var outline: Color = Color(str(palette.outline))
	var highlight: Color = Color(str(palette.highlight))
	var corner: int = clampi(int(palette.corner), 0, 18)

	var caption := Label.new()
	caption.text = L.text("TIC-TAC-TOE · DU GEGEN DEN COMPUTER")
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_color_override("font_color", accent)
	caption.add_theme_font_size_override("font_size", 19)
	add_child(caption)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", ink)
	_message.add_theme_font_size_override("font_size", 18)
	add_child(_message)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(grid)
	for index in range(9):
		var square := Button.new()
		square.name = "square_%d" % index
		square.custom_minimum_size = Vector2(76,76)
		square.focus_mode = Control.FOCUS_NONE
		square.add_theme_font_size_override("font_size", 38)
		square.add_theme_color_override("font_color", accent)
		square.add_theme_color_override("font_hover_color", ink)
		var rest := StyleBoxFlat.new()
		rest.bg_color = base
		rest.border_color = outline
		rest.set_border_width_all(2)
		rest.set_corner_radius_all(corner)
		square.add_theme_stylebox_override("normal", rest)
		var hover: StyleBoxFlat = rest.duplicate()
		hover.bg_color = highlight
		square.add_theme_stylebox_override("hover", hover)
		square.add_theme_stylebox_override("pressed", hover)
		var blocked: StyleBoxFlat = rest.duplicate()
		blocked.bg_color = base
		square.add_theme_stylebox_override("disabled", blocked)
		square.add_theme_color_override("font_disabled_color",accent)
		square.pressed.connect(_play.bind(index))
		grid.add_child(square)
		_cells.append(square)

	_results = Label.new()
	_results.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_results.add_theme_color_override("font_color", ink)
	_results.add_theme_font_size_override("font_size", 16)
	add_child(_results)
	var retry := Button.new()
	retry.text = L.text("Neue Runde")
	retry.custom_minimum_size.y = 52
	retry.pressed.connect(restart)
	add_child(retry)
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
