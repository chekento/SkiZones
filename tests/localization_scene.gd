extends SceneTree
const L=preload("res://src/core/i18n.gd")
const Preferences=preload("res://src/core/preferences.gd")
var game: Node
var passed:=0
var failed:=0
func _init() -> void: call_deferred("run")
func check(ok: bool,title: String) -> void:
	if ok: passed+=1;print("PASS ",title)
	else: failed+=1;push_error("FAIL "+title)
func texts(node: Node) -> Array:
	var result: Array=[]
	if node is Label or node is Button or node is RichTextLabel or node is Label3D: result.append(str(node.text))
	if node is OptionButton:
		for index in range(node.item_count): result.append(node.get_item_text(index))
	if node is Window: result.append(node.title)
	if node is TabContainer:
		for index in range(node.get_tab_count()): result.append(node.get_tab_title(index))
	for child in node.get_children(): result.append_array(texts(child))
	return result
func english_only(node: Node) -> bool:
	var words:=RegEx.new()
	words.compile("\\b(Bauen|Abbrechen|Pisten|Aufträge|Forschung|Rückweg|Tageskarte|Darstellung|Wärmegefühl|Gäste|Ausbauen|Finanzen|Plätze|Gebiet|Berghütte|Skiverleih)\\b|[äöüßÄÖÜ]")
	var leaks: Array=[]
	for text in texts(node):
		if words.search(text): leaks.append(text.left(180))
	if not leaks.is_empty(): print("UNTRANSLATED UI: ",leaks)
	return leaks.is_empty()
func capture(name: String) -> void:
	for index in range(4): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/qa")
	root.get_texture().get_image().save_png("res://build/qa/"+name+".png")
func run() -> void:
	check(L.locale_for("de-DE")=="de" and L.locale_for("de_CH")=="de","German system locales select German, including Switzerland")
	check(L.locale_for("en_US")=="en" and L.locale_for("en-GB")=="en" and L.locale_for("fr_FR")=="en","English variants and unsupported system languages select complete English")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.set_process(false);game.preferences.path="user://localization-test-display.cfg"
	var arguments:=OS.get_cmdline_args();var index:=arguments.find("--language")
	var expected:=L.locale_for(arguments[index+1] if index>=0 else OS.get_locale())
	check(L.language==expected,"The actual startup interface follows the system or Godot locale override")
	game.apply_language("en");await process_frame
	check(game.hud.continue_button.text.begins_with("Continue") and game.hud.display_options.language_choice.item_count==3,"The English main menu and language selector are fully constructed")
	await capture("en-menu-0110")
	game.start_game(true);game.paused=true
	for id in range(9): game.model.admit_guest(id%3)
	check(game.model.build_building("restaurant",Vector2(155,300)).ok,"The bilingual test resort has a real accessible restaurant")
	var guest: Dictionary=game.model.guests[0]
	guest.needs.hunger=90;guest.needs.warmth=85;guest.needs.energy=85
	var trip: Dictionary=game.model.service_route(guest)
	guest.route=trip;guest.leg=0;game.model._start_leg(guest)
	for minute in range(150):
		if game.model.buildings[-1].visits>0: break
		game.model.advance_minute(false)
	game.hud.show_guest(int(guest.id));game.view.focus=Vector2(195,260);game.view.zoom=245;game.view._update_camera()
	check(game.hud.inspector_text.text.contains("YOUR SKI DAY") and game.hud.inspector_text.text.contains("Hunger:") and guest.needs.hunger<=15,"The English guest inspector shows actual needs after an actual restaurant visit")
	await capture("en-guest-services-0110")
	for item in game.model.buildings+game.model.lifts+game.model.pistes: game.hud.show_context("inspect",int(item.id))
	game.hud.show_help();check(english_only(game.hud.help_dialog),"The complete English help includes building, camera, guests and new planning instructions");game.hud.help_dialog.hide()
	game.hud.atlas.open();check(english_only(game.hud.atlas),"All four areas and unlock requirements appear in English");game.hud.atlas.hide()
	game.hud.show_management(2)
	check(english_only(game.hud.management),"Every Resort Office tab uses English titles, descriptions, conditions and actions")
	await capture("en-research-0110");game.hud.management.hide()
	game.set_tool("building");game.hud.refresh()
	check(english_only(game.hud.root),"The full English HUD, catalogue, selectors and building inspector contain no untranslated German")
	game.set_tool("piste");game.points=game.model.pistes[0].points.duplicate(true);game._update_plan()
	check(game.hud.palette.suggest_button.text=="Suggest a gentle route" and game.last_plan_check.connections.entry,"The new route assistant is translated and checks actual network access")
	var before: Dictionary=game.model.snapshot()
	var points: Array=game.points.duplicate(true);var focus: Vector2=game.view.focus;var yaw: float=game.view.yaw
	game.speed=4;game.paused=true
	game.apply_language("de");await process_frame
	check(game.model.snapshot()==before and game.points==points and game.speed==4 and game.paused,"Changing language preserves all resort data, active planning, speed and pause")
	check(game.view.focus==focus and game.view.yaw==yaw,"A language change preserves the exact camera")
	check(game.hud.palette.suggest_button.text=="Sanften Verlauf vorschlagen" and game.hud.confirm_button.text.begins_with("Bauen"),"The rebuilt German planning interface translates actions and costs")
	var signs: Array=texts(game.view)
	check(signs.has("TALZUGANG") and not signs.has("VALLEY ENTRANCE"),"Existing 3D labels change language without rebuilding the resort")
	await capture("de-route-planning-0110")
	game.hud.display_options.open()
	root.size=Vector2i(960,540)
	for frame in range(4):await process_frame
	check(game.hud.display_options.get_global_rect().size.y>=540,"The settings overlay remains usable on a small landscape screen")
	await capture("de-settings-0110")
	game.hud.display_options.hide();root.size=Vector2i(1536,864)
	game.clear_plan();game.apply_language("en")
	var custom: Dictionary=game.model.buildings[0]
	custom.name="Meine Hütte";custom.custom_name=true
	game.hud.show_context("inspect",int(custom.id))
	check(game.hud.inspector_title.text=="Meine Hütte","Custom facility names remain verbatim in another language")
	var preferences:=Preferences.new();preferences.path="user://language-roundtrip-test.cfg";preferences.language="en"
	var saved:=preferences.save_to();var loaded:=Preferences.new();loaded.path=preferences.path;loaded.load_from()
	check(saved==OK and loaded.language=="en","An explicit language preference survives a settings roundtrip")
	game.hud.show_context("inspect")
	for minute in range(2000):
		if game.model.day_finished():break
		game.model.advance_minute(false)
	game.hud.show_report()
	check(game.hud.daily_dialog.visible and english_only(game.hud.daily_dialog),"A real completed day's financial report is fully translated")
	await capture("en-day-report-0110")
	game.queue_free();await process_frame;await process_frame
	print("LOCALIZATION SCENE: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
