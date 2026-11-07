extends SceneTree
const Saves=preload("res://src/core/save_store.gd")
const Resort=preload("res://src/core/resort.gd")
var passed:=0
var failed:=0
func _init() -> void:call_deferred("run")
func check(ok:bool,title:String) -> void:
	if ok:passed+=1;print("PASS ",title)
	else:failed+=1;push_error("FAIL "+title)
func settle() -> void:
	for i in range(8):await process_frame
func contrast(foreground:Color,background:Color) -> float:
	var f:float=foreground.srgb_to_linear().get_luminance()
	var b:float=background.srgb_to_linear().get_luminance()
	return (maxf(f,b)+0.05)/(minf(f,b)+0.05)
func audit_buttons(node:Node) -> bool:
	var readable:=true
	if node is Button and not node.text.is_empty():
		for pair in [["normal","font_color"],["hover","font_hover_color"],["pressed","font_pressed_color"],["normal","font_focus_color"],["disabled","font_disabled_color"]]:
			var style:StyleBox=node.get_theme_stylebox(pair[0])
			if style is StyleBoxFlat and style.bg_color.a>0.95:
				var ratio:float=contrast(node.get_theme_color(pair[1]),style.bg_color)
				if ratio<4.5:print("LOW CONTRAST ",node.text," ",pair," ",ratio);readable=false
	for child in node.get_children():readable=audit_buttons(child) and readable
	return readable
func capture(name:String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/"+name+".png")
func run() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("skizones-test-readable-0382"):quit(1);return
	var sample:=Resort.new();sample.new_game(true)
	for i in range(6):sample.admit_guest(2)
	for slot in range(1,5):Saves.save_game(sample,Saves.path_for_map("sonnenhang",slot))
	var free_sample:=Resort.new();free_sample.new_game(false)
	Saves.save_game(free_sample,Saves.path_for_map("sonnenhang",0,2))
	var game:Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);await settle()
	game.set_process(false);game.view.set_process(false);game.view.hide()
	# Exercise the real UI callback on a recoverable primary, not just the API.
	var damaged:Dictionary=sample.snapshot()
	damaged.guests[0].route_index=999999
	var payload:String=JSON.stringify(damaged,"",true,true)
	var file:=FileAccess.open(Saves.path_for_map("sonnenhang",3),FileAccess.WRITE)
	file.store_string(JSON.stringify({"format":"SkiZones","checksum":payload.sha256_text(),"payload":payload}));file.close()
	if FileAccess.file_exists(Saves.path_for_map("sonnenhang",3)+".bak"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Saves.path_for_map("sonnenhang",3)+".bak"))
	game.hud.career_slots.open();await settle()
	game.hud.career_slots.cards.get_child(2).find_child("rescue_save_038",true,false).pressed.emit();await settle()
	var repaired:=Resort.new()
	var recovery:Dictionary=Saves.load_game(repaired,Saves.path_for_map("sonnenhang",3))
	check(recovery.ok and not recovery.get("recovered",false) and repaired.guests.is_empty(),"Actual repair button writes a normally loadable recovered primary")
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=Vector2i.ZERO
	for language in ["de","en"]:
		game.apply_language(language);await settle()
		for viewport in [Vector2i(1536,709),Vector2i(360,740),Vector2i(420,860),Vector2i(740,360)]:
			root.size=viewport;await settle()
			var career:Control=game.hud.career_slots
			career.open();await settle()
			check(career.heading_label.is_visible_in_tree() and career.heading_label.size.x>=150 and career.close_button.text==game.hud.L.text("Zurück"),"Career heading and labelled Back action remain visible")
			var card:Control=career.cards.get_child(0)
			var grid:GridContainer=card.find_child("save_manager_actions",true,false)
			var visible_labels:=true
			for action in grid.get_children():
				var button:Button=action
				visible_labels=visible_labels and not button.text.is_empty() and button.autowrap_mode!=TextServer.AUTOWRAP_OFF and button.size.x>=144 and button.size.y>=50
				visible_labels=visible_labels and button.get_global_rect().position.x>=0 and button.get_global_rect().end.x<=float(viewport.x)
				var font:Font=button.get_theme_font("font")
				var caption_size:Vector2=font.get_multiline_string_size(button.text,HORIZONTAL_ALIGNMENT_CENTER,button.size.x-20,button.get_theme_font_size("font_size"))
				visible_labels=visible_labels and caption_size.y+20<=button.size.y+2
				for state in ["font_color","font_focus_color","font_hover_color","font_pressed_color"]:
					visible_labels=visible_labels and button.get_theme_color(state).srgb_to_linear().get_luminance()<0.15
			check(visible_labels,"All four save actions have readable captions and usable bounds: %s %s" % [language,viewport])
			check(grid.columns==(2 if grid.size.x>=310 else 1),"Save actions adapt to the actual card width")
			check(card.find_child("archive_save_038",true,false).text==game.hud.L.text("Löschen & sichern"),"Removal explicitly names deletion and backup")
			if language=="de":await capture("save-manager-0382-%dx%d" % [viewport.x,viewport.y])
			career._request_archive("sonnenhang",1,1);await settle()
			var dialog:ConfirmationDialog=career.archive_confirmation
			dialog.get_ok_button().grab_focus();await settle()
			var dialog_fits:bool=dialog.size.x<=viewport.x and dialog.size.y<=viewport.y and dialog.position.x>=0 and dialog.position.y>=0
			for button in [dialog.get_ok_button(),dialog.get_cancel_button()]:
				dialog_fits=dialog_fits and not button.text.is_empty() and button.size.y>=50 and button.get_theme_color("font_focus_color").srgb_to_linear().get_luminance()<0.15
			check(dialog_fits,"Focused confirmation and cancel captions fit the viewport: %s %s" % [language,viewport])
			check(dialog.cancel_button_text==game.hud.L.text("Abbrechen"),"Confirmation cancellation uses the selected language")
			if language=="de":await capture("save-confirmation-0382-%dx%d" % [viewport.x,viewport.y])
			dialog.hide();career.hide()
			for information in [game.hud.help_dialog,game.hud.credits,game.hud.community]:
				game.hud.present_dialog(information,Vector2i(760,520));await settle()
				check(information.size.x<=viewport.x and information.size.y<=viewport.y and information.get_ok_button().size.y>=50,"Help, credits or community dialog fits %s" % viewport)
				information.hide()
			career.open_free();await settle()
			var free_fits:=true
			for button in career.cards.find_children("*","Button",true,false):
				free_fits=free_fits and button.get_global_rect().position.x>=0 and button.get_global_rect().end.x<=float(viewport.x)
			check(free_fits,"Free-build cards and their captions fit the same viewport")
			career.hide()
			game.hud.management._credit_confirmation({"ok":true,"principal":10000,"days":28,"annual_rate":0.05,"total_interest":200,"max_payment":500})
			await settle()
			var credit:ConfirmationDialog=game.hud.management.get_children()[-1]
			check(credit.size.x<=viewport.x and credit.size.y<=viewport.y,"Loan confirmation uses readable labels inside the viewport")
			credit.queue_free();await settle()
			game.hud.lift_staff._demolish();await settle()
			var demolition:ConfirmationDialog=game.hud.lift_staff.get_children()[-1]
			check(demolition.size.x<=viewport.x and demolition.size.y<=viewport.y,"Demolition confirmation uses readable labels inside the viewport")
			demolition.queue_free();await settle()
			check(audit_buttons(game.hud),"Shared menu and dialog button states have at least 4.5:1 text contrast")
	game.queue_free();await settle()
	print("RESULT: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
