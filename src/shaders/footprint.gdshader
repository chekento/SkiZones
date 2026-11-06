shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float width = mix(0.62, 0.92, UV.y);
	float sole = p.x * p.x / (width * width) + pow(p.y, 4.0);
	if (sole > 1.0) discard;
	ALBEDO = mix(COLOR.rgb * 0.83, COLOR.rgb, smoothstep(0.0, 0.3, sole));
	ALPHA = COLOR.a * (1.0 - smoothstep(0.82, 1.0, sole));
}
