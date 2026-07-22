extends Node
class_name GameEventsHandler

const DEFAULT_EVENT_JSON_DIR := "res://data/events"
const EVENT_SAVE_SCHEMA_VERSION := 2
const EVENT_ACTION_DEFAULT_GATE_RANGE := 120.0
const EVENT_BATTLE_DEFAULT_GATE_RANGE := 180.0
const EVENT_MOVEMENT_PULSE_DISTANCE := 5.0
const EVENT_MOVEMENT_FRAME_EPSILON := 0.01
const EVENT_RUNTIME_AUTOSAVE_ENABLED := false
const EVENT_PERF_WARN_MS := 24


# ==========================================================
# EVENT HANDLER
# ----------------------------------------------------------
# Owns event state, event seeding, event step movement,
# event widget packets, and event object creation requests.
#
# Does NOT own:
# - NPC scene UI
# - beacon visuals
# - battle damage
# - inventory internals
# - save data internals
# ==========================================================


# ==========================================================
# REFERENCES
# ==========================================================

var star_field = null
var map = null
var space_objects = null
var npc_handler = null
var beacons = null
var enemy_handler = null
var inventory = null
var save_manager = null
var auto_pilot = null
var widget_state = null
var widget_controller = null
var widget_builder = null
var action_manager = null
var task_manager = null
var battle_v2_bridge = null
var main_ui_handler = null
var intel_handler = null
var enemy_intel_handler = null
var world_builder := EventWorldBuilder.new()


# ==========================================================
# EVENT STATE
# ==========================================================

var setup_complete: bool = false
var test_seed_checked: bool = false
var event_listener_install_checked: bool = false

var active_events: Dictionary = {}
var completed_events: Dictionary = {}
var available_events: Dictionary = {}
var event_catalog: Dictionary = {}
var seed_flags: Dictionary = {}

var pending_npc_event_start: Dictionary = {}

var event_widget_dirty: bool = false
var active_event_id: String = ""
var story_popup_token_sequence: int = 0
var event_pulse_requested: bool = false
var event_pulse_reasons: Dictionary = {}
var movement_watch_initialized: bool = false
var movement_watch_active: bool = false
var last_event_pulse_sector: Vector3i = Vector3i.ZERO
var last_event_pulse_local: Vector3 = Vector3.ZERO
var last_frame_sector: Vector3i = Vector3i.ZERO
var last_frame_local: Vector3 = Vector3.ZERO
var last_autopilot_enabled: bool = false
var event_autosave_skip_printed: Dictionary = {}
var event_world_save_in_progress := false


# ==========================================================
# SETUP
# ----------------------------------------------------------
# Called from main after world handlers exist.
# ==========================================================

func setup(refs: Dictionary) -> void:
	star_field = refs.get("star_field", null)
	map = refs.get("map", null)
	space_objects = refs.get("space_objects", null)
	npc_handler = refs.get("npc_handler", null)
	beacons = refs.get("beacons", null)
	enemy_handler = refs.get("enemy_handler", null)
	inventory = refs.get("inventory", null)
	save_manager = refs.get("save_manager", null)
	auto_pilot = refs.get("auto_pilot", null)
	widget_state = refs.get("widget_state", null)
	widget_controller = refs.get("widget_controller", null)
	widget_builder = refs.get("widget_builder", refs.get("gui_builder", null))
	action_manager = refs.get("action_manager", null)
	task_manager = refs.get("task_manager", null)
	battle_v2_bridge = refs.get("battle_v2_bridge", null)
	main_ui_handler = refs.get("main_ui_handler", null)
	intel_handler = refs.get("intel_handler", null)
	enemy_intel_handler = refs.get("enemy_intel_handler", null)
	if enemy_intel_handler == null and save_manager != null and save_manager.has_method("get_enemy_intel_handler"):
		enemy_intel_handler = save_manager.get_enemy_intel_handler()
	if intel_handler == null and save_manager != null and save_manager.has_method("get_intel_handler"):
		intel_handler = save_manager.get_intel_handler()

	world_builder.setup(refs)
	load_event_catalog_from_json()
	load_event_state_from_save_if_available()

	setup_complete = true
	initialize_event_movement_watch()
	connect_event_pulse_sources()
	request_event_pulse("startup")

	if Globals.print_priority_7:
		print("EventHandler setup complete. | refs")
		for r in refs:
			print(str(r))
		


# ==========================================================
# SINGLE DELTA EXECUTION CALL
# ----------------------------------------------------------
# Main calls this once per frame.
# Keep this lightweight.
# ==========================================================

func execute_event_checks(delta: float) -> void:
	if not setup_complete:
		return

	# s1.2:
	# Do not run world/story event processing while Battle V2 is active or pending.
	if Globals.battle_mode or Globals.battle_pending or Globals.swap_battle_v2:
		return

	update_event_movement_watch()

	if not bool(seed_flags.get("_s1_2_startup_seed_pass_done", false)):
		request_event_pulse("startup")

	if not pending_npc_event_start.is_empty():
		request_event_pulse("npc_result_returned")

	if typeof(Globals.last_battle_v2_result) == TYPE_DICTIONARY and not Globals.last_battle_v2_result.is_empty():
		request_event_pulse("battle_result_returned")

	if event_widget_dirty:
		request_event_pulse("event_widget_dirty")

	if not event_pulse_requested:
		return

	var pulse_reasons := event_pulse_reasons.duplicate(true)
	event_pulse_requested = false
	event_pulse_reasons.clear()

	run_requested_event_pulse(pulse_reasons)


func request_event_pulse(reason: String) -> void:
	var safe_reason := str(reason).strip_edges()
	if safe_reason == "":
		safe_reason = "unspecified"
	event_pulse_requested = true
	event_pulse_reasons[safe_reason] = true


func poke_event_widget(reason: String = "event_widget_poke") -> void:
	event_widget_dirty = true
	request_event_pulse(reason)


func run_requested_event_pulse(pulse_reasons: Dictionary) -> void:
	var pulse_started_ms := Time.get_ticks_msec()
	# s1.2:
	# Seeding and catalog listener install should not run during battle-return cleanup.
	# They are boot/setup concerns, not normal per-frame event progression.
	var should_run_startup := pulse_reasons.has("startup") or not bool(seed_flags.get("_s1_2_startup_seed_pass_done", false))
	if should_run_startup:
		var startup_started_ms := Time.get_ticks_msec()
		seed_start_events_once()
		install_catalog_event_listeners_once()
		seed_flags["_s1_2_startup_seed_pass_done"] = true
		save_event_world_state()
		print_event_perf("startup seed/listener install", startup_started_ms)

	var pending_started_ms := Time.get_ticks_msec()
	process_pending_npc_event_start()
	process_pending_battle_v2_result()
	print_event_perf("pending npc/battle event work", pending_started_ms)
	if typeof(Globals.last_battle_v2_result) == TYPE_DICTIONARY and not Globals.last_battle_v2_result.is_empty():
		if event_widget_dirty:
			var widget_started_ms := Time.get_ticks_msec()
			refresh_event_widget()
			print_event_perf("refresh_event_widget after battle result", widget_started_ms)
		print_event_perf("run_requested_event_pulse reasons=" + str(pulse_reasons.keys()), pulse_started_ms)
		return

	if should_run_startup or pulse_has_progress_reason(pulse_reasons):
		var progress_started_ms := Time.get_ticks_msec()
		process_active_event_progress()
		print_event_perf("process_active_event_progress", progress_started_ms)

	if should_run_startup or pulse_has_spatial_reason(pulse_reasons):
		var listeners_started_ms := Time.get_ticks_msec()
		process_world_event_listeners()
		print_event_perf("process_world_event_listeners", listeners_started_ms)

	if event_widget_dirty:
		var widget_started_ms := Time.get_ticks_msec()
		refresh_event_widget()
		print_event_perf("refresh_event_widget", widget_started_ms)

	print_event_perf("run_requested_event_pulse reasons=" + str(pulse_reasons.keys()), pulse_started_ms)


func pulse_has_progress_reason(pulse_reasons: Dictionary) -> bool:
	for raw_reason in pulse_reasons.keys():
		var reason := str(raw_reason)
		if reason != "event_widget_dirty":
			return true
	return false


func pulse_has_spatial_reason(pulse_reasons: Dictionary) -> bool:
	for reason in [
		"movement_started",
		"movement_distance_bucket",
		"autopilot_arrived",
		"manual_stop",
		"main_mode_loaded",
		"scan_completed",
		"mine_completed",
		"event_button",
		"event_widget_action",
		"event_state_changed",
		"event_object_installed",
		"story_popup_closed",
		"step_advanced",
		"event_completed",
		"npc_result_returned",
		"battle_result_returned"
	]:
		if pulse_reasons.has(reason):
			return true
	return false


func initialize_event_movement_watch() -> void:
	if map == null:
		movement_watch_initialized = false
		return

	last_event_pulse_sector = map.sector_pos
	last_event_pulse_local = map.local_pos
	last_frame_sector = map.sector_pos
	last_frame_local = map.local_pos
	last_autopilot_enabled = auto_pilot != null and auto_pilot.enabled
	movement_watch_active = false
	movement_watch_initialized = true


func update_event_movement_watch() -> void:
	if map == null:
		return
	if not movement_watch_initialized:
		initialize_event_movement_watch()
		return

	var current_sector: Vector3i = map.sector_pos
	var current_local: Vector3 = map.local_pos
	var autopilot_enabled = auto_pilot != null and auto_pilot.enabled
	var autopilot_stopped = last_autopilot_enabled and not autopilot_enabled
	var moved_this_frame := current_sector != last_frame_sector or get_event_position_distance(
		last_frame_sector,
		last_frame_local,
		current_sector,
		current_local
	) > EVENT_MOVEMENT_FRAME_EPSILON

	if moved_this_frame:
		if not movement_watch_active:
			request_event_pulse("movement_started")
		movement_watch_active = true

		if get_event_position_distance(
			last_event_pulse_sector,
			last_event_pulse_local,
			current_sector,
			current_local
		) >= EVENT_MOVEMENT_PULSE_DISTANCE:
			remember_event_pulse_position(current_sector, current_local)
			request_event_pulse("movement_distance_bucket")
	elif movement_watch_active:
		movement_watch_active = false
		remember_event_pulse_position(current_sector, current_local)
		request_event_pulse("autopilot_arrived" if autopilot_stopped else "manual_stop")

	if autopilot_stopped:
		remember_event_pulse_position(current_sector, current_local)
		request_event_pulse("autopilot_arrived")

	last_autopilot_enabled = autopilot_enabled
	last_frame_sector = current_sector
	last_frame_local = current_local


func remember_event_pulse_position(sector: Vector3i, local: Vector3) -> void:
	last_event_pulse_sector = sector
	last_event_pulse_local = local


func get_event_position_distance(
	from_sector: Vector3i,
	from_local: Vector3,
	to_sector: Vector3i,
	to_local: Vector3
) -> float:
	var sector_size := float(Globals.sector_size)
	var from_world := Vector3(
		float(from_sector.x) * sector_size + from_local.x,
		float(from_sector.y) * sector_size + from_local.y,
		float(from_sector.z) * sector_size + from_local.z
	)
	var to_world := Vector3(
		float(to_sector.x) * sector_size + to_local.x,
		float(to_sector.y) * sector_size + to_local.y,
		float(to_sector.z) * sector_size + to_local.z
	)
	return from_world.distance_to(to_world)


func connect_event_pulse_sources() -> void:
	if action_manager == null:
		return

	if action_manager.has_signal("scan_completed"):
		var scan_callable := Callable(self, "_on_action_scan_completed")
		if not action_manager.scan_completed.is_connected(scan_callable):
			action_manager.scan_completed.connect(scan_callable)

	if action_manager.has_signal("mining_completed"):
		var mining_callable := Callable(self, "_on_action_mining_completed")
		if not action_manager.mining_completed.is_connected(mining_callable):
			action_manager.mining_completed.connect(mining_callable)


func _on_action_scan_completed(scan_packet: Dictionary = {}) -> void:
	request_event_pulse("scan_completed")


func _on_action_mining_completed(mining_packet: Dictionary = {}) -> void:
	request_event_pulse("mine_completed")


# ==========================================================
# FIRST RUN / TEST EVENT SEED
# ----------------------------------------------------------
# Creates the NPC/event hook once.
# This should not activate the full event until the player
# talks to the NPC / accepts the event.
# ==========================================================

func seed_start_events_once() -> void:
	if test_seed_checked:
		return

	var seeded_any := false
	var repaired_seed_flags := false

	var event_ids := event_catalog.keys()
	if event_ids.is_empty():
		if Globals.print_priority_7:
			print("Event seed skipped - no event JSON loaded.")
		test_seed_checked = true
		return

	event_ids.sort()

	for raw_event_id in event_ids:
		var event_id := str(raw_event_id)
		var event_data := get_event_data_by_id(event_id)

		if event_data.is_empty():
			continue

		if not bool(event_data.get("start_on_ready", false)):
			continue

		if bool(seed_flags.get(event_id, false)):
			continue

		# s1.2:
		# If this start_on_ready event already exists in runtime/save state,
		# mark the seed flag and do not recreate/restart it.
		if is_event_completed(event_id) or is_event_active(event_id) or available_events.has(event_id):
			seed_flags[event_id] = true
			repaired_seed_flags = true
			continue

		if seed_guild_test_event_npc(event_data):
			seed_flags[event_id] = true
			seeded_any = true

	test_seed_checked = true

	if seeded_any or repaired_seed_flags:
		save_event_world_state()



	
	


func resolve_event_json_dir() -> String:
	var lane_dir := str(Globals.active_universe_events_dir).strip_edges()
	if lane_dir != "" and DirAccess.dir_exists_absolute(lane_dir):
		return lane_dir

	if Globals.print_priority_2:
		print("[UNIVERSE_LANE_EVENTS] active event dir missing, using fallback. active=", lane_dir, " fallback=", DEFAULT_EVENT_JSON_DIR)

	return DEFAULT_EVENT_JSON_DIR

func load_event_catalog_from_json() -> void:
	event_catalog.clear()

	var active_event_dir := resolve_event_json_dir()
	var dir := DirAccess.open(active_event_dir)
	if dir == null:
		if Globals.print_priority_7:
			print("Event JSON directory missing: ", active_event_dir)
		return

	if Globals.print_priority_2:
		print("[UNIVERSE_LANE_EVENTS] universe_id=", Globals.active_universe_id, " loading_dir=", active_event_dir)

	var file_names := dir.get_files()
	file_names.sort()
	for file_name in file_names:
		if not file_name.ends_with(".json"):
			continue

		var path := active_event_dir + "/" + file_name
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			if Globals.print_priority_7:
				print("Could not open event JSON: ", path)
			continue

		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			if Globals.print_priority_7:
				print("Event JSON rejected - root is not a Dictionary: ", path)
			continue

		var event_data := normalize_event_data(parsed)
		var event_id := str(event_data.get("event_id", ""))
		if event_id == "":
			if Globals.print_priority_7:
				print("Event JSON rejected - missing event_id: ", path)
			continue

		if event_catalog.has(event_id):
			if Globals.print_priority_2 or Globals.print_priority_7:
				var existing_source := str(event_catalog[event_id].get("source_path", ""))
				print("[EVENT_CATALOG_DUPLICATE] skipped duplicate event_id=", event_id, " source=", path, " existing=", existing_source)
			continue

		event_data["source_path"] = path
		event_catalog[event_id] = event_data

	if Globals.print_priority_2:
		print("[UNIVERSE_LANE_EVENTS] loaded_count=", event_catalog.size(), " keys=", event_catalog.keys())
	elif Globals.print_priority_7:
		print("Event JSON catalog loaded: ", event_catalog.keys())


func normalize_event_data(event_data: Dictionary) -> Dictionary:
	var data := event_data.duplicate(true)

	if typeof(data.get("anchor_star", {})) == TYPE_DICTIONARY:
		data["anchor_star"] = normalize_position_fields(data.get("anchor_star", {}))

	if typeof(data.get("giver", {})) == TYPE_DICTIONARY:
		var giver: Dictionary = normalize_position_fields(data.get("giver", {}))
		if giver.has("local_offset"):
			giver["local_offset"] = _read_local_pos(giver.get("local_offset", Vector3.ZERO))
		data["giver"] = giver

	var event_objects: Dictionary = data.get("event_objects", {})
	for object_id in event_objects.keys():
		if typeof(event_objects[object_id]) == TYPE_DICTIONARY:
			event_objects[object_id] = normalize_position_fields(event_objects[object_id])
	data["event_objects"] = event_objects

	data["event_listeners"] = normalize_event_listener_collection(
		data.get("event_listeners", data.get("listener_beacons", data.get("world_listeners", {})))
	)

	return data


func normalize_event_listener_collection(raw_listeners) -> Dictionary:
	var out := {}

	if typeof(raw_listeners) == TYPE_ARRAY:
		for i in range(raw_listeners.size()):
			var listener_data = raw_listeners[i]
			if typeof(listener_data) != TYPE_DICTIONARY:
				continue
			var normalized := normalize_position_fields(listener_data)
			var listener_id := str(normalized.get("object_id", normalized.get("id", "event_listener_" + str(i)))).strip_edges()
			if listener_id == "":
				listener_id = "event_listener_" + str(i)
			out[listener_id] = normalized
		return out

	if typeof(raw_listeners) != TYPE_DICTIONARY:
		return out

	var raw_dict: Dictionary = raw_listeners
	if raw_dict.has("listener_type") or raw_dict.has("trigger_event_id") or raw_dict.has("object_id"):
		var normalized_single := normalize_position_fields(raw_dict)
		var single_id := str(normalized_single.get("object_id", normalized_single.get("id", "event_listener"))).strip_edges()
		if single_id == "":
			single_id = "event_listener"
		out[single_id] = normalized_single
		return out

	for listener_id in raw_dict.keys():
		var listener_packet = raw_dict[listener_id]
		if typeof(listener_packet) != TYPE_DICTIONARY:
			continue
		out[str(listener_id)] = normalize_position_fields(listener_packet)

	return out


func normalize_position_fields(source: Dictionary) -> Dictionary:
	var data := source.duplicate(true)
	var has_position := false
	var sector := Vector3i.ZERO
	var local := Vector3.ZERO

	if data.has("sector_pos"):
		sector = _read_sector_pos(data["sector_pos"])
		has_position = true
	elif data.has("sector"):
		sector = _read_sector_pos(data["sector"])
		has_position = true

	if data.has("local_pos"):
		local = _read_local_pos(data["local_pos"])
		has_position = true
	elif data.has("local"):
		local = _read_local_pos(data["local"])
		has_position = true

	if has_position:
		var normalized := normalize_sector_local_pair(sector, local)
		data["sector_pos"] = normalized["sector_pos"]
		data["local_pos"] = normalized["local_pos"]

	return data


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


func seed_guild_test_event_npc(event_data: Dictionary) -> bool:
	if npc_handler == null:
		if Globals.print_priority_7:
			print("Event seed failed - npc_handler missing.")
		return false

	var giver: Dictionary = event_data.get("giver", {})
	var blueprint_id := str(giver.get("blueprint_id", "guild_contact_tier_1"))
	var npc_id := str(giver.get("owner_id", "guild_contact_tier_1"))

	var anchor_star = ensure_anchor_star(event_data)

	if anchor_star == null:
		if Globals.print_priority_7:
			print("Event seed failed - anchor star missing for event: ", event_data.get("event_id", ""))
		return false

	var sector: Vector3i = anchor_star.sector_pos
	var local: Vector3 = anchor_star.local_pos + Vector3(20, 0, 0)

	var existing_npc = find_existing_event_npc(event_data)
	if existing_npc != null:
		register_existing_event_npc(event_data, existing_npc, sector, local)
		if Globals.print_priority_7:
			print("Reused existing event NPC for event: ", event_data["event_id"])
		return true

	var npc = null

	if npc_handler.has_method("make_npc_from_blueprint"):
		npc = npc_handler.make_npc_from_blueprint(blueprint_id, sector, local)

	if npc == null:
		if Globals.print_priority_7:
			print("Event seed failed - could not create NPC from blueprint: ", blueprint_id)
		return false

	configure_event_npc(npc, event_data, sector, local)
	register_available_event_for_npc(event_data, npc, sector, local)

	if Globals.print_priority_7:
		print("Seeded event NPC: ", npc_id, " for event: ", event_data["event_id"])
	return true


func find_existing_event_npc(event_data: Dictionary):
	if npc_handler == null or not "npcs" in npc_handler:
		return null

	var event_id := str(event_data.get("event_id", ""))
	var giver: Dictionary = event_data.get("giver", {})
	var blueprint_id := str(giver.get("blueprint_id", ""))
	var owner_id := str(giver.get("owner_id", "")).strip_edges()
	var object_id := str(giver.get("object_id", "")).strip_edges()
	var template_owner_id := str(giver.get("template_owner_id", "")).strip_edges()
	var wanted_ids := []
	for id_value in [owner_id, object_id, template_owner_id]:
		if id_value != "" and not wanted_ids.has(id_value):
			wanted_ids.append(id_value)
	var event_match = null
	var blueprint_match_npc = null
	var owner_match_npc = null

	for npc in npc_handler.npcs:
		if npc == null:
			continue

		var npc_event_id := str(npc.get_meta("event_id", npc.event_id))
		var npc_active_event_id := str(npc.get_meta("active_event_id", npc.active_event_id))
		var npc_event_state := str(npc.get_meta("event_state", npc.event_state)).strip_edges().to_lower()
		var npc_blueprint_id := str(npc.get_meta("blueprint_id", ""))
		var npc_id := str(npc.get_meta("npc_id", ""))

		if event_id != "" and (npc_event_id == event_id or npc_active_event_id == event_id):
			if npc_event_state == "active":
				return npc
			if event_match == null:
				event_match = npc

		if blueprint_id != "" and npc_blueprint_id == blueprint_id and blueprint_match_npc == null:
			blueprint_match_npc = npc

		if wanted_ids.has(npc_id) and owner_match_npc == null:
			owner_match_npc = npc

	if event_match != null:
		return event_match
	if owner_match_npc != null:
		return owner_match_npc
	if bool(giver.get("allow_blueprint_reuse", false)) and blueprint_match_npc != null:
		return blueprint_match_npc
	return null


func configure_event_npc(npc, event_data: Dictionary, fallback_sector: Vector3i, fallback_local: Vector3) -> void:
	if npc == null:
		return

	var event_id := str(event_data.get("event_id", ""))
	var giver: Dictionary = event_data.get("giver", {})
	var blueprint_id := str(giver.get("blueprint_id", npc.get_meta("blueprint_id", "")))
	var display_name := str(giver.get("display_name", "")).strip_edges()
	if display_name == "":
		display_name = str(npc.display_name).strip_edges()
	if display_name == "":
		display_name = npc.npc_name
	var stable_npc_id := str(giver.get("template_owner_id", giver.get("owner_id", giver.get("object_id", "")))).strip_edges()
	if stable_npc_id == "":
		stable_npc_id = str(npc.get_meta("npc_id", npc.object_id)).strip_edges()
	var offer_step := get_event_offer_step(event_data)

	var sector = npc.sector_pos if npc.sector_pos != Vector3i.ZERO else fallback_sector
	var local = npc.local_pos if npc.local_pos != Vector3.ZERO else fallback_local

	if stable_npc_id != "":
		npc.object_id = stable_npc_id
		npc.set_meta("npc_id", stable_npc_id)

	npc.sector_pos = sector
	npc.local_pos = local
	npc.has_event = true
	npc.event_id = event_id
	npc.active_event_id = event_id
	npc.event_state = "available"
	npc.event_step = offer_step
	npc.current_step = offer_step
	npc.give_event = event_id
	npc.npc_name = display_name
	npc.display_name = display_name
	npc.event_accept_message = "Good. I am sending the beacon coordinates to your event console."
	npc.event_decline_message = "Understood. The signal is not going anywhere."
	npc.event_idle_message = "The beacon is still waiting. Use your event console autopilot."
	npc.event_completed_message = "That data chip is exactly what I needed."

	if blueprint_id != "":
		npc.set_meta("blueprint_id", blueprint_id)

	npc.set_meta("display_name", display_name)
	npc.set_meta("name", display_name)
	npc.set_meta("has_event", true)
	npc.set_meta("event_id", event_id)
	npc.set_meta("active_event_id", event_id)
	npc.set_meta("event_state", "available")
	npc.set_meta("event_step", offer_step)
	npc.set_meta("current_step", offer_step)
	npc.set_meta("event_next_step", resolve_event_start_step(event_data))
	npc.set_meta("give_event", event_id)

	npc.set_meta("event_offer_title", event_data.get("display_name", "Event"))
	npc.set_meta("event_offer_message", "I found an old guild beacon ping, but it is outside normal safe range.")
	npc.set_meta("event_accept_message", "Good. I am sending the beacon coordinates to your event console.")
	npc.set_meta("event_start_items", event_data.get("start_items", event_data.get("event_start_items", [])).duplicate(true))
	npc.set_meta("event_decline_message", "Understood. The signal is not going anywhere.")
	npc.set_meta("event_idle_message", "The beacon is still waiting. Use your event console autopilot.")
	npc.set_meta("event_completed_message", "That data chip is exactly what I needed.")
	if giver.has("dialogue_lines"):
		var giver_lines := normalize_dialogue_lines(giver.get("dialogue_lines", []))
		if not giver_lines.is_empty():
			npc.set_meta("dialogue_lines", giver_lines)
			npc.greeting_message = str(giver_lines[0])
			npc.has_message = true
	if giver.has("chat_line_delay"):
		npc.chat_line_delay = max(float(giver.get("chat_line_delay", npc.chat_line_delay)), 0.1)
		npc.set_meta("chat_line_delay", npc.chat_line_delay)
	if giver.has("chat_character_delay") or giver.has("chat_type_delay"):
		npc.chat_character_delay = max(float(giver.get("chat_character_delay", giver.get("chat_type_delay", npc.chat_character_delay))), 0.005)
		npc.set_meta("chat_character_delay", npc.chat_character_delay)
	if giver.has("can_trade") or giver.has("trade"):
		npc.can_trade = bool(giver.get("can_trade", giver.get("trade", npc.can_trade)))
		npc.set_meta("can_trade", npc.can_trade)
		npc.set_meta("trade", npc.can_trade)
	if giver.has("item_list") and typeof(giver.get("item_list", [])) == TYPE_ARRAY:
		npc.set_meta("item_list", giver.get("item_list", []).duplicate(true))
	for key in ["offer_title", "offer_text", "success_text"]:
		if giver.has(key):
			npc.set_meta(key, str(giver.get(key, "")))

	apply_npc_dialogue_update_to_npc(npc, build_step_npc_dialogue_packet(event_data, offer_step), {
		"source": "event_npc_configure",
		"step_id": offer_step
	})

	var labels := SharedObjectMeta.read_array(npc.labels)
	for label in ["npc", "event_giver", "guild_event"]:
		if not labels.has(label):
			labels.append(label)
	npc.labels = labels

	if npc.has_method("sync_shared_meta"):
		npc.sync_shared_meta()


func register_existing_event_npc(event_data: Dictionary, npc, fallback_sector: Vector3i, fallback_local: Vector3) -> void:
	if npc == null:
		return

	var event_id := str(event_data.get("event_id", ""))
	var event_state := str(npc.get_meta("event_state", npc.event_state)).strip_edges().to_lower()
	var event_step := str(npc.get_meta("current_step", npc.current_step)).strip_edges()
	if event_step == "":
		event_step = str(npc.get_meta("event_step", npc.event_step)).strip_edges()

	if event_state == "active":
		var active_event := event_data.duplicate(true)
		active_event["event_state"] = "active"
		active_event["current_step"] = event_step if event_step != "" else "go_to_beacon"
		active_event["giver"] = build_giver_data_for_npc(event_data, npc, fallback_sector, fallback_local)
		active_events[event_id] = active_event
		available_events.erase(event_id)
		active_event_id = event_id
		create_event_beacon_if_needed(active_event)
		event_widget_dirty = true
		return

	if event_state == "completed":
		completed_events[event_id] = event_data.duplicate(true)
		return

	configure_event_npc(npc, event_data, fallback_sector, fallback_local)
	register_available_event_for_npc(event_data, npc, npc.sector_pos, npc.local_pos)


func build_giver_data_for_npc(event_data: Dictionary, npc, fallback_sector: Vector3i, fallback_local: Vector3) -> Dictionary:
	var giver: Dictionary = event_data.get("giver", {}).duplicate(true)
	var template_owner_id := str(giver.get("template_owner_id", giver.get("owner_id", giver.get("object_id", "")))).strip_edges()
	var npc_id := template_owner_id

	if npc != null:
		var meta_id := str(npc.get_meta("npc_id", ""))
		if npc_id == "" or meta_id == npc_id:
			npc_id = meta_id

	giver["owner_type"] = "npc"
	giver["owner_id"] = npc_id
	giver["object_id"] = npc_id
	giver["blueprint_id"] = str(giver.get("blueprint_id", npc.get_meta("blueprint_id", ""))) if npc != null else str(giver.get("blueprint_id", ""))
	var giver_display_name := str(giver.get("display_name", "")).strip_edges()
	if giver_display_name == "" and npc != null:
		giver_display_name = str(npc.display_name).strip_edges()
	if giver_display_name == "" and npc != null:
		giver_display_name = npc.npc_name
	if giver_display_name == "":
		giver_display_name = "Guild Contact"
	giver["display_name"] = giver_display_name
	giver["sector_pos"] = npc.sector_pos if npc != null else fallback_sector
	giver["local_pos"] = npc.local_pos if npc != null else fallback_local
	giver["template_owner_id"] = template_owner_id
	return giver


func register_available_event_for_npc(
	event_data: Dictionary,
	npc,
	sector: Vector3i,
	local: Vector3
) -> void:
	var event_id := str(event_data.get("event_id", ""))
	if event_id == "":
		return

	var giver: Dictionary = event_data.get("giver", {}).duplicate(true)
	var blueprint_id := str(giver.get("blueprint_id", ""))
	var template_owner_id := str(giver.get("template_owner_id", giver.get("owner_id", giver.get("object_id", "")))).strip_edges()
	var npc_id := template_owner_id

	if npc != null and npc_id == "":
		var meta_id := str(npc.get_meta("npc_id", ""))
		if meta_id != "":
			npc_id = meta_id

	giver["owner_type"] = "npc"
	giver["owner_id"] = npc_id
	giver["object_id"] = npc_id
	giver["blueprint_id"] = blueprint_id
	giver["display_name"] = str(giver.get("display_name", "Guild Contact"))
	giver["sector_pos"] = sector
	giver["local_pos"] = local
	giver["template_owner_id"] = template_owner_id

	var available_event := event_data.duplicate(true)
	available_event["event_state"] = "available"
	available_event["current_step"] = get_event_offer_step(event_data)
	available_event["giver"] = giver

	available_events[event_id] = available_event
	if active_event_id == "" or not (active_events.has(active_event_id) or available_events.has(active_event_id)):
		active_event_id = event_id
	event_widget_dirty = true
	save_event_world_state()


func get_event_offer_step(event_data: Dictionary) -> String:
	var current_step := str(event_data.get("current_step", "")).strip_edges()
	if current_step != "":
		return current_step

	var steps = event_data.get("steps", {})
	if typeof(steps) == TYPE_DICTIONARY and not steps.is_empty():
		return str(steps.keys()[0])

	return "talk_to_npc"


func resolve_event_start_step(event_data: Dictionary, result: Dictionary = {}) -> String:
	var steps = event_data.get("steps", {})
	var authored_start := resolve_authored_event_start_step(event_data)

	for key in ["event_next_step", "current_step", "event_step"]:
		var candidate := str(result.get(key, "")).strip_edges()
		if candidate != "" and candidate == authored_start and typeof(steps) == TYPE_DICTIONARY and steps.has(candidate):
			return candidate

	return authored_start


func resolve_authored_event_start_step(event_data: Dictionary) -> String:
	var steps = event_data.get("steps", {})
	var offer_step := get_event_offer_step(event_data)
	var offer_data := get_step_data(event_data, offer_step)
	if is_event_offer_step(event_data, offer_step, offer_data):
		var next_step := str(offer_data.get("next_step", "")).strip_edges()
		if next_step != "":
			return next_step
	if offer_step != "":
		return offer_step

	return "go_to_beacon"


func is_event_offer_step(event_data: Dictionary, step_id: String, step_data: Dictionary) -> bool:
	if step_data.is_empty():
		return false

	var giver: Dictionary = event_data.get("giver", {})
	var target_owner_id := str(step_data.get("target_owner_id", "")).strip_edges()
	if target_owner_id != "":
		var giver_owner_id := str(giver.get("owner_id", "")).strip_edges()
		var giver_object_id := str(giver.get("object_id", "")).strip_edges()
		var giver_template_owner_id := str(giver.get("template_owner_id", "")).strip_edges()
		var giver_blueprint_id := str(giver.get("blueprint_id", "")).strip_edges()
		var allow_blueprint_target := bool(giver.get("allow_blueprint_reuse", false))
		if target_owner_id == giver_owner_id or target_owner_id == giver_object_id or target_owner_id == giver_template_owner_id:
			return true
		if allow_blueprint_target and target_owner_id == giver_blueprint_id:
			return true

	var step_kind := str(step_data.get("step_kind", step_data.get("interaction_type", ""))).strip_edges().to_lower()
	return step_kind == "offer" or step_kind == "talk" or step_id.begins_with("talk")


func request_start_event_from_npc(npc) -> void:
	if npc == null:
		return

	var event_id := str(npc.get_meta("event_id", ""))

	if event_id == "":
		return

	pending_npc_event_start = {
		"event_id": event_id,
		"npc": npc
	}
	request_event_pulse("npc_result_returned")


func process_pending_npc_event_start() -> void:
	if pending_npc_event_start.is_empty():
		return

	var request := pending_npc_event_start.duplicate(true)
	pending_npc_event_start.clear()

	var npc = request.get("npc", null)
	var event_id := str(request.get("event_id", ""))

	if npc == null or event_id == "":
		return

	start_event_from_npc(npc, event_id)


func start_event_from_npc(npc, event_id: String) -> void:
	if is_event_completed(event_id):
		return

	if is_event_active(event_id):
		active_event_id = event_id
		event_widget_dirty = true
		return

	var event_data := get_event_data_by_id(event_id)

	if event_data.is_empty():
		if Globals.print_priority_7:
			print("Could not start event. Missing event data: ", event_id)
		return

	var start_step := resolve_event_start_step(event_data)
	event_data["event_state"] = "active"
	event_data["current_step"] = start_step
	event_data["giver"] = build_giver_data_for_npc(event_data, npc, npc.sector_pos, npc.local_pos)

	active_events[event_id] = event_data
	active_event_id = event_id

	create_event_beacon_if_needed(event_data)
	sync_event_state_to_world(event_data)

	if npc != null:
		npc.set_meta("event_state", "active")
		npc.set_meta("event_step", start_step)
		npc.set_meta("current_step", start_step)
		if npc.has_method("sync_shared_meta"):
			npc.sync_shared_meta()

	save_event_world_state()

	event_widget_dirty = true

	if Globals.print_priority_7:
		print("Started event from NPC: ", event_id)


func start_event_from_npc_result(result: Dictionary) -> bool:
	if result.is_empty():
		return false

	if not bool(result.get("event_start_requested", false)):
		return false

	var event_id := str(result.get("event_id", result.get("active_event_id", "")))
	if event_id == "":
		return false

	if is_event_completed(event_id):
		return false

	var event_data := get_event_data_by_id(event_id)
	if event_data.is_empty():
		if Globals.print_priority_7:
			print("Could not start event from NPC result. Missing event data: ", event_id)
		return false

	event_data["event_state"] = "active"
	event_data["current_step"] = resolve_event_start_step(event_data, result)

	var giver: Dictionary = event_data.get("giver", {})
	var template_owner_id := str(giver.get("template_owner_id", giver.get("owner_id", giver.get("object_id", "")))).strip_edges()
	var result_sector = result.get("sector_pos", result.get("sector", null))
	var result_local = result.get("local_pos", result.get("local", null))
	if result.has("npc_id"):
		var result_npc_id := str(result.get("npc_id", "")).strip_edges()
		var runtime_owner_id := template_owner_id if template_owner_id != "" else result_npc_id
		if runtime_owner_id != "":
			giver["owner_id"] = runtime_owner_id
			giver["object_id"] = runtime_owner_id
	if result.has("blueprint_id"):
		giver["blueprint_id"] = str(result.get("blueprint_id", giver.get("blueprint_id", "")))
	if result_sector != null:
		giver["sector_pos"] = _read_sector_pos(result_sector)
	if result_local != null:
		giver["local_pos"] = _read_local_pos(result_local)
	if template_owner_id != "":
		giver["template_owner_id"] = template_owner_id
	event_data["giver"] = giver

	active_events[event_id] = event_data
	available_events.erase(event_id)
	active_event_id = event_id

	create_event_beacon_if_needed(event_data)
	sync_event_state_to_world(event_data)
	save_event_world_state()

	event_widget_dirty = true
	request_event_pulse("npc_result_returned")

	if Globals.print_priority_7:
		print("Started event from NPC result: ", event_id, " step=", event_data["current_step"])

	return true


# ==========================================================
# EVENT BEACON CREATION
# ==========================================================

func create_event_beacon_if_needed(event_data: Dictionary) -> void:
	if beacons == null:
		if Globals.print_priority_7:
			print("Event beacon creation failed - beacons missing.")
		return

	if world_builder != null:
		world_builder.install_event_objects(event_data, "")
		return

	var event_objects: Dictionary = event_data.get("event_objects", {})

	for object_id in event_objects.keys():
		var object_data: Dictionary = event_objects[object_id]

		if str(object_data.get("owner_type", "")) != "beacon":
			continue

		if beacon_exists(str(object_data.get("object_id", object_id))):
			continue

		create_event_beacon(event_data, object_data)


func create_event_beacon(event_data: Dictionary, object_data: Dictionary) -> void:
	var beacon_id := str(object_data.get("object_id", "lost_beacon_001"))
	var display_name := str(object_data.get("display_name", "Lost Beacon"))
	var beacon_type := str(object_data.get("beacon_type", "event_beacon"))

	var sector: Vector3i = object_data.get("sector_pos", Vector3i.ZERO)
	var local: Vector3 = object_data.get("local_pos", Vector3.ZERO)

	var beacon_data := {
		"id": beacon_id,
		"object_id": beacon_id,
		"object_type": "beacon",
		"display_name": display_name,
		"title": display_name,
		"beacon_type": beacon_type,
		"tier": int(event_data.get("tier", 1)),
		"sector_pos": sector,
		"local_pos": local,
		"parent_star_name": str(event_data.get("anchor_star", {}).get("star_name", "")),
		"message": "A cold guild signal repeats from the dark.",
		"event_id": event_data["event_id"],
		"has_event": true,
		"event_state": "active",
		"event_step": object_data.get("required_step", "download_beacon_data"),
		"required_step": object_data.get("required_step", "download_beacon_data"),
		"interaction_type": object_data.get("interaction_type", "download"),
		"labels": ["beacon", "event_beacon", "guild_event"]
	}

	if SharedObjectMeta:
		beacon_data = SharedObjectMeta.apply_to_dictionary(
			beacon_data,
			beacon_id,
			"beacon",
			display_name,
			sector,
			local
		)

	beacons.beacons.append(beacon_data)

	if Globals.print_priority_7:
		print("Created event beacon: ", beacon_id)


func beacon_exists(beacon_id: String) -> bool:
	if beacons == null:
		return false

	if not "beacons" in beacons:
		return false

	for beacon in beacons.beacons:
		if typeof(beacon) != TYPE_DICTIONARY:
			continue

		var id_a := str(beacon.get("object_id", ""))
		var id_b := str(beacon.get("id", ""))

		if id_a == beacon_id or id_b == beacon_id:
			return true

	return false


# ==========================================================
# EVENT WIDGET
# ==========================================================

func refresh_event_widget() -> void:
	event_widget_dirty = false

	ensure_display_event_selection()

	if active_event_id == "":
		if Globals.print_priority_7:
			print("Event widget refresh skipped - active_event_id empty.")
		return

	var event_data := get_display_event_data(active_event_id)

	if event_data.is_empty():
		if Globals.print_priority_7:
			print("Event widget refresh skipped - no display event data for: ", active_event_id)
		return

	var packet := build_event_widget_packet(event_data)
	packet["event_list"] = build_event_widget_event_list()
	packet["selected_event_id"] = active_event_id

	send_event_widget_packet(packet)


func send_event_widget_packet(packet: Dictionary) -> void:
	if widget_builder == null:
		if Globals.print_priority_7:
			print("Event widget refresh failed - widget_builder is null.")
		return

	if not widget_builder.has_method("set_event_widget_packet"):
		if Globals.print_priority_7:
			print("Event widget refresh failed - widget_builder missing set_event_widget_packet.")
		return

	widget_builder.set_event_widget_packet(packet)

	if Globals.print_priority_7:
		print("Event widget packet sent: ", packet.get("event_id", ""))


func build_event_widget_packet(event_data: Dictionary) -> Dictionary:
	var current_step := str(event_data.get("current_step", ""))
	var event_state := str(event_data.get("event_state", "active")).strip_edges().to_lower()
	var steps: Dictionary = event_data.get("steps", {})
	var step_data: Dictionary = steps.get(current_step, {})

	var target := build_target_packet_for_step(event_data, step_data)
	var objective = step_data.get("objective_text", "Waiting for objective data.")
	if event_state == "available":
		target = build_giver_target_packet(event_data)
		objective = "Talk to " + str(target.get("display_name", "the event contact")) + " to start this event."
	var buttons := build_event_widget_buttons(event_data, step_data)

	return {
		"event_id": event_data.get("event_id", ""),
		"display_name": event_data.get("display_name", "EVENT"),
		"objective_text": objective,
		"current_step": current_step,
		"target": target,
		"buttons": buttons
	}


func ensure_display_event_selection() -> void:
	if active_event_id != "" and (active_events.has(active_event_id) or available_events.has(active_event_id)):
		return

	if not active_events.is_empty():
		active_event_id = str(active_events.keys()[0])
		return

	if not available_events.is_empty():
		active_event_id = str(available_events.keys()[0])
		return

	active_event_id = ""


func build_event_widget_event_list() -> Array:
	var event_list := []
	var active_keys := active_events.keys()
	active_keys.sort()
	for event_id in active_keys:
		var event_data: Dictionary = active_events[event_id]
		event_list.append(build_event_summary_packet(event_data, "active"))

	var available_keys := available_events.keys()
	available_keys.sort()
	for event_id in available_keys:
		var event_data: Dictionary = available_events[event_id]
		event_list.append(build_event_summary_packet(event_data, "available"))

	return event_list


func build_event_summary_packet(event_data: Dictionary, state_label: String) -> Dictionary:
	var current_step := str(event_data.get("current_step", ""))
	var step_data := get_step_data(event_data, current_step)
	var objective := str(step_data.get("objective_text", "Waiting for objective data."))
	return {
		"event_id": str(event_data.get("event_id", "")),
		"display_name": str(event_data.get("display_name", "EVENT")),
		"event_state": state_label,
		"current_step": current_step,
		"objective_text": objective
	}


func build_event_widget_buttons(event_data: Dictionary, step_data: Dictionary) -> Array:
	var buttons := []
	var event_list := build_event_widget_event_list()
	if event_list.size() > 1:
		buttons.append({
			"button_id": "open_event_list",
			"label": "EVENTS",
			"action_id": "open_event_list",
			"event_id": event_data.get("event_id", ""),
			"step_id": event_data.get("current_step", "")
		})

	var actions = step_data.get("actions", [])
	if typeof(actions) != TYPE_ARRAY:
		return buttons

	for action in actions:
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var button_packet: Dictionary = action.duplicate(true)
		button_packet["event_id"] = str(button_packet.get("event_id", event_data.get("event_id", "")))
		button_packet["step_id"] = str(button_packet.get("step_id", event_data.get("current_step", "")))
		button_packet["button_id"] = str(button_packet.get("button_id", button_packet.get("action_id", "event_action")))
		button_packet["label"] = str(button_packet.get("label", button_packet.get("button_id", "EVENT")))
		button_packet["is_json_event_action"] = true
		button_packet["event_widget_attention"] = bool(button_packet.get("event_widget_attention", true))
		buttons.append(button_packet)

	return buttons


func build_event_selector_buttons(selected_event_id: String) -> Array:
	var buttons := []
	var event_list := build_event_widget_event_list()
	if event_list.size() <= 1:
		return buttons

	for i in range(event_list.size()):
		var summary: Dictionary = event_list[i]
		var event_id := str(summary.get("event_id", ""))
		var label := str(i + 1)
		if event_id == selected_event_id:
			label = "[" + label + "]"
		buttons.append({
			"button_id": "select_event_" + event_id,
			"label": label,
			"action_id": "select_event",
			"event_id": event_id,
			"target_event_id": event_id,
			"display_name": str(summary.get("display_name", event_id)),
			"event_state": str(summary.get("event_state", "")),
			"is_event_selector": true
		})

	return buttons


func build_target_packet_for_step(event_data: Dictionary, step_data: Dictionary) -> Dictionary:
	var target_owner_id := str(step_data.get("target_owner_id", ""))

	if target_owner_id != "":
		var giver: Dictionary = event_data.get("giver", {})
		var giver_id := str(giver.get("owner_id", giver.get("object_id", "")))
		var giver_object_id := str(giver.get("object_id", ""))
		var giver_blueprint_id := str(giver.get("blueprint_id", ""))
		var giver_template_owner_id := str(giver.get("template_owner_id", ""))
		var allow_blueprint_target := bool(giver.get("allow_blueprint_reuse", false))

		if target_owner_id == giver_id or target_owner_id == giver_object_id or target_owner_id == giver_template_owner_id:
			return build_giver_target_packet(event_data)
		if allow_blueprint_target and target_owner_id == giver_blueprint_id:
			return build_giver_target_packet(event_data)

	var target_object_id := str(step_data.get("target_object_id", ""))

	if target_object_id == "":
		return {}

	var event_objects: Dictionary = event_data.get("event_objects", {})

	if not event_objects.has(target_object_id):
		return {}

	var object_data: Dictionary = event_objects[target_object_id]
	var position := {}
	if world_builder != null and world_builder.has_method("resolve_object_position"):
		position = world_builder.resolve_object_position(object_data, event_data)
	else:
		position = normalize_sector_local_pair(
			_read_sector_pos(object_data.get("sector_pos", Vector3i.ZERO)),
			_read_local_pos(object_data.get("local_pos", Vector3.ZERO))
		)

	return {
		"owner_type": object_data.get("owner_type", object_data.get("object_type", "target")),
		"owner_id": object_data.get("object_id", target_object_id),
		"display_name": object_data.get("display_name", target_object_id),
		"sector_pos": _read_sector_pos(position.get("sector_pos", Vector3i.ZERO)),
		"local_pos": _read_local_pos(position.get("local_pos", Vector3.ZERO)),
		"event_id": event_data.get("event_id", ""),
		"event_step": event_data.get("current_step", "")
	}


func event_gate_result_blocks(result: Dictionary) -> bool:
	var status := str(result.get("status", "")).strip_edges().to_lower()
	return status == "blocked" or status == "failed"


func has_event_position_range_field(packet: Dictionary) -> bool:
	for key in ["gate_range", "activation_range", "interaction_range", "target_range", "range", "radius", "pos_radius", "position_radius"]:
		if packet.has(key):
			return true
	return false


func event_position_gate_applies(action_id: String, button_packet: Dictionary, step_data: Dictionary, context: Dictionary = {}) -> bool:
	if bool(button_packet.get("ignore_position_gate", false)):
		return false
	if bool(step_data.get("ignore_position_gate", false)):
		return false

	if bool(button_packet.get("requires_position_gate", button_packet.get("requires_target_range", false))):
		return true
	if bool(step_data.get("requires_position_gate", step_data.get("requires_target_range", false))):
		return true
	if has_event_position_range_field(button_packet) or has_event_position_range_field(step_data):
		return true

	var clean_action := action_id.strip_edges().to_lower()
	if clean_action in ["download_beacon_data", "claim_event_reward", "event_operations", "run_operations", "advance_step", "start_battle", "start_hunt_battle"]:
		if step_data.has("target_object_id") or step_data.has("target_owner_id"):
			return true
		if button_packet.has("target_object_id") or button_packet.has("target_owner_id") or button_packet.has("enemy_id"):
			return true

	var source := str(context.get("source", "")).strip_edges().to_lower()
	if source == "step_enter" and clean_action in ["start_battle", "start_hunt_battle"]:
		return true

	return false


func read_event_gate_range_from_packet(packet: Dictionary, fallback: float) -> float:
	for key in ["gate_range", "activation_range", "interaction_range", "target_range", "range", "radius", "pos_radius", "position_radius"]:
		if packet.has(key):
			return float(packet.get(key, fallback))
	return fallback


func resolve_event_gate_range(action_id: String, button_packet: Dictionary, step_data: Dictionary) -> float:
	var range := read_event_gate_range_from_packet(button_packet, -1.0)
	if range >= 0.0:
		return range

	range = read_event_gate_range_from_packet(step_data, -1.0)
	if range >= 0.0:
		return range

	var clean_action := action_id.strip_edges().to_lower()
	if clean_action == "start_battle" or clean_action == "start_hunt_battle":
		return EVENT_BATTLE_DEFAULT_GATE_RANGE
	if bool(button_packet.get("requires_position_gate", false)) or bool(step_data.get("requires_position_gate", false)):
		return EVENT_ACTION_DEFAULT_GATE_RANGE

	return 0.0


func normalize_event_gate_target_packet(raw_target: Dictionary, event_data: Dictionary) -> Dictionary:
	var has_sector := raw_target.has("sector_pos") or raw_target.has("sector")
	var has_local := raw_target.has("local_pos") or raw_target.has("local")
	if not has_sector and not has_local:
		return {}

	var sector := _read_sector_pos(raw_target.get("sector_pos", raw_target.get("sector", Vector3i.ZERO)))
	var local := _read_local_pos(raw_target.get("local_pos", raw_target.get("local", Vector3.ZERO)))
	var normalized := normalize_sector_local_pair(sector, local)
	return {
		"owner_type": raw_target.get("owner_type", raw_target.get("object_type", "target")),
		"owner_id": raw_target.get("owner_id", raw_target.get("object_id", raw_target.get("target_object_id", "event_target"))),
		"display_name": raw_target.get("display_name", raw_target.get("name", raw_target.get("owner_id", "Event Target"))),
		"sector_pos": _read_sector_pos(normalized.get("sector_pos", sector)),
		"local_pos": _read_local_pos(normalized.get("local_pos", local)),
		"event_id": raw_target.get("event_id", event_data.get("event_id", "")),
		"event_step": raw_target.get("event_step", event_data.get("current_step", ""))
	}


func resolve_event_gate_target(event_data: Dictionary, step_data: Dictionary, button_packet: Dictionary) -> Dictionary:
	var target_source := step_data.duplicate(true)

	for key in ["target_owner_id", "target_object_id"]:
		var value := str(button_packet.get(key, "")).strip_edges()
		if value != "":
			target_source[key] = value

	var enemy_id := str(button_packet.get("enemy_id", "")).strip_edges()
	if enemy_id != "":
		target_source["target_object_id"] = enemy_id

	var target := build_target_packet_for_step(event_data, target_source)
	if not target.is_empty():
		return target

	if button_packet.has("target") and typeof(button_packet.get("target")) == TYPE_DICTIONARY:
		target = normalize_event_gate_target_packet(button_packet.get("target", {}), event_data)
		if not target.is_empty():
			return target

	return normalize_event_gate_target_packet(button_packet, event_data)


func format_event_gate_distance(value: float) -> String:
	return str(int(round(value)))


func get_event_gate_auto_pilot():
	if auto_pilot != null:
		return auto_pilot
	if widget_state != null:
		auto_pilot = widget_state.get("auto_pilot")
	return auto_pilot


func is_event_gate_auto_pilot_already_routing(target: Dictionary) -> bool:
	var pilot = get_event_gate_auto_pilot()
	if pilot == null:
		return false
	if not pilot.has_method("is_current_impulse_route_for_target"):
		return false

	var sector := _read_sector_pos(target.get("sector_pos", Vector3i.ZERO))
	var local := _read_local_pos(target.get("local_pos", Vector3.ZERO))
	return bool(pilot.is_current_impulse_route_for_target(sector, local))


func start_event_gate_auto_pilot(target: Dictionary) -> bool:
	var pilot = get_event_gate_auto_pilot()
	if pilot == null:
		return false
	if not pilot.has_method("set_impulse_target"):
		return false

	var sector := _read_sector_pos(target.get("sector_pos", Vector3i.ZERO))
	var local := _read_local_pos(target.get("local_pos", Vector3.ZERO))
	var target_name := str(target.get("display_name", target.get("owner_id", "Event Target")))
	var target_kind := str(target.get("owner_type", target.get("object_type", "target"))).strip_edges().to_lower()
	var target_type := "event_" + target_kind if target_kind != "" else "event"

	if widget_state != null:
		widget_state.use_auto_pilot = false
	pilot.set_impulse_target(sector, local, target_name, target_type)
	return true


func build_event_position_gate_blocked_result(
	event_id: String,
	action_id: String,
	target: Dictionary,
	required_range: float,
	distance: float,
	context: Dictionary = {}
) -> Dictionary:
	var target_name := str(target.get("display_name", target.get("owner_id", "Event Target")))
	var already_routing := is_event_gate_auto_pilot_already_routing(target)
	var autopilot_started := already_routing
	if not already_routing:
		autopilot_started = start_event_gate_auto_pilot(target)

	var message := "EVENT TARGET OUT OF RANGE\n"
	message += target_name + "\n"
	message += "Needed: " + format_event_gate_distance(required_range) + " units\n"
	message += "Current: " + format_event_gate_distance(distance) + " units\n"
	message += ("AUTO PILOT ENGAGED" if autopilot_started else "Auto pilot is not connected.")

	var source := str(context.get("source", "")).strip_edges().to_lower()
	if not (source == "step_enter" and already_routing):
		write_event_log(message)
		event_widget_dirty = true

	return {
		"status": "blocked",
		"reason": "too far",
		"event_id": event_id,
		"action_id": action_id,
		"distance": distance,
		"required_range": required_range,
		"autopilot_started": autopilot_started,
		"message": message,
		"target": target
	}


func run_event_action_position_gate(event_id: String, event_data: Dictionary, button_packet: Dictionary, step_data: Dictionary, context: Dictionary = {}) -> Dictionary:
	var action_id := str(button_packet.get("action_id", button_packet.get("op", button_packet.get("type", ""))))
	if action_id == "":
		action_id = str(context.get("action_id", ""))

	if not event_position_gate_applies(action_id, button_packet, step_data, context):
		return {"status": "ok", "event_id": event_id, "action_id": action_id}

	var target := resolve_event_gate_target(event_data, step_data, button_packet)
	if target.is_empty():
		if bool(button_packet.get("requires_position_gate", step_data.get("requires_position_gate", false))):
			return {
				"status": "failed",
				"reason": "missing target",
				"event_id": event_id,
				"action_id": action_id,
				"message": "Event action blocked: no gate target was found."
			}
		return {"status": "ok", "event_id": event_id, "action_id": action_id}

	var required_range := resolve_event_gate_range(action_id, button_packet, step_data)
	if required_range <= 0.0:
		return {"status": "ok", "event_id": event_id, "action_id": action_id}

	if map == null:
		return {
			"status": "failed",
			"reason": "map missing",
			"event_id": event_id,
			"action_id": action_id,
			"message": "Event action blocked: map is not connected."
		}

	var sector := _read_sector_pos(target.get("sector_pos", Vector3i.ZERO))
	var local := _read_local_pos(target.get("local_pos", Vector3.ZERO))
	var distance := float(map.get_distance_to_target(sector, local))
	if distance <= required_range:
		return {"status": "ok", "event_id": event_id, "action_id": action_id}

	return build_event_position_gate_blocked_result(event_id, action_id, target, required_range, distance, context)


func handle_event_widget_action(button_packet: Dictionary) -> Dictionary:
	var event_id := str(button_packet.get("event_id", active_event_id))
	var action_id := str(button_packet.get("action_id", ""))
	request_event_pulse("event_button")
	var result := {
		"status": "failed",
		"reason": "",
		"event_id": event_id,
		"action_id": action_id
	}

	if action_id == "open_event_list":
		return show_event_list_popup()

	if action_id == "select_event":
		var target_event_id := str(button_packet.get("target_event_id", event_id))
		if target_event_id != "" and (active_events.has(target_event_id) or available_events.has(target_event_id)):
			var selection_changed := active_event_id != target_event_id
			active_event_id = target_event_id
			event_widget_dirty = true
			if selection_changed:
				save_event_runtime_state()
			return {
				"status": "success",
				"reason": "",
				"event_id": target_event_id,
				"action_id": action_id
			}
		result["reason"] = "missing selectable event"
		return result

	if action_id == "start_available_event" or action_id == "start_event":
		return handle_start_available_event(event_id, button_packet)

	if event_id == "" or not active_events.has(event_id):
		result["reason"] = "event is not active"
		write_event_log("Event action blocked: no active event.")
		return result

	var event_data: Dictionary = active_events[event_id]
	var current_step := str(event_data.get("current_step", ""))
	var step_data := get_step_data(event_data, current_step)
	var packet_step := str(button_packet.get("step_id", "")).strip_edges()
	if packet_step == "":
		result["reason"] = "missing step_id"
		write_event_log("Event action blocked: action packet is missing its step id.")
		return result
	if packet_step != current_step:
		result["reason"] = "stale step"
		result["expected_step"] = current_step
		result["packet_step"] = packet_step
		write_event_log("Event action blocked: stale event action for " + packet_step + " while current step is " + current_step + ".")
		return result

	if not event_intel_conditions_pass(event_data, button_packet, {
		"event_id": event_id,
		"step_id": current_step,
		"source": "event_widget_action",
		"action_id": action_id
	}):
		var blocked_message := str(button_packet.get("blocked_message", "Event action blocked: required intel condition is not complete.")).strip_edges()
		if blocked_message == "":
			blocked_message = "Event action blocked: required intel condition is not complete."
		result["status"] = "blocked"
		result["reason"] = "conditions not met"
		result["message"] = blocked_message
		write_event_log(blocked_message)
		event_widget_dirty = true
		request_event_pulse("event_condition_blocked")
		return result

	var gate_result := run_event_action_position_gate(event_id, event_data, button_packet, step_data, {
		"source": "event_widget_action"
	})
	if event_gate_result_blocks(gate_result):
		return gate_result

	match action_id:
		"download_beacon_data":
			return handle_download_beacon_data(event_id, event_data, button_packet)
		"claim_event_reward":
			return handle_claim_event_reward(event_id, event_data, button_packet)
		"show_story_popup", "story_popup":
			return handle_show_story_popup(event_id, event_data, button_packet)
		"show_tutorial_hint", "tutorial_hint", "show_helper_message":
			return handle_show_tutorial_hint(event_id, event_data, button_packet)
		"event_operations", "run_operations":
			return execute_event_action_operations(event_id, event_data, button_packet)
		"advance_step":
			var next_step := str(button_packet.get("next_step", get_step_data(event_data, str(event_data.get("current_step", ""))).get("next_step", "")))
			if next_step != "":
				return advance_event_to_step(event_id, next_step, {
					"source": "event_widget_action",
					"event_step": current_step,
					"action_id": action_id
				})
			result["reason"] = "missing next_step"
			return result
		_:
			if has_event_action_operations(button_packet):
				return execute_event_action_operations(event_id, event_data, button_packet)
			result["reason"] = "unknown event action"
			write_event_log("Event action not wired yet: " + action_id)
			return result


func handle_start_available_event(event_id: String, button_packet: Dictionary) -> Dictionary:
	var result := make_event_action_result(event_id, "start_available_event")
	if event_id == "":
		result["reason"] = "missing event_id"
		return result

	if active_events.has(event_id):
		active_event_id = event_id
		event_widget_dirty = true
		request_event_pulse("event_button")
		result["status"] = "success"
		result["reason"] = "event already active"
		return result

	if not available_events.has(event_id):
		result["reason"] = "event is not available"
		write_event_log("Event start blocked: event is not available.")
		return result

	var event_data: Dictionary = available_events[event_id].duplicate(true)
	var offer_step := str(event_data.get("current_step", "")).strip_edges()
	if offer_step == "":
		offer_step = get_event_offer_step(event_data)
	var offer_data := get_step_data(event_data, offer_step)
	if offer_data.is_empty():
		result["reason"] = "missing offer step"
		write_event_log("Event start blocked: available event step is missing.")
		return result

	var range := float(button_packet.get("range", offer_data.get("interaction_range", 120.0)))
	if range > 0.0 and not is_player_near_step_target(event_data, offer_data, range):
		result["reason"] = "too far"
		write_event_log("Event start blocked: move closer to the event contact.")
		return result

	var start_step := resolve_available_event_start_step(event_data, button_packet)
	if start_step == "":
		result["reason"] = "missing start step"
		write_event_log("Event start blocked: no valid start step.")
		return result

	if offer_step != "" and offer_step != start_step:
		mark_step_completed_on_event_data(event_data, offer_step)

	event_data["event_state"] = "active"
	event_data["current_step"] = start_step
	active_events[event_id] = event_data
	available_events.erase(event_id)
	active_event_id = event_id

	create_event_beacon_if_needed(event_data)
	sync_event_state_to_world(event_data)
	save_event_world_state()
	event_widget_dirty = true
	request_event_pulse("event_button")

	result["status"] = "success"
	result["next_step"] = start_step
	write_event_log("EVENT STARTED\n" + str(event_data.get("display_name", event_id)))
	return result


func resolve_available_event_start_step(event_data: Dictionary, button_packet: Dictionary) -> String:
	var steps = event_data.get("steps", {})
	var authored_start := resolve_event_start_step(event_data)
	for key in ["next_step", "event_next_step", "start_step"]:
		var candidate := str(button_packet.get(key, "")).strip_edges()
		if candidate != "" and candidate == authored_start and typeof(steps) == TYPE_DICTIONARY and steps.has(candidate):
			return candidate

	if authored_start != "" and typeof(steps) == TYPE_DICTIONARY and steps.has(authored_start):
		return authored_start

	return ""


func show_event_list_popup() -> Dictionary:
	if widget_builder == null:
		return {"status": "failed", "action_id": "open_event_list", "reason": "missing widget_builder"}
	if not widget_builder.has_method("show_event_list_popup"):
		return {"status": "failed", "action_id": "open_event_list", "reason": "missing show_event_list_popup"}

	return widget_builder.show_event_list_popup({
		"title": "EVENTS",
		"selected_event_id": active_event_id,
		"event_list": build_event_widget_event_list()
	})


func process_pending_battle_v2_result() -> void:
	if Globals.last_battle_v2_result.is_empty():
		return

	var result := Globals.last_battle_v2_result.duplicate(true)

	var outcome := str(result.get("outcome", ""))
	if outcome != "player_victory":
		print("[EVENT_BATTLE_RESULT] ignored non-victory outcome=", outcome)
		Globals.last_battle_v2_result.clear()
		return

	var shared_meta = result.get("defeated_enemy_shared_meta", {})
	if typeof(shared_meta) != TYPE_DICTIONARY:
		shared_meta = {}
	shared_meta = shared_meta.duplicate(true)

	var authored_context := get_battle_result_authored_context(result)
	shared_meta = merge_battle_result_context_into_shared_meta(shared_meta, authored_context)

	var event_id := resolve_battle_result_event_id(result, shared_meta, authored_context)
	var result_step := str(shared_meta.get("result_step", shared_meta.get("event_step", ""))).strip_edges()
	if result_step == "":
		result_step = str(shared_meta.get("current_step", shared_meta.get("required_step", ""))).strip_edges()
	if result_step == "":
		result_step = str(authored_context.get("event_step", authored_context.get("current_step", authored_context.get("required_step", "")))).strip_edges()
	var required_step := str(shared_meta.get("required_step", "")).strip_edges()
	if required_step == "":
		required_step = str(authored_context.get("required_step", result_step)).strip_edges()

	if event_id != "":
		shared_meta["event_id"] = event_id
		shared_meta["active_event_id"] = event_id
	if result_step != "":
		shared_meta["event_step"] = result_step
		shared_meta["current_step"] = result_step
	if required_step != "":
		shared_meta["required_step"] = required_step

	print(
		"[EVENT_BATTLE_RESULT]",
		" raw outcome=", outcome,
		" battle_id=", result.get("battle_id", ""),
		" defeated_enemy_id=", shared_meta.get("object_id", ""),
		" event_id=", event_id,
		" result_step=", result_step,
		" required_step=", required_step
	)

	if event_id == "":
		# Free-roam / debug enemies are valid Battle V2 victories, but they do not
		# belong to an authored event step.  The old behavior held this result
		# forever, which made execute_event_checks() return every frame and left
		# the event widget orphaned.
		if not battle_result_has_event_scope_claim(result, shared_meta, authored_context, result_step, required_step):
			print(
				"[EVENT_BATTLE_RESULT] consumed free-roam battle result; no authored event scope.",
				" battle_id=",
				result.get("battle_id", ""),
				" defeated_enemy_id=",
				get_battle_result_defeated_object_id(result, shared_meta, authored_context)
			)
			Globals.last_battle_v2_result.clear()
			event_widget_dirty = true
			return

		print("[EVENT_BATTLE_RESULT] held authored victory result; missing event_id. active=", active_events.keys())
		return

	if not active_events.has(event_id):
		print(
			"[EVENT_BATTLE_RESULT] cleared stale event result; event not active event_id=",
			event_id,
			" active=",
			active_events.keys()
		)
		Globals.last_battle_v2_result.clear()
		return

	var event_data: Dictionary = active_events[event_id]
	var current_step := str(event_data.get("current_step", ""))
	var step_data := get_step_data(event_data, current_step)

	if result_step != "" and result_step != current_step:
		print(
			"[EVENT_BATTLE_RESULT] cleared stale event result; result_step mismatch result=",
			result_step,
			" current=",
			current_step
		)
		Globals.last_battle_v2_result.clear()
		return

	if required_step != "" and required_step != current_step:
		print(
			"[EVENT_BATTLE_RESULT] cleared stale event result; required_step mismatch required=",
			required_step,
			" current=",
			current_step
		)
		Globals.last_battle_v2_result.clear()
		return

	if result_step == "" and required_step == "":
		print(
			"[EVENT_BATTLE_RESULT] cleared event result; missing authored step claim event_id=",
			event_id,
			" current=",
			current_step
		)
		Globals.last_battle_v2_result.clear()
		return

	shared_meta["event_step"] = current_step
	shared_meta["current_step"] = current_step
	shared_meta["required_step"] = current_step

	if not step_completes_on_battle_victory(step_data, shared_meta):
		print(
			"[EVENT_BATTLE_RESULT] cleared event result; step does not complete on battle victory event_id=",
			event_id,
			" step=",
			current_step
		)
		Globals.last_battle_v2_result.clear()
		return

	if typeof(step_data.get("on_battle_victory", [])) == TYPE_ARRAY:
		var operation_result := execute_event_operations(event_id, event_data, step_data.get("on_battle_victory", []), {
			"source": "battle_v2_result",
			"event_step": current_step,
			"required_step": current_step,
			"battle_result": result
		})
		if event_operation_result_succeeded(operation_result):
			save_event_world_state()
	else:
		var next_step := str(step_data.get("next_step", "download_beacon_data"))
		var advance_result := advance_event_to_step(event_id, next_step, {
			"source": "battle_v2_result",
			"event_step": current_step,
			"required_step": current_step,
			"save_mode": "full"
		})
		if str(advance_result.get("status", "")) == "success":
			write_event_log("Signal guardian defeated.\nBeacon data link is now safe to access.")

	print(
		"[EVENT_BATTLE_RESULT] consumed event battle result event_id=",
		event_id,
		" step=",
		current_step
	)

	Globals.last_battle_v2_result.clear()

func process_active_event_progress() -> void:
	if Globals.battle_mode or Globals.battle_pending:
		return

	for event_id in active_events.keys():
		var event_data: Dictionary = active_events[event_id]
		var current_step := str(event_data.get("current_step", ""))
		process_event_step_triggers(str(event_id), event_data, current_step)


func process_event_step_triggers(event_id: String, event_data: Dictionary, current_step: String) -> void:
	var step_data := get_step_data(event_data, current_step)
	if step_data.is_empty():
		if current_step == "completed" or bool(event_data.get("completed", false)):
			complete_event(event_id, event_data)
			save_event_runtime_state()
		return

	if try_skip_completed_step_replay(event_id, event_data, current_step, step_data):
		return

	if not event_intel_conditions_pass(event_data, step_data, {"event_id": event_id, "step_id": current_step, "source": "event_step"}):
		return

	if should_auto_complete_terminal_step(event_data, current_step, step_data):
		complete_event(event_id, event_data)
		save_event_runtime_state()
		return

	if step_has_enter_behavior(current_step, step_data):
		run_step_enter_operations(event_id, event_data, current_step)
		if not active_events.has(event_id):
			return

		event_data = active_events[event_id]
		if str(event_data.get("current_step", "")) != current_step:
			return
		if Globals.battle_mode or Globals.battle_pending:
			return

	if step_data.has("arrival_range"):
		process_event_arrival_step(event_id, event_data, current_step, step_data)

	match current_step:
		"go_to_beacon":
			if not step_data.has("arrival_range"):
				process_go_to_beacon_step(event_id, event_data)


func process_event_arrival_step(event_id: String, event_data: Dictionary, current_step: String, step_data: Dictionary) -> void:
	var trigger_range := float(step_data.get("arrival_range", 45.0))
	if not is_player_near_step_target(event_data, step_data, trigger_range):
		return

	var arrival_flag := "arrived_" + current_step
	var next_step := str(step_data.get("next_step", ""))
	var arrival_operations = step_data.get("on_arrival", [])
	var has_arrival_operations := false
	if typeof(arrival_operations) == TYPE_ARRAY:
		has_arrival_operations = not arrival_operations.is_empty()

	if bool(get_event_flag(event_data, arrival_flag, false)):
		var can_recover_marked_arrival := next_step != "" and not has_arrival_operations
		if has_arrival_operations:
			can_recover_marked_arrival = event_operations_include_step_change(arrival_operations)
		if not can_recover_marked_arrival:
			return
		# A saved arrival flag with the same current step means the old run marked
		# arrival before the step advanced. Let the step recover instead of trapping it.

	if has_arrival_operations:
		var operation_result := execute_event_operations(event_id, event_data, arrival_operations, {
			"source": "arrival",
			"step_id": current_step
		})
		if event_operation_result_succeeded(operation_result):
			set_event_flag(event_id, arrival_flag, true)
		return

	if next_step != "":
		advance_event_to_step(event_id, next_step, {
			"source": "arrival",
			"event_step": current_step,
			"required_step": current_step
		})
		return

	set_event_flag(event_id, arrival_flag, true)


func process_go_to_beacon_step(event_id: String, event_data: Dictionary) -> void:
	var step_data := get_step_data(event_data, "go_to_beacon")
	if step_data.is_empty():
		return

	var trigger_range := float(step_data.get("arrival_range", 45.0))
	if not is_player_near_step_target(event_data, step_data, trigger_range):
		return

	var next_step := str(step_data.get("next_step", "defeat_guardian"))
	advance_event_to_step(event_id, next_step, {
		"source": "go_to_beacon",
		"event_step": "go_to_beacon",
		"required_step": "go_to_beacon"
	})


func begin_event_guardian_battle(event_id: String, event_data: Dictionary) -> Dictionary:
	var step_data := get_step_data(event_data, "defeat_guardian")
	var enemy_object_id := str(step_data.get("enemy_id", step_data.get("target_object_id", "event_guardian_001")))
	return start_event_battle_from_operation(event_id, event_data, {
		"op": "start_battle",
		"action_id": "start_battle",
		"step_id": "defeat_guardian",
		"enemy_id": enemy_object_id,
		"entry_reason": "event_guardian_" + event_id,
		"message": "Signal guardian intercepted the beacon link."
	})


func handle_download_beacon_data(event_id: String, event_data: Dictionary, button_packet: Dictionary) -> Dictionary:
	var result := make_event_action_result(event_id, "download_beacon_data")
	var current_step := str(event_data.get("current_step", ""))
	var step_data := get_step_data(event_data, current_step)
	if step_data.is_empty():
		result["reason"] = "missing step"
		write_event_log("Download blocked: event step is missing.")
		return result

	var range := float(button_packet.get("range", step_data.get("interaction_range", 60.0)))
	if not is_player_near_step_target(event_data, step_data, range):
		result["reason"] = "too far"
		write_event_log("Download blocked: move closer to the event target.")
		return result

	var required_item := str(step_data.get("requires_item", ""))
	var gives_item := str(step_data.get("gives_item", ""))
	var download_next_step := str(step_data.get("next_step", "return_to_npc"))

	if inventory == null:
		result["reason"] = "inventory missing"
		write_event_log("Download blocked: inventory is not connected.")
		return result

	if required_item != "" and not inventory.has_item_anywhere(required_item):
		if gives_item != "" and inventory.has_item_anywhere(gives_item):
			var already_advance := advance_event_to_step(event_id, download_next_step, {
				"source": "download_beacon_data",
				"event_step": current_step,
				"required_step": current_step
			})
			result["status"] = str(already_advance.get("status", "failed"))
			result["reason"] = "already has downloaded item" if result["status"] == "success" else str(already_advance.get("reason", "advance blocked"))
			return result
		result["reason"] = "missing item"
		write_event_log("Download blocked: missing " + required_item)
		return result

	var preflight_result := validate_event_step_transition(event_id, event_data, current_step, download_next_step, {
		"source": "download_beacon_data",
		"event_step": current_step,
		"required_step": current_step
	})
	if str(preflight_result.get("status", "")) != "success":
		result["reason"] = str(preflight_result.get("reason", "advance blocked"))
		write_event_log("Download blocked: " + result["reason"])
		return result

	var consumed_required_item := false
	if required_item != "":
		consumed_required_item = bool(inventory.consume_item(required_item, 1))
		if not consumed_required_item:
			result["reason"] = "consume failed"
			write_event_log("Download blocked: could not consume " + required_item)
			return result

	if gives_item != "":
		var added_item := bool(inventory.add_item(gives_item, 1, "event_reward_download"))
		if not added_item:
			if consumed_required_item:
				inventory.add_item(required_item, 1, "event_reward_restore")
			result["reason"] = "inventory full"
			write_event_log("Download blocked: inventory could not receive " + gives_item)
			return result

	var beacon_completed := mark_event_beacon_completed(event_data, step_data)
	var advance_result := advance_event_to_step(event_id, download_next_step, {
		"source": "download_beacon_data",
		"event_step": current_step,
		"required_step": current_step,
		"save_mode": "defer"
	})
	if str(advance_result.get("status", "")) != "success":
		result["reason"] = str(advance_result.get("reason", "advance blocked"))
		return result
	write_event_log("EVENT DOWNLOAD COMPLETE\nEvent item updated. Continue to the next objective.")

	result["status"] = "success"
	if beacon_completed:
		save_event_world_state()
	else:
		save_event_reward_runtime_state()
	return result


func handle_claim_event_reward(event_id: String, event_data: Dictionary, button_packet: Dictionary) -> Dictionary:
	var result := make_event_action_result(event_id, "claim_event_reward")
	var current_step := str(event_data.get("current_step", ""))
	var step_data := get_step_data(event_data, current_step)
	if step_data.is_empty():
		result["reason"] = "missing step"
		write_event_log("Reward blocked: event step is missing.")
		return result

	var range := float(button_packet.get("range", step_data.get("interaction_range", 70.0)))
	if not is_player_near_step_target(event_data, step_data, range):
		result["reason"] = "too far"
		write_event_log("Reward blocked: return to the event target.")
		return result

	var required_item := str(step_data.get("requires_item", ""))
	if required_item != "" and inventory != null and not inventory.has_item_anywhere(required_item):
		result["reason"] = "missing item"
		write_event_log("Reward blocked: missing " + required_item)
		return result

	if required_item != "" and inventory != null:
		inventory.consume_item(required_item, 1)

	grant_event_reward(event_data)
	complete_event(event_id, event_data)

	result["status"] = "success"
	save_event_reward_runtime_state()
	return result


func has_event_action_operations(button_packet: Dictionary) -> bool:
	if button_packet.has("operations") and typeof(button_packet.get("operations")) == TYPE_ARRAY:
		return true
	if button_packet.has("operation") and typeof(button_packet.get("operation")) == TYPE_DICTIONARY:
		return true
	if button_packet.has("popup") and typeof(button_packet.get("popup")) == TYPE_DICTIONARY:
		return true
	if button_packet.has("tutorial") and typeof(button_packet.get("tutorial")) == TYPE_DICTIONARY:
		return true
	return false


func execute_event_action_operations(event_id: String, event_data: Dictionary, button_packet: Dictionary) -> Dictionary:
	var result := make_event_action_result(event_id, str(button_packet.get("action_id", "event_operations")))
	var operations := []

	if button_packet.has("operations") and typeof(button_packet.get("operations")) == TYPE_ARRAY:
		operations = button_packet.get("operations", []).duplicate(true)
	elif button_packet.has("operation") and typeof(button_packet.get("operation")) == TYPE_DICTIONARY:
		operations.append(button_packet.get("operation", {}).duplicate(true))

	if button_packet.has("popup") and typeof(button_packet.get("popup")) == TYPE_DICTIONARY:
		var popup_op: Dictionary = button_packet.get("popup", {}).duplicate(true)
		popup_op["op"] = str(popup_op.get("op", "show_story_popup"))
		operations.append(popup_op)

	if button_packet.has("tutorial") and typeof(button_packet.get("tutorial")) == TYPE_DICTIONARY:
		var tutorial_op: Dictionary = button_packet.get("tutorial", {}).duplicate(true)
		tutorial_op["op"] = str(tutorial_op.get("op", "show_tutorial_hint"))
		operations.append(tutorial_op)

	if operations.is_empty():
		result["reason"] = "missing operations"
		return result

	return execute_event_operations(event_id, event_data, operations, {
		"source": "event_widget_action",
		"button_packet": button_packet
	})


func execute_event_operations(event_id: String, event_data: Dictionary, operations: Array, context: Dictionary = {}) -> Dictionary:
	var result := {
		"status": "success",
		"event_id": event_id,
		"operation_results": []
	}

	for operation in operations:
		if typeof(operation) != TYPE_DICTIONARY:
			continue
		if active_events.has(event_id):
			event_data = active_events[event_id]

		var op_result := execute_event_operation(event_id, event_data, operation, context)
		result["operation_results"].append(op_result)
		if str(op_result.get("status", "success")) == "failed":
			result["status"] = "partial"

	if active_events.has(event_id):
		event_data = active_events[event_id]

	event_widget_dirty = true
	request_event_pulse(str(context.get("source", "event_state_changed")))
	return result


func event_operation_result_succeeded(result: Dictionary) -> bool:
	var status := str(result.get("status", "success"))
	if status == "failed":
		return false
	if status == "partial":
		var operation_results = result.get("operation_results", [])
		if typeof(operation_results) != TYPE_ARRAY:
			return false
		for op_result in operation_results:
			if typeof(op_result) == TYPE_DICTIONARY and str(op_result.get("status", "success")) == "success":
				return true
		return false
	return true


func should_mark_step_entered_after_operations(result: Dictionary) -> bool:
	var operation_results = result.get("operation_results", [])
	if typeof(operation_results) != TYPE_ARRAY:
		return event_operation_result_succeeded(result)

	var saw_operation := false
	var saw_success := false
	var saw_battle_operation := false
	var battle_started := false

	for op_result in operation_results:
		if typeof(op_result) != TYPE_DICTIONARY:
			continue

		saw_operation = true
		var op_id := str(op_result.get("op", ""))
		var status := str(op_result.get("status", "success"))
		var is_battle_operation := op_id == "start_battle" or op_id == "start_hunt_battle"
		if not is_battle_operation:
			is_battle_operation = op_result.has("enemy_id") and op_result.has("entry_reason")

		if is_battle_operation:
			saw_battle_operation = true
			if status == "success":
				battle_started = true

		if status == "success":
			saw_success = true

	if saw_battle_operation:
		return battle_started
	if saw_operation:
		return saw_success

	return event_operation_result_succeeded(result)


func step_has_enter_behavior(step_id: String, step_data: Dictionary) -> bool:
	var operations = step_data.get("on_enter", [])
	if typeof(operations) == TYPE_ARRAY and not operations.is_empty():
		return true
	return step_id == "defeat_guardian"


func event_operations_include_step_change(operations) -> bool:
	if typeof(operations) != TYPE_ARRAY:
		return false

	for operation in operations:
		if typeof(operation) != TYPE_DICTIONARY:
			continue

		var op_id := str(operation.get("op", operation.get("type", operation.get("action", "")))).strip_edges().to_lower()
		if op_id == "":
			op_id = str(operation.get("action_id", "")).strip_edges().to_lower()
		if op_id == "advance_step":
			return true

	return false


func execute_event_operation(event_id: String, event_data: Dictionary, operation: Dictionary, context: Dictionary = {}) -> Dictionary:
	var op_id := str(operation.get("op", operation.get("type", operation.get("action", "")))).strip_edges().to_lower()
	if op_id == "":
		op_id = str(operation.get("action_id", "")).strip_edges().to_lower()

	match op_id:
		"write_log", "log":
			write_event_log(str(operation.get("message", operation.get("text", ""))))
			return {"status": "success", "op": op_id}
		"show_story_popup", "story_popup":
			return handle_show_story_popup(event_id, event_data, operation)
		"show_tutorial_hint", "tutorial_hint", "show_helper_message":
			return handle_show_tutorial_hint(event_id, event_data, operation)
		"update_npc_dialogue", "set_npc_dialogue", "set_npc_talk_lines", "update_npc_contact", "set_npc_contact", "set_npc_actions":
			return apply_npc_dialogue_update(event_data, operation, {
				"source": "event_operation",
				"event_id": event_id
			})
		"remove_npc", "despawn_npc", "delete_npc":
			return handle_remove_npc_operation(event_id, event_data, operation)
		"spawn_npc", "install_npc", "refresh_npc", "refresh_npc_context", "replace_npc", "swap_npc", "reload_npc":
			return handle_replace_npc_operation(event_id, event_data, operation)
		"advance_step":
			var expected_step := str(operation.get(
				"required_step",
				operation.get("event_step", context.get("event_step", context.get("step_id", "")))
			)).strip_edges()
			if expected_step != "":
				var live_event_data := get_display_event_data(event_id)
				var live_step := str(live_event_data.get("current_step", event_data.get("current_step", ""))).strip_edges()
				if live_step != "" and live_step != expected_step:
					return {
						"status": "failed",
						"op": op_id,
						"reason": "step mismatch",
						"expected_step": expected_step,
						"current_step": live_step,
						"story_popup_token": str(operation.get("story_popup_token", context.get("story_popup_token", "")))
					}
				if not live_event_data.is_empty():
					event_data = live_event_data
			var next_step := str(operation.get("next_step", get_step_data(event_data, str(event_data.get("current_step", ""))).get("next_step", "")))
			if next_step == "":
				return {"status": "failed", "op": op_id, "reason": "missing next_step"}
			var advance_result := advance_event_to_step(event_id, next_step, {
				"source": str(context.get("source", "event_operation")),
				"event_step": expected_step,
				"required_step": expected_step,
				"story_popup_token": str(operation.get("story_popup_token", context.get("story_popup_token", "")))
			})
			advance_result["op"] = op_id
			return advance_result
		"start_battle", "start_hunt_battle":
			return start_event_battle_from_operation(event_id, event_data, operation, context)
		"install_event_object", "spawn_event_object":
			var object_id := str(operation.get("object_id", operation.get("target_object_id", "")))
			if object_id == "":
				return {"status": "failed", "op": op_id, "reason": "missing object_id"}
			var event_objects: Dictionary = event_data.get("event_objects", {})
			if not event_objects.has(object_id):
				return {"status": "failed", "op": op_id, "reason": "missing event object"}
			var installed = world_builder.install_event_object(object_id, event_objects[object_id], event_data)
			var status := "success" if installed != null else "failed"
			if status == "success":
				event_widget_dirty = true
				request_event_pulse("event_object_installed")
			return {"status": status, "op": op_id, "object_id": object_id}
		"set_flag":
			var flag_id := str(operation.get("flag_id", operation.get("key", "")))
			if flag_id == "":
				return {"status": "failed", "op": op_id, "reason": "missing flag_id"}
			set_event_flag(event_id, flag_id, operation.get("value", true))
			return {"status": "success", "op": op_id, "flag_id": flag_id}
		_:
			return {"status": "failed", "op": op_id, "reason": "unknown operation"}


func handle_remove_npc_operation(event_id: String, event_data: Dictionary, operation: Dictionary) -> Dictionary:
	var target_id := resolve_npc_operation_target_id(operation, event_data)
	if target_id == "":
		return {
			"status": "failed",
			"op": str(operation.get("op", "remove_npc")),
			"reason": "missing target npc id",
			"event_id": event_id,
			"labels": ["event_npc_remove_failed"]
		}

	var removed := remove_runtime_npc_by_story_id(target_id)
	var allow_missing := bool(operation.get("allow_missing", true))
	if not removed and not allow_missing:
		return {
			"status": "failed",
			"op": str(operation.get("op", "remove_npc")),
			"reason": "target npc not found",
			"target_object_id": target_id,
			"event_id": event_id,
			"labels": ["event_npc_remove_failed"]
		}

	mark_event_npc_runtime_removed(event_id, event_data, target_id, operation)
	if bool(operation.get("save", operation.get("save_world", true))):
		save_event_world_state()
	event_widget_dirty = true

	return {
		"status": "success",
		"op": str(operation.get("op", "remove_npc")),
		"target_object_id": target_id,
		"removed": removed,
		"reason": "removed" if removed else "already missing",
		"event_id": event_id,
		"labels": ["event_npc_removed"]
	}


func handle_replace_npc_operation(event_id: String, event_data: Dictionary, operation: Dictionary) -> Dictionary:
	var op_name := str(operation.get("op", operation.get("type", operation.get("action", "replace_npc")))).strip_edges().to_lower()
	var target_id := resolve_npc_operation_target_id(operation, event_data)
	var replacement_id := resolve_npc_operation_replacement_id(operation, target_id, op_name)

	if replacement_id == "":
		return {
			"status": "failed",
			"op": op_name,
			"reason": "missing replacement npc id",
			"event_id": event_id,
			"labels": ["event_npc_replace_failed"]
		}

	var object_data := build_npc_object_data_for_operation(event_id, event_data, operation, replacement_id, target_id)
	if object_data.is_empty():
		return {
			"status": "failed",
			"op": op_name,
			"reason": "missing npc object data",
			"replacement_object_id": replacement_id,
			"event_id": event_id,
			"labels": ["event_npc_replace_failed"]
		}

	var force_recreate := bool(operation.get("force_recreate", false))
	var should_remove_existing := bool(operation.get("remove_existing", false)) or bool(operation.get("remove_target", false))
	should_remove_existing = should_remove_existing or op_name == "replace_npc" or op_name == "swap_npc"
	if should_remove_existing and target_id != "" and (target_id != replacement_id or force_recreate):
		remove_runtime_npc_by_story_id(target_id)
		mark_event_npc_runtime_removed(event_id, event_data, target_id, operation)
	elif force_recreate and replacement_id != "":
		remove_runtime_npc_by_story_id(replacement_id)

	if world_builder == null:
		return {"status": "failed", "op": op_name, "reason": "missing world_builder", "event_id": event_id}

	var event_objects: Dictionary = event_data.get("event_objects", {}) if typeof(event_data.get("event_objects", {})) == TYPE_DICTIONARY else {}
	if bool(operation.get("store_event_object", true)):
		event_objects[replacement_id] = object_data
		event_data["event_objects"] = event_objects
		if active_events.has(event_id):
			active_events[event_id] = event_data

	var installed = world_builder.install_event_object(replacement_id, object_data, event_data)
	if installed == null:
		return {
			"status": "failed",
			"op": op_name,
			"reason": "npc install failed",
			"replacement_object_id": replacement_id,
			"event_id": event_id,
			"labels": ["event_npc_replace_failed"]
		}

	var dialogue_result := {}
	if dialogue_packet_has_content(operation):
		dialogue_result = apply_npc_dialogue_update_to_npc(installed, operation, {
			"source": op_name,
			"event_id": event_id,
			"step_id": str(event_data.get("current_step", ""))
		})

	if bool(operation.get("save", operation.get("save_world", true))):
		sync_event_state_to_world(event_data)
		save_event_world_state()
	event_widget_dirty = true

	return {
		"status": "success",
		"op": op_name,
		"target_object_id": target_id,
		"replacement_object_id": replacement_id,
		"npc_id": str(installed.get_meta("npc_id", installed.object_id)),
		"dialogue_result": dialogue_result,
		"event_id": event_id,
		"labels": ["event_npc_replaced"]
	}


func resolve_npc_operation_target_id(operation: Dictionary, event_data: Dictionary) -> String:
	for key in ["target_object_id", "target_owner_id", "remove_object_id", "remove_npc_id", "old_object_id", "old_npc_id", "npc_id", "owner_id", "object_id"]:
		var value := str(operation.get(key, "")).strip_edges()
		if value != "":
			return value
	var current_step := str(event_data.get("current_step", ""))
	var step_data := get_step_data(event_data, current_step)
	for key in ["target_object_id", "target_owner_id", "npc_dialogue_target_owner_id", "npc_id"]:
		var step_value := str(step_data.get(key, "")).strip_edges()
		if step_value != "":
			return step_value
	return get_event_giver_owner_id(event_data)


func resolve_npc_operation_replacement_id(operation: Dictionary, target_id: String, op_name: String) -> String:
	for key in ["replacement_object_id", "replacement_npc_id", "new_object_id", "new_npc_id", "spawn_object_id", "spawn_npc_id"]:
		var value := str(operation.get(key, "")).strip_edges()
		if value != "":
			return value
	if op_name == "spawn_npc" or op_name == "install_npc":
		for key in ["object_id", "npc_id", "target_object_id"]:
			var spawn_value := str(operation.get(key, "")).strip_edges()
			if spawn_value != "":
				return spawn_value
	if target_id != "":
		return target_id
	var inline_data = operation.get("npc_data", operation.get("object_data", operation.get("replacement_data", {})))
	if typeof(inline_data) == TYPE_DICTIONARY:
		for key in ["object_id", "npc_id", "owner_id", "blueprint_id"]:
			var inline_value := str(inline_data.get(key, "")).strip_edges()
			if inline_value != "":
				return inline_value
	return ""


func build_npc_object_data_for_operation(event_id: String, event_data: Dictionary, operation: Dictionary, replacement_id: String, target_id: String) -> Dictionary:
	var event_objects: Dictionary = event_data.get("event_objects", {}) if typeof(event_data.get("event_objects", {})) == TYPE_DICTIONARY else {}
	var object_data := {}
	var inline_data = operation.get("npc_data", operation.get("object_data", operation.get("replacement_data", {})))

	if replacement_id != "" and event_objects.has(replacement_id) and typeof(event_objects[replacement_id]) == TYPE_DICTIONARY:
		object_data = event_objects[replacement_id].duplicate(true)
	elif typeof(inline_data) == TYPE_DICTIONARY:
		object_data = inline_data.duplicate(true)
	elif target_id != "" and event_objects.has(target_id) and typeof(event_objects[target_id]) == TYPE_DICTIONARY:
		object_data = event_objects[target_id].duplicate(true)
	else:
		object_data = {}

	merge_npc_operation_overrides(object_data, operation)

	var clean_id := replacement_id
	if clean_id == "":
		clean_id = str(object_data.get("object_id", object_data.get("npc_id", target_id))).strip_edges()
	if clean_id == "":
		return {}

	object_data.erase("runtime_removed")
	object_data.erase("is_removed")
	if not object_data.has("is_visible"):
		object_data["is_visible"] = true
	object_data["owner_type"] = "npc"
	object_data["object_type"] = "npc"
	object_data["object_id"] = clean_id
	object_data["npc_id"] = clean_id
	if str(object_data.get("owner_id", "")).strip_edges() == "":
		object_data["owner_id"] = clean_id
	if str(object_data.get("template_owner_id", "")).strip_edges() == "":
		object_data["template_owner_id"] = clean_id
	if str(object_data.get("blueprint_id", "")).strip_edges() == "":
		object_data["blueprint_id"] = clean_id
	if str(object_data.get("display_name", object_data.get("name", ""))).strip_edges() == "":
		object_data["display_name"] = clean_id.capitalize()
	if str(object_data.get("event_id", "")).strip_edges() == "":
		object_data["event_id"] = event_id
	if str(object_data.get("active_event_id", "")).strip_edges() == "":
		object_data["active_event_id"] = event_id
	if not object_data.has("has_event"):
		object_data["has_event"] = event_id != ""
	if str(object_data.get("event_state", "")).strip_edges() == "":
		object_data["event_state"] = str(event_data.get("event_state", "active"))
	if str(object_data.get("event_step", "")).strip_edges() == "":
		object_data["event_step"] = str(event_data.get("current_step", ""))
	if str(object_data.get("current_step", "")).strip_edges() == "":
		object_data["current_step"] = str(event_data.get("current_step", ""))

	var labels := SharedObjectMeta.read_array(object_data.get("labels", []))
	for label in ["npc", "event_object", "story_npc", clean_id, event_id, "authored_object"]:
		if str(label).strip_edges() != "" and not labels.has(str(label)):
			labels.append(str(label))
	object_data["labels"] = labels
	return object_data


func merge_npc_operation_overrides(object_data: Dictionary, operation: Dictionary) -> void:
	var controls := npc_operation_control_keys()
	for key in operation.keys():
		var clean_key := str(key)
		if controls.has(clean_key):
			continue
		object_data[clean_key] = operation[key]

	for update_key in ["updates", "npc_updates", "replacement_updates"]:
		var updates = operation.get(update_key, {})
		if typeof(updates) == TYPE_DICTIONARY:
			for key in updates.keys():
				object_data[key] = updates[key]

	for talk_key in ["talk_meta", "npc_meta", "contact_meta", "trade_meta"]:
		var talk_data = operation.get(talk_key, {})
		if typeof(talk_data) == TYPE_DICTIONARY:
			var existing = object_data.get(talk_key, {})
			var merged := {}
			if typeof(existing) == TYPE_DICTIONARY:
				merged = existing.duplicate(true)
			for key in talk_data.keys():
				merged[key] = talk_data[key]
			object_data[talk_key] = merged


func npc_operation_control_keys() -> Array:
	return [
		"op", "type", "action", "action_id", "target_object_id", "target_owner_id",
		"remove_object_id", "remove_npc_id", "old_object_id", "old_npc_id",
		"replacement_object_id", "replacement_npc_id", "new_object_id", "new_npc_id",
		"spawn_object_id", "spawn_npc_id", "npc_data", "object_data", "replacement_data",
		"updates", "npc_updates", "replacement_updates", "allow_missing", "remove_existing",
		"remove_target", "force_recreate", "store_event_object", "save", "save_world"
	]


func mark_event_npc_runtime_removed(event_id: String, event_data: Dictionary, target_id: String, operation: Dictionary) -> void:
	if target_id == "":
		return
	var event_objects: Dictionary = event_data.get("event_objects", {}) if typeof(event_data.get("event_objects", {})) == TYPE_DICTIONARY else {}
	if not event_objects.has(target_id) or typeof(event_objects[target_id]) != TYPE_DICTIONARY:
		return
	var object_data: Dictionary = event_objects[target_id]
	object_data["runtime_removed"] = true
	object_data["is_visible"] = false
	if bool(operation.get("clear_event_on_remove", false)):
		object_data["has_event"] = false
		object_data["event_state"] = "removed"
	if bool(operation.get("erase_event_object", false)):
		event_objects.erase(target_id)
	else:
		event_objects[target_id] = object_data
	event_data["event_objects"] = event_objects
	if active_events.has(event_id):
		active_events[event_id] = event_data


func find_runtime_npc_by_story_id(npc_id: String):
	var clean_id := str(npc_id).strip_edges()
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


func remove_runtime_npc_by_story_id(npc_id: String) -> bool:
	var clean_id := str(npc_id).strip_edges()
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


func sanitize_story_popup_token_part(value: String) -> String:
	var text := value.strip_edges().to_lower()
	if text == "":
		return "popup"

	var out := ""
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		var code := ch.unicode_at(0)
		var is_digit := code >= 48 and code <= 57
		var is_lower := code >= 97 and code <= 122
		if is_digit or is_lower:
			out += ch
		else:
			out += "_"

	while out.find("__") >= 0:
		out = out.replace("__", "_")
	while out.length() > 0 and out.begins_with("_"):
		out = out.substr(1)
	while out.length() > 0 and out.ends_with("_"):
		out = out.substr(0, out.length() - 1)
	if out == "":
		return "popup"
	return out


func build_event_story_popup_token(event_id: String, event_step: String) -> String:
	story_popup_token_sequence += 1
	var event_part := sanitize_story_popup_token_part(event_id)
	var step_part := sanitize_story_popup_token_part(event_step)
	return event_part + "_" + step_part + "_" + str(Time.get_ticks_msec()) + "_" + str(story_popup_token_sequence)


func stamp_story_popup_close_operations(operations: Array, event_step: String, story_popup_token: String) -> Array:
	var stamped: Array = []
	for operation in operations:
		if typeof(operation) != TYPE_DICTIONARY:
			continue

		var op_copy: Dictionary = operation.duplicate(true)
		op_copy["story_popup_token"] = story_popup_token
		var op_id := str(op_copy.get("op", op_copy.get("type", op_copy.get("action", "")))).strip_edges().to_lower()
		if op_id == "":
			op_id = str(op_copy.get("action_id", "")).strip_edges().to_lower()
		if op_id == "advance_step" and event_step != "":
			op_copy["event_step"] = str(op_copy.get("event_step", event_step))
			op_copy["required_step"] = str(op_copy.get("required_step", event_step))

		stamped.append(op_copy)
	return stamped


func handle_show_story_popup(event_id: String, event_data: Dictionary, packet: Dictionary) -> Dictionary:
	if widget_builder == null:
		return {"status": "failed", "event_id": event_id, "reason": "missing widget_builder"}
	if not widget_builder.has_method("show_story_popup"):
		return {"status": "failed", "event_id": event_id, "reason": "widget_builder missing show_story_popup"}

	var outer_packet := packet.duplicate(true)
	var popup_packet := outer_packet.duplicate(true)
	if outer_packet.has("popup") and typeof(outer_packet.get("popup")) == TYPE_DICTIONARY:
		popup_packet = outer_packet.get("popup", {}).duplicate(true)
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
			if outer_packet.has(key) and not popup_packet.has(key):
				popup_packet[key] = outer_packet[key]

	popup_packet["event_id"] = str(popup_packet.get("event_id", event_id))
	popup_packet["event_step"] = str(popup_packet.get("event_step", event_data.get("current_step", "")))
	var popup_event_step := str(popup_packet.get("event_step", "")).strip_edges()
	var story_popup_token := str(popup_packet.get("story_popup_token", popup_packet.get("popup_token", ""))).strip_edges()
	if story_popup_token == "":
		story_popup_token = build_event_story_popup_token(event_id, popup_event_step)
	popup_packet["story_popup_token"] = story_popup_token
	if str(popup_packet.get("title", "")).strip_edges() == "":
		popup_packet["title"] = str(event_data.get("display_name", "EVENT"))

	var close_operations := stamp_story_popup_close_operations(
		collect_story_popup_close_operations(event_data, popup_packet),
		popup_event_step,
		story_popup_token
	)
	if not close_operations.is_empty() and not bool(popup_packet.get("_skip_pending_story_popup_save", false)):
		remember_pending_story_popup(event_id, event_data, popup_packet, close_operations)
	if Globals.debug_story_popup:
		print(
			"STORY POPUP DEBUG | handler event=",
			event_id,
			" step=",
			str(event_data.get("current_step", "")),
			" title=",
			str(popup_packet.get("title", "")),
			" token=",
			story_popup_token,
			" close_ops=",
			close_operations.size(),
			" keys=",
			popup_packet.keys()
		)
	if not close_operations.is_empty():
		popup_packet["on_close_callable"] = Callable(self, "handle_story_popup_closed")
		popup_packet["on_close_context"] = {
			"event_id": event_id,
			"event_step": popup_event_step,
			"story_popup_token": story_popup_token,
			"operations": close_operations,
			"source": "story_popup_close"
		}

	return widget_builder.show_story_popup(popup_packet)


func collect_story_popup_close_operations(event_data: Dictionary, packet: Dictionary) -> Array:
	var operations: Array = []

	for key in ["on_close_operations", "after_close_operations", "close_operations"]:
		var value = packet.get(key, [])
		if typeof(value) == TYPE_ARRAY:
			for op in value:
				if typeof(op) == TYPE_DICTIONARY:
					operations.append(op.duplicate(true))
		elif typeof(value) == TYPE_DICTIONARY:
			operations.append(value.duplicate(true))

	var on_close = packet.get("on_close", {})
	if typeof(on_close) == TYPE_DICTIONARY:
		if on_close.has("operations") and typeof(on_close.get("operations")) == TYPE_ARRAY:
			for op in on_close.get("operations", []):
				if typeof(op) == TYPE_DICTIONARY:
					operations.append(op.duplicate(true))
		elif on_close.has("operation") and typeof(on_close.get("operation")) == TYPE_DICTIONARY:
			operations.append(on_close.get("operation", {}).duplicate(true))
		else:
			var on_close_op: Dictionary = on_close.duplicate(true)
			if on_close_op.has("op") or on_close_op.has("action_id") or on_close_op.has("type"):
				operations.append(on_close_op)

	var next_step := str(packet.get("next_step_on_close", packet.get("advance_step_on_close", ""))).strip_edges()
	if next_step == "" and bool(packet.get("advance_on_close", false)):
		next_step = str(get_step_data(event_data, str(event_data.get("current_step", ""))).get("next_step", "")).strip_edges()
	if next_step != "":
		operations.append({
			"op": "advance_step",
			"next_step": next_step
		})

	return operations


func handle_story_popup_closed(context: Dictionary) -> void:
	var event_id := str(context.get("event_id", "")).strip_edges()
	if event_id == "":
		return
	var story_popup_token := str(context.get("story_popup_token", "")).strip_edges()
	var expected_step := str(context.get("event_step", "")).strip_edges()

	var operations = context.get("operations", [])
	if typeof(operations) != TYPE_ARRAY or operations.is_empty():
		clear_pending_story_popup(event_id, story_popup_token)
		return

	var event_data := get_display_event_data(event_id)
	if event_data.is_empty():
		clear_pending_story_popup(event_id, story_popup_token)
		return

	var current_step := str(event_data.get("current_step", "")).strip_edges()
	if expected_step != "" and current_step != "" and current_step != expected_step:
		if Globals.print_priority_7:
			print(
				"Story popup close ignored. event=",
				event_id,
				" expected_step=",
				expected_step,
				" current_step=",
				current_step,
				" token=",
				story_popup_token
			)
		clear_pending_story_popup(event_id, story_popup_token)
		return

	clear_pending_story_popup(event_id, story_popup_token)

	execute_event_operations(event_id, event_data, operations, {
		"source": str(context.get("source", "story_popup_close")),
		"event_step": expected_step,
		"story_popup_token": story_popup_token,
		"close_source": str(context.get("close_source", ""))
	})

	save_event_runtime_state()
	request_event_pulse("story_popup_closed")


func handle_show_tutorial_hint(event_id: String, event_data: Dictionary, packet: Dictionary) -> Dictionary:
	if main_ui_handler == null:
		return {"status": "failed", "event_id": event_id, "reason": "missing main_ui_handler"}

	var tutorial_packet := packet.duplicate(true)
	if tutorial_packet.has("tutorial") and typeof(tutorial_packet.get("tutorial")) == TYPE_DICTIONARY:
		tutorial_packet = tutorial_packet.get("tutorial", {}).duplicate(true)

	tutorial_packet["event_id"] = str(tutorial_packet.get("event_id", event_id))
	tutorial_packet["event_step"] = str(tutorial_packet.get("event_step", event_data.get("current_step", "")))
	if str(tutorial_packet.get("text", tutorial_packet.get("message", ""))).strip_edges() == "":
		tutorial_packet["text"] = str(tutorial_packet.get("title", event_data.get("display_name", "Event helper")))

	var complete_operations := collect_tutorial_hint_complete_operations(event_data, tutorial_packet)
	if not complete_operations.is_empty():
		tutorial_packet["on_complete_callable"] = Callable(self, "handle_tutorial_hint_completed")
		tutorial_packet["on_complete_context"] = {
			"event_id": event_id,
			"event_step": str(event_data.get("current_step", "")),
			"operations": complete_operations,
			"source": "tutorial_hint_complete"
		}

	if main_ui_handler.has_method("show_guidance_prompt"):
		return main_ui_handler.show_guidance_prompt(normalize_tutorial_packet(tutorial_packet))

	return {"status": "failed", "event_id": event_id, "reason": "main_ui_handler missing show_guidance_prompt"}


func collect_tutorial_hint_complete_operations(event_data: Dictionary, packet: Dictionary) -> Array:
	var operations: Array = []

	for key in ["on_complete_operations", "after_hint_operations", "on_close_operations", "after_close_operations"]:
		var value = packet.get(key, [])
		if typeof(value) == TYPE_ARRAY:
			for op in value:
				if typeof(op) == TYPE_DICTIONARY:
					operations.append(op.duplicate(true))
		elif typeof(value) == TYPE_DICTIONARY:
			operations.append(value.duplicate(true))

	var next_step := str(packet.get(
		"next_step_after_hint",
		packet.get("next_step_on_close", packet.get("advance_step_on_close", ""))
	)).strip_edges()
	if next_step == "" and bool(packet.get("advance_on_close", false)):
		next_step = str(get_step_data(event_data, str(event_data.get("current_step", ""))).get("next_step", "")).strip_edges()
	if next_step != "":
		operations.append({
			"op": "advance_step",
			"next_step": next_step
		})

	return operations


func handle_tutorial_hint_completed(context: Dictionary) -> void:
	var event_id := str(context.get("event_id", "")).strip_edges()
	if event_id == "":
		return

	var operations = context.get("operations", [])
	if typeof(operations) != TYPE_ARRAY or operations.is_empty():
		return

	var event_data := get_display_event_data(event_id)
	if event_data.is_empty():
		return

	execute_event_operations(event_id, event_data, operations, {
		"source": str(context.get("source", "tutorial_hint_complete")),
		"event_step": str(context.get("event_step", ""))
	})

	save_event_runtime_state()


func normalize_tutorial_packet(packet: Dictionary) -> Dictionary:
	var out := packet.duplicate(true)
	for key in ["popup_size", "popup_offset", "target_position", "line_to_position"]:
		if out.has(key):
			out[key] = read_vector2_value(out[key], Vector2.ZERO)
	return out


func start_event_battle_from_operation(event_id: String, event_data: Dictionary, operation: Dictionary, context: Dictionary = {}) -> Dictionary:
	var step_id := str(operation.get("step_id", event_data.get("current_step", "")))
	var step_data := get_step_data(event_data, step_id)
	var enemy_object_id := str(operation.get("enemy_id", operation.get("target_object_id", step_data.get("enemy_id", step_data.get("target_object_id", "")))))
	if enemy_object_id == "":
		return {"status": "failed", "op": "start_battle", "reason": "missing enemy_id"}

	var gate_packet := operation.duplicate(true)
	gate_packet["action_id"] = str(gate_packet.get("action_id", gate_packet.get("op", "start_battle")))
	gate_packet["target_object_id"] = str(gate_packet.get("target_object_id", enemy_object_id))
	gate_packet["enemy_id"] = enemy_object_id
	var gate_source := str(context.get("source", operation.get("source", "step_enter")))
	var gate_result := run_event_action_position_gate(event_id, event_data, gate_packet, step_data, {
		"source": gate_source,
		"step_id": step_id,
		"action_id": "start_battle"
	})
	if event_gate_result_blocks(gate_result):
		gate_result["op"] = "start_battle"
		gate_result["enemy_id"] = enemy_object_id
		return gate_result

	var result := begin_event_battle(event_id, event_data, enemy_object_id, operation)
	result["op"] = "start_battle"
	return result


func begin_event_battle(event_id: String, event_data: Dictionary, enemy_object_id: String, operation: Dictionary = {}) -> Dictionary:
	if battle_v2_bridge == null:
		write_event_log("Event battle blocked: Battle V2 bridge is not connected.")
		return {"status": "failed", "reason": "missing battle_v2_bridge"}

	var event_objects: Dictionary = event_data.get("event_objects", {})
	if not event_objects.has(enemy_object_id):
		write_event_log("Event battle blocked: missing event enemy object " + enemy_object_id)
		return {"status": "failed", "reason": "missing enemy object"}

	var enemy_data: Dictionary = event_objects[enemy_object_id]
	var enemy = world_builder.install_event_object(enemy_object_id, enemy_data, event_data)
	if enemy == null:
		write_event_log("Event battle blocked: enemy install failed.")
		return {"status": "failed", "reason": "enemy install failed"}

	sync_event_state_to_world(event_data)
	save_event_world_state()

	var enemy_name := str(enemy.get("enemy_name") if enemy is Object else enemy_object_id)
	var message := str(operation.get("message", "Event target intercepted you.\nEntering Battle V2: " + enemy_name))
	write_event_log(message)

	var entry_reason := str(operation.get("entry_reason", "event_battle_" + event_id))
	var current_step := str(event_data.get("current_step", operation.get("step_id", ""))).strip_edges()
	if current_step == "":
		current_step = str(operation.get("required_step", operation.get("event_step", ""))).strip_edges()
	var enemy_serial := ""
	var enemy_template_id := ""
	if enemy is Object:
		enemy_serial = str(enemy.get("enemy_serial")).strip_edges()
		enemy_template_id = str(enemy.get("enemy_template_id")).strip_edges()
	var authored_event_context := {
		"event_id": event_id,
		"active_event_id": event_id,
		"event_step": current_step,
		"current_step": current_step,
		"required_step": current_step,
		"enemy_id": enemy_object_id,
		"target_object_id": enemy_object_id,
		"enemy_serial": enemy_serial,
		"enemy_template_id": enemy_template_id,
		"entry_reason": entry_reason,
		"source": "GameEventsHandler.begin_event_battle"
	}
	var battle_started := bool(battle_v2_bridge.request_battle_v2_entry(entry_reason, enemy, authored_event_context))
	return {"status": "success" if battle_started else "failed", "enemy_id": enemy_object_id, "entry_reason": entry_reason}


func run_step_enter_operations(event_id: String, event_data: Dictionary, step_id: String) -> void:
	var step_data := get_step_data(event_data, step_id)
	if step_data.is_empty():
		return

	if try_skip_completed_step_replay(event_id, event_data, step_id, step_data):
		return

	var enter_flag := "entered_" + step_id
	if get_event_flag(event_data, enter_flag, false):
		return

	var operations = step_data.get("on_enter", [])
	if typeof(operations) == TYPE_ARRAY and not operations.is_empty():
		var operation_result := execute_event_operations(event_id, event_data, operations, {
			"source": "step_enter",
			"step_id": step_id
		})
		if should_mark_step_entered_after_operations(operation_result):
			set_event_flag(event_id, enter_flag, true)
		return

	if step_id == "defeat_guardian":
		var battle_result := begin_event_guardian_battle(event_id, event_data)
		battle_result["op"] = "start_battle"
		if event_operation_result_succeeded(battle_result):
			set_event_flag(event_id, enter_flag, true)


func step_completes_on_battle_victory(step_data: Dictionary, defeated_shared_meta: Dictionary) -> bool:
	if step_data.is_empty():
		return false

	var defeated_serial := str(defeated_shared_meta.get("enemy_serial", defeated_shared_meta.get("serial_number", ""))).strip_edges()
	var target_serial := str(step_data.get("enemy_serial", step_data.get("target_enemy_serial", ""))).strip_edges()
	if target_serial == "" and enemy_intel_handler != null and enemy_intel_handler.has_method("get_event_enemy_serial"):
		var serial_event_id := str(defeated_shared_meta.get("event_id", defeated_shared_meta.get("active_event_id", ""))).strip_edges()
		var serial_target_id := str(step_data.get("enemy_id", step_data.get("target_object_id", ""))).strip_edges()
		if serial_event_id != "" and serial_target_id != "":
			target_serial = str(enemy_intel_handler.get_event_enemy_serial(serial_event_id, serial_target_id)).strip_edges()
	if target_serial != "":
		return defeated_serial != "" and target_serial == defeated_serial

	var defeated_id := str(defeated_shared_meta.get("object_id", defeated_shared_meta.get("id", "")))
	var target_id := str(step_data.get("enemy_id", step_data.get("target_object_id", "")))
	if target_id != "" and defeated_id != "" and target_id != defeated_id:
		return false

	if bool(step_data.get("complete_on_battle_victory", false)):
		return true

	return str(step_data.get("interaction_type", "")) == "hunt" or str(step_data.get("event_type", "")) == "hunt" or str(step_data.get("step_kind", "")) == "hunt" or str(step_data.get("enemy_id", "")) != ""


func grant_event_reward(event_data: Dictionary) -> void:
	if inventory == null:
		return

	var reward_packet: Dictionary = event_data.get("reward_packet", {})
	var items = reward_packet.get("items", [])
	if typeof(items) == TYPE_ARRAY:
		for item in items:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var item_id := str(item.get("item_id", ""))
			var amount := int(item.get("amount", 1))
			if item_id != "" and amount > 0:
				inventory.add_item(item_id, amount, "event_reward_packet")

	if inventory.has_method("refresh_label_inventory_rows"):
		inventory.refresh_label_inventory_rows()


func complete_event(event_id: String, event_data: Dictionary) -> void:
	var previous_step := str(event_data.get("current_step", ""))
	if previous_step != "" and previous_step != "completed":
		mark_step_completed_on_event_data(event_data, previous_step)
	event_data["event_state"] = "completed"
	event_data["current_step"] = "completed"
	event_data["last_step"] = previous_step
	event_data["completed"] = true
	completed_events[event_id] = event_data.duplicate(true)
	active_events.erase(event_id)
	available_events.erase(event_id)
	if active_event_id == event_id:
		active_event_id = ""
		ensure_display_event_selection()

	sync_event_state_to_world(event_data)

	if active_event_id == "" and widget_builder != null and widget_builder.has_method("clear_event_widget"):
		widget_builder.clear_event_widget()
	else:
		event_widget_dirty = true
	request_event_pulse("event_completed")

	var reward_packet: Dictionary = event_data.get("reward_packet", {})
	var message := str(reward_packet.get("message", "Event complete. Reward received."))
	write_event_log("EVENT COMPLETE\n" + message)
	request_event_world_state_save_after_cover("event_complete_" + event_id, false)


func should_auto_complete_terminal_step(event_data: Dictionary, step_id: String, step_data: Dictionary) -> bool:
	if step_id == "" or step_data.is_empty():
		return false

	var next_step := str(step_data.get("next_step", "")).strip_edges()
	var has_pending_work := step_has_pending_manual_or_scripted_work(step_data)

	var clean_step_id := step_id.strip_edges().to_lower()
	if clean_step_id == "complete" or clean_step_id == "completed":
		return not has_pending_work
	if clean_step_id.ends_with("_complete") or clean_step_id.ends_with("_completed"):
		return not has_pending_work

	if next_step == "completed":
		return not has_pending_work and is_last_declared_event_step(event_data, step_id)

	if next_step != "":
		return false
	if not is_last_declared_event_step(event_data, step_id):
		return false
	if has_pending_work:
		return false

	return true


func is_last_declared_event_step(event_data: Dictionary, step_id: String) -> bool:
	var steps = event_data.get("steps", {})
	if typeof(steps) != TYPE_DICTIONARY or steps.is_empty():
		return false

	var keys = steps.keys()
	return str(keys[keys.size() - 1]) == step_id


func step_has_pending_manual_or_scripted_work(step_data: Dictionary) -> bool:
	for key in ["actions", "on_enter", "on_arrival", "operations", "buttons"]:
		var value = step_data.get(key, [])
		if typeof(value) == TYPE_ARRAY and not value.is_empty():
			return true
		if typeof(value) == TYPE_DICTIONARY and not value.is_empty():
			return true
	return false


func make_event_transition_result(event_id: String, next_step: String, status: String = "failed", reason: String = "") -> Dictionary:
	return {
		"status": status,
		"reason": reason,
		"event_id": event_id,
		"next_step": next_step,
		"action_id": "advance_step"
	}


func get_transition_expected_step(context: Dictionary) -> String:
	for key in ["required_step", "event_step", "step_id", "current_step"]:
		var expected_step := str(context.get(key, "")).strip_edges()
		if expected_step != "":
			return expected_step
	return ""


func add_authored_transition_target(targets: Dictionary, value) -> void:
	var target := str(value).strip_edges()
	if target == "":
		return
	targets[target] = true


func collect_authored_transition_targets_from_value(value, targets: Dictionary) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		var packet: Dictionary = value
		for key in ["next_step", "next_step_on_close", "advance_step_on_close"]:
			if packet.has(key):
				add_authored_transition_target(targets, packet.get(key, ""))

		var op_id := str(packet.get("op", packet.get("type", packet.get("action", "")))).strip_edges().to_lower()
		if op_id == "":
			op_id = str(packet.get("action_id", "")).strip_edges().to_lower()
		if op_id == "advance_step":
			add_authored_transition_target(targets, packet.get("next_step", ""))

		for key in packet.keys():
			collect_authored_transition_targets_from_value(packet[key], targets)
	elif typeof(value) == TYPE_ARRAY:
		for item in value:
			collect_authored_transition_targets_from_value(item, targets)


func collect_authored_transition_targets(event_data: Dictionary, step_id: String) -> Dictionary:
	var targets := {}
	var step_data := get_step_data(event_data, step_id)
	if step_data.is_empty():
		return targets
	collect_authored_transition_targets_from_value(step_data, targets)
	return targets


func event_transition_target_exists(event_data: Dictionary, target_step: String) -> bool:
	if target_step == "completed":
		return true
	var steps = event_data.get("steps", {})
	return typeof(steps) == TYPE_DICTIONARY and steps.has(target_step)


func validate_event_step_transition(event_id: String, event_data: Dictionary, current_step: String, next_step: String, context: Dictionary = {}) -> Dictionary:
	var result := make_event_transition_result(event_id, next_step)
	var clean_next := next_step.strip_edges()
	if clean_next == "":
		result["reason"] = "missing next_step"
		return result

	var expected_step := get_transition_expected_step(context)
	if expected_step != "" and current_step != "" and expected_step != current_step:
		result["reason"] = "step mismatch"
		result["expected_step"] = expected_step
		result["current_step"] = current_step
		result["source"] = str(context.get("source", ""))
		return result

	if not event_transition_target_exists(event_data, clean_next):
		result["reason"] = "unknown next_step"
		result["current_step"] = current_step
		result["source"] = str(context.get("source", ""))
		return result

	var authored_targets := collect_authored_transition_targets(event_data, current_step)
	if not bool(authored_targets.get(clean_next, false)):
		result["reason"] = "non-authored transition"
		result["current_step"] = current_step
		result["source"] = str(context.get("source", ""))
		return result

	result["status"] = "success"
	result["reason"] = ""
	result["current_step"] = current_step
	result["source"] = str(context.get("source", ""))
	return result


func advance_event_to_step(event_id: String, next_step: String, context: Dictionary = {}) -> Dictionary:
	if event_id == "" or next_step == "":
		return make_event_transition_result(event_id, next_step, "failed", "missing event_id or next_step")
	if not active_events.has(event_id):
		return make_event_transition_result(event_id, next_step, "failed", "event is not active")

	var event_data: Dictionary = active_events[event_id]
	var previous_step := str(event_data.get("current_step", ""))
	var transition_result := validate_event_step_transition(event_id, event_data, previous_step, next_step, context)
	if str(transition_result.get("status", "")) != "success":
		if Globals.print_priority_7:
			print(
				"[EVENT_TRANSITION_BLOCKED] event=",
				event_id,
				" current=",
				previous_step,
				" next=",
				next_step,
				" reason=",
				str(transition_result.get("reason", ""))
			)
		return transition_result

	if previous_step != "" and previous_step != next_step:
		mark_step_completed_on_event_data(event_data, previous_step)

	if next_step == "completed":
		complete_event(event_id, event_data)
		save_event_transition_state(context)
		transition_result["completed"] = true
		return transition_result

	event_data["event_state"] = "active"
	event_data["current_step"] = next_step
	active_events[event_id] = event_data
	active_event_id = event_id

	sync_event_state_to_world(event_data)
	save_event_transition_state(context)
	event_widget_dirty = true
	request_event_pulse("step_advanced")

	run_step_enter_operations(event_id, event_data, next_step)

	if active_events.has(event_id):
		event_data = active_events[event_id]
		var step_data := get_step_data(event_data, next_step)
		if should_auto_complete_terminal_step(event_data, next_step, step_data):
			complete_event(event_id, event_data)
			save_event_transition_state(context)
			transition_result["completed"] = true

	return transition_result


func sync_event_state_to_world(event_data: Dictionary) -> void:
	var event_id := str(event_data.get("event_id", ""))
	var current_step := str(event_data.get("current_step", ""))
	var event_state := str(event_data.get("event_state", "active"))

	var giver = find_giver_npc(event_data)
	if giver != null:
		giver.event_state = event_state
		giver.event_step = current_step
		giver.current_step = current_step
		giver.completed = bool(event_data.get("completed", false))
		giver.set_meta("event_id", event_id)
		giver.set_meta("active_event_id", event_id)
		giver.set_meta("event_state", event_state)
		giver.set_meta("event_step", current_step)
		giver.set_meta("current_step", current_step)
		giver.set_meta("completed", bool(event_data.get("completed", false)))
		if giver.has_method("sync_shared_meta"):
			giver.sync_shared_meta()

	apply_event_dialogue_for_current_state(event_data)

	if beacons != null and "beacons" in beacons:
		for beacon in beacons.beacons:
			if typeof(beacon) != TYPE_DICTIONARY:
				continue
			if str(beacon.get("event_id", beacon.get("active_event_id", ""))) != event_id:
				continue
			beacon["event_state"] = event_state
			beacon["event_step"] = current_step
			beacon["current_step"] = current_step
			beacon["active_event_id"] = event_id
			SharedObjectMeta.apply_to_dictionary(
				beacon,
				str(beacon.get("object_id", beacon.get("id", ""))),
				"beacon",
				str(beacon.get("display_name", beacon.get("title", "Beacon"))),
				SharedObjectMeta.read_sector_pos(beacon.get("sector_pos", Vector3i.ZERO)),
				SharedObjectMeta.read_local_pos(beacon.get("local_pos", Vector3.ZERO))
			)


func apply_event_dialogue_for_current_state(event_data: Dictionary) -> Dictionary:
	# Summary: Keep event NPC talk lines aligned with the current or completed story step.
	var event_state := str(event_data.get("event_state", "active")).strip_edges().to_lower()
	var packet := {}
	if event_state == "completed":
		packet = build_completed_npc_dialogue_packet(event_data)
	else:
		packet = build_step_npc_dialogue_packet(event_data, str(event_data.get("current_step", "")))

	if packet.is_empty():
		return {
			"status": "idle",
			"reason": "no dialogue update",
			"labels": ["event_npc_dialogue_sync"]
		}

	return apply_npc_dialogue_update(event_data, packet, {
		"source": "event_state_sync",
		"event_id": str(event_data.get("event_id", "")),
		"step_id": str(event_data.get("current_step", ""))
	})


func build_step_npc_dialogue_packet(event_data: Dictionary, step_id: String) -> Dictionary:
	var step_data := get_step_data(event_data, step_id)
	if step_data.is_empty():
		return {}

	var packet := {}
	for key in [
		"npc_dialogue_lines",
		"dialogue_lines",
		"lines",
		"npc_chat_line_delay",
		"chat_line_delay",
		"npc_chat_character_delay",
		"chat_character_delay",
		"chat_type_delay",
		"npc_can_trade",
		"can_trade",
		"trade",
		"trade_enabled",
		"trade_completed",
		"item_list",
		"offer_title",
		"offer_text",
		"success_text",
		"npc_quest_available",
		"quest_available",
		"npc_has_event",
		"has_event",
		"npc_event_id",
		"event_id",
		"active_event_id",
		"npc_event_state",
		"event_state",
		"event_next_step",
		"target_owner_id",
		"npc_dialogue_target_owner_id",
		"npc_id",
		"target_object_id",
		"event_idle_message",
		"event_completed_message",
		"message",
		"talk_meta",
		"npc_meta",
		"contact_meta",
		"trade_meta"
	]:
		if step_data.has(key):
			packet[key] = step_data[key]

	if not packet.has("target_owner_id"):
		var target_owner_id := str(step_data.get("npc_dialogue_target_owner_id", step_data.get("target_owner_id", ""))).strip_edges()
		if target_owner_id == "":
			target_owner_id = str(step_data.get("target_object_id", "")).strip_edges()
		if target_owner_id == "":
			target_owner_id = get_event_giver_owner_id(event_data)
		if target_owner_id != "":
			packet["target_owner_id"] = target_owner_id

	return packet if dialogue_packet_has_content(packet) else {}


func build_completed_npc_dialogue_packet(event_data: Dictionary) -> Dictionary:
	var packet := {}
	var last_step_id := str(event_data.get("last_step", "")).strip_edges()
	var last_step_data := get_step_data(event_data, last_step_id)
	if not last_step_data.is_empty():
		for key in [
			"completed_npc_dialogue_lines",
			"completed_dialogue_lines",
			"completed_chat_line_delay",
			"completed_npc_chat_line_delay",
			"completed_chat_character_delay",
			"completed_npc_chat_character_delay",
			"npc_dialogue_target_owner_id",
			"target_owner_id",
			"npc_id"
		]:
			if last_step_data.has(key):
				packet[key] = last_step_data[key]

	for key in [
		"completed_npc_dialogue_lines",
		"completed_dialogue_lines",
		"completed_chat_line_delay",
		"completed_npc_chat_line_delay",
		"completed_chat_character_delay",
		"completed_npc_chat_character_delay"
	]:
		if event_data.has(key):
			packet[key] = event_data[key]

	if packet.has("completed_npc_dialogue_lines") and not packet.has("npc_dialogue_lines"):
		packet["npc_dialogue_lines"] = packet["completed_npc_dialogue_lines"]
	if packet.has("completed_dialogue_lines") and not packet.has("dialogue_lines"):
		packet["dialogue_lines"] = packet["completed_dialogue_lines"]
	if packet.has("completed_chat_line_delay") and not packet.has("chat_line_delay"):
		packet["chat_line_delay"] = packet["completed_chat_line_delay"]
	if packet.has("completed_npc_chat_line_delay") and not packet.has("npc_chat_line_delay"):
		packet["npc_chat_line_delay"] = packet["completed_npc_chat_line_delay"]
	if packet.has("completed_chat_character_delay") and not packet.has("chat_character_delay"):
		packet["chat_character_delay"] = packet["completed_chat_character_delay"]
	if packet.has("completed_npc_chat_character_delay") and not packet.has("npc_chat_character_delay"):
		packet["npc_chat_character_delay"] = packet["completed_npc_chat_character_delay"]
	if not packet.has("target_owner_id"):
		var target_owner_id := str(packet.get("npc_dialogue_target_owner_id", packet.get("npc_id", ""))).strip_edges()
		if target_owner_id == "":
			target_owner_id = get_event_giver_owner_id(event_data)
		if target_owner_id != "":
			packet["target_owner_id"] = target_owner_id
	packet["event_state"] = "completed"
	return packet if dialogue_packet_has_content(packet) else {}


func flatten_npc_dialogue_packet(packet: Dictionary) -> Dictionary:
	var out := {}
	for nested_key in ["talk_meta", "npc_meta", "contact_meta", "dialogue", "trade_meta"]:
		var nested = packet.get(nested_key, {})
		if typeof(nested) == TYPE_DICTIONARY:
			for key in nested.keys():
				out[key] = nested[key]
	for key in packet.keys():
		var clean_key := str(key)
		if ["talk_meta", "npc_meta", "contact_meta", "dialogue", "trade_meta"].has(clean_key):
			continue
		out[clean_key] = packet[key]
	if out.has("dialogue_lines") and not out.has("npc_dialogue_lines"):
		out["npc_dialogue_lines"] = out["dialogue_lines"]
	if out.has("chat_type_delay") and not out.has("npc_chat_character_delay"):
		out["npc_chat_character_delay"] = out["chat_type_delay"]
	if out.has("chat_character_delay") and not out.has("npc_chat_character_delay"):
		out["npc_chat_character_delay"] = out["chat_character_delay"]
	if out.has("trade_enabled") and not out.has("npc_can_trade"):
		out["npc_can_trade"] = out["trade_enabled"]
	if out.has("quest_available") and not out.has("npc_quest_available"):
		out["npc_quest_available"] = out["quest_available"]
	return out


func dialogue_packet_has_content(packet: Dictionary) -> bool:
	var effective_packet := flatten_npc_dialogue_packet(packet)
	for key in ["npc_dialogue_lines", "dialogue_lines", "lines", "completed_npc_dialogue_lines", "completed_dialogue_lines"]:
		if not normalize_dialogue_lines(effective_packet.get(key, [])).is_empty():
			return true
	for key in ["npc_chat_line_delay", "chat_line_delay", "completed_chat_line_delay", "completed_npc_chat_line_delay", "npc_chat_character_delay", "chat_character_delay", "chat_type_delay", "completed_chat_character_delay", "completed_npc_chat_character_delay", "event_idle_message", "event_completed_message", "event_accept_message", "event_decline_message", "message", "interaction_type"]:
		if effective_packet.has(key) and str(effective_packet.get(key, "")).strip_edges() != "":
			return true
	for key in ["npc_can_trade", "can_trade", "trade", "trade_enabled", "trade_completed", "npc_quest_available", "quest_available", "npc_has_event", "has_event"]:
		if effective_packet.has(key):
			return true
	for key in ["item_list"]:
		if effective_packet.has(key) and typeof(effective_packet.get(key, [])) == TYPE_ARRAY and not effective_packet.get(key, []).is_empty():
			return true
	for key in ["offer_title", "offer_text", "success_text", "npc_event_id", "event_id", "active_event_id", "npc_event_state", "event_state", "event_next_step"]:
		if effective_packet.has(key) and str(effective_packet.get(key, "")).strip_edges() != "":
			return true
	return false

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


func apply_npc_dialogue_update(event_data: Dictionary, packet: Dictionary, context: Dictionary = {}) -> Dictionary:
	var effective_packet := flatten_npc_dialogue_packet(packet)
	var target_npc = find_npc_for_dialogue_update(event_data, effective_packet)
	if target_npc == null:
		return {
			"status": "failed",
			"op": "update_npc_dialogue",
			"reason": "missing target npc",
			"event_id": str(event_data.get("event_id", "")),
			"labels": ["event_npc_dialogue_update_failed"]
		}

	return apply_npc_dialogue_update_to_npc(target_npc, effective_packet, context)


func apply_npc_dialogue_update_to_npc(target_npc, packet: Dictionary, context: Dictionary = {}) -> Dictionary:
	if target_npc == null:
		return {"status": "failed", "op": "update_npc_dialogue", "reason": "missing target npc"}

	packet = flatten_npc_dialogue_packet(packet)
	var lines := normalize_dialogue_lines(packet.get("npc_dialogue_lines", packet.get("dialogue_lines", packet.get("lines", []))))
	if lines.is_empty():
		lines = normalize_dialogue_lines(packet.get("completed_npc_dialogue_lines", packet.get("completed_dialogue_lines", [])))
	if not lines.is_empty():
		target_npc.set_meta("dialogue_lines", lines.duplicate(true))
		target_npc.greeting_message = str(lines[0])
		target_npc.has_message = true

	var has_delay := packet.has("npc_chat_line_delay") or packet.has("chat_line_delay") or packet.has("completed_chat_line_delay") or packet.has("completed_npc_chat_line_delay")
	if has_delay:
		var delay := float(packet.get("npc_chat_line_delay", packet.get("chat_line_delay", packet.get("completed_chat_line_delay", packet.get("completed_npc_chat_line_delay", target_npc.chat_line_delay)))))
		target_npc.chat_line_delay = max(delay, 0.1)
		target_npc.set_meta("chat_line_delay", target_npc.chat_line_delay)

	var has_character_delay := packet.has("npc_chat_character_delay") or packet.has("chat_character_delay") or packet.has("chat_type_delay") or packet.has("completed_chat_character_delay") or packet.has("completed_npc_chat_character_delay")
	if has_character_delay:
		var character_delay := float(packet.get("npc_chat_character_delay", packet.get("chat_character_delay", packet.get("chat_type_delay", packet.get("completed_chat_character_delay", packet.get("completed_npc_chat_character_delay", target_npc.chat_character_delay))))))
		target_npc.chat_character_delay = max(character_delay, 0.005)
		target_npc.set_meta("chat_character_delay", target_npc.chat_character_delay)

	apply_npc_contact_action_update_to_npc(target_npc, packet, context)

	if packet.has("event_idle_message"):
		target_npc.event_idle_message = str(packet.get("event_idle_message", ""))
		target_npc.set_meta("event_idle_message", target_npc.event_idle_message)
	if packet.has("event_completed_message"):
		target_npc.event_completed_message = str(packet.get("event_completed_message", ""))
		target_npc.set_meta("event_completed_message", target_npc.event_completed_message)
	if packet.has("message"):
		target_npc.greeting_message = str(packet.get("message", target_npc.greeting_message))
		target_npc.has_message = target_npc.greeting_message.strip_edges() != ""

	target_npc.set_meta("last_dialogue_update_source", str(context.get("source", "event_dialogue")))
	target_npc.set_meta("last_dialogue_step_id", str(context.get("step_id", "")))

	if target_npc.has_method("sync_shared_meta"):
		target_npc.sync_shared_meta()

	return {
		"status": "success",
		"op": "update_npc_dialogue",
		"npc_id": str(target_npc.get_meta("npc_id", target_npc.object_id)),
		"line_count": lines.size(),
		"chat_line_delay": float(target_npc.get_meta("chat_line_delay", target_npc.chat_line_delay)),
		"chat_character_delay": float(target_npc.get_meta("chat_character_delay", target_npc.chat_character_delay)),
		"can_trade": bool(target_npc.get_meta("can_trade", target_npc.can_trade)),
		"has_event": bool(target_npc.get_meta("has_event", target_npc.has_event)),
		"labels": ["event_npc_dialogue_updated"]
	}


func apply_npc_contact_action_update_to_npc(target_npc, packet: Dictionary, context: Dictionary = {}) -> void:
	if target_npc == null:
		return

	var has_trade_update := packet.has("npc_can_trade") or packet.has("can_trade") or packet.has("trade") or packet.has("trade_enabled")
	if has_trade_update:
		var can_trade_now := bool(packet.get("npc_can_trade", packet.get("can_trade", packet.get("trade", packet.get("trade_enabled", target_npc.can_trade)))))
		target_npc.can_trade = can_trade_now
		target_npc.set_meta("can_trade", can_trade_now)
		target_npc.set_meta("trade", can_trade_now)

	if packet.has("trade_completed"):
		target_npc.set_meta("trade_completed", bool(packet.get("trade_completed", false)))

	if packet.has("item_list") and typeof(packet.get("item_list", [])) == TYPE_ARRAY:
		target_npc.set_meta("item_list", packet.get("item_list", []).duplicate(true))

	for key in ["offer_title", "offer_text", "success_text", "event_accept_message", "event_decline_message", "interaction_type"]:
		if packet.has(key):
			target_npc.set_meta(key, str(packet.get(key, "")))
			if key == "event_accept_message":
				target_npc.event_accept_message = str(packet.get(key, ""))
			elif key == "event_decline_message":
				target_npc.event_decline_message = str(packet.get(key, ""))

	var has_quest_update := packet.has("npc_quest_available") or packet.has("quest_available") or packet.has("npc_has_event") or packet.has("has_event")
	var has_explicit_event_id := packet.has("npc_event_id") or packet.has("event_id")
	var has_explicit_active_event_id := packet.has("active_event_id")
	var event_id := ""
	if has_explicit_event_id:
		event_id = str(packet.get("npc_event_id", packet.get("event_id", ""))).strip_edges()
	elif has_quest_update:
		event_id = str(context.get("event_id", target_npc.event_id)).strip_edges()
	else:
		event_id = target_npc.event_id
	var active_event_id := ""
	if has_explicit_active_event_id:
		active_event_id = str(packet.get("active_event_id", "")).strip_edges()
	elif has_quest_update and event_id != "":
		active_event_id = event_id
	else:
		active_event_id = target_npc.active_event_id
	var has_event_identity_update := has_explicit_event_id or has_explicit_active_event_id or packet.has("npc_event_state") or packet.has("event_state") or packet.has("event_next_step")

	if has_quest_update:
		var quest_available := bool(packet.get("npc_quest_available", packet.get("quest_available", packet.get("npc_has_event", packet.get("has_event", target_npc.has_event)))))
		target_npc.has_event = quest_available
		target_npc.set_meta("has_event", quest_available)
		if event_id != "":
			target_npc.event_id = event_id
			target_npc.set_meta("event_id", event_id)
		if active_event_id != "":
			target_npc.active_event_id = active_event_id
			target_npc.set_meta("active_event_id", active_event_id)
		var default_state := "available" if quest_available else "none"
		var event_state := str(packet.get("npc_event_state", packet.get("event_state", default_state))).strip_edges()
		if event_state == "":
			event_state = default_state
		target_npc.event_state = event_state
		target_npc.set_meta("event_state", event_state)
	elif has_event_identity_update:
		if event_id != "":
			target_npc.event_id = event_id
			target_npc.set_meta("event_id", event_id)
			target_npc.has_event = true
			target_npc.set_meta("has_event", true)
		if active_event_id != "":
			target_npc.active_event_id = active_event_id
			target_npc.set_meta("active_event_id", active_event_id)
		if packet.has("npc_event_state") or packet.has("event_state"):
			var event_state := str(packet.get("npc_event_state", packet.get("event_state", target_npc.event_state))).strip_edges()
			target_npc.event_state = event_state
			target_npc.set_meta("event_state", event_state)

	if packet.has("event_next_step"):
		target_npc.set_meta("event_next_step", str(packet.get("event_next_step", "")))


func find_npc_for_dialogue_update(event_data: Dictionary, packet: Dictionary):
	packet = flatten_npc_dialogue_packet(packet)
	var target_id := ""
	for key in ["target_owner_id", "npc_dialogue_target_owner_id", "npc_id", "owner_id", "object_id", "target_object_id"]:
		target_id = str(packet.get(key, "")).strip_edges()
		if target_id != "":
			break
	if target_id == "":
		return find_giver_npc(event_data)
	if owner_id_matches_event_giver(target_id, event_data):
		return find_giver_npc(event_data)

	if npc_handler != null:
		if npc_handler.has_method("get_npc_by_id"):
			var direct_npc = npc_handler.get_npc_by_id(target_id)
			if direct_npc != null:
				return direct_npc
		if "npcs" in npc_handler:
			for npc in npc_handler.npcs:
				if npc == null:
					continue
				if str(npc.get_meta("npc_id", "")).strip_edges() == target_id:
					return npc
				if str(npc.object_id).strip_edges() == target_id:
					return npc

	var event_objects: Dictionary = event_data.get("event_objects", {})
	if event_objects.has(target_id) and world_builder != null:
		var object_data = event_objects[target_id]
		if typeof(object_data) == TYPE_DICTIONARY and str(object_data.get("object_type", object_data.get("owner_type", ""))).strip_edges().to_lower() == "npc":
			return world_builder.install_event_object(target_id, object_data, event_data)

	return null


func owner_id_matches_event_giver(owner_id: String, event_data: Dictionary) -> bool:
	var giver: Dictionary = event_data.get("giver", {}) if typeof(event_data.get("giver", {})) == TYPE_DICTIONARY else {}
	for key in ["owner_id", "object_id", "template_owner_id", "blueprint_id"]:
		if owner_id == str(giver.get(key, "")).strip_edges():
			return true
	return false


func get_event_giver_owner_id(event_data: Dictionary) -> String:
	var giver: Dictionary = event_data.get("giver", {}) if typeof(event_data.get("giver", {})) == TYPE_DICTIONARY else {}
	for key in ["template_owner_id", "owner_id", "object_id", "blueprint_id"]:
		var id_value := str(giver.get(key, "")).strip_edges()
		if id_value != "":
			return id_value
	return ""


func mark_event_beacon_completed(event_data: Dictionary, step_data: Dictionary) -> bool:
	var target_id := str(step_data.get("target_object_id", ""))
	if target_id == "" or beacons == null:
		return false

	var beacon = beacons.get_beacon_by_id(target_id) if beacons.has_method("get_beacon_by_id") else {}
	if beacon.is_empty():
		return false

	beacon["completed"] = true
	beacon["helper_state"] = "downloaded"
	beacon["message"] = "Beacon data copied. Signal guardian defeated."
	SharedObjectMeta.apply_to_dictionary(
		beacon,
		str(beacon.get("object_id", beacon.get("id", target_id))),
		"beacon",
		str(beacon.get("display_name", beacon.get("title", "Beacon"))),
		SharedObjectMeta.read_sector_pos(beacon.get("sector_pos", Vector3i.ZERO)),
		SharedObjectMeta.read_local_pos(beacon.get("local_pos", Vector3.ZERO))
	)
	return true


func is_player_near_step_target(event_data: Dictionary, step_data: Dictionary, range: float) -> bool:
	if map == null:
		return false
	var target := build_target_packet_for_step(event_data, step_data)
	if target.is_empty():
		return false
	var sector := _read_sector_pos(target.get("sector_pos", Vector3i.ZERO))
	var local := _read_local_pos(target.get("local_pos", Vector3.ZERO))
	return map.get_distance_to_target(sector, local) <= range


func get_step_data(event_data: Dictionary, step_id: String) -> Dictionary:
	var steps: Dictionary = event_data.get("steps", {})
	if not steps.has(step_id):
		return {}
	return steps[step_id]


func find_giver_npc(event_data: Dictionary):
	if npc_handler == null or not "npcs" in npc_handler:
		return null

	var event_id := str(event_data.get("event_id", "")).strip_edges()
	var giver: Dictionary = event_data.get("giver", {})
	var wanted_owner_id := str(giver.get("owner_id", "")).strip_edges()
	var wanted_object_id := str(giver.get("object_id", "")).strip_edges()
	var wanted_template_owner_id := str(giver.get("template_owner_id", "")).strip_edges()
	var wanted_blueprint_id := str(giver.get("blueprint_id", ""))
	var allow_blueprint_reuse := bool(giver.get("allow_blueprint_reuse", false))
	var wanted_ids := []
	for id_value in [wanted_owner_id, wanted_object_id, wanted_template_owner_id]:
		if id_value != "" and not wanted_ids.has(id_value):
			wanted_ids.append(id_value)
	var event_match = null
	var blueprint_match = null
	var blueprint_match_count := 0

	for npc in npc_handler.npcs:
		if npc == null:
			continue
		var npc_id := str(npc.get_meta("npc_id", "")).strip_edges()
		var npc_object_id := str(npc.object_id).strip_edges()
		if wanted_ids.has(npc_id) or wanted_ids.has(npc_object_id):
			return npc

		var npc_event_id := str(npc.get_meta("event_id", npc.event_id)).strip_edges()
		var npc_active_event_id := str(npc.get_meta("active_event_id", npc.active_event_id)).strip_edges()
		if event_id != "" and (npc_event_id == event_id or npc_active_event_id == event_id):
			var labels := SharedObjectMeta.read_array(npc.labels)
			if labels.has("event_giver"):
				event_match = npc

		if allow_blueprint_reuse and wanted_blueprint_id != "" and str(npc.get_meta("blueprint_id", "")) == wanted_blueprint_id:
			blueprint_match = npc
			blueprint_match_count += 1

	if event_match != null:
		return event_match
	if allow_blueprint_reuse and blueprint_match_count == 1:
		return blueprint_match
	return null


func make_event_action_result(event_id: String, action_id: String) -> Dictionary:
	return {
		"status": "failed",
		"reason": "",
		"event_id": event_id,
		"action_id": action_id
	}


func write_event_log(message: String) -> void:
	if widget_state == null:
		return
	if widget_state.log_storage.has("log_text"):
		widget_state.log_storage["log_text"].text = message
# ==========================================================
# EVENT DATA
# ==========================================================

func get_event_data_by_id(event_id: String) -> Dictionary:
	if event_catalog.has(event_id):
		return event_catalog[event_id].duplicate(true)

	if Globals.print_priority_7:
		print("Event data missing for id: ", event_id, ". No fallback event will be created.")

	return {}


func get_guild_test_beacon_recovery_event() -> Dictionary:
	return {
		"event_id": "guild_test_beacon_recovery_001",
		"display_name": "Lost Beacon Recovery",
		"event_state": "seeded",
		"current_step": "talk_to_npc",

		"start_on_ready": true,
		"seed_once": true,

		"tier": 1,

		"anchor_star": {
			"star_id": "tier_1_event_star_001",
			"star_name": "Aster Gate",
			"star_type": "K",
			"sector_pos": Vector3i(0, 0, 0),
			"local_pos": Vector3(500, 500, 500),
			"brightness": 1.4,
			"size": 1.6,
			"tier": 1,
			"required": true,
			"create_if_missing": true
		},

		"giver": {
			"owner_type": "npc",
			"owner_id": "guild_contact_tier_1",
			"blueprint_id": "guild_contact_tier_1",
			"display_name": "Guild Contact",
			"place_near_anchor_star": true,
			"local_offset": Vector3(20, 0, 0)
		},

		"event_objects": {
			"lost_beacon_001": {
				"owner_type": "beacon",
				"object_type": "beacon",
				"object_id": "lost_beacon_001",
				"display_name": "Lost Beacon",
				"beacon_type": "guild_event_beacon",
				"place_mode": "exact",
				"sector_pos": Vector3i(1, 0, 0),
				"local_pos": Vector3(400, 500, 500),
				"outside_normal_units": true,
				"interaction_type": "download",
				"event_id": "guild_test_beacon_recovery_001",
				"active_event_id": "guild_test_beacon_recovery_001",
				"required_step": "download_beacon_data",
				"event_step": "download_beacon_data",
				"current_step": "go_to_beacon",
				"has_event": true,
				"labels": ["beacon", "event_beacon", "guild_event", "download_target"]
			},
			"event_guardian_001": {
				"owner_type": "enemy",
				"object_type": "enemy",
				"object_id": "event_guardian_001",
				"display_name": "Smart Guy Signal Guardian",
				"blueprint_id": "test_smart_guy",
				"spawn_on_step": "defeat_guardian",
				"sector_pos": Vector3i(1, 0, 0),
				"local_pos": Vector3(410, 500, 500),
				"event_id": "guild_test_beacon_recovery_001",
				"active_event_id": "guild_test_beacon_recovery_001",
				"required_step": "defeat_guardian",
				"event_step": "defeat_guardian",
				"current_step": "defeat_guardian",
				"has_event": true,
				"labels": ["enemy", "event_enemy", "event_guardian", "smart_guy"],
				"event_tags": ["guild_test_beacon_recovery_001", "event_guardian", "smart_guy"],
				"overrides": {
					"hp": 160,
					"max_hp": 160,
					"attack": 12,
					"energy_max": 5000,
					"primary": "smart_guy_focus_lance",
					"secondary": "smart_guy_calculated_rail",
					"shield": "smart_guy_mirror_shield",
					"consumable": "smart_guy_patch_cell",
					"item_stacks": {
						"smart_guy_calculated_rounds": 18,
						"smart_guy_patch_cell": 1
					},
					"behavior_profile": "smart_guy",
					"behavior_values": {
						"execute_player_threshold": 0.28,
						"critical_hull_evade_threshold": 0.22,
						"low_hull_evade_threshold": 0.45,
						"low_energy_secondary_threshold": 0.35,
						"decision_cooldown": 1.25
					},
					"reward": ["iron", "cobalt", "smart_guy_calculated_rounds"],
					"ship_name": "The Correct Answer"
				}
			}
		},

		"target": {},

		"required_items": [],

		"reward_packet": {
			"credits": 0,
			"items": [
				{"item_id": "credits", "amount": 25},
				{"item_id": "iron", "amount": 120},
				{"item_id": "repair_kit", "amount": 2},
				{"item_id": "shield_patch_cell", "amount": 2}
			],
			"blueprints": [],
			"lore": [],
			"unlocks": [],
			"message": "Guild reward received: credits, iron, repair kits, and shield patch cells."
		},

		"steps": {
			"talk_to_npc": {
			"objective_text": "A guild contact is broadcasting near Aster Gate. Travel to the contact and speak with them.",
			"target_owner_id": "guild_contact_tier_1",
			"next_step": "go_to_beacon"

			},

			"go_to_beacon": {
				"objective_text": "Travel to the lost beacon. A carrier signal may intercept you at close range.",
				"target_object_id": "lost_beacon_001",
				"arrival_range": 45,
				"next_step": "defeat_guardian"
			},

			"defeat_guardian": {
				"objective_text": "Defeat the Smart Guy signal guardian before touching the beacon data.",
				"target_object_id": "event_guardian_001",
				"enemy_id": "event_guardian_001",
				"interaction_type": "hunt",
				"complete_on_battle_victory": true,
				"next_step": "download_beacon_data",
				"on_enter": [
					{
						"op": "start_battle",
						"enemy_id": "event_guardian_001",
						"entry_reason": "guild_test_signal_guardian",
						"message": "Signal guardian intercepted the beacon link."
					}
				],
				"on_battle_victory": [
					{
						"op": "write_log",
						"message": "Signal guardian defeated.\nBeacon data link is now safe to access."
					},
					{
						"op": "show_tutorial_hint",
						"title": "SIGNAL CLEAR",
						"text": "The hunt target is down. Use the event widget to download the beacon data.",
						"target_point_id": "event_panel",
						"line_to_point_id": "event_panel",
						"duration": 4.0,
						"popup_size": Vector2(300, 118),
						"popup_offset": Vector2(30, -22),
						"draw_line": true,
						"line_color": [0.3, 0.92, 1.0, 0.72],
						"circle_color": [0.3, 0.92, 1.0, 0.22],
						"circle_radius": 24.0,
						"accent_color": [0.3, 0.92, 1.0, 0.95]
					},
					{
						"op": "advance_step",
						"next_step": "download_beacon_data"
					}
				]
			},

			"download_beacon_data": {
				"objective_text": "Download the beacon data into the empty data chip.",
				"target_object_id": "lost_beacon_001",
				"interaction_type": "download",
				"interaction_range": 60,
				"requires_item": "data_chip_empty",
				"gives_item": "data_chip_full",
				"next_step": "return_to_npc",
				"actions": [
					{
						"button_id": "read_beacon_signal",
						"label": "READ",
						"action_id": "show_story_popup",
						"title": "Lost Beacon Signal",
						"text": "[b]Guild Beacon Fragment[/b]\n\nThe carrier wave is stable now. The beacon is old, but the signature is clean enough to copy into an empty data chip.\n\nThis popup is driven from event JSON and can carry scrolling text plus up to two images.",
						"images": [
							{"path": "res://images/logo-v2.png"},
							{"path": "res://images/blue_scifi_backing.png"}
						],
						"popup_size": Vector2(580, 430)
					},
					{
						"button_id": "download_beacon_data",
						"label": "DOWNLOAD",
						"action_id": "download_beacon_data",
						"range": 60
					}
				]
			},

			"return_to_npc": {
				"objective_text": "Return the full data chip to the guild contact.",
				"target_owner_id": "guild_contact_tier_1",
				"interaction_range": 70,
				"requires_item": "data_chip_full",
				"next_step": "completed",
				"actions": [
					{
						"button_id": "claim_event_reward",
						"label": "CLAIM",
						"action_id": "claim_event_reward",
						"range": 70
					}
				]
			}
		},
		"guild_contact_tier_1": {
			"name": "Guild Contact",
			"species": "human",
			"role": "guild scout",
			"friendly": true,
			"can_trade": false,
			"message": "You picked up my signal. Good. I have a job if your ship can handle a little distance.",
			"stays_after_meeting": true,
			"item_list": [],
			"dialogue_lines": [
				"That old beacon is outside normal safe range.",
				"I need someone with enough nerve to pull its data.",
				"Bring the data back and I will make it worth your time."
			],
			"offer_title": "Lost Beacon Recovery",
			"offer_text": "A guild beacon is still broadcasting beyond normal local range. Reach it, download the data, and return.",
			"success_text": "That is the signal data. Good work."
		},
	}


# ==========================================================
# EVENT SAVE DATA
# ----------------------------------------------------------
# Saves runtime progress only. Full event definitions reload
# from JSON so story text and object templates stay editable.
# ==========================================================

func load_event_state_from_save_if_available() -> bool:
	if save_manager == null:
		return false

	if save_manager.has_method("read_event_runtime_save_data"):
		var runtime_data: Dictionary = save_manager.read_event_runtime_save_data()
		if not runtime_data.is_empty():
			return load_from_save_data(runtime_data)

	if not save_manager.has_method("read_universe_save_data"):
		return false

	var save_data: Dictionary = save_manager.read_universe_save_data()
	if save_data.is_empty():
		return false

	var game_events = save_data.get("game_events", {})
	if typeof(game_events) != TYPE_DICTIONARY or game_events.is_empty():
		return false

	return load_from_save_data(game_events)


func to_save_data() -> Dictionary:
	return {
		"schema_version": EVENT_SAVE_SCHEMA_VERSION,
		"active_event_id": active_event_id,
		"test_seed_checked": test_seed_checked,
		"seed_flags": make_json_safe_value(seed_flags),
		"available_events": export_event_runtime_map(available_events),
		"active_events": export_event_runtime_map(active_events),
		"completed_events": export_event_runtime_map(completed_events)
	}


func load_from_save_data(data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false

	active_events.clear()
	completed_events.clear()
	available_events.clear()
	pending_npc_event_start.clear()

	var loaded_seed_flags = data.get("seed_flags", {})
	seed_flags = loaded_seed_flags.duplicate(true) if typeof(loaded_seed_flags) == TYPE_DICTIONARY else {}
	test_seed_checked = bool(data.get("test_seed_checked", not seed_flags.is_empty()))

	var repaired_runtime_state := false
	repaired_runtime_state = import_event_runtime_map(data.get("available_events", {}), available_events) or repaired_runtime_state
	repaired_runtime_state = import_event_runtime_map(data.get("active_events", {}), active_events) or repaired_runtime_state
	repaired_runtime_state = import_event_runtime_map(data.get("completed_events", {}), completed_events) or repaired_runtime_state
	var repaired_completion_state := normalize_loaded_event_completion_state()

	active_event_id = str(data.get("active_event_id", ""))
	if active_event_id == "":
		if not active_events.is_empty():
			active_event_id = str(active_events.keys()[0])
		elif not available_events.is_empty():
			active_event_id = str(available_events.keys()[0])
	elif not active_events.has(active_event_id) and not available_events.has(active_event_id):
		ensure_display_event_selection()

	restore_loaded_event_world_state()
	restore_pending_story_popups_after_load()
	event_widget_dirty = active_event_id != ""
	if repaired_completion_state or repaired_runtime_state:
		save_event_runtime_state()

	if Globals.print_priority_7:
		print(
			"GameEventsHandler loaded save state. active=",
			active_events.keys(),
			" available=",
			available_events.keys(),
			" completed=",
			completed_events.keys()
		)

	return true


func export_event_runtime_map(source: Dictionary) -> Dictionary:
	var out := {}
	for event_id in source.keys():
		var event_data = source[event_id]
		if typeof(event_data) == TYPE_DICTIONARY:
			out[str(event_id)] = export_event_runtime_data(event_data)
	return out


func export_event_runtime_data(event_data: Dictionary) -> Dictionary:
	var event_id := str(event_data.get("event_id", ""))
	return {
		"event_id": event_id,
		"display_name": str(event_data.get("display_name", event_id)),
		"event_state": str(event_data.get("event_state", "")),
		"current_step": str(event_data.get("current_step", "")),
		"last_step": str(event_data.get("last_step", "")),
		"completed": bool(event_data.get("completed", false)),
		"source_path": str(event_data.get("source_path", "")),
		"flags": make_json_safe_value(event_data.get("flags", {})),
		"completed_steps": make_json_safe_value(event_data.get("completed_steps", {})),
		"step_history": make_json_safe_value(event_data.get("step_history", [])),
		"giver": make_json_safe_value(event_data.get("giver", {})),
		"pending_story_popup": make_json_safe_value(event_data.get("pending_story_popup", {}))
	}


func import_event_runtime_map(source, target: Dictionary) -> bool:
	var repaired_any := false
	if typeof(source) != TYPE_DICTIONARY:
		return false

	for event_id in source.keys():
		var snapshot = source[event_id]
		if typeof(snapshot) != TYPE_DICTIONARY:
			continue

		var event_data := import_event_runtime_data(snapshot)
		if event_data.is_empty():
			continue

		if bool(event_data.get("_load_repaired", false)):
			repaired_any = true
			event_data.erase("_load_repaired")

		target[str(event_data.get("event_id", event_id))] = event_data

	return repaired_any


func normalize_loaded_event_completion_state() -> bool:
	var changed := false

	for event_id in completed_events.keys():
		if active_events.has(event_id):
			active_events.erase(event_id)
			changed = true
		if available_events.has(event_id):
			available_events.erase(event_id)
			changed = true

	var active_ids := active_events.keys()
	for event_id in active_ids:
		var event_data: Dictionary = active_events[event_id]
		var current_step := str(event_data.get("current_step", ""))
		var event_state := str(event_data.get("event_state", "")).strip_edges().to_lower()
		var step_data := get_step_data(event_data, current_step)
		var should_complete := bool(event_data.get("completed", false))
		if event_state == "completed" or current_step == "completed":
			should_complete = true
		if should_auto_complete_terminal_step(event_data, current_step, step_data):
			should_complete = true

		if not should_complete:
			continue

		var previous_step := current_step
		if previous_step == "completed":
			previous_step = str(event_data.get("last_step", ""))
		if previous_step != "":
			mark_step_completed_on_event_data(event_data, previous_step)
		event_data["event_state"] = "completed"
		event_data["current_step"] = "completed"
		event_data["last_step"] = previous_step
		event_data["completed"] = true
		completed_events[str(event_id)] = event_data.duplicate(true)
		active_events.erase(event_id)
		available_events.erase(event_id)
		changed = true

	return changed


func is_loaded_event_step_valid(event_data: Dictionary, step_id: String) -> bool:
	if step_id == "completed":
		return true
	if step_id == "":
		return false
	var steps = event_data.get("steps", {})
	return typeof(steps) == TYPE_DICTIONARY and steps.has(step_id)


func resolve_safe_loaded_event_step(event_data: Dictionary, fallback_step: String) -> String:
	if is_loaded_event_step_valid(event_data, fallback_step) and fallback_step != "completed":
		return fallback_step

	var steps = event_data.get("steps", {})
	if typeof(steps) == TYPE_DICTIONARY and not steps.is_empty():
		return str(steps.keys()[0])

	return ""


func import_event_runtime_data(snapshot: Dictionary) -> Dictionary:
	var event_id := str(snapshot.get("event_id", ""))
	if event_id == "":
		return {}

	var event_data := get_event_data_by_id(event_id)
	if event_data.is_empty():
		if Globals.print_priority_7:
			print("Event save import skipped - missing JSON for event id: ", event_id)
		return {}

	var definition_step := str(event_data.get("current_step", ""))
	event_data["event_state"] = str(snapshot.get("event_state", event_data.get("event_state", "active")))
	var loaded_step := str(snapshot.get("current_step", definition_step))
	event_data["current_step"] = loaded_step
	event_data["completed"] = bool(snapshot.get("completed", false))
	var repaired_loaded_step := false
	if not is_loaded_event_step_valid(event_data, loaded_step):
		event_data["current_step"] = resolve_safe_loaded_event_step(event_data, definition_step)
		repaired_loaded_step = true
		event_data["_load_repaired"] = true

	if snapshot.has("flags") and typeof(snapshot["flags"]) == TYPE_DICTIONARY:
		event_data["flags"] = snapshot["flags"].duplicate(true)
	if snapshot.has("completed_steps") and typeof(snapshot["completed_steps"]) == TYPE_DICTIONARY:
		event_data["completed_steps"] = snapshot["completed_steps"].duplicate(true)
	else:
		event_data["completed_steps"] = build_completed_steps_from_legacy_flags(
			event_data.get("flags", {}),
			str(event_data.get("current_step", ""))
		)

	if snapshot.has("step_history") and typeof(snapshot["step_history"]) == TYPE_ARRAY:
		event_data["step_history"] = snapshot["step_history"].duplicate(true)
	else:
		event_data["step_history"] = build_step_history_from_completed_steps(event_data.get("completed_steps", {}))

	if snapshot.has("pending_story_popup") and typeof(snapshot["pending_story_popup"]) == TYPE_DICTIONARY:
		if repaired_loaded_step:
			event_data.erase("pending_story_popup")
		else:
			event_data["pending_story_popup"] = snapshot["pending_story_popup"].duplicate(true)

	if snapshot.has("last_step"):
		event_data["last_step"] = str(snapshot.get("last_step", ""))
	if snapshot.has("giver") and typeof(snapshot["giver"]) == TYPE_DICTIONARY:
		var definition_giver: Dictionary = event_data.get("giver", {}).duplicate(true) if typeof(event_data.get("giver", {})) == TYPE_DICTIONARY else {}
		var template_owner_id := str(definition_giver.get("template_owner_id", definition_giver.get("owner_id", definition_giver.get("object_id", "")))).strip_edges()
		var giver: Dictionary = event_data.get("giver", {}).duplicate(true)
		for key in snapshot["giver"].keys():
			giver[key] = snapshot["giver"][key]
		if template_owner_id != "":
			giver["template_owner_id"] = template_owner_id
			giver["owner_id"] = template_owner_id
			giver["object_id"] = template_owner_id
		elif str(giver.get("template_owner_id", "")).strip_edges() == "":
			giver["template_owner_id"] = template_owner_id
		event_data["giver"] = normalize_position_fields(giver)

	repair_loaded_event_runtime_flags(event_data)
	return event_data


func repair_loaded_event_runtime_flags(event_data: Dictionary) -> void:
	# s1.2:
	# Load is a restore, not a replay/repair trigger.
	# Do NOT erase entered_* or arrived_* flags here.
	# Those flags prevent on_enter/on_arrival JSON from firing again
	# after Battle V2, NPC scene swaps, popup reloads, or normal save/load.

	var flags = event_data.get("flags", {})
	if typeof(flags) != TYPE_DICTIONARY:
		event_data["flags"] = {}
		return

	event_data["flags"] = flags


func restore_loaded_event_world_state() -> void:
	for event_id in available_events.keys():
		repair_available_event_giver_location(str(event_id))

	for event_id in active_events.keys():
		var event_data: Dictionary = active_events[event_id]
		create_event_beacon_if_needed(event_data)
		sync_event_state_to_world(event_data)

	for event_id in completed_events.keys():
		var event_data: Dictionary = completed_events[event_id]
		sync_event_state_to_world(event_data)


func repair_available_event_giver_location(event_id: String) -> void:
	if not available_events.has(event_id):
		return
	if npc_handler == null:
		return

	var event_data: Dictionary = available_events[event_id]
	var giver: Dictionary = event_data.get("giver", {}) if typeof(event_data.get("giver", {})) == TYPE_DICTIONARY else {}
	var sector: Vector3i = _read_sector_pos(giver.get("sector_pos", Vector3i.ZERO))
	var local: Vector3 = _read_local_pos(giver.get("local_pos", Vector3.ZERO))

	if bool(giver.get("place_near_anchor_star", false)):
		var anchor_star = ensure_anchor_star(event_data)
		if anchor_star != null:
			var offset := _read_local_pos(giver.get("local_offset", Vector3(20, 0, 0)))
			var normalized := normalize_sector_local_pair(anchor_star.sector_pos, anchor_star.local_pos + offset)
			sector = normalized["sector_pos"]
			local = normalized["local_pos"]

	var npc = find_existing_event_npc(event_data)
	if npc == null and npc_handler.has_method("make_npc_from_blueprint"):
		var blueprint_id := str(giver.get("blueprint_id", "guild_contact_tier_1"))
		npc = npc_handler.make_npc_from_blueprint(blueprint_id, sector, local)
	if npc == null:
		return

	if sector != Vector3i.ZERO or local != Vector3.ZERO:
		npc.sector_pos = sector
		npc.local_pos = local
	configure_event_npc(npc, event_data, sector, local)
	event_data["giver"] = build_giver_data_for_npc(event_data, npc, sector, local)
	available_events[event_id] = event_data
	event_widget_dirty = true


func make_json_safe_value(value):
	var value_type := typeof(value)

	if value_type == TYPE_VECTOR2:
		return {"x": value.x, "y": value.y}

	if value_type == TYPE_VECTOR2I:
		return {"x": value.x, "y": value.y}

	if value_type == TYPE_VECTOR3:
		return SharedObjectMeta.vector3_to_dict(value)

	if value_type == TYPE_VECTOR3I:
		return SharedObjectMeta.vector3i_to_dict(value)

	if value_type == TYPE_COLOR:
		return {
			"r": value.r,
			"g": value.g,
			"b": value.b,
			"a": value.a
		}

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

# ==========================================================
# HELPERS
# ==========================================================



func is_event_active(event_id: String) -> bool:
	return active_events.has(event_id)


func is_event_completed(event_id: String) -> bool:
	return completed_events.has(event_id)


func get_event_flag(event_data: Dictionary, flag_id: String, fallback = false):
	var flags = event_data.get("flags", {})
	if typeof(flags) != TYPE_DICTIONARY:
		return fallback
	return flags.get(flag_id, fallback)


func set_event_flag(event_id: String, flag_id: String, value, should_save: bool = true) -> void:
	if event_id == "" or flag_id == "":
		return
	if not active_events.has(event_id):
		return

	var event_data: Dictionary = active_events[event_id]
	var flags = event_data.get("flags", {})
	if typeof(flags) != TYPE_DICTIONARY:
		flags = {}
	flags[flag_id] = value
	event_data["flags"] = flags
	active_events[event_id] = event_data

	if should_save:
		save_event_runtime_state()


func print_event_autosave_skip(save_type: String) -> void:
	var clean_type := str(save_type).strip_edges()
	if clean_type == "":
		clean_type = "unknown"
	if bool(event_autosave_skip_printed.get(clean_type, false)):
		return
	event_autosave_skip_printed[clean_type] = true
	print("[EVENT_SAVE_DISABLED] runtime event save skipped | type=", clean_type, " | use quicksave/scene snapshot for persistence")


func print_event_perf(label: String, started_ms: int) -> void:
	var elapsed_ms := Time.get_ticks_msec() - started_ms
	if elapsed_ms >= EVENT_PERF_WARN_MS:
		print("[EVENT_PERF] ", label, " | ", elapsed_ms, "ms")


func show_event_saving_cover(reason: String = "event_save") -> void:
	if main_ui_handler == null or not is_instance_valid(main_ui_handler):
		return
	if not main_ui_handler.has_method("show_saving_cover"):
		return
	main_ui_handler.show_saving_cover("Saving", reason)


func hide_event_saving_cover_deferred(reason: String = "event_save") -> void:
	if main_ui_handler == null or not is_instance_valid(main_ui_handler):
		return
	if not main_ui_handler.has_method("hide_saving_cover_deferred"):
		return
	main_ui_handler.hide_saving_cover_deferred(reason)


func request_event_world_state_save_after_cover(reason: String = "event_save", keep_cover_visible: bool = false) -> void:
	if event_world_save_in_progress:
		print("[EVENT_SAVE_DEFERRED] skipped | already_in_progress=true reason=", reason)
		return

	event_world_save_in_progress = true
	show_event_saving_cover(reason)
	call_deferred("_run_event_world_state_save_after_cover_frame", reason, keep_cover_visible)


func _run_event_world_state_save_after_cover_frame(reason: String = "event_save", keep_cover_visible: bool = false) -> void:
	await get_tree().process_frame
	save_event_world_state(reason, true, keep_cover_visible)
	event_world_save_in_progress = false


func save_event_world_state(reason: String = "world", force_save: bool = false, keep_cover_visible: bool = false) -> void:
	if not force_save and not EVENT_RUNTIME_AUTOSAVE_ENABLED:
		print_event_autosave_skip("world")
		return
	if save_manager == null:
		return

	if save_manager.has_method("save_universe_with_inventory_data"):
		if star_field == null or map == null or space_objects == null or inventory == null or enemy_handler == null:
			if Globals.print_priority_7:
				print("Event save skipped - missing full universe refs.")
			return

		var inventory_data := {}
		if inventory.has_method("get_save_data"):
			inventory_data = inventory.get_save_data()

		show_event_saving_cover(reason)
		save_manager.save_universe_with_inventory_data(
			star_field,
			map,
			space_objects,
			inventory_data,
			enemy_handler,
			npc_handler,
			beacons,
			[],
			[],
			[],
			self
		)
		if not keep_cover_visible:
			hide_event_saving_cover_deferred(reason)
		return

	if save_manager.has_method("save_universe"):
		show_event_saving_cover(reason)
		save_manager.save_universe(star_field, map, space_objects, inventory, enemy_handler, npc_handler, beacons, self)
		if not keep_cover_visible:
			hide_event_saving_cover_deferred(reason)


func save_event_runtime_state() -> void:
	if not EVENT_RUNTIME_AUTOSAVE_ENABLED:
		print_event_autosave_skip("runtime")
		return
	if save_manager == null:
		return
	if save_manager.has_method("save_game_events_section_from_data"):
		if bool(save_manager.save_game_events_section_from_data(to_save_data())):
			return
	save_event_world_state()


func save_event_reward_runtime_state() -> void:
	if not EVENT_RUNTIME_AUTOSAVE_ENABLED:
		print_event_autosave_skip("reward_runtime")
		return
	if save_manager == null:
		return

	var inventory_data := {}
	if inventory != null and inventory.has_method("get_save_data"):
		inventory_data = inventory.get_save_data()

	if save_manager.has_method("save_event_reward_runtime_sections") and not inventory_data.is_empty():
		if bool(save_manager.save_event_reward_runtime_sections(to_save_data(), inventory_data)):
			return

	save_event_world_state()


func save_event_transition_state(context: Dictionary = {}) -> void:
	var save_mode := str(context.get("save_mode", "")).strip_edges().to_lower()
	if save_mode == "defer" or save_mode == "none":
		return
	if not EVENT_RUNTIME_AUTOSAVE_ENABLED:
		print_event_autosave_skip("transition:" + save_mode)
		return
	if save_mode == "full" or save_mode == "world":
		save_event_world_state()
		return
	save_event_runtime_state()


func ensure_anchor_star(event_data: Dictionary):
	var found_star = find_anchor_star(event_data)

	if found_star != null:
		return found_star

	var anchor: Dictionary = event_data.get("anchor_star", {})

	if not bool(anchor.get("create_if_missing", false)):
		return null

	if star_field == null:
		if Globals.print_priority_7:
			print("Anchor star creation failed - star_field missing.")
		return null

	if not star_field.has_method("make_star"):
		if Globals.print_priority_7:
			print("Anchor star creation failed - StarField.make_star missing.")
		return null

	var star_id := str(anchor.get("star_id", "event_anchor_star"))
	var star_name := str(anchor.get("star_name", star_id))
	var star_type := str(anchor.get("star_type", "K"))
	var sector: Vector3i = _read_sector_pos(anchor.get("sector_pos", Vector3i.ZERO))
	var local: Vector3 = _read_local_pos(anchor.get("local_pos", Vector3(500, 500, 500)))
	var brightness := float(anchor.get("brightness", 1.2))
	var size := float(anchor.get("size", 1.4))
	var tier := int(anchor.get("tier", event_data.get("tier", 1)))

	var star = star_field.make_star(
		star_name,
		star_type,
		sector,
		local,
		brightness,
		size
	)

	if star == null:
		if Globals.print_priority_7:
			print("Anchor star creation failed - make_star returned null.")
		return null

	star.object_id = star_id
	star.display_name = star_name
	star.uni_tier_index = tier
	star.uni_tier = "uni_tier_" + str(tier)
	star.tier = tier
	star.section_id = "event_test_tier_" + str(tier)
	star.is_visible = true
	star.is_discovered = false
	star.has_event = true
	star.give_event = str(event_data.get("event_id", ""))
	star.labels = [
		"star",
		"event_anchor_star",
		"guild_event",
		"tier_" + str(tier)
	]

	if star.has_method("sync_shared_meta"):
		star.sync_shared_meta()

	if Globals.print_priority_7:
		print("Created event anchor star: ", star_name, " id=", star_id, " sector=", sector, " local=", local)

	return star
	
func find_anchor_star(event_data: Dictionary):
	if star_field == null:
		return null

	if not "stars" in star_field:
		return null

	var anchor: Dictionary = event_data.get("anchor_star", {})
	var wanted_id := str(anchor.get("star_id", ""))
	var wanted_name := str(anchor.get("star_name", ""))

	for star in star_field.stars:
		if star == null:
			continue

		if wanted_id != "" and str(star.object_id) == wanted_id:
			return star

		if wanted_name != "" and str(star.star_name) == wanted_name:
			return star

	return null
	
func _read_sector_pos(value) -> Vector3i:
	if value is Vector3i:
		return value

	if value is Vector3:
		return Vector3i(int(value.x), int(value.y), int(value.z))

	if typeof(value) == TYPE_DICTIONARY:
		return Vector3i(
			int(value.get("x", 0)),
			int(value.get("y", 0)),
			int(value.get("z", 0))
		)

	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3i(
			int(value[0]),
			int(value[1]),
			int(value[2])
		)

	return Vector3i.ZERO


func _read_local_pos(value) -> Vector3:
	if value is Vector3:
		return value

	if value is Vector3i:
		return Vector3(value.x, value.y, value.z)

	if typeof(value) == TYPE_DICTIONARY:
		return Vector3(
			float(value.get("x", 0.0)),
			float(value.get("y", 0.0)),
			float(value.get("z", 0.0))
		)

	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3(
			float(value[0]),
			float(value[1]),
			float(value[2])
		)

	return Vector3.ZERO


func read_vector2_value(value, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


func get_display_event_data(event_id: String) -> Dictionary:
	if active_events.has(event_id):
		return active_events[event_id]

	if available_events.has(event_id):
		return available_events[event_id]

	return {}
	
func build_giver_target_packet(event_data: Dictionary) -> Dictionary:
	var giver: Dictionary = event_data.get("giver", {})

	var owner_id := str(giver.get("owner_id", giver.get("object_id", "")))
	var display_name := str(giver.get("display_name", "Guild Contact"))

	var sector: Vector3i = _read_sector_pos(giver.get("sector_pos", Vector3i.ZERO))
	var local: Vector3 = _read_local_pos(giver.get("local_pos", Vector3.ZERO))

	return {
		"owner_type": "npc",
		"owner_id": owner_id,
		"display_name": display_name,
		"sector_pos": sector,
		"local_pos": local,
		"event_id": event_data.get("event_id", ""),
		"event_step": event_data.get("current_step", "")
	}


func install_catalog_event_listeners_once() -> void:
	if event_listener_install_checked:
		return
	if beacons == null or world_builder == null:
		return

	event_listener_install_checked = true

	var installed_any := false
	var event_ids := event_catalog.keys()
	event_ids.sort()

	for raw_event_id in event_ids:
		var event_id := str(raw_event_id)
		if event_id == "":
			continue
		if active_events.has(event_id) or available_events.has(event_id) or completed_events.has(event_id):
			continue

		var event_data := get_event_data_by_id(event_id)
		if event_data.is_empty():
			continue

		var listener_defs := get_event_listener_definitions(event_data)
		if listener_defs.is_empty():
			continue

		for listener_id in listener_defs.keys():
			var listener_data = listener_defs[listener_id]
			if typeof(listener_data) != TYPE_DICTIONARY:
				continue
			var result := install_event_listener_beacon(event_id, str(listener_id), listener_data, event_data)
			if bool(result.get("installed", false)):
				installed_any = true

	if installed_any:
		save_event_world_state()


func get_event_listener_definitions(event_data: Dictionary) -> Dictionary:
	var event_listeners = event_data.get("event_listeners", {})
	if typeof(event_listeners) == TYPE_DICTIONARY:
		return event_listeners
	return {}


func install_event_listener_beacon(event_id: String, listener_id: String, listener_data: Dictionary, event_data: Dictionary) -> Dictionary:
	var object_id := str(listener_data.get("object_id", listener_data.get("id", listener_id))).strip_edges()
	if object_id == "":
		object_id = event_id + "_listener"

	var object_data := listener_data.duplicate(true)
	object_data["owner_type"] = str(object_data.get("owner_type", "beacon"))
	object_data["object_type"] = "beacon"
	object_data["object_id"] = object_id
	object_data["id"] = object_id
	object_data["display_name"] = str(object_data.get("display_name", object_data.get("title", "Event Signal")))
	object_data["title"] = str(object_data.get("title", object_data.get("display_name", "Event Signal")))
	object_data["beacon_type"] = str(object_data.get("beacon_type", "event_listener_beacon"))
	object_data["listener_type"] = str(object_data.get("listener_type", "seed_event_on_range"))
	object_data["trigger_event_id"] = str(object_data.get("trigger_event_id", event_id))
	object_data["trigger_once"] = bool(object_data.get("trigger_once", true))
	object_data["triggered"] = bool(object_data.get("triggered", false))
	object_data["trigger_range"] = float(object_data.get("trigger_range", object_data.get("range", 250.0)))
	object_data["has_event"] = false
	object_data["event_id"] = str(object_data.get("event_id", ""))
	object_data["active_event_id"] = str(object_data.get("active_event_id", ""))
	object_data["message"] = str(object_data.get("message", "A quiet signal repeats nearby."))

	if not object_data.has("sector_pos") and not object_data.has("local_pos") and not object_data.has("local_offset"):
		object_data["position_mode"] = "anchor_offset"
		object_data["local_offset"] = Vector3(80, 0, 0)

	object_data["labels"] = merge_event_listener_labels(object_data.get("labels", []))

	var listener_event_data := event_data.duplicate(true)
	listener_event_data["event_objects"] = {
		object_id: object_data
	}

	var result = world_builder.install_event_objects(listener_event_data, "")
	var installed := false
	if typeof(result) == TYPE_DICTIONARY:
		var installed_map = result.get("installed", {})
		if typeof(installed_map) == TYPE_DICTIONARY and installed_map.has(object_id):
			installed = true

	if Globals.print_priority_7:
		print("Event listener install: ", object_id, " -> ", event_id, " installed=", installed, " result=", result)

	return {
		"installed": installed,
		"object_id": object_id,
		"event_id": event_id,
		"result": result
	}


func merge_event_listener_labels(raw_labels) -> Array:
	var labels := SharedObjectMeta.read_array(raw_labels)
	for label in ["beacon", "event_listener", "event_discovery"]:
		if not labels.has(label):
			labels.append(label)
	return labels


func process_orbit_event_discovery_queue(raw_queue) -> Dictionary:
	var result := {
		"ok": true,
		"processed": [],
		"skipped": [],
		"errors": [],
		"processed_count": 0,
		"skipped_count": 0,
		"error_count": 0,
		"silent_count": 0,
		"visible_count": 0
	}

	if typeof(raw_queue) != TYPE_ARRAY:
		result["ok"] = false
		result["errors"].append({"reason": "orbit event discovery queue is not an array"})
		result["error_count"] = 1
		return result

	for raw_packet in raw_queue:
		var packet := normalize_orbit_event_discovery_packet(raw_packet)
		if packet.is_empty():
			result["skipped"].append({"reason": "empty orbit event discovery packet"})
			continue

		var status := str(packet.get("status", "pending")).strip_edges().to_lower()
		if status in ["processed", "completed", "done"]:
			result["skipped"].append({
				"queue_id": str(packet.get("queue_id", packet.get("id", ""))),
				"event_id": str(packet.get("event_id", packet.get("trigger_event_id", ""))),
				"reason": "already processed"
			})
			continue

		var packet_result := process_orbit_event_discovery_packet(packet)
		if bool(packet_result.get("ok", false)):
			result["processed"].append(packet_result)
			result["processed_count"] = int(result["processed_count"]) + 1
			if bool(packet.get("silent", false)):
				result["silent_count"] = int(result["silent_count"]) + 1
			else:
				result["visible_count"] = int(result["visible_count"]) + 1
		else:
			result["errors"].append(packet_result)

	result["skipped_count"] = result["skipped"].size()
	result["error_count"] = result["errors"].size()
	result["ok"] = int(result["error_count"]) == 0

	if int(result["processed_count"]) > 0:
		event_widget_dirty = true
		request_event_pulse("orbit_event_discovery")

	return result


func normalize_orbit_event_discovery_packet(raw_packet) -> Dictionary:
	if typeof(raw_packet) == TYPE_STRING or typeof(raw_packet) == TYPE_STRING_NAME:
		var event_id := str(raw_packet).strip_edges()
		if event_id == "":
			return {}
		return {
			"queue_id": event_id + "_discover_event",
			"event_id": event_id,
			"trigger_event_id": event_id,
			"orbit_event_action": "discover_event",
			"listener_type": "discover_event"
		}

	if typeof(raw_packet) != TYPE_DICTIONARY:
		return {}

	var packet: Dictionary = raw_packet.duplicate(true)
	var event_id := resolve_orbit_event_discovery_event_id(packet)
	if event_id == "":
		return {}

	var listener_type := str(packet.get("listener_type", packet.get("installed_listener_type", "discover_event"))).strip_edges()
	if listener_type == "":
		listener_type = "discover_event"

	var action := str(packet.get("orbit_event_action", packet.get("event_action", packet.get("action", "")))).strip_edges()
	if action == "":
		action = infer_orbit_event_discovery_action(listener_type)
	action = normalize_orbit_event_discovery_action(action)

	var silent := bool(packet.get("silent", packet.get("silent_discovery", packet.get("background", false))))
	if listener_type in ["silent_discover_event", "discover_event_silent", "silent_activate_event", "activate_event_silent"]:
		silent = true

	packet["event_id"] = event_id
	packet["trigger_event_id"] = str(packet.get("trigger_event_id", event_id))
	packet["listener_type"] = listener_type
	packet["orbit_event_action"] = action
	packet["silent"] = silent
	packet["visible_in_orbit"] = bool(packet.get("visible_in_orbit", not silent))

	var queue_id := str(packet.get("queue_id", packet.get("id", packet.get("listener_id", "")))).strip_edges()
	if queue_id == "":
		queue_id = event_id + "_" + action
	packet["queue_id"] = queue_id
	packet["id"] = str(packet.get("id", queue_id))
	return packet


func process_orbit_event_discovery_packet(packet: Dictionary) -> Dictionary:
	var event_id := str(packet.get("event_id", packet.get("trigger_event_id", ""))).strip_edges()
	var action := normalize_orbit_event_discovery_action(str(packet.get("orbit_event_action", "")))
	var queue_id := str(packet.get("queue_id", packet.get("id", ""))).strip_edges()

	if event_id == "":
		return {"ok": false, "queue_id": queue_id, "reason": "missing event_id"}
	if not event_catalog.has(event_id):
		return {"ok": false, "queue_id": queue_id, "event_id": event_id, "reason": "event not found in catalog"}

	var event_data: Dictionary = event_catalog[event_id]
	if not event_intel_conditions_pass(event_data, packet, {"event_id": event_id, "source": "orbit_event_discovery"}):
		return {"ok": false, "queue_id": queue_id, "event_id": event_id, "reason": "event conditions blocked"}

	var action_result: Dictionary = {}
	match action:
		"install_event_listener":
			action_result = install_orbit_discovered_event_listener(event_id, packet, event_data)
		"activate_event":
			action_result = activate_event_by_id_from_listener(event_id, packet)
		_:
			action_result = seed_event_by_id(event_id)

	action_result["queue_id"] = queue_id
	action_result["event_id"] = event_id
	action_result["orbit_event_action"] = action
	action_result["silent"] = bool(packet.get("silent", false))
	action_result["source"] = "orbit_event_discovery"
	return action_result


func install_orbit_discovered_event_listener(event_id: String, packet: Dictionary, event_data: Dictionary) -> Dictionary:
	var listener_id := str(packet.get("listener_id", packet.get("object_id", packet.get("queue_id", event_id + "_orbit_listener")))).strip_edges()
	if listener_id == "":
		listener_id = event_id + "_orbit_listener"

	var listener_data := packet.duplicate(true)
	var installed_listener_type := str(listener_data.get("installed_listener_type", listener_data.get("target_listener_type", ""))).strip_edges()
	if installed_listener_type == "":
		var raw_listener_type := str(listener_data.get("listener_type", "activate_event_on_range")).strip_edges()
		installed_listener_type = raw_listener_type
	if installed_listener_type in ["install_event_listener", "spawn_event_listener", "discover_event_listener"]:
		installed_listener_type = "activate_event_on_range"

	listener_data["listener_type"] = installed_listener_type
	listener_data["trigger_event_id"] = event_id
	listener_data["object_id"] = listener_id
	listener_data["id"] = listener_id
	if bool(listener_data.get("silent", false)):
		listener_data["suppress_trigger_popup"] = true
		if not listener_data.has("is_visible"):
			listener_data["is_visible"] = false
		if not listener_data.has("is_discovered"):
			listener_data["is_discovered"] = false
	if not listener_data.has("trigger_once"):
		listener_data["trigger_once"] = true

	var install_result := install_event_listener_beacon(event_id, listener_id, listener_data, event_data)
	var installed := bool(install_result.get("installed", false))
	return {
		"ok": installed,
		"event_id": event_id,
		"listener_id": listener_id,
		"result": "event_listener_installed" if installed else "event_listener_install_failed",
		"install_result": install_result
	}


func resolve_orbit_event_discovery_event_id(packet: Dictionary) -> String:
	for key in ["trigger_event_id", "event_id", "target_event_id", "discover_event_id", "activate_event_id"]:
		var event_id := str(packet.get(key, "")).strip_edges()
		if event_id != "":
			return event_id
	return ""


func infer_orbit_event_discovery_action(listener_type: String) -> String:
	var clean_type := listener_type.strip_edges()
	if clean_type in ["install_event_listener", "spawn_event_listener", "discover_event_listener"]:
		return "install_event_listener"
	if clean_type in ["activate_event", "activate_event_on_range", "start_event", "start_event_on_range", "silent_activate_event", "activate_event_silent"]:
		return "activate_event"
	return "discover_event"


func normalize_orbit_event_discovery_action(action: String) -> String:
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


func process_world_event_listeners() -> void:
	if beacons == null:
		return
	if map == null:
		return
	if Globals.battle_mode or Globals.battle_pending:
		return
	if not "beacons" in beacons:
		return

	for beacon in beacons.beacons:
		if typeof(beacon) != TYPE_DICTIONARY:
			continue

		if not beacon_is_event_listener(beacon):
			continue

		var listener_type := str(beacon.get("listener_type", "")).strip_edges()
		if not is_supported_event_listener_type(listener_type):
			continue

		# Seed listeners and activate listeners should normally only fire once.
		var trigger_once := bool(beacon.get("trigger_once", true))
		trigger_once = trigger_once or is_event_seed_listener_type(listener_type) or is_event_activate_listener_type(listener_type)

		if trigger_once and bool(beacon.get("triggered", false)):
			continue

		var event_id := str(beacon.get("trigger_event_id", "")).strip_edges()
		if event_id == "":
			continue

		if not event_catalog.has(event_id):
			if Globals.print_priority_7:
				print("Event listener skipped - missing catalog event: ", event_id)
			continue

		var listener_event_data: Dictionary = event_catalog[event_id]
		if not event_intel_conditions_pass(listener_event_data, beacon, {"event_id": event_id, "source": "event_listener"}):
			continue

		var trigger_range := float(beacon.get("trigger_range", 250.0))
		var sector := _read_sector_pos(beacon.get("trigger_sector_pos", beacon.get("sector_pos", Vector3i.ZERO)))
		var local := _read_local_pos(beacon.get("trigger_local_pos", beacon.get("local_pos", Vector3.ZERO)))

		if map.get_distance_to_target(sector, local) > trigger_range:
			continue

		var result: Dictionary = {}

		if is_event_activate_listener_type(listener_type):
			result = activate_event_by_id_from_listener(event_id, beacon)
		else:
			result = seed_event_by_id(event_id)

		if bool(result.get("ok", false)):
			mark_beacon_listener_triggered(beacon, result)

			# For activate_event_on_range, I recommend leaving trigger_popup_message blank
			# in JSON if the first active step already opens a story popup.
			show_beacon_listener_trigger_feedback(beacon, result)

			SharedObjectMeta.apply_to_dictionary(
				beacon,
				str(beacon.get("object_id", beacon.get("id", ""))),
				"beacon",
				str(beacon.get("display_name", beacon.get("title", "Beacon"))),
				_read_sector_pos(beacon.get("sector_pos", Vector3i.ZERO)),
				_read_local_pos(beacon.get("local_pos", Vector3.ZERO))
			)

			save_event_world_state()

			if Globals.print_priority_7:
				print("World event listener triggered event: ", event_id, " | listener_type=", listener_type)
		elif Globals.print_priority_7:
			print("World event listener failed: ", event_id, " | ", result)


func is_supported_event_listener_type(listener_type: String) -> bool:
	return is_event_seed_listener_type(listener_type) or is_event_activate_listener_type(listener_type)


func is_event_seed_listener_type(listener_type: String) -> bool:
	var t := str(listener_type).strip_edges()
	return [
		"seed_event_on_range",
		"seed_event",
		"add_available_event",
		"discover_event"
	].has(t)


func mark_beacon_listener_triggered(beacon: Dictionary, result: Dictionary) -> void:
	beacon["triggered"] = true
	beacon["trigger_result"] = str(result.get("result", "event_seeded_available"))
	beacon["trigger_reason"] = str(result.get("reason", ""))
	beacon["is_completed"] = true
	beacon["completed"] = true
	beacon["helper_state"] = "triggered"
	beacon["message"] = str(beacon.get("triggered_message", "Signal accepted. New event contact added."))


func show_beacon_listener_trigger_feedback(beacon: Dictionary, result: Dictionary) -> void:
	if widget_state == null:
		return

	# IMPORTANT:
	# Direct activation listeners usually hand control straight to the first event step.
	# If we always call Globals.show_popup() here, that generic click-to-close popup
	# sits on top of the first story popup and makes it look like timer/story chaining
	# is broken. That was the regression: the listener acknowledgement popup was
	# masking the real story popup behind it.
	#
	# Rules:
	# - Explicit trigger_popup_message still shows.
	# - seed/discovery listeners keep the old default feedback behavior.
	# - activate/start listeners are silent by default unless show_trigger_feedback is true.
	# - suppress_trigger_popup always wins.
	if bool(beacon.get("suppress_trigger_popup", false)):
		return

	var listener_type := str(beacon.get("listener_type", "")).strip_edges()
	var message := str(beacon.get("trigger_popup_message", "")).strip_edges()
	var wants_legacy_feedback := bool(beacon.get("show_trigger_feedback", false))

	if message == "" and wants_legacy_feedback:
		message = str(beacon.get("triggered_message", "")).strip_edges()

	if message == "" and is_event_seed_listener_type(listener_type):
		message = str(beacon.get("triggered_message", "")).strip_edges()
		if message == "":
			var seed_event_id := str(result.get("event_id", beacon.get("trigger_event_id", "")))
			message = "Intercepted beacon signal.\nNew event added: " + seed_event_id

	# Activation listeners should not create a generic popup unless the JSON asked for it.
	# The event's first step is responsible for story UI.
	if message == "":
		return

	Globals.show_popup(widget_state, message)


func event_intel_conditions_pass(event_data: Dictionary, source_packet: Dictionary = {}, context: Dictionary = {}) -> bool:
	var conditions := collect_event_intel_conditions(event_data, source_packet)
	for condition in conditions:
		if typeof(condition) != TYPE_DICTIONARY:
			continue
		if not evaluate_event_intel_condition(condition, context):
			if Globals.print_priority_7:
				print("[EVENT_INTEL_CONDITION_BLOCKED] condition=", condition, " context=", context)
			return false
	return true


func collect_event_intel_conditions(event_data: Dictionary, source_packet: Dictionary = {}) -> Array:
	var out: Array = []
	for source in [event_data, source_packet]:
		if typeof(source) != TYPE_DICTIONARY:
			continue
		for key in ["intel_conditions", "awareness_conditions", "event_conditions", "requires_intel", "conditions"]:
			if source.has(key):
				append_event_intel_conditions(out, source.get(key))
	return out


func append_event_intel_conditions(out: Array, raw_conditions) -> void:
	if typeof(raw_conditions) == TYPE_ARRAY:
		for condition in raw_conditions:
			append_event_intel_conditions(out, condition)
		return

	if typeof(raw_conditions) == TYPE_DICTIONARY:
		var condition_dict: Dictionary = raw_conditions
		if condition_dict.has("type") or condition_dict.has("condition") or condition_dict.has("condition_type"):
			out.append(condition_dict.duplicate(true))
			return

		for key in condition_dict.keys():
			var value = condition_dict[key]
			if typeof(value) == TYPE_DICTIONARY:
				var condition = value.duplicate(true)
				if not condition.has("type"):
					condition["type"] = str(key)
				out.append(condition)
			else:
				out.append({
					"type": str(key),
					"value": value
				})
		return

	if typeof(raw_conditions) == TYPE_STRING:
		out.append({"type": str(raw_conditions)})


func evaluate_event_intel_condition(condition: Dictionary, context: Dictionary = {}) -> bool:
	var condition_type := str(condition.get("type", condition.get("condition_type", condition.get("condition", "")))).strip_edges().to_lower()
	if not is_supported_event_intel_condition_type(condition_type):
		return true

	match condition_type:
		"intel_discovered":
			var intel_id := resolve_condition_intel_id(condition)
			return intel_id != "" and intel_handler != null and intel_handler.has_method("has_discovered") and bool(intel_handler.has_discovered(intel_id))
		"intel_count_at_least", "intel_seen_count":
			var intel_id := resolve_condition_intel_id(condition)
			var required_count := resolve_condition_required_count(condition)
			return intel_id != "" and intel_handler != null and intel_handler.has_method("get_discovery_count") and int(intel_handler.get_discovery_count(intel_id)) >= required_count
		"enemy_serial_defeated":
			var serial := str(condition.get("enemy_serial", condition.get("serial", condition.get("value", "")))).strip_edges()
			return serial != "" and enemy_intel_handler != null and enemy_intel_handler.has_method("has_enemy_serial_defeated") and bool(enemy_intel_handler.has_enemy_serial_defeated(serial))
		"event_enemy_defeated":
			return evaluate_event_enemy_defeated_condition(condition, context)
		"enemy_display_defeated_count", "enemy_defeated_count":
			return evaluate_enemy_defeated_count_condition(condition)

	return true


func is_supported_event_intel_condition_type(condition_type: String) -> bool:
	return [
		"intel_discovered",
		"intel_count_at_least",
		"intel_seen_count",
		"enemy_defeated_count",
		"enemy_serial_defeated",
		"event_enemy_defeated",
		"enemy_display_defeated_count"
	].has(condition_type)


func resolve_condition_intel_id(condition: Dictionary) -> String:
	for key in ["intel_id", "item_id", "id", "key", "value"]:
		var value := str(condition.get(key, "")).strip_edges()
		if value != "":
			return value
	return ""


func resolve_condition_required_count(condition: Dictionary) -> int:
	for key in ["min_count", "required_count", "count", "amount", "at_least", "value"]:
		if condition.has(key):
			return max(int(condition.get(key, 1)), 1)
	return 1


func evaluate_event_enemy_defeated_condition(condition: Dictionary, context: Dictionary = {}) -> bool:
	if enemy_intel_handler == null or not enemy_intel_handler.has_method("get_event_enemy_serial") or not enemy_intel_handler.has_method("has_enemy_serial_defeated"):
		return false

	var event_id := str(condition.get("event_id", context.get("event_id", ""))).strip_edges()
	var enemy_id := ""
	for key in ["enemy_id", "object_id", "target_object_id", "id", "value"]:
		enemy_id = str(condition.get(key, "")).strip_edges()
		if enemy_id != "":
			break
	if event_id == "" or enemy_id == "":
		return false

	var serial := str(enemy_intel_handler.get_event_enemy_serial(event_id, enemy_id)).strip_edges()
	return serial != "" and bool(enemy_intel_handler.has_enemy_serial_defeated(serial))


func evaluate_enemy_defeated_count_condition(condition: Dictionary) -> bool:
	var required_count := resolve_condition_required_count(condition)
	var serial := str(condition.get("enemy_serial", condition.get("serial", ""))).strip_edges()
	if serial != "" and enemy_intel_handler != null and enemy_intel_handler.has_method("has_enemy_serial_defeated"):
		return bool(enemy_intel_handler.has_enemy_serial_defeated(serial))

	var display_name := ""
	for key in ["display_name", "enemy_name", "enemy_display_name", "enemy_key", "key", "value"]:
		display_name = str(condition.get(key, "")).strip_edges()
		if display_name != "":
			break

	if display_name != "" and enemy_intel_handler != null and enemy_intel_handler.has_method("get_defeated_count_for_display_name"):
		return int(enemy_intel_handler.get_defeated_count_for_display_name(display_name)) >= required_count

	if display_name != "" and intel_handler != null and intel_handler.has_method("get_enemy_defeat_count"):
		return int(intel_handler.get_enemy_defeat_count(display_name)) >= required_count

	return false


func seed_event_by_id(event_id: String) -> Dictionary:
	if not event_catalog.has(event_id):
		return {
			"ok": false,
			"reason": "event not found in catalog: " + event_id
		}

	if available_events.has(event_id):
		return {
			"ok": true,
			"reason": "event already available",
			"event_id": event_id,
			"result": "event_already_available"
		}

	if active_events.has(event_id):
		return {
			"ok": true,
			"reason": "event already active",
			"event_id": event_id,
			"result": "event_already_active"
		}

	if completed_events.has(event_id):
		return {
			"ok": true,
			"reason": "event already completed",
			"event_id": event_id,
			"result": "event_already_completed"
		}

	var event_data: Dictionary = event_catalog[event_id].duplicate(true)

	# Existing legacy-name route, but it is generic behavior.
	var seeded := seed_guild_test_event_npc(event_data)
	if not seeded:
		return {
			"ok": false,
			"reason": "event giver seed failed",
			"event_id": event_id,
			"result": "event_seed_failed"
		}

	seed_flags[event_id] = true
	event_widget_dirty = true
	save_event_world_state()

	return {
		"ok": true,
		"event_id": event_id,
		"result": "event_seeded_available"
	}
	
func beacon_is_event_listener(beacon: Dictionary) -> bool:
	var labels := SharedObjectMeta.read_array(beacon.get("labels", []))
	if labels.has("event_listener"):
		return true

	var shared_meta = beacon.get("shared_meta", {})
	if typeof(shared_meta) == TYPE_DICTIONARY:
		var shared_labels := SharedObjectMeta.read_array(shared_meta.get("labels", []))
		if shared_labels.has("event_listener"):
			return true

	return str(beacon.get("listener_type", "")).strip_edges() != ""


func activate_event_by_id_from_listener(event_id: String, beacon: Dictionary = {}) -> Dictionary:
	if not event_catalog.has(event_id):
		return {"ok": false, "reason": "event not found in catalog: " + event_id}

	if completed_events.has(event_id):
		return {"ok": true, "event_id": event_id, "result": "event_already_completed"}

	if active_events.has(event_id):
		active_event_id = event_id
		event_widget_dirty = true
		return {"ok": true, "event_id": event_id, "result": "event_already_active"}

	var event_data: Dictionary = event_catalog[event_id].duplicate(true)

	event_data["event_state"] = "active"

	var authored_start_step := resolve_event_start_step(event_data)
	var requested_start_step := str(beacon.get("start_step", authored_start_step)).strip_edges()
	var steps = event_data.get("steps", {})
	if requested_start_step != "" and requested_start_step != authored_start_step:
		return {
			"ok": false,
			"reason": "listener start_step does not match authored start step",
			"event_id": event_id,
			"requested_start_step": requested_start_step,
			"authored_start_step": authored_start_step
		}
	var start_step := authored_start_step
	if start_step == "" or typeof(steps) != TYPE_DICTIONARY or not steps.has(start_step):
		return {"ok": false, "reason": "authored start step missing", "event_id": event_id}

	event_data["current_step"] = start_step

	active_events[event_id] = event_data
	available_events.erase(event_id)
	active_event_id = event_id

	create_event_beacon_if_needed(event_data)
	sync_event_state_to_world(event_data)

	seed_flags[event_id] = true
	event_widget_dirty = true
	save_event_world_state()

	return {
		"ok": true,
		"event_id": event_id,
		"result": "event_activated_from_listener"
	}
	
func is_event_activate_listener_type(listener_type: String) -> bool:
	var t := str(listener_type).strip_edges()
	return [
		"activate_event_on_range",
		"activate_event",
		"start_event_on_range",
		"start_event"
	].has(t)


func get_battle_result_authored_context(result: Dictionary) -> Dictionary:
	for key in ["authored_event_context", "battle_authored_context", "event_context"]:
		if typeof(result.get(key, {})) == TYPE_DICTIONARY:
			return result.get(key, {}).duplicate(true)
	return {}


func merge_battle_result_context_into_shared_meta(shared_meta: Dictionary, authored_context: Dictionary) -> Dictionary:
	var merged := shared_meta.duplicate(true)

	# The battle-entry context is the authoritative event scope. Defeated enemy
	# shared meta may still contain the step where the enemy was first installed.
	for key in [
		"event_id",
		"active_event_id",
		"event_step",
		"current_step",
		"required_step"
	]:
		if not authored_context.has(key):
			continue
		if not is_battle_result_identity_value_missing(authored_context.get(key, null)):
			merged[key] = authored_context.get(key)

	for key in [
		"object_id",
		"enemy_serial",
		"enemy_template_id",
		"display_name"
	]:
		if not authored_context.has(key):
			continue
		if is_battle_result_identity_value_missing(merged.get(key, null)):
			merged[key] = authored_context.get(key)

	if is_battle_result_identity_value_missing(merged.get("object_id", null)):
		merged["object_id"] = str(authored_context.get("enemy_id", authored_context.get("target_object_id", "")))

	return merged


func is_battle_result_identity_value_missing(value) -> bool:
	if value == null:
		return true
	if typeof(value) == TYPE_STRING:
		return str(value).strip_edges() == ""
	if typeof(value) == TYPE_ARRAY:
		return value.is_empty()
	if typeof(value) == TYPE_DICTIONARY:
		return value.is_empty()
	return false


func resolve_battle_result_event_id(result: Dictionary, shared_meta: Dictionary, authored_context: Dictionary) -> String:
	for value in [
		shared_meta.get("event_id", ""),
		shared_meta.get("active_event_id", ""),
		authored_context.get("event_id", ""),
		authored_context.get("active_event_id", ""),
		result.get("event_id", ""),
		result.get("active_event_id", "")
	]:
		var event_id := str(value).strip_edges()
		if event_id != "":
			return event_id

	return find_active_battle_event_for_result(result)


func battle_result_has_event_scope_claim(
	result: Dictionary,
	shared_meta: Dictionary,
	authored_context: Dictionary,
	result_step: String = "",
	required_step: String = ""
) -> bool:
	# Summary: True only when a Battle V2 result appears to belong to an authored event.
	# Free-roam enemies may still carry object_id/enemy_id/display_name through shared meta;
	# those are world identity fields, not event-scope fields.
	for packet in [shared_meta, authored_context, result]:
		if typeof(packet) != TYPE_DICTIONARY:
			continue
		for key in ["event_id", "active_event_id"]:
			if str(packet.get(key, "")).strip_edges() != "":
				return true

	if str(result_step).strip_edges() != "":
		return true
	if str(required_step).strip_edges() != "":
		return true

	return false


func get_battle_result_defeated_object_id(result: Dictionary, shared_meta: Dictionary = {}, authored_context: Dictionary = {}) -> String:
	for value in [
		shared_meta.get("object_id", ""),
		shared_meta.get("id", ""),
		authored_context.get("enemy_id", ""),
		authored_context.get("target_object_id", ""),
		authored_context.get("object_id", ""),
		result.get("defeated_enemy_id", "")
	]:
		var object_id := str(value).strip_edges()
		if object_id != "":
			return object_id
	return ""


func find_active_battle_event_for_result(result: Dictionary) -> String:
	var shared_meta = result.get("defeated_enemy_shared_meta", {})
	if typeof(shared_meta) != TYPE_DICTIONARY:
		shared_meta = {}
	var authored_context := get_battle_result_authored_context(result)
	var context_event_id := str(authored_context.get("event_id", authored_context.get("active_event_id", ""))).strip_edges()
	if context_event_id != "" and active_events.has(context_event_id):
		return context_event_id

	var defeated_id := get_battle_result_defeated_object_id(result, shared_meta, authored_context)

	for event_id in active_events.keys():
		var event_data: Dictionary = active_events[event_id]
		var current_step := str(event_data.get("current_step", ""))
		var step_data := get_step_data(event_data, current_step)

		if step_data.is_empty():
			continue

		var target_id := str(step_data.get("enemy_id", step_data.get("target_object_id", ""))).strip_edges()
		if defeated_id != "" and target_id != "" and defeated_id != target_id:
			continue

		if bool(step_data.get("complete_on_battle_victory", false)):
			return str(event_id)

		if str(step_data.get("interaction_type", "")) == "hunt":
			return str(event_id)

		if str(step_data.get("event_type", "")) == "hunt":
			return str(event_id)

		if str(step_data.get("step_kind", "")) == "hunt":
			return str(event_id)

		if str(step_data.get("enemy_id", "")) != "":
			return str(event_id)

	return ""
	
	
func get_completed_steps(event_data: Dictionary) -> Dictionary:
	var completed_steps = event_data.get("completed_steps", {})
	if typeof(completed_steps) != TYPE_DICTIONARY:
		completed_steps = {}
		event_data["completed_steps"] = completed_steps
	return completed_steps


func get_step_history(event_data: Dictionary) -> Array:
	var step_history = event_data.get("step_history", [])
	if typeof(step_history) != TYPE_ARRAY:
		step_history = []
		event_data["step_history"] = step_history
	return step_history


func is_step_completed(event_data: Dictionary, step_id: String) -> bool:
	if step_id == "":
		return false

	var completed_steps := get_completed_steps(event_data)
	if bool(completed_steps.get(step_id, false)):
		return true

	var flags = event_data.get("flags", {})
	if typeof(flags) == TYPE_DICTIONARY:
		if bool(flags.get("completed_" + step_id, false)):
			return true

	return false


func mark_step_completed(event_id: String, step_id: String, should_save: bool = true) -> void:
	if event_id == "" or step_id == "":
		return
	if not active_events.has(event_id):
		return

	var event_data: Dictionary = active_events[event_id]
	mark_step_completed_on_event_data(event_data, step_id)
	active_events[event_id] = event_data

	if should_save:
		save_event_runtime_state()


func mark_step_completed_on_event_data(event_data: Dictionary, step_id: String) -> void:
	if step_id == "":
		return

	var completed_steps := get_completed_steps(event_data)
	completed_steps[step_id] = true
	event_data["completed_steps"] = completed_steps
	record_step_history(event_data, step_id, "completed")

	var flags = event_data.get("flags", {})
	if typeof(flags) != TYPE_DICTIONARY:
		flags = {}
	flags["completed_" + step_id] = true
	event_data["flags"] = flags


func record_step_history(event_data: Dictionary, step_id: String, state: String = "completed") -> void:
	if step_id == "":
		return

	var step_history := get_step_history(event_data)
	for entry in step_history:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("step_id", "")) == step_id and str(entry.get("state", "")) == state:
			return

	step_history.append({
		"step_id": step_id,
		"state": state,
		"timestamp_unix": Time.get_unix_time_from_system()
	})
	event_data["step_history"] = step_history
	
	
func get_completed_step_replay_next_step(step_data: Dictionary) -> String:
	var direct_next := str(step_data.get("next_step", ""))
	if direct_next != "":
		return direct_next

	var direct_close_next := str(step_data.get("next_step_on_close", ""))
	if direct_close_next != "":
		return direct_close_next

	var operations = step_data.get("on_enter", [])
	if typeof(operations) == TYPE_ARRAY:
		for operation in operations:
			if typeof(operation) != TYPE_DICTIONARY:
				continue

			var op_next := str(operation.get("next_step", ""))
			if op_next != "":
				return op_next

			var op_close_next := str(operation.get("next_step_on_close", ""))
			if op_close_next != "":
				return op_close_next

	return ""


func try_skip_completed_step_replay(event_id: String, event_data: Dictionary, step_id: String, step_data: Dictionary) -> bool:
	if not is_step_completed(event_data, step_id):
		return false

	var next_step := get_completed_step_replay_next_step(step_data)

	if Globals.print_priority_7:
		print(
			"[EVENT_STEP_REPLAY_BLOCKED] event=",
			event_id,
			" step=",
			step_id,
			" next=",
			next_step
		)

	if next_step != "" and next_step != step_id:
		advance_event_to_step(event_id, next_step, {
			"source": "completed_step_replay",
			"event_step": step_id,
			"required_step": step_id
		})
	elif should_auto_complete_terminal_step(event_data, step_id, step_data):
		complete_event(event_id, event_data)
		save_event_runtime_state()

	return true
	
func build_completed_steps_from_legacy_flags(flags, current_step: String) -> Dictionary:
	var completed_steps := {}

	if typeof(flags) != TYPE_DICTIONARY:
		return completed_steps

	for flag_id in flags.keys():
		if not bool(flags.get(flag_id, false)):
			continue

		var flag_text := str(flag_id)
		var step_id := ""

		if flag_text.begins_with("completed_"):
			step_id = flag_text.replace("completed_", "")
		elif flag_text.begins_with("entered_"):
			step_id = flag_text.replace("entered_", "")
		elif flag_text.begins_with("arrived_"):
			step_id = flag_text.replace("arrived_", "")

		if step_id == "":
			continue

		# Important: do not treat the current step as completed just because it was entered.
		# That preserves crash recovery for the currently-open step.
		if step_id == current_step and not flag_text.begins_with("completed_"):
			continue

		completed_steps[step_id] = true

	return completed_steps


func build_step_history_from_completed_steps(completed_steps) -> Array:
	var history := []
	if typeof(completed_steps) != TYPE_DICTIONARY:
		return history

	for step_id in completed_steps.keys():
		if bool(completed_steps.get(step_id, false)):
			history.append({
				"step_id": str(step_id),
				"state": "completed",
				"timestamp_unix": 0
			})

	return history


func print_battle_result_summary(result: Dictionary, label: String = "summary") -> void:
	if not Globals.print_priority_7:
		return

	var shared_meta = result.get("defeated_enemy_shared_meta", {})
	if typeof(shared_meta) != TYPE_DICTIONARY:
		shared_meta = {}

	print(
		"[EVENT_BATTLE_RESULT] ",
		label,
		" outcome=",
		str(result.get("outcome", "")),
		" battle_id=",
		str(result.get("battle_id", "")),
		" defeated_enemy_id=",
		str(result.get("defeated_enemy_id", "")),
		" event_id=",
		str(shared_meta.get("event_id", shared_meta.get("active_event_id", ""))),
		" result_step=",
		str(shared_meta.get("event_step", shared_meta.get("current_step", ""))),
		" required_step=",
		str(shared_meta.get("required_step", ""))
	)
	
func remember_pending_story_popup(event_id: String, event_data: Dictionary, popup_packet: Dictionary, close_operations: Array) -> void:
	if event_id == "":
		return
	if close_operations.is_empty():
		return
	if not active_events.has(event_id):
		return

	var safe_popup_packet := popup_packet.duplicate(true)
	safe_popup_packet.erase("on_close_callable")
	safe_popup_packet.erase("on_close_context")
	safe_popup_packet.erase("_skip_pending_story_popup_save")

	event_data["pending_story_popup"] = {
		"event_id": event_id,
		"event_step": str(event_data.get("current_step", "")),
		"story_popup_token": str(popup_packet.get("story_popup_token", "")),
		"popup_packet": make_json_safe_value(safe_popup_packet),
		"operations": make_json_safe_value(close_operations),
		"source": "story_popup_open"
	}

	active_events[event_id] = event_data
	save_event_runtime_state()


func clear_pending_story_popup(event_id: String, story_popup_token: String = "") -> void:
	if event_id == "":
		return
	if not active_events.has(event_id):
		return

	var event_data: Dictionary = active_events[event_id]
	if event_data.has("pending_story_popup"):
		var pending = event_data.get("pending_story_popup", {})
		if story_popup_token.strip_edges() != "" and typeof(pending) == TYPE_DICTIONARY:
			var pending_token := str(pending.get("story_popup_token", "")).strip_edges()
			var pending_packet = pending.get("popup_packet", {})
			if pending_token == "" and typeof(pending_packet) == TYPE_DICTIONARY:
				pending_token = str(pending_packet.get("story_popup_token", "")).strip_edges()
			if pending_token != "" and pending_token != story_popup_token.strip_edges():
				return
		event_data.erase("pending_story_popup")
		active_events[event_id] = event_data
		save_event_runtime_state()


func restore_pending_story_popups_after_load() -> void:
	if widget_builder == null:
		return
	if not widget_builder.has_method("show_story_popup"):
		return

	for event_id in active_events.keys():
		var event_data: Dictionary = active_events[event_id]
		var pending = event_data.get("pending_story_popup", {})
		if typeof(pending) != TYPE_DICTIONARY or pending.is_empty():
			continue

		var popup_packet = pending.get("popup_packet", {})
		if typeof(popup_packet) != TYPE_DICTIONARY or popup_packet.is_empty():
			continue

		var operations = pending.get("operations", [])
		if typeof(operations) != TYPE_ARRAY or operations.is_empty():
			continue

		var restored_packet: Dictionary = popup_packet.duplicate(true)
		var story_popup_token := str(pending.get("story_popup_token", restored_packet.get("story_popup_token", ""))).strip_edges()
		if story_popup_token == "":
			story_popup_token = build_event_story_popup_token(
				str(event_id),
				str(pending.get("event_step", event_data.get("current_step", "")))
			)
		restored_packet["story_popup_token"] = story_popup_token
		restored_packet["on_close_callable"] = Callable(self, "handle_story_popup_closed")
		restored_packet["on_close_context"] = {
			"event_id": str(event_id),
			"event_step": str(pending.get("event_step", event_data.get("current_step", ""))),
			"story_popup_token": story_popup_token,
			"operations": operations,
			"source": "story_popup_recovered"
		}

		widget_builder.show_story_popup(restored_packet)
