extends RefCounted
class_name PopupRuntimeController


# PopupRuntimeController
# ------------------------------------------------------------
# Owns shared popup runtime behavior that used to live directly
# in Globals.gd. Globals keeps public wrapper functions so older
# callers can continue using Globals.show_popup(...), etc.
# ------------------------------------------------------------

var popup_input_lock_sources := {}


func sync_from_globals(global_ref) -> void:
	if global_ref == null:
		return
	if typeof(global_ref.popup_input_lock_sources) == TYPE_DICTIONARY:
		popup_input_lock_sources = global_ref.popup_input_lock_sources.duplicate(true)


func sync_to_globals(global_ref) -> void:
	if global_ref == null:
		return
	global_ref.popup_input_lock_sources = popup_input_lock_sources.duplicate(true)
	global_ref.tutorial_story_popup_active = not popup_input_lock_sources.is_empty()


func set_popup_input_lock(global_ref, source_id: String, active: bool) -> void:
	sync_from_globals(global_ref)

	var source := source_id.strip_edges()
	if source == "":
		source = "popup"

	if global_ref != null and global_ref.print_priority_1:
		print("Globals | set_popup_input_lock | source_id = " + str(source) + "\n" + str(global_ref.pan_size))

	if active:
		popup_input_lock_sources[source] = true
	else:
		popup_input_lock_sources.erase(source)

	sync_to_globals(global_ref)


func is_popup_input_locked(global_ref) -> bool:
	if global_ref == null:
		return false
	sync_from_globals(global_ref)
	global_ref.tutorial_story_popup_active = not popup_input_lock_sources.is_empty()
	return bool(global_ref.tutorial_story_popup_active)


func reset_popup_runtime(global_ref, state: WidgetsState5, hide_popup: bool = false) -> void:
	set_popup_input_lock(global_ref, "story_popup", false)
	set_popup_input_lock(global_ref, "battle_loadout_popup", false)
	set_popup_input_lock(global_ref, "named_save_popup", false)

	if state == null:
		return
	if not state.controls.has("popup_root"):
		return

	var popup = state.controls["popup_root"]
	if popup == null or not is_instance_valid(popup):
		return

	release_popup_keyboard_focus(state)

	for child in popup.get_children():
		if child is Control and str(child.name).begins_with("story_popup_window_"):
			popup.remove_child(child)
			child.queue_free()

	var scrim = popup.get_node_or_null("story_popup_focus_scrim")
	if scrim != null and is_instance_valid(scrim):
		scrim.visible = false
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for timer_name in ["story_popup_auto_close_timer", "story_popup_countdown_timer"]:
		var timer = popup.get_node_or_null(timer_name)
		if timer != null and is_instance_valid(timer):
			timer.stop()
			popup.remove_child(timer)
			timer.queue_free()

	for meta_name in [
		"active_popup_kind",
		"story_popup_space_close_enabled",
		"story_popup_on_close_fired",
		"story_popup_on_close_callable",
		"story_popup_on_close_context",
		"shared_popup_space_close_enabled",
		"shared_popup_kind",
		"active_story_popup_window_path",
		"active_story_popup_token"
	]:
		if popup.has_meta(meta_name):
			popup.remove_meta(meta_name)

	resize_popup_root(global_ref, popup)

	var panel = popup.get_node_or_null("popup_panel")
	if panel != null and is_instance_valid(panel):
		panel.visible = true
		var panel_runtime_names := [
			"story_popup_content",
			"settings_handler_root",
			"coord_auto_pilot_root",
			"battle_loadout_popup_root",
			"named_save_popup_root"
		]
		for child_name in panel_runtime_names:
			var child = panel.get_node_or_null(child_name)
			if child != null and is_instance_valid(child):
				panel.remove_child(child)
				child.queue_free()

		configure_popup_panel(global_ref, state, Vector2(475, 350))

	var popup_runtime_names := [
		"coord_auto_pilot_root",
		"battle_loadout_popup_root",
		"named_save_popup_root"
	]
	for child_name in popup_runtime_names:
		var child = popup.get_node_or_null(child_name)
		if child != null and is_instance_valid(child):
			popup.remove_child(child)
			child.queue_free()

	clear_popup_state_refs(state)

	if state.labels.has("popup_text"):
		var popup_text = state.labels["popup_text"]
		if popup_text != null and is_instance_valid(popup_text):
			popup_text.clear()
			popup_text.visible = true

	if state.labels.has("popup_title"):
		var popup_title = state.labels["popup_title"]
		if popup_title != null and is_instance_valid(popup_title):
			popup_title.text = "INFO"
			popup_title.visible = true

	if state.buttons.has("popup_close"):
		var close_btn = state.buttons["popup_close"]
		if close_btn != null and is_instance_valid(close_btn):
			close_btn.text = "CLOSE"
			close_btn.size = Vector2(100, 30)
			if panel != null and is_instance_valid(panel):
				close_btn.position = Vector2(panel.size.x - 110, panel.size.y - 40)
			close_btn.z_index = 40
			close_btn.visible = true

	if hide_popup:
		popup.visible = false


func clear_popup_state_refs(state: WidgetsState5) -> void:
	var runtime_prefixes := [
		"coord_auto_",
		"settings_",
		"battle_loadout_",
		"named_save_",
		"story_popup_",
		"event_list_popup_"
	]
	var runtime_keys := [
		"coord_auto_pilot_root",
		"settings_handler_root",
		"battle_loadout_popup_root",
		"named_save_popup_root"
	]

	clear_state_dictionary_keys(state.controls, runtime_prefixes, runtime_keys)
	clear_state_dictionary_keys(state.labels, runtime_prefixes, runtime_keys)
	clear_state_dictionary_keys(state.buttons, runtime_prefixes, runtime_keys)
	clear_state_dictionary_keys(state.color_rects, runtime_prefixes, runtime_keys)
	clear_story_popup_runtime_state_keys(state.controls)
	clear_story_popup_runtime_state_keys(state.labels)
	clear_story_popup_runtime_state_keys(state.buttons)
	clear_story_popup_runtime_state_keys(state.color_rects)


func clear_story_popup_runtime_state_keys(dict: Dictionary) -> void:
	var keys_to_remove := []
	for key in dict.keys():
		var key_text := str(key)
		if key_text.begins_with("story_popup_window_") or key_text.find("_story_popup_") >= 0:
			keys_to_remove.append(key)

	for key in keys_to_remove:
		dict.erase(key)


func clear_state_dictionary_keys(dict: Dictionary, prefixes: Array, exact_keys: Array) -> void:
	var keys_to_remove := []
	for key in dict.keys():
		var key_text := str(key)
		var should_remove := exact_keys.has(key_text)
		if not should_remove:
			for prefix in prefixes:
				if key_text.begins_with(str(prefix)):
					should_remove = true
					break
		if should_remove:
			keys_to_remove.append(key)

	for key in keys_to_remove:
		dict.erase(key)


func get_popup_overlay_size(global_ref) -> Vector2:
	if global_ref == null:
		return Vector2.ZERO
	return Vector2(float(global_ref.screen_w), float(global_ref.screen_h))


func resize_popup_root(global_ref, popup: Control) -> void:
	if popup == null or not is_instance_valid(popup):
		return
	popup.position = Vector2.ZERO
	popup.size = get_popup_overlay_size(global_ref)
	for child in popup.get_children():
		var child_name := str(child.name)
		if child is Control and (
			child_name == "popup_overlay_bg"
			or child_name == "popup_aurora_background"
			or child_name == "story_popup_focus_scrim"
		):
			child.position = Vector2.ZERO
			child.size = popup.size


func release_popup_keyboard_focus(state: WidgetsState5) -> void:
	if state == null or not state.controls.has("popup_root"):
		return
	var popup = state.controls["popup_root"]
	if popup == null or not is_instance_valid(popup):
		return
	var viewport = popup.get_viewport()
	if viewport == null:
		return
	var focused = viewport.gui_get_focus_owner()
	if focused != null and is_instance_valid(focused):
		focused.release_focus()


func set_shared_popup_space_close_enabled(state: WidgetsState5, enabled: bool, popup_kind: String = "info") -> void:
	if state == null or not state.controls.has("popup_root"):
		return
	var popup = state.controls["popup_root"]
	if popup == null or not is_instance_valid(popup):
		return

	popup.set_meta("shared_popup_space_close_enabled", enabled)
	popup.set_meta("shared_popup_kind", popup_kind if enabled else "")
	release_popup_keyboard_focus(state)


func configure_popup_panel(
	global_ref,
	state: WidgetsState5,
	panel_size: Vector2,
	accent: Color = Color(0.30, 0.92, 1.0, 0.86),
	aurora_name: String = "popup_panel_aurora_background",
	frame_name: String = "popup_panel_theme_frame"
):
	if state == null:
		return null
	if not state.controls.has("popup_root"):
		return null

	var popup = state.controls["popup_root"]
	if popup == null or not is_instance_valid(popup):
		return null

	resize_popup_root(global_ref, popup)

	var panel = popup.get_node_or_null("popup_panel")
	if panel == null or not is_instance_valid(panel):
		return null

	panel.size = panel_size
	if global_ref != null:
		global_ref.pan_size = panel.size
	panel.position = (popup.size - panel.size) / 2
	clear_popup_panel_theme_siblings(panel, aurora_name, frame_name)
	apply_popup_panel_theme(panel, panel_size, accent, aurora_name, frame_name)

	if state.labels.has("popup_title"):
		var popup_title = state.labels["popup_title"]
		if popup_title != null and is_instance_valid(popup_title):
			popup_title.position = Vector2(18, 14)
			popup_title.size = Vector2(max(panel_size.x - 136.0, 140.0), 24)
			popup_title.z_index = 30
			popup_title.visible = true

	if state.labels.has("popup_text"):
		var popup_text = state.labels["popup_text"]
		if popup_text != null and is_instance_valid(popup_text):
			popup_text.position = Vector2(18, 48)
			popup_text.size = Vector2(max(panel_size.x - 36.0, 180.0), max(panel_size.y - 104.0, 90.0))
			popup_text.z_index = 30
			popup_text.visible = true

	if state.buttons.has("popup_close"):
		var close_btn = state.buttons["popup_close"]
		if close_btn != null and is_instance_valid(close_btn):
			close_btn.text = "CLOSE"
			close_btn.size = Vector2(100, 30)
			close_btn.position = Vector2(panel_size.x - 116, panel_size.y - 42)
			close_btn.z_index = 40
			close_btn.visible = true
			if close_btn.get_parent() == panel:
				panel.move_child(close_btn, panel.get_child_count() - 1)

	return panel


func clear_popup_panel_theme_siblings(panel: Control, aurora_name: String, frame_name: String) -> void:
	# Summary: Keep one themed frame/background on a reusable popup panel when popup types swap.
	if panel == null or not is_instance_valid(panel):
		return

	for child in panel.get_children():
		if child == null or not is_instance_valid(child):
			continue
		var child_name := str(child.name)
		var is_theme_frame := child_name.ends_with("_theme_frame") or child_name == "popup_panel_theme_frame"
		var is_panel_aurora := child_name.ends_with("_aurora_background") or child_name == "popup_panel_aurora_background"
		var should_remove := false
		if is_theme_frame and child_name != frame_name:
			should_remove = true
		if is_panel_aurora and child_name != aurora_name:
			should_remove = true
		if should_remove:
			panel.remove_child(child)
			child.queue_free()


func apply_popup_panel_theme(
	panel: Control,
	panel_size: Vector2,
	accent: Color = Color(0.30, 0.92, 1.0, 0.86),
	aurora_name: String = "popup_panel_aurora_background",
	frame_name: String = "popup_panel_theme_frame"
) -> void:
	if panel == null or not is_instance_valid(panel):
		return

	panel.clip_contents = true

	if panel is ColorRect:
		var rect := panel as ColorRect
		rect.color = Color(0.018, 0.034, 0.064, 0.86)

	var aurora = panel.get_node_or_null(aurora_name)
	if aurora == null or not is_instance_valid(aurora):
		aurora = AuroraBrainBackground.new()
		aurora.name = aurora_name
		aurora.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aurora.node_count = 28
		aurora.connection_distance = 120.0
		aurora.node_radius = 2.3
		panel.add_child(aurora)
		panel.move_child(aurora, 0)

	aurora.position = Vector2.ZERO
	aurora.size = panel_size
	aurora.z_index = 0
	aurora.modulate.a = 0.72

	var frame = panel.get_node_or_null(frame_name)
	if frame == null or not is_instance_valid(frame):
		frame = Panel.new()
		frame.name = frame_name
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(frame)

	frame.position = Vector2.ZERO
	frame.size = panel_size
	frame.z_index = 12

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = accent
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 5)
	frame.add_theme_stylebox_override("panel", style)


func show_popup(global_ref, state: WidgetsState5, message: String):
	if state == null:
		return null
	if not state.controls.has("popup_root"):
		return null

	if global_ref != null and global_ref.print_priority_3:
		print("LABEL KEYS: ", state.labels.keys())

	var popup = state.controls["popup_root"]
	if popup == null or not is_instance_valid(popup):
		return null

	reset_popup_runtime(global_ref, state)

	# ==========================================================
	# POPUP AURORA BACKGROUND
	# ----------------------------------------------------------
	# Create the animated background only once.
	# Do NOT make a new one every time the popup opens.
	# ==========================================================
	if not popup.has_node("popup_aurora_background"):
		var popup_aurora := AuroraBrainBackground.new()
		popup_aurora.name = "popup_aurora_background"
		popup_aurora.position = Vector2.ZERO
		popup_aurora.size = popup.size
		popup_aurora.z_index = 0
		popup_aurora.mouse_filter = Control.MOUSE_FILTER_IGNORE

		popup.add_child(popup_aurora)
		popup.move_child(popup_aurora, 0)

	# Keep the background matched to the popup size.
	var bg = popup.get_node("popup_aurora_background")
	bg.position = Vector2.ZERO
	bg.size = popup.size
	bg.z_index = 0

	var panel = popup.get_node_or_null("popup_panel")
	if panel != null and is_instance_valid(panel):
		configure_popup_panel(global_ref, state, panel.size)

	if state.labels.has("popup_text"):
		state.labels["popup_text"].clear()
		state.labels["popup_text"].append_text(message)
		state.labels["popup_text"].visible = true
		state.labels["popup_text"].z_index = 30

	if state.controls.has("settings_handler_root"):
		var settings_root = state.controls["settings_handler_root"]
		if settings_root != null and is_instance_valid(settings_root):
			settings_root.visible = false

	popup.position = Vector2.ZERO
	popup.z_index = 999

	if popup.get_parent() != null:
		popup.get_parent().move_child(popup, popup.get_parent().get_child_count() - 1)

	set_shared_popup_space_close_enabled(state, true, "info")
	popup.visible = true
	return popup
