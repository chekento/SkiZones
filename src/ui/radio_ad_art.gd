extends Control
## Original vector radio advert, printed like a miniature Alpine station poster.
## All lettering is rendered as native controls in the calling screen, so ad
## copy can wrap for phones and remain compatible with accessibility.
const Styles=preload("res://src/core/visual_styles.gd")
var station_id := "alpine"
var style_id := "alpine"

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(0,86)
	resized.connect(queue_redraw)

func set_station(id: String, theme: String) -> void:
	station_id=id
	style_id=Styles.valid(theme)
	queue_redraw()

func _draw() -> void:
	if size.x <= 0 or size.y <= 0: return
	var palette: Dictionary=Styles.ui_palette(style_id)
	var accent := Color(str(palette.accent))
	var dark := Color("132139") if style_id in ["neon_noir","aurora_ink","cinematic"] else Color("e8d6b3")
	var w: float=size.x
	var h: float=size.y
	draw_rect(Rect2(Vector2.ZERO,size),dark)
	draw_rect(Rect2(4,4,w-8,h-8),accent,false,2)
	for i in range(12):
		var x: float=16.0 + (w-32)*float(i)/11.0
		var tall: float=absf(sin(float(i)*2.17 + float(station_id.length())*.25))
		var amplitude: float=8.0 + tall*25.0
		draw_line(Vector2(x,h*.5-amplitude*.5),Vector2(x,h*.5+amplitude*.5),accent.lightened(.17),3)
	var vinyl_center:=Vector2(w-39,h*.5)
	draw_circle(vinyl_center,26,accent.darkened(.3))
	draw_circle(vinyl_center,19,dark)
	draw_circle(vinyl_center,5,accent)
	for n in range(3):
		var y: float=16.0+float(n)*21.0
		draw_line(Vector2(16,y),Vector2(w-75,y),Color(accent,0.25),1)
