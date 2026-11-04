extends Control
const L = preload("res://src/core/i18n.gd")
const VisualStyles = preload("res://src/core/visual_styles.gd")
var hud: CanvasLayer
var quality_choice := OptionButton.new()
var fps_choice := OptionButton.new()
var style_choice := OptionButton.new()
var style_hint := Label.new()
var style_swatches: Array = []
var snow := CheckButton.new()
var smoothing := CheckButton.new()
var day_choice := OptionButton.new()
var contours := CheckButton.new()
var wildlife := CheckButton.new()
var night_forward := CheckButton.new()
var language_choice := OptionButton.new()
const MODES := ["auto", "economy", "balanced", "high"]
const LANGUAGES := ["system","de","en"]
const DragScroll = preload("res://src/ui/drag_scroll.gd")

func setup(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.06, 0.09, 0.38)
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
	hud._label(box, L.text("Bildstil · neun Looks"), 16, hud.MUTED)
	for title in VisualStyles.NAMES:
		style_choice.add_item(L.text(title))
	style_choice.custom_minimum_size.y = 54
	box.add_child(style_choice)
	style_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	style_hint.add_theme_font_size_override("font_size", 16)
	style_hint.add_theme_color_override("font_color", hud.TEAL)
	box.add_child(style_hint)
	var swatch_row := HBoxContainer.new()
	swatch_row.add_theme_constant_override("separation", 7)
	box.add_child(swatch_row)
	for unused in range(5):
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(45, 24)
		swatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch_row.add_child(swatch)
		style_swatches.append(swatch)
	style_choice.item_selected.connect(func(index: int):
		_describe_style(index)
		if visible:
			hud.game.view.set_visual_style(VisualStyles.IDS[index])
	)
	hud._label(box, L.text("Live-Vorschau: Der Berg ändert sich sofort. Zurück verwirft die Auswahl; Speichern übernimmt sie dauerhaft."), 15, hud.MUTED, true)
	hud._label(box, L.text("Grafikqualität · unabhängig vom Stil"), 16, hud.MUTED)
	for caption in [L.text("Automatisch · passt sich an"), L.text("Sparsam · für mehr Reserven"), L.text("Ausgewogen"), L.text("Detailreich")]: quality_choice.add_item(caption)
	quality_choice.custom_minimum_size.y = 46
	box.add_child(quality_choice)
	hud._label(box, L.text("Bildratenziel"), 16, hud.MUTED)
	fps_choice.add_item(L.text("60 Bilder/s · flüssige Bewegung"))
	fps_choice.add_item(L.text("30 Bilder/s · weniger Energiebedarf"))
	fps_choice.custom_minimum_size.y = 46
	box.add_child(fps_choice)
	hud._label(box,L.text("Tageslänge & ruhiger Feierabend"),16,hud.MUTED)
	for caption in [L.text("Ausgewogen · kürzere Skitage"),L.text("Kompakt · zügiger Aufbau"),L.text("Gemütlich · mehr Zeit am Berg")]: day_choice.add_item(caption)
	day_choice.custom_minimum_size.y=46
	box.add_child(day_choice)
	hud._label(box,L.text("Alle Gäste, Fahrten und Betriebskosten folgen derselben Spielzeit. Von 17 bis 22 Uhr bleibt der Abend gemütlich."),15,hud.MUTED,true)
	contours.text=L.text("Dezente Höhenlinien auf dem Gelände")
	wildlife.text=L.text("Rehe, Füchse und Schneehasen darstellen")
	night_forward.text=L.text("Ruhige Nächte automatisch bis zum Morgen vorspulen")
	snow.text = L.text("Fallenden Schnee darstellen")
	smoothing.text = L.text("Verfolgungskamera sanft bewegen")
	for control in [contours,wildlife,night_forward,snow,smoothing]:
		control.custom_minimum_size.y = 46
		box.add_child(control)
	hud._label(box, L.text("Automatisch passt Auflösung und entfernte Details an die verfügbare Leistung an. Gäste, Betrieb und Spieltempo laufen vollständig weiter."), 16, hud.MUTED, true)
	hud._spacer(box)
	hud._button(box, L.text("Einstellungen speichern"), func():
		var preferences: RefCounted = hud.game.preferences
		preferences.quality = MODES[quality_choice.selected]
		preferences.visual_style = VisualStyles.IDS[style_choice.selected]
		preferences.target_fps = 60 if fps_choice.selected == 0 else 30
		preferences.day_length=["balanced","compact","cozy"][day_choice.selected]
		preferences.contour_lines=contours.button_pressed
		preferences.wildlife=wildlife.button_pressed
		preferences.night_forward=night_forward.button_pressed
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
	visibility_changed.connect(_restore_unsaved_preview)

func open() -> void:
	var preferences: RefCounted = hud.game.preferences
	quality_choice.select(MODES.find(preferences.quality))
	style_choice.select(maxi(0, VisualStyles.IDS.find(preferences.visual_style)))
	_describe_style(style_choice.selected)
	fps_choice.select(0 if preferences.target_fps == 60 else 1)
	day_choice.select(["balanced","compact","cozy"].find(preferences.day_length))
	contours.button_pressed=preferences.contour_lines
	wildlife.button_pressed=preferences.wildlife
	night_forward.button_pressed=preferences.night_forward
	snow.button_pressed = preferences.snowfall
	smoothing.button_pressed = preferences.camera_smoothing
	language_choice.select(LANGUAGES.find(preferences.language))
	show()

func _restore_unsaved_preview() -> void:
	if not visible and hud != null and hud.game != null:
		hud.game.view.set_visual_style(hud.game.preferences.visual_style)

func _describe_style(index: int) -> void:
	style_hint.text = L.text(VisualStyles.DESCRIPTIONS[clampi(index, 0, VisualStyles.IDS.size() - 1)])
	var colors: Dictionary = VisualStyles.palette(VisualStyles.IDS[clampi(index, 0, VisualStyles.IDS.size() - 1)])
	for i in range(style_swatches.size()):
		style_swatches[i].color = Color(colors[["top", "horizon", "snow", "rock", "ambient"][i]])

