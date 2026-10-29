extends RefCounted
const L = preload("res://src/core/i18n.gd")
## Validate the entire proposed change before charging or touching live assets.
const Terrain = preload("res://src/core/terrain.gd")
const Snow = preload("res://src/core/snow_surface.gd")
const Foot = preload("res://src/core/foot_network.gd")

static func valid_color(value: Variant) -> bool:
	if not value is String: return false
	if value == "": return true
	if value.length() != 6: return false
	for character in value.to_lower():
		if not character in "0123456789abcdef": return false
	return true

static func context(model: RefCounted, id: int) -> RefCounted:
	if model._edit_context.has(id): return model._edit_context[id]
	var candidate: RefCounted = model.get_script().new()
	candidate.map_id = model.map_id
	candidate.terrain_generation = model.terrain_generation
	candidate.legacy_foot = model.legacy_foot
	candidate.terrain = model.terrain
	candidate.money = model.money
	candidate.campaign = model.campaign
	for key in ["pistes", "lifts", "buildings", "walk_areas"]:
		var items: Array = []
		for item in model.get(key):
			if int(item.id) != id: items.append(item.duplicate())
		candidate.set(key, items)
	model._edit_context[id] = candidate
	return candidate

static func preview(model: RefCounted, id: int, points: Array, rotation_value: int = 0, width: float = 20) -> Dictionary:
	var item: Dictionary = model.asset(id)
	var invalid := {"ok": false, "message": L.text("Diese Änderung ist hier nicht möglich."), "cost": 0}
	if item.is_empty() or rotation_value < 0 or rotation_value > 3 or not is_finite(width) or width < 14 or width > 36: return invalid
	for point in points:
		if not model.terrain.contains(Terrain.unpack(point)): return invalid
	var candidate := context(model, id)
	var check: Dictionary
	var original: Array
	if item.has("difficulty"):
		check = candidate.preview_piste(points, width + (int(item.get("level", 1)) - 1) * 4)
		original = item.points
	elif item.get("kind", "") == "walkway":
		check = candidate.preview_walkway(points)
		original = item.points
	elif item.has("bottom"):
		if points.size() != 2: return invalid
		check = candidate.preview_lift(item.kind, Terrain.unpack(points[0]), Terrain.unpack(points[1]))
		original = [item.bottom, item.top]
	else:
		if points.size() != 1: return invalid
		check = candidate.preview_plaza(item.kind, Terrain.unpack(points[0])) if item.has("radius") else candidate.preview_building(item.kind, Terrain.unpack(points[0]), rotation_value)
		original = [item.point]
	if not check.ok: return check
	check.points = check.get("points", points).duplicate(true)
	check.rotation = rotation_value
	check.width = 8.0 if item.get("kind", "") == "walkway" else width + ((int(item.get("level", 1)) - 1) * 4 if item.has("difficulty") else 0)
	check.neighbors = {}
	var changed: bool = check.points != original or rotation_value != int(item.get("rotation", 0)) or (item.has("difficulty") and not is_equal_approx(width, item.get("width", 20)))
	if item.has("difficulty") and points.size() != original.size():
		for old in original:
			var retained := false
			for point in check.points:
				retained = retained or Terrain.unpack(old).distance_to(Terrain.unpack(point)) < 2
			if retained: continue
			for other in model.pistes:
				if other.id == id: continue
				for point in other.points:
					if Terrain.unpack(old).distance_to(Terrain.unpack(point)) < 2:
						return {"ok": false, "message": L.text("Gemeinsamen Anschluss erhalten: Den Punkt ziehen, statt ihn zu löschen."), "cost": 0}
	if item.has("difficulty") and points.size() == original.size():
		for other in model.pistes:
			if other.id == id: continue
			var moved: Array = other.points.duplicate(true)
			for index in range(original.size()):
				if Terrain.unpack(original[index]).distance_to(Terrain.unpack(check.points[index])) < 0.01: continue
				for neighbor in range(moved.size()):
					if Terrain.unpack(moved[neighbor]).distance_to(Terrain.unpack(original[index])) < 2:
						moved[neighbor] = check.points[index].duplicate()
			if moved != other.points:
				var analysis: Dictionary = candidate.preview_piste(moved, Snow.piste_width(other))
				if not analysis.ok:
					return {"ok": false, "message": L.text("Die angeschlossene Piste %d wäre ungültig: %s") % L.args([other.number, analysis.message]), "cost": 0}
				check.neighbors[other.id] = analysis
	var distance := 0.0
	for index in range(mini(check.points.size(), original.size())):
		distance += Terrain.unpack(check.points[index]).distance_to(Terrain.unpack(original[index]))
	check.cost = roundi(maxf(500, item.cost * (0.08 if item.has("bottom") else 0.04) + distance * 8 + maxf(0, check.get("cost", item.cost) - item.cost) * 0.7)) if changed else 0
	check.changed = changed
	check.message = L.text("Änderung prüfen · %.0f € · erst Übernehmen bestätigt den Umbau.") % L.args(check.cost)
	return check

static func _piste(item: Dictionary, analysis: Dictionary) -> void:
	Snow.migrate_length(item, analysis.length)
	for key in ["points", "difficulty", "length", "horizontal", "drop", "average", "grade"]:
		item[key] = analysis[key]
	item.surface_revision = int(item.get("surface_revision", 0)) + 1

static func apply(model: RefCounted, id: int, points: Array, title: String, color: String, rotation_value: int = 0, width: float = 20) -> Dictionary:
	title = title.strip_edges()
	if title.is_empty() or title.length() > 60 or not valid_color(color):
		return {"ok": false, "message": L.text("Name: 1–60 Zeichen. Eine gültige Akzentfarbe wählen.")}
	var check := preview(model, id, points, rotation_value, width)
	if not check.ok: return check
	if not model._spend(check.cost): return {"ok": false, "message": L.text("Das Budget reicht für diesen Umbau noch nicht.")}
	var item: Dictionary = model.asset(id)
	if item.has("difficulty"):
		_piste(item, check)
		item.width = width
		item.grading = true
		for neighbor in check.neighbors:
			_piste(model.asset(neighbor), check.neighbors[neighbor])
	elif item.has("bottom"):
		item.bottom = points[0].duplicate()
		item.top = points[1].duplicate()
		item.length = check.length
		item.recent_departures = []
		for piste in model.pistes:
			var prepared := Foot.prepare_piste(piste.points, [item])
			if prepared != piste.points:
				var analysis: Dictionary = model.terrain.analyse(prepared)
				analysis.points = prepared
				_piste(piste, analysis)
	elif item.get("kind", "") == "walkway":
		item.points = check.points.duplicate(true)
		item.point = item.points[0].duplicate()
		item.length = check.length
	else:
		item.point = points[0].duplicate()
		item.rotation = rotation_value
	item.custom_name = item.get("custom_name",false) or title != item.name
	item.name = title
	item.color = color
	item.upgrade_total = item.get("upgrade_total", 0) + check.cost
	model._invalidate()
	if check.changed: model._reroute_guests()
	return {"ok": true, "message": L.text("%s angepasst. Umbau: %.0f €.") % L.args([title, check.cost]), "cost": check.cost}
