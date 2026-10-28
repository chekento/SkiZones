extends SceneTree

const Resort = preload("res://src/core/resort.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Saves = preload("res://src/core/save_store.gd")
const BLUE := [[245, -130], [275, -30], [255, 95], [200, 205]]
const BLACK := [[-170, -235], [-160, -50], [-80, 90], [100, 190]]
var passed := 0
var failed := 0

func _init() -> void:
	_test_terrain()
	_test_building_and_money()
	_test_network()
	_test_capacity()
	_test_day_and_weather()
	_test_saves()
	print("RESULT: %d passed; %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func check(condition: bool, title: String) -> void:
	if condition:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func fresh(starter: bool = true):
	var model := Resort.new()
	model.new_game(starter)
	return model

func _test_terrain() -> void:
	check(Terrain.slope_percent(Vector2(330, 320)) < 1, "Flat valley land is shown as gentle terrain")
	check(Terrain.slope_percent(Vector2(-170, -100)) > 55, "The steep western hillside is identifiable before construction")
	check(Terrain.analyse(BLUE, 0).ok, "Starter blue piste has a valid full profile")
	check(not Terrain.analyse(BLACK, 0).ok, "Steep terrain cannot be painted blue")
	check(not Terrain.analyse(BLACK, 1).ok and Terrain.analyse(BLACK, 2).ok, "Black terrain exceeds the red limit")
	var reversed := BLUE.duplicate(true)
	reversed.reverse()
	check(not Terrain.analyse(reversed, 2).ok, "Pistes cannot run uphill")
	check(not Terrain.analyse([[245, -130], [245, -130]], 0).ok, "Zero-length segments are rejected")
	check(not Terrain.analyse([[245, -130], [900, 900]], 2).ok, "Out-of-bounds geometry is rejected")
	check(not Terrain.analyse([[NAN, 0], [200, 205]], 0).ok, "Non-finite coordinates are rejected")
	var hidden_peak := [[-170, -360], [-170, 190]]
	check(not Terrain.analyse(hidden_peak, 2).ok, "Interior uphill terrain is detected despite a downhill endpoint")

func _test_building_and_money() -> void:
	var model = fresh()
	check(model.pistes.size() == 1 and model.lifts.size() == 1 and model.buildings.size() == 2, "Starter scenario builds every promised asset")
	check(not model.build_building("hotel", Terrain.unpack(model.buildings[0].point)).ok, "Buildings cannot overlap")
	check(not model.build_building("hotel", Vector2(-320, -350)).ok, "Remote buildings need a station")
	var before: float = model.money
	model.money = 0
	check(not model.build_lift("gondola", Vector2(100, 200), Vector2(-170, -235)).ok and model.lifts.size() == 1, "Insufficient funds cannot create an asset")
	model.money = before
	check(not model.preview_lift("chair", Vector2(245, -130), Vector2(200, 205)).ok, "Lift direction must be uphill")
	check(not model.preview_lift("unknown", Vector2(0, 200), Vector2(0, -200)).ok, "Unknown lift types are rejected")
	check(model.take_loan() and not model.take_loan(), "Only one construction loan is available")
	check(model.repay_loan() and model.loan == 0, "Loans can be repaid without duplicate credit")

func _test_network() -> void:
	var empty = fresh(false)
	check(empty.routes_for(0).is_empty(), "Empty resorts do not sell unusable tickets")
	check(not empty.admit_guest(0) and empty.total_guests == 0, "Visitors cannot enter without a complete circuit")
	var model = fresh()
	check(model.routes_for(0).size() == 1 and model.routes_for(2).size() == 1, "Beginner and expert can use the starter circuit")
	var lift_id: int = model.lifts[0].id
	model.set_enabled(lift_id, false)
	check(model.routes_for(0).is_empty(), "Closing the only lift disconnects the circuit")
	model.set_enabled(lift_id, true)
	check(model.routes_for(0).size() == 1, "Reopening a lift invalidates the route cache")
	model.money = 1000000
	check(model.build_piste(BLACK, 2).ok, "Expert descent can be planned before its lift")
	check(model.routes_for(2).size() == 1, "Disconnected black descent is excluded from visitor routes")
	check(model.build_lift("chair", Vector2(100, 200), Vector2(-170, -235)).ok, "A second hillside can be opened with a lift")
	check(model.routes_for(0).size() == 1 and model.routes_for(2).size() == 2, "Visitor ability filters the reachable descents")
	model.demolish(lift_id)
	check(model.routes_for(0).is_empty() and model.routes_for(2).size() == 1, "Demolition updates the transport network")
	# A summit lift connected only through the lower lift must not be reachable alone.
	var chained = fresh()
	chained.money = 1000000
	var upper_bottom := Vector2(210, -130)
	var upper_top := Vector2(250, -310)
	check(chained.build_lift("drag", upper_bottom, upper_top).ok, "A lift can extend another lift uphill")
	check(chained.build_piste([[250, -310], [290, -220], [245, -130]], 1).ok, "An intermediate descent can return to another station")
	check(chained.routes_for(1).size() == 2, "Graph routing supports multiple consecutive lifts and descents")
	chained.set_enabled(chained.lifts[0].id, false)
	check(chained.routes_for(1).is_empty(), "An upper lift cannot bypass a disconnected valley connection")

func _test_capacity() -> void:
	var model = fresh()
	model.money = 1000000
	model.build_piste([[245, -130], [305, 0], [200, 205]], 1)
	check(model.routes_for(1).size() == 2, "Two pistes can share a single lift")
	for i in range(60):
		model.admit_guest(1)
	for guest in model.guests:
		for index in range(guest.route.legs.size()):
			if guest.route.legs[index].kind == "lift":
				guest.leg = index
				break
		model._start_leg(guest)
	for i in range(30):
		model.advance_minute(false)
	check(model.lifts[0].boarded == 7 and model.queue_size() == 53, "Shared lift boards seven guests per real minute at normal speed, across all pistes")
	for i in range(30):
		model.advance_minute(false)
	check(model.lifts[0].boarded == 14, "Lift throughput remains bounded on subsequent minutes")
	model.demolish(model.lifts[0].id)
	model.advance_minute(false)
	check(model.guests.is_empty(), "Guests leave cleanly after their lift is demolished")

func _test_day_and_weather() -> void:
	var model = fresh()
	for i in range(600):
		model.advance_minute()
	check(model.minute == 1080, "Admission ends at 18:00 without skipping simulation time")
	while not model.day_finished():
		model.advance_minute(false)
	check(model.guests.is_empty(), "The report waits for guests to finish their real return routes")
	check(model.total_guests > 60 and model.total_rides > 60, "Starter resort completes a populated trading day")
	check(model.last_report.costs > 0 and model.last_report.tickets > 0, "Daily report includes actual income and operating costs")
	var balance: float = model.money
	model.advance_minute()
	check(model.money == balance, "Day-end costs cannot be charged twice")
	var condition: float = model.pistes[0].condition
	check(model.next_day() and model.day == 2 and model.minute == 480 and model.pistes[0].condition >= condition, "Next day grooms pistes and resets trading hours")
	check(not model.next_day(), "Players cannot skip operating days")
	model.money = 1000000
	model.build_lift("chair", Vector2(100, 200), Vector2(-170, -235))
	model.weather_index = 3
	model._invalidate()
	check(model.lift_open(model.lifts[0]) and not model.lift_open(model.lifts[1]), "Storm wind respects each lift's wind limit")
	model.weather_index = 4
	var snow: float = model.pistes[0].snow
	model.advance_minute(false)
	check(model.pistes[0].snow < snow, "Warm weather melts snow")
	model.pistes[0].snow = 5.0
	model._invalidate()
	check(model.routes_for(0).is_empty(), "Snow shortage closes a piste to new itineraries")

func _test_saves() -> void:
	var model = fresh()
	for i in range(85):
		model.advance_minute()
	var copy = fresh(false)
	var data: Dictionary = JSON.parse_string(JSON.stringify(model.snapshot()))
	check(copy.restore(data).ok, "JSON roundtrip restores a populated mid-day game")
	check(copy.minute == model.minute and copy.guests.size() == model.guests.size() and copy.money == model.money, "Save retains clock, money and active guests")
	for i in range(12):
		copy.advance_minute()
		model.advance_minute()
	check(copy.total_rides == model.total_rides and copy.total_guests == model.total_guests and absf(copy.money - model.money) < 0.001, "Loaded simulation preserves RNG and future behavior")
	var old_balance: float = copy.money
	var damaged := model.snapshot()
	damaged.pistes[0].points[0] = [NAN, 0]
	check(not copy.restore(damaged).ok and copy.money == old_balance, "Invalid geometry cannot partially overwrite a running game")
	damaged = model.snapshot()
	damaged.pistes[0].id = damaged.lifts[0].id
	check(not copy.restore(damaged).ok, "Duplicate asset identifiers are rejected")
	damaged = model.snapshot()
	damaged.guests[0].leg = 99999
	check(not copy.restore(damaged).ok, "Invalid visitor itinerary indices are rejected")
	var path := "user://test_skizones_save.json"
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	check(Saves.save_game(model, path).ok, "First save is written successfully")
	model.advance_minute()
	check(Saves.save_game(model, path).ok, "Replacement save preserves a previous backup")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken interrupted save")
	file.close()
	check(Saves.load_game(copy, path).ok and copy.minute == model.minute - 1, "A damaged main save falls back to its verified backup")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
