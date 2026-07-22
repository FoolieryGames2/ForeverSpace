extends Control
class_name LiveMapTargetWidget

var action_manager = Action_Manager
var gui_state = WidgetsState5
var auto_pilot = AutoPilot
var selected_packet: Dictionary = {}
var target_sector: Vector3i = Vector3i.ZERO
var target_local: Vector3 = Vector3.ZERO
var has_target := false
var interaction_enabled := false

var title_label: Label = null
var sector_label: Label = null
var local_label: Label = null
var auto_button: Button = null




func setup_widget(pos: Vector2, widget_size: Vector2,new_action_manager = null,new_gui_state = null,new_auto_pilot = null) -> void:
	action_manager = new_action_manager
	gui_state = new_gui_state
	auto_pilot = new_auto_pilot
	# Summary: Build a compact selected-target readout that sits beside the round live map.
	position = pos
	size = widget_size
	mouse_filter = Control.MOUSE_FILTER_PASS

	title_label = Label.new()
	title_label.name = "LiveMapTargetTitle"
	title_label.text = "Target: none"
	title_label.position = Vector2.ZERO
	title_label.size = Vector2(widget_size.x, 18.0)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 12)
	add_child(title_label)

	sector_label = Label.new()
	sector_label.name = "LiveMapTargetSector"
	sector_label.text = "Sector: --"
	sector_label.position = Vector2(0.0, 18.0)
	sector_label.size = Vector2(widget_size.x, 16.0)
	sector_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sector_label.add_theme_font_size_override("font_size", 11)
	add_child(sector_label)

	local_label = Label.new()
	local_label.name = "LiveMapTargetLocal"
	local_label.text = "Local: --"
	local_label.position = Vector2(0.0, 34.0)
	local_label.size = Vector2(widget_size.x, 16.0)
	local_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	local_label.add_theme_font_size_override("font_size", 11)
	add_child(local_label)

	auto_button = Button.new()
	auto_button.name = "LiveMapAutoToTargetButton"
	auto_button.text = "AUTO TO TARGET"
	auto_button.position = Vector2(0.0, 52.0)
	auto_button.size = Vector2(min(widget_size.x, 150.0), 26.0)
	auto_button.visible = false
	auto_button.disabled = true
	auto_button.mouse_filter = Control.MOUSE_FILTER_STOP
	auto_button.pressed.connect(_on_auto_to_target_pressed)
	gui_state.buttons[auto_button.name] = auto_button
	add_child(auto_button)


func apply_widget_size(pos: Vector2, widget_size: Vector2) -> void:
	position = pos
	size = widget_size
	if title_label != null:
		title_label.position = Vector2.ZERO
		title_label.size = Vector2(widget_size.x, 20.0)
	if sector_label != null:
		sector_label.position = Vector2(0.0, 24.0)
		sector_label.size = Vector2(widget_size.x, 18.0)
	if local_label != null:
		local_label.position = Vector2(0.0, 44.0)
		local_label.size = Vector2(widget_size.x, 18.0)
	if auto_button != null:
		auto_button.position = Vector2(0.0, 70.0)
		auto_button.size = Vector2(min(widget_size.x, 180.0), 28.0)


func update_from_packet(packet: Dictionary) -> void:
	# Summary: Store the selected marker position and make the debug auto-target control available.
	selected_packet = packet.duplicate(true)
	target_sector = read_vector3i(packet.get("sector_pos", packet.get("sector", Vector3i.ZERO)))
	target_local = read_vector3(packet.get("local_pos", packet.get("local", Vector3.ZERO)))
	has_target = true

	var display_name := str(packet.get("display_name", packet.get("id", "unknown")))
	if packet_is_orbit_revealed(packet) and not display_name.begins_with("ORBIT "):
		display_name = "ORBIT " + display_name
	title_label.text = "Target: " + display_name
	sector_label.text = "Sector: " + format_vector3i(target_sector)
	var orbit_planet := get_orbit_revealed_planet_name(packet)
	if orbit_planet != "":
		local_label.text = "Orbit: " + orbit_planet
	else:
		local_label.text = "Local: " + format_vector3(target_local)

	auto_button.visible = true
	auto_button.disabled = not interaction_enabled

	if Globals.debug_radar:
		print("LIVE MAP TARGET | updated target : ", display_name, " sector=", target_sector, " local=", target_local)


func clear_target() -> void:
	# Summary: Reset the readout without changing live-map scan state.
	selected_packet.clear()
	target_sector = Vector3i.ZERO
	target_local = Vector3.ZERO
	has_target = false
	title_label.text = "Target: none"
	sector_label.text = "Sector: --"
	local_label.text = "Local: --"
	auto_button.visible = false
	auto_button.disabled = true


func set_interaction_enabled(enabled: bool) -> void:
	# Summary: Follow the live-map swap state so hidden radar UI cannot keep taking clicks.
	interaction_enabled = enabled and not Globals.is_popup_input_locked()
	mouse_filter = Control.MOUSE_FILTER_PASS if interaction_enabled else Control.MOUSE_FILTER_IGNORE
	if auto_button != null:
		auto_button.disabled = (not interaction_enabled) or (not has_target)
		auto_button.mouse_filter = Control.MOUSE_FILTER_STOP if interaction_enabled else Control.MOUSE_FILTER_IGNORE


func _on_auto_to_target_pressed() -> void:
	# Summary: Send the selected marker packet through Action_Manager's coordinate autopilot bridge.
	if Globals.is_popup_input_locked():
		if Globals.print_priority_2 or Globals.debug_radar:
			print("Live map auto-to-target blocked while tutorial/story popup is active.")
		return

	if not has_target:
		print("LIVE MAP TARGET | auto to target pressed without selected target")
		return

	print("LIVE MAP TARGET | AUTO TO TARGET pressed | sector=", target_sector, " local=", target_local)
	if action_manager != null and action_manager.has_method("run_live_map_target_autopilot"):
		action_manager.run_live_map_target_autopilot(selected_packet)
		return

	Globals.live_map_target_pos = [target_sector, target_local]
	Globals.live_map_is_guided = true
	if action_manager != null:
		action_manager.run_action("auto_pilot")

func read_vector3(value: Variant) -> Vector3:
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


func read_vector3i(value: Variant) -> Vector3i:
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


func format_vector3(value: Vector3) -> String:
	return "(" + str(snapped(value.x, 0.1)) + ", " + str(snapped(value.y, 0.1)) + ", " + str(snapped(value.z, 0.1)) + ")"


func format_vector3i(value: Vector3i) -> String:
	return "(" + str(value.x) + ", " + str(value.y) + ", " + str(value.z) + ")"


func packet_is_orbit_revealed(packet: Dictionary) -> bool:
	if packet.has("orbit_revealed") and bool(packet.get("orbit_revealed", false)):
		return true
	var data_slice = packet.get("data_slice", {})
	if typeof(data_slice) == TYPE_DICTIONARY and data_slice.has("orbit_revealed"):
		return bool(data_slice.get("orbit_revealed", false))
	return false


func get_orbit_revealed_planet_name(packet: Dictionary) -> String:
	for key in ["orbit_revealed_by_planet_name", "parent_planet_name", "anchor_planet_name"]:
		var value := str(packet.get(key, "")).strip_edges()
		if value != "":
			return value

	var data_slice = packet.get("data_slice", {})
	if typeof(data_slice) == TYPE_DICTIONARY:
		for key in ["orbit_revealed_by_planet_name", "parent_planet_name", "anchor_planet_name"]:
			var value := str(data_slice.get(key, "")).strip_edges()
			if value != "":
				return value

	return ""
