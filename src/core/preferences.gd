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
var music_genre := "off"
var music_volume := 0.35
var ambient_volume := 0.45
var sound_enabled := true
var master_volume := 1.0

func load_from() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	var value: Variant = config.get_value("display", "quality", "auto")
	quality = value if value is String and value in ["auto", "economy", "balanced", "high"] else "auto"
	value = config.get_value("display", "visual_style", "alpine")
	visual_style = value if value is String and value in ["alpine", "comic", "pastel", "cinematic", "crisp", "piste_map"] else "alpine"
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
	value=config.get_value("audio","music_genre","off")
	music_genre=value if value is String and value in ["off","alpine","techno","hiphop","punk","classical","meditative","freeride","space","apres","glacier","erg0sphere","folk_alpine","folk_swedish","atmospherics","mountain_sunrise","lodge_lofi","ska_album"] else "off"
	value=config.get_value("audio","music_volume",0.35)
	music_volume=clampf(float(value),0,1) if (value is int or value is float) and is_finite(float(value)) else 0.35
	value=config.get_value("audio","ambient_volume",0.45)
	ambient_volume=clampf(float(value),0,1) if (value is int or value is float) and is_finite(float(value)) else 0.45
	value=config.get_value("play","career_slot",1)
	career_slot=int(value) if value is int and value>=1 and value<=4 else 1
	value=config.get_value("play","free_play",false)
	free_play=value if value is bool else false
	value=config.get_value("audio","sound_enabled",true)
	sound_enabled=value if value is bool else true
	var legacy_volume: Variant=config.get_value("audio","sound_volume",100)
	var legacy_master: float=clampf(float(legacy_volume)/100.0,0,1) if (legacy_volume is int or legacy_volume is float) and is_finite(float(legacy_volume)) else 1.0
	value=config.get_value("audio","master_volume",legacy_master)
	master_volume=clampf(float(value),0,1) if (value is int or value is float) and is_finite(float(value)) else 1.0
	if not config.has_section_key("audio","music_genre") and config.has_section_key("audio","radio_station"):
		var legacy: String=str(config.get_value("audio","radio_station","nature"))
		music_genre={"piano":"classical","panorama":"meditative","village":"alpine","nature":"off"}.get(legacy,"off")

func save_to() -> Error:
	var config := ConfigFile.new()
	for key in ["quality", "visual_style", "target_fps", "snowfall", "camera_smoothing", "language", "contour_lines", "wildlife", "night_forward"]:
		config.set_value("display", key, get(key))
	config.set_value("audio","music_genre",music_genre)
	config.set_value("audio","music_volume",music_volume)
	config.set_value("audio","ambient_volume",ambient_volume)
	config.set_value("play","day_length",day_length)
	config.set_value("play","career_slot",career_slot)
	config.set_value("play","free_play",free_play)
	config.set_value("audio","sound_enabled",sound_enabled)
	config.set_value("audio","master_volume",master_volume)
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


