extends Control
const Catalog = preload("res://src/core/catalog.gd")
var kind := "cabin"

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	custom_minimum_size=Vector2(100,82)

func _draw() -> void:
	var scale_value := minf(size.x/120,size.y/90)
	draw_set_transform(Vector2((size.x-120*scale_value)/2,(size.y-90*scale_value)/2),0,Vector2.ONE*scale_value)
	var color := Color(Catalog.BUILDINGS.get(kind,{"color":"9bb8b4"}).color)
	if _special_preview(color): return
	var lodging := Catalog.LODGING.has(kind)
	var floors := 3 if kind=="grand_hotel" else 2 if kind in ["hotel","guesthouse","apartment"] else 1
	var top := 58-floors*12
	draw_ellipse_shadow()
	draw_colored_polygon(PackedVector2Array([Vector2(84,top+4),Vector2(106,top-4),Vector2(106,66),Vector2(84,75)]),color.darkened(0.3))
	draw_rect(Rect2(16,top+4,68,71-top),color)
	draw_colored_polygon(PackedVector2Array([Vector2(9,top+5),Vector2(50,top-15),Vector2(91,top+5)]),Color("7d6956"))
	draw_colored_polygon(PackedVector2Array([Vector2(50,top-15),Vector2(72,top-23),Vector2(113,top-4),Vector2(91,top+5)]),Color("cadbe2"))
	draw_line(Vector2(9,top+4),Vector2(50,top-15),Color("f8fbf9"),5,true)
	for floor_index in range(floors):
		for x in [29,50,71]:
			draw_rect(Rect2(x-4,top+11+floor_index*13,8,9),Color("fee5af"))
	draw_rect(Rect2(45,59,11,16),Color("69584a"))
	draw_rect(Rect2(12,75,80,4),Color("d6e3e8"))
	var at := Vector2(96,66)
	draw_circle(at,15,Color("fff7e8"))
	if kind=="fitness":
		for side in [-1,1]: draw_circle(at+Vector2(side*8,0),6,Color("446b7a"))
		draw_line(at+Vector2(-9,0),at+Vector2(9,0),Color("446b7a"),3,true)
	elif kind=="watchmaker":
		draw_circle(at,12,Color("e0b36f"))
		draw_circle(at,9,Color("fff8e8"))
		draw_line(at,at+Vector2(0,-7),Color("4a6570"),2,true)
		draw_line(at,at+Vector2(5,3),Color("4a6570"),2,true)
	elif kind in ["souvenir","craftshop"]:
		draw_rect(Rect2(at-Vector2(9,10),Vector2(18,19)),Color("bd976f"))
		for i in range(3):
			draw_circle(at+Vector2(-5+i*5,3),2,Color("f1dfb2"))
		draw_line(at+Vector2(-9,-3),at+Vector2(9,-3),Color("6e5a4c"),2,true)
	elif kind=="pizzeria":
		draw_circle(at,10,Color("d9aa64"))
		draw_circle(at,8,Color("d57f54"))
		for offset in [Vector2(-3,-3),Vector2(4,-1),Vector2(0,4)]: draw_circle(at+offset,2,Color("f2dab0"))
	elif lodging:
		draw_line(at+Vector2(-8,5),at+Vector2(-8,-6),Color("567e83"),2,true)
		draw_rect(Rect2(at+Vector2(-7,0),Vector2(15,5)),Color("567e83"))
		draw_rect(Rect2(at+Vector2(-7,-3),Vector2(5,4)),Color("98b7ba"))
	elif kind in ["first_aid","repair_office"]:
		draw_rect(Rect2(at-Vector2(3,9),Vector2(6,18)),Color("b6685a"))
		draw_rect(Rect2(at-Vector2(9,3),Vector2(18,6)),Color("b6685a"))
	elif kind in ["school","rental","snowpark"]:
		for side in [-1,1]: draw_line(at+Vector2(side*6,-8),at+Vector2(-side*6,8),Color("567e83"),3,true)
	elif kind in ["cocoa","kiosk","restaurant","bar","schmarrn","lodge"]:
		draw_rect(Rect2(at-Vector2(7,5),Vector2(12,12)),Color("b98461"))
		draw_arc(at+Vector2(6,0),5,-PI/2,PI/2,12,Color("b98461"),2,true)
		draw_line(at+Vector2(-3,-8),at+Vector2(0,-11),Color("98b2ba"),2,true)
	else:
		draw_circle(at,8,Color("739ca0"))
		draw_line(at+Vector2(0,-6),at+Vector2(0,4),Color("fff7e8"),2,true)
		draw_circle(at+Vector2(0,7),1.2,Color("fff7e8"))

func draw_ellipse_shadow() -> void:
	draw_style_box(_shadow(),Rect2(9,70,104,13))

func _shadow() -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color=Color(0.24,0.38,0.42,0.14)
	result.set_corner_radius_all(10)
	return result

func _special_preview(color: Color) -> bool:
	var ink := Color("587480")
	if kind=="snowmaker":
		draw_ellipse_shadow()
		draw_line(Vector2(40,71),Vector2(56,45),ink,6,true)
		draw_line(Vector2(78,71),Vector2(56,45),ink,6,true)
		draw_circle(Vector2(39,72),6,Color("40555d"))
		draw_circle(Vector2(80,72),6,Color("40555d"))
		draw_style_box(_colored(color,7),Rect2(40,19,39,38))
		draw_circle(Vector2(80,38),20,Color("dfebee"))
		draw_circle(Vector2(80,38),15,ink)
		for index in range(5):
			var at := Vector2.from_angle(index*TAU/5)*10
			draw_line(Vector2(80,38)+at*0.35,Vector2(80,38)+at,Color("c4d8de"),4,true)
		draw_circle(Vector2(80,38),3,Color("e2b16b"))
		return true
	if kind=="bus":
		draw_ellipse_shadow()
		draw_style_box(_colored(color,9),Rect2(12,24,96,48))
		for x in [23,43,63,83]: draw_style_box(_colored(Color("d5e7ec"),3),Rect2(x,32,15,19))
		for x in [33,88]:
			draw_circle(Vector2(x,72),8,Color("43545c"))
			draw_circle(Vector2(x,72),4,Color("adbdc3"))
		draw_rect(Rect2(12,58,96,4),Color("f3cf8b"))
		return true
	if kind in ["pool","spa"]:
		draw_ellipse_shadow()
		draw_style_box(_colored(Color("b9cdd3"),12),Rect2(12,27,96,48))
		draw_style_box(_colored(Color("75bdce"),10),Rect2(19,33,81,33))
		for x in [32,55,78]: draw_arc(Vector2(x,46),9,0.2,2.8,10,Color("c8e8ed"),2,true)
		for x in [23,75]:
			draw_rect(Rect2(x,15,20,7),Color("d1b68d"))
			draw_line(Vector2(x+3,15),Vector2(x,9),ink,2,true)
		return true
	if kind=="viewpoint":
		draw_ellipse_shadow()
		draw_style_box(_colored(Color("ad9474"),4),Rect2(13,56,94,18))
		for x in [19,39,59,79,99]: draw_line(Vector2(x,40),Vector2(x,62),ink,3,true)
		draw_line(Vector2(19,40),Vector2(99,40),ink,3,true)
		draw_line(Vector2(55,56),Vector2(64,30),ink,5,true)
		draw_line(Vector2(54,32),Vector2(83,22),color.darkened(0.2),10,true)
		return true
	if kind=="snowpark":
		draw_ellipse_shadow()
		draw_colored_polygon(PackedVector2Array([Vector2(9,70),Vector2(48,36),Vector2(64,70)]),Color("b5d0df"))
		draw_line(Vector2(9,70),Vector2(48,36),Color("f6fcfc"),4,true)
		draw_line(Vector2(67,49),Vector2(110,49),color,5,true)
		for x in [74,104]: draw_line(Vector2(x,49),Vector2(x,71),ink,3,true)
		return true
	if kind in ["maintenance","repair_office"]:
		draw_ellipse_shadow()
		draw_rect(Rect2(14,28,92,47),color)
		draw_style_box(_colored(Color("dce8eb"),4),Rect2(10,21,100,10))
		draw_rect(Rect2(24,39,41,36),Color("617c86"))
		for y in [44,51,58,65]: draw_line(Vector2(25,y),Vector2(64,y),Color("adc4cc"),2,true)
		draw_rect(Rect2(78,46,16,29),Color("7c624f"))
		draw_rect(Rect2(80,49,12,11),Color("f5d59d"))
		return true
	return false

func _colored(color: Color, radius: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color=color
	result.set_corner_radius_all(radius)
	return result
