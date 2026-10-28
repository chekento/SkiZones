extends Control
var hud: CanvasLayer
var quality_choice := OptionButton.new()
var fps_choice := OptionButton.new()
var snow := CheckButton.new()
var smoothing := CheckButton.new()
const MODES := ["auto", "economy", "balanced", "high"]

func setup(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.06, 0.09, 0.7)
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = hud._panel(self, -295, -290, 295, 290, 0.5, 0.5)
	var box: VBoxContainer = hud._vbox(panel, 14)
	hud._label(box, "DEIN SPIELGEFÜHL", 13, hud.TEAL)
	hud._label(box, "Darstellung & Komfort", 26)
	hud._label(box, "Grafik", 16, hud.MUTED)
	for caption in ["Automatisch · passt sich an", "Sparsam · für mehr Reserven", "Ausgewogen", "Detailreich"]: quality_choice.add_item(caption)
	quality_choice.custom_minimum_size.y = 46
	box.add_child(quality_choice)
	hud._label(box, "Bildratenziel", 16, hud.MUTED)
	fps_choice.add_item("60 Bilder/s · flüssige Bewegung")
	fps_choice.add_item("30 Bilder/s · weniger Energiebedarf")
	fps_choice.custom_minimum_size.y = 46
	box.add_child(fps_choice)
	snow.text = "Fallenden Schnee darstellen"
	smoothing.text = "Verfolgungskamera sanft bewegen"
	for control in [snow, smoothing]:
		control.custom_minimum_size.y = 46
		box.add_child(control)
	hud._label(box, "Automatisch passt Auflösung und entfernte Details an die verfügbare Leistung an. Gäste, Betrieb und Spieltempo laufen vollständig weiter.", 16, hud.MUTED, true)
	hud._spacer(box)
	hud._button(box, "Einstellungen speichern", func():
		var preferences: RefCounted = hud.game.preferences
		preferences.quality = MODES[quality_choice.selected]
		preferences.target_fps = 60 if fps_choice.selected == 0 else 30
		preferences.snowfall = snow.button_pressed
		preferences.camera_smoothing = smoothing.button_pressed
		preferences.apply(hud.game.view)
		var error: Error = preferences.save_to()
		hud.toast("Darstellung gespeichert." if error == OK else "Darstellung angewendet; Speichern fehlgeschlagen.")
		hide()
	, true)
	hud._button(box, "Zurück", hide)
	hide()

func open() -> void:
	var preferences: RefCounted = hud.game.preferences
	quality_choice.select(MODES.find(preferences.quality))
	fps_choice.select(0 if preferences.target_fps == 60 else 1)
	snow.button_pressed = preferences.snowfall
	smoothing.button_pressed = preferences.camera_smoothing
	show()
