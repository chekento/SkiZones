extends Control
## Illustrated ski plan with a single affine world/map transform for all layers.
const Maps = preload("res://src/core/maps.gd")
const Mountain = preload("res://src/core/mountain.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Styles = preload("res://src/core/visual_styles.gd")
const L = preload("res://src/core/i18n.gd")
const Director = preload("res://src/world/cinematic_tour.gd")
signal expand_requested
signal asset_selected(id: int)
var game: Node
var map_id := "sonnenhang"
var interactive := true
var expanded := false
var map_zoom := 1.0
var map_center := Vector2(0.5,0.5)
var _map: RefCounted
var _seen := ""
var _refresh_time := 0.0
var _draw_state := ""
static var _images: Dictionary = {}
var _background: ImageTexture
var _press := Vector2.ZERO
var _down := false
var _dragged := false
var _alerts: Array=[]
var _expand_button := Button.new()

func _ready() -> void:
	clip_contents=true
	if custom_minimum_size.y<=0: custom_minimum_size.y=150
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	resized.connect(queue_redraw)
	set_process(game!=null)
	if interactive and game!=null and not expanded:
		_expand_button.text="⤢"
		_expand_button.tooltip_text=L.text("Pistenplan vergrößern")
		_expand_button.custom_minimum_size=Vector2(36,30)
		_expand_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_expand_button.offset_left=-40
		_expand_button.offset_right=-4
		_expand_button.offset_top=2
		_expand_button.offset_bottom=32
		add_child(_expand_button)
		_expand_button.pressed.connect(func(): expand_requested.emit())

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_refresh_time+=delta
	if _refresh_time<0.3: return
	_refresh_time=0
	if map_id!=game.model.map_id:
		map_id=game.model.map_id
		reset_plan()
	var state := "%s/%d/%s/%s/%s" % [map_id,game.model.revision,str(game.view.focus),str(game.view.visual_style),str(game.model.minute)]
	if state!=_draw_state:
		_draw_state=state
		_alerts=Director.attention_points(game.model)
		queue_redraw()

func _terrain() -> RefCounted:
	if game!=null: return game.model.terrain
	if _map==null or _map.id!=map_id: _map=Mountain.new(map_id,2)
	return _map

func map_rect() -> Rect2:
	var bounds: Rect2=_terrain().bounds
	var top := 35.0
	var footer := 25.0 if expanded else 20.0
	var available := Rect2(8,top,maxf(1,size.x-16),maxf(1,size.y-top-footer))
	var scale_value: float=minf(available.size.x/bounds.size.x,available.size.y/bounds.size.y)
	var extent: Vector2=bounds.size*scale_value
	return Rect2(available.get_center()-extent*0.5,extent)

func _point(point: Vector2) -> Vector2:
	var bounds: Rect2=_terrain().bounds
	var plan: Rect2=map_rect()
	return plan.get_center()+((point-bounds.position)/bounds.size-map_center)*plan.size*map_zoom

func world_at(point: Vector2) -> Vector2:
	var bounds: Rect2=_terrain().bounds
	var plan: Rect2=map_rect()
	return bounds.position+((point-plan.get_center())/(plan.size*map_zoom)+map_center)*bounds.size

func zoom_by(factor: float, anchor: Vector2 = Vector2.INF) -> void:
	if not is_finite(factor) or factor<=0: return
	if not anchor.is_finite(): anchor=map_rect().get_center()
	var before: Vector2=world_at(anchor)
	map_zoom=clampf(map_zoom*factor,1,5)
	var after: Vector2=world_at(anchor)
	map_center+=(before-after)/_terrain().bounds.size
	map_center=map_center.clamp(Vector2.ZERO,Vector2.ONE)
	queue_redraw()

func reset_plan() -> void:
	map_zoom=1.0
	map_center=Vector2(0.5,0.5)
	queue_redraw()

func _natural(at: Vector2) -> float:
	var terrain: RefCounted=_terrain()
	return terrain.natural_height(at) if terrain.has_method("natural_height") else terrain.height(at)

func _prepare_background(style: String) -> void:
	var terrain: RefCounted=_terrain()
	var key := "%s/%d/%s" % [map_id,terrain.generation,style]
	if _seen==key: return
	_seen=key
	if not _images.has(key):
		var pixels := Image.create(192,144,false,Image.FORMAT_RGB8)
		var palette: Dictionary=Styles.palette(style)
		var light := Vector3(-0.55,0.85,0.2).normalized()
		for y in range(144):
			for x in range(192):
				var at: Vector2=terrain.bounds.position+terrain.bounds.size*Vector2(x/191.0,y/143.0)
				var h: float=_natural(at)
				var dx: float=_natural(at+Vector2(12,0))-_natural(at-Vector2(12,0))
				var dz: float=_natural(at+Vector2(0,12))-_natural(at-Vector2(0,12))
				var normal := Vector3(-dx/24.0,1,-dz/24.0).normalized()
				var color: Color=Color(palette.foliage).lerp(Color(palette.snow),clampf(h/900.0+0.18,0.18,0.95))
				color*=0.72+maxf(0,normal.dot(light))*0.40
				if fposmod(h,80.0)<3.0: color=color.darkened(0.13)
				pixels.set_pixel(x,y,color)
		if _images.size()>=12: _images.erase(_images.keys()[0])
		_images[key]=ImageTexture.create_from_image(pixels)
	_background=_images[key]

func _text_fit(value: String, at: Vector2, width: float, font_size: int, color: Color) -> void:
	var font: Font=get_theme_default_font()
	var text_value: String=value
	while text_value.length()>1 and font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:
		text_value=text_value.left(text_value.length()-2)+"…"
	draw_string(font,at,text_value,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)

func _number(at: Vector2, text_value: String, ink: Color) -> void:
	var radius := 10.0 if expanded else 7.0
	draw_circle(at,radius+1,Color("fffdf7"))
	draw_circle(at,radius,ink)
	var font: Font=get_theme_default_font()
	var fs := 11 if expanded else 9
	var width: float=font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	draw_string(font,at+Vector2(-width*0.5,fs*0.34),text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,Color.WHITE)

func _route(points: Array, color: Color, width: float, closed: bool = false) -> void:
	for i in range(1,points.size()):
		var a: Vector2=_point(Terrain.unpack(points[i-1]))
		var b: Vector2=_point(Terrain.unpack(points[i]))
		draw_line(a,b,Color(1,1,1,0.8),width+2.0,true)
		if closed: draw_dashed_line(a,b,Color(color,0.65),width,5.0)
		else: draw_line(a,b,color,width,true)

func asset_at(pixel: Vector2) -> int:
	if game==null: return -1
	var best := 13.0
	var selected := -1
	for lift in game.model.lifts:
		var a: Vector2=_point(Terrain.unpack(lift.bottom))
		var b: Vector2=_point(Terrain.unpack(lift.top))
		var distance: float=Geometry2D.get_closest_point_to_segment(pixel,a,b).distance_to(pixel)
		if distance<best: best=distance; selected=int(lift.id)
	for piste in game.model.pistes:
		for i in range(1,piste.points.size()):
			var a: Vector2=_point(Terrain.unpack(piste.points[i-1]))
			var b: Vector2=_point(Terrain.unpack(piste.points[i]))
			var distance: float=Geometry2D.get_closest_point_to_segment(pixel,a,b).distance_to(pixel)
			if distance<best: best=distance; selected=int(piste.id)
	return selected

func _draw() -> void:
	if size.x<10 or size.y<10: return
	if game!=null and map_id!=game.model.map_id:
		map_id=game.model.map_id
		reset_plan()
	var style: String=game.view.visual_style if game!=null else "piste_map"
	var dark: bool=style in ["neon_noir","aurora_ink"]
	var paper := Color("172b38") if dark else Color("f5edd8")
	var ink := Color("e7f5f1") if dark else Color("263f4a")
	draw_rect(Rect2(Vector2.ZERO,size),paper)
	_prepare_background(style)
	var rect: Rect2=map_rect()
	var image_rect := Rect2(rect.get_center()-map_center*rect.size*map_zoom,rect.size*map_zoom)
	draw_texture_rect(_background,image_rect,false)
	var width := 4.0 if expanded else 2.0
	var colors := [Color("1676c2"),Color("cb3946"),Color("242a34")]
	if game!=null:
		_route(game.model.portal_path,Color("bb955c"),width*0.7)
		var drawn_labels := 0
		var occupied_labels: Array=[]
		for piste in game.model.pistes:
			if piste.points.size()<2: continue
			var color: Color=colors[clampi(int(piste.difficulty),0,2)]
			var closed: bool=not bool(piste.get("enabled",true)) or float(piste.get("snow",100))<10
			_route(piste.points,color,width,closed)
			var at: Vector2=_point(Terrain.unpack(piste.points[int(piste.points.size()/2)]))
			if rect.has_point(at) and drawn_labels<(24 if expanded else 5) and not occupied_labels.any(func(other): return (other as Vector2).distance_to(at)<(25.0 if expanded else 18.0)):
				_number(at,str(piste.get("number",drawn_labels+1)),color)
				occupied_labels.append(at)
				drawn_labels+=1
		var lift_index := 0
		for lift in game.model.lifts:
			var a: Vector2=_point(Terrain.unpack(lift.bottom))
			var b: Vector2=_point(Terrain.unpack(lift.top))
			var line_ink := Color("d4b476") if dark else Color("5d4a32")
			draw_line(a,b,Color("fffdf7"),width+2,true)
			draw_line(a,b,line_ink,width,true)
			for at in [a,b]:
				draw_rect(Rect2(at-Vector2(3,3),Vector2(6,6)),Color("fffdf7"))
				draw_rect(Rect2(at-Vector2(3,3),Vector2(6,6)),line_ink,false,1)
			if expanded and lift_index<10 and rect.has_point((a+b)*0.5):
				_text_fit(str(lift.name),(a+b)*0.5+Vector2(7,-6),130,12,ink)
				lift_index+=1
		if expanded:
			for building in game.model.buildings:
				var at: Vector2=_point(Terrain.unpack(building.point))
				if not rect.has_point(at): continue
				draw_rect(Rect2(at-Vector2(3,3),Vector2(6,6)),Color("b9884b"))
			for alert in _alerts:
				var at: Vector2=_point(alert.point)
				if rect.has_point(at): _number(at,"!",Color("bb4b23"))
		var camera_point: Vector2=_point(game.view.focus)
		if rect.has_point(camera_point):
			draw_circle(camera_point,7,Color("fffdf7"))
			draw_circle(camera_point,4,Color("f0ad42"))
			var direction := Vector2(-sin(game.view.yaw),-cos(game.view.yaw))
			draw_line(camera_point,camera_point+direction*17,ink,2,true)
	elif map_id in Maps.Geo.IDS:
		for feature in Maps.Geo.data(map_id).features:
			if feature.osm_type!="way" or not feature.tags.has("aerialway") and feature.tags.get("piste:type")!="downhill": continue
			_route(feature.points,Color("8c6442") if feature.tags.has("aerialway") else colors[0],1.2)
	# Draw the printed title and legend last, so zoomed terrain never covers them.
	draw_rect(Rect2(0,0,size.x,34),paper)
	draw_rect(Rect2(0,size.y-23,size.x,23),paper)
	_text_fit(L.text("PISTENPLAN"),Vector2(9,15),maxf(20,size.x-57),11,ink)
	_text_fit(L.text(str(Maps.spec(map_id).name)),Vector2(9,29),maxf(20,size.x-57),10,ink)
	var footer_y: float=size.y-8
	for i in range(3):
		var x: float=9+i*minf(81.0,(size.x-18)/3.0)
		draw_circle(Vector2(x+3,footer_y-3),3,colors[i])
		if size.x>190: draw_string(get_theme_default_font(),Vector2(x+10,footer_y),L.text(["Blau","Rot","Schwarz"][i]),HORIZONTAL_ALIGNMENT_LEFT,-1,10,ink)
	if expanded: _text_fit(L.text("Gestrichelt: geschlossen · !: Aufmerksamkeit"),Vector2(268,footer_y),maxf(1,size.x-275),11,ink)
	draw_rect(Rect2(Vector2.ZERO,size),ink,false,1.5)
	draw_string(get_theme_default_font(),rect.position+Vector2(5,14),"N ↑",HORIZONTAL_ALIGNMENT_LEFT,-1,11,ink)

func _navigate(pixel: Vector2) -> void:
	if not map_rect().has_point(pixel): return
	var at: Vector2=world_at(pixel)
	if not _terrain().contains(at): return
	if game.view.tour.active: game.stop_cinematic_tour()
	game.view.follow_guest=-1
	game.view.focus=at
	game.view.zoom=minf(game.view.zoom,900)
	game.view._update_camera()
	if expanded:
		var id: int=asset_at(pixel)
		if id>=0: asset_selected.emit(id)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not interactive or game==null: return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_by(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.2,event.position)
			accept_event()
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press=event.position
				_down=true
				_dragged=false
			elif _down:
				_down=false
				if not _dragged:
					if event.double_click and not expanded: expand_requested.emit()
					else: _navigate(event.position)
			accept_event()
	elif event is InputEventMouseMotion and _down:
		if event.position.distance_to(_press)>7: _dragged=true
		if _dragged:
			map_center=(map_center-event.relative/(map_rect().size*map_zoom)).clamp(Vector2.ZERO,Vector2.ONE)
			queue_redraw()
		accept_event()
	elif event is InputEventMagnifyGesture:
		zoom_by(event.factor,event.position)
		accept_event()
