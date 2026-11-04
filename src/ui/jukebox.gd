extends Control
## Explicit opt-in: station playback is off by default; never contacts Suno,
## SoundCloud, an internet radio server or an account without permission.
const L=preload("res://src/core/i18n.gd")
const Design=preload("res://src/core/audio_design.gd")
const FloatingFrame=preload("res://src/ui/floating_window.gd")
const DragScroll=preload("res://src/ui/drag_scroll.gd")
const RadioFace=preload("res://src/ui/radio_face.gd")
var hud: CanvasLayer
var window:=FloatingFrame.new()
var genre_choice:=OptionButton.new()
var music_slider:=HSlider.new()
var ambience_slider:=HSlider.new()
var area_label:=Label.new()
var playing_label:=Label.new()
var credits_label:=Label.new()
var _now_playing_timer := 0.0
var face:=RadioFace.new()
var station_info:=Label.new()
var space_link: Button
var ska_link: Button
var enabled := CheckButton.new()
var master_slider := HSlider.new()

func setup(owner_hud: CanvasLayer) -> void:
	hud=owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var veil:=ColorRect.new()
	veil.color=Color(0.02,0.05,0.08,0.70)
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(window)
	window.setup(hud,L.text("Alpine Radio · deine Jukebox"))
	window.close_requested.connect(close)
	var scroll:=DragScroll.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	window.body.add_child(scroll)
	var page: VBoxContainer=hud._vbox(scroll,14)
	page.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hud._label(page,L.text("ALPINE RADIO CONTROL CENTER"),25,hud.TEAL)
	face.custom_minimum_size.y=214
	face.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	page.add_child(face)
	var tuner_panel:=PanelContainer.new()
	tuner_panel.add_theme_stylebox_override("panel",hud._style(Color("d8e8df"),15,15))
	page.add_child(tuner_panel)
	var tuner: VBoxContainer = hud._vbox(tuner_panel,8)
	hud._label(tuner,L.text("SENDERWAHL · BERGFREQUENZEN"),15,hud.TEAL)
	station_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	station_info.add_theme_color_override("font_color",hud.INK)
	station_info.add_theme_font_size_override("font_size",17)
	tuner.add_child(station_info)
	hud._label(page,L.text("Offline-Musik mit dokumentierten CC0-Quellen. Eigene Alben auf SoundCloud werden ausschließlich nach ausdrücklichem Klick geöffnet."),15,hud.MUTED,true)
	enabled.text=L.text("Audio einschalten")
	enabled.custom_minimum_size.y=46
	page.add_child(enabled)
	hud._label(page,L.text("Gesamtlautstärke"),17,hud.MUTED)
	master_slider.min_value=0;master_slider.max_value=1;master_slider.step=0.05
	page.add_child(master_slider)
	for kind in Design.GENRES:
		genre_choice.add_item(L.text(str(Design.GENRE_NAMES[kind])))
	tuner.add_child(genre_choice)
	genre_choice.custom_minimum_size.y=55
	genre_choice.item_selected.connect(func(index:int):
		_preview()
	)
	hud._label(page,L.text("Musiklautstärke"),17,hud.MUTED)
	music_slider.min_value=0;music_slider.max_value=1;music_slider.step=0.05
	page.add_child(music_slider)
	hud._label(page,L.text("Umgebung: Wind, Stimmen, Liftmotoren"),17,hud.MUTED)
	ambience_slider.min_value=0;ambience_slider.max_value=1;ambience_slider.step=0.05
	page.add_child(ambience_slider)
	for slider in [master_slider,music_slider,ambience_slider]:
		slider.custom_minimum_size.y=46
		slider.value_changed.connect(func(_value: float): _preview())
	enabled.toggled.connect(func(_on: bool): _preview())
	area_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	area_label.add_theme_font_size_override("font_size",17)
	area_label.add_theme_color_override("font_color",hud.TEAL)
	page.add_child(area_label)
	playing_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	playing_label.add_theme_font_size_override("font_size",18)
	var display:=PanelContainer.new()
	display.add_theme_stylebox_override("panel",hud._style(Color("10242d"),15,18))
	page.add_child(display)
	playing_label.add_theme_color_override("font_color",Color("a4f2d4"))
	display.add_child(playing_label)
	var transport:=HBoxContainer.new()
	transport.add_theme_constant_override("separation",10)
	page.add_child(transport)
	hud._button(transport,L.text("▶ Nächster Titel"),func():
		hud.game.audio.next_track()
		_update_now_playing()
	)
	space_link = hud._button(page,L.text("ERG0SPHERE Journey · SoundCloud-Player öffnen"),func():
		var error: Error = OS.shell_open(Design.SPACE_COLLECTION_URL)
		if error != OK: hud.toast(L.text("SoundCloud konnte nicht geöffnet werden."))
	)
	space_link.visible=false
	ska_link = hud._button(page,L.text("KoSch Milton · Ska'radise Lost auf SoundCloud öffnen"),func():
		var error: Error = OS.shell_open(Design.SKA_COLLECTION_URL)
		if error != OK: hud.toast(L.text("Ska-Album konnte nicht geöffnet werden."))
	)
	ska_link.visible=false
	hud._label(page,L.text("CC0-Musikquellen sind mit Künstler und Lizenz dokumentiert. Sender können lizenzierte Aufnahmen gemeinsam nutzen."),14,hud.MUTED,true)
	hud._button(page,L.text("Musik-Credits anzeigen"),func(): _toggle_credits())
	credits_label.visible=false
	credits_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	credits_label.add_theme_font_size_override("font_size",14)
	credits_label.add_theme_color_override("font_color",hud.MUTED)
	page.add_child(credits_label)
	hud._button(page,L.text("Jukebox-Einstellungen speichern"),func():
		var prefs:RefCounted=hud.game.preferences
		prefs.sound_enabled=enabled.button_pressed
		prefs.master_volume=float(master_slider.value)
		prefs.music_genre=str(Design.GENRES[genre_choice.selected])
		prefs.music_volume=float(music_slider.value)
		prefs.ambient_volume=float(ambience_slider.value)
		var error:Error=prefs.save_to()
		hud.game.audio.clear_preview()
		hud.toast(L.text("Audio gespeichert.") if error==OK else L.text("Audio angewendet; Speichern fehlgeschlagen."))
		close(false)
	,true)
	hud._button(page,L.text("Zurück"),close)
	hide()

func open() -> void:
	var prefs:RefCounted=hud.game.preferences
	enabled.set_pressed_no_signal(prefs.sound_enabled)
	master_slider.set_value_no_signal(prefs.master_volume)
	genre_choice.select(maxi(0,Design.GENRES.find(prefs.music_genre)))
	_refresh_tuner()
	music_slider.set_value_no_signal(prefs.music_volume)
	ambience_slider.set_value_no_signal(prefs.ambient_volume)
	area_label.text=L.text("Aktueller Hörbereich: ")+L.text(str(Design.ZONE_NAMES.get(hud.game.audio.active_zone,Design.ZONE_NAMES.wilderness)))
	show()
	window._fit()
	_preview()
	_update_now_playing()

func close(restore: bool = true) -> void:
	if restore and hud!=null and hud.game!=null:
		hud.game.audio.clear_preview()
	hide()


func _preview() -> void:
	if not visible or hud==null or hud.game==null:return
	hud.game.audio.set_preview({"genre":str(Design.GENRES[genre_choice.selected]),"enabled":enabled.button_pressed,"master":master_slider.value,"music":music_slider.value,"ambient":ambience_slider.value})
	_refresh_tuner()
	_update_now_playing()
	_update_credits()

func _process(delta: float) -> void:
	if not visible:
		return
	_now_playing_timer += delta
	if _now_playing_timer >= 0.7:
		_now_playing_timer = 0.0
		_update_now_playing()

func _update_now_playing() -> void:
	if hud == null or hud.game == null:
		return
	var info: Dictionary = hud.game.audio.now_playing()
	face.active=enabled.button_pressed and str(Design.GENRES[genre_choice.selected])!="off"
	face.signal_level=float(music_slider.value)*float(master_slider.value)
	face.frequency=genre_choice.selected
	face.queue_redraw()
	var track: String = str(info.get("title", ""))
	var artist: String = str(info.get("artist", ""))
	playing_label.text = L.text("Jetzt läuft: ") + (track if not track.is_empty() else L.text("Musik aus"))
	if not artist.is_empty():
		playing_label.text += " · " + artist
	var moment: String = str(info.get("moment", ""))
	if not moment.is_empty():
		playing_label.text += "\n" + L.text("Bergmoment: ") + moment
	if str(info.get("context","")) == "hotel_lobby":
		playing_label.text += "\n" + L.text("Hotelverwaltung · Lobby-Radio ist nur vorübergehend aktiv.")

func _toggle_credits() -> void:
	credits_label.visible = not credits_label.visible
	if credits_label.visible:
		_update_credits()

func _update_credits() -> void:
	if not credits_label.visible or hud == null or hud.game == null:
		return
	var station: String = str(Design.GENRES[genre_choice.selected])
	var records := PackedStringArray()
	for song in hud.game.audio.track_credits(station):
		records.append(str(song.get("title","")) + " · " + str(song.get("artist","")) + "\n" + str(song.get("source_url","")))
	credits_label.text = "\n\n".join(records)

func _refresh_tuner() -> void:
	if hud == null or hud.game == null or genre_choice.selected < 0: return
	var key: String = str(Design.GENRES[genre_choice.selected])
	var song_count: int = hud.game.audio.station_track_count(key)
	station_info.text = L.text("FREQUENZ %02d · %s · %d Titel im Offline-Archiv") % [genre_choice.selected,str(Design.GENRE_NAMES[key]),song_count]
	if key=="space":
		station_info.text += "\n" + L.text("Deep Space Trance · atmosphärische Offline-Auswahl")
		station_info.text += "\n" + L.text("Laufzeiten >4 Minuten sind für die Offline-Titel noch nicht verifiziert.")
	if key=="erg0sphere":
		station_info.text = L.text("KoSch ORIGINALALBUM · ERG0SPHERE Journey")
		station_info.text += "\n" + L.text("Nur auf Knopfdruck: Browser/SoundCloud. Keine automatische Wiedergabe im Spiel.")
	if key in ["folk_alpine","folk_swedish"]:
		station_info.text += "\n" + L.text("10 CC0-Titel · akustische Winterstimmung, regionale Originalaufnahmen noch in Prüfung.")
	if key=="ska_album":
		station_info.text = L.text("KoSch Milton · Ska'radise Lost · Eigenes Album")
		station_info.text += "\n" + L.text("SoundCloud wird nur nach deinem Klick im Browser geladen.")
	if key=="atmospherics":
		station_info.text += "\n" + L.text("Deep atmospheric · 15 CC0-Titel auf Länge und Stimmung zu prüfen (Ziel 3–7 Min.).")
	if key=="punk":
		station_info.text += "\n" + L.text("Skater-Punk-Kuration: richtige Gitarren-Songs werden noch ergänzt.")
	station_info.text += "\n" + L.text("Hotel Lobby FM wird automatisch nur in der Hotelverwaltung verwendet.")
	if is_instance_valid(space_link): space_link.visible=(key=="erg0sphere")
	if is_instance_valid(ska_link): ska_link.visible=(key=="ska_album")
