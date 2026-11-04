extends Control
## Original code-drawn fallback announcement when the previously authored
## Christmas poster has not yet been supplied as a game asset.
const Styles=preload("res://src/core/visual_styles.gd")
var style_id := "alpine"

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0: return
	var color: Dictionary=Styles.ui_palette(style_id)
	var accent := Color(str(color.accent))
	var dark := Color("192a42") if style_id != "bauhaus" else Color("183769")
	var w: float=size.x
	var h: float=size.y
	draw_rect(Rect2(Vector2.ZERO,size),dark)
	draw_rect(Rect2(9,9,w-18,h-18),accent,false,maxf(2.0,w*.007))
	# Mountains and frost make a crisp, legible poster without an external image.
	var peaks:=PackedVector2Array([Vector2(0,h*.75),Vector2(w*.20,h*.46),Vector2(w*.39,h*.72),
		Vector2(w*.57,h*.39),Vector2(w*.80,h*.69),Vector2(w,h*.5),Vector2(w,h),Vector2(0,h)])
	draw_colored_polygon(peaks,accent.darkened(.42))
	draw_colored_polygon(PackedVector2Array([Vector2(w*.20,h*.46),Vector2(w*.27,h*.57),Vector2(w*.15,h*.54)]),Color("eaf7f4"))
	draw_colored_polygon(PackedVector2Array([Vector2(w*.57,h*.39),Vector2(w*.65,h*.51),Vector2(w*.50,h*.50)]),Color("f1f9f5"))
	for i in range(24):
		var px: float=14.0+fposmod(float(i)*97.0,maxf(w-28,1.0))
		var py: float=16.0+fposmod(float(i)*53.0,maxf(h*.68,1.0))
		draw_circle(Vector2(px,py),1.3+(i%3)*.65,Color("f5f8ee",0.80))
	var font: Font=get_theme_default_font()
	if font==null: return
	var font_size:=clampi(roundi(w*.078),21,63)
	for line in ["WINTER","WUNDER","SKIZONES"]:
		while font_size>15 and font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>w-38:
			font_size-=1
	for i in range(3):
		draw_string(font,Vector2(w*.5,h*.20+float(i)*font_size*1.08),["WINTER","WUNDER","SKIZONES"][i],HORIZONTAL_ALIGNMENT_CENTER,roundi(w-24),font_size,Color("fff2d3"))
	var call_size:=clampi(roundi(w*.047),14,35)
	draw_string(font,Vector2(w*.5,h*.77),"AB 1. DEZEMBER",HORIZONTAL_ALIGNMENT_CENTER,roundi(w-20),call_size,Color("f5ffe9"))
	draw_string(font,Vector2(w*.5,h*.83),"24 TÜRCHEN · EIN BERGDORF",HORIZONTAL_ALIGNMENT_CENTER,roundi(w-20),clampi(roundi(w*.028),11,22),Color("fff3d3"))
