extends Control
class_name MainUIHandler

signal main_ui_event_received(match_id: String, packet: Dictionary)

const BattleV2EffectLayerScript = preload("res://battle_v2/BattleV2EffectLayer.gd")
const BattlePathTrailScript = preload("res://battle_v2/ui_fx/BattlePathTrail.gd")
const UIHandlerHelpersScript = preload("res://UI/UIHandlerHelpers.gd")

const TOP_LAYER_Z_INDEX := 520
const SAVE_COVER_Z_INDEX := 4096
# Keep this just under MainModeLoadScreenHandler.layer = 4096. That loader owns
# boot/loading takeover; this save curtain should beat normal HUD/UI layers.
const SAVE_COVER_CANVAS_LAYER := 4095
const HISTORY_LIMIT := 100

const MATCH_GUIDE_PROMPT := "main_ui_guide_prompt"
const MATCH_FLASH_POINT := "main_ui_flash_point"

const MATCH_BREATHING_ENERGY_FRAME := "main_ui_breathing_energy_frame"
const MATCH_CLEAR_BREATHING_ENERGY_FRAME := "main_ui_clear_breathing_energy_frame"
const FS_ENERGY_FRAME_COLOR := Color(0.34, 0.88, 1.0, 0.44)
const FRAME_REFRESH_INTERVAL := 0.35
const MAIN_HUD_BREATH_AMOUNT := 0.0075
const MAIN_HUD_ALPHA_PULSE_SCALE := 0.5

const MAIN_HUD_ENERGY_FRAME_POINTS := [
	"log_panel",
	"star_distance_panel",
	"blueprint_panel",
	"coords_panel",
	"inventory_panel",
	"action_panel",
	"todo_panel",
	"ami_report_panel",
	"ami_star_chart_panel",
	"event_panel",
	"port_window",
	"main_command_menu_frame",
	"live_map",
	"player_stats_panel",
	"enemy_stats_panel"
]

func show_energy_frame_for_point(point_id: String, extra_data: Dictionary = {}) -> Dictionary:
	var clean_point_id := point_id.strip_edges()
	if Globals.print_priority_3:
		print("DEBUG ENERGY FRAME | show_energy_frame_for_point | point_id = ", clean_point_id)
	if clean_point_id == "":
		return {
			"status": "failed",
			"reason": "missing point_id",
			"effect_kind": "breathing_energy_frame"
		}

	return receive_ui_event(MATCH_BREATHING_ENERGY_FRAME, build_energy_frame_packet(clean_point_id, extra_data))


func refresh_energy_frame_for_point(point_id: String, extra_data: Dictionary = {}) -> Dictionary:
	var clean_point_id := point_id.strip_edges()
	if clean_point_id == "":
		return {
			"status": "failed",
			"reason": "missing point_id",
			"effect_kind": "breathing_energy_frame"
		}
	ensure_effect_layer()
	if effect_layer == null:
		return {"status": "failed", "reason": "missing effect layer"}
	if effect_layer.has_method("set_breathing_energy_frame"):
		return effect_layer.set_breathing_energy_frame(build_energy_frame_packet(clean_point_id, extra_data))
	return {
		"status": "failed",
		"reason": "effect layer missing set_breathing_energy_frame"
	}


func show_ami_star_chart_compact_energy_frame(extra_data: Dictionary = {}) -> Dictionary:
	return show_compact_only_energy_frame_for_point("ami_star_chart_panel", extra_data)


func refresh_ami_star_chart_compact_energy_frame(extra_data: Dictionary = {}) -> Dictionary:
	return refresh_compact_only_energy_frame_for_point("ami_star_chart_panel", extra_data)


func clear_ami_star_chart_compact_energy_frame() -> Dictionary:
	return clear_energy_frame_for_point("ami_star_chart_panel")


func show_compact_only_energy_frame_for_point(point_id: String, extra_data: Dictionary = {}) -> Dictionary:
	refresh_position_data()
	var per_point_data := extra_data.duplicate(true)
	apply_main_hud_frame_style(point_id, per_point_data)
	if should_hide_energy_frame_point(point_id, {}):
		per_point_data["state"] = "hidden"
	return show_energy_frame_for_point(point_id, per_point_data)


func refresh_compact_only_energy_frame_for_point(point_id: String, extra_data: Dictionary = {}) -> Dictionary:
	refresh_position_data()
	var per_point_data := extra_data.duplicate(true)
	apply_main_hud_frame_style(point_id, per_point_data)
	if should_hide_energy_frame_point(point_id, {}):
		per_point_data["state"] = "hidden"
	return refresh_energy_frame_for_point(point_id, per_point_data)


func build_energy_frame_packet(clean_point_id: String, extra_data: Dictionary = {}) -> Dictionary:
	var packet := {
		"effect_match_id": clean_point_id + "_energy_frame",
		"point_id": clean_point_id,
		"base_color": FS_ENERGY_FRAME_COLOR,
		"state": "active",
		"duration": -1.0,
		"padding": 5.0,
		"thickness": 2.0,
		"glow_thickness": 5.0,
		"breath_speed": 1.15,
		"breath_amount": MAIN_HUD_BREATH_AMOUNT,
		"alpha_pulse_scale": MAIN_HUD_ALPHA_PULSE_SCALE,
		"particle_speed": 0.28,
		"particle_count": 1,
		"particle_size": 5.0,
		"tags": ["main_ui", "energy_frame", clean_point_id]
	}

	for key in extra_data.keys():
		packet[key] = extra_data[key]

	return packet


func show_all_main_hud_energy_frames(extra_data: Dictionary = {}) -> Array:
	var results: Array = []
	main_hud_frames_enabled = true
	refresh_position_data()
	var occupied_frame_rects := {}

	for point_id in MAIN_HUD_ENERGY_FRAME_POINTS:
		var per_point_data := extra_data.duplicate(true)
		apply_main_hud_frame_style(point_id, per_point_data)
		if should_hide_energy_frame_point(point_id, occupied_frame_rects):
			per_point_data["state"] = "hidden"

		results.append(show_energy_frame_for_point(point_id, per_point_data))

	return results


func refresh_all_main_hud_energy_frames(extra_data: Dictionary = {}) -> Array:
	var results: Array = []
	refresh_position_data()
	var occupied_frame_rects := {}

	for point_id in MAIN_HUD_ENERGY_FRAME_POINTS:
		var per_point_data := extra_data.duplicate(true)
		apply_main_hud_frame_style(point_id, per_point_data)
		if should_hide_energy_frame_point(point_id, occupied_frame_rects):
			per_point_data["state"] = "hidden"

		results.append(refresh_energy_frame_for_point(point_id, per_point_data))

	return results


func apply_main_hud_frame_style(point_id: String, frame_data: Dictionary) -> void:
	frame_data["particle_count"] = int(frame_data.get("particle_count", 1))

	match point_id:
		"log_panel":
			frame_data["state"] = frame_data.get("state", "quiet")
			frame_data["breath_speed"] = frame_data.get("breath_speed", 0.80)
			frame_data["particle_speed"] = frame_data.get("particle_speed", 0.18)
		"port_window":
			frame_data["state"] = frame_data.get("state", "quiet")
			frame_data["breath_speed"] = frame_data.get("breath_speed", 0.85)
			frame_data["particle_speed"] = frame_data.get("particle_speed", 0.20)
		"live_map", "inventory_panel", "star_distance_panel", "coords_panel":
			frame_data["state"] = frame_data.get("state", "quiet")
			frame_data["breath_speed"] = frame_data.get("breath_speed", 0.95)
			frame_data["particle_speed"] = frame_data.get("particle_speed", 0.24)
		"drive_panel", "blueprint_panel":
			frame_data["state"] = frame_data.get("state", "active")
			frame_data["breath_speed"] = frame_data.get("breath_speed", 1.05)
			frame_data["particle_speed"] = frame_data.get("particle_speed", 0.27)
		"event_panel":
			frame_data["state"] = frame_data.get("state", "active")
			frame_data["breath_speed"] = frame_data.get("breath_speed", 1.25)
			frame_data["particle_speed"] = frame_data.get("particle_speed", 0.34)
		"action_panel":
			frame_data["state"] = frame_data.get("state", "active")
			frame_data["breath_speed"] = frame_data.get("breath_speed", 1.20)
			frame_data["particle_speed"] = frame_data.get("particle_speed", 0.32)
		"todo_panel":
			frame_data["state"] = frame_data.get("state", "active")
			frame_data["breath_speed"] = frame_data.get("breath_speed", 1.10)
			frame_data["particle_speed"] = frame_data.get("particle_speed", 0.30)
		"ami_report_panel":
			frame_data["state"] = frame_data.get("state", "quiet")
			frame_data["breath_speed"] = frame_data.get("breath_speed", 0.92)
			frame_data["particle_speed"] = frame_data.get("particle_speed", 0.22)
			frame_data["base_color"] = frame_data.get("base_color", Color(0.38, 0.90, 1.0, 0.42))
		"ami_star_chart_panel":
			frame_data["state"] = frame_data.get("state", "quiet")
			frame_data["breath_speed"] = frame_data.get("breath_speed", 0.92)
			frame_data["particle_speed"] = frame_data.get("particle_speed", 0.22)
			frame_data["base_color"] = frame_data.get("base_color", Color(0.38, 0.90, 1.0, 0.42))
		"player_stats_panel", "enemy_stats_panel":
			frame_data["state"] = frame_data.get("state", "quiet")
			frame_data["breath_speed"] = frame_data.get("breath_speed", 0.95)
			frame_data["particle_speed"] = frame_data.get("particle_speed", 0.22)
		_:
			frame_data["state"] = frame_data.get("state", "quiet")
			frame_data["breath_speed"] = frame_data.get("breath_speed", 0.95)
			frame_data["particle_speed"] = frame_data.get("particle_speed", 0.24)

func clear_energy_frame_for_point(point_id: String) -> Dictionary:
	var clean_point_id := point_id.strip_edges()
	if clean_point_id == "":
		return {
			"status": "failed",
			"reason": "missing point_id",
			"effect_kind": "breathing_energy_frame"
		}

	return receive_ui_event(MATCH_CLEAR_BREATHING_ENERGY_FRAME, {
		"effect_match_id": clean_point_id + "_energy_frame",
		"point_id": clean_point_id
	})


func clear_all_main_hud_energy_frames() -> Array:
	var results: Array = []
	main_hud_frames_enabled = false

	for point_id in MAIN_HUD_ENERGY_FRAME_POINTS:
		results.append(clear_energy_frame_for_point(point_id))

	return results


func show_saving_cover(message: String = "Saving", reason: String = "save") -> Dictionary:
	ensure_saving_cover()
	if saving_cover_root == null or not is_instance_valid(saving_cover_root):
		return {"status": "failed", "reason": "saving cover unavailable"}

	var clean_message := message.strip_edges()
	if clean_message == "":
		clean_message = "Saving"

	saving_cover_label.text = clean_message
	saving_cover_root.visible = true
	_resize_saving_cover()
	if saving_cover_layer != null and is_instance_valid(saving_cover_layer):
		saving_cover_layer.layer = SAVE_COVER_CANVAS_LAYER
		move_child(saving_cover_layer, get_child_count() - 1)
	saving_cover_root.move_to_front()
	saving_cover_root.grab_focus()

	print("[MAIN_UI_SAVE_COVER] show reason=", reason, " message=", clean_message)
	print("[MAIN_UI_SAVE_COVER] state=", get_saving_cover_debug_state())
	print("[MAIN_UI_SAVE_COVER] canvas_layers=", collect_canvas_layer_debug())

	flush_saving_cover_draw()
	return {
		"status": "success",
		"reason": reason,
		"message": clean_message
	}


func hide_saving_cover(reason: String = "save_done") -> void:
	if saving_cover_root == null or not is_instance_valid(saving_cover_root):
		return
	saving_cover_root.visible = false
	print("[MAIN_UI_SAVE_COVER] hide reason=", reason)


func hide_saving_cover_deferred(reason: String = "save_done") -> void:
	call_deferred("hide_saving_cover", reason)


func get_saving_cover_debug_state() -> Dictionary:
	var state := {
		"handler_inside_tree": is_inside_tree(),
		"handler_path": str(get_path()) if is_inside_tree() else "",
		"layer_valid": saving_cover_layer != null and is_instance_valid(saving_cover_layer),
		"root_valid": saving_cover_root != null and is_instance_valid(saving_cover_root),
		"label_valid": saving_cover_label != null and is_instance_valid(saving_cover_label)
	}
	if saving_cover_layer != null and is_instance_valid(saving_cover_layer):
		state["layer_path"] = str(saving_cover_layer.get_path()) if saving_cover_layer.is_inside_tree() else ""
		state["layer"] = saving_cover_layer.layer
		state["layer_parent"] = str(saving_cover_layer.get_parent().name) if saving_cover_layer.get_parent() != null else ""
	if saving_cover_root != null and is_instance_valid(saving_cover_root):
		state["root_path"] = str(saving_cover_root.get_path()) if saving_cover_root.is_inside_tree() else ""
		state["visible"] = saving_cover_root.visible
		state["visible_in_tree"] = saving_cover_root.is_visible_in_tree()
		state["position"] = saving_cover_root.position
		state["size"] = saving_cover_root.size
		state["z_index"] = saving_cover_root.z_index
		state["top_level"] = saving_cover_root.top_level
		state["z_as_relative"] = saving_cover_root.z_as_relative
		state["mouse_filter"] = saving_cover_root.mouse_filter
		state["parent"] = str(saving_cover_root.get_parent().name) if saving_cover_root.get_parent() != null else ""
	if saving_cover_label != null and is_instance_valid(saving_cover_label):
		state["label_text"] = saving_cover_label.text
	return state


func collect_canvas_layer_debug(limit: int = 24) -> Array:
	var output: Array = []
	if not is_inside_tree():
		return output
	var tree := get_tree()
	if tree == null or tree.root == null:
		return output
	append_canvas_layer_debug(tree.root, output, limit)
	return output


func append_canvas_layer_debug(node: Node, output: Array, limit: int) -> void:
	if node == null or output.size() >= limit:
		return
	if node is CanvasLayer:
		var canvas_layer := node as CanvasLayer
		output.append({
			"path": str(canvas_layer.get_path()) if canvas_layer.is_inside_tree() else "",
			"name": str(canvas_layer.name),
			"layer": canvas_layer.layer,
			"visible": canvas_layer.visible
		})

	for child in node.get_children():
		if output.size() >= limit:
			return
		append_canvas_layer_debug(child, output, limit)


func ensure_saving_cover() -> void:
	if saving_cover_root != null and is_instance_valid(saving_cover_root):
		return

	if saving_cover_layer == null or not is_instance_valid(saving_cover_layer):
		saving_cover_layer = CanvasLayer.new()
		saving_cover_layer.name = "MainUISavingCoverLayer"
		saving_cover_layer.layer = SAVE_COVER_CANVAS_LAYER
		add_child(saving_cover_layer)

	saving_cover_root = ColorRect.new()
	saving_cover_root.name = "MainUISavingCover"
	saving_cover_root.color = Color(0.0, 0.015, 0.035, 0.94)
	saving_cover_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	saving_cover_root.mouse_filter = Control.MOUSE_FILTER_STOP
	saving_cover_root.focus_mode = Control.FOCUS_ALL
	saving_cover_root.show_behind_parent = false
	saving_cover_root.z_index = SAVE_COVER_Z_INDEX
	saving_cover_root.z_as_relative = false
	saving_cover_root.visible = false
	saving_cover_layer.add_child(saving_cover_root)

	var center := CenterContainer.new()
	center.name = "SavingCoverCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	saving_cover_root.add_child(center)

	saving_cover_label = Label.new()
	saving_cover_label.name = "SavingCoverLabel"
	saving_cover_label.text = "Saving"
	saving_cover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	saving_cover_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	saving_cover_label.add_theme_font_size_override("font_size", 34)
	saving_cover_label.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0, 1.0))
	saving_cover_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.20, 0.36, 0.9))
	saving_cover_label.add_theme_constant_override("shadow_offset_x", 0)
	saving_cover_label.add_theme_constant_override("shadow_offset_y", 2)
	center.add_child(saving_cover_label)

	_resize_saving_cover()


func _resize_saving_cover() -> void:
	if saving_cover_root == null or not is_instance_valid(saving_cover_root):
		return
	var viewport_size := Vector2(float(Globals.screen_w), float(Globals.screen_h))
	if get_viewport() != null:
		viewport_size = get_viewport().get_visible_rect().size
	saving_cover_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	saving_cover_root.position = Vector2.ZERO
	saving_cover_root.size = viewport_size


func flush_saving_cover_draw() -> void:
	# Lets the cover appear before a synchronous disk write when the renderer supports it.
	RenderingServer.force_draw()

var MAIN_DECORATION_POINTS = {
	"scene_top_layer": {
		"position": Vector2(0, 0),
		"size": Vector2(Globals.screen_w, Globals.screen_h),
		"purpose": "full-screen main overlay root"
	},

	"log_panel": {
		"control_key": "log_root",
		"position": Globals.log_widg_pos,
		"size": Globals.log_widget_size,
		"purpose": "main log widget"
	},

	"action_panel": {
		"control_key": "action_root",
		"position": Globals.action_pos,
		"size": Globals.action_widget_size,
		"purpose": "main action widget"
	},

	"todo_panel": {
		"control_key": "todo_root",
		"position": Globals.get_stacked_todo_pos(),
		"size": Globals.todo_widget_size,
		"purpose": "main TODO widget"
	},

	"ami_report_panel": {
		"control_key": "ami_report_root",
		"position": Globals.get_stacked_todo_pos() + Vector2(Globals.todo_widget_size.x + 10.0, 0.0),
		"size": Vector2(292.0, clamp(float(Globals.todo_widget_size.y), 148.0, 178.0)),
		"purpose": "AMI Report player state widget"
	},

	"ami_star_chart_panel": {
		"control_key": "ami_star_chart_root",
		"position": Globals.ami_star_chart_widget_pos,
		"size": Globals.ami_star_chart_widget_size,
		"purpose": "AMI Star Chart compact flat map widget"
	},

	"event_panel": {
		"control_key": "event_root",
		"position": Globals.get_event_widget_pos(),
		"size": Globals.event_widget_size,
		"purpose": "main event widget"
	},

	"blueprint_panel": {
		"control_key": "blueprint_root",
		"position": Globals.get_blueprint_widget_pos(),
		"size": Globals.blueprint_widget_size,
		"purpose": "blueprint crafting widget"
	},

	"star_distance_panel": {
		"control_key": "sd",
		"position": Globals.star_dis_widg_pos,
		"size": Globals.star_distance_widget_size,
		"purpose": "star distance widget"
	},

	"drive_panel": {
		"control_key": "drive_root",
		"position": Globals.eng_widg_pos,
		"size": Vector2(225, 250),
		"purpose": "hidden transitional drive control widget"
	},

	"coords_panel": {
		"control_key": "coords_root",
		"position": Globals.map_widg_pos,
		"size": Globals.nav_widget_size,
		"purpose": "navigation status widget"
	},

	"inventory_panel": {
		"control_key": "label_inventory_root",
		"position": Globals.inv_i_widg_pos,
		"size": Globals.inventory_widget_size,
		"purpose": "inventory widget"
	},

	"port_window": {
		"control_key": "port_window",
		"position": Globals.get_port_window_widget_pos(),
		"size": Globals.port_window_widget_size,
		"purpose": "forward port widget"
	},

	"main_command_menu_frame": {
		"control_key": "main_command_menu_root",
		"position": Globals.get_port_window_widget_pos() + Vector2(0, Globals.port_window_widget_size.y + 8.0),
		"size": Vector2(Globals.port_window_widget_size.x, 54),
		"purpose": "main command submenu frame"
	},

	"main_command_menu_button": {
		"control_key": "main_command_menu_button",
		"position": Globals.get_port_window_widget_pos() + Vector2(10, Globals.port_window_widget_size.y + 28.0),
		"size": Vector2(Globals.port_window_widget_size.x - 20, 28),
		"purpose": "Sub Menu command button"
	},

	"live_map": {
		"control_key": "live_map_control",
		"position": Globals.live_map_widg_pos,
		"size": Globals.inventory_widget_size,
		"purpose": "live map radar widget"
	},

	"player_stats_panel": {
		"control_key": "player_stats_root",
		"position": Globals.star_dis_widg_pos,
		"size": Vector2(350, 125),
		"purpose": "player stats widget"
	},

	"enemy_stats_panel": {
		"control_key": "enemy_stats_root",
		"position": Globals.star_dis_widg_pos + Vector2(0, 135),
		"size": Vector2(350, 125),
		"purpose": "enemy stats widget"
	},

	"coord_popup": {
		"control_key": "coord_auto_pilot_root",
		"position": Vector2(0, 0),
		"size": Vector2(300, 220),
		"purpose": "coordinate autopilot popup"
	}
}

var main_scene_ref = null
var gui_state = null
var label_refs: Dictionary = {}
var control_refs: Dictionary = {}
var source_refs: Dictionary = {}
var latest_by_match_id: Dictionary = {}
var event_history: Array = []
var latest_guide_packet: Dictionary = {}
var effect_layer: BattleV2EffectLayer = null
var guide_trail: BattlePathTrail = null
var ui_helpers = UIHandlerHelpersScript.new()
var position_data: Dictionary = {}
var main_hud_frames_enabled := false
var frame_refresh_elapsed := 0.0
var saving_cover_layer: CanvasLayer = null
var saving_cover_root: ColorRect = null
var saving_cover_label: Label = null


func _ready() -> void:
	name = "Main_UI_Handler"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = TOP_LAYER_Z_INDEX
	z_as_relative = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(Globals.screen_w, Globals.screen_h)
	set_process(true)


func _process(delta: float) -> void:
	if not main_hud_frames_enabled:
		return
	frame_refresh_elapsed += delta
	if frame_refresh_elapsed < FRAME_REFRESH_INTERVAL:
		return
	frame_refresh_elapsed = 0.0
	refresh_all_main_hud_energy_frames()


func setup(refs: Dictionary) -> void:
	source_refs = refs.duplicate(false)
	main_scene_ref = refs.get("main_scene", main_scene_ref)
	gui_state = refs.get("gui_state", gui_state)
	if refs.get("ui_helpers", null) != null:
		ui_helpers = refs.get("ui_helpers")
	if typeof(refs.get("labels", {})) == TYPE_DICTIONARY:
		label_refs = refs.get("labels", {}).duplicate(true)
	control_refs = build_control_refs(refs)
	refresh_position_data()
	ensure_effect_layer()
	ensure_saving_cover()
	if bool(refs.get("autostart_guide_trail", true)):
		ensure_guide_trail()


func build_control_refs(refs: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	if typeof(refs.get("controls", {})) == TYPE_DICTIONARY:
		output = refs.get("controls", {}).duplicate(true)
	if typeof(refs.get("log_storage", {})) == TYPE_DICTIONARY:
		for key in refs.get("log_storage", {}).keys():
			output[key] = refs.get("log_storage", {}).get(key)
	if typeof(refs.get("action_storage", {})) == TYPE_DICTIONARY:
		for key in refs.get("action_storage", {}).keys():
			if key == "root":
				output["action_root"] = refs.get("action_storage", {}).get(key)
			else:
				output["action_" + str(key)] = refs.get("action_storage", {}).get(key)
	merge_direct_control_ref(output, "live_map_control", refs.get("live_map_control", null))
	merge_direct_control_ref(output, "port_window", refs.get("port_window", null))
	merge_direct_control_ref(output, "port_window_backdrop", refs.get("port_window_backdrop", null))
	merge_direct_control_ref(output, "main_command_menu_root", refs.get("main_command_menu_root", null))
	merge_direct_control_ref(output, "main_command_menu_button", refs.get("main_command_menu_button", null))
	merge_direct_control_ref(output, "inventory_root", refs.get("inventory_root", null))
	merge_direct_control_ref(output, "drone_bay_root", refs.get("drone_bay_root", null))
	merge_direct_control_ref(output, "label_inventory_root", refs.get("label_inventory_root", null))
	return output


func merge_direct_control_ref(output: Dictionary, key: String, value) -> void:
	if value == null:
		return
	if value is Object and not is_instance_valid(value):
		return
	output[key] = value


func refresh_control_refs_from_sources() -> void:
	var refs := source_refs.duplicate(false)

	if gui_state != null:
		if typeof(gui_state.controls) == TYPE_DICTIONARY:
			refs["controls"] = gui_state.controls
		if typeof(gui_state.log_storage) == TYPE_DICTIONARY:
			refs["log_storage"] = gui_state.log_storage
		if typeof(gui_state.action_storage) == TYPE_DICTIONARY:
			refs["action_storage"] = gui_state.action_storage

	if main_scene_ref != null and is_instance_valid(main_scene_ref):
		var current_live_map = null
		var inv_radar_panel = main_scene_ref.get("inv_radar_panel")
		if inv_radar_panel != null:
			current_live_map = inv_radar_panel.get("live_map_control")
		if current_live_map != null:
			refs["live_map_control"] = current_live_map
		refs["port_window"] = main_scene_ref.get("port_window_widget")
		refs["port_window_backdrop"] = main_scene_ref.get("port_window_backdrop")
		refs["main_command_menu_root"] = main_scene_ref.get("main_command_menu_root")
		refs["main_command_menu_button"] = main_scene_ref.get("main_command_menu_button")
		var inventory_ref = main_scene_ref.get("inventory")
		if inventory_ref != null:
			refs["inventory_root"] = inventory_ref.get("inventory_root")
			refs["drone_bay_root"] = inventory_ref.get("drone_bay_root")
			refs["label_inventory_root"] = inventory_ref.get("label_inventory_root")

	control_refs = build_control_refs(refs)


func refresh_position_data() -> void:
	refresh_control_refs_from_sources()
	position_data = ui_helpers.build_position_data_from_controls(MAIN_DECORATION_POINTS, control_refs)
	apply_main_hud_position_adjustments()
	if effect_layer != null:
		effect_layer.position_data = position_data.duplicate(true)


func apply_main_hud_position_adjustments() -> void:
	if position_data.has("star_distance_panel"):
		var point: Dictionary = position_data["star_distance_panel"]
		point["size"] = point.get("size", Vector2.ZERO) + Vector2(0, 10)
		position_data["star_distance_panel"] = point


func is_point_visible(point_id: String) -> bool:
	if not MAIN_DECORATION_POINTS.has(point_id):
		return true
	var spec: Dictionary = MAIN_DECORATION_POINTS.get(point_id, {})
	var control_key := str(spec.get("control_key", "")).strip_edges()
	if control_key == "":
		return true
	if not control_refs.has(control_key):
		return false
	var control = control_refs.get(control_key)
	if control == null or (control is Object and not is_instance_valid(control)):
		return false
	if control is CanvasItem:
		return control.is_visible_in_tree()
	return true


func is_ami_star_chart_compact_frame_visible() -> bool:
	if not control_refs.has("ami_star_chart_root"):
		return false
	var control = control_refs.get("ami_star_chart_root")
	if control == null or (control is Object and not is_instance_valid(control)):
		return false
	if not (control is Control):
		return false
	var chart_root: Control = control as Control
	if not chart_root.is_visible_in_tree():
		return false

	# FullFlatMapHandler expands by resizing the same root.
	# Keep this frame compact-only so the expanded overlay does not get a giant HUD frame.
	var compact_size := Globals.ami_star_chart_widget_size
	var size_epsilon := 4.0
	if abs(chart_root.size.x - compact_size.x) > size_epsilon:
		return false
	if abs(chart_root.size.y - compact_size.y) > size_epsilon:
		return false
	return true


func should_hide_energy_frame_point(point_id: String, occupied_frame_rects: Dictionary) -> bool:
	if not is_point_visible(point_id):
		return true
	if not position_data.has(point_id):
		return true
	if point_id == "ami_star_chart_panel" and not is_ami_star_chart_compact_frame_visible():
		return true

	var rect_key := get_energy_frame_rect_key(point_id)
	if rect_key == "":
		return false
	if occupied_frame_rects.has(rect_key):
		return true
	occupied_frame_rects[rect_key] = point_id
	return false


func get_energy_frame_rect_key(point_id: String) -> String:
	if not position_data.has(point_id):
		return ""
	var point: Dictionary = position_data.get(point_id, {})
	var pos: Vector2 = point.get("position", Vector2.ZERO)
	var point_size: Vector2 = point.get("size", Vector2.ZERO)
	if point_size == Vector2.ZERO:
		return ""
	return str(round(pos.x)) + ":" + str(round(pos.y)) + ":" + str(round(point_size.x)) + ":" + str(round(point_size.y))


func ensure_effect_layer() -> void:
	if effect_layer != null:
		return
	effect_layer = BattleV2EffectLayerScript.new()
	effect_layer.name = "Main_UI_Effect_Layer"
	effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effect_layer)
	effect_layer.setup({
		"position_data": position_data,
		"size": Vector2(Globals.screen_w, Globals.screen_h),
		"z_index": TOP_LAYER_Z_INDEX + 100
	})


func ensure_guide_trail() -> void:
	if guide_trail != null:
		return
	guide_trail = BattlePathTrailScript.new()
	guide_trail.name = "MainGuideTrail"
	guide_trail.path_file = "res://data/battle_ui_paths/battle_log_wobble_trace.json"
	guide_trail.loop_path = true
	guide_trail.autostart = true
	guide_trail.draw_debug_path = false
	guide_trail.z_index = TOP_LAYER_Z_INDEX + 240
	add_child(guide_trail)


func receive_ui_event(match_id: String, packet: Dictionary = {}) -> Dictionary:
	
	var normalized_packet = ui_helpers.build_normalized_packet(
		match_id,
		packet,
		"main_mode",
		get_position_data(),
		get_current_header_state()
	)
	latest_by_match_id[match_id] = normalized_packet
	event_history.append(normalized_packet)
	ui_helpers.trim_array_to_limit(event_history, HISTORY_LIMIT)
	if Globals.print_priority_3:
		print("DEBUG ENERGY FRAME | receive_ui_event | match_id = ", match_id)
		print("DEBUG ENERGY FRAME | receive_ui_event | normalized_packet = ", normalized_packet)
	match match_id:
		MATCH_GUIDE_PROMPT:
			show_guidance_prompt(normalized_packet)
		MATCH_FLASH_POINT:
			flash_point(normalized_packet)
		MATCH_BREATHING_ENERGY_FRAME:
			show_breathing_energy_frame(normalized_packet)
			if Globals.print_priority_3:
				print("DEBUG ENERGY FRAME | matched breathing energy frame route")
		MATCH_CLEAR_BREATHING_ENERGY_FRAME:
			handle_clear_breathing_energy_frame(normalized_packet)
		_:
			pass
		

	main_ui_event_received.emit(match_id, normalized_packet)
	return normalized_packet


func show_guidance_prompt(packet: Dictionary) -> Dictionary:
	ensure_guide_trail()
	if guide_trail == null:
		return {"status": "failed", "reason": "missing guide trail"}

	refresh_position_data()
	var prompt_packet := packet.duplicate(true)
	var target_point_id := str(prompt_packet.get("target_point_id", "")).strip_edges()
	if target_point_id != "" and not prompt_packet.has("target_position"):
		prompt_packet["target_position"] = get_point_center(target_point_id)

	var line_to_point_id := str(prompt_packet.get("line_to_point_id", "")).strip_edges()
	if line_to_point_id != "" and not prompt_packet.has("line_to_position"):
		prompt_packet["line_to_position"] = get_point_center(line_to_point_id)

	latest_guide_packet = prompt_packet.duplicate(true)
	guide_trail.show_guidance_packet(prompt_packet)
	return {"status": "success", "match_id": MATCH_GUIDE_PROMPT}


func show_tutorial_hint(text: String, target_point_id: String = "log_panel", extra_data: Dictionary = {}) -> Dictionary:
	var packet := extra_data.duplicate(true)
	packet["text"] = text
	packet["target_point_id"] = target_point_id
	return receive_ui_event(MATCH_GUIDE_PROMPT, packet)


func flash_point(packet: Dictionary) -> void:
	ensure_effect_layer()
	var point_id := str(packet.get("point_id", "")).strip_edges()
	if point_id == "":
		return
	effect_layer.flash_box(
		point_id,
		packet.get("color", Color(0.2, 0.85, 1.0, 0.70)),
		float(packet.get("duration", 0.55)),
		float(packet.get("thickness", 4.0)),
		float(packet.get("pulse_speed", 18.0)),
		float(packet.get("padding", 4.0)),
		str(packet.get("effect_kind", "main_ui_flash_point"))
	)

func show_breathing_energy_frame(packet: Dictionary) -> Dictionary:
	if Globals.print_priority_3:
		print("DEBUG ENERGY FRAME | show_breathing_energy_frame called | packet = ", packet)
	ensure_effect_layer()
	if effect_layer == null:
		return {"status": "failed", "reason": "missing effect layer"}

	refresh_position_data()

	if effect_layer.has_method("set_breathing_energy_frame"):
		return effect_layer.set_breathing_energy_frame(packet)

	return {
		"status": "failed",
		"reason": "effect layer missing set_breathing_energy_frame"
	}



func get_position_data() -> Dictionary:
	return position_data.duplicate(true)


func get_point_center(point_id: String) -> Vector2:
	return ui_helpers.get_point_center(position_data, point_id, Vector2(Globals.screen_w, Globals.screen_h) * 0.5)


func get_current_header_state() -> Dictionary:
	return {
		"log_text": ui_helpers.get_label_text(control_refs, "log_text"),
		"points": get_position_data()
	}


func clear_ui_event_history() -> void:
	latest_by_match_id.clear()
	event_history.clear()
	latest_guide_packet.clear()
	if effect_layer != null:
		effect_layer.clear_all_effects()


func handle_clear_breathing_energy_frame(packet: Dictionary) -> Dictionary:
	ensure_effect_layer()
	if effect_layer == null:
		return {"status": "failed", "reason": "missing effect layer"}

	var effect_match_id := str(packet.get("effect_match_id", "")).strip_edges()
	if effect_match_id == "":
		effect_match_id = str(packet.get("frame_id", "")).strip_edges()
	if effect_match_id == "":
		effect_match_id = str(packet.get("point_id", "")).strip_edges() + "_breathing_energy_frame"

	if effect_layer.has_method("clear_breathing_energy_frame_by_id"):
		return effect_layer.clear_breathing_energy_frame_by_id(effect_match_id)

	return {
		"status": "failed",
		"reason": "effect layer missing clear_breathing_energy_frame_by_id"
	}
