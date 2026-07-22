extends Control
class_name ControllerFocusOverlay


# Light-blue controller focus theme.
# Kept visual-only: this overlay still ignores mouse input and does not change UI behavior.
const THEME_BLUE := Color(0.20, 0.74, 1.0, 0.72)
const TOP_COLOR := Color(0.20, 0.74, 1.0, 0.66)
const WIDGET_COLOR := Color(0.20, 0.82, 1.0, 0.58)
const ITEM_COLOR := Color(0.42, 0.90, 1.0, 0.78)
const POPUP_COLOR := Color(0.24, 0.78, 1.0, 0.68)
const INNER_COLOR := Color(0.82, 0.96, 1.0, 0.42)
const ACCENT_COLOR := Color(0.66, 0.92, 1.0, 0.52)
const HINT_BG_COLOR := Color(0.02, 0.05, 0.12, 0.74)
const HINT_BORDER_COLOR := Color(0.20, 0.74, 1.0, 0.76)
const HINT_TEXT_COLOR := Color(0.90, 0.97, 1.0, 0.92)
const GUIDE_BG_COLOR := Color(0.01, 0.03, 0.08, 0.20)
const GUIDE_COLOR := Color(0.20, 0.74, 1.0, 0.34)
const GUIDE_ACTIVE_COLOR := Color(0.78, 0.96, 1.0, 0.82)
const GUIDE_GLOW_COLOR := Color(0.20, 0.74, 1.0, 0.09)
# 4096 is Godot's normal CanvasItem z-index ceiling, so this keeps the overlay
# on top without relying on out-of-range values.
const TOP_LAYER_Z := 4096
const MAX_SCANLINES := 10

var controller_active := false
var popup_mode := false
var guidance_available := false
var top_rect := Rect2()
var widget_rect := Rect2()
var item_rect := Rect2()
var action_hint_text := ""
var pulse_time := 0.0
var guide_fade := 0.0
var guide_last_input_msec := 0
const GUIDE_FADE_IN_SECONDS := 0.16
const GUIDE_FADE_OUT_SECONDS := 0.42


func controller_procedural_ui_enabled() -> bool:
	return bool(Globals.get("show_controller_procedural_ui"))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	show_behind_parent = false
	z_index = TOP_LAYER_Z
	z_as_relative = false
	set_process(true)
	visible = false
	call_deferred("raise_overlay_to_front")


func _has_point(_point: Vector2) -> bool:
	return false


func raise_overlay_to_front() -> void:
	if not is_inside_tree():
		return
	top_level = true
	show_behind_parent = false
	z_index = TOP_LAYER_Z
	z_as_relative = false
	move_to_front()


func _process(delta: float) -> void:
	if not controller_procedural_ui_enabled():
		visible = false
		return

	pulse_time += delta
	update_directional_guidance_fade(delta)
	sync_to_viewport()
	if visible:
		raise_overlay_to_front()
		queue_redraw()


func sync_to_viewport() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	position = Vector2.ZERO
	size = viewport.get_visible_rect().size


func set_focus_nodes(
	top_node: Variant,
	widget_node: Variant,
	item_node: Variant,
	active: bool,
	is_popup_mode: bool = false,
	navigation_guidance_enabled: bool = false,
	controller_hint_text: String = ""
) -> void:
	controller_active = active
	popup_mode = is_popup_mode
	guidance_available = navigation_guidance_enabled
	action_hint_text = controller_hint_text.strip_edges()
	visible = controller_active and controller_procedural_ui_enabled()

	top_rect = rect_from_node(top_node, 3.0)
	widget_rect = rect_from_node(widget_node, 5.0)
	item_rect = rect_from_node(item_node, 2.0)
	queue_redraw()


func clear_focus() -> void:
	controller_active = false
	popup_mode = false
	guidance_available = false
	action_hint_text = ""
	top_rect = Rect2()
	widget_rect = Rect2()
	item_rect = Rect2()
	visible = false
	queue_redraw()


func rect_from_node(node_value: Variant, grow_amount: float) -> Rect2:
	if node_value == null:
		return Rect2()
	if not is_instance_valid(node_value):
		return Rect2()
	if not (node_value is Control):
		return Rect2()

	var node := node_value as Control
	if not node.is_visible_in_tree():
		return Rect2()

	var rect := node.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return Rect2()

	var inverse := get_global_transform_with_canvas().affine_inverse()
	var local_pos := inverse * rect.position
	var local_end := inverse * (rect.position + rect.size)
	var local_rect := Rect2(local_pos, local_end - local_pos).abs()
	return local_rect.grow(grow_amount)


func _draw() -> void:
	if not controller_procedural_ui_enabled():
		return
	if not controller_active:
		return

	var pulse_alpha := 0.90 + (sin(pulse_time * 5.0) * 0.08)
	draw_ambient_grid(pulse_alpha)

	if popup_mode:
		draw_focus_rect(widget_rect, POPUP_COLOR, 4.0, pulse_alpha, 0.08)
		draw_focus_rect(item_rect, ITEM_COLOR, 5.0, 1.0, 0.16)
		draw_action_hint()
		return

	draw_focus_rect(top_rect, TOP_COLOR, 4.0, pulse_alpha, 0.08)
	draw_focus_rect(widget_rect, WIDGET_COLOR, 3.0, pulse_alpha, 0.06)
	draw_focus_rect(item_rect, ITEM_COLOR, 5.0, 1.0, 0.16)
	draw_directional_guidance()
	draw_action_hint()


func draw_ambient_grid(pulse_alpha: float) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var background := Color(0.02, 0.04, 0.09, 0.10)
	draw_rect(Rect2(Vector2.ZERO, size), background, true)

	var frame := Color(0.14, 0.34, 0.52, 0.10)
	draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), frame, false, 1.0)

	var scan_alpha = clamp(pulse_alpha * 0.08, 0.0, 0.12)
	for index in range(MAX_SCANLINES):
		var y := (float(index) / float(max(1, MAX_SCANLINES - 1))) * size.y
		var line_color := Color(0.20, 0.56, 0.82, scan_alpha * 0.72)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), line_color, 1.0)

	var sweep_color := Color(0.20, 0.74, 1.0, 0.04 + pulse_alpha * 0.025)
	var center_y := size.y * 0.5 + sin(pulse_time * 1.2) * 24.0
	draw_line(Vector2(0.0, center_y), Vector2(size.x, center_y), sweep_color, 1.0)


func draw_focus_rect(rect: Rect2, color: Color, width: float, alpha_scale: float, fill_scale: float = 0.0) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var draw_color := color
	draw_color.a *= clamp(alpha_scale, 0.0, 1.0)
	var halo_color := color
	halo_color.a *= clamp(alpha_scale * 0.055, 0.0, 0.14)
	draw_rect(rect.grow(14.0), halo_color, false, 1.0)

	if fill_scale > 0.0:
		var fill_color := color
		fill_color.a *= clamp(fill_scale * alpha_scale * 0.55, 0.0, 0.42)
		draw_rect(rect, fill_color, true)

	draw_rect(rect, draw_color, false, width)
	draw_rect(rect.grow(2.0), Color(0.72, 0.94, 1.0, clamp(alpha_scale * 0.045, 0.0, 0.10)), false, 1.0)
	if width >= 3.0:
		var inner_rect := rect.grow(-3.0)
		if inner_rect.size.x > 0.0 and inner_rect.size.y > 0.0:
			var inner_color := INNER_COLOR
			inner_color.a *= clamp(alpha_scale, 0.0, 1.0)
			draw_rect(inner_rect, inner_color, false, 1.0)

	draw_corner_brackets(rect, draw_color, width + 1.0)
	draw_center_reticle(rect, draw_color, alpha_scale)
	draw_sweep_lines(rect, draw_color, alpha_scale)


func update_directional_guidance_fade(delta: float) -> void:
	var any_active := has_directional_input()
	if any_active and guidance_available:
		guide_last_input_msec = Time.get_ticks_msec()
		guide_fade = min(1.0, guide_fade + delta / GUIDE_FADE_IN_SECONDS)
		return

	if any_active and not guidance_available:
		guide_fade = max(0.0, guide_fade - delta / 0.12)
		return

	if guide_fade <= 0.0:
		return

	var age_seconds := float(Time.get_ticks_msec() - guide_last_input_msec) / 1000.0
	if age_seconds >= GUIDE_FADE_OUT_SECONDS:
		guide_fade = 0.0
	else:
		guide_fade = max(0.0, 1.0 - (age_seconds / GUIDE_FADE_OUT_SECONDS))


func draw_directional_guidance() -> void:
	if not controller_active:
		return
	if guide_fade <= 0.0:
		return
	if not guidance_available:
		return
	if top_rect.size.x <= 0.0 and widget_rect.size.x <= 0.0 and item_rect.size.x <= 0.0:
		return

	var alpha = clamp(guide_fade, 0.0, 1.0)
	alpha *= 0.85 if popup_mode else 1.0
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var panel_size := Vector2(200.0, 108.0)
	var panel_pos := Vector2(center.x - panel_size.x * 0.5, center.y - panel_size.y * 0.5)
	var panel_rect := Rect2(panel_pos, panel_size)
	var panel_color := GUIDE_BG_COLOR
	panel_color.a *= 0.55 * alpha
	var border_color := HINT_BORDER_COLOR
	border_color.a *= 0.85 * alpha
	draw_rect(panel_rect, panel_color, true)
	draw_rect(panel_rect, border_color, false, 1.0)
	var glow_color := GUIDE_GLOW_COLOR
	glow_color.a *= alpha
	draw_rect(panel_rect.grow(8.0), glow_color, false, 1.0)

	var font := get_theme_default_font()
	if font != null:
		var label_pos := Vector2(panel_pos.x + 10.0, panel_pos.y + 18.0)
		var label_color := HINT_TEXT_COLOR
		label_color.a *= alpha
		draw_string(font, label_pos, "D-pad / L3", HORIZONTAL_ALIGNMENT_LEFT, panel_size.x - 20.0, 12, label_color)

	var guide_center := center
	var center_radius := 8.0
	var core_color := GUIDE_COLOR
	core_color.a *= 0.85 * alpha
	draw_circle(guide_center, center_radius + 10.0, glow_color)
	draw_circle(guide_center, center_radius, core_color)
	draw_circle(guide_center, max(center_radius - 1.0, 1.0), Color(0.02, 0.06, 0.12, 0.92 * alpha))

	var directions := [
		{"name": "up", "offset": Vector2(0.0, -44.0)},
		{"name": "down", "offset": Vector2(0.0, 44.0)},
		{"name": "left", "offset": Vector2(-44.0, 0.0)},
		{"name": "right", "offset": Vector2(44.0, 0.0)},
	]

	for direction_data in directions:
		var direction_name: String = direction_data["name"]
		var offset: Vector2 = direction_data["offset"]
		var active := is_direction_active(direction_name)
		var color := GUIDE_ACTIVE_COLOR if active else GUIDE_COLOR
		color.a = (0.95 if active else 0.38) * alpha
		draw_direction_arrow(guide_center + offset, direction_name, 16.0, color)


func draw_direction_arrow(origin: Vector2, direction_name: String, length: float, color: Color) -> void:
	match direction_name:
		"up":
			draw_line(origin + Vector2(0.0, length * 0.35), origin + Vector2(0.0, -length), color, 2.0)
			draw_line(origin + Vector2(-5.0, -length + 6.0), origin, color, 2.0)
			draw_line(origin + Vector2(5.0, -length + 6.0), origin, color, 2.0)
		"down":
			draw_line(origin + Vector2(0.0, -length * 0.35), origin + Vector2(0.0, length), color, 2.0)
			draw_line(origin + Vector2(-5.0, length - 6.0), origin, color, 2.0)
			draw_line(origin + Vector2(5.0, length - 6.0), origin, color, 2.0)
		"left":
			draw_line(origin + Vector2(length * 0.35, 0.0), origin + Vector2(-length, 0.0), color, 2.0)
			draw_line(origin + Vector2(-length + 6.0, -5.0), origin, color, 2.0)
			draw_line(origin + Vector2(-length + 6.0, 5.0), origin, color, 2.0)
		"right":
			draw_line(origin + Vector2(-length * 0.35, 0.0), origin + Vector2(length, 0.0), color, 2.0)
			draw_line(origin + Vector2(length - 6.0, -5.0), origin, color, 2.0)
			draw_line(origin + Vector2(length - 6.0, 5.0), origin, color, 2.0)


func has_directional_input() -> bool:
	return Input.get_action_strength("controller_widget_nav_up") >= 0.25 or \
		Input.get_action_strength("controller_widget_nav_down") >= 0.25 or \
		Input.get_action_strength("controller_widget_nav_left") >= 0.25 or \
		Input.get_action_strength("controller_widget_nav_right") >= 0.25


func is_direction_active(direction_name: String) -> bool:
	var strength := 0.0
	match direction_name:
		"up":
			strength = Input.get_action_strength("controller_widget_nav_up")
		"down":
			strength = Input.get_action_strength("controller_widget_nav_down")
		"left":
			strength = Input.get_action_strength("controller_widget_nav_left")
		"right":
			strength = Input.get_action_strength("controller_widget_nav_right")
	return strength >= 0.25


func should_draw_action_hint() -> bool:
	return controller_active and action_hint_text != ""


func draw_action_hint() -> void:
	if not should_draw_action_hint():
		return

	var target_rect: Rect2 = item_rect
	var hint_text := action_hint_text

	if popup_mode:
		target_rect = widget_rect if widget_rect.size.x > 0.0 and widget_rect.size.y > 0.0 else item_rect
	elif item_rect.size.x > 0.0 and item_rect.size.y > 0.0:
		target_rect = item_rect
	elif widget_rect.size.x > 0.0 and widget_rect.size.y > 0.0:
		target_rect = widget_rect
	elif top_rect.size.x > 0.0 and top_rect.size.y > 0.0:
		target_rect = top_rect

	if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		return

	var panel_pos := Vector2(target_rect.position.x, target_rect.position.y - 34.0)
	var panel_size := Vector2(clamp(float(hint_text.length()) * 6.7 + 22.0, 260.0, 560.0), 28.0)
	if panel_pos.x + panel_size.x > size.x - 8.0:
		panel_pos.x = size.x - panel_size.x - 8.0
	if panel_pos.x < 8.0:
		panel_pos.x = 8.0
	if panel_pos.y < 8.0:
		panel_pos.y = target_rect.position.y + target_rect.size.y + 8.0

	var panel_rect := Rect2(panel_pos, panel_size)
	draw_rect(panel_rect, HINT_BG_COLOR, true)
	draw_rect(panel_rect, HINT_BORDER_COLOR, false, 2.0)
	var font := get_theme_default_font()
	if font != null:
		var text_pos := panel_rect.position + Vector2(10.0, 18.0)
		draw_string(font, text_pos, hint_text, HORIZONTAL_ALIGNMENT_LEFT, panel_size.x - 20.0, 11, HINT_TEXT_COLOR)


func draw_corner_brackets(rect: Rect2, color: Color, width: float) -> void:
	var corner_len = min(18.0, min(rect.size.x, rect.size.y) * 0.28)
	var inset := 2.0
	var p0 := rect.position + Vector2(inset, inset)
	var p1 := rect.position + Vector2(rect.size.x - inset, inset)
	var p2 := rect.position + Vector2(rect.size.x - inset, rect.size.y - inset)
	var p3 := rect.position + Vector2(inset, rect.size.y - inset)

	draw_line(p0, p0 + Vector2(corner_len, 0.0), color, width)
	draw_line(p0, p0 + Vector2(0.0, corner_len), color, width)
	draw_line(p1, p1 - Vector2(corner_len, 0.0), color, width)
	draw_line(p1, p1 + Vector2(0.0, corner_len), color, width)
	draw_line(p2, p2 - Vector2(corner_len, 0.0), color, width)
	draw_line(p2, p2 - Vector2(0.0, corner_len), color, width)
	draw_line(p3, p3 + Vector2(corner_len, 0.0), color, width)
	draw_line(p3, p3 - Vector2(0.0, corner_len), color, width)


func draw_center_reticle(rect: Rect2, color: Color, alpha_scale: float) -> void:
	var center := rect.position + rect.size * 0.5
	var arm_len = min(rect.size.x, rect.size.y) * 0.18
	var reticle_color := color
	reticle_color.a *= clamp(alpha_scale * 0.65, 0.0, 1.0)
	draw_line(center + Vector2(-arm_len, 0.0), center + Vector2(-arm_len * 0.35, 0.0), reticle_color, 2.0)
	draw_line(center + Vector2(arm_len, 0.0), center + Vector2(arm_len * 0.35, 0.0), reticle_color, 2.0)
	draw_line(center + Vector2(0.0, -arm_len), center + Vector2(0.0, -arm_len * 0.35), reticle_color, 2.0)
	draw_line(center + Vector2(0.0, arm_len), center + Vector2(0.0, arm_len * 0.35), reticle_color, 2.0)


func draw_sweep_lines(rect: Rect2, color: Color, alpha_scale: float) -> void:
	var center := rect.position + rect.size * 0.5
	var sweep_color := ACCENT_COLOR
	sweep_color.a *= clamp(alpha_scale * 0.12, 0.0, 0.18)
	var radius = min(rect.size.x, rect.size.y) * 0.42
	var angle_a := pulse_time * 1.4
	var angle_b := pulse_time * 1.4 + PI * 0.5
	var p_a = center + Vector2(cos(angle_a), sin(angle_a)) * radius
	var p_b = center + Vector2(cos(angle_b), sin(angle_b)) * radius
	draw_line(center, p_a, sweep_color, 1.0)
	draw_line(center, p_b, sweep_color, 1.0)
