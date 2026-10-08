// Bois verni pour les meubles : veinage en coordonnées locales de l'objet.
shader_type spatial;

uniform vec3 couleur : source_color = vec3(0.24, 0.12, 0.06);
uniform float echelle = 7.0;
uniform float brillance = 0.35;
varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 p = lp * echelle;
	float ring = length(p.yz + vec2(sin(p.x * 0.7) * 0.6, cos(p.x * 0.4) * 0.4));
	float arg = ring * 6.0 + sin(p.x * 2.3) * 0.5;
	float fade = 1.0 - clamp(fwidth(arg) * 1.2, 0.0, 1.0);
	float g = sin(arg) * 0.5 + 0.5;
	g = mix(0.5, g, fade);
	vec3 c = couleur * (0.78 + 0.32 * g);
	ALBEDO = c;
	ROUGHNESS = brillance + 0.15 * g;
	SPECULAR = 0.6;
}
