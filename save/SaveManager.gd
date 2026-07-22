extends Node
class_name SaveManager

const SAVE_ROOT_DIR := "user://save"
const UNIVERSE_SAVE_ROOT_DIR := "user://save/universes"
const LEGACY_SAVE_PATH := "res://save/universe_save.json"
const SAVE_VERSION := 3
const UNIVERSE_META_SCHEMA_VERSION := 1
const EVENT_RUNTIME_SAVE_FILE := "event_runtime.json"
const INVENTORY_RUNTIME_SAVE_FILE := "inventory_runtime.json"
const INTEL_DISCOVERY_SAVE_FILE := "intel_discovery.json"
const ENEMY_INTEL_SAVE_FILE := "enemy_intel.json"
const IntelDiscoveryHandlerScript = preload("res://save/intel_discovery_handler.gd")
const EnemyIntelHandlerScript = preload("res://save/enemy_intel_handler.gd")

var intel_handler = IntelDiscoveryHandlerScript.new()
var enemy_intel_handler = EnemyIntelHandlerScript.new()


func _init() -> void:
	if intel_handler != null and intel_handler.has_method("setup"):
		intel_handler.setup(self)
	if enemy_intel_handler != null and enemy_intel_handler.has_method("setup"):
		enemy_intel_handler.setup(self)


func set_intel_handler(handler) -> void:
	intel_handler = handler
	if intel_handler != null and intel_handler.has_method("setup"):
		intel_handler.setup(self)


func get_intel_handler():
	return intel_handler


func set_enemy_intel_handler(handler) -> void:
	enemy_intel_handler = handler
	if enemy_intel_handler != null and enemy_intel_handler.has_method("setup"):
		enemy_intel_handler.setup(self)


func get_enemy_intel_handler():
	return enemy_intel_handler


func get_active_universe_id() -> String:
	var universe_id := str(Globals.active_universe_id).strip_edges()
	if universe_id == "":
		universe_id = "universe_1"
	return universe_id


func get_active_universe_display_name() -> String:
	var display_name := str(Globals.active_universe_display_name).strip_edges()
	if display_name == "":
		display_name = get_active_universe_id()
	return display_name


func get_active_universe_save_lane() -> String:
	var lane := str(Globals.active_universe_save_lane).strip_edges()
	if lane == "":
		lane = get_active_universe_id()
	return sanitize_slot_fragment(lane, 72)


func get_active_save_dir() -> String:
	return UNIVERSE_SAVE_ROOT_DIR + "/" + get_active_universe_save_lane()


func get_active_named_save_dir() -> String:
	return get_active_save_dir() + "/named"


func get_active_backup_save_dir() -> String:
	return get_active_save_dir() + "/backups"


func get_active_save_path() -> String:
	return get_active_save_dir() + "/universe_save.json"


func get_active_event_runtime_save_path() -> String:
	return get_active_save_dir() + "/" + EVENT_RUNTIME_SAVE_FILE


func get_active_inventory_runtime_save_path() -> String:
	return get_active_save_dir() + "/" + INVENTORY_RUNTIME_SAVE_FILE


func get_active_intel_save_path() -> String:
	return get_active_save_dir() + "/" + INTEL_DISCOVERY_SAVE_FILE


func get_active_enemy_intel_save_path() -> String:
	return get_active_save_dir() + "/" + ENEMY_INTEL_SAVE_FILE


func get_active_save_manifest_path() -> String:
	return get_active_save_dir() + "/save_manifest.json"


func get_active_autosave_backup_before_named_load_path() -> String:
	return get_active_backup_save_dir() + "/autosave_backup_before_named_load.json"


func build_active_universe_meta() -> Dictionary:
	return {
		"schema_version": UNIVERSE_META_SCHEMA_VERSION,
		"universe_id": get_active_universe_id(),
		"display_name": get_active_universe_display_name(),
		"events_dir": str(Globals.active_universe_events_dir).strip_edges(),
		"world_seeds_dir": str(Globals.active_universe_world_seeds_dir).strip_edges(),
		"save_lane": get_active_universe_save_lane(),
		"autosave_path": get_active_save_path(),
		"named_save_dir": get_active_named_save_dir(),
		"updated_at_unix": int(Time.get_unix_time_from_system()),
		"updated_at_text": get_current_datetime_text()
	}


func attach_active_universe_meta(save_data: Dictionary) -> Dictionary:
	var meta := build_active_universe_meta()
	if save_data.has("universe_meta") and typeof(save_data.get("universe_meta")) == TYPE_DICTIONARY:
		var existing_meta: Dictionary = save_data.get("universe_meta", {})
		meta["created_at_unix"] = int(existing_meta.get("created_at_unix", int(Time.get_unix_time_from_system())))
		meta["created_at_text"] = str(existing_meta.get("created_at_text", get_current_datetime_text()))
	else:
		meta["created_at_unix"] = int(Time.get_unix_time_from_system())
		meta["created_at_text"] = get_current_datetime_text()

	save_data["universe_meta"] = meta
	return save_data


func get_save_data_universe_id(save_data: Dictionary) -> String:
	var meta = save_data.get("universe_meta", {})
	if typeof(meta) == TYPE_DICTIONARY:
		return str(meta.get("universe_id", "")).strip_edges()
	return ""


func save_data_matches_active_universe(save_data: Dictionary, allow_missing_meta: bool = true) -> bool:
	var saved_universe_id := get_save_data_universe_id(save_data)
	if saved_universe_id == "":
		return allow_missing_meta
	return saved_universe_id == get_active_universe_id()


func debug_print_active_save_lane(reason: String = "") -> void:
	if not Globals.print_priority_2:
		return
	print("[UNIVERSE_LANE_SAVE] reason=", reason, " universe_id=", get_active_universe_id(), " save_lane=", get_active_universe_save_lane())
	print("[UNIVERSE_LANE_SAVE] autosave=", get_active_save_path())
	print("[UNIVERSE_LANE_SAVE] named_dir=", get_active_named_save_dir())
	print("[UNIVERSE_LANE_SAVE] manifest=", get_active_save_manifest_path())



# ==========================================================
# DOES SAVE EXIST
# ==========================================================
func has_save() -> bool:
	return get_readable_universe_save_path() != ""


func can_read_legacy_res_save() -> bool:
	return OS.has_feature("editor")


func get_readable_universe_save_path() -> String:
	var active_path := get_active_save_path()
	if FileAccess.file_exists(active_path):
		return active_path
	return ""


func migrate_legacy_res_save_to_user_if_needed() -> bool:
	# Fresh universe lane pass: intentionally no legacy/global autosave migration.
	# The old user://save/universe_save.json lane is ignored so Universe 1 starts clean.
	return false


# ==========================================================
# SAVE ALL GAME DATA
# ==========================================================
func save_universe(
	star_field: StarField,
	map: Map,
	space_objects: Space_Objects,
	inventory: Inventory5,
	enemy_handler: EnemyHandler,
	npc_handler: NPCHandler = null,
	beacons_ref: Beacons = null,
	game_event_handler = null,
	planets_ref: Planets = null,
	player_state_ref: PlayerState = null
) -> bool:
	var inventory_data := {}

	if inventory != null:
		inventory_data = inventory.get_save_data()
	else:
		push_error("SaveManager.save_universe() received null inventory.")
		return false

	return save_universe_with_inventory_data(
		star_field,
		map,
		space_objects,
		inventory_data,
		enemy_handler,
		npc_handler,
		beacons_ref,
		[],
		[],
		[],
		game_event_handler,
		planets_ref,
		[],
		player_state_ref
	)

func is_universe_save_shape_valid(data) -> bool:
	# Summary: Confirm save data has the required top-level universe sections before loading.
	if typeof(data) != TYPE_DICTIONARY:
		if Globals.print_priority_7:
			print("Universe save rejected - root data is not a Dictionary.")
		return false

	# ------------------------------------------------------
	# These sections are required for a complete universe save.
	# Enemy-only or partial packets should force a clean rebuild.
	# ------------------------------------------------------
	var required_sections := ["stars", "map", "space_objects", "inventory"]
	for section_name in required_sections:
		if not data.has(section_name):
			if Globals.print_priority_7:
				print("Universe save rejected - missing section: ", section_name)
			return false

	return true


# ==========================================================
# LOAD ALL GAME DATA
# ==========================================================
func load_universe(
	star_field: StarField,
	map: Map,
	space_objects: Space_Objects,
	inventory: Inventory5,
	enemy_handler: EnemyHandler,
	npc_handler: NPCHandler = null,
	beacons_ref: Beacons = null,
	planets_ref: Planets = null,
	player_state_ref: PlayerState = null
) -> bool:
	if not has_save():
		if Globals.print_priority_7:
			print("No save file found.")
		return false

	var data := read_universe_save_data()

	if not is_universe_save_shape_valid(data):
		return false

	if Globals.print_priority_2:
		print("SaveManager v3 load path active. Save version: ", data.get("save_version", "missing"))

	load_intel_companion_data_for_active_lane()
	if inventory != null and inventory.has_method("set_intel_handler"):
		inventory.set_intel_handler(intel_handler)
	if enemy_handler != null and enemy_handler.has_method("set_enemy_intel_handler"):
		enemy_handler.set_enemy_intel_handler(enemy_intel_handler)

	if data.has("stars"):
		star_field.load_from_save_data(data["stars"])

	if data.has("map"):
		map.load_from_save_data(data["map"])

	if data.has("space_objects"):
		if typeof(data["space_objects"]) == TYPE_ARRAY:
			space_objects.load_save_data(data["space_objects"])
		else:
			if Globals.print_priority_7:
				print("Saved space objects were invalid. Rebuilding from stars.")
			space_objects.generate_from_stars(star_field, 3)
	else:
		if Globals.print_priority_7:
			print("No saved space objects found. Rebuilding from stars.")
		space_objects.generate_from_stars(star_field, 3)

	if Globals.print_priority_2:
		print("Universe loaded from: " + get_readable_universe_save_path())
	
	if data.has("inventory"):
		if typeof(data["inventory"]) == TYPE_DICTIONARY:
			inventory.load_save_data(data["inventory"])
		else:
			if Globals.print_priority_7:
				print("Saved inventory was invalid.")
	else:
		if Globals.print_priority_7:
			print("No saved inventory found.")
		
	if data.has("enemies"):
		var enemy_save_packet = data["enemies"]
		if typeof(enemy_save_packet) == TYPE_ARRAY:
			enemy_save_packet = {"enemies": enemy_save_packet}

		if enemy_handler.has_method("from_save_data"):
			if Globals.print_priority_2:
				print("Loading enemies through EnemyHandler.from_save_data.")
			enemy_handler.from_save_data(enemy_save_packet)
		else:
			if Globals.print_priority_7:
				print("Enemy load failed - enemy_handler has no from_save_data method.")
		if Globals.print_priority_2:
			print("Enemies loaded.")
	else:
		if Globals.print_priority_7:
			print("No saved enemies found. Rebuilding from stars.")
		if enemy_handler.has_method("generate_from_stars"):
			enemy_handler.generate_from_stars(star_field)

	if npc_handler != null:
		if data.has("npcs"):
			if typeof(data["npcs"]) == TYPE_ARRAY and npc_handler.has_method("load_from_data"):
				npc_handler.load_from_data(data["npcs"])
				if Globals.print_priority_2:
					print("NPCs loaded.")
			else:
				if Globals.print_priority_7:
					print("NPC load failed - npc_handler has no load_from_data method.")
		else:
			if Globals.print_priority_7:
				print("No saved NPCs found. Rebuilding from stars.")
			if npc_handler.has_method("generate_from_stars"):
				npc_handler.generate_from_stars(star_field)

	if beacons_ref != null:
		if data.has("beacons") and typeof(data["beacons"]) == TYPE_ARRAY and beacons_ref.has_method("load_save_data"):
			beacons_ref.load_save_data(data["beacons"])
			if Globals.print_priority_2:
				print("Beacons loaded.")
		else:
			if Globals.print_priority_7:
				print("No saved beacons found. Rebuilding from stars.")
			if beacons_ref.has_method("generate_from_stars"):
				beacons_ref.generate_from_stars(star_field, 35)

	if planets_ref != null:
		if data.has("planets") and typeof(data["planets"]) == TYPE_ARRAY and planets_ref.has_method("load_save_data"):
			planets_ref.load_save_data(data["planets"])
			if Globals.print_priority_2:
				print("Planets loaded.")
		else:
			if Globals.print_priority_7:
				print("No saved planets found. Rebuilding from stars.")
			if planets_ref.has_method("generate_from_stars"):
				planets_ref.generate_from_stars(star_field)


	if player_state_ref != null:
		if data.has("player_state") and typeof(data["player_state"]) == TYPE_DICTIONARY and player_state_ref.has_method("load_save_data"):
			player_state_ref.load_save_data(data["player_state"])
			if Globals.print_priority_2:
				print("PlayerState loaded.")
		else:
			if Globals.print_priority_7:
				print("No saved PlayerState found. Using defaults.")

	return true


func save_universe_with_inventory_data(
	star_field: StarField,
	map: Map,
	space_objects: Space_Objects,
	inventory_data: Dictionary,
	enemy_handler: EnemyHandler,
	npc_handler: NPCHandler = null,
	beacons_ref: Beacons = null,
	npc_snapshot_data: Array = [],
	beacon_snapshot_data: Array = [],
	space_object_snapshot_data: Array = [],
	game_event_handler = null,
	planets_ref: Planets = null,
	planet_snapshot_data: Array = [],
	player_state_ref: PlayerState = null,
	player_state_snapshot_data: Dictionary = {}
) -> bool:
	# Summary: Save full universe after Battle V2 using safe snapshot data for scene-switch fragile sections.
	var existing_save := read_universe_save_data()
	var safe_inventory_data := inventory_data.duplicate(true)

	var space_object_save_data := resolve_space_object_save_data(
		existing_save,
		space_objects,
		space_object_snapshot_data
	)

	var npc_save_data := resolve_npc_save_data(
		existing_save,
		npc_handler,
		npc_snapshot_data
	)

	var beacon_save_data := resolve_beacon_save_data(
		existing_save,
		beacons_ref,
		beacon_snapshot_data
	)

	var planet_save_data := resolve_planet_save_data(
		existing_save,
		planets_ref,
		planet_snapshot_data
	)

	var game_events_save_data := resolve_game_events_save_data(
		existing_save,
		game_event_handler
	)

	var scan_state_save_data := resolve_scan_state_save_data(existing_save)

	var player_state_save_data := resolve_player_state_save_data(
		existing_save,
		player_state_ref,
		player_state_snapshot_data
	)
	var runtime_migrations := get_runtime_migrations_from_data(existing_save)

	var save_data = {
		"save_version": SAVE_VERSION,
		"stars": star_field.to_save_data(),
		"map": map.to_save_data(),
		"space_objects": space_object_save_data,
		"inventory": safe_inventory_data,
		"enemies": enemy_handler.to_save_data(),
		"npcs": npc_save_data,
		"beacons": beacon_save_data,
		"planets": planet_save_data,
		"game_events": game_events_save_data,
		"scan_state": scan_state_save_data,
		"player_state": player_state_save_data,
		"runtime_migrations": runtime_migrations
	}

	var saved_ok := write_universe_save_data(save_data)
	if saved_ok:
		save_intel_companion_data_for_active_lane()
	return saved_ok
	
	
	
func write_universe_save_data(save_data: Dictionary) -> bool:
	if save_data.has("universe_meta") and not save_data_matches_active_universe(save_data, false):
		push_error("SaveManager.write_universe_save_data blocked: incoming save universe_meta does not match active universe lane.")
		if Globals.print_priority_2:
			print("[UNIVERSE_LANE_BLOCKED] write active=", get_active_universe_id(), " incoming_saved=", get_save_data_universe_id(save_data), " path=", get_active_save_path())
		return false

	attach_active_universe_meta(save_data)

	var active_path := get_active_save_path()
	var ok := write_json_dictionary_to_path(active_path, save_data)
	if not ok:
		push_error("Could not open save file for writing.")
		return false

	if Globals.print_priority_2:
		print("[UNIVERSE_LANE_SAVE] Universe saved to: " + active_path)

	save_runtime_companion_sections_from_universe_data(save_data)
	return true


func ensure_save_dirs() -> bool:
	for dir_path in [SAVE_ROOT_DIR, UNIVERSE_SAVE_ROOT_DIR, get_active_save_dir(), get_active_named_save_dir(), get_active_backup_save_dir()]:
		var err := DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK and err != ERR_ALREADY_EXISTS:
			push_error("SaveManager.ensure_save_dirs() failed for " + dir_path + " err=" + str(err))
			return false

	return true


func delete_active_autosave() -> Dictionary:
	# Summary: Remove only the active universe autosave. Named saves and backups are intentionally untouched.
	var autosave_path := get_active_save_path()
	var companion_delete_results := delete_active_companion_files()
	if autosave_path.strip_edges() == "":
		return {
			"ok": false,
			"deleted": false,
			"path": autosave_path,
			"companions": companion_delete_results,
			"reason": "missing autosave path"
		}

	if not FileAccess.file_exists(autosave_path):
		return {
			"ok": true,
			"deleted": false,
			"path": autosave_path,
			"companions": companion_delete_results,
			"reason": "autosave already missing"
		}

	var err := DirAccess.remove_absolute(autosave_path)
	var ok := err == OK
	if not ok:
		push_error("SaveManager.delete_active_autosave() failed for " + autosave_path + " err=" + str(err))

	return {
		"ok": ok,
		"deleted": ok,
		"path": autosave_path,
		"companions": companion_delete_results,
		"error": err
	}


func read_json_dictionary_from_path(path: String) -> Dictionary:
	var clean_path := path.strip_edges()
	if clean_path == "" or not FileAccess.file_exists(clean_path):
		return {}

	var file := FileAccess.open(clean_path, FileAccess.READ)
	if file == null:
		if Globals.print_priority_7:
			print("SaveManager.read_json_dictionary_from_path blocked: open read failed: ", clean_path)
		return {}

	var raw_text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(raw_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		if Globals.print_priority_7:
			print("SaveManager.read_json_dictionary_from_path blocked: JSON was not Dictionary: ", clean_path)
		return {}

	return parsed


func apply_runtime_companion_snapshots_to_universe_data(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)

	var event_runtime := read_event_runtime_save_data()
	if not event_runtime.is_empty():
		out["game_events"] = event_runtime

	var inventory_runtime := read_inventory_runtime_save_data()
	if not inventory_runtime.is_empty():
		out["inventory"] = inventory_runtime

	return out


func get_runtime_migrations_from_data(data: Dictionary) -> Dictionary:
	var migrations = data.get("runtime_migrations", {})
	if typeof(migrations) == TYPE_DICTIONARY:
		return migrations.duplicate(true)
	return {}


func has_runtime_migration(migration_id: String) -> bool:
	var clean_id := migration_id.strip_edges()
	if clean_id == "":
		return false
	var data := read_universe_save_data()
	if data.is_empty():
		return false
	return get_runtime_migrations_from_data(data).has(clean_id)


func mark_runtime_migration(migration_id: String, details: Dictionary = {}) -> bool:
	var clean_id := migration_id.strip_edges()
	if clean_id == "":
		return false

	var data := read_universe_save_data()
	if data.is_empty():
		return false

	var migrations := get_runtime_migrations_from_data(data)
	var payload := details.duplicate(true)
	payload["migration_id"] = clean_id
	payload["applied_at_unix"] = int(Time.get_unix_time_from_system())
	payload["applied_at_text"] = get_current_datetime_text()
	migrations[clean_id] = payload
	data["runtime_migrations"] = migrations

	return write_universe_save_data(data)


func write_json_dictionary_to_path(path: String, data: Dictionary) -> bool:
	if not ensure_save_dirs():
		return false

	var clean_path := path.strip_edges()
	if clean_path == "":
		return false

	var json_text = JSON.stringify(data, "\t")
	var file := FileAccess.open(clean_path, FileAccess.WRITE)
	if file == null:
		if Globals.print_priority_7:
			print("SaveManager.write_json_dictionary_to_path blocked: open write failed: ", clean_path)
		return false

	file.store_string(json_text)
	file.close()
	return true


func get_empty_intel_save_data() -> Dictionary:
	if intel_handler != null and intel_handler.has_method("get_empty_save_data"):
		var data = intel_handler.get_empty_save_data()
		if typeof(data) == TYPE_DICTIONARY:
			return data.duplicate(true)
	return {
		"schema_version": 1,
		"entries": {},
		"enemy_defeats": {}
	}


func get_empty_enemy_intel_save_data() -> Dictionary:
	if enemy_intel_handler != null and enemy_intel_handler.has_method("get_empty_save_data"):
		var data = enemy_intel_handler.get_empty_save_data()
		if typeof(data) == TYPE_DICTIONARY:
			return data.duplicate(true)
	return {
		"schema_version": 1,
		"next_serial_index": 1,
		"spawned_enemies": {},
		"defeated_enemy_serials": {},
		"defeated_counts_by_display_name": {},
		"event_enemy_serials": {}
	}


func read_event_runtime_save_data() -> Dictionary:
	return read_json_dictionary_from_path(get_active_event_runtime_save_path())


func read_inventory_runtime_save_data() -> Dictionary:
	return read_json_dictionary_from_path(get_active_inventory_runtime_save_path())


func read_intel_save_data() -> Dictionary:
	var data := read_json_dictionary_from_path(get_active_intel_save_path())
	if data.is_empty():
		return get_empty_intel_save_data()
	return data


func read_enemy_intel_save_data() -> Dictionary:
	var data := read_json_dictionary_from_path(get_active_enemy_intel_save_path())
	if data.is_empty():
		return get_empty_enemy_intel_save_data()
	return data


func write_intel_save_data(data: Dictionary) -> bool:
	return write_json_dictionary_to_path(get_active_intel_save_path(), data.duplicate(true))


func write_enemy_intel_save_data(data: Dictionary) -> bool:
	return write_json_dictionary_to_path(get_active_enemy_intel_save_path(), data.duplicate(true))


func write_event_runtime_save_data(data: Dictionary) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.is_empty():
		return false
	return write_json_dictionary_to_path(get_active_event_runtime_save_path(), data.duplicate(true))


func write_inventory_runtime_save_data(data: Dictionary) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.is_empty():
		return false
	return write_json_dictionary_to_path(get_active_inventory_runtime_save_path(), data.duplicate(true))


func save_game_events_section_from_data(game_events_data: Dictionary) -> bool:
	return write_event_runtime_save_data(game_events_data)


func save_inventory_runtime_section_from_data(inventory_data: Dictionary) -> bool:
	return write_inventory_runtime_save_data(inventory_data)


func save_event_reward_runtime_sections(game_events_data: Dictionary, inventory_data: Dictionary) -> bool:
	var ok := true
	ok = write_event_runtime_save_data(game_events_data) and ok
	ok = write_inventory_runtime_save_data(inventory_data) and ok
	ok = save_intel_companion_data_for_active_lane() and ok
	return ok


func save_runtime_companion_sections_from_universe_data(save_data: Dictionary) -> bool:
	var ok := true
	var game_events = save_data.get("game_events", {})
	if typeof(game_events) == TYPE_DICTIONARY and not game_events.is_empty():
		ok = write_event_runtime_save_data(game_events) and ok

	var inventory_data = save_data.get("inventory", {})
	if typeof(inventory_data) == TYPE_DICTIONARY and not inventory_data.is_empty():
		ok = write_inventory_runtime_save_data(inventory_data) and ok

	return ok


func load_intel_companion_data_for_active_lane() -> void:
	if intel_handler != null and intel_handler.has_method("load_save_data"):
		intel_handler.load_save_data(read_intel_save_data())
	if enemy_intel_handler != null and enemy_intel_handler.has_method("load_save_data"):
		enemy_intel_handler.load_save_data(read_enemy_intel_save_data())


func save_intel_companion_data_for_active_lane() -> bool:
	var ok := true
	if intel_handler != null and intel_handler.has_method("to_save_data"):
		ok = write_intel_save_data(intel_handler.to_save_data()) and ok
	if enemy_intel_handler != null and enemy_intel_handler.has_method("to_save_data"):
		ok = write_enemy_intel_save_data(enemy_intel_handler.to_save_data()) and ok
	return ok


func get_named_companion_save_path(slot_id: String, companion_name: String) -> String:
	var clean_slot := sanitize_slot_fragment(slot_id, 96)
	var clean_companion := sanitize_slot_fragment(companion_name, 48)
	return get_active_named_save_dir() + "/" + clean_slot + "." + clean_companion + ".json"


func get_named_event_runtime_save_path(slot_id: String) -> String:
	return get_named_companion_save_path(slot_id, "event_runtime")


func get_named_inventory_runtime_save_path(slot_id: String) -> String:
	return get_named_companion_save_path(slot_id, "inventory_runtime")


func get_named_intel_save_path(slot_id: String) -> String:
	return get_named_companion_save_path(slot_id, "intel_discovery")


func get_named_enemy_intel_save_path(slot_id: String) -> String:
	return get_named_companion_save_path(slot_id, "enemy_intel")


func copy_json_companion_file(source_path: String, target_path: String, fallback_data: Dictionary) -> bool:
	var data := read_json_dictionary_from_path(source_path)
	if data.is_empty():
		data = fallback_data.duplicate(true)
	return write_json_dictionary_to_path(target_path, data)


func copy_active_companion_files_to_named(slot_id: String) -> Dictionary:
	var active_save := read_universe_save_data()
	var event_runtime = active_save.get("game_events", get_empty_game_events_save_data())
	if typeof(event_runtime) != TYPE_DICTIONARY:
		event_runtime = get_empty_game_events_save_data()
	if not event_runtime.is_empty():
		write_event_runtime_save_data(event_runtime)

	var inventory_runtime = active_save.get("inventory", {})
	if typeof(inventory_runtime) != TYPE_DICTIONARY:
		inventory_runtime = {}
	if not inventory_runtime.is_empty():
		write_inventory_runtime_save_data(inventory_runtime)

	if intel_handler != null and intel_handler.has_method("to_save_data"):
		write_intel_save_data(intel_handler.to_save_data())
	if enemy_intel_handler != null and enemy_intel_handler.has_method("to_save_data"):
		write_enemy_intel_save_data(enemy_intel_handler.to_save_data())

	var event_ok := copy_json_companion_file(
		get_active_event_runtime_save_path(),
		get_named_event_runtime_save_path(slot_id),
		event_runtime
	)
	var inventory_ok := copy_json_companion_file(
		get_active_inventory_runtime_save_path(),
		get_named_inventory_runtime_save_path(slot_id),
		inventory_runtime
	)
	var intel_ok := copy_json_companion_file(
		get_active_intel_save_path(),
		get_named_intel_save_path(slot_id),
		get_empty_intel_save_data()
	)
	var enemy_ok := copy_json_companion_file(
		get_active_enemy_intel_save_path(),
		get_named_enemy_intel_save_path(slot_id),
		get_empty_enemy_intel_save_data()
	)
	return {
		"ok": event_ok and inventory_ok and intel_ok and enemy_ok,
		"event_runtime_path": get_named_event_runtime_save_path(slot_id),
		"inventory_runtime_path": get_named_inventory_runtime_save_path(slot_id),
		"intel_path": get_named_intel_save_path(slot_id),
		"enemy_intel_path": get_named_enemy_intel_save_path(slot_id),
		"event_ok": event_ok,
		"inventory_ok": inventory_ok,
		"intel_ok": intel_ok,
		"enemy_intel_ok": enemy_ok
	}


func copy_named_companion_files_to_active(slot_id: String) -> Dictionary:
	var named_snapshot := read_json_dictionary_from_path(get_named_save_path(slot_id))
	var event_fallback = named_snapshot.get("game_events", get_empty_game_events_save_data())
	if typeof(event_fallback) != TYPE_DICTIONARY:
		event_fallback = get_empty_game_events_save_data()
	var inventory_fallback = named_snapshot.get("inventory", {})
	if typeof(inventory_fallback) != TYPE_DICTIONARY:
		inventory_fallback = {}

	var event_ok := copy_json_companion_file(
		get_named_event_runtime_save_path(slot_id),
		get_active_event_runtime_save_path(),
		event_fallback
	)
	var inventory_ok := copy_json_companion_file(
		get_named_inventory_runtime_save_path(slot_id),
		get_active_inventory_runtime_save_path(),
		inventory_fallback
	)
	var intel_ok := copy_json_companion_file(
		get_named_intel_save_path(slot_id),
		get_active_intel_save_path(),
		get_empty_intel_save_data()
	)
	var enemy_ok := copy_json_companion_file(
		get_named_enemy_intel_save_path(slot_id),
		get_active_enemy_intel_save_path(),
		get_empty_enemy_intel_save_data()
	)
	if intel_ok and enemy_ok:
		load_intel_companion_data_for_active_lane()
	return {
		"ok": event_ok and inventory_ok and intel_ok and enemy_ok,
		"event_runtime_path": get_active_event_runtime_save_path(),
		"inventory_runtime_path": get_active_inventory_runtime_save_path(),
		"intel_path": get_active_intel_save_path(),
		"enemy_intel_path": get_active_enemy_intel_save_path(),
		"event_ok": event_ok,
		"inventory_ok": inventory_ok,
		"intel_ok": intel_ok,
		"enemy_intel_ok": enemy_ok
	}


func delete_active_companion_files() -> Dictionary:
	var result := {}
	for path in [
		get_active_event_runtime_save_path(),
		get_active_inventory_runtime_save_path(),
		get_active_intel_save_path(),
		get_active_enemy_intel_save_path()
	]:
		if not FileAccess.file_exists(path):
			result[path] = {"deleted": false, "reason": "already missing"}
			continue
		var err := DirAccess.remove_absolute(path)
		result[path] = {"deleted": err == OK, "error": err}
	return result


func get_empty_named_save_manifest() -> Dictionary:
	return {
		"schema_version": 1,
		"storage_root": get_active_save_dir(),
		"autosave_path": get_active_save_path(),
		"universe_meta": build_active_universe_meta(),
		"slots": [],
		"updated_at_unix": 0,
		"updated_at_text": ""
	}


func read_named_save_manifest() -> Dictionary:
	var manifest := read_json_dictionary_from_path(get_active_save_manifest_path())
	if manifest.is_empty():
		return get_empty_named_save_manifest()

	if typeof(manifest.get("slots", [])) != TYPE_ARRAY:
		manifest["slots"] = []

	if not manifest.has("schema_version"):
		manifest["schema_version"] = 1
	manifest["storage_root"] = get_active_save_dir()
	manifest["autosave_path"] = get_active_save_path()
	manifest["universe_meta"] = build_active_universe_meta()

	return manifest


func write_named_save_manifest(manifest: Dictionary) -> bool:
	var manifest_data := manifest.duplicate(true)
	manifest_data["schema_version"] = int(manifest_data.get("schema_version", 1))
	manifest_data["storage_root"] = get_active_save_dir()
	manifest_data["autosave_path"] = get_active_save_path()
	manifest_data["universe_meta"] = build_active_universe_meta()
	manifest_data["updated_at_unix"] = int(Time.get_unix_time_from_system())
	manifest_data["updated_at_text"] = get_current_datetime_text()
	if typeof(manifest_data.get("slots", [])) != TYPE_ARRAY:
		manifest_data["slots"] = []

	return write_json_dictionary_to_path(get_active_save_manifest_path(), manifest_data)


func sanitize_named_save_display_name(display_name: String) -> String:
	var clean := display_name.strip_edges()
	clean = clean.replace("\n", " ")
	clean = clean.replace("\r", " ")
	clean = clean.replace("\t", " ")
	while clean.find("  ") != -1:
		clean = clean.replace("  ", " ")
	if clean.length() > 64:
		clean = clean.substr(0, 64).strip_edges()
	return clean


func sanitize_slot_fragment(text: String, max_length: int = 72) -> String:
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


func make_named_save_slot_id(display_name: String) -> String:
	var clean_name := sanitize_slot_fragment(display_name, 24)
	var date := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d_%02d%02d%02d" % [
		int(date.get("year", 0)),
		int(date.get("month", 0)),
		int(date.get("day", 0)),
		int(date.get("hour", 0)),
		int(date.get("minute", 0)),
		int(date.get("second", 0))
	]
	return clean_name + "_" + stamp + "_" + str(Time.get_ticks_msec())


func get_current_datetime_text() -> String:
	var date := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(date.get("year", 0)),
		int(date.get("month", 0)),
		int(date.get("day", 0)),
		int(date.get("hour", 0)),
		int(date.get("minute", 0)),
		int(date.get("second", 0))
	]


func get_named_save_path(slot_id: String) -> String:
	return get_active_named_save_dir() + "/" + sanitize_slot_fragment(slot_id, 96) + ".json"


func create_named_save_from_current_autosave(display_name: String, summary: String = "") -> Dictionary:
	var clean_name := sanitize_named_save_display_name(display_name)
	if clean_name == "":
		return {
			"ok": false,
			"reason": "Enter a save name first."
		}

	var autosave := read_universe_save_data()
	if autosave.is_empty() or not is_universe_save_shape_valid(autosave):
		return {
			"ok": false,
			"reason": "Current autosave is missing or invalid."
		}

	var slot_id := make_named_save_slot_id(clean_name)
	var slot_path := get_named_save_path(slot_id)
	var now_unix := int(Time.get_unix_time_from_system())
	var now_text := get_current_datetime_text()
	var save_summary := summary.strip_edges()
	if save_summary.length() > 120:
		save_summary = save_summary.substr(0, 120).strip_edges()

	var snapshot := autosave.duplicate(true)
	snapshot["named_save_meta"] = {
		"slot_id": slot_id,
		"display_name": clean_name,
		"summary": save_summary,
		"created_at_unix": now_unix,
		"created_at_text": now_text,
		"source_autosave_path": get_active_save_path(),
		"storage_mode": "user",
		"universe_id": get_active_universe_id(),
		"save_lane": get_active_universe_save_lane()
	}

	if not write_json_dictionary_to_path(slot_path, snapshot):
		return {
			"ok": false,
			"reason": "Could not write named save file."
		}

	var companion_result := copy_active_companion_files_to_named(slot_id)
	if not bool(companion_result.get("ok", false)):
		return {
			"ok": false,
			"reason": "Named save was written, but its companion files failed to copy.",
			"slot_id": slot_id,
			"path": slot_path,
			"companions": companion_result
		}

	var manifest := read_named_save_manifest()
	var slots: Array = manifest.get("slots", [])
	slots.append({
		"slot_id": slot_id,
		"display_name": clean_name,
		"summary": save_summary,
		"path": slot_path,
		"event_runtime_path": str(companion_result.get("event_runtime_path", "")),
		"inventory_runtime_path": str(companion_result.get("inventory_runtime_path", "")),
		"intel_path": str(companion_result.get("intel_path", "")),
		"enemy_intel_path": str(companion_result.get("enemy_intel_path", "")),
		"created_at_unix": now_unix,
		"created_at_text": now_text,
		"save_version": int(autosave.get("save_version", SAVE_VERSION)),
		"universe_id": get_active_universe_id(),
		"save_lane": get_active_universe_save_lane()
	})
	manifest["slots"] = slots

	if not write_named_save_manifest(manifest):
		return {
			"ok": false,
			"reason": "Named save was written, but the manifest failed to update.",
			"slot_id": slot_id,
			"path": slot_path
		}

	return {
		"ok": true,
		"slot_id": slot_id,
		"path": slot_path,
		"display_name": clean_name,
		"created_at_text": now_text
	}


func list_named_save_slots() -> Array:
	var manifest := read_named_save_manifest()
	var slots: Array = manifest.get("slots", [])
	var visible_slots := []

	for slot in slots:
		if typeof(slot) != TYPE_DICTIONARY:
			continue

		var slot_copy = slot.duplicate(true)
		var slot_path := str(slot_copy.get("path", "")).strip_edges()
		if slot_path == "":
			slot_path = get_named_save_path(str(slot_copy.get("slot_id", "")))
			slot_copy["path"] = slot_path

		if FileAccess.file_exists(slot_path):
			visible_slots.append(slot_copy)

	visible_slots.sort_custom(func(a, b):
		return int(a.get("created_at_unix", 0)) > int(b.get("created_at_unix", 0))
	)

	return visible_slots


func get_named_save_slot(slot_id: String) -> Dictionary:
	var clean_slot_id := slot_id.strip_edges()
	if clean_slot_id == "":
		return {}

	for slot in list_named_save_slots():
		if typeof(slot) == TYPE_DICTIONARY and str(slot.get("slot_id", "")) == clean_slot_id:
			return slot.duplicate(true)

	return {}


func read_named_save_snapshot(slot_id: String) -> Dictionary:
	var slot := get_named_save_slot(slot_id)
	if slot.is_empty():
		return {}

	var slot_path := str(slot.get("path", "")).strip_edges()
	if slot_path == "":
		return {}

	var snapshot := read_json_dictionary_from_path(slot_path)
	if snapshot.is_empty() or not is_universe_save_shape_valid(snapshot):
		return {}

	if not save_data_matches_active_universe(snapshot, false):
		if Globals.print_priority_2:
			print("[UNIVERSE_LANE_BLOCKED] named save snapshot wrong lane. active=", get_active_universe_id(), " saved=", get_save_data_universe_id(snapshot), " path=", slot_path)
		return {}

	return snapshot


func backup_current_autosave_before_named_load(slot_id: String) -> bool:
	if not has_save():
		return true

	var autosave := read_universe_save_data()
	if autosave.is_empty() or not is_universe_save_shape_valid(autosave):
		return false

	var backup := autosave.duplicate(true)
	backup["autosave_backup_meta"] = {
		"reason": "before_named_save_load",
		"requested_slot_id": slot_id,
		"created_at_unix": int(Time.get_unix_time_from_system()),
		"created_at_text": get_current_datetime_text()
	}

	return write_json_dictionary_to_path(get_active_autosave_backup_before_named_load_path(), backup)


func mark_named_save_loaded(slot_id: String) -> void:
	var manifest := read_named_save_manifest()
	var slots: Array = manifest.get("slots", [])
	var now_unix := int(Time.get_unix_time_from_system())
	var now_text := get_current_datetime_text()

	for i in range(slots.size()):
		if typeof(slots[i]) != TYPE_DICTIONARY:
			continue
		if str(slots[i].get("slot_id", "")) == slot_id:
			var slot: Dictionary = slots[i]
			slot["last_loaded_at_unix"] = now_unix
			slot["last_loaded_at_text"] = now_text
			slots[i] = slot
			break

	manifest["slots"] = slots
	write_named_save_manifest(manifest)


func promote_named_save_to_autosave(slot_id: String) -> Dictionary:
	var clean_slot_id := slot_id.strip_edges()
	if clean_slot_id == "":
		return {
			"ok": false,
			"reason": "Missing named save id."
		}

	var snapshot := read_named_save_snapshot(clean_slot_id)
	if snapshot.is_empty():
		return {
			"ok": false,
			"reason": "Named save file is missing or invalid."
		}

	if not backup_current_autosave_before_named_load(clean_slot_id):
		return {
			"ok": false,
			"reason": "Current autosave backup failed."
		}

	var snapshot_for_autosave := snapshot.duplicate(true)
	snapshot_for_autosave["promoted_named_save_meta"] = {
		"slot_id": clean_slot_id,
		"promoted_at_unix": int(Time.get_unix_time_from_system()),
		"promoted_at_text": get_current_datetime_text()
	}

	if not write_universe_save_data(snapshot_for_autosave):
		return {
			"ok": false,
			"reason": "Could not promote named save to autosave."
		}

	var companion_result := copy_named_companion_files_to_active(clean_slot_id)
	if not bool(companion_result.get("ok", false)):
		return {
			"ok": false,
			"reason": "Named save universe was promoted, but its companion files failed to promote.",
			"slot_id": clean_slot_id,
			"companions": companion_result
		}

	mark_named_save_loaded(clean_slot_id)

	return {
		"ok": true,
		"slot_id": clean_slot_id,
		"backup_path": get_active_autosave_backup_before_named_load_path(),
		"companions": companion_result
	}


func save_inventory_section_from_data(inventory_data: Dictionary) -> bool:
	# Summary: Update only the inventory section inside the existing universe save.

	var loaded_data := read_universe_save_data()

	if loaded_data.is_empty():
		if Globals.print_priority_7:
			print("SaveManager.save_inventory_section_from_data blocked: no save data.")
		return false

	loaded_data["inventory"] = inventory_data.duplicate(true)

	var ok := write_universe_save_data(loaded_data)

	if Globals.print_priority_2:
		print("SaveManager.save_inventory_section_from_data complete: ", ok)

	return ok
	
	
func read_universe_save_data() -> Dictionary:
	# Summary: Read current universe save JSON from disk.

	var save_path := get_readable_universe_save_path()
	if save_path == "":
		if Globals.print_priority_7:
			print("SaveManager.read_universe_save_data blocked: save file missing.")
		return {}

	var file := FileAccess.open(save_path, FileAccess.READ)

	if file == null:
		if Globals.print_priority_7:
			print("SaveManager.read_universe_save_data blocked: open read failed: ", save_path)
		return {}

	var raw_text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(raw_text)

	if typeof(parsed) != TYPE_DICTIONARY:
		if Globals.print_priority_7:
			print("SaveManager.read_universe_save_data blocked: JSON was not Dictionary: ", save_path)
		return {}

	if not save_data_matches_active_universe(parsed, true):
		if Globals.print_priority_2:
			print("[UNIVERSE_LANE_BLOCKED] read active=", get_active_universe_id(), " saved=", get_save_data_universe_id(parsed), " path=", save_path)
		return {}

	return apply_runtime_companion_snapshots_to_universe_data(parsed)


func save_scan_state(scan_state: Dictionary) -> bool:
	var loaded_data := read_universe_save_data()
	if loaded_data.is_empty():
		if Globals.print_priority_7:
			print("SaveManager.save_scan_state blocked: no save data.")
		return false

	loaded_data["scan_state"] = scan_state.duplicate(true)
	return write_universe_save_data(loaded_data)


func load_scan_state() -> Dictionary:
	var loaded_data := read_universe_save_data()
	if loaded_data.is_empty():
		return {}

	var scan_state = loaded_data.get("scan_state", {})
	if typeof(scan_state) == TYPE_DICTIONARY:
		return scan_state.duplicate(true)

	return {}
	
	
func save_npc_trade_state_from_result(result: Dictionary) -> bool:
	# Summary: Update one NPC's trade state inside the existing universe save.
	# Used by NPC_tran before scene switch back to main_mode.

	if result.is_empty():
		if Globals.print_priority_7:
			print("SaveManager.save_npc_trade_state_from_result blocked: empty result.")
		return false

	var loaded_data := read_universe_save_data()

	if loaded_data.is_empty():
		if Globals.print_priority_7:
			print("SaveManager.save_npc_trade_state_from_result blocked: no save data.")
		return false

	if not loaded_data.has("npcs"):
		if Globals.print_priority_7:
			print("SaveManager.save_npc_trade_state_from_result blocked: save has no npcs section.")
		return false

	var npcs_data: Array = loaded_data.get("npcs", [])

	var result_npc_id := str(result.get("npc_id", ""))
	var result_blueprint_id := str(result.get("blueprint_id", ""))

	if result_npc_id == "" and result_blueprint_id == "":
		if Globals.print_priority_7:
			print("SaveManager.save_npc_trade_state_from_result blocked: missing npc_id and blueprint_id.")
		return false

	var found := false

	for i in range(npcs_data.size()):
		var npc_data = npcs_data[i]

		if typeof(npc_data) != TYPE_DICTIONARY:
			continue

		var saved_npc_id := str(npc_data.get("npc_id", ""))
		var saved_blueprint_id := str(npc_data.get("blueprint_id", ""))

		var id_match := result_npc_id != "" and saved_npc_id == result_npc_id
		var blueprint_match := result_blueprint_id != "" and saved_blueprint_id == result_blueprint_id

		if not id_match and not blueprint_match:
			continue

		if result.has("can_trade"):
			npc_data["can_trade"] = bool(result["can_trade"])
			npc_data["trade"] = bool(result["can_trade"])

		if result.has("trade_completed"):
			npc_data["trade_completed"] = bool(result["trade_completed"])

		if result.has("has_met"):
			npc_data["has_met"] = bool(result["has_met"])

		if result.has("depopulate_after_meeting"):
			npc_data["depopulate_after_meeting"] = bool(result["depopulate_after_meeting"])

		npcs_data[i] = npc_data
		found = true
		break

	if not found:
		if Globals.print_priority_7:
			print("SaveManager.save_npc_trade_state_from_result failed: no matching NPC. result=", result)
		return false

	loaded_data["npcs"] = npcs_data

	var ok := write_universe_save_data(loaded_data)

	if Globals.print_priority_2:
		print("SaveManager.save_npc_trade_state_from_result complete: ", ok)

	return ok


func resolve_npc_save_data(existing_save: Dictionary, npc_handler: NPCHandler = null, npc_snapshot_data: Array = []) -> Array:
	# Summary: Prefer Battle V2 NPC snapshot, then live NPCHandler data, then existing save data.
	if not npc_snapshot_data.is_empty():
		if Globals.print_priority_7:
			print("[SaveManager.resolve_npc_save_data] source=snapshot count=", npc_snapshot_data.size())
		return npc_snapshot_data.duplicate(true)

	if npc_handler != null and npc_handler.has_method("to_save_data"):
		var live_data = npc_handler.to_save_data()

		if typeof(live_data) == TYPE_ARRAY and not live_data.is_empty():
			if Globals.print_priority_7:
				print("[SaveManager.resolve_npc_save_data] source=live count=", live_data.size())
			return live_data.duplicate(true)

	var existing_npcs = existing_save.get("npcs", [])

	if typeof(existing_npcs) == TYPE_ARRAY:
		if Globals.print_priority_7:
			print("[SaveManager.resolve_npc_save_data] source=existing_save count=", existing_npcs.size())
		return existing_npcs.duplicate(true)

	if Globals.print_priority_7:
		print("[SaveManager.resolve_npc_save_data] source=empty")

	return []


func resolve_space_object_save_data(existing_save: Dictionary, space_objects_ref: Space_Objects = null, space_object_snapshot_data: Array = []) -> Array:
	# Summary: Prefer Battle V2 space-object snapshot, then live Space_Objects data, then existing save data.
	if not space_object_snapshot_data.is_empty():
		if Globals.print_priority_7:
			print("[SaveManager.resolve_space_object_save_data] source=snapshot count=", space_object_snapshot_data.size())
		return space_object_snapshot_data.duplicate(true)

	if space_objects_ref != null and space_objects_ref.has_method("get_save_data"):
		var live_data = space_objects_ref.get_save_data()

		if typeof(live_data) == TYPE_ARRAY and not live_data.is_empty():
			if Globals.print_priority_7:
				print("[SaveManager.resolve_space_object_save_data] source=live count=", live_data.size())
			return live_data.duplicate(true)

	var existing_space_objects = existing_save.get("space_objects", [])

	if typeof(existing_space_objects) == TYPE_ARRAY:
		if Globals.print_priority_7:
			print("[SaveManager.resolve_space_object_save_data] source=existing_save count=", existing_space_objects.size())
		return existing_space_objects.duplicate(true)

	if Globals.print_priority_7:
		print("[SaveManager.resolve_space_object_save_data] source=empty")

	return []


func resolve_beacon_save_data(existing_save: Dictionary, beacons_ref: Beacons = null, beacon_snapshot_data: Array = []) -> Array:
	# Summary: Prefer Battle V2 beacon snapshot, then live Beacons data, then existing save data.
	if not beacon_snapshot_data.is_empty():
		if Globals.print_priority_7:
			print("[SaveManager.resolve_beacon_save_data] source=snapshot count=", beacon_snapshot_data.size())
		return beacon_snapshot_data.duplicate(true)

	if beacons_ref != null and beacons_ref.has_method("get_save_data"):
		var live_data = beacons_ref.get_save_data()

		if typeof(live_data) == TYPE_ARRAY and not live_data.is_empty():
			if Globals.print_priority_7:
				print("[SaveManager.resolve_beacon_save_data] source=live count=", live_data.size())
			return live_data.duplicate(true)

	var existing_beacons = existing_save.get("beacons", [])

	if typeof(existing_beacons) == TYPE_ARRAY:
		if Globals.print_priority_7:
			print("[SaveManager.resolve_beacon_save_data] source=existing_save count=", existing_beacons.size())
		return existing_beacons.duplicate(true)

	if Globals.print_priority_7:
		print("[SaveManager.resolve_beacon_save_data] source=empty")

	return []


func resolve_planet_save_data(existing_save: Dictionary, planets_ref: Planets = null, planet_snapshot_data: Array = []) -> Array:
	# Summary: Prefer snapshot planet data, then live Planets data, then existing save data.
	if not planet_snapshot_data.is_empty():
		if Globals.print_priority_7:
			print("[SaveManager.resolve_planet_save_data] source=snapshot count=", planet_snapshot_data.size())
		return planet_snapshot_data.duplicate(true)

	if planets_ref != null and planets_ref.has_method("get_save_data"):
		var live_data = planets_ref.get_save_data()

		if typeof(live_data) == TYPE_ARRAY and not live_data.is_empty():
			if Globals.print_priority_7:
				print("[SaveManager.resolve_planet_save_data] source=live count=", live_data.size())
			return live_data.duplicate(true)

	var existing_planets = existing_save.get("planets", [])

	if typeof(existing_planets) == TYPE_ARRAY:
		if Globals.print_priority_7:
			print("[SaveManager.resolve_planet_save_data] source=existing_save count=", existing_planets.size())
		return existing_planets.duplicate(true)

	if Globals.print_priority_7:
		print("[SaveManager.resolve_planet_save_data] source=empty")

	return []


func resolve_game_events_save_data(existing_save: Dictionary, game_event_handler = null) -> Dictionary:
	# Summary: Save story-event runtime state while keeping full event definitions in JSON.
	if game_event_handler != null and game_event_handler.has_method("to_save_data"):
		var live_data = game_event_handler.to_save_data()
		if typeof(live_data) == TYPE_DICTIONARY and not live_data.is_empty():
			if Globals.print_priority_7:
				print("[SaveManager.resolve_game_events_save_data] source=live")
			return live_data.duplicate(true)

	var existing_events = existing_save.get("game_events", {})
	if typeof(existing_events) == TYPE_DICTIONARY and not existing_events.is_empty():
		if Globals.print_priority_7:
			print("[SaveManager.resolve_game_events_save_data] source=existing_save")
		return existing_events.duplicate(true)

	return get_empty_game_events_save_data()


func resolve_player_state_save_data(existing_save: Dictionary, player_state_ref: PlayerState = null, player_state_snapshot_data: Dictionary = {}) -> Dictionary:
	# Summary: Prefer explicit battle/player snapshot, then live PlayerState, then existing save data, then defaults.
	if typeof(player_state_snapshot_data) == TYPE_DICTIONARY and not player_state_snapshot_data.is_empty():
		if Globals.print_priority_7:
			print("[SaveManager.resolve_player_state_save_data] source=snapshot")
		return player_state_snapshot_data.duplicate(true)

	if player_state_ref != null and player_state_ref.has_method("get_save_data"):
		var live_data = player_state_ref.get_save_data()
		if typeof(live_data) == TYPE_DICTIONARY and not live_data.is_empty():
			if Globals.print_priority_7:
				print("[SaveManager.resolve_player_state_save_data] source=live")
			return live_data.duplicate(true)

	var existing_player_state = existing_save.get("player_state", {})
	if typeof(existing_player_state) == TYPE_DICTIONARY and not existing_player_state.is_empty():
		if Globals.print_priority_7:
			print("[SaveManager.resolve_player_state_save_data] source=existing_save")
		return existing_player_state.duplicate(true)

	return get_empty_player_state_save_data()


func resolve_scan_state_save_data(existing_save: Dictionary) -> Dictionary:
	var scan_state = existing_save.get("scan_state", {})
	if typeof(scan_state) == TYPE_DICTIONARY:
		return scan_state.duplicate(true)
	return {}


func get_empty_player_state_save_data() -> Dictionary:
	return {
		"schema_version": 1,
		"unit_id": "player",
		"unit_name": "Player",
		"display_name": "Player",
		"unit_side": "player",
		"is_alive": true,
		"is_destroyed": false,
		"hull_current": 500.0,
		"hull_max": 500.0,
		"player_hull_current": 500.0,
		"player_hull_max": 500.0,
		"energy_current": 100.0,
		"energy_max": 100.0,
		"energy_regen_per_second": 8.0,
		"player_energy_current": 100.0,
		"player_energy_max": 100.0,
		"player_energy_regen_per_second": 8.0,
		"shield_hp_current": 0.0,
		"shield_hp_max": 0.0,
		"shield_power_level": 0,
		"shield_disabled": false,
		"primary_disabled": false,
		"secondary_disabled": false,
		"consumable_disabled": false,
		"battle_loadout": {
			"selected_primary_weapon": "",
			"selected_secondary_weapon": "",
			"selected_shield": "",
			"loaded_consumable": "",
			"loaded_consumable_state": "none",
			"equipped_upgrades": [],
			"shield_power_level": 0,
			"default_shield_power_level": 2
		},
		"selected_primary_weapon": "",
		"selected_secondary_weapon": "",
		"selected_shield": "",
		"loaded_consumable": "",
		"loaded_consumable_state": "none",
		"default_shield_power_level": 2
	}


func get_empty_game_events_save_data() -> Dictionary:
	return {
		"schema_version": 2,
		"active_event_id": "",
		"test_seed_checked": false,
		"seed_flags": {},
		"available_events": {},
		"active_events": {},
		"completed_events": {}
	}
	
func save_player_state_section_from_data(player_state_data: Dictionary) -> bool:
	# Summary: Update only the PlayerState section inside the existing universe save.

	if typeof(player_state_data) != TYPE_DICTIONARY or player_state_data.is_empty():
		if Globals.print_priority_7:
			print("SaveManager.save_player_state_section_from_data blocked: empty PlayerState data.")
		return false

	var loaded_data := read_universe_save_data()

	if loaded_data.is_empty() or not is_universe_save_shape_valid(loaded_data):
		if Globals.print_priority_7:
			print("SaveManager.save_player_state_section_from_data blocked: missing full universe save.")
		return false

	loaded_data["player_state"] = player_state_data.duplicate(true)

	var ok := write_universe_save_data(loaded_data)

	if Globals.print_priority_7:
		print("[SaveManager.save_player_state_section_from_data] ok=", ok, " hull=", player_state_data.get("hull_current"), "/", player_state_data.get("hull_max"))

	return ok
