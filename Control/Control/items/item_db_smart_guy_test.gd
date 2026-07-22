extends RefCounted

# ==========================================================
# SMART GUY TEST ENEMY ITEMS
# ----------------------------------------------------------
# Data-only item dictionary slice.
# Loaded by Control/items/item_db_builder.gd.
# Do not put behavior in this file.
# ==========================================================

static func get_items() -> Dictionary:
	return {
		# ------------------------------------------------------
		# SMART GUY TEST ENEMY ITEMS
		# ------------------------------------------------------
		"smart_guy_focus_lance": {
		"id": "smart_guy_focus_lance",
		"item_id": "smart_guy_focus_lance",
		"name": "Smart Guy Focus Lance",
		"display_name": "Smart Guy Focus Lance",
		"type": "weapon",
		"item_type": "weapon",
		"subtype": "energy",
		"slot": "primary",
		"damage_type": "energy",
		"damage_value": 34,
		"damage": 34,
		"duration": 3.0,
		"energy_cost": 24,
		"weapon_group": "energy",
		"ammo_group": "",
		"ammo_cost": 0,
		"ammo_per_burst": 0,
		"burst_count": 1,
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": true,
		"grants_actions": ["fire_smart_guy_focus_lance"],
		"labels": [
			"enemy_weapon",
			"smart_guy_item",
			"primary_weapon_energy",
			"damage_type_energy"
		],
		"atlas": "item_sheet_test",
		"region": Rect2(45, 50, 34, 32)
		},

		"smart_guy_calculated_rail": {
		"id": "smart_guy_calculated_rail",
		"item_id": "smart_guy_calculated_rail",
		"name": "Smart Guy Calculated Rail",
		"display_name": "Smart Guy Calculated Rail",
		"type": "weapon",
		"item_type": "weapon",
		"subtype": "kinetic",
		"slot": "secondary",
		"damage_type": "kinetic",
		"damage_value": 22,
		"damage": 22,
		"duration": 4.0,
		"energy_cost": 0,
		"weapon_group": "medium",
		"ammo_group": "medium",
		"ammo_cost": 1,
		"ammo_per_burst": 1,
		"burst_count": 2,
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": true,
		"grants_actions": ["fire_smart_guy_calculated_rail"],
		"labels": [
			"enemy_weapon",
			"smart_guy_item",
			"secondary_weapon_kinetic",
			"damage_type_kinetic",
			"ammo_group_medium"
		],
		"atlas": "item_sheet_test",
		"region": Rect2(45, 85, 34, 32)
		},

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

		"smart_guy_mirror_shield": {
		"id": "smart_guy_mirror_shield",
		"item_id": "smart_guy_mirror_shield",
		"name": "Smart Guy Mirror Shield",
		"display_name": "Smart Guy Mirror Shield",
		"type": "shield",
		"item_type": "shield",
		"subtype": "shield",
		"slot": "shield",
		"shield_hp_max": 75,
		"base_damage_resist": 0.28,
		"base_shield_resist": 0.28,
		"regen_per_second": 3.0,
		"regen_delay": 2.0,
		"swap_time": 1.75,
		"duration": 1.75,
		"steady_energy_drain": 25.0,
		"break_consumes_item": true,
		"repairable_while_active": true,
		"repairable_when_broken": false,
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": true,
		"grants_actions": ["switch_shield"],
		"tags": ["shield", "energy_drain", "smart_guy_item", "shield_break_consumes", "shield_repairable_while_active"],
		"enemy_logic_tags": ["enemy_can_equip", "enemy_can_replace_broken_shield"],
		"labels": [
			"enemy_shield",
			"smart_guy_item",
			"unit_shield_equipped",
			"shield_slider_scaling"
		],
		"atlas": "item_sheet_test",
		"region": Rect2(150, 120, 34, 32)
		},

		"smart_guy_patch_cell": {
		"id": "smart_guy_patch_cell",
		"item_id": "smart_guy_patch_cell",
		"name": "Smart Guy Patch Cell",
		"display_name": "Smart Guy Patch Cell",
		"type": "consumable",
		"item_type": "consumable",
		"subtype": "repair",
		"consumable_group": "repair",
		"prep_time": 4.0,
		"load_time": 4.0,
		"execute_time": 0.25,
		"duration": 4.0,
		"heal_amount": 20,
		"repair_amount": 20,
		"hull_restore_amount": 20,
		"stackable": true,
		"max_stack": 5,
		"consumable": true,
		"installed_only": false,
		"grants_actions": ["repair_ship"],
		"labels": [
			"enemy_consumable",
			"smart_guy_item",
			"consumable_group_repair",
			"repair_hull",
			"support_consumable"
		],
		"atlas": "item_sheet_test",
		"region": Rect2(70, 11, 34, 32)
		},
	}
