extends Control
## A single advertisement composition shared by the 3D world and the preview.
## Supplied original artwork sits UNDER readable, editable event typography.
const Styles=preload("res://src/core/visual_styles.gd")
const Art=preload("res://src/ui/seasonal_poster_art.gd")
const L=preload("res://src/core/i18n.gd")
var style_id: String="alpine"
var campaign: Dictionary={}
var art:=Art.new()
var photo:=TextureRect.new()
var shade:=ColorRect.new()
var headline:=Label.new()
var subtitle:=Label.new()
var caption:=Label.new()
var date_badge:=PanelContainer.new()
var date_text:=Label.new()

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	photo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(photo)
	shade.color=Color("081e30",0.74)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	for label in [headline,subtitle,caption]:
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_color",Color("fffaf0"))
		label.add_theme_color_override("font_outline_color",Color("112332",0.87))
		label.add_theme_constant_override("outline_size",5)
		add_child(label)
	headline.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	add_child(date_badge)
	date_badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	date_badge.add_child(date_text)
	date_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	date_text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	date_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	date_text.add_theme_color_override("font_color",Color("fffbeb"))
	date_text.add_theme_constant_override("outline_size",1)
	resized.connect(_layout)
	_apply()
	_layout()

func configure(style: String,item: Dictionary) -> void:
	style_id=Styles.valid(style)
	campaign=item.duplicate(true)
	if is_node_ready():_apply()

func _apply() -> void:
	art.style_id=style_id
	art.motif=str(campaign.get("motif","trees"))
	art.queue_redraw()
	photo.texture=null
	var file:String=str(campaign.get("image",""))
	if file!="" and ResourceLoader.exists(file):
		photo.texture=load(file) as Texture2D
	photo.visible=photo.texture!=null
	headline.text=L.text(str(campaign.get("title","WINTERWUNDER")))
	subtitle.text=L.text(str(campaign.get("subtitle","Dein Winter am Berg")))
	caption.text=L.text(str(campaign.get("detail","")))
	date_text.text=L.text(str(campaign.get("date","01. DEZ")))
	var palette:Dictionary=Styles.ui_palette(style_id)
	var accent:=Color(str(palette.accent))
	var badge:=StyleBoxFlat.new()
	badge.bg_color=Color("152d43",0.87)
	badge.border_color=accent
	badge.set_border_width_all(2)
	badge.set_corner_radius_all(42)
	badge.set_content_margin_all(10)
	date_badge.add_theme_stylebox_override("panel",badge)
	_layout()

func _layout() -> void:
	if size.x<1 or size.y<1:return
	var w:float=size.x
	var h:float=size.y
	# Dark glass at the bottom keeps real photo details visible above it.
	shade.position=Vector2(0,h*.63)
	shade.size=Vector2(w,h*.37)
	headline.position=Vector2(w*.05,h*.53)
	headline.size=Vector2(w*.87,h*.15)
	headline.add_theme_font_size_override("font_size",clampi(roundi(w*.064),20,52))
	subtitle.position=Vector2(w*.05,h*.69)
	subtitle.size=Vector2(w*.90,h*.10)
	subtitle.add_theme_font_size_override("font_size",clampi(roundi(w*.033),13,28))
	caption.position=Vector2(w*.05,h*.81)
	caption.size=Vector2(w*.90,h*.11)
	caption.add_theme_font_size_override("font_size",clampi(roundi(w*.025),11,22))
	date_badge.position=Vector2(w*.66,h*.07)
	date_badge.size=Vector2(w*.29,h*.16)
	date_badge.pivot_offset=date_badge.size*.5
	date_badge.rotation_degrees=-9
	date_text.add_theme_font_size_override("font_size",clampi(roundi(w*.034),13,29))
