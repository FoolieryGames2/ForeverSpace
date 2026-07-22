extends Node
class_name PlayerState


# ==========================================================
# PLAYER STATE
# ----------------------------------------------------------
# Stores player-side battle condition for Battle V2.
# This script does not resolve outcomes, spend energy, or own
# inventory counts. Other handlers decide outcomes and call the
# safe mutation helpers here.
# ==========================================================

var unit_id: String = "player"
var unit_name: String = "Player"
var display_name: String = "Player"
var unit_side: String = "player"

var battle_active: bool = false
var is_alive: bool = true
var is_destroyed: bool = false
var removed_from_battle: bool = false

var hull_current: float = 300.0
var hull_max: float = 300.0
var player_hull_current: float = 300.0
var player_hull_max: float = 300.0
var low_hp_warning_triggered: bool = false

var energy_current: float = 100.0
var energy_max: float = 100.0
var energy_regen_per_second: float = 12.0
var player_energy_current: float = 100.0
var player_energy_max: float = 100.0
var player_energy_regen_per_second: float = 8.0

var shield_hp_current: float = 0.0
var shield_hp_max: float = 0.0
var selected_shield: Variant = null
var pending_shield: Variant = null
var shield_switching: bool = false
var shield_power_level: int = 0
var shield_disabled: bool = false

var player_good_lock: bool = false
var player_lock_disabled: bool = false
var player_lock_pending: bool = false
var enemy_good_lock: bool = false
var enemy_lock_disabled: bool = false
var enemy_lock_pending: bool = false

var selected_primary_weapon: Variant = null
var selected_secondary_weapon: Variant = null
var primary_disabled: bool = false
var secondary_disabled: bool = false

var loaded_consumable: Variant = null
var prepped_consumable: Variant = null
var ready_consumable: Variant = null
var loaded_consumable_state: String = "none"
var ready_consumables: Array = []
var executed_consumables_pending: Array = []
var consumable_ready: bool = false
var consumable_disabled: bool = false
var equipped_upgrades: Array = []

var active_signal_effect: Variant = null
var temporary_battle_flags: Dictionary = {}
var battle_loadout: Dictionary = {
	"selected_primary_weapon": "",
	"selected_secondary_weapon": "",
	"selected_shield": "",
	"loaded_consumable": "",
	"loaded_consumable_state": "none",
	"equipped_upgrades": [],
	"shield_power_level": 0,
	"default_shield_power_level": 2
}


func get_default_battle_loadout() -> Dictionary:
	return {
		"selected_primary_weapon": "",
		"selected_secondary_weapon": "",
		"selected_shield": "",
		"loaded_consumable": "",
		"loaded_consumable_state": "none",
		"equipped_upgrades": [],
		"shield_power_level": 0,
		"default_shield_power_level": 2
	}


func get_battle_loadout_save_data() -> Dictionary:
	battle_loadout = normalize_battle_loadout_data(battle_loadout)
	return battle_loadout.duplicate(true)


func set_battle_loadout_save_data(data: Dictionary) -> void:
	# Summary: Restore/equip the saved loadout ids without trusting stale runtime shield HP.
	var previous_shield_id := get_battle_loadout_item_id(selected_shield)
	battle_loadout = normalize_battle_loadout_data(data)

	selected_primary_weapon = battle_loadout.get("selected_primary_weapon", "")
	selected_secondary_weapon = battle_loadout.get("selected_secondary_weapon", "")
	selected_shield = battle_loadout.get("selected_shield", "")
	loaded_consumable = battle_loadout.get("loaded_consumable", "")
	loaded_consumable_state = str(battle_loadout.get("loaded_consumable_state", "none"))
	equipped_upgrades = sanitize_battle_loadout_upgrade_ids(battle_loadout.get("equipped_upgrades", []))
	consumable_ready = loaded_consumable_state == "ready"
	shield_power_level = int(battle_loadout.get("shield_power_level", shield_power_level))

	var current_shield_id := get_battle_loadout_item_id(selected_shield)
	if current_shield_id == "":
		shield_hp_current = 0.0
		shield_hp_max = 0.0
	elif previous_shield_id != "" and previous_shield_id != current_shield_id:
		# A newly selected shield id must not inherit the previous shield's HP pool.
		# main_mode hydrates the new max/current values from item_db immediately after save/load.
		shield_hp_current = 0.0
		shield_hp_max = 0.0


func normalize_battle_loadout_data(data: Dictionary) -> Dictionary:
	var normalized := get_default_battle_loadout()

	if typeof(data) != TYPE_DICTIONARY:
		return normalized

	normalized["selected_primary_weapon"] = get_battle_loadout_item_id(data.get("selected_primary_weapon", ""))
	normalized["selected_secondary_weapon"] = get_battle_loadout_item_id(data.get("selected_secondary_weapon", ""))
	normalized["selected_shield"] = get_battle_loadout_item_id(data.get("selected_shield", ""))
	normalized["loaded_consumable"] = get_battle_loadout_item_id(data.get("loaded_consumable", ""))
	normalized["equipped_upgrades"] = sanitize_battle_loadout_upgrade_ids(data.get("equipped_upgrades", []))
	normalized["shield_power_level"] = int(clamp(int(data.get("shield_power_level", normalized["shield_power_level"])), 0, 4))
	normalized["default_shield_power_level"] = int(clamp(int(data.get("default_shield_power_level", normalized["default_shield_power_level"])), 0, 4))

	var consumable_state := str(data.get("loaded_consumable_state", normalized["loaded_consumable_state"])).strip_edges().to_lower()
	if str(normalized["loaded_consumable"]).strip_edges() == "":
		consumable_state = "none"
	elif consumable_state == "" or consumable_state == "none":
		consumable_state = "ready"
	normalized["loaded_consumable_state"] = consumable_state

	return normalized


func sanitize_battle_loadout_upgrade_ids(upgrades) -> Array:
	# Summary: Keep save-state upgrade slots as a compact, duplicate-free string array.
	var clean: Array = []
	if typeof(upgrades) != TYPE_ARRAY:
		return clean

	for raw_id in upgrades:
		var upgrade_id := get_battle_loadout_item_id(raw_id)
		if upgrade_id == "":
			continue
		if clean.has(upgrade_id):
			continue
		clean.append(upgrade_id)
		if clean.size() >= 3:
			break

	return clean


func set_equipped_upgrades(upgrades: Array) -> void:
	equipped_upgrades = sanitize_battle_loadout_upgrade_ids(upgrades)
	battle_loadout["equipped_upgrades"] = equipped_upgrades.duplicate(true)


func get_battle_loadout_item_id(value: Variant) -> String:
	if value == null:
		return ""

	if typeof(value) == TYPE_DICTIONARY:
		var packet: Dictionary = value as Dictionary
		return str(packet.get("item_id", packet.get("id", ""))).strip_edges()

	var text := str(value).strip_edges()
	if text == "" or text == "<null>" or text.to_lower() == "null":
		return ""

	return text


func read_float_alias(data: Dictionary, keys: Array, fallback: float = 0.0) -> float:
	# Summary: Read a float from multiple accepted packet/save aliases.
	if typeof(data) != TYPE_DICTIONARY:
		return fallback

	for key in keys:
		var clean_key := str(key).strip_edges()
		if clean_key == "":
			continue
		if data.has(clean_key):
			return float(data.get(clean_key, fallback))

	return fallback


func read_shield_max_from_item_data(shield_data: Dictionary, fallback: float = 0.0) -> float:
	# Summary: Support the shield max names currently used by items, battle packets, and older saves.
	return read_float_alias(
		shield_data,
		[
			"shield_hp_max",
			"player_shield_hp_max",
			"shield_max",
			"player_shield_max",
			"max_shield",
			"max_shield_hp",
			"hp_max"
		],
		fallback
	)


func apply_selected_shield_runtime_data(shield_item_id: String, shield_data: Dictionary, refill_when_runtime_missing: bool = true) -> Dictionary:
	# Summary: Hydrate runtime shield HP from item_db after a saved/equipped shield id is known.
	var clean_id := shield_item_id.strip_edges()
	var result := {
		"status": "blocked",
		"reason": "",
		"shield_item_id": clean_id,
		"shield_hp_current": shield_hp_current,
		"shield_hp_max": shield_hp_max,
		"labels": ["player_state_shield_runtime_hydration"]
	}

	if clean_id == "":
		result["reason"] = "missing_shield_item_id"
		return result
	if typeof(shield_data) != TYPE_DICTIONARY or shield_data.is_empty():
		result["reason"] = "missing_shield_item_data"
		return result

	var max_hp = max(read_shield_max_from_item_data(shield_data, 0.0), 0.0)
	if max_hp <= 0.0:
		result["reason"] = "missing_shield_hp_max"
		return result

	var previous_max := shield_hp_max
	selected_shield = clean_id
	battle_loadout["selected_shield"] = clean_id
	shield_hp_max = max_hp

	if previous_max <= 0.0 and shield_hp_current <= 0.0 and refill_when_runtime_missing:
		# Migration/equip safety: old saves and first-time equip had no runtime shield HP lane.
		shield_hp_current = shield_hp_max
	else:
		shield_hp_current = clamp(shield_hp_current, 0.0, shield_hp_max)

	result["status"] = "success"
	result["reason"] = ""
	result["shield_hp_current"] = shield_hp_current
	result["shield_hp_max"] = shield_hp_max
	result["labels"].append("player_state_shield_runtime_hydrated")
	return result


func start_battle_state() -> void:
	# Summary: Mark the player as participating in battle without changing permanent state.
	battle_active = true
	removed_from_battle = false
	_sync_player_hull_aliases()
	_sync_player_energy_aliases()


func end_battle_state() -> void:
	# Summary: Mark battle participation finished while preserving permanent player state.
	battle_active = false
	_sync_player_hull_aliases()
	_sync_player_energy_aliases()


func clear_temporary_battle_state() -> void:
	# Summary: Clear temporary battle-only flags while preserving equipped loadout and inventory-owned counts.
	player_lock_pending = false
	enemy_lock_pending = false
	shield_switching = false
	pending_shield = null
	active_signal_effect = null
	temporary_battle_flags.clear()


func clear_safe_consumables_on_battle_end() -> void:
	# Summary: Clear loaded, prepped, and ready consumable state without touching inventory counts.
	loaded_consumable = null
	prepped_consumable = null
	ready_consumable = null
	loaded_consumable_state = "none"
	ready_consumables.clear()
	executed_consumables_pending.clear()
	consumable_ready = false


func clear_loaded_consumable_without_spend() -> void:
	# Summary: BattleManager cleanup hook that clears consumable state without inventory mutation.
	clear_safe_consumables_on_battle_end()


func set_selected_primary_weapon(weapon: Variant) -> void:
	# Summary: Store the equipped primary weapon reference or id.
	selected_primary_weapon = weapon


func set_selected_secondary_weapon(weapon: Variant) -> void:
	# Summary: Store the equipped secondary weapon reference or id.
	selected_secondary_weapon = weapon


func set_selected_shield(new_shield: Variant) -> void:
	# Summary: Store the equipped shield reference or packet.
	var previous_shield_id := get_battle_loadout_item_id(selected_shield)
	var new_shield_id := get_battle_loadout_item_id(new_shield)
	selected_shield = new_shield

	if typeof(new_shield) == TYPE_DICTIONARY:
		var shield_packet: Dictionary = new_shield as Dictionary
		shield_hp_max = read_shield_max_from_item_data(shield_packet, shield_hp_max)
		if new_shield_id != previous_shield_id:
			shield_hp_current = shield_hp_max
	elif new_shield == null or new_shield_id == "":
		shield_hp_current = 0.0
		shield_hp_max = 0.0

	battle_loadout["selected_shield"] = new_shield_id


func set_pending_shield(new_shield: Variant) -> void:
	# Summary: Store a shield waiting for a completed shield-switch TODO.
	pending_shield = new_shield
	shield_switching = new_shield != null


func set_shield_switching(value: bool) -> void:
	# Summary: Mark whether a shield switch is currently pending.
	shield_switching = value


func set_shield_power_level(value: int) -> void:
	# Summary: Store the Battle V2 shield slider level without doing energy math.
	shield_power_level = int(clamp(value, 0, 4))


func set_loaded_consumable(consumable: Variant, state: String = "") -> void:
	# Summary: Store the loaded consumable reference or id without changing inventory counts.
	loaded_consumable = consumable

	if consumable == null:
		loaded_consumable_state = "none"
		consumable_ready = false
		return

	if state.strip_edges() == "":
		loaded_consumable_state = "loaded"
	else:
		loaded_consumable_state = state

	consumable_ready = loaded_consumable_state == "ready"


func set_consumable_state(state: String) -> void:
	# Summary: Update the consumable readiness state without spending or loading inventory items.
	loaded_consumable_state = state
	consumable_ready = state == "ready"


func set_primary_disabled(value: bool) -> void:
	# Summary: Store primary weapon disabled state from the system that owns active effects.
	primary_disabled = value


func set_secondary_disabled(value: bool) -> void:
	# Summary: Store secondary weapon disabled state from the system that owns active effects.
	secondary_disabled = value


func set_consumable_disabled(value: bool) -> void:
	# Summary: Store consumable disabled state from the system that owns active effects.
	consumable_disabled = value


func set_shield_disabled(value: bool) -> void:
	# Summary: Store shield disabled state from the system that owns active effects.
	shield_disabled = value


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


func apply_hull_damage(amount: float) -> void:
	# Summary: Apply already-resolved hull damage from BattleManager.
	var damage: float = max(float(amount), 0.0)
	hull_current = max(hull_current - damage, 0.0)
	_sync_destroyed_state()
	_sync_player_hull_aliases()


func repair_hull(amount: float) -> void:
	# Summary: Apply already-approved hull repair from an owning repair handler.
	var repair_amount: float = max(float(amount), 0.0)
	hull_current = min(hull_current + repair_amount, hull_max)
	_sync_destroyed_state()
	_sync_player_hull_aliases()


func restore_energy(amount: float) -> Dictionary:
	# Summary: Apply already-approved main-mode/battle energy restoration.
	var restore_amount = max(float(amount), 0.0)
	var before := energy_current
	var result := {
		"status": "blocked",
		"energy_restored": 0.0,
		"energy_before": before,
		"energy_after": before,
		"blocked_reason": "none",
		"labels": ["player_state_energy_restore"]
	}
	if restore_amount <= 0.0:
		result["blocked_reason"] = "missing_energy_restore_amount"
		return result
	if energy_current >= energy_max:
		result["blocked_reason"] = "energy_not_depleted"
		return result

	energy_current = min(energy_current + restore_amount, energy_max)
	_sync_player_energy_aliases()
	result["status"] = "success"
	result["energy_after"] = energy_current
	result["energy_restored"] = max(energy_current - before, 0.0)
	result["labels"].append("energy_restore_applied")
	return result


func apply_shield_damage(amount: float) -> void:
	# Summary: Apply already-resolved shield damage from BattleManager.
	var damage: float = max(float(amount), 0.0)
	shield_hp_current = max(shield_hp_current - damage, 0.0)


func repair_shield(amount: float) -> Dictionary:
	# Summary: Repair only an equipped shield that still has positive HP.
	var repair_amount = max(float(amount), 0.0)
	var before := shield_hp_current
	var result := {
		"status": "blocked",
		"shield_repaired": 0.0,
		"shield_before": before,
		"shield_after": before,
		"blocked_reason": "none",
		"labels": ["player_state_shield_repair"]
	}
	if get_battle_loadout_item_id(selected_shield) == "":
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
	# Summary: Clear a zero-HP equipped shield without mutating inventory ownership.
	var current_id := get_battle_loadout_item_id(selected_shield)
	var result := {
		"status": "success",
		"shield_item_id": current_id,
		"cleared": false,
		"blocked_reason": "none",
		"labels": ["player_state_shield_break_clear"]
	}
	if expected_item_id.strip_edges() != "" and current_id != expected_item_id.strip_edges():
		result["status"] = "blocked"
		result["blocked_reason"] = "selected_shield_changed"
		return result

	selected_shield = null
	pending_shield = null
	shield_switching = false
	shield_hp_current = 0.0
	shield_hp_max = 0.0
	shield_power_level = 0
	battle_loadout["selected_shield"] = ""
	battle_loadout["shield_power_level"] = 0
	result["cleared"] = true
	result["labels"].append("shield_runtime_state_cleared")
	return result


func set_energy_values(current_value: float, max_value: float, regen_value: float = -1.0) -> void:
	# Summary: Store starting player energy values; EnergyHandler owns runtime battle math.
	energy_max = max(float(max_value), 0.0)
	if energy_max <= 0.0:
		energy_max = max(float(current_value), 1.0)
	energy_current = clamp(float(current_value), 0.0, energy_max)
	if regen_value >= 0.0:
		energy_regen_per_second = max(float(regen_value), 0.0)
	_sync_player_energy_aliases()


func get_energy_start_packet() -> Dictionary:
	# Summary: Return the player energy seed packet used to configure EnergyHandler at battle start.
	_sync_player_energy_aliases()
	return {
		"energy_current": energy_current,
		"energy_max": energy_max,
		"energy_regen_per_second": energy_regen_per_second,
		"player_energy_current": player_energy_current,
		"player_energy_max": player_energy_max,
		"player_energy_regen_per_second": player_energy_regen_per_second,
		"labels": ["player_state_energy_seed", "energy_handler_starting_values"]
	}


func get_state_packet() -> Dictionary:
	# Summary: Return a read-only style snapshot for handlers that need player battle state.
	_sync_player_hull_aliases()
	_sync_player_energy_aliases()
	_sync_destroyed_state()

	var packet := {
		"unit_id": unit_id,
		"unit_name": unit_name,
		"display_name": display_name,
		"unit_side": unit_side,
		"battle_active": battle_active,
		"is_alive": is_alive,
		"is_destroyed": is_destroyed,
		"removed_from_battle": removed_from_battle,
		"hull_current": hull_current,
		"hull_max": hull_max,
		"player_hull_current": player_hull_current,
		"player_hull_max": player_hull_max,
		"energy_current": energy_current,
		"energy_max": energy_max,
		"energy_regen_per_second": energy_regen_per_second,
		"player_energy_current": player_energy_current,
		"player_energy_max": player_energy_max,
		"player_energy_regen_per_second": player_energy_regen_per_second,
		"shield_hp_current": shield_hp_current,
		"shield_hp_max": shield_hp_max,
		"player_shield_hp_current": shield_hp_current,
		"player_shield_hp_max": shield_hp_max,
		"shield_current": shield_hp_current,
		"shield_max": shield_hp_max,
		"player_shield_current": shield_hp_current,
		"player_shield_max": shield_hp_max,
		"shield_disabled": shield_disabled,
		"selected_primary_weapon": selected_primary_weapon,
		"selected_secondary_weapon": selected_secondary_weapon,
		"selected_shield": selected_shield,
		"loaded_consumable": loaded_consumable,
		"loaded_consumable_state": loaded_consumable_state,
		"equipped_upgrades": equipped_upgrades.duplicate(true),
		"shield_power_level": shield_power_level,
		"labels": [
			"unit_id",
			"unit_name",
			"unit_side",
			"unit_state_packet",
			"unit_alive",
			"unit_destroyed",
			"unit_battle_active",
			"unit_removed_from_battle"
		]
	}

	return SharedObjectMeta.apply_to_dictionary(packet, unit_id, "battle_unit", display_name, Vector3i.ZERO, Vector3.ZERO)


func get_save_data() -> Dictionary:
	# Summary: Save only persistent player condition. Do not save live battle-only state.
	_sync_player_hull_aliases()
	_sync_player_energy_aliases()
	_sync_destroyed_state()

	var loadout_data := get_battle_loadout_save_data()
	var data := {
		"schema_version": 1,
		"unit_id": unit_id,
		"unit_name": unit_name,
		"display_name": display_name,
		"unit_side": unit_side,
		"is_alive": is_alive,
		"is_destroyed": is_destroyed,
		"hull_current": hull_current,
		"hull_max": hull_max,
		"player_hull_current": player_hull_current,
		"player_hull_max": player_hull_max,
		"low_hp_warning_triggered": low_hp_warning_triggered,
		"energy_current": energy_current,
		"energy_max": energy_max,
		"energy_regen_per_second": energy_regen_per_second,
		"player_energy_current": player_energy_current,
		"player_energy_max": player_energy_max,
		"player_energy_regen_per_second": player_energy_regen_per_second,
		"shield_hp_current": shield_hp_current,
		"shield_hp_max": shield_hp_max,
		"player_shield_hp_current": shield_hp_current,
		"player_shield_hp_max": shield_hp_max,
		"shield_current": shield_hp_current,
		"shield_max": shield_hp_max,
		"player_shield_current": shield_hp_current,
		"player_shield_max": shield_hp_max,
		"shield_power_level": shield_power_level,
		"shield_disabled": shield_disabled,
		"primary_disabled": primary_disabled,
		"secondary_disabled": secondary_disabled,
		"consumable_disabled": consumable_disabled,
		"battle_loadout": loadout_data.duplicate(true),
		"selected_primary_weapon": loadout_data.get("selected_primary_weapon", ""),
		"selected_secondary_weapon": loadout_data.get("selected_secondary_weapon", ""),
		"selected_shield": loadout_data.get("selected_shield", ""),
		"loaded_consumable": loadout_data.get("loaded_consumable", ""),
		"loaded_consumable_state": loadout_data.get("loaded_consumable_state", "none"),
		"default_shield_power_level": int(loadout_data.get("default_shield_power_level", 2))
	}

	data["shield_power_level"] = int(loadout_data.get("shield_power_level", shield_power_level))
	return data


func load_save_data(data: Dictionary):
	# Summary: Restore persistent player condition from the universe save.
	if typeof(data) != TYPE_DICTIONARY:
		if Globals.print_priority_1:
			print("PlayerState.load_save_data blocked: data was not Dictionary.")
		return

	unit_id = str(data.get("unit_id", unit_id))
	unit_name = str(data.get("unit_name", unit_name))
	display_name = str(data.get("display_name", display_name))
	unit_side = str(data.get("unit_side", unit_side))

	hull_max = max(float(data.get("hull_max", data.get("player_hull_max", hull_max))), 1.0)
	hull_current = clamp(float(data.get("hull_current", data.get("player_hull_current", hull_current))), 0.0, hull_max)
	low_hp_warning_triggered = bool(data.get("low_hp_warning_triggered", low_hp_warning_triggered))

	energy_max = max(float(data.get("energy_max", data.get("player_energy_max", energy_max))), 1.0)
	energy_current = clamp(float(data.get("energy_current", data.get("player_energy_current", energy_current))), 0.0, energy_max)
	energy_regen_per_second = max(float(data.get("energy_regen_per_second", data.get("player_energy_regen_per_second", energy_regen_per_second))), 0.0)

	shield_hp_max = max(read_float_alias(data, ["shield_hp_max", "player_shield_hp_max", "shield_max", "player_shield_max", "max_shield", "max_shield_hp"], shield_hp_max), 0.0)
	shield_hp_current = clamp(read_float_alias(data, ["shield_hp_current", "player_shield_hp_current", "shield_current", "player_shield_current", "current_shield", "shield"], shield_hp_current), 0.0, shield_hp_max)
	shield_power_level = int(clamp(int(data.get("shield_power_level", shield_power_level)), 0, 4))
	shield_disabled = bool(data.get("shield_disabled", shield_disabled))

	primary_disabled = bool(data.get("primary_disabled", primary_disabled))
	secondary_disabled = bool(data.get("secondary_disabled", secondary_disabled))
	consumable_disabled = bool(data.get("consumable_disabled", consumable_disabled))

	selected_primary_weapon = data.get("selected_primary_weapon", selected_primary_weapon)
	selected_secondary_weapon = data.get("selected_secondary_weapon", selected_secondary_weapon)
	selected_shield = data.get("selected_shield", selected_shield)

	if data.has("battle_loadout") and typeof(data["battle_loadout"]) == TYPE_DICTIONARY:
		set_battle_loadout_save_data(data["battle_loadout"])
	else:
		set_battle_loadout_save_data({
			"selected_primary_weapon": data.get("selected_primary_weapon", ""),
			"selected_secondary_weapon": data.get("selected_secondary_weapon", ""),
			"selected_shield": data.get("selected_shield", ""),
			"loaded_consumable": data.get("loaded_consumable", ""),
			"loaded_consumable_state": data.get("loaded_consumable_state", "none"),
			"equipped_upgrades": data.get("equipped_upgrades", []),
			"shield_power_level": int(data.get("shield_power_level", shield_power_level)),
			"default_shield_power_level": int(data.get("default_shield_power_level", 2))
		})

	# Runtime battle flags should never resume as active from disk.
	battle_active = false
	removed_from_battle = false
	clear_temporary_battle_state()
	clear_safe_consumables_on_battle_end()

	_sync_player_hull_aliases()
	_sync_player_energy_aliases()
	_sync_destroyed_state()
	return data

func _make_json_safe_value(value: Variant) -> Variant:
	# Summary: Prevent live Nodes/Resources/callables from being written into JSON.
	var value_type := typeof(value)

	if value == null:
		return null

	if [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING].has(value_type):
		return value

	if value_type == TYPE_DICTIONARY:
		var safe_dict := {}
		var value_dict: Dictionary = value
		for key in value_dict.keys():
			safe_dict[str(key)] = _make_json_safe_value(value_dict[key])
		return safe_dict

	if value_type == TYPE_ARRAY:
		var safe_array := []
		for entry in value:
			safe_array.append(_make_json_safe_value(entry))
		return safe_array

	return null


func _sync_player_hull_aliases() -> void:
	# Summary: Keep BattleManager's current player-specific hull field names mirrored.
	player_hull_current = hull_current
	player_hull_max = hull_max


func _sync_player_energy_aliases() -> void:
	# Summary: Keep player-specific energy field names mirrored for save/load and Battle V2 startup.
	player_energy_current = energy_current
	player_energy_max = energy_max
	player_energy_regen_per_second = energy_regen_per_second


func _sync_destroyed_state() -> void:
	# Summary: Keep alive/destroyed flags aligned to hull after outside systems apply changes.
	if hull_current <= 0.0:
		is_destroyed = true
		is_alive = false
	else:
		is_destroyed = false
		is_alive = true
