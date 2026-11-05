extends Control
const Assets=preload("res://src/world/style_assets.gd")
const IconArt=preload("res://src/ui/asset_icon_art.gd")
var style_override := ""
var _style_hud: CanvasLayer
var _seen := ""
static var themes: Dictionary={}
const Catalog = preload("res://src/core/catalog.gd")
var kind := "drag"

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	var ancestor: Node=get_parent()
	while ancestor!=null:
		if ancestor is CanvasLayer and ancestor.get("game")!=null:
			_style_hud=ancestor;break
		ancestor=ancestor.get_parent()
func current_style() -> String:
	return style_override if style_override!="" else str(_style_hud.game.view.visual_style) if _style_hud!=null else "alpine"
func _process(_delta: float) -> void:
	var state: String=current_style()+"/"+kind
	if state!=_seen:_seen=state;queue_redraw()
func _draw() -> void:
	var style: String=current_style()
	if style!="alpine":
		var key: String=style+"/"+kind
		if not themes.has(key):themes[key]=Assets.station(kind,1,"",style)
		IconArt.paint(self,themes[key],Rect2(2,2,maxf(1,size.x-4),maxf(1,size.y-4)))
		return
	var spec: Dictionary = Catalog.LIFTS[kind]
	var color := Color("b8754f")
	draw_line(Vector2(3, 10), Vector2(39, 6), Color("607f84"), 2, true)
	draw_line(Vector2(21, 8), Vector2(21, 25), Color("b6d2d6"), 2, true)
	if spec.family == "drag":
		draw_line(Vector2(21, 25), Vector2(21, 43), color, 2.5, true)
		_draw_cable_ellipse()
	elif spec.family == "carpet":
		draw_line(Vector2(4, 47), Vector2(39, 24), color, 8, true)
	elif spec.family == "gondola":
		draw_style_box(_box(Color("4e92a4")), Rect2(6, 24, 31, 27))
		draw_rect(Rect2(10, 28, 23, 12), Color("a7d2d8"))
	else:
		var width: float = 10 + minf(spec.seats, 8) * 3.5
		var left := 21 - width * 0.5
		draw_line(Vector2(left, 47), Vector2(left + width, 47), color, 5, true)
		draw_line(Vector2(left, 32), Vector2(left, 47), Color("607f84"), 2, true)
		draw_line(Vector2(left + width, 32), Vector2(left + width, 47), Color("607f84"), 2, true)
		for index in range(spec.seats):
			var x: float = left + (index + 0.5) / spec.seats * width
			draw_line(Vector2(x, 36), Vector2(x, 44), Color("8fc2d3"), maxf(1, width / spec.seats - 1), true)
		draw_string(ThemeDB.fallback_font, Vector2(10, 67), str(spec.seats) + "er", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

func _draw_cable_ellipse() -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle := float(index) / 24 * TAU
		points.append(Vector2(21 + cos(angle) * 10, 45 + sin(angle) * 3))
	draw_colored_polygon(points, Color("b8754f"))

func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(5)
	return box

