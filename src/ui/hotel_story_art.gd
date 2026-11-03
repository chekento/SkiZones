extends Control
## Five original, sharp vector tableaux with independent depth planes.
## Artist-provided PMDD stills can replace each tableau later without touching
## the hotel game's decisions, saves or guest handling.
const VisualStyles = preload("res://src/core/visual_styles.gd")
const SCENE_IDS := ["arrival","room","breakfast","service","farewell"]
var scene_id := "arrival"
var style_id := "alpine"
var character_mood := 0
var time := 0.0
var _cached: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	time += delta
	queue_redraw()

func _material(path: String) -> Texture2D:
	if not _cached.has(path):
		_cached[path] = load(path) if ResourceLoader.exists(path) else null
	return _cached[path]

func _draw() -> void:
	var scale_value := Vector2(size.x / 640.0,size.y / 270.0)
	if scale_value.x < 0.01 or scale_value.y < 0.01: return
	var art_path := "res://assets/hotel_story/%s/%s.webp" % [VisualStyles.valid(style_id),scene_id]
	var still := _material(art_path)
	if still != null:
		# Exact-size generated PMDD frames remain crisp; no blur is applied.
		draw_texture_rect(still,Rect2(Vector2.ZERO,size),false)
		return
	var ui: Dictionary = VisualStyles.ui_palette(style_id)
	var accent := Color(str(ui.accent))
	var shadow := Color(str(ui.shadow))
	var wall := Color("c8b18e")
	var wood := Color("7f5944")
	var snow := Color("f9fcff")
	match style_id:
		"comic":
			wall=Color("ffca75");wood=Color("9a4b4e")
		"pastel":
			wall=Color("f8d8d9");wood=Color("a986ac")
		"cinematic":
			wall=Color("8a857b");wood=Color("433f43");snow=Color("ccd9e4")
		"crisp":
			wall=Color("d8e8f6");wood=Color("506e8e")
	draw_set_transform(Vector2.ZERO,0.0,scale_value)
	# BACK PLANE: distant mountains move slowly, window mullions do not.
	draw_rect(Rect2(0,0,640,270),wall)
	var shift := sin(time*0.6)*3.5
	draw_rect(Rect2(390,22,206,141),Color("8ebad4") if style_id != "pastel" else Color("bbaed9"))
	draw_colored_polygon(PackedVector2Array([Vector2(394+shift,146),Vector2(431+shift,78),Vector2(471+shift,140),Vector2(513+shift,59),Vector2(581+shift,143),Vector2(598,163),Vector2(394,163)]),Color("657e96") if style_id != "comic" else Color("568aca"))
	draw_colored_polygon(PackedVector2Array([Vector2(431+shift,78),Vector2(447+shift,108),Vector2(420+shift,98)]),snow)
	draw_colored_polygon(PackedVector2Array([Vector2(513+shift,59),Vector2(535+shift,93),Vector2(496+shift,85)]),snow)
	for i in range(6):
		var px := float(404+i*31) + sin(time*.32+i)*4
		draw_circle(Vector2(px,120+sin(time+i)*11),1.9,snow)
	# MIDDLE PLANE: the alpine interior stays anchored to the camera.
	draw_rect(Rect2(0,174,640,96),wood.darkened(0.22))
	draw_rect(Rect2(0,170,640,6),wood.lightened(0.16))
	for x in [386,598]:
		draw_rect(Rect2(x,17,9,152),wood)
	for y in [16,163]:
		draw_rect(Rect2(385,y,220,8),wood)
	draw_rect(Rect2(485,22,6,141),wood)
	draw_rect(Rect2(391,90,208,6),wood)
	# A round ceiling lamp and wall decor reinforce miniature scale.
	draw_line(Vector2(270,0),Vector2(270,25),shadow,4)
	draw_circle(Vector2(270,34),24,accent.darkened(0.18))
	draw_circle(Vector2(270,34),13,accent)
	if scene_id == "arrival" or scene_id == "farewell":
		# Reception desk, bell and luggage.
		draw_rect(Rect2(48,137,245,91),wood)
		draw_rect(Rect2(41,132,259,14),wood.lightened(0.20))
		draw_circle(Vector2(114,125),10,accent)
		draw_line(Vector2(105,127),Vector2(123,127),shadow,3)
		draw_rect(Rect2(327,184,48,42),Color("a46769"))
		draw_rect(Rect2(337,175,30,9),accent)
		draw_line(Vector2(343,175),Vector2(343,169),shadow,3)
		draw_line(Vector2(343,169),Vector2(361,169),shadow,3)
	elif scene_id == "room":
		draw_rect(Rect2(76,133,273,88),wood)
		draw_rect(Rect2(68,155,294,67),snow)
		draw_rect(Rect2(78,147,104,33),Color("d9b7ac"))
		draw_rect(Rect2(80,180,275,11),accent.lightened(0.35))
		draw_rect(Rect2(25,113,41,87),wood)
		draw_circle(Vector2(45,102),17,accent)
	elif scene_id == "breakfast":
		draw_rect(Rect2(70,161,325,61),wood)
		draw_rect(Rect2(59,156,347,16),Color("fff5de"))
		for x in [112,171,230,293,353]:
			draw_circle(Vector2(x,155),19,accent if x%2==0 else Color("eab67d"))
			draw_circle(Vector2(x,151),12,Color("f9e6a6"))
		draw_rect(Rect2(430,176,125,20),wood)
		for x in [454,495,537]: draw_circle(Vector2(x,174),13,Color("fff1d5"))
	elif scene_id == "service":
		draw_rect(Rect2(65,105,92,111),wood)
		draw_rect(Rect2(76,113,70,72),snow)
		draw_rect(Rect2(215,170,152,57),wood)
		draw_rect(Rect2(245,154,46,30),Color("8bb6ba"))
		draw_line(Vector2(292,161),Vector2(309,142),accent,6)
		draw_rect(Rect2(421,180,90,39),wood.lightened(0.2))
		draw_circle(Vector2(450,174),15,accent)
		draw_circle(Vector2(483,174),15,accent)
	# FRONT PLANE: consistent cute silhouettes with independent animation.
	var bob := sin(time*2.1)*2
	if scene_id == "arrival":
		_person(Vector2(448,186+bob),Color("bc6577"),true)
		_person(Vector2(521,195-bob),Color("6b9bb9"),false)
		_person(Vector2(565,211+bob),Color("d8a55d"),true,0.67)
		_person(Vector2(204,128),Color("5b877c"),false,0.8)
	elif scene_id == "room":
		_person(Vector2(420,202+bob),Color("bb6b8f"),true)
		_person(Vector2(501,217-bob),Color("6f9fba"),false,0.82)
	elif scene_id == "breakfast":
		_person(Vector2(449,214+bob),Color("bd718f"),true)
		_person(Vector2(524,219-bob),Color("4c9fa6"),false)
	elif scene_id == "service":
		_person(Vector2(400,217+bob),Color("6d97bd"),false)
		_person(Vector2(532,215-bob),Color("c67977"),true)
	else:
		_person(Vector2(444,198+bob),Color("c77989"),true)
		_person(Vector2(532,198-bob),Color("5e97b8"),false)
		draw_circle(Vector2(600,44),11,accent)
	# Unobtrusive depth trim. Never blur any plane.
	draw_rect(Rect2(0,260,640,10),accent.darkened(0.15))
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _person(at: Vector2, coat: Color, bonnet: bool, scale_factor: float = 1.0) -> void:
	# Cartoony individual faces and scarves, consistently sharp at every plane.
	var u := scale_factor
	draw_ellipse_placeholder(at+Vector2(0,3)*u,22*u,6*u)
	draw_rect(Rect2(at+Vector2(-13,-32)*u,Vector2(26,36)*u),coat)
	draw_circle(at+Vector2(0,-41)*u,18*u,Color("f3ccac"))
	draw_circle(at+Vector2(-6,-43)*u,1.7*u,Color("35394a"))
	draw_circle(at+Vector2(6,-43)*u,1.7*u,Color("35394a"))
	draw_line(at+Vector2(-4,-36)*u,at+Vector2(4,-36)*u,Color("a65d62"),2*u,true)
	draw_rect(Rect2(at+Vector2(-13,-29)*u,Vector2(26,6)*u),Color("f3d2a3"))
	if bonnet:
		draw_circle(at+Vector2(0,-59)*u,6*u,Color("f6ece3"))
		draw_rect(Rect2(at+Vector2(-19,-61)*u,Vector2(38,12)*u),coat.darkened(0.15))
	else:
		draw_rect(Rect2(at+Vector2(-14,-60)*u,Vector2(28,11)*u),Color("554b52"))

func draw_ellipse_placeholder(at: Vector2, w: float, h: float) -> void:
	draw_circle(at,w,Color(0.03,0.06,0.12,0.15),true,-1.0,false)
