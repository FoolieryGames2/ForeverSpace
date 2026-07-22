extends Control
class_name PortWindowWidget


const HORIZONTAL_FOV_DEGREES := 72.0
const VERTICAL_FOV_DEGREES := 44.0
const SCAN_REFRESH_INTERVAL := 0.18
const CachedStarLayerBaker = preload("res://UI/PortView/cached_star_layer_baker.gd")
const MainViewCachedStarLayerShader = preload("res://UI/PortView/main_view/main_view_cached_star_layer.gdshader")

const PANEL_COLOR := Color(0.05, 0.05, 0.08, 0.95)
const PORT_FILL_COLOR := Color(0.005, 0.012, 0.020, 1.0)
const PORT_EDGE_COLOR := Color(0.24, 0.74, 0.96, 0.42)
const PORT_INNER_EDGE_COLOR := Color(0.12, 0.28, 0.38, 0.55)
const GRID_COLOR := Color(0.20, 0.55, 0.70, 0.18)
const GLASS_GLOW_COLOR := Color(0.30, 0.85, 1.0, 0.07)
const MOTION_DUST_SPEED_THRESHOLD := 1.0
const MOTION_DUST_WARP_FULL_SPEED := 220.0
const MOTION_DUST_IMPULSE_FULL_SPEED := 45.0
const MOTION_DUST_FADE_IN_RATE := 3.2
const MOTION_DUST_FADE_OUT_RATE := 4.2
const MOTION_DUST_STREAK_COUNT := 14
const CACHED_STAR_EDGE_SOFTNESS := 3.0
const FULL_YAW_DEGREES := 360.0

const MARKER_COLORS := {
	"star": Color(1.0, 1.0, 0.70, 1.0),
	"object": Color(1.0, 0.80, 0.25, 1.0),
	"beacon": Color(0.90, 0.55, 1.0, 1.0),
	"planet": Color(0.083, 0.438, 0.291, 1.0),
	"enemy": Color(1.0, 0.22, 0.20, 1.0),
	"npc": Color(0.25, 1.0, 0.45, 1.0)
}

var map_ref: Map = null
var engine_ref: Impulse_Engine = null
var widget_state: WidgetsState5 = null
var latest_scan_packet: Dictionary = {}
var refresh_timer := 0.0
var runtime_seconds := 0.0
var motion_dust_amount := 0.0
var drag_active := false
var backdrop_mode := false

var port_center := Vector2.ZERO
var port_radius := 68.0
var star_layers: Array = []
var cached_star_layer_root: Control = null
var cached_star_layer_nodes: Array[ColorRect] = []
var motion_dust_streaks: Array = []
var active_mining_visual: Dictionary = {}

var background_rect: ColorRect = null
var title_label: Label = null
var status_label: Label = null
var mode_label: Label = null


func setup(
	new_map: Map,
	widget_size: Vector2 = Vector2(300, 160),
	new_state: WidgetsState5 = null,
	new_backdrop_mode: bool = false,
	new_engine: Impulse_Engine = null
) -> void:
	map_ref = new_map
	engine_ref = new_engine
	widget_state = new_state
	backdrop_mode = new_backdrop_mode
	size = widget_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE if backdrop_mode else Control.MOUSE_FILTER_STOP
	set_process(true)

	if backdrop_mode:
		port_radius = max(size.x, size.y) * 0.62
		port_center = size * 0.5
	else:
		port_radius = min(size.y * 0.43, 70.0)
		port_center = size * 0.5

	build_background_rect()
	build_cached_star_layer_root()
	build_labels()
	generate_star_layers()
	rebuild_cached_star_layers()
	generate_motion_dust_streaks()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if backdrop_mode:
		return
	if not Globals.port_window_drag_enabled:
		return
	if manual_drag_locked():
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		drag_active = mouse_event.pressed
		if drag_active:
			update_drag_status_label()
		else:
			update_status_label_from_latest_packet()
		accept_event()
		return

	if event is InputEventMouseMotion and drag_active:
		var motion_event := event as InputEventMouseMotion
		apply_drag_delta(motion_event.relative)
		accept_event()


func manual_drag_locked() -> bool:
	if Globals.battle_mode or Globals.battle_pending:
		return true
	if widget_state == null:
		return false
	if widget_state.use_auto_pilot:
		return true
	if widget_state.auto_pilot != null and widget_state.auto_pilot.enabled:
		return true
	return false


func apply_drag_delta(delta: Vector2) -> void:
	if map_ref == null:
		return

	var sensitivity := float(Globals.port_window_drag_sensitivity)
	map_ref.yaw = normalize_yaw_to_drag_bounds(float(map_ref.yaw) + (delta.x * sensitivity))
	map_ref.pitch = clamp(
		float(map_ref.pitch) - (delta.y * sensitivity),
		float(Globals.port_window_drag_pitch_min),
		float(Globals.port_window_drag_pitch_max)
	)

	update_drive_widget_orientation()
	update_drag_status_label()
	queue_redraw()


func normalize_yaw_to_drag_bounds(value: float) -> float:
	var min_yaw := float(Globals.port_window_drag_yaw_min)
	var max_yaw := float(Globals.port_window_drag_yaw_max)
	var span := max_yaw - min_yaw

	if span >= 360.0:
		return min_yaw + fposmod(value - min_yaw, span)

	return clamp(value, min_yaw, max_yaw)


func update_drive_widget_orientation() -> void:
	if widget_state == null or map_ref == null:
		return

	if widget_state.drive_value_labels.has("yaw"):
		widget_state.drive_value_labels["yaw"].text = "Yaw : " + str(int(round(map_ref.yaw)))
	if widget_state.drive_value_labels.has("pitch"):
		widget_state.drive_value_labels["pitch"].text = "Pit : " + str(int(round(map_ref.pitch)))

	if widget_state.sliders.has("yaw_slider"):
		widget_state.sliders["yaw_slider"].set_value_no_signal(map_ref.yaw)
	if widget_state.sliders.has("pitch_slider"):
		widget_state.sliders["pitch_slider"].set_value_no_signal(map_ref.pitch)


func update_drag_status_label() -> void:
	if mode_label == null or map_ref == null:
		return

	mode_label.text = "Yaw " + str(int(round(map_ref.yaw))) + " / Pitch " + str(int(round(map_ref.pitch)))


func build_background_rect() -> void:
	if background_rect == null:
		background_rect = ColorRect.new()
		background_rect.name = "PortWindowBackground"
		background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background_rect.show_behind_parent = true
		background_rect.z_index = -10
		add_child(background_rect)

	background_rect.position = Vector2.ZERO
	background_rect.size = size
	background_rect.color = Color(0.0, 0.0, 0.0, 1.0) if backdrop_mode else PANEL_COLOR

	if widget_state != null and not backdrop_mode:
		widget_state.color_rects["port_window_bg"] = background_rect


func build_cached_star_layer_root() -> void:
	if cached_star_layer_root == null:
		cached_star_layer_root = Control.new()
		cached_star_layer_root.name = "PortWindowCachedStarLayerRoot"
		cached_star_layer_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cached_star_layer_root.z_index = 0
		add_child(cached_star_layer_root)

	cached_star_layer_root.position = Vector2.ZERO
	cached_star_layer_root.size = size
	cached_star_layer_root.visible = true


func build_labels() -> void:
	if backdrop_mode:
		return

	var title := Label.new()
	title.name = "PortWindowTitle"
	title.text = "OBSERVATION PORT"
	title.position = Vector2(8, 5)
	title.size = Vector2(max(size.x - 16.0, 80.0), 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.62, 0.92, 1.0, 0.88))
	add_child(title)

	var hint := Label.new()
	hint.name = "PortWindowHint"
	hint.text = "Hold down to steer survey"
	hint.position = Vector2(8, max(size.y - 20.0, 0.0))
	hint.size = Vector2(max(size.x - 16.0, 80.0), 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.70, 0.86, 0.94, 0.78))
	add_child(hint)


func generate_star_layers() -> void:
	star_layers.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = 42137

	if backdrop_mode:
		star_layers.append(make_star_layer(rng, 150, 1.0, 0.28, Color(0.45, 0.74, 1.0, 0.46), 1.0))
		star_layers.append(make_star_layer(rng, 105, 2.0, 0.62, Color(0.82, 0.94, 1.0, 0.66), 1.45))
		star_layers.append(make_star_layer(rng, 58, 3.0, 1.10, Color(1.0, 1.0, 0.86, 0.82), 2.0))
	else:
		star_layers.append(make_star_layer(rng, 36, 1.0, 0.38, Color(0.55, 0.80, 1.0, 0.55), 0.9))
		star_layers.append(make_star_layer(rng, 28, 2.0, 0.80, Color(0.85, 0.95, 1.0, 0.72), 1.2))
		star_layers.append(make_star_layer(rng, 18, 3.0, 1.45, Color(1.0, 1.0, 0.86, 0.84), 1.7))


func make_star_layer(
	rng: RandomNumberGenerator,
	count: int,
	yaw_loop_count: float,
	pitch_pan_speed: float,
	color: Color,
	dot_size: float
) -> Dictionary:
	var stars := []
	var span := port_radius * 2.0 + 96.0

	for i in range(count):
		stars.append({
			"base": Vector2(rng.randf_range(0.0, span), rng.randf_range(0.0, span)),
			"twinkle": rng.randf_range(0.0, TAU),
			"size": rng.randf_range(dot_size * 0.65, dot_size * 1.35)
		})

	return {
		"stars": stars,
		"span": span,
		"yaw_loop_count": yaw_loop_count,
		"pitch_pan_speed": pitch_pan_speed,
		"color": color
	}


func rebuild_cached_star_layers() -> void:
	build_cached_star_layer_root()
	for i in range(star_layers.size()):
		var layer: Dictionary = star_layers[i]
		var texture := CachedStarLayerBaker.bake_star_layer_texture(layer)
		var node := get_or_create_cached_star_layer_node(i)
		var material := get_or_create_cached_star_layer_material(node)

		node.position = Vector2.ZERO
		node.size = size
		node.color = Color.WHITE
		node.visible = true

		material.set_shader_parameter("star_texture", texture)
		material.set_shader_parameter("texture_size_px", Vector2(texture.get_width(), texture.get_height()))
		material.set_shader_parameter("alpha_scale", 1.0)
		update_cached_star_layer_material(i)

	hide_cached_star_layer_nodes_from_index(star_layers.size())


func get_or_create_cached_star_layer_node(layer_index: int) -> ColorRect:
	while cached_star_layer_nodes.size() <= layer_index:
		var node := ColorRect.new()
		node.name = "PortWindowCachedStarLayer_" + str(cached_star_layer_nodes.size())
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.z_index = 0
		cached_star_layer_root.add_child(node)
		cached_star_layer_nodes.append(node)

	return cached_star_layer_nodes[layer_index]


func get_or_create_cached_star_layer_material(node: ColorRect) -> ShaderMaterial:
	var material := node.material as ShaderMaterial
	if material == null or material.shader != MainViewCachedStarLayerShader:
		material = ShaderMaterial.new()
		material.shader = MainViewCachedStarLayerShader
		node.material = material
	return material


func hide_cached_star_layer_nodes_from_index(start_index: int) -> void:
	for i in range(start_index, cached_star_layer_nodes.size()):
		cached_star_layer_nodes[i].visible = false


func update_cached_star_layer_materials() -> void:
	if cached_star_layer_root == null:
		return

	cached_star_layer_root.position = Vector2.ZERO
	cached_star_layer_root.size = size

	for i in range(min(star_layers.size(), cached_star_layer_nodes.size())):
		update_cached_star_layer_material(i)


func update_cached_star_layer_material(layer_index: int) -> void:
	if layer_index < 0 or layer_index >= star_layers.size() or layer_index >= cached_star_layer_nodes.size():
		return

	var node := cached_star_layer_nodes[layer_index]
	if node == null or not is_instance_valid(node):
		return

	node.position = Vector2.ZERO
	node.size = size

	var material := node.material as ShaderMaterial
	if material == null:
		return

	var yaw := 0.0
	var pitch := 0.0
	if map_ref != null:
		yaw = float(map_ref.yaw)
		pitch = float(map_ref.pitch)

	var layer: Dictionary = star_layers[layer_index]
	var span := float(layer.get("span", port_radius * 2.0 + 96.0))
	var yaw_loop_count := float(layer.get("yaw_loop_count", 1.0))
	var pitch_pan_speed := float(layer.get("pitch_pan_speed", 1.0))
	var offset := Vector2(
		get_looped_yaw_star_offset(yaw, span, yaw_loop_count),
		pitch * pitch_pan_speed
	)

	material.set_shader_parameter("rect_size_px", size)
	material.set_shader_parameter("port_center_px", port_center)
	material.set_shader_parameter("port_radius_px", port_radius)
	material.set_shader_parameter("edge_softness_px", CACHED_STAR_EDGE_SOFTNESS)
	material.set_shader_parameter("view_offset_px", offset)


func generate_motion_dust_streaks() -> void:
	motion_dust_streaks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 91841

	for i in range(MOTION_DUST_STREAK_COUNT):
		motion_dust_streaks.append({
			"angle": rng.randf_range(0.0, TAU),
			"seed": rng.randf_range(0.0, 1.0),
			"speed": rng.randf_range(0.65, 1.35),
			"width": rng.randf_range(0.75, 1.8),
			"blue": rng.randf_range(0.0, 1.0)
		})


func _process(delta: float) -> void:
	runtime_seconds += delta
	refresh_timer += delta
	update_motion_dust_amount(delta)

	if refresh_timer >= SCAN_REFRESH_INTERVAL:
		refresh_timer = 0.0
		refresh_scan_packet()

	update_cached_star_layer_materials()
	queue_redraw()


func refresh_scan_packet() -> void:
	if map_ref == null:
		return
	if not map_ref.has_method("build_live_map_scan_packet"):
		return

	latest_scan_packet = map_ref.build_live_map_scan_packet()


func _draw() -> void:
	draw_port_shell()
	draw_motion_space_dust()
	draw_mining_visual_queue()
	draw_forward_contact_markers()


func draw_port_shell() -> void:
	draw_circle(port_center, port_radius + 7.0, Color(0.0, 0.0, 0.0, 0.38))
	draw_circle(port_center, port_radius, PORT_FILL_COLOR)
	draw_circle(port_center + Vector2(-port_radius * 0.22, -port_radius * 0.28), port_radius * 0.72, GLASS_GLOW_COLOR)
	draw_arc(port_center, port_radius, 0.0, TAU, 96, PORT_EDGE_COLOR, 2.0, true)
	draw_arc(port_center, port_radius * 0.72, 0.0, TAU, 96, PORT_INNER_EDGE_COLOR, 1.0, true)
	draw_arc(port_center, port_radius * 0.42, 0.0, TAU, 96, GRID_COLOR, 1.0, true)
	draw_line(port_center + Vector2(-port_radius * 0.82, 0.0), port_center + Vector2(port_radius * 0.82, 0.0), GRID_COLOR, 1.0)
	draw_line(port_center + Vector2(0.0, -port_radius * 0.82), port_center + Vector2(0.0, port_radius * 0.82), GRID_COLOR, 1.0)


func draw_panning_star_layers() -> void:
	var yaw := 0.0
	var pitch := 0.0
	if map_ref != null:
		yaw = float(map_ref.yaw)
		pitch = float(map_ref.pitch)

	for layer in star_layers:
		var span := float(layer.get("span", port_radius * 2.0 + 96.0))
		var yaw_loop_count := float(layer.get("yaw_loop_count", 1.0))
		var pitch_pan_speed := float(layer.get("pitch_pan_speed", 1.0))
		var color: Color = layer.get("color", Color.WHITE)
		var origin := port_center - Vector2(span * 0.5, span * 0.5)
		var offset := Vector2(
			get_looped_yaw_star_offset(yaw, span, yaw_loop_count),
			pitch * pitch_pan_speed
		)

		for star in layer.get("stars", []):
			var base: Vector2 = star.get("base", Vector2.ZERO)
			var wrapped := Vector2(
				fposmod(base.x + offset.x, span),
				fposmod(base.y + offset.y, span)
			)
			var pos := origin + wrapped
			if pos.distance_to(port_center) > port_radius - 2.0:
				continue

			var twinkle := 0.78 + (sin(runtime_seconds * 1.6 + float(star.get("twinkle", 0.0))) * 0.22)
			var star_color := color
			star_color.a *= twinkle
			draw_circle(pos, float(star.get("size", 1.0)), star_color)


func update_motion_dust_amount(delta: float) -> void:
	var target := get_forward_motion_amount()
	var fade_rate := MOTION_DUST_FADE_IN_RATE if target > motion_dust_amount else MOTION_DUST_FADE_OUT_RATE
	motion_dust_amount = move_toward(motion_dust_amount, target, delta * fade_rate)


func get_forward_motion_amount() -> float:
	if engine_ref == null:
		return 0.0
	if Globals.battle_mode or Globals.battle_pending:
		return 0.0

	var speed = max(float(engine_ref.speed), 0.0)
	if speed <= MOTION_DUST_SPEED_THRESHOLD:
		return 0.0

	var max_speed := MOTION_DUST_WARP_FULL_SPEED
	if str(engine_ref.mode).strip_edges().to_lower() == "impulse":
		max_speed = MOTION_DUST_IMPULSE_FULL_SPEED
	max_speed = max(max_speed, MOTION_DUST_SPEED_THRESHOLD + 1.0)
	return clamp(speed / max_speed, 0.0, 1.0)


func draw_motion_space_dust() -> void:
	if motion_dust_amount <= 0.08:
		return

	var amount := smoothstep(0.08, 1.0, motion_dust_amount)
	var travel_speed = lerp(0.42, 2.35, amount)
	var streak_length = port_radius * lerp(0.05, 0.18, amount)
	var alpha_scale = lerp(0.0, 0.30, amount)

	for streak in motion_dust_streaks:
		var angle := float(streak.get("angle", 0.0))
		var dir := Vector2(cos(angle), sin(angle))
		var seed := float(streak.get("seed", 0.0))
		var speed_scale := float(streak.get("speed", 1.0))
		var progress := fposmod(seed + runtime_seconds * travel_speed * speed_scale, 1.0)
		if progress < 0.18:
			continue

		var eased := smoothstep(0.0, 1.0, progress)
		var radius = lerp(port_radius * 0.16, port_radius - 4.0, eased)
		var pos = port_center + dir * radius
		if pos.distance_to(port_center) > port_radius - 2.0:
			continue

		var fade := smoothstep(0.18, 0.42, progress) * (1.0 - smoothstep(0.82, 1.0, progress))
		var tail = dir * streak_length * (0.45 + progress * 0.85)
		var color := Color(0.58, 0.80, 1.0, alpha_scale * fade)
		color = color.lerp(Color(0.92, 0.98, 1.0, color.a), float(streak.get("blue", 0.0)) * 0.55)
		draw_line(pos - tail, pos, color, float(streak.get("width", 1.0)), true)


func draw_forward_contact_markers() -> void:
	var markers = latest_scan_packet.get("markers", [])
	if map_ref == null or typeof(markers) != TYPE_ARRAY:
		update_status_label(0, 0)
		return

	var drawn_count := 0
	var total_count := 0
	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		total_count += 1

		var projected := project_marker_to_port(marker)
		if projected.is_empty():
			continue

		draw_contact_marker(marker, projected)
		drawn_count += 1

	update_status_label(drawn_count, total_count)


func update_status_label_from_latest_packet() -> void:
	if map_ref == null:
		update_status_label(0, 0)
		return

	var markers = latest_scan_packet.get("markers", [])
	if typeof(markers) != TYPE_ARRAY:
		update_status_label(0, 0)
		return

	var drawn_count := 0
	var total_count := 0
	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		total_count += 1
		if not project_marker_to_port(marker).is_empty():
			drawn_count += 1

	update_status_label(drawn_count, total_count)


func project_marker_to_port(marker: Dictionary) -> Dictionary:
	var target_sector := read_vector3i(marker.get("sector_pos", marker.get("sector", Vector3i.ZERO)))
	var target_local := read_vector3(marker.get("local_pos", marker.get("local", Vector3.ZERO)))
	var aim: Dictionary = map_ref.get_target_yaw_pitch(target_sector, target_local)

	var yaw_delta := wrap_angle(float(aim.get("yaw", 0.0)) - float(map_ref.yaw))
	var pitch_delta := wrap_angle(float(aim.get("pitch", 0.0)) - float(map_ref.pitch))
	var half_h := HORIZONTAL_FOV_DEGREES * 0.5
	var half_v := VERTICAL_FOV_DEGREES * 0.5

	if abs(yaw_delta) > half_h or abs(pitch_delta) > half_v:
		return {}

	var pos := port_center + Vector2(
		(yaw_delta / half_h) * port_radius * 0.82,
		(-pitch_delta / half_v) * port_radius * 0.82
	)

	if pos.distance_to(port_center) > port_radius * 0.92:
		return {}

	return {
		"pos": pos,
		"yaw_delta": yaw_delta,
		"pitch_delta": pitch_delta
	}


func draw_contact_marker(marker: Dictionary, projected: Dictionary) -> void:
	var marker_type := str(marker.get("type", "object"))
	var pos: Vector2 = projected.get("pos", port_center)
	var color: Color = MARKER_COLORS.get(marker_type, MARKER_COLORS["object"])
	var distance := float(marker.get("distance", 0.0))
	var scan_range := float(latest_scan_packet.get("range", 500.0))
	var range_alpha = clamp(1.0 - (distance / max(scan_range, 1.0)) * 0.45, 0.45, 1.0)
	color.a *= range_alpha

	var marker_radius := get_marker_radius(marker_type)
	draw_circle(pos, marker_radius, color)
	draw_arc(pos, marker_radius + 3.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.42), 1.0, true)

	if marker_type == "enemy":
		draw_line(pos + Vector2(-5, 0), pos + Vector2(5, 0), Color(1.0, 0.25, 0.25, 0.65), 1.0)
		draw_line(pos + Vector2(0, -5), pos + Vector2(0, 5), Color(1.0, 0.25, 0.25, 0.65), 1.0)


func get_marker_radius(marker_type: String) -> float:
	match marker_type:
		"enemy":
			return 4.4
		"beacon":
			return 4.0
		"npc":
			return 3.8
		"object":
			return 3.4
		"star":
			return 2.7
		"planet":
			return 10.0
		_:
			return 3.2



func queue_mining_visual(packet: Dictionary) -> void:
	# Summary: Visual-only mining cue. Backend mining still completes through task_manager/action_manager.
	if packet.is_empty():
		return

	active_mining_visual = packet.duplicate(true)
	active_mining_visual["started_at"] = runtime_seconds
	active_mining_visual["duration"] = max(float(active_mining_visual.get("duration", 1.0)), 0.1)
	active_mining_visual["finished_hold"] = max(float(active_mining_visual.get("finished_hold", 0.18)), 0.0)

	if latest_scan_packet.is_empty():
		refresh_scan_packet()

	queue_redraw()


func draw_mining_visual_queue() -> void:
	if active_mining_visual.is_empty():
		return
	if map_ref == null:
		active_mining_visual.clear()
		return

	var duration = max(float(active_mining_visual.get("duration", 1.0)), 0.1)
	var elapsed := runtime_seconds - float(active_mining_visual.get("started_at", runtime_seconds))
	var finished_hold = max(float(active_mining_visual.get("finished_hold", 0.18)), 0.0)
	if elapsed > duration + finished_hold:
		active_mining_visual.clear()
		return

	var projected := project_mining_visual_to_port(active_mining_visual)
	if projected.is_empty():
		return

	var progress = clamp(elapsed / duration, 0.0, 1.0)
	var pos: Vector2 = projected.get("pos", port_center)
	var out_dir := pos - port_center
	if out_dir.length() < 0.01:
		out_dir = Vector2(1.0, -0.35)
	out_dir = out_dir.normalized()

	var pulse := 0.5 + 0.5 * sin(runtime_seconds * 12.0)
	var ring_alpha = (1.0 - progress * 0.45) * (0.36 + pulse * 0.24)
	var ring_radius = lerp(14.0, 24.0, progress) + pulse * 4.0
	var mining_color := Color(1.0, 0.76, 0.24, ring_alpha)

	# Target lock / pulse around the asteroid.
	draw_arc(pos, ring_radius, 0.0, TAU, 40, mining_color, 2.0, true)
	draw_arc(pos, ring_radius + 5.0, 0.0, TAU, 40, Color(1.0, 0.92, 0.48, ring_alpha * 0.45), 1.0, true)

	# Non-clickable material packet popping out from behind the asteroid.
	var pop_offset = lerp(-7.0, 34.0, smoothstep(0.0, 1.0, progress))
	var packet_pos = pos + out_dir * pop_offset + Vector2(0.0, -sin(progress * PI) * 10.0)
	var packet_alpha = 1.0 - smoothstep(0.78, 1.0, progress)
	packet_alpha = max(packet_alpha, 0.14 if elapsed <= duration else 0.0)
	var packet_radius = lerp(3.0, 7.0, min(progress * 2.0, 1.0)) * (1.0 + pulse * 0.14)

	draw_line(pos, packet_pos, Color(1.0, 0.80, 0.30, 0.20 * packet_alpha), 1.2, true)
	draw_circle(packet_pos, packet_radius + 3.0, Color(1.0, 0.58, 0.18, 0.18 * packet_alpha))
	draw_circle(packet_pos, packet_radius, Color(1.0, 0.86, 0.35, 0.86 * packet_alpha))
	draw_arc(packet_pos, packet_radius + 5.0, 0.0, TAU, 24, Color(1.0, 0.96, 0.60, 0.48 * packet_alpha), 1.0, true)


func project_mining_visual_to_port(packet: Dictionary) -> Dictionary:
	var marker := find_mining_visual_marker(packet)
	if marker.is_empty():
		marker = {
			"type": "object",
			"sector_pos": packet.get("sector_pos", packet.get("sector", Vector3i.ZERO)),
			"local_pos": packet.get("local_pos", packet.get("local", Vector3.ZERO)),
			"object_id": packet.get("object_id", packet.get("target_object_id", ""))
		}

	return project_marker_to_port(marker)


func find_mining_visual_marker(packet: Dictionary) -> Dictionary:
	var markers = latest_scan_packet.get("markers", [])
	if typeof(markers) != TYPE_ARRAY:
		return {}

	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		if marker_matches_mining_visual_packet(marker, packet):
			return marker

	return {}


func marker_matches_mining_visual_packet(marker: Dictionary, packet: Dictionary) -> bool:
	var packet_id := str(packet.get("target_object_id", packet.get("object_id", ""))).strip_edges()
	if packet_id != "":
		var marker_ids := [
			str(marker.get("object_id", "")).strip_edges(),
			str(marker.get("id", "")).strip_edges(),
			str(marker.get("source_world_seed_object_id", "")).strip_edges(),
			str(marker.get("catalog_id", "")).strip_edges()
		]

		var data_slice = marker.get("data_slice", {})
		if typeof(data_slice) == TYPE_DICTIONARY:
			marker_ids.append(str(data_slice.get("object_id", "")).strip_edges())
			marker_ids.append(str(data_slice.get("id", "")).strip_edges())

		for marker_id in marker_ids:
			if marker_id != "" and marker_id == packet_id:
				return true

	var marker_sector := read_vector3i(marker.get("sector_pos", marker.get("sector", Vector3i.ZERO)))
	var marker_local := read_vector3(marker.get("local_pos", marker.get("local", Vector3.ZERO)))
	var packet_sector := read_vector3i(packet.get("sector_pos", packet.get("sector", Vector3i.ZERO)))
	var packet_local := read_vector3(packet.get("local_pos", packet.get("local", Vector3.ZERO)))

	return marker_sector == packet_sector and marker_local.distance_to(packet_local) <= 0.1


func update_status_label(ahead_count: int, total_count: int) -> void:
	if status_label != null:
		status_label.text = "Ahead: " + str(ahead_count) + " / " + str(total_count)


func wrap_angle(angle: float) -> float:
	while angle > 180.0:
		angle -= 360.0
	while angle < -180.0:
		angle += 360.0
	return angle


func read_vector3(value) -> Vector3:
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


func read_vector3i(value) -> Vector3i:
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


func get_looped_yaw_star_offset(yaw: float, span: float, yaw_loop_count: float) -> float:
	var yaw_ratio := fposmod(yaw, FULL_YAW_DEGREES) / FULL_YAW_DEGREES
	return -yaw_ratio * span * yaw_loop_count
