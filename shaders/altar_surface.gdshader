shader_type spatial;
render_mode cull_back;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float activated : hint_range(0.0, 1.0) = 0.0;
uniform float altar_time = 0.0;
void fragment() {
    vec3 surface = texture(albedo_texture, UV).rgb;
    // The supplied single-mesh atlas contains both limestone and blue crystal.
    float crystal = smoothstep(0.025, 0.16, min(surface.g, surface.b) - surface.r);
    ALBEDO = surface;
    ROUGHNESS = mix(0.86, 0.23, crystal);
    METALLIC = mix(0.02, 0.12, crystal);
    float breath = 0.94 + sin(altar_time * 1.7) * 0.06;
    EMISSION = surface * crystal * (0.12 + activated * 1.2) * breath;
}
