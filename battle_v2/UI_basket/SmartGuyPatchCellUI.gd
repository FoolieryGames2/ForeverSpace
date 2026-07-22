extends RefCounted

class_name BattleV2SmartGuyPatchCellUI

# Visual-only handler for Smart Guy Patch Cell.
# Safe contract: this script only draws. It never changes battle truth, timing, damage, healing, cooldowns, or inventory.

const ITEM_ID := "smart_guy_patch_cell"
const ACTION_ID := "repair_ship"
const PATCH_RED := Color(1.0, 0.16, 0.10, 1.0)
const PATCH_WHITE := Color(0.94, 1.0, 0.96, 1.0)
const PATCH_GREEN := Color(0.32, 1.0, 0.64, 1.0)
const PATCH_VIOLET := Color(0.74, 0.40, 1.0, 1.0)


func matches_packet(packet: Dictionary) -> bool:
	var item_id := str(packet.get("item_id", "")).strip_edges().to_lower()
	if item_id == ITEM_ID:
		return true

	var item_name := str(packet.get("item_name", packet.get("display_name", packet.get("display_text", "")))).strip_edges().to_lower()
	if item_name.find("smart guy patch cell") >= 0:
		return true

	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	if action_id == ACTION_ID and item_id == ITEM_ID:
		return true

	if string_array_has(packet.get("labels", []), "smart_guy_item") and string_array_has(packet.get("labels", []), "consumable_group_repair"):
		return true

	var group := str(packet.get("event_group", packet.get("consumable_group", ""))).strip_edges().to_lower()
	return group == "repair" and item_name.find("patch cell") >= 0


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

	# Enemy repair commitment: a small red/green diagnostic cell leaves the enemy and enters TODO.
	canvas.draw_line(start, pos, Color(PATCH_GREEN.r, PATCH_GREEN.g, PATCH_GREEN.b, 0.18 * alpha), 2.0, true)
	canvas.draw_line(start + Vector2(0.0, -5.0), pos + Vector2(0.0, -5.0), Color(PATCH_RED.r, PATCH_RED.g, PATCH_RED.b, 0.12 * alpha), 1.0, true)

	draw_patch_cell(canvas, pos, 9.0 + pulse * 2.0, anim_time * 1.8 + t * 5.0, 0.58 * alpha)

	for i in range(4):
		var tick_t = clamp(t - float(i) * 0.08, 0.0, 1.0)
		var tick_pos := start.lerp(finish, tick_t)
		var off := Vector2(0.0, -12.0 + float(i % 2) * 24.0)
		canvas.draw_circle(tick_pos + off, 1.8 + pulse * 0.8, Color(PATCH_GREEN.r, PATCH_GREEN.g, PATCH_GREEN.b, 0.36 * alpha))

	return true


func draw_todo_event(canvas: Control, event_summary: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(event_summary):
		return false

	var progress = clamp(float(event_summary.get("progress", 0.0)), 0.0, 1.0)
	var enemy_actor := get_anchor_rect(anchors, "enemy_actor")
	var todo_rect := get_anchor_rect(anchors, "todo")
	var enemy_lane := get_anchor_rect(anchors, "enemy_lane")
	if enemy_actor.size == Vector2.ZERO or todo_rect.size == Vector2.ZERO:
		return true

	var owner := enemy_actor.position + enemy_actor.size * 0.5
	var todo := todo_rect.position + todo_rect.size * 0.5
	if enemy_lane.size != Vector2.ZERO:
		owner.y = enemy_lane.position.y + enemy_lane.size.y * 0.5

	var charge_t := smoothstep(0.0, 0.66, progress)
	var release_t := smoothstep(0.66, 1.0, progress)
	var pulse := 0.5 + 0.5 * sin(anim_time * 12.0)

	# Phase 1: calculated medical lattice builds in the lane.
	var build_center := todo.lerp(owner, 0.36)
	build_center.y += sin(anim_time * 1.2) * 4.0
	draw_calculated_patch_lattice(canvas, build_center, charge_t, anim_time)

	# Phase 2: repair energy travels back from TODO/lattice into the enemy.
	var stream_start := build_center
	var stream_end := owner
	var stream_front := stream_start.lerp(stream_end, release_t)
	canvas.draw_line(stream_start, stream_end, Color(PATCH_GREEN.r, PATCH_GREEN.g, PATCH_GREEN.b, 0.055 + charge_t * 0.06), 1.0, true)
	if release_t > 0.0:
		canvas.draw_line(stream_start, stream_front, Color(PATCH_GREEN.r, PATCH_GREEN.g, PATCH_GREEN.b, 0.42 * release_t), 3.0, true)
		canvas.draw_line(stream_start + Vector2(0.0, -5.0), stream_front + Vector2(0.0, -5.0), Color(PATCH_WHITE.r, PATCH_WHITE.g, PATCH_WHITE.b, 0.22 * release_t), 1.0, true)
		canvas.draw_line(stream_start + Vector2(0.0, 5.0), stream_front + Vector2(0.0, 5.0), Color(PATCH_RED.r, PATCH_RED.g, PATCH_RED.b, 0.18 * release_t), 1.0, true)

		for i in range(5):
			var bead_t = clamp(release_t - float(i) * 0.08, 0.0, 1.0)
			var bead := stream_start.lerp(stream_end, bead_t)
			bead.y += sin(anim_time * 8.0 + float(i) * 1.7) * 4.0
			canvas.draw_circle(bead, 2.0 + pulse * 1.4, Color(PATCH_GREEN.r, PATCH_GREEN.g, PATCH_GREEN.b, 0.36 * release_t))

	# Final healing read: patch panels flicker around the enemy hull.
	if progress > 0.78:
		var finish_t := smoothstep(0.78, 1.0, progress)
		draw_hull_patch_bloom(canvas, owner, finish_t, anim_time)

	return true


func draw_calculated_patch_lattice(canvas: Control, center: Vector2, charge_t: float, anim_time: float) -> void:
	var alpha := 0.12 + charge_t * 0.32
	var size := 18.0 + charge_t * 18.0
	var pulse := 0.5 + 0.5 * sin(anim_time * 10.0)

	# Square solver frame, different from Focus Lance's offensive reticle.
	var half := size + pulse * 2.0
	var rect := Rect2(center - Vector2(half, half), Vector2(half * 2.0, half * 2.0))
	canvas.draw_rect(rect, Color(PATCH_RED.r, PATCH_RED.g, PATCH_RED.b, alpha * 0.20), false, 1.0, true)

	for i in range(3):
		var offset := -half + float(i + 1) * (half * 2.0 / 4.0)
		canvas.draw_line(Vector2(center.x - half, center.y + offset), Vector2(center.x + half, center.y + offset), Color(PATCH_GREEN.r, PATCH_GREEN.g, PATCH_GREEN.b, alpha * 0.26), 1.0, true)
		canvas.draw_line(Vector2(center.x + offset, center.y - half), Vector2(center.x + offset, center.y + half), Color(PATCH_WHITE.r, PATCH_WHITE.g, PATCH_WHITE.b, alpha * 0.16), 1.0, true)

	var spin := anim_time * (0.7 + charge_t * 0.5)
	for i in range(4):
		var a := spin + float(i) * TAU / 4.0
		var pos := center + Vector2(cos(a), sin(a)) * (half + 8.0)
		draw_patch_cell(canvas, pos, 5.0 + charge_t * 3.0, a, alpha * 0.85)

	canvas.draw_circle(center, 5.0 + charge_t * 5.0 + pulse * 2.0, Color(PATCH_GREEN.r, PATCH_GREEN.g, PATCH_GREEN.b, 0.08 + charge_t * 0.14))


func draw_hull_patch_bloom(canvas: Control, center: Vector2, finish_t: float, anim_time: float) -> void:
	var alpha = clamp(finish_t, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(anim_time * 18.0)

	for i in range(7):
		var t := float(i) / 7.0
		var angle := anim_time * 0.45 + t * TAU
		var radius := 24.0 + float(i % 3) * 8.0 + finish_t * 8.0
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		var cell_alpha = (0.16 + 0.18 * finish_t) * alpha
		draw_patch_cell(canvas, pos, 4.0 + float(i % 2) * 1.5 + pulse, angle, cell_alpha)

	# Short, readable hull-confirmation flashes.
	for i in range(4):
		var y := -16.0 + float(i) * 10.0
		var x0 := -28.0 + sin(anim_time * 4.0 + float(i)) * 3.0
		var p1 := center + Vector2(x0, y)
		var p2 := p1 + Vector2(18.0 + pulse * 5.0, 0.0)
		canvas.draw_line(p1, p2, Color(PATCH_GREEN.r, PATCH_GREEN.g, PATCH_GREEN.b, 0.28 * alpha), 2.0, true)
		canvas.draw_line(p1 + Vector2(2.0, -2.0), p2 + Vector2(-2.0, -2.0), Color(PATCH_WHITE.r, PATCH_WHITE.g, PATCH_WHITE.b, 0.14 * alpha), 1.0, true)

	canvas.draw_circle(center, 38.0 + pulse * 6.0, Color(PATCH_GREEN.r, PATCH_GREEN.g, PATCH_GREEN.b, 0.08 * alpha))
	canvas.draw_circle(center, 52.0 + pulse * 7.0, Color(PATCH_RED.r, PATCH_RED.g, PATCH_RED.b, 0.035 * alpha))


func draw_patch_cell(canvas: Control, center: Vector2, size: float, angle: float, alpha: float) -> void:
	var c1 := center + rotated(Vector2(-size, -size * 0.65), angle)
	var c2 := center + rotated(Vector2(size, -size * 0.65), angle)
	var c3 := center + rotated(Vector2(size * 0.78, size * 0.65), angle)
	var c4 := center + rotated(Vector2(-size * 0.78, size * 0.65), angle)
	var points := PackedVector2Array([c1, c2, c3, c4])
	canvas.draw_colored_polygon(points, Color(PATCH_GREEN.r, PATCH_GREEN.g, PATCH_GREEN.b, alpha * 0.38))
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	canvas.draw_polyline(outline, Color(PATCH_WHITE.r, PATCH_WHITE.g, PATCH_WHITE.b, alpha * 0.72), 1.0, true)
	canvas.draw_line(center + rotated(Vector2(-size * 0.45, 0.0), angle), center + rotated(Vector2(size * 0.45, 0.0), angle), Color(PATCH_RED.r, PATCH_RED.g, PATCH_RED.b, alpha * 0.56), 1.0, true)
	canvas.draw_line(center + rotated(Vector2(0.0, -size * 0.36), angle), center + rotated(Vector2(0.0, size * 0.36), angle), Color(PATCH_WHITE.r, PATCH_WHITE.g, PATCH_WHITE.b, alpha * 0.32), 1.0, true)


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
