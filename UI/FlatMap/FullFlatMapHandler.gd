extends Node
class_name FullFlatMapHandler

const DEFAULT_CANVAS_SIZE := Vector2(2200, 1500)
const MIN_CANVAS_SIZE := Vector2(1400, 900)
const MAP_PADDING := 90.0
const MARKER_SIZE := 18.0
const PAN_DRAG_CANCEL_DISTANCE := 6.0

# Expanded chart needs to sit above the normal widget/UI stack.
# Keep this below Godot's practical CanvasItem z ceiling while leaving room
# for player/vessel marker z offsets inside the map canvas.
const COMPACT_ROOT_Z_INDEX := 360
const EXPANDED_ROOT_Z_INDEX := 3000

const MARKER_COLORS := {
	"player": Color(0.40, 0.85, 1.0, 1.0),
	"star": Color(1.0, 0.92, 0.42, 1.0),
	"planet": Color(0.32, 0.86, 0.30, 1.0),
	"object": Color(1.0, 0.70, 0.22, 1.0),
	"beacon": Color(0.92, 0.56, 1.0, 1.0),
	"enemy": Color(1.0, 0.22, 0.22, 1.0),
	"npc": Color(0.26, 1.0, 0.58, 1.0),
	"event_hotspot": Color(1.0, 0.52, 0.18, 1.0),
	"hotspot": Color(1.0, 0.52, 0.18, 1.0)
}
const ORBIT_REVEALED_COLOR := Color(0.42, 1.0, 0.90, 1.0)

var gui_state = null
var root: Control = null
var scroll: ScrollContainer = null
var canvas: Control = null
var expand_button: Button = null
var status_label: Label = null
var log_text_node: Node = null

var compact_rect := Rect2(Vector2.ZERO, Vector2(292, 240))
var expanded_top_reserved_y := 170.0
var expanded_padding := 18.0
var is_expanded := false
var last_scan_packet: Dictionary = {}
var last_markers: Array = []
var selected_marker: Dictionary = {}
var canvas_size := DEFAULT_CANVAS_SIZE
var expanded_opaque_backdrop: ColorRect = null
var expanded_zoom := 1.0
var expanded_zoom_min := 0.45
var expanded_zoom_max := 5.0
var expanded_zoom_step := 0.20
var zoom_in_button: Button = null
var zoom_out_button: Button = null
var zoom_label: Label = null
var is_panning := false
var pan_started_on_marker := false
var pan_total_delta := Vector2.ZERO
var suppress_next_marker_click := false


func ensure_expanded_opaque_backdrop() -> void:
	if root == null:
		return
	if expanded_opaque_backdrop != null and is_instance_valid(expanded_opaque_backdrop):
		return
	expanded_opaque_backdrop = ColorRect.new()
	expanded_opaque_backdrop.name = "ami_star_chart_expanded_opaque_backdrop"
	expanded_opaque_backdrop.color = Color(0.0, 0.0, 0.0, 1.0)
	expanded_opaque_backdrop.position = Vector2.ZERO
	expanded_opaque_backdrop.size = root.size
	expanded_opaque_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	expanded_opaque_backdrop.visible = false
	expanded_opaque_backdrop.z_index = -100
	root.add_child(expanded_opaque_backdrop)
	root.move_child(expanded_opaque_backdrop, 0)
	print("[AMI_STAR_CHART_DEBUG] expanded_opaque_backdrop_ready node=", expanded_opaque_backdrop)


func update_expanded_opaque_backdrop(widget_size: Vector2) -> void:
	ensure_expanded_opaque_backdrop()
	if expanded_opaque_backdrop == null or not is_instance_valid(expanded_opaque_backdrop):
		return
	if is_expanded:
		expanded_opaque_backdrop.position = Vector2.ZERO
		expanded_opaque_backdrop.size = widget_size
		expanded_opaque_backdrop.custom_minimum_size = widget_size
		expanded_opaque_backdrop.visible = true
		expanded_opaque_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.move_child(expanded_opaque_backdrop, 0)
	else:
		# Hard release the expanded backdrop footprint.  A hidden large Control should not
		# remain as an invisible input/click blocker after the chart shrinks.
		expanded_opaque_backdrop.visible = false
		expanded_opaque_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		expanded_opaque_backdrop.position = Vector2.ZERO
		expanded_opaque_backdrop.size = Vector2.ZERO
		expanded_opaque_backdrop.custom_minimum_size = Vector2.ZERO


func apply_decorative_mouse_filter_release() -> void:
	# Decorative panels are visual only. They should never eat clicks outside the
	# actual buttons/scroll content, especially after returning from expanded mode.
	if gui_state == null:
		return
	#if not gui_state.has("color_rects"):
		#return
	var keys := [
		"ami_star_chart_bg",
		"ami_star_chart_border_glow",
		"ami_star_chart_inner",
		"ami_star_chart_header_bg"
	]
	for key in keys:
		if gui_state.color_rects.has(key) and gui_state.color_rects[key] is ColorRect:
			var rect: ColorRect = gui_state.color_rects[key]
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func release_expanded_input_capture() -> void:
	if root == null or not is_instance_valid(root):
		return
	# Let clicks outside the compact chart pass through to the live map / command UI.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.clip_contents = true
	root.z_as_relative = false
	root.z_index = COMPACT_ROOT_Z_INDEX
	root.position = compact_rect.position
	root.size = compact_rect.size
	root.custom_minimum_size = compact_rect.size
	apply_decorative_mouse_filter_release()
	if expanded_opaque_backdrop != null and is_instance_valid(expanded_opaque_backdrop):
		expanded_opaque_backdrop.visible = false
		expanded_opaque_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		expanded_opaque_backdrop.position = Vector2.ZERO
		expanded_opaque_backdrop.size = Vector2.ZERO
		expanded_opaque_backdrop.custom_minimum_size = Vector2.ZERO
	_resize_widget_children(compact_rect.size)
	update_expanded_zoom_controls(compact_rect.size)
	print("[AMI_STAR_CHART_DEBUG] release_expanded_input_capture pos=", root.position, " size=", root.size, " z=", root.z_index)


func ensure_expanded_zoom_controls() -> void:
	if root == null:
		return
	if zoom_in_button != null and is_instance_valid(zoom_in_button) and zoom_out_button != null and is_instance_valid(zoom_out_button) and zoom_label != null and is_instance_valid(zoom_label):
		return

	zoom_out_button = Button.new()
	zoom_out_button.name = "ami_star_chart_zoom_out_button"
	zoom_out_button.text = "-"
	zoom_out_button.focus_mode = Control.FOCUS_NONE
	zoom_out_button.visible = false
	zoom_out_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if not zoom_out_button.pressed.is_connected(_on_zoom_out_pressed):
		zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	root.add_child(zoom_out_button)

	zoom_label = Label.new()
	zoom_label.name = "ami_star_chart_zoom_label"
	zoom_label.text = "100%"
	zoom_label.visible = false
	zoom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if gui_state != null and gui_state.get("font") != null:
		zoom_label.add_theme_font_override("font", gui_state.font)
	zoom_label.add_theme_font_size_override("font_size", 9)
	zoom_label.modulate = Color(0.72, 0.92, 1.0, 0.88)
	root.add_child(zoom_label)

	zoom_in_button = Button.new()
	zoom_in_button.name = "ami_star_chart_zoom_in_button"
	zoom_in_button.text = "+"
	zoom_in_button.focus_mode = Control.FOCUS_NONE
	zoom_in_button.visible = false
	zoom_in_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if not zoom_in_button.pressed.is_connected(_on_zoom_in_pressed):
		zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	root.add_child(zoom_in_button)
	print("[AMI_STAR_CHART_DEBUG] expanded_zoom_controls_ready")


func update_expanded_zoom_controls(widget_size: Vector2) -> void:
	ensure_expanded_zoom_controls()
	var controls_visible := root != null and is_instance_valid(root) and root.visible
	var controls_x = max(widget_size.x - 104.0, 4.0)
	if zoom_out_button != null and is_instance_valid(zoom_out_button):
		zoom_out_button.visible = controls_visible
		zoom_out_button.position = Vector2(controls_x, 5.0)
		zoom_out_button.size = Vector2(24, 20)
		zoom_out_button.disabled = (not controls_visible) or expanded_zoom <= expanded_zoom_min + 0.001
		zoom_out_button.mouse_filter = Control.MOUSE_FILTER_STOP if controls_visible else Control.MOUSE_FILTER_IGNORE
		if controls_visible:
			zoom_out_button.move_to_front()
	if zoom_label != null and is_instance_valid(zoom_label):
		zoom_label.visible = controls_visible
		zoom_label.position = Vector2(controls_x + 28.0, 7.0)
		zoom_label.size = Vector2(42, 18)
		zoom_label.text = str(int(round(expanded_zoom * 100.0))) + "%"
		zoom_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if controls_visible:
			zoom_label.move_to_front()
	if zoom_in_button != null and is_instance_valid(zoom_in_button):
		zoom_in_button.visible = controls_visible
		zoom_in_button.position = Vector2(controls_x + 74.0, 5.0)
		zoom_in_button.size = Vector2(24, 20)
		zoom_in_button.disabled = (not controls_visible) or expanded_zoom >= expanded_zoom_max - 0.001
		zoom_in_button.mouse_filter = Control.MOUSE_FILTER_STOP if controls_visible else Control.MOUSE_FILTER_IGNORE
		if controls_visible:
			zoom_in_button.move_to_front()


func get_active_zoom() -> float:
	return expanded_zoom


func _on_zoom_in_pressed() -> void:
	set_chart_zoom(expanded_zoom + expanded_zoom_step)
	print("[AMI_STAR_CHART_DEBUG] expanded_zoom_in zoom=", expanded_zoom)


func _on_zoom_out_pressed() -> void:
	set_chart_zoom(expanded_zoom - expanded_zoom_step)
	print("[AMI_STAR_CHART_DEBUG] expanded_zoom_out zoom=", expanded_zoom)


func setup(new_gui_state, config: Dictionary = {}) -> void:
	gui_state = new_gui_state
	root = config.get("root", null) as Control
	scroll = config.get("scroll", null) as ScrollContainer
	canvas = config.get("canvas", null) as Control
	expand_button = config.get("expand_button", null) as Button
	status_label = config.get("status_label", null) as Label

	var possible_log_node = config.get("log_node", config.get("log_label", null))
	if possible_log_node is Node:
		log_text_node = possible_log_node as Node
	else:
		log_text_node = null

	if config.has("compact_rect") and config.get("compact_rect") is Rect2:
		compact_rect = config.get("compact_rect")
	elif root != null:
		compact_rect = Rect2(root.position, root.size)

	expanded_top_reserved_y = float(config.get("expanded_top_reserved_y", expanded_top_reserved_y))
	expanded_padding = float(config.get("expanded_padding", expanded_padding))

	print("[AMI_STAR_CHART_DEBUG] FullFlatMapHandler.setup root=", root, " scroll=", scroll, " canvas=", canvas, " expand_button=", expand_button, " status_label=", status_label, " log_text_node=", log_text_node, " compact_rect=", compact_rect)

	if expand_button != null and not expand_button.pressed.is_connected(_on_expand_button_pressed):
		expand_button.pressed.connect(_on_expand_button_pressed)
	if expand_button != null:
		expand_button.visible = false
		expand_button.disabled = true
		expand_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if scroll != null:
		scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		if not scroll.gui_input.is_connected(_on_map_view_gui_input):
			scroll.gui_input.connect(_on_map_view_gui_input)
	if canvas != null:
		canvas.mouse_filter = Control.MOUSE_FILTER_STOP
		if not canvas.gui_input.is_connected(_on_map_view_gui_input):
			canvas.gui_input.connect(_on_map_view_gui_input)

	ensure_expanded_opaque_backdrop()
	ensure_expanded_zoom_controls()
	apply_decorative_mouse_filter_release()
	_apply_layout()
	set_waiting_for_scan()


func apply_external_rect(rect: Rect2, force_contained: bool = true) -> void:
	compact_rect = rect
	if force_contained:
		is_expanded = false
	release_expanded_input_capture()
	_apply_layout()


func set_waiting_for_scan() -> void:
	if status_label != null:
		status_label.text = "Run Sensor Sweep to populate chart."
	if canvas != null:
		_clear_canvas()
		canvas.custom_minimum_size = MIN_CANVAS_SIZE
		canvas.size = MIN_CANVAS_SIZE
		var empty_label := _make_canvas_label("NO CHART DATA", Vector2(18, 18), 14)
		canvas.add_child(empty_label)
	print("[AMI_STAR_CHART_DEBUG] FullFlatMapHandler waiting_for_scan canvas=", canvas)


func refresh_from_scan(packet: Dictionary) -> void:
	last_scan_packet = packet.duplicate(true)
	var markers = packet.get("markers", [])
	last_markers = []
	if typeof(markers) == TYPE_ARRAY:
		for marker in markers:
			if typeof(marker) == TYPE_DICTIONARY:
				last_markers.append((marker as Dictionary).duplicate(true))
	print("[AMI_STAR_CHART_DEBUG] FullFlatMapHandler.refresh_from_scan markers=", last_markers.size())
	rebuild_chart(true)


func rebuild_chart(center_on_player: bool = false) -> void:
	if canvas == null:
		print("[AMI_STAR_CHART_DEBUG] FullFlatMapHandler.rebuild blocked: canvas null")
		return
	_clear_canvas()
	var active_zoom := get_active_zoom()
	canvas_size = resolve_canvas_size(last_markers) * active_zoom
	canvas.custom_minimum_size = canvas_size
	canvas.size = canvas_size

	if last_markers.is_empty():
		if status_label != null:
			status_label.text = "Scan complete. No contacts mapped."
		var empty_label := _make_canvas_label("NO CONTACTS", Vector2(18, 18), 14)
		canvas.add_child(empty_label)
		return

	var bounds := resolve_bounds(last_markers)
	_draw_axis_lines()
	var drawn_count := 0
	var label_count := 0
	var player_screen_pos := Vector2(canvas_size.x * 0.5, canvas_size.y * 0.5)
	var player_markers: Array = []
	for marker in last_markers:
		if is_player_marker(marker):
			player_markers.append(marker)
			continue
		var screen_pos := marker_to_canvas_position(marker, bounds)
		var marker_button := make_marker_button(marker, screen_pos)
		canvas.add_child(marker_button)
		drawn_count += 1
		if should_draw_marker_label(marker):
			var marker_label := make_marker_label(marker, screen_pos)
			canvas.add_child(marker_label)
			label_count += 1

	# Player/vessel markers draw last so they always sit above stars, NPCs, hotspots, labels, and other contacts.
	for marker in player_markers:
		var screen_pos := marker_to_canvas_position(marker, bounds)
		player_screen_pos = screen_pos
		var marker_button := make_marker_button(marker, screen_pos)
		canvas.add_child(marker_button)
		marker_button.move_to_front()
		drawn_count += 1
		if should_draw_marker_label(marker):
			var marker_label := make_marker_label(marker, screen_pos)
			canvas.add_child(marker_label)
			marker_label.move_to_front()
			label_count += 1

	if status_label != null:
		var zoom_text := " Zoom " + str(int(round(active_zoom * 100.0))) + "%."
		status_label.text = "Chart: " + str(drawn_count) + " contacts. " + build_type_count_summary(last_markers) + zoom_text
	if center_on_player:
		call_deferred("_apply_scroll_center", player_screen_pos)
	print("[AMI_STAR_CHART_DEBUG] FullFlatMapHandler.rebuild DONE drawn=", drawn_count, " labels=", label_count, " canvas_size=", canvas_size, " zoom=", active_zoom, " player_screen_pos=", player_screen_pos, " counts=", build_type_count_dictionary(last_markers))


func resolve_canvas_size(markers: Array) -> Vector2:
	var count = max(markers.size(), 1)
	var width := DEFAULT_CANVAS_SIZE.x
	var height := DEFAULT_CANVAS_SIZE.y
	if count > 140:
		width = 2800
		height = 1900
	elif count > 80:
		width = 2400
		height = 1650
	return Vector2(max(width, MIN_CANVAS_SIZE.x), max(height, MIN_CANVAS_SIZE.y))


func resolve_bounds(markers: Array) -> Dictionary:
	var found := false
	var min_x := 0.0
	var max_x := 0.0
	var min_z := 0.0
	var max_z := 0.0
	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		var world_pos := read_world_pos(marker)
		if not found:
			min_x = world_pos.x
			max_x = world_pos.x
			min_z = world_pos.z
			max_z = world_pos.z
			found = true
		else:
			min_x = min(min_x, world_pos.x)
			max_x = max(max_x, world_pos.x)
			min_z = min(min_z, world_pos.z)
			max_z = max(max_z, world_pos.z)

	if not found:
		return {"min_x": -1.0, "max_x": 1.0, "min_z": -1.0, "max_z": 1.0}
	if abs(max_x - min_x) < 1.0:
		max_x += 1.0
		min_x -= 1.0
	if abs(max_z - min_z) < 1.0:
		max_z += 1.0
		min_z -= 1.0
	return {"min_x": min_x, "max_x": max_x, "min_z": min_z, "max_z": max_z}


func marker_to_canvas_position(marker: Dictionary, bounds: Dictionary) -> Vector2:
	var world_pos := read_world_pos(marker)
	var usable_w = max(canvas_size.x - MAP_PADDING * 2.0, 1.0)
	var usable_h = max(canvas_size.y - MAP_PADDING * 2.0, 1.0)
	var min_x := float(bounds.get("min_x", 0.0))
	var max_x := float(bounds.get("max_x", 1.0))
	var min_z := float(bounds.get("min_z", 0.0))
	var max_z := float(bounds.get("max_z", 1.0))
	var t_x = clamp((world_pos.x - min_x) / max(max_x - min_x, 1.0), 0.0, 1.0)
	var t_y = clamp((world_pos.z - min_z) / max(max_z - min_z, 1.0), 0.0, 1.0)
	return Vector2(MAP_PADDING + usable_w * t_x, MAP_PADDING + usable_h * t_y)


func make_marker_button(marker: Dictionary, screen_pos: Vector2) -> Button:
	var marker_type := resolve_display_marker_type(marker)
	var b := Button.new()
	b.name = "StarChartMarker_" + str(marker.get("id", "contact"))
	b.text = get_marker_glyph(marker_type)
	b.position = screen_pos - Vector2(MARKER_SIZE * 0.5, MARKER_SIZE * 0.5)
	b.size = Vector2(MARKER_SIZE, MARKER_SIZE)
	b.tooltip_text = build_marker_highlight_text(marker)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.modulate = get_marker_button_color(marker, marker_type)
	if is_player_marker(marker):
		b.z_index = 1000
	b.gui_input.connect(_on_map_view_gui_input.bind(true))
	b.pressed.connect(_on_marker_pressed.bind(marker.duplicate(true)))
	return b


func is_player_marker(marker: Dictionary) -> bool:
	return resolve_display_marker_type(marker) == "player"


func get_marker_glyph(marker_type: String) -> String:
	match marker_type:
		"player": return "◎"
		"star": return "✦"
		"planet": return "●"
		"enemy": return "!"
		"npc": return "N"
		"beacon": return "B"
		"event_hotspot": return "H"
		"hotspot": return "H"
		_: return "•"


func should_draw_marker_label(marker: Dictionary) -> bool:
	var marker_type := resolve_display_marker_type(marker)
	if last_markers.size() > 180:
		return marker_type in ["player", "star", "npc", "event_hotspot", "hotspot", "enemy", "beacon"] or marker_is_orbit_revealed(marker)
	return true


func make_marker_label(marker: Dictionary, screen_pos: Vector2) -> Label:
	var label := Label.new()
	label.name = "StarChartLabel_" + str(marker.get("id", "contact"))
	label.text = build_marker_map_label_text(marker)
	label.position = screen_pos + Vector2(10, -7)
	label.size = Vector2(310, 28)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if gui_state != null and gui_state.get("font") != null:
		label.add_theme_font_override("font", gui_state.font)
	label.add_theme_font_size_override("font_size", 9)
	label.modulate = Color(0.76, 0.90, 1.0, 0.78)
	if marker_is_orbit_revealed(marker):
		label.modulate = Color(0.48, 1.0, 0.92, 0.96)
	if is_player_marker(marker):
		label.z_index = 1001
		label.modulate = Color(0.72, 0.94, 1.0, 1.0)
	return label


func build_marker_label_text(marker: Dictionary) -> String:
	var marker_type := resolve_display_marker_type(marker)
	var prefix := ""
	match marker_type:
		"player": prefix = "YOU"
		"star": prefix = "STAR"
		"npc": prefix = "NPC"
		"event_hotspot", "hotspot": prefix = "HOT"
		"beacon": prefix = "BCN"
		"enemy": prefix = "HOST"
		_: prefix = marker_type.substr(0, min(marker_type.length(), 4)).to_upper()
	if marker_is_orbit_revealed(marker):
		prefix = "ORB"
	var display_name := str(marker.get("display_name", marker.get("id", "Contact"))).strip_edges()
	if display_name.begins_with("HOT SPOT: "):
		display_name = display_name.replace("HOT SPOT: ", "")
	if display_name.length() > 22:
		display_name = display_name.substr(0, 21) + "…"
	return prefix + " " + display_name


func build_marker_map_label_text(marker: Dictionary) -> String:
	var marker_type := resolve_display_marker_type(marker)
	var prefix := ""
	match marker_type:
		"player": prefix = "YOU"
		"star": prefix = "STAR"
		"npc": prefix = "NPC"
		"event_hotspot", "hotspot": prefix = "HOT"
		"beacon": prefix = "BCN"
		"enemy": prefix = "HOST"
		_: prefix = marker_type.substr(0, min(marker_type.length(), 4)).to_upper()
	if marker_is_orbit_revealed(marker):
		prefix = "ORB"
	var display_name := str(marker.get("display_name", marker.get("id", "Contact"))).strip_edges()
	if display_name.begins_with("HOT SPOT: "):
		display_name = display_name.replace("HOT SPOT: ", "")
	if display_name.length() > 18:
		display_name = display_name.substr(0, 17) + "..."
	var sector_text := format_vector_like(marker.get("sector", marker.get("sector_pos", "--")))
	var local_text := format_vector_like(marker.get("local", marker.get("local_pos", "--")))
	return prefix + " " + display_name + " | S " + sector_text + " | L " + local_text


func build_marker_highlight_text(marker: Dictionary) -> String:
	var marker_type := resolve_display_marker_type(marker)
	var display_name := str(marker.get("display_name", marker.get("id", "Contact"))).strip_edges()
	var sector_text := format_vector_like(marker.get("sector", marker.get("sector_pos", "--")))
	var local_text := format_vector_like(marker.get("local", marker.get("local_pos", "--")))
	var orbit_text := ""
	if marker_is_orbit_revealed(marker):
		orbit_text = "\nOrbit Survey: " + get_marker_orbit_planet_name(marker)
	var text := (
		"Label: " + display_name + "\n"
		+ "Type: " + marker_type + "\n"
		+ "Sector Pos: " + sector_text + "\n"
		+ "Local Pos: " + local_text
	)
	return text + orbit_text


func resolve_display_marker_type(marker: Dictionary) -> String:
	var marker_type := str(marker.get("type", "object")).strip_edges().to_lower()
	if marker_type == "object" and str(marker.get("object_type", "")).strip_edges() != "":
		marker_type = str(marker.get("object_type", marker_type)).strip_edges().to_lower()
	return marker_type


func get_marker_button_color(marker: Dictionary, marker_type: String) -> Color:
	if marker_is_orbit_revealed(marker):
		return ORBIT_REVEALED_COLOR
	return MARKER_COLORS.get(marker_type, MARKER_COLORS.get(str(marker.get("type", "object")).strip_edges().to_lower(), MARKER_COLORS["object"]))


func marker_is_orbit_revealed(marker: Dictionary) -> bool:
	return read_marker_bool_deep(marker, ["orbit_revealed"])


func get_marker_orbit_planet_name(marker: Dictionary) -> String:
	var planet_name := read_marker_string_deep(marker, ["orbit_revealed_by_planet_name", "parent_planet_name", "anchor_planet_name"])
	return planet_name if planet_name != "" else "planet-linked contact"


func read_marker_bool_deep(marker: Dictionary, keys: Array) -> bool:
	for key in keys:
		if marker.has(key) and bool(marker.get(key, false)):
			return true

	for nested_key in ["visual", "metadata", "meta", "shared_meta", "data_slice"]:
		var nested = marker.get(nested_key, {})
		if typeof(nested) != TYPE_DICTIONARY:
			continue
		for key in keys:
			if nested.has(key) and bool(nested.get(key, false)):
				return true

		for deeper_key in ["visual", "metadata", "meta", "shared_meta"]:
			var deeper = nested.get(deeper_key, {})
			if typeof(deeper) != TYPE_DICTIONARY:
				continue
			for key in keys:
				if deeper.has(key) and bool(deeper.get(key, false)):
					return true

	return false


func read_marker_string_deep(marker: Dictionary, keys: Array) -> String:
	for key in keys:
		var top_value := str(marker.get(key, "")).strip_edges()
		if top_value != "":
			return top_value

	for nested_key in ["visual", "metadata", "meta", "shared_meta", "data_slice"]:
		var nested = marker.get(nested_key, {})
		if typeof(nested) != TYPE_DICTIONARY:
			continue
		for key in keys:
			var nested_value := str(nested.get(key, "")).strip_edges()
			if nested_value != "":
				return nested_value

		for deeper_key in ["visual", "metadata", "meta", "shared_meta"]:
			var deeper = nested.get(deeper_key, {})
			if typeof(deeper) != TYPE_DICTIONARY:
				continue
			for key in keys:
				var deeper_value := str(deeper.get(key, "")).strip_edges()
				if deeper_value != "":
					return deeper_value

	return ""


func build_type_count_dictionary(markers: Array) -> Dictionary:
	var counts := {}
	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		var marker_type := resolve_display_marker_type(marker)
		counts[marker_type] = int(counts.get(marker_type, 0)) + 1
	return counts


func build_type_count_summary(markers: Array) -> String:
	var counts := build_type_count_dictionary(markers)
	var parts: Array = []
	for key in ["star", "npc", "hotspot", "event_hotspot", "beacon", "enemy", "object", "player"]:
		if counts.has(key):
			var label = key
			if key == "event_hotspot":
				label = "hotspot"
			parts.append(label + ":" + str(counts[key]))
	var orbit_count := count_orbit_revealed_markers(markers)
	if orbit_count > 0:
		parts.append("orbit:" + str(orbit_count))
	if parts.is_empty():
		return ""
	return "[" + ", ".join(parts) + "]"


func count_orbit_revealed_markers(markers: Array) -> int:
	var count := 0
	for marker in markers:
		if typeof(marker) == TYPE_DICTIONARY and marker_is_orbit_revealed(marker):
			count += 1
	return count


func set_chart_zoom(new_zoom: float) -> void:
	var clamped_zoom = clamp(new_zoom, expanded_zoom_min, expanded_zoom_max)
	if is_equal_approx(clamped_zoom, expanded_zoom):
		update_expanded_zoom_controls(compact_rect.size)
		return
	var normalized_center := get_scroll_normalized_center()
	expanded_zoom = clamped_zoom
	rebuild_chart(false)
	_apply_layout()
	call_deferred("_apply_scroll_normalized_center", normalized_center)


func get_scroll_normalized_center() -> Vector2:
	var base_size := Vector2(max(canvas_size.x, 1.0), max(canvas_size.y, 1.0))
	var center := base_size * 0.5
	if scroll != null and is_instance_valid(scroll):
		center = Vector2(
			float(scroll.scroll_horizontal) + scroll.size.x * 0.5,
			float(scroll.scroll_vertical) + scroll.size.y * 0.5
		)
	return Vector2(
		clamp(center.x / base_size.x, 0.0, 1.0),
		clamp(center.y / base_size.y, 0.0, 1.0)
	)


func _apply_scroll_normalized_center(normalized_center: Vector2) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	var target_center := Vector2(
		canvas_size.x * clamp(normalized_center.x, 0.0, 1.0),
		canvas_size.y * clamp(normalized_center.y, 0.0, 1.0)
	)
	scroll.scroll_horizontal = int(max(target_center.x - scroll.size.x * 0.5, 0.0))
	scroll.scroll_vertical = int(max(target_center.y - scroll.size.y * 0.5, 0.0))
	print("[AMI_STAR_CHART_DEBUG] restored_scroll_after_zoom center=", normalized_center, " scroll=", Vector2(scroll.scroll_horizontal, scroll.scroll_vertical))


func _on_map_view_gui_input(event: InputEvent, started_on_marker: bool = false) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			set_chart_zoom(expanded_zoom + expanded_zoom_step)
			accept_map_view_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			set_chart_zoom(expanded_zoom - expanded_zoom_step)
			accept_map_view_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				is_panning = true
				pan_started_on_marker = started_on_marker
				pan_total_delta = Vector2.ZERO
			else:
				if is_panning and pan_started_on_marker and pan_total_delta.length() >= PAN_DRAG_CANCEL_DISTANCE:
					suppress_next_marker_click = true
				is_panning = false
				pan_started_on_marker = false
			if not started_on_marker or suppress_next_marker_click:
				accept_map_view_event()
			return
	if event is InputEventMouseMotion and is_panning:
		var motion_event := event as InputEventMouseMotion
		var delta := motion_event.relative
		if delta == Vector2.ZERO:
			return
		pan_total_delta += delta
		scroll.scroll_horizontal = int(max(float(scroll.scroll_horizontal) - delta.x, 0.0))
		scroll.scroll_vertical = int(max(float(scroll.scroll_vertical) - delta.y, 0.0))
		accept_map_view_event()


func accept_map_view_event() -> void:
	if scroll != null and is_instance_valid(scroll):
		scroll.accept_event()
	if canvas != null and is_instance_valid(canvas):
		canvas.accept_event()


func _apply_scroll_center(screen_pos: Vector2) -> void:
	if scroll == null:
		return
	var target_x := int(max(screen_pos.x - scroll.size.x * 0.5, 0.0))
	var target_y := int(max(screen_pos.y - scroll.size.y * 0.5, 0.0))
	scroll.scroll_horizontal = target_x
	scroll.scroll_vertical = target_y
	print("[AMI_STAR_CHART_DEBUG] centered_scroll_on_player screen_pos=", screen_pos, " scroll=", Vector2(target_x, target_y), " scroll_size=", scroll.size)


func _draw_axis_lines() -> void:
	if canvas == null:
		return
	var h_line := ColorRect.new()
	h_line.name = "StarChartAxisH"
	h_line.color = Color(0.20, 0.55, 0.95, 0.18)
	h_line.position = Vector2(MAP_PADDING * 0.5, canvas_size.y * 0.5)
	h_line.size = Vector2(canvas_size.x - MAP_PADDING, 1)
	h_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(h_line)

	var v_line := ColorRect.new()
	v_line.name = "StarChartAxisV"
	v_line.color = Color(0.20, 0.55, 0.95, 0.18)
	v_line.position = Vector2(canvas_size.x * 0.5, MAP_PADDING * 0.5)
	v_line.size = Vector2(1, canvas_size.y - MAP_PADDING)
	v_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(v_line)


func _on_marker_pressed(marker: Dictionary) -> void:
	if Globals.is_popup_input_locked():
		return
	if suppress_next_marker_click:
		suppress_next_marker_click = false
		return
	selected_marker = marker.duplicate(true)
	write_marker_to_log(selected_marker)


func write_marker_to_log(marker: Dictionary) -> void:
	var target_log = log_text_node
	if target_log == null and gui_state != null and gui_state.log_storage.has("log_text"):
		target_log = gui_state.log_storage["log_text"]
	if target_log == null:
		print("[AMI_STAR_CHART_DEBUG] write_marker_to_log blocked: no log node")
		return

	var data_slice: Dictionary = {}
	if typeof(marker.get("data_slice", {})) == TYPE_DICTIONARY:
		data_slice = marker.get("data_slice", {})

	var display_type := str(marker.get("type", "unknown"))
	if display_type == "object" and str(marker.get("object_type", "")).strip_edges() != "":
		display_type = str(marker.get("object_type", "object"))

	var sector_text := format_vector_like(marker.get("sector", marker.get("sector_pos", "--")))
	var local_text := format_vector_like(marker.get("local", marker.get("local_pos", "--")))
	var world_text := format_vector_like(marker.get("world", marker.get("world_pos", "--")))
	var orbit_text := ""
	if marker_is_orbit_revealed(marker):
		orbit_text = (
			"Orbit Survey: " + get_marker_orbit_planet_name(marker) + "\n"
			+ "Revealed At: " + read_marker_string_deep(marker, ["orbit_revealed_at_text"]) + "\n"
		)

	var text := (
		"AMI STAR CHART CONTACT\n\n"
		+ "Label: " + str(marker.get("display_name", "Unknown")) + "\n"
		+ "Type: " + display_type + "\n"
		+ "Owner: " + str(marker.get("owner", "none")) + "\n"
		+ "ID: " + str(marker.get("id", "none")) + "\n"
		+ "Distance: " + str(int(round(float(marker.get("distance", 0.0))))) + "\n\n"
		+ "Sector Pos: " + sector_text + "\n"
		+ "Local Pos: " + local_text + "\n"
		+ "World X/Z Map Pos: " + world_text + "\n\n"
		+ orbit_text
		+ "Data Slice:\n" + str(data_slice)
	)

	if target_log is TextEdit:
		(target_log as TextEdit).text = text
	elif target_log is Label:
		(target_log as Label).text = text
	elif target_log is RichTextLabel:
		(target_log as RichTextLabel).text = text
	else:
		print("[AMI_STAR_CHART_DEBUG] write_marker_to_log unsupported node=", target_log)


func _on_expand_button_pressed() -> void:
	is_expanded = false
	release_expanded_input_capture()
	_apply_layout()


func claim_expanded_top_layer() -> void:
	if root == null or not is_instance_valid(root):
		return
	is_expanded = false
	release_expanded_input_capture()


func _apply_layout() -> void:
	if root == null:
		print("[AMI_STAR_CHART_DEBUG] _apply_layout blocked: root null")
		return
	is_expanded = false
	var target_rect := compact_rect
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.clip_contents = true
	root.z_as_relative = false
	root.z_index = COMPACT_ROOT_Z_INDEX

	root.position = target_rect.position
	root.size = target_rect.size
	root.custom_minimum_size = target_rect.size
	root.visible = true
	root.move_to_front()
	update_expanded_opaque_backdrop(target_rect.size)
	_resize_widget_children(target_rect.size)
	apply_decorative_mouse_filter_release()
	update_expanded_zoom_controls(target_rect.size)
	call_deferred("release_expanded_input_capture")
	if expand_button != null:
		expand_button.visible = false
		expand_button.disabled = true
		expand_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	print("[AMI_STAR_CHART_DEBUG] _apply_layout expanded=", is_expanded, " pos=", root.position, " size=", root.size, " visible=", root.visible, " tree_visible=", root.is_visible_in_tree(), " parent=", root.get_parent(), " z=", root.z_index, " z_as_relative=", root.z_as_relative, " zoom=", get_active_zoom())


func _resize_widget_children(widget_size: Vector2) -> void:
	_set_color_rect_size("ami_star_chart_bg", widget_size)
	_set_color_rect_size("ami_star_chart_border_glow", widget_size)
	_set_color_rect_pos_size("ami_star_chart_inner", Vector2(2, 2), Vector2(max(widget_size.x - 4, 1), max(widget_size.y - 4, 1)))
	_set_color_rect_pos_size("ami_star_chart_header_bg", Vector2(2, 2), Vector2(max(widget_size.x - 4, 1), 28))
	if gui_state != null and gui_state.labels.has("ami_star_chart_title"):
		var title: Label = gui_state.labels["ami_star_chart_title"]
		title.size = Vector2(max(widget_size.x - 126, 60), 20)
	if expand_button != null:
		expand_button.position = Vector2(max(widget_size.x - 78, 4), 5)
		expand_button.visible = false
		expand_button.disabled = true
		expand_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if status_label != null:
		status_label.size = Vector2(max(widget_size.x - 20, 60), 18)
	if scroll != null:
		scroll.position = Vector2(8, 56)
		scroll.size = Vector2(max(widget_size.x - 16, 40), max(widget_size.y - 64, 40))


func _set_color_rect_size(key: String, new_size: Vector2) -> void:
	if gui_state != null and gui_state.color_rects.has(key) and gui_state.color_rects[key] is ColorRect:
		var rect: ColorRect = gui_state.color_rects[key]
		rect.size = new_size


func _set_color_rect_pos_size(key: String, new_pos: Vector2, new_size: Vector2) -> void:
	if gui_state != null and gui_state.color_rects.has(key) and gui_state.color_rects[key] is ColorRect:
		var rect: ColorRect = gui_state.color_rects[key]
		rect.position = new_pos
		rect.size = new_size


func _clear_canvas() -> void:
	if canvas == null:
		return
	for child in canvas.get_children():
		child.queue_free()


func _make_canvas_label(text: String, pos: Vector2, font_size: int = 12) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = Vector2(340, 24)
	if gui_state != null and gui_state.get("font") != null:
		label.add_theme_font_override("font", gui_state.font)
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = Color(0.70, 0.86, 1.0, 0.76)
	return label


func read_world_pos(marker: Dictionary) -> Vector3:
	var value = marker.get("world_pos", null)
	if value is Vector3:
		return value
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	var sector := read_vector3i(marker.get("sector_pos", marker.get("sector", Vector3i.ZERO)))
	var local := read_vector3(marker.get("local_pos", marker.get("local", Vector3.ZERO)))
	return Vector3(
		float(sector.x) * Globals.sector_size + local.x,
		float(sector.y) * Globals.sector_size + local.y,
		float(sector.z) * Globals.sector_size + local.z
	)


func read_vector3(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector3i:
		return Vector3(value.x, value.y, value.z)
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO


func read_vector3i(value) -> Vector3i:
	if value is Vector3i:
		return value
	if value is Vector3:
		return Vector3i(int(value.x), int(value.y), int(value.z))
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3i(int(value.get("x", 0)), int(value.get("y", 0)), int(value.get("z", 0)))
	return Vector3i.ZERO


func format_vector_like(value) -> String:
	if value is Vector3:
		return str(round(value.x)) + ", " + str(round(value.y)) + ", " + str(round(value.z))
	if value is Vector3i:
		return str(value.x) + ", " + str(value.y) + ", " + str(value.z)
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return str(value[0]) + ", " + str(value[1]) + ", " + str(value[2])
	if typeof(value) == TYPE_DICTIONARY:
		return str(value.get("x", 0)) + ", " + str(value.get("y", 0)) + ", " + str(value.get("z", 0))
	return str(value)
