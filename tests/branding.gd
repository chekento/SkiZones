extends SceneTree
## Release gate: tracked assets load, icon paths exist, correct startup scene scales proportionally.

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var source_paths: Array[String] = [
        "res://assets/branding/skizones_wordmark.png",
        "res://assets/branding/source_icon.png",
        "res://assets/branding/source_splash.png",
        "res://assets/branding/icon_192.png",
        "res://assets/branding/icon_512.png",
        "res://assets/branding/icon_1024.png",
        "res://assets/branding/adaptive_foreground_432.png",
        "res://assets/branding/adaptive_background_432.png",
        "res://assets/branding/splash_1920.png"
    ]
    for path in source_paths:
        if not FileAccess.file_exists(path):
            push_error("Branding asset missing: " + path)
            quit(1)
            return
    var splash := load("res://assets/branding/splash_1920.png") as Texture2D
    var icon := load("res://assets/branding/icon_1024.png") as Texture2D
    var foreground := load("res://assets/branding/adaptive_foreground_432.png") as Texture2D
    if splash == null or splash.get_width() != 1920 or splash.get_height() != 1080:
        push_error("Startup splash is not a 1920x1080 texture")
        quit(1)
        return
    if icon == null or icon.get_width() != 1024 or foreground == null or foreground.get_width() != 432:
        push_error("Android icon sources invalid")
        quit(1)
        return
    if ProjectSettings.get_setting("application/run/main_scene") != "res://scenes/boot.tscn":
        push_error("New startup scene is not selected")
        quit(1)
        return
    var packed := load("res://scenes/boot.tscn") as PackedScene
    if packed == null:
        push_error("Startup scene cannot be loaded")
        quit(1)
        return
    var splash_scene := packed.instantiate()
    var rect := splash_scene.get_node("Image") as TextureRect
    if rect == null or rect.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED:
        push_error("Splash does not use responsive aspect-covered layout")
        quit(1)
        return
    splash_scene.free()
    print("PASS: SkiZones app icon, PNG boot splash and responsive startup scene")
    print("RESULT: 1 passed; 0 failed")
    quit(0)

