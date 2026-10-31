extends Control
## Short, full-screen startup screen using the approved PMDD artwork.
## The native Android/engine boot image uses the same art before this scene is ready.
const GAME_SCENE := "res://scenes/main.tscn"

func _ready() -> void:
    _open_game.call_deferred()

func _open_game() -> void:
    var request_error := ResourceLoader.load_threaded_request(GAME_SCENE, "PackedScene")
    # Keep the art visible briefly even if the tiny entry scene loads instantly.
    await get_tree().create_timer(0.8).timeout
    if request_error == OK:
        var state := ResourceLoader.load_threaded_get_status(GAME_SCENE)
        while state == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            await get_tree().process_frame
            state = ResourceLoader.load_threaded_get_status(GAME_SCENE)
        if state == ResourceLoader.THREAD_LOAD_LOADED:
            var packed := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
            if packed != null:
                get_tree().change_scene_to_packed(packed)
                return
    # Recover to the game even when background preloading is not supported.
    get_tree().change_scene_to_file(GAME_SCENE)
