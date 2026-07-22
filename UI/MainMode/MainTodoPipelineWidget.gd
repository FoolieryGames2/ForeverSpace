extends Control
class_name MainTodoPipelineWidget

const FINISH_LABEL := "EXE"

var events: Array = []
var runtime_seconds := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func _process(delta: float) -> void:
	runtime_seconds += delta
	queue_redraw()


func set_snapshot(snapshot: Array) -> void:
	events = snapshot.duplicate(true)
	queue_redraw()


func clear() -> void:
	events.clear()
	queue_redraw()


func _draw() -> void:
	var local_size := size
	if local_size.x <= 0.0 or local_size.y <= 0.0:
		return

	var lane_rect := Rect2(Vector2(8, 6), Vector2(local_size.x - 16, max(local_size.y - 12, 24.0)))
	draw_rect(Rect2(Vector2.ZERO, local_size), Color(0.012, 0.026, 0.052, 0.72), true)
	draw_rect(lane_rect, Color(0.025, 0.085, 0.130, 0.52), true)
	draw_rect(lane_rect, Color(0.18, 0.64, 0.95, 0.20), false, 1.0)

	var finish_y := lane_rect.position.y + lane_rect.size.y - 8.0
	draw_line(
		Vector2(lane_rect.position.x + 6.0, finish_y),
		Vector2(lane_rect.position.x + lane_rect.size.x - 6.0, finish_y),
		Color(0.36, 0.86, 1.0, 0.72),
		2.0
	)
	draw_string(
		get_theme_default_font(),
		Vector2(lane_rect.position.x + lane_rect.size.x - 32.0, finish_y - 5.0),
		FINISH_LABEL,
		HORIZONTAL_ALIGNMENT_LEFT,
		28.0,
		9,
		Color(0.62, 0.92, 1.0, 0.84)
	)

	if events.is_empty():
		return

	for i in range(events.size()):
		var event: Dictionary = events[i]
		draw_event_chip(event, lane_rect, i)


func draw_event_chip(event: Dictionary, lane_rect: Rect2, index: int) -> void:
	var event_type := str(event.get("type", "")).strip_edges().to_lower()
	var progress = clamp(float(event.get("progress", 0.0)), 0.0, 1.0)
	var chip_size := Vector2(max(lane_rect.size.x - 28.0, 90.0), 18.0)
	var start_y := lane_rect.position.y + 8.0
	var finish_y := lane_rect.position.y + lane_rect.size.y - chip_size.y - 12.0
	var x_nudge := float(index % 2) * 8.0
	var pos := Vector2(lane_rect.position.x + 14.0 + x_nudge, lerp(start_y, finish_y, progress))
	var chip_rect := Rect2(pos, chip_size)
	var chip_color := get_event_color(event_type)

	if event_type == "scan":
		draw_scan_pulse(chip_rect)

	draw_rect(chip_rect, chip_color, true)
	draw_rect(chip_rect, Color(0.72, 0.94, 1.0, 0.34), false, 1.0)

	var text := str(event.get("text", event_type)).strip_edges()
	var time_left = max(float(event.get("time_left", 0.0)), 0.0)
	if text == "":
		text = event_type.capitalize()
	draw_string(
		get_theme_default_font(),
		chip_rect.position + Vector2(6.0, 13.0),
		text + " | " + ("%0.1f" % time_left) + "s",
		HORIZONTAL_ALIGNMENT_LEFT,
		chip_rect.size.x - 12.0,
		9,
		Color(0.92, 0.98, 1.0, 0.95)
	)


func draw_scan_pulse(chip_rect: Rect2) -> void:
	var pulse := 0.5 + 0.5 * sin(runtime_seconds * 5.4)
	var center := chip_rect.position + Vector2(13.0, chip_rect.size.y * 0.5)
	var radius := 11.0 + pulse * 7.0
	draw_arc(center, radius, 0.0, TAU, 36, Color(0.25, 0.72, 1.0, 0.32 + pulse * 0.22), 2.0, true)
	draw_circle(center, 3.0 + pulse * 1.4, Color(0.58, 0.90, 1.0, 0.72))


func get_event_color(event_type: String) -> Color:
	match event_type:
		"scan":
			return Color(0.04, 0.34, 0.62, 0.94)
		"mining":
			return Color(0.43, 0.34, 0.12, 0.94)
		"engage_enemy", "enter_battle":
			return Color(0.56, 0.18, 0.16, 0.94)
		"craft_blueprint":
			return Color(0.28, 0.38, 0.18, 0.94)
		_:
			return Color(0.16, 0.35, 0.40, 0.94)
