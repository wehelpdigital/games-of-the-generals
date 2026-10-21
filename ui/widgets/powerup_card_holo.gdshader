// Holographic foil sweeping across epic and legendary powerup cards.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 size = vec2(200.0, 280.0);
uniform float radius = 16.0;
uniform float strength = 0.35;
uniform float offset = 0.0;

void fragment() {
	vec2 px = UV * size;
	vec2 q = abs(px - size * 0.5) - (size * 0.5 - vec2(radius));
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float mask = 1.0 - smoothstep(-1.0, 1.0, d);
	float t = TIME * 0.22 + offset;
	float band = fract((UV.x * 0.8 + UV.y * 0.55) - t);
	vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (band * 1.6 + vec3(0.0, 0.33, 0.67)));
	float sheen = smoothstep(0.0, 0.18, band) * (1.0 - smoothstep(0.18, 0.42, band));
	COLOR = vec4(rainbow, (0.10 + sheen * 0.55) * strength * mask);
}
