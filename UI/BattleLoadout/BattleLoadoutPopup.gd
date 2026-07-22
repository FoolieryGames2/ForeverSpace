extends Control
class_name BattleLoadoutPopup

signal save_requested(loadout_data: Dictionary)
signal cancel_requested

const SLOT_PRIMARY := "selected_primary_weapon"
const SLOT_SECONDARY := "selected_secondary_weapon"
const SLOT_SHIELD := "selected_shield"
const SLOT_CONSUMABLE := "loaded_consumable"
const SLOT_UPGRADE_1 := "equipped_upgrade_0"
const SLOT_UPGRADE_2 := "equipped_upgrade_1"
const SLOT_UPGRADE_3 := "equipped_upgrade_2"
const UPGRADE_SLOT_COUNT := 3
const UPGRADE_SLOT_ORDER := [
	SLOT_UPGRADE_1,
	SLOT_UPGRADE_2,
	SLOT_UPGRADE_3
]
const SLOT_ORDER := [
	SLOT_PRIMARY,
	SLOT_SECONDARY,
	SLOT_SHIELD,
	SLOT_CONSUMABLE,
	SLOT_UPGRADE_1,
	SLOT_UPGRADE_2,
	SLOT_UPGRADE_3
]

var inventory: Inventory5 = null
var item_handler: ItemHandler = null
var player_state: PlayerState = null
var gui_state: WidgetsState5 = null
var current_loadout: Dictionary = {}
var option_lists: Dictionary = {}
var selected_slot_key := SLOT_PRIMARY

var slot_buttons: Dictionary = {}
var lane_buttons: Dictionary = {}
var option_list: VBoxContainer = null
var status_label: Label = null
var shield_power_slider: HSlider = null
var shield_power_value_label: Label = null
var cancel_button: Button = null
var save_button: Button = null
var controller_group_highlight: Panel = null

var controller_group := "slots"
var controller_group_items: Dictionary = {}
var controller_group_selection_index: Dictionary = {}

var press_row: Button = null
var press_item_id := ""
var press_source_slot_key := ""
var press_start_msec := 0
var press_start_pos := Vector2.ZERO
var drag_active := false
var drag_just_finished := false
var drag_preview: Label = null
var drag_long_press_msec := 230
var drag_start_distance := 8.0


func controller_support_debug_enabled() -> bool:
	return bool(Globals.get("print_priority_controller_support"))


func controller_debug(tag: String, data: Variant = "") -> void:
	if not controller_support_debug_enabled():
		return
	if str(data) == "":
		print("[BATTLE_LOADOUT_CONTROLLER] ", tag)
	else:
		print("[BATTLE_LOADOUT_CONTROLLER] ", tag, " ", data)


func get_debug_control_name(value: Variant) -> String:
	if value == null or not is_instance_valid(value):
		return "null"
	if value is Node:
		return str((value as Node).name) + " @ " + str((value as Node).get_path())
	return str(value)


func is_live_control(value: Variant) -> bool:
	if value == null:
		return false
	if not is_instance_valid(value):
		return false
	return value is Control


func is_live_button(value: Variant) -> bool:
	if value == null:
		return false
	if not is_instance_valid(value):
		return false
	return value is BaseButton


func setup(refs: Dictionary) -> void:
	inventory = refs.get("inventory", null)
	item_handler = refs.get("item_handler", null)
	player_state = refs.get("player_state", null)
	gui_state = refs.get("gui_state", null)
	controller_debug("SETUP", {"inventory": get_debug_control_name(inventory), "player_state": get_debug_control_name(player_state), "gui_state": get_debug_control_name(gui_state)})


func open_from_player_state() -> void:
	current_loadout = read_player_battle_loadout()
	refresh_option_lists()
	apply_first_available_defaults_if_empty()
	build_shell()
	refresh_visuals()
	visible = true
	set_process(true)
	controller_debug("OPEN", {"size": size, "selected_slot": selected_slot_key, "group": controller_group})


func build_loadout_save_data() -> Dictionary:
	var save_data := normalize_loadout(current_loadout)

	for slot_key in [SLOT_PRIMARY, SLOT_SECONDARY, SLOT_SHIELD, SLOT_CONSUMABLE]:
		var item_id := str(save_data.get(slot_key, "")).strip_edges()
		if item_id != "" and not is_valid_item_for_slot(item_id, slot_key):
			save_data[slot_key] = ""

	save_data["equipped_upgrades"] = sanitize_equipped_upgrades(save_data.get("equipped_upgrades", []), true)

	if str(save_data.get(SLOT_CONSUMABLE, "")).strip_edges() == "":
		save_data["loaded_consumable_state"] = "none"
	else:
		save_data["loaded_consumable_state"] = "ready"

	save_data["shield_power_level"] = int(clamp(int(save_data.get("shield_power_level", 0)), 0, 4))
	save_data["default_shield_power_level"] = int(clamp(int(save_data.get("default_shield_power_level", save_data["shield_power_level"])), 0, 4))
	return save_data


func build_shell() -> void:
	cleanup_drag_state()

	for child in get_children():
		remove_child(child)
		child.queue_free()

	slot_buttons.clear()
	lane_buttons.clear()
	option_list = null
	status_label = null
	shield_power_slider = null
	shield_power_value_label = null

	mouse_filter = Control.MOUSE_FILTER_STOP
	var content_w := size.x if size.x > 0.0 else 620.0
	var content_h := size.y if size.y > 0.0 else 430.0
	var left_w := 250.0
	var gap := 20.0
	var right_x := left_w + gap
	var right_w: float = max(content_w - right_x, 260.0)

	var title := make_label("battle_loadout_title", "BATTLE LOADOUT", Vector2.ZERO, Vector2(content_w, 24), 17)
	title.add_theme_color_override("font_color", Color(0.68, 0.92, 1.0, 1.0))
	add_child(title)

	controller_group_highlight = Panel.new()
	controller_group_highlight.name = "battle_loadout_group_highlight"
	controller_group_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controller_group_highlight.z_index = 700
	controller_group_highlight.visible = false
	controller_group_highlight.add_theme_stylebox_override("panel", make_group_highlight_style())
	add_child(controller_group_highlight)

	var hint := make_label(
		"battle_loadout_hint",
		"Drag an item row onto a slot, or tap a slot then tap an item.",
		Vector2(0, 28),
		Vector2(content_w, 22),
		11
	)
	hint.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0, 0.82))
	add_child(hint)

	var slot_title := make_label("battle_loadout_slots_title", "Ship Slots", Vector2(0, 58), Vector2(left_w, 20), 13)
	add_child(slot_title)

	var slot_scroll := ScrollContainer.new()
	slot_scroll.name = "battle_loadout_slot_scroll"
	slot_scroll.position = Vector2(0, 82)
	slot_scroll.size = Vector2(left_w, max(content_h - 136.0, 210.0))
	add_child(slot_scroll)

	var slot_stack := VBoxContainer.new()
	slot_stack.name = "battle_loadout_slot_stack"
	slot_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_stack.add_theme_constant_override("separation", 5)
	slot_scroll.add_child(slot_stack)

	for slot_key in [SLOT_PRIMARY, SLOT_SECONDARY, SLOT_SHIELD, SLOT_CONSUMABLE]:
		var button := Button.new()
		button.name = "battle_loadout_slot_" + slot_key
		button.custom_minimum_size = Vector2(left_w - 14.0, 38.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.set_meta("battle_loadout_slot_key", slot_key)
		button.set_meta("controller_focus_profile", "battle_loadout")
		button.add_theme_font_size_override("font_size", 11)
		if gui_state != null and gui_state.font != null:
			button.add_theme_font_override("font", gui_state.font)
		button.pressed.connect(_on_slot_pressed.bind(slot_key))
		slot_stack.add_child(button)
		slot_buttons[slot_key] = button

	var upgrade_title := make_label("battle_loadout_upgrade_slots_title", "Upgrades", Vector2.ZERO, Vector2(left_w - 14.0, 18), 12)
	upgrade_title.custom_minimum_size = Vector2(left_w - 14.0, 18.0)
	slot_stack.add_child(upgrade_title)

	for slot_key in UPGRADE_SLOT_ORDER:
		var upgrade_button := Button.new()
		upgrade_button.name = "battle_loadout_slot_" + slot_key
		upgrade_button.custom_minimum_size = Vector2(left_w - 14.0, 34.0)
		upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		upgrade_button.mouse_filter = Control.MOUSE_FILTER_STOP
		upgrade_button.set_meta("battle_loadout_slot_key", slot_key)
		upgrade_button.set_meta("controller_focus_profile", "battle_loadout")
		upgrade_button.add_theme_font_size_override("font_size", 10)
		if gui_state != null and gui_state.font != null:
			upgrade_button.add_theme_font_override("font", gui_state.font)
		upgrade_button.pressed.connect(_on_slot_pressed.bind(slot_key))
		slot_stack.add_child(upgrade_button)
		slot_buttons[slot_key] = upgrade_button

	var shield_title := make_label("battle_loadout_shield_power_title", "Shield Power", Vector2.ZERO, Vector2(left_w - 14.0, 18), 12)
	shield_title.custom_minimum_size = Vector2(left_w - 14.0, 18.0)
	slot_stack.add_child(shield_title)

	shield_power_slider = HSlider.new()
	shield_power_slider.name = "battle_loadout_shield_power_slider"
	shield_power_slider.custom_minimum_size = Vector2(left_w - 14.0, 28.0)
	shield_power_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shield_power_slider.min_value = 0.0
	shield_power_slider.max_value = 4.0
	shield_power_slider.set_meta("controller_focus_profile", "battle_loadout")
	shield_power_slider.step = 1.0
	shield_power_slider.value_changed.connect(_on_shield_power_changed)
	slot_stack.add_child(shield_power_slider)

	shield_power_value_label = make_label(
		"battle_loadout_shield_power_value",
		"Power: 0 / 4",
		Vector2.ZERO,
		Vector2(left_w - 14.0, 18),
		11
	)
	shield_power_value_label.custom_minimum_size = Vector2(left_w - 14.0, 18.0)
	slot_stack.add_child(shield_power_value_label)

	var option_title := make_label("battle_loadout_options_title", "Owned Gear", Vector2(right_x, 58), Vector2(right_w, 20), 13)
	add_child(option_title)

	var lane_w = max((right_w - 12.0) / 4.0, 58.0)
	for i in range(SLOT_ORDER.size()):
		var slot_key = SLOT_ORDER[i]
		var lane := Button.new()
		lane.name = "battle_loadout_lane_" + slot_key
		lane.position = Vector2(right_x + float(i % 4) * (lane_w + 4.0), 84 + float(i / 4) * 32.0)
		lane.size = Vector2(lane_w, 28)
		lane.text = get_short_slot_label(slot_key)
		lane.add_theme_font_size_override("font_size", 10)
		if gui_state != null and gui_state.font != null:
			lane.add_theme_font_override("font", gui_state.font)
		lane.set_meta("controller_focus_profile", "battle_loadout")
		lane.pressed.connect(_on_slot_pressed.bind(slot_key))
		add_child(lane)
		lane_buttons[slot_key] = lane

	var scroll := ScrollContainer.new()
	scroll.name = "battle_loadout_option_scroll"
	scroll.position = Vector2(right_x, 150)
	scroll.size = Vector2(right_w, max(content_h - 210.0, 150.0))
	add_child(scroll)

	option_list = VBoxContainer.new()
	option_list.name = "battle_loadout_option_list"
	option_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	option_list.add_theme_constant_override("separation", 6)
	scroll.add_child(option_list)

	status_label = make_label(
		"battle_loadout_status",
		"",
		Vector2(0, content_h - 36),
		Vector2(content_w - 230, 28),
		11
	)
	status_label.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0, 0.86))
	add_child(status_label)

	cancel_button = Button.new()
	cancel_button.name = "battle_loadout_cancel_button"
	cancel_button.text = "CANCEL"
	cancel_button.position = Vector2(content_w - 214, content_h - 38)
	cancel_button.size = Vector2(98, 30)
	cancel_button.set_meta("controller_focus_profile", "battle_loadout")
	cancel_button.pressed.connect(_on_cancel_pressed)
	add_child(cancel_button)

	save_button = Button.new()
	save_button.name = "battle_loadout_save_button"
	save_button.text = "SAVE"
	save_button.position = Vector2(content_w - 106, content_h - 38)
	save_button.size = Vector2(106, 30)
	save_button.set_meta("controller_focus_profile", "battle_loadout")
	save_button.pressed.connect(_on_save_pressed)
	add_child(save_button)


func make_label(label_name: String, label_text: String, label_pos: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = label_text
	label.position = label_pos
	label.size = label_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	if gui_state != null and gui_state.font != null:
		label.add_theme_font_override("font", gui_state.font)
	return label


func make_group_highlight_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = Color(0.82, 0.96, 1.0, 0.98)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_blend = true
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.12, 0.82, 1.0, 0.64)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0.0, 0.0)
	style.anti_aliasing = true
	return style


func make_slot_button_style(is_selected: bool, compact: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = true
	style.bg_color = Color(0.11, 0.19, 0.30, 0.95) if is_selected else Color(0.05, 0.10, 0.15, 0.90)
	style.border_color = Color(0.72, 0.96, 1.0, 1.0) if is_selected else Color(0.24, 0.70, 0.86, 0.72)
	style.border_width_top = 2 if is_selected else 1
	style.border_width_bottom = 2 if is_selected else 1
	style.border_width_left = 2 if is_selected else 1
	style.border_width_right = 2 if is_selected else 1
	style.border_blend = true
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.shadow_color = Color(0.16, 0.90, 1.0, 0.55) if is_selected else Color(0.0, 0.0, 0.0, 0.0)
	style.shadow_size = 10 if is_selected else 0
	style.content_margin_left = 8.0 if not compact else 6.0
	style.content_margin_top = 6.0 if not compact else 4.0
	style.content_margin_right = 8.0 if not compact else 6.0
	style.content_margin_bottom = 6.0 if not compact else 4.0
	style.anti_aliasing = true
	return style


func make_option_row_style(is_empty: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = true
	style.bg_color = Color(0.06, 0.12, 0.17, 0.92) if not is_empty else Color(0.04, 0.09, 0.13, 0.90)
	style.border_color = Color(0.30, 0.75, 0.92, 0.82)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_blend = true
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	style.anti_aliasing = true
	return style


func refresh_visuals() -> void:
	if shield_power_slider != null:
		shield_power_slider.value = int(current_loadout.get("shield_power_level", 0))
	update_shield_power_label()

	for slot_key in SLOT_ORDER:
		var button = slot_buttons.get(slot_key, null)
		if button != null and is_instance_valid(button):
			button.text = get_slot_button_text(slot_key)
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)
			button.add_theme_stylebox_override("normal", make_slot_button_style(slot_key == selected_slot_key))
			button.add_theme_stylebox_override("hover", make_slot_button_style(slot_key == selected_slot_key))
			button.add_theme_stylebox_override("pressed", make_slot_button_style(slot_key == selected_slot_key))
			button.add_theme_color_override("font_color", Color(0.96, 1.0, 1.0, 1.0))
			button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
			button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))

		var lane = lane_buttons.get(slot_key, null)
		if lane != null and is_instance_valid(lane):
			lane.disabled = slot_key == selected_slot_key
			lane.add_theme_stylebox_override("normal", make_slot_button_style(slot_key == selected_slot_key, true))
			lane.add_theme_stylebox_override("hover", make_slot_button_style(slot_key == selected_slot_key, true))
			lane.add_theme_stylebox_override("pressed", make_slot_button_style(slot_key == selected_slot_key, true))
			lane.add_theme_color_override("font_color", Color(0.96, 1.0, 1.0, 1.0))
			lane.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
			lane.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))

	refresh_option_rows()
	refresh_controller_group_state()
	update_controller_group_highlight()


func refresh_option_rows() -> void:
	if option_list == null:
		return

	for child in option_list.get_children():
		child.queue_free()

	add_option_row("", selected_slot_key)

	var options = option_lists.get(selected_slot_key, [])
	for item_id in options:
		add_option_row(str(item_id), selected_slot_key)

	if options.is_empty():
		var empty_label := make_label(
			"battle_loadout_no_owned_" + selected_slot_key,
			"No owned " + get_short_slot_label(selected_slot_key).to_lower() + " options found.",
			Vector2.ZERO,
			Vector2(260, 24),
			11
		)
		empty_label.custom_minimum_size = Vector2(260, 24)
		option_list.add_child(empty_label)

	refresh_controller_group_state()
	update_controller_group_highlight()


func add_option_row(item_id: String, source_slot_key: String) -> void:
	var row := Button.new()
	row.name = "battle_loadout_option_none" if item_id == "" else "battle_loadout_option_" + item_id
	row.text = get_option_row_text(item_id, source_slot_key)
	row.custom_minimum_size = Vector2(260, 36)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_theme_font_size_override("font_size", 11)
	row.add_theme_stylebox_override("normal", make_option_row_style(item_id == ""))
	row.add_theme_stylebox_override("hover", make_option_row_style(item_id == ""))
	row.add_theme_stylebox_override("pressed", make_option_row_style(item_id == ""))
	row.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 0.98))
	row.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	row.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	if gui_state != null and gui_state.font != null:
		row.add_theme_font_override("font", gui_state.font)
	row.set_meta("battle_loadout_item_id", item_id)
	row.set_meta("battle_loadout_source_slot_key", source_slot_key)
	row.set_meta("controller_focus_profile", "battle_loadout")
	row.pressed.connect(_on_option_row_pressed.bind(row))
	row.button_down.connect(_on_option_row_button_down.bind(row))
	row.button_up.connect(_on_option_row_button_up.bind(row))
	option_list.add_child(row)


func refresh_controller_group_state() -> void:
	controller_group_items.clear()

	# Keep Battle Loadout as real panels instead of one mixed list.
	# slots  = left Ship Slots panel
	# lanes  = compact slot-lane buttons above Owned Gear
	# gear   = Owned Gear option rows
	# actions = Cancel / Save
	var slot_items: Array = []
	for slot_key in SLOT_ORDER:
		var button = slot_buttons.get(slot_key, null)
		if button != null and is_instance_valid(button):
			slot_items.append(button)
	controller_group_items["slots"] = slot_items

	var lane_items: Array = []
	for slot_key in SLOT_ORDER:
		var lane = lane_buttons.get(slot_key, null)
		if lane != null and is_instance_valid(lane):
			lane_items.append(lane)
	controller_group_items["lanes"] = lane_items

	var gear_items: Array = []
	if option_list != null:
		for child in option_list.get_children():
			if child is BaseButton:
				gear_items.append(child)
	controller_group_items["gear"] = gear_items

	var action_items: Array = []
	if cancel_button != null and is_instance_valid(cancel_button):
		action_items.append(cancel_button)
	if save_button != null and is_instance_valid(save_button):
		action_items.append(save_button)
	controller_group_items["actions"] = action_items

	if not controller_group_items.has(controller_group):
		controller_group = "slots"
	if not controller_group_selection_index.has(controller_group):
		controller_group_selection_index[controller_group] = 0

	for group_name in controller_group_items.keys():
		var items: Array = get_controller_group_items(str(group_name))
		var index := int(controller_group_selection_index.get(group_name, 0))
		if items.is_empty():
			controller_group_selection_index[group_name] = 0
		else:
			controller_group_selection_index[group_name] = clampi(index, 0, items.size() - 1)

	controller_debug("GROUPS_REFRESH", {
		"group": controller_group,
		"slots": slot_items.size(),
		"lanes": lane_items.size(),
		"gear": gear_items.size(),
		"actions": action_items.size(),
		"selected": get_debug_control_name(get_controller_navigation_selected_control())
	})


func normalize_controller_group_name(group_name: String) -> String:
	var normalized := str(group_name).strip_edges().to_lower()
	if normalized in ["ship_slots", "ship slots", "slots", "slot"]:
		return "slots"
	if normalized in ["slot_lanes", "slot lanes", "lanes", "lane", "slot_tabs", "slot tabs"]:
		return "lanes"
	if normalized in ["owned_gear", "owned gear", "gear", "items"]:
		return "gear"
	if normalized in ["actions", "action", "cancel_save", "cancel/save", "cancel-save"]:
		return "actions"
	return normalized


func get_controller_group_name() -> String:
	return controller_group


func set_controller_navigation_group(group_name: String) -> void:
	var before_group := controller_group
	controller_group = normalize_controller_group_name(group_name)
	if not controller_group_items.has(controller_group):
		controller_group = "slots"
	controller_group_selection_index[controller_group] = clampi(int(controller_group_selection_index.get(controller_group, 0)), 0, max(0, get_controller_group_items(controller_group).size() - 1))
	controller_debug("SET_GROUP", {"requested": group_name, "before": before_group, "final": controller_group, "count": get_controller_group_items(controller_group).size()})
	update_controller_group_highlight()


func get_controller_group_items(group_name: String) -> Array:
	var normalized := normalize_controller_group_name(group_name)
	var raw_items: Array = Array(controller_group_items.get(normalized, []))
	var live_items: Array = []
	for item in raw_items:
		if is_live_control(item):
			live_items.append(item)
	return live_items


func get_controller_navigation_selected_control() -> Variant:
	var items := get_controller_group_items(controller_group)
	if items.is_empty():
		return null
	var index := clampi(int(controller_group_selection_index.get(controller_group, 0)), 0, max(0, items.size() - 1))
	controller_group_selection_index[controller_group] = index
	var selected: Variant = items[index]
	if not is_live_control(selected):
		return null
	return selected


func move_controller_navigation_selection(step: int) -> void:
	var items := get_controller_group_items(controller_group)
	if items.is_empty():
		controller_debug("MOVE_BLOCKED_EMPTY", {"group": controller_group})
		return
	var before_index := clampi(int(controller_group_selection_index.get(controller_group, 0)), 0, max(0, items.size() - 1))
	var index := wrapi(before_index + step, 0, items.size())
	controller_group_selection_index[controller_group] = index
	controller_debug("MOVE", {"group": controller_group, "step": step, "before": before_index, "after": index, "selected": get_debug_control_name(get_controller_navigation_selected_control())})
	update_controller_group_highlight()


func activate_controller_navigation_selection() -> void:
	var item: Variant = get_controller_navigation_selected_control()
	controller_debug("ACTIVATE", {"group": controller_group, "selected": get_debug_control_name(item)})
	if is_live_button(item):
		(item as BaseButton).emit_signal("pressed")


func update_controller_group_highlight() -> void:
	if controller_group_highlight == null:
		return
	var selected_control: Variant = get_controller_navigation_selected_control()
	if not is_live_control(selected_control):
		controller_group_highlight.visible = false
		controller_debug("HIGHLIGHT_NONE", {"group": controller_group})
		return
	var control := selected_control as Control
	var rect: Rect2 = control.get_global_rect()
	var local_pos: Vector2 = rect.position - get_global_rect().position
	controller_group_highlight.position = local_pos - Vector2(6.0, 6.0)
	controller_group_highlight.size = rect.size + Vector2(12.0, 12.0)
	controller_group_highlight.visible = true


func get_slot_button_text(slot_key: String) -> String:
	var item_id := get_current_slot_item_id(slot_key)
	return get_long_slot_label(slot_key) + "\n" + get_item_display_name_for_slot(item_id, slot_key)


func get_option_row_text(item_id: String, slot_key: String) -> String:
	if item_id == "":
		return "Empty slot"

	var item_data := get_item_data(item_id)
	var display_name := get_item_display_name(item_id, item_data)
	var count := get_owned_count(item_id)
	var detail := get_item_detail_text(item_data, slot_key)
	var count_text := "x" + str(count) + "  " if count > 1 else ""
	if detail == "":
		return count_text + display_name
	return count_text + display_name + "  |  " + detail


func get_item_detail_text(item_data: Dictionary, slot_key: String) -> String:
	if item_data.is_empty():
		return ""

	match slot_key:
		SLOT_PRIMARY, SLOT_SECONDARY:
			var damage := float(item_data.get("damage_value", item_data.get("damage", 0.0)))
			var damage_type := str(item_data.get("damage_type", "damage"))
			return str(int(damage)) + " " + damage_type
		SLOT_SHIELD:
			var hp := float(item_data.get("shield_hp_max", item_data.get("hp_max", 0.0)))
			return str(int(hp)) + " shield"
		SLOT_CONSUMABLE:
			return str(item_data.get("consumable_group", item_data.get("group", "consumable")))
		SLOT_UPGRADE_1, SLOT_UPGRADE_2, SLOT_UPGRADE_3:
			return get_upgrade_detail_text(item_data)

	return ""


func refresh_option_lists() -> void:
	option_lists.clear()
	for slot_key in SLOT_ORDER:
		option_lists[slot_key] = []

	if inventory == null or item_handler == null:
		return

	var item_db = item_handler.get("item_db")
	if typeof(item_db) != TYPE_DICTIONARY:
		return

	for raw_item_id in item_db.keys():
		var item_id := str(raw_item_id).strip_edges()
		if item_id == "":
			continue
		if not is_owned_item(item_id):
			continue

		var item_data := get_item_data(item_id)
		for slot_key in SLOT_ORDER:
			if item_matches_slot(item_data, slot_key):
				option_lists[slot_key].append(item_id)


func apply_first_available_defaults_if_empty() -> void:
	if not is_loadout_empty(current_loadout):
		return

	for slot_key in [SLOT_PRIMARY, SLOT_SECONDARY, SLOT_SHIELD]:
		var options = option_lists.get(slot_key, [])
		if not options.is_empty():
			current_loadout[slot_key] = str(options[0])

	if str(current_loadout.get(SLOT_SHIELD, "")).strip_edges() != "" and int(current_loadout.get("shield_power_level", 0)) <= 0:
		current_loadout["shield_power_level"] = 2
		current_loadout["default_shield_power_level"] = 2


func is_loadout_empty(data: Dictionary) -> bool:
	for slot_key in [SLOT_PRIMARY, SLOT_SECONDARY, SLOT_SHIELD, SLOT_CONSUMABLE]:
		if str(data.get(slot_key, "")).strip_edges() != "":
			return false
	var upgrades = data.get("equipped_upgrades", [])
	if typeof(upgrades) == TYPE_ARRAY and not upgrades.is_empty():
		return false
	return true


func read_player_battle_loadout() -> Dictionary:
	var data := {}

	if player_state != null:
		if player_state.has_method("get_battle_loadout_save_data"):
			data = player_state.get_battle_loadout_save_data()
		elif player_state.has_method("get_save_data"):
			var save_data = player_state.get_save_data()
			if typeof(save_data) == TYPE_DICTIONARY:
				data = save_data.get("battle_loadout", save_data)

	return normalize_loadout(data)


func normalize_loadout(data: Dictionary) -> Dictionary:
	var normalized := {
		"selected_primary_weapon": "",
		"selected_secondary_weapon": "",
		"selected_shield": "",
		"loaded_consumable": "",
		"loaded_consumable_state": "none",
		"equipped_upgrades": [],
		"shield_power_level": 0,
		"default_shield_power_level": 2
	}

	if typeof(data) != TYPE_DICTIONARY:
		return normalized

	for slot_key in SLOT_ORDER:
		if not is_upgrade_slot_key(slot_key):
			normalized[slot_key] = get_loadout_item_id(data.get(slot_key, ""))

	normalized["equipped_upgrades"] = sanitize_equipped_upgrades(data.get("equipped_upgrades", []), item_handler != null)

	var consumable_state := str(data.get("loaded_consumable_state", "none")).strip_edges().to_lower()
	if str(normalized[SLOT_CONSUMABLE]).strip_edges() == "":
		consumable_state = "none"
	elif consumable_state == "" or consumable_state == "none":
		consumable_state = "ready"

	normalized["loaded_consumable_state"] = consumable_state
	normalized["shield_power_level"] = int(clamp(int(data.get("shield_power_level", 0)), 0, 4))
	normalized["default_shield_power_level"] = int(clamp(int(data.get("default_shield_power_level", normalized["shield_power_level"])), 0, 4))
	return normalized


func get_loadout_item_id(value: Variant) -> String:
	if value == null:
		return ""

	if typeof(value) == TYPE_DICTIONARY:
		var packet: Dictionary = value as Dictionary
		return str(packet.get("item_id", packet.get("id", ""))).strip_edges()

	var text := str(value).strip_edges()
	if text == "" or text == "<null>" or text.to_lower() == "null":
		return ""
	return text


func is_upgrade_slot_key(slot_key: String) -> bool:
	return UPGRADE_SLOT_ORDER.has(slot_key)


func get_upgrade_slot_index(slot_key: String) -> int:
	for i in range(UPGRADE_SLOT_ORDER.size()):
		if str(UPGRADE_SLOT_ORDER[i]) == slot_key:
			return i
	return -1


func get_current_slot_item_id(slot_key: String) -> String:
	if is_upgrade_slot_key(slot_key):
		var index := get_upgrade_slot_index(slot_key)
		var upgrades = current_loadout.get("equipped_upgrades", [])
		if typeof(upgrades) == TYPE_ARRAY and index >= 0 and upgrades.size() > index:
			return get_loadout_item_id(upgrades[index])
		return ""
	return get_loadout_item_id(current_loadout.get(slot_key, ""))


func set_current_slot_item_id(slot_key: String, item_id: String) -> void:
	if is_upgrade_slot_key(slot_key):
		var index := get_upgrade_slot_index(slot_key)
		if index < 0:
			return

		var upgrades: Array = []
		var existing = current_loadout.get("equipped_upgrades", [])
		if typeof(existing) == TYPE_ARRAY:
			upgrades = existing.duplicate(true)
		while upgrades.size() < UPGRADE_SLOT_COUNT:
			upgrades.append("")
		upgrades[index] = item_id.strip_edges()
		var stable_upgrades: Array = []
		var seen: Array = []
		for i in range(UPGRADE_SLOT_COUNT):
			var upgrade_id := get_loadout_item_id(upgrades[i])
			if upgrade_id != "" and is_upgrade_item_id(upgrade_id) and not seen.has(upgrade_id):
				stable_upgrades.append(upgrade_id)
				seen.append(upgrade_id)
			else:
				stable_upgrades.append("")
		current_loadout["equipped_upgrades"] = stable_upgrades
		return

	current_loadout[slot_key] = item_id


func sanitize_equipped_upgrades(value, require_owned: bool = false) -> Array:
	var clean: Array = []
	if typeof(value) != TYPE_ARRAY:
		return clean

	for raw_id in value:
		var upgrade_id := get_loadout_item_id(raw_id)
		if upgrade_id == "":
			continue
		if clean.has(upgrade_id):
			continue
		if require_owned and not is_valid_item_for_slot(upgrade_id, SLOT_UPGRADE_1):
			continue
		elif not require_owned and not is_upgrade_item_id(upgrade_id):
			continue
		clean.append(upgrade_id)
		if clean.size() >= UPGRADE_SLOT_COUNT:
			break

	return clean


func is_upgrade_item_id(item_id: String) -> bool:
	var clean_id := item_id.strip_edges()
	if clean_id == "":
		return false
	var item_data := get_item_data(clean_id)
	if item_data.is_empty():
		return item_handler == null
	return str(item_data.get("item_type", item_data.get("type", ""))).strip_edges().to_lower() == "upgrade"


func _on_slot_pressed(slot_key: String) -> void:
	selected_slot_key = slot_key
	refresh_visuals()


func _on_option_row_pressed(row: Button) -> void:
	if drag_active or drag_just_finished:
		drag_just_finished = false
		return

	var item_id := str(row.get_meta("battle_loadout_item_id", ""))
	assign_item_to_slot(selected_slot_key, item_id)


func _on_option_row_button_down(row: Button) -> void:
	var item_id := str(row.get_meta("battle_loadout_item_id", ""))
	if item_id == "":
		return

	press_row = row
	press_item_id = item_id
	press_source_slot_key = str(row.get_meta("battle_loadout_source_slot_key", selected_slot_key))
	press_start_msec = Time.get_ticks_msec()
	press_start_pos = get_viewport().get_mouse_position()


func _on_option_row_button_up(_row: Button) -> void:
	if drag_active:
		finish_drag_at_mouse()
	else:
		clear_press_tracking()


func _process(_delta: float) -> void:
	if not visible:
		return

	update_drag_from_motion()

	if drag_active:
		update_drag_preview_position()


func update_drag_from_motion() -> void:
	if press_row == null or drag_active:
		return

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		clear_press_tracking()
		return

	var elapsed := Time.get_ticks_msec() - press_start_msec
	var moved := press_start_pos.distance_to(get_viewport().get_mouse_position())
	if elapsed >= drag_long_press_msec and moved >= drag_start_distance:
		start_drag()


func start_drag() -> void:
	if press_row == null:
		return

	drag_active = true
	press_row.modulate = Color(1, 1, 1, 0.45)

	drag_preview = Label.new()
	drag_preview.name = "battle_loadout_drag_preview"
	drag_preview.text = get_item_display_name(press_item_id, get_item_data(press_item_id))
	drag_preview.size = Vector2(220, 26)
	drag_preview.add_theme_font_size_override("font_size", 12)
	drag_preview.add_theme_color_override("font_color", Color(0.72, 0.95, 1.0, 1.0))
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.z_index = 1000

	var scene := get_tree().current_scene
	if scene != null:
		scene.add_child(drag_preview)
	else:
		add_child(drag_preview)

	update_drag_preview_position()


func update_drag_preview_position() -> void:
	if drag_preview == null:
		return
	drag_preview.position = get_viewport().get_mouse_position() + Vector2(14, 10)


func finish_drag_at_mouse() -> void:
	var target_slot_key := find_loadout_slot_key_from_control(get_viewport().gui_get_hovered_control())
	if target_slot_key != "":
		assign_item_to_slot(target_slot_key, press_item_id)
	else:
		set_status("Drop onto a ship slot to equip.")

	cleanup_drag_state()
	drag_just_finished = true
	call_deferred("_reset_drag_just_finished")


func find_loadout_slot_key_from_control(control: Control) -> String:
	var node: Node = control
	while node != null:
		if node.has_meta("battle_loadout_slot_key"):
			return str(node.get_meta("battle_loadout_slot_key", ""))
		node = node.get_parent()
	return ""


func cleanup_drag_state() -> void:
	if press_row != null and is_instance_valid(press_row):
		press_row.modulate = Color(1, 1, 1, 1)

	if drag_preview != null and is_instance_valid(drag_preview):
		drag_preview.queue_free()
		drag_preview = null

	drag_active = false
	clear_press_tracking()


func clear_press_tracking() -> void:
	press_row = null
	press_item_id = ""
	press_source_slot_key = ""
	press_start_msec = 0
	press_start_pos = Vector2.ZERO


func _reset_drag_just_finished() -> void:
	drag_just_finished = false


func assign_item_to_slot(slot_key: String, item_id: String) -> void:
	if not SLOT_ORDER.has(slot_key):
		return

	if item_id != "" and not is_valid_item_for_slot(item_id, slot_key):
		set_status("That item does not fit the " + get_short_slot_label(slot_key).to_lower() + " slot.")
		return
	if item_id != "" and is_upgrade_slot_key(slot_key) and is_upgrade_already_equipped_elsewhere(item_id, slot_key):
		set_status("That upgrade is already equipped.")
		return

	set_current_slot_item_id(slot_key, item_id)
	selected_slot_key = slot_key

	if slot_key == SLOT_CONSUMABLE:
		current_loadout["loaded_consumable_state"] = "ready" if item_id != "" else "none"

	if slot_key == SLOT_SHIELD and item_id != "" and int(current_loadout.get("shield_power_level", 0)) <= 0:
		current_loadout["shield_power_level"] = 2
		current_loadout["default_shield_power_level"] = 2

	if item_id == "":
		set_status(get_short_slot_label(slot_key) + " cleared.")
	else:
		set_status(get_short_slot_label(slot_key) + " set to " + get_item_display_name(item_id, get_item_data(item_id)) + ".")

	refresh_visuals()


func is_upgrade_already_equipped_elsewhere(item_id: String, slot_key: String) -> bool:
	var clean_id := item_id.strip_edges()
	if clean_id == "":
		return false
	var target_index := get_upgrade_slot_index(slot_key)
	var upgrades = current_loadout.get("equipped_upgrades", [])
	if typeof(upgrades) != TYPE_ARRAY:
		return false
	for i in range(upgrades.size()):
		if i == target_index:
			continue
		if get_loadout_item_id(upgrades[i]) == clean_id:
			return true
	return false


func _on_shield_power_changed(value: float) -> void:
	var level := int(clamp(int(value), 0, 4))
	current_loadout["shield_power_level"] = level
	current_loadout["default_shield_power_level"] = level
	update_shield_power_label()


func update_shield_power_label() -> void:
	if shield_power_value_label == null:
		return
	var level := int(current_loadout.get("shield_power_level", 0))
	shield_power_value_label.text = "Power: " + str(level) + " / 4  (" + str(level * 25) + "% output)"


func _on_save_pressed() -> void:
	var save_data := build_loadout_save_data()
	current_loadout = save_data.duplicate(true)
	save_requested.emit(save_data)


func _on_cancel_pressed() -> void:
	cancel_requested.emit()


func is_valid_item_for_slot(item_id: String, slot_key: String) -> bool:
	if item_id.strip_edges() == "":
		return true
	if not is_owned_item(item_id):
		return false
	return item_matches_slot(get_item_data(item_id), slot_key)


func is_owned_item(item_id: String) -> bool:
	if inventory == null:
		return false
	if not inventory.has_method("has_item_anywhere"):
		return false
	return inventory.has_item_anywhere(item_id)


func get_owned_count(item_id: String) -> int:
	if inventory == null or not inventory.has_method("count_item_anywhere"):
		return 0
	return int(inventory.count_item_anywhere(item_id))


func get_item_data(item_id: String) -> Dictionary:
	if item_handler == null:
		return {}
	if item_handler.has_method("has_item") and not item_handler.has_item(item_id):
		return {}
	if item_handler.has_method("get_item_data"):
		var data = item_handler.get_item_data(item_id)
		if typeof(data) == TYPE_DICTIONARY:
			return data
	return {}


func item_matches_slot(item_data: Dictionary, slot_key: String) -> bool:
	if item_data.is_empty():
		return false

	var item_type := str(item_data.get("item_type", item_data.get("type", ""))).strip_edges().to_lower()
	var item_slot := str(item_data.get("slot", "")).strip_edges().to_lower()

	match slot_key:
		SLOT_PRIMARY:
			return item_type == "weapon" and item_slot == "primary"
		SLOT_SECONDARY:
			return item_type == "weapon" and item_slot == "secondary"
		SLOT_SHIELD:
			return item_type == "shield" and item_slot == "shield"
		SLOT_CONSUMABLE:
			return item_type == "consumable"
		SLOT_UPGRADE_1, SLOT_UPGRADE_2, SLOT_UPGRADE_3:
			return item_type == "upgrade"

	return false


func get_item_display_name_for_slot(item_id: String, slot_key: String) -> String:
	if item_id == "":
		return "Empty"
	if is_valid_item_for_slot(item_id, slot_key):
		return get_item_display_name(item_id, get_item_data(item_id))
	return "Unavailable: " + item_id


func get_item_display_name(item_id: String, item_data: Dictionary) -> String:
	if item_data.is_empty():
		return item_id
	return str(item_data.get("display_name", item_data.get("name", item_id))).strip_edges()


func get_short_slot_label(slot_key: String) -> String:
	match slot_key:
		SLOT_PRIMARY:
			return "Primary"
		SLOT_SECONDARY:
			return "Secondary"
		SLOT_SHIELD:
			return "Shield"
		SLOT_CONSUMABLE:
			return "Consumable"
		SLOT_UPGRADE_1:
			return "Upg 1"
		SLOT_UPGRADE_2:
			return "Upg 2"
		SLOT_UPGRADE_3:
			return "Upg 3"
	return "Slot"


func get_long_slot_label(slot_key: String) -> String:
	match slot_key:
		SLOT_PRIMARY:
			return "Primary Weapon"
		SLOT_SECONDARY:
			return "Secondary Weapon"
		SLOT_SHIELD:
			return "Shield"
		SLOT_CONSUMABLE:
			return "Loaded Consumable"
		SLOT_UPGRADE_1:
			return "Upgrade Slot 1"
		SLOT_UPGRADE_2:
			return "Upgrade Slot 2"
		SLOT_UPGRADE_3:
			return "Upgrade Slot 3"
	return "Slot"


func get_upgrade_detail_text(item_data: Dictionary) -> String:
	var parts: Array = []
	var subtype := str(item_data.get("upgrade_subtype", item_data.get("subtype", "upgrade"))).strip_edges().replace("_", " ").capitalize()
	if subtype != "":
		parts.append(subtype)

	var meta = item_data.get("battle_upgrade_meta", {})
	if typeof(meta) == TYPE_DICTIONARY:
		append_upgrade_bonus_text(parts, meta, "max_hull_bonus", "Max Hull")
		append_upgrade_bonus_text(parts, meta, "max_energy_bonus", "Max Energy")
		append_upgrade_bonus_text(parts, meta, "primary_damage_bonus", "Primary Damage")
		append_upgrade_bonus_text(parts, meta, "secondary_damage_bonus", "Secondary Damage")
		append_upgrade_bonus_text(parts, meta, "secondary_burst_bonus", "Burst")

	return " | ".join(parts)


func append_upgrade_bonus_text(parts: Array, meta: Dictionary, key: String, label: String) -> void:
	var value := int(meta.get(key, 0))
	if value == 0:
		return
	var sign := "+" if value > 0 else ""
	parts.append(sign + str(value) + " " + label)


func set_status(text: String) -> void:
	if status_label != null and is_instance_valid(status_label):
		status_label.text = text


func _exit_tree() -> void:
	cleanup_drag_state()
