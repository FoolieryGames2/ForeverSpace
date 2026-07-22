extends Node


class_name ActionManager_battle



var battle_active: bool = false
var current_battle_id: String = ""

var player_state = null
var active_enemy = null
var event_manager = null
var energy_handler = null
var ammo_handler = null
var inventory_ref = null
var battle_action_packet_builder: BattleActionPacketBuilder = null





func _route_rejected(action_id: String, reason: String, labels: Array = []) -> Dictionary:
	# Summary: Builds a standard rejected result when a battle action click cannot be routed safely.
	if Globals.print_priority_2:
		print("ActionManager_battle._route_rejected | Action rejected: ", action_id, " | Reason: ", reason)

	# Copy incoming labels so this helper can add standard route labels without changing the caller's array.
	var result_labels := labels.duplicate()

	# Every rejected battle click should carry the standard rejected-click label.
	if not result_labels.has("battle_action_click_rejected"):
		result_labels.append("battle_action_click_rejected")

	# Keep the no-resolution label attached so debug logs make the ownership boundary obvious.
	if not result_labels.has("action_manager_no_resolution"):
		result_labels.append("action_manager_no_resolution")

	# Return the standard rejected route result shape for button handlers and UI refresh logic.
	return {
		"status": "rejected",
		"action_id": action_id,
		"reason": reason,
		"labels": result_labels
	}
	
	
	
	
func _route_queued(action_id: String, packet_result: Dictionary, event_result: Dictionary, labels: Array = []) -> Dictionary:
	# Summary: Builds a standard queued result after a battle action packet is accepted by EventManager.
	if Globals.print_priority_2:
		print("ActionManager_battle._route_queued | Action queued: ", action_id)

	# Copy incoming labels so this helper can add standard route labels without changing the caller's array.
	var result_labels := labels.duplicate()

	# Mark this result as part of the Action_Manager battle routing path.
	if not result_labels.has("action_manager_battle_route"):
		result_labels.append("action_manager_battle_route")

	# Mark that the built packet was handed off to EventManager for TODO ownership.
	if not result_labels.has("battle_action_queued_to_event_manager"):
		result_labels.append("battle_action_queued_to_event_manager")

	# Keep the no-resolution label attached so this result cannot be mistaken for battle outcome logic.
	if not result_labels.has("action_manager_no_resolution"):
		result_labels.append("action_manager_no_resolution")

	# Keep the no-timing label attached because EventManager owns TODO countdown behavior.
	if not result_labels.has("action_manager_no_todo_timing"):
		result_labels.append("action_manager_no_todo_timing")

	# Return the standard queued route result shape for UI refresh and debug review.
	return {
		"status": "queued",
		"action_id": action_id,
		"packet_result": packet_result,
		"event_result": event_result,
		"reason": "",
		"labels": result_labels
	}
	
	
	
	
func _build_battle_action_context(action_id: String, action_data: Dictionary = {}) -> Dictionary:
	# Summary: Builds the standard context dictionary passed from Action_Manager into BattleActionPacketBuilder.
	if Globals.print_priority_3:
		print("ActionManager_battle._build_battle_action_context | Building context for action: ", action_id)

	# Most battle actions target the active enemy by default.
	var target_unit = active_enemy

	# Shield switching is self-targeted because the player ship is changing its own shield state.
	if action_id == "switch_shield":
		target_unit = player_state

	# Pull item data from the action_data packet if the clicked action provided item information.
	var item_data = action_data.get("item_data", {})

	# Build the shared packet-builder context shape used by all battle action routes.
	var context := {
		"source_unit": player_state,
		"target_unit": target_unit,
		"owner_unit": player_state,
		"event_side": "player",
		"battle_id": current_battle_id,
		"item_data": item_data,
		"action_id": action_id,
		"extra_data": action_data,
		"ammo_handler": ammo_handler,
		"inventory_ref": inventory_ref
	}

	# Allow button/action data to override duration when the UI or item database already knows timing.
	if action_data.has("duration"):
		context["duration"] = action_data.get("duration", 0.0)

	# Allow button/action data to provide a same-type key override for special future cases.
	if action_data.has("same_type_key"):
		context["same_type_key"] = action_data.get("same_type_key", "")

	if Globals.print_priority_3:
		print("ActionManager_battle._build_battle_action_context | Context built for action: ", action_id)

	return context
	
	
	
	
func _queue_packet_result(action_id: String, packet_result: Dictionary) -> Dictionary:
	# Summary: Sends a built packet_result to EventManager and returns a standard queued or rejected route result.
	if Globals.print_priority_2:
		print("ActionManager_battle._queue_packet_result | Queue request for action: ", action_id)

	# Safety check so failed packet builds do not reach EventManager.
	if packet_result.get("status", "") != "built":
		if Globals.print_priority_2:
			print("ActionManager_battle._queue_packet_result | Packet was not built. Reason: ", packet_result.get("reason", "packet build failed"))

		return _route_rejected(
			action_id,
			packet_result.get("reason", "packet build failed"),
			[
				"battle_action_packet_failed"
			]
		)

	# Pull the completed event packet from the packet_result wrapper. A burst action may carry many TODO packets.
	var event_packet = packet_result.get("event_packet", {})
	var event_packets: Array = []
	var packet_event_list = packet_result.get("event_packets", [])
	if typeof(packet_event_list) == TYPE_ARRAY and packet_event_list.size() > 0:
		for packet_entry in packet_event_list:
			if typeof(packet_entry) == TYPE_DICTIONARY and not packet_entry.is_empty():
				event_packets.append(packet_entry)
	elif typeof(event_packet) == TYPE_DICTIONARY and not event_packet.is_empty():
		event_packets.append(event_packet)

	# Safety check so EventManager never receives an empty or malformed packet from this route.
	if event_packets.is_empty():
		if Globals.print_priority_2:
			print("ActionManager_battle._queue_packet_result | WARNING: Built packet_result had no valid event_packet.")

		return _route_rejected(
			action_id,
			"missing event_packet",
			[
				"battle_action_packet_failed"
			]
		)

	var reserve_results: Array = []
	var ammo_results: Array = []
	var accepted_event_ids: Array = []
	var accepted_event_results: Array = []
	var queued_event_rows: Array = []

	for reserve_packet in event_packets:
		var reserve_result: Dictionary = reserve_energy_for_event_packet(action_id, reserve_packet)
		if reserve_result.get("status", "") != "success":
			release_reserved_resources_for_event_packets(event_packets)
			return _route_rejected(
				action_id,
				str(reserve_result.get("reason", "energy reserve failed")),
				str_array_from_variant(reserve_result.get("labels", []))
			)
		reserve_results.append(reserve_result)

		var ammo_reserve_result: Dictionary = reserve_ammo_for_event_packet(action_id, reserve_packet)
		if ammo_reserve_result.get("status", "") != "success":
			release_reserved_resources_for_event_packets(event_packets)
			return _route_rejected(
				action_id,
				str(ammo_reserve_result.get("reason", "ammo reserve failed")),
				str_array_from_variant(ammo_reserve_result.get("labels", []))
			)
		ammo_results.append(ammo_reserve_result)

	# EventManager owns validation, final event_id, stacking, and TODO countdown after this handoff.
	var event_result: Dictionary = {}
	for queue_packet in event_packets:
		event_result = event_manager.add_event(queue_packet)
		if not bool(event_result.get("accepted", false)):
			for accepted_id in accepted_event_ids:
				if event_manager != null and event_manager.has_method("cancel_event"):
					event_manager.cancel_event(str(accepted_id), "burst_queue_rollback")
			release_reserved_resources_for_event_packets(event_packets)
			return _route_rejected(
				action_id,
				"event manager rejected: " + str(event_result.get("blocked_reason", "unknown")),
				str_array_from_variant(event_result.get("labels", []))
			)
		accepted_event_ids.append(event_result.get("event_id", ""))
		accepted_event_results.append(event_result.duplicate(true))
		queued_event_rows.append({
			"event_id": str(event_result.get("event_id", "")),
			"event_type": str(event_result.get("event_type", queue_packet.get("event_type", ""))),
			"same_type_key": str(event_result.get("same_type_key", queue_packet.get("same_type_key", ""))),
			"duration": float(event_result.get("duration", queue_packet.get("duration", 0.0))),
			"time_remaining": float(event_result.get("time_remaining", queue_packet.get("time_remaining", 0.0))),
			"burst_index": int(queue_packet.get("data", {}).get("burst_index", 0)) if typeof(queue_packet.get("data", {})) == TYPE_DICTIONARY else 0,
			"burst_total": int(queue_packet.get("data", {}).get("burst_total", 0)) if typeof(queue_packet.get("data", {})) == TYPE_DICTIONARY else 0,
			"ammo_cost": get_event_packet_ammo_cost(queue_packet)
		})

	if Globals.print_priority_2:
		print("ActionManager_battle._queue_packet_result | EventManager received packet for action: ", action_id, " count=", event_packets.size())
		if event_packets.size() > 1:
			print("[player_burst_todo_stack_queued] action=", action_id, " count=", event_packets.size(), " rows=", JSON.stringify(queued_event_rows))

	# Return the standard queued route result for UI refresh and debug review.
	var queued_result: Dictionary = _route_queued(
		action_id,
		packet_result,
		event_result,
		[
			"battle_action_packet_built",
			"battle_action_queued_to_event_manager"
		]
	)
	queued_result["energy_result"] = reserve_results[0] if not reserve_results.is_empty() else {}
	queued_result["ammo_result"] = ammo_results[0] if not ammo_results.is_empty() else {}
	queued_result["energy_results"] = reserve_results
	queued_result["ammo_results"] = ammo_results
	queued_result["event_results"] = accepted_event_results
	queued_result["queued_event_count"] = event_packets.size()
	queued_result["event_ids"] = accepted_event_ids
	queued_result["queued_event_rows"] = queued_event_rows
	return queued_result
	
	
	
	
func release_reserved_resources_for_event_packets(event_packets: Array) -> void:
	# Summary: Roll back queue-time reservations for a packet group when any packet fails to queue.
	for rollback_packet in event_packets:
		if typeof(rollback_packet) != TYPE_DICTIONARY:
			continue
		release_reserved_energy_for_event_packet(rollback_packet)
		release_reserved_ammo_for_event_packet(rollback_packet)
	
	
	
func reserve_energy_for_event_packet(action_id: String, event_packet: Dictionary) -> Dictionary:
	# Summary: Reserve EnergyHandler expected-use when a player energy action successfully builds a TODO packet.
	var energy_cost: float = get_event_packet_energy_cost(event_packet)
	var result: Dictionary = {
		"status": "success",
		"reason": "",
		"energy_cost": energy_cost,
		"labels": [
			"action_manager_energy_reserve_bridge",
			"energy_expected_use_on_action"
		]
	}

	if energy_cost <= 0.0:
		event_packet["energy_reserved"] = false
		event_packet["reserved_energy_cost"] = 0.0
		return result

	if energy_handler == null or not energy_handler.has_method("reserve_energy"):
		result["status"] = "failed"
		result["reason"] = "missing energy_handler reserve_energy"
		event_packet["energy_reserved"] = false
		event_packet["reserved_energy_cost"] = 0.0
		return result

	var reserve_result = energy_handler.reserve_energy(energy_cost)
	if not is_energy_result_success(reserve_result):
		result["status"] = "failed"
		result["reason"] = get_energy_result_reason(reserve_result, "not enough available energy")
		event_packet["energy_reserved"] = false
		event_packet["reserved_energy_cost"] = 0.0
		return result

	event_packet["energy_reserved"] = true
	event_packet["reserved_energy_cost"] = energy_cost
	result["energy_handler_result"] = reserve_result
	return result


func release_reserved_energy_for_event_packet(event_packet: Dictionary) -> void:
	# Summary: Roll back expected-use if EventManager rejects a packet after energy was reserved.
	if energy_handler == null or not energy_handler.has_method("release_reserved_energy"):
		return
	if not bool(event_packet.get("energy_reserved", false)):
		return

	var energy_cost: float = get_event_packet_energy_cost(event_packet)
	if energy_cost <= 0.0:
		return

	energy_handler.release_reserved_energy(energy_cost)
	event_packet["energy_reserved"] = false
	event_packet["reserved_energy_cost"] = 0.0


func get_event_packet_energy_cost(event_packet: Dictionary) -> float:
	# Summary: Read the queue-time energy cost from the packet data payload without calculating energy.
	var data_payload = event_packet.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY:
		return max(float(data_payload.get("energy_cost", event_packet.get("energy_cost", 0.0))), 0.0)

	return max(float(event_packet.get("energy_cost", 0.0)), 0.0)


func reserve_ammo_for_event_packet(action_id: String, event_packet: Dictionary) -> Dictionary:
	# Summary: Reserve AmmoHandler expected-use when a player ammo action successfully builds a TODO packet.
	var ammo_group: String = get_event_packet_ammo_group(event_packet)
	var ammo_cost: int = get_event_packet_ammo_cost(event_packet)
	var result: Dictionary = {
		"status": "success",
		"reason": "",
		"ammo_group": ammo_group,
		"ammo_cost": ammo_cost,
		"labels": [
			"action_manager_ammo_reserve_bridge",
			"ammo_expected_use_on_action"
		]
	}

	if ammo_cost <= 0:
		event_packet["ammo_reserved"] = false
		event_packet["reserved_ammo_cost"] = 0
		return result

	if ammo_handler == null or not ammo_handler.has_method("reserve_ammo"):
		result["status"] = "failed"
		result["reason"] = "missing ammo_handler reserve_ammo"
		event_packet["ammo_reserved"] = false
		event_packet["reserved_ammo_cost"] = 0
		return result

	var reserve_result = ammo_handler.reserve_ammo(ammo_group, ammo_cost, inventory_ref)
	if not is_ammo_result_success(reserve_result):
		result["status"] = "failed"
		result["reason"] = get_ammo_result_reason(reserve_result, "not enough available ammo")
		event_packet["ammo_reserved"] = false
		event_packet["reserved_ammo_cost"] = 0
		if typeof(reserve_result) == TYPE_DICTIONARY:
			result["labels"] = str_array_from_variant(reserve_result.get("labels", result["labels"]))
		return result

	event_packet["ammo_reserved"] = true
	event_packet["reserved_ammo_cost"] = ammo_cost
	result["ammo_handler_result"] = reserve_result
	return result


func release_reserved_ammo_for_event_packet(event_packet: Dictionary) -> void:
	# Summary: Roll back expected ammo use if EventManager rejects a packet after ammo was reserved.
	if ammo_handler == null or not ammo_handler.has_method("release_reserved_ammo"):
		return
	if not bool(event_packet.get("ammo_reserved", false)):
		return

	var ammo_group: String = get_event_packet_ammo_group(event_packet)
	var ammo_cost: int = max(int(event_packet.get("reserved_ammo_cost", 0)), get_event_packet_ammo_cost(event_packet))
	if ammo_cost <= 0:
		return

	ammo_handler.release_reserved_ammo(ammo_group, ammo_cost)
	event_packet["ammo_reserved"] = false
	event_packet["reserved_ammo_cost"] = 0


func get_event_packet_ammo_group(event_packet: Dictionary) -> String:
	# Summary: Read queue-time ammo group from packet data without owning ammo rules.
	var data_payload = event_packet.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY:
		return str(data_payload.get("ammo_group", event_packet.get("ammo_group", "")))
	return str(event_packet.get("ammo_group", ""))


func get_event_packet_ammo_cost(event_packet: Dictionary) -> int:
	# Summary: Read queue-time ammo cost from packet data without owning ammo rules.
	var data_payload = event_packet.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY:
		return max(int(data_payload.get("reserve_total_ammo_cost", data_payload.get("total_ammo_cost", data_payload.get("ammo_cost", event_packet.get("ammo_cost", 0))))), 0)

	return max(int(event_packet.get("ammo_cost", 0)), 0)


func str_array_from_variant(value: Variant) -> Array:
	# Summary: Convert optional label variants into a plain Array for standard route helpers.
	if typeof(value) == TYPE_ARRAY:
		return value
	return []


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


func get_battle_action_population_result(action_id: String, item_data: Dictionary) -> Dictionary:
	# Summary: Decide whether a battle action row may populate, using EnergyHandler/AmmoHandler reserve validity.
	var energy_cost: float = get_item_data_energy_cost(item_data)
	var ammo_group: String = get_item_data_ammo_group(item_data)
	var ammo_cost: int = get_item_data_ammo_cost(item_data)
	var result: Dictionary = {
		"status": "populate",
		"action_id": action_id,
		"reason": "",
		"energy_cost": energy_cost,
		"ammo_group": ammo_group,
		"ammo_cost": ammo_cost,
		"labels": [
			"action_manager_battle_population_decision"
		]
	}

	if energy_cost > 0.0 and (energy_handler == null or not energy_handler.has_method("can_reserve")):
		result["status"] = "blocked"
		result["reason"] = "missing energy reserve check"
		result["labels"].append("battle_action_population_reserved_energy_block")
		return result

	if energy_cost > 0.0 and not energy_handler.can_reserve(energy_cost):
		result["status"] = "blocked"
		result["reason"] = "reserved energy would exceed available energy"
		result["labels"].append("battle_action_population_reserved_energy_block")
		result["labels"].append("battle_action_population_same_action_energy_block")
		return result

	if ammo_cost <= 0:
		return result

	if ammo_handler == null or not ammo_handler.has_method("can_reserve_ammo"):
		result["status"] = "blocked"
		result["reason"] = "missing ammo reserve check"
		result["labels"].append("battle_action_population_ammo_failed")
		return result

	if not ammo_handler.can_reserve_ammo(ammo_group, ammo_cost, inventory_ref):
		result["status"] = "blocked"
		result["reason"] = "reserved ammo would exceed available ammo"
		result["labels"].append("battle_action_population_ammo_failed")
		result["labels"].append("battle_action_population_reserved_ammo_block")
		return result

	return result


func get_item_data_energy_cost(item_data: Dictionary) -> float:
	# Summary: Read action population energy cost from item data without calculating energy state.
	return max(float(item_data.get("energy_cost", 0.0)), 0.0)


func get_item_data_ammo_group(item_data: Dictionary) -> String:
	# Summary: Read action population ammo group from item data without owning ammo rules.
	if ammo_handler != null and ammo_handler.has_method("get_weapon_ammo_group"):
		return str(ammo_handler.get_weapon_ammo_group(item_data))
	return str(item_data.get("ammo_group", ""))


func get_item_data_ammo_cost(item_data: Dictionary) -> int:
	# Summary: Read action population ammo cost from item data without owning inventory counts.
	if ammo_handler != null and ammo_handler.has_method("get_weapon_ammo_cost"):
		return max(int(ammo_handler.get_weapon_ammo_cost(item_data)), 0)
	return max(int(item_data.get("total_ammo_cost", item_data.get("ammo_cost", 0))), 0)


func _validate_battle_route_references(action_id: String) -> Dictionary:
	# Summary: Checks that Action_Manager has the required battle references before routing a battle click.
	if Globals.print_priority_3:
		print("ActionManager_battle._validate_battle_route_references | Checking references for action: ", action_id)

	# Battle route must be active before any battle click can become a TODO packet.
	if not battle_active:
		return _route_rejected(
			action_id,
			"battle not active",
			[
				"battle_action_click_rejected"
			]
		)

	# Player state is required because player actions use it as source_unit and owner_unit.
	if player_state == null:
		return _route_rejected(
			action_id,
			"missing player_state",
			[
				"battle_action_click_rejected"
			]
		)

	# Most first-pass battle actions need one active enemy target.
	if active_enemy == null:
		return _route_rejected(
			action_id,
			"missing active_enemy",
			[
				"battle_action_click_rejected"
			]
		)

	# EventManager is required because Action_Manager hands built packets to it for TODO ownership.
	if event_manager == null:
		return _route_rejected(
			action_id,
			"missing event_manager",
			[
				"battle_action_click_rejected"
			]
		)

	# PacketBuilder is required because Action_Manager should not manually build full battle packets.
	if battle_action_packet_builder == null:
		return _route_rejected(
			action_id,
			"missing battle_action_packet_builder",
			[
				"battle_action_click_rejected"
			]
		)

	if Globals.print_priority_3:
		print("ActionManager_battle._validate_battle_route_references | References valid for action: ", action_id)

	# Return a small valid result so the main router can continue safely.
	return {
		"status": "valid",
		"action_id": action_id,
		"reason": "",
		"labels": [
			"action_manager_battle_route"
		]
	}
	
	
	
	
func handle_battle_action_click(action_id: String, action_data: Dictionary = {}) -> Dictionary:
	# Summary: Routes a battle action click into the packet builder, then queues the built packet with EventManager.
	if Globals.print_priority_2:
		print("ActionManager_battle.handle_battle_action_click | Battle action clicked: ", action_id)

	# Safety check so blank action ids never reach the packet builder or EventManager.
	if action_id.strip_edges() == "":
		return _route_rejected(
			action_id,
			"missing action_id",
			[
				"battle_action_click_rejected"
			]
		)

	# Confirm battle mode and required references before building context.
	var reference_result := _validate_battle_route_references(action_id)

	if reference_result.get("status", "") != "valid":
		return reference_result

	# Build the shared battle context that BattleActionPacketBuilder expects.
	var context := _build_battle_action_context(action_id, action_data)

	if Globals.print_priority_3:
		print("ActionManager_battle.handle_battle_action_click | Context built for action: ", action_id)

	# Ask the packet builder to create the correct packet_result for this battle action.
	var packet_result := {}

	match action_id:
		"fire_primary_weapon":
			packet_result = battle_action_packet_builder.build_fire_primary_packet(context)

		"fire_secondary_weapon":
			packet_result = battle_action_packet_builder.build_fire_secondary_packet(context)

		"switch_shield":
			packet_result = battle_action_packet_builder.build_switch_shield_packet(context)

		"load_consumable":
			packet_result = battle_action_packet_builder.build_load_consumable_packet(context)

		"execute_consumable":
			packet_result = battle_action_packet_builder.build_execute_consumable_packet(context)

		"player_evade":
			packet_result = battle_action_packet_builder.build_evade_packet(context)

		_:
			return _route_rejected(
				action_id,
				"unknown or not-yet-routed battle action_id",
				[
					"battle_action_click_rejected"
				]
			)

	if Globals.print_priority_3:
		print("ActionManager_battle.handle_battle_action_click | Packet build status: ", packet_result.get("status", ""))

	# Send the built packet_result to EventManager through the standard queue helper.
	return _queue_packet_result(action_id, packet_result)
	
	
	
	
func test_setup_primary_weapon_route() -> void:
	# Summary: Creates temporary test references for checking the primary weapon battle click route.
	if Globals.print_priority_2:
		print("ActionManager_battle.test_setup_primary_weapon_route | Starting test setup.")

	battle_active = true
	current_battle_id = "test_battle_001"

	player_state = {
		"unit_id": "player",
		"unit_side": "player"
	}

	active_enemy = {
		"unit_id": "enemy_001",
		"unit_side": "enemy"
	}

	battle_action_packet_builder = BattleActionPacketBuilder.new()

	if Globals.print_priority_2:
		print("ActionManager_battle.test_setup_primary_weapon_route | Test setup complete.")
		
		
		
func test_setup_primary_weapon_route_real_event_manager(real_event_manager) -> void:
	# Summary: Creates temporary real battle references for checking the primary weapon click route with the real EventManager.
	if Globals.print_priority_2:
		print("ActionManager_battle.test_setup_primary_weapon_route_real_event_manager | Starting real EventManager test setup.")

	battle_active = true
	current_battle_id = "test_battle_001"

	# Temporary player battle source.
	player_state = {
		"unit_id": "player",
		"unit_side": "player"
	}

	# Temporary enemy battle target.
	active_enemy = {
		"unit_id": "enemy_001",
		"unit_side": "enemy"
	}

	# Use the real EventManager instance passed in from the scene/main controller.
	event_manager = real_event_manager

	# Use the real packet builder class.
	battle_action_packet_builder = BattleActionPacketBuilder.new()

	if Globals.print_priority_2:
		print("ActionManager_battle.test_setup_primary_weapon_route_real_event_manager | Setup complete.")
