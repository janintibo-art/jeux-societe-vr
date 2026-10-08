// Plateau d'Abalone : ardoise sombre au centre, cercle doré autour de chaque alvéole,
// filet doré à la limite, cadre en bois. Coordonnées locales du plateau (centre = 0).
shader_type spatial;

uniform float cell = 0.054;
uniform float limite = 4.62;
uniform vec3 bois : source_color = vec3(0.2, 0.1, 0.05);
uniform vec3 ardoise : source_color = vec3(0.075, 0.078, 0.085);
uniform vec3 or_c : source_color = vec3(0.86, 0.66, 0.33);

varying vec3 lp;
varying vec3 ln;

float h(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec2 axial_round(vec2 qr) {
	vec3 c = vec3(qr.x, qr.y, -qr.x - qr.y);
	vec3 r = round(c);
	vec3 d = abs(r - c);
	if (d.x > d.y && d.x > d.z) {
		r.x = -r.y - r.z;
	} else if (d.y > d.z) {
		r.y = -r.x - r.z;
	}
	return r.xy;
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	vec2 p = lp.xz;
	float rr = p.y / (cell * 0.8660254);
	float qq = p.x / cell - rr * 0.5;
	float hd = max(max(abs(qq), abs(rr)), abs(qq + rr));
	bool dessus = ln.y > 0.6;

	// Bois du cadre et des tranches
	float arg = length(p * 9.0 + vec2(sin(p.y * 30.0), 0.0)) * 6.0;
	float g = sin(arg) * 0.5 + 0.5;
	g = mix(0.5, g, 1.0 - clamp(fwidth(arg), 0.0, 1.0));
	vec3 c = bois * (0.8 + 0.3 * g);
	float rough = 0.35;
	float metal = 0.0;

	if (dessus && hd < limite) {
		float n = vnoise(p * 60.0) * 0.6 + vnoise(p * 14.0) * 0.4;
		c = ardoise * (0.85 + 0.3 * n);
		rough = 0.55;
		vec2 a = axial_round(vec2(qq, rr));
		if (max(max(abs(a.x), abs(a.y)), abs(a.x + a.y)) <= 4.0) {
			vec2 centre = vec2(cell * (a.x + a.y * 0.5), cell * a.y * 0.8660254);
			float d = length(p - centre);
			float aa = fwidth(d) + 0.0002;
			float anneau = 1.0 - smoothstep(0.0, aa, abs(d - 0.0168) - 0.0007);
			c = mix(c, or_c, anneau);
			metal = anneau;
			rough = mix(rough, 0.3, anneau);
		}
	}
	if (dessus) {
		// Filet doré à la frontière ardoise / bois
		float aa2 = fwidth(hd) + 0.002;
		float filet = 1.0 - smoothstep(0.0, aa2, abs(hd - limite) - 0.02);
		c = mix(c, or_c, filet);
		metal = max(metal, filet);
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.5;
}
