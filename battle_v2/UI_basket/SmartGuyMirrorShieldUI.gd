extends RefCounted

class_name BattleV2SmartGuyMirrorShieldUI

# Visual-only handler for Smart Guy Mirror Shield.
# Safe contract: this script only draws. It never changes battle truth, timing, damage, or loadout state.

const ITEM_ID := "smart_guy_mirror_shield"
const ACTION_ID := "switch_shield"
const MIRROR_SILVER := Color(0.93, 0.96, 1.0, 1.0)
const MIRROR_WHITE := Color(1.0, 1.0, 1.0, 1.0)
const MIRROR_RED := Color(1.0, 0.18, 0.12, 1.0)
const MIRROR_VIOLET := Color(0.78, 0.42, 1.0, 1.0)


func matches_packet(packet: Dictionary) -> bool:
	var item_id := str(packet.get("item_id", "")).strip_edges().to_lower()
	if item_id == ITEM_ID:
		return true

	var item_name := str(packet.get("item_name", packet.get("display_name", packet.get("display_text", "")))).strip_edges().to_lower()
	if item_name.find("mirror shield") >= 0:
		return true

	if string_array_has(packet.get("labels", []), "smart_guy_item") and string_array_has(packet.get("labels", []), "enemy_shield"):
		return true

	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	return action_id == ACTION_ID and item_id == ITEM_ID


func matches_unit_side_state(side: String, side_state: Dictionary) -> bool:
	if side.strip_edges().to_lower() != "enemy":
		return false
	var selected_shield_id := str(side_state.get("selected_shield_id", side_state.get("equipped_shield_id", ""))).strip_edges().to_lower()
	if selected_shield_id == ITEM_ID:
		return true

	# Fallback heuristic only if the scene patch has not been merged yet.
	# This allows testing on the Smart Guy test enemy while still preferring explicit item id data.
	if selected_shield_id == "":
		var shield_max := float(side_state.get("shield_max", 0.0))
		return is_equal_approx(shield_max, 75.0)
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
	var pulse := 0.5 + 0.5 * sin(anim_time * 16.0 + t * 7.0)

	for i in range(4):
		var offset_angle := anim_time * 0.8 + float(i) * TAU / 4.0
		var shard_pos := pos + Vector2(cos(offset_angle), sin(offset_angle)) * (8.0 + float(i) * 3.0)
		draw_mirror_shard(canvas, shard_pos, 7.0 + pulse * 2.0, offset_angle, Color(MIRROR_SILVER.r, MIRROR_SILVER.g, MIRROR_SILVER.b, 0.34 * alpha), Color(MIRROR_RED.r, MIRROR_RED.g, MIRROR_RED.b, 0.18 * alpha))

	canvas.draw_line(start, pos, Color(MIRROR_RED.r, MIRROR_RED.g, MIRROR_RED.b, 0.16 * alpha), 1.4, true)
	canvas.draw_circle(start, 18.0 + pulse * 8.0, Color(MIRROR_WHITE.r, MIRROR_WHITE.g, MIRROR_WHITE.b, 0.06 * alpha))
	return true


func draw_todo_event(canvas: Control, event_summary: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(event_summary):
		return false

	var enemy_actor := get_anchor_rect(anchors, "enemy_actor")
	var todo_rect := get_anchor_rect(anchors, "todo")
	if enemy_actor.size == Vector2.ZERO or todo_rect.size == Vector2.ZERO:
		return true

	var progress = clamp(float(event_summary.get("progress", 0.0)), 0.0, 1.0)
	var source := todo_rect.position + todo_rect.size * 0.5
	var target := enemy_actor.position + enemy_actor.size * 0.5
	var converge_t := smoothstep(0.0, 0.92, progress)
	var center := source.lerp(target, converge_t)
	var pulse := 0.5 + 0.5 * sin(anim_time * 14.0)

	# Mirror shards gather from TODO to the enemy, then lock into orbit around the ship.
	for i in range(6):
		var shard_progress = clamp(progress - float(i) * 0.08, 0.0, 1.0)
		var from := source + Vector2(cos(anim_time * 0.6 + float(i) * 1.2), sin(anim_time * 0.8 + float(i) * 1.4)) * (18.0 + float(i) * 4.0)
		var to_angle := anim_time * 0.55 + float(i) * TAU / 6.0
		var to = target + Vector2(cos(to_angle), sin(to_angle)) * (42.0 - progress * 8.0)
		var pos := from.lerp(to, shard_progress)
		draw_mirror_shard(canvas, pos, 6.0 + pulse * 1.2, to_angle, Color(MIRROR_SILVER.r, MIRROR_SILVER.g, MIRROR_SILVER.b, 0.46), Color(MIRROR_RED.r, MIRROR_RED.g, MIRROR_RED.b, 0.18))
		if shard_progress > 0.05:
			canvas.draw_line(pos, pos.lerp(from, 0.18), Color(MIRROR_RED.r, MIRROR_RED.g, MIRROR_RED.b, 0.08 + 0.06 * (1.0 - shard_progress)), 1.0, true)

	if progress >= 0.72:
		var flash_alpha := smoothstep(0.72, 1.0, progress)
		canvas.draw_circle(target, 28.0 + pulse * 5.0, Color(MIRROR_WHITE.r, MIRROR_WHITE.g, MIRROR_WHITE.b, 0.08 * flash_alpha))
		canvas.draw_circle(target, 42.0 + pulse * 6.0, Color(MIRROR_VIOLET.r, MIRROR_VIOLET.g, MIRROR_VIOLET.b, 0.05 * flash_alpha))

	return true


func draw_shield_overlay(canvas: Control, side: String, center: Vector2, side_state: Dictionary, anim_time: float) -> bool:
	if not matches_unit_side_state(side, side_state):
		return false

	var shield_current := float(side_state.get("shield_current", 0.0))
	var shield_max = max(float(side_state.get("shield_max", 0.0)), 0.0)
	var shield_state := str(side_state.get("shield_state", "active")).strip_edges().to_lower()
	var has_energy := bool(side_state.get("shield_has_energy", true))
	var power_level = clamp(int(side_state.get("shield_power_level", 0)), 0, 4)
	var shield_ratio := 0.0
	if shield_max > 0.0:
		shield_ratio = clamp(shield_current / shield_max, 0.0, 1.0)

	var active = shield_max > 0.0 and shield_current > 0.0 and shield_state != "broken" and shield_state != "down"
	var weak = active and (not has_energy or shield_state == "no_energy")
	var broken = (shield_max > 0.0 and shield_current <= 0.0) or shield_state == "broken" or shield_state == "down"

	if broken:
		draw_broken_mirror_field(canvas, center, anim_time)
		return true

	var shard_count = 4 + power_level + int(ceil(shield_ratio * 2.0))
	shard_count = clamp(shard_count, 4, 10)
	var orbit_radius := 42.0 + shield_ratio * 12.0
	var drift_scale := 1.0
	if weak:
		drift_scale = 1.55

	for i in range(shard_count):
		var t = float(i) / max(float(shard_count), 1.0)
		var angle = anim_time * (0.42 + t * 0.22) + t * TAU
		if weak:
			angle += sin(anim_time * (1.2 + t * 0.8) + t * 9.0) * 0.18
		var radius := orbit_radius + sin(anim_time * (1.8 + t * 0.7) + t * 8.0) * 3.0 * drift_scale
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		var shard_size := 8.0 + shield_ratio * 4.0 + sin(anim_time * 3.0 + t * 6.0) * 0.8
		var alpha := 0.18 + shield_ratio * 0.28
		if weak:
			alpha *= 0.55
		draw_mirror_shard(canvas, pos, shard_size, angle + PI * 0.5, Color(MIRROR_SILVER.r, MIRROR_SILVER.g, MIRROR_SILVER.b, alpha), Color(MIRROR_RED.r, MIRROR_RED.g, MIRROR_RED.b, alpha * 0.45))

		# Reflection line from shard to center.
		canvas.draw_line(pos, center, Color(MIRROR_WHITE.r, MIRROR_WHITE.g, MIRROR_WHITE.b, 0.018 + alpha * 0.10), 1.0, true)
		if weak and i % 3 == 0:
			canvas.draw_line(pos + Vector2(-3.0, -2.0), pos + Vector2(4.0, 3.0), Color(MIRROR_RED.r, MIRROR_RED.g, MIRROR_RED.b, 0.18), 1.0, true)

	var shell_alpha := 0.05 + shield_ratio * 0.05
	if weak:
		shell_alpha *= 0.45
	canvas.draw_circle(center, orbit_radius + 14.0, Color(MIRROR_VIOLET.r, MIRROR_VIOLET.g, MIRROR_VIOLET.b, shell_alpha))
	canvas.draw_arc(center, orbit_radius + 6.0, anim_time * 0.3, anim_time * 0.3 + TAU * (0.22 + shield_ratio * 0.18), 38, Color(MIRROR_RED.r, MIRROR_RED.g, MIRROR_RED.b, 0.10 + shield_ratio * 0.08), 1.4, true)
	return true


func draw_broken_mirror_field(canvas: Control, center: Vector2, anim_time: float) -> void:
	for i in range(8):
		var t := float(i) / 8.0
		var angle := anim_time * 0.22 + t * TAU
		var radius := 54.0 + float(i % 3) * 9.0
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		draw_mirror_shard(canvas, pos, 7.0 + float(i % 2) * 2.0, angle, Color(MIRROR_SILVER.r, MIRROR_SILVER.g, MIRROR_SILVER.b, 0.14), Color(MIRROR_RED.r, MIRROR_RED.g, MIRROR_RED.b, 0.10))
		canvas.draw_line(pos, pos + Vector2(cos(angle), sin(angle)) * 8.0, Color(MIRROR_RED.r, MIRROR_RED.g, MIRROR_RED.b, 0.12), 1.0, true)


func draw_mirror_shard(canvas: Control, center: Vector2, size: float, angle: float, fill: Color, edge: Color) -> void:
	var points := PackedVector2Array()
	points.append(center + rotated(Vector2(0.0, -size), angle))
	points.append(center + rotated(Vector2(size * 0.68, 0.0), angle))
	points.append(center + rotated(Vector2(0.0, size), angle))
	points.append(center + rotated(Vector2(-size * 0.52, 0.0), angle))
	canvas.draw_colored_polygon(points, fill)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	canvas.draw_polyline(outline, edge, 1.2, true)
	canvas.draw_line(center + rotated(Vector2(-size * 0.25, -size * 0.05), angle), center + rotated(Vector2(size * 0.18, size * 0.20), angle), Color(MIRROR_WHITE.r, MIRROR_WHITE.g, MIRROR_WHITE.b, fill.a * 0.58), 1.0, true)


func rotated(v: Vector2, angle: float) -> Vector2:
	return Vector2(v.x * cos(angle) - v.y * sin(angle), v.x * sin(angle) + v.y * cos(angle))


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
