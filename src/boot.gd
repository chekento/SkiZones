extends Control
## Branded, responsive startup scene. The native Android splash uses the same
## image before Godot can report resource loading percentages.
const GAME_SCENE := "res://scenes/main.tscn"
var progress_label := Label.new()
var progress_bar := ProgressBar.new()
var _progress := 0.0

func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.07, 0.19, 0.25, 0.44)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var bottom := MarginContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bottom.add_theme_constant_override("margin_left", 32)
	bottom.add_theme_constant_override("margin_right", 32)
	bottom.add_theme_constant_override("margin_bottom", 58)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom)
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_END
	layout.add_theme_constant_override("separation", 12)
	bottom.add_child(layout)
	var title := Label.new()
	title.text = "SkiZones · Winterwelt wird geladen"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color.WHITE)
	layout.add_child(title)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 23)
	progress_label.add_theme_color_override("font_color", Color.WHITE)
	layout.add_child(progress_label)
	progress_bar.custom_minimum_size = Vector2(0, 21)
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.show_percentage = false
	layout.add_child(progress_bar)
	set_loading_progress(0.0)
	_open_game.call_deferred()

func set_loading_progress(value: float) -> void:
	_progress = clampf(value, _progress, 1.0)
	progress_bar.value = _progress * 100.0
	progress_label.text = "%d %%" % roundi(_progress * 100.0)

func _open_game() -> void:
	var err := ResourceLoader.load_threaded_request(GAME_SCENE, "PackedScene")
	# A brief brand hold makes the background visible on fast devices.
	var started := Time.get_ticks_msec()
	if err == OK:
		var status := ResourceLoader.THREAD_LOAD_IN_PROGRESS
		while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var progress := [0.0]
			status = ResourceLoader.load_threaded_get_status(GAME_SCENE, progress)
			if progress.size() > 0:
				set_loading_progress(minf(float(progress[0]), 0.99))
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await get_tree().process_frame
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
			if packed != null:
				while Time.get_ticks_msec() - started < 600:
					await get_tree().process_frame
				set_loading_progress(1.0)
				await get_tree().process_frame
				get_tree().change_scene_to_packed(packed)
				return
	# Threaded loading may not be supported on some devices. Keep the
	# graphical startup screen and let Godot's synchronous fallback load.
	set_loading_progress(0.99)
	var fallback := load(GAME_SCENE) as PackedScene
	if fallback != null:
		set_loading_progress(1.0)
		await get_tree().process_frame
		get_tree().change_scene_to_packed(fallback)
