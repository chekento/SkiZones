extends Control

var rows: Array = []

func _ready() -> void:
	custom_minimum_size = Vector2(0, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var font := get_theme_default_font()
	var area := Rect2(64, 22, maxf(100, size.x - 88), 154)
	var maximum := 1.0
	for row in rows:
		maximum = maxf(maximum, absf(row.net))
	var baseline := area.position.y + area.size.y * 0.5
	for ratio in [-1.0, 0.0, 1.0]:
		var y: float = baseline - ratio * area.size.y * 0.5
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("41626e"), 1)
		draw_string(font, Vector2(3, y + 5), "%.0f k€" % (ratio * maximum / 1000), HORIZONTAL_ALIGNMENT_LEFT, 56, 13, Color("9bb8c2"))
	if rows.is_empty():
		draw_string(font, Vector2(82, baseline - 12), "Nach dem ersten Betriebstag erscheint hier dein Verlauf.", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("9bb8c2"))
		return
	var step := area.size.x / rows.size()
	for i in range(rows.size()):
		var value: float = rows[i].net
		var height_value := absf(value) / maximum * area.size.y * 0.5
		var y := baseline - height_value if value >= 0 else baseline
		draw_rect(Rect2(area.position.x + i * step + 2, y, maxf(3, step - 4), maxf(1, height_value)), Color("7ac8b2") if value >= 0 else Color("d78a7e"))
		if i == 0 or i == rows.size() - 1 or int(rows[i].day) % 7 == 0:
			draw_string(font, Vector2(area.position.x + i * step + 2, area.end.y + 24), str(int(rows[i].day)), HORIZONTAL_ALIGNMENT_LEFT, step, 13, Color("c4d8df"))
