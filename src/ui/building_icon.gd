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
	if kind=="pizzeria":
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
