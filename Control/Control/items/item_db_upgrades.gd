extends RefCounted

# ==========================================================
# BATTLE LOADOUT UPGRADES
# ----------------------------------------------------------
# Data-only reward items. Upgrades are passive Battle V2
# augments and must not be produced by blueprints/crafting.
# ==========================================================

static func get_items() -> Dictionary:
	return {
		"hull_polarizer": {
			"id": "hull_polarizer",
			"item_id": "hull_polarizer",
			"name": "Hull Polarizer",
			"display_name": "Hull Polarizer",
			"type": "upgrade",
			"item_type": "upgrade",
			"subtype": "armor",
			"upgrade_subtype": "armor",
			"tier": 1,
			"meta_family": "battle_loadout_upgrade",
			"reward_only": true,
			"craftable": false,
			"blueprint_allowed": false,
			"blueprint_id": "",
			"stackable": false,
			"max_stack": 1,
			"consumable": false,
			"installed_only": true,
			"battle_upgrade_meta": {
				"max_hull_bonus": 25,
				"max_energy_bonus": 0,
				"primary_damage_bonus": 0,
				"secondary_damage_bonus": 0,
				"secondary_burst_bonus": 0
			},
			"labels": ["battle_upgrade", "player_upgrade", "upgrade_subtype_armor"],
			"atlas": "item_sheet_test",
			"region": Rect2(10, 155, 34, 32)
		},

		"generator_heat_sinks": {
			"id": "generator_heat_sinks",
			"item_id": "generator_heat_sinks",
			"name": "Generator Heat Sinks",
			"display_name": "Generator Heat Sinks",
			"type": "upgrade",
			"item_type": "upgrade",
			"subtype": "energy",
			"upgrade_subtype": "energy",
			"tier": 1,
			"meta_family": "battle_loadout_upgrade",
			"reward_only": true,
			"craftable": false,
			"blueprint_allowed": false,
			"blueprint_id": "",
			"stackable": false,
			"max_stack": 1,
			"consumable": false,
			"installed_only": true,
			"battle_upgrade_meta": {
				"max_hull_bonus": 0,
				"max_energy_bonus": 25,
				"primary_damage_bonus": 0,
				"secondary_damage_bonus": 0,
				"secondary_burst_bonus": 0
			},
			"labels": ["battle_upgrade", "player_upgrade", "upgrade_subtype_energy"],
			"atlas": "item_sheet_test",
			"region": Rect2(45, 155, 34, 32)
		},

		"primary_capacitor": {
			"id": "primary_capacitor",
			"item_id": "primary_capacitor",
			"name": "Primary Capacitor",
			"display_name": "Primary Capacitor",
			"type": "upgrade",
			"item_type": "upgrade",
			"subtype": "primary_augment",
			"upgrade_subtype": "primary_augment",
			"tier": 1,
			"meta_family": "battle_loadout_upgrade",
			"reward_only": true,
			"craftable": false,
			"blueprint_allowed": false,
			"blueprint_id": "",
			"stackable": false,
			"max_stack": 1,
			"consumable": false,
			"installed_only": true,
			"battle_upgrade_meta": {
				"max_hull_bonus": 0,
				"max_energy_bonus": 0,
				"primary_damage_bonus": 10,
				"secondary_damage_bonus": 0,
				"secondary_burst_bonus": 0
			},
			"labels": ["battle_upgrade", "player_upgrade", "upgrade_subtype_primary_augment"],
			"atlas": "item_sheet_test",
			"region": Rect2(80, 155, 34, 32)
		},

		"secondary_ammo_extender": {
			"id": "secondary_ammo_extender",
			"item_id": "secondary_ammo_extender",
			"name": "Secondary Ammo Extender",
			"display_name": "Secondary Ammo Extender",
			"type": "upgrade",
			"item_type": "upgrade",
			"subtype": "secondary_augment",
			"upgrade_subtype": "secondary_augment",
			"tier": 1,
			"meta_family": "battle_loadout_upgrade",
			"reward_only": true,
			"craftable": false,
			"blueprint_allowed": false,
			"blueprint_id": "",
			"stackable": false,
			"max_stack": 1,
			"consumable": false,
			"installed_only": true,
			"battle_upgrade_meta": {
				"max_hull_bonus": 0,
				"max_energy_bonus": 0,
				"primary_damage_bonus": 0,
				"secondary_damage_bonus": 5,
				"secondary_burst_bonus": 1
			},
			"labels": ["battle_upgrade", "player_upgrade", "upgrade_subtype_secondary_augment"],
			"atlas": "item_sheet_test",
			"region": Rect2(115, 155, 34, 32)
		}
	}
