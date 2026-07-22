extends Control

class_name BattleV3PipelineWidget

const DEFAULT_SIZE := Vector2(460, 425)
const PLAYER_SIDE := "player"
const ENEMY_SIDE := "enemy"

var title_label: Label = null
var drone_status_label: Label = null
var finish_label: Label = null
var player_lane_back: ColorRect = null
var enemy_lane_back: ColorRect = null
var player_lane_label: Label = null
var enemy_lane_label: Label = null
var player_finish_line: ColorRect = null
var enemy_finish_line: ColorRect = null
var slot_labels: Dictionary = {}
var chip_nodes: Dictionary = {}
var player_lane_rect := Rect2()
var enemy_lane_rect := Rect2()
var lane_intervention_handler: Callable = Callable()


func setup(_config: Dictionary = {}) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	if size.x <= 0.0 or size.y <= 0.0:
		size = DEFAULT_SIZE
	custom_minimum_size = size
	build_static_ui()


func build_static_ui() -> void:
	var local_size := get_local_widget_size()

	var back := ColorRect.new()
	back.name = "Battle_V3_Pipeline_Back"
	back.position = Vector2.ZERO
	back.size = local_size
	back.color = Color(0.025, 0.035, 0.045, 0.96)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	title_label = make_label(
		"Battle_V3_Pipeline_Title",
		"BATTLE V3 PIPELINE",
		Vector2(10, 6),
		Vector2(185, 18),
		13,
		Color(0.82, 0.95, 0.92, 1.0)
	)
	drone_status_label = make_label(
		"Battle_V3_Drone_Status",
		"Drones: none",
		Vector2(200, 6),
		Vector2(local_size.x - 210, 18),
		11,
		Color(0.94, 0.80, 0.44, 1.0)
	)

	build_slot_labels(local_size)
	build_lanes(local_size)


func build_slot_labels(local_size: Vector2) -> void:
	var slot_y := 28.0
	var slot_h := 17.0
	var slot_gap := 6.0
	var slot_w := (local_size.x - 26.0) * 0.5
	slot_labels["primary"] = make_slot_label("primary", "PRI: --", Vector2(10, slot_y), Vector2(slot_w, slot_h))
	slot_labels["secondary"] = make_slot_label("secondary", "SEC: --", Vector2(16 + slot_w, slot_y), Vector2(slot_w, slot_h))
	slot_labels["consumable"] = make_slot_label("consumable", "CON: --", Vector2(10, slot_y + slot_h + slot_gap), Vector2(slot_w, slot_h))
	slot_labels["drone"] = make_slot_label("drone", "DRN: --", Vector2(16 + slot_w, slot_y + slot_h + slot_gap), Vector2(slot_w, slot_h))


func make_slot_label(slot_id: String, text: String, pos: Vector2, label_size: Vector2) -> Label:
	return make_label(
		"Battle_V3_Slot_" + slot_id,
		text,
		pos,
		label_size,
		10,
		Color(0.74, 0.84, 0.86, 1.0)
	)


func build_lanes(local_size: Vector2) -> void:
	var lane_top := 76.0
	var lane_bottom_pad := 17.0
	var lane_h = max(local_size.y - lane_top - lane_bottom_pad, 62.0)
	var lane_gap := 10.0
	var lane_w := (local_size.x - 30.0 - lane_gap) * 0.5

	player_lane_rect = Rect2(Vector2(10, lane_top), Vector2(lane_w, lane_h))
	enemy_lane_rect = Rect2(Vector2(20 + lane_w, lane_top), Vector2(lane_w, lane_h))

	player_lane_back = make_lane_back("Battle_V3_Player_Lane", player_lane_rect, Color(0.05, 0.12, 0.12, 0.88))
	enemy_lane_back = make_lane_back("Battle_V3_Enemy_Lane", enemy_lane_rect, Color(0.14, 0.065, 0.06, 0.88))

	player_lane_label = make_label(
		"Battle_V3_Player_Lane_Label",
		"PLAYER",
		player_lane_rect.position + Vector2(8, 4),
		Vector2(player_lane_rect.size.x - 16, 14),
		10,
		Color(0.63, 0.94, 0.82, 1.0)
	)
	enemy_lane_label = make_label(
		"Battle_V3_Enemy_Lane_Label",
		"ENEMY",
		enemy_lane_rect.position + Vector2(8, 4),
		Vector2(enemy_lane_rect.size.x - 16, 14),
		10,
		Color(0.98, 0.66, 0.58, 1.0)
	)

	player_finish_line = make_finish_line("Battle_V3_Player_Finish", player_lane_rect)
	enemy_finish_line = make_finish_line("Battle_V3_Enemy_Finish", enemy_lane_rect)
	finish_label = make_label(
		"Battle_V3_Finish_Label",
		"FINISH",
		Vector2(10, local_size.y - 15),
		Vector2(local_size.x - 20, 12),
		9,
		Color(0.88, 0.88, 0.78, 1.0)
	)
	finish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func make_lane_back(lane_name: String, lane_rect: Rect2, lane_color: Color) -> ColorRect:
	var lane := ColorRect.new()
	lane.name = lane_name
	lane.position = lane_rect.position
	lane.size = lane_rect.size
	lane.color = lane_color
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lane)
	return lane


func make_finish_line(line_name: String, lane_rect: Rect2) -> ColorRect:
	var line := ColorRect.new()
	line.name = line_name
	line.position = lane_rect.position + Vector2(6, lane_rect.size.y - 9)
	line.size = Vector2(lane_rect.size.x - 12, 2)
	line.color = Color(0.96, 0.82, 0.44, 0.9)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	return line


func make_label(label_name: String, text: String, pos: Vector2, label_size: Vector2, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.position = pos
	label.size = label_size
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	add_child(label)
	return label


func set_snapshot(snapshot: Dictionary) -> void:
	if title_label != null:
		title_label.text = str(snapshot.get("title", "BATTLE V3 PIPELINE"))
	if drone_status_label != null:
		drone_status_label.text = "Drones: " + str(snapshot.get("drone_status", "none"))

	var slots: Dictionary = {}
	if typeof(snapshot.get("slots", {})) == TYPE_DICTIONARY:
		slots = snapshot.get("slots", {})
	set_slot_text("primary", "PRI: " + str(slots.get("primary", "--")))
	set_slot_text("secondary", "SEC: " + str(slots.get("secondary", "--")))
	set_slot_text("consumable", "CON: " + str(slots.get("consumable", "--")))
	set_slot_text("drone", "DRN: " + str(slots.get("drone", "--")))

	var events: Array = []
	if typeof(snapshot.get("events", [])) == TYPE_ARRAY:
		events = snapshot.get("events", [])
	update_action_chips(events)


func set_lane_intervention_handler(handler: Callable) -> void:
	lane_intervention_handler = handler


func listen_for_lane_intervention(intervention_packet: Dictionary) -> Dictionary:
	# Summary: Reusable lane listener hook for Evade now and future target/effect interventions later.
	if not lane_intervention_handler.is_valid():
		return {
			"accepted": false,
			"blocked_reason": "missing_lane_intervention_handler"
		}

	var packet := intervention_packet.duplicate(true)
	if str(packet.get("target_side", "")).strip_edges() == "":
		return {
			"accepted": false,
			"blocked_reason": "missing_target_side"
		}
	return lane_intervention_handler.call(packet)


func set_slot_text(slot_id: String, text: String) -> void:
	if not slot_labels.has(slot_id):
		return
	var label: Label = slot_labels[slot_id] as Label
	if label == null:
		return
	label.text = text


func get_widget_spec_refs() -> Dictionary:
	# Summary: Expose static pipeline nodes so Battle V2 can store proper widget metadata without changing timing logic.
	var labels := {}
	if title_label != null and is_instance_valid(title_label):
		labels["Battle_V3_Pipeline_Title"] = title_label
	if drone_status_label != null and is_instance_valid(drone_status_label):
		labels["Battle_V3_Drone_Status"] = drone_status_label
	if player_lane_label != null and is_instance_valid(player_lane_label):
		labels["Battle_V3_Player_Lane_Label"] = player_lane_label
	if enemy_lane_label != null and is_instance_valid(enemy_lane_label):
		labels["Battle_V3_Enemy_Lane_Label"] = enemy_lane_label
	if finish_label != null and is_instance_valid(finish_label):
		labels["Battle_V3_Finish_Label"] = finish_label
	for slot_id in slot_labels.keys():
		var slot_label = slot_labels[slot_id]
		if slot_label is Label:
			labels["Battle_V3_Slot_" + str(slot_id)] = slot_label

	var color_rects := {}
	var back = get_node_or_null("Battle_V3_Pipeline_Back")
	if back is ColorRect:
		color_rects["Battle_V3_Pipeline_Back"] = back
	if player_lane_back != null and is_instance_valid(player_lane_back):
		color_rects["Battle_V3_Player_Lane"] = player_lane_back
	if enemy_lane_back != null and is_instance_valid(enemy_lane_back):
		color_rects["Battle_V3_Enemy_Lane"] = enemy_lane_back
	if player_finish_line != null and is_instance_valid(player_finish_line):
		color_rects["Battle_V3_Player_Finish"] = player_finish_line
	if enemy_finish_line != null and is_instance_valid(enemy_finish_line):
		color_rects["Battle_V3_Enemy_Finish"] = enemy_finish_line

	return {
		"controls": {
			"Battle_V3_Pipeline_Widget": self
		},
		"color_rects": color_rects,
		"labels": labels
	}


func update_action_chips(events: Array) -> void:
	var visible_ids: Array = []
	var side_index := {
		PLAYER_SIDE: 0,
		ENEMY_SIDE: 0
	}

	for event_summary in events:
		if typeof(event_summary) != TYPE_DICTIONARY:
			continue
		var event_id := str(event_summary.get("event_id", "")).strip_edges()
		if event_id == "":
			continue
		visible_ids.append(event_id)

		var side := str(event_summary.get("event_side", "player")).strip_edges().to_lower()
		if side != ENEMY_SIDE:
			side = PLAYER_SIDE
		var lane_rect := enemy_lane_rect if side == ENEMY_SIDE else player_lane_rect
		var index := int(side_index.get(side, 0))
		side_index[side] = index + 1

		var chip := ensure_chip(event_id)
		place_chip(chip, event_summary, lane_rect, index, side)

	for existing_id in chip_nodes.keys():
		if visible_ids.has(existing_id):
			continue
		var chip_data: Dictionary = chip_nodes[existing_id]
		var root = chip_data.get("root", null)
		if root != null:
			root.queue_free()
		chip_nodes.erase(existing_id)


func ensure_chip(event_id: String) -> Dictionary:
	if chip_nodes.has(event_id):
		return chip_nodes[event_id]

	var root := Control.new()
	root.name = "Battle_V3_Chip_" + sanitize_node_name(event_id)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = Vector2(120, 24)
	add_child(root)

	var back := ColorRect.new()
	back.name = "Chip_Back"
	back.position = Vector2.ZERO
	back.size = root.size
	back.color = Color(0.18, 0.42, 0.38, 0.96)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)

	var label := Label.new()
	label.name = "Chip_Label"
	label.position = Vector2(6, 2)
	label.size = root.size - Vector2(12, 4)
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.95, 0.98, 0.96, 1.0))
	root.add_child(label)

	var chip := {
		"root": root,
		"back": back,
		"label": label
	}
	chip_nodes[event_id] = chip
	return chip


func place_chip(chip: Dictionary, event_summary: Dictionary, lane_rect: Rect2, side_index: int, side: String) -> void:
	var root: Control = chip.get("root", null)
	var back: ColorRect = chip.get("back", null)
	var label: Label = chip.get("label", null)
	if root == null or back == null or label == null:
		return

	var chip_size := Vector2(max(lane_rect.size.x - 16, 80.0), 23.0)
	var progress = clamp(float(event_summary.get("progress", 0.0)), 0.0, 1.0)
	var start_y := lane_rect.position.y + 22.0
	var finish_y := lane_rect.position.y + lane_rect.size.y - chip_size.y - 12.0
	var chip_y = lerp(start_y, finish_y, progress)
	var x_nudge := float(side_index % 2) * 5.0
	root.position = Vector2(lane_rect.position.x + 8.0 + x_nudge, chip_y)
	root.size = chip_size
	back.size = chip_size
	label.size = chip_size - Vector2(12, 4)
	label.text = get_chip_text(event_summary)
	back.color = get_chip_color(event_summary, side)
	root.modulate = get_chip_modulate(event_summary)
	root.visible = true


func get_chip_text(event_summary: Dictionary) -> String:
	var display_text := str(event_summary.get("display_text", event_summary.get("event_type", "action")))
	var time_remaining = max(float(event_summary.get("time_remaining", 0.0)), 0.0)
	if str(event_summary.get("resolution_gate_state", "")).strip_edges().to_lower() == "null":
		display_text = "NULL " + display_text
	return display_text + " | " + ("%0.1f" % time_remaining) + "s"


func get_chip_color(event_summary: Dictionary, side: String) -> Color:
	var group := str(event_summary.get("event_group", "")).strip_edges().to_lower()
	if group == "drone":
		return Color(0.70, 0.51, 0.16, 0.97)
	if group == "evade":
		return Color(0.22, 0.38, 0.68, 0.97)
	if group == "shield":
		return Color(0.36, 0.58, 0.65, 0.97)
	if group == "recharge":
		return Color(0.12, 0.58, 1.0, 0.97)
	if group == "repair":
		return Color(0.38, 0.48, 0.23, 0.97)
	if group == "consumable":
		var marker_text := (
			str(event_summary.get("event_type", "")) + " " +
			str(event_summary.get("item_id", "")) + " " +
			str(event_summary.get("subtype", "")) + " " +
			str(event_summary.get("consumable_group", "")) + " " +
			str(event_summary.get("labels", [])) + " " +
			str(event_summary.get("tags", [])) + " " +
			str(event_summary.get("data", {}))
		).to_lower()

		if marker_text.find("recharge") >= 0 or marker_text.find("energy_restore") >= 0 or marker_text.find("capacitor") >= 0:
			return Color(0.12, 0.58, 1.0, 0.97)
		if marker_text.find("repair") >= 0 or marker_text.find("repair_hull") >= 0:
			return Color(0.38, 0.48, 0.23, 0.97)
		return Color(0.30, 0.36, 0.38, 0.97)
	if side == ENEMY_SIDE:
		return Color(0.63, 0.24, 0.20, 0.97)
	return Color(0.16, 0.46, 0.39, 0.97)


func get_chip_modulate(event_summary: Dictionary) -> Color:
	if str(event_summary.get("resolution_gate_state", "")).strip_edges().to_lower() == "null":
		return Color(0.62, 0.62, 0.62, 0.72)
	return Color.WHITE


func sanitize_node_name(value: String) -> String:
	var clean := value.strip_edges()
	for token in [" ", ":", "/", "\\", ".", "|", "[", "]", "(", ")"]:
		clean = clean.replace(token, "_")
	return clean


func get_local_widget_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	if custom_minimum_size.x > 0.0 and custom_minimum_size.y > 0.0:
		return custom_minimum_size
	return DEFAULT_SIZE
