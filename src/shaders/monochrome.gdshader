shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {
    vec4 pixel = textureLod(screen_texture, SCREEN_UV, 0.0);
    float ink = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
    COLOR = vec4(vec3(smoothstep(0.14, 0.88, ink)), pixel.a);
}
