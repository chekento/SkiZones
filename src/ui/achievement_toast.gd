extends Control
## Small transparent digital achievement banner. Layout is bound to the usable
## HUD safe rectangle, with native word-wrapping and no title truncation.
## All children ignore mouse and touch input: gameplay remains interactive.
const VisualStyles = preload("res://src/core/visual_styles.gd")
const L = preload("res://src/core/i18n.gd")
const DISPLAY_SECONDS := 5.4
const MAX_QUEUE := 12
const MAX_HISTORY := 40
const EVENT_DURATIONS := {"music":3.8,"mission":6.3,"medal":6.8,"warning":7.4,"repair":4.8,"finance":5.8,"achievement":5.4,"rank":5.4,"poster":4.8}
const EVENT_PRIORITIES := {"warning":100,"mission":95,"medal":90,"achievement":80,"rank":80,"repair":55,"finance":50,"music":10,"poster":76}
var waiting: Array = []
var history: Array = []
var reserved_top := 0.0
var _current_duration := DISPLAY_SECONDS
var active: Dictionary = {}
var elapsed := 0.0
var style_id := "alpine"
var card := PanelContainer.new()
var content := VBoxContainer.new()
var kicker := Label.new()
var accent_bar := ColorRect.new()
var headline := Label.new()
var detail := Label.new()
var _card_top := 0.0
var _card_width := 0.0
var _headline_full := ""
var _detail_full := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = false
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.clip_contents = false
	add_child(card)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation",5)
	card.add_child(content)
	for line in [kicker,headline,detail]:
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.clip_text = false
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kicker.add_theme_font_size_override("font_size",11)
	content.add_child(kicker)
	accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent_bar.custom_minimum_size.y = 2
	content.add_child(accent_bar)
	content.add_child(headline)
	content.add_child(detail)
	resized.connect(_reflow)
	_apply_style()
	set_process(false)
	hide()

func set_visual_style(id: String) -> void:
	var chosen := VisualStyles.valid(id)
	if chosen != style_id:
		style_id = chosen
		_apply_style()
		_reflow()

## One safe notification channel for achievement, radio, missions and operations.
## No event is clickable, preventing accidental piste/landscape taps on Android.
static func priority(kind: String) -> int:
	return int(EVENT_PRIORITIES.get(kind, 35))

static func duration(kind: String) -> float:
	return float(EVENT_DURATIONS.get(kind, DISPLAY_SECONDS))

static func caption(kind: String) -> String:
	match kind:
		"rank": return L.text("✦  MEISTERSCHAFTSRANG")
		"achievement": return L.text("✦  ACHIEVEMENT FREIGESCHALTET")
		"poster": return L.text("✦  PLAKAT ENTDECKT")
		"medal": return L.text("◆  SZENARIOMEDAILLE")
		"mission": return L.text("✓  MISSION ABGESCHLOSSEN")
		"music": return L.text("♫  JETZT IM RADIO")
		"warning": return L.text("!  RESORT-WARNUNG")
		"repair": return L.text("⚒  WIEDER EINSATZBEREIT")
		"finance": return L.text("€  RESORT-FINANZEN")
	return L.text("◆  RESORT-MELDUNG")

static func same_event(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("kind","")) == str(b.get("kind","")) and str(a.get("title","")) == str(b.get("title","")) and str(a.get("detail","")) == str(b.get("detail",""))

func announce(event: Dictionary) -> void:
	if not event.has("title") or not event.has("kind") or str(event.title).strip_edges().is_empty(): return
	var incoming: Dictionary = event.duplicate(true)
	if not active.is_empty() and same_event(active,incoming): return
	if waiting.any(func(item): return same_event(item,incoming)): return
	# An urgent mission is never buried underneath ten station changes.
	var insert_at := waiting.size()
	for index in range(waiting.size()):
		if priority(str(incoming.kind)) > priority(str(waiting[index].kind)):
			insert_at=index
			break
	waiting.insert(insert_at,incoming)
	if waiting.size() > MAX_QUEUE: waiting.pop_back()
	if not waiting.has(incoming) and not active.is_empty(): return
	history.push_front(incoming.duplicate(true))
	if history.size() > MAX_HISTORY: history.resize(MAX_HISTORY)
	if active.is_empty(): _next()

func clear_all() -> void:
	waiting.clear()
	active.clear()
	elapsed=0.0
	hide()
	set_process(false)

func set_reserved_top(value: float) -> void:
	if absf(value-reserved_top) < 1.0: return
	reserved_top=maxf(0.0,value)
	_reflow()

func _next() -> void:
	if waiting.is_empty():
		active.clear()
		set_process(false)
		hide()
		return
	active = waiting.pop_front()
	elapsed = 0.0
	_current_duration = duration(str(active.get("kind","")))
	kicker.text = caption(str(active.get("kind","")))
	_headline_full = str(active.get("title",""))
	var extra := str(active.get("detail",""))
	if int(active.get("reward",0)) > 0:
		extra += ("   " if not extra.is_empty() else "") + "+%d €" % int(active.reward)
	_detail_full = extra
	detail.visible = not extra.is_empty()
	_reflow()
	show()
	set_process(true)
	_refresh_motion()

func _apply_style() -> void:
	var ui: Dictionary = VisualStyles.ui_palette(style_id)
	var primary := Color(str(ui.accent))
	var border := primary.lightened(0.20)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.045,0.105,0.15,0.76)
	panel.border_color = Color(border,0.68)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(15)
	panel.set_content_margin_all(14)
	panel.shadow_color = Color(0.01,0.02,0.03,0.20)
	panel.shadow_size = 4
	panel.shadow_offset = Vector2(0,3)
	card.add_theme_stylebox_override("panel",panel)
	kicker.add_theme_color_override("font_color",Color(primary.lightened(0.27),0.95))
	headline.add_theme_color_override("font_color",Color("f0faf9"))
	detail.add_theme_color_override("font_color",Color("c8e6e2"))
	accent_bar.color = Color(primary,0.72)

## Pre-wrap using a measured pixel width. Godot can otherwise calculate
## container minimum height with an unallocated (zero-width) label and force
## thousands of pixels of height before the first frame.
func _wrap_to_width(value: String, limit: float, font_size: int) -> String:
	if value.is_empty(): return ""
	var font: Font = get_theme_default_font()
	if font == null: return value
	var lines := PackedStringArray()
	var running := ""
	var words := value.replace("\n"," ").split(" ",false)
	for part in words:
		var word: String = str(part)
		var proposed: String = word if running.is_empty() else running + " " + word
		if font.get_string_size(proposed,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x <= limit:
			running = proposed
			continue
		if not running.is_empty():
			lines.append(running)
			running = ""
		var fragment := ""
		for index in range(word.length()):
			var glyph: String = word.substr(index,1)
			if not fragment.is_empty() and font.get_string_size(fragment+glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > limit:
				lines.append(fragment)
				fragment = ""
			fragment += glyph
		running = fragment
	if not running.is_empty(): lines.append(running)
	return "\n".join(lines)

func _reflow() -> void:
	if not is_inside_tree() or size.x <= 0.0 or size.y <= 0.0:return
	var narrow: bool = size.x < 640.0 or size.y < 480.0
	var tiny: bool = size.x < 355.0 or size.y < 320.0
	var headline_size := 16 if tiny else 19 if narrow else 23
	var detail_size := 12 if tiny else 14 if narrow else 16
	headline.add_theme_font_size_override("font_size",headline_size)
	detail.add_theme_font_size_override("font_size",detail_size)
	kicker.add_theme_font_size_override("font_size",10 if tiny else 11)
	_card_width = minf(620.0,maxf(100.0,size.x - (16.0 if tiny else 28.0)))
	headline.text = _wrap_to_width(_headline_full,maxf(65.0,_card_width-34.0),headline_size)
	detail.text = _wrap_to_width(_detail_full,maxf(65.0,_card_width-34.0),detail_size)
	card.size = Vector2(_card_width,0.0)
	var min_height: float = card.get_combined_minimum_size().y
	var usable_height: float = maxf(45.0,size.y - 12.0)
	card.size = Vector2(_card_width,minf(usable_height,maxf(72.0,min_height)))
	# Prefer the original achievement position, except when the scenario
	# progress panel occupies the same area. Then drop below it.
	_card_top = clampf(maxf(size.y * (0.16 if narrow else 0.19),reserved_top + (8.0 if reserved_top > 0.0 else 0.0)),6.0,maxf(6.0,size.y-card.size.y-6.0))
	_refresh_motion()

func _refresh_motion() -> void:
	if active.is_empty(): return
	var progress := clampf(elapsed/maxf(0.1,_current_duration),0.0,1.0)
	var fade := minf(clampf(progress*8.0,0.0,1.0),clampf((1.0-progress)*7.0,0.0,1.0))
	card.position = Vector2((size.x-card.size.x)*0.5,_card_top + 9.0*(1.0-fade))
	card.modulate.a = fade

func _process(delta: float) -> void:
	elapsed += maxf(0.0,delta)
	if elapsed >= _current_duration: _next()
	else: _refresh_motion()
