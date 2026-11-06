shader_type spatial;
render_mode cull_disabled;
varying vec3 world_at;
void vertex() { world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 tone = COLOR.rgb;
	float detail = 1.0;
	if (UV2.x > 1.5 && UV2.x < 2.5) {
		float board = abs(fract(UV.x / 1.2) - 0.5);
		detail = 0.80 + 0.20 * smoothstep(0.015, 0.065, board);
		detail -= 0.035 * sin(UV.y * 23.0 + sin(UV.x * 2.0));
	} else if (UV2.x > 2.5) {
		vec2 tile = abs(fract(vec2(UV.x + floor(UV.y / 1.3) * 0.75, UV.y) / vec2(1.5, 1.3)) - 0.5);
		detail = 0.80 + 0.20 * smoothstep(0.015, 0.06, min(tile.x, tile.y));
	} else if (UV2.x > 0.5) {
		detail = 0.92 + 0.08 * sin(world_at.x * 19.0) * cos(world_at.z * 17.0);
	} else {
		detail = 0.97 + 0.03 * sin(world_at.x * 2.4 + world_at.z * 1.7);
	}
	ALBEDO = tone * mix(1.0, detail, UV2.y);
	ROUGHNESS = 0.94;
	SPECULAR = 0.1;
}
