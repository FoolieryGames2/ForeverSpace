extends Node

class_name EnemyLogic


# ==========================================================
# ENEMY LOGIC
# ----------------------------------------------------------
# EnemyLogic chooses one enemy intent from a behavior profile.
# It does not queue TODOs, resolve damage, spend energy, or
# animate anything.
# ==========================================================

var behavior_profiles := {}
var last_intent_by_enemy_key := {}
var repeat_count_by_enemy_key := {}
var last_evade_msec_by_enemy_key := {}
var last_shield_switch_msec_by_enemy_key := {}
var enemy_evade_min_cooldown_seconds: float = 15.0
var smart_guy_default_shield_switch_cooldown_seconds: float = 12.0

const MAX_TRACKED_REPEAT_COUNT := 99
const FULL_LOOP_SAFE_INTENTS := [
	"enemy_reacquire_lock",
	"enemy_attack_primary",
	"enemy_attack_secondary",
	"enemy_switch_shield",
	"enemy_remove_shield",
	"enemy_load_consumable",
	"enemy_clear_loaded_consumable",
	"enemy_execute_consumable",
	"enemy_use_consumable",
	"enemy_repair",
	"enemy_recharge",
	"enemy_evade",
	"enemy_signal",
	"enemy_signal_disable_lock",
	"enemy_wait",
	"enemy_none"
]


func _init() -> void:
	# Summary: Build the behavior profile registry as soon as the handler is created.
	_build_behavior_profiles()


func set_enemy_evade_min_cooldown_seconds(value: float) -> void:
	# Summary: Let Battle V2 supply the shared player/enemy evade cooldown tuning value.
	enemy_evade_min_cooldown_seconds = max(float(value), 0.0)


func _build_behavior_profiles() -> void:
	# Summary: Register behavior profile ids to their owned behavior functions.
	if Globals.print_priority_5:
		print("EnemyLogic._build_behavior_profiles | Building behavior registry.")

	# Keep profile strings as the only behavior link enemy data needs to carry.
	behavior_profiles = {
		"raider_basic": Callable(self, "_behavior_raider_basic"),
		"raider_aggressive": Callable(self, "_behavior_raider_aggressive"),
		"test_basic_raider": Callable(self, "_behavior_test_basic_raider"),
		"test_aggressive_raider": Callable(self, "_behavior_test_aggressive_raider"),
		"test_coward_raider": Callable(self, "_behavior_test_coward_raider"),
		"test_lock_obsessed": Callable(self, "_behavior_test_lock_obsessed"),
		"test_signal_skirmisher": Callable(self, "_behavior_test_signal_skirmisher"),
		"smart_guy": Callable(self, "_behavior_smart_guy_balanced"),
		"smart_guy_balanced": Callable(self, "_behavior_smart_guy_balanced"),
		"smart_guy_balanced_slow": Callable(self, "_behavior_smart_guy_balanced_slow"),
		"smart_guy_survivor": Callable(self, "_behavior_smart_guy_survivor"),
		"smart_guy_bomber": Callable(self, "_behavior_smart_guy_bomber"),
		"smart_guy_tactician": Callable(self, "_behavior_smart_guy_tactician"),
		"smart_guy_pressure": Callable(self, "_behavior_smart_guy_pressure"),
		"smart_guy_2": Callable(self, "_behavior_smart_guy_2"),
		"smart_guy_3": Callable(self, "_behavior_smart_guy_3"),
		"test_smart_guy": Callable(self, "_behavior_smart_guy_balanced"),
		"raider_survivor": Callable(self, "_behavior_raider_survivor"),
		"raider_bomber": Callable(self, "_behavior_raider_bomber"),
		"raider_tactician": Callable(self, "_behavior_raider_tactician"),
		"raider_drone_opener": Callable(self, "_behavior_raider_drone_opener"),
		"raider_drone_survivor": Callable(self, "_behavior_raider_drone_survivor"),
		"raider_scripted_order": Callable(self, "_behavior_raider_scripted_order"),
		"test_drone_opener": Callable(self, "_behavior_raider_drone_opener")
	}


func choose_enemy_intent(update_package: Dictionary) -> Dictionary:
	# Summary: Choose one intent packet by looking up the enemy behavior profile and calling its behavior function.
	if Globals.print_priority_5:
		print("EnemyLogic.choose_enemy_intent | Choosing enemy intent.")

	# Pull the enemy from the update package; without it, no tactical choice can be made.
	var enemy = update_package.get("enemy", null)
	if enemy == null:
		return _intent_none(
			"missing enemy",
			[
				"enemy_intent_none",
				"enemy_behavior_profile_missing"
			]
		)

	var loop_safety: Dictionary = _validate_full_loop_context(update_package)
	if str(loop_safety.get("status", "")) != "success":
		return _intent_none(
			str(loop_safety.get("reason", "enemy loop safety blocked intent")),
			loop_safety.get("labels", [])
		)

	# Step 1/2 preview pass: build tactical readouts without changing behavior yet.
	# Later profile branches will read this packet instead of raw scattered fields.
	var awareness_preview: Dictionary = _build_awareness(update_package)
	if Globals.print_priority_5:
		_debug_print_awareness_preview(awareness_preview)
		_debug_print_capability_preview(_build_capability_preview(awareness_preview))

	# Enemy data should hold one simple behavior profile id.
	var profile_id := str(_unit_value(enemy, "behavior_profile", "raider_basic")).strip_edges()
	if profile_id == "":
		profile_id = "raider_basic"

	if Globals.print_priority_5:
		print("EnemyLogic.choose_enemy_intent | Profile lookup: ", profile_id)

	# Look up the behavior function from the registry.
	var behavior_func = behavior_profiles.get(profile_id, null)
	if behavior_func == null:
		return _intent_none(
			"unknown behavior profile: " + str(profile_id),
			[
				"enemy_intent_none",
				"enemy_behavior_profile_lookup",
				"enemy_behavior_profile_missing"
			]
		)

	# Call the selected behavior function and guard against malformed returns.
	var intent_packet = behavior_func.call(update_package)
	if typeof(intent_packet) != TYPE_DICTIONARY:
		return _intent_none(
			"behavior profile returned invalid intent: " + str(profile_id),
			[
				"enemy_intent_none",
				"enemy_behavior_function_called"
			]
		)

	# Add shared trace labels after the behavior-specific packet is returned.
	_append_intent_label(intent_packet, "enemy_behavior_profile_lookup")
	_append_intent_label(intent_packet, "enemy_behavior_function_called")

	return _finalize_full_loop_intent(intent_packet, update_package, profile_id)


func get_testing_enemy_data_packets() -> Dictionary:
	# Summary: Return starter enemy data packets for testing the behavior registry without battle resolution.
	return {
		"test_basic_raider": {
			"unit_id": "enemy_001",
			"display_name": "Test Basic Raider",
			"unit_side": "enemy",
			"behavior_profile": "test_basic_raider",
			"good_lock": false,
			"lock_pending": false,
			"lock_disabled": false,
			"hull_current": 80.0,
			"hull_max": 80.0,
			"can_evade": true,
			"selected_primary_weapon": "e_basic_energy_pew_pew",
			"selected_secondary_weapon": "enemy_snap_missile",
			"selected_enemy_shield": "basic_shield_mk1",
			"enemy_loaded_consumable": "repair_kit",
			"enemy_item_stacks": {
				"small_kinetic_rounds": 8,
				"medium_kinetic_rounds": 6,
				"large_kinetic_rounds": 1,
				"repair_kit": 1
			},
			"behavior_values": {
				"low_hull_evade_threshold": 0.35,
				"decision_cooldown": 1.5
			}
		},
		"test_aggressive_raider": {
			"unit_id": "enemy_002",
			"display_name": "Test Aggressive Raider",
			"unit_side": "enemy",
			"behavior_profile": "test_aggressive_raider",
			"good_lock": true,
			"lock_pending": false,
			"lock_disabled": false,
			"hull_current": 40.0,
			"hull_max": 80.0,
			"can_evade": true,
			"selected_primary_weapon": "e_basic_energy_pew_pew",
			"selected_secondary_weapon": "enemy_rail_snap",
			"selected_enemy_shield": "basic_shield_mk1",
			"enemy_loaded_consumable": "repair_kit",
			"enemy_item_stacks": {
				"small_kinetic_rounds": 8,
				"medium_kinetic_rounds": 9,
				"large_kinetic_rounds": 2,
				"repair_kit": 1
			},
			"behavior_values": {
				"critical_hull_evade_threshold": 0.15,
				"decision_cooldown": 1.0
			}
		},
		"test_coward_raider": {
			"unit_id": "enemy_003",
			"display_name": "Test Coward Raider",
			"unit_side": "enemy",
			"behavior_profile": "test_coward_raider",
			"good_lock": true,
			"lock_pending": false,
			"lock_disabled": false,
			"hull_current": 80.0,
			"hull_max": 80.0,
			"can_evade": true,
			"selected_primary_weapon": "e_basic_energy_pew_pew",
			"behavior_values": {
				"low_hull_evade_threshold": 0.60,
				"player_lock_evade": true,
				"decision_cooldown": 2.0
			}
		},
		"test_lock_obsessed": {
			"unit_id": "enemy_004",
			"display_name": "Test Lock Obsessed",
			"unit_side": "enemy",
			"behavior_profile": "test_lock_obsessed",
			"good_lock": false,
			"lock_pending": false,
			"lock_disabled": false,
			"hull_current": 80.0,
			"hull_max": 80.0,
			"selected_primary_weapon": "e_basic_energy_pew_pew",
			"behavior_values": {
				"decision_cooldown": 1.2
			}
		},
		"test_signal_skirmisher": {
			"unit_id": "enemy_005",
			"display_name": "Test Signal Skirmisher",
			"unit_side": "enemy",
			"behavior_profile": "test_signal_skirmisher",
			"good_lock": true,
			"lock_pending": false,
			"lock_disabled": false,
			"hull_current": 70.0,
			"hull_max": 90.0,
			"can_evade": true,
			"can_signal": true,
			"selected_primary_weapon": "e_basic_energy_pew_pew",
			"behavior_values": {
				"signal_preference": "disable_lock",
				"low_hull_evade_threshold": 0.40,
				"decision_cooldown": 1.8
			}
		}
	}


func get_testing_behavior_matrix() -> Array:
	# Summary: Return small behavior test cases with expected intent ids for manual and future automated checks.
	return [
		#{
			#"test_id": "basic_raider_no_lock",
			#"enemy": {
				#"behavior_profile": "test_basic_raider",
				#"good_lock": false,
				#"lock_pending": false,
				#"lock_disabled": false,
				#"hull_current": 80.0,
				#"hull_max": 80.0,
				#"can_evade": true,
				#"selected_primary_weapon": "enemy_laser"
			#},
			#"player_state": {},
			#"expected_intent_id": "enemy_reacquire_lock"
		#},
		#{
			#"test_id": "basic_raider_low_hull",
			#"enemy": {
				#"behavior_profile": "test_basic_raider",
				#"good_lock": true,
				#"hull_current": 20.0,
				#"hull_max": 80.0,
				#"can_evade": true,
				#"selected_primary_weapon": "enemy_laser"
			#},
			#"player_state": {},
			#"expected_intent_id": "enemy_evade"
		#},
		#{
			#"test_id": "aggressive_raider_good_lock",
			#"enemy": {
				#"behavior_profile": "test_aggressive_raider",
				#"good_lock": true,
				#"hull_current": 40.0,
				#"hull_max": 80.0,
				#"selected_primary_weapon": "enemy_laser",
				#"primary_disabled": false
			#},
			#"player_state": {},
			#"expected_intent_id": "enemy_attack_primary"
		#},
		#{
			#"test_id": "coward_raider_player_has_lock",
			#"enemy": {
				#"behavior_profile": "test_coward_raider",
				#"good_lock": true,
				#"hull_current": 80.0,
				#"hull_max": 80.0,
				#"can_evade": true,
				#"behavior_values": {
					#"player_lock_evade": true
				#}
			#},
			#"player_state": {
				#"good_lock": true
			#},
			#"expected_intent_id": "enemy_evade"
		#},
		#{
			#"test_id": "unknown_profile",
			#"enemy": {
				#"behavior_profile": "not_real"
			#},
			#"player_state": {},
			#"expected_intent_id": "enemy_none"
		#}
	]


func run_testing_behavior_matrix() -> Array:
	# Summary: Run the built-in behavior matrix and return result dictionaries without touching battle queues.
	if Globals.print_priority_5:
		print("EnemyLogic.run_testing_behavior_matrix | Running behavior matrix.")

	# Store one result per test so the caller can print, inspect, or route it into a debug widget later.
	var results := []

	# Execute each test as a normal choose_enemy_intent call.
	for test_case in get_testing_behavior_matrix():
		var update_package := {
			"enemy": test_case.get("enemy", {}),
			"player_state": test_case.get("player_state", {})
		}
		var intent_packet := choose_enemy_intent(update_package)
		var expected_intent := str(test_case.get("expected_intent_id", ""))
		var actual_intent := str(intent_packet.get("intent_id", ""))
		var passed := actual_intent == expected_intent

		results.append({
			"test_id": test_case.get("test_id", ""),
			"expected_intent_id": expected_intent,
			"actual_intent_id": actual_intent,
			"passed": passed,
			"intent_packet": intent_packet
		})

		if Globals.print_priority_5:
			print(
				"EnemyLogic matrix test | ",
				test_case.get("test_id", ""),
				" | expected=",
				expected_intent,
				" | actual=",
				actual_intent,
				" | passed=",
				passed
			)

	return results



func _behavior_smart_guy(update_package: Dictionary) -> Dictionary:
	# Summary: Choose Smart Guy's predictable tactical intent using awareness/capability helpers.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)
	var awareness: Dictionary = _build_awareness(update_package)

	# Smart Guy is only smart if he refuses to act from bad state.
	if not _awareness_can_act(awareness):
		return _intent_none(
			"smart guy cannot act: " + _awareness_wait_reason(awareness),
			[
				"enemy_intent_none",
				"enemy_behavior_profile_smart_guy",
				"enemy_awareness_smart_guy_v1"
			]
		)

	var values := _get_behavior_values(enemy)
	var execute_player_threshold := float(values.get("execute_player_threshold", 0.28))
	var critical_hull_threshold := float(values.get("critical_hull_evade_threshold", 0.22))
	var low_hull_threshold := float(values.get("low_hull_evade_threshold", 0.45))
	var low_energy_threshold := float(values.get("low_energy_secondary_threshold", 0.35))
	var shield_hull_threshold := float(values.get("shield_hull_threshold", 0.90))
	var repair_hull_threshold := float(values.get("repair_hull_threshold", 0.30))
	var explosive_player_threshold := float(values.get("explosive_player_threshold", 0.55))
	var shield_switch_cooldown := float(values.get("shield_switch_min_cooldown_seconds", smart_guy_default_shield_switch_cooldown_seconds))

	var enemy_health_ratio := float(awareness.get("enemy_health_ratio", 1.0))
	var player_health_ratio := float(awareness.get("player_health_ratio", 1.0))
	var enemy_energy_ratio := float(awareness.get("enemy_energy_ratio", 1.0))

	# Disabled lock is not fixable by this profile yet, so wait instead of pretending.
	if bool(awareness.get("enemy_lock_disabled", false)):
		return _intent_wait(enemy, player_state, "smart guy lock disabled", "smart_guy")
		# ===== Consumable priority check: execute loaded consumables before reacquire/attack logic =====

	# 1. Explosive consumable:
	# Only fires if player is under explosive threshold AND enemy already has a good lock.
	# _can_execute_explosive_consumable also checks loaded/ready/lock/damage validity.
	if _can_execute_explosive_consumable(awareness, explosive_player_threshold):
		return _intent_execute_consumable_from_awareness(
			awareness,
			enemy,
			player_state,
			"smart guy explosive consumable priority",
			95,
			[
				"enemy_intent_selected",
				"enemy_consumable_intent",
				"enemy_explosive_intent",
				"enemy_behavior_profile_smart_guy",
				"enemy_awareness_smart_guy_v1"
			],
			{
				"behavior_profile": "smart_guy",
				"player_health_ratio": player_health_ratio,
				"threshold": explosive_player_threshold,
				"consumable_item_id": str(awareness.get("consumable_item_id", "")),
				"consumable_group": str(awareness.get("consumable_group", "")),
				"rule": "explosive_consumable_priority"
			}
		)

	# 2. Repair consumable:
	# Only fires if enemy is under repair threshold and a repair consumable is loaded/ready.
	if _can_execute_repair_consumable(awareness, repair_hull_threshold):
		return _intent_execute_consumable_from_awareness(
			awareness,
			enemy,
			enemy,
			"smart guy repair consumable priority",
			93,
			[
				"enemy_intent_selected",
				"enemy_consumable_intent",
				"enemy_repair_intent",
				"enemy_behavior_profile_smart_guy",
				"enemy_awareness_smart_guy_v1"
			],
			{
				"behavior_profile": "smart_guy",
				"enemy_health_ratio": enemy_health_ratio,
				"threshold": repair_hull_threshold,
				"consumable_item_id": str(awareness.get("consumable_item_id", "")),
				"consumable_group": str(awareness.get("consumable_group", "")),
				"rule": "repair_consumable_priority"
			}
		)

	# 3. Drone consumable:
	# Drone/utility deployment gets priority once it is loaded and ready.
	if _can_execute_drone_consumable(awareness):
		return _intent_execute_consumable_from_awareness(
			awareness,
			enemy,
			enemy,
			"smart guy drone consumable priority",
			91,
			[
				"enemy_intent_selected",
				"enemy_consumable_intent",
				"enemy_drone_intent",
				"enemy_behavior_profile_smart_guy",
				"enemy_awareness_smart_guy_v1"
			],
			{
				"behavior_profile": "smart_guy",
				"consumable_item_id": str(awareness.get("consumable_item_id", "")),
				"consumable_group": str(awareness.get("consumable_group", "")),
				"rule": "drone_consumable_priority"
			}
		)

	# 4. Other ready utility consumables:
	# This catches ready signal/pulse/other non-explosive, non-repair, non-drone consumables.
	# It stays below the typed consumable checks so specialized logic wins first.
	if _can_execute_consumable(awareness):
		return _intent_execute_consumable_from_awareness(
			awareness,
			enemy,
			enemy,
			"smart guy utility consumable priority",
			90,
			[
				"enemy_intent_selected",
				"enemy_consumable_intent",
				"enemy_utility_consumable_intent",
				"enemy_behavior_profile_smart_guy",
				"enemy_awareness_smart_guy_v1"
			],
			{
				"behavior_profile": "smart_guy",
				"consumable_item_id": str(awareness.get("consumable_item_id", "")),
				"consumable_group": str(awareness.get("consumable_group", "")),
				"rule": "utility_consumable_priority"
			}
		)

	# ===== End consumable priority check =====
	# Predictable rule: Smart Guy always repairs his targeting first.
	if _awareness_needs_reacquire(awareness):
		return _intent_selected(
			"enemy_reacquire_lock",
			enemy,
			player_state,
			"smart guy wants clean lock first",
			90,
			[
				"enemy_intent_selected",
				"enemy_reacquire_lock_intent",
				"enemy_behavior_profile_smart_guy",
				"enemy_awareness_smart_guy_v1"
			],
			{
				"behavior_profile": "smart_guy",
				"awareness_driven": true,
				"rule": "reacquire_before_attack"
			}
		)

	# If the player is almost finished, Smart Guy takes the most reliable available shot.
	if player_health_ratio <= execute_player_threshold:
		if _can_execute_explosive_consumable(awareness, explosive_player_threshold):
			return _intent_execute_consumable_from_awareness(
				awareness,
				enemy,
				player_state,
				"smart guy execute explosive",
				88,
				[
					"enemy_intent_selected",
					"enemy_consumable_intent",
					"enemy_explosive_intent",
					"enemy_behavior_profile_smart_guy",
					"enemy_awareness_smart_guy_v1"
				],
				{
					"behavior_profile": "smart_guy",
					"player_health_ratio": player_health_ratio,
					"rule": "execute_low_player_hull_explosive"
				}
			)
		if _can_use_primary(awareness):
			return _intent_selected(
				"enemy_attack_primary",
				enemy,
				player_state,
				"smart guy execute primary",
				85,
				[
					"enemy_intent_selected",
					"enemy_attack_intent",
					"enemy_behavior_profile_smart_guy",
					"enemy_awareness_smart_guy_v1"
				],
				{
					"behavior_profile": "smart_guy",
					"player_health_ratio": player_health_ratio,
					"awareness_driven": true,
					"rule": "execute_low_player_hull"
				}
			)
		if _can_use_secondary(awareness):
			return _intent_selected(
				"enemy_attack_secondary",
				enemy,
				player_state,
				"smart guy execute secondary",
				82,
				[
					"enemy_intent_selected",
					"enemy_attack_intent",
					"enemy_behavior_profile_smart_guy",
					"enemy_awareness_smart_guy_v1"
				],
				{
					"behavior_profile": "smart_guy",
					"player_health_ratio": player_health_ratio,
					"awareness_driven": true,
					"rule": "execute_low_player_hull_fallback"
				}
			)

	# Critical hull means survival before damage; repair is preferred if the enemy has a ready recovery kit.
	if enemy_health_ratio <= repair_hull_threshold and _can_execute_repair_consumable(awareness, repair_hull_threshold):
		return _intent_execute_consumable_from_awareness(
			awareness,
			enemy,
			enemy,
			"smart guy recovery kit",
			83,
			[
				"enemy_intent_selected",
				"enemy_consumable_intent",
				"enemy_repair_intent",
				"enemy_behavior_profile_smart_guy",
				"enemy_awareness_smart_guy_v1"
			],
			{
				"behavior_profile": "smart_guy",
				"enemy_health_ratio": enemy_health_ratio,
				"threshold": repair_hull_threshold,
				"rule": "critical_recovery"
			}
		)

	# Critical hull means survival before damage.
	if enemy_health_ratio <= critical_hull_threshold and _can_evade_now(awareness):
		return _intent_selected(
			"enemy_evade",
			enemy,
			player_state,
			"smart guy critical hull evade",
			80,
			[
				"enemy_intent_selected",
				"enemy_evade_intent",
				"enemy_behavior_profile_smart_guy",
				"enemy_awareness_smart_guy_v1"
			],
			{
				"behavior_profile": "smart_guy",
				"enemy_health_ratio": enemy_health_ratio,
				"threshold": critical_hull_threshold,
				"awareness_driven": true,
				"rule": "critical_survival"
			}
		)

	# If the player has a firing solution and Smart Guy is not already switching, raise the mirror shield before normal pressure.
	if _smart_guy_should_switch_shield(enemy, awareness, shield_hull_threshold, shield_switch_cooldown):
		_mark_smart_guy_shield_switch(enemy)
		return _intent_selected(
			"enemy_switch_shield",
			enemy,
			player_state,
			"smart guy raises mirror shield under lock",
			75,
			[
				"enemy_intent_selected",
				"enemy_switch_shield_intent",
				"enemy_behavior_profile_smart_guy",
				"enemy_awareness_smart_guy_v1"
			],
			{
				"behavior_profile": "smart_guy",
				"shield_item_id": str(awareness.get("shield_item_id", "")),
				"pending_shield": str(awareness.get("shield_item_id", "")),
				"pending_shield_data": _safe_dictionary(awareness.get("shield_item_data", {})),
				"player_has_good_lock": bool(awareness.get("player_has_good_lock", false)),
				"enemy_health_ratio": enemy_health_ratio,
				"threshold": shield_hull_threshold,
				"cooldown_seconds": shield_switch_cooldown,
				"awareness_driven": true,
				"rule": "defend_against_player_lock"
			}
		)

	# Low energy makes Smart Guy prefer ammo if the secondary route is ready.
	if enemy_energy_ratio <= low_energy_threshold and _can_use_secondary(awareness):
		return _intent_selected(
			"enemy_attack_secondary",
			enemy,
			player_state,
			"smart guy conserves energy with secondary",
			70,
			[
				"enemy_intent_selected",
				"enemy_attack_intent",
				"enemy_behavior_profile_smart_guy",
				"enemy_awareness_smart_guy_v1"
			],
			{
				"behavior_profile": "smart_guy",
				"enemy_energy_ratio": enemy_energy_ratio,
				"secondary_item_id": str(awareness.get("secondary_item_id", "")),
				"awareness_driven": true,
				"rule": "conserve_energy"
			}
		)

	# Normal pressure: primary first because it is reliable and does not spend ammo.
	if _can_use_primary(awareness):
		return _intent_selected(
			"enemy_attack_primary",
			enemy,
			player_state,
			"smart guy pressure primary",
			60,
			[
				"enemy_intent_selected",
				"enemy_attack_intent",
				"enemy_behavior_profile_smart_guy",
				"enemy_awareness_smart_guy_v1"
			],
			{
				"behavior_profile": "smart_guy",
				"primary_item_id": str(awareness.get("primary_item_id", "")),
				"primary_energy_cost": float(awareness.get("primary_energy_cost", 0.0)),
				"awareness_driven": true,
				"rule": "normal_primary_pressure"
			}
		)

	# If energy blocks primary but ammo is ready, keep pressure with secondary.
	if _can_use_secondary(awareness):
		return _intent_selected(
			"enemy_attack_secondary",
			enemy,
			player_state,
			"smart guy fallback secondary",
			55,
			[
				"enemy_intent_selected",
				"enemy_attack_intent",
				"enemy_behavior_profile_smart_guy",
				"enemy_awareness_smart_guy_v1"
			],
			{
				"behavior_profile": "smart_guy",
				"secondary_item_id": str(awareness.get("secondary_item_id", "")),
				"secondary_ammo_group": str(awareness.get("secondary_ammo_group", "")),
				"secondary_ammo_cost": int(awareness.get("secondary_ammo_cost", 0)),
				"secondary_ammo_count": int(awareness.get("secondary_ammo_count", 0)),
				"awareness_driven": true,
				"rule": "secondary_fallback"
			}
		)

	# Low hull gets a late defensive chance if attacks are blocked.
	if enemy_health_ratio <= low_hull_threshold and _can_evade_now(awareness):
		return _intent_selected(
			"enemy_evade",
			enemy,
			player_state,
			"smart guy low hull fallback evade",
			45,
			[
				"enemy_intent_selected",
				"enemy_evade_intent",
				"enemy_behavior_profile_smart_guy",
				"enemy_awareness_smart_guy_v1"
			],
			{
				"behavior_profile": "smart_guy",
				"enemy_health_ratio": enemy_health_ratio,
				"threshold": low_hull_threshold,
				"awareness_driven": true,
				"rule": "late_defensive_fallback"
			}
		)

	return _intent_wait(enemy, player_state, "smart guy wait: " + _awareness_wait_reason(awareness), "smart_guy")


func _behavior_smart_guy_2(update_package: Dictionary) -> Dictionary:
	# Summary: Test-only Smart Guy 2 profile. Loads a consumable, then executes it when ready.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)
	var awareness: Dictionary = _build_awareness(update_package)

	if Globals.print_priority_5:
		print(
			"[P5_SMART_GUY_2_ENTERED]",
			" profile=", str(enemy.behavior_profile if enemy != null else ""),
			" can_act=", _awareness_can_act(awareness),
			" wait_reason=", _awareness_wait_reason(awareness),
			" loaded_consumable=", str(awareness.get("loaded_consumable", "")),
			" consumable_item_id=", str(awareness.get("consumable_item_id", "")),
			" consumable_group=", str(awareness.get("consumable_group", "")),
			" consumable_ready=", bool(awareness.get("consumable_ready", false))
		)

	# Still respect hard action state. If the enemy cannot act, do not queue anything.
	if not _awareness_can_act(awareness):
		return _intent_none(
			"smart guy 2 cannot act: " + _awareness_wait_reason(awareness),
			[
				"enemy_intent_none",
				"enemy_behavior_profile_smart_guy_2",
				"enemy_awareness_smart_guy_v1",
				"smart_guy_2_load_execute_test"
			]
		)

	# 1. If a consumable is already loaded and ready, execute it.
	if _can_execute_consumable(awareness):
		var execute_target = enemy
		var consumable_group := str(awareness.get("consumable_group", "")).strip_edges().to_lower()

		if consumable_group == "explosive":
			execute_target = player_state

		if Globals.print_priority_5:
			print(
				"[P5_SMART_GUY_2_EXECUTE_ONLY_SELECT]",
				" item_id=", str(awareness.get("consumable_item_id", "")),
				" group=", consumable_group,
				" target_is_player=", execute_target == player_state
			)

		return _intent_execute_consumable_from_awareness(
			awareness,
			enemy,
			execute_target,
			"smart guy 2 executes loaded consumable",
			100,
			[
				"enemy_intent_selected",
				"enemy_consumable_intent",
				"enemy_execute_consumable_intent",
				"enemy_behavior_profile_smart_guy_2",
				"enemy_awareness_smart_guy_v1",
				"smart_guy_2_load_execute_test"
			],
			{
				"behavior_profile": "smart_guy_2",
				"rule": "execute_loaded_consumable_only",
				"consumable_item_id": str(awareness.get("consumable_item_id", "")),
				"consumable_id": str(awareness.get("consumable_item_id", "")),
				"item_id": str(awareness.get("consumable_item_id", "")),
				"consumable_group": consumable_group,
				"awareness_driven": true
			}
		)

	# 2. If nothing is ready yet, load the consumable selected by awareness from held stacks.
	if _can_load_consumable(awareness):
		if Globals.print_priority_5:
			print(
				"[P5_SMART_GUY_2_LOAD_AWARENESS_SELECT]",
				" item_id=", str(awareness.get("consumable_item_id", "")),
				" group=", str(awareness.get("consumable_group", "")),
				" stack_count=", int(awareness.get("consumable_stack_count", 0))
			)

		return _intent_load_consumable_from_awareness(
			awareness,
			enemy,
			enemy,
			"smart guy 2 loads awareness-selected consumable before execute",
			100,
			[
				"enemy_intent_selected",
				"enemy_consumable_intent",
				"enemy_load_consumable_intent",
				"enemy_behavior_profile_smart_guy_2",
				"enemy_awareness_smart_guy_v1",
				"smart_guy_2_load_execute_test"
			],
			{
				"behavior_profile": "smart_guy_2",
				"rule": "load_awareness_selected_consumable_before_execute",
				"awareness_driven": true
			}
		)

	# 3. Fallback: if awareness did not select a candidate, load the first held consumable packet.
	var enemy_loadout: Dictionary = _safe_dictionary(update_package.get("enemy_loadout", {}))
	var usable_consumables: Array = []

	var raw_usable = enemy_loadout.get("usable_consumables", [])
	if typeof(raw_usable) == TYPE_ARRAY:
		usable_consumables = raw_usable

	if Globals.print_priority_5:
		print(
			"[P5_SMART_GUY_2_LOAD_EXECUTE]",
			" usable_count=", usable_consumables.size(),
			" loaded_consumable=", str(awareness.get("loaded_consumable", "")),
			" consumable_ready=", bool(awareness.get("consumable_ready", false))
		)

	for raw_consumable in usable_consumables:
		if typeof(raw_consumable) != TYPE_DICTIONARY:
			continue

		var consumable_packet: Dictionary = raw_consumable
		var consumable_item_id := str(consumable_packet.get("item_id", "")).strip_edges()
		if consumable_item_id == "":
			continue

		var stack_count := int(consumable_packet.get("stack_count", 0))
		if stack_count <= 0:
			continue

		var consumable_group := str(consumable_packet.get("consumable_group", "")).strip_edges().to_lower()
		var consumable_item_data: Dictionary = _safe_dictionary(consumable_packet.get("item_data", {}))

		if Globals.print_priority_5:
			print(
				"[P5_SMART_GUY_2_LOAD_ONLY_SELECT]",
				" item_id=", consumable_item_id,
				" group=", consumable_group,
				" stack_count=", stack_count
			)

		return _intent_selected(
			"enemy_load_consumable",
			enemy,
			enemy,
			"smart guy 2 loads consumable before execute",
			100,
			[
				"enemy_intent_selected",
				"enemy_consumable_intent",
				"enemy_load_consumable_intent",
				"enemy_behavior_profile_smart_guy_2",
				"enemy_awareness_smart_guy_v1",
				"smart_guy_2_load_execute_test"
			],
			{
				"behavior_profile": "smart_guy_2",
				"rule": "load_first_available_consumable_before_execute",
				"consumable_item_id": consumable_item_id,
				"consumable_id": consumable_item_id,
				"item_id": consumable_item_id,
				"consumable_group": consumable_group,
				"item_data": consumable_item_data,
				"loadable_consumable": consumable_packet.duplicate(true),
				"awareness_driven": true
			}
		)

	# 4. If it has nothing loadable and nothing executable, do nothing.
	if Globals.print_priority_5:
		print("[P5_SMART_GUY_2_LOAD_EXECUTE_WAIT] no loaded-ready or usable consumables found")

	return _intent_wait(
		enemy,
		player_state,
		"smart guy 2 load/execute test waits: no usable consumables",
		"smart_guy_2"
	)


func _behavior_smart_guy_balanced(update_package: Dictionary) -> Dictionary:
	# Summary: Balanced Smart Guy profile using the shared Smart Guy rule engine.
	return _behavior_smart_guy_profile(update_package, "smart_guy_balanced", "balanced")


func _behavior_smart_guy_balanced_slow(update_package: Dictionary) -> Dictionary:
	# Summary: Balanced Smart Guy decisions with a slower response cadence.
	return _behavior_smart_guy_profile(update_package, "smart_guy_balanced_slow", "balanced_slow")


func _behavior_smart_guy_survivor(update_package: Dictionary) -> Dictionary:
	# Summary: Defensive Smart Guy profile that favors repair, recharge, and evasion.
	return _behavior_smart_guy_profile(update_package, "smart_guy_survivor", "survivor")


func _behavior_smart_guy_bomber(update_package: Dictionary) -> Dictionary:
	# Summary: Offensive Smart Guy profile that favors explosives and pressure tools.
	return _behavior_smart_guy_profile(update_package, "smart_guy_bomber", "bomber")


func _behavior_smart_guy_tactician(update_package: Dictionary) -> Dictionary:
	# Summary: Mixed Smart Guy profile that uses the widest tool belt before weapons.
	return _behavior_smart_guy_profile(update_package, "smart_guy_tactician", "tactician")


func _behavior_smart_guy_pressure(update_package: Dictionary) -> Dictionary:
	# Summary: Pressure Smart Guy profile that favors drones, signal/pulse tools, then weapons.
	return _behavior_smart_guy_profile(update_package, "smart_guy_pressure", "pressure")


func _behavior_smart_guy_3(update_package: Dictionary) -> Dictionary:
	# Summary: Compatibility wrapper for authored Smart Guy 3 encounters.
	return _behavior_smart_guy_profile(update_package, "smart_guy_3", "balanced")


func _behavior_smart_guy_profile(update_package: Dictionary, profile_label: String, profile_flavor: String) -> Dictionary:
	# Summary: Shared Smart Guy rule engine. Profile defaults and behavior_values decide the personality.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)
	var awareness: Dictionary = _build_awareness(update_package)

	var values := _smart_guy_profile_values(enemy, profile_flavor)
	var repair_hull_threshold := float(values.get("smart_guy_3_repair_hull_threshold", values.get("repair_hull_threshold", 0.90)))
	var recharge_energy_threshold := float(values.get("recharge_energy_threshold", 0.35))
	var low_energy_ammo_threshold := float(values.get("smart_guy_3_low_energy_ammo_threshold", values.get("low_energy_ammo_threshold", 0.50)))
	var evade_health_threshold := float(values.get("evade_health_threshold", values.get("low_hull_evade_threshold", 0.20)))
	var allow_forced_zero_energy_primary := bool(values.get("allow_forced_zero_energy_primary", false))
	var enemy_health_ratio := float(awareness.get("enemy_health_ratio", 1.0))
	var enemy_energy_ratio := float(awareness.get("enemy_energy_ratio", 1.0))
	var enemy_energy_available := float(awareness.get("enemy_energy_available", 0.0))

	if Globals.print_priority_5:
		print(
			"[P5_SMART_GUY_3_ENTERED]",
			" profile=", profile_label,
			" flavor=", profile_flavor,
			" can_act=", _awareness_can_act(awareness),
			" wait_reason=", _awareness_wait_reason(awareness),
			" hp_ratio=", enemy_health_ratio,
			" energy_ratio=", enemy_energy_ratio,
			" energy_available=", enemy_energy_available,
			" loaded=", str(awareness.get("loaded_consumable_item_id", "")),
			" consumable=", str(awareness.get("consumable_item_id", "")),
			" group=", str(awareness.get("consumable_group", "")),
			" ready=", bool(awareness.get("consumable_ready", false)),
			" usable_count=", int(awareness.get("usable_consumable_count", 0))
		)

	if not _awareness_can_act(awareness):
		return _intent_none(
			profile_label + " cannot act: " + _awareness_wait_reason(awareness),
			[
				"enemy_intent_none",
				"enemy_behavior_profile_" + profile_label,
				"enemy_awareness_smart_guy_v1",
				"smart_guy_3_priority_test"
			]
		)

	# Energy-empty safety comes before weapon forcing. Power the shield down so drain can stop.
	if _smart_guy_3_should_remove_shield_for_empty_energy(awareness):
		return _intent_selected(
			"enemy_remove_shield",
			enemy,
			enemy,
			profile_label + " removes shield because energy is empty",
			110,
			[
				"enemy_intent_selected",
				"enemy_remove_shield_intent",
				"enemy_behavior_profile_" + profile_label,
				"enemy_awareness_smart_guy_v1",
				"smart_guy_3_priority_test"
			],
			{
				"behavior_profile": profile_label,
				"rule": "energy_empty_remove_shield",
				"enemy_energy_available": enemy_energy_available,
				"enemy_energy_ratio": enemy_energy_ratio,
				"shield_power_level": int(awareness.get("shield_power_level", 0)),
				"awareness_driven": true
			}
		)

	if _can_replace_shield(awareness) and enemy_energy_available > 0.01:
		var replacement_shield_id := str(awareness.get("shield_replacement_item_id", awareness.get("shield_item_id", ""))).strip_edges()
		return _intent_selected(
			"enemy_switch_shield",
			enemy,
			enemy,
			profile_label + " equips an owned replacement shield",
			108,
			[
				"enemy_intent_selected",
				"enemy_switch_shield_intent",
				"enemy_replace_broken_shield_intent",
				"enemy_behavior_profile_" + profile_label,
				"enemy_awareness_smart_guy_v1",
				"enemy_logic_tag_control"
			],
			{
				"behavior_profile": profile_label,
				"rule": "replace_missing_or_broken_shield",
				"item_id": replacement_shield_id,
				"shield_item_id": replacement_shield_id,
				"item_data": _safe_dictionary(awareness.get("shield_replacement_item_data", awareness.get("shield_item_data", {}))),
				"awareness_driven": true
			}
		)

	# Loaded consumables execute from the loaded slot, not from whichever stack item generic awareness selected.
	if _can_execute_consumable(awareness):
		var loaded_group := str(awareness.get("loaded_consumable_group", "")).strip_edges().to_lower()
		if loaded_group == "":
			loaded_group = str(awareness.get("consumable_group", "")).strip_edges().to_lower()

		if _smart_guy_loaded_group_needs_lock(loaded_group):
			if bool(awareness.get("enemy_lock_disabled", false)):
				return _intent_wait(enemy, player_state, profile_label + " waits: loaded " + loaded_group + " but enemy lock is disabled", profile_label)
			if _awareness_needs_reacquire(awareness):
				return _intent_reacquire_lock(enemy, player_state, profile_label + " reacquires lock for loaded " + loaded_group, profile_label)

		var loaded_intent := _smart_guy_execute_loaded_consumable_intent(
			awareness,
			enemy,
			player_state,
			profile_label,
			values,
			loaded_group,
			repair_hull_threshold,
			recharge_energy_threshold
		)
		if not loaded_intent.is_empty():
			return loaded_intent

	var desired_groups: Array = _smart_guy_desired_consumable_groups(values, awareness, repair_hull_threshold, recharge_energy_threshold)
	var desired_consumable: Dictionary = _smart_guy_3_find_desired_consumable(awareness, desired_groups)

	if _smart_guy_should_clear_loaded_consumable(
		awareness,
		desired_consumable,
		values,
		repair_hull_threshold,
		recharge_energy_threshold
	):
		return _intent_clear_loaded_consumable(
			enemy,
			enemy,
			profile_label + " clears stale loaded consumable",
			106,
			[
				"enemy_intent_selected",
				"enemy_consumable_intent",
				"enemy_clear_loaded_consumable_intent",
				"enemy_behavior_profile_" + profile_label,
				"enemy_awareness_smart_guy_v1",
				"smart_guy_stale_consumable_clear"
			],
			{
				"behavior_profile": profile_label,
				"rule": "clear_stale_loaded_consumable",
				"loaded_consumable_item_id": str(awareness.get("loaded_consumable_item_id", "")),
				"loaded_consumable_group": str(awareness.get("loaded_consumable_group", "")),
				"desired_consumable_item_id": str(desired_consumable.get("item_id", "")),
				"desired_groups": desired_groups.duplicate()
			}
		)

	if not desired_consumable.is_empty() and not bool(awareness.get("consumable_loaded", false)):
		var desired_group := str(desired_consumable.get("consumable_group", "")).strip_edges().to_lower()
		return _intent_load_consumable_from_candidate(
			desired_consumable,
			enemy,
			profile_label + " loads " + desired_group + " consumable",
			103,
			[
				"enemy_intent_selected",
				"enemy_consumable_intent",
				"enemy_load_consumable_intent",
				"enemy_behavior_profile_" + profile_label,
				"enemy_awareness_smart_guy_v1",
				"smart_guy_3_priority_test"
			],
			{
				"behavior_profile": profile_label,
				"rule": "load_profile_preferred_consumable",
				"enemy_health_ratio": enemy_health_ratio,
				"threshold": repair_hull_threshold,
				"desired_groups": desired_groups.duplicate()
			}
		)

	# Consumable path is exhausted or not useful; now move into weapon choices.
	if _awareness_needs_reacquire(awareness):
		return _intent_reacquire_lock(enemy, player_state, profile_label + " reacquires lock before weapon fallback", profile_label)

	if enemy_health_ratio <= evade_health_threshold and _can_evade_now(awareness):
		return _intent_selected(
			"enemy_evade",
			enemy,
			player_state,
			profile_label + " evades under pressure",
			95,
			[
				"enemy_intent_selected",
				"enemy_evade_intent",
				"enemy_behavior_profile_" + profile_label,
				"enemy_awareness_smart_guy_v1"
			],
			{
				"behavior_profile": profile_label,
				"threshold": evade_health_threshold,
				"enemy_health_ratio": enemy_health_ratio,
				"awareness_driven": true
			}
		)

	if enemy_energy_ratio < low_energy_ammo_threshold:
		if _can_use_secondary(awareness):
			return _intent_selected(
				"enemy_attack_secondary",
				enemy,
				player_state,
				"smart guy 3 low energy tries ammo",
				90,
				[
					"enemy_intent_selected",
					"enemy_attack_intent",
					"enemy_behavior_profile_" + profile_label,
					"enemy_awareness_smart_guy_v1",
					"smart_guy_3_priority_test"
				],
				{
					"behavior_profile": profile_label,
					"rule": "low_energy_try_ammo",
					"enemy_energy_ratio": enemy_energy_ratio,
					"threshold": low_energy_ammo_threshold,
					"secondary_item_id": str(awareness.get("secondary_item_id", "")),
					"secondary_ammo_group": str(awareness.get("secondary_ammo_group", "")),
					"secondary_ammo_count": int(awareness.get("secondary_ammo_count", 0))
				}
			)

		if allow_forced_zero_energy_primary and _smart_guy_3_secondary_ammo_empty(awareness):
			return _intent_force_primary_smart_guy_3(enemy, player_state, awareness, profile_label + " ammo empty forces primary", 89, "ammo_empty_force_primary", profile_label)

	if _can_use_primary(awareness):
		return _intent_selected(
			"enemy_attack_primary",
			enemy,
			player_state,
			profile_label + " primary fallback",
			80,
			[
				"enemy_intent_selected",
				"enemy_attack_intent",
				"enemy_behavior_profile_" + profile_label,
				"enemy_awareness_smart_guy_v1",
				"smart_guy_3_priority_test"
			],
			{
				"behavior_profile": profile_label,
				"rule": "no_consumables_try_primary",
				"primary_item_id": str(awareness.get("primary_item_id", ""))
			}
		)

	if _can_use_secondary(awareness):
		return _intent_selected(
			"enemy_attack_secondary",
			enemy,
			player_state,
			profile_label + " secondary fallback",
			70,
			[
				"enemy_intent_selected",
				"enemy_attack_intent",
				"enemy_behavior_profile_" + profile_label,
				"enemy_awareness_smart_guy_v1",
				"smart_guy_3_priority_test"
			],
			{
				"behavior_profile": profile_label,
				"rule": "secondary_fallback",
				"secondary_item_id": str(awareness.get("secondary_item_id", ""))
			}
		)

	if allow_forced_zero_energy_primary and bool(awareness.get("primary_available", false)) and bool(awareness.get("enemy_has_good_lock", false)):
		return _intent_force_primary_smart_guy_3(enemy, player_state, awareness, profile_label + " final forced primary", 60, "final_force_primary", profile_label)

	return _intent_wait(enemy, player_state, profile_label + " waits: no usable consumable or weapon path", profile_label)


func _smart_guy_3_find_desired_consumable(awareness: Dictionary, desired_groups: Array) -> Dictionary:
	# Summary: Smart Guy 3 chooses directly from usable stacks, bypassing the generic first-consumable loadout shortcut.
	var usable_consumables: Array = _safe_array(awareness.get("usable_consumables", []))
	for raw_group in desired_groups:
		var candidate := _find_usable_consumable_by_group(usable_consumables, str(raw_group))
		if not candidate.is_empty() and _item_allows_enemy_action(_safe_dictionary(candidate.get("item_data", {})), "enemy_can_use"):
			return candidate
	return {}


func _smart_guy_profile_values(enemy, profile_flavor: String) -> Dictionary:
	# Summary: Merge Smart Guy profile defaults with authored behavior_values.
	var values := _smart_guy_profile_defaults(profile_flavor)
	var authored_values := _get_behavior_values(enemy)
	for key in authored_values.keys():
		values[key] = authored_values[key]
	return values


func _smart_guy_profile_defaults(profile_flavor: String) -> Dictionary:
	# Summary: Provide conservative default knobs for each Smart Guy family profile.
	var flavor := profile_flavor.strip_edges().to_lower()
	var values := {
		"repair_hull_threshold": 0.90,
		"recharge_energy_threshold": 0.35,
		"low_energy_ammo_threshold": 0.50,
		"evade_health_threshold": 0.20,
		"shield_repair_threshold": 0.65,
		"clear_stale_loaded_consumable": true,
		"allow_forced_zero_energy_primary": false,
		"preferred_consumable_groups": ["shield_repair", "repair", "explosive", "drone", "signal", "pulse", "recharge"]
	}
	if flavor == "balanced_slow":
		values["decision_cooldown"] = 2.50
	elif flavor == "survivor":
		values["repair_hull_threshold"] = 0.70
		values["recharge_energy_threshold"] = 0.45
		values["evade_health_threshold"] = 0.35
		values["preferred_consumable_groups"] = ["shield_repair", "repair", "recharge", "drone", "signal", "pulse", "explosive"]
	elif flavor == "bomber":
		values["repair_hull_threshold"] = 0.35
		values["recharge_energy_threshold"] = 0.25
		values["evade_health_threshold"] = 0.12
		values["preferred_consumable_groups"] = ["explosive", "pulse", "signal", "drone", "repair", "recharge"]
	elif flavor == "tactician":
		values["repair_hull_threshold"] = 0.55
		values["recharge_energy_threshold"] = 0.40
		values["evade_health_threshold"] = 0.25
		values["preferred_consumable_groups"] = ["shield_repair", "repair", "drone", "signal", "pulse", "explosive", "recharge"]
	elif flavor == "pressure":
		values["repair_hull_threshold"] = 0.40
		values["recharge_energy_threshold"] = 0.30
		values["evade_health_threshold"] = 0.18
		values["preferred_consumable_groups"] = ["drone", "signal", "pulse", "explosive", "repair", "recharge"]
	return values


func get_decision_cooldown_seconds(enemy, fallback: float = 1.25) -> float:
	# Summary: Resolve optional behavior-profile response pacing for battle-loop cooldowns.
	var profile_id := str(_unit_value(enemy, "behavior_profile", "")).strip_edges().to_lower()
	if profile_id != "smart_guy_balanced_slow":
		return max(float(fallback), 0.0)

	var values := _smart_guy_profile_values(enemy, "balanced_slow")
	return max(float(values.get("decision_cooldown", fallback)), 0.0)


func _smart_guy_desired_consumable_groups(values: Dictionary, awareness: Dictionary, repair_threshold: float, recharge_threshold: float) -> Array:
	# Summary: Filter profile group preferences through the current battle rules.
	var raw_groups: Array = _safe_array(values.get("preferred_consumable_groups", []))
	if raw_groups.is_empty():
		raw_groups = ["shield_repair", "repair", "explosive", "drone", "signal", "pulse", "recharge"]

	var desired_groups: Array = []
	for raw_group in raw_groups:
		var group := str(raw_group).strip_edges().to_lower()
		if group == "":
			continue
		if group == "shield_repair" and not bool(awareness.get("shield_repair_needed", false)):
			continue
		if group == "repair" and float(awareness.get("enemy_health_ratio", 1.0)) >= repair_threshold:
			continue
		if group == "recharge" and float(awareness.get("enemy_energy_ratio", 1.0)) > recharge_threshold:
			continue
		if group == "drone" and bool(awareness.get("enemy_has_active_drone", false)) and not bool(values.get("allow_multiple_enemy_drones", false)):
			continue
		if (group == "explosive" or group == "signal") and bool(awareness.get("enemy_lock_disabled", false)):
			continue
		if not desired_groups.has(group):
			desired_groups.append(group)

	if bool(awareness.get("shield_repair_needed", false)) and not desired_groups.has("shield_repair"):
		desired_groups.push_front("shield_repair")
	return desired_groups


func _smart_guy_execute_loaded_consumable_intent(
	awareness: Dictionary,
	enemy,
	player_state,
	profile_label: String,
	values: Dictionary,
	loaded_group: String,
	repair_threshold: float,
	recharge_threshold: float
) -> Dictionary:
	# Summary: Build the execute intent for a loaded consumable only when the loaded group is useful now.
	var group := loaded_group.strip_edges().to_lower()
	if group == "":
		return {}
	if not _smart_guy_can_execute_loaded_consumable_group(awareness, values, group, repair_threshold, recharge_threshold):
		return {}

	var target = _smart_guy_loaded_consumable_target(group, enemy, player_state)
	var labels := [
		"enemy_intent_selected",
		"enemy_consumable_intent",
		"enemy_execute_consumable_intent",
		"enemy_" + group + "_intent",
		"enemy_behavior_profile_" + profile_label,
		"enemy_awareness_smart_guy_v1",
		"smart_guy_3_priority_test"
	]
	var priority := 104
	if group == "shield_repair":
		priority = 107
	elif group == "repair" or group == "recharge":
		priority = 105
	elif group == "drone" or group == "signal" or group == "pulse":
		priority = 104

	return _intent_execute_loaded_consumable_from_awareness(
		awareness,
		enemy,
		target,
		profile_label + " executes loaded " + group,
		priority,
		labels,
		{
			"behavior_profile": profile_label,
			"rule": "execute_loaded_" + group + "_when_useful",
			"loaded_consumable_item_id": str(awareness.get("loaded_consumable_item_id", "")),
			"loaded_consumable_group": group,
			"enemy_health_ratio": float(awareness.get("enemy_health_ratio", 1.0)),
			"enemy_energy_ratio": float(awareness.get("enemy_energy_ratio", 1.0)),
			"repair_threshold": repair_threshold,
			"recharge_threshold": recharge_threshold
		}
	)


func _smart_guy_can_execute_loaded_consumable_group(
	awareness: Dictionary,
	values: Dictionary,
	group: String,
	repair_threshold: float,
	recharge_threshold: float
) -> bool:
	# Summary: Decide whether a ready loaded consumable is useful under current game rules.
	if not _can_execute_consumable(awareness):
		return false
	var clean_group := group.strip_edges().to_lower()
	if clean_group == "shield_repair":
		return _can_execute_shield_repair_consumable(awareness)
	if clean_group == "repair":
		if float(awareness.get("enemy_health_ratio", 1.0)) >= repair_threshold:
			return false
		return float(awareness.get("loaded_consumable_repair_amount", 0.0)) > 0.0
	if clean_group == "recharge":
		if float(awareness.get("enemy_energy_ratio", 1.0)) > recharge_threshold:
			return false
		var recharge_data: Dictionary = _safe_dictionary(awareness.get("loaded_consumable_item_data", {}))
		var restore_amount := _dict_float(recharge_data, "energy_restore_amount", _dict_float(recharge_data, "recharge_amount", 0.0))
		return restore_amount > 0.0 or bool(recharge_data.get("recharge_to_full", false))
	if clean_group == "drone":
		if bool(awareness.get("enemy_has_active_drone", false)) and not bool(values.get("allow_multiple_enemy_drones", false)):
			return false
		return str(awareness.get("loaded_consumable_item_id", "")).strip_edges() != ""
	if clean_group == "explosive":
		if bool(awareness.get("enemy_lock_disabled", false)) or not bool(awareness.get("enemy_has_good_lock", false)):
			return false
		return float(awareness.get("loaded_consumable_explosive_damage", 0.0)) > 0.0
	if clean_group == "signal":
		return not bool(awareness.get("enemy_lock_disabled", false)) and bool(awareness.get("enemy_has_good_lock", false))
	if clean_group == "pulse":
		return not _safe_dictionary(awareness.get("loaded_consumable_item_data", {})).is_empty()
	return false


func _smart_guy_loaded_group_needs_lock(group: String) -> bool:
	# Summary: Offensive loaded groups wait for/reacquire lock instead of firing blind.
	var clean_group := group.strip_edges().to_lower()
	return clean_group == "explosive" or clean_group == "signal"


func _smart_guy_loaded_consumable_target(group: String, enemy, player_state):
	# Summary: Self-target defensive/support groups; offensive groups target the player.
	var clean_group := group.strip_edges().to_lower()
	if clean_group == "repair" or clean_group == "shield_repair" or clean_group == "recharge" or clean_group == "drone":
		return enemy
	return player_state


func _smart_guy_should_clear_loaded_consumable(
	awareness: Dictionary,
	desired_consumable: Dictionary,
	values: Dictionary,
	repair_threshold: float,
	recharge_threshold: float
) -> bool:
	# Summary: Clear ready loaded items only when they are stale and block a better valid load choice.
	if not bool(values.get("clear_stale_loaded_consumable", true)):
		return false
	if not bool(awareness.get("consumable_loaded", false)):
		return false
	if not bool(awareness.get("consumable_ready", false)):
		return false
	if desired_consumable.is_empty():
		return false

	var loaded_group := str(awareness.get("loaded_consumable_group", "")).strip_edges().to_lower()
	if loaded_group == "":
		loaded_group = str(awareness.get("consumable_group", "")).strip_edges().to_lower()
	if _smart_guy_can_execute_loaded_consumable_group(awareness, values, loaded_group, repair_threshold, recharge_threshold):
		return false

	var desired_id := str(desired_consumable.get("item_id", "")).strip_edges()
	var loaded_id := str(awareness.get("loaded_consumable_item_id", "")).strip_edges()
	if desired_id == "" or desired_id == loaded_id:
		return false
	return true


func _smart_guy_3_should_remove_shield_for_empty_energy(awareness: Dictionary) -> bool:
	# Summary: When shield drain empties enemy energy, queue a shield-power-down state change.
	if float(awareness.get("enemy_energy_available", 0.0)) > 0.01:
		return false
	if int(awareness.get("shield_power_level", 0)) <= 0:
		return false
	return bool(awareness.get("has_shield_option", false))


func _smart_guy_3_secondary_ammo_empty(awareness: Dictionary) -> bool:
	# Summary: True when the ammo route exists but the enemy cannot pay the ammo cost.
	var ammo_cost := int(awareness.get("secondary_ammo_cost", 0))
	if ammo_cost <= 0:
		return false
	return int(awareness.get("secondary_ammo_count", 0)) < ammo_cost


func _intent_reacquire_lock(enemy, target, reason: String, profile_label: String = "") -> Dictionary:
	# Summary: Build a standardized lock reacquire intent for profiles that need lock before damage.
	var labels := [
		"enemy_intent_selected",
		"enemy_reacquire_lock_intent"
	]
	if profile_label.strip_edges() != "":
		labels.append("enemy_behavior_profile_" + profile_label.strip_edges())
	return _intent_selected(
		"enemy_reacquire_lock",
		enemy,
		target,
		reason,
		100,
		labels,
		{
			"behavior_profile": profile_label,
			"rule": "reacquire_lock_before_damage",
			"awareness_driven": true
		}
	)


func _intent_force_primary_smart_guy_3(enemy, player_state, awareness: Dictionary, reason: String, priority: int, rule: String, profile_label: String = "smart_guy_3") -> Dictionary:
	# Summary: Force a primary attack for Smart Guy 3's ammo-empty fallback by overriding the event energy cost to zero.
	return _intent_selected(
		"enemy_attack_primary",
		enemy,
		player_state,
		reason,
		priority,
		[
			"enemy_intent_selected",
			"enemy_attack_intent",
			"enemy_primary_forced_intent",
			"enemy_behavior_profile_" + profile_label,
			"enemy_awareness_smart_guy_v1",
			"smart_guy_3_priority_test"
		],
		{
			"behavior_profile": profile_label,
			"rule": rule,
			"item_id": str(awareness.get("primary_item_id", "")),
			"primary_item_id": str(awareness.get("primary_item_id", "")),
			"force_primary": true,
			"energy_cost": 0.0,
			"enemy_energy_ratio": float(awareness.get("enemy_energy_ratio", 1.0)),
			"secondary_ammo_count": int(awareness.get("secondary_ammo_count", 0)),
			"secondary_ammo_cost": int(awareness.get("secondary_ammo_cost", 0)),
			"awareness_driven": true
		}
	)


func _intent_load_consumable_from_candidate(
	candidate: Dictionary,
	enemy,
	reason: String,
	priority: int,
	labels: Array,
	data: Dictionary = {}
) -> Dictionary:
	# Summary: Build a load-consumable intent from a direct usable stack candidate.
	var item_id := str(candidate.get("item_id", "")).strip_edges()
	var payload := data.duplicate(true)
	payload["item_id"] = item_id
	payload["consumable_item_id"] = item_id
	payload["consumable_id"] = item_id
	payload["consumable_group"] = str(candidate.get("consumable_group", "")).strip_edges().to_lower()
	payload["item_data"] = _safe_dictionary(candidate.get("item_data", {}))
	payload["loadable_consumable"] = candidate.duplicate(true)
	payload["awareness_driven"] = true
	payload["two_step_consumable_plan"] = "load_then_execute"
	return _intent_selected(
		"enemy_load_consumable",
		enemy,
		enemy,
		reason,
		priority,
		labels,
		payload
	)


func _intent_clear_loaded_consumable(
	enemy,
	target,
	reason: String,
	priority: int,
	labels: Array,
	data: Dictionary = {}
) -> Dictionary:
	# Summary: Build a safe state-change intent that clears a loaded consumable without spending a stack.
	var payload := data.duplicate(true)
	payload["awareness_driven"] = true
	payload["clear_loaded_consumable"] = true
	payload["no_item_spend"] = true
	return _intent_selected(
		"enemy_clear_loaded_consumable",
		enemy,
		target,
		reason,
		priority,
		labels,
		payload
	)


func _smart_guy_should_switch_shield(enemy, awareness: Dictionary, hull_threshold: float, cooldown_seconds: float) -> bool:
	# Summary: Let Smart Guy switch shields only when the player has lock, hull is inside the shield window, and cooldown allows it.
	if not _can_switch_shield(awareness):
		return false
	if not bool(awareness.get("player_has_good_lock", false)):
		return false
	if str(awareness.get("shield_item_id", "")).strip_edges() == "":
		return false
	if float(awareness.get("enemy_health_ratio", 1.0)) > hull_threshold:
		return false

	var enemy_key := _get_enemy_logic_key(enemy)
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(last_shield_switch_msec_by_enemy_key.get(enemy_key, -1))
	if last_msec < 0:
		return true

	var elapsed_seconds: float = float(now_msec - last_msec) / 1000.0
	if elapsed_seconds < cooldown_seconds:
		if Globals.print_priority_5:
			print("EnemyLogic._smart_guy_should_switch_shield | Cooldown active. remaining=", cooldown_seconds - elapsed_seconds)
		return false

	return true


func _mark_smart_guy_shield_switch(enemy) -> void:
	# Summary: Mark Smart Guy's shield-switch choice to prevent repeated shield spam during tests.
	var enemy_key := _get_enemy_logic_key(enemy)
	last_shield_switch_msec_by_enemy_key[enemy_key] = Time.get_ticks_msec()


func _behavior_raider_basic(update_package: Dictionary) -> Dictionary:
	# Summary: Choose a balanced raider intent with lock, low-hull evade, then attack priority.
	return _behavior_test_basic_raider(update_package, "raider_basic")


func _behavior_raider_aggressive(update_package: Dictionary) -> Dictionary:
	# Summary: Choose an aggressive raider intent that attacks before evading unless hull is critical.
	return _behavior_test_aggressive_raider(update_package, "raider_aggressive")


func _behavior_test_basic_raider(update_package: Dictionary, profile_label: String = "test_basic_raider") -> Dictionary:
	# Summary: Choose the basic raider intent from the awareness/capability snapshot.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)
	var awareness: Dictionary = _build_awareness(update_package)

	# Dead, inactive, queued, or missing enemies produce no queued combat intent.
	if not _awareness_can_act(awareness):
		return _intent_none(
			"basic raider cannot act: " + _awareness_wait_reason(awareness),
			[
				"enemy_intent_none",
				"enemy_behavior_profile_" + profile_label,
				"enemy_awareness_basic_raider_v1"
			]
		)

	# Profile values let test packets tune thresholds without changing the function.
	var values := _get_behavior_values(enemy)
	var low_hull_threshold := float(values.get("low_hull_evade_threshold", 0.35))
	var repair_hull_threshold := float(values.get("repair_hull_threshold", low_hull_threshold))

	# Lock-disabled enemies wait rather than inventing an action.
	if bool(awareness.get("enemy_lock_disabled", false)):
		return _intent_wait(enemy, player_state, "basic raider lock disabled", profile_label)

	# Reacquire comes before attacking because this profile wants stable lock behavior.
	if _awareness_needs_reacquire(awareness):
		return _intent_selected(
			"enemy_reacquire_lock",
			enemy,
			player_state,
			"basic raider awareness needs good lock",
			70,
			[
				"enemy_intent_selected",
				"enemy_reacquire_lock_intent",
				"enemy_behavior_profile_" + profile_label,
				"enemy_awareness_basic_raider_v1"
			],
			{
				"behavior_profile": profile_label,
				"awareness_driven": true
			}
		)

	# Basic raiders spend a ready recovery kit before evading if one is available.
	if _can_execute_repair_consumable(awareness, repair_hull_threshold):
		return _intent_execute_consumable_from_awareness(
			awareness,
			enemy,
			enemy,
			"basic raider recovery kit",
			82,
			[
				"enemy_intent_selected",
				"enemy_consumable_intent",
				"enemy_repair_intent",
				"enemy_behavior_profile_" + profile_label,
				"enemy_awareness_basic_raider_v1"
			],
			{
				"behavior_profile": profile_label,
				"threshold": repair_hull_threshold
			}
		)

	# Basic raiders evade before attacking once their hull is meaningfully low.
	if float(awareness.get("enemy_health_ratio", 1.0)) <= low_hull_threshold and _can_evade_now(awareness):
		return _intent_selected(
			"enemy_evade",
			enemy,
			player_state,
			"basic raider awareness low hull evade",
			80,
			[
				"enemy_intent_selected",
				"enemy_evade_intent",
				"enemy_behavior_profile_" + profile_label,
				"enemy_awareness_basic_raider_v1"
			],
			{
				"behavior_profile": profile_label,
				"threshold": low_hull_threshold,
				"awareness_driven": true
			}
		)

	# Primary attack is now gated by lock, weapon availability, and energy readiness.
	if _can_use_primary(awareness):
		return _intent_selected(
			"enemy_attack_primary",
			enemy,
			player_state,
			"basic raider awareness primary ready",
			50,
			[
				"enemy_intent_selected",
				"enemy_attack_intent",
				"enemy_behavior_profile_" + profile_label,
				"enemy_awareness_basic_raider_v1"
			],
			{
				"behavior_profile": profile_label,
				"primary_item_id": str(awareness.get("primary_item_id", "")),
				"primary_energy_cost": float(awareness.get("primary_energy_cost", 0.0)),
				"awareness_driven": true
			}
		)

	# Secondary attack is now gated by lock, weapon availability, energy readiness, and ammo readiness.
	if _can_use_secondary(awareness):
		return _intent_selected(
			"enemy_attack_secondary",
			enemy,
			player_state,
			"basic raider awareness secondary ready",
			45,
			[
				"enemy_intent_selected",
				"enemy_attack_intent",
				"enemy_behavior_profile_" + profile_label,
				"enemy_awareness_basic_raider_v1"
			],
			{
				"behavior_profile": profile_label,
				"secondary_item_id": str(awareness.get("secondary_item_id", "")),
				"secondary_energy_cost": float(awareness.get("secondary_energy_cost", 0.0)),
				"secondary_ammo_group": str(awareness.get("secondary_ammo_group", "")),
				"secondary_ammo_cost": int(awareness.get("secondary_ammo_cost", 0)),
				"secondary_ammo_count": int(awareness.get("secondary_ammo_count", 0)),
				"awareness_driven": true
			}
		)

	# Wait is the safe fallback when no tactical branch applies.
	return _intent_wait(enemy, player_state, "basic raider awareness wait: " + _awareness_wait_reason(awareness), profile_label)


func _behavior_test_aggressive_raider(update_package: Dictionary, profile_label: String = "test_aggressive_raider") -> Dictionary:
	# Summary: Choose the aggressive raider test intent using attack-first priority and late evade behavior.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)

	# Dead, inactive, or missing enemies produce no intent.
	if not _enemy_can_act(enemy):
		return _intent_none(
			"aggressive raider cannot act",
			[
				"enemy_intent_none",
				"enemy_behavior_profile_" + profile_label
			]
		)

	# Aggressive raiders only evade at critical hull unless values override that threshold.
	var values := _get_behavior_values(enemy)
	var awareness: Dictionary = _build_awareness(update_package)
	var critical_hull_threshold := float(values.get("critical_hull_evade_threshold", 0.15))
	var explosive_player_threshold := float(values.get("explosive_player_threshold", 0.65))
	var repair_hull_threshold := float(values.get("repair_hull_threshold", critical_hull_threshold))

	# Disabled locks make the enemy wait because there is no useful lock action to choose.
	if _enemy_lock_disabled(enemy):
		return _intent_wait(enemy, player_state, "aggressive raider lock disabled", profile_label)

	# Even aggressive raiders need a lock before lock-required attacks.
	if _enemy_needs_reacquire(enemy):
		return _intent_selected(
			"enemy_reacquire_lock",
			enemy,
			player_state,
			"aggressive raider needs lock",
			70,
			[
				"enemy_intent_selected",
				"enemy_reacquire_lock_intent",
				"enemy_behavior_profile_" + profile_label
			],
			{
				"behavior_profile": profile_label
			}
		)

	if _can_execute_repair_consumable(awareness, repair_hull_threshold):
		return _intent_execute_consumable_from_awareness(
			awareness,
			enemy,
			enemy,
			"aggressive raider emergency repair",
			95,
			[
				"enemy_intent_selected",
				"enemy_consumable_intent",
				"enemy_repair_intent",
				"enemy_behavior_profile_" + profile_label
			],
			{
				"behavior_profile": profile_label,
				"threshold": repair_hull_threshold
			}
		)

	if _can_execute_explosive_consumable(awareness, explosive_player_threshold):
		return _intent_execute_consumable_from_awareness(
			awareness,
			enemy,
			player_state,
			"aggressive raider explosive pressure",
			92,
			[
				"enemy_intent_selected",
				"enemy_consumable_intent",
				"enemy_explosive_intent",
				"enemy_behavior_profile_" + profile_label
			],
			{
				"behavior_profile": profile_label,
				"player_health_ratio": float(awareness.get("player_health_ratio", 1.0)),
				"threshold": explosive_player_threshold
			}
		)

	# Aggressive raiders attack with primary before checking non-critical evasion.
	if _can_use_primary(awareness):
		return _intent_selected(
			"enemy_attack_primary",
			enemy,
			player_state,
			"aggressive raider attacks primary",
			90,
			[
				"enemy_intent_selected",
				"enemy_attack_intent",
				"enemy_behavior_profile_" + profile_label
			],
			{
				"behavior_profile": profile_label
			}
		)

	# Secondary attack is the next attack lane for aggressive raiders.
	if _can_use_secondary(awareness):
		return _intent_selected(
			"enemy_attack_secondary",
			enemy,
			player_state,
			"aggressive raider attacks secondary",
			80,
			[
				"enemy_intent_selected",
				"enemy_attack_intent",
				"enemy_behavior_profile_" + profile_label
			],
			{
				"behavior_profile": profile_label
			}
		)

	# Critical hull can still override aggression if evasion is available.
	if _enemy_hull_below(enemy, critical_hull_threshold) and _enemy_can_evade(enemy):
		return _intent_selected(
			"enemy_evade",
			enemy,
			player_state,
			"aggressive raider critical hull evade",
			60,
			[
				"enemy_intent_selected",
				"enemy_evade_intent",
				"enemy_behavior_profile_" + profile_label
			],
			{
				"behavior_profile": profile_label,
				"threshold": critical_hull_threshold
			}
		)

	# Wait is the safe fallback when no tactical branch applies.
	return _intent_wait(enemy, player_state, "aggressive raider fallback wait", profile_label)


func _behavior_test_coward_raider(update_package: Dictionary) -> Dictionary:
	# Summary: Choose the coward raider test intent with early evade and cautious attack priority.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)
	var awareness: Dictionary = _build_awareness(update_package)

	# Dead, inactive, or missing enemies produce no intent.
	if not _enemy_can_act(enemy):
		return _intent_none(
			"coward raider cannot act",
			[
				"enemy_intent_none",
				"enemy_behavior_profile_test_coward_raider"
			]
		)

	# Coward behavior values make this profile easy to tune during tests.
	var values := _get_behavior_values(enemy)
	var low_hull_threshold := float(values.get("low_hull_evade_threshold", 0.60))
	var evade_if_player_has_lock := bool(values.get("player_lock_evade", true))

	# Lock-disabled enemies wait rather than spending effort on attack decisions.
	if _enemy_lock_disabled(enemy):
		return _intent_wait(enemy, player_state, "coward raider lock disabled", "test_coward_raider")

	# This profile may evade simply because the player has a strong lock.
	if evade_if_player_has_lock and _player_has_good_lock(player_state) and _enemy_can_evade(enemy):
		return _intent_selected(
			"enemy_evade",
			enemy,
			player_state,
			"coward raider evades because player has good lock",
			90,
			[
				"enemy_intent_selected",
				"enemy_evade_intent",
				"enemy_behavior_profile_test_coward_raider"
			],
			{
				"behavior_profile": "test_coward_raider",
				"trigger": "player_good_lock"
			}
		)

	# Coward raiders evade earlier than basic or aggressive raiders.
	if _enemy_hull_below(enemy, low_hull_threshold) and _enemy_can_evade(enemy):
		return _intent_selected(
			"enemy_evade",
			enemy,
			player_state,
			"coward raider low hull evade",
			85,
			[
				"enemy_intent_selected",
				"enemy_evade_intent",
				"enemy_behavior_profile_test_coward_raider"
			],
			{
				"behavior_profile": "test_coward_raider",
				"threshold": low_hull_threshold
			}
		)

	# Coward raiders reacquire if they are not already protected by an evade choice.
	if _enemy_needs_reacquire(enemy):
		return _intent_selected(
			"enemy_reacquire_lock",
			enemy,
			player_state,
			"coward raider lacks good lock",
			50,
			[
				"enemy_intent_selected",
				"enemy_reacquire_lock_intent",
				"enemy_behavior_profile_test_coward_raider"
			],
			{
				"behavior_profile": "test_coward_raider"
			}
		)

	# Coward raiders only attack when the state is stable.
	if _can_use_primary(awareness):
		return _intent_selected(
			"enemy_attack_primary",
			enemy,
			player_state,
			"coward raider attacks only when stable",
			40,
			[
				"enemy_intent_selected",
				"enemy_attack_intent",
				"enemy_behavior_profile_test_coward_raider"
			],
			{
				"behavior_profile": "test_coward_raider"
			}
		)

	# Wait is the safe fallback when no tactical branch applies.
	return _intent_wait(enemy, player_state, "coward raider fallback wait", "test_coward_raider")


func _behavior_test_lock_obsessed(update_package: Dictionary) -> Dictionary:
	# Summary: Choose the lock-obsessed test intent by prioritizing lock reacquire before any other action.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)
	var awareness: Dictionary = _build_awareness(update_package)

	# Dead, inactive, or missing enemies produce no intent.
	if not _enemy_can_act(enemy):
		return _intent_none(
			"lock obsessed enemy cannot act",
			[
				"enemy_intent_none",
				"enemy_behavior_profile_test_lock_obsessed"
			]
		)

	# Disabled lock still waits because this profile cannot fix disabled lock state yet.
	if _enemy_lock_disabled(enemy):
		return _intent_wait(enemy, player_state, "lock obsessed enemy lock disabled", "test_lock_obsessed")

	# This profile always reacquires before attacks if it lacks a good lock.
	if _enemy_needs_reacquire(enemy):
		return _intent_selected(
			"enemy_reacquire_lock",
			enemy,
			player_state,
			"lock obsessed enemy always reacquires first",
			100,
			[
				"enemy_intent_selected",
				"enemy_reacquire_lock_intent",
				"enemy_behavior_profile_test_lock_obsessed"
			],
			{
				"behavior_profile": "test_lock_obsessed"
			}
		)

	# Once lock is established, this profile can attack normally.
	if _can_use_primary(awareness):
		return _intent_selected(
			"enemy_attack_primary",
			enemy,
			player_state,
			"lock obsessed enemy attacks after lock",
			60,
			[
				"enemy_intent_selected",
				"enemy_attack_intent",
				"enemy_behavior_profile_test_lock_obsessed"
			],
			{
				"behavior_profile": "test_lock_obsessed"
			}
		)

	# Wait is the safe fallback when no tactical branch applies.
	return _intent_wait(enemy, player_state, "lock obsessed fallback wait", "test_lock_obsessed")


func _behavior_test_signal_skirmisher(update_package: Dictionary) -> Dictionary:
	# Summary: Choose the signal skirmisher test intent by preferring signal action before normal attack.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)
	var awareness: Dictionary = _build_awareness(update_package)

	# Dead, inactive, or missing enemies produce no intent.
	if not _enemy_can_act(enemy):
		return _intent_none(
			"signal skirmisher cannot act",
			[
				"enemy_intent_none",
				"enemy_behavior_profile_test_signal_skirmisher"
			]
		)

	# Pull signal and evade tuning from the enemy behavior values packet.
	var values := _get_behavior_values(enemy)
	var low_hull_threshold := float(values.get("low_hull_evade_threshold", 0.40))
	var signal_preference := str(values.get("signal_preference", "disable_lock")).strip_edges()
	if signal_preference == "":
		signal_preference = "disable_lock"

	# Disabled lock makes the skirmisher wait because signal target quality is unknown.
	if _enemy_lock_disabled(enemy):
		return _intent_wait(enemy, player_state, "signal skirmisher lock disabled", "test_signal_skirmisher")

	# This skirmisher evades if pressured before trying signal tricks.
	if _enemy_hull_below(enemy, low_hull_threshold) and _enemy_can_evade(enemy):
		return _intent_selected(
			"enemy_evade",
			enemy,
			player_state,
			"signal skirmisher low hull evade",
			80,
			[
				"enemy_intent_selected",
				"enemy_evade_intent",
				"enemy_behavior_profile_test_signal_skirmisher"
			],
			{
				"behavior_profile": "test_signal_skirmisher",
				"threshold": low_hull_threshold
			}
		)

	# Signal intent is preferred when the enemy has a lock and signal behavior is available.
	if _enemy_has_good_lock(enemy) and _enemy_signal_available(enemy):
		return _intent_selected(
			"enemy_signal_" + signal_preference,
			enemy,
			player_state,
			"signal skirmisher uses preferred signal",
			75,
			[
				"enemy_intent_selected",
				"enemy_signal_intent",
				"enemy_behavior_profile_test_signal_skirmisher"
			],
			{
				"behavior_profile": "test_signal_skirmisher",
				"signal_preference": signal_preference
			}
		)

	# Reacquire lock if signal and attack choices are blocked by missing lock.
	if _enemy_needs_reacquire(enemy):
		return _intent_selected(
			"enemy_reacquire_lock",
			enemy,
			player_state,
			"signal skirmisher needs lock",
			50,
			[
				"enemy_intent_selected",
				"enemy_reacquire_lock_intent",
				"enemy_behavior_profile_test_signal_skirmisher"
			],
			{
				"behavior_profile": "test_signal_skirmisher"
			}
		)

	# Primary attack is the plain fallback if the signal path is not available.
	if _can_use_primary(awareness):
		return _intent_selected(
			"enemy_attack_primary",
			enemy,
			player_state,
			"signal skirmisher fallback attack",
			40,
			[
				"enemy_intent_selected",
				"enemy_attack_intent",
				"enemy_behavior_profile_test_signal_skirmisher"
			],
			{
				"behavior_profile": "test_signal_skirmisher"
			}
		)

	# Wait is the safe fallback when no tactical branch applies.
	return _intent_wait(enemy, player_state, "signal skirmisher fallback wait", "test_signal_skirmisher")


func _behavior_raider_survivor(update_package: Dictionary) -> Dictionary:
	# Summary: Defensive raider profile: repair first, evade second, then take safe shots.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)
	var awareness: Dictionary = _build_awareness(update_package)
	if not _awareness_can_act(awareness):
		return _intent_none("survivor cannot act: " + _awareness_wait_reason(awareness), ["enemy_intent_none", "enemy_behavior_profile_raider_survivor"])

	var values := _get_behavior_values(enemy)
	var repair_threshold := float(values.get("repair_hull_threshold", 0.55))
	var evade_threshold := float(values.get("low_hull_evade_threshold", 0.35))

	if _awareness_needs_reacquire(awareness):
		return _intent_selected("enemy_reacquire_lock", enemy, player_state, "survivor needs lock", 70, ["enemy_intent_selected", "enemy_reacquire_lock_intent", "enemy_behavior_profile_raider_survivor"], {"behavior_profile": "raider_survivor"})
	if _can_load_or_execute_repair_consumable(awareness, repair_threshold):
		return _intent_load_or_execute_consumable_from_awareness(awareness, enemy, enemy, "survivor recovery kit", 90, ["enemy_intent_selected", "enemy_consumable_intent", "enemy_repair_intent", "enemy_two_step_consumable_intent", "enemy_behavior_profile_raider_survivor"], {"behavior_profile": "raider_survivor", "threshold": repair_threshold})
	if float(awareness.get("enemy_health_ratio", 1.0)) <= evade_threshold and _can_evade_now(awareness):
		return _intent_selected("enemy_evade", enemy, player_state, "survivor evade", 80, ["enemy_intent_selected", "enemy_evade_intent", "enemy_behavior_profile_raider_survivor"], {"behavior_profile": "raider_survivor", "threshold": evade_threshold})
	if _can_use_primary(awareness):
		return _intent_selected("enemy_attack_primary", enemy, player_state, "survivor primary", 45, ["enemy_intent_selected", "enemy_attack_intent", "enemy_behavior_profile_raider_survivor"], {"behavior_profile": "raider_survivor"})
	if _can_use_secondary(awareness):
		return _intent_selected("enemy_attack_secondary", enemy, player_state, "survivor secondary", 40, ["enemy_intent_selected", "enemy_attack_intent", "enemy_behavior_profile_raider_survivor"], {"behavior_profile": "raider_survivor"})
	return _intent_wait(enemy, player_state, "survivor wait: " + _awareness_wait_reason(awareness), "raider_survivor")


func _behavior_raider_bomber(update_package: Dictionary) -> Dictionary:
	# Summary: Burst profile: use explosive consumables when lock is good, then fall back to secondary pressure.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)
	var awareness: Dictionary = _build_awareness(update_package)
	if not _awareness_can_act(awareness):
		return _intent_none("bomber cannot act: " + _awareness_wait_reason(awareness), ["enemy_intent_none", "enemy_behavior_profile_raider_bomber"])

	var values := _get_behavior_values(enemy)
	var explosive_threshold := float(values.get("explosive_player_threshold", 0.85))

	if _awareness_needs_reacquire(awareness):
		return _intent_selected("enemy_reacquire_lock", enemy, player_state, "bomber needs lock", 80, ["enemy_intent_selected", "enemy_reacquire_lock_intent", "enemy_behavior_profile_raider_bomber"], {"behavior_profile": "raider_bomber"})
	if _can_load_or_execute_explosive_consumable(awareness, explosive_threshold):
		return _intent_load_or_execute_consumable_from_awareness(awareness, enemy, player_state, "bomber explosive charge", 95, ["enemy_intent_selected", "enemy_consumable_intent", "enemy_explosive_intent", "enemy_two_step_consumable_intent", "enemy_behavior_profile_raider_bomber"], {"behavior_profile": "raider_bomber", "threshold": explosive_threshold})
	if _can_use_secondary(awareness):
		return _intent_selected("enemy_attack_secondary", enemy, player_state, "bomber secondary pressure", 65, ["enemy_intent_selected", "enemy_attack_intent", "enemy_behavior_profile_raider_bomber"], {"behavior_profile": "raider_bomber"})
	if _can_use_primary(awareness):
		return _intent_selected("enemy_attack_primary", enemy, player_state, "bomber fallback primary", 50, ["enemy_intent_selected", "enemy_attack_intent", "enemy_behavior_profile_raider_bomber"], {"behavior_profile": "raider_bomber"})
	return _intent_wait(enemy, player_state, "bomber wait: " + _awareness_wait_reason(awareness), "raider_bomber")


func _behavior_raider_tactician(update_package: Dictionary) -> Dictionary:
	# Summary: Mixed profile: maintain lock, repair under pressure, exploit explosives, then alternate weapon lanes by readiness.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)
	var awareness: Dictionary = _build_awareness(update_package)
	if not _awareness_can_act(awareness):
		return _intent_none("tactician cannot act: " + _awareness_wait_reason(awareness), ["enemy_intent_none", "enemy_behavior_profile_raider_tactician"])

	var values := _get_behavior_values(enemy)
	var repair_threshold := float(values.get("repair_hull_threshold", 0.32))
	var explosive_threshold := float(values.get("explosive_player_threshold", 0.45))

	if _awareness_needs_reacquire(awareness):
		return _intent_selected("enemy_reacquire_lock", enemy, player_state, "tactician needs lock", 85, ["enemy_intent_selected", "enemy_reacquire_lock_intent", "enemy_behavior_profile_raider_tactician"], {"behavior_profile": "raider_tactician"})
	if _can_load_or_execute_repair_consumable(awareness, repair_threshold):
		return _intent_load_or_execute_consumable_from_awareness(awareness, enemy, enemy, "tactician repair", 90, ["enemy_intent_selected", "enemy_consumable_intent", "enemy_repair_intent", "enemy_two_step_consumable_intent", "enemy_behavior_profile_raider_tactician"], {"behavior_profile": "raider_tactician", "threshold": repair_threshold})
	if _should_use_drone_consumable(awareness, "pressure"):
		return _intent_load_or_execute_consumable_from_awareness(awareness, enemy, enemy, "tactician deploys drone", 82, ["enemy_intent_selected", "enemy_consumable_intent", "enemy_drone_intent", "enemy_two_step_consumable_intent", "enemy_behavior_profile_raider_tactician"], {"behavior_profile": "raider_tactician", "rule": "tactical_drone"})
	if _can_load_or_execute_explosive_consumable(awareness, explosive_threshold):
		return _intent_load_or_execute_consumable_from_awareness(awareness, enemy, player_state, "tactician explosive punish", 78, ["enemy_intent_selected", "enemy_consumable_intent", "enemy_explosive_intent", "enemy_two_step_consumable_intent", "enemy_behavior_profile_raider_tactician"], {"behavior_profile": "raider_tactician", "threshold": explosive_threshold})
	if _can_use_primary(awareness):
		return _intent_selected("enemy_attack_primary", enemy, player_state, "tactician primary", 60, ["enemy_intent_selected", "enemy_attack_intent", "enemy_behavior_profile_raider_tactician"], {"behavior_profile": "raider_tactician"})
	if _can_use_secondary(awareness):
		return _intent_selected("enemy_attack_secondary", enemy, player_state, "tactician secondary fallback", 55, ["enemy_intent_selected", "enemy_attack_intent", "enemy_behavior_profile_raider_tactician"], {"behavior_profile": "raider_tactician"})
	return _intent_wait(enemy, player_state, "tactician wait: " + _awareness_wait_reason(awareness), "raider_tactician")



func _behavior_raider_drone_opener(update_package: Dictionary) -> Dictionary:
	# Summary: Primitive opener: prepare/deploy a drone first, then fight like a basic raider.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)
	var awareness: Dictionary = _build_awareness(update_package)
	if not _awareness_can_act(awareness):
		return _intent_none("drone opener cannot act: " + _awareness_wait_reason(awareness), ["enemy_intent_none", "enemy_behavior_profile_raider_drone_opener"])

	if _should_use_drone_consumable(awareness, "pressure"):
		return _intent_load_or_execute_consumable_from_awareness(
			awareness,
			enemy,
			enemy,
			"drone opener wants drone online",
			95,
			["enemy_intent_selected", "enemy_consumable_intent", "enemy_drone_intent", "enemy_two_step_consumable_intent", "enemy_behavior_profile_raider_drone_opener"],
			{"behavior_profile": "raider_drone_opener", "rule": "open_with_drone"}
		)
	if _awareness_needs_reacquire(awareness):
		return _intent_selected("enemy_reacquire_lock", enemy, player_state, "drone opener needs lock", 75, ["enemy_intent_selected", "enemy_reacquire_lock_intent", "enemy_behavior_profile_raider_drone_opener"], {"behavior_profile": "raider_drone_opener"})
	if _can_use_primary(awareness):
		return _intent_selected("enemy_attack_primary", enemy, player_state, "drone opener primary", 50, ["enemy_intent_selected", "enemy_attack_intent", "enemy_behavior_profile_raider_drone_opener"], {"behavior_profile": "raider_drone_opener"})
	if _can_use_secondary(awareness):
		return _intent_selected("enemy_attack_secondary", enemy, player_state, "drone opener secondary", 45, ["enemy_intent_selected", "enemy_attack_intent", "enemy_behavior_profile_raider_drone_opener"], {"behavior_profile": "raider_drone_opener"})
	return _intent_wait(enemy, player_state, "drone opener wait: " + _awareness_wait_reason(awareness), "raider_drone_opener")


func _behavior_raider_drone_survivor(update_package: Dictionary) -> Dictionary:
	# Summary: Primitive defender: repair/evade if needed, then load/deploy defensive drone under pressure.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)
	var awareness: Dictionary = _build_awareness(update_package)
	if not _awareness_can_act(awareness):
		return _intent_none("drone survivor cannot act: " + _awareness_wait_reason(awareness), ["enemy_intent_none", "enemy_behavior_profile_raider_drone_survivor"])

	var values := _get_behavior_values(enemy)
	var repair_threshold := float(values.get("repair_hull_threshold", 0.50))
	var evade_threshold := float(values.get("low_hull_evade_threshold", 0.30))

	if _awareness_needs_reacquire(awareness):
		return _intent_selected("enemy_reacquire_lock", enemy, player_state, "drone survivor needs lock", 70, ["enemy_intent_selected", "enemy_reacquire_lock_intent", "enemy_behavior_profile_raider_drone_survivor"], {"behavior_profile": "raider_drone_survivor"})
	if _can_load_or_execute_repair_consumable(awareness, repair_threshold):
		return _intent_load_or_execute_consumable_from_awareness(awareness, enemy, enemy, "drone survivor repair", 92, ["enemy_intent_selected", "enemy_consumable_intent", "enemy_repair_intent", "enemy_two_step_consumable_intent", "enemy_behavior_profile_raider_drone_survivor"], {"behavior_profile": "raider_drone_survivor", "threshold": repair_threshold})
	if _should_use_drone_consumable(awareness, "survival"):
		return _intent_load_or_execute_consumable_from_awareness(
			awareness,
			enemy,
			enemy,
			"drone survivor deploys cover drone",
			85,
			["enemy_intent_selected", "enemy_consumable_intent", "enemy_drone_intent", "enemy_two_step_consumable_intent", "enemy_behavior_profile_raider_drone_survivor"],
			{"behavior_profile": "raider_drone_survivor", "rule": "survival_drone"}
		)
	if float(awareness.get("enemy_health_ratio", 1.0)) <= evade_threshold and _can_evade_now(awareness):
		return _intent_selected("enemy_evade", enemy, player_state, "drone survivor evade", 80, ["enemy_intent_selected", "enemy_evade_intent", "enemy_behavior_profile_raider_drone_survivor"], {"behavior_profile": "raider_drone_survivor", "threshold": evade_threshold})
	if _can_use_primary(awareness):
		return _intent_selected("enemy_attack_primary", enemy, player_state, "drone survivor primary", 45, ["enemy_intent_selected", "enemy_attack_intent", "enemy_behavior_profile_raider_drone_survivor"], {"behavior_profile": "raider_drone_survivor"})
	if _can_use_secondary(awareness):
		return _intent_selected("enemy_attack_secondary", enemy, player_state, "drone survivor secondary", 40, ["enemy_intent_selected", "enemy_attack_intent", "enemy_behavior_profile_raider_drone_survivor"], {"behavior_profile": "raider_drone_survivor"})
	return _intent_wait(enemy, player_state, "drone survivor wait: " + _awareness_wait_reason(awareness), "raider_drone_survivor")


func _behavior_raider_scripted_order(update_package: Dictionary) -> Dictionary:
	# Summary: Primitive hardcoded personality: try a configured action list in order, advancing after each selected intent.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)
	var awareness: Dictionary = _build_awareness(update_package)
	if not _awareness_can_act(awareness):
		return _intent_none("scripted order cannot act: " + _awareness_wait_reason(awareness), ["enemy_intent_none", "enemy_behavior_profile_raider_scripted_order"])

	var values := _get_behavior_values(enemy)
	var order = values.get("scripted_order", _unit_value(enemy, "scripted_order", []))
	if typeof(order) != TYPE_ARRAY or order.is_empty():
		order = ["drone", "reacquire", "primary", "secondary", "wait"]
	var index := int(_unit_value(enemy, "scripted_order_index", 0))
	var attempts = min(order.size(), 12)
	for i in range(attempts):
		var local_index = (index + i) % order.size()
		var step := str(order[local_index]).strip_edges().to_lower()
		var intent := _intent_for_scripted_step(step, awareness, enemy, player_state)
		if not intent.is_empty():
			_unit_set_value(enemy, "scripted_order_index", (local_index + 1) % order.size())
			_append_intent_label(intent, "enemy_behavior_profile_raider_scripted_order")
			return intent
	return _intent_wait(enemy, player_state, "scripted order wait: no legal scripted step", "raider_scripted_order")


func _intent_for_scripted_step(step: String, awareness: Dictionary, enemy, player_state) -> Dictionary:
	# Summary: Convert one primitive scripted token into an intent if currently legal.
	if step == "drone" or step == "load_drone" or step == "deploy_drone":
		if _should_use_drone_consumable(awareness, "pressure"):
			return _intent_load_or_execute_consumable_from_awareness(awareness, enemy, enemy, "scripted drone step", 90, ["enemy_intent_selected", "enemy_consumable_intent", "enemy_drone_intent", "enemy_two_step_consumable_intent"], {"behavior_profile": "raider_scripted_order", "scripted_step": step})
	elif step == "reacquire" or step == "lock":
		if _awareness_needs_reacquire(awareness):
			return _intent_selected("enemy_reacquire_lock", enemy, player_state, "scripted reacquire step", 80, ["enemy_intent_selected", "enemy_reacquire_lock_intent"], {"behavior_profile": "raider_scripted_order", "scripted_step": step})
	elif step == "repair":
		if _can_load_or_execute_repair_consumable(awareness, 1.0):
			return _intent_load_or_execute_consumable_from_awareness(awareness, enemy, enemy, "scripted repair step", 85, ["enemy_intent_selected", "enemy_consumable_intent", "enemy_repair_intent", "enemy_two_step_consumable_intent"], {"behavior_profile": "raider_scripted_order", "scripted_step": step})
	elif step == "explosive":
		if _can_load_or_execute_explosive_consumable(awareness, 1.0):
			return _intent_load_or_execute_consumable_from_awareness(awareness, enemy, player_state, "scripted explosive step", 85, ["enemy_intent_selected", "enemy_consumable_intent", "enemy_explosive_intent", "enemy_two_step_consumable_intent"], {"behavior_profile": "raider_scripted_order", "scripted_step": step})
	elif step == "primary":
		if _can_use_primary(awareness):
			return _intent_selected("enemy_attack_primary", enemy, player_state, "scripted primary step", 60, ["enemy_intent_selected", "enemy_attack_intent"], {"behavior_profile": "raider_scripted_order", "scripted_step": step})
	elif step == "secondary":
		if _can_use_secondary(awareness):
			return _intent_selected("enemy_attack_secondary", enemy, player_state, "scripted secondary step", 55, ["enemy_intent_selected", "enemy_attack_intent"], {"behavior_profile": "raider_scripted_order", "scripted_step": step})
	elif step == "evade":
		if _can_evade_now(awareness):
			return _intent_selected("enemy_evade", enemy, player_state, "scripted evade step", 70, ["enemy_intent_selected", "enemy_evade_intent"], {"behavior_profile": "raider_scripted_order", "scripted_step": step})
	elif step == "wait":
		return _intent_wait(enemy, player_state, "scripted wait step", "raider_scripted_order")
	return {}


func _build_awareness(update_package: Dictionary) -> Dictionary:
	# Summary: Build a single tactical readout for enemy behavior decisions without changing behavior yet.
	var enemy = update_package.get("enemy", null)
	var player_state = update_package.get("player_state", null)
	var energy: Dictionary = _safe_dictionary(update_package.get("enemy_energy", {}))
	var ammo: Dictionary = _safe_dictionary(update_package.get("enemy_ammo", {}))
	var loadout: Dictionary = _safe_dictionary(update_package.get("enemy_loadout", {}))
	var shield: Dictionary = _safe_dictionary(update_package.get("enemy_shield", {}))
	var consumable: Dictionary = _safe_dictionary(update_package.get("enemy_consumable", {}))
	var active_drone_snapshot: Dictionary = _safe_dictionary(update_package.get("active_drone_snapshot", {}))
	var weapon_gates: Dictionary = _safe_dictionary(update_package.get("enemy_weapon_spam_gates", {}))
	var item_stacks: Dictionary = _safe_dictionary(loadout.get("item_stacks", {}))
	var usable_consumables: Array = _safe_array(loadout.get("usable_consumables", []))
	var active_enemy_events: Array = _safe_array(update_package.get("active_enemy_events", []))
	var active_player_events: Array = _safe_array(update_package.get("active_player_events", []))

	var enemy_health_ratio := float(update_package.get("enemy_health_ratio", _unit_health_ratio(enemy, "enemy")))
	var player_health_ratio := float(update_package.get("player_health_ratio", _unit_health_ratio(player_state, "player")))

	var energy_current := _dict_float(energy, "current", _unit_float_value(enemy, "enemy_energy_current", 0.0))
	var energy_max := _dict_float(energy, "max", _unit_float_value(enemy, "enemy_energy_max", max(energy_current, 1.0)))
	var energy_reserved := _dict_float(energy, "reserved", _unit_float_value(enemy, "enemy_reserved_energy", 0.0))
	var energy_available := _dict_float(energy, "available", max(energy_current - energy_reserved, 0.0))
	var energy_ratio := 0.0
	if energy_max > 0.0:
		energy_ratio = clamp(energy_current / energy_max, 0.0, 1.0)

	var primary_id := str(loadout.get("primary", _unit_value(enemy, "selected_primary_weapon", ""))).strip_edges()
	var secondary_id := str(loadout.get("secondary", _unit_value(enemy, "selected_secondary_weapon", ""))).strip_edges()
	var shield_id := str(loadout.get("shield", _unit_value(enemy, "selected_enemy_shield", ""))).strip_edges()
	var consumable_id := str(loadout.get("consumable", _unit_value(enemy, "enemy_loaded_consumable", ""))).strip_edges()

	var primary_item_data: Dictionary = _safe_dictionary(loadout.get("primary_item_data", {}))
	var secondary_item_data: Dictionary = _safe_dictionary(loadout.get("secondary_item_data", {}))
	var shield_item_data: Dictionary = _safe_dictionary(loadout.get("shield_item_data", {}))
	var consumable_item_data: Dictionary = _safe_dictionary(loadout.get("consumable_item_data", {}))
	var behavior_values := _get_behavior_values(enemy)
	var equipped_shield_id := str(shield.get("equipped_shield_item_id", loadout.get("equipped_shield", ""))).strip_edges()
	if equipped_shield_id == "":
		equipped_shield_id = _extract_item_id_from_value(shield.get("selected_shield", shield.get("selected_enemy_shield", null)))
	var shield_hp_current := float(shield.get("shield_hp_current", _unit_float_value(enemy, "shield_hp_current", 0.0)))
	var shield_hp_max := float(shield.get("shield_hp_max", _unit_float_value(enemy, "shield_hp_max", 0.0)))
	if shield_hp_max <= 0.0 and equipped_shield_id != "":
		shield_hp_max = _dict_float(shield_item_data, "shield_hp_max", _dict_float(shield_item_data, "hp_max", 0.0))
	var shield_hp_ratio := 0.0
	if shield_hp_max > 0.0:
		shield_hp_ratio = clamp(shield_hp_current / shield_hp_max, 0.0, 1.0)
	var shield_equipped := equipped_shield_id != ""
	var shield_broken := shield_equipped and shield_hp_current <= 0.0
	var shield_damaged := shield_equipped and shield_hp_current > 0.0 and shield_hp_current < shield_hp_max
	var shield_repair_threshold = clamp(float(behavior_values.get("shield_repair_threshold", 0.65)), 0.0, 1.0)
	var shield_logic_allows_repair := bool(behavior_values.get("allow_shield_repair", true))
	var shield_repairable := (
		shield_damaged
		and bool(shield_item_data.get("repairable_while_active", true))
		and not bool(shield_item_data.get("repairable_when_broken", false))
		and shield_logic_allows_repair
	)
	var shield_repair_needed = shield_repairable and shield_hp_ratio <= shield_repair_threshold
	var replacement_shield_id := str(shield.get("replacement_shield_item_id", loadout.get("replacement_shield", ""))).strip_edges()
	if replacement_shield_id == "" and not shield_equipped:
		replacement_shield_id = shield_id
	var replacement_shield_item_data: Dictionary = _safe_dictionary(shield.get("replacement_shield_item_data", {}))
	if replacement_shield_item_data.is_empty() and replacement_shield_id == shield_id:
		replacement_shield_item_data = shield_item_data.duplicate(true)
	var replacement_control_item_data := replacement_shield_item_data if not replacement_shield_item_data.is_empty() else shield_item_data
	var shield_logic_allows_equip := (
		bool(behavior_values.get("allow_shield_use", true))
		and _item_allows_enemy_action(replacement_control_item_data, "enemy_can_equip")
	)
	var shield_logic_allows_replacement := _item_allows_enemy_action(replacement_control_item_data, "enemy_can_replace_broken_shield")
	var shield_has_replacement := (
		replacement_shield_id != ""
		and shield_logic_allows_equip
		and shield_logic_allows_replacement
		and bool(behavior_values.get("replace_broken_shield", true))
	)

	var selected_consumable := _choose_consumable_candidate_for_awareness(
		enemy,
		consumable_id,
		consumable_item_data,
		usable_consumables,
		enemy_health_ratio,
		player_health_ratio,
		shield_repair_needed
	)
	if not selected_consumable.is_empty():
		consumable_id = str(selected_consumable.get("item_id", consumable_id)).strip_edges()
		consumable_item_data = _safe_dictionary(selected_consumable.get("item_data", consumable_item_data))
	var consumable_group := _consumable_group(consumable_item_data)

	var primary_energy_cost := _item_energy_cost(primary_item_data)
	var secondary_energy_cost := _item_energy_cost(secondary_item_data)
	var secondary_ammo_group := _item_ammo_group(secondary_item_data)
	var secondary_ammo_cost := _item_ammo_cost(secondary_item_data)
	var secondary_ammo_count := _ammo_count_for_group(ammo, secondary_ammo_group)
	var secondary_needs_ammo := secondary_ammo_group != "" and secondary_ammo_cost > 0
	var secondary_ammo_ready := true
	if secondary_needs_ammo:
		secondary_ammo_ready = secondary_ammo_count >= secondary_ammo_cost

	var enemy_has_good_lock := bool(update_package.get("enemy_has_good_lock", _enemy_has_good_lock(enemy)))
	var enemy_lock_pending := bool(update_package.get("enemy_lock_pending", _unit_bool_value(enemy, "enemy_lock_pending", _unit_bool_value(enemy, "lock_pending", false))))
	var enemy_lock_disabled := bool(update_package.get("enemy_lock_disabled", _enemy_lock_disabled(enemy)))
	var player_has_good_lock := bool(update_package.get("player_has_good_lock", _player_has_good_lock(player_state)))
	var evade_cooldown_remaining := float(update_package.get("enemy_evade_cooldown_remaining_seconds", 0.0))

	var loaded_consumable = consumable.get("loaded_consumable", null)
	var enemy_loaded_consumable = consumable.get("enemy_loaded_consumable", null)
	var consumable_stack_count = max(int(_dict_float(item_stacks, consumable_id, 0.0)), 0)
	var consumable_has_stack = consumable_id != "" and consumable_stack_count > 0
	var loaded_consumable_id := _extract_item_id_from_value(loaded_consumable)
	if loaded_consumable_id == "":
		loaded_consumable_id = _extract_item_id_from_value(enemy_loaded_consumable)
	var loaded_consumable_item_data: Dictionary = _loaded_consumable_item_data_from_awareness_sources(
		loaded_consumable,
		enemy_loaded_consumable,
		loaded_consumable_id,
		consumable_id,
		consumable_item_data,
		usable_consumables
	)
	var loaded_consumable_group := _consumable_group(loaded_consumable_item_data)
	if loaded_consumable_group == "" and loaded_consumable_id != "" and loaded_consumable_id == consumable_id:
		loaded_consumable_group = consumable_group
	var consumable_loaded = loaded_consumable_id != ""
	var consumable_ready = _dict_bool(consumable, "consumable_ready", _dict_bool(consumable, "enemy_consumable_ready", false)) and consumable_loaded
	var consumable_enemy_use_allowed := _item_allows_enemy_action(consumable_item_data, "enemy_can_use")
	var loaded_consumable_enemy_use_allowed := _item_allows_enemy_action(loaded_consumable_item_data, "enemy_can_use")
	if consumable_group == "shield_repair":
		consumable_enemy_use_allowed = consumable_enemy_use_allowed and _item_allows_enemy_action(consumable_item_data, "enemy_use_when_shield_damaged")
	if loaded_consumable_group == "shield_repair":
		loaded_consumable_enemy_use_allowed = loaded_consumable_enemy_use_allowed and _item_allows_enemy_action(loaded_consumable_item_data, "enemy_use_when_shield_damaged")
	var drone_counts := _count_active_drones_by_side(active_drone_snapshot)
	var primary_spam_gate_remaining := _dict_float(weapon_gates, "primary_remaining", 0.0)
	var secondary_spam_gate_remaining := _dict_float(weapon_gates, "secondary_remaining", 0.0)

	return {
		"battle_active": bool(update_package.get("battle_active", true)) and not bool(update_package.get("battle_ended", false)) and not bool(update_package.get("battle_v2_ended", false)),
		"enemy_health_ratio": enemy_health_ratio,
		"player_health_ratio": player_health_ratio,
		"enemy_has_good_lock": enemy_has_good_lock,
		"enemy_lock_pending": enemy_lock_pending,
		"enemy_lock_disabled": enemy_lock_disabled,
		"player_has_good_lock": player_has_good_lock,
		"enemy_energy_current": energy_current,
		"enemy_energy_max": energy_max,
		"enemy_reserved_energy": energy_reserved,
		"enemy_energy_available": energy_available,
		"enemy_energy_ratio": energy_ratio,
		"primary_item_id": primary_id,
		"secondary_item_id": secondary_id,
		"shield_item_id": shield_id,
		"consumable_item_id": consumable_id,
		"primary_item_data": primary_item_data,
		"secondary_item_data": secondary_item_data,
		"shield_item_data": shield_item_data,
		"shield_power_level": int(shield.get("shield_power_level", _unit_float_value(enemy, "shield_power_level", 0.0))),
		"shield_hp_current": shield_hp_current,
		"shield_hp_max": shield_hp_max,
		"shield_hp_ratio": shield_hp_ratio,
		"shield_equipped": shield_equipped,
		"shield_equipped_item_id": equipped_shield_id,
		"shield_damaged": shield_damaged,
		"shield_broken": shield_broken,
		"shield_repairable": shield_repairable,
		"shield_repair_needed": shield_repair_needed,
		"shield_repair_threshold": shield_repair_threshold,
		"shield_logic_allows_repair": shield_logic_allows_repair,
		"shield_logic_allows_equip": shield_logic_allows_equip,
		"shield_logic_allows_replacement": shield_logic_allows_replacement,
		"shield_replacement_item_id": replacement_shield_id,
		"shield_replacement_item_data": replacement_shield_item_data,
		"shield_has_replacement": shield_has_replacement,
		"shield_inventory_count": int(shield.get("equipped_shield_inventory_count", _dict_float(item_stacks, equipped_shield_id, 0.0))),
		"consumable_item_data": consumable_item_data,
		"consumable_group": consumable_group,
		"consumable_enemy_use_allowed": consumable_enemy_use_allowed,
		"consumable_stack_count": consumable_stack_count,
		"usable_consumable_count": usable_consumables.size(),
		"usable_consumables": usable_consumables,
		"consumable_has_stack": consumable_has_stack,
		"loaded_consumable_item_id": loaded_consumable_id,
		"loaded_consumable_item_data": loaded_consumable_item_data,
		"loaded_consumable_group": loaded_consumable_group,
		"loaded_consumable_enemy_use_allowed": loaded_consumable_enemy_use_allowed,
		"loaded_consumable_repair_amount": _repair_amount(loaded_consumable_item_data),
		"loaded_consumable_shield_repair_amount": _shield_repair_amount(loaded_consumable_item_data),
		"loaded_consumable_explosive_damage": _explosive_damage(loaded_consumable_item_data),
		"consumable_repair_amount": _repair_amount(consumable_item_data),
		"consumable_shield_repair_amount": _shield_repair_amount(consumable_item_data),
		"consumable_explosive_damage": _explosive_damage(consumable_item_data),
		"consumable_is_repair": consumable_group == "repair",
		"consumable_is_shield_repair": consumable_group == "shield_repair",
		"consumable_is_recharge": consumable_group == "recharge",
		"consumable_is_explosive": consumable_group == "explosive",
		"consumable_is_signal": consumable_group == "signal",
		"consumable_is_drone": consumable_group == "drone",
		"consumable_is_pulse": consumable_group == "pulse",
		"drone_type": str(consumable_item_data.get("drone_type", "")).strip_edges(),
		"drone_group": str(consumable_item_data.get("drone_group", consumable_item_data.get("subgroup", ""))).strip_edges(),
		"drone_auto_attack": bool(consumable_item_data.get("drone_auto_attack", str(consumable_item_data.get("drone_type", "")).strip_edges() == "auto_attack")),
		"drone_damage_value": _dict_float(consumable_item_data, "drone_damage_value", 0.0),
		"drone_shield_active": bool(consumable_item_data.get("drone_shield_active", false)),
		"primary_available": primary_id != "" and _enemy_primary_available(enemy),
		"secondary_available": secondary_id != "" and _enemy_secondary_available(enemy),
		"primary_energy_cost": primary_energy_cost,
		"secondary_energy_cost": secondary_energy_cost,
		"primary_energy_ready": energy_available >= primary_energy_cost,
		"secondary_energy_ready": energy_available >= secondary_energy_cost,
		"primary_spam_gate_ready": primary_spam_gate_remaining <= 0.0,
		"secondary_spam_gate_ready": secondary_spam_gate_remaining <= 0.0,
		"primary_spam_gate_remaining": primary_spam_gate_remaining,
		"secondary_spam_gate_remaining": secondary_spam_gate_remaining,
		"secondary_ammo_group": secondary_ammo_group,
		"secondary_ammo_cost": secondary_ammo_cost,
		"secondary_ammo_count": secondary_ammo_count,
		"secondary_ammo_ready": secondary_ammo_ready,
		"shield_switching": _dict_bool(shield, "shield_switching", _unit_bool_value(enemy, "shield_switching", false)),
		"has_shield_option": shield_equipped or shield_has_replacement,
		"consumable_loaded": consumable_loaded,
		"consumable_ready": consumable_ready,
		"active_enemy_event_count": active_enemy_events.size(),
		"active_player_event_count": active_player_events.size(),
		"active_drone_count": int(active_drone_snapshot.get("active_count", 0)),
		"enemy_active_drone_count": int(drone_counts.get("enemy", 0)),
		"player_active_drone_count": int(drone_counts.get("player", 0)),
		"enemy_has_active_drone": int(drone_counts.get("enemy", 0)) > 0,
		"player_has_active_drone": int(drone_counts.get("player", 0)) > 0,
		"active_drone_snapshot": active_drone_snapshot,
		"evade_ready": _enemy_can_evade(enemy) and evade_cooldown_remaining <= 0.0,
		"evade_cooldown_remaining": evade_cooldown_remaining
	}


func _build_capability_preview(awareness: Dictionary) -> Dictionary:
	# Summary: Return a compact yes/no tactical capability readout for debug/testing before behavior uses it.
	return {
		"can_act": _awareness_can_act(awareness),
		"needs_reacquire": _awareness_needs_reacquire(awareness),
		"can_use_primary": _can_use_primary(awareness),
		"can_use_secondary": _can_use_secondary(awareness),
		"can_use_signal": _can_use_signal(awareness),
		"can_switch_shield": _can_switch_shield(awareness),
		"can_replace_shield": _can_replace_shield(awareness),
		"can_repair_shield": _can_load_or_execute_shield_repair_consumable(awareness),
		"can_load_consumable": _can_load_consumable(awareness),
		"can_execute_consumable": _can_execute_consumable(awareness),
		"can_execute_repair": _can_execute_repair_consumable(awareness, 1.0),
		"can_execute_explosive": _can_execute_explosive_consumable(awareness, 1.0),
		"can_load_or_execute_repair": _can_load_or_execute_repair_consumable(awareness, 1.0),
		"can_load_or_execute_explosive": _can_load_or_execute_explosive_consumable(awareness, 1.0),
		"can_load_or_execute_drone": _can_load_or_execute_drone_consumable(awareness),
		"can_execute_drone": _can_execute_drone_consumable(awareness),
		"can_evade_now": _can_evade_now(awareness),
		"wait_reason": _awareness_wait_reason(awareness)
	}


func _debug_print_awareness_preview(awareness: Dictionary) -> void:
	# Summary: Print the awareness snapshot in the current project log style.
	print("[enemy_awareness_preview] | drop down list")
	for key in _enemy_awareness_print_order():
		if awareness.has(key):
			print("[enemy_awareness_preview] ", key)


func _debug_print_capability_preview(capability: Dictionary) -> void:
	# Summary: Print capability checks in the current project log style.
	print("[enemy_capability_preview] | drop down list")
	for key in _enemy_capability_print_order():
		if capability.has(key):
			print("[enemy_capability_preview] ", key, "=", capability.get(key))


func _enemy_awareness_print_order() -> Array:
	# Summary: Keep awareness debug output stable and easy to compare between runs.
	return [
		"battle_active",
		"enemy_health_ratio",
		"player_health_ratio",
		"enemy_has_good_lock",
		"enemy_lock_pending",
		"enemy_lock_disabled",
		"player_has_good_lock",
		"enemy_energy_current",
		"enemy_energy_max",
		"enemy_reserved_energy",
		"enemy_energy_available",
		"enemy_energy_ratio",
		"primary_item_id",
		"secondary_item_id",
		"shield_item_id",
		"consumable_item_id",
		"primary_item_data",
		"secondary_item_data",
		"shield_item_data",
		"shield_equipped",
		"shield_equipped_item_id",
		"shield_hp_current",
		"shield_hp_max",
		"shield_hp_ratio",
		"shield_damaged",
		"shield_broken",
		"shield_repairable",
		"shield_repair_needed",
		"shield_replacement_item_id",
		"shield_has_replacement",
		"shield_logic_allows_equip",
		"shield_logic_allows_replacement",
		"shield_logic_allows_repair",
		"consumable_item_data",
		"consumable_group",
		"consumable_stack_count",
		"consumable_repair_amount",
		"consumable_explosive_damage",
		"primary_available",
		"secondary_available",
		"primary_energy_cost",
		"secondary_energy_cost",
		"primary_energy_ready",
		"secondary_energy_ready",
		"primary_spam_gate_ready",
		"secondary_spam_gate_ready",
		"primary_spam_gate_remaining",
		"secondary_spam_gate_remaining",
		"secondary_ammo_group",
		"secondary_ammo_cost",
		"secondary_ammo_count",
		"secondary_ammo_ready",
		"shield_switching",
		"has_shield_option",
		"consumable_loaded",
		"consumable_ready",
		"active_enemy_event_count",
		"active_player_event_count",
		"evade_ready",
		"evade_cooldown_remaining"
	]


func _enemy_capability_print_order() -> Array:
	# Summary: Keep capability debug output stable and easy to compare between runs.
	return [
		"can_act",
		"needs_reacquire",
		"can_use_primary",
		"can_use_secondary",
		"can_use_signal",
		"can_switch_shield",
		"can_replace_shield",
		"can_repair_shield",
		"can_load_consumable",
		"can_execute_consumable",
		"can_evade_now",
		"wait_reason"
	]


func _awareness_can_act(awareness: Dictionary) -> bool:
	# Summary: Check whether the awareness snapshot says battle and enemy state are valid for a decision.
	if not bool(awareness.get("battle_active", true)):
		return false
	if float(awareness.get("enemy_health_ratio", 0.0)) <= 0.0:
		return false
	if int(awareness.get("active_enemy_event_count", 0)) > 0:
		return false
	return true


func _awareness_needs_reacquire(awareness: Dictionary) -> bool:
	# Summary: Check whether reacquire is useful from the awareness snapshot.
	if bool(awareness.get("enemy_lock_disabled", false)):
		return false
	if bool(awareness.get("enemy_lock_pending", false)):
		return false
	return not bool(awareness.get("enemy_has_good_lock", false))


func _can_use_primary(awareness: Dictionary) -> bool:
	# Summary: Check if the enemy can choose a primary attack from awareness only.
	if not _awareness_can_act(awareness):
		return false
	if bool(awareness.get("enemy_lock_disabled", false)):
		return false
	if not bool(awareness.get("enemy_has_good_lock", false)):
		return false
	if not bool(awareness.get("primary_available", false)):
		return false
	if not bool(awareness.get("primary_energy_ready", false)):
		return false
	if not bool(awareness.get("primary_spam_gate_ready", true)):
		return false
	return true


func _can_use_secondary(awareness: Dictionary) -> bool:
	# Summary: Check if the enemy can choose a secondary attack from awareness only.
	if not _awareness_can_act(awareness):
		return false
	if bool(awareness.get("enemy_lock_disabled", false)):
		return false
	if not bool(awareness.get("enemy_has_good_lock", false)):
		return false
	if not bool(awareness.get("secondary_available", false)):
		return false
	if not bool(awareness.get("secondary_energy_ready", false)):
		return false
	if not bool(awareness.get("secondary_ammo_ready", true)):
		return false
	if not bool(awareness.get("secondary_spam_gate_ready", true)):
		return false
	return true


func _can_use_signal(awareness: Dictionary) -> bool:
	# Summary: Check if the enemy can choose a signal-style action from awareness only.
	if not _awareness_can_act(awareness):
		return false
	if bool(awareness.get("enemy_lock_disabled", false)):
		return false
	if not bool(awareness.get("enemy_has_good_lock", false)):
		return false
	# Signal-specific availability still comes from the behavior branch for now.
	return true


func _can_switch_shield(awareness: Dictionary) -> bool:
	# Summary: Check if the enemy can choose a shield switch from awareness only.
	return _can_replace_shield(awareness)


func _can_replace_shield(awareness: Dictionary) -> bool:
	# Summary: Require an owned, tagged replacement and no intact equipped shield.
	if not _awareness_can_act(awareness):
		return false
	if bool(awareness.get("shield_switching", false)):
		return false
	if bool(awareness.get("shield_equipped", false)) and not bool(awareness.get("shield_broken", false)):
		return false
	if not bool(awareness.get("shield_logic_allows_equip", false)):
		return false
	return bool(awareness.get("shield_has_replacement", false))


func _can_load_consumable(awareness: Dictionary) -> bool:
	# Summary: Check if the enemy has a consumable option that can be loaded later.
	if not _awareness_can_act(awareness):
		return false
	if bool(awareness.get("consumable_loaded", false)):
		return false
	if not bool(awareness.get("consumable_has_stack", false)):
		return false
	if not bool(awareness.get("consumable_enemy_use_allowed", true)):
		return false
	return str(awareness.get("consumable_item_id", "")).strip_edges() != ""


func _can_execute_consumable(awareness: Dictionary) -> bool:
	# Summary: Check if the enemy can execute a loaded/ready consumable.
	if not _awareness_can_act(awareness):
		return false
	if not bool(awareness.get("consumable_loaded", false)):
		return false
	if not bool(awareness.get("loaded_consumable_enemy_use_allowed", true)):
		return false
	return bool(awareness.get("consumable_ready", false))


func _can_execute_repair_consumable(awareness: Dictionary, threshold: float) -> bool:
	if not _can_execute_consumable(awareness):
		return false
	var group := str(awareness.get("loaded_consumable_group", awareness.get("consumable_group", ""))).strip_edges().to_lower()
	if group == "":
		group = str(awareness.get("consumable_group", "")).strip_edges().to_lower()
	if group != "repair":
		return false
	if float(awareness.get("enemy_health_ratio", 1.0)) > threshold:
		return false
	return float(awareness.get("loaded_consumable_repair_amount", awareness.get("consumable_repair_amount", 0.0))) > 0.0


func _can_execute_explosive_consumable(awareness: Dictionary, player_threshold: float = 1.0) -> bool:
	if not _can_execute_consumable(awareness):
		return false
	var group := str(awareness.get("loaded_consumable_group", awareness.get("consumable_group", ""))).strip_edges().to_lower()
	if group == "":
		group = str(awareness.get("consumable_group", "")).strip_edges().to_lower()
	if group != "explosive":
		return false
	if bool(awareness.get("enemy_lock_disabled", false)):
		return false
	if not bool(awareness.get("enemy_has_good_lock", false)):
		return false
	if float(awareness.get("player_health_ratio", 1.0)) > player_threshold:
		return false
	return float(awareness.get("loaded_consumable_explosive_damage", awareness.get("consumable_explosive_damage", 0.0))) > 0.0


func _can_execute_shield_repair_consumable(awareness: Dictionary) -> bool:
	# Summary: Shield repair can execute only against an equipped, damaged shield with positive HP.
	if not _can_execute_consumable(awareness):
		return false
	if str(awareness.get("loaded_consumable_group", "")).strip_edges().to_lower() != "shield_repair":
		return false
	if not bool(awareness.get("shield_repair_needed", false)):
		return false
	return float(awareness.get("loaded_consumable_shield_repair_amount", 0.0)) > 0.0


func _can_load_or_execute_shield_repair_consumable(awareness: Dictionary) -> bool:
	# Summary: Expose a single control check for shield-patch load or execute decisions.
	if not bool(awareness.get("shield_repair_needed", false)):
		return false
	if _can_execute_shield_repair_consumable(awareness):
		return true
	if str(awareness.get("consumable_group", "")).strip_edges().to_lower() != "shield_repair":
		return false
	if float(awareness.get("consumable_shield_repair_amount", 0.0)) <= 0.0:
		return false
	return _can_load_consumable(awareness)

func _can_execute_drone_consumable(awareness: Dictionary) -> bool:
	# Summary: Check if the currently loaded consumable can deploy as a drone now.
	if not _can_execute_consumable(awareness):
		return false
	var group := str(awareness.get("loaded_consumable_group", awareness.get("consumable_group", ""))).strip_edges().to_lower()
	if group == "":
		group = str(awareness.get("consumable_group", "")).strip_edges().to_lower()
	if group != "drone":
		return false
	return str(awareness.get("loaded_consumable_item_id", awareness.get("consumable_item_id", ""))).strip_edges() != ""


func _can_load_or_execute_drone_consumable(awareness: Dictionary) -> bool:
	# Summary: True when the enemy has a drone consumable either loaded or available to load.
	var group := str(awareness.get("loaded_consumable_group", awareness.get("consumable_group", ""))).strip_edges().to_lower()
	if group == "":
		group = str(awareness.get("consumable_group", "")).strip_edges().to_lower()
	if not bool(awareness.get("consumable_loaded", false)):
		group = str(awareness.get("consumable_group", "")).strip_edges().to_lower()
	if group != "drone":
		return false
	return _can_execute_drone_consumable(awareness) or _can_load_consumable(awareness)


func _can_load_or_execute_repair_consumable(awareness: Dictionary, threshold: float) -> bool:
	# Summary: True when a repair consumable is either ready or can be loaded for later execution.
	var group := str(awareness.get("loaded_consumable_group", awareness.get("consumable_group", ""))).strip_edges().to_lower()
	if group == "":
		group = str(awareness.get("consumable_group", "")).strip_edges().to_lower()
	if not bool(awareness.get("consumable_loaded", false)):
		group = str(awareness.get("consumable_group", "")).strip_edges().to_lower()
	if group != "repair":
		return false
	if float(awareness.get("enemy_health_ratio", 1.0)) > threshold:
		return false
	var repair_amount := float(awareness.get("loaded_consumable_repair_amount", awareness.get("consumable_repair_amount", 0.0)))
	if not bool(awareness.get("consumable_loaded", false)):
		repair_amount = float(awareness.get("consumable_repair_amount", 0.0))
	if repair_amount <= 0.0:
		return false
	return _can_execute_repair_consumable(awareness, threshold) or _can_load_consumable(awareness)


func _can_load_or_execute_explosive_consumable(awareness: Dictionary, player_threshold: float = 1.0) -> bool:
	# Summary: True when an explosive consumable is either ready or can be loaded for later execution.
	var group := str(awareness.get("loaded_consumable_group", awareness.get("consumable_group", ""))).strip_edges().to_lower()
	if group == "":
		group = str(awareness.get("consumable_group", "")).strip_edges().to_lower()
	if not bool(awareness.get("consumable_loaded", false)):
		group = str(awareness.get("consumable_group", "")).strip_edges().to_lower()
	if group != "explosive":
		return false
	if bool(awareness.get("enemy_lock_disabled", false)):
		return false
	if not bool(awareness.get("enemy_has_good_lock", false)):
		return false
	if float(awareness.get("player_health_ratio", 1.0)) > player_threshold:
		return false
	var explosive_damage := float(awareness.get("loaded_consumable_explosive_damage", awareness.get("consumable_explosive_damage", 0.0)))
	if not bool(awareness.get("consumable_loaded", false)):
		explosive_damage = float(awareness.get("consumable_explosive_damage", 0.0))
	if explosive_damage <= 0.0:
		return false
	return _can_execute_explosive_consumable(awareness, player_threshold) or _can_load_consumable(awareness)


func _should_use_drone_consumable(awareness: Dictionary, mode: String = "pressure") -> bool:
	# Summary: Primitive drone desire rules; profiles decide where this sits in their order.
	if not _can_load_or_execute_drone_consumable(awareness):
		return false
	if bool(awareness.get("enemy_has_active_drone", false)):
		return false
	var enemy_health_ratio := float(awareness.get("enemy_health_ratio", 1.0))
	var player_health_ratio := float(awareness.get("player_health_ratio", 1.0))
	var active_player_events := int(awareness.get("active_player_event_count", 0))
	var normalized_mode := mode.strip_edges().to_lower()
	if normalized_mode == "survival":
		return enemy_health_ratio <= 0.70 or bool(awareness.get("player_has_good_lock", false)) or active_player_events > 0
	if normalized_mode == "desperation":
		return enemy_health_ratio <= 0.35
	# pressure/opening mode: deploy early while the fight is still meaningful.
	return enemy_health_ratio > 0.35 and player_health_ratio > 0.20


func _can_evade_now(awareness: Dictionary) -> bool:
	# Summary: Check if the enemy can evade right now from awareness only.
	if not _awareness_can_act(awareness):
		return false
	return bool(awareness.get("evade_ready", false)) and float(awareness.get("evade_cooldown_remaining", 0.0)) <= 0.0


func _awareness_wait_reason(awareness: Dictionary) -> String:
	# Summary: Explain why a behavior may need to fall back to wait during debug.
	if not bool(awareness.get("battle_active", true)):
		return "battle inactive"
	if float(awareness.get("enemy_health_ratio", 0.0)) <= 0.0:
		return "enemy disabled"
	if int(awareness.get("active_enemy_event_count", 0)) > 0:
		return "enemy event already active"
	if bool(awareness.get("enemy_lock_disabled", false)):
		return "enemy lock disabled"
	if bool(awareness.get("enemy_lock_pending", false)):
		return "enemy lock pending"
	if not bool(awareness.get("enemy_has_good_lock", false)):
		return "enemy needs lock"
	if not bool(awareness.get("primary_available", false)) and not bool(awareness.get("secondary_available", false)):
		return "no weapon available"
	if not bool(awareness.get("primary_energy_ready", true)) and not bool(awareness.get("secondary_energy_ready", true)):
		return "not enough energy"
	if bool(awareness.get("secondary_available", false)) and not bool(awareness.get("secondary_ammo_ready", true)):
		return "secondary ammo missing"
	return "no blocking reason"


func _choose_consumable_candidate_for_awareness(
	enemy,
	current_id: String,
	current_data: Dictionary,
	usable_consumables: Array,
	enemy_health_ratio: float,
	player_health_ratio: float,
	shield_repair_needed: bool = false
) -> Dictionary:
	# Summary: Primitive item-belt chooser; keeps current loaded item, otherwise picks a usable consumable by profile flavor.
	if current_id.strip_edges() != "" and not current_data.is_empty():
		var current_group := _consumable_group(current_data)
		var shield_priority_changed := (
			(shield_repair_needed and current_group != "shield_repair")
			or (not shield_repair_needed and current_group == "shield_repair")
		)
		if not shield_priority_changed:
			return {"item_id": current_id.strip_edges(), "item_data": current_data}
	if usable_consumables.is_empty():
		return {}

	var profile_id := str(_unit_value(enemy, "behavior_profile", "")).strip_edges().to_lower()
	var preferred_groups: Array = []
	var behavior_values := _get_behavior_values(enemy)
	var authored_groups: Array = _safe_array(behavior_values.get("preferred_consumable_groups", []))
	if not authored_groups.is_empty():
		preferred_groups = authored_groups
	elif profile_id.find("drone") >= 0:
		preferred_groups = ["drone", "repair", "explosive", "recharge", "signal", "pulse"]
	elif profile_id.find("survivor") >= 0:
		preferred_groups = ["repair", "drone", "recharge", "signal", "explosive", "pulse"]
	elif profile_id.find("bomber") >= 0:
		preferred_groups = ["explosive", "drone", "recharge", "repair", "signal", "pulse"]
	elif profile_id.find("tactician") >= 0 or profile_id.find("smart") >= 0:
		if enemy_health_ratio <= 0.40:
			preferred_groups = ["repair", "drone", "explosive", "recharge", "signal", "pulse"]
		elif player_health_ratio <= 0.55:
			preferred_groups = ["explosive", "drone", "signal", "pulse", "repair", "recharge"]
		else:
			preferred_groups = ["drone", "signal", "pulse", "explosive", "repair", "recharge"]
	else:
		preferred_groups = ["repair", "explosive", "drone", "recharge", "signal", "pulse"]
	if shield_repair_needed:
		preferred_groups.erase("shield_repair")
		preferred_groups.push_front("shield_repair")

	for wanted_group in preferred_groups:
		var candidate := _find_usable_consumable_by_group(usable_consumables, str(wanted_group))
		if not candidate.is_empty() and _item_allows_enemy_action(_safe_dictionary(candidate.get("item_data", {})), "enemy_can_use"):
			return candidate

	for raw_candidate in usable_consumables:
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue
		var fallback_candidate: Dictionary = raw_candidate
		var fallback_group := str(fallback_candidate.get("consumable_group", "")).strip_edges().to_lower()
		if fallback_group == "shield_repair" and not shield_repair_needed:
			continue
		if not _item_allows_enemy_action(_safe_dictionary(fallback_candidate.get("item_data", {})), "enemy_can_use"):
			continue
		return fallback_candidate.duplicate(true)
	return {}


func _loaded_consumable_item_data_from_awareness_sources(
	loaded_consumable,
	enemy_loaded_consumable,
	loaded_consumable_id: String,
	current_consumable_id: String,
	current_consumable_item_data: Dictionary,
	usable_consumables: Array
) -> Dictionary:
	# Summary: Resolve the ready loaded slot's item data so profiles execute the loaded item, not a newly preferred stack item.
	var loaded_data: Dictionary = {}
	if typeof(loaded_consumable) == TYPE_DICTIONARY:
		loaded_data = _safe_dictionary(loaded_consumable)
	elif typeof(enemy_loaded_consumable) == TYPE_DICTIONARY:
		loaded_data = _safe_dictionary(enemy_loaded_consumable)

	if loaded_data.is_empty() and loaded_consumable_id.strip_edges() != "":
		for raw_candidate in usable_consumables:
			if typeof(raw_candidate) != TYPE_DICTIONARY:
				continue
			var candidate: Dictionary = raw_candidate
			if str(candidate.get("item_id", "")).strip_edges() != loaded_consumable_id.strip_edges():
				continue
			loaded_data = _safe_dictionary(candidate.get("item_data", {}))
			break

	if loaded_data.is_empty() and loaded_consumable_id.strip_edges() != "" and loaded_consumable_id.strip_edges() == current_consumable_id.strip_edges():
		loaded_data = current_consumable_item_data.duplicate(true)

	if not loaded_data.is_empty() and loaded_consumable_id.strip_edges() != "":
		if not loaded_data.has("item_id") or str(loaded_data.get("item_id", "")).strip_edges() == "":
			loaded_data["item_id"] = loaded_consumable_id.strip_edges()
		if not loaded_data.has("id") or str(loaded_data.get("id", "")).strip_edges() == "":
			loaded_data["id"] = loaded_consumable_id.strip_edges()

	return loaded_data


func _find_usable_consumable_by_group(usable_consumables: Array, wanted_group: String) -> Dictionary:
	# Summary: Find a held consumable by consumable_group from the controller-provided item belt.
	var group := wanted_group.strip_edges().to_lower()
	for raw_candidate in usable_consumables:
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = raw_candidate
		if int(candidate.get("stack_count", 0)) <= 0:
			continue
		if str(candidate.get("consumable_group", "")).strip_edges().to_lower() == group:
			return candidate.duplicate(true)
	return {}


func _extract_item_id_from_value(value) -> String:
	# Summary: Normalize a loaded item value that might be an id string or full item dictionary.
	if value == null:
		return ""
	if typeof(value) == TYPE_DICTIONARY:
		return str(value.get("item_id", value.get("id", value.get("name", "")))).strip_edges()
	var text := str(value).strip_edges()
	if text == "" or text == "<null>" or text.to_lower() == "null":
		return ""
	return text


func _count_active_drones_by_side(active_drone_snapshot: Dictionary) -> Dictionary:
	# Summary: Count active drones by owner side from BattleManager's read-only snapshot.
	var counts := {"enemy": 0, "player": 0, "unknown": 0}
	var drones := _safe_array(active_drone_snapshot.get("drones", []))
	for drone in drones:
		if typeof(drone) != TYPE_DICTIONARY:
			continue
		var owner_side := str(drone.get("owner_side", "unknown")).strip_edges().to_lower()
		if not counts.has(owner_side):
			owner_side = "unknown"
		counts[owner_side] = int(counts.get(owner_side, 0)) + 1
	return counts


func _safe_dictionary(raw_value) -> Dictionary:
	# Summary: Convert unknown nested values into a safe dictionary for awareness reads.
	if typeof(raw_value) == TYPE_DICTIONARY:
		return raw_value.duplicate(true)
	return {}


func _safe_array(raw_value) -> Array:
	# Summary: Convert unknown nested values into a safe array for awareness reads.
	if typeof(raw_value) == TYPE_ARRAY:
		return raw_value.duplicate(true)
	return []


func _dict_float(packet: Dictionary, key: String, fallback: float = 0.0) -> float:
	# Summary: Read a float from a dictionary with safe string/number fallback support.
	var raw_value = packet.get(key, fallback)
	if typeof(raw_value) == TYPE_INT or typeof(raw_value) == TYPE_FLOAT:
		return float(raw_value)
	if typeof(raw_value) == TYPE_STRING:
		var text := str(raw_value).strip_edges()
		if text != "":
			return text.to_float()
	return fallback


func _dict_bool(packet: Dictionary, key: String, fallback: bool = false) -> bool:
	# Summary: Read a bool from a dictionary with safe string/number fallback support.
	var raw_value = packet.get(key, fallback)
	if typeof(raw_value) == TYPE_BOOL:
		return raw_value
	if typeof(raw_value) == TYPE_INT or typeof(raw_value) == TYPE_FLOAT:
		return float(raw_value) != 0.0
	if typeof(raw_value) == TYPE_STRING:
		var text := str(raw_value).strip_edges().to_lower()
		if text == "true" or text == "yes" or text == "1":
			return true
		if text == "false" or text == "no" or text == "0":
			return false
	return fallback


func _value_exists(value) -> bool:
	# Summary: Treat null and empty marker strings as missing tactical values.
	if value == null:
		return false
	var text := str(value).strip_edges()
	return text != "" and text != "<null>" and text.to_lower() != "null"


func _unit_health_ratio(unit, side_hint: String) -> float:
	# Summary: Calculate a side-aware hull ratio for awareness fallback reads.
	var hull_max := _unit_hull_max(unit, side_hint, 1.0)
	var hull_current := _unit_hull_current(unit, side_hint, hull_max)
	if hull_max <= 0.0:
		return 0.0
	return clamp(hull_current / hull_max, 0.0, 1.0)


func _item_energy_cost(item_data: Dictionary) -> float:
	# Summary: Read likely energy-cost fields from an item packet.
	return max(_dict_float(item_data, "energy_cost", _dict_float(item_data, "energy_use", _dict_float(item_data, "use_energy", 0.0))), 0.0)


func _consumable_group(item_data: Dictionary) -> String:
	# Summary: Read the consumable behavior group from a consumable item packet.
	return str(item_data.get("consumable_group", item_data.get("group", item_data.get("subtype", "")))).strip_edges().to_lower()


func _item_allows_enemy_action(item_data: Dictionary, required_tag: String, blocked_tag: String = "") -> bool:
	# Summary: Honor item-level enemy control tags while preserving legacy items that do not define tags.
	if item_data.is_empty():
		return false
	var raw_tags = item_data.get("enemy_logic_tags", [])
	if typeof(raw_tags) != TYPE_ARRAY:
		return true
	var tags: Array = raw_tags
	if blocked_tag.strip_edges() != "" and tags.has(blocked_tag):
		return false
	if tags.is_empty() or required_tag.strip_edges() == "":
		return true
	return tags.has(required_tag)


func _repair_amount(item_data: Dictionary) -> float:
	# Summary: Read likely hull repair amount fields from a consumable item packet.
	return max(_dict_float(item_data, "heal_amount", _dict_float(item_data, "repair_amount", _dict_float(item_data, "hull_restore_amount", 0.0))), 0.0)


func _shield_repair_amount(item_data: Dictionary) -> float:
	# Summary: Read shield-only repair amount without treating hull repair fields as shield repair by default.
	return max(_dict_float(item_data, "shield_repair_amount", 0.0), 0.0)


func _explosive_damage(item_data: Dictionary) -> float:
	# Summary: Read likely explosive damage fields from a consumable item packet.
	var direct_damage = max(
		_dict_float(
			item_data,
			"explosive_damage",
			_dict_float(
				item_data,
				"damage_value",
				_dict_float(
					item_data,
					"damage",
					_dict_float(item_data, "blast_damage", _dict_float(item_data, "hull_damage", 0.0))
				)
			)
		),
		0.0
	)
	if direct_damage > 0.0:
		return direct_damage

	var values = item_data.get("values", {})
	if typeof(values) == TYPE_DICTIONARY:
		return max(
			_dict_float(
				values,
				"explosive_damage",
				_dict_float(values, "damage_value", _dict_float(values, "damage", _dict_float(values, "blast_damage", _dict_float(values, "hull_damage", 0.0))))
			),
			0.0
		)

	return 0.0


func _item_ammo_group(item_data: Dictionary) -> String:
	# Summary: Read the ammo group/type required by a weapon item packet.
	var group := str(item_data.get("ammo_group", item_data.get("ammo_type", ""))).strip_edges().to_lower()
	return group


func _item_ammo_cost(item_data: Dictionary) -> int:
	# Summary: Read likely ammo-cost fields from an item packet.
	var total_cost := int(max(_dict_float(item_data, "total_ammo_cost", -1.0), -1.0))
	if total_cost >= 0:
		return total_cost
	var ammo_cost := int(max(_dict_float(item_data, "ammo_cost", _dict_float(item_data, "ammo_per_shot", 0.0)), 0.0))
	var burst_count := int(max(_dict_float(item_data, "burst_count", _dict_float(item_data, "bursts", 1.0)), 1.0))
	return max(ammo_cost * burst_count, 0)


func _ammo_count_for_group(ammo_packet: Dictionary, ammo_group: String) -> int:
	# Summary: Read ammo count by small/medium/large group from the enemy ammo snapshot.
	var group := ammo_group.strip_edges().to_lower()
	if group == "":
		return 0
	return max(int(_dict_float(ammo_packet, group, 0.0)), 0)


func _enemy_can_act(enemy) -> bool:
	# Summary: Check whether the enemy exists and is not destroyed, dead, or inactive.
	if enemy == null:
		return false

	# Method-based enemy objects get first chance to report destroyed/active state.
	if _unit_has_method(enemy, "is_destroyed") and bool(enemy.call("is_destroyed")):
		return false
	if _unit_has_method(enemy, "is_battle_active") and not bool(enemy.call("is_battle_active")):
		return false

	# Dictionary/object fields support light test packets and future state packets.
	if _unit_bool_value(enemy, "destroyed", false) or _unit_bool_value(enemy, "is_destroyed", false):
		return false
	if _unit_bool_value(enemy, "inactive", false) or not _unit_bool_value(enemy, "is_active", true):
		return false

	# Status strings give tests a readable way to mark inactive enemies.
	var status := str(_unit_value(enemy, "status", "active")).strip_edges().to_lower()
	if status == "dead" or status == "destroyed" or status == "inactive":
		return false

	# Hull at or below zero means the enemy cannot choose an action.
	var hull_max := _unit_hull_max(enemy, "enemy")
	var hull_current := _unit_hull_current(enemy, "enemy", hull_max)
	if hull_max > 0.0 and hull_current <= 0.0:
		return false

	return true


func _enemy_has_good_lock(enemy) -> bool:
	# Summary: Check whether the enemy currently has a good lock on its target.
	if enemy == null:
		return false
	if _unit_has_method(enemy, "has_good_lock"):
		return bool(enemy.call("has_good_lock"))
	return _unit_bool_value(enemy, "enemy_good_lock", _unit_bool_value(enemy, "good_lock", false))


func _enemy_needs_reacquire(enemy) -> bool:
	# Summary: Check whether the enemy should attempt to reacquire lock.
	if enemy == null:
		return false

	# Reacquire is only useful if lock is not good, not already pending, and not disabled.
	var good_lock := _enemy_has_good_lock(enemy)
	var lock_pending := false
	if _unit_has_method(enemy, "is_lock_pending"):
		lock_pending = bool(enemy.call("is_lock_pending"))
	else:
		lock_pending = _unit_bool_value(enemy, "enemy_lock_pending", _unit_bool_value(enemy, "lock_pending", false))

	return not good_lock and not lock_pending and not _enemy_lock_disabled(enemy)


func _enemy_lock_disabled(enemy) -> bool:
	# Summary: Check whether the enemy lock system is disabled.
	if enemy == null:
		return false
	if _unit_has_method(enemy, "is_lock_disabled"):
		return bool(enemy.call("is_lock_disabled"))
	return _unit_bool_value(enemy, "enemy_lock_disabled", _unit_bool_value(enemy, "lock_disabled", false))


func _enemy_hull_below(enemy, threshold: float) -> bool:
	# Summary: Check whether enemy hull ratio is at or below the provided threshold.
	if enemy == null:
		return false

	# Read hull from methods first, then dictionary/object fields, then older hp fields.
	var hull_current := 0.0
	var hull_max := 1.0

	hull_max = _unit_hull_max(enemy, "enemy")
	hull_current = _unit_hull_current(enemy, "enemy", hull_max)

	if hull_max <= 0.0:
		return false

	return (hull_current / hull_max) <= threshold


func _enemy_can_evade(enemy) -> bool:
	# Summary: Check whether the enemy is allowed to choose an evade intent.
	if enemy == null:
		return false
	if _unit_has_method(enemy, "can_choose_evade"):
		return bool(enemy.call("can_choose_evade"))
	return _unit_bool_value(enemy, "can_evade", false)


func _enemy_primary_available(enemy) -> bool:
	# Summary: Check whether the enemy has a usable primary attack option.
	if enemy == null:
		return false

	# Disabled primary weapons cannot be used.
	var disabled := false
	if _unit_has_method(enemy, "is_primary_disabled"):
		disabled = bool(enemy.call("is_primary_disabled"))
	else:
		disabled = _unit_bool_value(enemy, "primary_disabled", false)

	if disabled:
		return false

	# Explicit availability lets future battle state packets bypass weapon object details.
	if _unit_bool_value(enemy, "primary_available", false):
		return true

	# Object-based enemies may expose a weapon lookup method.
	if _unit_has_method(enemy, "get_equipped_weapon"):
		return enemy.call("get_equipped_weapon", "primary") != null

	# Dictionary test packets can provide a selected weapon id.
	var selected_weapon = _unit_value(enemy, "selected_primary_weapon", null)
	if selected_weapon == null:
		return false

	return str(selected_weapon).strip_edges() != ""


func _enemy_secondary_available(enemy) -> bool:
	# Summary: Check whether the enemy has a usable secondary attack option.
	if enemy == null:
		return false

	# Disabled secondary weapons cannot be used.
	var disabled := false
	if _unit_has_method(enemy, "is_secondary_disabled"):
		disabled = bool(enemy.call("is_secondary_disabled"))
	else:
		disabled = _unit_bool_value(enemy, "secondary_disabled", false)

	if disabled:
		return false

	# Explicit availability lets future battle state packets bypass weapon object details.
	if _unit_bool_value(enemy, "secondary_available", false):
		return true

	# Object-based enemies may expose a weapon lookup method.
	if _unit_has_method(enemy, "get_equipped_weapon"):
		return enemy.call("get_equipped_weapon", "secondary") != null

	# Dictionary test packets can provide a selected weapon id.
	var selected_weapon = _unit_value(enemy, "selected_secondary_weapon", null)
	if selected_weapon == null:
		return false

	return str(selected_weapon).strip_edges() != ""


func _enemy_signal_available(enemy) -> bool:
	# Summary: Check whether the enemy can choose a signal-style intent.
	if enemy == null:
		return false
	if _unit_has_method(enemy, "can_choose_signal"):
		return bool(enemy.call("can_choose_signal"))
	return _unit_bool_value(enemy, "can_signal", true)


func _player_has_good_lock(player_state) -> bool:
	# Summary: Check whether the player currently has a good lock.
	if player_state == null:
		return false
	if _unit_has_method(player_state, "has_good_lock"):
		return bool(player_state.call("has_good_lock"))
	return _unit_bool_value(player_state, "player_good_lock", _unit_bool_value(player_state, "good_lock", false))


func _player_hull_below(player_state, threshold: float) -> bool:
	# Summary: Check whether player hull ratio is at or below the provided threshold.
	if player_state == null:
		return false

	# Read hull from methods first, then dictionary/object fields, then older hp fields.
	var hull_current := 0.0
	var hull_max := 1.0

	hull_max = _unit_hull_max(player_state, "player")
	hull_current = _unit_hull_current(player_state, "player", hull_max)

	if hull_max <= 0.0:
		return false

	return (hull_current / hull_max) <= threshold


func _intent_selected(
	intent_id: String,
	enemy,
	target,
	reason: String,
	priority: int,
	labels: Array,
	data: Dictionary = {}
) -> Dictionary:
	# Summary: Build a standardized selected intent packet for later packet-builder conversion.
	if Globals.print_priority_5:
		print("EnemyLogic._intent_selected | Intent selected: ", intent_id, " | Reason: ", reason)

	# Return only the enemy intent; queueing and resolution are owned by later handlers.
	return {
		"status": "selected",
		"intent_id": intent_id,
		"source_unit": enemy,
		"target_unit": target,
		"owner_unit": enemy,
		"event_side": "enemy",
		"reason": reason,
		"priority": priority,
		"labels": labels.duplicate(),
		"data": data.duplicate(true)
	}


func _intent_execute_consumable_from_awareness(
	awareness: Dictionary,
	enemy,
	target,
	reason: String,
	priority: int,
	labels: Array,
	data: Dictionary = {}
) -> Dictionary:
	# Summary: Build an enemy consumable execute intent with item id/data included for PacketBuilder.
	if bool(awareness.get("consumable_loaded", false)):
		return _intent_execute_loaded_consumable_from_awareness(awareness, enemy, target, reason, priority, labels, data)
	var payload := data.duplicate(true)
	payload["item_id"] = str(awareness.get("consumable_item_id", "")).strip_edges()
	payload["consumable_item_id"] = payload["item_id"]
	payload["consumable_group"] = str(awareness.get("consumable_group", "")).strip_edges().to_lower()
	payload["item_data"] = _safe_dictionary(awareness.get("consumable_item_data", {}))
	payload["awareness_driven"] = true
	return _intent_selected(
		"enemy_execute_consumable",
		enemy,
		target,
		reason,
		priority,
		labels,
		payload
	)


func _intent_execute_loaded_consumable_from_awareness(
	awareness: Dictionary,
	enemy,
	target,
	reason: String,
	priority: int,
	labels: Array,
	data: Dictionary = {}
) -> Dictionary:
	# Summary: Build an execute intent from the loaded slot specifically, avoiding drift to another held stack item.
	var payload := data.duplicate(true)
	var item_id := str(awareness.get("loaded_consumable_item_id", "")).strip_edges()
	if item_id == "":
		item_id = str(awareness.get("consumable_item_id", "")).strip_edges()
	var item_data: Dictionary = _safe_dictionary(awareness.get("loaded_consumable_item_data", {}))
	if item_data.is_empty():
		item_data = _safe_dictionary(awareness.get("consumable_item_data", {}))
	var group := str(awareness.get("loaded_consumable_group", "")).strip_edges().to_lower()
	if group == "":
		group = str(awareness.get("consumable_group", "")).strip_edges().to_lower()

	payload["item_id"] = item_id
	payload["consumable_item_id"] = item_id
	payload["consumable_id"] = item_id
	payload["consumable_group"] = group
	payload["item_data"] = item_data
	payload["loaded_slot_execute"] = true
	payload["awareness_driven"] = true
	return _intent_selected(
		"enemy_execute_consumable",
		enemy,
		target,
		reason,
		priority,
		labels,
		payload
	)


func _intent_load_consumable_from_awareness(
	awareness: Dictionary,
	enemy,
	target,
	reason: String,
	priority: int,
	labels: Array,
	data: Dictionary = {}
) -> Dictionary:
	# Summary: Build an enemy consumable load/prep intent with item id/data included for PacketBuilder.
	var payload := data.duplicate(true)
	payload["item_id"] = str(awareness.get("consumable_item_id", "")).strip_edges()
	payload["consumable_item_id"] = payload["item_id"]
	payload["consumable_group"] = str(awareness.get("consumable_group", "")).strip_edges().to_lower()
	payload["item_data"] = _safe_dictionary(awareness.get("consumable_item_data", {}))
	payload["awareness_driven"] = true
	payload["two_step_consumable_plan"] = "load_then_execute"
	return _intent_selected(
		"enemy_load_consumable",
		enemy,
		target,
		reason,
		priority,
		labels,
		payload
	)


func _intent_load_or_execute_consumable_from_awareness(
	awareness: Dictionary,
	enemy,
	target,
	reason: String,
	priority: int,
	labels: Array,
	data: Dictionary = {}
) -> Dictionary:
	# Summary: Primitive two-step item use. If loaded/ready, execute; otherwise load the item first.
	if _can_execute_consumable(awareness):
		var execute_labels := labels.duplicate()
		if not execute_labels.has("enemy_consumable_execute_step"):
			execute_labels.append("enemy_consumable_execute_step")
		return _intent_execute_loaded_consumable_from_awareness(awareness, enemy, target, reason + " execute", priority, execute_labels, data)
	var load_labels := labels.duplicate()
	if not load_labels.has("enemy_consumable_load_step"):
		load_labels.append("enemy_consumable_load_step")
	return _intent_load_consumable_from_awareness(awareness, enemy, enemy, reason + " load", priority, load_labels, data)


func _intent_wait(enemy, target, reason: String, profile_label: String = "") -> Dictionary:
	# Summary: Build a standardized wait intent packet.
	var labels := [
		"enemy_intent_selected",
		"enemy_wait_intent"
	]

	# Attach behavior profile trace when a behavior function provides it.
	if profile_label.strip_edges() != "":
		labels.append("enemy_behavior_profile_" + profile_label)

	return _intent_selected(
		"enemy_wait",
		enemy,
		target,
		reason,
		0,
		labels,
		{
			"behavior_profile": profile_label
		}
	)


func _intent_none(reason: String, labels: Array = []) -> Dictionary:
	# Summary: Build a standardized no-intent packet for missing, inactive, or invalid behavior state.
	if Globals.print_priority_5:
		print("EnemyLogic._intent_none | No enemy intent. Reason: ", reason)

	# Return a no-op intent packet that cannot be mistaken for queued battle work.
	return {
		"status": "none",
		"intent_id": "enemy_none",
		"reason": reason,
		"labels": labels.duplicate(),
		"data": {}
	}


func _validate_full_loop_context(update_package: Dictionary) -> Dictionary:
	# Summary: Block enemy choices when the battle loop or either combatant is no longer valid.
	var labels := [
		"enemy_logic_full_loop_safety_check",
		"enemy_logic_no_resolution"
	]

	if bool(update_package.get("battle_ended", false)) or bool(update_package.get("battle_v2_ended", false)):
		labels.append("enemy_logic_battle_ended_block")
		return {
			"status": "failed",
			"reason": "battle already ended",
			"labels": labels
		}

	if update_package.has("battle_active") and not bool(update_package.get("battle_active", true)):
		labels.append("enemy_logic_battle_inactive_block")
		return {
			"status": "failed",
			"reason": "battle is not active",
			"labels": labels
		}

	var battle_manager = update_package.get("battle_manager", null)
	if battle_manager != null and not _battle_manager_allows_intent(battle_manager):
		labels.append("enemy_logic_battle_manager_inactive_block")
		return {
			"status": "failed",
			"reason": "battle manager is not active",
			"labels": labels
		}

	var enemy = update_package.get("enemy", null)
	if not _enemy_can_act(enemy):
		labels.append("enemy_logic_enemy_inactive_block")
		return {
			"status": "failed",
			"reason": "enemy cannot act",
			"labels": labels
		}

	var player_state = update_package.get("player_state", null)
	if not _target_can_be_targeted(player_state):
		labels.append("enemy_logic_target_inactive_block")
		return {
			"status": "failed",
			"reason": "target cannot be attacked",
			"labels": labels
		}

	return {
		"status": "success",
		"reason": "",
		"labels": labels
	}


func _finalize_full_loop_intent(intent_packet: Dictionary, update_package: Dictionary, profile_id: String) -> Dictionary:
	# Summary: Validate selected intent shape and attach simple repeat tracking for full-loop play.
	var safety_result: Dictionary = _validate_full_loop_context(update_package)
	if str(safety_result.get("status", "")) != "success":
		return _intent_none(str(safety_result.get("reason", "enemy loop safety blocked intent")), safety_result.get("labels", []))

	var intent_id := str(intent_packet.get("intent_id", "")).strip_edges().to_lower()
	if intent_id == "":
		return _intent_none(
			"missing enemy intent id",
			[
				"enemy_intent_none",
				"enemy_logic_full_loop_safety_check",
				"enemy_logic_invalid_intent_block"
			]
		)

	if not _is_supported_loop_intent(intent_id):
		return _intent_none(
			"unsupported enemy intent id: " + intent_id,
			[
				"enemy_intent_none",
				"enemy_logic_full_loop_safety_check",
				"enemy_logic_invalid_intent_block"
			]
		)

	_append_intent_label(intent_packet, "enemy_logic_full_loop_safety_check")
	_append_intent_label(intent_packet, "enemy_logic_simple_repeat_behavior")
	_append_intent_label(intent_packet, "enemy_logic_no_resolution")

	var enemy = update_package.get("enemy", intent_packet.get("source_unit", null))
	if intent_id == "enemy_evade":
		var evade_cooldown_result: Dictionary = _check_enemy_evade_cooldown(enemy)
		if str(evade_cooldown_result.get("status", "")) != "success":
			return _intent_none(
				str(evade_cooldown_result.get("reason", "enemy evade cooldown active")),
				evade_cooldown_result.get("labels", [])
			)
		_append_intent_label(intent_packet, "enemy_evade_min_cooldown")
		_append_intent_label(intent_packet, "enemy_evade_cooldown_ready")

	var repeat_data: Dictionary = _track_repeat_intent(enemy, intent_id)
	if int(repeat_data.get("same_intent_repeat_count", 0)) > 1:
		_append_intent_label(intent_packet, "enemy_intent_repeated")

	var data = intent_packet.get("data", {})
	if typeof(data) != TYPE_DICTIONARY:
		data = {}
	data["behavior_profile"] = profile_id
	data["last_intent_id"] = repeat_data.get("last_intent_id", "")
	data["same_intent_repeat_count"] = repeat_data.get("same_intent_repeat_count", 1)
	data["enemy_logic_key"] = repeat_data.get("enemy_logic_key", "")
	intent_packet["data"] = data

	return intent_packet


func _check_enemy_evade_cooldown(enemy) -> Dictionary:
	# Summary: Block repeat enemy evade intents until the minimum cooldown has passed.
	var enemy_key := _get_enemy_logic_key(enemy)
	var labels := [
		"enemy_logic_full_loop_safety_check",
		"enemy_evade_min_cooldown"
	]
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = int(last_evade_msec_by_enemy_key.get(enemy_key, -1))

	if last_msec < 0:
		return {
			"status": "success",
			"reason": "",
			"labels": labels,
			"enemy_logic_key": enemy_key
		}

	var elapsed_seconds: float = float(now_msec - last_msec) / 1000.0
	if elapsed_seconds < enemy_evade_min_cooldown_seconds:
		labels.append("enemy_evade_cooldown_active")
		return {
			"status": "failed",
			"reason": "enemy evade cooldown active",
			"labels": labels,
			"enemy_logic_key": enemy_key,
			"cooldown_remaining": enemy_evade_min_cooldown_seconds - elapsed_seconds
		}

	return {
		"status": "success",
		"reason": "",
		"labels": labels,
		"enemy_logic_key": enemy_key
	}


func _mark_enemy_evade_cooldown(enemy) -> void:
	# Summary: Record when an enemy successfully chooses an evade intent.
	var enemy_key := _get_enemy_logic_key(enemy)
	last_evade_msec_by_enemy_key[enemy_key] = Time.get_ticks_msec()


func mark_enemy_evade_completed(enemy) -> void:
	# Summary: Let the scene restart the EnemyLogic evade cooldown when the evade TODO completes.
	_mark_enemy_evade_cooldown(enemy)


func _is_supported_loop_intent(intent_id: String) -> bool:
	# Summary: Keep malformed behavior returns from entering PacketBuilder/EventManager.
	if FULL_LOOP_SAFE_INTENTS.has(intent_id):
		return true
	return intent_id.begins_with("enemy_signal")


func _track_repeat_intent(enemy, intent_id: String) -> Dictionary:
	# Summary: Remember the last intent per enemy so simple repeat behavior is traceable.
	var enemy_key := _get_enemy_logic_key(enemy)
	var previous_intent := str(last_intent_by_enemy_key.get(enemy_key, ""))
	var repeat_count := 1

	if previous_intent == intent_id:
		repeat_count = min(int(repeat_count_by_enemy_key.get(enemy_key, 1)) + 1, MAX_TRACKED_REPEAT_COUNT)

	last_intent_by_enemy_key[enemy_key] = intent_id
	repeat_count_by_enemy_key[enemy_key] = repeat_count

	return {
		"enemy_logic_key": enemy_key,
		"last_intent_id": previous_intent,
		"same_intent_repeat_count": repeat_count
	}


func _get_enemy_logic_key(enemy) -> String:
	# Summary: Build a stable-enough repeat key for dictionaries, adapters, and test packets.
	if enemy == null:
		return "enemy_null"

	var unit_id = _unit_value(enemy, "unit_id", null)
	if unit_id != null and str(unit_id).strip_edges() != "":
		return str(unit_id).strip_edges()

	var enemy_id = _unit_value(enemy, "enemy_id", null)
	if enemy_id != null and str(enemy_id).strip_edges() != "":
		return str(enemy_id).strip_edges()

	var display_name = _unit_value(enemy, "display_name", null)
	if display_name != null and str(display_name).strip_edges() != "":
		return str(display_name).strip_edges()

	return str(enemy)


func _battle_manager_allows_intent(battle_manager) -> bool:
	# Summary: Read BattleManager active/end flags without asking it to resolve anything.
	if battle_manager == null:
		return true

	if _unit_bool_value(battle_manager, "battle_ended", false):
		return false
	if _unit_bool_value(battle_manager, "battle_v2_ended", false):
		return false
	if _unit_value(battle_manager, "battle_active", null) != null and not _unit_bool_value(battle_manager, "battle_active", true):
		return false

	return true


func _target_can_be_targeted(player_state) -> bool:
	# Summary: Check whether the player target is still present and above zero hull.
	if player_state == null:
		return false

	if _unit_bool_value(player_state, "destroyed", false) or _unit_bool_value(player_state, "is_destroyed", false):
		return false
	if _unit_bool_value(player_state, "inactive", false) or not _unit_bool_value(player_state, "is_active", true):
		return false

	var status := str(_unit_value(player_state, "status", "active")).strip_edges().to_lower()
	if status == "dead" or status == "destroyed" or status == "inactive":
		return false

	var hull_max := _unit_hull_max(player_state, "player")
	var hull_current := _unit_hull_current(player_state, "player", hull_max)
	if hull_max > 0.0 and hull_current <= 0.0:
		return false

	return true


func _get_behavior_values(enemy) -> Dictionary:
	# Summary: Read the enemy behavior values dictionary with a safe empty fallback.
	var values = _unit_value(enemy, "behavior_values", {})
	if typeof(values) == TYPE_DICTIONARY:
		return values
	return {}


func _append_intent_label(intent_packet: Dictionary, label_id: String) -> void:
	# Summary: Add a label to an intent packet if the packet does not already contain it.
	if label_id.strip_edges() == "":
		return

	# Make sure malformed or minimal packets still receive a label array.
	var labels = intent_packet.get("labels", [])
	if typeof(labels) != TYPE_ARRAY:
		labels = []

	if not labels.has(label_id):
		labels.append(label_id)

	intent_packet["labels"] = labels


func _unit_set_value(unit, key: String, value) -> bool:
	# Summary: Best-effort write helper for primitive scripted enemy behavior state.
	if unit == null:
		return false
	if typeof(unit) == TYPE_DICTIONARY:
		unit[key] = value
		return true
	if unit is Object:
		unit.set(key, value)
		return true
	return false


func _unit_has_method(unit, method_name: String) -> bool:
	# Summary: Check whether a unit object exposes the requested method.
	if unit == null:
		return false
	if not (unit is Object):
		return false
	return unit.has_method(method_name)


func _unit_value(unit, key: String, fallback = null):
	# Summary: Read a value from either a Dictionary packet or an Object property with a fallback.
	if unit == null:
		return fallback

	# Dictionary packets are the preferred test/update shape.
	if typeof(unit) == TYPE_DICTIONARY:
		return unit.get(key, fallback)

	# Object-based units can expose matching properties.
	if unit is Object:
		var value = unit.get(key)
		if value == null:
			return fallback
		return value

	return fallback


func _unit_bool_value(unit, key: String, fallback: bool) -> bool:
	# Summary: Read a boolean-like value from a Dictionary or Object unit packet.
	var raw_value = _unit_value(unit, key, fallback)

	# Preserve real booleans as-is.
	if typeof(raw_value) == TYPE_BOOL:
		return raw_value

	# Numbers treat zero as false and non-zero as true.
	if typeof(raw_value) == TYPE_INT or typeof(raw_value) == TYPE_FLOAT:
		return float(raw_value) != 0.0

	# Strings support common true/false test values.
	if typeof(raw_value) == TYPE_STRING:
		var raw_text := str(raw_value).strip_edges().to_lower()
		if raw_text == "true" or raw_text == "yes" or raw_text == "1":
			return true
		if raw_text == "false" or raw_text == "no" or raw_text == "0":
			return false

	return fallback


func _unit_float_value(unit, key: String, fallback: float) -> float:
	# Summary: Read a numeric-like value from a Dictionary or Object unit packet.
	var raw_value = _unit_value(unit, key, fallback)

	# Numeric fields are returned directly as floats.
	if typeof(raw_value) == TYPE_INT or typeof(raw_value) == TYPE_FLOAT:
		return float(raw_value)

	# Strings are useful in hand-built test packets and debug widgets.
	if typeof(raw_value) == TYPE_STRING:
		var raw_text := str(raw_value).strip_edges()
		if raw_text != "":
			return raw_text.to_float()

	return fallback


func _unit_hull_current(unit, side_hint: String, fallback: float = 0.0) -> float:
	# Summary: Read hull current from side-specific Battle V2 adapters, generic packets, or legacy hp fields.
	if unit == null:
		return fallback

	if _unit_has_method(unit, "get_hull_current"):
		return float(unit.call("get_hull_current"))

	if side_hint == "enemy":
		return _unit_float_value(unit, "enemy_hull_current", _unit_float_value(unit, "hull_current", _unit_float_value(unit, "hp", fallback)))
	if side_hint == "player":
		return _unit_float_value(unit, "player_hull_current", _unit_float_value(unit, "hull_current", _unit_float_value(unit, "hp", fallback)))

	return _unit_float_value(unit, "hull_current", _unit_float_value(unit, "hp", fallback))


func _unit_hull_max(unit, side_hint: String, fallback: float = 1.0) -> float:
	# Summary: Read hull max from side-specific Battle V2 adapters, generic packets, or legacy hp fields.
	if unit == null:
		return fallback

	if _unit_has_method(unit, "get_hull_max"):
		return float(unit.call("get_hull_max"))

	if side_hint == "enemy":
		return _unit_float_value(unit, "enemy_hull_max", _unit_float_value(unit, "hull_max", _unit_float_value(unit, "max_hp", fallback)))
	if side_hint == "player":
		return _unit_float_value(unit, "player_hull_max", _unit_float_value(unit, "hull_max", _unit_float_value(unit, "max_hp", fallback)))

	return _unit_float_value(unit, "hull_max", _unit_float_value(unit, "max_hp", fallback))
