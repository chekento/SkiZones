extends RefCounted
## Clip corridors to the rendered ground faces, sharing their exact planes.
var cell_size := 32.0
var source: Mesh
var faces := PackedVector3Array()
var buckets: Dictionary = {}
var heights: Dictionary = {}
var _bary_u := PackedVector3Array()
var _bary_v := PackedVector3Array()
var _planes := PackedVector3Array()
var _origins := PackedVector2Array()

func configure(mesh: Mesh) -> void:
	if source == mesh: return
	source = mesh
	cell_size = float(mesh.get_meta("ground_cell", 32.0))
	faces = mesh.get_faces()
	buckets.clear()
	heights.clear()
	_bary_u.clear()
	_bary_v.clear()
	_planes.clear()
	_origins.clear()
	for index in range(0, faces.size(), 3):
		var a: Vector3=faces[index]
		var b: Vector3=faces[index+1]-a
		var c: Vector3=faces[index+2]-a
		var determinant: float=b.x*c.z-c.x*b.z
		_origins.append(Vector2(a.x,a.z))
		if absf(determinant)<0.000000001:
			_bary_u.append(Vector3(INF,0,0))
			_bary_v.append(Vector3.ZERO)
			_planes.append(Vector3(0,0,a.y))
			continue
		var u:=Vector3(c.z,-c.x,0)/determinant
		var v:=Vector3(-b.z,b.x,0)/determinant
		_bary_u.append(u)
		_bary_v.append(v)
		_planes.append(Vector3(0,0,a.y)+u*b.y+v*c.y)
		var polygon := PackedVector2Array()
		for j in range(3): polygon.append(Vector2(faces[index + j].x, faces[index + j].z))
		var bounds := Rect2(polygon[0], Vector2.ZERO).expand(polygon[1]).expand(polygon[2])
		for x in range(floori(bounds.position.x / cell_size), floori(bounds.end.x / cell_size) + 1):
			for y in range(floori(bounds.position.y / cell_size), floori(bounds.end.y / cell_size) + 1):
				var key := Vector2i(x, y)
				if not buckets.has(key): buckets[key] = []
				buckets[key].append(index)

func plane_height(index: int, point: Vector2) -> float:
	var origin: Vector2=_origins[index/3]
	return _planes[index/3].dot(Vector3(point.x-origin.x,point.y-origin.y,1))

func position(point: Vector2, fallback: float = 0.0, offset: float = 0.0) -> Vector3:
	if heights.has(point): return Vector3(point.x, heights[point] + offset, point.y)
	var elevation := fallback
	for index in buckets.get(Vector2i((point / cell_size).floor()), []):
		# These coefficients are prepared once per terrain mesh. Moving guests
		# no longer allocate a polygon for every candidate ground triangle.
		var triangle: int=index/3
		# Local coordinates avoid cancellation on kilometre-scale real maps.
		var origin: Vector2=_origins[triangle]
		var sample:=Vector3(point.x-origin.x,point.y-origin.y,1)
		var u: float=_bary_u[triangle].dot(sample)
		var v: float=_bary_v[triangle].dot(sample)
		if u>=-0.000001 and v>=-0.000001 and u+v<=1.000001:
			elevation = _planes[triangle].dot(sample)
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
