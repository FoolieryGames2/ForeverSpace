extends Control
class_name LiveMapControl

var gui_state = WidgetsState5
var action_manager = Action_Manager
var auto_pilot = AutoPilot
signal marker_selected(packet: Dictionary)

const LIVE_MAP_RANGE := 500.0
const PLAYER_OVERLAP_RADIUS := 8.0
const MARKER_COLORS := {
	"player": Color(0.4, 0.8, 1.0, 1.0),
	"enemy": Color(1.0, 0.2, 0.2, 1.0),
	"npc": Color(0.2, 1.0, 0.4, 1.0),
	"object": Color(1.0, 0.8, 0.2, 1.0),
	"beacon": Color(0.9, 0.55, 1.0, 1.0),
	"planet": Color(0.298, 0.824, 0.09, 1.0),
	"star": Color(1.0, 1.0, 0.7, 1.0)
}

var live_map_state := {
	"range": LIVE_MAP_RANGE,
	"selected_marker": null,
	"markers": [],
	"last_packet": {}
}

var widget: LiveMapWidget = null
var target_widget: LiveMapTargetWidget = null
var marker_click_enabled := false
var last_debug_drawn_count := -1


func build(pos: Vector2, widget_size: Vector2,new_gui_state = null,new_action_manager = null,new_auto_pilot = null) -> void:
	gui_state = new_gui_state
	action_manager = new_action_manager
	auto_pilot = new_auto_pilot
	# Summary: Build the Live Map V1 control root and round widget shell.
	name = "LiveMapControl"
	position = pos
	size = widget_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	ensure_physics_object_picking()

	widget = LiveMapWidget.new()
	widget.name = "LiveMapWidget"
	widget.setup_widget(widget_size)
	gui_state.labels["livemaptitle"] = widget.title_label
	gui_state.labels["livemap2"] = widget.status_label
	add_child(widget)

	target_widget = LiveMapTargetWidget.new()
	target_widget.name = "LiveMapTargetWidget"
	var target_pos := Vector2(widget.title_label.position.x, 72.0)
	var target_size := Vector2(max(widget_size.x - target_pos.x - 12.0, 150.0), 78.0)
	target_widget.setup_widget(target_pos, target_size, action_manager, gui_state, auto_pilot)
	add_child(target_widget)

	set_clickable_enabled(false)
	if Globals.debug_radar:
		print("LIVE MAP CONTROL | build")


func apply_external_rect(rect: Rect2) -> void:
	position = rect.position
	size = rect.size
	custom_minimum_size = rect.size

	var widget_size := rect.size
	if widget_size.y > widget_size.x * 1.15:
		widget_size = Vector2(rect.size.x, min(rect.size.y * 0.68, rect.size.x + 210.0))

	if widget != null and widget.has_method("apply_widget_size"):
		widget.apply_widget_size(widget_size)
	elif widget != null:
		widget.size = widget_size

	if target_widget != null:
		var target_pos := Vector2(12.0, min(widget_size.y + 18.0, rect.size.y - 118.0))
		var target_size := Vector2(max(rect.size.x - 24.0, 120.0), max(rect.size.y - target_pos.y - 12.0, 96.0))
		if target_widget.has_method("apply_widget_size"):
			target_widget.apply_widget_size(target_pos, target_size)
		else:
			target_widget.position = target_pos
			target_widget.size = target_size


func set_clickable_enabled(enabled: bool) -> void:
	# Summary: Keep the live-map shell mouse-pass-through while toggling marker collider clicks.
	var final_enabled := enabled and not Globals.is_popup_input_locked()
	marker_click_enabled = final_enabled
	mouse_filter = Control.MOUSE_FILTER_PASS if final_enabled else Control.MOUSE_FILTER_IGNORE
	ensure_physics_object_picking()

	if target_widget != null:
		target_widget.set_interaction_enabled(final_enabled)

	if widget == null or widget.marker_layer == null:
		return

	for child in widget.marker_layer.get_children():
		if child is LiveMapMarker:
			var marker := child as LiveMapMarker
			marker.set_clickable_enabled(final_enabled)
			
	if Globals.debug_radar:
		print("LIVE MAP CONTROL | set_clickable_enabled : " + str(enabled))
	


func ensure_physics_object_picking() -> void:
	# Summary: Area2D markers need viewport picking enabled before they can emit input events.
	var viewport := get_viewport()
	if viewport != null:
		viewport.physics_object_picking = true
	

func refresh_from_packet(packet: Dictionary) -> void:
	# Summary: Redraw marker nodes from a scan packet owned by the parent/controller.
	live_map_state["last_packet"] = packet.duplicate(true)
	live_map_state["range"] = float(packet.get("range", LIVE_MAP_RANGE))
	live_map_state["markers"] = []

	if widget == null:
		if Globals.debug_radar:
			print("LIVE MAP CONTROL | refresh_from_packet :widget is null")
		return
	if Globals.debug_radar:
		print("LIVE MAP CONTROL | :" + str(widget))
	widget.clear_markers()

	var center_local: Vector3 = read_vector3(packet.get("center_local", Vector3.ZERO))
	var markers = packet.get("markers", [])
	if typeof(markers) != TYPE_ARRAY:
		widget.set_contact_count(0)
		return

	var drawn_count: int = 0
	for marker_packet in markers:
		if typeof(marker_packet) != TYPE_DICTIONARY:
			continue

		var marker_data: Dictionary = marker_packet as Dictionary
		var marker_local: Vector3 = read_vector3(marker_data.get("local_pos", marker_data.get("local", Vector3.ZERO)))
		var distance: float = float(marker_data.get("distance", marker_local.distance_to(center_local)))
		if distance > float(live_map_state["range"]):
			continue

		var offset_3d: Vector3 = marker_local - center_local
		var display_offset: Vector2 = local_offset_to_map_offset(offset_3d)
		display_offset = clamp_to_circle(display_offset, widget.map_radius)

		var overlaps_player: bool = display_offset.length() <= PLAYER_OVERLAP_RADIUS
		var marker_node: LiveMapMarker = LiveMapMarker.new()
		marker_node.name = "LiveMapMarker_" + str(marker_data.get("type", "contact")) + "_" + str(drawn_count)
		marker_node.position = display_offset + Vector2(widget.map_radius, widget.map_radius) - Vector2(marker_node.radius, marker_node.radius)
		marker_node.setup(
			marker_data,
			get_marker_color(marker_data),
			overlaps_player
		)
		marker_node.set_clickable_enabled(marker_click_enabled)
		marker_node.clicked.connect(_on_marker_clicked)
		widget.add_marker(marker_node)

		live_map_state["markers"].append(marker_data)
		drawn_count += 1

	widget.set_contact_count(drawn_count)
	if Globals.print_priority_2 and drawn_count != last_debug_drawn_count:
		print("LiveMapControl refresh drew markers: ", drawn_count, " clickable: ", marker_click_enabled)
	last_debug_drawn_count = drawn_count

	if Globals.debug_radar:
			print("LIVE MAP CONTROL | ensure_physics_object_picking")
func local_offset_to_map_offset(offset_3d: Vector3) -> Vector2:
	# Summary: Convert 3D local offset into the V1 2D awareness map offset.
	if widget == null:
		if Globals.debug_radar:
			print("LIVE MAP CONTROL | local_offset_to_map_offset widget is null")
		return Vector2.ZERO

	var offset_2d := Vector2(offset_3d.x, offset_3d.y)
	var scale: float = widget.map_radius / float(live_map_state.get("range", LIVE_MAP_RANGE))
	return offset_2d * scale


func clamp_to_circle(pos: Vector2, radius: float) -> Vector2:
	# Summary: Keep contact markers inside the round map edge.
	if pos.length() > radius:
		return pos.normalized() * radius
	return pos


func get_marker_color(marker: Dictionary) -> Color:
	# Summary: Return the V1 group color for a marker type.
	if marker_is_orbit_revealed(marker):
		return Color(0.42, 1.0, 0.88, 1.0)
	var marker_type := str(marker.get("type", "object"))
	return MARKER_COLORS.get(marker_type, MARKER_COLORS["object"])


func marker_is_orbit_revealed(marker: Dictionary) -> bool:
	if marker.has("orbit_revealed") and bool(marker.get("orbit_revealed", false)):
		return true
	var data_slice = marker.get("data_slice", {})
	if typeof(data_slice) == TYPE_DICTIONARY and data_slice.has("orbit_revealed"):
		return bool(data_slice.get("orbit_revealed", false))
	return false


func read_vector3(value: Variant) -> Vector3:
	# Summary: Read either Vector3, Vector3i, array, or dictionary position data into Vector3.
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


func _on_marker_clicked(packet: Dictionary) -> void:
	# Summary: Store the selected marker packet and relay it to the parent log receiver.
	if Globals.is_popup_input_locked():
		if Globals.print_priority_2 or Globals.debug_radar:
			print("Live map marker click blocked while tutorial/story popup is active.")
		return

	live_map_state["selected_marker"] = packet.duplicate(true)
	if Globals.print_priority_2 or Globals.debug_radar:
		print("LiveMapControl marker selected: ", packet.get("owner", "none"), " / ", packet.get("id", "none"))
	if target_widget != null:
		target_widget.update_from_packet(packet)
	if action_manager != null and action_manager.has_method("sync_live_map_target_to_action_cache"):
		action_manager.sync_live_map_target_to_action_cache(packet)
	marker_selected.emit(packet)
	if Globals.print_priority_1:
		print("LIVE MAP WIDGET | on click packet full : \n" + str(packet) + "\n end of packed")
	var marker_type := str(packet.get("type", "unknown"))
	if marker_type == "object":
		print("packet is object")
	elif marker_type == "enemy":
		print("packet is enemy")
	elif marker_type == "beacon":
		print("packet is beacon")
	elif marker_type == "planet":
		print("packet is planet")
	print(str(packet.get("sector", packet.get("sector_pos", "--"))) + "\n" + str(packet.get("local", packet.get("local_pos", "--"))))
	#action_manager.run_action("approach_enemy")
