extends Control
## Small transparent digital achievement banner. Layout is bound to the usable
## HUD safe rectangle, with native word-wrapping and no title truncation.
## All children ignore mouse and touch input: gameplay remains interactive.
const VisualStyles = preload("res://src/core/visual_styles.gd")
const DISPLAY_SECONDS := 5.4
const MAX_QUEUE := 12
var waiting: Array = []
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
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

func announce(event: Dictionary) -> void:
	if not event.has("title") or not event.has("kind"): return
	if waiting.size() >= MAX_QUEUE: waiting.pop_front()
	waiting.append(event.duplicate(true))
	if active.is_empty(): _next()

func _next() -> void:
	if waiting.is_empty():
		active.clear()
		set_process(false)
		hide()
		return
	active = waiting.pop_front()
	elapsed = 0.0
	kicker.text = "✦  MASTERY LEVEL" if str(active.get("kind","")) == "rank" else "✦  ACHIEVEMENT UNLOCKED"
	headline.text = str(active.get("title",""))
	var extra := str(active.get("detail",""))
	if int(active.get("reward",0)) > 0:
		extra += ("   " if not extra.is_empty() else "") + "+%d €" % int(active.reward)
	detail.text = extra
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
	card.size = Vector2(_card_width,0.0)
	var min_height: float = card.get_combined_minimum_size().y
	var usable_height: float = maxf(45.0,size.y - 12.0)
	card.size = Vector2(_card_width,minf(usable_height,maxf(72.0,min_height)))
	_card_top = clampf(size.y * (0.16 if narrow else 0.19),6.0,maxf(6.0,size.y-card.size.y-6.0))
	_refresh_motion()

func _refresh_motion() -> void:
	if active.is_empty(): return
	var progress := clampf(elapsed/DISPLAY_SECONDS,0.0,1.0)
	var fade := minf(clampf(progress*8.0,0.0,1.0),clampf((1.0-progress)*7.0,0.0,1.0))
	card.position = Vector2((size.x-card.size.x)*0.5,_card_top + 9.0*(1.0-fade))
	card.modulate.a = fade

func _process(delta: float) -> void:
	elapsed += maxf(0.0,delta)
	if elapsed >= DISPLAY_SECONDS: _next()
	else: _refresh_motion()
