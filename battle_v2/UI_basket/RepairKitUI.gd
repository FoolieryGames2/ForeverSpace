extends RefCounted

class_name BattleV2RepairKitUI

# Visual-only handler for player repair kit / Field Repair Spray MK1.
# Safe contract: this script only draws. It never changes battle state, repair amount, TODO timing, inventory, or cooldowns.

const ITEM_IDS := ["field_repair_spray_mk1", "repair_kit"]
const BLOCKED_SMART_GUY_ID := "smart_guy_patch_cell"
const ACTION_ID := "repair_ship"
const REPAIR_GREEN := Color(0.18, 1.0, 0.55, 1.0)
const REPAIR_MINT := Color(0.68, 1.0, 0.84, 1.0)
const REPAIR_GOLD := Color(1.0, 0.82, 0.30, 1.0)
const REPAIR_WHITE := Color(0.96, 1.0, 0.94, 1.0)
const REPAIR_BLUE := Color(0.20, 0.66, 1.0, 1.0)


func matches_packet(packet: Dictionary) -> bool:
	var item_id := str(packet.get("item_id", "")).strip_edges().to_lower()
	if item_id == BLOCKED_SMART_GUY_ID:
		return false
	if ITEM_IDS.has(item_id):
		return true

	var item_name := str(packet.get("item_name", packet.get("display_name", packet.get("display_text", "")))).strip_edges().to_lower()
	if item_name.find("field repair spray") >= 0 or item_name == "repair kit":
		return true
	if item_name.find("smart guy patch cell") >= 0:
		return false

	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	if action_id == ACTION_ID and string_array_has(packet.get("labels", []), "smart_guy_item"):
		return false
	if action_id == ACTION_ID and (item_id == "" or ITEM_IDS.has(item_id)):
		return true

	var group := str(packet.get("consumable_group", packet.get("event_group", ""))).strip_edges().to_lower()
	if group == "repair" and string_array_has(packet.get("labels", []), "repair_hull") and not string_array_has(packet.get("labels", []), "smart_guy_item"):
		return true
	if string_array_has(packet.get("labels", []), "consumable_group_repair") and not string_array_has(packet.get("labels", []), "smart_guy_item"):
		return true
	return false


func draw_ready_overlay(canvas: Control, anchors: Dictionary, unit_state: Dictionary, active_events: Array, anim_time: float) -> bool:
	var player_state := get_side_state(unit_state, "player")
	var loaded_id := str(player_state.get("loaded_consumable_id", "")).strip_edges().to_lower()
	var loaded_state := str(player_state.get("loaded_consumable_state", "none")).strip_edges().to_lower()
	if not ITEM_IDS.has(loaded_id):
		return false
	if loaded_state == "none" or loaded_state == "loading" or loaded_state == "executing":
		return false

	var actor_rect := get_anchor_rect(anchors, "player_actor")
	if actor_rect.size == Vector2.ZERO:
		return true

	var center := actor_rect.position + actor_rect.size * 0.5
	var pulse := 0.5 + 0.5 * sin(anim_time * 5.5)
	var sweep := anim_time * 0.72

	# Ready read: repair foam cartridge armed around the player, not a target box.
	for ring in range(3):
		var r := 35.0 + float(ring) * 9.0 + pulse * 3.0
		var alpha := 0.12 - float(ring) * 0.022
		canvas.draw_arc(center, r, sweep + float(ring) * 0.62, sweep + float(ring) * 0.62 + TAU * 0.22, 48, Color(REPAIR_GREEN.r, REPAIR_GREEN.g, REPAIR_GREEN.b, alpha), 1.7, true)
		canvas.draw_arc(center, r + 3.0, -sweep + float(ring) * 0.48, -sweep + float(ring) * 0.48 + TAU * 0.12, 32, Color(REPAIR_GOLD.r, REPAIR_GOLD.g, REPAIR_GOLD.b, alpha * 0.82), 1.1, true)

	for i in range(5):
		var angle := -anim_time * 1.2 + float(i) * TAU / 5.0
		var p := center + Vector2(cos(angle), sin(angle)) * (48.0 + pulse * 3.0)
		draw_repair_nozzle(canvas, p, angle + PI * 0.5, 0.44 + pulse * 0.12)

	return true


func draw_action_click(canvas: Control, packet: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(packet):
		return false

	var age := float(packet.get("age", 0.0))
	var duration = max(float(packet.get("duration", 0.72)), 0.01)
	var t = clamp(age / duration, 0.0, 1.0)
	var alpha = 1.0 - t

	var actor_rect := get_anchor_rect(anchors, "player_actor")
	var action_rect := get_anchor_rect(anchors, "player_action")
	if actor_rect.size == Vector2.ZERO:
		return true

	var center := actor_rect.position + actor_rect.size * 0.5
	var start := action_rect.position + action_rect.size * 0.5 if action_rect.size != Vector2.ZERO else center + Vector2(0.0, 86.0)
	var travel := start.lerp(center, ease_out_cubic(t))
	var pulse := 0.5 + 0.5 * sin(anim_time * 17.0 + t * 8.0)

	canvas.draw_line(start, travel, Color(REPAIR_GREEN.r, REPAIR_GREEN.g, REPAIR_GREEN.b, 0.20 * alpha), 2.0, true)
	canvas.draw_line(start + Vector2(0.0, -4.0), travel + Vector2(0.0, -4.0), Color(REPAIR_GOLD.r, REPAIR_GOLD.g, REPAIR_GOLD.b, 0.14 * alpha), 1.0, true)
	draw_repair_nozzle(canvas, travel, anim_time * 1.8, 0.72 * alpha)

	# Click feedback blooms at the owner so the user reads this as self-support.
	canvas.draw_circle(center, 22.0 + t * 26.0, Color(REPAIR_GREEN.r, REPAIR_GREEN.g, REPAIR_GREEN.b, 0.10 * alpha))
	canvas.draw_circle(center, 12.0 + pulse * 4.0, Color(REPAIR_MINT.r, REPAIR_MINT.g, REPAIR_MINT.b, 0.08 * alpha))
	return true


func draw_todo_event(canvas: Control, event_summary: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(event_summary):
		return false

	var progress = clamp(float(event_summary.get("progress", 0.0)), 0.0, 1.0)
	var actor_rect := get_anchor_rect(anchors, "player_actor")
	var todo_rect := get_anchor_rect(anchors, "todo")
	var lane_rect := get_anchor_rect(anchors, "player_lane")
	if actor_rect.size == Vector2.ZERO or todo_rect.size == Vector2.ZERO:
		return true

	var owner := actor_rect.position + actor_rect.size * 0.5
	if lane_rect.size != Vector2.ZERO:
		owner.y = lane_rect.position.y + lane_rect.size.y * 0.5
	var todo := todo_rect.position + todo_rect.size * 0.5
	var pulse := 0.5 + 0.5 * sin(anim_time * 10.5)

	# Repair reads backwards: TODO prepares the kit, then foam/patch effect returns to the ship.
	var charge_t := smoothstep(0.0, 0.72, progress)
	var finish_t := smoothstep(0.72, 1.0, progress)
	var mist_hub := todo.lerp(owner, 0.34)
	mist_hub.y += sin(anim_time * 1.5) * 5.0

	draw_repair_mist_hub(canvas, mist_hub, charge_t, anim_time)

	if finish_t > 0.0:
		var stream_front := mist_hub.lerp(owner, ease_out_cubic(finish_t))
		canvas.draw_line(mist_hub, stream_front, Color(REPAIR_GREEN.r, REPAIR_GREEN.g, REPAIR_GREEN.b, 0.42 * finish_t), 4.0, true)
		canvas.draw_line(mist_hub + Vector2(0.0, -5.0), stream_front + Vector2(0.0, -5.0), Color(REPAIR_MINT.r, REPAIR_MINT.g, REPAIR_MINT.b, 0.26 * finish_t), 1.3, true)
		canvas.draw_line(mist_hub + Vector2(0.0, 5.0), stream_front + Vector2(0.0, 5.0), Color(REPAIR_GOLD.r, REPAIR_GOLD.g, REPAIR_GOLD.b, 0.18 * finish_t), 1.1, true)

		for i in range(7):
			var bead_t = clamp(finish_t - float(i) * 0.055, 0.0, 1.0)
			var bead := mist_hub.lerp(owner, bead_t)
			bead.y += sin(anim_time * 8.0 + float(i) * 0.9) * (3.0 + finish_t * 3.0)
			canvas.draw_circle(bead, 2.2 + pulse * 1.4, Color(REPAIR_MINT.r, REPAIR_MINT.g, REPAIR_MINT.b, 0.32 * finish_t))

	if progress > 0.80:
		draw_hull_patch_finish(canvas, owner, smoothstep(0.80, 1.0, progress), anim_time)

	return true


func draw_repair_mist_hub(canvas: Control, center: Vector2, charge_t: float, anim_time: float) -> void:
	var alpha := 0.10 + charge_t * 0.28
	var pulse := 0.5 + 0.5 * sin(anim_time * 9.0)
	for i in range(3):
		var r := 13.0 + charge_t * 18.0 + float(i) * 8.0 + pulse * 2.0
		canvas.draw_arc(center, r, anim_time * (0.7 + float(i) * 0.12), anim_time * (0.7 + float(i) * 0.12) + TAU * (0.18 + charge_t * 0.12), 42, Color(REPAIR_GREEN.r, REPAIR_GREEN.g, REPAIR_GREEN.b, alpha - float(i) * 0.032), 1.6, true)
		canvas.draw_arc(center, r + 4.0, -anim_time * (0.46 + float(i) * 0.08), -anim_time * (0.46 + float(i) * 0.08) + TAU * 0.10, 28, Color(REPAIR_GOLD.r, REPAIR_GOLD.g, REPAIR_GOLD.b, alpha * 0.58), 1.0, true)

	for i in range(8):
		var a := anim_time * 1.2 + float(i) * TAU / 8.0
		var p := center + Vector2(cos(a), sin(a)) * (10.0 + charge_t * 22.0 + sin(anim_time * 3.0 + float(i)) * 2.0)
		canvas.draw_circle(p, 1.8 + charge_t * 1.4, Color(REPAIR_MINT.r, REPAIR_MINT.g, REPAIR_MINT.b, alpha * 0.74))

	canvas.draw_circle(center, 5.0 + pulse * 3.0 + charge_t * 3.0, Color(REPAIR_WHITE.r, REPAIR_WHITE.g, REPAIR_WHITE.b, 0.08 + charge_t * 0.13))


func draw_hull_patch_finish(canvas: Control, center: Vector2, finish_t: float, anim_time: float) -> void:
	var alpha = clamp(finish_t, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(anim_time * 14.0)
	for i in range(5):
		var y := -18.0 + float(i) * 9.0
		var x := -30.0 + sin(anim_time * 2.8 + float(i) * 0.7) * 4.0
		var p1 := center + Vector2(x, y)
		var p2 := p1 + Vector2(22.0 + pulse * 4.0, 0.0)
		canvas.draw_line(p1, p2, Color(REPAIR_GREEN.r, REPAIR_GREEN.g, REPAIR_GREEN.b, 0.34 * alpha), 2.2, true)
		canvas.draw_line(p1 + Vector2(2.0, -2.0), p2 + Vector2(-2.0, -2.0), Color(REPAIR_WHITE.r, REPAIR_WHITE.g, REPAIR_WHITE.b, 0.18 * alpha), 1.0, true)

	for plate in range(4):
		var angle := anim_time * 0.42 + float(plate) * TAU / 4.0
		var pos := center + Vector2(cos(angle), sin(angle)) * (34.0 + float(plate % 2) * 7.0)
		draw_repair_plate(canvas, pos, angle, 0.34 * alpha)

	canvas.draw_circle(center, 42.0 + pulse * 8.0, Color(REPAIR_GREEN.r, REPAIR_GREEN.g, REPAIR_GREEN.b, 0.08 * alpha))


func draw_repair_nozzle(canvas: Control, center: Vector2, angle: float, alpha: float) -> void:
	var size := 7.0
	var points := PackedVector2Array([
		center + rotated(Vector2(size, 0.0), angle),
		center + rotated(Vector2(-size * 0.55, -size * 0.65), angle),
		center + rotated(Vector2(-size * 0.30, 0.0), angle),
		center + rotated(Vector2(-size * 0.55, size * 0.65), angle)
	])
	canvas.draw_colored_polygon(points, Color(REPAIR_GREEN.r, REPAIR_GREEN.g, REPAIR_GREEN.b, 0.26 * alpha))
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	canvas.draw_polyline(outline, Color(REPAIR_MINT.r, REPAIR_MINT.g, REPAIR_MINT.b, 0.62 * alpha), 1.0, true)
	canvas.draw_circle(center + rotated(Vector2(size * 0.42, 0.0), angle), 2.0, Color(REPAIR_GOLD.r, REPAIR_GOLD.g, REPAIR_GOLD.b, 0.58 * alpha))


func draw_repair_plate(canvas: Control, center: Vector2, angle: float, alpha: float) -> void:
	var w := 10.0
	var h := 4.5
	var points := PackedVector2Array([
		center + rotated(Vector2(-w, -h), angle),
		center + rotated(Vector2(w, -h), angle),
		center + rotated(Vector2(w, h), angle),
		center + rotated(Vector2(-w, h), angle)
	])
	canvas.draw_colored_polygon(points, Color(REPAIR_GREEN.r, REPAIR_GREEN.g, REPAIR_GREEN.b, alpha * 0.38))
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	canvas.draw_polyline(outline, Color(REPAIR_WHITE.r, REPAIR_WHITE.g, REPAIR_WHITE.b, alpha * 0.72), 1.0, true)


func get_side_state(unit_state: Dictionary, side: String) -> Dictionary:
	var data = unit_state.get(side, {})
	if typeof(data) == TYPE_DICTIONARY:
		return data
	return {}


func get_anchor_rect(anchors: Dictionary, key: String) -> Rect2:
	var value = anchors.get(key, Rect2())
	if typeof(value) == TYPE_RECT2:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return Rect2(value.get("position", Vector2.ZERO), value.get("size", Vector2.ZERO))
	return Rect2()


func rotated(v: Vector2, angle: float) -> Vector2:
	return Vector2(v.x * cos(angle) - v.y * sin(angle), v.x * sin(angle) + v.y * cos(angle))


func ease_out_cubic(t: float) -> float:
	var clean_t = clamp(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - clean_t, 3.0)


func string_array_has(value, needle: String) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var clean_needle := needle.strip_edges().to_lower()
	for entry in value:
		if str(entry).strip_edges().to_lower() == clean_needle:
			return true
	return false
