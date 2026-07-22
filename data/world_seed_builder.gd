extends RefCounted
class_name WorldSeedBuilder


const DEFAULT_WORLD_SEED_DIR := "res://data/world_seeds"

var event_world_builder := EventWorldBuilder.new()
var seed_catalog: Dictionary = {}
var planets = null
var blocked_events: Dictionary = {}
var event_state_provider = null


func setup(refs: Dictionary) -> void:
	event_world_builder.setup(refs)
	planets = refs.get("planets", refs.get("planet_handler", null))
	var loaded_blocked_events = refs.get("blocked_events", {})
	blocked_events = loaded_blocked_events.duplicate(true) if typeof(loaded_blocked_events) == TYPE_DICTIONARY else {}
	event_state_provider = refs.get("event_state_provider", refs.get("game_event_handler", refs.get("game_events_handler", refs.get("event_handler", null))))
	if event_world_builder != null and event_world_builder.has_method("set_event_state_provider"):
		event_world_builder.set_event_state_provider(event_state_provider)
	load_seed_catalog_from_json()


func set_event_state_provider(provider) -> void:
	event_state_provider = provider
	if event_world_builder != null and event_world_builder.has_method("set_event_state_provider"):
		event_world_builder.set_event_state_provider(provider)




func resolve_world_seed_dir() -> String:
	var lane_dir := str(Globals.active_universe_world_seeds_dir).strip_edges()
	if lane_dir != "" and DirAccess.dir_exists_absolute(lane_dir):
		return lane_dir

	if Globals.print_priority_2:
		print("[UNIVERSE_LANE_SEEDS] active world seed dir missing, using fallback. active=", lane_dir, " fallback=", DEFAULT_WORLD_SEED_DIR)

	return DEFAULT_WORLD_SEED_DIR

func load_seed_catalog_from_json() -> void:
	seed_catalog.clear()

	var active_seed_dir := resolve_world_seed_dir()
	var dir := DirAccess.open(active_seed_dir)
	if dir == null:
		if Globals.print_priority_7:
			print("World seed directory missing: ", active_seed_dir)
		return

	if Globals.print_priority_2:
		print("[UNIVERSE_LANE_SEEDS] universe_id=", Globals.active_universe_id, " loading_dir=", active_seed_dir)

	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue

		var path := active_seed_dir + "/" + file_name
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			if Globals.print_priority_1:
				print("Could not open world seed JSON: ", path)
			continue

		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			if Globals.print_priority_1:
				print("World seed rejected - root is not a Dictionary: ", path)
			continue

		var seed_data := normalize_seed_data(parsed)
		var seed_id := str(seed_data.get("seed_id", ""))
		if seed_id == "":
			if Globals.print_priority_1:
				print("World seed rejected - missing seed_id: ", path)
			continue

		seed_data["source_path"] = path
		seed_catalog[seed_id] = seed_data

	if Globals.print_priority_2:
		print("[UNIVERSE_LANE_SEEDS] loaded_count=", seed_catalog.size(), " keys=", seed_catalog.keys())


func apply_startup_seeds(stage: String = "all") -> Dictionary:
	var result := {
		"status": "success",
		"stage": stage,
		"seeds": {}
	}

	for seed_id in seed_catalog.keys():
		var seed_data: Dictionary = seed_catalog[seed_id]
		if not bool(seed_data.get("apply_on_new_universe", false)):
			continue

		result["seeds"][seed_id] = apply_seed(seed_data, stage)

	return result


func apply_seed(seed_data: Dictionary, stage: String = "all") -> Dictionary:
	var filtered_objects := filter_seed_objects_for_stage(seed_data, stage)
	if filtered_objects.is_empty():
		return {
			"status": "skipped",
			"reason": "no objects for stage",
			"stage": stage
		}

	var event_data := {
		"event_id": "",
		"seed_id": str(seed_data.get("seed_id", "")),
		"tier": int(seed_data.get("tier", 1)),
		"event_objects": filtered_objects
	}

	if typeof(seed_data.get("anchor_star", {})) == TYPE_DICTIONARY:
		var anchor_star: Dictionary = seed_data.get("anchor_star", {})
		if not anchor_star.is_empty():
			event_data["anchor_star"] = anchor_star.duplicate(true)

	return install_filtered_seed_objects(filtered_objects, event_data, seed_data)



func install_filtered_seed_objects(filtered_objects: Dictionary, event_data: Dictionary, seed_data: Dictionary) -> Dictionary:
	var result := make_empty_install_result()
	var normal_objects := {}
	var planet_objects := {}

	for object_id in filtered_objects.keys():
		var object_data = filtered_objects[object_id]
		if typeof(object_data) != TYPE_DICTIONARY:
			result["errors"][str(object_id)] = "object data is not a dictionary"
			continue

		if is_planet_seed_object(object_data):
			planet_objects[str(object_id)] = object_data
		else:
			normal_objects[str(object_id)] = object_data

	if not normal_objects.is_empty():
		var normal_event_data := event_data.duplicate(true)
		normal_event_data["event_objects"] = normal_objects
		merge_install_result(result, event_world_builder.install_event_objects(normal_event_data, ""))

	if not planet_objects.is_empty():
		merge_install_result(result, install_planet_seed_objects(planet_objects, event_data, seed_data))

	finalize_install_result_status(result)
	return result


func install_planet_seed_objects(planet_objects: Dictionary, event_data: Dictionary, seed_data: Dictionary) -> Dictionary:
	if Globals.print_priority_4:
		print("world_seed_builder | install_planet_seed_objects")
	var result := make_empty_install_result()

	if planets == null:
		for object_id in planet_objects.keys():
			result["errors"][str(object_id)] = "planets ref missing"
		finalize_install_result_status(result)
		if Globals.print_priority_4:
			print("planet is null")
		return result

	if not planets.has_method("add_planet_from_data"):
		for object_id in planet_objects.keys():
			result["errors"][str(object_id)] = "planets handler missing add_planet_from_data()"
		finalize_install_result_status(result)
		if Globals.print_priority_4:
			print("no add_planet_from_data")
		return result

	for object_id in planet_objects.keys():
		var object_data = planet_objects[object_id]
		if typeof(object_data) != TYPE_DICTIONARY:
			result["errors"][str(object_id)] = "planet data is not a dictionary"
			continue

		var planet_source := build_planet_seed_source(str(object_id), object_data, event_data, seed_data)
		var planet = planets.add_planet_from_data(planet_source, true)
		if typeof(planet) == TYPE_DICTIONARY and not planet.is_empty():
			result["installed"][str(object_id)] = planet
		else:
			result["errors"][str(object_id)] = "planet install failed"

	finalize_install_result_status(result)
	print(str(result))
	
	return result


func build_planet_seed_source(object_id: String, object_data: Dictionary, event_data: Dictionary, seed_data: Dictionary) -> Dictionary:
	var source := object_data.duplicate(true)
	var position_event_data := build_planet_position_event_data(source, event_data)
	var position := event_world_builder.resolve_object_position(source, position_event_data)
	var sector: Vector3i = position.get("sector_pos", Vector3i.ZERO)
	var local: Vector3 = position.get("local_pos", Vector3.ZERO)
	var display_name := str(source.get("display_name", source.get("scan_name", object_id)))

	source["id"] = object_id
	source["object_id"] = object_id
	source["owner_type"] = "planet"
	source["object_type"] = "planet"
	source["display_name"] = display_name
	source["sector_pos"] = sector
	source["local_pos"] = local
	source["seed_id"] = str(seed_data.get("seed_id", ""))
	source["tier"] = int(source.get("tier", event_data.get("tier", seed_data.get("tier", 1))))
	source["labels"] = merge_labels(source.get("labels", []), ["planet", "world_seed", "authored_object"])

	if not source.has("parent_star_name") and typeof(position_event_data.get("anchor_star", {})) == TYPE_DICTIONARY:
		var anchor: Dictionary = position_event_data.get("anchor_star", {})
		if str(anchor.get("star_name", "")) != "":
			source["parent_star_name"] = str(anchor.get("star_name", ""))

	return source


func build_planet_position_event_data(object_data: Dictionary, event_data: Dictionary) -> Dictionary:
	var position_event_data := event_data.duplicate(true)
	if typeof(position_event_data.get("anchor_star", {})) == TYPE_DICTIONARY and not position_event_data.get("anchor_star", {}).is_empty():
		return position_event_data

	if typeof(object_data.get("anchor_star", {})) == TYPE_DICTIONARY and not object_data.get("anchor_star", {}).is_empty():
		position_event_data["anchor_star"] = object_data.get("anchor_star", {}).duplicate(true)
		return position_event_data

	var star_id := str(object_data.get("anchor_star_id", object_data.get("parent_star_id", object_data.get("star_id", "")))).strip_edges()
	var star_name := str(object_data.get("anchor_star_name", object_data.get("parent_star_name", object_data.get("star_name", "")))).strip_edges()

	if star_id != "" or star_name != "":
		position_event_data["anchor_star"] = {
			"star_id": star_id,
			"star_name": star_name
		}

	return position_event_data


func is_planet_seed_object(object_data: Dictionary) -> bool:
	var owner_type := str(object_data.get("owner_type", object_data.get("object_type", ""))).strip_edges().to_lower()
	var object_type := str(object_data.get("object_type", "")).strip_edges().to_lower()
	return owner_type == "planet" or object_type == "planet"


func make_empty_install_result() -> Dictionary:
	return {
		"status": "success",
		"installed": {},
		"skipped": {},
		"errors": {}
	}


func merge_install_result(target: Dictionary, source: Dictionary) -> void:
	if typeof(source) != TYPE_DICTIONARY:
		return

	for bucket in ["installed", "skipped", "errors"]:
		if typeof(source.get(bucket, {})) != TYPE_DICTIONARY:
			continue
		var source_bucket: Dictionary = source.get(bucket, {})
		for key in source_bucket.keys():
			target[bucket][str(key)] = source_bucket[key]

	if str(source.get("status", "success")) == "partial":
		target["status"] = "partial"


func finalize_install_result_status(result: Dictionary) -> void:
	if not result["errors"].is_empty():
		result["status"] = "partial"
	elif result["installed"].is_empty() and not result["skipped"].is_empty():
		result["status"] = "skipped"
	else:
		result["status"] = "success"


func merge_labels(base_value, add_value) -> Array:
	var labels := []
	if typeof(base_value) == TYPE_ARRAY:
		labels = base_value.duplicate(true)
	elif str(base_value) != "":
		labels.append(str(base_value))

	if typeof(add_value) == TYPE_ARRAY:
		for label in add_value:
			if str(label) != "" and not labels.has(str(label)):
				labels.append(str(label))
	elif str(add_value) != "" and not labels.has(str(add_value)):
		labels.append(str(add_value))

	return labels


func filter_seed_objects_for_stage(seed_data: Dictionary, stage: String) -> Dictionary:
	var out := {}
	var objects: Dictionary = seed_data.get("objects", {})

	for object_id in objects.keys():
		var object_data = objects[object_id]
		if typeof(object_data) != TYPE_DICTIONARY:
			continue

		var owner_type := str(object_data.get("owner_type", object_data.get("object_type", ""))).strip_edges().to_lower()
		var should_include := false

		match stage:
			"stars":
				should_include = owner_type == "star"
			"objects":
				should_include = owner_type != "star"
			_:
				should_include = true

		if should_include:
			if seed_object_targets_blocked_event(object_data):
				continue
			var copied: Dictionary = object_data.duplicate(true)
			copied["seed_id"] = str(seed_data.get("seed_id", ""))
			out[str(object_id)] = copied

	return out


func is_event_blocked(event_id: String) -> bool:
	var clean_event_id := str(event_id).strip_edges()
	if clean_event_id == "":
		return false
	if blocked_events.has(clean_event_id):
		return true
	if event_state_provider != null:
		if event_state_provider.has_method("is_event_runtime_locked") and bool(event_state_provider.is_event_runtime_locked(clean_event_id)):
			return true
		if event_state_provider.has_method("is_event_blocked") and bool(event_state_provider.is_event_blocked(clean_event_id)):
			return true
		if event_state_provider.has_method("is_event_cancelled") and bool(event_state_provider.is_event_cancelled(clean_event_id)):
			return true
	return false


func seed_object_targets_blocked_event(object_data: Dictionary) -> bool:
	for key in ["event_id", "active_event_id", "trigger_event_id", "give_event", "requires_event"]:
		var event_id := str(object_data.get(key, "")).strip_edges()
		if event_id != "" and is_event_blocked(event_id):
			return true
	return false


func normalize_seed_data(seed_data: Dictionary) -> Dictionary:
	if Globals.print_priority_4:
			print("world_seed_builder | normalize_seed_data")
	var data := seed_data.duplicate(true)
	var objects: Dictionary = data.get("objects", {})

	for object_id in objects.keys():
		if typeof(objects[object_id]) != TYPE_DICTIONARY:
			continue
		var object_data: Dictionary = objects[object_id].duplicate(true)
		if object_data.has("sector_pos"):
			object_data["sector_pos"] = SharedObjectMeta.read_sector_pos(object_data["sector_pos"])
		elif object_data.has("sector"):
			object_data["sector_pos"] = SharedObjectMeta.read_sector_pos(object_data["sector"])
		if object_data.has("local_pos"):
			object_data["local_pos"] = SharedObjectMeta.read_local_pos(object_data["local_pos"])
		elif object_data.has("local"):
			object_data["local_pos"] = SharedObjectMeta.read_local_pos(object_data["local"])
		objects[object_id] = object_data

	data["objects"] = objects
	if Globals.print_priority_4:
		print("return data --->" + str(data))
	return data
