extends Control
## True interactive radio display artwork: original vector logo per station,
## waveform, frequency cursor and illuminated tuner. Buttons are provided
## by the Jukebox controller over/in the same device, never as inert art.
const Branding = preload("res://src/core/radio_branding.gd")
var frequency := 1
var active := false
var signal_level := 0.4
var station_id := "alpine"
var logo_texture: Texture2D

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_station(station_id)

func set_station(id: String) -> void:
	station_id = id if Branding.BRANDS.has(id) else "alpine"
	logo_texture=Branding.logo(station_id)
	queue_redraw()

func _draw() -> void:
	var w:float=maxf(1.0,size.x)
	var h:float=maxf(1.0,size.y)
	var compact:bool=w<480.0
	var spec:Dictionary=Branding.spec(station_id)
	var active_color:Color=Color(str(spec.accent))
	var rim:Color=Color(str(spec.deep)).lightened(0.32)
	var glow:Color=active_color if active else Color("70858f")
	draw_rect(Rect2(Vector2.ZERO,size),Color("0d1821"),true)
	draw_rect(Rect2(Vector2(5,5),size-Vector2(10,10)),rim,false,2.5)
	var speaker_width:float=w*(0.23 if not compact else 0.18)
	var grill:Rect2=Rect2(Vector2(13,18),Vector2(maxf(25.0,speaker_width-16),h-36))
	draw_rect(grill,Color("213643"),true)
	var grill_count:int=clampi(roundi(grill.size.x/9.0),4,26)
	for i in range(grill_count):
		var gx:float=grill.position.x+7.0+float(i)*(grill.size.x-14.0)/maxf(1.0,grill_count-1)
		draw_line(Vector2(gx,grill.position.y+9),Vector2(gx,grill.end.y-9),Color("587282"),1.8,true)
	var left:float=speaker_width+17.0
	var screen:Rect2=Rect2(Vector2(left,14.0),Vector2(maxf(25.0,w-left-12.0),h-28.0))
	draw_rect(screen,Color("06151e"),true)
	draw_rect(screen,glow.darkened(0.3),false,2.0)
	if logo_texture!=null:
		var logo_region:Rect2=Rect2(screen.position+Vector2(6,6),Vector2(maxf(20,screen.size.x-12),maxf(15,screen.size.y-38)))
		draw_texture_rect(logo_texture,logo_region,false,Color.WHITE if active else Color(0.62,0.67,0.7,0.8))
	var bar_count:int=14 if compact else 28
	for i in range(bar_count):
		var x:float=screen.position.x+9.0+float(i)*(screen.size.x-18.0)/float(bar_count)
		var oscillation:float=0.25+0.70*absf(sin(float(i)*1.72+float(frequency)*0.71))
		var height:float=21.0*oscillation*maxf(0.07,signal_level) if active else 2.0
		draw_rect(Rect2(Vector2(x,screen.end.y-8-height),Vector2(maxf(2.0,(screen.size.x-18.0)/float(bar_count)*0.48),height)),glow,true)
