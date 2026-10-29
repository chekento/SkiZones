extends RefCounted
## Ray queries use the actual visible triangles, independently of physics ticks.
const Snow = preload("res://src/core/snow_surface.gd")
var entries: Dictionary = {}
var builds := 0

func reset() -> void:
	var ground: Dictionary = entries.get("ground", {})
	entries.clear()
	if not ground.is_empty(): entries.ground = ground

func add_mesh(key: String, mesh: Mesh, piste: Dictionary = {}, frames: Array = []) -> void:
	if entries.has(key) and entries[key].mesh == mesh: return
	entries[key] = {"mesh": mesh, "bounds": mesh.get_aabb().grow(0.7), "piste": piste, "frames": frames, "revision": -2, "tree": null}

func intersect(origin: Vector3, direction: Vector3) -> Dictionary:
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
	return result
