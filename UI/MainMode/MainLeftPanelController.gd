extends RefCounted
class_name MainLeftPanelController

const PANEL_NONE := ""
const PANEL_COMMAND := "command"
const PANEL_LOCAL_MAP := "local_map"
const PANEL_FLAT_MAP := "flat_map"
const PANEL_TIER_MAP := "tier_map"
const PANEL_INVENTORY_CRAFT := "inventory_craft"
const PANEL_LOADOUT := "loadout"
const PANEL_STORY_LOG := "story_log"

var owner_node = null
var gui_state = null
var active_panel_id := ""
var panel_roots := {}
var panel_open_callbacks := {}
var panel_close_callbacks := {}
var rail_buttons := {}

var left_panel_rect := Rect2(Vector2(20, 80), Vector2(350, 680))
var top_strip_rect := Rect2(Vector2(20, 20), Vector2(1260, 42))

var rail_root: Panel = null
var shell_root: Panel = null
var content_root: Control = null


func setup(p_owner_node, p_gui_state, config: Dictionary = {}) -> void:
	owner_node = p_owner_node
	gui_state = p_gui_state
	if config.has("left_panel_rect") and config.get("left_panel_rect") is Rect2:
		left_panel_rect = config.get("left_panel_rect")
	if config.has("top_strip_rect") and config.get("top_strip_rect") is Rect2:
		top_strip_rect = config.get("top_strip_rect")


func build_shell() -> void:
	if owner_node == null:
		return
	if shell_root != null and is_instance_valid(shell_root):
		return

	shell_root = Panel.new()
	shell_root.name = "MainLeftPanelShell"
	shell_root.position = left_panel_rect.position
	shell_root.size = left_panel_rect.size
	shell_root.visible = false
	shell_root.z_index = 120
	shell_root.mouse_filter = Control.MOUSE_FILTER_STOP
	shell_root.add_theme_stylebox_override("panel", make_panel_style())
	owner_node.add_child(shell_root)

	content_root = Control.new()
	content_root.name = "MainLeftPanelContent"
	content_root.position = Vector2.ZERO
	content_root.size = left_panel_rect.size
	content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.clip_contents = true
	shell_root.add_child(content_root)

	if gui_state != null:
		gui_state.controls["main_left_panel_shell"] = shell_root
		gui_state.controls["main_left_panel_content"] = content_root


func build_button_rail() -> void:
	if owner_node == null:
		return
	if rail_root != null and is_instance_valid(rail_root):
		return

	rail_root = Panel.new()
	rail_root.name = "MainCockpitButtonRail"
	rail_root.position = top_strip_rect.position
	rail_root.size = top_strip_rect.size
	rail_root.z_index = 130
	rail_root.mouse_filter = Control.MOUSE_FILTER_STOP
	rail_root.add_theme_stylebox_override("panel", make_panel_style())
	owner_node.add_child(rail_root)

	if gui_state != null:
		gui_state.controls["main_cockpit_button_rail"] = rail_root

	var buttons := [
		{"id": PANEL_COMMAND, "text": "SUB-COMMAND"},
		{"id": PANEL_LOCAL_MAP, "text": "LOCAL MAP"},
		{"id": PANEL_FLAT_MAP, "text": "FLAT MAP"},
		{"id": PANEL_TIER_MAP, "text": "SECTOR NAVIGATOR"},
		{"id": PANEL_INVENTORY_CRAFT, "text": "INVENTORY / CRAFT"},
		{"id": PANEL_STORY_LOG, "text": "STORY LOG"},
		{"id": PANEL_LOADOUT, "text": "LOADOUT"},
		{"id": PANEL_NONE, "text": "CLOSE"}
	]

	var gap := 8.0
	var x := 10.0
	var y := 7.0
	var h = max(top_strip_rect.size.y - 14.0, 24.0)
	var widths := [132.0, 126.0, 118.0, 156.0, 180.0, 122.0, 112.0, 92.0]

	for i in range(buttons.size()):
		var packet: Dictionary = buttons[i]
		var panel_id := str(packet.get("id", ""))
		var button := Button.new()
		button.name = "main_cockpit_button_" + ("close" if panel_id == "" else panel_id)
		button.text = str(packet.get("text", "PANEL"))
		button.position = Vector2(x, y)
		button.size = Vector2(widths[i], h)
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 11)
		button.add_theme_stylebox_override("normal", make_button_style(Color(0.035, 0.090, 0.130, 0.92), Color(0.22, 0.85, 1.0, 0.55)))
		button.add_theme_stylebox_override("hover", make_button_style(Color(0.045, 0.125, 0.175, 0.98), Color(0.38, 0.98, 1.0, 0.86)))
		button.add_theme_stylebox_override("pressed", make_button_style(Color(0.018, 0.065, 0.105, 1.0), Color(0.90, 1.0, 1.0, 0.95)))
		if gui_state != null and gui_state.font != null:
			button.add_theme_font_override("font", gui_state.font)
		rail_root.add_child(button)
		rail_buttons[panel_id] = button
		if gui_state != null:
			gui_state.buttons[button.name] = button

		if panel_id == PANEL_NONE:
			button.pressed.connect(close_active_panel)
		else:
			button.pressed.connect(open_panel.bind(panel_id))

		x += widths[i] + gap


func register_panel(panel_id: String, root: Control, open_callback: Callable = Callable(), close_callback: Callable = Callable()) -> void:
	var clean_id := panel_id.strip_edges()
	if clean_id == "" or root == null or not is_instance_valid(root):
		return

	build_shell()
	panel_roots[clean_id] = root
	if open_callback.is_valid():
		panel_open_callbacks[clean_id] = open_callback
	if close_callback.is_valid():
		panel_close_callbacks[clean_id] = close_callback

	attach_panel_root(root)
	apply_left_panel_layout(root)
	root.visible = false


func open_panel(panel_id: String) -> void:
	var clean_id := panel_id.strip_edges()
	if clean_id == "":
		close_active_panel()
		return

	if active_panel_id == clean_id:
		close_active_panel()
		return

	close_active_panel()

	if not panel_roots.has(clean_id):
		print("[LEFT_PANEL] Missing panel root: ", clean_id)
		return

	var root = panel_roots[clean_id]
	if root == null or not is_instance_valid(root):
		print("[LEFT_PANEL] Invalid panel root: ", clean_id)
		return

	build_shell()
	shell_root.visible = true
	shell_root.move_to_front()
	attach_panel_root(root)
	apply_left_panel_layout(root)
	root.visible = true
	root.move_to_front()
	active_panel_id = clean_id
	update_button_states()

	if panel_open_callbacks.has(clean_id):
		var cb: Callable = panel_open_callbacks[clean_id]
		if cb.is_valid():
			cb.call()

	if Globals.print_priority_2:
		print("[LEFT_PANEL_OPEN] panel=", clean_id)


func close_active_panel() -> void:
	if active_panel_id == "":
		if shell_root != null and is_instance_valid(shell_root):
			shell_root.visible = false
		update_button_states()
		return

	var closing_id := active_panel_id
	active_panel_id = ""

	if panel_close_callbacks.has(closing_id):
		var cb: Callable = panel_close_callbacks[closing_id]
		if cb.is_valid():
			cb.call()

	if panel_roots.has(closing_id):
		var root = panel_roots[closing_id]
		if root != null and is_instance_valid(root):
			root.visible = false

	if shell_root != null and is_instance_valid(shell_root):
		shell_root.visible = false

	update_button_states()

	if Globals.print_priority_2:
		print("[LEFT_PANEL_CLOSE] panel=", closing_id)


func hide_all_panels() -> void:
	for panel_id in panel_roots.keys():
		var root = panel_roots[panel_id]
		if root != null and is_instance_valid(root):
			root.visible = false
	active_panel_id = ""
	if shell_root != null and is_instance_valid(shell_root):
		shell_root.visible = false
	update_button_states()


func apply_left_panel_layout(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	root.position = Vector2.ZERO
	root.size = left_panel_rect.size
	root.custom_minimum_size = left_panel_rect.size
	root.z_index = 2
	if root.has_method("apply_main_left_panel_size"):
		root.apply_main_left_panel_size(left_panel_rect.size)


func is_panel_open(panel_id: String) -> bool:
	return active_panel_id == panel_id.strip_edges()


func get_active_panel_id() -> String:
	return active_panel_id


func get_controller_top_bar_items() -> Array:
	var output: Array = []
	var ordered_panel_ids := [
		PANEL_COMMAND,
		PANEL_LOCAL_MAP,
		PANEL_FLAT_MAP,
		PANEL_TIER_MAP,
		PANEL_INVENTORY_CRAFT,
		PANEL_STORY_LOG,
		PANEL_LOADOUT,
		PANEL_NONE
	]

	for panel_id in ordered_panel_ids:
		var button = rail_buttons.get(panel_id, null)
		if button == null or not is_instance_valid(button):
			continue
		if not (button is BaseButton):
			continue
		if not button.is_visible_in_tree() or button.disabled:
			continue

		var item_id := "close" if str(panel_id) == PANEL_NONE else str(panel_id)
		button.set_meta("controller_focus_id", "top:" + item_id)
		output.append({
			"item_id": "top:" + item_id,
			"panel_id": str(panel_id),
			"display_name": str(button.get("text")),
			"node": button,
			"enabled": true
		})

	return output


func attach_panel_root(root: Control) -> void:
	if content_root == null or not is_instance_valid(content_root):
		return
	if root.get_parent() == content_root:
		return
	var old_parent = root.get_parent()
	if old_parent != null:
		old_parent.remove_child(root)
	content_root.add_child(root)


func update_button_states() -> void:
	for panel_id in rail_buttons.keys():
		var button = rail_buttons[panel_id]
		if button == null or not is_instance_valid(button):
			continue
		button.disabled = false
		button.modulate = Color(0.70, 1.0, 1.0, 1.0) if panel_id != PANEL_NONE and active_panel_id == str(panel_id) else Color.WHITE


func make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.035, 0.060, 0.88)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.18, 0.76, 0.95, 0.56)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
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
