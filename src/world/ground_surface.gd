extends RefCounted
## Clip corridors to the rendered ground faces, sharing their exact planes.
var cell_size := 32.0
var source: Mesh
var faces := PackedVector3Array()
var buckets: Dictionary = {}
var heights: Dictionary = {}

func configure(mesh: Mesh) -> void:
	if source == mesh: return
	source = mesh
	cell_size = float(mesh.get_meta("ground_cell", 32.0))
	faces = mesh.get_faces()
	buckets.clear()
	heights.clear()
	for index in range(0, faces.size(), 3):
		var polygon := PackedVector2Array()
		for j in range(3): polygon.append(Vector2(faces[index + j].x, faces[index + j].z))
		var bounds := Rect2(polygon[0], Vector2.ZERO).expand(polygon[1]).expand(polygon[2])
		for x in range(floori(bounds.position.x / cell_size), floori(bounds.end.x / cell_size) + 1):
			for y in range(floori(bounds.position.y / cell_size), floori(bounds.end.y / cell_size) + 1):
				var key := Vector2i(x, y)
				if not buckets.has(key): buckets[key] = []
				buckets[key].append(index)

func plane_height(index: int, point: Vector2) -> float:
	var a := faces[index]
	var normal := (faces[index + 1] - a).cross(faces[index + 2] - a)
	return a.y - (normal.x * (point.x - a.x) + normal.z * (point.y - a.z)) / normal.y

func position(point: Vector2, fallback: float = 0.0, offset: float = 0.0) -> Vector3:
	if heights.has(point): return Vector3(point.x, heights[point] + offset, point.y)
	var elevation := fallback
	for index in buckets.get(Vector2i((point / cell_size).floor()), []):
		var a := Vector2(faces[index].x, faces[index].z)
		var b := Vector2(faces[index + 1].x, faces[index + 1].z)
		var c := Vector2(faces[index + 2].x, faces[index + 2].z)
		if Geometry2D.is_point_in_polygon(point, PackedVector2Array([a, b, c])):
			elevation = plane_height(index, point)
			break
	if heights.size() > 12000: heights.clear()
	heights[point] = elevation
	return Vector3(point.x, elevation + offset, point.y)

func clip(polygon: PackedVector2Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	var candidates: Dictionary = {}
	for x in range(floori(bounds.position.x / cell_size), floori(bounds.end.x / cell_size) + 1):
		for y in range(floori(bounds.position.y / cell_size), floori(bounds.end.y / cell_size) + 1):
			for index in buckets.get(Vector2i(x, y), []): candidates[index] = true
	for index in candidates:
		var triangle := PackedVector2Array()
		for j in range(3): triangle.append(Vector2(faces[index + j].x, faces[index + j].z))
		for patch in Geometry2D.intersect_polygons(polygon, triangle):
			var indices := Geometry2D.triangulate_polygon(patch)
			for i in range(0, indices.size(), 3):
				var a: Vector2 = patch[indices[i]]
				var b: Vector2 = patch[indices[i + 1]]
				var c: Vector2 = patch[indices[i + 2]]
				if absf((b - a).cross(c - a)) < 0.0001: continue
				for point in ([a, b, c] if (b - a).cross(c - a) > 0 else [a, c, b]):
					result.append(Vector3(point.x, plane_height(index, point), point.y))
	return result
