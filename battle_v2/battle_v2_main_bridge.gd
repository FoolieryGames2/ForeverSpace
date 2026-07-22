extends RefCounted
class_name BattleV2MainBridge


# ==========================================================
# BATTLE V2 MAIN BRIDGE
# ----------------------------------------------------------
# Owns Battle V2 handoff/context/result behavior.
#
# Does NOT change scenes directly.
# main_mode.gd still owns add_scene_tree_swap_check().
# ==========================================================
var npc_save_data := get_battle_npc_save_data_from_context()
var beacon_save_data := get_battle_beacon_save_data_from_context()
var space_object_save_data := get_battle_space_object_save_data_from_context()

var action_manager = null
var inventory = null
var item_handler = null
var energy_handler = null
var player_state: PlayerState = null

var enemy_handler = null
var save_manager = null
var enemy_intel_handler = null

var star_field = null
var map_ref = null
var space_objects = null
var npc_handler: NPCHandler = null
var beacons: Beacons = null
var map: Map = null
var game_event_handler = null



func setup(refs: Dictionary) -> void:
	# Summary: Receives main-owned system references without making this bridge own their lifecycle.
	action_manager = refs.get("action_manager", null)
	inventory = refs.get("inventory", null)
	item_handler = refs.get("item_handler", null)
	energy_handler = refs.get("energy_handler", null)
	player_state = refs.get("player_state", null)
	print("player | battle bridge | setup | player state is " + "\n" + "player_state:"+str(player_state))

	enemy_handler = refs.get("enemy_handler", null)
	save_manager = refs.get("save_manager", null)
	enemy_intel_handler = refs.get("enemy_intel_handler", null)
	if enemy_intel_handler == null and save_manager != null and save_manager.has_method("get_enemy_intel_handler"):
		enemy_intel_handler = save_manager.get_enemy_intel_handler()

	star_field = refs.get("star_field", null)
	map_ref = refs.get("map", null)
	space_objects = refs.get("space_objects", null)
	npc_handler = refs.get("npc_handler", null)
	beacons = refs.get("beacons", null)
	game_event_handler = refs.get("game_event_handler", null)
	


# ==========================================================
# BUILD BATTLE V2 CONTEXT
# ==========================================================

func build_context(entry_reason: String, enemy_ref, authored_event_context: Dictionary = {}) -> Dictionary:
	# Summary: Build the Battle V2 handoff packet using plain data that survives scene swap.
	if Globals.print_priority_7:
		print("!!! ACTIVE BattleV2MainBridge.build_context CALLED !!! entry_reason=", entry_reason)

	var loadout_data := build_saved_battle_loadout_data()
	var inventory_save_data := build_inventory_save_data()
	var item_db_snapshot := build_item_db_snapshot()
	var npc_save_data := build_npc_save_data()
	var beacon_save_data := build_beacon_save_data()
	var space_object_save_data := build_space_object_save_data()
	var player_state_save_data := build_player_state_save_data()
	var safe_authored_context := build_authored_event_context(entry_reason, enemy_ref, authored_event_context)

	var context := {
		"context_schema": "battle_v2_snapshot_context_v1",
		"entry_reason": entry_reason,
		"enemy": enemy_ref,
		"authored_event_context": safe_authored_context,
		"loadout_data": loadout_data,

		# Safe plain data.
		"inventory_save_data": inventory_save_data,
		"item_db_snapshot": item_db_snapshot,
		"npc_save_data": npc_save_data,
		"beacon_save_data": beacon_save_data,
		"space_object_save_data": space_object_save_data,
		"player_state_save_data": player_state_save_data,
		

		# Temporary refs only. These can be freed after scene swap.
		"inventory": inventory,
		"energy_handler": energy_handler,
		"player_state": player_state,
		"action_manager": action_manager,
		
		

		# Temporary refs only. These can be freed after scene swap.
		
	
		}
		

	if Globals.print_priority_7:
		print("[BATTLE_V2_BRIDGE context_RETURN_KEYS] ", context.keys())
		print("[BATTLE_V2_BRIDGE context_inventory_save_keys] ", inventory_save_data.keys())
		print("[BATTLE_V2_BRIDGE context_item_db_count] ", item_db_snapshot.size())
		print("[BATTLE_V2_BRIDGE context_player_state_keys] ", player_state_save_data.keys())

	return context


func get_empty_battle_loadout_data() -> Dictionary:
	return {
		"selected_primary_weapon": "",
		"selected_secondary_weapon": "",
		"selected_shield": "",
		"loaded_consumable": "",
		"loaded_consumable_state": "none",
		"equipped_upgrades": [],
		"shield_power_level": 0,
		"default_shield_power_level": 2
	}


func build_saved_battle_loadout_data() -> Dictionary:
	# Summary: Prefer the saved PlayerState loadout, then fall back to the legacy inventory guess for old saves.
	var loadout_data := get_empty_battle_loadout_data()
	var saved_data := {}

	if player_state != null:
		if player_state.has_method("get_battle_loadout_save_data"):
			saved_data = player_state.get_battle_loadout_save_data()
		elif player_state.has_method("get_save_data"):
			var player_save_data = player_state.get_save_data()
			if typeof(player_save_data) == TYPE_DICTIONARY:
				saved_data = player_save_data.get("battle_loadout", player_save_data)

	if typeof(saved_data) == TYPE_DICTIONARY and not saved_data.is_empty():
		loadout_data = normalize_battle_loadout_packet(saved_data, loadout_data)

	if is_battle_loadout_empty(loadout_data) and action_manager != null and action_manager.has_method("build_battle_v2_loadout_data"):
		var fallback_data = action_manager.build_battle_v2_loadout_data()
		if typeof(fallback_data) == TYPE_DICTIONARY:
			loadout_data = normalize_battle_loadout_packet(fallback_data, loadout_data)
			if Globals.print_priority_7:
				print("[battle_v2_bridge_loadout_fallback] using ActionManager inventory-derived loadout.")

	loadout_data["labels"] = [
		"player_loadout_bridge",
		"player_state_saved_loadout",
		"player_inventory_bridge"
	]
	return loadout_data


func normalize_battle_loadout_packet(data: Dictionary, defaults: Dictionary = {}) -> Dictionary:
	var normalized := get_empty_battle_loadout_data()

	if typeof(defaults) == TYPE_DICTIONARY:
		for key in normalized.keys():
			if defaults.has(key):
				normalized[key] = defaults[key]

	if typeof(data) != TYPE_DICTIONARY:
		return normalized

	for key in [
		"selected_primary_weapon",
		"selected_secondary_weapon",
		"selected_shield",
		"loaded_consumable"
	]:
		if data.has(key):
			normalized[key] = get_loadout_item_id(data.get(key, ""))

	normalized["equipped_upgrades"] = sanitize_equipped_upgrade_ids(data.get("equipped_upgrades", normalized.get("equipped_upgrades", [])))

	if data.has("loaded_consumable_state"):
		normalized["loaded_consumable_state"] = str(data.get("loaded_consumable_state", "none")).strip_edges().to_lower()

	if str(normalized.get("loaded_consumable", "")).strip_edges() == "":
		normalized["loaded_consumable_state"] = "none"
	elif str(normalized.get("loaded_consumable_state", "")).strip_edges() == "" or str(normalized.get("loaded_consumable_state", "")).strip_edges() == "none":
		normalized["loaded_consumable_state"] = "ready"

	if data.has("shield_power_level"):
		normalized["shield_power_level"] = int(clamp(int(data.get("shield_power_level", 0)), 0, 4))
	if data.has("default_shield_power_level"):
		normalized["default_shield_power_level"] = int(clamp(int(data.get("default_shield_power_level", 2)), 0, 4))

	return normalized


func sanitize_equipped_upgrade_ids(value) -> Array:
	var clean: Array = []
	if typeof(value) != TYPE_ARRAY:
		return clean

	for raw_id in value:
		var upgrade_id := get_loadout_item_id(raw_id)
		if upgrade_id == "":
			continue
		if clean.has(upgrade_id):
			continue
		if not is_valid_owned_upgrade_id(upgrade_id):
			continue
		clean.append(upgrade_id)
		if clean.size() >= 3:
			break

	return clean


func is_valid_owned_upgrade_id(item_id: String) -> bool:
	var clean_id := item_id.strip_edges()
	if clean_id == "":
		return false

	if inventory != null and inventory.has_method("has_item_anywhere"):
		if not inventory.has_item_anywhere(clean_id):
			return false

	if item_handler == null:
		return true

	if item_handler.has_method("has_item") and not item_handler.has_item(clean_id):
		return false

	var item_data := {}
	if item_handler.has_method("get_item_data"):
		var data = item_handler.get_item_data(clean_id)
		if typeof(data) == TYPE_DICTIONARY:
			item_data = data
	else:
		var item_db = item_handler.get("item_db")
		if typeof(item_db) == TYPE_DICTIONARY:
			var db_data = item_db.get(clean_id, {})
			if typeof(db_data) == TYPE_DICTIONARY:
				item_data = db_data

	if item_data.is_empty():
		return true

	return str(item_data.get("item_type", item_data.get("type", ""))).strip_edges().to_lower() == "upgrade"


func get_loadout_item_id(value: Variant) -> String:
	if value == null:
		return ""

	if typeof(value) == TYPE_DICTIONARY:
		var packet: Dictionary = value as Dictionary
		return str(packet.get("item_id", packet.get("id", ""))).strip_edges()

	var text := str(value).strip_edges()
	if text == "" or text == "<null>" or text.to_lower() == "null":
		return ""

	return text


func is_battle_loadout_empty(data: Dictionary) -> bool:
	for key in [
		"selected_primary_weapon",
		"selected_secondary_weapon",
		"selected_shield",
		"loaded_consumable",
		"equipped_upgrades"
	]:
		if key == "equipped_upgrades":
			var upgrades = data.get(key, [])
			if typeof(upgrades) == TYPE_ARRAY and not upgrades.is_empty():
				return false
		elif str(data.get(key, "")).strip_edges() != "":
			return false
	return true


func build_authored_event_context(entry_reason: String, enemy_ref, authored_event_context: Dictionary = {}) -> Dictionary:
	# Summary: Carry authored JSON identity across the scene swap independent of enemy object wrappers.
	var context := authored_event_context.duplicate(true)
	var enemy_meta := read_enemy_shared_meta(enemy_ref)

	for key in [
		"event_id",
		"active_event_id",
		"event_step",
		"current_step",
		"required_step",
		"object_id",
		"target_object_id",
		"enemy_id",
		"enemy_serial",
		"enemy_template_id",
		"display_name"
	]:
		if not enemy_meta.has(key):
			continue
		if str(context.get(key, "")).strip_edges() == "":
			context[key] = enemy_meta[key]

	context["entry_reason"] = str(context.get("entry_reason", entry_reason))
	if str(context.get("enemy_id", "")).strip_edges() == "":
		context["enemy_id"] = str(context.get("object_id", context.get("target_object_id", "")))
	if str(context.get("target_object_id", "")).strip_edges() == "":
		context["target_object_id"] = str(context.get("enemy_id", context.get("object_id", "")))
	if str(context.get("active_event_id", "")).strip_edges() == "":
		context["active_event_id"] = str(context.get("event_id", ""))
	if str(context.get("required_step", "")).strip_edges() == "":
		context["required_step"] = str(context.get("event_step", context.get("current_step", "")))
	if str(context.get("event_step", "")).strip_edges() == "":
		context["event_step"] = str(context.get("current_step", context.get("required_step", "")))
	if str(context.get("current_step", "")).strip_edges() == "":
		context["current_step"] = str(context.get("event_step", context.get("required_step", "")))

	return context


func register_battle_entry_enemy_intel(entry_reason: String, enemy_ref, authored_event_context: Dictionary = {}) -> void:
	if enemy_ref == null:
		return

	var source := authored_event_context.duplicate(true)
	source["source"] = "BattleV2MainBridge.request_battle_v2_entry"
	source["entry_reason"] = entry_reason

	if enemy_handler != null and enemy_handler.has_method("register_enemy_intel"):
		enemy_handler.register_enemy_intel(enemy_ref, source)
		return

	if enemy_intel_handler != null and enemy_intel_handler.has_method("register_enemy_spawned"):
		enemy_intel_handler.register_enemy_spawned(enemy_ref, source)


func read_enemy_shared_meta(enemy_ref) -> Dictionary:
	if enemy_ref == null:
		return {}

	if enemy_ref is Dictionary:
		var dict_ref: Dictionary = enemy_ref
		var out := dict_ref.duplicate(true)
		if typeof(dict_ref.get("shared_meta", {})) == TYPE_DICTIONARY:
			var shared_meta: Dictionary = dict_ref.get("shared_meta", {})
			for key in shared_meta.keys():
				if str(out.get(key, "")).strip_edges() == "":
					out[key] = shared_meta[key]
		return out

	if enemy_ref is Object:
		if enemy_ref.has_method("get_shared_meta_save_data"):
			var save_meta = enemy_ref.get_shared_meta_save_data()
			if typeof(save_meta) == TYPE_DICTIONARY and not save_meta.is_empty():
				return save_meta.duplicate(true)
		if enemy_ref.has_method("sync_shared_meta"):
			var synced_meta = enemy_ref.sync_shared_meta()
			if typeof(synced_meta) == TYPE_DICTIONARY and not synced_meta.is_empty():
				return synced_meta.duplicate(true)

	return {}


# ==========================================================
# REQUEST BATTLE ENTRY
# ==========================================================

func request_battle_v2_entry(entry_reason: String, enemy_ref, authored_event_context: Dictionary = {}) -> bool:
	# Summary: Prepares Battle V2 context and raises global scene-swap request.
	# Important: This does NOT call change_scene_to_file().
	if not Globals.Let_battle_v2:
		if Globals.print_priority_7:
			print("[battle_v2_bridge_entry_blocked] reason=Let_battle_v2_false")
		return false

	if Globals.battle_mode or Globals.battle_pending:
		if Globals.print_priority_7:
			print("[battle_v2_bridge_entry_blocked] reason=battle_mode_or_pending")
		return false

	if enemy_ref == null:
		if Globals.print_priority_7:
			print("[battle_v2_bridge_entry_blocked] reason=no_enemy_ref")
		return false

	register_battle_entry_enemy_intel(entry_reason, enemy_ref, authored_event_context)

	# Build context before raising pending/swap flags.
	Globals.current_enemy = enemy_ref
	Globals.battle_v2_context = build_context(entry_reason, enemy_ref, authored_event_context)

	if Globals.print_priority_7:
		print("[BATTLE_V2_BRIDGE battle_context_set_FINAL_KEYS] ", Globals.battle_v2_context.keys())
		print("[BATTLE_V2_BRIDGE battle_context_schema] ", Globals.battle_v2_context.get("context_schema", "NO_SCHEMA"))

	Globals.battle_pending = true
	Globals.swap_battle_v2 = true

	return true


# ==========================================================
# DEBUG E REAL ENEMY PATH
# ==========================================================

func debug_force_real_enemy_encounter() -> void:
	# Summary: Route the closest real enemy in the player's sector into Battle V2.
	if Globals.print_priority_7:
		print("BattleV2MainBridge debug real-enemy encounter requested.")

	if Globals.battle_mode or Globals.battle_pending:
		if Globals.print_priority_7:
			print("[debug_battle_v2_real_enemy_failed] reason=battle_already_active_or_pending")
		return

	if not Globals.Let_battle_v2:
		if Globals.print_priority_7:
			print("[debug_battle_v2_real_enemy_failed] reason=Let_battle_v2_false")
		return

	if map_ref == null:
		if Globals.print_priority_7:
			print("[debug_battle_v2_real_enemy_failed] reason=no_map")
		return

	if enemy_handler == null:
		if Globals.print_priority_7:
			print("[debug_battle_v2_real_enemy_failed] reason=no_enemy_handler")
		return

	if not enemy_handler.has_method("get_enemies_in_sector"):
		if Globals.print_priority_7:
			print("[debug_battle_v2_real_enemy_failed] reason=enemy_handler_missing_get_enemies_in_sector")
		return

	var enemies := get_debug_battle_v2_candidate_enemies()

	if enemies.is_empty():
		if Globals.print_priority_7:
			print("[debug_battle_v2_real_enemy_failed] reason=no_debug_candidate_enemies sector=", map_ref.sector_pos)
		return

	var closest_enemy = null
	var closest_enemy_dist := INF

	for e in enemies:
		if e == null:
			continue

		var dist := get_debug_battle_v2_enemy_distance(e)

		if Globals.print_priority_7:
			print("[debug_battle_v2_enemy_candidate] enemy=", get_debug_battle_v2_enemy_name(e), " dist=", dist)

		if dist < closest_enemy_dist:
			closest_enemy_dist = dist
			closest_enemy = e

	if closest_enemy == null:
		if Globals.print_priority_7:
			print("[debug_battle_v2_real_enemy_failed] reason=no_valid_closest_enemy")
		return

	if request_battle_v2_entry("debug_key_e_real_enemy_encounter", closest_enemy):
		if Globals.print_priority_7:
			print("[DEBUG_E_REAL battle_context_enemy] ", get_debug_battle_v2_enemy_name(closest_enemy))
			print("[DEBUG_E_REAL battle_context_enemy_dist] ", closest_enemy_dist)


func get_debug_battle_v2_candidate_enemies() -> Array:
	# Summary: Prefer the current-sector enemy query, but fall back to the raw
	# enemy list so dev-spawned test enemies can still be engaged by the B key.
	var candidates: Array = []

	if enemy_handler == null:
		return candidates

	if enemy_handler.has_method("get_enemies_in_sector") and map_ref != null:
		var sector_enemies = enemy_handler.get_enemies_in_sector(map_ref.sector_pos)
		if typeof(sector_enemies) == TYPE_ARRAY:
			candidates = sector_enemies.duplicate()

	if not candidates.is_empty():
		return candidates

	var raw_enemies = enemy_handler.get("enemies")
	if typeof(raw_enemies) != TYPE_ARRAY:
		return candidates

	for e in raw_enemies:
		if e == null:
			continue
		if bool(get_debug_battle_v2_enemy_value(e, "is_completed", false)):
			continue
		candidates.append(e)

	if Globals.print_priority_7:
		print("[debug_battle_v2_candidate_fallback] using raw enemy list count=", candidates.size())

	return candidates


func get_debug_battle_v2_enemy_distance(enemy_ref) -> float:
	# Summary: Distance helper for the dev engage key. Same-sector enemies use
	# normal map distance; cross-sector fallback receives a large sector penalty.
	if map_ref == null or enemy_ref == null:
		return INF

	var enemy_sector = get_debug_battle_v2_enemy_value(enemy_ref, "sector_pos", Vector3i.ZERO)
	var enemy_local = get_debug_battle_v2_enemy_value(enemy_ref, "local_pos", Vector3.ZERO)

	if sectors_match_for_debug_battle(enemy_sector, map_ref.sector_pos):
		if map_ref.has_method("get_distance_to_target"):
			return float(map_ref.get_distance_to_target(enemy_sector, enemy_local))

	var sector_distance := vector3_like_distance(enemy_sector, map_ref.sector_pos)
	var local_distance := vector3_like_distance(enemy_local, get_debug_battle_v2_map_local_pos())
	return (sector_distance * 100000.0) + local_distance


func get_debug_battle_v2_map_local_pos():
	if map_ref == null:
		return Vector3.ZERO
	var value = map_ref.get("local_pos")
	if value is Vector3 or value is Vector3i:
		return value
	value = map_ref.get("position")
	if value is Vector3 or value is Vector3i:
		return value
	return Vector3.ZERO


func get_debug_battle_v2_enemy_value(enemy_ref, key: String, fallback):
	if enemy_ref == null:
		return fallback
	if enemy_ref is Dictionary:
		return enemy_ref.get(key, fallback)
	if enemy_ref is Object:
		var value = enemy_ref.get(key)
		if value != null:
			return value
	return fallback


func get_debug_battle_v2_enemy_name(enemy_ref) -> String:
	var name_text := str(get_debug_battle_v2_enemy_value(enemy_ref, "enemy_name", "")).strip_edges()
	if name_text == "":
		name_text = str(get_debug_battle_v2_enemy_value(enemy_ref, "display_name", "")).strip_edges()
	if name_text == "":
		name_text = str(get_debug_battle_v2_enemy_value(enemy_ref, "name", "Enemy")).strip_edges()
	return name_text


func sectors_match_for_debug_battle(a, b) -> bool:
	return int(get_vector3_like_axis(a, "x")) == int(get_vector3_like_axis(b, "x")) \
		and int(get_vector3_like_axis(a, "y")) == int(get_vector3_like_axis(b, "y")) \
		and int(get_vector3_like_axis(a, "z")) == int(get_vector3_like_axis(b, "z"))


func vector3_like_distance(a, b) -> float:
	var dx := float(get_vector3_like_axis(a, "x") - get_vector3_like_axis(b, "x"))
	var dy := float(get_vector3_like_axis(a, "y") - get_vector3_like_axis(b, "y"))
	var dz := float(get_vector3_like_axis(a, "z") - get_vector3_like_axis(b, "z"))
	return sqrt((dx * dx) + (dy * dy) + (dz * dz))


func get_vector3_like_axis(value, axis: String) -> float:
	if value is Vector3 or value is Vector3i:
		if axis == "x":
			return float(value.x)
		if axis == "y":
			return float(value.y)
		return float(value.z)

	if value is Array:
		var index := 0
		if axis == "y":
			index = 1
		elif axis == "z":
			index = 2
		if value.size() > index:
			return float(value[index])

	return 0.0


# ==========================================================
# APPLY BATTLE V2 RESULT
# ==========================================================

func apply_result_if_needed() -> void:
	
	# Summary: Apply Battle V2 result after main mode has been rebuilt.
	if Globals.battle_v2_result.is_empty():
		return

	if not bool(Globals.battle_v2_result.get("pending", false)):
		return

	var result_inventory_save_data := get_pending_result_inventory_save_data()
	var result_npc_save_data := get_pending_result_npc_save_data()
	var result_beacon_save_data := get_pending_result_beacon_save_data()
	var result_space_object_save_data := get_pending_result_space_object_save_data()
	var result_player_state_save_data := get_pending_result_player_state_save_data()

	var inventory_result_applied := apply_inventory_result_if_present(result_inventory_save_data)
	var npc_result_applied := apply_npc_result_if_present(result_npc_save_data)
	var beacon_result_applied := apply_beacon_result_if_present(result_beacon_save_data)
	var space_object_result_applied := apply_space_object_result_if_present(result_space_object_save_data)
	var player_state_result_applied := apply_player_state_result_if_present(result_player_state_save_data)

	# Keep your defeated-enemy cleanup here if already present.
	# Example:
	# apply_defeated_enemy_cleanup_if_present()
	var defeated_enemy_signature = Globals.battle_v2_result.get("defeated_enemy_signature", {})
	if typeof(defeated_enemy_signature) != TYPE_DICTIONARY:
		defeated_enemy_signature = {}
	var removed_enemy := false
	var player_sector := get_current_player_sector_array()
	var defeated_enemy_serial := get_defeated_enemy_serial_from_result(Globals.battle_v2_result)

	if defeated_enemy_serial != "" and enemy_handler != null and enemy_handler.has_method("remove_enemy_by_serial"):
		removed_enemy = bool(enemy_handler.remove_enemy_by_serial(defeated_enemy_serial))
		if Globals.print_priority_7:
			print("[BattleV2MainBridge.apply_result_if_needed] serial removal serial=", defeated_enemy_serial, " removed=", removed_enemy)

	# ------------------------------------------------------
	# Path 0: battle-safe signature.
	# ------------------------------------------------------
	if not removed_enemy and not defeated_enemy_signature.is_empty():
		if Globals.print_priority_7:
			print(
				"[BattleV2MainBridge.apply_result_if_needed] Trying signature removal",
				" | signature=", defeated_enemy_signature
			)

		removed_enemy = remove_enemy_by_battle_signature(defeated_enemy_signature)
	record_enemy_intel_defeat_from_result(Globals.battle_v2_result)
	save_universe_after_result(
		result_inventory_save_data,
		result_npc_save_data,
		result_beacon_save_data,
		result_space_object_save_data,
		result_player_state_save_data
	)
	if Globals.print_priority_7:
		print(
			"[BattleV2MainBridge.apply_result_if_needed]",
			" | inventory_applied=", inventory_result_applied,
			" | npc_applied=", npc_result_applied,
			" | beacon_applied=", beacon_result_applied,
			" | space_object_applied=", space_object_result_applied,
			" | player_state_applied=", player_state_result_applied
		)

	Globals.last_battle_v2_result = Globals.battle_v2_result.duplicate(true)
	Globals.battle_v2_result.clear()


func save_universe_after_result(
	inventory_save_data: Dictionary = {},
	npc_save_data: Array = [],
	beacon_save_data: Array = [],
	space_object_save_data: Array = [],
	player_state_save_data: Dictionary = {}
) -> void:
	# Summary: Saves the universe after Battle V2 result application using safe snapshot sections.
	if save_manager == null:
		if Globals.print_priority_7:
			print("Battle V2 save skipped: save_manager is null.")
		return

	if not save_manager.has_method("save_universe_with_inventory_data"):
		if Globals.print_priority_7:
			print("Battle V2 save skipped: SaveManager missing save_universe_with_inventory_data.")
		return

	var safe_inventory_data := inventory_save_data

	if safe_inventory_data.is_empty() and inventory != null and inventory.has_method("get_save_data"):
		safe_inventory_data = inventory.get_save_data()

	var saved_ok := bool(save_manager.save_universe_with_inventory_data(
		star_field,
		map_ref,
		space_objects,
		safe_inventory_data,
		enemy_handler,
		npc_handler,
		beacons,
		npc_save_data,
		beacon_save_data,
		space_object_save_data,
		game_event_handler,
		null,
		[],
		player_state,
		player_state_save_data
	))

	if Globals.print_priority_7:
		print(
			"Battle V2 post-result save completed: ",
			saved_ok,
			" | npc_snapshot_count=",
			npc_save_data.size(),
			" | beacon_snapshot_count=",
			beacon_save_data.size(),
			" | space_object_snapshot_count=",
			space_object_save_data.size(),
			" | player_state_snapshot_keys=",
			player_state_save_data.keys()
		)

	if Globals.print_priority_7:
		print("Battle V2 post-result save completed: ", saved_ok)


func get_pending_result_inventory_save_data() -> Dictionary:
	# Summary: Read updated inventory save-data from a Battle V2 result packet.
	if Globals.battle_v2_result.is_empty():
		return {}

	var data = Globals.battle_v2_result.get("inventory_save_data", {})
	if typeof(data) == TYPE_DICTIONARY:
		return data.duplicate(true)

	return {}


func get_pending_result_player_state_save_data() -> Dictionary:
	# Summary: Read updated PlayerState save-data from a Battle V2 result packet.
	if Globals.battle_v2_result.is_empty():
		return {}

	var data = Globals.battle_v2_result.get("player_state_save_data", {})
	if typeof(data) == TYPE_DICTIONARY:
		return data.duplicate(true)

	# Backward-compatible aliases while Battle V2 result packet names settle.
	data = Globals.battle_v2_result.get("player_state", {})
	if typeof(data) == TYPE_DICTIONARY:
		return data.duplicate(true)

	return {}


func apply_player_state_result_if_present(player_state_save_data: Dictionary) -> bool:
	# Summary: Apply Battle V2 PlayerState snapshot back into the live main-mode PlayerState.
	if player_state_save_data.is_empty():
		return false

	if player_state == null:
		if Globals.print_priority_7:
			print("[BattleV2MainBridge.apply_player_state_result] skipped reason=no_player_state_ref")
		return false

	if not player_state.has_method("load_save_data"):
		if Globals.print_priority_7:
			print("[BattleV2MainBridge.apply_player_state_result] skipped reason=missing_load_save_data")
		return false

	player_state.load_save_data(player_state_save_data)

	if Globals.print_priority_7:
		print("[BattleV2MainBridge.apply_player_state_result] keys=", player_state_save_data.keys())

	return true


func apply_inventory_result_if_present(inventory_save_data: Dictionary) -> bool:
	# Summary: Apply Battle V2 inventory snapshot changes before clearing the result packet.
	if inventory_save_data.is_empty():
		return false

	apply_inventory_save_data_to_live_inventory(inventory_save_data)

	if Globals.print_priority_7:
		print(
			"[BattleV2MainBridge.apply_inventory_result]",
			" | keys=", inventory_save_data.keys()
		)

	return true


func apply_inventory_save_data_to_live_inventory(inventory_save_data: Dictionary) -> void:
	# Summary: Refresh main-mode Inventory5 from the Battle V2 snapshot without relying on old scene refs.
	if inventory == null:
		return

	if inventory.get("cells") != null:
		apply_inventory_section_to_slots(
			inventory.cells.get("each_cell", {}),
			inventory_save_data.get("main", {})
		)

	if inventory.get("drone_cells") != null:
		apply_inventory_section_to_slots(
			inventory.drone_cells.get("each_cell", {}),
			inventory_save_data.get("drones", {})
		)

	if inventory.has_method("refresh_inventory_icons"):
		inventory.refresh_inventory_icons()

	if inventory.has_method("refresh_label_inventory_rows"):
		inventory.refresh_label_inventory_rows()


func apply_inventory_section_to_slots(target_slots: Dictionary, section_save_data) -> void:
	# Summary: Replace one Inventory5 slot section with save-data item/count values.
	var source_section := {}
	if typeof(section_save_data) == TYPE_DICTIONARY:
		source_section = section_save_data

	for slot_name in target_slots.keys():
		var target_slot = target_slots.get(slot_name, {})
		if typeof(target_slot) != TYPE_DICTIONARY:
			continue

		var saved_slot = source_section.get(slot_name, {})
		if typeof(saved_slot) == TYPE_DICTIONARY:
			target_slot["item_id"] = str(saved_slot.get("item_id", ""))
			target_slot["count"] = max(int(saved_slot.get("count", 0)), 0)
		else:
			target_slot["item_id"] = ""
			target_slot["count"] = 0

		target_slots[slot_name] = target_slot


# ==========================================================
# MATCH / CLEANUP HELPERS
# ==========================================================

func get_defeated_enemy_serial_from_result(result: Dictionary) -> String:
	for key in ["defeated_enemy_serial", "enemy_serial", "serial_number"]:
		var value := str(result.get(key, "")).strip_edges()
		if value != "":
			return value

	for packet_key in ["defeated_enemy_shared_meta", "defeated_enemy_signature", "authored_event_context"]:
		var packet = result.get(packet_key, {})
		if typeof(packet) != TYPE_DICTIONARY:
			continue
		for key in ["enemy_serial", "serial_number", "defeated_enemy_serial"]:
			var value := str(packet.get(key, "")).strip_edges()
			if value != "":
				return value
		var shared_meta = packet.get("shared_meta", {})
		if typeof(shared_meta) == TYPE_DICTIONARY:
			for key in ["enemy_serial", "serial_number"]:
				var shared_value := str(shared_meta.get(key, "")).strip_edges()
				if shared_value != "":
					return shared_value

	return ""


func record_enemy_intel_defeat_from_result(result: Dictionary) -> void:
	if enemy_intel_handler == null and save_manager != null and save_manager.has_method("get_enemy_intel_handler"):
		enemy_intel_handler = save_manager.get_enemy_intel_handler()
	if enemy_intel_handler == null or not enemy_intel_handler.has_method("record_enemy_defeated_from_battle_result"):
		return

	var record_result = enemy_intel_handler.record_enemy_defeated_from_battle_result(result)
	if Globals.print_priority_7:
		print("[BattleV2MainBridge.enemy_intel_defeat] ", record_result)


func remove_enemy_by_battle_signature(signature: Dictionary) -> bool:
	# Summary: Removes one defeated enemy by matching saved-world identity fields from Battle V2.
	if enemy_handler == null:
		return false

	var target_serial := str(signature.get("enemy_serial", "")).strip_edges()
	if target_serial == "" and typeof(signature.get("shared_meta", {})) == TYPE_DICTIONARY:
		target_serial = str(signature.get("shared_meta", {}).get("enemy_serial", "")).strip_edges()
	if target_serial != "" and enemy_handler.has_method("remove_enemy_by_serial"):
		if bool(enemy_handler.remove_enemy_by_serial(target_serial)):
			return true

	var target_name := str(signature.get("name", ""))
	var target_type := str(signature.get("type", ""))
	var target_sector: Array = signature.get("sector", [])
	var target_local: Array = signature.get("local", [])

	for enemy in enemy_handler.enemies:
		if enemy == null:
			continue

		var enemy_name := str(enemy.get("enemy_name"))
		if enemy_name == "":
			enemy_name = str(enemy.get("name"))

		var enemy_type := str(enemy.get("enemy_type"))
		if enemy_type == "":
			enemy_type = str(enemy.get("type"))

		var enemy_sector := vector3_to_array_safe(enemy.get("sector_pos"))
		var enemy_local := vector3_to_array_safe(enemy.get("local_pos"))

		if enemy_name != target_name:
			continue

		if target_type != "" and enemy_type != target_type:
			continue

		if not arrays_match_exact(enemy_sector, target_sector):
			continue

		if not arrays_match_close(enemy_local, target_local, 0.01):
			continue

		enemy_handler.remove_enemy(enemy)
		return true

	return false


func arrays_match_exact(a: Array, b: Array) -> bool:
	# Summary: Compares exact sector-style coordinate arrays.
	if a.size() != b.size():
		return false

	for i in range(a.size()):
		if int(a[i]) != int(b[i]):
			return false

	return true


func arrays_match_close(a: Array, b: Array, tolerance: float = 0.01) -> bool:
	# Summary: Compares local-position coordinate arrays with float tolerance.
	if a.size() != b.size():
		return false

	for i in range(a.size()):
		if abs(float(a[i]) - float(b[i])) > tolerance:
			return false

	return true


func vector3_to_array_safe(value) -> Array:
	# Summary: Converts Vector3/Vector3i or array-like values into a simple array for cleanup matching.
	if value is Vector3 or value is Vector3i:
		return [value.x, value.y, value.z]

	if value is Array:
		return value

	return []


func get_current_player_sector_array() -> Array:
	# Summary: Returns the current player/map sector as an array for post-battle cleanup matching.
	if map_ref == null:
		return []

	if map_ref.sector_pos is Vector3 or map_ref.sector_pos is Vector3i:
		return [
			int(map_ref.sector_pos.x),
			int(map_ref.sector_pos.y),
			int(map_ref.sector_pos.z)
		]

	if map_ref.sector_pos is Array:
		return [
			int(map_ref.sector_pos[0]),
			int(map_ref.sector_pos[1]),
			int(map_ref.sector_pos[2])
		]

	return []
	
	
func get_pending_result_npc_save_data() -> Array:
	# Summary: Read NPC save-data from a Battle V2 result packet.
	if Globals.battle_v2_result.is_empty():
		return []

	var data = Globals.battle_v2_result.get("npc_save_data", [])

	if typeof(data) == TYPE_ARRAY:
		return data.duplicate(true)

	return []


func get_pending_result_beacon_save_data() -> Array:
	# Summary: Read beacon save-data from a Battle V2 result packet.
	if Globals.battle_v2_result.is_empty():
		return []

	var data = Globals.battle_v2_result.get("beacon_save_data", [])

	if typeof(data) == TYPE_ARRAY:
		return data.duplicate(true)

	return []


func get_pending_result_space_object_save_data() -> Array:
	# Summary: Read space-object save-data from a Battle V2 result packet.
	if Globals.battle_v2_result.is_empty():
		return []

	var data = Globals.battle_v2_result.get("space_object_save_data", [])

	if typeof(data) == TYPE_ARRAY:
		return data.duplicate(true)

	return []


func get_enemy_by_name_in_sector(enemy_name: String, sector_array: Array):
	# Summary: Finds one enemy by name only inside the current player sector.
	if enemy_handler == null:
		return null

	if sector_array.size() < 3:
		return null

	for enemy in enemy_handler.enemies:
		if enemy == null:
			continue

		var this_name := str(enemy.get("enemy_name"))
		if this_name == "" or this_name == "<null>":
			this_name = str(enemy.get("name"))

		if this_name != enemy_name:
			continue

		var enemy_sector_value = enemy.get("sector_pos")
		var enemy_sector := []

		if enemy_sector_value is Vector3 or enemy_sector_value is Vector3i:
			enemy_sector = [
				int(enemy_sector_value.x),
				int(enemy_sector_value.y),
				int(enemy_sector_value.z)
			]
		elif enemy_sector_value is Array:
			enemy_sector = [
				int(enemy_sector_value[0]),
				int(enemy_sector_value[1]),
				int(enemy_sector_value[2])
			]

		if enemy_sector.size() < 3:
			continue

		if (
			int(enemy_sector[0]) == int(sector_array[0])
			and int(enemy_sector[1]) == int(sector_array[1])
			and int(enemy_sector[2]) == int(sector_array[2])
		):
			if Globals.print_priority_7:
				print(
					"[BattleV2MainBridge.get_enemy_by_name_in_sector] MATCH",
					" | name=", enemy_name,
					" | sector=", sector_array
				)

			return enemy

	return null


# ==========================================================
# SNAPSHOT HELPERS
# ==========================================================

func build_inventory_save_data() -> Dictionary:
	# Summary: Copy current inventory save data into plain data before the main scene is swapped away.
	if inventory == null:
		if Globals.print_priority_7:
			print("[battle_context_inventory_save_failed] reason=no_inventory")
		return {}

	if not inventory.has_method("get_save_data"):
		if Globals.print_priority_7:
			print("[battle_context_inventory_save_failed] reason=inventory_has_no_get_save_data")
		return {}

	var data = inventory.get_save_data()

	if typeof(data) != TYPE_DICTIONARY:
		if Globals.print_priority_7:
			print("[battle_context_inventory_save_failed] reason=get_save_data_not_dictionary type=", typeof(data))
		return {}

	var safe_data: Dictionary = data.duplicate(true)

	if Globals.print_priority_7:
		print("[battle_context_inventory_save_built] keys=", safe_data.keys())

	return safe_data


func build_player_state_save_data() -> Dictionary:
	# Summary: Copy current PlayerState save data into plain data before the main scene is swapped away.
	if player_state == null:
		if Globals.print_priority_7:
			print("[battle_context_player_state_save_failed] reason=no_player_state")
		return {}

	if not player_state.has_method("get_save_data"):
		if Globals.print_priority_7:
			print("[battle_context_player_state_save_failed] reason=player_state_has_no_get_save_data")
		return {}

	var data = player_state.get_save_data()

	if typeof(data) != TYPE_DICTIONARY:
		if Globals.print_priority_7:
			print("[battle_context_player_state_save_failed] reason=get_save_data_not_dictionary type=", typeof(data))
		return {}

	var safe_data: Dictionary = data.duplicate(true)

	if Globals.print_priority_7:
		print("[battle_context_player_state_save_built] keys=", safe_data.keys())

	return safe_data


func build_item_db_snapshot() -> Dictionary:
	# Summary: Copy item metadata into plain data before the main scene is swapped away.
	var snapshot := {}

	if item_handler == null:
		if Globals.print_priority_7:
			print("[battle_context_item_snapshot_failed] reason=no_item_handler")
		return snapshot

	if item_handler.has_method("normalize_item_shared_meta"):
		item_handler.normalize_item_shared_meta()

	var item_db = item_handler.get("item_db")
	if typeof(item_db) != TYPE_DICTIONARY:
		if Globals.print_priority_7:
			print("[battle_context_item_snapshot_failed] reason=item_db_not_dictionary type=", typeof(item_db))
		return snapshot

	for item_id in item_db.keys():
		var clean_item_id := str(item_id).strip_edges()
		var item_data = item_db.get(item_id, {})

		if clean_item_id == "":
			continue

		if typeof(item_data) == TYPE_DICTIONARY:
			snapshot[clean_item_id] = item_data.duplicate(true)

	if Globals.print_priority_7:
		print("[battle_context_item_snapshot_built] count=", snapshot.size())

	return snapshot
	
	
func build_battle_v2_context(entry_reason: String, enemy_ref) -> Dictionary:
	return build_context(entry_reason, enemy_ref)


func apply_battle_v2_result_if_needed() -> void:
	apply_result_if_needed()


func build_npc_save_data() -> Array:
	# Summary: Copy current NPC save data into plain data before the main scene is swapped away.
	if npc_handler == null:
		if Globals.print_priority_7:
			print("[battle_context_npc_save_failed] reason=no_npc_handler")
		return []

	if not npc_handler.has_method("to_save_data"):
		if Globals.print_priority_7:
			print("[battle_context_npc_save_failed] reason=npc_handler_has_no_to_save_data")
		return []

	var data = npc_handler.to_save_data()

	if typeof(data) != TYPE_ARRAY:
		if Globals.print_priority_7:
			print("[battle_context_npc_save_failed] reason=to_save_data_not_array type=", typeof(data))
		return []

	var safe_data: Array = data.duplicate(true)

	if Globals.print_priority_7:
		print("[battle_context_npc_save_built] count=", safe_data.size())

	return safe_data
	
	
func build_beacon_save_data() -> Array:
	# Summary: Copy current beacon save data into plain data before the main scene is swapped away.
	if beacons == null:
		if Globals.print_priority_7:
			print("[battle_context_beacon_save_failed] reason=no_beacons_ref")
		return []

	if not beacons.has_method("get_save_data"):
		if Globals.print_priority_7:
			print("[battle_context_beacon_save_failed] reason=beacons_has_no_get_save_data")
		return []

	var data = beacons.get_save_data()

	if typeof(data) != TYPE_ARRAY:
		if Globals.print_priority_7:
			print("[battle_context_beacon_save_failed] reason=get_save_data_not_array type=", typeof(data))
		return []

	var safe_data: Array = data.duplicate(true)

	if Globals.print_priority_7:
		print("[battle_context_beacon_save_built] count=", safe_data.size())

	return safe_data


func build_space_object_save_data() -> Array:
	# Summary: Copy current space-object save data into plain data before the main scene is swapped away.
	if space_objects == null:
		if Globals.print_priority_7:
			print("[battle_context_space_object_save_failed] reason=no_space_objects_ref")
		return []

	if not space_objects.has_method("get_save_data"):
		if Globals.print_priority_7:
			print("[battle_context_space_object_save_failed] reason=space_objects_has_no_get_save_data")
		return []

	var data = space_objects.get_save_data()

	if typeof(data) != TYPE_ARRAY:
		if Globals.print_priority_7:
			print("[battle_context_space_object_save_failed] reason=get_save_data_not_array type=", typeof(data))
		return []

	var safe_data: Array = data.duplicate(true)

	if Globals.print_priority_7:
		print("[battle_context_space_object_save_built] count=", safe_data.size())

	return safe_data


func apply_npc_result_if_present(npc_save_data: Array) -> bool:
	# Summary: Apply Battle V2 NPC snapshot back into the live main-mode NPCHandler.
	if npc_save_data.is_empty():
		return false

	apply_npc_save_data_to_live_handler(npc_save_data)

	if Globals.print_priority_7:
		print(
			"[BattleV2MainBridge.apply_npc_result]",
			" | count=", npc_save_data.size()
		)

	return true


func apply_npc_save_data_to_live_handler(npc_save_data: Array) -> void:
	# Summary: Refresh main-mode NPCHandler from the Battle V2 snapshot without relying on old scene refs.
	if npc_handler == null:
		if Globals.print_v:
			print("[BattleV2MainBridge.apply_npc_live_failed] reason=no_npc_handler")
		return

	if npc_handler.has_method("load_from_data"):
		npc_handler.load_from_data(npc_save_data.duplicate(true))
	elif npc_handler.has_method("from_save_data"):
		npc_handler.from_save_data(npc_save_data.duplicate(true))
	elif npc_handler.has_method("load_save_data"):
		npc_handler.load_save_data(npc_save_data.duplicate(true))
	else:
		if Globals.print_priority_7:
			print("[BattleV2MainBridge.apply_npc_live_failed] reason=no_load_method")
		return

	if Globals.print_priority_7:
		print("[BattleV2MainBridge.apply_npc_live_ok] count=", npc_save_data.size())
		
		
		
func apply_beacon_result_if_present(beacon_save_data: Array) -> bool:
	# Summary: Apply Battle V2 beacon snapshot back into the live main-mode Beacons handler.
	if beacon_save_data.is_empty():
		return false

	apply_beacon_save_data_to_live_handler(beacon_save_data)

	if Globals.print_priority_7:
		print(
			"[BattleV2MainBridge.apply_beacon_result]",
			" | count=", beacon_save_data.size()
		)

	return true


func apply_beacon_save_data_to_live_handler(beacon_save_data: Array) -> void:
	var battle_context: Dictionary = {}
	# Summary: Refresh main-mode Beacons from the Battle V2 snapshot without relying on old scene refs.
	if beacons == null:
		if Globals.print_priority_7:
			print("[BattleV2MainBridge.apply_beacon_live_failed] reason=no_beacons_ref")
		return

	if beacons.has_method("load_save_data"):
		beacons.load_save_data(beacon_save_data.duplicate(true))
	elif beacons.has_method("load_from_data"):
		beacons.load_from_data(beacon_save_data.duplicate(true))
	elif beacons.has_method("from_save_data"):
		beacons.from_save_data(beacon_save_data.duplicate(true))
	else:
		if Globals.print_priority_7:
			print("[BattleV2MainBridge.apply_beacon_live_failed] reason=no_load_method")
		return

	if Globals.print_priority_7:
		print("[BattleV2MainBridge.apply_beacon_live_ok] count=", beacon_save_data.size())


func apply_space_object_result_if_present(space_object_save_data: Array) -> bool:
	# Summary: Apply Battle V2 space-object snapshot back into the live main-mode Space_Objects handler.
	if space_object_save_data.is_empty():
		return false

	apply_space_object_save_data_to_live_handler(space_object_save_data)

	if Globals.print_priority_7:
		print(
			"[BattleV2MainBridge.apply_space_object_result]",
			" | count=", space_object_save_data.size()
		)

	return true


func apply_space_object_save_data_to_live_handler(space_object_save_data: Array) -> void:
	# Summary: Refresh main-mode Space_Objects from the Battle V2 snapshot without relying on old scene refs.
	if space_objects == null:
		if Globals.print_priority_7:
			print("[BattleV2MainBridge.apply_space_object_live_failed] reason=no_space_objects_ref")
		return

	if space_objects.has_method("load_save_data"):
		space_objects.load_save_data(space_object_save_data.duplicate(true))
	elif space_objects.has_method("load_from_data"):
		space_objects.load_from_data(space_object_save_data.duplicate(true))
	elif space_objects.has_method("from_save_data"):
		space_objects.from_save_data(space_object_save_data.duplicate(true))
	else:
		if Globals.print_priority_7:
			print("[BattleV2MainBridge.apply_space_object_live_failed] reason=no_load_method")
		return

	if Globals.print_priority_7:
		print("[BattleV2MainBridge.apply_space_object_live_ok] count=", space_object_save_data.size())


func get_battle_npc_save_data_from_context() -> Array:
	# Summary: Read NPC save-data snapshot from the global Battle V2 context.
	var context := {}

	if typeof(Globals.battle_v2_context) == TYPE_DICTIONARY:
		context = Globals.battle_v2_context

	var data = context.get("npc_save_data", [])

	if typeof(data) == TYPE_ARRAY:
		return data.duplicate(true)

	return []


func get_battle_beacon_save_data_from_context() -> Array:
	# Summary: Read beacon save-data snapshot from the global Battle V2 context.
	var context := {}

	if typeof(Globals.battle_v2_context) == TYPE_DICTIONARY:
		context = Globals.battle_v2_context

	var data = context.get("beacon_save_data", [])

	if typeof(data) == TYPE_ARRAY:
		return data.duplicate(true)

	return []


func get_battle_space_object_save_data_from_context() -> Array:
	# Summary: Read space-object save-data snapshot from the global Battle V2 context.
	var context := {}

	if typeof(Globals.battle_v2_context) == TYPE_DICTIONARY:
		context = Globals.battle_v2_context

	var data = context.get("space_object_save_data", [])

	if typeof(data) == TYPE_ARRAY:
		return data.duplicate(true)

	return []
	
	
func resolve_npc_save_data(existing_save: Dictionary, npc_handler: NPCHandler = null, npc_snapshot_data: Array = []) -> Array:
	# Summary: Prefer Battle V2 NPC snapshot, then live NPCHandler data, then existing save data.
	if not npc_snapshot_data.is_empty():
		if Globals.print_v:
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
