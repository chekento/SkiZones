extends Control
## PMDD image remains the whole backdrop during the real threaded scene load.
## Percentage reflects the engine's resource-loader result, not a fake timer.
const GAME_SCENE := "res://scenes/main.tscn"
var percent := Label.new()
var detail := Label.new()
var progress := ProgressBar.new()

func _ready() -> void:
	var footer := PanelContainer.new()
	footer.name = "LoadFooter"
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -150
	footer.offset_bottom = -18
	footer.offset_left = 26
	footer.offset_right = -26
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.16, 0.23, 0.82)
	style.set_corner_radius_all(15)
	style.set_content_margin_all(16)
	footer.add_theme_stylebox_override("panel", style)
	add_child(footer)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	footer.add_child(content)
	detail.text = "SkiZones wird gestartet …"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_theme_font_size_override("font_size", 23)
	detail.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(detail)
	percent.text = "0 %"
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent.add_theme_font_size_override("font_size", 29)
	percent.add_theme_color_override("font_color", Color("ffe9ac"))
	content.add_child(percent)
	progress.max_value = 100.0
	progress.show_percentage = false
	progress.custom_minimum_size.y = 16
	content.add_child(progress)
	_open_game.call_deferred()

func _set_progress(value: float, message: String) -> void:
	var amount := clampf(value, 0.0, 100.0)
	progress.value = amount
	percent.text = "%d %%" % roundi(amount)
	detail.text = message

func _open_game() -> void:
	_set_progress(0.0, "Spieloberfläche wird vorbereitet …")
	var request_error := ResourceLoader.load_threaded_request(GAME_SCENE, "PackedScene")
	if request_error == OK:
		var report: Array = []
		var state := ResourceLoader.load_threaded_get_status(GAME_SCENE, report)
		while state == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_set_progress(float(report[0]) * 100.0 if not report.is_empty() else 0.0, "Spieloberfläche und Winterwelt werden geladen …")
			await get_tree().process_frame
			report.clear()
			state = ResourceLoader.load_threaded_get_status(GAME_SCENE, report)
		if state == ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
			if packed != null:
				_set_progress(100.0, "Spieloberfläche bereit")
				await get_tree().process_frame
				get_tree().change_scene_to_packed(packed)
				return
	# Fallback keeps the full-size image and a truthful status while loading.
	_set_progress(0.0, "Starte im kompatiblen Modus …")
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME_SCENE)
