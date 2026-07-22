extends RefCounted

# ==========================================================
# DRONE ITEMS
# ----------------------------------------------------------
# Data-only item dictionary slice generated from the original
# Control/item_handler.gd item_db source.
# Do not put behavior in this file.
# ==========================================================

static func get_items() -> Dictionary:
	return {
		"roamer_drone_mk1": {
		"id": "roamer_drone_mk1",
		"name": "Roamer Drone MK1",
		"type": "drone",
		"subtype": "explorer",
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": false,
		"grants_actions": ["explore_local"],
		"atlas": "drone_sheet",
		"region": Rect2(0, 192, 64, 64)
		},

		"scout_drone": {
		"id": "scout_drone",
		"name": "Scout Drone",
		"type": "drone",
		"subtype": "scout",
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": false,
		"grants_actions": ["deploy_scout_drone"],
		"atlas": "drone_sheet",
		"region": Rect2(0, 0, 64, 64)
		},

		"miner_drone_mk1": {
		"id": "miner_drone_mk1",
		"name": "Miner Drone MK1",
		"type": "drone",
		"subtype": "miner",
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": false,
		"grants_actions": ["mine_local"],
		"atlas": "drone_sheet",
		"region": Rect2(0, 64, 64, 64)
		},

		"survey_drone_mk1": {
		"id": "survey_drone_mk1",
		"name": "Survey Drone MK1",
		"type": "drone",
		"subtype": "survey",
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": false,
		"grants_actions": ["survey_body"],
		"atlas": "drone_sheet",
		"region": Rect2(0, 0, 64, 64)
		},

		"lander_drone_mk1": {
		"id": "lander_drone_mk1",
		"name": "Lander Drone MK1",
		"type": "drone",
		"subtype": "lander",
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": false,
		"grants_actions": ["land_and_study"],
		"atlas": "drone_sheet",
		"region": Rect2(0, 128, 64, 64)
		#resources
		}
	}
