extends Control

class_name BattleV2ProceduralLaneLayer

const IonThreaderMK1UIScript = preload("res://battle_v2/UI_basket/IonThreaderMK1UI.gd")
const DroneOrbitUIScript = preload("res://battle_v2/UI_basket/DroneOrbitUI.gd")
const CoilSpitterMK1UIScript = preload("res://battle_v2/UI_basket/CoilSpitterMK1UI.gd")
const BreachChargeUIScript = preload("res://battle_v2/UI_basket/BreachChargeUI.gd")
const BusterChargeUIScript = preload("res://battle_v2/UI_basket/BusterChargeUI.gd")
const SmartGuyFocusLanceUIScript = preload("res://battle_v2/UI_basket/SmartGuyFocusLanceUI.gd")
const SmartGuyCalculatedRailUIScript = preload("res://battle_v2/UI_basket/SmartGuyCalculatedRailUI.gd")
const SmartGuyMirrorShieldUIScript = preload("res://battle_v2/UI_basket/SmartGuyMirrorShieldUI.gd")
const SmartGuyPatchCellUIScript = preload("res://battle_v2/UI_basket/SmartGuyPatchCellUI.gd")
const RepairKitUIScript = preload("res://battle_v2/UI_basket/RepairKitUI.gd")
const RechargeKitUIScript = preload("res://battle_v2/UI_basket/RechargeKitUI.gd")

const DEFAULT_SIZE := Vector2(1280, 760)
const PLAYER_COLOR := Color(0.10, 0.68, 1.0, 1.0)
const PLAYER_CORE := Color(0.54, 0.96, 1.0, 1.0)
const ENEMY_COLOR := Color(1.0, 0.20, 0.10, 1.0)
const ENEMY_CORE := Color(1.0, 0.62, 0.34, 1.0)
const TODO_COLOR := Color(0.76, 0.25, 1.0, 1.0)
const SLOT_COLOR := Color(0.94, 0.82, 0.44, 1.0)

var anchors: Dictionary = {}
var unit_state: Dictionary = {}
var event_summaries: Array = []
var action_pulses: Array = []
var anim_time: float = 0.0
var ion_threader_mk1_ui: RefCounted = null
var drone_orbit_ui: RefCounted = null
var coil_spitter_mk1_ui: RefCounted = null
var breach_charge_ui: RefCounted = null
var buster_charge_ui: RefCounted = null
var smart_guy_focus_lance_ui: RefCounted = null
var smart_guy_calculated_rail_ui: RefCounted = null
var smart_guy_mirror_shield_ui: RefCounted = null
var smart_guy_patch_cell_ui: RefCounted = null
var repair_kit_ui: RefCounted = null
var recharge_kit_ui: RefCounted = null
var damage_pulses: Array = []
var slot_snapshot: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size == Vector2.ZERO:
		size = DEFAULT_SIZE
	set_process(true)
	setup_ui_basket_handlers()


func setup(config: Dictionary = {}) -> void:
	if config.has("size"):
		size = config.get("size", size)
	if size == Vector2.ZERO:
		size = DEFAULT_SIZE
	if typeof(config.get("anchors", {})) == TYPE_DICTIONARY:
		anchors = config.get("anchors", {}).duplicate(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	setup_ui_basket_handlers()
	queue_redraw()


func setup_ui_basket_handlers() -> void:
	if ion_threader_mk1_ui == null:
		ion_threader_mk1_ui = IonThreaderMK1UIScript.new()
	if drone_orbit_ui == null:
		drone_orbit_ui = DroneOrbitUIScript.new()
	if coil_spitter_mk1_ui == null:
		coil_spitter_mk1_ui = CoilSpitterMK1UIScript.new()
	if breach_charge_ui == null:
		breach_charge_ui = BreachChargeUIScript.new()
	if buster_charge_ui == null:
		buster_charge_ui = BusterChargeUIScript.new()
	if smart_guy_focus_lance_ui == null:
		smart_guy_focus_lance_ui = SmartGuyFocusLanceUIScript.new()
	if smart_guy_calculated_rail_ui == null:
		smart_guy_calculated_rail_ui = SmartGuyCalculatedRailUIScript.new()
	if smart_guy_mirror_shield_ui == null:
		smart_guy_mirror_shield_ui = SmartGuyMirrorShieldUIScript.new()
	if smart_guy_patch_cell_ui == null:
		smart_guy_patch_cell_ui = SmartGuyPatchCellUIScript.new()
	if repair_kit_ui == null:
		repair_kit_ui = RepairKitUIScript.new()
	if recharge_kit_ui == null:
		recharge_kit_ui = RechargeKitUIScript.new()


func set_anchor_data(new_anchors: Dictionary) -> void:
	anchors = new_anchors.duplicate(true)
	queue_redraw()


func set_todo_snapshot(snapshot: Dictionary) -> void:
	event_summaries.clear()
	if typeof(snapshot.get("slots", {})) == TYPE_DICTIONARY:
		slot_snapshot = snapshot.get("slots", {}).duplicate(true)
	else:
		slot_snapshot.clear()
	if typeof(snapshot.get("events", [])) == TYPE_ARRAY:
		for event_summary in snapshot.get("events", []):
			if typeof(event_summary) == TYPE_DICTIONARY:
				event_summaries.append(event_summary.duplicate(true))
	queue_redraw()


func set_unit_state(new_unit_state: Dictionary) -> void:
	unit_state = new_unit_state.duplicate(true)
	queue_redraw()


func set_drone_runtime_packet(packet: Dictionary) -> void:
	setup_ui_basket_handlers()
	if drone_orbit_ui != null and drone_orbit_ui.has_method("set_runtime_packet"):
		drone_orbit_ui.set_runtime_packet(packet, anim_time)
	queue_redraw()


func pulse_action(packet: Dictionary) -> void:
	var pulse := packet.duplicate(true)
	pulse["age"] = 0.0
	pulse["duration"] = 0.72
	action_pulses.append(pulse)
	queue_redraw()


func pulse_damage(packet: Dictionary) -> void:
	var pulse := packet.duplicate(true)
	pulse["age"] = 0.0
	pulse["duration"] = float(pulse.get("duration", 0.82))
	if not pulse.has("ui_seed"):
		pulse["ui_seed"] = build_visual_seed(str(pulse.get("event_id", "")) + str(pulse.get("item_id", "")) + str(damage_pulses.size()))
	damage_pulses.append(pulse)
	queue_redraw()


func _process(delta: float) -> void:
	anim_time += delta
	for i in range(action_pulses.size() - 1, -1, -1):
		var pulse: Dictionary = action_pulses[i]
		pulse["age"] = float(pulse.get("age", 0.0)) + delta
		if float(pulse.get("age", 0.0)) >= float(pulse.get("duration", 0.72)):
			action_pulses.remove_at(i)
		else:
			action_pulses[i] = pulse
	for i in range(damage_pulses.size() - 1, -1, -1):
		var damage_pulse: Dictionary = damage_pulses[i]
		damage_pulse["age"] = float(damage_pulse.get("age", 0.0)) + delta
		if float(damage_pulse.get("age", 0.0)) >= float(damage_pulse.get("duration", 0.82)):
			damage_pulses.remove_at(i)
		else:
			damage_pulses[i] = damage_pulse
	if drone_orbit_ui != null and drone_orbit_ui.has_method("process"):
		drone_orbit_ui.process(delta)
	queue_redraw()


func _draw() -> void:
	draw_lane_field("player")
	draw_lane_field("enemy")
	draw_todo_events()
	draw_action_pulses()
	draw_actor("player")
	draw_actor("enemy")
	draw_actor_shield_overlay("player")
	draw_actor_shield_overlay("enemy")
	draw_ready_overlays()
	draw_drone_runtime()
	draw_damage_pulses()


func draw_lane_field(side: String) -> void:
	var lane_rect := get_anchor_rect(side + "_lane")
	if lane_rect.size == Vector2.ZERO:
		return

	var color := get_side_color(side)
	var center_y := lane_rect.position.y + lane_rect.size.y * 0.5
	var start_x := lane_rect.position.x + 32.0
	var end_x := lane_rect.position.x + lane_rect.size.x - 32.0
	var player_lane_rect := get_anchor_rect("player_lane")
	var enemy_lane_rect := get_anchor_rect("enemy_lane")
	if player_lane_rect == enemy_lane_rect:
		var mid_x := lane_rect.position.x + lane_rect.size.x * 0.5
		if side == "player":
			end_x = mid_x - 18.0
		else:
			start_x = mid_x + 18.0
	var rail_alpha := 0.18 + 0.04 * sin(anim_time * 1.3 + get_side_phase(side))

	draw_line(Vector2(start_x, center_y), Vector2(end_x, center_y), Color(color.r, color.g, color.b, rail_alpha), 2.0, true)
	draw_line(Vector2(start_x, center_y + 18.0), Vector2(end_x, center_y + 18.0), Color(0.96, 0.82, 0.44, 0.055), 1.0, true)

	for i in range(4):
		var slot_t := (float(i) + 1.0) / 5.0
		var x = lerp(start_x, end_x, slot_t)
		var slot_alpha := 0.28 + 0.10 * sin(anim_time * 1.7 + float(i) * 0.9 + get_side_phase(side))
		draw_circle(Vector2(x, center_y), 5.0, Color(SLOT_COLOR.r, SLOT_COLOR.g, SLOT_COLOR.b, slot_alpha))
		draw_circle(Vector2(x, center_y), 11.0, Color(color.r, color.g, color.b, 0.045))
		draw_line(Vector2(x, center_y - 15.0), Vector2(x, center_y + 15.0), Color(SLOT_COLOR.r, SLOT_COLOR.g, SLOT_COLOR.b, 0.12), 1.0, true)


func draw_todo_events() -> void:
	for event_summary in event_summaries:
		if typeof(event_summary) != TYPE_DICTIONARY:
			continue
		if try_draw_ui_basket_todo_event(event_summary):
			continue
		var side := get_event_side(event_summary)
		var color := get_event_color(event_summary, side)
		var progress = clamp(float(event_summary.get("progress", 0.0)), 0.0, 1.0)
		var start := get_anchor_center("todo")
		var finish := get_actor_center(side)
		if start == Vector2.ZERO or finish == Vector2.ZERO:
			continue

		var pos := start.lerp(finish, progress)
		pos.y += sin(anim_time * 2.8 + progress * 4.0 + get_side_phase(side)) * 5.0
		var pulse := 0.5 + 0.5 * sin(anim_time * 5.0 + progress * 7.0)
		draw_circle(pos, 15.0 + pulse * 4.0, Color(color.r, color.g, color.b, 0.11))
		draw_circle(pos, 5.5, Color(color.r, color.g, color.b, 0.82))

		var tail_dir := (start - finish).normalized()
		if tail_dir == Vector2.ZERO:
			tail_dir = Vector2(-1.0, 0.0)
		draw_line(pos, pos + tail_dir * 24.0, Color(color.r, color.g, color.b, 0.42), 2.0, true)


func draw_action_pulses() -> void:
	for pulse in action_pulses:
		if typeof(pulse) != TYPE_DICTIONARY:
			continue
		if try_draw_ui_basket_action_pulse(pulse):
			continue
		var age := float(pulse.get("age", 0.0))
		var duration = max(float(pulse.get("duration", 0.72)), 0.01)
		var t = clamp(age / duration, 0.0, 1.0)
		var status := str(pulse.get("click_status", "")).strip_edges().to_lower()
		var accepted := status == "queued" or status == "clicked" or status == ""
		var color := PLAYER_COLOR if accepted else Color(1.0, 0.38, 0.14, 1.0)
		var start := get_anchor_center("player_action")
		var finish := get_anchor_center("todo")
		if start == Vector2.ZERO or finish == Vector2.ZERO:
			continue

		var pos := start.lerp(finish, t)
		var alpha = 1.0 - t
		draw_circle(start, 12.0 + t * 28.0, Color(color.r, color.g, color.b, 0.18 * alpha))
		draw_circle(pos, 4.0 + t * 4.0, Color(color.r, color.g, color.b, 0.70 * alpha))


func draw_drone_runtime() -> void:
	setup_ui_basket_handlers()
	if drone_orbit_ui != null and drone_orbit_ui.has_method("draw_runtime"):
		drone_orbit_ui.draw_runtime(self, anchors, unit_state, anim_time)


func draw_ready_overlays() -> void:
	setup_ui_basket_handlers()
	if breach_charge_ui != null and breach_charge_ui.has_method("draw_ready_overlay"):
		breach_charge_ui.draw_ready_overlay(self, anchors, unit_state, event_summaries, anim_time)
	if buster_charge_ui != null and buster_charge_ui.has_method("draw_ready_overlay"):
		buster_charge_ui.draw_ready_overlay(self, anchors, unit_state, event_summaries, anim_time)
	if repair_kit_ui != null and repair_kit_ui.has_method("draw_ready_overlay"):
		repair_kit_ui.draw_ready_overlay(self, anchors, unit_state, event_summaries, anim_time)
	if recharge_kit_ui != null and recharge_kit_ui.has_method("draw_ready_overlay"):
		recharge_kit_ui.draw_ready_overlay(self, anchors, unit_state, event_summaries, anim_time)


func draw_damage_pulses() -> void:
	setup_ui_basket_handlers()
	for pulse in damage_pulses:
		if typeof(pulse) != TYPE_DICTIONARY:
			continue
		if breach_charge_ui != null and breach_charge_ui.has_method("draw_damage_pulse"):
			if bool(breach_charge_ui.draw_damage_pulse(self, pulse, anchors, unit_state, anim_time)):
				continue
		if buster_charge_ui != null and buster_charge_ui.has_method("draw_damage_pulse"):
			if bool(buster_charge_ui.draw_damage_pulse(self, pulse, anchors, unit_state, anim_time)):
				continue


func try_draw_ui_basket_todo_event(event_summary: Dictionary) -> bool:
	setup_ui_basket_handlers()
	if ion_threader_mk1_ui != null and ion_threader_mk1_ui.has_method("draw_todo_event"):
		if bool(ion_threader_mk1_ui.draw_todo_event(self, event_summary, anchors, unit_state, anim_time)):
			return true
	if smart_guy_focus_lance_ui != null and smart_guy_focus_lance_ui.has_method("draw_todo_event"):
		if bool(smart_guy_focus_lance_ui.draw_todo_event(self, event_summary, anchors, unit_state, anim_time)):
			return true
	if smart_guy_calculated_rail_ui != null and smart_guy_calculated_rail_ui.has_method("draw_todo_event"):
		if bool(smart_guy_calculated_rail_ui.draw_todo_event(self, event_summary, anchors, unit_state, anim_time)):
			return true
	if smart_guy_mirror_shield_ui != null and smart_guy_mirror_shield_ui.has_method("draw_todo_event"):
		if bool(smart_guy_mirror_shield_ui.draw_todo_event(self, event_summary, anchors, unit_state, anim_time)):
			return true
	if smart_guy_patch_cell_ui != null and smart_guy_patch_cell_ui.has_method("draw_todo_event"):
		if bool(smart_guy_patch_cell_ui.draw_todo_event(self, event_summary, anchors, unit_state, anim_time)):
			return true
	if repair_kit_ui != null and repair_kit_ui.has_method("draw_todo_event"):
		if bool(repair_kit_ui.draw_todo_event(self, event_summary, anchors, unit_state, anim_time)):
			return true
	if recharge_kit_ui != null and recharge_kit_ui.has_method("draw_todo_event"):
		if bool(recharge_kit_ui.draw_todo_event(self, event_summary, anchors, unit_state, anim_time)):
			return true
	if coil_spitter_mk1_ui != null and coil_spitter_mk1_ui.has_method("draw_todo_event"):
		if bool(coil_spitter_mk1_ui.draw_todo_event(self, event_summary, anchors, unit_state, anim_time)):
			return true
	if breach_charge_ui != null and breach_charge_ui.has_method("draw_todo_event"):
		if bool(breach_charge_ui.draw_todo_event(self, event_summary, anchors, unit_state, anim_time)):
			return true
	if buster_charge_ui != null and buster_charge_ui.has_method("draw_todo_event"):
		if bool(buster_charge_ui.draw_todo_event(self, event_summary, anchors, unit_state, anim_time)):
			return true
	return false


func try_draw_ui_basket_action_pulse(pulse: Dictionary) -> bool:
	setup_ui_basket_handlers()
	if ion_threader_mk1_ui != null and ion_threader_mk1_ui.has_method("draw_action_click"):
		if bool(ion_threader_mk1_ui.draw_action_click(self, pulse, anchors, unit_state, anim_time)):
			return true
	if smart_guy_focus_lance_ui != null and smart_guy_focus_lance_ui.has_method("draw_action_click"):
		if bool(smart_guy_focus_lance_ui.draw_action_click(self, pulse, anchors, unit_state, anim_time)):
			return true
	if smart_guy_calculated_rail_ui != null and smart_guy_calculated_rail_ui.has_method("draw_action_click"):
		if bool(smart_guy_calculated_rail_ui.draw_action_click(self, pulse, anchors, unit_state, anim_time)):
			return true
	if smart_guy_mirror_shield_ui != null and smart_guy_mirror_shield_ui.has_method("draw_action_click"):
		if bool(smart_guy_mirror_shield_ui.draw_action_click(self, pulse, anchors, unit_state, anim_time)):
			return true
	if smart_guy_patch_cell_ui != null and smart_guy_patch_cell_ui.has_method("draw_action_click"):
		if bool(smart_guy_patch_cell_ui.draw_action_click(self, pulse, anchors, unit_state, anim_time)):
			return true
	if repair_kit_ui != null and repair_kit_ui.has_method("draw_action_click"):
		if bool(repair_kit_ui.draw_action_click(self, pulse, anchors, unit_state, anim_time)):
			return true
	if recharge_kit_ui != null and recharge_kit_ui.has_method("draw_action_click"):
		if bool(recharge_kit_ui.draw_action_click(self, pulse, anchors, unit_state, anim_time)):
			return true
	if coil_spitter_mk1_ui != null and coil_spitter_mk1_ui.has_method("draw_action_click"):
		if bool(coil_spitter_mk1_ui.draw_action_click(self, pulse, anchors, unit_state, anim_time)):
			return true
	if breach_charge_ui != null and breach_charge_ui.has_method("draw_action_click"):
		if bool(breach_charge_ui.draw_action_click(self, pulse, anchors, unit_state, anim_time)):
			return true
	if buster_charge_ui != null and buster_charge_ui.has_method("draw_action_click"):
		if bool(buster_charge_ui.draw_action_click(self, pulse, anchors, unit_state, anim_time)):
			return true
	return false


func draw_actor(side: String) -> void:
	var center := get_actor_center(side)
	if center == Vector2.ZERO:
		return

	var color := get_side_color(side)
	var core := get_side_core_color(side)
	var phase := get_side_phase(side)
	var idle := 0.5 + 0.5 * sin(anim_time * 1.65 + phase)
	var dir := 1.0 if side == "player" else -1.0

	var body := PackedVector2Array([
		center + Vector2(dir * 30.0, 0.0),
		center + Vector2(-dir * 18.0, -17.0),
		center + Vector2(-dir * 10.0, 0.0),
		center + Vector2(-dir * 18.0, 17.0)
	])
	draw_colored_polygon(body, Color(color.r, color.g, color.b, 0.36))
	draw_polyline(close_points(body), Color(core.r, core.g, core.b, 0.88), 1.6, true)

	var core_radius := 5.0 + idle * 2.5
	draw_circle(center + Vector2(dir * 2.0, 0.0), core_radius + 8.0, Color(core.r, core.g, core.b, 0.10))
	draw_circle(center + Vector2(dir * 2.0, 0.0), core_radius, Color(core.r, core.g, core.b, 0.92))

	for i in range(3):
		var angle := anim_time * (0.55 + float(i) * 0.08) + phase + float(i) * TAU / 3.0
		var orbit := center + Vector2(cos(angle), sin(angle)) * (42.0 + idle * 4.0)
		draw_circle(orbit, 2.2, Color(core.r, core.g, core.b, 0.58))


func draw_actor_shield_overlay(side: String) -> void:
	var center := get_actor_center(side)
	if center == Vector2.ZERO:
		return

	var shield_ratio := get_side_shield_ratio(side)
	var state := get_side_shield_state(side)
	var has_energy := get_side_shield_has_energy(side)
	var power_level := get_side_shield_power_level(side)
	var color := get_side_color(side)
	var idle := 0.5 + 0.5 * sin(anim_time * 1.8 + get_side_phase(side))

	if try_draw_ui_basket_shield_overlay(side, center):
		return

	if shield_ratio <= 0.0 or state == "broken":
		draw_broken_shield_overlay(center, color, idle)
		return

	var active_count = clamp(max(power_level, int(ceil(shield_ratio * 4.0))), 1, 4)
	var alpha_scale = clamp(shield_ratio, 0.22, 1.0)
	if not has_energy or state == "no_energy":
		alpha_scale *= 0.42
	if state == "switching":
		alpha_scale *= 0.62

	for ring in range(4):
		var is_active = ring < active_count
		var layer_t := float(ring) / 3.0
		var radius := 36.0 + layer_t * 28.0 + idle * 3.5
		var ring_alpha = (0.10 + layer_t * 0.05 + idle * 0.04) * alpha_scale
		if not is_active:
			ring_alpha = 0.045
		var spin := anim_time * (0.36 + layer_t * 0.08) + get_side_phase(side)
		var arc_span := TAU * (0.62 + shield_ratio * 0.22)
		draw_arc(center, radius, spin, spin + arc_span, 84, Color(color.r, color.g, color.b, ring_alpha), 2.0, true)
		draw_arc(center, radius, spin + PI, spin + PI + arc_span * 0.42, 84, Color(color.r, color.g, color.b, ring_alpha * 0.78), 1.2, true)

	draw_circle(center, 69.0 + idle * 2.0, Color(color.r, color.g, color.b, 0.045 * alpha_scale))


func draw_broken_shield_overlay(center: Vector2, color: Color, idle: float) -> void:
	var radius := 56.0 + idle * 3.0
	for shard in range(5):
		var start_angle := anim_time * 0.12 + float(shard) * TAU / 5.0
		var end_angle := start_angle + 0.24 + idle * 0.08
		draw_arc(center, radius + float(shard % 2) * 5.0, start_angle, end_angle, 16, Color(color.r, color.g, color.b, 0.10), 1.4, true)


func try_draw_ui_basket_shield_overlay(side: String, center: Vector2) -> bool:
	setup_ui_basket_handlers()
	var side_state := get_side_unit_state(side)
	if smart_guy_mirror_shield_ui != null and smart_guy_mirror_shield_ui.has_method("draw_shield_overlay"):
		if bool(smart_guy_mirror_shield_ui.draw_shield_overlay(self, side, center, side_state, anim_time)):
			return true
	return false


func get_anchor_rect(key: String) -> Rect2:
	var value = anchors.get(key, Rect2())
	if typeof(value) == TYPE_RECT2:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		var source: Dictionary = value
		return Rect2(source.get("position", Vector2.ZERO), source.get("size", Vector2.ZERO))
	return Rect2()


func get_anchor_center(key: String) -> Vector2:
	var rect := get_anchor_rect(key)
	if rect.size == Vector2.ZERO:
		return Vector2.ZERO
	return rect.position + rect.size * 0.5


func get_actor_center(side: String) -> Vector2:
	var rect := get_anchor_rect(side + "_actor")
	if rect.size != Vector2.ZERO:
		return rect.position + rect.size * 0.5
	var lane_rect := get_anchor_rect(side + "_lane")
	if lane_rect.size == Vector2.ZERO:
		return Vector2.ZERO
	var x := lane_rect.position.x + 58.0
	if side == "enemy":
		x = lane_rect.position.x + lane_rect.size.x - 58.0
	return Vector2(x, lane_rect.position.y + lane_rect.size.y * 0.5)


func get_event_side(event_summary: Dictionary) -> String:
	var side := str(event_summary.get("event_side", event_summary.get("owner_side", "player"))).strip_edges().to_lower()
	if side == "enemy":
		return "enemy"
	return "player"


func get_event_color(event_summary: Dictionary, side: String) -> Color:
	var group := str(event_summary.get("event_group", "")).strip_edges().to_lower()
	if group == "shield":
		return Color(0.28, 0.68, 1.0, 1.0)
	if group == "evade":
		return Color(0.72, 0.80, 1.0, 1.0)
	if group == "consumable":
		return Color(0.94, 0.82, 0.44, 1.0)
	if group == "lock":
		return TODO_COLOR
	return get_side_color(side)


func get_side_unit_state(side: String) -> Dictionary:
	var data = unit_state.get(side, {})
	if typeof(data) == TYPE_DICTIONARY:
		return data
	return {}


func get_side_shield_ratio(side: String) -> float:
	var data := get_side_unit_state(side)
	var max_value = max(float(data.get("shield_max", 0.0)), 0.0)
	if max_value <= 0.0:
		return 0.0
	return clamp(float(data.get("shield_current", 0.0)) / max_value, 0.0, 1.0)


func get_side_shield_state(side: String) -> String:
	return str(get_side_unit_state(side).get("shield_state", "active")).strip_edges().to_lower()


func get_side_shield_power_level(side: String) -> int:
	return clamp(int(get_side_unit_state(side).get("shield_power_level", 0)), 0, 4)


func get_side_shield_has_energy(side: String) -> bool:
	return bool(get_side_unit_state(side).get("shield_has_energy", true))


func get_side_color(side: String) -> Color:
	return ENEMY_COLOR if side == "enemy" else PLAYER_COLOR


func get_side_core_color(side: String) -> Color:
	return ENEMY_CORE if side == "enemy" else PLAYER_CORE


func get_side_phase(side: String) -> float:
	return 2.7 if side == "enemy" else 0.0


func build_visual_seed(value: String) -> int:
	var hash_value := 5381
	for i in range(value.length()):
		hash_value = int((hash_value * 33 + value.unicode_at(i)) % 2147483647)
	return abs(hash_value)


func close_points(points: PackedVector2Array) -> PackedVector2Array:
	var output := PackedVector2Array(points)
	if points.size() > 0:
		output.append(points[0])
	return output
