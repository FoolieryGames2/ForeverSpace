shader_type canvas_item;

uniform vec4 core_color : source_color = vec4(0.1, 0.8, 1.0, 1.0);
uniform vec4 shimmer_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shimmer_speed = 1.4;
uniform float shimmer_strength = 0.45;
uniform float pulse_speed = 1.0;
uniform float pixel_grid = 32.0;
uniform float alpha_scale = 1.0;
uniform float black_threshold = 0.55;
uniform float shimmer_seed = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	if (tex.a < 0.05) {
		discard;
	}

	float brightness = max(max(tex.r, tex.g), tex.b);
	float black_mask = 1.0 - brightness;

	if (black_mask < black_threshold) {
		discard;
	}

	vec2 pixel_uv = floor(UV * pixel_grid);
	float noise = fract(sin(dot(pixel_uv + vec2(shimmer_seed), vec2(12.9898, 78.233))) * 43758.5453);
	float wave = sin((UV.y * 18.0) + (TIME * shimmer_speed) + noise * 2.5 + shimmer_seed);
	float shimmer = smoothstep(0.25, 1.0, wave) * shimmer_strength;
	float pulse = 0.82 + 0.18 * sin(TIME * pulse_speed + shimmer_seed);
	vec3 final_color = mix(core_color.rgb, shimmer_color.rgb, shimmer) * pulse;

	COLOR = vec4(final_color, tex.a * core_color.a * alpha_scale);
}
