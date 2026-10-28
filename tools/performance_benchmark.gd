extends SceneTree
## Reproducible CPU benchmark, also runnable unchanged against 0.6 source.
## This measures update work; the headless renderer cannot measure Android FPS.
var game: Node
var results: Array = []
var failed := false
func _init() -> void: call_deferred("run")
func stats(values: Array) -> Dictionary:
	values.sort()
	return {"median": values[values.size()/2], "p95": values[floori(values.size()*0.95)], "max": values[-1]}
func step(speed: int, delta: float) -> void:
	var fraction: float = game.view.simulation_fraction + speed * delta * 0.5
	while fraction >= 1:
		fraction -= 1
		game.model.minute += 1
		for lift in game.model.lifts: lift.clock += 1
		for guest in game.model.guests: guest.elapsed += 1
	game.view.simulation_fraction = fraction
	game.view.motion_running = true
	game.view.motion_rate = speed
func scenario(visitors: int, lifts: int) -> Dictionary:
	game._junction_showcase()
	var model: RefCounted = game.model
	model.guests.clear()
	for i in range(visitors): model.admit_guest(i%3)
	for guest in model.guests:
		for index in range(guest.route.legs.size()):
			if guest.route.legs[index].kind == "ski":
				guest.leg=index;model._start_leg(guest)
				guest.elapsed=guest.duration*(0.1+float(int(guest.id)%75)/100)
				break
	var original: Dictionary = model.lifts[0].duplicate(true)
	for i in range(1,lifts):
		# Generated visual stress layout; its extra lifts are not built by a player.
		var lift: Dictionary = original.duplicate(true)
		lift.id=model.next_id;model.next_id+=1
		var offset := Vector2((i%6-3)*180,(i/6-2)*220)
		lift.bottom=model.Terrain.pack(model.Terrain.unpack(lift.bottom)+offset)
		lift.top=model.Terrain.pack(model.Terrain.unpack(lift.top)+offset)
		lift.length=model._lift_profile(lift.kind,model.Terrain.unpack(lift.bottom),model.Terrain.unpack(lift.top)).length
		model.lifts.append(lift)
	model._invalidate()
	var start := Time.get_ticks_usec();game.view.rebuild()
	var build_ms := (Time.get_ticks_usec()-start)/1000.0
	for piste in model.pistes:
		piste.tracks.clear()
		for i in range(32):
			piste.tracks.append({"key":"bench%d"%i,"guest":i+1,"ability":i%3,"run":i%5,"from":0.0,"until":1.0,"to":0.8})
	start=Time.get_ticks_usec();game.view._draw_tracks()
	var tracks_ms := (Time.get_ticks_usec()-start)/1000.0
	start=Time.get_ticks_usec()
	for piste in model.pistes: game.view._draw_snow(piste)
	var snow_ms := (Time.get_ticks_usec()-start)/1000.0
	var speeds: Array=[]
	for speed in [1,4]:
		game.view.simulation_fraction=0
		for i in range(24): step(speed,1.0/60);game.view._process(0)
		var samples: Array=[]
		for i in range(120):
			step(speed,1.0/60)
			start=Time.get_ticks_usec();game.view._process(1.0/60)
			samples.append((Time.get_ticks_usec()-start)/1000.0)
		var values := stats(samples);values.speed=speed;speeds.append(values)
	if model.guests.size() != visitors or model.lifts.size() != lifts:
		push_error("Stress fixture lost simulated guests or lifts")
		failed = true
	return {"guests": model.guests.size(), "lifts":model.lifts.size(),"pistes":model.pistes.size(),"build_ms":build_ms,"full_tracks_ms":tracks_ms,"snow_update_ms":snow_ms,"frame_cpu_ms":speeds}
func run() -> void:
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
	await process_frame
	game.set_process(false);game.view.set_process(false)
	for case in [[80,1],[360,24]]: results.append(scenario(case[0],case[1]))
	var report := {"version":ProjectSettings.get_setting("application/config/version"),"engine":Engine.get_version_info().string,"mode":"headless CPU; generated stress layout; 24 warmup and 120 measured frames per speed", "cases":results}
	print("PERFORMANCE_JSON ",JSON.stringify(report))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--benchmark-json="):
			var file := FileAccess.open(argument.trim_prefix("--benchmark-json="),FileAccess.WRITE)
			file.store_string(JSON.stringify(report,"  ")+"\n")
	game.queue_free();await process_frame;quit(1 if failed else 0)
