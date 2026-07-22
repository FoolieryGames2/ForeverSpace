extends Node
class_name EventStoryCatalog

const ItemDbBuilder = preload("res://Control/Control/items/item_db_builder.gd")
const NPCHandlerScript = preload("res://Objects/npc_handler.gd")
const EnemyHandlerScript = preload("res://Objects/enemy_handler.gd")

const DEFAULT_WORLD_SEED_DIR := "res://data/world_seeds"
const WORLD_SEED_EXTENSION := ".json"
const DEFAULT_EVENT_DIR := "res://data/events"
const EVENT_EXTENSION := ".json"

var item_db: Dictionary = {}
var npc_blueprints: Dictionary = {}
var enemy_blueprints: Dictionary = {}
var event_packets: Dictionary = {}
var world_seed_objects: Dictionary = {}
var world_seed_anchors: Dictionary = {}


func refresh() -> void:
	item_db = ItemDbBuilder.build()

	var npc_handler = NPCHandlerScript.new()
	npc_blueprints = npc_handler.get_npc_blueprints()

	var enemy_handler = EnemyHandlerScript.new()
	enemy_blueprints = enemy_handler.get_enemy_blueprints()

	load_world_seed_objects()
	load_event_packets()


func get_counts() -> Dictionary:
	return {
		"items": item_db.size(),
		"npcs": npc_blueprints.size(),
		"enemies": enemy_blueprints.size(),
		"events": event_packets.size(),
		"world_objects": world_seed_objects.size(),
		"world_anchors": world_seed_anchors.size()
	}


func get_item_options(type_filter: Array = []) -> Array:
	var options := [{"id": "", "label": ""}]
	var ids := item_db.keys()
	ids.sort()
	for item_id in ids:
		var item_data: Dictionary = item_db[item_id]
		if not matches_type_filter(item_data, type_filter):
			continue
		options.append({
			"id": str(item_id),
			"label": build_label(str(item_id), item_data, ["display_name", "name", "title"], ["type", "category", "item_type"])
		})
	return options


func get_npc_options() -> Array:
	var options := [{"id": "", "label": ""}]
	var ids := npc_blueprints.keys()
	ids.sort()
	for npc_id in ids:
		var npc_data: Dictionary = npc_blueprints[npc_id]
		options.append({
			"id": str(npc_id),
			"label": build_label(str(npc_id), npc_data, ["display_name", "name"], ["species", "role"])
		})
	return options


func get_enemy_options() -> Array:
	var options := [{"id": "", "label": ""}]
	var ids := enemy_blueprints.keys()
	ids.sort()
	for enemy_id in ids:
		var enemy_data: Dictionary = enemy_blueprints[enemy_id]
		options.append({
			"id": str(enemy_id),
			"label": build_label(str(enemy_id), enemy_data, ["display_name", "ship_name", "name"], ["type", "behavior_profile"])
		})
	return options


func get_world_object_options(type_filter: Array = []) -> Array:
	var options := [{"id": "", "label": ""}]
	var ids := world_seed_objects.keys()
	ids.sort()
	for object_id in ids:
		var object_data: Dictionary = world_seed_objects[object_id]
		if not matches_type_filter(object_data, type_filter):
			continue
		options.append({
			"id": str(object_id),
			"label": build_world_object_label(str(object_id), object_data)
		})
	return options


func get_world_anchor_options() -> Array:
	var options := [{"id": "", "label": ""}]
	var ids := world_seed_anchors.keys()
	ids.sort()
	for object_id in ids:
		var object_data: Dictionary = world_seed_anchors[object_id]
		options.append({
			"id": str(object_id),
			"label": build_world_object_label(str(object_id), object_data)
		})
	return options


func get_event_options() -> Array:
	var options := [{"id": "", "label": ""}]
	var ids := event_packets.keys()
	ids.sort()
	for event_id in ids:
		var event_data: Dictionary = event_packets[event_id]
		options.append({
			"id": str(event_id),
			"label": build_label(str(event_id), event_data, ["display_name", "title", "name"], ["event_state", "current_step"])
		})
	return options


func get_item(item_id: String) -> Dictionary:
	return get_catalog_entry(item_db, item_id)


func get_npc_blueprint(blueprint_id: String) -> Dictionary:
	return get_catalog_entry(npc_blueprints, blueprint_id)


func get_enemy_blueprint(blueprint_id: String) -> Dictionary:
	return get_catalog_entry(enemy_blueprints, blueprint_id)


func get_world_seed_object(object_id: String) -> Dictionary:
	return get_catalog_entry(world_seed_objects, object_id)


func get_world_seed_anchor(object_id: String) -> Dictionary:
	return get_catalog_entry(world_seed_anchors, object_id)


func get_event_packet(event_id: String) -> Dictionary:
	return get_catalog_entry(event_packets, event_id)


func get_catalog_entry(source: Dictionary, entry_id: String) -> Dictionary:
	var clean_id := entry_id.strip_edges()
	if clean_id == "" or not source.has(clean_id):
		return {}
	var entry = source[clean_id]
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	return entry.duplicate(true)


func load_world_seed_objects() -> void:
	world_seed_objects.clear()
	world_seed_anchors.clear()

	var world_seed_dir := get_world_seed_dir()
	var dir := DirAccess.open(world_seed_dir)
	if dir == null:
		push_warning("EventStoryCatalog could not open world seed dir: " + world_seed_dir)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(WORLD_SEED_EXTENSION):
			load_world_seed_file(world_seed_dir.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()


func get_world_seed_dir() -> String:
	var lane_dir := str(Globals.active_universe_world_seeds_dir).strip_edges()
	if lane_dir != "":
		return lane_dir
	return DEFAULT_WORLD_SEED_DIR


func get_event_dir() -> String:
	var lane_dir := str(Globals.active_universe_events_dir).strip_edges()
	if lane_dir != "":
		return lane_dir
	return DEFAULT_EVENT_DIR


func load_world_seed_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("EventStoryCatalog could not read world seed: " + file_path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("EventStoryCatalog skipped malformed world seed: " + file_path)
		return

	var seed_data: Dictionary = parsed
	var seed_id := str(seed_data.get("seed_id", file_path.get_file().get_basename())).strip_edges()
	var objects = seed_data.get("objects", {})
	if typeof(objects) != TYPE_DICTIONARY:
		return

	for object_id in objects.keys():
		var raw_object = objects[object_id]
		if typeof(raw_object) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = raw_object.duplicate(true)
		var clean_id := str(object_data.get("object_id", object_id)).strip_edges()
		if clean_id == "":
			continue
		object_data["object_id"] = clean_id
		object_data["source_seed_id"] = seed_id
		object_data["source_path"] = file_path
		object_data["catalog_source"] = "world_seed"
		object_data["catalog_id"] = clean_id
		world_seed_objects[clean_id] = object_data
		if is_world_anchor_object(object_data):
			world_seed_anchors[clean_id] = object_data


func load_event_packets() -> void:
	event_packets.clear()

	var event_dir := get_event_dir()
	var dir := DirAccess.open(event_dir)
	if dir == null:
		push_warning("EventStoryCatalog could not open event dir: " + event_dir)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(EVENT_EXTENSION):
			load_event_file(event_dir.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()


func load_event_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("EventStoryCatalog could not read event file: " + file_path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("EventStoryCatalog skipped malformed event file: " + file_path)
		return

	var event_data: Dictionary = parsed
	var event_id := str(event_data.get("event_id", file_path.get_file().get_basename())).strip_edges()
	if event_id == "":
		return
	event_data = event_data.duplicate(true)
	event_data["event_id"] = event_id
	event_data["source_path"] = file_path
	event_data["catalog_source"] = "event_packet"
	event_data["catalog_id"] = event_id
	event_packets[event_id] = event_data


func is_world_anchor_object(object_data: Dictionary) -> bool:
	var owner_type := str(object_data.get("owner_type", object_data.get("object_type", ""))).strip_edges().to_lower()
	if owner_type == "star":
		return true
	var labels = object_data.get("labels", [])
	if typeof(labels) == TYPE_ARRAY:
		for label in labels:
			var clean_label := str(label).strip_edges().to_lower()
			if clean_label == "story_anchor" or clean_label == "tier_spine":
				return true
	return false


func matches_type_filter(data: Dictionary, type_filter: Array) -> bool:
	if type_filter.is_empty():
		return true
	var candidates := [
		str(data.get("owner_type", "")).strip_edges().to_lower(),
		str(data.get("object_type", "")).strip_edges().to_lower(),
		str(data.get("type", "")).strip_edges().to_lower(),
		str(data.get("category", "")).strip_edges().to_lower(),
		str(data.get("item_type", "")).strip_edges().to_lower()
	]
	var labels = data.get("labels", [])
	if typeof(labels) == TYPE_ARRAY:
		for label in labels:
			candidates.append(str(label).strip_edges().to_lower())
	for filter_value in type_filter:
		if candidates.has(str(filter_value).strip_edges().to_lower()):
			return true
	return false


func build_label(entry_id: String, data: Dictionary, name_keys: Array, detail_keys: Array) -> String:
	var name := ""
	for key in name_keys:
		name = str(data.get(str(key), "")).strip_edges()
		if name != "":
			break
	if name == "":
		name = entry_id

	var details: Array = []
	for key in detail_keys:
		var detail := str(data.get(str(key), "")).strip_edges()
		if detail != "" and not details.has(detail):
			details.append(detail)

	var label := name
	if entry_id != "" and entry_id != name:
		label += " / " + entry_id
	if not details.is_empty():
		label += " [" + join_strings(details, ", ") + "]"
	return label


func build_world_object_label(object_id: String, data: Dictionary) -> String:
	var label := build_label(object_id, data, ["display_name", "star_name", "scan_name", "title", "name"], ["owner_type", "object_type", "resource_type"])
	var seed_id := str(data.get("source_seed_id", "")).strip_edges()
	if seed_id != "":
		label += " {" + seed_id + "}"
	return label


func join_strings(values: Array, separator: String) -> String:
	var out := ""
	for i in range(values.size()):
		if i > 0:
			out += separator
		out += str(values[i])
	return out
