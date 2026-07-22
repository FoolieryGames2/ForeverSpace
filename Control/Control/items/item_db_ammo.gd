extends RefCounted

# ==========================================================
# AMMO ITEMS
# ----------------------------------------------------------
# Data-only item dictionary slice generated from the original
# Control/item_handler.gd item_db source.
# Do not put behavior in this file.
# ==========================================================

static func get_items() -> Dictionary:
	return {
		"smart_guy_calculated_rounds": {
		"id": "smart_guy_calculated_rounds",
		"item_id": "smart_guy_calculated_rounds",
		"name": "Smart Guy Calculated Rounds",
		"display_name": "Smart Guy Calculated Rounds",
		"type": "ammo",
		"item_type": "ammo",
		"subtype": "medium",
		"ammo_group": "medium",
		"stackable": true,
		"max_stack": 999,
		"consumable": false,
		"installed_only": false,
		"grants_actions": [],
		"stats": {
		"ammo_damage": 8
		},
		"tags": ["ammo", "medium_ammo", "stackable", "smart_guy_item"],
		"labels": [
		"enemy_ammo",
		"smart_guy_item",
		"ammo_group_medium",
		"ammo_stackable",
		"ammo_damage_bonus"
		],
		"atlas": "item_sheet_test",
		"region": Rect2(150, 85, 34, 32)
		},

		"small_kinetic_rounds": {
		"id": "small_kinetic_rounds",
		"item_id": "small_kinetic_rounds",
		"name": "Small Kinetic Rounds",
		"display_name": "Small Kinetic Rounds",
		"type": "ammo",
		"item_type": "ammo",
		"subtype": "small",
		"ammo_group": "small",
		"stackable": true,
		"max_stack": 999,
		"consumable": false,
		"installed_only": false,
		"grants_actions": [],
		"stats": {
		"ammo_damage": 5
		},
		"tags": ["ammo", "small_ammo", "stackable"],
		"labels": ["ammo_group_small", "ammo_stackable", "ammo_damage_bonus"],
		"atlas": "item_sheet_test",
		"region": Rect2(115, 85, 34, 32)
		},

		"medium_kinetic_rounds": {
		"id": "medium_kinetic_rounds",
		"item_id": "medium_kinetic_rounds",
		"name": "Medium Kinetic Rounds",
		"display_name": "Medium Kinetic Rounds",
		"type": "ammo",
		"item_type": "ammo",
		"subtype": "medium",
		"ammo_group": "medium",
		"stackable": true,
		"max_stack": 999,
		"consumable": false,
		"installed_only": false,
		"grants_actions": [],
		"stats": {
		"ammo_damage": 10
		},
		"tags": ["ammo", "medium_ammo", "stackable"],
		"labels": ["ammo_group_medium", "ammo_stackable", "ammo_damage_bonus"],
		"atlas": "item_sheet_test",
		"region": Rect2(150, 85, 34, 32)
		},

		"large_kinetic_rounds": {
		"id": "large_kinetic_rounds",
		"item_id": "large_kinetic_rounds",
		"name": "Large Kinetic Rounds",
		"display_name": "Large Kinetic Rounds",
		"type": "ammo",
		"item_type": "ammo",
		"subtype": "large",
		"ammo_group": "large",
		"stackable": true,
		"max_stack": 999,
		"consumable": false,
		"installed_only": false,
		"grants_actions": [],
		"stats": {
		"ammo_damage": 20
		},
		"tags": ["ammo", "large_ammo", "stackable"],
		"labels": ["ammo_group_large", "ammo_stackable", "ammo_damage_bonus"],
		"atlas": "item_sheet_test",
		"region": Rect2(185, 85, 34, 32)
		}
	}
