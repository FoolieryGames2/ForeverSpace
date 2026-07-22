extends Control
class_name BattlePathTrail

@export_file("*.json") var path_file: String = "res://data/battle_ui_paths/battle_log_wobble_trace.json"

@export var autostart: bool = true
@export var loop_path: bool = true
@export var duration_override: float = -1.0

@export var spawn_interval: float = 0.018
@export var trail_life: float = 0.42
@export var head_size: float = 3.5
@export var trail_size_min: float = 1.4
@export var trail_size_max: float = 3.0

@export var draw_debug_path: bool = false

var path_id: String = ""
var path_duration: float = 0.7
var points: Array[Vector2] = []
var segment_lengths: Array[float] = []
var total_length: float = 0.0

var running: bool = false
var travel_distance: float = 0.0
var spawn_timer: float = 0.0
var head_pos: Vector2 = Vector2.ZERO

var trail_dots: Array[Dictionary] = []

const GUIDE_MODE_PATH := "path"
const GUIDE_MODE_TO_TARGET := "to_target"
const GUIDE_MODE_HOLD := "hold"
const GUIDE_MODE_RETURN := "return"

var guide_mode: String = GUIDE_MODE_PATH
var guide_packet: Dictionary = {}
var guide_break_distance: float = 0.0
var guide_break_pos: Vector2 = Vector2.ZERO
var guide_move_start_pos: Vector2 = Vector2.ZERO
var guide_target_pos: Vector2 = Vector2.ZERO
var guide_move_elapsed: float = 0.0
var guide_move_duration: float = 0.45
var guide_hold_elapsed: float = 0.0
var guide_hold_duration: float = 4.0
var guide_popup_root: Panel = null
var guide_countdown_label: Label = null
var guide_line_enabled: bool = false
var guide_line_to_pos: Vector2 = Vector2.ZERO
var guide_line_color: Color = Color(0.55, 0.90, 1.0, 0.65)
var guide_circle_color: Color = Color(0.55, 0.90, 1.0, 0.35)
var guide_circle_radius: float = 18.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 900

	_load_path(path_file)

	if autostart:
		start()


func start() -> void:
	if points.size() < 2:
		return

	running = true
	set_process(true)


func stop() -> void:
	running = false
	set_process(false)


func _process(delta: float) -> void:
	if guide_mode != GUIDE_MODE_PATH:
		_process_guidance(delta)
		_spawn_trail(delta)
		_update_trail(delta)
		queue_redraw()
		return

	if not running:
		return

	if points.size() < 2 or total_length <= 0.0:
		return

	var safe_duration = max(path_duration, 0.01)
	var speed = total_length / safe_duration

	travel_distance += speed * delta

	if loop_path:
		travel_distance = fmod(travel_distance, total_length)
	else:
		travel_distance = min(travel_distance, total_length)

	head_pos = _get_position_at_distance(travel_distance)

	_spawn_trail(delta)
	_update_trail(delta)

	queue_redraw()


func _draw() -> void:
	if draw_debug_path and points.size() >= 2:
		_draw_debug_path_lines()

	if guide_line_enabled and guide_mode == GUIDE_MODE_HOLD:
		draw_line(head_pos, guide_line_to_pos, guide_line_color, float(guide_packet.get("line_width", 2.0)), true)
		draw_circle(guide_line_to_pos, guide_circle_radius, guide_circle_color)

	for dot in trail_dots:
		var age: float = dot.get("age", 0.0)
		var life: float = dot.get("life", trail_life)
		var t = clamp(age / max(life, 0.01), 0.0, 1.0)

		var alpha = 1.0 - t
		var size: float = dot.get("size", 2.0)
		var pos: Vector2 = dot.get("pos", Vector2.ZERO)

		# soft outer glow
		draw_circle(
			pos,
			size * 2.5,
			Color(0.75, 0.9, 1.0, alpha * 0.12)
		)

		# white particle core
		draw_circle(
			pos,
			size,
			Color(0.92, 0.96, 1.0, alpha * 0.55)
		)

	# moving head glow
	draw_circle(
		head_pos,
		head_size * 3.0,
		Color(0.75, 0.9, 1.0, 0.20)
	)

	# moving head core
	draw_circle(
		head_pos,
		head_size,
		Color(1.0, 1.0, 1.0, 0.95)
	)


func show_guidance_packet(packet: Dictionary) -> Dictionary:
	var target_pos := get_packet_vector2(packet, "target_position", head_pos)
	var text := str(packet.get("text", packet.get("message", ""))).strip_edges()
	if text == "":
		return {"status": "failed", "reason": "missing guidance text"}

	remove_guidance_popup(true)
	Globals.set_popup_input_lock("tutorial_popup", true)
	guide_packet = packet.duplicate(true)
	guide_break_distance = travel_distance
	guide_break_pos = head_pos
	guide_move_start_pos = head_pos
	guide_target_pos = target_pos
	guide_move_elapsed = 0.0
	guide_hold_elapsed = 0.0
	guide_move_duration = max(float(packet.get("move_duration", 0.45)), 0.05)
	guide_hold_duration = max(float(packet.get("duration", packet.get("hold_duration", 4.0))), 0.25)
	guide_line_enabled = bool(packet.get("draw_line", packet.get("line_enabled", false)))
	guide_line_to_pos = get_packet_vector2(packet, "line_to_position", guide_target_pos)
	guide_line_color = get_packet_color(packet, "line_color", Color(0.55, 0.90, 1.0, 0.65))
	guide_circle_color = get_packet_color(packet, "circle_color", Color(0.55, 0.90, 1.0, 0.35))
	guide_circle_radius = max(float(packet.get("circle_radius", 18.0)), 2.0)
	guide_mode = GUIDE_MODE_TO_TARGET
	running = true
	set_process(true)
	return {"status": "success", "target_position": target_pos}


func _process_guidance(delta: float) -> void:
	if guide_mode == GUIDE_MODE_TO_TARGET:
		guide_move_elapsed += delta
		var t = clamp(guide_move_elapsed / max(guide_move_duration, 0.01), 0.0, 1.0)
		var eased_t := 1.0 - pow(1.0 - t, 2.0)
		head_pos = guide_move_start_pos.lerp(guide_target_pos, eased_t)
		if t >= 1.0:
			head_pos = guide_target_pos
			guide_mode = GUIDE_MODE_HOLD
			guide_hold_elapsed = 0.0
			spawn_guidance_popup()
		return

	if guide_mode == GUIDE_MODE_HOLD:
		guide_hold_elapsed += delta
		update_guidance_countdown()
		if guide_hold_elapsed >= guide_hold_duration:
			var completed_packet := guide_packet.duplicate(false)
			remove_guidance_popup(true)
			guide_mode = GUIDE_MODE_RETURN
			guide_move_elapsed = 0.0
			guide_move_start_pos = head_pos
			dispatch_guidance_complete(completed_packet)
		return

	if guide_mode == GUIDE_MODE_RETURN:
		guide_move_elapsed += delta
		var return_duration = max(float(guide_packet.get("return_duration", guide_move_duration)), 0.05)
		var t = clamp(guide_move_elapsed / return_duration, 0.0, 1.0)
		var eased_t := 1.0 - pow(1.0 - t, 2.0)
		head_pos = guide_move_start_pos.lerp(guide_break_pos, eased_t)
		if t >= 1.0:
			travel_distance = guide_break_distance
			head_pos = guide_break_pos
			guide_mode = GUIDE_MODE_PATH
			guide_packet.clear()


func spawn_guidance_popup() -> void:
	remove_guidance_popup(false)

	var popup_size := get_packet_vector2(guide_packet, "popup_size", Vector2(280, 116))
	popup_size.x = max(popup_size.x, 180.0)
	popup_size.y = max(popup_size.y, 78.0)
	var popup_offset := get_packet_vector2(guide_packet, "popup_offset", Vector2(26, -18))
	var popup_pos := clamp_popup_position(guide_target_pos + popup_offset, popup_size)
	var accent := get_packet_color(guide_packet, "accent_color", Color(0.25, 0.85, 1.0, 0.92))

	guide_popup_root = Panel.new()
	guide_popup_root.name = "GuidancePrompt"
	guide_popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_popup_root.position = popup_pos
	guide_popup_root.size = popup_size
	add_child(guide_popup_root)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.040, 0.070, 0.76)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = accent
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	guide_popup_root.add_theme_stylebox_override("panel", style)

	Globals.apply_popup_panel_theme(
		guide_popup_root,
		popup_size,
		accent,
		"tutorial_popup_aurora_background",
		"tutorial_popup_theme_frame"
	)

	var title_text := str(guide_packet.get("title", ""))
	if title_text.strip_edges() != "":
		var title := Label.new()
		title.name = "GuidanceTitle"
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.z_index = 30
		title.text = title_text
		title.position = Vector2(12, 8)
		title.size = Vector2(popup_size.x - 68, 20)
		title.add_theme_font_size_override("font_size", 13)
		title.add_theme_color_override("font_color", accent)
		guide_popup_root.add_child(title)

	var body := Label.new()
	body.name = "GuidanceText"
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.z_index = 30
	body.text = str(guide_packet.get("text", guide_packet.get("message", "")))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.position = Vector2(12, 30 if title_text.strip_edges() != "" else 12)
	body.size = Vector2(popup_size.x - 24, popup_size.y - body.position.y - 10)
	body.add_theme_font_size_override("font_size", int(guide_packet.get("font_size", 13)))
	body.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0, 0.96))
	guide_popup_root.add_child(body)

	guide_countdown_label = Label.new()
	guide_countdown_label.name = "GuidanceCountdown"
	guide_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	guide_countdown_label.z_index = 35
	guide_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	guide_countdown_label.position = Vector2(popup_size.x - 58, 8)
	guide_countdown_label.size = Vector2(46, 18)
	guide_countdown_label.add_theme_font_size_override("font_size", 12)
	guide_countdown_label.add_theme_color_override("font_color", Color(0.90, 0.97, 1.0, 0.86))
	guide_popup_root.add_child(guide_countdown_label)
	update_guidance_countdown()


func update_guidance_countdown() -> void:
	if guide_countdown_label == null or not is_instance_valid(guide_countdown_label):
		return
	var remaining = max(guide_hold_duration - guide_hold_elapsed, 0.0)
	guide_countdown_label.text = "%0.1f" % remaining


func dispatch_guidance_complete(completed_packet: Dictionary) -> void:
	var complete_callable = completed_packet.get("on_complete_callable", null)
	if complete_callable is Callable and complete_callable.is_valid():
		complete_callable.call(completed_packet.get("on_complete_context", {}))


func remove_guidance_popup(clear_lock: bool = false) -> void:
	if guide_popup_root != null and is_instance_valid(guide_popup_root):
		guide_popup_root.queue_free()
	guide_popup_root = null
	guide_countdown_label = null
	if clear_lock:
		Globals.set_popup_input_lock("tutorial_popup", false)


func clamp_popup_position(pos: Vector2, popup_size: Vector2) -> Vector2:
	var screen_size := size
	if screen_size == Vector2.ZERO:
		screen_size = Vector2(Globals.screen_w, Globals.screen_h)
	var margin := 10.0
	return Vector2(
		clamp(pos.x, margin, max(screen_size.x - popup_size.x - margin, margin)),
		clamp(pos.y, margin, max(screen_size.y - popup_size.y - margin, margin))
	)


func get_packet_vector2(packet: Dictionary, key: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var value = packet.get(key, fallback)
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


func get_packet_color(packet: Dictionary, key: String, fallback: Color) -> Color:
	var value = packet.get(key, fallback)
	if typeof(value) == TYPE_COLOR:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return Color(
			float(value.get("r", fallback.r)),
			float(value.get("g", fallback.g)),
			float(value.get("b", fallback.b)),
			float(value.get("a", fallback.a))
		)
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		var alpha := fallback.a
		if value.size() >= 4:
			alpha = float(value[3])
		return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
	return fallback


func _load_path(file_path: String) -> void:
	points.clear()
	segment_lengths.clear()
	total_length = 0.0

	if not FileAccess.file_exists(file_path):
		push_warning("BattlePathTrail missing path file: " + file_path)
		return

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("BattlePathTrail could not open path file: " + file_path)
		return

	var text := file.get_as_text()
	var data = JSON.parse_string(text)

	if typeof(data) != TYPE_DICTIONARY:
		push_warning("BattlePathTrail invalid JSON shape: " + file_path)
		return

	path_id = str(data.get("path_id", "unnamed_path"))

	var file_duration := float(data.get("duration", 0.7))
	path_duration = file_duration

	if duration_override > 0.0:
		path_duration = duration_override

	var point_data: Array = data.get("points", [])

	for p in point_data:
		if typeof(p) != TYPE_DICTIONARY:
			continue

		var x := float(p.get("x", 0.0))
		var y := float(p.get("y", 0.0))
		points.append(Vector2(x, y))

	_calculate_lengths()

	if points.size() >= 1:
		head_pos = points[0]


func _calculate_lengths() -> void:
	segment_lengths.clear()
	total_length = 0.0

	if points.size() < 2:
		return

	var segment_count := points.size() - 1

	if loop_path:
		segment_count = points.size()

	for i in range(segment_count):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var length := a.distance_to(b)

		segment_lengths.append(length)
		total_length += length


func _get_position_at_distance(distance: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO

	if points.size() == 1:
		return points[0]

	var remaining := distance

	for i in range(segment_lengths.size()):
		var seg_len := segment_lengths[i]

		if remaining <= seg_len:
			var a := points[i]
			var b := points[(i + 1) % points.size()]
			var t = remaining / max(seg_len, 0.001)
			return a.lerp(b, t)

		remaining -= seg_len

	return points[points.size() - 1]


func _spawn_trail(delta: float) -> void:
	spawn_timer += delta

	while spawn_timer >= spawn_interval:
		spawn_timer -= spawn_interval

		trail_dots.append({
			"pos": head_pos,
			"age": 0.0,
			"life": trail_life,
			"size": randf_range(trail_size_min, trail_size_max)
		})


func _update_trail(delta: float) -> void:
	for i in range(trail_dots.size() - 1, -1, -1):
		var dot := trail_dots[i]
		dot["age"] = float(dot.get("age", 0.0)) + delta
		trail_dots[i] = dot

		if float(dot.get("age", 0.0)) >= float(dot.get("life", trail_life)):
			trail_dots.remove_at(i)


func _draw_debug_path_lines() -> void:
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], Color(0.5, 0.8, 1.0, 0.28), 1.0)

	if loop_path and points.size() > 2:
		draw_line(points[points.size() - 1], points[0], Color(0.5, 0.8, 1.0, 0.28), 1.0)
