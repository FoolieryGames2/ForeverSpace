extends RefCounted

# ==========================================================
# BASE RESOURCE ITEMS
# ----------------------------------------------------------
# Data-only item dictionary slice generated from the original
# Control/item_handler.gd item_db source.
# Do not put behavior in this file.
# ==========================================================

static func get_items() -> Dictionary:
	return {
		"iron": {
		"id": "iron",
		"name": "Iron",
		"type": "resource",
		"subtype": "metal",
		"stackable": true,
		"max_stack": 99999,
		"consumable": false,
		"installed_only": false,
		"grants_actions": [],
		"texture": preload("res://images/iron.png")
		},

		"cobalt": {
		"id": "cobalt",
		"name": "Cobalt",
		"type": "resource",
		"subtype": "metal",
		"stackable": true,
		"max_stack": 99999,
		"consumable": false,
		"installed_only": false,
		"grants_actions": [],
		"texture": preload("res://images/cobalt.png")
		},

		"nickel": {
		"id": "nickel",
		"name": "Nickel",
		"type": "resource",
		"subtype": "metal",
		"stackable": true,
		"max_stack": 99999,
		"consumable": false,
		"installed_only": false,
		"grants_actions": [],
		"texture": preload("res://images/nickel.png")
		},

		"gold": {
		"id": "gold",
		"name": "Gold",
		"type": "resource",
		"subtype": "metal",
		"stackable": true,
		"max_stack": 99999,
		"consumable": false,
		"installed_only": false,
		"grants_actions": [],
		"texture": preload("res://images/nickel.png")
		},

		"credits": {
		"id": "credits",
		"name": "Credits",
		"type": "resource",
		"subtype": "metal",
		"stackable": true,
		"max_stack": 99999,
		"consumable": false,
		"installed_only": false,
		"grants_actions": [],
		"texture": preload("res://images/nickel.png")
		}
	}
