extends Node






class_name WidgetsController5


# ==========================================================
# W I D G E T S   C O N T R O L L E R
# ----------------------------------------------------------
# This script handles behavior.
#
# It does NOT build the GUI pieces.
# It does NOT own the dictionaries directly.
# It operates on a shared WidgetsState object.
#
# In short:
#   - builder = makes the parts
#   - state   = stores the parts
#   - this    = reacts to the parts
# ==========================================================


# ----------------------------------------------------------
# SHARED STATE LINK
# ----------------------------------------------------------
# Assign this from your main script after .new().
# Example:
#   controller.state = state
# ----------------------------------------------------------
var state : WidgetsState5

# ==========================================================
# S L I D E R   H A N D L E R
# ==========================================================
func _on_slider(value: float, axis: String):
	# Codex edit: manual pitch/yaw/roll input is free-drive only.
	# Autopilot writes these slider values while steering, so user slider
	# callbacks must not push back into the map during autopilot.
	if _manual_drive_locked():
		return

	# ------------------------------------------------------
	# Update the visible slider readout first.
	# ------------------------------------------------------
	if state.drive_value_labels.has(axis):
		state.drive_value_labels[axis].text = str(axis) + ' : ' + str(int(value))

	# ------------------------------------------------------
	# Push the same value into the linked map object.
	# This keeps the GUI slider acting like a direct ship
	# orientation control.
	# ------------------------------------------------------
	if state.map == null:
		return

	if axis == "yaw":
		state.map.yaw = value
	elif axis == "pitch":
		state.map.pitch = value
	elif axis == "roll":
		state.map.roll = value


# ==========================================================
# B U T T O N   H A N D L E R
# ==========================================================
func _on_but_pressed(index):
	if Globals.is_popup_input_locked():
		if Globals.print_priority_2:
			print("Widget click blocked while tutorial/story popup is active: ", index)
		return

	if Globals.debug:
		if Globals.print_priority_3:
			print("Pressed button index: ", index)  
	Globals.target_star_label = index
	var key = index

	# ------------------------------------------------------
	# If the signal sent a real Button node, use its name.
	# If the signal sent a string key, keep that string.
	# ------------------------------------------------------
	if index is Button:
		key = index.name

	# ------------------------------------------------------
	# Codex edit: drive buttons are now real free-drive controls.
	# They are ignored while autopilot is active; otherwise they
	# operate the shared engine directly.
	# ------------------------------------------------------
	if _is_drive_key(key):
		if _manual_drive_locked():
			return

		state.use_auto_pilot = false
		_handle_drive_button(key)
		return

	# ------------------------------------------------------
	# Clicking any non-drive manual button drops autopilot.
	# Star-distance buttons turn it back on below.
	# ------------------------------------------------------
	state.use_auto_pilot = false

	# ------------------------------------------------------
	# STAR DISTANCE BUTTON 0
	# ------------------------------------------------------
	# Keeping your original exact behavior here.
	# You can expand this later to all star buttons.
	# ------------------------------------------------------
	if state.buttons.has("star_distances"):
		if Globals.debug:
			if Globals.print_priority_3:
				print('connected star : ' + index.text)
		var x = get_star_button_slot(index)
		if Globals.debug:
			if Globals.print_priority_3:
				print('this is star in slot selected : ' + str(x))
		state.use_auto_pilot = true
		if Globals.debug:
			if Globals.print_priority_3:
				print(str(state.buttons['star_distances']))
		
		
		
		
		

	# ------------------------------------------------------
	# FALLBACK DEBUG
	# ------------------------------------------------------
	else:
		if Globals.debug:
			if Globals.print_priority_3:
				print('not connected')
			if Globals.print_priority_3:
				print(str(index))
		if state.buttons.has("star_distances"):
			if Globals.debug:
				if Globals.print_priority_3:
					print(str(state.buttons["star_distances"]))
			
		
		


# ==========================================================
# D E B U G   I N F O   D U M P
# ==========================================================
func get_all_info():
	if Globals.print_priority_3:
		print('----star distances----')
	for i in state.buttons:
		if Globals.print_priority_3:
			print('Button >>')
		if Globals.print_priority_3:
			print(str(i))

	if Globals.print_priority_3:
		print('----Nodes in labels ----')
	for i in state.labels:
		if Globals.print_priority_3:
			print('Label >>')
		if Globals.print_priority_3:
			print(str(i))

	if Globals.print_priority_3:
		print('----drive value labels ----')
	for i in state.drive_value_labels:
		if Globals.print_priority_3:
			print('drive_value_labels >>')
		if Globals.print_priority_3:
			print(str(i))

	if Globals.print_priority_3:
		print('-----controls----')
	for i in state.controls:
		if Globals.print_priority_3:
			print('contorl >>')
		if Globals.print_priority_3:
			print(str(i))

	if Globals.print_priority_3:
		print('-----sliders----')
	for i in state.sliders:
		if Globals.print_priority_3:
			print('slider >>')
		if Globals.print_priority_3:
			print(str(i))


func _on_blank_action_widget_pressed(widget_id: String) -> void:
	# Summary: Route the starter blank widget button through the controller.
	if Globals.print_priority_3:
		print("Blank action widget pressed: ", widget_id)

	# ------------------------------------------------------
	# Guard against setup/state problems before touching UI.
	# ------------------------------------------------------
	if state == null:
		return

	# ------------------------------------------------------
	# Find the status label that the builder stored in state.
	# ------------------------------------------------------
	var status_key = widget_id + "_body_label"
	if not state.labels.has(status_key):
		if Globals.print_priority_1:
			print("Blank action widget status label missing: ", status_key)
		return

	# ------------------------------------------------------
	# Update visible state so we can prove the control route.
	# ------------------------------------------------------
	state.labels[status_key].text = "Controller connected. Waiting for real behavior."


func _on_event_widget_action_pressed(button_id: String, button_packet: Dictionary, button: Button) -> void:
	if state == null:
		return

	var previous_button = state.event_storage.get("selected_action_button", null)
	if previous_button != null and is_instance_valid(previous_button):
		previous_button.modulate = Color(1, 1, 1, 1)

	state.event_storage["selected_button_id"] = button_id
	state.event_storage["selected_action_packet"] = button_packet.duplicate(true)
	state.event_storage["selected_action_button"] = button

	if button != null:
		button.modulate = Color(0.35, 0.8, 1.0, 1.0)

	if state.controls.has("event_text"):
		var active_packet: Dictionary = state.event_storage.get("active_packet", {})
		var title := str(active_packet.get("display_name", "Event"))
		var label := str(button_packet.get("label", button_id))
		state.controls["event_text"].text = title + "\nSelected: " + label

	var action_id := str(button_packet.get("action_id", ""))
	if action_id != "" and action_id != "event_active" and state.game_event_handler != null:
		if state.game_event_handler.has_method("handle_event_widget_action"):
			var result: Dictionary = state.game_event_handler.handle_event_widget_action(button_packet)
			handle_event_widget_action_result(result)


func handle_event_widget_action_result(result: Dictionary) -> void:
	if result.is_empty():
		return

	var status := str(result.get("status", "")).strip_edges().to_lower()
	if status != "blocked":
		return

	var message := str(result.get("message", "")).strip_edges()
	if message == "":
		message = "Event action blocked: " + str(result.get("reason", "out of range"))
	show_event_widget_feedback(message)


func _on_event_widget_info_pressed() -> void:
	if state == null:
		return

	var packet: Dictionary = state.event_storage.get("selected_action_packet", {})
	var active_packet: Dictionary = state.event_storage.get("active_packet", {})
	if packet.is_empty():
		packet = active_packet

	var message := build_event_widget_info_text(active_packet, packet)
	if state.controls.has("popup_root") and state.labels.has("popup_text"):
		Globals.show_popup(state, message)
	elif state.controls.has("event_text"):
		state.controls["event_text"].text = message


func _on_event_widget_auto_pilot_pressed() -> void:
	if state == null:
		return

	var active_packet: Dictionary = state.event_storage.get("active_packet", {})
	var target: Dictionary = get_event_widget_target_packet(active_packet)
	if target.is_empty():
		show_event_widget_feedback("No event target loaded.")
		return

	if state.auto_pilot == null:
		show_event_widget_feedback("Event target ready, but autopilot is not connected.")
		return

	if _task_navigation_locked():
		show_event_widget_feedback("Auto pilot unavailable while " + _task_navigation_lock_text() + ".")
		return

	var target_sector := read_event_widget_vector3i(target.get("sector_pos", target.get("sector", Vector3i.ZERO)))
	var target_local := read_event_widget_vector3(target.get("local_pos", target.get("local", Vector3.ZERO)))
	var target_name := str(target.get("display_name", target.get("owner_id", "Event Target")))
	var target_kind := str(target.get("owner_type", target.get("object_type", "target"))).strip_edges().to_lower()
	var target_type := "event_widget_" + target_kind if target_kind != "" else "event_widget"

	state.use_auto_pilot = false
	state.auto_pilot.set_impulse_target(target_sector, target_local, target_name, target_type)

	show_event_widget_auto_pilot_feedback(
		build_event_widget_auto_pilot_feed_text(active_packet, target, target_sector, target_local)
	)


func _on_event_list_popup_event_selected(event_id: String) -> void:
	if state == null:
		return

	event_id = event_id.strip_edges()
	if event_id == "":
		show_event_widget_feedback("Event selection blocked: missing event id.")
		return

	if state.game_event_handler == null or not state.game_event_handler.has_method("handle_event_widget_action"):
		show_event_widget_feedback("Event selection blocked: event handler missing.")
		return

	var result: Dictionary = state.game_event_handler.handle_event_widget_action({
		"action_id": "select_event",
		"event_id": event_id,
		"target_event_id": event_id
	})

	if typeof(result) == TYPE_DICTIONARY and str(result.get("status", "")) == "failed":
		show_event_widget_feedback("Event selection blocked: " + str(result.get("reason", "unknown reason")))
		return

	if state.controls.has("popup_root"):
		var popup = state.controls["popup_root"]
		if popup != null and is_instance_valid(popup):
			popup.visible = false


func _on_blueprint_widget_button_pressed(blueprint_id: String, blueprint_packet: Dictionary, button: Button) -> void:
	if state == null:
		return

	var previous_button = state.blueprint_storage.get("selected_blueprint_button", null)
	if previous_button != null and is_instance_valid(previous_button):
		previous_button.modulate = Color(1, 1, 1, 1)

	state.blueprint_storage["selected_blueprint_id"] = blueprint_id
	state.blueprint_storage["selected_blueprint_packet"] = blueprint_packet.duplicate(true)
	state.blueprint_storage["selected_blueprint_button"] = button

	if button != null:
		button.modulate = Color(0.35, 0.8, 1.0, 1.0)

	var can_build := bool(blueprint_packet.get("can_build", false))
	if state.buttons.has("blueprint_build_button"):
		state.buttons["blueprint_build_button"].visible = can_build
		state.buttons["blueprint_build_button"].disabled = not can_build

	if state.labels.has("blueprint_status_label"):
		state.labels["blueprint_status_label"].text = "Ready to build." if can_build else "Needs materials."

	write_blueprint_log(build_blueprint_log_text(blueprint_packet))


func _on_blueprint_widget_build_pressed() -> void:
	if state == null:
		return

	var packet: Dictionary = state.blueprint_storage.get("selected_blueprint_packet", {})
	if packet.is_empty():
		write_blueprint_log("No blueprint selected.")
		return

	if state.inventory == null:
		write_blueprint_log("Blueprint build failed: inventory is not connected.")
		return

	if state.task_manager == null:
		write_blueprint_log("Blueprint build failed: task manager is not connected.")
		return

	var cost := read_blueprint_count_map(packet.get("cost", {}))
	var missing := get_missing_blueprint_requirements(cost)
	if not missing.is_empty():
		packet["missing"] = missing
		state.blueprint_storage["selected_blueprint_packet"] = packet.duplicate(true)
		if state.buttons.has("blueprint_build_button"):
			state.buttons["blueprint_build_button"].visible = false
			state.buttons["blueprint_build_button"].disabled = true
		write_blueprint_log(build_blueprint_log_text(packet))
		run_blueprint_refresh_callback()
		return

	var spent := {}
	for item_id in cost.keys():
		var clean_id := str(item_id)
		var amount := int(cost[item_id])
		if amount <= 0:
			continue
		if state.inventory.consume_item(clean_id, amount):
			spent[clean_id] = amount
		else:
			for spent_id in spent.keys():
				state.inventory.add_item(str(spent_id), int(spent[spent_id]))
			write_blueprint_log("Blueprint build failed while removing materials. Nothing was crafted.")
			run_blueprint_refresh_callback()
			return

	var result_item_id := str(packet.get("result_item_id", ""))
	var result_count := int(packet.get("result_count", 1))
	var result_name := str(packet.get("result_name", result_item_id))
	var craft_time := float(packet.get("craft_time", 2.0))
	if craft_time < 0.25:
		craft_time = 0.25

	var event_data := packet.duplicate(true)
	event_data["cost"] = cost.duplicate(true)
	event_data["result_item_id"] = result_item_id
	event_data["result_count"] = max(result_count, 1)
	event_data["result_name"] = result_name

	state.task_manager.add_event(
		"Crafting " + result_name,
		craft_time,
		"craft_blueprint",
		event_data
	)

	if state.action_manager != null and state.action_manager.has_method("refresh_actions_from_inventory"):
		state.action_manager.refresh_actions_from_inventory()

	if state.buttons.has("blueprint_build_button"):
		state.buttons["blueprint_build_button"].visible = false
		state.buttons["blueprint_build_button"].disabled = true

	write_blueprint_log("Crafting started: " + result_name + "\nBlueprint was kept. Materials were spent.")
	run_blueprint_refresh_callback()


func write_blueprint_log(message: String) -> void:
	if state == null:
		return
	if state.log_storage.has("log_text"):
		state.log_storage["log_text"].text = message


func build_blueprint_log_text(packet: Dictionary) -> String:
	var lines := []
	lines.append(str(packet.get("display_name", "Blueprint")))
	lines.append("Blueprint ID: " + str(packet.get("blueprint_id", packet.get("item_id", "--"))))
	lines.append("Result: " + str(packet.get("result_name", packet.get("result_item_id", "--"))) + " x" + str(packet.get("result_count", 1)))
	lines.append("Craft time: " + str(packet.get("craft_time", 2.0)) + "s")
	lines.append("")
	lines.append("Needs:")

	var cost := read_blueprint_count_map(packet.get("cost", {}))
	var cost_names: Dictionary = packet.get("cost_names", {})
	if cost.is_empty():
		lines.append("- No material cost listed.")
	else:
		for item_id in cost.keys():
			var clean_id := str(item_id)
			var need := int(cost[item_id])
			var have := 0
			if state != null and state.inventory != null:
				have = state.inventory.count_item_anywhere(clean_id)
			var label := str(cost_names.get(clean_id, clean_id))
			lines.append("- " + label + ": " + str(have) + " / " + str(need))

	var missing: Dictionary = packet.get("missing", {})
	if not missing.is_empty():
		lines.append("")
		lines.append("Missing:")
		for item_id in missing.keys():
			var clean_id := str(item_id)
			var label := str(cost_names.get(clean_id, clean_id))
			lines.append("- " + label + ": " + str(missing[item_id]))

	if bool(packet.get("can_build", false)):
		lines.append("")
		lines.append("Status: requirements met. Build button unlocked.")
	else:
		lines.append("")
		lines.append("Status: requirements not met.")

	var text := ""
	for i in range(lines.size()):
		if i > 0:
			text += "\n"
		text += str(lines[i])
	return text


func read_blueprint_count_map(value: Variant) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result

	for item_id in value.keys():
		var amount := int(value[item_id])
		if amount > 0:
			result[str(item_id)] = amount

	return result


func get_missing_blueprint_requirements(cost: Dictionary) -> Dictionary:
	var missing := {}
	if state == null or state.inventory == null:
		return cost.duplicate(true)

	for item_id in cost.keys():
		var clean_id := str(item_id)
		var need := int(cost[item_id])
		var have = state.inventory.count_item_anywhere(clean_id)
		if have < need:
			missing[clean_id] = need - have

	return missing


func run_blueprint_refresh_callback() -> void:
	if state == null:
		return
	if state.blueprint_refresh_callable.is_valid():
		state.blueprint_refresh_callable.call()


func get_event_widget_target_packet(active_packet: Dictionary) -> Dictionary:
	var target = active_packet.get("target", {})
	if typeof(target) == TYPE_DICTIONARY:
		return target
	return {}


func build_event_widget_info_text(active_packet: Dictionary, button_packet: Dictionary) -> String:
	var lines := []
	if not active_packet.is_empty():
		lines.append(str(active_packet.get("display_name", "Event")))
		lines.append("Event ID: " + str(active_packet.get("event_id", "--")))
		lines.append("Step: " + str(active_packet.get("current_step", "--")))
		lines.append("")
		lines.append(str(active_packet.get("objective_text", "No objective text.")))

	var target := get_event_widget_target_packet(active_packet)
	if not target.is_empty():
		lines.append("")
		lines.append("Target: " + str(target.get("display_name", target.get("owner_id", "Unknown"))))
		lines.append("Type: " + str(target.get("owner_type", "target")))
		lines.append("Sector: " + str(target.get("sector_pos", "--")))
		lines.append("Local: " + str(target.get("local_pos", "--")))

	if not button_packet.is_empty():
		lines.append("")
		lines.append("Selected Action: " + str(button_packet.get("label", button_packet.get("button_id", "--"))))
		lines.append("Action ID: " + str(button_packet.get("action_id", "--")))

	var text := ""
	for i in range(lines.size()):
		if i > 0:
			text += "\n"
		text += str(lines[i])

	return text


func build_event_widget_auto_pilot_feed_text(
	active_packet: Dictionary,
	target: Dictionary,
	target_sector: Vector3i,
	target_local: Vector3
) -> String:
	var target_name := str(target.get("display_name", target.get("owner_id", "Event Target"))).strip_edges()
	if target_name == "":
		target_name = "Event Target"

	var event_name := str(active_packet.get("display_name", "")).strip_edges()
	var lines := []
	lines.append("AMI NAV-LINK")
	lines.append("Event route accepted.")
	lines.append("Destination: " + target_name)
	if event_name != "" and event_name != target_name:
		lines.append("Signal: " + event_name)
	lines.append("Vector: S" + format_event_widget_vector3i(target_sector) + " / L" + format_event_widget_vector3(target_local))
	return join_event_widget_lines(lines)


func show_event_widget_auto_pilot_feedback(message: String) -> void:
	if state == null:
		return
	if state.log_storage.has("log_text"):
		state.log_storage["log_text"].text = message
	elif state.controls.has("event_text"):
		state.controls["event_text"].text = message


func show_event_widget_feedback(message: String) -> void:
	if state == null:
		return
	if state.controls.has("popup_root") and state.labels.has("popup_text"):
		Globals.show_popup(state, message)
	elif state.controls.has("event_text"):
		state.controls["event_text"].text = message


func read_event_widget_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector3i:
		return Vector3(value.x, value.y, value.z)
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3(
			float(value.get("x", 0.0)),
			float(value.get("y", 0.0)),
			float(value.get("z", 0.0))
		)
	return Vector3.ZERO


func read_event_widget_vector3i(value: Variant) -> Vector3i:
	if value is Vector3i:
		return value
	if value is Vector3:
		return Vector3i(int(value.x), int(value.y), int(value.z))
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3i(
			int(value.get("x", 0)),
			int(value.get("y", 0)),
			int(value.get("z", 0))
		)
	return Vector3i.ZERO


func format_event_widget_vector3(value: Vector3) -> String:
	return "(" + str(snapped(value.x, 0.1)) + ", " + str(snapped(value.y, 0.1)) + ", " + str(snapped(value.z, 0.1)) + ")"


func format_event_widget_vector3i(value: Vector3i) -> String:
	return "(" + str(value.x) + ", " + str(value.y) + ", " + str(value.z) + ")"


func join_event_widget_lines(lines: Array) -> String:
	var text := ""
	for i in range(lines.size()):
		if i > 0:
			text += "\n"
		text += str(lines[i])
	return text



func get_star_button_slot(button: Button) -> int:
	if not state.buttons.has("star_distances"):
		return -1

	for i in range(10):
		var key = "star_distance_" + str(i)

		if state.buttons["star_distances"].has(key):
			if button == state.buttons["star_distances"][key]:
				return i

	return -1


# ==========================================================
# C O D E X   E D I T :   F R E E   D R I V E   C O N T R O L
# ----------------------------------------------------------
# These helpers keep the engine widget rules in one place:
# - Warp / Impulse tabs change the engine mode only in free drive.
# - Switching tabs while thrust is active stops thrust first.
# - Thrust buttons operate the real Impulse_Engine, not just UI flags.
# - Autopilot owns the engine while active, so manual controls are ignored.
# ==========================================================
func _is_drive_key(key) -> bool:
	return key in [
		"drive_warp",
		"drive_impulse",
		"drive_stop",
		"drive_thrust",
		"drive_thrust_off"
	]


func _manual_drive_locked() -> bool:
	if Globals.is_popup_input_locked():
		return true
	if state == null:
		return false
	if _task_navigation_locked():
		return true
	if state.use_auto_pilot:
		return true
	return state.auto_pilot != null and state.auto_pilot.enabled


func _task_navigation_locked() -> bool:
	if state == null:
		return false
	if state.task_manager == null:
		return false
	if not state.task_manager.has_method("has_navigation_lock_todo"):
		return false
	return bool(state.task_manager.has_navigation_lock_todo())


func _task_navigation_lock_text() -> String:
	if state == null or state.task_manager == null:
		return "the active task"
	if not state.task_manager.has_method("get_navigation_lock_todo_text"):
		return "the active task"

	var task_text := str(state.task_manager.get_navigation_lock_todo_text()).strip_edges()
	return task_text if task_text != "" else "the active task"


func _handle_drive_button(key: String) -> void:
	if state == null or state.engine == null:
		return

	match key:
		"drive_warp":
			_set_free_drive_mode("warp")

		"drive_impulse":
			_set_free_drive_mode("impulse")

		"drive_stop":
			state.engine.stop()

		"drive_thrust":
			state.engine.set_thrust(true)

		"drive_thrust_off":
			state.engine.set_thrust(false)


func _set_free_drive_mode(new_mode: String) -> void:
	if state.engine.thrust_on:
		state.engine.set_thrust(false)

	state.engine.set_mode(new_mode)
