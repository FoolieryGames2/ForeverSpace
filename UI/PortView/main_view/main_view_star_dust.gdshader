shader_type canvas_item;

uniform vec4 dust_color_a : source_color = vec4(0.42, 0.68, 1.0, 1.0);
uniform vec4 dust_color_b : source_color = vec4(0.85, 0.92, 1.0, 1.0);

uniform float strength = 0.08;
uniform float density = 0.10;
uniform float speck_scale = 190.0;
uniform float twinkle_speed = 0.65;
uniform float drift_speed = 0.004;
uniform float parallax_strength = 0.020;
uniform vec2 view_offset = vec2(0.0, 0.0);
uniform vec2 drift_direction = vec2(-0.07, 0.04);
uniform float motion_strength = 0.0;
uniform float motion_speed = 0.0;
uniform float motion_streak = 0.0;

uniform vec2 rect_size = vec2(1.0, 1.0);
uniform vec2 port_center_px = vec2(0.0, 0.0);
uniform float port_radius_px = 1.0;
uniform float edge_softness_px = 18.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	vec2 center_uv = port_center_px / max(rect_size, vec2(1.0));
	vec2 radial = uv - center_uv;
	float radial_len = length(radial);
	vec2 radial_dir = radial_len > 0.0001 ? radial / radial_len : vec2(0.0, -1.0);

	vec2 drift = drift_direction * TIME * drift_speed;
	vec2 forward_drift = radial_dir * TIME * motion_speed * motion_strength;
	vec2 p = uv + drift + view_offset * parallax_strength - forward_drift;

	vec2 grid = p * speck_scale;
	vec2 cell = floor(grid);
	vec2 local = fract(grid) - vec2(0.5);

	float seed = hash(cell);

	float effective_density = clamp(mix(density, density * 0.35, motion_strength), 0.0, 0.45);
	if (seed > effective_density) {
		discard;
	}

	float size_seed = hash(cell + vec2(19.7, 4.3));
	float speck_size = mix(0.055, 0.16, size_seed);

	float d = length(local);
	float dot_value = smoothstep(speck_size, 0.0, d);
	vec2 tangent = vec2(-radial_dir.y, radial_dir.x);
	vec2 streak_space = vec2(dot(local, radial_dir), dot(local, tangent));
	float streak_len = mix(speck_size, 0.26, motion_streak);
	float streak_width = mix(speck_size, 0.032, motion_streak);
	float streak_value = smoothstep(streak_len, 0.0, abs(streak_space.x)) * smoothstep(streak_width, 0.0, abs(streak_space.y));
	float dust_value = mix(dot_value, max(dot_value, streak_value) * 0.68, motion_strength);

	vec2 px = uv * rect_size;
	float lens_dist = distance(px, port_center_px);
	float lens_mask = 1.0 - smoothstep(
		max(port_radius_px - edge_softness_px, 0.0),
		port_radius_px + 2.0,
		lens_dist
	);

	float twinkle = 0.65 + 0.35 * sin(TIME * twinkle_speed + seed * 31.415);
	vec3 color = mix(dust_color_a.rgb, dust_color_b.rgb, hash(cell + vec2(8.1, 2.4)));
	float motion_boost = mix(1.0, 0.62, motion_strength);

	COLOR = vec4(color, dust_value * strength * twinkle * lens_mask * motion_boost);
}
