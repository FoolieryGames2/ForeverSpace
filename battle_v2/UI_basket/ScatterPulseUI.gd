extends RefCounted

class_name BattleV2ScatterPulseUI

# Visual-only handler for Scatter Pulse MK2 and Raider Arc Stinger MK2.
# Safe contract: this script only draws. It never changes battle state, damage, timing, cooldowns, or inventory.

const SCATTER_PRIMARY := Color(0.10, 0.76, 1.0, 1.0)
const SCATTER_CORE := Color(0.72, 1.0, 0.92, 1.0)
const SCATTER_HOT := Color(1.0, 0.88, 0.32, 1.0)
const SCATTER_DAMAGE := Color(0.88, 0.98, 1.0, 1.0)

const STINGER_PRIMARY := Color(1.0, 0.24, 0.08, 1.0)
const STINGER_CORE := Color(1.0, 0.66, 0.18, 1.0)
const STINGER_HOT := Color(1.0, 0.92, 0.42, 1.0)
const STINGER_GHOST := Color(0.84, 0.12, 1.0, 1.0)
const STINGER_DAMAGE := Color(1.0, 0.34, 0.12, 1.0)


func matches_packet(packet: Dictionary) -> bool:
	return get_visual_family(packet) != ""


func draw_action_click(canvas: Control, packet: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(packet):
		return false

	var context := build_attack_context(packet)
	var owner_side := str(context.get("owner_side", "player"))
	var family := str(context.get("family", "scatter"))
	var colors := get_family_colors(family)
	var age := float(packet.get("age", 0.0))
	var duration = max(float(packet.get("duration", 0.72)), 0.01)
	var t = clamp(age / duration, 0.0, 1.0)
	var alpha = 1.0 - t

	var start_rect := get_anchor_rect(anchors, "player_action")
	if owner_side == "enemy":
		start_rect = get_anchor_rect(anchors, "enemy_actor")
	var todo_rect := get_anchor_rect(anchors, "todo")
	if start_rect.size == Vector2.ZERO or todo_rect.size == Vector2.ZERO:
		return true

	var start := start_rect.position + start_rect.size * 0.5
	var finish := todo_rect.position + todo_rect.size * 0.5
	var path := finish - start
	var dir := path.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var perp := Vector2(-dir.y, dir.x)
	var primary: Color = colors.get("primary", SCATTER_PRIMARY)
	var core: Color = colors.get("core", SCATTER_CORE)
	var hot: Color = colors.get("hot", SCATTER_HOT)
	var pos := start.lerp(finish, t)
	var shimmer := 0.5 + 0.5 * sin(anim_time * 22.0 + t * 8.0)

	canvas.draw_line(start, pos, Color(primary.r, primary.g, primary.b, 0.15 * alpha), 1.3, true)
	canvas.draw_circle(pos, 14.0 + shimmer * 7.0, Color(primary.r, primary.g, primary.b, 0.08 * alpha))
	canvas.draw_circle(pos, 4.2 + shimmer * 2.0, Color(core.r, core.g, core.b, 0.76 * alpha))

	for mote in range(5):
		var mote_t = clamp(t - float(mote) * 0.055, 0.0, 1.0)
		var side_offset := (float(mote) - 2.0) * 4.5
		var mote_pos := start.lerp(finish, mote_t) + perp * side_offset + Vector2(0.0, sin(anim_time * 18.0 + float(mote) * 1.9) * 3.0)
		canvas.draw_circle(mote_pos, 2.0 + shimmer * 1.1, Color(hot.r, hot.g, hot.b, 0.42 * alpha))

	return true


func draw_todo_event(canvas: Control, event_summary: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(event_summary):
		return false

	var context := build_attack_context(event_summary)
	var owner_side := str(context.get("owner_side", "player"))
	var target_side := str(context.get("target_side", "enemy"))
	var family := str(context.get("family", "scatter"))
	var colors := get_family_colors(family)
	var is_stinger := family == "stinger"
	var progress = clamp(float(event_summary.get("progress", 0.0)), 0.0, 1.0)

	var source_actor := get_anchor_rect(anchors, owner_side + "_actor")
	var target_actor := get_anchor_rect(anchors, target_side + "_actor")
	var lane_rect := get_anchor_rect(anchors, owner_side + "_lane")
	if lane_rect.size == Vector2.ZERO:
		lane_rect = get_anchor_rect(anchors, "player_lane")
	if source_actor.size == Vector2.ZERO or target_actor.size == Vector2.ZERO or lane_rect.size == Vector2.ZERO:
		return true

	var dir_sign := 1.0 if owner_side == "player" else -1.0
	var lane_y := lane_rect.position.y + lane_rect.size.y * 0.5
	var source := source_actor.position + source_actor.size * 0.5 + Vector2(dir_sign * 42.0, 0.0)
	var target := target_actor.position + target_actor.size * 0.5 + Vector2(-dir_sign * 42.0, 0.0)
	source.y = lane_y
	target.y = lane_y

	var path := target - source
	var path_dir := path.normalized()
	if path_dir == Vector2.ZERO:
		path_dir = Vector2(dir_sign, 0.0)
	var perp := Vector2(-path_dir.y, path_dir.x)
	var primary: Color = colors.get("primary", SCATTER_PRIMARY)
	var core: Color = colors.get("core", SCATTER_CORE)
	var hot: Color = colors.get("hot", SCATTER_HOT)
	var ghost: Color = colors.get("ghost", primary)
	var heat := 0.5 + 0.5 * sin(anim_time * (24.0 if is_stinger else 18.0))

	canvas.draw_line(source, target, Color(primary.r, primary.g, primary.b, 0.055), 1.0, true)

	var shard_count := 6 if is_stinger else 5
	for shard in range(shard_count):
		var shard_center := (float(shard) - (float(shard_count) - 1.0) * 0.5)
		var shard_delay := float(shard) * 0.035
		var travel_t = clamp(progress * 1.12 - shard_delay, 0.0, 1.0)
		var scatter_width = 10.0 + progress * (12.0 if is_stinger else 18.0)
		var wave = sin(travel_t * PI) * scatter_width * shard_center * 0.36
		var jitter := sin(anim_time * (13.0 if is_stinger else 9.0) + float(shard) * 2.1) * (5.0 if is_stinger else 3.5)
		var head = source.lerp(target, travel_t) + perp * (wave + jitter)
		var tail = source.lerp(target, max(travel_t - 0.12, 0.0)) + perp * (wave * 0.58)
		var shard_alpha = 0.22 + progress * 0.48
		canvas.draw_line(tail, head, Color(primary.r, primary.g, primary.b, shard_alpha), 1.4 if shard % 2 == 0 else 1.0, true)
		canvas.draw_circle(head, 4.0 + heat * 2.2, Color(core.r, core.g, core.b, 0.48 + progress * 0.28))
		if is_stinger and shard % 2 == 0:
			canvas.draw_line(head - perp * 7.0, head + perp * 7.0, Color(ghost.r, ghost.g, ghost.b, 0.18 + progress * 0.12), 1.0, true)

	if progress >= 0.76:
		var contact_alpha = clamp((progress - 0.76) / 0.24, 0.0, 1.0)
		draw_scatter_contact(canvas, target, target_side, unit_state, colors, anim_time, contact_alpha, is_stinger)

	return true


func draw_scatter_contact(canvas: Control, target: Vector2, target_side: String, unit_state: Dictionary, colors: Dictionary, anim_time: float, alpha: float, is_stinger: bool) -> void:
	var state := get_contact_status(target_side, unit_state)
	var primary: Color = colors.get("primary", SCATTER_PRIMARY)
	var core: Color = colors.get("core", SCATTER_CORE)
	var hot: Color = colors.get("hot", SCATTER_HOT)
	var damage: Color = colors.get("damage", SCATTER_DAMAGE)
	var ghost: Color = colors.get("ghost", primary)
	var pulse := 0.5 + 0.5 * sin(anim_time * (30.0 if is_stinger else 23.0))
	var facing := 1.0 if target_side == "enemy" else -1.0

	if state == "shield_active":
		for ring in range(4):
			var radius := 16.0 + float(ring) * 9.0 + pulse * 4.0
			var start_angle := -0.95 if target_side == "enemy" else PI - 0.95
			canvas.draw_arc(target, radius, start_angle, start_angle + 1.9, 30, Color(primary.r, primary.g, primary.b, (0.32 - float(ring) * 0.055) * alpha), 1.7, true)
		for tick in range(5):
			var offset := Vector2(facing * (8.0 + float(tick) * 4.0), (float(tick) - 2.0) * 5.0 + sin(anim_time * 6.0 + float(tick)) * 2.0)
			canvas.draw_circle(target + offset, 2.0 + pulse, Color(hot.r, hot.g, hot.b, 0.32 * alpha))
		canvas.draw_circle(target, 7.0 + pulse * 4.0, Color(core.r, core.g, core.b, 0.18 * alpha))
		return

	if state == "shield_weak" or state == "shield_failed":
		for chip in range(4):
			var angle := (-0.7 + float(chip) * 0.42) if target_side == "enemy" else (PI - 0.7 + float(chip) * 0.42)
			var chip_pos := target + Vector2(cos(angle), sin(angle)) * (22.0 + pulse * 5.0)
			canvas.draw_line(chip_pos, chip_pos + Vector2(cos(angle), sin(angle)) * 7.0, Color(primary.r, primary.g, primary.b, 0.16 * alpha), 1.0, true)
		if state == "shield_weak":
			return

	var hull_pos := target + Vector2(facing * 12.0, 0.0)
	canvas.draw_circle(hull_pos, 12.0 + pulse * 6.0, Color(damage.r, damage.g, damage.b, 0.18 * alpha))
	canvas.draw_circle(hull_pos, 4.5 + pulse * 2.0, Color(core.r, core.g, core.b, 0.78 * alpha))
	for spark in range(7):
		var angle := float(spark) * TAU / 7.0 + anim_time * 0.7
		var spark_dir := Vector2(cos(angle), sin(angle))
		var spark_color := ghost if is_stinger and spark % 2 == 0 else hot
		canvas.draw_line(hull_pos, hull_pos + spark_dir * (8.0 + pulse * 10.0), Color(spark_color.r, spark_color.g, spark_color.b, 0.30 * alpha), 1.1, true)


func build_attack_context(packet: Dictionary) -> Dictionary:
	var family := get_visual_family(packet)
	var owner_side := clean_side(str(packet.get("source_side", packet.get("owner_side", packet.get("event_side", "")))))
	if owner_side == "":
		owner_side = "enemy" if family == "stinger" else "player"
	var target_side := clean_side(str(packet.get("target_side", "")))
	if target_side == "":
		target_side = get_opposite_side(owner_side)
	return {
		"family": family,
		"owner_side": owner_side,
		"target_side": target_side
	}


func get_visual_family(packet: Dictionary) -> String:
	var item_id := str(packet.get("item_id", "")).strip_edges().to_lower()
	var item_name := str(packet.get("item_name", packet.get("display_name", packet.get("display_text", "")))).strip_edges().to_lower()
	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	var same_type_key := str(packet.get("same_type_key", "")).strip_edges().to_lower()

	if item_id.find("scatter_pulse") >= 0 or action_id == "fire_scatter_pulse" or same_type_key.find("scatter_pulse") >= 0 or item_name.find("scatter pulse") >= 0:
		return "scatter"
	if item_id.find("raider_arc_stinger") >= 0 or action_id == "fire_raider_arc_stinger" or same_type_key.find("arc_stinger") >= 0 or item_name.find("arc stinger") >= 0:
		return "stinger"

	if string_array_has(packet.get("labels", []), "primary_weapon_energy") and string_array_has(packet.get("labels", []), "tier_2"):
		if item_name.find("scatter") >= 0 or item_id.find("scatter") >= 0:
			return "scatter"
		if item_name.find("stinger") >= 0 or item_id.find("stinger") >= 0:
			return "stinger"
	return ""


func get_family_colors(family: String) -> Dictionary:
	if family == "stinger":
		return {
			"primary": STINGER_PRIMARY,
			"core": STINGER_CORE,
			"hot": STINGER_HOT,
			"ghost": STINGER_GHOST,
			"damage": STINGER_DAMAGE
		}
	return {
		"primary": SCATTER_PRIMARY,
		"core": SCATTER_CORE,
		"hot": SCATTER_HOT,
		"ghost": SCATTER_PRIMARY,
		"damage": SCATTER_DAMAGE
	}


func get_contact_status(side: String, unit_state: Dictionary) -> String:
	var data := get_unit_state(side, unit_state)
	var shield_current := float(data.get("shield_current", 0.0))
	var shield_max = max(float(data.get("shield_max", 0.0)), 0.0)
	var state := str(data.get("shield_state", "active")).strip_edges().to_lower()
	var has_energy := bool(data.get("shield_has_energy", true))

	if shield_max <= 0.0:
		return "no_shield"
	if shield_current <= 0.0 or state == "broken" or state == "down" or state == "offline" or state == "none":
		return "shield_failed"
	if not has_energy or state == "no_energy":
		return "shield_weak"
	return "shield_active"


func get_unit_state(side: String, unit_state: Dictionary) -> Dictionary:
	var data = unit_state.get(side, {})
	if typeof(data) == TYPE_DICTIONARY:
		return data
	return {}


func clean_side(value: String) -> String:
	var side := value.strip_edges().to_lower()
	if side == "enemy" or side == "player":
		return side
	return ""


func get_opposite_side(side: String) -> String:
	return "player" if side == "enemy" else "enemy"


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
