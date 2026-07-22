extends Node


const SaveManagerScript = preload("res://save/SaveManager.gd")
const StartMenuLoadScreenHandlerScript = preload("res://UI/Loading/MainModeLoadScreenHandler.gd")
const ControllerFocusOverlayScript = preload("res://UI/Controller/ControllerFocusOverlay.gd")
const ControllerSceneListFocusScript = preload("res://UI/Controller/ControllerSceneListFocus.gd")
const START_BACK_TEXTURE = preload("res://images/blue_scifi_backing.png")

var save_manager = SaveManagerScript.new()
var start_menu_load_screen_handler = null
var start_widget_state: WidgetsState5 = null
var start_widget_builder: WidgetsBuilder5 = null
var decorative_ui: DecorativeUI = null
var start_background_root: Control = null
var aurora_bg: AuroraBrainBackground = null
var universe_select: OptionButton = null
var universe_info_label: Label = null
var universe_lane_ids := []
var selected_universe_lane: Dictionary = {}
var named_save_select: OptionButton = null
var load_named_save_button: Button = null
var load_autosave_button: Button = null
var exit_game_button: Button = null
var start_status_label: Label = null
var named_save_slot_ids := []
var start_menu_boot_started := false
var start_menu_boot_complete := false
var start_menu_last_loading_stage := ""
var controller_focus_overlay: ControllerFocusOverlay = null
var controller_scene_focus: ControllerSceneListFocus = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start_menu_boot_started = true
	start_menu_boot_complete = false
	setup_start_menu_load_screen_handler()
	await get_tree().process_frame
	await boot_start_menu_with_loading_screen()


func setup_start_menu_load_screen_handler() -> void:
	if start_menu_load_screen_handler == null:
		start_menu_load_screen_handler = get_tree().root.get_node_or_null("StartMenuLoadScreenHandler")
	if start_menu_load_screen_handler == null or not is_instance_valid(start_menu_load_screen_handler):
		start_menu_load_screen_handler = StartMenuLoadScreenHandlerScript.new()

	start_menu_load_screen_handler.name = "StartMenuLoadScreenHandler"
	if start_menu_load_screen_handler.has_method("configure_visual_theme"):
		start_menu_load_screen_handler.configure_visual_theme({
			"background_color": Color(0.0, 0.012, 0.035, 1.0),
			"title_color": Color(0.72, 0.94, 1.0, 1.0),
			"detail_color": Color(0.58, 0.86, 1.0, 0.88),
			"percent_color": Color(0.46, 0.95, 1.0, 0.95),
			"progress_bg_color": Color(0.015, 0.045, 0.070, 0.95),
			"progress_fill_color": Color(0.26, 0.90, 1.0, 0.96)
		})

	if start_menu_load_screen_handler.get_parent() == null:
		add_child(start_menu_load_screen_handler)

	start_menu_load_screen_handler.begin("FOREVER SPACE", "Opening universe command access...")


func boot_start_menu_with_loading_screen() -> void:
	await start_menu_loading_stage(12, "Opening universe command access...")

	setup_start_background()

	await start_menu_loading_stage(38, "Lighting start screen background...")

	setup_start_decorative_handlers()

	await start_menu_loading_stage(62, "Building universe command menu...")

	setup_start_screen_ui()

	await start_menu_loading_stage(92, "Reading save lanes and snapshots...")
	refresh_universe_start_options()
	refresh_named_save_start_options()
	setup_controller_focus_handler()

	await start_menu_loading_stage(100, "Start menu ready.")

	start_menu_boot_complete = true
	start_menu_boot_started = false
	finish_start_menu_load_screen()


func finish_start_menu_load_screen() -> void:
	if start_menu_load_screen_handler == null or not is_instance_valid(start_menu_load_screen_handler):
		return

	start_menu_load_screen_handler.force_hide()
	if start_menu_load_screen_handler.get_parent() == get_tree().root:
		get_tree().root.remove_child(start_menu_load_screen_handler)
		start_menu_load_screen_handler.queue_free()
		start_menu_load_screen_handler = null


func start_menu_loading_stage(percent: int, detail_text: String) -> void:
	start_menu_last_loading_stage = detail_text
	if should_print_start_loading_debug():
		print("[START_MENU_LOAD] ", percent, "% | ", detail_text)

	if start_menu_load_screen_handler != null and is_instance_valid(start_menu_load_screen_handler):
		start_menu_load_screen_handler.set_stage(percent, detail_text)

	await get_tree().process_frame


func should_print_start_loading_debug() -> bool:
	var loading_debug = Globals.get("print_priority_loading_debug")
	if typeof(loading_debug) == TYPE_BOOL:
		return loading_debug
	return false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if decorative_ui != null:
		decorative_ui.update_decorative_ui(delta)


func _input(event: InputEvent) -> void:
	if controller_scene_focus != null and is_instance_valid(controller_scene_focus):
		if controller_scene_focus.handle_input(event):
			get_viewport().set_input_as_handled()


func _on_new_game_pressed() -> void:
	commit_selected_universe_lane()
	Globals.startup_mode = "new"
	get_tree().change_scene_to_file("res://Scenes/main_mode.tscn")


func _on_load_game_pressed() -> void:
	commit_selected_universe_lane()
	Globals.startup_mode = "load"
	get_tree().change_scene_to_file("res://Scenes/main_mode.tscn")


func _on_exit_game_pressed() -> void:
	if Globals.print_priority_2:
		print("[EXIT_GAME] Start menu exit requested. Closing runtime.")
	get_tree().quit()


func setup_start_screen_ui() -> void:
	hide_scene_stub_buttons()

	start_widget_state = WidgetsState5.new()
	start_widget_state.name = "StartWidgetState"
	add_child(start_widget_state)

	start_widget_builder = WidgetsBuilder5.new()
	start_widget_builder.name = "StartWidgetBuilder"
	add_child(start_widget_builder)

	var widget_root := start_widget_builder.build_start_menu_widget(
		start_widget_state,
		Vector2(340, 150),
		Vector2(620, 540)
	)
	if widget_root != null:
		add_child(widget_root)

	wire_start_widget_controls()


func setup_start_background() -> void:
	if start_background_root != null and is_instance_valid(start_background_root):
		return

	start_background_root = Control.new()
	start_background_root.name = "start_background_root"
	start_background_root.position = Vector2.ZERO
	start_background_root.size = Vector2(Globals.screen_w, Globals.screen_h)
	start_background_root.z_index = -50
	start_background_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(start_background_root)
	move_child(start_background_root, 0)

	var blue_back := TextureRect.new()
	blue_back.name = "start_blue_scifi_background"
	blue_back.texture = START_BACK_TEXTURE
	blue_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	blue_back.offset_left = 0.0
	blue_back.offset_top = 0.0
	blue_back.offset_right = 0.0
	blue_back.offset_bottom = 0.0
	blue_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blue_back.stretch_mode = TextureRect.STRETCH_SCALE
	blue_back.z_index = -50
	blue_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_background_root.add_child(blue_back)

	var dimmer := ColorRect.new()
	dimmer.name = "start_background_dimmer"
	dimmer.color = Color(0.0, 0.012, 0.035, 0.34)
	dimmer.position = Vector2.ZERO
	dimmer.size = start_background_root.size
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.z_index = -45
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_background_root.add_child(dimmer)

	var aurora_container := Control.new()
	aurora_container.name = "start_aurora_container"
	aurora_container.position = Globals.aurora_pos
	aurora_container.size = Globals.aurora_size
	aurora_container.z_index = -40
	aurora_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_background_root.add_child(aurora_container)

	aurora_bg = AuroraBrainBackground.new()
	aurora_bg.name = "start_aurora_background"
	aurora_bg.node_count = 54
	aurora_bg.connection_distance = 165.0
	aurora_bg.node_radius = 2.4
	aurora_bg.size = aurora_container.size
	aurora_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	aurora_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aurora_container.add_child(aurora_bg)


func setup_start_decorative_handlers() -> void:
	if decorative_ui != null and is_instance_valid(decorative_ui):
		return

	decorative_ui = DecorativeUI.new()
	decorative_ui.name = "StartDecorativeUI"
	add_child(decorative_ui)


func hide_scene_stub_buttons() -> void:
	for button_name in ["new_game", "load_game"]:
		var button := get_node_or_null(button_name) as Button
		if button == null:
			continue
		button.visible = false
		button.disabled = true


func wire_start_widget_controls() -> void:
	if start_widget_state == null:
		return

	var new_game_button := start_widget_state.buttons.get("start_new_game", null) as Button
	if new_game_button != null and not new_game_button.pressed.is_connected(_on_new_game_pressed):
		new_game_button.pressed.connect(_on_new_game_pressed)

	load_autosave_button = start_widget_state.buttons.get("start_load_autosave", null) as Button
	commit_selected_universe_lane()
	if load_autosave_button != null:
		load_autosave_button.disabled = not save_manager.has_save()
		if not load_autosave_button.pressed.is_connected(_on_load_game_pressed):
			load_autosave_button.pressed.connect(_on_load_game_pressed)

	universe_select = start_widget_state.controls.get("start_universe_select", null) as OptionButton
	if universe_select != null and not universe_select.item_selected.is_connected(_on_start_universe_selected):
		universe_select.item_selected.connect(_on_start_universe_selected)

	universe_info_label = start_widget_state.labels.get("start_universe_info_label", null) as Label

	named_save_select = start_widget_state.controls.get("start_named_save_select", null) as OptionButton

	load_named_save_button = start_widget_state.buttons.get("start_load_named_save", null) as Button
	if load_named_save_button != null and not load_named_save_button.pressed.is_connected(_on_load_named_save_pressed):
		load_named_save_button.pressed.connect(_on_load_named_save_pressed)

	exit_game_button = start_widget_state.buttons.get("start_exit_game", null) as Button
	if exit_game_button != null and not exit_game_button.pressed.is_connected(_on_exit_game_pressed):
		exit_game_button.pressed.connect(_on_exit_game_pressed)

	start_status_label = start_widget_state.labels.get("start_status_label", null) as Label


func refresh_universe_start_options() -> void:
	if universe_select == null:
		return

	universe_select.clear()
	universe_lane_ids.clear()
	selected_universe_lane.clear()

	var lanes: Array = []
	if Globals.has_method("get_available_universe_lanes"):
		lanes = Globals.get_available_universe_lanes()

	if lanes.is_empty():
		lanes = [
			{
				"universe_id": "demo_alpha",
				"display_name": "Forever Space Demo Alpha",
				"description": "Main story demo lane.",
				"events_dir": "res://data/universes/demo_alpha/events",
				"world_seeds_dir": "res://data/universes/demo_alpha/world_seeds",
				"save_lane": "demo_alpha"
			}
		]

	var selected_index := 0
	var active_id := str(Globals.active_universe_id).strip_edges()

	for lane in lanes:
		if typeof(lane) != TYPE_DICTIONARY:
			continue

		var universe_id := str(lane.get("universe_id", "")).strip_edges()
		if universe_id == "":
			continue

		var display_name := str(lane.get("display_name", universe_id)).strip_edges()
		if display_name == "":
			display_name = universe_id

		universe_lane_ids.append(universe_id)
		var item_index := universe_lane_ids.size() - 1
		universe_select.add_item(display_name, item_index)
		universe_select.set_item_metadata(item_index, lane.duplicate(true))

		if universe_id == active_id:
			selected_index = item_index

	universe_select.disabled = universe_lane_ids.is_empty()
	if not universe_lane_ids.is_empty():
		universe_select.select(selected_index)
		selected_universe_lane = get_universe_lane_from_select_index(selected_index)
		commit_selected_universe_lane()
		update_selected_universe_info_label()
	else:
		update_selected_universe_info_label()


func get_universe_lane_from_select_index(index: int) -> Dictionary:
	if universe_select == null:
		return {}
	if index < 0 or index >= universe_select.get_item_count():
		return {}

	var metadata = universe_select.get_item_metadata(index)
	if typeof(metadata) == TYPE_DICTIONARY:
		return metadata.duplicate(true)

	if index >= 0 and index < universe_lane_ids.size() and Globals.has_method("get_universe_lane_by_id"):
		return Globals.get_universe_lane_by_id(str(universe_lane_ids[index]))

	return {}


func _on_start_universe_selected(index: int) -> void:
	selected_universe_lane = get_universe_lane_from_select_index(index)
	commit_selected_universe_lane()
	update_selected_universe_info_label()
	refresh_named_save_start_options()


func commit_selected_universe_lane() -> Dictionary:
	if selected_universe_lane.is_empty() and universe_select != null:
		selected_universe_lane = get_universe_lane_from_select_index(universe_select.selected)

	if selected_universe_lane.is_empty():
		if Globals.has_method("get_default_universe_lane"):
			selected_universe_lane = Globals.get_default_universe_lane()

	if Globals.has_method("set_active_universe_lane"):
		return Globals.set_active_universe_lane(selected_universe_lane)

	return selected_universe_lane


func update_selected_universe_info_label() -> void:
	if universe_info_label == null:
		return

	var lane := selected_universe_lane
	if lane.is_empty():
		universe_info_label.text = "No universe lane found. Default demo lane will be used."
		return

	var display_name := str(lane.get("display_name", lane.get("universe_id", "Universe"))).strip_edges()
	var description := str(lane.get("description", "")).strip_edges()
	var events_dir := str(lane.get("events_dir", "")).strip_edges()
	var world_seeds_dir := str(lane.get("world_seeds_dir", "")).strip_edges()
	var save_lane := str(lane.get("save_lane", lane.get("universe_id", ""))).strip_edges()

	var text := display_name
	if description != "":
		text += " — " + description
	text += "\nEvents: " + events_dir
	text += "\nWorld seeds: " + world_seeds_dir
	text += "\nSave lane: " + save_lane
	universe_info_label.text = text


func refresh_named_save_start_options() -> void:
	if named_save_select == null:
		return

	named_save_select.clear()
	named_save_slot_ids.clear()

	if load_autosave_button != null:
		load_autosave_button.disabled = not save_manager.has_save()

	var slots = save_manager.list_named_save_slots()
	if slots.is_empty():
		named_save_select.add_item("No named saves found")
		named_save_select.disabled = true
		if load_named_save_button != null:
			load_named_save_button.disabled = true
		if start_status_label != null:
			start_status_label.text = "Selected lane: " + str(Globals.active_universe_display_name) + ". Named saves will list here after SaveManager lane wiring is active."
		return

	for slot in slots:
		if typeof(slot) != TYPE_DICTIONARY:
			continue

		var slot_id := str(slot.get("slot_id", "")).strip_edges()
		if slot_id == "":
			continue

		named_save_slot_ids.append(slot_id)
		named_save_select.add_item(build_start_named_save_label(slot), named_save_slot_ids.size() - 1)

	named_save_select.disabled = named_save_slot_ids.is_empty()
	if load_named_save_button != null:
		load_named_save_button.disabled = named_save_slot_ids.is_empty()
	if start_status_label != null:
		start_status_label.text = "Selected lane: " + str(Globals.active_universe_display_name) + ". Choose Load Autosave or pick a named save."


func build_start_named_save_label(slot: Dictionary) -> String:
	var display_name := str(slot.get("display_name", "Save")).strip_edges()
	if display_name == "":
		display_name = "Save"

	var created := str(slot.get("created_at_text", "")).strip_edges()
	if created != "":
		return display_name + "  " + created

	return display_name


func _on_load_named_save_pressed() -> void:
	if named_save_select == null or named_save_slot_ids.is_empty():
		set_start_status("No named save selected.")
		return

	var selected_index := named_save_select.selected
	if selected_index < 0 or selected_index >= named_save_slot_ids.size():
		set_start_status("No named save selected.")
		return

	commit_selected_universe_lane()
	var slot_id := str(named_save_slot_ids[selected_index])
	var result: Dictionary = save_manager.promote_named_save_to_autosave(slot_id)
	if not bool(result.get("ok", false)):
		set_start_status("Named save load failed: " + str(result.get("reason", "unknown reason")))
		return

	Globals.startup_mode = "load"
	get_tree().change_scene_to_file("res://Scenes/main_mode.tscn")


func set_start_status(message: String) -> void:
	if start_status_label != null:
		start_status_label.text = message


func setup_controller_focus_handler() -> void:
	if controller_focus_overlay == null or not is_instance_valid(controller_focus_overlay):
		controller_focus_overlay = ControllerFocusOverlayScript.new()
	controller_focus_overlay.name = "StartControllerFocusOverlay"
	controller_focus_overlay.z_index = ControllerFocusOverlay.TOP_LAYER_Z
	controller_focus_overlay.z_as_relative = false
	controller_focus_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if controller_focus_overlay.get_parent() == null:
		add_child(controller_focus_overlay)

	if controller_scene_focus == null or not is_instance_valid(controller_scene_focus):
		controller_scene_focus = ControllerSceneListFocusScript.new()
	controller_scene_focus.name = "StartControllerSceneFocus"
	if controller_scene_focus.get_parent() == null:
		add_child(controller_scene_focus)

	var focus_root = start_widget_state.controls.get("start_menu_widget_root", null) if start_widget_state != null else null
	controller_scene_focus.setup({
		"owner_scene": self,
		"overlay": controller_focus_overlay,
		"focus_root": focus_root,
		"focus_items_provider": Callable(self, "get_start_controller_focus_items")
	})
	move_child(controller_focus_overlay, get_child_count() - 1)


func get_start_controller_focus_items() -> Array:
	var items: Array = []
	append_start_controller_focus_item(items, "start_universe_select", universe_select, "option", Callable(), Callable(self, "adjust_controller_universe_select"))
	append_start_controller_focus_item(items, "start_new_game", start_widget_state.buttons.get("start_new_game", null) if start_widget_state != null else null)
	append_start_controller_focus_item(items, "start_load_autosave", load_autosave_button)
	append_start_controller_focus_item(items, "start_named_save_select", named_save_select, "option", Callable(), Callable(self, "adjust_controller_named_save_select"))
	append_start_controller_focus_item(items, "start_load_named_save", load_named_save_button)
	append_start_controller_focus_item(items, "start_exit_game", exit_game_button)
	return items


func append_start_controller_focus_item(
	items: Array,
	item_id: String,
	node_value: Variant,
	kind: String = "button",
	activate_callable: Callable = Callable(),
	adjust_callable: Callable = Callable()
) -> void:
	if node_value == null or not is_instance_valid(node_value):
		return
	var item := {
		"item_id": item_id,
		"node": node_value,
		"kind": kind,
		"enabled": true
	}
	if activate_callable.is_valid():
		item["activate_callable"] = activate_callable
	if adjust_callable.is_valid():
		item["adjust_callable"] = adjust_callable
	items.append(item)


func adjust_controller_universe_select(delta: int) -> void:
	if universe_select == null or universe_select.disabled:
		return
	var next_index := adjust_start_option_button(universe_select, delta)
	if next_index >= 0:
		_on_start_universe_selected(next_index)


func adjust_controller_named_save_select(delta: int) -> void:
	if named_save_select == null or named_save_select.disabled:
		return
	adjust_start_option_button(named_save_select, delta)


func adjust_start_option_button(option_button: OptionButton, delta: int) -> int:
	if option_button == null:
		return -1
	var count := option_button.get_item_count()
	if count <= 0:
		return -1
	var next_index := int(posmod(option_button.selected + delta, count))
	option_button.select(next_index)
	return next_index
