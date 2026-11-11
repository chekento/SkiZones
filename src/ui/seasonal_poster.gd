extends Control
## Full-screen, accessible poster preview. Original artwork is preferred when
## it becomes available; the fallback is visibly an original replacement.
const Styles=preload("res://src/core/visual_styles.gd")
const L=preload("res://src/core/i18n.gd")
const Fallback=preload("res://src/ui/seasonal_poster_art.gd")
const Calendar=preload("res://src/core/annual_festival.gd")
const Posters=preload("res://src/core/holiday_poster_catalog.gd")
var fallback:=Fallback.new()
var picture:=TextureRect.new()
var panel:=PanelContainer.new()
var dismiss:=Button.new()
var head:=Label.new()
var image_overlay:=Label.new()
var discovery_text:=Label.new()
var discovery_bar:=ProgressBar.new()
var selected_artwork: String=""

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
	# Short, translated headline on top of the texture; text is never embedded
	# in the WebP and can switch languages without regenerating any artwork.
	holder.add_child(image_overlay)
	image_overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	image_overlay.offset_left=15
	image_overlay.offset_top=16
	image_overlay.offset_right=-15
	image_overlay.offset_bottom=70
	image_overlay.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	image_overlay.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	image_overlay.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	image_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	image_overlay.add_theme_font_size_override("font_size",25)
	image_overlay.add_theme_color_override("font_color",Color("fff4df"))
	image_overlay.add_theme_color_override("font_outline_color",Color("10223f"))
	image_overlay.add_theme_constant_override("outline_size",8)
	discovery_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	discovery_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	discovery_text.add_theme_font_size_override("font_size",18)
	stack.add_child(discovery_text)
	discovery_bar.custom_minimum_size.y=12
	discovery_bar.show_percentage=false
	discovery_bar.min_value=0
	stack.add_child(discovery_bar)
	dismiss.text=L.text("Schließen · zurück zur Piste")
	dismiss.custom_minimum_size.y=55
	dismiss.pressed.connect(hide)
	stack.add_child(dismiss)
	_refresh_art()
	hide()

func _refresh_art() -> void:
	var now: Dictionary=Calendar.device_now()
	var phase: String="november_poster" if Calendar.preview_poster(now) else Calendar.season(now)
	var originals: Array=Posters.available(phase)
	var display_path: String=selected_artwork if selected_artwork in originals else str(originals[0]) if not originals.is_empty() else ""
	picture.texture=load(display_path) as Texture2D if not display_path.is_empty() else null
	picture.visible=picture.texture!=null
	fallback.phase=phase
	fallback.visible=not picture.visible
	fallback.queue_redraw()
	image_overlay.text=Posters.headline(phase,display_path) if picture.visible else ""
	head.text=L.text("SKIZONES · SILVESTER UND NEUJAHR") if phase in ["new_year_eve","new_year"] else L.text("SKIZONES · WEIHNACHTSWERBUNG") if phase=="november_poster" else L.text("SKIZONES · ADVENT UND WEIHNACHTEN")

func open(style: String, artwork: String = "", found: int = 0, total: int = 10) -> void:
	selected_artwork=artwork
	discovery_text.text=L.text("Plakatsammlung: %d von %d entdeckt") % L.args([found,total])
	discovery_bar.max_value=maxi(1,total)
	discovery_bar.value=clampi(found,0,total)
	_refresh_art()
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
