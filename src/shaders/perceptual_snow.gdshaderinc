// Static world-locked microrelief. Camera motion reveals its directional facets;
// there is no TIME/UV scrolling, screen warp or movement of the snow surface.
uniform bool perceptual_snow = true;
float snow_depth_detail(vec3 world, vec3 eye) {
    if (!perceptual_snow) { return 0.0; }
    vec2 axis = vec2(0.82, 0.57236);
    float footprint = length(fwidth(world.xz));
    float visible = 1.0 - smoothstep(0.25, 1.25, footprint);
    float phase = dot(world.xz, axis) * 2.7
        + sin(world.x * 0.07) * 2.5 + sin(world.z * 0.045) * 3.0;
    float cross_phase = dot(world.xz, vec2(-axis.y, axis.x)) * 0.74;
    float ripple = sin(phase) * 0.62 + sin(cross_phase) * 0.38;
    vec3 sight = normalize(eye - world);
    float facet = cos(phase) * dot(sight.xz, axis);
    float local_patch = smoothstep(-0.35, 0.55,
        sin(world.x * 0.021) * cos(world.z * 0.017));
    // Maximum +/-4.4% local contrast, smoothly removed before subpixel aliasing.
    return visible * local_patch * (ripple * 0.024 + facet * 0.020);
}
