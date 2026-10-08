// Papier peint vert sombre à motifs dorés (UV exprimées en mètres via « taille »).
shader_type spatial;

uniform vec2 taille = vec2(4.0, 3.0);
uniform vec3 fond : source_color = vec3(0.10, 0.19, 0.155);
uniform vec3 motif : source_color = vec3(0.78, 0.63, 0.36);

void fragment() {
	vec2 p = UV * taille;
	p.y = -p.y;
	vec2 cell = vec2(0.45, 0.45);
	vec2 q = mod(p, cell) - cell * 0.5;
	vec2 q2 = mod(p + cell * 0.5, cell) - cell * 0.5;
	float a = atan(q.y, q.x);
	float r = length(q);
	float petal = r - (0.075 + 0.035 * cos(a * 4.0));
	float aa = fwidth(petal) + 0.0005;
	float m = 1.0 - smoothstep(-aa, aa, petal);
	float core = 1.0 - smoothstep(-aa, aa, r - 0.018);
	float ringd = abs(length(q2) - 0.05) - 0.003;
	float ring = 1.0 - smoothstep(-aa, aa, ringd);
	float stripe = step(0.85, fract(p.x / 0.15));
	vec3 c = fond * (1.0 - 0.12 * stripe);
	c = mix(c, motif, m * 0.14 + core * 0.22 + ring * 0.12);
	ALBEDO = c;
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
}
