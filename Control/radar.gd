extends Node


class_name InventoryRadarPanel

var map = Map
var inventory = Inventory5
var blueprint_root: Control = null
var live_map_control: LiveMapControl = null
var live_map_refresh_timer := 0.0

func setup(new_map, new_inventory, new_blueprint_root: Control = null):
	map = new_map
	inventory = new_inventory
	blueprint_root = new_blueprint_root


func toggle_inventory_live_map() -> void:
	# Summary: Compatibility hook for the old swap key; radar and inventory now stay visible together.
	if Globals.is_popup_input_locked():
		if Globals.print_priority_2 or Globals.debug_radar:
			print("Radar refresh blocked while tutorial/story popup is active.")
		return

	map.live_map_inventory_mode = true

	if Globals.print_priority_2:
		print("Refreshing independent radar/inventory panels.")

	set_inventory_panel_active(true)
	set_blueprint_panel_active(true)
	set_live_map_panel_active(true)





func set_live_map_panel_active(is_active: bool) -> void:
	# Summary: Make the independent radar widget visible and marker-pickable.
	if live_map_control == null:
		return

	live_map_control.visible = is_active
	live_map_control.mouse_filter = Control.MOUSE_FILTER_PASS if is_active else Control.MOUSE_FILTER_IGNORE

	if live_map_control.has_method("set_clickable_enabled"):
		live_map_control.set_clickable_enabled(is_active)

	if is_active:
		live_map_refresh_timer = 0.0
		live_map_control.refresh_from_packet(map.build_live_map_scan_packet())
		if live_map_control.has_method("set_clickable_enabled"):
			live_map_control.set_clickable_enabled(true)

	if Globals.print_priority_2:
		var marker_count := 0
		if live_map_control.live_map_state.has("markers"):
			marker_count = (live_map_control.live_map_state["markers"] as Array).size()
		print("Live map panel state | active: ", is_active, " markers: ", marker_count)
		
		
func set_control_tree_visible_and_interactive(root: Node, is_active: bool) -> void:
	# Summary: Apply visibility and GUI input state to a whole UI subtree.
	if root == null:
		return

	if root is CanvasItem:
		var canvas_item := root as CanvasItem
		canvas_item.visible = is_active

	set_control_tree_interactive(root, is_active)


func set_control_tree_interactive(root: Node, is_active: bool) -> void:
	# Summary: Recursively enable or disable GUI input for inventory controls.
	if root == null:
		return

	if root is Control:
		var control := root as Control
		if is_active:
			if control is Button or control is TextureButton or control is ScrollContainer:
				control.mouse_filter = Control.MOUSE_FILTER_STOP
			else:
				control.mouse_filter = Control.MOUSE_FILTER_PASS
		else:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE

		if control is Button:
			var button := control as Button
			button.disabled = not is_active
		elif control is TextureButton:
			var texture_button := control as TextureButton
			texture_button.disabled = not is_active

	for child in root.get_children():
		set_control_tree_interactive(child, is_active)
		
		
func set_inventory_panel_active(is_active: bool) -> void:
	# Summary: Enable or disable inventory interaction without swapping it against radar.
	if inventory == null:
		return

	if inventory.has_method("set_inventory_interaction_enabled"):
		inventory.set_inventory_interaction_enabled(is_active)
	else:
		inventory.set_process(is_active)
		inventory.set_process_input(is_active)

	var has_label_inventory := inventory.label_inventory_root != null
	set_control_tree_visible_and_interactive(inventory.label_inventory_root, is_active)
	set_control_tree_visible_and_interactive(inventory.inventory_root, is_active and not has_label_inventory)
	set_control_tree_visible_and_interactive(inventory.drone_bay_root, false)

	if is_active and inventory.has_method("_update_label_inventory_tabs"):
		inventory._update_label_inventory_tabs()

	if Globals.print_priority_2:
		print(
			"Inventory panel state | active: ", is_active,
			" label_visible: ", inventory.label_inventory_root != null and inventory.label_inventory_root.visible,
			" legacy_visible: ", inventory.inventory_root != null and inventory.inventory_root.visible
		)


func set_blueprint_panel_active(is_active: bool) -> void:
	# Summary: Blueprint has its own right-column slot and can be controlled independently.
	set_control_tree_visible_and_interactive(blueprint_root, is_active)
