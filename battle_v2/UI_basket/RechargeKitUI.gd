extends RefCounted

class_name BattleV2RechargeKitUI

# Visual-only handler for player recharge kit / Emergency Capacitor Cell MK2.
# Safe contract: this script only draws. It never changes battle state, energy amount, TODO timing, inventory, or cooldowns.

const ITEM_IDS := ["emergency_capacitor_cell_mk2", "recharge_kit"]
const ACTION_ID := "recharge_energy"
const CAP_BLUE := Color(0.10, 0.70, 1.0, 1.0)
const CAP_CORE := Color(0.66, 0.96, 1.0, 1.0)
const CAP_WHITE := Color(0.94, 1.0, 1.0, 1.0)
const CAP_VIOLET := Color(0.50, 0.36, 1.0, 1.0)
const CAP_GOLD := Color(1.0, 0.86, 0.36, 1.0)


func matches_packet(packet: Dictionary) -> bool:
	var item_id := str(packet.get("item_id", "")).strip_edges().to_lower()
	if ITEM_IDS.has(item_id):
		return true

	var item_name := str(packet.get("item_name", packet.get("display_name", packet.get("display_text", "")))).strip_edges().to_lower()
	if item_name.find("emergency capacitor cell") >= 0 or item_name == "recharge kit" or item_name.find("recharge") >= 0:
		return true

	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	if action_id == ACTION_ID and (item_id == "" or ITEM_IDS.has(item_id)):
		return true

	var group := str(packet.get("consumable_group", packet.get("event_group", ""))).strip_edges().to_lower()
	if group == "recharge" or group == "energy_restore":
		return true
	if string_array_has(packet.get("labels", []), "consumable_group_recharge") or string_array_has(packet.get("labels", []), "energy_restore"):
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
	var pulse := 0.5 + 0.5 * sin(anim_time * 7.0)

	# Ready read: a charged capacitor cage around the player.
	for ring in range(3):
		var radius := 33.0 + float(ring) * 10.0 + pulse * 2.5
		var start := anim_time * (0.80 + float(ring) * 0.16) + float(ring) * 0.9
		canvas.draw_arc(center, radius, start, start + TAU * 0.16, 42, Color(CAP_BLUE.r, CAP_BLUE.g, CAP_BLUE.b, 0.15 - float(ring) * 0.025), 1.8, true)
		canvas.draw_arc(center, radius + 3.0, -start, -start + TAU * 0.09, 28, Color(CAP_WHITE.r, CAP_WHITE.g, CAP_WHITE.b, 0.09 - float(ring) * 0.014), 1.0, true)

	for i in range(4):
		var angle := anim_time * 1.45 + float(i) * TAU / 4.0
		var p := center + Vector2(cos(angle), sin(angle)) * (45.0 + pulse * 3.0)
		draw_capacitor_cell(canvas, p, angle + PI * 0.5, 0.50 + pulse * 0.16)
		var inner := center + Vector2(cos(angle), sin(angle)) * 25.0
		draw_lightning(canvas, p, inner, 0.18 + pulse * 0.10, anim_time + float(i))

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
	var travel := start.lerp(center, ease_in_out(t))
	var pulse := 0.5 + 0.5 * sin(anim_time * 24.0 + t * 12.0)

	canvas.draw_line(start, travel, Color(CAP_BLUE.r, CAP_BLUE.g, CAP_BLUE.b, 0.22 * alpha), 2.4, true)
	canvas.draw_line(start + Vector2(0.0, -5.0), travel + Vector2(0.0, -5.0), Color(CAP_WHITE.r, CAP_WHITE.g, CAP_WHITE.b, 0.14 * alpha), 1.1, true)
	draw_capacitor_cell(canvas, travel, anim_time * 2.3, 0.76 * alpha)
	canvas.draw_circle(center, 22.0 + t * 26.0, Color(CAP_BLUE.r, CAP_BLUE.g, CAP_BLUE.b, 0.10 * alpha))
	canvas.draw_circle(center, 8.0 + pulse * 5.0, Color(CAP_CORE.r, CAP_CORE.g, CAP_CORE.b, 0.16 * alpha))
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
	var pulse := 0.5 + 0.5 * sin(anim_time * 15.0)

	# Recharge feels like a capacitor being wound tight, then dumped into the player core.
	var wind_t := smoothstep(0.0, 0.70, progress)
	var dump_t := smoothstep(0.70, 1.0, progress)
	var capacitor_center := todo.lerp(owner, 0.40)
	capacitor_center.y += sin(anim_time * 1.1) * 3.0

	draw_capacitor_chamber(canvas, capacitor_center, wind_t, anim_time)

	if dump_t > 0.0:
		var stream_front := capacitor_center.lerp(owner, ease_in_out(dump_t))
		canvas.draw_line(capacitor_center, stream_front, Color(CAP_BLUE.r, CAP_BLUE.g, CAP_BLUE.b, 0.48 * dump_t), 4.4, true)
		canvas.draw_line(capacitor_center + Vector2(0.0, -5.0), stream_front + Vector2(0.0, -5.0), Color(CAP_WHITE.r, CAP_WHITE.g, CAP_WHITE.b, 0.30 * dump_t), 1.4, true)
		canvas.draw_line(capacitor_center + Vector2(0.0, 5.0), stream_front + Vector2(0.0, 5.0), Color(CAP_VIOLET.r, CAP_VIOLET.g, CAP_VIOLET.b, 0.20 * dump_t), 1.3, true)

		for i in range(5):
			var bolt_t = clamp(dump_t - float(i) * 0.07, 0.0, 1.0)
			var bolt_start := capacitor_center.lerp(owner, bolt_t)
			var bolt_end := bolt_start + Vector2(12.0 * sin(anim_time * 8.0 + float(i)), 5.0 * cos(anim_time * 9.0 + float(i)))
			draw_lightning(canvas, bolt_start, bolt_end, 0.24 * dump_t, anim_time + float(i) * 1.7)

	if progress > 0.80:
		draw_energy_core_finish(canvas, owner, smoothstep(0.80, 1.0, progress), anim_time)

	return true


func draw_capacitor_chamber(canvas: Control, center: Vector2, wind_t: float, anim_time: float) -> void:
	var alpha := 0.10 + wind_t * 0.34
	var pulse := 0.5 + 0.5 * sin(anim_time * 11.0)
	var radius := 15.0 + wind_t * 23.0 + pulse * 2.0

	for i in range(4):
		var angle := anim_time * (0.85 + float(i) * 0.08) + float(i) * TAU / 4.0
		var p := center + Vector2(cos(angle), sin(angle)) * radius
		draw_capacitor_cell(canvas, p, angle + PI * 0.5, alpha)
		draw_lightning(canvas, p, center, alpha * 0.32, anim_time + float(i))

	for ring in range(3):
		var r := radius + float(ring) * 8.0
		canvas.draw_arc(center, r, anim_time * (0.62 + float(ring) * 0.11), anim_time * (0.62 + float(ring) * 0.11) + TAU * (0.18 + wind_t * 0.10), 42, Color(CAP_BLUE.r, CAP_BLUE.g, CAP_BLUE.b, alpha - float(ring) * 0.045), 1.7, true)
		canvas.draw_arc(center, r + 3.0, -anim_time * (0.50 + float(ring) * 0.07), -anim_time * (0.50 + float(ring) * 0.07) + TAU * 0.10, 28, Color(CAP_WHITE.r, CAP_WHITE.g, CAP_WHITE.b, (alpha - float(ring) * 0.050) * 0.52), 1.0, true)

	canvas.draw_circle(center, 6.0 + wind_t * 6.0 + pulse * 3.0, Color(CAP_CORE.r, CAP_CORE.g, CAP_CORE.b, 0.10 + wind_t * 0.18))


func draw_energy_core_finish(canvas: Control, center: Vector2, finish_t: float, anim_time: float) -> void:
	var alpha = clamp(finish_t, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(anim_time * 18.0)
	for ring in range(4):
		var radius := 20.0 + float(ring) * 13.0 + pulse * 4.0
		canvas.draw_arc(center, radius, anim_time * (1.1 + float(ring) * 0.10), anim_time * (1.1 + float(ring) * 0.10) + TAU * (0.20 + finish_t * 0.12), 52, Color(CAP_BLUE.r, CAP_BLUE.g, CAP_BLUE.b, (0.18 - float(ring) * 0.026) * alpha), 2.0, true)
		canvas.draw_arc(center, radius + 4.0, -anim_time * (0.9 + float(ring) * 0.08), -anim_time * (0.9 + float(ring) * 0.08) + TAU * 0.10, 34, Color(CAP_WHITE.r, CAP_WHITE.g, CAP_WHITE.b, (0.10 - float(ring) * 0.014) * alpha), 1.0, true)

	for i in range(7):
		var a := anim_time * 2.0 + float(i) * TAU / 7.0
		var p1 := center + Vector2(cos(a), sin(a)) * (18.0 + pulse * 3.0)
		var p2 := center + Vector2(cos(a + 0.28), sin(a + 0.28)) * (42.0 + pulse * 6.0)
		draw_lightning(canvas, p1, p2, 0.20 * alpha, anim_time + float(i) * 0.33)

	canvas.draw_circle(center, 10.0 + pulse * 7.0, Color(CAP_CORE.r, CAP_CORE.g, CAP_CORE.b, 0.20 * alpha))
	canvas.draw_circle(center, 50.0 + pulse * 8.0, Color(CAP_BLUE.r, CAP_BLUE.g, CAP_BLUE.b, 0.07 * alpha))


func draw_capacitor_cell(canvas: Control, center: Vector2, angle: float, alpha: float) -> void:
	var w := 8.0
	var h := 5.0
	var points := PackedVector2Array([
		center + rotated(Vector2(-w, -h), angle),
		center + rotated(Vector2(w, -h), angle),
		center + rotated(Vector2(w, h), angle),
		center + rotated(Vector2(-w, h), angle)
	])
	canvas.draw_colored_polygon(points, Color(CAP_BLUE.r, CAP_BLUE.g, CAP_BLUE.b, alpha * 0.38))
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	canvas.draw_polyline(outline, Color(CAP_CORE.r, CAP_CORE.g, CAP_CORE.b, alpha * 0.78), 1.0, true)
	canvas.draw_line(center + rotated(Vector2(-w * 0.55, 0.0), angle), center + rotated(Vector2(w * 0.55, 0.0), angle), Color(CAP_WHITE.r, CAP_WHITE.g, CAP_WHITE.b, alpha * 0.56), 1.0, true)
	canvas.draw_circle(center + rotated(Vector2(w * 0.15, 0.0), angle), 1.7, Color(CAP_GOLD.r, CAP_GOLD.g, CAP_GOLD.b, alpha * 0.62))


func draw_lightning(canvas: Control, start: Vector2, finish: Vector2, alpha: float, seed: float) -> void:
	var points := PackedVector2Array()
	var dir := finish - start
	var length := dir.length()
	if length <= 0.01:
		return
	var normal := Vector2(-dir.y, dir.x).normalized()
	for i in range(5):
		var t := float(i) / 4.0
		var wobble := sin(seed * 2.1 + float(i) * 1.7) * 4.0 + cos(seed * 1.3 + float(i) * 2.4) * 2.0
		if i == 0 or i == 4:
			wobble = 0.0
		points.append(start.lerp(finish, t) + normal * wobble)
	canvas.draw_polyline(points, Color(CAP_CORE.r, CAP_CORE.g, CAP_CORE.b, alpha), 1.4, true)
	canvas.draw_polyline(points, Color(CAP_BLUE.r, CAP_BLUE.g, CAP_BLUE.b, alpha * 0.52), 3.0, true)


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


func ease_in_out(t: float) -> float:
	var clean_t = clamp(t, 0.0, 1.0)
	return clean_t * clean_t * (3.0 - 2.0 * clean_t)


func string_array_has(value, needle: String) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var clean_needle := needle.strip_edges().to_lower()
	for entry in value:
		if str(entry).strip_edges().to_lower() == clean_needle:
			return true
	return false
