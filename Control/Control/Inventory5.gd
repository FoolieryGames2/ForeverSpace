extends Node

# =========================================================
# 🧱 CLASS DECLARATION — INVENTORY CORE
# =========================================================
class_name Inventory5


# Emitted by every data-changing inventory operation.
# Main mode uses this to keep blueprint/action readiness live instead of stale.
signal inventory_changed(reason: String)

const LABEL_INVENTORY_TABS := [
	{"id": "all", "text": "ALL", "width": 42.0},
	{"id": "recovery", "text": "REC", "width": 46.0},
	{"id": "weapon", "text": "WPN", "width": 48.0},
	{"id": "shield", "text": "SHD", "width": 48.0},
	{"id": "module", "text": "MOD", "width": 48.0},
	{"id": "res", "text": "RES", "width": 44.0},
	{"id": "cons", "text": "CON", "width": 46.0},
	{"id": "blue", "text": "BP", "width": 42.0},
	{"id": "drone", "text": "DRN", "width": 48.0},
	{"id": "ammo", "text": "AMO", "width": 48.0},
	{"id": "parts", "text": "PRT", "width": 48.0},
	{"id": "slots", "text": "SLOT", "width": 52.0}
]
const LABEL_INVENTORY_TAB_IDS := ["all", "recovery", "weapon", "shield", "module", "res", "cons", "blue", "drone", "ammo", "parts", "slots"]
const RECOVERY_CONSUMABLE_GROUPS := ["repair", "shield_repair", "recharge"]
const RECYCLE_REWARD_ITEM_ID := "iron"
const RECYCLE_REWARD_AMOUNT := 100
const RECYCLE_BLOCKED_ITEM_IDS := ["scan_module_mk1", "drone_controller_mk1"]
const LABEL_INVENTORY_NEW_MODULATE := Color(1.0, 0.88, 0.38, 1.0)


# =========================================================
# 🔗 EXTERNAL STATE LINK
# ---------------------------------------------------------
# This connects to your UI state system (WidgetsState)
# Used later for logging + UI updates
# =========================================================
var state : WidgetsState5
var npc_use_state  = null

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

var widget_state = null
var recovery_use_owner = null

# =========================================================
# 🪟 ROOT UI CONTAINERS
# ---------------------------------------------------------
# These are the parent Control nodes that hold the buttons
# =========================================================
var inventory_root: Control
var drone_bay_root: Control
var label_inventory_root: Control
var label_inventory_list: VBoxContainer
var label_inventory_tab_cargo: Button
var label_inventory_tab_drone: Button
var label_inventory_tab_bar_scroll: ScrollContainer
var label_inventory_tab_bar: HBoxContainer
var label_inventory_category_buttons := {}
var label_inventory_active_tab := "all"
var label_inventory_active_category := "all"
var label_inventory_rows := []
var label_inventory_use_button: Button
var label_inventory_recycle_drop_box: Button
var label_inventory_recycle_status_label: Label
var label_inventory_selected_recovery_container := ""
var label_inventory_selected_recovery_slot := ""
var label_press_row: Button = null
var label_press_slot_name := ""
var label_press_container_name := ""
var label_press_start_msec := 0
var label_press_start_pos := Vector2.ZERO
var label_drag_active := false
var label_drag_just_finished := false
var label_drag_preview: Label = null
var inventory_interaction_enabled := true
var intel_handler = null
var intel_save_callable := Callable()
var intel_inventory_totals: Dictionary = {}
var intel_sync_suppressed := false


# =========================================================
# ✋ HOLD SYSTEM — CLICK / DRAG SIMULATION
# ---------------------------------------------------------
# Stores:
# - which slot is being "held"
# - which container it came from
# =========================================================
var hold_item_slot_name = null
var hold_item_container_name := ""
var selected_slot_name = null
var selected_container_name := ""
var press_slot_name = null
var press_container_name := ""
var press_button: TextureButton = null
var press_start_msec := 0
var press_start_pos := Vector2.ZERO
var drag_active := false
var drag_just_finished := false
var drag_long_press_msec := 250
var drag_start_distance := 8.0
var drag_preview: TextureRect = null


func set_inventory_interaction_enabled(enabled: bool) -> void:
	# Summary: Enable or disable inventory clicks/drags when another panel owns this UI space.
	inventory_interaction_enabled = enabled
	set_process(enabled)
	set_process_input(enabled)

	if Globals.print_priority_2:
		print("Inventory interaction enabled: ", enabled)

	if enabled:
		return

	cleanup_drag_state()
	cleanup_label_drag_state()
	drag_just_finished = false
	label_drag_just_finished = false


func notify_inventory_changed(reason: String = "changed") -> void:
	# Summary: Single exit point for inventory data mutations.
	# It keeps the label inventory current and lets main mode refresh blueprint readiness.
	var intel_changed := sync_intel_discovery_from_inventory(reason)
	refresh_label_inventory_rows()
	if intel_changed and not should_defer_intel_save_for_inventory_reason(reason):
		save_intel_if_available()
	emit_signal("inventory_changed", reason)


const SLOT_MODULATE_NORMAL := Color(1, 1, 1, 1)
const SLOT_MODULATE_SELECTED := Color(0.65, 0.9, 1.0, 1.0)
const SLOT_MODULATE_DRAG_SOURCE := Color(1, 1, 1, 0.45)


# =========================================================
# ⚙️ SETUP — CONNECT EXTERNAL SYSTEMS
# =========================================================
func setup(new_item_handler: ItemHandler) -> void:
	item_handler = new_item_handler


func set_intel_handler(handler) -> void:
	intel_handler = handler
	remember_intel_inventory_totals()
	refresh_label_inventory_rows()


func set_intel_save_callable(callable_value: Callable) -> void:
	intel_save_callable = callable_value


func set_recovery_use_owner(new_owner) -> void:
	recovery_use_owner = new_owner


# =========================================================
# 🧱 BUILD MAIN INVENTORY GRID
# =========================================================
func save_intel_if_available() -> bool:
	if intel_save_callable.is_valid():
		return bool(intel_save_callable.call())
	if intel_handler != null and intel_handler.has_method("save_to_universe_if_available"):
		return bool(intel_handler.save_to_universe_if_available())
	return false


func should_defer_intel_save_for_inventory_reason(reason: String) -> bool:
	return reason.begins_with("event_reward")


func sync_intel_discovery_from_inventory(reason: String = "changed") -> bool:
	if intel_sync_suppressed:
		remember_intel_inventory_totals()
		return false
	if intel_handler == null or not intel_handler.has_method("record_discovery"):
		remember_intel_inventory_totals()
		return false

	var totals := collect_intel_inventory_totals(reason)
	var changed := false

	for item_id in totals.keys():
		var item_packet: Dictionary = totals[item_id]
		var current_count := int(item_packet.get("total_count", 0))
		var previous_count := int(intel_inventory_totals.get(item_id, 0))
		if current_count <= previous_count:
			continue

		var source_packet := item_packet.duplicate(true)
		source_packet["previous_total_count"] = previous_count
		source_packet["count_delta"] = current_count - previous_count
		var result = intel_handler.record_discovery(str(item_id), str(source_packet.get("category", "item")), source_packet)
		if typeof(result) == TYPE_DICTIONARY and bool(result.get("ok", false)):
			changed = changed or bool(result.get("is_new", false))

	intel_inventory_totals = extract_intel_inventory_total_counts(totals)
	return changed


func remember_intel_inventory_totals() -> void:
	intel_inventory_totals = extract_intel_inventory_total_counts(collect_intel_inventory_totals("remember"))


func extract_intel_inventory_total_counts(totals: Dictionary) -> Dictionary:
	var out := {}
	for item_id in totals.keys():
		var item_packet = totals[item_id]
		if typeof(item_packet) == TYPE_DICTIONARY:
			out[str(item_id)] = int(item_packet.get("total_count", 0))
	return out


func collect_intel_inventory_totals(reason: String = "changed") -> Dictionary:
	var totals := {}
	append_intel_inventory_totals_from_container(totals, "main", cells, reason)
	append_intel_inventory_totals_from_container(totals, "drone", drone_cells, reason)
	return totals


func append_intel_inventory_totals_from_container(totals: Dictionary, container_name: String, container_slots: Dictionary, reason: String) -> void:
	if not container_slots.has("each_cell"):
		return

	for slot_name in container_slots["each_cell"]:
		var slot = container_slots["each_cell"][slot_name]
		if typeof(slot) != TYPE_DICTIONARY:
			continue

		var item_id := str(slot.get("item_id", "")).strip_edges()
		var count := int(slot.get("count", 0))
		if item_id == "" or count <= 0:
			continue

		var source := build_intel_source_packet(item_id, count, container_name, str(slot_name), slot, reason)
		var entry = totals.get(item_id, {})
		if typeof(entry) != TYPE_DICTIONARY or entry.is_empty():
			entry = source
			entry["total_count"] = count
		else:
			entry["total_count"] = int(entry.get("total_count", 0)) + count
		totals[item_id] = entry


func build_intel_source_packet(item_id: String, count: int, container_name: String, slot_name: String, slot: Dictionary, reason: String) -> Dictionary:
	var item_data := {}
	var item_name := item_id
	if item_handler != null:
		item_name = item_handler.get_item_name(item_id)
		item_data = item_handler.get_item_data(item_id)
	var item_type := str(item_data.get("type", item_data.get("item_type", "item"))).strip_edges()
	var category := resolve_label_inventory_category(item_id, item_data, container_name)

	var source := item_data.duplicate(true)
	source["source"] = "inventory"
	source["reason"] = reason
	source["item_id"] = item_id
	source["item_name"] = item_name
	source["display_name"] = str(item_data.get("display_name", item_name))
	source["item_type"] = item_type
	source["subtype"] = str(item_data.get("subtype", ""))
	source["category"] = category
	source["container_name"] = container_name
	source["slot_name"] = slot_name
	source["count"] = count
	source["slot_count"] = count
	source["slot"] = slot.duplicate(true)
	return source


func inventory_intel_is_unchecked(item_id: String) -> bool:
	if intel_handler == null or not intel_handler.has_method("is_unchecked"):
		return false
	return bool(intel_handler.is_unchecked(item_id))


func mark_inventory_item_checked(item_id: String) -> bool:
	var clean_id := item_id.strip_edges()
	if clean_id == "" or intel_handler == null or not intel_handler.has_method("mark_checked"):
		return false

	var result = intel_handler.mark_checked(clean_id)
	if typeof(result) != TYPE_DICTIONARY or not bool(result.get("ok", false)):
		return false

	if bool(result.get("changed", false)):
		save_intel_if_available()
		refresh_label_inventory_rows()
		return true

	return false


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
			if Globals.debug_heat_1:
				if Globals.print_priority_3:
					print(str(tex.name))

			# Assign visuals
			tex.texture_normal = tex_cell
			tex.size = Vector2(32, 32)

			# Position in grid
			tex.position = Vector2(col * step, row * step)

			# Connect click signal
			tex.pressed.connect(_on_but_pressed.bind(tex))
			tex.button_down.connect(_on_slot_button_down.bind(tex))
			tex.button_up.connect(_on_slot_button_up.bind(tex))

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
		var slot_name := make_drone_slot_name(col)

		d_cell.name = slot_name
		d_cell.texture_normal = drone_cell
		d_cell.size = Vector2(64, 64)
		d_cell.position = Vector2(col * step, 0)

		d_cell.pressed.connect(_on_but_pressed.bind(d_cell))
		d_cell.button_down.connect(_on_slot_button_down.bind(d_cell))
		d_cell.button_up.connect(_on_slot_button_up.bind(d_cell))
		d_cell.stretch_mode = TextureButton.STRETCH_SCALE

		drone_bay_root.add_child(d_cell)

		drone_cells["each_cell"][slot_name] = {
			"item_id": "",
			"count": 0,
			"button": d_cell
		}


# =========================================================
# LABEL INVENTORY WIDGET
# ---------------------------------------------------------
# Replaces the image grid with action-style tabs and rows.
# =========================================================
func build_label_inventory_widget(pos: Vector2) -> Control:
	if Globals.print_priority_3:
		print("[INV5_DEBUG] build_label_inventory_widget ENTERED")
		print("[INV5_DEBUG] pos :: ", pos)
		print("[INV5_DEBUG] state :: ", state)
		print("[INV5_DEBUG] cells count :: ", cells.get("each_cell", {}).size())
		print("[INV5_DEBUG] drone cells count :: ", drone_cells.get("each_cell", {}).size())

	if state == null:
		if Globals.print_priority_3:
			print("[INV5_DEBUG] BLOCKED: missing state")
		return Control.new()

	# -----------------------------------------
	# Build root shell in the action panel style.
	# -----------------------------------------
	label_inventory_root = Control.new()
	label_inventory_root.name = "label_inventory_root"
	label_inventory_root.position = pos
	label_inventory_root.size = Globals.inventory_widget_size
	add_child(label_inventory_root)
	state.controls["label_inventory_root"] = label_inventory_root

	var bg := ColorRect.new()
	bg.name = "label_inventory_bg"
	bg.color = Color(0.05, 0.05, 0.08, 0.95)
	bg.position = Vector2(0, 30)
	bg.size = Vector2(label_inventory_root.size.x, label_inventory_root.size.y - 30)
	state.color_rects["label_inventory_bg"] = bg
	label_inventory_root.add_child(bg)

	build_label_inventory_tab_bar()

	# -----------------------------------------
	# Scroll body holds 25px item rows.
	# -----------------------------------------
	var scroll := ScrollContainer.new()
	scroll.name = "label_inventory_scroll"
	scroll.position = Vector2(0, 32)
	scroll.size = Vector2(label_inventory_root.size.x, label_inventory_root.size.y - 32)
	label_inventory_root.add_child(scroll)
	state.controls["label_inventory_scroll"] = scroll

	label_inventory_list = VBoxContainer.new()
	label_inventory_list.name = "label_inventory_list"
	label_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_inventory_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(label_inventory_list)
	state.controls["label_inventory_list"] = label_inventory_list

	build_label_inventory_recovery_use_button()
	build_label_inventory_recycle_drop_box()

	# -----------------------------------------
	# Hide legacy image roots so this becomes the visible inventory.
	# -----------------------------------------
	if inventory_root != null:
		inventory_root.visible = false
	if drone_bay_root != null:
		drone_bay_root.visible = false

	label_inventory_active_tab = "all"
	label_inventory_active_category = "all"
	apply_label_inventory_widget_size(label_inventory_root.size)
	refresh_label_inventory_rows()
	return label_inventory_root


func build_label_inventory_tab_bar() -> void:
	label_inventory_category_buttons.clear()

	label_inventory_tab_bar_scroll = ScrollContainer.new()
	label_inventory_tab_bar_scroll.name = "label_inventory_tab_bar_scroll"
	label_inventory_tab_bar_scroll.position = Vector2.ZERO
	label_inventory_tab_bar_scroll.size = Vector2(label_inventory_root.size.x, 30)
	label_inventory_tab_bar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	label_inventory_tab_bar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	label_inventory_tab_bar_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	label_inventory_root.add_child(label_inventory_tab_bar_scroll)
	state.controls["label_inventory_tab_bar_scroll"] = label_inventory_tab_bar_scroll

	label_inventory_tab_bar = HBoxContainer.new()
	label_inventory_tab_bar.name = "label_inventory_tab_bar"
	label_inventory_tab_bar.position = Vector2.ZERO
	label_inventory_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_inventory_tab_bar.add_theme_constant_override("separation", 3)
	label_inventory_tab_bar_scroll.add_child(label_inventory_tab_bar)
	state.controls["label_inventory_tab_bar"] = label_inventory_tab_bar

	for tab_packet in LABEL_INVENTORY_TABS:
		var tab_id := str(tab_packet.get("id", ""))
		var tab_text := str(tab_packet.get("text", tab_id)).to_upper()
		var tab_width := float(tab_packet.get("width", 58.0))
		var tab := _make_label_inventory_tab(tab_text, Vector2.ZERO, tab_id)
		tab.custom_minimum_size = Vector2(tab_width, 28)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		label_inventory_tab_bar.add_child(tab)
		label_inventory_category_buttons[tab_id] = tab
		state.buttons["label_inventory_tab_" + tab_id] = tab

		if tab_id == "slots":
			label_inventory_tab_cargo = tab
			state.buttons["label_inventory_tab_cargo"] = tab
		elif tab_id == "drone":
			label_inventory_tab_drone = tab
			state.buttons["label_inventory_tab_drone"] = tab


func build_label_inventory_recovery_use_button() -> void:
	label_inventory_use_button = Button.new()
	label_inventory_use_button.name = "label_inventory_recovery_use_button"
	label_inventory_use_button.text = "RECOVERY USE: SELECT ITEM"
	label_inventory_use_button.focus_mode = Control.FOCUS_NONE
	label_inventory_use_button.clip_text = true
	label_inventory_use_button.mouse_filter = Control.MOUSE_FILTER_STOP
	label_inventory_use_button.visible = false
	label_inventory_use_button.disabled = true
	label_inventory_use_button.add_theme_font_size_override("font_size", 10)
	if state != null and state.font != null:
		label_inventory_use_button.add_theme_font_override("font", state.font)
	label_inventory_use_button.pressed.connect(_on_label_inventory_recovery_use_pressed)
	label_inventory_root.add_child(label_inventory_use_button)
	state.buttons["label_inventory_recovery_use_button"] = label_inventory_use_button


func build_label_inventory_recycle_drop_box() -> void:
	label_inventory_recycle_drop_box = Button.new()
	label_inventory_recycle_drop_box.name = "label_inventory_recycle_drop_box"
	label_inventory_recycle_drop_box.text = "RECYCLE DROP  +100 IRON"
	label_inventory_recycle_drop_box.focus_mode = Control.FOCUS_NONE
	label_inventory_recycle_drop_box.clip_text = true
	label_inventory_recycle_drop_box.mouse_filter = Control.MOUSE_FILTER_STOP
	label_inventory_recycle_drop_box.add_theme_font_size_override("font_size", 10)
	if state != null and state.font != null:
		label_inventory_recycle_drop_box.add_theme_font_override("font", state.font)
	label_inventory_root.add_child(label_inventory_recycle_drop_box)
	state.buttons["label_inventory_recycle_drop_box"] = label_inventory_recycle_drop_box

	label_inventory_recycle_status_label = Label.new()
	label_inventory_recycle_status_label.name = "label_inventory_recycle_status_label"
	label_inventory_recycle_status_label.text = "Drag one item here to recycle."
	label_inventory_recycle_status_label.clip_text = true
	label_inventory_recycle_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_inventory_recycle_status_label.add_theme_font_size_override("font_size", 9)
	label_inventory_recycle_status_label.add_theme_color_override("font_color", Color(0.72, 0.90, 0.96, 0.88))
	if state != null and state.font != null:
		label_inventory_recycle_status_label.add_theme_font_override("font", state.font)
	label_inventory_root.add_child(label_inventory_recycle_status_label)
	state.labels["label_inventory_recycle_status_label"] = label_inventory_recycle_status_label


func apply_label_inventory_widget_size(widget_size: Vector2) -> void:
	if label_inventory_root == null or not is_instance_valid(label_inventory_root):
		return

	label_inventory_root.size = widget_size
	label_inventory_root.custom_minimum_size = widget_size

	if state != null and state.color_rects.has("label_inventory_bg") and state.color_rects["label_inventory_bg"] is ColorRect:
		var bg := state.color_rects["label_inventory_bg"] as ColorRect
		bg.position = Vector2(0, 30)
		bg.size = Vector2(widget_size.x, max(widget_size.y - 30.0, 1.0))

	if label_inventory_tab_bar_scroll != null:
		label_inventory_tab_bar_scroll.position = Vector2.ZERO
		label_inventory_tab_bar_scroll.size = Vector2(widget_size.x, 30)

	var recovery_use_h := 28.0
	var recycle_h := 48.0
	var bottom_reserved := recycle_h + recovery_use_h + 8.0

	if state != null and state.controls.has("label_inventory_scroll") and state.controls["label_inventory_scroll"] is ScrollContainer:
		var scroll := state.controls["label_inventory_scroll"] as ScrollContainer
		scroll.position = Vector2(0, 32)
		scroll.size = Vector2(widget_size.x, max(widget_size.y - 32.0 - bottom_reserved, 40.0))

	var recycle_y = max(widget_size.y - recycle_h - 2.0, 40.0)
	if label_inventory_use_button != null:
		label_inventory_use_button.position = Vector2(6, max(recycle_y - recovery_use_h - 4.0, 40.0))
		label_inventory_use_button.size = Vector2(max(widget_size.x - 12.0, 120.0), recovery_use_h)
	if label_inventory_recycle_drop_box != null:
		label_inventory_recycle_drop_box.position = Vector2(6, recycle_y)
		label_inventory_recycle_drop_box.size = Vector2(max(widget_size.x - 12.0, 120.0), 28)
	if label_inventory_recycle_status_label != null:
		label_inventory_recycle_status_label.position = Vector2(8, recycle_y + 29.0)
		label_inventory_recycle_status_label.size = Vector2(max(widget_size.x - 16.0, 120.0), 16)

	for row in label_inventory_rows:
		if row is Control:
			(row as Control).custom_minimum_size = Vector2(max(widget_size.x - 32.0, 120.0), 25)


func refresh_label_inventory_rows() -> void:
	# Summary: Rebuild the label inventory rows from filtered inventory packets.
	if Globals.print_priority_3:
		print("[INV5_DEBUG] refresh_label_inventory_rows ENTERED")
		print("[INV5_DEBUG] active tab :: ", label_inventory_active_category)

	if label_inventory_list == null:
		if Globals.print_priority_1:
			print("[INV5_DEBUG] refresh blocked: label_inventory_list missing")
		return

	for child in label_inventory_list.get_children():
		child.queue_free()

	label_inventory_rows.clear()

	var row_packets := collect_label_inventory_rows(label_inventory_active_category)
	for packet in row_packets:
		var row := _make_label_inventory_row(str(packet.get("container_name", "main")), str(packet.get("slot_name", "")), packet.get("slot", {}), packet)
		label_inventory_list.add_child(row)
		label_inventory_rows.append(row)

	if label_inventory_rows.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No items in " + get_label_inventory_tab_label(label_inventory_active_category) + "."
		empty_label.custom_minimum_size = Vector2(max(label_inventory_root.size.x - 32.0, 120.0), 25)

		if state != null and state.font != null:
			empty_label.add_theme_font_override("font", state.font)

		empty_label.add_theme_font_size_override("font_size", 12)
		label_inventory_list.add_child(empty_label)

	if Globals.print_priority_3:
		print("[INV5_DEBUG] label rows created :: ", label_inventory_rows.size())

	update_label_inventory_recovery_use_button()
	_update_label_inventory_tabs()


func collect_label_inventory_rows(category_id: String) -> Array:
	var rows := []
	var slot_index := 0

	if cells.has("each_cell"):
		for slot_name in cells["each_cell"]:
			var slot: Dictionary = cells["each_cell"][slot_name]
			var packet := make_label_inventory_row_packet("main", str(slot_name), slot, slot_index)
			slot_index += 1
			if packet.is_empty():
				continue
			if label_inventory_packet_matches_category(packet, category_id):
				rows.append(packet)

	if drone_cells.has("each_cell"):
		for slot_name in drone_cells["each_cell"]:
			var slot: Dictionary = drone_cells["each_cell"][slot_name]
			var packet := make_label_inventory_row_packet("drone", str(slot_name), slot, slot_index)
			slot_index += 1
			if packet.is_empty():
				continue
			if label_inventory_packet_matches_category(packet, category_id):
				rows.append(packet)

	sort_label_inventory_rows(rows, category_id)
	return rows


func make_label_inventory_row_packet(container_name: String, slot_name: String, slot: Dictionary, slot_index: int) -> Dictionary:
	var item_id := str(slot.get("item_id", "")).strip_edges()
	var count := int(slot.get("count", 0))
	if item_id == "" or count <= 0:
		return {}

	var item_data := {}
	var item_name := item_id
	if item_handler != null:
		item_name = item_handler.get_item_name(item_id)
		item_data = item_handler.get_item_data(item_id)

	var item_type := str(item_data.get("type", item_data.get("item_type", "item"))).strip_edges()
	if item_type == "":
		item_type = "item"
	var subtype := str(item_data.get("subtype", "")).strip_edges()

	return {
		"container_name": container_name,
		"slot_name": slot_name,
		"slot": slot,
		"slot_index": slot_index,
		"item_id": item_id,
		"item_name": item_name,
		"item_type": item_type,
		"subtype": subtype,
		"category": resolve_label_inventory_category(item_id, item_data, container_name),
		"count": count,
		"item_data": item_data,
		"intel_unchecked": inventory_intel_is_unchecked(item_id)
	}


func label_inventory_packet_matches_category(packet: Dictionary, category_id: String) -> bool:
	var clean_category := category_id.strip_edges().to_lower()
	if clean_category == "" or clean_category == "all":
		return true
	if clean_category == "slots":
		return true
	if clean_category == "recovery":
		var item_data = packet.get("item_data", {})
		return typeof(item_data) == TYPE_DICTIONARY and is_recovery_item_data(item_data)
	return str(packet.get("category", "item")) == clean_category


func resolve_label_inventory_category(item_id: String, item_data: Dictionary, container_name: String = "main") -> String:
	var clean_id := item_id.strip_edges().to_lower()
	var item_type := str(item_data.get("type", item_data.get("item_type", "item"))).strip_edges().to_lower()
	var subtype := str(item_data.get("subtype", "")).strip_edges().to_lower()

	if container_name == "drone" or item_type == "drone" or subtype == "drone" or clean_id.find("drone") >= 0:
		return "drone"
	if item_type == "weapon":
		return "weapon"
	if item_type == "shield":
		return "shield"
	if item_type == "module":
		return "module"
	if item_type == "resource":
		return "res"
	if is_recovery_item_data(item_data):
		return "recovery"
	if item_type == "consumable" or bool(item_data.get("consumable", false)):
		return "cons"
	if item_type == "blueprint":
		return "blue"
	if item_type == "ammo":
		return "ammo"
	if item_type in ["part", "event_item"] or subtype == "event_item":
		return "parts"
	return "parts"


func is_recovery_item_data(item_data: Dictionary) -> bool:
	var item_type := str(item_data.get("type", item_data.get("item_type", ""))).strip_edges().to_lower()
	var subtype := str(item_data.get("subtype", "")).strip_edges().to_lower()
	var group := str(item_data.get("consumable_group", "")).strip_edges().to_lower()

	if item_type != "consumable" and not bool(item_data.get("consumable", false)):
		return false
	if RECOVERY_CONSUMABLE_GROUPS.has(group) or RECOVERY_CONSUMABLE_GROUPS.has(subtype):
		return true
	if item_data.has("hull_restore_amount") or item_data.has("heal_amount"):
		return true
	if item_data.has("shield_repair_amount"):
		return true
	if item_data.has("energy_restore_amount") or item_data.has("recharge_amount"):
		return true
	return false


func sort_label_inventory_rows(rows: Array, category_id: String) -> void:
	var clean_category := category_id.strip_edges().to_lower()
	rows.sort_custom(func(a, b):
		if clean_category == "slots":
			return int(a.get("slot_index", 0)) < int(b.get("slot_index", 0))

		var category_a := str(a.get("category", ""))
		var category_b := str(b.get("category", ""))
		if category_a != category_b:
			return category_a < category_b

		var name_a := str(a.get("item_name", "")).to_lower()
		var name_b := str(b.get("item_name", "")).to_lower()
		if name_a != name_b:
			return name_a < name_b

		return int(a.get("slot_index", 0)) < int(b.get("slot_index", 0))
	)


func get_label_inventory_tab_label(category_id: String) -> String:
	for tab_packet in LABEL_INVENTORY_TABS:
		if str(tab_packet.get("id", "")) == category_id:
			return str(tab_packet.get("text", category_id)).to_upper()
	return category_id.to_upper()


func _make_label_inventory_row(container_name: String, slot_name: String, slot: Dictionary, packet: Dictionary = {}) -> Button:
	if Globals.print_priority_3:
		print("[INV5_DEBUG] _make_label_inventory_row")
		print("[INV5_DEBUG] container :: ", container_name)
		print("[INV5_DEBUG] slot_name :: ", slot_name)
		print("[INV5_DEBUG] slot :: ", slot)
	var item_id: String = str(packet.get("item_id", slot.get("item_id", "")))
	var item_name := str(packet.get("item_name", item_handler.get_item_name(item_id) if item_handler != null else item_id))
	var count := int(packet.get("count", slot.get("count", 0)))
	var category := str(packet.get("category", resolve_label_inventory_category(item_id, packet.get("item_data", {}), container_name))).to_upper()
	var intel_unchecked := bool(packet.get("intel_unchecked", inventory_intel_is_unchecked(item_id)))

	# -----------------------------------------
	# Build player-facing row text.
	# -----------------------------------------
	var row_text := item_name
	if count > 1:
		row_text = "x" + str(count) + "  " + item_name
	if label_inventory_active_category in ["all", "slots"]:
		row_text += "  [" + category + "]"
	if container_name == "drone":
		row_text = slot_name.replace("drone bay - col", "Bay ") + "  |  " + row_text
	elif label_inventory_active_category == "slots":
		row_text = slot_name.replace("row ", "R").replace(" - col", " C") + "  |  " + row_text

	# -----------------------------------------
	# Create row button so click and long press can share input.
	# -----------------------------------------
	var row := Button.new()
	row.name = "label_inventory_row_" + slot_name.replace(" ", "_").replace("-", "_")
	row.flat = false
	row.text = row_text
	row.custom_minimum_size = Vector2(max(label_inventory_root.size.x - 32.0, 120.0), 25)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_font_override("font", state.font)
	row.add_theme_font_size_override("font_size", 12)
	#row.add_theme_color_override("font" , Color.BLUE)
	row.set_meta("slot_name", slot_name)
	row.set_meta("container_name", container_name)
	row.set_meta("item_id", item_id)
	row.set_meta("category", category)
	row.set_meta("intel_unchecked", intel_unchecked)
	if intel_unchecked:
		row.modulate = LABEL_INVENTORY_NEW_MODULATE
	row.pressed.connect(_on_label_inventory_row_pressed.bind(row))
	row.button_down.connect(_on_label_inventory_row_button_down.bind(row))
	row.button_up.connect(_on_label_inventory_row_button_up.bind(row))
	return row


func _update_label_inventory_tabs() -> void:
	# Summary: Keep the active tab visually obvious without changing behavior.
	if Globals.print_priority_3:
		print("Updating label inventory tabs: ", label_inventory_active_category)

	for tab_id in label_inventory_category_buttons.keys():
		var tab = label_inventory_category_buttons[tab_id]
		if tab is Button:
			var button := tab as Button
			var is_active := str(tab_id) == label_inventory_active_category
			button.disabled = is_active
			button.modulate = Color(0.70, 1.0, 1.0, 1.0) if is_active else Color.WHITE

	if Globals.print_priority_3:
		print("[INV5_DEBUG] label rows created :: ", label_inventory_rows.size())
func _on_label_inventory_row_pressed(row: Button) -> void:
	# Summary: Route a label inventory row click into the log widget.
	if Globals.is_popup_input_locked():
		if Globals.print_priority_2:
			print("Inventory row click ignored while tutorial/story popup is active.")
		return

	if not inventory_interaction_enabled:
		if Globals.print_priority_3:
			print("Inventory row click ignored because inventory interaction is disabled.")
		return
	if Globals.print_priority_3:
		print("Label inventory row pressed: ", row.name)
	if label_drag_just_finished:
		label_drag_just_finished = false
		return

	# -----------------------------------------
	# Read row metadata and show item details.
	# -----------------------------------------
	var slot_name := str(row.get_meta("slot_name", ""))
	var container_name := str(row.get_meta("container_name", ""))
	var item_id := str(row.get_meta("item_id", ""))
	show_slot_info_in_log(container_name, slot_name)
	if label_inventory_active_category == "recovery":
		select_label_inventory_recovery_slot(container_name, slot_name)
	mark_inventory_item_checked(item_id)


func show_slot_info_in_log(container_name: String, slot_name: String) -> void:
	# Summary: Write selected cargo/drone inventory row details into the active detail log.
	if Globals.print_priority_2:
		print("[INV5_CLICK_DEBUG] row selected")
		print("[INV5_CLICK_DEBUG] container_name :: ", container_name)
		print("[INV5_CLICK_DEBUG] slot_name :: ", slot_name)

	if state == null or not state.log_storage.has("log_text"):
		if Globals.print_priority_1:
			print("[INV5_CLICK_DEBUG] blocked: missing state.log_storage['log_text']")
		return

	var slot := {}

	if container_name == "drone":
		slot = drone_cells.get("each_cell", {}).get(slot_name, {})
	else:
		slot = cells.get("each_cell", {}).get(slot_name, {})

	if slot.is_empty() or slot.get("item_id", "") == "":
		if Globals.print_priority_2:
			print("[INV5_CLICK_DEBUG] empty slot clicked")
		return

	var item_id: String = slot.get("item_id", "")
	var count := int(slot.get("count", 0))

	var item_name := item_id
	var item_data := {}

	if item_handler != null:
		item_name = item_handler.get_item_name(item_id)
		item_data = item_handler.get_item_data(item_id)

	var text := ""
	text += item_name + "\n"
	text += "Item ID: " + item_id + "\n"
	text += "Container: " + container_name + "\n"
	text += "Slot: " + slot_name + "\n"
	text += "Amount: " + str(count)

	for key in item_data:
		text += "\n" + str(key) + " : " + str(item_data[key])

	state.log_storage["log_text"].text = text


func select_label_inventory_recovery_slot(container_name: String, slot_name: String) -> void:
	var slot := get_slot_from_container(container_name, slot_name)
	var item_id := str(slot.get("item_id", "")).strip_edges()
	var item_data := item_handler.get_item_data(item_id) if item_handler != null and item_id != "" else {}
	if item_id == "" or typeof(item_data) != TYPE_DICTIONARY or not is_recovery_item_data(item_data):
		label_inventory_selected_recovery_container = ""
		label_inventory_selected_recovery_slot = ""
	else:
		label_inventory_selected_recovery_container = container_name
		label_inventory_selected_recovery_slot = slot_name
	update_label_inventory_recovery_use_button()


func update_label_inventory_recovery_use_button() -> void:
	if label_inventory_use_button == null:
		return

	var recovery_tab_active := label_inventory_active_category == "recovery"
	label_inventory_use_button.visible = recovery_tab_active
	if not recovery_tab_active:
		label_inventory_use_button.disabled = true
		return

	var slot := get_slot_from_container(label_inventory_selected_recovery_container, label_inventory_selected_recovery_slot)
	var item_id := str(slot.get("item_id", "")).strip_edges()
	var count := int(slot.get("count", 0))
	var item_data := item_handler.get_item_data(item_id) if item_handler != null and item_id != "" else {}
	if item_id == "" or count <= 0 or typeof(item_data) != TYPE_DICTIONARY or not is_recovery_item_data(item_data):
		label_inventory_selected_recovery_container = ""
		label_inventory_selected_recovery_slot = ""
		label_inventory_use_button.text = "RECOVERY USE: SELECT ITEM"
		label_inventory_use_button.disabled = true
		return

	var item_name := item_handler.get_item_name(item_id) if item_handler != null else item_id
	label_inventory_use_button.text = "USE " + item_name.to_upper() + "  x" + str(count)
	label_inventory_use_button.disabled = false


func _on_label_inventory_recovery_use_pressed() -> void:
	if Globals.is_popup_input_locked() or not inventory_interaction_enabled:
		return

	var slot := get_slot_from_container(label_inventory_selected_recovery_container, label_inventory_selected_recovery_slot)
	var item_id := str(slot.get("item_id", "")).strip_edges()
	if item_id == "":
		show_recycle_message("Recovery use blocked: select an item.")
		update_label_inventory_recovery_use_button()
		return

	if recovery_use_owner == null or not recovery_use_owner.has_method("request_inventory_recovery_use_item"):
		show_recycle_message("Recovery use blocked: handler missing.")
		return

	var result = recovery_use_owner.request_inventory_recovery_use_item(item_id, "inventory_recovery_tab")
	if typeof(result) == TYPE_DICTIONARY:
		show_recycle_message(str(result.get("message", "Recovery item used.")))
	else:
		show_recycle_message("Recovery use returned no result.")
	refresh_label_inventory_rows()


func get_slot_from_container(container_name: String, slot_name: String) -> Dictionary:
	var container = get_container_by_name(container_name)
	if container == null or not container.has(slot_name):
		return {}
	var slot = container[slot_name]
	return slot if typeof(slot) == TYPE_DICTIONARY else {}


func _on_label_inventory_row_button_down(row: Button) -> void:
	# Summary: Start tracking a possible long-press drag from a label row.
	if Globals.is_popup_input_locked():
		if Globals.print_priority_2:
			print("Inventory row press ignored while tutorial/story popup is active.")
		return

	if not inventory_interaction_enabled:
		if Globals.print_priority_2:
			print("Inventory row press ignored because inventory interaction is disabled.")
		return
	if Globals.print_priority_3:
		print("Label inventory row button down: ", row.name)
	var slot_name := str(row.get_meta("slot_name", ""))
	var container_name := str(row.get_meta("container_name", ""))

	# -----------------------------------------
	# Only filled rows can be dragged.
	# -----------------------------------------
	var slot := get_slot_data(slot_name)
	if slot.is_empty() or slot.get("item_id", "") == "":
		return

	label_press_row = row
	label_press_slot_name = slot_name
	label_press_container_name = container_name
	label_press_start_msec = Time.get_ticks_msec()
	label_press_start_pos = get_viewport().get_mouse_position()


func _on_label_inventory_row_button_up(_row: Button) -> void:
	# Summary: Finish a label-row drag or clear press tracking when released.
	if Globals.is_popup_input_locked():
		cleanup_label_drag_state()
		return

	if not inventory_interaction_enabled:
		return
	if Globals.print_priority_3:
		print("Label inventory row button up.")
	if label_drag_active:
		finish_label_drag_at_mouse()
	else:
		clear_label_press_tracking()


func update_label_drag_from_motion() -> void:
	# Summary: Promote a label row press into a drag after the long-press threshold.
	if Globals.print_priority_3:
		print("Checking label inventory drag motion.")
	if label_press_row == null or label_drag_active:
		return

	# -----------------------------------------
	# Stop tracking if the mouse is no longer held.
	# -----------------------------------------
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		clear_label_press_tracking()
		return

	var elapsed := Time.get_ticks_msec() - label_press_start_msec
	var moved := label_press_start_pos.distance_to(get_viewport().get_mouse_position())

	# -----------------------------------------
	# Match the old inventory's drag feel.
	# -----------------------------------------
	if elapsed >= drag_long_press_msec and moved >= drag_start_distance:
		start_label_drag()


func start_label_drag() -> void:
	# Summary: Create a text drag preview for label inventory rows.
	if label_press_row == null:
		return

	if Globals.print_priority_3:
		print("Starting label inventory drag: ", label_press_container_name, " / ", label_press_slot_name)

	# -----------------------------------------
	# Keep drag same-container for now.
	# -----------------------------------------
	hold_item_slot_name = label_press_slot_name
	hold_item_container_name = label_press_container_name
	label_drag_active = true
	label_press_row.modulate = SLOT_MODULATE_DRAG_SOURCE

	label_drag_preview = Label.new()
	label_drag_preview.text = label_press_row.text
	label_drag_preview.size = Vector2(260, 25)
	label_drag_preview.add_theme_font_override("font", state.font)
	label_drag_preview.add_theme_font_size_override("font_size", 12)
	label_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_drag_preview.modulate = Color(1, 1, 1, 0.85)
	label_drag_preview.z_index = 1000
	get_tree().current_scene.add_child(label_drag_preview)
	update_label_drag_preview_position()


func update_label_drag_preview_position() -> void:
	# Summary: Keep the label drag preview under the mouse.
	if Globals.print_priority_3:
		print("Updating label inventory drag preview.")
	if label_drag_preview == null:
		return

	label_drag_preview.position = get_viewport().get_mouse_position() - Vector2(10, 12)


func finish_label_drag_at_mouse() -> void:
	# Summary: Drop a label row onto another row in the same inventory container.
	if Globals.print_priority_3:
		print("Finishing label inventory drag.")
	if not label_drag_active:
		clear_label_press_tracking()
		return

	var hovered := get_viewport().gui_get_hovered_control()
	if is_recycle_drop_hovered(hovered):
		recycle_slot_item(hold_item_container_name, hold_item_slot_name)
		cleanup_label_drag_state()
		label_drag_just_finished = true
		call_deferred("_reset_label_drag_just_finished")
		return

	var target_row := hovered as Button

	# -----------------------------------------
	# Only swap when dropping on another label row.
	# -----------------------------------------
	if target_row != null and target_row.has_meta("slot_name") and target_row.has_meta("container_name"):
		var target_slot_name := str(target_row.get_meta("slot_name", ""))
		var target_container_name := str(target_row.get_meta("container_name", ""))

		if target_container_name == hold_item_container_name:
			swap_held_slot_with(target_container_name, target_slot_name)
		else:
			if Globals.print_priority_3:
				print("Label inventory drag blocked across containers.")

	cleanup_label_drag_state()
	label_drag_just_finished = true
	call_deferred("_reset_label_drag_just_finished")


func is_recycle_drop_hovered(control: Control) -> bool:
	var node: Node = control
	while node != null:
		if node == label_inventory_recycle_drop_box:
			return true
		node = node.get_parent()
	return false


func recycle_slot_item(container_name: String, slot_name: String) -> bool:
	var container = get_container_by_name(container_name)
	if container == null or not container.has(slot_name):
		show_recycle_message("Recycle blocked: no item selected.")
		return false

	var slot: Dictionary = container[slot_name]
	var item_id := str(slot.get("item_id", "")).strip_edges()
	var count := int(slot.get("count", 0))
	if item_id == "" or count <= 0:
		show_recycle_message("Recycle blocked: empty slot.")
		return false

	if not can_recycle_item(item_id):
		show_recycle_message("Recycle blocked: system item protected.")
		return false

	if not can_accept_recycle_reward(container_name, slot_name, item_id, count):
		show_recycle_message("Recycle blocked: no room for iron.")
		return false

	slot["count"] = count - 1
	if int(slot["count"]) <= 0:
		slot["item_id"] = ""
		slot["count"] = 0
	update_slot_visual(container_name, slot)
	notify_inventory_changed("recycle_consume")

	if not add_item(RECYCLE_REWARD_ITEM_ID, RECYCLE_REWARD_AMOUNT):
		slot["item_id"] = item_id
		slot["count"] = count
		update_slot_visual(container_name, slot)
		notify_inventory_changed("recycle_restore")
		show_recycle_message("Recycle failed: iron could not be stored.")
		return false

	var item_name := item_handler.get_item_name(item_id) if item_handler != null else item_id
	show_recycle_message("Recycled " + item_name + " for +" + str(RECYCLE_REWARD_AMOUNT) + " iron.")
	return true


func can_recycle_item(item_id: String) -> bool:
	var clean_id := item_id.strip_edges().to_lower()
	if RECYCLE_BLOCKED_ITEM_IDS.has(clean_id):
		return false
	if clean_id.find("scan_module") >= 0 or clean_id.find("drone_controller") >= 0:
		return false

	var item_data := item_handler.get_item_data(item_id) if item_handler != null else {}
	var item_type := str(item_data.get("type", item_data.get("item_type", ""))).strip_edges().to_lower()
	var subtype := str(item_data.get("subtype", "")).strip_edges().to_lower()
	if item_type == "module" and subtype in ["scanner", "drone_control"]:
		return false

	return true


func can_accept_recycle_reward(source_container_name: String, _source_slot_name: String, source_item_id: String, source_count: int) -> bool:
	if item_handler == null or not item_handler.has_item(RECYCLE_REWARD_ITEM_ID):
		return false

	var reward_data := item_handler.get_item_data(RECYCLE_REWARD_ITEM_ID)
	var max_stack := int(reward_data.get("max_stack", 1))
	for slot_name in cells["each_cell"]:
		var slot = cells["each_cell"][slot_name]
		if str(slot.get("item_id", "")) == RECYCLE_REWARD_ITEM_ID:
			var projected_count := int(slot.get("count", 0)) + RECYCLE_REWARD_AMOUNT
			if source_container_name == "main" and source_item_id == RECYCLE_REWARD_ITEM_ID:
				projected_count -= 1
			if projected_count <= max_stack:
				return true

	for slot_name in cells["each_cell"]:
		var slot = cells["each_cell"][slot_name]
		if str(slot.get("item_id", "")) == "":
			return true

	return source_container_name == "main" and source_count <= 1


func update_slot_visual(container_name: String, slot: Dictionary) -> void:
	if not slot.has("button") or not (slot["button"] is TextureButton):
		return

	var button := slot["button"] as TextureButton
	var item_id := str(slot.get("item_id", "")).strip_edges()
	if item_id == "":
		button.texture_normal = drone_cell if container_name == "drone" else tex_cell
		return

	if item_handler == null:
		return
	var tex := item_handler.get_item_texture(item_id)
	if tex != null:
		button.texture_normal = tex


func show_recycle_message(message: String) -> void:
	if label_inventory_recycle_status_label != null:
		label_inventory_recycle_status_label.text = message
	if state != null and state.log_storage.has("log_text"):
		state.log_storage["log_text"].text = message
	if Globals.print_priority_2:
		print("[INV_RECYCLE] ", message)


func cleanup_label_drag_state() -> void:
	# Summary: Clear label drag visuals and tracking state.
	if Globals.print_priority_3:
		print("Cleaning label inventory drag state.")
	if label_press_row != null:
		label_press_row.modulate = SLOT_MODULATE_NORMAL

	if label_drag_preview != null:
		label_drag_preview.queue_free()
		label_drag_preview = null

	hold_item_slot_name = null
	hold_item_container_name = ""
	label_drag_active = false
	clear_label_press_tracking()


func clear_label_press_tracking() -> void:
	# Summary: Reset pending label-row press values.
	if Globals.print_priority_3:
		print("Clearing label inventory press tracking.")
	label_press_row = null
	label_press_slot_name = ""
	label_press_container_name = ""
	label_press_start_msec = 0
	label_press_start_pos = Vector2.ZERO


func _reset_label_drag_just_finished() -> void:
	# Summary: Allow normal row clicks after a completed label drag settles.
	if Globals.print_priority_3:
		print("Resetting label inventory drag click guard.")
	label_drag_just_finished = false


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
func set_slot_item(slot_name: String, item_id: String, count: int = 1, change_reason: String = "set_slot_item") -> void:
	var clean_item_id := item_id.strip_edges()
	if Globals.print_priority_3:
		print("[INV5_DEBUG] set_slot_item ENTERED")
		print("[INV5_DEBUG] slot_name :: ", slot_name)
		print("[INV5_DEBUG] item_id :: ", clean_item_id)
		print("[INV5_DEBUG] count :: ", count)
		print("[INV5_DEBUG] main has slot :: ", cells.get("each_cell", {}).has(slot_name))
		print("[INV5_DEBUG] drone has slot :: ", drone_cells.get("each_cell", {}).has(slot_name))
		print("[INV5_DEBUG] item_handler :: ", item_handler)

	# Safety check
	if item_handler == null:
		if Globals.print_priority_1:
			print("Missing item_handler")
		return

	if clean_item_id == "":
		if Globals.print_priority_1:
			print("Blocked empty item id for slot: ", slot_name)
		return

	if not item_handler.has_item(clean_item_id):
		if Globals.print_priority_1:
			print("Blocked unknown item id for slot: ", clean_item_id)
		return

	# Get icon texture
	var tex = item_handler.get_item_texture(clean_item_id)

	# MAIN INVENTORY
	if slot_name in cells["each_cell"]:
		cells["each_cell"][slot_name]["item_id"] = clean_item_id
		cells["each_cell"][slot_name]["count"] = count

		if tex != null:
			cells["each_cell"][slot_name]["button"].texture_normal = tex
		notify_inventory_changed(change_reason)
		return

	# DRONE BAY
	if slot_name in drone_cells["each_cell"]:
		drone_cells["each_cell"][slot_name]["item_id"] = clean_item_id
		drone_cells["each_cell"][slot_name]["count"] = count

		if tex != null:
			drone_cells["each_cell"][slot_name]["button"].texture_normal = tex
		notify_inventory_changed(change_reason)
		return

	if Globals.print_priority_1:
		print("Slot not found: ", slot_name)
	
	
# =========================================================
# 🤖 SET DRONE INTO DRONE BAY
# ---------------------------------------------------------
# Only drone-type items are allowed into drone bay slots.
# =========================================================
func set_drone_slot_item(slot_name: String, item_id: String, count: int = 1) -> void:
	if item_handler == null:
		if Globals.print_priority_1:
			print("Missing item_handler")
		return

	var data := item_handler.get_item_data(item_id)

	if data.is_empty():
		if Globals.print_priority_1:
			print("Unknown item_id: ", item_id)
		return

	if data.get("type", "") != "drone":
		if Globals.print_priority_3:
			print("Item is not a drone: ", item_id)
		return

	if not drone_cells.has("each_cell"):
		if Globals.print_priority_3:
			print("Drone bay not built yet.")
		return

	if not drone_cells["each_cell"].has(slot_name):
		if Globals.print_priority_1:
			print("Drone slot not found: ", slot_name)
		return

	set_slot_item(slot_name, item_id, count)
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


func has_any_items() -> bool:
	for slot_name in cells["each_cell"]:
		var slot = cells["each_cell"][slot_name]
		if str(slot.get("item_id", "")).strip_edges() != "" and int(slot.get("count", 0)) > 0:
			return true

	for slot_name in drone_cells["each_cell"]:
		var slot = drone_cells["each_cell"][slot_name]
		if str(slot.get("item_id", "")).strip_edges() != "" and int(slot.get("count", 0)) > 0:
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
	# Summary: Remove item count from inventory data and refresh the label rows.
	if Globals.print_priority_3:
		print("Consuming inventory item: ", item_id, " x", amount)

	if amount <= 0:
		return true

	# Prevent partial spends when a caller asks for more than exists.
	if count_item_anywhere(item_id) < amount:
		if Globals.print_priority_2:
			print("Consume blocked, not enough inventory: ", item_id, " x", amount)
		return false

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
				update_slot_visual("main", slot)

			# ---------------------------------
			# Finished consuming requested amount
			# ---------------------------------
			if remaining <= 0:
				notify_inventory_changed("consume_item")
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
				update_slot_visual("drone", slot)

			# ---------------------------------
			# Finished consuming requested amount
			# ---------------------------------
			if remaining <= 0:
				notify_inventory_changed("consume_item")
				return true

	notify_inventory_changed("consume_item")
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
			if Globals.debug_heat_1:
				if Globals.print_priority_3:
					print(slot_name, " -> ", slot)
	if Globals.debug_heat_1:
		if Globals.print_priority_3:
			print("---- DRONE BAY ----")

	# -----------------------------------------
	# Print filled drone bay slots
	# -----------------------------------------
	for slot_name in drone_cells["each_cell"]:
		var slot = drone_cells["each_cell"][slot_name]

		if slot["item_id"] != "":
			if Globals.debug_heat_1:
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
	if Globals.is_popup_input_locked():
		if Globals.print_priority_2:
			print("Inventory slot click ignored while tutorial/story popup is active.")
		return

	if drag_just_finished:
		drag_just_finished = false
		return

	# -----------------------------------------
	# The button name IS the slot name
	# -----------------------------------------
	var slot_name = str(btn.name)

	if Globals.print_priority_3:
		print("---- CLICKED:", slot_name, "----")


	# ===============================
	# PRINT FULL MAIN INVENTORY
	# ===============================
	if Globals.print_priority_3:
		print("---- MAIN INVENTORY ----")

	for key in cells["each_cell"]:
		if Globals.debug_heat_1:
			if Globals.print_priority_3:
				print(key, " -> ", cells["each_cell"][key])


	# ===============================
	# PRINT DRONE BAY
	# ===============================
	if Globals.print_priority_3:
		print("---- DRONE BAY ----")

	for key in drone_cells["each_cell"]:
		if Globals.debug_heat_1:
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
	# ===============================
	# EMPTY SLOT CHECK
	# ===============================
	if slot["item_id"] == "":
		clear_selected_slot()

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
	select_slot(clicked_container_name, slot_name)

	if Globals.print_priority_3:
		print("Selected slot: ", selected_container_name, " / ", selected_slot_name)


	# ===============================
	# MAIN INVENTORY LOG INFO
	# ===============================
	if clicked_container_name == "main":

		var item_name = item_handler.get_item_name(slot["item_id"])
		var item_data = item_handler.get_item_data(slot["item_id"])

		var t := ""

		for key in item_data:
			t += "\n" + str(key) + " : " + str(item_data[key])

		state.log_storage["log_text"].text = (
		item_name
		+ "\nAmount: " + str(slot["count"])
		+ "\n" + t
			)

		return


	# ===============================
	# DRONE BAY LOG INFO
	# ===============================
	if clicked_container_name == "drone":

		var drone_item_name = item_handler.get_item_name(slot["item_id"])
		var item_data = item_handler.get_item_data(slot["item_id"])
		
		var t := ""

		for key in item_data:
			t += "\n" + str(key) + " : " + str(item_data[key])
		
		
		if Globals.print_priority_3:
			print("Clicked drone bay item: " + drone_item_name)
		state.log_storage["log_text"].text = drone_item_name + "\n" + t

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

func make_drone_slot_name(col: int) -> String:
	return "drone bay - col%d" % col
# =========================================================
# 🎁 STARTER ITEMS
# ---------------------------------------------------------
# Places the starting equipment into known inventory slots.
# =========================================================

func give_starter_items() -> void:

	set_slot_item(make_slot_name(0, 0), "scan_module_mk1", 1)
	set_slot_item(make_slot_name(0, 1), "drone_controller_mk1", 1)
	set_slot_item(make_slot_name(0, 2), "planetary_resource_rover", 1)
	#set_slot_item(make_slot_name(0, 2), "signal_filter_drone_mk1", 4)
	#set_slot_item(make_slot_name(2, 0), "auto_attack_drone_test_mk1", 4)
	set_slot_item(make_slot_name(0, 3), "ion_threader_mk1", 1)
	set_slot_item(make_slot_name(0, 4), "railgun_sk1", 1)
	set_slot_item(make_slot_name(0, 5), "planet_recovery_launcher", 1)
	#set_slot_item(make_slot_name(0, 5), "scatter_pulse_mk2_blueprint", 1)
	set_slot_item(make_slot_name(1, 0), "coil_spitter_mk1", 1)
	set_slot_item(make_slot_name(1, 1), "repair_kit", 5)
	set_slot_item(make_slot_name(1, 2), "planetary_resource_rover_blueprint", 1)
	set_slot_item(make_slot_name(1, 3), "planet_recovery_launcher_blueprint", 1)
	#set_slot_item(make_slot_name(1, 2), "iron", 2200)
	#set_slot_item(make_slot_name(1, 8), "cobalt", 2200)
	#set_slot_item(make_slot_name(1, 9), "nickel", 2200)
	#set_slot_item(make_slot_name(1, 3), "buster_charge", 20)
	#set_slot_item(make_slot_name(1, 4), "breach_charge", 20)
	#set_slot_item(make_slot_name(1, 5), "recharge_kit", 1)
	#set_slot_item(make_slot_name(0, 6), "buster_charge",5)
	set_slot_item(make_slot_name(0,7) , "reinforced_barrier_mk1",2)
	set_slot_item(make_slot_name(2,8) , "small_kinetic_rounds",20)
	#set_drone_slot_item(make_drone_slot_name(0), "roamer_drone_mk1")
	set_drone_slot_item(make_drone_slot_name(1), "miner_drone_mk1")
	set_drone_slot_item(make_drone_slot_name(2), "survey_drone_mk1")
	#set_drone_slot_item(make_drone_slot_name(3), "lander_drone_mk1")

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
	# Summary: Swap held inventory data with a target slot and refresh old/new visuals.
	if Globals.print_priority_3:
		print("Trying inventory swap into: ", to_container_name, " / ", to_slot_name)

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

	notify_inventory_changed("swap_held_slot_with")

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

			var item_data: Dictionary = item_handler.get_item_data(item_id)

			if item_data.has("icon"):
				btn.texture_normal = item_data["icon"]
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
	
func get_container_name_for_slot(slot_name: String) -> String:
	if cells.has("each_cell") and slot_name in cells["each_cell"]:
		return "main"

	if drone_cells.has("each_cell") and slot_name in drone_cells["each_cell"]:
		return "drone"

	return ""


func select_slot(container_name: String, slot_name: String) -> void:
	clear_selected_slot()

	var slot := get_slot_data(slot_name)
	if slot.is_empty():
		return

	selected_container_name = container_name
	selected_slot_name = slot_name

	var button: TextureButton = slot["button"]
	button.modulate = SLOT_MODULATE_SELECTED


func clear_selected_slot() -> void:
	if selected_slot_name == null:
		return

	var slot := get_slot_data(selected_slot_name)
	if not slot.is_empty():
		var button: TextureButton = slot["button"]
		button.modulate = SLOT_MODULATE_NORMAL

	selected_slot_name = null
	selected_container_name = ""


func _on_slot_button_down(btn: TextureButton) -> void:
	if Globals.is_popup_input_locked():
		if Globals.print_priority_2:
			print("Inventory texture slot press ignored while tutorial/story popup is active.")
		return

	if not inventory_interaction_enabled:
		if Globals.print_priority_2:
			print("Inventory texture slot press ignored because inventory interaction is disabled.")
		return

	var slot_name := str(btn.name)
	var container_name := get_container_name_for_slot(slot_name)
	if container_name == "":
		return

	var slot := get_slot_data(slot_name)
	if slot.is_empty() or slot["item_id"] == "":
		return

	press_slot_name = slot_name
	press_container_name = container_name
	press_button = btn
	press_start_msec = Time.get_ticks_msec()
	press_start_pos = get_viewport().get_mouse_position()


func _on_slot_button_up(_btn: TextureButton) -> void:
	if Globals.is_popup_input_locked():
		cleanup_drag_state()
		return

	if not inventory_interaction_enabled:
		return

	if drag_active:
		finish_drag_at_mouse()
	else:
		clear_press_tracking()


func _input(event: InputEvent) -> void:
	# Summary: Feed mouse motion and release events into texture and label drag systems.
	if Globals.is_popup_input_locked():
		cleanup_drag_state()
		cleanup_label_drag_state()
		return

	if not inventory_interaction_enabled:
		return

	if event is InputEventMouseMotion:
		update_drag_from_motion()
		update_label_drag_from_motion()

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if not event.pressed and drag_active:
			finish_drag_at_mouse()
		if not event.pressed and label_drag_active:
			finish_label_drag_at_mouse()


func _process(_delta: float) -> void:
	# Summary: Keep active texture and label drag previews updated while inventory runs.
	if Globals.is_popup_input_locked():
		cleanup_drag_state()
		cleanup_label_drag_state()
		return

	if not inventory_interaction_enabled:
		return

	update_drag_from_motion()
	update_label_drag_from_motion()

	if drag_active:
		update_drag_preview_position()
	if label_drag_active:
		update_label_drag_preview_position()


func update_drag_from_motion() -> void:
	if press_button == null or drag_active:
		return

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		clear_press_tracking()
		return

	var elapsed := Time.get_ticks_msec() - press_start_msec
	var moved := press_start_pos.distance_to(get_viewport().get_mouse_position())

	if elapsed >= drag_long_press_msec and moved >= drag_start_distance:
		start_drag()


func start_drag() -> void:
	if press_button == null:
		return

	hold_item_slot_name = press_slot_name
	hold_item_container_name = press_container_name
	drag_active = true
	clear_selected_slot()

	press_button.modulate = SLOT_MODULATE_DRAG_SOURCE

	drag_preview = TextureRect.new()
	drag_preview.texture = press_button.texture_normal
	drag_preview.size = press_button.size
	drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_preview.stretch_mode = TextureRect.STRETCH_SCALE
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.modulate = Color(1, 1, 1, 0.85)
	drag_preview.z_index = 1000
	get_tree().current_scene.add_child(drag_preview)
	update_drag_preview_position()


func update_drag_preview_position() -> void:
	if drag_preview == null:
		return

	drag_preview.position = get_viewport().get_mouse_position() - (drag_preview.size / 2.0)


func finish_drag_at_mouse() -> void:
	if not drag_active:
		clear_press_tracking()
		return

	var hovered := get_viewport().gui_get_hovered_control()
	if is_recycle_drop_hovered(hovered):
		recycle_slot_item(hold_item_container_name, hold_item_slot_name)
		cleanup_drag_state()
		drag_just_finished = true
		call_deferred("_reset_drag_just_finished")
		return

	var target_button := hovered as TextureButton

	if target_button != null:
		var target_slot_name := str(target_button.name)
		var target_container_name := get_container_name_for_slot(target_slot_name)

		if target_container_name != "":
			swap_held_slot_with(target_container_name, target_slot_name)

	cleanup_drag_state()
	drag_just_finished = true
	call_deferred("_reset_drag_just_finished")


func cleanup_drag_state() -> void:
	if press_button != null:
		press_button.modulate = SLOT_MODULATE_NORMAL

	if drag_preview != null:
		drag_preview.queue_free()
		drag_preview = null

	hold_item_slot_name = null
	hold_item_container_name = ""
	drag_active = false
	clear_press_tracking()


func clear_press_tracking() -> void:
	press_slot_name = null
	press_container_name = ""
	press_button = null
	press_start_msec = 0
	press_start_pos = Vector2.ZERO


func _reset_drag_just_finished() -> void:
	drag_just_finished = false


func cancel_held_swap() -> void:
	if Globals.print_priority_3:
		print("Held swap canceled.")

	cleanup_drag_state()
	
	
	
	
func has_drone_anywhere(drone_id: String) -> bool:
	if not drone_cells.has("each_cell"):
		return false

	for slot in drone_cells["each_cell"]:
		var item = drone_cells["each_cell"][slot]

		if item == null:
			continue

		if Globals.print_priority_3:
			print("DRONE SLOT:", slot, " DATA:", item)

		if item.get("id", "") == drone_id:
			return true

		if item.get("item_id", "") == drone_id:
			return true

		if item.get("item_name", "") == drone_id:
			return true

	return false
	
func add_item(item_id: String, amount: int = 1, change_reason: String = "add_item") -> bool:
	if item_handler == null:
		if Globals.print_priority_1:
			print("Missing item_handler")
		return false

	if not item_handler.has_item(item_id):
		if Globals.print_priority_1:
			print("Missing item id: ", item_id)
		return false

	var item_data: Dictionary = item_handler.get_item_data(item_id)
	var stackable: bool = item_data.get("stackable", false)
	var max_stack: int = item_data.get("max_stack", 1)

	# 1. Try stacking first
	if stackable:
		for slot_name in cells["each_cell"]:
			var slot = cells["each_cell"][slot_name]

			if slot.get("item_id", "") == item_id:
				var current_count: int = slot.get("count", 0)
				var new_count: int = min(current_count + amount, max_stack)

				set_slot_item(slot_name, item_id, new_count, change_reason)
				return true

	# 2. Find empty main inventory slot
	for slot_name in cells["each_cell"]:
		var slot = cells["each_cell"][slot_name]

		if slot.get("item_id", "") == "":
			set_slot_item(slot_name, item_id, amount, change_reason)
			return true

	if Globals.print_priority_1:
		print("Inventory full. Could not add item: ", item_id)
	return false
	
	
	
func get_save_data() -> Dictionary:
	
	var main_save := {}
	var drone_save := {}

	for slot_name in cells["each_cell"]:
		var slot = cells["each_cell"][slot_name]

		main_save[slot_name] = {
			"item_id": slot["item_id"],
			"count": slot["count"]
		}

	for slot_name in drone_cells["each_cell"]:
		var slot = drone_cells["each_cell"][slot_name]

		drone_save[slot_name] = {
			"item_id": slot["item_id"],
			"count": slot["count"]
		}

	return {
		"main": main_save,
		"drones": drone_save
	}
func load_save_data(save_data: Dictionary) -> void:
	intel_sync_suppressed = true
	if save_data.has("main"):
		for slot_name in save_data["main"]:
			var slot = save_data["main"][slot_name]

			if slot.get("item_id", "") != "":
				set_slot_item(slot_name, slot["item_id"], int(slot.get("count", 1)))

	if save_data.has("drones"):
		for slot_name in save_data["drones"]:
			var slot = save_data["drones"][slot_name]

			if slot.get("item_id", "") != "":
				set_slot_item(slot_name, slot["item_id"], int(slot.get("count", 1)))

	intel_sync_suppressed = false
	remember_intel_inventory_totals()



func setup_widget_state(new_state: WidgetsState5) -> void:
	state = new_state
	
	
func _make_label_inventory_tab(text: String, pos: Vector2, tab_id: String) -> Button:
	if Globals.print_priority_3:
		print("Creating inventory label tab: ", tab_id)

	var tab := Button.new()
	tab.name = "label_inventory_tab_" + tab_id
	tab.text = text
	tab.position = pos
	tab.size = Vector2(210, 30)

	if state != null and state.font != null:
		tab.add_theme_font_override("font", state.font)

	tab.add_theme_font_size_override("font_size", 12)
	tab.pressed.connect(_on_label_inventory_tab_pressed.bind(tab_id))
	return tab
	
	
func _on_label_inventory_tab_pressed(tab_id: String) -> void:
	# Summary: Switch visible inventory list between category-filtered row views.
	if Globals.is_popup_input_locked():
		if Globals.print_priority_2:
			print("Inventory tab click ignored while tutorial/story popup is active.")
		return

	if Globals.print_priority_2:
		print("[INV5_TAB_DEBUG] tab pressed: ", tab_id)

	var clean_tab_id := tab_id.strip_edges().to_lower()
	if clean_tab_id == "cargo":
		clean_tab_id = "slots"

	if not LABEL_INVENTORY_TAB_IDS.has(clean_tab_id):
		if Globals.print_priority_1:
			print("[INV5_TAB_DEBUG] invalid tab_id: ", tab_id)
		return

	label_inventory_active_tab = clean_tab_id
	label_inventory_active_category = clean_tab_id
	if clean_tab_id != "recovery":
		label_inventory_selected_recovery_container = ""
		label_inventory_selected_recovery_slot = ""
	refresh_label_inventory_rows()
