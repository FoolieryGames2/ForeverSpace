extends RefCounted
class_name ControllerFocusVisual


const ControllerFocusControlMarkerScript = preload("res://UI/Controller/ControllerFocusControlMarker.gd")

const META_ORIGINAL_SELF_MODULATE := "_controller_focus_original_self_modulate"
const META_HAD_FOCUS_STYLE := "_controller_focus_had_focus_style"
const META_ORIGINAL_FOCUS_STYLE := "_controller_focus_original_focus_style"
const META_ORIGINAL_FONT_COLOR := "_controller_focus_original_font_color"
const META_ORIGINAL_BUTTON_STYLEBOXES := "_controller_focus_original_button_styleboxes"
const META_CONTROLLER_FOCUS_PROFILE := "controller_focus_profile"
const MARKER_NAME := "_controller_focus_control_marker"


static func controller_procedural_ui_enabled() -> bool:
	return bool(Globals.get("show_controller_procedural_ui"))


static func apply_to_control(control_value: Variant) -> void:
	if control_value == null or not is_instance_valid(control_value):
		return
	if not (control_value is Control):
		return

	var control := control_value as Control
	if not controller_procedural_ui_enabled():
		clear_from_control(control)
		control.grab_focus()
		return

	if not control.has_meta(META_ORIGINAL_SELF_MODULATE):
		control.set_meta(META_ORIGINAL_SELF_MODULATE, control.self_modulate)
	var current_modulate := control.self_modulate
	if current_modulate.a <= 0.0:
		current_modulate.a = 1.0
	control.self_modulate = Color(1.00, 1.00, 1.00, min(1.0, current_modulate.a + 0.20))

	if not control.has_meta(META_ORIGINAL_FONT_COLOR):
		var had_font_color_override := control.has_theme_color_override("font_color")
		var original_font_color = control.get_theme_color("font_color") if had_font_color_override else null
		control.set_meta(META_ORIGINAL_FONT_COLOR, {"had_override": had_font_color_override, "color": original_font_color})
	if control.has_method("add_theme_color_override"):
		control.add_theme_color_override("font_color", Color(0.98, 1.00, 1.00, 1.00))
		control.add_theme_color_override("font_hover_color", Color(0.98, 1.00, 1.00, 1.00))
		control.add_theme_color_override("font_focus_color", Color(0.98, 1.00, 1.00, 1.00))
		control.add_theme_color_override("font_pressed_color", Color(0.98, 1.00, 1.00, 1.00))

	var focus_profile := ""
	if control.has_meta(META_CONTROLLER_FOCUS_PROFILE):
		focus_profile = str(control.get_meta(META_CONTROLLER_FOCUS_PROFILE, "")).strip_edges()

	if control.has_method("has_theme_stylebox_override") and not control.has_meta(META_HAD_FOCUS_STYLE):
		var had_focus_style := control.has_theme_stylebox_override("focus")
		control.set_meta(META_HAD_FOCUS_STYLE, had_focus_style)
		if had_focus_style:
			control.set_meta(META_ORIGINAL_FOCUS_STYLE, control.get_theme_stylebox("focus"))

	if control.has_method("add_theme_stylebox_override"):
		var focus_style := make_focus_style(focus_profile)
		control.add_theme_stylebox_override("focus", focus_style)
		if control is BaseButton:
			if not control.has_meta(META_ORIGINAL_BUTTON_STYLEBOXES):
				var original_button_styleboxes := {}
				for style_name in ["normal", "hover", "pressed"]:
					if control.has_theme_stylebox_override(style_name):
						original_button_styleboxes[style_name] = control.get_theme_stylebox(style_name)
				control.set_meta(META_ORIGINAL_BUTTON_STYLEBOXES, original_button_styleboxes)
			control.add_theme_stylebox_override("normal", focus_style)
			control.add_theme_stylebox_override("hover", focus_style)
			control.add_theme_stylebox_override("pressed", focus_style)

	ensure_control_marker(control)


static func clear_from_control(control_value: Variant) -> void:
	if control_value == null or not is_instance_valid(control_value):
		return
	if not (control_value is Control):
		return

	var control := control_value as Control
	if control.has_meta(META_ORIGINAL_SELF_MODULATE):
		var original = control.get_meta(META_ORIGINAL_SELF_MODULATE)
		if typeof(original) == TYPE_COLOR:
			control.self_modulate = original
		control.remove_meta(META_ORIGINAL_SELF_MODULATE)

	if control.has_meta(META_HAD_FOCUS_STYLE):
		var had_focus_style := bool(control.get_meta(META_HAD_FOCUS_STYLE))
		if had_focus_style and control.has_meta(META_ORIGINAL_FOCUS_STYLE):
			var original_style = control.get_meta(META_ORIGINAL_FOCUS_STYLE)
			if original_style is StyleBox:
				control.add_theme_stylebox_override("focus", original_style)
		elif control.has_method("remove_theme_stylebox_override"):
			control.remove_theme_stylebox_override("focus")
		control.remove_meta(META_HAD_FOCUS_STYLE)
		if control.has_meta(META_ORIGINAL_FOCUS_STYLE):
			control.remove_meta(META_ORIGINAL_FOCUS_STYLE)

	if control.has_meta(META_ORIGINAL_BUTTON_STYLEBOXES):
		var original_button_styleboxes = control.get_meta(META_ORIGINAL_BUTTON_STYLEBOXES)
		if typeof(original_button_styleboxes) == TYPE_DICTIONARY:
			for style_name in ["normal", "hover", "pressed"]:
				var original_style = original_button_styleboxes.get(style_name, null)
				if original_style is StyleBox:
					control.add_theme_stylebox_override(style_name, original_style)
				elif control.has_method("remove_theme_stylebox_override"):
					control.remove_theme_stylebox_override(style_name)
		control.remove_meta(META_ORIGINAL_BUTTON_STYLEBOXES)

	if control.has_meta(META_ORIGINAL_FONT_COLOR):
		var original_font_data = control.get_meta(META_ORIGINAL_FONT_COLOR)
		if typeof(original_font_data) == TYPE_DICTIONARY:
			var had_override := bool(original_font_data.get("had_override", false))
			if had_override:
				var original_font_color = original_font_data.get("color", null)
				if original_font_color is Color:
					control.add_theme_color_override("font_color", original_font_color)
					control.add_theme_color_override("font_hover_color", original_font_color)
					control.add_theme_color_override("font_focus_color", original_font_color)
					control.add_theme_color_override("font_pressed_color", original_font_color)
			else:
				control.remove_theme_color_override("font_color")
				control.remove_theme_color_override("font_hover_color")
				control.remove_theme_color_override("font_focus_color")
				control.remove_theme_color_override("font_pressed_color")
		control.remove_meta(META_ORIGINAL_FONT_COLOR)

	remove_control_marker(control)


static func ensure_control_marker(control: Control) -> void:
	if not controller_procedural_ui_enabled():
		remove_control_marker(control)
		return

	var marker = control.get_node_or_null(MARKER_NAME)
	if marker == null or not is_instance_valid(marker):
		marker = ControllerFocusControlMarkerScript.new()
		marker.name = MARKER_NAME
		control.add_child(marker)

	var marker_control := marker as Control
	if marker_control == null:
		return
	marker_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	marker_control.offset_left = 0.0
	marker_control.offset_top = 0.0
	marker_control.offset_right = 0.0
	marker_control.offset_bottom = 0.0
	marker_control.position = Vector2.ZERO
	marker_control.size = control.size
	marker_control.z_index = 12000
	marker_control.z_as_relative = false
	marker_control.visible = true
	marker_control.modulate = Color(0.98, 1.00, 1.00, 1.00)
	control.move_child(marker_control, control.get_child_count() - 1)


static func remove_control_marker(control: Control) -> void:
	var marker = control.get_node_or_null(MARKER_NAME)
	if marker != null and is_instance_valid(marker):
		marker.queue_free()


static func make_focus_style(profile_key: String = "") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = true
	var profile := profile_key.to_lower()
	if profile == "battle_loadout":
		style.bg_color = Color(0.10, 0.22, 0.34, 0.74)
		style.border_color = Color(0.90, 0.96, 1.0, 1.0)
		style.border_width_top = 8
		style.border_width_bottom = 8
		style.border_width_left = 8
		style.border_width_right = 8
		style.shadow_color = Color(0.12, 0.92, 1.0, 0.92)
		style.shadow_size = 36
	elif profile == "main_command":
		style.bg_color = Color(0.08, 0.16, 0.24, 0.78)
		style.border_color = Color(0.34, 0.96, 1.0, 1.0)
		style.border_width_top = 7
		style.border_width_bottom = 7
		style.border_width_left = 7
		style.border_width_right = 7
		style.shadow_color = Color(0.14, 0.86, 1.0, 0.86)
		style.shadow_size = 30
	else:
		style.bg_color = Color(0.04, 0.15, 0.28, 0.60)
		style.border_color = Color(0.20, 0.90, 1.0, 1.0)
		style.border_width_top = 6
		style.border_width_bottom = 6
		style.border_width_left = 6
		style.border_width_right = 6
		style.shadow_color = Color(0.14, 0.80, 1.0, 0.78)
		style.shadow_size = 28
	style.border_blend = true
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_offset = Vector2(0.0, 0.0)
	style.content_margin_left = 3.0
	style.content_margin_top = 3.0
	style.content_margin_right = 3.0
	style.content_margin_bottom = 3.0
	style.anti_aliasing = true
	return style
