extends Node
class_name ControllerSceneListFocus


const ControllerFocusVisualScript = preload("res://UI/Controller/ControllerFocusVisual.gd")

var owner_scene = null
var overlay: ControllerFocusOverlay = null
var focus_root = null
var focus_items_provider: Callable = Callable()
var direct_action_handler: Callable = Callable()
var direct_action_names: Array = []
var held_direct_action_names: Array = []

var controller_active := false
var controller_deadzone := 0.25
var controller_repeat_delay := 0.18
var controller_initial_repeat_delay := 0.35
var selected_item_id := ""
var edit_item_id := ""
var dropdown_item_id := ""
var dropdown_option_button = null
var dropdown_original_index := -1
var dropdown_focus_index := -1
var focus_items: Array = []
var repeat_state := {}
var visually_focused_control = null


func setup(refs: Dictionary) -> void:
	owner_scene = refs.get("owner_scene", null)
	overlay = refs.get("overlay", null)
	focus_root = refs.get("focus_root", null)
	focus_items_provider = refs.get("focus_items_provider", Callable())
	direct_action_handler = refs.get("direct_action_handler", Callable())
	direct_action_names = refs.get("direct_action_names", [])
	held_direct_action_names = refs.get("held_direct_action_names", [])
	set_process(true)
	refresh_focus_items()
	update_overlay()


func handle_input(event: InputEvent) -> bool:
	if not is_controller_event(event):
		return false

	if controller_event_activates(event):
		controller_active = true
		refresh_focus_items()
		focus_selected_item()
		update_overlay()

	return controller_active


func _process(_delta: float) -> void:
	if not controller_active:
		return

	if Input.get_connected_joypads().is_empty():
		controller_active = false
		edit_item_id = ""
		close_option_dropdown(false)
		clear_visual_focus()
		if overlay != null and is_instance_valid(overlay):
			overlay.clear_focus()
		return

	refresh_focus_items()
	handle_direct_actions()

	if dropdown_item_id != "":
		handle_option_dropdown_inputs()
		update_overlay()
		return

	if edit_item_id != "":
		handle_edit_inputs()
		if is_action_just_pressed_safe("controller_widget_activate") or is_action_just_pressed_safe("controller_popup_confirm"):
			edit_item_id = ""
		update_overlay()
		return

	if is_action_just_pressed_safe("controller_widget_activate") or is_action_just_pressed_safe("controller_popup_confirm"):
		activate_selected_item()

	handle_navigation_inputs()
	update_overlay()


func is_controller_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


func controller_event_activates(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return bool((event as InputEventJoypadButton).pressed)
	if event is InputEventJoypadMotion:
		return abs(float((event as InputEventJoypadMotion).axis_value)) >= controller_deadzone
	return false


func refresh_focus_items() -> void:
	var next_items: Array = []
	if focus_items_provider.is_valid():
		var provided = focus_items_provider.call()
		if typeof(provided) == TYPE_ARRAY:
			next_items = provided

	focus_items.clear()
	for item in next_items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var focus_item: Dictionary = item
		if not is_item_available(focus_item):
			continue
		focus_items.append(focus_item)

	if focus_items.is_empty():
		selected_item_id = ""
		edit_item_id = ""
		close_option_dropdown(false)
		return

	if selected_item_id == "" or find_item_index(selected_item_id) < 0:
		selected_item_id = str(focus_items[0].get("item_id", ""))

	if edit_item_id != "" and find_item_index(edit_item_id) < 0:
		edit_item_id = ""

	if dropdown_item_id != "" and find_item_index(dropdown_item_id) < 0:
		close_option_dropdown(false)


func is_item_available(item: Dictionary) -> bool:
	if not bool(item.get("enabled", true)):
		return false

	var node_value = item.get("node", null)
	if node_value == null or not is_instance_valid(node_value):
		return false
	if not (node_value is Control):
		return false
	var control := node_value as Control
	if not control.is_visible_in_tree():
		return false
	if node_value is BaseButton and (node_value as BaseButton).disabled:
		return false
	if node_value is Range and not (node_value as Range).editable:
		return false
	return true


func handle_direct_actions() -> void:
	if not direct_action_handler.is_valid():
		return

	for action_name in direct_action_names:
		var clean_action := str(action_name)
		if clean_action == "" or not is_action_just_pressed_safe(clean_action):
			continue
		direct_action_handler.call(clean_action)

	for action_name in held_direct_action_names:
		var clean_action := str(action_name)
		if clean_action == "":
			continue
		if is_action_pressed_safe(clean_action):
			if can_repeat("held_direct_" + clean_action):
				direct_action_handler.call(clean_action)
		else:
			reset_repeat("held_direct_" + clean_action)


func handle_navigation_inputs() -> void:
	var horizontal := get_action_strength_safe("controller_widget_nav_right") - get_action_strength_safe("controller_widget_nav_left")
	var vertical := get_action_strength_safe("controller_widget_nav_down") - get_action_strength_safe("controller_widget_nav_up")

	if abs(vertical) >= controller_deadzone and abs(vertical) >= abs(horizontal):
		if can_repeat("scene_focus_vertical"):
			move_focus(1 if vertical > 0.0 else -1)
	else:
		reset_repeat("scene_focus_vertical")

	if abs(horizontal) >= controller_deadzone and abs(horizontal) > abs(vertical):
		if can_repeat("scene_focus_horizontal"):
			move_focus(1 if horizontal > 0.0 else -1)
	else:
		reset_repeat("scene_focus_horizontal")


func handle_edit_inputs() -> void:
	var item := get_selected_item()
	if item.is_empty() or str(item.get("item_id", "")) != edit_item_id:
		edit_item_id = ""
		return

	var delta := 0
	if is_action_pressed_safe("controller_widget_nav_up"):
		if can_repeat("scene_edit_up"):
			delta = 1
	else:
		reset_repeat("scene_edit_up")

	if is_action_pressed_safe("controller_widget_nav_down"):
		if can_repeat("scene_edit_down"):
			delta = -1
	else:
		reset_repeat("scene_edit_down")

	if is_action_pressed_safe("controller_widget_nav_right"):
		if can_repeat("scene_edit_right"):
			delta = 1
	else:
		reset_repeat("scene_edit_right")

	if is_action_pressed_safe("controller_widget_nav_left"):
		if can_repeat("scene_edit_left"):
			delta = -1
	else:
		reset_repeat("scene_edit_left")

	if delta != 0:
		adjust_item_value(item, delta)


func move_focus(step: int) -> void:
	if focus_items.is_empty():
		return

	var index := find_item_index(selected_item_id)
	if index < 0:
		index = 0
	index = wrap_index(index + step, focus_items.size())
	selected_item_id = str(focus_items[index].get("item_id", ""))
	edit_item_id = ""
	focus_selected_item()


func activate_selected_item() -> bool:
	var item := get_selected_item()
	if item.is_empty():
		return false

	var activate_callable: Callable = item.get("activate_callable", Callable())
	if activate_callable.is_valid():
		activate_callable.call()
		return true

	var kind := str(item.get("kind", "button"))
	match kind:
		"option":
			return open_option_dropdown(item)
		"slider", "numeric", "option_spinner":
			edit_item_id = str(item.get("item_id", ""))
			focus_selected_item()
			return true
		"button":
			return press_button(item.get("node", null))
		_:
			return press_button(item.get("node", null))


func adjust_item_value(item: Dictionary, delta: int) -> void:
	var adjust_callable: Callable = item.get("adjust_callable", Callable())
	if adjust_callable.is_valid():
		adjust_callable.call(delta)
		return

	var node_value = item.get("node", null)
	if node_value == null or not is_instance_valid(node_value):
		return

	if node_value is Range:
		var range := node_value as Range
		range.value = clamp(range.value + delta, range.min_value, range.max_value)
		return

	if node_value is OptionButton:
		var option := node_value as OptionButton
		var count := option.get_item_count()
		if count <= 0:
			return
		var next_index := wrap_index(option.selected + delta, count)
		option.select(next_index)
		option.item_selected.emit(next_index)


func open_option_dropdown(item: Dictionary) -> bool:
	var node_value = item.get("node", null)
	if node_value == null or not is_instance_valid(node_value):
		return false
	if not (node_value is OptionButton):
		return false

	var option := node_value as OptionButton
	if option.disabled or not option.is_visible_in_tree():
		return false

	var count := option.get_item_count()
	if count <= 0:
		return false

	edit_item_id = ""
	dropdown_item_id = str(item.get("item_id", ""))
	dropdown_option_button = option
	dropdown_original_index = clamp(option.selected, 0, count - 1)
	dropdown_focus_index = dropdown_original_index
	option.grab_focus()

	if option.has_method("show_popup"):
		option.show_popup()
	else:
		var popup = option.get_popup()
		if popup != null and is_instance_valid(popup) and popup.has_method("popup"):
			popup.popup()

	focus_option_dropdown_index(option, dropdown_focus_index)
	return true


func handle_option_dropdown_inputs() -> void:
	var option := get_active_dropdown_option_button()
	if option == null:
		close_option_dropdown(false)
		return

	var count := option.get_item_count()
	if count <= 0:
		close_option_dropdown(false)
		return

	var popup = option.get_popup()
	if popup != null and is_instance_valid(popup):
		if not is_popup_visible(popup):
			close_option_dropdown(true)
			return

	if is_action_just_pressed_safe("controller_popup_cancel"):
		close_option_dropdown(false)
		return

	if is_action_just_pressed_safe("controller_widget_activate") or is_action_just_pressed_safe("controller_popup_confirm"):
		commit_option_dropdown_selection()
		return

	var horizontal := get_action_strength_safe("controller_widget_nav_right") - get_action_strength_safe("controller_widget_nav_left")
	var vertical := get_action_strength_safe("controller_widget_nav_down") - get_action_strength_safe("controller_widget_nav_up")

	if abs(vertical) >= controller_deadzone and abs(vertical) >= abs(horizontal):
		if can_repeat("scene_dropdown_vertical"):
			move_option_dropdown_focus(1 if vertical > 0.0 else -1)
	else:
		reset_repeat("scene_dropdown_vertical")

	if abs(horizontal) >= controller_deadzone and abs(horizontal) > abs(vertical):
		if can_repeat("scene_dropdown_horizontal"):
			move_option_dropdown_focus(1 if horizontal > 0.0 else -1)
	else:
		reset_repeat("scene_dropdown_horizontal")


func move_option_dropdown_focus(step: int) -> void:
	var option := get_active_dropdown_option_button()
	if option == null:
		close_option_dropdown(false)
		return
	var count := option.get_item_count()
	if count <= 0:
		close_option_dropdown(false)
		return
	dropdown_focus_index = wrap_index(dropdown_focus_index + step, count)
	focus_option_dropdown_index(option, dropdown_focus_index)


func focus_option_dropdown_index(option: OptionButton, index: int) -> void:
	if option == null or not is_instance_valid(option):
		return
	var count := option.get_item_count()
	if count <= 0:
		return
	var safe_index := int(clamp(index, 0, count - 1))
	dropdown_focus_index = safe_index

	var popup = option.get_popup()
	if popup != null and is_instance_valid(popup) and popup.has_method("set_focused_item"):
		popup.set_focused_item(safe_index)
	else:
		option.select(safe_index)


func commit_option_dropdown_selection() -> void:
	var option := get_active_dropdown_option_button()
	if option == null:
		close_option_dropdown(false)
		return
	var count := option.get_item_count()
	if count <= 0:
		close_option_dropdown(false)
		return

	var selected_index := int(clamp(dropdown_focus_index, 0, count - 1))
	option.select(selected_index)
	option.item_selected.emit(selected_index)
	close_option_dropdown(true)


func close_option_dropdown(keep_selection: bool) -> void:
	if dropdown_item_id == "":
		return

	var option := get_active_dropdown_option_button()
	if option != null:
		if not keep_selection and dropdown_original_index >= 0 and dropdown_original_index < option.get_item_count():
			option.select(dropdown_original_index)
		var popup = option.get_popup()
		if popup != null and is_instance_valid(popup) and popup.has_method("hide"):
			popup.hide()

	dropdown_item_id = ""
	dropdown_option_button = null
	dropdown_original_index = -1
	dropdown_focus_index = -1
	reset_repeat("scene_dropdown_vertical")
	reset_repeat("scene_dropdown_horizontal")


func get_active_dropdown_option_button() -> OptionButton:
	if dropdown_item_id == "":
		return null
	if dropdown_option_button != null and is_instance_valid(dropdown_option_button) and dropdown_option_button is OptionButton:
		return dropdown_option_button as OptionButton
	var index := find_item_index(dropdown_item_id)
	if index < 0:
		return null
	var item: Dictionary = focus_items[index]
	var node_value = item.get("node", null)
	if node_value == null or not is_instance_valid(node_value):
		return null
	if not (node_value is OptionButton):
		return null
	return node_value as OptionButton


func is_popup_visible(popup) -> bool:
	if popup == null or not is_instance_valid(popup):
		return false
	var visible_value = popup.get("visible")
	if typeof(visible_value) == TYPE_BOOL:
		return bool(visible_value)
	if popup.has_method("is_visible"):
		return bool(popup.is_visible())
	return true


func press_button(button_value: Variant) -> bool:
	if button_value == null or not is_instance_valid(button_value):
		return false
	if not (button_value is BaseButton):
		return false
	var button := button_value as BaseButton
	if button.disabled or not button.is_visible_in_tree():
		return false
	button.emit_signal("pressed")
	return true


func get_selected_item() -> Dictionary:
	if focus_items.is_empty():
		return {}
	var index := find_item_index(selected_item_id)
	if index < 0:
		index = 0
		selected_item_id = str(focus_items[index].get("item_id", ""))
	return focus_items[index]


func find_item_index(item_id: String) -> int:
	for i in range(focus_items.size()):
		if str(focus_items[i].get("item_id", "")) == item_id:
			return i
	return -1


func wrap_index(index: int, size_value: int) -> int:
	if size_value <= 0:
		return 0
	return int(posmod(index, size_value))


func focus_selected_item() -> void:
	var item := get_selected_item()
	var node_value = item.get("node", null)
	if node_value != null and is_instance_valid(node_value) and node_value is Control:
		var control := node_value as Control
		control.grab_focus()
		ensure_control_visible_in_scroll(control)


func ensure_control_visible_in_scroll(control: Control) -> void:
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			var scroll := parent as ScrollContainer
			if scroll.has_method("ensure_control_visible"):
				scroll.ensure_control_visible(control)
			return
		parent = parent.get_parent()


func update_overlay() -> void:
	if overlay == null or not is_instance_valid(overlay):
		clear_visual_focus()
		return
	if not controller_active:
		clear_visual_focus()
		overlay.clear_focus()
		return

	var item := get_selected_item()
	var item_node = item.get("node", null)
	set_visual_focus(item_node)
	var navigation_guidance_enabled := focus_items.size() > 1
	overlay.set_focus_nodes(null, focus_root, item_node, true, edit_item_id != "" or dropdown_item_id != "", navigation_guidance_enabled)


func set_visual_focus(control_value: Variant) -> void:
	if visually_focused_control == control_value:
		return
	clear_visual_focus()
	if control_value == null or not is_instance_valid(control_value):
		return
	if control_value is Control:
		visually_focused_control = control_value
		ControllerFocusVisualScript.apply_to_control(visually_focused_control)


func clear_visual_focus() -> void:
	if visually_focused_control == null:
		return
	if is_instance_valid(visually_focused_control):
		ControllerFocusVisualScript.clear_from_control(visually_focused_control)
	visually_focused_control = null


func _exit_tree() -> void:
	clear_visual_focus()


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


func is_action_just_pressed_safe(action_name: String) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name)


func is_action_pressed_safe(action_name: String) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_pressed(action_name)


func get_action_strength_safe(action_name: String) -> float:
	if not InputMap.has_action(action_name):
		return 0.0
	return Input.get_action_strength(action_name)
