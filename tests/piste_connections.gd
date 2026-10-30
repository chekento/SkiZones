extends SceneTree
const Resort = preload("res://src/core/resort.gd")
const Terrain = preload("res://src/core/terrain.gd")
const SnowRender = preload("res://src/world/snow_render.gd")
const PisteMesh = preload("res://src/world/piste_mesh.gd")
const Picker = preload("res://src/world/surface_picker.gd")
var passed := 0
var failed := 0

class GentleMountain extends "res://src/core/mountain.gd":
	func height(point: Vector2) -> float: return 300 - point.y * 0.2

func check(value: bool, title: String) -> void:
	if value: passed += 1; print("PASS ", title)
	else: failed += 1; push_error("FAIL " + title)

func area(polygon: PackedVector2Array) -> float:
	var sum := 0.0
	for index in range(polygon.size()): sum += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return absf(sum) * 0.5

func run() -> void:
	var model := Resort.new()
	model.new_game(false)
	model.money = 2000000
	check(model.build_lift("chair", Vector2(200, 235), Vector2(200, -230)).ok and model.build_piste([[200, -200], [200, 200]]).ok, "An operating main run has no pre-existing intermediate vertices")
	var main: Dictionary = model.pistes[0]
	var snap := model.snap_anchor(Vector2(203, -125))
	check(not snap.is_empty() and snap.point == Vector2(200, -125) and snap.waypoint == -1, "Docking projects onto the middle of a segment rather than a distant waypoint")
	var branch := [[200, -125], [260, -20], [200, 100]]
	var before: Array = main.points.duplicate(true)
	var money: float = model.money
	var revision: int = model.revision
	var quote := model.preview_piste(branch, 20, false)
	check(quote.ok and quote.connections.entry and quote.connections.exit, "A branch preview recognises both segment-interior connections")
	check(main.points == before and model.money == money and model.revision == revision, "Junction previews leave all existing geometry and funds untouched")
	var length: float = main.length
	check(model.build_piste(branch, -1, 20, false).ok and main.points.size() == 4, "Confirmation creates both shared junction vertices on the old run")
	check(main.length == length and model.money == money - quote.cost and model.PisteLinks.profile_points(main.points) == before, "Topology cuts preserve the physical line and do not charge for the neighbour")
	var routes := model.routes_for(2)
	var route: Dictionary = {}
	for item in routes:
		if item.target == model.pistes[1].id: route = item
	var ids: Array = []
	for leg in route.get("legs", []):
		if leg.kind == "ski": ids.append(leg.id)
	check(ids == [main.id, model.pistes[1].id, main.id], "Guests ski the main approach, the new branch and the lower main run")
	var restored := Resort.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "A saved segment junction restores through the ordinary JSON validator")
	model.admit_guest(2)
	var point_index := -1
	for index in range(main.points.size()):
		if Terrain.unpack(main.points[index]).distance_to(Terrain.unpack(branch[0])) < 0.02: point_index = index
	var edited: Array = main.points.duplicate(true)
	edited[point_index] = [210, -120]
	var edit := model.preview_change(main.id, edited, 0, 20, false)
	check(edit.ok and edit.neighbors.has(model.pistes[1].id), "Dragging a shared junction previews its connected neighbour atomically")
	check(model.change_asset(main.id, edited, main.name, "", 0, 20, false).ok and model.pistes[1].points[0] == [210, -120], "Moving a shared point moves the attached branch with it")
	check(not model.guests.is_empty() and Resort.new().restore(JSON.parse_string(JSON.stringify(model.snapshot()))).ok, "Moved junctions and their actual guests survive a populated JSON save")
	var station: Array = [[200, -230], [260, -100], [200, 200]]
	var exact := model.preview_piste(station, 20, false)
	check(exact.points == station and not exact.ok, "Strict editor previews reject station collisions without moving the clicked point")
	var full := Resort.new()
	full.new_game(false)
	full.money = 2000000
	var dense: Array = []
	for i in range(64): dense.append([340 + sin(i) * 3, -200 + i * 400.0 / 63])
	full.build_piste(dense)
	var original: Dictionary = full.snapshot().duplicate(true)
	var midpoint := Terrain.unpack(dense[0]).lerp(Terrain.unpack(dense[1]), 0.5)
	var overflow := full.build_piste([Terrain.pack(midpoint), [380, -20], [340, 190]], -1, 20, false)
	check(not overflow.ok and full.snapshot() == original, "An exhausted junction-vertex limit rejects construction atomically before charging")
	_mesh_junctions()
	print("SURFACES: %d passed; %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _mesh_junctions() -> void:
	var mountain := GentleMountain.new()
	var pistes: Array = [
		{"id": 1, "points": [[0, -160], [0, 160]], "length": 326.34, "width": 24, "level": 1},
		{"id": 2, "points": [[-90, -130], [0, -40], [85, 50]], "length": 256.8, "width": 20, "level": 1},
		{"id": 3, "points": [[70, -140], [0, 60]], "length": 214.5, "width": 18, "level": 1}
	]
	var renderer := SnowRender.new()
	renderer.configure(pistes)
	var total := 0.0
	var picker := Picker.new()
	var seam_ok := true
	var seam_vertices := 0
	for piste in pistes:
		renderer.update(piste)
		for index in range(piste.surface.size()): piste.surface[index] = 0.4 if piste.id == 1 else -0.3
		piste.surface_revision = 1
		var mesh := renderer.build(mountain, piste)
		var faces := mesh.get_faces()
		for index in range(0, faces.size(), 3):
			var a := Vector2(faces[index].x, faces[index].z)
			var b := Vector2(faces[index + 1].x, faces[index + 1].z)
			var c := Vector2(faces[index + 2].x, faces[index + 2].z)
			total += absf((b - a).cross(c - a)) * 0.5
		for index in range(faces.size()):
			if renderer.pick_weights[piste.id][index] > 0.00001: continue
			seam_vertices += 1
			var p := Vector2(faces[index].x, faces[index].z)
			seam_ok = seam_ok and absf(faces[index].y - mountain.height(p) - 0.65) < 0.0001
		picker.add_mesh(str(piste.id), mesh, piste, renderer.pick_frames[piste.id], renderer.pick_weights[piste.id])
	var union: Array = PisteMesh.outlines(pistes[0].points, pistes[0].width)
	for piste in pistes.slice(1):
		for polygon in PisteMesh.outlines(piste.points, piste.width): union = Geometry2D.merge_polygons(union[0], polygon)
	var expected := 0.0
	for polygon in union: expected += area(polygon) * (-1 if Geometry2D.is_polygon_clockwise(polygon) else 1)
	check(absf(total - expected) / expected < 0.0001, "Three crossing snow meshes cover exactly their union without overlapping triangles or gaps")
	check(seam_ok and seam_vertices > 20, "Junction vertices share one height despite different snow histories and piste widths")
	var hit := picker.position(Vector2(0, -40))
	check(hit.is_finite() and absf(hit.y - mountain.height(Vector2(0, -40)) - 0.65) < 0.001, "Visible-surface picking applies the same junction deformation weights as the GPU")
	check(renderer.junction_weight(1, Vector2(0, 145)) > 0.999, "Local snow deformation remains active away from junctions")

func _init() -> void: call_deferred("run")
