extends RefCounted
class_name EnemyIntelHandler


const SCHEMA_VERSION := 1

var save_manager = null
var next_serial_index: int = 1
var spawned_enemies: Dictionary = {}
var defeated_enemy_serials: Dictionary = {}
var defeated_counts_by_display_name: Dictionary = {}
var event_enemy_serials: Dictionary = {}


func setup(new_save_manager = null) -> EnemyIntelHandler:
	save_manager = new_save_manager
	return self


func get_empty_save_data() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"next_serial_index": 1,
		"spawned_enemies": {},
		"defeated_enemy_serials": {},
		"defeated_counts_by_display_name": {},
		"event_enemy_serials": {}
	}


func ensure_enemy_serial(enemy_ref, source_packet: Dictionary = {}) -> String:
	var source := build_enemy_source_packet(enemy_ref, source_packet)
	var serial := read_enemy_serial_from_packet(source)
	if serial == "":
		serial = generate_enemy_serial(source)
	if serial == "":
		return ""

	apply_serial_to_enemy_ref(enemy_ref, serial, source)
	register_spawned_serial(serial, source)
	return serial


func register_enemy_spawned(enemy_or_packet, source_packet: Dictionary = {}) -> Dictionary:
	var serial := ensure_enemy_serial(enemy_or_packet, source_packet)
	if serial == "":
		return {"ok": false, "reason": "missing enemy_serial"}
	return {
		"ok": true,
		"enemy_serial": serial,
		"event_id": resolve_event_id(build_enemy_source_packet(enemy_or_packet, source_packet)),
		"object_id": resolve_object_id(build_enemy_source_packet(enemy_or_packet, source_packet))
	}


func record_enemy_defeated(enemy_or_result_packet, source_packet: Dictionary = {}) -> Dictionary:
	var source := build_enemy_source_packet(enemy_or_result_packet, source_packet)
	merge_result_identity_packets(source, enemy_or_result_packet)
	var serial := read_enemy_serial_from_packet(source)
	if serial == "":
		var event_id := resolve_event_id(source)
		var object_id := resolve_object_id(source)
		if event_id != "" and object_id != "":
			serial = get_event_enemy_serial(event_id, object_id)
			if serial != "":
				source["enemy_serial"] = serial
	if serial == "":
		source["generated_from_result"] = true
		serial = ensure_enemy_serial(enemy_or_result_packet, source)
	if serial == "":
		return {"ok": false, "reason": "missing enemy_serial"}

	if defeated_enemy_serials.has(serial):
		var duplicate_entry: Dictionary = defeated_enemy_serials.get(serial, {})
		return {
			"ok": true,
			"enemy_serial": serial,
			"duplicate": true,
			"display_name": str(duplicate_entry.get("display_name", "")),
			"defeated_count": get_defeated_count_for_display_name(str(duplicate_entry.get("display_name", "")))
		}

	var now_unix := int(Time.get_unix_time_from_system())
	var now_text := get_current_datetime_text()
	var display_name := resolve_display_name(source)
	var display_key := normalize_display_key(display_name)
	var defeat_entry := build_enemy_fact_packet(serial, source)
	defeat_entry["defeated_at_unix"] = now_unix
	defeat_entry["defeated_at_text"] = now_text
	defeat_entry["defeat_source"] = make_json_safe_value(source)
	defeated_enemy_serials[serial] = defeat_entry

	var count_entry = defeated_counts_by_display_name.get(display_key, {})
	if typeof(count_entry) != TYPE_DICTIONARY:
		count_entry = {}
	count_entry["display_key"] = display_key
	count_entry["display_name"] = display_name
	count_entry["defeated_count"] = max(int(count_entry.get("defeated_count", 0)) + 1, 1)
	count_entry["last_defeated_at_unix"] = now_unix
	count_entry["last_defeated_at_text"] = now_text
	var serials := []
	if typeof(count_entry.get("enemy_serials", [])) == TYPE_ARRAY:
		serials = count_entry.get("enemy_serials", []).duplicate(true)
	if not serials.has(serial):
		serials.append(serial)
	count_entry["enemy_serials"] = serials
	defeated_counts_by_display_name[display_key] = count_entry

	register_spawned_serial(serial, source)
	return {
		"ok": true,
		"enemy_serial": serial,
		"duplicate": false,
		"display_name": display_name,
		"defeated_count": int(count_entry.get("defeated_count", 0))
	}


func record_enemy_defeated_from_battle_result(result: Dictionary) -> Dictionary:
	return record_enemy_defeated(result)


func has_enemy_serial_defeated(enemy_serial: String) -> bool:
	var clean_serial := normalize_serial(enemy_serial)
	return clean_serial != "" and defeated_enemy_serials.has(clean_serial)


func get_defeated_count_for_display_name(display_name: String) -> int:
	var display_key := normalize_display_key(display_name)
	if display_key == "":
		return 0
	var entry = defeated_counts_by_display_name.get(display_key, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return 0
	return int(entry.get("defeated_count", 0))


func get_event_enemy_serial(event_id: String, object_id_or_enemy_id: String) -> String:
	var clean_event_id := normalize_key(event_id)
	var clean_object_id := normalize_key(object_id_or_enemy_id)
	if clean_event_id == "" or clean_object_id == "":
		return ""
	var event_map = event_enemy_serials.get(clean_event_id, {})
	if typeof(event_map) != TYPE_DICTIONARY:
		return ""
	return normalize_serial(str(event_map.get(clean_object_id, "")))


func to_save_data() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"next_serial_index": max(next_serial_index, 1),
		"spawned_enemies": make_json_safe_value(spawned_enemies),
		"defeated_enemy_serials": make_json_safe_value(defeated_enemy_serials),
		"defeated_counts_by_display_name": make_json_safe_value(defeated_counts_by_display_name),
		"event_enemy_serials": make_json_safe_value(event_enemy_serials)
	}


func load_save_data(data) -> bool:
	spawned_enemies.clear()
	defeated_enemy_serials.clear()
	defeated_counts_by_display_name.clear()
	event_enemy_serials.clear()
	next_serial_index = 1

	if typeof(data) != TYPE_DICTIONARY:
		return false

	next_serial_index = max(int(data.get("next_serial_index", 1)), 1)
	load_dictionary_section(spawned_enemies, data.get("spawned_enemies", {}), true)
	load_dictionary_section(defeated_enemy_serials, data.get("defeated_enemy_serials", {}), true)
	load_dictionary_section(defeated_counts_by_display_name, data.get("defeated_counts_by_display_name", {}), true)
	load_dictionary_section(event_enemy_serials, data.get("event_enemy_serials", {}), true)
	return true


func save_to_universe_if_available() -> bool:
	if save_manager == null:
		return false
	if save_manager.has_method("write_enemy_intel_save_data"):
		return bool(save_manager.write_enemy_intel_save_data(to_save_data()))
	return false


func build_enemy_source_packet(enemy_ref, source_packet: Dictionary = {}) -> Dictionary:
	var source := {}
	if typeof(source_packet) == TYPE_DICTIONARY:
		source = source_packet.duplicate(true)

	if typeof(enemy_ref) == TYPE_DICTIONARY:
		merge_missing_source_values(source, enemy_ref)
	elif enemy_ref is Object:
		for key in [
			"enemy_serial",
			"serial_number",
			"enemy_instance_serial",
			"enemy_template_id",
			"enemy_blueprint_id",
			"blueprint_id",
			"object_id",
			"enemy_id",
			"id",
			"name",
			"enemy_name",
			"display_name",
			"type",
			"enemy_type",
			"sector_pos",
			"local_pos",
			"has_event",
			"event_id",
			"active_event_id",
			"event_ids",
			"event_step",
			"current_step",
			"required_step",
			"labels",
			"shared_meta"
		]:
			var value = enemy_ref.get(key)
			if value != null and not source.has(key):
				source[key] = value

	if typeof(source.get("shared_meta", {})) == TYPE_DICTIONARY:
		merge_missing_source_values(source, source.get("shared_meta", {}))

	return source


func merge_result_identity_packets(source: Dictionary, result_packet) -> void:
	if typeof(result_packet) != TYPE_DICTIONARY:
		return
	var result: Dictionary = result_packet
	for key in ["defeated_enemy_shared_meta", "defeated_enemy_signature", "authored_event_context"]:
		var packet = result.get(key, {})
		if typeof(packet) == TYPE_DICTIONARY:
			merge_missing_source_values(source, packet)
			if typeof(packet.get("shared_meta", {})) == TYPE_DICTIONARY:
				merge_missing_source_values(source, packet.get("shared_meta", {}))

	for key in [
		"defeated_enemy_serial",
		"defeated_enemy_id",
		"defeated_enemy_name",
		"battle_id",
		"outcome"
	]:
		if result.has(key) and not source.has(key):
			source[key] = result[key]

	if str(source.get("enemy_serial", "")).strip_edges() == "" and str(result.get("defeated_enemy_serial", "")).strip_edges() != "":
		source["enemy_serial"] = result.get("defeated_enemy_serial")
	if str(source.get("object_id", "")).strip_edges() == "" and str(result.get("defeated_enemy_id", "")).strip_edges() != "":
		source["object_id"] = result.get("defeated_enemy_id")
	if str(source.get("display_name", "")).strip_edges() == "" and str(result.get("defeated_enemy_name", "")).strip_edges() != "":
		source["display_name"] = result.get("defeated_enemy_name")


func merge_missing_source_values(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		if is_source_value_missing(target.get(key, null)):
			target[key] = source[key]


func is_source_value_missing(value) -> bool:
	if value == null:
		return true
	if typeof(value) == TYPE_STRING:
		return str(value).strip_edges() == ""
	if typeof(value) == TYPE_ARRAY:
		return value.is_empty()
	if typeof(value) == TYPE_DICTIONARY:
		return value.is_empty()
	return false


func read_enemy_serial_from_packet(source: Dictionary) -> String:
	for key in ["enemy_serial", "serial_number", "enemy_instance_serial", "defeated_enemy_serial"]:
		var value := normalize_serial(str(source.get(key, "")))
		if value != "":
			return value
	var shared_meta = source.get("shared_meta", {})
	if typeof(shared_meta) == TYPE_DICTIONARY:
		for key in ["enemy_serial", "serial_number", "enemy_instance_serial"]:
			var shared_value := normalize_serial(str(shared_meta.get(key, "")))
			if shared_value != "":
				return shared_value
	return ""


func generate_enemy_serial(source: Dictionary) -> String:
	var slug := sanitize_fragment(resolve_display_name(source))
	if slug == "":
		slug = "enemy"

	for i in range(0, 10000):
		var serial := "enemy_" + slug + "_" + str(next_serial_index)
		next_serial_index += 1
		if not spawned_enemies.has(serial) and not defeated_enemy_serials.has(serial):
			return serial

	return "enemy_" + slug + "_" + str(int(Time.get_unix_time_from_system()))


func apply_serial_to_enemy_ref(enemy_ref, serial: String, source: Dictionary) -> void:
	var clean_serial := normalize_serial(serial)
	if clean_serial == "":
		return
	var template_id := resolve_template_id(source)

	if typeof(enemy_ref) == TYPE_DICTIONARY:
		enemy_ref["enemy_serial"] = clean_serial
		if template_id != "":
			enemy_ref["enemy_template_id"] = template_id
		var shared_meta = enemy_ref.get("shared_meta", {})
		if typeof(shared_meta) != TYPE_DICTIONARY:
			shared_meta = {}
		shared_meta["enemy_serial"] = clean_serial
		if template_id != "":
			shared_meta["enemy_template_id"] = template_id
		enemy_ref["shared_meta"] = shared_meta
		return

	if enemy_ref is Object:
		enemy_ref.set("enemy_serial", clean_serial)
		if template_id != "":
			enemy_ref.set("enemy_template_id", template_id)
		var object_shared = enemy_ref.get("shared_meta")
		if typeof(object_shared) != TYPE_DICTIONARY:
			object_shared = {}
		object_shared["enemy_serial"] = clean_serial
		if template_id != "":
			object_shared["enemy_template_id"] = template_id
		enemy_ref.set("shared_meta", object_shared)
		if enemy_ref.has_method("sync_shared_meta"):
			enemy_ref.sync_shared_meta()


func register_spawned_serial(serial: String, source: Dictionary) -> void:
	var clean_serial := normalize_serial(serial)
	if clean_serial == "":
		return

	var packet := build_enemy_fact_packet(clean_serial, source)
	var existing = spawned_enemies.get(clean_serial, {})
	if typeof(existing) == TYPE_DICTIONARY:
		for key in existing.keys():
			if is_source_value_missing(packet.get(key, null)):
				packet[key] = existing[key]

	packet["enemy_serial"] = clean_serial
	packet["last_seen_at_unix"] = int(Time.get_unix_time_from_system())
	packet["last_seen_at_text"] = get_current_datetime_text()
	if not packet.has("first_seen_at_unix"):
		packet["first_seen_at_unix"] = packet["last_seen_at_unix"]
		packet["first_seen_at_text"] = packet["last_seen_at_text"]
	spawned_enemies[clean_serial] = packet

	var event_id := resolve_event_id(source)
	var object_id := resolve_object_id(source)
	if event_id != "" and object_id != "":
		register_event_enemy_serial(event_id, object_id, clean_serial)


func register_event_enemy_serial(event_id: String, object_id_or_enemy_id: String, serial: String) -> void:
	var clean_event_id := normalize_key(event_id)
	var clean_object_id := normalize_key(object_id_or_enemy_id)
	var clean_serial := normalize_serial(serial)
	if clean_event_id == "" or clean_object_id == "" or clean_serial == "":
		return
	var event_map = event_enemy_serials.get(clean_event_id, {})
	if typeof(event_map) != TYPE_DICTIONARY:
		event_map = {}
	event_map[clean_object_id] = clean_serial
	event_enemy_serials[clean_event_id] = event_map


func build_enemy_fact_packet(serial: String, source: Dictionary) -> Dictionary:
	return {
		"enemy_serial": normalize_serial(serial),
		"object_id": resolve_object_id(source),
		"enemy_id": str(source.get("enemy_id", source.get("object_id", ""))).strip_edges(),
		"display_name": resolve_display_name(source),
		"enemy_template_id": resolve_template_id(source),
		"enemy_type": str(source.get("enemy_type", source.get("type", ""))).strip_edges(),
		"event_id": resolve_event_id(source),
		"active_event_id": str(source.get("active_event_id", source.get("event_id", ""))).strip_edges(),
		"has_event": bool(source.get("has_event", resolve_event_id(source) != "")),
		"labels": read_array(source.get("labels", [])),
		"source": make_json_safe_value(source)
	}


func resolve_display_name(source: Dictionary) -> String:
	for key in ["display_name", "defeated_enemy_name", "enemy_name", "name", "ship_name"]:
		var value := str(source.get(key, "")).strip_edges()
		if value != "":
			return value
	return "Unknown enemy"


func resolve_template_id(source: Dictionary) -> String:
	for key in ["enemy_template_id", "enemy_blueprint_id", "source_blueprint_id", "blueprint_id", "catalog_id"]:
		var value := str(source.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""


func resolve_object_id(source: Dictionary) -> String:
	for key in ["object_id", "enemy_id", "target_object_id", "id", "defeated_enemy_id"]:
		var value := str(source.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""


func resolve_event_id(source: Dictionary) -> String:
	for key in ["event_id", "active_event_id", "give_event", "requires_event"]:
		var value := str(source.get(key, "")).strip_edges()
		if value != "":
			return value
	var event_ids = source.get("event_ids", [])
	if typeof(event_ids) == TYPE_ARRAY and not event_ids.is_empty():
		return str(event_ids[0]).strip_edges()
	return ""


func normalize_serial(value: String) -> String:
	return value.strip_edges()


func normalize_key(value: String) -> String:
	return value.strip_edges()


func normalize_display_key(value: String) -> String:
	return sanitize_fragment(value)


func sanitize_fragment(value: String) -> String:
	var clean := value.strip_edges().to_lower()
	for separator in [" ", "\t", "\n", "\r", ":", ";", "/", "\\", ".", ",", "(", ")", "[", "]", "{", "}", "|", "'", "\""]:
		clean = clean.replace(separator, "_")
	while clean.find("__") != -1:
		clean = clean.replace("__", "_")
	return clean.strip_edges().trim_prefix("_").trim_suffix("_")


func load_dictionary_section(target: Dictionary, value, duplicate_values: bool = true) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	for key in value.keys():
		var clean_key := str(key).strip_edges()
		if clean_key == "":
			continue
		var entry = value[key]
		if duplicate_values and typeof(entry) == TYPE_DICTIONARY:
			target[clean_key] = entry.duplicate(true)
		else:
			target[clean_key] = entry


func read_array(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return []


func make_json_safe_value(value):
	match typeof(value):
		TYPE_DICTIONARY:
			var out := {}
			for key in value.keys():
				out[str(key)] = make_json_safe_value(value[key])
			return out
		TYPE_ARRAY:
			var out_array := []
			for item in value:
				out_array.append(make_json_safe_value(item))
			return out_array
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_VECTOR3I:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR2I:
			return {"x": value.x, "y": value.y}
		TYPE_OBJECT:
			return str(value)
		_:
			return value


func get_current_datetime_text() -> String:
	var now := Time.get_datetime_dict_from_system()
	return (
		str(now.get("year", 0)).pad_zeros(4)
		+ "-"
		+ str(now.get("month", 0)).pad_zeros(2)
		+ "-"
		+ str(now.get("day", 0)).pad_zeros(2)
		+ " "
		+ str(now.get("hour", 0)).pad_zeros(2)
		+ ":"
		+ str(now.get("minute", 0)).pad_zeros(2)
		+ ":"
		+ str(now.get("second", 0)).pad_zeros(2)
	)
