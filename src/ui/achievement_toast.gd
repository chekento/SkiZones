extends Control
## 0.22: curved, translucent reward lettering and short celebratory ribbons.
## Visual-only: never catches touches and never mutates campaign or money.
const DISPLAY_SECONDS := 3.6
const MAX_QUEUE := 12
var waiting: Array = []
var active: Dictionary = {}
var elapsed := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	hide()

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
	if elapsed >= DISPLAY_SECONDS:
		_next()
	else:
		queue_redraw()

func _arc_text(font: Font, value: String, origin: Vector2, radius: float, color: Color, size: int) -> void:
	if value.is_empty(): return
	var glyphs := value.length()
	var span := minf(2.16, float(glyphs) * 0.057)
	for i in range(glyphs):
		# The top of the semicircle is readable horizontally; edges fan out.
		var angle := -PI*0.5 + (-0.5 + (float(i)+0.5)/float(glyphs)) * span
		var point := origin + Vector2(cos(angle),sin(angle))*radius
		var glyph := value.substr(i,1)
		var glyph_width := font.get_string_size(glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		draw_set_transform(point,angle+PI*0.5,Vector2.ONE)
		draw_string(font,Vector2(-glyph_width*0.5,0.0),glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw() -> void:
	if active.is_empty(): return
	var progress := clampf(elapsed/DISPLAY_SECONDS,0.0,1.0)
	var fade_in := clampf(progress*6.0,0.0,1.0)
	var fade_out := clampf((1.0-progress)*5.0,0.0,1.0)
	var opacity := minf(fade_in,fade_out)
	var pulse := 1.0 + 0.085*sin(minf(1.0,progress*4.0)*PI)
	var center := Vector2(size.x*0.5, size.y*0.44 - 30.0 + 22.0*(1.0-opacity))
	var radius := minf(size.x*0.31,260.0)*pulse
	var tone := Color("bdeffe") if str(active.kind) == "rank" else Color("ffe5a9")
	var font: Font = get_theme_default_font()
	var text_size := clampi(roundi(minf(size.x/22.0,46.0)),25,46)
	var label: String = str(active.title).to_upper()
	# Limit the ribbon text only; the full title stays in the career ledger.
	if label.length() > 36: label = label.substr(0,35)+"…"
	draw_arc(center,radius,-PI*0.94,-PI*0.06,48,Color(tone,opacity*0.25),4.0,true)
	draw_arc(center,radius+16.0,-PI*0.88,-PI*0.12,36,Color(tone,opacity*0.12),1.7,true)
	_arc_text(font,label,center,radius,tone*Color(1,1,1,opacity),text_size)
	var subtitle := str(active.get("detail",""))
	if active.get("reward",0) > 0:
		subtitle += "   +%d €" % int(active.reward)
	var subtitle_color := Color(0.95,0.99,1.0,opacity*0.9)
	draw_string(font,center+Vector2(0,20),subtitle,HORIZONTAL_ALIGNMENT_CENTER,roundi(radius*1.9),22,subtitle_color)
	for index in range(7):
		var theta := -PI + float(index)*PI/6.0
		var sparkle := center+Vector2(cos(theta),sin(theta))*(radius+35.0+sin(progress*12+index)*5.0)
		draw_circle(sparkle,2.0+2.0*opacity,Color(tone,opacity*0.65))
