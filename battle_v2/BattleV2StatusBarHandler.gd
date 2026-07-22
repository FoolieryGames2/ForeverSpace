extends RefCounted

class_name BattleV2StatusBarHandler

const DEFAULT_MAX := 1.0

var bars: Dictionary = {}


func bind_bar(bar_id: String, refs: Dictionary) -> void:
	var clean_id := bar_id.strip_edges()
	if clean_id == "":
		return
	bars[clean_id] = refs.duplicate()


func paint_value_bar(bar_id: String, packet: Dictionary) -> void:
	var refs := get_bar_refs(bar_id)
	if refs.is_empty():
		return

	var root := get_control_ref(refs, "root")
	var fill := get_color_rect_ref(refs, "fill")
	var queued := get_color_rect_ref(refs, "queued")
	var spent := get_color_rect_ref(refs, "spent")
	var label := get_label_ref(refs, "label")
	if root == null or fill == null:
		return

	var current = max(float(packet.get("current", 0.0)), 0.0)
	var max_value = max(float(packet.get("max", DEFAULT_MAX)), 0.0)
	var ratio := 0.0
	if max_value > 0.0:
		ratio = clamp(current / max_value, 0.0, 1.0)

	var size := get_bar_size(root)
	fill.position = Vector2.ZERO
	fill.size = Vector2(size.x * ratio, size.y)
	fill.color = packet.get("fill_color", fill.color)
	fill.visible = fill.size.x > 0.0

	if queued != null:
		queued.visible = false
		queued.size = Vector2.ZERO
	if spent != null:
		spent.visible = false
		spent.size = Vector2.ZERO

	if label != null:
		var text := str(packet.get("text", ""))
		if text == "":
			text = str(packet.get("label", "VALUE")) + " " + whole(current) + "/" + whole(max_value)
		label.text = text


func paint_energy_bar(bar_id: String, packet: Dictionary) -> void:
	var refs := get_bar_refs(bar_id)
	if refs.is_empty():
		return

	var root := get_control_ref(refs, "root")
	var available := get_color_rect_ref(refs, "fill")
	var queued := get_color_rect_ref(refs, "queued")
	var spent := get_color_rect_ref(refs, "spent")
	var label := get_label_ref(refs, "label")
	if root == null or available == null or queued == null or spent == null:
		return

	var max_value = max(float(packet.get("max", DEFAULT_MAX)), 0.0)
	var current = clamp(float(packet.get("current", 0.0)), 0.0, max_value)
	var queued_value = max(float(packet.get("queued", 0.0)), 0.0)
	var spent_value = max(float(packet.get("spent", max_value - current)), 0.0)
	var available_value = max(float(packet.get("available", current - queued_value)), 0.0)
	var size := get_bar_size(root)

	var queued_width := 0.0
	var available_width := 0.0
	var spent_width := 0.0
	if max_value > 0.0:
		queued_width = clamp(queued_value / max_value, 0.0, 1.0) * size.x
		available_width = clamp(available_value / max_value, 0.0, 1.0) * size.x
		spent_width = clamp(spent_value / max_value, 0.0, 1.0) * size.x

	var current_width = clamp(size.x - spent_width, 0.0, size.x)
	var usable_width = clamp(queued_width + available_width, 0.0, size.x)
	if current_width < usable_width:
		current_width = usable_width
	available_width = min(available_width, max(size.x - queued_width, 0.0))

	spent.position = Vector2(current_width, 0.0)
	spent.size = Vector2(max(size.x - current_width, 0.0), size.y)
	available.position = Vector2(queued_width, 0.0)
	available.size = Vector2(max(min(available_width, current_width - queued_width), 0.0), size.y)
	queued.position = Vector2.ZERO
	queued.size = Vector2(queued_width, size.y)
	available.visible = available.size.x > 0.0
	queued.visible = queued.size.x > 0.0
	spent.visible = spent.size.x > 0.0

	root.move_child(queued, root.get_child_count() - 1)
	if label != null:
		root.move_child(label, root.get_child_count() - 1)
		var text := str(packet.get("text", ""))
		if text == "":
			text = "ENERGY " + whole(current) + "/" + whole(max_value)
		label.text = text


func get_bar_refs(bar_id: String) -> Dictionary:
	var clean_id := bar_id.strip_edges()
	if clean_id == "" or not bars.has(clean_id):
		return {}
	var refs = bars.get(clean_id, {})
	if typeof(refs) != TYPE_DICTIONARY:
		return {}
	return refs


func get_control_ref(refs: Dictionary, key: String) -> Control:
	var value = refs.get(key, null)
	if value is Control and is_instance_valid(value):
		return value as Control
	return null


func get_color_rect_ref(refs: Dictionary, key: String) -> ColorRect:
	var value = refs.get(key, null)
	if value is ColorRect and is_instance_valid(value):
		return value as ColorRect
	return null


func get_label_ref(refs: Dictionary, key: String) -> Label:
	var value = refs.get(key, null)
	if value is Label and is_instance_valid(value):
		return value as Label
	return null


func get_bar_size(root: Control) -> Vector2:
	var size := root.size
	if size.x <= 0.0:
		size.x = root.custom_minimum_size.x
	if size.y <= 0.0:
		size.y = root.custom_minimum_size.y
	if size.x <= 0.0:
		size.x = 120.0
	if size.y <= 0.0:
		size.y = 18.0
	root.size = size
	return size


func whole(value: float) -> String:
	return str(int(round(value)))
