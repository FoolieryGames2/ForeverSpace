extends Control
class_name BattleUIPathPainter

const BattleUIPathStorageScript = preload("res://Scripts/dev/BattleUIPathStorage.gd")

const SCREEN_SIZE := Vector2(1300, 800)
const TOOLBAR_HEIGHT := 78.0
const CAPTURE_STEP_PIXELS := 6.0
const SIMPLIFY_EPSILON := 5.0
const DEFAULT_DURATION := 0.65

const GUIDE_POINTS := {
	"player_panel": {"position": Vector2(40, 95), "size": Vector2(370, 185), "label": "PLAYER PANEL"},
	"enemy_panel": {"position": Vector2(890, 95), "size": Vector2(370, 185), "label": "ENEMY PANEL"},
	"shield_panel": {"position": Vector2(40, 300), "size": Vector2(210, 275), "label": "SHIELD PANEL"},
	"action_panel": {"position": Vector2(280, 300), "size": Vector2(590, 275), "label": "ACTION AREA"},
	"todo_panel": {"position": Vector2(280, 600), "size": Vector2(590, 140), "label": "TODO AREA"},
	"battle_log": {"position": Vector2(900, 300), "size": Vector2(360, 440), "label": "BATTLE LOG"},
	"action_button_stack": {"position": Vector2(292, 388), "size": Vector2(566, 175), "label": "ACTION BUTTON STACK"},
	"todo_next_row": {"position": Vector2(292, 645), "size": Vector2(566, 22), "label": "NEXT TODO"},
	"center_stage": {"position": Vector2(430, 105), "size": Vector2(430, 175), "label": "CENTER FX STAGE"}
}

var storage: BattleUIPathStorage
var path_name_edit: LineEdit
var status_label: Label
var load_options: OptionButton
var duration_spin: SpinBox
var ease_options: OptionButton
var loop_check: CheckBox
var points_label: Label

var strokes: Array = []
var current_stroke: Array = []
var drawing: bool = false
var last_capture_point := Vector2.ZERO

var test_playing: bool = false
var test_elapsed: float = 0.0
var test_duration: float = DEFAULT_DURATION
var test_points: Array = []


func _ready() -> void:
	name = "BattleUIPathPainter"
	size = SCREEN_SIZE
	custom_minimum_size = SCREEN_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	storage = BattleUIPathStorageScript.new()
	add_child(storage)
	build_toolbar()
	refresh_load_options()
	update_points_label()
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	if test_playing:
		test_elapsed += delta
		if test_elapsed >= test_duration:
			test_playing = false
			set_process(false)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.position.y < TOOLBAR_HEIGHT:
			return

		if mouse_event.pressed:
			start_stroke(mouse_event.position)
		else:
			finish_stroke()
		accept_event()

	if event is InputEventMouseMotion and drawing:
		var motion_event := event as InputEventMouseMotion
		add_stroke_point_if_needed(motion_event.position)
		accept_event()


func _draw() -> void:
	draw_background()
	draw_battle_v2_guides()
	draw_saved_strokes()
	draw_current_stroke()
	draw_test_playback()


func build_toolbar() -> void:
	var toolbar := ColorRect.new()
	toolbar.name = "PathPainterToolbar"
	toolbar.position = Vector2.ZERO
	toolbar.size = Vector2(SCREEN_SIZE.x, TOOLBAR_HEIGHT)
	toolbar.color = Color(0.025, 0.035, 0.055, 0.98)
	toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(toolbar)

	var x := 14.0
	var title := make_label("Title", "Battle V2 Path Painter", Vector2(x, 8), Vector2(210, 22), 16)
	title.add_theme_color_override("font_color", Color(0.70, 0.92, 1.0, 1.0))
	x += 220.0

	make_label("PathNameLabel", "Path Name", Vector2(x, 10), Vector2(76, 18), 12)
	x += 78.0
	path_name_edit = LineEdit.new()
	path_name_edit.name = "PathName"
	path_name_edit.text = "enemy_laser_arc_01"
	path_name_edit.position = Vector2(x, 7)
	path_name_edit.size = Vector2(225, 28)
	add_child(path_name_edit)
	x += 235.0

	add_button("Save", Vector2(x, 7), Vector2(58, 28), _on_save_pressed)
	x += 64.0
	add_button("New", Vector2(x, 7), Vector2(54, 28), _on_new_pressed)
	x += 60.0
	add_button("Clear", Vector2(x, 7), Vector2(58, 28), _on_clear_pressed)
	x += 64.0
	add_button("Undo", Vector2(x, 7), Vector2(58, 28), _on_undo_pressed)
	x += 64.0
	add_button("Smooth", Vector2(x, 7), Vector2(72, 28), _on_smooth_pressed)
	x += 78.0
	add_button("Simplify", Vector2(x, 7), Vector2(78, 28), _on_simplify_pressed)
	x += 84.0
	add_button("Test", Vector2(x, 7), Vector2(54, 28), _on_test_pressed)

	var x2 := 14.0
	make_label("DurationLabel", "Duration", Vector2(x2, 45), Vector2(70, 18), 12)
	x2 += 74.0
	duration_spin = SpinBox.new()
	duration_spin.name = "Duration"
	duration_spin.min_value = 0.05
	duration_spin.max_value = 8.0
	duration_spin.step = 0.05
	duration_spin.value = DEFAULT_DURATION
	duration_spin.position = Vector2(x2, 40)
	duration_spin.size = Vector2(92, 28)
	add_child(duration_spin)
	x2 += 104.0

	make_label("EaseLabel", "Ease", Vector2(x2, 45), Vector2(38, 18), 12)
	x2 += 42.0
	ease_options = OptionButton.new()
	ease_options.name = "Ease"
	ease_options.position = Vector2(x2, 40)
	ease_options.size = Vector2(118, 28)
	ease_options.add_item("smooth")
	ease_options.add_item("linear")
	ease_options.add_item("snap")
	add_child(ease_options)
	x2 += 128.0

	loop_check = CheckBox.new()
	loop_check.name = "Loop"
	loop_check.text = "Loop"
	loop_check.position = Vector2(x2, 40)
	loop_check.size = Vector2(70, 28)
	add_child(loop_check)
	x2 += 78.0

	load_options = OptionButton.new()
	load_options.name = "LoadOptions"
	load_options.position = Vector2(x2, 40)
	load_options.size = Vector2(210, 28)
	add_child(load_options)
	x2 += 218.0
	add_button("Load", Vector2(x2, 40), Vector2(60, 28), _on_load_pressed)

	status_label = make_label("StatusLabel", "Draw on the Battle V2 guide surface.", Vector2(745, 45), Vector2(300, 18), 12)
	points_label = make_label("PointsLabel", "Points: 0", Vector2(1060, 45), Vector2(110, 18), 12)


func make_label(label_name: String, text: String, pos: Vector2, label_size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.82, 0.90, 1.0, 0.95))
	add_child(label)
	return label


func add_button(button_text: String, pos: Vector2, button_size: Vector2, target_callable: Callable) -> Button:
	var button := Button.new()
	button.text = button_text
	button.position = pos
	button.size = button_size
	button.pressed.connect(target_callable)
	add_child(button)
	return button


func draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.018, 0.024, 0.040, 1.0), true)
	draw_rect(Rect2(Vector2(0, TOOLBAR_HEIGHT), Vector2(SCREEN_SIZE.x, SCREEN_SIZE.y - TOOLBAR_HEIGHT)), Color(0.025, 0.033, 0.058, 1.0), true)


func draw_battle_v2_guides() -> void:
	for point_id in GUIDE_POINTS.keys():
		var point: Dictionary = GUIDE_POINTS[point_id]
		draw_guide_panel(point_id, point)


func draw_guide_panel(point_id: String, point: Dictionary) -> void:
	var panel_pos: Vector2 = point.get("position", Vector2.ZERO)
	var panel_size: Vector2 = point.get("size", Vector2.ZERO)
	var rect := Rect2(panel_pos, panel_size)
	var shadow_rect := Rect2(panel_pos + Vector2(6, 7), panel_size)
	var is_nested := point_id in ["action_button_stack", "todo_next_row"]
	var fill := Color(0.050, 0.070, 0.110, 0.50)
	var outline := Color(0.26, 0.56, 0.86, 0.72)
	if is_nested:
		fill = Color(0.030, 0.050, 0.080, 0.28)
		outline = Color(0.45, 0.78, 1.0, 0.42)

	draw_rect(shadow_rect, Color(0.0, 0.0, 0.0, 0.35), true)
	draw_rect(rect, fill, true)
	draw_rect(rect, outline, false, 2.0)

	var font := ThemeDB.fallback_font
	var label_text := str(point.get("label", point_id))
	draw_string(font, panel_pos + Vector2(12, 22), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.72, 0.88, 1.0, 0.92))
	draw_string(font, panel_pos + Vector2(12, panel_size.y - 10), point_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.58, 0.72, 0.92, 0.72))


func draw_saved_strokes() -> void:
	for stroke in strokes:
		draw_path(stroke, Color(0.20, 0.76, 1.0, 0.92), Color(0.82, 0.96, 1.0, 0.95), 3.0)


func draw_current_stroke() -> void:
	if current_stroke.is_empty():
		return
	draw_path(current_stroke, Color(0.35, 1.0, 0.55, 0.95), Color(0.85, 1.0, 0.90, 0.98), 3.0)


func draw_path(points: Array, line_color: Color, dot_color: Color, width: float) -> void:
	if points.size() >= 2:
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], line_color, width, true)
	for point in points:
		draw_circle(point, 3.5, dot_color)


func draw_test_playback() -> void:
	if not test_playing or test_points.size() < 2:
		return
	var t = clamp(test_elapsed / max(test_duration, 0.05), 0.0, 1.0)
	var pos := get_position_along_path(test_points, t)
	draw_circle(pos, 11.0, Color(1.0, 0.55, 0.08, 0.35))
	draw_circle(pos, 5.5, Color(1.0, 0.85, 0.20, 1.0))


func start_stroke(pos: Vector2) -> void:
	drawing = true
	test_playing = false
	current_stroke = [pos]
	last_capture_point = pos
	status_label.text = "Drawing path..."
	queue_redraw()


func add_stroke_point_if_needed(pos: Vector2) -> void:
	if pos.distance_to(last_capture_point) < CAPTURE_STEP_PIXELS:
		return
	current_stroke.append(pos)
	last_capture_point = pos
	update_points_label()
	queue_redraw()


func finish_stroke() -> void:
	if not drawing:
		return
	drawing = false
	if current_stroke.size() >= 2:
		strokes.append(current_stroke.duplicate(true))
		status_label.text = "Stroke captured. Name it and save."
	else:
		status_label.text = "Stroke too short; ignored."
	current_stroke.clear()
	update_points_label()
	queue_redraw()


func _on_save_pressed() -> void:
	if get_flat_points().size() < 2:
		status_label.text = "Need at least two points before saving."
		return

	var packet := build_path_packet()
	var result := storage.save_path_packet(packet)
	if result.get("status", "") == "success":
		status_label.text = "Saved: " + str(result.get("file_path", ""))
	else:
		status_label.text = "Save failed: " + str(result.get("reason", ""))
	refresh_load_options()


func _on_new_pressed() -> void:
	strokes.clear()
	current_stroke.clear()
	test_playing = false
	path_name_edit.text = "battle_path_" + str(Time.get_ticks_msec())
	status_label.text = "New path ready."
	update_points_label()
	queue_redraw()


func _on_clear_pressed() -> void:
	strokes.clear()
	current_stroke.clear()
	test_playing = false
	status_label.text = "Path cleared."
	update_points_label()
	queue_redraw()


func _on_undo_pressed() -> void:
	if not strokes.is_empty():
		strokes.pop_back()
		status_label.text = "Undid last stroke."
	else:
		status_label.text = "Nothing to undo."
	update_points_label()
	queue_redraw()


func _on_smooth_pressed() -> void:
	for i in range(strokes.size()):
		strokes[i] = smooth_points(strokes[i])
	status_label.text = "Smoothed path points."
	queue_redraw()


func _on_simplify_pressed() -> void:
	for i in range(strokes.size()):
		strokes[i] = simplify_points(strokes[i], SIMPLIFY_EPSILON)
	status_label.text = "Simplified path points."
	update_points_label()
	queue_redraw()


func _on_test_pressed() -> void:
	test_points = get_flat_points()
	if test_points.size() < 2:
		status_label.text = "Need at least two points to test."
		return
	test_duration = float(duration_spin.value)
	test_elapsed = 0.0
	test_playing = true
	status_label.text = "Testing path playback."
	set_process(true)
	queue_redraw()


func _on_load_pressed() -> void:
	if load_options.item_count <= 0:
		status_label.text = "No saved paths to load."
		return
	var path_id := load_options.get_item_text(load_options.selected)
	var packet := storage.load_path_packet(path_id)
	if packet.is_empty():
		status_label.text = "Load failed: " + path_id
		return
	load_packet(packet)
	status_label.text = "Loaded: " + path_id


func refresh_load_options() -> void:
	if load_options == null:
		return
	load_options.clear()
	for path_id in storage.list_path_ids():
		load_options.add_item(str(path_id))
	if load_options.item_count > 0:
		load_options.select(0)


func build_path_packet() -> Dictionary:
	var path_id := storage.sanitize_path_id(path_name_edit.text)
	if path_id == "":
		path_id = "battle_path_" + str(Time.get_ticks_msec())
		path_name_edit.text = path_id

	var points_data: Array = []
	for point in get_flat_points():
		points_data.append({"x": point.x, "y": point.y})

	var ease_text := "smooth"
	if ease_options != null and ease_options.item_count > 0:
		ease_text = ease_options.get_item_text(ease_options.selected)

	return {
		"path_id": path_id,
		"screen_size": {"x": SCREEN_SIZE.x, "y": SCREEN_SIZE.y},
		"space": "battle_v2_ui",
		"duration": float(duration_spin.value),
		"ease": ease_text,
		"loop": loop_check.button_pressed,
		"tags": ["battle_fx", "dev_path"],
		"points": points_data
	}


func load_packet(packet: Dictionary) -> void:
	strokes.clear()
	current_stroke.clear()
	test_playing = false
	path_name_edit.text = str(packet.get("path_id", "loaded_path"))
	duration_spin.value = float(packet.get("duration", DEFAULT_DURATION))
	loop_check.button_pressed = bool(packet.get("loop", false))
	select_ease_option(str(packet.get("ease", "smooth")))

	var points: Array = []
	var packet_points = packet.get("points", [])
	if typeof(packet_points) == TYPE_ARRAY:
		for point_data in packet_points:
			if typeof(point_data) == TYPE_DICTIONARY:
				points.append(Vector2(float(point_data.get("x", 0.0)), float(point_data.get("y", 0.0))))
	if not points.is_empty():
		strokes.append(points)

	update_points_label()
	queue_redraw()


func select_ease_option(ease_name: String) -> void:
	if ease_options == null:
		return
	for i in range(ease_options.item_count):
		if ease_options.get_item_text(i) == ease_name:
			ease_options.select(i)
			return
	ease_options.select(0)


func get_flat_points() -> Array:
	var points: Array = []
	for stroke in strokes:
		if typeof(stroke) != TYPE_ARRAY:
			continue
		for point in stroke:
			points.append(point)
	if drawing:
		for point in current_stroke:
			points.append(point)
	return points


func update_points_label() -> void:
	if points_label == null:
		return
	points_label.text = "Points: " + str(get_flat_points().size())


func smooth_points(points: Array) -> Array:
	if points.size() < 3:
		return points.duplicate(true)
	var output: Array = [points[0]]
	for i in range(1, points.size() - 1):
		var smoothed: Vector2 = (points[i - 1] + points[i] * 2.0 + points[i + 1]) / 4.0
		output.append(smoothed)
	output.append(points[points.size() - 1])
	return output


func simplify_points(points: Array, epsilon: float) -> Array:
	if points.size() < 3:
		return points.duplicate(true)
	return ramer_douglas_peucker(points, epsilon)


func ramer_douglas_peucker(points: Array, epsilon: float) -> Array:
	if points.size() < 3:
		return points.duplicate(true)

	var first: Vector2 = points[0]
	var last: Vector2 = points[points.size() - 1]
	var max_distance := 0.0
	var index := 0

	for i in range(1, points.size() - 1):
		var distance := distance_to_segment(points[i], first, last)
		if distance > max_distance:
			index = i
			max_distance = distance

	if max_distance > epsilon:
		var left := ramer_douglas_peucker(points.slice(0, index + 1), epsilon)
		var right := ramer_douglas_peucker(points.slice(index, points.size()), epsilon)
		left.pop_back()
		left.append_array(right)
		return left

	return [first, last]


func distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_squared := ab.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(a)
	var t = clamp((point - a).dot(ab) / length_squared, 0.0, 1.0)
	var projection = a + ab * t
	return point.distance_to(projection)


func get_position_along_path(points: Array, t: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]

	var total_length := get_path_length(points)
	if total_length <= 0.0:
		return points[0]

	var target_distance = total_length * clamp(t, 0.0, 1.0)
	var traveled := 0.0
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var segment_length := a.distance_to(b)
		if traveled + segment_length >= target_distance:
			var local_t = (target_distance - traveled) / max(segment_length, 0.001)
			return a.lerp(b, local_t)
		traveled += segment_length

	return points[points.size() - 1]


func get_path_length(points: Array) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total
