shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float activated : hint_range(0.0, 1.0) = 0.0;
uniform float altar_time = 0.0;
void fragment() {
    vec2 p = (UV - 0.5) * 2.0;
    float r = length(p);
    float a = atan(p.y, p.x);
    float wave = 0.95 + 0.05 * sin(altar_time * 1.7);
    float rim = exp(-pow((r - 0.72) / 0.009, 2.0));
    float outer = exp(-pow((r - 0.83) / 0.004, 2.0));
    float arcs = pow(0.5 + 0.5 * cos(a * 3.0 - altar_time * 1.2), 8.0);
    float trail = exp(-pow((r - 0.77) / 0.012, 2.0)) * arcs;
    float ticks = pow(0.5 + 0.5 * cos(a * 24.0 + altar_time * 0.55), 20.0)
        * smoothstep(0.855, 0.86, r) * (1.0 - smoothstep(0.88, 0.89, r));
    float glow = exp(-abs(r - 0.72) * 28.0) * 0.23;
    float power = mix(0.38, 1.0, activated) * wave;
    vec3 cyan = vec3(0.035, 0.58, 1.0);
    // Unshaded materials output ALBEDO directly, including values above 1 for glow.
    ALBEDO = (cyan * (rim * 3.0 + outer * 1.3 + trail * 3.2 + glow)
        + vec3(1.0, 0.78, 0.36) * ticks) * power;
    ALPHA = clamp((rim + outer * 0.55 + trail + ticks * 0.7 + glow) * power, 0.0, 0.9);
}
