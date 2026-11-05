extends Control
## One sharp procedural vector insignia for each SkiZones radio station.
## Shape identity stays legible in all screen sizes and monochrome theme.
const Branding=preload("res://src/ui/radio_branding.gd")
var station_id: String="alpine"
var monochrome:=false

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(76,82)
	resized.connect(queue_redraw)

func set_brand(station: String, outline_only: bool=false) -> void:
	var normalized: String=station if Branding.IDENTITIES.has(station) else "off"
	if station_id==normalized and monochrome==outline_only: return
	station_id=normalized
	monochrome=outline_only
	queue_redraw()

func _draw() -> void:
	var item: Dictionary=Branding.info(station_id)
	var color: Color=Color("ddeaf2") if monochrome else Branding.color(station_id)
	var center:=Vector2(size.x*0.5,size.y*0.43)
	var radius: float=minf(size.x*0.37,size.y*0.36)
	draw_circle(center,radius,Color("142631"))
	draw_arc(center,radius,0.0,TAU,48,Color(color,0.82),2.4,true)
	draw_arc(center,radius-6.0,0.0,TAU,48,Color(color,0.28),1.1,true)
	var scale_value:float=radius/31.0
	draw_set_transform(center,0.0,Vector2(scale_value,scale_value))
	_mark(str(item.mark),color)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	var font:Font=get_theme_default_font()
	if font!=null:
		draw_string(font,Vector2(0.0,size.y-4.0),str(item.short),HORIZONTAL_ALIGNMENT_CENTER,size.x,14,color)
	# A single accent point identifies power-on without requiring a texture.
	draw_circle(Vector2(size.x-10.0,10.0),2.5,Color(color,0.7))

func _stroke(points: Array, color: Color, width: float=2.7) -> void:
	var packed:=PackedVector2Array()
	for p in points:packed.append(p)
	draw_polyline(packed,color,width,true)

func _mark(id: String, c: Color) -> void:
	match id:
		"power":
			draw_arc(Vector2.ZERO,17.0,-PI*0.32,PI*1.32,26,c,3.5,true)
			draw_line(Vector2(0,-23),Vector2(0,-2),c,3.5,true)
		"mountain_wave":
			_stroke([Vector2(-23,10),Vector2(-9,-13),Vector2(-1,-4),Vector2(8,-20),Vector2(23,10)],c,3)
			_stroke([Vector2(-21,17),Vector2(-12,13),Vector2(-2,17),Vector2(10,13),Vector2(21,17)],c,2)
		"chalet":
			_stroke([Vector2(-24,-3),Vector2(0,-22),Vector2(24,-3)],c,3)
			_stroke([Vector2(-17,-5),Vector2(-17,19),Vector2(17,19),Vector2(17,-5)],c,3)
			draw_rect(Rect2(-5,3,10,16),c,false,2.7)
			draw_line(Vector2(-14,-13),Vector2(14,-13),c,2.0,true)
		"snowflake":
			for i in range(6):
				var angle:float=TAU*float(i)/6.0
				var p:=Vector2.RIGHT.rotated(angle)
				draw_line(p*3.0,p*22.0,c,2.8,true)
				for wing in [-1.0,1.0]:
					draw_line(p*14.0,p*10.5+p.rotated(wing*0.55)*6.0,c,1.8,true)
			draw_circle(Vector2.ZERO,3.0,c)
		"sunrise":
			draw_arc(Vector2(0,12),15.0,PI,TAU,24,c,3,true)
			_stroke([Vector2(-23,15),Vector2(-14,4),Vector2(-5,15),Vector2(6,2),Vector2(19,15)],c,2.7)
			for i in range(5):
				var a:float=PI+float(i)*PI/4.0
				var p:=Vector2.RIGHT.rotated(a)
				draw_line(Vector2(0,12)+p*19,Vector2(0,12)+p*24,c,2.0,true)
		"speed":
			_stroke([Vector2(-23,18),Vector2(-3,-18),Vector2(5,-10),Vector2(19,-25)],c,3.2)
			_stroke([Vector2(-14,22),Vector2(3,-8),Vector2(11,1),Vector2(23,-16)],c,2.4)
			draw_line(Vector2(-24,-12),Vector2(-10,-12),c,2.4,true)
		"bolt":
			_stroke([Vector2(4,-25),Vector2(-13,-2),Vector2(2,-2),Vector2(-5,24),Vector2(17,-7),Vector2(3,-7)],c,3.9)
			draw_line(Vector2(-23,17),Vector2(-11,12),c,2,true)
		"vinyl":
			draw_circle(Vector2.ZERO,22,c)
			draw_circle(Vector2.ZERO,18,Color("142631"))
			for rad in [8.0,13.0,17.0]:draw_arc(Vector2.ZERO,rad,0.3,PI*1.73,35,Color(c,0.60),1.0,true)
			draw_circle(Vector2.ZERO,4.5,c)
			draw_circle(Vector2.ZERO,1.5,Color("142631"))
		"equalizer":
			var heights:=[13.0,28.0,20.0,35.0,24.0]
			for i in range(5):
				var x:float=-20.0+i*10.0
				draw_line(Vector2(x,heights[i]*0.5),Vector2(x,-heights[i]*0.5),c,4,true)
				draw_circle(Vector2(x,-heights[i]*0.5),2.3,c)
		"disco":
			draw_circle(Vector2(0,0),19,c)
			draw_arc(Vector2.ZERO,19,0,TAU,35,Color("142631"),2.8,true)
			for x in [-10.0,0.0,10.0]:draw_line(Vector2(x,-15),Vector2(x,15),Color("142631"),1.4,true)
			for y in [-10.0,0.0,10.0]:draw_line(Vector2(-15,y),Vector2(15,y),Color("142631"),1.4,true)
			draw_line(Vector2(0,-24),Vector2(0,-19),c,2,true)
		"note":
			draw_line(Vector2(1,-20),Vector2(1,12),c,3.2,true)
			draw_line(Vector2(1,-20),Vector2(20,-17),c,3.2,true)
			draw_line(Vector2(20,-17),Vector2(20,5),c,3.2,true)
			draw_circle(Vector2(-6,12),8,c)
			draw_circle(Vector2(13,6),8,c)
		"zen":
			for rad in [6.0,13.0,21.0]:draw_arc(Vector2.ZERO,rad,PI*0.15,PI*1.86,42,Color(c,1.0 if rad==21 else 0.7),2.6,true)
			draw_circle(Vector2.ZERO,2.3,c)
		"cup":
			_stroke([Vector2(-20,1),Vector2(-17,16),Vector2(10,16),Vector2(13,1)],c,3)
			draw_arc(Vector2(14,7),8,-PI/2.0,PI/2.0,15,c,2.6,true)
			for x in [-10.0,0.0,10.0]:_stroke([Vector2(x,-7),Vector2(x-3,-15),Vector2(x,-24)],c,1.7)
		"ice":
			_stroke([Vector2(-22,17),Vector2(-11,-4),Vector2(-2,-22),Vector2(8,-8),Vector2(17,-16),Vector2(24,17),Vector2(-22,17)],c,2.8)
			draw_line(Vector2(-2,-22),Vector2(4,17),c,1.6,true)
			draw_line(Vector2(-11,-4),Vector2(14,2),c,1.6,true)
		"orbit":
			draw_circle(Vector2.ZERO,9,c)
			draw_arc(Vector2.ZERO,22,-PI*0.85,PI*0.72,40,c,2.4,true)
			draw_arc(Vector2.ZERO,22,PI*0.88,PI*1.18,10,c,2.4,true)
			draw_circle(Vector2(20,-10),3.2,c)
			draw_circle(Vector2(-17,15),2.5,c)
		"echo":
			for i in range(4):
				var x:float=-19.0+float(i)*6.0
				_stroke([Vector2(x,12),Vector2(x+5,-12),Vector2(x+12,12)],Color(c,1.0-float(i)*0.16),2.2)
		"deco":
			_stroke([Vector2(-21,20),Vector2(-21,-6),Vector2(-15,-16),Vector2(0,-21),Vector2(15,-16),Vector2(21,-6),Vector2(21,20)],c,3)
			_stroke([Vector2(-13,20),Vector2(-13,-5),Vector2(0,-13),Vector2(13,-5),Vector2(13,20)],c,2.5)
			draw_line(Vector2(-23,20),Vector2(23,20),c,2.7,true)
