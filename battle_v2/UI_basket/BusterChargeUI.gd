extends RefCounted

class_name BattleV2BusterChargeUI

# Visual-only handler for buster_charge.
# Safe contract: this script only draws. It never changes battle state, damage, TODO timing, cooldowns, ammo, inventory, lock state, or loaded-consumable state.

const ITEM_ID := "buster_charge"
const ITEM_ID_ALT := "buster_charge_mk1"

# Buster is the lighter explosive sibling of breach_charge:
# same target box language, softer load read, smaller particle shot, smaller end explosion.
const BLUE_BODY := Color(0.08, 0.40, 1.0, 1.0)
const BLUE_CORE := Color(0.18, 0.76, 1.0, 1.0)
const BLUE_HOT := Color(0.66, 0.94, 1.0, 1.0)
const ORANGE_BODY := Color(1.0, 0.48, 0.12, 1.0)
const ORANGE_CORE := Color(1.0, 0.78, 0.28, 1.0)
const RED_EDGE := Color(1.0, 0.16, 0.08, 1.0)
const SMOKE := Color(0.22, 0.34, 0.62, 1.0)


func matches_packet(packet: Dictionary) -> bool:
	var item_id := get_packet_item_id(packet)
	return item_id == ITEM_ID or item_id == ITEM_ID_ALT


func draw_action_click(canvas: Control, packet: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(packet):
		return false

	var event_type := str(packet.get("event_type", packet.get("action_id", ""))).strip_edges().to_lower()
	var is_execute := is_execute_packet(packet) or event_type.find("execute") >= 0 or event_type.find("detonate") >= 0 or event_type.find("use_buster") >= 0
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

	# buster_charge is an explosive execution packet. If the packet matches but its event label is odd,
	# prefer the execute read so it never falls through to generic UI during the damage action.
	draw_execute_todo(canvas, event_summary, anchors, unit_state, anim_time)
	return true


func draw_ready_overlay(canvas: Control, anchors: Dictionary, unit_state: Dictionary, active_events: Array, anim_time: float) -> bool:
	var drew := false
	for owner_side in ["player", "enemy"]:
		if not is_buster_loaded_ready(unit_state, owner_side):
			continue
		if has_active_buster_event(active_events, owner_side):
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
	var duration = max(float(pulse.get("duration", 0.62)), 0.01)
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
	center += Vector2(-dir_sign * 22.0, 0.0)

	var hull_damage := float(pulse.get("hull_damage", 0.0)) + float(pulse.get("overflow_damage", 0.0))
	var shield_damage := float(pulse.get("shield_damage", 0.0))
	var seed := int(pulse.get("ui_seed", 4477))
	var direct_hull := hull_damage > 0.0 and shield_damage <= 0.0
	var blast_scale = 0.72 + clamp((hull_damage + shield_damage) / 95.0, 0.0, 0.42)
	if direct_hull:
		blast_scale += 0.12

	var flash := sin((1.0 - t) * PI)
	canvas.draw_circle(center, (15.0 + 26.0 * t) * blast_scale, Color(ORANGE_BODY.r, ORANGE_BODY.g, ORANGE_BODY.b, 0.17 * alpha))
	canvas.draw_circle(center, (8.0 + 16.0 * flash) * blast_scale, Color(BLUE_CORE.r, BLUE_CORE.g, BLUE_CORE.b, 0.12 * alpha))
	canvas.draw_circle(center, (4.0 + 8.0 * flash) * blast_scale, Color(ORANGE_CORE.r, ORANGE_CORE.g, ORANGE_CORE.b, 0.40 * alpha))

	# Smaller random-looking deterministic particle pop. No actual RNG state is used so redraw is stable.
	var particle_count := 19 if not direct_hull else 24
	if hull_damage > 0.0 and shield_damage > 0.0:
		particle_count = 27
	for i in range(particle_count):
		var r1 := pseudo_random(seed, i, 0)
		var r2 := pseudo_random(seed, i, 1)
		var r3 := pseudo_random(seed, i, 2)
		var angle := r1 * TAU + sin(anim_time * 1.8 + float(i)) * 0.055
		var speed = lerp(18.0, 78.0, r2) * blast_scale
		var dist = speed * ease_out_cubic(t)
		var drift = Vector2(cos(angle), sin(angle)) * dist
		var fall := Vector2(0.0, 10.0 * t * t * r3)
		var pos = center + drift + fall
		var particle_color := ORANGE_CORE
		if i % 4 == 0:
			particle_color = BLUE_HOT
		elif i % 4 == 1:
			particle_color = RED_EDGE
		var radius = lerp(0.9, 3.2, r3) * (1.0 - t * 0.38)
		canvas.draw_circle(pos, radius + 3.0, Color(particle_color.r, particle_color.g, particle_color.b, 0.045 * alpha))
		canvas.draw_circle(pos, radius, Color(particle_color.r, particle_color.g, particle_color.b, 0.56 * alpha))
		if i % 5 == 0:
			var tail = pos - Vector2(cos(angle), sin(angle)) * (7.0 + r3 * 13.0)
			canvas.draw_line(tail, pos, Color(particle_color.r, particle_color.g, particle_color.b, 0.20 * alpha), 1.1, true)

	# Tiny target-box crack read, lighter than breach_charge.
	for c in range(4):
		var corner_dir := Vector2(-1.0 if c % 2 == 0 else 1.0, -1.0 if c < 2 else 1.0)
		var p = center + corner_dir * (Vector2(12.0, 12.0) + Vector2(30.0, 20.0) * t)
		canvas.draw_line(p, p + Vector2(corner_dir.x * 7.0, 0.0), Color(BLUE_CORE.r, BLUE_CORE.g, BLUE_CORE.b, 0.24 * alpha), 1.2, true)
		canvas.draw_line(p, p + Vector2(0.0, corner_dir.y * 7.0), Color(ORANGE_BODY.r, ORANGE_BODY.g, ORANGE_BODY.b, 0.24 * alpha), 1.2, true)

	return true


func draw_load_click_pulse(canvas: Control, packet: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> void:
	var owner_side := get_packet_side(packet)
	var actor_rect := get_anchor_rect(anchors, owner_side + "_actor")
	var action_rect := get_anchor_rect(anchors, "player_action")
	if actor_rect.size == Vector2.ZERO:
		return

	var age := float(packet.get("age", 0.0))
	var duration = max(float(packet.get("duration", 0.64)), 0.01)
	var t = clamp(age / duration, 0.0, 1.0)
	var alpha = 1.0 - t
	var center := actor_rect.position + actor_rect.size * 0.5
	var from_pos := action_rect.position + action_rect.size * 0.5 if action_rect.size != Vector2.ZERO else center + Vector2(0.0, 86.0)
	var travel := from_pos.lerp(center, ease_out_cubic(t))

	canvas.draw_line(from_pos, travel, Color(BLUE_BODY.r, BLUE_BODY.g, BLUE_BODY.b, 0.18 * alpha), 1.3, true)
	canvas.draw_circle(center, 32.0 + 22.0 * t, Color(BLUE_CORE.r, BLUE_CORE.g, BLUE_CORE.b, 0.10 * alpha))
	canvas.draw_circle(center, 22.0 + 18.0 * t, Color(ORANGE_BODY.r, ORANGE_BODY.g, ORANGE_BODY.b, 0.08 * alpha))
	canvas.draw_circle(travel, 3.5 + 2.0 * t, Color(ORANGE_CORE.r, ORANGE_CORE.g, ORANGE_CORE.b, 0.68 * alpha))


func draw_execute_click_pulse(canvas: Control, packet: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> void:
	var owner_side := get_packet_side(packet)
	var target_side := get_opposite_side(owner_side)
	var actor_rect := get_anchor_rect(anchors, owner_side + "_actor")
	var target_rect := get_anchor_rect(anchors, target_side + "_actor")
	if actor_rect.size == Vector2.ZERO or target_rect.size == Vector2.ZERO:
		return

	var age := float(packet.get("age", 0.0))
	var duration = max(float(packet.get("duration", 0.64)), 0.01)
	var t = clamp(age / duration, 0.0, 1.0)
	var alpha = 1.0 - t
	var source := actor_rect.position + actor_rect.size * 0.5
	var target := target_rect.position + target_rect.size * 0.5
	var marker := source.lerp(target, t * 0.20)
	canvas.draw_circle(source, 36.0 + 26.0 * t, Color(ORANGE_BODY.r, ORANGE_BODY.g, ORANGE_BODY.b, 0.13 * alpha))
	canvas.draw_circle(source, 24.0 + 18.0 * t, Color(BLUE_BODY.r, BLUE_BODY.g, BLUE_BODY.b, 0.10 * alpha))
	draw_buster_particle(canvas, marker, (target - source).normalized(), 0.78 * alpha, 0.88 + t * 0.14, anim_time)


func draw_load_todo(canvas: Control, event_summary: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> void:
	var owner_side := get_packet_side(event_summary)
	var actor_rect := get_anchor_rect(anchors, owner_side + "_actor")
	if actor_rect.size == Vector2.ZERO:
		return

	var center := actor_rect.position + actor_rect.size * 0.5
	var progress = clamp(float(event_summary.get("progress", 0.0)), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(anim_time * 7.0)
	var alpha = 0.30 + progress * 0.24

	# Smaller user pulse than breach_charge: quick arming ring and small buster pips.
	for ring in range(3):
		var r = 31.0 + float(ring) * 8.5 + pulse * 3.0 + progress * 6.0
		var color := BLUE_CORE if ring % 2 == 0 else ORANGE_BODY
		canvas.draw_arc(center, r, anim_time * (0.42 + float(ring) * 0.05), anim_time * (0.42 + float(ring) * 0.05) + TAU * (0.16 + progress * 0.13), 42, Color(color.r, color.g, color.b, (0.16 - float(ring) * 0.025) * alpha), 1.5, true)

	for i in range(4):
		var angle := anim_time * 1.75 + float(i) * TAU / 4.0
		var pip := center + Vector2(cos(angle), sin(angle)) * (39.0 + pulse * 4.0)
		var pip_dir := (pip - center).normalized()
		draw_mini_buster_pip(canvas, pip, pip_dir, 0.72 + progress * 0.18, alpha)

	# Its own load identity: four small charged dots under the actor instead of breach's linked stack.
	var base := center + Vector2(-18.0, 42.0)
	for dot in range(4):
		var dot_alpha = 0.16 + 0.62 * clamp(progress * 4.0 - float(dot), 0.0, 1.0)
		var p := base + Vector2(float(dot) * 12.0, sin(anim_time * 6.0 + float(dot) * 1.2) * 1.8)
		canvas.draw_circle(p, 6.0, Color(BLUE_BODY.r, BLUE_BODY.g, BLUE_BODY.b, dot_alpha * 0.60))
		canvas.draw_circle(p, 3.1, Color(ORANGE_CORE.r, ORANGE_CORE.g, ORANGE_CORE.b, dot_alpha))


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
	var source := source_actor.position + source_actor.size * 0.5 + Vector2(dir_sign * 42.0, 0.0)
	var target := target_actor.position + target_actor.size * 0.5 + Vector2(-dir_sign * 42.0, 0.0)
	var lane_y := lane_rect.position.y + lane_rect.size.y * 0.5
	source.y = lane_y
	target.y = lane_y

	var launch_t = clamp((progress - 0.18) / 0.72, 0.0, 1.0)
	var head_t := ease_in_out(launch_t)
	var path_dir := (target - source).normalized()
	if path_dir == Vector2.ZERO:
		path_dir = Vector2(dir_sign, 0.0)
	var perp := Vector2(-path_dir.y, path_dir.x)
	var head := source.lerp(target, head_t)
	head += perp * sin(anim_time * 10.5 + progress * 5.0) * (3.0 * launch_t)

	# Small pre-launch pop around user.
	if progress < 0.25:
		var charge_alpha = 1.0 - clamp(progress / 0.25, 0.0, 1.0)
		canvas.draw_circle(source, 40.0 + progress * 52.0, Color(ORANGE_BODY.r, ORANGE_BODY.g, ORANGE_BODY.b, 0.13 * charge_alpha))
		canvas.draw_circle(source, 24.0 + progress * 38.0, Color(BLUE_BODY.r, BLUE_BODY.g, BLUE_BODY.b, 0.10 * charge_alpha))

	# Light trail: a small particle bead, not the heavy breach triangle.
	for i in range(7):
		var step_t = clamp(head_t - float(i) * 0.042, 0.0, 1.0)
		var trail_pos := source.lerp(target, step_t)
		trail_pos += perp * sin(anim_time * 7.4 + float(i) * 1.35) * (1.6 + float(i) * 0.32)
		var trail_alpha = (1.0 - float(i) / 7.0) * launch_t
		canvas.draw_circle(trail_pos, 6.0 + float(i) * 1.0, Color(SMOKE.r, SMOKE.g, SMOKE.b, 0.040 * trail_alpha))
		canvas.draw_circle(trail_pos, 2.0 + float(i) * 0.22, Color(BLUE_CORE.r, BLUE_CORE.g, BLUE_CORE.b, 0.16 * trail_alpha))
		if i % 2 == 0:
			canvas.draw_circle(trail_pos + perp * 3.0, 1.4, Color(ORANGE_CORE.r, ORANGE_CORE.g, ORANGE_CORE.b, 0.24 * trail_alpha))

	# Exact same target square behavior/UI as breach_charge while armed and in flight.
	draw_target_square(canvas, target_actor, owner_side, anim_time, 0.52 + launch_t * 0.28)

	if progress >= 0.13:
		draw_buster_particle(canvas, head, path_dir, 0.92, 1.0 + launch_t * 0.10, anim_time)

	# Small final explosion at the very end. The random particle damage explosion is drawn from pulse_damage when battle resolution reports it.
	if progress >= 0.93:
		var hit_alpha = clamp((progress - 0.93) / 0.07, 0.0, 1.0)
		draw_small_end_pop(canvas, target, path_dir, anim_time, hit_alpha)


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
		canvas.draw_circle(p, 2.6 + pulse * 1.2, Color(RED_EDGE.r, RED_EDGE.g, RED_EDGE.b, 0.68 * alpha_scale))

	canvas.draw_line(center + Vector2(-half.x * 0.32, 0.0), center + Vector2(half.x * 0.32, 0.0), Color(ORANGE_CORE.r, ORANGE_CORE.g, ORANGE_CORE.b, 0.20 * alpha_scale), 1.0, true)
	canvas.draw_line(center + Vector2(0.0, -half.y * 0.32), center + Vector2(0.0, half.y * 0.32), Color(ORANGE_CORE.r, ORANGE_CORE.g, ORANGE_CORE.b, 0.20 * alpha_scale), 1.0, true)
	canvas.draw_circle(center, 5.0 + pulse * 2.0, Color(RED_EDGE.r, RED_EDGE.g, RED_EDGE.b, 0.20 * alpha_scale))


func draw_buster_particle(canvas: Control, head: Vector2, path_dir: Vector2, alpha: float, scale: float, anim_time: float) -> void:
	if path_dir == Vector2.ZERO:
		path_dir = Vector2.RIGHT
	var perp := Vector2(-path_dir.y, path_dir.x)
	var pulse := 0.5 + 0.5 * sin(anim_time * 16.0)
	var front := head + path_dir * (8.0 * scale)
	var back := head - path_dir * (8.0 * scale)
	canvas.draw_line(back - perp * 3.0 * scale, front, Color(BLUE_HOT.r, BLUE_HOT.g, BLUE_HOT.b, 0.70 * alpha), 2.0 * scale, true)
	canvas.draw_line(back + perp * 3.0 * scale, front, Color(ORANGE_CORE.r, ORANGE_CORE.g, ORANGE_CORE.b, 0.62 * alpha), 1.5 * scale, true)
	canvas.draw_circle(head, (5.0 + pulse * 1.2) * scale, Color(ORANGE_CORE.r, ORANGE_CORE.g, ORANGE_CORE.b, 0.76 * alpha))
	canvas.draw_circle(head - path_dir * 7.0 * scale, 3.0 * scale, Color(BLUE_CORE.r, BLUE_CORE.g, BLUE_CORE.b, 0.50 * alpha))


func draw_mini_buster_pip(canvas: Control, center: Vector2, dir: Vector2, scale: float, alpha: float) -> void:
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	canvas.draw_line(center - dir * 4.5 * scale - perp * 2.0 * scale, center + dir * 6.0 * scale, Color(BLUE_HOT.r, BLUE_HOT.g, BLUE_HOT.b, 0.48 * alpha), 1.1, true)
	canvas.draw_circle(center, 2.5 * scale, Color(ORANGE_CORE.r, ORANGE_CORE.g, ORANGE_CORE.b, 0.56 * alpha))


func draw_small_end_pop(canvas: Control, center: Vector2, path_dir: Vector2, anim_time: float, alpha: float) -> void:
	var pulse := 0.5 + 0.5 * sin(anim_time * 22.0)
	canvas.draw_circle(center, 12.0 + pulse * 5.0, Color(ORANGE_BODY.r, ORANGE_BODY.g, ORANGE_BODY.b, 0.14 * alpha))
	canvas.draw_circle(center, 6.0 + pulse * 3.0, Color(ORANGE_CORE.r, ORANGE_CORE.g, ORANGE_CORE.b, 0.24 * alpha))
	for i in range(5):
		var a := float(i) * TAU / 5.0 + anim_time * 0.5
		var p := center + Vector2(cos(a), sin(a)) * (12.0 + pulse * 5.0)
		canvas.draw_line(center, p, Color(BLUE_CORE.r, BLUE_CORE.g, BLUE_CORE.b, 0.14 * alpha), 1.0, true)


func is_load_packet(packet: Dictionary) -> bool:
	var event_type := str(packet.get("event_type", packet.get("action_id", ""))).strip_edges().to_lower()
	var event_group := str(packet.get("event_group", "")).strip_edges().to_lower()
	return event_type == "load_consumable" or event_type.find("load") >= 0 or (event_group == "consumable" and not is_execute_packet(packet))


func is_execute_packet(packet: Dictionary) -> bool:
	var event_type := str(packet.get("event_type", packet.get("action_id", ""))).strip_edges().to_lower()
	var event_group := str(packet.get("event_group", "")).strip_edges().to_lower()
	var damage_type := str(packet.get("damage_type", "")).strip_edges().to_lower()
	var consumable_group := str(packet.get("consumable_group", "")).strip_edges().to_lower()
	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	return event_type == "execute_explosive" or event_type.find("execute") >= 0 or event_type.find("use_buster") >= 0 or action_id.find("use_buster") >= 0 or event_group == "explosive" or consumable_group == "explosive" or damage_type == "explosive"


func is_buster_loaded_ready(unit_state: Dictionary, owner_side: String) -> bool:
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


func has_active_buster_event(active_events: Array, owner_side: String) -> bool:
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
	# Player owns this consumable unless a later enemy explosive uses this handler.
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
