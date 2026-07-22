extends RefCounted

class_name BattleV2SpikeDriverUI

# Visual-only handler for Spike Driver MK3 and Guardian Punch Driver MK3.
# Safe contract: this script only draws. It never changes battle state, damage, TODO timing, ammo, or inventory.

const SPIKE_METAL := Color(0.68, 0.78, 0.84, 1.0)
const SPIKE_CORE := Color(0.92, 0.98, 1.0, 1.0)
const SPIKE_GLOW := Color(0.24, 0.78, 1.0, 1.0)
const SPIKE_SPARK := Color(1.0, 0.78, 0.24, 1.0)

const PUNCH_METAL := Color(0.92, 0.58, 0.38, 1.0)
const PUNCH_CORE := Color(1.0, 0.88, 0.62, 1.0)
const PUNCH_GLOW := Color(1.0, 0.22, 0.10, 1.0)
const PUNCH_SHADOW := Color(0.72, 0.10, 0.18, 1.0)


func matches_packet(packet: Dictionary) -> bool:
	return get_visual_family(packet) != ""


func draw_action_click(canvas: Control, packet: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(packet):
		return false

	var context := build_attack_context(packet)
	var owner_side := str(context.get("owner_side", "player"))
	var colors := get_family_colors(str(context.get("family", "spike")))
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
	var pos := start.lerp(finish, t)
	var glow: Color = colors.get("glow", SPIKE_GLOW)
	var core: Color = colors.get("core", SPIKE_CORE)
	var heat := 0.5 + 0.5 * sin(anim_time * 18.0 + t * 10.0)

	canvas.draw_line(start, pos, Color(glow.r, glow.g, glow.b, 0.15 * alpha), 2.0, true)
	draw_spike_slug(canvas, pos, dir, 0.78 + heat * 0.12, colors, alpha)
	canvas.draw_circle(pos - dir * 18.0, 9.0 + heat * 3.0, Color(core.r, core.g, core.b, 0.10 * alpha))
	return true


func draw_todo_event(canvas: Control, event_summary: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(event_summary):
		return false

	var context := build_attack_context(event_summary)
	var owner_side := str(context.get("owner_side", "player"))
	var target_side := str(context.get("target_side", "enemy"))
	var family := str(context.get("family", "spike"))
	var colors := get_family_colors(family)
	var progress = clamp(float(event_summary.get("progress", 0.0)), 0.0, 1.0)
	var burst_index = max(int(event_summary.get("burst_index", 1)), 1)
	var burst_total = max(int(event_summary.get("burst_total", event_summary.get("burst_count", 3))), 1)

	var source_actor := get_anchor_rect(anchors, owner_side + "_actor")
	var target_actor := get_anchor_rect(anchors, target_side + "_actor")
	var lane_rect := get_anchor_rect(anchors, owner_side + "_lane")
	if lane_rect.size == Vector2.ZERO:
		lane_rect = get_anchor_rect(anchors, "player_lane")
	if source_actor.size == Vector2.ZERO or target_actor.size == Vector2.ZERO or lane_rect.size == Vector2.ZERO:
		return true

	var dir_sign := 1.0 if owner_side == "player" else -1.0
	var lane_y := lane_rect.position.y + lane_rect.size.y * 0.5
	var burst_offset := (float(burst_index) - (float(burst_total) + 1.0) * 0.5) * 11.0
	burst_offset += sin(anim_time * 5.0 + float(burst_index) * 1.4) * 2.0

	var source := source_actor.position + source_actor.size * 0.5 + Vector2(dir_sign * 48.0, 0.0)
	var target := target_actor.position + target_actor.size * 0.5 + Vector2(-dir_sign * 48.0, 0.0)
	source.y = lane_y + burst_offset
	target.y = lane_y + burst_offset

	var path := target - source
	var path_dir := path.normalized()
	if path_dir == Vector2.ZERO:
		path_dir = Vector2(dir_sign, 0.0)
	var metal: Color = colors.get("metal", SPIKE_METAL)
	var core: Color = colors.get("core", SPIKE_CORE)
	var glow: Color = colors.get("glow", SPIKE_GLOW)
	var shadow: Color = colors.get("shadow", glow)
	var heat := 0.5 + 0.5 * sin(anim_time * 20.0 + float(burst_index))

	draw_driver_rails(canvas, source, target, path_dir, colors, progress, anim_time, float(burst_index))

	if progress < 0.34:
		var windup_t = progress / 0.34
		var chamber = source - path_dir * (34.0 - windup_t * 18.0)
		canvas.draw_circle(source, 18.0 + windup_t * 12.0, Color(glow.r, glow.g, glow.b, 0.07 + windup_t * 0.12))
		draw_spike_slug(canvas, chamber, path_dir, 0.82, colors, 0.42 + windup_t * 0.38)
		for clamp_i in range(3):
			var clamp_pos := source - path_dir * (18.0 + float(clamp_i) * 12.0)
			canvas.draw_line(clamp_pos + Vector2(0.0, -7.0), clamp_pos + Vector2(0.0, 7.0), Color(core.r, core.g, core.b, 0.14 + windup_t * 0.12), 1.3, true)
		return true

	var shot_t = clamp((progress - 0.34) / 0.56, 0.0, 1.0)
	var travel_t := 1.0 - pow(1.0 - shot_t, 3.6)
	var head := source.lerp(target, travel_t)
	var recoil_alpha = clamp(1.0 - shot_t, 0.0, 1.0)
	canvas.draw_line(source, head, Color(glow.r, glow.g, glow.b, 0.14 + shot_t * 0.24), 2.2, true)
	canvas.draw_line(head - path_dir * 58.0, head - path_dir * 12.0, Color(shadow.r, shadow.g, shadow.b, 0.18 * recoil_alpha), 4.0, true)
	draw_spike_slug(canvas, head, path_dir, 0.96 + heat * 0.10, colors, 0.70 + shot_t * 0.24)

	if progress >= 0.82:
		var contact_alpha = clamp((progress - 0.82) / 0.18, 0.0, 1.0)
		draw_spike_contact(canvas, target, target_side, unit_state, path_dir, colors, anim_time, float(burst_index), contact_alpha)

	canvas.draw_circle(source + Vector2(0.0, -16.0), 2.4, Color(metal.r, metal.g, metal.b, 0.26))
	for bead in range(burst_total):
		var bead_alpha := 0.16 if bead + 1 != burst_index else 0.58
		canvas.draw_circle(source + Vector2(float(bead) * 7.0 - 7.0, -16.0), 2.0 if bead + 1 != burst_index else 3.2, Color(core.r, core.g, core.b, bead_alpha))

	return true


func draw_driver_rails(canvas: Control, source: Vector2, target: Vector2, path_dir: Vector2, colors: Dictionary, progress: float, anim_time: float, burst_phase: float) -> void:
	var perp := Vector2(-path_dir.y, path_dir.x)
	var metal: Color = colors.get("metal", SPIKE_METAL)
	var glow: Color = colors.get("glow", SPIKE_GLOW)
	var rail_end := source.lerp(target, clamp(progress * 0.72, 0.0, 0.72))
	for rail_side in [-1.0, 1.0]:
		var offset = perp * rail_side * 8.0
		canvas.draw_line(source + offset, rail_end + offset, Color(metal.r, metal.g, metal.b, 0.14 + progress * 0.10), 1.2, true)
	canvas.draw_line(source, target, Color(glow.r, glow.g, glow.b, 0.045), 1.0, true)
	for ring in range(3):
		var ring_t = clamp(progress * 1.25 - float(ring) * 0.16, 0.0, 1.0)
		var ring_pos := source.lerp(target, ring_t)
		var radius := 8.0 + sin(anim_time * 12.0 + burst_phase + float(ring)) * 2.0
		canvas.draw_arc(ring_pos, radius, 0.0, TAU, 20, Color(glow.r, glow.g, glow.b, 0.055 + progress * 0.045), 1.0, true)


func draw_spike_slug(canvas: Control, center: Vector2, dir: Vector2, scale: float, colors: Dictionary, alpha: float) -> void:
	var clean_dir := dir.normalized()
	if clean_dir == Vector2.ZERO:
		clean_dir = Vector2.RIGHT
	var perp := Vector2(-clean_dir.y, clean_dir.x)
	var metal: Color = colors.get("metal", SPIKE_METAL)
	var core: Color = colors.get("core", SPIKE_CORE)
	var glow: Color = colors.get("glow", SPIKE_GLOW)
	var points := PackedVector2Array([
		center + clean_dir * 23.0 * scale,
		center - clean_dir * 14.0 * scale + perp * 8.0 * scale,
		center - clean_dir * 28.0 * scale,
		center - clean_dir * 14.0 * scale - perp * 8.0 * scale
	])
	canvas.draw_colored_polygon(points, Color(metal.r, metal.g, metal.b, 0.62 * alpha))
	canvas.draw_polyline(close_points(points), Color(core.r, core.g, core.b, 0.52 * alpha), 1.2, true)
	canvas.draw_line(center - clean_dir * 18.0 * scale, center + clean_dir * 17.0 * scale, Color(glow.r, glow.g, glow.b, 0.34 * alpha), 1.5, true)


func draw_spike_contact(canvas: Control, target: Vector2, target_side: String, unit_state: Dictionary, path_dir: Vector2, colors: Dictionary, anim_time: float, burst_phase: float, alpha: float) -> void:
	var status := get_contact_status(target_side, unit_state)
	var metal: Color = colors.get("metal", SPIKE_METAL)
	var core: Color = colors.get("core", SPIKE_CORE)
	var glow: Color = colors.get("glow", SPIKE_GLOW)
	var spark := SPIKE_SPARK
	var pulse := 0.5 + 0.5 * sin(anim_time * 28.0 + burst_phase)
	var facing := 1.0 if target_side == "enemy" else -1.0

	if status == "shield_active":
		for arc_i in range(3):
			var radius := 17.0 + float(arc_i) * 10.0 + pulse * 3.0
			var start_angle := -1.08 if target_side == "enemy" else PI - 1.08
			canvas.draw_arc(target, radius, start_angle, start_angle + 2.16, 30, Color(glow.r, glow.g, glow.b, (0.28 - float(arc_i) * 0.055) * alpha), 2.0, true)
		for chip in range(6):
			var chip_pos := target - path_dir * (6.0 + float(chip) * 4.0) + Vector2(0.0, (float(chip) - 2.5) * 4.0)
			canvas.draw_line(chip_pos, chip_pos - path_dir * (8.0 + pulse * 5.0), Color(spark.r, spark.g, spark.b, 0.28 * alpha), 1.0, true)
		return

	if status == "shield_weak" or status == "shield_failed":
		for chip in range(4):
			var chip_pos := target + Vector2(facing * (12.0 + float(chip) * 4.0), (float(chip) - 1.5) * 6.0)
			canvas.draw_circle(chip_pos, 2.0 + pulse, Color(glow.r, glow.g, glow.b, 0.18 * alpha))
		if status == "shield_weak":
			return

	var hull_pos := target + Vector2(facing * 12.0, 0.0)
	canvas.draw_circle(hull_pos, 10.0 + pulse * 6.0, Color(glow.r, glow.g, glow.b, 0.18 * alpha))
	canvas.draw_circle(hull_pos, 4.0 + pulse * 2.0, Color(core.r, core.g, core.b, 0.72 * alpha))
	canvas.draw_line(hull_pos - path_dir * 8.0, hull_pos + path_dir * 22.0, Color(metal.r, metal.g, metal.b, 0.34 * alpha), 2.0, true)
	for spark_i in range(8):
		var angle := float(spark_i) * TAU / 8.0 + anim_time * 0.8
		var spark_dir := Vector2(cos(angle), sin(angle))
		canvas.draw_line(hull_pos, hull_pos + spark_dir * (8.0 + pulse * 10.0), Color(spark.r, spark.g, spark.b, 0.30 * alpha), 1.0, true)


func build_attack_context(packet: Dictionary) -> Dictionary:
	var family := get_visual_family(packet)
	var owner_side := clean_side(str(packet.get("source_side", packet.get("owner_side", packet.get("event_side", "")))))
	if owner_side == "":
		owner_side = "enemy" if family == "punch" else "player"
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

	if item_id.find("spike_driver") >= 0 or action_id == "fire_spike_driver" or same_type_key.find("spike_driver") >= 0 or item_name.find("spike driver") >= 0:
		return "spike"
	if item_id.find("guardian_punch_driver") >= 0 or action_id == "fire_guardian_punch_driver" or same_type_key.find("punch_driver") >= 0 or item_name.find("punch driver") >= 0:
		return "punch"

	if string_array_has(packet.get("labels", []), "secondary_weapon_kinetic") and string_array_has(packet.get("labels", []), "ammo_group_medium"):
		if item_name.find("spike") >= 0 or item_id.find("spike") >= 0:
			return "spike"
		if item_name.find("punch") >= 0 or item_id.find("punch") >= 0:
			return "punch"
	return ""


func get_family_colors(family: String) -> Dictionary:
	if family == "punch":
		return {
			"metal": PUNCH_METAL,
			"core": PUNCH_CORE,
			"glow": PUNCH_GLOW,
			"shadow": PUNCH_SHADOW
		}
	return {
		"metal": SPIKE_METAL,
		"core": SPIKE_CORE,
		"glow": SPIKE_GLOW,
		"shadow": SPIKE_GLOW
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
