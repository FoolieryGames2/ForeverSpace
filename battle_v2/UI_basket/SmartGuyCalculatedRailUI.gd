extends RefCounted

class_name BattleV2SmartGuyCalculatedRailUI

# Visual-only handler for Smart Guy Calculated Rail.
# Safe contract: this script only draws. It never changes battle state, damage, TODO timing, cooldowns, or inventory.

const ITEM_ID := "smart_guy_calculated_rail"
const ACTION_ID := "fire_smart_guy_calculated_rail"
const RAIL_RED := Color(1.0, 0.16, 0.08, 1.0)
const RAIL_CORE := Color(1.0, 0.72, 0.38, 1.0)
const CALC_WHITE := Color(0.90, 0.98, 1.0, 1.0)
const RAIL_SHADOW := Color(0.36, 0.04, 0.02, 1.0)


func matches_packet(packet: Dictionary) -> bool:
	var item_id := str(packet.get("item_id", "")).strip_edges().to_lower()
	if item_id == ITEM_ID:
		return true

	var item_name := str(packet.get("item_name", packet.get("display_text", packet.get("display_name", "")))).strip_edges().to_lower()
	if item_name.find("smart guy calculated rail") >= 0:
		return true

	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	if action_id == ACTION_ID:
		return true

	if string_array_has(packet.get("labels", []), "smart_guy_item") and string_array_has(packet.get("labels", []), "secondary_weapon_kinetic"):
		return item_id.find("calculated_rail") >= 0 or item_name.find("calculated rail") >= 0

	return false


func draw_action_click(canvas: Control, packet: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(packet):
		return false

	var age := float(packet.get("age", 0.0))
	var duration = max(float(packet.get("duration", 0.72)), 0.01)
	var t = clamp(age / duration, 0.0, 1.0)
	var alpha = 1.0 - t

	var enemy_actor := get_anchor_rect(anchors, "enemy_actor")
	var todo_rect := get_anchor_rect(anchors, "todo")
	if enemy_actor.size == Vector2.ZERO or todo_rect.size == Vector2.ZERO:
		return true

	var start := enemy_actor.position + enemy_actor.size * 0.5
	var finish := todo_rect.position + todo_rect.size * 0.5
	var pos := start.lerp(finish, t)
	var pulse := 0.5 + 0.5 * sin(anim_time * 18.0 + t * 8.0)

	canvas.draw_line(start, pos, Color(RAIL_RED.r, RAIL_RED.g, RAIL_RED.b, 0.25 * alpha), 2.0, true)
	canvas.draw_line(start + Vector2(0.0, -5.0), pos + Vector2(0.0, -5.0), Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, 0.15 * alpha), 1.0, true)
	canvas.draw_line(start + Vector2(0.0, 5.0), pos + Vector2(0.0, 5.0), Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, 0.15 * alpha), 1.0, true)
	canvas.draw_circle(start, 14.0 + pulse * 7.0, Color(RAIL_RED.r, RAIL_RED.g, RAIL_RED.b, 0.10 * alpha))
	draw_slug(canvas, pos, Vector2(-1.0, 0.0), 0.72 * alpha, 0.78 + pulse * 0.18)

	# Small solver squares tell the player this is a calculated secondary shot, not a wild burst.
	for i in range(2):
		var tick_t = clamp(t - float(i) * 0.12, 0.0, 1.0)
		var tick_pos := start.lerp(finish, tick_t) + Vector2(0.0, -12.0 + float(i) * 24.0)
		draw_mini_square(canvas, tick_pos, 7.0 + pulse * 1.5, Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, 0.38 * alpha))

	return true


func draw_todo_event(canvas: Control, event_summary: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(event_summary):
		return false

	var progress = clamp(float(event_summary.get("progress", 0.0)), 0.0, 1.0)
	var enemy_actor := get_anchor_rect(anchors, "enemy_actor")
	var player_actor := get_anchor_rect(anchors, "player_actor")
	var enemy_lane := get_anchor_rect(anchors, "enemy_lane")
	if enemy_actor.size == Vector2.ZERO or player_actor.size == Vector2.ZERO or enemy_lane.size == Vector2.ZERO:
		return true

	var source := enemy_actor.position + enemy_actor.size * 0.5 + Vector2(-42.0, 0.0)
	var target := player_actor.position + player_actor.size * 0.5 + Vector2(42.0, 0.0)
	var lane_y := enemy_lane.position.y + enemy_lane.size.y * 0.5
	source.y = lane_y
	target.y = lane_y

	var burst_index := int(event_summary.get("burst_index", event_summary.get("burst_number", 1)))
	var burst_total = max(int(event_summary.get("burst_total", event_summary.get("original_burst_count", 2))), 1)
	if burst_index <= 0:
		burst_index = 1
	var offset_index := float(burst_index - 1) - float(burst_total - 1) * 0.5
	var lane_offset := Vector2(0.0, offset_index * 18.0)

	var s := source + lane_offset
	var e := target + lane_offset
	var aim_t := smoothstep(0.0, 0.48, progress)
	var release_t := smoothstep(0.48, 1.0, progress)
	var snap_t := ease_out_cubic(release_t)
	var slug_pos := s.lerp(e, snap_t)
	var pulse := 0.5 + 0.5 * sin(anim_time * 16.0 + float(burst_index) * 1.7)

	# Calculated twin rails: line up first, then fire the slug down the solved lane.
	draw_prediction_ladder(canvas, s, e, aim_t, burst_index, anim_time)
	canvas.draw_line(s, e, Color(RAIL_RED.r, RAIL_RED.g, RAIL_RED.b, 0.06 + aim_t * 0.15), 1.0, true)
	canvas.draw_line(s + Vector2(0.0, -6.0), e + Vector2(0.0, -6.0), Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, 0.04 + aim_t * 0.11), 1.0, true)
	canvas.draw_line(s + Vector2(0.0, 6.0), e + Vector2(0.0, 6.0), Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, 0.04 + aim_t * 0.11), 1.0, true)

	# Solver reticle hangs near mid lane while Smart Guy chooses the exact shot.
	var solver_center := s.lerp(e, 0.52) + Vector2(0.0, sin(anim_time * 2.2 + float(burst_index)) * 3.0)
	draw_calculated_solver(canvas, solver_center, aim_t, progress, anim_time, burst_index)

	if release_t > 0.0:
		canvas.draw_line(s, slug_pos, Color(RAIL_RED.r, RAIL_RED.g, RAIL_RED.b, 0.22 * release_t), 3.0, true)
		canvas.draw_line(s, slug_pos, Color(RAIL_SHADOW.r, RAIL_SHADOW.g, RAIL_SHADOW.b, 0.18 * release_t), 7.0 + pulse * 1.5, true)
		draw_slug(canvas, slug_pos, (e - s).normalized(), 0.82, 1.0 + pulse * 0.12)
		if release_t >= 0.94:
			draw_kinetic_contact(canvas, target, unit_state, anim_time, release_t, burst_index)
	else:
		var chamber := s.lerp(e, 0.12 + aim_t * 0.18)
		canvas.draw_circle(chamber, 5.0 + pulse * 3.0, Color(RAIL_CORE.r, RAIL_CORE.g, RAIL_CORE.b, 0.16 + aim_t * 0.18))
		canvas.draw_circle(chamber, 2.5, Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, 0.36 + aim_t * 0.25))

	return true


func draw_prediction_ladder(canvas: Control, start: Vector2, finish: Vector2, aim_t: float, burst_index: int, anim_time: float) -> void:
	var alpha := 0.08 + aim_t * 0.22
	for i in range(5):
		var t := (float(i) + 1.0) / 6.0
		var center := start.lerp(finish, t)
		var wobble := sin(anim_time * 3.0 + float(i) * 0.7 + float(burst_index)) * (1.0 - aim_t) * 5.0
		center.y += wobble
		var half := 5.0 + aim_t * 5.0
		canvas.draw_line(center + Vector2(0.0, -half), center + Vector2(0.0, half), Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, alpha), 1.0, true)
		canvas.draw_circle(center, 1.7 + aim_t * 0.7, Color(RAIL_RED.r, RAIL_RED.g, RAIL_RED.b, alpha * 0.75))


func draw_calculated_solver(canvas: Control, center: Vector2, aim_t: float, progress: float, anim_time: float, burst_index: int) -> void:
	var spin := anim_time * (0.7 + aim_t * 0.4) + float(burst_index) * 0.6
	var radius := 24.0 - aim_t * 5.0
	var alpha := 0.10 + aim_t * 0.36
	draw_mini_square(canvas, center, radius, Color(RAIL_RED.r, RAIL_RED.g, RAIL_RED.b, alpha))
	canvas.draw_arc(center, radius + 9.0, spin, spin + PI * 0.72, 24, Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, alpha * 0.74), 1.2, true)
	canvas.draw_arc(center, radius + 15.0, -spin, -spin + PI * 0.42, 18, Color(RAIL_CORE.r, RAIL_CORE.g, RAIL_CORE.b, alpha * 0.52), 1.2, true)
	for i in range(2):
		var angle := spin + PI * float(i)
		var p := center + Vector2(cos(angle), sin(angle)) * (radius + 5.0)
		canvas.draw_circle(p, 2.2 + aim_t, Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, alpha))


func draw_slug(canvas: Control, center: Vector2, dir: Vector2, alpha: float, scale: float) -> void:
	if dir == Vector2.ZERO:
		dir = Vector2(-1.0, 0.0)
	dir = dir.normalized()
	var side := Vector2(-dir.y, dir.x)
	var nose := center + dir * 13.0 * scale
	var tail := center - dir * 9.0 * scale
	var points := PackedVector2Array([
		nose,
		tail + side * 5.0 * scale,
		tail - side * 5.0 * scale
	])
	canvas.draw_colored_polygon(points, Color(RAIL_CORE.r, RAIL_CORE.g, RAIL_CORE.b, 0.75 * alpha))
	canvas.draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, 0.62 * alpha), 1.2, true)
	canvas.draw_line(tail, tail - dir * 16.0 * scale, Color(RAIL_RED.r, RAIL_RED.g, RAIL_RED.b, 0.28 * alpha), 2.0, true)


func draw_kinetic_contact(canvas: Control, target: Vector2, unit_state: Dictionary, anim_time: float, alpha: float, burst_index: int) -> void:
	var player_state: Dictionary = {}
	if typeof(unit_state.get("player", {})) == TYPE_DICTIONARY:
		player_state = unit_state.get("player", {})

	var shield_current := float(player_state.get("shield_current", 0.0))
	var shield_max = max(float(player_state.get("shield_max", 0.0)), 0.0)
	var shield_state := str(player_state.get("shield_state", "")).strip_edges().to_lower()
	var has_energy := bool(player_state.get("shield_has_energy", true))
	var has_shield_capacity = shield_max > 0.0
	var shield_active = has_shield_capacity and shield_current > 0.0 and shield_state != "broken" and shield_state != "down"
	var weak_shield = shield_active and (not has_energy or shield_state == "no_energy")
	var pulse := 0.5 + 0.5 * sin(anim_time * 23.0 + float(burst_index))

	if shield_active:
		var shield_alpha := 0.34 * alpha
		if weak_shield:
			shield_alpha *= 0.48
		for i in range(5):
			var angle := PI + (float(i) - 2.0) * 0.19
			var p1 := target + Vector2(cos(angle), sin(angle)) * (28.0 + pulse * 3.0)
			var p2 := p1 + Vector2(cos(angle + 0.45), sin(angle + 0.45)) * 13.0
			canvas.draw_line(p1, p2, Color(RAIL_CORE.r, RAIL_CORE.g, RAIL_CORE.b, shield_alpha), 2.0, true)
		canvas.draw_arc(target, 34.0 + pulse * 3.0, PI - 0.75, PI + 0.75, 34, Color(RAIL_RED.r, RAIL_RED.g, RAIL_RED.b, shield_alpha * 0.8), 2.0, true)
	else:
		if has_shield_capacity:
			for i in range(4):
				var chip_angle := PI + (float(i) - 1.5) * 0.28
				var chip_pos := target + Vector2(cos(chip_angle), sin(chip_angle)) * (30.0 + pulse * 2.0)
				canvas.draw_line(chip_pos, chip_pos + Vector2(-9.0, sin(float(i)) * 5.0), Color(RAIL_RED.r, RAIL_RED.g, RAIL_RED.b, 0.26 * alpha), 1.2, true)
		for i in range(7):
			var a := PI + (float(i) - 3.0) * 0.20
			var p := target + Vector2(cos(a), sin(a)) * (8.0 + pulse * 2.0)
			canvas.draw_line(p, p + Vector2(cos(a), sin(a)) * (14.0 + float(i % 3) * 3.0), Color(RAIL_CORE.r, RAIL_CORE.g, RAIL_CORE.b, 0.38 * alpha), 1.4, true)
		canvas.draw_circle(target + Vector2(-8.0, 0.0), 9.0 + pulse * 3.0, Color(RAIL_RED.r, RAIL_RED.g, RAIL_RED.b, 0.22 * alpha))
		canvas.draw_circle(target + Vector2(-8.0, 0.0), 3.5, Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, 0.70 * alpha))


func draw_mini_square(canvas: Control, center: Vector2, half: float, color: Color) -> void:
	var p1 := center + Vector2(-half, -half)
	var p2 := center + Vector2(half, -half)
	var p3 := center + Vector2(half, half)
	var p4 := center + Vector2(-half, half)
	canvas.draw_line(p1, p2, color, 1.2, true)
	canvas.draw_line(p2, p3, color, 1.2, true)
	canvas.draw_line(p3, p4, color, 1.2, true)
	canvas.draw_line(p4, p1, color, 1.2, true)


func ease_out_cubic(t: float) -> float:
	var u = 1.0 - clamp(t, 0.0, 1.0)
	return 1.0 - u * u * u


func get_anchor_rect(anchors: Dictionary, key: String) -> Rect2:
	var value = anchors.get(key, Rect2())
	if typeof(value) == TYPE_RECT2:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return Rect2(value.get("position", Vector2.ZERO), value.get("size", Vector2.ZERO))
	return Rect2()


func string_array_has(value, needle: String) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var clean_needle := needle.strip_edges().to_lower()
	for entry in value:
		if str(entry).strip_edges().to_lower() == clean_needle:
			return true
	return false
