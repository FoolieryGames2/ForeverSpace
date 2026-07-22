extends RefCounted

class_name BattleV2IonThreaderMK1UI

# Visual-only handler for Ion Threader MK1 and its enemy mirror, Vayrax Needler Lance MK1.
# Safe contract: this script only draws. It never changes battle state, damage, TODO timing, cooldowns, or inventory.

const ION_ITEM_ID := "ion_threader_mk1"
const LANCE_ITEM_ID := "vayrax_needler_lance_mk1"

# Player Ion Threader: colder, cleaner, more AMI-blue.
const ION_PRIMARY := Color(0.06, 0.58, 1.0, 1.0)
const ION_CORE := Color(0.55, 0.92, 1.0, 1.0)
const ION_HOT := Color(0.86, 1.0, 1.0, 1.0)
const ION_DAMAGE := Color(0.72, 0.94, 1.0, 1.0)

# Enemy Lance: red, hostile, slightly dirty/violet.
const LANCE_PRIMARY := Color(1.0, 0.10, 0.04, 1.0)
const LANCE_CORE := Color(1.0, 0.38, 0.22, 1.0)
const LANCE_HOT := Color(1.0, 0.80, 0.38, 1.0)
const LANCE_DAMAGE := Color(1.0, 0.18, 0.08, 1.0)
const LANCE_GHOST := Color(0.72, 0.10, 1.0, 1.0)


func matches_packet(packet: Dictionary) -> bool:
	return get_visual_family(packet) != ""


func draw_action_click(canvas: Control, packet: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(packet):
		return false

	var context := build_attack_context(packet)
	var colors := get_family_colors(str(context.get("family", "ion")))
	var owner_side := str(context.get("owner_side", "player"))
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
	var wobble_scale := 7.0 if bool(context.get("is_lance", false)) else 3.0
	var wobble := Vector2(0.0, sin(anim_time * 28.0 + t * 10.0) * wobble_scale)

	var primary: Color = colors.get("primary", ION_PRIMARY)
	var core: Color = colors.get("core", ION_CORE)
	var hot: Color = colors.get("hot", ION_HOT)

	canvas.draw_line(start, pos + wobble, Color(primary.r, primary.g, primary.b, 0.34 * alpha), 2.0, true)
	canvas.draw_circle(pos + wobble, 18.0 + 12.0 * t, Color(primary.r, primary.g, primary.b, 0.09 * alpha))
	canvas.draw_circle(pos + wobble, 5.0 + 3.0 * t, Color(core.r, core.g, core.b, 0.86 * alpha))

	for i in range(3):
		var spark_t = clamp(t - float(i) * 0.12, 0.0, 1.0)
		var spark_pos := start.lerp(finish, spark_t) + Vector2(0.0, sin(anim_time * 18.0 + float(i) * 1.7) * (6.0 if owner_side == "enemy" else 4.0))
		canvas.draw_circle(spark_pos, 2.0, Color(hot.r, hot.g, hot.b, 0.60 * alpha))

	return true


func draw_todo_event(canvas: Control, event_summary: Dictionary, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	if not matches_packet(event_summary):
		return false

	var context := build_attack_context(event_summary)
	var owner_side := str(context.get("owner_side", "player"))
	var target_side := str(context.get("target_side", "enemy"))
	var is_lance := bool(context.get("is_lance", false))
	var colors := get_family_colors(str(context.get("family", "ion")))

	var progress = clamp(float(event_summary.get("progress", 0.0)), 0.0, 1.0)
	var source_actor := get_anchor_rect(anchors, owner_side + "_actor")
	var target_actor := get_anchor_rect(anchors, target_side + "_actor")
	var combat_lane := get_anchor_rect(anchors, "player_lane")
	if source_actor.size == Vector2.ZERO or target_actor.size == Vector2.ZERO or combat_lane.size == Vector2.ZERO:
		return true

	var dir := 1.0 if owner_side == "player" else -1.0
	var source := source_actor.position + source_actor.size * 0.5 + Vector2(dir * 42.0, 0.0)
	var target := target_actor.position + target_actor.size * 0.5 + Vector2(-dir * 42.0, 0.0)
	var lane_y := combat_lane.position.y + combat_lane.size.y * 0.5
	source.y = lane_y
	target.y = lane_y

	var primary: Color = colors.get("primary", ION_PRIMARY)
	var core: Color = colors.get("core", ION_CORE)
	var hot: Color = colors.get("hot", ION_HOT)
	var ghost: Color = colors.get("ghost", primary)
	var charge_end := source.lerp(target, clamp(progress * 0.84, 0.0, 0.84))
	var beam_ready = progress >= 0.94
	var heat := 0.5 + 0.5 * sin(anim_time * (22.0 if is_lance else 18.0))
	var charge_alpha = 0.22 + progress * 0.56

	# Thin threading guide. Player Ion is smooth. Enemy Lance is jagged and hostile.
	canvas.draw_line(source, target, Color(primary.r, primary.g, primary.b, 0.09), 1.0, true)
	if is_lance:
		draw_jagged_thread(canvas, source, charge_end, primary, ghost, anim_time, charge_alpha)
	else:
		canvas.draw_line(source, charge_end, Color(primary.r, primary.g, primary.b, charge_alpha), 2.2, true)
		canvas.draw_line(source + Vector2(0, -7), charge_end + Vector2(0, -7), Color(core.r, core.g, core.b, 0.12 + progress * 0.22), 1.0, true)
		canvas.draw_line(source + Vector2(0, 7), charge_end + Vector2(0, 7), Color(core.r, core.g, core.b, 0.12 + progress * 0.22), 1.0, true)

	# Traveling bead while charging.
	var bead_t := fmod(anim_time * (1.15 if is_lance else 0.9) + progress * 0.35, 1.0)
	var bead := source.lerp(target, bead_t)
	var bead_wobble := 0.0
	if is_lance:
		bead_wobble = sin(anim_time * 32.0 + bead_t * 9.0) * 8.0
	bead.y += bead_wobble
	canvas.draw_circle(bead, 13.0 + heat * 5.0, Color(primary.r, primary.g, primary.b, 0.08 + progress * 0.08))
	canvas.draw_circle(bead, 3.2 + heat * 2.2, Color(core.r, core.g, core.b, 0.68))

	# Stable firing read near finish.
	if beam_ready:
		var fire_alpha = clamp((progress - 0.94) / 0.06, 0.0, 1.0)
		if is_lance:
			draw_jagged_thread(canvas, source, target, core, ghost, anim_time + 10.0, 0.90 * fire_alpha, 3.0)
			canvas.draw_line(source, target, Color(primary.r, primary.g, primary.b, 0.30 * fire_alpha), 9.0, true)
		else:
			canvas.draw_line(source, target, Color(core.r, core.g, core.b, 0.92 * fire_alpha), 3.2, true)
			canvas.draw_line(source, target, Color(primary.r, primary.g, primary.b, 0.42 * fire_alpha), 8.0, true)
		draw_energy_contact(canvas, target, target_side, unit_state, colors, anim_time, fire_alpha, is_lance)

	# Tiny side filaments so it reads as a threader/lance, not a fat laser.
	var filament_count := 7 if is_lance else 5
	for i in range(filament_count):
		var filament_t = clamp(progress - float(i) * 0.075, 0.0, 1.0)
		var x = lerp(source.x, target.x, filament_t)
		var wiggle := sin(anim_time * (11.0 if is_lance else 8.0) + float(i) * 1.3) * (14.0 if is_lance else 10.0)
		var y := lane_y + wiggle
		canvas.draw_circle(Vector2(x, y), 1.8, Color(hot.r, hot.g, hot.b, 0.38 + progress * 0.26))

	return true


func draw_jagged_thread(canvas: Control, start: Vector2, finish: Vector2, primary: Color, ghost: Color, anim_time: float, alpha: float, width: float = 2.0) -> void:
	var points := PackedVector2Array()
	var segment_count := 9
	for i in range(segment_count + 1):
		var t := float(i) / float(segment_count)
		var p := start.lerp(finish, t)
		if i > 0 and i < segment_count:
			p.y += sin(anim_time * 18.0 + float(i) * 2.21) * 7.5
			p.y += cos(anim_time * 7.5 + float(i) * 1.37) * 3.5
		points.append(p)
	canvas.draw_polyline(points, Color(primary.r, primary.g, primary.b, alpha), width, true)
	canvas.draw_polyline(points, Color(ghost.r, ghost.g, ghost.b, alpha * 0.22), width + 4.0, true)


func draw_energy_contact(canvas: Control, target: Vector2, target_side: String, unit_state: Dictionary, colors: Dictionary, anim_time: float, alpha: float, is_lance: bool) -> void:
	var target_state := get_unit_state(unit_state, target_side)
	var shield_current := float(target_state.get("shield_current", 0.0))
	var shield_max = max(float(target_state.get("shield_max", 0.0)), 0.0)
	var shield_state := str(target_state.get("shield_state", "active")).strip_edges().to_lower()
	var shield_has_energy := bool(target_state.get("shield_has_energy", true))

	var has_shield_capacity = shield_max > 0.0
	var shield_blocks_hit = has_shield_capacity and shield_current > 0.0 and shield_state != "broken" and shield_state != "down" and shield_state != "offline" and shield_state != "none"
	var shield_is_weak := shield_state == "no_energy" or not shield_has_energy
	var pulse := 0.5 + 0.5 * sin(anim_time * (30.0 if is_lance else 24.0))

	var primary: Color = colors.get("primary", ION_PRIMARY)
	var core: Color = colors.get("core", ION_CORE)
	var damage: Color = colors.get("damage", ION_DAMAGE)
	var ghost: Color = colors.get("ghost", primary)

	if shield_blocks_hit:
		var shield_alpha_scale := 0.52 if shield_is_weak else 1.0
		for ring in range(3):
			var radius := 18.0 + float(ring) * 11.0 + pulse * 4.0
			var ring_alpha := (0.36 - float(ring) * 0.075) * alpha * shield_alpha_scale
			if is_lance:
				canvas.draw_arc(target, radius, PI - 0.95, PI + 0.95, 32, Color(primary.r, primary.g, primary.b, ring_alpha), 2.0, true)
				canvas.draw_arc(target, radius + 5.0, PI - 0.35, PI + 0.35, 24, Color(ghost.r, ghost.g, ghost.b, ring_alpha * 0.75), 1.4, true)
			else:
				canvas.draw_arc(target, radius, -0.95, 0.95, 32, Color(primary.r, primary.g, primary.b, ring_alpha), 2.0, true)
		canvas.draw_circle(target, 8.0 + pulse * 4.0, Color(core.r, core.g, core.b, 0.22 * alpha * shield_alpha_scale))
		return

	# Shield existed but failed/missing power: show the missing shield read first, then extra hull-damage-looking pop.
	if has_shield_capacity:
		for shard in range(3):
			var radius := 22.0 + float(shard) * 12.0 + pulse * 2.5
			var start_angle := (-0.75 + float(shard) * 0.35) if not is_lance else (PI - 0.75 + float(shard) * 0.35)
			canvas.draw_arc(target, radius, start_angle, start_angle + 0.38, 16, Color(primary.r, primary.g, primary.b, 0.14 * alpha), 1.4, true)

	# Hull contact. Offset inward toward the target actor so it reads as damage after shield check.
	var hull_dir := 1.0 if target_side == "enemy" else -1.0
	var hull_point := target + Vector2(hull_dir * 13.0, 0.0)
	var hull_radius := 11.0 + pulse * (5.0 if is_lance else 4.0)
	canvas.draw_circle(hull_point, hull_radius + 7.0, Color(damage.r, damage.g, damage.b, 0.12 * alpha))
	canvas.draw_circle(hull_point, hull_radius, Color(damage.r, damage.g, damage.b, 0.34 * alpha))
	canvas.draw_circle(hull_point, 3.8, Color(core.r, core.g, core.b, 0.90 * alpha))

	if is_lance:
		for i in range(4):
			var spike := hull_point + Vector2(hull_dir * (6.0 + float(i) * 4.0), sin(anim_time * 19.0 + float(i)) * 7.0)
			canvas.draw_line(hull_point, spike, Color(LANCE_DAMAGE.r, LANCE_DAMAGE.g, LANCE_DAMAGE.b, 0.34 * alpha), 1.2, true)


func build_attack_context(packet: Dictionary) -> Dictionary:
	var family := get_visual_family(packet)
	var is_lance := family == "lance"
	var owner_side := clean_side(str(packet.get("source_side", packet.get("owner_side", packet.get("event_side", "")))))
	if owner_side == "":
		owner_side = "enemy" if is_lance else "player"
	var target_side := clean_side(str(packet.get("target_side", "")))
	if target_side == "":
		target_side = get_opposite_side(owner_side)
	return {
		"family": family,
		"is_lance": is_lance,
		"owner_side": owner_side,
		"target_side": target_side
	}


func get_visual_family(packet: Dictionary) -> String:
	var item_id := str(packet.get("item_id", "")).strip_edges().to_lower()
	var item_name := str(packet.get("item_name", packet.get("display_text", packet.get("row_text", "")))).strip_edges().to_lower()
	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	var same_type_key := str(packet.get("same_type_key", "")).strip_edges().to_lower()

	if item_id == ION_ITEM_ID or item_id.find("ion_threader") >= 0 or action_id == "fire_ion_threader" or same_type_key.find("ion_threader") >= 0:
		return "ion"
	if item_name.find("ion threader") >= 0:
		return "ion"

	if item_id == LANCE_ITEM_ID or item_id.find("vayrax_needler_lance") >= 0 or action_id == "fire_vayrax_needler_lance" or same_type_key.find("vayrax_needler_lance") >= 0:
		return "lance"
	if item_name.find("needler lance") >= 0 or item_name.find("vayrax needler") >= 0:
		return "lance"

	if string_array_has(packet.get("labels", []), "primary_weapon_energy") and string_array_has(packet.get("labels", []), "tier_1"):
		if item_name.find("thread") >= 0 or item_id.find("threader") >= 0:
			return "ion"
		if item_name.find("lance") >= 0 or item_id.find("lance") >= 0:
			return "lance"

	return ""


func get_family_colors(family: String) -> Dictionary:
	if family == "lance":
		return {
			"primary": LANCE_PRIMARY,
			"core": LANCE_CORE,
			"hot": LANCE_HOT,
			"damage": LANCE_DAMAGE,
			"ghost": LANCE_GHOST
		}
	return {
		"primary": ION_PRIMARY,
		"core": ION_CORE,
		"hot": ION_HOT,
		"damage": ION_DAMAGE,
		"ghost": ION_PRIMARY
	}


func get_unit_state(unit_state: Dictionary, side: String) -> Dictionary:
	var value = unit_state.get(side, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func clean_side(value: String) -> String:
	var side := value.strip_edges().to_lower()
	if side == "enemy":
		return "enemy"
	if side == "player":
		return "player"
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
