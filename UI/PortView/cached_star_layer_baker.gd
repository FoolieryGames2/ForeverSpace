extends RefCounted


const STATIC_ALPHA_SCALE := 0.82
const EDGE_DUPLICATE_COPIES := [-1, 0, 1]


static func bake_star_layer_texture(layer: Dictionary) -> ImageTexture:
	var span = max(int(ceil(float(layer.get("span", 128.0)))), 8)
	var image := Image.create(span, span, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var color: Color = layer.get("color", Color.WHITE)
	color.a *= STATIC_ALPHA_SCALE

	for star in layer.get("stars", []):
		if typeof(star) != TYPE_DICTIONARY:
			continue
		var center: Vector2 = star.get("base", Vector2.ZERO)
		var radius = max(float(star.get("size", 1.0)), 0.35)
		draw_wrapped_star_dot(image, center, radius, color, span)

	return ImageTexture.create_from_image(image)


static func draw_wrapped_star_dot(image: Image, center: Vector2, radius: float, color: Color, span: int) -> void:
	for copy_x in EDGE_DUPLICATE_COPIES:
		for copy_y in EDGE_DUPLICATE_COPIES:
			var copy_center := center + Vector2(float(copy_x * span), float(copy_y * span))
			draw_star_dot(image, copy_center, radius, color)


static func draw_star_dot(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var soft_radius := radius + 0.85
	var min_x = max(int(floor(center.x - soft_radius)), 0)
	var min_y = max(int(floor(center.y - soft_radius)), 0)
	var max_x = min(int(ceil(center.x + soft_radius)), image.get_width() - 1)
	var max_y = min(int(ceil(center.y + soft_radius)), image.get_height() - 1)
	if max_x < min_x or max_y < min_y:
		return

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var sample_pos := Vector2(float(x) + 0.5, float(y) + 0.5)
			var distance := sample_pos.distance_to(center)
			var coverage = clamp(soft_radius - distance, 0.0, 1.0)
			if coverage <= 0.0:
				continue

			var source := color
			source.a = clamp(source.a * coverage, 0.0, 1.0)
			if source.a <= 0.0:
				continue

			blend_pixel(image, x, y, source)


static func blend_pixel(image: Image, x: int, y: int, source: Color) -> void:
	var target := image.get_pixel(x, y)
	var inverse_alpha := 1.0 - source.a
	var out_alpha := source.a + target.a * inverse_alpha
	if out_alpha <= 0.0:
		image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
		return

	image.set_pixel(
		x,
		y,
		Color(
			(source.r * source.a + target.r * target.a * inverse_alpha) / out_alpha,
			(source.g * source.a + target.g * target.a * inverse_alpha) / out_alpha,
			(source.b * source.a + target.b * target.a * inverse_alpha) / out_alpha,
			out_alpha
		)
	)
