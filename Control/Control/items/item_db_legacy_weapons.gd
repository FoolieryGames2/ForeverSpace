extends RefCounted

# ==========================================================
# PRE-S1.4 / BASE WEAPON ITEMS
# ----------------------------------------------------------
# Data-only item dictionary slice.
# Loaded by Control/items/item_db_builder.gd.
# Do not put behavior in this file.
# ==========================================================

static func get_items() -> Dictionary:
	return {
		# WEAPONS - ENERGY (alien tech infused)
		# ------------------------------------------------------
		"pulse_laser_mk1": {
		"id": "pulse_laser_mk1",
		"item_id": "pulse_laser_mk1",
		"name": "Pulse Laser MK1",
		"display_name": "Pulse Laser MK1",
		"type": "weapon",
		"item_type": "weapon",
		"subtype": "energy",
		"slot": "primary",
		"damage_type": "energy",
		"damage_value": 50,
		"damage": 50,
		"duration": 3.0,
		"energy_cost": 25,
		"weapon_group": "energy",
		"ammo_group": "",
		"ammo_per_burst": 0,
		"burst_count": 1,
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": true,
		"grants_actions": ["fire_pulse_laser"],
		"atlas": "item_sheet_test",
		"texture" : preload("res://images/laser_mk_1_resiz.png")
		},

		"plasma_arc_emitter": {
		"id": "plasma_arc_emitter",
		"item_id": "plasma_arc_emitter",
		"name": "Plasma Arc Emitter",
		"display_name": "Plasma Arc Emitter",
		"type": "weapon",
		"item_type": "weapon",
		"subtype": "energy",
		"slot": "primary",
		"damage_type": "energy",
		"damage_value": 32,
		"damage": 32,
		"duration": 3.0,
		"energy_cost": 25,
		"weapon_group": "energy",
		"ammo_group": "",
		"ammo_per_burst": 0,
		"burst_count": 1,
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": true,
		"grants_actions": ["fire_plasma_arc"],
		"atlas": "item_sheet_test",
		"region": Rect2(45, 50, 34, 32)
		},

		"phase_beam_array": {
		"id": "phase_beam_array",
		"item_id": "phase_beam_array",
		"name": "Phase Beam Array",
		"display_name": "Phase Beam Array",
		"type": "weapon",
		"item_type": "weapon",
		"subtype": "energy",
		"slot": "primary",
		"damage_type": "energy",
		"damage_value": 45,
		"damage": 45,
		"duration": 3.5,
		"energy_cost": 35,
		"weapon_group": "energy",
		"ammo_group": "",
		"ammo_per_burst": 0,
		"burst_count": 1,
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": true,
		"grants_actions": ["fire_phase_beam"],
		"atlas": "item_sheet_test",
		"region": Rect2(80, 50, 34, 32)
		},


		# ------------------------------------------------------
		# WEAPONS - KINETIC (probe adapted tech)
		# ------------------------------------------------------
		"railgun_mk1": {
		"id": "railgun_mk1",
		"item_id": "railgun_mk1",
		"name": "Railgun MK1",
		"display_name": "Railgun MK1",
		"type": "weapon",
		"item_type": "weapon",
		"subtype": "kinetic",
		"slot": "secondary",
		"damage_type": "kinetic",
		"damage_value": 28,
		"damage": 28,
		"duration": 4.0,
		"energy_cost": 0,
		"weapon_group": "medium",
		"ammo_group": "medium",
		"ammo_per_burst": 1,
		"burst_count": 3,
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": true,
		"grants_actions": ["fire_railgun"],
		"atlas": "item_sheet_test",
		"region": Rect2(10, 85, 34, 32)
		},

		"railgun_sk1": {
		"id": "railgun_sk1",
		"item_id": "railgun_sk1",
		"name": "Railgun SK1",
		"display_name": "Railgun SK1",
		"type": "weapon",
		"item_type": "weapon",
		"subtype": "kinetic",
		"slot": "secondary",
		"damage_type": "kinetic",
		"damage_value": 12,
		"damage": 12,
		"duration": 1.5,
		"energy_cost": 0,
		"weapon_group": "small",
		"ammo_group": "small",
		"ammo_per_burst": 1,
		"burst_count": 5,
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": true,
		"grants_actions": ["fire_railgun"],
		"atlas": "item_sheet_test",
		"region": Rect2(10, 85, 34, 32)
		},

		"mass_driver": {
		"id": "mass_driver",
		"item_id": "mass_driver",
		"name": "Mass Driver",
		"display_name": "Mass Driver",
		"type": "weapon",
		"item_type": "weapon",
		"subtype": "kinetic",
		"slot": "secondary",
		"damage_type": "kinetic",
		"damage_value": 36,
		"damage": 36,
		"duration": 4.5,
		"energy_cost": 0,
		"weapon_group": "medium",
		"ammo_group": "medium",
		"ammo_per_burst": 1,
		"burst_count": 3,
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": true,
		"grants_actions": ["fire_mass_driver"],
		"atlas": "item_sheet_test",
		"region": Rect2(45, 85, 34, 32)
		},

		"shard_flinger": {
		"id": "shard_flinger",
		"item_id": "shard_flinger",
		"name": "Shard Flinger",
		"display_name": "Shard Flinger",
		"type": "weapon",
		"item_type": "weapon",
		"subtype": "kinetic",
		"slot": "secondary",
		"damage_type": "kinetic",
		"damage_value": 22,
		"damage": 22,
		"duration": 3.5,
		"energy_cost": 0,
		"weapon_group": "small",
		"ammo_group": "small",
		"ammo_per_burst": 1,
		"burst_count": 4,
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": true,
		"grants_actions": ["fire_shards"],
		"atlas": "item_sheet_test",
		"region": Rect2(80, 85, 34, 32)
		},


		# ------------------------------------------------------
		# WEAPONS - EXPLOSIVE (hybrid alien payloads)
		# ------------------------------------------------------
		"micro_torpedo_launcher": {
		"id": "micro_torpedo_launcher",
		"item_id": "micro_torpedo_launcher",
		"name": "Micro Torpedo Launcher",
		"display_name": "Micro Torpedo Launcher",
		"type": "weapon",
		"item_type": "weapon",
		"subtype": "explosive",
		"slot": "secondary",
		"damage_type": "explosive",
		"damage_value": 40,
		"damage": 40,
		"explosive_pass_percent": 0.25,
		"duration": 5.0,
		"energy_cost": 0,
		"weapon_group": "large",
		"ammo_group": "large",
		"ammo_per_burst": 1,
		"burst_count": 1,
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": true,
		"grants_actions": ["launch_torpedo"],
		"labels": ["secondary_weapon_explosive_based", "damage_type_explosive", "explosive_pass_damage"],
		"atlas": "item_sheet_test",
		"region": Rect2(10, 120, 34, 32)
		},

		"void_charge_cannon": {
		"id": "void_charge_cannon",
		"item_id": "void_charge_cannon",
		"name": "Void Charge Cannon",
		"display_name": "Void Charge Cannon",
		"type": "weapon",
		"item_type": "weapon",
		"subtype": "explosive",
		"slot": "secondary",
		"damage_type": "explosive",
		"damage_value": 50,
		"damage": 50,
		"explosive_pass_percent": 0.35,
		"duration": 5.5,
		"energy_cost": 0,
		"weapon_group": "large",
		"ammo_group": "large",
		"ammo_per_burst": 1,
		"burst_count": 1,
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": true,
		"grants_actions": ["fire_void_charge"],
		"labels": ["secondary_weapon_explosive_based", "damage_type_explosive", "explosive_pass_damage"],
		"atlas": "item_sheet_test",
		"region": Rect2(45, 120, 34, 32)
		},

		"fragmentation_pod": {
		"id": "fragmentation_pod",
		"item_id": "fragmentation_pod",
		"name": "Fragmentation Pod",
		"display_name": "Fragmentation Pod",

		"type": "consumable",
		"item_type": "consumable",
		"subtype": "explosive",
		"consumable_group": "explosive",
		"group": "explosive",
		"slot": "consumable",

		"consumable": true,
		"stackable": true,
		"max_stack": 9,
		"installed_only": false,

		"damage_type": "explosive",
		"damage_value": 26,
		"damage": 26,
		"explosive_damage": 26,
		"explosive_pass_percent": 0.20,

		"prep_time": 4.0,
		"load_time": 4.0,
		"execute_time": 0.4,
		"duration": 4.0,

		"energy_cost": 0,

		"grants_actions": ["load_consumable"],

		"labels": [
			"consumable",
			"enemy_consumable",
			"consumable_group_explosive",
			"damage_type_explosive",
			"explosive_pass_damage"
		],

		"atlas": "item_sheet_test",
		"region": Rect2(80, 120, 34, 32)
		},
	}
