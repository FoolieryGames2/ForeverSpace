extends RefCounted

# ==========================================================
# PART ITEMS
# ----------------------------------------------------------
# Data-only item dictionary slice generated from the original
# Control/item_handler.gd item_db source.
# Do not put behavior in this file.
# ==========================================================

static func get_items() -> Dictionary:
	return {
		"navigation_relay_coupler": {
		"item_id": "navigation_relay_coupler",
		"display_name": "Navigation Relay Coupler",
		"name": "Navigation Relay Coupler",
		
		"type": "part",
		"subtype": "event_item",
		"slot": "cargo",
		
		"stackable": true,
		"max_stack": 99,
		"consumable": false,
		"installed_only": false,
		
		"description": "An essential unit for Auto-pilot navigation",
		
		"labels": [
		"part",
		"navigation",
		"event_item",
		"auto_pilot"
		]
		}
	}
