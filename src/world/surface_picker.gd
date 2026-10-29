extends RefCounted
## Ray queries use the actual visible triangles, independently of physics ticks.
const Snow = preload("res://src/core/snow_surface.gd")
var entries: Dictionary = {}
var builds := 0
var heights: Dictionary = {}

func reset() -> void:
	var ground: Dictionary = entries.get("ground", {})
	entries.clear()
	heights.clear()
	if not ground.is_empty(): entries.ground = ground

func add_mesh(key: String, mesh: Mesh, piste: Dictionary = {}, frames: Array = []) -> void:
	if entries.has(key) and entries[key].mesh == mesh:
		if piste.is_empty() or entries[key].piste.get("surface_revision", 0) == piste.get("surface_revision", 0): return
	var visible_snow: Dictionary = {}
	if not piste.is_empty():
		for field in ["length", "width", "level", "surface_revision"]: visible_snow[field] = piste.get(field, 20 if field == "width" else 1 if field == "level" else 0)
		visible_snow.surface = piste.surface.duplicate()
	entries[key] = {"mesh": mesh, "bounds": mesh.get_aabb().grow(0.7), "piste": visible_snow, "frames": frames, "revision": -2, "tree": null}
	heights.clear()

func position(point: Vector2) -> Vector3:
	if heights.has(point): return heights[point]
	var hit := intersect(Vector3(point.x, 10000, point.y), Vector3.DOWN)
	var at: Vector3 = hit.get("position", Vector3.INF)
	if at.is_finite(): at = Vector3(point.x, at.y, point.y)
	if heights.size() >= 8192: heights.clear()
	heights[point] = at
	return at

func intersect(origin: Vector3, direction: Vector3, repair_edge: bool = true) -> Dictionary:
	var nearest := INF
	var result: Dictionary = {}
	for data in entries.values():
		if not data.bounds.has_point(origin) and data.bounds.intersects_ray(origin, direction) == null: continue
		var revision: int = data.piste.get("surface_revision", -1)
		if data.tree == null or data.revision != revision:
			var faces: PackedVector3Array = data.mesh.get_faces()
			if not data.piste.is_empty():
				for i in range(faces.size()):
					var frame: Vector2 = data.frames[i]
					faces[i].y += Snow.relief(data.piste, frame.x, frame.y)
			var tree := TriangleMesh.new()
			if not tree.create_from_faces(faces): continue
			data.tree = tree
			data.revision = revision
			builds += 1
		var hit: Dictionary = data.tree.intersect_ray(origin, direction)
		if hit.is_empty(): continue
		var distance := origin.distance_squared_to(hit.position)
		if distance < nearest:
			nearest = distance
			result = hit
	# Float rounding can put an exact vertex ray just outside both adjacent faces.
	# A millimetre probe finds that face; intersect its plane with the original ray.
	if result.is_empty() and repair_edge:
		var side := direction.cross(Vector3.UP).normalized()
		if side.length_squared() < 0.5: side = Vector3.RIGHT
		var up := side.cross(direction).normalized()
		for offset in [side, -side, up, -up]:
			var nearby := intersect(origin + offset * 0.002, direction, false)
			if nearby.is_empty(): continue
			var denominator: float = direction.dot(nearby.normal)
			if absf(denominator) > 0.0001:
				nearby.position = origin + direction * ((nearby.position - origin).dot(nearby.normal) / denominator)
			return nearby
	return result
