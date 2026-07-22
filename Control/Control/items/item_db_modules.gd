extends RefCounted

# ==========================================================
# MODULE ITEMS
# ----------------------------------------------------------
# Data-only item dictionary slice generated from the original
# Control/item_handler.gd item_db source.
# Do not put behavior in this file.
# ==========================================================

static func get_items() -> Dictionary:
	return {
		"scan_module_mk1": {
		"id": "scan_module_mk1",
		"name": "Scan Module Mk1",
		"type": "module",
		"subtype": "scanner",
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": true,
		"grants_actions": ["scan_local"],
		"atlas": "item_sheet_test",
		"region": Rect2(3, 11, 34, 32)
		},

		"drone_controller_mk1": {
		"id": "drone_controller_mk1",
		"name": "Drone Controller Mk1",
		"type": "module",
		"subtype": "drone_control",
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": true,
		"grants_actions": [],
		"atlas": "item_sheet_test",
		"region": Rect2(38, 11, 34, 32)
		}
	}
