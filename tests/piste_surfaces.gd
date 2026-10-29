extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Terrain = preload("res://src/core/terrain.gd")
const Mountain = preload("res://src/core/mountain.gd")
const Planner = preload("res://src/core/route_planner.gd")
var passed := 0
var failed := 0
func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)
func _init() -> void:
	var m := Resort.new()
	m.new_game(false)
	var points := [[0, -200], [0, 100]]
	var narrow := m.preview_piste(points, 14)
	var wide := m.preview_piste(points, 36)
	check(narrow.ok and wide.ok and wide.width == 36, "Narrow and wide routes receive real corridor previews")
	check(absf(float(wide.cost) / narrow.cost - 36.0 / 14) < 0.002, "Construction quotes scale with the chosen actual width")
	var money := m.money
	check(not m.build_piste(points, -1, 13).ok and not m.build_piste(points, -1, 37).ok and not m.build_piste(points, -1, NAN).ok and m.money == money and m.pistes.is_empty(), "Invalid new-build widths never spend money or create a piste")
	check(m.build_piste(points, -1, 36).ok and m.pistes[0].width == 36 and m.Snow.piste_width(m.pistes[0]) == 36, "A new wide piste stores and uses its selected width")
	check(m.money == money - wide.cost and m.pistes[0].grading, "The confirmed width is charged once and enables bounded earthworks")
	var copy := Resort.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(m.snapshot()))).ok and copy.pistes[0].width == 36 and copy.snapshot().version == 13, "Width and earthworks survive a format 13 JSON roundtrip")
	var bad: Dictionary = m.snapshot()
	bad.pistes[0].grading = "yes"
	var before := copy.snapshot()
	check(not copy.restore(bad).ok and copy.snapshot() == before, "Corrupt earthworks flags cannot partially overwrite the current resort")
	bad = m.snapshot()
	bad.pistes[0].points[0] = [1e20, 1e20]
	check(not copy.restore(bad).ok and copy.snapshot() == before, "Huge invalid coordinates are rejected before earthworks are indexed")
	m.campaign.mode = "free"
	check(m.upgrade_asset(m.pistes[0].id).ok and m.upgrade_asset(m.pistes[0].id).ok and m.Snow.piste_width(m.pistes[0]) == 44, "Upgrades retain the chosen base width and validate the complete 44-metre corridor")
	var hill := Mountain.new()
	var route := [[-220, -350], [-220, 50]]
	hill.configure_pistes([{"points": route, "width": 36, "level": 1, "grading": true}])
	var changed := false
	var bounded := true
	var centers := true
	var softened := true
	for y in range(-320, 20, 8):
		var center := Vector2(-220, y)
		centers = centers and absf(hill.height(center) - hill.natural_height(center)) < 0.000001
		for x in [-16, -8, 8, 16]:
			var at := center + Vector2(x, 0)
			var change := hill.height(at) - hill.natural_height(at)
			changed = changed or absf(change) > 0.05
			bounded = bounded and absf(change) <= 1.200001
			softened = softened and absf(hill.height(at) - hill.height(center)) <= absf(hill.natural_height(at) - hill.natural_height(center)) + 0.0001
	check(changed and softened, "Actual cross-slope ground is benched toward the piste center")
	check(bounded, "Cuts and fills remain within 1.2 metres even on a steep flank")
	check(centers, "All centerline elevations and their downhill profiles remain exact")
	check(is_equal_approx(hill.height(Vector2(-220, -348)), hill.natural_height(Vector2(-220, -348))) and is_equal_approx(hill.height(Vector2(-180, -220)), hill.natural_height(Vector2(-180, -220))), "Ends and terrain outside the shoulder retain their original heights")
	hill.configure_pistes([{"points": route, "width": 36, "level": 1, "grading": false}])
	check(is_equal_approx(hill.height(Vector2(-228, -200)), hill.natural_height(Vector2(-228, -200))), "Unmodified legacy pistes retain the original ground")
	var block := Resort.new()
	block.new_game(false)
	block.buildings = [{"id": 1, "kind": "lodge", "point": [29, 0], "enabled": true, "level": 1, "cost": 18500, "name": "Hut", "visits": 0, "revenue": 0}]
	block.next_id = 2
	block._invalidate()
	check(block.preview_piste(points, 14).ok and not block.preview_piste(points, 36).ok, "The full corridor, including its edge, stays clear of building footprints")
	block.buildings[0].kind = "snowmaker"
	block.buildings[0].point = [0, -50]
	block._invalidate()
	check(not block.preview_piste(points, 14).ok, "Snowmaking machinery is also kept outside the piste")
	var bend := [[360, -340], [420, -160], [350, 70]]
	var smooth := Planner.smooth(m, bend, 20)
	check(smooth.ok and smooth.points.size() > bend.size() and smooth.points.size() <= 64, "Bend smoothing creates a bounded, buildable actual route")
	if smooth.ok:
		check(bend.all(func(p): return smooth.points.any(func(q): return Terrain.unpack(p).distance_to(Terrain.unpack(q)) < 0.001)), "Smoothing retains every manually chosen waypoint")
		var spacing := true
		for i in range(1, smooth.points.size()): spacing = spacing and Terrain.unpack(smooth.points[i]).distance_to(Terrain.unpack(smooth.points[i - 1])) >= 3.999
		check(spacing and m.preview_piste(smooth.points, 20).ok, "Generated bends pass the regular spacing and construction checks")
	check(not Planner.smooth(m, [[0, -100], [INF, 0], [0, 100]], 20).ok and not Planner.smooth(m, bend, 100).ok, "Unsafe bend requests are rejected without changing the plan")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v0.11-starter.json"))
	var old := Resort.new()
	check(old.restore(fixture.duplicate(true)).ok and old.guests.size() == 12, "An authentic populated 0.11 resort loads successfully")
	check(old.money == fixture.money and old.minute == fixture.minute and old.guests.map(func(g): return int(g.id)) == fixture.guests.map(func(g): return int(g.id)), "Migration retains money, clock and guest identities")
	check(old.pistes.all(func(p): return not p.grading), "Loading an old save does not silently regrade existing routes")
	var roundtrip := Resort.new()
	check(roundtrip.restore(JSON.parse_string(JSON.stringify(old.snapshot()))).ok, "The migrated populated resort saves and reloads in format 13")
	for i in range(120): old.advance_minute(false); roundtrip.advance_minute(false)
	check(old.snapshot() == roundtrip.snapshot(), "Actual guests continue deterministically after the format 13 reload")
	print("PISTE SURFACES: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)
