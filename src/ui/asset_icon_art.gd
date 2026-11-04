extends RefCounted
## Orthographic catalogue drawings use the very same theme models as the world.
static var batches: Dictionary={}
static func paint(canvas: Control,mesh: Mesh,rect: Rect2) -> void:
	if mesh.get_surface_count()==0:return
	var key: String=str(mesh.get_instance_id())+str(rect)
	if batches.has(key):
		canvas.set_meta("icon_batch",batches[key])
		if batches[key] is PackedVector2Array:canvas.draw_multiline(batches[key],Color.BLACK,1.5,true)
		else:canvas.draw_mesh(batches[key],null)
		return
	if batches.size()>320:batches.clear()
	var arrays: Array=mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var points:=PackedVector2Array()
	var bounds:=Rect2()
	for index in range(vertices.size()):
		var v: Vector3=vertices[index]
		var at:=Vector2(v.x*.86-v.z*.5,-v.y+v.x*.22+v.z*.32)
		points.append(at)
		bounds=Rect2(at,Vector2.ZERO) if index==0 else bounds.expand(at)
	var scale_value: float=minf(rect.size.x/maxf(1,bounds.size.x),rect.size.y/maxf(1,bounds.size.y))
	for index in range(points.size()):points[index]=rect.get_center()+(points[index]-bounds.get_center())*scale_value
	if mesh is ArrayMesh and mesh.surface_get_primitive_type(0)==Mesh.PRIMITIVE_LINES:
		batches[key]=points
		canvas.draw_multiline(points,Color.BLACK,1.5,true)
		return
	var facets: Array=[]
	var count: int=indices.size() if not indices.is_empty() else vertices.size()
	for index in range(0,count-2,3):
		var a: int=indices[index] if not indices.is_empty() else index
		var b: int=indices[index+1] if not indices.is_empty() else index+1
		var c: int=indices[index+2] if not indices.is_empty() else index+2
		var center: Vector3=(vertices[a]+vertices[b]+vertices[c])/3
		facets.append({"depth":center.x+center.z-center.y*.05,"points":PackedVector2Array([points[a],points[b],points[c]]),"color":colors[a] if not colors.is_empty() else Color.WHITE})
	facets.sort_custom(func(a,b):return float(a.depth)<float(b.depth))
	var draw_vertices:=PackedVector2Array()
	var draw_colors:=PackedColorArray()
	for facet in facets:
		var triangle: PackedVector2Array=facet.points
		if absf((triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]))>.01:
			draw_vertices.append_array(triangle)
			for index in range(3):draw_colors.append(facet.color)
	var draw_arrays:=[];draw_arrays.resize(Mesh.ARRAY_MAX)
	draw_arrays[Mesh.ARRAY_VERTEX]=draw_vertices
	draw_arrays[Mesh.ARRAY_COLOR]=draw_colors
	var batch:=ArrayMesh.new()
	if not draw_vertices.is_empty():
		batch.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,draw_arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		batches[key]=batch
		canvas.set_meta("icon_batch",batch)
		canvas.draw_mesh(batch,null)
