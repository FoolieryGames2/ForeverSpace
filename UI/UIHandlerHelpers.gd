extends RefCounted
class_name UIHandlerHelpers


func build_normalized_packet(
	match_id: String,
	packet: Dictionary,
	context_id: String = "",
	position_data: Dictionary = {},
	header_state: Dictionary = {}
) -> Dictionary:
	var normalized_packet := packet.duplicate(true)
	normalized_packet["match_id"] = match_id
	normalized_packet["timestamp_msec"] = Time.get_ticks_msec()
	if context_id.strip_edges() != "" and str(normalized_packet.get("context_id", "")).strip_edges() == "":
		normalized_packet["context_id"] = context_id
	if not position_data.is_empty():
		normalized_packet["position_data"] = position_data.duplicate(true)
	if not header_state.is_empty():
		normalized_packet["header_state"] = header_state.duplicate(true)
	if not normalized_packet.has("tags") or typeof(normalized_packet.get("tags")) != TYPE_ARRAY:
		normalized_packet["tags"] = []
	if not normalized_packet.has("labels") or typeof(normalized_packet.get("labels")) != TYPE_ARRAY:
		normalized_packet["labels"] = []
	return normalized_packet


func trim_array_to_limit(target: Array, limit: int) -> void:
	while target.size() > limit:
		target.pop_front()


func get_label_text(label_refs: Dictionary, label_key: String) -> String:
	if not label_refs.has(label_key):
		return ""
	var label = label_refs[label_key]
	if label is Label:
		return str(label.text)
	if label is RichTextLabel:
		return str(label.text)
	if label is TextEdit:
		return str(label.text)
	if label is LineEdit:
		return str(label.text)
	return ""


func get_control_rect(control) -> Rect2:
	if control == null or not is_instance_valid(control):
		return Rect2()
	if control is Control:
		var control_ref: Control = control
		return Rect2(control_ref.global_position, control_ref.size)
	if control is Node2D:
		var node_ref: Node2D = control
		return Rect2(node_ref.global_position, Vector2.ZERO)
	return Rect2()


func build_position_data_from_controls(point_specs: Dictionary, control_refs: Dictionary = {}) -> Dictionary:
	var output: Dictionary = {}
	for point_id in point_specs.keys():
		var spec: Dictionary = point_specs[point_id]
		var point := {
			"position": spec.get("position", Vector2.ZERO),
			"size": spec.get("size", Vector2.ZERO),
			"purpose": str(spec.get("purpose", point_id))
		}
		var control_key := str(spec.get("control_key", "")).strip_edges()
		if control_key != "" and control_refs.has(control_key):
			var rect := get_control_rect(control_refs[control_key])
			if rect.size != Vector2.ZERO:
				point["position"] = rect.position
				point["size"] = rect.size
		output[point_id] = point
	return output


func get_point_center(position_data: Dictionary, point_id: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if not position_data.has(point_id):
		return fallback
	var point: Dictionary = position_data[point_id]
	return point.get("position", fallback) + point.get("size", Vector2.ZERO) * 0.5


func get_packet_vector2(packet: Dictionary, key: String, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	var value = packet.get(key, fallback)
	if typeof(value) == TYPE_VECTOR2:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	return fallback


func append_unique_string(target: Array, value: String) -> void:
	var clean_value := value.strip_edges()
	if clean_value == "":
		return
	if target.has(clean_value):
		return
	target.append(clean_value)

