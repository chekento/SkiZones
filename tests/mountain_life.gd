extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Mountain = preload("res://src/core/mountain.gd")
const Maps = preload("res://src/core/maps.gd")
const Passport = preload("res://src/core/passport.gd")
const Motion = preload("res://src/core/ski_motion.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const Saves = preload("res://src/core/save_store.gd")
const Terrain = preload("res://src/core/terrain.gd")
var passed := 0
var failed := 0

func _init() -> void:
	_maps()
	_passport()
	_motion_and_snow()
	_grooming_and_saves()
	print("MOUNTAIN LIFE: %d passed; %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func check(value: bool, title: String) -> void:
	if value:
		passed += 1
		print("PASS ", title)
	else:
		failed += 1
		push_error("FAIL " + title)

func fresh(id: String = "sonnenhang"):
	var model := Resort.new()
	model.new_game(true, 20261027, id)
	return model

func skiing(model: RefCounted, ability: int = 0) -> Dictionary:
	model.admit_guest(ability)
	var guest: Dictionary = model.guests[-1]
	for i in range(guest.route.legs.size()):
		if guest.route.legs[i].kind == "ski":
			guest.leg = i
			model._start_leg(guest)
			break
	return guest

func _maps() -> void:
	var heights: Array = []
	for id in Maps.FANTASY_MAPS:
		var model = fresh(id)
		check(model.pistes.size() == 1 and model.routes_for(0).size() == 1 and model.terrain.bounds.size.x >= 2880, "A larger %s has a working starter circuit" % id)
		heights.append(roundi(model.terrain.height(Vector2(-1000, -1800))))
	check(Maps.area("sonnenhang") > Terrain.BOUNDS.get_area() / 1000000 * 10 and Maps.area("dreigipfel") > 25, "The first area is over ten times larger and the final region exceeds 25 km²")
	check(heights[0] != heights[1] and heights[1] != heights[2] and heights[2] != heights[3], "Each region has different actual mountain geometry")
	var small = fresh()
	var large = fresh("dreigipfel")
	check(not small.terrain.contains(Vector2(2500, -4200)) and large.terrain.contains(Vector2(2500, -4200)), "Terrain bounds belong to each resort instance")
	check(small.terrain.height(Vector2(200, 0)) == Terrain.height(Vector2(200, 0)), "The original valley remains compatible with existing layouts")
	check(small.preview_lift("chair", Vector2(1300, 200), Vector2(1300, -1800)).ok, "A valid two-kilometre lift can be planned in the expanded region")
	check(not small.preview_lift("carpet", Vector2(200, 205), Vector2(245, -130)).ok, "Moving carpets remain restricted to short practice slopes")

func _passport() -> void:
	var passport := Passport.new()
	check(passport.unlocked("sonnenhang") and not passport.unlocked("fichtenkamm"), "Only the first region is available to a new player")
	var model = fresh()
	model.total_guests = 800
	model.campaign.rank = 2
	model.campaign.completed = 2
	passport.record(model)
	check(passport.unlocked("fichtenkamm") and not passport.unlocked("gletscherwelt"), "Real rank, visitors and contracts unlock the next region")
	passport.record(fresh())
	check(passport.unlocked("fichtenkamm") and passport.totals().guests == 800, "Restarting a resort preserves unlocked regions without duplicating visitor records")
	var next = fresh("fichtenkamm")
	next.total_guests = 1200
	next.campaign.rank = 3
	next.campaign.completed = 3
	passport.record(next)
	check(passport.unlocked("gletscherwelt") and not passport.unlocked("dreigipfel"), "Progress across separate resorts contributes to the mountain passport")
	var path := "user://test_passport.json"
	check(passport.save_to(path), "The mountain passport is saved atomically")
	var copy := Passport.new()
	copy.load_from(path)
	check(copy.unlocked("gletscherwelt") and copy.data.last_map == "fichtenkamm", "A saved passport retains unlocks and the last visited area")
	passport.save_to(path)
	var broken := FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("interrupted write")
	broken.close()
	copy = Passport.new()
	copy.load_from(path)
	check(copy.unlocked("gletscherwelt"), "A damaged passport falls back to its verified previous copy")
	check(Saves.path_for_map("sonnenhang") != Saves.path_for_map("fichtenkamm"), "Each region uses a separate resort save slot")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))

func _motion_and_snow() -> void:
	var model = fresh()
	var first := skiing(model)
	var second := skiing(model)
	first.elapsed = first.duration * 0.4
	second.elapsed = second.duration * 0.4
	check(model.guest_position(first).distance_to(model.guest_position(second)) > 0.5, "Guests take different personal lines down the same piste")
	check(Motion.name_for(first.id) != Motion.name_for(second.id) and first.duration != second.duration, "Guests retain individual names, styles and travel durations")
	var contained := true
	var piste: Dictionary = model.pistes[0]
	for id in range(1, 40):
		for step in range(1, 20):
			var fraction := step / 20.0
			contained = contained and Motion.position(model.terrain, piste, id, id % 3, fraction).distance_to(model.terrain.point_on_path(piste.points, fraction)) < 9
	check(contained, "Varied carving lines stay within the groomed piste")
	var delta: float = model.guest_position(first, 0.5).distance_to(model.guest_position(first))
	check(delta > 1 and delta < 15, "A real second advances an individual skier by metres rather than a whole descent")
	var route: Dictionary = model.routes_for(0)[0]
	var ride_minutes := 0.0
	for leg in route.legs:
		if leg.kind == "lift":
			ride_minutes += leg.minutes
	check(ride_minutes / Resort.MINUTES_PER_SECOND > 120, "The starter lift takes more than two real minutes at normal speed")
	first.elapsed = 0
	second.elapsed = 0
	for i in range(40):
		model.advance_minute(false)
	check(not piste.tracks.is_empty() and piste.tracks[0].to > 0.5, "Actual skiing leaves a persistent traversed track")
	check(Snow.roughness(piste) > 0 and piste.surface.min() < 0 and piste.surface.max() > 0, "Ski traffic makes local troughs and raised snow shoulders")
	check(piste.snow < 55, "Traffic also changes the piste snow quantity")
	for id in range(10, 100):
		var guest := {"id": id, "ability": id % 3, "loops": 0, "leg": 0, "age": 0}
		Snow.start(piste, guest)
		Snow.touch(model.terrain, piste, guest, 0, 1)
	check(piste.tracks.size() == Snow.MAX_TRACKS and piste.surface.min() >= -0.35 and piste.surface.max() <= 0.6, "Track history and snow deformation stay bounded under heavy traffic")
	var old_roughness := Snow.roughness(piste)
	Snow.groom(piste, 0.9)
	check(piste.tracks.is_empty() and Snow.roughness(piste) < old_roughness * 0.11, "Grooming removes tracks and smooths the accumulated bumps")

func _grooming_and_saves() -> void:
	var model = fresh()
	var guest := skiing(model)
	for i in range(12):
		model.advance_minute(false)
	model.pistes[0].condition = 10.0
	model._invalidate()
	var copy := Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok and copy.guests.size() == model.guests.size(), "Full itineraries retain guests already skiing on a newly exhausted piste")
	check(copy.pistes[0].tracks.size() == model.pistes[0].tracks.size() and absf(Snow.roughness(copy.pistes[0]) - Snow.roughness(model.pistes[0])) < 0.00001, "Tracks and snow relief survive a save roundtrip")
	var before: float = copy.money
	var broken: Dictionary = model.snapshot()
	broken.pistes[0].surface[0] = NAN
	check(not copy.restore(broken).ok and copy.money == before, "Invalid snow data cannot overwrite an existing resort")
	broken = model.snapshot()
	broken.map_id = "unknown"
	check(not copy.restore(broken).ok, "Unknown map IDs are rejected")
	check(not model.groom_piste(model.pistes[0].id).ok, "An active grooming service needs research and a garage")
	model.campaign.research.append("snowcraft")
	model.money = 1000000
	model.build_building("maintenance", Vector2(80, 280))
	var id: int = model.pistes[0].id
	var quote: Dictionary = model.groom_check(id)
	before = model.money
	check(model.groom_piste(id).ok and model.money == before - quote.cost and not model.piste_open(model.pistes[0]), "Grooming charges its quote and closes the piste to new routes")
	check(not model.groom_piste(id).ok, "An already running grooming job cannot be charged twice")
	check(copy.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "A grooming job can be saved while it is running")
	for i in range(45):
		model.advance_minute(false)
	check(model.piste_open(model.pistes[0]) and model.pistes[0].condition == 100 and model.pistes[0].tracks.is_empty(), "The finished grooming job reopens a smooth, restored piste")
