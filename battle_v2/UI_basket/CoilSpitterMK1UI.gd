extends RefCounted

class_name BattleV2CoilSpitterMK1UI

# Visual-only handler for Coil Spitter MK1.
# Safe contract: this script only draws. It never changes battle state, damage, TODO timing, cooldowns, ammo, or inventory.

const ITEM_ID := "coil_spitter_mk1"
const SPRING_COLOR := Color(0.36, 0.82, 1.0, 1.0)
const CORE_COLOR := Color(0.74, 0.96, 1.0, 1.0)
const SPARK_COLOR := Color(0.92, 0.84, 0.34, 1.0)
const BLUE_SPARK_COLOR := Color(0.12, 0.58, 1.0, 1.0)
const DEEP_BLUE_COLOR := Color(0.08, 0.26, 0.86, 1.0)
const HULL_HOT_COLOR := Color(1.0, 0.46, 0.16, 1.0)


func matches_packet(packet: Dictionary) -> bool:
	var item_id := str(packet.get("item_id", "")).strip_edges().to_lower()
	if item_id == ITEM_ID:
		return true

	var item_name := str(packet.get("item_name", packet.get("display_text", packet.get("display_name", "")))).strip_edges().to_lower()
	if item_name.find("coil spitter") >= 0:
		return true

	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	if action_id == "fire_coil_spitter":
		return true

	var same_type_key := str(packet.get("same_type_key", "")).strip_edges().to_lower()
	if same_type_key.find("coil_spitter") >= 0:
		return true

	if string_array_has(packet.get("labels", []), "secondary_weapon_kinetic") and string_array_has(packet.get("labels", []), "tier_1"):
		return item_name.find("coil") >= 0 or item_id.find("coil") >= 0 or same_type_key.find("coil") >= 0

	return false


func draw_action_click(canvas: Control, packet: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(packet):
		return false

	var age := float(packet.get("age", 0.0))
	var duration = max(float(packet.get("duration", 0.72)), 0.01)
	var t = clamp(age / duration, 0.0, 1.0)
	var alpha = 1.0 - t

	var action_rect := get_anchor_rect(anchors, "player_action")
	var todo_rect := get_anchor_rect(anchors, "todo")
	if action_rect.size == Vector2.ZERO or todo_rect.size == Vector2.ZERO:
		return true

	var start := action_rect.position + action_rect.size * 0.5
	var finish := todo_rect.position + todo_rect.size * 0.5
	var head := start.lerp(finish, t)
	var dir := (finish - start).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2(-1.0, 0.0)
	var tail = head - dir * (42.0 + t * 18.0)

	canvas.draw_line(start, head, Color(SPRING_COLOR.r, SPRING_COLOR.g, SPRING_COLOR.b, 0.12 * alpha), 1.4, true)
	draw_spring_segment(canvas, tail, head, anim_time, 5, 5.5, 1.0, alpha)
	canvas.draw_circle(head, 13.0 + t * 8.0, Color(SPRING_COLOR.r, SPRING_COLOR.g, SPRING_COLOR.b, 0.08 * alpha))
	canvas.draw_circle(head, 4.0 + t * 2.0, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.82 * alpha))

	for i in range(3):
		var spark_t = clamp(t - float(i) * 0.10, 0.0, 1.0)
		var spark_pos := start.lerp(finish, spark_t)
		var hop := sin(anim_time * 24.0 + float(i) * 1.6) * 5.0
		canvas.draw_circle(spark_pos + Vector2(0.0, hop), 2.3, Color(SPARK_COLOR.r, SPARK_COLOR.g, SPARK_COLOR.b, 0.55 * alpha))

	return true


func draw_todo_event(canvas: Control, event_summary: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(event_summary):
		return false

	var side := get_packet_side(event_summary)
	var target_side := "enemy" if side == "player" else "player"
	var source_actor := get_anchor_rect(anchors, side + "_actor")
	var target_actor := get_anchor_rect(anchors, target_side + "_actor")
	var lane_rect := get_anchor_rect(anchors, side + "_lane")
	if source_actor.size == Vector2.ZERO or target_actor.size == Vector2.ZERO or lane_rect.size == Vector2.ZERO:
		return true

	var progress = clamp(float(event_summary.get("progress", 0.0)), 0.0, 1.0)
	var burst_index = max(int(event_summary.get("burst_index", 1)), 1)
	var burst_total = max(int(event_summary.get("burst_total", event_summary.get("burst_count", 4))), 1)
	var lane_y := lane_rect.position.y + lane_rect.size.y * 0.5
	var burst_offset := (float(burst_index) - (float(burst_total) + 1.0) * 0.5) * 9.0
	burst_offset += sin(anim_time * 5.0 + float(burst_index) * 1.2) * 2.5

	var dir_sign := 1.0 if side == "player" else -1.0
	var source := source_actor.position + source_actor.size * 0.5 + Vector2(dir_sign * 44.0, 0.0)
	var target := target_actor.position + target_actor.size * 0.5 + Vector2(-dir_sign * 46.0, 0.0)
	source.y = lane_y + burst_offset
	target.y = lane_y + burst_offset

	var travel_data := build_mid_spring_travel(source, target, progress, anim_time, float(burst_index))
	var travel_t := float(travel_data.get("travel_t", progress))
	var head: Vector2 = travel_data.get("head", source.lerp(target, travel_t))
	var spring_stage := str(travel_data.get("stage", "travel"))
	var compression := float(travel_data.get("compression", 0.0))
	var path_dir := (target - source).normalized()
	if path_dir == Vector2.ZERO:
		path_dir = Vector2(dir_sign, 0.0)
	var tail_len := 68.0 + 14.0 * sin(anim_time * 8.0 + float(burst_index))
	if spring_stage == "compress":
		tail_len = 48.0 + compression * 34.0
	elif spring_stage == "snap":
		tail_len = 92.0 + compression * 38.0
	var tail := head - path_dir * tail_len
	var heat := 0.5 + 0.5 * sin(anim_time * 18.0 + float(burst_index) * 0.8)
	var alpha = 0.30 + progress * 0.64
	if spring_stage == "compress":
		alpha += compression * 0.18
	elif spring_stage == "snap":
		alpha += 0.22

	# Faint lane guide for this individual burst.
	canvas.draw_line(source, target, Color(SPRING_COLOR.r, SPRING_COLOR.g, SPRING_COLOR.b, 0.055), 1.0, true)
	canvas.draw_line(source, head, Color(SPRING_COLOR.r, SPRING_COLOR.g, SPRING_COLOR.b, 0.10 + progress * 0.16), 1.5, true)
	if spring_stage == "compress":
		draw_mid_compression_field(canvas, head, path_dir, anim_time, compression, alpha)

	# The actual "spring shot" projectile. It compresses near mid-lane, then snaps forward near finish.
	var coil_count := 8
	var coil_amp := 7.5 + heat * 2.0
	if spring_stage == "compress":
		coil_count = 11
		coil_amp = 5.0 + compression * 4.0
	elif spring_stage == "snap":
		coil_count = 6
		coil_amp = 9.0 + heat * 3.0
	draw_spring_segment(canvas, tail, head, anim_time + float(burst_index) * 0.35, coil_count, coil_amp, 1.25, alpha)
	draw_spring_shell(canvas, head, path_dir, anim_time, float(burst_index), alpha, spring_stage, compression)

	# Small burst-index bead stack so the 4 stacked Coil TODOs do not read as one single shot.
	var tag_pos := source + Vector2(0.0, -14.0)
	for bead in range(burst_total):
		var bead_alpha := 0.18 if bead + 1 != burst_index else 0.58
		canvas.draw_circle(tag_pos + Vector2(float(bead) * 7.0, 0.0), 2.2 if bead + 1 != burst_index else 3.4, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, bead_alpha + 0.10 * heat))

	if progress >= 0.86:
		var contact_alpha = clamp((progress - 0.86) / 0.14, 0.0, 1.0)
		draw_coil_contact(canvas, target, target_side, unit_state, anim_time, float(burst_index), contact_alpha)

	return true


func build_mid_spring_travel(source: Vector2, target: Vector2, progress: float, anim_time: float, burst_phase: float) -> Dictionary:
	# Coil Spitter timing language:
	# 1) travel toward the middle,
	# 2) slow/compress around mid-lane,
	# 3) snap to the target at the last moment.
	var clean = clamp(progress, 0.0, 1.0)
	var mid_t := 0.54
	var mid := source.lerp(target, mid_t)
	var path_dir := (target - source).normalized()
	if path_dir == Vector2.ZERO:
		path_dir = Vector2.RIGHT
	var perp := Vector2(-path_dir.y, path_dir.x)
	var wobble := perp * sin(anim_time * 15.0 + burst_phase * 1.7) * 4.0

	if clean < 0.62:
		var t = clean / 0.62
		# Ease-out means the projectile visibly slows as it arrives at the middle, not at the target.
		var slow_mid := 1.0 - pow(1.0 - t, 3.2)
		var travel_t = lerp(0.0, mid_t, slow_mid)
		return {
			"stage": "travel",
			"travel_t": travel_t,
			"head": source.lerp(target, travel_t),
			"compression": 0.0,
		}

	if clean < 0.84:
		var t = (clean - 0.62) / 0.22
		var compression = 0.35 + t * 0.65
		# Stay near the middle while the coil winds up. Small forward/back vibration sells stored spring force.
		var windup = sin(anim_time * 24.0 + burst_phase) * (8.0 + compression * 8.0)
		var head = mid + path_dir * windup + wobble * compression
		return {
			"stage": "compress",
			"travel_t": mid_t,
			"head": head,
			"compression": compression,
		}

	var snap_t = (clean - 0.84) / 0.16
	# Sharp spring finish: starts very fast after compression, then lands clean at target.
	var spring = ease_out_snap(snap_t)
	var travel_t = lerp(mid_t, 1.0, spring)
	var recoil = path_dir * sin((1.0 - snap_t) * PI * 2.0) * (10.0 * (1.0 - snap_t))
	return {
		"stage": "snap",
		"travel_t": travel_t,
		"head": source.lerp(target, travel_t) - recoil,
		"compression": 1.0 - snap_t,
	}


func ease_out_snap(t: float) -> float:
	var clean = clamp(t, 0.0, 1.0)
	# Fast release without overshooting past target; good for a spring finish that stays truthful to hit position.
	return clamp(1.0 - pow(1.0 - clean, 4.6), 0.0, 1.0)


func draw_mid_compression_field(canvas: Control, center: Vector2, path_dir: Vector2, anim_time: float, compression: float, alpha: float) -> void:
	var perp := Vector2(-path_dir.y, path_dir.x)
	var pulse := 0.5 + 0.5 * sin(anim_time * 20.0)
	for ring in range(3):
		var spread := 10.0 + float(ring) * 9.0 + pulse * 4.0
		canvas.draw_arc(center, spread, -2.35, 2.35, 28, Color(BLUE_SPARK_COLOR.r, BLUE_SPARK_COLOR.g, BLUE_SPARK_COLOR.b, (0.16 - float(ring) * 0.035) * alpha * compression), 1.2, true)
	for side in [-1.0, 1.0]:
		var a = center + perp * side * (8.0 + compression * 8.0) - path_dir * 18.0
		var b = center + perp * side * (4.0 + compression * 4.0) + path_dir * 18.0
		canvas.draw_line(a, b, Color(DEEP_BLUE_COLOR.r, DEEP_BLUE_COLOR.g, DEEP_BLUE_COLOR.b, 0.18 * alpha * compression), 1.0, true)


func draw_spring_segment(canvas: Control, a: Vector2, b: Vector2, anim_time: float, coils: int, amplitude: float, width: float, alpha: float) -> void:
	var diff := b - a
	var length := diff.length()
	if length <= 1.0:
		return
	var dir := diff / length
	var perp := Vector2(-dir.y, dir.x)
	var point_count = max(coils * 6, 12)
	var points := PackedVector2Array()
	for i in range(point_count + 1):
		var t := float(i) / float(point_count)
		var wave := sin(t * TAU * float(coils) + anim_time * 10.0) * amplitude
		var taper := sin(t * PI)
		points.append(a.lerp(b, t) + perp * wave * taper)

	canvas.draw_polyline(points, Color(DEEP_BLUE_COLOR.r, DEEP_BLUE_COLOR.g, DEEP_BLUE_COLOR.b, 0.24 * alpha), width + 1.35, true)
	canvas.draw_polyline(points, Color(SPRING_COLOR.r, SPRING_COLOR.g, SPRING_COLOR.b, 0.58 * alpha), width, true)
	canvas.draw_polyline(points, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.24 * alpha), max(width * 0.55, 0.7), true)

	for ring in range(coils):
		var t := (float(ring) + 0.5) / float(coils)
		var center := a.lerp(b, t)
		var pulse := 0.5 + 0.5 * sin(anim_time * 12.0 + float(ring))
		canvas.draw_circle(center, 3.0 + pulse * 1.6, Color(BLUE_SPARK_COLOR.r, BLUE_SPARK_COLOR.g, BLUE_SPARK_COLOR.b, 0.16 * alpha))
		canvas.draw_circle(center, 2.0 + pulse * 1.1, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.25 * alpha))


func draw_spring_shell(canvas: Control, head: Vector2, path_dir: Vector2, anim_time: float, burst_phase: float, alpha: float, spring_stage: String = "travel", compression: float = 0.0) -> void:
	var perp := Vector2(-path_dir.y, path_dir.x)
	var pulse := 0.5 + 0.5 * sin(anim_time * 24.0 + burst_phase)
	var shell_boost := 1.0
	if spring_stage == "compress":
		shell_boost = 1.0 + compression * 0.65
	elif spring_stage == "snap":
		shell_boost = 1.35
	canvas.draw_circle(head, (10.0 + pulse * 3.6) * shell_boost, Color(DEEP_BLUE_COLOR.r, DEEP_BLUE_COLOR.g, DEEP_BLUE_COLOR.b, 0.09 * alpha))
	canvas.draw_circle(head, (8.0 + pulse * 2.5) * shell_boost, Color(SPRING_COLOR.r, SPRING_COLOR.g, SPRING_COLOR.b, 0.11 * alpha))
	canvas.draw_circle(head, 3.8 + pulse * 1.4, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.82 * alpha))
	canvas.draw_line(head - perp * 8.0, head + perp * 8.0, Color(BLUE_SPARK_COLOR.r, BLUE_SPARK_COLOR.g, BLUE_SPARK_COLOR.b, 0.32 * alpha), 1.2, true)
	canvas.draw_line(head - path_dir * 12.0, head - path_dir * 34.0, Color(SPRING_COLOR.r, SPRING_COLOR.g, SPRING_COLOR.b, 0.25 * alpha), 1.7, true)
	if spring_stage == "snap":
		canvas.draw_line(head - path_dir * 10.0, head - path_dir * 58.0, Color(BLUE_SPARK_COLOR.r, BLUE_SPARK_COLOR.g, BLUE_SPARK_COLOR.b, 0.24 * alpha), 1.1, true)


func draw_coil_contact(canvas: Control, target: Vector2, target_side: String, unit_state: Dictionary, anim_time: float, burst_phase: float, alpha: float) -> void:
	var state := get_contact_status(target_side, unit_state)
	var pulse := 0.5 + 0.5 * sin(anim_time * 28.0 + burst_phase)

	if state == "shield_active":
		# Kinetic hit stops at shield surface: hard wall tick, no hull pop.
		for arc_i in range(3):
			var radius := 16.0 + float(arc_i) * 9.0 + pulse * 3.5
			canvas.draw_arc(target, radius, -1.15, 1.15, 32, Color(SPRING_COLOR.r, SPRING_COLOR.g, SPRING_COLOR.b, (0.34 - float(arc_i) * 0.07) * alpha), 2.0, true)
		for spark in range(6):
			var angle := -0.8 + float(spark) * 0.32 + sin(anim_time * 8.0 + float(spark)) * 0.05
			var dir := Vector2(cos(angle), sin(angle))
			canvas.draw_line(target, target + dir * (12.0 + pulse * 8.0), Color(SPARK_COLOR.r, SPARK_COLOR.g, SPARK_COLOR.b, 0.42 * alpha), 1.2, true)
		canvas.draw_circle(target, 5.0 + pulse * 3.0, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, 0.26 * alpha))
		return

	if state == "shield_weak":
		# No-energy shield read: faint containment plus a few leaking kinetic flecks.
		for arc_i in range(2):
			var radius := 17.0 + float(arc_i) * 12.0 + pulse * 4.0
			canvas.draw_arc(target, radius, -0.88, 0.88, 24, Color(SPRING_COLOR.r, SPRING_COLOR.g, SPRING_COLOR.b, 0.16 * alpha), 1.4, true)
		for spark in range(4):
			var offset := Vector2(8.0 + float(spark) * 3.0, sin(anim_time * 7.0 + float(spark)) * 8.0)
			canvas.draw_circle(target + offset, 2.0 + pulse, Color(SPARK_COLOR.r, SPARK_COLOR.g, SPARK_COLOR.b, 0.26 * alpha))
		return

	if state == "shield_failed":
		# Shield existed but failed: draw broken shield chips first, then hull contact.
		for chip in range(5):
			var angle := float(chip) * TAU / 5.0 + anim_time * 0.5
			var chip_pos := target + Vector2(cos(angle), sin(angle)) * (18.0 + pulse * 5.0)
			canvas.draw_line(chip_pos, chip_pos + Vector2(cos(angle), sin(angle)) * 8.0, Color(SPRING_COLOR.r, SPRING_COLOR.g, SPRING_COLOR.b, 0.18 * alpha), 1.0, true)

	# No shield, or failed shield after chips: hard hull sparks.
	var hull_pos := target + Vector2(10.0 if target_side == "enemy" else -10.0, 0.0)
	canvas.draw_circle(hull_pos, 11.0 + pulse * 5.0, Color(HULL_HOT_COLOR.r, HULL_HOT_COLOR.g, HULL_HOT_COLOR.b, 0.22 * alpha))
	canvas.draw_circle(hull_pos, 4.0 + pulse * 2.0, Color(SPARK_COLOR.r, SPARK_COLOR.g, SPARK_COLOR.b, 0.72 * alpha))
	for spark in range(7):
		var angle := float(spark) * TAU / 7.0 + anim_time * 1.4
		var dir := Vector2(cos(angle), sin(angle))
		canvas.draw_line(hull_pos, hull_pos + dir * (8.0 + pulse * 9.0), Color(SPARK_COLOR.r, SPARK_COLOR.g, SPARK_COLOR.b, 0.34 * alpha), 1.2, true)


func get_contact_status(side: String, unit_state: Dictionary) -> String:
	var data := get_unit_state(side, unit_state)
	var shield_current := float(data.get("shield_current", 0.0))
	var shield_max = max(float(data.get("shield_max", 0.0)), 0.0)
	var state := str(data.get("shield_state", "active")).strip_edges().to_lower()
	var has_energy := bool(data.get("shield_has_energy", true))

	if shield_max <= 0.0:
		return "no_shield"
	if shield_current <= 0.0 or state == "broken" or state == "down" or state == "disabled" or state == "none":
		return "shield_failed"
	if not has_energy or state == "no_energy":
		return "shield_weak"
	return "shield_active"


func get_unit_state(side: String, unit_state: Dictionary) -> Dictionary:
	var data = unit_state.get(side, {})
	if typeof(data) == TYPE_DICTIONARY:
		return data
	return {}


func get_packet_side(packet: Dictionary) -> String:
	var side := str(packet.get("event_side", packet.get("owner_side", packet.get("source_side", "player")))).strip_edges().to_lower()
	if side == "enemy":
		return "enemy"
	return "player"


func ease_out_backlite(t: float) -> float:
	# Slight overshoot-feeling timing without actually traveling past the target.
	var clean = clamp(t, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - clean, 2.6)
	return clamp(eased, 0.0, 1.0)


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
