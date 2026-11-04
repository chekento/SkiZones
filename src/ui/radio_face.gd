extends Control
## Lightweight, resolution-independent analogue radio face (no textures, no extra audio).
var frequency := 1
var active := false
var signal_level := 0.4

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w: float = maxf(1.0, size.x)
	var h: float = maxf(1.0, size.y)
	var dark := Color("10242d")
	var rim := Color("527e82")
	var glow := Color("7af1c8") if active else Color("80a4a4")
	draw_rect(Rect2(Vector2.ZERO,size), dark, true)
	draw_rect(Rect2(Vector2(6,6),size-Vector2(12,12)),rim,false,3.0)
	var compact := w < 480.0
	var speaker_width: float = w * (0.27 if not compact else 0.22)
	var grill := Rect2(Vector2(22,26),Vector2(speaker_width-28,h-52))
	draw_rect(grill,Color("1e3d46"),true)
	for i in range(4, maxi(5,roundi(grill.size.x / 11.0))):
		var gx: float = grill.position.x + 10.0 + i * (grill.size.x-20.0) / maxf(1.0, float(maxi(5,roundi(grill.size.x / 11.0))-1))
		draw_line(Vector2(gx,grill.position.y+12),Vector2(gx,grill.end.y-12),Color("63818a"),2.0,true)
	var left: float = speaker_width + 20.0
	var width_left: float = maxf(50.0,w-left-22.0)
	var lcd := Rect2(Vector2(left,26),Vector2(width_left,h*0.44))
	draw_rect(lcd,Color("081b25"),true)
	draw_rect(lcd,glow.darkened(0.45),false,2.0)
	var signal_y: float = lcd.position.y + lcd.size.y * 0.68
	for i in range(29):
		var tick_x: float = left+12.0 + width_left * 0.89 * float(i)/28.0
		var major := (i % 4 == 0)
		draw_line(Vector2(tick_x,signal_y-(12 if major else 5)),Vector2(tick_x,signal_y+7),glow.darkened(0.20 if major else 0.48),2.0,true)
	var tuning: float = 12.0 + width_left * 0.89 * float(frequency % 11)/10.0
	draw_line(Vector2(left+tuning,lcd.position.y+10),Vector2(left+tuning,lcd.end.y-8),Color("e7ae6e"),3.0,true)
	var bars: int = 12 if compact else 18
	for i in range(bars):
		var amplitude: float = 0.12 + 0.85 * absf(sin(float(i)*1.67+float(frequency)*0.81))
		var bar_h: float = (h*0.23)*amplitude*(signal_level if active else 0.1)
		var bx: float = left+width_left*(float(i)+0.75)/float(bars+1)
		draw_rect(Rect2(bx,h*0.85-bar_h,maxf(2.0,width_left/float(bars+1)*0.52),bar_h),glow,true)
	var knob_center := Vector2(left+width_left-25.0,h-24.0)
	draw_circle(knob_center,16.0,Color("769296"))
	draw_circle(knob_center,11.0,Color("1e333c"))
	draw_line(knob_center,knob_center+Vector2(0,-9).rotated(float(frequency)*0.26),glow,3.0,true)
