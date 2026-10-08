// Feutre de table de jeu.
shader_type spatial;

uniform vec3 couleur : source_color = vec3(0.07, 0.30, 0.18);
varying vec3 wp;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = vnoise(wp.xz * 40.0) * 0.6 + vnoise(wp.xz * 9.0) * 0.4;
	ALBEDO = couleur * (0.85 + 0.25 * n);
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
