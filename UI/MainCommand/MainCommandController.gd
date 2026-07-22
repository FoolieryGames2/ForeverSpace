extends RefCounted
class_name MainCommandController


# ==========================================================
# MAIN COMMAND CONTROLLER
# ----------------------------------------------------------
# Pass 2 extraction from main_mode.gd.
# Owns:
# - Main command menu UI construction
# - Main command action list
# - Hotkey routing
# - Command dispatch
#
# MainMode still owns boot order and the real game systems.
# This controller only calls back into MainMode for existing behavior.
# Expected project path:
# res://UI/MainCommand/MainCommandController.gd
# ==========================================================

const MAIN_COMMAND_MENU_DOC_PATH := "res://docs_v_s1.2/Main_Mode_Sub_Menu_Keycode_Map_s1.2.md"

var owner_node = null
var gui_state = null
var inv_radar_panel = null
var map = null
var star_field = null

var menu_root: Panel = null
var menu_button: MenuButton = null
# Compatibility alias: some main_mode builds still read menu_toggle_button.
var menu_toggle_button: MenuButton = null
var action_by_id := {}


func setup(p_owner_node, p_gui_state, p_inv_radar_panel, p_map, p_star_field) -> void:
	owner_node = p_owner_node
	gui_state = p_gui_state
	inv_radar_panel = p_inv_radar_panel
	map = p_map
	star_field = p_star_field


func build_menu() -> void:
	if owner_node == null:
		return
	if menu_root != null and is_instance_valid(menu_root):
		return

	menu_root = Panel.new()
	menu_root.name = "MainCommandMenuFrame"
	menu_root.position = get_menu_position()
	menu_root.size = Vector2(Globals.port_window_widget_size.x, 54)
	menu_root.z_index = 80
	menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_root.add_theme_stylebox_override("panel", make_panel_style())

	var title_label := Label.new()
	title_label.name = "MainCommandMenuTitle"
	title_label.text = "SUB-COMMAND"
	title_label.position = Vector2(10, 4)
	title_label.size = Vector2(menu_root.size.x - 20, 14)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 10)
	title_label.add_theme_color_override("font_color", Color(0.46, 0.95, 1.0, 0.82))
	if gui_state != null and gui_state.font != null:
		title_label.add_theme_font_override("font", gui_state.font)
	menu_root.add_child(title_label)

	menu_button = MenuButton.new()
	menu_button.name = "MainCommandMenu"
	menu_button.text = "Sub Menu"
	menu_button.position = Vector2(10, 20)
	menu_button.size = Vector2(menu_root.size.x - 20, 28)
	menu_button.z_index = 1
	menu_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_button.add_theme_font_size_override("font_size", 12)
	menu_button.set_meta("controller_focus_profile", "main_command")
	menu_button.add_theme_stylebox_override(
		"normal",
		make_button_style(Color(0.035, 0.090, 0.130, 0.92), Color(0.22, 0.85, 1.0, 0.60))
	)
	menu_button.add_theme_stylebox_override(
		"hover",
		make_button_style(Color(0.045, 0.125, 0.175, 0.98), Color(0.38, 0.98, 1.0, 0.88))
	)
	menu_button.add_theme_stylebox_override(
		"pressed",
		make_button_style(Color(0.018, 0.065, 0.105, 1.0), Color(0.90, 1.0, 1.0, 0.95))
	)
	if gui_state != null and gui_state.font != null:
		menu_button.add_theme_font_override("font", gui_state.font)
	menu_toggle_button = menu_button
	menu_root.add_child(menu_button)
	owner_node.add_child(menu_root)

	register_menu_refs()
	populate_popup_actions()


func build_left_panel_command_root(panel_size: Vector2) -> Control:
	var root := Control.new()
	root.name = "main_command_left_panel_root"
	root.position = Vector2.ZERO
	root.size = panel_size
	root.custom_minimum_size = panel_size
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_label := Label.new()
	title_label.name = "main_command_left_title"
	title_label.text = "SUB-COMMAND"
	title_label.position = Vector2(14, 12)
	title_label.size = Vector2(max(panel_size.x - 28.0, 120.0), 24)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.46, 0.95, 1.0, 0.88))
	if gui_state != null and gui_state.font != null:
		title_label.add_theme_font_override("font", gui_state.font)
	root.add_child(title_label)

	var subtitle := Label.new()
	subtitle.name = "main_command_left_subtitle"
	subtitle.text = "Select a station command."
	subtitle.position = Vector2(14, 38)
	subtitle.size = Vector2(max(panel_size.x - 28.0, 120.0), 18)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color(0.70, 0.85, 0.92, 0.82))
	if gui_state != null and gui_state.font != null:
		subtitle.add_theme_font_override("font", gui_state.font)
	root.add_child(subtitle)

	var scroll := ScrollContainer.new()
	scroll.name = "main_command_left_scroll"
	scroll.position = Vector2(12, 70)
	scroll.size = Vector2(max(panel_size.x - 24.0, 120.0), max(panel_size.y - 84.0, 160.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.name = "main_command_left_rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)

	var actions := get_main_command_actions()
	for action in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_id := str(action.get("id", "")).strip_edges()
		if action_id == "" or is_debug_action_hidden(action_id):
			continue
		var button := Button.new()
		button.name = "main_command_left_" + action_id
		button.text = str(action.get("label", "Command")).to_upper()
		button.custom_minimum_size = Vector2(max(panel_size.x - 44.0, 140.0), 38)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 12)
		button.set_meta("controller_focus_profile", "main_command")
		button.add_theme_stylebox_override("normal", make_button_style(Color(0.035, 0.090, 0.130, 0.92), Color(0.22, 0.85, 1.0, 0.55)))
		button.add_theme_stylebox_override("hover", make_button_style(Color(0.045, 0.125, 0.175, 0.98), Color(0.38, 0.98, 1.0, 0.86)))
		button.add_theme_stylebox_override("pressed", make_button_style(Color(0.018, 0.065, 0.105, 1.0), Color(0.90, 1.0, 1.0, 0.95)))
		if gui_state != null and gui_state.font != null:
			button.add_theme_font_override("font", gui_state.font)
		button.pressed.connect(run_command.bind(action_id))
		rows.add_child(button)

		if gui_state != null:
			gui_state.buttons[button.name] = button

	if gui_state != null:
		gui_state.controls["main_command_left_panel_root"] = root
		gui_state.controls["main_command_left_scroll"] = scroll
		gui_state.controls["main_command_left_rows"] = rows

	return root


func is_debug_action_hidden(action_id: String) -> bool:
	var debug_actions := ["spawn_test_contact", "read_universe_tier"]
	if not debug_actions.has(action_id):
		return false
	return not Globals.debug


func register_menu_refs() -> void:
	if gui_state == null:
		return

	gui_state.controls["main_command_menu_root"] = menu_root
	gui_state.controls["main_command_menu_button"] = menu_button
	gui_state.controls["main_command_menu_toggle_button"] = menu_toggle_button
	gui_state.controls["main_command_menu"] = menu_button
	gui_state.buttons["main_command_menu"] = menu_button

	# Compatibility refs for code/debug paths that still inspect MainMode directly.
	if owner_node != null:
		owner_node.main_command_menu_root = menu_root
		owner_node.main_command_menu_button = menu_button
		owner_node.main_command_menu_action_by_id = action_by_id


func populate_popup_actions() -> void:
	if menu_button == null:
		return

	var popup := menu_button.get_popup()
	popup.clear()
	action_by_id.clear()

	var actions := get_main_command_actions()
	for i in range(actions.size()):
		var action = actions[i]
		var label := str(action.get("label", "Command"))
		var key_text := str(action.get("key", "")).strip_edges()
		if key_text != "":
			label += "  [" + key_text + "]"
		popup.add_item(label, i)
		action_by_id[i] = str(action.get("id", ""))

	var callback := Callable(self, "on_menu_id_pressed")
	if not popup.id_pressed.is_connected(callback):
		popup.id_pressed.connect(callback)


func make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.035, 0.060, 0.80)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.18, 0.76, 0.95, 0.56)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	return style


func make_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = border_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func get_menu_position() -> Vector2:
	var front_view_pos := Globals.get_port_window_widget_pos()
	return Vector2(
		front_view_pos.x,
		front_view_pos.y + Globals.port_window_widget_size.y + 8.0
	)


func get_main_command_actions() -> Array:
	# Update MAIN_COMMAND_MENU_DOC_PATH whenever this hard-coded menu or any key below changes.
	return [
		{"id": "quick_save", "label": "Quick Save", "key": "Q"},
		{"id": "battle_loadout", "label": "Battle Loadout", "key": "E"},
		{"id": "named_saves", "label": "Named Saves", "key": ""},
		{"id": "battle_near_enemy", "label": "Battle near Enemy", "key": "B"},
		{"id": "debug_orbit", "label": "Planet Orbit", "key": "O"},
		{"id": "print_intel_debug", "label": "Print Intel Debug", "key": "I"},
		{"id": "settings", "label": "Settings", "key": "0"},
		{"id": "coord_auto", "label": "Coordinate Autopilot", "key": "1"},
		{"id": "spawn_test_contact", "label": "Spawn Test Contact", "key": "Z"},
		{"id": "start_screen", "label": "Return To Start", "key": "Esc"}
	]


func on_menu_id_pressed(id: int) -> void:
	var action_id := str(action_by_id.get(id, ""))
	run_command(action_id)


func close_command_popup_for_deferred_action() -> void:
	if menu_button == null or not is_instance_valid(menu_button):
		return
	var popup := menu_button.get_popup()
	if popup == null or not is_instance_valid(popup):
		return
	if popup.visible:
		print("[QUICK_SAVE_MENU] closing submenu popup before quicksave")
		popup.hide()


func request_quick_save_after_menu_close() -> void:
	await owner_node.get_tree().process_frame
	if owner_node == null or not is_instance_valid(owner_node):
		return
	if owner_node.has_method("request_quick_save"):
		print("[QUICK_SAVE_MENU] requesting quicksave after submenu close frame")
		owner_node.request_quick_save("main_command")


func run_command_from_key(action_id: String) -> bool:
	if is_text_input_focused():
		if Globals.print_priority_2:
			print("Main command ignored while text input has focus: ", action_id)
		return false

	run_command(action_id)
	return true


func run_command(action_id: String) -> void:
	if owner_node == null:
		return

	var clean_action := action_id.strip_edges()
	if clean_action == "":
		return

	if clean_action != "start_screen" and Globals.is_popup_input_locked():
		if Globals.print_priority_2:
			print("Main command ignored while popup input is locked: ", clean_action)
		return

	match clean_action:
		"quick_save":
			if owner_node.has_method("request_quick_save"):
				close_command_popup_for_deferred_action()
				call_deferred("request_quick_save_after_menu_close")
		"battle_loadout":
			owner_node.show_battle_loadout_popup()
		"named_saves":
			owner_node.show_named_saves_popup()
		"battle_near_enemy":
			owner_node.debug_force_battle_v2_enemy_encounter()
		"debug_orbit":
			run_debug_orbit()
		"print_intel_debug":
			if owner_node.has_method("debug_print_intel_state"):
				owner_node.debug_print_intel_state()
		"settings":
			owner_node.show_settings_popup()
		"coord_auto":
			owner_node.show_coord_auto_popup()
		"toggle_live_map":
			if inv_radar_panel != null:
				inv_radar_panel.toggle_inventory_live_map()
		"toggle_port_window":
			owner_node.toggle_port_window_backdrop()
		"read_universe_tier":
			run_read_universe_tier()
		"spawn_test_contact":
			run_spawn_test_contact()
		"start_screen":
			owner_node.get_tree().change_scene_to_file("res://Scenes/Start_Screen.tscn")


func run_read_universe_tier() -> void:
	if star_field == null or map == null:
		return
	if not star_field.has_method("_get_universe_tier_index_from_sector"):
		return

	var tier = star_field._get_universe_tier_index_from_sector(map.sector_pos)
	print("uni_tier : " + str(tier))
	write_to_log("Sector tier: " + str(tier))


func run_spawn_test_contact() -> void:
	if owner_node == null or map == null:
		return
	owner_node.make_smart_guy_enemy(map.sector_pos, map.local_pos)
	write_to_log("Test contact spawned in this sector.")


func run_debug_orbit() -> void:
	if owner_node == null:
		return
	if not owner_node.has_method("request_orbit_entry"):
		write_to_log("Orbit failed: main mode has no request_orbit_entry().")
		return

	var ok := bool(owner_node.request_orbit_entry("debug_key_o"))
	if ok:
		write_to_log("Planet Orbit transition requested.")
	else:
		write_to_log("Planet Orbit transition blocked.")


func write_to_log(message: String) -> void:
	if gui_state == null:
		return
	if not gui_state.log_storage.has("log_text"):
		return
	gui_state.log_storage["log_text"].text = message


func handle_input(event) -> bool:
	if owner_node == null:
		return false
	if not (event is InputEventKey):
		return false
	if not event.pressed or event.echo:
		return false

	var handled := false

	match event.keycode:
		KEY_Q:
			handled = run_command_from_key("quick_save")
		KEY_F10:
			if OS.has_feature("editor") and owner_node.has_method("debug_toggle_saving_cover"):
				print("[SAVE_COVER_DEBUG] F10 reached MainCommandController fallback")
				owner_node.debug_toggle_saving_cover("debug_key_f10_controller")
				handled = true
		KEY_0:
			handled = run_command_from_key("settings")
		KEY_1:
			handled = run_command_from_key("coord_auto")
		KEY_E:
			handled = run_command_from_key("battle_loadout")
		KEY_B:
			handled = run_command_from_key("battle_near_enemy")
		KEY_O:
			handled = run_command_from_key("debug_orbit")
		KEY_I:
			handled = run_command_from_key("print_intel_debug")
		KEY_ESCAPE:
			run_command("start_screen")
			handled = true
		KEY_Z:
			handled = run_command_from_key("spawn_test_contact")

	if handled:
		owner_node.get_viewport().set_input_as_handled()

	return handled


func is_text_input_focused() -> bool:
	# Keep debug hotkeys from firing while the player is typing in UI text fields.
	if owner_node == null:
		return false
	var focus_owner = owner_node.get_viewport().gui_get_focus_owner()
	return focus_owner is TextEdit or focus_owner is LineEdit
