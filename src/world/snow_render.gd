extends RefCounted
## Keep corridor geometry on the GPU; traffic only uploads a small height map.
const Snow = preload("res://src/core/snow_surface.gd")
const PisteMesh = preload("res://src/world/piste_mesh.gd")
var surfaces: Dictionary = {}
var uploads := 0
var mesh_builds := 0
var pick_frames: Dictionary = {}
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
 VERTEX.y += h;
 snow_world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
 float groove = sin(UV.x*760.0)*0.012/(1.0+fwidth(UV.x)*600.0);
 float grain = sin(snow_world.x*13.1+snow_world.z*27.2)*sin(snow_world.x*35.3-snow_world.z*17.8);
 grain *= 0.007/(1.0+length(fwidth(snow_world.xz))*18.0);
 ALBEDO = COLOR.rgb * (1.0 + (trace_material ? 0.0 : groove*groomed+grain));
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
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(0)
	for sample in PisteMesh.samples(mountain, piste.points, width):
		frames.append(Vector2(sample.fraction, sample.lateral))
		var edge := smoothstep(width * 0.5 - 2.3, width * 0.5, sample.distance)
		var color := Color("f4f5fc").darkened((sin(sample.lateral * 10) * 0.5 + 0.5) * 0.012)
		surface.set_color(color.lerp(Color("e1e8f5"), edge * 0.55))
		surface.set_uv(uv(piste, sample.fraction, sample.lateral))
		surface.add_vertex(mountain.world(sample.point, Snow.base_height(piste, sample.fraction) + edge * 0.13))
	surface.index()
	surface.generate_normals()
	mesh_builds += 1
	pick_frames[piste.id] = frames
	return surface.commit()
