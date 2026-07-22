extends RefCounted

# ==========================================================
# ITEM DB BUILDER
# ----------------------------------------------------------
# Central merge point for separated item dictionary slices.
# ItemHandler remains the behavior owner; these files only build data.
# ==========================================================

const Modules = preload("res://Control/Control/items/item_db_modules.gd")
const Consumables = preload("res://Control/Control/items/item_db_consumables.gd")
const EventItems = preload("res://Control/Control/items/item_db_event_items.gd")
const Drones = preload("res://Control/Control/items/item_db_drones.gd")
const BaseResources = preload("res://Control/Control/items/item_db_base_resources.gd")
const SpaceMaterials = preload("res://Control/Control/items/item_db_space_materials.gd")
const Parts = preload("res://Control/Control/items/item_db_parts.gd")
const Ammo = preload("res://Control/Control/items/item_db_ammo.gd")
const Blueprints = preload("res://Control/Control/items/item_db_blueprints.gd")
const Weapons = preload("res://Control/Control/items/item_db_weapons.gd")
const Shields = preload("res://Control/Control/items/item_db_shields.gd")
const Upgrades = preload("res://Control/Control/items/item_db_upgrades.gd")


static func build() -> Dictionary:
	var db: Dictionary = {}

	merge_item_list(db, Modules.get_items(), "item_db_modules.gd")
	merge_item_list(db, Consumables.get_items(), "item_db_consumables.gd")
	merge_item_list(db, EventItems.get_items(), "item_db_event_items.gd")
	merge_item_list(db, Drones.get_items(), "item_db_drones.gd")
	merge_item_list(db, BaseResources.get_items(), "item_db_base_resources.gd")
	merge_item_list(db, SpaceMaterials.get_items(), "item_db_space_materials.gd")
	merge_item_list(db, Parts.get_items(), "item_db_parts.gd")
	merge_item_list(db, Ammo.get_items(), "item_db_ammo.gd")
	merge_item_list(db, Blueprints.get_items(), "item_db_blueprints.gd")
	merge_item_list(db, Weapons.get_items(), "item_db_weapons.gd")
	merge_item_list(db, Shields.get_items(), "item_db_shields.gd")
	merge_item_list(db, Upgrades.get_items(), "item_db_upgrades.gd")

	return db


static func merge_item_list(db: Dictionary, incoming: Dictionary, source_name: String) -> void:
	for item_id in incoming.keys():
		var clean_id := str(item_id).strip_edges()
		if clean_id == "":
			push_error("Item database has a blank item id in " + source_name)
			continue

		if db.has(clean_id):
			push_error("Duplicate item_id in item database: " + clean_id + " from " + source_name)
			continue

		var item_data = incoming[item_id]
		if typeof(item_data) != TYPE_DICTIONARY:
			push_error("Item database entry is not a Dictionary: " + clean_id + " from " + source_name)
			continue

		var clean_data: Dictionary = item_data.duplicate(true)

		if not clean_data.has("id"):
			clean_data["id"] = clean_id

		if not clean_data.has("item_id"):
			clean_data["item_id"] = clean_id

		db[clean_id] = clean_data
