extends Control
## SkiZones Alpine Radio 0.35: all real controls live ON the radio hardware.
## No redundant confirmation step, duplicate checkbox sheet or simulated fake player.
## Invisible legacy inputs remain wired for old UI/save regression fixtures.
const L = preload("res://src/core/i18n.gd")
const Design = preload("res://src/core/audio_design.gd")
const Branding = preload("res://src/core/radio_branding.gd")
const FloatingFrame = preload("res://src/ui/floating_window.gd")
const DragScroll = preload("res://src/ui/drag_scroll.gd")
const RadioFace = preload("res://src/ui/radio_face.gd")
const RadioDial = preload("res://src/ui/radio_dial.gd")
const RAIL := Color("0c1b27")
const SCREEN := Color("102a35")
const INK_LIGHT := Color("e8f5ee")
const PAD := 0.05

var hud: CanvasLayer
var window := FloatingFrame.new()
var genre_choice := OptionButton.new()
var music_slider := HSlider.new()
var ambience_slider := HSlider.new()
var master_slider := HSlider.new()
var enabled := CheckButton.new()
var face := RadioFace.new()
var dial := RadioDial.new()
var area_label := Label.new()
var station_info := Label.new()
var playing_label := Label.new()
var credits_label := Label.new()
var power_button: Button
var skip_button: Button
var station_left: Button
var station_right: Button
var credits_button: Button
var station_counter := Label.new()
var _now_playing_timer := 0.0
var preset_buttons: Dictionary = {}
var volume_meters: Dictionary = {}
var volume_readouts: Dictionary = {}
var _station_last := "alpine"
var _suppress_callbacks := false

func _panel(parent: Node, color: Color, rounding: int = 12) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",hud._style(color,rounding,13))
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, size_value: int, color: Color = INK_LIGHT) -> Label:
	var result: Label = hud._label(parent,L.text(text),size_value,color,true)
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return result

func _radio_button(parent: Node, text: String, callback: Callable, emphasized: bool = false) -> Button:
	var button: Button=hud._button(parent,L.text(text),callback,emphasized)
	button.custom_minimum_size.y=52
	button.add_theme_color_override("font_color",Color("13323c"))
	button.add_theme_color_override("font_hover_color",Color("13323c"))
	button.add_theme_stylebox_override("normal",hud._style(Color("d7e9e6") if not emphasized else Color("a7e7cd"),12,8))
	button.add_theme_stylebox_override("hover",hud._style(Color("ebfbf5"),12,8))
	button.add_theme_stylebox_override("pressed",hud._style(Color("85c8b6"),12,8))
	return button

func _icon_button(parent: Node, asset: String, callback: Callable, tooltip: String, emphasized: bool = false) -> Button:
	var button := _radio_button(parent,"",callback,emphasized)
	button.icon = load("res://assets/radio/controls/" + asset + ".svg")
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.custom_minimum_size = Vector2(62,62)
	button.tooltip_text = L.text(tooltip)
	return button

func setup(owner_hud: CanvasLayer) -> void:
	hud=owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var veil:=ColorRect.new()
	veil.color=Color(0.015,0.035,0.06,0.82)
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(window)
	window.setup(hud,L.text("Alpine Radio · Sound Control"))
	window.close_requested.connect(close)
	var scroll:=DragScroll.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	window.body.add_child(scroll)
	var page: VBoxContainer=hud._vbox(scroll,13)
	page.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var shell: PanelContainer=_panel(page,RAIL,19)
	var radio: VBoxContainer=hud._vbox(shell,8)
	var top: HBoxContainer=HBoxContainer.new()
	top.add_theme_constant_override("separation",12)
	radio.add_child(top)
	var identity: VBoxContainer=hud._vbox(top,2)
	identity.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var identity_title: Label = _label(identity,L.text("ALPINE RADIO"),18,Color("e6f2ec"))
	identity_title.custom_minimum_size.y=24
	identity_title.autowrap_mode=TextServer.AUTOWRAP_OFF
	identity_title.clip_text=true
	identity_title.max_lines_visible=-1
	identity_title.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
	_label(identity,L.text("15 SENDER · OFFLINE"),11,Color("8bb9ba"))
	power_button=_icon_button(top,"power",func(): _set_power(not enabled.button_pressed), "Radio sofort ein- oder ausschalten",true)
	power_button.custom_minimum_size.x=92
	power_button.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	power_button.tooltip_text=L.text("Radio sofort einschalten oder ausschalten")
	face.custom_minimum_size.y=156
	face.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	radio.add_child(face)
	var now_panel: PanelContainer=_panel(radio,SCREEN,13)
	var now: VBoxContainer=hud._vbox(now_panel,6)
	_label(now,L.text("LIVE · JETZT AUF SENDUNG"),12,Color("8bdfbc"))
	playing_label=_label(now,L.text("Musik aus"),16,Color("f0fff4"))
	playing_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	playing_label.custom_minimum_size.y=66
	playing_label.max_lines_visible=3
	playing_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	var tuning: HBoxContainer=HBoxContainer.new()
	tuning.add_theme_constant_override("separation",8)
	radio.add_child(tuning)
	station_left=_icon_button(tuning,"previous",func(): _step_station(-1),"Vorheriger Sender")
	station_left.tooltip_text=L.text("Vorherigen Sender wählen")
	station_left.custom_minimum_size.x=62
	dial.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	dial.tuned.connect(_step_station)
	dial.tooltip_text=L.text("Sendersuchrad drehen, wischen oder anklicken")
	tuning.add_child(dial)
	station_counter=_label(tuning,"",15,Color("dce9e2"))
	station_counter.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	station_counter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	station_right=_icon_button(tuning,"next",func(): _step_station(1),"Nächster Sender")
	station_right.tooltip_text=L.text("Nächsten Sender wählen")
	station_right.custom_minimum_size.x=62
	station_info=_label(radio,"",14,Color("a7c9ce"))
	station_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var transport := HFlowContainer.new()
	transport.add_theme_constant_override("h_separation",9)
	transport.add_theme_constant_override("v_separation",7)
	radio.add_child(transport)
	skip_button=_radio_button(transport,L.text("NÄCHSTER TITEL"),func():
		hud.game.audio.next_track()
		_update_now_playing()
	)
	skip_button.icon=load("res://assets/radio/controls/skip.svg")
	skip_button.expand_icon=true
	skip_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	skip_button.tooltip_text=L.text("Zum nächsten Titel dieses Senders springen")
	credits_button=_radio_button(transport,L.text("CREDITS"),_toggle_credits)
	credits_button.icon=load("res://assets/radio/controls/info.svg")
	credits_button.tooltip_text=L.text("Musik- und Lizenzquellen dieses Senders zeigen")
	var bank: PanelContainer=_panel(radio,Color("132d39"))
	var bank_stack: VBoxContainer=hud._vbox(bank,8)
	_label(bank_stack,L.text("DEINE SENDERPRESETS · LOGO ANTIPPEN"),14,Color("b3dce0"))
	# Wrap all station presets into additional rows on every aspect ratio.
	# Horizontal-only scrolling hid most stations on smaller Android screens.
	var presets:=HFlowContainer.new()
	presets.name="radio_station_grid"
	presets.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	presets.add_theme_constant_override("h_separation",8)
	presets.add_theme_constant_override("v_separation",8)
	bank_stack.add_child(presets)
	for id in Design.GENRES:
		if id=="off": continue
		_add_preset(presets,str(id))
	# All previously separate audio options now use actual radio +/- controls.
	var volume: PanelContainer=_panel(radio,Color("122936"))
	var volume_stack: VBoxContainer=hud._vbox(volume,8)
	_label(volume_stack,L.text("MISCHPULT · DIREKT AM RADIO"),14,Color("a6d9ce"))
	for data in [["master",master_slider,L.text("GESAMT")],["music",music_slider,L.text("MUSIK")],["ambient",ambience_slider,L.text("UMGEBUNG")]]:
		_add_volume_row(volume_stack,str(data[0]),data[1],str(data[2]))
	_label(volume_stack,L.text("Hinweis: schrille FX sind deaktiviert. Der Umgebungsregler wird gespeichert; hörbare FX bleiben bis zur sicheren Neuvertonung ausgeschaltet."),12,Color("94b5b8"))
	var locality: PanelContainer=_panel(radio,Color("132d39"))
	area_label=_label(locality,"",14,Color("a8dbd2"))
	credits_label=_label(radio,"",13,Color("cce5e3"))
	credits_label.visible=false
	_label(radio,L.text("15 echte Offline-Sender · Titel und Interpreten aus dem lokalen CC0-Archiv. Jede Änderung gilt sofort und bleibt gespeichert. Keine Internet- oder SoundCloud-Wiedergabe."),13,Color("aac7c6"))
	_radio_button(radio,L.text("ZURÜCK ZUM RESORT"),close)
	# Former OptionButton / CheckButton / sliders remain as invisible adapters so
	# old controls and save-compatibility UI tests do not lose their contract.
	for id in Design.GENRES:
		genre_choice.add_item(L.text(str(Design.GENRE_NAMES[id])))
	genre_choice.visible=false
	page.add_child(genre_choice)
	genre_choice.item_selected.connect(func(_i:int): _apply_settings())
	enabled.visible=false
	page.add_child(enabled)
	enabled.toggled.connect(func(_on:bool): _apply_settings())
	for slider in [master_slider,music_slider,ambience_slider]:
		slider.min_value=0.0
		slider.max_value=1.0
		slider.step=0.05
		slider.visible=false
		page.add_child(slider)
		slider.value_changed.connect(func(_value:float): _apply_settings())
	hide()

func _add_preset(parent: Node, id: String) -> void:
	var button:=Button.new()
	button.text=""
	button.tooltip_text=L.text(str(Design.GENRE_NAMES[id]))
	button.focus_mode=Control.FOCUS_NONE
	button.custom_minimum_size=Vector2(144,70)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	var row:=HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left=7
	row.offset_right=-7
	row.add_theme_constant_override("separation",5)
	row.mouse_filter=Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	var logo:=TextureRect.new()
	logo.texture=Branding.logo(id)
	logo.custom_minimum_size=Vector2(62,52)
	logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	logo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	row.add_child(logo)
	var name: Label=_label(row,str(Branding.spec(id).short),12,Color("16343b"))
	name.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(func(): _choose_station(id))
	preset_buttons[id]=button

func _add_volume_row(parent: VBoxContainer, id: String, slider: HSlider, caption: String) -> void:
	# Two rows per volume control preserve real 48pt+ touch targets even
	# on 360px Android portrait widths. No horizontal clipping of the
	# label/percent/meter/plus/minus combination.
	var block: VBoxContainer=hud._vbox(parent,3)
	var headline:HBoxContainer=HBoxContainer.new()
	headline.add_theme_constant_override("separation",6)
	block.add_child(headline)
	var text:Label=_label(headline,caption,14,INK_LIGHT)
	text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var percentage:Label=_label(headline,"0 %",14,Color("aee5d3"))
	percentage.custom_minimum_size.x=53
	volume_readouts[id]=percentage
	var row:HBoxContainer=HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	block.add_child(row)
	var minus:Button=_icon_button(row,"minus",func(): _adjust(slider,-PAD),"Lautstärke verringern")
	minus.custom_minimum_size.x=52
	minus.tooltip_text=L.text("Lautstärke verringern")
	var meter:ProgressBar=ProgressBar.new()
	meter.min_value=0
	meter.max_value=100
	meter.show_percentage=false
	meter.custom_minimum_size=Vector2(86,17)
	meter.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(meter)
	volume_meters[id]=meter
	var plus:Button=_icon_button(row,"plus",func(): _adjust(slider,PAD),"Lautstärke erhöhen")
	plus.custom_minimum_size.x=52
	plus.tooltip_text=L.text("Lautstärke erhöhen")

func _adjust(slider: HSlider, diff: float) -> void:
	slider.value=clampf(slider.value+diff,0.0,1.0)
	_update_dials()

func _choose_station(id: String) -> void:
	var index:int=Design.GENRES.find(id)
	if index < 0: return
	_station_last=id
	genre_choice.select(index)
	enabled.set_pressed_no_signal(true)
	_apply_settings()

func _step_station(direction: int) -> void:
	var stations: Array=Design.GENRES.filter(func(id): return str(id)!="off")
	var selected: String=str(Design.GENRES[maxi(0,genre_choice.selected)])
	var idx:int=stations.find(selected)
	if idx<0: idx=0
	_choose_station(str(stations[posmod(idx+direction,stations.size())]))

func _set_power(on: bool) -> void:
	if on and genre_choice.selected==0:
		genre_choice.select(maxi(1,Design.GENRES.find(_station_last)))
	enabled.set_pressed_no_signal(on)
	_apply_settings()

func open() -> void:
	if hud==null or hud.game==null:return
	var prefs:RefCounted=hud.game.preferences
	_suppress_callbacks=true
	enabled.set_pressed_no_signal(prefs.sound_enabled)
	master_slider.set_value_no_signal(prefs.master_volume)
	music_slider.set_value_no_signal(prefs.music_volume)
	ambience_slider.set_value_no_signal(prefs.ambient_volume)
	genre_choice.select(maxi(0,Design.GENRES.find(prefs.music_genre)))
	if prefs.music_genre!="off": _station_last=prefs.music_genre
	_suppress_callbacks=false
	show()
	window._fit()
	hud.game.audio.clear_preview()
	_refresh_tuner()
	_update_now_playing()

func close(_restore: bool = true) -> void:
	if hud!=null and hud.game!=null: hud.game.audio.clear_preview()
	hide()

func _apply_settings() -> void:
	if _suppress_callbacks or not visible or hud==null or hud.game==null:return
	if genre_choice.selected<0 or genre_choice.selected>=Design.GENRES.size():return
	var prefs:RefCounted=hud.game.preferences
	prefs.music_genre=str(Design.GENRES[genre_choice.selected])
	prefs.sound_enabled=enabled.button_pressed
	prefs.master_volume=float(master_slider.value)
	prefs.music_volume=float(music_slider.value)
	prefs.ambient_volume=float(ambience_slider.value)
	if prefs.music_genre!="off":_station_last=prefs.music_genre
	hud.game.audio.clear_preview()
	var error:Error=prefs.save_to()
	if error!=OK: hud.toast(L.text("Audio angewendet; Speichern fehlgeschlagen."))
	_refresh_tuner()
	_update_now_playing()
	_update_credits()

func _process(delta: float) -> void:
	if not visible:return
	_now_playing_timer+=delta
	if _now_playing_timer>=0.65:
		_now_playing_timer=0.0
		_update_now_playing()

func _update_dials() -> void:
	var values:Dictionary={"master":master_slider.value,"music":music_slider.value,"ambient":ambience_slider.value}
	for key in values:
		if volume_meters.has(key):
			volume_meters[key].value=100.0*float(values[key])
			volume_readouts[key].text="%d %%" % roundi(100.0*float(values[key]))

func _update_now_playing() -> void:
	if hud==null or hud.game==null or genre_choice.selected<0:return
	var info:Dictionary=hud.game.audio.now_playing()
	var station: String=str(Design.GENRES[genre_choice.selected])
	var muted:bool=not enabled.button_pressed or music_slider.value<=0.001 or master_slider.value<=0.001
	var playing:bool=not muted and hud.game.audio.active and hud.game.audio.players.has("music") and hud.game.audio.players.music.playing and not hud.game.audio.players.music.stream_paused and station!="off"
	face.active=playing
	face.signal_level=float(music_slider.value)*float(master_slider.value) if playing else 0.0
	face.frequency=genre_choice.selected
	face.set_station(station if station!="off" else _station_last)
	var track:String=str(info.get("title",""))
	var artist:String=str(info.get("artist",""))
	face.set_track(track,artist)
	dial.active=enabled.button_pressed and station!="off"
	dial.queue_redraw()
	if station=="off" or not enabled.button_pressed:playing_label.text=L.text("RADIO AUS · mit dem Power-Knopf einschalten")
	elif muted:playing_label.text=L.text("STUMM · Musik- oder Gesamtlautstärke erhöhen")
	else:
		playing_label.text=(L.text("♫ Jetzt läuft: ")+track) if not track.is_empty() else L.text("Der Sender wird eingestellt …")
		if not artist.is_empty():playing_label.text+="  ·  "+artist
	playing_label.tooltip_text=playing_label.text
	var moment:String=str(info.get("moment",""))
	if playing and not moment.is_empty():playing_label.tooltip_text+="\n"+L.text("Bergmoment: ")+moment
	if str(info.get("context",""))=="hotel_lobby":
		playing_label.text+="\n"+L.text("Hotelverwaltung · Lobby-Radio ist nur vorübergehend aktiv.")
	power_button.text=L.text("AUS") if enabled.button_pressed and station!="off" else L.text("EIN")
	power_button.modulate=Color("ffffff") if enabled.button_pressed and station!="off" else Color("9baab2")
	power_button.tooltip_text=L.text("Radio ausschalten") if enabled.button_pressed and station!="off" else L.text("Radio einschalten")
	skip_button.disabled=not playing
	_update_dials()

func _toggle_credits() -> void:
	credits_label.visible=not credits_label.visible
	credits_button.text=L.text("ZUKLAPPEN") if credits_label.visible else L.text("CREDITS")
	if credits_label.visible:_update_credits()

func _update_credits() -> void:
	if not credits_label.visible or hud==null or hud.game==null:return
	var station:String=str(Design.GENRES[maxi(0,genre_choice.selected)])
	var records:=PackedStringArray()
	for song in hud.game.audio.track_credits(station):
		records.append(str(song.get("title",""))+" · "+str(song.get("artist",""))+"\n"+str(song.get("source_url","")))
	credits_label.text="\n\n".join(records)
	if records.is_empty(): credits_label.text=L.text("Auf diesem Sender ist kein lokaler Titel hinterlegt.")

func _refresh_tuner() -> void:
	if hud==null or hud.game==null or genre_choice.selected<0:return
	var station:String=str(Design.GENRES[genre_choice.selected])
	var count:int=hud.game.audio.station_track_count(station)
	var mood:String=L.text(str(Design.GENRE_MOODS.get(station,"")))
	station_counter.text=L.text("KANAL %02d / 15") % maxi(1,genre_choice.selected)
	station_info.text=L.text(str(Design.GENRE_NAMES[station]))+" · "+L.text("%d echte Offline-Titel") % count
	if not mood.is_empty():station_info.text+="\n"+mood
	for id in preset_buttons:
		var selected:bool=str(id)==station
		var mark:Dictionary=Branding.spec(str(id))
		var accent:Color=Color(str(mark.accent))
		var button:Button=preset_buttons[id]
		button.add_theme_stylebox_override("normal",hud._style(accent.lightened(0.14) if selected else Color("d5e5e5"),10,5,accent if selected else Color("526b72")))
		button.add_theme_color_override("font_color",Color("183b3f"))
	area_label.text=L.text("HÖRBEREICH: ")+L.text(str(Design.ZONE_NAMES.get(hud.game.audio.active_zone,Design.ZONE_NAMES.wilderness)))
