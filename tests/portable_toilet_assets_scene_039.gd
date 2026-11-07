extends SceneTree
const Assets=preload("res://src/world/style_assets.gd")
const Styles=preload("res://src/core/visual_styles.gd")
const Development=preload("res://src/core/wc_development.gd")
class Preview extends Control:
	const Painter=preload("res://src/ui/asset_icon_art.gd")
	var mesh:ArrayMesh
	func _draw() -> void:Painter.paint(self,mesh,Rect2(Vector2(8,5),size-Vector2(16,10)))
func _init() -> void:call_deferred("run")
func run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(1400,850)
	var background:=ColorRect.new();background.color=Color("fffaf2");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(background)
	var content:=VBoxContainer.new();background.add_child(content);content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left=24;content.offset_top=18;content.offset_right=-24;content.offset_bottom=-18
	var heading:=Label.new();heading.text="PORTABLE TOILET · 5 AUSBAUSTUFEN";heading.add_theme_font_size_override("font_size",30);heading.add_theme_color_override("font_color",Color("294d54"));content.add_child(heading)
	var grid:=GridContainer.new();grid.columns=5;grid.size_flags_vertical=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",12);content.add_child(grid)
	var passed:=0;var failed:=0
	for style in Styles.IDS:
		var previous:float=0
		for level in range(1,6):
			var mesh:ArrayMesh=Assets.building("wc_dixi",level,Color("278fc6"),style)
			if mesh.get_aabb().size.x>previous:passed+=1
			else:failed+=1;push_error("Stage mesh does not grow: "+style)
			previous=mesh.get_aabb().size.x
			if style not in ["alpine","monochrome"]:continue
			var card:=VBoxContainer.new();card.custom_minimum_size.x=250;card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;card.size_flags_vertical=Control.SIZE_EXPAND_FILL;grid.add_child(card)
			var preview:=Preview.new();preview.mesh=mesh;preview.custom_minimum_size=Vector2(240,290);preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;card.add_child(preview)
			var label:=Label.new();label.text="%d · %s\n%d Plätze · %.0f Nutzungen" % [level,Development.STAGES[level-1].name,Development.STAGES[level-1].places,Development.STAGES[level-1].volume];label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_color_override("font_color",Color("294d54"));label.add_theme_font_size_override("font_size",17);card.add_child(label)
	for frame in range(8):await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/portable-toilet-stages-039.png")
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
