extends VBoxContainer
## Five actual timed touch rounds, measured with monotonic elapsed time.
## This optional arcade game cannot alter resort cash or career progress.
const L = preload("res://src/core/i18n.gd")
const Styles = preload("res://src/core/visual_styles.gd")
var style_id := "alpine"
var phase := "idle"
var samples: Array[float] = []
var _remaining := 0.0
var _elapsed := 0.0
var _go_at:=0
var _button := Button.new()
var _message := Label.new()
var _score := Label.new()
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	name = "reaction_game"
	_button.name = "reaction_button"
	_rng.randomize()
	add_theme_constant_override("separation", 10)
	var palette: Dictionary = Styles.ui_palette(style_id)
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(str(palette.panel))
	box.border_color = Color(str(palette.outline))
	box.set_border_width_all(2)
	box.set_corner_radius_all(clampi(int(palette.corner),0,18))
	box.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel",box)
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	panel.add_child(body)
	var title := Label.new()
	title.text = L.text("REAKTION · FÜNF ECHTE STARTRUNDEN")
	title.add_theme_font_size_override("font_size",19)
	title.add_theme_color_override("font_color",Color(str(palette.ink)))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(title)
	for label in [_message,_score]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color",Color(str(palette.ink)))
		label.add_theme_font_size_override("font_size",16)
	body.add_child(_message)
	_button.custom_minimum_size = Vector2(0,76)
	_button.add_theme_font_size_override("font_size",22)
	_button.pressed.connect(press)
	body.add_child(_button)
	body.add_child(_score)
	reset()

func reset() -> void:
	phase = "idle"
	samples.clear()
	_score.text = ""
	_message.text = L.text("Warte auf LOS und tippe dann. Zu frühes Tippen zählt als Fehlstart. Ohne Einsatz oder Geldprämie.")
	_button.text = L.text("Reaktion starten")

func _begin() -> void:
	phase = "waiting"
	_remaining = _rng.randf_range(0.9,2.8)
	_elapsed = 0.0
	_button.text = L.text("WARTEN …")
	_message.text = L.text("Runde %d von 5 · erst bei LOS tippen") % (samples.size()+1)

func press() -> void:
	if phase == "idle" or phase == "next": _begin()
	elif phase == "done": reset(); _begin()
	elif phase == "waiting": _finish(1500.0, true)
	elif phase == "go": _finish(clampf(float(Time.get_ticks_usec()-_go_at)/1000.0,0.0,1500.0),false)

func _finish(milliseconds: float, early: bool) -> void:
	samples.append(milliseconds)
	phase = "done" if samples.size() == 5 else "next"
	_message.text = L.text("Fehlstart · 1500 ms") if early else L.text("Deine Reaktion: %.0f ms") % milliseconds
	_button.text = L.text("Neue fünf Runden") if phase == "done" else L.text("Nächste Startrunde")
	if phase == "done":
		var ordered: Array[float] = samples.duplicate()
		ordered.sort()
		_score.text = L.text("Fertig · Median %.0f ms · beste Runde %.0f ms") % [ordered[2],ordered[0]]
	else: _score.text = L.text("%d von 5 Runden abgeschlossen") % samples.size()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		# Closing or changing tabs never creates an invisible timed challenge.
		if phase in ["waiting","go"]:
			phase = "next"
			_button.text = L.text("Startrunde wiederholen")
		return
	if phase == "waiting":
		_remaining -= delta
		if _remaining <= 0:
			phase = "go"
			_elapsed = 0.0
			_go_at=Time.get_ticks_usec()
			_button.text = L.text("LOS · JETZT TIPPEN")
	elif phase == "go":
		_elapsed = float(Time.get_ticks_usec()-_go_at)/1000000.0
		if _elapsed >= 1.5: _finish(1500.0,false)

func _notification(what:int)->void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT] and phase in ["waiting","go"]:
		phase="next"
		_button.text=L.text("Startrunde wiederholen")
