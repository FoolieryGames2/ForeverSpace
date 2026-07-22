extends RefCounted
class_name BlueprintWidgetController


# ==========================================================
# BLUEPRINT WIDGET CONTROLLER
# ----------------------------------------------------------
# Pass 3 extraction from main_mode.gd.
# Owns:
# - Blueprint widget dependency wiring
# - Inventory-change refresh queue
# - Lightweight inventory signature polling
# - Blueprint packet collection/building
# - Blueprint READY/NEEDS display data
#
# MainMode still owns boot order and the real game systems.
# This controller only watches inventory and updates the existing widget builder.
# Expected project path:
# res://UI/Blueprints/BlueprintWidgetController.gd
# ==========================================================

var owner_node = null
var gui_state = null
var gui_builder = null
var inventory = null
var item_handler = null
var action_manager = null
var event_handler = null

var refresh_queued := false
var inventory_poll_timer := 0.0
var last_inventory_signature := ""
var inventory_change_signal_connected := false
var inventory_poll_interval := 0.25


func setup(
	p_owner_node,
	p_gui_state,
	p_gui_builder,
	p_inventory,
	p_item_handler,
	p_action_manager,
	p_event_handler,
	p_inventory_poll_interval: float = 0.25
) -> void:
	owner_node = p_owner_node
	gui_state = p_gui_state
	gui_builder = p_gui_builder
	if inventory != p_inventory:
		inventory_change_signal_connected = false
	inventory = p_inventory
	item_handler = p_item_handler
	action_manager = p_action_manager
	event_handler = p_event_handler
	inventory_poll_interval = p_inventory_poll_interval


func connect_blueprint_widget_refs() -> void:
	if gui_state == null:
		return

	gui_state.inventory = inventory
	gui_state.task_manager = event_handler
	gui_state.action_manager = action_manager
	gui_state.blueprint_refresh_callable = Callable(self, "refresh_blueprint_widget")
	connect_inventory_change_refresh()
	last_inventory_signature = build_inventory_signature()


func connect_inventory_change_refresh() -> void:
	# Summary: Blueprint READY/NEEDS labels depend on inventory counts, so any inventory mutation must refresh them.
	if inventory == null or inventory_change_signal_connected:
		return
	if not inventory.has_signal("inventory_changed"):
		return

	var callback := Callable(self, "_on_inventory_changed")
	if not inventory.inventory_changed.is_connected(callback):
		inventory.inventory_changed.connect(callback)
	inventory_change_signal_connected = true


func _on_inventory_changed(reason: String = "changed") -> void:
	queue_blueprint_widget_refresh(reason)


func queue_blueprint_widget_refresh(_reason: String = "changed") -> void:
	refresh_queued = true


func process_blueprint_inventory_refresh(delta: float) -> void:
	# Signal refresh covers normal paths. The lightweight signature check catches older code that edits slots directly.
	if inventory == null:
		return

	inventory_poll_timer += delta
	if inventory_poll_timer >= inventory_poll_interval:
		inventory_poll_timer = 0.0
		var signature := build_inventory_signature()
		if signature != last_inventory_signature:
			last_inventory_signature = signature
			queue_blueprint_widget_refresh("inventory_signature_changed")

	if not refresh_queued:
		return

	refresh_queued = false
	refresh_inventory_dependent_widgets()


func refresh_inventory_dependent_widgets() -> void:
	if action_manager != null:
		action_manager.refresh_actions_from_inventory()
	refresh_blueprint_widget()
	last_inventory_signature = build_inventory_signature()


func build_inventory_signature() -> String:
	if inventory == null:
		return ""

	var parts := []
	append_inventory_container_signature(parts, inventory.cells.get("each_cell", {}), "cargo")
	append_inventory_container_signature(parts, inventory.drone_cells.get("each_cell", {}), "drone")
	parts.sort()

	var signature := ""
	for i in range(parts.size()):
		if i > 0:
			signature += "|"
		signature += str(parts[i])
	return signature


func append_inventory_container_signature(parts: Array, container: Dictionary, prefix: String) -> void:
	for slot_name in container.keys():
		var slot = container[slot_name]
		if typeof(slot) != TYPE_DICTIONARY:
			continue
		var item_id := str(slot.get("item_id", ""))
		var count := int(slot.get("count", 0))
		if item_id == "" or count <= 0:
			continue
		parts.append(prefix + ":" + str(slot_name) + ":" + item_id + ":" + str(count))


func refresh_blueprint_widget() -> void:
	if gui_state == null or gui_builder == null:
		return
	if not gui_state.controls.has("blueprint_root"):
		return

	var previous_selected_id := ""
	if gui_state.blueprint_storage.has("selected_blueprint_id"):
		previous_selected_id = str(gui_state.blueprint_storage.get("selected_blueprint_id", ""))

	gui_builder.clear_blueprint_widget_buttons()

	gui_state.blueprint_storage["selected_blueprint_id"] = ""
	gui_state.blueprint_storage["selected_blueprint_packet"] = {}
	gui_state.blueprint_storage["selected_blueprint_button"] = null

	if gui_state.buttons.has("blueprint_build_button"):
		gui_state.buttons["blueprint_build_button"].visible = false
		gui_state.buttons["blueprint_build_button"].disabled = true

	var packets := collect_inventory_blueprint_packets()
	if packets.is_empty():
		gui_builder.set_blueprint_widget_status("No craft blueprints in inventory.")
		return

	var restored_packet := {}
	for packet in packets:
		gui_builder.add_blueprint_widget_button(packet)
		if previous_selected_id != "" and str(packet.get("blueprint_id", "")) == previous_selected_id:
			restored_packet = packet

	if not restored_packet.is_empty():
		restore_selected_blueprint_after_refresh(restored_packet)
		return

	gui_builder.set_blueprint_widget_status("Select a blueprint.")


func restore_selected_blueprint_after_refresh(packet: Dictionary) -> void:
	var blueprint_id := str(packet.get("blueprint_id", ""))
	if blueprint_id == "":
		gui_builder.set_blueprint_widget_status("Select a blueprint.")
		return

	gui_state.blueprint_storage["selected_blueprint_id"] = blueprint_id
	gui_state.blueprint_storage["selected_blueprint_packet"] = packet

	if gui_state.buttons.has("blueprint_build_button"):
		gui_state.buttons["blueprint_build_button"].visible = true
		gui_state.buttons["blueprint_build_button"].disabled = not bool(packet.get("can_build", false))

	gui_builder.set_blueprint_widget_status(str(packet.get("tooltip", "")))


func collect_inventory_blueprint_packets() -> Array:
	var packets := []
	if inventory == null or item_handler == null:
		return packets

	var blueprint_counts := {}

	if inventory.cells.has("each_cell"):
		collect_blueprint_counts_from_container(inventory.cells["each_cell"], blueprint_counts)

	if inventory.drone_cells.has("each_cell"):
		collect_blueprint_counts_from_container(inventory.drone_cells["each_cell"], blueprint_counts)

	var blueprint_ids := blueprint_counts.keys()
	blueprint_ids.sort()
	for blueprint_id in blueprint_ids:
		var packet := build_blueprint_widget_packet(str(blueprint_id), int(blueprint_counts[blueprint_id]))
		if not packet.is_empty():
			packets.append(packet)

	return packets


func collect_blueprint_counts_from_container(container: Dictionary, blueprint_counts: Dictionary) -> void:
	for slot_name in container.keys():
		var slot = container[slot_name]
		if typeof(slot) != TYPE_DICTIONARY:
			continue

		var item_id := str(slot.get("item_id", ""))
		var count := int(slot.get("count", 0))
		if item_id == "" or count <= 0:
			continue

		var item_data = item_handler.get_item_data(item_id)
		if not is_craft_blueprint_item(item_data):
			continue

		blueprint_counts[item_id] = int(blueprint_counts.get(item_id, 0)) + count


func is_craft_blueprint_item(item_data: Dictionary) -> bool:
	if item_data.is_empty():
		return false

	var item_type := str(item_data.get("item_type", item_data.get("type", "")))
	var subtype := str(item_data.get("subtype", ""))
	if item_type != "blueprint" or subtype != "craft":
		return false

	var result := read_blueprint_result_packet(item_data)
	var result_item_id := str(result.get("item_id", "")).strip_edges()
	if result_item_id == "":
		return true

	var result_data = item_handler.get_item_data(result_item_id) if item_handler != null and item_handler.has_method("get_item_data") else {}
	if typeof(result_data) == TYPE_DICTIONARY and not result_data.is_empty():
		var result_type := str(result_data.get("item_type", result_data.get("type", ""))).strip_edges().to_lower()
		if result_type == "upgrade":
			return false
		if not bool(result_data.get("blueprint_allowed", true)):
			return false

	return true


func build_blueprint_widget_packet(blueprint_id: String, owned_count: int) -> Dictionary:
	var item_data = item_handler.get_item_data(blueprint_id)
	if item_data.is_empty():
		return {}

	var cost := read_blueprint_cost_map(item_data)
	var result := read_blueprint_result_packet(item_data)
	var result_item_id := str(result.get("item_id", ""))
	var result_count := int(result.get("count", 1))
	var result_name = item_handler.get_item_name(result_item_id) if result_item_id != "" else "Unknown Result"
	var craft_time := float(item_data.get("craft_time", item_data.get("duration", 2.0)))
	var missing := {}
	var cost_names := {}

	for item_id in cost.keys():
		var clean_id := str(item_id)
		var need := int(cost[item_id])
		var have = inventory.count_item_anywhere(clean_id)
		cost_names[clean_id] = item_handler.get_item_name(clean_id)
		if have < need:
			missing[clean_id] = need - have

	var can_build := result_item_id != "" and missing.is_empty()
	var display_name := str(item_data.get("display_name", item_data.get("name", blueprint_id)))
	var state_text := "READY" if can_build else "NEEDS"

	return {
		"blueprint_id": blueprint_id,
		"item_id": blueprint_id,
		"display_name": display_name,
		"owned_count": owned_count,
		"button_label": display_name + " [" + state_text + "]",
		"tooltip": build_blueprint_tooltip(display_name, cost, cost_names, result_name, result_count),
		"craft_time": craft_time,
		"cost": cost,
		"cost_names": cost_names,
		"missing": missing,
		"can_build": can_build,
		"result_item_id": result_item_id,
		"result_count": max(result_count, 1),
		"result_name": result_name
	}


func read_blueprint_cost_map(item_data: Dictionary) -> Dictionary:
	var source = item_data.get("craft_cost", item_data.get("requires_items", item_data.get("cost", {})))
	var result := {}
	if typeof(source) != TYPE_DICTIONARY:
		return result

	for item_id in source.keys():
		var amount := int(source[item_id])
		if amount > 0:
			result[str(item_id)] = amount

	return result


func read_blueprint_result_packet(item_data: Dictionary) -> Dictionary:
	var source = item_data.get("craft_result", {})
	var result := {
		"item_id": "",
		"count": 1
	}

	if typeof(source) == TYPE_DICTIONARY:
		result["item_id"] = str(source.get("item_id", source.get("id", "")))
		result["count"] = int(source.get("count", source.get("amount", 1)))
	elif typeof(source) == TYPE_STRING:
		result["item_id"] = str(source)

	if str(result["item_id"]) == "":
		var gain = item_data.get("gain", "")
		if typeof(gain) == TYPE_DICTIONARY:
			result["item_id"] = str(gain.get("item_id", gain.get("id", "")))
			result["count"] = int(gain.get("count", gain.get("amount", 1)))
		elif typeof(gain) == TYPE_STRING:
			result["item_id"] = str(gain)

	return result


func build_blueprint_tooltip(display_name: String, cost: Dictionary, cost_names: Dictionary, result_name: String, result_count: int) -> String:
	var lines := []
	lines.append(display_name)
	lines.append("Builds: " + result_name + " x" + str(max(result_count, 1)))

	if cost.is_empty():
		lines.append("Needs: none")
	else:
		lines.append("Needs:")
		for item_id in cost.keys():
			var clean_id := str(item_id)
			lines.append("- " + str(cost_names.get(clean_id, clean_id)) + " x" + str(cost[item_id]))

	var text := ""
	for i in range(lines.size()):
		if i > 0:
			text += "\n"
		text += str(lines[i])
	return text
