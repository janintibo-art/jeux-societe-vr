// Dos de carte : coins arrondis, bordure blanche, fond bordeaux à croisillons dorés.
shader_type spatial;
render_mode cull_back;

uniform vec2 taille = vec2(0.064, 0.09);
uniform vec3 fond : source_color = vec3(0.36, 0.05, 0.09);
uniform vec3 motif : source_color = vec3(0.85, 0.68, 0.38);

float sd_rr(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - 0.5) * taille;
	float d = sd_rr(p, taille * 0.5, 0.005);
	if (d > 0.0) {
		discard;
	}
	float aa = fwidth(d) + 0.0001;
	vec3 c = vec3(0.96, 0.94, 0.9);
	float dedans = 1.0 - smoothstep(-aa, aa, d + 0.0035);
	vec2 g = p * 160.0;
	float l1 = abs(fract((g.x + g.y) * 0.5) - 0.5);
	float l2 = abs(fract((g.x - g.y) * 0.5) - 0.5);
	float w = fwidth(g.x) * 0.6 + 0.04;
	float lignes = 1.0 - smoothstep(0.0, w, min(l1, l2));
	vec3 interieur = mix(fond, motif, lignes * 0.55);
	float cadre = 1.0 - smoothstep(0.0, aa, abs(d + 0.0055) - 0.0004);
	interieur = mix(interieur, motif, cadre);
	c = mix(c, interieur, dedans);
	ALBEDO = c;
	ROUGHNESS = 0.5;
	SPECULAR = 0.4;
}
