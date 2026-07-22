extends RefCounted
class_name IntelDiscoveryHandler

const SCHEMA_VERSION := 1
const HIDDEN_LABELS := [
	"hidden",
	"internal",
	"debug",
	"no_intel",
	"not_discoverable",
	"invisible_listener"
]

var save_manager = null
var entries: Dictionary = {}
var enemy_defeats: Dictionary = {}


func setup(new_save_manager = null) -> IntelDiscoveryHandler:
	save_manager = new_save_manager
	return self


func get_empty_save_data() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"entries": {},
		"enemy_defeats": {}
	}


func record_discovery(intel_id: String, category: String = "item", source_packet: Dictionary = {}) -> Dictionary:
	var clean_id := normalize_intel_id(intel_id)
	if clean_id == "":
		return {"ok": false, "reason": "missing intel_id"}

	if not is_source_discoverable(source_packet):
		return {"ok": false, "reason": "source is not discoverable", "intel_id": clean_id}

	var now_unix := int(Time.get_unix_time_from_system())
	var now_text := get_current_datetime_text()
	var display_name := resolve_display_name(clean_id, source_packet)
	var clean_category := normalize_category(category, source_packet)
	var is_new := not entries.has(clean_id)
	var entry := {}

	if is_new:
		entry = {
			"intel_id": clean_id,
			"display_name": display_name,
			"category": clean_category,
			"discovered": true,
			"checked": false,
			"discovery_count": 0,
			"first_discovered_at_unix": now_unix,
			"first_discovered_at_text": now_text,
			"last_seen_at_unix": now_unix,
			"last_seen_at_text": now_text,
			"source_type": str(source_packet.get("source", source_packet.get("source_type", ""))).strip_edges(),
			"labels": read_labels(source_packet)
		}
	else:
		entry = entries[clean_id].duplicate(true)
		if str(entry.get("display_name", "")).strip_edges() == "":
			entry["display_name"] = display_name
		if str(entry.get("category", "")).strip_edges() == "":
			entry["category"] = clean_category

	entry["discovered"] = true
	entry["discovery_count"] = max(int(entry.get("discovery_count", 0)) + 1, 1)
	entry["last_seen_at_unix"] = now_unix
	entry["last_seen_at_text"] = now_text
	entry["last_source"] = build_safe_source_stamp(source_packet)

	# First-discovery-only highlight: repeat sightings never flip checked back to false.
	if not entry.has("checked"):
		entry["checked"] = false

	entries[clean_id] = entry
	return {
		"ok": true,
		"intel_id": clean_id,
		"is_new": is_new,
		"checked": bool(entry.get("checked", false)),
		"discovery_count": int(entry.get("discovery_count", 0))
	}


func has_discovered(intel_id: String) -> bool:
	var clean_id := normalize_intel_id(intel_id)
	if clean_id == "":
		return false
	if not entries.has(clean_id):
		return false
	var entry = entries.get(clean_id, {})
	return typeof(entry) == TYPE_DICTIONARY and bool(entry.get("discovered", false))


func get_discovery_count(intel_id: String) -> int:
	var clean_id := normalize_intel_id(intel_id)
	if clean_id == "" or not entries.has(clean_id):
		return 0
	var entry = entries.get(clean_id, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return 0
	return int(entry.get("discovery_count", 0))


func is_unchecked(intel_id: String) -> bool:
	var clean_id := normalize_intel_id(intel_id)
	if clean_id == "" or not entries.has(clean_id):
		return false
	var entry = entries.get(clean_id, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	return bool(entry.get("discovered", false)) and not bool(entry.get("checked", false))


func mark_checked(intel_id: String) -> Dictionary:
	var clean_id := normalize_intel_id(intel_id)
	if clean_id == "":
		return {"ok": false, "reason": "missing intel_id"}
	if not entries.has(clean_id):
		return {"ok": false, "reason": "intel entry not found", "intel_id": clean_id}

	var entry: Dictionary = entries[clean_id].duplicate(true)
	var was_checked := bool(entry.get("checked", false))
	entry["checked"] = true
	entry["checked_at_unix"] = int(Time.get_unix_time_from_system())
	entry["checked_at_text"] = get_current_datetime_text()
	entries[clean_id] = entry

	return {
		"ok": true,
		"intel_id": clean_id,
		"changed": not was_checked,
		"checked": true
	}


func record_enemy_defeated(enemy_key: String, source_packet: Dictionary = {}) -> Dictionary:
	var clean_key := normalize_intel_id(enemy_key)
	if clean_key == "":
		clean_key = normalize_intel_id(str(source_packet.get("enemy_id", source_packet.get("object_id", source_packet.get("display_name", "")))))
	if clean_key == "":
		return {"ok": false, "reason": "missing enemy_key"}

	var now_unix := int(Time.get_unix_time_from_system())
	var now_text := get_current_datetime_text()
	var entry = enemy_defeats.get(clean_key, {})
	if typeof(entry) != TYPE_DICTIONARY:
		entry = {}
	entry["enemy_key"] = clean_key
	entry["display_name"] = resolve_display_name(clean_key, source_packet)
	entry["defeated_count"] = max(int(entry.get("defeated_count", 0)) + 1, 1)
	entry["last_defeated_at_unix"] = now_unix
	entry["last_defeated_at_text"] = now_text
	entry["last_source"] = build_safe_source_stamp(source_packet)
	enemy_defeats[clean_key] = entry
	return {"ok": true, "enemy_key": clean_key, "defeated_count": int(entry.get("defeated_count", 0))}


func get_enemy_defeat_count(enemy_key: String) -> int:
	var clean_key := normalize_intel_id(enemy_key)
	if clean_key == "" or not enemy_defeats.has(clean_key):
		return 0
	var entry = enemy_defeats.get(clean_key, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return 0
	return int(entry.get("defeated_count", 0))


func to_save_data() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"entries": make_json_safe_value(entries),
		"enemy_defeats": make_json_safe_value(enemy_defeats)
	}


func load_save_data(data) -> bool:
	entries.clear()
	enemy_defeats.clear()

	if typeof(data) != TYPE_DICTIONARY:
		return false

	var loaded_entries = data.get("entries", {})
	if typeof(loaded_entries) == TYPE_DICTIONARY:
		for key in loaded_entries.keys():
			var clean_key := normalize_intel_id(str(key))
			var entry = loaded_entries[key]
			if clean_key != "" and typeof(entry) == TYPE_DICTIONARY:
				var safe_entry = entry.duplicate(true)
				safe_entry["intel_id"] = normalize_intel_id(str(safe_entry.get("intel_id", clean_key)))
				if not safe_entry.has("checked"):
					safe_entry["checked"] = false
				if not safe_entry.has("discovered"):
					safe_entry["discovered"] = true
				entries[clean_key] = safe_entry

	var loaded_defeats = data.get("enemy_defeats", {})
	if typeof(loaded_defeats) == TYPE_DICTIONARY:
		for key in loaded_defeats.keys():
			var clean_defeat_key := normalize_intel_id(str(key))
			var defeat_entry = loaded_defeats[key]
			if clean_defeat_key != "" and typeof(defeat_entry) == TYPE_DICTIONARY:
				enemy_defeats[clean_defeat_key] = defeat_entry.duplicate(true)

	return true


func save_to_universe_if_available() -> bool:
	if save_manager == null:
		return false
	if save_manager.has_method("write_intel_save_data"):
		return bool(save_manager.write_intel_save_data(to_save_data()))
	return false


func normalize_intel_id(value: String) -> String:
	return str(value).strip_edges()


func normalize_category(category: String, source_packet: Dictionary = {}) -> String:
	var clean_category := str(category).strip_edges().to_lower()
	if clean_category == "":
		clean_category = str(source_packet.get("category", source_packet.get("item_type", "item"))).strip_edges().to_lower()
	if clean_category == "res":
		return "resource"
	if clean_category == "cons":
		return "consumable"
	if clean_category == "blue":
		return "blueprint"
	if clean_category == "parts":
		return "part"
	return clean_category if clean_category != "" else "item"


func resolve_display_name(fallback_id: String, source_packet: Dictionary) -> String:
	for key in ["display_name", "item_name", "name", "title", "scan_name", "enemy_name", "npc_name"]:
		var value := str(source_packet.get(key, "")).strip_edges()
		if value != "":
			return value

	var shared_meta = source_packet.get("shared_meta", {})
	if typeof(shared_meta) == TYPE_DICTIONARY:
		for key in ["display_name", "name", "title", "scan_name"]:
			var shared_value := str(shared_meta.get(key, "")).strip_edges()
			if shared_value != "":
				return shared_value

	return fallback_id


func is_source_discoverable(source_packet: Dictionary) -> bool:
	if bool(source_packet.get("discoverable", source_packet.get("is_discoverable", true))) == false:
		return false
	if bool(source_packet.get("hidden", false)) or bool(source_packet.get("internal", false)):
		return false

	var labels := read_labels(source_packet)
	for label in labels:
		var clean_label := str(label).strip_edges().to_lower()
		if HIDDEN_LABELS.has(clean_label):
			return false
	return true


func read_labels(source_packet: Dictionary) -> Array:
	var labels := []
	append_labels(labels, source_packet.get("labels", []))

	var shared_meta = source_packet.get("shared_meta", {})
	if typeof(shared_meta) == TYPE_DICTIONARY:
		append_labels(labels, shared_meta.get("labels", []))

	return labels


func append_labels(labels: Array, value) -> void:
	if typeof(value) == TYPE_ARRAY:
		for item in value:
			var array_label := str(item).strip_edges()
			if array_label != "" and not labels.has(array_label):
				labels.append(array_label)
	elif typeof(value) == TYPE_STRING:
		for raw_label in str(value).split(",", false):
			var string_label := raw_label.strip_edges()
			if string_label != "" and not labels.has(string_label):
				labels.append(string_label)


func build_safe_source_stamp(source_packet: Dictionary) -> Dictionary:
	var stamp := {}
	for key in [
		"source",
		"reason",
		"item_id",
		"object_id",
		"enemy_id",
		"display_name",
		"item_name",
		"category",
		"item_type",
		"subtype",
		"container_name",
		"slot_name"
	]:
		if source_packet.has(key):
			stamp[key] = make_json_safe_value(source_packet[key])
	return stamp


func get_current_datetime_text() -> String:
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


func make_json_safe_value(value):
	var value_type := typeof(value)

	if value_type == TYPE_VECTOR2:
		return {"x": value.x, "y": value.y}
	if value_type == TYPE_VECTOR2I:
		return {"x": value.x, "y": value.y}
	if value_type == TYPE_VECTOR3:
		return {"x": value.x, "y": value.y, "z": value.z}
	if value_type == TYPE_VECTOR3I:
		return {"x": value.x, "y": value.y, "z": value.z}
	if value_type == TYPE_COLOR:
		return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
	if value_type == TYPE_CALLABLE or value_type == TYPE_OBJECT:
		return null
	if value_type == TYPE_DICTIONARY:
		var out := {}
		for key in value.keys():
			out[str(key)] = make_json_safe_value(value[key])
		return out
	if value_type == TYPE_ARRAY:
		var out_array := []
		for item in value:
			out_array.append(make_json_safe_value(item))
		return out_array

	return value
