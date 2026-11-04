extends Control
## Full-screen, accessible poster preview. Original artwork is preferred when
## it becomes available; the fallback is visibly an original replacement.
const Styles=preload("res://src/core/visual_styles.gd")
const L=preload("res://src/core/i18n.gd")
const Fallback=preload("res://src/ui/seasonal_poster_art.gd")
const ORIGINAL_PATH="res://assets/seasonal/christmas_poster_original.webp"
var fallback:=Fallback.new()
var picture:=TextureRect.new()
var panel:=PanelContainer.new()
var dismiss:=Button.new()
var head:=Label.new()

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil:=ColorRect.new()
	veil.color=Color(0.018,0.034,0.055,0.94)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=10
	panel.offset_top=10
	panel.offset_right=-10
	panel.offset_bottom=-10
	var stack:=VBoxContainer.new()
	stack.add_theme_constant_override("separation",7)
	panel.add_child(stack)
	head.text=L.text("SKIZONES · DER WINTER KOMMT")
	head.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	head.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_size_override("font_size",22)
	stack.add_child(head)
	var holder:=Control.new()
	holder.size_flags_vertical=Control.SIZE_EXPAND_FILL
	stack.add_child(holder)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	holder.add_child(picture)
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(fallback)
	dismiss.text=L.text("Schließen · zurück zur Piste")
	dismiss.custom_minimum_size.y=55
	dismiss.pressed.connect(hide)
	stack.add_child(dismiss)
	if ResourceLoader.exists(ORIGINAL_PATH):
		picture.texture=load(ORIGINAL_PATH) as Texture2D
	picture.visible=picture.texture!=null
	fallback.visible=not picture.visible
	hide()

func open(style: String) -> void:
	fallback.style_id=Styles.valid(style)
	fallback.queue_redraw()
	var accent:=Color(str(Styles.ui_palette(style).accent))
	var panel_style:=StyleBoxFlat.new()
	panel_style.bg_color=Color("0e1a2b")
	panel_style.border_color=accent
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel",panel_style)
	head.add_theme_color_override("font_color",accent)
	show()
