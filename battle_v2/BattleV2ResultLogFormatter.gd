extends RefCounted
class_name BattleV2ResultLogFormatter

# Text-only formatter for Battle V2 resolution logs.
# It reads result packets and returns strings; it never mutates battle state.

var battle_scene = null


func setup(scene_ref) -> void:
	battle_scene = scene_ref


func build_battle_result_log_text(event_packet: Dictionary, handoff_result: Dictionary) -> String:
	if Globals.print_priority_3:
		print("[BattleV2ResultLogFormatter.build_battle_result_log_text] START | event_packet=", event_packet, " | handoff_result=", handoff_result)

	var summary = handoff_result.get("resolution_summary", handoff_result)
	if typeof(summary) != TYPE_DICTIONARY:
		if Globals.print_priority_5:
			print("[BattleV2ResultLogFormatter.build_battle_result_log_text] BLOCKED | summary is not dictionary")
		return "Battle result: no resolution details returned."

	var battle_outcome := str(summary.get("battle_outcome", "battle_continues"))
	var battle_ended := bool(summary.get("battle_ended", false))
	var cleanup_required := bool(summary.get("cleanup_required", false))

	if Globals.print_priority_5:
		print(
			"[BattleV2ResultLogFormatter.build_battle_result_log_text] SUMMARY",
			" | battle_outcome=", battle_outcome,
			" | battle_ended=", battle_ended,
			" | cleanup_required=", cleanup_required
		)

	var resolved_events: Array = summary.get("resolved_events", []) as Array
	if resolved_events.is_empty():
		var invalid_events: Array = summary.get("invalid_events", []) as Array
		if not invalid_events.is_empty():
			if Globals.print_priority_5:
				print("[BattleV2ResultLogFormatter.build_battle_result_log_text] INVALID EVENTS | invalid_events=", invalid_events)
			return "Battle result: invalid event skipped."
		if battle_outcome == "player_victory":
			return "Battle result: enemy defeated."
		if battle_outcome == "player_defeat":
			return "Battle result: player defeated."
		return "Battle result: no resolved events returned."

	var event_id := str(event_packet.get("event_id", ""))
	var result_text := ""
	for resolution_result in resolved_events:
		if typeof(resolution_result) != TYPE_DICTIONARY:
			continue
		var resolution_event_id := str(resolution_result.get("event_id", ""))
		if resolution_event_id != event_id and resolved_events.size() > 1:
			continue
		var line := build_resolution_result_log_text(resolution_result)
		if line == "":
			continue
		if result_text != "":
			result_text += "\n"
		result_text += line

	if battle_outcome == "player_victory":
		if result_text != "":
			result_text += "\n"
		result_text += "Battle result: enemy defeated."
	elif battle_outcome == "player_defeat":
		if result_text != "":
			result_text += "\n"
		result_text += "Battle result: player defeated."

	if result_text == "":
		return "Battle result: handoff acknowledged without matching detail."
	return result_text


func build_resolution_result_log_text(resolution_result: Dictionary) -> String:
	var result_type := str(resolution_result.get("type", ""))
	var blocked_reason := str(resolution_result.get("blocked_reason", "none"))
	var resource_suffix := get_resolution_energy_log_suffix(resolution_result) + get_resolution_ammo_log_suffix(resolution_result) + get_resolution_consumable_log_suffix(resolution_result)

	if str(resolution_result.get("status", "")).strip_edges().to_lower() == "nullified" or result_type == "resolution_gate":
		return "Result: nullified at lane gate (" + blocked_reason + ")."

	if blocked_reason != "" and blocked_reason != "none":
		if result_type == "weapon_damage":
			return "Result: miss or blocked shot (" + blocked_reason + ")." + resource_suffix
		if result_type == "explosive":
			return "Result: explosive missed or was blocked (" + blocked_reason + ")." + resource_suffix
		return "Result: blocked (" + blocked_reason + ")." + resource_suffix

	if result_type == "weapon_damage":
		var damage_result = resolution_result.get("damage_result", {})
		if typeof(damage_result) != TYPE_DICTIONARY:
			return "Result: weapon resolved without damage details." + resource_suffix
		return (
			"Result: hit | shield "
			+ value(float(damage_result.get("shield_damage", 0.0)))
			+ " | hull "
			+ value(float(damage_result.get("hull_damage", 0.0)))
			+ " | overflow "
			+ value(float(damage_result.get("overflow_damage", 0.0)))
		) + resource_suffix

	if result_type == "explosive":
		var explosive_damage_result = resolution_result.get("damage_result", {})
		if typeof(explosive_damage_result) != TYPE_DICTIONARY:
			return "Result: explosive resolved without damage details." + resource_suffix
		return (
			"Result: explosive hit | shield "
			+ value(float(explosive_damage_result.get("shield_damage", 0.0)))
			+ " | hull "
			+ value(float(explosive_damage_result.get("hull_damage", 0.0)))
			+ " | overflow "
			+ value(float(explosive_damage_result.get("overflow_damage", 0.0)))
		) + resource_suffix

	if result_type == "state_change":
		var subtype := str(resolution_result.get("event_subtype", ""))
		if not bool(resolution_result.get("applied", false)):
			return "Result: state change did not apply." + resource_suffix
		if subtype == "shield_switch_complete":
			return "Result: shield changed to " + get_selected_player_shield_name() + "." + resource_suffix
		if subtype == "load_consumable_complete":
			return "Result: consumable loaded and ready." + resource_suffix
		if subtype == "lock_restore":
			return "Result: lock restored." + resource_suffix
		if subtype == "evade_complete":
			return "Result: evade complete; relock timer already running." + resource_suffix
		return "Result: state change applied (" + subtype + ")." + resource_suffix

	if result_type == "signal":
		if bool(resolution_result.get("signal_applied", false)):
			return "Result: signal effect applied." + resource_suffix
		return "Result: signal completed without applying an effect." + resource_suffix

	if result_type == "drone":
		if bool(resolution_result.get("drone_deployed", false)):
			var drone_text := "Result: drone deployed."
			if bool(resolution_result.get("runtime_started", false)):
				var runtime_result = resolution_result.get("runtime_result", {})
				var active_count := 0
				if typeof(runtime_result) == TYPE_DICTIONARY:
					active_count = int(runtime_result.get("active_count", 0))
				drone_text = "Result: drone deployed; auto attack active"
				if active_count > 0:
					drone_text += " | active drones " + str(active_count)
				drone_text += "."
			if bool(resolution_result.get("effect_applied", false)):
				drone_text = "Result: drone deployed; protection active."
			return drone_text + resource_suffix
		return "Result: drone completed without deployment." + resource_suffix

	if result_type == "repair":
		if bool(resolution_result.get("repair_applied", false)):
			return "Result: repair kit used | hull +" + value(float(resolution_result.get("hull_repaired", 0.0))) + " | hull " + value(float(resolution_result.get("hull_after", 0.0))) + resource_suffix
		return "Result: repair kit completed without repair." + resource_suffix

	if result_type == "shield_repair":
		if bool(resolution_result.get("repair_applied", false)):
			return "Result: shield patch used | shield +" + value(float(resolution_result.get("shield_repaired", 0.0))) + " | shield " + value(float(resolution_result.get("shield_after", 0.0))) + resource_suffix
		return "Result: shield patch blocked (" + str(resolution_result.get("blocked_reason", "unknown")) + ")." + resource_suffix

	if result_type == "recharge":
		if bool(resolution_result.get("recharge_applied", false)):
			return "Result: recharge kit used | energy +" + value(float(resolution_result.get("energy_restored", 0.0))) + " | energy " + value(float(resolution_result.get("energy_after", 0.0))) + resource_suffix
		return "Result: recharge kit completed without energy restore." + resource_suffix

	if result_type == "damage":
		return "Result: damage | shield " + value(float(resolution_result.get("shield_damage", 0.0))) + " | hull " + value(float(resolution_result.get("hull_damage", 0.0))) + resource_suffix

	if result_type == "":
		return "Result: BattleManager returned an unnamed result." + resource_suffix
	return "Result: " + result_type + " resolved." + resource_suffix


func get_resolution_energy_log_suffix(resolution_result: Dictionary) -> String:
	var energy_result = resolution_result.get("energy_result", {})
	if typeof(energy_result) != TYPE_DICTIONARY:
		return ""
	var energy_cost := float(energy_result.get("energy_cost", 0.0))
	if energy_cost <= 0.0:
		return ""
	if str(energy_result.get("status", "")) != "success":
		return " | energy spend failed"
	return " | energy spent " + value(energy_cost)


func get_resolution_ammo_log_suffix(resolution_result: Dictionary) -> String:
	var ammo_result = resolution_result.get("ammo_result", {})
	if typeof(ammo_result) != TYPE_DICTIONARY:
		return ""
	var ammo_cost := int(ammo_result.get("ammo_cost", 0))
	if ammo_cost <= 0:
		return ""
	if str(ammo_result.get("status", "")) != "success":
		return " | ammo spend failed"
	return " | ammo spent " + str(ammo_cost) + " " + str(ammo_result.get("ammo_group", "ammo"))


func get_resolution_consumable_log_suffix(resolution_result: Dictionary) -> String:
	var consumable_result = resolution_result.get("consumable_result", {})
	if typeof(consumable_result) != TYPE_DICTIONARY:
		return ""
	var consumable_cost := int(consumable_result.get("consumable_cost", 0))
	if consumable_cost <= 0:
		return ""
	if str(consumable_result.get("status", "")) != "success":
		return " | consumable spend failed"
	return " | consumable spent " + str(consumable_result.get("consumable_id", "unknown"))


func get_selected_player_shield_name() -> String:
	if battle_scene != null and battle_scene.has_method("get_selected_player_shield_name"):
		return str(battle_scene.get_selected_player_shield_name())
	return "selected shield"


func value(amount: float) -> String:
	if battle_scene != null and battle_scene.has_method("format_battle_value"):
		return str(battle_scene.format_battle_value(amount))
	var rounded = round(amount * 10.0) / 10.0
	if is_equal_approx(rounded, round(rounded)):
		return str(int(round(rounded)))
	return str(rounded)
