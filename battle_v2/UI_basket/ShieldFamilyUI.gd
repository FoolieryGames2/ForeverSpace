extends RefCounted

class_name BattleV2ShieldFamilyUI

# Visual-only handler for non-bespoke battle shields.
# Safe contract: this script only draws. It never changes shield state, inventory, energy drain, or swap timing.

const PLAYER_SCREEN := Color(0.24, 0.86, 1.0, 1.0)
const PLAYER_PULSE := Color(0.34, 0.58, 1.0, 1.0)
const PLAYER_BARRIER := Color(0.96, 0.78, 0.34, 1.0)
const PLAYER_CORE := Color(0.86, 1.0, 0.96, 1.0)

const ENEMY_SCREEN := Color(1.0, 0.30, 0.18, 1.0)
const ENEMY_PULSE := Color(0.96, 0.22, 0.64, 1.0)
const ENEMY_BARRIER := Color(1.0, 0.58, 0.20, 1.0)
const ENEMY_CORE := Color(1.0, 0.86, 0.62, 1.0)


func matches_packet(packet: Dictionary) -> bool:
	if get_visual_family(packet) == "":
		return false
	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	var event_group := str(packet.get("event_group", "")).strip_edges().to_lower()
	var item_type := str(packet.get("item_type", packet.get("type", ""))).strip_edges().to_lower()
	if action_id == "switch_shield" or event_group == "shield" or item_type == "shield":
		return true
	if string_array_has(packet.get("labels", []), "player_shield") or string_array_has(packet.get("labels", []), "enemy_shield"):
		return true
	return string_array_has(packet.get("labels", []), "unit_shield_equipped")


func matches_unit_side_state(side_state: Dictionary) -> bool:
	return get_visual_family(side_state) != ""


func draw_action_click(canvas: Control, packet: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(packet):
		return false

	var owner_side := get_packet_side(packet)
	var family := get_visual_family(packet)
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
	var pos := start.lerp(finish, t)
	var color := get_family_color(family, owner_side)
	var core := get_core_color(owner_side)
	var pulse := 0.5 + 0.5 * sin(anim_time * 15.0 + t * 9.0)

	canvas.draw_line(start, pos, Color(color.r, color.g, color.b, 0.14 * alpha), 1.3, true)
	draw_switch_token(canvas, pos, family, owner_side, 0.70 + pulse * 0.12, alpha, anim_time)
	canvas.draw_circle(pos, 12.0 + pulse * 5.0, Color(core.r, core.g, core.b, 0.06 * alpha))
	return true


func draw_todo_event(canvas: Control, event_summary: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(event_summary):
		return false

	var owner_side := get_packet_side(event_summary)
	var family := get_visual_family(event_summary)
	var progress = clamp(float(event_summary.get("progress", 0.0)), 0.0, 1.0)
	var todo_rect := get_anchor_rect(anchors, "todo")
	var actor_rect := get_anchor_rect(anchors, owner_side + "_actor")
	if todo_rect.size == Vector2.ZERO or actor_rect.size == Vector2.ZERO:
		return true

	var source := todo_rect.position + todo_rect.size * 0.5
	var target := actor_rect.position + actor_rect.size * 0.5
	var color := get_family_color(family, owner_side)
	var core := get_core_color(owner_side)
	var lock_t := smoothstep(0.0, 0.90, progress)
	var center := source.lerp(target, lock_t)
	var pulse := 0.5 + 0.5 * sin(anim_time * 14.0)

	for shard in range(6):
		var shard_t = clamp(progress - float(shard) * 0.055, 0.0, 1.0)
		var angle := anim_time * 0.65 + float(shard) * TAU / 6.0
		var start_offset := Vector2(cos(angle), sin(angle)) * (16.0 + float(shard % 3) * 5.0)
		var end_offset := Vector2(cos(angle), sin(angle)) * (38.0 + pulse * 5.0)
		var shard_pos := (source + start_offset).lerp(target + end_offset, shard_t)
		draw_switch_token(canvas, shard_pos, family, owner_side, 0.42 + pulse * 0.08, 0.26 + shard_t * 0.44, anim_time + float(shard))
		if shard_t > 0.08:
			canvas.draw_line(shard_pos, center, Color(color.r, color.g, color.b, 0.045 + shard_t * 0.05), 1.0, true)

	if progress >= 0.70:
		var overlay_alpha = smoothstep(0.70, 1.0, progress)
		draw_family_shell(canvas, target, family, owner_side, 0.42 + overlay_alpha * 0.36, anim_time, 0.72 + overlay_alpha * 0.18)
		canvas.draw_circle(target, 24.0 + pulse * 4.0, Color(core.r, core.g, core.b, 0.07 * overlay_alpha))

	return true


func draw_shield_overlay(canvas: Control, side: String, center: Vector2, side_state: Dictionary, anim_time: float) -> bool:
	if not matches_unit_side_state(side_state):
		return false

	var family := get_visual_family(side_state)
	var shield_current := float(side_state.get("shield_current", 0.0))
	var shield_max = max(float(side_state.get("shield_max", 0.0)), 0.0)
	var shield_state := str(side_state.get("shield_state", "active")).strip_edges().to_lower()
	var has_energy := bool(side_state.get("shield_has_energy", true))
	var power_level = clamp(int(side_state.get("shield_power_level", 0)), 0, 4)
	var shield_ratio := 0.0
	if shield_max > 0.0:
		shield_ratio = clamp(shield_current / shield_max, 0.0, 1.0)

	var active = shield_max > 0.0 and shield_current > 0.0 and shield_state != "broken" and shield_state != "down" and shield_state != "offline"
	if not active:
		draw_broken_family_overlay(canvas, center, family, side, anim_time)
		return true

	var alpha_scale = clamp(shield_ratio, 0.20, 1.0)
	if not has_energy or shield_state == "no_energy":
		alpha_scale *= 0.42
	if shield_state == "switching":
		alpha_scale *= 0.62

	var density = clamp(max(power_level, int(ceil(shield_ratio * 4.0))), 1, 4)
	draw_family_shell(canvas, center, family, side, alpha_scale, anim_time, 0.84 + float(density) * 0.05)
	return true


func draw_switch_token(canvas: Control, center: Vector2, family: String, side: String, scale: float, alpha: float, anim_time: float) -> void:
	var color := get_family_color(family, side)
	var core := get_core_color(side)
	if family == "barrier":
		draw_plate(canvas, center, anim_time, 12.0 * scale, 9.0 * scale, Color(color.r, color.g, color.b, 0.34 * alpha), Color(core.r, core.g, core.b, 0.30 * alpha))
		draw_plate(canvas, center + Vector2(7.0 * scale, 0.0), anim_time + 0.7, 9.0 * scale, 7.0 * scale, Color(color.r, color.g, color.b, 0.22 * alpha), Color(core.r, core.g, core.b, 0.22 * alpha))
	elif family == "pulse":
		for ring in range(3):
			canvas.draw_arc(center, 7.0 * scale + float(ring) * 5.0 * scale, anim_time * 0.5, anim_time * 0.5 + TAU * 0.72, 28, Color(color.r, color.g, color.b, (0.22 - float(ring) * 0.045) * alpha), 1.1, true)
		canvas.draw_circle(center, 3.0 * scale, Color(core.r, core.g, core.b, 0.46 * alpha))
	else:
		for line_i in range(3):
			var y := (float(line_i) - 1.0) * 4.5 * scale
			canvas.draw_line(center + Vector2(-11.0 * scale, y), center + Vector2(11.0 * scale, y), Color(color.r, color.g, color.b, 0.24 * alpha), 1.0, true)
		canvas.draw_arc(center, 15.0 * scale, -0.72, 0.72, 20, Color(core.r, core.g, core.b, 0.28 * alpha), 1.1, true)


func draw_family_shell(canvas: Control, center: Vector2, family: String, side: String, alpha_scale: float, anim_time: float, radius_scale: float) -> void:
	if family == "barrier":
		draw_barrier_shell(canvas, center, side, alpha_scale, anim_time, radius_scale)
	elif family == "pulse":
		draw_pulse_shell(canvas, center, side, alpha_scale, anim_time, radius_scale)
	else:
		draw_screen_shell(canvas, center, side, alpha_scale, anim_time, radius_scale)


func draw_screen_shell(canvas: Control, center: Vector2, side: String, alpha_scale: float, anim_time: float, radius_scale: float) -> void:
	var color := get_family_color("screen", side)
	var core := get_core_color(side)
	var idle := 0.5 + 0.5 * sin(anim_time * 2.4)
	var radius := 58.0 * radius_scale + idle * 3.0
	for arc_i in range(3):
		var arc_radius := radius + float(arc_i) * 7.0
		var spin := anim_time * (0.24 + float(arc_i) * 0.05)
		canvas.draw_arc(center, arc_radius, spin, spin + TAU * 0.36, 44, Color(color.r, color.g, color.b, (0.13 - float(arc_i) * 0.025) * alpha_scale), 1.4, true)
		canvas.draw_arc(center, arc_radius, spin + PI, spin + PI + TAU * 0.28, 44, Color(core.r, core.g, core.b, (0.09 - float(arc_i) * 0.018) * alpha_scale), 1.0, true)
	for row in range(5):
		var y := (float(row) - 2.0) * 14.0
		var half_width := sqrt(max(radius * radius - y * y, 0.0))
		var left := center + Vector2(-half_width, y)
		var right := center + Vector2(half_width, y)
		canvas.draw_line(left, right, Color(color.r, color.g, color.b, 0.030 * alpha_scale), 1.0, true)
	for dot in range(10):
		var angle := anim_time * 0.36 + float(dot) * TAU / 10.0
		var pos := center + Vector2(cos(angle), sin(angle)) * (radius + sin(anim_time * 1.4 + float(dot)) * 3.5)
		canvas.draw_circle(pos, 1.8, Color(core.r, core.g, core.b, 0.20 * alpha_scale))


func draw_pulse_shell(canvas: Control, center: Vector2, side: String, alpha_scale: float, anim_time: float, radius_scale: float) -> void:
	var color := get_family_color("pulse", side)
	var core := get_core_color(side)
	var pulse := 0.5 + 0.5 * sin(anim_time * 3.2)
	for ring in range(5):
		var t := float(ring) / 4.0
		var radius := (38.0 + t * 35.0 + pulse * 5.0) * radius_scale
		var spin := anim_time * (0.34 + t * 0.12)
		var span := TAU * (0.48 + t * 0.18)
		canvas.draw_arc(center, radius, spin, spin + span, 72, Color(color.r, color.g, color.b, (0.11 + t * 0.045) * alpha_scale), 1.7, true)
		canvas.draw_arc(center, radius, spin + PI * 0.72, spin + PI * 0.72 + span * 0.34, 42, Color(core.r, core.g, core.b, 0.07 * alpha_scale), 1.1, true)
	canvas.draw_circle(center, 69.0 * radius_scale + pulse * 4.0, Color(color.r, color.g, color.b, 0.036 * alpha_scale))


func draw_barrier_shell(canvas: Control, center: Vector2, side: String, alpha_scale: float, anim_time: float, radius_scale: float) -> void:
	var color := get_family_color("barrier", side)
	var core := get_core_color(side)
	var plate_count := 8
	var radius := 60.0 * radius_scale
	for plate_i in range(plate_count):
		var t := float(plate_i) / float(plate_count)
		var angle := t * TAU + anim_time * 0.16
		var plate_center := center + Vector2(cos(angle), sin(angle)) * (radius + sin(anim_time * 1.6 + float(plate_i)) * 3.0)
		var plate_alpha := (0.18 + 0.07 * sin(anim_time * 2.0 + float(plate_i))) * alpha_scale
		draw_plate(canvas, plate_center, angle + PI * 0.5, 16.0 * radius_scale, 10.0 * radius_scale, Color(color.r, color.g, color.b, plate_alpha), Color(core.r, core.g, core.b, plate_alpha * 0.82))
		if plate_i % 2 == 0:
			canvas.draw_line(plate_center, center, Color(color.r, color.g, color.b, 0.030 * alpha_scale), 1.0, true)
	canvas.draw_arc(center, radius + 16.0, anim_time * 0.22, anim_time * 0.22 + TAU * 0.30, 48, Color(core.r, core.g, core.b, 0.10 * alpha_scale), 1.4, true)
	canvas.draw_circle(center, radius + 13.0, Color(color.r, color.g, color.b, 0.025 * alpha_scale))


func draw_broken_family_overlay(canvas: Control, center: Vector2, family: String, side: String, anim_time: float) -> void:
	var color := get_family_color(family, side)
	var core := get_core_color(side)
	for chip in range(7):
		var angle := anim_time * 0.18 + float(chip) * TAU / 7.0
		var radius := 48.0 + float(chip % 3) * 8.0
		var chip_pos := center + Vector2(cos(angle), sin(angle)) * radius
		if family == "barrier":
			draw_plate(canvas, chip_pos, angle, 9.0, 6.0, Color(color.r, color.g, color.b, 0.11), Color(core.r, core.g, core.b, 0.10))
		else:
			canvas.draw_arc(center, radius, angle, angle + 0.24, 12, Color(color.r, color.g, color.b, 0.10), 1.2, true)
			canvas.draw_circle(chip_pos, 2.0, Color(core.r, core.g, core.b, 0.11))


func draw_plate(canvas: Control, center: Vector2, angle: float, width: float, height: float, fill: Color, edge: Color) -> void:
	var tangent := Vector2(cos(angle), sin(angle))
	var radial := Vector2(-tangent.y, tangent.x)
	var points := PackedVector2Array([
		center - tangent * width * 0.5 - radial * height * 0.5,
		center + tangent * width * 0.5 - radial * height * 0.34,
		center + tangent * width * 0.5 + radial * height * 0.5,
		center - tangent * width * 0.5 + radial * height * 0.34
	])
	canvas.draw_colored_polygon(points, fill)
	canvas.draw_polyline(close_points(points), edge, 1.0, true)


func get_visual_family(packet: Dictionary) -> String:
	var item_id := str(packet.get("item_id", packet.get("selected_shield_id", packet.get("equipped_shield_id", "")))).strip_edges().to_lower()
	var item_name := str(packet.get("item_name", packet.get("display_name", packet.get("display_text", packet.get("selected_shield_name", ""))))).strip_edges().to_lower()
	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	var same_type_key := str(packet.get("same_type_key", "")).strip_edges().to_lower()
	var haystack := item_id + " " + item_name + " " + same_type_key

	if haystack.find("smart_guy") >= 0 or haystack.find("mirror_shield") >= 0 or haystack.find("mirror shield") >= 0:
		return ""
	if action_id != "" and action_id != "switch_shield" and item_id == "" and same_type_key == "":
		return ""

	if haystack.find("anchor") >= 0 or haystack.find("barrier") >= 0 or haystack.find("lock") >= 0 or haystack.find("plate") >= 0:
		return "barrier"
	if haystack.find("pulse") >= 0 or haystack.find("guard") >= 0:
		return "pulse"
	if haystack.find("screen") >= 0 or haystack.find("flicker") >= 0 or haystack.find("shield") >= 0:
		return "screen"
	return ""


func get_packet_side(packet: Dictionary) -> String:
	var side := str(packet.get("source_side", packet.get("owner_side", packet.get("event_side", "")))).strip_edges().to_lower()
	if side == "enemy":
		return "enemy"
	return "player"


func get_family_color(family: String, side: String) -> Color:
	if side == "enemy":
		if family == "barrier":
			return ENEMY_BARRIER
		if family == "pulse":
			return ENEMY_PULSE
		return ENEMY_SCREEN
	if family == "barrier":
		return PLAYER_BARRIER
	if family == "pulse":
		return PLAYER_PULSE
	return PLAYER_SCREEN


func get_core_color(side: String) -> Color:
	return ENEMY_CORE if side == "enemy" else PLAYER_CORE


func get_anchor_rect(anchors: Dictionary, key: String) -> Rect2:
	var value = anchors.get(key, Rect2())
	if typeof(value) == TYPE_RECT2:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return Rect2(value.get("position", Vector2.ZERO), value.get("size", Vector2.ZERO))
	return Rect2()


func close_points(points: PackedVector2Array) -> PackedVector2Array:
	var output := PackedVector2Array(points)
	if points.size() > 0:
		output.append(points[0])
	return output


func string_array_has(value, needle: String) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var clean_needle := needle.strip_edges().to_lower()
	for entry in value:
		if str(entry).strip_edges().to_lower() == clean_needle:
			return true
	return false
