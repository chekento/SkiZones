extends SceneTree
const Features=preload("res://src/core/piste_features.gd")
const DragScroll=preload("res://src/ui/drag_scroll.gd")
var passed:=0
var failed:=0
var game:Node
func _init()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;push_error("FAIL "+label)
func settle()->void:
	for i in range(4):await process_frame
func touch(at:Vector2,pressed:bool)->void:
	var event:=InputEventScreenTouch.new();event.index=0;event.position=root.get_screen_transform()*at;event.pressed=pressed
	Input.parse_input_event(event);await process_frame
func drag(at:Vector2,from:Vector2)->void:
	var event:=InputEventScreenDrag.new();event.index=0;event.position=root.get_screen_transform()*at;event.relative=root.get_screen_transform().basis_xform(at-from)
	Input.parse_input_event(event);await process_frame
func run()->void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await settle()
	game.start_game(true);game.set_process(false);game.view.set_process(false);game.paused=true
	game.model.campaign.mode="free";game.hud.hide_menu()
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
	for language in ["de","en"]:
		game.apply_language(language);game.hud.hide_menu()
		for size_value in [Vector2i(360,740),Vector2i(420,860),Vector2i(740,360)]:
			root.size=size_value;await settle()
			var ui:Control=game.hud.piste_workshop
			var piste:Dictionary=game.model.pistes[0]
			ui.open(int(piste.id));await settle()
			check(ui.kind.item_count==20,language+str(size_value)+": all twenty real modules are selectable")
			check(Rect2(Vector2.ZERO,Vector2(size_value)).grow(1).encloses(ui.window.get_global_rect()),language+str(size_value)+": workshop stays within phone screen")
			check(Rect2(Vector2.ZERO,Vector2(size_value)).grow(1).encloses(ui.window.close_button.get_global_rect()),language+str(size_value)+": close control remains reachable")
			ui.kind.select(Features.KINDS.find("box"));ui.kind.item_selected.emit(ui.kind.selected)
			var scroll:ScrollContainer=ui.diagram.get_parent().get_parent()
			scroll.scroll_vertical=0;await settle()
			var rect:Rect2=ui.diagram.get_global_rect()
			var begin:Vector2=rect.position+Vector2(rect.size.x*0.40,35)
			var finish:Vector2=rect.position+Vector2(rect.size.x*0.65,75)
			var points:Array=game.points.duplicate(true)
			await touch(begin,true);await drag(finish,begin);await touch(finish,false);await settle()
			check(ui.position_slider.value>55 and absf(ui.lateral_slider.value)>0.5,language+str(size_value)+": actual finger drag positions the module in both axes")
			check(scroll.scroll_vertical==0 and not DragScroll.dragging_any,language+str(size_value)+": placing the module never scrolls its parent page")
			check(game.points==points,language+str(size_value)+": workshop gestures never add world construction points")
			ui.rotation_slider.value=10;ui.scale_slider.value=110;await settle()
			var preview:Node3D=game.view.preview_root.get_child(0)
			check(absf(preview.transform.basis.x.length()-1.1)<0.01,language+str(size_value)+": size slider scales the actual 3D preview")
			var expected:Transform3D=game.view._feature_transform(piste,{"kind":"box","fraction":ui.position_slider.value/100,"lateral":ui.lateral_slider.value,"rotation":10.0,"scale":1.1})
			check(preview.transform.is_equal_approx(expected),language+str(size_value)+": rotation, size and placement share the world transform")
			if language=="de" and size_value==Vector2i(420,860):
				ui.position_slider.value=50;ui.lateral_slider.value=0;ui.rotation_slider.value=0;ui.scale_slider.value=100
				ui._refresh();ui.install_button.pressed.emit();await settle()
				check(piste.get("features",[]).size()==1,"Actual install button builds the selected box")
				if piste.get("features",[]).size()==1:
					var select:Button=ui.list.get_child(0).get_child(0).get_child(0)
					select.pressed.emit();await settle()
					var money:float=game.model.money
					ui.duplicate_button.pressed.emit();await settle()
					check(ui.selected_index==-1 and piste.features.size()==1 and game.model.money==money,"Duplicate opens a new preview without spending or replacing the original")
					check(not ui.install_button.disabled,"Duplicate proposes a non-overlapping next section")
					ui.install_button.pressed.emit();await settle()
					check(piste.features.size()==2,"Confirming the duplicate builds a second independent module")
					piste.features=[];game.model.revision+=1
			if DisplayServer.get_name()!="headless":
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://build/qa")
				root.get_texture().get_image().save_png("res://build/qa/snowpark-workshop-%s-%d-%d.png" % [language,size_value.x,size_value.y])
			ui.close();await settle()
	game.queue_free();await settle()
	print("RESULT: %d passed; %d failed" % [passed,failed]);quit(1 if failed else 0)
