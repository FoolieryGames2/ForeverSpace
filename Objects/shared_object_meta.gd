extends RefCounted
class_name SharedObjectMeta


const SHARED_META_KEYS := [
	"object_id",
	"object_type",
	"display_name",
	"main_view_icon_id",
	"main_view_icon_path",
	"tier",
	"section_id",
	"sector_pos",
	"local_pos",
	"is_visible",
	"is_discovered",
	"is_completed",
	"has_event",
	"event_id",
	"event_ids",
	"active_event_id",
	"event_state",
	"event_step",
	"current_step",
	"required_step",
	"interaction_type",
	"helper_state",
	"completed",
	"event_accept_message",
	"event_decline_message",
	"event_idle_message",
	"event_completed_message",
	"give_event",
	"requires_event",
	"has_run_lore",
	"run_lore_id",
	"has_universe_lore",
	"universe_lore_id",
	"has_gift",
	"gift_id",
	"labels"
]


static func default_meta() -> Dictionary:
	return {
		"object_id": "",
		"object_type": "",
		"display_name": "",
		"main_view_icon_id": "",
		"main_view_icon_path": "",
		"tier": 1,
		"section_id": "",
		"sector_pos": Vector3i.ZERO,
		"local_pos": Vector3.ZERO,
		"is_visible": true,
		"is_discovered": false,
		"is_completed": false,
		"has_event": false,
		"event_id": "",
		"event_ids": [],
		"active_event_id": "",
		"event_state": "none",
		"event_step": "",
		"current_step": "",
		"required_step": "",
		"interaction_type": "",
		"helper_state": "none",
		"completed": false,
		"event_accept_message": "",
		"event_decline_message": "",
		"event_idle_message": "",
		"event_completed_message": "",
		"give_event": "",
		"requires_event": "",
		"has_run_lore": false,
		"run_lore_id": "",
		"has_universe_lore": false,
		"universe_lore_id": "",
		"has_gift": false,
		"gift_id": "",
		"labels": []
	}


static func build_meta(
	object_id: String = "",
	object_type: String = "",
	display_name: String = "",
	sector_pos = null,
	local_pos = null,
	source: Dictionary = {}
) -> Dictionary:
	var meta := default_meta()

	if typeof(source.get("shared_meta", {})) == TYPE_DICTIONARY:
		merge_shared_keys(meta, source.get("shared_meta", {}))

	merge_shared_keys(meta, source)
	apply_alias_fallbacks(meta, source)

	if object_id.strip_edges() != "":
		meta["object_id"] = object_id.strip_edges()
	if object_type.strip_edges() != "":
		meta["object_type"] = object_type.strip_edges()
	if display_name.strip_edges() != "":
		meta["display_name"] = display_name.strip_edges()

	meta["sector_pos"] = read_sector_pos(sector_pos if sector_pos != null else meta.get("sector_pos", Vector3i.ZERO))
	meta["local_pos"] = read_local_pos(local_pos if local_pos != null else meta.get("local_pos", Vector3.ZERO))

	return normalize_meta(meta)


static func merge_shared_keys(target: Dictionary, source: Dictionary) -> void:
	for key in SHARED_META_KEYS:
		if source.has(key):
			target[key] = source[key]

	if source.has("sector"):
		target["sector_pos"] = source["sector"]
	if source.has("local"):
		target["local_pos"] = source["local"]


static func apply_alias_fallbacks(meta: Dictionary, source: Dictionary) -> void:
	if str(meta.get("object_id", "")).strip_edges() == "":
		for key in ["id", "item_id", "npc_id", "enemy_id", "unit_id", "star_id"]:
			if source.has(key) and str(source.get(key, "")).strip_edges() != "":
				meta["object_id"] = str(source.get(key)).strip_edges()
				break

	if str(meta.get("display_name", "")).strip_edges() == "":
		for key in ["display_name", "name", "enemy_name", "npc_name", "star_name", "scan_name", "title"]:
			if source.has(key) and str(source.get(key, "")).strip_edges() != "":
				meta["display_name"] = str(source.get(key)).strip_edges()
				break

	if str(meta.get("object_type", "")).strip_edges() == "":
		for key in ["object_type", "item_type", "type", "enemy_type", "npc_role", "beacon_type", "star_type"]:
			if source.has(key) and str(source.get(key, "")).strip_edges() != "":
				meta["object_type"] = str(source.get(key)).strip_edges()
				break

	if str(meta.get("main_view_icon_id", "")).strip_edges() == "":
		var icon_id := read_first_nested_string(
			source,
			["main_view_icon_id", "main_view_icon", "icon_id"],
			["visual", "metadata", "meta", "shared_meta"]
		)
		if icon_id != "":
			meta["main_view_icon_id"] = icon_id

	if str(meta.get("main_view_icon_path", "")).strip_edges() == "":
		var icon_path := read_first_nested_string(
			source,
			["main_view_icon_path", "icon_path"],
			["visual", "metadata", "meta", "shared_meta"]
		)
		if icon_path != "":
			meta["main_view_icon_path"] = icon_path

	if source.has("uni_tier_index") and not source.has("tier"):
		meta["tier"] = int(source.get("uni_tier_index", meta.get("tier", 1)))


static func normalize_meta(meta: Dictionary) -> Dictionary:
	meta["object_id"] = str(meta.get("object_id", ""))
	meta["object_type"] = str(meta.get("object_type", ""))
	meta["display_name"] = str(meta.get("display_name", ""))
	meta["main_view_icon_id"] = str(meta.get("main_view_icon_id", ""))
	meta["main_view_icon_path"] = str(meta.get("main_view_icon_path", ""))
	meta["tier"] = max(int(meta.get("tier", 1)), 1)
	meta["section_id"] = str(meta.get("section_id", ""))
	meta["sector_pos"] = read_sector_pos(meta.get("sector_pos", Vector3i.ZERO))
	meta["local_pos"] = read_local_pos(meta.get("local_pos", Vector3.ZERO))
	meta["is_visible"] = bool(meta.get("is_visible", true))
	meta["is_discovered"] = bool(meta.get("is_discovered", false))
	meta["is_completed"] = bool(meta.get("is_completed", false))
	meta["has_event"] = bool(meta.get("has_event", false))
	meta["event_id"] = str(meta.get("event_id", ""))
	meta["event_ids"] = read_array(meta.get("event_ids", []))
	meta["active_event_id"] = str(meta.get("active_event_id", ""))
	meta["event_state"] = str(meta.get("event_state", "none"))
	meta["event_step"] = str(meta.get("event_step", ""))
	meta["current_step"] = str(meta.get("current_step", ""))
	meta["required_step"] = str(meta.get("required_step", ""))
	meta["interaction_type"] = str(meta.get("interaction_type", ""))
	meta["helper_state"] = str(meta.get("helper_state", "none"))
	meta["completed"] = bool(meta.get("completed", false))
	meta["event_accept_message"] = str(meta.get("event_accept_message", ""))
	meta["event_decline_message"] = str(meta.get("event_decline_message", ""))
	meta["event_idle_message"] = str(meta.get("event_idle_message", ""))
	meta["event_completed_message"] = str(meta.get("event_completed_message", ""))
	if meta["event_id"] == "" and not meta["event_ids"].is_empty():
		meta["event_id"] = str(meta["event_ids"][0])
	if meta["active_event_id"] == "" and meta["event_id"] != "":
		meta["active_event_id"] = meta["event_id"]
	if not meta["event_ids"].is_empty() or meta["event_id"] != "":
		meta["has_event"] = true
	meta["give_event"] = str(meta.get("give_event", ""))
	meta["requires_event"] = str(meta.get("requires_event", ""))
	if meta["event_id"] == "" and meta["give_event"] != "":
		meta["event_id"] = meta["give_event"]
	if meta["event_id"] == "" and meta["requires_event"] != "":
		meta["event_id"] = meta["requires_event"]
	if meta["event_id"] != "" and not meta["event_ids"].has(meta["event_id"]):
		meta["event_ids"].append(meta["event_id"])
	if meta["active_event_id"] == "" and meta["event_id"] != "":
		meta["active_event_id"] = meta["event_id"]
	if not meta["event_ids"].is_empty() or meta["event_id"] != "":
		meta["has_event"] = true
	meta["has_run_lore"] = bool(meta.get("has_run_lore", false))
	meta["run_lore_id"] = str(meta.get("run_lore_id", ""))
	meta["has_universe_lore"] = bool(meta.get("has_universe_lore", false))
	meta["universe_lore_id"] = str(meta.get("universe_lore_id", ""))
	meta["has_gift"] = bool(meta.get("has_gift", false))
	meta["gift_id"] = str(meta.get("gift_id", ""))
	meta["labels"] = read_array(meta.get("labels", []))
	return meta


static func to_save_data(meta: Dictionary) -> Dictionary:
	var save_meta := normalize_meta(meta.duplicate(true))
	save_meta["sector_pos"] = vector3i_to_dict(save_meta.get("sector_pos", Vector3i.ZERO))
	save_meta["local_pos"] = vector3_to_dict(save_meta.get("local_pos", Vector3.ZERO))
	return save_meta


static func from_save_data(
	data: Dictionary,
	object_id: String = "",
	object_type: String = "",
	display_name: String = "",
	sector_pos = null,
	local_pos = null
) -> Dictionary:
	return build_meta(object_id, object_type, display_name, sector_pos, local_pos, data)


static func apply_to_dictionary(
	data: Dictionary,
	object_id: String = "",
	object_type: String = "",
	display_name: String = "",
	sector_pos = null,
	local_pos = null
) -> Dictionary:
	var meta := build_meta(object_id, object_type, display_name, sector_pos, local_pos, data)
	data["shared_meta"] = meta

	for key in SHARED_META_KEYS:
		if key == "labels" and data.has("labels"):
			continue
		data[key] = meta[key]

	return data


static func apply_save_meta_to_dictionary(
	data: Dictionary,
	object_id: String = "",
	object_type: String = "",
	display_name: String = "",
	sector_pos = null,
	local_pos = null
) -> Dictionary:
	var meta := build_meta(object_id, object_type, display_name, sector_pos, local_pos, data)
	var save_meta := to_save_data(meta)
	data["shared_meta"] = save_meta

	for key in SHARED_META_KEYS:
		if key == "labels" and data.has("labels"):
			continue
		data[key] = save_meta[key]

	return data


static func read_sector_pos(value) -> Vector3i:
	if value is Vector3i:
		return value
	if value is Vector3:
		return Vector3i(int(value.x), int(value.y), int(value.z))
	if value is Vector2:
		return Vector3i(int(value.x), int(value.y), 0)
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3i(
			int(value.get("x", 0)),
			int(value.get("y", 0)),
			int(value.get("z", 0))
		)
	return Vector3i.ZERO


static func read_local_pos(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector3i:
		return Vector3(value.x, value.y, value.z)
	if value is Vector2:
		return Vector3(value.x, value.y, 0.0)
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3(
			float(value.get("x", 0.0)),
			float(value.get("y", 0.0)),
			float(value.get("z", 0.0))
		)
	return Vector3.ZERO


static func read_array(value) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return []


static func read_first_nested_string(source: Dictionary, keys: Array, nested_keys: Array = []) -> String:
	for source_key in keys:
		if source.has(source_key) and str(source.get(source_key, "")).strip_edges() != "":
			return str(source.get(source_key)).strip_edges()

	for nested_key in nested_keys:
		var nested = source.get(nested_key, {})
		if typeof(nested) != TYPE_DICTIONARY:
			continue

		for nested_value_key in keys:
			if nested.has(nested_value_key) and str(nested.get(nested_value_key, "")).strip_edges() != "":
				return str(nested.get(nested_value_key)).strip_edges()

	return ""


static func vector3i_to_dict(value) -> Dictionary:
	var vector := read_sector_pos(value)
	return {
		"x": vector.x,
		"y": vector.y,
		"z": vector.z
	}


static func vector3_to_dict(value) -> Dictionary:
	var vector := read_local_pos(value)
	return {
		"x": vector.x,
		"y": vector.y,
		"z": vector.z
	}
