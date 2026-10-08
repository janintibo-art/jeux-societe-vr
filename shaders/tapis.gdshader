// Tapis rond oriental (UV 0..1 sur un disque).
shader_type spatial;

uniform vec3 bordeaux : source_color = vec3(0.42, 0.08, 0.11);
uniform vec3 or_c : source_color = vec3(0.72, 0.55, 0.25);
uniform vec3 nuit : source_color = vec3(0.10, 0.12, 0.24);

float h(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float band(float r, float a, float b, float aa) {
	return smoothstep(a - aa, a + aa, r) * (1.0 - smoothstep(b - aa, b + aa, r));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float aa = fwidth(r) + 0.001;
	vec3 c = bordeaux * 0.6;
	c = mix(c, or_c, band(r, 0.94, 0.965, aa));
	c = mix(c, nuit, band(r, 0.84, 0.94, aa));
	c = mix(c, or_c, band(r, 0.82, 0.84, aa));
	c = mix(c, bordeaux, band(r, 0.36, 0.82, aa));
	// Médaillons en couronne
	float k = 16.0;
	float sa = mod(a + 3.14159 / k, 6.28318 / k) - 3.14159 / k;
	vec2 m = vec2(r * cos(sa), r * sin(sa));
	float petal = length((m - vec2(0.6, 0.0)) * vec2(1.0, 3.2)) - 0.14;
	float pa = fwidth(petal) + 0.002;
	c = mix(c, or_c * 0.95, 1.0 - smoothstep(-pa, pa, petal));
	float inner = length((m - vec2(0.6, 0.0)) * vec2(1.0, 6.0)) - 0.08;
	c = mix(c, nuit, 1.0 - smoothstep(-pa, pa, inner));
	// Perles de la bordure
	float kb = 64.0;
	float sb = mod(a + 3.14159 / kb, 6.28318 / kb) - 3.14159 / kb;
	vec2 mb = vec2(r * cos(sb), r * sin(sb));
	float dot_d = length(mb - vec2(0.89, 0.0)) - 0.017;
	c = mix(c, or_c, 1.0 - smoothstep(-pa, pa, dot_d));
	// Centre
	c = mix(c, or_c, band(r, 0.33, 0.36, aa));
	c = mix(c, nuit, band(r, 0.16, 0.33, aa));
	c = mix(c, or_c, band(r, 0.0, 0.16, aa) * 0.9);
	c = mix(c, bordeaux, band(r, 0.0, 0.11, aa));
	// Laine
	float n = h(floor(UV * 900.0));
	c *= 0.9 + 0.18 * n;
	if (r > 1.0) {
		discard;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
