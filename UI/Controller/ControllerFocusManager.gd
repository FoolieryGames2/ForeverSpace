extends Node
class_name ControllerFocusManager


const ControllerFocusVisualScript = preload("res://UI/Controller/ControllerFocusVisual.gd")

const WIDGET_ACTION := "action_widget"
const WIDGET_EVENT := "event_widget"
const WIDGET_LEFT_PANEL := "left_panel"
const WIDGET_PORT := "port_window"

const INVENTORY_CRAFT_GROUP_TABS := "tabs"
const INVENTORY_CRAFT_GROUP_ITEMS := "items"
const INVENTORY_CRAFT_GROUP_CRAFTING := "crafting"

const LOCAL_MAP_MODE_CONTACTS := "contacts"
const TIER_MAP_GROUP_TABS := "tabs"
const TIER_MAP_GROUP_CONTACTS := "contacts"
const TIER_MAP_GROUP_BRIDGES := "bridges"
const STORY_POPUP_SCROLL_REPEAT_KEY := "story_popup_scroll_vertical"
const STORY_POPUP_SCROLL_MIN_PIXELS := 36.0
const STORY_POPUP_SCROLL_FRACTION := 0.28
const STORY_LOG_SCROLL_REPEAT_KEY := "story_log_scroll_vertical"
const STORY_LOG_SCROLL_MIN_PIXELS := 44.0
const STORY_LOG_SCROLL_FRACTION := 0.32

var main_scene = null
var gui_state = null
var main_left_panel_controller = null
var action_manager = null
var live_map_control = null
var map_ref = null
var port_window = null
var port_window_backdrop = null
var overlay: ControllerFocusOverlay = null

var controller_active := false
var controller_deadzone := 0.25
var controller_repeat_delay := 0.18
var controller_initial_repeat_delay := 0.35
var port_look_pixels_per_second := 520.0

var top_bar_items: Array = []
var widgets: Array = []
var highlighted_top_bar_id := ""
var highlighted_widget_id := WIDGET_ACTION
var highlighted_item_id_by_widget := {}
var pending_widget_focus_id := ""
var repeat_state := {}
var last_controller_connected := false
var popup_items: Array = []
var highlighted_popup_item_id := ""
var popup_scope_key := ""
var popup_edit_item_id := ""
var inventory_craft_group_name := INVENTORY_CRAFT_GROUP_TABS
var inventory_craft_group_items := {}
var highlighted_inventory_craft_item_id_by_group := {}
var local_map_focus_mode := LOCAL_MAP_MODE_CONTACTS
var highlighted_local_map_contact_id := ""
var local_map_prepared_contact_id := ""
var tier_map_group_name := TIER_MAP_GROUP_TABS
var tier_map_group_items := {}
var highlighted_tier_map_item_id_by_group := {}
var tier_map_prepared_item_id := ""
var visually_focused_item_control = null
var visually_focused_top_control = null
var controller_debug_last_route_key := ""
var controller_debug_last_route_msec := 0
var controller_debug_last_top_key := ""
var controller_debug_last_popup_key := ""
var last_scroll_ensure_key := ""
var last_scroll_ensure_msec := 0


func controller_support_debug_enabled() -> bool:
	return bool(Globals.get("print_priority_controller_support"))


func controller_debug(tag: String, data: Variant = "") -> void:
	if not controller_support_debug_enabled():
		return
	if str(data) == "":
		print("[CONTROLLER_SUPPORT] ", tag)
	else:
		print("[CONTROLLER_SUPPORT] ", tag, " ", data)


func controller_debug_throttled(key: String, tag: String, data: Variant = "", interval_msec: int = 700) -> void:
	if not controller_support_debug_enabled():
		return
	var now := Time.get_ticks_msec()
	if key == controller_debug_last_route_key and now - controller_debug_last_route_msec < interval_msec:
		return
	controller_debug_last_route_key = key
	controller_debug_last_route_msec = now
	controller_debug(tag, data)


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


func setup(refs: Dictionary) -> void:
	main_scene = refs.get("main_scene", null)
	gui_state = refs.get("gui_state", null)
	main_left_panel_controller = refs.get("main_left_panel_controller", null)
	action_manager = refs.get("action_manager", null)
	live_map_control = refs.get("live_map_control", null)
	map_ref = refs.get("map", null)
	port_window = refs.get("port_window", null)
	port_window_backdrop = refs.get("port_window_backdrop", null)
	overlay = refs.get("overlay", null)
	set_process(true)
	refresh_focus_model()
	update_overlay()
	controller_debug("SETUP", {
		"top_count": top_bar_items.size(),
		"widget_count": widgets.size(),
		"overlay": get_debug_control_name(overlay),
		"left_panel_controller": get_debug_control_name(main_left_panel_controller)
	})


func request_left_panel_focus(reason: String = "manual") -> void:
	pending_widget_focus_id = WIDGET_LEFT_PANEL
	highlighted_widget_id = WIDGET_LEFT_PANEL
	refresh_focus_model()
	update_overlay()
	controller_debug("REQUEST_LEFT_PANEL_FOCUS", {"reason": reason, "active_panel": get_active_left_panel_id()})


func handle_input(event: InputEvent) -> bool:
	if not is_controller_event(event):
		return false

	if controller_event_activates(event):
		controller_active = true
		last_controller_connected = true
		refresh_focus_model()
		update_overlay()
		controller_debug("INPUT_ACTIVATE", {
			"event": str(event),
			"joypads": Input.get_connected_joypads(),
			"top_count": top_bar_items.size(),
			"top_id": highlighted_top_bar_id,
			"widget_count": widgets.size(),
			"widget_id": highlighted_widget_id
		})

	return controller_active


func _process(delta: float) -> void:
	if not controller_active:
		return

	if Input.get_connected_joypads().is_empty():
		controller_active = false
		last_controller_connected = false
		clear_visual_focus()
		if overlay != null and is_instance_valid(overlay):
			overlay.clear_focus()
		return

	refresh_focus_model()
	controller_debug_throttled("process:" + str(is_controller_popup_active()) + ":" + str(top_bar_items.size()) + ":" + highlighted_top_bar_id + ":" + highlighted_widget_id, "PROCESS", {
		"popup_active": is_controller_popup_active(),
		"popup_lock": bool(Globals.is_popup_input_locked()),
		"top_count": top_bar_items.size(),
		"top_id": highlighted_top_bar_id,
		"widget_count": widgets.size(),
		"widget_id": highlighted_widget_id
	})

	# Local Map has a custom controller layout while it is focused.
	# It also keeps control during the coord-auto popup that was opened from a contact,
	# so X can click ENGAGE and D-pad can return to contacts.
	if is_local_map_controller_scope_active():
		handle_local_map_controller_input()
		handle_port_look(delta)
		update_local_map_overlay()
		return

	if is_tier_map_controller_scope_active():
		handle_tier_map_controller_input()
		handle_port_look(delta)
		update_tier_map_overlay()
		return

	if is_story_log_controller_scope_active():
		handle_story_log_controller_input()
		handle_port_look(delta)
		update_story_log_overlay()
		return

	if is_controller_popup_active():
		handle_popup_controller_input()
		update_popup_overlay()
		return

	if is_inventory_craft_controller_scope_active():
		handle_inventory_craft_controller_input()
		handle_port_look(delta)
		update_inventory_craft_overlay()
		return

	handle_top_bar_inputs()
	handle_widget_inputs()
	handle_port_look(delta)
	update_overlay()


func is_controller_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


func controller_event_activates(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return bool((event as InputEventJoypadButton).pressed)
	if event is InputEventJoypadMotion:
		return abs(float((event as InputEventJoypadMotion).axis_value)) >= controller_deadzone
	return false


func handle_top_bar_inputs() -> void:
	if Input.is_action_just_pressed("controller_top_left"):
		controller_debug("TOP_INPUT_L1", {"count": top_bar_items.size(), "before": highlighted_top_bar_id})
		move_top_bar_highlight(-1)
		controller_debug("TOP_INPUT_L1_AFTER", {"after": highlighted_top_bar_id})
	if Input.is_action_just_pressed("controller_top_right"):
		controller_debug("TOP_INPUT_R1", {"count": top_bar_items.size(), "before": highlighted_top_bar_id})
		move_top_bar_highlight(1)
		controller_debug("TOP_INPUT_R1_AFTER", {"after": highlighted_top_bar_id})
	if Input.is_action_just_pressed("controller_top_activate"):
		controller_debug("TOP_INPUT_TRIANGLE", {"id": highlighted_top_bar_id, "item": get_current_top_bar_item()})
		activate_highlighted_top_bar_item()


func handle_widget_inputs() -> void:
	if Input.is_action_just_pressed("controller_widget_activate"):
		controller_debug("WIDGET_INPUT_X", {"widget": highlighted_widget_id, "item": get_current_widget_item()})
		activate_highlighted_widget_item()

	# Normal Main Mode controller layout:
	# - Left stick actions move between widgets only.
	# - D-pad item actions move inside the currently highlighted widget only.
	# BattleLoadoutPopup does not use this function while its custom layout is active.
	var split_widget_navigation_enabled := has_any_input_action([
		"controller_widget_focus_left",
		"controller_widget_focus_right",
		"controller_widget_focus_up",
		"controller_widget_focus_down",
		"controller_widget_item_left",
		"controller_widget_item_right",
		"controller_widget_item_up",
		"controller_widget_item_down"
	])

	if split_widget_navigation_enabled:
		handle_split_widget_navigation_inputs()
	else:
		handle_legacy_widget_navigation_inputs()

	if Input.is_action_just_pressed("controller_scan"):
		controller_debug("SCAN_INPUT_CIRCLE", {"widget": highlighted_widget_id})
		request_scan_from_controller()


func handle_split_widget_navigation_inputs() -> void:
	var focus_horizontal := get_action_strength_safe("controller_widget_focus_right") - get_action_strength_safe("controller_widget_focus_left")
	var focus_vertical := get_action_strength_safe("controller_widget_focus_down") - get_action_strength_safe("controller_widget_focus_up")
	var focus_step := 0

	if abs(focus_horizontal) >= controller_deadzone or abs(focus_vertical) >= controller_deadzone:
		if abs(focus_horizontal) >= abs(focus_vertical):
			focus_step = 1 if focus_horizontal > 0.0 else -1
		else:
			focus_step = 1 if focus_vertical > 0.0 else -1

	if focus_step != 0:
		if can_repeat("widget_focus_split"):
			controller_debug("WIDGET_FOCUS_MOVE", {"step": focus_step, "before": highlighted_widget_id})
			move_widget_highlight(focus_step)
			controller_debug("WIDGET_FOCUS_MOVE_AFTER", {"after": highlighted_widget_id})
	else:
		reset_repeat("widget_focus_split")

	var item_horizontal := get_action_strength_safe("controller_widget_item_right") - get_action_strength_safe("controller_widget_item_left")
	var item_vertical := get_action_strength_safe("controller_widget_item_down") - get_action_strength_safe("controller_widget_item_up")
	var item_step := 0

	if abs(item_horizontal) >= controller_deadzone or abs(item_vertical) >= controller_deadzone:
		if abs(item_horizontal) >= abs(item_vertical):
			item_step = 1 if item_horizontal > 0.0 else -1
		else:
			item_step = 1 if item_vertical > 0.0 else -1

	if item_step != 0:
		if can_repeat("widget_item_split"):
			controller_debug("WIDGET_ITEM_MOVE", {"widget": highlighted_widget_id, "step": item_step, "before": get_current_widget_item()})
			move_widget_item_highlight(item_step)
			controller_debug("WIDGET_ITEM_MOVE_AFTER", {"widget": highlighted_widget_id, "after": get_current_widget_item()})
	else:
		reset_repeat("widget_item_split")


func handle_legacy_widget_navigation_inputs() -> void:
	var horizontal := Input.get_action_strength("controller_widget_nav_right") - Input.get_action_strength("controller_widget_nav_left")
	var vertical := Input.get_action_strength("controller_widget_nav_down") - Input.get_action_strength("controller_widget_nav_up")

	if abs(horizontal) >= controller_deadzone and abs(horizontal) >= abs(vertical):
		if can_repeat("widget_horizontal"):
			move_widget_highlight(1 if horizontal > 0.0 else -1)
	else:
		reset_repeat("widget_horizontal")

	if abs(vertical) >= controller_deadzone and abs(vertical) > abs(horizontal):
		if can_repeat("widget_vertical"):
			move_widget_item_highlight(1 if vertical > 0.0 else -1)
	else:
		reset_repeat("widget_vertical")


func has_any_input_action(action_names: Array) -> bool:
	for action_name in action_names:
		if InputMap.has_action(str(action_name)):
			return true
	return false


func get_action_strength_safe(action_name: String) -> float:
	if not InputMap.has_action(action_name):
		return 0.0
	return Input.get_action_strength(action_name)


func is_action_just_pressed_safe(action_name: String) -> bool:
	if not InputMap.has_action(action_name):
		return false
	return Input.is_action_just_pressed(action_name)


func handle_port_look(delta: float) -> void:
	if Input.is_action_just_pressed("controller_port_look_click"):
		recenter_port_view()

	var look_x := Input.get_action_strength("controller_port_look_right") - Input.get_action_strength("controller_port_look_left")
	var look_y := Input.get_action_strength("controller_port_look_down") - Input.get_action_strength("controller_port_look_up")
	var look := Vector2(look_x, look_y)
	if look.length() < controller_deadzone:
		return

	var target = get_port_look_target()
	if target == null:
		return
	if target.has_method("manual_drag_locked") and bool(target.manual_drag_locked()):
		return
	if not bool(Globals.port_window_drag_enabled):
		return
	if not target.has_method("apply_drag_delta"):
		return

	target.apply_drag_delta(look * port_look_pixels_per_second * delta)


func get_port_look_target():
	if port_window != null and is_instance_valid(port_window) and port_window is Control:
		if (port_window as Control).is_visible_in_tree():
			return port_window
	if port_window_backdrop != null and is_instance_valid(port_window_backdrop) and port_window_backdrop is Control:
		if (port_window_backdrop as Control).is_visible_in_tree():
			return port_window_backdrop
	return null


func recenter_port_view() -> void:
	if map_ref == null:
		return
	map_ref.yaw = 0.0
	map_ref.pitch = 0.0

	for target in [port_window, port_window_backdrop]:
		if target == null or not is_instance_valid(target):
			continue
		if target.has_method("update_drive_widget_orientation"):
			target.update_drive_widget_orientation()
		if target.has_method("update_drag_status_label"):
			target.update_drag_status_label()
		if target.has_method("queue_redraw"):
			target.queue_redraw()


func request_scan_from_controller() -> void:
	var scan_button = find_action_button("scan_local")
	controller_debug("SCAN_REQUEST", {"button": get_debug_control_name(scan_button)})
	if scan_button != null:
		press_button(scan_button)


func find_action_button(action_id: String):
	if gui_state == null:
		return null
	var button_list = gui_state.action_storage.get("button_list", null)
	if not is_control_visible(button_list):
		return null

	for child in (button_list as Node).get_children():
		if child == null or not is_instance_valid(child):
			continue
		if not (child is BaseButton):
			continue
		if not is_button_selectable(child):
			continue
		if str(child.get_meta("controller_action_id", "")).strip_edges() == action_id:
			return child
	return null


func handle_popup_controller_input() -> void:
	var popup_root: Variant = gui_state.controls.get("popup_root", null) if gui_state != null else null
	var active_popup_scope: Variant = get_active_popup_scope(popup_root)
	controller_debug_throttled("popup_route:" + get_debug_control_name(active_popup_scope) + ":" + str(is_battle_loadout_popup_scope(active_popup_scope)), "POPUP_ROUTE", {
		"popup_root": get_debug_control_name(popup_root),
		"scope": get_debug_control_name(active_popup_scope),
		"is_battle_loadout": is_battle_loadout_popup_scope(active_popup_scope),
		"popup_lock": bool(Globals.is_popup_input_locked())
	})

	# BattleLoadoutPopup owns a custom controller layout.
	# Check it before the generic popup_items guard, because the custom
	# layout can be valid even when the generic popup item collector is empty.
	if is_battle_loadout_popup_scope(active_popup_scope):
		handle_battle_loadout_controller_input(active_popup_scope)
		return

	refresh_popup_focus_model()

	if is_story_popup_scope(active_popup_scope):
		if Input.is_action_just_pressed("controller_popup_confirm") or Input.is_action_just_pressed("controller_widget_activate"):
			activate_highlighted_popup_item()
			return
		if handle_story_popup_scroll_input(active_popup_scope):
			return

	if popup_items.is_empty():
		controller_debug_throttled("popup_empty:" + get_debug_control_name(active_popup_scope), "POPUP_GENERIC_EMPTY", {"scope": get_debug_control_name(active_popup_scope)})
		return

	if popup_edit_item_id != "":
		handle_popup_numeric_edit_inputs()
		if Input.is_action_just_pressed("controller_popup_confirm") or Input.is_action_just_pressed("controller_widget_activate"):
			popup_edit_item_id = ""
		return

	var horizontal := Input.get_action_strength("controller_widget_nav_right") - Input.get_action_strength("controller_widget_nav_left")
	var vertical := Input.get_action_strength("controller_widget_nav_down") - Input.get_action_strength("controller_widget_nav_up")

	if abs(horizontal) >= controller_deadzone and abs(horizontal) >= abs(vertical):
		if can_repeat("popup_horizontal"):
			move_popup_highlight(1 if horizontal > 0.0 else -1)
	else:
		reset_repeat("popup_horizontal")

	if abs(vertical) >= controller_deadzone and abs(vertical) > abs(horizontal):
		if can_repeat("popup_vertical"):
			move_popup_highlight(1 if vertical > 0.0 else -1)
	else:
		reset_repeat("popup_vertical")

	if Input.is_action_just_pressed("controller_popup_confirm") or Input.is_action_just_pressed("controller_widget_activate"):
		activate_highlighted_popup_item()


func is_battle_loadout_popup_scope(scope: Variant) -> bool:
	if scope == null or not is_instance_valid(scope):
		return false
	return scope.has_method("get_controller_group_name") and scope.has_method("move_controller_navigation_selection") and scope.has_method("activate_controller_navigation_selection")


func is_story_popup_scope(scope: Variant) -> bool:
	if scope == null or not is_instance_valid(scope):
		return false
	if not (scope is Node):
		return false

	var node := scope as Node
	if str(node.name).begins_with("story_popup_window_"):
		return true
	if str(node.get_meta("active_popup_kind", "")).strip_edges() == "story_popup":
		return true
	if node.has_meta("story_popup_token"):
		return true
	return false


func handle_story_popup_scroll_input(scope: Variant) -> bool:
	var vertical := Input.get_action_strength("controller_widget_nav_down") - Input.get_action_strength("controller_widget_nav_up")
	if abs(vertical) < controller_deadzone:
		reset_repeat(STORY_POPUP_SCROLL_REPEAT_KEY)
		return false

	var scroll := find_story_popup_scroll_container(scope)
	if scroll == null or not is_instance_valid(scroll):
		reset_repeat(STORY_POPUP_SCROLL_REPEAT_KEY)
		return false

	if can_repeat(STORY_POPUP_SCROLL_REPEAT_KEY):
		scroll_story_popup_text(scroll, 1 if vertical > 0.0 else -1)
	return true


func find_story_popup_scroll_container(scope: Variant) -> ScrollContainer:
	if scope == null or not is_instance_valid(scope):
		return null
	if not (scope is Node):
		return null

	var named_scroll := find_story_popup_scroll_container_recursive(scope as Node, true)
	if named_scroll != null:
		return named_scroll
	return find_story_popup_scroll_container_recursive(scope as Node, false)


func find_story_popup_scroll_container_recursive(root: Node, require_story_name: bool) -> ScrollContainer:
	if root == null or not is_instance_valid(root):
		return null

	for child in root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child is Control and not (child as Control).is_visible_in_tree():
			continue

		if child is ScrollContainer:
			var scroll := child as ScrollContainer
			if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
				if not require_story_name or is_story_popup_scroll_container(scroll):
					return scroll

		if child is Node:
			var nested_scroll := find_story_popup_scroll_container_recursive(child as Node, require_story_name)
			if nested_scroll != null:
				return nested_scroll

	return null


func is_story_popup_scroll_container(scroll: ScrollContainer) -> bool:
	if scroll == null or not is_instance_valid(scroll):
		return false
	if str(scroll.name).find("story_popup") >= 0:
		return true

	for child in scroll.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child is RichTextLabel and str(child.name).find("story_popup") >= 0:
			return true
	return false


func scroll_story_popup_text(scroll: ScrollContainer, direction: int) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	if direction == 0:
		return

	var step_pixels := int(max(STORY_POPUP_SCROLL_MIN_PIXELS, scroll.size.y * STORY_POPUP_SCROLL_FRACTION))
	var target_vertical = max(0, int(scroll.scroll_vertical) + direction * step_pixels)
	var bar := scroll.get_v_scroll_bar()
	if bar != null and is_instance_valid(bar):
		var max_vertical := int(max(0.0, bar.max_value - bar.page))
		if max_vertical > 0:
			target_vertical = clamp(target_vertical, 0, max_vertical)

	var old_vertical := int(scroll.scroll_vertical)
	scroll.scroll_vertical = target_vertical
	if int(scroll.scroll_vertical) != old_vertical:
		controller_debug("STORY_POPUP_SCROLL", {
			"scroll": get_debug_control_name(scroll),
			"from": old_vertical,
			"to": scroll.scroll_vertical
		})


func is_story_log_controller_scope_active() -> bool:
	if is_controller_popup_active():
		return false
	if highlighted_widget_id != WIDGET_LEFT_PANEL:
		return false
	if get_active_left_panel_id() != "story_log":
		return false
	return get_story_log_scroll_container() != null


func handle_story_log_controller_input() -> void:
	handle_top_bar_inputs()

	var vertical := get_story_log_scroll_input()
	if abs(vertical) < controller_deadzone:
		reset_repeat(STORY_LOG_SCROLL_REPEAT_KEY)
		return

	var scroll := get_story_log_scroll_container()
	if scroll == null or not is_instance_valid(scroll):
		reset_repeat(STORY_LOG_SCROLL_REPEAT_KEY)
		return

	if can_repeat(STORY_LOG_SCROLL_REPEAT_KEY):
		scroll_story_log_text(scroll, 1 if vertical > 0.0 else -1)


func get_story_log_scroll_input() -> float:
	var vertical := get_action_strength_safe("controller_widget_item_down") - get_action_strength_safe("controller_widget_item_up")
	if abs(vertical) < controller_deadzone:
		vertical = get_action_strength_safe("controller_widget_nav_down") - get_action_strength_safe("controller_widget_nav_up")
	return vertical


func get_story_log_scroll_container() -> ScrollContainer:
	if gui_state == null:
		return null
	var scroll_value: Variant = gui_state.controls.get("story_popup_log_scroll", null)
	if is_control_visible(scroll_value) and scroll_value is ScrollContainer:
		return scroll_value as ScrollContainer
	return null


func scroll_story_log_text(scroll: ScrollContainer, direction: int) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	if direction == 0:
		return

	var step_pixels := int(max(STORY_LOG_SCROLL_MIN_PIXELS, scroll.size.y * STORY_LOG_SCROLL_FRACTION))
	var target_vertical = max(0, int(scroll.scroll_vertical) + direction * step_pixels)
	var bar := scroll.get_v_scroll_bar()
	if bar != null and is_instance_valid(bar):
		var max_vertical := int(max(0.0, bar.max_value - bar.page))
		if max_vertical > 0:
			target_vertical = clamp(target_vertical, 0, max_vertical)

	var old_vertical := int(scroll.scroll_vertical)
	scroll.scroll_vertical = target_vertical
	if int(scroll.scroll_vertical) != old_vertical:
		controller_debug("STORY_LOG_SCROLL", {
			"scroll": get_debug_control_name(scroll),
			"from": old_vertical,
			"to": scroll.scroll_vertical
		})


func update_story_log_overlay() -> void:
	var root := get_story_log_root()
	var scroll := get_story_log_scroll_container()
	clear_top_visual_focus()
	set_visual_focus(scroll)
	if overlay != null and is_instance_valid(overlay):
		overlay.set_focus_nodes(null, root, scroll, true, false, true, get_story_log_controller_hint())


func get_story_log_root() -> Control:
	if gui_state == null:
		return null
	var root_value: Variant = gui_state.controls.get("story_popup_log_left_root", null)
	if is_control_visible(root_value) and root_value is Control:
		return root_value as Control
	return null


func handle_battle_loadout_controller_input(scope: Variant) -> void:
	if scope == null or not is_instance_valid(scope):
		return

	controller_debug_throttled("battle_loadout_route:" + get_debug_control_name(scope), "BATTLE_LOADOUT_ROUTE", {
		"scope": get_debug_control_name(scope),
		"group": scope.get_controller_group_name() if scope.has_method("get_controller_group_name") else "no_method",
		"selected": get_debug_control_name(scope.get_controller_navigation_selected_control()) if scope.has_method("get_controller_navigation_selected_control") else "no_method"
	})

	if Input.is_action_just_pressed("controller_top_left"):
		controller_debug("BATTLE_LOADOUT_L1", {"before_group": scope.get_controller_group_name() if scope.has_method("get_controller_group_name") else "no_method"})
		switch_battle_loadout_group(scope, -1)
		controller_debug("BATTLE_LOADOUT_L1_AFTER", {"after_group": scope.get_controller_group_name() if scope.has_method("get_controller_group_name") else "no_method"})
		return
	if Input.is_action_just_pressed("controller_top_right"):
		controller_debug("BATTLE_LOADOUT_R1", {"before_group": scope.get_controller_group_name() if scope.has_method("get_controller_group_name") else "no_method"})
		switch_battle_loadout_group(scope, 1)
		controller_debug("BATTLE_LOADOUT_R1_AFTER", {"after_group": scope.get_controller_group_name() if scope.has_method("get_controller_group_name") else "no_method"})
		return

	var current_group := str(scope.get_controller_group_name()) if scope.has_method("get_controller_group_name") else "slots"
	var horizontal := Input.get_action_strength("controller_widget_nav_right") - Input.get_action_strength("controller_widget_nav_left")
	var vertical := Input.get_action_strength("controller_widget_nav_down") - Input.get_action_strength("controller_widget_nav_up")
	var move_step := 0

	# Battle Loadout has its own controller panels. L1/R1 switch panels.
	# D-pad/left-stick should only move inside the current panel, never jump panels.
	# Vertical panels use up/down only; compact horizontal panels may use left/right.
	if current_group in ["slots", "gear"]:
		if abs(vertical) >= controller_deadzone:
			move_step = 1 if vertical > 0.0 else -1
	else:
		if abs(horizontal) >= controller_deadzone and abs(horizontal) >= abs(vertical):
			move_step = 1 if horizontal > 0.0 else -1
		elif abs(vertical) >= controller_deadzone:
			move_step = 1 if vertical > 0.0 else -1

	if move_step != 0 and can_repeat("battle_loadout_navigation"):
		controller_debug("BATTLE_LOADOUT_MOVE", {"step": move_step, "group": current_group})
		scope.move_controller_navigation_selection(move_step)
	else:
		reset_repeat("battle_loadout_navigation")

	if Input.is_action_just_pressed("controller_popup_confirm") or Input.is_action_just_pressed("controller_widget_activate"):
		controller_debug("BATTLE_LOADOUT_X", {"group": scope.get_controller_group_name() if scope.has_method("get_controller_group_name") else "no_method", "selected": get_debug_control_name(scope.get_controller_navigation_selected_control()) if scope.has_method("get_controller_navigation_selected_control") else "no_method"})
		scope.activate_controller_navigation_selection()


func switch_battle_loadout_group(scope: Variant, step: int) -> void:
	if scope == null or not is_instance_valid(scope):
		return
	var groups := ["slots", "lanes", "gear", "actions"]
	var current_group := str(scope.get_controller_group_name()) if scope.has_method("get_controller_group_name") else "slots"
	var current_index := groups.find(current_group)
	if current_index < 0:
		current_index = 0

	for attempt in range(groups.size()):
		current_index = wrap_index(current_index + step, groups.size())
		var group_name := str(groups[current_index])
		if scope.has_method("get_controller_group_items"):
			var raw_group_items: Variant = scope.get_controller_group_items(group_name)
			if raw_group_items is Array and (raw_group_items as Array).is_empty():
				continue
		scope.set_controller_navigation_group(group_name)
		return



func is_local_map_controller_scope_active() -> bool:
	# Normal contact browsing only owns input when the Local Map panel itself is focused.
	if is_controller_popup_active():
		return false
	if highlighted_widget_id != WIDGET_LEFT_PANEL:
		return false
	if get_active_left_panel_id() != "local_map":
		return false
	if get_local_map_contact_items().is_empty():
		return false
	return true


func handle_local_map_controller_input() -> void:
	refresh_local_map_contact_selection()
	controller_debug_throttled("local_map_route:" + local_map_focus_mode + ":" + str(get_local_map_contact_items().size()), "LOCAL_MAP_ROUTE", {
		"mode": local_map_focus_mode,
		"contacts": get_local_map_contact_items().size(),
		"selected_contact": get_current_local_map_contact_item(),
		"target_trigger": get_debug_control_name(get_local_map_target_auto_button())
	})

	# Triangle closes the Local Map and returns to the normal controller layout.
	if is_action_just_pressed_safe("controller_top_activate"):
		controller_debug("LOCAL_MAP_TRIANGLE_CLOSE", {"mode": local_map_focus_mode})
		close_local_map_controller_scope()
		return

	var dpad_step := get_local_map_dpad_step()

	if local_map_focus_mode == LOCAL_MAP_MODE_CONTACTS:
		if dpad_step != 0 and can_repeat("local_map_contacts"):
			controller_debug("LOCAL_MAP_CONTACT_MOVE", {"step": dpad_step, "before": get_current_local_map_contact_item()})
			move_local_map_contact(dpad_step)
			controller_debug("LOCAL_MAP_CONTACT_MOVE_AFTER", {"after": get_current_local_map_contact_item()})
		elif dpad_step == 0:
			reset_repeat("local_map_contacts")

		# X clicks the selected map contact. Existing marker button/signal logic handles
		# loading the target widget. A second X on the same prepared contact presses
		# the target widget's own autopilot trigger.
		if is_action_just_pressed_safe("controller_widget_activate") or is_action_just_pressed_safe("controller_popup_confirm"):
			var current_contact_id := get_current_local_map_contact_id()
			if should_trigger_prepared_local_map_contact(current_contact_id):
				controller_debug("LOCAL_MAP_X_TRIGGER_PREPARED_TARGET", {"contact_id": current_contact_id, "button": get_debug_control_name(get_local_map_target_auto_button())})
				if press_button(get_local_map_target_auto_button()):
					local_map_focus_mode = LOCAL_MAP_MODE_CONTACTS
					local_map_prepared_contact_id = ""
					refresh_local_map_contact_selection()
					call_deferred("update_local_map_overlay")
				else:
					controller_debug("LOCAL_MAP_TARGET_TRIGGER_PRESS_FAILED", {"button": get_debug_control_name(get_local_map_target_auto_button())})
				return

			controller_debug("LOCAL_MAP_X_CONTACT_PREPARE_AUTOPILOT", {"contact": get_current_local_map_contact_item()})
			if activate_local_map_selected_contact():
				local_map_focus_mode = LOCAL_MAP_MODE_CONTACTS
				local_map_prepared_contact_id = current_contact_id
				call_deferred("update_local_map_overlay")
			else:
				controller_debug("LOCAL_MAP_CONTACT_CLICK_FAILED", {"contact": get_current_local_map_contact_item()})
		return


func get_local_map_dpad_step() -> int:
	# Prefer the new split D-pad item actions. Fall back to legacy nav names so this
	# remains forgiving while input maps are being refined.
	var horizontal := get_action_strength_safe("controller_widget_item_right") - get_action_strength_safe("controller_widget_item_left")
	var vertical := get_action_strength_safe("controller_widget_item_down") - get_action_strength_safe("controller_widget_item_up")
	if abs(horizontal) < controller_deadzone and abs(vertical) < controller_deadzone:
		horizontal = get_action_strength_safe("controller_widget_nav_right") - get_action_strength_safe("controller_widget_nav_left")
		vertical = get_action_strength_safe("controller_widget_nav_down") - get_action_strength_safe("controller_widget_nav_up")

	if abs(horizontal) < controller_deadzone and abs(vertical) < controller_deadzone:
		return 0
	if abs(vertical) >= abs(horizontal):
		return 1 if vertical > 0.0 else -1
	return 1 if horizontal > 0.0 else -1


func is_local_map_dpad_active() -> bool:
	return get_local_map_dpad_step() != 0


func get_local_map_contact_items() -> Array:
	var items: Array = []
	collect_live_map_marker_items(items)
	return filter_live_items(items)


func refresh_local_map_contact_selection() -> void:
	var items := get_local_map_contact_items()
	if items.is_empty():
		highlighted_local_map_contact_id = ""
		return
	if highlighted_local_map_contact_id == "" or find_item_index(items, highlighted_local_map_contact_id) < 0:
		highlighted_local_map_contact_id = str(items[0].get("item_id", ""))

	# Mirror into the normal left-panel selected item id so existing overlay/debug helpers
	# and future fallbacks see the same selected contact.
	highlighted_item_id_by_widget[WIDGET_LEFT_PANEL] = highlighted_local_map_contact_id


func get_current_local_map_contact_item() -> Dictionary:
	var items := get_local_map_contact_items()
	if items.is_empty():
		return {}
	var index := find_item_index(items, highlighted_local_map_contact_id)
	if index < 0:
		index = 0
		highlighted_local_map_contact_id = str(items[index].get("item_id", ""))
		highlighted_item_id_by_widget[WIDGET_LEFT_PANEL] = highlighted_local_map_contact_id
	return items[index]


func get_current_local_map_contact_id() -> String:
	var item := get_current_local_map_contact_item()
	if item.is_empty():
		return ""
	return str(item.get("item_id", "")).strip_edges()


func should_trigger_prepared_local_map_contact(contact_id: String) -> bool:
	if contact_id == "":
		return false
	if local_map_prepared_contact_id != contact_id:
		return false
	return is_button_selectable(get_local_map_target_auto_button())


func move_local_map_contact(step: int) -> void:
	var items := get_local_map_contact_items()
	if items.is_empty():
		return
	var index := find_item_index(items, highlighted_local_map_contact_id)
	if index < 0:
		index = 0
	index = wrap_index(index + step, items.size())
	highlighted_local_map_contact_id = str(items[index].get("item_id", ""))
	highlighted_item_id_by_widget[WIDGET_LEFT_PANEL] = highlighted_local_map_contact_id
	local_map_prepared_contact_id = ""
	ensure_local_map_contact_visible("local_map_contact_changed")


func activate_local_map_selected_contact() -> bool:
	var item := get_current_local_map_contact_item()
	if item.is_empty():
		return false
	# Click the existing LiveMapMarker signal/button path.
	return activate_live_map_marker(item)


func is_coord_auto_pilot_popup_active() -> bool:
	return is_control_visible(get_coord_auto_root())


func get_coord_auto_root() -> Control:
	if gui_state == null:
		return null
	var root_value: Variant = gui_state.controls.get("coord_auto_pilot_root", null)
	if is_control_visible(root_value):
		return root_value as Control
	return null


func get_coord_auto_engage_button() -> Variant:
	if gui_state == null:
		return null
	return gui_state.buttons.get("coord_auto_engage", null)


func get_local_map_target_auto_button() -> Variant:
	if live_map_control != null and is_instance_valid(live_map_control):
		var target_widget = live_map_control.get("target_widget")
		if target_widget != null and is_instance_valid(target_widget):
			var auto_button = target_widget.get("auto_button")
			if auto_button != null:
				return auto_button
	if gui_state != null:
		return gui_state.buttons.get("LiveMapAutoToTargetButton", null)
	return null


func close_coord_auto_popup_from_local_map() -> void:
	# Prefer the existing shared popup reset because the coord-auto popup was built in
	# shared popup space. This keeps mouse/keyboard behavior unchanged and only runs
	# during the Local Map controller route.
	if gui_state != null and Globals.has_method("reset_popup_runtime"):
		Globals.reset_popup_runtime(gui_state, true)


func close_local_map_controller_scope() -> void:
	if is_coord_auto_pilot_popup_active():
		close_coord_auto_popup_from_local_map()

	var close_button: Variant = null
	if gui_state != null:
		close_button = gui_state.buttons.get("main_cockpit_button_close", null)
	if is_button_selectable(close_button):
		press_button(close_button)
	elif main_left_panel_controller != null and is_instance_valid(main_left_panel_controller):
		if main_left_panel_controller.has_method("hide_all_panels"):
			main_left_panel_controller.hide_all_panels()
		elif main_left_panel_controller.has_method("close_current_panel"):
			main_left_panel_controller.close_current_panel()

	local_map_focus_mode = LOCAL_MAP_MODE_CONTACTS
	highlighted_local_map_contact_id = ""
	local_map_prepared_contact_id = ""
	highlighted_widget_id = WIDGET_ACTION
	pending_widget_focus_id = WIDGET_ACTION
	clear_item_visual_focus()
	last_scroll_ensure_key = ""


func ensure_local_map_contact_visible(reason: String = "local_map_contact") -> void:
	var item := get_current_local_map_contact_item()
	if item.is_empty():
		return
	var control_value: Variant = item.get("node", null)
	if not is_live_control(control_value):
		return
	ensure_control_visible_in_scroll(control_value as Control, reason)


func update_local_map_overlay() -> void:
	if overlay == null or not is_instance_valid(overlay):
		clear_visual_focus()
		return

	var root: Variant = live_map_control
	var selected_control: Variant = null
	var popup_mode := false

	local_map_focus_mode = LOCAL_MAP_MODE_CONTACTS
	refresh_local_map_contact_selection()
	selected_control = get_current_local_map_contact_item().get("node", null)
	root = live_map_control
	ensure_local_map_contact_visible("local_map_overlay")

	clear_top_visual_focus()
	set_visual_focus(selected_control)
	if overlay != null and is_instance_valid(overlay):
		overlay.set_focus_nodes(null, root, selected_control, true, popup_mode, true, get_local_map_controller_hint())


func is_tier_map_controller_scope_active() -> bool:
	if get_active_left_panel_id() != "tier_map":
		return false
	if is_coord_auto_pilot_popup_active() and tier_map_prepared_item_id != "":
		return true
	if is_controller_popup_active():
		return false
	if highlighted_widget_id != WIDGET_LEFT_PANEL:
		return false
	return get_tier_map_root() != null


func get_tier_map_root() -> Control:
	if gui_state == null:
		return null
	var root_value: Variant = gui_state.controls.get("tier_map", null)
	if is_control_visible(root_value):
		return root_value as Control
	return null


func handle_tier_map_controller_input() -> void:
	refresh_tier_map_group_model()
	controller_debug_throttled("tier_map_route:" + tier_map_group_name + ":" + str(get_tier_map_group_items(tier_map_group_name).size()), "TIER_MAP_ROUTE", {
		"group": tier_map_group_name,
		"tabs": get_tier_map_group_items(TIER_MAP_GROUP_TABS).size(),
		"contacts": get_tier_map_group_items(TIER_MAP_GROUP_CONTACTS).size(),
		"bridges": get_tier_map_group_items(TIER_MAP_GROUP_BRIDGES).size(),
		"prepared": tier_map_prepared_item_id,
		"selected": get_debug_control_name(get_current_tier_map_group_item().get("node", null))
	})

	if is_action_just_pressed_safe("controller_top_activate"):
		controller_debug("TIER_MAP_TRIANGLE_CLOSE", {"group": tier_map_group_name})
		close_tier_map_controller_scope()
		return

	if is_action_just_pressed_safe("controller_top_left"):
		switch_tier_map_group(-1)
		return

	if is_action_just_pressed_safe("controller_top_right"):
		switch_tier_map_group(1)
		return

	if is_action_just_pressed_safe("controller_widget_activate") or is_action_just_pressed_safe("controller_popup_confirm"):
		activate_tier_map_group_item()
		return

	var move_step := get_tier_map_dpad_step()
	if move_step != 0 and can_repeat("tier_map_navigation"):
		move_tier_map_group_item(move_step)
	else:
		reset_repeat("tier_map_navigation")


func get_tier_map_dpad_step() -> int:
	var horizontal := get_action_strength_safe("controller_widget_item_right") - get_action_strength_safe("controller_widget_item_left")
	var vertical := get_action_strength_safe("controller_widget_item_down") - get_action_strength_safe("controller_widget_item_up")
	if abs(horizontal) < controller_deadzone and abs(vertical) < controller_deadzone:
		horizontal = get_action_strength_safe("controller_widget_nav_right") - get_action_strength_safe("controller_widget_nav_left")
		vertical = get_action_strength_safe("controller_widget_nav_down") - get_action_strength_safe("controller_widget_nav_up")

	if abs(horizontal) < controller_deadzone and abs(vertical) < controller_deadzone:
		return 0
	if abs(vertical) >= abs(horizontal):
		return 1 if vertical > 0.0 else -1
	return 1 if horizontal > 0.0 else -1


func get_tier_map_group_order() -> Array:
	return [TIER_MAP_GROUP_TABS, TIER_MAP_GROUP_CONTACTS, TIER_MAP_GROUP_BRIDGES]


func switch_tier_map_group(step: int) -> void:
	var groups := get_tier_map_group_order()
	var index := groups.find(tier_map_group_name)
	if index < 0:
		index = 0

	for attempt in range(groups.size()):
		index = wrap_index(index + step, groups.size())
		var group_name := str(groups[index])
		if get_tier_map_group_items(group_name).is_empty():
			continue
		tier_map_group_name = group_name
		ensure_tier_map_group_selection(group_name)
		tier_map_prepared_item_id = ""
		close_coord_auto_popup_from_tier_map()
		ensure_current_tier_map_item_visible("tier_map_group_changed")
		return


func refresh_tier_map_group_model() -> void:
	var groups := {
		TIER_MAP_GROUP_TABS: [],
		TIER_MAP_GROUP_CONTACTS: [],
		TIER_MAP_GROUP_BRIDGES: []
	}

	var root := get_tier_map_root()
	if root == null:
		tier_map_group_items = groups
		return

	if gui_state != null and gui_state.buttons.has("tier_map"):
		var tier_buttons: Dictionary = gui_state.buttons["tier_map"]
		for tab_id in ["all", "star", "planet", "object", "beacon", "enemy", "npc"]:
			var key = "tab_" + tab_id
			if tier_buttons.has(key) and is_button_selectable(tier_buttons[key]):
				append_tier_map_group_item(groups, TIER_MAP_GROUP_TABS, make_tier_map_item(tier_buttons[key], TIER_MAP_GROUP_TABS))
		for bridge_key in ["bridge_previous", "bridge_next"]:
			if tier_buttons.has(bridge_key) and is_button_selectable(tier_buttons[bridge_key]):
				append_tier_map_group_item(groups, TIER_MAP_GROUP_BRIDGES, make_tier_map_item(tier_buttons[bridge_key], TIER_MAP_GROUP_BRIDGES))

	var rows: Array = []
	if gui_state != null:
		var raw_rows: Variant = gui_state.labels.get("tier_map_rows", [])
		if raw_rows is Array:
			rows = raw_rows as Array
	for row in rows:
		if is_button_selectable(row):
			append_tier_map_group_item(groups, TIER_MAP_GROUP_CONTACTS, make_tier_map_item(row, TIER_MAP_GROUP_CONTACTS))

	tier_map_group_items = groups
	if get_tier_map_group_items(tier_map_group_name).is_empty():
		for group_name in get_tier_map_group_order():
			if not get_tier_map_group_items(str(group_name)).is_empty():
				tier_map_group_name = str(group_name)
				break

	for group_name in get_tier_map_group_order():
		ensure_tier_map_group_selection(str(group_name))


func make_tier_map_item(control_value: Variant, group_name: String) -> Dictionary:
	var base_item := make_button_item(control_value, "tier_map_" + group_name)
	var item_id := str(base_item.get("item_id", ""))
	if control_value is Node:
		item_id = "tier_map:" + group_name + ":" + str((control_value as Node).name) + ":" + str(control_value.get_instance_id())
	base_item["item_id"] = item_id
	base_item["tier_map_group"] = group_name
	return base_item


func get_tier_map_group_items(group_name: String) -> Array:
	var raw_items: Variant = tier_map_group_items.get(group_name, [])
	if raw_items is Array:
		return raw_items as Array
	return []


func append_tier_map_group_item(groups: Dictionary, group_name: String, item: Dictionary) -> void:
	if item.is_empty():
		return
	if not groups.has(group_name):
		groups[group_name] = []
	var items: Array = groups[group_name]
	items.append(item)
	groups[group_name] = items


func ensure_tier_map_group_selection(group_name: String) -> void:
	var items := get_tier_map_group_items(group_name)
	if items.is_empty():
		highlighted_tier_map_item_id_by_group[group_name] = ""
		return
	var current_id := str(highlighted_tier_map_item_id_by_group.get(group_name, ""))
	if current_id == "" or find_item_index(items, current_id) < 0:
		highlighted_tier_map_item_id_by_group[group_name] = str(items[0].get("item_id", ""))


func get_current_tier_map_group_item() -> Dictionary:
	var items := get_tier_map_group_items(tier_map_group_name)
	if items.is_empty():
		return {}
	var current_id := str(highlighted_tier_map_item_id_by_group.get(tier_map_group_name, ""))
	var index := find_item_index(items, current_id)
	if index < 0:
		index = 0
		highlighted_tier_map_item_id_by_group[tier_map_group_name] = str(items[index].get("item_id", ""))
	return items[index]


func move_tier_map_group_item(step: int) -> void:
	var items := get_tier_map_group_items(tier_map_group_name)
	if items.is_empty():
		return
	var current_id := str(highlighted_tier_map_item_id_by_group.get(tier_map_group_name, ""))
	var index := find_item_index(items, current_id)
	if index < 0:
		index = 0
	index = wrap_index(index + step, items.size())
	highlighted_tier_map_item_id_by_group[tier_map_group_name] = str(items[index].get("item_id", ""))
	tier_map_prepared_item_id = ""
	close_coord_auto_popup_from_tier_map()
	ensure_current_tier_map_item_visible("tier_map_item_changed")


func activate_tier_map_group_item() -> void:
	var item := get_current_tier_map_group_item()
	if item.is_empty():
		return

	var item_id := str(item.get("item_id", "")).strip_edges()
	var group_name := str(item.get("tier_map_group", tier_map_group_name))
	if group_name in [TIER_MAP_GROUP_CONTACTS, TIER_MAP_GROUP_BRIDGES]:
		if tier_map_prepared_item_id == item_id and is_coord_auto_pilot_popup_active() and is_button_selectable(get_coord_auto_engage_button()):
			controller_debug("TIER_MAP_X_ENGAGE_PREPARED", {"item": item_id, "button": get_debug_control_name(get_coord_auto_engage_button())})
			if press_button(get_coord_auto_engage_button()):
				tier_map_prepared_item_id = ""
				refresh_tier_map_group_model()
				ensure_tier_map_group_selection(group_name)
				ensure_current_tier_map_item_visible("tier_map_autopilot_engaged")
			return

		controller_debug("TIER_MAP_X_PREPARE_TARGET", {"item": item_id, "control": get_debug_control_name(item.get("node", null))})
		if activate_focus_item(item):
			tier_map_prepared_item_id = item_id
		ensure_current_tier_map_item_visible("tier_map_prepare_target")
		return

	tier_map_prepared_item_id = ""
	close_coord_auto_popup_from_tier_map()
	activate_focus_item(item)
	refresh_tier_map_group_model()
	ensure_tier_map_group_selection(group_name)
	ensure_current_tier_map_item_visible("tier_map_activate")


func close_coord_auto_popup_from_tier_map() -> void:
	if is_coord_auto_pilot_popup_active():
		close_coord_auto_popup_from_local_map()


func close_tier_map_controller_scope() -> void:
	if is_coord_auto_pilot_popup_active():
		close_coord_auto_popup_from_tier_map()

	var close_button: Variant = null
	if gui_state != null:
		close_button = gui_state.buttons.get("main_cockpit_button_close", null)
	if is_button_selectable(close_button):
		press_button(close_button)
	elif main_left_panel_controller != null and is_instance_valid(main_left_panel_controller):
		if main_left_panel_controller.has_method("hide_all_panels"):
			main_left_panel_controller.hide_all_panels()
		elif main_left_panel_controller.has_method("close_current_panel"):
			main_left_panel_controller.close_current_panel()

	tier_map_group_name = TIER_MAP_GROUP_TABS
	tier_map_prepared_item_id = ""
	highlighted_widget_id = WIDGET_ACTION
	pending_widget_focus_id = WIDGET_ACTION
	clear_item_visual_focus()
	last_scroll_ensure_key = ""


func ensure_current_tier_map_item_visible(reason: String = "tier_map_item") -> void:
	var item := get_current_tier_map_group_item()
	if item.is_empty():
		return
	var control_value: Variant = item.get("node", null)
	if not is_live_control(control_value):
		return
	ensure_control_visible_in_scroll(control_value as Control, reason)


func update_tier_map_overlay() -> void:
	if overlay == null or not is_instance_valid(overlay):
		clear_visual_focus()
		return
	var root := get_tier_map_root()
	if root == null:
		update_overlay()
		return
	refresh_tier_map_group_model()
	var item := get_current_tier_map_group_item()
	var selected_control: Variant = item.get("node", null)
	if not is_live_control(selected_control):
		selected_control = null
	clear_top_visual_focus()
	set_visual_focus(selected_control)
	ensure_current_tier_map_item_visible("tier_map_overlay")
	overlay.set_focus_nodes(null, root, selected_control, true, false, true, get_tier_map_controller_hint())



func is_inventory_craft_controller_scope_active() -> bool:
	if is_controller_popup_active():
		return false
	if highlighted_widget_id != WIDGET_LEFT_PANEL:
		return false
	var root := get_inventory_craft_root()
	if root == null:
		return false
	var active_id := get_active_left_panel_id()
	if active_id != "" and active_id != "inventory_craft":
		return false
	return true


func get_active_left_panel_id() -> String:
	if main_left_panel_controller != null and is_instance_valid(main_left_panel_controller) and main_left_panel_controller.has_method("get_active_panel_id"):
		return str(main_left_panel_controller.get_active_panel_id())
	return ""


func get_inventory_craft_root() -> Control:
	if gui_state == null:
		return null
	var root_value: Variant = gui_state.controls.get("inventory_craft_left_root", null)
	if is_control_visible(root_value):
		return root_value as Control
	return null


func handle_inventory_craft_controller_input() -> void:
	refresh_inventory_craft_group_model()
	controller_debug_throttled("inventory_craft_route:" + inventory_craft_group_name + ":" + str(get_inventory_craft_group_items(inventory_craft_group_name).size()), "INVENTORY_CRAFT_ROUTE", {
		"group": inventory_craft_group_name,
		"tabs": get_inventory_craft_group_items(INVENTORY_CRAFT_GROUP_TABS).size(),
		"items": get_inventory_craft_group_items(INVENTORY_CRAFT_GROUP_ITEMS).size(),
		"crafting": get_inventory_craft_group_items(INVENTORY_CRAFT_GROUP_CRAFTING).size(),
		"selected": get_debug_control_name(get_current_inventory_craft_group_item().get("node", null))
	})

	if Input.is_action_just_pressed("controller_top_activate"):
		controller_debug("INVENTORY_CRAFT_TRIANGLE_CLOSE", {"group": inventory_craft_group_name})
		close_inventory_craft_controller_scope()
		return

	if Input.is_action_just_pressed("controller_top_left"):
		controller_debug("INVENTORY_CRAFT_L1", {"before_group": inventory_craft_group_name})
		switch_inventory_craft_group(-1)
		controller_debug("INVENTORY_CRAFT_L1_AFTER", {"after_group": inventory_craft_group_name})
		return

	if Input.is_action_just_pressed("controller_top_right"):
		controller_debug("INVENTORY_CRAFT_R1", {"before_group": inventory_craft_group_name})
		switch_inventory_craft_group(1)
		controller_debug("INVENTORY_CRAFT_R1_AFTER", {"after_group": inventory_craft_group_name})
		return

	if inventory_recycle_action_pressed():
		controller_debug("INVENTORY_CRAFT_SQUARE_RECYCLE", {"group": inventory_craft_group_name, "item": get_current_inventory_craft_group_item()})
		recycle_current_inventory_craft_item()
		return

	if Input.is_action_just_pressed("controller_widget_activate"):
		controller_debug("INVENTORY_CRAFT_X", {"group": inventory_craft_group_name, "item": get_current_inventory_craft_group_item()})
		activate_inventory_craft_group_item()
		return

	var move_step := get_inventory_craft_dpad_step()
	if move_step != 0 and can_repeat("inventory_craft_navigation"):
		controller_debug("INVENTORY_CRAFT_MOVE", {"group": inventory_craft_group_name, "step": move_step, "before": get_current_inventory_craft_group_item()})
		move_inventory_craft_group_item(move_step)
		controller_debug("INVENTORY_CRAFT_MOVE_AFTER", {"group": inventory_craft_group_name, "after": get_current_inventory_craft_group_item()})
	else:
		reset_repeat("inventory_craft_navigation")


func inventory_recycle_action_pressed() -> bool:
	return is_action_just_pressed_safe("controller_inventory_recycle") or is_action_just_pressed_safe("controller_widget_secondary") or is_action_just_pressed_safe("controller_square")


func get_inventory_craft_dpad_step() -> int:
	var horizontal := get_action_strength_safe("controller_widget_item_right") - get_action_strength_safe("controller_widget_item_left")
	var vertical := get_action_strength_safe("controller_widget_item_down") - get_action_strength_safe("controller_widget_item_up")

	# Fallback for projects that have not separated D-pad into item-only actions yet.
	if abs(horizontal) < controller_deadzone and abs(vertical) < controller_deadzone:
		horizontal = get_action_strength_safe("controller_widget_nav_right") - get_action_strength_safe("controller_widget_nav_left")
		vertical = get_action_strength_safe("controller_widget_nav_down") - get_action_strength_safe("controller_widget_nav_up")

	if abs(horizontal) < controller_deadzone and abs(vertical) < controller_deadzone:
		return 0

	if abs(horizontal) >= abs(vertical):
		return 1 if horizontal > 0.0 else -1
	return 1 if vertical > 0.0 else -1


func get_inventory_craft_group_order() -> Array:
	return [INVENTORY_CRAFT_GROUP_TABS, INVENTORY_CRAFT_GROUP_ITEMS, INVENTORY_CRAFT_GROUP_CRAFTING]


func switch_inventory_craft_group(step: int) -> void:
	var groups := get_inventory_craft_group_order()
	var index := groups.find(inventory_craft_group_name)
	if index < 0:
		index = 0

	for attempt in range(groups.size()):
		index = wrap_index(index + step, groups.size())
		var group_name := str(groups[index])
		if get_inventory_craft_group_items(group_name).is_empty():
			continue
		inventory_craft_group_name = group_name
		ensure_inventory_craft_group_selection(group_name)
		ensure_current_inventory_craft_item_visible("inventory_craft_group_changed")
		return


func refresh_inventory_craft_group_model() -> void:
	var groups := {
		INVENTORY_CRAFT_GROUP_TABS: [],
		INVENTORY_CRAFT_GROUP_ITEMS: [],
		INVENTORY_CRAFT_GROUP_CRAFTING: []
	}

	var root := get_inventory_craft_root()
	if root == null:
		inventory_craft_group_items = groups
		return

	var label_root := find_inventory_label_root(root)
	if label_root != null:
		collect_inventory_label_group_items(label_root, groups)

	var blueprint_root := find_inventory_blueprint_root(root)
	if blueprint_root != null:
		collect_inventory_crafting_group_items(blueprint_root, groups)

	inventory_craft_group_items = groups

	if get_inventory_craft_group_items(inventory_craft_group_name).is_empty():
		for group_name in get_inventory_craft_group_order():
			if not get_inventory_craft_group_items(str(group_name)).is_empty():
				inventory_craft_group_name = str(group_name)
				break

	for group_name in get_inventory_craft_group_order():
		ensure_inventory_craft_group_selection(str(group_name))


func find_inventory_label_root(root: Control) -> Control:
	for name_text in ["label_inventory_root", "label_inventory_widget_root", "label_inventory", "inventory_label_root", "inventory_root"]:
		var found := find_visible_control_by_name(root, name_text)
		if found != null:
			return found
	return root


func find_inventory_blueprint_root(root: Control) -> Control:
	if gui_state != null:
		var blueprint_value: Variant = gui_state.controls.get("blueprint_root", null)
		if is_control_visible(blueprint_value):
			return blueprint_value as Control
	for name_text in ["blueprint_root", "blueprint_widget", "crafting_root", "craft_root"]:
		var found := find_visible_control_by_name(root, name_text)
		if found != null:
			return found
	return null


func find_visible_control_by_name(root: Variant, wanted_name: String) -> Control:
	if root == null or not is_instance_valid(root):
		return null
	if not (root is Node):
		return null
	if root is Control:
		var control := root as Control
		if control.name == wanted_name and control.is_visible_in_tree():
			return control
	for child in (root as Node).get_children():
		var found := find_visible_control_by_name(child, wanted_name)
		if found != null:
			return found
	return null


func collect_inventory_label_group_items(label_root: Control, groups: Dictionary) -> void:
	var buttons: Array = []
	collect_button_items_recursive(label_root, buttons, "inventory")
	for raw_item in buttons:
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item
		var button_value: Variant = item.get("node", null)
		if not is_button_selectable(button_value):
			continue
		var clean_item := make_inventory_craft_item(button_value, "inventory")
		if is_inventory_tab_button(button_value):
			append_inventory_craft_group_item(groups, INVENTORY_CRAFT_GROUP_TABS, clean_item)
		else:
			append_inventory_craft_group_item(groups, INVENTORY_CRAFT_GROUP_ITEMS, clean_item)


func collect_inventory_crafting_group_items(blueprint_root: Control, groups: Dictionary) -> void:
	var crafting_items: Array = []
	var button_list := find_visible_control_by_name(blueprint_root, "blueprint_button_list")
	if button_list != null:
		collect_button_items_recursive(button_list, crafting_items, "inventory_crafting")
	else:
		collect_button_items_recursive(blueprint_root, crafting_items, "inventory_crafting")

	var build_button: Variant = null
	if gui_state != null:
		build_button = gui_state.buttons.get("blueprint_build_button", null)
	if not is_button_selectable(build_button):
		build_button = find_named_button_recursive(blueprint_root, ["blueprint_build_button", "build", "craft"])
	if is_button_selectable(build_button):
		crafting_items.append(make_button_item(build_button, "inventory_crafting"))

	for raw_item in crafting_items:
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item
		var node_value: Variant = item.get("node", null)
		if not is_button_selectable(node_value):
			continue
		append_inventory_craft_group_item(groups, INVENTORY_CRAFT_GROUP_CRAFTING, make_inventory_craft_item(node_value, "inventory_crafting"))


func make_inventory_craft_item(control_value: Variant, prefix: String) -> Dictionary:
	var base_item := make_button_item(control_value, prefix)
	var node_name := str((control_value as Node).name) if control_value is Node else "control"
	base_item["item_id"] = prefix + ":" + node_name + ":" + str(control_value.get_instance_id())
	if control_value.has_meta("controller_focus_id"):
		base_item["item_id"] = str(control_value.get_meta("controller_focus_id"))
	base_item["inventory_item_id"] = extract_inventory_item_id_from_control(control_value)
	return base_item


func is_inventory_tab_button(button_value: Variant) -> bool:
	if not is_button_selectable(button_value):
		return false
	var button := button_value as BaseButton
	var name_text := str(button.name).to_lower()
	var button_text := str(button.text).strip_edges().to_lower()
	var meta_text := ""
	if button.has_meta("controller_focus_id"):
		meta_text += " " + str(button.get_meta("controller_focus_id")).to_lower()
	for meta_name in ["tab_id", "category", "label", "filter"]:
		if button.has_meta(meta_name):
			meta_text += " " + str(button.get_meta(meta_name)).to_lower()
	var parent_text := build_parent_name_text(button, 3).to_lower()
	var joined := name_text + " " + button_text + " " + meta_text + " " + parent_text

	if joined.find("tab") >= 0 or joined.find("category") >= 0 or joined.find("filter") >= 0:
		return true
	if joined.find("item_row") >= 0 or joined.find("item_button") >= 0 or joined.find("slot") >= 0 or joined.find("blueprint") >= 0:
		return false

	var known_tab_texts := ["all", "items", "gear", "weapons", "weapon", "ammo", "resources", "resource", "mats", "materials", "recov", "recovery", "blueprints", "mods", "ship", "drone", "drones", "tools", "quest", "misc"]
	if button_text in known_tab_texts:
		return true
	if button_text.length() <= 12 and button_text != "" and button_text.find(" ") < 0 and parent_text.find("tab") >= 0:
		return true
	return false


func build_parent_name_text(node_value: Node, max_depth: int = 3) -> String:
	var parts: Array = []
	var parent := node_value.get_parent()
	var depth := 0
	while parent != null and is_instance_valid(parent) and depth < max_depth:
		parts.append(str(parent.name))
		parent = parent.get_parent()
		depth += 1
	return " ".join(parts)


func find_named_button_recursive(root: Variant, name_fragments: Array) -> BaseButton:
	if root == null or not is_instance_valid(root):
		return null
	if not (root is Node):
		return null
	for child in (root as Node).get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child is Control and not (child as Control).is_visible_in_tree():
			continue
		if child is BaseButton and is_button_selectable(child):
			var haystack := str(child.name).to_lower() + " " + str((child as BaseButton).text).to_lower()
			for fragment in name_fragments:
				if haystack.find(str(fragment).to_lower()) >= 0:
					return child as BaseButton
		if child is Node:
			var found := find_named_button_recursive(child, name_fragments)
			if found != null:
				return found
	return null


func get_inventory_craft_group_items(group_name: String) -> Array:
	var raw_items: Variant = inventory_craft_group_items.get(group_name, [])
	if raw_items is Array:
		return raw_items as Array
	return []


func append_inventory_craft_group_item(groups: Dictionary, group_name: String, item: Dictionary) -> void:
	if item.is_empty():
		return
	if not groups.has(group_name):
		groups[group_name] = []
	var items: Array = groups[group_name]
	items.append(item)
	groups[group_name] = items


func ensure_inventory_craft_group_selection(group_name: String) -> void:
	var items := get_inventory_craft_group_items(group_name)
	if items.is_empty():
		highlighted_inventory_craft_item_id_by_group[group_name] = ""
		return
	var current_id := str(highlighted_inventory_craft_item_id_by_group.get(group_name, ""))
	if current_id == "" or find_item_index(items, current_id) < 0:
		highlighted_inventory_craft_item_id_by_group[group_name] = str(items[0].get("item_id", ""))


func get_current_inventory_craft_group_item() -> Dictionary:
	var items := get_inventory_craft_group_items(inventory_craft_group_name)
	if items.is_empty():
		return {}
	var current_id := str(highlighted_inventory_craft_item_id_by_group.get(inventory_craft_group_name, ""))
	var index := find_item_index(items, current_id)
	if index < 0:
		index = 0
		highlighted_inventory_craft_item_id_by_group[inventory_craft_group_name] = str(items[index].get("item_id", ""))
	return items[index]


func move_inventory_craft_group_item(step: int) -> void:
	var items := get_inventory_craft_group_items(inventory_craft_group_name)
	if items.is_empty():
		return
	var current_id := str(highlighted_inventory_craft_item_id_by_group.get(inventory_craft_group_name, ""))
	var index := find_item_index(items, current_id)
	if index < 0:
		index = 0
	index = wrap_index(index + step, items.size())
	highlighted_inventory_craft_item_id_by_group[inventory_craft_group_name] = str(items[index].get("item_id", ""))
	ensure_current_inventory_craft_item_visible("inventory_craft_item_changed")


func activate_inventory_craft_group_item() -> void:
	var item := get_current_inventory_craft_group_item()
	if item.is_empty():
		return
	activate_focus_item(item)
	ensure_current_inventory_craft_item_visible("inventory_craft_activate")


func recycle_current_inventory_craft_item() -> void:
	if inventory_craft_group_name != INVENTORY_CRAFT_GROUP_ITEMS:
		controller_debug("INVENTORY_CRAFT_RECYCLE_BLOCKED_GROUP", {"group": inventory_craft_group_name})
		return
	var item := get_current_inventory_craft_group_item()
	if item.is_empty():
		return
	var control_value: Variant = item.get("node", null)
	if not is_button_selectable(control_value):
		return

	# Select the item first, preserving existing inventory behavior.
	press_button(control_value)

	var item_id := str(item.get("inventory_item_id", "")).strip_edges()
	if item_id == "":
		item_id = extract_inventory_item_id_from_control(control_value)

	if try_recycle_inventory_slot(control_value):
		controller_debug("INVENTORY_CRAFT_RECYCLE_OK", {"item_id": item_id, "control": get_debug_control_name(control_value), "route": "slot"})
		return

	if try_recycle_inventory_item(item_id, control_value):
		controller_debug("INVENTORY_CRAFT_RECYCLE_OK", {"item_id": item_id, "control": get_debug_control_name(control_value)})
		return

	controller_debug("INVENTORY_CRAFT_RECYCLE_NO_ENDPOINT", {
		"item_id": item_id,
		"control": get_debug_control_name(control_value),
		"note": "No recycle method/button was found. Upload Inventory5.gd if this prints."
	})


func try_recycle_inventory_slot(control_value: Variant) -> bool:
	if control_value == null or not is_instance_valid(control_value):
		return false
	if not control_value.has_meta("container_name") or not control_value.has_meta("slot_name"):
		return false

	var container_name := str(control_value.get_meta("container_name")).strip_edges()
	var slot_name := str(control_value.get_meta("slot_name")).strip_edges()
	if container_name == "" or slot_name == "":
		return false

	var inv: Variant = get_inventory_ref()
	if inv == null or not is_instance_valid(inv):
		return false
	if not inv.has_method("recycle_slot_item"):
		return false
	return bool(inv.recycle_slot_item(container_name, slot_name))


func try_recycle_inventory_item(item_id: String, control_value: Variant) -> bool:
	var root := get_inventory_craft_root()
	if root != null:
		var recycle_button := find_named_button_recursive(root, ["recycle", "scrap", "trash", "discard"])
		if is_button_selectable(recycle_button):
			return press_button(recycle_button)

	var inv: Variant = get_inventory_ref()
	for target in [inv, main_scene]:
		if target == null or not is_instance_valid(target):
			continue
		for method_name in ["controller_recycle_selected_inventory_item", "recycle_selected_inventory_item", "send_selected_item_to_recycle", "request_recycle_selected_item"]:
			if target.has_method(method_name):
				target.call(method_name)
				return true
		if item_id != "":
			for method_name in ["controller_recycle_inventory_item", "recycle_inventory_item", "send_item_to_recycle", "request_recycle_item", "recycle_item"]:
				if target.has_method(method_name):
					target.call(method_name, item_id)
					return true
		for method_name in ["controller_recycle_inventory_control", "recycle_inventory_control"]:
			if target.has_method(method_name):
				target.call(method_name, control_value)
				return true
	return false


func get_inventory_ref() -> Variant:
	if gui_state != null:
		var inv_value: Variant = gui_state.get("inventory")
		if inv_value != null and is_instance_valid(inv_value):
			return inv_value
	if main_scene != null and is_instance_valid(main_scene):
		var inv_from_scene: Variant = main_scene.get("inventory")
		if inv_from_scene != null and is_instance_valid(inv_from_scene):
			return inv_from_scene
	return null


func extract_inventory_item_id_from_control(control_value: Variant) -> String:
	if control_value == null or not is_instance_valid(control_value):
		return ""
	for meta_name in ["item_id", "inventory_item_id", "controller_item_id", "slot_item_id", "source_item_id", "id"]:
		if control_value.has_meta(meta_name):
			var meta_value := str(control_value.get_meta(meta_name)).strip_edges()
			if meta_value != "":
				return meta_value
	if control_value is BaseButton:
		for meta_name in ["item_data", "packet", "inventory_packet"]:
			if control_value.has_meta(meta_name):
				var packet_value: Variant = control_value.get_meta(meta_name)
				if packet_value is Dictionary:
					for key_name in ["item_id", "id", "inventory_item_id"]:
						var item_id := str((packet_value as Dictionary).get(key_name, "")).strip_edges()
						if item_id != "":
							return item_id
	return ""


func close_inventory_craft_controller_scope() -> void:
	var close_button: Variant = null
	if gui_state != null:
		close_button = gui_state.buttons.get("main_cockpit_button_close", null)
	if is_button_selectable(close_button):
		press_button(close_button)
	elif main_left_panel_controller != null and is_instance_valid(main_left_panel_controller):
		if main_left_panel_controller.has_method("hide_all_panels"):
			main_left_panel_controller.hide_all_panels()
		elif main_left_panel_controller.has_method("close_current_panel"):
			main_left_panel_controller.close_current_panel()

	inventory_craft_group_name = INVENTORY_CRAFT_GROUP_TABS
	highlighted_widget_id = WIDGET_ACTION
	pending_widget_focus_id = WIDGET_ACTION
	clear_item_visual_focus()
	last_scroll_ensure_key = ""


func ensure_current_inventory_craft_item_visible(reason: String = "inventory_craft_item") -> void:
	var item := get_current_inventory_craft_group_item()
	if item.is_empty():
		return
	var control_value: Variant = item.get("node", null)
	if not is_live_control(control_value):
		return
	ensure_control_visible_in_scroll(control_value as Control, reason)


func update_inventory_craft_overlay() -> void:
	if overlay == null or not is_instance_valid(overlay):
		clear_visual_focus()
		return
	var root := get_inventory_craft_root()
	if root == null:
		update_overlay()
		return
	refresh_inventory_craft_group_model()
	var item := get_current_inventory_craft_group_item()
	var selected_control: Variant = item.get("node", null)
	if not is_live_control(selected_control):
		selected_control = null
	clear_top_visual_focus()
	set_visual_focus(selected_control)
	ensure_current_inventory_craft_item_visible("inventory_craft_overlay")
	overlay.set_focus_nodes(null, root, selected_control, true, false, true, get_inventory_craft_controller_hint())

func refresh_focus_model() -> void:
	top_bar_items = collect_top_bar_items()
	if highlighted_top_bar_id == "" or find_item_index(top_bar_items, highlighted_top_bar_id) < 0:
		highlighted_top_bar_id = str(top_bar_items[0].get("item_id", "")) if not top_bar_items.is_empty() else ""

	widgets = collect_widgets()
	if widgets.is_empty():
		highlighted_widget_id = ""
		return

	if pending_widget_focus_id != "" and find_widget_index(pending_widget_focus_id) >= 0:
		highlighted_widget_id = pending_widget_focus_id
		pending_widget_focus_id = ""
	elif highlighted_widget_id == "" or find_widget_index(highlighted_widget_id) < 0:
		highlighted_widget_id = str(widgets[0].get("widget_id", ""))

	ensure_widget_item_selection()


func collect_top_bar_items() -> Array:
	var supplied_output: Array = []
	if main_left_panel_controller != null and main_left_panel_controller.has_method("get_controller_top_bar_items"):
		var supplied_items: Variant = main_left_panel_controller.get_controller_top_bar_items()
		if supplied_items is Array:
			supplied_output = sanitize_focus_items(supplied_items as Array)
			controller_debug_throttled("top_supplied:" + str(supplied_output.size()), "TOP_SUPPLIED", {
				"raw_count": (supplied_items as Array).size(),
				"valid_count": supplied_output.size(),
				"items": summarize_focus_items(supplied_output)
			})

	var fallback_output: Array = collect_fallback_top_bar_items()
	var discovered_output: Array = collect_discovered_top_bar_items()
	var output: Array = []
	append_unique_focus_items(output, supplied_output)
	append_unique_focus_items(output, discovered_output)
	append_unique_focus_items(output, fallback_output)

	# If the left panel supplied only the default command button, keep trying the
	# fallback/discovered paths so L1/R1 has real top-strip targets to move through.
	controller_debug_throttled("top_collect:" + str(output.size()) + ":" + highlighted_top_bar_id, "TOP_COLLECT", {
		"supplied": summarize_focus_items(supplied_output),
		"discovered": summarize_focus_items(discovered_output),
		"fallback": summarize_focus_items(fallback_output),
		"final": summarize_focus_items(output)
	})
	return output


func collect_fallback_top_bar_items() -> Array:
	var output: Array = []
	if gui_state == null:
		return output

	var fallback_names := [
		"main_cockpit_button_command",
		"main_cockpit_button_local_map",
		"main_cockpit_button_flat_map",
		"main_cockpit_button_tier_map",
		"main_cockpit_button_inventory_craft",
		"main_cockpit_button_story_log",
		"main_cockpit_button_loadout",
		"main_cockpit_button_close"
	]
	for button_name in fallback_names:
		var button = gui_state.buttons.get(button_name, null)
		if is_button_selectable(button):
			output.append(make_button_item(button, "top"))
	return output


func collect_discovered_top_bar_items() -> Array:
	var output: Array = []
	if gui_state == null:
		return output
	var roots: Array = []
	var possible_control_keys := [
		"main_top_strip_root",
		"main_top_strip",
		"top_strip_root",
		"main_left_panel_top_strip",
		"main_left_panel_button_rail",
		"main_left_panel_shell"
	]
	for key in possible_control_keys:
		var value: Variant = gui_state.controls.get(key, null)
		if is_control_visible(value):
			roots.append(value)

	if main_left_panel_controller != null and is_instance_valid(main_left_panel_controller):
		for prop_name in ["top_strip_root", "button_rail", "button_rail_root", "top_button_rail", "top_strip"]:
			var prop_value: Variant = main_left_panel_controller.get(prop_name)
			if is_control_visible(prop_value):
				roots.append(prop_value)

	for root in roots:
		collect_button_items_recursive(root, output, "top_discovered")
	return sanitize_focus_items(output)


func sanitize_focus_items(source_items: Array) -> Array:
	var output: Array = []
	append_unique_focus_items(output, source_items)
	return output


func append_unique_focus_items(output: Array, source_items: Array) -> void:
	for raw_item in source_items:
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item
		var node_value: Variant = item.get("node", null)
		if not is_button_selectable(node_value):
			continue
		var item_id := str(item.get("item_id", "")).strip_edges()
		if item_id == "":
			item_id = "top:" + str((node_value as Node).name)
		if find_item_index(output, item_id) >= 0:
			continue
		var clean_item: Dictionary = item.duplicate(true)
		clean_item["item_id"] = item_id
		output.append(clean_item)


func summarize_focus_items(items: Array) -> Array:
	var summary: Array = []
	for raw_item in items:
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item
		var node_value: Variant = item.get("node", null)
		summary.append(str(item.get("item_id", "")) + "|" + str(item.get("display_name", "")) + "|" + get_debug_control_name(node_value))
	return summary

func collect_widgets() -> Array:
	var output: Array = []
	if gui_state == null:
		return output

	add_left_panel_widget(output)
	add_action_widget(output)
	add_event_widget(output)
	add_port_widget(output)
	return output


func add_left_panel_widget(output: Array) -> void:
	var shell = gui_state.controls.get("main_left_panel_shell", null)
	if not is_control_visible(shell):
		return

	var active_id := ""
	if main_left_panel_controller != null and main_left_panel_controller.has_method("get_active_panel_id"):
		active_id = str(main_left_panel_controller.get_active_panel_id())
	if active_id == "":
		return

	var items: Array = []
	if active_id == "local_map":
		collect_live_map_marker_items(items)
	collect_button_items_recursive(shell, items, "left_panel")
	add_widget(output, WIDGET_LEFT_PANEL, "Left Panel", shell, items)


func add_action_widget(output: Array) -> void:
	var root = gui_state.action_storage.get("root", null)
	if not is_control_visible(root):
		return

	var items: Array = []
	var button_list = gui_state.action_storage.get("button_list", null)
	if is_control_visible(button_list):
		collect_button_items_recursive(button_list, items, "action")
	add_widget(output, WIDGET_ACTION, "Actions", root, items)


func add_event_widget(output: Array) -> void:
	var root = gui_state.controls.get("event_root", null)
	if not is_control_visible(root):
		return

	var items: Array = []
	for list_key in ["event_action_button_list", "event_utility_button_wrap"]:
		var list_node = gui_state.controls.get(list_key, null)
		if is_control_visible(list_node):
			collect_button_items_recursive(list_node, items, "event")
	add_widget(output, WIDGET_EVENT, "Event", root, items)


func add_port_widget(output: Array) -> void:
	if is_control_visible(port_window):
		add_widget(output, WIDGET_PORT, "Port View", port_window, [])


func add_widget(output: Array, widget_id: String, display_name: String, node_value: Variant, items: Array) -> void:
	if not is_control_visible(node_value):
		return
	output.append({
		"widget_id": widget_id,
		"display_name": display_name,
		"node": node_value,
		"items": items
	})


func collect_button_items_recursive(root: Variant, output: Array, prefix: String) -> void:
	if root == null or not is_instance_valid(root):
		return
	if not (root is Node):
		return

	for child in (root as Node).get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child is Control and not (child as Control).is_visible_in_tree():
			continue
		if child is BaseButton and is_button_selectable(child):
			output.append(make_button_item(child, prefix))
		if child is Node and (child as Node).get_child_count() > 0:
			collect_button_items_recursive(child, output, prefix)


func make_button_item(button: Variant, prefix: String) -> Dictionary:
	var focus_id := ""
	if button != null and is_instance_valid(button) and button.has_meta("controller_focus_id"):
		focus_id = str(button.get_meta("controller_focus_id"))
	if focus_id == "":
		focus_id = prefix + ":" + str(button.name)

	var display_name := str(button.get("text"))
	if display_name == "":
		display_name = str(button.name)

	return {
		"item_id": focus_id,
		"display_name": display_name,
		"kind": "button",
		"node": button,
		"enabled": is_button_selectable(button)
	}


func collect_live_map_marker_items(output: Array) -> void:
	if live_map_control == null or not is_instance_valid(live_map_control):
		return
	if not is_control_visible(live_map_control):
		return

	var live_widget = live_map_control.widget
	if live_widget == null or not is_instance_valid(live_widget):
		return

	var marker_layer = live_widget.marker_layer
	if not is_control_visible(marker_layer):
		return

	var index := 0
	for child in marker_layer.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if not is_control_visible(child):
			continue
		if not (child is LiveMapMarker):
			continue

		var marker := child as LiveMapMarker
		var packet: Dictionary = marker.packet.duplicate(true)
		var marker_id := str(packet.get("id", packet.get("owner", marker.name))).strip_edges()
		var display_name := str(packet.get("display_name", marker_id)).strip_edges()
		if display_name == "":
			display_name = str(marker.name)

		output.append({
			"item_id": "live_map_marker:" + marker_id + ":" + str(index),
			"display_name": display_name,
			"kind": "live_map_marker",
			"node": marker,
			"packet": packet,
			"enabled": true
		})
		index += 1


func filter_live_items(items: Array) -> Array:
	var output: Array = []
	for raw_item in items:
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item
		var node_value: Variant = item.get("node", null)
		if not is_live_control(node_value):
			continue
		if bool(item.get("enabled", true)) == false:
			continue
		output.append(item)
	return output



func is_control_visible(value: Variant) -> bool:
	if value == null or not is_instance_valid(value):
		return false
	if not (value is Control):
		return false
	return (value as Control).is_visible_in_tree()


func is_button_selectable(value: Variant) -> bool:
	if value == null or not is_instance_valid(value):
		return false
	if not (value is BaseButton):
		return false
	var button := value as BaseButton
	if not button.is_visible_in_tree():
		return false
	if button.disabled:
		return false
	return true


func move_top_bar_highlight(step: int) -> void:
	if top_bar_items.is_empty():
		controller_debug("TOP_MOVE_BLOCKED_EMPTY", {})
		return
	var index := find_item_index(top_bar_items, highlighted_top_bar_id)
	if index < 0:
		index = 0
	var before_id := highlighted_top_bar_id
	index = wrap_index(index + step, top_bar_items.size())
	highlighted_top_bar_id = str(top_bar_items[index].get("item_id", ""))
	controller_debug("TOP_MOVE", {"step": step, "before": before_id, "after": highlighted_top_bar_id, "count": top_bar_items.size()})


func activate_highlighted_top_bar_item() -> void:
	var item := get_current_top_bar_item()
	if item.is_empty():
		controller_debug("TOP_ACTIVATE_BLOCKED_EMPTY", {})
		return
	var button = item.get("node", null)
	controller_debug("TOP_ACTIVATE", {"id": highlighted_top_bar_id, "button": get_debug_control_name(button), "item": item})
	if not press_button(button):
		controller_debug("TOP_ACTIVATE_PRESS_FAILED", {"button": get_debug_control_name(button)})
		return

	var panel_id := str(item.get("panel_id", ""))
	if panel_id != "":
		pending_widget_focus_id = WIDGET_LEFT_PANEL
	else:
		pending_widget_focus_id = WIDGET_ACTION


func move_widget_highlight(step: int) -> void:
	if widgets.is_empty():
		return
	var index := find_widget_index(highlighted_widget_id)
	if index < 0:
		index = 0
	index = wrap_index(index + step, widgets.size())
	highlighted_widget_id = str(widgets[index].get("widget_id", ""))
	ensure_widget_item_selection()
	last_scroll_ensure_key = ""
	ensure_current_widget_item_visible("widget_focus_changed")


func move_widget_item_highlight(step: int) -> void:
	var widget := get_current_widget()
	if widget.is_empty():
		return
	var items: Array = widget.get("items", [])
	if items.is_empty():
		return

	var widget_id := str(widget.get("widget_id", ""))
	var current_id := str(highlighted_item_id_by_widget.get(widget_id, ""))
	var index := find_item_index(items, current_id)
	if index < 0:
		index = 0
	index = wrap_index(index + step, items.size())
	highlighted_item_id_by_widget[widget_id] = str(items[index].get("item_id", ""))
	ensure_current_widget_item_visible("widget_item_changed")


func activate_highlighted_widget_item() -> void:
	var item := get_current_widget_item()
	if item.is_empty():
		return
	activate_focus_item(item)


func ensure_widget_item_selection() -> void:
	var widget := get_current_widget()
	if widget.is_empty():
		return

	var widget_id := str(widget.get("widget_id", ""))
	var items: Array = widget.get("items", [])
	if items.is_empty():
		highlighted_item_id_by_widget[widget_id] = ""
		return

	var current_id := str(highlighted_item_id_by_widget.get(widget_id, ""))
	if current_id == "" or find_item_index(items, current_id) < 0:
		highlighted_item_id_by_widget[widget_id] = str(items[0].get("item_id", ""))


func press_button(button_value: Variant) -> bool:
	if not is_button_selectable(button_value):
		controller_debug("PRESS_BUTTON_BLOCKED", {"button": get_debug_control_name(button_value)})
		return false
	var button := button_value as BaseButton
	controller_debug("PRESS_BUTTON", {"button": get_debug_control_name(button), "text": str(button.text)})
	button.emit_signal("pressed")
	return true


func activate_focus_item(item: Dictionary) -> bool:
	if item.is_empty():
		return false

	var kind := str(item.get("kind", "button"))
	match kind:
		"button":
			return press_button(item.get("node", null))
		"live_map_marker":
			return activate_live_map_marker(item)
		"popup_numeric", "popup_slider":
			popup_edit_item_id = str(item.get("item_id", ""))
			focus_control(item.get("node", null))
			return true
		_:
			return false


func activate_live_map_marker(item: Dictionary) -> bool:
	var marker = item.get("node", null)
	if marker == null or not is_instance_valid(marker):
		return false
	if not marker.has_signal("clicked"):
		return false
	var packet: Dictionary = item.get("packet", {}) if typeof(item.get("packet", {})) == TYPE_DICTIONARY else {}
	marker.emit_signal("clicked", packet)
	return true


func focus_control(control_value: Variant) -> void:
	if control_value == null or not is_instance_valid(control_value):
		return
	if control_value is Control:
		var control := control_value as Control
		control.grab_focus()
		ensure_control_visible_in_scroll(control)


func ensure_current_widget_item_visible(reason: String = "current_widget_item") -> void:
	if not controller_active:
		return
	if is_controller_popup_active():
		return

	var item: Dictionary = get_current_widget_item()
	if item.is_empty():
		return

	var control_value: Variant = item.get("node", null)
	if not is_live_control(control_value):
		return

	var control := control_value as Control
	var scroll := find_parent_scroll_container(control)
	if scroll == null or not is_instance_valid(scroll):
		return

	var key := highlighted_widget_id + "|" + str(item.get("item_id", "")) + "|" + str(control.get_instance_id())
	var now := Time.get_ticks_msec()
	if key == last_scroll_ensure_key and now - last_scroll_ensure_msec < 120:
		return

	last_scroll_ensure_key = key
	last_scroll_ensure_msec = now
	ensure_control_visible_in_scroll(control, reason)


func ensure_control_visible_in_scroll(control: Control, reason: String = "controller_focus") -> void:
	if control == null or not is_instance_valid(control):
		return

	var scroll := find_parent_scroll_container(control)
	if scroll == null or not is_instance_valid(scroll):
		return

	# Use Godot's native helper first, then apply a conservative manual nudge.
	# The manual nudge helps with nested VBox/HBox rows where focus visuals move
	# but the ScrollContainer does not automatically follow the selected row.
	if scroll.has_method("ensure_control_visible"):
		scroll.ensure_control_visible(control)

	nudge_scroll_container_to_control(scroll, control, reason)
	call_deferred("_deferred_ensure_control_visible_in_scroll", control, reason)


func _deferred_ensure_control_visible_in_scroll(control_value: Variant, reason: String = "controller_focus_deferred") -> void:
	if not is_live_control(control_value):
		return
	var control := control_value as Control
	var scroll := find_parent_scroll_container(control)
	if scroll == null or not is_instance_valid(scroll):
		return
	nudge_scroll_container_to_control(scroll, control, reason)


func find_parent_scroll_container(control: Control) -> ScrollContainer:
	var parent: Node = control.get_parent()
	while parent != null:
		if not is_instance_valid(parent):
			return null
		if parent is ScrollContainer:
			return parent as ScrollContainer
		parent = parent.get_parent()
	return null


func nudge_scroll_container_to_control(scroll: ScrollContainer, control: Control, reason: String = "controller_focus") -> void:
	if scroll == null or control == null:
		return
	if not is_instance_valid(scroll) or not is_instance_valid(control):
		return

	var scroll_rect: Rect2 = scroll.get_global_rect()
	var control_rect: Rect2 = control.get_global_rect()
	if scroll_rect.size.x <= 0.0 or scroll_rect.size.y <= 0.0 or control_rect.size.x <= 0.0 or control_rect.size.y <= 0.0:
		return

	var margin := 10.0
	var changed := false

	if scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		var visible_top := scroll_rect.position.y + margin
		var visible_bottom := scroll_rect.position.y + scroll_rect.size.y - margin
		var control_top := control_rect.position.y
		var control_bottom := control_rect.position.y + control_rect.size.y
		var new_vertical: int = int(scroll.scroll_vertical)

		if control_top < visible_top:
			new_vertical += int(floor(control_top - visible_top))
			changed = true
		elif control_bottom > visible_bottom:
			new_vertical += int(ceil(control_bottom - visible_bottom))
			changed = true

		if changed:
			scroll.scroll_vertical = max(0, new_vertical)

	if scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		var visible_left := scroll_rect.position.x + margin
		var visible_right := scroll_rect.position.x + scroll_rect.size.x - margin
		var control_left := control_rect.position.x
		var control_right := control_rect.position.x + control_rect.size.x
		var new_horizontal: int = int(scroll.scroll_horizontal)
		var horizontal_changed := false

		if control_left < visible_left:
			new_horizontal += int(floor(control_left - visible_left))
			horizontal_changed = true
		elif control_right > visible_right:
			new_horizontal += int(ceil(control_right - visible_right))
			horizontal_changed = true

		if horizontal_changed:
			scroll.scroll_horizontal = max(0, new_horizontal)
			changed = true

	if changed:
		controller_debug("SCROLL_ENSURE", {
			"reason": reason,
			"scroll": get_debug_control_name(scroll),
			"control": get_debug_control_name(control),
			"v": scroll.scroll_vertical,
			"h": scroll.scroll_horizontal
		})


func get_current_top_bar_item() -> Dictionary:
	if top_bar_items.is_empty():
		return {}
	var index := find_item_index(top_bar_items, highlighted_top_bar_id)
	if index < 0:
		index = 0
	return top_bar_items[index]


func get_current_widget() -> Dictionary:
	if widgets.is_empty():
		return {}
	var index := find_widget_index(highlighted_widget_id)
	if index < 0:
		index = 0
		highlighted_widget_id = str(widgets[index].get("widget_id", ""))
	return widgets[index]


func get_current_widget_item() -> Dictionary:
	var widget := get_current_widget()
	if widget.is_empty():
		return {}
	var widget_id := str(widget.get("widget_id", ""))
	var items: Array = widget.get("items", [])
	if items.is_empty():
		return {}

	var current_id := str(highlighted_item_id_by_widget.get(widget_id, ""))
	var index := find_item_index(items, current_id)
	if index < 0:
		index = 0
	return items[index]


func find_widget_index(widget_id: String) -> int:
	for i in range(widgets.size()):
		if str(widgets[i].get("widget_id", "")) == widget_id:
			return i
	return -1


func find_item_index(items: Array, item_id: String) -> int:
	for i in range(items.size()):
		if str(items[i].get("item_id", "")) == item_id:
			return i
	return -1


func wrap_index(index: int, size_value: int) -> int:
	if size_value <= 0:
		return 0
	return int(posmod(index, size_value))


func can_repeat(key: String) -> bool:
	var now := Time.get_ticks_msec()
	var data: Dictionary = repeat_state.get(key, {})
	var last_msec := int(data.get("last_msec", 0))
	var active := bool(data.get("active", false))
	var wait_seconds := controller_repeat_delay if active else controller_initial_repeat_delay
	if now - last_msec < int(wait_seconds * 1000.0):
		return false
	repeat_state[key] = {
		"last_msec": now,
		"active": true
	}
	return true


func reset_repeat(key: String) -> void:
	repeat_state.erase(key)


func update_overlay() -> void:
	if overlay == null or not is_instance_valid(overlay):
		clear_visual_focus()
		return
	if not controller_active:
		clear_visual_focus()
		overlay.clear_focus()
		return

	var top_item := get_current_top_bar_item()
	var widget := get_current_widget()
	var item := get_current_widget_item()
	set_top_visual_focus(top_item.get("node", null))
	set_visual_focus(item.get("node", null))
	ensure_current_widget_item_visible("overlay_update")
	var navigation_guidance_enabled := false
	var top_bar_count = max(0, top_bar_items.size() - 1)
	var widget_item_count := 0
	if widget is Dictionary:
		widget_item_count = int(Array(widget.get("items", [])).size())
	navigation_guidance_enabled = top_bar_count > 0 or widgets.size() > 1 or widget_item_count > 1
	overlay.set_focus_nodes(
		top_item.get("node", null),
		widget.get("node", null),
		item.get("node", null),
		true,
		false,
		navigation_guidance_enabled,
		get_main_controller_hint()
	)


func update_popup_overlay() -> void:
	if overlay == null or not is_instance_valid(overlay):
		clear_visual_focus()
		return

	var popup_root: Variant = gui_state.controls.get("popup_root", null) if gui_state != null else null
	if not is_control_visible(popup_root):
		clear_visual_focus()
		overlay.clear_focus()
		return

	var active_popup_scope: Variant = get_active_popup_scope(popup_root)
	if active_popup_scope == null or not is_instance_valid(active_popup_scope):
		clear_visual_focus()
		overlay.clear_focus()
		return

	var battle_loadout_scope_active := is_battle_loadout_popup_scope(active_popup_scope)
	if not battle_loadout_scope_active:
		refresh_popup_focus_model()

	var popup_item: Dictionary = get_current_popup_item()

	clear_top_visual_focus()

	var selected_control: Variant = popup_item.get("node", null)
	if not is_live_control(selected_control):
		selected_control = null

	var navigation_guidance_enabled := popup_items.size() > 1

	if battle_loadout_scope_active and active_popup_scope.has_method("get_controller_navigation_selected_control"):
		var scoped_control: Variant = active_popup_scope.get_controller_navigation_selected_control()
		# Freed controls can remain for one frame after Battle Loadout rebuilds/closes.
		# Always validate before any `is Control` check.
		if is_live_control(scoped_control):
			selected_control = scoped_control
		else:
			selected_control = null
		# The Battle Loadout popup has its own controller lanes/groups, so show
		# guidance even if the generic popup collector only sees one/no item.
		navigation_guidance_enabled = true

	set_visual_focus(selected_control)
	overlay.set_focus_nodes(null, active_popup_scope, selected_control, true, true, navigation_guidance_enabled, get_popup_controller_hint(battle_loadout_scope_active))


func get_main_controller_hint() -> String:
	var widget := get_current_widget()
	var widget_id := str(widget.get("widget_id", ""))
	if widget_id == WIDGET_LEFT_PANEL:
		var active_panel := get_active_left_panel_id()
		if active_panel == "story_log":
			return get_story_log_controller_hint()
		if active_panel != "":
			return "L1/R1 rail   Triangle close/open   D-pad move   X select"
	if widget_id == WIDGET_PORT:
		return "Right stick look   R3 recenter   L1/R1 rail   Triangle open"
	return "L1/R1 rail   Triangle open   D-pad move   X select   Circle scan"


func get_popup_controller_hint(battle_loadout_scope_active: bool = false) -> String:
	if battle_loadout_scope_active:
		return "L1/R1 group   D-pad move   X select   Circle back"
	if popup_edit_item_id != "":
		return "D-pad adjust   X done"
	var item := get_current_popup_item()
	var kind := str(item.get("kind", ""))
	if kind == "popup_numeric" or kind == "popup_slider":
		return "D-pad move   X edit value   Circle close"
	return "D-pad move   X confirm   Circle close"


func get_local_map_controller_hint() -> String:
	if local_map_prepared_contact_id != "":
		return "D-pad browse   X auto to target   Triangle close"
	return "D-pad browse   X select target   Triangle close"


func get_tier_map_controller_hint() -> String:
	var group_label := tier_map_group_name.capitalize()
	if tier_map_prepared_item_id != "":
		return "Group: " + group_label + "   X engage   D-pad browse   L1/R1 group   Triangle close"
	return "Group: " + group_label + "   D-pad browse   X select   L1/R1 group   Triangle close"


func get_inventory_craft_controller_hint() -> String:
	var group_label := inventory_craft_group_name.capitalize()
	if inventory_craft_group_name == INVENTORY_CRAFT_GROUP_ITEMS:
		return "Group: " + group_label + "   D-pad browse   X details   Square recycle   L1/R1 group"
	return "Group: " + group_label + "   D-pad browse   X select   L1/R1 group   Triangle close"


func get_story_log_controller_hint() -> String:
	return "D-pad scroll story log   L1/R1 rail   Triangle open/close"


func set_visual_focus(control_value: Variant) -> void:
	if visually_focused_item_control != null and not is_instance_valid(visually_focused_item_control):
		visually_focused_item_control = null
	if is_live_control(control_value) and visually_focused_item_control == control_value:
		return
	clear_item_visual_focus()
	if not is_live_control(control_value):
		return
	visually_focused_item_control = control_value
	ControllerFocusVisualScript.apply_to_control(visually_focused_item_control)


func set_top_visual_focus(control_value: Variant) -> void:
	if visually_focused_top_control != null and not is_instance_valid(visually_focused_top_control):
		visually_focused_top_control = null
	if is_live_control(control_value) and visually_focused_top_control == control_value:
		return
	clear_top_visual_focus()
	if not is_live_control(control_value):
		return
	visually_focused_top_control = control_value
	ControllerFocusVisualScript.apply_to_control(visually_focused_top_control)


func clear_visual_focus() -> void:
	clear_item_visual_focus()
	clear_top_visual_focus()


func clear_item_visual_focus() -> void:
	if visually_focused_item_control == null:
		return
	if is_instance_valid(visually_focused_item_control):
		ControllerFocusVisualScript.clear_from_control(visually_focused_item_control)
	visually_focused_item_control = null


func clear_top_visual_focus() -> void:
	if visually_focused_top_control == null:
		return
	if is_instance_valid(visually_focused_top_control):
		ControllerFocusVisualScript.clear_from_control(visually_focused_top_control)
	visually_focused_top_control = null


func _exit_tree() -> void:
	clear_visual_focus()


func is_controller_popup_active() -> bool:
	if Globals.is_popup_input_locked():
		return true
	if gui_state == null:
		return false
	var popup_root = gui_state.controls.get("popup_root", null)
	return is_control_visible(popup_root)


func refresh_popup_focus_model() -> void:
	popup_items.clear()
	if gui_state == null:
		highlighted_popup_item_id = ""
		popup_edit_item_id = ""
		popup_scope_key = ""
		return

	var popup_root = gui_state.controls.get("popup_root", null)
	if not is_control_visible(popup_root):
		highlighted_popup_item_id = ""
		popup_edit_item_id = ""
		popup_scope_key = ""
		return

	var scope = get_active_popup_scope(popup_root)
	if scope == null or not is_instance_valid(scope):
		highlighted_popup_item_id = ""
		popup_edit_item_id = ""
		return

	var new_scope_key := build_popup_scope_key(scope)
	if new_scope_key != popup_scope_key:
		popup_scope_key = new_scope_key
		highlighted_popup_item_id = ""
		popup_edit_item_id = ""

	collect_popup_focus_items_recursive(scope, popup_items)
	popup_items.sort_custom(func(a, b): return sort_focus_items_by_screen_position(a, b))

	if popup_items.is_empty():
		highlighted_popup_item_id = ""
		popup_edit_item_id = ""
		return

	if highlighted_popup_item_id == "" or find_item_index(popup_items, highlighted_popup_item_id) < 0:
		highlighted_popup_item_id = str(popup_items[0].get("item_id", ""))

	if popup_edit_item_id != "" and find_item_index(popup_items, popup_edit_item_id) < 0:
		popup_edit_item_id = ""


func build_popup_scope_key(scope: Variant) -> String:
	if scope == null or not is_instance_valid(scope):
		return ""
	var token := ""
	if scope.has_meta("story_popup_token"):
		token = str(scope.get_meta("story_popup_token"))
	elif scope.has_meta("popup_token"):
		token = str(scope.get_meta("popup_token"))
	if token != "":
		return "token:" + token
	return str(scope.get_instance_id())


func collect_popup_focus_items_recursive(root: Variant, output: Array) -> void:
	if root == null or not is_instance_valid(root):
		return
	if not (root is Node):
		return

	for child in (root as Node).get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child is Control and not (child as Control).is_visible_in_tree():
			continue

		if is_button_selectable(child):
			output.append(make_popup_focus_item(child, "button"))
		elif is_popup_numeric_control(child):
			output.append(make_popup_focus_item(child, "popup_numeric"))
		elif is_popup_slider_control(child):
			output.append(make_popup_focus_item(child, "popup_slider"))

		if child is Node and (child as Node).get_child_count() > 0:
			collect_popup_focus_items_recursive(child, output)


func make_popup_focus_item(control_value: Variant, kind: String) -> Dictionary:
	var item_id := "popup:" + str(control_value.name) + ":" + str(control_value.get_instance_id())
	if control_value.has_meta("controller_focus_id"):
		item_id = str(control_value.get_meta("controller_focus_id"))

	var display_name := str(control_value.name)
	if control_value is BaseButton:
		var button_text := str(control_value.get("text")).strip_edges()
		if button_text != "":
			display_name = button_text

	return {
		"item_id": item_id,
		"display_name": display_name,
		"kind": kind,
		"node": control_value,
		"enabled": true
	}


func is_popup_numeric_control(value: Variant) -> bool:
	if value == null or not is_instance_valid(value):
		return false
	if value is LineEdit:
		return (value as LineEdit).editable and is_numeric_text((value as LineEdit).text)
	if value is TextEdit:
		return (value as TextEdit).editable and is_numeric_text((value as TextEdit).text)
	return false


func is_popup_slider_control(value: Variant) -> bool:
	if value == null or not is_instance_valid(value):
		return false
	return value is HSlider or value is VSlider


func is_numeric_text(text: String) -> bool:
	var clean := text.strip_edges()
	if clean == "":
		return false
	return clean.is_valid_int() or clean.is_valid_float()


func sort_focus_items_by_screen_position(a: Dictionary, b: Dictionary) -> bool:
	var node_a = a.get("node", null)
	var node_b = b.get("node", null)
	if not is_control_visible(node_a) or not is_control_visible(node_b):
		return str(a.get("item_id", "")) < str(b.get("item_id", ""))
	var rect_a := (node_a as Control).get_global_rect()
	var rect_b := (node_b as Control).get_global_rect()
	if abs(rect_a.position.y - rect_b.position.y) > 12.0:
		return rect_a.position.y < rect_b.position.y
	return rect_a.position.x < rect_b.position.x


func move_popup_highlight(step: int) -> void:
	if popup_items.is_empty():
		return
	var index := find_item_index(popup_items, highlighted_popup_item_id)
	if index < 0:
		index = 0
	index = wrap_index(index + step, popup_items.size())
	highlighted_popup_item_id = str(popup_items[index].get("item_id", ""))


func activate_highlighted_popup_item() -> void:
	var item := get_current_popup_item()
	if item.is_empty():
		return
	activate_focus_item(item)


func get_current_popup_item() -> Dictionary:
	if popup_items.is_empty():
		return {}
	var index := find_item_index(popup_items, highlighted_popup_item_id)
	if index < 0:
		index = 0
		highlighted_popup_item_id = str(popup_items[index].get("item_id", ""))
	return popup_items[index]


func handle_popup_numeric_edit_inputs() -> void:
	var item := get_current_popup_item()
	if item.is_empty() or str(item.get("item_id", "")) != popup_edit_item_id:
		popup_edit_item_id = ""
		return

	var delta := 0.0
	if Input.is_action_pressed("controller_widget_nav_up"):
		if can_repeat("popup_value_up"):
			delta = 1.0
	else:
		reset_repeat("popup_value_up")

	if Input.is_action_pressed("controller_widget_nav_down"):
		if can_repeat("popup_value_down"):
			delta = -1.0
	else:
		reset_repeat("popup_value_down")

	if Input.is_action_pressed("controller_widget_nav_right"):
		if can_repeat("popup_value_right"):
			delta = 10.0
	else:
		reset_repeat("popup_value_right")

	if Input.is_action_pressed("controller_widget_nav_left"):
		if can_repeat("popup_value_left"):
			delta = -10.0
	else:
		reset_repeat("popup_value_left")

	if delta != 0.0:
		adjust_popup_numeric_control(item.get("node", null), delta)


func adjust_popup_numeric_control(control_value: Variant, delta: float) -> void:
	if control_value == null or not is_instance_valid(control_value):
		return

	if control_value is LineEdit:
		var line_edit := control_value as LineEdit
		line_edit.text = format_adjusted_numeric_text(line_edit.text, delta, str(line_edit.name))
		line_edit.caret_column = line_edit.text.length()
		return

	if control_value is TextEdit:
		var text_edit := control_value as TextEdit
		text_edit.text = format_adjusted_numeric_text(text_edit.text, delta, str(text_edit.name))
		text_edit.set_caret_column(text_edit.text.length())
		return

	if control_value is Range:
		var range := control_value as Range
		range.value = clamp(range.value + delta, range.min_value, range.max_value)


func format_adjusted_numeric_text(old_text: String, delta: float, control_name: String) -> String:
	var old_clean := old_text.strip_edges()
	var value := float(old_clean) if old_clean.is_valid_float() or old_clean.is_valid_int() else 0.0
	value += delta
	if control_name.find("sector") >= 0 or (old_clean.find(".") < 0 and abs(delta) >= 1.0):
		return str(int(round(value)))
	return str(snapped(value, 0.1))


func get_default_popup_button():
	if gui_state == null:
		return null
	var popup_root: Variant = gui_state.controls.get("popup_root", null)
	if not is_control_visible(popup_root):
		return null

	var scope: Variant = get_active_popup_scope(popup_root)
	var candidates: Array = []
	collect_button_items_recursive(scope, candidates, "popup")
	if candidates.is_empty():
		return null

	for item in candidates:
		var button = item.get("node", null)
		var name_text := str(button.name).to_lower()
		var button_text := str(button.get("text")).strip_edges().to_lower()
		if name_text.find("close") >= 0 or button_text in ["close", "ok", "okay", "continue", "confirm", "x"]:
			return button

	return candidates[0].get("node", null)


func get_active_popup_scope(popup_root: Variant):
	if popup_root == null or not is_instance_valid(popup_root):
		controller_debug_throttled("active_scope:null_root", "ACTIVE_SCOPE_NULL_ROOT", {})
		return null

	# Runtime tool popups can be children of the shared popup panel. Some shared
	# popup panels may carry token/meta of their own, so check named runtime roots
	# before accepting the panel as the active scope.
	var runtime_scope: Variant = find_visible_runtime_popup_scope(popup_root)
	if runtime_scope != null:
		controller_debug_throttled("active_scope_runtime:" + get_debug_control_name(runtime_scope), "ACTIVE_SCOPE_RUNTIME", {"scope": get_debug_control_name(runtime_scope)})
		return runtime_scope

	if popup_root.has_meta("active_story_popup_window_path"):
		var path_text := str(popup_root.get_meta("active_story_popup_window_path"))
		var active_node: Variant = popup_root.get_node_or_null(NodePath(path_text))
		if is_control_visible(active_node):
			controller_debug_throttled("active_scope_story_path:" + get_debug_control_name(active_node), "ACTIVE_SCOPE_STORY_PATH", {"scope": get_debug_control_name(active_node)})
			return active_node

	var best_control: Variant = null
	var best_score := -999999999.0
	for child in (popup_root as Node).get_children():
		if not is_control_visible(child):
			continue
		var control := child as Control
		var child_name := str(control.name)
		var is_popup_window := child_name.begins_with("story_popup_window_") or control.has_meta("story_popup_token") or control.has_meta("popup_token")
		if not is_popup_window:
			continue
		var score := float(control.z_index) * 100000.0 + float(control.get_index())
		if best_control == null or score >= best_score:
			best_control = control
			best_score = score

	if best_control != null:
		controller_debug_throttled("active_scope_best:" + get_debug_control_name(best_control), "ACTIVE_SCOPE_BEST", {"scope": get_debug_control_name(best_control)})
		return best_control

	var panel: Variant = popup_root.get_node_or_null("popup_panel")
	if is_control_visible(panel):
		controller_debug_throttled("active_scope_panel:" + get_debug_control_name(panel), "ACTIVE_SCOPE_PANEL", {"scope": get_debug_control_name(panel)})
		return panel

	controller_debug_throttled("active_scope_root:" + get_debug_control_name(popup_root), "ACTIVE_SCOPE_ROOT", {"scope": get_debug_control_name(popup_root)})
	return popup_root


func find_visible_runtime_popup_scope(root: Variant) -> Variant:
	if root == null or not is_instance_valid(root):
		return null
	if not (root is Node):
		return null

	var runtime_names := [
		"battle_loadout_popup_root",
		"coord_auto_pilot_root",
		"settings_handler_root",
		"named_save_popup_root",
		"event_list_popup_root"
	]

	for runtime_name in runtime_names:
		var found: Variant = find_visible_named_control_recursive(root, runtime_name)
		if found != null:
			return found
	return null


func find_visible_named_control_recursive(root: Variant, target_name: String) -> Variant:
	if root == null or not is_instance_valid(root):
		return null
	if not (root is Node):
		return null
	for child in (root as Node).get_children():
		if child == null or not is_instance_valid(child):
			continue
		if child is Control:
			var control := child as Control
			if str(control.name) == target_name and control.is_visible_in_tree():
				return control
		if child is Node and (child as Node).get_child_count() > 0:
			var found: Variant = find_visible_named_control_recursive(child, target_name)
			if found != null:
				return found
	return null
