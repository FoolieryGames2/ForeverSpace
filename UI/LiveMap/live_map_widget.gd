extends Control
class_name LiveMapWidget




const PLAYER_COLOR := Color(0.4, 0.8, 1.0, 1.0)
const FRAME_COLOR := Color(0.05, 0.09, 0.13, 0.96)
const MAP_FILL_COLOR := Color(0.015, 0.025, 0.035, 0.1)
const MAP_BORDER_COLOR := Color(0.22, 0.75, 0.95, 0.3)
const RANGE_RING_COLOR := Color(0.20, 0.55, 0.70, 0.38)

var map_radius: float = 68.0
var map_center: Vector2 = Vector2(80, 75)
var marker_layer: Control = null
var title_label: Label = null
var status_label: Label = null



func setup_widget(widget_size: Vector2) -> void:
	# Summary: Build the round visual shell and marker layer for the Live Map V1 control.
	size = widget_size
	mouse_filter = Control.MOUSE_FILTER_PASS

	map_radius = min(widget_size.y * 0.44, 70.0)
	map_center = Vector2(map_radius + 12.0, widget_size.y * 0.5)

	marker_layer = Control.new()
	marker_layer.name = "LiveMapMarkerLayer"
	marker_layer.position = map_center - Vector2(map_radius, map_radius)
	marker_layer.size = Vector2(map_radius * 2.0, map_radius * 2.0)
	marker_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(marker_layer)

	title_label = Label.new()
	title_label.name = "LiveMapTitle"
	title_label.text = "Proximity Sensors"
	title_label.position = Vector2(map_center.x + map_radius + 18.0, 18.0)
	title_label.size = Vector2(max(widget_size.x - title_label.position.x - 12.0, 80.0), 24.0)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 16)
	
	add_child(title_label)

	status_label = Label.new()
	status_label.name = "LiveMapStatus"
	status_label.text = "Contacts: 0"
	status_label.position = Vector2(title_label.position.x, 48.0)
	status_label.size = Vector2(title_label.size.x, 22.0)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_font_size_override("font_size", 13)
	add_child(status_label)

	queue_redraw()


func apply_widget_size(widget_size: Vector2) -> void:
	size = widget_size

	var vertical_layout := widget_size.y > widget_size.x * 1.15
	if vertical_layout:
		map_radius = min(widget_size.x * 0.40, 135.0)
		map_center = Vector2(widget_size.x * 0.5, map_radius + 62.0)
		if title_label != null:
			title_label.position = Vector2(12.0, 14.0)
			title_label.size = Vector2(max(widget_size.x - 24.0, 80.0), 24.0)
		if status_label != null:
			status_label.position = Vector2(12.0, 38.0)
			status_label.size = Vector2(max(widget_size.x - 24.0, 80.0), 22.0)
	else:
		map_radius = min(widget_size.y * 0.44, 70.0)
		map_center = Vector2(map_radius + 12.0, widget_size.y * 0.5)
		if title_label != null:
			title_label.position = Vector2(map_center.x + map_radius + 18.0, 18.0)
			title_label.size = Vector2(max(widget_size.x - title_label.position.x - 12.0, 80.0), 24.0)
		if status_label != null:
			status_label.position = Vector2(title_label.position.x, 48.0)
			status_label.size = Vector2(title_label.size.x, 22.0)

	if marker_layer != null:
		marker_layer.position = map_center - Vector2(map_radius, map_radius)
		marker_layer.size = Vector2(map_radius * 2.0, map_radius * 2.0)

	queue_redraw()


func clear_markers() -> void:
	# Summary: Remove old marker nodes before a fresh Live Map scan packet is drawn.
	if marker_layer == null:
		return

	for child in marker_layer.get_children():
		if child is LiveMapMarker:
			var marker := child as LiveMapMarker
			marker.set_clickable_enabled(false)
		child.queue_free()


func add_marker(marker: LiveMapMarker) -> void:
	# Summary: Add one already-positioned marker node to the marker layer.
	if marker_layer == null:
		return

	marker_layer.add_child(marker)


func set_contact_count(count: int) -> void:
	# Summary: Keep the compact status label synced to the current drawn marker count.
	if status_label != null:
		status_label.text = "Contacts: " + str(count)


func _draw() -> void:
	# Summary: Draw the round live-map shell, range ring, and centered player marker.
	#draw_rect(Rect2(Vector2.ZERO, size), FRAME_COLOR, true)
	draw_circle(map_center, map_radius, MAP_FILL_COLOR)
	draw_arc(map_center, map_radius, 0.0, TAU, 96, MAP_BORDER_COLOR, 2.0, true)
	draw_arc(map_center, map_radius * 0.66, 0.0, TAU, 96, RANGE_RING_COLOR, 1.0, true)
	draw_arc(map_center, map_radius * 0.33, 0.0, TAU, 96, RANGE_RING_COLOR, 1.0, true)
	draw_line(map_center + Vector2(-map_radius, 0.0), map_center + Vector2(map_radius, 0.0), RANGE_RING_COLOR, 1.0)
	draw_line(map_center + Vector2(0.0, -map_radius), map_center + Vector2(0.0, map_radius), RANGE_RING_COLOR, 1.0)
	draw_circle(map_center, 4.5, PLAYER_COLOR)
