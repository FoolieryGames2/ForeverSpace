extends Control
class_name EventStoryBuilder

const EventStoryStorageScript = preload("res://Scripts/dev/EventStoryStorage.gd")
const EventStoryCatalogScript = preload("res://Scripts/dev/EventStoryCatalog.gd")

const EVENT_TOOL_VERSION := "v2.3"
const SCREEN_SIZE := Vector2(1300, 800)
const TOOLBAR_HEIGHT := 62.0
const LEFT_PANEL := Rect2(Vector2(12, 76), Vector2(245, 690))
const STEP_PANEL := Rect2(Vector2(270, 76), Vector2(405, 690))
const INSPECTOR_PANEL := Rect2(Vector2(688, 76), Vector2(600, 370))
const PREVIEW_PANEL := Rect2(Vector2(688, 460), Vector2(600, 306))
const MAIN_VIEW_ICON_DIR := "res://UI/PortView/main_view/icons"
const AWARENESS_CONDITION_KEY := "awareness_conditions"
const UNIVERSE_ROOT_DIR := "res://data/universes"

var storage: EventStoryStorage
var catalog: EventStoryCatalog
var event_packet: Dictionary = {}
var selected_kind := "header"
var selected_id := ""
var refreshing := false
var section_open_state: Dictionary = {}
var inspector_parent_stack: Array = []

var event_id_edit: LineEdit
var display_name_edit: LineEdit
var universe_options: OptionButton
var load_options: OptionButton
var status_label: Label
var left_vbox: VBoxContainer
var step_vbox: VBoxContainer
var object_vbox: VBoxContainer
var inspector_vbox: VBoxContainer
var preview_text: TextEdit


func _ready() -> void:
	name = "EventStoryBuilder"
	size = SCREEN_SIZE
	custom_minimum_size = SCREEN_SIZE
	storage = EventStoryStorageScript.new()
	add_child(storage)
	catalog = EventStoryCatalogScript.new()
	add_child(catalog)
	catalog.refresh()
	event_packet = make_default_event_packet()
	build_shell()
	refresh_universe_options()
	refresh_load_options()
	refresh_all(get_tool_ready_status())


func build_shell() -> void:
	var bg := ColorRect.new()
	bg.name = "EventStoryBuilderBackground"
	bg.color = Color(0.017, 0.023, 0.038, 1.0)
	bg.size = SCREEN_SIZE
	add_child(bg)

	build_toolbar()
	build_left_panel()
	build_step_panel()
	build_inspector_panel()
	build_preview_panel()


func build_toolbar() -> void:
	var toolbar := add_panel("Toolbar", Rect2(Vector2.ZERO, Vector2(SCREEN_SIZE.x, TOOLBAR_HEIGHT)), Color(0.025, 0.036, 0.057, 0.98))
	toolbar.mouse_filter = Control.MOUSE_FILTER_STOP

	make_label("Title", "Event Engine Dev Tool " + EVENT_TOOL_VERSION, Vector2(16, 9), Vector2(190, 22), 17, Color(0.70, 0.92, 1.0, 1.0))

	make_label("EventIdTopLabel", "Event ID", Vector2(205, 12), Vector2(60, 18), 12)
	event_id_edit = LineEdit.new()
	event_id_edit.position = Vector2(265, 8)
	event_id_edit.size = Vector2(220, 28)
	event_id_edit.text_changed.connect(_on_event_id_changed)
	add_child(event_id_edit)

	make_label("DisplayNameTopLabel", "Name", Vector2(498, 12), Vector2(42, 18), 12)
	display_name_edit = LineEdit.new()
	display_name_edit.position = Vector2(542, 8)
	display_name_edit.size = Vector2(240, 28)
	display_name_edit.text_changed.connect(_on_display_name_changed)
	add_child(display_name_edit)

	add_button("New", Vector2(796, 8), Vector2(58, 28), _on_new_pressed)
	add_button("Validate", Vector2(862, 8), Vector2(82, 28), _on_validate_pressed)
	add_button("Save", Vector2(952, 8), Vector2(64, 28), _on_save_pressed)

	load_options = OptionButton.new()
	load_options.position = Vector2(1028, 8)
	load_options.size = Vector2(190, 28)
	add_child(load_options)
	add_button("Load", Vector2(1225, 8), Vector2(58, 28), _on_load_pressed)

	make_label("UniverseTopLabel", "Universe", Vector2(16, 40), Vector2(64, 18), 12)
	universe_options = OptionButton.new()
	universe_options.position = Vector2(84, 36)
	universe_options.size = Vector2(260, 24)
	universe_options.item_selected.connect(_on_universe_selected)
	add_child(universe_options)

	status_label = make_label("Status", "Ready.", Vector2(360, 40), Vector2(920, 18), 12, Color(0.75, 0.88, 1.0, 0.85))


func build_left_panel() -> void:
	add_panel("LeftPanel", LEFT_PANEL, Color(0.032, 0.044, 0.070, 0.96))
	make_label("LeftTitle", "Builder Parts", LEFT_PANEL.position + Vector2(12, 10), Vector2(180, 20), 15)

	var scroll := ScrollContainer.new()
	scroll.position = LEFT_PANEL.position + Vector2(10, 38)
	scroll.size = LEFT_PANEL.size - Vector2(20, 50)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(left_vbox)
	build_left_buttons()


func build_step_panel() -> void:
	add_panel("StepPanel", STEP_PANEL, Color(0.028, 0.039, 0.064, 0.94))
	make_label("StepTitle", "Story Chain", STEP_PANEL.position + Vector2(12, 10), Vector2(180, 20), 15)
	make_label("ObjectTitle", "Event Objects", STEP_PANEL.position + Vector2(12, 365), Vector2(180, 20), 15)

	var step_scroll := ScrollContainer.new()
	step_scroll.position = STEP_PANEL.position + Vector2(10, 38)
	step_scroll.size = Vector2(STEP_PANEL.size.x - 20, 315)
	step_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(step_scroll)
	step_vbox = VBoxContainer.new()
	step_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_scroll.add_child(step_vbox)

	var object_scroll := ScrollContainer.new()
	object_scroll.position = STEP_PANEL.position + Vector2(10, 392)
	object_scroll.size = Vector2(STEP_PANEL.size.x - 20, 286)
	object_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(object_scroll)
	object_vbox = VBoxContainer.new()
	object_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	object_scroll.add_child(object_vbox)


func build_inspector_panel() -> void:
	add_panel("InspectorPanel", INSPECTOR_PANEL, Color(0.035, 0.047, 0.074, 0.96))
	make_label("InspectorTitle", "Inspector", INSPECTOR_PANEL.position + Vector2(12, 10), Vector2(180, 20), 15)

	var scroll := ScrollContainer.new()
	scroll.position = INSPECTOR_PANEL.position + Vector2(10, 38)
	scroll.size = INSPECTOR_PANEL.size - Vector2(20, 50)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	inspector_vbox = VBoxContainer.new()
	inspector_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inspector_vbox)


func build_preview_panel() -> void:
	add_panel("PreviewPanel", PREVIEW_PANEL, Color(0.020, 0.030, 0.050, 0.96))
	make_label("PreviewTitle", "Generated JSON Preview", PREVIEW_PANEL.position + Vector2(12, 10), Vector2(220, 20), 15)

	preview_text = TextEdit.new()
	preview_text.position = PREVIEW_PANEL.position + Vector2(10, 38)
	preview_text.size = PREVIEW_PANEL.size - Vector2(20, 50)
	preview_text.editable = false
	preview_text.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	preview_text.add_theme_font_size_override("font_size", 10)
	add_child(preview_text)


func add_panel(panel_name: String, rect: Rect2, color: Color) -> ColorRect:
	var panel := ColorRect.new()
	panel.name = panel_name
	panel.position = rect.position
	panel.size = rect.size
	panel.color = color
	add_child(panel)
	return panel


func make_label(label_name: String, text: String, pos: Vector2, label_size: Vector2, font_size: int = 12, color: Color = Color(0.82, 0.90, 1.0, 0.95)) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func add_button(button_text: String, pos: Vector2, button_size: Vector2, target_callable: Callable) -> Button:
	var button := Button.new()
	button.text = button_text
	button.position = pos
	button.size = button_size
	button.pressed.connect(target_callable)
	add_child(button)
	return button


func get_section_open(section_key: String, default_open: bool) -> bool:
	if not section_open_state.has(section_key):
		section_open_state[section_key] = default_open
	return bool(section_open_state.get(section_key, default_open))


func make_section_title(title: String, is_open: bool) -> String:
	return ("v " if is_open else "> ") + title


func add_collapsible_section(parent: VBoxContainer, section_key: String, title: String, default_open: bool) -> VBoxContainer:
	var is_open := get_section_open(section_key, default_open)
	var header := Button.new()
	header.text = make_section_title(title, is_open)
	header.custom_minimum_size = Vector2(210, 28)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(header)

	var body := VBoxContainer.new()
	body.visible = is_open
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(body)

	header.pressed.connect(_on_collapsible_section_pressed.bind(section_key, title, header, body))
	return body


func _on_collapsible_section_pressed(section_key: String, title: String, header: Button, body: VBoxContainer) -> void:
	var is_open := not body.visible
	section_open_state[section_key] = is_open
	body.visible = is_open
	header.text = make_section_title(title, is_open)


func get_inspector_parent() -> VBoxContainer:
	if inspector_parent_stack.is_empty():
		return inspector_vbox
	return inspector_parent_stack[inspector_parent_stack.size() - 1]


func push_inspector_parent(parent: VBoxContainer) -> void:
	inspector_parent_stack.append(parent)


func pop_inspector_parent() -> void:
	if not inspector_parent_stack.is_empty():
		inspector_parent_stack.pop_back()


func add_inspector_section(section_key: String, title: String, default_open: bool) -> VBoxContainer:
	return add_collapsible_section(inspector_vbox, "inspector_" + section_key, title, default_open)


func build_left_buttons() -> void:
	clear_container(left_vbox)
	var docs_section := add_collapsible_section(left_vbox, "sidebar_v23_docs", "V2.3 ENGINE", true)
	add_sidebar_button("Engine Reference", "docs", "engine", docs_section)
	add_sidebar_button("Orbit Handoffs", "docs", "orbit", docs_section)
	add_sidebar_button("JSON Authoring Map", "docs", "json", docs_section)

	var event_section := add_collapsible_section(left_vbox, "sidebar_event", "EVENT", true)
	add_sidebar_button("Header", "header", "", event_section)
	add_sidebar_button("Giver", "giver", "", event_section)
	add_sidebar_button("Rewards", "rewards", "", event_section)

	var step_section := add_collapsible_section(left_vbox, "sidebar_add_step", "ADD STEP", true)
	add_template_button("Talk / NPC Contact", "talk", step_section)
	add_template_button("Story Popup", "story_popup", step_section)
	add_template_button("Tutorial Hint", "tutorial_popup", step_section)
	add_template_button("Travel / Find Target", "find", step_section)
	add_template_button("Inspect / Action Button", "action", step_section)
	add_template_button("Battle / Hunt Enemy", "hunt", step_section)
	add_template_button("Download / Item Pickup", "download", step_section)
	add_template_button("Handoff", "handoff", step_section)
	add_template_button("Turn-In", "turn_in", step_section)
	add_template_button("Reward / Complete", "complete", step_section)

	var npc_section := add_collapsible_section(left_vbox, "sidebar_npc_tools", "NPC TOOLS", false)
	add_template_button("NPC Refresh Step", "npc_refresh", npc_section)
	add_template_button("Remove NPC Step", "remove_npc", npc_section)
	add_template_button("Replace NPC Step", "replace_npc", npc_section)

	var object_section := add_collapsible_section(left_vbox, "sidebar_add_object", "ADD OBJECT", true)
	add_object_template_button("Enemy", "enemy", object_section)
	add_object_template_button("Beacon", "beacon", object_section)
	add_object_template_button("NPC", "npc", object_section)
	add_object_template_button("Planet", "planet", object_section)
	add_object_template_button("Asteroid", "asteroid", object_section)
	add_object_template_button("Space Object", "space_object", object_section)
	add_object_template_button("Star", "star", object_section)
	add_object_template_button("Event Listener", "event_listener", object_section)

	var tools_section := add_collapsible_section(left_vbox, "sidebar_tools", "TOOLS", false)
	add_utility_button("Refresh Catalogs", _on_refresh_catalogs_pressed, tools_section)
	add_utility_button("Validate", _on_validate_pressed, tools_section)
	add_utility_button("Save JSON", _on_save_pressed, tools_section)


func add_sidebar_button(label: String, kind: String, id_value: String, parent: VBoxContainer = null) -> void:
	var target_parent := parent if parent != null else left_vbox
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(210, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_select_pressed.bind(kind, id_value))
	target_parent.add_child(button)


func add_template_button(label: String, template_id: String, parent: VBoxContainer = null) -> void:
	var target_parent := parent if parent != null else left_vbox
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(210, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_add_step_template_pressed.bind(template_id))
	target_parent.add_child(button)


func add_object_template_button(label: String, object_type: String, parent: VBoxContainer = null) -> void:
	var target_parent := parent if parent != null else left_vbox
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(210, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_on_add_object_template_pressed.bind(object_type))
	target_parent.add_child(button)


func add_utility_button(label: String, target_callable: Callable, parent: VBoxContainer = null) -> void:
	var target_parent := parent if parent != null else left_vbox
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(210, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(target_callable)
	target_parent.add_child(button)


func add_sidebar_spacer() -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 8)
	left_vbox.add_child(spacer)


func refresh_all(message: String = "") -> void:
	refreshing = true
	event_id_edit.text = str(event_packet.get("event_id", ""))
	display_name_edit.text = str(event_packet.get("display_name", ""))
	rebuild_story_lists()
	rebuild_inspector()
	refresh_preview()
	refreshing = false
	if message != "":
		status_label.text = message


func rebuild_story_lists() -> void:
	clear_container(step_vbox)
	clear_container(object_vbox)

	var steps: Dictionary = event_packet.get("steps", {})
	for entry in get_story_chain_entries():
		var step_id := str(entry.get("step_id", ""))
		var label := str(entry.get("label", step_id))
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(365, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = bool(entry.get("missing", false))
		if selected_kind == "step" and selected_id == step_id:
			button.modulate = Color(0.42, 0.82, 1.0, 1.0)
		elif str(entry.get("state", "")) == "unlinked":
			button.modulate = Color(1.0, 0.78, 0.42, 1.0)
		elif bool(entry.get("cycle", false)) or bool(entry.get("missing", false)):
			button.modulate = Color(1.0, 0.42, 0.42, 1.0)
		if not button.disabled:
			button.pressed.connect(_on_select_pressed.bind("step", step_id))
		step_vbox.add_child(button)

	var objects: Dictionary = event_packet.get("event_objects", {})
	for object_id in objects.keys():
		var object_data: Dictionary = objects[object_id]
		var object_type := str(object_data.get("object_type", object_data.get("owner_type", "object")))
		var button := Button.new()
		button.text = str(object_id) + "  [" + object_type + "]"
		button.custom_minimum_size = Vector2(365, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if selected_kind == "object" and selected_id == str(object_id):
			button.modulate = Color(0.42, 0.82, 1.0, 1.0)
		button.pressed.connect(_on_select_pressed.bind("object", str(object_id)))
		object_vbox.add_child(button)

	var listeners: Dictionary = event_packet.get("event_listeners", {})
	for listener_id in listeners.keys():
		var listener_data: Dictionary = listeners[listener_id]
		var listener_type := str(listener_data.get("listener_type", "seed_event_on_range"))
		var button := Button.new()
		button.text = str(listener_id) + "  [" + listener_type + "]"
		button.custom_minimum_size = Vector2(365, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if selected_kind == "listener" and selected_id == str(listener_id):
			button.modulate = Color(0.42, 0.82, 1.0, 1.0)
		button.pressed.connect(_on_select_pressed.bind("listener", str(listener_id)))
		object_vbox.add_child(button)


func rebuild_inspector() -> void:
	clear_container(inspector_vbox)
	inspector_parent_stack.clear()
	match selected_kind:
		"header":
			build_header_inspector()
		"giver":
			build_giver_inspector()
		"rewards":
			build_rewards_inspector()
		"step":
			build_step_inspector(selected_id)
		"object":
			build_object_inspector(selected_id)
		"listener":
			build_listener_inspector(selected_id)
		"docs":
			build_docs_inspector(selected_id)
		_:
			build_header_inspector()


func build_header_inspector() -> void:
	add_inspector_title("Event Header")
	add_line_field("Event ID", str(event_packet.get("event_id", "")), _on_event_id_changed)
	add_line_field("Display Name", str(event_packet.get("display_name", "")), _on_display_name_changed)
	add_check_field("Start On Ready", bool(event_packet.get("start_on_ready", false)), _on_bool_packet_changed.bind("start_on_ready"))
	add_check_field("Seed Once", bool(event_packet.get("seed_once", true)), _on_bool_packet_changed.bind("seed_once"))
	add_check_field("Requires Giver", bool(event_packet.get("requires_giver", false)), _on_bool_packet_changed.bind("requires_giver"))
	add_spin_field("Tier", float(event_packet.get("tier", 1)), 1.0, 99.0, 1.0, _on_number_packet_changed.bind("tier"))
	add_option_field("Current Step", get_step_ids(), str(event_packet.get("current_step", "")), _on_current_step_selected)
	add_inspector_subtitle("Anchor Star")
	var anchor: Dictionary = ensure_dict(event_packet, "anchor_star")
	add_catalog_option_field("Star ID", get_world_anchor_catalog_options(), get_anchor_star_selection(anchor), _on_anchor_catalog_selected)
	add_line_field("Star Name", str(anchor.get("star_name", "")), _on_nested_text_changed.bind(["anchor_star", "star_name"]))
	add_vector3_field("Anchor Sector", anchor.get("sector_pos", [0, 0, 0]), _on_anchor_sector_changed)
	add_vector3_field("Anchor Local", anchor.get("local_pos", [500, 500, 500]), _on_anchor_local_changed)
	build_event_awareness_conditions_inspector()


func build_giver_inspector() -> void:
	add_inspector_title("Event Giver")
	var giver: Dictionary = ensure_dict(event_packet, "giver")
	add_commit_line_field("Stable Giver ID", str(giver.get("template_owner_id", giver.get("owner_id", ""))), _on_giver_owner_id_changed)
	add_catalog_option_field("Blueprint ID", get_npc_catalog_options(), get_catalog_blueprint_selection(giver, get_stable_giver_id()), _on_giver_npc_blueprint_selected)
	add_line_field("Display Name", str(giver.get("display_name", "")), _on_nested_text_changed.bind(["giver", "display_name"]))
	add_inspector_button("Sync Real Giver Identity", _on_sync_giver_identity_pressed)
	add_check_field("Place Near Anchor", bool(giver.get("place_near_anchor_star", true)), _on_nested_bool_changed.bind(["giver", "place_near_anchor_star"]))
	add_vector3_field("Local Offset", giver.get("local_offset", [20, 0, 0]), _on_giver_offset_changed)
	add_inspector_note("Listener-driven chains may leave giver empty. Use one stable giver id only when an NPC directly offers or owns the event.")


func build_rewards_inspector() -> void:
	add_inspector_title("Rewards")
	var reward: Dictionary = ensure_dict(event_packet, "reward_packet")
	add_spin_field("Credits", float(reward.get("credits", 0)), 0.0, 999999.0, 1.0, _on_reward_credits_changed)
	add_catalog_option_field("Reward Item ID", get_item_catalog_options(), "", _on_reward_catalog_item_selected)
	var text := reward_items_to_text(reward.get("items", []))
	add_text_field("Items, one per line: item_id:amount", text, Vector2(550, 120), _on_reward_items_changed)
	add_line_field("Complete Message", str(reward.get("message", "Event complete.")), _on_nested_text_changed.bind(["reward_packet", "message"]))


func build_docs_inspector(doc_id: String) -> void:
	var clean_doc_id := doc_id.strip_edges()
	if clean_doc_id == "":
		clean_doc_id = "engine"
	add_inspector_title(get_docs_title(clean_doc_id))
	add_inspector_note(get_docs_summary(clean_doc_id))
	var docs_section := add_inspector_section("docs_" + clean_doc_id, "REFERENCE", true)
	push_inspector_parent(docs_section)
	add_readonly_text_field(get_docs_text(clean_doc_id), Vector2(550, 250))
	pop_inspector_parent()


func build_step_inspector(step_id: String) -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	if not steps.has(step_id):
		add_inspector_title("Missing Step")
		return

	var step: Dictionary = steps[step_id]
	add_inspector_title("Step: " + step_id)
	add_inspector_button("Duplicate Step", _on_duplicate_step_pressed.bind(step_id))
	add_inspector_button("Delete Step", _on_delete_step_pressed.bind(step_id))

	var basic_section := add_inspector_section("step_basic", "BASIC", true)
	push_inspector_parent(basic_section)
	add_text_field("Objective", str(step.get("objective_text", "")), Vector2(550, 80), _on_step_text_changed.bind(step_id, "objective_text"))
	add_option_field("Next Step", get_next_step_options(), str(step.get("next_step", "")), _on_step_next_selected.bind(step_id))
	add_option_field("Interaction", ["", "talk", "npc_contact", "story_popup", "tutorial_popup", "find", "travel", "arrive", "inspect", "hunt", "battle", "download", "handoff", "turn_in", "claim", "complete"], str(step.get("interaction_type", "")), _on_step_interaction_selected.bind(step_id))
	pop_inspector_parent()

	if should_show_step_npc_dialogue(step):
		var npc_dialogue_section := add_inspector_section("step_npc_dialogue", "NPC DIALOGUE", false)
		push_inspector_parent(npc_dialogue_section)
		add_text_field("NPC Talk Lines (one per line)", dialogue_lines_to_text(step.get("npc_dialogue_lines", [])), Vector2(550, 90), _on_step_dialogue_lines_changed.bind(step_id))
		add_text_field("Completed NPC Talk Lines", dialogue_lines_to_text(step.get("completed_npc_dialogue_lines", [])), Vector2(550, 80), _on_step_completed_dialogue_lines_changed.bind(step_id))
		add_line_field("Dialogue Target Owner", str(step.get("npc_dialogue_target_owner_id", "")), _on_step_text_changed.bind(step_id, "npc_dialogue_target_owner_id"))
		add_spin_field("NPC Chat Line Delay", float(step.get("npc_chat_line_delay", step.get("chat_line_delay", 1.65))), 0.1, 10.0, 0.05, _on_step_chat_delay_changed.bind(step_id))
		add_spin_field("NPC Chat Type Delay", float(step.get("npc_chat_character_delay", step.get("chat_character_delay", 0.04))), 0.005, 0.5, 0.005, _on_step_chat_character_delay_changed.bind(step_id))
		add_check_field("NPC Trade Button", bool(step.get("npc_can_trade", step.get("can_trade", false))), _on_step_bool_changed.bind(step_id, "npc_can_trade"))
		add_check_field("NPC Quest Button", bool(step.get("npc_quest_available", step.get("has_event", false))), _on_step_bool_changed.bind(step_id, "npc_quest_available"))
		pop_inspector_parent()

	var target_section := add_inspector_section("step_target_gate", "TARGET / GATE", true)
	push_inspector_parent(target_section)
	add_spin_field("Range", get_step_range_value(step, 70.0), 0.0, 5000.0, 5.0, _on_step_range_changed.bind(step_id))
	add_option_field("Target Object", [""] + get_object_ids(), str(step.get("target_object_id", "")), _on_step_target_object_selected.bind(step_id))
	add_line_field("Target Owner", str(step.get("target_owner_id", "")), _on_step_text_changed.bind(step_id, "target_owner_id"))
	add_catalog_option_field("Requires Item", get_item_catalog_options(), str(step.get("requires_item", "")), _on_step_requires_item_catalog_selected.bind(step_id))
	add_catalog_option_field("Gives Item", get_item_catalog_options(), str(step.get("gives_item", "")), _on_step_gives_item_catalog_selected.bind(step_id))
	pop_inspector_parent()

	build_step_awareness_conditions_inspector(step_id, step)

	if is_hunt_or_battle_step(step):
		var battle_section := add_inspector_section("step_battle", "BATTLE / HUNT", true)
		push_inspector_parent(battle_section)
		add_option_field("Enemy", [""] + get_enemy_object_ids(), str(step.get("enemy_id", "")), _on_step_enemy_selected.bind(step_id))
		add_check_field("Complete On Battle Victory", bool(step.get("complete_on_battle_victory", false)), _on_step_bool_changed.bind(step_id, "complete_on_battle_victory"))
		add_line_field("Battle Entry Message", get_start_battle_message(step), _on_step_entry_message_changed.bind(step_id))
		add_line_field("Victory Message", get_victory_message(step), _on_step_victory_message_changed.bind(step_id))
		add_inspector_button("Sync Hunt IDs", _on_sync_hunt_ids_pressed.bind(step_id))
		pop_inspector_parent()

	if should_show_step_npc_tools(step):
		var npc_tools_section := add_inspector_section("step_npc_tools", "NPC RUNTIME TOOLS", step_has_npc_operation(step))
		push_inspector_parent(npc_tools_section)
		add_inspector_note("Show this when the step targets an NPC, changes story context near an NPC, or already contains NPC lifecycle/dialogue ops.")
		add_inspector_button("Add NPC Refresh Op", _on_step_add_npc_refresh_pressed.bind(step_id))
		add_inspector_button("Add Remove NPC Op", _on_step_add_remove_npc_pressed.bind(step_id))
		add_inspector_button("Add Replace NPC Op", _on_step_add_replace_npc_pressed.bind(step_id))
		pop_inspector_parent()

	build_step_action_inspector(step_id, step)

	var ops_section := add_inspector_section("step_runtime_ops", "RUNTIME OPS / RAW JSON", false)
	push_inspector_parent(ops_section)
	add_inspector_button("Add Tutorial Hint On Enter", _on_step_add_tutorial_hint_pressed.bind(step_id))
	add_text_field("On Enter Ops JSON", operations_to_text(step.get("on_enter", [])), Vector2(550, 115), _on_step_operations_json_changed.bind(step_id, "on_enter"))
	add_text_field("On Arrival Ops JSON", operations_to_text(step.get("on_arrival", [])), Vector2(550, 85), _on_step_operations_json_changed.bind(step_id, "on_arrival"))
	add_text_field("On Battle Victory Ops JSON", operations_to_text(step.get("on_battle_victory", [])), Vector2(550, 85), _on_step_operations_json_changed.bind(step_id, "on_battle_victory"))
	pop_inspector_parent()

	build_step_story_popup_inspector(step_id, step)


func build_object_inspector(object_id: String) -> void:
	var objects: Dictionary = event_packet.get("event_objects", {})
	if not objects.has(object_id):
		add_inspector_title("Missing Object")
		return

	var object_data: Dictionary = objects[object_id]
	var object_type := str(object_data.get("object_type", object_data.get("owner_type", ""))).strip_edges().to_lower()
	add_inspector_title("Object: " + object_id)
	add_inspector_button("Delete Object", _on_delete_object_pressed.bind(object_id))

	var basic_section := add_inspector_section("object_basic", "BASIC", true)
	push_inspector_parent(basic_section)
	add_commit_line_field("Stable Object ID", object_id, _on_object_id_changed.bind(object_id))
	add_option_field("Object Type", ["enemy", "beacon", "npc", "planet", "space_object", "asteroid", "star", "object"], str(object_data.get("object_type", object_data.get("owner_type", "enemy"))), _on_object_type_selected.bind(object_id))
	if object_type == "npc":
		add_catalog_option_field("Blueprint ID", get_npc_catalog_options(), get_catalog_blueprint_selection(object_data, object_id), _on_object_npc_blueprint_selected.bind(object_id))
	elif object_type == "enemy":
		add_catalog_option_field("Blueprint ID", get_enemy_catalog_options(), get_catalog_blueprint_selection(object_data, object_id), _on_object_enemy_blueprint_selected.bind(object_id))
	else:
		add_line_field("Blueprint ID", str(object_data.get("blueprint_id", "")), _on_object_text_changed.bind(object_id, "blueprint_id"))
	add_line_field("Display Name", str(object_data.get("display_name", object_id)), _on_object_text_changed.bind(object_id, "display_name"))
	if is_real_actor_type(str(object_data.get("object_type", object_data.get("owner_type", "")))):
		add_inspector_button("Sync Real Object Identity", _on_sync_object_identity_pressed.bind(object_id))
		add_inspector_note("For catalog NPCs/enemies, keep the stable object id local and let blueprint id point to the selected database row.")
	add_option_field("Spawn On Step", [""] + get_step_ids(), str(object_data.get("spawn_on_step", "")), _on_object_spawn_step_selected.bind(object_id))
	pop_inspector_parent()

	var icon_section := add_inspector_section("object_icon", "MAIN VIEW ICON", true)
	push_inspector_parent(icon_section)
	add_line_field("Icon ID", str(object_data.get("main_view_icon_id", "")), _on_object_text_changed.bind(object_id, "main_view_icon_id"))
	add_line_field("Icon Path", str(object_data.get("main_view_icon_path", "")), _on_object_text_changed.bind(object_id, "main_view_icon_path"))
	add_inspector_button("Use Standard Path From Icon ID", _on_object_icon_standard_path_pressed.bind(object_id))
	add_inspector_note("Authored objects should point at a PNG in UI/PortView/main_view/icons. Defaults remain for generated objects, but story JSON should name its icon.")
	pop_inspector_parent()

	var placement_section := add_inspector_section("object_placement", "PLACEMENT", false)
	push_inspector_parent(placement_section)
	add_catalog_option_field("Copy From World Seed", get_world_object_catalog_options(), get_world_seed_selection(object_data), _on_object_world_seed_selected.bind(object_id))
	add_option_field("Position Mode", ["absolute", "anchor_offset", "anchor_relative"], str(object_data.get("position_mode", "absolute")), _on_object_position_mode_selected.bind(object_id))
	add_vector3_field("Sector", object_data.get("sector_pos", [0, 0, 0]), _on_object_sector_changed.bind(object_id))
	add_vector3_field("Local", object_data.get("local_pos", [500, 500, 500]), _on_object_local_changed.bind(object_id))
	add_vector3_field("Sector Offset", object_data.get("sector_offset", [0, 0, 0]), _on_object_sector_offset_changed.bind(object_id))
	add_vector3_field("Local Offset", object_data.get("local_offset", [0, 0, 0]), _on_object_local_offset_changed.bind(object_id))
	pop_inspector_parent()

	if object_type == "npc":
		var npc_content_section := add_inspector_section("object_npc_content", "NPC CONTENT", true)
		push_inspector_parent(npc_content_section)
		add_text_field("Message", str(object_data.get("message", "")), Vector2(550, 70), _on_object_text_changed.bind(object_id, "message"))
		add_text_field("NPC Object Talk Lines", dialogue_lines_to_text(object_data.get("dialogue_lines", [])), Vector2(550, 90), _on_object_dialogue_lines_changed.bind(object_id))
		add_spin_field("NPC Object Chat Line Delay", float(object_data.get("chat_line_delay", 1.65)), 0.1, 10.0, 0.05, _on_object_chat_delay_changed.bind(object_id))
		add_spin_field("NPC Object Chat Type Delay", float(object_data.get("chat_character_delay", object_data.get("chat_type_delay", 0.04))), 0.005, 0.5, 0.005, _on_object_chat_character_delay_changed.bind(object_id))
		add_check_field("NPC Object Trade Button", bool(object_data.get("can_trade", object_data.get("trade", false))), _on_object_bool_changed.bind(object_id, "can_trade"))
		add_check_field("NPC Object Quest Button", bool(object_data.get("has_event", false)), _on_object_bool_changed.bind(object_id, "has_event"))
		add_line_field("NPC Trade Title", str(object_data.get("offer_title", "")), _on_object_text_changed.bind(object_id, "offer_title"))
		add_text_field("NPC Trade Text", str(object_data.get("offer_text", "")), Vector2(550, 55), _on_object_text_changed.bind(object_id, "offer_text"))
		add_line_field("NPC Trade Success", str(object_data.get("success_text", "")), _on_object_text_changed.bind(object_id, "success_text"))
		add_catalog_option_field("Trade Item ID", get_item_catalog_options(), "", _on_object_trade_item_catalog_selected.bind(object_id))
		add_text_field("NPC Trade Items item:amount:role", trade_items_to_text(object_data.get("item_list", [])), Vector2(550, 80), _on_object_trade_items_changed.bind(object_id))
		pop_inspector_parent()

		var npc_tools_section := add_inspector_section("object_npc_tools", "NPC RUNTIME TOOLS", false)
		push_inspector_parent(npc_tools_section)
		add_inspector_note("Use these when a story beat should change, remove, or replace this NPC in the live world.")
		add_inspector_button("Create Refresh NPC Step", _on_create_npc_refresh_step_pressed.bind(object_id))
		add_inspector_button("Create Remove NPC Step", _on_create_remove_npc_step_pressed.bind(object_id))
		add_inspector_button("Create Replace NPC Step", _on_create_replace_npc_step_pressed.bind(object_id))
		pop_inspector_parent()
	else:
		var object_content_section := add_inspector_section("object_content", "OBJECT CONTENT", false)
		push_inspector_parent(object_content_section)
		add_text_field("Message", str(object_data.get("message", "")), Vector2(550, 70), _on_object_text_changed.bind(object_id, "message"))
		pop_inspector_parent()

	if object_type == "enemy":
		var overrides: Dictionary = object_data.get("overrides", {}) if typeof(object_data.get("overrides", {})) == TYPE_DICTIONARY else {}
		var enemy_section := add_inspector_section("object_enemy_stats", "ENEMY STATS", false)
		push_inspector_parent(enemy_section)
		add_spin_field("HP", float(overrides.get("hp", overrides.get("max_hp", 160))), 1.0, 9999.0, 1.0, _on_object_override_number_changed.bind(object_id, "hp"))
		add_spin_field("Attack", float(overrides.get("attack", 12)), 0.0, 9999.0, 1.0, _on_object_override_number_changed.bind(object_id, "attack"))
		pop_inspector_parent()


func build_listener_inspector(listener_id: String) -> void:
	var listeners: Dictionary = event_packet.get("event_listeners", {})
	if not listeners.has(listener_id):
		add_inspector_title("Missing Listener")
		return

	var listener_data: Dictionary = listeners[listener_id]
	add_inspector_title("Event Listener: " + listener_id)
	add_inspector_button("Delete Listener", _on_delete_listener_pressed.bind(listener_id))

	var basic_section := add_inspector_section("listener_basic", "BASIC", true)
	push_inspector_parent(basic_section)
	add_commit_line_field("Stable Listener ID", listener_id, _on_listener_id_changed.bind(listener_id))
	add_line_field("Display Name", str(listener_data.get("display_name", listener_id)), _on_listener_display_name_changed.bind(listener_id))
	add_option_field("Listener Type", get_listener_type_options(), str(listener_data.get("listener_type", "seed_event_on_range")), _on_listener_text_selected.bind(listener_id, "listener_type"))
	pop_inspector_parent()

	var trigger_section := add_inspector_section("listener_trigger", "TRIGGER", true)
	push_inspector_parent(trigger_section)
	add_line_field("Trigger Event ID", str(listener_data.get("trigger_event_id", event_packet.get("event_id", ""))), _on_listener_text_changed.bind(listener_id, "trigger_event_id"))
	var start_step_options := [""] + get_step_ids()
	var start_step := str(listener_data.get("start_step", ""))
	if start_step != "" and not start_step_options.has(start_step):
		start_step_options.append(start_step)
	add_option_field("Start Step", start_step_options, start_step, _on_listener_text_selected.bind(listener_id, "start_step"))
	add_spin_field("Trigger Range", float(listener_data.get("trigger_range", 1000)), 1.0, 50000.0, 25.0, _on_listener_number_changed.bind(listener_id, "trigger_range"))
	add_check_field("Trigger Once", bool(listener_data.get("trigger_once", true)), _on_listener_bool_changed.bind(listener_id, "trigger_once"))
	add_check_field("Suppress Trigger Popup", bool(listener_data.get("suppress_trigger_popup", is_activate_listener_type(str(listener_data.get("listener_type", ""))))), _on_listener_bool_changed.bind(listener_id, "suppress_trigger_popup"))
	add_check_field("Show Trigger Feedback", bool(listener_data.get("show_trigger_feedback", false)), _on_listener_bool_changed.bind(listener_id, "show_trigger_feedback"))
	add_text_field("Trigger Popup Message", str(listener_data.get("trigger_popup_message", "")), Vector2(550, 120), _on_listener_text_changed.bind(listener_id, "trigger_popup_message"))
	add_text_field("Triggered Message", str(listener_data.get("triggered_message", "")), Vector2(550, 60), _on_listener_text_changed.bind(listener_id, "triggered_message"))
	add_inspector_note("Seed listeners add an available event. Activate listeners start the event directly and are quiet by default so the first story popup stays clean.")
	pop_inspector_parent()

	build_listener_awareness_conditions_inspector(listener_id, listener_data)

	var placement_section := add_inspector_section("listener_placement", "PLACEMENT", false)
	push_inspector_parent(placement_section)
	add_option_field("Position Mode", ["absolute", "anchor_offset", "anchor_relative"], str(listener_data.get("position_mode", "anchor_offset")), _on_listener_text_selected.bind(listener_id, "position_mode"))
	add_vector3_field("Sector", listener_data.get("sector_pos", [0, 0, 0]), _on_listener_sector_changed.bind(listener_id))
	add_vector3_field("Local", listener_data.get("local_pos", [500, 500, 500]), _on_listener_local_changed.bind(listener_id))
	add_vector3_field("Sector Offset", listener_data.get("sector_offset", [0, 0, 0]), _on_listener_sector_offset_changed.bind(listener_id))
	add_vector3_field("Local Offset", listener_data.get("local_offset", [100, 0, 0]), _on_listener_local_offset_changed.bind(listener_id))
	add_text_field("Beacon Message", str(listener_data.get("message", "")), Vector2(550, 60), _on_listener_text_changed.bind(listener_id, "message"))
	pop_inspector_parent()


func add_inspector_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.72, 0.92, 1.0, 1.0))
	get_inspector_parent().add_child(label)


func add_inspector_subtitle(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.66, 0.82, 1.0, 0.9))
	get_inspector_parent().add_child(label)


func add_inspector_note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(550, 36)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.76, 0.82, 0.90, 0.84))
	get_inspector_parent().add_child(label)


func add_inspector_button(text: String, target_callable: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170, 28)
	button.pressed.connect(target_callable)
	get_inspector_parent().add_child(button)


func build_step_story_popup_inspector(step_id: String, step: Dictionary) -> void:
	var popup_op := get_story_popup_operation(step)
	var popup_section := add_inspector_section("step_story_popup", "STORY POPUP", not popup_op.is_empty() or str(step.get("interaction_type", "")) == "story_popup")
	push_inspector_parent(popup_section)
	if popup_op.is_empty():
		add_inspector_button("Add Story Popup On Enter", _on_step_add_story_popup_pressed.bind(step_id))
		add_inspector_note("Use a popup step when a story beat should show first, then move to the next step after the player closes it or the countdown finishes.")
		pop_inspector_parent()
		return

	var popup_size := read_popup_size(popup_op)
	add_inspector_button("Remove Story Popup On Enter", _on_step_remove_story_popup_pressed.bind(step_id))
	add_line_field("Story Popup Title", str(popup_op.get("title", "STORY")), _on_step_story_popup_text_changed.bind(step_id, "title"))
	add_text_field("Story Popup Text", str(popup_op.get("bbcode", popup_op.get("text", popup_op.get("message", "")))), Vector2(550, 110), _on_step_story_popup_text_changed.bind(step_id, "text"))
	add_text_field("Story Popup Image Paths, one res:// path per line", story_popup_images_to_text(popup_op.get("images", popup_op.get("image_paths", []))), Vector2(550, 70), _on_step_story_popup_images_changed.bind(step_id))
	add_option_field("Story Popup Close Mode", ["button", "timer", "both"], normalize_story_popup_close_mode_value(str(popup_op.get("close_mode", "button"))), _on_step_story_popup_close_mode_selected.bind(step_id))
	add_spin_field("Story Popup Countdown", float(popup_op.get("duration", popup_op.get("countdown", 4.0))), 0.1, 120.0, 0.1, _on_step_story_popup_number_changed.bind(step_id, "duration"))
	add_spin_field("Story Popup Width", popup_size.x, 360.0, 720.0, 10.0, _on_step_story_popup_size_changed.bind(step_id, "x"))
	add_spin_field("Story Popup Height", popup_size.y, 260.0, 540.0, 10.0, _on_step_story_popup_size_changed.bind(step_id, "y"))
	add_spin_field("Story Popup Image Height", float(popup_op.get("image_height", 112.0)), 48.0, 300.0, 4.0, _on_step_story_popup_number_changed.bind(step_id, "image_height"))
	add_option_field("Story Popup Next Step On Close", get_next_step_options(), str(popup_op.get("next_step_on_close", popup_op.get("advance_step_on_close", ""))), _on_step_story_popup_next_step_selected.bind(step_id))
	pop_inspector_parent()


func build_step_action_inspector(step_id: String, step: Dictionary) -> void:
	var actions := get_step_actions_array(step)
	var default_open := not actions.is_empty() or button_action_step_type(str(step.get("interaction_type", "")))
	var actions_section := add_inspector_section("step_actions", "ACTIONS / BUTTON OPS", default_open)
	push_inspector_parent(actions_section)
	add_inspector_note("Buttons in this section appear in the event widget. They run runtime actions such as download, claim reward, advance step, or button-owned operations.")
	add_inspector_button("Use Download/Handoff Button", _on_step_use_download_action_pressed.bind(step_id))
	add_inspector_button("Use Popup Continue Button", _on_step_use_popup_continue_action_pressed.bind(step_id))
	add_inspector_button("Use Claim Reward Button", _on_step_use_claim_reward_action_pressed.bind(step_id))
	add_inspector_button("Use Advance Button", _on_step_use_advance_action_pressed.bind(step_id))
	if actions.is_empty():
		pop_inspector_parent()
		return

	var action := get_primary_step_action(step)
	add_line_field("Button ID", str(action.get("button_id", step_id)), _on_step_action_text_changed.bind(step_id, "button_id"))
	add_line_field("Button Label", str(action.get("label", "CONTINUE")), _on_step_action_text_changed.bind(step_id, "label"))
	add_option_field("Action ID", get_event_action_id_options(), str(action.get("action_id", "event_operations")), _on_step_action_text_changed.bind(step_id, "action_id"))
	add_spin_field("Button Range", float(action.get("range", get_step_range_value(step, 70.0))), 0.0, 50000.0, 5.0, _on_step_action_number_changed.bind(step_id, "range"))
	add_option_field("Button Target Object", [""] + get_object_ids(), str(action.get("target_object_id", "")), _on_step_action_text_changed.bind(step_id, "target_object_id"))
	add_option_field("Button Next Step", get_next_step_options(), get_action_next_step_value(action), _on_step_action_text_changed.bind(step_id, "next_step"))
	add_check_field("Requires Position Gate", bool(action.get("requires_position_gate", false)), _on_step_action_bool_changed.bind(step_id, "requires_position_gate"))
	add_text_field("Button Operations JSON", action_operations_to_text(action), Vector2(550, 105), _on_step_action_operations_json_changed.bind(step_id))
	add_text_field("All Button Actions JSON", actions_to_text(actions), Vector2(550, 120), _on_step_actions_json_changed.bind(step_id))
	add_inspector_button("Clear Button Actions", _on_step_clear_actions_pressed.bind(step_id))
	pop_inspector_parent()


func build_event_awareness_conditions_inspector() -> void:
	var condition_key := get_awareness_condition_edit_key(event_packet)
	var section := add_inspector_section("event_awareness_conditions", "AWARENESS / INTEL CONDITIONS", has_awareness_conditions(event_packet))
	push_inspector_parent(section)
	add_inspector_note("These gates are read-only checks. They can wait for discovered item intel or defeated enemy intel without saving extra data into the universe JSON.")
	add_inspector_button("Add Item Discovered Gate", _on_event_add_item_discovered_condition_pressed)
	add_inspector_button("Add Event Enemy Defeated Gate", _on_event_add_event_enemy_defeated_condition_pressed)
	add_inspector_button("Add Enemy Defeat Count Gate", _on_event_add_enemy_count_condition_pressed)
	add_text_field("Event Conditions JSON (" + condition_key + ")", conditions_to_text(event_packet.get(condition_key, [])), Vector2(550, 105), _on_packet_conditions_json_changed.bind(condition_key))
	pop_inspector_parent()


func build_step_awareness_conditions_inspector(step_id: String, step: Dictionary) -> void:
	var condition_key := get_awareness_condition_edit_key(step)
	var section := add_inspector_section("step_awareness_conditions_" + step_id, "AWARENESS / INTEL CONDITIONS", has_awareness_conditions(step))
	push_inspector_parent(section)
	add_inspector_note("Step gates are checked before active step enter/arrival behavior runs.")
	add_inspector_button("Add Item Discovered Gate", _on_step_add_item_discovered_condition_pressed.bind(step_id, condition_key))
	add_inspector_button("Add Event Enemy Defeated Gate", _on_step_add_event_enemy_defeated_condition_pressed.bind(step_id, condition_key))
	add_inspector_button("Add Enemy Defeat Count Gate", _on_step_add_enemy_count_condition_pressed.bind(step_id, condition_key))
	add_text_field("Step Conditions JSON (" + condition_key + ")", conditions_to_text(step.get(condition_key, [])), Vector2(550, 105), _on_step_conditions_json_changed.bind(step_id, condition_key))
	pop_inspector_parent()


func build_listener_awareness_conditions_inspector(listener_id: String, listener_data: Dictionary) -> void:
	var condition_key := get_awareness_condition_edit_key(listener_data)
	var section := add_inspector_section("listener_awareness_conditions_" + listener_id, "AWARENESS / INTEL CONDITIONS", has_awareness_conditions(listener_data))
	push_inspector_parent(section)
	add_inspector_note("Listener gates are checked before a seed/start listener fires in the world.")
	add_inspector_button("Add Item Discovered Gate", _on_listener_add_item_discovered_condition_pressed.bind(listener_id, condition_key))
	add_inspector_button("Add Event Enemy Defeated Gate", _on_listener_add_event_enemy_defeated_condition_pressed.bind(listener_id, condition_key))
	add_inspector_button("Add Enemy Defeat Count Gate", _on_listener_add_enemy_count_condition_pressed.bind(listener_id, condition_key))
	add_text_field("Listener Conditions JSON (" + condition_key + ")", conditions_to_text(listener_data.get(condition_key, [])), Vector2(550, 105), _on_listener_conditions_json_changed.bind(listener_id, condition_key))
	pop_inspector_parent()


func add_line_field(label_text: String, value: String, target_callable: Callable) -> LineEdit:
	var parent := get_inspector_parent()
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	parent.add_child(label)
	var edit := LineEdit.new()
	edit.text = value
	edit.custom_minimum_size = Vector2(550, 28)
	edit.text_changed.connect(target_callable)
	parent.add_child(edit)
	return edit


func add_commit_line_field(label_text: String, value: String, target_callable: Callable) -> LineEdit:
	var parent := get_inspector_parent()
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	parent.add_child(label)
	var edit := LineEdit.new()
	edit.text = value
	edit.custom_minimum_size = Vector2(550, 28)
	edit.text_submitted.connect(target_callable)
	edit.focus_exited.connect(_on_commit_line_focus_exited.bind(edit, target_callable))
	parent.add_child(edit)
	return edit


func add_text_field(label_text: String, value: String, field_size: Vector2, target_callable: Callable) -> TextEdit:
	var parent := get_inspector_parent()
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	parent.add_child(label)
	var edit := TextEdit.new()
	edit.text = value
	edit.custom_minimum_size = field_size
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.text_changed.connect(_on_text_field_changed.bind(edit, target_callable))
	parent.add_child(edit)
	return edit


func add_readonly_text_field(value: String, field_size: Vector2) -> TextEdit:
	var edit := TextEdit.new()
	edit.text = value
	edit.editable = false
	edit.custom_minimum_size = field_size
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.add_theme_font_size_override("font_size", 10)
	get_inspector_parent().add_child(edit)
	return edit


func add_spin_field(label_text: String, value: float, min_value: float, max_value: float, step: float, target_callable: Callable) -> SpinBox:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(550, 30)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170, 24)
	label.add_theme_font_size_override("font_size", 11)
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.custom_minimum_size = Vector2(130, 28)
	spin.value_changed.connect(target_callable)
	row.add_child(spin)
	get_inspector_parent().add_child(row)
	return spin


func add_check_field(label_text: String, value: bool, target_callable: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.text = label_text
	check.button_pressed = value
	check.custom_minimum_size = Vector2(550, 28)
	check.toggled.connect(target_callable)
	get_inspector_parent().add_child(check)
	return check


func add_option_field(label_text: String, values: Array, selected_value: String, target_callable: Callable) -> OptionButton:
	var parent := get_inspector_parent()
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	parent.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(550, 28)
	if values.is_empty():
		values = [""]
	var has_selected := selected_value == ""
	for value in values:
		option.add_item(str(value))
		if str(value) == selected_value:
			has_selected = true
	if selected_value != "" and not has_selected:
		option.add_item(selected_value)
	var selected_index := 0
	for i in range(option.item_count):
		if option.get_item_text(i) == selected_value:
			selected_index = i
			break
	option.select(selected_index)
	option.item_selected.connect(_on_option_field_selected.bind(option, target_callable))
	parent.add_child(option)
	return option


func add_catalog_option_field(label_text: String, options: Array, selected_id: String, target_callable: Callable) -> OptionButton:
	var parent := get_inspector_parent()
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 11)
	parent.add_child(label)

	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(550, 28)
	if options.is_empty():
		options = [{"id": "", "label": ""}]

	var clean_selected := selected_id.strip_edges()
	var selected_index := 0
	var found_selected := clean_selected == ""
	for option_data in options:
		var option_id := ""
		var option_label := ""
		if typeof(option_data) == TYPE_DICTIONARY:
			option_id = str(option_data.get("id", "")).strip_edges()
			option_label = str(option_data.get("label", option_id)).strip_edges()
		else:
			option_id = str(option_data).strip_edges()
			option_label = option_id
		if option_label == "" and option_id != "":
			option_label = option_id
		option.add_item(option_label)
		var item_index := option.item_count - 1
		option.set_item_metadata(item_index, option_id)
		if option_id == clean_selected:
			selected_index = item_index
			found_selected = true

	if clean_selected != "" and not found_selected:
		option.add_item("Missing: " + clean_selected)
		selected_index = option.item_count - 1
		option.set_item_metadata(selected_index, clean_selected)

	option.select(selected_index)
	option.item_selected.connect(_on_catalog_option_field_selected.bind(option, target_callable))
	parent.add_child(option)
	return option


func add_vector3_field(label_text: String, value, target_callable: Callable) -> void:
	var vec := read_vector3_array(value)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(550, 30)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 24)
	label.add_theme_font_size_override("font_size", 11)
	row.add_child(label)
	for i in range(3):
		var spin := SpinBox.new()
		spin.min_value = -999999.0
		spin.max_value = 999999.0
		spin.step = 1.0
		spin.value = float(vec[i])
		spin.custom_minimum_size = Vector2(92, 28)
		spin.value_changed.connect(_on_vector_axis_changed.bind(target_callable, i))
		row.add_child(spin)
	get_inspector_parent().add_child(row)


func refresh_preview() -> void:
	if selected_kind == "docs":
		preview_text.text = get_docs_text(selected_id)
		return
	preview_text.text = JSON.stringify(event_packet, "\t")


func refresh_universe_options() -> void:
	if universe_options == null:
		return

	var active_id := str(Globals.active_universe_id).strip_edges()
	var selected_index := 0
	universe_options.clear()

	var lanes := get_available_universe_lane_options()
	for i in range(lanes.size()):
		var lane: Dictionary = lanes[i]
		var universe_id := str(lane.get("universe_id", "")).strip_edges()
		if universe_id == "":
			continue
		var item_index := universe_options.item_count
		universe_options.add_item(build_universe_option_label(lane))
		universe_options.set_item_metadata(item_index, lane.duplicate(true))
		if universe_id == active_id:
			selected_index = item_index

	if universe_options.item_count > 0:
		universe_options.select(selected_index)


func get_available_universe_lane_options() -> Array:
	var lanes_by_id := {}

	for lane in Globals.get_available_universe_lanes():
		if typeof(lane) != TYPE_DICTIONARY:
			continue
		var lane_data: Dictionary = lane.duplicate(true)
		var universe_id := str(lane_data.get("universe_id", "")).strip_edges()
		if universe_id == "":
			continue
		lanes_by_id[universe_id] = normalize_universe_lane_packet(lane_data)

	var root := DirAccess.open(UNIVERSE_ROOT_DIR)
	if root != null:
		root.list_dir_begin()
		var entry_name := root.get_next()
		while entry_name != "":
			if root.current_is_dir() and not entry_name.begins_with("."):
				var universe_id := entry_name.strip_edges()
				if universe_id != "" and not lanes_by_id.has(universe_id):
					lanes_by_id[universe_id] = normalize_universe_lane_packet({
						"universe_id": universe_id,
						"display_name": universe_id.replace("_", " ").capitalize(),
						"description": "Discovered universe lane.",
						"events_dir": UNIVERSE_ROOT_DIR.path_join(universe_id).path_join("events"),
						"world_seeds_dir": UNIVERSE_ROOT_DIR.path_join(universe_id).path_join("world_seeds"),
						"save_lane": universe_id
					})
			entry_name = root.get_next()
		root.list_dir_end()

	var ids := lanes_by_id.keys()
	ids.sort()
	var output := []
	for universe_id in ids:
		output.append(lanes_by_id[universe_id])
	return output


func normalize_universe_lane_packet(lane_data: Dictionary) -> Dictionary:
	var lane := lane_data.duplicate(true)
	var universe_id := str(lane.get("universe_id", "universe_1")).strip_edges()
	if universe_id == "":
		universe_id = "universe_1"
	lane["universe_id"] = universe_id

	if str(lane.get("display_name", "")).strip_edges() == "":
		lane["display_name"] = universe_id.replace("_", " ").capitalize()
	if str(lane.get("events_dir", "")).strip_edges() == "":
		lane["events_dir"] = UNIVERSE_ROOT_DIR.path_join(universe_id).path_join("events")
	if str(lane.get("world_seeds_dir", "")).strip_edges() == "":
		lane["world_seeds_dir"] = UNIVERSE_ROOT_DIR.path_join(universe_id).path_join("world_seeds")
	if str(lane.get("save_lane", "")).strip_edges() == "":
		lane["save_lane"] = universe_id
	return lane


func build_universe_option_label(lane: Dictionary) -> String:
	var universe_id := str(lane.get("universe_id", "")).strip_edges()
	var display_name := str(lane.get("display_name", universe_id)).strip_edges()
	if display_name == "":
		display_name = universe_id
	if universe_id != "" and universe_id != display_name:
		return display_name + " / " + universe_id
	return display_name


func refresh_load_options() -> void:
	if load_options == null:
		return
	load_options.clear()
	for event_id in storage.list_event_ids():
		load_options.add_item(str(event_id))
	if load_options.item_count > 0:
		load_options.select(0)


func get_tool_ready_status() -> String:
	var counts := catalog.get_counts() if catalog != null else {}
	var event_dir := storage.get_storage_dir() if storage != null else ""
	var seed_dir := catalog.get_world_seed_dir() if catalog != null else ""
	var universe_id := str(Globals.active_universe_id).strip_edges()
	if universe_id == "":
		universe_id = "default"
	var display_name := str(Globals.active_universe_display_name).strip_edges()
	if display_name == "":
		display_name = universe_id
	return "Event dev tool " + EVENT_TOOL_VERSION + " ready. Universe: " + display_name + " (" + universe_id + ") | Events: " + str(counts.get("events", 0)) + " | Event lane: " + event_dir + " | World seeds: " + seed_dir + " | Items: " + str(counts.get("items", 0)) + ", NPCs: " + str(counts.get("npcs", 0)) + ", enemies: " + str(counts.get("enemies", 0)) + "."


func get_docs_title(doc_id: String) -> String:
	match doc_id:
		"orbit":
			return "v2.3 Orbit Handoffs"
		"json":
			return "v2.3 JSON Authoring Map"
		_:
			return "v2.3 Event Engine Reference"


func get_docs_summary(doc_id: String) -> String:
	match doc_id:
		"orbit":
			return "Author planet/orbit discoveries as quiet event handoffs, visible discoveries, or installed world listeners."
		"json":
			return "Use active-lane JSON files as the source of truth. Event files live in the universe event lane; planet/orbit fields live in world seed JSON."
		_:
			return "The event engine turns authored JSON into active events, event objects, range listeners, widget buttons, story popups, rewards, and save state."


func get_docs_text(doc_id: String) -> String:
	match doc_id:
		"orbit":
			return build_orbit_docs_text()
		"json":
			return build_json_authoring_docs_text()
		_:
			return build_engine_docs_text()


func build_engine_docs_text() -> String:
	var counts := catalog.get_counts() if catalog != null else {}
	var lines := []
	lines.append("FOREVER SPACE EVENT ENGINE " + EVENT_TOOL_VERSION)
	lines.append("")
	lines.append("Active lane")
	lines.append("Universe: " + str(Globals.active_universe_id))
	lines.append("Events: " + (storage.get_storage_dir() if storage != null else ""))
	lines.append("World seeds: " + (catalog.get_world_seed_dir() if catalog != null else ""))
	lines.append("Loaded catalogs: " + str(counts.get("events", 0)) + " events, " + str(counts.get("world_objects", 0)) + " world objects, " + str(counts.get("items", 0)) + " items, " + str(counts.get("npcs", 0)) + " NPCs, " + str(counts.get("enemies", 0)) + " enemies")
	lines.append("Use the toolbar Universe dropdown to switch lanes. The event load list, event catalog, and world seed object catalogs refresh from the selected lane.")
	lines.append("The current draft remains in the editor when switching lanes; Save writes it to the selected universe event folder.")
	lines.append("")
	lines.append("Core runtime map")
	lines.append("GameEventsHandler loads event JSON, owns active/available/completed event state, installs event beacons, runs widget/button ops, and saves event state.")
	lines.append("EventWorldBuilder and world seed loaders place authored event objects into the current universe lane.")
	lines.append("OrbitHandler scans planet data from world seed JSON and queues Orbit event discovery packets for GameEventsHandler.")
	lines.append("SaveManager persists active universe state so silent discoveries and installed listeners survive reloads.")
	lines.append("")
	lines.append("Event JSON root")
	lines.append("event_id, display_name, event_state, current_step, start_on_ready, seed_once, tier")
	lines.append("anchor_star, giver, event_objects, event_listeners, required_items, reward_packet, steps")
	lines.append("")
	lines.append("Step model")
	lines.append("Each step needs objective_text and normally points to next_step. Interaction types include talk, story_popup, tutorial_popup, find, inspect, hunt, download, handoff, turn_in, claim, and complete.")
	lines.append("Use on_enter/on_arrival/on_battle_victory for runtime operations. Use actions for event-widget buttons.")
	lines.append("")
	lines.append("World event listeners")
	lines.append("event_listeners are hidden/authored objects that seed or activate an event when the player enters trigger_range.")
	lines.append("Supported world listener types: seed_event_on_range, seed_event, add_available_event, discover_event, activate_event_on_range, activate_event, start_event_on_range, start_event.")
	lines.append("")
	lines.append("Validation focus")
	lines.append("The tool checks ids, chain shape, target references, object identity, authored icon paths, condition shapes, listener ranges, Orbit handoff shape, and missing target event files.")
	return join_strings(lines, "\n")


func build_orbit_docs_text() -> String:
	var discover_example := {
		"orbit_event_listeners": [
			{
				"queue_id": "planet_archive_silent_discovery",
				"event_id": "vela_archive_signal_001",
				"orbit_event_action": "discover_event",
				"silent": true,
				"visible_in_orbit": false
			}
		]
	}
	var install_example := {
		"orbit_event_listeners": [
			{
				"queue_id": "planet_claim_notice_installer",
				"event_id": "vela_orbit_claim_notice_001",
				"orbit_event_action": "install_event_listener",
				"listener_id": "vela_claim_notice_range_listener",
				"installed_listener_type": "activate_event_on_range",
				"trigger_range": 1250,
				"silent": true,
				"visible_in_orbit": false,
				"suppress_trigger_popup": true
			}
		]
	}
	var lines := []
	lines.append("ORBIT EVENT HANDOFFS")
	lines.append("")
	lines.append("Where this is authored")
	lines.append("Planet/orbit handoff fields belong on planet objects in world seed JSON, not in event JSON. The event dev tool validates the shape when the same collection appears in an event draft, and this page documents the engine contract.")
	lines.append("")
	lines.append("Recognized planet keys")
	lines.append("orbit_event_listeners, orbit_discovered_event_listeners, orbital_event_listeners")
	lines.append("")
	lines.append("Recognized discovery/interaction keys")
	lines.append("orbit_event_listeners, event_listeners, discover_events, silent_discover_events")
	lines.append("")
	lines.append("Actions")
	lines.append("discover_event: add the target event to available events. Use silent true for background chapter handoffs.")
	lines.append("activate_event: start the target event immediately. Best used silently when the first event step owns the visible story beat.")
	lines.append("install_event_listener: spawn a normal world range listener for the target event after Orbit discovers it.")
	lines.append("")
	lines.append("Silent discovery example")
	lines.append(JSON.stringify(discover_example, "\t"))
	lines.append("")
	lines.append("Install range listener example")
	lines.append(JSON.stringify(install_example, "\t"))
	lines.append("")
	lines.append("Authoring rules")
	lines.append("Every packet needs an event id: event_id, trigger_event_id, target_event_id, discover_event_id, or activate_event_id.")
	lines.append("Use queue_id for stable save/dedupe behavior.")
	lines.append("Use silent/background plus visible_in_orbit false for handoffs that should not show UI.")
	lines.append("For installed listeners, set installed_listener_type and trigger_range explicitly.")
	lines.append("For direct activation, start_step must match the target event current_step if supplied.")
	return join_strings(lines, "\n")


func build_json_authoring_docs_text() -> String:
	var event_example := {
		"event_id": "example_orbit_followup_001",
		"display_name": "Example Orbit Followup",
		"event_state": "seeded",
		"current_step": "incoming_signal",
		"start_on_ready": false,
		"seed_once": true,
		"event_objects": {},
		"event_listeners": {},
		"steps": {
			"incoming_signal": {
				"objective_text": "Decode the orbital signal.",
				"interaction_type": "story_popup",
				"next_step": "completed"
			}
		}
	}
	var lines := []
	lines.append("JSON AUTHORING MAP")
	lines.append("")
	lines.append("Event files")
	lines.append("Save event JSON in the active universe event lane. Current lane: " + (storage.get_storage_dir() if storage != null else ""))
	lines.append("Use the toolbar Universe dropdown before loading or saving if you want a different lane.")
	lines.append("Filename should match event_id.json after sanitation.")
	lines.append("")
	lines.append("World seed files")
	lines.append("Planet/orbit data belongs in active universe world seeds. Current lane: " + (catalog.get_world_seed_dir() if catalog != null else ""))
	lines.append("Planet objects can own scan_description, surface_sites, orbit_discoveries, orbit_interactions, and orbit_event_listeners.")
	lines.append("")
	lines.append("Minimum event file shape")
	lines.append(JSON.stringify(event_example, "\t"))
	lines.append("")
	lines.append("Cross-file references")
	lines.append("Planet orbit_event_listeners reference event_id values in the event lane.")
	lines.append("Event event_listeners reference their own trigger_event_id and install hidden beacons into the world.")
	lines.append("Steps reference event_objects by target_object_id/enemy_id and items by item ids from the item catalog.")
	lines.append("")
	lines.append("Authored assets")
	lines.append("Orbit-only items, icons, popup images, discovery text, surface sites, and interaction labels need to be authored. The engine will route the data, but it cannot invent final content assets.")
	lines.append("")
	lines.append("Suggested authoring order")
	lines.append("1. Create the target event JSON first.")
	lines.append("2. Validate and save the event from this tool.")
	lines.append("3. Add the planet orbit_event_listeners in world seed JSON.")
	lines.append("4. Run Orbit scan in game and verify available/active/installed event state.")
	return join_strings(lines, "\n")


func make_default_event_packet() -> Dictionary:
	return {
		"event_id": "new_story_event_001",
		"display_name": "New Story Event",
		"event_state": "seeded",
		"current_step": "talk_to_contact",
		"start_on_ready": false,
		"seed_once": true,
		"tier": 1,
		"anchor_star": {
			"star_id": "story_anchor_star_001",
			"star_name": "Story Gate",
			"star_type": "K",
			"sector_pos": [0, 0, 0],
			"local_pos": [500, 500, 500],
			"brightness": 1.3,
			"size": 1.4,
			"tier": 1,
			"required": true,
			"create_if_missing": true
		},
		"giver": {
			"owner_type": "npc",
			"owner_id": "story_contact_001",
			"object_id": "story_contact_001",
			"template_owner_id": "story_contact_001",
			"blueprint_id": "story_contact_001",
			"display_name": "Story Contact",
			"place_near_anchor_star": true,
			"local_offset": [25, 0, 0],
			"labels": ["npc", "event_giver", "story_npc", "story_contact_001", "authored_object"]
		},
		"event_objects": {},
		"event_listeners": {},
		"required_items": [],
		"reward_packet": {
			"credits": 0,
			"items": [],
			"blueprints": [],
			"lore": [],
			"unlocks": [],
			"message": "Story event complete."
		},
		"steps": {
			"talk_to_contact": {
				"objective_text": "Talk to the story contact.",
				"target_owner_id": "story_contact_001",
				"interaction_type": "talk",
				"npc_dialogue_lines": [
					"I have a new story signal for you.",
					"Follow the event console and come back when the trail changes."
				],
				"npc_chat_line_delay": 1.65,
				"npc_chat_character_delay": 0.04,
				"npc_quest_available": true,
				"next_step": "return_to_contact"
			},
			"return_to_contact": {
				"objective_text": "Return to the story contact and claim the reward.",
				"target_owner_id": "story_contact_001",
				"interaction_range": 70,
				"npc_dialogue_lines": [
					"You made it back. Good.",
					"Let me see what the story signal did to your logs."
				],
				"completed_npc_dialogue_lines": [
					"That closes this thread.",
					"If the story wakes up again, I will have different words for you."
				],
				"npc_chat_line_delay": 1.65,
				"npc_chat_character_delay": 0.04,
				"next_step": "completed",
				"actions": [{
					"button_id": "claim_story_reward",
					"label": "CLAIM",
					"action_id": "claim_event_reward",
					"range": 70
				}]
			}
		}
	}


func ensure_packet_shape() -> void:
	if typeof(event_packet.get("anchor_star", {})) != TYPE_DICTIONARY:
		event_packet["anchor_star"] = make_default_event_packet()["anchor_star"]
	if typeof(event_packet.get("giver", {})) != TYPE_DICTIONARY:
		event_packet["giver"] = make_default_event_packet()["giver"]
	if typeof(event_packet.get("event_objects", {})) != TYPE_DICTIONARY:
		event_packet["event_objects"] = {}
	if typeof(event_packet.get("event_listeners", {})) != TYPE_DICTIONARY:
		event_packet["event_listeners"] = {}
	if typeof(event_packet.get("steps", {})) != TYPE_DICTIONARY:
		event_packet["steps"] = {}
	if typeof(event_packet.get("reward_packet", {})) != TYPE_DICTIONARY:
		event_packet["reward_packet"] = make_default_event_packet()["reward_packet"]


func ensure_dict(parent: Dictionary, key: String) -> Dictionary:
	if typeof(parent.get(key, {})) != TYPE_DICTIONARY:
		parent[key] = {}
	return parent[key]


func get_step_ids() -> Array:
	var ids: Array = []
	var steps: Dictionary = event_packet.get("steps", {})
	for step_id in steps.keys():
		ids.append(str(step_id))
	return ids


func get_story_chain_entries() -> Array:
	var entries: Array = []
	var steps: Dictionary = event_packet.get("steps", {})
	var visited: Dictionary = {}
	var current_step := str(event_packet.get("current_step", "")).strip_edges()
	var chain_index := 1

	if current_step == "":
		entries.append({
			"step_id": "",
			"label": "!! Missing current_step",
			"missing": true
		})
	elif not steps.has(current_step):
		entries.append({
			"step_id": current_step,
			"label": "!! Missing current_step: " + current_step,
			"missing": true
		})
	else:
		var walk_step := current_step
		while walk_step != "" and walk_step != "completed":
			if visited.has(walk_step):
				entries.append({
					"step_id": walk_step,
					"label": "!! Cycle returns to: " + walk_step,
					"cycle": true
				})
				break
			if not steps.has(walk_step):
				entries.append({
					"step_id": walk_step,
					"label": "!! Missing next_step: " + walk_step,
					"missing": true
				})
				break

			visited[walk_step] = true
			var step: Dictionary = steps[walk_step]
			entries.append({
				"step_id": walk_step,
				"label": format_step_chain_label(chain_index, walk_step, step, "chain"),
				"state": "chain"
			})
			chain_index += 1
			var next_step := get_effective_step_next(step)
			if next_step == "" or next_step == "completed":
				break
			walk_step = next_step

	var unlinked_ids: Array = []
	for step_id in steps.keys():
		var clean_id := str(step_id)
		if not visited.has(clean_id):
			unlinked_ids.append(clean_id)
	unlinked_ids.sort()
	for step_id in unlinked_ids:
		var step: Dictionary = steps[step_id]
		entries.append({
			"step_id": step_id,
			"label": format_step_chain_label(0, step_id, step, "unlinked"),
			"state": "unlinked"
		})
	return entries


func format_step_chain_label(chain_index: int, step_id: String, step: Dictionary, state: String) -> String:
	var prefix := str(chain_index).pad_zeros(2) + ". " if chain_index > 0 else "UNLINKED "
	var label := prefix + step_id
	var next_step := str(step.get("next_step", "")).strip_edges()
	if next_step != "":
		label += " -> " + next_step
	else:
		var effective_next := get_effective_step_next(step)
		if effective_next != "":
			label += " ~> " + effective_next
	var action_count := 0
	var actions = step.get("actions", [])
	if typeof(actions) == TYPE_ARRAY:
		action_count = actions.size()
	if action_count > 0:
		label += " [" + str(action_count) + " btn]"
	var interaction_type := str(step.get("interaction_type", "")).strip_edges()
	if interaction_type != "":
		label += " {" + interaction_type + "}"
	if state == "unlinked" and str(event_packet.get("current_step", "")) == step_id:
		label = "CURRENT? " + label
	return label


func get_next_step_options() -> Array:
	return [""] + get_step_ids() + ["completed"]


func get_story_popup_operation_index(step: Dictionary) -> int:
	var operations = step.get("on_enter", [])
	if typeof(operations) != TYPE_ARRAY:
		return -1
	for i in range(operations.size()):
		if typeof(operations[i]) != TYPE_DICTIONARY:
			continue
		var operation: Dictionary = operations[i]
		var op_id := str(operation.get("op", operation.get("action_id", operation.get("type", "")))).strip_edges().to_lower()
		if op_id == "show_story_popup" or op_id == "story_popup":
			return i
	return -1


func get_story_popup_operation(step: Dictionary) -> Dictionary:
	var index := get_story_popup_operation_index(step)
	if index < 0:
		return {}
	var operations = step.get("on_enter", [])
	if typeof(operations) != TYPE_ARRAY or index >= operations.size():
		return {}
	if typeof(operations[index]) != TYPE_DICTIONARY:
		return {}
	return operations[index]


func make_story_popup_operation(next_step_on_close: String = "") -> Dictionary:
	return {
		"op": "show_story_popup",
		"title": "Story Beat",
		"text": "[b]Story beat[/b]\n\nAdd the scene text here.",
		"images": [],
		"popup_size": {"x": 580, "y": 430},
		"image_height": 112,
		"close_mode": "button",
		"duration": 4.0,
		"next_step_on_close": next_step_on_close
	}


func ensure_story_popup_operation(step_id: String) -> Dictionary:
	var step := get_step(step_id)
	var operations := get_step_operation_array(step, "on_enter")
	var index := get_story_popup_operation_index(step)
	if index < 0:
		var operation := make_story_popup_operation(str(step.get("next_step", "")))
		operations.append(operation)
		step["on_enter"] = operations
		set_step(step_id, step)
		return operation
	if typeof(operations[index]) != TYPE_DICTIONARY:
		operations[index] = make_story_popup_operation(str(step.get("next_step", "")))
	var popup_op: Dictionary = operations[index]
	popup_op["op"] = "show_story_popup"
	operations[index] = popup_op
	step["on_enter"] = operations
	set_step(step_id, step)
	return popup_op


func set_story_popup_operation(step_id: String, operation: Dictionary) -> void:
	var step := get_step(step_id)
	var operations := get_step_operation_array(step, "on_enter")
	var index := get_story_popup_operation_index(step)
	if index < 0:
		operations.append(operation)
	else:
		operations[index] = operation
	step["on_enter"] = operations
	set_step(step_id, step)


func read_popup_size(operation: Dictionary) -> Vector2:
	var raw_size = operation.get("popup_size", operation.get("size", {"x": 580, "y": 430}))
	if raw_size is Vector2:
		return raw_size
	if typeof(raw_size) == TYPE_DICTIONARY:
		return Vector2(float(raw_size.get("x", 580.0)), float(raw_size.get("y", 430.0)))
	if typeof(raw_size) == TYPE_ARRAY and raw_size.size() >= 2:
		return Vector2(float(raw_size[0]), float(raw_size[1]))
	return Vector2(580, 430)


func normalize_story_popup_close_mode_value(raw_value: String) -> String:
	var clean := raw_value.strip_edges().to_lower()
	if clean == "timer" or clean == "countdown" or clean == "auto" or clean == "automatic":
		return "timer"
	if clean == "both" or clean == "button_and_timer" or clean == "button_timer" or clean == "timer_or_button":
		return "both"
	return "button"


func get_object_ids() -> Array:
	var ids: Array = []
	var objects: Dictionary = event_packet.get("event_objects", {})
	for object_id in objects.keys():
		ids.append(str(object_id))
	return ids


func get_enemy_object_ids() -> Array:
	var ids: Array = []
	var objects: Dictionary = event_packet.get("event_objects", {})
	for object_id in objects.keys():
		var object_data: Dictionary = objects[object_id]
		if str(object_data.get("owner_type", object_data.get("object_type", ""))) == "enemy":
			ids.append(str(object_id))
	return ids


func get_npc_object_ids() -> Array:
	var ids: Array = []
	var objects: Dictionary = event_packet.get("event_objects", {})
	for object_id in objects.keys():
		var object_data: Dictionary = objects[object_id]
		var object_type := str(object_data.get("object_type", object_data.get("owner_type", ""))).strip_edges().to_lower()
		if object_type == "npc":
			ids.append(str(object_id))
	ids.sort()
	return ids


func get_item_catalog_options(type_filter: Array = []) -> Array:
	if catalog == null:
		return [{"id": "", "label": ""}]
	return catalog.get_item_options(type_filter)


func get_npc_catalog_options() -> Array:
	if catalog == null:
		return [{"id": "", "label": ""}]
	return catalog.get_npc_options()


func get_enemy_catalog_options() -> Array:
	if catalog == null:
		return [{"id": "", "label": ""}]
	return catalog.get_enemy_options()


func get_world_object_catalog_options(type_filter: Array = []) -> Array:
	if catalog == null:
		return [{"id": "", "label": ""}]
	return catalog.get_world_object_options(type_filter)


func get_world_anchor_catalog_options() -> Array:
	if catalog == null:
		return [{"id": "", "label": ""}]
	return catalog.get_world_anchor_options()


func get_event_action_id_options() -> Array:
	return [
		"open_event_list",
		"select_event",
		"start_available_event",
		"start_event",
		"download_beacon_data",
		"claim_event_reward",
		"event_operations",
		"run_operations",
		"advance_step",
		"show_story_popup",
		"story_popup",
		"show_tutorial_hint",
		"tutorial_hint",
		"show_helper_message"
	]


func get_catalog_blueprint_selection(object_data: Dictionary, stable_id: String) -> String:
	var source_blueprint_id := str(object_data.get("source_blueprint_id", "")).strip_edges()
	if source_blueprint_id != "":
		return source_blueprint_id
	var catalog_source := str(object_data.get("catalog_source", "")).strip_edges()
	var blueprint_id := str(object_data.get("blueprint_id", "")).strip_edges()
	if blueprint_id != "" and (catalog_source == "npc_blueprints" or catalog_source == "enemy_blueprints" or blueprint_id != stable_id):
		return blueprint_id
	return ""


func get_world_seed_selection(object_data: Dictionary) -> String:
	var source_id := str(object_data.get("source_world_seed_object_id", "")).strip_edges()
	if source_id != "":
		return source_id
	if str(object_data.get("catalog_source", "")).strip_edges() == "world_seed":
		return str(object_data.get("catalog_id", "")).strip_edges()
	return ""


func get_anchor_star_selection(anchor: Dictionary) -> String:
	var source_id := get_world_seed_selection(anchor)
	if source_id != "":
		return source_id
	return str(anchor.get("star_id", "")).strip_edges()


func get_effective_step_next(step: Dictionary) -> String:
	var direct_next := str(step.get("next_step", "")).strip_edges()
	if direct_next != "":
		return direct_next

	for key in ["on_enter", "on_arrival", "on_battle_victory"]:
		var operation_next := get_operations_next_step(step.get(key, []))
		if operation_next != "":
			return operation_next

	var actions = step.get("actions", [])
	if typeof(actions) == TYPE_ARRAY:
		for action in actions:
			if typeof(action) != TYPE_DICTIONARY:
				continue
			var action_next := get_action_next_step_value(action)
			if action_next != "":
				return action_next
	return ""


func get_operations_next_step(operations) -> String:
	if typeof(operations) != TYPE_ARRAY:
		return ""
	for operation in operations:
		if typeof(operation) != TYPE_DICTIONARY:
			continue
		var op: Dictionary = operation
		var op_id := str(op.get("op", op.get("action_id", op.get("type", "")))).strip_edges().to_lower()
		if op_id == "advance_step":
			var next_step := str(op.get("next_step", "")).strip_edges()
			if next_step != "":
				return next_step
		elif op_id == "show_story_popup" or op_id == "story_popup":
			var popup_next := str(op.get("next_step_on_close", op.get("advance_step_on_close", ""))).strip_edges()
			if popup_next != "":
				return popup_next
		elif op_id == "show_tutorial_hint" or op_id == "tutorial_hint" or op_id == "show_helper_message":
			var tutorial_next := str(op.get("next_step_after_hint", op.get("next_step_on_close", op.get("advance_step_on_close", "")))).strip_edges()
			if tutorial_next != "":
				return tutorial_next
	return ""


func should_show_step_npc_dialogue(step: Dictionary) -> bool:
	if step_has_npc_context(step):
		return true
	for key in ["npc_dialogue_lines", "completed_npc_dialogue_lines", "npc_dialogue_target_owner_id", "npc_chat_line_delay", "npc_chat_character_delay", "npc_can_trade", "npc_quest_available"]:
		if step.has(key):
			return true
	return false


func should_show_step_npc_tools(step: Dictionary) -> bool:
	return step_has_npc_context(step) or step_has_npc_operation(step)


func step_has_npc_context(step: Dictionary) -> bool:
	var interaction_type := str(step.get("interaction_type", "")).strip_edges().to_lower()
	if ["talk", "npc_contact", "handoff", "turn_in"].has(interaction_type):
		return true
	return step_targets_npc(step)


func step_targets_npc(step: Dictionary) -> bool:
	for key in ["target_object_id", "npc_dialogue_target_owner_id", "target_owner_id", "npc_id"]:
		var value := str(step.get(key, "")).strip_edges()
		if value == "":
			continue
		if is_event_object_npc(value) or value == get_stable_giver_id():
			return true
	return false


func is_event_object_npc(object_id: String) -> bool:
	var object_data := get_event_object(object_id)
	if object_data.is_empty():
		return false
	var object_type := str(object_data.get("object_type", object_data.get("owner_type", ""))).strip_edges().to_lower()
	return object_type == "npc"


func is_event_object_enemy(object_id: String) -> bool:
	var object_data := get_event_object(object_id)
	if object_data.is_empty():
		return false
	var object_type := str(object_data.get("object_type", object_data.get("owner_type", ""))).strip_edges().to_lower()
	return object_type == "enemy"


func step_has_npc_operation(step: Dictionary) -> bool:
	for key in ["on_enter", "on_arrival", "on_battle_victory"]:
		if operations_have_npc_operation(step.get(key, [])):
			return true
	var actions = step.get("actions", [])
	if typeof(actions) == TYPE_ARRAY:
		for action in actions:
			if typeof(action) != TYPE_DICTIONARY:
				continue
			if operations_have_npc_operation(action.get("operations", [])):
				return true
			if operations_have_npc_operation([action.get("operation", {})]):
				return true
	return false


func operations_have_npc_operation(operations) -> bool:
	if typeof(operations) != TYPE_ARRAY:
		return false
	for operation in operations:
		if typeof(operation) != TYPE_DICTIONARY:
			continue
		var op_id := str(operation.get("op", operation.get("action_id", operation.get("type", "")))).strip_edges().to_lower()
		if is_npc_operation_id(op_id):
			return true
	return false


func is_npc_operation_id(op_id: String) -> bool:
	return [
		"update_npc_dialogue",
		"set_npc_dialogue",
		"set_npc_talk_lines",
		"update_npc_contact",
		"set_npc_contact",
		"set_npc_actions",
		"remove_npc",
		"despawn_npc",
		"delete_npc",
		"spawn_npc",
		"install_npc",
		"refresh_npc",
		"refresh_npc_context",
		"replace_npc",
		"swap_npc",
		"reload_npc"
	].has(op_id.strip_edges().to_lower())


func get_listener_ids() -> Array:
	var ids: Array = []
	var listeners: Dictionary = event_packet.get("event_listeners", {})
	for listener_id in listeners.keys():
		ids.append(str(listener_id))
	return ids


func get_listener_type_options() -> Array:
	return [
		"seed_event_on_range",
		"activate_event_on_range",
		"seed_event",
		"activate_event",
		"start_event_on_range",
		"start_event",
		"add_available_event",
		"discover_event"
	]


func get_step_range_value(step: Dictionary, fallback: float = 70.0) -> float:
	var preferred_key := get_step_range_key(step)
	if preferred_key != "" and step.has(preferred_key):
		return float(step.get(preferred_key, fallback))
	for key in ["interaction_range", "gate_range", "activation_range", "target_range", "range", "arrival_range", "radius", "pos_radius", "position_radius"]:
		if step.has(key):
			return float(step.get(key, fallback))
	return fallback


func set_step_range_value(step: Dictionary, value: float) -> void:
	var key := get_step_range_key(step)
	if key == "":
		return
	step[key] = float(value)
	if key == "interaction_range" and not is_arrival_step(step):
		step.erase("arrival_range")
	elif key == "arrival_range" and is_hunt_or_battle_step(step):
		step.erase("arrival_range")
		step["interaction_range"] = float(value)


func get_step_range_key(step: Dictionary) -> String:
	if is_hunt_or_battle_step(step):
		return "interaction_range"
	if is_arrival_step(step):
		return "arrival_range"
	if step.has("gate_range"):
		return "gate_range"
	if is_action_gated_step(step):
		return "interaction_range"
	if step.has("interaction_range"):
		return "interaction_range"
	if step.has("arrival_range"):
		return "arrival_range"
	return "interaction_range"


func is_hunt_or_battle_step(step: Dictionary) -> bool:
	var interaction_type := str(step.get("interaction_type", step.get("event_type", step.get("step_kind", "")))).strip_edges().to_lower()
	if ["hunt", "battle"].has(interaction_type):
		return true
	if str(step.get("enemy_id", "")).strip_edges() != "":
		return true
	if bool(step.get("complete_on_battle_victory", false)):
		return true
	return step_has_operation(step, ["start_battle", "start_hunt_battle"])


func is_arrival_step(step: Dictionary) -> bool:
	if is_hunt_or_battle_step(step):
		return false
	var interaction_type := str(step.get("interaction_type", "")).strip_edges().to_lower()
	if ["find", "travel", "go_to", "arrive"].has(interaction_type):
		return true
	return step.has("on_arrival")


func is_action_gated_step(step: Dictionary) -> bool:
	var interaction_type := str(step.get("interaction_type", "")).strip_edges().to_lower()
	if ["download", "handoff", "turn_in", "claim", "complete", "npc_contact", "talk", "inspect", "event_start"].has(interaction_type):
		return true
	return step.has("actions")


func step_has_operation(step: Dictionary, op_ids: Array) -> bool:
	for key in ["on_enter", "on_arrival", "on_battle_victory"]:
		var operations = step.get(key, [])
		if operations_have_operation(operations, op_ids):
			return true
	var actions = step.get("actions", [])
	if typeof(actions) == TYPE_ARRAY:
		for action in actions:
			if typeof(action) != TYPE_DICTIONARY:
				continue
			if operations_have_operation(action.get("operations", []), op_ids):
				return true
			if operations_have_operation([action.get("operation", {})], op_ids):
				return true
	return false


func operations_have_operation(operations, op_ids: Array) -> bool:
	if typeof(operations) != TYPE_ARRAY:
		return false
	for operation in operations:
		if typeof(operation) != TYPE_DICTIONARY:
			continue
		var op_id := str(operation.get("op", operation.get("action_id", operation.get("type", "")))).strip_edges().to_lower()
		if op_ids.has(op_id):
			return true
	return false


func is_activate_listener_type(listener_type: String) -> bool:
	var clean_type := listener_type.strip_edges().to_lower()
	return ["activate_event_on_range", "activate_event", "start_event_on_range", "start_event"].has(clean_type)


func sync_listener_type_defaults(listener_data: Dictionary) -> void:
	var listener_type := str(listener_data.get("listener_type", "")).strip_edges()
	if is_activate_listener_type(listener_type):
		if str(listener_data.get("start_step", "")).strip_edges() == "":
			listener_data["start_step"] = str(event_packet.get("current_step", ""))
		if str(listener_data.get("trigger_popup_message", "")).begins_with("[b]Intercepted Beacon Signal[/b]"):
			listener_data["trigger_popup_message"] = ""
		if not listener_data.has("suppress_trigger_popup"):
			listener_data["suppress_trigger_popup"] = true
		if not listener_data.has("show_trigger_feedback"):
			listener_data["show_trigger_feedback"] = false
	else:
		if not listener_data.has("suppress_trigger_popup"):
			listener_data["suppress_trigger_popup"] = false
		if not listener_data.has("show_trigger_feedback"):
			listener_data["show_trigger_feedback"] = true
	var labels = listener_data.get("labels", [])
	if typeof(labels) != TYPE_ARRAY:
		labels = []
	for label in ["beacon", "event_listener", str(event_packet.get("event_id", "")), "authored_object"]:
		if str(label).strip_edges() != "" and not labels.has(label):
			labels.append(label)
	if listener_type != "" and not labels.has(listener_type):
		labels.append(listener_type)
	listener_data["labels"] = labels


func make_unique_id(prefix: String, existing: Dictionary) -> String:
	var clean := storage.sanitize_id(prefix)
	if clean == "":
		clean = "id"
	if not existing.has(clean):
		return clean
	var index := 2
	while existing.has(clean + "_" + str(index)):
		index += 1
	return clean + "_" + str(index)


func make_display_name_from_id(raw_id: String) -> String:
	var words := storage.sanitize_id(raw_id).replace("_", " ").replace("-", " ")
	return words.capitalize()


func add_event_object(object_type: String, preferred_id: String = "") -> String:
	var objects: Dictionary = event_packet.get("event_objects", {})
	var event_id := storage.sanitize_id(str(event_packet.get("event_id", "story_event")))
	var prefix := preferred_id if preferred_id != "" else event_id + "_" + object_type + "_001"
	var object_id := make_unique_id(prefix, objects)
	var display := make_display_name_from_id(object_id)
	var object_data := {
		"owner_type": object_type,
		"object_type": object_type,
		"object_id": object_id,
		"display_name": display,
		"event_id": event_id,
		"active_event_id": event_id,
		"has_event": true,
		"main_view_icon_id": "",
		"main_view_icon_path": "",
		"sector_pos": [0, 0, 0],
		"local_pos": [500, 500, 500],
		"labels": [object_type, "event_" + object_type, event_id, "authored_object"]
	}

	if object_type == "enemy":
		object_data["blueprint_id"] = object_id
		object_data["template_owner_id"] = object_id
		object_data["overrides"] = {
			"ship_name": display,
			"hp": 130,
			"max_hp": 130,
			"attack": 10,
			"energy_max": 260,
			"primary": "e_basic_energy_pew_pew",
			"secondary": "railgun_mk1",
			"shield": "basic_shield_mk1",
			"consumable": "repair_kit",
			"item_stacks": {
				"small_kinetic_rounds": 8,
				"repair_kit": 1
			},
			"behavior_profile": "smart_guy",
			"reward": ["iron", "nickel", "small_kinetic_rounds"]
		}
	elif object_type == "beacon":
		object_data["beacon_type"] = "event_beacon"
		object_data["interaction_type"] = "download"
		object_data["message"] = "Event beacon signal is active."
	elif object_type == "npc":
		object_data["owner_id"] = object_id
		object_data["template_owner_id"] = object_id
		object_data["blueprint_id"] = object_id
		object_data["interaction_type"] = "npc_contact"
		object_data["dialogue_lines"] = ["Contact link established.", "I have updated context for this story beat."]
		object_data["chat_line_delay"] = 1.65
		object_data["chat_character_delay"] = 0.04
		object_data["labels"] = ["npc", "event_target_npc", "story_npc", object_id, event_id, "authored_object"]
	elif object_type == "planet":
		object_data["owner_type"] = "planet"
		object_data["object_type"] = "planet"
		object_data["title"] = display
		object_data["scan_name"] = display
		object_data["scan_description"] = "Authored story planet contact."
		object_data["contact_text"] = "Orbital contact available."
		object_data["planet_type"] = "rocky"
		object_data["planet_role"] = "story_planet"
		object_data["population_state"] = "frontier"
		object_data["has_planet_interface"] = true
		object_data["can_land"] = false
		object_data["interaction_type"] = "planet_contact"
		object_data["labels"] = ["planet", "event_object", "story_planet", object_id, event_id, "authored_object"]
	elif object_type == "star":
		object_data["owner_type"] = "star"
		object_data["object_type"] = "star"
		object_data["star_name"] = display
		object_data["star_type"] = "K"
		object_data["brightness"] = 1.2
		object_data["size"] = 1.4
		object_data["labels"] = ["star", "event_object", "story_star", object_id, event_id, "authored_object"]
	elif object_type == "asteroid" or object_type == "space_object" or object_type == "object":
		object_data["owner_type"] = object_type
		object_data["object_type"] = object_type
		object_data["space_object_type"] = "asteroid" if object_type == "asteroid" else object_type
		object_data["scan_name"] = display
		object_data["scan_description"] = "Authored story object."
		object_data["resource_type"] = "iron" if object_type == "asteroid" else ""
		object_data["labels"] = ["space_object", object_type, "event_object", object_id, event_id, "authored_object"]

	ensure_main_view_icon_fields(object_data)
	objects[object_id] = object_data
	event_packet["event_objects"] = objects
	return object_id


func add_event_listener(preferred_id: String = "") -> String:
	var listeners: Dictionary = event_packet.get("event_listeners", {})
	var event_id := storage.sanitize_id(str(event_packet.get("event_id", "story_event")))
	var anchor: Dictionary = event_packet.get("anchor_star", {}) if typeof(event_packet.get("anchor_star", {})) == TYPE_DICTIONARY else {}
	var prefix := preferred_id if preferred_id != "" else event_id + "_listener_001"
	var listener_id := make_unique_id(prefix, listeners)
	var display := make_display_name_from_id(listener_id)
	event_packet["start_on_ready"] = false
	listeners[listener_id] = {
		"owner_type": "beacon",
		"object_type": "beacon",
		"object_id": listener_id,
		"display_name": display,
		"title": display,
		"beacon_type": "event_listener_beacon",
		"position_mode": "anchor_offset",
		"sector_offset": [0, 0, 0],
		"local_offset": [250, 80, 20],
		"parent_star_id": str(anchor.get("star_id", "")),
		"parent_star_name": str(anchor.get("star_name", "")),
		"message": display + " is listening silently for a story signal.",
		"triggered_message": "New event discovered: " + str(event_packet.get("display_name", event_id)) + ".",
		"trigger_popup_message": "",
		"listener_type": "activate_event_on_range",
		"trigger_event_id": event_id,
		"start_step": str(event_packet.get("current_step", "")),
		"trigger_once": true,
		"triggered": false,
		"trigger_range": 140,
		"suppress_trigger_popup": true,
		"is_visible": false,
		"is_discovered": false,
		"is_completed": false,
		"labels": ["beacon", "event_listener", "activate_event_on_range", "hidden_listener", "invisible_listener", event_id, "authored_object"]
	}
	event_packet["event_listeners"] = listeners
	return listener_id


func append_step(step_id: String, step_data: Dictionary) -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	var previous_step := selected_id if selected_kind == "step" else ""
	steps[step_id] = step_data
	if previous_step != "" and steps.has(previous_step):
		var previous: Dictionary = steps[previous_step]
		if str(previous.get("next_step", "")).strip_edges() == "":
			previous["next_step"] = step_id
			steps[previous_step] = previous
	if str(event_packet.get("current_step", "")).strip_edges() == "":
		event_packet["current_step"] = step_id
	event_packet["steps"] = steps
	selected_kind = "step"
	selected_id = step_id


func create_talk_step() -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	var step_id := make_unique_id("talk_to_contact", steps)
	var giver_id := get_stable_giver_id()
	append_step(step_id, {
		"objective_text": "Talk to " + str(event_packet.get("giver", {}).get("display_name", "the contact")) + ".",
		"target_owner_id": giver_id,
		"interaction_type": "talk",
		"next_step": ""
	})


func create_story_popup_step() -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	var step_id := make_unique_id("story_popup", steps)
	append_step(step_id, {
		"objective_text": "Read the story popup.",
		"interaction_type": "story_popup",
		"next_step": "",
		"on_enter": [
			make_story_popup_operation("")
		]
	})


func create_tutorial_popup_step() -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	var step_id := make_unique_id("tutorial_hint", steps)
	append_step(step_id, {
		"objective_text": "Review tutorial hint.",
		"interaction_type": "tutorial_popup",
		"next_step": "",
		"on_enter": [{
			"op": "show_tutorial_hint",
			"title": "EVENT HELP",
			"text": "Use the Event panel to follow the active story objective.",
			"target_point_id": "event_panel",
			"line_to_point_id": "event_panel",
			"duration": 5.0,
			"popup_size": {"x": 330, "y": 126},
			"popup_offset": {"x": 30, "y": -22},
			"draw_line": true
		}]
	})


func create_find_step() -> void:
	var target_id := add_event_object("beacon", storage.sanitize_id(str(event_packet.get("event_id", "story_event"))) + "_story_beacon")
	var steps: Dictionary = event_packet.get("steps", {})
	var step_id := make_unique_id("find_" + target_id, steps)
	append_step(step_id, {
		"objective_text": "Find " + target_id + ".",
		"target_object_id": target_id,
		"interaction_type": "find",
		"arrival_range": 70,
		"next_step": ""
	})


func create_action_step() -> void:
	var target_id := add_event_object("beacon", storage.sanitize_id(str(event_packet.get("event_id", "story_event"))) + "_inspect_target")
	var steps: Dictionary = event_packet.get("steps", {})
	var step_id := make_unique_id("inspect_" + target_id, steps)
	append_step(step_id, {
		"objective_text": "Inspect " + target_id + ".",
		"target_object_id": target_id,
		"interaction_type": "inspect",
		"interaction_range": 70,
		"next_step": "",
		"actions": [{
			"button_id": step_id,
			"label": "INSPECT",
			"action_id": "advance_step",
			"range": 70,
			"requires_position_gate": true
		}]
	})


func create_hunt_step() -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	var step_id := make_unique_id("hunt_enemy", steps)
	var enemy_id := add_event_object("enemy", storage.sanitize_id(str(event_packet.get("event_id", "story_event"))) + "_" + step_id + "_enemy")
	var objects: Dictionary = event_packet.get("event_objects", {})
	var enemy: Dictionary = objects[enemy_id]
	enemy["spawn_on_step"] = step_id
	enemy["required_step"] = step_id
	enemy["event_step"] = step_id
	objects[enemy_id] = enemy
	event_packet["event_objects"] = objects
	append_step(step_id, make_hunt_step_packet(step_id, enemy_id))


func make_hunt_step_packet(step_id: String, enemy_id: String) -> Dictionary:
	return {
		"objective_text": "Defeat " + enemy_id + ".",
		"target_object_id": enemy_id,
		"enemy_id": enemy_id,
		"interaction_type": "hunt",
		"interaction_range": 180,
		"complete_on_battle_victory": true,
		"next_step": "",
		"on_enter": [{
			"op": "start_battle",
			"enemy_id": enemy_id,
			"entry_reason": step_id,
			"message": enemy_id + " has engaged."
		}],
		"on_battle_victory": [{
			"op": "write_log",
			"message": enemy_id + " defeated."
		}]
	}


func create_download_step() -> void:
	var target_id := add_event_object("beacon", storage.sanitize_id(str(event_packet.get("event_id", "story_event"))) + "_download_beacon")
	var steps: Dictionary = event_packet.get("steps", {})
	var step_id := make_unique_id("download_data", steps)
	append_step(step_id, {
		"objective_text": "Download data from " + target_id + ".",
		"target_object_id": target_id,
		"interaction_type": "download",
		"interaction_range": 70,
		"requires_item": "data_chip_empty",
		"gives_item": "data_chip_full",
		"next_step": "",
		"actions": [{
			"button_id": step_id,
			"label": "DOWNLOAD",
			"action_id": "download_beacon_data",
			"range": 70
		}]
	})


func create_handoff_step() -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	var step_id := make_unique_id("accept_handoff", steps)
	var target_id := get_primary_npc_target_id()
	append_step(step_id, {
		"objective_text": "Move close to " + target_id + " and accept the handoff.",
		"target_object_id": target_id,
		"interaction_type": "handoff",
		"interaction_range": 30,
		"gives_item": "story_handoff_item",
		"next_step": "",
		"actions": [{
			"button_id": step_id,
			"label": "ACCEPT",
			"action_id": "download_beacon_data",
			"range": 30
		}]
	})


func create_turn_in_step() -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	var step_id := make_unique_id("turn_in_item", steps)
	var target_id := get_primary_npc_target_id()
	append_step(step_id, {
		"objective_text": "Return to " + target_id + " and deliver the requested item.",
		"target_object_id": target_id,
		"interaction_type": "turn_in",
		"interaction_range": 95,
		"requires_item": "story_turn_in_item",
		"next_step": "",
		"actions": [{
			"button_id": step_id,
			"label": "DELIVER",
			"action_id": "download_beacon_data",
			"range": 95
		}]
	})


func create_npc_refresh_step(target_id: String = "") -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	var step_id := make_unique_id("refresh_npc_context", steps)
	var npc_id := target_id.strip_edges()
	if npc_id == "":
		npc_id = get_primary_npc_target_id()
	append_step(step_id, {
		"objective_text": "Refresh NPC context for " + npc_id + ".",
		"target_object_id": npc_id,
		"interaction_type": "npc_contact",
		"next_step": "",
		"on_enter": [{
			"op": "refresh_npc",
			"target_object_id": npc_id,
			"talk_meta": {
				"npc_dialogue_lines": [
					"Context refreshed.",
					"The story engine swapped my live talk metadata without rebuilding the whole event."
				],
				"npc_chat_line_delay": 1.65,
				"npc_chat_character_delay": 0.04,
				"message": "Context refreshed."
			}
		}]
	})


func create_remove_npc_step(target_id: String = "") -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	var step_id := make_unique_id("remove_npc", steps)
	var npc_id := target_id.strip_edges()
	if npc_id == "":
		npc_id = get_primary_npc_target_id()
	append_step(step_id, {
		"objective_text": "Remove NPC " + npc_id + " from the runtime world.",
		"target_object_id": npc_id,
		"next_step": "",
		"on_enter": [{
			"op": "remove_npc",
			"target_object_id": npc_id,
			"allow_missing": true
		}]
	})


func create_replace_npc_step(target_id: String = "") -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	var old_id := target_id.strip_edges()
	if old_id == "":
		old_id = get_primary_npc_target_id()
	var new_id := add_event_object("npc", storage.sanitize_id(str(event_packet.get("event_id", "story_event"))) + "_replacement_npc")
	var step_id := make_unique_id("replace_npc", steps)
	append_step(step_id, {
		"objective_text": "Replace " + old_id + " with " + new_id + ".",
		"target_object_id": new_id,
		"next_step": "",
		"on_enter": [{
			"op": "replace_npc",
			"target_object_id": old_id,
			"replacement_object_id": new_id,
			"talk_meta": {
				"npc_dialogue_lines": [
					"Replacement contact online.",
					"This actor inherited the event context cleanly."
				],
				"message": "Replacement contact online."
			}
		}]
	})


func create_return_step() -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	var step_id := make_unique_id("return_to_contact", steps)
	append_step(step_id, {
		"objective_text": "Return to the contact and claim the reward.",
		"target_owner_id": get_stable_giver_id(),
		"interaction_range": 70,
		"next_step": "completed",
		"actions": [{
			"button_id": "claim_" + storage.sanitize_id(str(event_packet.get("event_id", "event"))),
			"label": "CLAIM",
			"action_id": "claim_event_reward",
			"range": 70
		}]
	})


func create_complete_step() -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	var step_id := make_unique_id("complete_event", steps)
	append_step(step_id, {
		"objective_text": "Complete the event and claim the reward.",
		"target_owner_id": get_stable_giver_id(),
		"interaction_type": "complete",
		"interaction_range": 70,
		"next_step": "completed",
		"actions": [{
			"button_id": "complete_" + storage.sanitize_id(str(event_packet.get("event_id", "event"))),
			"label": "COMPLETE",
			"action_id": "claim_event_reward",
			"range": 70
		}]
	})


func get_stable_giver_id() -> String:
	var giver: Dictionary = event_packet.get("giver", {})
	return str(giver.get("template_owner_id", giver.get("owner_id", "story_contact_001")))


func clear_container(container: Node) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()


func _on_select_pressed(kind: String, id_value: String) -> void:
	selected_kind = kind
	selected_id = id_value
	refresh_all()


func _on_add_step_template_pressed(template_id: String) -> void:
	match template_id:
		"talk":
			create_talk_step()
		"story_popup":
			create_story_popup_step()
		"tutorial_popup":
			create_tutorial_popup_step()
		"find":
			create_find_step()
		"action":
			create_action_step()
		"hunt":
			create_hunt_step()
		"download":
			create_download_step()
		"handoff":
			create_handoff_step()
		"turn_in":
			create_turn_in_step()
		"return":
			create_return_step()
		"complete":
			create_complete_step()
		"npc_refresh":
			create_npc_refresh_step()
		"remove_npc":
			create_remove_npc_step()
		"replace_npc":
			create_replace_npc_step()
	refresh_all("Added " + template_id + " step.")


func _on_add_object_template_pressed(object_type: String) -> void:
	if object_type == "event_listener":
		var listener_id := add_event_listener()
		selected_kind = "listener"
		selected_id = listener_id
		refresh_all("Added listener: " + listener_id + ".")
		return
	var object_id := add_event_object(object_type)
	selected_kind = "object"
	selected_id = object_id
	refresh_all("Added " + object_id + ".")


func _on_new_pressed() -> void:
	event_packet = make_default_event_packet()
	selected_kind = "header"
	selected_id = ""
	refresh_all("New event started.")


func _on_load_pressed() -> void:
	if load_options.item_count <= 0:
		status_label.text = "No saved events to load."
		return
	var event_id := load_options.get_item_text(load_options.selected)
	var packet := storage.load_event_packet(event_id)
	if packet.is_empty():
		status_label.text = "Load failed: " + event_id
		return
	event_packet = packet
	ensure_packet_shape()
	selected_kind = "header"
	selected_id = ""
	refresh_all("Loaded: " + event_id)


func _on_validate_pressed() -> void:
	var result := storage.validate_event_packet(event_packet)
	status_label.text = validation_result_text(result)


func _on_save_pressed() -> void:
	event_packet["event_id"] = storage.sanitize_id(str(event_packet.get("event_id", "")))
	event_id_edit.text = str(event_packet.get("event_id", ""))
	var result := storage.validate_event_packet(event_packet)
	if str(result.get("status", "")) != "success":
		status_label.text = validation_result_text(result)
		return
	var save_result := storage.save_event_packet(event_packet)
	if str(save_result.get("status", "")) == "success":
		status_label.text = "Saved: " + str(save_result.get("file_path", ""))
		if catalog != null:
			catalog.refresh()
		refresh_load_options()
	else:
		status_label.text = "Save failed: " + str(save_result.get("reason", ""))


func validation_result_text(result: Dictionary) -> String:
	var errors: Array = result.get("errors", [])
	var warnings: Array = result.get("warnings", [])
	if errors.is_empty() and warnings.is_empty():
		return "Validation passed."
	var parts: Array = []
	if not errors.is_empty():
		parts.append("Errors: " + join_strings(errors, "; "))
	if not warnings.is_empty():
		parts.append("Warnings: " + join_strings(warnings, "; "))
	return join_strings(parts, " | ")


func join_strings(values: Array, separator: String) -> String:
	var out := ""
	for i in range(values.size()):
		if i > 0:
			out += separator
		out += str(values[i])
	return out


func dialogue_lines_to_text(value) -> String:
	var lines := parse_dialogue_lines(value)
	return join_strings(lines, "\n")


func parse_dialogue_lines(value) -> Array:
	var lines: Array = []
	if typeof(value) == TYPE_ARRAY:
		for line in value:
			var clean_line := str(line).strip_edges()
			if clean_line != "":
				lines.append(clean_line)
	elif typeof(value) == TYPE_STRING:
		for raw_line in str(value).split("\n", false):
			var clean_string := str(raw_line).strip_edges()
			if clean_string != "":
				lines.append(clean_string)
	return lines


func story_popup_images_to_text(value) -> String:
	var lines: Array = []
	if typeof(value) == TYPE_STRING:
		var clean := str(value).strip_edges()
		if clean != "":
			lines.append(clean)
	elif typeof(value) == TYPE_ARRAY:
		for item in value:
			if typeof(item) == TYPE_STRING:
				var clean_string := str(item).strip_edges()
				if clean_string != "":
					lines.append(clean_string)
			elif typeof(item) == TYPE_DICTIONARY:
				var image_data: Dictionary = item
				var path := str(image_data.get("path", image_data.get("image", ""))).strip_edges()
				if path != "":
					lines.append(path)
	return join_strings(lines, "\n")


func parse_story_popup_images(text: String) -> Array:
	var images: Array = []
	for raw_line in text.split("\n"):
		var path := raw_line.strip_edges()
		if path != "":
			images.append({"path": path})
	return images


func operations_to_text(value) -> String:
	if typeof(value) == TYPE_ARRAY:
		if value.is_empty():
			return ""
		return JSON.stringify(value, "\t")
	if typeof(value) == TYPE_DICTIONARY and not value.is_empty():
		return JSON.stringify([value], "\t")
	return ""


func actions_to_text(value) -> String:
	if typeof(value) == TYPE_ARRAY:
		if value.is_empty():
			return ""
		return JSON.stringify(value, "\t")
	if typeof(value) == TYPE_DICTIONARY and not value.is_empty():
		return JSON.stringify([value], "\t")
	return ""


func action_operations_to_text(action: Dictionary) -> String:
	if action.has("operations"):
		return operations_to_text(action.get("operations", []))
	if action.has("operation") and typeof(action.get("operation")) == TYPE_DICTIONARY:
		return operations_to_text([action.get("operation", {})])
	if action.has("popup") and typeof(action.get("popup")) == TYPE_DICTIONARY:
		return operations_to_text([action.get("popup", {})])
	if action.has("tutorial") and typeof(action.get("tutorial")) == TYPE_DICTIONARY:
		return operations_to_text([action.get("tutorial", {})])
	return ""


func parse_operations_json(text: String) -> Dictionary:
	var clean := text.strip_edges()
	if clean == "":
		return {"status": "success", "operations": []}
	var parsed = JSON.parse_string(clean)
	if typeof(parsed) == TYPE_ARRAY:
		for item in parsed:
			if typeof(item) != TYPE_DICTIONARY:
				return {"status": "failed", "reason": "Every operation must be a JSON object."}
		return {"status": "success", "operations": parsed}
	if typeof(parsed) == TYPE_DICTIONARY:
		return {"status": "success", "operations": [parsed]}
	return {"status": "failed", "reason": "Operations JSON must be an object or array."}


func parse_actions_json(text: String) -> Dictionary:
	var clean := text.strip_edges()
	if clean == "":
		return {"status": "success", "actions": []}
	var parsed = JSON.parse_string(clean)
	if typeof(parsed) == TYPE_ARRAY:
		for item in parsed:
			if typeof(item) != TYPE_DICTIONARY:
				return {"status": "failed", "reason": "Every action must be a JSON object."}
		return {"status": "success", "actions": parsed}
	if typeof(parsed) == TYPE_DICTIONARY:
		return {"status": "success", "actions": [parsed]}
	return {"status": "failed", "reason": "Actions JSON must be an object or array."}


func get_awareness_condition_keys() -> Array:
	return [
		"intel_conditions",
		AWARENESS_CONDITION_KEY,
		"event_conditions",
		"requires_intel",
		"conditions"
	]


func get_awareness_condition_edit_key(source: Dictionary) -> String:
	for key in get_awareness_condition_keys():
		if source.has(str(key)):
			return str(key)
	return AWARENESS_CONDITION_KEY


func has_awareness_conditions(source: Dictionary) -> bool:
	for key in get_awareness_condition_keys():
		if not source.has(str(key)):
			continue
		var value = source.get(str(key))
		if typeof(value) == TYPE_ARRAY and not value.is_empty():
			return true
		if typeof(value) == TYPE_DICTIONARY and not value.is_empty():
			return true
		if typeof(value) == TYPE_STRING and str(value).strip_edges() != "":
			return true
	return false


func conditions_to_text(value) -> String:
	if typeof(value) == TYPE_ARRAY:
		if value.is_empty():
			return ""
		return JSON.stringify(value, "\t")
	if typeof(value) == TYPE_DICTIONARY and not value.is_empty():
		return JSON.stringify(value, "\t")
	if typeof(value) == TYPE_STRING and str(value).strip_edges() != "":
		return JSON.stringify([{"type": str(value).strip_edges()}], "\t")
	return ""


func parse_conditions_json(text: String) -> Dictionary:
	var clean := text.strip_edges()
	if clean == "":
		return {"status": "success", "conditions": []}
	var parsed = JSON.parse_string(clean)
	if typeof(parsed) == TYPE_ARRAY:
		for item in parsed:
			if typeof(item) != TYPE_DICTIONARY and typeof(item) != TYPE_STRING:
				return {"status": "failed", "reason": "Every condition must be a JSON object or string."}
		return {"status": "success", "conditions": parsed}
	if typeof(parsed) == TYPE_DICTIONARY:
		return {"status": "success", "conditions": parsed}
	if typeof(parsed) == TYPE_STRING:
		return {"status": "success", "conditions": [{"type": str(parsed)}]}
	return {"status": "failed", "reason": "Conditions JSON must be an object, array, or string."}


func append_awareness_condition(source: Dictionary, condition_key: String, condition: Dictionary) -> void:
	var conditions: Array = []
	var existing = source.get(condition_key, [])
	if typeof(existing) == TYPE_ARRAY:
		conditions = existing.duplicate(true)
	elif typeof(existing) == TYPE_DICTIONARY and not existing.is_empty():
		conditions.append(existing.duplicate(true))
	elif typeof(existing) == TYPE_STRING and str(existing).strip_edges() != "":
		conditions.append({"type": str(existing).strip_edges()})
	conditions.append(condition.duplicate(true))
	source[condition_key] = conditions


func guess_condition_item_id(source: Dictionary = {}) -> String:
	for key in ["requires_item", "gives_item", "item_id", "intel_id"]:
		var value := str(source.get(str(key), "")).strip_edges()
		if value != "":
			return value
	var reward: Dictionary = event_packet.get("reward_packet", {}) if typeof(event_packet.get("reward_packet", {})) == TYPE_DICTIONARY else {}
	var items = reward.get("items", [])
	if typeof(items) == TYPE_ARRAY:
		for item in items:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var item_id := str(item.get("item_id", item.get("id", ""))).strip_edges()
			if item_id != "":
				return item_id
	return "story_item_id"


func guess_condition_enemy_id(source: Dictionary = {}) -> String:
	for key in ["enemy_id", "target_object_id", "object_id"]:
		var value := str(source.get(str(key), "")).strip_edges()
		if value != "" and is_event_object_enemy(value):
			return value
	var enemy_ids := get_enemy_object_ids()
	if not enemy_ids.is_empty():
		return str(enemy_ids[0])
	return "enemy_object_id"


func make_item_discovered_condition(source: Dictionary = {}) -> Dictionary:
	return {
		"type": "intel_discovered",
		"item_id": guess_condition_item_id(source)
	}


func make_event_enemy_defeated_condition(source: Dictionary = {}) -> Dictionary:
	return {
		"type": "event_enemy_defeated",
		"event_id": storage.sanitize_id(str(event_packet.get("event_id", ""))),
		"enemy_id": guess_condition_enemy_id(source)
	}


func make_enemy_count_condition(source: Dictionary = {}) -> Dictionary:
	var enemy_id := guess_condition_enemy_id(source)
	var enemy := get_event_object(enemy_id)
	var display_name := str(enemy.get("display_name", enemy_id)).strip_edges()
	if display_name == "":
		display_name = enemy_id
	return {
		"type": "enemy_defeated_count",
		"display_name": display_name,
		"min_count": 1
	}


func _on_event_id_changed(value: String) -> void:
	if refreshing:
		return
	event_packet["event_id"] = storage.sanitize_id(value)
	sync_event_ids()
	refresh_preview()


func _on_display_name_changed(value: String) -> void:
	if refreshing:
		return
	event_packet["display_name"] = value
	refresh_preview()


func _on_bool_packet_changed(value: bool, key: String) -> void:
	if refreshing:
		return
	event_packet[key] = value
	refresh_preview()


func _on_number_packet_changed(value: float, key: String) -> void:
	if refreshing:
		return
	event_packet[key] = int(value)
	refresh_preview()


func _on_packet_conditions_json_changed(value: String, key: String) -> void:
	if refreshing:
		return
	var parsed := parse_conditions_json(value)
	if str(parsed.get("status", "")) != "success":
		status_label.text = "Event conditions JSON error: " + str(parsed.get("reason", "invalid JSON"))
		return
	var conditions = parsed.get("conditions", [])
	if conditions_is_empty(conditions):
		event_packet.erase(key)
	else:
		event_packet[key] = conditions
	refresh_preview()


func _on_step_conditions_json_changed(value: String, step_id: String, key: String) -> void:
	if refreshing:
		return
	var parsed := parse_conditions_json(value)
	if str(parsed.get("status", "")) != "success":
		status_label.text = "Step conditions JSON error: " + str(parsed.get("reason", "invalid JSON"))
		return
	var step := get_step(step_id)
	var conditions = parsed.get("conditions", [])
	if conditions_is_empty(conditions):
		step.erase(key)
	else:
		step[key] = conditions
	set_step(step_id, step)
	refresh_preview()


func _on_listener_conditions_json_changed(value: String, listener_id: String, key: String) -> void:
	if refreshing:
		return
	var parsed := parse_conditions_json(value)
	if str(parsed.get("status", "")) != "success":
		status_label.text = "Listener conditions JSON error: " + str(parsed.get("reason", "invalid JSON"))
		return
	var listener_data := get_event_listener(listener_id)
	var conditions = parsed.get("conditions", [])
	if conditions_is_empty(conditions):
		listener_data.erase(key)
	else:
		listener_data[key] = conditions
	refresh_preview()


func conditions_is_empty(conditions) -> bool:
	if typeof(conditions) == TYPE_ARRAY:
		return conditions.is_empty()
	if typeof(conditions) == TYPE_DICTIONARY:
		return conditions.is_empty()
	if typeof(conditions) == TYPE_STRING:
		return str(conditions).strip_edges() == ""
	return true


func _on_event_add_item_discovered_condition_pressed() -> void:
	var condition_key := get_awareness_condition_edit_key(event_packet)
	append_awareness_condition(event_packet, condition_key, make_item_discovered_condition(event_packet))
	refresh_all("Event item discovery gate added.")


func _on_event_add_event_enemy_defeated_condition_pressed() -> void:
	var condition_key := get_awareness_condition_edit_key(event_packet)
	append_awareness_condition(event_packet, condition_key, make_event_enemy_defeated_condition(event_packet))
	refresh_all("Event enemy defeated gate added.")


func _on_event_add_enemy_count_condition_pressed() -> void:
	var condition_key := get_awareness_condition_edit_key(event_packet)
	append_awareness_condition(event_packet, condition_key, make_enemy_count_condition(event_packet))
	refresh_all("Event enemy count gate added.")


func _on_step_add_item_discovered_condition_pressed(step_id: String, condition_key: String) -> void:
	var step := get_step(step_id)
	append_awareness_condition(step, condition_key, make_item_discovered_condition(step))
	set_step(step_id, step)
	refresh_all("Step item discovery gate added.")


func _on_step_add_event_enemy_defeated_condition_pressed(step_id: String, condition_key: String) -> void:
	var step := get_step(step_id)
	append_awareness_condition(step, condition_key, make_event_enemy_defeated_condition(step))
	set_step(step_id, step)
	refresh_all("Step enemy defeated gate added.")


func _on_step_add_enemy_count_condition_pressed(step_id: String, condition_key: String) -> void:
	var step := get_step(step_id)
	append_awareness_condition(step, condition_key, make_enemy_count_condition(step))
	set_step(step_id, step)
	refresh_all("Step enemy count gate added.")


func _on_listener_add_item_discovered_condition_pressed(listener_id: String, condition_key: String) -> void:
	var listener_data := get_event_listener(listener_id)
	append_awareness_condition(listener_data, condition_key, make_item_discovered_condition(listener_data))
	refresh_all("Listener item discovery gate added.")


func _on_listener_add_event_enemy_defeated_condition_pressed(listener_id: String, condition_key: String) -> void:
	var listener_data := get_event_listener(listener_id)
	append_awareness_condition(listener_data, condition_key, make_event_enemy_defeated_condition(listener_data))
	refresh_all("Listener enemy defeated gate added.")


func _on_listener_add_enemy_count_condition_pressed(listener_id: String, condition_key: String) -> void:
	var listener_data := get_event_listener(listener_id)
	append_awareness_condition(listener_data, condition_key, make_enemy_count_condition(listener_data))
	refresh_all("Listener enemy count gate added.")


func _on_refresh_catalogs_pressed() -> void:
	refresh_universe_options()
	if storage != null:
		storage.ensure_storage_dir()
	if catalog != null:
		catalog.refresh()
	refresh_load_options()
	var counts := catalog.get_counts() if catalog != null else {}
	refresh_all("Catalogs refreshed. Events: " + str(counts.get("events", 0)) + ", items: " + str(counts.get("items", 0)) + ", NPCs: " + str(counts.get("npcs", 0)) + ", enemies: " + str(counts.get("enemies", 0)) + ", world objects: " + str(counts.get("world_objects", 0)) + ".")


func _on_universe_selected(index: int) -> void:
	if refreshing or universe_options == null:
		return
	if index < 0 or index >= universe_options.item_count:
		return

	var metadata = universe_options.get_item_metadata(index)
	if typeof(metadata) != TYPE_DICTIONARY:
		return

	var lane: Dictionary = normalize_universe_lane_packet(metadata)
	Globals.set_active_universe_lane(lane)

	if storage != null:
		storage.ensure_storage_dir()
	if catalog != null:
		catalog.refresh()
	refresh_load_options()
	refresh_all(get_tool_ready_status() + " Current draft remains loaded; Save writes to the selected universe lane.")


func _on_text_field_changed(edit: TextEdit, target_callable: Callable) -> void:
	if refreshing:
		return
	target_callable.call(edit.text)


func _on_commit_line_focus_exited(edit: LineEdit, target_callable: Callable) -> void:
	if refreshing:
		return
	target_callable.call(edit.text)


func _on_option_field_selected(index: int, option: OptionButton, target_callable: Callable) -> void:
	if refreshing:
		return
	target_callable.call(option.get_item_text(index))


func _on_catalog_option_field_selected(index: int, option: OptionButton, target_callable: Callable) -> void:
	if refreshing:
		return
	target_callable.call(str(option.get_item_metadata(index)))


func _on_vector_axis_changed(value: float, target_callable: Callable, axis: int) -> void:
	if refreshing:
		return
	target_callable.call(value, axis)


func _on_nested_text_changed(value: String, path: Array) -> void:
	if refreshing:
		return
	set_nested_value(path, value)
	refresh_preview()


func _on_nested_bool_changed(value: bool, path: Array) -> void:
	if refreshing:
		return
	set_nested_value(path, value)
	refresh_preview()


func _on_current_step_selected(value: String) -> void:
	if refreshing:
		return
	event_packet["current_step"] = value
	refresh_preview()


func _on_anchor_sector_changed(value: float, axis: int) -> void:
	update_vector_path(["anchor_star", "sector_pos"], value, axis, true)


func _on_anchor_local_changed(value: float, axis: int) -> void:
	update_vector_path(["anchor_star", "local_pos"], value, axis, false)


func _on_anchor_catalog_selected(anchor_id: String) -> void:
	if refreshing:
		return
	if anchor_id.strip_edges() == "":
		return
	if apply_world_seed_anchor_to_packet(anchor_id):
		refresh_all("Anchor selected: " + anchor_id + ".")


func _on_giver_owner_id_changed(value: String) -> void:
	if refreshing:
		return
	var giver: Dictionary = ensure_dict(event_packet, "giver")
	var old_id := str(giver.get("template_owner_id", giver.get("owner_id", "")))
	var clean := storage.sanitize_id(value)
	giver["owner_id"] = clean
	giver["object_id"] = clean
	giver["template_owner_id"] = clean
	var source_blueprint_id := str(giver.get("source_blueprint_id", "")).strip_edges()
	giver["blueprint_id"] = source_blueprint_id if source_blueprint_id != "" else clean
	sync_step_giver_target_ids(old_id, clean)
	refresh_preview()


func _on_giver_npc_blueprint_selected(blueprint_id: String) -> void:
	if refreshing:
		return
	var clean_blueprint_id := blueprint_id.strip_edges()
	var giver: Dictionary = ensure_dict(event_packet, "giver")
	var stable_id := get_stable_giver_id()
	if clean_blueprint_id == "":
		clear_catalog_blueprint(giver, stable_id)
		refresh_all("Giver blueprint returned to local id: " + stable_id + ".")
		return
	if stable_id == "":
		stable_id = storage.sanitize_id(clean_blueprint_id)
		giver["owner_id"] = stable_id
		giver["object_id"] = stable_id
		giver["template_owner_id"] = stable_id
	if apply_npc_blueprint_to_actor(giver, clean_blueprint_id, stable_id, "event_giver"):
		refresh_all("Giver NPC database row applied: " + clean_blueprint_id + ".")


func _on_sync_giver_identity_pressed() -> void:
	var giver: Dictionary = ensure_dict(event_packet, "giver")
	var stable_id := storage.sanitize_id(str(giver.get("template_owner_id", giver.get("owner_id", ""))))
	if stable_id == "":
		stable_id = storage.sanitize_id(str(giver.get("display_name", "story_contact_001")))
	if stable_id == "":
		stable_id = "story_contact_001"
	var old_id := str(giver.get("template_owner_id", giver.get("owner_id", "")))
	giver["owner_type"] = "npc"
	giver["owner_id"] = stable_id
	giver["object_id"] = stable_id
	giver["template_owner_id"] = stable_id
	var source_blueprint_id := str(giver.get("source_blueprint_id", "")).strip_edges()
	giver["blueprint_id"] = source_blueprint_id if source_blueprint_id != "" else stable_id
	if str(giver.get("display_name", "")).strip_edges() == "":
		giver["display_name"] = make_display_name_from_id(stable_id)
	giver["labels"] = merge_unique_labels(giver.get("labels", []), ["npc", "event_giver", "story_npc", stable_id, "authored_object"])
	sync_step_giver_target_ids(old_id, stable_id)
	refresh_all("Giver identity synced: " + stable_id)


func sync_step_giver_target_ids(old_id: String, new_id: String) -> void:
	if old_id == "" or new_id == "" or old_id == new_id:
		return
	var steps: Dictionary = event_packet.get("steps", {})
	for step_id in steps.keys():
		var step: Dictionary = steps[step_id]
		if str(step.get("target_owner_id", "")) == old_id:
			step["target_owner_id"] = new_id
			steps[step_id] = step
	event_packet["steps"] = steps


func _on_giver_offset_changed(value: float, axis: int) -> void:
	update_vector_path(["giver", "local_offset"], value, axis, false)


func _on_reward_credits_changed(value: float) -> void:
	if refreshing:
		return
	var reward: Dictionary = ensure_dict(event_packet, "reward_packet")
	reward["credits"] = int(value)
	refresh_preview()


func _on_reward_items_changed(value: String) -> void:
	if refreshing:
		return
	var reward: Dictionary = ensure_dict(event_packet, "reward_packet")
	reward["items"] = parse_reward_items(value)
	refresh_preview()


func _on_reward_catalog_item_selected(item_id: String) -> void:
	if refreshing:
		return
	var clean_item_id := item_id.strip_edges()
	if clean_item_id == "":
		return
	add_reward_item(clean_item_id, 1)
	refresh_all("Reward item added: " + clean_item_id + ".")


func _on_step_text_changed(value: String, step_id: String, key: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	step[key] = value
	refresh_preview()


func _on_step_dialogue_lines_changed(value: String, step_id: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	var lines := parse_dialogue_lines(value)
	if lines.is_empty():
		step.erase("npc_dialogue_lines")
	else:
		step["npc_dialogue_lines"] = lines
	refresh_preview()


func _on_step_completed_dialogue_lines_changed(value: String, step_id: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	var lines := parse_dialogue_lines(value)
	if lines.is_empty():
		step.erase("completed_npc_dialogue_lines")
	else:
		step["completed_npc_dialogue_lines"] = lines
	refresh_preview()


func _on_step_chat_delay_changed(value: float, step_id: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	step["npc_chat_line_delay"] = max(float(value), 0.1)
	refresh_preview()


func _on_step_chat_character_delay_changed(value: float, step_id: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	step["npc_chat_character_delay"] = max(float(value), 0.005)
	refresh_preview()


func _on_step_next_selected(value: String, step_id: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	var previous_next := str(step.get("next_step", ""))
	step["next_step"] = value
	update_victory_advance_step(step, value)
	var popup_index := get_story_popup_operation_index(step)
	if popup_index >= 0:
		var operations: Array = ensure_array(step, "on_enter")
		if popup_index < operations.size() and typeof(operations[popup_index]) == TYPE_DICTIONARY:
			var popup_op: Dictionary = operations[popup_index]
			var current_popup_next := str(popup_op.get("next_step_on_close", popup_op.get("advance_step_on_close", ""))).strip_edges()
			if current_popup_next == "" or current_popup_next == previous_next:
				popup_op["next_step_on_close"] = value
				operations[popup_index] = popup_op
				step["on_enter"] = operations
	refresh_all()


func _on_step_interaction_selected(value: String, step_id: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	if value == "":
		step.erase("interaction_type")
	else:
		step["interaction_type"] = value
	refresh_all()


func _on_step_range_changed(value: float, step_id: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	set_step_range_value(step, value)
	refresh_preview()


func _on_step_target_object_selected(value: String, step_id: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	if value == "":
		step.erase("target_object_id")
	else:
		step["target_object_id"] = value
	refresh_all()


func _on_step_requires_item_catalog_selected(item_id: String, step_id: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	var clean_item_id := item_id.strip_edges()
	if clean_item_id == "":
		step.erase("requires_item")
	else:
		step["requires_item"] = clean_item_id
	refresh_all()


func _on_step_gives_item_catalog_selected(item_id: String, step_id: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	var clean_item_id := item_id.strip_edges()
	if clean_item_id == "":
		step.erase("gives_item")
	else:
		step["gives_item"] = clean_item_id
		ensure_gives_item_uses_download_action(step_id, step)
	refresh_all()


func _on_step_use_download_action_pressed(step_id: String) -> void:
	var step := get_step(step_id)
	var action := make_download_button_action(step_id, step)
	set_primary_step_action(step_id, action)
	refresh_all("Download button action set.")


func _on_step_use_popup_continue_action_pressed(step_id: String) -> void:
	var step := get_step(step_id)
	var action := make_popup_continue_button_action(step_id, step)
	set_primary_step_action(step_id, action)
	refresh_all("Popup continue button action set.")


func _on_step_use_claim_reward_action_pressed(step_id: String) -> void:
	var step := get_step(step_id)
	var action := make_claim_reward_button_action(step_id, step)
	set_primary_step_action(step_id, action)
	refresh_all("Claim reward button action set.")


func _on_step_use_advance_action_pressed(step_id: String) -> void:
	var step := get_step(step_id)
	var action := make_advance_button_action(step_id, step)
	set_primary_step_action(step_id, action)
	refresh_all("Advance button action set.")


func _on_step_action_text_changed(value: String, step_id: String, key: String) -> void:
	if refreshing:
		return
	var action := ensure_primary_step_action(step_id)
	var clean_value := value.strip_edges()
	if clean_value == "" and ["target_object_id", "target_owner_id", "enemy_id", "next_step"].has(key):
		action.erase(key)
	else:
		action[key] = value
	if key == "next_step":
		sync_action_next_step(action, clean_value)
	set_primary_step_action(step_id, action)
	refresh_preview()


func _on_step_action_number_changed(value: float, step_id: String, key: String) -> void:
	if refreshing:
		return
	var action := ensure_primary_step_action(step_id)
	action[key] = float(value)
	set_primary_step_action(step_id, action)
	refresh_preview()


func _on_step_action_bool_changed(value: bool, step_id: String, key: String) -> void:
	if refreshing:
		return
	var action := ensure_primary_step_action(step_id)
	if value:
		action[key] = true
	else:
		action.erase(key)
	set_primary_step_action(step_id, action)
	refresh_preview()


func _on_step_action_operations_json_changed(value: String, step_id: String) -> void:
	if refreshing:
		return
	var parsed := parse_operations_json(value)
	if str(parsed.get("status", "")) != "success":
		status_label.text = "Button ops JSON error: " + str(parsed.get("reason", "invalid JSON"))
		return
	var action := ensure_primary_step_action(step_id)
	var operations: Array = parsed.get("operations", [])
	action.erase("operation")
	action.erase("popup")
	action.erase("tutorial")
	if operations.is_empty():
		action.erase("operations")
	else:
		action["operations"] = operations
		action["action_id"] = "event_operations"
	set_primary_step_action(step_id, action)
	refresh_preview()


func _on_step_actions_json_changed(value: String, step_id: String) -> void:
	if refreshing:
		return
	var parsed := parse_actions_json(value)
	if str(parsed.get("status", "")) != "success":
		status_label.text = "Actions JSON error: " + str(parsed.get("reason", "invalid JSON"))
		return
	var step := get_step(step_id)
	var actions: Array = parsed.get("actions", [])
	if actions.is_empty():
		step.erase("actions")
	else:
		step["actions"] = actions
	set_step(step_id, step)
	refresh_preview()


func _on_step_clear_actions_pressed(step_id: String) -> void:
	var step := get_step(step_id)
	step.erase("actions")
	set_step(step_id, step)
	refresh_all("Button actions cleared.")


func _on_step_enemy_selected(enemy_id: String, step_id: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	if enemy_id == "":
		step.erase("enemy_id")
	else:
		step["enemy_id"] = enemy_id
		step["target_object_id"] = enemy_id
		step["interaction_type"] = "hunt"
		step["complete_on_battle_victory"] = true
		sync_step_battle_operations(step_id, enemy_id)
	refresh_all()


func _on_step_bool_changed(value: bool, step_id: String, key: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	step[key] = value
	refresh_preview()


func _on_step_entry_message_changed(value: String, step_id: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	var on_enter: Array = ensure_array(step, "on_enter")
	if on_enter.is_empty():
		on_enter.append({"op": "start_battle", "enemy_id": str(step.get("enemy_id", "")), "entry_reason": step_id})
	var operation: Dictionary = on_enter[0]
	operation["message"] = value
	on_enter[0] = operation
	step["on_enter"] = on_enter
	refresh_preview()


func _on_step_victory_message_changed(value: String, step_id: String) -> void:
	if refreshing:
		return
	var step := get_step(step_id)
	var operations: Array = ensure_array(step, "on_battle_victory")
	if operations.is_empty():
		operations.append({"op": "write_log", "message": value})
	if typeof(operations[0]) == TYPE_DICTIONARY:
		var log_op: Dictionary = operations[0]
		log_op["op"] = "write_log"
		log_op["message"] = value
		operations[0] = log_op
	step["on_battle_victory"] = operations
	refresh_preview()


func _on_step_add_story_popup_pressed(step_id: String) -> void:
	ensure_story_popup_operation(step_id)
	var step := get_step(step_id)
	if str(step.get("interaction_type", "")).strip_edges() == "":
		step["interaction_type"] = "story_popup"
		set_step(step_id, step)
	refresh_all("Story popup added to " + step_id + ".")


func _on_step_remove_story_popup_pressed(step_id: String) -> void:
	var step := get_step(step_id)
	var operations := get_step_operation_array(step, "on_enter")
	var index := get_story_popup_operation_index(step)
	if index >= 0 and index < operations.size():
		operations.remove_at(index)
	if operations.is_empty():
		step.erase("on_enter")
	else:
		step["on_enter"] = operations
	if str(step.get("interaction_type", "")).strip_edges() == "story_popup":
		step.erase("interaction_type")
	set_step(step_id, step)
	refresh_all("Story popup removed from " + step_id + ".")


func _on_step_story_popup_text_changed(value: String, step_id: String, key: String) -> void:
	if refreshing:
		return
	var operation := ensure_story_popup_operation(step_id)
	if key == "text":
		operation.erase("bbcode")
		operation.erase("message")
	operation[key] = value
	set_story_popup_operation(step_id, operation)
	refresh_preview()


func _on_step_story_popup_images_changed(value: String, step_id: String) -> void:
	if refreshing:
		return
	var operation := ensure_story_popup_operation(step_id)
	var images := parse_story_popup_images(value)
	if images.is_empty():
		operation.erase("images")
		operation.erase("image_paths")
	else:
		operation["images"] = images
		operation.erase("image_paths")
	set_story_popup_operation(step_id, operation)
	refresh_preview()


func _on_step_story_popup_close_mode_selected(value: String, step_id: String) -> void:
	if refreshing:
		return
	var operation := ensure_story_popup_operation(step_id)
	operation["close_mode"] = normalize_story_popup_close_mode_value(value)
	set_story_popup_operation(step_id, operation)
	refresh_preview()


func _on_step_story_popup_number_changed(value: float, step_id: String, key: String) -> void:
	if refreshing:
		return
	var operation := ensure_story_popup_operation(step_id)
	operation[key] = float(value)
	set_story_popup_operation(step_id, operation)
	refresh_preview()


func _on_step_story_popup_size_changed(value: float, step_id: String, axis: String) -> void:
	if refreshing:
		return
	var operation := ensure_story_popup_operation(step_id)
	var popup_size := read_popup_size(operation)
	if axis == "x":
		popup_size.x = clamp(float(value), 360.0, 720.0)
	else:
		popup_size.y = clamp(float(value), 260.0, 540.0)
	operation["popup_size"] = {"x": popup_size.x, "y": popup_size.y}
	set_story_popup_operation(step_id, operation)
	refresh_preview()


func _on_step_story_popup_next_step_selected(value: String, step_id: String) -> void:
	if refreshing:
		return
	var operation := ensure_story_popup_operation(step_id)
	if value == "":
		operation.erase("next_step_on_close")
		operation.erase("advance_step_on_close")
	else:
		operation["next_step_on_close"] = value
		operation.erase("advance_step_on_close")
	set_story_popup_operation(step_id, operation)
	refresh_preview()


func _on_step_operations_json_changed(value: String, step_id: String, key: String) -> void:
	if refreshing:
		return
	var parsed := parse_operations_json(value)
	if str(parsed.get("status", "")) != "success":
		status_label.text = "Ops JSON error: " + str(parsed.get("reason", "invalid JSON"))
		return
	var step := get_step(step_id)
	var operations: Array = parsed.get("operations", [])
	if operations.is_empty():
		step.erase(key)
	else:
		step[key] = operations
	set_step(step_id, step)
	refresh_preview()


func _on_step_add_tutorial_hint_pressed(step_id: String) -> void:
	append_step_operation(step_id, "on_enter", {
		"op": "show_tutorial_hint",
		"title": "EVENT HELP",
		"text": "Use the Event panel to follow this story objective.",
		"target_point_id": "event_panel",
		"line_to_point_id": "event_panel",
		"duration": 5.0,
		"popup_size": {"x": 330, "y": 126},
		"popup_offset": {"x": 30, "y": -22},
		"draw_line": true
	})
	refresh_all("Tutorial hint op added.")


func _on_step_add_npc_refresh_pressed(step_id: String) -> void:
	var target_id := get_primary_npc_target_id()
	append_step_operation(step_id, "on_enter", {
		"op": "refresh_npc",
		"target_object_id": target_id,
		"talk_meta": {
			"npc_dialogue_lines": ["Context refreshed.", "This dialogue came from a JSON operation."],
			"message": "Context refreshed.",
			"npc_chat_line_delay": 1.65,
			"npc_chat_character_delay": 0.04
		}
	})
	refresh_all("NPC refresh op added.")


func _on_step_add_remove_npc_pressed(step_id: String) -> void:
	append_step_operation(step_id, "on_enter", {
		"op": "remove_npc",
		"target_object_id": get_primary_npc_target_id(),
		"allow_missing": true
	})
	refresh_all("Remove NPC op added.")


func _on_step_add_replace_npc_pressed(step_id: String) -> void:
	var old_id := get_primary_npc_target_id()
	var new_id := add_event_object("npc", storage.sanitize_id(str(event_packet.get("event_id", "story_event"))) + "_replacement_npc")
	append_step_operation(step_id, "on_enter", {
		"op": "replace_npc",
		"target_object_id": old_id,
		"replacement_object_id": new_id,
		"talk_meta": {
			"npc_dialogue_lines": ["Replacement contact online.", "The previous NPC was removed by event op."],
			"message": "Replacement contact online."
		}
	})
	refresh_all("Replace NPC op added: " + new_id)


func _on_create_npc_refresh_step_pressed(object_id: String) -> void:
	create_npc_refresh_step(object_id)
	refresh_all("Added NPC refresh step for " + object_id + ".")


func _on_create_remove_npc_step_pressed(object_id: String) -> void:
	create_remove_npc_step(object_id)
	refresh_all("Added NPC remove step for " + object_id + ".")


func _on_create_replace_npc_step_pressed(object_id: String) -> void:
	create_replace_npc_step(object_id)
	refresh_all("Added NPC replace step for " + object_id + ".")


func _on_sync_hunt_ids_pressed(step_id: String) -> void:
	var step := get_step(step_id)
	var enemy_id := str(step.get("enemy_id", step.get("target_object_id", "")))
	if enemy_id == "":
		status_label.text = "Select an enemy first."
		return
	step["target_object_id"] = enemy_id
	step["enemy_id"] = enemy_id
	step["interaction_type"] = "hunt"
	step["complete_on_battle_victory"] = true
	sync_step_battle_operations(step_id, enemy_id)
	refresh_all("Hunt ids synced.")


func _on_duplicate_step_pressed(step_id: String) -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	if not steps.has(step_id):
		return
	var new_id := make_unique_id(step_id + "_copy", steps)
	steps[new_id] = steps[step_id].duplicate(true)
	selected_kind = "step"
	selected_id = new_id
	refresh_all("Duplicated step: " + new_id)


func _on_delete_step_pressed(step_id: String) -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	if not steps.has(step_id):
		return
	steps.erase(step_id)
	for id in steps.keys():
		var step: Dictionary = steps[id]
		if str(step.get("next_step", "")) == step_id:
			step["next_step"] = ""
			steps[id] = step
	if str(event_packet.get("current_step", "")) == step_id:
		event_packet["current_step"] = str(steps.keys()[0]) if not steps.is_empty() else ""
	selected_kind = "header"
	selected_id = ""
	refresh_all("Deleted step: " + step_id)


func _on_object_id_changed(value: String, old_object_id: String) -> void:
	if refreshing:
		return
	var new_object_id := storage.sanitize_id(value)
	if new_object_id == "" or new_object_id == old_object_id:
		refresh_preview()
		return
	var objects: Dictionary = event_packet.get("event_objects", {})
	if not objects.has(old_object_id):
		return
	new_object_id = make_unique_id(new_object_id, objects)
	var object_data: Dictionary = objects[old_object_id]
	objects.erase(old_object_id)
	object_data["object_id"] = new_object_id
	if str(object_data.get("id", "")).strip_edges() != "":
		object_data["id"] = new_object_id
	if is_real_actor_type(str(object_data.get("object_type", object_data.get("owner_type", "")))):
		sync_real_object_identity(new_object_id, object_data)
	objects[new_object_id] = object_data
	event_packet["event_objects"] = objects
	replace_step_object_references(old_object_id, new_object_id)
	selected_kind = "object"
	selected_id = new_object_id
	refresh_all("Renamed object: " + new_object_id)


func _on_sync_object_identity_pressed(object_id: String) -> void:
	var object_data := get_event_object(object_id)
	if object_data.is_empty():
		return
	sync_real_object_identity(object_id, object_data)
	refresh_all("Object identity synced: " + object_id)


func _on_object_type_selected(value: String, object_id: String) -> void:
	if refreshing:
		return
	var object_data := get_event_object(object_id)
	object_data["owner_type"] = value
	object_data["object_type"] = value
	if is_real_actor_type(value):
		sync_real_object_identity(object_id, object_data)
	refresh_all()


func _on_object_npc_blueprint_selected(blueprint_id: String, object_id: String) -> void:
	if refreshing:
		return
	var clean_blueprint_id := blueprint_id.strip_edges()
	var object_data := get_event_object(object_id)
	if clean_blueprint_id == "":
		clear_catalog_blueprint(object_data, object_id)
		refresh_all("NPC blueprint returned to local id: " + object_id + ".")
		return
	if apply_npc_blueprint_to_actor(object_data, clean_blueprint_id, object_id, "event_target_npc"):
		refresh_all("NPC database row applied: " + clean_blueprint_id + ".")


func _on_object_enemy_blueprint_selected(blueprint_id: String, object_id: String) -> void:
	if refreshing:
		return
	var clean_blueprint_id := blueprint_id.strip_edges()
	var object_data := get_event_object(object_id)
	if clean_blueprint_id == "":
		clear_catalog_blueprint(object_data, object_id)
		object_data.erase("enemy_blueprint_id")
		refresh_all("Enemy blueprint returned to local id: " + object_id + ".")
		return
	if apply_enemy_blueprint_to_object(object_id, object_data, clean_blueprint_id):
		refresh_all("Enemy database row applied: " + clean_blueprint_id + ".")


func _on_object_world_seed_selected(source_object_id: String, object_id: String) -> void:
	if refreshing:
		return
	var clean_source_id := source_object_id.strip_edges()
	if clean_source_id == "":
		return
	var object_data := get_event_object(object_id)
	if apply_world_seed_object_to_event_object(object_id, object_data, clean_source_id):
		refresh_all("World seed object copied: " + clean_source_id + ".")


func _on_object_text_changed(value: String, object_id: String, key: String) -> void:
	if refreshing:
		return
	var object_data := get_event_object(object_id)
	object_data[key] = value
	if key == "main_view_icon_id" and str(object_data.get("main_view_icon_path", "")).strip_edges() == "":
		fill_standard_main_view_icon_path_if_available(object_data)
	refresh_preview()


func _on_object_icon_standard_path_pressed(object_id: String) -> void:
	var object_data := get_event_object(object_id)
	var icon_id := str(object_data.get("main_view_icon_id", "")).strip_edges()
	if icon_id == "":
		status_label.text = "Set an Icon ID first."
		return
	object_data["main_view_icon_id"] = normalize_main_view_icon_id(icon_id)
	object_data["main_view_icon_path"] = get_standard_main_view_icon_path(icon_id)
	refresh_all("Main View icon path set from icon id.")


func _on_object_dialogue_lines_changed(value: String, object_id: String) -> void:
	if refreshing:
		return
	var object_data := get_event_object(object_id)
	var lines := parse_dialogue_lines(value)
	if lines.is_empty():
		object_data.erase("dialogue_lines")
	else:
		object_data["dialogue_lines"] = lines
	refresh_preview()


func _on_object_chat_delay_changed(value: float, object_id: String) -> void:
	if refreshing:
		return
	var object_data := get_event_object(object_id)
	object_data["chat_line_delay"] = max(float(value), 0.1)
	refresh_preview()


func _on_object_chat_character_delay_changed(value: float, object_id: String) -> void:
	if refreshing:
		return
	var object_data := get_event_object(object_id)
	object_data["chat_character_delay"] = max(float(value), 0.005)
	refresh_preview()


func _on_object_bool_changed(value: bool, object_id: String, key: String) -> void:
	if refreshing:
		return
	var object_data := get_event_object(object_id)
	object_data[key] = value
	if key == "can_trade":
		object_data["trade"] = value
	refresh_preview()


func _on_object_trade_items_changed(value: String, object_id: String) -> void:
	if refreshing:
		return
	var object_data := get_event_object(object_id)
	var items := parse_trade_items(value)
	if items.is_empty():
		object_data.erase("item_list")
	else:
		object_data["item_list"] = items
	refresh_preview()


func _on_object_trade_item_catalog_selected(item_id: String, object_id: String) -> void:
	if refreshing:
		return
	var clean_item_id := item_id.strip_edges()
	if clean_item_id == "":
		return
	var object_data := get_event_object(object_id)
	var items: Array = object_data.get("item_list", []) if typeof(object_data.get("item_list", [])) == TYPE_ARRAY else []
	items.append({
		"item_id": clean_item_id,
		"amount": 1,
		"trade_role": "reward"
	})
	object_data["item_list"] = items
	refresh_all("Trade item added: " + clean_item_id + ".")


func _on_object_spawn_step_selected(value: String, object_id: String) -> void:
	if refreshing:
		return
	var object_data := get_event_object(object_id)
	if value == "":
		object_data.erase("spawn_on_step")
	else:
		object_data["spawn_on_step"] = value
		object_data["required_step"] = value
		object_data["event_step"] = value
	refresh_preview()


func _on_object_position_mode_selected(value: String, object_id: String) -> void:
	if refreshing:
		return
	var object_data := get_event_object(object_id)
	if value == "absolute":
		object_data.erase("position_mode")
		object_data.erase("place_near_anchor_star")
	else:
		object_data["position_mode"] = value
	refresh_preview()


func _on_object_sector_changed(value: float, axis: int, object_id: String) -> void:
	update_object_vector(object_id, "sector_pos", value, axis, true)


func _on_object_local_changed(value: float, axis: int, object_id: String) -> void:
	update_object_vector(object_id, "local_pos", value, axis, false)


func _on_object_sector_offset_changed(value: float, axis: int, object_id: String) -> void:
	update_object_vector(object_id, "sector_offset", value, axis, true)


func _on_object_local_offset_changed(value: float, axis: int, object_id: String) -> void:
	update_object_vector(object_id, "local_offset", value, axis, false)


func _on_object_override_number_changed(value: float, object_id: String, key: String) -> void:
	if refreshing:
		return
	var object_data := get_event_object(object_id)
	var overrides: Dictionary = object_data.get("overrides", {}) if typeof(object_data.get("overrides", {})) == TYPE_DICTIONARY else {}
	overrides[key] = int(value)
	if key == "hp":
		overrides["max_hp"] = int(value)
	object_data["overrides"] = overrides
	refresh_preview()


func _on_delete_object_pressed(object_id: String) -> void:
	var objects: Dictionary = event_packet.get("event_objects", {})
	if not objects.has(object_id):
		return
	objects.erase(object_id)
	var steps: Dictionary = event_packet.get("steps", {})
	for step_id in steps.keys():
		var step: Dictionary = steps[step_id]
		if str(step.get("target_object_id", "")) == object_id:
			step.erase("target_object_id")
		if str(step.get("enemy_id", "")) == object_id:
			step.erase("enemy_id")
		steps[step_id] = step
	selected_kind = "header"
	selected_id = ""
	refresh_all("Deleted object: " + object_id)


func _on_listener_id_changed(value: String, old_listener_id: String) -> void:
	if refreshing:
		return
	var new_listener_id := storage.sanitize_id(value)
	if new_listener_id == "" or new_listener_id == old_listener_id:
		refresh_preview()
		return
	var listeners: Dictionary = event_packet.get("event_listeners", {})
	if not listeners.has(old_listener_id):
		return
	new_listener_id = make_unique_id(new_listener_id, listeners)
	var listener_data: Dictionary = listeners[old_listener_id]
	listeners.erase(old_listener_id)
	listener_data["object_id"] = new_listener_id
	listeners[new_listener_id] = listener_data
	event_packet["event_listeners"] = listeners
	selected_kind = "listener"
	selected_id = new_listener_id
	refresh_all("Renamed listener: " + new_listener_id)


func _on_listener_display_name_changed(value: String, listener_id: String) -> void:
	if refreshing:
		return
	var listener_data := get_event_listener(listener_id)
	listener_data["display_name"] = value
	listener_data["title"] = value
	refresh_preview()


func _on_listener_text_changed(value: String, listener_id: String, key: String) -> void:
	if refreshing:
		return
	var listener_data := get_event_listener(listener_id)
	listener_data[key] = value
	refresh_preview()


func _on_listener_text_selected(value: String, listener_id: String, key: String) -> void:
	if refreshing:
		return
	var listener_data := get_event_listener(listener_id)
	listener_data[key] = value
	if key == "listener_type":
		sync_listener_type_defaults(listener_data)
		refresh_all("Listener defaults synced.")
		return
	refresh_preview()


func _on_listener_number_changed(value: float, listener_id: String, key: String) -> void:
	if refreshing:
		return
	var listener_data := get_event_listener(listener_id)
	listener_data[key] = float(value)
	refresh_preview()


func _on_listener_bool_changed(value: bool, listener_id: String, key: String) -> void:
	if refreshing:
		return
	var listener_data := get_event_listener(listener_id)
	listener_data[key] = value
	refresh_preview()


func _on_listener_sector_changed(value: float, axis: int, listener_id: String) -> void:
	update_listener_vector(listener_id, "sector_pos", value, axis, true)


func _on_listener_local_changed(value: float, axis: int, listener_id: String) -> void:
	update_listener_vector(listener_id, "local_pos", value, axis, false)


func _on_listener_sector_offset_changed(value: float, axis: int, listener_id: String) -> void:
	update_listener_vector(listener_id, "sector_offset", value, axis, true)


func _on_listener_local_offset_changed(value: float, axis: int, listener_id: String) -> void:
	update_listener_vector(listener_id, "local_offset", value, axis, false)


func _on_delete_listener_pressed(listener_id: String) -> void:
	var listeners: Dictionary = event_packet.get("event_listeners", {})
	if not listeners.has(listener_id):
		return
	listeners.erase(listener_id)
	event_packet["event_listeners"] = listeners
	selected_kind = "header"
	selected_id = ""
	refresh_all("Deleted listener: " + listener_id)


func sync_step_battle_operations(step_id: String, enemy_id: String) -> void:
	var step := get_step(step_id)
	step["interaction_type"] = "hunt"
	step["interaction_range"] = get_step_range_value(step, 180.0)
	step.erase("arrival_range")
	step["on_enter"] = [{
		"op": "start_battle",
		"enemy_id": enemy_id,
		"entry_reason": step_id,
		"message": enemy_id + " has engaged."
	}]
	var victory_ops: Array = [{
		"op": "write_log",
		"message": enemy_id + " defeated."
	}]
	var next_step := str(step.get("next_step", "")).strip_edges()
	if next_step != "":
		victory_ops.append({
			"op": "advance_step",
			"next_step": next_step
		})
	step["on_battle_victory"] = victory_ops
	var objects: Dictionary = event_packet.get("event_objects", {})
	if objects.has(enemy_id):
		var enemy: Dictionary = objects[enemy_id]
		enemy["spawn_on_step"] = step_id
		enemy["required_step"] = step_id
		enemy["event_step"] = step_id
		objects[enemy_id] = enemy


func update_victory_advance_step(step: Dictionary, next_step: String) -> void:
	var operations = step.get("on_battle_victory", [])
	if typeof(operations) != TYPE_ARRAY:
		return
	for i in range(operations.size()):
		if typeof(operations[i]) != TYPE_DICTIONARY:
			continue
		if str(operations[i].get("op", "")) == "advance_step":
			var op: Dictionary = operations[i]
			if next_step.strip_edges() == "":
				operations.remove_at(i)
			else:
				op["next_step"] = next_step
				operations[i] = op
			step["on_battle_victory"] = operations
			return
	if next_step.strip_edges() != "":
		operations.append({
			"op": "advance_step",
			"next_step": next_step
		})
		step["on_battle_victory"] = operations


func get_step(step_id: String) -> Dictionary:
	var steps: Dictionary = event_packet.get("steps", {})
	return steps.get(step_id, {})


func set_step(step_id: String, step: Dictionary) -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	steps[step_id] = step
	event_packet["steps"] = steps


func get_step_operation_array(step: Dictionary, key: String) -> Array:
	var operations: Array = []
	var raw_operations = step.get(key, [])
	if typeof(raw_operations) == TYPE_ARRAY:
		operations = raw_operations.duplicate(true)
	return operations


func get_step_actions_array(step: Dictionary) -> Array:
	var actions: Array = []
	var raw_actions = step.get("actions", [])
	if typeof(raw_actions) == TYPE_ARRAY:
		actions = raw_actions.duplicate(true)
	return actions


func get_primary_step_action(step: Dictionary) -> Dictionary:
	var actions := get_step_actions_array(step)
	for action in actions:
		if typeof(action) == TYPE_DICTIONARY:
			return action.duplicate(true)
	return {}


func ensure_primary_step_action(step_id: String) -> Dictionary:
	var step := get_step(step_id)
	var action := get_primary_step_action(step)
	if action.is_empty():
		action = make_advance_button_action(step_id, step)
		set_primary_step_action(step_id, action)
	return action


func set_primary_step_action(step_id: String, action: Dictionary) -> void:
	var step := get_step(step_id)
	var actions := get_step_actions_array(step)
	if actions.is_empty():
		actions.append(action.duplicate(true))
	else:
		actions[0] = action.duplicate(true)
	step["actions"] = actions
	set_step(step_id, step)


func button_action_step_type(interaction_type: String) -> bool:
	var clean_type := interaction_type.strip_edges().to_lower()
	return ["download", "handoff", "turn_in", "claim", "complete", "inspect", "story_popup", "tutorial_popup"].has(clean_type)


func make_step_button_id(step_id: String, label: String) -> String:
	var clean := storage.sanitize_id(step_id + "_" + label)
	return clean if clean != "" else storage.sanitize_id(step_id + "_button")


func get_default_button_range(step: Dictionary, fallback: float = 70.0) -> float:
	for key in ["range", "interaction_range", "gate_range", "target_range"]:
		if step.has(key):
			return float(step.get(key, fallback))
	return get_step_range_value(step, fallback)


func get_download_button_label(step: Dictionary) -> String:
	var interaction_type := str(step.get("interaction_type", "")).strip_edges().to_lower()
	match interaction_type:
		"handoff":
			return "ACCEPT"
		"turn_in":
			return "DELIVER"
		"npc_contact", "talk":
			return "TALK"
		"inspect":
			return "INSPECT"
		"claim", "complete":
			return "COMPLETE"
		_:
			return "DOWNLOAD"


func make_download_button_action(step_id: String, step: Dictionary) -> Dictionary:
	var label := get_download_button_label(step)
	return {
		"button_id": make_step_button_id(step_id, label),
		"label": label,
		"action_id": "download_beacon_data",
		"range": get_default_button_range(step, 70.0)
	}


func ensure_gives_item_uses_download_action(step_id: String, step: Dictionary) -> void:
	if str(step.get("gives_item", "")).strip_edges() == "":
		return
	var action := get_primary_step_action(step)
	var action_id := str(action.get("action_id", "")).strip_edges()
	if action.is_empty() or action_id == "" or action_id == "claim_event_reward":
		set_primary_step_action(step_id, make_download_button_action(step_id, step))


func make_claim_reward_button_action(step_id: String, step: Dictionary) -> Dictionary:
	var label := "CLAIM"
	if str(step.get("interaction_type", "")).strip_edges().to_lower() == "complete":
		label = "COMPLETE"
	return {
		"button_id": make_step_button_id(step_id, label),
		"label": label,
		"action_id": "claim_event_reward",
		"range": get_default_button_range(step, 70.0)
	}


func make_advance_button_action(step_id: String, step: Dictionary) -> Dictionary:
	var action := {
		"button_id": make_step_button_id(step_id, "continue"),
		"label": "CONTINUE",
		"action_id": "advance_step"
	}
	var next_step := str(step.get("next_step", "")).strip_edges()
	if next_step != "":
		action["next_step"] = next_step
	return action


func make_popup_continue_button_action(step_id: String, step: Dictionary) -> Dictionary:
	var popup_op := make_story_popup_operation("")
	popup_op["title"] = "Story Beat"
	popup_op["text"] = "[b]Story beat[/b]\n\nAdd the scene text here."
	var next_step := str(step.get("next_step", "")).strip_edges()
	if next_step != "":
		popup_op["next_step_on_close"] = next_step
	var action := {
		"button_id": make_step_button_id(step_id, "continue"),
		"label": "CONTINUE",
		"action_id": "event_operations",
		"operations": [popup_op]
	}
	if next_step != "":
		action["next_step"] = next_step
	return action


func get_action_next_step_value(action: Dictionary) -> String:
	var direct := str(action.get("next_step", "")).strip_edges()
	if direct != "":
		return direct
	var operations: Array = []
	if typeof(action.get("operations", [])) == TYPE_ARRAY:
		operations = action.get("operations", [])
	elif typeof(action.get("operation", {})) == TYPE_DICTIONARY:
		operations = [action.get("operation", {})]
	elif typeof(action.get("popup", {})) == TYPE_DICTIONARY:
		operations = [action.get("popup", {})]
	elif typeof(action.get("tutorial", {})) == TYPE_DICTIONARY:
		operations = [action.get("tutorial", {})]
	for operation in operations:
		if typeof(operation) != TYPE_DICTIONARY:
			continue
		var op: Dictionary = operation
		var op_id := str(op.get("op", op.get("action_id", op.get("type", "")))).strip_edges().to_lower()
		if op_id == "advance_step":
			var next_step := str(op.get("next_step", "")).strip_edges()
			if next_step != "":
				return next_step
		if op_id == "show_story_popup" or op_id == "story_popup" or op_id == "show_tutorial_hint" or op_id == "tutorial_hint":
			var close_next := str(op.get("next_step_on_close", op.get("advance_step_on_close", op.get("next_step_after_hint", "")))).strip_edges()
			if close_next != "":
				return close_next
	return ""


func sync_action_next_step(action: Dictionary, next_step: String) -> void:
	var clean_next := next_step.strip_edges()
	if clean_next == "":
		action.erase("next_step")
	else:
		action["next_step"] = clean_next
	var operations = action.get("operations", [])
	if typeof(operations) != TYPE_ARRAY:
		return
	for i in range(operations.size()):
		if typeof(operations[i]) != TYPE_DICTIONARY:
			continue
		var operation: Dictionary = operations[i]
		var op_id := str(operation.get("op", operation.get("action_id", operation.get("type", "")))).strip_edges().to_lower()
		if op_id == "advance_step":
			if clean_next == "":
				operation.erase("next_step")
			else:
				operation["next_step"] = clean_next
		elif op_id == "show_story_popup" or op_id == "story_popup":
			if clean_next == "":
				operation.erase("next_step_on_close")
				operation.erase("advance_step_on_close")
			else:
				operation["next_step_on_close"] = clean_next
				operation.erase("advance_step_on_close")
		elif op_id == "show_tutorial_hint" or op_id == "tutorial_hint" or op_id == "show_helper_message":
			if clean_next == "":
				operation.erase("next_step_after_hint")
				operation.erase("next_step_on_close")
				operation.erase("advance_step_on_close")
			else:
				operation["next_step_after_hint"] = clean_next
				operation.erase("next_step_on_close")
				operation.erase("advance_step_on_close")
		operations[i] = operation
	action["operations"] = operations


func append_step_operation(step_id: String, key: String, operation: Dictionary) -> void:
	var step := get_step(step_id)
	var operations: Array = get_step_operation_array(step, key)
	operations.append(operation.duplicate(true))
	step[key] = operations
	set_step(step_id, step)


func get_primary_npc_target_id() -> String:
	var selected_step: Dictionary = {}
	if selected_kind == "step":
		selected_step = get_step(selected_id)
	for key in ["target_object_id", "npc_dialogue_target_owner_id", "target_owner_id", "npc_id"]:
		var value := str(selected_step.get(key, "")).strip_edges()
		if value != "":
			return value
	var npc_ids := get_npc_object_ids()
	if not npc_ids.is_empty():
		return str(npc_ids[0])
	var giver_id := get_stable_giver_id()
	if giver_id != "":
		return giver_id
	return "story_contact_001"


func get_event_object(object_id: String) -> Dictionary:
	var objects: Dictionary = event_packet.get("event_objects", {})
	return objects.get(object_id, {})


func apply_world_seed_anchor_to_packet(anchor_id: String) -> bool:
	if catalog == null:
		return false
	var source := catalog.get_world_seed_anchor(anchor_id)
	if source.is_empty():
		status_label.text = "Anchor not found in world seed catalog: " + anchor_id
		return false

	var anchor: Dictionary = ensure_dict(event_packet, "anchor_star")
	anchor["star_id"] = str(source.get("object_id", anchor_id))
	anchor["star_name"] = str(source.get("star_name", source.get("display_name", anchor_id)))
	anchor["star_type"] = str(source.get("star_type", anchor.get("star_type", "K")))
	anchor["sector_pos"] = read_vector3_array(source.get("sector_pos", anchor.get("sector_pos", [0, 0, 0])))
	anchor["local_pos"] = read_vector3_array(source.get("local_pos", anchor.get("local_pos", [500, 500, 500])))
	anchor["brightness"] = float(source.get("brightness", anchor.get("brightness", 1.2)))
	anchor["size"] = float(source.get("size", anchor.get("size", 1.4)))
	anchor["tier"] = int(source.get("tier", anchor.get("tier", event_packet.get("tier", 1))))
	anchor["required"] = true
	anchor["create_if_missing"] = true
	anchor["catalog_source"] = "world_seed"
	anchor["catalog_id"] = anchor_id
	anchor["source_world_seed_object_id"] = anchor_id
	anchor["source_seed_id"] = str(source.get("source_seed_id", ""))
	return true


func apply_npc_blueprint_to_actor(actor_data: Dictionary, blueprint_id: String, stable_id: String, actor_label: String) -> bool:
	if catalog == null:
		return false
	var data := catalog.get_npc_blueprint(blueprint_id)
	if data.is_empty():
		status_label.text = "NPC blueprint not found: " + blueprint_id
		return false

	var clean_stable_id := storage.sanitize_id(stable_id)
	if clean_stable_id == "":
		clean_stable_id = storage.sanitize_id(blueprint_id)
	var event_id := storage.sanitize_id(str(event_packet.get("event_id", "")))
	var display_name := str(data.get("display_name", data.get("name", make_display_name_from_id(clean_stable_id)))).strip_edges()
	if display_name == "":
		display_name = make_display_name_from_id(clean_stable_id)

	actor_data["owner_type"] = "npc"
	actor_data["object_type"] = "npc"
	actor_data["owner_id"] = clean_stable_id
	actor_data["object_id"] = clean_stable_id
	actor_data["id"] = clean_stable_id
	actor_data["template_owner_id"] = clean_stable_id
	actor_data["blueprint_id"] = blueprint_id
	actor_data["source_blueprint_id"] = blueprint_id
	actor_data["catalog_source"] = "npc_blueprints"
	actor_data["catalog_id"] = blueprint_id
	actor_data["display_name"] = display_name
	actor_data["name"] = display_name
	actor_data["event_id"] = event_id
	actor_data["active_event_id"] = event_id

	for key in ["species", "role", "friendly", "can_trade", "message", "stays_after_meeting", "offer_title", "offer_text", "success_text", "repeatable", "retradable", "main_view_icon_id", "main_view_icon_path", "event_start_items", "player_state_effects", "shared_meta"]:
		if data.has(key):
			actor_data[key] = clone_catalog_value(data[key])
	for key in ["item_list", "dialogue_lines"]:
		if data.has(key):
			actor_data[key] = clone_catalog_value(data[key])
	actor_data["chat_line_delay"] = float(data.get("chat_line_delay", actor_data.get("chat_line_delay", 1.65)))
	actor_data["chat_character_delay"] = float(data.get("chat_character_delay", data.get("chat_type_delay", actor_data.get("chat_character_delay", 0.04))))
	actor_data["labels"] = merge_unique_labels(actor_data.get("labels", []), ["npc", actor_label, "story_npc", clean_stable_id, event_id, blueprint_id, "catalog_npc", "authored_object"])
	ensure_main_view_icon_fields(actor_data)
	fill_standard_main_view_icon_path_if_available(actor_data)
	return true


func apply_enemy_blueprint_to_object(object_id: String, object_data: Dictionary, blueprint_id: String) -> bool:
	if catalog == null:
		return false
	var data := catalog.get_enemy_blueprint(blueprint_id)
	if data.is_empty():
		status_label.text = "Enemy blueprint not found: " + blueprint_id
		return false

	var event_id := storage.sanitize_id(str(event_packet.get("event_id", "")))
	var display_name := str(data.get("display_name", data.get("ship_name", data.get("name", make_display_name_from_id(object_id))))).strip_edges()
	if display_name == "":
		display_name = make_display_name_from_id(object_id)

	object_data["owner_type"] = "enemy"
	object_data["object_type"] = "enemy"
	object_data["object_id"] = object_id
	object_data["id"] = object_id
	object_data["template_owner_id"] = object_id
	object_data["blueprint_id"] = blueprint_id
	object_data["enemy_blueprint_id"] = blueprint_id
	object_data["source_blueprint_id"] = blueprint_id
	object_data["catalog_source"] = "enemy_blueprints"
	object_data["catalog_id"] = blueprint_id
	object_data["display_name"] = display_name
	object_data["name"] = str(data.get("name", display_name))
	object_data["enemy_type"] = str(data.get("type", object_data.get("enemy_type", "enemy")))
	object_data["event_id"] = event_id
	object_data["active_event_id"] = event_id
	object_data["has_event"] = true
	copy_catalog_keys(data, object_data, ["main_view_icon_id", "main_view_icon_path", "shared_meta"])
	object_data["labels"] = merge_unique_labels(object_data.get("labels", []), ["enemy", "event_enemy", object_id, event_id, blueprint_id, "catalog_enemy", "authored_object"])
	ensure_main_view_icon_fields(object_data)
	fill_standard_main_view_icon_path_if_available(object_data)

	var overrides: Dictionary = {}
	overrides["ship_name"] = display_name
	copy_catalog_keys(data, overrides, ["energy_max", "primary", "secondary", "shield", "consumable", "item_stacks", "behavior_profile", "behavior_values", "reward", "battle_comment"])
	var hp := average_min_max(data, "hp", "hp_min", "hp_max", 0)
	if hp > 0:
		overrides["hp"] = hp
		overrides["max_hp"] = hp
	var attack := average_min_max(data, "attack", "attack_min", "attack_max", 0)
	if attack > 0:
		overrides["attack"] = attack
	object_data["overrides"] = overrides
	return true


func apply_world_seed_object_to_event_object(object_id: String, object_data: Dictionary, source_object_id: String) -> bool:
	if catalog == null:
		return false
	var source := catalog.get_world_seed_object(source_object_id)
	if source.is_empty():
		status_label.text = "World seed object not found: " + source_object_id
		return false

	var preserved: Dictionary = {}
	for key in ["spawn_on_step", "required_step", "event_step"]:
		if object_data.has(key):
			preserved[key] = clone_catalog_value(object_data[key])

	object_data.clear()
	for key in source.keys():
		object_data[str(key)] = clone_catalog_value(source[key])

	var event_id := storage.sanitize_id(str(event_packet.get("event_id", "")))
	object_data["object_id"] = object_id
	object_data["id"] = object_id
	object_data["event_id"] = event_id
	object_data["active_event_id"] = event_id
	object_data["has_event"] = true
	object_data["catalog_source"] = "world_seed"
	object_data["catalog_id"] = source_object_id
	object_data["source_world_seed_object_id"] = source_object_id
	object_data["source_seed_id"] = str(source.get("source_seed_id", ""))
	object_data["source_path"] = str(source.get("source_path", ""))
	for key in preserved.keys():
		object_data[key] = preserved[key]

	var owner_type := str(object_data.get("owner_type", "")).strip_edges().to_lower()
	var object_type := str(object_data.get("object_type", "")).strip_edges().to_lower()
	if owner_type == "" and object_type != "":
		object_data["owner_type"] = object_type
	elif owner_type != "" and object_type == "":
		object_data["object_type"] = owner_type
	if str(object_data.get("display_name", "")).strip_edges() == "":
		object_data["display_name"] = make_display_name_from_id(object_id)
	object_data["labels"] = merge_unique_labels(object_data.get("labels", []), ["event_object", object_id, event_id, "catalog_world_seed", "authored_object"])
	ensure_main_view_icon_fields(object_data)
	fill_standard_main_view_icon_path_if_available(object_data)
	return true


func add_reward_item(item_id: String, amount: int = 1) -> void:
	var reward: Dictionary = ensure_dict(event_packet, "reward_packet")
	var items: Array = []
	if typeof(reward.get("items", [])) == TYPE_ARRAY:
		items = reward.get("items", [])
	var clean_item_id := item_id.strip_edges()
	for i in range(items.size()):
		if typeof(items[i]) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = items[i]
		if str(item.get("item_id", "")).strip_edges() == clean_item_id:
			item["amount"] = max(int(item.get("amount", 1)) + amount, 1)
			items[i] = item
			reward["items"] = items
			return
	items.append({"item_id": clean_item_id, "amount": max(amount, 1)})
	reward["items"] = items


func clear_catalog_blueprint(object_data: Dictionary, stable_id: String) -> void:
	var clean_stable_id := storage.sanitize_id(stable_id)
	if clean_stable_id == "":
		clean_stable_id = str(object_data.get("object_id", object_data.get("owner_id", ""))).strip_edges()
	object_data["blueprint_id"] = clean_stable_id
	object_data.erase("source_blueprint_id")
	object_data.erase("catalog_source")
	object_data.erase("catalog_id")


func copy_catalog_keys(source: Dictionary, target: Dictionary, keys: Array) -> void:
	for key in keys:
		var clean_key := str(key)
		if source.has(clean_key):
			target[clean_key] = clone_catalog_value(source[clean_key])


func ensure_main_view_icon_fields(object_data: Dictionary) -> void:
	if not object_data.has("main_view_icon_id"):
		object_data["main_view_icon_id"] = ""
	if not object_data.has("main_view_icon_path"):
		object_data["main_view_icon_path"] = ""


func fill_standard_main_view_icon_path_if_available(object_data: Dictionary) -> void:
	var icon_id := str(object_data.get("main_view_icon_id", "")).strip_edges()
	if icon_id == "":
		return
	if str(object_data.get("main_view_icon_path", "")).strip_edges() != "":
		return
	var standard_path := get_standard_main_view_icon_path(icon_id)
	if ResourceLoader.exists(standard_path):
		object_data["main_view_icon_path"] = standard_path


func get_standard_main_view_icon_path(icon_id: String) -> String:
	return MAIN_VIEW_ICON_DIR.path_join(normalize_main_view_icon_id(icon_id) + ".png")


func normalize_main_view_icon_id(icon_id: String) -> String:
	return icon_id.strip_edges().to_lower().replace(" ", "_").replace("-", "_")


func clone_catalog_value(value):
	if typeof(value) == TYPE_DICTIONARY:
		var dict_value: Dictionary = value
		return dict_value.duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		var array_value: Array = value
		return array_value.duplicate(true)
	return value


func average_min_max(data: Dictionary, exact_key: String, min_key: String, max_key: String, fallback: int) -> int:
	if data.has(exact_key):
		return int(data[exact_key])
	if data.has(min_key) or data.has(max_key):
		var min_value := int(data.get(min_key, data.get(max_key, fallback)))
		var max_value := int(data.get(max_key, min_value))
		return int(round(float(min_value + max_value) * 0.5))
	return fallback


func get_event_listener(listener_id: String) -> Dictionary:
	var listeners: Dictionary = event_packet.get("event_listeners", {})
	return listeners.get(listener_id, {})


func ensure_array(parent: Dictionary, key: String) -> Array:
	if typeof(parent.get(key, [])) != TYPE_ARRAY:
		parent[key] = []
	return parent[key]


func is_real_actor_type(object_type: String) -> bool:
	var clean_type := object_type.strip_edges().to_lower()
	return clean_type == "npc" or clean_type == "enemy"


func sync_real_object_identity(object_id: String, object_data: Dictionary) -> void:
	var object_type := str(object_data.get("object_type", object_data.get("owner_type", ""))).strip_edges().to_lower()
	if not is_real_actor_type(object_type):
		return
	var source_blueprint_id := str(object_data.get("source_blueprint_id", "")).strip_edges()
	if source_blueprint_id == "" and str(object_data.get("catalog_source", "")).strip_edges() in ["npc_blueprints", "enemy_blueprints"]:
		source_blueprint_id = str(object_data.get("blueprint_id", "")).strip_edges()
	object_data["object_id"] = object_id
	object_data["id"] = object_id
	object_data["blueprint_id"] = source_blueprint_id if source_blueprint_id != "" else object_id
	object_data["template_owner_id"] = object_id
	if object_type == "npc":
		object_data["owner_type"] = "npc"
		object_data["object_type"] = "npc"
		object_data["owner_id"] = object_id
		object_data["labels"] = merge_unique_labels(object_data.get("labels", []), ["npc", "event_target_npc", "story_npc", object_id, "authored_object"])
	elif object_type == "enemy":
		object_data["owner_type"] = "enemy"
		object_data["object_type"] = "enemy"
		if source_blueprint_id != "":
			object_data["enemy_blueprint_id"] = source_blueprint_id
		object_data["labels"] = merge_unique_labels(object_data.get("labels", []), ["enemy", "event_enemy", object_id, "authored_object"])
	var event_id := storage.sanitize_id(str(event_packet.get("event_id", "")))
	object_data["event_id"] = event_id
	object_data["active_event_id"] = event_id
	if str(object_data.get("display_name", "")).strip_edges() == "":
		object_data["display_name"] = make_display_name_from_id(object_id)


func merge_unique_labels(existing_labels, new_labels: Array) -> Array:
	var labels: Array = []
	if typeof(existing_labels) == TYPE_ARRAY:
		for label in existing_labels:
			var existing_clean := str(label).strip_edges()
			if existing_clean != "" and not labels.has(existing_clean):
				labels.append(existing_clean)
	for label in new_labels:
		var new_clean := str(label).strip_edges()
		if new_clean != "" and not labels.has(new_clean):
			labels.append(new_clean)
	return labels


func replace_step_object_references(old_object_id: String, new_object_id: String) -> void:
	var steps: Dictionary = event_packet.get("steps", {})
	for step_id in steps.keys():
		var step: Dictionary = steps[step_id]
		if str(step.get("target_object_id", "")) == old_object_id:
			step["target_object_id"] = new_object_id
		if str(step.get("enemy_id", "")) == old_object_id:
			step["enemy_id"] = new_object_id
		update_operation_object_references(step.get("on_enter", []), old_object_id, new_object_id)
		update_operation_object_references(step.get("on_battle_victory", []), old_object_id, new_object_id)
		steps[step_id] = step
	event_packet["steps"] = steps


func update_operation_object_references(operations, old_object_id: String, new_object_id: String) -> void:
	if typeof(operations) != TYPE_ARRAY:
		return
	for i in range(operations.size()):
		if typeof(operations[i]) != TYPE_DICTIONARY:
			continue
		var operation: Dictionary = operations[i]
		for key in ["enemy_id", "target_object_id", "object_id"]:
			if str(operation.get(key, "")) == old_object_id:
				operation[key] = new_object_id
		operations[i] = operation


func set_nested_value(path: Array, value) -> void:
	if path.size() < 2:
		return
	var parent: Dictionary = event_packet
	for i in range(path.size() - 1):
		var key := str(path[i])
		if typeof(parent.get(key, {})) != TYPE_DICTIONARY:
			parent[key] = {}
		parent = parent[key]
	parent[str(path[path.size() - 1])] = value


func update_vector_path(path: Array, value: float, axis: int, integer_values: bool) -> void:
	if refreshing:
		return
	var current = get_nested_value(path, [0, 0, 0])
	var vec := read_vector3_array(current)
	vec[axis] = int(value) if integer_values else float(value)
	set_nested_value(path, vec)
	refresh_preview()


func get_nested_value(path: Array, fallback):
	var parent: Dictionary = event_packet
	for i in range(path.size()):
		var key := str(path[i])
		if not parent.has(key):
			return fallback
		if i == path.size() - 1:
			return parent[key]
		if typeof(parent[key]) != TYPE_DICTIONARY:
			return fallback
		parent = parent[key]
	return fallback


func update_object_vector(object_id: String, key: String, value: float, axis: int, integer_values: bool) -> void:
	if refreshing:
		return
	var object_data := get_event_object(object_id)
	var vec := read_vector3_array(object_data.get(key, [0, 0, 0]))
	vec[axis] = int(value) if integer_values else float(value)
	object_data[key] = vec
	refresh_preview()


func update_listener_vector(listener_id: String, key: String, value: float, axis: int, integer_values: bool) -> void:
	if refreshing:
		return
	var listener_data := get_event_listener(listener_id)
	var vec := read_vector3_array(listener_data.get(key, [0, 0, 0]))
	vec[axis] = int(value) if integer_values else float(value)
	listener_data[key] = vec
	refresh_preview()


func read_vector3_array(value) -> Array:
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return [value[0], value[1], value[2]]
	if typeof(value) == TYPE_DICTIONARY:
		return [value.get("x", 0), value.get("y", 0), value.get("z", 0)]
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Vector3i:
		return [value.x, value.y, value.z]
	return [0, 0, 0]


func reward_items_to_text(items) -> String:
	if typeof(items) != TYPE_ARRAY:
		return ""
	var lines: Array = []
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		lines.append(str(item.get("item_id", "")) + ":" + str(item.get("amount", 1)))
	return join_strings(lines, "\n")


func parse_reward_items(text: String) -> Array:
	var items: Array = []
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line == "":
			continue
		var parts := line.split(":")
		var item_id := str(parts[0]).strip_edges()
		var amount := 1
		if parts.size() > 1:
			amount = int(parts[1])
		if item_id != "":
			items.append({"item_id": item_id, "amount": max(amount, 1)})
	return items


func trade_items_to_text(items) -> String:
	if typeof(items) != TYPE_ARRAY:
		return ""
	var lines: Array = []
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var role := str(item.get("trade_role", item.get("role", "reward"))).strip_edges()
		var amount := int(item.get("amount", item.get("count", 1)))
		lines.append(str(item.get("item_id", "")) + ":" + str(amount) + ":" + role)
	return join_strings(lines, "\n")


func parse_trade_items(text: String) -> Array:
	var items: Array = []
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line == "":
			continue
		var parts := line.split(":")
		var item_id := str(parts[0]).strip_edges()
		var amount := 1
		var role := "reward"
		if parts.size() > 1:
			amount = int(parts[1])
		if parts.size() > 2:
			role = str(parts[2]).strip_edges()
		if role == "":
			role = "reward"
		if item_id != "":
			items.append({
				"item_id": item_id,
				"amount": max(amount, 1),
				"trade_role": role
			})
	return items


func get_start_battle_message(step: Dictionary) -> String:
	var operations = step.get("on_enter", [])
	if typeof(operations) == TYPE_ARRAY:
		for operation in operations:
			if typeof(operation) == TYPE_DICTIONARY and str(operation.get("op", "")) == "start_battle":
				return str(operation.get("message", ""))
	return ""


func get_victory_message(step: Dictionary) -> String:
	var operations = step.get("on_battle_victory", [])
	if typeof(operations) == TYPE_ARRAY:
		for operation in operations:
			if typeof(operation) == TYPE_DICTIONARY and str(operation.get("op", "")) == "write_log":
				return str(operation.get("message", ""))
	return ""


func sync_event_ids() -> void:
	var event_id := str(event_packet.get("event_id", ""))
	var objects: Dictionary = event_packet.get("event_objects", {})
	for object_id in objects.keys():
		var object_data: Dictionary = objects[object_id]
		object_data["event_id"] = event_id
		object_data["active_event_id"] = event_id
		objects[object_id] = object_data
	var listeners: Dictionary = event_packet.get("event_listeners", {})
	for listener_id in listeners.keys():
		var listener_data: Dictionary = listeners[listener_id]
		listener_data["trigger_event_id"] = event_id
		listener_data["labels"] = merge_unique_labels(listener_data.get("labels", []), [event_id, "event_listener", "authored_object"])
		listeners[listener_id] = listener_data
	event_packet["event_objects"] = objects
	event_packet["event_listeners"] = listeners
