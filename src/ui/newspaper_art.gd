extends Control
## Editorial vector masthead. Resizes without losing text and shares the
## exact world palette; scenery silhouettes are original procedural artwork.
const Styles = preload("res://src/core/visual_styles.gd")
const L = preload("res://src/core/i18n.gd")
var style_id := "alpine"
var edition_day := 1
var district := "Alpen"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0,215)
	resized.connect(queue_redraw)

func setup(style: String, day: int, region: String) -> void:
	style_id = Styles.valid(style)
	edition_day = maxi(1,day)
	district = region
	queue_redraw()

func _draw() -> void:
	if size.x < 30 or size.y < 120:return
	var use_dark: bool = style_id in ["neon_noir","aurora_ink"]
	var paper := Color("172137") if use_dark else Color("faf1dc")
	var ink := Color("edfaff") if use_dark else Color("273848")
	var accent := Color(str(Styles.ui_palette(style_id).accent))
	var thin := accent if use_dark else Color("8f795d")
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(Vector2.ZERO,size),paper)
	draw_rect(Rect2(7,7,maxf(1,w-14),maxf(1,h-14)),thin,false,2)
	draw_rect(Rect2(12,13,maxf(1,w-24),5),accent)
	var font: Font = get_theme_default_font()
	if font == null: return
	var masthead: String = L.text("DAS ALPEN-EXTRABLATT")
	var title_size := clampi(roundi(w/22.0),22,40)
	while title_size > 18 and font.get_string_size(masthead,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x > w-34:
		title_size -= 1
	var subtitle_size := clampi(roundi(w/44.0),11,15)
	draw_string(font,Vector2(w*0.5,46),L.text("SEIT DEM ERSTEN SKITAG  ·  STIMME DER BERGE"),HORIZONTAL_ALIGNMENT_CENTER,roundi(w-35),subtitle_size,thin)
	draw_string(font,Vector2(w*0.5,92),masthead,HORIZONTAL_ALIGNMENT_CENTER,roundi(w-28),title_size,ink)
	draw_line(Vector2(21,102),Vector2(w-21,102),accent,3)
	draw_line(Vector2(21,107),Vector2(w-21,107),thin,1)
	# A miniature hand-inked mountain panorama with expressive contour lines.
	var ridge := PackedVector2Array([
		Vector2(19,h-31),Vector2(w*.16,h-66),Vector2(w*.27,h-45),
		Vector2(w*.40,h-95),Vector2(w*.51,h-55),
		Vector2(w*.67,h-90),Vector2(w*.82,h-56),Vector2(w-19,h-39),
		Vector2(w-19,h-24),Vector2(19,h-24)])
	draw_colored_polygon(ridge,accent.darkened(0.45) if use_dark else accent.lightened(0.28))
	for i in range(3):
		var yy: float=h-25-float(i)*8.0
		draw_line(Vector2(20,yy),Vector2(w-20,yy),thin,1)
	draw_string(font,Vector2(28,h-9),L.text("BETRIEBSTAG %d") % edition_day,HORIZONTAL_ALIGNMENT_LEFT,roundi(w-54),13,ink)
	draw_string(font,Vector2(w-22,h-9),district.to_upper(),HORIZONTAL_ALIGNMENT_RIGHT,roundi(w-54),13,ink)
