extends RefCounted

class_name BattleV2BreachChargeUI

# Visual-only handler for breach_charge.
# Safe contract: this script only draws. It never changes battle state, damage, TODO timing, cooldowns, ammo, inventory, lock state, or loaded-consumable state.

const ITEM_ID := "breach_charge"
const ITEM_ID_ALT := "breach_charge_mk1"

const BLUE_BODY := Color(0.05, 0.30, 1.0, 1.0)
const BLUE_CORE := Color(0.18, 0.72, 1.0, 1.0)
const BLUE_HOT := Color(0.72, 0.94, 1.0, 1.0)
const RED_FIN := Color(1.0, 0.12, 0.06, 1.0)
const RED_CORE := Color(1.0, 0.38, 0.16, 1.0)
const WARN_YELLOW := Color(1.0, 0.86, 0.30, 1.0)
const SMOKE_BLUE := Color(0.20, 0.34, 1.0, 1.0)


func matches_packet(packet: Dictionary) -> bool:
	var item_id := get_packet_item_id(packet)
	return item_id == ITEM_ID or item_id == ITEM_ID_ALT


func draw_action_click(canvas: Control, packet: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(packet):
		return false

	var event_type := str(packet.get("event_type", packet.get("action_id", ""))).strip_edges().to_lower()
	var is_execute := is_execute_packet(packet) or event_type.find("execute") >= 0 or event_type.find("detonate") >= 0
	if is_execute:
		draw_execute_click_pulse(canvas, packet, anchors, unit_state, anim_time)
	else:
		draw_load_click_pulse(canvas, packet, anchors, unit_state, anim_time)
	return true


func draw_todo_event(canvas: Control, event_summary: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(event_summary):
		return false

	if is_load_packet(event_summary):
		draw_load_todo(canvas, event_summary, anchors, unit_state, anim_time)
		return true

	# breach_charge should normally execute as an explosive packet. If the packet is matched but its event label is odd,
	# prefer the execute read so it never falls through to generic UI during the damage action.
	draw_execute_todo(canvas, event_summary, anchors, unit_state, anim_time)
	return true


func draw_ready_overlay(canvas: Control, anchors: Dictionary, unit_state: Dictionary, active_events: Array, anim_time: float) -> bool:
	var drew := false
	for owner_side in ["player", "enemy"]:
		if not is_breach_loaded_ready(unit_state, owner_side):
			continue
		if has_active_breach_event(active_events, owner_side):
			continue
		if not side_has_good_lock(unit_state, owner_side):
			continue

		var target_side := get_opposite_side(owner_side)
		var target_rect := get_anchor_rect(anchors, target_side + "_actor")
		if target_rect.size == Vector2.ZERO:
			continue
		draw_target_square(canvas, target_rect, owner_side, anim_time)
		drew = true
	return drew


func draw_damage_pulse(canvas: Control, pulse: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(pulse):
		return false

	var age := float(pulse.get("age", 0.0))
	var duration = max(float(pulse.get("duration", 0.82)), 0.01)
	var t = clamp(age / duration, 0.0, 1.0)
	var alpha = 1.0 - t
	var owner_side := clean_side(str(pulse.get("owner_side", pulse.get("source_side", pulse.get("event_side", "player")))))
	if owner_side == "":
		owner_side = "player"
	var target_side := clean_side(str(pulse.get("target_side", "")))
	if target_side == "":
		target_side = get_opposite_side(owner_side)

	var target_rect := get_anchor_rect(anchors, target_side + "_actor")
	if target_rect.size == Vector2.ZERO:
		return true

	var center := target_rect.position + target_rect.size * 0.5
	var dir_sign := 1.0 if target_side == "enemy" else -1.0
	center += Vector2(-dir_sign * 28.0, 0.0)

	var hull_damage := float(pulse.get("hull_damage", 0.0)) + float(pulse.get("overflow_damage", 0.0))
	var shield_damage := float(pulse.get("shield_damage", 0.0))
	var direct_hull := hull_damage > 0.0 and shield_damage <= 0.0
	var seed := int(pulse.get("ui_seed", 9191))
	var blast_scale = 1.0 + clamp((hull_damage + shield_damage) / 80.0, 0.0, 0.65)
	if direct_hull:
		blast_scale += 0.25

	# Flash core.
	var flash := sin((1.0 - t) * PI)
	canvas.draw_circle(center, (22.0 + 32.0 * t) * blast_scale, Color(RED_FIN.r, RED_FIN.g, RED_FIN.b, 0.22 * alpha))
	canvas.draw_circle(center, (12.0 + 22.0 * flash) * blast_scale, Color(BLUE_CORE.r, BLUE_CORE.g, BLUE_CORE.b, 0.18 * alpha))
	canvas.draw_circle(center, (6.0 + 10.0 * flash) * blast_scale, Color(WARN_YELLOW.r, WARN_YELLOW.g, WARN_YELLOW.b, 0.44 * alpha))

	# Random-looking deterministic particle explosion. No actual RNG state is used so redraw is stable.
	var particle_count := 34 if direct_hull else 26
	if hull_damage > 0.0 and shield_damage > 0.0:
		particle_count = 42
	for i in range(particle_count):
		var r1 := pseudo_random(seed, i, 0)
		var r2 := pseudo_random(seed, i, 1)
		var r3 := pseudo_random(seed, i, 2)
		var angle := r1 * TAU + sin(anim_time * 1.5 + float(i)) * 0.08
		var speed = lerp(28.0, 118.0, r2) * blast_scale
		var dist = speed * ease_out_cubic(t)
		var drift = Vector2(cos(angle), sin(angle)) * dist
		var fall := Vector2(0.0, 18.0 * t * t * r3)
		var pos = center + drift + fall
		var particle_color := BLUE_HOT
		if i % 3 == 0:
			particle_color = RED_FIN
		elif i % 3 == 1:
			particle_color = WARN_YELLOW
		var radius = lerp(1.2, 4.6, r3) * (1.0 - t * 0.35)
		canvas.draw_circle(pos, radius + 4.0, Color(particle_color.r, particle_color.g, particle_color.b, 0.055 * alpha))
		canvas.draw_circle(pos, radius, Color(particle_color.r, particle_color.g, particle_color.b, 0.62 * alpha))
		if i % 4 == 0:
			var tail = pos - Vector2(cos(angle), sin(angle)) * (10.0 + r3 * 20.0)
			canvas.draw_line(tail, pos, Color(particle_color.r, particle_color.g, particle_color.b, 0.25 * alpha), 1.4, true)

	# Square shrapnel brackets: this keeps it visually tied to the target-lock square.
	for c in range(4):
		var corner_dir := Vector2(-1.0 if c % 2 == 0 else 1.0, -1.0 if c < 2 else 1.0)
		var p = center + corner_dir * (Vector2(18.0, 18.0) + Vector2(44.0, 28.0) * t)
		canvas.draw_line(p, p + Vector2(corner_dir.x * 10.0, 0.0), Color(BLUE_CORE.r, BLUE_CORE.g, BLUE_CORE.b, 0.32 * alpha), 1.6, true)
		canvas.draw_line(p, p + Vector2(0.0, corner_dir.y * 10.0), Color(RED_FIN.r, RED_FIN.g, RED_FIN.b, 0.28 * alpha), 1.6, true)

	return true


func draw_load_click_pulse(canvas: Control, packet: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> void:
	var owner_side := get_packet_side(packet)
	var actor_rect := get_anchor_rect(anchors, owner_side + "_actor")
	var action_rect := get_anchor_rect(anchors, "player_action")
	if actor_rect.size == Vector2.ZERO:
		return

	var age := float(packet.get("age", 0.0))
	var duration = max(float(packet.get("duration", 0.72)), 0.01)
	var t = clamp(age / duration, 0.0, 1.0)
	var alpha = 1.0 - t
	var center := actor_rect.position + actor_rect.size * 0.5
	var from_pos := action_rect.position + action_rect.size * 0.5 if action_rect.size != Vector2.ZERO else center + Vector2(0.0, 90.0)
	var travel := from_pos.lerp(center, ease_out_cubic(t))

	canvas.draw_line(from_pos, travel, Color(BLUE_BODY.r, BLUE_BODY.g, BLUE_BODY.b, 0.22 * alpha), 1.6, true)
	canvas.draw_circle(center, 42.0 + 32.0 * t, Color(BLUE_CORE.r, BLUE_CORE.g, BLUE_CORE.b, 0.12 * alpha))
	canvas.draw_circle(center, 31.0 + 24.0 * t, Color(RED_FIN.r, RED_FIN.g, RED_FIN.b, 0.09 * alpha))
	canvas.draw_circle(travel, 4.5 + 3.0 * t, Color(WARN_YELLOW.r, WARN_YELLOW.g, WARN_YELLOW.b, 0.74 * alpha))


func draw_execute_click_pulse(canvas: Control, packet: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> void:
	var owner_side := get_packet_side(packet)
	var target_side := get_opposite_side(owner_side)
	var actor_rect := get_anchor_rect(anchors, owner_side + "_actor")
	var target_rect := get_anchor_rect(anchors, target_side + "_actor")
	if actor_rect.size == Vector2.ZERO or target_rect.size == Vector2.ZERO:
		return

	var age := float(packet.get("age", 0.0))
	var duration = max(float(packet.get("duration", 0.72)), 0.01)
	var t = clamp(age / duration, 0.0, 1.0)
	var alpha = 1.0 - t
	var source := actor_rect.position + actor_rect.size * 0.5
	var target := target_rect.position + target_rect.size * 0.5
	var marker := source.lerp(target, t * 0.24)
	canvas.draw_circle(source, 48.0 + 38.0 * t, Color(RED_FIN.r, RED_FIN.g, RED_FIN.b, 0.14 * alpha))
	canvas.draw_circle(source, 30.0 + 24.0 * t, Color(BLUE_BODY.r, BLUE_BODY.g, BLUE_BODY.b, 0.12 * alpha))
	draw_triangle_projectile(canvas, marker, (target - source).normalized(), 0.75 * alpha, 0.72 + t * 0.35, anim_time)


func draw_load_todo(canvas: Control, event_summary: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> void:
	var owner_side := get_packet_side(event_summary)
	var actor_rect := get_anchor_rect(anchors, owner_side + "_actor")
	if actor_rect.size == Vector2.ZERO:
		return

	var center := actor_rect.position + actor_rect.size * 0.5
	var progress = clamp(float(event_summary.get("progress", 0.0)), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(anim_time * 8.5)
	var alpha = 0.36 + progress * 0.34

	# Arming pulse around the user: blue charge ring, red breach warning, and triangle arming ticks.
	for ring in range(4):
		var r = 38.0 + float(ring) * 10.5 + pulse * 4.0 + progress * 10.0
		var color := BLUE_CORE if ring % 2 == 0 else RED_FIN
		canvas.draw_arc(center, r, anim_time * (0.35 + float(ring) * 0.05), anim_time * (0.35 + float(ring) * 0.05) + TAU * (0.22 + progress * 0.18), 54, Color(color.r, color.g, color.b, (0.19 - float(ring) * 0.025) * alpha), 1.8, true)

	for i in range(6):
		var angle := anim_time * 1.25 + float(i) * TAU / 6.0
		var tick_center := center + Vector2(cos(angle), sin(angle)) * (50.0 + pulse * 5.0)
		var tick_dir := (tick_center - center).normalized()
		draw_micro_triangle(canvas, tick_center, tick_dir, Color(BLUE_HOT.r, BLUE_HOT.g, BLUE_HOT.b, 0.62 * alpha), Color(RED_FIN.r, RED_FIN.g, RED_FIN.b, 0.52 * alpha), 0.65 + progress * 0.25)

	# Loading coil stack under the actor, inspired by the supplied breach-charge sprite.
	var base := center + Vector2(-22.0, 43.0)
	for link in range(5):
		var link_t := float(link) / 4.0
		var link_alpha = 0.18 + 0.60 * clamp(progress * 5.0 - float(link), 0.0, 1.0)
		var p := base + Vector2(float(link) * 9.0, sin(anim_time * 7.0 + float(link)) * 2.0)
		canvas.draw_arc(p, 6.0, 0.0, TAU, 18, Color(BLUE_BODY.r, BLUE_BODY.g, BLUE_BODY.b, link_alpha), 1.8, true)
		canvas.draw_arc(p + Vector2(2.0, 0.0), 6.0, 0.0, TAU, 18, Color(BLUE_HOT.r, BLUE_HOT.g, BLUE_HOT.b, link_alpha * 0.52), 1.0, true)


func draw_execute_todo(canvas: Control, event_summary: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> void:
	var owner_side := get_packet_side(event_summary)
	var target_side := get_opposite_side(owner_side)
	var source_actor := get_anchor_rect(anchors, owner_side + "_actor")
	var target_actor := get_anchor_rect(anchors, target_side + "_actor")
	var lane_rect := get_anchor_rect(anchors, owner_side + "_lane")
	if source_actor.size == Vector2.ZERO or target_actor.size == Vector2.ZERO or lane_rect.size == Vector2.ZERO:
		return

	var progress = clamp(float(event_summary.get("progress", 0.0)), 0.0, 1.0)
	var dir_sign := 1.0 if owner_side == "player" else -1.0
	var source := source_actor.position + source_actor.size * 0.5 + Vector2(dir_sign * 46.0, 0.0)
	var target := target_actor.position + target_actor.size * 0.5 + Vector2(-dir_sign * 48.0, 0.0)
	var lane_y := lane_rect.position.y + lane_rect.size.y * 0.5
	source.y = lane_y
	target.y = lane_y

	var launch_t = clamp((progress - 0.16) / 0.74, 0.0, 1.0)
	var head_t := ease_in_out(launch_t)
	var head := source.lerp(target, head_t)
	var path_dir := (target - source).normalized()
	if path_dir == Vector2.ZERO:
		path_dir = Vector2(dir_sign, 0.0)
	var wobble = Vector2(-path_dir.y, path_dir.x) * sin(anim_time * 9.0 + progress * 6.0) * (5.0 * launch_t)
	head += wobble

	# Pre-launch execution pulse at the user's ship.
	if progress < 0.28:
		var charge_alpha = 1.0 - clamp(progress / 0.28, 0.0, 1.0)
		canvas.draw_circle(source, 54.0 + progress * 80.0, Color(RED_FIN.r, RED_FIN.g, RED_FIN.b, 0.18 * charge_alpha))
		canvas.draw_circle(source, 32.0 + progress * 62.0, Color(BLUE_BODY.r, BLUE_BODY.g, BLUE_BODY.b, 0.14 * charge_alpha))

	# Trail and smoke wake.
	for i in range(9):
		var step_t = clamp(head_t - float(i) * 0.035, 0.0, 1.0)
		var trail_pos := source.lerp(target, step_t)
		trail_pos += Vector2(-path_dir.y, path_dir.x) * sin(anim_time * 8.0 + float(i) * 1.8) * (2.0 + float(i) * 0.4)
		var trail_alpha = (1.0 - float(i) / 9.0) * launch_t
		var trail_color := BLUE_CORE if i % 2 == 0 else RED_FIN
		canvas.draw_circle(trail_pos, 8.5 + float(i) * 1.6, Color(SMOKE_BLUE.r, SMOKE_BLUE.g, SMOKE_BLUE.b, 0.045 * trail_alpha))
		canvas.draw_circle(trail_pos, 2.8 + float(i) * 0.34, Color(trail_color.r, trail_color.g, trail_color.b, 0.20 * trail_alpha))

	# Target lock square remains visible while the charge is in flight.
	draw_target_square(canvas, target_actor, owner_side, anim_time, 0.55 + launch_t * 0.35)

	# Triangle projectile with red breach fin.
	if progress >= 0.12:
		draw_triangle_projectile(canvas, head, path_dir, 0.95, 1.0 + launch_t * 0.22, anim_time)

	# Last-moment impact flare. The real random damage explosion is drawn from pulse_damage when battle resolution reports it.
	if progress >= 0.90:
		var hit_alpha = clamp((progress - 0.90) / 0.10, 0.0, 1.0)
		draw_pre_damage_bloom(canvas, target, path_dir, anim_time, hit_alpha)


func draw_target_square(canvas: Control, target_rect: Rect2, owner_side: String, anim_time: float, alpha_scale: float = 1.0) -> void:
	var center := target_rect.position + target_rect.size * 0.5
	var pulse := 0.5 + 0.5 * sin(anim_time * 5.5)
	var half := Vector2(target_rect.size.x * 0.46 + pulse * 5.0, target_rect.size.y * 0.42 + pulse * 5.0)
	var alpha := 0.48 * alpha_scale + 0.20 * pulse * alpha_scale
	var corner_len := 18.0 + pulse * 5.0
	var corners := [
		Vector2(-1.0, -1.0),
		Vector2(1.0, -1.0),
		Vector2(1.0, 1.0),
		Vector2(-1.0, 1.0)
	]
	for c in corners:
		var p := center + Vector2(c.x * half.x, c.y * half.y)
		canvas.draw_line(p, p + Vector2(-c.x * corner_len, 0.0), Color(BLUE_CORE.r, BLUE_CORE.g, BLUE_CORE.b, alpha), 2.0, true)
		canvas.draw_line(p, p + Vector2(0.0, -c.y * corner_len), Color(BLUE_CORE.r, BLUE_CORE.g, BLUE_CORE.b, alpha), 2.0, true)
		canvas.draw_circle(p, 2.6 + pulse * 1.2, Color(RED_FIN.r, RED_FIN.g, RED_FIN.b, 0.68 * alpha_scale))

	canvas.draw_line(center + Vector2(-half.x * 0.32, 0.0), center + Vector2(half.x * 0.32, 0.0), Color(WARN_YELLOW.r, WARN_YELLOW.g, WARN_YELLOW.b, 0.20 * alpha_scale), 1.0, true)
	canvas.draw_line(center + Vector2(0.0, -half.y * 0.32), center + Vector2(0.0, half.y * 0.32), Color(WARN_YELLOW.r, WARN_YELLOW.g, WARN_YELLOW.b, 0.20 * alpha_scale), 1.0, true)
	canvas.draw_circle(center, 5.0 + pulse * 2.0, Color(RED_FIN.r, RED_FIN.g, RED_FIN.b, 0.20 * alpha_scale))


func draw_triangle_projectile(canvas: Control, head: Vector2, path_dir: Vector2, alpha: float, scale: float, anim_time: float) -> void:
	if path_dir == Vector2.ZERO:
		path_dir = Vector2.RIGHT
	var perp := Vector2(-path_dir.y, path_dir.x)
	var nose := head + path_dir * (18.0 * scale)
	var left := head - path_dir * (14.0 * scale) - perp * (13.0 * scale)
	var right := head - path_dir * (8.0 * scale) + perp * (12.0 * scale)
	var body := PackedVector2Array([nose, left, right])
	canvas.draw_colored_polygon(body, Color(BLUE_BODY.r, BLUE_BODY.g, BLUE_BODY.b, 0.56 * alpha))
	canvas.draw_polyline(close_points(body), Color(BLUE_HOT.r, BLUE_HOT.g, BLUE_HOT.b, 0.82 * alpha), 1.5, true)

	var fin := PackedVector2Array([
		head - path_dir * (3.0 * scale) + perp * (2.0 * scale),
		head - path_dir * (19.0 * scale) + perp * (13.0 * scale),
		head - path_dir * (11.0 * scale) + perp * (22.0 * scale)
	])
	canvas.draw_colored_polygon(fin, Color(RED_FIN.r, RED_FIN.g, RED_FIN.b, 0.72 * alpha))
	canvas.draw_polyline(close_points(fin), Color(RED_CORE.r, RED_CORE.g, RED_CORE.b, 0.78 * alpha), 1.2, true)
	canvas.draw_circle(head - path_dir * 9.0, 4.0 + sin(anim_time * 18.0) * 1.4, Color(WARN_YELLOW.r, WARN_YELLOW.g, WARN_YELLOW.b, 0.76 * alpha))


func draw_micro_triangle(canvas: Control, center: Vector2, dir: Vector2, blue: Color, red: Color, scale: float) -> void:
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var body := PackedVector2Array([
		center + dir * 8.0 * scale,
		center - dir * 5.0 * scale - perp * 5.0 * scale,
		center - dir * 3.0 * scale + perp * 5.0 * scale
	])
	canvas.draw_colored_polygon(body, blue)
	var fin := PackedVector2Array([
		center - dir * 2.0 * scale + perp * 1.0 * scale,
		center - dir * 7.0 * scale + perp * 5.0 * scale,
		center - dir * 5.0 * scale + perp * 8.0 * scale
	])
	canvas.draw_colored_polygon(fin, red)


func draw_pre_damage_bloom(canvas: Control, center: Vector2, path_dir: Vector2, anim_time: float, alpha: float) -> void:
	var pulse := 0.5 + 0.5 * sin(anim_time * 20.0)
	canvas.draw_circle(center, 18.0 + pulse * 8.0, Color(RED_FIN.r, RED_FIN.g, RED_FIN.b, 0.16 * alpha))
	canvas.draw_circle(center, 10.0 + pulse * 4.0, Color(WARN_YELLOW.r, WARN_YELLOW.g, WARN_YELLOW.b, 0.22 * alpha))
	for i in range(7):
		var a := float(i) * TAU / 7.0 + anim_time * 0.6
		var p := center + Vector2(cos(a), sin(a)) * (18.0 + pulse * 7.0)
		canvas.draw_line(center, p, Color(BLUE_CORE.r, BLUE_CORE.g, BLUE_CORE.b, 0.18 * alpha), 1.1, true)


func is_load_packet(packet: Dictionary) -> bool:
	var event_type := str(packet.get("event_type", packet.get("action_id", ""))).strip_edges().to_lower()
	var event_group := str(packet.get("event_group", "")).strip_edges().to_lower()
	return event_type == "load_consumable" or event_type.find("load") >= 0 or (event_group == "consumable" and not is_execute_packet(packet))


func is_execute_packet(packet: Dictionary) -> bool:
	var event_type := str(packet.get("event_type", packet.get("action_id", ""))).strip_edges().to_lower()
	var event_group := str(packet.get("event_group", "")).strip_edges().to_lower()
	var damage_type := str(packet.get("damage_type", "")).strip_edges().to_lower()
	var consumable_group := str(packet.get("consumable_group", "")).strip_edges().to_lower()
	return event_type == "execute_explosive" or event_type.find("execute") >= 0 or event_group == "explosive" or consumable_group == "explosive" or damage_type == "explosive"


func is_breach_loaded_ready(unit_state: Dictionary, owner_side: String) -> bool:
	var state := get_unit_state(unit_state, owner_side)
	var loaded_id := str(state.get("loaded_consumable_id", state.get("loaded_consumable", ""))).strip_edges().to_lower()
	var loaded_state := str(state.get("loaded_consumable_state", "none")).strip_edges().to_lower()
	if loaded_id != ITEM_ID and loaded_id != ITEM_ID_ALT:
		return false
	return loaded_state == "ready" or loaded_state == "loaded" or loaded_state == "armed"


func side_has_good_lock(unit_state: Dictionary, owner_side: String) -> bool:
	var state := get_unit_state(unit_state, owner_side)
	if bool(state.get("lock_disabled", false)):
		return false
	if bool(state.get("lock_pending", false)):
		return false
	return bool(state.get("good_lock", state.get("has_good_lock", false)))


func has_active_breach_event(active_events: Array, owner_side: String) -> bool:
	for event_summary in active_events:
		if typeof(event_summary) != TYPE_DICTIONARY:
			continue
		if not matches_packet(event_summary):
			continue
		var side := get_packet_side(event_summary)
		if side == owner_side:
			return true
	return false


func get_packet_item_id(packet: Dictionary) -> String:
	var item_id := str(packet.get("item_id", packet.get("consumable_id", packet.get("weapon_id", "")))).strip_edges().to_lower()
	if item_id != "":
		return item_id
	if typeof(packet.get("data", {})) == TYPE_DICTIONARY:
		var data_payload: Dictionary = packet.get("data", {})
		item_id = str(data_payload.get("item_id", data_payload.get("consumable_id", data_payload.get("weapon_id", "")))).strip_edges().to_lower()
		if item_id != "":
			return item_id
		if typeof(data_payload.get("item_data", {})) == TYPE_DICTIONARY:
			var item_data: Dictionary = data_payload.get("item_data", {})
			return str(item_data.get("item_id", item_data.get("id", ""))).strip_edges().to_lower()
	if typeof(packet.get("item_data", {})) == TYPE_DICTIONARY:
		var direct_item_data: Dictionary = packet.get("item_data", {})
		return str(direct_item_data.get("item_id", direct_item_data.get("id", ""))).strip_edges().to_lower()
	return ""


func get_packet_side(packet: Dictionary) -> String:
	var side := clean_side(str(packet.get("source_side", packet.get("owner_side", packet.get("event_side", "")))))
	if side != "":
		return side
	# Player owns the first pass breach charge unless a later enemy explosive uses this handler.
	return "player"


func get_opposite_side(side: String) -> String:
	return "player" if side == "enemy" else "enemy"


func get_unit_state(unit_state: Dictionary, side: String) -> Dictionary:
	var data = unit_state.get(side, {})
	if typeof(data) == TYPE_DICTIONARY:
		return data
	return {}


func clean_side(value: String) -> String:
	var side := value.strip_edges().to_lower()
	if side == "enemy":
		return "enemy"
	if side == "player":
		return "player"
	return ""


func get_anchor_rect(anchors: Dictionary, key: String) -> Rect2:
	var value = anchors.get(key, Rect2())
	if typeof(value) == TYPE_RECT2:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		var source: Dictionary = value
		return Rect2(source.get("position", Vector2.ZERO), source.get("size", Vector2.ZERO))
	return Rect2()


func ease_out_cubic(t: float) -> float:
	var clean = clamp(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - clean, 3.0)


func ease_in_out(t: float) -> float:
	var clean = clamp(t, 0.0, 1.0)
	return clean * clean * (3.0 - 2.0 * clean)


func pseudo_random(seed: int, index: int, salt: int) -> float:
	var value := sin(float(seed * 37 + index * 101 + salt * 911)) * 43758.5453
	return value - floor(value)


func close_points(points: PackedVector2Array) -> PackedVector2Array:
	var output := PackedVector2Array(points)
	if points.size() > 0:
		output.append(points[0])
	return output
