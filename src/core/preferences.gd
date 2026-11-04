extends RefCounted
var path := "user://display.cfg"
var quality := "auto"
var visual_style := "alpine"
var target_fps := 60
var snowfall := true
var camera_smoothing := true
var language := "system"
var career_slot := 1
var free_play := false
var day_length := "balanced"
var contour_lines := true
var wildlife := true
var night_forward := true
var sound_enabled := true
var sound_volume := 55
var radio_station := "piano"

func load_from() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	var value: Variant = config.get_value("display", "quality", "auto")
	quality = value if value is String and value in ["auto", "economy", "balanced", "high"] else "auto"
	value = config.get_value("display", "visual_style", "alpine")
	visual_style = value if value is String and value in ["alpine", "comic", "pastel", "cinematic", "crisp"] else "alpine"
	value = config.get_value("display", "target_fps", 60)
	target_fps = value if value is int and value in [30, 60] else 60
	value = config.get_value("display", "snowfall", true)
	snowfall = value if value is bool else true
	value = config.get_value("display", "camera_smoothing", true)
	camera_smoothing = value if value is bool else true
	value=config.get_value("display","language","system")
	language=value if value is String and value in ["system","de","en"] else "system"
	value=config.get_value("play","day_length","balanced")
	day_length=value if value is String and value in ["balanced","compact","cozy"] else "balanced"
	for key in ["contour_lines","wildlife","night_forward"]:
		value=config.get_value("display",key,true)
		set(key,value if value is bool else true)
	value=config.get_value("play","career_slot",1)
	career_slot=int(value) if value is int and value>=1 and value<=4 else 1
	value=config.get_value("play","free_play",false)
	free_play=value if value is bool else false
	value=config.get_value("audio","sound_enabled",true)
	sound_enabled=value if value is bool else true
	value=config.get_value("audio","sound_volume",55)
	sound_volume=clampi(int(value),0,100) if value is int else 55
	value=config.get_value("audio","radio_station","piano")
	radio_station=value if value is String and value in ["piano","panorama","village","nature"] else "piano"

func save_to() -> Error:
	var config := ConfigFile.new()
	for key in ["quality", "visual_style", "target_fps", "snowfall", "camera_smoothing", "language", "contour_lines", "wildlife", "night_forward"]:
		config.set_value("display", key, get(key))
	config.set_value("play","day_length",day_length)
	config.set_value("play","career_slot",career_slot)
	config.set_value("play","free_play",free_play)
	config.set_value("audio","sound_enabled",sound_enabled)
	config.set_value("audio","sound_volume",sound_volume)
	config.set_value("audio","radio_station",radio_station)
	return config.save(path)

func apply(view: Node3D) -> void:
	Engine.max_fps = target_fps
	view.set_contours(contour_lines)
	view.wildlife_enabled=wildlife
	view.set_quality(quality)
	view.set_visual_style(visual_style)
	view.frame_target = 1.0 / target_fps
	view._frame_average = view.frame_target
	view.effects_enabled = snowfall
	view.camera_smoothing = camera_smoothing
	view._atmosphere_tick = ""

