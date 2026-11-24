shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.10, 0.36, 0.46, 0.80);
uniform vec4 deep_color : source_color = vec4(0.02, 0.14, 0.24, 0.92);
uniform float wave_speed = 0.6;
uniform float wave_scale = 0.06;

varying vec3 wpos;

void vertex() {
    wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float t = TIME * wave_speed;
    vec2 p = wpos.xz * wave_scale;
    float h1 = sin(p.x * 1.3 + t) + sin(p.y * 1.7 - t * 1.2) + sin((p.x + p.y) * 2.1 + t * 0.7);
    vec3 n = normalize(vec3(-cos(p.x * 1.3 + t) * 0.12, 1.0, -cos(p.y * 1.7 - t * 1.2) * 0.12));
    NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
    float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
    vec3 col = mix(shallow_color.rgb, deep_color.rgb, clamp(0.5 + 0.12 * h1, 0.0, 1.0));
    ALBEDO = col;
    ALPHA = mix(shallow_color.a, 1.0, fres);
    ROUGHNESS = 0.06;
    METALLIC = 0.0;
    SPECULAR = 0.9;
}
