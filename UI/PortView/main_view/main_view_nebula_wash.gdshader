shader_type canvas_item;

uniform vec4 color_a : source_color = vec4(0.035, 0.095, 0.24, 1.0);
uniform vec4 color_b : source_color = vec4(0.22, 0.07, 0.34, 1.0);
uniform vec4 color_c : source_color = vec4(0.03, 0.24, 0.34, 1.0);

uniform float strength = 0.16;
uniform float cloud_scale = 2.05;
uniform float band_strength = 0.58;
uniform float drift_speed = 0.008;
uniform float breath_speed = 0.14;
uniform float parallax_strength = 0.028;
uniform vec2 view_offset = vec2(0.0, 0.0);
uniform vec2 drift_direction = vec2(0.18, -0.10);

uniform vec2 rect_size = vec2(1.0, 1.0);
uniform vec2 port_center_px = vec2(0.0, 0.0);
uniform float port_radius_px = 1.0;
uniform float edge_softness_px = 18.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash(i + vec2(0.0, 0.0));
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	float freq = 1.0;

	for (int i = 0; i < 5; i++) {
		value += noise(p * freq) * amp;
		freq *= 2.0;
		amp *= 0.5;
	}

	return value;
}

void fragment() {
	vec2 uv = UV;
	vec2 drift = drift_direction * TIME * drift_speed;
	vec2 p = uv * cloud_scale + drift + view_offset * parallax_strength;

	float cloud = fbm(p);
	float cloud_detail = fbm(p * 2.7 + vec2(4.2, -2.8));

	float diagonal = uv.x * 0.72 + uv.y * 0.42;
	float band = sin((diagonal + cloud * 0.25) * 6.28318);
	band = smoothstep(-0.18, 0.88, band) * band_strength;

	float nebula = cloud * 0.72 + cloud_detail * 0.28;
	nebula = nebula * (0.42 + band);
	nebula = smoothstep(0.48, 0.88, nebula);

	vec2 px = uv * rect_size;
	float lens_dist = distance(px, port_center_px);
	float lens_mask = 1.0 - smoothstep(
		max(port_radius_px - edge_softness_px, 0.0),
		port_radius_px + 2.0,
		lens_dist
	);

	float breath = 0.90 + 0.10 * sin(TIME * breath_speed);
	vec3 mixed_ab = mix(color_a.rgb, color_b.rgb, cloud);
	vec3 final_color = mix(mixed_ab, color_c.rgb, cloud_detail * 0.35);

	COLOR = vec4(final_color, nebula * strength * breath * lens_mask);
}
