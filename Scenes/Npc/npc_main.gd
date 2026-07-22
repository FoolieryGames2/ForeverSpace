extends Node2D
class_name NPCMain

# =========================================================
# NPC MAIN
# ---------------------------------------------------------
# NPC chat scene owner.
#
# Current NPC scene UI:
# - NPC contact/dialogue log
# - NPC-local item detail log
# - NPC inventory clone panel
# - NPC action options
#
# Inventory clone rule:
# Do not move/reparent the main-mode Inventory5 node.
# Build a local Inventory5 instance and point its item-detail output
# at this scene's item_detail_box through NPCInventoryWidgetState.
# =========================================================

const Inventory5Script := preload("res://Control/Control/Inventory5.gd")
const ItemHandlerScript := preload("res://Control/Control/item_handler.gd")
const ControllerFocusOverlayScript := preload("res://UI/Controller/ControllerFocusOverlay.gd")
const ControllerSceneListFocusScript := preload("res://UI/Controller/ControllerSceneListFocus.gd")

const NPC_INVENTORY_PANEL_SIZE := Vector2(425, 250)
const NPC_ITEM_DETAIL_PANEL_SIZE := Vector2(425, 250)
const NPC_LOG_PANEL_SIZE := Vector2(400, 250)
const NPC_TRADE_PANEL_SIZE := Vector2(375, 260)
const NPC_ACTION_PANEL_SIZE := Vector2(400, 170)
const NPC_PANEL_GAP := 12
const NPC_LEGACY_SLOT_BUILD_POS := Vector2(-10000, -10000)
const NPC_LAYOUT_TOP := 105.0
const NPC_LAYOUT_LEFT_X := 25.0
const NPC_LAYOUT_MID_X := 475.0
const NPC_LAYOUT_RIGHT_X := 900.0
const DEFAULT_CHAT_LINE_DELAY := 1.65
const DEFAULT_CHAT_CHARACTER_DELAY := 0.04
var star_field = StarField
var save_manager = null
var widget_spec_ui: WidgetSpecUi = null
var decorative_ui: DecorativeUI = null
var aurora_bg: AuroraBrainBackground = null
var aurora_holder = preload("res://images/blue_scifi_backing.png")
var color_handler: Color_Handler = null
var npc_background_root: Control = null
var npc_background_texture: TextureRect = null

var player_state_save_data: Dictionary = {}
var npc_player_state_dirty: bool = false
# =========================================================
# UI STATE ADAPTER
# ---------------------------------------------------------
# Main mode can pass Widgets_State5.
# NPC chat can pass NPCInventoryWidgetState.
#
# Keep this untyped because both objects provide:
# controls, buttons, log_storage, font.
# =========================================================
var state = null
var widget_state: WidgetsState5 = null

var bob := NPC.new()

var npc: NPC = null
var log_box: TextEdit = null
var item_detail_box: TextEdit = null
var action_button_list: VBoxContainer = null
var ui_built := false

var trade_root: Control = null
var trade_text_box: TextEdit = null
var trade_accept_button: Button = null
var chat_action_button: Button = null
var trade_action_button: Button = null
var event_accept_button: Button = null

var active_trade_offer: Dictionary = {}
var active_trade_accepted := false
var active_chat_lines: Array = []
var visible_chat_lines: Array = []
var active_chat_line_index: int = 0
var active_chat_character_index: int = 0
var active_chat_line_delay: float = DEFAULT_CHAT_LINE_DELAY
var active_chat_character_delay: float = DEFAULT_CHAT_CHARACTER_DELAY
var active_chat_line_timer: float = 0.0
var active_chat_character_timer: float = 0.0
var chat_playback_active: bool = false
var chat_waiting_for_next_line: bool = false

var npc_item_handler = null
var npc_inventory = null
var npc_inventory_root: Control = null
var npc_player_state: PlayerState = null
var controller_focus_overlay: ControllerFocusOverlay = null
var controller_scene_focus: ControllerSceneListFocus = null


func setup_needed(new_starfield):
	star_field = new_starfield
	
	
func _ready() -> void:
	ensure_npc_widget_state()
	build_background()

	save_manager = SaveManager.new()

	if save_manager is Node:
		add_child(save_manager)

	build_ui()

	if Globals.current_npc != null:
		setup_npc_from_data(Globals.current_npc)
	setup_controller_focus_handler()


func _process(delta: float) -> void:
	update_decorative_ui(delta)
	process_npc_chat_playback(delta)

	if widget_spec_ui != null:
		widget_spec_ui.process_onscreen_widget_runtime(delta)


func _input(event: InputEvent) -> void:
	if controller_scene_focus != null and is_instance_valid(controller_scene_focus):
		if controller_scene_focus.handle_input(event):
			get_viewport().set_input_as_handled()


func setup_npc(new_npc: NPC) -> void:
	npc = new_npc

	if not ui_built:
		build_ui()

	configure_trade_widget_from_npc()
	configure_npc_action_buttons()
	write_intro_log()
	setup_controller_focus_handler()


func build_ui() -> void:
	if ui_built:
		return

	ensure_npc_widget_state()
	ui_built = true
	z_index = 100

	build_log_box()
	build_item_detail_box()
	build_npc_widget_state()
	build_npc_inventory_clone()
	build_action_box()
	build_trade_widget()
	build_npc_decorative_overlays()
	setup_npc_widget_spec_runtime()


func build_background() -> void:
	help_arora_work()

	decorative_ui = DecorativeUI.new()
	decorative_ui.name = "npc_decorative_ui"
	add_child(decorative_ui)
	decorative_ui.build_hostile_contact_alert()
	decorative_ui.build_receiving_message_alert()


func help_arora_work() -> void:
	npc_background_root = Control.new()
	npc_background_root.name = "npc_background_root"
	npc_background_root.size = Vector2(Globals.screen_w, Globals.screen_h)
	npc_background_root.position = Vector2.ZERO
	npc_background_root.z_index = -100
	npc_background_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(npc_background_root)
	store_control("npc_background_root", npc_background_root)

	npc_background_texture = TextureRect.new()
	npc_background_texture.name = "npc_blue_scifi_background"
	npc_background_texture.texture = aurora_holder
	npc_background_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	npc_background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	npc_background_texture.stretch_mode = TextureRect.STRETCH_SCALE
	npc_background_texture.z_index = -10
	npc_background_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	npc_background_root.add_child(npc_background_texture)
	store_control("npc_blue_scifi_background", npc_background_texture)

	var aurora_container := Control.new()
	aurora_container.name = "npc_aurora_container"
	aurora_container.size = Globals.aurora_size
	aurora_container.position = Globals.aurora_pos
	aurora_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	npc_background_root.add_child(aurora_container)
	store_control("npc_aurora_container", aurora_container)

	aurora_bg = AuroraBrainBackground.new()
	aurora_bg.name = "npc_aurora_background"
	aurora_container.add_child(aurora_bg)
	aurora_bg.set_anchors_preset(Control.PRESET_CENTER)
	aurora_bg.z_index = -10
	aurora_bg.anchor_left = 0.0
	aurora_bg.anchor_top = 0.0
	aurora_bg.anchor_right = 1.0
	aurora_bg.anchor_bottom = 1.0
	aurora_bg.offset_left = 0
	aurora_bg.offset_top = 0
	aurora_bg.offset_right = 0
	aurora_bg.offset_bottom = 0
	store_control("npc_aurora_background", aurora_bg)


func update_decorative_ui(delta: float) -> void:
	if decorative_ui == null:
		return

	decorative_ui.update_decorative_ui(delta)


func ensure_npc_widget_state() -> void:
	if widget_state != null:
		state = widget_state
		return

	widget_state = WidgetsState5.new()
	widget_state.name = "npc_widget_state"
	add_child(widget_state)
	state = widget_state


func store_control(key: String, control: CanvasItem) -> void:
	if widget_state == null or control == null:
		return

	widget_state.controls[key] = control


func store_label(key: String, label: Label) -> void:
	if widget_state == null or label == null:
		return

	widget_state.labels[key] = label


func store_color_rect(key: String, color_rect: ColorRect) -> void:
	if widget_state == null or color_rect == null:
		return

	widget_state.color_rects[key] = color_rect


func store_button(key: String, button: Button) -> void:
	if widget_state == null or button == null:
		return

	widget_state.buttons[key] = button


func store_log_ref(key: String, text_control: TextEdit) -> void:
	if widget_state == null or text_control == null:
		return

	widget_state.log_storage[key] = text_control


func setup_controller_focus_handler() -> void:
	if controller_focus_overlay == null or not is_instance_valid(controller_focus_overlay):
		controller_focus_overlay = ControllerFocusOverlayScript.new()
	controller_focus_overlay.name = "NPCControllerFocusOverlay"
	controller_focus_overlay.z_index = ControllerFocusOverlay.TOP_LAYER_Z
	controller_focus_overlay.z_as_relative = false
	controller_focus_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if controller_focus_overlay.get_parent() == null:
		add_child(controller_focus_overlay)

	if controller_scene_focus == null or not is_instance_valid(controller_scene_focus):
		controller_scene_focus = ControllerSceneListFocusScript.new()
	controller_scene_focus.name = "NPCControllerSceneFocus"
	if controller_scene_focus.get_parent() == null:
		add_child(controller_scene_focus)

	var focus_root = widget_state.controls.get("npc_action_root", null) if widget_state != null else null
	controller_scene_focus.setup({
		"owner_scene": self,
		"overlay": controller_focus_overlay,
		"focus_root": focus_root,
		"focus_items_provider": Callable(self, "get_npc_controller_focus_items")
	})
	move_child(controller_focus_overlay, get_child_count() - 1)


func get_npc_controller_focus_items() -> Array:
	var items: Array = []
	append_npc_controller_focus_item(items, "npc_chat", chat_action_button)
	append_npc_controller_focus_item(items, "npc_trade", trade_action_button)
	append_npc_controller_focus_item(items, "npc_quest", event_accept_button)
	append_npc_controller_focus_item(items, "npc_trade_accept", trade_accept_button)
	append_npc_controller_focus_item(items, "npc_back", widget_state.buttons.get("npc_action_back", null) if widget_state != null else null)
	return items


func append_npc_controller_focus_item(items: Array, item_id: String, node_value: Variant) -> void:
	if node_value == null or not is_instance_valid(node_value):
		return
	items.append({
		"item_id": item_id,
		"node": node_value,
		"kind": "button",
		"enabled": true
	})


func build_log_box() -> void:
	var root := Control.new()
	root.name = "npc_log_root"
	root.position = get_npc_log_pos()
	root.size = NPC_LOG_PANEL_SIZE
	add_child(root)
	store_control("npc_log_root", root)

	var bg := ColorRect.new()
	bg.name = "npc_log_bg"
	bg.color = Color(0.04, 0.06, 0.09, 0.95)
	bg.size = root.size
	root.add_child(bg)
	store_color_rect("npc_log_bg", bg)

	var header := Label.new()
	header.name = "npc_log_header"
	header.text = "NPC CONTACT"
	header.position = Vector2(10, 4)
	header.size = Vector2(root.size.x - 20, 24)
	root.add_child(header)
	store_label("npc_log_header", header)

	log_box = TextEdit.new()
	log_box.name = "npc_log_box"
	log_box.position = Vector2(0, 30)
	log_box.size = Vector2(root.size.x, root.size.y - 30)
	log_box.editable = false
	log_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	log_box.text = "Awaiting contact..."
	root.add_child(log_box)
	store_control("npc_log_box", log_box)
	store_log_ref("npc_contact_log", log_box)


func build_item_detail_box() -> void:
	var root := Control.new()
	root.name = "npc_item_detail_root"
	root.position = get_npc_item_detail_pos()
	root.size = NPC_ITEM_DETAIL_PANEL_SIZE
	add_child(root)
	store_control("npc_item_detail_root", root)

	var bg := ColorRect.new()
	bg.name = "npc_item_detail_bg"
	bg.color = Color(0.035, 0.045, 0.065, 0.95)
	bg.size = root.size
	root.add_child(bg)
	store_color_rect("npc_item_detail_bg", bg)

	var header := Label.new()
	header.name = "npc_item_detail_header"
	header.text = "ITEM DETAILS"
	header.position = Vector2(10, 4)
	header.size = Vector2(root.size.x - 20, 24)
	root.add_child(header)
	store_label("npc_item_detail_header", header)

	item_detail_box = TextEdit.new()
	item_detail_box.name = "npc_item_detail_box"
	item_detail_box.position = Vector2(0, 30)
	item_detail_box.size = Vector2(root.size.x, root.size.y - 30)
	item_detail_box.editable = false
	item_detail_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	item_detail_box.text = "Select an inventory item..."
	root.add_child(item_detail_box)
	store_control("npc_item_detail_box", item_detail_box)
	store_log_ref("log_text", item_detail_box)
	store_log_ref("npc_item_detail", item_detail_box)





func build_npc_inventory_clone() -> void:
	npc_inv_debug("build_npc_inventory_clone ENTERED")

	if item_detail_box == null:
		npc_inv_debug("BLOCKED", "item_detail_box missing")
		return

	if widget_state == null:
		npc_inv_debug("BLOCKED", "npc_inventory_state missing")
		return

	npc_inv_debug("item_detail_box OK", item_detail_box)
	npc_inv_debug("npc_inventory_state OK", widget_state)

	npc_item_handler = ItemHandlerScript.new()
	npc_item_handler.name = "npc_item_handler"
	add_child(npc_item_handler)

	npc_inv_debug("npc_item_handler created", npc_item_handler)

	npc_inventory = Inventory5Script.new()
	npc_inventory.name = "npc_inventory_clone"
	add_child(npc_inventory)

	npc_inv_debug("npc_inventory created", npc_inventory)

	if npc_inventory.has_method("setup_widget_state"):
		npc_inventory.setup_widget_state(widget_state)
		npc_inv_debug("setup_widget_state called")
	else:
		npc_inv_debug("BLOCKED", "Inventory5 missing setup_widget_state")
		item_detail_box.text = "Inventory5 missing setup_widget_state(new_state)."
		return

	npc_inventory.setup(npc_item_handler)
	npc_inv_debug("npc_inventory.setup called")

	npc_inventory.buildit(NPC_LEGACY_SLOT_BUILD_POS, 10)
	npc_inv_debug("buildit called", "main cells=" + str(npc_inventory.cells.get("each_cell", {}).size()))

	npc_inventory.build_drone_bay(NPC_LEGACY_SLOT_BUILD_POS, 10)
	npc_inv_debug("build_drone_bay called", "drone cells=" + str(npc_inventory.drone_cells.get("each_cell", {}).size()))

	var inventory_snapshot := get_inventory_snapshot_from_current_context()
	npc_inv_debug("inventory_snapshot keys", inventory_snapshot.keys())

	if not inventory_snapshot.is_empty():
		npc_inv_debug("loading inventory snapshot")
		npc_inventory.load_save_data(inventory_snapshot)
		debug_print_npc_inventory_slots("AFTER load_save_data")
	else:
		npc_inv_debug("NO INVENTORY SNAPSHOT FOUND", "panel will build empty")

	npc_inventory_root = npc_inventory.build_label_inventory_widget(get_npc_inventory_pos())

	if npc_inventory_root != null:
		npc_inventory_root.visible = true
		npc_inventory_root.z_index = 250
		npc_inventory_root.position = get_npc_inventory_pos()
		store_control("npc_inventory_root", npc_inventory_root)

		npc_inv_debug("label inventory root built", npc_inventory_root)
		npc_inv_debug("label inventory root position", npc_inventory_root.position)
		npc_inv_debug("label inventory root visible", npc_inventory_root.visible)
	else:
		npc_inv_debug("FAILED", "build_label_inventory_widget returned null")
		item_detail_box.text = "NPC inventory clone failed to build."


func get_inventory_snapshot_from_current_context() -> Dictionary:
	var context := get_npc_context()

	if context.is_empty():
		print("[NPC_INV_DEBUG] no NPC context")
		return {}

	print("[NPC_INV_DEBUG] Globals.current_npc keys: ", context.keys())

	if not context.has("inventory_save_data"):
		print("[NPC_INV_DEBUG] MISSING KEY: inventory_save_data")
		return {}

	var snapshot: Dictionary = context.get("inventory_save_data", {})

	print("[NPC_INV_DEBUG] inventory_save_data keys: ", snapshot.keys())

	if snapshot.has("main"):
		print("[NPC_INV_DEBUG] main save slots: ", snapshot["main"].size())

	if snapshot.has("drones"):
		print("[NPC_INV_DEBUG] drone save slots: ", snapshot["drones"].size())

	return snapshot

func build_action_box() -> void:
	var root := Control.new()
	root.name = "npc_action_root"
	root.position = get_npc_action_pos()
	root.size = NPC_ACTION_PANEL_SIZE
	add_child(root)
	store_control("npc_action_root", root)

	var bg := ColorRect.new()
	bg.name = "npc_action_bg"
	bg.color = Color(0.05, 0.05, 0.08, 0.9)
	bg.size = root.size
	root.add_child(bg)
	store_color_rect("npc_action_bg", bg)

	var header := Label.new()
	header.name = "npc_action_header"
	header.text = "NPC ACTIONS"
	header.position = Vector2(10, 4)
	header.size = Vector2(root.size.x - 20, 24)
	root.add_child(header)
	store_label("npc_action_header", header)

	action_button_list = VBoxContainer.new()
	action_button_list.name = "npc_action_button_list"
	action_button_list.position = Vector2(10, 35)
	action_button_list.size = Vector2(root.size.x - 20, root.size.y - 45)
	root.add_child(action_button_list)
	store_control("npc_action_button_list", action_button_list)
	widget_state.action_storage["button_list"] = action_button_list

	chat_action_button = add_npc_action_button("Chat", _on_chat_pressed)
	trade_action_button = add_npc_action_button("Trade", _on_trade_pressed)
	event_accept_button = add_npc_action_button("Quest", _on_quest_pressed)
	add_npc_action_button("Back", _on_back_pressed)
	configure_npc_action_buttons()


func add_npc_action_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	var button_key := "npc_action_" + text.to_lower().replace(" ", "_")
	btn.name = button_key + "_button"
	btn.text = text
	btn.custom_minimum_size = Vector2(NPC_ACTION_PANEL_SIZE.x - 20, 32)
	btn.pressed.connect(callback)
	action_button_list.add_child(btn)
	store_button(button_key, btn)
	return btn


func write_intro_log() -> void:
	if log_box == null or npc == null:
		return

	log_box.text = (
		"Contact: " + npc.npc_name + "\n"
		+ "Species: " + npc.npc_species + "\n"
		+ "Role: " + npc.npc_role + "\n"
		+ "Friendly: " + str(npc.is_friendly) + "\n"
		+ "Can Trade: " + str(npc.can_trade)
	)


func _on_talk_pressed() -> void:
	_on_chat_pressed()


func _on_chat_pressed() -> void:
	if npc == null:
		if Globals.print_priority_2:
			print("NPC SCENE CHAT: no NPC loaded.")

		if Globals.print_priority_3:
			print("switching to bob")

		npc = bob
		add_child(bob)
		return

	if Globals.print_priority_3:
		print("NPC SCENE CHAT: Chat pressed for " + npc.npc_name)

	#if decorative_ui != null:
		#decorative_ui.show_receiving_message_alert()

	var meet_result := npc.meet()
	mark_current_npc_met(meet_result)
		
	if Globals.print_priority_1:
		print("NPC CHAT DEBUG name: ", npc.npc_name)
		print("NPC CHAT DEBUG has dialogue meta: ", npc.has_meta("dialogue_lines"))
		print("NPC CHAT DEBUG dialogue meta: ", npc.get_meta("dialogue_lines", []))

	if log_box != null:
		start_npc_chat_playback()


func start_npc_chat_playback() -> void:
	# Summary: Type NPC dialogue from top to bottom, leaving the final text visible.
	if log_box == null or npc == null:
		return

	active_chat_lines = get_ordered_npc_chat_lines()
	visible_chat_lines.clear()
	active_chat_line_index = 0
	active_chat_character_index = 0
	active_chat_line_timer = 0.0
	active_chat_character_timer = 0.0
	active_chat_line_delay = get_active_npc_chat_line_delay()
	active_chat_character_delay = get_active_npc_chat_character_delay()
	chat_waiting_for_next_line = false
	chat_playback_active = true

	if active_chat_lines.is_empty():
		log_box.text = get_empty_chat_message()
		chat_playback_active = false
		return

	refresh_npc_chat_log_text()
	reveal_next_chat_character()


func process_npc_chat_playback(delta: float) -> void:
	if not chat_playback_active:
		return
	if log_box == null:
		chat_playback_active = false
		return

	if active_chat_line_index >= active_chat_lines.size():
		chat_playback_active = false
		chat_waiting_for_next_line = false
		return

	if chat_waiting_for_next_line:
		active_chat_line_timer += delta
		if active_chat_line_timer < active_chat_line_delay:
			return
		active_chat_line_timer = 0.0
		active_chat_character_timer = 0.0
		active_chat_character_index = 0
		chat_waiting_for_next_line = false

	active_chat_character_timer += delta
	while active_chat_character_timer >= active_chat_character_delay and chat_playback_active and not chat_waiting_for_next_line:
		active_chat_character_timer -= active_chat_character_delay
		reveal_next_chat_character()


func reveal_next_chat_character() -> void:
	if active_chat_line_index >= active_chat_lines.size():
		chat_playback_active = false
		return

	var line := str(active_chat_lines[active_chat_line_index])
	if visible_chat_lines.size() <= active_chat_line_index:
		visible_chat_lines.append("")

	active_chat_character_index = min(active_chat_character_index + 1, line.length())
	visible_chat_lines[active_chat_line_index] = line.substr(0, active_chat_character_index)
	refresh_npc_chat_log_text()

	if active_chat_character_index < line.length():
		return

	active_chat_line_index += 1
	active_chat_character_index = 0

	if active_chat_line_index >= active_chat_lines.size():
		chat_playback_active = false
		chat_waiting_for_next_line = false
		return

	chat_waiting_for_next_line = true
	active_chat_line_timer = 0.0


func refresh_npc_chat_log_text() -> void:
	if log_box == null or npc == null:
		return

	var text := npc.npc_name + ":"
	for line in visible_chat_lines:
		text += "\n" + str(line)
	log_box.text = text


func get_empty_chat_message() -> String:
	if npc == null:
		return "No chat signal available."

	var options := []
	if npc_has_available_trade():
		options.append("Trade")
	if npc_has_available_event():
		options.append("Quest")

	if options.is_empty():
		return npc.npc_name + " has nothing to say right now."

	var option_text := ""
	for option in options:
		if option_text != "":
			option_text += ", "
		option_text += str(option)
	return npc.npc_name + " has no chat lines right now.\nAvailable: " + option_text


func get_ordered_npc_chat_lines() -> Array:
	var lines: Array = []
	if npc != null and npc.has_meta("dialogue_lines"):
		var meta_lines = npc.get_meta("dialogue_lines")
		if typeof(meta_lines) == TYPE_ARRAY:
			for line in meta_lines:
				var clean_line := str(line).strip_edges()
				if clean_line != "":
					lines.append(clean_line)

	if lines.is_empty() and npc != null and npc.has_message:
		var greeting := str(npc.greeting_message).strip_edges()
		if greeting != "":
			lines.append(greeting)

	return lines


func get_active_npc_chat_line_delay() -> float:
	var delay := DEFAULT_CHAT_LINE_DELAY
	var context := get_npc_context()
	if not context.is_empty():
		delay = float(context.get("chat_line_delay", delay))
	if npc != null:
		delay = float(npc.get_meta("chat_line_delay", npc.chat_line_delay))
	return max(delay, 0.1)


func get_active_npc_chat_character_delay() -> float:
	var delay := DEFAULT_CHAT_CHARACTER_DELAY
	var context := get_npc_context()
	if not context.is_empty():
		delay = float(context.get("chat_character_delay", context.get("chat_type_delay", delay)))
	if npc != null:
		delay = float(npc.get_meta("chat_character_delay", npc.get_meta("chat_type_delay", delay)))
	return max(delay, 0.005)


func configure_npc_action_buttons() -> void:
	configure_chat_action_button()
	configure_trade_action_button()
	configure_event_action_button()


func configure_chat_action_button() -> void:
	if chat_action_button == null:
		return

	var has_chat := npc_has_chat_lines()
	chat_action_button.visible = has_chat
	chat_action_button.disabled = not has_chat
	chat_action_button.text = "Chat"


func configure_trade_action_button() -> void:
	if trade_action_button == null:
		return

	var can_use_trade := npc_has_available_trade()
	trade_action_button.visible = can_use_trade
	trade_action_button.disabled = not can_use_trade
	trade_action_button.text = "Trade"


func configure_event_action_button() -> void:
	if event_accept_button == null:
		if Globals.print_priority_1:
			print("npc_main.gd | event_accept_button == null")
		return

	var can_accept := npc_has_available_event()
	event_accept_button.visible = can_accept
	event_accept_button.disabled = not can_accept
	if Globals.print_priority_1:
			print("npc_main.gd | can_accept yes / no")
	if can_accept:
		if Globals.print_priority_1:
			print("npc_main.gd | yes, has event")
		event_accept_button.text = "Quest"
	else:
		if Globals.print_priority_1:
			print("npc_main.gd | can_accept no, no event")
		event_accept_button.text = "Quest"


func npc_has_chat_lines() -> bool:
	return not get_ordered_npc_chat_lines().is_empty()


func npc_has_available_trade() -> bool:
	return not active_trade_offer.is_empty() and not active_trade_accepted


func npc_has_available_event() -> bool:
	if npc == null:
		if Globals.print_priority_1:
			print("npc_main.gd | npc_has_available_event() | \n npc = null")
		return false

	var event_id := str(npc.get_meta("event_id", npc.event_id)).strip_edges()
	var event_state := str(npc.get_meta("event_state", npc.event_state)).strip_edges().to_lower()
	var has_event_flag := bool(npc.get_meta("has_event", npc.has_event))

	if event_id == "" or not has_event_flag:
		return false

	return event_state == "available" or event_state == "seeded" or event_state == "none" or event_state == ""


func _on_trade_pressed() -> void:
	if not npc_has_available_trade():
		if log_box != null:
			log_box.text = "No trade offer available from this contact."
		configure_npc_action_buttons()
		return

	set_trade_panel_visible(true)
	refresh_trade_widget()


func _on_quest_pressed() -> void:
	_on_accept_event_pressed()


func _on_accept_event_pressed() -> void:
	if npc == null:
		return
	if not npc_has_available_event():
		if log_box != null:
			log_box.text = "No available event from this contact."
		return

	var event_id := str(npc.get_meta("event_id", npc.event_id)).strip_edges()
	var npc_id := get_current_npc_id()
	var blueprint_id := get_current_blueprint_id()
	var event_next_step := str(npc.get_meta("event_next_step", "go_to_beacon")).strip_edges()
	if event_next_step == "":
		event_next_step = "go_to_beacon"

	grant_event_start_items()

	npc.event_state = "active"
	npc.event_step = event_next_step
	npc.current_step = event_next_step
	npc.set_meta("event_state", "active")
	npc.set_meta("event_step", event_next_step)
	npc.set_meta("current_step", event_next_step)

	if Globals.current_npc != null and typeof(Globals.current_npc) == TYPE_DICTIONARY:
		Globals.current_npc["event_state"] = "active"
		Globals.current_npc["event_step"] = event_next_step
		Globals.current_npc["current_step"] = event_next_step

	merge_npc_chat_result({
		"npc_id": npc_id,
		"blueprint_id": blueprint_id,
		"has_met": true,
		"has_event": true,
		"event_start_requested": true,
		"event_id": event_id,
		"active_event_id": event_id,
		"event_state": "active",
		"event_step": event_next_step,
		"current_step": event_next_step,
		"event_next_step": event_next_step,
		"sector_pos": npc.sector_pos,
		"local_pos": npc.local_pos
	})

	if npc.has_method("sync_shared_meta"):
		npc.sync_shared_meta()

	configure_npc_action_buttons()
	refresh_inventory_after_trade()

	if log_box != null:
		var accept_message := str(npc.get_meta("event_accept_message", "Event accepted. Coordinates added to your event console."))
		log_box.text = npc.npc_name + ": " + accept_message


func grant_event_start_items() -> void:
	if npc_inventory == null:
		return

	var start_items := get_event_start_items()
	if start_items.is_empty():
		return

	for item in start_items:
		var item_id := ""
		var amount := 1
		if typeof(item) == TYPE_DICTIONARY:
			item_id = str(item.get("item_id", item.get("id", ""))).strip_edges()
			amount = int(item.get("amount", 1))
		else:
			item_id = str(item).strip_edges()
		if item_id == "" or amount <= 0:
			continue
		if npc_inventory.has_method("has_item_anywhere") and npc_inventory.has_item_anywhere(item_id):
			continue
		if npc_inventory.has_method("add_item"):
			npc_inventory.add_item(item_id, amount)


func get_event_start_items() -> Array:
	var items = []
	var context := get_npc_context()
	if not context.is_empty():
		items = context.get("event_start_items", [])
	if (typeof(items) != TYPE_ARRAY or items.is_empty()) and npc != null:
		items = npc.get_meta("event_start_items", [])
	if typeof(items) != TYPE_ARRAY:
		return []
	return items.duplicate(true)


func get_current_npc_id() -> String:
	var context := get_npc_context()
	var npc_id := ""
	if not context.is_empty():
		npc_id = str(context.get("npc_id", ""))
	if npc_id == "" and npc != null:
		npc_id = str(npc.get_meta("npc_id", ""))
	return npc_id


func get_current_blueprint_id() -> String:
	var context := get_npc_context()
	var blueprint_id := ""
	if not context.is_empty():
		blueprint_id = str(context.get("blueprint_id", ""))
	if blueprint_id == "" and npc != null:
		blueprint_id = str(npc.get_meta("blueprint_id", ""))
	return blueprint_id


func _on_back_pressed() -> void:
	save_npc_inventory_before_exit()
	save_npc_player_state_before_exit()
	save_npc_trade_state_before_exit()

	print("NPC MAIN - _on_back_pressed | saved inventory + player state + npc trade state + scene swap")
	get_tree().change_scene_to_file("res://Scenes/main_mode.tscn")


func setup_npc_from_data(data: Dictionary) -> void:
	if data == null:
		if Globals.print_priority_1:
			print("NO NPC DATA")
		return

	debug_npc_trade_meta(data)

	var new_npc := NPC.new()

	var scene_npc_name := str(data.get("display_name", data.get("name", "Unknown Contact"))).strip_edges()
	if scene_npc_name == "":
		scene_npc_name = "Unknown Contact"
	new_npc.npc_name = scene_npc_name
	new_npc.display_name = scene_npc_name
	new_npc.sector_pos = variant_to_vector3i(data.get("sector", Vector3i.ZERO))
	new_npc.local_pos = variant_to_vector3(data.get("local", Vector3.ZERO))

	new_npc.npc_species = data.get("species", "alien")
	new_npc.npc_role = data.get("role", "traveler")
	new_npc.is_friendly = data.get("friendly", data.get("is_friendly", true))

	# Support both future and current keys.
	new_npc.can_trade = bool(data.get("can_trade", data.get("trade", false)))

	new_npc.has_message = bool(data.get("has_message", data.has("message") or data.has("greeting_message")))
	new_npc.greeting_message = data.get("message", data.get("greeting_message", ""))
	new_npc.has_met = bool(data.get("has_met", false))
	new_npc.stays_after_meeting = bool(data.get("stays_after_meeting", true))
	new_npc.depopulate_after_meeting = bool(data.get("depopulate_after_meeting", not new_npc.stays_after_meeting))

	# ------------------------------------------------------
	# Copy NPC metadata into the runtime NPC object.
	# This matches how dialogue_lines are already being used.
	# ------------------------------------------------------
	new_npc.set_meta("npc_id", data.get("npc_id", ""))
	new_npc.set_meta("blueprint_id", data.get("blueprint_id", ""))
	new_npc.set_meta("display_name", scene_npc_name)
	new_npc.set_meta("name", scene_npc_name)
	new_npc.set_meta("item_list", data.get("item_list", []).duplicate(true))
	new_npc.set_meta("dialogue_lines", data.get("dialogue_lines", []).duplicate(true))
	new_npc.chat_line_delay = max(float(data.get("chat_line_delay", new_npc.chat_line_delay)), 0.1)
	new_npc.set_meta("chat_line_delay", new_npc.chat_line_delay)
	new_npc.chat_character_delay = max(float(data.get("chat_character_delay", data.get("chat_type_delay", new_npc.chat_character_delay))), 0.005)
	new_npc.set_meta("chat_character_delay", new_npc.chat_character_delay)
	new_npc.set_meta("can_trade", new_npc.can_trade)
	new_npc.set_meta("trade_completed", bool(data.get("trade_completed", false)))
	new_npc.set_meta("offer_title", str(data.get("offer_title", "")))
	new_npc.set_meta("offer_text", str(data.get("offer_text", "")))
	new_npc.set_meta("success_text", str(data.get("success_text", "")))
	new_npc.set_meta("repeatable", bool(data.get("repeatable", data.get("retradable", false))))
	new_npc.set_meta("retradable", bool(data.get("retradable", data.get("repeatable", false))))
	new_npc.set_meta("player_state_effects", read_dictionary_array(data.get("player_state_effects", [])))
	apply_scene_npc_event_meta(new_npc, data)
	setup_player_state_from_data(data)
	player_state_save_data = {}

	var incoming_player_state = data.get("player_state_save_data", {})
	if typeof(incoming_player_state) == TYPE_DICTIONARY:
		player_state_save_data = incoming_player_state.duplicate(true)

	if Globals.print_priority_1:
		print("[NPC_PLAYER_STATE setup] has_data=", not player_state_save_data.is_empty(), " data=", player_state_save_data)

	# Critical: setup must always run.
	# This was previously nested under Globals.print_priority_1, which meant
	# exported/quiet builds could receive Globals.current_npc but never apply it
	# to the scene, leaving the contact log stuck on "Awaiting contact...".
	setup_npc(new_npc)

	if Globals.print_priority_1:
		debug_runtime_npc_trade_meta()
		print("npc_main.gd | setup_npc_from_data\nnew_npc: %s\ndata: %s" % [str(new_npc), str(data)])

func apply_scene_npc_event_meta(target_npc: NPC, data: Dictionary) -> void:
	if target_npc == null:
		if Globals.print_priority_1:
			print("npc_main.gd | target_npc == null")
		return

	var meta_source := data
	if typeof(data.get("shared_meta", {})) == TYPE_DICTIONARY:
		meta_source = data.get("shared_meta", {})

	target_npc.apply_shared_meta(meta_source, false)
	if str(target_npc.display_name).strip_edges() != "":
		target_npc.npc_name = str(target_npc.display_name).strip_edges()

	for key in [
		"has_event",
		"event_id",
		"event_ids",
		"active_event_id",
		"event_state",
		"event_step",
		"current_step",
		"required_step",
		"interaction_type",
		"helper_state",
		"event_accept_message",
		"event_start_items",
		"event_decline_message",
		"event_idle_message",
		"event_completed_message",
		"give_event",
		"requires_event",
		"dialogue_lines",
		"chat_line_delay",
		"chat_character_delay",
		"chat_type_delay"
	]:
		if data.has(key):
			target_npc.set_meta(key, data[key])
		elif meta_source.has(key):
			target_npc.set_meta(key, meta_source[key])

	if target_npc.has_meta("chat_line_delay"):
		target_npc.chat_line_delay = max(float(target_npc.get_meta("chat_line_delay", target_npc.chat_line_delay)), 0.1)
	if target_npc.has_meta("chat_character_delay"):
		target_npc.chat_character_delay = max(float(target_npc.get_meta("chat_character_delay", target_npc.chat_character_delay)), 0.005)
	elif target_npc.has_meta("chat_type_delay"):
		target_npc.chat_character_delay = max(float(target_npc.get_meta("chat_type_delay", target_npc.chat_character_delay)), 0.005)
		target_npc.set_meta("chat_character_delay", target_npc.chat_character_delay)


func variant_to_vector3i(value) -> Vector3i:
	if value is Vector3i:
		return value
	if value is Vector3:
		return Vector3i(int(value.x), int(value.y), int(value.z))
	if value is Array and value.size() >= 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	return Vector3i.ZERO


func variant_to_vector3(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector3i:
		return Vector3(value.x, value.y, value.z)
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO

func npc_inv_debug(label: String, data = "") -> void:
	if Globals.print_priority_2:
		print("[NPC_INV_DEBUG] ", label, " :: ", data)
		
		
func debug_print_npc_inventory_slots(label: String) -> void:
	if not Globals.print_priority_2:
		return

	if npc_inventory == null:
		print("[NPC_INV_DEBUG] ", label, " :: npc_inventory is null")
		return

	print("[NPC_INV_DEBUG] ===== ", label, " =====")

	var main_count := 0
	var drone_count := 0

	var main_cells = npc_inventory.cells.get("each_cell", {})
	for slot_name in main_cells:
		var slot: Dictionary = main_cells[slot_name]
		var item_id := str(slot.get("item_id", ""))
		var count := int(slot.get("count", 0))

		if item_id != "" and count > 0:
			main_count += 1
			print("[NPC_INV_DEBUG] MAIN SLOT ", slot_name, " -> ", item_id, " x", count)

	var drone_cells = npc_inventory.drone_cells.get("each_cell", {})
	for slot_name in drone_cells:
		var slot: Dictionary = drone_cells[slot_name]
		var item_id := str(slot.get("item_id", ""))
		var count := int(slot.get("count", 0))

		if item_id != "" and count > 0:
			drone_count += 1
			print("[NPC_INV_DEBUG] DRONE SLOT ", slot_name, " -> ", item_id, " x", count)

	print("[NPC_INV_DEBUG] filled main slots: ", main_count)
	print("[NPC_INV_DEBUG] filled drone slots: ", drone_count)




func build_npc_widget_state() -> void:
	ensure_npc_widget_state()

	# Route Inventory5 item-detail output to the NPC item detail box.
	if item_detail_box != null:
		widget_state.log_storage["log_text"] = item_detail_box
		widget_state.log_storage["npc_item_detail"] = item_detail_box

	if log_box != null:
		widget_state.log_storage["npc_contact_log"] = log_box



func get_npc_context() -> Dictionary:
	if Globals.current_npc == null:
		return {}

	if typeof(Globals.current_npc) != TYPE_DICTIONARY:
		return {}

	return Globals.current_npc


func read_dictionary_array(value) -> Array:
	# Summary: Return only dictionary entries from a loose authored array.
	var result: Array = []
	if typeof(value) != TYPE_ARRAY:
		return result

	for item in value:
		if typeof(item) == TYPE_DICTIONARY:
			result.append(item.duplicate(true))

	return result


func setup_player_state_from_data(data: Dictionary) -> void:
	# Summary: Build a local PlayerState clone from the main-mode NPC handoff packet.
	npc_player_state = PlayerState.new()
	npc_player_state_dirty = false

	var player_state_data = data.get("player_state_save_data", data.get("player_state", {}))
	if typeof(player_state_data) == TYPE_DICTIONARY and not player_state_data.is_empty():
		npc_player_state.load_save_data(player_state_data)

	if Globals.print_priority_1:
		print("[NPC_PLAYER_STATE setup] has_data=", typeof(player_state_data) == TYPE_DICTIONARY and not player_state_data.is_empty(), " data=", get_player_state_save_data())


func get_player_state_save_data() -> Dictionary:
	# player_state_save_data is the canonical NPC-scene copy because trade services
	# mutate this dictionary directly. Prefer it so exit save cannot pull an old
	# npc_player_state clone and overwrite the healed hull.
	if typeof(player_state_save_data) == TYPE_DICTIONARY and not player_state_save_data.is_empty():
		return player_state_save_data.duplicate(true)
	var live_data = npc_player_state.get_save_data()
	if typeof(live_data) == TYPE_DICTIONARY and not live_data.is_empty():
		return live_data.duplicate(true)
	var context := get_npc_context()
	var data = context.get("player_state_save_data", context.get("player_state", {}))
	if typeof(data) == TYPE_DICTIONARY:
		return data.duplicate(true)
		
	return {}
	
	

func save_npc_inventory_before_exit() -> void:
	if npc_inventory == null:
		print("[NPC_SAVE_DEBUG] blocked: npc_inventory missing")
		return

	if save_manager == null:
		print("[NPC_SAVE_DEBUG] blocked: save_manager missing")
		return

	var inv_data = npc_inventory.get_save_data()

	if save_manager.has_method("save_inventory_section_from_data"):
		var ok = save_manager.save_inventory_section_from_data(inv_data)
		print("[NPC_SAVE_DEBUG] inventory section save result: ", ok)
	else:
		print("[NPC_SAVE_DEBUG] SaveManager missing save_inventory_section_from_data")

func get_npc_inventory_pos() -> Vector2:
	return Vector2(NPC_LAYOUT_LEFT_X, NPC_LAYOUT_TOP)


func get_npc_item_detail_pos() -> Vector2:
	return get_npc_inventory_pos() + Vector2(0, NPC_INVENTORY_PANEL_SIZE.y + NPC_PANEL_GAP)


func get_npc_log_pos() -> Vector2:
	return Vector2(NPC_LAYOUT_MID_X, NPC_LAYOUT_TOP)


func get_npc_trade_pos() -> Vector2:
	return Vector2(NPC_LAYOUT_RIGHT_X, NPC_LAYOUT_TOP)


func get_npc_action_pos() -> Vector2:
	return get_npc_log_pos() + Vector2(0, NPC_LOG_PANEL_SIZE.y + NPC_PANEL_GAP)
	
	
func build_trade_widget() -> void:
	trade_root = Control.new()
	trade_root.name = "npc_trade_root"
	trade_root.position = get_npc_trade_pos()
	trade_root.size = NPC_TRADE_PANEL_SIZE
	add_child(trade_root)
	store_control("npc_trade_root", trade_root)

	var bg := ColorRect.new()
	bg.name = "npc_trade_bg"
	bg.color = Color(0.04, 0.05, 0.075, 0.95)
	bg.size = trade_root.size
	trade_root.add_child(bg)
	store_color_rect("npc_trade_bg", bg)

	var header := Label.new()
	header.name = "npc_trade_header"
	header.text = "TRADE OFFER"
	header.position = Vector2(10, 4)
	header.size = Vector2(trade_root.size.x - 20, 24)
	trade_root.add_child(header)
	store_label("npc_trade_header", header)

	trade_text_box = TextEdit.new()
	trade_text_box.name = "npc_trade_text_box"
	trade_text_box.position = Vector2(0, 30)
	trade_text_box.size = Vector2(trade_root.size.x, trade_root.size.y - 70)
	trade_text_box.editable = false
	trade_text_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	trade_text_box.text = "No trade offer selected."
	trade_root.add_child(trade_text_box)
	store_control("npc_trade_text_box", trade_text_box)
	store_log_ref("npc_trade_text", trade_text_box)

	trade_accept_button = Button.new()
	trade_accept_button.name = "npc_trade_accept_button"
	trade_accept_button.text = "ACCEPT"
	trade_accept_button.position = Vector2((trade_root.size.x - 120) * 0.5, trade_root.size.y - 35)
	trade_accept_button.size = Vector2(120, 28)
	trade_accept_button.disabled = true
	trade_accept_button.pressed.connect(_on_trade_accept_pressed)
	trade_root.add_child(trade_accept_button)
	store_button("npc_trade_accept_button", trade_accept_button)

	active_trade_offer.clear()
	active_trade_accepted = false
	refresh_trade_widget()
	set_trade_panel_visible(false)


func build_npc_decorative_overlays() -> void:
	if decorative_ui == null:
		return

	register_pulse_overlay_nodes(
		"npc_log_living_overlay",
		decorative_ui.create_pulse_overlay(
			get_npc_log_pos(),
			NPC_LOG_PANEL_SIZE,
			"npc_log_living_overlay",
			Color(0.0, 0.75, 1.0, 0.12)
		)
	)

	register_pulse_overlay_nodes(
		"npc_item_detail_living_overlay",
		decorative_ui.create_pulse_overlay(
			get_npc_item_detail_pos(),
			NPC_ITEM_DETAIL_PANEL_SIZE,
			"npc_item_detail_living_overlay",
			Color(0.4, 0.85, 0.9, 0.10)
		)
	)

	register_pulse_overlay_nodes(
		"npc_inventory_living_overlay",
		decorative_ui.create_pulse_overlay(
			get_npc_inventory_pos(),
			NPC_INVENTORY_PANEL_SIZE,
			"npc_inventory_living_overlay",
			Color(0.4, 0.85, 0.15, 0.10)
		)
	)

	register_pulse_overlay_nodes(
		"npc_action_living_overlay",
		decorative_ui.create_pulse_overlay(
			get_npc_action_pos(),
			NPC_ACTION_PANEL_SIZE,
			"npc_action_living_overlay",
			Color(0.0, 1.0, 0.45, 0.10)
		)
	)

	register_pulse_overlay_nodes(
		"npc_trade_living_overlay",
		decorative_ui.create_pulse_overlay(
			get_npc_trade_pos(),
			NPC_TRADE_PANEL_SIZE,
			"npc_trade_living_overlay",
			Color(1.0, 0.85, 0.15, 0.10)
		)
	)

	decorative_ui.set_pulse_overlays_visible(Globals.show_decorative_overlays)


func register_pulse_overlay_nodes(key: String, overlay: Control) -> void:
	if overlay == null:
		return

	store_control(key, overlay)


func setup_npc_widget_spec_runtime() -> void:
	if widget_state == null:
		return

	if color_handler == null:
		color_handler = Color_Handler.new()
		color_handler.name = "npc_color_handler"
		add_child(color_handler)
		color_handler.setup(widget_state)

	if widget_spec_ui == null:
		widget_spec_ui = WidgetSpecUi.new()
		widget_spec_ui.name = "npc_widget_spec_ui"
		add_child(widget_spec_ui)

	widget_spec_ui.setup(
		npc_inventory,
		null,
		null,
		widget_state,
		decorative_ui,
		aurora_bg,
		color_handler
	)
	widget_spec_ui.build_onscreen_widget_runtime_data()
	
	
func load_test_trade_offer() -> void:
	active_trade_offer = {
		"trade_id": "test_scanner_upgrade_trade",
		"display_name": "Scanner Upgrade Trade",

		"requirements": [
			{"item_id": "repair_kit", "count": 1}
		],

		"rewards": [
			{"item_id": "scan_module_mk1", "count": 1}
		],

		"success_text": "Trade complete. Inventory updated."
	}

	active_trade_accepted = false
	refresh_trade_widget()
	
	
func refresh_trade_widget() -> void:
	if trade_text_box == null or trade_accept_button == null:
		return

	if active_trade_offer.is_empty():
		trade_text_box.text = "No trade offer available."
		trade_accept_button.disabled = true
		trade_accept_button.visible = false
		set_trade_panel_visible(false)
		configure_trade_action_button()
		return

	if active_trade_accepted:
		trade_text_box.text = str(active_trade_offer.get("success_text", "Trade complete."))
		trade_accept_button.disabled = true
		trade_accept_button.visible = false
		set_trade_panel_visible(true)
		configure_trade_action_button()
		return

	var validation := validate_trade_offer(active_trade_offer)

	var text := ""
	text += str(active_trade_offer.get("display_name", "Trade Offer")) + "\n\n"

	var offer_text := str(active_trade_offer.get("offer_text", ""))
	if offer_text != "":
		text += offer_text + "\n\n"

	text += "Requirements:\n"

	var requirements: Array = active_trade_offer.get("requirements", [])

	if requirements.is_empty():
		text += "- None\n"
	else:
		for req in requirements:
			var item_id := str(req.get("item_id", ""))
			var needed := int(req.get("count", 1))
			var owned := get_inventory_item_count(item_id)

			text += "- " + get_trade_item_line(req)
			text += " [" + str(owned) + "/" + str(needed) + "]"

			if owned >= needed:
				text += " PASS"
			else:
				text += " FAIL"

			text += "\n"

	text += "\nReward / Service:\n"

	var rewards: Array = active_trade_offer.get("rewards", [])
	var player_state_effects: Array = active_trade_offer.get("player_state_effects", [])

	if rewards.is_empty() and player_state_effects.is_empty():
		text += "- None\n"
	else:
		for reward in rewards:
			text += "- " + get_trade_item_line(reward) + "\n"
		for effect in player_state_effects:
			if typeof(effect) == TYPE_DICTIONARY:
				text += "- " + get_player_state_effect_line(effect) + "\n"

	text += "\nResult:\n"
	if validation.get("can_accept", false):
		text += "Ready. Accept to complete this service."
	else:
		text += str(validation.get("reason", "Requirements missing."))

	trade_text_box.text = text
	trade_accept_button.visible = true
	trade_accept_button.disabled = not validation.get("can_accept", false)
	configure_trade_action_button()


func set_trade_panel_visible(is_visible: bool) -> void:
	if trade_root == null:
		return
	trade_root.visible = is_visible
	
func get_trade_item_line(item: Dictionary) -> String:
	var item_id := str(item.get("item_id", ""))
	var count := int(item.get("count", 1))

	var item_name := item_id

	if npc_item_handler != null:
		item_name = npc_item_handler.get_item_name(item_id)

	return item_name + " x" + str(count)
	
	
func get_inventory_item_count(item_id: String) -> int:
	if npc_inventory == null:
		return 0

	if npc_inventory.has_method("count_item_anywhere"):
		return int(npc_inventory.count_item_anywhere(item_id))

	return 0


func read_player_state_effect_op(effect: Dictionary) -> String:
	# Summary: Support service-style and PlayerState-style authoring aliases.
	var op := str(effect.get("op", "")).strip_edges()
	if op == "":
		op = str(effect.get("service_type", "")).strip_edges()
	if op == "":
		op = str(effect.get("player_state_op", "")).strip_edges()
	if op == "":
		op = str(effect.get("effect_id", "")).strip_edges()
	if op == "":
		op = str(effect.get("effect_type", "")).strip_edges()
	if op == "repair_hull_full":
		op = "repair_hull_to_full"
	return op


func read_player_state_effect_bonus(effect: Dictionary) -> float:
	return float(effect.get("bonus_hull_max_add", effect.get("bonus_hull_max", effect.get("extra_hull_bonus", effect.get("max_hull_bonus", 0.0)))))


func get_player_state_effect_line(effect: Dictionary) -> String:
	var op := read_player_state_effect_op(effect)
	if op == "repair_hull_full" or op == "repair_hull_to_full":
		var bonus := read_player_state_effect_bonus(effect)
		if bonus > 0.0:
			return "Repair hull to full +" + str(bonus) + " max hull bonus"
		return "Repair hull to full"
	if op == "repair_hull":
		return "Repair hull +" + str(effect.get("amount", effect.get("repair_amount", 0)))
	return "Player-state effect: " + op


func is_trade_offer_repeatable(offer: Dictionary) -> bool:
	return bool(offer.get("repeatable", offer.get("retradable", false)))


func validate_player_state_effects(effects: Array) -> Dictionary:
	if effects.is_empty():
		return {"can_accept": true, "reason": "Ready."}

	if typeof(player_state_save_data) != TYPE_DICTIONARY or player_state_save_data.is_empty():
		return {"can_accept": false, "reason": "PlayerState save data missing from NPC handoff."}

	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue

		var op := read_player_state_effect_op(effect)

		if op == "repair_hull_to_full":
			var hull_current := float(player_state_save_data.get("hull_current", player_state_save_data.get("player_hull_current", 0.0)))
			var hull_max := float(player_state_save_data.get("hull_max", player_state_save_data.get("player_hull_max", 0.0)))

			if hull_max <= 0.0:
				return {"can_accept": false, "reason": "Player hull max invalid."}

			var bonus := read_player_state_effect_bonus(effect)
			var bonus_flag := str(effect.get("bonus_flag", effect.get("bonus_id", effect.get("repair_bonus_id", ""))))
			var flags := get_player_state_flags()
			var bonus_available := bonus > 0.0 and bonus_flag != "" and not bool(flags.get(bonus_flag, false))

			if hull_current >= hull_max and not bonus_available:
				return {"can_accept": false, "reason": "Hull already full."}

		else:
			return {"can_accept": false, "reason": "Unknown PlayerState service: " + op}

	return {"can_accept": true, "reason": "Ready."}


func apply_player_state_trade_effects(effects: Array) -> bool:
	if effects.is_empty():
		return true

	if typeof(player_state_save_data) != TYPE_DICTIONARY or player_state_save_data.is_empty():
		print("[NPC_PLAYER_STATE_TRADE] blocked: player_state_save_data missing")
		return false

	var applied_messages: Array = []
	var changed := false

	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue

		var op := read_player_state_effect_op(effect)

		if op == "repair_hull_to_full":
			var result := apply_repair_hull_to_full_trade_effect(effect)

			if typeof(result) != TYPE_DICTIONARY or not bool(result.get("ok", false)):
				print("[NPC_PLAYER_STATE_TRADE] repair failed: ", result)
				return false

			changed = true
			applied_messages.append(str(result.get("message", "Hull repaired to full.")))

		else:
			print("[NPC_PLAYER_STATE_TRADE] unknown effect op: ", op)
			return false

	if changed:
		if Globals.current_npc != null and typeof(Globals.current_npc) == TYPE_DICTIONARY:
			Globals.current_npc["player_state_save_data"] = player_state_save_data.duplicate(true)

		npc_player_state_dirty = true

		merge_npc_chat_result({
			"player_state_changed": true,
			"player_state_action": "npc_trade_service",
			"player_state_source": "npc_mechanic_station",
			"player_state_save_data": player_state_save_data.duplicate(true),
			"player_state_messages": applied_messages
		})

	return true
	
	
func validate_trade_offer(offer: Dictionary) -> Dictionary:
	if npc_inventory == null:
		return {
			"can_accept": false,
			"reason": "Inventory missing."
		}

	var rewards: Array = offer.get("rewards", [])
	var player_state_effects: Array = offer.get("player_state_effects", [])
	if rewards.is_empty() and player_state_effects.is_empty():
		return {
			"can_accept": false,
			"reason": "No reward or service configured."
		}

	var effect_validation := validate_player_state_effects(player_state_effects)
	if not bool(effect_validation.get("can_accept", false)):
		return effect_validation

	var requirements: Array = offer.get("requirements", [])

	# Reward/service-only offer is valid.
	if requirements.is_empty():
		return {
			"can_accept": true,
			"reason": "Ready."
		}

	for req in requirements:
		var item_id := str(req.get("item_id", ""))
		var needed := int(req.get("count", 1))
		var owned := get_inventory_item_count(item_id)

		if owned < needed:
			return {
				"can_accept": false,
				"reason": "Missing " + get_trade_item_line(req)
			}

	return {
		"can_accept": true,
		"reason": "Ready."
	}
	

func _on_trade_accept_pressed() -> void:
	if active_trade_accepted:
		if Globals.print_priority_1:
			print("[NPC_TRADE_DEBUG] trade already accepted, ignoring.")
		return

	if active_trade_offer.is_empty():
		return
	

	var validation := validate_trade_offer(active_trade_offer)

	if not validation.get("can_accept", false):
		refresh_trade_widget()
		return

	var ok := apply_trade_offer(active_trade_offer)

	if ok:
		if is_trade_offer_repeatable(active_trade_offer):
			active_trade_accepted = false
			mark_current_npc_repeatable_trade_used()
		else:
			active_trade_accepted = true

			if trade_accept_button != null:
				trade_accept_button.disabled = true
				trade_accept_button.visible = false

			mark_current_npc_trade_completed()

		refresh_inventory_after_trade()
		refresh_trade_widget()
		
		

func apply_trade_offer(offer: Dictionary) -> bool:
	var t = true
	var f = false
	if npc_inventory == null:
		print("[NPC_TRADE_DEBUG] apply blocked: npc_inventory missing")
		return false

	# Final validation before changing anything.
	var validation := validate_trade_offer(offer)
	if not validation.get("can_accept", false):
		print("[NPC_TRADE_DEBUG] apply blocked: validation failed: ", validation.get("reason", "unknown"))
		return false

	# -----------------------------------------
	# Remove requirements from inventory.
	# -----------------------------------------
	for req in offer.get("requirements", []):
		var item_id := str(req.get("item_id", ""))
		var count := int(req.get("count", 1))

		if item_id == "" or count <= 0:
			print("[NPC_TRADE_DEBUG] bad requirement data: ", req)
			return false

		if not npc_inventory.has_method("consume_item"):
			print("[NPC_TRADE_DEBUG] npc_inventory missing consume_item")
			return false

		var consume_result = npc_inventory.consume_item(item_id, count)

		# Supports either bool or result-packet style return.
		if typeof(consume_result) == TYPE_BOOL:
			if consume_result == false:
				print("[NPC_TRADE_DEBUG] consume_item failed: ", item_id, " x", count)
				return false

		elif typeof(consume_result) == TYPE_DICTIONARY:
			if consume_result.get("status", "") == "failed" or consume_result.get("success", true) == false:
				print("[NPC_TRADE_DEBUG] consume_item failed packet: ", consume_result)
				return false

	# -----------------------------------------
	# Add rewards to inventory.
	# -----------------------------------------
	for reward in offer.get("rewards", []):
		var item_id := str(reward.get("item_id", ""))
		var count := int(reward.get("count", 1))

		if item_id == "" or count <= 0:
			print("[NPC_TRADE_DEBUG] bad reward data: ", reward)
			return false

		if not npc_inventory.has_method("add_item"):
			print("[NPC_TRADE_DEBUG] npc_inventory missing add_item")
			return false

		var add_result = npc_inventory.add_item(item_id, count)

		# Supports either bool or result-packet style return.
		if typeof(add_result) == TYPE_BOOL:
			if add_result == false:
				print("[NPC_TRADE_DEBUG] add_item failed: ", item_id, " x", count)
				return false

		elif typeof(add_result) == TYPE_DICTIONARY:
			if add_result.get("status", "") == "failed" or add_result.get("success", true) == false:
				print("[NPC_TRADE_DEBUG] add_item failed packet: ", add_result)
				return false

	# -----------------------------------------
	# Apply PlayerState rewards/services.
	# -----------------------------------------
	var player_state_effects: Array = offer.get("player_state_effects", [])
	if not apply_player_state_trade_effects(player_state_effects):
		return false

	print("[NPC_TRADE_DEBUG] trade applied successfully")
	
	return true
			
func refresh_inventory_after_trade():
	if npc_inventory == null:
		return

	if npc_inventory.has_method("refresh_label_inventory_rows"):
		npc_inventory.refresh_label_inventory_rows()

	return true
	
	
func debug_npc_trade_meta(data: Dictionary) -> void:
	print("===================================")
	print("[NPC_TRADE_META_DEBUG]")
	print("keys: ", data.keys())
	print("name: ", data.get("name", "NO_NAME"))
	print("can_trade: ", data.get("can_trade", "NO_CAN_TRADE"))
	print("trade: ", data.get("trade", "NO_TRADE"))
	print("has item_list: ", data.has("item_list"))

	if data.has("item_list"):
		print("item_list: ", data["item_list"])

	print("has dialogue_lines: ", data.has("dialogue_lines"))

	if data.has("dialogue_lines"):
		print("dialogue_lines count: ", data["dialogue_lines"].size())

	print("===================================")


func build_trade_offer_from_item_list(context: Dictionary) -> Dictionary:
	var item_list: Array = context.get("item_list", [])

	if item_list.is_empty():
		return {}

	var requirements: Array = []
	var rewards: Array = []
	var player_state_effects: Array = read_dictionary_array(context.get("player_state_effects", []))

	for entry in item_list:
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var trade_role := str(entry.get("trade_role", "")).strip_edges().to_lower()
		var effect_type := read_player_state_effect_op(entry)

		if trade_role in ["player_state_effect", "player_state_reward", "ship_service", "service"] or effect_type != "":
			var effect = entry.duplicate(true)
			if not effect.has("op") and effect_type != "":
				effect["op"] = effect_type
			player_state_effects.append(effect)
			continue

		var item_id := str(entry.get("item_id", ""))
		var amount := int(entry.get("amount", entry.get("count", 1)))

		if item_id == "" or amount <= 0:
			continue

		if trade_role == "want" or trade_role == "requirement" or trade_role == "cost":
			requirements.append({
				"item_id": item_id,
				"count": amount
			})

		elif trade_role == "sell" or trade_role == "reward" or trade_role == "give":
			rewards.append({
				"item_id": item_id,
				"count": amount
			})

	if requirements.is_empty() and rewards.is_empty() and player_state_effects.is_empty():
		return {}

	var fallback_title := str(context.get("name", "NPC")) + " Offer"
	var fallback_success := "Offer accepted. Inventory updated."

	return {
		"trade_id": str(context.get("blueprint_id", context.get("npc_id", context.get("name", "npc_trade")))) + "_trade",
		"display_name": str(context.get("offer_title", fallback_title)),
		"offer_text": str(context.get("offer_text", "")),
		"requirements": requirements,
		"rewards": rewards,
		"player_state_effects": player_state_effects,
		"repeatable": bool(context.get("repeatable", context.get("retradable", false))),
		"retradable": bool(context.get("retradable", context.get("repeatable", false))),
		"success_text": str(context.get("success_text", fallback_success))
	}
	
func configure_trade_widget_from_npc() -> void:
	if trade_text_box == null or trade_accept_button == null:
		return

	var context := get_npc_context()

	# -----------------------------------------
	# Trade-completed state blocks one-time offers only.
	# Repeatable/retradable station services stay open.
	# -----------------------------------------
	var repeatable_context := bool(context.get("repeatable", context.get("retradable", false)))
	if npc != null:
		repeatable_context = bool(npc.get_meta("repeatable", npc.get_meta("retradable", repeatable_context)))

	var trade_completed := bool(context.get("trade_completed", false))

	if npc != null and npc.has_meta("trade_completed"):
		trade_completed = bool(npc.get_meta("trade_completed", false))

	if trade_completed and not repeatable_context:
		active_trade_offer.clear()
		active_trade_accepted = true
		trade_text_box.text = "Offer already accepted."
		trade_accept_button.disabled = true
		trade_accept_button.visible = false
		set_trade_panel_visible(false)
		configure_trade_action_button()
		return

	# -----------------------------------------
	# can_trade is the real permission gate.
	# item_list alone does NOT allow trading.
	# -----------------------------------------
	var can_trade_now := false

	if npc != null:
		can_trade_now = npc.can_trade

	if not context.is_empty():
		can_trade_now = bool(context.get("can_trade", context.get("trade", can_trade_now)))

	if not can_trade_now:
		active_trade_offer.clear()
		active_trade_accepted = false
		trade_text_box.text = "No trade offer available."
		trade_accept_button.disabled = true
		trade_accept_button.visible = false
		set_trade_panel_visible(false)
		configure_trade_action_button()
		return

	# -----------------------------------------
	# item_list only describes the offer.
	# It does not grant permission to trade.
	# -----------------------------------------
	var item_list: Array = []

	if npc != null and npc.has_meta("item_list"):
		var meta_items = npc.get_meta("item_list")
		if meta_items is Array:
			item_list = meta_items

	if item_list.is_empty() and not context.is_empty():
		item_list = context.get("item_list", [])

	if item_list.is_empty():
		active_trade_offer.clear()
		active_trade_accepted = false
		trade_text_box.text = "No trade offer configured."
		trade_accept_button.disabled = true
		trade_accept_button.visible = false
		set_trade_panel_visible(false)
		configure_trade_action_button()
		return

	# -----------------------------------------
	# Build the offer only after trade permission passes.
	# -----------------------------------------
	var offer_context := context.duplicate(true)
	offer_context["item_list"] = item_list
	offer_context["player_state_effects"] = read_dictionary_array(context.get("player_state_effects", []))
	offer_context["repeatable"] = repeatable_context
	offer_context["retradable"] = repeatable_context

	if npc != null:
		offer_context["name"] = npc.npc_name
		offer_context["npc_id"] = npc.get_meta("npc_id", "")
		offer_context["blueprint_id"] = npc.get_meta("blueprint_id", "")
		offer_context["offer_title"] = npc.get_meta("offer_title", offer_context.get("offer_title", ""))
		offer_context["offer_text"] = npc.get_meta("offer_text", offer_context.get("offer_text", ""))
		offer_context["success_text"] = npc.get_meta("success_text", offer_context.get("success_text", ""))
		offer_context["repeatable"] = bool(npc.get_meta("repeatable", offer_context.get("repeatable", false)))
		offer_context["retradable"] = bool(npc.get_meta("retradable", offer_context.get("retradable", offer_context.get("repeatable", false))))
		if npc.has_meta("player_state_effects"):
			offer_context["player_state_effects"] = read_dictionary_array(npc.get_meta("player_state_effects", []))
		if offer_context.get("player_state_effects", []).is_empty():
			offer_context["player_state_effects"] = read_dictionary_array(npc.get_meta("player_state_effects", []))

	var offer := build_trade_offer_from_item_list(offer_context)

	if offer.is_empty():
		active_trade_offer.clear()
		active_trade_accepted = false
		trade_text_box.text = "No trade offer configured."
		trade_accept_button.disabled = true
		trade_accept_button.visible = false
		set_trade_panel_visible(false)
		configure_trade_action_button()
		return

	active_trade_offer = offer
	active_trade_accepted = false
	set_trade_panel_visible(false)
	refresh_trade_widget()
	
	
func debug_runtime_npc_trade_meta() -> void:
	if npc == null:
		print("NPC TRADE DEBUG npc is null")
		return

	print("NPC TRADE DEBUG name: ", npc.npc_name)
	print("NPC TRADE DEBUG can_trade: ", npc.can_trade)
	print("NPC TRADE DEBUG has item_list meta: ", npc.has_meta("item_list"))
	print("NPC TRADE DEBUG item_list meta: ", npc.get_meta("item_list", []))
	print("NPC TRADE DEBUG has blueprint_id meta: ", npc.has_meta("blueprint_id"))
	print("NPC TRADE DEBUG blueprint_id: ", npc.get_meta("blueprint_id", ""))

func mark_current_npc_repeatable_trade_used() -> void:
	var context := get_npc_context()
	var npc_id := ""
	var blueprint_id := ""

	if not context.is_empty():
		npc_id = str(context.get("npc_id", ""))
		blueprint_id = str(context.get("blueprint_id", ""))

	if npc != null:
		npc.can_trade = true
		npc.set_meta("can_trade", true)
		npc.set_meta("trade_completed", false)
		npc.set_meta("repeatable", true)
		npc.set_meta("retradable", true)

		if npc_id == "":
			npc_id = str(npc.get_meta("npc_id", ""))
		if blueprint_id == "":
			blueprint_id = str(npc.get_meta("blueprint_id", ""))

	if Globals.current_npc != null and typeof(Globals.current_npc) == TYPE_DICTIONARY:
		Globals.current_npc["can_trade"] = true
		Globals.current_npc["trade"] = true
		Globals.current_npc["trade_completed"] = false
		Globals.current_npc["repeatable"] = true
		Globals.current_npc["retradable"] = true

	merge_npc_chat_result({
		"npc_id": npc_id,
		"blueprint_id": blueprint_id,
		"can_trade": true,
		"trade_completed": false,
		"repeatable": true,
		"retradable": true
	})

	print("[NPC_TRADE_DEBUG] repeatable trade used: ", Globals.npc_chat_result)


func mark_current_npc_trade_completed() -> void:
	var context := get_npc_context()

	var npc_id := ""
	var blueprint_id := ""

	if not context.is_empty():
		npc_id = str(context.get("npc_id", ""))
		blueprint_id = str(context.get("blueprint_id", ""))

	if npc != null:
		npc.can_trade = false
		npc.set_meta("can_trade", false)
		npc.set_meta("trade_completed", true)

		if npc_id == "":
			npc_id = str(npc.get_meta("npc_id", ""))

		if blueprint_id == "":
			blueprint_id = str(npc.get_meta("blueprint_id", ""))

	if Globals.current_npc != null and typeof(Globals.current_npc) == TYPE_DICTIONARY:
		Globals.current_npc["can_trade"] = false
		Globals.current_npc["trade"] = false
		Globals.current_npc["trade_completed"] = true

	# This is applied by main_mode after returning if the direct scene save did not already commit it.
	merge_npc_chat_result({
		"npc_id": npc_id,
		"blueprint_id": blueprint_id,
		"can_trade": false,
		"trade_completed": true
	})

	print("[NPC_TRADE_DEBUG] marked trade completed: ", Globals.npc_chat_result)


func mark_current_npc_met(meet_result: Dictionary) -> void:
	var context := get_npc_context()
	var npc_id := ""
	var blueprint_id := ""

	if not context.is_empty():
		npc_id = str(context.get("npc_id", ""))
		blueprint_id = str(context.get("blueprint_id", ""))

	if npc != null:
		if npc_id == "":
			npc_id = str(npc.get_meta("npc_id", ""))
		if blueprint_id == "":
			blueprint_id = str(npc.get_meta("blueprint_id", ""))

	merge_npc_chat_result({
		"npc_id": npc_id,
		"blueprint_id": blueprint_id,
		"has_met": true,
		"depopulate_after_meeting": bool(meet_result.get("depopulate_after_meeting", false))
	})


func merge_npc_chat_result(update: Dictionary) -> void:
	var current := {}
	if typeof(Globals.npc_chat_result) == TYPE_DICTIONARY:
		current = Globals.npc_chat_result.duplicate(true)

	for key in update.keys():
		current[key] = update[key]

	Globals.npc_chat_result = current


func save_npc_player_state_before_exit() -> void:
	if not npc_player_state_dirty and not Globals.npc_chat_result.has("player_state_save_data"):
		return

	var player_state_data := get_player_state_save_data()
	if player_state_data.is_empty():
		return

	var context := get_npc_context()
	var npc_id := str(context.get("npc_id", ""))
	var blueprint_id := str(context.get("blueprint_id", ""))
	if npc != null:
		if npc_id == "":
			npc_id = str(npc.get_meta("npc_id", ""))
		if blueprint_id == "":
			blueprint_id = str(npc.get_meta("blueprint_id", ""))

	merge_npc_chat_result({
		"npc_id": npc_id,
		"blueprint_id": blueprint_id,
		"player_state_save_data": player_state_data
	})

	if save_manager == null:
		print("[NPC_PLAYER_STATE_SAVE] blocked: save_manager missing")
		return

	if not save_manager.has_method("save_player_state_section_from_data"):
		print("[NPC_PLAYER_STATE_SAVE] SaveManager missing save_player_state_section_from_data")
		return

	var player_state_data_to_save: Dictionary = {}

	if Globals.npc_chat_result != null and typeof(Globals.npc_chat_result) == TYPE_DICTIONARY:
		var result_player_state = Globals.npc_chat_result.get("player_state_save_data", {})
		if typeof(result_player_state) == TYPE_DICTIONARY and not result_player_state.is_empty():
			player_state_data_to_save = result_player_state.duplicate(true)

	if player_state_data_to_save.is_empty() and typeof(player_state_save_data) == TYPE_DICTIONARY and not player_state_save_data.is_empty():
		player_state_data_to_save = player_state_save_data.duplicate(true)

	if player_state_data_to_save.is_empty():
		print("[NPC_PLAYER_STATE_SAVE] blocked: no PlayerState data to save")
	else:
		var ok := bool(save_manager.save_player_state_section_from_data(player_state_data_to_save))
		print("[NPC_PLAYER_STATE_SAVE] section save result=", ok, " hull=", player_state_data_to_save.get("hull_current"), "/", player_state_data_to_save.get("hull_max"))
		if Globals.print_priority_2:
			print("[NPC_PLAYER_STATE_SAVE] player_state section save result: ", ok)


func save_npc_trade_state_before_exit() -> void:
	if save_manager == null:
		print("[NPC_SAVE_DEBUG] blocked: save_manager missing")
		return

	if Globals.npc_chat_result.is_empty():
		print("[NPC_SAVE_DEBUG] no npc_chat_result to save")
		return

	if not save_manager.has_method("save_npc_trade_state_from_result"):
		print("[NPC_SAVE_DEBUG] SaveManager missing save_npc_trade_state_from_result")
		return

	var ok = save_manager.save_npc_trade_state_from_result(Globals.npc_chat_result)
	if Globals.print_priority_2:
		print("[NPC_SAVE_DEBUG] npc trade state save result: ", ok)
	if Globals.print_priority_1:
		print("npc_main.gd | Global npc data check below \n" +str(Globals.current_npc))

	if ok and not bool(Globals.npc_chat_result.get("event_start_requested", false)) and not Globals.npc_chat_result.has("player_state_save_data"):
		Globals.npc_chat_result.clear()
func get_player_state_flags() -> Dictionary:
	var flags = player_state_save_data.get("player_state_flags", player_state_save_data.get("flags", {}))
	if typeof(flags) != TYPE_DICTIONARY:
		flags = {}
	return flags.duplicate(true)


func set_player_state_flags(flags: Dictionary) -> void:
	player_state_save_data["player_state_flags"] = flags.duplicate(true)
	player_state_save_data["flags"] = flags.duplicate(true)
	
	
func apply_repair_hull_to_full_trade_effect(effect: Dictionary) -> Dictionary:
	var hull_current := float(player_state_save_data.get("hull_current", player_state_save_data.get("player_hull_current", 0.0)))
	var hull_max := float(player_state_save_data.get("hull_max", player_state_save_data.get("player_hull_max", 0.0)))

	if hull_max <= 0.0:
		return {"ok": false, "reason": "player_hull_max_invalid"}

	var bonus := read_player_state_effect_bonus(effect)
	var bonus_flag := str(effect.get("bonus_flag", effect.get("bonus_id", effect.get("repair_bonus_id", ""))))
	var bonus_apply_once := bool(effect.get("bonus_apply_once", true))

	var flags := get_player_state_flags()
	var bonus_applied := false

	if bonus > 0.0:
		var already_applied := bonus_flag != "" and bool(flags.get(bonus_flag, false))

		if not bonus_apply_once or not already_applied:
			hull_max += bonus
			bonus_applied = true

			if bonus_flag != "":
				flags[bonus_flag] = true
				set_player_state_flags(flags)

	hull_current = hull_max

	player_state_save_data["hull_current"] = hull_current
	player_state_save_data["hull_max"] = hull_max
	player_state_save_data["player_hull_current"] = hull_current
	player_state_save_data["player_hull_max"] = hull_max
	player_state_save_data["is_alive"] = true
	player_state_save_data["is_destroyed"] = false
	sync_npc_player_state_clone_from_save_data()

	return {
		"ok": true,
		"message": "Hull repaired to full.",
		"hull_current": hull_current,
		"hull_max": hull_max,
		"bonus_applied": bonus_applied
	}
func sync_npc_player_state_clone_from_save_data() -> void:
	if npc_player_state == null:
		return
	if not npc_player_state.has_method("load_save_data"):
		return
	if typeof(player_state_save_data) != TYPE_DICTIONARY or player_state_save_data.is_empty():
		return
		
	npc_player_state.load_save_data(player_state_save_data.duplicate(true))
