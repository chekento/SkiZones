extends Control
## Full-screen ad preview uses the same campaign artwork and live text overlay
## as its corresponding 3D billboard. No freestanding unframed labels.
const Styles=preload("res://src/core/visual_styles.gd")
const Calendar=preload("res://src/core/annual_festival.gd")
const Campaign=preload("res://src/core/seasonal_campaign.gd")
const Card=preload("res://src/ui/seasonal_poster_card.gd")
const L=preload("res://src/core/i18n.gd")
var poster:=Card.new()
var panel:=PanelContainer.new()
var dismiss:=Button.new()
var head:=Label.new()

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil:=ColorRect.new()
	veil.color=Color("071927",0.95)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=10
	panel.offset_top=10
	panel.offset_right=-10
	panel.offset_bottom=-10
	var stack:=VBoxContainer.new()
	stack.add_theme_constant_override("separation",9)
	panel.add_child(stack)
	head.text=L.text("SKIZONES · BERGFESTE")
	head.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size",22)
	stack.add_child(head)
	var holder:=CenterContainer.new()
	holder.size_flags_vertical=Control.SIZE_EXPAND_FILL
	stack.add_child(holder)
	var ratio:=AspectRatioContainer.new()
	ratio.ratio=640.0/420.0
	ratio.stretch_mode=AspectRatioContainer.STRETCH_FIT
	ratio.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	ratio.size_flags_vertical=Control.SIZE_EXPAND_FILL
	holder.add_child(ratio)
	poster.custom_minimum_size=Vector2(250,165)
	poster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ratio.add_child(poster)
	dismiss.text=L.text("Schließen · zurück zur Piste")
	dismiss.custom_minimum_size.y=55
	dismiss.pressed.connect(hide)
	stack.add_child(dismiss)
	hide()

func open(style: String, item: Dictionary = {}) -> void:
	var selected:Dictionary=Campaign.choose(Calendar.device_now(),0) if item.is_empty() else item
	poster.configure(style,selected)
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
