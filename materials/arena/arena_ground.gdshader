// Procedural arena ground. One shader, one pattern per arena (see ArenaLibrary "ground"):
// 0 polka dots, 1 lava, 2 grass + petals, 3 snow, 4 neon grid, 5 sand dunes, 6 seabed caustics,
// 7 candy stripes + sprinkles, 8 mossy stone tiles, 9 haunted soil + mist, 10 cloud tops.
// Unshaded with the shading baked in, so the toy look stays flat and cheap on WebGL 2.
shader_type spatial;
render_mode unshaded, cull_back;

uniform int pattern = 0;
uniform vec4 color_a : source_color = vec4(1.0, 0.85, 0.69, 1.0);
uniform vec4 color_b : source_color = vec4(1.0);
uniform vec4 color_c : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float glow_strength = 1.5;
uniform float scale = 1.0;
uniform float calm_radius = 6.8;  // Keeps busy features away from the board's edge.

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// A round dot of radius r (world units) in a jittered cell grid of size cell; returns coverage and id.
vec2 cell_dots(vec2 w, float cell, float r, float chance) {
	vec2 g = floor(w / cell);
	float h = hash(g);
	if (h > chance) {
		return vec2(0.0, h);
	}
	vec2 centre = (g + 0.25 + 0.5 * vec2(hash(g + 3.1), hash(g + 7.7))) * cell;
	float d = length(w - centre);
	return vec2(1.0 - smoothstep(r * 0.8, r, d), h);
}

void fragment() {
	vec2 w = world_xz;
	vec2 p = w * scale;
	float t = TIME;
	float calm = smoothstep(calm_radius, calm_radius + 3.0, length(w));
	vec3 col = color_a.rgb;

	if (pattern == 0) {
		vec2 q = w * 0.5;
		float d = min(length(fract(q) - 0.25), length(fract(q) - 0.75)) * 2.0;
		col = color_a.rgb * mix(0.94, 1.0, 1.0 - smoothstep(0.19, 0.23, d));
	} else if (pattern == 1) {
		float rock = fbm(p * 1.6);
		col = mix(color_a.rgb, color_b.rgb, smoothstep(0.3, 0.7, rock));
		float flow = fbm(p * 0.55 + vec2(t * 0.03, -t * 0.02));
		float crack = 1.0 - smoothstep(0.0, 0.03, abs(vnoise(p * 1.1 + 7.0) - 0.5));
		float pool = smoothstep(0.57, 0.62, flow);
		float pulse = 0.75 + 0.25 * sin(t * 1.7 + flow * 14.0);
		vec3 lava = mix(glow_color.rgb, vec3(1.0, 0.85, 0.35), smoothstep(0.62, 0.72, flow)) * glow_strength * pulse;
		float hot = max(crack * 0.85, pool) * calm;
		col = mix(col, lava, hot);
		col = mix(col, glow_color.rgb * 0.5, smoothstep(0.5, 0.57, flow) * (1.0 - pool) * calm * 0.6);
	} else if (pattern == 2) {
		col = mix(color_a.rgb, color_b.rgb, smoothstep(0.35, 0.7, fbm(p * 0.8)));
		vec2 petal = cell_dots(w, 0.7, 0.13, 0.3);
		col = mix(col, color_c.rgb, petal.x * calm);
	} else if (pattern == 3) {
		col = mix(color_a.rgb, color_b.rgb, smoothstep(0.35, 0.85, fbm(p * 0.6)) * 0.9);
		vec2 glint = cell_dots(w, 0.7, 0.05, 0.05);
		float twinkle = max(0.0, sin(t * 3.0 + glint.y * 60.0));
		col += vec3(0.6, 0.8, 1.0) * glint.x * twinkle;
	} else if (pattern == 4) {
		col = mix(color_a.rgb, color_b.rgb, fbm(p * 0.7) * 0.6);
		float puddle = smoothstep(0.6, 0.66, fbm(p * 0.35 + 4.0)) * calm;
		col = mix(col, color_b.rgb * 1.6, puddle * 0.5);
		vec2 g1 = abs(fract(w * 0.5) - 0.5);
		float line1 = 1.0 - smoothstep(0.0, 0.035, min(g1.x, g1.y));
		vec2 g2 = abs(fract(w / 6.0) - 0.5);
		float line2 = 1.0 - smoothstep(0.0, 0.012, min(g2.x, g2.y));
		float pulse = 0.7 + 0.3 * sin(t * 2.0 - length(w) * 0.6);
		col = mix(col, glow_color.rgb * glow_strength * pulse, line1 * 0.75);
		col = mix(col, color_c.rgb * glow_strength, line2);
	} else if (pattern == 5) {
		float warp = fbm(p * 0.35) * 6.0;
		float ripple = sin(w.x * 2.4 + w.y * 0.6 + warp) * 0.5 + 0.5;
		float dune = fbm(p * 0.12 + 2.0);
		col = mix(color_a.rgb, color_b.rgb, ripple * 0.35 + smoothstep(0.4, 0.75, dune) * 0.5);
	} else if (pattern == 6) {
		col = mix(color_a.rgb, color_b.rgb, smoothstep(0.35, 0.7, fbm(p * 0.9)));
		float c1 = abs(sin(w.x * 1.3 + sin(w.y * 0.9 + t * 0.8) * 1.6));
		float c2 = abs(sin(w.y * 1.2 + sin(w.x * 1.1 - t * 0.7) * 1.6));
		float caustic = (pow(1.0 - c1, 12.0) + pow(1.0 - c2, 12.0)) * (0.45 + 0.55 * calm);
		col += glow_color.rgb * glow_strength * caustic;
	} else if (pattern == 7) {
		float stripe = step(0.5, fract((w.x + w.y) * 0.18 + fbm(p * 0.2) * 0.4));
		col = mix(color_a.rgb, color_b.rgb, stripe);
		vec2 spr = cell_dots(w, 0.6, 0.075, 0.55);
		vec3 sprinkle = spr.y < 0.14 ? color_c.rgb : (spr.y < 0.28 ? glow_color.rgb : (spr.y < 0.42 ? vec3(0.45, 0.7, 1.0) : vec3(1.0)));
		col = mix(col, sprinkle, spr.x * calm);
	} else if (pattern == 8) {
		vec2 tw = w * 0.5;
		tw.x += step(1.0, mod(floor(tw.y), 2.0)) * 0.5;
		vec2 f = fract(tw);
		float grout = 1.0 - smoothstep(0.03, 0.06, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		float shade = 0.88 + 0.12 * hash(floor(tw));
		col = color_a.rgb * shade;
		col = mix(col, color_b.rgb, smoothstep(0.5, 0.68, fbm(p * 0.9)) * 0.85);
		col = mix(col, color_c.rgb, grout);
	} else if (pattern == 9) {
		col = mix(color_a.rgb, color_b.rgb, smoothstep(0.3, 0.75, fbm(p * 0.9)));
		float mist = fbm(p * 0.35 + vec2(t * 0.05, t * 0.03));
		col = mix(col, color_c.rgb, smoothstep(0.48, 0.78, mist) * 0.55);
		vec2 shroom = cell_dots(w, 1.6, 0.09, 0.08);
		col = mix(col, glow_color.rgb * glow_strength, shroom.x * calm);
	} else if (pattern == 10) {
		float puff = fbm(p * 1.0 + vec2(t * 0.01, 0.0));
		col = mix(color_b.rgb, color_a.rgb, smoothstep(0.38, 0.62, puff));
		col = mix(col, color_c.rgb, (1.0 - smoothstep(0.2, 0.3, puff)) * 0.55 * calm);
	}
	ALBEDO = col;
}
