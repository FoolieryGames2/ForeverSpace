extends Node

var BATTLE_MANAGER_SOURCE_VERSION = '0.1'
# BattleManager is active only while a battle is currently being resolved.
var battle_active: bool = false

# Current player battle-state reference.
var active_player_state = null

# Current enemy battle-state reference.
var active_enemy = null

# Action_Manager reference.
# Used only to request Action UI refresh after outcomes.
var action_manager = null

# EnergyHandler reference.
# BattleManager calls official energy APIs only.
var energy_handler = null

# Enemy EnergyHandler reference.
# BattleManager spends enemy reserved energy when enemy TODOs complete.
var enemy_energy_handler = null

# AmmoHandler reference.
# BattleManager calls official ammo APIs only.
var ammo_handler = null

# Inventory reference.
# BattleManager requests ammo / consumable spends only.
var inventory = null

# EventManager reference.
# BattleManager requests active TODO cleanup only.
var event_manager = null





# StatEffectHandler reference.
# BattleManager routes pulse/stat effects here but does not store them.
var stat_effect_handler = null

# Active drone runtime storage.
# StatEffectManager still owns simple effect drones; this array owns drones with HP, timers, and autonomous attacks.
var active_drones: Array = []
var drone_runtime_counter: int = 0

# AnimatorFetcher reference.
# BattleManager sends semantic result labels only.
var animator_fetcher = null




func _ready() -> void:
	print(
	"[S1.2_BATTLE_MANAGER_READY_ENTER]",
	" battle_mode=", Globals.battle_mode,
	" battle_pending=", Globals.battle_pending,
	" swap_battle_v2=", Globals.swap_battle_v2,
	" context_empty=", Globals.battle_v2_context.is_empty() if typeof(Globals.battle_v2_context) == TYPE_DICTIONARY else true
)
	# Summary:
	# Manual proof marker for confirming the BattleManager script currently pasted into Godot
	# is the one actually reaching runtime.
	#
	# This should print once when the BattleManager node enters the tree.
	# If this does not print, do not assume BattleManager is wrong yet:
	# BattleManager may be created/used in a way where _ready() is not the useful proof point.
	#
	# The stronger proof point is still the [P5_BATTLEMANAGER_RESOLVE] print inside the resolve function.

	if Globals.print_priority_5:
		print("BattleManager prototype loaded idle.")

	print("[BM_READY_MANUAL_PROBE] BattleManager _ready() reached")



	if Globals.print_priority_5:
		print(
			"[P5_BATTLEMANAGER_FILE_VERSION]",
			" version=", BATTLE_MANAGER_SOURCE_VERSION,
			" manual_probe=ready_v1"
		)
	# Summary: Keep the prototype battle resolver idle until the Battle V2 scene wires real battle state into it.
	


func validate_event_ownership(event: Dictionary) -> Dictionary:
	# Summary: Validates that a completed Battle V2 TODO event carries explicit unit ownership fields.
	#
	# BattleManager must not assume:
	# - source_unit is player
	# - target_unit is enemy
	# - owner_unit is player
	#
	# Every completed event must declare its own ownership.

	var result := {
		"valid": true,
		"missing_fields": [],
		"event_id": event.get("event_id", null)
	}

	if Globals.print_priority_3:
		print("[BattleManager.validate_event_ownership] START | event_id=", result["event_id"])

	var required_fields := [
		"source_unit",
		"target_unit",
		"owner_unit",
		"event_side"
	]

	for field_name in required_fields:
		if not event.has(field_name):
			result["valid"] = false
			result["missing_fields"].append(field_name)

	if not result["valid"]:
		if Globals.print_priority_5:
			print(
				"[BattleManager.validate_event_ownership] INVALID",
				" | event_id=", result["event_id"],
				" | missing_fields=", result["missing_fields"]
			)
	else:
		if Globals.print_priority_3:
			print("[BattleManager.validate_event_ownership] VALID | event_id=", result["event_id"])

	return result
	
	
	
	
func sort_completed_events_by_resolution_order(completed_events: Array) -> Array:
	# Summary: Sorts completed TODO events so state changes resolve before damage/effects.
	#
	# Reason:
	# A same-time lock restore, shield switch, or evade should apply before damage
	# checks lock/shield state.

	var state_change_events := []
	var damage_effect_events := []

	if Globals.print_priority_5:
		print(
			"[BattleManager.sort_completed_events_by_resolution_order] START",
			" | completed_count=", completed_events.size()
		)

	for event in completed_events:
		if typeof(event) != TYPE_DICTIONARY:
			if Globals.print_priority_5:
				print("[BattleManager.sort_completed_events_by_resolution_order] SKIP non-dictionary event=", event)
			continue

		if bool(event.get("is_state_change", false)):
			state_change_events.append(event)
		else:
			damage_effect_events.append(event)

	var ordered_events := []
	ordered_events.append_array(state_change_events)
	ordered_events.append_array(damage_effect_events)

	if Globals.print_priority_5:
		print(
			"[BattleManager.sort_completed_events_by_resolution_order] END",
			" | state_changes=", state_change_events.size(),
			" | damage_effects=", damage_effect_events.size(),
			" | ordered_count=", ordered_events.size()
		)

	return ordered_events
	
func get_battle_unit_side(unit, fallback_side: String = "") -> String:
	# PURPOSE: Read the side name from an adapter, object, or dictionary before applying side-specific lock methods.
	if unit == null:
		return fallback_side
	if typeof(unit) == TYPE_DICTIONARY:
		return str(unit.get("unit_side", fallback_side)).strip_edges()
	if unit is Object:
		var side_value = unit.get("unit_side")
		if side_value != null:
			return str(side_value).strip_edges()
	return fallback_side
	
	
func apply_lock_restore_to_unit(unit, fallback_side: String = "") -> bool:
	# PURPOSE: Restore lock on the correct side-specific fields for temporary Battle V2 unit adapters.
	if unit == null or not (unit is Object):
		return false

	var unit_side := get_battle_unit_side(unit, fallback_side)
	if unit_side == "enemy" and unit.has_method("set_enemy_lock_good"):
		unit.set_enemy_lock_good()
		return true
	if unit_side == "player" and unit.has_method("set_player_lock_good"):
		unit.set_player_lock_good()
		return true
	if unit.has_method("set_player_lock_good"):
		unit.set_player_lock_good()
		return true
	if unit.has_method("set_enemy_lock_good"):
		unit.set_enemy_lock_good()
		return true
	return false
	
	
func apply_lock_lost_to_unit(unit, fallback_side: String = "") -> bool:
	# PURPOSE: Remove lock on the correct side-specific fields for temporary Battle V2 unit adapters.
	if unit == null or not (unit is Object):
		return false

	var unit_side := get_battle_unit_side(unit, fallback_side)
	if unit_side == "enemy" and unit.has_method("set_enemy_lock_lost"):
		unit.set_enemy_lock_lost()
		return true
	if unit_side == "player" and unit.has_method("set_player_lock_lost"):
		unit.set_player_lock_lost()
		return true
	if unit.has_method("set_player_lock_lost"):
		unit.set_player_lock_lost()
		return true
	if unit.has_method("set_enemy_lock_lost"):
		unit.set_enemy_lock_lost()
		return true
	return false
	
	
	
func resolve_todo_completion(completed_events: Array) -> Dictionary:
	# Summary: Resolves one completed Battle V2 TODO batch and reports whether the scene must stop battle processing.
	#
	# Ownership rule:
	# - BattleManager resolves math/state changes.
	# - BattleManager checks victory/defeat.
	# - BattleManager does NOT clear active_enemy here.
	# - battle_v2_scene.gd owns terminal scene flow, result packaging, and cleanup ordering.
	#
	# Important:
	# If this returns "cleanup_required": true, battle_v2_scene.gd must immediately:
	# 1. Queue defeated enemy result if player_victory.
	# 2. Mark Battle V2 ended.
	# 3. Clear pending TODOs.
	# 4. Call BattleManager.end_battle_cleanup(...).
	# 5. Return without queuing enemy response.

	if Globals.print_priority_5:
		print(
			"[BattleManager.resolve_todo_completion] START",
			" | battle_active=", battle_active,
			" | completed_events_count=", completed_events.size()
		)

	var summary := {
		"resolved_events": [],
		"invalid_events": [],
		"battle_outcome": "battle_continues",
		"battle_ended": false,
		"cleanup_required": false,
		"cleanup_outcome": "",
		"blocked_reason": "none"
	}

	# ------------------------------------------------------
	# GUARD: Do not resolve more TODOs after BattleManager cleanup.
	# Priority 1 because reaching this means something is still
	# sending completed events after battle ended.
	# ------------------------------------------------------
	if not battle_active:
		summary["blocked_reason"] = "battle_not_active"

		if Globals.print_priority_5:
			print("[BattleManager.resolve_todo_completion] BLOCKED | battle_active=false | completed events ignored")

		return summary

	# ------------------------------------------------------
	# EVENT OWNERSHIP VALIDATION PHASE
	# Every completed event must contain explicit ownership fields.
	# Invalid events are skipped safely.
	# ------------------------------------------------------
	var validated_events := []

	if Globals.print_priority_5:
		print("[BattleManager.resolve_todo_completion] PHASE validate ownership")

	for event in completed_events:
		if Globals.print_priority_3:
			print("[BattleManager.resolve_todo_completion] VALIDATING EVENT | event=", event)

		var validation_result = validate_event_ownership(event)

		if validation_result["valid"]:
			if Globals.print_priority_3:
				print("[BattleManager.resolve_todo_completion] EVENT VALID | event_id=", event.get("event_id", null))

			validated_events.append(event)
		else:
			if Globals.print_priority_5:
				print("[BattleManager.resolve_todo_completion] EVENT INVALID | result=", validation_result)

			summary["invalid_events"].append(validation_result)

	# ------------------------------------------------------
	# RESOLUTION ORDER PHASE
	# State-change TODOs resolve before damage/effect TODOs.
	# ------------------------------------------------------
	if Globals.print_priority_5:
		print(
			"[BattleManager.resolve_todo_completion] PHASE sort resolution order",
			" | validated_count=", validated_events.size()
		)

	var ordered_events = sort_completed_events_by_resolution_order(validated_events)

	# ------------------------------------------------------
	# EVENT RESOLUTION PHASE
	# Each ordered event routes into the official resolution pipeline.
	# ------------------------------------------------------
	if Globals.print_priority_5:
		print(
			"[BattleManager.resolve_todo_completion] PHASE resolve ordered events",
			" | ordered_count=", ordered_events.size()
		)

	for event in ordered_events:
		if Globals.print_priority_3:
			print("[BattleManager.resolve_todo_completion] RESOLVING EVENT | event=", event)

		var pre_event_outcome := check_victory_conditions()
		if pre_event_outcome == "player_victory" or pre_event_outcome == "player_defeat":
			if Globals.print_priority_5:
				print(
					"[BattleManager.resolve_todo_completion] STOP remaining batch | terminal already reached",
					" | outcome=", pre_event_outcome,
					" | skipped_event_id=", event.get("event_id", null)
				)
			summary["battle_outcome"] = pre_event_outcome
			summary["battle_ended"] = true
			summary["cleanup_required"] = true
			summary["cleanup_outcome"] = "victory" if pre_event_outcome == "player_victory" else "defeat"
			break

		var resolution_gate_result := evaluate_completed_event_resolution_gate(event)
		if str(resolution_gate_result.get("status", "")) == "nullified":
			if Globals.print_priority_5:
				print("[BattleManager.resolve_todo_completion] GATED NULL | result=", resolution_gate_result)
			resolution_gate_result["resource_release_result"] = release_reserved_resources_for_nullified_event(event)
			summary["resolved_events"].append(resolution_gate_result)
			continue

		var shield_repair_gate_result := evaluate_shield_repair_completion_gate(event)
		if str(shield_repair_gate_result.get("status", "")) == "nullified":
			if Globals.print_priority_5:
				print("[BattleManager.resolve_todo_completion] SHIELD REPAIR GATED NULL | result=", shield_repair_gate_result)
			shield_repair_gate_result["resource_release_result"] = release_reserved_resources_for_nullified_event(event)
			shield_repair_gate_result["consumable_state_result"] = restore_nullified_consumable_ready_state(event)
			summary["resolved_events"].append(shield_repair_gate_result)
			continue

		# --------------------------------------------------
		# Spend energy only for this completed event.
		# If spend fails, skip resolution for that event.
		# --------------------------------------------------
		var energy_spend_result: Dictionary = spend_energy_for_completed_event(event)

		if energy_spend_result.get("status", "") != "success":
			if Globals.print_priority_5:
				print("[BattleManager.resolve_todo_completion] ENERGY SPEND FAILED | result=", energy_spend_result)

			summary["invalid_events"].append(energy_spend_result)
			continue

		# --------------------------------------------------
		# Spend ammo only for this completed event.
		# If spend fails, skip resolution for that event.
		# --------------------------------------------------
		if Globals.print_priority_5:
			var p5_data = event.get("data", {})
			print(
				"[P5_BATTLEMANAGER_RESOLVE]",
				" bm_version=manual_resolve_probe_v1",
				" event_id=", event.get("event_id", ""),
				" event_type=", event.get("event_type", ""),
				" item_id=", event.get("item_id", ""),
				" packet_source=", event.get("packet_source", p5_data.get("packet_source", "") if typeof(p5_data) == TYPE_DICTIONARY else ""),
				" packet_shape=", event.get("packet_shape", p5_data.get("packet_shape", "") if typeof(p5_data) == TYPE_DICTIONARY else ""),
				" burst=", (str(p5_data.get("burst_index", 0)) + "/" + str(p5_data.get("burst_total", 0))) if typeof(p5_data) == TYPE_DICTIONARY else "0/0",
				" damage_value=", event.get("damage_value", 0.0),
				" ammo_group=", p5_data.get("ammo_group", "") if typeof(p5_data) == TYPE_DICTIONARY else "",
				" ammo_cost=", p5_data.get("total_ammo_cost", p5_data.get("ammo_cost", 0)) if typeof(p5_data) == TYPE_DICTIONARY else 0
			)

		var ammo_spend_result: Dictionary = spend_ammo_for_completed_event(event)

		if ammo_spend_result.get("status", "") != "success":
			if Globals.print_priority_5:
				print("[BattleManager.resolve_todo_completion] AMMO SPEND FAILED | result=", ammo_spend_result)

			summary["invalid_events"].append(ammo_spend_result)
			continue

		# --------------------------------------------------
		# Spend executed consumables only after their execute
		# TODO completes. Loading never changes inventory.
		# --------------------------------------------------
		var consumable_spend_result: Dictionary = spend_consumable_for_completed_event(event)

		if consumable_spend_result.get("status", "") != "success":
			if Globals.print_priority_5:
				print("[BattleManager.resolve_todo_completion] CONSUMABLE SPEND FAILED | result=", consumable_spend_result)

			summary["invalid_events"].append(consumable_spend_result)
			continue

		var resolution_result

		if event.get("is_state_change", false):
			if Globals.print_priority_5:
				print(
					"[BattleManager.resolve_todo_completion] ROUTE resolve_state_changes",
					" | event_id=", event.get("event_id", null)
				)

			resolution_result = resolve_state_changes(event)
		else:
			if Globals.print_priority_5:
				print(
					"[BattleManager.resolve_todo_completion] ROUTE resolve_action_result",
					" | event_id=", event.get("event_id", null)
				)

			resolution_result = resolve_action_result(event)

		if typeof(resolution_result) == TYPE_DICTIONARY:
			resolution_result["energy_result"] = energy_spend_result
			resolution_result["ammo_result"] = ammo_spend_result
			resolution_result["consumable_result"] = consumable_spend_result

		summary["resolved_events"].append(resolution_result)

		var post_event_outcome := check_victory_conditions()
		if post_event_outcome == "player_victory" or post_event_outcome == "player_defeat":
			if Globals.print_priority_5:
				print(
					"[BattleManager.resolve_todo_completion] STOP remaining batch after terminal event",
					" | outcome=", post_event_outcome,
					" | event_id=", event.get("event_id", null)
				)
			summary["battle_outcome"] = post_event_outcome
			summary["battle_ended"] = true
			summary["cleanup_required"] = true
			summary["cleanup_outcome"] = "victory" if post_event_outcome == "player_victory" else "defeat"
			break

	# ------------------------------------------------------
	# VICTORY / DEFEAT CHECK PHASE
	# Victory conditions are checked after the completed batch resolves.
	# check_victory_conditions() must only report outcome.
	# It must not call end_battle_cleanup().
	# ------------------------------------------------------
	if Globals.print_priority_5:
		print("[BattleManager.resolve_todo_completion] PHASE check victory conditions")

	var battle_outcome := str(summary.get("battle_outcome", "battle_continues"))
	if not bool(summary.get("battle_ended", false)):
		battle_outcome = check_victory_conditions()
		summary["battle_outcome"] = battle_outcome

	if battle_outcome == "player_victory":
		summary["battle_ended"] = true
		summary["cleanup_required"] = true
		summary["cleanup_outcome"] = "victory"

		if Globals.print_priority_5:
			print("[BattleManager.resolve_todo_completion] TERMINAL OUTCOME | player_victory | cleanup_required=true")

	elif battle_outcome == "player_defeat":
		summary["battle_ended"] = true
		summary["cleanup_required"] = true
		summary["cleanup_outcome"] = "defeat"

		if Globals.print_priority_5:
			print("[BattleManager.resolve_todo_completion] TERMINAL OUTCOME | player_defeat | cleanup_required=true")

	else:
		if Globals.print_priority_3:
			print("[BattleManager.resolve_todo_completion] OUTCOME | battle_continues")

	# ------------------------------------------------------
	# ACTION UI REFRESH PHASE
	# Refresh only if battle continues.
	# If battle ended, battle_v2_scene.gd should disable/refresh rows
	# during mark_battle_v2_ended().
	# ------------------------------------------------------
	if not summary["battle_ended"]:
		if Globals.print_priority_5:
			print("[BattleManager.resolve_todo_completion] PHASE refresh Action UI")

		if action_manager != null:
			if action_manager.has_method("refresh_action_ui"):
				action_manager.refresh_action_ui()
	else:
		if Globals.print_priority_5:
			print("[BattleManager.resolve_todo_completion] SKIP action UI refresh | terminal outcome reached")

	# ------------------------------------------------------
	# FINAL SUMMARY
	# Priority 2 because this is the handoff packet the scene needs.
	# ------------------------------------------------------
	if Globals.print_priority_5:
		print("[BattleManager.resolve_todo_completion] END | summary=", summary)

	return summary
	
	
func evaluate_completed_event_resolution_gate(event: Dictionary) -> Dictionary:
	# Summary: Reusable finish-line gate for lane interventions that let TODOs travel but skip resolution.
	var gate_state := str(event.get("resolution_gate_state", "")).strip_edges().to_lower()
	if gate_state != "null":
		return {
			"status": "open",
			"type": "resolution_gate",
			"event_id": event.get("event_id", null)
		}

	return {
		"status": "nullified",
		"type": "resolution_gate",
		"result_type": "nullified",
		"event_id": event.get("event_id", null),
		"event_type": event.get("event_type", ""),
		"event_side": event.get("event_side", ""),
		"blocked_reason": str(event.get("resolution_gate_reason", "lane intervention")),
		"source_event_id": str(event.get("resolution_gate_source_event_id", "")),
		"labels": [
			"todo_event_resolution_gate",
			"todo_event_resolution_nullified",
			"no_energy_spend",
			"no_ammo_spend",
			"no_damage_resolution"
		]
	}


func evaluate_shield_repair_completion_gate(event: Dictionary) -> Dictionary:
	# Summary: Prevent shield-repair items from spending when their target is missing, full, switching, disabled, or broken.
	var event_type := str(event.get("event_type", "")).strip_edges().to_lower()
	var event_group := str(event.get("event_group", "")).strip_edges().to_lower()
	var data_payload: Dictionary = {}
	if typeof(event.get("data", {})) == TYPE_DICTIONARY:
		data_payload = event.get("data", {})
	var consumable_group := str(data_payload.get("consumable_group", event_group)).strip_edges().to_lower()
	if event_type != "execute_shield_repair" and event_group != "shield_repair" and consumable_group != "shield_repair":
		return {
			"status": "open",
			"type": "shield_repair_gate",
			"event_id": event.get("event_id", null)
		}

	var owner_unit = event.get("owner_unit", event.get("source_unit", null))
	var blocked_reason := ""
	if owner_unit == null:
		blocked_reason = "missing_shield_repair_target"
	elif get_unit_shield_item_id(owner_unit) == "":
		blocked_reason = "missing_selected_shield"
	elif get_unit_shield_hp_current(owner_unit) <= 0.0:
		blocked_reason = "shield_broken_not_repairable"
	elif bool(owner_unit.get("shield_switching")):
		blocked_reason = "shield_switching"
	elif bool(owner_unit.get("shield_disabled")):
		blocked_reason = "shield_disabled"
	elif get_unit_shield_hp_current(owner_unit) >= get_unit_shield_hp_max(owner_unit):
		blocked_reason = "shield_not_damaged"

	if blocked_reason == "":
		return {
			"status": "open",
			"type": "shield_repair_gate",
			"event_id": event.get("event_id", null),
			"labels": ["shield_repair_completion_gate", "shield_repair_target_active"]
		}

	return {
		"status": "nullified",
		"type": "shield_repair",
		"result_type": "nullified",
		"event_id": event.get("event_id", null),
		"event_type": event.get("event_type", ""),
		"event_side": event.get("event_side", ""),
		"blocked_reason": blocked_reason,
		"labels": [
			"shield_repair_completion_gate",
			"shield_repair_no_consumable_spend",
			"shield_repair_blocked_" + blocked_reason
		]
	}


func restore_nullified_consumable_ready_state(event: Dictionary) -> Dictionary:
	# Summary: A shield patch that became invalid before completion remains loaded and ready because it was not spent.
	var owner_unit = event.get("owner_unit", event.get("source_unit", null))
	var result := {
		"status": "blocked",
		"restored_state": "",
		"labels": ["nullified_consumable_state_restore"]
	}
	if owner_unit == null or not owner_unit.has_method("set_consumable_state"):
		result["blocked_reason"] = "missing_consumable_state_owner"
		return result
	owner_unit.set_consumable_state("ready")
	result["status"] = "success"
	result["restored_state"] = "ready"
	result["blocked_reason"] = "none"
	result["labels"].append("shield_repair_unspent_remains_ready")
	return result
	
	
func release_reserved_resources_for_nullified_event(event: Dictionary) -> Dictionary:
	# Summary: Return queue-time reservations for a TODO that reached completion but was nullified before resolution.
	return {
		"status": "success",
		"event_id": event.get("event_id", null),
		"energy_result": release_reserved_energy_for_nullified_event(event),
		"ammo_result": release_reserved_ammo_for_nullified_event(event),
		"enemy_item_result": release_reserved_enemy_items_for_nullified_event(event),
		"labels": [
			"nullified_todo_resource_release",
			"reserved_resources_released_without_spend"
		]
	}


func release_reserved_enemy_items_for_nullified_event(event: Dictionary) -> Dictionary:
	# Summary: Return queue-time enemy stack reservations when a completed TODO is nullified before resolution.
	var result := {
		"status": "success",
		"restored_items": [],
		"labels": ["nullified_enemy_item_reservation_release"]
	}
	if str(event.get("event_side", "")).strip_edges().to_lower() != "enemy":
		return result

	var reserved_items = event.get("enemy_reserved_items", [])
	if typeof(reserved_items) != TYPE_ARRAY or reserved_items.is_empty():
		return result
	var owner_unit = event.get("owner_unit", event.get("source_unit", null))
	if owner_unit == null or not owner_unit.has_method("add_enemy_item"):
		result["status"] = "failed"
		result["blocked_reason"] = "missing_enemy_item_reservation_owner"
		return result

	for raw_reservation in reserved_items:
		if typeof(raw_reservation) != TYPE_DICTIONARY:
			continue
		var item_id := str(raw_reservation.get("item_id", "")).strip_edges()
		var amount = max(int(raw_reservation.get("amount", 0)), 0)
		if item_id == "" or amount <= 0:
			continue
		owner_unit.add_enemy_item(item_id, amount)
		result["restored_items"].append({
			"item_id": item_id,
			"amount": amount
		})

	event["enemy_reserved_items"] = []
	result["labels"].append("enemy_reserved_items_restored_without_spend")
	return result


func release_reserved_energy_for_nullified_event(event: Dictionary) -> Dictionary:
	var energy_cost: float = get_event_energy_cost(event)
	var event_side := str(event.get("event_side", "")).strip_edges()
	var result: Dictionary = {
		"status": "success",
		"reason": "",
		"event_id": event.get("event_id", null),
		"event_side": event_side,
		"energy_cost": energy_cost,
		"labels": [
			"nullified_todo_energy_release"
		]
	}

	if event_side != "player" and event_side != "enemy":
		return result
	if energy_cost <= 0.0:
		return result
	if not bool(event.get("energy_reserved", false)):
		return result

	var release_handler = energy_handler
	if event_side == "enemy":
		release_handler = enemy_energy_handler

	if release_handler == null or not release_handler.has_method("release_reserved_energy"):
		result["status"] = "failed"
		result["reason"] = "missing " + event_side + " energy_handler release_reserved_energy"
		return result

	var release_result = release_handler.release_reserved_energy(energy_cost)
	if not is_energy_result_success(release_result):
		result["status"] = "failed"
		result["reason"] = get_energy_result_reason(release_result, "reserved energy release failed")
		return result

	result["energy_handler_result"] = release_result
	event["energy_reserved"] = false
	event["reserved_energy_cost"] = 0.0
	if event_side == "enemy":
		sync_active_enemy_energy_from_handler()
	return result


func release_reserved_ammo_for_nullified_event(event: Dictionary) -> Dictionary:
	var ammo_group: String = get_event_ammo_group(event)
	var ammo_cost: int = max(int(event.get("reserved_ammo_cost", 0)), get_event_ammo_cost(event))
	var result: Dictionary = {
		"status": "success",
		"reason": "",
		"event_id": event.get("event_id", null),
		"ammo_group": ammo_group,
		"ammo_cost": ammo_cost,
		"labels": [
			"nullified_todo_ammo_release"
		]
	}

	if str(event.get("event_side", "")) != "player":
		return result
	if ammo_cost <= 0:
		return result
	if not bool(event.get("ammo_reserved", false)):
		return result

	if ammo_handler == null or not ammo_handler.has_method("release_reserved_ammo"):
		result["status"] = "failed"
		result["reason"] = "missing ammo_handler release_reserved_ammo"
		return result

	var release_result = ammo_handler.release_reserved_ammo(ammo_group, ammo_cost)
	if not is_ammo_result_success(release_result):
		result["status"] = "failed"
		result["reason"] = get_ammo_result_reason(release_result, "reserved ammo release failed")
		return result

	result["ammo_handler_result"] = release_result
	event["ammo_reserved"] = false
	event["reserved_ammo_cost"] = 0
	return result
	
	
func spend_energy_for_completed_event(event: Dictionary) -> Dictionary:
	# Summary: Spend already-reserved EnergyHandler expected-use when a completed TODO resolves.
	var energy_cost: float = get_event_energy_cost(event)
	var event_side := str(event.get("event_side", "")).strip_edges()
	var result: Dictionary = {
		"status": "success",
		"reason": "",
		"event_id": event.get("event_id", null),
		"event_side": event_side,
		"energy_cost": energy_cost,
		"labels": [
			"battle_manager_energy_spend_bridge",
			"energy_spent_on_completion"
		]
	}

	if event_side != "player" and event_side != "enemy":
		return result

	if energy_cost <= 0.0:
		return result

	var spend_handler = energy_handler
	if event_side == "enemy":
		spend_handler = enemy_energy_handler
		result["labels"].append("enemy_energy_spend_bridge")
	else:
		result["labels"].append("player_energy_spend_bridge")

	if spend_handler == null or not spend_handler.has_method("spend_reserved_energy"):
		result["status"] = "failed"
		result["reason"] = "missing " + event_side + " energy_handler spend_reserved_energy"
		return result

	var spend_result = spend_handler.spend_reserved_energy(energy_cost)
	if not is_energy_result_success(spend_result):
		result["status"] = "failed"
		result["reason"] = get_energy_result_reason(spend_result, "reserved energy spend failed")
		return result

	result["energy_handler_result"] = spend_result
	if event_side == "enemy":
		sync_active_enemy_energy_from_handler()
	return result


func sync_active_enemy_energy_from_handler() -> void:
	# Summary: Mirror enemy EnergyHandler values back into the active enemy adapter after spend/cleanup.
	if enemy_energy_handler == null:
		return
	if not (active_enemy is BattleV2UnitAdapter):
		return
	var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
	enemy_state.enemy_energy_current = enemy_energy_handler.current_energy
	enemy_state.enemy_energy_max = enemy_energy_handler.max_energy
	enemy_state.enemy_reserved_energy = enemy_energy_handler.reserved_energy


func get_event_energy_cost(event: Dictionary) -> float:
	# Summary: Read completed TODO energy cost from packet payload without owning energy calculations.
	var data_payload = event.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY:
		return max(float(data_payload.get("energy_cost", event.get("energy_cost", 0.0))), 0.0)

	return max(float(event.get("energy_cost", 0.0)), 0.0)


func spend_ammo_for_completed_event(event: Dictionary) -> Dictionary:
	# Summary: Spend already-reserved AmmoHandler expected-use when a completed player TODO resolves.
	var ammo_group: String = get_event_ammo_group(event)
	var ammo_cost: int = get_event_ammo_cost(event)
	var result: Dictionary = {
		"status": "success",
		"reason": "",
		"event_id": event.get("event_id", null),
		"ammo_group": ammo_group,
		"ammo_cost": ammo_cost,
		"labels": [
			"battle_manager_ammo_spend_bridge",
			"ammo_spend_on_todo_complete"
		]
	}

	if str(event.get("event_side", "")) != "player":
		return result

	if ammo_cost <= 0:
		return result

	if ammo_handler == null or not ammo_handler.has_method("spend_reserved_ammo"):
		result["status"] = "failed"
		result["reason"] = "missing ammo_handler spend_reserved_ammo"
		return result

	var spend_result = ammo_handler.spend_reserved_ammo(ammo_group, ammo_cost, inventory)
	if not is_ammo_result_success(spend_result):
		result["status"] = "failed"
		result["reason"] = get_ammo_result_reason(spend_result, "reserved ammo spend failed")
		return result

	result["ammo_handler_result"] = spend_result
	return result


func get_event_ammo_group(event: Dictionary) -> String:
	# Summary: Read completed TODO ammo group from packet payload without owning ammo rules.
	var data_payload = event.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY:
		return str(data_payload.get("ammo_group", event.get("ammo_group", "")))

	return str(event.get("ammo_group", ""))


func get_event_ammo_cost(event: Dictionary) -> int:
	# Summary: Read completed TODO ammo cost from packet payload without owning ammo rules.
	var data_payload = event.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY:
		return max(int(data_payload.get("total_ammo_cost", data_payload.get("ammo_cost", event.get("ammo_cost", 0)))), 0)

	return max(int(event.get("ammo_cost", 0)), 0)


func spend_consumable_for_completed_event(event: Dictionary) -> Dictionary:
	# Summary: Spend one executed consumable after its execute TODO completes.
	var consumable_id := get_event_consumable_id(event)
	var should_spend := should_spend_consumable_for_event(event)
	var result: Dictionary = {
		"status": "success",
		"reason": "",
		"event_id": event.get("event_id", null),
		"consumable_id": consumable_id,
		"consumable_cost": 1 if should_spend else 0,
		"labels": [
			"battle_manager_consumable_spend_bridge",
			"consumable_spend_on_execute_todo_complete"
		]
	}

	if str(event.get("event_side", "")) != "player":
		return result

	if not should_spend:
		return result

	if consumable_id == "":
		result["status"] = "failed"
		result["reason"] = "missing consumable id"
		return result

	if not consume_inventory_item(consumable_id, 1):
		result["status"] = "failed"
		result["reason"] = "inventory consumable spend failed"
		return result

	result["inventory_save_data"] = get_inventory_save_data_for_result()
	return result


func should_spend_consumable_for_event(event: Dictionary) -> bool:
	# Summary: Identify execute-completion events that consume one inventory item.
	var event_type := str(event.get("event_type", "")).strip_edges().to_lower()
	var action_id := str(event.get("action_id", "")).strip_edges().to_lower()
	if event_type.begins_with("execute_"):
		return true
	if action_id == "execute_consumable":
		return true
	return false


func get_event_consumable_id(event: Dictionary) -> String:
	# Summary: Read the consumable id from event data or item id.
	var data_payload = event.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY:
		var data_id := str(data_payload.get("consumable_id", "")).strip_edges()
		if data_id != "":
			return data_id
	return str(event.get("item_id", "")).strip_edges()


func consume_inventory_item(item_id: String, amount: int = 1) -> bool:
	# Summary: Consume a regular inventory item from live Inventory or Battle V2 snapshot data.
	if amount <= 0:
		return true
	if inventory == null:
		return false
	if inventory is Dictionary:
		return consume_snapshot_item(item_id, amount, inventory)
	if inventory.has_method("consume_item"):
		return inventory.consume_item(item_id, amount)
	return false


func consume_snapshot_item(item_id: String, amount: int, inventory_ref: Dictionary) -> bool:
	# Summary: Mutate the Battle V2 inventory snapshot for regular consumable spending.
	var inventory_data = inventory_ref.get("inventory_save_data", {})
	if typeof(inventory_data) != TYPE_DICTIONARY:
		return false

	var remaining = max(amount, 0)
	for section_name in ["main", "drones"]:
		var section = inventory_data.get(section_name, {})
		if typeof(section) != TYPE_DICTIONARY:
			continue

		for slot_name in section.keys():
			var slot = section.get(slot_name, {})
			if typeof(slot) != TYPE_DICTIONARY:
				continue
			if str(slot.get("item_id", "")) != item_id:
				continue

			var available = max(int(slot.get("count", 0)), 0)
			if available <= 0:
				continue

			var take: int = min(available, remaining)
			slot["count"] = available - take
			if int(slot["count"]) <= 0:
				slot["item_id"] = ""
				slot["count"] = 0

			section[slot_name] = slot
			remaining -= take

			if remaining <= 0:
				inventory_data[section_name] = section
				inventory_ref["inventory_save_data"] = inventory_data
				return true

		inventory_data[section_name] = section

	inventory_ref["inventory_save_data"] = inventory_data
	return false


func get_inventory_save_data_for_result() -> Dictionary:
	# Summary: Return updated Battle V2 snapshot data after consumable spending.
	if inventory is Dictionary:
		var data = inventory.get("inventory_save_data", {})
		if typeof(data) == TYPE_DICTIONARY:
			return data.duplicate(true)
	return {}


func is_energy_result_success(value: Variant) -> bool:
	# Summary: Accept modern EnergyHandler result packets and legacy boolean returns.
	if typeof(value) == TYPE_DICTIONARY:
		return str(value.get("status", "")) == "success"
	return bool(value)


func get_energy_result_reason(value: Variant, fallback: String) -> String:
	# Summary: Read an EnergyHandler result-packet reason with a safe fallback.
	if typeof(value) == TYPE_DICTIONARY:
		var reason: String = str(value.get("reason", ""))
		if reason != "":
			return reason
	return fallback


func is_ammo_result_success(value: Variant) -> bool:
	# Summary: Accept modern AmmoHandler result packets and legacy boolean returns.
	if typeof(value) == TYPE_DICTIONARY:
		return str(value.get("status", "")) == "success"
	return bool(value)


func get_ammo_result_reason(value: Variant, fallback: String) -> String:
	# Summary: Read an AmmoHandler result-packet reason with a safe fallback.
	if typeof(value) == TYPE_DICTIONARY:
		var reason: String = str(value.get("reason", ""))
		if reason != "":
			return reason
	return fallback


func resolve_state_changes(event: Dictionary) -> Dictionary:
	# PURPOSE: Apply completed state-change TODO effects before damage/effect events, using event ownership fields without assuming player/enemy direction.

	if Globals.debug_battleManager:
		print("[resolve_state_changes] START | event:", event)

	var result := {
		"type": "state_change",
		"event_id": event.get("event_id", null),
		"event_subtype": event.get("event_subtype", ""),
		"applied": false,
		"label": "none"
	}

	# --- OWNERSHIP READ PHASE ---
	var source_unit = event.get("source_unit")
	var target_unit = event.get("target_unit")
	var owner_unit = event.get("owner_unit")
	var event_side = event.get("event_side", "")
	var subtype = event.get("event_subtype", "")

	if Globals.debug_battleManager:
		print("[resolve_state_changes] OWNER | source:", source_unit, " target:", target_unit, " owner:", owner_unit, " side:", event_side)
		print("[resolve_state_changes] CHECK subtype:", subtype)

	# --- LOCK RESTORE ---
	if subtype == "lock_restore":
		if Globals.debug_battleManager:
			print("[resolve_state_changes] APPLY: lock_restore on owner_unit")

		if not apply_lock_restore_to_unit(owner_unit, event_side):
			result["blocked_reason"] = "UNDEFINED — owner_unit missing lock restore method"
			return result

		result["applied"] = true
		return result

	# --- LOCK LOST ---
	if subtype == "lock_lost":
		if Globals.debug_battleManager:
			print("[resolve_state_changes] APPLY: lock_lost on owner_unit")

		if not apply_lock_lost_to_unit(owner_unit, event_side):
			result["blocked_reason"] = "UNDEFINED — owner_unit missing lock lost method"
			return result

		result["applied"] = true
		return result

	# --- EVADE COMPLETE ---
	if subtype == "evade_complete":
		if Globals.debug_battleManager:
			print("[resolve_state_changes] APPLY: evade_complete → both source and target lose lock")

		var data_payload = event.get("data", {})
		if typeof(data_payload) == TYPE_DICTIONARY and bool(data_payload.get("lock_loss_already_applied", false)):
			result["label"] = "evade_lock_loss_already_applied"
		else:
			apply_lock_lost_to_unit(source_unit, event_side)
			apply_lock_lost_to_unit(target_unit, "")
			result["label"] = "evade_locks_lost"

		var pipeline_disruption := {
			"disrupted": false,
			"blocked_reason": "lane_intervention_gate_already_applied",
			"labels": ["evade_lane_intervention_gate"]
		}
		if typeof(data_payload) != TYPE_DICTIONARY or not bool(data_payload.get("evade_lane_intervention_applied", false)):
			pipeline_disruption = disrupt_next_opposing_pipeline_event(event)
		result["pipeline_disruption"] = pipeline_disruption

		result["applied"] = true
		result["labels"] = [
			"evade_resolution_rule",
			"evade_todo_completed",
			"evade_lock_loss_resolved"
		]
		if bool(pipeline_disruption.get("disrupted", false)):
			result["labels"].append("evade_pipeline_disrupted")
		return result

	# --- SHIELD SWITCH COMPLETE ---
	if subtype == "shield_switch_complete":
		if Globals.debug_battleManager:
			print("[resolve_state_changes] APPLY: shield_switch_complete on owner_unit")

		if not owner_unit.has_method("set_selected_shield"):
			result["blocked_reason"] = "UNDEFINED — owner_unit missing set_selected_shield"
			return result

		if not owner_unit.has_method("set_shield_switching"):
			result["blocked_reason"] = "UNDEFINED — owner_unit missing set_shield_switching"
			return result

		owner_unit.set_selected_shield(owner_unit.pending_shield)
		owner_unit.set_shield_switching(false)

		result["applied"] = true
		return result

	# --- SHIELD REMOVE / POWER DOWN COMPLETE ---
	if subtype == "shield_remove_complete":
		if Globals.debug_battleManager:
			print("[resolve_state_changes] APPLY: shield_remove_complete on owner_unit")

		if owner_unit == null:
			result["blocked_reason"] = "UNDEFINED — missing owner_unit for shield remove"
			return result

		if owner_unit.has_method("remove_shield_for_energy_empty"):
			owner_unit.remove_shield_for_energy_empty()
		else:
			if owner_unit.has_method("set_shield_switching"):
				owner_unit.set_shield_switching(false)
			if owner_unit.has_method("set_selected_shield"):
				owner_unit.set_selected_shield(null)
			if owner_unit.has_method("set_shield_power_level"):
				owner_unit.set_shield_power_level(0)

		result["applied"] = true
		result["label"] = "shield_removed_for_empty_energy"
		return result

	# --- CONSUMABLE LOAD COMPLETE ---
	if subtype == "load_consumable_complete":
		if Globals.debug_battleManager:
			print("[resolve_state_changes] APPLY: load_consumable_complete on owner_unit")

		if owner_unit == null or not owner_unit.has_method("set_loaded_consumable"):
			result["blocked_reason"] = "UNDEFINED — owner_unit missing set_loaded_consumable"
			return result

		var data_payload = event.get("data", {})
		var loaded_consumable = event.get("item_id", null)
		if typeof(data_payload) == TYPE_DICTIONARY:
			loaded_consumable = data_payload.get("item_data", data_payload.get("consumable_id", loaded_consumable))

		owner_unit.set_loaded_consumable(loaded_consumable, "ready")

		result["applied"] = true
		result["label"] = "loaded_consumable_ready"
		return result

	# --- CONSUMABLE CLEAR COMPLETE ---
	if subtype == "clear_loaded_consumable_complete":
		if Globals.debug_battleManager:
			print("[resolve_state_changes] APPLY: clear_loaded_consumable_complete on owner_unit")

		if owner_unit == null or not owner_unit.has_method("clear_loaded_consumable_without_spend"):
			result["blocked_reason"] = "UNDEFINED - owner_unit missing clear_loaded_consumable_without_spend"
			return result

		owner_unit.clear_loaded_consumable_without_spend()

		result["applied"] = true
		result["label"] = "loaded_consumable_cleared_without_spend"
		return result

	# --- UNDEFINED STATE CHANGE ---
	if Globals.debug_battleManager:
		print("[resolve_state_changes] UNDEFINED subtype:", subtype)

	result["blocked_reason"] = "UNDEFINED — NEEDS SPEC: state-change subtype"
	return result
	
	
	
	
func check_victory_conditions() -> String:
	# Summary: Checks whether the active Battle V2 fight has reached a terminal outcome.
	#
	# Important behavior rule:
	# This function ONLY checks and reports the outcome.
	# It must NOT call end_battle_cleanup().
	# It must NOT clear active_enemy.
	# It must NOT clear active_player_state.
	#
	# Reason:
	# battle_v2_scene.gd still needs the active enemy adapter after victory so it can
	# package the defeated-world-enemy result before BattleManager cleanup clears refs.
	#
	# Return values:
	# - "player_victory"
	# - "player_defeat"
	# - "battle_continues"

	# ------------------------------------------------------
	# START TRACE
	# Priority 2: useful battle-resolution checkpoint.
	# ------------------------------------------------------
	if Globals.print_priority_5:
		print(
			"[BattleManager.check_victory_conditions] START",
			" | battle_active=", battle_active,
			" | active_enemy=", active_enemy,
			" | active_player_state=", active_player_state
		)

	# ------------------------------------------------------
	# GUARD: Battle must still be active.
	# If this is being called after cleanup, do not report a
	# fresh terminal outcome again.
	# ------------------------------------------------------
	if not battle_active:
		if Globals.print_priority_5:
			print("[BattleManager.check_victory_conditions] BLOCKED | battle_active=false")

		return "battle_continues"

	# ------------------------------------------------------
	# ENEMY DEFEAT CHECK
	# Victory happens when the active enemy hull reaches 0 or below.
	# Cleanup is intentionally deferred to battle_v2_scene.gd.
	# ------------------------------------------------------
	var enemy_hull := INF

	if active_enemy != null:
		enemy_hull = get_unit_hull_current(active_enemy, "enemy")

		if Globals.print_priority_5:
			print(
				"[BattleManager.check_victory_conditions] CHECK enemy hull",
				" | enemy_hull=", enemy_hull
			)

		if enemy_hull <= 0.001:
			if Globals.print_priority_5:
				print(
					"[BattleManager.check_victory_conditions] RESULT player_victory",
					" | enemy_hull=", enemy_hull,
					" | cleanup_deferred_to_scene=true"
				)

			return "player_victory"

	else:
		if Globals.print_priority_5:
			print("[BattleManager.check_victory_conditions] WARNING | active_enemy=null during victory check")

	# ------------------------------------------------------
	# PLAYER DEFEAT CHECK
	# Defeat happens when active player hull reaches 0 or below.
	# Cleanup is intentionally deferred to battle_v2_scene.gd.
	# ------------------------------------------------------
	var player_hull := INF

	if active_player_state != null:
		player_hull = get_unit_hull_current(active_player_state, "player")

		if Globals.print_priority_5:
			print(
				"[BattleManager.check_victory_conditions] CHECK player hull",
				" | player_hull=", player_hull
			)

		if player_hull <= 0.001:
			if Globals.print_priority_5:
				print(
					"[BattleManager.check_victory_conditions] RESULT player_defeat",
					" | player_hull=", player_hull,
					" | cleanup_deferred_to_scene=true"
				)

			return "player_defeat"

	else:
		if Globals.print_priority_5:
			print("[BattleManager.check_victory_conditions] WARNING | active_player_state=null during defeat check")

	# ------------------------------------------------------
	# BATTLE CONTINUES
	# Priority 3 because this may print often during repeated
	# TODO batch resolution.
	# ------------------------------------------------------
	if Globals.print_priority_3:
		print(
			"[BattleManager.check_victory_conditions] RESULT battle_continues",
			" | enemy_hull=", enemy_hull,
			" | player_hull=", player_hull
		)

	return "battle_continues"


func get_unit_hull_current(unit, side_hint: String = "") -> float:
	# PURPOSE: Read current hull from adapter/object/dictionary using side-specific fallbacks.
	if unit == null:
		return INF

	if typeof(unit) == TYPE_DICTIONARY:
		if side_hint == "enemy":
			return float(unit.get("enemy_hull_current", unit.get("hull_current", unit.get("hp", INF))))
		if side_hint == "player":
			return float(unit.get("player_hull_current", unit.get("hull_current", unit.get("hp", INF))))
		return float(unit.get("hull_current", unit.get("hp", INF)))

	if unit is Object:
		var side_value := get_battle_unit_side(unit, side_hint)
		var hull_value = null

		if side_value == "enemy":
			hull_value = unit.get("enemy_hull_current")
			if hull_value != null:
				return float(hull_value)

		if side_value == "player":
			hull_value = unit.get("player_hull_current")
			if hull_value != null:
				return float(hull_value)

		hull_value = unit.get("hull_current")
		if hull_value != null:
			return float(hull_value)

		hull_value = unit.get("hp")
		if hull_value != null:
			return float(hull_value)

	return INF
	
	
	
	
func evaluate_lock_state(event: Dictionary) -> String:
	# PURPOSE: Determine whether this completed TODO event has valid lock at the exact moment of resolution, using event ownership fields only.

	if Globals.debug_battleManager:
		print("[evaluate_lock_state] START | event:", event)

	# --- LOCK REQUIREMENT CHECK ---
	# If this event does not require lock, resolution may continue without good lock.
	if Globals.debug_battleManager:
		print("[evaluate_lock_state] CHECK: requires_lock")

	if not event.get("requires_lock", true):
		if Globals.debug_battleManager:
			print("[evaluate_lock_state] RESULT: lock_not_required")

		return "lock_not_required"

	# --- SOURCE UNIT CHECK ---
	# Lock is always checked from source_unit.
	# BattleManager must not assume source_unit is player or enemy.
	if Globals.debug_battleManager:
		print("[evaluate_lock_state] CHECK: source_unit exists")

	var source_unit = event.get("source_unit")

	if source_unit == null:
		if Globals.debug_battleManager:
			print("[evaluate_lock_state] RESULT: missing_source_unit")

		return "missing_source_unit"

	# --- LOCK DISABLED CHECK ---
	# Source unit may be player, enemy, ally, or future unit type.
	# Use available lock-disabled fields without assuming side.
	if Globals.debug_battleManager:
		print("[evaluate_lock_state] CHECK: source lock disabled")

	if source_unit.get("player_lock_disabled") == true:
		if Globals.debug_battleManager:
			print("[evaluate_lock_state] RESULT: lock_disabled")

		return "lock_disabled"

	if source_unit.get("enemy_lock_disabled") == true:
		if Globals.debug_battleManager:
			print("[evaluate_lock_state] RESULT: lock_disabled")

		return "lock_disabled"

	# --- GOOD LOCK CHECK ---
	# Source unit must have good lock for lock-required actions.
	if Globals.debug_battleManager:
		print("[evaluate_lock_state] CHECK: source good lock")

	if source_unit.get("player_good_lock") == true:
		if Globals.debug_battleManager:
			print("[evaluate_lock_state] RESULT: good_lock")

		return "good_lock"

	if source_unit.get("enemy_good_lock") == true:
		if Globals.debug_battleManager:
			print("[evaluate_lock_state] RESULT: good_lock")

		return "good_lock"

	# --- NO LOCK FALLBACK ---
	# If lock is required, not disabled, and not good, result is no_lock.
	if Globals.debug_battleManager:
		print("[evaluate_lock_state] RESULT: no_lock")

	return "no_lock"
	
	
	
	
func resolve_weapon_damage(event: Dictionary) -> Dictionary:
	# PURPOSE: Resolve completed weapon TODO damage only after lock passes, then route approved damage through apply_damage().

	if Globals.debug_battleManager:
		print("[resolve_weapon_damage] START | event:", event)

	var result := {
		"type": "weapon_damage",
		"event_id": event.get("event_id", null),
		"damage_applied": false,
		"blocked_reason": "none",
		"labels": []
	}

	# --- LOCK CHECK PHASE ---
	# Weapon damage must pass lock check before damage is allowed.
	if Globals.debug_battleManager:
		print("[resolve_weapon_damage] CHECK: evaluate_lock_state")

	var lock_result = evaluate_lock_state(event)

	if Globals.debug_battleManager:
		print("[resolve_weapon_damage] LOCK RESULT:", lock_result)

	# --- NO LOCK / BAD LOCK BLOCK ---
	# If lock fails, weapon damage function does not run.
	if lock_result != "good_lock" and lock_result != "lock_not_required":
		if Globals.debug_battleManager:
			print("[resolve_weapon_damage] RESULT: weapon blocked by lock_result:", lock_result)

		result["blocked_reason"] = lock_result
		result["labels"].append("weapon_damage_blocked_no_lock")
		result["labels"].append("miss_animation")

		return result

	# --- OWNERSHIP READ PHASE ---
	# Damage source and target come from event fields.
	var source_unit = event.get("source_unit")
	var target_unit = event.get("target_unit")

	if Globals.debug_battleManager:
		print("[resolve_weapon_damage] OWNER | source:", source_unit, " target:", target_unit)

	# --- DAMAGE PACKET BUILD ---
	# Damage is not applied here.
	# This only packages approved damage for apply_damage().
	var damage_packet := {
		"damage_type": event.get("damage_type", ""),
		"damage_value": event.get("damage_value", 0.0),
		"explosive_pass_percent": get_event_explosive_pass_percent(event),
		"item_id": event.get("item_id", null),
		"data": event.get("data", {})
	}

	if Globals.debug_battleManager:
		print("[resolve_weapon_damage] DAMAGE PACKET:", damage_packet)

	# --- APPROVED DAMAGE ROUTE ---
	# apply_damage() owns damage type routing.
	var damage_result = apply_damage(source_unit, target_unit, damage_packet)

	result["damage_applied"] = true
	result["damage_result"] = damage_result

	if Globals.debug_battleManager:
		print("[resolve_weapon_damage] END RESULT:", result)

	return result
	
	
	
	
func get_event_explosive_pass_percent(event: Dictionary) -> float:
	# Summary: Read explosive hull-pass percent from top-level or nested event data.
	var data_payload = event.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY and data_payload.has("explosive_pass_percent"):
		return clamp(float(data_payload.get("explosive_pass_percent", 0.0)), 0.0, 1.0)
	return clamp(float(event.get("explosive_pass_percent", 0.0)), 0.0, 1.0)
	
	
	
func resolve_explosive(event: Dictionary) -> Dictionary:
	# PURPOSE: Resolve executed explosive consumable after execute TODO completion, enforcing explosive-specific lock rules before damage routing.

	if Globals.debug_battleManager:
		print("[resolve_explosive] START | event:", event)

	var result := {
		"type": "explosive",
		"event_id": event.get("event_id", null),
		"damage_applied": false,
		"blocked_reason": "none",
		"labels": []
	}

	# --- OWNERSHIP READ PHASE ---
	# Explosive resolution must use event ownership fields.
	var source_unit = event.get("source_unit")
	var target_unit = event.get("target_unit")

	if Globals.debug_battleManager:
		print("[resolve_explosive] OWNER | source:", source_unit, " target:", target_unit)

	# --- EXPLOSIVE SPEND PHASE ---
	# Executed explosive is already committed at this stage.
	# Inventory owns actual count mutation.
	if Globals.debug_battleManager:
		print("[resolve_explosive] APPLY: explosive_spent_on_execute")

	result["labels"].append("explosive_spent_on_execute")

	# --- LOCK REQUIREMENT PHASE ---
	# Explosives require good lock to apply damage.
	if Globals.debug_battleManager:
		print("[resolve_explosive] APPLY: explosive_requires_good_lock")

	result["labels"].append("explosive_requires_good_lock")

	# --- LOCK CHECK PHASE ---
	if Globals.debug_battleManager:
		print("[resolve_explosive] CHECK: evaluate_lock_state")

	var lock_result = evaluate_lock_state(event)

	if Globals.debug_battleManager:
		print("[resolve_explosive] LOCK RESULT:", lock_result)

	# --- NO LOCK BLOCK PHASE ---
	# No lock means:
	# explosive is spent
	# explosive damage function does not run
	# miss feedback triggers
	if lock_result != "good_lock":
		if Globals.debug_battleManager:
			print("[resolve_explosive] RESULT: explosive blocked by lock")

		result["blocked_reason"] = lock_result

		result["labels"].append("explosive_block_damage_no_lock")
		result["labels"].append("explosive_miss_feedback")
		result["labels"].append("miss_animation")
		clear_executed_consumable_state(event)

		return result

	# --- GOOD LOCK APPROVAL PHASE ---
	# Explosive damage is now allowed to route.
	if Globals.debug_battleManager:
		print("[resolve_explosive] APPLY: explosive_apply_damage_good_lock")

	result["labels"].append("explosive_apply_damage_good_lock")

	# --- DAMAGE PACKET BUILD ---
	# Damage math itself is owned by apply_damage().
	var damage_packet := {
		"damage_type": "explosive",
		"damage_value": event.get("damage_value", 0.0),
		"explosive_pass_percent": get_event_explosive_pass_percent(event),
		"item_id": event.get("item_id", null),
		"data": event.get("data", {})
	}

	if Globals.debug_battleManager:
		print("[resolve_explosive] DAMAGE PACKET:", damage_packet)

	# --- DAMAGE ROUTE PHASE ---
	var damage_result = apply_damage(source_unit, target_unit, damage_packet)

	result["damage_applied"] = true
	result["damage_result"] = damage_result

	# --- EXPLOSIVE RESULT LABELS ---
	if Globals.debug_battleManager:
		print("[resolve_explosive] APPLY: explosive result labels")

	result["labels"].append("explosive_pass_damage")
	result["labels"].append("explosive_shield_damage_math")
	clear_executed_consumable_state(event)

	if Globals.debug_battleManager:
		print("[resolve_explosive] END RESULT:", result)

	return result
	
	
	
func resolve_repair(event: Dictionary) -> Dictionary:
	# Summary: Resolve a prepared repair kit after its execute TODO completes.
	if Globals.debug_battleManager:
		print("[resolve_repair] START | event:", event)

	var owner_unit = event.get("owner_unit", event.get("source_unit", null))
	var repair_amount := get_event_repair_amount(event)
	var result := {
		"type": "repair",
		"event_id": event.get("event_id", null),
		"repair_applied": false,
		"repair_amount": repair_amount,
		"hull_before": get_unit_hull_current(owner_unit),
		"hull_after": get_unit_hull_current(owner_unit),
		"hull_repaired": 0.0,
		"blocked_reason": "none",
		"labels": [
			"repair_kit_execute",
			"consumable_spent_on_execute"
		]
	}

	if owner_unit == null or not owner_unit.has_method("repair_hull"):
		result["blocked_reason"] = "missing repair_hull target"
		clear_executed_consumable_state(event)
		return result

	if repair_amount <= 0.0:
		result["blocked_reason"] = "missing repair amount"
		clear_executed_consumable_state(event)
		return result

	var hull_before := get_unit_hull_current(owner_unit)
	var repair_result = owner_unit.repair_hull(repair_amount)
	var hull_after := get_unit_hull_current(owner_unit)

	result["repair_result"] = repair_result
	result["repair_applied"] = true
	result["hull_before"] = hull_before
	result["hull_after"] = hull_after
	result["hull_repaired"] = max(hull_after - hull_before, 0.0)
	result["labels"].append("repair_hull_applied")
	clear_executed_consumable_state(event)
	return result


func resolve_shield_repair(event: Dictionary) -> Dictionary:
	# Summary: Resolve a shield patch only while the equipped shield remains above zero HP.
	var owner_unit = event.get("owner_unit", event.get("source_unit", null))
	var repair_amount := get_event_shield_repair_amount(event)
	var before := get_unit_shield_hp_current(owner_unit)
	var result := {
		"type": "shield_repair",
		"event_id": event.get("event_id", null),
		"repair_applied": false,
		"shield_repair_amount": repair_amount,
		"shield_before": before,
		"shield_after": before,
		"shield_repaired": 0.0,
		"blocked_reason": "none",
		"labels": [
			"shield_repair_item_execute",
			"consumable_spent_on_execute"
		]
	}

	if owner_unit == null or not owner_unit.has_method("repair_shield"):
		result["blocked_reason"] = "missing_repair_shield_target"
		clear_executed_consumable_state(event)
		return result
	if repair_amount <= 0.0:
		result["blocked_reason"] = "missing_shield_repair_amount"
		clear_executed_consumable_state(event)
		return result

	var repair_result = owner_unit.repair_shield(repair_amount)
	if typeof(repair_result) != TYPE_DICTIONARY or str(repair_result.get("status", "")) != "success":
		result["blocked_reason"] = str(repair_result.get("blocked_reason", "shield_repair_failed")) if typeof(repair_result) == TYPE_DICTIONARY else "shield_repair_failed"
		result["repair_result"] = repair_result
		clear_executed_consumable_state(event)
		return result

	result["repair_result"] = repair_result
	result["repair_applied"] = true
	result["shield_after"] = get_unit_shield_hp_current(owner_unit)
	result["shield_repaired"] = max(float(result["shield_after"]) - before, 0.0)
	result["labels"].append("shield_repair_applied")
	clear_executed_consumable_state(event)
	return result


func resolve_recharge(event: Dictionary) -> Dictionary:
	# Summary: Resolve a prepared recharge kit after its execute TODO completes.
	if Globals.debug_battleManager:
		print("[resolve_recharge] START | event:", event)

	var event_side := str(event.get("event_side", "player")).strip_edges().to_lower()
	var recharge_handler = energy_handler
	if event_side == "enemy":
		recharge_handler = enemy_energy_handler

	var restore_amount := get_event_recharge_amount(event)
	var fill_to_max := get_event_recharge_to_full(event)
	var result := {
		"type": "recharge",
		"event_id": event.get("event_id", null),
		"recharge_applied": false,
		"energy_before": 0.0,
		"energy_after": 0.0,
		"energy_restored": 0.0,
		"blocked_reason": "none",
		"labels": [
			"recharge_kit_execute",
			"consumable_spent_on_execute"
		]
	}

	if recharge_handler == null or not recharge_handler.has_method("restore_energy"):
		result["blocked_reason"] = "missing energy restore handler"
		clear_executed_consumable_state(event)
		return result

	result["energy_before"] = recharge_handler.current_energy
	var restore_result = recharge_handler.restore_energy(restore_amount, fill_to_max)
	result["energy_result_packet"] = restore_result
	result["energy_after"] = recharge_handler.current_energy
	result["energy_restored"] = max(float(result["energy_after"]) - float(result["energy_before"]), 0.0)
	result["recharge_applied"] = true
	result["labels"].append("energy_restore_applied")

	if event_side == "enemy":
		sync_active_enemy_energy_from_handler()

	clear_executed_consumable_state(event)
	return result


func get_event_repair_amount(event: Dictionary) -> float:
	# Summary: Read repair amount from the execute repair packet.
	var data_payload = event.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY:
		var payload_amount := float(data_payload.get("heal_amount", data_payload.get("repair_amount", data_payload.get("hull_restore_amount", 0.0))))
		if payload_amount > 0.0:
			return payload_amount
	return max(float(event.get("heal_amount", event.get("repair_amount", event.get("hull_restore_amount", 0.0)))), 0.0)


func get_event_shield_repair_amount(event: Dictionary) -> float:
	# Summary: Read shield repair amount from an execute shield-repair packet.
	var data_payload = event.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY:
		return max(float(data_payload.get("shield_repair_amount", data_payload.get("repair_amount", 0.0))), 0.0)
	return 0.0


func get_event_recharge_amount(event: Dictionary) -> float:
	# Summary: Read energy restore amount from the execute recharge packet.
	var data_payload = event.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY:
		return max(float(data_payload.get("energy_restore_amount", data_payload.get("recharge_amount", 0.0))), 0.0)
	return 0.0


func get_event_recharge_to_full(event: Dictionary) -> bool:
	# Summary: Read whether this recharge item fills to max energy.
	var data_payload = event.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY:
		return bool(data_payload.get("recharge_to_full", true))
	return true


#func get_unit_hull_current(unit_ref) -> float:
	## Summary: Read current hull across PlayerState and BattleV2UnitAdapter shapes.
	#if unit_ref == null:
		#return 0.0
	#if unit_ref is BattleV2UnitAdapter:
		#var adapter: BattleV2UnitAdapter = unit_ref as BattleV2UnitAdapter
		#if adapter.unit_side == "enemy":
			#return adapter.enemy_hull_current
		#return adapter.player_hull_current
	#if unit_ref is Object:
		#var value = unit_ref.get("hull_current")
		#if value == null:
			#value = unit_ref.get("player_hull_current")
		#if value == null:
			#value = unit_ref.get("enemy_hull_current")
		#return float(value)
	#if unit_ref is Dictionary:
		#return float(unit_ref.get("hull_current", unit_ref.get("player_hull_current", unit_ref.get("enemy_hull_current", 0.0))))
	#return 0.0


func clear_executed_consumable_state(event: Dictionary) -> void:
	# Summary: Clear loaded consumable state after an execute TODO resolves/spends.
	var owner_unit = event.get("owner_unit", event.get("source_unit", null))
	if owner_unit == null:
		return
	if owner_unit.has_method("clear_loaded_consumable_after_spend"):
		owner_unit.clear_loaded_consumable_after_spend()
	elif owner_unit.has_method("clear_loaded_consumable_without_spend"):
		owner_unit.clear_loaded_consumable_without_spend()


func get_signal_defense_for_unit(unit) -> float:
	# Summary: Read signal defense from player or enemy battle-state packets without assuming one side-only field.
	if unit == null:
		return 0.0

	var signal_defense_keys := [
		"signal_defense",
		"player_signal_defense",
		"enemy_signal_defense"
	]

	if typeof(unit) == TYPE_DICTIONARY:
		for key in signal_defense_keys:
			if unit.has(key):
				return float(unit.get(key, 0.0))
		return 0.0

	if unit is Object:
		for key in signal_defense_keys:
			var value = unit.get(key)
			if value != null:
				return float(value)

	return 0.0
	
	
	
func resolve_signal(event: Dictionary) -> Dictionary:
	# PURPOSE: Resolve executed signal consumable after TODO completion, then apply successful signal disable through standardized effect_packet routing.

	if Globals.debug_battleManager:
		print("[resolve_signal] START | event:", event)

	var result := {
		"type": "signal",
		"event_id": event.get("event_id", null),
		"signal_applied": false,
		"blocked_reason": "none",
		"labels": []
	}

	# --- OWNERSHIP READ PHASE ---
	var source_unit = event.get("source_unit")
	var target_unit = event.get("target_unit")
	var owner_unit = event.get("owner_unit")
	var event_side = event.get("event_side", "")

	if Globals.debug_battleManager:
		print("[resolve_signal] OWNER | source:", source_unit, " target:", target_unit, " owner:", owner_unit, " side:", event_side)

	# --- SIGNAL SPEND PHASE ---
	if Globals.debug_battleManager:
		print("[resolve_signal] APPLY: consumable_spent_on_execute")

	result["labels"].append("consumable_spent_on_execute")

	# --- ACTIVE SIGNAL CHECK ---
	if Globals.debug_battleManager:
		print("[resolve_signal] CHECK: target active signal effect")

	var signal_already_active := false
	if stat_effect_handler != null and stat_effect_handler.has_method("has_effect_group"):
		signal_already_active = bool(stat_effect_handler.has_effect_group(target_unit, "signal"))
	elif target_unit != null and target_unit is Object:
		signal_already_active = target_unit.get("active_signal_effect") != null

	if signal_already_active:
		if Globals.debug_battleManager:
			print("[resolve_signal] RESULT: signal already active")

		result["blocked_reason"] = "signal_already_active"
		result["labels"].append("signal_fail_after_todo")
		clear_executed_consumable_state(event)
		return result

	# --- SIGNAL DATA READ ---
	var data = event.get("data", {})
	var signal_strength = data.get("signal_strength", 0)
	var signal_type = data.get("signal_type", "")
	var duration = data.get("duration", 5.0)

	if Globals.debug_battleManager:
		print("[resolve_signal] DATA | strength:", signal_strength, " type:", signal_type, " duration:", duration)

	# --- SIGNAL DEFENSE CHECK ---
	var signal_defense = get_signal_defense_for_unit(target_unit)

	if Globals.debug_battleManager:
		print("[resolve_signal] CHECK: signal_strength >= signal_defense |", signal_strength, ">=", signal_defense)

	if signal_strength < signal_defense:
		if Globals.debug_battleManager:
			print("[resolve_signal] RESULT: signal failed defense check")

		result["blocked_reason"] = "signal_failed_check"
		result["labels"].append("signal_fail_after_todo")
		clear_executed_consumable_state(event)
		return result

	# --- SIGNAL SUCCESS LABEL ---
	if Globals.debug_battleManager:
		print("[resolve_signal] RESULT: signal success")

	result["labels"].append("signal_success_apply_disable")

	var signal_flags: Dictionary = {}
	if typeof(data.get("flags", {})) == TYPE_DICTIONARY:
		signal_flags = data.get("flags", {}).duplicate(true)
	signal_flags["exclusive_per_unit"] = bool(signal_flags.get("exclusive_per_unit", true))
	var signal_tags: Array = []
	if typeof(signal_flags.get("tags", [])) == TYPE_ARRAY:
		signal_tags = signal_flags.get("tags", []).duplicate(true)
	for tag in ["signal", "disable", signal_type]:
		if str(tag).strip_edges() != "" and not signal_tags.has(tag):
			signal_tags.append(tag)
	signal_flags["tags"] = signal_tags

	# --- EFFECT PACKET BUILD ---
	var effect_packet := {
		"effect_id": signal_type,
		"effect_group": "signal",
		"effect_type": "disable",

		"source_unit": source_unit,
		"target_unit": target_unit,
		"owner_unit": owner_unit,
		"event_side": event_side,

		"duration": duration,
		"tick_rate": 0.0,
		"time_remaining": duration,

		"stack_rule": str(data.get("stack_rule", "unique")).strip_edges(),
		"priority": data.get("priority", 80),

		"affects": data.get("affects", ["weapon"]),

		"values": {
			"disabled_lane": data.get("disabled_lane", signal_type)
		},

		"flags": signal_flags,

		"source_event_id": event.get("event_id", null),

		"visual_labels": data.get("visual_labels", ["signal_success_apply_disable"])
	}

	if Globals.debug_battleManager:
		print("[resolve_signal] EFFECT PACKET:", effect_packet)

	# --- EFFECT ROUTE ---
	var effect_result = apply_stat_effects(effect_packet)

	result["signal_applied"] = effect_result.get("effect_applied", false)
	result["effect_result"] = effect_result

	if Globals.debug_battleManager:
		print("[resolve_signal] END RESULT:", result)

	clear_executed_consumable_state(event)
	return result
	
	
	
	


	
func resolve_pulse(event: Dictionary) -> Dictionary:
	# PURPOSE: Resolve completed pulse TODO by building pulse data and routing it to StatEffectHandler while leaving pulse timing/UI ownership outside BattleManager.

	if Globals.debug_battleManager:
		print("[resolve_pulse] START | event:", event)

	var result := {
		"type": "pulse",
		"event_id": event.get("event_id", null),
		"pulse_applied": false,
		"blocked_reason": "none",
		"labels": []
	}

	# --- OWNERSHIP READ PHASE ---
	# Pulse resolution uses explicit event ownership fields.
	var source_unit = event.get("source_unit")
	var target_unit = event.get("target_unit")

	if Globals.debug_battleManager:
		print("[resolve_pulse] OWNER | source:", source_unit, " target:", target_unit)

	# --- STAT EFFECT HANDLER CHECK ---
	# Pulse is represented as timing/stat effect data.
	# BattleManager routes it but does not own active pulse ticking.
	if Globals.debug_battleManager:
		print("[resolve_pulse] CHECK: stat_effect_handler exists")

	if stat_effect_handler == null:
		if Globals.debug_battleManager:
			print("[resolve_pulse] RESULT: missing stat_effect_handler")

		result["blocked_reason"] = "UNDEFINED — missing stat_effect_handler"
		return result

	# --- PULSE DATA BUILD ---
	# Pulse data should contain the timing pattern, duration, current window state, and timing config.
	var pulse_data := {
		"pulse_pattern": event.get("data", {}).get("pulse_pattern", []),
		"duration_time": event.get("data", {}).get("duration_time", 0.0),
		"current_window_state": event.get("data", {}).get("current_window_state", "N"),
		"window_timing": event.get("data", {}).get("window_timing", {})
	}

	if Globals.debug_battleManager:
		print("[resolve_pulse] PULSE DATA:", pulse_data)

	# --- PULSE PATTERN CHECK ---
	# Pulse needs a pattern to create opportunity windows.
	if Globals.debug_battleManager:
		print("[resolve_pulse] CHECK: pulse_pattern")

	if pulse_data["pulse_pattern"].is_empty():
		if Globals.debug_battleManager:
			print("[resolve_pulse] RESULT: missing pulse pattern")

		result["blocked_reason"] = "missing_pulse_pattern"
		return result

	# --- PULSE ROUTE PHASE ---
	# Official API:
	# stat_effect_handler.apply_pulse_effect(source_unit, target_unit, pulse_data)
	if Globals.debug_battleManager:
		print("[resolve_pulse] APPLY: stat_effect_handler.apply_pulse_effect")

	var pulse_result = stat_effect_handler.apply_pulse_effect(
		source_unit,
		target_unit,
		pulse_data
	)

	result["pulse_applied"] = true
	result["pulse_result"] = pulse_result

	# --- SEMANTIC LABELS ---
	# BattleManager can mark pulse resolution, but timing/UI is handled elsewhere.
	result["labels"].append("pulse_resolution_rule")
	result["labels"].append("pulse_applies_stat_effect")

	if Globals.debug_battleManager:
		print("[resolve_pulse] END RESULT:", result)

	return result


func apply_stat_effects(effect_packet: Dictionary) -> Dictionary:
	# PURPOSE: Validate and route a standardized effect_packet into StatEffectHandler.apply_effect(), keeping active effect ownership outside BattleManager.

	if Globals.debug_battleManager:
		print("[apply_stat_effects] START | effect_packet:", effect_packet)

	var result := {
		"type": "stat_effect_route",
		"effect_applied": false,
		"effect_result": "none",
		"blocked_reason": "none",
		"labels": []
	}

	# --- STAT EFFECT HANDLER CHECK ---
	# BattleManager does not store active effects.
	# StatEffectHandler owns stacking, replacement, refresh, activation, rejection, duration, and ticking.
	if Globals.debug_battleManager:
		print("[apply_stat_effects] CHECK: stat_effect_handler exists")

	if stat_effect_handler == null:
		if Globals.debug_battleManager:
			print("[apply_stat_effects] RESULT: missing stat_effect_handler")

		result["blocked_reason"] = "UNDEFINED — missing stat_effect_handler"
		result["labels"].append("effect_rejected")

		return result

	# --- EFFECT PACKET VALIDATION ---
	# Official packet fields required by the generic StatEffectHandler API.
	if Globals.debug_battleManager:
		print("[apply_stat_effects] CHECK: required effect_packet fields")

	var required_fields := [
		"effect_id",
		"effect_group",
		"effect_type",
		"source_unit",
		"target_unit",
		"owner_unit",
		"event_side",
		"duration",
		"tick_rate",
		"stack_rule",
		"priority",
		"affects",
		"values",
		"flags",
		"visual_labels"
	]

	for field_name in required_fields:
		if Globals.debug_battleManager:
			print("[apply_stat_effects] CHECK FIELD:", field_name)

		if not effect_packet.has(field_name):
			if Globals.debug_battleManager:
				print("[apply_stat_effects] RESULT: missing effect_packet field:", field_name)

			result["blocked_reason"] = "missing_effect_packet_field"
			result["missing_field"] = field_name
			result["labels"].append("effect_packet_validation")
			result["labels"].append("effect_rejected")

			return result

	# --- EFFECT API LABELS ---
	# These labels mark that the generic effect packet route is being used.
	result["labels"].append("stat_effect_apply_effect_api")
	result["labels"].append("effect_packet")
	result["labels"].append("effect_packet_validation")

	# --- EFFECT ROUTE ---
	# Official API:
	# stat_effect_handler.apply_effect(effect_packet)
	if Globals.debug_battleManager:
		print("[apply_stat_effects] APPLY: stat_effect_handler.apply_effect(effect_packet)")

	var handler_result = stat_effect_handler.apply_effect(effect_packet)

	if Globals.debug_battleManager:
		print("[apply_stat_effects] HANDLER RESULT:", handler_result)

	result["effect_result"] = handler_result
	var handler_status := ""
	var handler_reason := ""
	if typeof(handler_result) == TYPE_DICTIONARY:
		handler_status = str(handler_result.get("status", ""))
		handler_reason = str(handler_result.get("reason", ""))
	elif typeof(handler_result) == TYPE_STRING:
		handler_status = str(handler_result)
	else:
		handler_status = "applied" if bool(handler_result) else "failed"
	result["effect_status"] = handler_status
	result["labels"].append("effect_result")

	# --- HANDLER RESULT INTERPRETATION ---
	# Expected handler results:
	# applied, rejected, refreshed, replaced, stacked, blocked, failed
	if handler_status == "applied":
		result["effect_applied"] = true
		result["labels"].append("effect_applied")

	elif handler_status == "refreshed":
		result["effect_applied"] = true
		result["labels"].append("effect_refreshed")

	elif handler_status == "replaced":
		result["effect_applied"] = true
		result["labels"].append("effect_replaced")

	elif handler_status == "stacked":
		result["effect_applied"] = true
		result["labels"].append("effect_stacked")

	else:
		result["effect_applied"] = false
		result["blocked_reason"] = handler_reason if handler_reason != "" else handler_status
		result["labels"].append("effect_rejected")

	# --- VISUAL LABEL PASS-THROUGH ---
	# Effect packet may carry visual labels for AnimatorFetcher / Decorative_UI.
	# BattleManager records them but does not draw visuals.
	if Globals.debug_battleManager:
		print("[apply_stat_effects] CHECK: visual_labels")

	for visual_label in effect_packet.get("visual_labels", []):
		result["labels"].append(visual_label)

	if Globals.debug_battleManager:
		print("[apply_stat_effects] END RESULT:", result)

	return result
	
	
	
func resolve_action_result(event: Dictionary) -> Dictionary:
	# PURPOSE: Route a completed non-state-change TODO event into the correct BattleManager resolver without applying damage or effects directly.

	if Globals.debug_battleManager:
		print("[resolve_action_result] START | event:", event)

	var result := {
		"type": "action_result",
		"event_id": event.get("event_id", null),
		"event_group": event.get("event_group", ""),
		"routed": false,
		"route": "none",
		"blocked_reason": "none"
	}

	# --- OWNERSHIP VALIDATION ---
	if Globals.debug_battleManager:
		print("[resolve_action_result] CHECK: validate_event_ownership")

	var validation_result = validate_event_ownership(event)

	if not validation_result["valid"]:
		if Globals.debug_battleManager:
			print("[resolve_action_result] RESULT: invalid ownership:", validation_result)

		result["blocked_reason"] = "invalid_event_ownership"
		result["validation"] = validation_result
		return result

	# --- STATE CHANGE SAFETY ROUTE ---
	if Globals.debug_battleManager:
		print("[resolve_action_result] CHECK: is_state_change")

	if event.get("is_state_change", false):
		if Globals.debug_battleManager:
			print("[resolve_action_result] ROUTE: resolve_state_changes")

		return resolve_state_changes(event)

	# --- EVENT GROUP ROUTING ---
	var event_group = event.get("event_group", "")

	if Globals.debug_battleManager:
		print("[resolve_action_result] CHECK: event_group:", event_group)

	if event_group == "weapon":
		if Globals.debug_battleManager:
			print("[resolve_action_result] ROUTE: resolve_weapon_damage")

		return resolve_weapon_damage(event)

	if event_group == "explosive":
		if Globals.debug_battleManager:
			print("[resolve_action_result] ROUTE: resolve_explosive")

		return resolve_explosive(event)

	if event_group == "repair":
		if Globals.debug_battleManager:
			print("[resolve_action_result] ROUTE: resolve_repair")

		return resolve_repair(event)

	if event_group == "shield_repair":
		if Globals.debug_battleManager:
			print("[resolve_action_result] ROUTE: resolve_shield_repair")

		return resolve_shield_repair(event)

	if event_group == "recharge":
		if Globals.debug_battleManager:
			print("[resolve_action_result] ROUTE: resolve_recharge")

		return resolve_recharge(event)

	if event_group == "signal":
		if Globals.debug_battleManager:
			print("[resolve_action_result] ROUTE: resolve_signal")

		return resolve_signal(event)

	if event_group == "pulse":
		if Globals.debug_battleManager:
			print("[resolve_action_result] ROUTE: resolve_pulse")

		return resolve_pulse(event)

	if event_group == "drone":
		if Globals.debug_battleManager:
			print("[resolve_action_result] ROUTE: resolve_drone")

		return resolve_drone(event)

	if event_group == "stat_effect":
		if Globals.debug_battleManager:
			print("[resolve_action_result] ROUTE: apply_stat_effects")

		return apply_stat_effects(event.get("data", {}).get("effect_packet", {}))

	# --- UNKNOWN EVENT GROUP ---
	if Globals.debug_battleManager:
		print("[resolve_action_result] UNDEFINED event_group:", event_group)

	result["blocked_reason"] = "UNDEFINED — NEEDS SPEC: event_group"
	result["route"] = "undefined"

	return result
	




func disrupt_next_opposing_pipeline_event(event: Dictionary) -> Dictionary:
	# Summary: Let completed evade visibly disrupt the opposing pipeline without cancelling or resolving TODOs.
	var event_side := str(event.get("event_side", "")).strip_edges().to_lower()
	var opposing_side := "enemy" if event_side == "player" else "player"
	if event_side != "player" and event_side != "enemy":
		opposing_side = ""

	var data_payload: Dictionary = {}
	if typeof(event.get("data", {})) == TYPE_DICTIONARY:
		data_payload = event.get("data", {})
	var delay_seconds := float(data_payload.get("evade_pipeline_disrupt_seconds", data_payload.get("evade_duration", 1.5)))
	delay_seconds = clamp(delay_seconds, 0.5, 5.0)

	var result := {
		"disrupted": false,
		"blocked_reason": "",
		"labels": ["evade_pipeline_disrupt"]
	}
	if opposing_side == "":
		result["blocked_reason"] = "missing_opposing_side"
		return result
	if event_manager == null or not event_manager.has_method("disrupt_next_event_for_side"):
		result["blocked_reason"] = "missing_event_manager_disrupt_route"
		return result

	var disrupt_result: Dictionary = event_manager.disrupt_next_event_for_side(
		opposing_side,
		"evade_complete:" + str(event.get("event_id", "")),
		delay_seconds,
		str(event.get("event_id", ""))
	)
	for key in disrupt_result.keys():
		result[key] = disrupt_result[key]
	return result


func start_battle(player_state, enemy, opening_state: String) -> Dictionary:
	# Summary: Starts a Battle V2 resolver session using temporary player/enemy battle-state adapters.
	#
	# Ownership:
	# - BattleManager stores active battle references.
	# - BattleManager applies opening lock state.
	# - BattleManager does not build adapters.
	# - BattleManager does not change scenes.

	var result := {
		"type": "start_battle",
		"battle_started": false,
		"opening_state": opening_state,
		"labels": [],
		"blocked_reason": "none"
	}

	if Globals.print_priority_5:
		print(
			"[BattleManager.start_battle] START",
			" | player_state=", player_state,
			" | enemy=", enemy,
			" | opening_state=", opening_state
		)

	if player_state == null:
		result["blocked_reason"] = "missing_player_state"

		if Globals.print_priority_5:
			print("[BattleManager.start_battle] BLOCKED | missing_player_state")

		return result

	if enemy == null:
		result["blocked_reason"] = "missing_enemy"

		if Globals.print_priority_5:
			print("[BattleManager.start_battle] BLOCKED | missing_enemy")

		return result

	active_player_state = player_state
	active_enemy = enemy
	battle_active = true

	if opening_state == "player_advantage":
		if player_state.has_method("set_player_lock_good"):
			player_state.set_player_lock_good()

		if enemy.has_method("set_enemy_lock_lost"):
			enemy.set_enemy_lock_lost()

		if enemy.has_method("set_enemy_lock_pending"):
			enemy.set_enemy_lock_pending(true)

		result["labels"].append("battle_start_player_advantage")

	elif opening_state == "enemy_advantage":
		if enemy.has_method("set_enemy_lock_good"):
			enemy.set_enemy_lock_good()

		if player_state.has_method("set_player_lock_lost"):
			player_state.set_player_lock_lost()

		if player_state.has_method("set_player_lock_pending"):
			player_state.set_player_lock_pending(true)

		result["labels"].append("battle_start_enemy_advantage")

	elif opening_state == "no_lock":
		if player_state.has_method("set_player_lock_lost"):
			player_state.set_player_lock_lost()

		if enemy.has_method("set_enemy_lock_lost"):
			enemy.set_enemy_lock_lost()

		if player_state.has_method("set_player_lock_pending"):
			player_state.set_player_lock_pending(true)

		if enemy.has_method("set_enemy_lock_pending"):
			enemy.set_enemy_lock_pending(true)

		result["labels"].append("battle_start_no_lock")

	elif opening_state == "rush":
		if player_state.has_method("set_player_lock_good"):
			player_state.set_player_lock_good()

		if enemy.has_method("set_enemy_lock_good"):
			enemy.set_enemy_lock_good()

		result["labels"].append("battle_start_rush")

	else:
		battle_active = false
		active_player_state = null
		active_enemy = null

		result["blocked_reason"] = "undefined_opening_state"

		if Globals.print_priority_5:
			print("[BattleManager.start_battle] BLOCKED | undefined opening_state=", opening_state)

		return result

	if action_manager != null and action_manager.has_method("refresh_action_ui"):
		action_manager.refresh_action_ui()

	result["battle_started"] = true

	if Globals.print_priority_5:
		print("[BattleManager.start_battle] END | result=", result)

	return result
	
	
	
	
func end_battle_cleanup(outcome: String) -> Dictionary:
	# PURPOSE: Safely terminate active battle state, trigger semantic cleanup labels, request proper handler cleanup, and release active battle references without leaking battle-only state.

	if Globals.debug_battleManager:
		print("[end_battle_cleanup] START | outcome:", outcome)

	var result := {
		"type": "battle_cleanup",
		"outcome": outcome,
		"cleanup_complete": false,
		"labels": [],
		"blocked_reason": "none"
	}

	# --- ACTIVE BATTLE CHECK ---
	# Cleanup should only run while battle is active.
	if Globals.debug_battleManager:
		print("[end_battle_cleanup] CHECK: battle_active")

	if not battle_active:
		if Globals.debug_battleManager:
			print("[end_battle_cleanup] RESULT: no active battle")

		result["blocked_reason"] = "battle_not_active"
		return result

	# --- CLEANUP LABEL PHASE ---
	# These are semantic transition labels only.
	# They do not own gameplay cleanup behavior.
	if Globals.debug_battleManager:
		print("[end_battle_cleanup] APPLY: semantic cleanup label")

	if outcome == "victory":
		result["labels"].append("battle_cleanup_victory")

	elif outcome == "defeat":
		result["labels"].append("battle_cleanup_defeat")

	elif outcome == "escape":
		result["labels"].append("battle_cleanup_escape")

	# --- BATTLE ACTIVE FLAG ---
	# Battle officially ends here.
	if Globals.debug_battleManager:
		print("[end_battle_cleanup] SET: battle_active = false")

	battle_active = false

	# --- SAFE CONSUMABLE CLEANUP ---
	# Loaded/prepped consumables that never executed are preserved.
	# BattleManager requests cleanup only.
	if Globals.debug_battleManager:
		print("[end_battle_cleanup] CHECK: clear safe loaded consumables")

	if active_player_state != null:
		if active_player_state.has_method("clear_loaded_consumable_without_spend"):
			active_player_state.clear_loaded_consumable_without_spend()

	# --- RESERVED ENERGY CLEANUP ---
	# EnergyHandler owns reserved energy tracking.
	if Globals.debug_battleManager:
		print("[end_battle_cleanup] CHECK: energy_handler.clear_reserved_energy")

	if energy_handler != null:
		if energy_handler.has_method("clear_reserved_energy"):
			energy_handler.clear_reserved_energy()

	if enemy_energy_handler != null:
		if enemy_energy_handler.has_method("clear_reserved_energy"):
			enemy_energy_handler.clear_reserved_energy()
			sync_active_enemy_energy_from_handler()

	# --- RESERVED AMMO CLEANUP ---
	# AmmoHandler owns battle-only ammo reservations.
	if Globals.debug_battleManager:
		print("[end_battle_cleanup] CHECK: ammo_handler.clear_reserved_ammo")

	if ammo_handler != null:
		if ammo_handler.has_method("clear_reserved_ammo"):
			ammo_handler.clear_reserved_ammo()

	# --- ACTIVE TODO CLEANUP ---
	# EventManager owns active TODO storage. BattleManager only requests cleanup after outcome.
	if Globals.debug_battleManager:
		print("[end_battle_cleanup] CHECK: event_manager.clear_battle_events")

	if event_manager != null:
		if event_manager.has_method("clear_battle_events"):
			result["event_cleanup"] = event_manager.clear_battle_events()

	# --- ACTIVE EFFECT CLEANUP ---
	# StatEffectHandler owns active effect storage.
	if Globals.debug_battleManager:
		print("[end_battle_cleanup] CHECK: stat_effect_handler.clear_battle_effects")

	if stat_effect_handler != null:
		if stat_effect_handler.has_method("clear_battle_effects"):
			stat_effect_handler.clear_battle_effects()

	# --- LOCK STATE RESET ---
	# Battle-only lock state should not leak outside battle.
	if Globals.debug_battleManager:
		print("[end_battle_cleanup] CHECK: reset battle lock states")

	if active_player_state != null:
		if active_player_state.has_method("set_player_lock_lost"):
			active_player_state.set_player_lock_lost()

	if active_enemy != null:
		if active_enemy.has_method("set_enemy_lock_lost"):
			active_enemy.set_enemy_lock_lost()

	# --- ACTION UI REFRESH ---
	# BattleManager requests refresh only.
	if Globals.debug_battleManager:
		print("[end_battle_cleanup] CHECK: action_manager.refresh_action_ui")

	if action_manager != null:
		if action_manager.has_method("refresh_action_ui"):
			action_manager.refresh_action_ui()

	# --- ACTIVE REFERENCE CLEAR ---
	# Clear references last after all cleanup completes.
	if Globals.debug_battleManager:
		print("[end_battle_cleanup] CLEAR: active references")

	active_player_state = null
	active_enemy = null
	active_drones.clear()

	result["cleanup_complete"] = true

	if Globals.debug_battleManager:
		print("[end_battle_cleanup] END RESULT:", result)

	return result


func deploy_active_drone(event: Dictionary, data: Dictionary) -> Dictionary:
	# Summary: Create one runtime drone with its own timer, HP, shield absorb, and optional autonomous attack.
	drone_runtime_counter += 1
	var runtime_id := str(data.get("runtime_id", "")).strip_edges()
	if runtime_id == "":
		runtime_id = str(data.get("drone_type", "drone")) + "_runtime_" + str(drone_runtime_counter)

	var owner_unit = event.get("owner_unit", event.get("source_unit", null))
	var owner_side := get_battle_unit_side(owner_unit, str(event.get("event_side", "")))
	var target_unit = event.get("target_unit", null)
	if target_unit == null or target_unit == owner_unit:
		target_unit = get_default_drone_attack_target(owner_side)

	var duration = max(float(data.get("duration", 10.0)), 0.1)
	var hull_max = max(float(data.get("drone_hull_max", data.get("hull_max", 50.0))), 1.0)
	var hull_current = clamp(float(data.get("drone_hull_current", hull_max)), 0.0, hull_max)
	var fire_interval = max(float(data.get("drone_fire_interval", 0.2)), 0.01)
	var max_shots := get_drone_fire_count(data, duration, fire_interval)

	var runtime_packet := {
		"runtime_id": runtime_id,
		"source_event_id": event.get("event_id", null),
		"source_item_id": event.get("item_id", data.get("consumable_id", "")),
		"battle_id": event.get("battle_id", ""),
		"owner_side": owner_side,
		"owner_unit": owner_unit,
		"target_unit": target_unit,
		"drone_type": str(data.get("drone_type", "auto_attack")).strip_edges(),
		"drone_group": str(data.get("drone_group", "")).strip_edges(),
		"duration": duration,
		"time_remaining": duration,
		"hull_current": hull_current,
		"hull_max": hull_max,
		"shield_active": bool(data.get("drone_shield_active", data.get("shield_active", true))),
		"auto_attack": bool(data.get("drone_auto_attack", true)),
		"fire_interval": fire_interval,
		"fire_timer": fire_interval,
		"drone_fire_count": max_shots,
		"max_shots": max_shots,
		"shots_fired": 0,
		"shots_remaining": max_shots,
		"damage_type": str(data.get("drone_damage_type", "hull")).strip_edges(),
		"damage_value": max(float(data.get("drone_damage_value", 1.0)), 0.0),
		"active": true,
		"labels": data.get("labels", [])
	}

	active_drones.append(runtime_packet)

	return {
		"status": "deployed",
		"runtime_id": runtime_id,
		"active_count": active_drones.size(),
		"runtime": runtime_packet.duplicate(true),
		"labels": [
			"active_drone_runtime_started",
			"active_drone_no_stack_limit",
			"active_drone_consumable_spent_on_deploy"
		]
	}


func get_drone_fire_count(data: Dictionary, duration: float, fire_interval: float) -> int:
	# Summary: Prefer explicit drone shot count metadata; otherwise match the duration/rate behavior.
	var explicit_count := int(data.get("drone_fire_count", data.get("drone_max_shots", data.get("drone_shot_count", 0))))
	if explicit_count > 0:
		return explicit_count
	return max(int(ceil(max(duration, 0.1) / max(fire_interval, 0.01))), 1)


func get_default_drone_attack_target(owner_side: String):
	# Summary: Resolve the normal opposing target for an autonomous drone.
	if owner_side == "player":
		return active_enemy
	if owner_side == "enemy":
		return active_player_state
	return active_enemy


func update_active_drones(delta: float) -> Dictionary:
	# Summary: Tick active runtime drones, fire autonomous attacks, and expire drones by time or HP.
	var summary := {
		"status": "updated",
		"active_count_before": active_drones.size(),
		"active_count_after": active_drones.size(),
		"attacks": [],
		"expired": [],
		"destroyed": [],
		"battle_outcome": "battle_continues",
		"battle_ended": false,
		"cleanup_required": false,
		"labels": ["active_drone_runtime_update"]
	}

	if not battle_active:
		summary["status"] = "inactive"
		summary["active_count_after"] = 0
		return summary

	if active_drones.is_empty():
		summary["status"] = "idle"
		return summary

	var kept_drones: Array = []
	for drone in active_drones:
		if typeof(drone) != TYPE_DICTIONARY:
			continue

		var runtime: Dictionary = drone
		if not bool(runtime.get("active", true)):
			continue

		var hull_current := float(runtime.get("hull_current", 0.0))
		if hull_current <= 0.0:
			runtime["active"] = false
			summary["destroyed"].append(get_drone_runtime_summary(runtime, "destroyed"))
			continue

		var time_remaining := float(runtime.get("time_remaining", 0.0)) - delta
		runtime["time_remaining"] = time_remaining
		if time_remaining <= 0.0:
			runtime["active"] = false
			summary["expired"].append(get_drone_runtime_summary(runtime, "expired"))
			continue

		if bool(runtime.get("auto_attack", false)):
			var fire_interval = max(float(runtime.get("fire_interval", 0.2)), 0.01)
			var fire_timer := float(runtime.get("fire_timer", fire_interval)) - delta
			var max_shots := int(runtime.get("max_shots", runtime.get("drone_fire_count", 0)))
			var shots_fired = max(int(runtime.get("shots_fired", 0)), 0)
			var shots_remaining = max(int(runtime.get("shots_remaining", max_shots - shots_fired)), 0)
			if max_shots > 0 and shots_remaining <= 0:
				runtime["active"] = false
				summary["expired"].append(get_drone_runtime_summary(runtime, "expired"))
				continue

			var safety_counter := 0
			while fire_timer <= 0.0 and safety_counter < 20 and (max_shots <= 0 or shots_remaining > 0):
				var attack_result := resolve_active_drone_attack(runtime)
				shots_fired += 1
				if max_shots > 0:
					shots_remaining = max(max_shots - shots_fired, 0)
				runtime["shots_fired"] = shots_fired
				runtime["shots_remaining"] = shots_remaining
				attack_result["shot_index"] = shots_fired
				attack_result["shot_total"] = max_shots
				attack_result["shots_remaining"] = shots_remaining
				summary["attacks"].append(attack_result)
				fire_timer += fire_interval
				safety_counter += 1

				var battle_outcome := check_victory_conditions()
				if battle_outcome == "player_victory" or battle_outcome == "player_defeat":
					summary["battle_outcome"] = battle_outcome
					summary["battle_ended"] = true
					summary["cleanup_required"] = true
					break

			runtime["fire_timer"] = fire_timer
			runtime["shots_fired"] = shots_fired
			runtime["shots_remaining"] = shots_remaining
			if max_shots > 0 and shots_remaining <= 0 and not bool(summary.get("battle_ended", false)):
				runtime["active"] = false
				summary["expired"].append(get_drone_runtime_summary(runtime, "expired"))
				continue

		if bool(summary.get("battle_ended", false)):
			kept_drones.append(runtime)
			break

		if bool(runtime.get("active", true)) and float(runtime.get("hull_current", 0.0)) > 0.0:
			kept_drones.append(runtime)

	active_drones = kept_drones
	summary["active_count_after"] = active_drones.size()
	return summary


func resolve_active_drone_attack(runtime: Dictionary) -> Dictionary:
	# Summary: Apply one autonomous drone damage tick through the normal BattleManager damage route.
	var target_unit = runtime.get("target_unit", null)
	if target_unit == null:
		target_unit = get_default_drone_attack_target(str(runtime.get("owner_side", "")))
		runtime["target_unit"] = target_unit

	var result := {
		"type": "active_drone_attack",
		"runtime_id": runtime.get("runtime_id", ""),
		"owner_side": str(runtime.get("owner_side", "")),
		"target_unit": target_unit,
		"target_side": "",
		"damage_value": max(float(runtime.get("damage_value", 1.0)), 0.0),
		"shot_index": int(runtime.get("shots_fired", 0)) + 1,
		"shot_total": int(runtime.get("max_shots", runtime.get("drone_fire_count", 0))),
		"shots_remaining": max(int(runtime.get("shots_remaining", 0)) - 1, 0),
		"damage_applied": false,
		"blocked_reason": "none",
		"damage_result": {},
		"labels": ["active_drone_attack_tick"]
	}

	if target_unit == null:
		result["blocked_reason"] = "missing_target_unit"
		return result

	var target_side := get_battle_unit_side(target_unit, "")
	result["target_side"] = target_side
	if get_unit_hull_current(target_unit, target_side) <= 0.001:
		result["blocked_reason"] = "target_already_terminal"
		return result

	var damage_packet := {
		"damage_type": str(runtime.get("damage_type", "hull")),
		"damage_value": max(float(runtime.get("damage_value", 1.0)), 0.0),
		"drone_runtime_id": runtime.get("runtime_id", ""),
		"source_item_id": runtime.get("source_item_id", ""),
		"bypass_drone_shield": false,
		"labels": ["active_drone_attack_damage"]
	}

	var damage_result := apply_damage(runtime, target_unit, damage_packet)
	result["damage_result"] = damage_result
	result["damage_applied"] = bool(damage_result.get("damage_applied", false))
	return result


func get_drone_runtime_summary(runtime: Dictionary, status: String) -> Dictionary:
	# Summary: Return a small serializable view of one runtime drone for logs and update summaries.
	return {
		"status": status,
		"runtime_id": runtime.get("runtime_id", ""),
		"source_item_id": runtime.get("source_item_id", ""),
		"owner_side": runtime.get("owner_side", ""),
		"target_side": get_battle_unit_side(runtime.get("target_unit", null), ""),
		"drone_type": runtime.get("drone_type", ""),
		"auto_attack": bool(runtime.get("auto_attack", false)),
		"duration": float(runtime.get("duration", 0.0)),
		"hull_current": float(runtime.get("hull_current", 0.0)),
		"hull_max": float(runtime.get("hull_max", 0.0)),
		"time_remaining": float(runtime.get("time_remaining", 0.0)),
		"fire_timer": float(runtime.get("fire_timer", 0.0)),
		"fire_interval": float(runtime.get("fire_interval", 0.0)),
		"drone_fire_count": int(runtime.get("drone_fire_count", runtime.get("max_shots", 0))),
		"max_shots": int(runtime.get("max_shots", runtime.get("drone_fire_count", 0))),
		"shots_fired": int(runtime.get("shots_fired", 0)),
		"shots_remaining": int(runtime.get("shots_remaining", runtime.get("max_shots", 0))),
		"damage_type": runtime.get("damage_type", ""),
		"damage_value": float(runtime.get("damage_value", 0.0)),
		"labels": ["active_drone_runtime_" + status]
	}


func get_active_drone_runtime_snapshot() -> Dictionary:
	# Summary: Expose read-only active drone state for Battle V3 UI without moving runtime ownership out of BattleManager.
	var drones: Array = []
	for drone in active_drones:
		if typeof(drone) != TYPE_DICTIONARY:
			continue
		var runtime: Dictionary = drone
		if not bool(runtime.get("active", true)):
			continue
		drones.append(get_drone_runtime_summary(runtime, "active"))

	return {
		"active_count": drones.size(),
		"drones": drones,
		"labels": ["active_drone_runtime_snapshot"]
	}


func absorb_damage_with_active_drones(target_unit, damage_packet: Dictionary, incoming_damage: float) -> Dictionary:
	# Summary: Let shield-capable active drones absorb incoming damage before normal shield/hull routing.
	var safe_incoming = max(float(incoming_damage), 0.0)
	var result := {
		"absorbed_damage": 0.0,
		"remaining_damage": safe_incoming,
		"destroyed": [],
		"labels": []
	}

	if safe_incoming <= 0.0:
		return result
	if bool(damage_packet.get("bypass_drone_shield", false)):
		return result
	if active_drones.is_empty():
		return result

	var remaining = safe_incoming
	var kept_drones: Array = []

	for drone in active_drones:
		if typeof(drone) != TYPE_DICTIONARY:
			continue

		var runtime: Dictionary = drone
		if not bool(runtime.get("active", true)):
			continue

		if runtime.get("owner_unit", null) != target_unit:
			kept_drones.append(runtime)
			continue

		if not bool(runtime.get("shield_active", false)):
			kept_drones.append(runtime)
			continue

		var hull_current = max(float(runtime.get("hull_current", 0.0)), 0.0)
		if hull_current <= 0.0:
			runtime["active"] = false
			result["destroyed"].append(get_drone_runtime_summary(runtime, "destroyed"))
			continue

		if remaining > 0.0:
			var absorbed = min(hull_current, remaining)
			hull_current -= absorbed
			remaining -= absorbed
			runtime["hull_current"] = hull_current
			result["absorbed_damage"] = float(result["absorbed_damage"]) + absorbed
			result["remaining_damage"] = remaining
			if not result["labels"].has("active_drone_shield_absorb"):
				result["labels"].append("active_drone_shield_absorb")

		if hull_current <= 0.001:
			runtime["active"] = false
			result["destroyed"].append(get_drone_runtime_summary(runtime, "destroyed"))
			if not result["labels"].has("active_drone_destroyed"):
				result["labels"].append("active_drone_destroyed")
			continue

		kept_drones.append(runtime)

	active_drones = kept_drones
	result["remaining_damage"] = remaining
	return result

func apply_damage(source_unit, target_unit, damage_packet: Dictionary) -> Dictionary:
	# PURPOSE: Route already-approved damage by damage type, apply pulse bypass when pulse window is vulnerable, then send shield-path damage through resolve_shield_damage().

	if Globals.debug_battleManager:
		print("[apply_damage] START | source:", source_unit, " target:", target_unit, " damage_packet:", damage_packet)

	var result := {
		"type": "damage",
		"damage_type": damage_packet.get("damage_type", ""),
		"damage_applied": false,
		"shield_damage": 0.0,
		"hull_damage": 0.0,
		"drone_shield_damage": 0.0,
		"overflow_damage": 0.0,
		"shield_bypassed": false,
		"drone_shield_result": {},
		"blocked_reason": "none",
		"labels": []
	}

	# --- DAMAGE DATA READ ---
	var damage_type = damage_packet.get("damage_type", "")
	var damage_value = damage_packet.get("damage_value", 0.0)

	if Globals.debug_battleManager:
		print("[apply_damage] CHECK: damage_type:", damage_type, " damage_value:", damage_value)

	# --- TARGET CHECK ---
	if Globals.debug_battleManager:
		print("[apply_damage] CHECK: target_unit exists")

	if target_unit == null:
		if Globals.debug_battleManager:
			print("[apply_damage] RESULT: missing target_unit")

		result["blocked_reason"] = "missing_target_unit"
		return result

	var drone_absorb_result := absorb_damage_with_active_drones(target_unit, damage_packet, float(damage_value))
	var drone_absorbed := float(drone_absorb_result.get("absorbed_damage", 0.0))
	if drone_absorbed > 0.0:
		result["damage_applied"] = true
		result["drone_shield_damage"] = drone_absorbed
		result["drone_shield_result"] = drone_absorb_result
		result["labels"].append("active_drone_shield_absorb")
		for absorb_label in drone_absorb_result.get("labels", []):
			if not result["labels"].has(absorb_label):
				result["labels"].append(absorb_label)
		damage_value = float(drone_absorb_result.get("remaining_damage", 0.0))
		if damage_value <= 0.0:
			return result

	# --- PULSE WINDOW CHECK ---
	# BattleManager reads current pulse window state.
	# It does not tick pulse or own pulse timing.
	# If current pulse window is V, approved damage bypasses shield.
	var pulse_window_state = damage_packet.get("pulse_window_state", "N")

	if Globals.debug_battleManager:
		print("[apply_damage] CHECK: pulse_window_state:", pulse_window_state)

	if pulse_window_state == "V":
		if Globals.debug_battleManager:
			print("[apply_damage] RESULT: pulse bypass shield -> hull damage:", damage_value)

		target_unit.apply_hull_damage(damage_value)

		result["damage_applied"] = true
		result["hull_damage"] = damage_value
		result["shield_bypassed"] = true
		result["labels"].append("pulse_bypass_shield")
		result["labels"].append("hull_hit_animation")

		return result

	# --- DIRECT HULL DAMAGE ROUTE ---
	# Runtime drones use this tiny damage route for exact per-tick hull chips.
	if damage_type == "hull" or damage_type == "direct" or damage_type == "drone":
		if Globals.debug_battleManager:
			print("[apply_damage] ROUTE: direct hull damage")

		target_unit.apply_hull_damage(damage_value)
		result["damage_applied"] = true
		result["hull_damage"] = damage_value
		result["shield_bypassed"] = true
		result["labels"].append("direct_hull_damage")
		result["labels"].append("hull_hit_animation")

		return result

	# --- ENERGY DAMAGE ROUTE ---
	# Energy damage uses the standard shield path:
	# shield power split -> shield HP -> overflow -> hull
	if damage_type == "energy":
		if Globals.debug_battleManager:
			print("[apply_damage] ROUTE: energy -> resolve_shield_damage")

		var shield_result = resolve_shield_damage(target_unit, damage_value, "energy")

		result["damage_applied"] = true
		result["shield_damage"] = shield_result.get("shield_damage", 0.0)
		result["hull_damage"] = shield_result.get("hull_damage", 0.0)
		result["overflow_damage"] = shield_result.get("overflow_damage", 0.0)
		copy_shield_break_result(result, shield_result)

		if result["shield_damage"] > 0.0:
			result["labels"].append("shield_hit_animation")

		if result["hull_damage"] > 0.0:
			result["labels"].append("hull_hit_animation")

		return result

	# --- KINETIC DAMAGE ROUTE ---
	# Kinetic damage splits:
	# 25% shield path
	# 75% direct hull
	if damage_type == "kinetic":
		if Globals.debug_battleManager:
			print("[apply_damage] ROUTE: kinetic split")

		var shield_portion = damage_value * 0.25
		var hull_portion = damage_value * 0.75

		if Globals.debug_battleManager:
			print("[apply_damage] CALC: shield_portion:", shield_portion, " hull_portion:", hull_portion)

		var shield_result = resolve_shield_damage(target_unit, shield_portion, "kinetic")

		target_unit.apply_hull_damage(hull_portion)

		result["damage_applied"] = true
		result["shield_damage"] = shield_result.get("shield_damage", 0.0)
		result["overflow_damage"] = shield_result.get("overflow_damage", 0.0)
		result["hull_damage"] = hull_portion + shield_result.get("hull_damage", 0.0)
		copy_shield_break_result(result, shield_result)

		if result["shield_damage"] > 0.0:
			result["labels"].append("shield_hit_animation")

		if result["hull_damage"] > 0.0:
			result["labels"].append("hull_hit_animation")

		return result

	# --- EXPLOSIVE DAMAGE ROUTE ---
	# Explosive damage splits:
	# pass percent goes directly to hull
	# remaining damage goes through shield math
	if damage_type == "explosive":
		if Globals.debug_battleManager:
			print("[apply_damage] ROUTE: explosive split")

		var pass_percent = damage_packet.get("explosive_pass_percent", 0.0)
		var pass_damage = damage_value * pass_percent
		var shield_portion = damage_value - pass_damage

		if Globals.debug_battleManager:
			print("[apply_damage] CALC: pass_percent:", pass_percent, " pass_damage:", pass_damage, " shield_portion:", shield_portion)

		target_unit.apply_hull_damage(pass_damage)

		var shield_result = resolve_shield_damage(target_unit, shield_portion, "explosive")

		result["damage_applied"] = true
		result["shield_damage"] = shield_result.get("shield_damage", 0.0)
		result["overflow_damage"] = shield_result.get("overflow_damage", 0.0)
		result["hull_damage"] = pass_damage + shield_result.get("hull_damage", 0.0)
		copy_shield_break_result(result, shield_result)

		result["labels"].append("explosive_pass_damage")
		result["labels"].append("explosive_shield_damage_math")

		if result["shield_damage"] > 0.0:
			result["labels"].append("shield_hit_animation")

		if result["hull_damage"] > 0.0:
			result["labels"].append("hull_hit_animation")

		return result

	# --- UNDEFINED DAMAGE TYPE ---
	if Globals.debug_battleManager:
		print("[apply_damage] UNDEFINED damage_type:", damage_type)

	result["blocked_reason"] = "UNDEFINED — NEEDS SPEC: damage_type"

	return result	
	
	
	
	
func copy_shield_break_result(target_result: Dictionary, shield_result: Dictionary) -> void:
	# Summary: Lift shield-break facts onto the parent damage packet for UI, logs, and save synchronization.
	if not bool(shield_result.get("shield_broken", false)):
		return
	target_result["shield_broken"] = true
	target_result["shield_consumed"] = bool(shield_result.get("shield_consumed", false))
	target_result["shield_break_result"] = shield_result.get("shield_break_result", {}).duplicate(true)
	var labels = target_result.get("labels", [])
	if typeof(labels) != TYPE_ARRAY:
		labels = []
	if not labels.has("shield_break_detected"):
		labels.append("shield_break_detected")
	if bool(target_result["shield_consumed"]) and not labels.has("shield_consumed_at_zero_hp"):
		labels.append("shield_consumed_at_zero_hp")
	target_result["labels"] = labels


func resolve_shield_damage(target_unit, incoming_damage: float, damage_type: String) -> Dictionary:
	# PURPOSE: Resolve shield-path damage with shield power as the absorb percent.
	# Example: 25% shield power absorbs at most 25% of incoming shield-path damage.
	# The unprotected slice and any shield HP overflow both carry to hull.
	if Globals.debug_battleManager:
		print("[resolve_shield_damage] START | target:", target_unit, " incoming_damage:", incoming_damage, " damage_type:", damage_type)

	var safe_incoming_damage = max(float(incoming_damage), 0.0)
	var result := {
		"type": "shield_damage",
		"damage_type": damage_type,
		"shield_damage": 0.0,
		"hull_damage": 0.0,
		"overflow_damage": 0.0,
		"shield_passthrough_damage": 0.0,
		"shield_lane_damage": 0.0,
		"shield_power_level": 0,
		"shield_power_percent": 0.0,
		"base_resist": 0.0,
		"effective_resist": 0.0,
		"shield_broken": false,
		"shield_consumed": false,
		"shield_break_result": {},
		"blocked_reason": "none",
		"labels": []
	}

	if target_unit == null:
		if Globals.debug_battleManager:
			print("[resolve_shield_damage] RESULT: missing target_unit")
		result["blocked_reason"] = "missing_target_unit"
		return result

	if target_unit.shield_switching:
		if Globals.debug_battleManager:
			print("[resolve_shield_damage] RESULT: shield offline during swap -> hull damage:", safe_incoming_damage)
		target_unit.apply_hull_damage(safe_incoming_damage)
		result["hull_damage"] = safe_incoming_damage
		result["shield_passthrough_damage"] = safe_incoming_damage
		result["labels"].append("shield_offline_during_swap")
		result["labels"].append("hull_hit_animation")
		return result

	var selected_shield = target_unit.selected_shield
	if not is_active_shield_packet(selected_shield):
		if Globals.debug_battleManager:
			print("[resolve_shield_damage] RESULT: no active shield packet -> hull damage:", safe_incoming_damage, " selected_shield:", selected_shield)
		target_unit.apply_hull_damage(safe_incoming_damage)
		result["hull_damage"] = safe_incoming_damage
		result["shield_passthrough_damage"] = safe_incoming_damage
		result["labels"].append("shield_missing_or_unresolved")
		result["labels"].append("hull_hit_animation")
		return result

	var slider_value = clamp(int(target_unit.shield_power_level), 0, 4)
	var slider_percent = clamp(float(slider_value) * 0.25, 0.0, 1.0)
	result["shield_power_level"] = slider_value
	result["shield_power_percent"] = slider_percent
	result["labels"].append("shield_slider_scaling")
	result["labels"].append("shield_power_absorption_split")

	if Globals.debug_battleManager:
		print("[resolve_shield_damage] CALC: slider_value:", slider_value, " slider_percent:", slider_percent)

	var shield_energy_handler = get_shield_energy_handler_for_unit(target_unit)
	if shield_energy_handler == null or not shield_energy_handler.has_method("shield_has_energy"):
		if Globals.debug_battleManager:
			print("[resolve_shield_damage] RESULT: missing shield energy handler -> hull damage:", safe_incoming_damage)
		target_unit.apply_hull_damage(safe_incoming_damage)
		result["hull_damage"] = safe_incoming_damage
		result["shield_passthrough_damage"] = safe_incoming_damage
		result["blocked_reason"] = "missing_shield_energy_handler"
		result["labels"].append("shield_energy_handler_missing")
		result["labels"].append("shield_offline_no_energy_support")
		result["labels"].append("hull_hit_animation")
		return result

	var shield_has_energy = shield_energy_handler.shield_has_energy()
	result["labels"].append("shield_energy_available_check")

	if Globals.debug_battleManager:
		print("[resolve_shield_damage] RESULT: shield_has_energy:", shield_has_energy)

	if not shield_has_energy or slider_percent <= 0.0:
		if Globals.debug_battleManager:
			print("[resolve_shield_damage] RESULT: shield cannot absorb -> hull damage:", safe_incoming_damage)
		target_unit.apply_hull_damage(safe_incoming_damage)
		result["hull_damage"] = safe_incoming_damage
		result["shield_passthrough_damage"] = safe_incoming_damage
		if not shield_has_energy:
			result["labels"].append("shield_energy_failure_state")
			result["labels"].append("shield_no_energy_all_damage_to_hull")
		if slider_percent <= 0.0:
			result["labels"].append("shield_slider_zero_state")
			result["labels"].append("shield_power_zero_all_damage_to_hull")
		result["labels"].append("hull_hit_animation")
		return result

	result["base_resist"] = get_shield_number_value(
		selected_shield,
		"base_shield_resist",
		get_shield_number_value(selected_shield, "base_damage_resist", 0.0)
	)

	var shield_lane_damage = safe_incoming_damage * slider_percent
	var shield_passthrough_damage = max(safe_incoming_damage - shield_lane_damage, 0.0)
	result["shield_lane_damage"] = shield_lane_damage
	result["shield_passthrough_damage"] = shield_passthrough_damage
	result["labels"].append("shield_damage_resolution_order")
	result["labels"].append("shield_power_split_before_shield_hp")
	result["labels"].append("shield_resist_reserved_for_future")

	if Globals.debug_battleManager:
		print("[resolve_shield_damage] CALC: shield_lane_damage:", shield_lane_damage, " shield_passthrough_damage:", shield_passthrough_damage)

	var current_shield_hp = target_unit.shield_hp_current
	var shield_item_id := get_shield_item_id(selected_shield)
	var shield_damage = min(shield_lane_damage, current_shield_hp)
	var overflow_damage = max(0.0, shield_lane_damage - current_shield_hp)
	var hull_damage = shield_passthrough_damage + overflow_damage
	result["labels"].append("shield_hp_absorbs_power_limited_damage")

	if Globals.debug_battleManager:
		print("[resolve_shield_damage] CALC: current_shield_hp:", current_shield_hp, " shield_damage:", shield_damage, " overflow_damage:", overflow_damage, " hull_damage:", hull_damage)

	target_unit.apply_shield_damage(shield_damage)
	result["shield_damage"] = shield_damage

	var shield_hp_after := get_unit_shield_hp_current(target_unit)
	if current_shield_hp > 0.0 and shield_hp_after <= 0.0 and shield_damage > 0.0:
		var break_result := finalize_broken_shield(
			target_unit,
			shield_item_id,
			selected_shield,
			current_shield_hp,
			shield_hp_after
		)
		result["shield_break_result"] = break_result
		result["shield_broken"] = bool(break_result.get("shield_broken", false))
		result["shield_consumed"] = bool(break_result.get("shield_consumed", false))
		if bool(result["shield_broken"]):
			result["labels"].append("shield_break_detected")
		if bool(result["shield_consumed"]):
			result["labels"].append("shield_consumed_at_zero_hp")

	if hull_damage > 0.0:
		if Globals.debug_battleManager:
			print("[resolve_shield_damage] RESULT: shield passthrough/overflow to hull:", hull_damage)
		target_unit.apply_hull_damage(hull_damage)
		result["hull_damage"] = hull_damage
		result["overflow_damage"] = overflow_damage
		result["labels"].append("shield_unabsorbed_damage_to_hull")
		if shield_passthrough_damage > 0.0:
			result["labels"].append("shield_power_passthrough_to_hull")
		if overflow_damage > 0.0:
			result["labels"].append("shield_hp_overflow_to_hull")
		result["labels"].append("hull_hit_animation")

	if shield_damage > 0.0:
		result["labels"].append("shield_hit_animation")

	if Globals.debug_battleManager:
		print("[resolve_shield_damage] END RESULT:", result)

	return result


func resolve_shield_damage_legacy(target_unit, incoming_damage: float, damage_type: String) -> Dictionary:
	# PURPOSE: Resolve shield-path damage by checking shield switching, shield presence, slider scaling, energy support, resist-before-shield math, shield HP absorption, and overflow to hull.

	if Globals.debug_battleManager:
		print("[resolve_shield_damage] START | target:", target_unit, " incoming_damage:", incoming_damage, " damage_type:", damage_type)

	var result := {
		"type": "shield_damage",
		"damage_type": damage_type,
		"shield_damage": 0.0,
		"hull_damage": 0.0,
		"overflow_damage": 0.0,
		"effective_resist": 0.0,
		"blocked_reason": "none",
		"labels": []
	}

	# --- TARGET CHECK ---
	if Globals.debug_battleManager:
		print("[resolve_shield_damage] CHECK: target_unit exists")

	if target_unit == null:
		if Globals.debug_battleManager:
			print("[resolve_shield_damage] RESULT: missing target_unit")

		result["blocked_reason"] = "missing_target_unit"
		return result

	# --- SHIELD SWITCHING CHECK ---
	# If shield is switching, protection is offline.
	# Incoming shield-path damage goes directly to hull.
	if Globals.debug_battleManager:
		print("[resolve_shield_damage] CHECK: target_unit.shield_switching")

	if target_unit.shield_switching:
		if Globals.debug_battleManager:
			print("[resolve_shield_damage] RESULT: shield offline during swap -> hull damage:", incoming_damage)

		target_unit.apply_hull_damage(incoming_damage)

		result["hull_damage"] = incoming_damage
		result["labels"].append("shield_offline_during_swap")
		result["labels"].append("hull_hit_animation")

		return result

	# --- SHIELD EQUIPPED CHECK ---
	# If no shield is equipped, incoming shield-path damage hits hull.
	if Globals.debug_battleManager:
		print("[resolve_shield_damage] CHECK: target_unit.selected_shield")

	var selected_shield = target_unit.selected_shield
	if not is_active_shield_packet(selected_shield):
		if Globals.debug_battleManager:
			print("[resolve_shield_damage] RESULT: no active shield packet -> hull damage:", incoming_damage, " selected_shield:", selected_shield)

		target_unit.apply_hull_damage(incoming_damage)

		result["hull_damage"] = incoming_damage
		result["labels"].append("shield_missing_or_unresolved")
		result["labels"].append("hull_hit_animation")

		return result

	# --- SHIELD SLIDER SCALING ---
	# slider_percent = shield_power_level * 0.25
	if Globals.debug_battleManager:
		print("[resolve_shield_damage] CHECK: shield_power_level")

	var slider_value = target_unit.shield_power_level
	var slider_percent = slider_value * 0.25

	result["labels"].append("shield_slider_scaling")

	if Globals.debug_battleManager:
		print("[resolve_shield_damage] CALC: slider_value:", slider_value, " slider_percent:", slider_percent)

	# --- ENERGY SUPPORT CHECK ---
	# EnergyHandler owns shield energy support.
	if Globals.debug_battleManager:
		print("[resolve_shield_damage] CHECK: energy_handler exists")

	if energy_handler == null:
		if Globals.debug_battleManager:
			print("[resolve_shield_damage] RESULT: missing energy_handler")

		result["blocked_reason"] = "UNDEFINED — missing energy_handler"
		return result

	if Globals.debug_battleManager:
		print("[resolve_shield_damage] CHECK: energy_handler.shield_has_energy()")

	var shield_has_energy = energy_handler.shield_has_energy()

	result["labels"].append("shield_energy_available_check")

	if Globals.debug_battleManager:
		print("[resolve_shield_damage] RESULT: shield_has_energy:", shield_has_energy)

	# --- EFFECTIVE RESIST CALCULATION ---
	# If slider is 0 or shield has no energy, resist is 0.
	# Otherwise:
	# effective_resist = base_shield_resist * slider_percent
	var effective_resist = 0.0

	if shield_has_energy and slider_percent > 0.0:
		if Globals.debug_battleManager:
			print("[resolve_shield_damage] CHECK: selected_shield base_shield_resist")

		var base_resist = get_shield_number_value(
			selected_shield,
			"base_shield_resist",
			get_shield_number_value(selected_shield, "base_damage_resist", 0.0)
		)
		effective_resist = base_resist * slider_percent

	result["effective_resist"] = effective_resist

	if Globals.debug_battleManager:
		print("[resolve_shield_damage] CALC: effective_resist:", effective_resist)

	# --- RESIST BEFORE SHIELD HP ---
	# Resist reduces incoming damage before shield HP absorbs anything.
	var reduced_damage = incoming_damage * (1.0 - effective_resist)

	result["labels"].append("shield_damage_resolution_order")
	result["labels"].append("resist_applied_before_shield_hp")

	if Globals.debug_battleManager:
		print("[resolve_shield_damage] CALC: reduced_damage:", reduced_damage)

	# --- SHIELD HP ABSORPTION ---
	# Shield HP absorbs reduced damage first.
	# Excess becomes overflow to hull.
	var current_shield_hp = target_unit.shield_hp_current
	var shield_damage = min(reduced_damage, current_shield_hp)
	var overflow_damage = max(0.0, reduced_damage - current_shield_hp)

	result["labels"].append("shield_hp_absorbs_after_resist")

	if Globals.debug_battleManager:
		print("[resolve_shield_damage] CALC: current_shield_hp:", current_shield_hp, " shield_damage:", shield_damage, " overflow_damage:", overflow_damage)

	target_unit.apply_shield_damage(shield_damage)

	result["shield_damage"] = shield_damage

	# --- OVERFLOW TO HULL ---
	if Globals.debug_battleManager:
		print("[resolve_shield_damage] CHECK: overflow_damage > 0")

	if overflow_damage > 0.0:
		if Globals.debug_battleManager:
			print("[resolve_shield_damage] RESULT: overflow to hull:", overflow_damage)

		target_unit.apply_hull_damage(overflow_damage)

		result["hull_damage"] = overflow_damage
		result["overflow_damage"] = overflow_damage
		result["labels"].append("shield_excess_to_hull")
		result["labels"].append("hull_hit_animation")

	# --- SHIELD HIT LABEL ---
	if shield_damage > 0.0:
		result["labels"].append("shield_hit_animation")

	if Globals.debug_battleManager:
		print("[resolve_shield_damage] END RESULT:", result)

	return result


func get_shield_energy_handler_for_unit(target_unit):
	# Summary: Use the target side's own EnergyHandler when checking shield energy support.
	var target_side := get_battle_unit_side(target_unit, "")
	if target_side == "enemy" and enemy_energy_handler != null:
		return enemy_energy_handler
	if target_side == "player" and energy_handler != null:
		return energy_handler
	if target_unit == active_enemy and enemy_energy_handler != null:
		return enemy_energy_handler
	return energy_handler


func is_active_shield_packet(shield_data) -> bool:
	# Summary: A selected shield must be real packet/object data before shield math can read resist values.
	if shield_data == null:
		return false
	if typeof(shield_data) == TYPE_DICTIONARY:
		return not shield_data.is_empty()
	if shield_data is Object:
		return true
	return false


func finalize_broken_shield(
	target_unit,
	shield_item_id: String,
	shield_packet,
	shield_hp_before: float,
	shield_hp_after: float
) -> Dictionary:
	# Summary: Consume one zero-HP shield and clear runtime state exactly once.
	var event_side := get_battle_unit_side(target_unit, "")
	var break_consumes_item := get_shield_bool_value(shield_packet, "break_consumes_item", true)
	var count_before := get_owned_item_count_for_unit(target_unit, shield_item_id)
	var consumed := false
	var inventory_desync := false
	var consume_status := "not_required"

	if break_consumes_item and shield_item_id != "":
		if event_side == "enemy" and target_unit != null and target_unit.has_method("consume_enemy_item"):
			consumed = bool(target_unit.consume_enemy_item(shield_item_id, 1))
		else:
			consumed = consume_inventory_item(shield_item_id, 1)
		consume_status = "success" if consumed else "failed"
		inventory_desync = not consumed

	var clear_result := {}
	if target_unit != null and target_unit.has_method("clear_broken_shield"):
		clear_result = target_unit.clear_broken_shield(shield_item_id)
	else:
		if target_unit != null and target_unit.has_method("set_selected_shield"):
			target_unit.set_selected_shield(null)
		if target_unit != null and target_unit.has_method("set_shield_switching"):
			target_unit.set_shield_switching(false)
		if target_unit != null and target_unit.has_method("set_shield_power_level"):
			target_unit.set_shield_power_level(0)
		clear_result = {
			"status": "success",
			"cleared": true,
			"labels": ["shield_runtime_state_cleared_fallback"]
		}

	var count_after := get_owned_item_count_for_unit(target_unit, shield_item_id)
	var result := {
		"status": "success" if not inventory_desync else "desync",
		"shield_broken": true,
		"shield_consumed": consumed,
		"shield_item_id": shield_item_id,
		"shield_hp_before": shield_hp_before,
		"shield_hp_after": shield_hp_after,
		"inventory_count_before": count_before,
		"inventory_count_after": count_after,
		"event_side": event_side,
		"break_consumes_item": break_consumes_item,
		"consume_status": consume_status,
		"inventory_desync": inventory_desync,
		"clear_result": clear_result,
		"blocked_reason": "shield_inventory_desync" if inventory_desync else "none",
		"labels": [
			"shield_break_detected",
			"shield_runtime_state_cleared"
		]
	}
	if consumed:
		result["labels"].append("shield_consumed_at_zero_hp")
		result["labels"].append("shield_break_inventory_spend_success")
	elif inventory_desync:
		result["labels"].append("shield_break_inventory_desync")
	return result


func get_owned_item_count_for_unit(unit_ref, item_id: String) -> int:
	var clean_id := item_id.strip_edges()
	if clean_id == "":
		return 0
	if get_battle_unit_side(unit_ref, "") == "enemy" and unit_ref != null and unit_ref.has_method("get_enemy_item_count"):
		return max(int(unit_ref.get_enemy_item_count(clean_id)), 0)
	return get_inventory_item_count(clean_id)


func get_inventory_item_count(item_id: String) -> int:
	if inventory == null:
		return 0
	if inventory is Dictionary:
		return count_snapshot_item(item_id, inventory)
	if inventory.has_method("count_item_anywhere"):
		return max(int(inventory.count_item_anywhere(item_id)), 0)
	return 0


func count_snapshot_item(item_id: String, inventory_ref: Dictionary) -> int:
	var inventory_data = inventory_ref.get("inventory_save_data", {})
	if typeof(inventory_data) != TYPE_DICTIONARY:
		return 0
	var total := 0
	for section_name in ["main", "drones"]:
		var section = inventory_data.get(section_name, {})
		if typeof(section) != TYPE_DICTIONARY:
			continue
		for slot_name in section.keys():
			var slot = section.get(slot_name, {})
			if typeof(slot) != TYPE_DICTIONARY:
				continue
			if str(slot.get("item_id", "")).strip_edges() == item_id.strip_edges():
				total += max(int(slot.get("count", 0)), 0)
	return total


func get_shield_item_id(shield_data) -> String:
	if shield_data == null:
		return ""
	if typeof(shield_data) == TYPE_DICTIONARY:
		return str(shield_data.get("item_id", shield_data.get("id", ""))).strip_edges()
	if shield_data is Object:
		var value = shield_data.get("item_id")
		if value == null:
			value = shield_data.get("id")
		if value != null:
			return str(value).strip_edges()
	return str(shield_data).strip_edges()


func get_shield_bool_value(shield_data, key: String, fallback: bool = false) -> bool:
	if typeof(shield_data) == TYPE_DICTIONARY:
		return bool(shield_data.get(key, fallback))
	if shield_data is Object:
		var value = shield_data.get(key)
		if value != null:
			return bool(value)
	return fallback


func get_unit_shield_item_id(unit_ref) -> String:
	if unit_ref == null:
		return ""
	if typeof(unit_ref) == TYPE_DICTIONARY:
		return get_shield_item_id(unit_ref.get("selected_shield", null))
	return get_shield_item_id(unit_ref.get("selected_shield"))


func get_unit_shield_hp_current(unit_ref) -> float:
	if unit_ref == null:
		return 0.0
	if typeof(unit_ref) == TYPE_DICTIONARY:
		return max(float(unit_ref.get("shield_hp_current", 0.0)), 0.0)
	var value = unit_ref.get("shield_hp_current")
	return max(float(value), 0.0) if value != null else 0.0


func get_unit_shield_hp_max(unit_ref) -> float:
	if unit_ref == null:
		return 0.0
	if typeof(unit_ref) == TYPE_DICTIONARY:
		var dict_value := float(unit_ref.get("shield_hp_max", 0.0))
		if dict_value > 0.0:
			return dict_value
		return get_shield_number_value(unit_ref.get("selected_shield", null), "shield_hp_max", 0.0)
	var direct_value = unit_ref.get("shield_hp_max")
	if direct_value != null and float(direct_value) > 0.0:
		return float(direct_value)
	return get_shield_number_value(unit_ref.get("selected_shield"), "shield_hp_max", 0.0)


func get_shield_number_value(shield_data, key: String, fallback: float = 0.0) -> float:
	# Summary: Read shield numeric data without assuming selected_shield is a Dictionary.
	if typeof(shield_data) == TYPE_DICTIONARY:
		return float(shield_data.get(key, fallback))
	if shield_data is Object:
		var value = shield_data.get(key)
		if value != null:
			return float(value)
	return fallback
	
	
	
func resolve_drone(event: Dictionary) -> Dictionary:
	# PURPOSE: Resolve completed drone deploy TODO, mark drone deployment as successful, and route any ongoing drone effect through standardized effect_packet handling.

	if Globals.debug_battleManager:
		print("[resolve_drone] START | event:", event)

	var result := {
		"type": "drone",
		"event_id": event.get("event_id", null),
		"drone_deployed": false,
		"effect_applied": false,
		"blocked_reason": "none",
		"labels": []
	}

	# --- OWNERSHIP READ PHASE ---
	var source_unit = event.get("source_unit")
	var target_unit = event.get("target_unit")
	var owner_unit = event.get("owner_unit")
	var event_side = event.get("event_side", "")

	if Globals.debug_battleManager:
		print("[resolve_drone] OWNER | source:", source_unit, " target:", target_unit, " owner:", owner_unit, " side:", event_side)

	# --- DRONE DEPLOY SUCCESS ---
	# Drones do not fail after TODO completion.
	# Support drones do not require lock.
	result["drone_deployed"] = true
	result["labels"].append("drone_resolution_rule")
	result["labels"].append("drone_functions_independent_of_lock")

	if Globals.debug_battleManager:
		print("[resolve_drone] RESULT: drone deployed")

	# --- DRONE DATA READ ---
	var data = event.get("data", {})
	var drone_type = data.get("drone_type", "")
	var applies_effect = data.get("applies_effect", false)

	if Globals.debug_battleManager:
		print("[resolve_drone] DATA | drone_type:", drone_type, " applies_effect:", applies_effect)

	if drone_type == "auto_attack":
		var runtime_result := deploy_active_drone(event, data)
		result["runtime_started"] = str(runtime_result.get("status", "")) == "deployed"
		result["runtime_result"] = runtime_result
		result["effect_applied"] = false
		result["labels"].append("auto_attack_drone_runtime")
		result["labels"].append("active_drone_runtime_started")
		for runtime_label in runtime_result.get("labels", []):
			if not result["labels"].has(runtime_label):
				result["labels"].append(runtime_label)
		clear_executed_consumable_state(event)
		return result

	# --- ALLY WEAPON DRONE EXCEPTION ---
	# Ally weapon drones deploy here.
	# Future weapon-drone attacks must come back as separate weapon damage TODOs using normal lock rules.
	if drone_type == "ally_weapon":
		if Globals.debug_battleManager:
			print("[resolve_drone] RESULT: ally weapon drone deployed; future attacks use lock rules")

		result["labels"].append("drone_weapon_type_exception")
		clear_executed_consumable_state(event)
		return result

	# --- NO ONGOING EFFECT CHECK ---
	# Some drones may deploy without creating an active stat effect.
	if not applies_effect:
		if Globals.debug_battleManager:
			print("[resolve_drone] RESULT: no ongoing drone effect")

		clear_executed_consumable_state(event)
		return result

	# --- DRONE EFFECT LABELS ---
	if drone_type == "signal_filter":
		result["labels"].append("signal_filter_drone_no_lock_check")
		result["labels"].append("drone_filtering_countdown")

	elif drone_type == "defensive" or drone_type == "support":
		result["labels"].append("defensive_drone_no_lock_check")

	# --- EFFECT PACKET BUILD ---
	var duration = data.get("duration", 6.0)

	var effect_packet := {
		"effect_id": data.get("effect_id", drone_type),
		"effect_group": "drone",
		"effect_type": data.get("effect_type", "protection"),

		"source_unit": source_unit,
		"target_unit": target_unit,
		"owner_unit": owner_unit,
		"event_side": event_side,

		"duration": duration,
		"tick_rate": data.get("tick_rate", 0.0),
		"time_remaining": duration,

		"stack_rule": data.get("stack_rule", "replace"),
		"priority": data.get("priority", 60),

		"affects": data.get("affects", []),
		"values": data.get("values", {}),
		"flags": data.get("flags", {}),

		"source_event_id": event.get("event_id", null),
		"battle_id": event.get("battle_id", ""),
		"battle_only": true,

		"visual_labels": data.get("visual_labels", []),
		"visual_labels_on_expire": data.get("visual_labels_on_expire", [])
	}

	if Globals.debug_battleManager:
		print("[resolve_drone] EFFECT PACKET:", effect_packet)

	# --- EFFECT ROUTE ---
	var effect_result = apply_stat_effects(effect_packet)

	result["effect_applied"] = effect_result.get("effect_applied", false)
	result["effect_result"] = effect_result

	if Globals.debug_battleManager:
		print("[resolve_drone] END RESULT:", result)

	clear_executed_consumable_state(event)
	return result
	
	
	
	
	
