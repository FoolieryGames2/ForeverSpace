extends Node
class_name EnemyBattleController


# ==========================================================
# ENEMY BATTLE CONTROLLER
# ----------------------------------------------------------
# Owns the active enemy think loop for Battle V2.
#
# This controller does NOT:
# - resolve damage
# - tick TODOs
# - spend resources
# - decide victory/defeat
#
# It does:
# - tick enemy think timing
# - build live state snapshots for EnemyLogic
# - ask PacketBuilder for enemy event packets
# - hand accepted packets to EventManager
# - apply small no-spam / cooldown gates
# ==========================================================

var battle_scene = null
var battle_id: String = ""
var enemy_logic: EnemyLogic = null
var battle_event_manager: BattleV2EventManager = null
var battle_action_manager: ActionManager_battle = null
var battle_manager = null
var active_enemy = null
var player_state = null
var enemy_energy_handler: EnergyHandler = null
var item_db_snapshot: Dictionary = {}
var log_label = null
var refresh_todo_callable: Callable = Callable()
var refresh_unit_callable: Callable = Callable()

var enemy_think_timer: float = 0.0
var enemy_think_interval: float = 1.25
var enemy_think_paused: bool = true
var enemy_action_cooldown_until_msec: int = 0
var enemy_wait_cooldown_seconds: float = 0.75
var enemy_action_cooldown_seconds: float = 1.25
var evade_cooldown_seconds: float = 15.0
var evade_duration_seconds: float = 15.0
var enemy_evade_cooldown_until_msec_by_key: Dictionary = {}
var enemy_primary_spam_gate_seconds: float = 3.0
var enemy_secondary_spam_gate_seconds: float = 1.0
var enemy_weapon_spam_gate_until_msec_by_key: Dictionary = {}


func setup(refs: Dictionary) -> void:
	# Summary: Link the battle scene refs this controller coordinates.
	battle_scene = refs.get("battle_scene", null)
	battle_id = str(refs.get("battle_id", ""))
	enemy_logic = refs.get("enemy_logic", null)
	battle_event_manager = refs.get("event_manager", null)
	battle_action_manager = refs.get("action_manager", null)
	battle_manager = refs.get("battle_manager", null)
	active_enemy = refs.get("active_enemy", null)
	player_state = refs.get("player_state", null)
	enemy_energy_handler = refs.get("enemy_energy_handler", null)
	var snapshot = refs.get("item_db_snapshot", {})
	if typeof(snapshot) == TYPE_DICTIONARY:
		item_db_snapshot = snapshot.duplicate(true)
	log_label = refs.get("log_label", null)
	refresh_todo_callable = refs.get("refresh_todo_callable", Callable())
	refresh_unit_callable = refs.get("refresh_unit_callable", Callable())
	enemy_think_interval = float(refs.get("think_interval", enemy_think_interval))
	enemy_wait_cooldown_seconds = float(refs.get("wait_cooldown_seconds", enemy_wait_cooldown_seconds))
	enemy_action_cooldown_seconds = float(refs.get("action_cooldown_seconds", enemy_action_cooldown_seconds))
	evade_cooldown_seconds = float(refs.get("evade_cooldown_seconds", evade_cooldown_seconds))
	evade_duration_seconds = float(refs.get("evade_duration_seconds", evade_duration_seconds))
	enemy_primary_spam_gate_seconds = float(refs.get("primary_spam_gate_seconds", enemy_primary_spam_gate_seconds))
	enemy_secondary_spam_gate_seconds = float(refs.get("secondary_spam_gate_seconds", enemy_secondary_spam_gate_seconds))


func refresh_refs(refs: Dictionary) -> void:
	# Summary: Refresh refs that can be created after setup or replaced during scene setup.
	if refs.has("battle_id"):
		battle_id = str(refs.get("battle_id", battle_id))
	if refs.has("enemy_logic"):
		enemy_logic = refs.get("enemy_logic", enemy_logic)
	if refs.has("event_manager"):
		battle_event_manager = refs.get("event_manager", battle_event_manager)
	if refs.has("action_manager"):
		battle_action_manager = refs.get("action_manager", battle_action_manager)
	if refs.has("battle_manager"):
		battle_manager = refs.get("battle_manager", battle_manager)
	if refs.has("active_enemy"):
		active_enemy = refs.get("active_enemy", active_enemy)
	if refs.has("player_state"):
		player_state = refs.get("player_state", player_state)
	if refs.has("enemy_energy_handler"):
		enemy_energy_handler = refs.get("enemy_energy_handler", enemy_energy_handler)
	if refs.has("item_db_snapshot") and typeof(refs.get("item_db_snapshot", {})) == TYPE_DICTIONARY:
		item_db_snapshot = refs.get("item_db_snapshot", {}).duplicate(true)
	if refs.has("log_label"):
		log_label = refs.get("log_label", log_label)
	if refs.has("evade_cooldown_seconds"):
		evade_cooldown_seconds = float(refs.get("evade_cooldown_seconds", evade_cooldown_seconds))
	if refs.has("evade_duration_seconds"):
		evade_duration_seconds = float(refs.get("evade_duration_seconds", evade_duration_seconds))
	if refs.has("primary_spam_gate_seconds"):
		enemy_primary_spam_gate_seconds = float(refs.get("primary_spam_gate_seconds", enemy_primary_spam_gate_seconds))
	if refs.has("secondary_spam_gate_seconds"):
		enemy_secondary_spam_gate_seconds = float(refs.get("secondary_spam_gate_seconds", enemy_secondary_spam_gate_seconds))


func start() -> void:
	# Summary: Start enemy initiative after Battle V2 refs are ready.
	enemy_think_timer = 0.15
	enemy_think_paused = false
	enemy_action_cooldown_until_msec = 0

	if Globals.print_priority_5:
		print("EnemyBattleController.start | Enemy thinking started.")


func stop() -> void:
	# Summary: Pause enemy thinking without clearing state snapshots.
	enemy_think_paused = true


func process_enemy_thinking(delta: float) -> Dictionary:
	# Summary: Tick enemy thought timing and queue one enemy event when ready.
	if enemy_think_paused:
		return _think_result("paused", "enemy thinking paused")

	if not can_enemy_think_now():
		return _think_result("held", "enemy cannot think now")

	enemy_think_timer -= delta
	if enemy_think_timer > 0.0:
		return _think_result("waiting", "think timer not ready")

	enemy_think_timer = enemy_think_interval
	var queue_result: Dictionary = queue_enemy_intent_from_logic()

	if Globals.print_priority_5:
		print("[enemy_think_result] ", queue_result)

	return queue_result


func can_enemy_think_now() -> bool:
	# Summary: No-spam gate for the active enemy battle loop.
	if is_battle_ended():
		return false
	if not Globals.battle_mode:
		return false
	if not can_continue_enemy_response_loop():
		return false
	if active_enemy == null:
		return false
	if player_state == null:
		return false
	if battle_event_manager == null:
		return false
	if battle_action_manager == null:
		return false
	if battle_action_manager.battle_action_packet_builder == null:
		return false
	if enemy_logic == null:
		return false
	if Time.get_ticks_msec() < enemy_action_cooldown_until_msec:
		return false
	if has_active_enemy_event():
		return false
	return true


func can_continue_enemy_response_loop() -> bool:
	# Summary: Stop enemy thinking after terminal hull or inactive battle state.
	if is_battle_ended():
		return false

	if battle_manager != null and battle_manager.get("battle_active") != null and not bool(battle_manager.get("battle_active")):
		return false

	if active_enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = active_enemy
		if enemy_state.enemy_hull_max > 0.0 and enemy_state.enemy_hull_current <= 0.0:
			return false

	if player_state is BattleV2UnitAdapter:
		var player_adapter: BattleV2UnitAdapter = player_state
		if player_adapter.player_hull_max > 0.0 and player_adapter.player_hull_current <= 0.0:
			return false

	return true


func has_active_enemy_event() -> bool:
	# Summary: True when EventManager already has an enemy-side TODO in flight.
	return not get_active_events_for_side("enemy").is_empty()


func get_active_events_for_side(side: String) -> Array:
	# Summary: Read active TODO packets for one side without mutating EventManager state.
	var output: Array = []
	if battle_event_manager == null:
		return output

	var clean_side := side.strip_edges().to_lower()
	if clean_side == "":
		return output

	for event_packet in battle_event_manager.active_events:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		if str(event_packet.get("lifecycle_state", "active")).strip_edges().to_lower() != "active":
			continue
		if str(event_packet.get("event_side", "")).strip_edges().to_lower() == clean_side:
			output.append(event_packet.duplicate(true))

	return output


func wake_after_player_event(completed_event: Dictionary) -> void:
	# Summary: Let completed player events wake the thinker without directly queueing enemy work.
	if typeof(completed_event) != TYPE_DICTIONARY:
		return
	if str(completed_event.get("event_side", "")).strip_edges().to_lower() != "player":
		return
	if is_battle_ended():
		return

	enemy_think_paused = false
	enemy_think_timer = min(enemy_think_timer, 0.10)

	if Globals.print_priority_5:
		print("[enemy_thinker_wake] player event completed: ", completed_event.get("event_type", "unknown"))


func build_enemy_logic_update_package() -> Dictionary:
	# Summary: Build the clean live-state snapshot passed into EnemyLogic.
	return {
		"enemy": active_enemy,
		"player_state": player_state,
		"battle_id": battle_id,
		"battle_active": not is_battle_ended(),
		"battle_ended": is_battle_ended(),
		"battle_v2_ended": is_battle_ended(),
		"enemy_energy": build_enemy_energy_snapshot(),
		"enemy_ammo": build_enemy_ammo_snapshot(),
		"enemy_loadout": build_enemy_loadout_snapshot(),
		"enemy_shield": build_enemy_shield_snapshot(),
		"enemy_consumable": build_enemy_consumable_snapshot(),
		"active_drone_snapshot": build_active_drone_snapshot(),
		"enemy_weapon_spam_gates": build_enemy_weapon_spam_gate_snapshot(active_enemy),
		"enemy_health_ratio": get_unit_health_ratio(active_enemy),
		"player_health_ratio": get_unit_health_ratio(player_state),
		"enemy_has_good_lock": get_unit_bool(active_enemy, "enemy_good_lock", false),
		"enemy_lock_pending": get_unit_bool(active_enemy, "enemy_lock_pending", false),
		"enemy_lock_disabled": get_unit_bool(active_enemy, "enemy_lock_disabled", false),
		"player_has_good_lock": get_unit_bool(player_state, "player_good_lock", false),
		"active_enemy_events": get_active_events_for_side("enemy"),
		"active_player_events": get_active_events_for_side("player"),
		"enemy_evade_cooldown_remaining_seconds": get_enemy_evade_cooldown_remaining_seconds(active_enemy),
		"time_now_msec": Time.get_ticks_msec(),
		"battle_manager": battle_manager,
		"event_manager": battle_event_manager
	}


func build_enemy_loadout_snapshot() -> Dictionary:
	# Summary: Give EnemyLogic full read access to the enemy battle loadout.
	var primary_id := get_enemy_item_id_for_slot("primary")
	var secondary_id := get_enemy_item_id_for_slot("secondary")
	var shield_id := get_enemy_item_id_for_slot("shield")
	var equipped_shield_id := get_enemy_equipped_shield_id()
	var consumable_id := get_enemy_item_id_for_slot("consumable")

	return {
		"primary": primary_id,
		"secondary": secondary_id,
		"shield": shield_id,
		"equipped_shield": equipped_shield_id,
		"replacement_shield": get_enemy_first_shield_id_from_stacks(equipped_shield_id),
		"consumable": consumable_id,
		"primary_item_data": get_enemy_item_data_by_id(primary_id, "energy", get_unit_float(active_enemy, "attack", 8.0)),
		"secondary_item_data": get_enemy_item_data_by_id(secondary_id, "kinetic", 6.0),
		"shield_item_data": get_enemy_item_data_by_id(shield_id, "shield", 0.0),
		"available_shields": build_enemy_available_shields_snapshot(),
		"consumable_item_data": get_enemy_item_data_by_id(consumable_id, "consumable", 0.0),
		"usable_consumables": build_enemy_usable_consumables_snapshot(),
		"item_stacks": get_enemy_item_stacks()
	}


func build_enemy_usable_consumables_snapshot() -> Array:
	# Summary: List all enemy-held consumables so EnemyLogic can choose more than the current loaded slot.
	var usable: Array = []
	var stacks := get_enemy_item_stacks()
	for raw_id in stacks.keys():
		var item_id := normalize_enemy_battle_item_id(str(raw_id).strip_edges())
		var count = max(int(stacks.get(raw_id, 0)), 0)
		if item_id == "" or count <= 0:
			continue
		var data := get_enemy_item_data_by_id(item_id, "consumable", 0.0)
		if data.is_empty():
			continue
		var item_type := str(data.get("item_type", data.get("type", ""))).strip_edges().to_lower()
		var group := str(data.get("consumable_group", data.get("group", data.get("subtype", "")))).strip_edges().to_lower()
		if item_type != "consumable" and not bool(data.get("consumable", false)) and not is_enemy_consumable_group(group):
			continue
		var packet := {
			"item_id": item_id,
			"stack_count": count,
			"consumable_group": group,
			"item_data": data
		}
		usable.append(packet)
	return usable


func is_enemy_consumable_group(group_id: String) -> bool:
	# Summary: Avoid treating ammo/weapon stack metadata as consumables just because they have a generic group field.
	var clean_group := group_id.strip_edges().to_lower()
	return clean_group == "repair" or clean_group == "shield_repair" or clean_group == "recharge" or clean_group == "explosive" or clean_group == "signal" or clean_group == "drone" or clean_group == "pulse" or clean_group == "override"


func build_enemy_shield_snapshot() -> Dictionary:
	# Summary: Give EnemyLogic current enemy shield state.
	if active_enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
		var equipped_id := get_enemy_equipped_shield_id()
		var replacement_id := get_enemy_first_shield_id_from_stacks(equipped_id)
		return {
			"selected_shield": enemy_state.selected_shield,
			"selected_enemy_shield": enemy_state.selected_enemy_shield,
			"pending_shield": enemy_state.pending_shield,
			"shield_switching": enemy_state.shield_switching,
			"shield_power_level": enemy_state.shield_power_level,
			"shield_hp_current": enemy_state.shield_hp_current,
			"shield_hp_max": enemy_state.shield_hp_max,
			"shield_disabled": enemy_state.shield_disabled,
			"equipped_shield_item_id": equipped_id,
			"equipped_shield_inventory_count": enemy_state.get_enemy_item_count(equipped_id),
			"replacement_shield_item_id": replacement_id,
			"replacement_shield_item_data": get_enemy_item_data_by_id(replacement_id, "shield", 0.0),
			"available_shields": build_enemy_available_shields_snapshot()
		}
	return {}


func build_enemy_consumable_snapshot() -> Dictionary:
	# Summary: Give EnemyLogic current enemy consumable state.
	if active_enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
		return {
			"loaded_consumable": enemy_state.loaded_consumable,
			"loaded_consumable_state": enemy_state.loaded_consumable_state,
			"consumable_ready": enemy_state.consumable_ready,
			"enemy_loaded_consumable": enemy_state.enemy_loaded_consumable,
			"enemy_consumable_ready": enemy_state.enemy_consumable_ready
		}
	return {}


func build_active_drone_snapshot() -> Dictionary:
	# Summary: Give EnemyLogic a read-only BattleManager drone runtime snapshot.
	if battle_manager != null and battle_manager.has_method("get_active_drone_runtime_snapshot"):
		var snapshot = battle_manager.get_active_drone_runtime_snapshot()
		if typeof(snapshot) == TYPE_DICTIONARY:
			return snapshot.duplicate(true)
	return {
		"active_count": 0,
		"drones": [],
		"labels": ["active_drone_runtime_snapshot_missing"]
	}


func build_enemy_energy_snapshot() -> Dictionary:
	# Summary: Enemy energy shape from its handler, falling back to adapter mirrors.
	if enemy_energy_handler != null:
		sync_active_enemy_energy_from_handler()
		return {
			"current": enemy_energy_handler.current_energy,
			"max": enemy_energy_handler.max_energy,
			"reserved": enemy_energy_handler.reserved_energy,
			"available": enemy_energy_handler.get_available_energy(),
			"handler_ready": true,
			"source": "enemy_energy_handler"
		}

	return {
		"current": get_unit_float(active_enemy, "enemy_energy_current", 0.0),
		"max": get_unit_float(active_enemy, "enemy_energy_max", 0.0),
		"reserved": get_unit_float(active_enemy, "enemy_reserved_energy", 0.0),
		"available": max(get_unit_float(active_enemy, "enemy_energy_current", 0.0) - get_unit_float(active_enemy, "enemy_reserved_energy", 0.0), 0.0),
		"handler_ready": false,
		"source": "enemy_quick_v1"
	}


func build_enemy_weapon_spam_gate_snapshot(enemy_ref) -> Dictionary:
	# Summary: Report independent primary/secondary weapon gate timers to EnemyLogic.
	return {
		"primary_remaining": get_enemy_weapon_spam_gate_remaining_seconds(enemy_ref, "primary"),
		"secondary_remaining": get_enemy_weapon_spam_gate_remaining_seconds(enemy_ref, "secondary"),
		"primary_ready": get_enemy_weapon_spam_gate_remaining_seconds(enemy_ref, "primary") <= 0.0,
		"secondary_ready": get_enemy_weapon_spam_gate_remaining_seconds(enemy_ref, "secondary") <= 0.0,
		"primary_duration": enemy_primary_spam_gate_seconds,
		"secondary_duration": enemy_secondary_spam_gate_seconds
	}


func build_enemy_ammo_snapshot() -> Dictionary:
	# Summary: Enemy ammo/item snapshot for EnemyLogic decisions.
	var item_stacks := get_enemy_item_stacks()
	return {
		"small": get_enemy_ammo_count_from_stacks(item_stacks, "small", int(get_unit_float(active_enemy, "enemy_ammo_small", 0.0))),
		"medium": get_enemy_ammo_count_from_stacks(item_stacks, "medium", int(get_unit_float(active_enemy, "enemy_ammo_medium", 0.0))),
		"large": get_enemy_ammo_count_from_stacks(item_stacks, "large", int(get_unit_float(active_enemy, "enemy_ammo_large", 0.0))),
		"item_stacks": item_stacks,
		"handler_ready": false,
		"source": "enemy_adapter_item_stacks"
	}


func get_enemy_item_stacks() -> Dictionary:
	# Summary: Read stackable enemy-held items without exposing the live dictionary.
	if active_enemy is BattleV2UnitAdapter:
		return (active_enemy as BattleV2UnitAdapter).enemy_item_stacks.duplicate(true)
	if active_enemy is Dictionary:
		var stacks = active_enemy.get("enemy_item_stacks", active_enemy.get("item_stacks", {}))
		if typeof(stacks) == TYPE_DICTIONARY:
			return stacks.duplicate(true)
	return {}


func get_enemy_ammo_count_from_stacks(stacks: Dictionary, ammo_group: String, fallback: int = 0) -> int:
	# Summary: Count enemy-held ammo stacks by item metadata group.
	if stacks.is_empty():
		return max(fallback, 0)
	var wanted_group := ammo_group.strip_edges().to_lower()
	var total := 0
	for item_id in stacks.keys():
		var item_data = item_db_snapshot.get(str(item_id), {})
		if typeof(item_data) != TYPE_DICTIONARY:
			continue
		if str(item_data.get("ammo_group", "")).strip_edges().to_lower() == wanted_group:
			total += max(int(stacks.get(item_id, 0)), 0)
	return total


func queue_enemy_intent_from_logic() -> Dictionary:
	# Summary: Ask EnemyLogic, build a packet, and queue it through EventManager.
	var update_package: Dictionary = build_enemy_logic_update_package()
	var primary_item_data := get_enemy_primary_item_data()
	var primary_item_id := get_enemy_primary_item_id()
	var secondary_item_id := get_enemy_item_id_for_slot("secondary")
	var secondary_item_data := get_enemy_item_data_by_id(secondary_item_id, "kinetic", 6.0)
	var shield_item_id := get_enemy_item_id_for_slot("shield")
	var shield_item_data := get_enemy_item_data_by_id(shield_item_id, "shield", 0.0)
	var consumable_item_id := get_enemy_item_id_for_slot("consumable")
	var consumable_item_data := get_enemy_item_data_by_id(consumable_item_id, "consumable", 0.0)
	var attack_value: float = get_enemy_primary_damage_value(primary_item_data)

	var packet_result: Dictionary = battle_action_manager.battle_action_packet_builder.build_enemy_action_packet({
		"enemy_logic": enemy_logic,
		"enemy": active_enemy,
		"player_state": player_state,
		"source_unit": active_enemy,
		"owner_unit": active_enemy,
		"target_unit": player_state,
		"event_side": "enemy",
		"battle_id": battle_id,
		"battle_active": not is_battle_ended(),
		"battle_ended": is_battle_ended(),
		"battle_v2_ended": is_battle_ended(),
		"battle_manager": battle_manager,
		"event_manager": battle_event_manager,
		"enemy_update_package": update_package,
		"enemy_loadout": {
			"primary": primary_item_id,
			"primary_item_data": primary_item_data,
			"secondary": secondary_item_id,
			"secondary_item_data": secondary_item_data,
			"shield": shield_item_id,
			"shield_item_data": shield_item_data,
			"consumable": consumable_item_id,
			"consumable_item_data": consumable_item_data,
			"usable_consumables": build_enemy_usable_consumables_snapshot(),
			"item_stacks": get_enemy_item_stacks()
		},
		"item_db_snapshot": item_db_snapshot.duplicate(true),
		"evade_duration": evade_duration_seconds,
		"evade_cooldown_seconds": evade_cooldown_seconds,
		"signal_strength": attack_value,
		"intent_data": {
			"attack": attack_value,
			"evade_duration": evade_duration_seconds
		}
	})

	if packet_result.get("status", "") != "built":
		set_enemy_think_cooldown(enemy_wait_cooldown_seconds)
		var reason := str(packet_result.get("reason", "enemy intent did not build event"))
		if Globals.print_priority_5:
			print("[enemy_intent_not_queued] ", reason)
		return {
			"status": "not_queued",
			"reason": reason,
			"labels": packet_result.get("labels", [])
		}

	var enemy_event_packet: Dictionary = packet_result.get("event_packet", {})
	if enemy_event_packet.is_empty():
		set_enemy_think_cooldown(enemy_wait_cooldown_seconds)
		return {
			"status": "failed",
			"reason": "packet_result missing event_packet",
			"labels": ["enemy_logic_no_spam_gate", "enemy_packet_missing_event_packet"]
		}

	var weapon_spam_gate_result: Dictionary = can_queue_enemy_weapon_spam_gate_packet(enemy_event_packet)
	if str(weapon_spam_gate_result.get("status", "")) != "success":
		set_enemy_think_cooldown(enemy_wait_cooldown_seconds)
		append_log("\nEnemy weapon held: " + str(weapon_spam_gate_result.get("reason", "weapon spam gate active")) + "\n")
		return {
			"status": "held",
			"reason": weapon_spam_gate_result.get("reason", "enemy weapon spam gate active"),
			"labels": weapon_spam_gate_result.get("labels", [])
		}

	var item_reserve_result: Dictionary = reserve_enemy_items_for_event_packet(enemy_event_packet)
	if str(item_reserve_result.get("status", "")) != "success":
		release_enemy_reserved_energy_for_event_packet(enemy_event_packet)
		set_enemy_think_cooldown(enemy_wait_cooldown_seconds)
		append_log("\nEnemy item held: " + str(item_reserve_result.get("reason", "item reserve failed")) + "\n")
		return {
			"status": "held",
			"reason": item_reserve_result.get("reason", "enemy item reserve failed"),
			"labels": item_reserve_result.get("labels", [])
		}

	var energy_reserve_result: Dictionary = reserve_enemy_energy_for_event_packet(enemy_event_packet)
	if str(energy_reserve_result.get("status", "")) != "success":
		release_enemy_reserved_items_for_event_packet(enemy_event_packet)
		set_enemy_think_cooldown(enemy_wait_cooldown_seconds)
		append_log("\nEnemy energy held: " + str(energy_reserve_result.get("reason", "energy reserve failed")) + "\n")
		return {
			"status": "held",
			"reason": energy_reserve_result.get("reason", "enemy energy reserve failed"),
			"labels": energy_reserve_result.get("labels", [])
		}

	var cooldown_result: Dictionary = can_queue_enemy_evade_packet(enemy_event_packet)
	if str(cooldown_result.get("status", "")) != "success":
		release_enemy_reserved_energy_for_event_packet(enemy_event_packet)
		release_enemy_reserved_items_for_event_packet(enemy_event_packet)
		set_enemy_think_cooldown(enemy_wait_cooldown_seconds)
		append_log("\nEnemy evade held: " + str(cooldown_result.get("reason", "evade unavailable")) + " (" + ("%0.1f" % float(cooldown_result.get("remaining_seconds", 0.0))) + "s).\n")
		return {
			"status": "held",
			"reason": cooldown_result.get("reason", "enemy evade cooldown active"),
			"labels": cooldown_result.get("labels", [])
		}

	var event_result: Dictionary = battle_event_manager.add_event(enemy_event_packet)
	if not bool(event_result.get("accepted", false)):
		release_enemy_reserved_energy_for_event_packet(enemy_event_packet)
		release_enemy_reserved_items_for_event_packet(enemy_event_packet)
		set_enemy_think_cooldown(enemy_wait_cooldown_seconds)
		append_log("\nEnemy intent queue rejected: " + str(event_result.get("blocked_reason", "unknown")) + "\n")
		return {
			"status": "rejected",
			"reason": event_result.get("blocked_reason", "EventManager rejected enemy event"),
			"labels": event_result.get("labels", [])
		}

	if is_enemy_evade_event_packet(enemy_event_packet):
		start_enemy_evade_cooldown(enemy_event_packet)
		if battle_scene != null and battle_scene.has_method("apply_evade_queue_effects"):
			battle_scene.apply_evade_queue_effects(enemy_event_packet)
	if is_enemy_weapon_spam_gated_event_packet(enemy_event_packet):
		start_enemy_weapon_spam_gate(enemy_event_packet)

	mark_enemy_lock_reacquire_pending_if_needed(enemy_event_packet)
	prepare_enemy_queued_item_state(enemy_event_packet)
	sync_active_enemy_energy_from_handler()
	set_enemy_think_cooldown(get_enemy_decision_cooldown_seconds())
	call_refresh_todo()

	var queued_item_id := str(enemy_event_packet.get("item_id", "")).strip_edges()
	var queued_energy_cost := get_event_packet_energy_cost(enemy_event_packet)
	var queue_log_text := "\nEnemy queued: " + str(enemy_event_packet.get("event_type", "unknown"))
	queue_log_text += "\nEvent id: " + str(event_result.get("event_id", "pending"))
	if queued_item_id != "":
		queue_log_text += "\nItem: " + queued_item_id
	if queued_energy_cost > 0.0:
		queue_log_text += "\nReserved energy: " + ("%0.1f" % queued_energy_cost)
	queue_log_text += "\nIntent path: EnemyBattleController -> EnemyLogic -> PacketBuilder -> EventManager\n"
	append_log(queue_log_text)

	return {
		"status": "queued",
		"event_id": event_result.get("event_id", ""),
		"event_type": enemy_event_packet.get("event_type", ""),
		"labels": [
			"enemy_battle_controller",
			"enemy_logic_think_tick",
			"enemy_logic_state_snapshot",
			"enemy_logic_no_spam_gate",
			"enemy_action_queued_to_event_manager"
		]
	}


func get_enemy_primary_item_id() -> String:
	# Summary: Read the active enemy's starting primary weapon id.
	if active_enemy is BattleV2UnitAdapter:
		return str((active_enemy as BattleV2UnitAdapter).selected_primary_weapon).strip_edges()
	if active_enemy is Dictionary:
		return str(active_enemy.get("selected_primary_weapon", active_enemy.get("primary", ""))).strip_edges()
	if active_enemy is Object:
		var value = active_enemy.get("selected_primary_weapon")
		if value == null:
			value = active_enemy.get("primary")
		return str(value).strip_edges()
	return ""


func get_enemy_primary_item_data() -> Dictionary:
	# Summary: Read the active enemy primary weapon data from the shared item database snapshot.
	var item_id := get_enemy_primary_item_id()
	if item_id == "":
		return {}

	var data = item_db_snapshot.get(item_id, {})
	if typeof(data) == TYPE_DICTIONARY and not data.is_empty():
		var packet: Dictionary = data.duplicate(true)
		packet["item_id"] = item_id
		packet["id"] = item_id
		return packet

	return {
		"item_id": item_id,
		"id": item_id,
		"display_name": item_id,
		"name": item_id,
		"damage_type": "energy",
		"damage_value": max(get_unit_float(active_enemy, "attack", 8.0), 8.0),
		"duration": 2.0,
		"energy_cost": 0.0,
		"labels": ["enemy_primary_item_data_fallback"]
	}


func get_enemy_item_id_for_slot(slot_name: String) -> String:
	# Summary: Read enemy loadout ids by slot from the active adapter/dictionary/object.
	var slot := slot_name.strip_edges().to_lower()
	if active_enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
		if slot == "primary":
			return normalize_enemy_battle_item_id(str(enemy_state.selected_primary_weapon).strip_edges())
		if slot == "secondary":
			return normalize_enemy_battle_item_id(str(enemy_state.selected_secondary_weapon).strip_edges())
		if slot == "shield":
			var equipped_id := get_enemy_equipped_shield_id()
			if equipped_id != "":
				return equipped_id
			return get_enemy_first_shield_id_from_stacks()
		if slot == "consumable":
			var enemy_loaded_id := extract_enemy_item_id_from_value(enemy_state.enemy_loaded_consumable)
			if enemy_loaded_id != "":
				return normalize_enemy_battle_item_id(enemy_loaded_id)
			var loaded_id := extract_enemy_item_id_from_value(enemy_state.loaded_consumable)
			if loaded_id != "":
				return normalize_enemy_battle_item_id(loaded_id)
			return get_enemy_first_consumable_id_from_stacks()

	if active_enemy is Dictionary:
		var key_by_slot := {
			"primary": "selected_primary_weapon",
			"secondary": "selected_secondary_weapon",
			"shield": "selected_enemy_shield",
			"consumable": "enemy_loaded_consumable"
		}
		var key := str(key_by_slot.get(slot, slot))
		var dictionary_item_id := normalize_enemy_battle_item_id(extract_enemy_item_id_from_value(active_enemy.get(key, active_enemy.get(slot, ""))))
		if slot == "shield" and dictionary_item_id == "":
			return get_enemy_first_shield_id_from_stacks()
		return dictionary_item_id

	if active_enemy is Object:
		var property_by_slot := {
			"primary": "selected_primary_weapon",
			"secondary": "selected_secondary_weapon",
			"shield": "selected_enemy_shield",
			"consumable": "enemy_loaded_consumable"
		}
		var property_name := str(property_by_slot.get(slot, slot))
		var value = active_enemy.get(property_name)
		if value == null and slot == "shield":
			value = active_enemy.get("shield")
		if value == null and slot == "consumable":
			value = active_enemy.get("consumable")
		if value != null:
			var object_item_id := normalize_enemy_battle_item_id(extract_enemy_item_id_from_value(value))
			if slot == "shield" and object_item_id == "":
				return get_enemy_first_shield_id_from_stacks()
			return object_item_id
		if slot == "shield":
			return get_enemy_first_shield_id_from_stacks()

	return ""


func get_enemy_equipped_shield_id() -> String:
	# Summary: Read only the currently equipped shield, never an inventory replacement.
	if active_enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
		var selected_id := extract_enemy_item_id_from_value(enemy_state.selected_shield)
		if selected_id == "":
			selected_id = str(enemy_state.selected_enemy_shield).strip_edges()
		return normalize_enemy_battle_item_id(selected_id)
	if active_enemy is Dictionary:
		var dictionary_selected_value = active_enemy.get("selected_shield", null)
		if dictionary_selected_value == null:
			dictionary_selected_value = active_enemy.get("selected_enemy_shield", "")
		return normalize_enemy_battle_item_id(extract_enemy_item_id_from_value(dictionary_selected_value))
	if active_enemy is Object:
		var object_selected_value = active_enemy.get("selected_shield")
		if object_selected_value == null:
			object_selected_value = active_enemy.get("selected_enemy_shield")
		return normalize_enemy_battle_item_id(extract_enemy_item_id_from_value(object_selected_value))
	return ""


func build_enemy_available_shields_snapshot() -> Array:
	# Summary: Expose owned shield candidates and their enemy-control tags to EnemyLogic.
	var available: Array = []
	var stacks := get_enemy_item_stacks()
	for raw_id in stacks.keys():
		var item_id := normalize_enemy_battle_item_id(str(raw_id).strip_edges())
		var count = max(int(stacks.get(raw_id, 0)), 0)
		if item_id == "" or count <= 0:
			continue
		var item_data := get_enemy_item_data_by_id(item_id, "shield", 0.0)
		if str(item_data.get("item_type", item_data.get("type", ""))).strip_edges().to_lower() != "shield":
			continue
		available.append({
			"item_id": item_id,
			"stack_count": count,
			"item_data": item_data,
			"enemy_logic_tags": item_data.get("enemy_logic_tags", [])
		})
	return available


func get_enemy_first_shield_id_from_stacks(exclude_item_id: String = "") -> String:
	# Summary: Find an owned replacement shield without reusing the currently equipped instance.
	var excluded := normalize_enemy_battle_item_id(exclude_item_id)
	for raw_candidate in build_enemy_available_shields_snapshot():
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue
		var candidate_id := normalize_enemy_battle_item_id(str(raw_candidate.get("item_id", "")).strip_edges())
		if candidate_id == "" or candidate_id == excluded:
			continue
		return candidate_id
	return ""


func extract_enemy_item_id_from_value(value) -> String:
	# Summary: Normalize a slot value that might be an id string or a full item dictionary.
	if value == null:
		return ""
	if typeof(value) == TYPE_DICTIONARY:
		return str(value.get("item_id", value.get("id", value.get("name", "")))).strip_edges()
	var text := str(value).strip_edges()
	if text == "" or text == "<null>" or text.to_lower() == "null":
		return ""
	return text


func get_enemy_first_consumable_id_from_stacks() -> String:
	# Summary: Fallback single-slot consumable pick for legacy logic. EnemyLogic also receives the full usable list.
	var usable := build_enemy_usable_consumables_snapshot()
	if usable.is_empty():
		return ""
	for item in usable:
		if typeof(item) == TYPE_DICTIONARY and str(item.get("consumable_group", "")).strip_edges().to_lower() == "drone":
			return str(item.get("item_id", "")).strip_edges()
	var first = usable[0]
	if typeof(first) == TYPE_DICTIONARY:
		return str(first.get("item_id", "")).strip_edges()
	return ""


func get_enemy_item_data_by_id(item_id: String, fallback_damage_type: String = "", fallback_damage: float = 0.0) -> Dictionary:
	# Summary: Read enemy item data from the battle item snapshot with a safe fallback packet.
	var clean_id := normalize_enemy_battle_item_id(item_id)
	if clean_id == "":
		return {}

	var data = item_db_snapshot.get(clean_id, {})
	if typeof(data) == TYPE_DICTIONARY and not data.is_empty():
		var packet: Dictionary = data.duplicate(true)
		packet["item_id"] = clean_id
		packet["id"] = clean_id
		return packet

	return {
		"item_id": clean_id,
		"id": clean_id,
		"display_name": clean_id,
		"name": clean_id,
		"damage_type": fallback_damage_type,
		"damage_value": fallback_damage,
		"damage": fallback_damage,
		"duration": 2.0,
		"energy_cost": 0.0,
		"labels": ["enemy_item_data_fallback"]
	}


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


func reserve_enemy_items_for_event_packet(event_packet: Dictionary) -> Dictionary:
	# Summary: Spend enemy-held stackables at queue time so enemy logic cannot overspend them.
	var result := {
		"status": "success",
		"reason": "",
		"labels": ["enemy_item_stack_reserve"],
		"reserved_items": []
	}
	if not (active_enemy is BattleV2UnitAdapter):
		return result

	var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
	var data_payload = event_packet.get("data", {})
	if typeof(data_payload) != TYPE_DICTIONARY:
		return result

	var reserve_items: Array = []
	var ammo_cost = max(int(data_payload.get("total_ammo_cost", data_payload.get("ammo_cost", 0))), 0)
	if ammo_cost > 0:
		var ammo_item_id := str(data_payload.get("ammo_item_id", "")).strip_edges()
		if ammo_item_id == "":
			ammo_item_id = get_first_enemy_item_id_for_ammo_group(str(data_payload.get("ammo_group", "")))
		if ammo_item_id == "":
			result["status"] = "failed"
			result["reason"] = "missing enemy ammo item stack"
			result["labels"].append("enemy_ammo_stack_missing")
			return result
		reserve_items.append({"item_id": ammo_item_id, "amount": ammo_cost, "reason": "ammo"})

	if should_reserve_enemy_consumable(event_packet):
		var consumable_id := str(data_payload.get("consumable_id", event_packet.get("item_id", ""))).strip_edges()
		if consumable_id == "":
			result["status"] = "failed"
			result["reason"] = "missing enemy consumable item id"
			result["labels"].append("enemy_consumable_stack_missing")
			return result
		reserve_items.append({"item_id": consumable_id, "amount": 1, "reason": "consumable"})

	for reserve in reserve_items:
		var item_id := str(reserve.get("item_id", "")).strip_edges()
		var amount = max(int(reserve.get("amount", 0)), 0)
		if not enemy_state.consume_enemy_item(item_id, amount):
			result["status"] = "failed"
			result["reason"] = "not enough enemy item stack: " + item_id
			result["labels"].append("enemy_item_stack_insufficient")
			release_enemy_stack_reservations(result["reserved_items"])
			return result
		result["reserved_items"].append(reserve)

	event_packet["enemy_reserved_items"] = result["reserved_items"].duplicate(true)
	sync_enemy_legacy_ammo_fields_from_stacks()
	return result


func release_enemy_reserved_items_for_event_packet(event_packet: Dictionary) -> void:
	# Summary: Return enemy stackables if queueing fails after reservation.
	var reserved_items = event_packet.get("enemy_reserved_items", [])
	if typeof(reserved_items) != TYPE_ARRAY:
		return
	release_enemy_stack_reservations(reserved_items)
	event_packet["enemy_reserved_items"] = []
	sync_enemy_legacy_ammo_fields_from_stacks()


func can_queue_enemy_weapon_spam_gate_packet(event_packet: Dictionary) -> Dictionary:
	# Summary: Enforce independent enemy primary/secondary click gates at the queue boundary.
	var result := {
		"status": "success",
		"reason": "",
		"remaining_seconds": 0.0,
		"weapon_slot": get_enemy_weapon_slot_for_event_packet(event_packet),
		"labels": ["enemy_weapon_spam_gate_check"]
	}
	if not is_enemy_weapon_spam_gated_event_packet(event_packet):
		return result

	var slot := str(result.get("weapon_slot", "")).strip_edges().to_lower()
	var remaining := get_enemy_weapon_spam_gate_remaining_seconds(
		event_packet.get("owner_unit", event_packet.get("source_unit", active_enemy)),
		slot
	)
	result["remaining_seconds"] = remaining
	if remaining > 0.0:
		result["status"] = "held"
		result["reason"] = "enemy " + slot + " spam gate active"
		result["labels"].append("enemy_weapon_spam_gate_active")
		return result

	result["labels"].append("enemy_weapon_spam_gate_ready")
	return result


func start_enemy_weapon_spam_gate(event_packet: Dictionary) -> void:
	# Summary: Start the enemy weapon gate once the matching event has actually queued.
	var slot := get_enemy_weapon_slot_for_event_packet(event_packet)
	var duration := get_enemy_weapon_spam_gate_duration_seconds(slot)
	if duration <= 0.0:
		return
	var key := get_enemy_weapon_spam_gate_key(
		event_packet.get("owner_unit", event_packet.get("source_unit", active_enemy)),
		slot
	)
	enemy_weapon_spam_gate_until_msec_by_key[key] = Time.get_ticks_msec() + int(round(duration * 1000.0))
	if Globals.print_priority_5:
		print("[enemy_weapon_spam_gate_started] key=", key, " seconds=", duration)


func is_enemy_weapon_spam_gated_event_packet(event_packet: Dictionary) -> bool:
	var event_type := str(event_packet.get("event_type", "")).strip_edges().to_lower()
	return event_type == "enemy_primary_attack" or event_type == "enemy_secondary_attack"


func get_enemy_weapon_slot_for_event_packet(event_packet: Dictionary) -> String:
	var event_type := str(event_packet.get("event_type", "")).strip_edges().to_lower()
	if event_type == "enemy_primary_attack":
		return "primary"
	if event_type == "enemy_secondary_attack":
		return "secondary"
	var data_payload = event_packet.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY:
		return str(data_payload.get("weapon_slot", "")).strip_edges().to_lower()
	return ""


func get_enemy_weapon_spam_gate_duration_seconds(slot: String) -> float:
	var clean_slot := slot.strip_edges().to_lower()
	if clean_slot == "primary":
		return enemy_primary_spam_gate_seconds
	if clean_slot == "secondary":
		return enemy_secondary_spam_gate_seconds
	return 0.0


func get_enemy_weapon_spam_gate_remaining_seconds(enemy_ref, slot: String) -> float:
	var key := get_enemy_weapon_spam_gate_key(enemy_ref, slot)
	if key == "":
		return 0.0
	var until_msec := int(enemy_weapon_spam_gate_until_msec_by_key.get(key, 0))
	return max(float(until_msec - Time.get_ticks_msec()) / 1000.0, 0.0)


func get_enemy_weapon_spam_gate_key(enemy_ref, slot: String) -> String:
	var clean_slot := slot.strip_edges().to_lower()
	if clean_slot == "":
		return ""
	return get_enemy_evade_cooldown_key(enemy_ref) + "|" + clean_slot


func release_enemy_stack_reservations(reserved_items: Array) -> void:
	if not (active_enemy is BattleV2UnitAdapter):
		return
	var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
	for reserve in reserved_items:
		if typeof(reserve) != TYPE_DICTIONARY:
			continue
		enemy_state.add_enemy_item(str(reserve.get("item_id", "")), int(reserve.get("amount", 0)))


func should_reserve_enemy_consumable(event_packet: Dictionary) -> bool:
	return is_enemy_consumable_execute_event_packet(event_packet)


func is_enemy_consumable_execute_event_packet(event_packet: Dictionary) -> bool:
	# Summary: True for enemy consumable execution packets, including deploy_drone variants.
	var event_type := str(event_packet.get("event_type", "")).strip_edges().to_lower()
	var action_id := str(event_packet.get("action_id", "")).strip_edges().to_lower()
	if action_id == "enemy_execute_consumable":
		return true
	return event_type.begins_with("execute_") or event_type == "deploy_drone"


func get_first_enemy_item_id_for_ammo_group(ammo_group: String) -> String:
	var wanted_group := ammo_group.strip_edges().to_lower()
	if wanted_group == "":
		return ""
	var stacks := get_enemy_item_stacks()
	for item_id in stacks.keys():
		if int(stacks.get(item_id, 0)) <= 0:
			continue
		var item_data = item_db_snapshot.get(str(item_id), {})
		if typeof(item_data) != TYPE_DICTIONARY:
			continue
		if str(item_data.get("ammo_group", "")).strip_edges().to_lower() == wanted_group:
			return str(item_id)
	return ""


func sync_enemy_legacy_ammo_fields_from_stacks() -> void:
	if not (active_enemy is BattleV2UnitAdapter):
		return
	var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
	var stacks := enemy_state.enemy_item_stacks.duplicate(true)
	enemy_state.enemy_ammo_small = get_enemy_ammo_count_from_stacks(stacks, "small", 0)
	enemy_state.enemy_ammo_medium = get_enemy_ammo_count_from_stacks(stacks, "medium", 0)
	enemy_state.enemy_ammo_large = get_enemy_ammo_count_from_stacks(stacks, "large", 0)


func prepare_enemy_queued_item_state(event_packet: Dictionary) -> void:
	# Summary: Apply queue-time enemy state needed by delayed BattleManager completion.
	if not (active_enemy is BattleV2UnitAdapter):
		return
	var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
	var event_subtype := str(event_packet.get("event_subtype", "")).strip_edges().to_lower()
	var event_type := str(event_packet.get("event_type", "")).strip_edges().to_lower()
	var data_payload = event_packet.get("data", {})
	if typeof(data_payload) != TYPE_DICTIONARY:
		data_payload = {}

	if event_subtype == "shield_switch_complete":
		var pending = data_payload.get("pending_shield_data", data_payload.get("item_data", null))
		if pending == null:
			pending = data_payload.get("pending_shield", event_packet.get("item_id", null))
		enemy_state.pending_shield = pending
		enemy_state.set_shield_switching(true)
		call_refresh_unit()
		return

	if event_subtype == "load_consumable_complete":
		enemy_state.set_loaded_consumable(data_payload.get("item_data", data_payload.get("consumable_id", event_packet.get("item_id", null))), "loading")
		call_refresh_unit()
		return

	if event_subtype == "clear_loaded_consumable_complete":
		enemy_state.set_consumable_state("clearing")
		call_refresh_unit()
		return

	if event_subtype == "shield_remove_complete":
		enemy_state.set_shield_switching(true)
		call_refresh_unit()
		return

	if is_enemy_consumable_execute_event_packet(event_packet):
		enemy_state.set_consumable_state("executing")
		call_refresh_unit()


func get_enemy_primary_damage_value(item_data: Dictionary) -> float:
	# Summary: Read enemy primary damage from item data, falling back to adapter attack.
	var damage := float(item_data.get("damage_value", item_data.get("damage", 0.0)))
	if damage <= 0.0:
		damage = max(get_unit_float(active_enemy, "attack", 8.0), 8.0)
	return damage


func get_enemy_primary_energy_cost(item_data: Dictionary) -> float:
	# Summary: Read enemy primary energy cost from item data.
	return max(float(item_data.get("energy_cost", 0.0)), 0.0)


func get_enemy_primary_duration(item_data: Dictionary) -> float:
	# Summary: Read enemy primary firing duration from item data.
	var duration := float(item_data.get("duration", item_data.get("fire_time", item_data.get("cooldown", 0.0))))
	if duration <= 0.0:
		duration = 2.0
	return duration


func reserve_enemy_energy_for_event_packet(event_packet: Dictionary) -> Dictionary:
	# Summary: Reserve enemy energy when the enemy queues an energy-cost TODO.
	var energy_cost := get_event_packet_energy_cost(event_packet)
	var result := {
		"status": "success",
		"reason": "",
		"energy_cost": energy_cost,
		"labels": ["enemy_energy_reserve_bridge"]
	}

	if energy_cost <= 0.0:
		event_packet["energy_reserved"] = false
		event_packet["reserved_energy_cost"] = 0.0
		return result

	if enemy_energy_handler == null or not enemy_energy_handler.has_method("reserve_energy"):
		result["status"] = "failed"
		result["reason"] = "missing enemy energy handler"
		result["labels"].append("energy_reserve_failed")
		event_packet["energy_reserved"] = false
		event_packet["reserved_energy_cost"] = 0.0
		return result

	var reserve_result = enemy_energy_handler.reserve_energy(energy_cost)
	if typeof(reserve_result) == TYPE_DICTIONARY and str(reserve_result.get("status", "")) != "success":
		result["status"] = "failed"
		result["reason"] = str(reserve_result.get("reason", "enemy energy reserve failed"))
		var reserve_labels = reserve_result.get("labels", [])
		if typeof(reserve_labels) == TYPE_ARRAY:
			for label in reserve_labels:
				result["labels"].append(str(label))
		event_packet["energy_reserved"] = false
		event_packet["reserved_energy_cost"] = 0.0
		return result

	event_packet["energy_reserved"] = true
	event_packet["reserved_energy_cost"] = energy_cost
	result["energy_handler_result"] = reserve_result
	sync_active_enemy_energy_from_handler()
	return result


func release_enemy_reserved_energy_for_event_packet(event_packet: Dictionary) -> void:
	# Summary: Release enemy reserved energy if EventManager rejects the queued packet.
	if enemy_energy_handler == null or not enemy_energy_handler.has_method("release_reserved_energy"):
		return
	if not bool(event_packet.get("energy_reserved", false)):
		return
	var energy_cost := get_event_packet_energy_cost(event_packet)
	if energy_cost <= 0.0:
		return
	enemy_energy_handler.release_reserved_energy(energy_cost)
	event_packet["energy_reserved"] = false
	event_packet["reserved_energy_cost"] = 0.0
	sync_active_enemy_energy_from_handler()


func get_event_packet_energy_cost(event_packet: Dictionary) -> float:
	# Summary: Read energy cost from enemy event packet data.
	var data_payload = event_packet.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY:
		return max(float(data_payload.get("energy_cost", event_packet.get("energy_cost", 0.0))), 0.0)
	return max(float(event_packet.get("energy_cost", 0.0)), 0.0)


func sync_active_enemy_energy_from_handler() -> void:
	# Summary: Mirror enemy handler values into the active enemy adapter.
	if enemy_energy_handler == null:
		return
	if not (active_enemy is BattleV2UnitAdapter):
		return
	var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
	enemy_state.enemy_energy_current = enemy_energy_handler.current_energy
	enemy_state.enemy_energy_max = enemy_energy_handler.max_energy
	enemy_state.enemy_reserved_energy = enemy_energy_handler.reserved_energy


func set_enemy_think_cooldown(seconds: float) -> void:
	# Summary: Prevent the active enemy loop from asking for another action immediately.
	enemy_action_cooldown_until_msec = Time.get_ticks_msec() + int(max(seconds, 0.0) * 1000.0)


func get_enemy_decision_cooldown_seconds() -> float:
	# Summary: Let behavior profiles slow or speed enemy response cadence without changing action rules.
	if enemy_logic != null and enemy_logic.has_method("get_decision_cooldown_seconds"):
		return float(enemy_logic.get_decision_cooldown_seconds(active_enemy, enemy_action_cooldown_seconds))
	return enemy_action_cooldown_seconds


func mark_enemy_lock_reacquire_pending_if_needed(event_packet: Dictionary) -> void:
	# Summary: Mirror queued enemy lock-restore TODOs into the enemy pending lock flag for logic/UI.
	if typeof(event_packet) != TYPE_DICTIONARY:
		return
	if str(event_packet.get("event_type", "")).strip_edges().to_lower() != "enemy_reacquire_lock":
		return
	if active_enemy == null:
		return
	if active_enemy is Object and active_enemy.has_method("set_enemy_lock_pending"):
		active_enemy.set_enemy_lock_pending(true)
		call_refresh_unit()


func can_queue_enemy_evade_packet(event_packet: Dictionary) -> Dictionary:
	# Summary: Enforce the enemy evade cooldown at the final queue boundary.
	if not is_enemy_evade_event_packet(event_packet):
		return {
			"status": "success",
			"reason": "",
			"labels": ["enemy_evade_queue_cooldown_check"]
		}

	if has_active_weapon_todo():
		return {
			"status": "failed",
			"reason": "enemy weapon TODO active",
			"remaining_seconds": 0.0,
			"labels": [
				"enemy_evade_queue_cooldown_check",
				"evade_blocked_weapon_todo_active"
			]
		}

	if has_active_enemy_evade_todo():
		return {
			"status": "failed",
			"reason": "enemy evade already active",
			"remaining_seconds": 0.0,
			"labels": [
				"enemy_evade_queue_cooldown_check",
				"evade_todo_active"
			]
		}

	var enemy_key := get_enemy_evade_cooldown_key(event_packet.get("owner_unit", event_packet.get("source_unit", active_enemy)))
	var now_msec: int = Time.get_ticks_msec()
	var cooldown_until_msec: int = int(enemy_evade_cooldown_until_msec_by_key.get(enemy_key, 0))

	if cooldown_until_msec > now_msec:
		return {
			"status": "failed",
			"reason": "enemy evade cooldown active",
			"enemy_key": enemy_key,
			"remaining_seconds": float(cooldown_until_msec - now_msec) / 1000.0,
			"labels": [
				"enemy_evade_queue_cooldown_check",
				"enemy_evade_cooldown_active"
			]
		}

	return {
		"status": "success",
		"reason": "",
		"enemy_key": enemy_key,
		"labels": [
			"enemy_evade_queue_cooldown_check",
			"enemy_evade_cooldown_ready"
		]
	}


func record_completed_enemy_evade_cooldown(event_packet: Dictionary) -> void:
	# Summary: Mirror completed enemy evade to EnemyLogic without restarting the queue-time cooldown.
	if not is_enemy_evade_event_packet(event_packet):
		return

	if Globals.print_priority_5:
		print("[enemy_evade_completed] cooldown was started at queue time")


func start_enemy_evade_cooldown(event_packet: Dictionary) -> void:
	# Summary: Start enemy evade cooldown at queue/use time so it cannot stack while active.
	var enemy_ref = event_packet.get("owner_unit", event_packet.get("source_unit", active_enemy))
	var enemy_key := get_enemy_evade_cooldown_key(enemy_ref)
	enemy_evade_cooldown_until_msec_by_key[enemy_key] = Time.get_ticks_msec() + int(max(evade_cooldown_seconds, 0.0) * 1000.0)

	if enemy_logic != null and enemy_logic.has_method("mark_enemy_evade_completed"):
		enemy_logic.mark_enemy_evade_completed(enemy_ref)

	if Globals.print_priority_5:
		print("[enemy_evade_cooldown_started_on_queue] key=", enemy_key, " seconds=", evade_cooldown_seconds)


func has_active_weapon_todo() -> bool:
	# Summary: Enemy evade cannot queue while the enemy already has a weapon TODO active.
	if battle_scene != null and battle_scene.has_method("has_active_weapon_todo"):
		return bool(battle_scene.has_active_weapon_todo("enemy"))
	if battle_event_manager == null:
		return false

	for event_packet in battle_event_manager.active_events:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		var event_side := str(event_packet.get("event_side", "")).strip_edges().to_lower()
		if event_side != "enemy":
			continue
		var event_group := str(event_packet.get("event_group", "")).strip_edges().to_lower()
		var event_type := str(event_packet.get("event_type", "")).strip_edges().to_lower()
		if event_group == "weapon":
			return true
		if event_type == "fire_primary_weapon" or event_type == "fire_secondary_weapon" or event_type == "enemy_primary_attack" or event_type == "enemy_secondary_attack":
			return true

	return false


func has_active_enemy_evade_todo() -> bool:
	# Summary: Prevent duplicate active enemy evade TODOs.
	if battle_event_manager == null:
		return false

	for event_packet in battle_event_manager.active_events:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		if str(event_packet.get("event_side", "")).strip_edges().to_lower() != "enemy":
			continue
		if is_enemy_evade_event_packet(event_packet):
			return true

	return false


func is_enemy_evade_event_packet(event_packet: Dictionary) -> bool:
	# Summary: Identify enemy evade packets from either event type or completion subtype.
	if typeof(event_packet) != TYPE_DICTIONARY:
		return false
	if str(event_packet.get("event_side", "")).strip_edges().to_lower() != "enemy":
		return false

	var event_type := str(event_packet.get("event_type", "")).strip_edges().to_lower()
	var event_subtype := str(event_packet.get("event_subtype", "")).strip_edges().to_lower()
	return event_type == "enemy_evade" or event_subtype == "evade_complete"


func get_enemy_evade_cooldown_remaining_seconds(enemy_ref) -> float:
	# Summary: Read current enemy evade cooldown remaining for EnemyLogic snapshots.
	var enemy_key := get_enemy_evade_cooldown_key(enemy_ref)
	var remaining_msec: int = int(enemy_evade_cooldown_until_msec_by_key.get(enemy_key, 0)) - Time.get_ticks_msec()
	if remaining_msec <= 0:
		return 0.0
	return float(remaining_msec) / 1000.0


func get_enemy_evade_cooldown_key(enemy_ref) -> String:
	# Summary: Build a stable key for enemy evade cooldown tracking.
	if enemy_ref == null:
		return "enemy_null"

	if typeof(enemy_ref) == TYPE_DICTIONARY:
		for key in ["unit_id", "enemy_id", "id", "display_name", "name"]:
			var value = enemy_ref.get(key, null)
			if value != null and str(value).strip_edges() != "":
				return str(value).strip_edges()
		return str(enemy_ref)

	if enemy_ref is Object:
		for key in ["unit_id", "enemy_id", "id", "display_name", "name"]:
			var value = enemy_ref.get(key)
			if value != null and str(value).strip_edges() != "":
				return str(value).strip_edges()

	return str(enemy_ref)


func get_unit_health_ratio(unit_ref) -> float:
	# Summary: Read BattleV2UnitAdapter hull safely for player or enemy.
	if unit_ref == null:
		return 0.0

	if unit_ref is BattleV2UnitAdapter:
		var adapter: BattleV2UnitAdapter = unit_ref
		if adapter.unit_side == "player":
			if adapter.player_hull_max <= 0.0:
				return 0.0
			return clamp(adapter.player_hull_current / adapter.player_hull_max, 0.0, 1.0)
		if adapter.enemy_hull_max <= 0.0:
			return 0.0
		return clamp(adapter.enemy_hull_current / adapter.enemy_hull_max, 0.0, 1.0)

	if typeof(unit_ref) == TYPE_DICTIONARY:
		var current := float(unit_ref.get("hull", unit_ref.get("hp", unit_ref.get("current_hp", 0.0))))
		var max_value := float(unit_ref.get("max_hull", unit_ref.get("max_hp", 1.0)))
		if max_value <= 0.0:
			return 0.0
		return clamp(current / max_value, 0.0, 1.0)

	return 0.0


func get_unit_bool(unit_ref, key: String, fallback: bool = false) -> bool:
	# Summary: Read known battle state bools from adapters or dictionaries.
	if unit_ref == null:
		return fallback

	if unit_ref is BattleV2UnitAdapter:
		var adapter: BattleV2UnitAdapter = unit_ref
		match key:
			"enemy_good_lock":
				return bool(adapter.enemy_good_lock)
			"enemy_lock_pending":
				return bool(adapter.enemy_lock_pending)
			"enemy_lock_disabled":
				return bool(adapter.enemy_lock_disabled)
			"player_good_lock":
				return bool(adapter.player_good_lock)
			"player_lock_pending":
				return bool(adapter.player_lock_pending)
			"player_lock_disabled":
				return bool(adapter.player_lock_disabled)

	if typeof(unit_ref) == TYPE_DICTIONARY:
		return bool(unit_ref.get(key, fallback))

	return fallback


func get_unit_float(unit_ref, key: String, fallback: float = 0.0) -> float:
	# Summary: Read numeric values from adapters, objects, or dictionaries.
	if unit_ref == null:
		return fallback

	if typeof(unit_ref) == TYPE_DICTIONARY:
		return float(unit_ref.get(key, fallback))

	if unit_ref is Object:
		var value = unit_ref.get(key)
		if value != null:
			return float(value)

	return fallback


func is_battle_ended() -> bool:
	# Summary: Read the scene-owned battle end flag without making the controller own cleanup.
	if battle_scene != null and battle_scene is Object:
		var ended_value = battle_scene.get("battle_v2_ended")
		if ended_value != null:
			return bool(ended_value)
	return false


func call_refresh_todo() -> void:
	# Summary: Ask the scene to repaint TODO UI when a queue result changes.
	if refresh_todo_callable.is_valid():
		refresh_todo_callable.call()


func call_refresh_unit() -> void:
	# Summary: Ask the scene to repaint unit UI after pending lock changes.
	if refresh_unit_callable.is_valid():
		refresh_unit_callable.call()


func append_log(text: String) -> void:
	# Summary: Write small queue-route messages to the scene log if available.
	if log_label != null and log_label is Object:
		log_label.text += text


func _think_result(status: String, reason: String) -> Dictionary:
	# Summary: Small standard packet for non-queue think-loop ticks.
	return {
		"status": status,
		"reason": reason,
		"labels": ["enemy_battle_controller"]
	}
