extends RefCounted
class_name EventWorldBuilder


var star_field = null
var npc_handler = null
var beacons: Beacons = null
var enemy_handler: EnemyHandler = null
var space_objects = null
var planets = null
var map = null
var blocked_events: Dictionary = {}
var event_state_provider = null
var enemy_intel_handler = null


func setup(refs: Dictionary) -> void:
	star_field = refs.get("star_field", null)
	npc_handler = refs.get("npc_handler", null)
	beacons = refs.get("beacons", null)
	enemy_handler = refs.get("enemy_handler", null)
	space_objects = refs.get("space_objects", null)
	planets = refs.get("planets", refs.get("planet_handler", null))
	map = refs.get("map", null)
	enemy_intel_handler = refs.get("enemy_intel_handler", null)
	var loaded_blocked_events = refs.get("blocked_events", {})
	blocked_events = loaded_blocked_events.duplicate(true) if typeof(loaded_blocked_events) == TYPE_DICTIONARY else {}
	event_state_provider = refs.get("event_state_provider", refs.get("game_event_handler", refs.get("game_events_handler", refs.get("event_handler", null))))


func set_event_state_provider(provider) -> void:
	event_state_provider = provider


func install_event_objects(event_data: Dictionary, only_spawn_step: String = "") -> Dictionary:
	var result := {
		"status": "success",
		"installed": {},
		"skipped": {},
		"errors": {}
	}

	var source_event_id := str(event_data.get("event_id", "")).strip_edges()
	if source_event_id != "" and is_event_blocked(source_event_id):
		result["status"] = "skipped"
		result["skipped"][source_event_id] = "source event blocked"
		return result

	var event_objects: Dictionary = event_data.get("event_objects", {})
	for object_id in event_objects.keys():
		var object_data = event_objects[object_id]
		if typeof(object_data) != TYPE_DICTIONARY:
			result["errors"][str(object_id)] = "object data is not a dictionary"
			continue
		if bool(object_data.get("runtime_removed", object_data.get("is_removed", false))):
			result["skipped"][str(object_id)] = "runtime removed"
			continue

		var spawn_on_step := str(object_data.get("spawn_on_step", ""))
		if only_spawn_step == "" and spawn_on_step != "":
			result["skipped"][str(object_id)] = "waiting for spawn_on_step"
			continue
		if only_spawn_step != "" and spawn_on_step != "" and spawn_on_step != only_spawn_step:
			result["skipped"][str(object_id)] = "spawn_on_step mismatch"
			continue
		if object_targets_blocked_event(object_data):
			result["skipped"][str(object_id)] = "object targets blocked event"
			continue

		var installed = install_event_object(str(object_id), object_data, event_data)
		if installed == null:
			result["errors"][str(object_id)] = "install returned null"
		else:
			result["installed"][str(object_id)] = installed

	if not result["errors"].is_empty():
		result["status"] = "partial"

	return result


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


func object_targets_blocked_event(object_data: Dictionary) -> bool:
	for key in ["event_id", "active_event_id", "trigger_event_id", "give_event", "requires_event"]:
		var event_id := str(object_data.get(key, "")).strip_edges()
		if event_id != "" and is_event_blocked(event_id):
			return true
	return false


func install_event_object(object_id: String, object_data: Dictionary, event_data: Dictionary):
	var owner_type := str(object_data.get("owner_type", object_data.get("object_type", ""))).strip_edges().to_lower()
	var object_type := str(object_data.get("object_type", "")).strip_edges().to_lower()

	# Planets are authored world citizens, not generic space_objects.
	# This lets event_objects use either owner_type or object_type safely.
	if owner_type == "planet" or object_type == "planet":
		return install_planet(object_id, object_data, event_data)

	match owner_type:
		"star":
			return install_star(object_id, object_data, event_data)
		"npc":
			return install_npc(object_id, object_data, event_data)
		"beacon":
			return install_beacon(object_id, object_data, event_data)
		"enemy":
			return install_enemy(object_id, object_data, event_data)
		"space_object", "asteroid", "object":
			return install_space_object(object_id, object_data, event_data)
		_:
			return null


func install_star(object_id: String, object_data: Dictionary, event_data: Dictionary):
	if star_field == null or not star_field.has_method("make_star"):
		return null

	var existing = find_star(object_id, str(object_data.get("display_name", object_data.get("star_name", ""))))
	if existing != null:
		return existing

	var sector := read_sector(object_data.get("sector_pos", object_data.get("sector", Vector3i.ZERO)))
	var local := read_local(object_data.get("local_pos", object_data.get("local", Vector3(500, 500, 500))))
	var display_name := str(object_data.get("display_name", object_data.get("star_name", object_id)))
	var star_type := str(object_data.get("star_type", "K"))

	var star = star_field.make_star(
		display_name,
		star_type,
		sector,
		local,
		float(object_data.get("brightness", 1.2)),
		float(object_data.get("size", 1.4))
	)

	if star == null:
		return null

	star.object_id = object_id
	star.display_name = display_name
	var event_id := str(object_data.get("event_id", event_data.get("event_id", "")))
	star.has_event = bool(object_data.get("has_event", event_id != ""))
	star.give_event = str(object_data.get("give_event", event_id if star.has_event else ""))
	var star_labels := ["star"]
	if event_id != "":
		star_labels.append("event_object")
	star.labels = merge_labels(object_data.get("labels", []), star_labels)
	if star.has_method("sync_shared_meta"):
		star.sync_shared_meta()

	return star


func install_npc(object_id: String, object_data: Dictionary, event_data: Dictionary):
	if npc_handler == null:
		return null

	var npc_id := str(object_data.get("object_id", object_data.get("npc_id", object_id))).strip_edges()
	if npc_id == "":
		npc_id = object_id

	var existing = find_npc(npc_id)
	if existing != null:
		apply_event_npc_runtime_data(existing, npc_id, object_data, event_data, true)
		return existing

	if not npc_handler.has_method("make_npc_from_blueprint"):
		return null

	var position := resolve_object_position(object_data, event_data)
	var sector: Vector3i = position["sector_pos"]
	var local: Vector3 = position["local_pos"]
	var blueprint_id := str(object_data.get("blueprint_id", npc_id))
	var npc = npc_handler.make_npc_from_blueprint(blueprint_id, sector, local)
	if npc == null:
		return null

	apply_event_npc_runtime_data(npc, npc_id, object_data, event_data, true)
	return npc


func apply_event_npc_runtime_data(npc, object_id: String, object_data: Dictionary, event_data: Dictionary, update_position: bool = true) -> void:
	if npc == null:
		return

	var source := object_data.duplicate(true)
	var npc_id := str(source.get("object_id", source.get("npc_id", object_id))).strip_edges()
	if npc_id == "":
		npc_id = object_id
	var blueprint_id := str(source.get("blueprint_id", npc_id)).strip_edges()
	if blueprint_id == "":
		blueprint_id = npc_id

	var sector: Vector3i = npc.sector_pos
	var local: Vector3 = npc.local_pos
	if update_position and npc_object_has_position_data(source):
		var position := resolve_object_position(source, event_data)
		sector = position["sector_pos"]
		local = position["local_pos"]

	var display_name := str(source.get("display_name", source.get("name", npc.npc_name))).strip_edges()
	if display_name == "":
		display_name = npc_id

	npc.object_id = npc_id
	npc.object_type = "npc"
	npc.display_name = display_name
	npc.npc_name = display_name
	npc.sector_pos = sector
	npc.local_pos = local
	npc.set_meta("npc_id", npc_id)
	npc.set_meta("blueprint_id", blueprint_id)

	if source.has("species"):
		npc.npc_species = str(source.get("species", npc.npc_species))
	if source.has("role"):
		npc.npc_role = str(source.get("role", npc.npc_role))
	if source.has("friendly"):
		npc.is_friendly = bool(source.get("friendly", npc.is_friendly))

	var meta := build_event_meta_source(npc_id, "npc", display_name, sector, local, source, event_data)
	npc.apply_shared_meta(meta, true)
	npc.set_meta("npc_id", npc_id)
	npc.set_meta("blueprint_id", blueprint_id)
	apply_event_npc_dialogue_content(npc, source)
	if npc.has_method("sync_shared_meta"):
		npc.sync_shared_meta()


func npc_object_has_position_data(object_data: Dictionary) -> bool:
	return object_data.has("sector_pos") or object_data.has("local_pos") or object_data.has("sector") or object_data.has("local") or object_data.has("sector_offset") or object_data.has("local_offset") or object_data.has("anchor_local_offset") or object_data.has("position_mode") or bool(object_data.get("place_near_anchor_star", false))


func remove_npc(object_id: String) -> bool:
	var clean_id := str(object_id).strip_edges()
	if clean_id == "" or npc_handler == null:
		return false
	if npc_handler.has_method("remove_npc_by_id"):
		return bool(npc_handler.remove_npc_by_id(clean_id))
	if not "npcs" in npc_handler:
		return false
	var removed_any := false
	for i in range(npc_handler.npcs.size() - 1, -1, -1):
		var npc = npc_handler.npcs[i]
		if npc == null:
			continue
		var matches := false
		matches = matches or str(npc.get_meta("npc_id", "")).strip_edges() == clean_id
		matches = matches or str(npc.object_id).strip_edges() == clean_id
		matches = matches or str(npc.get_meta("blueprint_id", "")).strip_edges() == clean_id
		if matches:
			npc_handler.npcs.remove_at(i)
			removed_any = true
			if npc is Node and is_instance_valid(npc):
				npc.queue_free()
	return removed_any


func apply_event_npc_dialogue_content(npc, object_data: Dictionary) -> void:
	if npc == null:
		return

	for source in collect_npc_talk_sources(object_data):
		apply_npc_talk_source_to_npc(npc, source)

	if npc.has_method("sync_shared_meta"):
		npc.sync_shared_meta()


func collect_npc_talk_sources(object_data: Dictionary) -> Array:
	var sources: Array = []
	for nested_key in ["talk_meta", "npc_meta", "contact_meta", "dialogue", "trade_meta"]:
		var nested = object_data.get(nested_key, {})
		if typeof(nested) == TYPE_DICTIONARY:
			sources.append(nested)
	sources.append(object_data)
	return sources


func apply_npc_talk_source_to_npc(npc, source: Dictionary) -> void:
	var lines := []
	for key in ["npc_dialogue_lines", "dialogue_lines", "lines", "completed_npc_dialogue_lines", "completed_dialogue_lines"]:
		lines = normalize_dialogue_lines(source.get(key, []))
		if not lines.is_empty():
			break
	if not lines.is_empty():
		npc.set_meta("dialogue_lines", lines.duplicate(true))
		npc.greeting_message = str(lines[0])
		npc.has_message = true

	if source.has("message"):
		npc.greeting_message = str(source.get("message", npc.greeting_message))
		npc.has_message = npc.greeting_message.strip_edges() != ""
	if source.has("greeting_message"):
		npc.greeting_message = str(source.get("greeting_message", npc.greeting_message))
		npc.has_message = npc.greeting_message.strip_edges() != ""

	if source.has("chat_line_delay") or source.has("npc_chat_line_delay") or source.has("completed_chat_line_delay") or source.has("completed_npc_chat_line_delay"):
		var line_delay := float(source.get("npc_chat_line_delay", source.get("chat_line_delay", source.get("completed_chat_line_delay", source.get("completed_npc_chat_line_delay", npc.chat_line_delay)))))
		npc.chat_line_delay = max(line_delay, 0.1)
		npc.set_meta("chat_line_delay", npc.chat_line_delay)

	if source.has("chat_character_delay") or source.has("chat_type_delay") or source.has("npc_chat_character_delay") or source.has("completed_chat_character_delay") or source.has("completed_npc_chat_character_delay"):
		var character_delay := float(source.get("npc_chat_character_delay", source.get("chat_character_delay", source.get("chat_type_delay", source.get("completed_chat_character_delay", source.get("completed_npc_chat_character_delay", npc.chat_character_delay))))))
		npc.chat_character_delay = max(character_delay, 0.005)
		npc.set_meta("chat_character_delay", npc.chat_character_delay)

	if source.has("can_trade") or source.has("trade") or source.has("npc_can_trade") or source.has("trade_enabled"):
		var can_trade_now := bool(source.get("npc_can_trade", source.get("can_trade", source.get("trade", source.get("trade_enabled", npc.can_trade)))))
		npc.can_trade = can_trade_now
		npc.set_meta("can_trade", can_trade_now)
		npc.set_meta("trade", can_trade_now)
	if source.has("trade_completed"):
		npc.set_meta("trade_completed", bool(source.get("trade_completed", false)))
	if source.has("item_list") and typeof(source.get("item_list", [])) == TYPE_ARRAY:
		npc.set_meta("item_list", source.get("item_list", []).duplicate(true))

	for key in ["offer_title", "offer_text", "success_text"]:
		if source.has(key):
			npc.set_meta(key, str(source.get(key, "")))

	for key in ["event_accept_message", "event_decline_message", "event_idle_message", "event_completed_message"]:
		if source.has(key):
			var value := str(source.get(key, ""))
			npc.set_meta(key, value)
			match key:
				"event_accept_message":
					npc.event_accept_message = value
				"event_decline_message":
					npc.event_decline_message = value
				"event_idle_message":
					npc.event_idle_message = value
				"event_completed_message":
					npc.event_completed_message = value

	if source.has("event_next_step"):
		npc.set_meta("event_next_step", str(source.get("event_next_step", "")))
	if source.has("interaction_type"):
		npc.set_meta("interaction_type", str(source.get("interaction_type", "")))

	var has_quest_update := source.has("npc_quest_available") or source.has("quest_available") or source.has("npc_has_event") or source.has("has_event")
	var has_event_id_update := source.has("npc_event_id") or source.has("event_id") or source.has("active_event_id")
	if has_quest_update:
		var has_event_now := bool(source.get("npc_quest_available", source.get("quest_available", source.get("npc_has_event", source.get("has_event", npc.has_event)))))
		npc.has_event = has_event_now
		npc.set_meta("has_event", has_event_now)
	if has_event_id_update:
		var event_id := str(source.get("npc_event_id", source.get("event_id", npc.event_id))).strip_edges()
		var active_event_id := str(source.get("active_event_id", event_id)).strip_edges()
		if event_id != "":
			npc.event_id = event_id
			npc.set_meta("event_id", event_id)
			npc.has_event = true
			npc.set_meta("has_event", true)
		if active_event_id != "":
			npc.active_event_id = active_event_id
			npc.set_meta("active_event_id", active_event_id)
	if source.has("npc_event_state") or source.has("event_state"):
		var event_state := str(source.get("npc_event_state", source.get("event_state", npc.event_state))).strip_edges()
		npc.event_state = event_state
		npc.set_meta("event_state", event_state)


func install_beacon(object_id: String, object_data: Dictionary, event_data: Dictionary) -> Dictionary:
	if beacons == null:
		return {}

	var existing := find_beacon(object_id)
	if not existing.is_empty():
		merge_beacon_data(existing, object_id, object_data, event_data)
		return existing

	var position := resolve_object_position(object_data, event_data)
	var sector: Vector3i = position["sector_pos"]
	var local: Vector3 = position["local_pos"]
	var display_name := str(object_data.get("display_name", object_data.get("title", object_id)))
	var beacon_type := str(object_data.get("beacon_type", "event_beacon"))

	var beacon_data := {
		"id": object_id,
		"object_id": object_id,
		"object_type": "beacon",
		"display_name": display_name,
		"title": display_name,
		"beacon_type": beacon_type,
		"tier": int(event_data.get("tier", object_data.get("tier", 1))),
		"sector_pos": sector,
		"local_pos": local,
		"parent_star_name": str(object_data.get("parent_star_name", event_data.get("anchor_star", {}).get("star_name", ""))),
		"message": str(object_data.get("message", "A cold signal repeats from the dark.")),
		"quest_messages": object_data.get("quest_messages", []),
		"labels": merge_labels(object_data.get("labels", []), ["beacon", "event_object"])
	}

	merge_dictionary(beacon_data, object_data)
	beacon_data = SharedObjectMeta.apply_to_dictionary(
		beacon_data,
		object_id,
		"beacon",
		display_name,
		sector,
		local
	)

	beacons.beacons.append(beacon_data)
	return beacon_data


func install_enemy(object_id: String, object_data: Dictionary, event_data: Dictionary):
	if enemy_handler == null:
		return null

	var existing = find_enemy(object_id)
	if existing != null:
		register_event_enemy_intel(existing, object_id, object_data, event_data)
		return existing

	var position := resolve_object_position(object_data, event_data)
	var sector: Vector3i = position["sector_pos"]
	var local: Vector3 = position["local_pos"]
	var blueprint_id := str(object_data.get("blueprint_id", object_data.get("enemy_blueprint_id", "scout_drone")))

	var enemy = null
	if enemy_handler.has_method("make_enemy_from_blueprint"):
		enemy = enemy_handler.make_enemy_from_blueprint(blueprint_id, sector, local)
	if enemy == null:
		return null

	var display_name := str(object_data.get("display_name", object_data.get("name", enemy.enemy_name)))
	enemy.object_id = object_id
	enemy.enemy_name = display_name
	enemy.display_name = display_name
	enemy.sector_pos = sector
	enemy.local_pos = local

	apply_enemy_overrides(enemy, object_data)

	var meta := build_event_meta_source(object_id, "enemy", display_name, sector, local, object_data, event_data)
	enemy.apply_shared_meta(meta, true)
	enemy.labels = merge_labels(enemy.labels, object_data.get("labels", ["enemy", "event_enemy"]))
	var event_id := str(object_data.get("event_id", event_data.get("event_id", "")))
	if event_id != "":
		enemy.events = merge_labels(enemy.events, [event_id])
		enemy.event_tags = merge_labels(enemy.event_tags, object_data.get("event_tags", ["event_guardian"]))
		enemy.has_event = bool(object_data.get("has_event", true))
	else:
		enemy.events = merge_labels(enemy.events, object_data.get("events", []))
		enemy.event_tags = merge_labels(enemy.event_tags, object_data.get("event_tags", []))
		enemy.has_event = bool(object_data.get("has_event", false))
	enemy.sync_shared_meta()
	register_event_enemy_intel(enemy, object_id, object_data, event_data)

	return enemy


func register_event_enemy_intel(enemy, object_id: String, object_data: Dictionary, event_data: Dictionary) -> void:
	if enemy == null:
		return

	var source := object_data.duplicate(true)
	var event_id := str(source.get("event_id", event_data.get("event_id", ""))).strip_edges()
	var display_name := str(source.get("display_name", source.get("name", object_id))).strip_edges()
	source["source"] = "EventWorldBuilder.install_enemy"
	source["object_id"] = object_id
	source["enemy_id"] = object_id
	source["target_object_id"] = object_id
	source["display_name"] = display_name
	source["event_id"] = event_id
	source["active_event_id"] = str(source.get("active_event_id", event_id))
	source["has_event"] = event_id != ""
	source["enemy_template_id"] = str(source.get("enemy_template_id", source.get("enemy_blueprint_id", source.get("blueprint_id", ""))))
	if enemy_handler != null and enemy_handler.has_method("register_enemy_intel"):
		enemy_handler.register_enemy_intel(enemy, source)
	elif enemy_intel_handler != null and enemy_intel_handler.has_method("register_enemy_spawned"):
		enemy_intel_handler.register_enemy_spawned(enemy, source)


func install_space_object(object_id: String, object_data: Dictionary, event_data: Dictionary) -> Dictionary:
	if space_objects == null:
		return {}

	var existing := find_space_object(object_id)
	if not existing.is_empty():
		merge_space_object_data(existing, object_id, object_data, event_data)
		return existing

	var position := resolve_object_position(object_data, event_data)
	var sector: Vector3i = position["sector_pos"]
	var local: Vector3 = position["local_pos"]
	var object_type := str(object_data.get("object_type", object_data.get("space_object_type", "asteroid")))
	var display_name := str(object_data.get("display_name", object_data.get("scan_name", object_id)))

	var object_data_out := {
		"id": object_id,
		"object_id": object_id,
		"object_type": object_type,
		"display_name": display_name,
		"scan_name": str(object_data.get("scan_name", display_name)),
		"scan_description": str(object_data.get("scan_description", "")),
		"sector_pos": sector,
		"local_pos": local,
		"tier": int(object_data.get("tier", event_data.get("tier", 1))),
		"resource_type": str(object_data.get("resource_type", "")),
		"labels": merge_labels(object_data.get("labels", []), ["space_object", object_type])
	}

	merge_dictionary(object_data_out, object_data)
	object_data_out["sector_pos"] = sector
	object_data_out["local_pos"] = local
	object_data_out["object_id"] = object_id
	object_data_out["id"] = object_id
	object_data_out["object_type"] = object_type
	object_data_out["display_name"] = display_name

	object_data_out = SharedObjectMeta.apply_to_dictionary(
		object_data_out,
		object_id,
		object_type,
		display_name,
		sector,
		local
	)

	space_objects.objects.append(object_data_out)
	return object_data_out


func install_planet(object_id: String, object_data: Dictionary, event_data: Dictionary) -> Dictionary:
	if planets == null:
		if Globals.print_priority_7:
			print("EventWorldBuilder planet install skipped - planets handler missing. object=", object_id)
		return {}

	var planet_id := str(object_data.get("object_id", object_data.get("id", object_id))).strip_edges()
	if planet_id == "":
		planet_id = object_id

	var existing := find_planet(planet_id)
	if not existing.is_empty():
		merge_planet_data(existing, planet_id, object_data, event_data)
		return existing

	var position := resolve_object_position(object_data, event_data)
	var sector: Vector3i = position["sector_pos"]
	var local: Vector3 = position["local_pos"]
	var display_name := str(object_data.get("display_name", object_data.get("scan_name", planet_id)))
	var planet_type := str(object_data.get("planet_type", object_data.get("planet_class", "rocky")))
	var planet_role := str(object_data.get("planet_role", "survey_target"))

	var planet_data := {
		"id": planet_id,
		"object_id": planet_id,
		"owner_type": "planet",
		"object_type": "planet",
		"display_name": display_name,
		"title": str(object_data.get("title", display_name)),
		"scan_name": str(object_data.get("scan_name", display_name)),
		"scan_description": str(object_data.get("scan_description", "")),
		"contact_text": str(object_data.get("contact_text", "")),
		"sector_pos": sector,
		"local_pos": local,
		"tier": int(object_data.get("tier", event_data.get("tier", 1))),
		"parent_star_id": str(object_data.get("parent_star_id", "")),
		"parent_star_name": str(object_data.get("parent_star_name", event_data.get("anchor_star", {}).get("star_name", ""))),
		"planet_type": planet_type,
		"planet_role": planet_role,
		"population_state": str(object_data.get("population_state", "")),
		"services": object_data.get("services", []),
		"planet_board_events": object_data.get("planet_board_events", []),
		"has_planet_interface": bool(object_data.get("has_planet_interface", true)),
		"can_land": bool(object_data.get("can_land", false)),
		"interaction_type": str(object_data.get("interaction_type", "planet_contact")),
		"labels": merge_labels(object_data.get("labels", []), ["planet", "event_object", "authored_object"])
	}

	merge_dictionary(planet_data, object_data)
	planet_data["id"] = planet_id
	planet_data["object_id"] = planet_id
	planet_data["owner_type"] = "planet"
	planet_data["object_type"] = "planet"
	planet_data["display_name"] = display_name
	planet_data["sector_pos"] = sector
	planet_data["local_pos"] = local
	planet_data["planet_type"] = planet_type
	planet_data["planet_role"] = planet_role
	planet_data["labels"] = merge_labels(planet_data.get("labels", []), ["planet", "event_object", "authored_object"])

	var event_id := str(object_data.get("event_id", event_data.get("event_id", ""))).strip_edges()
	if event_id != "":
		planet_data["has_event"] = true
		planet_data["event_id"] = str(planet_data.get("event_id", event_id))
		planet_data["active_event_id"] = str(planet_data.get("active_event_id", event_id))
		planet_data["event_state"] = str(planet_data.get("event_state", event_data.get("event_state", "active")))
		planet_data["event_step"] = str(planet_data.get("event_step", event_data.get("current_step", "")))
		planet_data["current_step"] = str(planet_data.get("current_step", event_data.get("current_step", "")))
		planet_data["event_ids"] = merge_labels(planet_data.get("event_ids", []), [event_id])

	planet_data = SharedObjectMeta.apply_to_dictionary(
		planet_data,
		planet_id,
		"planet",
		display_name,
		sector,
		local
	)

	if planets.has_method("add_planet_from_data"):
		var installed = planets.add_planet_from_data(planet_data, true)
		if typeof(installed) == TYPE_DICTIONARY:
			if Globals.print_priority_7:
				print("EventWorldBuilder installed planet: ", planet_id, " sector=", sector, " local=", local)
			return installed

	if "planets" in planets:
		planets.planets.append(planet_data)
		if Globals.print_priority_7:
			print("EventWorldBuilder installed planet fallback: ", planet_id, " sector=", sector, " local=", local)
		return planet_data

	return {}


func apply_enemy_overrides(enemy, object_data: Dictionary) -> void:
	var overrides: Dictionary = object_data.get("overrides", {})
	for source in [object_data, overrides]:
		if typeof(source) != TYPE_DICTIONARY:
			continue
		if source.has("hp"):
			enemy.hp = int(source["hp"])
		if source.has("max_hp"):
			enemy.max_hp = int(source["max_hp"])
		if source.has("attack"):
			enemy.attack = int(source["attack"])
		if source.has("energy_max"):
			enemy.energy_max = float(source["energy_max"])
		if source.has("primary"):
			enemy.primary = str(source["primary"])
		if source.has("secondary"):
			enemy.secondary = str(source["secondary"])
		if source.has("shield"):
			enemy.shield = str(source["shield"])
		if source.has("consumable"):
			enemy.consumable = str(source["consumable"])
		if source.has("item_stacks") and typeof(source["item_stacks"]) == TYPE_DICTIONARY:
			enemy.item_stacks = source["item_stacks"].duplicate(true)
		if source.has("behavior_profile"):
			enemy.behavior_profile = str(source["behavior_profile"])
		if source.has("behavior_values") and typeof(source["behavior_values"]) == TYPE_DICTIONARY:
			enemy.behavior_values = source["behavior_values"].duplicate(true)
		if source.has("reward") and typeof(source["reward"]) == TYPE_ARRAY:
			enemy.reward = source["reward"].duplicate(true)
		if source.has("battle_comment") and typeof(source["battle_comment"]) == TYPE_ARRAY:
			enemy.battle_comment = source["battle_comment"].duplicate(true)
		if source.has("ship_name"):
			enemy.ship_name = str(source["ship_name"])

	if enemy.max_hp < enemy.hp:
		enemy.max_hp = enemy.hp


func merge_beacon_data(beacon_data: Dictionary, object_id: String, object_data: Dictionary, event_data: Dictionary) -> void:
	var fallback_data := object_data.duplicate(true)
	if not fallback_data.has("sector_pos"):
		fallback_data["sector_pos"] = beacon_data.get("sector_pos", Vector3i.ZERO)
	if not fallback_data.has("local_pos") and not fallback_data.has("local_offset"):
		fallback_data["local_pos"] = beacon_data.get("local_pos", Vector3.ZERO)
	var position := resolve_object_position(fallback_data, event_data)
	var sector: Vector3i = position["sector_pos"]
	var local: Vector3 = position["local_pos"]
	var display_name := str(object_data.get("display_name", beacon_data.get("display_name", object_id)))
	merge_dictionary(beacon_data, object_data)
	beacon_data["sector_pos"] = sector
	beacon_data["local_pos"] = local
	beacon_data["display_name"] = display_name
	beacon_data["title"] = str(beacon_data.get("title", display_name))
	beacon_data["labels"] = merge_labels(beacon_data.get("labels", []), ["beacon", "event_object"])
	SharedObjectMeta.apply_to_dictionary(beacon_data, object_id, "beacon", display_name, sector, local)


func merge_space_object_data(space_object_data: Dictionary, object_id: String, object_data: Dictionary, event_data: Dictionary) -> void:
	var fallback_data := object_data.duplicate(true)
	if not fallback_data.has("sector_pos"):
		fallback_data["sector_pos"] = space_object_data.get("sector_pos", Vector3i.ZERO)
	if not fallback_data.has("local_pos") and not fallback_data.has("local_offset"):
		fallback_data["local_pos"] = space_object_data.get("local_pos", Vector3.ZERO)
	var position := resolve_object_position(fallback_data, event_data)
	var sector: Vector3i = position["sector_pos"]
	var local: Vector3 = position["local_pos"]
	var object_type := str(object_data.get("object_type", space_object_data.get("object_type", "asteroid")))
	var display_name := str(object_data.get("display_name", space_object_data.get("display_name", object_id)))
	merge_dictionary(space_object_data, object_data)
	space_object_data["id"] = object_id
	space_object_data["object_id"] = object_id
	space_object_data["object_type"] = object_type
	space_object_data["display_name"] = display_name
	space_object_data["sector_pos"] = sector
	space_object_data["local_pos"] = local
	space_object_data["labels"] = merge_labels(space_object_data.get("labels", []), ["space_object", object_type])
	SharedObjectMeta.apply_to_dictionary(space_object_data, object_id, object_type, display_name, sector, local)


func merge_planet_data(planet_data: Dictionary, object_id: String, object_data: Dictionary, event_data: Dictionary) -> void:
	var fallback_data := object_data.duplicate(true)
	if not fallback_data.has("sector_pos"):
		fallback_data["sector_pos"] = planet_data.get("sector_pos", Vector3i.ZERO)
	if not fallback_data.has("local_pos") and not fallback_data.has("local_offset"):
		fallback_data["local_pos"] = planet_data.get("local_pos", Vector3.ZERO)
	var position := resolve_object_position(fallback_data, event_data)
	var sector: Vector3i = position["sector_pos"]
	var local: Vector3 = position["local_pos"]
	var display_name := str(object_data.get("display_name", planet_data.get("display_name", object_id)))
	var planet_type := str(object_data.get("planet_type", planet_data.get("planet_type", "rocky")))
	var planet_role := str(object_data.get("planet_role", planet_data.get("planet_role", "survey_target")))

	merge_dictionary(planet_data, object_data)
	planet_data["id"] = object_id
	planet_data["object_id"] = object_id
	planet_data["owner_type"] = "planet"
	planet_data["object_type"] = "planet"
	planet_data["display_name"] = display_name
	planet_data["sector_pos"] = sector
	planet_data["local_pos"] = local
	planet_data["planet_type"] = planet_type
	planet_data["planet_role"] = planet_role
	planet_data["labels"] = merge_labels(planet_data.get("labels", []), ["planet", "event_object", "authored_object"])
	SharedObjectMeta.apply_to_dictionary(planet_data, object_id, "planet", display_name, sector, local)


func build_event_meta_source(object_id: String, object_type: String, display_name: String, sector: Vector3i, local: Vector3, object_data: Dictionary, event_data: Dictionary) -> Dictionary:
	var event_id := str(object_data.get("event_id", event_data.get("event_id", "")))
	var source := object_data.duplicate(true)
	source["object_id"] = object_id
	source["object_type"] = object_type
	source["display_name"] = display_name
	source["sector_pos"] = sector
	source["local_pos"] = local
	source["has_event"] = event_id != ""
	source["event_id"] = event_id
	source["active_event_id"] = str(object_data.get("active_event_id", event_id))
	source["event_state"] = str(object_data.get("event_state", "active"))
	source["event_step"] = str(object_data.get("event_step", object_data.get("required_step", "")))
	source["current_step"] = str(object_data.get("current_step", object_data.get("required_step", "")))
	source["required_step"] = str(object_data.get("required_step", ""))
	source["labels"] = merge_labels(object_data.get("labels", []), [object_type, "event_object"])
	return source


func find_star(object_id: String, display_name: String):
	if star_field == null or not "stars" in star_field:
		return null
	for star in star_field.stars:
		if star == null:
			continue
		if object_id != "" and str(star.object_id) == object_id:
			return star
		if display_name != "" and str(star.star_name) == display_name:
			return star
	return null


func find_npc(object_id: String):
	var clean_id := str(object_id).strip_edges()
	if clean_id == "" or npc_handler == null:
		return null
	if npc_handler.has_method("get_npc_by_id"):
		var direct_npc = npc_handler.get_npc_by_id(clean_id)
		if direct_npc != null:
			return direct_npc
	if not "npcs" in npc_handler:
		return null
	for npc in npc_handler.npcs:
		if npc == null:
			continue
		if str(npc.get_meta("npc_id", "")).strip_edges() == clean_id:
			return npc
		if str(npc.object_id).strip_edges() == clean_id:
			return npc
		if str(npc.get_meta("blueprint_id", "")).strip_edges() == clean_id:
			return npc
	return null


func find_beacon(object_id: String) -> Dictionary:
	if beacons == null:
		return {}
	if beacons.has_method("get_beacon_by_id"):
		return beacons.get_beacon_by_id(object_id)
	for beacon in beacons.beacons:
		if typeof(beacon) == TYPE_DICTIONARY and str(beacon.get("object_id", beacon.get("id", ""))) == object_id:
			return beacon
	return {}


func find_enemy(object_id: String):
	if enemy_handler == null or not "enemies" in enemy_handler:
		return null
	for enemy in enemy_handler.enemies:
		if enemy == null:
			continue
		if str(enemy.object_id) == object_id:
			return enemy
	return null


func find_space_object(object_id: String) -> Dictionary:
	if space_objects == null or not "objects" in space_objects:
		return {}
	if space_objects.has_method("get_object_by_id"):
		var found = space_objects.get_object_by_id(object_id)
		if typeof(found) == TYPE_DICTIONARY:
			return found
	for space_object in space_objects.objects:
		if typeof(space_object) == TYPE_DICTIONARY and str(space_object.get("object_id", space_object.get("id", ""))) == object_id:
			return space_object
	return {}


func find_planet(object_id: String) -> Dictionary:
	if planets == null:
		return {}
	if planets.has_method("get_planet_by_id"):
		var found = planets.get_planet_by_id(object_id)
		if typeof(found) == TYPE_DICTIONARY:
			return found
	if not "planets" in planets:
		return {}
	for planet in planets.planets:
		if typeof(planet) == TYPE_DICTIONARY and str(planet.get("object_id", planet.get("id", ""))) == object_id:
			return planet
	return {}


func merge_dictionary(target: Dictionary, source: Dictionary) -> void:
	for key in source.keys():
		target[key] = source[key]


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


func normalize_dialogue_lines(value) -> Array:
	var lines: Array = []
	if typeof(value) == TYPE_ARRAY:
		for line in value:
			var clean_line := str(line).strip_edges()
			if clean_line != "":
				lines.append(clean_line)
	elif typeof(value) == TYPE_STRING:
		for raw_line in str(value).split("\n", false):
			var clean_string := str(raw_line).strip_edges()
			if clean_string != "":
				lines.append(clean_string)
	return lines


func read_sector(value) -> Vector3i:
	return SharedObjectMeta.read_sector_pos(value)


func read_local(value) -> Vector3:
	return SharedObjectMeta.read_local_pos(value)


func resolve_object_position(object_data: Dictionary, event_data: Dictionary) -> Dictionary:
	var position_mode := str(object_data.get("position_mode", "")).strip_edges().to_lower()
	var use_anchor := bool(object_data.get("place_near_anchor_star", false))
	use_anchor = use_anchor or position_mode == "anchor_offset" or position_mode == "anchor_relative"
	use_anchor = use_anchor or object_data.has("anchor_local_offset") or object_data.has("sector_offset")

	if not use_anchor:
		var absolute_sector := read_sector(object_data.get("sector_pos", object_data.get("sector", Vector3i.ZERO)))
		var absolute_local := read_local(object_data.get("local_pos", object_data.get("local", Vector3.ZERO)))
		return normalize_sector_local_pair(absolute_sector, absolute_local)

	var anchor_position := resolve_anchor_position(event_data)
	var sector: Vector3i = anchor_position["sector_pos"]
	var local: Vector3 = anchor_position["local_pos"]
	var sector_offset := read_sector(object_data.get("sector_offset", Vector3i.ZERO))
	var offset_source = object_data.get("local_offset", object_data.get("anchor_local_offset", object_data.get("local_pos", Vector3.ZERO)))
	var local_offset := read_local(offset_source)

	sector += sector_offset
	local += local_offset
	return normalize_sector_local_pair(sector, local)


func resolve_anchor_position(event_data: Dictionary) -> Dictionary:
	var anchor: Dictionary = event_data.get("anchor_star", {}) if typeof(event_data.get("anchor_star", {})) == TYPE_DICTIONARY else {}
	var star = find_star(str(anchor.get("star_id", "")), str(anchor.get("star_name", "")))
	if star != null:
		return normalize_sector_local_pair(star.sector_pos, star.local_pos)

	var sector := read_sector(anchor.get("sector_pos", anchor.get("sector", Vector3i.ZERO)))
	var local := read_local(anchor.get("local_pos", anchor.get("local", Vector3(500, 500, 500))))
	return normalize_sector_local_pair(sector, local)


func normalize_sector_local_pair(sector: Vector3i, local: Vector3) -> Dictionary:
	var sector_size := float(Globals.sector_size)
	if sector_size <= 0.0:
		return {
			"sector_pos": sector,
			"local_pos": local
		}

	while local.x >= sector_size:
		local.x -= sector_size
		sector.x += 1
	while local.x < 0.0:
		local.x += sector_size
		sector.x -= 1

	while local.y >= sector_size:
		local.y -= sector_size
		sector.y += 1
	while local.y < 0.0:
		local.y += sector_size
		sector.y -= 1

	while local.z >= sector_size:
		local.z -= sector_size
		sector.z += 1
	while local.z < 0.0:
		local.z += sector_size
		sector.z -= 1

	return {
		"sector_pos": sector,
		"local_pos": local
	}
