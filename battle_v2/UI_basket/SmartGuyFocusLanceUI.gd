extends RefCounted

class_name BattleV2SmartGuyFocusLanceUI

# Visual-only handler for Smart Guy Focus Lance.
# Safe contract: this script only draws. It never changes battle state, damage, TODO timing, cooldowns, or inventory.

const ITEM_ID := "smart_guy_focus_lance"
const ACTION_ID := "fire_smart_guy_focus_lance"
const LANCE_RED := Color(1.0, 0.10, 0.08, 1.0)
const LANCE_CORE := Color(1.0, 0.82, 0.58, 1.0)
const CALC_WHITE := Color(0.92, 0.98, 1.0, 1.0)
const TARGET_RED := Color(1.0, 0.22, 0.12, 1.0)


func matches_packet(packet: Dictionary) -> bool:
	var item_id := str(packet.get("item_id", "")).strip_edges().to_lower()
	if item_id == ITEM_ID:
		return true

	var item_name := str(packet.get("item_name", packet.get("display_text", packet.get("display_name", "")))).strip_edges().to_lower()
	if item_name.find("smart guy focus lance") >= 0:
		return true

	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	if action_id == ACTION_ID:
		return true

	if string_array_has(packet.get("labels", []), "smart_guy_item") and string_array_has(packet.get("labels", []), "primary_weapon_energy"):
		return item_id.find("focus_lance") >= 0 or item_name.find("focus lance") >= 0

	return false


func draw_action_click(canvas: Control, packet: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(packet):
		return false

	var age := float(packet.get("age", 0.0))
	var duration = max(float(packet.get("duration", 0.72)), 0.01)
	var t = clamp(age / duration, 0.0, 1.0)
	var alpha = 1.0 - t

	# Enemy action clicks do not have a dedicated enemy action widget anchor.
	# Use enemy actor -> TODO so the player can read that Smart Guy has committed a focused shot.
	var enemy_actor := get_anchor_rect(anchors, "enemy_actor")
	var todo_rect := get_anchor_rect(anchors, "todo")
	if enemy_actor.size == Vector2.ZERO or todo_rect.size == Vector2.ZERO:
		return true

	var start := enemy_actor.position + enemy_actor.size * 0.5
	var finish := todo_rect.position + todo_rect.size * 0.5
	var pos := start.lerp(finish, t)
	var pulse := 0.5 + 0.5 * sin(anim_time * 22.0 + t * 8.0)

	canvas.draw_line(start, pos, Color(LANCE_RED.r, LANCE_RED.g, LANCE_RED.b, 0.28 * alpha), 2.0, true)
	canvas.draw_circle(start, 18.0 + pulse * 10.0 + t * 6.0, Color(LANCE_RED.r, LANCE_RED.g, LANCE_RED.b, 0.10 * alpha))
	canvas.draw_circle(pos, 7.0 + pulse * 3.0, Color(LANCE_CORE.r, LANCE_CORE.g, LANCE_CORE.b, 0.72 * alpha))

	# Calculated targeting ticks: three small red brackets that move toward TODO.
	for i in range(3):
		var tick_t = clamp(t - float(i) * 0.10, 0.0, 1.0)
		var tick_pos := start.lerp(finish, tick_t)
		var side := Vector2(0.0, -1.0 if i % 2 == 0 else 1.0) * (10.0 + pulse * 4.0)
		canvas.draw_line(tick_pos + side + Vector2(-5.0, 0.0), tick_pos + side + Vector2(5.0, 0.0), Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, 0.48 * alpha), 1.0, true)

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

	var focus_t := smoothstep(0.0, 0.78, progress)
	var release_t := smoothstep(0.78, 1.0, progress)
	var focus_point := source.lerp(target, 0.38 + 0.10 * sin(anim_time * 1.5))
	var heat := 0.5 + 0.5 * sin(anim_time * 18.0)

	# Long red calculated sight line. It gets more certain as the TODO approaches release.
	canvas.draw_line(source, target, Color(LANCE_RED.r, LANCE_RED.g, LANCE_RED.b, 0.07 + focus_t * 0.13), 1.0, true)
	canvas.draw_line(source + Vector2(0.0, -8.0), target + Vector2(0.0, -8.0), Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, 0.035 + focus_t * 0.07), 1.0, true)
	canvas.draw_line(source + Vector2(0.0, 8.0), target + Vector2(0.0, 8.0), Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, 0.035 + focus_t * 0.07), 1.0, true)

	# Smart Guy identity: a geometric focus reticle that solves around the middle before the lance fires.
	draw_focus_solver(canvas, focus_point, progress, anim_time)

	# Targeting square over the player: it tightens while charging.
	draw_target_square(canvas, target, progress, anim_time)

	# Beam only really releases in the final fraction.
	if release_t > 0.0:
		var beam_alpha = clamp(release_t, 0.0, 1.0)
		var beam_front := source.lerp(target, release_t)
		canvas.draw_line(source, beam_front, Color(LANCE_CORE.r, LANCE_CORE.g, LANCE_CORE.b, 0.82 * beam_alpha), 3.0, true)
		canvas.draw_line(source, beam_front, Color(LANCE_RED.r, LANCE_RED.g, LANCE_RED.b, 0.42 * beam_alpha), 9.0 + heat * 2.0, true)
		canvas.draw_line(source + Vector2(0.0, -4.0), beam_front + Vector2(0.0, -4.0), Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, 0.28 * beam_alpha), 1.0, true)
		canvas.draw_line(source + Vector2(0.0, 4.0), beam_front + Vector2(0.0, 4.0), Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, 0.28 * beam_alpha), 1.0, true)
		if release_t >= 0.96:
			draw_focus_contact(canvas, target, unit_state, anim_time, beam_alpha)
	else:
		# Pre-release charge bead, not a damage read.
		var bead := source.lerp(target, 0.10 + focus_t * 0.44)
		canvas.draw_circle(bead, 10.0 + heat * 5.0, Color(LANCE_RED.r, LANCE_RED.g, LANCE_RED.b, 0.10 + focus_t * 0.12))
		canvas.draw_circle(bead, 3.0 + heat * 1.5, Color(LANCE_CORE.r, LANCE_CORE.g, LANCE_CORE.b, 0.45 + focus_t * 0.28))

	return true


func draw_focus_solver(canvas: Control, center: Vector2, progress: float, anim_time: float) -> void:
	var focus_t := smoothstep(0.0, 0.82, progress)
	var spin := anim_time * (0.9 + focus_t * 0.7)
	var radius := 30.0 - focus_t * 7.0 + sin(anim_time * 5.0) * 1.5
	var alpha := 0.12 + focus_t * 0.36

	for i in range(3):
		var angle := spin + float(i) * TAU / 3.0
		var p1 := center + Vector2(cos(angle), sin(angle)) * radius
		var p2 := center + Vector2(cos(angle + 0.55), sin(angle + 0.55)) * (radius + 9.0)
		canvas.draw_line(p1, p2, Color(LANCE_RED.r, LANCE_RED.g, LANCE_RED.b, alpha), 2.0, true)
		canvas.draw_circle(p1, 2.2 + focus_t * 1.2, Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, alpha * 0.9))

	canvas.draw_arc(center, radius + 14.0, -spin, -spin + TAU * (0.32 + focus_t * 0.18), 42, Color(CALC_WHITE.r, CALC_WHITE.g, CALC_WHITE.b, alpha * 0.55), 1.4, true)
	canvas.draw_circle(center, 5.0 + focus_t * 4.0, Color(LANCE_CORE.r, LANCE_CORE.g, LANCE_CORE.b, 0.08 + focus_t * 0.14))


func draw_target_square(canvas: Control, center: Vector2, progress: float, anim_time: float) -> void:
	var lock_t := smoothstep(0.1, 0.82, progress)
	var pulse := 0.5 + 0.5 * sin(anim_time * 8.0)
	var half := 45.0 - lock_t * 13.0 + pulse * 2.0
	var alpha := 0.14 + lock_t * 0.42
	var len := 13.0 + lock_t * 5.0
	var c := Color(TARGET_RED.r, TARGET_RED.g, TARGET_RED.b, alpha)
	var hot := Color(LANCE_CORE.r, LANCE_CORE.g, LANCE_CORE.b, alpha * 0.65)

	var corners := [
		center + Vector2(-half, -half),
		center + Vector2(half, -half),
		center + Vector2(half, half),
		center + Vector2(-half, half)
	]
	for corner in corners:
		var sx := 1.0 if corner.x < center.x else -1.0
		var sy := 1.0 if corner.y < center.y else -1.0
		canvas.draw_line(corner, corner + Vector2(sx * len, 0.0), c, 2.0, true)
		canvas.draw_line(corner, corner + Vector2(0.0, sy * len), c, 2.0, true)
	canvas.draw_circle(center, 2.5 + pulse * 1.5, hot)


func draw_focus_contact(canvas: Control, target: Vector2, unit_state: Dictionary, anim_time: float, alpha: float) -> void:
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
	var pulse := 0.5 + 0.5 * sin(anim_time * 26.0)

	if shield_active:
		var shield_alpha := 0.34 * alpha
		if weak_shield:
			shield_alpha *= 0.48
		for ring in range(4):
			var radius := 17.0 + float(ring) * 9.0 + pulse * 3.0
			canvas.draw_arc(target, radius, PI - 0.85, PI + 0.85, 34, Color(LANCE_RED.r, LANCE_RED.g, LANCE_RED.b, (shield_alpha - float(ring) * 0.045)), 2.0, true)
		canvas.draw_circle(target, 7.0 + pulse * 3.0, Color(LANCE_CORE.r, LANCE_CORE.g, LANCE_CORE.b, 0.18 * alpha))
		if weak_shield:
			for i in range(4):
				var ang := PI + float(i) * 0.42 - 0.63
				var p := target + Vector2(cos(ang), sin(ang)) * (34.0 + pulse * 2.0)
				canvas.draw_circle(p, 1.9, Color(LANCE_RED.r, LANCE_RED.g, LANCE_RED.b, 0.36 * alpha))
	else:
		if has_shield_capacity:
			for i in range(5):
				var chip_angle := PI + float(i) * 0.32 - 0.64
				var chip_pos := target + Vector2(cos(chip_angle), sin(chip_angle)) * (28.0 + pulse * 4.0)
				canvas.draw_line(chip_pos, chip_pos + Vector2(-8.0, sin(float(i)) * 4.0), Color(LANCE_RED.r, LANCE_RED.g, LANCE_RED.b, 0.32 * alpha), 1.4, true)
		canvas.draw_circle(target + Vector2(-10.0, 0.0), 12.0 + pulse * 4.0, Color(LANCE_RED.r, LANCE_RED.g, LANCE_RED.b, 0.28 * alpha))
		canvas.draw_circle(target + Vector2(-10.0, 0.0), 4.0, Color(LANCE_CORE.r, LANCE_CORE.g, LANCE_CORE.b, 0.82 * alpha))


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
