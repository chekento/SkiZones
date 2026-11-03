extends Control
## Small procedural interiors keep games readable and light on mobile GPUs.
var kind := "pizzeria"
var mode := "pizza"
var toppings: Array = []
var cursor := 0.0
var target := 0.5
var gate := 1
var time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	time += delta
	if mode != "pizza": queue_redraw()

func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_style_box(_background(), area)
	var centre := size * 0.5
	if mode == "pizza":
		var radius: float = minf(size.x * 0.42, size.y * 0.42)
		draw_circle(centre + Vector2(0, 6), radius + 12, Color("c4c6b8"))
		draw_circle(centre, radius + 10, Color("fffaf1"))
		draw_circle(centre, radius, Color("c9853f"))
		draw_circle(centre, radius * 0.87, Color("b4543b") if toppings.has("tomato") else Color("e4b879"))
		if toppings.has("cheese"): draw_circle(centre, radius * 0.78, Color("f4d887"))
		for index in range(8):
			var direction := Vector2.RIGHT.rotated(index * TAU / 8.0)
			draw_line(centre + direction * 7, centre + direction * radius * 0.91, Color("d9ad62"), 1.5, true)
		var ingredients: Array = toppings.filter(func(t): return t not in ["tomato", "cheese"])
		for index in range(ingredients.size()):
			for piece in range(5):
				var angle: float = piece * TAU / 5.0 + index * 0.97
				var at: Vector2 = centre + Vector2.RIGHT.rotated(angle) * radius * (0.26 + index * 0.065 + piece * 0.025)
				var ingredient: String = str(ingredients[index])
				var colors := {"mushroom":"b7a48d", "pepper":"d86f42", "olive":"597451", "ham":"d38e87", "salami":"a74b3c", "pineapple":"edc34f", "spinach":"547955", "onion":"b88bb5"}
				var color := Color(colors.get(ingredient, "c09070"))
				if ingredient in ["salami", "mushroom", "olive"]:
					draw_circle(at, radius * 0.075, color)
					if ingredient == "olive": draw_circle(at, radius * 0.035, Color("e2ce83"))
				else:
					draw_line(at - Vector2(4, 3), at + Vector2(4, 3), color, radius * 0.075, true)
	elif mode == "slalom":
		for index in range(3):
			var x: float = size.x * (0.25 + index * 0.25)
			for step in range(6):
				var y: float = fmod(step * 40.0 + time * 35.0, size.y)
				draw_line(Vector2(x - 20, y), Vector2(x + 20, y - 18), Color("d2e3e6"), 2, true)
			var gate_y: float = 40.0 + sin(time * 1.6) * 7.0
			var color := Color("397f75") if index == gate else Color("d4b9ae")
			draw_line(Vector2(x - 26, gate_y + 30), Vector2(x - 26, gate_y - 15), color, 4, true)
			draw_line(Vector2(x + 26, gate_y + 30), Vector2(x + 26, gate_y - 15), color, 4, true)
			draw_rect(Rect2(x - 26, gate_y - 15, 52, 16), color)
		var skier := Vector2(centre.x, size.y * 0.78)
		draw_line(skier + Vector2(-9, 22), skier + Vector2(-13, -4), Color("b46e4c"), 5, true)
		draw_line(skier + Vector2(9, 22), skier + Vector2(13, -4), Color("b46e4c"), 5, true)
		draw_circle(skier, 13, Color("4f849a"))
		draw_circle(skier + Vector2(0, -14), 9, Color("f2d3ad"))
	elif kind == "schmarrn":
		var radius: float = minf(size.y * 0.38, size.x * 0.24)
		draw_line(centre + Vector2(radius * 0.7, 0), centre + Vector2(radius * 1.9, 12), Color("6e6254"), 18, true)
		draw_circle(centre, radius + 8, Color("5b615b"))
		draw_circle(centre, radius, Color("807666"))
		for index in range(11):
			var at: Vector2 = centre + Vector2.RIGHT.rotated(index * 2.4) * radius * (0.15 + index * 0.055)
			draw_rect(Rect2(at - Vector2(9, 6), Vector2(18, 12)), Color("e8bf76").darkened(cursor * 0.25))
	else:
		var glass := Rect2(centre.x - 45, 20, 90, size.y - 40)
		draw_style_box(_glass(), glass)
		var filled := Rect2(glass.position + Vector2(8, 8), glass.size - Vector2(16, 16))
		filled.position.y += filled.size.y * (1.0 - cursor)
		filled.size.y *= cursor
		draw_rect(filled, Color("c58d50") if kind in ["bar", "disco"] else Color("75aaa8"))
		var target_y: float = glass.end.y - 8 - (glass.size.y - 16) * target
		draw_line(Vector2(glass.position.x - 15, target_y), Vector2(glass.end.x + 15, target_y), Color("367d73"), 4, true)

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4e8d1") if mode == "pizza" or kind == "schmarrn" else Color("eff5f0")
	style.set_corner_radius_all(18)
	return style

func _glass() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff9e9")
	style.border_color = Color("a1b7b5")
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	return style
