extends Control
const L = preload("res://src/core/i18n.gd")
var hud: CanvasLayer
var quality_choice := OptionButton.new()
var fps_choice := OptionButton.new()
var snow := CheckButton.new()
var smoothing := CheckButton.new()
var language_choice := OptionButton.new()
const MODES := ["auto", "economy", "balanced", "high"]
const LANGUAGES := ["system","de","en"]
const DragScroll = preload("res://src/ui/drag_scroll.gd")

func setup(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.06, 0.09, 0.7)
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer=hud._panel(self,-315,32,315,-32,0.5,1)
	var scroll:=DragScroll.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box: VBoxContainer=hud._vbox(scroll,14)
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hud._label(box, L.text("DEIN SPIELGEFÜHL"), 13, hud.TEAL)
	hud._label(box, L.text("Darstellung & Komfort"), 26)
	hud._label(box,L.text("Sprache"),16,hud.MUTED)
	for caption in [L.text("Systemsprache"),L.text("Deutsch"),L.text("English")]: language_choice.add_item(caption)
	language_choice.custom_minimum_size.y=46
	box.add_child(language_choice)
	hud._label(box, L.text("Grafik"), 16, hud.MUTED)
	for caption in [L.text("Automatisch · passt sich an"), L.text("Sparsam · für mehr Reserven"), L.text("Ausgewogen"), L.text("Detailreich")]: quality_choice.add_item(caption)
	quality_choice.custom_minimum_size.y = 46
	box.add_child(quality_choice)
	hud._label(box, L.text("Bildratenziel"), 16, hud.MUTED)
	fps_choice.add_item(L.text("60 Bilder/s · flüssige Bewegung"))
	fps_choice.add_item(L.text("30 Bilder/s · weniger Energiebedarf"))
	fps_choice.custom_minimum_size.y = 46
	box.add_child(fps_choice)
	snow.text = L.text("Fallenden Schnee darstellen")
	smoothing.text = L.text("Verfolgungskamera sanft bewegen")
	for control in [snow, smoothing]:
		control.custom_minimum_size.y = 46
		box.add_child(control)
	hud._label(box, L.text("Automatisch passt Auflösung und entfernte Details an die verfügbare Leistung an. Gäste, Betrieb und Spieltempo laufen vollständig weiter."), 16, hud.MUTED, true)
	hud._spacer(box)
	hud._button(box, L.text("Einstellungen speichern"), func():
		var preferences: RefCounted = hud.game.preferences
		preferences.quality = MODES[quality_choice.selected]
		preferences.target_fps = 60 if fps_choice.selected == 0 else 30
		preferences.snowfall = snow.button_pressed
		preferences.camera_smoothing = smoothing.button_pressed
		var language: String=LANGUAGES[language_choice.selected]
		var changed: bool=language != preferences.language
		preferences.language=language
		preferences.apply(hud.game.view)
		var error: Error = preferences.save_to()
		hud.toast(L.text("Darstellung gespeichert.") if error == OK else L.text("Darstellung angewendet; Speichern fehlgeschlagen."))
		hide()
		if changed: hud.game.apply_language(language)
	, true)
	hud._button(box, L.text("Zurück"), hide)
	hide()

func open() -> void:
	var preferences: RefCounted = hud.game.preferences
	quality_choice.select(MODES.find(preferences.quality))
	fps_choice.select(0 if preferences.target_fps == 60 else 1)
	snow.button_pressed = preferences.snowfall
	smoothing.button_pressed = preferences.camera_smoothing
	language_choice.select(LANGUAGES.find(preferences.language))
	show()
