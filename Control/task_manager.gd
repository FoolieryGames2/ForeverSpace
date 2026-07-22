extends Node
class_name EventManager

signal craft_completed(packet: Dictionary)

const TODO_PERF_WARN_MS := 24


# ==========================================================
# ACTIVE EVENTS
# ==========================================================
var events : Array = []
const NAVIGATION_LOCK_EVENT_TYPES := [
	"scan",
	"mining",
	"engage_enemy",
	"enter_battle"
]

var state : WidgetsState5   # UI access

var build : WidgetsBuilder5

var map : Map
var star_field : StarField
var space_objects : Space_Objects
var beacons : Beacons
var planets : Planets
var inventory : Inventory5
var auto_pilot : AutoPilot
var save_manager : SaveManager
var action_manager : Action_Manager

var enemy_handler : EnemyHandler
var energy_handler : EnergyHandler
var todo_pipeline_last_signature := ""
var pending_deferred_scan_reasons: Dictionary = {}

# ==========================================================
# ADD EVENT
# ==========================================================

func setup(
	new_map,
	new_star_field,
	new_space_objects,
	new_beacons,
	new_planets,
	new_inventory,
	new_state,
	new_auto_pilot,
	new_save_manager,
	new_build,
	new_action_manager,
	
	new_enemy_handler,
	new_energy_handler
):
	map = new_map
	star_field = new_star_field
	space_objects = new_space_objects
	beacons = new_beacons
	planets = new_planets
	inventory = new_inventory
	state = new_state
	auto_pilot = new_auto_pilot
	save_manager = new_save_manager
	build = new_build
	action_manager = new_action_manager
	
	enemy_handler = new_enemy_handler
	energy_handler = new_energy_handler
	
	if energy_handler != null:
		if Globals.print_priority_3:
			print("EventManager connected to EnergyHandler.")
	else:
		if Globals.print_priority_1:
			print("EventManager energy_handler is null.")
	
	
	
func add_event(text: String, duration: float, event_type: String = "", data := {}):

	# ----------------------------------------------
	# Create UI row
	# ----------------------------------------------
	var row = build.add_todo_task(state, text, str(int(duration)) + "s")
	var time_label = row.get_child(1)


	# ----------------------------------------------
	# Store event
	# ----------------------------------------------
	var e = {
		"event_id": make_todo_event_id(event_type, text),
		"text": text,
		"time_left": duration,
		"duration": max(duration, 0.01),
		"row": row,
		"time_label": time_label,
		"type": event_type,   # ðŸ”¥ NEW
		"data": data          # ðŸ”¥ NEW
	}

	events.append(e)

	if is_navigation_lock_event(e):
		enforce_navigation_lock()

	refresh_todo_pipeline_widget(true)


func show_event_widget_packet(packet: Dictionary) -> void:
	# EventManager owns event truth; WidgetsBuilder owns the UI drawing.
	if build != null and build.has_method("set_event_widget_packet"):
		build.set_event_widget_packet(packet)


func clear_event_widget() -> void:
	if build != null and build.has_method("clear_event_widget"):
		build.clear_event_widget()


func has_active_todo() -> bool:
	return not events.is_empty()


func get_active_todo_count() -> int:
	return events.size()


func is_navigation_lock_event(event) -> bool:
	if typeof(event) != TYPE_DICTIONARY:
		return false

	var event_type := str(event.get("type", "")).strip_edges().to_lower()
	return event_type in NAVIGATION_LOCK_EVENT_TYPES


func has_navigation_lock_todo() -> bool:
	for event in events:
		if is_navigation_lock_event(event):
			return true

	return false


func get_navigation_lock_todo_text() -> String:
	for event in events:
		if is_navigation_lock_event(event):
			var text := str(event.get("text", "")).strip_edges()
			if text != "":
				return text

			var event_type := str(event.get("type", "")).strip_edges()
			if event_type != "":
				return event_type

	return ""


func enforce_navigation_lock() -> void:
	if not has_navigation_lock_todo():
		return

	if state != null:
		state.use_auto_pilot = false

	if auto_pilot != null:
		if auto_pilot.enabled:
			auto_pilot.stop()
		elif auto_pilot.engine != null:
			auto_pilot.engine.stop()


# ==========================================================
# PROCESS LOOP (TICKS TIME)
# ==========================================================
func _process(delta):

	if events.is_empty():
		refresh_todo_pipeline_widget(false)
		return

	# iterate backwards (safe removal)
	for i in range(events.size() - 1, -1, -1):

		var e = events[i]

		# ------------------------------------------
		# countdown
		# ------------------------------------------
		e["time_left"] -= delta

		# ------------------------------------------
		# update UI
		# ------------------------------------------
		var time_text := str(int(ceil(e["time_left"]))) + "s"
		if e["time_label"].text != time_text:
			e["time_label"].text = time_text

		# ------------------------------------------
		# finished?
		# ------------------------------------------
		if e["time_left"] <= 0:

			# remove UI
			e["row"].queue_free()

			# remove event
			events.remove_at(i)

			# trigger completion
			_on_event_finished(e)

	refresh_todo_pipeline_widget(true)



# ==========================================================
# EVENT COMPLETE HOOK
# ==========================================================
func _on_event_finished(event):
	var event_started_ms := Time.get_ticks_msec()
	var event_type := str(event.get("type", "")).strip_edges()

	if Globals.print_priority_2:
		print("EVENT COMPLETE: ", event["text"])
		print("-| todo autosave disabled; applying runtime update only |-")
	# TODO autosave disabled. Runtime completion handlers below still update
	# game state, inventory, actions, and UI; persistence should happen from
	# explicit snapshots or scene-transition saves.
	#save_manager.save_universe(star_field,map,space_objects,inventory,enemy_handler)

	match event_type:

		# ============================
		# ðŸ“¬ MAIL
		# ============================
		"get_mail":

			state.log_storage['log_text'].text += \
			"you have a message from Gilbert \nhe whats up buddy!\n"
			var msg = 'I know your working hard on your game. \n just wanted to check in and make sure you were \n taking breaks and stuff.  \n  have a good one buddy!'
			Globals.show_popup(state, msg)


		# ============================
		# ðŸ“¡ SCAN
		# ============================
		"scan":

			if Globals.print_priority_2:
				print("Scan complete â†’ running scan_local_mk1")

			if action_manager != null:
				var scan_started_ms := Time.get_ticks_msec()

				# reset scan-related state
				#action_manager.scanned_mineable_asteroids.clear()

				action_manager.scan_in_progress = false
				action_manager.scan_local_mk1()
				print_todo_perf("scan_local_mk1 from todo", scan_started_ms)
			var enemies = enemy_handler.get_enemies_in_sector(map.sector_pos)

			if Globals.print_priority_3:
				print("ENEMIES IN SECTOR:", enemies.size())

			for e in enemies:
				if Globals.print_priority_3:
					print("Enemy:", e.enemy_name, " @ ", e.local_pos)


		# ============================
		# â› MINING
		# ============================
		"mining":

			if Globals.print_priority_2:
				print("Mining complete â†’ running mine_asteroid")

			if action_manager != null:
				var mine_started_ms := Time.get_ticks_msec()
				action_manager.mining_in_progress = false
				action_manager.mine_asteroid()
				print_todo_perf("mine_asteroid from todo", mine_started_ms)
				request_deferred_completion_scan("mining_complete")

				
		"engage_enemy":
			Globals.engage_enemy = false

			if Globals.print_priority_2:
				print("Engage enemy TODO complete.")

			if action_manager != null:
				action_manager.complete_scanned_enemy_engage(event.get("data", {}))


		"enter_battle":

			Globals.battle_pending = false   # ðŸ‘ˆ UNLOCK
			Globals.battle_mode = true

			var enemy = event["data"].get("enemy", Globals.current_enemy)
			Globals.current_enemy = enemy
			
			action_manager.refresh_actions_from_inventory()

			var battle_text := "[ALERT] ENTERING BATTLE MODE"
			

			if enemy != null:
				battle_text += "\n[ENEMY] " + enemy.enemy_name + " engaged"

			state.log_storage["log_text"].text = battle_text

		"craft_blueprint":
			complete_blueprint_craft(event.get("data", {}))
		_:
			
			if Globals.print_priority_1:
				print("No handler for event type:", event_type)
			
	print_todo_perf("event_finished type=" + event_type, event_started_ms)


func complete_blueprint_craft(data: Dictionary) -> void:
	var result_item_id := str(data.get("result_item_id", data.get("gain", "")))
	var result_count := int(data.get("result_count", data.get("amount", 1)))
	var result_name := str(data.get("result_name", result_item_id))

	if result_item_id == "":
		write_task_log("Craft complete failed: blueprint result was empty.")
		return

	if inventory == null:
		write_task_log("Craft complete failed: inventory is not connected.")
		return

	var added := inventory.add_item(result_item_id, max(result_count, 1))
	if not added:
		write_task_log("Craft complete failed: inventory is full. " + result_name + " could not be added.")
		refund_blueprint_craft_cost(data)
		refresh_blueprint_widget_from_task_manager()
		return

	inventory.refresh_label_inventory_rows()

	if action_manager != null:
		action_manager.refresh_actions_from_inventory()

	refresh_blueprint_widget_from_task_manager()

	write_task_log("CRAFT COMPLETE\nAdded: " + result_name + " x" + str(max(result_count, 1)))
	craft_completed.emit({
		"reason": "craft_blueprint",
		"item_id": result_item_id,
		"display_name": result_name,
		"amount": max(result_count, 1),
		"craft_rewards": [
			{
				"item_id": result_item_id,
				"display_name": result_name,
				"amount": max(result_count, 1)
			}
		],
		"message": "CRAFT COMPLETE\nAdded: " + result_name + " x" + str(max(result_count, 1))
	})

	# TODO autosave disabled. Craft result is applied in memory; persistence
	# should happen from explicit snapshots or scene-transition saves.
	#if save_manager != null:
		#save_manager.save_universe(star_field, map, space_objects, inventory, enemy_handler)


func refund_blueprint_craft_cost(data: Dictionary) -> void:
	if inventory == null:
		return
	var cost = data.get("cost", {})
	if typeof(cost) != TYPE_DICTIONARY:
		return
	for item_id in cost.keys():
		var amount := int(cost[item_id])
		if amount > 0:
			inventory.add_item(str(item_id), amount)


func refresh_blueprint_widget_from_task_manager() -> void:
	if state == null:
		return
	if state.blueprint_refresh_callable.is_valid():
		state.blueprint_refresh_callable.call()


func write_task_log(message: String) -> void:
	if state == null:
		return
	if state.log_storage.has("log_text"):
		state.log_storage["log_text"].text = message


func make_todo_event_id(event_type: String, text: String) -> String:
	return str(event_type).strip_edges().to_lower() + "_" + str(hash(text + str(Time.get_ticks_msec())))


func request_deferred_completion_scan(reason: String = "completion") -> void:
	if action_manager == null:
		return
	var clean_reason := str(reason).strip_edges()
	if clean_reason == "":
		clean_reason = "completion"
	if bool(pending_deferred_scan_reasons.get(clean_reason, false)):
		return
	pending_deferred_scan_reasons[clean_reason] = true
	call_deferred("run_deferred_completion_scan", clean_reason)


func run_deferred_completion_scan(reason: String = "completion") -> void:
	pending_deferred_scan_reasons.erase(reason)
	if action_manager == null:
		return
	var scan_started_ms := Time.get_ticks_msec()
	action_manager.scan_in_progress = false
	action_manager.scan_local_mk1()
	print_todo_perf("deferred scan_local_mk1 reason=" + str(reason), scan_started_ms)


func refresh_todo_pipeline_widget(force: bool = false) -> void:
	if state == null:
		return
	if not state.controls.has("main_todo_pipeline_widget"):
		return
	var widget = state.controls["main_todo_pipeline_widget"]
	if widget == null or not is_instance_valid(widget):
		return
	if widget.has_method("set_snapshot"):
		var snapshot := build_todo_pipeline_snapshot()
		var signature := build_todo_pipeline_signature(snapshot)
		if not force and signature == todo_pipeline_last_signature:
			return
		todo_pipeline_last_signature = signature
		widget.set_snapshot(snapshot)


func build_todo_pipeline_snapshot() -> Array:
	var snapshot: Array = []
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var duration = max(float(event.get("duration", event.get("time_left", 1.0))), 0.01)
		var time_left = max(float(event.get("time_left", 0.0)), 0.0)
		snapshot.append({
			"event_id": str(event.get("event_id", "")),
			"text": str(event.get("text", "")),
			"type": str(event.get("type", "")),
			"time_left": time_left,
			"duration": duration,
			"progress": clamp(1.0 - (time_left / duration), 0.0, 1.0),
			"data": event.get("data", {})
		})
	return snapshot


func build_todo_pipeline_signature(snapshot: Array) -> String:
	if snapshot.is_empty():
		return "empty"

	var parts := []
	for event in snapshot:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var time_bucket := int(ceil(float(event.get("time_left", 0.0)) * 5.0))
		var progress_bucket := int(round(float(event.get("progress", 0.0)) * 100.0))
		parts.append(
			str(event.get("event_id", ""))
			+ ":"
			+ str(event.get("type", ""))
			+ ":"
			+ str(time_bucket)
			+ ":"
			+ str(progress_bucket)
		)
	return "|".join(parts)


func print_todo_perf(label: String, started_ms: int) -> void:
	var elapsed_ms := Time.get_ticks_msec() - started_ms
	if elapsed_ms >= TODO_PERF_WARN_MS or Globals.print_priority_2:
		print("[TODO_PERF] ", label, " | ", elapsed_ms, "ms")
		
