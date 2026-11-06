extends Control
## Alpine Radio's true hardware display. Dynamic station, song and artist
## share the lit tuner with the logo; no empty decorative fake screen.
const Branding = preload("res://src/core/radio_branding.gd")
var frequency := 1
var active := false
var signal_level := 0.4
var station_id := "alpine"
var track_title := ""
var artist_name := ""
var logo_texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_station(station_id)

func set_station(id: String) -> void:
	station_id = id if Branding.BRANDS.has(id) else "alpine"
	logo_texture = Branding.logo(station_id)
	queue_redraw()

func set_track(title: String, artist: String) -> void:
	if track_title == title and artist_name == artist:return
	track_title = title
	artist_name = artist
	queue_redraw()

func _draw() -> void:
	var w: float=maxf(1.0,size.x)
	var h: float=maxf(1.0,size.y)
	var compact := w < 470.0
	var spec: Dictionary=Branding.spec(station_id)
	var lit := Color(str(spec.accent)) if active else Color("6e828b")
	var rim := Color(str(spec.deep)).lightened(0.35)
	draw_rect(Rect2(Vector2.ZERO,size),Color("081721"),true)
	draw_rect(Rect2(Vector2(4.0,4.0),size-Vector2(8.0,8.0)),rim,false,3.0)
	var grill_w := clampf(w * (0.16 if compact else 0.19),55.0,156.0)
	var grill := Rect2(Vector2(12,16),Vector2(grill_w - 11.0,h - 32.0))
	draw_rect(grill,Color("18313c"),true)
	for i in range(10):
		var xx:float=grill.position.x+6.0+float(i)*(grill.size.x-12.0)/9.0
		draw_line(Vector2(xx,grill.position.y+5),Vector2(xx,grill.end.y-5),Color("65838a"),1.4,true)
	var screen := Rect2(Vector2(grill_w+16.0,13.0),Vector2(w-grill_w-30.0,h-26.0))
	draw_rect(screen,Color("04151b"),true)
	draw_rect(screen,lit.darkened(0.30),false,3.0)
	draw_rect(Rect2(screen.position+Vector2(4,4),screen.size-Vector2(8,8)),Color("0b2731"),true)
	var logo_w := minf(screen.size.x * (0.33 if compact else 0.27),207.0)
	var logo_zone := Rect2(screen.position+Vector2(10,10),Vector2(logo_w,screen.size.y-35))
	if logo_texture != null:
		draw_texture_rect(logo_texture,logo_zone,false,Color.WHITE if active else Color("84969b"))
	var text_x := logo_zone.end.x + 14.0
	var max_w := maxf(30.0,screen.end.x-text_x-13.0)
	var font: Font=ThemeDB.fallback_font
	var label_color := Color("dcffeb") if active else Color("99b0b2")
	var station_name := str(spec.short) if spec.has("short") else station_id.to_upper()
	draw_string(font,Vector2(text_x,screen.position.y+23),station_name,HORIZONTAL_ALIGNMENT_LEFT,max_w,12,lit)
	var song := track_title if not track_title.is_empty() else ("SCAN / WÄHLE SENDER" if active else "RADIO AUS")
	draw_string(font,Vector2(text_x,screen.position.y+52),song.substr(0,54),HORIZONTAL_ALIGNMENT_LEFT,max_w,20 if not compact else 15,label_color)
	draw_string(font,Vector2(text_x,screen.position.y+74),artist_name.substr(0,65),HORIZONTAL_ALIGNMENT_LEFT,max_w,13,Color("a8ccd0"))
	var count := 21 if compact else 48
	var start := screen.position.x+12.0
	var usable := maxf(15.0,screen.size.x-24.0)
	for i in range(count):
		var x:float=start+usable*(float(i)+0.5)/float(count)
		var oscillation := absf(sin(float(i)*1.62+float(frequency)*0.45))
		var bar:float=(5.0+oscillation*14.0)*clampf(signal_level,0.0,1.0) if active else 1.5
		draw_rect(Rect2(Vector2(x,screen.end.y-8.0-bar),Vector2(maxf(1.0,usable/count*0.45),bar)),lit,true)
