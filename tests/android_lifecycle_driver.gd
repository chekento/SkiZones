extends Node
## Included only by the emulator test export, never by the public ARM64 APK.
var game: Node
var timer := 0.0
var boot := ""
func setup(controller: Node) -> void:
	game=controller;boot=str(Time.get_unix_time_from_system())
	if not game.has_game:
		game.start_game(true)
		for i in range(9):game.model.admit_guest(i%3)
		for i in range(80):game.model.advance_minute(false)
		game.speed=4
		game.view.zoom=250;game.view._update_camera()
	write_health()
func _process(delta: float) -> void:
	if game == null: return
	timer += delta
	if timer >= 0.5:
		timer=0;write_health()
func write_health() -> void:
	var file:=FileAccess.open("user://lifecycle-ci.json.tmp",FileAccess.WRITE)
	if file == null:return
	file.store_string(JSON.stringify({"boot":boot,"map":game.model.map_id,"minute":game.model.minute,"day":game.model.day,"guests":game.model.guests.map(func(g):return g.id),"sports":game.model.guests.map(func(g):return g.get("sport","ski")),"resumes":game.resume_count,"background":game._app_background,"camera":game.view.camera.is_current(),"paused":game.paused,"size":[get_viewport().size.x,get_viewport().size.y]}))
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path("user://lifecycle-ci.json.tmp"),ProjectSettings.globalize_path("user://lifecycle-ci.json"))
