extends Node

# =========================================================
# 🧱 CLASS DECLARATION — INVENTORY CORE
# =========================================================
class_name Inventory


# =========================================================
# 🔗 EXTERNAL STATE LINK
# ---------------------------------------------------------
# This connects to your UI state system (WidgetsState)
# Used later for logging + UI updates
# =========================================================
var state : WidgetsState5


# =========================================================
# 🔌 CONNECTED SYSTEMS
# ---------------------------------------------------------
# Handles item lookup, textures, metadata, etc
# =========================================================
var item_handler: ItemHandler


# =========================================================
# 🎨 UI TEXTURES
# ---------------------------------------------------------
# Base textures for:
# - normal inventory slots
# - drone bay slots
# =========================================================
var tex_cell   = preload("res://images/inv_cell.png")
var drone_cell = preload("res://images/drone_bay2.png")


# =========================================================
# 📦 SLOT STORAGE — DATA STRUCTURES
# ---------------------------------------------------------
# Format example:
#
# cells["each_cell"]["row 0 - col0"] = {
#     "item_id": "",
#     "count": 0,
#     "button": <TextureButton>
# }
# =========================================================
var cells := {}
var drone_cells := {}


# =========================================================
# 🪟 ROOT UI CONTAINERS
# ---------------------------------------------------------
# These are the parent Control nodes that hold the buttons
# =========================================================
var inventory_root: Control
var drone_bay_root: Control


# =========================================================
# ✋ HOLD SYSTEM — CLICK / DRAG SIMULATION
# ---------------------------------------------------------
# Stores:
# - which slot is being "held"
# - which container it came from
# =========================================================
var hold_item_slot_name = null
var hold_item_container_name := ""


# =========================================================
# ⚙️ SETUP — CONNECT EXTERNAL SYSTEMS
# =========================================================
func setup(new_item_handler: ItemHandler) -> void:
	item_handler = new_item_handler


# =========================================================
# 🧱 BUILD MAIN INVENTORY GRID
# =========================================================
func buildit(pos: Vector2, padding: int = 4, outer_padding: int = 4) -> void:

	# -----------------------------------------
	# Create root container
	# -----------------------------------------
	inventory_root = Control.new()
	add_child(inventory_root)

	# -----------------------------------------
	# Layout math
	# -----------------------------------------
	var cell_size := 32
	var step := cell_size + padding

	var cell_x := 32 * 10   # width (10 columns)
	var cell_y := 32 * 6    # height (6 rows)

	# -----------------------------------------
	# Apply size + position
	# -----------------------------------------
	inventory_root.size = Vector2(cell_x, cell_y)
	inventory_root.position = pos

	# -----------------------------------------
	# Reset storage
	# -----------------------------------------
	cells.clear()
	cells["each_cell"] = {}

	# -----------------------------------------
	# Build grid
	# -----------------------------------------
	for row in range(6):
		for col in range(10):

			var tex := TextureButton.new()

			# Build slot name
			var slot_name = make_slot_name(row, col)

			# Assign name (CRITICAL for lookup later)
			tex.name = slot_name

			if Globals.print_priority_3:
				print(str(tex.name))

			# Assign visuals
			tex.texture_normal = tex_cell
			tex.size = Vector2(32, 32)

			# Position in grid
			tex.position = Vector2(col * step, row * step)

			# Connect click signal
			tex.pressed.connect(_on_but_pressed.bind(tex))

			# Scaling mode for textures
			tex.stretch_mode = TextureButton.STRETCH_SCALE

			# Add to scene
			inventory_root.add_child(tex)

			# Store slot data
			cells["each_cell"][slot_name] = {
				"item_id": "",
				"count": 0,
				"button": tex
			}


# =========================================================
# 🚁 BUILD DRONE BAY
# =========================================================
func build_drone_bay(pos: Vector2, padding: int = 4, outer_padding: int = 4) -> void:

	drone_bay_root = Control.new()
	add_child(drone_bay_root)

	# Layout
	var step := 64 + padding
	var cell_x := 64 * 4
	var cell_y := 64

	drone_bay_root.size = Vector2(cell_x, cell_y)
	drone_bay_root.position = pos

	# Reset storage
	drone_cells.clear()
	drone_cells["each_cell"] = {}

	# Build row
	for col in range(4):

		var d_cell := TextureButton.new()
		var slot_name := make_slot_name(0, col)

		d_cell.name = slot_name
		d_cell.texture_normal = drone_cell
		d_cell.size = Vector2(64, 64)
		d_cell.position = Vector2(col * step, 0)

		d_cell.pressed.connect(_on_but_pressed.bind(d_cell))
		d_cell.stretch_mode = TextureButton.STRETCH_SCALE

		drone_bay_root.add_child(d_cell)

		drone_cells["each_cell"][slot_name] = {
			"item_id": "",
			"count": 0,
			"button": d_cell
		}


# =========================================================
# 🧠 SLOT HELPERS
# =========================================================

func make_empty_slot() -> Dictionary:
	return {
		"item_id": "",
		"count": 0
	}


func is_main_slot(slot_name: String) -> bool:
	return slot_name in cells.get("each_cell", {})


func is_drone_slot(slot_name: String) -> bool:
	return slot_name in drone_cells.get("each_cell", {})


func get_slot_data(slot_name: String) -> Dictionary:
	if is_main_slot(slot_name):
		return cells["each_cell"][slot_name]

	if is_drone_slot(slot_name):
		return drone_cells["each_cell"][slot_name]

	return {}


func slot_has_item(slot_name: String) -> bool:
	var slot = get_slot_data(slot_name)

	if slot.is_empty():
		return false

	return slot["item_id"] != "" and slot["count"] > 0


# =========================================================
# 📥 SET ITEM INTO SLOT
# =========================================================
func set_slot_item(slot_name: String, item_id: String, count: int = 1) -> void:

	# Safety check
	if item_handler == null:
		if Globals.print_priority_1:
			print("Missing item_handler")
		return

	# Get icon texture
	var tex = item_handler.get_item_texture(item_id)

	# MAIN INVENTORY
	if slot_name in cells["each_cell"]:
		cells["each_cell"][slot_name]["item_id"] = item_id
		cells["each_cell"][slot_name]["count"] = count

		if tex != null:
			cells["each_cell"][slot_name]["button"].texture_normal = tex
		return

	# DRONE BAY
	if slot_name in drone_cells["each_cell"]:
		drone_cells["each_cell"][slot_name]["item_id"] = item_id
		drone_cells["each_cell"][slot_name]["count"] = count

		if tex != null:
			drone_cells["each_cell"][slot_name]["button"].texture_normal = tex
		return

	if Globals.print_priority_1:
		print("Slot not found: ", slot_name)
# =========================================================
# 🔍 CHECK FOR ITEMS
# =========================================================

func has_item_anywhere(item_id: String) -> bool:

	# -----------------------------------------
	# Search main inventory
	# -----------------------------------------
	for slot_name in cells["each_cell"]:
		var slot = cells["each_cell"][slot_name]

		if slot["item_id"] == item_id and slot["count"] > 0:
			return true

	# -----------------------------------------
	# Search drone bay
	# -----------------------------------------
	for slot_name in drone_cells["each_cell"]:
		var slot = drone_cells["each_cell"][slot_name]

		if slot["item_id"] == item_id and slot["count"] > 0:
			return true

	return false


func count_item_anywhere(item_id: String) -> int:

	# -----------------------------------------
	# Total counter
	# -----------------------------------------
	var total := 0

	# -----------------------------------------
	# Count matching items in main inventory
	# -----------------------------------------
	for slot_name in cells["each_cell"]:
		var slot = cells["each_cell"][slot_name]

		if slot["item_id"] == item_id:
			total += slot["count"]

	# -----------------------------------------
	# Count matching items in drone bay
	# -----------------------------------------
	for slot_name in drone_cells["each_cell"]:
		var slot = drone_cells["each_cell"][slot_name]

		if slot["item_id"] == item_id:
			total += slot["count"]

	return total


# =========================================================
# 🧩 MODULE CHECKS
# ---------------------------------------------------------
# For now, modules in main inventory count as "owned".
# Later this can split into:
# - installed modules
# - cargo modules
# - equipped systems
# =========================================================

func has_module(item_id: String) -> bool:

	# -----------------------------------------
	# Make sure the item exists in the item DB
	# -----------------------------------------
	if not item_handler.has_item(item_id):
		return false

	# -----------------------------------------
	# Pull item metadata
	# -----------------------------------------
	var data = item_handler.get_item_data(item_id)

	# -----------------------------------------
	# Only module-type items pass this check
	# -----------------------------------------
	if data.get("type", "") != "module":
		return false

	# -----------------------------------------
	# Confirm the module exists somewhere
	# -----------------------------------------
	return has_item_anywhere(item_id)


# =========================================================
# 🍽 CONSUME ITEM
# ---------------------------------------------------------
# Removes a requested amount of an item from inventory.
# It searches:
# 1. Main inventory
# 2. Drone bay
#
# Returns:
# true  -> enough items were consumed
# false -> not enough items were found
# =========================================================

func consume_item(item_id: String, amount: int = 1) -> bool:

	# -----------------------------------------
	# Track how many still need removed
	# -----------------------------------------
	var remaining := amount

	# -----------------------------------------
	# Consume from main inventory first
	# -----------------------------------------
	for slot_name in cells["each_cell"]:
		var slot = cells["each_cell"][slot_name]

		if slot["item_id"] == item_id and slot["count"] > 0:
			var take = min(slot["count"], remaining)

			slot["count"] -= take
			remaining -= take

			# ---------------------------------
			# Empty the slot if count hits zero
			# ---------------------------------
			if slot["count"] <= 0:
				slot["item_id"] = ""
				slot["count"] = 0

			# ---------------------------------
			# Finished consuming requested amount
			# ---------------------------------
			if remaining <= 0:
				return true

	# -----------------------------------------
	# Consume from drone bay second
	# -----------------------------------------
	for slot_name in drone_cells["each_cell"]:
		var slot = drone_cells["each_cell"][slot_name]

		if slot["item_id"] == item_id and slot["count"] > 0:
			var take = min(slot["count"], remaining)

			slot["count"] -= take
			remaining -= take

			# ---------------------------------
			# Empty the slot if count hits zero
			# ---------------------------------
			if slot["count"] <= 0:
				slot["item_id"] = ""
				slot["count"] = 0

			# ---------------------------------
			# Finished consuming requested amount
			# ---------------------------------
			if remaining <= 0:
				return true

	return false


# =========================================================
# 🧾 DEBUG — PRINT INVENTORY CONTENTS
# =========================================================

func print_inventory() -> void:

	if Globals.print_priority_3:
		print("---- MAIN INVENTORY ----")

	# -----------------------------------------
	# Print filled main inventory slots
	# -----------------------------------------
	for slot_name in cells["each_cell"]:
		var slot = cells["each_cell"][slot_name]

		if slot["item_id"] != "":
			if Globals.print_priority_3:
				print(slot_name, " -> ", slot)

	if Globals.print_priority_3:
		print("---- DRONE BAY ----")

	# -----------------------------------------
	# Print filled drone bay slots
	# -----------------------------------------
	for slot_name in drone_cells["each_cell"]:
		var slot = drone_cells["each_cell"][slot_name]

		if slot["item_id"] != "":
			if Globals.print_priority_3:
				print(slot_name, " -> ", slot)


# =========================================================
# 🖱 SLOT CLICK HANDLER
# ---------------------------------------------------------
# This is the heart of the inventory click system.
#
# It handles:
# - detecting which slot was clicked
# - printing inventory state
# - selecting a held slot
# - swapping on second click
# - showing item details in the log
# =========================================================

func _on_but_pressed(btn: TextureButton) -> void:

	# -----------------------------------------
	# The button name IS the slot name
	# -----------------------------------------
	var slot_name = btn.name

	if Globals.print_priority_3:
		print("---- CLICKED:", slot_name, "----")


	# ===============================
	# PRINT FULL MAIN INVENTORY
	# ===============================
	if Globals.print_priority_3:
		print("---- MAIN INVENTORY ----")

	for key in cells["each_cell"]:
		if Globals.print_priority_3:
			print(key, " -> ", cells["each_cell"][key])


	# ===============================
	# PRINT DRONE BAY
	# ===============================
	if Globals.print_priority_3:
		print("---- DRONE BAY ----")

	for key in drone_cells["each_cell"]:
		if Globals.print_priority_3:
			print(key, " -> ", drone_cells["each_cell"][key])


	# ===============================
	# FIGURE OUT WHICH CONTAINER WAS CLICKED
	# ===============================

	var clicked_container = null
	var clicked_container_name := ""

	# -----------------------------------------
	# Was it a main inventory slot?
	# -----------------------------------------
	if slot_name in cells["each_cell"]:
		clicked_container = cells["each_cell"]
		clicked_container_name = "main"

	# -----------------------------------------
	# Was it a drone bay slot?
	# -----------------------------------------
	elif slot_name in drone_cells["each_cell"]:
		clicked_container = drone_cells["each_cell"]
		clicked_container_name = "drone"

	# -----------------------------------------
	# Safety fallback
	# -----------------------------------------
	else:
		if Globals.print_priority_1:
			print("Slot name not found in inventory dictionaries")
		return

	# -----------------------------------------
	# Pull the clicked slot data
	# -----------------------------------------
	var slot = clicked_container[slot_name]


	# ===============================
	# SECOND CLICK — SWAP HELD SLOT WITH CLICKED SLOT
	# ===============================
	if hold_item_slot_name != null:
		swap_held_slot_with(clicked_container_name, slot_name)

		hold_item_slot_name = null
		hold_item_container_name = ""

		# refresh_inventory_icons()

		return


	# ===============================
	# EMPTY SLOT CHECK
	# ===============================
	if slot["item_id"] == "":

		if clicked_container_name == "main":
			if Globals.print_priority_3:
				print("Empty main inventory slot")
		else:
			if Globals.print_priority_3:
				print("Empty drone bay slot")

		return


	# ===============================
	# FIRST CLICK — HOLD THIS SLOT
	# ===============================
	hold_item_slot_name = slot_name
	hold_item_container_name = clicked_container_name

	if Globals.print_priority_3:
		print("Holding slot: ", hold_item_container_name, " / ", hold_item_slot_name)


	# ===============================
	# MAIN INVENTORY LOG INFO
	# ===============================
	if clicked_container_name == "main":

		var item_name = item_handler.get_item_name(slot["item_id"])
		var item_data = item_handler.item_db[slot["item_id"]]

		var t := ""

		for key in item_data:
			t += "\n" + str(key) + " : " + str(item_data[key])

		state.log_storage["log_text"].text = item_name + "\n" + t

		return


	# ===============================
	# DRONE BAY LOG INFO
	# ===============================
	if clicked_container_name == "drone":

		var drone_item_name = item_handler.get_item_name(slot["item_id"])

		if Globals.print_priority_3:
			print("Clicked drone bay item: " + drone_item_name)

		return


# =========================================================
# 🏷 SLOT NAME BUILDER
# ---------------------------------------------------------
# Keeps all slot naming consistent across:
# - main inventory
# - drone bay
# - starter item placement
# - click lookup
# =========================================================

func make_slot_name(row: int, col: int) -> String:
	return "row %d - col%d" % [row, col]


# =========================================================
# 🎁 STARTER ITEMS
# ---------------------------------------------------------
# Places the starting equipment into known inventory slots.
# =========================================================

func give_starter_items() -> void:

	set_slot_item(make_slot_name(0, 0), "scan_module_mk1", 1)
	set_slot_item(make_slot_name(0, 1), "drone_controller_mk1", 1)
	set_slot_item(make_slot_name(0, 2), "scout_drone", 2)


# =========================================================
# 🔄 SWAP HELD SLOT WITH TARGET SLOT
# ---------------------------------------------------------
# This performs the actual inventory swap.
#
# It swaps:
# - item_id
# - count
# - visual texture
# =========================================================

func swap_held_slot_with(to_container_name: String, to_slot_name: String) -> void:

	# -----------------------------------------
	# Find source + destination containers
	# -----------------------------------------
	var from_container = get_container_by_name(hold_item_container_name)
	var to_container = get_container_by_name(to_container_name)

	# -----------------------------------------
	# Safety check
	# -----------------------------------------
	if from_container == null or to_container == null:
		if Globals.print_priority_1:
			print("Could not swap. Bad container.")
		return

	# -----------------------------------------
	# Pull slot dictionaries
	# -----------------------------------------
	var from_slot = from_container[hold_item_slot_name]
	var to_slot = to_container[to_slot_name]


	# -------------------------------
	# SWAP DATA
	# -------------------------------

	var temp_item = from_slot["item_id"]
	var temp_count = from_slot["count"]

	from_slot["item_id"] = to_slot["item_id"]
	from_slot["count"] = to_slot["count"]

	to_slot["item_id"] = temp_item
	to_slot["count"] = temp_count


	# -------------------------------
	# SWAP VISUAL TEXTURES TOO
	# -------------------------------

	var from_button : TextureButton = from_slot["button"]
	var to_button : TextureButton = to_slot["button"]

	var temp_texture = from_button.texture_normal

	from_button.texture_normal = to_button.texture_normal
	to_button.texture_normal = temp_texture

	if Globals.print_priority_3:
		print("Swapped ", hold_item_slot_name, " with ", to_slot_name)


# =========================================================
# 🖼 REFRESH INVENTORY ICONS
# ---------------------------------------------------------
# Rebuilds main inventory visuals from the current item data.
#
# Empty slot:
# - gets default inventory cell texture
#
# Filled slot:
# - tries to use item icon from item_db
# - falls back to default cell texture
# =========================================================

func refresh_inventory_icons() -> void:

	# -----------------------------------------
	# Walk every main inventory slot
	# -----------------------------------------
	for slot_name in cells["each_cell"]:

		var slot = cells["each_cell"][slot_name]
		var btn: TextureButton = slot["button"]

		# -------------------------------------
		# Empty slot gets default texture
		# -------------------------------------
		if slot["item_id"] == "":
			btn.texture_normal = tex_cell

		# -------------------------------------
		# Filled slot gets item icon if possible
		# -------------------------------------
		else:
			var item_id = slot["item_id"]

			if item_handler.item_db.has(item_id) and item_handler.item_db[item_id].has("icon"):
				btn.texture_normal = item_handler.item_db[item_id]["icon"]
			else:
				btn.texture_normal = tex_cell


# =========================================================
# 📦 GET CONTAINER BY NAME
# ---------------------------------------------------------
# Converts simple string names into the correct dictionary.
#
# "main"  -> cells["each_cell"]
# "drone" -> drone_cells["each_cell"]
# =========================================================

func get_container_by_name(container_name: String):

	if container_name == "main":
		return cells["each_cell"]

	if container_name == "drone":
		return drone_cells["each_cell"]

	return null
