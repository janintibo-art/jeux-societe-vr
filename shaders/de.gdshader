// Dé ivoire : le numéro de la face arrive dans COLOR.r (n / 6).
shader_type spatial;

varying float face;
uniform vec3 halo : source_color = vec3(0.0);
uniform float halo_force = 0.0;

void vertex() {
	face = COLOR.r * 6.0;
}

float pip(vec2 uv, vec2 c, float r) {
	float d = length(uv - c) - r;
	float aa = fwidth(d) + 0.002;
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	int n = int(face + 0.5);
	vec2 uv = UV;
	float m = 0.0;
	float r = 0.085;
	float a = 0.26;
	float b = 0.74;
	if (n == 1) {
		m = pip(uv, vec2(0.5), 0.13);
	} else if (n == 2) {
		m = pip(uv, vec2(a), r) + pip(uv, vec2(b), r);
	} else if (n == 3) {
		m = pip(uv, vec2(a), r) + pip(uv, vec2(0.5), r) + pip(uv, vec2(b), r);
	} else if (n == 4) {
		m = pip(uv, vec2(a, a), r) + pip(uv, vec2(b, a), r) + pip(uv, vec2(a, b), r) + pip(uv, vec2(b, b), r);
	} else if (n == 5) {
		m = pip(uv, vec2(a, a), r) + pip(uv, vec2(b, a), r) + pip(uv, vec2(0.5), r) + pip(uv, vec2(a, b), r) + pip(uv, vec2(b, b), r);
	} else {
		m = pip(uv, vec2(a, 0.22), r) + pip(uv, vec2(b, 0.22), r) + pip(uv, vec2(a, 0.5), r)
			+ pip(uv, vec2(b, 0.5), r) + pip(uv, vec2(a, 0.78), r) + pip(uv, vec2(b, 0.78), r);
	}
	float e = max(abs(uv.x - 0.5), abs(uv.y - 0.5));
	vec3 ivoire = vec3(0.95, 0.92, 0.85) * (1.0 - smoothstep(0.42, 0.5, e) * 0.25);
	vec3 point = n == 1 ? vec3(0.65, 0.05, 0.07) : vec3(0.05, 0.05, 0.07);
	ALBEDO = mix(ivoire, point, clamp(m, 0.0, 1.0));
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
	EMISSION = halo * halo_force;
}
