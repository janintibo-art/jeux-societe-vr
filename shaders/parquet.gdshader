// Parquet à lames décalées, calculé en coordonnées monde (mètres).
shader_type spatial;

uniform float plank_w = 0.16;
uniform float plank_l = 1.25;
varying vec3 wp;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float row = floor(p.y / plank_w);
	float off = h(vec2(row, 3.1)) * plank_l;
	float col = floor((p.x + off) / plank_l);
	vec2 id = vec2(col, row);
	vec2 f = vec2(fract((p.x + off) / plank_l), fract(p.y / plank_w));
	float r = h(id);
	float r2 = h(id + 17.0);
	vec3 base = mix(vec3(0.28, 0.14, 0.065), vec3(0.47, 0.26, 0.12), r);
	base = mix(base, base * vec3(1.05, 0.95, 0.85), r2);

	// Veinage étiré dans le sens de la lame, atténué au loin pour éviter le scintillement.
	float arg = f.y * 9.0 + sin(f.x * 5.0 + r * 20.0) * 0.8 + r * 30.0;
	float fade = 1.0 - clamp(fwidth(arg) * 1.2, 0.0, 1.0);
	float g = sin(arg * 3.14159) * 0.5 + 0.5;
	float arg2 = f.y * 26.0 + sin(f.x * 13.0 + r2 * 9.0) * 1.5;
	float fade2 = 1.0 - clamp(fwidth(arg2) * 1.2, 0.0, 1.0);
	float g2 = sin(arg2 * 3.14159) * 0.5 + 0.5;
	base *= 0.86 + 0.14 * mix(0.5, g, fade) + 0.06 * mix(0.5, g2, fade2);

	// Joints entre les lames
	vec2 w = fwidth(f) * 1.2 + vec2(0.003 / plank_l, 0.004 / plank_w);
	float jx = smoothstep(0.0, w.x, f.x) * smoothstep(0.0, w.x, 1.0 - f.x);
	float jy = smoothstep(0.0, w.y, f.y) * smoothstep(0.0, w.y, 1.0 - f.y);
	base *= mix(0.4, 1.0, jx * jy);

	ALBEDO = base;
	ROUGHNESS = 0.38 + 0.12 * g;
	SPECULAR = 0.55;
}
