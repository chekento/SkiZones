extends RefCounted
## Small, atomic UI checkpoint bound to the exact independently verified resort save.
const SaveStore = preload("res://src/core/save_store.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Maps = preload("res://src/core/maps.gd")
var path := "user://app-session.json"

func save(game: Node) -> void:
	if not game.has_game: return
	var state := {"map":game.model.map_id,"checksum":FileAccess.get_sha256(SaveStore.path_for_map(game.model.map_id)),"paused":game.paused,"speed":game.speed,"accumulator":game._accumulator,"focus":Terrain.pack(game.view.focus),"yaw":game.view.yaw,"zoom":game.view.zoom,"pitch":game.view.pitch_degrees,"camera_mode":game.view.camera_mode,"tool":game.tool,"plaza_kind":game.plaza_kind,"points":game.points.duplicate(true),"editing_id":game.editing_id,"edit_title":game.edit_title,"edit_color":game.edit_color,"edit_rotation":game.edit_rotation,"edit_width":game.edit_width,"plan_width":game.plan_width,"selected_guest":game.view.selected_guest,"follow_guest":game.view.follow_guest,"suspended_at":Time.get_unix_time_from_system() if game._app_background else 0.0,"running":game._background_running if game._app_background else false,"version":1}
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(state));file.flush();file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))

func read_state() -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 65536: return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {}
	var value: Variant = parser.data
	if not value is Dictionary or value.get("version") != 1 or not value.get("map") is String or not value.get("checksum") is String: return {}
	if not Maps.MAPS.has(value.map): return {}
	if not value.get("paused") is bool or not value.get("running") is bool or not Terrain.number(value.get("speed")): return {}
	if value.speed != int(value.speed) or int(value.speed) not in [1,4]: return {}
	for key in ["accumulator","yaw","zoom","pitch","camera_mode","suspended_at","editing_id","edit_rotation","edit_width","selected_guest","follow_guest"]:
		if not Terrain.number(value.get(key)): return {}
	if value.accumulator < 0 or value.accumulator > 1000000 or value.zoom < 48 or value.zoom > maxf(Maps.spec(value.map).bounds.size.x, Maps.spec(value.map).bounds.size.y) * 1.3 or value.pitch < 20 or value.pitch > 90 or value.camera_mode != int(value.camera_mode) or int(value.camera_mode) not in [0,1,2,3]: return {}
	if not Terrain.unpack(value.get("focus")).is_finite() or not value.get("points") is Array or value.points.size() > 64: return {}
	for point in value.points:
		if not Terrain.unpack(point).is_finite(): return {}
	for key in ["tool","plaza_kind","edit_title","edit_color"]:
		if not value.get(key) is String or value[key].length() > 120: return {}
	if value.tool not in ["inspect","piste","lift","building","plaza","walkway"]: return {}
	if not Terrain.number(value.get("plan_width", 20)) or value.get("plan_width", 20) < 14 or value.get("plan_width", 20) > 36: return {}
	return value

func restore(game: Node, already_loaded: bool = false) -> bool:
	var state := read_state()
	if state.is_empty() or state.checksum != FileAccess.get_sha256(SaveStore.path_for_map(state.map)): return false
	if already_loaded:
		if game.model.map_id != state.map: return false
	elif not SaveStore.load_game(game.model,SaveStore.path_for_map(state.map)).ok: return false
	game.has_game = true;game.paused = state.paused;game.speed = int(state.speed)
	game._accumulator = state.accumulator
	game.view.rebuild()
	game.view.focus = Terrain.unpack(state.focus).clamp(game.model.terrain.bounds.position+Vector2(20,20),game.model.terrain.bounds.end-Vector2(20,20))
	game.view.yaw = state.yaw;game.view.zoom = state.zoom;game.view.camera_mode = int(state.camera_mode);game.view.pitch_degrees = state.pitch
	game.view.selected_guest = int(state.selected_guest);game.view.follow_guest = int(state.follow_guest)
	game.hud.hide_menu();game.hud.atlas.hide();game.set_tool(state.tool)
	game.plan_width = state.get("plan_width", 20)
	game.plaza_kind = state.plaza_kind
	if state.editing_id >= 0:
		if not game.begin_edit(int(state.editing_id),state.edit_title,state.edit_color,int(state.edit_rotation),state.edit_width):
			game.set_tool("inspect")
	if game.tool != "inspect":
		var valid := true
		for point in state.points: valid = valid and game.model.terrain.contains(Terrain.unpack(point))
		if valid: game.points = state.points.duplicate(true)
	game._update_plan();game.view._update_camera();game.hud.refresh()
	if game.model.guests.any(func(g):return g.id == game.view.selected_guest):
		game.hud.show_guest(game.view.selected_guest)
	if state.running and state.suspended_at > 0:
		game._queue_background_time(maxf(0,Time.get_unix_time_from_system()-state.suspended_at),int(state.speed))
	return true
