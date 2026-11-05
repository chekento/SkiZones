extends SceneTree
## Regression for Android speed lock, 8x, night catch-up and temporary lift
## planning perspective; progressive foot wear is visual-only.
const FootWear = preload("res://src/world/foot_wear.gd")
var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS ", description)
	else:
		failed += 1
		push_error("FAIL " + description)

func run() -> void:
	var snow := FootWear.new()
	root.add_child(snow)
	snow.setup()
	check(FootWear.wear_stage(1) == 0 and FootWear.wear_stage(2) == 0
		and FootWear.wear_stage(3) == 1 and FootWear.wear_stage(11) == 1
		and FootWear.wear_stage(12) == 2 and FootWear.wear_stage(31) == 2
		and FootWear.wear_stage(32) == 3, "Footprints progress into compact snow, ice groove and packed path at fixed traffic levels")
	snow.sample_guest(41, Vector3(10, 0, 20), 1, 0)
	snow.sample_guest(41, Vector3(16, 0, 20), 2, 0)
	check(not snow._cells.is_empty() and snow._cells.values().any(func(data): return int(data.hits) == 1), "Real movement lays separate footprints on snow")
	var initial: int = snow._cells.size()
	snow.sample_guest(41, Vector3(16, 0, 20), 2, 0)
	check(snow._cells.size() == initial, "Repeated render frames cannot multiply footprints when simulation time stands still")
	for tick in range(3, 40):
		snow.sample_guest(41 + tick, Vector3(10, 0, 20), tick, 0)
		snow.sample_guest(41 + tick, Vector3(16, 0, 20), tick + 1, 0)
	check(snow._cells.values().any(func(data): return FootWear.wear_stage(int(data.hits)) == 3), "Many real guests produce a trodden path on the same snow corridor")
	snow.sample_guest(999, Vector3(50, 0, 50), 50, 0)
	snow.sample_guest(999, Vector3(400, 0, 400), 51, 0)
	check(snow._cells.size() < initial + 100, "Teleports never draw straight trails through the mountain")
	snow.reset()
	check(snow._cells.is_empty() and snow._layers.all(func(layer): return layer.multimesh.visible_instance_count == 0), "Starting another map removes stale foot wear")
	snow.queue_free()

	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_game(true)
	game.set_process(false)
	game.view.set_process(false)
	game.model.campaign.mode = "free"
	game.model.money = 2000000.0
	var saved := JSON.stringify(game.model.snapshot())
	game._accumulator = 45.4
	game.set_speed(1)
	check(game.speed == 1 and not game.paused and game._accumulator < 1.0, "Downshifting after night resume discards queued old-speed catch-up")
	game.set_speed(4)
	check(game.speed == 4, "Manual 4x is available")
	game.set_speed(8)
	check(game.speed == 8, "Manual 8x is available")
	game.set_speed(3)
	check(game.speed == 8, "Unsupported speeds do not silently change the clock")
	game.hud._update_responsive_layout(360)
	check(game.hud.speed_cycle_button.visible and game.hud.speed_cycle_button.custom_minimum_size.y >= 44
		and game.hud.speed_cycle_button.get_index() == 0, "On narrow Android screens the large tempo control remains the first toolbar action")
	game.hud.speed_cycle_button.pressed.emit()
	check(game.speed == 1 and game.hud.speed_cycle_button.text.begins_with("1×"), "On the phone 8x cycles back to 1x without closing the menu")
	game.hud.speed_cycle_button.pressed.emit()
	check(game.speed == 4, "Phone speed control can switch 1x to 4x")
	game.hud.speed_cycle_button.pressed.emit()
	check(game.speed == 8, "Phone speed control can switch 4x to 8x")
	game.hud._update_responsive_layout(1440)
	check(not game.hud.speed_cycle_button.visible and game.hud.speed_buttons.size() == 3
		and game.hud.speed_buttons.all(func(b): return b.visible), "Wide view offers all three explicit 1x/4x/8x buttons")

	if game.view.slopes_visible: game.view.toggle_slopes()
	game.view.set_camera_mode(0)
	game.set_tool("lift")
	check(game.tool == "lift" and game.view.camera_mode == 2 and game.view.slopes_visible, "Starting lift construction enables terrain camera and slope overlays")
	game.clear_plan()
	check(game.tool == "inspect" and game.view.camera_mode == 0 and not game.view.slopes_visible, "Cancel restores the exact original camera and terrain state")
	game.set_tool("lift")
	game.note_manual_camera_change()
	game.view.set_camera_mode(1)
	game.clear_plan()
	check(game.view.camera_mode == 1 and not game.view.slopes_visible, "Manually disabled terrain camera remains at the player's chosen angle")
	game.set_tool("lift")
	game.hud.toggle_slopes()
	game.clear_plan()
	check(not game.view.slopes_visible and game.view.camera_mode == 1, "Manually disabled terrain overlay is not switched back on after building")
	check(JSON.stringify(game.model.snapshot()) == saved, "Camera, speed and snow wear make no changes to gameplay or career save data")
	game.queue_free()
	await process_frame
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
