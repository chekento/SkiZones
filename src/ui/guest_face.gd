extends Control
## A vector expression also works on Android without an installed emoji font.
var mood := "content"
var jacket := Color("de8358")

func update_face(value: String, color: Color) -> void:
	mood = value
	jacket = color
	visible = true
	queue_redraw()

func _draw() -> void:
	var center := Vector2(size.x * 0.5, 55)
	draw_circle(center + Vector2(0, 3), 48, Color("e1eeea"))
	draw_circle(center, 34, Color("ecc49c"))
	draw_circle(center + Vector2(0, -9), 36, jacket.darkened(0.15))
	draw_style_box(_box(jacket), Rect2(center + Vector2(-34, -2), Vector2(68, 18)))
	draw_circle(center + Vector2(0, 14), 29, Color("ecc49c"))
	for side in [-1,1]:
		draw_circle(center+Vector2(side*18,19),5,Color("e7a69c"))
	draw_circle(center+Vector2(0,-43),8,jacket.lightened(0.2))
	draw_style_box(_box(Color("173744")), Rect2(center + Vector2(-29, -2), Vector2(58, 20)))
	draw_style_box(_box(Color("a5d6df")), Rect2(center + Vector2(-25, 1), Vector2(50, 12)))
	draw_line(center + Vector2(-20, 3), center + Vector2(2, 3), Color("e6f5ef"), 2, true)
	var mouth := center + Vector2(0, 26)
	if mood in ["cold", "tired", "hungry"]:
		draw_circle(mouth, 5, Color("7c4a3c"))
		if mood == "cold":
			draw_line(mouth + Vector2(-7, 0), mouth + Vector2(7, 0), Color("d8f1f6"), 2, true)
	elif mood == "impatient":
		draw_arc(mouth + Vector2(0, 8), 9, PI * 1.15, PI * 1.85, 20, Color("7c4a3c"), 2, true)
	elif mood == "focused":
		draw_line(mouth + Vector2(-5, 0), mouth + Vector2(6, -1), Color("7c4a3c"), 2, true)
	else:
		draw_arc(mouth - Vector2(0, 5), 10 if mood == "excited" else 8, 0.15, PI - 0.15, 20, Color("7c4a3c"), 3, true)
	if mood == "excited":
		for side in [-1, 1]:
			var star := center + Vector2(side * 48, -18)
			draw_line(star - Vector2(0, 5), star + Vector2(0, 5), Color("efb17d"), 2, true)
			draw_line(star - Vector2(5, 0), star + Vector2(5, 0), Color("efb17d"), 2, true)

func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(7)
	return box
