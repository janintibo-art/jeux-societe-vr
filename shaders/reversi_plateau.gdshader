// Surface de jeu du Reversi : drap vert, lignes de la grille 8×8, quatre repères.
shader_type spatial;

uniform vec3 drap : source_color = vec3(0.06, 0.36, 0.2);
uniform vec3 ligne : source_color = vec3(0.02, 0.1, 0.05);

float h(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 g = UV * 8.0;
	vec2 f = abs(fract(g + 0.5) - 0.5);
	float d = min(f.x, f.y);
	float w = fwidth(d) * 1.2 + 0.012;
	float l = 1.0 - smoothstep(w * 0.5, w, d);
	// Bord extérieur plus épais
	vec2 e = min(UV, 1.0 - UV) * 8.0;
	float be = 1.0 - smoothstep(0.02, 0.02 + fwidth(e.x) * 1.5, min(e.x, e.y));
	// Quatre points de repère aux intersections (2,2) (2,6) (6,2) (6,6)
	vec2 q = abs(g - 4.0);
	float pt = 1.0 - smoothstep(0.07, 0.07 + fwidth(g.x) * 1.5, length(q - vec2(2.0)));
	float n = vnoise(UV * 160.0) * 0.6 + vnoise(UV * 30.0) * 0.4;
	vec3 c = drap * (0.88 + 0.22 * n);
	c = mix(c, ligne, clamp(l + be + pt, 0.0, 1.0) * 0.85);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
