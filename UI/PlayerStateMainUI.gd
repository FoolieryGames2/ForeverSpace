extends Node
class_name PlayerStateMainUI


# ==========================================================
# AMI REPORT — MAIN MODE PLAYER STATE UI
# ----------------------------------------------------------
# Display and button-routing handler for main-mode vessel state.
# WidgetsBuilder5 builds visual nodes. MainMode owns actual stat,
# inventory, save, and game-rule mutation.
# ==========================================================

const ITEM_REPAIR_KIT := "repair_kit"
const ITEM_PATCH_CELL := "shield_patch_cell"
const ITEM_RECHARGE_KIT := "recharge_kit"
const PATCH_CELL_IDS := ["shield_patch_cell", "patch_cell", "smart_guy_patch_cell"]
const AMI_REPORT_FIELD_DEBUG := true


var state: WidgetsState5 = null
var player_state: PlayerState = null
var inventory = null
var item_handler = null
var main_mode_owner = null

var last_signature: String = ""
var refresh_timer: float = 0.0
var refresh_interval: float = 0.20
var button_signals_connected := false
var last_supply_message := ""
var last_supply_message_timer := 0.0
var last_field_debug_signature := ""
var last_button_debug_signature := ""



func setup(new_state: WidgetsState5, new_player_state: PlayerState, new_inventory = null, new_item_handler = null, new_owner = null) -> void:
	state = new_state
	player_state = new_player_state
	inventory = new_inventory
	item_handler = new_item_handler
	main_mode_owner = new_owner
	last_signature = ""
	last_field_debug_signature = ""
	last_button_debug_signature = ""
	debug_field_print("setup", "state=" + str(state) + " player_state=" + str(player_state) + " inventory=" + str(inventory) + " item_handler=" + str(item_handler) + " owner=" + str(main_mode_owner))
	connect_supply_buttons_once()
	refresh("setup")


func set_inventory_refs(new_inventory, new_item_handler = null, new_owner = null) -> void:
	inventory = new_inventory
	item_handler = new_item_handler
	if new_owner != null:
		main_mode_owner = new_owner
	last_signature = ""
	last_field_debug_signature = ""
	last_button_debug_signature = ""
	debug_field_print("set_inventory_refs", "inventory=" + str(inventory) + " item_handler=" + str(item_handler) + " owner=" + str(main_mode_owner))
	refresh("inventory_refs")


func refresh(reason: String = "") -> void:
	# Summary: Force the AMI Report to redraw from the current PlayerState packet.
	if state == null:
		return
	if player_state == null:
		set_unavailable("Player state missing")
		return

	connect_supply_buttons_once()
	var packet := get_player_state_packet()
	apply_packet(packet, reason)


func update_if_changed(delta: float) -> void:
	# Summary: Cheap polling fallback so missed call-sites still update the report.
	if state == null or player_state == null:
		return

	if last_supply_message_timer > 0.0:
		last_supply_message_timer = max(last_supply_message_timer - delta, 0.0)
		if last_supply_message_timer <= 0.0:
			last_supply_message = ""
			last_signature = ""

	refresh_timer -= delta
	if refresh_timer > 0.0:
		return

	refresh_timer = refresh_interval
	var packet := get_player_state_packet()
	var signature := build_signature(packet)
	if signature == last_signature:
		return

	apply_packet(packet, "signature_changed")


func get_player_state_packet() -> Dictionary:
	# Summary: Prefer the live state packet, but fall back to save data if needed.
	if player_state == null:
		return {}

	if player_state.has_method("get_state_packet"):
		var state_packet = player_state.get_state_packet()
		if typeof(state_packet) == TYPE_DICTIONARY:
			return state_packet

	if player_state.has_method("get_save_data"):
		var save_packet = player_state.get_save_data()
		if typeof(save_packet) == TYPE_DICTIONARY:
			return save_packet

	return {}


func apply_packet(packet: Dictionary, reason: String = "") -> void:
	# Summary: Push one player state packet into the widget nodes.
	if packet.is_empty():
		set_unavailable("No vessel data")
		return

	var hull_current := float(packet.get("hull_current", packet.get("player_hull_current", 0.0)))
	var hull_max = max(float(packet.get("hull_max", packet.get("player_hull_max", 1.0))), 1.0)

	var shield_current := float(packet.get("shield_hp_current", packet.get("player_shield_hp_current", packet.get("shield_current", 0.0))))
	var shield_max = max(float(packet.get("shield_hp_max", packet.get("player_shield_hp_max", packet.get("shield_max", 0.0)))), 0.0)

	var energy_current := float(packet.get("energy_current", packet.get("player_energy_current", 0.0)))
	var energy_max = max(float(packet.get("energy_max", packet.get("player_energy_max", 1.0))), 1.0)

	_set_label_text("ami_report_hull_value", format_stat(hull_current, hull_max))
	_set_label_text("ami_report_shield_value", format_stat(shield_current, shield_max))
	_set_label_text("ami_report_energy_value", format_stat(energy_current, energy_max))

	_set_bar_percent("hull", safe_percent(hull_current, hull_max))
	_set_bar_percent("shield", safe_percent(shield_current, shield_max))
	_set_bar_percent("energy", safe_percent(energy_current, energy_max))

	var status := build_status_text(packet, hull_current, hull_max, shield_current, shield_max, energy_current, energy_max)
	_set_label_text("ami_report_status_line", status)
	_set_status_visual(status)

	update_supply_buttons(packet, hull_current, hull_max, shield_current, shield_max, energy_current, energy_max)

	last_signature = build_signature(packet)

	if Globals.print_priority_3:
		print("[AMI_REPORT_REFRESH] reason=", reason, " signature=", last_signature)


func set_unavailable(message: String) -> void:
	_set_label_text("ami_report_hull_value", "-- / --")
	_set_label_text("ami_report_shield_value", "-- / --")
	_set_label_text("ami_report_energy_value", "-- / --")
	_set_bar_percent("hull", 0.0)
	_set_bar_percent("shield", 0.0)
	_set_bar_percent("energy", 0.0)
	_set_label_text("ami_report_status_line", message)
	_set_label_text("ami_report_supply_line", "Field support: waiting")
	_set_label_text("ami_report_upgrade_line", "Field support: waiting")
	set_button_state("ami_report_use_repair", false, false, "REPAIR")
	set_button_state("ami_report_use_patch", false, false, "PATCH")
	set_button_state("ami_report_use_recharge", false, false, "RECHARGE")
	last_signature = "unavailable:" + message


func build_signature(packet: Dictionary) -> String:
	return (
		"H:" + str(packet.get("hull_current", packet.get("player_hull_current", 0.0))) + "/" + str(packet.get("hull_max", packet.get("player_hull_max", 0.0))) +
		"|S:" + str(packet.get("shield_hp_current", packet.get("player_shield_hp_current", packet.get("shield_current", 0.0)))) + "/" + str(packet.get("shield_hp_max", packet.get("player_shield_hp_max", packet.get("shield_max", 0.0)))) +
		"|E:" + str(packet.get("energy_current", packet.get("player_energy_current", 0.0))) + "/" + str(packet.get("energy_max", packet.get("player_energy_max", 0.0))) +
		"|repair:" + str(count_inventory_item(ITEM_REPAIR_KIT)) +
		"|patch:" + str(count_inventory_items(PATCH_CELL_IDS)) +
		"|recharge:" + str(count_inventory_item(ITEM_RECHARGE_KIT)) +
		"|msg:" + last_supply_message +
		"|alive:" + str(packet.get("is_alive", true)) +
		"|destroyed:" + str(packet.get("is_destroyed", false))
	)


func build_status_text(
	packet: Dictionary,
	hull_current: float,
	hull_max: float,
	shield_current: float,
	shield_max: float,
	energy_current: float,
	energy_max: float
) -> String:
	var destroyed := bool(packet.get("is_destroyed", false)) or bool(packet.get("is_alive", true)) == false or hull_current <= 0.0
	if destroyed:
		return "Destroyed"

	if safe_percent(hull_current, hull_max) <= 0.25:
		return "Hull Critical"

	if safe_percent(energy_current, energy_max) <= 0.15:
		return "Energy Low"

	if shield_max > 0.0 and shield_current <= 0.0:
		return "Shield Offline"

	return "Stable"


func update_supply_buttons(
	_packet: Dictionary,
	_hull_current: float,
	_hull_max: float,
	_shield_current: float,
	_shield_max: float,
	_energy_current: float,
	_energy_max: float
) -> void:
	ensure_supply_buttons_exist()
	connect_supply_buttons_once()

	var repair_count := count_inventory_item(ITEM_REPAIR_KIT)
	var patch_count := count_inventory_items(PATCH_CELL_IDS)
	var recharge_count := count_inventory_item(ITEM_RECHARGE_KIT)
	var owned_total := repair_count + patch_count + recharge_count

	set_button_state("ami_report_use_repair", false, false, "REPAIR")
	set_button_state("ami_report_use_patch", false, false, "PATCH")
	set_button_state("ami_report_use_recharge", false, false, "RECHARGE")

	if last_supply_message != "":
		_set_label_text("ami_report_supply_line", last_supply_message)
		_set_label_text("ami_report_upgrade_line", last_supply_message)
		return

	if owned_total > 0:
		_set_label_text("ami_report_supply_line", "Recovery supplies: use Inventory > RECOV")
		_set_label_text("ami_report_upgrade_line", "Recovery supplies: use Inventory > RECOV")
	else:
		_set_label_text("ami_report_supply_line", "Recovery supplies: none")
		_set_label_text("ami_report_upgrade_line", "Recovery supplies: none")


func join_text_array(values: Array, separator: String = ", ") -> String:
	var text := ""
	for i in range(values.size()):
		if i > 0:
			text += separator
		text += str(values[i])
	return text


func connect_supply_buttons_once() -> void:
	if state == null:
		return

	ensure_supply_buttons_exist()

	var repair_button := get_button("ami_report_use_repair")
	var patch_button := get_button("ami_report_use_patch")
	var recharge_button := get_button("ami_report_use_recharge")

	connect_button_signal(repair_button, Callable(self, "_on_repair_button_pressed"))
	connect_button_signal(patch_button, Callable(self, "_on_patch_button_pressed"))
	connect_button_signal(recharge_button, Callable(self, "_on_recharge_button_pressed"))

	button_signals_connected = repair_button != null and patch_button != null and recharge_button != null
	var button_debug_signature := str([repair_button, patch_button, recharge_button, button_signals_connected])
	if button_debug_signature != last_button_debug_signature:
		last_button_debug_signature = button_debug_signature
		debug_field_print("connect_buttons", "repair=" + str(repair_button) + " patch=" + str(patch_button) + " recharge=" + str(recharge_button) + " all_connected=" + str(button_signals_connected))


func connect_button_signal(button: Button, callback: Callable) -> void:
	if button == null:
		return
	if button.pressed.is_connected(callback):
		return
	button.pressed.connect(callback)


func _on_repair_button_pressed() -> void:
	request_use_item(ITEM_REPAIR_KIT)


func _on_patch_button_pressed() -> void:
	request_use_item(resolve_first_owned_item(PATCH_CELL_IDS, ITEM_PATCH_CELL))


func _on_recharge_button_pressed() -> void:
	request_use_item(ITEM_RECHARGE_KIT)


func request_use_item(item_id: String) -> void:
	if main_mode_owner == null or not main_mode_owner.has_method("request_ami_report_use_item"):
		show_supply_message("AMI: field kit handler missing.")
		return

	var result = main_mode_owner.request_ami_report_use_item(item_id, "ami_report_button")
	if typeof(result) == TYPE_DICTIONARY:
		show_supply_message(str(result.get("message", "AMI: field kit action complete.")))
	else:
		show_supply_message("AMI: field kit action returned no data.")
	last_signature = ""
	refresh("after_button_" + item_id)


func show_supply_message(message: String, duration: float = 2.5) -> void:
	last_supply_message = message
	last_supply_message_timer = duration
	_set_label_text("ami_report_supply_line", message)
	_set_label_text("ami_report_upgrade_line", message)


func count_inventory_item(item_id: String) -> int:
	# Summary: Count live inventory items without requiring every inventory sub-container to be built.
	var clean_item_id := str(item_id).strip_edges()
	if inventory == null or clean_item_id == "":
		return 0

	var total := 0
	var main_cells = inventory.get("cells")
	if typeof(main_cells) == TYPE_DICTIONARY:
		total += count_item_in_slot_map(main_cells.get("each_cell", {}), clean_item_id)

	var drone_cells = inventory.get("drone_cells")
	if typeof(drone_cells) == TYPE_DICTIONARY:
		total += count_item_in_slot_map(drone_cells.get("each_cell", {}), clean_item_id)

	if total > 0:
		return total

	# Only call Inventory5's built-in helpers after both storage maps exist; those
	# helpers index cells["each_cell"] and drone_cells["each_cell"] directly.
	if inventory_slot_maps_ready() and inventory.has_method("count_item_anywhere"):
		return int(inventory.count_item_anywhere(clean_item_id))

	if inventory_slot_maps_ready() and inventory.has_method("has_item_anywhere") and inventory.has_item_anywhere(clean_item_id):
		return 1

	return 0


func inventory_slot_maps_ready() -> bool:
	if inventory == null:
		return false
	var main_cells = inventory.get("cells")
	var drone_cells = inventory.get("drone_cells")
	return (
		typeof(main_cells) == TYPE_DICTIONARY
		and main_cells.has("each_cell")
		and typeof(drone_cells) == TYPE_DICTIONARY
		and drone_cells.has("each_cell")
	)


func count_item_in_slot_map(slot_map, item_id: String) -> int:
	if typeof(slot_map) != TYPE_DICTIONARY:
		return 0

	var total := 0
	for slot_name in slot_map.keys():
		var slot = slot_map[slot_name]
		if typeof(slot) != TYPE_DICTIONARY:
			continue

		var slot_item_id := str(slot.get("item_id", "")).strip_edges()
		var slot_count := int(slot.get("count", 0))
		if slot_item_id == item_id and slot_count > 0:
			total += slot_count

	return total


func count_inventory_items(item_ids: Array) -> int:
	var total := 0
	for item_id in item_ids:
		total += count_inventory_item(str(item_id))
	return total


func resolve_first_owned_item(item_ids: Array, fallback_item_id: String = "") -> String:
	for item_id in item_ids:
		var clean_id := str(item_id).strip_edges()
		if clean_id != "" and count_inventory_item(clean_id) > 0:
			if AMI_REPORT_FIELD_DEBUG and Globals.print_priority_9:
				print("PlayerStateMainUI | resolve_first_owned_item owned=", clean_id, " from=", item_ids)
			return clean_id
	if AMI_REPORT_FIELD_DEBUG and Globals.print_priority_9:
		print("PlayerStateMainUI | resolve_first_owned_item fallback=", fallback_item_id, " from=", item_ids)
	return fallback_item_id

func ensure_supply_buttons_exist() -> void:
	# Summary: Self-heal this widget when the active Widgets_Builder5.gd only built labels/bars.
	# This keeps the patch isolated to PlayerStateMainUI.gd.
	if state == null:
		return

	var root = null
	if state.controls.has("ami_report_root"):
		root = state.controls["ami_report_root"]
	if not (root is Control):
		debug_field_print("ensure_buttons", "missing ami_report_root; cannot create fallback buttons yet")
		return

	var ami_root := root as Control
	ensure_supply_label_alias(ami_root)
	fit_status_label_for_button_row(ami_root)

	ensure_one_supply_button(ami_root, "ami_report_use_repair", "REPAIR", 0)
	ensure_one_supply_button(ami_root, "ami_report_use_patch", "PATCH", 1)
	ensure_one_supply_button(ami_root, "ami_report_use_recharge", "RECHARGE", 2)


func ensure_one_supply_button(root: Control, button_key: String, default_text: String, index: int) -> void:
	if get_button(button_key) != null:
		return

	var button := Button.new()
	button.name = button_key
	button.text = default_text
	button.visible = false
	button.disabled = true
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 8)
	if state != null and state.font != null:
		button.add_theme_font_override("font", state.font)

	var row_y = max(root.size.y - 45.0, 112.0)
	var widths := [58.0, 54.0, 72.0]
	var starts := [100.0, 162.0, 220.0]
	button.position = Vector2(starts[index], row_y)
	button.size = Vector2(widths[index], 18.0)

	root.add_child(button)
	state.buttons[button_key] = {"button": button}
	debug_field_print("fallback_button_created", button_key + " pos=" + str(button.position) + " size=" + str(button.size))


func ensure_supply_label_alias(root: Control) -> void:
	if state.labels.has("ami_report_supply_line"):
		return

	if state.labels.has("ami_report_upgrade_line") and state.labels["ami_report_upgrade_line"] is Label:
		var existing := state.labels["ami_report_upgrade_line"] as Label
		existing.name = "ami_report_supply_line"
		existing.position = Vector2(10.0, max(root.size.y - 22.0, 134.0))
		existing.size = Vector2(max(root.size.x - 20.0, 80.0), 18.0)
		state.labels["ami_report_supply_line"] = existing
		debug_field_print("supply_label_alias", "using existing upgrade line as supply line")
		return

	var label := Label.new()
	label.name = "ami_report_supply_line"
	label.text = "Field support: waiting"
	label.position = Vector2(10.0, max(root.size.y - 22.0, 134.0))
	label.size = Vector2(max(root.size.x - 20.0, 80.0), 18.0)
	label.add_theme_font_size_override("font_size", 10)
	if state != null and state.font != null:
		label.add_theme_font_override("font", state.font)
	root.add_child(label)
	state.labels["ami_report_supply_line"] = label
	state.labels["ami_report_upgrade_line"] = label
	debug_field_print("supply_label_created", "created fallback supply label")


func fit_status_label_for_button_row(root: Control) -> void:
	if not state.labels.has("ami_report_status_line"):
		return
	var label = state.labels["ami_report_status_line"]
	if not (label is Label):
		return
	var status_label := label as Label
	status_label.position = Vector2(10.0, max(root.size.y - 43.0, 113.0))
	status_label.size = Vector2(86.0, 18.0)


func get_button(button_key: String) -> Button:
	if state == null:
		return null
	if not state.buttons.has(button_key):
		return null
	var button_packet = state.buttons[button_key]
	if typeof(button_packet) == TYPE_DICTIONARY and button_packet.has("button") and button_packet["button"] is Button:
		return button_packet["button"] as Button
	if button_packet is Button:
		return button_packet as Button
	return null


func set_button_state(button_key: String, visible: bool, enabled: bool, text: String) -> void:
	ensure_supply_buttons_exist()
	var button := get_button(button_key)
	if button == null:
		debug_field_print("set_button_state_missing", button_key + " visible=" + str(visible) + " enabled=" + str(enabled) + " text=" + text)
		return
	button.visible = visible
	button.disabled = not enabled
	button.text = text


func debug_supply_decision(
	repair_count: int,
	patch_count: int,
	recharge_count: int,
	show_repair: bool,
	show_patch: bool,
	show_recharge: bool,
	can_repair: bool,
	can_patch: bool,
	can_recharge: bool,
	hull_current: float,
	hull_max: float,
	shield_current: float,
	shield_max: float,
	energy_current: float,
	energy_max: float
) -> void:
	if not AMI_REPORT_FIELD_DEBUG or not Globals.print_priority_9:
		return

	var buttons_exist := [
		get_button("ami_report_use_repair") != null,
		get_button("ami_report_use_patch") != null,
		get_button("ami_report_use_recharge") != null
	]
	var inventory_snapshot := build_inventory_debug_snapshot()
	var debug_signature := str([
		repair_count,
		patch_count,
		recharge_count,
		show_repair,
		show_patch,
		show_recharge,
		can_repair,
		can_patch,
		can_recharge,
		hull_current,
		hull_max,
		shield_current,
		shield_max,
		energy_current,
		energy_max,
		buttons_exist,
		inventory_snapshot
	])

	if debug_signature == last_field_debug_signature:
		return
	last_field_debug_signature = debug_signature

	print("[AMI_REPORT_FIELD_DEBUG][decision] counts=", [repair_count, patch_count, recharge_count], " show=", [show_repair, show_patch, show_recharge], " can=", [can_repair, can_patch, can_recharge])
	print("[AMI_REPORT_FIELD_DEBUG][stats] hull=", hull_current, "/", hull_max, " shield=", shield_current, "/", shield_max, " energy=", energy_current, "/", energy_max)
	print("[AMI_REPORT_FIELD_DEBUG][buttons_exist] repair/patch/recharge=", buttons_exist)
	print("[AMI_REPORT_FIELD_DEBUG][inventory] ", inventory_snapshot)


func build_inventory_debug_snapshot() -> Dictionary:
	var result := {
		"inventory": str(inventory),
		"main_ready": false,
		"main_size": 0,
		"main_filled": [],
		"drone_ready": false,
		"drone_size": 0,
		"drone_filled": []
	}

	if inventory == null:
		return result

	var main_cells = inventory.get("cells")
	if typeof(main_cells) == TYPE_DICTIONARY:
		var main_each = main_cells.get("each_cell", {})
		result["main_ready"] = typeof(main_each) == TYPE_DICTIONARY
		if typeof(main_each) == TYPE_DICTIONARY:
			result["main_size"] = main_each.size()
			result["main_filled"] = collect_filled_slot_debug(main_each, 16)

	var drone_cells = inventory.get("drone_cells")
	if typeof(drone_cells) == TYPE_DICTIONARY:
		var drone_each = drone_cells.get("each_cell", {})
		result["drone_ready"] = typeof(drone_each) == TYPE_DICTIONARY
		if typeof(drone_each) == TYPE_DICTIONARY:
			result["drone_size"] = drone_each.size()
			result["drone_filled"] = collect_filled_slot_debug(drone_each, 16)

	return result


func collect_filled_slot_debug(slot_map, limit: int = 16) -> Array:
	var filled := []
	if typeof(slot_map) != TYPE_DICTIONARY:
		return filled

	for slot_name in slot_map.keys():
		var slot = slot_map[slot_name]
		if typeof(slot) != TYPE_DICTIONARY:
			continue
		var slot_item_id := str(slot.get("item_id", "")).strip_edges()
		var slot_count := int(slot.get("count", 0))
		if slot_item_id == "" and slot_count <= 0:
			continue
		filled.append(str(slot_name) + "=" + slot_item_id + " x" + str(slot_count))
		if filled.size() >= limit:
			filled.append("...")
			break

	return filled


func debug_field_print(tag: String, message: String) -> void:
	if not AMI_REPORT_FIELD_DEBUG or not Globals.print_priority_9:
		return
	print("[AMI_REPORT_FIELD_DEBUG][", tag, "] ", message)


func safe_percent(current_value: float, max_value: float) -> float:
	if max_value <= 0.0:
		return 0.0
	return clamp(current_value / max_value, 0.0, 1.0)


func format_stat(current_value: float, max_value: float) -> String:
	return format_number(current_value) + " / " + format_number(max_value)


func format_number(value: float) -> String:
	var rounded = round(value)
	if is_equal_approx(value, rounded):
		return str(int(rounded))
	var rounded_tenth = round(value * 10.0) / 10.0
	return str(rounded_tenth)


func _set_label_text(label_key: String, text: String) -> void:
	if state == null:
		return
	if not state.labels.has(label_key):
		return
	var label = state.labels[label_key]
	if label is Label:
		(label as Label).text = text
	elif label is RichTextLabel:
		(label as RichTextLabel).text = text


func _set_bar_percent(stat_id: String, percent: float) -> void:
	if state == null:
		return

	var rail_key := "ami_report_" + stat_id + "_bar_rail"
	var fill_key := "ami_report_" + stat_id + "_bar_fill"
	if not state.color_rects.has(rail_key):
		return
	if not state.color_rects.has(fill_key):
		return

	var rail = state.color_rects[rail_key]
	var fill = state.color_rects[fill_key]
	if not (rail is ColorRect) or not (fill is ColorRect):
		return

	var rail_rect := rail as ColorRect
	var fill_rect := fill as ColorRect
	fill_rect.size = Vector2(max(rail_rect.size.x * clamp(percent, 0.0, 1.0), 0.0), rail_rect.size.y)


func _set_status_visual(status: String) -> void:
	if state == null:
		return

	var status_color := Color(0.55, 0.95, 1.0, 1.0)
	if status == "Destroyed":
		status_color = Color(1.0, 0.18, 0.18, 1.0)
	elif status == "Hull Critical":
		status_color = Color(1.0, 0.32, 0.22, 1.0)
	elif status == "Energy Low":
		status_color = Color(0.45, 0.75, 1.0, 1.0)
	elif status == "Shield Offline":
		status_color = Color(0.7, 0.78, 0.92, 1.0)

	if state.labels.has("ami_report_status_line") and state.labels["ami_report_status_line"] is Label:
		(state.labels["ami_report_status_line"] as Label).modulate = status_color
