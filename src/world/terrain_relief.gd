extends RefCounted
## Ground-only shader: antialiased height contours and directional relief.
## Geometry, collision, picking and snow corridors retain their exact surfaces.
static func material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
uniform bool contours = true;
uniform float relief_strength = 0.22;
uniform vec3 contour_color : source_color = vec3(0.31, 0.45, 0.49);
varying vec3 ground_world;
varying vec3 ground_normal;
void vertex() {
 ground_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
 ground_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
float contour(float height, float spacing, float width) {
 float distance = abs(fract(height / spacing + 0.5) - 0.5) * spacing;
 float aa = max(fwidth(height) * 0.85, 0.12);
 float fade = 1.0 - smoothstep(spacing * 0.10, spacing * 0.30, aa);
 return (1.0 - smoothstep(width, width + aa, distance)) * fade;
}
void fragment() {
 vec3 n = normalize(ground_normal);
 float face = dot(n, normalize(vec3(-0.55,0.75,-0.36)));
 float slope = 1.0 - n.y;
 float shape = 1.0 - relief_strength * clamp(0.65 - face, 0.0, 0.85);
 vec3 snow = COLOR.rgb * shape;
 snow = mix(snow, snow * vec3(0.78,0.87,1.0), slope * 0.16);
 if (contours) {
  float fine = contour(ground_world.y, 20.0, 0.16);
  float major = contour(ground_world.y, 100.0, 0.32);
  float ink = max(fine * 0.16, major * 0.30);
  ink *= smoothstep(0.012,0.10,slope);
  snow = mix(snow, contour_color, ink);
 }
 ALBEDO = snow;
 ROUGHNESS = 0.96;
 SPECULAR = 0.10;
}
"""
	var result := ShaderMaterial.new()
	result.shader = shader
	return result

static func label_points(mesh: Mesh) -> Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var selected := {}
	for index in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[index]]
		var b: Vector3 = vertices[indices[index + 1]]
		var c: Vector3 = vertices[indices[index + 2]]
		var low := minf(a.y, minf(b.y, c.y))
		var high := maxf(a.y, maxf(b.y, c.y))
		for height in range((floori(low / 100) + 1) * 100, floori(high / 100) * 100 + 1, 100):
			var crossings: Array[Vector3] = []
			for pair in [[a,b],[b,c],[c,a]]:
				if (pair[0].y < height and pair[1].y >= height) or (pair[1].y < height and pair[0].y >= height):
					crossings.append(pair[0].lerp(pair[1], (height - pair[0].y) / (pair[1].y - pair[0].y)))
			if crossings.size() == 2:
				var point := (crossings[0]+crossings[1])*0.5
				if not selected.has(height) or Vector2(point.x,point.z).length_squared()<Vector2(selected[height].x,selected[height].z).length_squared(): selected[height]=point
	var result: Array = []
	var heights := selected.keys()
	heights.sort()
	for height in heights:
		if result.size() >= 10: break
		result.append({"height":height, "point":selected[height]})
	return result
