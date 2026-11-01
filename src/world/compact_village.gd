extends RefCounted
## Compact ski-village dressing, not a reconstruction of whole municipalities.
## Real hospitality sites retain OSM coordinates/IDs but use fictional names.
## Schools/snack/after-ski scenery are openly marked as gameplay additions.
const Geo = preload("res://src/core/real_resorts.gd")
const Terrain = preload("res://src/core/terrain.gd")
const MAX_HOTELS := 7
const MAX_FOOD := 7
const MAX_SLOPE_VENUES := 6
const VILLAGE_RADIUS := 1350.0
const SLOPE_VENUE_DISTANCE := 115.0
const GENERIC_VENUES := [
	{"kind":"school", "point": Vector2(135, 268)},
	{"kind":"kiosk", "point": Vector2(231, 272)},
	{"kind":"disco", "point": Vector2(123, 341)}
]
const FACADE := {
	"lodging": Color("e2bba0"), "food": Color("ca8365"),
	"school": Color("79b6b5"), "kiosk": Color("d9aa67"),
	"disco": Color("b68db8")
}
const ROOFS := {
	"lodging": Color("71515f"), "food": Color("6f4b46"),
	"school": Color("457780"), "kiosk": Color("956044"),
	"disco": Color("655578")
}

static func _point(raw: Variant) -> Vector2:
	if not raw is Array or raw.size() != 2: return Vector2.INF
	var at := Vector2(float(raw[0]), float(raw[1]))
	return at if at.is_finite() else Vector2.INF

static func _centroid(points: Array) -> Vector2:
	if points.is_empty(): return Vector2.INF
	var value := Vector2.ZERO
	var count := 0
	for raw in points:
		var at := _point(raw)
		if at.is_finite():
			value += at
			count += 1
	return value / float(count) if count > 0 else Vector2.INF

static func _piste_segments(id: String) -> Array:
	var segments: Array = []
	for feature in Geo.data(id).get("features", []):
		var tags: Dictionary = feature.get("tags", {})
		if tags.get("piste:type") != "downhill": continue
		var points: Array = feature.get("points", [])
		for index in range(1, points.size()):
			var a := _point(points[index - 1])
			var b := _point(points[index])
			if a.is_finite() and b.is_finite() and a.distance_to(b) > 0.1:
				segments.append([a, b])
	return segments

static func _near_piste(point: Vector2, segments: Array) -> bool:
	for segment in segments:
		if Geometry2D.get_closest_point_to_segment(point, segment[0], segment[1]).distance_to(point) <= SLOPE_VENUE_DISTANCE:
			return true
	return false

static func _distinct(entries: Array, at: Vector2, distance: float) -> bool:
	for entry in entries:
		if at.distance_to(entry.point) < distance: return false
	return true

static func _archived_mountainside(id: String, town: Dictionary) -> Array:
	# A generated, exact-source OSM subset, with explicitly partial coverage
	# when Overpass is unavailable. Never infer sites or reuse original names.
	var path := "res://assets/geodata/mountain-venues/%s.json" % id
	if not FileAccess.file_exists(path): return []
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not doc is Dictionary or doc.get("region") != id or doc.get("source") != "OpenStreetMap":
		return []
	if doc.get("license") != "ODbL-1.0" or not doc.get("features") is Array:
		return []
	if doc.get("coverage") == "partial_town_extract" and doc.get("source_sha256") != town.get("source_sha256"):
		return []
	var selected: Array = []
	for entry in doc.features:
		if not entry is Dictionary or entry.get("kind") not in ["food", "lodging"]:
			continue
		if int(entry.get("osm_id", 0)) <= 0: continue
		var metres: float = minf(float(entry.get("piste_metres", 100000) if entry.get("piste_metres") != null else 100000), float(entry.get("station_metres", 100000) if entry.get("station_metres") != null else 100000))
		if metres > float(doc.get("max_distance_metres", 165.0)): continue
		var at := _point(entry.get("point", []))
		if not at.is_finite(): continue
		selected.append({"kind": str(entry.kind), "point": at, "source": "osm",
			"osm_id": int(entry.osm_id), "osm_type": str(entry.get("osm_type", "")),
			"distance": metres})
	selected.sort_custom(func(a, b): return a.distance < b.distance if not is_equal_approx(a.distance, b.distance) else a.osm_id < b.osm_id)
	return selected

static func sites(id: String, mountain: RefCounted, town: Dictionary) -> Dictionary:
	var result := {"hotels": [], "food": [], "slope_food": [], "game": []}
	if id not in Geo.IDS or town.is_empty(): return result
	var candidates: Array = []
	for feature in town.get("features", []):
		if not feature is Dictionary: continue
		var kind: String = str(feature.get("kind", ""))
		if kind not in ["lodging", "food"]: continue
		var at := _centroid(feature.get("points", []))
		if not at.is_finite() or not mountain.contains(at): continue
		if mountain.slope_percent(at) > 55: continue
		candidates.append({"kind":kind, "point":at, "osm_id":int(feature.get("osm_id", 0)),
			"osm_type":str(feature.get("osm_type", "")), "source":"osm"})
	candidates.sort_custom(func(a, b): return a.point.distance_squared_to(Terrain.BASE) < b.point.distance_squared_to(Terrain.BASE) if not is_equal_approx(a.point.distance_squared_to(Terrain.BASE), b.point.distance_squared_to(Terrain.BASE)) else a.osm_id < b.osm_id)
	var occupied: Array = []
	for candidate in candidates:
		if candidate.point.distance_to(Terrain.BASE) > VILLAGE_RADIUS: continue
		var family: String = "hotels" if candidate.kind == "lodging" else "food"
		var capacity: int = MAX_HOTELS if family == "hotels" else MAX_FOOD
		if result[family].size() >= capacity or not _distinct(occupied, candidate.point, 47.0): continue
		result[family].append(candidate)
		occupied.append(candidate)
	# Prefer independently verified OSM hospitality near *real runs* and
	# lift stations; old towns-only snapshots remain a safe offline fallback.
	var segments: Array = _piste_segments(id)
	var mountain_sites: Array = _archived_mountainside(id, town)
	for candidate in mountain_sites:
		if result.slope_food.size() >= MAX_SLOPE_VENUES: break
		if candidate.point.distance_to(Terrain.BASE) < 360.0: continue
		if not mountain.contains(candidate.point) or mountain.slope_percent(candidate.point) > 55: continue
		if not _distinct(occupied, candidate.point, 65.0): continue
		result.slope_food.append(candidate)
		occupied.append(candidate)
	if mountain_sites.is_empty():
		for candidate in candidates:
			if candidate.kind != "food" or result.slope_food.size() >= MAX_SLOPE_VENUES: continue
			if candidate.point.distance_to(Terrain.BASE) < 360.0: continue
			if not _distinct(occupied, candidate.point, 65.0): continue
			if not _near_piste(candidate.point, segments): continue
			result.slope_food.append(candidate)
			occupied.append(candidate)
	# These fictional types fill the *small village centre*, never assert
	# real-world POI coordinates or copied restaurant names.
	for spec in GENERIC_VENUES:
		var at: Vector2 = spec.point
		if not mountain.contains(at): continue
		if not _distinct(occupied, at, 24.0):
			at += Vector2(29, 41)
		if not mountain.contains(at): continue
		var site := {"kind":spec.kind, "point":at, "source":"game", "osm_id":0, "osm_type":""}
		result.game.append(site)
		occupied.append(site)
	return result

static func _part(root: Node3D, size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = StandardMaterial3D.new()
	node.material_override.albedo_color = color
	node.material_override.roughness = 0.95
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = offset
	root.add_child(node)
	return node

static func _building(parent: Node3D, mountain: RefCounted, site: Dictionary) -> Node3D:
	var kind: String = str(site.kind)
	var hotel := kind == "lodging"
	var snack := kind == "kiosk"
	var dims := Vector3(20, 10, 14) if hotel else Vector3(9, 5, 8) if snack else Vector3(15, 7, 12)
	var node := Node3D.new()
	node.name = "SkiOrt_%s_%d" % [kind, int(site.get("osm_id", 0))]
	node.position = mountain.world(site.point, 0.5)
	node.set_meta("village_venue", kind)
	node.set_meta("source", site.source)
	node.set_meta("source_osm", int(site.get("osm_id", 0)))
	node.set_meta("source_osm_type", site.get("osm_type", ""))
	_part(node, dims, Vector3(0, dims.y * 0.5, 0), FACADE.get(kind, Color("d4ad93")))
	# Stylized alpine sloping roof: two thick tiles angled at the ridge.
	for sign_value in [-1.0, 1.0]:
		var roof := _part(node, Vector3(dims.x * 0.58 + 1.2, 0.9, dims.z + 2.0),
			Vector3(sign_value * dims.x * 0.245, dims.y + dims.x * 0.12, 0),
			ROOFS.get(kind, Color("684e53")))
		roof.rotation.z = sign_value * 0.37
	var door := _part(node, Vector3(2.0, 3.0, 0.38), Vector3(0, 1.5, dims.z * 0.5 + 0.2), Color("493e3b"))
	door.set_meta("game_decor", true)
	for side in [-1.0, 1.0]:
		_part(node, Vector3(2.2, 1.4, 0.18), Vector3(side * dims.x * 0.26, dims.y * 0.60, dims.z * 0.5 + 0.17), Color("a5d3dc"))
	if kind == "disco":
		_part(node, Vector3(dims.x * 0.8, 0.45, 1.0), Vector3(0, dims.y * 0.78, dims.z * 0.5 + 0.7), Color("c476d0"))
	if kind == "school":
		_part(node, Vector3(0.5, 5, 0.5), Vector3(-dims.x * 0.6, 2.5, 0), Color("5ba6ba"))
		_part(node, Vector3(4.0, 0.8, 1.0), Vector3(-dims.x * 0.6, 5.0, 0), Color("e4b358"))
	parent.add_child(node)
	return node

static func build(parent: Node3D, mountain: RefCounted, id: String, town: Dictionary, resort: RefCounted = null) -> Dictionary:
	var plan := sites(id, mountain, town)
	var result := {"village_models": 0, "slope_venues": 0, "game_added": 0, "lodging": 0}
	for kind in ["hotels", "food", "slope_food", "game"]:
		for entry in plan[kind]:
			if kind == "game" and resort != null and resort.buildings.any(func(b): return b.kind == entry.kind):
				# The player-owned, staffable venue already has its own world mesh.
				continue
			_building(parent, mountain, entry)
			result.village_models += 1
			if kind == "slope_food": result.slope_venues += 1
			if kind == "game": result.game_added += 1
			if kind == "hotels": result.lodging += 1
	return result
