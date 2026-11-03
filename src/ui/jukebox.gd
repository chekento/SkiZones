extends Control
## Explicit opt-in: station playback is off by default; never contacts Suno,
## SoundCloud, an internet radio server or an account without permission.
const L=preload("res://src/core/i18n.gd")
const Design=preload("res://src/core/audio_design.gd")
const FloatingFrame=preload("res://src/ui/floating_window.gd")
const DragScroll=preload("res://src/ui/drag_scroll.gd")
var hud: CanvasLayer
var window:=FloatingFrame.new()
var genre_choice:=OptionButton.new()
var music_slider:=HSlider.new()
var ambience_slider:=HSlider.new()
var area_label:=Label.new()

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
	window.body.add_child(scroll)
	var page: VBoxContainer=hud._vbox(scroll,14)
	page.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hud._label(page,L.text("Deine Musik für den Berg"),25,hud.TEAL)
	hud._label(page,L.text("Kostenlose Offline-Basis: kleine eigens erzeugte Klangschleifen, keine Songs fremder Künstler. Suno-Generierung und lizenzierte Sender sind spätere optionale Erweiterungen."),16,hud.MUTED,true)
	for kind in Design.GENRES:
		genre_choice.add_item(L.text(str(Design.GENRE_NAMES[kind])))
	page.add_child(genre_choice)
	genre_choice.custom_minimum_size.y=55
	genre_choice.item_selected.connect(func(index:int):
		if is_instance_valid(hud.game.audio):hud.game.audio.set_genre(str(Design.GENRES[index]),true)
	)
	hud._label(page,L.text("Musiklautstärke"),17,hud.MUTED)
	music_slider.min_value=0;music_slider.max_value=1;music_slider.step=0.05
	page.add_child(music_slider)
	hud._label(page,L.text("Umgebung: Wind, Stimmen, Liftmotoren"),17,hud.MUTED)
	ambience_slider.min_value=0;ambience_slider.max_value=1;ambience_slider.step=0.05
	page.add_child(ambience_slider)
	area_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	area_label.add_theme_font_size_override("font_size",17)
	area_label.add_theme_color_override("font_color",hud.TEAL)
	page.add_child(area_label)
	hud._button(page,L.text("Jukebox-Einstellungen speichern"),func():
		var prefs:RefCounted=hud.game.preferences
		prefs.music_genre=str(Design.GENRES[genre_choice.selected])
		prefs.music_volume=float(music_slider.value)
		prefs.ambient_volume=float(ambience_slider.value)
		var error:Error=prefs.save_to()
		hud.game.audio.set_genre(prefs.music_genre,false)
		hud.game.audio.sync()
		hud.toast(L.text("Audio gespeichert.") if error==OK else L.text("Audio angewendet; Speichern fehlgeschlagen."))
		close(false)
	,true)
	hud._button(page,L.text("Zurück"),close)
	hide()

func open() -> void:
	var prefs:RefCounted=hud.game.preferences
	hud.game.audio.set_genre(str(prefs.music_genre),false)
	genre_choice.select(maxi(0,Design.GENRES.find(prefs.music_genre)))
	music_slider.value=prefs.music_volume
	ambience_slider.value=prefs.ambient_volume
	area_label.text=L.text("Aktueller Hörbereich: ")+str(hud.game.audio.active_zone)
	show()
	window._fit()

func close(restore: bool = true) -> void:
	if restore and hud!=null and hud.game!=null:
		hud.game.audio.set_genre(str(hud.game.preferences.music_genre),false)
	hide()
