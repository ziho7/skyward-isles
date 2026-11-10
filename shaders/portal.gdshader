shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled;

uniform sampler2D seal_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float activated : hint_range(0.0, 1.0) = 0.0;
uniform float portal_time = 0.0;
uniform float seal_charge : hint_range(0.0, 1.0) = 0.0;
uniform int layer_id : hint_range(0, 3) = 0;

vec2 rotate_point(vec2 p, float angle) {
    float c = cos(angle); float s = sin(angle);
    return vec2(c * p.x - s * p.y, s * p.x + c * p.y);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 cell = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
        mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
    vec2 p = (UV - 0.5) * 2.0;
    float r = length(p);
    float t = portal_time;
    float opening = smoothstep(0.0, 1.0, activated);
    float pulse = 0.95 + 0.05 * sin(t * 1.4);
    vec3 amber = vec3(1.0, 0.38, 0.055);
    vec3 warm_white = vec3(1.0, 0.62, 0.16);
    if (layer_id == 3) {
        // Quiet moving depth behind the luminous strokes keeps the seal readable in daylight.
        vec2 flow = rotate_point(p, t * 0.035 + r * 0.8);
        float mist = noise(flow * 5.0 + vec2(t * 0.07, -t * 0.035));
        mist += noise(flow * 11.0 - vec2(t * 0.04)) * 0.35;
        float inside = 1.0 - smoothstep(0.72, 0.87, r);
        float rim_glow = exp(-abs(r - 0.85) * 42.0);
        ALBEDO = mix(vec3(0.018, 0.025, 0.055), vec3(0.055, 0.043, 0.085), mist * 0.5);
        ALBEDO += amber * rim_glow * 1.4 + vec3(0.015, 0.03, 0.065) * mist;
        ALPHA = inside * mix(0.68 + mist * 0.06, 0.10, opening) + rim_glow * 0.12;
    } else {
        // Three meshes at different depths carry independently rotating annular artwork.
        float spin = t * 0.037 + opening * 0.35;
        float band = smoothstep(0.655, 0.675, r) * (1.0 - smoothstep(0.89, 0.95, r));
        float visibility = 1.0;
        if (layer_id == 1) {
            spin = -t * 0.052 - opening * 0.55;
            band = smoothstep(0.425, 0.445, r) * (1.0 - smoothstep(0.655, 0.675, r));
            visibility = 1.0 - opening * 0.72;
        } else if (layer_id == 2) {
            spin = t * 0.071 + opening * 0.7;
            band = 1.0 - smoothstep(0.425, 0.445, r);
            visibility = 1.0 - opening;
        }
        vec2 art_uv = rotate_point(p, spin) * 0.5 + 0.5;
        vec4 ink = texture(seal_texture, art_uv);
        float luminance = dot(ink.rgb, vec3(0.2126, 0.7152, 0.0722));
        // Preserve the source alpha; suppress the amber haze to isolate fine emissive calligraphy.
        float detail = ink.a * smoothstep(0.08, 0.57, luminance);
        float power = (0.8 + seal_charge * 0.14 + opening * 0.18) * pulse;
        vec3 color = mix(amber, warm_white, smoothstep(0.24, 0.85, luminance));
        // Godot's unshaded path uses ALBEDO as its final HDR color.
        ALBEDO = color * (1.9 + luminance * 2.2) * power;
        ALPHA = clamp(detail * band * visibility, 0.0, 0.97);
    }
}
