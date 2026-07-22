extends Node
class_name BattleV2EventManager

# EventManager owns active TODO timing storage.
var active_events: Array = []


# Events completed during the current tick/frame are collected here.
# This is a timing snapshot only.
# BattleManager decides how the batch resolves.
var completed_event_batch: Array = []


# Optional debug/handoff receipt storage.
# Used only to remember whether BattleManager accepted/acknowledged the latest batch.
var last_handoff_result: Dictionary = {}


# Local counter for generated event IDs if an event is allowed to auto-generate one.
var event_id_counter: int = 0


# Optional reference for push-style handoff.
# EventManager may send completed batches to BattleManager,
# but it must not resolve the events itself.
var battle_manager = null



func validate_event_packet(event_packet: Dictionary) -> Dictionary:
	# Full purpose summary:
	# Validate that an incoming TODO event packet has the required blueprint fields before EventManager is allowed to queue it.

	# EventManager must not silently accept malformed TODO packets.
	# This function only validates packet shape and timing fields.
	# It does not resolve gameplay.
	# It does not apply damage.
	# It does not check lock.
	# It does not decide whether the action succeeds.
	# BattleManager owns outcome resolution after completed batch handoff.

	var result := {
		"valid": true,
		"blocked_reason": "",
		"missing_fields": [],
		"labels": []
	}

	var required_fields := [
		"event_id",
		"event_type",
		"event_group",
		"source_unit",
		"target_unit",
		"owner_unit",
		"event_side",
		"duration",
		"time_remaining",
		"same_type_key",
		"requires_lock",
		"is_state_change",
		"is_damage_event",
		"is_effect_event",
		"is_visual_only",
		"data"
	]

	if Globals.debug_eventManager:
		print("EventManager.validate_event_packet() checking packet: ", event_packet)

	for field in required_fields:
		if not event_packet.has(field):
			result["valid"] = false
			result["missing_fields"].append(field)

	if not result["missing_fields"].is_empty():
		result["blocked_reason"] = "missing_required_field"
		result["labels"].append("event_packet_validation")
		result["labels"].append("event_missing_required_field")
		result["labels"].append("event_rejected_invalid_packet")

		if Globals.debug_eventManager:
			print("EventManager.validate_event_packet() rejected packet. Missing fields: ", result["missing_fields"])

		return result

	if float(event_packet["duration"]) < 0.0:
		result["valid"] = false
		result["blocked_reason"] = "invalid_duration"
		result["labels"].append("event_packet_validation")
		result["labels"].append("event_rejected_invalid_packet")

		if Globals.debug_eventManager:
			print("EventManager.validate_event_packet() rejected packet. Invalid duration: ", event_packet["duration"])

		return result

	if float(event_packet["time_remaining"]) < 0.0:
		result["valid"] = false
		result["blocked_reason"] = "invalid_time_remaining"
		result["labels"].append("event_packet_validation")
		result["labels"].append("event_rejected_invalid_packet")

		if Globals.debug_eventManager:
			print("EventManager.validate_event_packet() rejected packet. Invalid time_remaining: ", event_packet["time_remaining"])

		return result

	if event_packet["same_type_key"] == "":
		result["valid"] = false
		result["blocked_reason"] = "missing_same_type_key"
		result["labels"].append("event_packet_validation")
		result["labels"].append("event_rejected_invalid_packet")

		if Globals.debug_eventManager:
			print("EventManager.validate_event_packet() rejected packet. Empty same_type_key.")

		return result

	result["labels"].append("event_packet_validation")

	if Globals.debug_eventManager:
		print(
			"EventManager.validate_event_packet() passed. ",
			"event_id=", event_packet["event_id"],
			" event_type=", event_packet["event_type"],
			" duration=", event_packet["duration"],
			" time_remaining=", event_packet["time_remaining"]
		)

	return result
	
	
func ensure_event_id(event_packet: Dictionary) -> Dictionary:
	# Full purpose summary:
	# Ensure every TODO event has a unique event_id before EventManager stores it as an active timing event.

	# EventManager needs stable event identity for:
	# - debugging
	# - cleanup
	# - removal by owner
	# - batch acknowledgement
	# - event tracing
	#
	# This function only protects event identity.
	# It does not queue the event.
	# It does not apply same-type stacking.
	# It does not resolve gameplay.
	# It does not decide if the event succeeds.

	var result := {
		"valid": true,
		"event_id": "",
		"blocked_reason": "",
		"labels": []
	}

	result["labels"].append("event_unique_id")
	result["labels"].append("event_id_collision_check")

	if Globals.debug_eventManager:
		print("EventManager.ensure_event_id() checking event_id: ", event_packet.get("event_id", null))

	var current_id = event_packet.get("event_id", "")

	# Blank event_id is allowed to be generated.
	# This follows the blueprint recommendation:
	# regenerate only if event_id was blank or auto-generated.
	if current_id == "":
		event_id_counter += 1
		var generated_id := "event_" + str(event_id_counter)
		event_packet["event_id"] = generated_id

		result["event_id"] = generated_id

		if Globals.debug_eventManager:
			print("EventManager.ensure_event_id() generated new event_id: ", generated_id)

		return result

	# Explicit event_id must be checked against active events.
	# If another active event already uses this ID, reject it.
	for active_event in active_events:
		if typeof(active_event) != TYPE_DICTIONARY:
			continue
		if active_event.has("event_id") and active_event["event_id"] == current_id:
			result["valid"] = false
			result["event_id"] = current_id
			result["blocked_reason"] = "duplicate_event_id"
			result["labels"].append("event_id_required")

			if Globals.debug_eventManager:
				print("EventManager.ensure_event_id() rejected duplicate explicit event_id: ", current_id)

			return result

	result["event_id"] = current_id

	if Globals.debug_eventManager:
		print("EventManager.ensure_event_id() passed event_id: ", current_id)

	return result
	
	
	
func add_event(event_packet: Dictionary) -> Dictionary:
	# Full purpose summary:
	# Validate, identity-check, same-type stack, and store an incoming TODO event as an active EventManager timing event.

	# EventManager owns TODO timing storage.
	# This function is the main entry point for Action_Manager, Enemy, drones, allies, or future systems to request a timed TODO.
	#
	# This function does:
	# - validate packet shape
	# - confirm/generate unique event_id
	# - apply same-type stacking
	# - mark the event active
	# - store the event in active_events
	#
	# This function does NOT:
	# - tick countdowns
	# - complete events
	# - resolve damage
	# - check lock
	# - spend ammo
	# - spend energy
	# - apply effects
	# - decide victory/defeat
	# - draw UI

	var result := {
		"accepted": false,
		"event_id": "",
		"blocked_reason": "",
		"labels": []
	}

	if Globals.debug_eventManager:
		print("EventManager.add_event() received packet: ", event_packet)

	var validation_result := validate_event_packet(event_packet)

	result["labels"].append_array(validation_result["labels"])

	if not validation_result["valid"]:
		result["blocked_reason"] = validation_result["blocked_reason"]

		if Globals.debug_eventManager:
			print(
				"EventManager.add_event() rejected during validation. ",
				"blocked_reason=", result["blocked_reason"],
				" missing_fields=", validation_result.get("missing_fields", [])
			)

		return result

	var id_result := ensure_event_id(event_packet)

	result["labels"].append_array(id_result["labels"])
	result["event_id"] = id_result["event_id"]

	if not id_result["valid"]:
		result["blocked_reason"] = id_result["blocked_reason"]

		if Globals.debug_eventManager:
			print(
				"EventManager.add_event() rejected during event_id check. ",
				"event_id=", result["event_id"],
				" blocked_reason=", result["blocked_reason"]
			)

		return result

	# Same-type stacking:
	# If another active event has the same same_type_key,
	# this new event is delayed behind the latest matching active countdown.
	#
	# Blueprint rule:
	# new_time_remaining = last_matching_same_type_remaining + new_event_normal_duration
	#
	# Important:
	# same_type_key must already be specific enough.
	# EventManager does not reinterpret the action type.
	# EventManager only applies the timing rule.
	var same_type_key = event_packet["same_type_key"]
	var last_matching_time_remaining := -1.0

	for active_event in active_events:
		if typeof(active_event) != TYPE_DICTIONARY:
			continue
		if active_event.has("same_type_key") and active_event["same_type_key"] == same_type_key:
			if active_event.has("time_remaining"):
				if float(active_event["time_remaining"]) > last_matching_time_remaining:
					last_matching_time_remaining = float(active_event["time_remaining"])

	if last_matching_time_remaining >= 0.0:
		event_packet["time_remaining"] = last_matching_time_remaining + float(event_packet["duration"])
		result["same_type_stack_applied"] = true
		result["previous_same_type_time_remaining"] = last_matching_time_remaining

		result["labels"].append("same_type_todo_stacking")
		result["labels"].append("same_type_key")
		result["labels"].append("same_type_stack_group")
		result["labels"].append("same_type_next_start_after_previous")
		result["labels"].append("methodical_queue_timing")

		if Globals.debug_eventManager:
			print(
				"EventManager.add_event() applied same-type stacking. ",
				"event_id=", event_packet["event_id"],
				" same_type_key=", same_type_key,
				" stacked_time_remaining=", event_packet["time_remaining"]
			)

	# Mark lifecycle state as active.
	# This is EventManager timing state only.
	# It does not mean the gameplay result has happened.
	event_packet["lifecycle_state"] = "active"
	result["labels"].append("todo_event_active")

	active_events.append(event_packet)

	result["accepted"] = true
	result["event_id"] = event_packet["event_id"]
	result["event_type"] = event_packet.get("event_type", "")
	result["same_type_key"] = event_packet.get("same_type_key", "")
	result["duration"] = float(event_packet.get("duration", 0.0))
	result["time_remaining"] = float(event_packet.get("time_remaining", 0.0))

	if Globals.debug_eventManager:
		print(
			"EventManager.add_event() accepted event. ",
			"event_id=", result["event_id"],
			" event_type=", event_packet["event_type"],
			" same_type_key=", event_packet["same_type_key"],
			" time_remaining=", event_packet["time_remaining"],
			" active_count=", active_events.size()
		)

	return result
	
	
	
	
func process_events(delta: float) -> void:
	# Full purpose summary:
	# Tick all active TODO events, collect every event that completes during this tick, lock them into a completed timing batch, and prepare/send that batch for BattleManager resolution.

	# EventManager owns TODO countdown progression.
	# This function is the authoritative timing step.
	#
	# Decorative UI countdowns may display timing,
	# but this function is the source of truth.
	#
	# This function does:
	# - reduce active event time_remaining by delta
	# - detect events that reach zero or below
	# - mark completed events as completed
	# - remove completed events from active_events
	# - build one completed_event_batch for this tick/frame
	# - optionally hand that batch to BattleManager
	#
	# This function does NOT:
	# - apply damage
	# - check lock
	# - resolve shield math
	# - apply effects
	# - decide victory/defeat
	# - sort gameplay outcomes
	# - decide same-timestamp resolution order
	# - draw UI

	if Globals.debug_eventManager:
		print(
			"EventManager.process_events() start. ",
			"delta=", delta,
			" active_count=", active_events.size()
		)

	# Clear the previous tick/frame completion snapshot.
	# A completed_event_batch represents only the events completed during this process_events() call.
	completed_event_batch.clear()

	# If there are no active TODOs, there is no timing work to do.
	if active_events.is_empty():
		if Globals.debug_eventManager:
			print("EventManager.process_events() no active events. Returning.")
		return

	var still_active_events: Array = []
	var completed_this_tick: Array = []

	for event_packet in active_events:
		# EventManager only processes active TODOs.
		# Cancelled, ignored, expired, or completed events should not continue ticking.
		if event_packet.get("lifecycle_state", "active") != "active":
			if Globals.debug_eventManager:
				print(
					"EventManager.process_events() skipping non-active event. ",
					"event_id=", event_packet.get("event_id", ""),
					" lifecycle_state=", event_packet.get("lifecycle_state", "")
				)
			continue

		# Countdown authority lives here.
		# UI display timers are non-authoritative.
		event_packet["time_remaining"] = float(event_packet["time_remaining"]) - delta

		if Globals.debug_eventManager:
			print(
				"EventManager.process_events() ticked event. ",
				"event_id=", event_packet.get("event_id", ""),
				" event_type=", event_packet.get("event_type", ""),
				" time_remaining=", event_packet.get("time_remaining", 0.0)
			)

		if float(event_packet["time_remaining"]) <= 0.0:
			# This event completed during the current timing tick.
			# Its completion snapshot is now locked for this resolution cycle.
			# BattleManager decides what that completion means.
			event_packet["lifecycle_state"] = "completed"
			event_packet["completion_timestamp"] = Time.get_ticks_msec()
			event_packet["completed_in_current_batch"] = true

			completed_this_tick.append(event_packet)

			if Globals.debug_eventManager:
				print(
					"EventManager.process_events() completed event. ",
					"event_id=", event_packet.get("event_id", ""),
					" event_type=", event_packet.get("event_type", ""),
					" same_type_key=", event_packet.get("same_type_key", "")
				)
		else:
			# Event has not completed yet, so it remains active.
			still_active_events.append(event_packet)

	# Replace active storage with only the events still counting down.
	active_events = still_active_events

	# If no events completed this tick, no batch is created or handed off.
	if completed_this_tick.is_empty():
		if Globals.debug_eventManager:
			print(
				"EventManager.process_events() no completed events this tick. ",
				"remaining_active_count=", active_events.size()
			)
		return

	# Build the same-tick completed batch.
	# EventManager groups these together.
	# BattleManager determines the same-timestamp resolution order.
	completed_event_batch = completed_this_tick

	if Globals.debug_eventManager:
		print(
			"EventManager.process_events() built completed_event_batch. ",
			"batch_size=", completed_event_batch.size(),
			" remaining_active_count=", active_events.size()
		)

	send_completed_batch_to_battle_manager()
	
	
	
	
func send_completed_batch_to_battle_manager() -> Dictionary:
	# Full purpose summary:
	# Send the current completed_event_batch timing snapshot to BattleManager for gameplay resolution and store the handoff receipt.

	# EventManager owns the completed timing batch.
	# BattleManager owns what happens because of that batch.
	#
	# This function does:
	# - check whether a completed batch exists
	# - check whether a BattleManager reference exists
	# - send the batch to BattleManager.resolve_todo_completion(batch)
	# - store the handoff result if one is returned
	# - return a delivery/acknowledgement dictionary
	#
	# This function does NOT:
	# - sort events by gameplay priority
	# - resolve state changes
	# - apply damage
	# - check lock
	# - apply effects
	# - decide victory/defeat
	# - mutate shield/hull/resources
	# - draw UI

	var result := {
		"delivered": false,
		"acknowledged": false,
		"resolved_count": 0,
		"failed_count": 0,
		"battle_outcome": "",
		"blocked_reason": "",
		"resolution_summary": {},
		"labels": []
	}

	result["labels"].append("send_completed_batch_to_battle_manager")

	if Globals.debug_eventManager:
		print(
			"EventManager.send_completed_batch_to_battle_manager() start. ",
			"batch_size=", completed_event_batch.size(),
			" battle_manager=", battle_manager
		)

	if completed_event_batch.is_empty():
		result["blocked_reason"] = "empty_completed_batch"

		if Globals.debug_eventManager:
			print("EventManager.send_completed_batch_to_battle_manager() blocked: empty_completed_batch")

		last_handoff_result = result
		return result

	if battle_manager == null:
		result["blocked_reason"] = "missing_battle_manager_reference"

		if Globals.debug_eventManager:
			print("EventManager.send_completed_batch_to_battle_manager() blocked: missing_battle_manager_reference")

		last_handoff_result = result
		return result

	if not battle_manager.has_method("resolve_todo_completion"):
		result["blocked_reason"] = "battle_manager_missing_resolve_todo_completion"

		if Globals.debug_eventManager:
			print("EventManager.send_completed_batch_to_battle_manager() blocked: BattleManager missing resolve_todo_completion(batch)")

		last_handoff_result = result
		return result

	# Duplicate the array so this handoff is treated as a timing snapshot.
	# This protects the current batch from accidental mutation during later EventManager work.
	# The event dictionaries inside are duplicated deeply to lock the emitted snapshot.
	var batch_snapshot: Array = completed_event_batch.duplicate(true)

	var handoff_result: Variant = battle_manager.resolve_todo_completion(batch_snapshot)

	result["delivered"] = true
	result["labels"].append("completed_batch_delivered")

	if typeof(handoff_result) == TYPE_DICTIONARY:
		result["acknowledged"] = true
		result["labels"].append("completed_batch_acknowledged")
		result["labels"].append("event_handoff_result")

		var handoff_dictionary: Dictionary = handoff_result as Dictionary
		var resolved_events: Array = handoff_dictionary.get("resolved_events", []) as Array
		var invalid_events: Array = handoff_dictionary.get("invalid_events", []) as Array
		result["resolved_count"] = resolved_events.size()
		result["failed_count"] = invalid_events.size()
		result["battle_outcome"] = str(handoff_dictionary.get("battle_outcome", ""))
		result["resolution_summary"] = handoff_dictionary.duplicate(true)
	else:
		# Delivery can still be true even if BattleManager does not return a receipt.
		# Acknowledgement only means a dictionary receipt came back.
		result["acknowledged"] = false

	last_handoff_result = result

	if Globals.debug_eventManager:
		print(
			"EventManager.send_completed_batch_to_battle_manager() finished. ",
			"delivered=", result["delivered"],
			" acknowledged=", result["acknowledged"],
			" resolved_count=", result["resolved_count"],
			" failed_count=", result["failed_count"]
		)

	return result
	
	
	
	
func get_completed_batch() -> Array:
	# Full purpose summary:
	# Return a safe copy of the latest completed_event_batch timing snapshot for pull-style BattleManager access or debug testing.

	# EventManager owns completed TODO batching.
	# This function only exposes the latest completed batch.
	#
	# This function does:
	# - return a duplicated copy of completed_event_batch
	# - preserve the completed timing snapshot
	#
	# This function does NOT:
	# - process countdowns
	# - clear active events
	# - resolve outcomes
	# - apply damage
	# - check lock
	# - apply effects
	# - decide victory/defeat
	# - determine same-timestamp resolution order

	if Globals.debug_eventManager:
		print(
			"EventManager.get_completed_batch() called. ",
			"batch_size=", completed_event_batch.size()
		)

	return completed_event_batch.duplicate(true)
	
	
	
	
func clear_battle_events(battle_id = null) -> Dictionary:
	# Full purpose summary:
	# Clear, cancel, or ignore active battle TODO events during battle cleanup so pending events do not resolve after the battle ends.

	# EventManager owns cleanup of active TODO timing events.
	# BattleManager decides when battle cleanup begins.
	#
	# This function does:
	# - scan active_events
	# - find events matching the provided battle_id if one is given
	# - clear all active battle events if battle_id is null
	# - mark removed events as ignored/cancelled
	# - remove those events from active_events
	# - return a cleanup report
	#
	# This function does NOT:
	# - resolve any completed event
	# - alter an already emitted completed batch
	# - apply damage
	# - check lock
	# - apply effects
	# - decide victory/defeat
	# - draw UI
	#
	# Important blueprint rule:
	# Completed events already inside the current resolution batch are timing snapshots.
	# They should not be recalculated here.
	# This function only cleans active pending TODOs.

	var result := {
		"cleared_count": 0,
		"ignored_count": 0,
		"cancelled_count": 0,
		"battle_id": battle_id,
		"labels": []
	}

	result["labels"].append("event_cleanup_battle_end")
	result["labels"].append("clear_battle_todos")

	if Globals.debug_eventManager:
		print(
			"EventManager.clear_battle_events() start. ",
			"battle_id=", battle_id,
			" active_count=", active_events.size(),
			" completed_batch_size=", completed_event_batch.size()
		)

	if active_events.is_empty():
		if Globals.debug_eventManager:
			print("EventManager.clear_battle_events() no active events to clear.")

		return result

	var still_active_events: Array = []

	for event_packet in active_events:
		var should_clear := false

		# If battle_id is null, this is a broad battle cleanup.
		# All active battle TODOs are cleared.
		if battle_id == null:
			should_clear = true
		else:
			# If battle_id is provided, only events from that battle are cleared.
			# Events without a matching battle_id remain active.
			if event_packet.get("battle_id", null) == battle_id:
				should_clear = true

		if should_clear:
			# During battle cleanup, pending events should not fire afterward.
			# Mark as ignored because the battle context no longer exists.
			# This does not resolve the event.
			event_packet["lifecycle_state"] = "ignored"
			event_packet["cleanup_reason"] = "battle_cleanup"

			result["cleared_count"] += 1
			result["ignored_count"] += 1

			if Globals.debug_eventManager:
				print(
					"EventManager.clear_battle_events() ignored active event. ",
					"event_id=", event_packet.get("event_id", ""),
					" event_type=", event_packet.get("event_type", ""),
					" owner_unit=", event_packet.get("owner_unit", null),
					" battle_id=", event_packet.get("battle_id", null),
					" time_remaining=", event_packet.get("time_remaining", 0.0)
				)
		else:
			still_active_events.append(event_packet)

	active_events = still_active_events

	if result["ignored_count"] > 0:
		result["labels"].append("todo_event_ignored")

	if Globals.debug_eventManager:
		print(
			"EventManager.clear_battle_events() finished. ",
			"cleared_count=", result["cleared_count"],
			" ignored_count=", result["ignored_count"],
			" remaining_active_count=", active_events.size(),
			" completed_batch_size_unchanged=", completed_event_batch.size()
		)

	return result
	
	
	
	
func remove_events_by_owner(owner_unit) -> Dictionary:
	# Full purpose summary:
	# Remove or ignore active TODO events owned by a specific unit so removed/defeated units cannot resolve pending events later.

	# EventManager owns active TODO cleanup by owner.
	# This function is used when a unit is removed from battle context.
	#
	# This function does:
	# - receive an owner_unit
	# - scan active_events
	# - find events where event["owner_unit"] == owner_unit
	# - mark those events as ignored
	# - remove them from active_events
	# - return a removal report
	#
	# This function does NOT:
	# - resolve the removed events
	# - apply damage
	# - check lock
	# - apply effects
	# - decide victory/defeat
	# - mutate shields/hull/resources
	# - draw UI
	#
	# Important blueprint rule:
	# Dead enemy TODOs must not fire after victory or removal.
	# EventManager may remove/ignore timing events,
	# but BattleManager still owns the reason a unit was defeated.

	var result := {
		"removed_count": 0,
		"ignored_count": 0,
		"owner_unit": owner_unit,
		"labels": []
	}

	result["labels"].append("remove_events_by_owner")

	if Globals.debug_eventManager:
		print(
			"EventManager.remove_events_by_owner() start. ",
			"owner_unit=", owner_unit,
			" active_count=", active_events.size()
		)

	if owner_unit == null:
		if Globals.debug_eventManager:
			print("EventManager.remove_events_by_owner() blocked: owner_unit is null.")

		return result

	if active_events.is_empty():
		if Globals.debug_eventManager:
			print("EventManager.remove_events_by_owner() no active events to scan.")

		return result

	var still_active_events: Array = []

	for event_packet in active_events:
		var event_owner = event_packet.get("owner_unit", null)

		if event_owner == owner_unit:
			# This event belongs to the removed/defeated owner.
			# It must not continue counting down or resolve later.
			# Mark as ignored because the owner context no longer exists.
			event_packet["lifecycle_state"] = "ignored"
			event_packet["cleanup_reason"] = "owner_removed"

			result["removed_count"] += 1
			result["ignored_count"] += 1

			if Globals.debug_eventManager:
				print(
					"EventManager.remove_events_by_owner() ignored owned event. ",
					"event_id=", event_packet.get("event_id", ""),
					" event_type=", event_packet.get("event_type", ""),
					" owner_unit=", event_owner,
					" time_remaining=", event_packet.get("time_remaining", 0.0)
				)
		else:
			still_active_events.append(event_packet)

	active_events = still_active_events

	if result["ignored_count"] > 0:
		result["labels"].append("todo_event_ignored")
		result["labels"].append("ignore_events_for_dead_unit")

	if Globals.debug_eventManager:
		print(
			"EventManager.remove_events_by_owner() finished. ",
			"removed_count=", result["removed_count"],
			" ignored_count=", result["ignored_count"],
			" remaining_active_count=", active_events.size()
		)

	return result
	
	
	
	
func cancel_event(event_id: String, reason := "") -> Dictionary:
	# Full purpose summary:
	# Cancel one specific active TODO event by event_id so it stops counting down and cannot resolve later.

	# EventManager owns active TODO cancellation.
	# This function is for removing a specific pending timing event.
	#
	# This function does:
	# - receive an event_id
	# - scan active_events
	# - find the matching active event
	# - mark it as cancelled
	# - remove it from active_events
	# - return a cancellation report
	#
	# This function does NOT:
	# - resolve the cancelled event
	# - apply damage
	# - check lock
	# - apply effects
	# - refund ammo
	# - refund energy
	# - consume inventory
	# - decide victory/defeat
	# - draw UI
	#
	# Important:
	# Cancelling a TODO only changes EventManager timing state.
	# Any gameplay meaning of that cancellation belongs outside EventManager.

	var result := {
		"cancelled": false,
		"event_id": event_id,
		"blocked_reason": "",
		"reason": reason,
		"labels": []
	}

	if Globals.debug_eventManager:
		print(
			"EventManager.cancel_event() start. ",
			"event_id=", event_id,
			" reason=", reason,
			" active_count=", active_events.size()
		)

	if event_id == "":
		result["blocked_reason"] = "missing_event_id"

		if Globals.debug_eventManager:
			print("EventManager.cancel_event() blocked: missing_event_id")

		return result

	if active_events.is_empty():
		result["blocked_reason"] = "no_active_events"

		if Globals.debug_eventManager:
			print("EventManager.cancel_event() blocked: no_active_events")

		return result

	var still_active_events: Array = []
	var found_event := false

	for event_packet in active_events:
		if event_packet.get("event_id", "") == event_id:
			found_event = true

			# This event is intentionally removed before completion.
			# It must not continue counting down.
			# It must not be placed into completed_event_batch.
			event_packet["lifecycle_state"] = "cancelled"
			event_packet["cancel_reason"] = reason

			result["cancelled"] = true
			result["labels"].append("todo_event_cancelled")

			if Globals.debug_eventManager:
				print(
					"EventManager.cancel_event() cancelled event. ",
					"event_id=", event_packet.get("event_id", ""),
					" event_type=", event_packet.get("event_type", ""),
					" owner_unit=", event_packet.get("owner_unit", null),
					" time_remaining=", event_packet.get("time_remaining", 0.0),
					" reason=", reason
				)
		else:
			still_active_events.append(event_packet)

	active_events = still_active_events

	if not found_event:
		result["blocked_reason"] = "event_id_not_found"

		if Globals.debug_eventManager:
			print(
				"EventManager.cancel_event() blocked: event_id_not_found. ",
				"event_id=", event_id
			)

	if Globals.debug_eventManager:
		print(
			"EventManager.cancel_event() finished. ",
			"cancelled=", result["cancelled"],
			" blocked_reason=", result["blocked_reason"],
			" remaining_active_count=", active_events.size()
		)

	return result
	
	
	
	
func disrupt_next_event_for_side(side: String, reason := "", delay_seconds: float = 1.5, excluded_event_id: String = "") -> Dictionary:
	# Summary: Push back the next active TODO for one side without cancelling it or touching resource reservations.
	var clean_side := side.strip_edges().to_lower()
	var safe_delay = max(float(delay_seconds), 0.0)
	var result := {
		"disrupted": false,
		"event_id": "",
		"event_side": clean_side,
		"delay_seconds": safe_delay,
		"old_time_remaining": 0.0,
		"new_time_remaining": 0.0,
		"blocked_reason": "",
		"reason": reason,
		"labels": ["todo_event_pipeline_disrupt"]
	}

	if clean_side == "":
		result["blocked_reason"] = "missing_side"
		return result
	if safe_delay <= 0.0:
		result["blocked_reason"] = "missing_delay"
		return result
	if active_events.is_empty():
		result["blocked_reason"] = "no_active_events"
		return result

	var best_index := -1
	var best_time_remaining := INF
	for i in range(active_events.size()):
		var event_packet = active_events[i]
		if not is_event_disruptible_for_side(event_packet, clean_side, excluded_event_id):
			continue
		var time_remaining = max(float(event_packet.get("time_remaining", 0.0)), 0.0)
		if time_remaining < best_time_remaining:
			best_time_remaining = time_remaining
			best_index = i

	if best_index < 0:
		result["blocked_reason"] = "no_disruptible_event"
		return result

	var target_event: Dictionary = active_events[best_index]
	var old_time = max(float(target_event.get("time_remaining", 0.0)), 0.0)
	var new_time = old_time + safe_delay
	target_event["time_remaining"] = new_time
	target_event["pipeline_disrupted"] = true
	target_event["pipeline_disrupt_reason"] = reason
	target_event["pipeline_disrupt_count"] = int(target_event.get("pipeline_disrupt_count", 0)) + 1
	active_events[best_index] = target_event

	result["disrupted"] = true
	result["event_id"] = str(target_event.get("event_id", ""))
	result["old_time_remaining"] = old_time
	result["new_time_remaining"] = new_time
	result["labels"].append("todo_event_disrupted")
	return result
	
	
func nullify_next_event_for_side(side: String, reason := "", excluded_event_id: String = "", source_event_id: String = "") -> Dictionary:
	# Summary: Mark the nearest active TODO for one side so it keeps moving but resolves as null at the finish gate.
	var clean_side := side.strip_edges().to_lower()
	var result := {
		"nullified": false,
		"event_id": "",
		"event_side": clean_side,
		"blocked_reason": "",
		"reason": reason,
		"source_event_id": source_event_id,
		"labels": ["todo_event_resolution_gate"]
	}

	if clean_side == "":
		result["blocked_reason"] = "missing_side"
		return result
	if active_events.is_empty():
		result["blocked_reason"] = "no_active_events"
		return result

	var best_index := -1
	var best_time_remaining := INF
	for i in range(active_events.size()):
		var event_packet = active_events[i]
		if not is_event_disruptible_for_side(event_packet, clean_side, excluded_event_id):
			continue
		if str(event_packet.get("resolution_gate_state", "")).strip_edges().to_lower() == "null":
			continue
		var time_remaining = max(float(event_packet.get("time_remaining", 0.0)), 0.0)
		if time_remaining < best_time_remaining:
			best_time_remaining = time_remaining
			best_index = i

	if best_index < 0:
		result["blocked_reason"] = "no_gate_target"
		return result

	var target_event: Dictionary = active_events[best_index]
	var existing_labels := []
	if typeof(target_event.get("labels", [])) == TYPE_ARRAY:
		existing_labels = target_event.get("labels", [])
	existing_labels.append("todo_event_nullified")
	existing_labels.append("todo_event_resolution_gate_null")

	target_event["resolution_gate_state"] = "null"
	target_event["resolution_gate_reason"] = reason
	target_event["resolution_gate_source_event_id"] = source_event_id
	target_event["lane_intervention_type"] = "nullify"
	target_event["lane_intervention_reason"] = reason
	target_event["labels"] = existing_labels
	active_events[best_index] = target_event

	result["nullified"] = true
	result["event_id"] = str(target_event.get("event_id", ""))
	result["time_remaining"] = best_time_remaining
	result["labels"].append("todo_event_nullified")
	return result
	
	
func is_event_disruptible_for_side(event_packet, side: String, excluded_event_id: String = "") -> bool:
	if typeof(event_packet) != TYPE_DICTIONARY:
		return false
	if str(event_packet.get("lifecycle_state", "active")).strip_edges().to_lower() != "active":
		return false
	if excluded_event_id.strip_edges() != "" and str(event_packet.get("event_id", "")) == excluded_event_id:
		return false
	if str(event_packet.get("event_side", "")).strip_edges().to_lower() != side:
		return false

	var event_group := str(event_packet.get("event_group", "")).strip_edges().to_lower()
	var event_type := str(event_packet.get("event_type", "")).strip_edges().to_lower()
	var event_subtype := str(event_packet.get("event_subtype", "")).strip_edges().to_lower()
	var data_payload = event_packet.get("data", {})
	if typeof(data_payload) == TYPE_DICTIONARY and bool(data_payload.get("evade_relock", false)):
		return false
	if event_group == "evade" or event_type.ends_with("_lock_restore") or event_subtype == "lock_restore":
		return false
	if bool(event_packet.get("is_visual_only", false)):
		return false
	return true
	
	
func debug_print_active_events() -> void:
	# Full purpose summary:
	# Print the current active TODO timing list for EventManager debugging without changing any event state.

	# This function is debug-only.
	# It does not tick countdowns.
	# It does not complete events.
	# It does not remove events.
	# It does not hand off batches.
	# It does not resolve gameplay.

	if not Globals.debug_eventManager:
		return

	print("EventManager.debug_print_active_events() active_count=", active_events.size())

	for event_packet in active_events:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		print(
			"  ACTIVE TODO | ",
			"event_id=", event_packet.get("event_id", ""),
			" event_type=", event_packet.get("event_type", ""),
			" owner_unit=", event_packet.get("owner_unit", null),
			" same_type_key=", event_packet.get("same_type_key", ""),
			" time_remaining=", event_packet.get("time_remaining", 0.0),
			" lifecycle_state=", event_packet.get("lifecycle_state", "")
		)


func debug_print_completed_batch() -> void:
	# Full purpose summary:
	# Print the current completed_event_batch timing snapshot for EventManager debugging without changing the batch.

	# This function is debug-only.
	# It only inspects the latest completed batch.
	# It does not sort events.
	# It does not resolve events.
	# It does not clear the batch.
	# It does not call BattleManager.

	if not Globals.debug_eventManager:
		return

	print("EventManager.debug_print_completed_batch() batch_size=", completed_event_batch.size())

	for event_packet in completed_event_batch:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		print(
			"  COMPLETED TODO | ",
			"event_id=", event_packet.get("event_id", ""),
			" event_type=", event_packet.get("event_type", ""),
			" owner_unit=", event_packet.get("owner_unit", null),
			" same_type_key=", event_packet.get("same_type_key", ""),
			" completion_timestamp=", event_packet.get("completion_timestamp", null),
			" lifecycle_state=", event_packet.get("lifecycle_state", "")
		)


func debug_print_handoff_result() -> void:
	# Full purpose summary:
	# Print the latest EventManager completed-batch handoff result for debugging without changing handoff state.

	# This function is debug-only.
	# It only prints last_handoff_result.
	# It does not resend the batch.
	# It does not alter acknowledgement.
	# It does not resolve gameplay.

	if not Globals.debug_eventManager:
		return

	print("EventManager.debug_print_handoff_result() result=", last_handoff_result)
	
	
func get_active_events_for_side(side: String) -> Array:
	# Full purpose summary:
	# Return active TODO timing events for one event_side without changing EventManager state.

	# EventManager owns active TODO storage.
	# This helper is read-only.
	# It does not tick countdowns.
	# It does not complete events.
	# It does not resolve gameplay.
	# It does not cancel events.

	var output: Array = []
	var clean_side := side.strip_edges().to_lower()

	if clean_side == "":
		return output

	for event_packet in active_events:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		if event_packet.get("lifecycle_state", "active") != "active":
			continue

		var event_side := str(event_packet.get("event_side", "")).strip_edges().to_lower()

		if event_side == clean_side:
			output.append(event_packet.duplicate(true))

	return output
	
	
func has_active_event_for_side(side: String) -> bool:
	return not get_active_events_for_side(side).is_empty()
