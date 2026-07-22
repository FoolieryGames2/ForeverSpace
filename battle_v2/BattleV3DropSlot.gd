extends Button
class_name BattleV3DropSlot

signal item_dropped(lane_id: String, item_id: String, item_data: Dictionary)

var lane_id: String = ""
var accepted_tab: String = ""
var display_prefix: String = ""


func setup(new_lane_id: String, new_accepted_tab: String, new_display_prefix: String) -> void:
	lane_id = new_lane_id.strip_edges().to_lower()
	accepted_tab = new_accepted_tab.strip_edges().to_lower()
	display_prefix = new_display_prefix
	add_theme_font_size_override("font_size", 10)


func set_slot_text(display_name: String) -> void:
	var clean_name := display_name.strip_edges()
	if clean_name == "":
		clean_name = "empty"
	text = display_prefix + ": " + clean_name


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false

	var drag_data: Dictionary = data
	if str(drag_data.get("type", "")) != "battle_v3_item":
		return false

	return str(drag_data.get("battle_tab", "")).strip_edges().to_lower() == accepted_tab


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return

	var drag_data: Dictionary = data
	var dropped_item_id := str(drag_data.get("item_id", "")).strip_edges()
	if dropped_item_id == "":
		return

	var dropped_item_data: Dictionary = {}
	if typeof(drag_data.get("item_data", {})) == TYPE_DICTIONARY:
		dropped_item_data = drag_data.get("item_data", {}).duplicate(true)
	item_dropped.emit(lane_id, dropped_item_id, dropped_item_data)
