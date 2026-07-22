extends Button
class_name BattleV3ItemRefButton

var item_id: String = ""
var item_data: Dictionary = {}
var battle_tab: String = ""


func setup(new_item_id: String, new_item_data: Dictionary, new_battle_tab: String, label_text: String) -> void:
	item_id = new_item_id.strip_edges()
	item_data = new_item_data.duplicate(true)
	battle_tab = new_battle_tab.strip_edges().to_lower()
	text = label_text
	add_theme_font_size_override("font_size", 10)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id == "":
		return null

	var preview := Label.new()
	preview.text = text
	preview.size = Vector2(210, 24)
	preview.add_theme_font_size_override("font_size", 10)
	set_drag_preview(preview)

	return {
		"type": "battle_v3_item",
		"item_id": item_id,
		"item_data": item_data.duplicate(true),
		"battle_tab": battle_tab
	}
