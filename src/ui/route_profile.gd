extends Control
## A live longitudinal section: altitude over travelled horizontal distance.
const Mountain = preload("res://src/core/mountain.gd")
const COLORS := [Color("71baf0"), Color("f28c99"), Color("bec8d5")]
var analysis: Dictionary = {}

func _init() -> void:
	custom_minimum_size = Vector2(0,224)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func update_profile(value: Dictionary) -> void:
	analysis = value
	queue_redraw()

func _text(at: Vector2, text: String, color: Color, font_size: int = 13) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, size.x - at.x, font_size, color)

func _draw() -> void:
	var muted := Color("91b0bc")
	var samples: Array = analysis.get("profile", [])
	_text(Vector2(2, 18), "HÖHENPROFIL · BERG → TAL", Color("75cdc7"), 13)
	if samples.size() < 2:
		_text(Vector2(2, 48), "Plane bergab, mit Gegenanstiegen.", Color("e7f2f4"), 15)
		_text(Vector2(2, 74), "Die Farbe entsteht automatisch.", muted, 12)
		_text(Vector2(2, 103), "Querungen senken das Gefälle.", muted, 12)
		_text(Vector2(2, 125), "Steile Teilstücke zählen mit.", muted, 12)
		_text(Vector2(2, 154), "Nummerierte Punkte: ziehen.", muted, 12)
		_text(Vector2(2, 176), "Kleine Kreise: hier andocken.", muted, 12)
		return
	var color: Color = COLORS[analysis.difficulty]
	_text(Vector2(2, 43), "%s · automatisch" % ["BLAU", "ROT", "SCHWARZ"][analysis.difficulty], color, 16)
	_text(Vector2(2, 64), "Max. %.0f %% · Ø %.0f %% · ↓ %.0f m" % [analysis.grade, analysis.average, analysis.drop], muted)
	var top: float = samples[0].height
	var bottom := top
	for sample in samples:
		top = maxf(top, sample.height)
		bottom = minf(bottom, sample.height)
	var chart := Rect2(4, 94, size.x - 8, 70)
	draw_rect(chart, Color("163b4a"))
	for fraction in [0.0, 0.5, 1.0]:
		var y: float = chart.position.y + chart.size.y * fraction
		draw_line(Vector2(chart.position.x, y), Vector2(chart.end.x, y), Color("365865"), 1)
	for i in range(1, samples.size()):
		var a: Dictionary = samples[i - 1]
		var b: Dictionary = samples[i]
		var from := chart.position + Vector2(a.distance / maxf(analysis.horizontal, 1) * chart.size.x, (top - a.height) / maxf(top - bottom, 1) * chart.size.y)
		var to := chart.position + Vector2(b.distance / maxf(analysis.horizontal, 1) * chart.size.x, (top - b.height) / maxf(top - bottom, 1) * chart.size.y)
		var section_color: Color = Color("efb17d") if b.grade < -0.5 else COLORS[Mountain.difficulty_for_grade(b.grade)]
		draw_line(from, to, section_color, 2.5, true)
	_text(Vector2(4, 87), "%.0f m" % top, muted, 11)
	_text(Vector2(4, 182), "%.0f m · Tal" % bottom, muted, 11)
	var length_text := "%.0f m Strecke" % analysis.length
	var length_width := ThemeDB.fallback_font.get_string_size(length_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	_text(Vector2(size.x - length_width - 4, 182), length_text, muted, 11)
	if analysis.get("uphill",0) > 0.2:
		_text(Vector2(2,207),"↑ %.1f m · %s" % [analysis.uphill,"%.0f m stapfen" % analysis.get("hike_meters",0) if analysis.get("hike_meters",0) > 0.5 else "mit Schwung"],Color("efb17d"),12)
