extends Control
## Alpine Radio's true hardware display. Dynamic station, song and artist
## share the lit tuner with the logo; no empty decorative fake screen.
const Branding = preload("res://src/core/radio_branding.gd")
const L = preload("res://src/core/i18n.gd")
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
	var w:float=maxf(1.0,size.x)
	var h:float=maxf(1.0,size.y)
	var compact:bool=w<470.0
	var spec:Dictionary=Branding.spec(station_id)
	var accent:Color=Color(str(spec.accent))
	var lit:Color=accent if active else Color("657f84")
	var text_color:Color=Color("e8fff3") if active else Color("99b0b2")
	var metal:Color=Color("314c58")
	# Beveled metal chassis, screw heads and inset hardware rather than a
	# generic dark box. All art is vectors and inexpensive on Android.
	draw_rect(Rect2(Vector2.ZERO,size),Color("06121b"))
	draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),metal,false,3.0)
	draw_line(Vector2(6,6),Vector2(w-6,6),Color("86b7b3",0.72),2.0,true)
	draw_line(Vector2(8,h-7),Vector2(w-8,h-7),Color("020e15"),3.0,true)
	for screw in [Vector2(10,9),Vector2(w-10,9),Vector2(10,h-9),Vector2(w-10,h-9)]:
		draw_circle(screw,3.0,Color("879e9e"))
		draw_line(screw+Vector2(-1.5,-1.2),screw+Vector2(1.5,1.2),Color("172b34"),1.0)
	# Actual driver / drilled speaker matrix on the left.
	var speaker_w:float=clampf(w*(0.17 if compact else 0.19),58.0,170.0)
	var grill:Rect2=Rect2(Vector2(15,16),Vector2(speaker_w-13,h-32))
	draw_rect(grill,Color("142b36"))
	draw_rect(grill,Color("607d82"),false,1.3)
	var center:Vector2=grill.get_center()
	var radius:float=minf(grill.size.x,grill.size.y)*0.40
	draw_circle(center,radius+7.0,Color("081b27"))
	draw_arc(center,radius+6.0,0,TAU,48,Color("769296"),2.0,true)
	draw_circle(center,radius,Color("25404b"))
	draw_arc(center,radius*.67,0,TAU,48,Color("355b61"),1.2,true)
	for ix in range(8):
		for iy in range(9):
			var p:Vector2=Vector2(grill.position.x+8.0+float(ix)*(grill.size.x-16.0)/7.0,grill.position.y+8.0+float(iy)*(grill.size.y-16.0)/8.0)
			if p.distance_to(center)<radius*.92:
				draw_circle(p,1.15,Color("8ca7aa",0.56))
	# Distinct glass display, illuminated receiver branding and station data.
	var screen:Rect2=Rect2(Vector2(speaker_w+15.0,12),Vector2(maxf(74.0,w-speaker_w-28.0),h-24))
	draw_rect(screen,Color("020d14"))
	draw_rect(screen,lit.darkened(.38),false,3.0)
	var glass:Rect2=Rect2(screen.position+Vector2(5,5),screen.size-Vector2(10,10))
	draw_rect(glass,Color("0a2631"))
	draw_rect(Rect2(glass.position,Vector2(glass.size.x,4.0)),Color("446f78",.28))
	# Short analogue illuminated tuner scale along the bottom.
	var scale_left:float=screen.position.x+12.0
	var scale_end:float=screen.end.x-12.0
	var scale_y:float=screen.end.y-21.0
	draw_line(Vector2(scale_left,scale_y),Vector2(scale_end,scale_y),Color("294852"),1.4,true)
	for i in range(25):
		var x:float=lerpf(scale_left,scale_end,float(i)/24.0)
		var major:bool=i%4==0
		draw_line(Vector2(x,scale_y),Vector2(x,scale_y-(7.0 if major else 4.0)),Color("9ac0b8",.78) if active else Color("617b82"),1.2,true)
	var tuned:float=clampf(float(frequency)/15.0,0.0,1.0)
	var indicator_x:float=lerpf(scale_left,scale_end,tuned)
	draw_line(Vector2(indicator_x,scale_y-13),Vector2(indicator_x,scale_y+4),lit,3.0,true)
	draw_circle(Vector2(screen.end.x-18.0,screen.position.y+15.0),3.0,Color("8eefd2") if active else Color("52616c"))
	# Keep station logo and playing title on top of a genuine lit LCD.
	var logo_w:float=minf(screen.size.x*(0.29 if compact else 0.27),194.0)
	var logo_h:float=maxf(28.0,screen.size.y-58.0)
	var logo_zone:Rect2=Rect2(screen.position+Vector2(10,10),Vector2(logo_w,logo_h))
	if logo_texture!=null:
		draw_texture_rect(logo_texture,logo_zone,false,Color.WHITE if active else Color("84969b"))
	var font:Font=ThemeDB.fallback_font
	var txt_x:float=logo_zone.end.x+10.0
	var max_w:float=maxf(22.0,screen.end.x-txt_x-12.0)
	var label_y:float=screen.position.y+26.0
	var short:String=str(spec.short) if spec.has("short") else station_id.to_upper()
	draw_string(font,Vector2(txt_x,label_y),short,HORIZONTAL_ALIGNMENT_LEFT,max_w,11 if compact else 13,lit)
	var song:String=track_title if not track_title.is_empty() else (L.text("SCAN / WÄHLE SENDER") if active else L.text("RADIO AUS"))
	var song_size:int=14 if compact else 21
	draw_string(font,Vector2(txt_x,label_y+25.0),song,HORIZONTAL_ALIGNMENT_LEFT,max_w,song_size,text_color)
	if h>112.0:
		draw_string(font,Vector2(txt_x,label_y+45.0),artist_name,HORIZONTAL_ALIGNMENT_LEFT,max_w,12,Color("9ec9c9"))
	# VU meters are driven from actual playing state, not a permanent loop.
	var count:int=15 if compact else 34
	var start_x:float=logo_zone.position.x
	var span:float=minf(screen.size.x*.38,logo_zone.size.x)
	var bottom:float=screen.end.y-34.0
	for i in range(count):
		var x:float=start_x+span*(float(i)+.5)/float(count)
		var oscillation:float=absf(sin(float(i)*1.62+float(frequency)*0.45))
		var bar:float=(2.0+oscillation*10.0)*clampf(signal_level,0.0,1.0) if active else 1.5
		draw_rect(Rect2(Vector2(x,bottom-bar),Vector2(maxf(1.4,span/float(count)*0.51),bar)),lit,true)
