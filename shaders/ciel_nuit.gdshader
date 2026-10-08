// Vue nocturne à travers les fenêtres : dégradé, étoiles, lune, collines.
shader_type spatial;
render_mode unshaded;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float y = 1.0 - uv.y;
	vec3 c = mix(vec3(0.20, 0.13, 0.28), vec3(0.02, 0.03, 0.09), smoothstep(0.0, 0.85, y));
	vec2 g = floor(uv * vec2(70.0, 105.0));
	float s = h(g);
	vec2 f = fract(uv * vec2(70.0, 105.0)) - 0.5;
	float star = step(0.965, s) * smoothstep(0.25, 0.0, length(f)) * smoothstep(0.25, 0.5, y);
	c += vec3(1.0, 0.97, 0.88) * star * (0.5 + 0.5 * h(g + 3.0));
	vec2 mp = vec2(0.7, 0.78);
	float md = length((uv - vec2(mp.x, 1.0 - mp.y)) * vec2(1.0, 1.5));
	c += vec3(1.0, 0.95, 0.8) * (1.0 - smoothstep(0.065, 0.07, md));
	c += vec3(0.5, 0.48, 0.42) * exp(-md * 9.0) * 0.6;
	float hill = 0.18 + sin(uv.x * 7.0) * 0.05 + sin(uv.x * 23.0) * 0.015;
	c = mix(c, vec3(0.012, 0.014, 0.03), step(y, hill));
	float hill2 = 0.1 + sin(uv.x * 11.0 + 2.0) * 0.03;
	c = mix(c, vec3(0.004, 0.005, 0.012), step(y, hill2));
	ALBEDO = c * 0.9;
}
