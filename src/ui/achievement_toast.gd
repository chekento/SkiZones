extends Control
## Compact, theme-reactive raised lettering instead of a steep semicircle.
## Presentation only: never captures input or changes rewards.
const VisualStyles = preload("res://src/core/visual_styles.gd")
const DISPLAY_SECONDS := 4.2
const MAX_QUEUE := 12
var waiting: Array = []
var active: Dictionary = {}
var elapsed := 0.0
var style_id := "alpine"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	hide()

func set_visual_style(id: String) -> void:
	var chosen := VisualStyles.valid(id)
	if chosen != style_id:
		style_id = chosen
		queue_redraw()

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
	show()
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DISPLAY_SECONDS: _next()
	else: queue_redraw()

func _faceted_rect(rect: Rect2, cut: float) -> PackedVector2Array:
	var l := rect.position.x
	var t := rect.position.y
	var r := rect.end.x
	var b := rect.end.y
	var c := clampf(cut, 1.0, minf(rect.size.x, rect.size.y)*0.20)
	return PackedVector2Array([Vector2(l+c,t),Vector2(r-c,t),Vector2(r,t+c),Vector2(r,b-c),Vector2(r-c,b),Vector2(l+c,b),Vector2(l,b-c),Vector2(l,t+c)])

func _raised_text(font: Font, value: String, center: Vector2, limit: float, base_size: int, color: Color, outline: Color, shadow: Color, depth: int, curve: float) -> void:
	if value.is_empty(): return
	var font_size := base_size
	while font_size > 18 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > limit:
		font_size -= 1
	var total := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var x := -total*0.5
	for i in range(value.length()):
		var letter := value.substr(i,1)
		var width_value := font.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var u := (x + width_value*0.5) / maxf(total,1.0)
		# Subtle smile: ~2px instead of a large circular text baseline.
		var y := curve * 17.0 * pow(absf(u)*2.0,2.0)
		var angle := curve * u * 0.21
		var at := center + Vector2(x + width_value*0.5,y)
		draw_set_transform(at,angle,Vector2.ONE)
		var origin := Vector2(-width_value*0.5,0)
		for z in range(depth,0,-1):
			draw_string(font,origin+Vector2(0,z),letter,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,shadow)
		draw_string_outline(font,origin,letter,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,outline)
		draw_string(font,origin,letter,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
		x += width_value
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw() -> void:
	if active.is_empty(): return
	var progress := clampf(elapsed / DISPLAY_SECONDS,0.0,1.0)
	var fade := minf(clampf(progress*7.0,0.0,1.0),clampf((1.0-progress)*6.0,0.0,1.0))
	var ui: Dictionary = VisualStyles.ui_palette(style_id)
	var primary := Color(str(ui.accent))
	var ink := Color(str(ui.ink))
	var border := Color(str(ui.outline))
	var panel := Color(str(ui.panel))
	var highlight := Color(str(ui.highlight))
	var depth := int(ui.depth)
	var width_value := minf(size.x*0.88,900.0)
	var height_value := minf(194.0,size.y*0.32)
	var box_rect := Rect2(Vector2((size.x-width_value)*0.5,size.y*0.24-height_value*0.15+12.0*(1-fade)),Vector2(width_value,height_value))
	var cut := float(ui.corner)
	var backing := box_rect.grow(5)
	backing.position.y += depth + 8
	draw_colored_polygon(_faceted_rect(backing,cut),Color(0.01,0.02,0.03,0.25*fade))
	draw_colored_polygon(_faceted_rect(box_rect.grow(4),cut),Color(border,fade*0.98))
	draw_colored_polygon(_faceted_rect(box_rect,cut),Color(panel,fade*0.95))
	var accent_rect := Rect2(box_rect.position + Vector2(14,14),Vector2(box_rect.size.x-28,5))
	draw_rect(accent_rect,Color(highlight,fade*0.9))
	var center := Vector2(box_rect.get_center().x,box_rect.position.y+box_rect.size.y*0.47)
	var headline := str(active.title).to_upper()
	if headline.length() > 44: headline = headline.substr(0,43)+"…"
	var font: Font = get_theme_default_font()
	var base_font := clampi(roundi(size.x/20.0),25,44)
	_raised_text(font,headline,center,width_value-44,base_font,Color(primary,fade),Color(border,fade),Color(ui.shadow,fade),depth,float(ui.letter_arc))
	var detail := str(active.get("detail",""))
	if int(active.get("reward",0)) > 0:
		detail += "   +%d €" % int(active.reward)
	var detail_size := clampi(roundi(size.x/41.0),17,24)
	draw_string_outline(font,Vector2(center.x,box_rect.end.y-30),detail,HORIZONTAL_ALIGNMENT_CENTER,roundi(width_value-40),detail_size,2,Color(border,fade))
	draw_string(font,Vector2(center.x,box_rect.end.y-30),detail,HORIZONTAL_ALIGNMENT_CENTER,roundi(width_value-40),detail_size,Color(ink,fade))
	# Restrained cinematic particles; the angular themes receive crisp facets.
	var sparkle_count := int(ui.sparkle)
	for index in range(sparkle_count):
		var phase := float(index)*2.39996
		var spread := Vector2(cos(phase),sin(phase))
		var p := box_rect.get_center() + spread*Vector2(width_value*0.56,height_value*0.71)
		var radius := 1.4 + 2.4 * fade * (0.5 + 0.5*sin(progress*12.0+index))
		if style_id in ["comic","cinematic","crisp"]:
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-radius*1.7),p+Vector2(radius,0),p+Vector2(0,radius*1.7),p+Vector2(-radius,0)]),Color(highlight,fade*0.85))
		else:
			draw_circle(p,radius,Color(highlight,fade*0.7))
