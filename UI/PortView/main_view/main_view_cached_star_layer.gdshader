shader_type canvas_item;

uniform sampler2D star_texture;
uniform vec2 texture_size_px = vec2(1.0, 1.0);
uniform vec2 rect_size_px = vec2(1.0, 1.0);
uniform vec2 port_center_px = vec2(0.0, 0.0);
uniform float port_radius_px = 1.0;
uniform float edge_softness_px = 2.0;
uniform vec2 view_offset_px = vec2(0.0, 0.0);
uniform float alpha_scale = 1.0;

void fragment() {
	vec2 px = UV * rect_size_px;
	vec2 texture_size = max(texture_size_px, vec2(1.0, 1.0));
	vec2 origin_px = port_center_px - texture_size * 0.5;
	vec2 sample_px = px - origin_px - view_offset_px;
	vec2 star_uv = fract(sample_px / texture_size);
	vec4 star_color = texture(star_texture, star_uv);

	float lens_dist = distance(px, port_center_px);
	float lens_mask = 1.0 - smoothstep(
		max(port_radius_px - edge_softness_px, 0.0),
		port_radius_px + 1.0,
		lens_dist
	);

	COLOR = vec4(star_color.rgb, star_color.a * lens_mask * alpha_scale);
}
