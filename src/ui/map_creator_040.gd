extends PanelContainer
## 0.40 map-creator workbench: responsive controls, deterministic topo preview,
## safe draft storage and a strict final mission unlock. Actual playable-map
## activation is deliberately gated until independent saves are implemented.
const Creator=preload("res://src/core/map_creator_040.gd")
const Preview=preload("res://src/ui/map_creator_preview_040.gd")
const Medals=preload("res://src/core/scenario_medals.gd")
const Maps=preload("res://src/core/maps.gd")
const Geo=preload("res://src/core/real_resorts.gd")
const L=preload("res://src/core/i18n.gd")
const DRAFT_PATH:="user://skizones_map_creator_040_draft.json"
var hud:CanvasLayer
var settings:Dictionary=Creator.DEFAULT.duplicate(true)
var preview:=Preview.new()
var result_label:=Label.new()
var access_label:=Label.new()
var generate_button:=Button.new()
var draft_button:=Button.new()

func _text(de:String,en:String)->String:
	return en if L.language=="en" else de

func _label(parent:Node,message:String,size_px:int=16) -> Label:
	var result:=Label.new()
	result.text=message
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size",size_px)
	parent.add_child(result)
	return result

func _action(parent:Node,message:String,callback:Callable) -> Button:
	var result:=Button.new()
	result.text=message
	result.custom_minimum_size.y=50
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func _line(parent:Node) -> HFlowContainer:
	var row:=HFlowContainer.new()
	row.add_theme_constant_override("h_separation",12)
	row.add_theme_constant_override("v_separation",8)
	parent.add_child(row)
	return row

func _selector(parent:Node,key:String,caption:String,choices:Array) -> void:
	var row:=_line(parent)
	var name_label:=_label(row,caption)
	name_label.custom_minimum_size.x=166
	var field:=OptionButton.new()
	field.custom_minimum_size=Vector2(212,48)
	for entry in choices:
		field.add_item(_text(str(entry[1]),str(entry[2])))
		field.set_item_metadata(field.item_count-1,entry[0])
	for index in range(field.item_count):
		if field.get_item_metadata(index)==settings[key]:field.select(index);break
	field.item_selected.connect(func(index:int):settings[key]=field.get_item_metadata(index))
	row.add_child(field)

func _number(parent:Node,key:String,caption:String,minimum:float,maximum:float,step_value:float=1.0) -> void:
	var row:=_line(parent)
	var name_label:=_label(row,caption)
	name_label.custom_minimum_size.x=166
	var input:=SpinBox.new()
	input.min_value=minimum
	input.max_value=maximum
	input.step=step_value
	input.rounded=true
	input.value=float(settings[key])
	input.custom_minimum_size=Vector2(180,48)
	input.value_changed.connect(func(value:float):settings[key]=int(value))
	row.add_child(input)

func setup(owner:CanvasLayer) -> void:
	hud=owner
	_load_draft()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel",hud._style(Color("f7faf8"),16,20))
	var page:=VBoxContainer.new()
	page.add_theme_constant_override("separation",12)
	add_child(page)
	var header:=HBoxContainer.new()
	page.add_child(header)
	var heading:=_label(header,_text("MAP CREATOR · DEINE ALPENWELT","MAP CREATOR · YOUR ALPINE WORLD"),23)
	heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_action(header,_text("Zurück","Back"),hide)
	_label(page,_text("Erschaffe einzigartige Täler, Bergketten, Almen oder Plateaus. Gleicher Seed = gleiche Landschaft.","Create valleys, mountain ranges, pastures and plateaus. The same seed always rebuilds the same terrain."),15)
	access_label=_label(page,"",14)
	var scroll:=preload("res://src/ui/drag_scroll.gd").new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var content:=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	scroll.add_child(content)
	var name_row:=_line(content)
	_label(name_row,_text("Kartenname","Map name"))
	var name_input:=LineEdit.new()
	name_input.custom_minimum_size=Vector2(220,48)
	name_input.text=settings.name
	name_input.text_changed.connect(func(value:String):settings.name=value)
	name_row.add_child(name_input)
	_selector(content,"size",_text("Kartengröße","Map size"),[["compact","Kompakt","Compact"],["standard","Standard","Standard"],["large","Groß","Large"],["grand","Gigantisch","Grand"]])
	_selector(content,"landform",_text("Landschaftstyp","Landform"),[["ridge","Bergkette","Mountain range"],["isolated","Einzelberge","Isolated peaks"],["plateau","Hochplateau","Plateau"],["alpine_pasture","Almlandschaft","Alpine pasture"],["hills","Hügelland","Rolling hills"],["glacial_basin","Gletscherkessel","Glacial basin"],["horseshoe","Hufeisental","Horseshoe valley"]])
	_selector(content,"difficulty",_text("Geländeschwierigkeit","Terrain challenge"),[["gentle","Leicht","Gentle"],["mixed","Gemischt","Mixed"],["technical","Anspruchsvoll","Technical"],["extreme","Extrem","Extreme"]])
	_selector(content,"climate",_text("Klima","Climate"),[["alpine","Alpin","Alpine"],["continental","Kontinental","Continental"],["snowy","Schneereich","Snowy"],["mild","Mild","Mild"]])
	_selector(content,"exposure",_text("Hangausrichtung","Slope exposure"),[["north","Nord","North"],["east","Ost","East"],["south","Süd","South"],["west","West","West"]])
	_number(content,"seed",_text("Welt-Seed","World seed"),0,2147483647)
	_number(content,"peak_count",_text("Anzahl Berge","Number of peaks"),1,24)
	_number(content,"peak_height",_text("Gipfelhöhe (m)","Peak height (m)"),80,2800)
	_number(content,"ridge_angle",_text("Kettenrichtung (°)","Range direction (°)"),0,359)
	_number(content,"valley_width",_text("Talbreite (%)","Valley width (%)"),0,100)
	_number(content,"plateau_width",_text("Plateaufläche (%)","Plateau width (%)"),0,100)
	_number(content,"rolling_hills",_text("Hügelintensität (%)","Rolling hill intensity (%)"),0,100)
	_number(content,"tree_count",_text("Anzahl Bäume","Number of trees"),0,12000)
	_number(content,"forest",_text("Waldanteil (%)","Forest coverage (%)"),0,100)
	_number(content,"lake_count",_text("Seen","Lakes"),0,8)
	_number(content,"village_count",_text("Dörfer / Startorte","Villages / hubs"),0,8)
	_number(content,"snowline",_text("Schneegrenze (m)","Snowline (m)"),100,3500)
	_number(content,"erosion",_text("Erosion (%)","Erosion (%)"),0,100)
	_number(content,"avalanche_risk",_text("Lawinenrisiko (%)","Avalanche exposure (%)"),0,100)
	var actions:=_line(content)
	generate_button=_action(actions,_text("Karte neu generieren","Generate new map"),regenerate)
	draft_button=_action(actions,_text("Entwurf speichern","Save blueprint"),save_draft)
	_label(content,_text("Topografische Vorschau · noch keine spielbare Karte. Die Anbindung an unabhängige Spielstände folgt.","Topographic preview · not yet playable. Independent save-slot integration follows."),14)
	preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_child(preview)
	result_label=_label(content,"",15)
	hide()

func mission_unlocked() -> bool:
	if hud.game.preferences.free_play:return true
	var medals:Dictionary=Medals.new().records()
	for id in Geo.IDS:
		if int(medals.get(id,0))<3:return false
	for id in Maps.FANTASY_MAPS:
		if not hud.game.passport.unlocked(id):return false
	return true

func open() -> void:
	var allowed:=mission_unlocked()
	generate_button.disabled=not allowed
	draft_button.disabled=not allowed
	access_label.text=_text("Freier Modus: sofort verfügbar. Missionsmodus: erst nach allen Gebietsfreischaltungen und vier Goldmedaillen.","Free mode: available immediately. Mission mode: unlock every resort and earn gold in all four scenarios.") if allowed else _text("Noch gesperrt: Im freien Modus sofort verfügbar; im Missionsmodus sind alle Gebietsfreischaltungen und vier Goldmedaillen erforderlich.","Locked: open in free mode, or unlock every resort and earn four gold scenario medals.")
	if allowed:regenerate()
	else:result_label.text=_text("Generator gesperrt. Bisherige Spielstände bleiben unverändert.","Generator locked. Existing saves are untouched.")
	show()

func regenerate() -> void:
	if not mission_unlocked():return
	var result:Dictionary=Creator.generate(settings)
	if not result.ok:
		result_label.text=str(result.error)
		return
	preview.set_blueprint(result.map)
	var map_data:Dictionary=result.map
	result_label.text=_text("%d Gipfel · %.1f km² · %d Bäume · %d Seen · Seed %d","%d peaks · %.1f km² · %d trees · %d lakes · seed %d") % [map_data.peaks.size(),map_data.bounds.size.x*map_data.bounds.size.y/1000000.0,map_data.tree_count,map_data.lake_count,int(settings.seed)]

func save_draft() -> void:
	if not mission_unlocked():return
	var checked:Dictionary=Creator.validate(settings)
	if not checked.ok:
		result_label.text=str(checked.error)
		return
	var payload:=JSON.stringify(checked.settings)
	var envelope:=JSON.stringify({"schema":1,"payload":payload,"sha256":payload.sha256_text()})
	var tmp:=DRAFT_PATH+".tmp"
	var file:=FileAccess.open(tmp,FileAccess.WRITE)
	if file==null:
		result_label.text=_text("Entwurf konnte nicht gespeichert werden.","Unable to save blueprint.")
		return
	file.store_string(envelope)
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),ProjectSettings.globalize_path(DRAFT_PATH))!=OK:
		result_label.text=_text("Entwurf konnte nicht gespeichert werden.","Unable to save blueprint.")
		return
	result_label.text=_text("Karteneinstellungen sicher gespeichert. Noch keine spielbare Karte.","Map settings saved. Not yet a playable map.")

func _load_draft() -> void:
	if not FileAccess.file_exists(DRAFT_PATH):return
	var text_file:=FileAccess.get_file_as_string(DRAFT_PATH)
	if text_file.length()>12000:return
	var parser:=JSON.new()
	if parser.parse(text_file)!=OK or not parser.data is Dictionary:return
	var envelope:Dictionary=parser.data
	if envelope.get("schema")!=1 or not envelope.get("payload") is String:return
	if envelope.get("sha256")!=str(envelope.payload).sha256_text():return
	if parser.parse(envelope.payload)!=OK or not parser.data is Dictionary:return
	var validated:Dictionary=Creator.validate(parser.data)
	if validated.ok:settings=validated.settings
