// Panneau d'interface : rectangle arrondi net à toute distance, bordure, halo de survol.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform vec2 quad_size = vec2(1.0, 1.0);
uniform vec2 rect_size = vec2(0.9, 0.9);
uniform float radius = 0.04;
uniform float border = 0.004;
uniform vec4 fill_top : source_color = vec4(0.12, 0.11, 0.13, 0.92);
uniform vec4 fill_bottom : source_color = vec4(0.05, 0.045, 0.06, 0.9);
uniform vec4 border_color : source_color = vec4(0.85, 0.7, 0.35, 0.8);
uniform vec4 glow_color : source_color = vec4(0.95, 0.75, 0.35, 1.0);
uniform float glow = 0.0;
uniform float inner_line = 0.0;

float sd_round_rect(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * quad_size;
	p.y = -p.y;
	float d = sd_round_rect(p, rect_size * 0.5, radius);
	float aa = max(fwidth(d), 0.00001);
	float inside = 1.0 - smoothstep(-aa, aa, d);
	float t = clamp(0.5 - p.y / rect_size.y, 0.0, 1.0);
	vec4 col = mix(fill_top, fill_bottom, t);
	col.a *= inside;
	float b = 1.0 - smoothstep(-aa, aa, abs(d + border * 0.5) - border * 0.5);
	b *= border_color.a;
	col.rgb = mix(col.rgb, border_color.rgb, b);
	col.a = max(col.a, b);
	if (inner_line > 0.0) {
		float b2 = 1.0 - smoothstep(-aa, aa, abs(d + inner_line) - 0.0007);
		col.rgb = mix(col.rgb, border_color.rgb, b2 * 0.4 * inside);
	}
	float g = glow * exp(-max(d, 0.0) * 70.0) * (1.0 - inside);
	vec3 rgb = mix(col.rgb, glow_color.rgb, clamp(g / (col.a + g + 0.0001), 0.0, 1.0));
	ALBEDO = rgb;
	ALPHA = clamp(col.a + g * 0.85, 0.0, 1.0);
}
