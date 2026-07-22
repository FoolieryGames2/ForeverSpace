extends RefCounted

class_name AchievementHandler

const SCHEMA_VERSION := 1
const AUTO_FLUSH_SECONDS := 10.0
const AUTO_FLUSH_DISTANCE := 100.0
const DEFAULT_SAVE_ROOT_DIR := "user://save"
const DEFAULT_UNIVERSE_SAVE_ROOT_DIR := "user://save/universes"

var save_manager = null
var profiles_path_override := ""
var disk_writes_enabled := true
var profiles_document: Dictionary = {}
var active_profile_id := ""
var session_started := false
var session_start_unix := 0
var pending_flush_seconds := 0.0
var pending_distance := 0.0
var last_world_pos = null
var last_saved_profiles_document: Dictionary = {}


func setup(new_save_manager = null) -> AchievementHandler:
	save_manager = new_save_manager
	return self


func set_profiles_path_override(path: String) -> void:
	profiles_path_override = path.strip_edges()
	profiles_document.clear()


func set_disk_writes_enabled(enabled: bool) -> void:
	disk_writes_enabled = enabled


func get_profiles_path() -> String:
	if profiles_path_override != "":
		return profiles_path_override
	if save_manager != null and save_manager.has_method("get_active_save_dir"):
		return str(save_manager.get_active_save_dir()) + "/achievement_profiles.json"
	return DEFAULT_UNIVERSE_SAVE_ROOT_DIR + "/" + get_active_save_lane() + "/achievement_profiles.json"


func get_active_save_lane() -> String:
	if save_manager != null and save_manager.has_method("get_active_universe_save_lane"):
		return str(save_manager.get_active_universe_save_lane()).strip_edges()
	var lane := str(Globals.active_universe_save_lane).strip_edges()
	if lane == "":
		lane = str(Globals.active_universe_id).strip_edges()
	if lane == "":
		lane = "universe_1"
	return sanitize_fragment(lane, 72)


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


func prepare_universe_save_data(save_data: Dictionary, existing_save: Dictionary = {}) -> Dictionary:
	var result := save_data.duplicate(true)
	var profile := ensure_profile_for_save(result, existing_save)
	result["achievement_profile"] = build_save_profile_stamp(profile)
	save_profiles_document()
	return result


func prepare_named_save_snapshot(snapshot_data: Dictionary, slot_id: String, display_name: String = "") -> Dictionary:
	var result := snapshot_data.duplicate(true)
	var source_profile := ensure_profile_for_save(result, {})
	var profile_id := build_named_profile_id(slot_id)
	var profile := ensure_profile(profile_id, {
		"profile_kind": "named",
		"slot_id": slot_id.strip_edges(),
		"display_name": display_name.strip_edges(),
		"source_profile_id": str(source_profile.get("profile_id", ""))
	}, source_profile)
	profile["profile_kind"] = "named"
	profile["slot_id"] = slot_id.strip_edges()
	if display_name.strip_edges() != "":
		profile["display_name"] = display_name.strip_edges()
	profile["source_profile_id"] = str(source_profile.get("profile_id", ""))
	set_profile(profile)
	result["achievement_profile"] = build_save_profile_stamp(profile)
	save_profiles_document()
	return result


func begin_profile_session(save_data: Dictionary = {}, map_ref = null) -> Dictionary:
	var source_save := save_data
	if source_save.is_empty() and save_manager != null and save_manager.has_method("read_universe_save_data"):
		source_save = save_manager.read_universe_save_data()

	var profile := ensure_profile_for_save(source_save, {})
	active_profile_id = str(profile.get("profile_id", ""))
	session_started = active_profile_id != ""
	session_start_unix = int(Time.get_unix_time_from_system())
	pending_flush_seconds = 0.0
	pending_distance = 0.0
	last_world_pos = get_map_world_pos(map_ref)

	if session_started:
		profile["last_session_started_at_unix"] = session_start_unix
		profile["last_session_started_at_text"] = get_current_datetime_text()
		set_profile(profile)
		save_profiles_document()

	return profile


func process_achievement_runtime(delta: float, map_ref = null) -> void:
	if delta <= 0.0:
		return
	if active_profile_id == "":
		begin_profile_session({}, map_ref)
	if active_profile_id == "":
		return

	var profile := get_profile(active_profile_id)
	if profile.is_empty():
		return

	profile["time_played_seconds"] = max(float(profile.get("time_played_seconds", 0.0)) + delta, 0.0)
	profile["time_played_from_start_seconds"] = float(profile.get("time_played_seconds", 0.0))
	pending_flush_seconds += delta

	var current_world_pos = get_map_world_pos(map_ref)
	if current_world_pos != null:
		if last_world_pos != null:
			var moved := float(last_world_pos.distance_to(current_world_pos))
			if moved > 0.001 and moved < 1000000.0:
				profile["distance_traveled"] = max(float(profile.get("distance_traveled", 0.0)) + moved, 0.0)
				pending_distance += moved
		last_world_pos = current_world_pos
		profile["last_map_position"] = build_map_position_packet(map_ref, current_world_pos)

	profile["updated_at_unix"] = int(Time.get_unix_time_from_system())
	profile["updated_at_text"] = get_current_datetime_text()
	set_profile(profile)

	if pending_flush_seconds >= AUTO_FLUSH_SECONDS or pending_distance >= AUTO_FLUSH_DISTANCE:
		flush_active_profile("runtime_auto_flush")


func flush_active_profile(reason: String = "manual") -> bool:
	if active_profile_id == "":
		return false
	var profile := get_profile(active_profile_id)
	if profile.is_empty():
		return false
	profile["last_flush_reason"] = reason
	profile["updated_at_unix"] = int(Time.get_unix_time_from_system())
	profile["updated_at_text"] = get_current_datetime_text()
	set_profile(profile)
	pending_flush_seconds = 0.0
	pending_distance = 0.0
	return save_profiles_document()


func record_enemy_defeated_from_battle_result(result: Dictionary) -> Dictionary:
	if typeof(result) != TYPE_DICTIONARY or result.is_empty():
		return {"ok": false, "reason": "empty battle result"}

	if active_profile_id == "":
		begin_profile_session()
	if active_profile_id == "":
		return {"ok": false, "reason": "missing active profile"}

	var record := build_enemy_defeat_record(result)
	return record_enemy_defeated(record)


func record_enemy_defeated(record: Dictionary) -> Dictionary:
	if active_profile_id == "":
		begin_profile_session()
	if active_profile_id == "":
		return {"ok": false, "reason": "missing active profile"}

	var profile := get_profile(active_profile_id)
	if profile.is_empty():
		return {"ok": false, "reason": "missing profile"}

	var safe_record = json_safe_value(record)
	if typeof(safe_record) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "invalid record"}

	var enemy_key := str(safe_record.get("defeated_key", "")).strip_edges()
	if enemy_key == "":
		enemy_key = build_enemy_defeat_key(safe_record)
	safe_record["defeated_key"] = enemy_key

	var known_keys = profile.get("defeated_enemy_keys", {})
	if typeof(known_keys) != TYPE_DICTIONARY:
		known_keys = {}

	if known_keys.has(enemy_key):
		return {
			"ok": true,
			"duplicate": true,
			"profile_id": active_profile_id,
			"defeated_key": enemy_key
		}

	var defeated_enemies = profile.get("defeated_enemies", [])
	if typeof(defeated_enemies) != TYPE_ARRAY:
		defeated_enemies = []

	safe_record["defeated_at_unix"] = int(Time.get_unix_time_from_system())
	safe_record["defeated_at_text"] = get_current_datetime_text()
	defeated_enemies.append(safe_record)
	known_keys[enemy_key] = {
		"defeated_at_unix": safe_record.get("defeated_at_unix", 0),
		"enemy_id": str(safe_record.get("enemy_id", "")),
		"enemy_name": str(safe_record.get("enemy_name", ""))
	}

	profile["defeated_enemy_keys"] = known_keys
	profile["defeated_enemies"] = defeated_enemies
	profile["enemies_defeated_count"] = defeated_enemies.size()
	profile["updated_at_unix"] = int(Time.get_unix_time_from_system())
	profile["updated_at_text"] = get_current_datetime_text()
	set_profile(profile)
	save_profiles_document()

	return {
		"ok": true,
		"duplicate": false,
		"profile_id": active_profile_id,
		"defeated_key": enemy_key,
		"enemies_defeated_count": defeated_enemies.size()
	}


func build_enemy_defeat_record(result: Dictionary) -> Dictionary:
	var shared_meta = result.get("defeated_enemy_shared_meta", {})
	if typeof(shared_meta) != TYPE_DICTIONARY:
		shared_meta = {}
	var signature = result.get("defeated_enemy_signature", {})
	if typeof(signature) != TYPE_DICTIONARY:
		signature = {}

	var enemy_id := str(result.get("defeated_enemy_id", shared_meta.get("object_id", shared_meta.get("enemy_id", "")))).strip_edges()
	var enemy_name := str(result.get("defeated_enemy_name", shared_meta.get("display_name", shared_meta.get("name", "Unknown enemy")))).strip_edges()
	if enemy_name == "":
		enemy_name = "Unknown enemy"

	var record := {
		"enemy_id": enemy_id,
		"enemy_name": enemy_name,
		"battle_outcome": str(result.get("outcome", result.get("battle_outcome", "player_victory"))),
		"defeated_enemy_signature": signature,
		"defeated_enemy_shared_meta": shared_meta
	}
	record["defeated_key"] = build_enemy_defeat_key(record)
	return record


func build_enemy_defeat_key(record: Dictionary) -> String:
	var enemy_id := str(record.get("enemy_id", "")).strip_edges()
	if enemy_id != "":
		return "id:" + sanitize_fragment(enemy_id, 120)

	var signature = record.get("defeated_enemy_signature", {})
	if typeof(signature) == TYPE_DICTIONARY and not signature.is_empty():
		return "sig:" + sanitize_fragment(JSON.stringify(json_safe_value(signature)), 160)

	var shared_meta = record.get("defeated_enemy_shared_meta", {})
	if typeof(shared_meta) == TYPE_DICTIONARY:
		var object_id := str(shared_meta.get("object_id", "")).strip_edges()
		if object_id != "":
			return "id:" + sanitize_fragment(object_id, 120)

	var name := str(record.get("enemy_name", "unknown_enemy")).strip_edges()
	return "name:" + sanitize_fragment(name, 120)


func ensure_profile_for_save(save_data: Dictionary, existing_save: Dictionary = {}) -> Dictionary:
	ensure_profiles_loaded()
	var profile_context := resolve_profile_context(save_data, existing_save)
	var profile_id := str(profile_context.get("profile_id", "")).strip_edges()
	var source_profile := {}
	if typeof(existing_save.get("achievement_profile", {})) == TYPE_DICTIONARY:
		var existing_stamp: Dictionary = existing_save.get("achievement_profile", {})
		var existing_id := str(existing_stamp.get("profile_id", "")).strip_edges()
		if existing_id != "":
			source_profile = get_profile(existing_id)
	return ensure_profile(profile_id, profile_context, source_profile)


func resolve_profile_context(save_data: Dictionary, existing_save: Dictionary = {}) -> Dictionary:
	var save_stamp = save_data.get("achievement_profile", {})
	if typeof(save_stamp) == TYPE_DICTIONARY:
		var stamped_profile_id := str(save_stamp.get("profile_id", "")).strip_edges()
		if stamped_profile_id != "":
			return {
				"profile_id": stamped_profile_id,
				"profile_kind": str(save_stamp.get("profile_kind", "autosave")),
				"slot_id": str(save_stamp.get("slot_id", "")),
				"save_lane": get_active_save_lane()
			}

	var existing_stamp = existing_save.get("achievement_profile", {})
	if typeof(existing_stamp) == TYPE_DICTIONARY:
		var existing_profile_id := str(existing_stamp.get("profile_id", "")).strip_edges()
		if existing_profile_id != "":
			return {
				"profile_id": existing_profile_id,
				"profile_kind": str(existing_stamp.get("profile_kind", "autosave")),
				"slot_id": str(existing_stamp.get("slot_id", "")),
				"save_lane": get_active_save_lane()
			}

	var slot_id := read_named_slot_id(save_data)
	var profile_kind := "named" if slot_id != "" else "autosave"
	var profile_id := build_named_profile_id(slot_id) if slot_id != "" else build_autosave_profile_id()
	return {
		"profile_id": profile_id,
		"profile_kind": profile_kind,
		"slot_id": slot_id,
		"save_lane": get_active_save_lane()
	}


func read_named_slot_id(save_data: Dictionary) -> String:
	for key in ["promoted_named_save_meta", "named_save_meta"]:
		var meta = save_data.get(key, {})
		if typeof(meta) == TYPE_DICTIONARY:
			var slot_id := str(meta.get("slot_id", "")).strip_edges()
			if slot_id != "":
				return slot_id
	return ""


func ensure_profile(profile_id: String, context: Dictionary = {}, source_profile: Dictionary = {}) -> Dictionary:
	ensure_profiles_loaded()
	var clean_profile_id := profile_id.strip_edges()
	if clean_profile_id == "":
		clean_profile_id = build_autosave_profile_id()

	var profiles = profiles_document.get("profiles", {})
	if typeof(profiles) != TYPE_DICTIONARY:
		profiles = {}

	var profile = profiles.get(clean_profile_id, {})
	var is_new = typeof(profile) != TYPE_DICTIONARY or profile.is_empty()
	if is_new:
		profile = build_empty_profile(clean_profile_id, context, source_profile)
	else:
		profile = profile.duplicate(true)

	profile["profile_id"] = clean_profile_id
	profile["save_lane"] = get_active_save_lane()
	if context.has("profile_kind"):
		profile["profile_kind"] = str(context.get("profile_kind", profile.get("profile_kind", "autosave")))
	if context.has("slot_id"):
		profile["slot_id"] = str(context.get("slot_id", profile.get("slot_id", "")))
	if context.has("display_name") and str(context.get("display_name", "")).strip_edges() != "":
		profile["display_name"] = str(context.get("display_name", "")).strip_edges()

	profile["updated_at_unix"] = int(Time.get_unix_time_from_system())
	profile["updated_at_text"] = get_current_datetime_text()
	profiles[clean_profile_id] = profile
	profiles_document["profiles"] = profiles
	return profile


func build_empty_profile(profile_id: String, context: Dictionary = {}, source_profile: Dictionary = {}) -> Dictionary:
	var now_unix := int(Time.get_unix_time_from_system())
	var now_text := get_current_datetime_text()
	var profile := {
		"profile_id": profile_id,
		"profile_kind": str(context.get("profile_kind", "autosave")),
		"save_lane": get_active_save_lane(),
		"slot_id": str(context.get("slot_id", "")),
		"display_name": str(context.get("display_name", "")),
		"created_at_unix": now_unix,
		"created_at_text": now_text,
		"updated_at_unix": now_unix,
		"updated_at_text": now_text,
		"time_played_seconds": 0.0,
		"time_played_from_start_seconds": 0.0,
		"distance_traveled": 0.0,
		"enemies_defeated_count": 0,
		"defeated_enemies": [],
		"defeated_enemy_keys": {},
		"last_map_position": {}
	}

	if typeof(source_profile) == TYPE_DICTIONARY and not source_profile.is_empty():
		profile["time_played_seconds"] = float(source_profile.get("time_played_seconds", 0.0))
		profile["time_played_from_start_seconds"] = float(profile.get("time_played_seconds", 0.0))
		profile["distance_traveled"] = float(source_profile.get("distance_traveled", 0.0))
		profile["enemies_defeated_count"] = int(source_profile.get("enemies_defeated_count", 0))
		profile["defeated_enemies"] = json_safe_value(source_profile.get("defeated_enemies", []))
		profile["defeated_enemy_keys"] = json_safe_value(source_profile.get("defeated_enemy_keys", {}))
		profile["last_map_position"] = json_safe_value(source_profile.get("last_map_position", {}))
		profile["source_profile_id"] = str(source_profile.get("profile_id", ""))

	return profile


func build_save_profile_stamp(profile: Dictionary) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"profile_id": str(profile.get("profile_id", "")),
		"profile_kind": str(profile.get("profile_kind", "autosave")),
		"save_lane": str(profile.get("save_lane", get_active_save_lane())),
		"slot_id": str(profile.get("slot_id", "")),
		"achievement_profiles_path": get_profiles_path(),
		"updated_at_unix": int(profile.get("updated_at_unix", int(Time.get_unix_time_from_system()))),
		"updated_at_text": str(profile.get("updated_at_text", get_current_datetime_text()))
	}


func build_autosave_profile_id() -> String:
	return sanitize_fragment(get_active_save_lane(), 72) + "__autosave"


func build_named_profile_id(slot_id: String) -> String:
	return sanitize_fragment(get_active_save_lane(), 72) + "__named__" + sanitize_fragment(slot_id, 96)


func get_profile(profile_id: String) -> Dictionary:
	ensure_profiles_loaded()
	var profiles = profiles_document.get("profiles", {})
	if typeof(profiles) != TYPE_DICTIONARY:
		return {}
	var profile = profiles.get(profile_id, {})
	if typeof(profile) == TYPE_DICTIONARY:
		return profile.duplicate(true)
	return {}


func set_profile(profile: Dictionary) -> void:
	if typeof(profile) != TYPE_DICTIONARY or profile.is_empty():
		return
	ensure_profiles_loaded()
	var profile_id := str(profile.get("profile_id", "")).strip_edges()
	if profile_id == "":
		return
	var profiles = profiles_document.get("profiles", {})
	if typeof(profiles) != TYPE_DICTIONARY:
		profiles = {}
	profiles[profile_id] = json_safe_value(profile)
	profiles_document["profiles"] = profiles
	profiles_document["updated_at_unix"] = int(Time.get_unix_time_from_system())
	profiles_document["updated_at_text"] = get_current_datetime_text()


func ensure_profiles_loaded() -> void:
	if not profiles_document.is_empty():
		return
	profiles_document = read_profiles_document()
	if profiles_document.is_empty():
		profiles_document = get_empty_profiles_document()
	if typeof(profiles_document.get("profiles", {})) != TYPE_DICTIONARY:
		profiles_document["profiles"] = {}
	profiles_document["schema_version"] = int(profiles_document.get("schema_version", SCHEMA_VERSION))
	profiles_document["save_lane"] = get_active_save_lane()
	profiles_document["profiles_path"] = get_profiles_path()


func get_empty_profiles_document() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"save_lane": get_active_save_lane(),
		"profiles_path": get_profiles_path(),
		"created_at_unix": int(Time.get_unix_time_from_system()),
		"created_at_text": get_current_datetime_text(),
		"updated_at_unix": int(Time.get_unix_time_from_system()),
		"updated_at_text": get_current_datetime_text(),
		"profiles": {}
	}


func read_profiles_document() -> Dictionary:
	var path := get_profiles_path()
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


func save_profiles_document() -> bool:
	ensure_profiles_loaded()
	profiles_document["schema_version"] = SCHEMA_VERSION
	profiles_document["save_lane"] = get_active_save_lane()
	profiles_document["profiles_path"] = get_profiles_path()
	profiles_document["updated_at_unix"] = int(Time.get_unix_time_from_system())
	profiles_document["updated_at_text"] = get_current_datetime_text()
	last_saved_profiles_document = profiles_document.duplicate(true)

	if not disk_writes_enabled:
		return true

	if save_manager != null and save_manager.has_method("ensure_save_dirs"):
		if not bool(save_manager.ensure_save_dirs()):
			return false
	else:
		ensure_fallback_save_dirs()

	var file := FileAccess.open(get_profiles_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(json_safe_value(profiles_document), "\t"))
	file.close()
	return true


func ensure_fallback_save_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(DEFAULT_SAVE_ROOT_DIR)
	DirAccess.make_dir_recursive_absolute(DEFAULT_UNIVERSE_SAVE_ROOT_DIR)
	DirAccess.make_dir_recursive_absolute(DEFAULT_UNIVERSE_SAVE_ROOT_DIR + "/" + get_active_save_lane())


func get_map_world_pos(map_ref):
	if map_ref == null:
		return null
	if map_ref.has_method("get_world_pos"):
		var value = map_ref.get_world_pos()
		if typeof(value) == TYPE_VECTOR3:
			return value
	var sector := read_vector3i(map_ref.get("sector_pos") if map_ref != null else Vector3i.ZERO)
	var local := read_vector3(map_ref.get("local_pos") if map_ref != null else Vector3.ZERO)
	return Vector3(
		float(sector.x) * Globals.sector_size + local.x,
		float(sector.y) * Globals.sector_size + local.y,
		float(sector.z) * Globals.sector_size + local.z
	)


func build_map_position_packet(map_ref, world_pos) -> Dictionary:
	var packet := {}
	if map_ref != null:
		packet["sector_pos"] = vector3i_to_dict(read_vector3i(map_ref.get("sector_pos")))
		packet["local_pos"] = vector3_to_dict(read_vector3(map_ref.get("local_pos")))
	if typeof(world_pos) == TYPE_VECTOR3:
		packet["world_pos"] = vector3_to_dict(world_pos)
	return packet


func read_vector3i(value) -> Vector3i:
	if typeof(value) == TYPE_VECTOR3I:
		return value
	if typeof(value) == TYPE_VECTOR3:
		return Vector3i(int(value.x), int(value.y), int(value.z))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3i(int(value.get("x", 0)), int(value.get("y", 0)), int(value.get("z", 0)))
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	return Vector3i.ZERO


func read_vector3(value) -> Vector3:
	if typeof(value) == TYPE_VECTOR3:
		return value
	if typeof(value) == TYPE_VECTOR3I:
		return Vector3(float(value.x), float(value.y), float(value.z))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func vector3_to_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func vector3i_to_dict(value: Vector3i) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func json_safe_value(value):
	var value_type := typeof(value)
	if value_type == TYPE_DICTIONARY:
		var output := {}
		for key in value.keys():
			output[str(key)] = json_safe_value(value[key])
		return output
	if value_type == TYPE_ARRAY:
		var output_array := []
		for entry in value:
			output_array.append(json_safe_value(entry))
		return output_array
	if value_type == TYPE_VECTOR3:
		return vector3_to_dict(value)
	if value_type == TYPE_VECTOR3I:
		return vector3i_to_dict(value)
	if value_type == TYPE_VECTOR2:
		return {"x": value.x, "y": value.y}
	if value_type == TYPE_VECTOR2I:
		return {"x": value.x, "y": value.y}
	return value


func sanitize_fragment(text: String, max_length: int = 72) -> String:
	var lower := text.strip_edges().to_lower()
	var out := ""
	var valid_chars := "abcdefghijklmnopqrstuvwxyz0123456789"
	for i in range(lower.length()):
		var ch := lower.substr(i, 1)
		if valid_chars.find(ch) != -1:
			out += ch
		elif out != "" and not out.ends_with("_"):
			out += "_"

	while out.ends_with("_"):
		out = out.substr(0, out.length() - 1)

	if out == "":
		out = "save"

	var clean_max_length = max(max_length, 1)
	if out.length() > clean_max_length:
		out = out.substr(0, clean_max_length)

	return out
