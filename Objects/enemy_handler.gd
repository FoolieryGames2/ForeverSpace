extends Node
class_name EnemyHandler





# ==========================================================
# STORAGE
# ==========================================================
var enemies : Array[Enemy] = []
var enemy_intel_handler = null


func set_enemy_intel_handler(handler) -> void:
	enemy_intel_handler = handler


func get_enemy_intel_handler():
	return enemy_intel_handler


func build_enemy_intel_source(enemy_ref: Enemy, source_packet: Dictionary = {}) -> Dictionary:
	var source := source_packet.duplicate(true)
	if enemy_ref == null:
		return source

	source["source"] = str(source.get("source", "EnemyHandler"))
	source["object_id"] = str(source.get("object_id", enemy_ref.object_id))
	source["enemy_id"] = str(source.get("enemy_id", enemy_ref.object_id))
	source["display_name"] = str(source.get("display_name", enemy_ref.display_name if enemy_ref.display_name.strip_edges() != "" else enemy_ref.enemy_name))
	source["enemy_name"] = str(source.get("enemy_name", enemy_ref.enemy_name))
	source["enemy_type"] = str(source.get("enemy_type", enemy_ref.enemy_type))
	source["type"] = str(source.get("type", enemy_ref.enemy_type))
	source["sector_pos"] = source.get("sector_pos", enemy_ref.sector_pos)
	source["local_pos"] = source.get("local_pos", enemy_ref.local_pos)
	source["has_event"] = bool(source.get("has_event", enemy_ref.has_event))
	source["events"] = source.get("events", enemy_ref.events.duplicate(true))
	source["event_tags"] = source.get("event_tags", enemy_ref.event_tags.duplicate(true))
	source["labels"] = source.get("labels", enemy_ref.labels.duplicate(true))
	source["enemy_serial"] = str(source.get("enemy_serial", enemy_ref.enemy_serial))
	source["enemy_template_id"] = str(source.get("enemy_template_id", enemy_ref.enemy_template_id))
	source["shared_meta"] = source.get("shared_meta", enemy_ref.shared_meta.duplicate(true))
	return source


func register_enemy_intel(enemy_ref: Enemy, source_packet: Dictionary = {}) -> String:
	if enemy_ref == null:
		return ""
	if enemy_intel_handler == null or not enemy_intel_handler.has_method("register_enemy_spawned"):
		return enemy_ref.enemy_serial

	var source := build_enemy_intel_source(enemy_ref, source_packet)
	var result = enemy_intel_handler.register_enemy_spawned(enemy_ref, source)
	if typeof(result) == TYPE_DICTIONARY:
		return str(result.get("enemy_serial", enemy_ref.enemy_serial))
	return enemy_ref.enemy_serial

# ==========================================================
# ENEMY BLUEPRINT DATABASE
# ----------------------------------------------------------
# Enemy.gd is only the data object.
# EnemyHandler owns the enemy creation rules.
# ==========================================================
func get_enemy_blueprints() -> Dictionary:
	# Summary: Returns the handler-owned enemy blueprint database used for enemy creation.
	if Globals.print_priority_3:
		print("EnemyHandler.get_enemy_blueprints | Returning enemy blueprint database.")

	# Keep blueprint data in the handler so Enemy.gd stays a clean unit/state object.
	return {
	"scout_drone": {
			"name": "Scout Drone",
			"type": "drone",
			"energy_max": 100.0,
			"tier": 1,
			"reward": ["iron", "cobalt", "nickel"],
			"primary": "e_basic_energy_pew_pew",
			"secondary": "micro_torpedo_launcher",
			"shield": "basic_shield_mk1",
			"consumable": "repair_kit",
			"item_stacks": {
				"small_kinetic_rounds": 8,
				"medium_kinetic_rounds": 6,
				"large_kinetic_rounds": 1,
				"repair_kit": 1
			},
			"behavior_profile": "raider_survivor",
			"behavior_values": {
				"repair_hull_threshold": 0.55,
				"low_hull_evade_threshold": 0.35
			},
			"battle_comment": ["No were to run", "we have you now"],
			"ship_name": "Bomba Ring Grazer",
			"has_event": true,
			"events": [],
			"event_tags": [],
			"hp_min": 150,
			"hp_max": 300,
			"attack_min": 5,
			"attack_max": 15,
			"cooldown_min": 3.0,
			"cooldown_max": 6.0
		},
		
		"tier_1_smart_guy_boss": {
			"name": "Smart GUy 2",
			"type": "killa",
			"energy_max": 100.0,
			"tier": 1,
			"reward": ["iron", "cobalt", "nickel"],
			"primary": "e_basic_energy_pew_pew",
			"secondary": "railgun_mk1",
			"shield": "basic_shield_mk1",
			"consumable": "breach_charge",
			"item_stacks": {
				"small_kinetic_rounds": 8,
				"medium_kinetic_rounds": 9,
				"large_kinetic_rounds": 2,
				"repair_kit": 1,
				"breach_charge": 1
			},
			"behavior_profile": "raider_tactician",
			"behavior_values": {
				"repair_hull_threshold": 0.30,
				"explosive_player_threshold": 0.45
			},
		"raider_drone": {
			"name": "Raider Drone",
			"type": "drone",
			"energy_max": 100.0,
			"tier": 1,
			"reward": ["iron", "cobalt", "nickel"],
			"primary": "e_basic_energy_pew_pew",
			"secondary": "railgun_mk1",
			"shield": "basic_shield_mk1",
			"consumable": "breach_charge",
			"item_stacks": {
				"small_kinetic_rounds": 8,
				"medium_kinetic_rounds": 9,
				"large_kinetic_rounds": 2,
				"repair_kit": 1,
				"breach_charge": 1
			},
			"behavior_profile": "raider_tactician",
			"behavior_values": {
				"repair_hull_threshold": 0.30,
				"explosive_player_threshold": 0.45
			},
			"battle_comment": ["No were to run", "we have you now"],
			"ship_name": "Bomba Ring Grazer",
			"has_event": true,
			"events": [],
			"event_tags": [],
			"hp_min": 250,
			"hp_max": 450,
			"attack_min": 12,
			"attack_max": 25,
			"cooldown_min": 3.5,
			"cooldown_max": 7.0
		},

		"guardian_probe": {
			"name": "Guardian Probe",
			"type": "probe",
			"energy_max": 100.0,
			"tier": 1,
			"reward": ["iron", "cobalt", "nickel"],
			"primary": "e_energy_pew_pew",
			"secondary": "micro_torpedo_launcher",
			"shield": "basic_shield_mk1",
			"consumable": "buster_charge",
			"item_stacks": {
				"small_kinetic_rounds": 10,
				"medium_kinetic_rounds": 4,
				"large_kinetic_rounds": 1,
				"buster_charge": 1
			},
			"behavior_profile": "raider_bomber",
			"behavior_values": {
				"explosive_player_threshold": 0.90
			},
			"battle_comment": ["No were to run", "we have you now"],
			"ship_name": "Bomba Ring Grazer",
			"has_event": true,
			"events": [],
			"event_tags": [],
			"hp_min": 100,
			"hp_max": 150,
			"attack_min": 18,
			"attack_max": 35,
			"cooldown_min": 4.0,
			"cooldown_max": 8.0
		},

		"test_smart_guy": {
			"name": "Smart Guy Signal Guardian",
			"type": "smart_test_drone",
			"energy_max": 5000.0,
			"tier": 1,
			"reward": ["iron", "cobalt", "smart_guy_calculated_rounds"],
			"primary": "smart_guy_focus_lance",
			"secondary": "smart_guy_calculated_rail",
			"shield": "smart_guy_mirror_shield",
			"consumable": "smart_guy_patch_cell",
			"item_stacks": {
				"smart_guy_calculated_rounds": 18,
				"smart_guy_patch_cell": 1
			},
			"behavior_profile": "smart_guy",
			"behavior_values": {
				"execute_player_threshold": 0.28,
				"critical_hull_evade_threshold": 0.22,
				"low_hull_evade_threshold": 0.45,
				"low_energy_secondary_threshold": 0.35,
				"decision_cooldown": 1.25
			},
			"battle_comment": [
				"I calculated twelve endings. You dislike eleven.",
				"Your angle is brave. Not correct. Brave.",
				"Please hold still while I improve the odds."
			],
			"ship_name": "The Correct Answer",
			"has_event": true,
			"events": [],
			"event_tags": ["event_guardian", "smart_guy"],
			"hp_min": 160,
			"hp_max": 160,
			"attack_min": 12,
			"attack_max": 12,
			"cooldown_min": 3.0,
			"cooldown_max": 4.0
		},
		
	"vayrax_claim_drone_001": {
		"id": "vayrax_claim_drone_001",
		"name": "Vayrax Claim Drone",
		"display_name": "Vayrax Claim Drone",
		"ship_name": "Vayrax Claim Drone",
		"type": "vayrax_claim_drone",
		"faction": "vayrax",
		"tier": 1,
		"energy_max": 130.0,
		"max_energy": 130,
		"energy": 130,
		"primary": "e_basic_energy_pew_pew",
		"primary_weapon": "e_basic_energy_pew_pew",
		"secondary": "railgun_mk1",
		"secondary_weapon": "railgun_mk1",
		"shield": "basic_shield_mk1",
		"shield_item": "basic_shield_mk1",
		"consumable": "repair_kit",
		"consumable_item": "repair_kit",
		"item_stacks": {
			"medium_kinetic_rounds": 4,
			"repair_kit": 1
		},
		"behavior_profile": "smart_guy_3",
		"behavior_values": {
			"decision_cooldown": 1.75,
			"low_hull_evade_threshold": 0.25,
			"repair_hull_threshold": 0.30,
			"explosive_player_threshold": 0.45
		},
		"battle_comment": [
			"Unauthorized vessel detected.",
			"Remain where you are.",
			"I will now destroy you.",
			"Comply."
		],
		"reward": ["iron", "nickel"],
		"reward_items": ["iron", "nickel"],
		"has_event": true,
		"events": [],
		"event_tags": ["tutorial_battle", "vayrax", "claim_drone"],
		"hp_min": 95,
		"hp_max": 95,
		"max_hull": 95,
		"hull": 95,
		"attack_min": 7,
		"attack_max": 7,
		"attack_power": 7,
		"cooldown_min": 3.5,
		"cooldown_max": 4.5
	},
	"vayrax_raider": {
		"id": "vayrax_raider",
		"name": "Vayrax Raider",
		"display_name": "Vayrax Raider",
		"ship_name": "Vayrax Raider",
		"type": "vayrax_raider",
		"faction": "vayrax",
		"tier": 1,
		"energy_max": 220.0,
		"max_energy": 220,
		"energy": 220,
		"primary": "vayrax_needler_lance_mk1",
		"primary_weapon": "vayrax_needler_lance_mk1",
		"secondary": "vayrax_splitter_rail_mk1",
		"secondary_weapon": "vayrax_splitter_rail_mk1",
		"shield": "vayrax_flicker_screen_mk1",
		"shield_item": "vayrax_flicker_screen_mk1",
		"consumable": "vayrax_hull_knit_cell_mk1",
		"consumable_item": "vayrax_hull_knit_cell_mk1",
		"item_stacks": {
			"small_kinetic_rounds": 12,
			"medium_kinetic_rounds": 4,
			"vayrax_hull_knit_cell_mk1": 1
		},
		"behavior_profile": "smart_guy_balanced",
		"behavior_values": {
			"decision_cooldown": 1.55,
			"low_hull_evade_threshold": 0.28,
			"repair_hull_threshold": 0.34,
			"low_energy_secondary_threshold": 0.30
		},
		"battle_comment": [
			"Relic claim remains active.",
			"Vayrax raider pattern repeats.",
			"Your recovery attempt is unauthorized."
		],
		"reward": ["iron", "cobalt", "small_kinetic_rounds"],
		"reward_items": ["iron", "cobalt", "small_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_raider", "moonpie_raider"],
		"hp_min": 210,
		"hp_max": 210,
		"max_hull": 210,
		"hull": 210,
		"attack_min": 16,
		"attack_max": 16,
		"attack_power": 16,
		"cooldown_min": 3.25,
		"cooldown_max": 4.15
	},
	"vayrax_drone_002": {
		"id": "vayrax_drone_002",
		"name": "Vayrax Drone 002",
		"display_name": "Vayrax Drone 002",
		"ship_name": "Vayrax Drone 002",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 1,
		"energy_max": 180.0,
		"max_energy": 180,
		"energy": 180,
		"primary": "pulse_laser_mk1",
		"primary_weapon": "pulse_laser_mk1",
		"secondary": "railgun_mk1",
		"secondary_weapon": "railgun_mk1",
		"shield": "",
		"shield_item": "",
		"consumable": "",
		"consumable_item": "",
		"item_stacks": {
			"small_kinetic_rounds": 8,
			"medium_kinetic_rounds": 3
		},
		"behavior_profile": "smart_guy_balanced",
		"behavior_values": {
			"decision_cooldown": 1.70,
			"low_hull_evade_threshold": 0.25,
			"repair_hull_threshold": 0.30
		},
		"battle_comment": [
			"Claim pattern extended.",
			"Second contact will be cleaner.",
			"Your hull teaches slowly."
		],
		"reward": ["iron", "small_kinetic_rounds"],
		"reward_items": ["iron", "small_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_002"],
		"hp_min": 180,
		"hp_max": 180,
		"max_hull": 180,
		"hull": 180,
		"attack_min": 14,
		"attack_max": 14,
		"attack_power": 14,
		"cooldown_min": 3.45,
		"cooldown_max": 4.35
	},
	"vayrax_drone_003": {
		"id": "vayrax_drone_003",
		"name": "Vayrax Drone 003",
		"display_name": "Vayrax Drone 003",
		"ship_name": "Vayrax Drone 003",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 1,
		"energy_max": 190.0,
		"max_energy": 190,
		"energy": 190,
		"primary": "pulse_laser_mk1",
		"primary_weapon": "pulse_laser_mk1",
		"secondary": "railgun_mk1",
		"secondary_weapon": "railgun_mk1",
		"shield": "basic_shield_mk1",
		"shield_item": "basic_shield_mk1",
		"consumable": "repair_kit",
		"consumable_item": "repair_kit",
		"item_stacks": {
			"small_kinetic_rounds": 10,
			"medium_kinetic_rounds": 4,
			"repair_kit": 1
		},
		"behavior_profile": "smart_guy_3",
		"behavior_values": {
			"decision_cooldown": 1.68,
			"low_hull_evade_threshold": 0.26,
			"repair_hull_threshold": 0.31,
			"low_energy_secondary_threshold": 0.30
		},
		"battle_comment": [
			"Third contact confirms resistance.",
			"Indexing your damage habits.",
			"Compliance remains available."
		],
		"reward": ["iron", "nickel", "small_kinetic_rounds"],
		"reward_items": ["iron", "nickel", "small_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_003"],
		"hp_min": 200,
		"hp_max": 200,
		"max_hull": 200,
		"hull": 200,
		"attack_min": 16,
		"attack_max": 16,
		"attack_power": 16,
		"cooldown_min": 3.40,
		"cooldown_max": 4.30
	},
	"vayrax_drone_004": {
		"id": "vayrax_drone_004",
		"name": "Vayrax Drone 004",
		"display_name": "Vayrax Drone 004",
		"ship_name": "Vayrax Drone 004",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 1,
		"energy_max": 205.0,
		"max_energy": 205,
		"energy": 205,
		"primary": "vayrax_needler_lance_mk1",
		"primary_weapon": "vayrax_needler_lance_mk1",
		"secondary": "vayrax_splitter_rail_mk1",
		"secondary_weapon": "vayrax_splitter_rail_mk1",
		"shield": "vayrax_flicker_screen_mk1",
		"shield_item": "vayrax_flicker_screen_mk1",
		"consumable": "repair_kit",
		"consumable_item": "repair_kit",
		"item_stacks": {
			"small_kinetic_rounds": 10,
			"repair_kit": 1
		},
		"behavior_profile": "smart_guy_balanced",
		"behavior_values": {
			"decision_cooldown": 1.65,
			"low_hull_evade_threshold": 0.28,
			"repair_hull_threshold": 0.32,
			"low_energy_secondary_threshold": 0.28
		},
		"battle_comment": [
			"Vayrax sequence four: correction begins.",
			"Hold still for clean indexing.",
			"Your signal is louder than your armor."
		],
		"reward": ["iron", "nickel", "small_kinetic_rounds"],
		"reward_items": ["iron", "nickel", "small_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_004"],
		"hp_min": 215,
		"hp_max": 215,
		"max_hull": 215,
		"hull": 215,
		"attack_min": 17,
		"attack_max": 17,
		"attack_power": 17,
		"cooldown_min": 3.35,
		"cooldown_max": 4.25
	},
	"vayrax_drone_005": {
		"id": "vayrax_drone_005",
		"name": "Vayrax Drone 005",
		"display_name": "Vayrax Drone 005",
		"ship_name": "Vayrax Drone 005",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 1,
		"energy_max": 225.0,
		"max_energy": 225,
		"energy": 225,
		"primary": "vayrax_needler_lance_mk1",
		"primary_weapon": "vayrax_needler_lance_mk1",
		"secondary": "raider_scrap_ripper_mk2",
		"secondary_weapon": "raider_scrap_ripper_mk2",
		"shield": "vayrax_flicker_screen_mk1",
		"shield_item": "vayrax_flicker_screen_mk1",
		"consumable": "recharge_kit",
		"consumable_item": "recharge_kit",
		"item_stacks": {
			"small_kinetic_rounds": 14,
			"recharge_kit": 1
		},
		"behavior_profile": "smart_guy_pressure",
		"behavior_values": {
			"decision_cooldown": 1.50,
			"low_hull_evade_threshold": 0.24,
			"low_energy_secondary_threshold": 0.38,
			"execute_player_threshold": 0.42
		},
		"battle_comment": [
			"Pressure pattern accepted.",
			"Your retreat vector has been reserved.",
			"Vayrax sequence five: close distance."
		],
		"reward": ["iron", "nickel", "small_kinetic_rounds"],
		"reward_items": ["iron", "nickel", "small_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_005"],
		"hp_min": 235,
		"hp_max": 235,
		"max_hull": 235,
		"hull": 235,
		"attack_min": 19,
		"attack_max": 19,
		"attack_power": 19,
		"cooldown_min": 3.25,
		"cooldown_max": 4.15
	},
	"vayrax_drone_006": {
		"id": "vayrax_drone_006",
		"name": "Vayrax Drone 006",
		"display_name": "Vayrax Drone 006",
		"ship_name": "Vayrax Drone 006",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 1,
		"energy_max": 250.0,
		"max_energy": 250,
		"energy": 250,
		"primary": "raider_arc_stinger_mk2",
		"primary_weapon": "raider_arc_stinger_mk2",
		"secondary": "vayrax_splitter_rail_mk1",
		"secondary_weapon": "vayrax_splitter_rail_mk1",
		"shield": "raider_plate_screen_mk2",
		"shield_item": "raider_plate_screen_mk2",
		"consumable": "repair_kit",
		"consumable_item": "repair_kit",
		"item_stacks": {
			"small_kinetic_rounds": 16,
			"medium_kinetic_rounds": 4,
			"repair_kit": 1
		},
		"behavior_profile": "smart_guy_survivor",
		"behavior_values": {
			"decision_cooldown": 1.45,
			"low_hull_evade_threshold": 0.36,
			"critical_hull_evade_threshold": 0.20,
			"repair_hull_threshold": 0.45,
			"shield_hull_threshold": 0.50
		},
		"battle_comment": [
			"Damage accepted. Adapting.",
			"The sixth shell does not break first.",
			"Survival routine has priority."
		],
		"reward": ["iron", "cobalt", "small_kinetic_rounds"],
		"reward_items": ["iron", "cobalt", "small_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_006"],
		"hp_min": 260,
		"hp_max": 260,
		"max_hull": 260,
		"hull": 260,
		"attack_min": 21,
		"attack_max": 21,
		"attack_power": 21,
		"cooldown_min": 3.15,
		"cooldown_max": 4.05
	},
	"vayrax_drone_007": {
		"id": "vayrax_drone_007",
		"name": "Vayrax Drone 007",
		"display_name": "Vayrax Drone 007",
		"ship_name": "Vayrax Drone 007",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 1,
		"energy_max": 275.0,
		"max_energy": 275,
		"energy": 275,
		"primary": "raider_arc_stinger_mk2",
		"primary_weapon": "raider_arc_stinger_mk2",
		"secondary": "raider_scrap_ripper_mk2",
		"secondary_weapon": "raider_scrap_ripper_mk2",
		"shield": "raider_plate_screen_mk2",
		"shield_item": "raider_plate_screen_mk2",
		"consumable": "repair_kit",
		"consumable_item": "repair_kit",
		"item_stacks": {
			"small_kinetic_rounds": 18,
			"medium_kinetic_rounds": 6,
			"repair_kit": 1
		},
		"behavior_profile": "smart_guy_tactician",
		"behavior_values": {
			"decision_cooldown": 1.25,
			"low_hull_evade_threshold": 0.30,
			"repair_hull_threshold": 0.34,
			"shield_switch_min_cooldown_seconds": 9.0,
			"low_energy_secondary_threshold": 0.42
		},
		"battle_comment": [
			"Pattern seven: feint, punish, repeat.",
			"You are teaching me useful things.",
			"Your next mistake is already highlighted."
		],
		"reward": ["iron", "cobalt", "medium_kinetic_rounds"],
		"reward_items": ["iron", "cobalt", "medium_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_007"],
		"hp_min": 285,
		"hp_max": 285,
		"max_hull": 285,
		"hull": 285,
		"attack_min": 23,
		"attack_max": 23,
		"attack_power": 23,
		"cooldown_min": 3.05,
		"cooldown_max": 3.95
	},
	"vayrax_drone_008": {
		"id": "vayrax_drone_008",
		"name": "Vayrax Drone 008",
		"display_name": "Vayrax Drone 008",
		"ship_name": "Vayrax Drone 008",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 1,
		"energy_max": 305.0,
		"max_energy": 305,
		"energy": 305,
		"primary": "raider_arc_stinger_mk2",
		"primary_weapon": "raider_arc_stinger_mk2",
		"secondary": "vayrax_puncture_charge_mk1",
		"secondary_weapon": "vayrax_puncture_charge_mk1",
		"shield": "raider_plate_screen_mk2",
		"shield_item": "raider_plate_screen_mk2",
		"consumable": "repair_kit",
		"consumable_item": "repair_kit",
		"item_stacks": {
			"large_kinetic_rounds": 3,
			"medium_kinetic_rounds": 8,
			"repair_kit": 1
		},
		"behavior_profile": "smart_guy_bomber",
		"behavior_values": {
			"decision_cooldown": 1.20,
			"low_hull_evade_threshold": 0.26,
			"repair_hull_threshold": 0.30,
			"explosive_player_threshold": 0.62,
			"execute_player_threshold": 0.48
		},
		"battle_comment": [
			"Eight carries the loud answer.",
			"Stand inside the bracket.",
			"Impact solution loaded."
		],
		"reward": ["iron", "cobalt", "large_kinetic_rounds"],
		"reward_items": ["iron", "cobalt", "large_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_008"],
		"hp_min": 315,
		"hp_max": 315,
		"max_hull": 315,
		"hull": 315,
		"attack_min": 26,
		"attack_max": 26,
		"attack_power": 26,
		"cooldown_min": 2.95,
		"cooldown_max": 3.85
	},
	"vayrax_drone_009": {
		"id": "vayrax_drone_009",
		"name": "Vayrax Drone 009",
		"display_name": "Vayrax Drone 009",
		"ship_name": "Vayrax Drone 009",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 2,
		"energy_max": 335.0,
		"max_energy": 335,
		"energy": 335,
		"primary": "raider_arc_stinger_mk2",
		"primary_weapon": "raider_arc_stinger_mk2",
		"secondary": "vayrax_puncture_charge_mk1",
		"secondary_weapon": "vayrax_puncture_charge_mk1",
		"shield": "raider_plate_screen_mk2",
		"shield_item": "raider_plate_screen_mk2",
		"consumable": "recharge_kit",
		"consumable_item": "recharge_kit",
		"item_stacks": {
			"large_kinetic_rounds": 4,
			"medium_kinetic_rounds": 8,
			"recharge_kit": 1
		},
		"behavior_profile": "smart_guy_balanced",
		"behavior_values": {
			"decision_cooldown": 1.18,
			"low_hull_evade_threshold": 0.27,
			"repair_hull_threshold": 0.31,
			"recharge_energy_threshold": 0.32
		},
		"battle_comment": [
			"Nine balances threat against waste.",
			"Your motion has become a number.",
			"Correction remains efficient."
		],
		"reward": ["iron", "cobalt", "large_kinetic_rounds"],
		"reward_items": ["iron", "cobalt", "large_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_009"],
		"hp_min": 345,
		"hp_max": 345,
		"max_hull": 345,
		"hull": 345,
		"attack_min": 28,
		"attack_max": 28,
		"attack_power": 28,
		"cooldown_min": 2.90,
		"cooldown_max": 3.80
	},
	"vayrax_drone_010": {
		"id": "vayrax_drone_010",
		"name": "Vayrax Drone 010",
		"display_name": "Vayrax Drone 010",
		"ship_name": "Vayrax Drone 010",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 2,
		"energy_max": 365.0,
		"max_energy": 365,
		"energy": 365,
		"primary": "raider_arc_stinger_mk2",
		"primary_weapon": "raider_arc_stinger_mk2",
		"secondary": "raider_scrap_ripper_mk2",
		"secondary_weapon": "raider_scrap_ripper_mk2",
		"shield": "raider_plate_screen_mk2",
		"shield_item": "raider_plate_screen_mk2",
		"consumable": "breach_charge",
		"consumable_item": "breach_charge",
		"item_stacks": {
			"small_kinetic_rounds": 22,
			"medium_kinetic_rounds": 8,
			"breach_charge": 1
		},
		"behavior_profile": "smart_guy_pressure",
		"behavior_values": {
			"decision_cooldown": 1.12,
			"low_hull_evade_threshold": 0.23,
			"low_energy_secondary_threshold": 0.40,
			"execute_player_threshold": 0.46
		},
		"battle_comment": [
			"Ten compresses the space between us.",
			"Pressure is not anger. It is math.",
			"You are inside the closing bracket."
		],
		"reward": ["cobalt", "nickel", "small_kinetic_rounds"],
		"reward_items": ["cobalt", "nickel", "small_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_010"],
		"hp_min": 375,
		"hp_max": 375,
		"max_hull": 375,
		"hull": 375,
		"attack_min": 30,
		"attack_max": 30,
		"attack_power": 30,
		"cooldown_min": 2.85,
		"cooldown_max": 3.75
	},
	"vayrax_drone_011": {
		"id": "vayrax_drone_011",
		"name": "Vayrax Drone 011",
		"display_name": "Vayrax Drone 011",
		"ship_name": "Vayrax Drone 011",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 2,
		"energy_max": 395.0,
		"max_energy": 395,
		"energy": 395,
		"primary": "raider_arc_stinger_mk2",
		"primary_weapon": "raider_arc_stinger_mk2",
		"secondary": "vayrax_puncture_charge_mk1",
		"secondary_weapon": "vayrax_puncture_charge_mk1",
		"shield": "raider_plate_screen_mk2",
		"shield_item": "raider_plate_screen_mk2",
		"consumable": "repair_kit",
		"consumable_item": "repair_kit",
		"item_stacks": {
			"large_kinetic_rounds": 5,
			"medium_kinetic_rounds": 10,
			"repair_kit": 1
		},
		"behavior_profile": "smart_guy_survivor",
		"behavior_values": {
			"decision_cooldown": 1.10,
			"low_hull_evade_threshold": 0.38,
			"critical_hull_evade_threshold": 0.22,
			"repair_hull_threshold": 0.47,
			"shield_hull_threshold": 0.52
		},
		"battle_comment": [
			"Eleven preserves the useful frame.",
			"Damage does not become permission.",
			"I remain operational by design."
		],
		"reward": ["iron", "cobalt", "medium_kinetic_rounds"],
		"reward_items": ["iron", "cobalt", "medium_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_011"],
		"hp_min": 410,
		"hp_max": 410,
		"max_hull": 410,
		"hull": 410,
		"attack_min": 32,
		"attack_max": 32,
		"attack_power": 32,
		"cooldown_min": 2.80,
		"cooldown_max": 3.70
	},
	"vayrax_drone_012": {
		"id": "vayrax_drone_012",
		"name": "Vayrax Drone 012",
		"display_name": "Vayrax Drone 012",
		"ship_name": "Vayrax Drone 012",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 2,
		"energy_max": 430.0,
		"max_energy": 430,
		"energy": 430,
		"primary": "guardian_suppression_beam_mk3",
		"primary_weapon": "guardian_suppression_beam_mk3",
		"secondary": "raider_scrap_ripper_mk2",
		"secondary_weapon": "raider_scrap_ripper_mk2",
		"shield": "raider_plate_screen_mk2",
		"shield_item": "raider_plate_screen_mk2",
		"consumable": "recharge_kit",
		"consumable_item": "recharge_kit",
		"item_stacks": {
			"small_kinetic_rounds": 24,
			"medium_kinetic_rounds": 10,
			"recharge_kit": 1
		},
		"behavior_profile": "smart_guy_tactician",
		"behavior_values": {
			"decision_cooldown": 1.08,
			"low_hull_evade_threshold": 0.31,
			"repair_hull_threshold": 0.36,
			"shield_switch_min_cooldown_seconds": 8.5,
			"low_energy_secondary_threshold": 0.44
		},
		"battle_comment": [
			"Twelve opens with an answer you have not earned.",
			"Observed. Ranked. Replied.",
			"Your pattern is now a tool."
		],
		"reward": ["cobalt", "nickel", "small_kinetic_rounds"],
		"reward_items": ["cobalt", "nickel", "small_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_012"],
		"hp_min": 445,
		"hp_max": 445,
		"max_hull": 445,
		"hull": 445,
		"attack_min": 34,
		"attack_max": 34,
		"attack_power": 34,
		"cooldown_min": 2.75,
		"cooldown_max": 3.65
	},
	"vayrax_drone_013": {
		"id": "vayrax_drone_013",
		"name": "Vayrax Drone 013",
		"display_name": "Vayrax Drone 013",
		"ship_name": "Vayrax Drone 013",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 2,
		"energy_max": 465.0,
		"max_energy": 465,
		"energy": 465,
		"primary": "guardian_suppression_beam_mk3",
		"primary_weapon": "guardian_suppression_beam_mk3",
		"secondary": "raider_spike_mortar_mk2",
		"secondary_weapon": "raider_spike_mortar_mk2",
		"shield": "raider_plate_screen_mk2",
		"shield_item": "raider_plate_screen_mk2",
		"consumable": "breach_charge",
		"consumable_item": "breach_charge",
		"item_stacks": {
			"large_kinetic_rounds": 6,
			"medium_kinetic_rounds": 10,
			"breach_charge": 1
		},
		"behavior_profile": "smart_guy_bomber",
		"behavior_values": {
			"decision_cooldown": 1.05,
			"low_hull_evade_threshold": 0.25,
			"repair_hull_threshold": 0.30,
			"explosive_player_threshold": 0.58,
			"execute_player_threshold": 0.50
		},
		"battle_comment": [
			"Thirteen carries an ugly proof.",
			"Distance will not make this gentle.",
			"Brace for translated certainty."
		],
		"reward": ["cobalt", "large_kinetic_rounds", "breach_charge"],
		"reward_items": ["cobalt", "large_kinetic_rounds", "breach_charge"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_013"],
		"hp_min": 485,
		"hp_max": 485,
		"max_hull": 485,
		"hull": 485,
		"attack_min": 37,
		"attack_max": 37,
		"attack_power": 37,
		"cooldown_min": 2.70,
		"cooldown_max": 3.55
	},
	"vayrax_drone_014": {
		"id": "vayrax_drone_014",
		"name": "Vayrax Drone 014",
		"display_name": "Vayrax Drone 014",
		"ship_name": "Vayrax Drone 014",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 2,
		"energy_max": 500.0,
		"max_energy": 500,
		"energy": 500,
		"primary": "guardian_suppression_beam_mk3",
		"primary_weapon": "guardian_suppression_beam_mk3",
		"secondary": "guardian_punch_driver_mk3",
		"secondary_weapon": "guardian_punch_driver_mk3",
		"shield": "raider_plate_screen_mk2",
		"shield_item": "raider_plate_screen_mk2",
		"consumable": "repair_kit",
		"consumable_item": "repair_kit",
		"item_stacks": {
			"medium_kinetic_rounds": 14,
			"large_kinetic_rounds": 5,
			"repair_kit": 1
		},
		"behavior_profile": "smart_guy_balanced",
		"behavior_values": {
			"decision_cooldown": 1.02,
			"low_hull_evade_threshold": 0.29,
			"repair_hull_threshold": 0.33,
			"recharge_energy_threshold": 0.30
		},
		"battle_comment": [
			"Fourteen does not rush. It arrives.",
			"Balance is just violence with patience.",
			"Your strongest choice has been noted."
		],
		"reward": ["iron", "cobalt", "medium_kinetic_rounds"],
		"reward_items": ["iron", "cobalt", "medium_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_014"],
		"hp_min": 525,
		"hp_max": 525,
		"max_hull": 525,
		"hull": 525,
		"attack_min": 40,
		"attack_max": 40,
		"attack_power": 40,
		"cooldown_min": 2.65,
		"cooldown_max": 3.50
	},
	"bleezzee_tier_2_boss": {
		"id": "bleezzee_tier_2_boss",
		"name": "Warden Bleezzee",
		"display_name": "Warden Bleezzee",
		"ship_name": "Warden Bleezzee",
		"type": "vayrax_warden",
		"faction": "vayrax",
		"tier": 2,
		"energy_max": 560.0,
		"max_energy": 560,
		"energy": 560,
		"primary": "raider_arc_stinger_mk2",
		"primary_weapon": "raider_arc_stinger_mk2",
		"secondary": "raider_spike_mortar_mk2",
		"secondary_weapon": "raider_spike_mortar_mk2",
		"shield": "raider_plate_screen_mk2",
		"shield_item": "raider_plate_screen_mk2",
		"consumable": "raider_hot_patch_canister_mk2",
		"consumable_item": "raider_hot_patch_canister_mk2",
		"item_stacks": {
			"small_kinetic_rounds": 28,
			"medium_kinetic_rounds": 18,
			"large_kinetic_rounds": 10,
			"raider_arc_stinger_mk2": 1,
			"raider_scrap_ripper_mk2": 1,
			"raider_spike_mortar_mk2": 1,
			"raider_plate_screen_mk2": 1,
			"raider_hot_patch_canister_mk2": 2
		},
		"behavior_profile": "smart_guy_3",
		"behavior_values": {
			"decision_cooldown": 0.92,
			"repair_hull_threshold": 0.58,
			"recharge_energy_threshold": 0.34,
			"low_energy_ammo_threshold": 0.48,
			"evade_health_threshold": 0.20,
			"low_hull_evade_threshold": 0.20,
			"critical_hull_evade_threshold": 0.16,
			"shield_repair_threshold": 0.62,
			"execute_player_threshold": 0.48,
			"explosive_player_threshold": 0.52,
			"clear_stale_loaded_consumable": true,
			"allow_forced_zero_energy_primary": false,
			"preferred_consumable_groups": [
				"repair",
				"explosive",
				"recharge"
			]
		},
		"battle_comment": [
			"I will find what remains of you.",
			"I let nothing go to waste.",
			"Scrap is only a body that has stopped lying.",
			"Your route is salvage now."
		],
		"reward": ["iron", "cobalt", "nickel", "large_kinetic_rounds", "raider_hot_patch_canister_mk2"],
		"reward_items": ["iron", "cobalt", "nickel", "large_kinetic_rounds", "raider_hot_patch_canister_mk2"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_warden", "chapter_004", "bleezzee_tier_2_boss"],
		"hp_min": 650,
		"hp_max": 650,
		"max_hull": 650,
		"hull": 650,
		"attack_min": 44,
		"attack_max": 44,
		"attack_power": 44,
		"cooldown_min": 2.40,
		"cooldown_max": 3.15
	},
	"vayrax_drone_015": {
		"id": "vayrax_drone_015",
		"name": "Vayrax Drone 015",
		"display_name": "Vayrax Drone 015",
		"ship_name": "Vayrax Drone 015",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 3,
		"energy_max": 540.0,
		"max_energy": 540,
		"energy": 540,
		"primary": "guardian_suppression_beam_mk3",
		"primary_weapon": "guardian_suppression_beam_mk3",
		"secondary": "raider_spike_mortar_mk2",
		"secondary_weapon": "raider_spike_mortar_mk2",
		"shield": "raider_plate_screen_mk2",
		"shield_item": "raider_plate_screen_mk2",
		"consumable": "recharge_kit",
		"consumable_item": "recharge_kit",
		"item_stacks": {
			"large_kinetic_rounds": 7,
			"medium_kinetic_rounds": 12,
			"recharge_kit": 1
		},
		"behavior_profile": "smart_guy_pressure",
		"behavior_values": {
			"decision_cooldown": 1.00,
			"low_hull_evade_threshold": 0.23,
			"low_energy_secondary_threshold": 0.45,
			"execute_player_threshold": 0.52,
			"explosive_player_threshold": 0.55
		},
		"battle_comment": [
			"Fifteen removes quiet options.",
			"Every vector now closes.",
			"You may still choose where it hurts."
		],
		"reward": ["cobalt", "nickel", "large_kinetic_rounds"],
		"reward_items": ["cobalt", "nickel", "large_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_015"],
		"hp_min": 570,
		"hp_max": 570,
		"max_hull": 570,
		"hull": 570,
		"attack_min": 43,
		"attack_max": 43,
		"attack_power": 43,
		"cooldown_min": 2.60,
		"cooldown_max": 3.45
	},
	"vayrax_drone_016": {
		"id": "vayrax_drone_016",
		"name": "Vayrax Drone 016",
		"display_name": "Vayrax Drone 016",
		"ship_name": "Vayrax Drone 016",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 3,
		"energy_max": 580.0,
		"max_energy": 580,
		"energy": 580,
		"primary": "guardian_suppression_beam_mk3",
		"primary_weapon": "guardian_suppression_beam_mk3",
		"secondary": "guardian_punch_driver_mk3",
		"secondary_weapon": "guardian_punch_driver_mk3",
		"shield": "guardian_lock_barrier_mk3",
		"shield_item": "guardian_lock_barrier_mk3",
		"consumable": "repair_kit",
		"consumable_item": "repair_kit",
		"item_stacks": {
			"medium_kinetic_rounds": 16,
			"large_kinetic_rounds": 6,
			"repair_kit": 1
		},
		"behavior_profile": "smart_guy_survivor",
		"behavior_values": {
			"decision_cooldown": 0.98,
			"low_hull_evade_threshold": 0.40,
			"critical_hull_evade_threshold": 0.24,
			"repair_hull_threshold": 0.50,
			"shield_hull_threshold": 0.56
		},
		"battle_comment": [
			"Sixteen was built to remain.",
			"Your impact becomes inventory.",
			"Survival is not mercy."
		],
		"reward": ["iron", "cobalt", "medium_kinetic_rounds"],
		"reward_items": ["iron", "cobalt", "medium_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_016"],
		"hp_min": 620,
		"hp_max": 620,
		"max_hull": 620,
		"hull": 620,
		"attack_min": 46,
		"attack_max": 46,
		"attack_power": 46,
		"cooldown_min": 2.55,
		"cooldown_max": 3.40
	},
	"vayrax_drone_017": {
		"id": "vayrax_drone_017",
		"name": "Vayrax Drone 017",
		"display_name": "Vayrax Drone 017",
		"ship_name": "Vayrax Drone 017",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 3,
		"energy_max": 625.0,
		"max_energy": 625,
		"energy": 625,
		"primary": "guardian_suppression_beam_mk3",
		"primary_weapon": "guardian_suppression_beam_mk3",
		"secondary": "guardian_punch_driver_mk3",
		"secondary_weapon": "guardian_punch_driver_mk3",
		"shield": "guardian_lock_barrier_mk3",
		"shield_item": "guardian_lock_barrier_mk3",
		"consumable": "recharge_kit",
		"consumable_item": "recharge_kit",
		"item_stacks": {
			"medium_kinetic_rounds": 18,
			"large_kinetic_rounds": 6,
			"recharge_kit": 1
		},
		"behavior_profile": "smart_guy_tactician",
		"behavior_values": {
			"decision_cooldown": 0.95,
			"low_hull_evade_threshold": 0.32,
			"repair_hull_threshold": 0.37,
			"shield_switch_min_cooldown_seconds": 8.0,
			"low_energy_secondary_threshold": 0.46
		},
		"battle_comment": [
			"Seventeen spends nothing twice.",
			"Your best route now belongs to me.",
			"Correction has become elegant."
		],
		"reward": ["cobalt", "nickel", "medium_kinetic_rounds"],
		"reward_items": ["cobalt", "nickel", "medium_kinetic_rounds"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_017"],
		"hp_min": 675,
		"hp_max": 675,
		"max_hull": 675,
		"hull": 675,
		"attack_min": 49,
		"attack_max": 49,
		"attack_power": 49,
		"cooldown_min": 2.50,
		"cooldown_max": 3.35
	},
	"vayrax_drone_018": {
		"id": "vayrax_drone_018",
		"name": "Vayrax Drone 018",
		"display_name": "Vayrax Drone 018",
		"ship_name": "Vayrax Drone 018",
		"type": "vayrax_drone",
		"faction": "vayrax",
		"tier": 3,
		"energy_max": 675.0,
		"max_energy": 675,
		"energy": 675,
		"primary": "guardian_suppression_beam_mk3",
		"primary_weapon": "guardian_suppression_beam_mk3",
		"secondary": "raider_spike_mortar_mk2",
		"secondary_weapon": "raider_spike_mortar_mk2",
		"shield": "guardian_lock_barrier_mk3",
		"shield_item": "guardian_lock_barrier_mk3",
		"consumable": "breach_charge",
		"consumable_item": "breach_charge",
		"item_stacks": {
			"large_kinetic_rounds": 8,
			"medium_kinetic_rounds": 16,
			"breach_charge": 1
		},
		"behavior_profile": "smart_guy_bomber",
		"behavior_values": {
			"decision_cooldown": 0.92,
			"low_hull_evade_threshold": 0.24,
			"repair_hull_threshold": 0.30,
			"explosive_player_threshold": 0.54,
			"execute_player_threshold": 0.55
		},
		"battle_comment": [
			"Eighteen brings the argument to a point.",
			"The bracket closes now.",
			"Your answer must survive impact."
		],
		"reward": ["cobalt", "large_kinetic_rounds", "breach_charge"],
		"reward_items": ["cobalt", "large_kinetic_rounds", "breach_charge"],
		"has_event": true,
		"events": [],
		"event_tags": ["vayrax", "vayrax_drone", "vayrax_drone_018"],
		"hp_min": 735,
		"hp_max": 735,
		"max_hull": 735,
		"hull": 735,
		"attack_min": 53,
		"attack_max": 53,
		"attack_power": 53,
		"cooldown_min": 2.45,
		"cooldown_max": 3.30
	}
}
}


func get_default_enemy_meta() -> Dictionary:
	# Summary: Central default metadata packet applied to every enemy creation/load path.
	return {
		"energy_max": 100.0,
		"tier": 1,
		"reward": ["iron", "cobalt", "nickel"],
		"primary": "e_basic_energy_pew_pew",
		"secondary": "micro_torpedo_launcher",
		"shield": "basic_shield_mk1",
		"consumable": "repair_kit",
		"item_stacks": {
			"small_kinetic_rounds": 6,
			"medium_kinetic_rounds": 3,
			"large_kinetic_rounds": 1,
			"repair_kit": 1
		},
		"behavior_profile": "raider_basic",
		"behavior_values": {},
		"battle_comment": ["No were to run", "we have you now"],
		"ship_name": "Bomba Ring Grazer",
		"has_event": true,
		"events": [],
		"event_tags": []
	}


func apply_enemy_meta(enemy_ref: Enemy, meta_source: Dictionary = {}) -> void:
	# Summary: Copy handler-owned enemy metadata onto an enemy without touching live hull/location.
	if enemy_ref == null:
		return

	var meta := get_default_enemy_meta()
	for key in meta_source.keys():
		if meta.has(key):
			meta[key] = meta_source[key]

	enemy_ref.energy_max = float(meta.get("energy_max", 100.0))
	enemy_ref.tier = int(meta.get("tier", 1))
	enemy_ref.reward = get_meta_array(meta, "reward", ["iron", "cobalt", "nickel"])
	enemy_ref.primary = str(meta.get("primary", "e_basic_energy_pew_pew"))
	enemy_ref.secondary = str(meta.get("secondary", "micro_torpedo_launcher"))
	enemy_ref.shield = str(meta.get("shield", "basic_shield_mk1"))
	enemy_ref.consumable = str(meta.get("consumable", "repair_kit"))
	enemy_ref.item_stacks = get_meta_dictionary(meta, "item_stacks", {})
	enemy_ref.behavior_profile = str(meta.get("behavior_profile", "raider_basic"))
	enemy_ref.behavior_values = get_meta_dictionary(meta, "behavior_values", {})
	enemy_ref.battle_comment = get_meta_array(meta, "battle_comment", ["No were to run", "we have you now"])
	enemy_ref.ship_name = str(meta.get("ship_name", "Bomba Ring Grazer"))
	enemy_ref.has_event = bool(meta.get("has_event", true))
	enemy_ref.events = get_meta_array(meta, "events", [])
	enemy_ref.event_tags = get_meta_array(meta, "event_tags", [])
	if enemy_ref.enemy_template_id.strip_edges() == "":
		for key in ["enemy_template_id", "enemy_blueprint_id", "blueprint_id", "id"]:
			var template_value := str(meta_source.get(key, "")).strip_edges()
			if template_value != "":
				enemy_ref.enemy_template_id = template_value
				break

	if enemy_ref.object_id.strip_edges() == "":
		enemy_ref.object_id = build_enemy_instance_id(enemy_ref.enemy_type, enemy_ref.enemy_name, enemy_ref.sector_pos, enemy_ref.local_pos)
	enemy_ref.object_type = "enemy"
	enemy_ref.display_name = enemy_ref.enemy_name
	enemy_ref.apply_shared_meta(meta_source, false)
	register_enemy_intel(enemy_ref, meta_source)


func get_meta_array(meta: Dictionary, key: String, fallback: Array) -> Array:
	# Summary: Return a duplicated metadata array so enemy instances do not share mutable lists.
	var value = meta.get(key, fallback)
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return fallback.duplicate(true)


func get_meta_dictionary(meta: Dictionary, key: String, fallback: Dictionary) -> Dictionary:
	# Summary: Return a duplicated metadata dictionary so enemy instances do not share mutable maps.
	var value = meta.get(key, fallback)
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return fallback.duplicate(true)
# ==========================================================
# CREATE ENEMY
# ==========================================================
func make_enemy(
	name: String,
	type: String,
	sector: Vector3i,
	local: Vector3
) -> Enemy:
	# Summary: Creates a basic Enemy instance, assigns its world identity/location, and tracks it in the handler list.
	if Globals.print_priority_3:
		print("EnemyHandler.make_enemy | Creating basic enemy: ", name, " | Type: ", type, " | Sector: ", sector)

	# Create one clean enemy unit; Enemy.gd owns the individual unit state after creation.
	var e = Enemy.new()

	# Assign identity and type values passed in by the caller.
	e.enemy_name = name
	e.enemy_type = type

	# Assign world placement so the handler can later find this enemy by sector/local space.
	e.sector_pos = sector
	e.local_pos = local
	e.object_id = build_enemy_instance_id(type, name, sector, local)
	e.object_type = "enemy"
	e.display_name = name
	apply_enemy_meta(e)

	# Track the enemy in the handler-owned world enemy collection.
	enemies.append(e)

	return e


# ==========================================================
# GET ENEMIES IN SECTOR
# ==========================================================
func get_enemies_in_sector(sector: Vector3i) -> Array:
	# Summary: Finds and returns every tracked enemy currently assigned to the requested sector.
	if Globals.print_priority_3:
		print("EnemyHandler.get_enemies_in_sector | Searching sector: ", sector)

	# Build a clean result list instead of exposing or modifying the full handler-owned enemy list.
	var result := []

	# Check each tracked enemy and collect only enemies whose sector matches the requested sector.
	for e in enemies:
		if e.sector_pos == sector:
			result.append(e)

	if Globals.print_priority_3:
		print("EnemyHandler.get_enemies_in_sector | Found enemies: ", result.size())

	return result


func get_enemies_near(sector_pos: Vector3i, local_pos: Vector3, scan_range: float) -> Array:
	# Summary: Finds tracked enemies in the same sector within the requested local 3D range.
	var result: Array = []

	for e in enemies:
		if e == null:
			continue
		if e.sector_pos != sector_pos:
			continue
		if e.local_pos.distance_to(local_pos) <= scan_range:
			result.append(e)

	return result


func get_closest_enemy_in_sector(sector_pos: Vector3i, local_pos: Vector3):
	# Summary: Return the closest enemy in a sector for later battle target handoff.
	var closest_enemy = null
	var closest_distance: float = INF

	for e in get_enemies_in_sector(sector_pos):
		var distance: float = e.local_pos.distance_to(local_pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = e

	return closest_enemy


func get_enemy_by_id(enemy_id: String):
	# Summary: Return a tracked enemy by Live Map V1 id for later owner handoff.
	for i in range(enemies.size()):
		var e: Enemy = enemies[i]
		if get_enemy_id(e, i) == enemy_id:
			return e

	return null


func get_enemy_id(enemy: Enemy, index: int = -1) -> String:
	# Summary: Build a V1 enemy id from handler index because Enemy has no persistent id yet.
	if enemy == null:
		return "enemy_none"
	if str(enemy.object_id).strip_edges() != "":
		return str(enemy.object_id).strip_edges()
	if index >= 0:
		enemy.object_id = build_enemy_instance_id(enemy.enemy_type, enemy.enemy_name, enemy.sector_pos, enemy.local_pos)
		return enemy.object_id
	enemy.object_id = build_enemy_instance_id(enemy.enemy_type, enemy.enemy_name, enemy.sector_pos, enemy.local_pos)
	return enemy.object_id


# ==========================================================
# CLEAR
# ==========================================================
func clear_enemies() -> void:
	# Summary: Removes all tracked enemies from the handler-owned world enemy collection.
	if Globals.print_priority_2:
		print("EnemyHandler.clear_enemies | Clearing tracked enemies. Current count: ", enemies.size())

	# Clear the handler-owned enemy collection.
	# This removes world tracking references but does not resolve battle outcomes.
	enemies.clear()

	if Globals.print_priority_2:
		print("EnemyHandler.clear_enemies | Enemy collection cleared. Current count: ", enemies.size())


# ==========================================================
# SAVE
# ==========================================================
func to_save_data() -> Dictionary:
	# Summary: Builds a save-safe dictionary containing all handler-tracked enemy save data.
	if Globals.print_priority_2:
		print("EnemyHandler.to_save_data | Saving tracked enemies. Count: ", enemies.size())

	# Store all enemy save packets in a dedicated array for persistence.
	var enemy_save_list := []

	# Convert each tracked enemy into a save-safe dictionary packet.
	for e in enemies:
		# Safety check so invalid enemy references do not corrupt save output.
		if e == null:
			if Globals.print_priority_2:
				print("EnemyHandler.to_save_data | WARNING: Null enemy found during save export.")

			continue

		# Enemy.gd owns its own unit save packet generation.
		enemy_save_list.append(e.to_save_data())

	# Return a handler-owned save dictionary that can later rebuild the world enemy list.
	return {
		"enemies": enemy_save_list
	}


# ==========================================================
# LOAD
# ==========================================================
func from_save_data(data: Dictionary) -> void:
	# Summary: Rebuilds the handler-owned enemy collection from a save dictionary.
	if Globals.print_priority_2:
		print("EnemyHandler.from_save_data | Loading enemy handler save data.")

	# Always clear the existing handler-owned collection before rebuilding from save data.
	clear_enemies()

	# Pull the enemy array from the new dictionary save format.
	var enemy_save_list = data.get("enemies", [])

	# Safety check so malformed save data does not crash the load path.
	if typeof(enemy_save_list) != TYPE_ARRAY:
		if Globals.print_priority_2:
			print("EnemyHandler.from_save_data | WARNING: Save field 'enemies' was not an Array.")

		return

	# Rebuild each enemy object from its own enemy-owned save packet.
	for enemy_data in enemy_save_list:
		if typeof(enemy_data) != TYPE_DICTIONARY:
			if Globals.print_priority_2:
				print("EnemyHandler.from_save_data | WARNING: Skipping malformed enemy save packet.")

			continue

		# Enemy.gd owns restoring the individual enemy unit state.
		var e = Enemy.new()
		e.from_save_data(enemy_data)
		if e.object_id.strip_edges() == "":
			e.object_id = build_enemy_instance_id(e.enemy_type, e.enemy_name, e.sector_pos, e.local_pos)
		e.sync_shared_meta()
		register_enemy_intel(e, {"source": "EnemyHandler.from_save_data"})

		# Track the restored enemy in the handler-owned world enemy collection.
		enemies.append(e)

	if Globals.print_priority_2:
		print("EnemyHandler.from_save_data | Loaded enemies. Count: ", enemies.size())


func load_from_data(data) -> void:
	# Summary: Compatibility load entry used by SaveManager for enemy save packets.
	if Globals.print_priority_2:
		print("EnemyHandler.load_from_data | Loading enemy data from SaveManager.")

	# ------------------------------------------------------
	# Current enemy saves arrive as {"enemies": [...]}; older
	# or manual saves may pass the array directly.
	# ------------------------------------------------------
	if typeof(data) == TYPE_DICTIONARY:
		from_save_data(data)
		return

	if typeof(data) == TYPE_ARRAY:
		from_save_data({"enemies": data})
		return

	# ------------------------------------------------------
	# Reject unknown save shapes without crashing startup.
	# ------------------------------------------------------
	if Globals.print_priority_2:
		print("EnemyHandler.load_from_data | WARNING: Unsupported enemy save data shape.")
		
func generate_enemies_for_sector(sector: Vector3i):

	# prevent duplicates
	var existing = get_enemies_in_sector(sector)
	if not existing.is_empty():
		return

	## simple chance system
	#if randi() % 3 != 0:
		#return

	# spawn 1 enemy
	make_enemy(
		"Scout Drone",
		"drone",
		sector,
		Vector3(randf()*800, randf()*800, randf()*800)
	)
	
	
# ==========================================================
# MAKE ENEMY NEAR STAR
# ----------------------------------------------------------
# Spawns a random enemy near a star.
# The actual stats come from the enemy blueprint database above.
# ==========================================================
func make_enemy_near_star(star) -> Enemy:

	var local_offset := Vector3(
		randf_range(-300.0, 300.0),
		randf_range(-300.0, 300.0),
		randf_range(-300.0, 300.0)
	)

	var spawn_sector: Vector3i = star.sector_pos
	var spawn_local: Vector3 = star.local_pos + local_offset

	var blueprint_id := get_random_enemy_blueprint_id()

	return make_enemy_from_blueprint(
		blueprint_id,
		spawn_sector,
		spawn_local
	)
	
# ==========================================================
# PICK RANDOM ENEMY BLUEPRINT
# ----------------------------------------------------------
# Chooses what enemy type the universe should spawn.
# ==========================================================
func get_random_enemy_blueprint_id() -> String:
	var ids := get_enemy_blueprints().keys()

	if ids.is_empty():
		return "scout_drone"

	return ids[randi_range(0, ids.size() - 1)]

# ==========================================================
# MAKE ENEMY FROM BLUEPRINT
# ----------------------------------------------------------
# Creates an Enemy object using data from the handler database.
# Enemy.gd stays clean and generic.
# ==========================================================
func make_enemy_from_blueprint(
	blueprint_id: String,
	sector: Vector3i,
	local: Vector3
) -> Enemy:

	var blueprints := get_enemy_blueprints()

	if not blueprints.has(blueprint_id):
		if Globals.print_priority_2:
			print("Missing enemy blueprint: ", blueprint_id)
		blueprint_id = "scout_drone"

	var data: Dictionary = blueprints[blueprint_id]

	var e := Enemy.new()

	e.enemy_name = data.get("name", "Unknown Enemy")
	e.enemy_type = data.get("type", "drone")
	e.enemy_template_id = blueprint_id

	e.sector_pos = sector
	e.local_pos = local
	e.object_id = build_enemy_instance_id(e.enemy_type, e.enemy_name, sector, local)
	e.object_type = "enemy"
	e.display_name = e.enemy_name

	e.hp = randi_range(
		int(data.get("hp_min", 100)),
		int(data.get("hp_max", 200))
	)

	e.max_hp = e.hp

	e.attack = randi_range(
		int(data.get("attack_min", 5)),
		int(data.get("attack_max", 10))
	)

	e.cooldown = randf_range(
		float(data.get("cooldown_min", 3.0)),
		float(data.get("cooldown_max", 6.0))
	)

	e.timer = e.cooldown
	apply_enemy_meta(e, data)

	enemies.append(e)

	if Globals.print_priority_2:
		print(
			"ENEMY CREATED: "
			+ e.enemy_name
			+ " | HP: "
			+ str(e.hp)
			+ " | ATK: "
			+ str(e.attack)
			+ " | Sector: "
			+ str(e.sector_pos)
		)

	return e
	
# ==========================================================
# GENERATE ENEMIES FROM STARS
# ----------------------------------------------------------
# Walks the star field and gives some stars an enemy nearby.
# This is the universe population function.
# ==========================================================
func generate_from_stars(star_field) -> void:

	if star_field == null:
		if Globals.print_priority_2:
			print("Enemy generation failed - star_field is null")
		return

	for star in star_field.stars:

		## 1 in 3 chance that a star gets an enemy.
		#if randi() % 3 != 0:
			#continue

		make_enemy_near_star(star)

	if Globals.print_priority_2:
		print("Enemy universe population complete. Total enemies: ", enemies.size())
	
	
func regenerate_from_stars(star_field) -> void:
	clear_enemies()
	generate_from_stars(star_field)
	
	
func get_enemy_by_serial(enemy_serial: String) -> Enemy:
	var clean_serial := enemy_serial.strip_edges()
	if clean_serial == "":
		return null

	for enemy in enemies:
		if enemy == null:
			continue
		if str(enemy.enemy_serial).strip_edges() == clean_serial:
			return enemy
		var shared_meta = enemy.shared_meta
		if typeof(shared_meta) == TYPE_DICTIONARY and str(shared_meta.get("enemy_serial", "")).strip_edges() == clean_serial:
			return enemy

	return null


func remove_enemy_by_serial(enemy_serial: String) -> bool:
	var enemy := get_enemy_by_serial(enemy_serial)
	if enemy == null:
		return false
	remove_enemy(enemy)
	return true
	
	
	
func remove_enemy(enemy: Enemy) -> void:
	# Summary: Removes a specific enemy instance from the handler-owned world enemy collection.
	if Globals.print_priority_2:
		print("EnemyHandler.remove_enemy | Attempting removal for enemy: ", enemy.enemy_name)

	# Safety check so we do not attempt to remove an invalid or null enemy reference.
	if enemy == null:
		if Globals.print_priority_2:
			print("EnemyHandler.remove_enemy | WARNING: Null enemy passed into remove_enemy().")

		return

	# Only remove the enemy if it currently exists inside the tracked handler collection.
	if enemies.has(enemy):
		enemies.erase(enemy)

		if Globals.print_priority_2:
			print("EnemyHandler.remove_enemy | Enemy removed successfully: ", enemy.enemy_name)
	else:
		# Report failed removal attempts for debugging world-state drift.
		if Globals.print_priority_2:
			print("EnemyHandler.remove_enemy | Enemy was not found in tracked collection: ", enemy.enemy_name)



func remove_enemy_by_name(enemy_name: String) -> void:
	# Summary: Finds and removes the first tracked enemy whose enemy_name matches the requested name.
	if Globals.print_priority_2:
		print("EnemyHandler.remove_enemy_by_name | Searching for enemy: ", enemy_name)

	# Safety check so blank names do not trigger accidental removals.
	if enemy_name.strip_edges() == "":
		if Globals.print_priority_2:
			print("EnemyHandler.remove_enemy_by_name | WARNING: Blank enemy name provided.")

		return

	# Search through the handler-owned enemy collection for a matching enemy name.
	for e in enemies:
		if e.enemy_name == enemy_name:
			# Remove the matched enemy from the tracked collection.
			enemies.erase(e)

			if Globals.print_priority_2:
				print("EnemyHandler.remove_enemy_by_name | Enemy removed successfully: ", enemy_name)

			return

	# Report failed searches for easier world-state debugging.
	if Globals.print_priority_2:
		print("EnemyHandler.remove_enemy_by_name | Enemy not found: ", enemy_name)
		
		
		
func get_enemy_by_name(enemy_name: String) -> Enemy:
	# Summary: Finds and returns the first tracked enemy whose enemy_name matches the requested name.
	if Globals.print_priority_3:
		print("EnemyHandler.get_enemy_by_name | Searching for enemy: ", enemy_name)

	# Safety check so blank names do not perform meaningless searches.
	if enemy_name.strip_edges() == "":
		if Globals.print_priority_2:
			print("EnemyHandler.get_enemy_by_name | WARNING: Blank enemy name provided.")

		return null

	# Search through the handler-owned enemy collection for a matching enemy name.
	for e in enemies:
		if e.enemy_name == enemy_name:
			if Globals.print_priority_3:
				print("EnemyHandler.get_enemy_by_name | Enemy found: ", enemy_name)

			return e

	# Report failed searches to help debug world enemy tracking issues.
	if Globals.print_priority_2:
		print("EnemyHandler.get_enemy_by_name | Enemy not found: ", enemy_name)

	return null


func build_enemy_instance_id(enemy_type: String, enemy_name: String, sector: Vector3i, local: Vector3) -> String:
	# Summary: Stable enough world id for enemy save/live-map/battle cleanup handoff.
	return (
		str(enemy_type).to_lower().replace(" ", "_")
		+ "_"
		+ str(enemy_name).to_lower().replace(" ", "_")
		+ "_s" + str(sector.x) + "_" + str(sector.y) + "_" + str(sector.z)
		+ "_l" + str(int(round(local.x))) + "_" + str(int(round(local.y))) + "_" + str(int(round(local.z)))
	)
