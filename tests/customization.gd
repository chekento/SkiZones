extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Edit = preload("res://src/core/resort_edit.gd")
const Foot = preload("res://src/core/foot_network.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const Profile = preload("res://src/core/guest_profile.gd")
const Preferences = preload("res://src/core/preferences.gd")
const Terrain = preload("res://src/core/terrain.gd")
const BLUE := [[-170,-235],[-150,-225],[-140,-225],[-120,-235],[-50,-305],[-20,-325],[200,-265],[240,-245],[200,-125],[200,205]]
var passed := 0
var failed := 0
func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)
func _init() -> void:
	var model := Resort.new(); model.new_game(false); model.money = 3000000
	model.build_plaza("plaza", Vector2(340,300))
	check(model.build_building("lodge", Vector2(400,290)).ok, "A normal attached lodge is available for remodeling")
	var building: Dictionary = model.buildings[-1]
	var balance: float = model.money
	var before := model.snapshot()
	var plan := model.preview_change(building.id, [[405,300]], 1)
	check(plan.ok and plan.cost > 0 and model.snapshot() == before, "Move and rotation preview is valid and leaves the live resort untouched")
	var result := model.change_asset(building.id, [[405,300]], "Bergblick", "4a998f", 1)
	check(result.ok and model.money == balance-result.cost and building.name == "Bergblick" and building.id == before.buildings[0].id, "Moving and rotating charges once and preserves the original building identity")
	check(Foot.door(building).x > building.point[0] and is_equal_approx(Foot.door(building).y, building.point[1]) and Foot.building_size(building).x == 18, "Rotated entrances and obstacle footprints match the rotated building")
	var walk_safe := true
	for link in model.pedestrian_layout().links:
		walk_safe = walk_safe and Foot.clear_walk(link.points, model.buildings, model.lifts)
	check(walk_safe and not model.pedestrian_layout().links.is_empty(), "Remodeled building forecourts retain safe pedestrian connections")
	balance = model.money
	check(model.change_asset(building.id, [building.point], "Alpenzeit", "cc7c4e", 1).ok and model.money == balance, "Renaming and recoloring without a structural change are free")
	before = model.snapshot()
	check(not model.change_asset(building.id, [[90000,90000]], "Fehler", "cc7c4e", 1).ok and model.snapshot() == before, "An invalid move is rejected without a partial charge or mutation")
	check(not model.change_asset(building.id, [building.point], "", "cc7c4e", 1).ok and not model.change_asset(building.id, [building.point], "Name", "bad-color", 1).ok, "Invalid names and color values cannot be committed")
	var plaza: Dictionary = model.walk_areas[0]
	check(model.change_asset(plaza.id, [[345,300]], "Dorfplatz", "").ok and plaza.point == [345,300], "Independent walking areas can also be moved and renamed")
	var copy := Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok and copy.buildings[0].rotation == 1 and copy.buildings[0].color == "cc7c4e", "Remodeled buildings and walking areas survive a validated JSON roundtrip")
	for field in ["rotation", "color", "width"]:
		var broken := model.snapshot()
		broken.buildings[0][field] = {"rotation": 9, "color": "oops", "width": 300}[field]
		check(not copy.restore(broken).ok, "Corrupt saved customization is rejected: " + field)
	model.new_game(false); model.money = 3000000
	model.build_piste(BLUE); model.build_piste([BLUE[4],BLUE[7]])
	var piste: Dictionary = model.pistes[0]
	var branch: Dictionary = model.pistes[1]
	var moved := BLUE.duplicate(true); moved[4] = [-49,-305]
	plan = model.preview_change(piste.id, moved, 0, 20)
	check(plan.ok and plan.neighbors.has(branch.id), "Moving a shared waypoint includes its connected piste in the preview")
	check(model.change_asset(piste.id,moved,"Panorama", "",0,20).ok and branch.points[0] == moved[4], "Shared junctions move together rather than leaving a disconnected branch")
	before = model.snapshot()
	var removed: Array = piste.points.duplicate(true); removed.remove_at(4)
	check(not model.preview_change(piste.id,removed,0,20).ok and model.snapshot() == before, "Deleting a shared junction cannot silently detach the neighboring piste")
	model.money=0;before=model.snapshot()
	check(not model.change_asset(piste.id,piste.points,"Zu teuer","",0,24).ok and model.snapshot() == before, "An unaffordable remodel is rejected before any asset or visitor mutation")
	model.new_game(false); model.money = 3000000
	model.build_piste([[245,-130],[275,-30],[255,95],[200,205]])
	piste = model.pistes[0]
	Snow.touch(model.terrain,piste,{"id": 17,"ability": 1,"loops": 0},0.2,0.4)
	var runs: int = piste.rides
	var old_costs := model.operating_costs()
	check(model.change_asset(piste.id,piste.points,"Breite Waldabfahrt","",0,30).ok and Snow.piste_width(piste) == 30 and piste.rides == runs and Snow.roughness(piste) > 0, "Piste widening preserves its number, statistics and resampled snow history")
	check(model.operating_costs() > old_costs and not model.preview_change(piste.id,piste.points,0,60).ok, "Wider pistes have higher upkeep and cannot exceed the allowed width")
	check(Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "A resized piste retains a valid saved snow surface")
	model.new_game(false); model.money = 3000000
	model.build_lift("chair", Vector2(200,205),Vector2(245,-130))
	var lift: Dictionary = model.lifts[0]
	check(model.change_asset(lift.id,[[205,205],[250,-130]],"Waldbahn","a47baa").ok and lift.id == 1 and lift.bottom == [205,205], "Lift stations can be replanned while preserving the lift identity")
	before = model.snapshot()
	check(not model.change_asset(lift.id,[[205,205],[206,206]],"Fehler","").ok and model.snapshot() == before, "An invalid lift length leaves the old lift and budget intact")
	model.new_game(true); model.admit_guest(0)
	var guest: Dictionary = model.guests[0]
	var profile := Profile.describe(model,guest)
	check(profile == Profile.describe(model,guest) and profile.home != "" and profile.years >= 18 and profile.spending == model.ticket_price, "Personal identity and admission spending are stable and come from actual admission")
	guest.phase="queue"; guest.wait=60
	check(Profile.describe(model,guest).mood == "impatient", "An individual guest becomes impatient after their own waiting tolerance")
	guest.phase="moving"; guest.wait=0; guest.needs.hunger=75; model.weather_index=4
	check(Profile.describe(model,guest).mood == "hungry", "Several hours without a service visit create hunger")
	model.Needs.complete(guest, "restaurant")
	check(Profile.describe(model,guest).hunger < 20, "A completed service visit reduces that guest's hunger")
	guest.needs.warmth=30; model.weather_index=1
	check(Profile.describe(model,guest).mood == "cold", "Long exposure in cold weather changes the guest's mood")
	guest.needs.warmth=80; guest.needs.energy=20; model.weather_index=0
	check(Profile.describe(model,guest).mood == "tired", "Many actual descents consume personal energy")
	guest.needs.energy=80; guest.runs=3
	check(Profile.describe(model,guest).mood == "excited", "Successful descents create an enthusiastic mood")
	var migrated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.6-starter.json"))
	var count: int = migrated.guests.size()
	var old_balance: float = migrated.money
	check(copy.restore(migrated).ok and copy.guests.size() == count and copy.money == old_balance and count > 0, "An actual populated 0.6 save migrates without losing guests or funds")
	check(copy.snapshot().version == 11 and Resort.new().restore(JSON.parse_string(JSON.stringify(copy.snapshot()))).ok, "Migrated and customized saves can be saved again in format 10")
	var settings := Preferences.new(); settings.path = "user://display-customization-test.cfg"
	settings.quality="economy"; settings.target_fps=30; settings.snowfall=false; settings.camera_smoothing=false
	check(settings.save_to() == OK, "Graphics and comfort preferences can be saved")
	var loaded := Preferences.new(); loaded.path=settings.path; loaded.load_from()
	check(loaded.quality == "economy" and loaded.target_fps == 30 and not loaded.snowfall and not loaded.camera_smoothing, "Graphics preferences survive an isolated roundtrip")
	var config := ConfigFile.new(); config.set_value("display","quality", "invalid");config.set_value("display","target_fps",-1);config.save(settings.path)
	loaded.load_from()
	check(loaded.quality == "auto" and loaded.target_fps == 60, "Invalid display settings fall back to safe defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings.path))
	print("CUSTOMIZATION: %d passed; %d failed" % [passed,failed])
	quit(1 if failed else 0)
