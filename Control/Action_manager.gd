extends Node
class_name Action_Manager

signal scan_completed(packet: Dictionary)
signal mining_visual_queued(packet: Dictionary)
signal mining_completed(packet: Dictionary)


# ╔══════════════════════════════════════════════════════════╗
# ║                  ACTION MANAGER REFERENCES              ║
# ╠══════════════════════════════════════════════════════════╣
# ║ These variables are the outside systems this manager     ║
# ║ talks to. The Action_Manager does not own these systems; ║
# ║ it simply receives references during setup() and uses    ║
# ║ them to scan, mine, refresh buttons, save, and log.      ║
# ╚══════════════════════════════════════════════════════════╝

var state : WidgetsState5
var map : Map
var star_field : StarField
var space_objects : Space_Objects
var beacons : Beacons
var planets : Planets
var inventory : Inventory5
var save_manager : SaveManager
var auto_pilot : AutoPilot
var action_handler : Action_Handler
var event_handler : EventManager
var enemy_handler : EnemyHandler
var npc_handler : NPCHandler

var energy_handler : EnergyHandler
var npc_scene_bridge = null
var scanned_enemies: Array = []
var scanned_event_targets: Array = []
var engage_enemy_in_progress := false
var battle_v2_bridge = BattleV2MainBridge
const ACTION_SCAN_RANGE := 1000.0
const ENEMY_BATTLE_RANGE := 180.0
const ENEMY_BATTLE_ENTRY_SECONDS := 2.5
const SCAN_POSITION_MOVE_EPSILON := 1.0
const ASTEROID_RESOURCE_LEFT_SUFFIX := "_left"

# ╔══════════════════════════════════════════════════════════╗
# ║              SCANNED ASTEROID MEMORY CACHE              ║
# ╠══════════════════════════════════════════════════════════╣
# ║ This array temporarily stores asteroids found during     ║
# ║ scan_local_mk1().                                       ║
# ║                                                          ║
# ║ The mining action later uses this list to know what      ║
# ║ asteroid targets are currently available to mine.        ║
# ╚══════════════════════════════════════════════════════════╝

var scanned_mineable_asteroids: Array = []
var scanned_npcs: Array[NPC] = []
var has_scan_position_snapshot := false
var last_scan_sector_pos := Vector3i.ZERO
var last_scan_local_pos := Vector3.ZERO

#bool for can mine or auto impuse
var show_mine_action = false

var scan_in_progress := false
var mining_in_progress := false

var battle_mode := false

# ╔══════════════════════════════════════════════════════════╗
# ║                         SETUP                           ║
# ╠══════════════════════════════════════════════════════════╣
# ║ Receives and stores every outside system reference that  ║
# ║ the Action_Manager needs.                               ║
# ║                                                          ║
# ║ This is the “plug everything in” function.               ║
# ╚══════════════════════════════════════════════════════════╝

func setup(
	new_state: WidgetsState5,
	new_map: Map,
	new_star_field: StarField,
	new_space_objects: Space_Objects,
	new_beacons: Beacons,
	new_planets : Planets,
	new_inventory: Inventory5,
	new_save_manager : SaveManager,
	new_auto_pilot : AutoPilot,
	new_event_handler : EventManager,
	new_enemy_handler : EnemyHandler,
	new_npc_handler : NPCHandler = null,
	
	new_energy_handler : EnergyHandler = null,
	new_npc_scene_bridge = null,
	new_battle_v2_scene_bridge = null
) -> void:

	action_handler = Action_Handler.new()
	add_child(action_handler)
	
	enemy_handler = new_enemy_handler
	npc_handler = new_npc_handler
	npc_scene_bridge = new_npc_scene_bridge
	
	event_handler = new_event_handler
	# Store the autopilot reference so action buttons can react
	# differently when autopilot is running.
	auto_pilot = new_auto_pilot

	# Store the save manager so actions like mining can save progress.
	save_manager = new_save_manager

	# Debug print to confirm beacons arrived correctly.
	if Globals.debug_heat_1:
		if Globals.print_priority_2:
			print("ACTION SETUP received new_beacons = ", new_beacons)

	# Store the beacon system reference.
	beacons = new_beacons
	planets = new_planets

	# Debug print to confirm beacons were stored correctly.
	if Globals.debug_heat_1:
		if Globals.print_priority_2:
			print("ACTION SETUP stored beacons = ", beacons)

	# Store the shared GUI/widget state.
	state = new_state

	# Store the map reference for sector/local position checks.
	map = new_map

	# Store the star field reference for local star scanning.
	star_field = new_star_field

	# Store the space object manager reference for asteroids/objects.
	space_objects = new_space_objects
	if Globals.debug_heat_1:
		# Final beacon debug confirmation.
		if Globals.print_priority_3:
			print("ACTION MANAGER BEACONS SET TO: ", beacons)
		
		# Debug message marking where inventory is attached.
		if Globals.print_priority_3:
			print("this is were im adding inventory = new_inventory")

	# Store the inventory reference so actions can be unlocked by items.
	inventory = new_inventory
	
	energy_handler = new_energy_handler
	action_handler.setup(
		map,
		star_field,
		space_objects,
		beacons,
		planets,
		inventory,
		state,
		auto_pilot,
		save_manager,
		energy_handler
	)
	battle_v2_bridge = new_battle_v2_scene_bridge
	load_scan_position_snapshot()


func has_navigation_lock_todo() -> bool:
	if event_handler == null:
		return false
	if not event_handler.has_method("has_navigation_lock_todo"):
		return false
	return bool(event_handler.has_navigation_lock_todo())


func get_navigation_lock_todo_text() -> String:
	if event_handler == null:
		return ""
	if not event_handler.has_method("get_navigation_lock_todo_text"):
		return ""
	return str(event_handler.get_navigation_lock_todo_text()).strip_edges()


func get_navigation_lock_message(action_label: String = "Action") -> String:
	var task_text := get_navigation_lock_todo_text()
	if task_text == "":
		task_text = "the active task"
	return action_label + " unavailable while " + task_text + "."


func should_block_navigation_action(action_id: String) -> bool:
	if not has_navigation_lock_todo():
		return false
	return action_id in [
		"auto_pilot",
		"approach",
		"approach_enemy"
	]


func block_navigation_action_for_todo(action_label: String = "Action") -> void:
	if state != null:
		state.use_auto_pilot = false
		if state.log_storage.has("log_text"):
			state.log_storage["log_text"].text = get_navigation_lock_message(action_label)

	if auto_pilot != null and auto_pilot.enabled:
		auto_pilot.stop()

	if Globals.print_priority_2:
		print(get_navigation_lock_message(action_label))


func remember_scan_position() -> void:
	if map == null:
		return

	has_scan_position_snapshot = true
	last_scan_sector_pos = map.sector_pos
	last_scan_local_pos = map.local_pos
	save_scan_position_snapshot()


func has_player_moved_since_scan() -> bool:
	if not has_scan_position_snapshot:
		return false
	if map == null:
		return false
	if map.sector_pos != last_scan_sector_pos:
		return true
	return map.local_pos.distance_to(last_scan_local_pos) > SCAN_POSITION_MOVE_EPSILON


func clear_scan_results_if_player_moved(reason: String = "") -> bool:
	if not has_player_moved_since_scan():
		return false

	scanned_npcs.clear()
	scanned_enemies.clear()
	scanned_event_targets.clear()
	scanned_mineable_asteroids.clear()
	show_mine_action = false
	has_scan_position_snapshot = false
	save_scan_position_snapshot()

	if Globals.print_priority_2:
		print("Scan cache cleared after movement. reason=", reason)

	refresh_actions_from_inventory()
	return true


func save_scan_position_snapshot() -> void:
	if save_manager == null or not save_manager.has_method("save_scan_state"):
		return

	# Scan autosave disabled. Keep scan position in memory, but avoid disk writes
	# during timed scan/TODO flows.
	#save_manager.save_scan_state({
		#"valid": has_scan_position_snapshot,
		#"sector_pos": {
			#"x": last_scan_sector_pos.x,
			#"y": last_scan_sector_pos.y,
			#"z": last_scan_sector_pos.z
		#},
		#"local_pos": {
			#"x": last_scan_local_pos.x,
			#"y": last_scan_local_pos.y,
			#"z": last_scan_local_pos.z
		#}
	#})


func load_scan_position_snapshot() -> void:
	if save_manager == null or not save_manager.has_method("load_scan_state"):
		return

	var scan_state: Dictionary = save_manager.load_scan_state()
	if scan_state.is_empty():
		return

	has_scan_position_snapshot = bool(scan_state.get("valid", false))
	last_scan_sector_pos = read_live_map_target_sector({"sector_pos": scan_state.get("sector_pos", Vector3i.ZERO)})
	last_scan_local_pos = read_live_map_target_local({"local_pos": scan_state.get("local_pos", Vector3.ZERO)})

# ╔══════════════════════════════════════════════════════════╗
# ║                    CREATE ACTION ROOT                   ║
# ╠══════════════════════════════════════════════════════════╣
# ║ Builds the main holder for the whole Actions widget.     ║
# ║                                                          ║
# ║ Full widget size:                                       ║
# ║   - 300 wide                                            ║
# ║   - 325 tall                                            ║
# ╚══════════════════════════════════════════════════════════╝

func build_battle_v2_context(entry_reason: String, enemy_ref) -> Dictionary:
	# Summary: Build the main-project Battle V2 handoff packet, including the current inventory-derived loadout.
	return {
		"entry_reason": entry_reason,
		"enemy": enemy_ref,
		"loadout_data": build_battle_v2_loadout_data(),
		"inventory": inventory,
		"energy_handler": energy_handler,
		"action_manager": self
	}


func build_battle_v2_loadout_data() -> Dictionary:
	# Summary: Read currently owned/equipped-style battle items from Inventory without mutating counts.
	var loadout := {
		"selected_primary_weapon": null,
		"selected_secondary_weapon": null,
		"selected_shield": null,
		"loaded_consumable": null,
		"loaded_consumable_state": "none",
		"equipped_upgrades": [],
		"labels": [
			"player_loadout_bridge",
			"player_inventory_bridge",
			"player_handler_no_inventory_counts"
		]
	}

	loadout["selected_primary_weapon"] = _find_battle_v2_loadout_item("weapon", ["energy"])
	loadout["selected_secondary_weapon"] = _find_battle_v2_loadout_item("weapon", ["kinetic"])
	loadout["selected_shield"] = _find_battle_v2_loadout_item("shield", ["shield", ""])
	loadout["loaded_consumable"] = null

	return loadout


func _find_battle_v2_loadout_item(item_type: String, subtypes: Array) -> Variant:
	# Summary: Find the first owned item matching a battle loadout lane using Inventory as the count owner.
	if inventory == null:
		return null
	if inventory.item_handler == null:
		return null

	var item_db: Dictionary = inventory.item_handler.item_db
	var priority_order := _get_battle_v2_loadout_priority(item_type, subtypes)

	for item_id in priority_order:
		if _battle_v2_inventory_has_item(str(item_id)) and _item_matches_battle_v2_lane(item_db.get(item_id, {}), item_type, subtypes):
			return str(item_id)

	for item_id in item_db.keys():
		if _battle_v2_inventory_has_item(str(item_id)) and _item_matches_battle_v2_lane(item_db.get(item_id, {}), item_type, subtypes):
			return str(item_id)

	return null


func _get_battle_v2_loadout_priority(item_type: String, subtypes: Array) -> Array:
	# Summary: Keep current starter gear stable before falling back to the item database order.
	if item_type == "weapon" and subtypes.has("energy"):
		return ["pulse_laser_mk1", "plasma_arc_emitter", "phase_beam_array"]
	if item_type == "weapon" and subtypes.has("kinetic"):
		return ["railgun_mk1", "mass_driver", "shard_flinger"]
	if item_type == "shield":
		return ["reinforced_barrier_mk1", "basic_shield_mk1"]
	if item_type == "consumable":
		return ["repair_kit", "shield_patch_cell", "recharge_kit", "buster_charge"]
	return []


func _battle_v2_inventory_has_item(item_id: String) -> bool:
	# Summary: Ask Inventory whether an item is present without reading or changing item counts here.
	if item_id.strip_edges() == "":
		return false
	if inventory == null:
		return false
	if not inventory.has_method("has_item_anywhere"):
		return false
	return inventory.has_item_anywhere(item_id)


func _item_matches_battle_v2_lane(item_data: Dictionary, item_type: String, subtypes: Array) -> bool:
	# Summary: Match item metadata to a Battle V2 loadout lane.
	if item_data.is_empty():
		return false

	var data_type := str(item_data.get("type", "")).strip_edges()
	var data_subtype := str(item_data.get("subtype", "")).strip_edges()

	if data_type != item_type:
		return false
	if subtypes.is_empty():
		return true
	if subtypes.has(data_subtype):
		return true
	if item_type == "shield" and data_type == "shield":
		return true
	if item_type == "consumable" and data_type == "consumable":
		return true

	return false


func create_action_root(pos: Vector2) -> Control:

	# Create the root Control node that holds the action UI.
	var c = Control.new()

	# Give the node a clear scene-tree name.
	c.name = "Action_Root"

	# Place the action widget at the requested screen position.
	c.position = pos

	# Lock in the shared compact action panel size.
	c.size = Globals.action_widget_size

	# Store this root in action_storage so other scripts can find it.
	state.action_storage["root"] = c

	# Return the finished root node.
	return c
	

# ╔══════════════════════════════════════════════════════════╗
# ║                        RUN ACTION                       ║
# ╠══════════════════════════════════════════════════════════╣
# ║ Routes action button clicks to the correct function.     ║
# ║                                                          ║
# ║ Button IDs come in as strings, then match decides which  ║
# ║ action function should fire.                             ║
# ╚══════════════════════════════════════════════════════════╝

func run_action(action_id: String, action_payload: Dictionary = {}) -> void:
	if Globals.is_popup_input_locked():
		if Globals.print_priority_2:
			print("Action blocked while tutorial/story popup is active: ", action_id)
		return

	if should_block_navigation_action(action_id):
		block_navigation_action_for_todo("Auto pilot")
		refresh_actions_from_inventory()
		return

	# Debug print so we can see exactly what button was clicked.
	if Globals.print_priority_3:
		print("ACTION CLICKED: ", action_id)
	
	# Route the incoming action ID to the correct behavior.
	match action_id:
		
		"auto_pilot":
			run_live_map_target_autopilot()

		# Scan button.
		"scan_local":
			Globals.scan_was_clicked = true
			
			
			state.log_storage["log_text"].text = "SCANNING LOCAL SPACE..."
			if scan_in_progress:
				
				if Globals.print_priority_2:
					print("Scan already in progress.")
				return

			scan_in_progress = true

			# hide button immediately
			refresh_actions_from_inventory()

			# start timed event
			event_handler.add_event(
				"Scanning Local Space...",
				2.5,
				"scan",
				{}
			)

		# Mining button.
		"mine_asteroid":
			Globals.scan_was_clicked = false

			if mining_in_progress:
				if Globals.print_priority_2:
					print("Mining already in progress.")
				return

			var mining_duration := 1.0
			var mining_visual_packet := build_mining_visual_packet(mining_duration)
			if mining_visual_packet.is_empty():
				if Globals.print_priority_2:
					print("Mining visual cue blocked - no valid scanned asteroid packet.")
				return

			mining_in_progress = true

			# hide button immediately
			refresh_actions_from_inventory()

			# Let visual-only views animate the exact asteroid before the result popup opens.
			mining_visual_queued.emit(mining_visual_packet)

			# start timed event
			event_handler.add_event(
				"Deploying Miner Drone...",
				mining_duration,
				"mining",
				mining_visual_packet
			)
			
		"approach":
			Globals.scan_was_clicked = false
			
			action_handler.handle_auto_impulse_to_target(scanned_mineable_asteroids)
			refresh_actions_from_inventory()
		"talk_npc":
			Globals.scan_was_clicked = false
			if Globals.battle_mode or Globals.battle_pending:
				if Globals.print_priority_2:
					print("NPC TALK blocked - battle active")
				return

			var talk_npc := resolve_talk_npc_from_payload(action_payload)
			if talk_npc == null:
				if Globals.print_priority_2:
					print("NPC TALK blocked - clicked NPC could not be resolved: ", action_payload)
				return

			if npc_scene_bridge == null or not npc_scene_bridge.has_method("request_npc_chat"):
				if Globals.print_priority_2:
					print("NPC TALK blocked - npc_scene_bridge missing")
				return

			var request_packet := build_npc_scene_request_packet(talk_npc)
			var requested := bool(npc_scene_bridge.request_npc_chat(request_packet))
			if Globals.print_priority_2:
				print("NPC TALK bridge request result: ", requested, " packet=", request_packet)

			refresh_actions_from_inventory()
			return

			
		"approach_enemy":
			Globals.scan_was_clicked = false
			var enemy_data := get_enemy_action_payload_data(action_payload)
			if enemy_data.is_empty():
				if Globals.print_priority_2:
					print("Engage enemy blocked - no scanned enemies.")
				refresh_actions_from_inventory()
				return

			var enemy = enemy_data.get("enemy", null)

			if enemy == null:
				if Globals.print_priority_2:
					print("Engage enemy blocked - scanned enemy ref is null.")
				refresh_actions_from_inventory()
				return

			#engage_enemy_in_progress = true
			Globals.current_enemy = enemy
			var enemy_distance := get_scanned_enemy_distance(enemy_data, enemy)
			if Globals.print_priority_2:
				print("[ACTION_ENEMY_APPROACH] enemy=", str(enemy.enemy_name), " dist=", enemy_distance, " battle_range=", ENEMY_BATTLE_RANGE)
			if enemy_distance <= ENEMY_BATTLE_RANGE:
				queue_scanned_enemy_battle_entry(enemy)
				return

			if Globals.print_priority_2:
				print("#-------------------#")
				print("#-------------------#")
				print(str(enemy.local_pos))
				print("#-------------------#")
				print("#-------------------#")

			state.log_storage["log_text"].text = "Preparing to engage " + str(enemy.enemy_name) + "..."

			
			auto_pilot.set_impulse_target(enemy.sector_pos, enemy.local_pos, str(enemy.enemy_name), "enemy")
			refresh_actions_from_inventory()	
			return
					
		"engage_scanned_enemy":
			Globals.scan_was_clicked = false

			if engage_enemy_in_progress:
				if Globals.print_priority_2:
					print("Engage enemy already in progress.")
				return

			if Globals.battle_mode or Globals.battle_pending:
				if Globals.print_priority_2:
					print("Engage enemy blocked - battle already active or pending.")
				return

			var enemy_data := get_enemy_action_payload_data(action_payload)
			if enemy_data.is_empty():
				if Globals.print_priority_2:
					print("Engage enemy blocked - no scanned enemies.")
				refresh_actions_from_inventory()
				return

			var enemy = enemy_data.get("enemy", null)

			if enemy == null:
				if Globals.print_priority_2:
					print("Engage enemy blocked - scanned enemy ref is null.")
				refresh_actions_from_inventory()
				return

			if Globals.print_priority_2:
				print("[ACTION_ENEMY_BATTLE_CLICK] enemy=", str(enemy.enemy_name), " dist=", get_scanned_enemy_distance(enemy_data, enemy))

			queue_scanned_enemy_battle_entry(enemy)
			return

		"select_scanned_event":
			Globals.scan_was_clicked = false
			run_scanned_event_action(action_payload)
			return
			
			
		"combat":
			Globals.scan_was_clicked = false

			if Globals.Let_battle_v2:
				# Route combat into the isolated Battle V2 scene through the safe global swap path.
				if Globals.print_priority_2:
					print("Requesting Battle V2 scene from combat action.")
				Globals.battle_v2_context = build_battle_v2_context("manual_combat_action", Globals.current_enemy)
				Globals.battle_pending = true
				Globals.swap_battle_v2 = true
				return

			if not Globals.Let_battle_v1:
				if Globals.print_priority_2:
					print("Battle v1 entry is disabled.")
				return

			if Globals.battle_mode:
				if Globals.print_priority_2:
					print("Already in battle")
				return

			if Globals.print_priority_3:
				print("INITIATING COMBAT")

			event_handler.add_event(
				"Entering Combat Zone...",
				25.0,
				"enter_battle",
				{}
			)
			
		# Safety catch for any unknown action ID.
		_:
			if Globals.print_priority_2:
				print("Unknown action: ", action_id)


# ╔══════════════════════════════════════════════════════════╗
# ║                       SCAN LOCAL                        ║
# ╠══════════════════════════════════════════════════════════╣
# ║ Older/local scan function.                              ║
# ║                                                          ║
# ║ Current behavior:                                       ║
# ║   - checks required references                          ║
# ║   - finds nearest star                                  ║
# ║   - writes basic star data into the log                  ║
# ╚══════════════════════════════════════════════════════════╝
	
func scan_local() -> void:

	# Start marker for debug output.
	if Globals.print_priority_2:
		print("SCAN LOCAL STARTED")

	# Safety check: GUI state must exist before logging.
	if state == null:
		if Globals.print_priority_2:
			print("Scan failed: state missing.")
		return

	# Safety check: map must exist before distance checks.
	if map == null:
		if Globals.print_priority_2:
			print("Scan failed: map missing.")
		return

	# Safety check: star field must exist before star scanning.
	if star_field == null:
		if Globals.print_priority_2:
			print("Scan failed: star_field missing.")
		return

	# Ask the star field for the nearest star to the current map position.
	var nearest_stars = star_field.get_nearest_stars(map, 1)

	# If no stars are found, write a clean scan result and stop.
	if nearest_stars.size() <= 0:
		state.log_storage["log_text"].text = "LOCAL SCAN COMPLETE\nNo star detected."
		return

	# Pull the first nearest-star result.
	var scan_data = nearest_stars[0]

	# Extract the actual star object from the scan dictionary.
	var star = scan_data["star"]

	# Write the scan report into the log panel.
	state.log_storage["log_text"].text = (
		"LOCAL SCAN COMPLETE\n"
		+ "Object: Star\n"
		+ "Type: " + str(star.star_type) + "\n"
		+ "Distance: " + str(int(scan_data["distance"])) + "\n"
		+ "Sector: " + str(star.sector_pos) + "\n"
		+ "Local Pos: " + str(star.local_pos)
	)
		

# ╔══════════════════════════════════════════════════════════╗
# ║                    SCAN LOCAL MK1                       ║
# ╠══════════════════════════════════════════════════════════╣
# ║ Main scan-module action.                                ║
# ║                                                          ║
# ║ This scan currently gathers:                            ║
# ║   - nearby stars                                        ║
# ║   - local space objects                                 ║
# ║   - mineable asteroids                                  ║
# ║   - beacon signals                                      ║
# ║                                                          ║
# ║ NOTE: This function has some repeated beacon/object      ║
# ║ sections later in the original script. They are kept     ║
# ║ exactly as-is so behavior is not changed.                ║
# ╚══════════════════════════════════════════════════════════╝

func scan_local_mk1() -> void:
	scanned_npcs.clear()
	scanned_enemies.clear()
	scanned_event_targets.clear()
	if Globals.print_priority_3:
		print("here are the npcs in sector" + str(npc_handler.get_npcs_in_sector(map.sector_pos)))
	#if save_manager != null:
		#save_world_with_events()
	scanned_mineable_asteroids.clear()
	#scanned_npcs.clear()
	show_mine_action = false
	# 🚫 BLOCK SCAN DURING WARP
	if auto_pilot != null and auto_pilot.enabled and auto_pilot.mode == "warp":
		if Globals.print_priority_2:
			print("Scan blocked: ship is in warp.")
		return


	# The closest star found by this scan.
	var found_star = null

	# Starting huge number so any real distance can beat it.
	var closest_dist := 999999999.0

	# MK1 scan range limit.
	var scan_range := ACTION_SCAN_RANGE
	
	
	# Debug print to confirm this function has a beacon reference.
	if Globals.print_priority_3:
		print("SCAN USING beacons = ", beacons)
	
	# Safety check: beacons must exist before beacon scanning.
	if beacons == null:
		if Globals.print_priority_2:
			print("ERROR: scan_local_mk1 has no Beacons reference yet")
		return

	# Safety check: space objects must exist before object scanning.
	if space_objects == null:
		if Globals.print_priority_2:
			print("ERROR: scan_local_mk1 has no Space_Objects reference yet")
		return

	# Get all beacon signals in the current sector.
	var local_beacons = beacons.get_beacons_in_sector(map.sector_pos)

	# Debug print block for all local beacons.
	if Globals.print_priority_3:
		print("---- LOCAL BEACONS ----")

	# Print each beacon title/message for testing.
	for beacon in local_beacons:
		if Globals.print_priority_3:
			print(beacon["title"])
		if Globals.print_priority_3:
			print(beacon["message"])
		
	var enemies = enemy_handler.get_enemies_in_sector(map.sector_pos)
	var scan_text := ""

	var found_enemy_count := 0
	if enemies.is_empty():
		#scan_text += "No enemy signatures detected.\n"
		pass
	else:
		#scan_text += "ENEMY SIGNATURES DETECTED:\n"

		for enemy in enemies:
			var enemy_dist = map.get_distance_to_target(enemy.sector_pos, enemy.local_pos)
			if enemy_dist > scan_range:
				continue

			scanned_enemies.append({
				"enemy": enemy,
				"distance": enemy_dist
			})
			found_enemy_count += 1

			scan_text += enemy.enemy_name + " - Distance: " + str(round(enemy_dist)) + "\n"

		scanned_enemies.sort_custom(func(a, b):
			return float(a.get("distance", 999999.0)) < float(b.get("distance", 999999.0))
		)

		#if found_enemy_count <= 0:
			#scan_text += "No enemy signatures detected in scan range.\n"
		#scan_text += "\n"

	if npc_handler != null:
		var npcs = npc_handler.get_npcs_in_sector(map.sector_pos)
		var found_npc_count := 0
		if npcs.is_empty():
			#scan_text += "No NPC contacts detected.\n"
			pass
		else:
			#scan_text += "NPC CONTACTS DETECTED:\n"
			for npc in npcs:
				var npc_dist = map.get_distance_to_target(npc.sector_pos, npc.local_pos)
				if npc_dist > scan_range:
					continue
				scanned_npcs.append(npc)
				found_npc_count += 1
				#scan_text += npc.npc_name + " - " + npc.npc_species + " " + npc.npc_role + "\n"
				#scan_text += "Distance: " + str(round(npc_dist)) + "\n"
				#scan_text += "Friendly: " + str(npc.is_friendly) + "\n"
				#scan_text += "Can Trade: " + str(npc.can_trade) + "\n"
				#if npc.has_message:
					#scan_text += "Message: " + npc.greeting_message + "\n"
				#scan_text += "\n"
			#if found_npc_count <= 0:
				#scan_text += "No NPC contacts detected in scan range.\n\n"

	collect_scanned_event_targets(scan_range)
	#if scanned_event_targets.is_empty():
		#scan_text += "No event targets detected in scan range.\n"
	#else:
		#scan_text += "EVENT TARGETS DETECTED:\n"
		#for event_packet in scanned_event_targets:
			#scan_text += "- " + str(event_packet.get("display_name", event_packet.get("event_id", "Event"))) + "\n"
			#scan_text += "  State: " + str(event_packet.get("event_state", "active")) + "\n"
			#scan_text += "  Distance: " + str(round(float(event_packet.get("distance", 0.0)))) + "\n"
		#scan_text += "\n"

	# Search through every generated star.
	for star in star_field.stars:

		# Get the full distance from the ship/map to this star.
		var dist = map.get_distance_to_target(star.sector_pos, star.local_pos)

		# If the star is within scan range and closer than the current best,
		# remember it as the found star.
		if dist <= scan_range and dist < closest_dist:
			closest_dist = dist
			found_star = star

	# This string becomes the full scan report.
	

	# Main scan title.
	#scan_text += "LOCAL SCAN COMPLETE\n\n"
#
	## If a star was found, write its details.
	#if found_star != null:
		#scan_text += "Object: Star\n"
		#scan_text += "Type: " + str(found_star.star_type) + "\n"
		#scan_text += "Distance: " + str(int(closest_dist)) + "\n"
		#scan_text += "Sector: " + str(found_star.sector_pos) + "\n"
		#scan_text += "Local Pos: " + str(found_star.local_pos) + "\n\n"
#
	## If no star was found, write a clean empty result.
	#else:
		#scan_text += "No stellar objects detected.\n\n"


	# ╔══════════════════════════════════════════════════════╗
	# ║                    SPACE OBJECTS                    ║
	# ╚══════════════════════════════════════════════════════╝
	var asteroid_scan_text := scan_asteroids_in_sector()
	if asteroid_scan_text != "":
		scan_text += asteroid_scan_text
	else:
		if Globals.print_priority_2:
			print('scan_asteroids_in_sector() is null. .. .. ')
	# --------------------------------
	# AUTO TARGET CLOSEST ASTEROID
	# --------------------------------
	


	# ╔══════════════════════════════════════════════════════╗
	# ║                       BEACONS                       ║
	# ╚══════════════════════════════════════════════════════╝

	if local_beacons.is_empty():
		scan_text += "No beacon signals detected.\n"

	else:
		scan_text += "BEACON SIGNALS:\n"

		for beacon in local_beacons:
			var beacon_dist = map.local_pos.distance_to(beacon["local_pos"])

			scan_text += "- " + str(beacon["title"]) + "\n"
			scan_text += "  Distance: " + str(int(beacon_dist)) + "\n"
			scan_text += "  Message: " + str(beacon["message"]) + "\n"


	# ╔══════════════════════════════════════════════════════╗
	# ║                  FINAL LOG WRITE                    ║
	# ╚══════════════════════════════════════════════════════╝

	state.log_storage["log_text"].text = scan_text

	# Refresh action buttons after scan results update.
	remember_scan_position()
	refresh_actions_from_inventory()
	# AMI STAR CHART first pass: notify main_mode only after a real sensor sweep completes.
	scan_completed.emit({
		"reason": "scan_local_mk1",
		"sector_pos": map.sector_pos if map != null else Vector3i.ZERO,
		"local_pos": map.local_pos if map != null else Vector3.ZERO,
		"enemy_awareness": build_scan_enemy_awareness_packet(found_enemy_count, scan_range),
		"found_enemy_count": found_enemy_count,
		"scan_range": scan_range
	})


func build_scan_enemy_awareness_packet(found_enemy_count: int, scan_range: float) -> Dictionary:
	var enemies: Array = []
	var max_entries = min(scanned_enemies.size(), 5)
	for i in range(max_entries):
		var enemy_data = scanned_enemies[i]
		if typeof(enemy_data) != TYPE_DICTIONARY:
			continue
		var enemy_ref = enemy_data.get("enemy", null)
		var distance := float(enemy_data.get("distance", 0.0))
		enemies.append(build_scan_enemy_commentary_summary(enemy_ref, distance))

	return {
		"found_enemy_count": found_enemy_count,
		"enemy_count": enemies.size(),
		"scan_range": scan_range,
		"battle_range": ENEMY_BATTLE_RANGE,
		"sector": str(map.sector_pos) if map != null else str(Vector3i.ZERO),
		"ship_local": str(map.local_pos) if map != null else str(Vector3.ZERO),
		"enemies": enemies
	}


func build_scan_enemy_commentary_summary(enemy_ref, distance: float) -> Dictionary:
	var enemy_name := str(read_enemy_commentary_value(enemy_ref, "enemy_name", read_enemy_commentary_value(enemy_ref, "display_name", "enemy contact")))
	return {
		"name": enemy_name,
		"enemy_name": enemy_name,
		"enemy_type": str(read_enemy_commentary_value(enemy_ref, "enemy_type", read_enemy_commentary_value(enemy_ref, "type", "enemy"))),
		"distance": distance,
		"in_battle_range": distance <= ENEMY_BATTLE_RANGE,
		"sector": str(read_enemy_commentary_value(enemy_ref, "sector_pos", "")),
		"local": str(read_enemy_commentary_value(enemy_ref, "local_pos", "")),
		"object_id": str(read_enemy_commentary_value(enemy_ref, "object_id", ""))
	}


func read_enemy_commentary_value(source, key: String, fallback = null):
	if typeof(source) == TYPE_DICTIONARY:
		return source.get(key, fallback)
	if source is Object:
		if not (key in source):
			return fallback
		var value = source.get(key)
		if value == null:
			return fallback
		return value
	return fallback
func _create_action_header(parent: Control) -> void:

	# ──────────────────────────────────────────────────────
	# BACKGROUND PANEL (dark sci-fi strip)
	# ──────────────────────────────────────────────────────
	var header_bg = ColorRect.new()
	header_bg.name = "Action_Header_BG"                 # Scene tree identifier
	header_bg.position = Vector2(0, 0)                 # Top of panel
	header_bg.size = Vector2(parent.size.x, 25)        # Full width, thin strip
	header_bg.color = Color(0.1, 0.1, 0.1, 0.9)        # Slightly transparent dark tone

	parent.add_child(header_bg)                        # Attach to parent container

	# ──────────────────────────────────────────────────────
	# HEADER TEXT LABEL
	# ──────────────────────────────────────────────────────
	var label = Label.new()
	label.name = "Action_Header_Label"                 # Scene tree identifier
	label.text = "Available Commands"                  # Displayed title
	label.size = Vector2(parent.size.x, 25)            # Match header size
	label.position = Vector2(0, 0)                     # Align perfectly with bg

	# Center the text both horizontally and vertically
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	parent.add_child(label)                            # Add label above background

	# ──────────────────────────────────────────────────────
	# STORE REFERENCES (VERY IMPORTANT)
	# ──────────────────────────────────────────────────────
	state.action_storage["header_bg"] = header_bg
	state.action_storage["header_label"] = label
	

# ╔══════════════════════════════════════════════════════════╗
# ║             ACTION SCROLL BODY CREATION                 ║
# ╠══════════════════════════════════════════════════════════╣
# ║ Creates the scrollable area where action buttons live.  ║
# ║                                                        ║
# ║ Structure:                                             ║
# ║  ScrollContainer                                       ║
# ║     └── VBoxContainer (button list)                    ║
# ╚══════════════════════════════════════════════════════════╝
func _create_action_scroll_body(parent: Control) -> void:

	# ──────────────────────────────────────────────────────
	# SCROLL CONTAINER (viewport)
	# ──────────────────────────────────────────────────────
	var scroll = ScrollContainer.new()
	scroll.name = "Action_Scroll"

	var header_h: float = 25.0
	scroll.position = Vector2(0, header_h)        # Positioned BELOW header
	scroll.size = Vector2(parent.size.x, max(parent.size.y - header_h, 0.0))

	parent.add_child(scroll)

	# ──────────────────────────────────────────────────────
	# BUTTON HOLDER (vertical stack)
	# ──────────────────────────────────────────────────────
	var box = VBoxContainer.new()
	box.name = "Action_Button_List"

	# Allow it to stretch and fill available space
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL

	scroll.add_child(box)

	# ──────────────────────────────────────────────────────
	# STORE REFERENCES
	# ──────────────────────────────────────────────────────
	state.action_storage["scroll"] = scroll
	state.action_storage["button_list"] = box
	
	
# ╔══════════════════════════════════════════════════════════╗
# ║              ACTION ROOT + BACK PANEL                   ║
# ╠══════════════════════════════════════════════════════════╣
# ║ Builds the full container AND its visual styling.       ║
# ║                                                        ║
# ║ Includes:                                              ║
# ║  - Glow border                                         ║
# ║  - Background panel                                    ║
# ╚══════════════════════════════════════════════════════════╝
func _create_action_root(pos: Vector2) -> Control:

	# Root container
	var c = Control.new()
	c.name = "Action_Root"
	c.position = pos
	c.size = Globals.action_widget_size

	# Store reference
	state.action_storage["root"] = c


	# ──────────────────────────────────────────────────────
	# GLOW BORDER (visual flair)
	# ──────────────────────────────────────────────────────
	var border = ColorRect.new()
	border.size = c.size
	border.color = Color(0.2, 0.6, 1.0, 0.3)   # Blue glow effect
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE

	c.add_child(border)
	border.z_index = 1                         # Ensure above bg


	# ──────────────────────────────────────────────────────
	# MAIN BACKGROUND PANEL
	# ──────────────────────────────────────────────────────
	var bg = ColorRect.new()
	bg.name = "Action_BG"
	bg.position = Vector2(0, 0)
	bg.size = c.size
	bg.color = Color(0.05, 0.05, 0.08, 0.85)   # Dark sci-fi tone

	c.add_child(bg)

	# Push behind everything
	bg.z_index = -1

	state.action_storage["bg"] = bg

	return c
	

# ╔══════════════════════════════════════════════════════════╗
# ║           CREATE ACTION BACKGROUND (ALT PATH)           ║
# ╠══════════════════════════════════════════════════════════╣
# ║ Separate helper that ONLY creates the background.       ║
# ║                                                        ║
# ║ NOTE: You already do this in _create_action_root().      ║
# ║ This appears to be an alternate or legacy path.         ║
# ╚══════════════════════════════════════════════════════════╝
func create_action_background(parent: Control) -> void:

	var bg = ColorRect.new()
	bg.name = "Action_BG"
	bg.position = Vector2(0, 0)
	bg.size = parent.size
	bg.color = Color(0.05, 0.05, 0.08, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	parent.add_child(bg)
	bg.z_index = -1

	state.action_storage["bg"] = bg
	
	
# ╔══════════════════════════════════════════════════════════╗
# ║          REFRESH ACTIONS FROM INVENTORY                 ║
# ╠══════════════════════════════════════════════════════════╣
# ║ Rebuilds the action buttons dynamically based on:       ║
# ║   - Inventory contents                                 ║
# ║   - Scan results (asteroids found)                     ║
# ╚══════════════════════════════════════════════════════════╝


#this is a function for when to build non_inventory buttons:


func refresh_actions_from_inventory() -> void:

	if Globals.print_priority_3:
		print("=== REFRESH ACTIONS CALLED ===")
	
	# Safety check: inventory must exist
	if inventory == null:
		if Globals.print_priority_2:
			print("Cannot refresh actions. Inventory missing.")
		return

	# Safety check: button list must exist
	if not state.action_storage.has("button_list"):
		if Globals.print_priority_2:
			print("Cannot refresh actions. Button list missing.")
		return

	var button_list: VBoxContainer = state.action_storage["button_list"]

	# ──────────────────────────────────────────────────────
	# CLEAR OLD BUTTONS
	# ──────────────────────────────────────────────────────
	for child in button_list.get_children():
		child.queue_free()
	for button_key in state.buttons.keys():
		if str(button_key).begins_with("action_button_"):
			state.buttons.erase(button_key)
	if Globals.battle_pending:
		return

	if Globals.engage_enemy and not engage_enemy_in_progress and not Globals.battle_mode:
		if Globals.print_priority_2:
			print("Enemy engage flag was stale during action refresh. Clearing Globals.engage_enemy.")
		Globals.engage_enemy = false

	var navigation_lock_active := has_navigation_lock_todo()


	# ──────────────────────────────────────────────────────
	# SCAN ACTION (unlocked by scan module)
	# ──────────────────────────────────────────────────────
	
	
	if inventory.has_item_anywhere("scan_module_mk1") and (auto_pilot == null or not (auto_pilot.enabled and auto_pilot.mode == "warp")) and not Globals.engage_enemy and not Globals.scan_was_clicked and not mining_in_progress and not navigation_lock_active:
		add_action_button("scan_local", "Scan Local") 

	add_local_mining_action_buttons()

	var enemy_action_block_reason := get_enemy_action_population_block_reason()
	if enemy_action_block_reason == "":

		update_scanned_enemy_distances()
		for enemy_data in scanned_enemies:
			var enemy = enemy_data.get("enemy", null)

			if enemy != null:
				var enemy_distance := get_scanned_enemy_distance(enemy_data, enemy)
				if enemy_distance > ACTION_SCAN_RANGE:
					continue
				if enemy_distance <= ENEMY_BATTLE_RANGE:
					if Globals.print_priority_2:
						print("[ACTION_ENEMY_BUTTON] Battle button shown enemy=", str(enemy.enemy_name), " dist=", enemy_distance, " range=", ENEMY_BATTLE_RANGE)
					add_action_button("engage_scanned_enemy", "Battle " + str(enemy.enemy_name), {"enemy_data": enemy_data})
				else:
					if Globals.print_priority_2:
						print("[ACTION_ENEMY_BUTTON] Engage button shown enemy=", str(enemy.enemy_name), " dist=", enemy_distance, " battle_range=", ENEMY_BATTLE_RANGE)
					add_action_button("approach_enemy", "Engage " + str(enemy.enemy_name) + " : " + str(round(enemy_distance)), {"enemy_data": enemy_data})
			elif Globals.print_priority_2:
				print("Enemy action blocked - scanned enemy packet has no enemy ref.")
	elif not scanned_enemies.is_empty() and Globals.print_priority_2:
		print(
			"Enemy action population blocked: ",
			enemy_action_block_reason,
			" | scanned=", scanned_enemies.size(),
			" scan_in_progress=", scan_in_progress,
			" engage_in_progress=", engage_enemy_in_progress,
			" battle_mode=", Globals.battle_mode,
			" battle_pending=", Globals.battle_pending,
			" autopilot_enabled=", auto_pilot != null and auto_pilot.enabled
		)
	if not Globals.battle_mode and not Globals.battle_pending and not Globals.engage_enemy and not scan_in_progress:
		update_scanned_npc_order()
		for talk_npc in scanned_npcs:
			if talk_npc == null:
				continue
			var npc_distance := get_scanned_npc_distance(talk_npc)
			if npc_distance > ACTION_SCAN_RANGE:
				continue
			add_action_button("talk_npc", "Link Call: [" + talk_npc.npc_name + "] : " + str(round(npc_distance)), build_talk_npc_action_payload(talk_npc))

		update_scanned_event_target_distances()
		for event_packet in scanned_event_targets:
			var event_distance := float(event_packet.get("distance", 999999.0))
			if event_distance > ACTION_SCAN_RANGE:
				continue
			add_action_button(
				"select_scanned_event",
				"Event: " + str(event_packet.get("display_name", event_packet.get("event_id", "Event"))) + " : " + str(round(event_distance)),
				{"event_packet": event_packet}
			)
		
	# Mining buttons are intentionally added immediately after Scan Local above.
		

	# ──────────────────────────────────────────────────────
	# MINING ACTION (requires drone + scanned asteroids)
	# ──────────────────────────────────────────────────────
	# Debug info
	if Globals.debug_heat_1:
		if Globals.print_priority_3:
			print("ACTION STORAGE:", state.action_storage)
		if Globals.print_priority_3:
			print("HAS MINER DRONE?: ", inventory.has_item_anywhere("miner_drone_mk1"))
# ╔══════════════════════════════════════════════════════════╗
# ║                  ADD ACTION BUTTON                      ║
# ╠══════════════════════════════════════════════════════════╣
# ║ Creates a clickable button and wires it to run_action.  ║
# ╚══════════════════════════════════════════════════════════╝
func add_local_mining_action_buttons() -> void:
	if has_navigation_lock_todo():
		return

	update_scanned_asteroid_distances()
	var should_approach := should_show_approach_asteroid()

	if inventory.has_item_anywhere("miner_drone_mk1") \
	and scanned_mineable_asteroids.size() > 0 \
	and not should_approach \
	and not mining_in_progress and show_mine_action and not Globals.engage_enemy and not scan_in_progress:
		add_action_button("mine_asteroid", "Mine Local")

	if should_approach and not Globals.engage_enemy and not scan_in_progress:
		add_action_button("approach", "Approach asteroid : " + str(round(scanned_mineable_asteroids[0]["distance"])))
		show_mine_action = true


func add_action_button(action_id: String, text: String, action_payload: Dictionary = {}) -> void:
	var autopilot_blocks := auto_pilot != null and auto_pilot.enabled
	var popup_blocks := Globals.is_popup_input_locked()
	var navigation_lock_blocks := has_navigation_lock_todo()
	var button_list: VBoxContainer = state.action_storage["button_list"]

	var btn := Button.new()
	var button_index := button_list.get_child_count()
	btn.name = "action_button_" + action_id + "_" + str(button_index)
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 35)
	btn.disabled = autopilot_blocks or popup_blocks or navigation_lock_blocks
	btn.set_meta("controller_focus_id", "action:" + action_id + ":" + str(button_index))
	btn.set_meta("controller_action_id", action_id)
	btn.set_meta("controller_action_payload", action_payload.duplicate(true))
	if popup_blocks:
		btn.tooltip_text = "Tutorial active"
	elif navigation_lock_blocks:
		btn.tooltip_text = get_navigation_lock_message("Action")
	else:
		btn.tooltip_text = "Autopilot active" if autopilot_blocks else ""

	# Connect click to run_action(action_id)
	btn.pressed.connect(run_action.bind(action_id, action_payload))

	button_list.add_child(btn)
	state.buttons[btn.name] = btn


func build_talk_npc_action_payload(talk_npc: NPC) -> Dictionary:
	# Summary: Preserve the exact NPC identity for Link Call buttons.
	if talk_npc == null or not is_instance_valid(talk_npc):
		return {}

	return {
		"npc": talk_npc,
		"npc_id": get_action_npc_id(talk_npc),
		"blueprint_id": str(talk_npc.get_meta("blueprint_id", "")),
		"name": talk_npc.npc_name,
		"sector": talk_npc.sector_pos,
		"local": talk_npc.local_pos
	}


func resolve_talk_npc_from_payload(action_payload: Dictionary) -> NPC:
	# Summary: Resolve the clicked Link Call target without falling back to the closest NPC.
	var direct_ref = action_payload.get("npc", null)
	if direct_ref != null and is_instance_valid(direct_ref):
		var direct_npc := direct_ref as NPC
		if direct_npc != null:
			return direct_npc

	var wanted_npc_id := str(action_payload.get("npc_id", "")).strip_edges()
	var wanted_sector := read_live_map_target_sector(action_payload)
	var wanted_local := read_live_map_target_local(action_payload)
	var has_position := action_payload.has("sector") or action_payload.has("sector_pos")

	var scanned_match := find_matching_talk_npc(scanned_npcs, wanted_npc_id, wanted_sector, wanted_local, has_position)
	if scanned_match != null:
		return scanned_match

	if npc_handler != null:
		return find_matching_talk_npc(npc_handler.npcs, wanted_npc_id, wanted_sector, wanted_local, has_position)

	return null


func find_matching_talk_npc(npc_list: Array, wanted_npc_id: String, wanted_sector: Vector3i, wanted_local: Vector3, has_position: bool) -> NPC:
	for npc in npc_list:
		if npc == null or not is_instance_valid(npc):
			continue
		var typed_npc := npc as NPC
		if typed_npc == null:
			continue
		var current_npc_id := get_action_npc_id(typed_npc)
		if wanted_npc_id != "" and current_npc_id == wanted_npc_id:
			return typed_npc
		if has_position and typed_npc.sector_pos == wanted_sector and typed_npc.local_pos.distance_to(wanted_local) <= 1.0:
			return typed_npc

	return null


func get_action_npc_id(npc: NPC) -> String:
	if npc == null or not is_instance_valid(npc):
		return ""
	if npc_handler != null and npc_handler.has_method("get_npc_id"):
		return str(npc_handler.get_npc_id(npc)).strip_edges()
	var npc_id := str(npc.get_meta("npc_id", "")).strip_edges()
	if npc_id == "":
		npc_id = str(npc.object_id).strip_edges()
	return npc_id


func get_first_talkable_scanned_npc() -> NPC:

	for npc in scanned_npcs:
		if npc != null:
			return npc

	return null


func get_enemy_action_population_block_reason() -> String:
	# Summary: Explain why the scanned enemy action should not populate right now.
	if Globals.battle_mode:
		return "battle_mode"
	if Globals.battle_pending:
		return "battle_pending"
	if engage_enemy_in_progress:
		return "engage_enemy_in_progress"
	if scan_in_progress:
		return "scan_in_progress"
	if has_navigation_lock_todo():
		return "task_navigation_lock"
	if scanned_enemies.is_empty():
		return "no_scanned_enemies"
	if auto_pilot != null and auto_pilot.enabled:
		# Keep the near-enemy battle state visible once the ship reaches contact range.
		# add_action_button() still disables clicks while autopilot is actively running,
		# but the button no longer disappears during the handoff frame.
		update_scanned_enemy_distances()
		for enemy_data in scanned_enemies:
			var enemy = enemy_data.get("enemy", null)
			if enemy == null:
				continue
			if get_scanned_enemy_distance(enemy_data, enemy) <= ENEMY_BATTLE_RANGE:
				if Globals.print_priority_2:
					print("[ACTION_ENEMY_BLOCK_BYPASS] autopilot still on, but enemy is in battle range: ", str(enemy.enemy_name))
				return ""
		return "autopilot_enabled"

	return ""


func get_enemy_action_payload_data(action_payload: Dictionary) -> Dictionary:
	var payload_enemy_data = action_payload.get("enemy_data", {})
	if typeof(payload_enemy_data) == TYPE_DICTIONARY and not payload_enemy_data.is_empty():
		return payload_enemy_data

	if scanned_enemies.is_empty():
		return {}

	return scanned_enemies[0]


func update_scanned_enemy_distances() -> void:
	if scanned_enemies.is_empty():
		return

	for i in range(scanned_enemies.size() - 1, -1, -1):
		var data = scanned_enemies[i]
		if typeof(data) != TYPE_DICTIONARY:
			scanned_enemies.remove_at(i)
			continue

		var enemy = data.get("enemy", null)
		if enemy == null or not is_instance_valid(enemy):
			scanned_enemies.remove_at(i)
			continue

		data["distance"] = map.get_distance_to_target(enemy.sector_pos, enemy.local_pos) if map != null else float(data.get("distance", 999999.0))

	scanned_enemies.sort_custom(func(a, b):
		return float(a.get("distance", 999999.0)) < float(b.get("distance", 999999.0))
	)


func get_scanned_npc_distance(npc) -> float:
	if npc != null and is_instance_valid(npc) and map != null:
		return map.get_distance_to_target(npc.sector_pos, npc.local_pos)
	return 999999.0


func update_scanned_npc_order() -> void:
	if scanned_npcs.is_empty():
		return

	for i in range(scanned_npcs.size() - 1, -1, -1):
		var npc = scanned_npcs[i]
		if npc == null or not is_instance_valid(npc):
			scanned_npcs.remove_at(i)

	scanned_npcs.sort_custom(func(a, b):
		return get_scanned_npc_distance(a) < get_scanned_npc_distance(b)
	)


func get_game_event_handler():
	if state == null:
		return null
	return state.game_event_handler


func collect_scanned_event_targets(scan_range: float = ACTION_SCAN_RANGE) -> void:
	scanned_event_targets.clear()

	var game_events = get_game_event_handler()
	if game_events == null:
		return

	if "active_events" in game_events:
		append_scanned_event_targets_from_map(game_events.active_events, "active", scan_range, game_events)
	if "available_events" in game_events:
		append_scanned_event_targets_from_map(game_events.available_events, "available", scan_range, game_events)

	update_scanned_event_target_distances()


func append_scanned_event_targets_from_map(source: Dictionary, state_label: String, scan_range: float, game_events) -> void:
	for event_id in source.keys():
		var event_data = source[event_id]
		if typeof(event_data) != TYPE_DICTIONARY:
			continue
		var runtime_state := str(event_data.get("event_state", "")).strip_edges().to_lower()
		if runtime_state == "completed" or str(event_data.get("current_step", "")) == "completed" or bool(event_data.get("completed", false)):
			continue
		if has_scanned_event_target(str(event_id)):
			continue
		if not game_events.has_method("build_event_widget_packet"):
			continue

		var widget_packet: Dictionary = game_events.build_event_widget_packet(event_data)
		var target = widget_packet.get("target", {})
		if typeof(target) != TYPE_DICTIONARY or target.is_empty():
			continue

		var target_sector := read_live_map_target_sector(target)
		var target_local := read_live_map_target_local(target)
		var distance := map.get_distance_to_target(target_sector, target_local) if map != null else 999999.0
		if distance > scan_range:
			continue

		widget_packet["event_id"] = str(widget_packet.get("event_id", event_id))
		widget_packet["event_state"] = state_label
		widget_packet["target"] = target
		widget_packet["distance"] = distance
		scanned_event_targets.append(widget_packet)


func has_scanned_event_target(event_id: String) -> bool:
	for event_packet in scanned_event_targets:
		if typeof(event_packet) == TYPE_DICTIONARY and str(event_packet.get("event_id", "")) == event_id:
			return true
	return false


func update_scanned_event_target_distances() -> void:
	if scanned_event_targets.is_empty():
		return

	for i in range(scanned_event_targets.size() - 1, -1, -1):
		var event_packet = scanned_event_targets[i]
		if typeof(event_packet) != TYPE_DICTIONARY:
			scanned_event_targets.remove_at(i)
			continue

		var target = event_packet.get("target", {})
		if typeof(target) != TYPE_DICTIONARY or target.is_empty():
			scanned_event_targets.remove_at(i)
			continue

		var target_sector := read_live_map_target_sector(target)
		var target_local := read_live_map_target_local(target)
		event_packet["distance"] = map.get_distance_to_target(target_sector, target_local) if map != null else float(event_packet.get("distance", 999999.0))

	scanned_event_targets.sort_custom(func(a, b):
		return float(a.get("distance", 999999.0)) < float(b.get("distance", 999999.0))
	)


func run_scanned_event_action(action_payload: Dictionary) -> void:
	var event_packet = action_payload.get("event_packet", {})
	if typeof(event_packet) != TYPE_DICTIONARY or event_packet.is_empty():
		if Globals.print_priority_2:
			print("Event action blocked - missing event packet.")
		return

	var event_id := str(event_packet.get("event_id", ""))
	var game_events = get_game_event_handler()
	if game_events != null and game_events.has_method("handle_event_widget_action") and event_id != "":
		game_events.handle_event_widget_action({
			"action_id": "select_event",
			"event_id": event_id,
			"target_event_id": event_id
		})

	var target = event_packet.get("target", {})
	if typeof(target) != TYPE_DICTIONARY or target.is_empty():
		if state != null and state.log_storage.has("log_text"):
			state.log_storage["log_text"].text = "Event selected: " + str(event_packet.get("display_name", event_id))
		refresh_actions_from_inventory()
		return

	if auto_pilot == null:
		if state != null and state.log_storage.has("log_text"):
			state.log_storage["log_text"].text = "Event selected, but autopilot is not connected."
		refresh_actions_from_inventory()
		return

	if has_navigation_lock_todo():
		block_navigation_action_for_todo("Event autopilot")
		refresh_actions_from_inventory()
		return

	var target_sector := read_live_map_target_sector(target)
	var target_local := read_live_map_target_local(target)
	var target_name := str(target.get("display_name", event_packet.get("display_name", "Event Target")))
	var target_kind := str(target.get("owner_type", target.get("object_type", "target"))).strip_edges().to_lower()
	var target_type := "event_" + target_kind if target_kind != "" else "event"

	state.use_auto_pilot = false
	auto_pilot.set_impulse_target(target_sector, target_local, target_name, target_type)

	if state != null and state.log_storage.has("log_text"):
		state.log_storage["log_text"].text = (
			"Event target selected:\n"
			+ str(event_packet.get("display_name", event_id)) + "\n"
			+ "Target: " + target_name + "\n"
			+ "Distance: " + str(round(float(event_packet.get("distance", 0.0))))
		)

	refresh_actions_from_inventory()


func run_live_map_target_autopilot(packet: Dictionary = {}) -> Dictionary:
	# Summary: Start coordinate autopilot from a Live Map marker without depending on star-button state.
	var source_packet := packet.duplicate(true)
	if source_packet.is_empty() and typeof(Globals.live_map_target_pos) == TYPE_ARRAY and Globals.live_map_target_pos.size() >= 2:
		source_packet = {
			"sector_pos": Globals.live_map_target_pos[0],
			"local_pos": Globals.live_map_target_pos[1],
			"display_name": "Live Map Target",
			"type": "manual"
		}

	var cache_synced := false
	if not source_packet.is_empty():
		cache_synced = sync_live_map_target_to_action_cache(source_packet, false)

	var result := {
		"status": "failed",
		"reason": "",
		"labels": ["live_map_target_autopilot"],
		"data": {}
	}

	if has_navigation_lock_todo():
		result["reason"] = "task_navigation_lock"
		result["data"] = {
			"task": get_navigation_lock_todo_text()
		}
		block_navigation_action_for_todo("Auto pilot")
		return result

	if source_packet.is_empty():
		result["reason"] = "missing live map target packet"
		if Globals.print_priority_2:
			print("Live Map auto target blocked - no target packet.")
		return result

	if auto_pilot == null:
		result["reason"] = "autopilot missing"
		if Globals.print_priority_2:
			print("Live Map auto target blocked - auto_pilot missing.")
		return result

	var target_sector := read_live_map_target_sector(source_packet)
	var target_local := read_live_map_target_local(source_packet)
	var target_name := str(source_packet.get("display_name", source_packet.get("id", "Live Map Target")))
	var target_type := resolve_live_map_target_type(source_packet)

	Globals.live_map_target_pos = [target_sector, target_local]
	Globals.live_map_is_guided = true
	Globals.scan_was_clicked = false
	Globals.target_star_button = ""
	Globals.target_star_button_run = false
	Globals.update_star_button_red = false

	auto_pilot.set_impulse_target(target_sector, target_local, target_name, target_type)

	if state != null:
		state.use_auto_pilot = false
		if state.log_storage.has("log_text"):
			state.log_storage["log_text"].text = (
				"Auto to target:\n"
				+ target_name + "\n"
				+ "Type: " + target_type + "\n"
				+ "Sector: " + str(target_sector) + "\n"
				+ "Local: " + str(target_local)
			)

	refresh_actions_from_inventory()

	result["status"] = "success"
	result["reason"] = ""
	result["labels"].append("live_map_target_autopilot_started")
	result["data"] = {
		"target_name": target_name,
		"target_type": target_type,
		"sector_pos": target_sector,
		"local_pos": target_local,
		"cache_synced": cache_synced
	}

	if Globals.print_priority_2 or Globals.debug_radar:
		print("Live Map auto target started: ", result["data"])

	return result


func sync_live_map_target_to_action_cache(packet: Dictionary, refresh_actions: bool = true) -> bool:
	# Summary: Let Live Map object clicks hydrate the same asteroid cache used by action scan buttons.
	if typeof(packet) != TYPE_DICTIONARY or packet.is_empty():
		return false

	var marker_type := str(packet.get("type", "")).strip_edges().to_lower()
	var data_slice: Dictionary = {}
	if typeof(packet.get("data_slice", {})) == TYPE_DICTIONARY:
		data_slice = packet.get("data_slice", {})

	var object_type := resolve_live_map_target_type(packet)
	if marker_type != "object" and object_type != "asteroid":
		return false
	if object_type != "asteroid":
		return false

	var asteroid := find_space_object_for_live_map_packet(packet, data_slice)
	if asteroid.is_empty():
		return false
	if bool(asteroid.get("mined_out", false)):
		remove_scanned_asteroid_by_id(str(asteroid.get("object_id", asteroid.get("id", ""))))
		if refresh_actions:
			refresh_actions_from_inventory()
		return false

	upsert_scanned_asteroid(asteroid)
	Globals.scan_was_clicked = false
	if refresh_actions:
		refresh_actions_from_inventory()
	return true


func resolve_live_map_target_type(packet: Dictionary) -> String:
	# Summary: Prefer the Space_Objects type stored inside Live Map object packets.
	var marker_type := str(packet.get("type", "")).strip_edges().to_lower()
	var data_slice: Dictionary = {}
	if typeof(packet.get("data_slice", {})) == TYPE_DICTIONARY:
		data_slice = packet.get("data_slice", {})

	var object_type := str(data_slice.get("object_type", packet.get("object_type", ""))).strip_edges().to_lower()
	if marker_type == "object" and object_type != "":
		return object_type
	if marker_type != "":
		return marker_type
	if object_type != "":
		return object_type
	return "manual"


func find_space_object_for_live_map_packet(packet: Dictionary, data_slice: Dictionary) -> Dictionary:
	if space_objects == null:
		return {}

	var ids := [
		str(packet.get("object_id", "")),
		str(packet.get("id", "")),
		str(data_slice.get("object_id", "")),
		str(data_slice.get("id", ""))
	]

	if space_objects.has_method("get_object_by_id"):
		for object_id in ids:
			if object_id.strip_edges() == "":
				continue
			var found: Dictionary = space_objects.get_object_by_id(object_id)
			if not found.is_empty():
				return found

	var target_sector := read_live_map_target_sector(packet)
	var target_local := read_live_map_target_local(packet)
	var local_objects: Array = []
	if space_objects.has_method("get_objects_in_sector"):
		local_objects = space_objects.get_objects_in_sector(target_sector)

	for obj in local_objects:
		if typeof(obj) != TYPE_DICTIONARY:
			continue
		if str(obj.get("object_type", "")) != "asteroid":
			continue
		if not obj.has("local_pos"):
			continue
		var obj_local: Vector3 = read_live_map_target_local({"local_pos": obj.get("local_pos", Vector3.ZERO)})
		if obj_local.distance_to(target_local) <= 0.1:
			return obj

	return {}


func upsert_scanned_asteroid(asteroid: Dictionary) -> void:
	var asteroid_id := str(asteroid.get("object_id", asteroid.get("id", "")))
	var distance := map.get_distance_to_target(
		read_live_map_target_sector({"sector_pos": asteroid.get("sector_pos", map.sector_pos)}),
		read_live_map_target_local({"local_pos": asteroid.get("local_pos", Vector3.ZERO)})
	) if map != null else 0.0

	for data in scanned_mineable_asteroids:
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var existing = data.get("object", null)
		if typeof(existing) != TYPE_DICTIONARY:
			continue
		var existing_id := str(existing.get("object_id", existing.get("id", "")))
		if asteroid_id != "" and existing_id == asteroid_id:
			data["object"] = asteroid
			data["distance"] = distance
			update_scanned_asteroid_distances()
			return
		if existing == asteroid:
			data["distance"] = distance
			update_scanned_asteroid_distances()
			return

	scanned_mineable_asteroids.append({
		"object": asteroid,
		"distance": distance
	})
	update_scanned_asteroid_distances()


func remove_scanned_asteroid_by_id(asteroid_id: String) -> void:
	if asteroid_id.strip_edges() == "":
		return

	for i in range(scanned_mineable_asteroids.size() - 1, -1, -1):
		var data = scanned_mineable_asteroids[i]
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var asteroid = data.get("object", null)
		if typeof(asteroid) != TYPE_DICTIONARY:
			continue
		var existing_id := str(asteroid.get("object_id", asteroid.get("id", "")))
		if existing_id == asteroid_id:
			scanned_mineable_asteroids.remove_at(i)


func read_live_map_target_sector(packet: Dictionary) -> Vector3i:
	# Summary: Read sector position from a Live Map packet or save-safe dictionary.
	var value = packet.get("sector_pos", packet.get("sector", Vector3i.ZERO))
	if value is Vector3i:
		return value
	if value is Vector3:
		return Vector3i(int(value.x), int(value.y), int(value.z))
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3i(
			int(value.get("x", 0)),
			int(value.get("y", 0)),
			int(value.get("z", 0))
		)
	return Vector3i.ZERO


func read_live_map_target_local(packet: Dictionary) -> Vector3:
	# Summary: Read local position from a Live Map packet or save-safe dictionary.
	var value = packet.get("local_pos", packet.get("local", Vector3.ZERO))
	if value is Vector3:
		return value
	if value is Vector3i:
		return Vector3(value.x, value.y, value.z)
	if typeof(value) == TYPE_ARRAY and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector3(
			float(value.get("x", 0.0)),
			float(value.get("y", 0.0)),
			float(value.get("z", 0.0))
		)
	return Vector3.ZERO


func get_scanned_enemy_distance(enemy_data: Dictionary, enemy) -> float:
	# Summary: Read the live distance for the scanned enemy, falling back to the scan snapshot.
	if enemy != null and map != null:
		return map.get_distance_to_target(enemy.sector_pos, enemy.local_pos)

	return float(enemy_data.get("distance", 999999.0))


func queue_scanned_enemy_battle_entry(enemy) -> void:
	# Summary: Queue the short final battle-entry TODO after the player is already in contact range.
	if enemy == null:
		return

	if event_handler == null:
		if Globals.print_priority_2:
			print("Battle entry blocked - event_handler missing.")
		return

	Globals.engage_enemy = true
	Globals.current_enemy = enemy
	engage_enemy_in_progress = true

	if Globals.print_priority_2:
		print("[ACTION_ENEMY_QUEUE_BATTLE] enemy=", str(enemy.enemy_name), " countdown=", ENEMY_BATTLE_ENTRY_SECONDS)

	state.log_storage["log_text"].text = "Battle link established with " + str(enemy.enemy_name) + "..."
	refresh_actions_from_inventory()

	event_handler.add_event(
		"Battle " + str(enemy.enemy_name) + "...",
		ENEMY_BATTLE_ENTRY_SECONDS,
		"engage_enemy",
		{
			"enemy": enemy
		}
	)


func build_npc_scene_request_packet(talk_npc: NPC) -> Dictionary:
	# Summary: Build the minimal NPCSceneBridge lookup packet. The bridge hydrates the full scene packet.
	if talk_npc == null:
		return {}

	var npc_id := ""
	if npc_handler != null and npc_handler.has_method("get_npc_id"):
		npc_id = str(npc_handler.get_npc_id(talk_npc))
	else:
		npc_id = str(talk_npc.get_meta("npc_id", ""))

	return {
		"npc_id": npc_id,
		"blueprint_id": str(talk_npc.get_meta("blueprint_id", "")),
		"name": talk_npc.npc_name,
		"sector": talk_npc.sector_pos,
		"local": talk_npc.local_pos
	}


# ╔══════════════════════════════════════════════════════════╗
# ║                    MINE ASTEROID                        ║
# ╠══════════════════════════════════════════════════════════╣
# ║ Takes the closest scanned asteroid and extracts iron.   ║
# ║                                                        ║
# ║ Flow:                                                  ║
# ║   1. Save game                                         ║
# ║   2. Validate scan results                             ║
# ║   3. Find closest asteroid                             ║
# ║   4. Extract iron                                      ║
# ║   5. Update inventory                                  ║
# ║   6. Mark asteroid depleted                            ║
# ║   7. Refresh UI                                        ║
# ╚══════════════════════════════════════════════════════════╝
func get_mining_item_data(item_id: String) -> Dictionary:
	if inventory == null or inventory.item_handler == null:
		return {}
	if not inventory.item_handler.has_item(item_id):
		return {}

	var item_data: Dictionary = inventory.item_handler.get_item_data(item_id)
	if typeof(item_data) != TYPE_DICTIONARY:
		return {}
	return item_data


func is_mineable_resource_id(item_id: String) -> bool:
	var clean_item_id := item_id.strip_edges()
	if clean_item_id == "":
		return false

	var item_data := get_mining_item_data(clean_item_id)
	if item_data.is_empty():
		return false

	var data_type := str(item_data.get("type", item_data.get("item_type", ""))).strip_edges().to_lower()
	var item_type := str(item_data.get("item_type", item_data.get("type", ""))).strip_edges().to_lower()
	if data_type == "resource" or item_type == "resource":
		return true

	var labels = item_data.get("labels", [])
	if typeof(labels) == TYPE_ARRAY:
		for label in labels:
			var clean_label := str(label).strip_edges().to_lower()
			if clean_label == "resource" or clean_label == "space_material" or clean_label == "crafting_material":
				return true

	return false


func format_mining_item_fallback_name(item_id: String) -> String:
	var display := ""
	for raw_word in item_id.replace("_", " ").split(" ", false):
		var word := str(raw_word).strip_edges()
		if word == "":
			continue
		if display != "":
			display += " "
		display += word.substr(0, 1).to_upper() + word.substr(1).to_lower()
	return display if display != "" else item_id


func get_mining_item_display_name(item_id: String) -> String:
	var item_data := get_mining_item_data(item_id)
	var display := str(item_data.get("display_name", item_data.get("name", ""))).strip_edges()
	if display != "":
		return display
	return format_mining_item_fallback_name(item_id)


func get_sorted_mining_resource_ids(resource_amounts: Dictionary) -> Array:
	var resource_ids := []
	for item_id in resource_amounts.keys():
		resource_ids.append(str(item_id))
	resource_ids.sort()
	return resource_ids


func get_asteroid_resource_amounts(asteroid: Dictionary) -> Dictionary:
	var resource_amounts := {}
	var resource_ids_from_fields := {}

	for raw_key in asteroid.keys():
		var key := str(raw_key)
		if not key.ends_with(ASTEROID_RESOURCE_LEFT_SUFFIX):
			continue

		var item_id := key.substr(0, key.length() - ASTEROID_RESOURCE_LEFT_SUFFIX.length()).strip_edges()
		if not is_mineable_resource_id(item_id):
			continue

		var amount := int(asteroid.get(key, 0))
		if amount <= 0:
			continue

		resource_amounts[item_id] = amount
		resource_ids_from_fields[item_id] = true

	var direct_resources = asteroid.get("resources_left", {})
	if typeof(direct_resources) == TYPE_DICTIONARY:
		for raw_item_id in direct_resources.keys():
			var item_id := str(raw_item_id).strip_edges()
			if resource_ids_from_fields.has(item_id):
				continue
			if not is_mineable_resource_id(item_id):
				continue

			var amount := int(direct_resources.get(raw_item_id, 0))
			if amount <= 0:
				continue
			resource_amounts[item_id] = amount

	return resource_amounts


func grant_mining_resources(resource_amounts: Dictionary) -> Dictionary:
	var granted_amounts := {}
	if inventory == null:
		return granted_amounts

	for item_id in get_sorted_mining_resource_ids(resource_amounts):
		var amount := int(resource_amounts.get(item_id, 0))
		if amount <= 0:
			continue
		if inventory.add_item(item_id, amount):
			granted_amounts[item_id] = amount
	return granted_amounts


func deplete_granted_asteroid_resources(asteroid: Dictionary, granted_amounts: Dictionary) -> void:
	for item_id in granted_amounts.keys():
		var key := str(item_id) + ASTEROID_RESOURCE_LEFT_SUFFIX
		if asteroid.has(key):
			asteroid[key] = 0

	var direct_resources = asteroid.get("resources_left", {})
	if typeof(direct_resources) == TYPE_DICTIONARY:
		for item_id in granted_amounts.keys():
			if direct_resources.has(item_id):
				direct_resources[item_id] = 0
		asteroid["resources_left"] = direct_resources

	asteroid["mined_out"] = get_asteroid_resource_amounts(asteroid).is_empty()


func build_mining_resource_lines(resource_amounts: Dictionary) -> Array:
	var lines := []
	for item_id in get_sorted_mining_resource_ids(resource_amounts):
		var amount := int(resource_amounts.get(item_id, 0))
		if amount <= 0:
			continue
		lines.append(get_mining_item_display_name(item_id) + " mined: " + str(amount))
	return lines


func build_mining_resource_reward_packets(resource_amounts: Dictionary) -> Array:
	var rewards := []
	for item_id in get_sorted_mining_resource_ids(resource_amounts):
		var amount := int(resource_amounts.get(item_id, 0))
		if amount <= 0:
			continue
		rewards.append({
			"item_id": str(item_id),
			"display_name": get_mining_item_display_name(item_id),
			"amount": amount
		})
	return rewards


func mine_asteroid() -> void:

	# Save before doing anything risky
	#if save_manager != null:
		#save_world_with_events()

	# No asteroids available → fail
	if scanned_mineable_asteroids.is_empty():
		state.log_storage["log_text"].text = "MINING FAILED\nNo scanned asteroids available."
		refresh_actions_from_inventory()
		show_mine_action = false
		scanned_mineable_asteroids.clear()
		return

	update_scanned_asteroid_distances()

	# Assume first is closest, then refine
	# ==========================================================
# FIND CLOSEST ASTEROID
# ==========================================================
# ==========================================================
# FIND CLOSEST ASTEROID
# ==========================================================
	var closest = scanned_mineable_asteroids[0]

	for data in scanned_mineable_asteroids:
		if data["distance"] < closest["distance"]:
			closest = data

	# NOW get correct distance
	var distance = closest["distance"]
	var asteroid = closest["object"]

	# ==========================================================
	# NOT IN RANGE → ENGAGE IMPULSE AUTOPILOT
	# ==========================================================
	
	
	###>>>>>>>>>>>placeholder>>>removed not in rage block and put in function  asteroid_not_in_range():

	# Extract asteroid data

	var resource_amounts := get_asteroid_resource_amounts(asteroid)
	if Globals.print_priority_3:
		print(str(asteroid))
	
	# Already mined → fail
	# Already mined → fail only if ALL resources are empty
	if resource_amounts.is_empty():
		space_objects.objects.erase(asteroid)
		# Mining autosave disabled for this reward-display pass.
		#if save_manager != null:
			#save_world_with_events()

		state.log_storage["log_text"].text = "MINING FAILED\nAsteroid already depleted."
		show_mine_action = false
		scanned_mineable_asteroids.clear()
		refresh_actions_from_inventory()
		return


	if Globals.print_priority_3:
		print("ASTEROID RESOURCES: ", resource_amounts)

	var granted_amounts := grant_mining_resources(resource_amounts)
	if granted_amounts.is_empty():
		state.log_storage["log_text"].text = "MINING FAILED\nCargo inventory could not receive asteroid resources."
		refresh_actions_from_inventory()
		return

	deplete_granted_asteroid_resources(asteroid, granted_amounts)

	
	# Write result to log and emit the reward packet for the main-screen gain feed.
	# ==========================================================
# WRITE RESULT TO LOG
# ==========================================================
	# ==========================================================
# SHOW MINING RESULT
# ==========================================================
	var resource_lines := build_mining_resource_lines(granted_amounts)
	var mining_message := "MINING COMPLETE\n"
	mining_message += "Target: " + str(asteroid.get("scan_name", "Asteroid")) + "\n"
	mining_message += "Distance: " + str(int(closest["distance"])) + "\n"
	for line in resource_lines:
		mining_message += str(line) + "\n"
	mining_message += "Asteroid depleted." if bool(asteroid.get("mined_out", false)) else "Remaining resources still detected."

	if state != null and state.log_storage.has("log_text"):
		state.log_storage["log_text"].text = mining_message

	# Remove mined asteroid from scan cache.
	scanned_mineable_asteroids.erase(closest)
	show_mine_action = false
	refresh_actions_from_inventory()

	# Mining autosave disabled for this reward-display pass.
	#if save_manager != null:
		#save_world_with_events()
	mining_completed.emit({
		"reason": "mine_asteroid",
		"sector_pos": map.sector_pos if map != null else Vector3i.ZERO,
		"local_pos": map.local_pos if map != null else Vector3.ZERO,
		"target": str(asteroid.get("object_id", asteroid.get("scan_name", "Asteroid"))),
		"target_name": str(asteroid.get("scan_name", "Asteroid")),
		"distance": int(closest["distance"]),
		"resource_amounts": granted_amounts.duplicate(true),
		"resource_rewards": build_mining_resource_reward_packets(granted_amounts),
		"resource_lines": resource_lines.duplicate(true),
		"mined_out": bool(asteroid.get("mined_out", false)),
		"message": mining_message
	})

func scan_asteroids_in_sector() -> String:
	var log_text := ''
	# Clear previous scan results
	#scanned_mineable_asteroids.clear()

	if space_objects == null:
		if Globals.print_priority_3:
			print("No space_objects found.")
		log_text += "No space_objects found." +'\n'
		return log_text

	var local_objects = space_objects.get_objects_in_sector(map.sector_pos)
	
	if local_objects.is_empty():
		if Globals.print_priority_3:
			print("No asteroids or objects found.")
		log_text += "No asteroids or objects found."  +'\n'
		return log_text

	for obj in local_objects:

		# Skip mined out
		if obj.get("mined_out", false) == true:
			continue

		# Only care about asteroids
		if obj.get("object_type", "") == "asteroid":
			
			
			log_text += 'Asteroid Found : ' + "\n"
			var obj_dist = map.local_pos.distance_to(obj["local_pos"])
			#log_text += "Distance To : " + str(obj_dist) + "\n" + "Local Position : " + str(obj["local_pos"])
			scanned_mineable_asteroids.append({
				"object": obj,
				"distance": obj_dist
			})

	if Globals.print_priority_3:
		print("Asteroids found: ", scanned_mineable_asteroids.size())
	var re = "Asteroids found: " + str(scanned_mineable_asteroids.size()) + "\n" + log_text
	return re
	return re
	
func send_miner_drone_mk1():
	if has_navigation_lock_todo():
		block_navigation_action_for_todo("Asteroid approach")
		refresh_actions_from_inventory()
		return
	
	if scanned_mineable_asteroids.size() > 0:

		scanned_mineable_asteroids.sort_custom(func(a, b):
			return a["distance"] < b["distance"]
		)

		var closest = scanned_mineable_asteroids[0]["object"]

		if Globals.print_priority_3:
			print("AUTO TARGET ASTEROID: ", closest["scan_name"])

		auto_pilot.set_impulse_target(
			closest.get("sector_pos", map.sector_pos),
			closest["local_pos"],
			str(closest.get("scan_name", closest.get("display_name", "Asteroid"))),
			str(closest.get("object_type", "asteroid"))
		)

		auto_pilot.enabled = true
		
		refresh_actions_from_inventory()
func should_show_approach_asteroid() -> bool:
	if has_navigation_lock_todo():
		show_mine_action = false
		return false

	if scanned_mineable_asteroids.is_empty():
		show_mine_action = false
		return false

	if inventory == null:
		show_mine_action = false
		return false

	if not inventory.has_item_anywhere("miner_drone_mk1"):
		show_mine_action = false
		return false

	update_scanned_asteroid_distances()

	if scanned_mineable_asteroids.is_empty():
		show_mine_action = false
		return false

	# If we reached this point, the player has a miner drone
	# and at least one scanned asteroid exists.
	# This means mining behavior is available.
	show_mine_action = true

	var closest_dist := float(scanned_mineable_asteroids[0].get("distance", 999999.0))

	return closest_dist > 30.0


func update_scanned_asteroid_distances() -> void:
	if scanned_mineable_asteroids.is_empty():
		return

	for data in scanned_mineable_asteroids:
		if not data.has("object"):
			continue

		var obj = data["object"]
		if obj == null or not obj.has("local_pos"):
			continue

		var obj_sector := read_live_map_target_sector({"sector_pos": obj.get("sector_pos", map.sector_pos)})
		var obj_local := read_live_map_target_local({"local_pos": obj.get("local_pos", Vector3.ZERO)})
		data["distance"] = map.get_distance_to_target(obj_sector, obj_local) if map != null else 0.0

	scanned_mineable_asteroids.sort_custom(func(a, b):
		return a["distance"] < b["distance"]
	)


func build_mining_visual_packet(duration: float = 1.0) -> Dictionary:
	# Summary: Capture the exact asteroid the Mine Local click is acting on.
	# The packet is visual-only and is passed to the TODO row so the animation stays in sync.
	if scanned_mineable_asteroids.is_empty():
		return {}

	update_scanned_asteroid_distances()
	if scanned_mineable_asteroids.is_empty():
		return {}

	var closest = scanned_mineable_asteroids[0]
	if typeof(closest) != TYPE_DICTIONARY:
		return {}

	var asteroid = closest.get("object", null)
	if typeof(asteroid) != TYPE_DICTIONARY:
		return {}

	var resource_amounts := get_asteroid_resource_amounts(asteroid)
	if bool(asteroid.get("mined_out", false)) or resource_amounts.is_empty():
		return {}

	var asteroid_id := str(asteroid.get("object_id", asteroid.get("id", ""))).strip_edges()
	var display_name := str(asteroid.get("scan_name", asteroid.get("display_name", asteroid.get("name", "Asteroid"))))

	var packet := {
		"target_object_id": asteroid_id,
		"object_id": asteroid_id,
		"target_name": display_name,
		"scan_name": display_name,
		"object_type": str(asteroid.get("object_type", "asteroid")),
		"type": "object",
		"sector_pos": asteroid.get("sector_pos", map.sector_pos if map != null else Vector3i.ZERO),
		"local_pos": asteroid.get("local_pos", Vector3.ZERO),
		"distance": float(closest.get("distance", 0.0)),
		"duration": max(duration, 0.1),
		"visual_type": "mining_resource_packet",
		"resources_left": resource_amounts.duplicate(true)
	}

	for item_id in resource_amounts.keys():
		packet[str(item_id) + ASTEROID_RESOURCE_LEFT_SUFFIX] = int(resource_amounts.get(item_id, 0))

	return packet


func complete_scanned_enemy_engage(data: Dictionary) -> void:
	# Summary:
	# Called by EventManager after the engage_enemy TODO finishes.
	# This is the actual Battle V2 launch point.

	engage_enemy_in_progress = false
	Globals.engage_enemy = false

	var enemy = data.get("enemy", null)

	if enemy == null and not scanned_enemies.is_empty():
		enemy = scanned_enemies[0].get("enemy", null)

	if enemy == null:
		if Globals.print_priority_2:
			print("[ACTION_ENEMY_COMPLETE_FAIL] reason=no_enemy_ref")
		state.log_storage["log_text"].text = "ENGAGE FAILED\nNo enemy contact available."
		refresh_actions_from_inventory()
		return

	Globals.current_enemy = enemy

	if battle_v2_bridge == null:
		if Globals.print_priority_2:
			print("[ACTION_ENEMY_COMPLETE_FAIL] reason=battle_v2_bridge_missing")
		state.log_storage["log_text"].text = "ENGAGE FAILED\nBattle V2 bridge missing."
		refresh_actions_from_inventory()
		return

	if battle_v2_bridge.has_method("request_battle_v2_entry"):
		if Globals.print_priority_2:
			print("[ACTION_ENEMY_COMPLETE] requesting Battle V2 for selected enemy=", str(enemy.enemy_name))

		var requested := bool(battle_v2_bridge.request_battle_v2_entry("scanned_enemy_action", enemy))
		if not requested:
			if Globals.print_priority_2:
				print("[ACTION_ENEMY_COMPLETE_FAIL] reason=bridge_request_rejected enemy=", str(enemy.enemy_name))
			state.log_storage["log_text"].text = "ENGAGE FAILED\nBattle V2 rejected the request."
			refresh_actions_from_inventory()
		return

	# Fallback only for older bridge builds. The current bridge should use the selected enemy above.
	if not battle_v2_bridge.has_method("debug_force_real_enemy_encounter"):
		if Globals.print_priority_2:
			print("[ACTION_ENEMY_COMPLETE_FAIL] reason=bridge_missing_battle_entry_methods")
		state.log_storage["log_text"].text = "ENGAGE FAILED\nBattle V2 bridge method missing."
		refresh_actions_from_inventory()
		return

	if Globals.print_priority_2:
		print("[ACTION_ENEMY_COMPLETE] fallback debug launch for enemy=", str(enemy.enemy_name))

	battle_v2_bridge.debug_force_real_enemy_encounter()


func save_world_with_events() -> void:
	if save_manager == null:
		return

	# Action/TODO autosave disabled. Keep this helper as a no-op so older
	# action paths can call it without freezing the frame on disk writes.
	return
	#var game_events = get_game_event_handler()
	#save_manager.save_universe(
		#star_field,
		#map,
		#space_objects,
		#inventory,
		#enemy_handler,
		#npc_handler,
		#beacons,
		#game_events
	#)
