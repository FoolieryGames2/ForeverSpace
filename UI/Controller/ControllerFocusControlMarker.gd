extends Control
class_name ControllerFocusControlMarker


const BORDER_COLOR := Color(1.0, 0.95, 0.10, 1.0)
const INNER_COLOR := Color(1.0, 1.0, 1.0, 0.90)
const FILL_COLOR := Color(1.0, 0.82, 0.04, 0.42)

var pulse_time := 0.0


func controller_procedural_ui_enabled() -> bool:
	return bool(Globals.get("show_controller_procedural_ui"))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	z_index = 12000
	z_as_relative = false
	set_process(true)


func _has_point(_point: Vector2) -> bool:
	return false


func _process(delta: float) -> void:
	if not controller_procedural_ui_enabled():
		visible = false
		return

	visible = true
	pulse_time += delta
	queue_redraw()


func _draw() -> void:
	if not controller_procedural_ui_enabled():
		return

	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var pulse := 0.92 + (sin(pulse_time * 6.0) * 0.08)
	var fill := FILL_COLOR
	fill.a *= pulse
	draw_rect(rect, fill, true)

	var border := BORDER_COLOR
	border.a *= pulse
	draw_rect(rect.grow(-1.0), border, false, 5.0)

	var inner := INNER_COLOR
	inner.a *= pulse
	draw_rect(rect.grow(-6.0), inner, false, 2.0)

	var corner_len = min(14.0, min(rect.size.x, rect.size.y) * 0.30)
	var p0 := Vector2(2.0, 2.0)
	var p1 := Vector2(rect.size.x - 2.0, 2.0)
	var p2 := Vector2(rect.size.x - 2.0, rect.size.y - 2.0)
	var p3 := Vector2(2.0, rect.size.y - 2.0)

	draw_line(p0, p0 + Vector2(corner_len, 0.0), border, 6.0)
	draw_line(p0, p0 + Vector2(0.0, corner_len), border, 6.0)
	draw_line(p1, p1 - Vector2(corner_len, 0.0), border, 6.0)
	draw_line(p1, p1 + Vector2(0.0, corner_len), border, 6.0)
	draw_line(p2, p2 - Vector2(corner_len, 0.0), border, 6.0)
	draw_line(p2, p2 - Vector2(0.0, corner_len), border, 6.0)
	draw_line(p3, p3 + Vector2(corner_len, 0.0), border, 6.0)
	draw_line(p3, p3 - Vector2(0.0, corner_len), border, 6.0)
