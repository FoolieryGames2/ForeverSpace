extends Node
class_name EventStoryStorage

const DEFAULT_STORAGE_DIR := "res://data/events"
const FILE_EXTENSION := ".json"
const EVENT_INTEL_CONDITION_KEYS := [
	"intel_conditions",
	"awareness_conditions",
	"event_conditions",
	"requires_intel",
	"conditions"
]
const EVENT_INTEL_CONDITION_TYPES := [
	"intel_discovered",
	"intel_count_at_least",
	"intel_seen_count",
	"enemy_defeated_count",
	"enemy_serial_defeated",
	"event_enemy_defeated",
	"enemy_display_defeated_count"
]
const EVENT_WIDGET_ACTION_IDS := [
	"open_event_list",
	"select_event",
	"start_available_event",
	"start_event",
	"download_beacon_data",
	"claim_event_reward",
	"show_story_popup",
	"story_popup",
	"show_tutorial_hint",
	"tutorial_hint",
	"show_helper_message",
	"event_operations",
	"run_operations",
	"advance_step"
]
const EVENT_STEP_INTERACTION_TYPES := [
	"offer",
	"talk",
	"npc_contact",
	"story_popup",
	"tutorial_popup",
	"find",
	"travel",
	"go_to",
	"arrive",
	"inspect",
	"hunt",
	"battle",
	"download",
	"handoff",
	"turn_in",
	"claim",
	"complete",
	"event_start"
]
const ORBIT_EVENT_LISTENER_COLLECTION_KEYS := [
	"orbit_event_listeners",
	"orbit_discovered_event_listeners",
	"orbital_event_listeners"
]
const ORBIT_EVENT_LISTENER_NESTED_KEYS := [
	"orbit_event_listeners",
	"event_listeners",
	"discover_events",
	"silent_discover_events"
]
const ORBIT_EVENT_ID_KEYS := [
	"trigger_event_id",
	"event_id",
	"target_event_id",
	"discover_event_id",
	"activate_event_id"
]
const MAIN_VIEW_ICON_ID_PATH_TEMPLATES := [
	"res://UI/PortView/main_view/icons/{id}.png",
	"res://UI/PortView/main_view/icons/icon_{id}.png",
	"res://UI/PortView/main_view/{id}.png",
	"res://UI/PortView/main_view/icon_{id}.png"
]
const AUTHORED_ICON_LABELS := [
	"authored_object",
	"event_object",
	"catalog_npc",
	"catalog_enemy",
	"catalog_world_seed"
]


func ensure_storage_dir() -> bool:
	var storage_dir := get_storage_dir()
	var error := OK
	if storage_dir.begins_with("res://"):
		var root := DirAccess.open("res://")
		if root == null:
			return false
		error = root.make_dir_recursive(storage_dir.trim_prefix("res://"))
	else:
		error = DirAccess.make_dir_recursive_absolute(storage_dir)
	return error == OK or error == ERR_ALREADY_EXISTS


func get_storage_dir() -> String:
	var lane_dir := str(Globals.active_universe_events_dir).strip_edges()
	if lane_dir != "":
		return lane_dir
	return DEFAULT_STORAGE_DIR


func save_event_packet(packet: Dictionary) -> Dictionary:
	if not ensure_storage_dir():
		return make_result("failed", "could not create event storage folder", "")

	var event_id := sanitize_id(str(packet.get("event_id", "")))
	if event_id == "":
		return make_result("failed", "missing event_id", "")

	packet["event_id"] = event_id
	var file_path := get_event_file(event_id)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return make_result("failed", "could not open file for write", file_path)

	file.store_string(JSON.stringify(packet, "\t"))
	file.close()
	return make_result("success", "", file_path)


func load_event_packet(event_id: String) -> Dictionary:
	var file_path := resolve_event_file_path(event_id)
	if file_path == "":
		return {}

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if not is_event_packet_shape(parsed):
		return {}

	return parsed


func list_event_ids() -> Array:
	if not ensure_storage_dir():
		return []

	var dir := DirAccess.open(get_storage_dir())
	if dir == null:
		return []

	var ids: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(FILE_EXTENSION):
			var file_path := get_storage_dir().path_join(file_name)
			if is_event_packet_file(file_path):
				ids.append(file_name.trim_suffix(FILE_EXTENSION))
		file_name = dir.get_next()
	dir.list_dir_end()
	ids.sort()
	return ids


func get_event_file(event_id: String) -> String:
	return get_storage_dir().path_join(sanitize_id(event_id) + FILE_EXTENSION)


func resolve_event_file_path(event_id_or_file_stem: String) -> String:
	var raw_id := event_id_or_file_stem.strip_edges()
	if raw_id == "":
		return ""
	if raw_id.begins_with("res://") and FileAccess.file_exists(raw_id):
		return raw_id

	var stem := raw_id.trim_suffix(FILE_EXTENSION)
	var candidates: Array = []
	append_event_file_candidate(candidates, stem)

	var clean_id := sanitize_id(stem)
	if clean_id != "":
		append_event_file_candidate(candidates, clean_id)

	if stem.find("_") >= 0:
		append_event_file_candidate(candidates, stem.replace("_", " "))

	for file_path in candidates:
		if FileAccess.file_exists(str(file_path)):
			return str(file_path)
	return ""


func append_event_file_candidate(candidates: Array, file_stem: String) -> void:
	var clean_stem := file_stem.strip_edges()
	if clean_stem == "":
		return
	var file_path := get_storage_dir().path_join(clean_stem + FILE_EXTENSION)
	if not candidates.has(file_path):
		candidates.append(file_path)


func is_event_packet_file(file_path: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	return is_event_packet_shape(parsed)


func is_event_packet_shape(packet) -> bool:
	if typeof(packet) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = packet
	if data.has("event_id") or data.has("steps") or data.has("event_objects") or data.has("event_listeners"):
		return true
	for key in ORBIT_EVENT_LISTENER_COLLECTION_KEYS:
		if data.has(str(key)):
			return true
	return false


func sanitize_id(raw_id: String) -> String:
	var clean := raw_id.strip_edges().to_lower()
	clean = clean.replace(" ", "_")
	var output := ""
	for i in range(clean.length()):
		var c := clean.substr(i, 1)
		var keep := false
		keep = keep or (c >= "a" and c <= "z")
		keep = keep or (c >= "0" and c <= "9")
		keep = keep or c == "_"
		keep = keep or c == "-"
		if keep:
			output += c
	return output


func validate_event_packet(packet: Dictionary) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []

	var event_id := str(packet.get("event_id", "")).strip_edges()
	if event_id == "":
		errors.append("event_id is required.")
	if sanitize_id(event_id) != event_id:
		warnings.append("event_id will be saved as: " + sanitize_id(event_id))

	if str(packet.get("display_name", "")).strip_edges() == "":
		errors.append("display_name is required.")

	var event_objects = packet.get("event_objects", {})
	if typeof(event_objects) != TYPE_DICTIONARY:
		errors.append("event_objects must be a Dictionary.")
		event_objects = {}

	var event_listeners = packet.get("event_listeners", {})
	if typeof(event_listeners) != TYPE_DICTIONARY:
		errors.append("event_listeners must be a Dictionary when present.")
		event_listeners = {}

	var steps = packet.get("steps", {})
	if typeof(steps) != TYPE_DICTIONARY or steps.is_empty():
		errors.append("steps must contain at least one step.")
		steps = {}

	var current_step := str(packet.get("current_step", "")).strip_edges()
	if current_step == "":
		errors.append("current_step is required.")
	elif not steps.has(current_step):
		errors.append("current_step does not exist in steps: " + current_step)
	else:
		validate_step_chain_shape(current_step, steps, errors, warnings)

	var giver: Dictionary = packet.get("giver", {}) if typeof(packet.get("giver", {})) == TYPE_DICTIONARY else {}
	if giver.is_empty():
		if bool(packet.get("requires_giver", false)):
			errors.append("giver is required when requires_giver is true.")
		else:
			warnings.append("giver is empty. This is valid for listener-driven or popup-driven event chains.")
	else:
		for key in ["owner_id", "object_id", "blueprint_id", "display_name"]:
			if str(giver.get(key, "")).strip_edges() == "":
				warnings.append("giver." + key + " is empty.")
		validate_giver_identity(giver, errors, warnings)

	var reward: Dictionary = packet.get("reward_packet", {}) if typeof(packet.get("reward_packet", {})) == TYPE_DICTIONARY else {}
	validate_reward_packet_current_shape(reward, warnings)

	validate_event_object_positions(event_objects, warnings)
	validate_event_object_positions(event_listeners, warnings)
	validate_event_object_identity(event_objects, errors, warnings)
	validate_authored_main_view_icons(event_objects, warnings, "event object")
	validate_authored_main_view_icons(event_listeners, warnings, "event listener")
	if not giver.is_empty():
		validate_one_main_view_icon("giver", giver, warnings)
	validate_event_intel_conditions("event", packet, event_id, event_objects, errors, warnings)
	validate_event_listeners(event_listeners, event_id, steps, event_objects, errors, warnings)
	validate_orbit_event_listener_collections(packet, event_id, current_step, steps, errors, warnings)

	for step_id in steps.keys():
		var step = steps[step_id]
		if typeof(step) != TYPE_DICTIONARY:
			errors.append("step is not a Dictionary: " + str(step_id))
			continue

		if str(step.get("objective_text", "")).strip_edges() == "":
			warnings.append(str(step_id) + " has no objective_text.")

		var interaction_type := str(step.get("interaction_type", step.get("event_type", step.get("step_kind", "")))).strip_edges().to_lower()
		if interaction_type != "" and not EVENT_STEP_INTERACTION_TYPES.has(interaction_type):
			warnings.append(str(step_id) + " uses an interaction_type not exposed by the current dev tool: " + interaction_type)

		var next_step := str(step.get("next_step", "")).strip_edges()
		if next_step != "" and next_step != "completed" and not steps.has(next_step):
			errors.append(str(step_id) + " points to missing next_step: " + next_step)

		var target_object_id := str(step.get("target_object_id", "")).strip_edges()
		if target_object_id != "" and not event_objects.has(target_object_id):
			errors.append(str(step_id) + " points to missing target_object_id: " + target_object_id)

		var enemy_id := str(step.get("enemy_id", "")).strip_edges()
		if enemy_id != "" and not event_objects.has(enemy_id):
			errors.append(str(step_id) + " points to missing enemy_id: " + enemy_id)
		if enemy_id != "" and target_object_id != "" and enemy_id != target_object_id:
			errors.append(str(step_id) + " target_object_id and enemy_id should match for hunt steps.")

		var target_owner_id := str(step.get("target_owner_id", "")).strip_edges()
		if target_owner_id != "" and not target_owner_matches_giver(target_owner_id, giver):
			warnings.append(str(step_id) + " target_owner_id does not match the giver: " + target_owner_id)

		validate_current_range_shape(str(step_id), step, warnings)
		validate_current_battle_shape(str(step_id), step, event_objects, warnings)
		validate_step_dialogue_fields(str(step_id), step, giver, event_objects, errors, warnings)
		validate_event_intel_conditions(str(step_id), step, event_id, event_objects, errors, warnings)
		validate_step_operations(str(step_id), step, event_objects, steps, errors, warnings)

	return {
		"status": "success" if errors.is_empty() else "failed",
		"errors": errors,
		"warnings": warnings,
		"labels": ["event_story_storage", "validation"]
	}


func validate_giver_identity(giver: Dictionary, errors: Array, warnings: Array) -> void:
	var stable_id := str(giver.get("template_owner_id", giver.get("owner_id", ""))).strip_edges()
	if stable_id == "":
		return
	for key in ["owner_id", "object_id", "template_owner_id"]:
		var value := str(giver.get(key, "")).strip_edges()
		if value != "" and value != stable_id:
			errors.append("giver." + key + " must match the stable giver id: " + stable_id)
	var blueprint_id := str(giver.get("blueprint_id", "")).strip_edges()
	if blueprint_id != "" and blueprint_id != stable_id:
		if allows_catalog_blueprint(giver):
			warnings.append("giver uses catalog blueprint " + blueprint_id + " with stable giver id " + stable_id + ".")
		else:
			errors.append("giver.blueprint_id must match the stable giver id for authored NPCs: " + stable_id)
	var labels = giver.get("labels", [])
	if typeof(labels) == TYPE_ARRAY and not labels.has("authored_object"):
		warnings.append("giver labels should include authored_object for one-off story NPCs.")


func validate_event_object_identity(event_objects: Dictionary, errors: Array, warnings: Array) -> void:
	for object_id in event_objects.keys():
		var object_data = event_objects[object_id]
		if typeof(object_data) != TYPE_DICTIONARY:
			errors.append("event object is not a Dictionary: " + str(object_id))
			continue

		var declared_id := str(object_data.get("object_id", "")).strip_edges()
		if declared_id == "":
			errors.append(str(object_id) + " is missing object_id.")
		elif declared_id != str(object_id):
			errors.append(str(object_id) + " key and object_id must match. Found object_id: " + declared_id)

		var object_type := str(object_data.get("object_type", object_data.get("owner_type", ""))).strip_edges().to_lower()
		if object_type == "npc":
			validate_actor_identity(str(object_id), object_data, ["owner_id", "template_owner_id", "blueprint_id"], errors, warnings)
			validate_dialogue_lines(str(object_id) + " dialogue_lines", object_data.get("dialogue_lines", []), errors)
			if object_data.has("chat_line_delay") and float(object_data.get("chat_line_delay", 0.0)) <= 0.0:
				errors.append(str(object_id) + " chat_line_delay must be greater than 0.")
			if object_data.has("chat_character_delay") and float(object_data.get("chat_character_delay", 0.0)) <= 0.0:
				errors.append(str(object_id) + " chat_character_delay must be greater than 0.")
			if object_data.has("item_list"):
				validate_trade_items(str(object_id) + " item_list", object_data.get("item_list", []), errors)
		elif object_type == "enemy":
			validate_actor_identity(str(object_id), object_data, ["template_owner_id", "blueprint_id"], errors, warnings)


func validate_authored_main_view_icons(objects: Dictionary, warnings: Array, label_prefix: String) -> void:
	for object_id in objects.keys():
		var object_data = objects[object_id]
		if typeof(object_data) != TYPE_DICTIONARY:
			continue
		validate_one_main_view_icon(label_prefix + " " + str(object_id), object_data, warnings)


func validate_one_main_view_icon(label: String, object_data: Dictionary, warnings: Array) -> void:
	if not should_validate_authored_icon(object_data):
		return

	var icon_id := read_main_view_icon_string(object_data, ["main_view_icon_id", "main_view_icon", "icon_id"])
	var icon_path := read_main_view_icon_string(object_data, ["main_view_icon_path", "icon_path"])

	if icon_id == "" and icon_path == "":
		warnings.append(label + " is authored/visible but has no main_view_icon_id or main_view_icon_path; it will fall back to a default marker.")
		return

	if icon_id == "":
		warnings.append(label + " has main_view_icon_path but no main_view_icon_id; add an id so the dev tool and dropdowns can link it.")
	else:
		var clean_icon_id := normalize_main_view_icon_id(icon_id)
		if icon_path == "" and not main_view_icon_id_resolves(clean_icon_id):
			warnings.append(label + " main_view_icon_id does not resolve to an icon file: " + icon_id + " checked " + join_strings(get_main_view_icon_expected_paths(clean_icon_id), ", "))

	if icon_path != "":
		validate_main_view_icon_path(label, icon_path, warnings)


func should_validate_authored_icon(object_data: Dictionary) -> bool:
	if not bool(object_data.get("is_visible", true)):
		return false
	if str(object_data.get("catalog_source", "")).strip_edges() != "":
		return true
	if str(object_data.get("source_blueprint_id", "")).strip_edges() != "":
		return true
	if str(object_data.get("source_world_seed_object_id", "")).strip_edges() != "":
		return true

	var labels = object_data.get("labels", [])
	if typeof(labels) == TYPE_ARRAY:
		for label in labels:
			var clean_label := str(label).strip_edges().to_lower()
			if AUTHORED_ICON_LABELS.has(clean_label) or clean_label.begins_with("catalog_"):
				return true
	return false


func read_main_view_icon_string(source: Dictionary, keys: Array) -> String:
	for key in keys:
		var clean_key := str(key)
		if source.has(clean_key) and str(source.get(clean_key, "")).strip_edges() != "":
			return str(source.get(clean_key)).strip_edges()

	for nested_key in ["visual", "metadata", "meta", "shared_meta"]:
		var nested = source.get(nested_key, {})
		if typeof(nested) != TYPE_DICTIONARY:
			continue
		for key in keys:
			var clean_key := str(key)
			if nested.has(clean_key) and str(nested.get(clean_key, "")).strip_edges() != "":
				return str(nested.get(clean_key)).strip_edges()

	return ""


func validate_main_view_icon_path(label: String, raw_path: String, warnings: Array) -> void:
	var path := raw_path.strip_edges()
	if path == "":
		return
	if not path.begins_with("res://"):
		warnings.append(label + " main_view_icon_path should use a res:// path: " + path)
		return
	if not ResourceLoader.exists(path):
		warnings.append(label + " main_view_icon_path was not found: " + path)


func main_view_icon_id_resolves(icon_id: String) -> bool:
	if icon_id == "":
		return false
	for path in get_main_view_icon_expected_paths(icon_id):
		if ResourceLoader.exists(str(path)):
			return true
	return false


func get_main_view_icon_expected_paths(icon_id: String) -> Array:
	var paths: Array = []
	for template in MAIN_VIEW_ICON_ID_PATH_TEMPLATES:
		paths.append(str(template).replace("{id}", icon_id))
	return paths


func normalize_main_view_icon_id(icon_id: String) -> String:
	return icon_id.strip_edges().to_lower().replace(" ", "_").replace("-", "_")


func validate_actor_identity(object_id: String, object_data: Dictionary, keys: Array, errors: Array, warnings: Array) -> void:
	var labels = object_data.get("labels", [])
	var authored = typeof(labels) == TYPE_ARRAY and labels.has("authored_object")
	for key in keys:
		var value := str(object_data.get(str(key), "")).strip_edges()
		if value == "":
			if authored:
				warnings.append(object_id + " is authored but missing " + str(key) + ".")
			continue
		if value != object_id:
			var message := object_id + " " + str(key) + " should match object_id. Found: " + value
			if str(key) == "blueprint_id" and allows_catalog_blueprint(object_data):
				warnings.append(object_id + " uses catalog blueprint " + value + ".")
			elif authored:
				errors.append(message)
			else:
				warnings.append(message)
	if typeof(labels) == TYPE_ARRAY and authored and not labels.has(object_id):
		warnings.append(object_id + " labels should include the object id.")


func allows_catalog_blueprint(object_data: Dictionary) -> bool:
	var source_blueprint_id := str(object_data.get("source_blueprint_id", "")).strip_edges()
	if source_blueprint_id != "":
		return true
	var catalog_source := str(object_data.get("catalog_source", "")).strip_edges()
	return catalog_source == "npc_blueprints" or catalog_source == "enemy_blueprints"


func validate_event_listeners(event_listeners: Dictionary, event_id: String, steps: Dictionary, event_objects: Dictionary, errors: Array, warnings: Array) -> void:
	for listener_id in event_listeners.keys():
		var listener_data = event_listeners[listener_id]
		if typeof(listener_data) != TYPE_DICTIONARY:
			errors.append("event listener is not a Dictionary: " + str(listener_id))
			continue

		var declared_id := str(listener_data.get("object_id", "")).strip_edges()
		if declared_id == "":
			errors.append(str(listener_id) + " listener is missing object_id.")
		elif declared_id != str(listener_id):
			errors.append(str(listener_id) + " listener key and object_id must match. Found object_id: " + declared_id)

		var listener_type := str(listener_data.get("listener_type", "")).strip_edges()
		if listener_type == "":
			errors.append(str(listener_id) + " is missing listener_type.")
		elif not is_supported_listener_type(listener_type):
			warnings.append(str(listener_id) + " uses an unknown listener_type: " + listener_type)
		elif is_activate_listener_type(listener_type):
			var start_step := str(listener_data.get("start_step", "")).strip_edges()
			if start_step == "":
				warnings.append(str(listener_id) + " activate listener has no start_step; the event current_step will be used.")
			elif not steps.has(start_step):
				errors.append(str(listener_id) + " start_step does not exist in steps: " + start_step)

		var trigger_event_id := str(listener_data.get("trigger_event_id", "")).strip_edges()
		if trigger_event_id == "":
			errors.append(str(listener_id) + " is missing trigger_event_id.")
		elif trigger_event_id != event_id:
			errors.append(str(listener_id) + " trigger_event_id must match this event_id. Found: " + trigger_event_id)

		if float(listener_data.get("trigger_range", 0.0)) <= 0.0:
			errors.append(str(listener_id) + " trigger_range must be greater than 0.")

		var labels = listener_data.get("labels", [])
		if typeof(labels) != TYPE_ARRAY or not labels.has("event_listener"):
			warnings.append(str(listener_id) + " labels should include event_listener.")
		if typeof(labels) == TYPE_ARRAY and not labels.has("authored_object"):
			warnings.append(str(listener_id) + " labels should include authored_object.")
		if typeof(labels) == TYPE_ARRAY and (labels.has("hidden_listener") or labels.has("invisible_listener")) and bool(listener_data.get("is_visible", true)):
			warnings.append(str(listener_id) + " has hidden listener labels but is_visible is true.")
		if (is_activate_listener_type(listener_type) or is_seed_listener_type(listener_type)) and not bool(listener_data.get("trigger_once", true)):
			warnings.append(str(listener_id) + " story listener should usually trigger_once.")
		if is_activate_listener_type(listener_type) and not bool(listener_data.get("suppress_trigger_popup", false)):
			var popup_start_step := str(listener_data.get("start_step", "")).strip_edges()
			if popup_start_step != "" and steps.has(popup_start_step) and step_opens_story_popup(steps[popup_start_step]):
				warnings.append(str(listener_id) + " activate listener may show generic feedback over the first story popup; consider suppress_trigger_popup true.")
		validate_event_intel_conditions(str(listener_id) + " listener", listener_data, event_id, event_objects, errors, warnings)


func validate_orbit_event_listener_collections(packet: Dictionary, current_event_id: String, current_step: String, current_steps: Dictionary, errors: Array, warnings: Array) -> void:
	for key in ORBIT_EVENT_LISTENER_COLLECTION_KEYS:
		if packet.has(str(key)):
			validate_orbit_event_listener_collection(str(key), packet.get(str(key)), current_event_id, current_step, current_steps, errors, warnings)

	for nested_key in ["discoveries", "orbit_discoveries", "interactions", "orbit_interactions"]:
		if packet.has(str(nested_key)):
			validate_orbit_event_nested_sources(str(nested_key), packet.get(str(nested_key)), current_event_id, current_step, current_steps, errors, warnings)


func validate_orbit_event_nested_sources(label: String, raw_value, current_event_id: String, current_step: String, current_steps: Dictionary, errors: Array, warnings: Array) -> void:
	if raw_value == null:
		return
	if typeof(raw_value) == TYPE_ARRAY:
		for i in range(raw_value.size()):
			validate_orbit_event_nested_sources(label + "[" + str(i) + "]", raw_value[i], current_event_id, current_step, current_steps, errors, warnings)
		return
	if typeof(raw_value) != TYPE_DICTIONARY:
		warnings.append(label + " is not a Dictionary or Array; Orbit listener validation skipped for this value.")
		return

	var source_data: Dictionary = raw_value
	for listener_key in ORBIT_EVENT_LISTENER_NESTED_KEYS:
		if source_data.has(str(listener_key)):
			validate_orbit_event_listener_collection(label + "." + str(listener_key), source_data.get(str(listener_key)), current_event_id, current_step, current_steps, errors, warnings)

	if not orbit_event_listener_dict_is_packet(source_data):
		for key in source_data.keys():
			var child = source_data[key]
			if typeof(child) == TYPE_DICTIONARY or typeof(child) == TYPE_ARRAY:
				validate_orbit_event_nested_sources(label + "." + str(key), child, current_event_id, current_step, current_steps, errors, warnings)


func validate_orbit_event_listener_collection(label: String, raw_value, current_event_id: String, current_step: String, current_steps: Dictionary, errors: Array, warnings: Array) -> void:
	if raw_value == null:
		return

	if typeof(raw_value) == TYPE_STRING or typeof(raw_value) == TYPE_STRING_NAME:
		var event_id := str(raw_value).strip_edges()
		if event_id == "":
			errors.append(label + " contains an empty event id.")
			return
		validate_orbit_event_listener_packet(label, {"event_id": event_id}, current_event_id, current_step, current_steps, errors, warnings)
		return

	if typeof(raw_value) == TYPE_ARRAY:
		for i in range(raw_value.size()):
			validate_orbit_event_listener_collection(label + "[" + str(i) + "]", raw_value[i], current_event_id, current_step, current_steps, errors, warnings)
		return

	if typeof(raw_value) != TYPE_DICTIONARY:
		errors.append(label + " must be a String, Array, or Dictionary.")
		return

	var source_data: Dictionary = raw_value
	if orbit_event_listener_dict_is_packet(source_data):
		validate_orbit_event_listener_packet(label, source_data, current_event_id, current_step, current_steps, errors, warnings)
		return

	for key in source_data.keys():
		validate_orbit_event_listener_collection(label + "." + str(key), source_data[key], current_event_id, current_step, current_steps, errors, warnings)


func orbit_event_listener_dict_is_packet(data: Dictionary) -> bool:
	for key in ["event_id", "trigger_event_id", "target_event_id", "discover_event_id", "activate_event_id", "listener_type", "installed_listener_type", "target_listener_type", "orbit_event_action", "event_action", "action"]:
		if data.has(str(key)):
			return true
	return false


func validate_orbit_event_listener_packet(label: String, raw_packet: Dictionary, current_event_id: String, current_step: String, current_steps: Dictionary, errors: Array, warnings: Array) -> void:
	var packet := raw_packet.duplicate(true)
	var event_id := resolve_orbit_event_listener_event_id(packet)
	if event_id == "":
		errors.append(label + " is missing event_id/trigger_event_id/target_event_id.")
		return

	if sanitize_id(event_id) != event_id:
		warnings.append(label + " targets event id that will sanitize differently: " + event_id + " -> " + sanitize_id(event_id))

	if event_id != current_event_id and resolve_event_file_path(event_id) == "":
		warnings.append(label + " targets an event file that was not found in the active event lane: " + event_id)

	var listener_type := str(packet.get("listener_type", packet.get("installed_listener_type", "discover_event"))).strip_edges()
	if listener_type == "":
		listener_type = "discover_event"

	var raw_action := str(packet.get("orbit_event_action", packet.get("event_action", packet.get("action", "")))).strip_edges()
	var action := raw_action
	if action == "":
		action = infer_orbit_event_listener_action(listener_type)
	if raw_action != "" and not is_known_orbit_event_action_alias(raw_action):
		warnings.append(label + " uses unknown orbit_event_action '" + raw_action + "'. Runtime will normalize it to discover_event.")
	action = normalize_orbit_event_listener_action(action)

	var silent := bool(packet.get("silent", packet.get("silent_discovery", packet.get("background", false))))
	if listener_type in ["silent_discover_event", "discover_event_silent", "silent_activate_event", "activate_event_silent"]:
		silent = true
	var visible_in_orbit := bool(packet.get("visible_in_orbit", not silent))
	if silent and visible_in_orbit:
		warnings.append(label + " is silent but visible_in_orbit is true; background discoveries should usually stay hidden.")
	if not silent and not visible_in_orbit:
		warnings.append(label + " is visible_in_orbit false but silent is false; decide whether this is a UI discovery or a background handoff.")

	if str(packet.get("queue_id", packet.get("id", packet.get("listener_id", "")))).strip_edges() == "":
		warnings.append(label + " has no queue_id/id/listener_id. Runtime will generate one from event/action/source context.")

	match action:
		"install_event_listener":
			validate_orbit_install_listener_packet(label, packet, event_id, current_event_id, current_step, current_steps, errors, warnings)
		"activate_event":
			validate_orbit_activate_packet(label, packet, event_id, current_event_id, current_step, current_steps, errors, warnings)
		_:
			pass


func validate_orbit_install_listener_packet(label: String, packet: Dictionary, event_id: String, current_event_id: String, current_step: String, current_steps: Dictionary, errors: Array, warnings: Array) -> void:
	var listener_id := str(packet.get("listener_id", packet.get("object_id", ""))).strip_edges()
	if listener_id == "":
		warnings.append(label + " install_event_listener has no listener_id/object_id. Runtime will use queue_id or event_id + _orbit_listener.")

	var installed_listener_type := str(packet.get("installed_listener_type", packet.get("target_listener_type", ""))).strip_edges()
	if installed_listener_type == "":
		var raw_listener_type := str(packet.get("listener_type", "")).strip_edges()
		if raw_listener_type != "" and raw_listener_type not in ["install_event_listener", "spawn_event_listener", "discover_event_listener"]:
			installed_listener_type = raw_listener_type
		else:
			warnings.append(label + " install_event_listener should set installed_listener_type, usually activate_event_on_range.")
			installed_listener_type = "activate_event_on_range"

	if not is_supported_listener_type(installed_listener_type):
		warnings.append(label + " installs listener_type not supported by world listener runtime: " + installed_listener_type)

	if float(packet.get("trigger_range", 0.0)) <= 0.0:
		errors.append(label + " install_event_listener trigger_range must be greater than 0.")

	validate_orbit_packet_start_step(label, packet, event_id, current_event_id, current_step, current_steps, warnings)

	if is_activate_listener_type(installed_listener_type) and not bool(packet.get("suppress_trigger_popup", bool(packet.get("silent", false)))):
		warnings.append(label + " installs an activation listener without suppress_trigger_popup. This can cover the first story popup.")


func validate_orbit_activate_packet(label: String, packet: Dictionary, event_id: String, current_event_id: String, current_step: String, current_steps: Dictionary, errors: Array, warnings: Array) -> void:
	validate_orbit_packet_start_step(label, packet, event_id, current_event_id, current_step, current_steps, warnings)
	if not bool(packet.get("silent", false)) and not bool(packet.get("suppress_trigger_popup", false)):
		warnings.append(label + " activates an event from Orbit with visible feedback. Use silent/background for chapter-like handoffs.")


func validate_orbit_packet_start_step(label: String, packet: Dictionary, event_id: String, current_event_id: String, current_step: String, current_steps: Dictionary, warnings: Array) -> void:
	var start_step := str(packet.get("start_step", "")).strip_edges()
	if start_step == "":
		return

	var target_event := get_event_packet_for_validation(event_id, current_event_id)
	var target_steps := current_steps
	if event_id != current_event_id:
		target_steps = target_event.get("steps", {}) if typeof(target_event.get("steps", {})) == TYPE_DICTIONARY else {}

	if target_steps.is_empty():
		warnings.append(label + " start_step cannot be checked because target event steps are not loaded: " + event_id)
		return
	if not target_steps.has(start_step):
		warnings.append(label + " start_step does not exist in target event steps: " + start_step)

	var authored_start := str(target_event.get("current_step", "")).strip_edges()
	if event_id == current_event_id:
		authored_start = current_step
	if authored_start != "" and start_step != authored_start:
		warnings.append(label + " start_step differs from the target event current_step. Direct activation requires the authored start step.")


func get_event_packet_for_validation(event_id: String, current_event_id: String) -> Dictionary:
	if event_id == current_event_id:
		return {}
	return load_event_packet(event_id)


func resolve_orbit_event_listener_event_id(packet: Dictionary) -> String:
	for key in ORBIT_EVENT_ID_KEYS:
		var event_id := str(packet.get(str(key), "")).strip_edges()
		if event_id != "":
			return event_id
	return ""


func infer_orbit_event_listener_action(listener_type: String) -> String:
	var clean_type := listener_type.strip_edges()
	if clean_type in ["install_event_listener", "spawn_event_listener", "discover_event_listener"]:
		return "install_event_listener"
	if clean_type in ["activate_event", "activate_event_on_range", "start_event", "start_event_on_range", "silent_activate_event", "activate_event_silent"]:
		return "activate_event"
	return "discover_event"


func normalize_orbit_event_listener_action(action: String) -> String:
	var clean_action := action.strip_edges()
	match clean_action:
		"seed_event", "add_available_event", "discover_event", "silent_discover_event", "discover_event_silent":
			return "discover_event"
		"activate_event", "activate_event_on_range", "start_event", "start_event_on_range", "silent_activate_event", "activate_event_silent":
			return "activate_event"
		"install_event_listener", "spawn_event_listener", "discover_event_listener":
			return "install_event_listener"
		_:
			return "discover_event"


func is_known_orbit_event_action_alias(action: String) -> bool:
	var clean_action := action.strip_edges()
	return [
		"seed_event",
		"add_available_event",
		"discover_event",
		"silent_discover_event",
		"discover_event_silent",
		"activate_event",
		"activate_event_on_range",
		"start_event",
		"start_event_on_range",
		"silent_activate_event",
		"activate_event_silent",
		"install_event_listener",
		"spawn_event_listener",
		"discover_event_listener"
	].has(clean_action)


func is_supported_listener_type(listener_type: String) -> bool:
	var clean_type := listener_type.strip_edges().to_lower()
	return [
		"seed_event_on_range",
		"seed_event",
		"add_available_event",
		"discover_event",
		"activate_event_on_range",
		"activate_event",
		"start_event_on_range",
		"start_event"
	].has(clean_type)


func is_activate_listener_type(listener_type: String) -> bool:
	var clean_type := listener_type.strip_edges().to_lower()
	return ["activate_event_on_range", "activate_event", "start_event_on_range", "start_event"].has(clean_type)


func is_seed_listener_type(listener_type: String) -> bool:
	var clean_type := listener_type.strip_edges().to_lower()
	return ["seed_event_on_range", "seed_event", "add_available_event", "discover_event"].has(clean_type)


func validate_event_intel_conditions(label: String, source: Dictionary, event_id: String, event_objects: Dictionary, errors: Array, warnings: Array) -> void:
	for key in EVENT_INTEL_CONDITION_KEYS:
		if source.has(str(key)):
			validate_event_intel_condition_collection(label + " " + str(key), source.get(str(key)), event_id, event_objects, errors, warnings)


func validate_event_intel_condition_collection(label: String, raw_conditions, event_id: String, event_objects: Dictionary, errors: Array, warnings: Array) -> void:
	if raw_conditions == null:
		return
	if typeof(raw_conditions) == TYPE_ARRAY:
		for i in range(raw_conditions.size()):
			var condition = raw_conditions[i]
			validate_event_intel_condition(label + "[" + str(i) + "]", condition, event_id, event_objects, errors, warnings)
		return
	if typeof(raw_conditions) == TYPE_DICTIONARY:
		var condition_dict: Dictionary = raw_conditions
		if condition_dict.has("type") or condition_dict.has("condition") or condition_dict.has("condition_type"):
			validate_event_intel_condition(label, condition_dict, event_id, event_objects, errors, warnings)
			return
		for key in condition_dict.keys():
			var value = condition_dict[key]
			var condition := {}
			if typeof(value) == TYPE_DICTIONARY:
				condition = value.duplicate(true)
				if not condition.has("type"):
					condition["type"] = str(key)
			else:
				condition = {
					"type": str(key),
					"value": value
				}
			validate_event_intel_condition(label + "." + str(key), condition, event_id, event_objects, errors, warnings)
		return
	if typeof(raw_conditions) == TYPE_STRING:
		validate_event_intel_condition(label, {"type": str(raw_conditions)}, event_id, event_objects, errors, warnings)
		return
	errors.append(label + " must be a condition object, array, dictionary map, or string.")


func validate_event_intel_condition(label: String, raw_condition, event_id: String, event_objects: Dictionary, errors: Array, warnings: Array) -> void:
	if typeof(raw_condition) == TYPE_STRING:
		raw_condition = {"type": str(raw_condition)}
	if typeof(raw_condition) != TYPE_DICTIONARY:
		errors.append(label + " condition must be a Dictionary or String.")
		return

	var condition: Dictionary = raw_condition
	var condition_type := str(condition.get("type", condition.get("condition_type", condition.get("condition", "")))).strip_edges().to_lower()
	if condition_type == "":
		warnings.append(label + " condition has no type.")
		return
	if not EVENT_INTEL_CONDITION_TYPES.has(condition_type):
		warnings.append(label + " condition type is not handled by the current runtime and will be ignored: " + condition_type)
		return

	match condition_type:
		"intel_discovered":
			if resolve_condition_intel_id(condition) == "":
				warnings.append(label + " intel_discovered needs intel_id, item_id, id, key, or value.")
		"intel_count_at_least", "intel_seen_count":
			if resolve_condition_intel_id(condition) == "":
				warnings.append(label + " " + condition_type + " needs intel_id, item_id, id, key, or value.")
			if resolve_condition_required_count(condition) <= 0:
				errors.append(label + " " + condition_type + " count must be greater than 0.")
		"enemy_serial_defeated":
			var serial := str(condition.get("enemy_serial", condition.get("serial", condition.get("value", "")))).strip_edges()
			if serial == "":
				warnings.append(label + " enemy_serial_defeated needs enemy_serial or serial.")
		"event_enemy_defeated":
			validate_event_enemy_defeated_condition(label, condition, event_id, event_objects, warnings)
		"enemy_display_defeated_count", "enemy_defeated_count":
			validate_enemy_defeated_count_condition(label, condition, errors, warnings)


func resolve_condition_intel_id(condition: Dictionary) -> String:
	for key in ["intel_id", "item_id", "id", "key", "value"]:
		var value := str(condition.get(str(key), "")).strip_edges()
		if value != "":
			return value
	return ""


func resolve_condition_required_count(condition: Dictionary) -> int:
	for key in ["min_count", "required_count", "count", "amount", "at_least", "value"]:
		if condition.has(str(key)):
			return int(condition.get(str(key), 1))
	return 1


func validate_event_enemy_defeated_condition(label: String, condition: Dictionary, event_id: String, event_objects: Dictionary, warnings: Array) -> void:
	var condition_event_id := str(condition.get("event_id", event_id)).strip_edges()
	if condition_event_id == "":
		warnings.append(label + " event_enemy_defeated needs event_id.")
	elif event_id != "" and condition_event_id != event_id:
		warnings.append(label + " event_enemy_defeated event_id differs from this event: " + condition_event_id)

	var enemy_id := ""
	for key in ["enemy_id", "object_id", "target_object_id", "id", "value"]:
		enemy_id = str(condition.get(str(key), "")).strip_edges()
		if enemy_id != "":
			break
	if enemy_id == "":
		warnings.append(label + " event_enemy_defeated needs enemy_id/object_id/target_object_id.")
		return
	if not event_objects.has(enemy_id):
		warnings.append(label + " event_enemy_defeated points to a missing event object: " + enemy_id)
		return
	var enemy = event_objects[enemy_id]
	if typeof(enemy) != TYPE_DICTIONARY:
		return
	var object_type := str(enemy.get("object_type", enemy.get("owner_type", ""))).strip_edges().to_lower()
	if object_type != "enemy":
		warnings.append(label + " event_enemy_defeated target is not marked enemy: " + enemy_id)


func validate_enemy_defeated_count_condition(label: String, condition: Dictionary, errors: Array, warnings: Array) -> void:
	if resolve_condition_required_count(condition) <= 0:
		errors.append(label + " enemy defeated count must be greater than 0.")
	var serial := str(condition.get("enemy_serial", condition.get("serial", ""))).strip_edges()
	if serial != "":
		return
	for key in ["display_name", "enemy_name", "enemy_display_name", "enemy_key", "key", "value"]:
		if str(condition.get(str(key), "")).strip_edges() != "":
			return
	warnings.append(label + " enemy defeated count needs display_name/enemy_name or enemy_serial.")


func validate_reward_packet_current_shape(reward: Dictionary, warnings: Array) -> void:
	var blueprints = reward.get("blueprints", [])
	if typeof(blueprints) == TYPE_ARRAY and not blueprints.is_empty():
		warnings.append("reward_packet.blueprints is populated, but current reward grant only processes reward_packet.items. Use gives_item or reward_packet.items for blueprint item ids.")


func validate_current_range_shape(step_id: String, step: Dictionary, warnings: Array) -> void:
	if is_hunt_or_battle_step(step):
		if step.has("arrival_range") and not step_has_current_gate_range(step):
			warnings.append(step_id + " hunt/battle uses arrival_range without interaction_range or gate_range.")
		elif step.has("arrival_range"):
			warnings.append(step_id + " hunt/battle still has arrival_range; prefer interaction_range or gate_range for battle gating.")
		if not step_has_current_gate_range(step):
			warnings.append(step_id + " hunt/battle has no interaction_range/gate_range and will use the runtime default.")
		return

	if step.has("actions") and typeof(step.get("actions")) == TYPE_ARRAY and not step_has_current_gate_range(step) and not actions_have_range(step.get("actions", [])):
		warnings.append(step_id + " has actions but no interaction_range/gate_range/range.")


func validate_step_chain_shape(current_step: String, steps: Dictionary, errors: Array, warnings: Array) -> void:
	var incoming: Dictionary = {}
	for step_id in steps.keys():
		var step = steps[step_id]
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var step_data: Dictionary = step
		var next_step := get_effective_step_next(step_data)
		if next_step == "" or next_step == "completed":
			continue
		if not incoming.has(next_step):
			incoming[next_step] = []
		incoming[next_step].append(str(step_id))

	for step_id in incoming.keys():
		var sources: Array = incoming[step_id]
		if sources.size() > 1:
			warnings.append(str(step_id) + " has multiple incoming next_step links: " + join_strings(sources, ", "))

	var visited: Dictionary = {}
	var walk_step := current_step
	while walk_step != "" and walk_step != "completed":
		if visited.has(walk_step):
			errors.append("step chain contains a cycle at: " + walk_step)
			break
		if not steps.has(walk_step):
			errors.append("step chain points to missing step: " + walk_step)
			break
		visited[walk_step] = true
		var step: Dictionary = steps[walk_step]
		walk_step = get_effective_step_next(step)

	for step_id in steps.keys():
		var clean_id := str(step_id)
		if not visited.has(clean_id):
			warnings.append(clean_id + " is not reachable from current_step via step, popup, or button advance links.")


func get_effective_step_next(step: Dictionary) -> String:
	var direct_next := str(step.get("next_step", "")).strip_edges()
	if direct_next != "":
		return direct_next

	for key in ["on_enter", "on_arrival", "on_battle_victory"]:
		var operation_next := get_operations_next_step(step.get(key, []))
		if operation_next != "":
			return operation_next

	var actions = step.get("actions", [])
	if typeof(actions) == TYPE_ARRAY:
		for action in actions:
			if typeof(action) != TYPE_DICTIONARY:
				continue
			var action_data: Dictionary = action
			var action_next := get_action_next_step_value(action_data)
			if action_next != "":
				return action_next
	return ""


func get_operations_next_step(operations) -> String:
	if typeof(operations) != TYPE_ARRAY:
		return ""
	for operation in operations:
		if typeof(operation) != TYPE_DICTIONARY:
			continue
		var op: Dictionary = operation
		var op_id := str(op.get("op", op.get("action_id", op.get("type", "")))).strip_edges().to_lower()
		if op_id == "advance_step":
			var next_step := str(op.get("next_step", "")).strip_edges()
			if next_step != "":
				return next_step
		elif op_id == "show_story_popup" or op_id == "story_popup":
			var popup_next := str(op.get("next_step_on_close", op.get("advance_step_on_close", ""))).strip_edges()
			if popup_next != "":
				return popup_next
		elif op_id == "show_tutorial_hint" or op_id == "tutorial_hint" or op_id == "show_helper_message":
			var tutorial_next := str(op.get("next_step_after_hint", op.get("next_step_on_close", op.get("advance_step_on_close", "")))).strip_edges()
			if tutorial_next != "":
				return tutorial_next
	return ""


func get_action_next_step_value(action: Dictionary) -> String:
	var direct := str(action.get("next_step", "")).strip_edges()
	if direct != "":
		return direct
	var operations: Array = []
	if typeof(action.get("operations", [])) == TYPE_ARRAY:
		operations = action.get("operations", [])
	elif typeof(action.get("operation", {})) == TYPE_DICTIONARY:
		operations = [action.get("operation", {})]
	elif typeof(action.get("popup", {})) == TYPE_DICTIONARY:
		operations = [action.get("popup", {})]
	elif typeof(action.get("tutorial", {})) == TYPE_DICTIONARY:
		operations = [action.get("tutorial", {})]
	return get_operations_next_step(operations)


func action_has_event_operations(action: Dictionary) -> bool:
	if action.has("operations") and typeof(action.get("operations")) == TYPE_ARRAY and not action.get("operations", []).is_empty():
		return true
	if action.has("operation") and typeof(action.get("operation")) == TYPE_DICTIONARY and not action.get("operation", {}).is_empty():
		return true
	if action.has("popup") and typeof(action.get("popup")) == TYPE_DICTIONARY and not action.get("popup", {}).is_empty():
		return true
	if action.has("tutorial") and typeof(action.get("tutorial")) == TYPE_DICTIONARY and not action.get("tutorial", {}).is_empty():
		return true
	return false


func validate_current_battle_shape(step_id: String, step: Dictionary, event_objects: Dictionary, warnings: Array) -> void:
	if not is_hunt_or_battle_step(step):
		return

	var enemy_id := str(step.get("enemy_id", "")).strip_edges()
	if enemy_id == "":
		warnings.append(step_id + " hunt/battle step has no enemy_id.")
	elif event_objects.has(enemy_id):
		var enemy = event_objects[enemy_id]
		if typeof(enemy) == TYPE_DICTIONARY:
			var enemy_type := str(enemy.get("object_type", enemy.get("owner_type", ""))).strip_edges().to_lower()
			if enemy_type != "enemy":
				warnings.append(step_id + " enemy_id points to an event object that is not marked enemy: " + enemy_id)

	if not step_has_operation(step, ["start_battle", "start_hunt_battle"]):
		warnings.append(step_id + " hunt/battle step has no start_battle operation.")

	validate_empty_battle_advance_step(step_id, step, warnings)


func validate_empty_battle_advance_step(step_id: String, step: Dictionary, warnings: Array) -> void:
	var operations = step.get("on_battle_victory", [])
	if typeof(operations) != TYPE_ARRAY:
		return
	for operation in operations:
		if typeof(operation) != TYPE_DICTIONARY:
			continue
		var op_id := str(operation.get("op", operation.get("action_id", operation.get("type", "")))).strip_edges().to_lower()
		if op_id == "advance_step" and str(operation.get("next_step", "")).strip_edges() == "":
			warnings.append(step_id + " on_battle_victory advance_step has empty next_step.")


func step_has_current_gate_range(step: Dictionary) -> bool:
	for key in ["gate_range", "activation_range", "interaction_range", "target_range", "range", "radius", "pos_radius", "position_radius"]:
		if step.has(key):
			return true
	return false


func actions_have_range(actions: Array) -> bool:
	for action in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		for key in ["gate_range", "activation_range", "interaction_range", "target_range", "range", "radius", "pos_radius", "position_radius"]:
			if action.has(key):
				return true
	return false


func is_hunt_or_battle_step(step: Dictionary) -> bool:
	var interaction_type := str(step.get("interaction_type", step.get("event_type", step.get("step_kind", "")))).strip_edges().to_lower()
	if ["hunt", "battle"].has(interaction_type):
		return true
	if str(step.get("enemy_id", "")).strip_edges() != "":
		return true
	if bool(step.get("complete_on_battle_victory", false)):
		return true
	return step_has_operation(step, ["start_battle", "start_hunt_battle"])


func step_has_operation(step: Dictionary, op_ids: Array) -> bool:
	for key in ["on_enter", "on_arrival", "on_battle_victory"]:
		var operations = step.get(key, [])
		if operations_have_operation(operations, op_ids):
			return true
	var actions = step.get("actions", [])
	if typeof(actions) == TYPE_ARRAY:
		for action in actions:
			if typeof(action) != TYPE_DICTIONARY:
				continue
			if operations_have_operation(action.get("operations", []), op_ids):
				return true
			if operations_have_operation([action.get("operation", {})], op_ids):
				return true
	return false


func operations_have_operation(operations, op_ids: Array) -> bool:
	if typeof(operations) != TYPE_ARRAY:
		return false
	for operation in operations:
		if typeof(operation) != TYPE_DICTIONARY:
			continue
		var op_id := str(operation.get("op", operation.get("action_id", operation.get("type", "")))).strip_edges().to_lower()
		if op_ids.has(op_id):
			return true
	return false


func step_opens_story_popup(step) -> bool:
	if typeof(step) != TYPE_DICTIONARY:
		return false
	var interaction_type := str(step.get("interaction_type", "")).strip_edges().to_lower()
	if interaction_type == "story_popup":
		return true
	return step_has_operation(step, ["show_story_popup", "story_popup"])



func is_npc_dialogue_operation(op_id: String) -> bool:
	return [
		"update_npc_dialogue",
		"set_npc_dialogue",
		"set_npc_talk_lines",
		"update_npc_contact",
		"set_npc_contact",
		"set_npc_actions"
	].has(op_id.strip_edges().to_lower())


func is_npc_lifecycle_operation(op_id: String) -> bool:
	return [
		"remove_npc",
		"despawn_npc",
		"delete_npc",
		"spawn_npc",
		"install_npc",
		"refresh_npc",
		"refresh_npc_context",
		"replace_npc",
		"swap_npc",
		"reload_npc"
	].has(op_id.strip_edges().to_lower())


func is_supported_event_operation(op_id: String) -> bool:
	var clean := op_id.strip_edges().to_lower()
	if clean == "":
		return true
	if is_npc_dialogue_operation(clean) or is_npc_lifecycle_operation(clean):
		return true
	return [
		"write_log",
		"log",
		"show_story_popup",
		"story_popup",
		"show_tutorial_hint",
		"tutorial_hint",
		"show_helper_message",
		"advance_step",
		"start_battle",
		"start_hunt_battle",
		"install_event_object",
		"spawn_event_object",
		"set_flag"
	].has(clean)


func validate_npc_lifecycle_operation(label: String, operation: Dictionary, event_objects: Dictionary, errors: Array, warnings: Array) -> void:
	var op_id := str(operation.get("op", operation.get("action_id", operation.get("type", "")))).strip_edges().to_lower()
	var target_id := first_non_empty_string(operation, ["target_object_id", "target_owner_id", "remove_object_id", "remove_npc_id", "old_object_id", "old_npc_id", "npc_id", "owner_id", "object_id"])
	var replacement_id := first_non_empty_string(operation, ["replacement_object_id", "replacement_npc_id", "new_object_id", "new_npc_id", "spawn_object_id", "spawn_npc_id"])
	var inline_data = operation.get("npc_data", operation.get("object_data", operation.get("replacement_data", {})))
	var has_inline_data = typeof(inline_data) == TYPE_DICTIONARY and not inline_data.is_empty()

	if ["remove_npc", "despawn_npc", "delete_npc"].has(op_id):
		if target_id == "":
			errors.append(label + " is missing target_object_id/npc_id.")
		elif not event_objects.has(target_id):
			warnings.append(label + " target is not an event_object; this is okay for giver NPCs but check id: " + target_id)
		return

	if replacement_id == "":
		replacement_id = target_id
	var inline_dict: Dictionary = {}
	if has_inline_data:
		inline_dict = inline_data
	if replacement_id == "" and has_inline_data:
		replacement_id = first_non_empty_string(inline_dict, ["object_id", "npc_id", "owner_id", "blueprint_id"])
	if replacement_id == "":
		errors.append(label + " is missing replacement_object_id/object_id/npc_data.object_id.")
	elif event_objects.has(replacement_id):
		var replacement = event_objects[replacement_id]
		if typeof(replacement) == TYPE_DICTIONARY:
			var replacement_type := str(replacement.get("object_type", replacement.get("owner_type", ""))).strip_edges().to_lower()
			if replacement_type != "npc":
				errors.append(label + " replacement object is not an NPC: " + replacement_id)
	elif not has_inline_data:
		warnings.append(label + " replacement is not an event_object and has no inline npc_data: " + replacement_id)

	validate_npc_talk_meta(label, operation, errors)
	if has_inline_data:
		validate_dialogue_lines(label + " npc_data dialogue_lines", inline_dict.get("dialogue_lines", inline_dict.get("npc_dialogue_lines", [])), errors)
		validate_npc_talk_meta(label + " npc_data", inline_dict, errors)


func validate_npc_talk_meta(label: String, packet: Dictionary, errors: Array) -> void:
	for nested_key in ["talk_meta", "npc_meta", "contact_meta", "trade_meta"]:
		var nested = packet.get(nested_key, {})
		if typeof(nested) == TYPE_DICTIONARY:
			validate_dialogue_lines(label + " " + nested_key + " dialogue_lines", nested.get("npc_dialogue_lines", nested.get("dialogue_lines", nested.get("lines", []))), errors)
			validate_npc_action_update_fields(label + " " + nested_key, nested, errors)


func first_non_empty_string(source: Dictionary, keys: Array) -> String:
	for key in keys:
		var value := str(source.get(str(key), "")).strip_edges()
		if value != "":
			return value
	return ""


func join_strings(values: Array, separator: String) -> String:
	var out := ""
	for i in range(values.size()):
		if i > 0:
			out += separator
		out += str(values[i])
	return out


func validate_step_operations(step_id: String, step: Dictionary, event_objects: Dictionary, steps: Dictionary, errors: Array, warnings: Array) -> void:
	var enemy_id := str(step.get("enemy_id", "")).strip_edges()
	var on_enter = step.get("on_enter", [])
	if typeof(on_enter) == TYPE_ARRAY:
		for operation in on_enter:
			if typeof(operation) != TYPE_DICTIONARY:
				continue
			var op_id := str(operation.get("op", operation.get("action_id", operation.get("type", "")))).strip_edges().to_lower()
			if op_id == "start_battle":
				var op_enemy_id := str(operation.get("enemy_id", "")).strip_edges()
				if op_enemy_id == "":
					errors.append(step_id + " start_battle is missing enemy_id.")
				elif not event_objects.has(op_enemy_id):
					errors.append(step_id + " start_battle enemy is missing: " + op_enemy_id)
				elif enemy_id != "" and op_enemy_id != enemy_id:
					errors.append(step_id + " start_battle enemy_id does not match step enemy_id.")
			elif is_npc_dialogue_operation(op_id):
				validate_dialogue_lines(step_id + " update_npc_dialogue lines", operation.get("npc_dialogue_lines", operation.get("dialogue_lines", operation.get("lines", []))), errors)
				validate_npc_action_update_fields(step_id + " " + op_id, operation, errors)
				validate_npc_talk_meta(step_id + " " + op_id, operation, errors)
				var target_owner_id := str(operation.get("target_owner_id", operation.get("npc_id", operation.get("target_object_id", "")))).strip_edges()
				if target_owner_id != "" and not event_objects.has(target_owner_id):
					warnings.append(step_id + " update_npc_dialogue target is not an event object. It should be the giver id or an NPC object id: " + target_owner_id)
			elif is_npc_lifecycle_operation(op_id):
				validate_npc_lifecycle_operation(step_id + " " + op_id, operation, event_objects, errors, warnings)
			elif op_id == "show_story_popup" or op_id == "story_popup":
				validate_story_popup_operation(step_id, operation, steps, errors, warnings)
			elif op_id != "" and not is_supported_event_operation(op_id):
				warnings.append(step_id + " uses an operation the runtime may not handle: " + op_id)

	var on_battle_victory = step.get("on_battle_victory", [])
	if enemy_id != "" and typeof(on_battle_victory) == TYPE_ARRAY and on_battle_victory.is_empty():
		warnings.append(step_id + " has an enemy but no on_battle_victory operations.")

	var on_arrival = step.get("on_arrival", [])
	if typeof(on_arrival) == TYPE_ARRAY:
		validate_story_popup_operations_in_array(step_id + " on_arrival", on_arrival, steps, errors, warnings, event_objects)
	if typeof(on_battle_victory) == TYPE_ARRAY:
		validate_story_popup_operations_in_array(step_id + " on_battle_victory", on_battle_victory, steps, errors, warnings, event_objects)

	var actions = step.get("actions", [])
	if typeof(actions) == TYPE_ARRAY:
		for action in actions:
			if typeof(action) != TYPE_DICTIONARY:
				continue
			var action_id := str(action.get("action_id", "")).strip_edges()
			if action_id != "" and not EVENT_WIDGET_ACTION_IDS.has(action_id):
				if action_has_event_operations(action):
					warnings.append(step_id + " uses custom action_id with button operations: " + action_id)
				else:
					warnings.append(step_id + " uses an action_id the current runtime will not handle: " + action_id)
			if str(step.get("gives_item", "")).strip_edges() != "" and action_id == "claim_event_reward":
				errors.append(step_id + " has gives_item, but claim_event_reward ignores gives_item. Use download_beacon_data or move the item into reward_packet.items.")
			if action_id == "show_story_popup" or action_id == "story_popup":
				validate_story_popup_operation(step_id + " action", action, steps, errors, warnings)
			if action.has("popup") and typeof(action.get("popup")) == TYPE_DICTIONARY:
				validate_story_popup_operation(step_id + " action popup", action.get("popup", {}), steps, errors, warnings)
			if action.has("operation") and typeof(action.get("operation")) == TYPE_DICTIONARY:
				validate_story_popup_operations_in_array(step_id + " action operation", [action.get("operation", {})], steps, errors, warnings, event_objects)
			if action.has("operations") and typeof(action.get("operations")) == TYPE_ARRAY:
				validate_story_popup_operations_in_array(step_id + " action operations", action.get("operations", []), steps, errors, warnings, event_objects)


func validate_story_popup_operations_in_array(label: String, operations: Array, steps: Dictionary, errors: Array, warnings: Array, event_objects: Dictionary = {}) -> void:
	for operation in operations:
		if typeof(operation) != TYPE_DICTIONARY:
			continue
		var op_id := str(operation.get("op", operation.get("action_id", operation.get("type", "")))).strip_edges().to_lower()
		if op_id == "show_story_popup" or op_id == "story_popup":
			validate_story_popup_operation(label, operation, steps, errors, warnings)
		elif is_npc_dialogue_operation(op_id):
			validate_dialogue_lines(label + " update_npc_dialogue lines", operation.get("npc_dialogue_lines", operation.get("dialogue_lines", operation.get("lines", []))), errors)
			validate_npc_action_update_fields(label + " " + op_id, operation, errors)
			validate_npc_talk_meta(label + " " + op_id, operation, errors)
		elif is_npc_lifecycle_operation(op_id):
			validate_npc_lifecycle_operation(label + " " + op_id, operation, event_objects, errors, warnings)
		elif op_id != "" and not is_supported_event_operation(op_id):
			warnings.append(label + " uses an operation the runtime may not handle: " + op_id)


func validate_story_popup_operation(label: String, operation: Dictionary, steps: Dictionary, errors: Array, warnings: Array) -> void:
	var popup_packet := operation
	if operation.has("popup") and typeof(operation.get("popup")) == TYPE_DICTIONARY:
		popup_packet = operation.get("popup", {}).duplicate(true)
		for key in [
			"close_mode",
			"dismiss_mode",
			"completion_mode",
			"duration",
			"countdown",
			"auto_close_seconds",
			"auto_close",
			"next_step_on_close",
			"advance_step_on_close",
			"advance_on_close",
			"on_close_operations",
			"after_close_operations",
			"close_operations",
			"on_close"
		]:
			if operation.has(key) and not popup_packet.has(key):
				popup_packet[key] = operation[key]

	var raw_images = popup_packet.get("images", popup_packet.get("image_paths", popup_packet.get("image", "")))
	validate_story_popup_images(label, raw_images, errors, warnings)

	var has_text := str(popup_packet.get("text", popup_packet.get("bbcode", popup_packet.get("message", "")))).strip_edges() != ""
	var has_images := has_story_popup_images(raw_images)
	if not has_text and not has_images:
		warnings.append(label + " story popup has no text or image paths.")

	var close_mode := normalize_story_popup_close_mode_value(str(popup_packet.get("close_mode", popup_packet.get("dismiss_mode", popup_packet.get("completion_mode", "button")))))
	if close_mode == "timer" or close_mode == "both":
		var duration := float(popup_packet.get("duration", popup_packet.get("countdown", popup_packet.get("auto_close_seconds", popup_packet.get("auto_close", 4.0)))))
		if duration <= 0.0:
			errors.append(label + " story popup countdown must be greater than 0.")

	validate_story_popup_close_step(label, popup_packet, steps, errors)
	validate_story_popup_close_operations(label, popup_packet, steps, errors, warnings)


func validate_story_popup_images(label: String, raw_images, errors: Array, warnings: Array) -> void:
	if raw_images == null:
		return
	if typeof(raw_images) == TYPE_STRING:
		validate_story_popup_image_path(label, str(raw_images), warnings)
		return
	if typeof(raw_images) != TYPE_ARRAY:
		errors.append(label + " story popup images must be a String path or an Array.")
		return
	if raw_images.size() > 2:
		warnings.append(label + " story popup uses more than two images; only the first two will show.")
	for item in raw_images:
		if typeof(item) == TYPE_STRING:
			validate_story_popup_image_path(label, str(item), warnings)
		elif typeof(item) == TYPE_DICTIONARY:
			var path := str(item.get("path", item.get("image", ""))).strip_edges()
			if path == "":
				errors.append(label + " story popup image entry is missing path.")
			else:
				validate_story_popup_image_path(label, path, warnings)
		else:
			errors.append(label + " story popup image entries must be Strings or Dictionaries.")


func validate_story_popup_image_path(label: String, raw_path: String, warnings: Array) -> void:
	var path := raw_path.strip_edges()
	if path == "":
		return
	if not path.begins_with("res://"):
		warnings.append(label + " story popup image should use a res:// path: " + path)
		return
	if not ResourceLoader.exists(path):
		warnings.append(label + " story popup image path was not found: " + path)


func has_story_popup_images(raw_images) -> bool:
	if typeof(raw_images) == TYPE_STRING:
		return str(raw_images).strip_edges() != ""
	if typeof(raw_images) != TYPE_ARRAY:
		return false
	for item in raw_images:
		if typeof(item) == TYPE_STRING and str(item).strip_edges() != "":
			return true
		if typeof(item) == TYPE_DICTIONARY and str(item.get("path", item.get("image", ""))).strip_edges() != "":
			return true
	return false


func normalize_story_popup_close_mode_value(raw_mode: String) -> String:
	var clean := raw_mode.strip_edges().to_lower()
	if clean == "timer" or clean == "countdown" or clean == "auto" or clean == "automatic":
		return "timer"
	if clean == "both" or clean == "button_and_timer" or clean == "button_timer" or clean == "timer_or_button":
		return "both"
	return "button"


func validate_story_popup_close_step(label: String, popup_packet: Dictionary, steps: Dictionary, errors: Array) -> void:
	var next_step := str(popup_packet.get("next_step_on_close", popup_packet.get("advance_step_on_close", ""))).strip_edges()
	if next_step != "" and next_step != "completed" and not steps.has(next_step):
		errors.append(label + " story popup next_step_on_close is missing: " + next_step)


func validate_story_popup_close_operations(label: String, popup_packet: Dictionary, steps: Dictionary, errors: Array, warnings: Array) -> void:
	var close_operations := collect_story_popup_close_operations(popup_packet)
	for operation in close_operations:
		if typeof(operation) != TYPE_DICTIONARY:
			continue
		var op_id := str(operation.get("op", operation.get("action_id", operation.get("type", "")))).strip_edges()
		if op_id == "advance_step":
			var next_step := str(operation.get("next_step", "")).strip_edges()
			if next_step == "":
				errors.append(label + " story popup close advance_step is missing next_step.")
			elif next_step != "completed" and not steps.has(next_step):
				errors.append(label + " story popup close advance_step is missing: " + next_step)
		elif op_id == "show_story_popup" or op_id == "story_popup":
			warnings.append(label + " story popup close operation opens another popup; prefer making that popup its own step.")


func collect_story_popup_close_operations(popup_packet: Dictionary) -> Array:
	var operations: Array = []
	for key in ["on_close_operations", "after_close_operations", "close_operations"]:
		var value = popup_packet.get(key, [])
		if typeof(value) == TYPE_ARRAY:
			for op in value:
				if typeof(op) == TYPE_DICTIONARY:
					operations.append(op)
		elif typeof(value) == TYPE_DICTIONARY:
			operations.append(value)
	var on_close = popup_packet.get("on_close", {})
	if typeof(on_close) == TYPE_DICTIONARY:
		if on_close.has("operations") and typeof(on_close.get("operations")) == TYPE_ARRAY:
			for op in on_close.get("operations", []):
				if typeof(op) == TYPE_DICTIONARY:
					operations.append(op)
		elif on_close.has("operation") and typeof(on_close.get("operation")) == TYPE_DICTIONARY:
			operations.append(on_close.get("operation", {}))
		elif on_close.has("op") or on_close.has("action_id") or on_close.has("type"):
			operations.append(on_close)
	return operations


func validate_step_dialogue_fields(step_id: String, step: Dictionary, giver: Dictionary, event_objects: Dictionary, errors: Array, warnings: Array) -> void:
	validate_dialogue_lines(step_id + " npc_dialogue_lines", step.get("npc_dialogue_lines", []), errors)
	validate_dialogue_lines(step_id + " completed_npc_dialogue_lines", step.get("completed_npc_dialogue_lines", []), errors)
	for key in ["npc_chat_line_delay", "chat_line_delay", "completed_chat_line_delay", "completed_npc_chat_line_delay", "npc_chat_character_delay", "chat_character_delay", "chat_type_delay", "completed_chat_character_delay", "completed_npc_chat_character_delay"]:
		if step.has(key) and float(step.get(key, 0.0)) <= 0.0:
			errors.append(step_id + " " + key + " must be greater than 0.")
	validate_npc_action_update_fields(step_id, step, errors)

	var dialogue_target := str(step.get("npc_dialogue_target_owner_id", "")).strip_edges()
	if dialogue_target == "":
		return
	if target_owner_matches_giver(dialogue_target, giver):
		return
	if event_objects.has(dialogue_target):
		var target_object = event_objects[dialogue_target]
		if typeof(target_object) == TYPE_DICTIONARY and str(target_object.get("object_type", target_object.get("owner_type", ""))).strip_edges().to_lower() == "npc":
			return
	warnings.append(step_id + " npc_dialogue_target_owner_id should be the giver id or an NPC event object id: " + dialogue_target)


func validate_dialogue_lines(label: String, value, errors: Array) -> void:
	if value == null:
		return
	if typeof(value) == TYPE_STRING:
		return
	if typeof(value) != TYPE_ARRAY:
		errors.append(label + " must be an Array or newline-separated String.")
		return
	for line in value:
		if typeof(line) != TYPE_STRING:
			errors.append(label + " entries must be Strings.")
			return


func validate_npc_action_update_fields(label: String, packet: Dictionary, errors: Array) -> void:
	for key in ["item_list"]:
		if packet.has(key):
			validate_trade_items(label + " " + key, packet.get(key, []), errors)
	for key in ["npc_chat_character_delay", "chat_character_delay", "chat_type_delay", "completed_chat_character_delay", "completed_npc_chat_character_delay"]:
		if packet.has(key) and float(packet.get(key, 0.0)) <= 0.0:
			errors.append(label + " " + key + " must be greater than 0.")


func validate_trade_items(label: String, value, errors: Array) -> void:
	if value == null:
		return
	if typeof(value) != TYPE_ARRAY:
		errors.append(label + " must be an Array.")
		return
	for item in value:
		if typeof(item) != TYPE_DICTIONARY:
			errors.append(label + " entries must be Dictionaries.")
			return
		var item_id := str(item.get("item_id", "")).strip_edges()
		if item_id == "":
			errors.append(label + " entries require item_id.")
			return
		var amount := int(item.get("amount", item.get("count", 1)))
		if amount <= 0:
			errors.append(label + " item amount must be greater than 0.")
			return


func validate_event_object_positions(event_objects: Dictionary, warnings: Array) -> void:
	for object_id in event_objects.keys():
		var object_data = event_objects[object_id]
		if typeof(object_data) != TYPE_DICTIONARY:
			continue

		var uses_anchor := event_object_uses_anchor_position(object_data)
		var local := read_validation_vector3(object_data.get("local_pos", object_data.get("local", Vector3.ZERO)))
		var sector := read_validation_vector3(object_data.get("sector_pos", object_data.get("sector", Vector3.ZERO)))

		if uses_anchor:
			var has_offset = object_data.has("local_offset") or object_data.has("anchor_local_offset")
			if not has_offset and is_validation_zero_vector3(local):
				warnings.append(str(object_id) + " is anchor-relative but has no local_offset. It will sit directly on the anchor star.")
			continue

		if is_validation_zero_vector3(local):
			warnings.append(str(object_id) + " local_pos is [0,0,0]. That is a sector corner; use [500,500,500] or anchor-relative local_offset.")
		if is_validation_zero_vector3(sector) and is_validation_zero_vector3(local):
			warnings.append(str(object_id) + " target position is full zero. Autopilot will fly to the universe/sector origin unless this is intentional.")


func event_object_uses_anchor_position(object_data: Dictionary) -> bool:
	var mode := str(object_data.get("position_mode", "")).strip_edges().to_lower()
	return bool(object_data.get("place_near_anchor_star", false)) or mode == "anchor_offset" or mode == "anchor_relative" or object_data.has("anchor_local_offset") or object_data.has("sector_offset")


func read_validation_vector3(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector3i:
		return Vector3(value.x, value.y, value.z)
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func is_validation_zero_vector3(value: Vector3) -> bool:
	return is_zero_approx(value.x) and is_zero_approx(value.y) and is_zero_approx(value.z)


func target_owner_matches_giver(target_owner_id: String, giver: Dictionary) -> bool:
	for key in ["owner_id", "object_id", "blueprint_id", "template_owner_id"]:
		if target_owner_id == str(giver.get(key, "")).strip_edges():
			return true
	return false


func make_result(status: String, reason: String, file_path: String) -> Dictionary:
	return {
		"status": status,
		"reason": reason,
		"file_path": file_path,
		"labels": ["event_story_storage"]
	}
