extends RefCounted

# ==========================================================
# EVENT ITEMS
# ----------------------------------------------------------
# Data-only item dictionary slice generated from the original
# Control/item_handler.gd item_db source.
# Do not put behavior in this file.
# ==========================================================

static func get_items() -> Dictionary:
	return {
		"data_chip_empty": {
		"id": "data_chip_empty",
		"item_id": "data_chip_empty",
		"name": "Data Chip [Empty]",
		"display_name": "Data Chip [Empty]",
		"type": "event_item",
		"item_type": "event_item",
		"subtype": "data_chip",
		"stackable": true,
		"max_stack": 10,
		"consumable": false,
		"installed_only": false,
		"grants_actions": [],
		"labels": ["event_item", "data_chip", "empty_data_chip"],
		"atlas": "item_sheet_test",
		"region": Rect2(3, 11, 34, 32)
		},

		"data_chip_full": {
		"id": "data_chip_full",
		"item_id": "data_chip_full",
		"name": "Data Chip [Full]",
		"display_name": "Data Chip [Full]",
		"type": "event_item",
		"item_type": "event_item",
		"subtype": "data_chip",
		"stackable": true,
		"max_stack": 10,
		"consumable": false,
		"installed_only": false,
		"grants_actions": [],
		"labels": ["event_item", "data_chip", "full_data_chip"],
		"atlas": "item_sheet_test",
		"region": Rect2(38, 11, 34, 32)
		},
		"vayrax_beacon_key": {
		"id": "vayrax_beacon_key",
		"item_id": "vayrax_beacon_key",
		"name": "Vayrax Beacon Key",
		"display_name": "Vayrax Beacon Key",
		"type": "event_item",
		"item_type": "event_item",
		"subtype": "key",
		"stackable": true,
		"max_stack": 10,
		"consumable": false,
		"installed_only": false,
		"grants_actions": [],
		"labels": ["event_item", "key", "beacon_key"],
		"atlas": "item_sheet_test",
		"region": Rect2(3, 11, 34, 32)
		},
		"moonpie_damaged_guardian_unit": {
		"id": "moonpie_damaged_guardian_unit",
		"item_id": "moonpie_damaged_guardian_unit",
		"name": "MoonPie Damaged Guardian Unit",
		"display_name": "MoonPie Damaged Guardian Unit",
		"type": "event_item",
		"item_type": "event_item",
		"subtype": "guardian_unit",
		"stackable": false,
		"max_stack": 1,
		"consumable": false,
		"installed_only": false,
		"grants_actions": [],
		"labels": ["event_item", "moonpie", "guardian_unit", "cargo_story_item"],
		"atlas": "item_sheet_test",
		"region": Rect2(3, 11, 34, 32)
		},
	}
