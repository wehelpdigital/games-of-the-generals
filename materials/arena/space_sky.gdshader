// Deep Space arena sky: a blue-violet gradient, two drifting nebula colours and twinkling stars,
// all from 3D value noise (no seams). Visible below the board too, since this arena has no ground.
shader_type sky;

uniform vec4 top_color : source_color = vec4(0.06, 0.05, 0.18, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.02, 0.02, 0.07, 1.0);
uniform vec4 nebula_a : source_color = vec4(0.55, 0.3, 1.0, 1.0);
uniform vec4 nebula_b : source_color = vec4(0.1, 0.6, 1.0, 1.0);

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), u.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), u.x), u.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), u.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), u.x), u.y),
		u.z);
}

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3(p);
		p *= 2.02;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 col = mix(bottom_color.rgb, top_color.rgb, d.y * 0.5 + 0.5);
	col += nebula_a.rgb * smoothstep(0.5, 0.8, fbm3(d * 2.4 + vec3(TIME * 0.004))) * 0.55;
	col += nebula_b.rgb * smoothstep(0.55, 0.85, fbm3(d * 3.1 - 4.0)) * 0.45;
	vec3 p = d * 150.0;
	vec3 cell = floor(p);
	float h = hash3(cell);
	if (h > 0.962) {
		float s = 1.0 - smoothstep(0.04, 0.2, length(fract(p) - 0.5));
		col += vec3(0.9, 0.92, 1.0) * s * (0.55 + 0.45 * sin(TIME * 2.3 + h * 60.0));
	}
	COLOR = col;
}
