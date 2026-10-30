extends RefCounted
var path := "user://display.cfg"
var quality := "auto"
var target_fps := 60
var snowfall := true
var camera_smoothing := true
var language := "system"
var career_slot := 1
var free_play := false

func load_from() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	var value: Variant = config.get_value("display", "quality", "auto")
	quality = value if value is String and value in ["auto", "economy", "balanced", "high"] else "auto"
	value = config.get_value("display", "target_fps", 60)
	target_fps = value if value is int and value in [30, 60] else 60
	value = config.get_value("display", "snowfall", true)
	snowfall = value if value is bool else true
	value = config.get_value("display", "camera_smoothing", true)
	camera_smoothing = value if value is bool else true
	value=config.get_value("display","language","system")
	language=value if value is String and value in ["system","de","en"] else "system"
	value=config.get_value("play","career_slot",1)
	career_slot=int(value) if value is int and value>=1 and value<=4 else 1
	value=config.get_value("play","free_play",false)
	free_play=value if value is bool else false

func save_to() -> Error:
	var config := ConfigFile.new()
	for key in ["quality", "target_fps", "snowfall", "camera_smoothing", "language"]:
		config.set_value("display", key, get(key))
	config.set_value("play","career_slot",career_slot)
	config.set_value("play","free_play",free_play)
	return config.save(path)

func apply(view: Node3D) -> void:
	Engine.max_fps = target_fps
	view.set_quality(quality)
	view.frame_target = 1.0 / target_fps
	view._frame_average = view.frame_target
	view.effects_enabled = snowfall
	view.camera_smoothing = camera_smoothing
	view._atmosphere_tick = ""
