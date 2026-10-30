extends RefCounted
## Keep corridor geometry on the GPU; traffic only uploads a small height map.
const Snow = preload("res://src/core/snow_surface.gd")
const PisteMesh = preload("res://src/world/piste_mesh.gd")
var surfaces: Dictionary = {}
var uploads := 0
var mesh_builds := 0
var pick_frames: Dictionary = {}
var pick_weights: Dictionary = {}
var exclusions: Dictionary = {}
var junction_grid: Dictionary = {}
var shader := Shader.new()

func _init() -> void:
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D relief_map : filter_linear, repeat_disable;
uniform vec2 map_size;
uniform bool trace_material = false;
uniform float groomed = 1.0;
varying vec3 snow_world;
void vertex() {
 vec2 at = (clamp(UV,vec2(0.0),vec2(1.0))*(map_size-vec2(1.0))+vec2(0.5))/map_size;
 float h = textureLod(relief_map,at,0.0).r*0.95-0.35;
 VERTEX.y += h*COLOR.a;
 snow_world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
 float groove = sin(UV.x*760.0)*0.012/(1.0+fwidth(UV.x)*600.0);
 float grain = sin(snow_world.x*13.1+snow_world.z*27.2)*sin(snow_world.x*35.3-snow_world.z*17.8);
 grain *= 0.007/(1.0+length(fwidth(snow_world.xz))*18.0);
 ALBEDO = COLOR.rgb * (1.0 + (trace_material ? 0.0 : groove*groomed*COLOR.a+grain));
 if (!trace_material) {
  vec3 geometric_normal = normalize(cross(dFdx(VERTEX),dFdy(VERTEX)));
  if (dot(geometric_normal,NORMAL)<0.0) { geometric_normal = -geometric_normal; }
  NORMAL = normalize(mix(NORMAL,geometric_normal,0.55));
 }
 ROUGHNESS = 0.92;
 SPECULAR = trace_material ? 0.04 : 0.16;
}
"""

func reset() -> void:
	surfaces.clear()
	pick_frames.clear()
	pick_weights.clear()
	exclusions.clear()
	junction_grid.clear()

func configure(pistes: Array) -> void:
	# Partition overlapping snow corridors. Each square metre has exactly one
	# owner; junction shoulders/deformation fade to one common snow surface.
	var shapes: Array = []
	for piste in pistes:
		var width := Snow.piste_width(piste)
		for polygon in PisteMesh.outlines(piste.points, width):
			shapes.append({"id": piste.id, "polygon": polygon, "bounds": PisteMesh.polygon_bounds(polygon)})
		for index in range(1, piste.points.size()):
			var a := Vector2(piste.points[index - 1][0], piste.points[index - 1][1])
			var b := Vector2(piste.points[index][0], piste.points[index][1])
			var segment := {"id": piste.id, "a": a, "b": b, "radius": width * 0.5}
			var bounds := Rect2(a, Vector2.ZERO).expand(b).grow(width * 0.5 + 12)
			for x in range(floori(bounds.position.x / 64), floori(bounds.end.x / 64) + 1):
				for y in range(floori(bounds.position.y / 64), floori(bounds.end.y / 64) + 1):
					var key := Vector2i(x, y)
					if not junction_grid.has(key): junction_grid[key] = []
					junction_grid[key].append(segment)
	for shape in shapes:
		if not exclusions.has(shape.id): exclusions[shape.id] = []
		for other in shapes:
			if other.id < shape.id and shape.bounds.intersects(other.bounds, true) and not exclusions[shape.id].has(other): exclusions[shape.id].append(other)

func junction_weight(id: int, point: Vector2) -> float:
	var weight := 1.0
	for segment in junction_grid.get(Vector2i((point / 64).floor()), []):
		if segment.id == id: continue
		var distance := Geometry2D.get_closest_point_to_segment(point, segment.a, segment.b).distance_to(point)
		weight = minf(weight, smoothstep(segment.radius + 0.15, segment.radius + 12, distance))
	return weight

func height_offset(piste: Dictionary, point: Vector2, fraction: float, lateral: float) -> float:
	return lerpf(0.65, Snow.mesh_height(piste, fraction, lateral), junction_weight(piste.id, point))

func update(piste: Dictionary) -> Dictionary:
	Snow.ensure(piste)
	if not surfaces.has(piste.id):
		var material := ShaderMaterial.new()
		material.shader = shader
		var trace: ShaderMaterial = material.duplicate()
		trace.set_shader_parameter("trace_material", true)
		surfaces[piste.id] = {"material": material, "trace": trace, "revision": -1, "texture": null}
	var data: Dictionary = surfaces[piste.id]
	var revision: int = piste.get("surface_revision", 0)
	if data.revision != revision:
		var bytes := PackedByteArray()
		bytes.resize(piste.surface.size())
		for index in range(bytes.size()):
			bytes[index] = clampi(roundi((piste.surface[index] + 0.35) / 0.95 * 255), 0, 255)
		var image := Image.create_from_data(Snow.LANES + 1, Snow.rows(piste), false, Image.FORMAT_R8, bytes)
		if data.texture == null:
			data.texture = ImageTexture.create_from_image(image)
			for material in [data.material, data.trace]:
				material.set_shader_parameter("relief_map", data.texture)
				material.set_shader_parameter("map_size", Vector2(Snow.LANES + 1, Snow.rows(piste)))
		else:
			data.texture.update(image)
		data.material.set_shader_parameter("groomed", 1.0 - Snow.roughness(piste))
		data.revision = revision
		uploads += 1
	return data

func uv(piste: Dictionary, fraction: float, lateral: float) -> Vector2:
	return Vector2(clampf(lateral / Snow.piste_width(piste) + 0.5, 0, 1), clampf(fraction * piste.length / Snow.STEP / (Snow.rows(piste) - 1), 0, 1))

func build(mountain: RefCounted, piste: Dictionary) -> ArrayMesh:
	var width := Snow.piste_width(piste)
	var surface := SurfaceTool.new()
	var frames: Array = []
	var weights := PackedFloat32Array()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	for sample in PisteMesh.samples(mountain, piste.points, width, 12.0 if piste.get("imported", false) else 4.0, exclusions.get(piste.id, [])):
		frames.append(Vector2(sample.fraction, sample.lateral))
		var weight := junction_weight(piste.id, sample.point)
		weights.append(weight)
		var edge := smoothstep(width * 0.5 - 2.3, width * 0.5, sample.distance)
		var color := Color("f4f5fc").darkened((sin(sample.lateral * 10) * 0.5 + 0.5) * 0.012 * weight).lerp(Color("e1e8f5"), edge * weight * 0.55)
		color.a = weight
		surface.set_color(color)
		surface.set_uv(uv(piste, sample.fraction, sample.lateral))
		surface.add_vertex(mountain.world(sample.point, lerpf(0.65, Snow.base_height(piste, sample.fraction) + edge * 0.13, weight)))
	pick_frames[piste.id] = frames
	pick_weights[piste.id] = weights
	if frames.is_empty(): return ArrayMesh.new()
	surface.index()
	surface.generate_normals()
	mesh_builds += 1
	return surface.commit()
