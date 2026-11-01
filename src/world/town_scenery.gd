extends RefCounted
## Decorative, non-colliding, real OSM town layer. No fictional road or bus
## timetable is inferred. The imported way shapes and POI identities survive.
const Geo = preload("res://src/core/real_resorts.gd")
const Terrain = preload("res://src/core/terrain.gd")
const MAX_ROAD_QUADS := 22000
const MAX_POI_LABELS := 52
const ROAD_COLORS := [Color("98aab0"), Color("ad9e8f"), Color("c5b9a7")]
const POI_COLORS := {
	"lodging": Color("6a9fb6"),
	"food": Color("e4b26b"),
	"bus_stop": Color("75ac9b"),
	"transit_stop": Color("75ac9b")
}
static var _cache: Dictionary = {}

static func data(id: String) -> Dictionary:
	if id not in Geo.IDS: return {}
	if not _cache.has(id):
		var path := "res://assets/geodata/towns/%s.json" % id
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_cache[id] = parsed if parsed is Dictionary and parsed.get("schema") == 1 and parsed.get("region") == id and parsed.get("source") == "OpenStreetMap" and parsed.get("features") is Array else {}
	return _cache[id]

static func _point(raw: Variant) -> Vector2:
	if not raw is Array or raw.size() != 2: return Vector2.INF
	var point := Vector2(float(raw[0]), float(raw[1]))
	return point if point.is_finite() else Vector2.INF

static func _road_style(tags: Dictionary) -> int:
	var highway: String = str(tags.get("highway", ""))
	if highway in ["primary", "secondary", "tertiary", "residential", "unclassified"]: return 0
	if highway in ["living_street", "service"]: return 1
	if highway in ["pedestrian", "footway", "track", "path"]: return 2
	return -1

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	return material

static func _add_quad(vertices: PackedVector3Array, mountain: RefCounted, first: Vector2, last: Vector2, width: float) -> void:
	var direction := (last - first).normalized()
	if direction.length_squared() < 0.5: return
	var side := direction.orthogonal() * width * 0.5
	var a: Vector3 = mountain.world(first - side, 0.85)
	var b: Vector3 = mountain.world(first + side, 0.85)
	var c: Vector3 = mountain.world(last - side, 0.85)
	var d: Vector3 = mountain.world(last + side, 0.85)
	vertices.append_array(PackedVector3Array([a, b, c, c, b, d]))

static func _make_road_mesh(geometry: PackedVector3Array, color: Color, parent: Node3D, name_value: String) -> void:
	if geometry.is_empty(): return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = geometry
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = name_value
	node.mesh = mesh
	node.material_override = _material(color)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A static decorative overlay, not a walkable/skiable collision surface.
	node.set_meta("osm_town_overlay", true)
	parent.add_child(node)

static func preview_shuttle(id: String) -> Dictionary:
	var town := data(id)
	if town.is_empty(): return {}
	var path := "res://assets/geodata/towns/%s-network.json" % id
	if not FileAccess.file_exists(path): return {}
	var network: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not network is Dictionary or network.get("source_sha256") != town.get("source_sha256"): return {}
	var shuttle: Variant = network.get("game_shuttle_preview", {})
	if not shuttle is Dictionary or shuttle.is_empty() or shuttle.get("official_route", true): return {}
	var outbound: Variant = shuttle.get("outbound", [])
	var returning: Variant = shuttle.get("return", [])
	if not outbound is Array or not returning is Array or outbound.size() < 2 or returning.size() < 2: return {}
	return shuttle

static func _bus_part(parent: Node3D, size: Vector3, offset: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = offset
	part.material_override = _material(color)
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)

static func _bus_node(parent: Node3D, shuttle: Dictionary, mountain: RefCounted) -> Node3D:
	var bus := Node3D.new()
	bus.name = "SkiZonesShuttle"
	bus.set_meta("fictional_service", true)
	var path: Array = shuttle.outbound.duplicate(true)
	for point in shuttle["return"].slice(1):
		path.append(point)
	var length := 0.0
	var previous := _point(path[0])
	for index in range(1, path.size()):
		var current := _point(path[index])
		if current.is_finite() and previous.is_finite(): length += previous.distance_to(current)
		previous = current
	bus.set_meta("route", path)
	bus.set_meta("metres", length)
	bus.set_meta("from_osm", shuttle.from_stop.osm_id)
	bus.set_meta("to_osm", shuttle.to_stop.osm_id)
	_bus_part(bus, Vector3(3.1, 2.7, 7.8), Vector3(0, 2.05, 0), Color("e5b65c"))
	_bus_part(bus, Vector3(3.0, 1.3, 5.2), Vector3(0, 3.2, -0.1), Color("6b98ae"))
	_bus_part(bus, Vector3(3.12, 0.36, 7.85), Vector3(0, 4.05, 0), Color("f7e3a3"))
	for side in [-1.0, 1.0]:
		for end in [-2.45, 2.45]:
			_bus_part(bus, Vector3(0.64, 1.16, 1.2), Vector3(side * 1.6, 0.83, end), Color("334653"))
	var sign := Label3D.new()
	sign.text = "SkiZones-Spielbus"
	sign.font_size = 26
	sign.pixel_size = 0.12
	sign.modulate = Color("365462")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 5.3, 0)
	sign.visibility_range_end = 350
	bus.add_child(sign)
	parent.add_child(bus)
	position_shuttle(bus, mountain, 0.0)
	return bus

static func position_shuttle(bus: Node3D, mountain: RefCounted, virtual_minute: float) -> void:
	if not is_instance_valid(bus): return
	var raw: Variant = bus.get_meta("route", [])
	var length: float = float(bus.get_meta("metres", 0.0))
	if not raw is Array or raw.size() < 2 or length < 1: return
	# A fictional visual shuttle, synchronized to simulation time (not wall
	# time). ≈15 km/h on winter roads with a short turnaround pause.
	var travelled: float = clampf((fposmod(virtual_minute, length / 250.0 + 0.6) - 0.3) * 250.0, 0.0, length)
	for index in range(1, raw.size()):
		var a := _point(raw[index - 1])
		var b := _point(raw[index])
		var segment := a.distance_to(b)
		if segment < 0.1: continue
		if travelled <= segment or index == raw.size() - 1:
			var current := a.lerp(b, clampf(travelled / segment, 0.0, 1.0))
			bus.position = mountain.world(current, 0.35)
			var tangent := (b - a).normalized()
			bus.rotation.y = atan2(tangent.x, tangent.y)
			return
		travelled -= segment

static func build(parent: Node3D, mountain: RefCounted, id: String) -> Dictionary:
	var result := {"roads": 0, "road_quads": 0, "poi": 0, "labels": 0, "stops": 0, "osm": false, "shuttle_preview": false, "shuttle": null}
	var town := data(id)
	if town.is_empty(): return result
	var layer := Node3D.new()
	layer.name = "OSMTown_%s" % id
	parent.add_child(layer)
	var roads := [PackedVector3Array(), PackedVector3Array(), PackedVector3Array()]
	var marker_points := {"lodging": [], "food": [], "bus_stop": [], "transit_stop": []}
	var labels: Array = []
	var quads := 0
	for feature in town.features:
		if not feature is Dictionary: continue
		var kind: String = str(feature.get("kind", ""))
		var pts: Array = feature.get("points", [])
		var tags: Dictionary = feature.get("tags", {})
		if kind == "road":
			var style := _road_style(tags)
			if style < 0 or pts.size() < 2: continue
			var width: float = [7.2, 4.8, 2.6][style]
			var wrote := false
			for index in range(1, pts.size()):
				var a := _point(pts[index - 1])
				var b := _point(pts[index])
				if not a.is_finite() or not b.is_finite() or not mountain.contains(a) or not mountain.contains(b): continue
				var length := a.distance_to(b)
				if length < 0.2 or length > 6000: continue
				# Steep terrain crosses must be tessellated; no buried streets.
				var steps := mini(ceili(length / 22.0), 120)
				if quads + steps > MAX_ROAD_QUADS: break
				for step in range(steps):
					_add_quad(roads[style], mountain, a.lerp(b, float(step) / steps), a.lerp(b, float(step + 1) / steps), width)
				quads += steps
				wrote = true
			if wrote: result.roads += 1
		elif marker_points.has(kind) and not pts.is_empty():
			var point := _point(pts[0])
			if not point.is_finite() or not mountain.contains(point): continue
			marker_points[kind].append(point)
			if kind in ["bus_stop", "transit_stop"]: result.stops += 1
			var label_name := str(tags.get("name", ""))
			if not label_name.is_empty():
				labels.append({"point": point, "name": label_name, "kind": kind, "osm_id": feature.get("osm_id", -1)})
	result.road_quads = quads
	for style in range(3):
		_make_road_mesh(roads[style], ROAD_COLORS[style], layer, ["Roads", "Service roads", "Walk and hiking paths"][style])
	for kind in marker_points:
		var positions: Array = marker_points[kind]
		if positions.is_empty(): continue
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.5 if kind in ["bus_stop", "transit_stop"] else 3.0
		mesh.bottom_radius = 1.5 if kind in ["bus_stop", "transit_stop"] else 3.0
		mesh.height = 4.0 if kind in ["bus_stop", "transit_stop"] else 6.0
		mesh.radial_segments = 6
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = positions.size()
		var index := 0
		for point in positions:
			multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, mountain.world(point, 3.6)))
			index += 1
		var node := MultiMeshInstance3D.new()
		node.name = "OSM " + kind
		node.multimesh = multi
		node.material_override = _material(POI_COLORS[kind])
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.set_meta("osm_town_overlay", true)
		layer.add_child(node)
		result.poi += positions.size()
	# Only a bounded set of named, close-to-entry real sites is labelled.
	# Unnamed entries are represented solely by coloured geometry.
	labels.sort_custom(func(a, b): return a.point.distance_squared_to(Terrain.BASE) < b.point.distance_squared_to(Terrain.BASE))
	var accepted: Array = []
	for record in labels:
		if accepted.size() >= MAX_POI_LABELS: break
		if accepted.any(func(p): return p.distance_to(record.point) < 28): continue
		var label := Label3D.new()
		label.text = str(record.name).substr(0, 42)
		label.font_size = 27
		label.pixel_size = 0.12
		label.modulate = POI_COLORS[record.kind]
		label.outline_modulate = Color("edf3f4")
		label.outline_size = 8
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.visibility_range_end = 650
		label.position = mountain.world(record.point, 12.0)
		label.set_meta("osm_id", record.osm_id)
		label.set_meta("osm_town_overlay", true)
		layer.add_child(label)
		accepted.append(record.point)
	result.labels = accepted.size()
	result.osm = true
	var shuttle := preview_shuttle(id)
	if not shuttle.is_empty():
		result.shuttle = _bus_node(layer, shuttle, mountain)
		result.shuttle_preview = true
	layer.set_meta("source", "© OpenStreetMap contributors · ODbL 1.0")
	layer.set_meta("counts", result)
	return result
