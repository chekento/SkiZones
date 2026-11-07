extends Control
## Hand-drawn, theme-aware artwork used only when an original campaign
## image is not installed. Event typography is a separate overlay.
const Styles=preload("res://src/core/visual_styles.gd")
var style_id: String="alpine"
var motif: String="trees"

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _pine(center: Vector2, scale: float, pine: Color, snow: Color) -> void:
	draw_line(center+Vector2(0,9)*scale,center+Vector2(0,-48)*scale,Color("6e524b"),8*scale)
	for layer in range(3):
		var y: float=center.y-(18+layer*17)*scale
		var wide: float=(29-layer*6)*scale
		draw_colored_polygon(PackedVector2Array([
			Vector2(center.x-wide,y+19*scale),Vector2(center.x,y-31*scale),
			Vector2(center.x+wide,y+19*scale)]),pine)
		draw_line(Vector2(center.x-wide*.45,y),Vector2(center.x+wide*.32,y-2*scale),snow,2.6*scale)

func _mountains(w:float,h:float,accent:Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(0,h*.83),Vector2(w*.13,h*.52),Vector2(w*.29,h*.77),
		Vector2(w*.51,h*.30),Vector2(w*.73,h*.74),Vector2(w*.88,h*.42),
		Vector2(w,h*.70),Vector2(w,h),Vector2(0,h)]),accent.darkened(.39))
	draw_colored_polygon(PackedVector2Array([
		Vector2(w*.51,h*.30),Vector2(w*.59,h*.45),Vector2(w*.46,h*.42)]),Color("f6f9f2"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(w*.88,h*.42),Vector2(w*.94,h*.54),Vector2(w*.82,h*.52)]),Color("e5f6f5"))

func _firework(center: Vector2,radius:float,color:Color) -> void:
	for i in range(16):
		var t:float=TAU*float(i)/16.0
		var ray:=Vector2.from_angle(t)
		draw_line(center+ray*radius*.42,center+ray*radius,color,2.4)
		draw_circle(center+ray*radius,2.7,color)
	draw_circle(center,5,Color("fff5ce"))

func _draw() -> void:
	if size.x<20 or size.y<20:return
	var w:float=size.x
	var h:float=size.y
	var palette:Dictionary=Styles.ui_palette(style_id)
	var accent:=Color(str(palette.accent))
	var night:bool=motif in ["fireworks","midnight"]
	var dark:=Color("101c39") if night else Color("123e54") if style_id!="bauhaus" else Color("204578")
	var upper:=Color("3d6277") if not night else Color("34426d")
	for band in range(44):
		var t:float=float(band)/43.0
		draw_rect(Rect2(0,h*t,w,h/43.0+1.0),dark.lerp(upper,t))
	# Distinct imagery on adjacent billboards; no repeated painted lettering.
	var offset:int=abs(hash(motif))%71
	for i in range(52):
		var x:float=fposmod(33.0+float(i*127+offset*7),w)
		var y:float=fposmod(11.0+float(i*73+offset),h*.78)
		draw_circle(Vector2(x,y),1.1+float(i%4)*.47,Color(1,1,1,.36+.12*float(i%4)))
	_mountains(w,h,accent if not night else Color("6d8da5"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,h*.87),
		Vector2(w*.19,h*.78),Vector2(w*.48,h*.90),Vector2(w*.71,h*.80),
		Vector2(w,h*.88),Vector2(w,h),Vector2(0,h)]),Color("dae7e8"))
	if motif in ["trees","village","stars"]:
		for i in range(7):
			var px:float=float(i)*w/6.0+float(offset%13)-12
			var py:float=h*(.79+.035*float(i%3))
			_pine(Vector2(px,py),.48+.16*float(i%3),Color("315b58"),Color("dae9e4"))
		if motif=="village":
			for i in range(5):
				var px:float=w*(.24+.13*i)
				var py:float=h*(.79+(.02 if i%2 else 0))
				draw_rect(Rect2(px-14,py-17,28,23),Color("9e7259"))
				draw_colored_polygon(PackedVector2Array([
					Vector2(px-19,py-17),Vector2(px,py-29),Vector2(px+19,py-17)]),Color("d9e7e3"))
				draw_rect(Rect2(px-4,py-12,8,8),Color("ffe4a2"))
		elif motif=="trees":
			for i in range(4):
				var px:float=w*(.22+.09*i)
				var py:float=h*(.88-(i%2)*.027)
				draw_rect(Rect2(px,py-12,20,16),Color("c94d52") if i%2 else accent)
				draw_line(Vector2(px+10,py-12),Vector2(px+10,py+4),Color("ffe7a3"),3)
				draw_line(Vector2(px,py-4),Vector2(px+20,py-4),Color("ffe7a3"),3)
		else:
			for i in range(6):
				var at:=Vector2(w*(.13+.15*i),h*(.28+.08*(i%3)))
				_firework(at,13.0+float(i%3)*4.0,Color("fff1cd"))
	else:
		# Two night-event concepts: golden fireworks and neon midnight.
		for i in range(6):
			var at:=Vector2(w*(.10+.16*i),h*(.16+.11*(i%3)))
			var glow:=Color("ffcc82") if (i%2==0 or motif=="fireworks") else Color("82d4f2")
			_firework(at,20.0+float(i%3)*15.0,glow)
		draw_line(Vector2(w*.20,h*.81),Vector2(w*.70,h*.85),Color("fff0cb",.65),4)
	draw_rect(Rect2(8,8,w-16,h-16),Color(accent.r,accent.g,accent.b,.65),false,3)
