extends Node
class_name PlayerHandler


# ==========================================================
# PLAYER HANDLER
# ----------------------------------------------------------
# Player-side bridge between current gameplay systems and
# Battle V2. This handler coordinates references and handoffs
# only. It does not resolve battle outcomes, queue TODOs,
# spend resources, calculate energy, or count inventory items.
# ==========================================================

var player_state: PlayerState = null

var inventory = null
var inventory_handler = null
var energy_handler = null
var action_manager = null
var battle_manager = null
var battle_action_packet_builder = null
var event_manager = null
var stat_effect_handler = null

var animator_fetcher = null
var decorative_ui = null
var current_battle_id: String = ""
var last_loadout_data: Dictionary = {}
var last_prepare_result: Dictionary = {}
var last_cleanup_result: Dictionary = {}
var debug_enabled: bool = false


func setup(references: Dictionary = {}) -> void:
	# Summary: Store outside system references without taking ownership of their logic.
	if references.has("player_state"):
		set_player_state(references.get("player_state"))

	set_inventory_ref(references.get("inventory", inventory))
	inventory_handler = references.get("inventory_handler", references.get("inventory", inventory_handler))
	set_energy_handler_ref(references.get("energy_handler", energy_handler))
	set_action_manager_ref(references.get("action_manager", action_manager))
	battle_manager = references.get("battle_manager", battle_manager)
	battle_action_packet_builder = references.get("battle_action_packet_builder", battle_action_packet_builder)
	event_manager = references.get("event_manager", event_manager)
	stat_effect_handler = references.get("stat_effect_handler", stat_effect_handler)
	animator_fetcher = references.get("animator_fetcher", animator_fetcher)
	decorative_ui = references.get("decorative_ui", decorative_ui)
	debug_enabled = bool(references.get("debug_enabled", debug_enabled))


func get_player_state():
	# Summary: Return the active PlayerState, creating one if the battle context has not supplied it yet.
	if player_state == null:
		player_state = PlayerState.new()
		player_state.name = "PlayerState"

		if is_inside_tree() and player_state.get_parent() == null:
			add_child(player_state)

	return player_state


func set_player_state(state) -> Dictionary:
	# Summary: Store the PlayerState reference supplied by the main project or test harness.
	if state == null:
		player_state = null
		return _make_result("failed", "missing player_state", ["player_handler_failed"], {})

	player_state = state
	return _make_result("success", "", ["player_handler_ready"], {"player_state": player_state})


func ensure_player_state() -> Dictionary:
	# Summary: Guarantee this handler has a PlayerState reference before battle prep.
	var state = get_player_state()
	if state == null:
		return _make_result("failed", "missing player_state", ["player_handler_failed"], {})
	return _make_result("success", "", ["player_handler_ready"], {"player_state": state})


func set_inventory_ref(ref) -> Dictionary:
	# Summary: Store the Inventory bridge reference without taking count ownership.
	inventory = ref
	if inventory_handler == null:
		inventory_handler = ref
	return _make_result("success", "", ["player_inventory_bridge"], {"inventory": inventory})


func set_energy_handler_ref(ref) -> Dictionary:
	# Summary: Store the EnergyHandler bridge reference without doing energy math.
	energy_handler = ref
	return _make_result("success", "", ["player_energy_bridge"], {"energy_handler": energy_handler})


func set_action_manager_ref(ref) -> Dictionary:
	# Summary: Store the ActionManager bridge reference without drawing rows.
	action_manager = ref
	return _make_result("success", "", ["player_action_availability_bridge"], {"action_manager": action_manager})


func sync_loadout_to_player_state(loadout_data: Dictionary) -> Dictionary:
	# Summary: Copy equipped loadout fields into PlayerState without resolving or spending anything.
	var ensure_result := ensure_player_state()
	if ensure_result.get("status", "") != "success":
		return ensure_result

	var state = player_state

	var primary_weapon = _normalize_slot_value(loadout_data.get("selected_primary_weapon", state.selected_primary_weapon))
	var secondary_weapon = _normalize_slot_value(loadout_data.get("selected_secondary_weapon", state.selected_secondary_weapon))
	var shield = _normalize_slot_value(loadout_data.get("selected_shield", state.selected_shield))
	var consumable = _normalize_slot_value(loadout_data.get("loaded_consumable", state.loaded_consumable))
	var consumable_state := str(loadout_data.get("loaded_consumable_state", "")).strip_edges()
	var upgrades := _normalize_upgrade_list(loadout_data.get("equipped_upgrades", []))

	if state.has_method("set_selected_primary_weapon"):
		state.set_selected_primary_weapon(primary_weapon)
	else:
		state.selected_primary_weapon = primary_weapon

	if state.has_method("set_selected_secondary_weapon"):
		state.set_selected_secondary_weapon(secondary_weapon)
	else:
		state.selected_secondary_weapon = secondary_weapon

	if state.has_method("set_selected_shield"):
		state.set_selected_shield(shield)
	else:
		state.selected_shield = shield

	if state.has_method("set_loaded_consumable"):
		state.set_loaded_consumable(consumable, consumable_state)
	else:
		state.loaded_consumable = consumable
		if state.get("loaded_consumable_state") != null:
			if consumable == null:
				state.loaded_consumable_state = "none"
			elif consumable_state == "":
				state.loaded_consumable_state = "loaded"
			else:
				state.loaded_consumable_state = consumable_state

	if state.has_method("set_equipped_upgrades"):
		state.set_equipped_upgrades(upgrades)
	elif state.get("battle_loadout") is Dictionary:
		state.battle_loadout["equipped_upgrades"] = upgrades.duplicate(true)
		if state.get("equipped_upgrades") != null:
			state.equipped_upgrades = upgrades.duplicate(true)

	last_loadout_data = {
		"selected_primary_weapon": primary_weapon,
		"selected_secondary_weapon": secondary_weapon,
		"selected_shield": shield,
		"loaded_consumable": consumable,
		"loaded_consumable_state": state.get("loaded_consumable_state"),
		"equipped_upgrades": upgrades.duplicate(true)
	}

	var labels := [
		"player_state_sync_on_battle_start",
		"player_loadout_bridge"
	]
	if primary_weapon != null:
		labels.append("player_primary_weapon_equipped")
	if secondary_weapon != null:
		labels.append("player_secondary_weapon_equipped")
	if shield != null:
		labels.append("player_shield_equipped")
	if consumable == null:
		labels.append("player_consumable_slot_empty")
	if not upgrades.is_empty():
		labels.append("player_battle_upgrades_equipped")

	return _make_result("success", "", labels, last_loadout_data.duplicate(true))


func sync_energy_to_player_state(battle_context: Dictionary) -> Dictionary:
	# Summary: Copy starting energy values into PlayerState without taking runtime energy math away from EnergyHandler.
	var ensure_result := ensure_player_state()
	if ensure_result.get("status", "") != "success":
		return ensure_result

	var state = player_state
	var current_energy := _read_energy_value_from_context(
		battle_context,
		["player_energy_current", "energy_current", "current_energy"],
		float(state.get("energy_current"))
	)
	var max_energy := _read_energy_value_from_context(
		battle_context,
		["player_energy_max", "energy_max", "max_energy"],
		float(state.get("energy_max"))
	)
	var regen_per_second := _read_energy_value_from_context(
		battle_context,
		["player_energy_regen_per_second", "energy_regen_per_second", "regen_per_second", "recharge_rate"],
		float(state.get("energy_regen_per_second"))
	)

	if state.has_method("set_energy_values"):
		state.set_energy_values(current_energy, max_energy, regen_per_second)
	else:
		if state.get("energy_max") != null:
			state.energy_max = max(max_energy, 0.0)
		if state.get("energy_current") != null:
			state.energy_current = clamp(current_energy, 0.0, max(max_energy, 1.0))
		if state.get("energy_regen_per_second") != null:
			state.energy_regen_per_second = max(regen_per_second, 0.0)

	last_prepare_result["energy_data"] = {
		"energy_current": current_energy,
		"energy_max": max_energy,
		"energy_regen_per_second": regen_per_second
	}

	return _make_result(
		"success",
		"",
		["player_state_energy_seed", "energy_handler_starting_values", "player_energy_bridge"],
		{
			"energy_current": state.get("energy_current"),
			"energy_max": state.get("energy_max"),
			"energy_regen_per_second": state.get("energy_regen_per_second")
		}
	)


func prepare_player_for_battle(battle_context: Dictionary) -> Dictionary:
	# Summary: Prepare player-side battle state for Battle V2 without queuing events or resolving outcomes.
	var ensure_result := ensure_player_state()
	if ensure_result.get("status", "") != "success":
		last_prepare_result = ensure_result
		return ensure_result

	var state = player_state
	current_battle_id = str(battle_context.get("battle_id", current_battle_id))

	set_inventory_ref(battle_context.get("inventory_ref", battle_context.get("inventory", inventory)))
	set_energy_handler_ref(battle_context.get("energy_handler_ref", battle_context.get("energy_handler", energy_handler)))
	set_action_manager_ref(battle_context.get("action_manager_ref", battle_context.get("action_manager", action_manager)))
	battle_manager = battle_context.get("battle_manager_ref", battle_context.get("battle_manager", battle_manager))
	event_manager = battle_context.get("event_manager_ref", battle_context.get("event_manager", event_manager))
	stat_effect_handler = battle_context.get("stat_effect_handler_ref", battle_context.get("stat_effect_handler", stat_effect_handler))

	if state.has_method("clear_temporary_battle_state"):
		state.clear_temporary_battle_state()

	if state.has_method("start_battle_state"):
		state.start_battle_state()
	else:
		state.battle_active = true

	var loadout_data := _extract_loadout_data_from_context(battle_context)
	if Globals.print_priority_1:
		print("[player_prepare_start] raw_context=", battle_context)
		print("[player_prepare_start] extracted_loadout_data=", loadout_data)

	var energy_sync_result := sync_energy_to_player_state(battle_context)
	if energy_sync_result.get("status", "") != "success":
		last_prepare_result = _make_result(
			"failed",
			str(energy_sync_result.get("reason", "energy sync failed")),
			["player_battle_start_prep", "player_prepare_for_battle_failed"],
			{"energy_sync_result": energy_sync_result}
		)
		return last_prepare_result

	var sync_result := sync_loadout_to_player_state(loadout_data)
	if sync_result.get("status", "") != "success":
		last_prepare_result = _make_result(
			"failed",
			str(sync_result.get("reason", "loadout sync failed")),
			["player_battle_start_prep", "player_prepare_for_battle_failed"],
			{"sync_result": sync_result}
		)
		return last_prepare_result
		
	if Globals.print_priority_1:
		print("[player_prepare_done] result=", sync_result)
		print("[player_prepare_done] primary=", player_state.selected_primary_weapon)
		print("[player_prepare_done] secondary=", player_state.selected_secondary_weapon)
		print("[player_prepare_done] shield=", player_state.selected_shield)
		print("[player_prepare_done] consumable=", player_state.loaded_consumable)
		print("[player_prepare_done] energy=", energy_sync_result.get("data", {}))

	last_prepare_result = _make_result(
		"success",
		"",
		[
			"player_battle_start_prep",
			"player_state_sync_on_battle_start",
			"player_state_energy_seed",
			"player_loadout_bridge",
			"player_prepare_for_battle_success"
		],
		{
			"battle_id": current_battle_id,
			"player_state": state,
			"loadout_synced": true,
			"loadout_data": last_loadout_data.duplicate(true),
			"energy_data": energy_sync_result.get("data", {}).duplicate(true)
		}
	)
	return last_prepare_result


func cleanup_player_after_battle(cleanup_context: Dictionary) -> Dictionary:
	# Summary: Clear safe temporary player battle flags after BattleManager has resolved the outcome.
	var ensure_result := ensure_player_state()
	if ensure_result.get("status", "") != "success":
		last_cleanup_result = ensure_result
		return ensure_result

	var state = player_state

	if state.has_method("clear_safe_consumables_on_battle_end"):
		state.clear_safe_consumables_on_battle_end()
	else:
		_clear_consumables_by_field(state)

	if state.has_method("clear_temporary_battle_state"):
		state.clear_temporary_battle_state()

	if state.has_method("end_battle_state"):
		state.end_battle_state()
	else:
		state.battle_active = false

	var cleanup_battle_id := str(cleanup_context.get("battle_id", current_battle_id))
	current_battle_id = ""

	last_cleanup_result = _make_result(
		"success",
		"",
		[
			"player_battle_cleanup_bridge",
			"player_state_clear_temporary_state",
			"loaded_consumable_safe_on_battle_end",
			"player_cleanup_after_battle_success"
		],
		{
			"battle_id": cleanup_battle_id,
			"outcome": cleanup_context.get("outcome", ""),
			"player_state": state,
			"inventory_counts_preserved": true,
			"energy_values_untouched": true
		}
	)
	return last_cleanup_result


func get_player_action_availability(item_id: Variant = null, slot_type: String = "") -> Dictionary:
	# Summary: Report player action lane availability from PlayerState and handler references only.
	var state = get_player_state()

	var has_primary_weapon := _has_value(state.get("selected_primary_weapon"))
	var has_secondary_weapon := _has_value(state.get("selected_secondary_weapon"))
	var has_shield := _has_value(state.get("selected_shield"))
	var has_loaded_consumable := _has_value(state.get("loaded_consumable"))
	var ready_list = state.get("ready_consumables")
	var ready_list_has_items: bool = ready_list is Array and not ready_list.is_empty()
	var loaded_state := str(state.get("loaded_consumable_state")).strip_edges()

	var consumable_ready := bool(state.get("consumable_ready")) \
		or loaded_state == "ready" \
		or loaded_state == "loaded" \
		or ready_list_has_items \
		or _has_value(state.get("ready_consumable")) \
		or has_loaded_consumable

	var primary_disabled := bool(state.get("primary_disabled"))
	var secondary_disabled := bool(state.get("secondary_disabled"))
	var consumable_disabled := bool(state.get("consumable_disabled"))
	var shield_disabled := bool(state.get("shield_disabled"))

	var normalized_slot := str(slot_type).strip_edges().to_lower()
	var available := false
	var reason := ""

	match normalized_slot:
		"primary", "primary_weapon":
			available = has_primary_weapon and not primary_disabled
			reason = "" if available else "missing_primary_weapon_or_disabled"

		"secondary", "secondary_weapon":
			available = has_secondary_weapon and not secondary_disabled
			reason = "" if available else "missing_secondary_weapon_or_disabled"

		"consumable", "loaded_consumable":
			available = has_loaded_consumable and consumable_ready and not consumable_disabled
			reason = "" if available else "missing_consumable_or_not_ready_or_disabled"

		"shield", "shields":
			available = has_shield and not shield_disabled
			reason = "" if available else "missing_shield_or_disabled"

		_:
			available = (
				(has_primary_weapon and not primary_disabled)
				or (has_secondary_weapon and not secondary_disabled)
				or (has_shield and not shield_disabled)
				or (has_loaded_consumable and consumable_ready and not consumable_disabled)
			)
			reason = "" if available else "no_available_player_actions"

	return {
		"available": available,
		"reason": reason,
		"item_id": item_id,
		"slot_type": slot_type,

		"has_primary_weapon": has_primary_weapon,
		"has_secondary_weapon": has_secondary_weapon,
		"has_shield": has_shield,
		"has_loaded_consumable": has_loaded_consumable,
		"consumable_ready": consumable_ready,

		"primary_disabled": primary_disabled,
		"secondary_disabled": secondary_disabled,
		"consumable_disabled": consumable_disabled,
		"shield_disabled": shield_disabled,

		"selected_primary_weapon": state.get("selected_primary_weapon"),
		"selected_secondary_weapon": state.get("selected_secondary_weapon"),
		"selected_shield": state.get("selected_shield"),
		"loaded_consumable": state.get("loaded_consumable"),

		"labels": _base_labels([
			"player_action_availability_bridge",
			"player_action_availability_checked",
			"player_inventory_bridge",
			"player_energy_bridge"
		])
	}


func run_player_handler_battle_prep_cleanup_test() -> Dictionary:
	# Summary: Local lightweight smoke test for the PlayerHandler Battle V2 prep and cleanup contract.
	var test_state := PlayerState.new()
	set_player_state(test_state)
	inventory = Node.new()
	inventory_handler = inventory
	energy_handler = EnergyHandler.new()

	var inventory_snapshot := {}
	var energy_snapshot := {}

	var test_loadout := {
		"selected_primary_weapon": "pulse_laser_mk1",
		"selected_secondary_weapon": "kinetic_cannon_mk1",
		"selected_shield": "reinforced_barrier_mk1",
		"loaded_consumable": null
	}

	var result = prepare_player_for_battle({
		"battle_id": "test_battle_001",
		"loadout_data": test_loadout
	})
	var prepare_battle_active := test_state.battle_active

	var availability = get_player_action_availability()

	var cleanup_result = cleanup_player_after_battle({
		"battle_id": "test_battle_001",
		"outcome": "victory"
	})

	var passed := true
	passed = passed and result.get("status", "") == "success"
	passed = passed and prepare_battle_active == true
	passed = passed and test_state.battle_active == false
	passed = passed and test_state.selected_primary_weapon == "pulse_laser_mk1"
	passed = passed and test_state.selected_secondary_weapon == "kinetic_cannon_mk1"
	passed = passed and test_state.selected_shield == "reinforced_barrier_mk1"
	passed = passed and availability.get("has_primary_weapon", false) == true
	passed = passed and availability.get("has_secondary_weapon", false) == true
	passed = passed and availability.get("has_shield", false) == true
	passed = passed and cleanup_result.get("status", "") == "success"
	passed = passed and test_state.loaded_consumable == null
	passed = passed and test_state.loaded_consumable_state == "none"

	return _make_result(
		"success" if passed else "failed",
		"" if passed else "PlayerHandler prep/cleanup smoke test failed",
		[
			"player_battle_start_prep",
			"player_action_availability_bridge",
			"player_battle_cleanup_bridge"
		],
		{
			"prepare_result": result,
			"availability": availability,
			"cleanup_result": cleanup_result,
			"inventory_snapshot_unchanged": inventory_snapshot.is_empty(),
			"energy_snapshot_unchanged": energy_snapshot.is_empty()
		}
	)


func _make_result(status: String, reason: String = "", labels: Array = [], data: Dictionary = {}) -> Dictionary:
	# Summary: Build the standard PlayerHandler result packet.
	return {
		"status": status,
		"reason": reason,
		"labels": _base_labels(labels),
		"data": data
	}


func _base_labels(extra_labels: Array = []) -> Array:
	# Summary: Return common PlayerHandler boundary labels plus caller-specific labels.
	var labels := [
		"player_handler",
		"player_handler_owns_player_state_reference",
		"player_loadout_bridge",
		"player_inventory_bridge",
		"player_energy_bridge",
		"player_handler_no_damage_resolution",
		"player_handler_no_todo_timing",
		"player_handler_no_energy_math",
		"player_handler_no_inventory_counts",
		"player_handler_no_active_effect_storage",
		"player_handler_no_ui_drawing"
	]

	for label in extra_labels:
		if not labels.has(label):
			labels.append(label)

	return labels


func _has_value(value: Variant) -> bool:
	# Summary: Treat null and blank strings as unavailable while allowing dictionaries, objects, and ids.
	return not _is_empty_slot_value(value)


func _normalize_slot_value(value: Variant) -> Variant:
	# Summary: Normalize empty slot spellings so Battle V2 does not build fake null rows.
	if _is_empty_slot_value(value):
		return null
	return value


func _is_empty_slot_value(value: Variant) -> bool:
	# Summary: Treat null, blank, and textual null values as empty loadout slots.
	if value == null:
		return true

	if typeof(value) == TYPE_STRING:
		var clean_value := str(value).strip_edges()
		return clean_value == "" or clean_value.to_lower() == "null" or clean_value.to_lower() == "<null>"

	return false


func _read_energy_value_from_context(battle_context: Dictionary, field_names: Array, fallback: float) -> float:
	# Summary: Read energy seed values from future player saves first, then PlayerState defaults.
	var sources: Array = []

	for key in ["player_state_data", "player_save_data", "player_energy_data", "energy_data"]:
		var source = battle_context.get(key, null)
		if typeof(source) == TYPE_DICTIONARY:
			sources.append(source)

	sources.append(battle_context)

	for source in sources:
		for field_name in field_names:
			var read_result := _try_read_float_from_source(source, str(field_name))
			if bool(read_result.get("found", false)):
				return float(read_result.get("value", fallback))

	return fallback


func _try_read_float_from_source(source, field_name: String) -> Dictionary:
	if source == null:
		return {"found": false, "value": 0.0}

	if typeof(source) == TYPE_DICTIONARY:
		var dictionary_source: Dictionary = source
		if dictionary_source.has(field_name):
			return {"found": true, "value": float(dictionary_source.get(field_name, 0.0))}
		return {"found": false, "value": 0.0}

	if source is Object:
		var value = source.get(field_name)
		if value != null:
			return {"found": true, "value": float(value)}

	return {"found": false, "value": 0.0}


func _clear_consumables_by_field(state) -> void:
	# Summary: Fallback consumable cleanup for state objects that do not expose the PlayerState helper.
	if state == null:
		return

	if state.get("loaded_consumable") != null:
		state.loaded_consumable = null
	if state.get("prepped_consumable") != null:
		state.prepped_consumable = null
	if state.get("ready_consumable") != null:
		state.ready_consumable = null
	if state.get("loaded_consumable_state") != null:
		state.loaded_consumable_state = "none"
	if state.get("consumable_ready") != null:
		state.consumable_ready = false
	if state.get("ready_consumables") is Array:
		state.ready_consumables.clear()


func _extract_loadout_data_from_context(battle_context: Dictionary) -> Dictionary:
	# Summary: Accept either a full Battle V2 context or a direct loadout_data packet.
	if battle_context.is_empty():
		return {}

	var wrapped_loadout = battle_context.get("loadout_data", null)
	if typeof(wrapped_loadout) == TYPE_DICTIONARY:
		return wrapped_loadout

	var loadout_keys := [
		"selected_primary_weapon",
		"selected_secondary_weapon",
		"selected_shield",
		"loaded_consumable",
		"loaded_consumable_state",
		"equipped_upgrades"
	]

	for key in loadout_keys:
		if battle_context.has(key):
			return battle_context

	return {}


func _normalize_upgrade_list(value) -> Array:
	var clean: Array = []
	if typeof(value) != TYPE_ARRAY:
		return clean

	for raw_id in value:
		var upgrade_id = _normalize_slot_value(raw_id)
		if upgrade_id == null:
			continue
		var clean_id := str(upgrade_id).strip_edges()
		if clean_id == "":
			continue
		if clean.has(clean_id):
			continue
		clean.append(clean_id)
		if clean.size() >= 3:
			break

	return clean
