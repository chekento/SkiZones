shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
uniform vec4 deep_color : source_color = vec4(0.075, 0.29, 0.36, 1.0);
uniform vec4 edge_color : source_color = vec4(0.48, 0.79, 0.84, 1.0);
varying vec2 lake_uv;
void vertex() {
	lake_uv = UV;
}
void fragment() {
	vec2 p = (lake_uv - vec2(0.5)) * 2.0;
	float radius = length(p);
	float shallows = smoothstep(0.38, 1.05, radius);
	float primary = sin(radius * 61.0 - TIME * 1.45 + sin(p.x * 14.0) * 0.7);
	float crosswave = sin(p.x * 92.0 + TIME * 0.78) * cos(p.y * 77.0 - TIME * 0.57);
	vec3 water = mix(deep_color.rgb, edge_color.rgb, shallows);
	water += vec3(0.019, 0.032, 0.039) * (primary * 0.58 + crosswave * 0.42);
	float highlights = pow(max(0.0, primary * crosswave), 7.0) * 0.12;
	ALBEDO = clamp(water + vec3(highlights), vec3(0.0), vec3(1.0));
	ROUGHNESS = mix(0.31, 0.16, highlights);
	SPECULAR = 0.72;
	METALLIC = 0.035;
}
