extends Control
const Maps = preload("res://src/core/maps.gd")
const Mountain = preload("res://src/core/mountain.gd")
const Terrain = preload("res://src/core/terrain.gd")
var game: Node
var map_id := "sonnenhang"
var interactive := true
var _map: RefCounted
var _seen := ""
var _refresh_time := 0.0
var _draw_state := ""
static var _images: Dictionary = {}
var _background: ImageTexture

func _ready() -> void:
	if custom_minimum_size.y <= 0:
		custom_minimum_size.y = 112
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	set_process(game != null)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_refresh_time += delta
	if _refresh_time < 0.15: return
	_refresh_time = 0
	map_id = game.model.map_id
	var state := "%s/%d/%s" % [map_id, game.model.revision, str(game.view.focus)]
	if state != _draw_state:
		_draw_state = state
		queue_redraw()

func _point(point: Vector2) -> Vector2:
	return (point - _map.bounds.position) / _map.bounds.size * size

func _draw() -> void:
	var generation: int = game.model.terrain_generation if game != null else 2
	var cache_key := "%s/%d" % [map_id, generation]
	if _seen != cache_key:
		_map = Mountain.new(map_id, generation)
		_seen = cache_key
		if not _images.has(cache_key):
			var pixels := Image.create(128, 96, false, Image.FORMAT_RGB8)
			var light := Vector3(-0.5, 0.8, 0.3).normalized()
			for y in range(96):
				for x in range(128):
					var point: Vector2 = _map.bounds.position + _map.bounds.size * Vector2(x / 127.0, y / 95.0)
					var h: float = _map.height(point)
					var dx: float = _map.height(point + Vector2(12, 0)) - _map.height(point - Vector2(12, 0))
					var dz: float = _map.height(point + Vector2(0, 12)) - _map.height(point - Vector2(0, 12))
					var normal := Vector3(-dx / 24, 1, -dz / 24).normalized()
					var color := Color("315b64").lerp(Color("dbe9eb"), clampf(h / 1500, 0, 1))
					color *= 0.65 + maxf(0, normal.dot(light)) * 0.55
					if fmod(h, 120) < 5:
						color = color.darkened(0.13)
					pixels.set_pixel(x, y, color)
			_images[cache_key] = ImageTexture.create_from_image(pixels)
		_background = _images[cache_key]
	draw_texture_rect(_background, Rect2(Vector2.ZERO, size), false)
	if game != null:
		for piste in game.model.pistes:
			for i in range(1, piste.points.size()):
				draw_line(_point(Terrain.unpack(piste.points[i - 1])), _point(Terrain.unpack(piste.points[i])), [Color("7cc4f2"), Color("e88790"), Color("b9a9da")][piste.difficulty], 2)
		for lift in game.model.lifts:
			draw_line(_point(Terrain.unpack(lift.bottom)), _point(Terrain.unpack(lift.top)), Color("efb17d"), 2)
		var camera_point := _point(game.view.focus)
		draw_circle(camera_point, 4, Color("f5c696"))
		draw_arc(camera_point, 7, 0, TAU, 20, Color.WHITE, 1)
	draw_rect(Rect2(Vector2.ZERO, size), Color("477482"), false, 1)
	draw_string(get_theme_default_font(), Vector2(6, 14), "N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d8e6eb"))

func _gui_input(event: InputEvent) -> void:
	if not interactive or game == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		game.view.follow_guest = -1
		game.view.focus = _map.bounds.position + event.position / size * _map.bounds.size
		game.view.zoom = minf(game.view.zoom, 900)
		game.view._update_camera()
		accept_event()
