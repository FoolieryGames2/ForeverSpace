

extends RefCounted
class_name BattleActionPacketBuilder


func make_packet_result(status: String, event_packet: Dictionary, reason: String = "", labels: Array = []) -> Dictionary:
	# Summary: Builds the standard packet_result dictionary returned by packet builder functions.
	if Globals.print_priority_3:
		print("BattleActionPacketBuilder.make_packet_result | Status: ", status, " | Reason: ", reason)

	# Keep all builder responses in one predictable shape for Action_Manager to read safely.
	var packet_result := {
		"status": status,
		"event_packet": event_packet,
		"reason": reason,
		"labels": labels
	}

	# Return the completed packet_result without queuing, resolving, or timing the event.
	return packet_result
	
	
	
	
func make_rejected_result(reason: String, labels: Array = []) -> Dictionary:
	# Summary: Builds a standardized rejected packet_result when a battle event packet cannot be created safely.
	if Globals.print_priority_2:
		print("BattleActionPacketBuilder.make_rejected_result | Rejected packet build. Reason: ", reason)

	# Copy incoming labels so the caller's original array is not modified by this helper.
	var result_labels := labels.duplicate()

	# Ensure every rejected result carries the standard rejection label for Action_Manager/debug routing.
	if not result_labels.has("packet_build_rejected"):
		result_labels.append("packet_build_rejected")

	# Reuse the shared result wrapper so all builder functions return the same shape.
	return make_packet_result("rejected", {}, reason, result_labels)
	
	
	
	
func make_built_result(event_packet: Dictionary, labels: Array = []) -> Dictionary:
	# Summary: Builds a standardized built packet_result for a completed EventManager-ready packet.
	if Globals.print_priority_3:
		print("BattleActionPacketBuilder.make_built_result | Built packet type: ", event_packet.get("event_type", ""))

	# Copy incoming labels so this helper can add standard labels without mutating the caller's array.
	var result_labels := labels.duplicate()

	# Ensure every built result carries the standard ready label for Action_Manager/EventManager handoff.
	if not result_labels.has("packet_ready_for_event_manager"):
		result_labels.append("packet_ready_for_event_manager")

	# Reuse the shared result wrapper so all builder functions return the same packet_result shape.
	return make_packet_result("built", event_packet, "", result_labels)
	
	
	
func make_built_multi_result(event_packets: Array, labels: Array = []) -> Dictionary:
	# Summary: Build one packet result for a click that expands into multiple EventManager TODO packets.
	var result_labels := labels.duplicate()

	if not result_labels.has("packet_ready_for_event_manager"):
		result_labels.append("packet_ready_for_event_manager")
	if not result_labels.has("packet_builder_multi_event_result"):
		result_labels.append("packet_builder_multi_event_result")

	var first_event_packet: Dictionary = {}
	if not event_packets.is_empty() and typeof(event_packets[0]) == TYPE_DICTIONARY:
		first_event_packet = event_packets[0]

	var result := make_packet_result("built", first_event_packet, "", result_labels)
	result["event_packets"] = event_packets
	result["event_packet_count"] = event_packets.size()
	return result
	
	
	
	
func build_base_event_packet(context: Dictionary, event_type: String, event_group: String) -> Dictionary:
	# Summary: Builds the shared EventManager event packet shell using battle context and basic event identity fields.
	if Globals.print_priority_3:
		print("BattleActionPacketBuilder.build_base_event_packet | Event type: ", event_type, " | Group: ", event_group)

	# Pull duration once so duration and time_remaining always start synchronized.
	var duration := float(context.get("duration", 0.0))

	# Build the standard packet shape expected by EventManager and later BattleManager resolution.
	var event_packet := {
		"event_id": "",
		"event_type": event_type,
		"event_group": event_group,
		"event_subtype": context.get("event_subtype", ""),

		# Ownership fields tell the battle pipeline who created, owns, and receives this event.
		"source_unit": context.get("source_unit", null),
		"target_unit": context.get("target_unit", null),
		"owner_unit": context.get("owner_unit", null),
		"event_side": context.get("event_side", ""),

		# Timing fields are filled here, but EventManager still owns countdown behavior.
		"duration": duration,
		"time_remaining": duration,

		# Same-type key can be overridden by action-specific builders to prevent action spam correctly.
		"same_type_key": context.get("same_type_key", event_type),

		# Lock and routing flags default safe/off until an action-specific builder turns them on.
		"requires_lock": bool(context.get("requires_lock", false)),
		"is_state_change": bool(context.get("is_state_change", false)),
		"is_damage_event": bool(context.get("is_damage_event", false)),
		"is_effect_event": bool(context.get("is_effect_event", false)),
		"is_visual_only": bool(context.get("is_visual_only", false)),

		# Item/action fields stay generic here and are filled by specific weapon, shield, or consumable builders.
		"item_id": context.get("item_id", ""),
		"action_id": context.get("action_id", event_type),
		"damage_type": context.get("damage_type", ""),
		"damage_value": context.get("damage_value", 0),

		# Battle id links the packet back to the active battle instance if the caller provides one.
		"battle_id": context.get("battle_id", ""),

		# Data payload carries action-specific details without changing the top-level packet shape.
		"data": context.get("data", context.get("extra_data", {}))
	}

	var source_shared_meta := {}
	if typeof(context.get("shared_meta", {})) == TYPE_DICTIONARY:
		source_shared_meta = context.get("shared_meta", {}).duplicate(true)
	elif typeof(context.get("item_data", {})) == TYPE_DICTIONARY:
		var item_data: Dictionary = context.get("item_data", {})
		if typeof(item_data.get("shared_meta", {})) == TYPE_DICTIONARY:
			source_shared_meta = item_data.get("shared_meta", {}).duplicate(true)
		else:
			source_shared_meta = item_data.duplicate(true)

	var packet_object_id := str(context.get("object_id", context.get("item_id", context.get("action_id", event_type)))).strip_edges()
	if packet_object_id == "":
		packet_object_id = event_type
	var packet_display_name := str(context.get("display_name", packet_object_id)).strip_edges()
	if packet_display_name == "":
		packet_display_name = event_type

	event_packet = SharedObjectMeta.apply_to_dictionary(
		event_packet,
		packet_object_id,
		"battle_event",
		packet_display_name,
		Vector3i.ZERO,
		Vector3.ZERO
	)
	if not source_shared_meta.is_empty():
		event_packet["source_shared_meta"] = SharedObjectMeta.to_save_data(
			SharedObjectMeta.build_meta("", "", "", null, null, source_shared_meta)
		)

	# Return the base packet only; action-specific builders will finish flags, payload, and result wrapping.
	return event_packet
	
	
	
	
func validate_common_context(context: Dictionary, needs_target: bool = true, needs_item_data: bool = false) -> Dictionary:
	# Summary: Validates shared battle packet build context before an action-specific packet is created.
	if Globals.print_priority_3:
		print("BattleActionPacketBuilder.validate_common_context | Checking context. Needs target: ", needs_target, " | Needs item data: ", needs_item_data)

	# Source unit is required because EventManager and BattleManager need to know who created the action.
	if context.get("source_unit", null) == null:
		return make_rejected_result("missing source_unit", ["packet_build_rejected"])

	# Owner unit is required because ownership can differ from source for allies or future drone actions.
	if context.get("owner_unit", null) == null:
		return make_rejected_result("missing owner_unit", ["packet_build_rejected"])

	# Event side is required for battle routing and debug separation between player, enemy, ally, and neutral actions.
	if str(context.get("event_side", "")).strip_edges() == "":
		return make_rejected_result("missing event_side", ["packet_build_rejected"])

	# Target validation is optional because self-target and prep actions may not always need an enemy target.
	if needs_target and context.get("target_unit", null) == null:
		return make_rejected_result("missing target_unit", ["packet_build_rejected"])

	# Item data validation is optional because evade or other non-item actions do not require item payloads.
	if needs_item_data:
		var item_data = context.get("item_data", {})

		if typeof(item_data) != TYPE_DICTIONARY or item_data.is_empty():
			return make_rejected_result("missing item_data", ["packet_build_rejected"])

	# Action id should be present so packets can be traced back to the clicked battle action.
	if str(context.get("action_id", "")).strip_edges() == "":
		return make_rejected_result("missing action_id", ["packet_build_rejected"])

	# Duration must be valid before packet creation, even though EventManager owns the countdown after queuing.
	if not context.has("duration") or float(context.get("duration", 0.0)) <= 0.0:
		return make_rejected_result("missing or invalid duration", ["packet_build_rejected"])

	if Globals.print_priority_3:
		print("BattleActionPacketBuilder.validate_common_context | Context passed validation for action: ", context.get("action_id", ""))

	# Return a lightweight success dictionary so action-specific builders can continue safely.
	return {
		"status": "valid",
		"reason": "",
		"labels": []
	}
	
	
	
	
func get_item_id(item_data: Dictionary) -> String:
	# Summary: Reads a stable item id from item_data using safe fallback keys.
	if Globals.print_priority_3:
		print("BattleActionPacketBuilder.get_item_id | Reading item id from item data.")

	# Prefer the standard item_id key because EventManager packets use item_id as the top-level field.
	var item_id := str(item_data.get("item_id", "")).strip_edges()

	# Support common fallback key names so older item dictionaries can still build packets safely.
	if item_id == "":
		item_id = str(item_data.get("id", "")).strip_edges()

	if item_id == "":
		item_id = str(item_data.get("uid", "")).strip_edges()

	# Report empty ids without rejecting here; action-specific builders decide whether an item id is required.
	if item_id == "" and Globals.print_priority_2:
		print("BattleActionPacketBuilder.get_item_id | WARNING: Item data did not contain item_id, id, or uid.")

	return item_id
	
	
	
	
func get_explosive_damage_value(item_data: Dictionary) -> float:
	# Summary: Read explosive damage across the common direct and nested item-data shapes.
	var damage := get_item_number(
		item_data,
		"explosive_damage",
		get_item_number(
			item_data,
			"damage_value",
			get_item_number(
				item_data,
				"damage",
				get_item_number(item_data, "blast_damage", get_item_number(item_data, "hull_damage", 0.0))
			)
		)
	)
	if damage > 0.0:
		return damage

	var values = item_data.get("values", {})
	if typeof(values) == TYPE_DICTIONARY:
		var value_packet: Dictionary = values
		return get_item_number(
			value_packet,
			"explosive_damage",
			get_item_number(
				value_packet,
				"damage_value",
				get_item_number(
					value_packet,
					"damage",
					get_item_number(value_packet, "blast_damage", get_item_number(value_packet, "hull_damage", 0.0))
				)
			)
		)

	return 0.0


func get_item_number(item_data: Dictionary, key: String, fallback: float = 0.0) -> float:
	# Summary: Reads a numeric item value from item_data using a safe fallback when the key is missing or invalid.
	if Globals.print_priority_3:
		print("BattleActionPacketBuilder.get_item_number | Reading numeric key: ", key)

	# Safety check so blank keys do not accidentally read meaningless item data.
	if key.strip_edges() == "":
		if Globals.print_priority_2:
			print("BattleActionPacketBuilder.get_item_number | WARNING: Blank key provided. Using fallback: ", fallback)

		return fallback

	# If the requested key is missing, return the provided fallback value.
	if not item_data.has(key):
		if Globals.print_priority_3:
			print("BattleActionPacketBuilder.get_item_number | Key missing: ", key, " | Using fallback: ", fallback)

		return fallback

	# Pull the raw value so we can safely handle ints, floats, and numeric strings.
	var raw_value = item_data.get(key, fallback)

	# Numeric strings are allowed because some data tables may store values as text.
	if typeof(raw_value) == TYPE_STRING:
		var clean_value := str(raw_value).strip_edges()

		if clean_value.is_valid_float():
			return clean_value.to_float()

		if Globals.print_priority_2:
			print("BattleActionPacketBuilder.get_item_number | WARNING: Invalid numeric string for key: ", key, " | Value: ", raw_value, " | Using fallback: ", fallback)

		return fallback

	# Godot number types can be safely converted to float for packet fields.
	if typeof(raw_value) == TYPE_INT or typeof(raw_value) == TYPE_FLOAT:
		return float(raw_value)

	# Unsupported value types fall back safely and report the mismatch for debugging item data drift.
	if Globals.print_priority_2:
		print("BattleActionPacketBuilder.get_item_number | WARNING: Unsupported value type for key: ", key, " | Using fallback: ", fallback)

	return fallback


func get_enemy_slot_for_intent(enemy_intent: String) -> String:
	# Summary: Map enemy logic intent ids to loadout slots.
	var intent := enemy_intent.strip_edges().to_lower()
	if intent == "enemy_attack" or intent == "enemy_primary_attack" or intent == "enemy_attack_primary":
		return "primary"
	if intent == "enemy_secondary_attack" or intent == "enemy_attack_secondary":
		return "secondary"
	if intent == "enemy_switch_shield":
		return "shield"
	if intent == "enemy_remove_shield":
		return ""
	if intent == "enemy_clear_loaded_consumable":
		return ""
	if intent == "enemy_load_consumable" or intent == "enemy_execute_consumable" or intent == "enemy_use_consumable" or intent == "enemy_repair" or intent == "enemy_recharge":
		return "consumable"
	return ""


func get_enemy_loadout_item_data(context: Dictionary, enemy_intent: String) -> Dictionary:
	# Summary: Resolve enemy loadout item data from enemy_loadout, intent data, item_data, or item_db_snapshot.
	var slot := get_enemy_slot_for_intent(enemy_intent)
	if slot == "":
		return {}

	var intent_data = context.get("intent_data", {})
	if typeof(intent_data) == TYPE_DICTIONARY:
		var intent_item_data = intent_data.get("item_data", {})
		if typeof(intent_item_data) == TYPE_DICTIONARY and not intent_item_data.is_empty():
			return intent_item_data.duplicate(true)
		var intent_item_id := normalize_enemy_battle_item_id(str(intent_data.get("item_id", "")).strip_edges())
		if intent_item_id != "":
			var item_db_for_intent = context.get("item_db_snapshot", {})
			if typeof(item_db_for_intent) == TYPE_DICTIONARY:
				var intent_snapshot_item = item_db_for_intent.get(intent_item_id, {})
				if typeof(intent_snapshot_item) == TYPE_DICTIONARY and not intent_snapshot_item.is_empty():
					var intent_packet: Dictionary = intent_snapshot_item.duplicate(true)
					intent_packet["item_id"] = intent_item_id
					intent_packet["id"] = intent_item_id
					return intent_packet

	var loadout = context.get("enemy_loadout", {})
	if typeof(loadout) == TYPE_DICTIONARY:
		var data_key := slot + "_item_data"
		var slot_data = loadout.get(data_key, {})
		if typeof(slot_data) == TYPE_DICTIONARY and not slot_data.is_empty():
			return slot_data.duplicate(true)

	var direct_item_data = context.get("item_data", {})
	if slot == "primary" and typeof(direct_item_data) == TYPE_DICTIONARY and not direct_item_data.is_empty():
		return direct_item_data.duplicate(true)

	var item_id := get_enemy_loadout_item_id(context, enemy_intent)
	if item_id == "":
		return {}

	var item_db = context.get("item_db_snapshot", {})
	if typeof(item_db) == TYPE_DICTIONARY:
		var snapshot_item = item_db.get(item_id, {})
		if typeof(snapshot_item) == TYPE_DICTIONARY and not snapshot_item.is_empty():
			var packet: Dictionary = snapshot_item.duplicate(true)
			packet["item_id"] = item_id
			packet["id"] = item_id
			return packet

	return {
		"item_id": item_id,
		"id": item_id,
		"display_name": item_id,
		"name": item_id
	}


func get_enemy_loadout_item_id(context: Dictionary, enemy_intent: String) -> String:
	# Summary: Resolve enemy loadout item id from intent data or enemy_loadout by slot.
	var slot := get_enemy_slot_for_intent(enemy_intent)
	var intent_data = context.get("intent_data", {})
	if typeof(intent_data) == TYPE_DICTIONARY:
		var slot_item_id := normalize_enemy_battle_item_id(str(intent_data.get(slot + "_item_id", "")).strip_edges())
		if slot_item_id != "":
			return slot_item_id

		var intent_item_id := str(intent_data.get("item_id", "")).strip_edges()
		if intent_item_id != "":
			return normalize_enemy_battle_item_id(intent_item_id)

	if slot == "":
		return str(context.get("item_id", "")).strip_edges()

	var loadout = context.get("enemy_loadout", {})
	if typeof(loadout) == TYPE_DICTIONARY:
		return normalize_enemy_battle_item_id(str(loadout.get(slot, "")).strip_edges())

	return normalize_enemy_battle_item_id(str(context.get("item_id", "")).strip_edges())


func get_enemy_item_duration(item_data: Dictionary, enemy_intent: String, fallback: float) -> float:
	# Summary: Pick the correct timing key for enemy weapon/shield/consumable actions.
	if item_data.is_empty():
		return fallback
	var intent := enemy_intent.strip_edges().to_lower()
	if intent == "enemy_switch_shield":
		var shield_time := get_item_number(item_data, "switch_time", get_item_number(item_data, "duration", get_item_number(item_data, "cooldown", fallback)))
		return shield_time if shield_time > 0.0 else fallback
	if intent == "enemy_load_consumable":
		var load_time := get_item_number(item_data, "prep_time", get_item_number(item_data, "load_time", get_item_number(item_data, "duration", fallback)))
		return load_time if load_time > 0.0 else fallback
	if intent == "enemy_execute_consumable" or intent == "enemy_use_consumable" or intent == "enemy_repair" or intent == "enemy_recharge":
		var execute_time := get_item_number(item_data, "execute_time", get_item_number(item_data, "duration", get_item_number(item_data, "cooldown", fallback)))
		return execute_time if execute_time > 0.0 else fallback
	var weapon_time := get_item_number(item_data, "duration", get_item_number(item_data, "fire_time", get_item_number(item_data, "cooldown", fallback)))
	return weapon_time if weapon_time > 0.0 else fallback


func get_enemy_ammo_item_id_for_group(context: Dictionary, ammo_group: String) -> String:
	# Summary: Pick the first enemy-held ammo item id that matches the weapon's ammo group.
	var wanted_group := ammo_group.strip_edges().to_lower()
	if wanted_group == "":
		return ""
	var loadout = context.get("enemy_loadout", {})
	if typeof(loadout) != TYPE_DICTIONARY:
		return ""
	var stacks = loadout.get("item_stacks", {})
	if typeof(stacks) != TYPE_DICTIONARY:
		return ""
	var item_db = context.get("item_db_snapshot", {})
	if typeof(item_db) != TYPE_DICTIONARY:
		return ""

	for item_id in stacks.keys():
		if int(stacks.get(item_id, 0)) <= 0:
			continue
		var item_data = item_db.get(str(item_id), {})
		if typeof(item_data) != TYPE_DICTIONARY:
			continue
		if str(item_data.get("ammo_group", "")).strip_edges().to_lower() == wanted_group:
			return str(item_id)
	return ""


func get_enemy_ammo_damage_from_context(context: Dictionary, ammo_group: String) -> int:
	# Summary: Read the best ammo damage bonus from the enemy-held stack matching this ammo group.
	var ammo_item_id := get_enemy_ammo_item_id_for_group(context, ammo_group)
	if ammo_item_id == "":
		return 0
	var item_db = context.get("item_db_snapshot", {})
	if typeof(item_db) != TYPE_DICTIONARY:
		return 0
	var item_data = item_db.get(ammo_item_id, {})
	if typeof(item_data) != TYPE_DICTIONARY:
		return 0
	var stats = item_data.get("stats", {})
	if typeof(stats) == TYPE_DICTIONARY:
		return int(stats.get("ammo_damage", item_data.get("ammo_damage", 0)))
	return int(item_data.get("ammo_damage", 0))


func normalize_enemy_battle_item_id(item_id: String) -> String:
	# Summary: Keep older enemy meta aliases compatible with the current item database.
	var clean_id := item_id.strip_edges()
	match clean_id:
		"enemy_light_laser":
			return "e_basic_energy_pew_pew"
		"enemy_snap_missile":
			return "micro_torpedo_launcher"
		"enemy_rail_snap":
			return "railgun_mk1"
		"recovery_kit":
			return "repair_kit"
		_:
			return clean_id
	
	
	
	
func build_fire_primary_packet(context: Dictionary) -> Dictionary:
	# Summary: Builds an EventManager-ready packet_result for firing the selected primary energy weapon.
	if Globals.print_priority_3:
		print("BattleActionPacketBuilder.build_fire_primary_packet | Building primary fire packet.")

	# Duplicate the context so this builder can add packet fields without mutating the caller's dictionary.
	var build_context := context.duplicate(true)

	# Primary fire has a stable action id, even if Action_Manager did not provide one yet.
	if str(build_context.get("action_id", "")).strip_edges() == "":
		build_context["action_id"] = "fire_primary_weapon"

	# Read item data early so we can use item table fallbacks before common validation runs.
	var item_data = build_context.get("item_data", {})

	# If duration was not passed by context, allow common weapon timing keys from item_data.
	if typeof(item_data) == TYPE_DICTIONARY:
		if not build_context.has("duration") or float(build_context.get("duration", 0.0)) <= 0.0:
			var item_duration := get_item_number(item_data, "duration", 0.0)

			if item_duration <= 0.0:
				item_duration = get_item_number(item_data, "fire_time", 0.0)

			if item_duration <= 0.0:
				item_duration = get_item_number(item_data, "cooldown", 0.0)

			build_context["duration"] = item_duration

	# Validate shared build requirements before creating the final packet shell.
	var validation_result := validate_common_context(build_context, true, true)

	if validation_result.get("status", "") != "valid":
		return validation_result

	# Pull the now-validated item data dictionary from context.
	item_data = build_context.get("item_data", {})

	# Primary weapon packets require a stable item id for same-type stacking and resolution routing.
	var item_id := get_item_id(item_data)

	if item_id == "":
		return make_rejected_result("missing primary weapon item_id", ["packet_build_rejected"])

	# Read packet values only; spending energy and resolving damage belong to other battle systems.
	var damage_value := get_item_number(item_data, "damage_value", get_item_number(item_data, "damage", 0.0))
	var energy_cost := get_item_number(item_data, "energy_cost", 0.0)
	var weapon_group := str(item_data.get("weapon_group", item_data.get("group", "primary"))).strip_edges()

	# Fill primary weapon packet fields required by the EventManager/BattleManager pipeline.
	build_context["same_type_key"] = "fire_primary_" + item_id
	build_context["requires_lock"] = true
	build_context["is_state_change"] = false
	build_context["is_damage_event"] = true
	build_context["is_effect_event"] = false
	build_context["is_visual_only"] = false
	build_context["item_id"] = item_id
	build_context["damage_type"] = "energy"
	build_context["damage_value"] = damage_value
	build_context["data"] = {
		"weapon_slot": "primary",
		"item_id": item_id,
		"energy_cost": energy_cost,
		"damage_value": damage_value,
		"weapon_group": weapon_group
	}

	# Build the shared event shell, then return it inside the standard built packet_result wrapper.
	var event_packet := build_base_event_packet(build_context, "fire_primary_weapon", "weapon")

	return make_built_result(event_packet, ["action_to_event_packet", "packet_builder_event_ownership_fields"])
	
	
	
	
func build_fire_secondary_packet(context: Dictionary) -> Dictionary:
	# Summary: Builds an EventManager-ready packet_result for firing the selected secondary kinetic weapon.
	if Globals.print_priority_3:
		print("BattleActionPacketBuilder.build_fire_secondary_packet | Building secondary fire packet.")

	# Duplicate the context so this builder can add packet fields without mutating the caller's dictionary.
	var build_context := context.duplicate(true)

	# Secondary fire has a stable action id, even if Action_Manager did not provide one yet.
	if str(build_context.get("action_id", "")).strip_edges() == "":
		build_context["action_id"] = "fire_secondary_weapon"

	# Read item data early so item timing can provide a duration fallback before validation runs.
	var item_data = build_context.get("item_data", {})

	# If duration was not passed by context, allow common weapon timing keys from item_data.
	if typeof(item_data) == TYPE_DICTIONARY:
		if not build_context.has("duration") or float(build_context.get("duration", 0.0)) <= 0.0:
			var item_duration := get_item_number(item_data, "duration", 0.0)

			if item_duration <= 0.0:
				item_duration = get_item_number(item_data, "fire_time", 0.0)

			if item_duration <= 0.0:
				item_duration = get_item_number(item_data, "cooldown", 0.0)

			build_context["duration"] = item_duration

	# Validate shared build requirements before creating the final packet shell.
	var validation_result := validate_common_context(build_context, true, true)

	if validation_result.get("status", "") != "valid":
		return validation_result

	# Pull the now-validated item data dictionary from context.
	item_data = build_context.get("item_data", {})

	# Secondary weapon packets require a stable item id for same-type stacking and resolution routing.
	var item_id := get_item_id(item_data)

	if item_id == "":
		return make_rejected_result("missing secondary weapon item_id", ["packet_build_rejected"])

	# Read packet values only; ammo spending and damage resolution belong to AmmoHandler/Inventory/BattleManager later.
	var weapon_damage := get_item_number(item_data, "damage_value", get_item_number(item_data, "damage", 0.0))
	var ammo_group := str(item_data.get("ammo_group", item_data.get("weapon_group", item_data.get("group", "secondary")))).strip_edges()
	var weapon_group := str(item_data.get("weapon_group", item_data.get("group", "secondary"))).strip_edges()
	var damage_type := str(item_data.get("damage_type", "kinetic")).strip_edges()
	if damage_type == "":
		damage_type = "kinetic"
	var ammo_per_burst := int(get_item_number(item_data, "ammo_per_burst", get_item_number(item_data, "ammo_cost", 1.0)))
	var burst_count := int(get_item_number(item_data, "burst_count", 1.0))
	var total_ammo_cost = max(ammo_per_burst * max(burst_count, 1), 0)
	var ammo_damage := int(get_item_number(item_data, "ammo_damage", 0.0))
	var total_damage := weapon_damage
	var explosive_pass_percent := get_item_number(item_data, "explosive_pass_percent", 0.0)

	var ammo_handler = build_context.get("ammo_handler", null)
	var inventory_ref = build_context.get("inventory_ref", null)
	if ammo_handler != null and ammo_handler.has_method("build_ammo_damage_packet"):
		var ammo_packet = ammo_handler.build_ammo_damage_packet(item_data, inventory_ref)
		if typeof(ammo_packet) == TYPE_DICTIONARY:
			ammo_group = str(ammo_packet.get("ammo_group", ammo_group))
			ammo_per_burst = int(ammo_packet.get("ammo_per_burst", ammo_per_burst))
			burst_count = int(ammo_packet.get("burst_count", burst_count))
			total_ammo_cost = int(ammo_packet.get("total_ammo_cost", total_ammo_cost))
			weapon_damage = float(ammo_packet.get("weapon_damage", weapon_damage))
			ammo_damage = int(ammo_packet.get("ammo_damage", ammo_damage))
			total_damage = float(ammo_packet.get("total_damage", total_damage))
	else:
		total_damage = (weapon_damage + ammo_damage) * max(burst_count, 1)

	var normalized_burst_count: int = max(burst_count, 1)
	var normalized_ammo_per_burst: int = max(ammo_per_burst, 0)
	var normalized_total_ammo_cost: int = max(normalized_ammo_per_burst * normalized_burst_count, 0)
	var damage_per_burst := float(weapon_damage + ammo_damage)
	if damage_per_burst <= 0.0 and total_damage > 0.0:
		damage_per_burst = float(total_damage) / float(normalized_burst_count)
	var normalized_total_damage := damage_per_burst * float(normalized_burst_count)
	var display_name := str(item_data.get("display_name", item_data.get("name", item_id))).strip_edges()
	if display_name == "":
		display_name = item_id

	# Fill secondary weapon packet fields required by the EventManager/BattleManager pipeline.
	build_context["same_type_key"] = "fire_secondary_" + item_id
	build_context["requires_lock"] = true
	build_context["is_state_change"] = false
	build_context["is_damage_event"] = true
	build_context["is_effect_event"] = false
	build_context["is_visual_only"] = false
	build_context["item_id"] = item_id
	build_context["display_name"] = display_name
	build_context["damage_type"] = damage_type
	build_context["damage_value"] = normalized_total_damage
	build_context["data"] = {
		"weapon_slot": "secondary",
		"item_id": item_id,
		"display_name": display_name,
		"ammo_group": ammo_group,
		"ammo_per_burst": normalized_ammo_per_burst,
		"burst_count": normalized_burst_count,
		"ammo_cost": normalized_total_ammo_cost,
		"total_ammo_cost": normalized_total_ammo_cost,
		"reserve_total_ammo_cost": normalized_total_ammo_cost,
		"weapon_damage": weapon_damage,
		"ammo_damage": ammo_damage,
		"damage_per_burst": damage_per_burst,
		"damage_value": normalized_total_damage,
		"total_damage": normalized_total_damage,
		"weapon_group": weapon_group,
		"damage_type": damage_type,
		"explosive_pass_percent": explosive_pass_percent
	}

	if normalized_burst_count > 1:
		var burst_packets: Array = []

		for burst_index in range(normalized_burst_count):
			var burst_context := build_context.duplicate(true)
			burst_context["damage_value"] = damage_per_burst

			var burst_data: Dictionary = build_context["data"].duplicate(true)
			burst_data["burst_index"] = burst_index + 1
			burst_data["burst_total"] = normalized_burst_count
			burst_data["original_burst_count"] = normalized_burst_count
			burst_data["is_burst_todo"] = true
			burst_data["burst_stack_rule"] = "one_todo_per_burst_same_type_key"
			burst_data["burst_total_ammo_cost"] = normalized_total_ammo_cost
			burst_data["burst_total_damage"] = normalized_total_damage
			burst_data["burst_count"] = 1
			burst_data["ammo_cost"] = normalized_ammo_per_burst
			burst_data["total_ammo_cost"] = normalized_ammo_per_burst
			burst_data["reserve_total_ammo_cost"] = normalized_ammo_per_burst
			burst_data["damage_value"] = damage_per_burst
			burst_data["total_damage"] = damage_per_burst
			burst_data["todo_display_name"] = display_name + " " + str(burst_index + 1) + "/" + str(normalized_burst_count)
			burst_context["data"] = burst_data

			var burst_packet := build_base_event_packet(burst_context, "fire_secondary_weapon", "weapon")
			burst_packets.append(burst_packet)

		if Globals.print_priority_2:
			print(
				"[secondary_burst_packets_built]",
				" item=", item_id,
				" count=", burst_packets.size(),
				" duration_each=", float(build_context.get("duration", 0.0)),
				" same_type_key=", build_context.get("same_type_key", "")
			)

		return make_built_multi_result(
			burst_packets,
			[
				"action_to_event_packet",
				"packet_builder_event_ownership_fields",
				"secondary_burst_expanded_to_todos"
			]
		)

	# Build the shared event shell, then return it inside the standard built packet_result wrapper.
	var event_packet := build_base_event_packet(build_context, "fire_secondary_weapon", "weapon")

	return make_built_result(event_packet, ["action_to_event_packet", "packet_builder_event_ownership_fields"])
	
	
	
	
func build_load_consumable_packet(context: Dictionary) -> Dictionary:
	# Summary: Builds an EventManager-ready packet_result for loading/prepping a selected consumable.
	if Globals.print_priority_3:
		print("BattleActionPacketBuilder.build_load_consumable_packet | Building load consumable packet.")

	# Duplicate the context so this builder can add packet fields without mutating the caller's dictionary.
	var build_context := context.duplicate(true)

	# Loading a consumable has a stable action id, even if Action_Manager did not provide one yet.
	if str(build_context.get("action_id", "")).strip_edges() == "":
		build_context["action_id"] = "load_consumable"

	# Read item data early so consumable timing can provide a duration fallback before validation runs.
	var item_data = build_context.get("item_data", {})

	# If duration was not passed by context, allow common consumable prep timing keys from item_data.
	if typeof(item_data) == TYPE_DICTIONARY:
		if not build_context.has("duration") or float(build_context.get("duration", 0.0)) <= 0.0:
			var item_duration := get_item_number(item_data, "prep_time", 0.0)

			if item_duration <= 0.0:
				item_duration = get_item_number(item_data, "load_time", 0.0)

			if item_duration <= 0.0:
				item_duration = get_item_number(item_data, "duration", 0.0)

			build_context["duration"] = item_duration

	# Loading/prepping does not need an enemy target, but it does require item data.
	var validation_result := validate_common_context(build_context, false, true)

	if validation_result.get("status", "") != "valid":
		return validation_result

	# Pull the now-validated item data dictionary from context.
	item_data = build_context.get("item_data", {})

	# Consumable load packets require a stable item id so the ready/execute flow can identify the loaded item.
	var item_id := get_item_id(item_data)

	if item_id == "":
		return make_rejected_result("missing consumable item_id", ["packet_build_rejected"])

	# Read consumable group only; spending inventory belongs to the execute/completion flow later.
	var consumable_group := str(item_data.get("consumable_group", item_data.get("group", "consumable"))).strip_edges()
	var prep_time := float(build_context.get("duration", 0.0))

	# Fill load consumable packet fields required by the EventManager/BattleManager pipeline.
	build_context["same_type_key"] = "load_" + item_id
	build_context["event_subtype"] = "load_consumable_complete"
	build_context["requires_lock"] = false
	build_context["is_state_change"] = true
	build_context["is_damage_event"] = false
	build_context["is_effect_event"] = false
	build_context["is_visual_only"] = false
	build_context["item_id"] = item_id
	build_context["damage_type"] = ""
	build_context["damage_value"] = 0
	build_context["target_unit"] = build_context.get("target_unit", build_context.get("source_unit", null))
	build_context["data"] = {
		"consumable_id": item_id,
		"consumable_group": consumable_group,
		"prep_time": prep_time,
		"reserved_consumable": true,
		"item_data": item_data
	}

	# Build the shared event shell, then return it inside the standard built packet_result wrapper.
	var event_packet := build_base_event_packet(build_context, "load_consumable", "consumable")

	return make_built_result(event_packet, ["action_to_event_packet", "packet_builder_event_ownership_fields"])
	
	
	
func build_execute_consumable_packet(context: Dictionary) -> Dictionary:
	# Summary: Builds an EventManager-ready packet_result for executing a loaded or selected consumable.
	if Globals.print_priority_3:
		print("BattleActionPacketBuilder.build_execute_consumable_packet | Building execute consumable packet.")

	# Duplicate the context so this builder can add packet fields without mutating the caller's dictionary.
	var build_context := context.duplicate(true)

	# Execute consumable has a general action id until the consumable group selects the final event type.
	if str(build_context.get("action_id", "")).strip_edges() == "":
		build_context["action_id"] = "execute_consumable"

	# Read item data early so group, timing, and packet payload can be prepared before validation.
	var item_data = build_context.get("item_data", {})

	# Item data must be a dictionary because execute behavior depends on consumable group fields.
	if typeof(item_data) != TYPE_DICTIONARY or item_data.is_empty():
		return make_rejected_result("missing consumable item_data", ["packet_build_rejected"])

	# Consumable execution requires a stable item id for stack control and completion routing.
	var item_id := get_item_id(item_data)

	if item_id == "":
		return make_rejected_result("missing execute consumable item_id", ["packet_build_rejected"])

	# Consumable group decides the final event type, lock requirement, and routing flags.
	var consumable_group := str(item_data.get("consumable_group", item_data.get("group", ""))).strip_edges().to_lower()

	if consumable_group == "":
		return make_rejected_result("missing consumable_group", ["packet_build_rejected"])

	# If duration was not passed by context, allow common execute timing keys from item_data.
	if not build_context.has("duration") or float(build_context.get("duration", 0.0)) <= 0.0:
		var item_duration := get_item_number(item_data, "execute_time", 0.0)

		if item_duration <= 0.0:
			item_duration = get_item_number(item_data, "duration", 0.0)

		if item_duration <= 0.0:
			item_duration = get_item_number(item_data, "cooldown", 0.0)

		build_context["duration"] = item_duration

	# Most execute actions target the active enemy; drone/support actions may self-target later.
	var needs_target := true

	if consumable_group == "repair" or consumable_group == "recharge":
		build_context["target_unit"] = build_context.get("owner_unit", build_context.get("source_unit", null))

	if consumable_group == "drone":
		needs_target = false

	# Validate shared build requirements after group and duration fallbacks are prepared.
	var validation_result := validate_common_context(build_context, needs_target, true)

	if validation_result.get("status", "") != "valid":
		return validation_result

	# Default packet fields are set to safe non-damage values before group-specific rules turn them on.
	var event_type := "execute_consumable"
	var event_group := "consumable"
	var requires_lock := false
	var is_damage_event := false
	var is_effect_event := true
	var damage_type := ""
	var damage_value := 0.0
	var same_type_key := "execute_" + item_id
	var data_payload := {
		"consumable_id": item_id,
		"consumable_group": consumable_group,
		"effect_data": item_data.get("effect_data", {})
	}

	# Explosives are damage events and require lock, but BattleManager still owns the final lock check.
	if consumable_group == "explosive":
		event_type = "execute_explosive"
		event_group = "explosive"
		requires_lock = true
		is_damage_event = true
		is_effect_event = false
		damage_type = "explosive"
		damage_value = get_explosive_damage_value(item_data)
		same_type_key = "execute_explosive_" + item_id
		data_payload["damage_value"] = damage_value
		data_payload["explosive_damage"] = damage_value
		data_payload["explosive_pass_percent"] = get_item_number(item_data, "explosive_pass_percent", 0.0)

	# Repair kits are support effects. BattleManager applies hull repair after the execute TODO completes.
	elif consumable_group == "repair":
		event_type = "execute_repair"
		event_group = "repair"
		requires_lock = false
		is_damage_event = false
		is_effect_event = true
		same_type_key = "execute_repair_" + item_id
		var heal_amount := get_item_number(item_data, "heal_amount", get_item_number(item_data, "repair_amount", get_item_number(item_data, "hull_restore_amount", 0.0)))
		data_payload["heal_amount"] = heal_amount
		data_payload["repair_amount"] = heal_amount
		data_payload["hull_restore_amount"] = heal_amount
		data_payload["display_name"] = str(item_data.get("display_name", item_data.get("name", item_id))).strip_edges()

	# Shield repair is valid only while the equipped shield still has positive HP.
	elif consumable_group == "shield_repair":
		event_type = "execute_shield_repair"
		event_group = "shield_repair"
		requires_lock = false
		is_damage_event = false
		is_effect_event = true
		same_type_key = "execute_shield_repair_" + item_id
		var shield_repair_amount := get_item_number(item_data, "shield_repair_amount", get_item_number(item_data, "repair_amount", 0.0))
		data_payload["shield_repair_amount"] = shield_repair_amount
		data_payload["repair_amount"] = shield_repair_amount
		data_payload["requires_equipped_shield"] = bool(item_data.get("requires_equipped_shield", true))
		data_payload["requires_unbroken_shield"] = bool(item_data.get("requires_unbroken_shield", true))
		data_payload["display_name"] = str(item_data.get("display_name", item_data.get("name", item_id))).strip_edges()
		data_payload["item_data"] = item_data

	# Recharge kits are support effects. EnergyHandler owns the actual energy restore.
	elif consumable_group == "recharge":
		event_type = "execute_recharge"
		event_group = "recharge"
		requires_lock = false
		is_damage_event = false
		is_effect_event = true
		same_type_key = "execute_recharge_" + item_id
		var energy_restore_amount := get_item_number(item_data, "energy_restore_amount", get_item_number(item_data, "recharge_amount", 0.0))
		data_payload["energy_restore_amount"] = energy_restore_amount
		data_payload["recharge_amount"] = energy_restore_amount
		data_payload["recharge_to_full"] = bool(item_data.get("recharge_to_full", true))
		data_payload["display_name"] = str(item_data.get("display_name", item_data.get("name", item_id))).strip_edges()

	# Signals are effect events and do not require lock; BattleManager/StatEffectHandler resolve success later.
	elif consumable_group == "signal":
		event_type = "execute_signal"
		event_group = "signal"
		requires_lock = false
		is_damage_event = false
		is_effect_event = true
		same_type_key = "execute_signal_" + item_id
		var signal_duration := get_item_number(item_data, "effect_duration", get_item_number(item_data, "duration", float(build_context.get("duration", 5.0))))
		data_payload["signal_type"] = str(item_data.get("signal_type", item_data.get("effect_type", ""))).strip_edges()
		data_payload["signal_strength"] = get_item_number(item_data, "signal_strength", 0.0)
		data_payload["duration"] = signal_duration
		data_payload["disabled_lane"] = str(item_data.get("disabled_lane", data_payload["signal_type"])).strip_edges()
		data_payload["affects"] = item_data.get("affects", ["weapon"])
		data_payload["stack_rule"] = str(item_data.get("stack_rule", "unique")).strip_edges()
		data_payload["priority"] = int(item_data.get("priority", 80))
		data_payload["flags"] = item_data.get("flags", {})
		data_payload["visual_labels"] = item_data.get("visual_labels", ["signal_success_apply_disable"])
		data_payload["effect_packet_template"] = item_data.get("effect_packet_template", {})

	# Drones are effect events and may self-target because deployment belongs to the player side.
	elif consumable_group == "drone":
		event_type = "deploy_drone"
		event_group = "drone"
		requires_lock = false
		is_damage_event = false
		is_effect_event = true
		same_type_key = "deploy_drone_" + item_id
		build_context["target_unit"] = build_context.get("owner_unit", build_context.get("source_unit", null))
		var drone_duration := get_item_number(item_data, "effect_duration", get_item_number(item_data, "duration", float(build_context.get("duration", 0.0))))
		data_payload["drone_type"] = str(item_data.get("drone_type", "")).strip_edges()
		data_payload["drone_group"] = str(item_data.get("drone_group", item_data.get("subgroup", ""))).strip_edges()
		data_payload["applies_effect"] = bool(item_data.get("applies_effect", false))
		data_payload["drone_auto_attack"] = bool(item_data.get("drone_auto_attack", data_payload["drone_type"] == "auto_attack"))
		data_payload["drone_damage_type"] = str(item_data.get("drone_damage_type", "hull")).strip_edges()
		data_payload["drone_damage_value"] = get_item_number(item_data, "drone_damage_value", 1.0)
		data_payload["drone_fire_interval"] = get_item_number(item_data, "drone_fire_interval", 0.2)
		data_payload["drone_fire_count"] = int(max(get_item_number(item_data, "drone_fire_count", get_item_number(item_data, "drone_max_shots", get_item_number(item_data, "drone_shot_count", 0.0))), 0.0))
		data_payload["drone_hull_current"] = get_item_number(item_data, "drone_hull_current", get_item_number(item_data, "drone_hull_max", 50.0))
		data_payload["drone_hull_max"] = get_item_number(item_data, "drone_hull_max", 50.0)
		data_payload["drone_shield_active"] = bool(item_data.get("drone_shield_active", false))
		data_payload["effect_id"] = str(item_data.get("effect_id", item_id)).strip_edges()
		data_payload["effect_type"] = str(item_data.get("effect_type", "protection")).strip_edges()
		data_payload["stack_rule"] = str(item_data.get("stack_rule", "replace")).strip_edges()
		data_payload["priority"] = int(item_data.get("priority", 60))
		data_payload["affects"] = item_data.get("affects", [])
		data_payload["values"] = item_data.get("values", {})
		data_payload["flags"] = item_data.get("flags", {})
		data_payload["visual_labels"] = item_data.get("visual_labels", [])
		data_payload["visual_labels_on_expire"] = item_data.get("visual_labels_on_expire", [])
		data_payload["effect_packet_template"] = item_data.get("effect_packet_template", {})
		data_payload["duration"] = drone_duration

	# Pulses are effect events and do not require lock; pulse behavior resolves after TODO completion.
	elif consumable_group == "pulse":
		event_type = "execute_pulse"
		event_group = "pulse"
		requires_lock = false
		is_damage_event = false
		is_effect_event = true
		same_type_key = "execute_pulse_" + item_id
		data_payload["pulse_pattern"] = str(item_data.get("pulse_pattern", item_data.get("pattern", ""))).strip_edges()
		data_payload["pulse_duration"] = get_item_number(item_data, "pulse_duration", float(build_context.get("duration", 0.0)))
		data_payload["pulse_tick_rate"] = get_item_number(item_data, "pulse_tick_rate", 0.0)
		data_payload["effect_packet_template"] = item_data.get("effect_packet_template", {})

	# Override is intentionally rejected for now because the guide marks it as placeholder only.
	elif consumable_group == "override":
		return make_rejected_result("override consumable execution is placeholder only", ["packet_build_rejected"])

	# Unknown consumable groups are rejected so invalid item data does not create vague TODO packets.
	else:
		return make_rejected_result("unknown consumable_group: " + consumable_group, ["packet_build_rejected"])

	# Fill execute consumable packet fields required by the EventManager/BattleManager pipeline.
	build_context["same_type_key"] = same_type_key
	build_context["requires_lock"] = requires_lock
	build_context["is_state_change"] = false
	build_context["is_damage_event"] = is_damage_event
	build_context["is_effect_event"] = is_effect_event
	build_context["is_visual_only"] = false
	build_context["item_id"] = item_id
	build_context["damage_type"] = damage_type
	build_context["damage_value"] = damage_value
	build_context["data"] = data_payload

	# Build the shared event shell, then return it inside the standard built packet_result wrapper.
	var event_packet := build_base_event_packet(build_context, event_type, event_group)

	return make_built_result(event_packet, ["action_to_event_packet", "packet_builder_event_ownership_fields"])
	
	
	
	
func build_evade_packet(context: Dictionary) -> Dictionary:
	# Summary: Builds an EventManager-ready packet_result for the player evade battle action.
	if Globals.print_priority_3:
		print("BattleActionPacketBuilder.build_evade_packet | Building evade packet.")

	# Duplicate the context so this builder can add packet fields without mutating the caller's dictionary.
	var build_context := context.duplicate(true)

	# Evade has a stable action id, even if Action_Manager did not provide one yet.
	if str(build_context.get("action_id", "")).strip_edges() == "":
		build_context["action_id"] = "player_evade"

	# If duration was not passed by context, allow common evade timing keys from extra_data or context fallback fields.
	if not build_context.has("duration") or float(build_context.get("duration", 0.0)) <= 0.0:
		var extra_data = build_context.get("extra_data", {})
		var evade_duration := 0.0

		if typeof(extra_data) == TYPE_DICTIONARY:
			evade_duration = float(extra_data.get("evade_duration", 0.0))

		if evade_duration <= 0.0:
			evade_duration = float(build_context.get("evade_duration", 0.0))

		build_context["duration"] = evade_duration

	# Evade can target the active enemy for battle context, but it does not require lock or enemy damage resolution.
	var validation_result := validate_common_context(build_context, true, false)

	if validation_result.get("status", "") != "valid":
		return validation_result

	# Record evade duration in the payload for BattleManager to interpret when the TODO completes.
	var evade_duration_value := float(build_context.get("duration", 0.0))
	var evade_extra_data = build_context.get("extra_data", {})
	var evade_energy_cost := float(build_context.get("energy_cost", 0.0))
	var pipeline_disrupt_seconds := evade_duration_value
	if typeof(evade_extra_data) == TYPE_DICTIONARY:
		evade_energy_cost = float(evade_extra_data.get("energy_cost", evade_energy_cost))
		pipeline_disrupt_seconds = float(evade_extra_data.get("evade_pipeline_disrupt_seconds", pipeline_disrupt_seconds))

	# Fill evade packet fields required by the EventManager/BattleManager pipeline.
	build_context["same_type_key"] = "player_evade"
	build_context["event_subtype"] = "evade_complete"
	build_context["requires_lock"] = false
	build_context["is_state_change"] = true
	build_context["is_damage_event"] = false
	build_context["is_effect_event"] = false
	build_context["is_visual_only"] = false
	build_context["item_id"] = ""
	build_context["damage_type"] = ""
	build_context["damage_value"] = 0
	build_context["data"] = {
		"evade_duration": evade_duration_value,
		"evade_cooldown_seconds": float(build_context.get("evade_cooldown_seconds", 0.0)),
		"evade_lock_reacquire_penalty_seconds": float(build_context.get("evade_lock_reacquire_penalty_seconds", 0.0)),
		"evade_pipeline_disrupt_seconds": pipeline_disrupt_seconds,
		"energy_cost": max(evade_energy_cost, 0.0),
		"effect": "both_sides_lock_loss",
		"labels": [
			"evade_resolution_rule",
			"evade_todo_started"
		]
	}

	# Build the shared event shell, then return it inside the standard built packet_result wrapper.
	var event_packet := build_base_event_packet(build_context, "player_evade", "evade")

	return make_built_result(event_packet, ["action_to_event_packet", "packet_builder_event_ownership_fields"])
	
	
	
	
func build_enemy_action_packet(context: Dictionary) -> Dictionary:
	# Summary: Choose or receive an enemy intent, then build an EventManager-ready packet_result from it.
	if Globals.print_priority_3:
		print("BattleActionPacketBuilder.build_enemy_action_packet | Building enemy action packet.")

	# Duplicate the context so this builder can add packet fields without mutating the caller's dictionary.
	var build_context := context.duplicate(true)
	var intent_packet: Dictionary = {}
	var intent_chosen_by_logic := false

	# ------------------------------------------------------
	# If the caller provides EnemyLogic, this builder owns the
	# bridge from behavior choice to EventManager packet.
	# ------------------------------------------------------
	var enemy_logic = build_context.get("enemy_logic", null)
	if enemy_logic != null and enemy_logic.has_method("choose_enemy_intent"):

		var update_package: Dictionary = {}

		# Prefer the richer live state snapshot from battle_v2_scene / future EnemyBattleController.
		if typeof(build_context.get("enemy_update_package", {})) == TYPE_DICTIONARY:
			update_package = build_context.get("enemy_update_package", {}).duplicate(true)

		# Fill required fallback values so old callers still work.
		update_package["enemy"] = update_package.get(
			"enemy",
			build_context.get("enemy", build_context.get("source_unit", build_context.get("owner_unit", null)))
		)

		update_package["player_state"] = update_package.get(
			"player_state",
			build_context.get("player_state", build_context.get("target_unit", null))
		)

		update_package["battle_id"] = update_package.get("battle_id", build_context.get("battle_id", ""))
		update_package["battle_active"] = update_package.get("battle_active", build_context.get("battle_active", true))
		update_package["battle_ended"] = update_package.get("battle_ended", build_context.get("battle_ended", false))
		update_package["battle_v2_ended"] = update_package.get("battle_v2_ended", build_context.get("battle_v2_ended", false))
		update_package["battle_manager"] = update_package.get("battle_manager", build_context.get("battle_manager", null))
		update_package["event_manager"] = update_package.get("event_manager", build_context.get("event_manager", null))

		var chosen_intent = enemy_logic.choose_enemy_intent(update_package)
		if typeof(chosen_intent) != TYPE_DICTIONARY:
			return make_rejected_result("EnemyLogic returned invalid intent packet", ["packet_build_rejected", "enemy_logic_invalid_intent"])
		intent_packet = chosen_intent
		intent_chosen_by_logic = true
	elif typeof(build_context.get("enemy_intent_packet", {})) == TYPE_DICTIONARY:
		intent_packet = build_context.get("enemy_intent_packet", {})

	# Merge a selected intent packet into the packet-builder context.
	if not intent_packet.is_empty():
		if str(intent_packet.get("status", "selected")) == "none":
			return make_rejected_result(
				"enemy intent produced no action: " + str(intent_packet.get("reason", "unknown")),
				["packet_build_rejected", "enemy_logic_intent_none"]
			)

		build_context["enemy_intent"] = str(intent_packet.get("intent_id", build_context.get("enemy_intent", "")))
		build_context["source_unit"] = intent_packet.get("source_unit", build_context.get("source_unit", null))
		build_context["target_unit"] = intent_packet.get("target_unit", build_context.get("target_unit", null))
		build_context["owner_unit"] = intent_packet.get("owner_unit", build_context.get("owner_unit", null))
		build_context["event_side"] = str(intent_packet.get("event_side", build_context.get("event_side", "enemy")))
		build_context["intent_reason"] = str(intent_packet.get("reason", ""))
		build_context["intent_priority"] = int(intent_packet.get("priority", 0))

		var merged_intent_data := {}
		if typeof(build_context.get("intent_data", {})) == TYPE_DICTIONARY:
			merged_intent_data = build_context.get("intent_data", {}).duplicate(true)
		if typeof(build_context.get("extra_data", {})) == TYPE_DICTIONARY:
			for extra_key in build_context.get("extra_data", {}).keys():
				merged_intent_data[extra_key] = build_context.get("extra_data", {}).get(extra_key)
		if typeof(intent_packet.get("data", {})) == TYPE_DICTIONARY:
			for data_key in intent_packet.get("data", {}).keys():
				merged_intent_data[data_key] = intent_packet.get("data", {}).get(data_key)
		build_context["intent_data"] = merged_intent_data

	# Enemy action packets can be based on a chosen intent or on an explicit caller-provided enemy_intent.
	var enemy_intent := str(build_context.get("enemy_intent", build_context.get("current_intent", build_context.get("action_id", "")))).strip_edges().to_lower()
	if enemy_intent == "":
		return make_rejected_result("missing enemy_intent", ["packet_build_rejected"])

	if enemy_intent == "enemy_evade":
		var forced_evade_duration := float(build_context.get("evade_duration", 0.0))
		if forced_evade_duration <= 0.0 and typeof(build_context.get("intent_data", {})) == TYPE_DICTIONARY:
			forced_evade_duration = float(build_context.get("intent_data", {}).get("evade_duration", 0.0))
		if forced_evade_duration > 0.0:
			build_context["duration"] = forced_evade_duration

	# Waiting is a valid behavior choice, but it does not need an EventManager TODO yet.
	if enemy_intent == "enemy_wait" or enemy_intent == "enemy_none":
		return make_rejected_result("enemy intent does not queue a TODO: " + enemy_intent, ["enemy_wait_no_event"])

	# Fill default source/owner/target references from the context aliases used by EnemyLogic.
	if build_context.get("source_unit", null) == null:
		build_context["source_unit"] = build_context.get("enemy", null)
	if build_context.get("owner_unit", null) == null:
		build_context["owner_unit"] = build_context.get("source_unit", null)
	if build_context.get("target_unit", null) == null:
		build_context["target_unit"] = build_context.get("player_state", null)

	if enemy_intent == "enemy_remove_shield" or enemy_intent == "enemy_clear_loaded_consumable":
		build_context["target_unit"] = build_context.get("owner_unit", build_context.get("source_unit", null))
		if not build_context.has("duration") or float(build_context.get("duration", 0.0)) <= 0.0:
			build_context["duration"] = 0.5

	# Enemy actions default to enemy ownership, but the caller can still provide exact objects in the context.
	build_context["event_side"] = str(build_context.get("event_side", "enemy")).strip_edges()

	if build_context["event_side"] == "":
		build_context["event_side"] = "enemy"

	var selected_enemy_item_data := get_enemy_loadout_item_data(build_context, enemy_intent)
	if not selected_enemy_item_data.is_empty():
		build_context["item_data"] = selected_enemy_item_data
		if str(build_context.get("item_id", "")).strip_edges() == "":
			build_context["item_id"] = get_item_id(selected_enemy_item_data)
		if str(build_context.get("display_name", "")).strip_edges() == "":
			build_context["display_name"] = str(selected_enemy_item_data.get("display_name", selected_enemy_item_data.get("name", build_context.get("item_id", ""))))

	# Use the chosen intent as the fallback action id so the packet remains traceable after queuing.
	if str(build_context.get("action_id", "")).strip_edges() == "":
		build_context["action_id"] = enemy_intent

	# If duration was not passed by context, allow intent_data or extra_data to provide timing.
	if not build_context.has("duration") or float(build_context.get("duration", 0.0)) <= 0.0:
		var intent_data = build_context.get("intent_data", build_context.get("extra_data", {}))
		var intent_duration := 0.0

		if typeof(intent_data) == TYPE_DICTIONARY:
			intent_duration = float(intent_data.get("duration", intent_data.get("intent_duration", 0.0)))

		if intent_duration <= 0.0:
			if enemy_intent == "enemy_reacquire_lock":
				intent_duration = 1.5
			elif enemy_intent == "enemy_attack_primary" or enemy_intent == "enemy_primary_attack" or enemy_intent == "enemy_attack":
				intent_duration = 2.0
			elif enemy_intent == "enemy_attack_secondary" or enemy_intent == "enemy_secondary_attack":
				intent_duration = 3.0
			elif enemy_intent == "enemy_signal" or enemy_intent == "enemy_signal_disable_lock":
				intent_duration = 2.5
			elif enemy_intent == "enemy_evade":
				intent_duration = float(build_context.get("evade_duration", 5.0))
			elif enemy_intent == "enemy_remove_shield":
				intent_duration = 0.5
			elif enemy_intent == "enemy_clear_loaded_consumable":
				intent_duration = 0.5
			else:
				intent_duration = 1.0

		intent_duration = get_enemy_item_duration(selected_enemy_item_data, enemy_intent, intent_duration)
		build_context["duration"] = intent_duration

	# Enemy action packets need a source enemy, owner enemy, side, target player, action id, and valid duration.
	var validation_result := validate_common_context(build_context, true, false)

	if validation_result.get("status", "") != "valid":
		return validation_result

	# Default enemy packet values are safe effect/state values until the intent branch defines the packet type.
	var event_type := enemy_intent
	var event_group := "enemy"
	var requires_lock := false
	var is_state_change := false
	var is_damage_event := false
	var is_effect_event := false
	var damage_type := ""
	var damage_value := 0.0
	var energy_cost := 0.0
	var event_item_id := get_item_id(selected_enemy_item_data)
	var intent_data_for_cost := {}
	if typeof(build_context.get("intent_data", {})) == TYPE_DICTIONARY:
		intent_data_for_cost = build_context.get("intent_data", {})
		var slot_for_intent := get_enemy_slot_for_intent(enemy_intent)
		var slot_item_key := slot_for_intent + "_item_id"
		var intent_slot_item_id := normalize_enemy_battle_item_id(str(intent_data_for_cost.get(slot_item_key, "")).strip_edges())
		if intent_slot_item_id != "":
			event_item_id = intent_slot_item_id
		elif str(intent_data_for_cost.get("item_id", "")).strip_edges() != "" and event_item_id == "":
			event_item_id = normalize_enemy_battle_item_id(str(intent_data_for_cost.get("item_id", "")).strip_edges())
	if event_item_id == "":
		event_item_id = normalize_enemy_battle_item_id(str(build_context.get("item_id", "")).strip_edges())
	var event_display_name := str(build_context.get("display_name", event_item_id)).strip_edges()
	if event_display_name == "":
		event_display_name = event_type
	var same_type_key := enemy_intent
	var data_payload := {
		"enemy_intent": enemy_intent,
		"intent_reason": str(build_context.get("intent_reason", "")),
		"intent_priority": int(build_context.get("intent_priority", 0))
	}

	# Reacquire lock becomes a state-change TODO that restores the enemy lock when it completes.
	if enemy_intent == "enemy_reacquire_lock":
		event_type = "enemy_reacquire_lock"
		event_group = "lock"
		requires_lock = false
		is_state_change = true
		same_type_key = "enemy_reacquire_lock"
		build_context["event_subtype"] = "lock_restore"
		data_payload["lock_action"] = "restore"

	# Enemy attack intent becomes a lock-required damage event, but BattleManager still resolves hit and damage.
	elif enemy_intent == "enemy_attack" or enemy_intent == "enemy_primary_attack" or enemy_intent == "enemy_attack_primary":
		event_type = "enemy_primary_attack"
		event_group = "weapon"
		requires_lock = true
		is_damage_event = true
		damage_type = str(selected_enemy_item_data.get("damage_type", build_context.get("damage_type", "energy"))).strip_edges()
		damage_value = float(selected_enemy_item_data.get("damage_value", selected_enemy_item_data.get("damage", build_context.get("damage_value", 0.0))))
		if damage_value <= 0.0 and typeof(build_context.get("intent_data", {})) == TYPE_DICTIONARY:
			damage_value = float(build_context.get("intent_data", {}).get("damage_value", build_context.get("intent_data", {}).get("attack", 8.0)))
		if damage_value <= 0.0:
			damage_value = 8.0
		energy_cost = max(float(selected_enemy_item_data.get("energy_cost", 0.0)), 0.0)
		if typeof(intent_data_for_cost) == TYPE_DICTIONARY and str(intent_data_for_cost.get("item_id", "")).strip_edges() == event_item_id:
			energy_cost = max(float(intent_data_for_cost.get("energy_cost", energy_cost)), 0.0)
		same_type_key = "enemy_primary_attack"
		if event_item_id != "":
			same_type_key += "_" + event_item_id
		data_payload["weapon_slot"] = str(build_context.get("weapon_slot", "primary")).strip_edges()
		data_payload["item_id"] = event_item_id
		data_payload["weapon_id"] = event_item_id
		data_payload["display_name"] = event_display_name
		data_payload["energy_cost"] = energy_cost
		data_payload["damage_type"] = damage_type
		data_payload["damage_value"] = damage_value
		data_payload["weapon_group"] = str(selected_enemy_item_data.get("weapon_group", selected_enemy_item_data.get("group", "primary"))).strip_edges()
		data_payload["item_data"] = selected_enemy_item_data

	# Enemy secondary attack becomes a kinetic weapon event.
	elif enemy_intent == "enemy_secondary_attack" or enemy_intent == "enemy_attack_secondary":
		event_type = "enemy_secondary_attack"
		event_group = "weapon"
		requires_lock = true
		is_damage_event = true
		damage_type = str(selected_enemy_item_data.get("damage_type", build_context.get("damage_type", "kinetic"))).strip_edges()
		var weapon_damage := float(selected_enemy_item_data.get("damage_value", selected_enemy_item_data.get("damage", build_context.get("damage_value", 0.0))))
		var ammo_group := str(selected_enemy_item_data.get("ammo_group", selected_enemy_item_data.get("weapon_group", selected_enemy_item_data.get("group", "secondary")))).strip_edges()
		var ammo_per_burst := int(get_item_number(selected_enemy_item_data, "ammo_per_burst", get_item_number(selected_enemy_item_data, "ammo_cost", 1.0)))
		var burst_count := int(get_item_number(selected_enemy_item_data, "burst_count", 1.0))
		var total_ammo_cost = max(ammo_per_burst * max(burst_count, 1), 0)
		var ammo_damage := int(get_enemy_ammo_damage_from_context(build_context, ammo_group))
		damage_value = (weapon_damage + ammo_damage) * max(burst_count, 1)
		if damage_value <= 0.0 and typeof(build_context.get("intent_data", {})) == TYPE_DICTIONARY:
			damage_value = float(build_context.get("intent_data", {}).get("damage_value", build_context.get("intent_data", {}).get("attack", 6.0)))
		if damage_value <= 0.0:
			damage_value = 6.0
		energy_cost = max(float(selected_enemy_item_data.get("energy_cost", 0.0)), 0.0)
		if typeof(intent_data_for_cost) == TYPE_DICTIONARY and intent_data_for_cost.has("secondary_energy_cost"):
			energy_cost = max(float(intent_data_for_cost.get("secondary_energy_cost", energy_cost)), 0.0)
		same_type_key = "enemy_secondary_attack"
		if event_item_id != "":
			same_type_key += "_" + event_item_id
		data_payload["weapon_slot"] = str(build_context.get("weapon_slot", "secondary")).strip_edges()
		data_payload["item_id"] = event_item_id
		data_payload["weapon_id"] = event_item_id
		data_payload["display_name"] = event_display_name
		data_payload["energy_cost"] = energy_cost
		data_payload["damage_type"] = damage_type
		data_payload["damage_value"] = damage_value
		data_payload["ammo_group"] = ammo_group
		data_payload["ammo_item_id"] = get_enemy_ammo_item_id_for_group(build_context, ammo_group)
		data_payload["ammo_per_burst"] = ammo_per_burst
		data_payload["burst_count"] = burst_count
		data_payload["ammo_cost"] = total_ammo_cost
		data_payload["total_ammo_cost"] = total_ammo_cost
		data_payload["weapon_damage"] = weapon_damage
		data_payload["ammo_damage"] = ammo_damage
		data_payload["total_damage"] = damage_value
		data_payload["explosive_pass_percent"] = get_item_number(selected_enemy_item_data, "explosive_pass_percent", 0.0)
		data_payload["item_data"] = selected_enemy_item_data

	# Enemy shield switch is self-targeted and completes through the same shield state subtype.
	elif enemy_intent == "enemy_switch_shield":
		event_type = "enemy_switch_shield"
		event_group = "shield"
		requires_lock = false
		is_state_change = true
		same_type_key = "enemy_shield_switch"
		if event_item_id != "":
			same_type_key += "_" + event_item_id
		build_context["event_subtype"] = "shield_switch_complete"
		build_context["target_unit"] = build_context.get("owner_unit", build_context.get("source_unit", null))
		data_payload["current_shield"] = ""
		data_payload["pending_shield"] = event_item_id
		data_payload["pending_shield_data"] = selected_enemy_item_data
		data_payload["item_data"] = selected_enemy_item_data
		data_payload["switch_time"] = float(build_context.get("duration", 0.0))
		data_payload["shield_offline_during_swap"] = true

	# Enemy shield removal powers the shield down when energy is empty.
	elif enemy_intent == "enemy_remove_shield":
		event_type = "enemy_remove_shield"
		event_group = "shield"
		requires_lock = false
		is_state_change = true
		same_type_key = "enemy_remove_shield"
		build_context["event_subtype"] = "shield_remove_complete"
		build_context["target_unit"] = build_context.get("owner_unit", build_context.get("source_unit", null))
		data_payload["shield_action"] = "remove"
		data_payload["shield_power_level"] = 0
		data_payload["clear_selected_shield"] = true
		data_payload["reason"] = str(build_context.get("intent_reason", "energy empty"))

	# Enemy consumable load/prep uses the same state-change completion as player load.
	elif enemy_intent == "enemy_load_consumable":
		event_type = "enemy_load_consumable"
		event_group = "consumable"
		requires_lock = false
		is_state_change = true
		same_type_key = "enemy_load_consumable"
		if event_item_id != "":
			same_type_key += "_" + event_item_id
		build_context["event_subtype"] = "load_consumable_complete"
		build_context["target_unit"] = build_context.get("owner_unit", build_context.get("source_unit", null))
		data_payload["consumable_id"] = event_item_id
		data_payload["consumable_group"] = str(selected_enemy_item_data.get("consumable_group", selected_enemy_item_data.get("group", "consumable"))).strip_edges()
		data_payload["prep_time"] = float(build_context.get("duration", 0.0))
		data_payload["reserved_consumable"] = true
		data_payload["item_data"] = selected_enemy_item_data

	# Enemy loaded-consumable clear is a self-targeted state change that does not spend inventory.
	elif enemy_intent == "enemy_clear_loaded_consumable":
		event_type = "enemy_clear_loaded_consumable"
		event_group = "consumable"
		requires_lock = false
		is_state_change = true
		same_type_key = "enemy_clear_loaded_consumable"
		build_context["event_subtype"] = "clear_loaded_consumable_complete"
		build_context["target_unit"] = build_context.get("owner_unit", build_context.get("source_unit", null))
		data_payload["clear_loaded_consumable"] = true
		data_payload["no_item_spend"] = true
		data_payload["reason"] = str(build_context.get("intent_reason", "clear stale loaded consumable"))

	# Enemy consumable execute mirrors player consumable execute, with enemy ownership and stack checks.
	elif enemy_intent == "enemy_execute_consumable" or enemy_intent == "enemy_use_consumable" or enemy_intent == "enemy_repair" or enemy_intent == "enemy_recharge":
		var consumable_group := str(selected_enemy_item_data.get("consumable_group", selected_enemy_item_data.get("group", ""))).strip_edges().to_lower()
		if consumable_group == "" and enemy_intent == "enemy_repair":
			consumable_group = "repair"
		if consumable_group == "" and enemy_intent == "enemy_recharge":
			consumable_group = "recharge"
		if consumable_group == "":
			return make_rejected_result("missing enemy consumable_group", ["packet_build_rejected"])

		event_type = "enemy_execute_consumable"
		event_group = "consumable"
		requires_lock = false
		is_effect_event = true
		same_type_key = "enemy_execute_" + event_item_id
		build_context["target_unit"] = build_context.get("target_unit", build_context.get("player_state", null))
		data_payload["consumable_id"] = event_item_id
		data_payload["consumable_group"] = consumable_group
		data_payload["effect_data"] = selected_enemy_item_data.get("effect_data", {})
		data_payload["display_name"] = event_display_name
		data_payload["item_data"] = selected_enemy_item_data

		if consumable_group == "explosive":
			event_type = "execute_explosive"
			event_group = "explosive"
			requires_lock = true
			is_damage_event = true
			is_effect_event = false
			damage_type = "explosive"
			damage_value = get_explosive_damage_value(selected_enemy_item_data)
			data_payload["damage_value"] = damage_value
			data_payload["explosive_damage"] = damage_value
			data_payload["explosive_pass_percent"] = get_item_number(selected_enemy_item_data, "explosive_pass_percent", 0.0)
		elif consumable_group == "repair":
			event_type = "execute_repair"
			event_group = "repair"
			build_context["target_unit"] = build_context.get("owner_unit", build_context.get("source_unit", null))
			var heal_amount := get_item_number(selected_enemy_item_data, "heal_amount", get_item_number(selected_enemy_item_data, "repair_amount", get_item_number(selected_enemy_item_data, "hull_restore_amount", 0.0)))
			data_payload["heal_amount"] = heal_amount
			data_payload["repair_amount"] = heal_amount
			data_payload["hull_restore_amount"] = heal_amount
		elif consumable_group == "shield_repair":
			event_type = "execute_shield_repair"
			event_group = "shield_repair"
			build_context["target_unit"] = build_context.get("owner_unit", build_context.get("source_unit", null))
			var shield_repair_amount := get_item_number(selected_enemy_item_data, "shield_repair_amount", get_item_number(selected_enemy_item_data, "repair_amount", 0.0))
			data_payload["shield_repair_amount"] = shield_repair_amount
			data_payload["repair_amount"] = shield_repair_amount
			data_payload["requires_equipped_shield"] = bool(selected_enemy_item_data.get("requires_equipped_shield", true))
			data_payload["requires_unbroken_shield"] = bool(selected_enemy_item_data.get("requires_unbroken_shield", true))
		elif consumable_group == "recharge":
			event_type = "execute_recharge"
			event_group = "recharge"
			build_context["target_unit"] = build_context.get("owner_unit", build_context.get("source_unit", null))
			var energy_restore_amount := get_item_number(selected_enemy_item_data, "energy_restore_amount", get_item_number(selected_enemy_item_data, "recharge_amount", 0.0))
			data_payload["energy_restore_amount"] = energy_restore_amount
			data_payload["recharge_amount"] = energy_restore_amount
			data_payload["recharge_to_full"] = bool(selected_enemy_item_data.get("recharge_to_full", true))
		elif consumable_group == "signal":
			event_type = "execute_signal"
			event_group = "signal"
			var enemy_signal_duration := get_item_number(selected_enemy_item_data, "effect_duration", get_item_number(selected_enemy_item_data, "duration", float(build_context.get("duration", 5.0))))
			data_payload["signal_type"] = str(selected_enemy_item_data.get("signal_type", selected_enemy_item_data.get("effect_type", ""))).strip_edges()
			data_payload["signal_strength"] = get_item_number(selected_enemy_item_data, "signal_strength", 0.0)
			data_payload["duration"] = enemy_signal_duration
			data_payload["disabled_lane"] = str(selected_enemy_item_data.get("disabled_lane", data_payload["signal_type"])).strip_edges()
			data_payload["affects"] = selected_enemy_item_data.get("affects", ["weapon"])
			data_payload["stack_rule"] = str(selected_enemy_item_data.get("stack_rule", "unique")).strip_edges()
			data_payload["priority"] = int(selected_enemy_item_data.get("priority", 80))
			data_payload["flags"] = selected_enemy_item_data.get("flags", {})
			data_payload["visual_labels"] = selected_enemy_item_data.get("visual_labels", ["signal_success_apply_disable"])
			data_payload["effect_packet_template"] = selected_enemy_item_data.get("effect_packet_template", {})
		elif consumable_group == "pulse":
			event_type = "execute_pulse"
			event_group = "pulse"
			data_payload["pulse_pattern"] = str(selected_enemy_item_data.get("pulse_pattern", selected_enemy_item_data.get("pattern", ""))).strip_edges()
			data_payload["pulse_duration"] = get_item_number(selected_enemy_item_data, "pulse_duration", float(build_context.get("duration", 0.0)))
			data_payload["pulse_tick_rate"] = get_item_number(selected_enemy_item_data, "pulse_tick_rate", 0.0)
			data_payload["effect_packet_template"] = selected_enemy_item_data.get("effect_packet_template", {})
		elif consumable_group == "drone":
			event_type = "deploy_drone"
			event_group = "drone"
			requires_lock = false
			is_damage_event = false
			is_effect_event = true
			same_type_key = "enemy_deploy_drone_" + event_item_id
			build_context["target_unit"] = build_context.get("owner_unit", build_context.get("source_unit", null))
			var enemy_drone_duration := get_item_number(selected_enemy_item_data, "effect_duration", get_item_number(selected_enemy_item_data, "duration", float(build_context.get("duration", 10.0))))
			data_payload["duration"] = enemy_drone_duration
			data_payload["drone_type"] = str(selected_enemy_item_data.get("drone_type", "auto_attack")).strip_edges()
			data_payload["drone_group"] = str(selected_enemy_item_data.get("drone_group", selected_enemy_item_data.get("subgroup", ""))).strip_edges()
			data_payload["applies_effect"] = bool(selected_enemy_item_data.get("applies_effect", false))
			data_payload["drone_auto_attack"] = bool(selected_enemy_item_data.get("drone_auto_attack", data_payload["drone_type"] == "auto_attack"))
			data_payload["drone_damage_type"] = str(selected_enemy_item_data.get("drone_damage_type", "hull")).strip_edges()
			data_payload["drone_damage_value"] = get_item_number(selected_enemy_item_data, "drone_damage_value", 1.0)
			data_payload["drone_fire_interval"] = get_item_number(selected_enemy_item_data, "drone_fire_interval", 0.2)
			data_payload["drone_fire_count"] = int(max(get_item_number(selected_enemy_item_data, "drone_fire_count", get_item_number(selected_enemy_item_data, "drone_max_shots", get_item_number(selected_enemy_item_data, "drone_shot_count", 0.0))), 0.0))
			data_payload["drone_hull_current"] = get_item_number(selected_enemy_item_data, "drone_hull_current", get_item_number(selected_enemy_item_data, "drone_hull_max", 50.0))
			data_payload["drone_hull_max"] = get_item_number(selected_enemy_item_data, "drone_hull_max", 50.0)
			data_payload["drone_shield_active"] = bool(selected_enemy_item_data.get("drone_shield_active", true))
			data_payload["effect_id"] = str(selected_enemy_item_data.get("effect_id", event_item_id)).strip_edges()
		else:
			return make_rejected_result("unknown enemy consumable_group: " + consumable_group, ["packet_build_rejected"])

	# Enemy signal intent becomes an effect event; strength checks still belong to BattleManager later.
	elif enemy_intent == "enemy_signal" or enemy_intent == "enemy_signal_disable_lock":
		event_type = "enemy_signal_disable_lock"
		event_group = "signal"
		requires_lock = false
		is_effect_event = true
		same_type_key = "enemy_signal_disable_lock"
		data_payload["signal_type"] = str(build_context.get("signal_type", "disable_lock")).strip_edges()
		data_payload["signal_strength"] = float(build_context.get("signal_strength", 0.0))
		data_payload["duration"] = float(build_context.get("duration", 0.0))
		data_payload["disabled_lane"] = str(build_context.get("disabled_lane", data_payload["signal_type"])).strip_edges()
		data_payload["affects"] = build_context.get("affects", ["lock"])
		data_payload["stack_rule"] = str(build_context.get("stack_rule", "unique")).strip_edges()
		data_payload["priority"] = int(build_context.get("priority", 80))
		data_payload["flags"] = build_context.get("flags", {})
		data_payload["visual_labels"] = build_context.get("visual_labels", ["signal_success_apply_disable"])
		data_payload["effect_packet_template"] = build_context.get("effect_packet_template", {})

	# Enemy evade intent becomes a state-change event; lock loss outcome still resolves later.
	elif enemy_intent == "enemy_evade":
		event_type = "enemy_evade"
		event_group = "evade"
		requires_lock = false
		is_state_change = true
		same_type_key = "enemy_evade"
		build_context["event_subtype"] = "evade_complete"
		data_payload["evade_duration"] = float(build_context.get("duration", 0.0))
		data_payload["evade_cooldown_seconds"] = float(build_context.get("evade_cooldown_seconds", 0.0))
		data_payload["evade_lock_reacquire_penalty_seconds"] = float(build_context.get("evade_lock_reacquire_penalty_seconds", 0.0))
		data_payload["effect"] = "both_sides_lock_loss"
		data_payload["labels"] = [
			"evade_resolution_rule",
			"enemy_evade_intent",
			"evade_todo_started"
		]

	# Unknown enemy intents are rejected so the builder does not invent enemy behavior.
	else:
		return make_rejected_result("unknown enemy_intent: " + enemy_intent, ["packet_build_rejected"])

	# Fill enemy action packet fields required by the EventManager/BattleManager pipeline.
	build_context["same_type_key"] = same_type_key
	build_context["requires_lock"] = requires_lock
	build_context["is_state_change"] = is_state_change
	build_context["is_damage_event"] = is_damage_event
	build_context["is_effect_event"] = is_effect_event
	build_context["is_visual_only"] = false
	build_context["item_id"] = event_item_id
	build_context["energy_cost"] = energy_cost
	build_context["damage_type"] = damage_type
	build_context["damage_value"] = damage_value
	build_context["data"] = data_payload

	# Build the shared event shell, then return it inside the standard built packet_result wrapper.
	var event_packet := build_base_event_packet(build_context, event_type, event_group)

	var result_labels := ["action_to_event_packet", "packet_builder_event_ownership_fields", "enemy_intent_to_event_packet"]
	if intent_chosen_by_logic:
		result_labels.append("enemy_logic_choose_enemy_intent")

	return make_built_result(event_packet, result_labels)
	
	
	
	
func build_switch_shield_packet(context: Dictionary) -> Dictionary:
	# Summary: Builds an EventManager-ready packet_result for switching the player's active shield.
	if Globals.print_priority_3:
		print("BattleActionPacketBuilder.build_switch_shield_packet | Building shield switch packet.")

	# Duplicate the context so this builder can add packet fields without mutating the caller's dictionary.
	var build_context := context.duplicate(true)

	# Shield switching has a stable action id, even if Action_Manager did not provide one yet.
	if str(build_context.get("action_id", "")).strip_edges() == "":
		build_context["action_id"] = "switch_shield"

	# Read item data early so shield timing and shield id can provide safe fallbacks before validation runs.
	var item_data = build_context.get("item_data", {})

	# Shield switch requires item data because the packet must know which shield is being switched to.
	if typeof(item_data) != TYPE_DICTIONARY or item_data.is_empty():
		return make_rejected_result("missing shield item_data", ["packet_build_rejected"])

	# If duration was not passed by context, allow common shield switch timing keys from item_data.
	if not build_context.has("duration") or float(build_context.get("duration", 0.0)) <= 0.0:
		var item_duration := get_item_number(item_data, "switch_time", 0.0)

		if item_duration <= 0.0:
			item_duration = get_item_number(item_data, "duration", 0.0)

		if item_duration <= 0.0:
			item_duration = get_item_number(item_data, "cooldown", 0.0)

		build_context["duration"] = item_duration

	# Shield switching is usually self-targeted, so default the target to the source unit before validation.
	build_context["target_unit"] = build_context.get("target_unit", build_context.get("source_unit", null))

	# Shield switching needs a source/owner/side/action/duration, but it does not need an enemy target.
	var validation_result := validate_common_context(build_context, false, true)

	if validation_result.get("status", "") != "valid":
		return validation_result

	# Shield switch packets require a stable item id for same-type stacking and completion routing.
	var item_id := get_item_id(item_data)

	if item_id == "":
		return make_rejected_result("missing shield item_id", ["packet_build_rejected"])

	# Current shield can come from context or item data; the builder only records it and does not mutate player state.
	var current_shield := str(build_context.get("current_shield", item_data.get("current_shield", ""))).strip_edges()
	var pending_shield := str(build_context.get("pending_shield", item_id)).strip_edges()
	var switch_time := float(build_context.get("duration", 0.0))

	# Fill shield switch packet fields required by the EventManager/BattleManager pipeline.
	build_context["same_type_key"] = "shield_switch_" + item_id
	build_context["event_subtype"] = "shield_switch_complete"
	build_context["requires_lock"] = false
	build_context["is_state_change"] = true
	build_context["is_damage_event"] = false
	build_context["is_effect_event"] = false
	build_context["is_visual_only"] = false
	build_context["item_id"] = item_id
	build_context["damage_type"] = ""
	build_context["damage_value"] = 0
	build_context["data"] = {
		"current_shield": current_shield,
		"pending_shield": pending_shield,
		"pending_shield_data": item_data,
		"item_data": item_data,
		"switch_time": switch_time,
		"shield_offline_during_swap": true
	}

	# Build the shared event shell, then return it inside the standard built packet_result wrapper.
	var event_packet := build_base_event_packet(build_context, "switch_shield", "shield")

	return make_built_result(event_packet, ["action_to_event_packet", "packet_builder_event_ownership_fields"])
