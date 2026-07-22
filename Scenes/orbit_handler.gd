extends Node2D

const SaveManagerScript = preload("res://save/SaveManager.gd")
const LocalAIServerManagerScript = preload("res://local_ai/local_ai_server_manager.gd")
const LocalAITalkerScript = preload("res://local_ai/local_ai_talker.gd")
const WidgetSpecUiScript = preload("res://UI/Widget_spec_UI.gd")
const OrbitItemOperationBridgeScript = preload("res://Scenes/OrbitItemOperationBridge.gd")
const MAIN_MODE_SCENE_PATH := "res://Scenes/main_mode.tscn"
const ORBIT_SNAPSHOT_SCHEMA := "orbit_snapshot_save_v1"
const ORBIT_OPERATIONS_SCHEMA := "orbit_operations_v1"
const ORBIT_SURVEY_OPERATION_ID := "survey_orbit"
const ORBIT_PLANET_SCAN_OPERATION_ID := "scan_planet_orbit"
const ORBIT_RESOURCE_ROVER_ITEM_ID := "planetary_resource_rover"
const ORBIT_RECOVERY_LAUNCHER_ITEM_ID := "planet_recovery_launcher"
const ORBIT_RESOURCE_ROVER_OPERATION_ID := "planetary_rover_explore"
const ORBIT_RECOVERY_LAUNCH_OPERATION_ID := "planet_recovery_launch"
const MAX_ORBIT_GLOBE_MARKERS := 32
const MAX_ORBIT_MARKER_COORDINATE_DEPTH := 16
const ORBIT_STORY_POPUP_READ_HISTORY_MAX := 120
const DEBUG_PREFIX := "[ORBIT_AI]"

@onready var exit_button: Button = $ExitButton
@onready var send_button: Button = $SendButton
@onready var survey_orbit_button: Button = $OrbitTargetPanel/SurveyOrbitButton
@onready var scan_planet_button: Button = $OrbitTargetPanel/ScanPlanetButton
@onready var text_log: RichTextLabel = $TextLog
@onready var write_log: TextEdit = $WriteLog
@onready var status_label: Label = $StatusLabel
@onready var latest_reply_label: Label = $LatestReplyLabel
@onready var orbit_globe_view: Control = $OrbitGlobeView
@onready var orbit_target_title: Label = $OrbitTargetPanel/OrbitTargetTitle
@onready var orbit_target_meta: Label = $OrbitTargetPanel/OrbitTargetMeta
@onready var orbit_target_description: Label = $OrbitTargetPanel/OrbitTargetDescription
@onready var orbit_result_label: Label = $OrbitTargetPanel/OrbitResultLabel

var save_manager: SaveManager = SaveManagerScript.new()
var local_ai_server_manager = LocalAIServerManagerScript.new()
var local_ai_talker = LocalAITalkerScript.new()
var orbit_item_operation_bridge = OrbitItemOperationBridgeScript.new()
var orbit_context: Dictionary = {}
var orbit_snapshot: Dictionary = {}
var orbit_target_body: Dictionary = {}
var last_orbit_survey_result: Dictionary = {}
var last_planet_scan_result: Dictionary = {}
var last_orbit_operation_result: Dictionary = {}
var pending_orbit_analysis := false
var pending_orbit_analysis_operation_id := ""
var pending_orbit_analysis_result: Dictionary = {}
var exit_in_progress := false
var selected_orbit_marker: Dictionary = {}
var orbit_marker_popup: Panel = null
var orbit_marker_popup_title: Label = null
var orbit_marker_popup_body: Label = null
var orbit_marker_popup_action_button: Button = null
var orbit_marker_popup_close_button: Button = null
var orbit_story_popup_root: Control = null
var orbit_story_popup_scrim: ColorRect = null
var orbit_story_popup_panel: ColorRect = null
var orbit_story_popup_title: Label = null
var orbit_story_popup_text: RichTextLabel = null
var orbit_story_popup_progress_label: Label = null
var orbit_story_popup_close_button: Button = null
var orbit_story_popup_queue: Array = []
var orbit_story_popup_chain_marker: Dictionary = {}
var active_orbit_story_popup_packet: Dictionary = {}
var orbit_story_popup_sequence := 0
var orbit_story_popup_chain_index := 0
var orbit_story_popup_chain_total := 0


func _ready() -> void:
	debug_print("ready")
	add_child(save_manager)
	claim_orbit_context()
	setup_exit_button()
	setup_send_button()
	setup_write_log()
	setup_orbit_widget_theme()
	setup_orbit_marker_popup()
	setup_orbit_story_popup_overlay()
	setup_visual_debug_surface()
	setup_orbit_globe_view()
	setup_orbit_operations_ui()
	setup_local_ai_server_manager()
	setup_local_ai_talker()
	append_text_log("SYSTEM", "Orbit operations ready.")
	append_text_log("SYSTEM", "Survey orbit to reveal authored planet-linked contacts.")


func claim_orbit_context() -> void:
	Globals.orbit_pending = false
	Globals.orbit_mode = true

	if typeof(Globals.orbit_context) == TYPE_DICTIONARY:
		orbit_context = Globals.orbit_context.duplicate(true)
	else:
		orbit_context = {}

	var snapshot = orbit_context.get("snapshot", orbit_context.get("universe_snapshot", {}))
	if typeof(snapshot) == TYPE_DICTIONARY:
		orbit_snapshot = snapshot.duplicate(true)
	else:
		orbit_snapshot = {}

	orbit_target_body = resolve_orbit_target_body()
	if not orbit_target_body.is_empty():
		orbit_snapshot["orbit_target_body"] = make_orbit_body_save_slice(orbit_target_body)

	debug_print("snapshot claimed | summary=" + str(build_snapshot_summary(orbit_snapshot)))


func setup_exit_button() -> void:
	if exit_button == null:
		return
	if not exit_button.pressed.is_connected(_on_exit_button_pressed):
		exit_button.pressed.connect(_on_exit_button_pressed)


func setup_send_button() -> void:
	if send_button == null:
		return
	if not send_button.pressed.is_connected(_on_send_button_pressed):
		send_button.pressed.connect(_on_send_button_pressed)


func setup_orbit_operations_ui() -> void:
	if survey_orbit_button != null:
		if not survey_orbit_button.pressed.is_connected(_on_survey_orbit_button_pressed):
			survey_orbit_button.pressed.connect(_on_survey_orbit_button_pressed)
	if scan_planet_button != null:
		if not scan_planet_button.pressed.is_connected(_on_scan_planet_button_pressed):
			scan_planet_button.pressed.connect(_on_scan_planet_button_pressed)
	update_orbit_operations_ui()


func setup_write_log() -> void:
	if write_log == null:
		return

	write_log.placeholder_text = "Ask AMI about this orbit."
	if not write_log.gui_input.is_connected(_on_write_log_gui_input):
		write_log.gui_input.connect(_on_write_log_gui_input)


func setup_visual_debug_surface() -> void:
	if status_label != null:
		status_label.text = "Orbit operations initializing."
	if latest_reply_label != null:
		latest_reply_label.text = "AMI analysis will appear here."


func setup_orbit_widget_theme() -> void:
	WidgetSpecUiScript.apply_orbit_widget_theme(self)


func setup_orbit_marker_popup() -> void:
	if orbit_marker_popup != null:
		return

	orbit_marker_popup = Panel.new()
	orbit_marker_popup.name = "OrbitMarkerPopup"
	orbit_marker_popup.position = Vector2(526.0, 410.0)
	orbit_marker_popup.size = Vector2(250.0, 138.0)
	orbit_marker_popup.visible = false
	orbit_marker_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(orbit_marker_popup)
	WidgetSpecUiScript.apply_widget_panel_theme(orbit_marker_popup, "primary")

	orbit_marker_popup_title = Label.new()
	orbit_marker_popup_title.name = "MarkerTitle"
	orbit_marker_popup_title.position = Vector2(10.0, 8.0)
	orbit_marker_popup_title.size = Vector2(198.0, 24.0)
	orbit_marker_popup_title.clip_text = true
	orbit_marker_popup.add_child(orbit_marker_popup_title)
	WidgetSpecUiScript.apply_widget_label_theme(orbit_marker_popup_title, "title", 14)

	orbit_marker_popup_close_button = Button.new()
	orbit_marker_popup_close_button.name = "CloseButton"
	orbit_marker_popup_close_button.text = "X"
	orbit_marker_popup_close_button.position = Vector2(214.0, 8.0)
	orbit_marker_popup_close_button.size = Vector2(28.0, 24.0)
	orbit_marker_popup.add_child(orbit_marker_popup_close_button)
	WidgetSpecUiScript.apply_widget_button_theme(orbit_marker_popup_close_button, "secondary")
	if not orbit_marker_popup_close_button.pressed.is_connected(_on_orbit_marker_popup_close_pressed):
		orbit_marker_popup_close_button.pressed.connect(_on_orbit_marker_popup_close_pressed)

	orbit_marker_popup_body = Label.new()
	orbit_marker_popup_body.name = "MarkerBody"
	orbit_marker_popup_body.position = Vector2(10.0, 34.0)
	orbit_marker_popup_body.size = Vector2(230.0, 58.0)
	orbit_marker_popup_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	orbit_marker_popup_body.clip_text = true
	orbit_marker_popup.add_child(orbit_marker_popup_body)
	WidgetSpecUiScript.apply_widget_label_theme(orbit_marker_popup_body, "body", 11)

	orbit_marker_popup_action_button = Button.new()
	orbit_marker_popup_action_button.name = "ActionButton"
	orbit_marker_popup_action_button.position = Vector2(10.0, 100.0)
	orbit_marker_popup_action_button.size = Vector2(230.0, 28.0)
	orbit_marker_popup_action_button.text = "NO ORBIT TOOL"
	orbit_marker_popup_action_button.disabled = true
	orbit_marker_popup.add_child(orbit_marker_popup_action_button)
	WidgetSpecUiScript.apply_widget_button_theme(orbit_marker_popup_action_button, "primary")
	if not orbit_marker_popup_action_button.pressed.is_connected(_on_orbit_marker_action_pressed):
		orbit_marker_popup_action_button.pressed.connect(_on_orbit_marker_action_pressed)


func setup_orbit_story_popup_overlay() -> void:
	if orbit_story_popup_root != null:
		return

	orbit_story_popup_root = Control.new()
	orbit_story_popup_root.name = "OrbitStoryPopupRoot"
	orbit_story_popup_root.position = Vector2.ZERO
	orbit_story_popup_root.size = get_orbit_story_popup_overlay_size()
	orbit_story_popup_root.visible = false
	orbit_story_popup_root.mouse_filter = Control.MOUSE_FILTER_STOP
	orbit_story_popup_root.z_index = 1200
	add_child(orbit_story_popup_root)

	orbit_story_popup_scrim = ColorRect.new()
	orbit_story_popup_scrim.name = "OrbitStoryPopupScrim"
	orbit_story_popup_scrim.position = Vector2.ZERO
	orbit_story_popup_scrim.size = orbit_story_popup_root.size
	orbit_story_popup_scrim.color = Color(0.0, 0.015, 0.04, 0.20)
	orbit_story_popup_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	orbit_story_popup_scrim.z_index = 1
	orbit_story_popup_root.add_child(orbit_story_popup_scrim)

	orbit_story_popup_panel = ColorRect.new()
	orbit_story_popup_panel.name = "OrbitStoryPopupPanel"
	orbit_story_popup_panel.size = Vector2(560.0, 430.0)
	orbit_story_popup_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	orbit_story_popup_panel.clip_contents = true
	orbit_story_popup_panel.z_index = 10
	orbit_story_popup_root.add_child(orbit_story_popup_panel)

	orbit_story_popup_title = Label.new()
	orbit_story_popup_title.name = "OrbitStoryPopupTitle"
	orbit_story_popup_title.position = Vector2(16.0, 12.0)
	orbit_story_popup_title.size = Vector2(420.0, 24.0)
	orbit_story_popup_title.clip_text = true
	orbit_story_popup_title.z_index = 35
	orbit_story_popup_panel.add_child(orbit_story_popup_title)
	WidgetSpecUiScript.apply_widget_label_theme(orbit_story_popup_title, "accent", 16)

	orbit_story_popup_progress_label = Label.new()
	orbit_story_popup_progress_label.name = "OrbitStoryPopupProgress"
	orbit_story_popup_progress_label.position = Vector2(438.0, 14.0)
	orbit_story_popup_progress_label.size = Vector2(92.0, 20.0)
	orbit_story_popup_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	orbit_story_popup_progress_label.z_index = 35
	orbit_story_popup_panel.add_child(orbit_story_popup_progress_label)
	WidgetSpecUiScript.apply_widget_label_theme(orbit_story_popup_progress_label, "muted", 11)

	orbit_story_popup_text = RichTextLabel.new()
	orbit_story_popup_text.name = "OrbitStoryPopupText"
	orbit_story_popup_text.position = Vector2(16.0, 50.0)
	orbit_story_popup_text.size = Vector2(528.0, 324.0)
	orbit_story_popup_text.bbcode_enabled = true
	orbit_story_popup_text.scroll_active = true
	orbit_story_popup_text.scroll_following = false
	orbit_story_popup_text.fit_content = false
	orbit_story_popup_text.mouse_filter = Control.MOUSE_FILTER_STOP
	orbit_story_popup_text.z_index = 35
	orbit_story_popup_panel.add_child(orbit_story_popup_text)
	WidgetSpecUiScript.apply_widget_rich_text_theme(orbit_story_popup_text)

	orbit_story_popup_close_button = Button.new()
	orbit_story_popup_close_button.name = "OrbitStoryPopupClose"
	orbit_story_popup_close_button.text = "CLOSE"
	orbit_story_popup_close_button.size = Vector2(100.0, 28.0)
	orbit_story_popup_close_button.z_index = 40
	orbit_story_popup_panel.add_child(orbit_story_popup_close_button)
	WidgetSpecUiScript.apply_widget_button_theme(orbit_story_popup_close_button, "secondary")
	if not orbit_story_popup_close_button.pressed.is_connected(_on_orbit_story_popup_close_pressed):
		orbit_story_popup_close_button.pressed.connect(_on_orbit_story_popup_close_pressed)

	resize_orbit_story_popup_overlay(Vector2(560.0, 430.0))


func get_orbit_story_popup_overlay_size() -> Vector2:
	var viewport := get_viewport()
	if viewport != null:
		var visible_rect := viewport.get_visible_rect()
		if visible_rect.size.x > 0.0 and visible_rect.size.y > 0.0:
			return visible_rect.size
	if Globals.has_method("get_popup_overlay_size"):
		return Globals.get_popup_overlay_size()
	return Vector2(1280.0, 768.0)


func resize_orbit_story_popup_overlay(popup_size: Vector2) -> void:
	if orbit_story_popup_root == null:
		return

	var overlay_size := get_orbit_story_popup_overlay_size()
	orbit_story_popup_root.position = Vector2.ZERO
	orbit_story_popup_root.size = overlay_size

	if orbit_story_popup_scrim != null:
		orbit_story_popup_scrim.position = Vector2.ZERO
		orbit_story_popup_scrim.size = overlay_size

	if orbit_story_popup_panel == null:
		return

	orbit_story_popup_panel.size = popup_size
	orbit_story_popup_panel.position = ((overlay_size - popup_size) / 2.0).floor()
	Globals.apply_popup_panel_theme(
		orbit_story_popup_panel,
		popup_size,
		Color(0.34, 0.88, 1.0, 0.86),
		"orbit_story_popup_aurora_background",
		"orbit_story_popup_theme_frame"
	)

	if orbit_story_popup_title != null:
		orbit_story_popup_title.position = Vector2(16.0, 12.0)
		orbit_story_popup_title.size = Vector2(max(popup_size.x - 140.0, 180.0), 24.0)
	if orbit_story_popup_progress_label != null:
		orbit_story_popup_progress_label.position = Vector2(max(popup_size.x - 122.0, 120.0), 14.0)
		orbit_story_popup_progress_label.size = Vector2(92.0, 20.0)
	if orbit_story_popup_text != null:
		orbit_story_popup_text.position = Vector2(16.0, 50.0)
		orbit_story_popup_text.size = Vector2(max(popup_size.x - 32.0, 180.0), max(popup_size.y - 104.0, 90.0))
	if orbit_story_popup_close_button != null:
		orbit_story_popup_close_button.position = Vector2(popup_size.x - 116.0, popup_size.y - 38.0)


func setup_orbit_globe_view() -> void:
	if orbit_globe_view != null:
		var selected_callable := Callable(self, "_on_orbit_globe_marker_selected")
		if orbit_globe_view.has_signal("marker_selected") and not orbit_globe_view.is_connected("marker_selected", selected_callable):
			orbit_globe_view.connect("marker_selected", selected_callable)
		var cleared_callable := Callable(self, "_on_orbit_globe_marker_selection_cleared")
		if orbit_globe_view.has_signal("marker_selection_cleared") and not orbit_globe_view.is_connected("marker_selection_cleared", cleared_callable):
			orbit_globe_view.connect("marker_selection_cleared", cleared_callable)
	sync_orbit_globe_view()


func sync_orbit_globe_view() -> void:
	if orbit_globe_view == null:
		return
	if orbit_globe_view.has_method("set_target_body"):
		orbit_globe_view.call("set_target_body", orbit_target_body)
	if orbit_globe_view.has_method("set_scan_result"):
		orbit_globe_view.call("set_scan_result", last_planet_scan_result)
	if orbit_globe_view.has_method("set_survey_result"):
		orbit_globe_view.call("set_survey_result", last_orbit_survey_result)
	if orbit_globe_view.has_method("set_scan_markers"):
		orbit_globe_view.call("set_scan_markers", build_orbit_globe_markers())


func build_orbit_globe_markers() -> Array:
	var result := get_active_planet_scan_result_for_globe()
	if result.is_empty():
		return []

	var markers := []
	var discoveries := SharedObjectMeta.read_array(result.get("discoveries", []))
	var resource_actions := get_planet_resource_tool_actions(result)
	var has_resource_marker := false

	for i in range(discoveries.size()):
		var raw_discovery = discoveries[i]
		if typeof(raw_discovery) != TYPE_DICTIONARY:
			continue
		var discovery: Dictionary = raw_discovery
		var marker := make_orbit_globe_discovery_marker(discovery, i, result, resource_actions)
		if marker.is_empty():
			continue
		if is_resource_marker_category(str(marker.get("category", ""))):
			has_resource_marker = true
		markers.append(marker)

	append_orbit_globe_event_listener_markers(markers, result)
	append_orbit_globe_item_action_markers(markers, result, has_resource_marker)
	return cap_orbit_globe_markers(dedupe_orbit_globe_markers(markers))


func get_active_planet_scan_result_for_globe() -> Dictionary:
	if not last_planet_scan_result.is_empty():
		return last_planet_scan_result.duplicate(true)

	var planet_id := get_orbit_body_id(orbit_target_body)
	var state = orbit_snapshot.get("orbit_operations", {})
	if typeof(state) == TYPE_DICTIONARY:
		var planet_scans = state.get("planet_scans", {})
		if typeof(planet_scans) == TYPE_DICTIONARY and planet_id != "":
			var saved_scan = planet_scans.get(planet_id, {})
			if typeof(saved_scan) == TYPE_DICTIONARY and not saved_scan.is_empty():
				return saved_scan.duplicate(true)

	var found_discoveries := SharedObjectMeta.read_array(orbit_target_body.get("orbit_discoveries_found", []))
	var found_interactions := SharedObjectMeta.read_array(orbit_target_body.get("orbit_interactions_available", []))
	var found_listeners := SharedObjectMeta.read_array(orbit_target_body.get("orbit_event_listeners_found", []))
	if found_discoveries.is_empty() and found_interactions.is_empty() and found_listeners.is_empty():
		return {}

	return {
		"ok": true,
		"operation_id": ORBIT_PLANET_SCAN_OPERATION_ID,
		"planet_id": planet_id,
		"planet_name": get_orbit_body_display_name(orbit_target_body),
		"discoveries": found_discoveries,
		"interactions": found_interactions,
		"event_listeners": found_listeners
	}


func make_orbit_globe_discovery_marker(discovery: Dictionary, index: int, result: Dictionary, resource_actions: Array) -> Dictionary:
	var entry_id := str(discovery.get("id", "discovery_" + str(index))).strip_edges()
	if entry_id == "":
		entry_id = "discovery_" + str(index)

	var title := str(discovery.get("title", discovery.get("display_name", entry_id))).strip_edges()
	if title == "":
		title = entry_id.replace("_", " ").capitalize()

	var marker := {
		"id": "discovery_" + entry_id,
		"kind": "discovery",
		"entry_id": entry_id,
		"title": title,
		"summary": str(discovery.get("summary", discovery.get("description", ""))).strip_edges(),
		"category": str(discovery.get("category", "discovery")).strip_edges(),
		"source_key": str(discovery.get("source_key", "")),
		"source_planet_id": str(result.get("planet_id", "")),
		"source_planet_name": str(result.get("planet_name", "")),
		"origin_packet": discovery.duplicate(true)
	}

	var actions := find_orbit_marker_actions_for_discovery(discovery, result, resource_actions)
	if not actions.is_empty():
		marker["actions"] = actions
		marker["primary_action"] = actions[0]

	var story_popups := collect_orbit_story_popup_packets_for_marker(discovery, marker, result)
	if not story_popups.is_empty():
		marker["story_popups"] = story_popups

	apply_orbit_marker_coordinates(marker, discovery, index)
	return marker


func find_orbit_marker_actions_for_discovery(discovery: Dictionary, result: Dictionary, resource_actions: Array) -> Array:
	var actions := []
	var discovery_id := str(discovery.get("id", "")).strip_edges()
	var marker_id := "discovery_" + discovery_id
	if is_resource_marker_category(str(discovery.get("category", ""))):
		for resource_action in resource_actions:
			append_orbit_marker_action_if_available(actions, marker_id, resource_action)

	var interactions := SharedObjectMeta.read_array(result.get("interactions", []))
	for raw_interaction in interactions:
		if typeof(raw_interaction) != TYPE_DICTIONARY:
			continue
		var interaction: Dictionary = raw_interaction
		if should_link_interaction_to_discovery(interaction, discovery):
			append_orbit_marker_action_if_available(actions, marker_id, interaction)
		if actions.size() >= 3:
			break

	return actions


func should_link_interaction_to_discovery(interaction: Dictionary, discovery: Dictionary) -> bool:
	var discovery_id := str(discovery.get("id", "")).strip_edges()
	var interaction_id := str(interaction.get("id", "")).strip_edges()
	if discovery_id != "" and (interaction_id == discovery_id or interaction_id == "inspect_" + discovery_id):
		return true

	for key in ["site_id", "resource_site_id", "building_id"]:
		if discovery_id != "" and str(interaction.get(key, "")).strip_edges() == discovery_id:
			return true

	var source_key := str(discovery.get("source_key", "")).strip_edges()
	var interaction_source := str(interaction.get("source_key", "")).strip_edges()
	if source_key != "" and source_key == interaction_source and interaction_source != "planetary_resource_tools":
		return true

	return false


func append_orbit_globe_event_listener_markers(markers: Array, result: Dictionary) -> void:
	var listeners := SharedObjectMeta.read_array(result.get("event_listeners", []))
	for i in range(listeners.size()):
		var raw_listener = listeners[i]
		if typeof(raw_listener) != TYPE_DICTIONARY:
			continue
		var listener: Dictionary = raw_listener
		if not bool(listener.get("visible_in_orbit", true)):
			continue

		var queue_id := str(listener.get("queue_id", listener.get("id", "event_listener_" + str(i)))).strip_edges()
		if queue_id == "":
			queue_id = "event_listener_" + str(i)
		var event_id := str(listener.get("event_id", listener.get("trigger_event_id", queue_id))).strip_edges()
		var title := str(listener.get("title", listener.get("display_name", listener.get("source_entry_title", event_id)))).strip_edges()
		if title == "":
			title = "Event Signal"
		var summary := str(listener.get("summary", listener.get("description", ""))).strip_edges()
		if summary == "":
			summary = "Event " + event_id + " can be " + str(listener.get("orbit_event_action", "discover_event")).replace("_", " ") + " from orbit."

		var marker := {
			"id": "event_listener_" + queue_id,
			"kind": "event_listener",
			"entry_id": queue_id,
			"title": title,
			"summary": summary,
			"category": "event_signal",
			"source_key": str(listener.get("source_key", "")),
			"source_planet_id": str(result.get("planet_id", "")),
			"source_planet_name": str(result.get("planet_name", "")),
			"event_listener": listener.duplicate(true)
		}
		var story_popups := collect_orbit_story_popup_packets_for_marker(listener, marker, result)
		if not story_popups.is_empty():
			marker["story_popups"] = story_popups
		apply_orbit_marker_coordinates(marker, listener, 200 + i)
		markers.append(marker)


func append_orbit_globe_item_action_markers(markers: Array, result: Dictionary, resource_marker_exists: bool) -> void:
	var interactions := SharedObjectMeta.read_array(result.get("interactions", []))
	for i in range(interactions.size()):
		var raw_interaction = interactions[i]
		if typeof(raw_interaction) != TYPE_DICTIONARY:
			continue
		var interaction: Dictionary = raw_interaction
		var requires := SharedObjectMeta.read_array(interaction.get("requires_orbit_items", []))
		if requires.is_empty():
			continue
		if resource_marker_exists and str(interaction.get("source_key", "")) == "planetary_resource_tools":
			continue

		var interaction_id := str(interaction.get("id", "orbit_action_" + str(i))).strip_edges()
		if interaction_id == "":
			interaction_id = "orbit_action_" + str(i)
		var marker_id := "interaction_" + interaction_id
		if orbit_item_operation_bridge != null and not orbit_item_operation_bridge.should_offer_action(
			orbit_snapshot,
			get_orbit_body_id(orbit_target_body),
			marker_id,
			interaction
		):
			continue
		var label := str(interaction.get("label", interaction_id.replace("_", " ").capitalize())).strip_edges()
		var marker := {
			"id": marker_id,
			"kind": "interaction",
			"entry_id": interaction_id,
			"title": label,
			"summary": str(interaction.get("summary", interaction.get("description", ""))).strip_edges(),
			"category": "orbit_action",
			"source_key": str(interaction.get("source_key", "")),
			"source_planet_id": str(result.get("planet_id", "")),
			"source_planet_name": str(result.get("planet_name", "")),
			"actions": [interaction.duplicate(true)],
			"primary_action": interaction.duplicate(true),
			"origin_packet": interaction.duplicate(true)
		}
		var story_popups := collect_orbit_story_popup_packets_for_marker(interaction, marker, result)
		if not story_popups.is_empty():
			marker["story_popups"] = story_popups
		apply_orbit_marker_coordinates(marker, interaction, 400 + i)
		markers.append(marker)


func get_planet_resource_tool_actions(result: Dictionary) -> Array:
	var output := []
	var interactions := SharedObjectMeta.read_array(result.get("interactions", []))
	for raw_interaction in interactions:
		if typeof(raw_interaction) != TYPE_DICTIONARY:
			continue
		var interaction: Dictionary = raw_interaction
		var interaction_id := str(interaction.get("id", "")).strip_edges()
		if interaction_id in [ORBIT_RESOURCE_ROVER_OPERATION_ID, ORBIT_RECOVERY_LAUNCH_OPERATION_ID] or str(interaction.get("source_key", "")) == "planetary_resource_tools":
			append_marker_action_if_missing(output, interaction)
	return output


func append_marker_action_if_missing(actions: Array, raw_action: Dictionary) -> void:
	var action := raw_action.duplicate(true)
	var action_id := str(action.get("id", "")).strip_edges()
	if action_id == "":
		action_id = str(action.get("label", "orbit_action")).strip_edges()
	for existing in actions:
		if typeof(existing) == TYPE_DICTIONARY and str(existing.get("id", "")) == action_id:
			return
	actions.append(action)


func append_orbit_marker_action_if_available(actions: Array, marker_id: String, raw_action: Dictionary) -> void:
	if orbit_item_operation_bridge != null and not orbit_item_operation_bridge.should_offer_action(
		orbit_snapshot,
		get_orbit_body_id(orbit_target_body),
		marker_id,
		raw_action
	):
		return
	append_marker_action_if_missing(actions, raw_action)


func is_resource_marker_category(category: String) -> bool:
	var clean_category := category.strip_edges().to_lower()
	return clean_category in ["resource", "planet_resource", "resource_site", "mining_claim"]


func apply_orbit_marker_coordinates(marker: Dictionary, source: Dictionary, index: int) -> void:
	if copy_orbit_marker_coordinates(marker, source):
		return
	assign_stable_orbit_marker_coordinates(marker, index)


func copy_orbit_marker_coordinates(marker: Dictionary, source: Dictionary, depth: int = 0) -> bool:
	if depth >= MAX_ORBIT_MARKER_COORDINATE_DEPTH:
		return false

	var latitude_keys := ["latitude_deg", "latitude", "lat", "surface_latitude", "planet_latitude", "orbit_latitude"]
	var longitude_keys := ["longitude_deg", "longitude", "lon", "lng", "surface_longitude", "planet_longitude", "orbit_longitude"]
	var has_latitude := false
	var has_longitude := false
	var latitude := 0.0
	var longitude := 0.0

	for key in latitude_keys:
		if source.has(key) and str(source.get(key, "")).strip_edges() != "":
			latitude = clamp(float(source.get(key)), -82.0, 82.0)
			has_latitude = true
			break

	for key in longitude_keys:
		if source.has(key) and str(source.get(key, "")).strip_edges() != "":
			longitude = wrapf(float(source.get(key)), -180.0, 180.0)
			has_longitude = true
			break

	if has_latitude and has_longitude:
		marker["latitude_deg"] = latitude
		marker["longitude_deg"] = longitude
		return true

	for nested_key in ["orbit_marker", "surface_position", "planet_position", "coordinates"]:
		if not source.has(nested_key):
			continue
		var nested = source.get(nested_key)
		if typeof(nested) == TYPE_DICTIONARY and not nested.is_empty() and copy_orbit_marker_coordinates(marker, nested, depth + 1):
			return true

	return false


func assign_stable_orbit_marker_coordinates(marker: Dictionary, index: int) -> void:
	var marker_id := str(marker.get("id", "marker_" + str(index)))
	var seed := stable_orbit_marker_hash(marker_id + ":" + str(index))
	var latitude_bucket := seed % 11800
	var longitude_bucket := (int(seed / 17) + (index * 997)) % 32000
	marker["latitude_deg"] = -59.0 + (float(latitude_bucket) / 100.0)
	marker["longitude_deg"] = -160.0 + (float(longitude_bucket) / 100.0)


func stable_orbit_marker_hash(text: String) -> int:
	var hash := 5381
	for i in range(text.length()):
		hash = int(fposmod(float((hash * 33) + text.unicode_at(i)), 1000003.0))
	return hash


func dedupe_orbit_globe_markers(markers: Array) -> Array:
	var output := []
	var seen := {}
	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		var marker_packet: Dictionary = marker
		var marker_id := str(marker_packet.get("id", "")).strip_edges()
		if marker_id == "":
			continue
		if seen.has(marker_id):
			continue
		seen[marker_id] = true
		output.append(marker_packet)
	return output


func cap_orbit_globe_markers(markers: Array) -> Array:
	var output := []
	for marker in markers:
		if output.size() >= MAX_ORBIT_GLOBE_MARKERS:
			break
		output.append(marker)
	return output


func collect_orbit_story_popup_packets_for_marker(source: Dictionary, marker: Dictionary, result: Dictionary) -> Array:
	var output := []
	var context := {
		"marker_id": str(marker.get("id", "")),
		"marker_title": get_orbit_marker_title(marker),
		"marker_category": str(marker.get("category", "")),
		"source_planet_id": str(result.get("planet_id", "")),
		"source_planet_name": str(result.get("planet_name", "")),
		"source_entry_id": str(source.get("id", source.get("queue_id", marker.get("entry_id", "")))),
		"source_key": str(source.get("source_key", marker.get("source_key", "")))
	}

	for key in [
		"orbit_story_popups",
		"orbit_lore_popups",
		"orbit_story_popup_chain",
		"orbit_lore_popup_chain",
		"story_popup_chain",
		"lore_popup_chain",
		"story_popups",
		"lore_popups",
		"story_entries",
		"lore_entries"
	]:
		append_orbit_story_popup_packets(output, source.get(key, []), context, key)

	for key in [
		"orbit_story_popup",
		"orbit_lore_popup",
		"story_popup",
		"lore_popup"
	]:
		append_orbit_story_popup_packets(output, source.get(key, {}), context, key)

	for key in [
		"orbit_story_text",
		"orbit_lore_text",
		"story_text",
		"lore_text"
	]:
		var text := str(source.get(key, "")).strip_edges()
		if text == "":
			continue
		append_orbit_story_popup_packets(output, {
			"id": key,
			"title": get_orbit_marker_title(marker),
			"text": text
		}, context, key)

	var operation_id := str(source.get("op", source.get("action_id", source.get("interaction_type", "")))).strip_edges().to_lower()
	if operation_id in ["show_story_popup", "story_popup"]:
		append_orbit_story_popup_packets(output, source, context, "story_popup_operation")

	return dedupe_orbit_story_popup_packets(output)


func append_orbit_story_popup_packets(output: Array, raw_value, context: Dictionary, source_key: String) -> void:
	if raw_value == null:
		return

	if typeof(raw_value) == TYPE_STRING or typeof(raw_value) == TYPE_STRING_NAME:
		var text := str(raw_value).strip_edges()
		if text != "":
			var packet := normalize_orbit_story_popup_packet({"text": text}, context, output.size(), source_key)
			if not packet.is_empty():
				output.append(packet)
		return

	if typeof(raw_value) == TYPE_ARRAY:
		for item in raw_value:
			append_orbit_story_popup_packets(output, item, context, source_key)
		return

	if typeof(raw_value) != TYPE_DICTIONARY:
		return

	var raw_packet: Dictionary = raw_value
	if raw_packet.has("popup") and typeof(raw_packet.get("popup")) == TYPE_DICTIONARY and not orbit_story_popup_dict_has_text(raw_packet):
		var popup_packet: Dictionary = raw_packet.get("popup", {}).duplicate(true)
		for key in ["id", "popup_id", "story_id", "lore_id", "event_id", "event_step", "story_popup_token", "popup_token"]:
			if raw_packet.has(key) and not popup_packet.has(key):
				popup_packet[key] = raw_packet[key]
		append_orbit_story_popup_packets(output, popup_packet, context, source_key)
		return

	if raw_packet.has("chain") and typeof(raw_packet.get("chain")) == TYPE_ARRAY and not orbit_story_popup_dict_has_text(raw_packet):
		append_orbit_story_popup_packets(output, raw_packet.get("chain", []), context, source_key)
		return
	if raw_packet.has("pages") and typeof(raw_packet.get("pages")) == TYPE_ARRAY and not orbit_story_popup_dict_has_text(raw_packet):
		append_orbit_story_popup_packets(output, raw_packet.get("pages", []), context, source_key)
		return

	var packet := normalize_orbit_story_popup_packet(raw_packet, context, output.size(), source_key)
	if not packet.is_empty():
		output.append(packet)


func orbit_story_popup_dict_has_text(packet: Dictionary) -> bool:
	for key in ["bbcode", "text", "message", "body", "story_text", "lore_text"]:
		if str(packet.get(key, "")).strip_edges() != "":
			return true
	return false


func normalize_orbit_story_popup_packet(raw_packet: Dictionary, context: Dictionary, index: int, source_key: String) -> Dictionary:
	var packet := raw_packet.duplicate(true)
	if packet.has("popup") and typeof(packet.get("popup")) == TYPE_DICTIONARY:
		var popup_packet: Dictionary = packet.get("popup", {}).duplicate(true)
		for key in packet.keys():
			if not popup_packet.has(key) and key != "popup":
				popup_packet[key] = packet[key]
		packet = popup_packet

	var story_text := str(packet.get("bbcode", packet.get("text", packet.get("message", packet.get("body", packet.get("story_text", packet.get("lore_text", ""))))))).strip_edges()
	if story_text == "":
		return {}

	var popup_id := str(packet.get("id", packet.get("popup_id", packet.get("story_id", packet.get("lore_id", ""))))).strip_edges()
	if popup_id == "":
		popup_id = source_key + "_" + str(index)

	var marker_title := str(context.get("marker_title", "Orbit Story")).strip_edges()
	var title := str(packet.get("title", packet.get("display_name", marker_title))).strip_edges()
	if title == "":
		title = marker_title

	var token := str(packet.get("story_popup_token", packet.get("popup_token", ""))).strip_edges()
	if token == "":
		token = str(context.get("marker_id", "marker")) + "_" + popup_id

	return {
		"id": popup_id,
		"title": title,
		"text": story_text,
		"bbcode": story_text,
		"close_label": str(packet.get("close_label", "CLOSE")),
		"story_popup_token": sanitize_orbit_story_popup_token_part(token),
		"event_id": str(packet.get("event_id", packet.get("source_event_id", ""))),
		"event_step": str(packet.get("event_step", packet.get("source_event_step", ""))),
		"source_key": source_key,
		"source_planet_id": str(context.get("source_planet_id", "")),
		"source_planet_name": str(context.get("source_planet_name", "")),
		"source_entry_id": str(context.get("source_entry_id", "")),
		"marker_id": str(context.get("marker_id", "")),
		"marker_title": marker_title,
		"marker_category": str(context.get("marker_category", "")),
		"read_once": bool(packet.get("read_once", packet.get("show_once", packet.get("once", false)))),
		"size": packet.get("size", packet.get("popup_size", Vector2(560.0, 430.0)))
	}


func dedupe_orbit_story_popup_packets(packets: Array) -> Array:
	var output := []
	var seen := {}
	for raw_packet in packets:
		if typeof(raw_packet) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = raw_packet
		var token := str(packet.get("story_popup_token", packet.get("id", ""))).strip_edges()
		if token == "":
			continue
		if seen.has(token):
			continue
		seen[token] = true
		output.append(packet)
	return output


func sanitize_orbit_story_popup_token_part(value: String) -> String:
	var text := value.strip_edges().to_lower()
	if text == "":
		return "popup"
	var out := ""
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		var code := ch.unicode_at(0)
		var is_digit := code >= 48 and code <= 57
		var is_lower := code >= 97 and code <= 122
		if is_digit or is_lower:
			out += ch
		else:
			out += "_"
	while out.find("__") >= 0:
		out = out.replace("__", "_")
	while out.begins_with("_") and out.length() > 0:
		out = out.substr(1)
	while out.ends_with("_") and out.length() > 0:
		out = out.substr(0, out.length() - 1)
	return out if out != "" else "popup"


func update_orbit_operations_ui() -> void:
	var has_target := not orbit_target_body.is_empty()
	var target_name := get_orbit_body_display_name(orbit_target_body)
	if orbit_target_title != null:
		orbit_target_title.text = target_name if has_target else "No orbital body selected"
	if orbit_target_meta != null:
		orbit_target_meta.text = build_orbit_target_meta_text(orbit_target_body) if has_target else "Orbit needs a planet in the current universe snapshot."
	if orbit_target_description != null:
		orbit_target_description.text = build_orbit_target_description(orbit_target_body) if has_target else "Return to Main Mode and enter Orbit from a universe with planets."
	if survey_orbit_button != null:
		survey_orbit_button.disabled = not has_target
	if scan_planet_button != null:
		scan_planet_button.disabled = not has_target
	if orbit_result_label != null:
		if last_orbit_operation_result.is_empty():
			orbit_result_label.text = "No orbit operation run yet."
		else:
			orbit_result_label.text = build_orbit_operation_result_text(last_orbit_operation_result)
	sync_orbit_globe_view()


func setup_local_ai_server_manager() -> void:
	if local_ai_server_manager == null:
		return

	local_ai_server_manager.name = "LocalAIServerManager"
	if local_ai_server_manager.get_parent() == null:
		add_child(local_ai_server_manager)

	if not local_ai_server_manager.status_changed.is_connected(_on_local_ai_server_status_changed):
		local_ai_server_manager.status_changed.connect(_on_local_ai_server_status_changed)

	local_ai_server_manager.begin_startup("orbit_boot")


func setup_local_ai_talker() -> void:
	if local_ai_talker == null:
		return

	local_ai_talker.name = "LocalAITalker"
	if local_ai_talker.get_parent() == null:
		add_child(local_ai_talker)

	if not local_ai_talker.reply_received.is_connected(_on_local_ai_reply_received):
		local_ai_talker.reply_received.connect(_on_local_ai_reply_received)
	if not local_ai_talker.request_failed.is_connected(_on_local_ai_request_failed):
		local_ai_talker.request_failed.connect(_on_local_ai_request_failed)
	if not local_ai_talker.status_changed.is_connected(_on_local_ai_status_changed):
		local_ai_talker.status_changed.connect(_on_local_ai_status_changed)

	debug_print("talker connections | reply=" + str(local_ai_talker.reply_received.is_connected(_on_local_ai_reply_received)) + " failed=" + str(local_ai_talker.request_failed.is_connected(_on_local_ai_request_failed)) + " status=" + str(local_ai_talker.status_changed.is_connected(_on_local_ai_status_changed)))
	local_ai_talker.setup()


func _on_write_log_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var is_enter := key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER
	if not is_enter or key_event.shift_pressed:
		return

	write_log.accept_event()
	_on_send_button_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if orbit_story_popup_root == null or not orbit_story_popup_root.visible:
		return
	if event == null:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_orbit_story_popup_close_pressed()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_down"):
		scroll_orbit_story_popup_text(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_up"):
		scroll_orbit_story_popup_text(-1)
		get_viewport().set_input_as_handled()
		return


func _on_send_button_pressed() -> void:
	if write_log == null:
		return

	var message := write_log.text.strip_edges()
	if message == "":
		debug_print("send skipped | empty message")
		append_text_log("SYSTEM", "Write a message before sending.")
		return

	write_log.text = ""
	append_text_log("YOU", message)
	set_latest_reply_text("Sending: " + message)
	debug_print("send requested | chars=" + str(message.length()))

	if local_ai_talker == null:
		debug_print("send failed | local_ai_talker missing")
		append_text_log("SYSTEM", "Local AI talker is missing.")
		return

	var accepted := local_ai_talker.send_message(message, {
		"scene": "Orbit",
		"local_ai_role": "shipboard orbit analyst",
		"target_body": make_orbit_body_save_slice(orbit_target_body),
		"snapshot_summary": build_snapshot_summary(orbit_snapshot)
	})
	debug_print("send dispatched | accepted=" + str(accepted))


func _on_orbit_globe_marker_selected(marker: Dictionary) -> void:
	selected_orbit_marker = marker.duplicate(true)
	if orbit_marker_popup != null:
		orbit_marker_popup.visible = false
	var story_chain := get_pending_orbit_story_popup_chain(selected_orbit_marker)
	if not story_chain.is_empty():
		start_orbit_story_popup_chain(selected_orbit_marker, story_chain)
	else:
		show_orbit_marker_popup(selected_orbit_marker)
	append_text_log("PLANET_MARKER", get_orbit_marker_title(marker))


func _on_orbit_globe_marker_selection_cleared() -> void:
	selected_orbit_marker = {}
	if orbit_marker_popup != null:
		orbit_marker_popup.visible = false


func _on_orbit_marker_popup_close_pressed() -> void:
	selected_orbit_marker = {}
	if orbit_marker_popup != null:
		orbit_marker_popup.visible = false
	if orbit_globe_view != null and orbit_globe_view.has_method("clear_selected_marker"):
		orbit_globe_view.call("clear_selected_marker")


func _on_orbit_story_popup_close_pressed() -> void:
	close_active_orbit_story_popup("button")


func start_orbit_story_popup_chain(marker: Dictionary, story_chain: Array) -> void:
	if story_chain.is_empty():
		show_orbit_marker_popup(marker)
		return

	if orbit_story_popup_root == null:
		setup_orbit_story_popup_overlay()
	if orbit_story_popup_root == null:
		show_orbit_marker_popup(marker)
		return

	orbit_story_popup_chain_marker = marker.duplicate(true)
	orbit_story_popup_queue = story_chain.duplicate(true)
	active_orbit_story_popup_packet = {}
	orbit_story_popup_chain_index = 0
	orbit_story_popup_chain_total = story_chain.size()
	if orbit_marker_popup != null:
		orbit_marker_popup.visible = false
	Globals.set_popup_input_lock("story_popup", true)
	show_next_orbit_story_popup()


func show_next_orbit_story_popup() -> void:
	if orbit_story_popup_queue.is_empty():
		finish_orbit_story_popup_chain()
		return

	var packet = orbit_story_popup_queue.pop_front()
	if typeof(packet) != TYPE_DICTIONARY:
		show_next_orbit_story_popup()
		return

	active_orbit_story_popup_packet = packet.duplicate(true)
	orbit_story_popup_sequence += 1
	orbit_story_popup_chain_index += 1
	var popup_size := read_orbit_story_popup_size(active_orbit_story_popup_packet.get("size", Vector2(560.0, 430.0)))
	resize_orbit_story_popup_overlay(popup_size)

	if orbit_story_popup_title != null:
		orbit_story_popup_title.text = str(active_orbit_story_popup_packet.get("title", "ORBIT STORY")).to_upper()
	if orbit_story_popup_text != null:
		orbit_story_popup_text.text = str(active_orbit_story_popup_packet.get("bbcode", active_orbit_story_popup_packet.get("text", "")))
		orbit_story_popup_text.scroll_to_line(0)
	if orbit_story_popup_progress_label != null:
		orbit_story_popup_progress_label.text = str(orbit_story_popup_chain_index) + " / " + str(max(orbit_story_popup_chain_total, orbit_story_popup_chain_index))
	if orbit_story_popup_close_button != null:
		orbit_story_popup_close_button.text = str(active_orbit_story_popup_packet.get("close_label", "CLOSE"))
		orbit_story_popup_close_button.grab_focus()

	if orbit_story_popup_root != null:
		orbit_story_popup_root.visible = true
		orbit_story_popup_root.move_to_front()

	if Globals.has_method("record_story_popup_text"):
		Globals.record_story_popup_text(
			str(active_orbit_story_popup_packet.get("text", active_orbit_story_popup_packet.get("bbcode", ""))),
			str(active_orbit_story_popup_packet.get("title", "ORBIT STORY")),
			{
				"event_id": str(active_orbit_story_popup_packet.get("event_id", "")),
				"event_step": str(active_orbit_story_popup_packet.get("event_step", "")),
				"story_popup_token": str(active_orbit_story_popup_packet.get("story_popup_token", ""))
			}
		)


func close_active_orbit_story_popup(close_source: String = "button") -> void:
	if active_orbit_story_popup_packet.is_empty():
		finish_orbit_story_popup_chain()
		return

	record_orbit_story_popup_read(active_orbit_story_popup_packet, orbit_story_popup_chain_marker, close_source)
	active_orbit_story_popup_packet = {}
	show_next_orbit_story_popup()


func finish_orbit_story_popup_chain() -> void:
	orbit_story_popup_queue = []
	orbit_story_popup_chain_index = 0
	orbit_story_popup_chain_total = 0
	active_orbit_story_popup_packet = {}
	if orbit_story_popup_root != null:
		orbit_story_popup_root.visible = false
	Globals.set_popup_input_lock("story_popup", false)

	var marker := orbit_story_popup_chain_marker.duplicate(true)
	orbit_story_popup_chain_marker = {}
	if marker.is_empty():
		return
	if not get_orbit_marker_primary_action(marker).is_empty():
		selected_orbit_marker = marker.duplicate(true)
		show_orbit_marker_popup(selected_orbit_marker)


func get_pending_orbit_story_popup_chain(marker: Dictionary) -> Array:
	var raw_chain = marker.get("story_popups", [])
	if typeof(raw_chain) != TYPE_ARRAY:
		return []

	var output := []
	for raw_packet in raw_chain:
		if typeof(raw_packet) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = raw_packet
		if bool(packet.get("read_once", false)) and is_orbit_story_popup_read(packet, marker):
			continue
		output.append(packet.duplicate(true))
	return output


func scroll_orbit_story_popup_text(direction: int) -> void:
	if orbit_story_popup_text == null:
		return
	var scrollbar := orbit_story_popup_text.get_v_scroll_bar()
	if scrollbar == null:
		return
	scrollbar.value = clamp(scrollbar.value + float(direction * 42), scrollbar.min_value, scrollbar.max_value)


func read_orbit_story_popup_size(value) -> Vector2:
	var fallback := Vector2(560.0, 430.0)
	var size_value := fallback
	if value is Vector2:
		size_value = value
	elif typeof(value) == TYPE_DICTIONARY:
		size_value = Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	elif typeof(value) == TYPE_ARRAY and value.size() >= 2:
		size_value = Vector2(float(value[0]), float(value[1]))
	size_value.x = clamp(size_value.x, 360.0, 720.0)
	size_value.y = clamp(size_value.y, 260.0, 540.0)
	return size_value


func is_orbit_story_popup_read(packet: Dictionary, marker: Dictionary) -> bool:
	var state := ensure_orbit_operations_state()
	var reads = state.get("orbit_story_popup_reads", {})
	if typeof(reads) != TYPE_DICTIONARY:
		return false
	return reads.has(get_orbit_story_popup_read_id(packet, marker))


func record_orbit_story_popup_read(packet: Dictionary, marker: Dictionary, close_source: String) -> void:
	var state := ensure_orbit_operations_state()
	var reads = state.get("orbit_story_popup_reads", {})
	if typeof(reads) != TYPE_DICTIONARY:
		reads = {}
	var history = state.get("orbit_story_popup_read_history", [])
	if typeof(history) != TYPE_ARRAY:
		history = []

	var read_id := get_orbit_story_popup_read_id(packet, marker)
	var now_unix := int(Time.get_unix_time_from_system())
	var now_text := get_datetime_text()
	var previous = reads.get(read_id, {})
	var previous_count := 0
	var first_read_at_unix := now_unix
	var first_read_at_text := now_text
	if typeof(previous) == TYPE_DICTIONARY:
		previous_count = int(previous.get("read_count", 0))
		first_read_at_unix = int(previous.get("first_read_at_unix", now_unix))
		first_read_at_text = str(previous.get("first_read_at_text", now_text))

	var read_packet := {
		"read_id": read_id,
		"story_popup_token": str(packet.get("story_popup_token", "")),
		"popup_id": str(packet.get("id", "")),
		"title": str(packet.get("title", "")),
		"target_planet_id": get_orbit_body_id(orbit_target_body),
		"target_planet_name": get_orbit_body_display_name(orbit_target_body),
		"marker_id": str(marker.get("id", packet.get("marker_id", ""))),
		"marker_title": get_orbit_marker_title(marker),
		"marker_category": str(marker.get("category", packet.get("marker_category", ""))),
		"source_key": str(packet.get("source_key", "")),
		"source_entry_id": str(packet.get("source_entry_id", "")),
		"event_id": str(packet.get("event_id", "")),
		"event_step": str(packet.get("event_step", "")),
		"read_count": previous_count + 1,
		"first_read_at_unix": first_read_at_unix,
		"first_read_at_text": first_read_at_text,
		"last_read_at_unix": now_unix,
		"last_read_at_text": now_text,
		"close_source": close_source,
		"source": "Orbit.story_popup_chain"
	}
	reads[read_id] = read_packet
	history.append(read_packet.duplicate(true))
	while history.size() > ORBIT_STORY_POPUP_READ_HISTORY_MAX:
		history.pop_front()

	state["orbit_story_popup_reads"] = reads
	state["orbit_story_popup_read_history"] = history
	orbit_snapshot["orbit_operations"] = state


func get_orbit_story_popup_read_id(packet: Dictionary, marker: Dictionary) -> String:
	var planet_id := get_orbit_body_id(orbit_target_body)
	var marker_id := str(marker.get("id", packet.get("marker_id", "marker"))).strip_edges()
	var token := str(packet.get("story_popup_token", packet.get("id", ""))).strip_edges()
	if token == "":
		token = str(packet.get("title", "orbit_story_popup")).strip_edges()
	return planet_id + "|" + marker_id + "|" + token


func _on_orbit_marker_action_pressed() -> void:
	if selected_orbit_marker.is_empty():
		append_text_log("ORBIT_TOOL", "No planet marker is selected.")
		return

	var action := get_orbit_marker_primary_action(selected_orbit_marker)
	if action.is_empty():
		append_text_log("ORBIT_TOOL", "Selected marker has no orbit item action attached.")
		return

	var action_label := str(action.get("label", action.get("id", "Orbit tool"))).strip_edges()
	var marker_title := get_orbit_marker_title(selected_orbit_marker)
	var request := record_orbit_marker_tool_request(selected_orbit_marker, action)
	var result := orbit_item_operation_bridge.execute(
		orbit_snapshot,
		orbit_target_body,
		selected_orbit_marker,
		action
	)
	update_orbit_marker_tool_request(str(request.get("request_id", "")), result)

	last_orbit_operation_result = result.duplicate(true)
	selected_orbit_marker["queued_action_status"] = str(result.get("status", "blocked"))
	var summary := str(result.get("summary_line", result.get("reason", action_label + " could not be completed.")))

	if bool(result.get("ok", false)):
		var save_result := save_orbit_item_operation_truth(str(result.get("operation_id", "orbit_item_action")))
		result["save_result"] = save_result
		last_orbit_operation_result = result.duplicate(true)
		append_text_log("ORBIT_TOOL", summary)
		set_latest_reply_text("ORBIT TOOL> " + summary)
		refresh_selected_orbit_marker_after_item_operation()
	else:
		append_text_log("ORBIT_TOOL_BLOCKED", summary)
		set_latest_reply_text("ORBIT TOOL> " + summary)
		show_orbit_marker_popup(selected_orbit_marker)

	update_orbit_operations_ui()
	debug_print(
		"item operation | action=" + str(action.get("id", ""))
		+ " marker=" + str(selected_orbit_marker.get("id", ""))
		+ " status=" + str(result.get("status", ""))
		+ " consumed=" + str(result.get("consumed_items", {}))
		+ " granted=" + str(result.get("granted_items", {}))
	)


func show_orbit_marker_popup(marker: Dictionary) -> void:
	if orbit_marker_popup == null:
		setup_orbit_marker_popup()
	if orbit_marker_popup == null:
		return

	if orbit_marker_popup_title != null:
		orbit_marker_popup_title.text = truncate_orbit_text(get_orbit_marker_title(marker), 34)
	if orbit_marker_popup_body != null:
		orbit_marker_popup_body.text = build_orbit_marker_popup_text(marker)

	var action := get_orbit_marker_primary_action(marker)
	if orbit_marker_popup_action_button != null:
		if action.is_empty():
			orbit_marker_popup_action_button.disabled = true
			orbit_marker_popup_action_button.text = "NO ORBIT TOOL"
		else:
			orbit_marker_popup_action_button.disabled = false
			var label := str(action.get("label", "USE ORBIT TOOL")).strip_edges()
			orbit_marker_popup_action_button.text = truncate_orbit_text(label.to_upper(), 26)

	orbit_marker_popup.visible = true
	orbit_marker_popup.move_to_front()


func build_orbit_marker_popup_text(marker: Dictionary) -> String:
	var lines := []
	var category := str(marker.get("category", "")).strip_edges()
	if category != "":
		lines.append(category.replace("_", " ").capitalize())

	var summary := str(marker.get("summary", "")).strip_edges()
	if summary != "":
		lines.append(truncate_orbit_text(summary, 112))

	var action := get_orbit_marker_primary_action(marker)
	if action.is_empty():
		lines.append("No orbit item action attached yet.")
	else:
		var item_text := format_orbit_item_ids(SharedObjectMeta.read_array(action.get("requires_orbit_items", [])))
		if item_text != "":
			lines.append("Needs: " + item_text)
		var consume_text := format_orbit_item_ids(SharedObjectMeta.read_array(action.get("consume_orbit_items", [])))
		if consume_text != "":
			lines.append("Consumes: " + consume_text)

	var status := str(marker.get("queued_action_status", "")).strip_edges()
	if status != "":
		lines.append("Status: " + status.replace("_", " "))

	return "\n".join(lines)


func get_orbit_marker_title(marker: Dictionary) -> String:
	for key in ["title", "label", "display_name", "entry_id", "id"]:
		var value := str(marker.get(key, "")).strip_edges()
		if value != "":
			return value
	return "Planet Marker"


func get_orbit_marker_primary_action(marker: Dictionary) -> Dictionary:
	var primary = marker.get("primary_action", {})
	if typeof(primary) == TYPE_DICTIONARY and not primary.is_empty():
		return primary.duplicate(true)

	var actions = marker.get("actions", [])
	if typeof(actions) == TYPE_ARRAY:
		for raw_action in actions:
			if typeof(raw_action) == TYPE_DICTIONARY:
				var action: Dictionary = raw_action
				return action.duplicate(true)
	return {}


func record_orbit_marker_tool_request(marker: Dictionary, action: Dictionary) -> Dictionary:
	var state := ensure_orbit_operations_state()
	var requests = state.get("planet_item_action_requests", [])
	if typeof(requests) != TYPE_ARRAY:
		requests = []

	var created_at_unix := int(Time.get_unix_time_from_system())
	var created_at_text := get_datetime_text()
	var action_id := str(action.get("id", action.get("operation_id", "orbit_item_action"))).strip_edges()
	var marker_id := str(marker.get("id", marker.get("entry_id", "planet_marker"))).strip_edges()
	var request := {
		"request_id": action_id + "_" + marker_id + "_" + str(created_at_unix) + "_" + str(requests.size()),
		"status": "processing_inventory_bridge",
		"operation_id": action_id,
		"operation_label": str(action.get("label", action_id)),
		"operation_runtime_status": str(action.get("operation_runtime_status", "metadata_ready")),
		"planetary_resource_action": str(action.get("planetary_resource_action", "")),
		"target_planet_id": get_orbit_body_id(orbit_target_body),
		"target_planet_name": get_orbit_body_display_name(orbit_target_body),
		"marker_id": marker_id,
		"marker_title": get_orbit_marker_title(marker),
		"marker_category": str(marker.get("category", "")),
		"requires_orbit_items": SharedObjectMeta.read_array(action.get("requires_orbit_items", [])).duplicate(true),
		"consume_orbit_items": SharedObjectMeta.read_array(action.get("consume_orbit_items", [])).duplicate(true),
		"consume_on_success": bool(action.get("consume_on_success", false)),
		"created_at_unix": created_at_unix,
		"created_at_text": created_at_text,
		"source": "Orbit.marker_popup"
	}
	requests.append(request)
	while requests.size() > 30:
		requests.pop_front()

	state["planet_item_action_requests"] = requests
	orbit_snapshot["orbit_operations"] = state
	return request


func update_orbit_marker_tool_request(request_id: String, result: Dictionary) -> void:
	var clean_request_id := request_id.strip_edges()
	if clean_request_id == "":
		return
	var state := ensure_orbit_operations_state()
	var requests = state.get("planet_item_action_requests", [])
	if typeof(requests) != TYPE_ARRAY:
		return
	for i in range(requests.size()):
		var raw_request = requests[i]
		if typeof(raw_request) != TYPE_DICTIONARY:
			continue
		var request: Dictionary = raw_request
		if str(request.get("request_id", "")) != clean_request_id:
			continue
		request["status"] = str(result.get("status", "blocked"))
		request["ok"] = bool(result.get("ok", false))
		request["result"] = result.duplicate(true)
		request["resolved_at_unix"] = int(Time.get_unix_time_from_system())
		request["resolved_at_text"] = get_datetime_text()
		requests[i] = request
		break
	state["planet_item_action_requests"] = requests
	orbit_snapshot["orbit_operations"] = state


func refresh_selected_orbit_marker_after_item_operation() -> void:
	var selected_id := str(selected_orbit_marker.get("id", "")).strip_edges()
	var refreshed_markers := build_orbit_globe_markers()
	if orbit_globe_view != null and orbit_globe_view.has_method("set_scan_markers"):
		orbit_globe_view.call("set_scan_markers", refreshed_markers)

	for raw_marker in refreshed_markers:
		if typeof(raw_marker) != TYPE_DICTIONARY:
			continue
		var marker: Dictionary = raw_marker
		if str(marker.get("id", "")) != selected_id:
			continue
		selected_orbit_marker = marker.duplicate(true)
		selected_orbit_marker["queued_action_status"] = "completed"
		show_orbit_marker_popup(selected_orbit_marker)
		return

	selected_orbit_marker["queued_action_status"] = "completed"
	show_orbit_marker_popup(selected_orbit_marker)


func format_orbit_item_ids(item_ids: Array) -> String:
	var labels := []
	for raw_item_id in item_ids:
		var item_id := str(raw_item_id).strip_edges()
		if item_id == "":
			continue
		labels.append(item_id.replace("_", " ").capitalize())
	return ", ".join(labels)


func _on_survey_orbit_button_pressed() -> void:
	if orbit_target_body.is_empty():
		append_text_log("ORBIT", "Survey blocked: no orbital body selected.")
		return

	var result := run_survey_orbit_for_target(orbit_target_body)
	last_orbit_survey_result = result
	last_orbit_operation_result = result
	update_orbit_operations_ui()

	append_text_log("ORBIT", str(result.get("summary_line", "Orbit survey complete.")))
	request_local_ai_orbit_analysis(result)


func _on_scan_planet_button_pressed() -> void:
	if orbit_target_body.is_empty():
		append_text_log("PLANET", "Scan blocked: no orbital body selected.")
		return

	var result := run_planet_orbit_scan_for_target(orbit_target_body)
	last_planet_scan_result = result
	last_orbit_operation_result = result
	update_orbit_operations_ui()

	append_text_log("PLANET", str(result.get("summary_line", "Planet scan complete.")))
	request_local_ai_orbit_analysis(result)


func _on_local_ai_reply_received(packet: Dictionary) -> void:
	var reply := str(packet.get("reply", ""))
	var backend := str(packet.get("backend", ""))
	var inference_ready := bool(packet.get("inference_ready", backend != "echo"))
	debug_print("reply received | chars=" + str(reply.length()) + " packet=" + str(packet))
	if pending_orbit_analysis and (backend == "echo" or not inference_ready):
		pending_orbit_analysis = false
		var fallback := build_fallback_orbit_analysis(pending_orbit_analysis_result)
		set_latest_reply_text("AMI> " + fallback)
		append_text_log("AMI_OFFLINE", fallback)
		record_orbit_analysis(fallback, {
			"backend": "deterministic_fallback",
			"source_backend": backend
		}, pending_orbit_analysis_operation_id)
		pending_orbit_analysis_operation_id = ""
		pending_orbit_analysis_result = {}
		return

	if backend == "echo" or not inference_ready:
		set_latest_reply_text("ECHO TEST> " + reply)
	else:
		set_latest_reply_text("AI> " + reply)
	append_text_log("AI", reply)

	if pending_orbit_analysis:
		pending_orbit_analysis = false
		record_orbit_analysis(reply, packet, pending_orbit_analysis_operation_id)
		pending_orbit_analysis_operation_id = ""
		pending_orbit_analysis_result = {}


func _on_local_ai_request_failed(packet: Dictionary) -> void:
	var reason := str(packet.get("reason", packet.get("error", "Unknown local AI error.")))
	debug_print("request failed | packet=" + str(packet))
	if pending_orbit_analysis and not pending_orbit_analysis_result.is_empty():
		pending_orbit_analysis = false
		var fallback := build_fallback_orbit_analysis(pending_orbit_analysis_result)
		set_latest_reply_text("AMI> " + fallback)
		append_text_log("AMI_OFFLINE", fallback)
		record_orbit_analysis(fallback, {
			"backend": "deterministic_fallback",
			"reason": reason
		}, pending_orbit_analysis_operation_id)
		pending_orbit_analysis_operation_id = ""
		pending_orbit_analysis_result = {}
		return
	set_latest_reply_text("LOCAL_AI_ERROR> " + reason)
	append_text_log("LOCAL_AI_ERROR", reason)


func _on_local_ai_status_changed(status_text: String) -> void:
	debug_print("status | " + status_text)
	if status_label != null:
		status_label.text = status_text
	append_text_log("LOCAL_AI", status_text)


func _on_local_ai_server_status_changed(packet: Dictionary) -> void:
	var message := str(packet.get("message", "Local AI server status changed."))
	debug_print("server status | " + str(packet))
	if status_label != null:
		status_label.text = message
	append_text_log("LOCAL_AI_SERVER", message)


func append_text_log(source: String, message: String) -> void:
	if text_log == null:
		return

	var line := "[" + get_log_time_text() + "] " + source + "> " + message
	if text_log.text.strip_edges() == "":
		text_log.text = line
	else:
		text_log.text += "\n" + line

	text_log.scroll_to_line(max(0, text_log.get_line_count() - 1))
	text_log.queue_redraw()


func set_latest_reply_text(value: String) -> void:
	if latest_reply_label != null:
		latest_reply_label.text = value
		latest_reply_label.queue_redraw()
	if status_label != null and value.begins_with("AI> "):
		status_label.text = "Local AI reply received."


func run_survey_orbit_for_target(target_body: Dictionary) -> Dictionary:
	var planet_id := get_orbit_body_id(target_body)
	var planet_name := get_orbit_body_display_name(target_body)
	var raw_objects = orbit_snapshot.get("space_objects", [])
	if typeof(raw_objects) != TYPE_ARRAY:
		return {
			"ok": false,
			"operation_id": ORBIT_SURVEY_OPERATION_ID,
			"planet_id": planet_id,
			"planet_name": planet_name,
			"reason": "Orbit snapshot has no space_objects array.",
			"summary_line": "Survey failed: no space object data was available."
		}

	var object_list: Array = raw_objects
	var matched_contact_ids: Array = []
	var matched_contact_names: Array = []
	var revealed_contact_ids: Array = []
	var revealed_contact_names: Array = []
	var already_discovered_count := 0
	var resource_totals := {}
	var surveyed_at_unix := int(Time.get_unix_time_from_system())
	var surveyed_at_text := get_datetime_text()

	for i in range(object_list.size()):
		var object_data = object_list[i]
		if typeof(object_data) != TYPE_DICTIONARY:
			continue

		var contact: Dictionary = object_data
		if not is_space_object_linked_to_orbit_body(contact, target_body):
			continue

		var contact_id := get_space_object_id(contact, "object_" + str(i))
		var contact_name := get_space_object_display_name(contact, contact_id)
		matched_contact_ids.append(contact_id)
		matched_contact_names.append(contact_name)

		var was_discovered := is_space_object_discovered(contact)
		if was_discovered:
			already_discovered_count += 1
		else:
			revealed_contact_ids.append(contact_id)
			revealed_contact_names.append(contact_name)

		mark_space_object_revealed_by_orbit(contact, target_body, surveyed_at_unix, surveyed_at_text)
		add_space_object_resources_to_totals(contact, resource_totals)
		object_list[i] = contact

	orbit_snapshot["space_objects"] = object_list

	var result := {
		"ok": true,
		"operation_id": ORBIT_SURVEY_OPERATION_ID,
		"planet_id": planet_id,
		"planet_name": planet_name,
		"surveyed_at_unix": surveyed_at_unix,
		"surveyed_at_text": surveyed_at_text,
		"matched_contact_count": matched_contact_ids.size(),
		"matched_contact_ids": matched_contact_ids,
		"matched_contact_names": matched_contact_names,
		"revealed_contact_count": revealed_contact_ids.size(),
		"revealed_contact_ids": revealed_contact_ids,
		"revealed_contact_names": revealed_contact_names,
		"already_discovered_count": already_discovered_count,
		"resource_totals": resource_totals
	}
	result["summary_line"] = build_orbit_survey_summary_line(result)

	record_orbit_survey_result(result)
	update_orbit_scan_state(result)
	return result


func is_space_object_linked_to_orbit_body(object_data: Dictionary, target_body: Dictionary) -> bool:
	var planet_id := get_orbit_body_id(target_body).to_lower()
	var planet_name := get_orbit_body_display_name(target_body).to_lower()
	if planet_id == "" and planet_name == "":
		return false

	for key in ["parent_planet_id", "anchor_planet_id", "orbit_parent_planet_id"]:
		if object_data.has(key) and str(object_data.get(key, "")).strip_edges().to_lower() == planet_id:
			return true

	for key in ["parent_planet_name", "anchor_planet_name", "orbit_parent_planet_name"]:
		if object_data.has(key) and str(object_data.get(key, "")).strip_edges().to_lower() == planet_name:
			return true

	var labels := read_orbit_label_array(object_data.get("labels", []))
	if typeof(object_data.get("shared_meta", {})) == TYPE_DICTIONARY:
		var shared_meta: Dictionary = object_data.get("shared_meta", {})
		labels.append_array(read_orbit_label_array(shared_meta.get("labels", [])))

	var wanted_labels := [
		"near_" + planet_id,
		"parent_" + planet_id,
		"orbit_" + planet_id
	]
	for raw_label in labels:
		var label := str(raw_label).strip_edges().to_lower()
		if wanted_labels.has(label):
			return true

	return false


func mark_space_object_revealed_by_orbit(object_data: Dictionary, target_body: Dictionary, revealed_at_unix: int, revealed_at_text: String) -> void:
	object_data["is_visible"] = true
	object_data["is_discovered"] = true
	object_data["orbit_revealed"] = true
	object_data["orbit_revealed_by_operation"] = ORBIT_SURVEY_OPERATION_ID
	object_data["orbit_revealed_by_planet_id"] = get_orbit_body_id(target_body)
	object_data["orbit_revealed_by_planet_name"] = get_orbit_body_display_name(target_body)
	object_data["orbit_revealed_at_unix"] = revealed_at_unix
	object_data["orbit_revealed_at_text"] = revealed_at_text

	var shared_meta := {}
	if typeof(object_data.get("shared_meta", {})) == TYPE_DICTIONARY:
		shared_meta = object_data.get("shared_meta", {}).duplicate(true)
	shared_meta["is_visible"] = true
	shared_meta["is_discovered"] = true
	object_data["shared_meta"] = shared_meta


func is_space_object_discovered(object_data: Dictionary) -> bool:
	if object_data.has("is_discovered") and bool(object_data.get("is_discovered", false)):
		return true
	var shared_meta = object_data.get("shared_meta", {})
	if typeof(shared_meta) == TYPE_DICTIONARY:
		return bool(shared_meta.get("is_discovered", false))
	return false


func add_space_object_resources_to_totals(object_data: Dictionary, totals: Dictionary) -> void:
	var direct_resource_ids := {}
	var direct_resources = object_data.get("resources_left", {})
	if typeof(direct_resources) == TYPE_DICTIONARY:
		for raw_item_id in direct_resources.keys():
			var item_id := str(raw_item_id).strip_edges()
			if item_id == "":
				continue
			direct_resource_ids[item_id] = true
			add_resource_amount_to_totals(totals, item_id, direct_resources.get(raw_item_id, 0))

	for raw_key in object_data.keys():
		var key := str(raw_key)
		if not key.ends_with("_left"):
			continue
		var item_id := key.substr(0, key.length() - "_left".length()).strip_edges()
		if direct_resource_ids.has(item_id):
			continue
		add_resource_amount_to_totals(totals, item_id, object_data.get(raw_key, 0))


func add_resource_amount_to_totals(totals: Dictionary, item_id: String, raw_amount) -> void:
	var clean_item_id := item_id.strip_edges()
	if clean_item_id == "" or clean_item_id == "mined_out":
		return
	if typeof(raw_amount) != TYPE_INT and typeof(raw_amount) != TYPE_FLOAT:
		return
	var amount := int(raw_amount)
	if amount <= 0:
		return
	totals[clean_item_id] = int(totals.get(clean_item_id, 0)) + amount


func record_orbit_survey_result(result: Dictionary) -> void:
	var state := ensure_orbit_operations_state()
	var planet_id := str(result.get("planet_id", "")).strip_edges()
	var planet_surveys = state.get("planet_surveys", {})
	if typeof(planet_surveys) != TYPE_DICTIONARY:
		planet_surveys = {}

	if planet_id != "":
		planet_surveys[planet_id] = {
			"operation_id": ORBIT_SURVEY_OPERATION_ID,
			"planet_id": planet_id,
			"planet_name": str(result.get("planet_name", "")),
			"surveyed_at_unix": int(result.get("surveyed_at_unix", 0)),
			"surveyed_at_text": str(result.get("surveyed_at_text", "")),
			"matched_contact_ids": result.get("matched_contact_ids", []).duplicate(true),
			"revealed_contact_ids": result.get("revealed_contact_ids", []).duplicate(true),
			"already_discovered_count": int(result.get("already_discovered_count", 0)),
			"resource_totals": result.get("resource_totals", {}).duplicate(true)
		}

	var history = state.get("history", [])
	if typeof(history) != TYPE_ARRAY:
		history = []
	history.append({
		"operation_id": ORBIT_SURVEY_OPERATION_ID,
		"planet_id": planet_id,
		"planet_name": str(result.get("planet_name", "")),
		"summary_line": str(result.get("summary_line", "")),
		"surveyed_at_unix": int(result.get("surveyed_at_unix", 0)),
		"surveyed_at_text": str(result.get("surveyed_at_text", ""))
	})
	while history.size() > 20:
		history.pop_front()

	state["planet_surveys"] = planet_surveys
	state["history"] = history
	orbit_snapshot["orbit_operations"] = state


func update_orbit_scan_state(result: Dictionary) -> void:
	var scan_state = orbit_snapshot.get("scan_state", {})
	if typeof(scan_state) != TYPE_DICTIONARY:
		scan_state = {}

	var revealed_contacts = scan_state.get("orbit_revealed_contacts", {})
	if typeof(revealed_contacts) != TYPE_DICTIONARY:
		revealed_contacts = {}

	var contact_ids = result.get("matched_contact_ids", [])
	if typeof(contact_ids) == TYPE_ARRAY:
		for raw_contact_id in contact_ids:
			var contact_id := str(raw_contact_id).strip_edges()
			if contact_id == "":
				continue
			revealed_contacts[contact_id] = {
				"planet_id": str(result.get("planet_id", "")),
				"planet_name": str(result.get("planet_name", "")),
				"operation_id": ORBIT_SURVEY_OPERATION_ID,
				"discovered_at_unix": int(result.get("surveyed_at_unix", 0)),
				"discovered_at_text": str(result.get("surveyed_at_text", ""))
			}

	scan_state["orbit_revealed_contacts"] = revealed_contacts
	orbit_snapshot["scan_state"] = scan_state


func run_planet_orbit_scan_for_target(target_body: Dictionary) -> Dictionary:
	var planet_id := get_orbit_body_id(target_body)
	var planet_name := get_orbit_body_display_name(target_body)
	var scan_time_unix := int(Time.get_unix_time_from_system())
	var scan_time_text := get_datetime_text()
	var planet_lookup := find_planet_snapshot_entry(planet_id)
	var planet_data := target_body.duplicate(true)
	if typeof(planet_lookup.get("planet", {})) == TYPE_DICTIONARY and not planet_lookup.get("planet", {}).is_empty():
		planet_data = planet_lookup.get("planet", {}).duplicate(true)

	var discoveries := build_planet_orbit_discoveries(planet_data)
	var interactions := build_planet_orbit_interactions(planet_data, discoveries)
	var event_listeners := build_planet_orbit_event_listeners(planet_data, discoveries, interactions)
	mark_planet_scanned_by_orbit(planet_data, discoveries, interactions, event_listeners, scan_time_unix, scan_time_text)

	if int(planet_lookup.get("index", -1)) >= 0:
		var planets := get_array_section(orbit_snapshot, "planets")
		var planet_index := int(planet_lookup.get("index", -1))
		if planet_index >= 0 and planet_index < planets.size():
			planets[planet_index] = planet_data
			orbit_snapshot["planets"] = planets

	orbit_target_body = planet_data.duplicate(true)
	orbit_snapshot["orbit_target_body"] = make_orbit_body_save_slice(orbit_target_body)

	var result := {
		"ok": true,
		"operation_id": ORBIT_PLANET_SCAN_OPERATION_ID,
		"planet_id": planet_id,
		"planet_name": planet_name,
		"scanned_at_unix": scan_time_unix,
		"scanned_at_text": scan_time_text,
		"planet_type": str(planet_data.get("planet_type", "")),
		"planet_role": str(planet_data.get("planet_role", "")),
		"population_state": str(planet_data.get("population_state", "")),
		"danger_level": int(planet_data.get("danger_level", 0)),
		"resource_value": int(planet_data.get("resource_value", 0)),
		"discoveries": discoveries,
		"interactions": interactions,
		"event_listeners": event_listeners,
		"discovery_count": discoveries.size(),
		"interaction_count": interactions.size(),
		"event_listener_count": event_listeners.size(),
		"visible_event_listener_count": count_visible_orbit_event_listeners(event_listeners),
		"silent_event_listener_count": count_silent_orbit_event_listeners(event_listeners)
	}
	result["summary_line"] = build_planet_scan_summary_line(result)

	queue_orbit_event_listener_discoveries(result)
	record_orbit_planet_scan_result(result)
	update_orbit_planet_scan_state(result)
	return result


func find_planet_snapshot_entry(planet_id: String) -> Dictionary:
	var planets := get_array_section(orbit_snapshot, "planets")
	for i in range(planets.size()):
		var planet = planets[i]
		if typeof(planet) != TYPE_DICTIONARY:
			continue
		var entry_id := str(planet.get("object_id", planet.get("id", ""))).strip_edges()
		if entry_id == planet_id:
			return {
				"index": i,
				"planet": planet
			}
	return {
		"index": -1,
		"planet": {}
	}


func build_planet_orbit_discoveries(planet_data: Dictionary) -> Array:
	var discoveries := []
	add_planet_text_discovery(discoveries, "scan_description", "Scan Reading", planet_data.get("scan_description", ""))
	add_planet_text_discovery(discoveries, "contact_text", "Orbital Contact", planet_data.get("contact_text", ""))

	var population_state := str(planet_data.get("population_state", "")).strip_edges()
	if population_state != "" and population_state not in ["unknown", "uninhabited"]:
		discoveries.append(make_planet_orbit_discovery(
			"population_" + population_state,
			"Population Trace",
			"Population state reads " + population_state.replace("_", " ") + ".",
			"population_state",
			"population"
		))

	var danger_level := int(planet_data.get("danger_level", 0))
	if danger_level > 0:
		discoveries.append(make_planet_orbit_discovery(
			"danger_level_" + str(danger_level),
			"Hazard Warning",
			"Orbital hazard index " + str(danger_level) + ".",
			"danger_level",
			"hazard"
		))

	var resource_value := int(planet_data.get("resource_value", 0))
	if resource_value > 0:
		discoveries.append(make_planet_orbit_discovery(
			"resource_value_" + str(resource_value),
			"Resource Signature",
			"Broad resource reading " + str(resource_value) + ".",
			"resource_value",
			"resource"
		))

	for service_id in SharedObjectMeta.read_array(planet_data.get("services", [])):
		var clean_service := str(service_id).strip_edges()
		if clean_service == "":
			continue
		discoveries.append(make_planet_orbit_discovery(
			"service_" + clean_service,
			"Service Channel",
			"Available service: " + clean_service.replace("_", " ") + ".",
			"services",
			"service"
		))

	add_planet_array_discoveries(discoveries, planet_data, "planet_board_events", "Board Event", "board_event")
	add_planet_array_discoveries(discoveries, planet_data, "quest_messages", "Quest Message", "message")
	add_planet_array_discoveries(discoveries, planet_data, "event_ids", "Event Signal", "event_signal")
	add_planet_authored_discoveries(discoveries, planet_data)
	add_planet_surface_site_discoveries(discoveries, planet_data)
	add_planet_resource_site_discoveries(discoveries, planet_data)
	return dedupe_orbit_entries(discoveries, "id")


func build_planet_orbit_interactions(planet_data: Dictionary, discoveries: Array) -> Array:
	var interactions := []
	var role := str(planet_data.get("planet_role", "")).strip_edges()
	add_role_based_planet_interactions(interactions, role)

	for service_id in SharedObjectMeta.read_array(planet_data.get("services", [])):
		add_service_based_planet_interaction(interactions, str(service_id).strip_edges())

	if not SharedObjectMeta.read_array(planet_data.get("planet_board_events", [])).is_empty():
		interactions.append(make_planet_orbit_interaction("read_planet_board", "Read Board", "Review available planet board entries from orbit.", "planet_board_events"))
	if not SharedObjectMeta.read_array(planet_data.get("quest_messages", [])).is_empty():
		interactions.append(make_planet_orbit_interaction("read_quest_messages", "Read Messages", "Review planet-linked quest messages from orbit.", "quest_messages"))
	if bool(planet_data.get("has_event", false)) or str(planet_data.get("event_id", "")).strip_edges() != "" or not SharedObjectMeta.read_array(planet_data.get("event_ids", [])).is_empty():
		interactions.append(make_planet_orbit_interaction("trace_event_signal", "Trace Signal", "Trace an authored event signal attached to this planet.", "event_ids"))
	if bool(planet_data.get("has_planet_interface", false)):
		interactions.append(make_planet_orbit_interaction("open_planet_interface", "Open Interface", "Use the planet contact interface from orbit.", "has_planet_interface"))

	add_planet_authored_interactions(interactions, planet_data)
	add_planet_surface_site_interactions(interactions, planet_data)
	add_planet_resource_tool_interactions(interactions, planet_data)
	add_planet_resource_site_interactions(interactions, planet_data)
	return dedupe_orbit_entries(interactions, "id")


func build_planet_orbit_event_listeners(planet_data: Dictionary, discoveries: Array, interactions: Array) -> Array:
	var event_listeners := []
	var planet_id := get_orbit_body_id(planet_data)
	var planet_name := get_orbit_body_display_name(planet_data)

	for source_key in ["orbit_event_listeners", "orbit_discovered_event_listeners", "orbital_event_listeners"]:
		append_orbit_event_listener_packets(event_listeners, planet_data.get(source_key, []), {
			"source_key": source_key,
			"source_kind": "planet",
			"source_planet_id": planet_id,
			"source_planet_name": planet_name
		})

	for discovery in discoveries:
		if typeof(discovery) != TYPE_DICTIONARY:
			continue
		var discovery_data: Dictionary = discovery
		for source_key in ["orbit_event_listeners", "event_listeners", "discover_events", "silent_discover_events"]:
			append_orbit_event_listener_packets(event_listeners, discovery_data.get(source_key, []), {
				"source_key": source_key,
				"source_kind": "discovery",
				"source_entry_id": str(discovery_data.get("id", "")),
				"source_entry_title": str(discovery_data.get("title", "")),
				"source_planet_id": planet_id,
				"source_planet_name": planet_name
			})

	for interaction in interactions:
		if typeof(interaction) != TYPE_DICTIONARY:
			continue
		var interaction_data: Dictionary = interaction
		for source_key in ["orbit_event_listeners", "event_listeners", "discover_events", "silent_discover_events"]:
			append_orbit_event_listener_packets(event_listeners, interaction_data.get(source_key, []), {
				"source_key": source_key,
				"source_kind": "interaction",
				"source_entry_id": str(interaction_data.get("id", "")),
				"source_entry_title": str(interaction_data.get("label", "")),
				"source_planet_id": planet_id,
				"source_planet_name": planet_name
			})

	return dedupe_orbit_entries(event_listeners, "queue_id")


func append_orbit_event_listener_packets(output: Array, raw_value, context: Dictionary) -> void:
	if raw_value == null:
		return

	if typeof(raw_value) == TYPE_STRING or typeof(raw_value) == TYPE_STRING_NAME:
		var event_id := str(raw_value).strip_edges()
		if event_id != "":
			var packet := normalize_orbit_event_listener_packet({"event_id": event_id}, context)
			if not packet.is_empty():
				output.append(packet)
		return

	if typeof(raw_value) == TYPE_ARRAY:
		for item in raw_value:
			append_orbit_event_listener_packets(output, item, context)
		return

	if typeof(raw_value) != TYPE_DICTIONARY:
		return

	var raw_dict: Dictionary = raw_value
	if orbit_event_listener_dict_is_packet(raw_dict):
		var packet := normalize_orbit_event_listener_packet(raw_dict, context)
		if not packet.is_empty():
			output.append(packet)
		return

	for key in raw_dict.keys():
		var item = raw_dict[key]
		var child_context := context.duplicate(true)
		child_context["source_entry_id"] = str(key)
		append_orbit_event_listener_packets(output, item, child_context)


func orbit_event_listener_dict_is_packet(data: Dictionary) -> bool:
	for key in ["event_id", "trigger_event_id", "target_event_id", "listener_type", "orbit_event_action", "event_action"]:
		if data.has(key):
			return true
	return false


func normalize_orbit_event_listener_packet(raw_packet: Dictionary, context: Dictionary) -> Dictionary:
	var packet := raw_packet.duplicate(true)
	var event_id := resolve_orbit_event_listener_event_id(packet)
	if event_id == "":
		return {}

	var listener_type := str(packet.get("listener_type", packet.get("installed_listener_type", "discover_event"))).strip_edges()
	if listener_type == "":
		listener_type = "discover_event"

	var action := str(packet.get("orbit_event_action", packet.get("event_action", packet.get("action", "")))).strip_edges()
	if action == "":
		action = infer_orbit_event_listener_action(listener_type)
	action = normalize_orbit_event_listener_action(action)

	var silent := bool(packet.get("silent", packet.get("silent_discovery", packet.get("background", false))))
	if str(packet.get("listener_type", "")).strip_edges() in ["silent_discover_event", "discover_event_silent", "silent_activate_event", "activate_event_silent"]:
		silent = true

	packet["event_id"] = event_id
	packet["trigger_event_id"] = str(packet.get("trigger_event_id", event_id))
	packet["listener_type"] = listener_type
	packet["orbit_event_action"] = action
	packet["silent"] = silent
	packet["visible_in_orbit"] = bool(packet.get("visible_in_orbit", not silent))
	packet["source"] = str(packet.get("source", "orbit_scan"))
	packet["source_operation_id"] = ORBIT_PLANET_SCAN_OPERATION_ID

	for key in context.keys():
		if not packet.has(key):
			packet[key] = context[key]

	var queue_id := str(packet.get("queue_id", packet.get("id", packet.get("listener_id", "")))).strip_edges()
	if queue_id == "":
		queue_id = event_id + "_" + action + "_" + str(packet.get("source_kind", "planet")) + "_" + str(packet.get("source_entry_id", "root"))
	packet["queue_id"] = queue_id
	packet["id"] = str(packet.get("id", queue_id))
	return packet


func resolve_orbit_event_listener_event_id(packet: Dictionary) -> String:
	for key in ["trigger_event_id", "event_id", "target_event_id", "discover_event_id", "activate_event_id"]:
		var event_id := str(packet.get(key, "")).strip_edges()
		if event_id != "":
			return event_id
	return ""


func infer_orbit_event_listener_action(listener_type: String) -> String:
	var clean_type := listener_type.strip_edges()
	if clean_type in ["install_event_listener", "spawn_event_listener", "discover_event_listener"]:
		return "install_event_listener"
	if clean_type in ["activate_event", "activate_event_on_range", "start_event", "start_event_on_range", "silent_activate_event", "activate_event_silent"]:
		return "activate_event"
	return "discover_event"


func normalize_orbit_event_listener_action(action: String) -> String:
	var clean_action := action.strip_edges()
	match clean_action:
		"seed_event", "add_available_event", "discover_event", "silent_discover_event", "discover_event_silent":
			return "discover_event"
		"activate_event", "activate_event_on_range", "start_event", "start_event_on_range", "silent_activate_event", "activate_event_silent":
			return "activate_event"
		"install_event_listener", "spawn_event_listener", "discover_event_listener":
			return "install_event_listener"
		_:
			return "discover_event"


func count_visible_orbit_event_listeners(event_listeners: Array) -> int:
	var count := 0
	for listener in event_listeners:
		if typeof(listener) == TYPE_DICTIONARY and bool(listener.get("visible_in_orbit", true)):
			count += 1
	return count


func count_silent_orbit_event_listeners(event_listeners: Array) -> int:
	var count := 0
	for listener in event_listeners:
		if typeof(listener) == TYPE_DICTIONARY and bool(listener.get("silent", false)):
			count += 1
	return count


func add_planet_text_discovery(discoveries: Array, source_key: String, title: String, raw_text) -> void:
	var text := str(raw_text).strip_edges()
	if text == "":
		return
	discoveries.append(make_planet_orbit_discovery(source_key, title, text, source_key, "planet_reading"))


func add_planet_array_discoveries(discoveries: Array, planet_data: Dictionary, source_key: String, title: String, category: String) -> void:
	var values := SharedObjectMeta.read_array(planet_data.get(source_key, []))
	for i in range(values.size()):
		var value = values[i]
		var entry_id := source_key + "_" + str(i)
		var summary := ""
		var extra := {}
		if typeof(value) == TYPE_DICTIONARY:
			var entry: Dictionary = value
			extra = entry.duplicate(true)
			entry_id = str(entry.get("id", entry.get("event_id", entry.get("message_id", entry_id)))).strip_edges()
			summary = str(entry.get("summary", entry.get("text", entry.get("title", entry_id)))).strip_edges()
		else:
			entry_id = str(value).strip_edges()
			summary = entry_id
		if entry_id == "":
			continue
		discoveries.append(make_planet_orbit_discovery(entry_id, title, summary, source_key, category, extra))


func add_planet_authored_discoveries(discoveries: Array, planet_data: Dictionary) -> void:
	for source_key in ["orbit_discoveries", "orbital_discoveries"]:
		var values := SharedObjectMeta.read_array(planet_data.get(source_key, []))
		for i in range(values.size()):
			var value = values[i]
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = value
			var entry_id := str(entry.get("id", entry.get("discovery_id", source_key + "_" + str(i)))).strip_edges()
			var title := str(entry.get("title", entry.get("display_name", "Orbit Discovery"))).strip_edges()
			var summary := str(entry.get("summary", entry.get("text", entry.get("description", "")))).strip_edges()
			var category := str(entry.get("category", "authored")).strip_edges()
			discoveries.append(make_planet_orbit_discovery(entry_id, title, summary, source_key, category, entry))


func add_planet_surface_site_discoveries(discoveries: Array, planet_data: Dictionary) -> void:
	for source_key in ["orbit_surface_sites", "planet_surface_sites", "surface_sites", "surface_buildings"]:
		var values := SharedObjectMeta.read_array(planet_data.get(source_key, []))
		for i in range(values.size()):
			var value = values[i]
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var site: Dictionary = value
			var site_id := str(site.get("site_id", site.get("building_id", site.get("id", source_key + "_" + str(i))))).strip_edges()
			var title := str(site.get("display_name", site.get("title", "Surface Site"))).strip_edges()
			var summary := str(site.get("scan_summary", site.get("summary", site.get("description", "")))).strip_edges()
			discoveries.append(make_planet_orbit_discovery(site_id, title, summary, source_key, "surface_site", site))


func add_planet_resource_site_discoveries(discoveries: Array, planet_data: Dictionary) -> void:
	for source_key in get_planet_resource_source_keys():
		var values := SharedObjectMeta.read_array(planet_data.get(source_key, []))
		for i in range(values.size()):
			var value = values[i]
			if typeof(value) == TYPE_DICTIONARY:
				var site: Dictionary = value
				var site_id := get_planet_resource_site_id(site, source_key, i)
				var title := get_planet_resource_site_title(site)
				var summary := get_planet_resource_site_summary(site)
				discoveries.append(make_planet_orbit_discovery(site_id, title, summary, source_key, "planet_resource", site))
			else:
				var site_id := str(value).strip_edges()
				if site_id == "":
					continue
				var title := site_id.replace("_", " ").capitalize()
				discoveries.append(make_planet_orbit_discovery(site_id, title, "Planet resource signal detected from orbit.", source_key, "planet_resource"))


func add_role_based_planet_interactions(interactions: Array, role: String) -> void:
	match role:
		"trade_board":
			interactions.append(make_planet_orbit_interaction("remote_trade_board", "Trade Relay", "Contact a trade relay from orbit.", "planet_role"))
		"quest_board":
			interactions.append(make_planet_orbit_interaction("orbital_bulletin", "Bulletin Board", "Read available work from the orbital board.", "planet_role"))
		"refuge_contact":
			interactions.append(make_planet_orbit_interaction("hail_refuge", "Hail Refuge", "Attempt a masked orbital hail.", "planet_role"))
		"mining_claim", "mining_world", "resource_world":
			interactions.append(make_planet_orbit_interaction("review_mining_claims", "Mining Claims", "Review planet-linked mining claim data.", "planet_role"))
		"lore_site", "ruin_world", "silent_world", "anomaly_world":
			interactions.append(make_planet_orbit_interaction("trace_lore_signal", "Trace Lore", "Trace weak historical or anomalous signals from orbit.", "planet_role"))
		"survey_target", "frontier_world", "anchor_planet":
			interactions.append(make_planet_orbit_interaction("survey_contact", "Survey Contact", "Maintain a basic orbital survey channel.", "planet_role"))


func add_service_based_planet_interaction(interactions: Array, service_id: String) -> void:
	if service_id == "":
		return
	var label := service_id.replace("_", " ").capitalize()
	interactions.append(make_planet_orbit_interaction(service_id, label, "Use " + label + " from orbit.", "services"))


func add_planet_authored_interactions(interactions: Array, planet_data: Dictionary) -> void:
	for source_key in ["orbit_interactions", "orbital_interactions"]:
		var values := SharedObjectMeta.read_array(planet_data.get(source_key, []))
		for i in range(values.size()):
			var value = values[i]
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var entry: Dictionary = value
			var entry_id := str(entry.get("id", entry.get("interaction_id", source_key + "_" + str(i)))).strip_edges()
			var label := str(entry.get("label", entry.get("display_name", "Orbit Interaction"))).strip_edges()
			var summary := str(entry.get("summary", entry.get("description", ""))).strip_edges()
			interactions.append(make_planet_orbit_interaction(entry_id, label, summary, source_key, entry))


func add_planet_surface_site_interactions(interactions: Array, planet_data: Dictionary) -> void:
	for source_key in ["orbit_surface_sites", "planet_surface_sites", "surface_sites", "surface_buildings"]:
		var values := SharedObjectMeta.read_array(planet_data.get(source_key, []))
		for i in range(values.size()):
			var value = values[i]
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var site: Dictionary = value
			var site_id := str(site.get("site_id", site.get("building_id", site.get("id", source_key + "_" + str(i))))).strip_edges()
			if site_id == "":
				continue
			var site_interactions := SharedObjectMeta.read_array(site.get("interaction_ids", site.get("interactions", [])))
			if site_interactions.is_empty():
				interactions.append(make_planet_orbit_interaction("inspect_" + site_id, "Inspect Site", "Inspect " + str(site.get("display_name", site_id)) + " from orbit.", source_key, site))
			else:
				for raw_interaction in site_interactions:
					var interaction_id := ""
					var label := ""
					var summary := "Use site interaction from orbit."
					var extra := site.duplicate(true)
					if typeof(raw_interaction) == TYPE_DICTIONARY:
						var interaction_data: Dictionary = raw_interaction
						interaction_id = str(interaction_data.get("id", interaction_data.get("interaction_id", ""))).strip_edges()
						label = str(interaction_data.get("label", interaction_data.get("display_name", ""))).strip_edges()
						summary = str(interaction_data.get("summary", interaction_data.get("description", summary))).strip_edges()
						extra = interaction_data.duplicate(true)
						extra["site_id"] = site_id
					else:
						interaction_id = str(raw_interaction).strip_edges()
					if interaction_id == "":
						continue
					if label == "":
						label = interaction_id.replace("_", " ").capitalize()
					interactions.append(make_planet_orbit_interaction(interaction_id, label, summary, source_key, extra))


func add_planet_resource_tool_interactions(interactions: Array, planet_data: Dictionary) -> void:
	if not planet_has_resource_operation_data(planet_data):
		return

	interactions.append(make_planet_orbit_interaction(
		ORBIT_RESOURCE_ROVER_OPERATION_ID,
		"Deploy Rover",
		"Consume one Planetary Resource Rover to explore planet resource data from orbit.",
		"planetary_resource_tools",
		{
			"requires_orbit_items": [ORBIT_RESOURCE_ROVER_ITEM_ID],
			"consume_orbit_items": [ORBIT_RESOURCE_ROVER_ITEM_ID],
			"consume_on_success": true,
			"consumed_on_use": true,
			"planetary_resource_action": "explore",
			"operation_result_kind": "planet_resource_data",
			"operation_runtime_status": "metadata_ready",
			"local_ai_hint": "This is a data-only surface resource exploration action. It does not open landing gameplay."
		}
	))

	interactions.append(make_planet_orbit_interaction(
		ORBIT_RECOVERY_LAUNCH_OPERATION_ID,
		"Recovery Launch",
		"Consume one Planet Recovery Launcher to send planet-held resources or items back to orbit.",
		"planetary_resource_tools",
		{
			"requires_orbit_items": [ORBIT_RECOVERY_LAUNCHER_ITEM_ID],
			"consume_orbit_items": [ORBIT_RECOVERY_LAUNCHER_ITEM_ID],
			"consume_on_success": true,
			"consumed_on_use": true,
			"planetary_resource_action": "recover_to_orbit",
			"operation_result_kind": "planet_resource_recovery",
			"operation_runtime_status": "metadata_ready",
			"local_ai_hint": "This is the surface-to-orbit recovery action. Inventory mutation belongs to deterministic operation code."
		}
	))


func add_planet_resource_site_interactions(interactions: Array, planet_data: Dictionary) -> void:
	for source_key in get_planet_resource_source_keys():
		var values := SharedObjectMeta.read_array(planet_data.get(source_key, []))
		for i in range(values.size()):
			var value = values[i]
			if typeof(value) != TYPE_DICTIONARY:
				continue
			var site: Dictionary = value
			var site_id := get_planet_resource_site_id(site, source_key, i)
			var site_interactions := SharedObjectMeta.read_array(site.get("interaction_ids", site.get("interactions", [])))
			for raw_interaction in site_interactions:
				var interaction_id := ""
				var label := ""
				var summary := "Use resource-site interaction from orbit."
				var extra := site.duplicate(true)
				if typeof(raw_interaction) == TYPE_DICTIONARY:
					var interaction_data: Dictionary = raw_interaction
					interaction_id = str(interaction_data.get("id", interaction_data.get("interaction_id", ""))).strip_edges()
					label = str(interaction_data.get("label", interaction_data.get("display_name", ""))).strip_edges()
					summary = str(interaction_data.get("summary", interaction_data.get("description", summary))).strip_edges()
					extra = interaction_data.duplicate(true)
					extra["resource_site_id"] = site_id
				else:
					interaction_id = str(raw_interaction).strip_edges()
				if interaction_id == "":
					continue
				if label == "":
					label = interaction_id.replace("_", " ").capitalize()
				interactions.append(make_planet_orbit_interaction(interaction_id, label, summary, source_key, extra))


func get_planet_resource_source_keys() -> Array:
	return ["orbit_resource_sites", "planet_resource_sites", "planet_surface_resources", "surface_resources"]


func planet_has_resource_operation_data(planet_data: Dictionary) -> bool:
	if int(planet_data.get("resource_value", 0)) > 0:
		return true

	for source_key in get_planet_resource_source_keys():
		if not SharedObjectMeta.read_array(planet_data.get(source_key, [])).is_empty():
			return true

	for source_key in ["resources", "planet_resources", "recovery_items", "recoverable_items"]:
		var value = planet_data.get(source_key, {})
		if typeof(value) == TYPE_DICTIONARY and not value.is_empty():
			return true
		if typeof(value) == TYPE_ARRAY and not value.is_empty():
			return true

	return false


func get_planet_resource_site_id(site: Dictionary, source_key: String, index: int) -> String:
	var site_id := str(site.get("site_id", site.get("resource_site_id", site.get("resource_id", site.get("id", ""))))).strip_edges()
	if site_id == "":
		site_id = source_key + "_" + str(index)
	return site_id


func get_planet_resource_site_title(site: Dictionary) -> String:
	var title := str(site.get("display_name", site.get("title", site.get("name", "")))).strip_edges()
	if title != "":
		return title

	var resource_id := str(site.get("resource_id", site.get("item_id", ""))).strip_edges()
	if resource_id != "":
		return resource_id.replace("_", " ").capitalize()

	return "Planet Resource"


func get_planet_resource_site_summary(site: Dictionary) -> String:
	var summary := str(site.get("scan_summary", site.get("summary", site.get("description", "")))).strip_edges()
	if summary != "":
		return summary

	for source_key in ["resources", "resource_mix", "items", "recovery_items", "recoverable_items"]:
		var value = site.get(source_key, {})
		if typeof(value) == TYPE_DICTIONARY:
			var resource_text := format_resource_totals(value, 4)
			if resource_text != "":
				return "Resources: " + resource_text + "."
		if typeof(value) == TYPE_ARRAY and not value.is_empty():
			return "Recoverable entries: " + str(value.size()) + "."

	var resource_id := str(site.get("resource_id", site.get("item_id", ""))).strip_edges()
	var amount := int(site.get("amount", site.get("remaining_amount", 0)))
	if resource_id != "" and amount > 0:
		return resource_id.replace("_", " ") + " x" + str(amount) + "."
	if resource_id != "":
		return resource_id.replace("_", " ") + " detected."

	return "Planet resource signal detected from orbit."


func make_planet_orbit_discovery(entry_id: String, title: String, summary: String, source_key: String, category: String, extra: Dictionary = {}) -> Dictionary:
	var packet := extra.duplicate(true)
	packet["id"] = entry_id
	packet["title"] = title
	packet["summary"] = summary
	packet["source_key"] = source_key
	packet["category"] = category
	return packet


func make_planet_orbit_interaction(entry_id: String, label: String, summary: String, source_key: String, extra: Dictionary = {}) -> Dictionary:
	var packet := extra.duplicate(true)
	packet["id"] = entry_id
	packet["label"] = label
	packet["summary"] = summary
	packet["source_key"] = source_key
	packet["enabled_from_orbit"] = bool(packet.get("enabled_from_orbit", true))
	if not packet.has("requires_orbit_items"):
		packet["requires_orbit_items"] = []
	return packet


func dedupe_orbit_entries(entries: Array, id_key: String) -> Array:
	var output := []
	var seen := {}
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var entry_id := str(entry.get(id_key, "")).strip_edges()
		if entry_id == "" or seen.has(entry_id):
			continue
		seen[entry_id] = true
		output.append(entry)
	return output


func mark_planet_scanned_by_orbit(planet_data: Dictionary, discoveries: Array, interactions: Array, event_listeners: Array, scanned_at_unix: int, scanned_at_text: String) -> void:
	planet_data["is_visible"] = true
	planet_data["is_discovered"] = true
	planet_data["orbit_planet_scanned"] = true
	planet_data["orbit_planet_scanned_at_unix"] = scanned_at_unix
	planet_data["orbit_planet_scanned_at_text"] = scanned_at_text
	planet_data["orbit_discoveries_found"] = discoveries.duplicate(true)
	planet_data["orbit_interactions_available"] = interactions.duplicate(true)
	planet_data["orbit_event_listeners_found"] = event_listeners.duplicate(true)

	var shared_meta := {}
	if typeof(planet_data.get("shared_meta", {})) == TYPE_DICTIONARY:
		shared_meta = planet_data.get("shared_meta", {}).duplicate(true)
	shared_meta["is_visible"] = true
	shared_meta["is_discovered"] = true
	planet_data["shared_meta"] = shared_meta


func queue_orbit_event_listener_discoveries(result: Dictionary) -> void:
	var event_listeners = result.get("event_listeners", [])
	if typeof(event_listeners) != TYPE_ARRAY or event_listeners.is_empty():
		return

	var queue = orbit_snapshot.get("orbit_event_discovery_queue", [])
	if typeof(queue) != TYPE_ARRAY:
		queue = []

	var seen := {}
	for existing in queue:
		if typeof(existing) != TYPE_DICTIONARY:
			continue
		var existing_id := str(existing.get("queue_id", existing.get("id", ""))).strip_edges()
		if existing_id != "":
			seen[existing_id] = true

	var queued_at_unix := int(result.get("scanned_at_unix", Time.get_unix_time_from_system()))
	var queued_at_text := str(result.get("scanned_at_text", get_datetime_text()))
	for listener in event_listeners:
		if typeof(listener) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = listener.duplicate(true)
		var queue_id := str(packet.get("queue_id", packet.get("id", ""))).strip_edges()
		if queue_id == "" or seen.has(queue_id):
			continue
		packet["queue_id"] = queue_id
		packet["status"] = str(packet.get("status", "pending"))
		packet["queued_by"] = "Orbit.scan_planet"
		packet["queued_at_unix"] = queued_at_unix
		packet["queued_at_text"] = queued_at_text
		packet["source_operation_id"] = ORBIT_PLANET_SCAN_OPERATION_ID
		packet["source_planet_id"] = str(result.get("planet_id", packet.get("source_planet_id", "")))
		packet["source_planet_name"] = str(result.get("planet_name", packet.get("source_planet_name", "")))
		queue.append(packet)
		seen[queue_id] = true

	orbit_snapshot["orbit_event_discovery_queue"] = queue
	update_orbit_event_discovery_scan_state(queue, result)


func update_orbit_event_discovery_scan_state(queue: Array, result: Dictionary) -> void:
	var scan_state = orbit_snapshot.get("scan_state", {})
	if typeof(scan_state) != TYPE_DICTIONARY:
		scan_state = {}

	var pending = scan_state.get("orbit_event_discoveries_pending", {})
	if typeof(pending) != TYPE_DICTIONARY:
		pending = {}

	var planet_id := str(result.get("planet_id", "")).strip_edges()
	for listener in queue:
		if typeof(listener) != TYPE_DICTIONARY:
			continue
		var packet: Dictionary = listener
		if str(packet.get("status", "pending")) != "pending":
			continue
		var queue_id := str(packet.get("queue_id", packet.get("id", ""))).strip_edges()
		if queue_id == "":
			continue
		pending[queue_id] = {
			"queue_id": queue_id,
			"event_id": str(packet.get("event_id", packet.get("trigger_event_id", ""))),
			"listener_type": str(packet.get("listener_type", "")),
			"orbit_event_action": str(packet.get("orbit_event_action", "")),
			"source_planet_id": str(packet.get("source_planet_id", planet_id)),
			"source_planet_name": str(packet.get("source_planet_name", result.get("planet_name", ""))),
			"silent": bool(packet.get("silent", false)),
			"queued_at_unix": int(packet.get("queued_at_unix", 0)),
			"queued_at_text": str(packet.get("queued_at_text", ""))
		}

	scan_state["orbit_event_discoveries_pending"] = pending
	orbit_snapshot["scan_state"] = scan_state


func record_orbit_planet_scan_result(result: Dictionary) -> void:
	var state := ensure_orbit_operations_state()
	var planet_id := str(result.get("planet_id", "")).strip_edges()
	var planet_scans = state.get("planet_scans", {})
	if typeof(planet_scans) != TYPE_DICTIONARY:
		planet_scans = {}

	if planet_id != "":
		planet_scans[planet_id] = {
			"operation_id": ORBIT_PLANET_SCAN_OPERATION_ID,
			"planet_id": planet_id,
			"planet_name": str(result.get("planet_name", "")),
			"scanned_at_unix": int(result.get("scanned_at_unix", 0)),
			"scanned_at_text": str(result.get("scanned_at_text", "")),
			"discoveries": result.get("discoveries", []).duplicate(true),
			"interactions": result.get("interactions", []).duplicate(true),
			"event_listeners": result.get("event_listeners", []).duplicate(true)
		}

	var history = state.get("history", [])
	if typeof(history) != TYPE_ARRAY:
		history = []
	history.append({
		"operation_id": ORBIT_PLANET_SCAN_OPERATION_ID,
		"planet_id": planet_id,
		"planet_name": str(result.get("planet_name", "")),
		"summary_line": str(result.get("summary_line", "")),
		"scanned_at_unix": int(result.get("scanned_at_unix", 0)),
		"scanned_at_text": str(result.get("scanned_at_text", ""))
	})
	while history.size() > 20:
		history.pop_front()

	state["planet_scans"] = planet_scans
	state["history"] = history
	orbit_snapshot["orbit_operations"] = state


func update_orbit_planet_scan_state(result: Dictionary) -> void:
	var scan_state = orbit_snapshot.get("scan_state", {})
	if typeof(scan_state) != TYPE_DICTIONARY:
		scan_state = {}

	var revealed_planets = scan_state.get("orbit_revealed_planets", {})
	if typeof(revealed_planets) != TYPE_DICTIONARY:
		revealed_planets = {}

	var planet_id := str(result.get("planet_id", "")).strip_edges()
	if planet_id != "":
		revealed_planets[planet_id] = {
			"planet_id": planet_id,
			"planet_name": str(result.get("planet_name", "")),
			"operation_id": ORBIT_PLANET_SCAN_OPERATION_ID,
			"discovered_at_unix": int(result.get("scanned_at_unix", 0)),
			"discovered_at_text": str(result.get("scanned_at_text", "")),
			"discovery_count": int(result.get("discovery_count", 0)),
			"interaction_count": int(result.get("interaction_count", 0)),
			"event_listener_count": int(result.get("event_listener_count", 0)),
			"visible_event_listener_count": int(result.get("visible_event_listener_count", 0)),
			"silent_event_listener_count": int(result.get("silent_event_listener_count", 0))
		}

	scan_state["orbit_revealed_planets"] = revealed_planets
	orbit_snapshot["scan_state"] = scan_state


func ensure_orbit_operations_state() -> Dictionary:
	var state = orbit_snapshot.get("orbit_operations", {})
	if typeof(state) != TYPE_DICTIONARY:
		state = {}

	state["schema"] = ORBIT_OPERATIONS_SCHEMA
	if not state.has("planet_surveys") or typeof(state.get("planet_surveys")) != TYPE_DICTIONARY:
		state["planet_surveys"] = {}
	if not state.has("history") or typeof(state.get("history")) != TYPE_ARRAY:
		state["history"] = []
	if not state.has("analysis_history") or typeof(state.get("analysis_history")) != TYPE_ARRAY:
		state["analysis_history"] = []
	if not state.has("planet_scans") or typeof(state.get("planet_scans")) != TYPE_DICTIONARY:
		state["planet_scans"] = {}
	if not state.has("planet_item_action_requests") or typeof(state.get("planet_item_action_requests")) != TYPE_ARRAY:
		state["planet_item_action_requests"] = []
	if not state.has("planet_item_action_completions") or typeof(state.get("planet_item_action_completions")) != TYPE_DICTIONARY:
		state["planet_item_action_completions"] = {}
	if not state.has("planet_resource_site_state") or typeof(state.get("planet_resource_site_state")) != TYPE_DICTIONARY:
		state["planet_resource_site_state"] = {}
	if not state.has("planet_item_action_result_history") or typeof(state.get("planet_item_action_result_history")) != TYPE_ARRAY:
		state["planet_item_action_result_history"] = []
	if not state.has("orbit_story_popup_reads") or typeof(state.get("orbit_story_popup_reads")) != TYPE_DICTIONARY:
		state["orbit_story_popup_reads"] = {}
	if not state.has("orbit_story_popup_read_history") or typeof(state.get("orbit_story_popup_read_history")) != TYPE_ARRAY:
		state["orbit_story_popup_read_history"] = []

	orbit_snapshot["orbit_operations"] = state
	return state


func request_local_ai_orbit_analysis(result: Dictionary) -> void:
	var fallback := build_fallback_orbit_analysis(result)
	if local_ai_talker == null:
		set_latest_reply_text("AMI> " + fallback)
		append_text_log("AMI_OFFLINE", fallback)
		record_orbit_analysis(fallback, {"backend": "deterministic_fallback"}, str(result.get("operation_id", ORBIT_SURVEY_OPERATION_ID)))
		return

	var prompt := build_orbit_analysis_prompt(result)
	pending_orbit_analysis = true
	pending_orbit_analysis_operation_id = str(result.get("operation_id", ORBIT_SURVEY_OPERATION_ID))
	pending_orbit_analysis_result = result.duplicate(true)
	var accepted := local_ai_talker.send_message(prompt, {
		"scene": "Orbit",
		"local_ai_role": "shipboard orbit analyst",
		"target_body": make_orbit_body_save_slice(orbit_target_body),
		"operation": result.duplicate(true),
		"snapshot_summary": build_snapshot_summary(orbit_snapshot),
		"rules": [
			"Game code owns state changes.",
			"Local AI interprets confirmed survey results.",
			"Do not invent rewards, item ids, or discoveries not present in the operation packet."
		]
	})
	if not accepted:
		pending_orbit_analysis = false
		pending_orbit_analysis_operation_id = ""
		pending_orbit_analysis_result = {}


func build_orbit_analysis_prompt(result: Dictionary) -> String:
	var operation_id := str(result.get("operation_id", ORBIT_SURVEY_OPERATION_ID))
	if operation_id == ORBIT_PLANET_SCAN_OPERATION_ID:
		return build_planet_scan_analysis_prompt(result)

	var target_name := str(result.get("planet_name", "this orbital body"))
	var revealed := int(result.get("revealed_contact_count", 0))
	var matched := int(result.get("matched_contact_count", 0))
	var names_text := join_limited_string_array(result.get("revealed_contact_names", []), 5)
	if names_text == "":
		names_text = join_limited_string_array(result.get("matched_contact_names", []), 5)
	var resource_text := format_resource_totals(result.get("resource_totals", {}), 6)
	if resource_text == "":
		resource_text = "no resource totals"

	return "Orbit survey complete for " + target_name + ". Confirmed " + str(matched) + " linked contacts and newly revealed " + str(revealed) + ". Contacts: " + names_text + ". Resources: " + resource_text + ". Give a short in-universe analyst readout and one practical next move."


func build_planet_scan_analysis_prompt(result: Dictionary) -> String:
	var target_name := str(result.get("planet_name", "this orbital body"))
	var role := str(result.get("planet_role", "unknown"))
	var population := str(result.get("population_state", "unknown"))
	var discovery_text := join_orbit_entry_titles(result.get("discoveries", []), "title", 6)
	if discovery_text == "":
		discovery_text = "no named discoveries"
	var discovery_detail_text := join_orbit_entry_summaries(result.get("discoveries", []), "title", 4)
	if discovery_detail_text == "":
		discovery_detail_text = "no authored discovery details"
	var interaction_text := join_orbit_entry_titles(result.get("interactions", []), "label", 6)
	if interaction_text == "":
		interaction_text = "no orbit interactions"
	var interaction_detail_text := join_orbit_entry_summaries(result.get("interactions", []), "label", 4)
	if interaction_detail_text == "":
		interaction_detail_text = "no authored interaction details"
	var event_signal_text := join_visible_orbit_event_listener_titles(result.get("event_listeners", []), 4)
	if event_signal_text == "":
		event_signal_text = "no visible event signals"
	return "Planet orbit scan complete for " + target_name + ". Role: " + role + ". Population: " + population + ". Discoveries: " + discovery_text + ". Discovery details: " + discovery_detail_text + ". Orbit interactions: " + interaction_text + ". Interaction details: " + interaction_detail_text + ". Visible event signals: " + event_signal_text + ". Give a short in-universe analyst readout and one practical next move. Do not invent rewards, item ids, surface sites, or events."


func build_fallback_orbit_analysis(result: Dictionary) -> String:
	var operation_id := str(result.get("operation_id", ORBIT_SURVEY_OPERATION_ID))
	if operation_id == ORBIT_PLANET_SCAN_OPERATION_ID:
		return build_fallback_planet_scan_analysis(result)

	var target_name := str(result.get("planet_name", "this orbit"))
	var revealed := int(result.get("revealed_contact_count", 0))
	var matched := int(result.get("matched_contact_count", 0))
	var resource_text := format_resource_totals(result.get("resource_totals", {}), 4)
	if matched <= 0:
		return target_name + " has no authored orbit-linked contacts in the current snapshot yet. This is a clean hook for authored Orbit items and planet-specific survey content."
	if revealed <= 0:
		return target_name + " has already-charted orbital contacts. Re-run confirms the local field and keeps the route data warm."
	if resource_text == "":
		return target_name + " revealed " + str(revealed) + " new orbital contacts. Plot one and inspect the contact before committing resources."
	return target_name + " revealed " + str(revealed) + " new orbital contacts. Resource signatures read " + resource_text + "; mark the richest contact as the next field objective."


func build_fallback_planet_scan_analysis(result: Dictionary) -> String:
	var target_name := str(result.get("planet_name", "this orbit"))
	var discoveries := int(result.get("discovery_count", 0))
	var interactions := int(result.get("interaction_count", 0))
	if discoveries <= 0 and interactions <= 0:
		return target_name + " has no authored planet-facing orbit data yet. This is the JSON hook for surface sites, contact channels, and orbit-only interactions."
	if interactions <= 0:
		return target_name + " returned " + str(discoveries) + " planet readings but no active orbit interactions. Good candidate for authored surface-site or contact-channel data."
	return target_name + " returned " + str(discoveries) + " readings and " + str(interactions) + " orbit interactions. Choose the interaction that best matches the planet role before spending resources."


func record_orbit_analysis(reply: String, packet: Dictionary, operation_id: String) -> void:
	var clean_reply := truncate_orbit_text(reply.strip_edges(), 900)
	if clean_reply == "":
		return

	var state := ensure_orbit_operations_state()
	var history = state.get("analysis_history", [])
	if typeof(history) != TYPE_ARRAY:
		history = []

	history.append({
		"operation_id": operation_id,
		"target_planet_id": get_orbit_body_id(orbit_target_body),
		"target_planet_name": get_orbit_body_display_name(orbit_target_body),
		"reply": clean_reply,
		"backend": str(packet.get("backend", "")),
		"created_at_unix": int(Time.get_unix_time_from_system()),
		"created_at_text": get_datetime_text()
	})
	while history.size() > 12:
		history.pop_front()

	state["analysis_history"] = history
	orbit_snapshot["orbit_operations"] = state


func resolve_orbit_target_body() -> Dictionary:
	for key in ["target_body", "orbit_target_body", "planet"]:
		var context_body = orbit_context.get(key, {})
		if typeof(context_body) == TYPE_DICTIONARY and not context_body.is_empty():
			return context_body.duplicate(true)

	var snapshot_body = orbit_snapshot.get("orbit_target_body", {})
	if typeof(snapshot_body) == TYPE_DICTIONARY and not snapshot_body.is_empty():
		return snapshot_body.duplicate(true)

	var planets := get_array_section(orbit_snapshot, "planets")
	if planets.is_empty():
		return {}

	var map_data := get_dictionary_section(orbit_snapshot, "map")
	if map_data.is_empty():
		var first_planet = planets[0]
		return first_planet.duplicate(true) if typeof(first_planet) == TYPE_DICTIONARY else {}

	var origin_sector := SharedObjectMeta.read_sector_pos(map_data.get("sector_pos", map_data.get("sector", Vector3i.ZERO)))
	var origin_local := SharedObjectMeta.read_local_pos(map_data.get("local_pos", map_data.get("local", Vector3.ZERO)))
	var best_planet := {}
	var best_distance := INF

	for planet in planets:
		if typeof(planet) != TYPE_DICTIONARY:
			continue
		var planet_sector := SharedObjectMeta.read_sector_pos(planet.get("sector_pos", planet.get("sector", Vector3i.ZERO)))
		var planet_local := SharedObjectMeta.read_local_pos(planet.get("local_pos", planet.get("local", Vector3.ZERO)))
		var distance := get_cross_sector_distance(origin_sector, origin_local, planet_sector, planet_local)
		if distance < best_distance:
			best_distance = distance
			best_planet = planet.duplicate(true)

	return best_planet


func make_orbit_body_save_slice(body: Dictionary) -> Dictionary:
	if body.is_empty():
		return {}

	var sector := SharedObjectMeta.read_sector_pos(body.get("sector_pos", body.get("sector", Vector3i.ZERO)))
	var local := SharedObjectMeta.read_local_pos(body.get("local_pos", body.get("local", Vector3.ZERO)))
	return {
		"object_id": get_orbit_body_id(body),
		"id": get_orbit_body_id(body),
		"object_type": str(body.get("object_type", "planet")),
		"display_name": get_orbit_body_display_name(body),
		"scan_name": str(body.get("scan_name", get_orbit_body_display_name(body))),
		"planet_type": str(body.get("planet_type", "")),
		"planet_role": str(body.get("planet_role", "")),
		"tier": int(body.get("tier", 1)),
		"sector_pos": SharedObjectMeta.vector3i_to_dict(sector),
		"local_pos": SharedObjectMeta.vector3_to_dict(local),
		"parent_star_name": str(body.get("parent_star_name", "")),
		"contact_text": str(body.get("contact_text", "")),
		"scan_description": str(body.get("scan_description", "")),
		"population_state": str(body.get("population_state", "")),
		"danger_level": int(body.get("danger_level", 0)),
		"resource_value": int(body.get("resource_value", 0)),
		"resources": get_dictionary_section(body, "resources"),
		"planet_resources": get_dictionary_section(body, "planet_resources"),
		"services": SharedObjectMeta.read_array(body.get("services", [])),
		"planet_board_events": SharedObjectMeta.read_array(body.get("planet_board_events", [])),
		"quest_messages": SharedObjectMeta.read_array(body.get("quest_messages", [])),
		"event_ids": SharedObjectMeta.read_array(body.get("event_ids", [])),
		"orbit_discoveries": SharedObjectMeta.read_array(body.get("orbit_discoveries", [])),
		"orbital_discoveries": SharedObjectMeta.read_array(body.get("orbital_discoveries", [])),
		"orbit_interactions": SharedObjectMeta.read_array(body.get("orbit_interactions", [])),
		"orbital_interactions": SharedObjectMeta.read_array(body.get("orbital_interactions", [])),
		"orbit_event_listeners": SharedObjectMeta.read_array(body.get("orbit_event_listeners", [])),
		"orbit_discovered_event_listeners": SharedObjectMeta.read_array(body.get("orbit_discovered_event_listeners", [])),
		"orbital_event_listeners": SharedObjectMeta.read_array(body.get("orbital_event_listeners", [])),
		"orbit_surface_sites": SharedObjectMeta.read_array(body.get("orbit_surface_sites", [])),
		"planet_surface_sites": SharedObjectMeta.read_array(body.get("planet_surface_sites", [])),
		"surface_sites": SharedObjectMeta.read_array(body.get("surface_sites", [])),
		"surface_buildings": SharedObjectMeta.read_array(body.get("surface_buildings", [])),
		"orbit_resource_sites": SharedObjectMeta.read_array(body.get("orbit_resource_sites", [])),
		"planet_resource_sites": SharedObjectMeta.read_array(body.get("planet_resource_sites", [])),
		"planet_surface_resources": SharedObjectMeta.read_array(body.get("planet_surface_resources", [])),
		"surface_resources": SharedObjectMeta.read_array(body.get("surface_resources", [])),
		"orbit_discoveries_found": SharedObjectMeta.read_array(body.get("orbit_discoveries_found", [])),
		"orbit_interactions_available": SharedObjectMeta.read_array(body.get("orbit_interactions_available", [])),
		"orbit_event_listeners_found": SharedObjectMeta.read_array(body.get("orbit_event_listeners_found", [])),
		"orbit_planet_scanned": bool(body.get("orbit_planet_scanned", false)),
		"orbit_planet_scanned_at_unix": int(body.get("orbit_planet_scanned_at_unix", 0)),
		"orbit_planet_scanned_at_text": str(body.get("orbit_planet_scanned_at_text", ""))
	}


func get_orbit_body_id(body: Dictionary) -> String:
	return str(body.get("object_id", body.get("id", ""))).strip_edges()


func get_orbit_body_display_name(body: Dictionary) -> String:
	if body.is_empty():
		return "Unknown Orbit"
	var display_name := str(body.get("display_name", body.get("scan_name", get_orbit_body_id(body)))).strip_edges()
	return display_name if display_name != "" else "Unknown Orbit"


func build_orbit_target_meta_text(body: Dictionary) -> String:
	var parts := []
	var planet_type := str(body.get("planet_type", body.get("object_type", "planet"))).strip_edges()
	var planet_role := str(body.get("planet_role", "survey_target")).strip_edges()
	var tier := int(body.get("tier", 1))
	if planet_type != "":
		parts.append(planet_type.replace("_", " ").to_upper())
	if planet_role != "":
		parts.append(planet_role.replace("_", " ").to_upper())
	parts.append("TIER " + str(tier))
	return " | ".join(parts)


func build_orbit_target_description(body: Dictionary) -> String:
	var contact_text := str(body.get("contact_text", "")).strip_edges()
	if contact_text != "":
		return contact_text
	var scan_description := str(body.get("scan_description", "")).strip_edges()
	if scan_description != "":
		return scan_description
	return "Orbital operations are available for this planet."


func build_orbit_operation_result_text(result: Dictionary) -> String:
	var operation_id := str(result.get("operation_id", ORBIT_SURVEY_OPERATION_ID))
	if operation_id == ORBIT_PLANET_SCAN_OPERATION_ID:
		return build_planet_scan_result_text(result)
	if str(result.get("operation_kind", "")) in ["explore", "recover_to_orbit"]:
		return build_orbit_item_operation_result_text(result)
	return build_orbit_survey_result_text(result)


func build_orbit_item_operation_result_text(result: Dictionary) -> String:
	if result.is_empty():
		return "No orbit item operation run yet."
	var lines := [str(result.get("summary_line", result.get("reason", "Orbit item operation finished.")))]
	var consumed := format_resource_totals(result.get("consumed_items", {}), 5)
	if consumed != "":
		lines.append("Consumed: " + consumed)
	var granted := format_resource_totals(result.get("granted_items", {}), 6)
	if granted != "":
		lines.append("Recovered: " + granted)
	lines.append("Status: " + str(result.get("status", "unknown")).replace("_", " "))
	return "\n".join(lines)


func build_orbit_survey_result_text(result: Dictionary) -> String:
	if result.is_empty():
		return "No survey run yet."
	if not bool(result.get("ok", false)):
		return str(result.get("summary_line", result.get("reason", "Survey failed.")))

	var lines := [
		str(result.get("summary_line", "Orbit survey complete."))
	]
	var contacts := join_limited_string_array(result.get("revealed_contact_names", []), 5)
	if contacts == "":
		contacts = join_limited_string_array(result.get("matched_contact_names", []), 5)
	if contacts != "":
		lines.append("Contacts: " + contacts)
	var resources := format_resource_totals(result.get("resource_totals", {}), 6)
	if resources != "":
		lines.append("Resources: " + resources)
	if int(result.get("matched_contact_count", 0)) <= 0:
		lines.append("Authoring note: no planet-linked orbital contacts are present yet.")
	return "\n".join(lines)


func build_planet_scan_result_text(result: Dictionary) -> String:
	if result.is_empty():
		return "No planet scan run yet."
	if not bool(result.get("ok", false)):
		return str(result.get("summary_line", result.get("reason", "Planet scan failed.")))

	var lines := [
		str(result.get("summary_line", "Planet scan complete."))
	]
	var discoveries := join_orbit_entry_titles(result.get("discoveries", []), "title", 5)
	if discoveries != "":
		lines.append("Discoveries: " + discoveries)
	var interactions := join_orbit_entry_titles(result.get("interactions", []), "label", 5)
	if interactions != "":
		lines.append("Orbit actions: " + interactions)
	var event_signals := join_visible_orbit_event_listener_titles(result.get("event_listeners", []), 4)
	if event_signals != "":
		lines.append("Event signals: " + event_signals)
	if int(result.get("discovery_count", 0)) <= 0 and int(result.get("interaction_count", 0)) <= 0:
		lines.append("Authoring note: add JSON orbit discoveries, interactions, or surface sites for this planet.")
	return "\n".join(lines)


func build_orbit_survey_summary_line(result: Dictionary) -> String:
	var target_name := str(result.get("planet_name", "Orbit"))
	var matched := int(result.get("matched_contact_count", 0))
	var revealed := int(result.get("revealed_contact_count", 0))
	var already := int(result.get("already_discovered_count", 0))
	if matched <= 0:
		return target_name + " survey found no authored orbit-linked contacts."
	return target_name + " survey confirmed " + str(matched) + " contacts; " + str(revealed) + " newly revealed, " + str(already) + " already known."


func build_planet_scan_summary_line(result: Dictionary) -> String:
	var target_name := str(result.get("planet_name", "Planet"))
	var discoveries := int(result.get("discovery_count", 0))
	var interactions := int(result.get("interaction_count", 0))
	return target_name + " scan found " + str(discoveries) + " planet readings and " + str(interactions) + " orbit actions."


func get_space_object_id(object_data: Dictionary, fallback_id: String = "") -> String:
	var object_id := str(object_data.get("object_id", object_data.get("id", fallback_id))).strip_edges()
	return object_id if object_id != "" else fallback_id


func get_space_object_display_name(object_data: Dictionary, fallback_name: String = "Object") -> String:
	var display_name := str(object_data.get("display_name", object_data.get("scan_name", fallback_name))).strip_edges()
	return display_name if display_name != "" else fallback_name


func read_orbit_label_array(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	if str(value).strip_edges() != "":
		return [str(value)]
	return []


func get_cross_sector_distance(origin_sector: Vector3i, origin_local: Vector3, target_sector: Vector3i, target_local: Vector3) -> float:
	var sector_size := 999.0
	var sector_size_value = Globals.get("sector_size")
	if sector_size_value != null:
		sector_size = float(sector_size_value)

	var sector_delta := Vector3(
		float(target_sector.x - origin_sector.x) * sector_size,
		float(target_sector.y - origin_sector.y) * sector_size,
		float(target_sector.z - origin_sector.z) * sector_size
	)
	return (sector_delta + (target_local - origin_local)).length()


func format_resource_totals(raw_totals, max_items: int = 5) -> String:
	if typeof(raw_totals) != TYPE_DICTIONARY:
		return ""
	var totals: Dictionary = raw_totals
	if totals.is_empty():
		return ""

	var keys := totals.keys()
	keys.sort()
	var parts := []
	for key in keys:
		if parts.size() >= max_items:
			break
		var item_id := str(key).strip_edges()
		var amount := int(totals.get(key, 0))
		if item_id == "" or amount <= 0:
			continue
		parts.append(item_id.replace("_", " ") + " x" + str(amount))
	return ", ".join(parts)


func join_limited_string_array(value, max_items: int = 5) -> String:
	if typeof(value) != TYPE_ARRAY:
		return ""

	var parts := []
	for item in value:
		if parts.size() >= max_items:
			break
		var text := str(item).strip_edges()
		if text != "":
			parts.append(text)
	return ", ".join(parts)


func join_orbit_entry_titles(value, title_key: String, max_items: int = 5) -> String:
	if typeof(value) != TYPE_ARRAY:
		return ""

	var parts := []
	for item in value:
		if parts.size() >= max_items:
			break
		if typeof(item) == TYPE_DICTIONARY:
			var entry: Dictionary = item
			var text := str(entry.get(title_key, entry.get("title", entry.get("label", entry.get("id", ""))))).strip_edges()
			if text != "":
				parts.append(text)
		else:
			var text := str(item).strip_edges()
			if text != "":
				parts.append(text)
	return ", ".join(parts)


func join_orbit_entry_summaries(value, title_key: String, max_items: int = 4) -> String:
	if typeof(value) != TYPE_ARRAY:
		return ""

	var parts := []
	for item in value:
		if parts.size() >= max_items:
			break
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var title := str(entry.get(title_key, entry.get("title", entry.get("label", entry.get("display_name", entry.get("id", "")))))).strip_edges()
		var summary := str(entry.get("summary", entry.get("scan_summary", entry.get("description", "")))).strip_edges()
		var hint := str(entry.get("local_ai_hint", "")).strip_edges()
		var text := title
		if summary != "":
			text += ": " + summary
		if hint != "":
			text += " Hint: " + hint
		text = text.strip_edges()
		if text != "":
			parts.append(text)
	return " | ".join(parts)


func join_visible_orbit_event_listener_titles(value, max_items: int = 4) -> String:
	if typeof(value) != TYPE_ARRAY:
		return ""

	var parts := []
	for item in value:
		if parts.size() >= max_items:
			break
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		if not bool(entry.get("visible_in_orbit", not bool(entry.get("silent", false)))):
			continue
		var text := str(entry.get("display_name", entry.get("title", entry.get("event_id", entry.get("trigger_event_id", ""))))).strip_edges()
		if text != "":
			parts.append(text)
	return ", ".join(parts)


func truncate_orbit_text(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return text.substr(0, max_chars) + "...[truncated]"


func debug_print(message: String) -> void:
	print(DEBUG_PREFIX + " " + message)


func get_log_time_text() -> String:
	var date := Time.get_datetime_dict_from_system()
	return "%02d:%02d:%02d" % [
		int(date.get("hour", 0)),
		int(date.get("minute", 0)),
		int(date.get("second", 0))
	]


func _on_exit_button_pressed() -> void:
	if exit_in_progress:
		return

	exit_in_progress = true
	var save_result := save_orbit_snapshot_as_truth()
	Globals.orbit_last_save_result = save_result
	Globals.clear_orbit_transition_state(true)
	Globals.startup_mode = "load"
	get_tree().change_scene_to_file(MAIN_MODE_SCENE_PATH)


func save_orbit_item_operation_truth(reason: String) -> Dictionary:
	var snapshot := get_snapshot_for_save()
	if snapshot.is_empty():
		return {
			"ok": false,
			"reason": "Orbit item operation snapshot was empty."
		}

	var meta = snapshot.get("orbit_snapshot_meta", {})
	if typeof(meta) != TYPE_DICTIONARY:
		meta = {}
	meta["last_runtime_save_at_unix"] = int(Time.get_unix_time_from_system())
	meta["last_runtime_save_at_text"] = get_datetime_text()
	meta["last_runtime_save_reason"] = reason
	snapshot["orbit_snapshot_meta"] = meta

	var universe_saved := false
	if save_manager != null and save_manager.has_method("write_universe_save_data"):
		universe_saved = bool(save_manager.write_universe_save_data(snapshot))

	var inventory_saved := true
	var inventory_data = snapshot.get("inventory", {})
	if typeof(inventory_data) == TYPE_DICTIONARY and save_manager != null and save_manager.has_method("save_inventory_runtime_section_from_data"):
		inventory_saved = bool(save_manager.save_inventory_runtime_section_from_data(inventory_data))

	return {
		"ok": universe_saved and inventory_saved,
		"universe_saved": universe_saved,
		"inventory_runtime_saved": inventory_saved,
		"reason": "" if universe_saved and inventory_saved else "Orbit item operation did not fully persist."
	}


func save_orbit_snapshot_as_truth() -> Dictionary:
	var snapshot := get_snapshot_for_save()
	if snapshot.is_empty():
		return {
			"ok": false,
			"reason": "Orbit snapshot was empty and no autosave fallback was available."
		}

	stamp_snapshot_for_exit(snapshot)

	var universe_saved := false
	if save_manager != null and save_manager.has_method("write_universe_save_data"):
		universe_saved = bool(save_manager.write_universe_save_data(snapshot))

	# Inventory has a runtime companion file that overrides the universe section
	# during load, so Orbit must update both copies after item consumption/recovery.
	var inventory_saved := true
	var inventory_data = snapshot.get("inventory", {})
	if typeof(inventory_data) == TYPE_DICTIONARY and save_manager != null and save_manager.has_method("save_inventory_runtime_section_from_data"):
		inventory_saved = bool(save_manager.save_inventory_runtime_section_from_data(inventory_data))
	var saved := universe_saved and inventory_saved

	var result := {
		"ok": saved,
		"reason": "" if saved else "Orbit universe or inventory runtime save returned false.",
		"universe_saved": universe_saved,
		"inventory_runtime_saved": inventory_saved,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"saved_at_text": get_datetime_text(),
		"summary": build_snapshot_summary(snapshot)
	}

	if not saved:
		push_error("Orbit exit failed to save snapshot as universe truth.")

	return result


func get_snapshot_for_save() -> Dictionary:
	if not orbit_snapshot.is_empty():
		return orbit_snapshot.duplicate(true)

	if save_manager != null and save_manager.has_method("read_universe_save_data"):
		var data = save_manager.read_universe_save_data()
		if typeof(data) == TYPE_DICTIONARY:
			return data.duplicate(true)

	return {}


func stamp_snapshot_for_exit(snapshot: Dictionary) -> void:
	var meta := {}
	if typeof(snapshot.get("orbit_snapshot_meta", {})) == TYPE_DICTIONARY:
		meta = snapshot.get("orbit_snapshot_meta", {}).duplicate(true)

	meta["schema"] = str(meta.get("schema", ORBIT_SNAPSHOT_SCHEMA))
	meta["saved_as_truth_at_unix"] = int(Time.get_unix_time_from_system())
	meta["saved_as_truth_at_text"] = get_datetime_text()
	meta["saved_as_truth_source"] = "Orbit.exit_button"
	meta["summary"] = build_snapshot_summary(snapshot)
	snapshot["orbit_snapshot_meta"] = meta


func get_datetime_text() -> String:
	if save_manager != null and save_manager.has_method("get_current_datetime_text"):
		return str(save_manager.get_current_datetime_text())

	var date := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(date.get("year", 0)),
		int(date.get("month", 0)),
		int(date.get("day", 0)),
		int(date.get("hour", 0)),
		int(date.get("minute", 0)),
		int(date.get("second", 0))
	]


func build_snapshot_summary(snapshot: Dictionary) -> Dictionary:
	var enemies_packet = snapshot.get("enemies", {})
	var enemy_count := 0
	if typeof(enemies_packet) == TYPE_DICTIONARY:
		var enemies = enemies_packet.get("enemies", [])
		if typeof(enemies) == TYPE_ARRAY:
			enemy_count = enemies.size()
	elif typeof(enemies_packet) == TYPE_ARRAY:
		enemy_count = enemies_packet.size()

	return {
		"stars": get_array_section(snapshot, "stars").size(),
		"space_objects": get_array_section(snapshot, "space_objects").size(),
		"npcs": get_array_section(snapshot, "npcs").size(),
		"enemies": enemy_count,
		"beacons": get_array_section(snapshot, "beacons").size(),
		"planets": get_array_section(snapshot, "planets").size(),
		"has_map": not get_dictionary_section(snapshot, "map").is_empty(),
		"has_inventory": not get_dictionary_section(snapshot, "inventory").is_empty(),
		"has_player_state": not get_dictionary_section(snapshot, "player_state").is_empty()
	}


func get_array_section(source: Dictionary, section_name: String) -> Array:
	var value = source.get(section_name, [])
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return []


func get_dictionary_section(source: Dictionary, section_name: String) -> Dictionary:
	var value = source.get(section_name, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return {}
