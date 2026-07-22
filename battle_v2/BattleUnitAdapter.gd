extends Node
class_name BattleV2UnitAdapter


# ==========================================================
# BATTLE V2 UNIT ADAPTER
# ----------------------------------------------------------
# Small prototype battle-state object used by BattleManager.
# This keeps scene handoff data safe while the full PlayerState
# and EnemyState objects are still being merged.
# ==========================================================

var unit_id: String = ""
var display_name: String = "Unknown Unit"
var unit_side: String = "neutral"

var object_id: String = ""
var object_type: String = "battle_unit"
var enemy_serial: String = ""
var enemy_template_id: String = ""
var tier: int = 1
var section_id: String = ""
var sector_pos: Vector3i = Vector3i.ZERO
var local_pos: Vector3 = Vector3.ZERO
var is_visible: bool = true
var is_discovered: bool = false
var is_completed: bool = false
var has_event: bool = false
var give_event: String = ""
var requires_event: String = ""
var has_run_lore: bool = false
var run_lore_id: String = ""
var has_universe_lore: bool = false
var universe_lore_id: String = ""
var has_gift: bool = false
var gift_id: String = ""
var labels: Array = []
var shared_meta: Dictionary = {}

var player_hull_current: float = 500.0
var player_hull_max: float = 500.0
var base_player_hull_max: float = 500.0
var player_energy_current: float = 100.0
var player_energy_max: float = 100.0
var player_energy_regen_per_second: float = 8.0
var base_player_energy_max: float = 100.0
var equipped_upgrades: Array = []
var battle_upgrade_meta: Dictionary = {}
var enemy_hull_current: float = 100.0
var enemy_hull_max: float = 100.0

var player_lock_disabled: bool = false
var enemy_lock_disabled: bool = false
var player_good_lock: bool = false
var enemy_good_lock: bool = false
var player_lock_pending: bool = false
var enemy_lock_pending: bool = false

var shield_switching: bool = false
var selected_shield: Variant = null
var pending_shield: Variant = null
var shield_power_level: int = 0
var shield_hp_current: float = 0.0
var shield_hp_max: float = 0.0
var shield_disabled: bool = false

var active_signal_effect: Variant = null
var enemy_signal_defense: float = 0.0
var behavior_profile: String = "raider_basic"
var behavior_values: Dictionary = {}
var selected_primary_weapon: String = ""
var selected_secondary_weapon: String = ""
var selected_enemy_shield: String = ""
var loaded_consumable: Variant = null
var loaded_consumable_state: String = "none"
var consumable_ready: bool = false
var primary_available: bool = false
var secondary_available: bool = false
var primary_disabled: bool = false
var secondary_disabled: bool = false
var can_evade: bool = true
var can_signal: bool = false
var attack: float = 8.0
var enemy_energy_current: float = 100.0
var enemy_energy_max: float = 100.0
var enemy_reserved_energy: float = 0.0
var enemy_ammo_small: int = 0
var enemy_ammo_medium: int = 0
var enemy_ammo_large: int = 0
var enemy_loaded_consumable: Variant = null
var enemy_consumable_ready: bool = false
var enemy_item_stacks: Dictionary = {}

var source_world_enemy: Variant = null
var source_enemy_id: String = ""


func setup_from_packet(data: Dictionary) -> void:
	# Summary: Load adapter fields from a safe dictionary packet.
	if Globals.print_priority_6:
		print("BattleV2UnitAdapter.setup_from_packet | Loading unit packet.")

	# ------------------------------------------------------
	# Identity and side.
	# ------------------------------------------------------
	unit_id = str(data.get("unit_id", unit_id))
	display_name = str(data.get("display_name", display_name))
	unit_side = str(data.get("unit_side", unit_side))
	apply_shared_meta(data.get("shared_meta", data), true)
	enemy_serial = str(data.get("enemy_serial", enemy_serial))
	enemy_template_id = str(data.get("enemy_template_id", enemy_template_id))

	# ------------------------------------------------------
	# Hull values are mirrored by side because BattleManager
	# currently reads side-specific field names.
	# ------------------------------------------------------
	var hull_current: float = float(data.get("hull_current", data.get("hp", 100.0)))
	var hull_max: float = float(data.get("hull_max", data.get("max_hp", hull_current)))
	player_hull_current = float(data.get("player_hull_current", hull_current))
	player_hull_max = float(data.get("player_hull_max", hull_max))
	base_player_hull_max = float(data.get("base_player_hull_max", player_hull_max))
	player_energy_current = float(data.get("player_energy_current", data.get("energy_current", player_energy_current)))
	player_energy_max = float(data.get("player_energy_max", data.get("energy_max", player_energy_max)))
	player_energy_regen_per_second = float(data.get("player_energy_regen_per_second", data.get("energy_regen_per_second", player_energy_regen_per_second)))
	base_player_energy_max = float(data.get("base_player_energy_max", player_energy_max))
	if typeof(data.get("equipped_upgrades", [])) == TYPE_ARRAY:
		equipped_upgrades = data.get("equipped_upgrades", []).duplicate(true)
	if typeof(data.get("battle_upgrade_meta", {})) == TYPE_DICTIONARY:
		battle_upgrade_meta = data.get("battle_upgrade_meta", {}).duplicate(true)
	enemy_hull_current = float(data.get("enemy_hull_current", hull_current))
	enemy_hull_max = float(data.get("enemy_hull_max", hull_max))

	# ------------------------------------------------------
	# Lock values.
	# ------------------------------------------------------
	player_good_lock = bool(data.get("player_good_lock", data.get("good_lock", false)))
	enemy_good_lock = bool(data.get("enemy_good_lock", data.get("good_lock", false)))
	player_lock_disabled = bool(data.get("player_lock_disabled", false))
	enemy_lock_disabled = bool(data.get("enemy_lock_disabled", false))
	player_lock_pending = bool(data.get("player_lock_pending", false))
	enemy_lock_pending = bool(data.get("enemy_lock_pending", false))

	# ------------------------------------------------------
	# Shield and signal fields used by BattleManager.
	# ------------------------------------------------------
	shield_switching = bool(data.get("shield_switching", false))
	selected_shield = data.get("selected_shield", null)
	pending_shield = data.get("pending_shield", null)
	shield_power_level = int(data.get("shield_power_level", 0))
	shield_hp_current = float(data.get("shield_hp_current", 0.0))
	shield_hp_max = float(data.get("shield_hp_max", get_shield_packet_max_hp(selected_shield, shield_hp_current)))
	shield_disabled = bool(data.get("shield_disabled", false))
	active_signal_effect = data.get("active_signal_effect", null)
	enemy_signal_defense = float(data.get("enemy_signal_defense", 0.0))
	behavior_profile = str(data.get("behavior_profile", behavior_profile))
	if typeof(data.get("behavior_values", {})) == TYPE_DICTIONARY:
		behavior_values = data.get("behavior_values", {}).duplicate(true)
	selected_primary_weapon = str(data.get("selected_primary_weapon", selected_primary_weapon))
	selected_secondary_weapon = str(data.get("selected_secondary_weapon", selected_secondary_weapon))
	selected_enemy_shield = str(data.get("selected_enemy_shield", data.get("enemy_shield", selected_enemy_shield)))
	loaded_consumable = data.get("loaded_consumable", loaded_consumable)
	loaded_consumable_state = str(data.get("loaded_consumable_state", loaded_consumable_state))
	consumable_ready = bool(data.get("consumable_ready", loaded_consumable_state == "ready"))
	primary_available = bool(data.get("primary_available", selected_primary_weapon.strip_edges() != ""))
	secondary_available = bool(data.get("secondary_available", selected_secondary_weapon.strip_edges() != ""))
	primary_disabled = bool(data.get("primary_disabled", false))
	secondary_disabled = bool(data.get("secondary_disabled", false))
	can_evade = bool(data.get("can_evade", can_evade))
	can_signal = bool(data.get("can_signal", can_signal))
	attack = float(data.get("attack", attack))
	enemy_energy_current = float(data.get("enemy_energy_current", enemy_energy_current))
	enemy_energy_max = float(data.get("enemy_energy_max", enemy_energy_max))
	enemy_reserved_energy = float(data.get("enemy_reserved_energy", enemy_reserved_energy))
	enemy_ammo_small = int(data.get("enemy_ammo_small", enemy_ammo_small))
	enemy_ammo_medium = int(data.get("enemy_ammo_medium", enemy_ammo_medium))
	enemy_ammo_large = int(data.get("enemy_ammo_large", enemy_ammo_large))
	enemy_loaded_consumable = data.get("enemy_loaded_consumable", enemy_loaded_consumable)
	enemy_consumable_ready = bool(data.get("enemy_consumable_ready", enemy_consumable_ready))
	if typeof(data.get("enemy_item_stacks", {})) == TYPE_DICTIONARY:
		enemy_item_stacks = data.get("enemy_item_stacks", {}).duplicate(true)


func apply_hull_damage(amount: float) -> void:
	# Summary: Apply hull damage to the adapter side BattleManager is resolving.
	var damage: float = max(float(amount), 0.0)

	if unit_side == "enemy":
		enemy_hull_current = max(enemy_hull_current - damage, 0.0)
	else:
		player_hull_current = max(player_hull_current - damage, 0.0)


func repair_hull(amount: float) -> Dictionary:
	# Summary: Apply approved hull repair to this adapter side without spending inventory here.
	var repair_amount: float = max(float(amount), 0.0)
	var hull_before := player_hull_current
	var hull_after := player_hull_current

	if unit_side == "enemy":
		hull_before = enemy_hull_current
		enemy_hull_current = min(enemy_hull_current + repair_amount, enemy_hull_max)
		hull_after = enemy_hull_current
	else:
		hull_before = player_hull_current
		player_hull_current = min(player_hull_current + repair_amount, player_hull_max)
		hull_after = player_hull_current

	return {
		"status": "success",
		"repair_amount": repair_amount,
		"hull_before": hull_before,
		"hull_after": hull_after,
		"hull_repaired": max(hull_after - hull_before, 0.0),
		"labels": ["battle_unit_adapter", "repair_hull"]
	}


func apply_shield_damage(amount: float) -> void:
	# Summary: Apply shield damage to the adapter shield pool.
	var damage: float = max(float(amount), 0.0)
	shield_hp_current = max(shield_hp_current - damage, 0.0)


func set_player_lock_good() -> void:
	# Summary: Mark player lock as good.
	player_good_lock = true
	player_lock_pending = false


func set_player_lock_lost() -> void:
	# Summary: Mark player lock as lost.
	player_good_lock = false
	player_lock_pending = false


func set_player_lock_pending(value: bool) -> void:
	# Summary: Mark player lock as pending or not pending.
	player_lock_pending = value


func set_enemy_lock_good() -> void:
	# Summary: Mark enemy lock as good.
	enemy_good_lock = true
	enemy_lock_pending = false


func set_enemy_lock_lost() -> void:
	# Summary: Mark enemy lock as lost.
	enemy_good_lock = false
	enemy_lock_pending = false


func set_enemy_lock_pending(value: bool) -> void:
	# Summary: Mark enemy lock as pending or not pending.
	enemy_lock_pending = value


func set_selected_shield(new_shield: Variant) -> void:
	# Summary: Assign the selected shield object or packet.
	var previous_shield_id := get_shield_item_id(selected_shield)
	var new_shield_id := get_shield_item_id(new_shield)
	selected_shield = new_shield

	# ------------------------------------------------------
	# Shield packets carry their prototype max HP in the
	# normalized item dictionary used by Battle V2.
	# ------------------------------------------------------
	if typeof(new_shield) == TYPE_DICTIONARY:
		var shield_packet: Dictionary = new_shield as Dictionary
		shield_hp_max = float(shield_packet.get("shield_hp_max", shield_packet.get("hp_max", shield_hp_max)))
		if new_shield_id != previous_shield_id:
			shield_hp_current = shield_hp_max
		if unit_side == "enemy":
			selected_enemy_shield = new_shield_id
	elif new_shield == null:
		shield_hp_current = 0.0
		shield_hp_max = 0.0
		if unit_side == "enemy":
			selected_enemy_shield = ""


func set_shield_switching(value: bool) -> void:
	# Summary: Mark shield switching state.
	shield_switching = value


func set_shield_power_level(value: int) -> void:
	# Summary: Set the shield output slider level for battle logic and drain sync.
	shield_power_level = int(clamp(value, 0, 4))


func remove_shield_for_energy_empty() -> void:
	# Summary: Power down and clear the enemy shield when energy is empty.
	selected_shield = null
	pending_shield = null
	selected_enemy_shield = ""
	shield_power_level = 0
	shield_hp_current = 0.0
	shield_hp_max = 0.0
	shield_switching = false


func repair_shield(amount: float) -> Dictionary:
	# Summary: Repair only an equipped shield that remains above zero HP.
	var repair_amount = max(float(amount), 0.0)
	var before := shield_hp_current
	var result := {
		"status": "blocked",
		"shield_repaired": 0.0,
		"shield_before": before,
		"shield_after": before,
		"blocked_reason": "none",
		"labels": ["battle_unit_adapter_shield_repair"]
	}
	if get_shield_item_id(selected_shield) == "":
		result["blocked_reason"] = "missing_selected_shield"
		return result
	if shield_hp_current <= 0.0:
		result["blocked_reason"] = "shield_broken_not_repairable"
		result["labels"].append("shield_repair_blocked_broken")
		return result
	if repair_amount <= 0.0:
		result["blocked_reason"] = "missing_shield_repair_amount"
		return result
	if shield_hp_current >= shield_hp_max:
		result["blocked_reason"] = "shield_not_damaged"
		return result

	shield_hp_current = min(shield_hp_current + repair_amount, shield_hp_max)
	result["status"] = "success"
	result["shield_after"] = shield_hp_current
	result["shield_repaired"] = max(shield_hp_current - before, 0.0)
	result["labels"].append("shield_repair_applied")
	return result


func clear_broken_shield(expected_item_id: String = "") -> Dictionary:
	# Summary: Clear a broken equipped shield while inventory ownership is handled by BattleManager.
	var current_id := get_shield_item_id(selected_shield)
	var result := {
		"status": "success",
		"shield_item_id": current_id,
		"cleared": false,
		"blocked_reason": "none",
		"labels": ["battle_unit_adapter_shield_break_clear"]
	}
	if expected_item_id.strip_edges() != "" and current_id != expected_item_id.strip_edges():
		result["status"] = "blocked"
		result["blocked_reason"] = "selected_shield_changed"
		return result

	selected_shield = null
	pending_shield = null
	selected_enemy_shield = ""
	shield_switching = false
	shield_power_level = 0
	shield_hp_current = 0.0
	shield_hp_max = 0.0
	result["cleared"] = true
	result["labels"].append("shield_runtime_state_cleared")
	return result


func get_shield_item_id(value: Variant) -> String:
	if value == null:
		return ""
	if typeof(value) == TYPE_DICTIONARY:
		var packet: Dictionary = value as Dictionary
		return str(packet.get("item_id", packet.get("id", ""))).strip_edges()
	return str(value).strip_edges()


func get_shield_packet_max_hp(value: Variant, fallback: float = 0.0) -> float:
	if typeof(value) == TYPE_DICTIONARY:
		var packet: Dictionary = value as Dictionary
		return float(packet.get("shield_hp_max", packet.get("hp_max", fallback)))
	return fallback


func set_loaded_consumable(consumable: Variant, state: String = "") -> void:
	# Summary: Store a loaded/prepped/ready consumable packet without changing inventory counts.
	loaded_consumable = consumable
	if consumable == null:
		loaded_consumable_state = "none"
		consumable_ready = false
		mirror_enemy_loaded_consumable_fields()
		return

	var clean_state := state.strip_edges().to_lower()
	if clean_state == "":
		clean_state = "loaded"
	loaded_consumable_state = clean_state
	consumable_ready = clean_state == "ready"
	mirror_enemy_loaded_consumable_fields()


func set_consumable_state(state: String) -> void:
	# Summary: Update the loaded consumable state without spending inventory.
	loaded_consumable_state = state.strip_edges().to_lower()
	consumable_ready = loaded_consumable_state == "ready"
	mirror_enemy_loaded_consumable_fields()


func clear_loaded_consumable_after_spend() -> void:
	# Summary: Clear the loaded consumable after its execute TODO has spent inventory.
	loaded_consumable = null
	loaded_consumable_state = "none"
	consumable_ready = false
	mirror_enemy_loaded_consumable_fields()


func clear_loaded_consumable_without_spend() -> void:
	# Summary: Placeholder cleanup hook for BattleManager battle-end cleanup.
	clear_loaded_consumable_after_spend()


func mirror_enemy_loaded_consumable_fields() -> void:
	# Summary: Keep legacy enemy-specific consumable mirrors aligned with the generic loaded slot.
	if unit_side != "enemy":
		return
	enemy_loaded_consumable = loaded_consumable
	enemy_consumable_ready = consumable_ready


func get_enemy_item_count(item_id: String) -> int:
	# Summary: Return the enemy-held stack count for an item id.
	var clean_id := item_id.strip_edges()
	if clean_id == "":
		return 0
	return max(int(enemy_item_stacks.get(clean_id, 0)), 0)


func consume_enemy_item(item_id: String, amount: int = 1) -> bool:
	# Summary: Spend enemy-held stackable items such as ammo or consumables.
	var clean_id := item_id.strip_edges()
	var clean_amount: int = max(amount, 0)
	if clean_id == "" or clean_amount <= 0:
		return clean_amount <= 0

	var available := get_enemy_item_count(clean_id)
	if available < clean_amount:
		return false

	enemy_item_stacks[clean_id] = available - clean_amount
	if int(enemy_item_stacks[clean_id]) <= 0:
		enemy_item_stacks.erase(clean_id)
	return true


func add_enemy_item(item_id: String, amount: int = 1) -> void:
	# Summary: Return enemy-held items to their stack after a rejected queue.
	var clean_id := item_id.strip_edges()
	var clean_amount: int = max(amount, 0)
	if clean_id == "" or clean_amount <= 0:
		return
	enemy_item_stacks[clean_id] = get_enemy_item_count(clean_id) + clean_amount

func bind_world_enemy(enemy_ref: Variant, enemy_id: String = "") -> void:
	# Summary: Stores the original world enemy reference so Battle V2 can remove it after victory.
	source_world_enemy = enemy_ref
	source_enemy_id = enemy_id
	
func get_source_world_enemy() -> Variant:
	# Summary: Returns the original world enemy reference used for post-battle world cleanup.
	return source_world_enemy


func get_source_enemy_id() -> String:
	# Summary: Returns the tracked world enemy id captured during battle handoff.
	return source_enemy_id


func sync_shared_meta() -> Dictionary:
	# Summary: Keep generic object/event/lore fields aligned with the battle adapter identity.
	if object_id.strip_edges() == "":
		object_id = unit_id
	if display_name.strip_edges() == "":
		display_name = unit_id

	var source := shared_meta.duplicate(true)
	source["tier"] = tier
	source["enemy_serial"] = enemy_serial
	source["enemy_template_id"] = enemy_template_id
	source["section_id"] = section_id
	source["is_visible"] = is_visible
	source["is_discovered"] = is_discovered
	source["is_completed"] = is_completed
	source["has_event"] = has_event
	source["give_event"] = give_event
	source["requires_event"] = requires_event
	source["has_run_lore"] = has_run_lore
	source["run_lore_id"] = run_lore_id
	source["has_universe_lore"] = has_universe_lore
	source["universe_lore_id"] = universe_lore_id
	source["has_gift"] = has_gift
	source["gift_id"] = gift_id
	source["labels"] = labels.duplicate(true)

	shared_meta = SharedObjectMeta.build_meta(object_id, object_type, display_name, sector_pos, local_pos, source)
	apply_shared_meta(shared_meta, false)
	return shared_meta


func apply_shared_meta(meta_data: Dictionary, update_position: bool = true) -> void:
	# Summary: Load shared object fields for Battle V2 handoffs without resolving outcomes.
	var preferred_object_id := object_id
	if preferred_object_id.strip_edges() == "" and meta_data.has("object_id"):
		preferred_object_id = str(meta_data.get("object_id", ""))
	if preferred_object_id.strip_edges() == "":
		preferred_object_id = unit_id
	var meta := SharedObjectMeta.build_meta(preferred_object_id, str(meta_data.get("object_type", object_type)), display_name, sector_pos, local_pos, meta_data)
	object_id = str(meta.get("object_id", object_id))
	object_type = str(meta.get("object_type", object_type))
	display_name = str(meta.get("display_name", display_name))
	enemy_serial = str(meta.get("enemy_serial", enemy_serial))
	enemy_template_id = str(meta.get("enemy_template_id", enemy_template_id))
	tier = int(meta.get("tier", tier))
	section_id = str(meta.get("section_id", section_id))
	is_visible = bool(meta.get("is_visible", is_visible))
	is_discovered = bool(meta.get("is_discovered", is_discovered))
	is_completed = bool(meta.get("is_completed", is_completed))
	has_event = bool(meta.get("has_event", has_event))
	give_event = str(meta.get("give_event", give_event))
	requires_event = str(meta.get("requires_event", requires_event))
	has_run_lore = bool(meta.get("has_run_lore", has_run_lore))
	run_lore_id = str(meta.get("run_lore_id", run_lore_id))
	has_universe_lore = bool(meta.get("has_universe_lore", has_universe_lore))
	universe_lore_id = str(meta.get("universe_lore_id", universe_lore_id))
	has_gift = bool(meta.get("has_gift", has_gift))
	gift_id = str(meta.get("gift_id", gift_id))
	labels = SharedObjectMeta.read_array(meta.get("labels", labels))

	if update_position:
		sector_pos = SharedObjectMeta.read_sector_pos(meta.get("sector_pos", sector_pos))
		local_pos = SharedObjectMeta.read_local_pos(meta.get("local_pos", local_pos))

	shared_meta = meta
	if Globals.print_priority_6:
		print(str(shared_meta))

func get_shared_meta_save_data() -> Dictionary:
	# Summary: Return a JSON-safe shared-meta packet for battle results.
	return SharedObjectMeta.to_save_data(sync_shared_meta())
