extends RefCounted
class_name OrbitItemOperationBridge


const ItemDbBuilderScript = preload("res://Control/Control/items/item_db_builder.gd")
const RESOURCE_ROVER_ITEM_ID := "planetary_resource_rover"
const RECOVERY_LAUNCHER_ITEM_ID := "planet_recovery_launcher"
const MAX_RESULT_HISTORY := 60

var item_db: Dictionary = ItemDbBuilderScript.build()


func should_offer_action(snapshot: Dictionary, planet_id: String, marker_id: String, action: Dictionary) -> bool:
	var action_kind := resolve_action_kind(action)
	if action_kind == "":
		return true
	if is_action_kind_completed(snapshot, planet_id, marker_id, action_kind):
		return false
	if action_kind == "recover_to_orbit":
		return is_action_kind_completed(snapshot, planet_id, marker_id, "explore")
	return true


func execute(snapshot: Dictionary, planet: Dictionary, marker: Dictionary, action: Dictionary) -> Dictionary:
	var planet_id := str(planet.get("object_id", planet.get("id", ""))).strip_edges()
	var planet_name := str(planet.get("display_name", planet.get("scan_name", planet_id))).strip_edges()
	var marker_id := str(marker.get("id", marker.get("entry_id", "planet_marker"))).strip_edges()
	var marker_title := get_marker_title(marker)
	var action_id := str(action.get("id", action.get("operation_id", "orbit_item_action"))).strip_edges()
	var action_kind := resolve_action_kind(action)
	var result := {
		"ok": false,
		"status": "blocked_invalid_action",
		"operation_id": action_id,
		"operation_kind": action_kind,
		"operation_label": str(action.get("label", action_id)),
		"planet_id": planet_id,
		"planet_name": planet_name,
		"marker_id": marker_id,
		"marker_title": marker_title,
		"consumed_items": {},
		"granted_items": {},
		"completed_at_unix": int(Time.get_unix_time_from_system()),
		"completed_at_text": get_datetime_text()
	}

	if action_kind == "":
		result["reason"] = "This marker action has no supported orbit item operation."
		result["summary_line"] = result["reason"]
		return result

	if is_action_kind_completed(snapshot, planet_id, marker_id, action_kind):
		result["status"] = "already_completed"
		result["reason"] = marker_title + " already completed this orbit operation."
		result["summary_line"] = result["reason"]
		return result

	if action_kind == "recover_to_orbit" and not is_action_kind_completed(snapshot, planet_id, marker_id, "explore"):
		result["status"] = "blocked_requires_exploration"
		result["reason"] = "Deploy a Planetary Resource Rover at " + marker_title + " before recovery."
		result["summary_line"] = result["reason"]
		return result

	var inventory = snapshot.get("inventory", {})
	if typeof(inventory) != TYPE_DICTIONARY:
		inventory = {}
	var inventory_transaction: Dictionary = inventory.duplicate(true)
	ensure_inventory_shape(inventory_transaction)

	var required_counts := collect_item_counts(action.get("requires_orbit_items", []))
	var consume_counts := collect_item_counts(action.get("consume_orbit_items", []))
	var missing_items := find_missing_inventory_items(inventory_transaction, required_counts)
	if not missing_items.is_empty():
		result["status"] = "blocked_missing_items"
		result["missing_items"] = missing_items
		result["reason"] = "Missing orbit tool: " + format_item_totals(missing_items) + "."
		result["summary_line"] = result["reason"]
		return result

	var recovery_payload := {}
	if action_kind == "recover_to_orbit":
		recovery_payload = get_recovery_payload(snapshot, planet_id, marker_id, marker, action, planet)
		if recovery_payload.is_empty():
			result["status"] = "blocked_no_authored_payload"
			result["reason"] = marker_title + " has no authored recoverable items remaining."
			result["summary_line"] = result["reason"]
			return result

	if bool(action.get("consume_on_success", action.get("consumed_on_use", false))):
		if not consume_inventory_items(inventory_transaction, consume_counts):
			result["status"] = "blocked_consume_failed"
			result["reason"] = "Orbit tool consumption could not be completed."
			result["summary_line"] = result["reason"]
			return result

	if action_kind == "recover_to_orbit":
		if not add_inventory_items(inventory_transaction, recovery_payload):
			result["status"] = "blocked_inventory_full"
			result["reason"] = "Recovery launch blocked: cargo has no room for " + format_item_totals(recovery_payload) + "."
			result["summary_line"] = result["reason"]
			return result

	snapshot["inventory"] = inventory_transaction
	result["ok"] = true
	result["status"] = "completed"
	result["consumed_items"] = consume_counts.duplicate(true)
	result["granted_items"] = recovery_payload.duplicate(true)

	if action_kind == "explore":
		var detected_payload := extract_recovery_payload(marker, action, planet)
		result["resource_data"] = detected_payload.duplicate(true)
		result["summary_line"] = marker_title + " explored. Rover telemetry mapped the authored resource site."
		if not detected_payload.is_empty():
			result["summary_line"] += " Detected: " + format_item_totals(detected_payload) + "."
	else:
		result["summary_line"] = marker_title + " recovery complete. Cargo received " + format_item_totals(recovery_payload) + "."

	record_completed_operation(snapshot, result)
	return result


func resolve_action_kind(action: Dictionary) -> String:
	var explicit_kind := str(action.get("planetary_resource_action", "")).strip_edges().to_lower()
	if explicit_kind in ["explore", "recover_to_orbit"]:
		return explicit_kind

	var operation_id := str(action.get("id", action.get("operation_id", ""))).strip_edges().to_lower()
	if operation_id == "planetary_rover_explore":
		return "explore"
	if operation_id == "planet_recovery_launch":
		return "recover_to_orbit"

	var required := collect_item_counts(action.get("requires_orbit_items", []))
	if required.has(RESOURCE_ROVER_ITEM_ID):
		return "explore"
	if required.has(RECOVERY_LAUNCHER_ITEM_ID):
		return "recover_to_orbit"
	return ""


func is_action_kind_completed(snapshot: Dictionary, planet_id: String, marker_id: String, action_kind: String) -> bool:
	var operations = snapshot.get("orbit_operations", {})
	if typeof(operations) != TYPE_DICTIONARY:
		return false
	var completions = operations.get("planet_item_action_completions", {})
	if typeof(completions) != TYPE_DICTIONARY:
		return false
	return completions.has(make_completion_key(planet_id, marker_id, action_kind))


func record_completed_operation(snapshot: Dictionary, result: Dictionary) -> void:
	var operations = snapshot.get("orbit_operations", {})
	if typeof(operations) != TYPE_DICTIONARY:
		operations = {}

	var completions = operations.get("planet_item_action_completions", {})
	if typeof(completions) != TYPE_DICTIONARY:
		completions = {}
	var completion_key := make_completion_key(
		str(result.get("planet_id", "")),
		str(result.get("marker_id", "")),
		str(result.get("operation_kind", ""))
	)
	completions[completion_key] = result.duplicate(true)
	operations["planet_item_action_completions"] = completions

	var sites = operations.get("planet_resource_site_state", {})
	if typeof(sites) != TYPE_DICTIONARY:
		sites = {}
	var site_key := make_site_key(str(result.get("planet_id", "")), str(result.get("marker_id", "")))
	var site_state = sites.get(site_key, {})
	if typeof(site_state) != TYPE_DICTIONARY:
		site_state = {}
	if str(result.get("operation_kind", "")) == "explore":
		site_state["explored"] = true
		site_state["explored_at_unix"] = int(result.get("completed_at_unix", 0))
		site_state["explored_at_text"] = str(result.get("completed_at_text", ""))
		site_state["detected_items"] = result.get("resource_data", {}).duplicate(true)
	else:
		site_state["recovered"] = true
		site_state["recovered_at_unix"] = int(result.get("completed_at_unix", 0))
		site_state["recovered_at_text"] = str(result.get("completed_at_text", ""))
		site_state["recovered_items"] = result.get("granted_items", {}).duplicate(true)
		site_state["remaining_items"] = {}
	sites[site_key] = site_state
	operations["planet_resource_site_state"] = sites

	var history = operations.get("planet_item_action_result_history", [])
	if typeof(history) != TYPE_ARRAY:
		history = []
	history.append(result.duplicate(true))
	while history.size() > MAX_RESULT_HISTORY:
		history.pop_front()
	operations["planet_item_action_result_history"] = history
	snapshot["orbit_operations"] = operations


func get_recovery_payload(snapshot: Dictionary, planet_id: String, marker_id: String, marker: Dictionary, action: Dictionary, planet: Dictionary) -> Dictionary:
	var operations = snapshot.get("orbit_operations", {})
	if typeof(operations) == TYPE_DICTIONARY:
		var sites = operations.get("planet_resource_site_state", {})
		if typeof(sites) == TYPE_DICTIONARY:
			var site_state = sites.get(make_site_key(planet_id, marker_id), {})
			if typeof(site_state) == TYPE_DICTIONARY:
				if bool(site_state.get("recovered", false)):
					return {}
				var remaining = site_state.get("remaining_items", null)
				if typeof(remaining) == TYPE_DICTIONARY:
					return remaining.duplicate(true)
	return extract_recovery_payload(marker, action, planet)


func extract_recovery_payload(marker: Dictionary, action: Dictionary, planet: Dictionary) -> Dictionary:
	var totals := {}
	append_payload_from_source(totals, marker.get("origin_packet", {}))
	append_payload_from_source(totals, action)
	if totals.is_empty():
		append_payload_from_source(totals, planet)
	return totals


func append_payload_from_source(totals: Dictionary, raw_source) -> void:
	if typeof(raw_source) != TYPE_DICTIONARY:
		return
	var source: Dictionary = raw_source
	for key in ["resources", "resource_mix", "planet_resources", "recovery_items", "recoverable_items", "items"]:
		append_payload_value(totals, source.get(key, null))
	if totals.is_empty():
		var item_id := str(source.get("resource_id", source.get("item_id", ""))).strip_edges()
		var amount := int(source.get("remaining_amount", source.get("amount", 0)))
		append_payload_item(totals, item_id, amount)


func append_payload_value(totals: Dictionary, value) -> void:
	if typeof(value) == TYPE_DICTIONARY:
		for raw_item_id in value.keys():
			var raw_amount = value.get(raw_item_id, 0)
			if typeof(raw_amount) == TYPE_DICTIONARY:
				var packet: Dictionary = raw_amount
				append_payload_item(totals, str(packet.get("item_id", raw_item_id)), int(packet.get("remaining_amount", packet.get("amount", packet.get("count", 0)))))
			else:
				append_payload_item(totals, str(raw_item_id), int(raw_amount))
	elif typeof(value) == TYPE_ARRAY:
		for entry in value:
			if typeof(entry) == TYPE_DICTIONARY:
				var packet: Dictionary = entry
				append_payload_item(totals, str(packet.get("item_id", packet.get("resource_id", packet.get("id", "")))), int(packet.get("remaining_amount", packet.get("amount", packet.get("count", 1)))))
			elif typeof(entry) == TYPE_STRING:
				append_payload_item(totals, str(entry), 1)


func append_payload_item(totals: Dictionary, item_id: String, amount: int) -> void:
	var clean_id := item_id.strip_edges()
	if clean_id == "" or amount <= 0 or not item_db.has(clean_id):
		return
	totals[clean_id] = int(totals.get(clean_id, 0)) + amount


func collect_item_counts(raw_items) -> Dictionary:
	var totals := {}
	if typeof(raw_items) == TYPE_STRING:
		append_payload_item(totals, str(raw_items), 1)
	elif typeof(raw_items) == TYPE_ARRAY:
		for raw_item in raw_items:
			if typeof(raw_item) == TYPE_DICTIONARY:
				var packet: Dictionary = raw_item
				append_payload_item(totals, str(packet.get("item_id", packet.get("id", ""))), int(packet.get("amount", packet.get("count", 1))))
			else:
				append_payload_item(totals, str(raw_item), 1)
	elif typeof(raw_items) == TYPE_DICTIONARY:
		append_payload_value(totals, raw_items)
	return totals


func ensure_inventory_shape(inventory: Dictionary) -> void:
	if typeof(inventory.get("main", {})) != TYPE_DICTIONARY:
		inventory["main"] = {}
	if typeof(inventory.get("drones", {})) != TYPE_DICTIONARY:
		inventory["drones"] = {}


func find_missing_inventory_items(inventory: Dictionary, required_counts: Dictionary) -> Dictionary:
	var missing := {}
	for item_id in required_counts.keys():
		var needed := int(required_counts.get(item_id, 0))
		var owned := count_inventory_item(inventory, str(item_id))
		if owned < needed:
			missing[str(item_id)] = needed - owned
	return missing


func count_inventory_item(inventory: Dictionary, item_id: String) -> int:
	var total := 0
	for container_name in ["main", "drones"]:
		var slots = inventory.get(container_name, {})
		if typeof(slots) != TYPE_DICTIONARY:
			continue
		for slot_name in slots.keys():
			var slot = slots.get(slot_name, {})
			if typeof(slot) == TYPE_DICTIONARY and str(slot.get("item_id", "")) == item_id:
				total += max(int(slot.get("count", 0)), 0)
	return total


func consume_inventory_items(inventory: Dictionary, consume_counts: Dictionary) -> bool:
	if not find_missing_inventory_items(inventory, consume_counts).is_empty():
		return false
	for item_id in consume_counts.keys():
		var remaining := int(consume_counts.get(item_id, 0))
		for container_name in ["main", "drones"]:
			var slots = inventory.get(container_name, {})
			if typeof(slots) != TYPE_DICTIONARY:
				continue
			for slot_name in slots.keys():
				var slot = slots.get(slot_name, {})
				if typeof(slot) != TYPE_DICTIONARY or str(slot.get("item_id", "")) != str(item_id):
					continue
				var take = min(max(int(slot.get("count", 0)), 0), remaining)
				slot["count"] = int(slot.get("count", 0)) - take
				remaining -= take
				if int(slot.get("count", 0)) <= 0:
					slot["item_id"] = ""
					slot["count"] = 0
				slots[slot_name] = slot
				if remaining <= 0:
					break
			inventory[container_name] = slots
			if remaining <= 0:
				break
		if remaining > 0:
			return false
	return true


func add_inventory_items(inventory: Dictionary, item_totals: Dictionary) -> bool:
	var main_slots = inventory.get("main", {})
	if typeof(main_slots) != TYPE_DICTIONARY:
		return false

	for item_id in item_totals.keys():
		var clean_id := str(item_id).strip_edges()
		var remaining := int(item_totals.get(item_id, 0))
		if clean_id == "" or remaining <= 0 or not item_db.has(clean_id):
			return false
		var item_data: Dictionary = item_db.get(clean_id, {})
		var stackable := bool(item_data.get("stackable", false))
		var max_stack = max(int(item_data.get("max_stack", 1)), 1)

		if stackable:
			for slot_name in main_slots.keys():
				var slot = main_slots.get(slot_name, {})
				if typeof(slot) != TYPE_DICTIONARY or str(slot.get("item_id", "")) != clean_id:
					continue
				var room = max(max_stack - int(slot.get("count", 0)), 0)
				var add_count = min(room, remaining)
				slot["count"] = int(slot.get("count", 0)) + add_count
				remaining -= add_count
				main_slots[slot_name] = slot
				if remaining <= 0:
					break

		while remaining > 0:
			var empty_slot_name := find_empty_inventory_slot(main_slots)
			if empty_slot_name == "":
				return false
			var add_count = min(max_stack if stackable else 1, remaining)
			main_slots[empty_slot_name] = {"item_id": clean_id, "count": add_count}
			remaining -= add_count

	inventory["main"] = main_slots
	return true


func find_empty_inventory_slot(slots: Dictionary) -> String:
	for slot_name in slots.keys():
		var slot = slots.get(slot_name, {})
		if typeof(slot) == TYPE_DICTIONARY and (str(slot.get("item_id", "")) == "" or int(slot.get("count", 0)) <= 0):
			return str(slot_name)
	return ""


func get_marker_title(marker: Dictionary) -> String:
	for key in ["title", "label", "display_name", "entry_id", "id"]:
		var value := str(marker.get(key, "")).strip_edges()
		if value != "":
			return value
	return "Planet Marker"


func make_completion_key(planet_id: String, marker_id: String, action_kind: String) -> String:
	return planet_id + "|" + marker_id + "|" + action_kind


func make_site_key(planet_id: String, marker_id: String) -> String:
	return planet_id + "|" + marker_id


func format_item_totals(totals: Dictionary) -> String:
	var parts := []
	var item_ids := totals.keys()
	item_ids.sort()
	for item_id in item_ids:
		parts.append(str(item_id).replace("_", " ").capitalize() + " x" + str(int(totals.get(item_id, 0))))
	return ", ".join(parts)


func get_datetime_text() -> String:
	var date := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(date.get("year", 0)),
		int(date.get("month", 0)),
		int(date.get("day", 0)),
		int(date.get("hour", 0)),
		int(date.get("minute", 0)),
		int(date.get("second", 0))
	]
