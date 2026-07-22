extends Control
class_name BattleV2BackgroundDrawLayer

# ==========================================================
# BATTLE V2 BACKGROUND DRAW LAYER
# ----------------------------------------------------------
# Procedural, visual-only Battle UI backfield.
# Sits above Battle_V2_Background and below all widgets.
# It reads small header-state summaries and draws plasma/shield
# atmosphere. It never resolves combat or mutates gameplay state.
# ==========================================================

const DEFAULT_SCREEN_SIZE := Vector2(1300, 800)
const PLAYER_COLOR := Color(0.08, 0.55, 1.0, 1.0)
const ENEMY_COLOR := Color(1.0, 0.12, 0.08, 1.0)
const CENTER_COLOR := Color(0.72, 0.22, 1.0, 1.0)
const HULL_STRESS_COLOR := Color(1.0, 0.42, 0.12, 1.0)
const REDRAW_INTERVAL := 1.0 / 30.0
const REACTIVE_STATE_FIELDS := [
	"hp_current",
	"hp_max",
	"shield_current",
	"shield_max",
	"shield_power_level",
	"shield_max_count",
	"shield_has_energy",
	"shield_state"
]

var position_data: Dictionary = {}
var latest_header_state: Dictionary = {}
var anim_time: float = 0.0
var redraw_elapsed: float = 0.0
var player_field_phase: float = 0.0
var enemy_field_phase: float = 3.7


func _ready() -> void:
	name = "Battle_V2_Background_Draw_Layer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if size == Vector2.ZERO:
		size = get_target_screen_size()
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func setup(refs: Dictionary = {}) -> void:
	if typeof(refs.get("position_data", {})) == TYPE_DICTIONARY:
		position_data = refs.get("position_data", {}).duplicate(true)
	if refs.has("size"):
		size = refs.get("size", size)
	if size == Vector2.ZERO:
		size = get_target_screen_size()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(is_visible_in_tree())
	queue_redraw()


func set_position_data(new_position_data: Dictionary) -> void:
	if new_position_data == position_data:
		return
	position_data = new_position_data.duplicate(true)
	queue_redraw()


func set_header_state(packet: Dictionary) -> void:
	var reactive_state := extract_reactive_header_state(packet)
	if reactive_state == latest_header_state:
		return
	latest_header_state = reactive_state
	queue_redraw()


func _process(delta: float) -> void:
	anim_time = fmod(anim_time + min(delta, 0.1), 4096.0)
	redraw_elapsed += delta
	if redraw_elapsed < REDRAW_INTERVAL:
		return
	redraw_elapsed = fmod(redraw_elapsed, REDRAW_INTERVAL)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _on_visibility_changed() -> void:
	set_process(is_visible_in_tree())
	if is_visible_in_tree():
		queue_redraw()


func get_target_screen_size() -> Vector2:
	var viewport := get_viewport()
	if viewport != null:
		var viewport_size := viewport.get_visible_rect().size
		if viewport_size.x > 0.0 and viewport_size.y > 0.0:
			return viewport_size

	var globals_size := Vector2(float(Globals.screen_w), float(Globals.screen_h))
	if globals_size.x > 0.0 and globals_size.y > 0.0:
		return globals_size
	return DEFAULT_SCREEN_SIZE


func extract_reactive_header_state(packet: Dictionary) -> Dictionary:
	var state: Dictionary = {}
	for side in ["player", "enemy"]:
		for field in REACTIVE_STATE_FIELDS:
			var key: String = side + "_" + str(field)
			if packet.has(key):
				state[key] = packet[key]
	return state


func _draw() -> void:
	var screen_size := size
	if screen_size == Vector2.ZERO:
		screen_size = DEFAULT_SCREEN_SIZE

	draw_dark_field(screen_size)
	draw_soft_side_fields(screen_size)
	draw_background_grid(screen_size)
	draw_plasma_dome("player", screen_size)
	draw_plasma_dome("enemy", screen_size)
	draw_center_entanglement(screen_size)


func draw_dark_field(screen_size: Vector2) -> void:
	# Keep this subtle because Battle_V2_Background already owns the raw base.
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.005, 0.008, 0.018, 0.32), true)


func draw_soft_side_fields(screen_size: Vector2) -> void:
	var mid_x := screen_size.x * 0.5
	var player_shield := get_side_shield_ratio("player")
	var enemy_shield := get_side_shield_ratio("enemy")
	var player_hull_stress := 1.0 - get_side_hull_ratio("player")
	var enemy_hull_stress := 1.0 - get_side_hull_ratio("enemy")

	var player_alpha := 0.04 + (player_shield * 0.10) + (player_hull_stress * 0.05)
	var enemy_alpha := 0.04 + (enemy_shield * 0.10) + (enemy_hull_stress * 0.05)

	draw_rect(Rect2(Vector2.ZERO, Vector2(mid_x, screen_size.y)), Color(0.02, 0.18, 0.34, player_alpha), true)
	draw_rect(Rect2(Vector2(mid_x, 0.0), Vector2(mid_x, screen_size.y)), Color(0.34, 0.03, 0.03, enemy_alpha), true)

	# Hull stress under-layer. This only appears when the side is damaged/exposed.
	if player_hull_stress > 0.18:
		draw_rect(Rect2(Vector2.ZERO, Vector2(mid_x, screen_size.y)), Color(0.70, 0.16, 0.04, player_hull_stress * 0.045), true)
	if enemy_hull_stress > 0.18:
		draw_rect(Rect2(Vector2(mid_x, 0.0), Vector2(mid_x, screen_size.y)), Color(0.70, 0.16, 0.04, enemy_hull_stress * 0.045), true)


func draw_background_grid(screen_size: Vector2) -> void:
	var grid_color := Color(0.22, 0.36, 0.55, 0.045)
	var step := 64.0
	var x := 0.0
	while x <= screen_size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, screen_size.y), grid_color, 1.0)
		x += step
	var y := 0.0
	while y <= screen_size.y:
		draw_line(Vector2(0.0, y), Vector2(screen_size.x, y), grid_color, 1.0)
		y += step

	# Center split: visible enough to orient, soft enough to stay behind widgets.
	var mid_x := screen_size.x * 0.5
	draw_line(Vector2(mid_x, 0.0), Vector2(mid_x, screen_size.y), Color(0.75, 0.18, 1.0, 0.12), 2.0)


func draw_plasma_dome(side: String, screen_size: Vector2) -> void:
	var is_player := side == "player"
	var side_color := PLAYER_COLOR if is_player else ENEMY_COLOR
	var shield_ratio := get_side_shield_ratio(side)
	var hull_ratio := get_side_hull_ratio(side)
	var has_energy := get_side_has_energy(side)
	var shield_state := get_side_shield_state(side)
	var exposed := get_side_is_exposed(side)

	var side_strength := shield_ratio
	if not has_energy:
		side_strength *= 0.38
	if shield_state == "switching":
		side_strength *= 0.65
	if exposed:
		side_strength = max(side_strength * 0.20, 0.05)

	var source_x := -42.0 if is_player else screen_size.x + 42.0
	var source := Vector2(source_x, screen_size.y * 0.47)
	var dome_radius = lerp(210.0, 390.0, clamp(side_strength, 0.0, 1.0))
	var dome_alpha = lerp(0.08, 0.34, clamp(side_strength, 0.0, 1.0))
	var phase := player_field_phase if is_player else enemy_field_phase
	var pulse := 0.5 + 0.5 * sin(anim_time * 1.6 + phase)

	# Source glow, like the plasma-globe core just off-screen.
	for i in range(3):
		var radius := 52.0 + float(i) * 34.0 + pulse * 9.0
		var alpha := (0.050 / float(i + 1)) + (side_strength * 0.025)
		draw_circle(source, radius, Color(side_color.r, side_color.g, side_color.b, alpha))

	# Shield shell arcs.
	var start_angle := -0.95 if is_player else PI - 0.95
	var end_angle := 0.95 if is_player else PI + 0.95
	for ring in range(3):
		var rr = dome_radius + float(ring) * 18.0 + sin(anim_time * 0.9 + float(ring) + phase) * 5.0
		var alpha = dome_alpha * (0.75 - float(ring) * 0.18)
		draw_arc(source, rr, start_angle, end_angle, 72, Color(side_color.r, side_color.g, side_color.b, alpha), 2.0 + float(ring), true)

	# Plasma tendrils. Count and reach are shield-readable.
	var arc_count := int(lerp(2.0, 8.0, clamp(side_strength, 0.0, 1.0)))
	if shield_state == "no_energy":
		arc_count = max(arc_count - 2, 1)
	if exposed:
		arc_count = 1

	for i in range(arc_count):
		var t := (float(i) + 0.5) / float(max(arc_count, 1))
		var target_y = lerp(screen_size.y * 0.18, screen_size.y * 0.82, t)
		var center_bias := 0.47 + 0.07 * sin(anim_time * 0.55 + float(i) * 1.91 + phase)
		var target_x := screen_size.x * center_bias if is_player else screen_size.x * (1.0 - center_bias)
		var target := Vector2(target_x, target_y)
		var jitter = lerp(0.45, 1.25, 1.0 - shield_ratio)
		if shield_state == "no_energy" or exposed:
			jitter += 0.55
		var points := build_jagged_arc_points(source, target, i, jitter, is_player)
		var arc_alpha = lerp(0.12, 0.62, side_strength) * (0.80 + 0.20 * pulse)
		draw_plasma_polyline(points, side_color, arc_alpha)

		# Small branch toward nearby invisible touch points.
		if i % 2 == 0 and not exposed:
			var branch_start := points[int(points.size() * 0.55)]
			var branch_dir := Vector2(1.0 if is_player else -1.0, sin(float(i) * 2.17 + anim_time) * 0.7).normalized()
			var branch_end := branch_start + branch_dir * (42.0 + 45.0 * shield_ratio)
			var branch_points := build_jagged_arc_points(branch_start, branch_end, i + 80, jitter * 0.65, is_player)
			draw_plasma_polyline(branch_points, side_color, arc_alpha * 0.55)

	# Low hull makes dirty undercurrent visible even while shield exists.
	if hull_ratio < 0.70:
		var stress_alpha := (1.0 - hull_ratio) * (0.10 if exposed else 0.055)
		var side_rect := Rect2(Vector2.ZERO, Vector2(screen_size.x * 0.5, screen_size.y)) if is_player else Rect2(Vector2(screen_size.x * 0.5, 0.0), Vector2(screen_size.x * 0.5, screen_size.y))
		draw_rect(side_rect, Color(HULL_STRESS_COLOR.r, HULL_STRESS_COLOR.g, HULL_STRESS_COLOR.b, stress_alpha), true)


func draw_center_entanglement(screen_size: Vector2) -> void:
	var mid_x := screen_size.x * 0.5
	var player_strength := get_side_shield_ratio("player")
	var enemy_strength := get_side_shield_ratio("enemy")
	var pressure_offset := (player_strength - enemy_strength) * 52.0
	var center_alpha := 0.12 + ((player_strength + enemy_strength) * 0.12)
	var bands := 7

	for i in range(bands):
		var band_t := float(i) / float(max(bands - 1, 1))
		var points := PackedVector2Array()
		var segments := 18
		var x_base = mid_x + pressure_offset + lerp(-30.0, 30.0, band_t)
		var phase := anim_time * (0.85 + band_t * 0.25) + float(i) * 0.73
		for s in range(segments + 1):
			var y := screen_size.y * (float(s) / float(segments))
			var amp := 12.0 + 12.0 * sin(anim_time * 0.4 + float(i))
			var x = x_base + sin((float(s) * 0.72) + phase) * amp
			points.append(Vector2(x, y))

		var mix_color := CENTER_COLOR
		if i % 3 == 0:
			mix_color = PLAYER_COLOR
		elif i % 3 == 1:
			mix_color = ENEMY_COLOR
		draw_plasma_polyline(points, mix_color, center_alpha * (0.45 + band_t * 0.45), 0.75)

	# Crossing pressure lines: readable first version of manipulable center tension.
	var left_anchor := Vector2(screen_size.x * 0.38, screen_size.y * 0.50)
	var right_anchor := Vector2(screen_size.x * 0.62, screen_size.y * 0.50)
	for i in range(4):
		var y_offset = lerp(-140.0, 140.0, float(i) / 3.0)
		var start := left_anchor + Vector2(0.0, y_offset)
		var finish := right_anchor + Vector2(0.0, -y_offset * 0.55)
		var points := build_jagged_arc_points(start, finish, i + 200, 0.45, true)
		draw_plasma_polyline(points, CENTER_COLOR, 0.13 + center_alpha * 0.30, 0.55)


func build_jagged_arc_points(start: Vector2, finish: Vector2, arc_index: int, jitter: float, is_player: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments := 9
	var dir := finish - start
	var normal := Vector2(-dir.y, dir.x).normalized()
	var side_sign := 1.0 if is_player else -1.0
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var base := start.lerp(finish, t)
		var taper := sin(t * PI)
		var wave := sin((t * PI * 4.0) + anim_time * 4.2 + float(arc_index) * 1.37)
		var noise := (hash01(float(arc_index) * 19.13 + float(i) * 7.91) - 0.5) * 2.0
		var offset := normal * ((wave * 18.0 + noise * 20.0) * jitter * taper)
		var pull := Vector2(0.0, sin(anim_time * 2.0 + float(i) + float(arc_index)) * 8.0 * taper)
		points.append(base + offset + pull * side_sign)
	return points


func draw_plasma_polyline(points: PackedVector2Array, base_color: Color, alpha: float, width_scale: float = 1.0) -> void:
	if points.size() < 2:
		return
	var safe_alpha = clamp(alpha, 0.0, 1.0)
	draw_polyline(points, Color(base_color.r, base_color.g, base_color.b, safe_alpha * 0.11), 12.0 * width_scale, true)
	draw_polyline(points, Color(base_color.r, base_color.g, base_color.b, safe_alpha * 0.42), 4.5 * width_scale, true)
	draw_polyline(points, Color(0.90, 0.96, 1.0, safe_alpha * 0.78), 1.2 * width_scale, true)


func get_side_hull_ratio(side: String) -> float:
	var current_key := side + "_hp_current"
	var max_key := side + "_hp_max"
	var current := float(latest_header_state.get(current_key, 1.0))
	var maximum := float(latest_header_state.get(max_key, max(current, 1.0)))
	if maximum <= 0.0:
		return 1.0
	return clamp(current / maximum, 0.0, 1.0)


func get_side_shield_ratio(side: String) -> float:
	if latest_header_state.is_empty():
		return 1.0
	var current_key := side + "_shield_current"
	var max_key := side + "_shield_max"
	if latest_header_state.has(current_key) and latest_header_state.has(max_key):
		var current := float(latest_header_state.get(current_key, 0.0))
		var maximum := float(latest_header_state.get(max_key, max(current, 1.0)))
		if maximum > 0.0:
			return clamp(current / maximum, 0.0, 1.0)

	var power := float(latest_header_state.get(side + "_shield_power_level", 0.0))
	var max_count := float(latest_header_state.get(side + "_shield_max_count", 4.0))
	if max_count <= 0.0:
		return 0.0
	return clamp(power / max_count, 0.0, 1.0)


func get_side_has_energy(side: String) -> bool:
	return bool(latest_header_state.get(side + "_shield_has_energy", true))


func get_side_shield_state(side: String) -> String:
	var state := str(latest_header_state.get(side + "_shield_state", "active")).strip_edges().to_lower()
	if state == "":
		state = "active"
	return state


func get_side_is_exposed(side: String) -> bool:
	var shield_ratio := get_side_shield_ratio(side)
	var shield_state := get_side_shield_state(side)
	return shield_state in ["broken", "inactive", "hidden"] or shield_ratio <= 0.02


func get_side_widget_rect(side: String, screen_size: Vector2) -> Rect2:
	var point_id := side + "_panel"
	if position_data.has(point_id) and typeof(position_data.get(point_id, {})) == TYPE_DICTIONARY:
		var point: Dictionary = position_data.get(point_id, {})
		return Rect2(point.get("position", Vector2.ZERO), point.get("size", Vector2(360, 180)))
	if side == "player":
		return Rect2(Vector2(40, 95), Vector2(370, 185))
	return Rect2(Vector2(screen_size.x - 390.0, 95), Vector2(370, 185))


func hash01(value: float) -> float:
	var raw := sin(value * 12.9898 + 78.233) * 43758.5453
	return raw - floor(raw)
