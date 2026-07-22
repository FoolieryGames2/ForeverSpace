extends Node
class_name ItemHandler


# ==========================================================
# ITEM HANDLER
# ----------------------------------------------------------
# Inventory stores ONLY item_id strings.
# This handler looks up:
# - item names
# - item types
# - granted actions
# - atlas textures
# - atlas regions
#
# IMPORTANT:
# Every item uses the SAME image format:
#
# "atlas": "atlas_key",
# "region": Rect2(x, y, w, h)
#
# EXPORT SAFETY NOTE:
# Do not hard-preload optional icon/atlas files here. A single missing PNG
# causes ItemHandler to fail compilation in exported builds, which then causes
# Inventory5, SaveManager, and StartMenu to fail too. Runtime load keeps the
# item database alive even if one icon sheet is missing.
# ==========================================================
var iron_img: Texture2D = null
var colbalt_img: Texture2D = null
var nickel_img: Texture2D = null
var laser_mk1: Texture2D = null

# ==========================================================
# ATLAS TEXTURE FILES
# ----------------------------------------------------------
# Add new sprite sheets here. Loaded at runtime for export safety.
# ==========================================================
var atlases: Dictionary = {}
var printed_missing_texture_paths: Dictionary = {}

const ITEM_HANDLER_TEXTURE_CANDIDATES := {
	"iron_img": ["res://images/iron.png"],
	"colbalt_img": ["res://images/cobalt.png"],
	"nickel_img": ["res://images/nickel.png"],
	"laser_mk1": ["res://images/laser_mk_1_resiz.png"],
	"item_sheet_test": ["res://images/items2.png"],
	"drone_sheet": [
		"res://images/Drone5.png",
		"res://images/drone5.png",
		"res://images/Drone5.PNG",
		"res://images/drone5.PNG",
		"res://images/DRONE5.png",
		"res://Images/Drone5.png",
		"res://images/drones/Drone5.png",
		"res://images/drones/drone5.png"
	]
}


func load_item_handler_visual_resources(reason: String = "manual") -> void:
	# Summary: Runtime-load textures so missing optional art cannot break export boot.
	iron_img = safe_load_item_texture(ITEM_HANDLER_TEXTURE_CANDIDATES.get("iron_img", []), "iron_img", reason)
	colbalt_img = safe_load_item_texture(ITEM_HANDLER_TEXTURE_CANDIDATES.get("colbalt_img", []), "colbalt_img", reason)
	nickel_img = safe_load_item_texture(ITEM_HANDLER_TEXTURE_CANDIDATES.get("nickel_img", []), "nickel_img", reason)
	laser_mk1 = safe_load_item_texture(ITEM_HANDLER_TEXTURE_CANDIDATES.get("laser_mk1", []), "laser_mk1", reason)

	atlases.clear()
	var item_sheet := safe_load_item_texture(ITEM_HANDLER_TEXTURE_CANDIDATES.get("item_sheet_test", []), "atlas:item_sheet_test", reason)
	if item_sheet != null:
		atlases["item_sheet_test"] = item_sheet

	var drone_sheet := safe_load_item_texture(ITEM_HANDLER_TEXTURE_CANDIDATES.get("drone_sheet", []), "atlas:drone_sheet", reason)
	if drone_sheet != null:
		atlases["drone_sheet"] = drone_sheet
	else:
		print("[ITEM_HANDLER_ATLAS_DISABLED] atlas=drone_sheet reason=missing_texture compile_safe=true inventory_can_continue=true")

	print("[ITEM_HANDLER_TEXTURE_REPORT]",
		" reason=", reason,
		" atlases=", atlases.keys(),
		" has_item_sheet=", atlases.has("item_sheet_test"),
		" has_drone_sheet=", atlases.has("drone_sheet")
	)


func safe_load_item_texture(candidate_paths: Array, resource_label: String, reason: String = "manual") -> Texture2D:
	for raw_path in candidate_paths:
		var path := str(raw_path).strip_edges()
		if path == "":
			continue

		if ResourceLoader.exists(path):
			var loaded = load(path)
			if loaded is Texture2D:
				print("[ITEM_HANDLER_TEXTURE_LOADED] label=", resource_label, " path=", path, " reason=", reason)
				return loaded as Texture2D

			print("[ITEM_HANDLER_TEXTURE_BAD_TYPE] label=", resource_label, " path=", path, " loaded=", loaded, " reason=", reason)

	if not printed_missing_texture_paths.has(resource_label):
		printed_missing_texture_paths[resource_label] = true
		print("[ITEM_HANDLER_TEXTURE_MISSING] label=", resource_label, " candidates=", candidate_paths, " reason=", reason)

	return null


# ==========================================================
# DRONE ATLAS HELPERS
# ----------------------------------------------------------
# The drone sheet is arranged as:
# 6 columns x 3 rows
# Each drone cell is 64x64.
# ==========================================================
const DRONE_CELL_SIZE := 64

var drone_slots := {
	"roamer": Vector2i(0, 3),
	"scout": Vector2i(0, 0),
	"miner": Vector2i(0, 1),
	"cargo": Vector2i(0, 1),
	"repair": Vector2i(0, 1),
	"surveyor": Vector2i(0, 0),

	"comms": Vector2i(0, 1),
	"sensor": Vector2i(1, 1),
	"atmos": Vector2i(2, 1),
	"seismic": Vector2i(3, 1),
	"probe": Vector2i(4, 1),
	"ice": Vector2i(5, 1),

	"agro": Vector2i(0, 2),
	"defense": Vector2i(1, 2),
	"decoy": Vector2i(2, 2),
	"micro": Vector2i(3, 2),
	"deep": Vector2i(4, 2),
	"lander": Vector2i(0, 2)
}


func drone_region(drone_key: String) -> Rect2:
	if not drone_slots.has(drone_key):
		if Globals.print_priority_1:
			print("Missing drone atlas key: ", drone_key)
		return Rect2()

	var slot: Vector2i = drone_slots[drone_key]

	return Rect2(
		slot.x * DRONE_CELL_SIZE,
		slot.y * DRONE_CELL_SIZE,
		DRONE_CELL_SIZE,
		DRONE_CELL_SIZE
	)


# ==========================================================
# ITEM DATABASE
# ----------------------------------------------------------
# Database content now lives in separated data-only scripts under:
# res://Control/items/
# ItemHandler remains the behavior/API owner.
# ==========================================================
const ITEM_DB_BUILDER = preload("res://Control/Control/items/item_db_builder.gd")

var item_db: Dictionary = ITEM_DB_BUILDER.build()



var item_shared_meta_normalized := false


func _init() -> void:
	load_item_handler_visual_resources("init")


func _ready() -> void:
	load_item_handler_visual_resources("ready")
	normalize_item_shared_meta()


func normalize_item_shared_meta() -> void:
	# Summary: Ensure every item definition carries the shared object/event/lore meta block.
	if item_shared_meta_normalized:
		return

	for item_id in item_db.keys():
		var item_data = item_db.get(item_id, {})
		if typeof(item_data) != TYPE_DICTIONARY:
			continue
		item_db[item_id] = normalize_item_data_shared_meta(str(item_id), item_data)

	item_shared_meta_normalized = true


func normalize_item_data_shared_meta(item_id: String, item_data: Dictionary) -> Dictionary:
	# Summary: Add shared meta without changing item-owned weapon/shield/consumable stats.
	var clean_item_id := str(item_data.get("item_id", item_data.get("id", item_id))).strip_edges()
	if clean_item_id == "":
		clean_item_id = item_id

	var item_type := str(item_data.get("item_type", item_data.get("type", "item"))).strip_edges()
	if item_type == "":
		item_type = "item"

	var display := str(item_data.get("display_name", item_data.get("name", clean_item_id))).strip_edges()
	if display == "":
		display = clean_item_id

	return SharedObjectMeta.apply_to_dictionary(
		item_data,
		clean_item_id,
		"item_" + item_type,
		display,
		Vector3i.ZERO,
		Vector3.ZERO
	)


# ==========================================================
# BASIC ITEM LOOKUPS
# ==========================================================
func has_item(item_id: String) -> bool:
	return item_db.has(item_id)


func get_item_data(item_id: String) -> Dictionary:
	normalize_item_shared_meta()
	if item_db.has(item_id):
		return item_db[item_id]

	return {}


func get_item_name(item_id: String) -> String:
	if item_db.has(item_id):
		return item_db[item_id].get("name", "Unnamed Item")

	return "Unknown Item"


# ==========================================================
# ITEM TEXTURE LOOKUP
# ----------------------------------------------------------
# This now works for:
# - modules
# - consumables
# - drones
# - resources later
#
# Anything with:
# "atlas": "atlas_key"
# "region": Rect2(...)
# can be displayed the exact same way.
# ==========================================================
func get_item_texture(item_id: String) -> Texture2D:
	if not item_db.has(item_id):
		if Globals.print_priority_1:
			print("Missing item id: ", item_id)
		return null

	var data: Dictionary = item_db[item_id]

	# Direct image texture support
	if data.has("texture"):
		return data["texture"]

	# Atlas texture support
	var atlas_name: String = data.get("atlas", "")
	var region: Rect2 = data.get("region", Rect2())

	if atlas_name == "":
		if Globals.print_priority_3:
			print("Item has no atlas: ", item_id)
		return null

	if region == Rect2():
		if Globals.print_priority_3:
			print("Item has no region: ", item_id)
		return null

	if not atlases.has(atlas_name):
		if Globals.print_priority_1:
			print("Missing atlas: ", atlas_name, " for item: ", item_id)
		return null

	var atlas_texture = atlases.get(atlas_name, null)
	if atlas_texture == null:
		if Globals.print_priority_1:
			print("Null atlas texture: ", atlas_name, " for item: ", item_id)
		return null

	var tex := AtlasTexture.new()
	tex.atlas = atlas_texture
	tex.region = region

	return tex
