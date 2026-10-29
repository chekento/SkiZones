extends Control
const L = preload("res://src/core/i18n.gd")
## Screen-sized handles stay easy to grab at every camera distance.
const Terrain = preload("res://src/core/terrain.gd")
const COLORS := [Color("68b5ee"), Color("ee7f8e"), Color("455366")]
var game: Node
var _state := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	visible = game.has_game and game.tool in ["piste","lift","building","plaza","walkway"] and not game.hud.menu.visible
	if visible:
		var state := hash([game.tool, game.model.revision, game.points, game.selected_waypoint, game.view.focus, game.view.zoom, game.view.yaw, game.view.pitch_degrees, size, game.hud.map_focus])
		if state != _state:
			_state = state
			queue_redraw()

func pick_waypoint(at: Vector2, radius: float = 24) -> int:
	var selected := -1
	var distance := radius
	if game.tool not in ["piste","lift","building","plaza","walkway"]:
		return selected
	for index in range(game.points.size()):
		var world: Vector3 = game.view.surface_position(Terrain.unpack(game.points[index]))
		if game.view.camera.is_position_behind(world):
			continue
		var candidate: float = game.view.camera.unproject_position(world).distance_to(at)
		if candidate < distance:
			distance = candidate
			selected = index
	return selected

func _draw() -> void:
	if game == null or game.view.camera == null:
		return
	var bounds := Rect2(Vector2.ZERO, size).grow(30)
	for anchor in (game.model.walkway_anchors(game.editing_id) if game.tool == "walkway" else game.model.connection_anchors()):
		if not anchor.has("difficulty"): anchor = anchor.merged({"difficulty":-1})
		if game.tool != "piste" and anchor.difficulty >= 0: continue
		if anchor.point.distance_to(game.view.focus) > maxf(game.view.zoom * 2, 160): continue
		var world: Vector3 = game.view.surface_position(anchor.point)
		if game.view.camera.is_position_behind(world):
			continue
		var at: Vector2 = game.view.camera.unproject_position(world)
		if not bounds.has_point(at):
			continue
		var color: Color = COLORS[anchor.difficulty] if anchor.difficulty >= 0 else Color("efb17d")
		draw_circle(at, 6, Color("f4f9f5"))
		draw_circle(at, 4, color)
		draw_arc(at, 9, 0, TAU, 20, color, 1.5, true)
	for index in range(game.points.size()):
		var point := Terrain.unpack(game.points[index])
		var world: Vector3 = game.view.surface_position(point)
		if game.view.camera.is_position_behind(world):
			continue
		var at: Vector2 = game.view.camera.unproject_position(world)
		var selected: bool = index == game.selected_waypoint
		var color := Color("efb17d") if selected else Color("75cdc7")
		draw_circle(at, 14, Color("173744"))
		draw_arc(at, 14, 0, TAU, 32, color, 2.5, true)
		var text := str(index + 1)
		var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(ThemeDB.fallback_font, at + Vector2(-width / 2, 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		if selected:
			var caption := L.text("%.0f m · ziehen zum Verschieben") % L.args(game.model.terrain.height(point))
			var right_edge: float = size.x - (24 if game.hud.map_focus else 328)
			var label_at := at + Vector2(-246 if at.x + 242 > right_edge else 18, -17)
			draw_style_box(game.hud._style(Color("173744"), 5, 4), Rect2(label_at, Vector2(224, 28)))
			draw_string(ThemeDB.fallback_font, label_at + Vector2(6, 19), caption, HORIZONTAL_ALIGNMENT_LEFT, 214, 12, Color("eaf4ee"))
