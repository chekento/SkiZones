shader_type spatial;
// Wind acts on visible geometry only. Terrain, pathfinding and picking remain unchanged.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform float sway_metres : hint_range(0.0, 1.0) = 0.32;
uniform float tempo : hint_range(0.1, 3.0) = 0.75;
uniform float canopy_height : hint_range(1.0, 20.0) = 16.0;

void vertex() {
    float top_weight = pow(clamp(VERTEX.y / canopy_height, 0.0, 1.0), 1.8);
    float individual = dot(MODEL_MATRIX[3].xz, vec2(0.021, 0.037));
    float gust = sin(TIME * tempo + individual) * 0.72
        + sin(TIME * tempo * 0.47 + individual * 1.31) * 0.28;
    VERTEX.x += sway_metres * top_weight * gust;
    VERTEX.z += sway_metres * top_weight * 0.46
        * sin(TIME * tempo * 0.81 + individual * 0.77);
}
void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 0.93;
    SPECULAR = 0.2;
}
