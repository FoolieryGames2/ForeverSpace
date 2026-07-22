extends RefCounted
class_name NPCSceneBridge


# ==========================================================
# NPC SCENE BRIDGE
# ----------------------------------------------------------
# Owns NPC talk scene handoff packet creation.
#
# Does NOT change scenes directly.
# main_mode.gd still owns add_scene_tree_swap_check().
# ==========================================================


var inventory = null
var star_field = null
var map_ref = null
var space_objects = null
var player_state: PlayerState = null



var save_manager = null
var enemy_handler = null
var npc_handler = null
var beacons: Beacons = null
var game_event_handler = null

func setup(refs: Dictionary) -> void:
	# Summary: Receives main-owned references needed for NPC scene handoff snapshots.
	inventory = refs.get("inventory", null)
	star_field = refs.get("star_field", null)
	map_ref = refs.get("map", null)
	space_objects = refs.get("space_objects", null)
	player_state = refs.get("player_state", null)

	save_manager = refs.get("save_manager", null)
	enemy_handler = refs.get("enemy_handler", null)
	npc_handler = refs.get("npc_handler", null)
	beacons = refs.get("beacons", null)
	game_event_handler = refs.get("game_event_handler", null)

func request_npc_chat(npc_data: Dictionary) -> bool:
	# Summary: Builds the NPC talk packet and requests the NPC transition scene.
	# Important: This only sets Globals.swap_NPC_tran. It does not change scenes directly.

	if npc_data.is_empty():
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE request_failed] reason=empty_npc_data")
		return false

	var npc_packet := npc_data.duplicate(true)

	var tracked_npc := find_tracked_npc_for_chat_packet(npc_data)

	if tracked_npc != null and npc_handler != null and npc_handler.has_method("build_npc_chat_packet"):
		npc_packet = npc_handler.build_npc_chat_packet(tracked_npc)

		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE hydrated_packet] keys=", npc_packet.keys())
			print("[NPC_SCENE_BRIDGE hydrated_can_trade] ", npc_packet.get("can_trade", "NO_CAN_TRADE"))
			print("[NPC_SCENE_BRIDGE hydrated_trade_completed] ", npc_packet.get("trade_completed", "NO_TRADE_COMPLETED"))
	else:
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE using_raw_packet] keys=", npc_packet.keys())

	# ------------------------------------------------------
	# Inventory snapshot for NPC inventory clone.
	# ------------------------------------------------------
	var inventory_snapshot := build_inventory_save_data()
	if not inventory_snapshot.is_empty():
		npc_packet["inventory_save_data"] = inventory_snapshot

	# ------------------------------------------------------
	# Optional world/event snapshots.
	# ------------------------------------------------------
	var stars_snapshot := build_stars_save_data()
	if not stars_snapshot.is_empty():
		npc_packet["stars_save_data"] = stars_snapshot

	var map_snapshot := build_map_save_data()
	if not map_snapshot.is_empty():
		npc_packet["map_save_data"] = map_snapshot

	var space_objects_snapshot := build_space_objects_save_data()
	if not space_objects_snapshot.is_empty():
		npc_packet["space_objects_save_data"] = space_objects_snapshot

	var player_state_snapshot := build_player_state_save_data()
	if not player_state_snapshot.is_empty():
		npc_packet["player_state_save_data"] = player_state_snapshot

	Globals.current_npc = npc_packet
	Globals.swap_NPC_tran = true

	if Globals.print_priority_1:
		print("[NPC_SCENE_BRIDGE request_success] keys=", npc_packet.keys())

	return true


# ==========================================================
# SNAPSHOT HELPERS
# ==========================================================

func build_inventory_save_data() -> Dictionary:
	# Summary: Copies current inventory data into plain save data before scene swap.
	if inventory == null:
		if Globals.print_priority_2:
			print("[NPC_SCENE_BRIDGE inventory_snapshot_skipped] reason=no_inventory")
		return {}

	if not inventory.has_method("get_save_data"):
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE inventory_snapshot_failed] reason=missing_get_save_data")
		return {}

	var data = inventory.get_save_data()

	if typeof(data) != TYPE_DICTIONARY:
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE inventory_snapshot_failed] reason=not_dictionary type=", typeof(data))
		return {}

	return data.duplicate(true)


func build_stars_save_data() -> Array:
	# Summary: Copies current star data into plain save data before scene swap.
	if star_field == null:
		if Globals.print_priority_2:
			print("[NPC_SCENE_BRIDGE stars_snapshot_skipped] reason=no_star_field")
		return []

	if not star_field.has_method("to_save_data"):
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE stars_snapshot_failed] reason=missing_to_save_data")
		return []

	var data = star_field.to_save_data()

	if typeof(data) != TYPE_ARRAY:
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE stars_snapshot_failed] reason=not_array type=", typeof(data))
		return []

	return data.duplicate(true)


func build_map_save_data() -> Dictionary:
	# Summary: Copies current map data into plain save data before scene swap.
	if map_ref == null:
		if Globals.print_priority_2:
			print("[NPC_SCENE_BRIDGE map_snapshot_skipped] reason=no_map")
		return {}

	if not map_ref.has_method("to_save_data"):
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE map_snapshot_failed] reason=missing_to_save_data")
		return {}

	var data = map_ref.to_save_data()

	if typeof(data) != TYPE_DICTIONARY:
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE map_snapshot_failed] reason=not_dictionary type=", typeof(data))
		return {}

	return data.duplicate(true)


func build_space_objects_save_data() -> Dictionary:
	# Summary: Copies current space-object data into plain save data before scene swap.
	if space_objects == null:
		if Globals.print_priority_2:
			print("[NPC_SCENE_BRIDGE space_objects_snapshot_skipped] reason=no_space_objects")
		return {}

	if not space_objects.has_method("get_save_data"):
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE space_objects_snapshot_failed] reason=missing_get_save_data")
		return {}

	var data = space_objects.get_save_data()

	if typeof(data) != TYPE_DICTIONARY:
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE space_objects_snapshot_failed] reason=not_dictionary type=", typeof(data))
		return {}

	return data.duplicate(true)


func build_player_state_save_data() -> Dictionary:
	# Summary: Copies current PlayerState data into plain save data before NPC scene swap.
	if player_state == null:
		if Globals.print_priority_2:
			print("[NPC_SCENE_BRIDGE player_state_snapshot_skipped] reason=no_player_state")
		return {}

	if not player_state.has_method("get_save_data"):
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE player_state_snapshot_failed] reason=missing_get_save_data")
		return {}

	var data = player_state.get_save_data()

	if typeof(data) != TYPE_DICTIONARY:
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE player_state_snapshot_failed] reason=not_dictionary type=", typeof(data))
		return {}

	return data.duplicate(true)


func apply_player_state_result(result: Dictionary) -> bool:
	# Summary: Apply NPC-trade PlayerState result data back to main-owned PlayerState.
	if player_state == null:
		return false

	var data = result.get("player_state_save_data", result.get("player_state", {}))
	if typeof(data) != TYPE_DICTIONARY or data.is_empty():
		return false

	if not player_state.has_method("load_save_data"):
		return false

	#var ok := bool(player_state.load_save_data(data))
	player_state.load_save_data(data)
	#if Globals.print_priority_1:
		#print("[NPC_SCENE_BRIDGE player_state_result_applied] ok=", ok, " hull=", data.get("hull_current", "NO_HULL"))
	return true
	
	
func apply_pending_npc_chat_result_if_needed() -> bool:
	# Summary: Applies NPC_tran result data back to main-owned NPCHandler,
	# then saves the full universe so NPC trade/reward state persists.

	if Globals.npc_chat_result.is_empty():
		return false

	var result := Globals.npc_chat_result.duplicate(true)

	if Globals.print_priority_1:
		print("[NPC_SCENE_BRIDGE apply_result_entered] result=", result)

	if npc_handler == null:
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE apply_result_failed] reason=no_npc_handler")
		return false

	if not npc_handler.has_method("apply_npc_chat_result"):
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE apply_result_failed] reason=npc_handler_missing_apply_method")
		return false

	var applied := bool(npc_handler.apply_npc_chat_result(result))

	if not applied:
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE apply_result_warning] reason=no_matching_npc_but_continuing_for_player_state result=", result)
	else:
		if npc_handler.has_method("depopulate_finished_contacts"):
			npc_handler.depopulate_finished_contacts()

	apply_event_result_to_game_event_handler(result)

	var player_state_applied := apply_player_state_result(result)

	if Globals.print_priority_1:
		print("[NPC_SCENE_BRIDGE player_state_apply_after_npc] applied=", player_state_applied)

		if player_state != null and player_state.has_method("get_save_data"):
			var live_player_state_data = player_state.get_save_data()
			print("[NPC_SCENE_BRIDGE live_player_state_after_apply] hull=", live_player_state_data.get("hull_current"), "/", live_player_state_data.get("hull_max"))
		else:
			print("[NPC_SCENE_BRIDGE live_player_state_after_apply] missing_player_state_ref")

	if save_manager == null:
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE apply_result_warning] reason=no_save_manager applied_but_not_saved")
		Globals.npc_chat_result.clear()
		return true

	if not save_manager.has_method("save_universe_with_inventory_data"):
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE apply_result_warning] reason=save_manager_missing_save_universe_with_inventory_data")
		Globals.npc_chat_result.clear()
		return true

	if inventory == null or star_field == null or map_ref == null or space_objects == null or enemy_handler == null:
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE apply_result_warning] reason=missing_world_refs_for_full_save")
		Globals.npc_chat_result.clear()
		return true

	var inventory_data := {}

	if inventory.has_method("get_save_data"):
		inventory_data = inventory.get_save_data()

	var player_state_result_data := {}
	var raw_player_state_result = result.get("player_state_save_data", result.get("player_state", {}))
	if typeof(raw_player_state_result) == TYPE_DICTIONARY:
		player_state_result_data = raw_player_state_result.duplicate(true)
	if Globals.print_priority_1:
		print("[NPC_SCENE_BRIDGE player_state_result_data_for_save] empty=", player_state_result_data.is_empty(), " data=", player_state_result_data)
	var saved := bool(save_manager.save_universe_with_inventory_data(
		star_field,
		map_ref,
		space_objects,
		inventory_data,
		enemy_handler,
		npc_handler,
		beacons,
		[],
		[],
		[],
		game_event_handler,
		null,
		[],
		player_state,
		player_state_result_data
	))

	if Globals.print_priority_1:
		print("[NPC_SCENE_BRIDGE apply_result_saved] applied=", applied, " saved=", saved, " result=", result)

	Globals.npc_chat_result.clear()
	return saved


func apply_player_state_result_to_live_player_state(result: Dictionary) -> bool:
	# Summary: Apply NPC scene PlayerState result back to live main-mode PlayerState before full save.
	if typeof(result) != TYPE_DICTIONARY:
		return false

	var data = result.get("player_state_save_data", {})
	if typeof(data) != TYPE_DICTIONARY or data.is_empty():
		return false

	if player_state == null:
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE player_state_result_failed] reason=no_player_state")
		return false

	if not player_state.has_method("load_save_data"):
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE player_state_result_failed] reason=missing_load_save_data")
		return false

	player_state.load_save_data(data)
	if Globals.print_priority_1:
		print("[NPC_SCENE_BRIDGE player_state_result_applied] hull=", data.get("hull_current", "?"), "/", data.get("hull_max", "?"))
	return true


func apply_event_result_to_game_event_handler(result: Dictionary) -> bool:
	if not bool(result.get("event_start_requested", false)):
		return false

	if game_event_handler == null:
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE event_result_failed] reason=no_game_event_handler result=", result)
		return false

	if not game_event_handler.has_method("start_event_from_npc_result"):
		if Globals.print_priority_1:
			print("[NPC_SCENE_BRIDGE event_result_failed] reason=missing_start_event_from_npc_result")
		return false

	return bool(game_event_handler.start_event_from_npc_result(result))

func find_tracked_npc_for_chat_packet(npc_data: Dictionary) -> NPC:
	# Summary: Find the real tracked NPC from a raw scan/contact packet.

	if npc_handler == null:
		return null

	var wanted_npc_id := str(npc_data.get("npc_id", ""))
	var wanted_blueprint_id := str(npc_data.get("blueprint_id", ""))
	var wanted_name := str(npc_data.get("name", ""))
	var wanted_sector := SharedObjectMeta.read_sector_pos(npc_data.get("sector", Vector3i.ZERO))
	var wanted_local := SharedObjectMeta.read_local_pos(npc_data.get("local", Vector3.ZERO))
	var has_position := npc_data.has("sector") and npc_data.has("local")
	var blueprint_match: NPC = null
	var blueprint_match_count := 0

	for npc in npc_handler.npcs:
		if npc == null:
			continue

		var current_npc_id := str(npc.get_meta("npc_id", ""))
		var current_blueprint_id := str(npc.get_meta("blueprint_id", ""))

		if wanted_npc_id != "" and current_npc_id == wanted_npc_id:
			return npc

		if has_position and npc.sector_pos == wanted_sector and npc.local_pos.distance_to(wanted_local) <= 1.0:
			return npc

		if wanted_name != "" and npc.npc_name == wanted_name:
			return npc

		if wanted_blueprint_id != "" and current_blueprint_id == wanted_blueprint_id:
			blueprint_match = npc
			blueprint_match_count += 1

	if blueprint_match_count == 1:
		return blueprint_match

	return null
