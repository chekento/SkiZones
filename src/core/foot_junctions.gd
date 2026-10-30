extends RefCounted
## Split actual drawn paths at their crossings. A spatial grid bounds the work.
const Terrain = preload("res://src/core/terrain.gd")

static func stitch(links: Array, nodes: Dictionary, areas: Array) -> Array:
	var result: Array = []
	var segments: Array = []
	for link in links:
		if link.get("closed", false) or not (link.get("manual", false) or link.get("promenade", false)):
			result.append(link)
			continue
		for index in range(1, link.points.size()):
			var a := Terrain.unpack(link.points[index - 1])
			var b := Terrain.unpack(link.points[index])
			var first: String = link.from if index == 1 else "pathbend:%d:%d" % [segments.size(), index]
			var last: String = link.to if index == link.points.size() - 1 else "pathbend:%d:%d" % [segments.size() + 1, index + 1]
			nodes[first] = Terrain.pack(a)
			nodes[last] = Terrain.pack(b)
			segments.append({"a": a, "b": b, "first": first, "last": last, "link": link, "cuts": [{"at": 0.0, "key": first}, {"at": 1.0, "key": last}]})
	var grid: Dictionary = {}
	var seen: Dictionary = {}
	for index in range(segments.size()):
		var segment: Dictionary = segments[index]
		var bounds := Rect2(segment.a, Vector2.ZERO).expand(segment.b)
		var low := Vector2i((bounds.position / 64).floor())
		var high := Vector2i((bounds.end / 64).floor())
		for x in range(low.x, high.x + 1):
			for y in range(low.y, high.y + 1):
				var cell := Vector2i(x, y)
				for other_index in grid.get(cell, []):
					var pair := Vector2i(other_index, index)
					if seen.has(pair): continue
					seen[pair] = true
					var other: Dictionary = segments[other_index]
					if segment.first in [other.first, other.last] or segment.last in [other.first, other.last]: continue
					var hit: Variant = Geometry2D.segment_intersects_segment(segment.a, segment.b, other.a, other.b)
					if hit != null:
						var key := _junction(hit, nodes, areas)
						_cut(segment, hit, key)
						_cut(other, hit, key)
					else:
						# Collinear overlaps have no unique segment intersection.
						# Their shared endpoints still form real road junctions.
						for point in [segment.a, segment.b, other.a, other.b]:
							if Geometry2D.get_closest_point_to_segment(point, segment.a, segment.b).distance_to(point) > 0.005 or Geometry2D.get_closest_point_to_segment(point, other.a, other.b).distance_to(point) > 0.005: continue
							var key := _junction(point, nodes, areas)
							_cut(segment, point, key)
							_cut(other, point, key)
				if not grid.has(cell): grid[cell] = []
				grid[cell].append(index)
	# Piste starts and runouts can join the middle of a drawn road as well.
	for area in areas.duplicate():
		if area.kind != "piste_gate": continue
		var closest: Dictionary = {}
		var distance := 1.81
		for segment in segments:
			var hit := Geometry2D.get_closest_point_to_segment(area.point, segment.a, segment.b)
			if hit.distance_to(area.point) < distance:
				distance = hit.distance_to(area.point)
				closest = {"segment": segment, "point": hit}
		if closest.is_empty(): continue
		var key := _junction(closest.point, nodes, areas)
		_cut(closest.segment, closest.point, key)
		result.append({"from": area.key, "to": key, "points": [nodes[area.key], nodes[key]], "width": 7.0, "piste_access": true})
	for segment in segments:
		segment.cuts.sort_custom(func(a, b): return a.at < b.at)
		var previous: Dictionary = segment.cuts[0]
		for cut in segment.cuts.slice(1):
			if previous.key != cut.key:
				var link: Dictionary = segment.link.duplicate()
				link.from = previous.key
				link.to = cut.key
				link.points = [nodes[previous.key], nodes[cut.key]]
				result.append(link)
			previous = cut
	return result

static func _junction(point: Vector2, nodes: Dictionary, areas: Array) -> String:
	var snapped := point.snapped(Vector2(0.001, 0.001))
	var key := "pathjoin:%.3f:%.3f" % [snapped.x, snapped.y]
	if not nodes.has(key):
		nodes[key] = Terrain.pack(snapped)
		areas.append({"key": key, "center": snapped, "point": snapped, "radius": 4.0, "root": false, "id": 0, "kind": "walkway"})
	return key

static func _cut(segment: Dictionary, point: Vector2, key: String) -> void:
	var along: float = segment.a.distance_to(point) / maxf(0.001, segment.a.distance_to(segment.b))
	for cut in segment.cuts:
		if cut.key == key: return
	segment.cuts.append({"at": clampf(along, 0, 1), "key": key})
