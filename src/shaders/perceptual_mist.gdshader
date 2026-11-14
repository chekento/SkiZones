shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

uniform vec4 mist_color : source_color = vec4(0.82, 0.90, 0.96, 1.0);
uniform float opacity : hint_range(0.0, 0.16) = 0.05;
varying vec3 mist_world;

void vertex() {
    mist_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    // Soft ellipsoids occupy real world positions and obey terrain occlusion.
    // Local structure remains static; only real camera movement causes parallax.
    float edge = pow(max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 1.8);
    float structure = 0.78 + 0.22 * sin(mist_world.x * 0.025 + mist_world.z * 0.013)
        * sin(mist_world.z * 0.031 - mist_world.y * 0.04);
    float near_fade = smoothstep(90.0, 260.0, distance(CAMERA_POSITION_WORLD, mist_world));
    ALBEDO = mist_color.rgb;
    ALPHA = opacity * edge * structure * near_fade;
}
