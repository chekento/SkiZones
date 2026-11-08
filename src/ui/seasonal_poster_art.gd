extends Control
## Original, responsive holiday artwork. Used whenever the optional custom
## poster images are absent; both campaigns have actual distinct illustrations.
const Styles=preload("res://src/core/visual_styles.gd")
const L=preload("res://src/core/i18n.gd")
const Posters=preload("res://src/core/seasonal_billboards_040.gd")
var style_id: String="alpine"
var campaign: String="christmas"
var variant: int=0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x<=0.0 or size.y<=0.0:return
	var palette: Dictionary=Styles.ui_palette(style_id)
	var accent:=Color(str(palette.accent))
	var night:=Color("0c163d") if campaign=="new_year" else Color("142b43")
	var glow:=Color("ffe7b3") if campaign=="new_year" else Color("edf9ec")
	if style_id=="monochrome":
		night=Color("252525")
		glow=Color.WHITE
	var w: float=size.x
	var h: float=size.y
	draw_rect(Rect2(Vector2.ZERO,size),night)
	draw_rect(Rect2(9,9,w-18,h-18),accent,false,maxf(2.0,w*.007))
	var ridge:=PackedVector2Array([Vector2(0,h*.79),Vector2(w*.18,h*.51),Vector2(w*.35,h*.76),Vector2(w*.60,h*.39),Vector2(w*.83,h*.71),Vector2(w,h*.55),Vector2(w,h),Vector2(0,h)])
	draw_colored_polygon(ridge,accent.darkened(0.48))
	draw_colored_polygon(PackedVector2Array([Vector2(w*.60,h*.39),Vector2(w*.68,h*.55),Vector2(w*.52,h*.54)]),glow)
	if campaign=="new_year":
		for burst in range(4):
			var center:=Vector2(w*(.16+float(burst)*.23),h*(.18+float(burst%2)*.12))
			for ray in range(16):
				var theta:=float(ray)*TAU/16.0
				var heading:=Vector2.from_angle(theta)
				draw_line(center+heading*w*.025,center+heading*w*.092,glow,2.0)
	else:
		for i in range(65):
			var point:=Vector2(12.0+fposmod(float(i*97+variant*37),maxf(w-24,1.0)),12.0+fposmod(float(i*53+variant*19),maxf(h*.65,1.0)))
			draw_circle(point,1.4+float(i%3)*.65,glow)
	var design: Array=Posters.DESIGNS.get(campaign,Posters.DESIGNS.christmas)[posmod(variant,4)]
	var words: Array=["SKIZONES",str(design[0]),str(design[1])]
	var font: Font=get_theme_default_font()
	if font==null:return
	var font_size:=clampi(roundi(w*.071),23,60)
	for word in words:
		while font_size>17 and font.get_string_size(L.text(word),HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>w-40:
			font_size-=1
	for idx in range(words.size()):
		draw_string(font,Vector2(12,h*.24+float(idx)*font_size*1.18),L.text(str(words[idx])),HORIZONTAL_ALIGNMENT_CENTER,roundi(w-24),font_size,glow)
	var footer:=L.text("1. NOVEMBER – 26. DEZEMBER") if campaign=="christmas" else L.text("27. DEZEMBER – 1. JANUAR")
	var sub_size:=clampi(roundi(w*.031),12,26)
	draw_string(font,Vector2(10,h*.81),footer,HORIZONTAL_ALIGNMENT_CENTER,roundi(w-20),sub_size,glow)
	draw_string(font,Vector2(10,h*.88),L.text("SKIZONES · WINTER AM BERG"),HORIZONTAL_ALIGNMENT_CENTER,roundi(w-20),sub_size,glow)
