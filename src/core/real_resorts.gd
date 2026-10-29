extends RefCounted
## Offline WGS84-derived geometry and an independent elevation raster.
const Terrain = preload("res://src/core/terrain.gd")
const Catalog = preload("res://src/core/catalog.gd")
const Foot = preload("res://src/core/foot_network.gd")
const L = preload("res://src/core/i18n.gd")
const IDS := ["braunlage", "filzmoos", "kitzbuehel", "seiseralm"]
static var _cache: Dictionary = {}
static var _rasters: Dictionary = {}
static var _seeds: Dictionary = {}

static func baked(id: String) -> Dictionary:
	if not _seeds.has(id):
		var path := "res://assets/geodata/%s-seed.json" % id
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_seeds[id] = value if value is Dictionary and value.get("revision") == 1 and value.get("source_sha256") == data(id).source_sha256 else {}
	return _seeds[id]

static func cached_piste(item: Dictionary, id: String) -> Dictionary:
	if id not in IDS or not item.get("imported", false) or not Terrain.number(item.get("osm_id")) or not Terrain.number(item.get("id")): return {}
	for original in baked(id).get("pistes", []):
		if int(original.id) == int(item.get("id", -1)) and int(original.osm_id) == int(item.get("osm_id", -1)) and original.points == item.get("points") and original.get("source_points") == item.get("source_points"):
			return original
	return {}

static func cached_analysis(item: Dictionary, id: String) -> Dictionary:
	var original := cached_piste(item, id)
	if original.is_empty(): return {}
	var value := {"ok": original.enabled}
	for key in ["length", "horizontal", "drop", "average", "grade", "difficulty", "cost"]: value[key] = original[key]
	return value

static func data(id: String) -> Dictionary:
	if not _cache.has(id):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/geodata/%s.json" % id))
		_cache[id] = value if value is Dictionary else {}
	return _cache[id]

static func height(point: Vector2, id: String) -> float:
	if not _rasters.has(id):
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/geodata/%s-heights.json" % id))
		meta.values = FileAccess.get_file_as_bytes("res://assets/geodata/%s-heights.bin" % id).to_float32_array()
		_rasters[id] = meta
	var raster: Dictionary = _rasters[id]
	var x := clampf((point.x - raster.left) / raster.step, 0, raster.width - 1.001)
	var y := clampf((point.y - raster.top) / raster.step, 0, raster.depth - 1.001)
	var col := floori(x)
	var row := floori(y)
	var index: int = row * int(raster.width) + col
	return lerpf(lerpf(raster.values[index], raster.values[index + 1], x - col), lerpf(raster.values[index + int(raster.width)], raster.values[index + int(raster.width) + 1], x - col), y - row)

static func map_spec(id: String) -> Dictionary:
	var geo := data(id)
	var bounds: Array = geo.bounds
	return {"name": geo.name, "bounds": Rect2(bounds[0], bounds[1], bounds[2], bounds[3]), "subtitle": ["Der erste Winter", "Winterbetrieb unter Druck", "Die große Verbindung", "Das alpine Meisterstück"][IDS.find(id)], "description": "Reale Landschaft, Lifte und Pisten aus offenen Geodaten. Die betrieblichen Probleme sind erfundene Spielszenarien.", "color": ["70bba6", "7da7bd", "b19cce", "d5ac80"][IDS.find(id)], "rank": 1, "guests": 0, "contracts": 0, "forest": 0.8, "snow": 1.0, "budget": [850000, 1250000, 4500000, 3000000][IDS.find(id)], "start": "Szenario mit 24-Stunden-Betrieb", "sky": "cedee8", "ground": "eef3fc", "trees": "6e9092", "peaks": [], "valleys": [], "real": true, "tree_line": [1100, 1950, 2050, 2100][IDS.find(id)]}

static func _kind(tags: Dictionary) -> String:
	var family: String = tags.get("aerialway", "")
	if family in ["gondola", "cable_car", "mixed_lift"]: return "gondola"
	if family == "magic_carpet": return "carpet"
	if family in ["drag_lift", "t-bar", "j-bar", "platter", "rope_tow"]: return "drag"
	var seats := int(str(tags.get("aerialway:occupancy", "4")).to_int())
	return "chair8" if seats >= 8 else "chair6" if seats >= 6 else "chair" if seats >= 4 else "chair2" if seats >= 2 else "chair1"

static func seed(model: RefCounted) -> void:
	var prepared := baked(model.map_id) if not OS.get_cmdline_user_args().has("--fresh-geodata") else {}
	if not prepared.is_empty():
		model.lifts = prepared.lifts.duplicate(true)
		model.pistes = prepared.pistes.duplicate(true)
		model.buildings = prepared.buildings.duplicate(true)
		model.next_id = int(prepared.next_id)
		for collection in [model.lifts, model.pistes, model.buildings]:
			for item in collection:
				for key in ["id", "number", "level", "difficulty", "section", "sections", "boarded", "last_load", "rotation"]:
					if item.has(key): item[key] = int(item[key])
		model.campaign.mode = "career"
		model._reset_report()
		model._invalidate()
		return
	var geo := data(model.map_id)
	var stations: Dictionary = {}
	for feature in geo.features:
		if feature.osm_type == "node" and feature.tags.get("aerialway") == "station": stations[int(feature.osm_id)] = true
	for feature in geo.features:
		var tags: Dictionary = feature.tags
		if feature.osm_type != "way" or not tags.has("aerialway") or tags.aerialway not in ["gondola", "cable_car", "chair_lift", "mixed_lift", "drag_lift", "t-bar", "j-bar", "platter", "rope_tow", "magic_carpet"]: continue
		var cuts: Array = [0]
		for i in range(1, feature.points.size() - 1):
			if i < feature.nodes.size() and stations.has(int(feature.nodes[i])): cuts.append(i)
		cuts.append(feature.points.size() - 1)
		for section in range(cuts.size() - 1):
			var a := Terrain.unpack(feature.points[cuts[section]])
			var b := Terrain.unpack(feature.points[cuts[section + 1]])
			if not model.terrain.contains(a) or not model.terrain.contains(b) or a.distance_to(b) < 25: continue
			if model.terrain.height(a) > model.terrain.height(b):
				var swap := a
				a = b
				b = swap
			var kind := _kind(tags)
			var spec: Dictionary = Catalog.LIFTS[kind]
			var profile: Dictionary = model._lift_profile(kind, a, b)
			var title: String = tags.get("name", tags.get("ref", spec.name))
			model.lifts.append({"id": model.next_id, "kind": kind, "bottom": Terrain.pack(a), "top": Terrain.pack(b), "length": profile.length, "cost": roundi(spec.cost + profile.length * spec.per_m), "enabled": true, "credit": 0.0, "clock": 0.0, "boarded": 0, "last_load": 0, "recent_departures": [], "level": 1, "upgrade_total": 0.0, "name": title, "custom_name": true, "imported": true, "osm_id": feature.osm_id, "line": str(feature.osm_id), "section": section, "sections": cuts.size() - 1, "occupancy": clampi(str(tags.get("aerialway:occupancy", str(spec.seats))).to_int(), 1, 64)})
			var capacity := str(tags.get("aerialway:capacity", "0")).to_int()
			if capacity >= 50 and capacity <= 10000: model.lifts[-1].source_capacity = capacity
			model.next_id += 1
	# Preserve exact shared OSM nodes. Long ways are split at existing nodes,
	# never reshaped to a fantasy resort's training valley.
	for feature in geo.features:
		var tags: Dictionary = feature.tags
		if feature.osm_type != "way" or tags.get("piste:type") != "downhill" or tags.get("area") == "yes" or feature.points[0] == feature.points[-1]: continue
		var points: Array = feature.points.duplicate(true)
		if points.any(func(p): return not model.terrain.contains(Terrain.unpack(p))): continue
		if model.terrain.height(Terrain.unpack(points[0])) < model.terrain.height(Terrain.unpack(points[-1])): points.reverse()
		var offset := 0
		while offset < points.size() - 1:
			var part := points.slice(offset, mini(points.size(), offset + 64))
			offset += part.size() - 1
			var docked := Foot.prepare_piste(part, model.lifts)
			var analysis: Dictionary = model.terrain.analyse(docked, -1, true)
			if analysis.length < 10: continue
			var number: int = model.pistes.size() + 1
			var name_value: String = tags.get("name", tags.get("piste:name", tags.get("ref", "OSM %d" % int(feature.osm_id))))
			var difficulty: int = source_difficulty(tags.get("piste:difficulty", "unknown"), int(analysis.difficulty))
			model.pistes.append({"id": model.next_id, "number": number, "name": name_value, "custom_name": true, "points": docked, "source_points": part, "difficulty": difficulty, "length": analysis.length, "horizontal": analysis.horizontal, "drop": analysis.drop, "average": analysis.average, "grade": analysis.grade, "cost": analysis.get("cost", 0), "condition": 78.0, "snow": 50.0, "enabled": analysis.ok, "rides": 0, "level": 1, "upgrade_total": 0.0, "width": 20.0, "grading": false, "imported": true, "osm_id": feature.osm_id, "osm_difficulty": tags.get("piste:difficulty", "unknown")})
			model.next_id += 1
	model._invalidate()
	# The existing access coordinate is the WGS84 origin of this map. Place
	# starter services beside it, checking the real ground and existing assets.
	var used_lots: Array = []
	for kind in ["rental", "restaurant", "hotel"]:
		var found := false
		for ring in range(1, 9):
			if found: break
			for angle in range(20):
				var at := Terrain.BASE + Vector2(cos(angle * TAU / 20), sin(angle * TAU / 20)) * (30 + ring * 22)
				if not model.terrain.contains(at) or model.terrain.slope_percent(at) > 40: continue
				if used_lots.any(func(p): return at.distance_to(p) < 45): continue
				var blocked := false
				for lift in model.lifts:
					if at.distance_to(Terrain.unpack(lift.bottom)) < 60 or at.distance_to(Terrain.unpack(lift.top)) < 60: blocked = true
				for piste in model.pistes:
					for i in range(1, piste.points.size()):
						if Geometry2D.get_closest_point_to_segment(at, Terrain.unpack(piste.points[i-1]), Terrain.unpack(piste.points[i])).distance_to(at) < 30: blocked = true
				if blocked: continue
				used_lots.append(at)
				model.buildings.append({"id": model.next_id, "kind": kind, "point": Terrain.pack(at), "cost": Catalog.BUILDINGS[kind].cost, "enabled": true, "level": 1, "upgrade_total": 0.0, "name": Catalog.BUILDINGS[kind].name, "visits": 0, "revenue": 0.0, "rotation": 0})
				model.next_id += 1
				found = true
				break
	model.campaign.mode = "career"
	model.money = float(map_spec(model.map_id).budget)
	model._reset_report()
	model._invalidate()

static func exact_import(item: Dictionary, id: String, piste: bool) -> bool:
	if id not in IDS or not item.get("imported", false) or not Terrain.number(item.get("osm_id")): return false
	if piste and not cached_piste(item, id).is_empty(): return true
	for feature in data(id).features:
		if feature.osm_type != "way" or int(feature.osm_id) != int(item.get("osm_id", -1)): continue
		if piste:
			if feature.tags.get("piste:type") != "downhill": return false
			var source: Variant = item.get("source_points", item.points)
			if not source is Array: return false
			var original: Array = source
			for point in original:
				if not Terrain.unpack(point).is_finite(): return false
			if original.size() < 2 or original.size() > 64: return false
			var contiguous := false
			for first in range(feature.points.size()):
				if Terrain.unpack(feature.points[first]).distance_to(Terrain.unpack(original[0])) > 0.02: continue
				for direction in [-1, 1]:
					var valid := true
					for i in range(original.size()):
						var index: int = first + i * direction
						if index < 0 or index >= feature.points.size() or Terrain.unpack(feature.points[index]).distance_to(Terrain.unpack(original[i])) > 0.02:
							valid = false
							break
					contiguous = contiguous or valid
			if not contiguous: return false
			for point in item.points:
				var distance := INF
				for i in range(1, original.size()):
					distance = minf(distance, Geometry2D.get_closest_point_to_segment(Terrain.unpack(point), Terrain.unpack(original[i-1]), Terrain.unpack(original[i])).distance_to(Terrain.unpack(point)))
				if distance > 25: return false
			return true
		return feature.points.any(func(p): return Terrain.unpack(p).distance_to(Terrain.unpack(item.bottom)) < 0.01) and feature.points.any(func(p): return Terrain.unpack(p).distance_to(Terrain.unpack(item.top)) < 0.01) and _kind(feature.tags) == item.kind
	return false

static func source_difficulty(value: String, fallback: int) -> int:
	if value in ["novice", "easy"]: return 0
	if value == "intermediate": return 1
	if value in ["advanced", "expert", "freeride", "extreme"]: return 2
	return fallback
