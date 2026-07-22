shader_type canvas_item;

uniform vec4 ripple_color : source_color = vec4(0.72, 0.36, 1.0, 1.0);

uniform int ripple_count = 0;

uniform vec2 ripple_origin_0 = vec2(-1.0, -1.0);
uniform vec2 ripple_origin_1 = vec2(-1.0, -1.0);
uniform vec2 ripple_origin_2 = vec2(-1.0, -1.0);
uniform vec2 ripple_origin_3 = vec2(-1.0, -1.0);

uniform float ripple_strength_0 = 0.0;
uniform float ripple_strength_1 = 0.0;
uniform float ripple_strength_2 = 0.0;
uniform float ripple_strength_3 = 0.0;

uniform float ripple_seed_0 = 0.0;
uniform float ripple_seed_1 = 1.0;
uniform float ripple_seed_2 = 2.0;
uniform float ripple_seed_3 = 3.0;

uniform float ring_speed = 0.38;
uniform float ring_frequency = 8.0;
uniform float ring_width = 0.045;
uniform float max_alpha = 0.18;

uniform vec2 port_center_uv = vec2(0.5, 0.5);
uniform float port_radius_uv = 0.45;
uniform float port_softness_uv = 0.018;
uniform float screen_aspect = 1.777;

float ripple_at(vec2 uv, vec2 origin, float strength, float seed) {
	if (strength <= 0.001 || origin.x < 0.0 || origin.y < 0.0) {
		return 0.0;
	}

	vec2 auv = vec2(uv.x * screen_aspect, uv.y);
	vec2 aorigin = vec2(origin.x * screen_aspect, origin.y);

	float d = distance(auv, aorigin);

	float wave = fract(d * ring_frequency - TIME * ring_speed + seed);
	float ring = 1.0 - smoothstep(0.0, ring_width, abs(wave - 0.5));
	float falloff = 1.0 - smoothstep(0.0, 0.55, d);

	return ring * falloff * strength;
}

void fragment() {
	vec2 uv = UV;

	vec2 auv = vec2(uv.x * screen_aspect, uv.y);
	vec2 acenter = vec2(port_center_uv.x * screen_aspect, port_center_uv.y);
	float port_d = distance(auv, acenter);
	float port_mask = 1.0 - smoothstep(port_radius_uv, port_radius_uv + port_softness_uv, port_d);

	float value = 0.0;

	if (ripple_count > 0) {
		value += ripple_at(uv, ripple_origin_0, ripple_strength_0, ripple_seed_0);
	}
	if (ripple_count > 1) {
		value += ripple_at(uv, ripple_origin_1, ripple_strength_1, ripple_seed_1);
	}
	if (ripple_count > 2) {
		value += ripple_at(uv, ripple_origin_2, ripple_strength_2, ripple_seed_2);
	}
	if (ripple_count > 3) {
		value += ripple_at(uv, ripple_origin_3, ripple_strength_3, ripple_seed_3);
	}

	value = clamp(value, 0.0, 1.0);
	COLOR = vec4(ripple_color.rgb, value * max_alpha * port_mask);
}
