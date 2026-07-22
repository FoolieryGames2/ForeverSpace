extends Control
class_name OrbitGlobeView

signal marker_selected(marker_packet: Dictionary)
signal marker_selection_cleared

const WidgetSpecUiScript = preload("res://UI/Widget_spec_UI.gd")
const LATITUDE_DEGREES := [-60.0, -30.0, 0.0, 30.0, 60.0]
const LONGITUDE_DEGREES := [-75.0, -45.0, -15.0, 15.0, 45.0, 75.0]
const CURVE_STEPS := 72
const MARKER_RADIUS := 4.5
const MARKER_SELECTED_RADIUS := 6.0
const MARKER_HIT_RADIUS := 12.0

var target_body: Dictionary = {}
var scan_result: Dictionary = {}
var survey_result: Dictionary = {}
var scan_markers: Array = []
var projected_markers: Array = []
var widget_theme_palette: Dictionary = {}
var selected_marker_id := ""
var view_rotation := 0.0
var rotation_speed := 0.10
var scan_pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func set_target_body(body: Dictionary) -> void:
	target_body = body.duplicate(true)
	queue_redraw()


func set_scan_result(result: Dictionary) -> void:
	scan_result = result.duplicate(true)
	queue_redraw()


func set_scan_markers(markers: Array) -> void:
	scan_markers = markers.duplicate(true)
	if selected_marker_id != "" and not has_scan_marker_id(selected_marker_id):
		selected_marker_id = ""
	queue_redraw()


func clear_selected_marker() -> void:
	if selected_marker_id == "":
		return
	selected_marker_id = ""
	marker_selection_cleared.emit()
	queue_redraw()


func set_survey_result(result: Dictionary) -> void:
	survey_result = result.duplicate(true)
	queue_redraw()


func set_widget_theme_palette(palette: Dictionary) -> void:
	widget_theme_palette = palette.duplicate(true)
	queue_redraw()


func _process(delta: float) -> void:
	view_rotation = fposmod(view_rotation + (delta * rotation_speed), TAU)
	scan_pulse = fposmod(scan_pulse + (delta * 1.8), TAU)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var marker := find_marker_at_position(mouse_event.position)
	if marker.is_empty():
		clear_selected_marker()
		return

	selected_marker_id = str(marker.get("id", ""))
	marker_selected.emit(marker.duplicate(true))
	accept_event()
	queue_redraw()


func _draw() -> void:
	if size.x <= 8.0 or size.y <= 8.0:
		return

	var center := size * 0.5
	var radius: float = min(size.x, size.y) * 0.40
	var palette := build_palette()

	draw_widget_frame(palette)
	draw_circle(center, radius + 10.0, palette["atmosphere_outer"])
	draw_circle(center, radius + 4.0, palette["atmosphere_inner"])
	draw_circle(center, radius, palette["body"])
	draw_surface_shading(center, radius)
	draw_longitude_lines(center, radius, palette)
	draw_latitude_lines(center, radius, palette)
	draw_equator(center, radius, palette)
	draw_scan_markers(center, radius, palette)
	draw_scan_pulse(center, radius, palette)
	draw_circle_arc(center, radius, palette["limb"], 2.0)


func build_palette() -> Dictionary:
	var theme := get_theme_palette()
	var body := get_planet_body_color()
	var grid: Color = theme.get("globe_grid", Color(0.68, 0.92, 1.0, 0.22))
	var equator: Color = theme.get("globe_equator", Color(0.76, 1.0, 0.88, 0.32))
	var pulse: Color = theme.get("globe_scan", Color(0.76, 1.0, 0.88, 0.36))

	return {
		"body": body,
		"grid": grid,
		"equator": equator,
		"pulse": pulse,
		"limb": theme.get("globe_limb", Color(0.88, 1.0, 1.0, 0.54)),
		"frame_bg": theme.get("globe_bg", Color(0.008, 0.022, 0.035, 0.82)),
		"frame_border": theme.get("panel_border_soft", Color(0.16, 0.50, 0.66, 0.38)),
		"frame_accent": theme.get("accent_dim", Color(0.32, 0.72, 0.86, 0.72)),
		"marker_resource": theme.get("action", Color(0.70, 1.0, 0.76, 0.92)),
		"marker_story": theme.get("warning", Color(1.0, 0.86, 0.46, 0.92)),
		"marker_site": theme.get("accent", Color(0.46, 0.95, 1.0, 0.96)),
		"marker_action": Color(0.92, 0.70, 1.0, 0.92),
		"marker_outline": Color(0.0, 0.0, 0.0, 0.68),
		"marker_selected": Color(1.0, 1.0, 1.0, 0.88),
		"atmosphere_inner": Color(body.r + 0.12, body.g + 0.16, body.b + 0.20, 0.12),
		"atmosphere_outer": Color(body.r + 0.08, body.g + 0.12, body.b + 0.18, 0.06)
	}


func get_theme_palette() -> Dictionary:
	if not widget_theme_palette.is_empty():
		return widget_theme_palette
	return WidgetSpecUiScript.get_orbit_widget_theme_palette()


func draw_widget_frame(palette: Dictionary) -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, palette["frame_bg"], true)
	draw_rect(rect.grow(-0.5), palette["frame_border"], false, 1.0)
	draw_line(Vector2(10.0, 10.0), Vector2(max(size.x - 10.0, 10.0), 10.0), palette["frame_accent"], 1.0, true)


func get_planet_body_color() -> Color:
	var planet_type := str(target_body.get("planet_type", target_body.get("object_type", ""))).to_lower()
	var planet_role := str(target_body.get("planet_role", "")).to_lower()

	if planet_type.find("ice") >= 0 or planet_type.find("frozen") >= 0:
		return Color(0.20, 0.46, 0.64, 1.0)
	if planet_type.find("desert") >= 0 or planet_type.find("arid") >= 0:
		return Color(0.50, 0.38, 0.22, 1.0)
	if planet_type.find("volcan") >= 0 or planet_type.find("lava") >= 0:
		return Color(0.45, 0.15, 0.10, 1.0)
	if planet_type.find("ocean") >= 0 or planet_type.find("water") >= 0:
		return Color(0.08, 0.32, 0.55, 1.0)
	if planet_type.find("gas") >= 0:
		return Color(0.40, 0.35, 0.58, 1.0)
	if planet_role.find("resource") >= 0 or planet_role.find("mining") >= 0:
		return Color(0.24, 0.36, 0.31, 1.0)
	if planet_role.find("anomaly") >= 0 or planet_role.find("silent") >= 0:
		return Color(0.28, 0.25, 0.40, 1.0)
	return Color(0.12, 0.34, 0.38, 1.0)


func draw_surface_shading(center: Vector2, radius: float) -> void:
	var band_count := 20
	for i in range(band_count):
		var t := float(i) / float(band_count - 1)
		var x = lerp(-radius, radius, t)
		var chord := sqrt(max(0.0, (radius * radius) - (x * x)))
		var darkness = clamp((x / radius + 0.20) * 0.18, 0.0, 0.22)
		var lightness = clamp((-x / radius - 0.35) * 0.08, 0.0, 0.08)
		var width = max(1.0, (radius * 2.0) / float(band_count))
		if darkness > 0.0:
			draw_line(center + Vector2(x, -chord), center + Vector2(x, chord), Color(0.0, 0.0, 0.0, darkness), width, true)
		if lightness > 0.0:
			draw_line(center + Vector2(x, -chord), center + Vector2(x, chord), Color(1.0, 1.0, 1.0, lightness), width, true)


func draw_latitude_lines(center: Vector2, radius: float, palette: Dictionary) -> void:
	for raw_lat in LATITUDE_DEGREES:
		var lat := deg_to_rad(float(raw_lat))
		var y := -sin(lat) * radius
		var latitude_radius := cos(lat) * radius
		var ellipse_height = max(2.0, latitude_radius * 0.13)
		draw_projected_ellipse(center + Vector2(0.0, y), latitude_radius, ellipse_height, palette["grid"], 1.0)


func draw_equator(center: Vector2, radius: float, palette: Dictionary) -> void:
	draw_projected_ellipse(center, radius, max(2.0, radius * 0.13), palette["equator"], 1.5)


func draw_longitude_lines(center: Vector2, radius: float, palette: Dictionary) -> void:
	for raw_lon in LONGITUDE_DEGREES:
		var lon := deg_to_rad(float(raw_lon)) + view_rotation
		var meridian_radius = abs(sin(lon)) * radius
		if meridian_radius <= 1.0:
			draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), palette["grid"], 1.0, true)
		else:
			draw_projected_ellipse(center, meridian_radius, radius, palette["grid"], 1.0)


func draw_scan_pulse(center: Vector2, radius: float, palette: Dictionary) -> void:
	var has_scan := not scan_result.is_empty() or bool(target_body.get("orbit_planet_scanned", false))
	var has_survey := not survey_result.is_empty()
	if not has_scan and not has_survey:
		return

	var wave := (sin(scan_pulse) + 1.0) * 0.5
	var scan_radius := radius + 5.0 + (wave * 5.0)
	var pulse_color: Color = palette["pulse"]
	pulse_color.a = 0.18 + (wave * 0.12)
	draw_circle_arc(center, scan_radius, pulse_color, 1.5)


func draw_scan_markers(center: Vector2, radius: float, palette: Dictionary) -> void:
	projected_markers = build_projected_marker_packets(center, radius)
	for projected in projected_markers:
		if typeof(projected) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = projected
		if not bool(packet.get("visible", false)):
			continue
		var marker = packet.get("marker", {})
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		draw_scan_marker(marker, packet.get("position", center), palette)


func draw_scan_marker(marker: Dictionary, position: Vector2, palette: Dictionary) -> void:
	var marker_id := str(marker.get("id", ""))
	var is_selected := selected_marker_id != "" and marker_id == selected_marker_id
	var radius := MARKER_SELECTED_RADIUS if is_selected else MARKER_RADIUS
	var color := get_marker_color(marker, palette)
	var outline: Color = palette["marker_outline"]

	draw_circle(position, radius + 2.0, outline)
	match get_marker_shape(marker):
		"diamond":
			draw_marker_diamond(position, radius + 1.0, color, outline)
		"square":
			var rect := Rect2(position - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
			draw_rect(rect, color, true)
			draw_rect(rect, outline, false, 1.0)
		_:
			draw_circle(position, radius, color)

	if is_selected:
		draw_circle_arc(position, radius + 5.0, palette["marker_selected"], 1.5)


func draw_marker_diamond(position: Vector2, radius: float, color: Color, outline: Color) -> void:
	var points := PackedVector2Array([
		position + Vector2(0.0, -radius),
		position + Vector2(radius, 0.0),
		position + Vector2(0.0, radius),
		position + Vector2(-radius, 0.0)
	])
	draw_colored_polygon(points, color)

	var outline_points := PackedVector2Array(points)
	outline_points.append(points[0])
	draw_polyline(outline_points, outline, 1.0, true)


func get_marker_color(marker: Dictionary, palette: Dictionary) -> Color:
	var category := str(marker.get("category", "")).to_lower()
	var kind := str(marker.get("kind", "")).to_lower()
	if category in ["resource", "planet_resource", "mining_claim", "resource_site"]:
		return palette["marker_resource"]
	if category in ["event_signal", "message", "board_event", "story", "planet_reading"] or kind == "event_listener":
		return palette["marker_story"]
	if category in ["surface_site", "structure", "service", "contact"]:
		return palette["marker_site"]
	if kind == "interaction" or category == "orbit_action":
		return palette["marker_action"]
	return palette["marker_site"]


func get_marker_shape(marker: Dictionary) -> String:
	var category := str(marker.get("category", "")).to_lower()
	var kind := str(marker.get("kind", "")).to_lower()
	if category in ["event_signal", "message", "board_event", "story", "planet_reading"] or kind == "event_listener":
		return "diamond"
	if category in ["surface_site", "structure", "service", "contact"]:
		return "square"
	return "circle"


func find_marker_at_position(local_position: Vector2) -> Dictionary:
	if scan_markers.is_empty() or size.x <= 8.0 or size.y <= 8.0:
		return {}

	var center := size * 0.5
	var radius: float = min(size.x, size.y) * 0.40
	var packets := build_projected_marker_packets(center, radius)
	for i in range(packets.size() - 1, -1, -1):
		var projected = packets[i]
		if typeof(projected) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = projected
		if not bool(packet.get("visible", false)):
			continue
		var position: Vector2 = packet.get("position", center)
		var hit_radius := float(packet.get("hit_radius", MARKER_HIT_RADIUS))
		if local_position.distance_to(position) <= hit_radius:
			var marker = packet.get("marker", {})
			if typeof(marker) == TYPE_DICTIONARY:
				return marker
	return {}


func build_projected_marker_packets(center: Vector2, radius: float) -> Array:
	var packets := []
	for marker in scan_markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		var marker_packet: Dictionary = marker
		var latitude = clamp(float(marker_packet.get("latitude_deg", marker_packet.get("latitude", 0.0))), -82.0, 82.0)
		var longitude := float(marker_packet.get("longitude_deg", marker_packet.get("longitude", 0.0)))
		var projected := project_lat_lon(latitude, longitude, center, radius)
		projected["marker"] = marker_packet
		projected["hit_radius"] = float(marker_packet.get("hit_radius", MARKER_HIT_RADIUS))
		packets.append(projected)
	return packets


func project_lat_lon(latitude_deg: float, longitude_deg: float, center: Vector2, radius: float) -> Dictionary:
	var lat := deg_to_rad(latitude_deg)
	var lon := deg_to_rad(longitude_deg) + view_rotation
	var x := cos(lat) * sin(lon) * radius
	var y := -sin(lat) * radius
	var depth := cos(lat) * cos(lon)
	return {
		"position": center + Vector2(x, y),
		"depth": depth,
		"visible": depth >= -0.08
	}


func has_scan_marker_id(marker_id: String) -> bool:
	for marker in scan_markers:
		if typeof(marker) == TYPE_DICTIONARY and str(marker.get("id", "")) == marker_id:
			return true
	return false


func draw_projected_ellipse(center: Vector2, radius_x: float, radius_y: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in range(CURVE_STEPS + 1):
		var angle := (float(i) / float(CURVE_STEPS)) * TAU
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_polyline(points, color, width, true)


func draw_circle_arc(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in range(CURVE_STEPS + 1):
		var angle := (float(i) / float(CURVE_STEPS)) * TAU
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius))
	draw_polyline(points, color, width, true)
