extends Node
class_name AmmoHandler


# ==========================================================
# AMMO HANDLER
# ----------------------------------------------------------
# Inventory owns actual ammo stacks.
# AmmoHandler owns battle ammo reservation, availability checks,
# ammo damage lookup, and spend/release result packets.
# ==========================================================

const AMMO_GROUPS := ["small", "medium", "large"]

var reserved_ammo := {
	"small": 0,
	"medium": 0,
	"large": 0
}


func get_ammo_count(ammo_group: String, inventory_ref) -> int:
	# Summary: Count ammo stacks for one official ammo group from Inventory or a Battle V2 snapshot source.
	var group := normalize_ammo_group(ammo_group)
	if not is_valid_ammo_group(group):
		return 0
	if inventory_ref == null:
		return 0

	var total := 0
	for item_id in get_ammo_item_ids_for_group(group, inventory_ref):
		total += get_inventory_item_count(inventory_ref, item_id)

	return total


func get_reserved_ammo(ammo_group: String) -> int:
	# Summary: Return battle-reserved ammo for one group.
	var group := normalize_ammo_group(ammo_group)
	if not is_valid_ammo_group(group):
		return 0
	return int(reserved_ammo.get(group, 0))


func get_available_ammo(ammo_group: String, inventory_ref) -> int:
	# Summary: Return stack count minus battle reservations.
	var group := normalize_ammo_group(ammo_group)
	if not is_valid_ammo_group(group):
		return 0
	return max(get_ammo_count(group, inventory_ref) - get_reserved_ammo(group), 0)


func can_reserve_ammo(ammo_group: String, amount: int, inventory_ref) -> bool:
	# Summary: Check whether another queued action may reserve this ammo.
	var group := normalize_ammo_group(ammo_group)
	if amount <= 0:
		return true
	if not is_valid_ammo_group(group):
		return false
	return get_available_ammo(group, inventory_ref) >= amount


func reserve_ammo(ammo_group: String, amount: int, inventory_ref) -> Dictionary:
	# Summary: Reserve expected ammo use when a battle TODO is queued.
	var group := normalize_ammo_group(ammo_group)
	var cost: int = max(amount, 0)

	if cost <= 0:
		return make_result(
			"success",
			"",
			["ammo_available_check"],
			{
				"ammo_group": group,
				"ammo_cost": 0,
				"reserved_ammo": get_reserved_ammo(group),
				"available_ammo": get_available_ammo(group, inventory_ref)
			}
		)

	if not is_valid_ammo_group(group):
		return make_result(
			"failed",
			"invalid ammo group",
			["ammo_reserve_failed", "ammo_inventory_required"],
			{
				"ammo_group": group,
				"ammo_cost": cost
			}
		)

	if not can_reserve_ammo(group, cost, inventory_ref):
		return make_result(
			"failed",
			"not enough available ammo",
			["ammo_available_check", "ammo_reserve_failed", "battle_action_population_reserved_ammo_block"],
			{
				"ammo_group": group,
				"ammo_cost": cost,
				"reserved_ammo": get_reserved_ammo(group),
				"available_ammo": get_available_ammo(group, inventory_ref)
			}
		)

	reserved_ammo[group] = get_reserved_ammo(group) + cost
	return make_result(
		"success",
		"",
		["ammo_available_check", "ammo_reserved", "ammo_reserve_success"],
		{
			"ammo_group": group,
			"ammo_cost": cost,
			"reserved_ammo": get_reserved_ammo(group),
			"available_ammo": get_available_ammo(group, inventory_ref)
		}
	)


func spend_reserved_ammo(ammo_group: String, amount: int, inventory_ref) -> Dictionary:
	# Summary: Spend already-reserved ammo from Inventory/snapshot when the TODO completes.
	var group := normalize_ammo_group(ammo_group)
	var cost: int = max(amount, 0)

	if cost <= 0:
		return make_result("success", "", ["ammo_spend_on_todo_complete"], {"ammo_group": group, "ammo_cost": 0})

	if not is_valid_ammo_group(group):
		return make_result("failed", "invalid ammo group", ["ammo_spend_on_todo_complete"], {"ammo_group": group, "ammo_cost": cost})

	if get_reserved_ammo(group) < cost:
		return make_result(
			"failed",
			"reserved ammo below spend cost",
			["ammo_spend_on_todo_complete"],
			{
				"ammo_group": group,
				"ammo_cost": cost,
				"reserved_ammo": get_reserved_ammo(group)
			}
		)

	if not consume_ammo_group(group, cost, inventory_ref):
		return make_result(
			"failed",
			"inventory ammo spend failed",
			["ammo_spend_on_todo_complete", "ammo_inventory_required"],
			{
				"ammo_group": group,
				"ammo_cost": cost,
				"reserved_ammo": get_reserved_ammo(group),
				"inventory_ammo": get_ammo_count(group, inventory_ref)
			}
		)

	reserved_ammo[group] = max(get_reserved_ammo(group) - cost, 0)
	return make_result(
		"success",
		"",
		["ammo_spend_on_todo_complete", "ammo_spend_success"],
		{
			"ammo_group": group,
			"ammo_cost": cost,
			"reserved_ammo": get_reserved_ammo(group),
			"available_ammo": get_available_ammo(group, inventory_ref),
			"inventory_save_data": get_inventory_save_data_from_source(inventory_ref)
		}
	)


func release_reserved_ammo(ammo_group: String, amount: int) -> Dictionary:
	# Summary: Release expected ammo use when a queued TODO is cancelled/rejected.
	var group := normalize_ammo_group(ammo_group)
	var cost: int = max(amount, 0)
	if not is_valid_ammo_group(group):
		return make_result("failed", "invalid ammo group", ["ammo_release_success"], {"ammo_group": group, "ammo_cost": cost})

	reserved_ammo[group] = max(get_reserved_ammo(group) - cost, 0)
	return make_result(
		"success",
		"",
		["ammo_release_success"],
		{
			"ammo_group": group,
			"ammo_cost": cost,
			"reserved_ammo": get_reserved_ammo(group)
		}
	)


func clear_reserved_ammo() -> Dictionary:
	# Summary: Clear all battle-only ammo reservations without changing inventory stacks.
	for group in AMMO_GROUPS:
		reserved_ammo[group] = 0

	return make_result(
		"success",
		"reserved ammo cleared",
		["ammo_cleanup"],
		{
			"reserved_ammo": reserved_ammo.duplicate()
		}
	)


func can_fire_weapon(weapon_data: Dictionary, inventory_ref) -> bool:
	# Summary: Return true when the selected weapon has enough available ammo to queue.
	var ammo_group := get_weapon_ammo_group(weapon_data)
	var total_cost := get_weapon_ammo_cost(weapon_data)
	if total_cost <= 0:
		return true
	return can_reserve_ammo(ammo_group, total_cost, inventory_ref)


func reserve_weapon_ammo(weapon_data: Dictionary, inventory_ref) -> Dictionary:
	# Summary: Convenience wrapper for queue-time weapon ammo reservation.
	return reserve_ammo(get_weapon_ammo_group(weapon_data), get_weapon_ammo_cost(weapon_data), inventory_ref)


func get_weapon_ammo_cost(weapon_data: Dictionary) -> int:
	# Summary: Calculate total ammo cost from weapon burst fields.
	var total_cost := int(weapon_data.get("total_ammo_cost", -1))
	if total_cost >= 0:
		return total_cost

	var ammo_group := get_weapon_ammo_group(weapon_data)
	if ammo_group == "":
		return 0

	var ammo_per_burst := get_weapon_ammo_per_burst(weapon_data)
	var burst_count := get_weapon_burst_count(weapon_data)
	return max(ammo_per_burst * burst_count, 0)


func get_weapon_ammo_group(weapon_data: Dictionary) -> String:
	# Summary: Read and normalize the weapon's required ammo group.
	return normalize_ammo_group(str(weapon_data.get("ammo_group", "")))


func get_weapon_ammo_per_burst(weapon_data: Dictionary) -> int:
	# Summary: Read ammo per burst, supporting the older ammo_cost field.
	if weapon_data.has("ammo_per_burst"):
		return max(int(weapon_data.get("ammo_per_burst", 0)), 0)
	return max(int(weapon_data.get("ammo_cost", 0)), 0)


func get_weapon_burst_count(weapon_data: Dictionary) -> int:
	# Summary: Read the number of bursts this weapon applies when the TODO resolves.
	return max(int(weapon_data.get("burst_count", 1)), 1)


func get_ammo_damage(ammo_group: String, inventory_ref) -> int:
	# Summary: Read the ammo damage bonus for the best available ammo stack in this group.
	var group := normalize_ammo_group(ammo_group)
	if not is_valid_ammo_group(group):
		return 0

	var best_damage := 0

	for item_id in get_ammo_item_ids_for_group(group, inventory_ref):
		if get_inventory_item_count(inventory_ref, item_id) <= 0:
			continue
		var item_data: Dictionary = get_item_data_from_inventory_source(inventory_ref, item_id)
		best_damage = max(best_damage, get_item_damage_value(item_data, "ammo_damage", 0))

	return best_damage


func build_ammo_damage_packet(weapon_data: Dictionary, inventory_ref) -> Dictionary:
	# Summary: Build the ammo math slice PacketBuilder can place into the event packet.
	var ammo_group := get_weapon_ammo_group(weapon_data)
	var ammo_per_burst := get_weapon_ammo_per_burst(weapon_data)
	var burst_count := get_weapon_burst_count(weapon_data)
	var total_ammo_cost := get_weapon_ammo_cost(weapon_data)
	var weapon_damage := get_item_damage_value(weapon_data, "damage_value", get_item_damage_value(weapon_data, "damage", 0))
	var ammo_damage := get_ammo_damage(ammo_group, inventory_ref)
	var damage_per_burst := weapon_damage + ammo_damage
	var total_damage := damage_per_burst * burst_count
	if Globals.print_priority_5:
		var ammo_debug := {
			"ammo_group": ammo_group,
			"ammo_per_burst": ammo_per_burst,
			"burst_count": burst_count,
			"total_ammo_cost": total_ammo_cost,
			"weapon_damage": weapon_damage,
			"ammo_damage": ammo_damage,
			"damage_per_burst": damage_per_burst,
			"total_damage": total_damage,
			"available_ammo": get_available_ammo(ammo_group, inventory_ref),
			"reserved_ammo": get_reserved_ammo(ammo_group),
			"labels": [
				"ammo_burst_count",
				"ammo_per_burst",
				"ammo_total_cost",
				"ammo_damage_bonus",
				"weapon_damage_plus_ammo_damage"
			]
		}

		
		print("[ammo_burst_debug] ", JSON.stringify(ammo_debug))
	return {
		"ammo_group": ammo_group,
		"ammo_per_burst": ammo_per_burst,
		"burst_count": burst_count,
		"total_ammo_cost": total_ammo_cost,
		"weapon_damage": weapon_damage,
		"ammo_damage": ammo_damage,
		"damage_per_burst": damage_per_burst,
		"total_damage": total_damage,
		"available_ammo": get_available_ammo(ammo_group, inventory_ref),
		"reserved_ammo": get_reserved_ammo(ammo_group),
		"labels": [
			"ammo_burst_count",
			"ammo_per_burst",
			"ammo_total_cost",
			"ammo_damage_bonus",
			"weapon_damage_plus_ammo_damage"
		]
	}


func normalize_ammo_group(ammo_group: String) -> String:
	# Summary: Normalize official ammo group names and legacy *_ammo aliases.
	var group := ammo_group.strip_edges().to_lower()
	if group.ends_with("_ammo"):
		group = group.replace("_ammo", "")
	return group


func is_valid_ammo_group(ammo_group: String) -> bool:
	return AMMO_GROUPS.has(normalize_ammo_group(ammo_group))


func get_ammo_item_ids_for_group(ammo_group: String, inventory_ref) -> Array:
	# Summary: Find item ids in the item database/snapshot that represent an ammo group.
	var group := normalize_ammo_group(ammo_group)
	var item_ids: Array = []
	var item_db := get_item_db_from_inventory_source(inventory_ref)
	if typeof(item_db) != TYPE_DICTIONARY:
		return item_ids

	for item_id in item_db.keys():
		var item_data: Dictionary = item_db.get(item_id, {})
		if item_matches_ammo_group(item_data, group):
			item_ids.append(str(item_id))

	return item_ids


func item_matches_ammo_group(item_data: Dictionary, ammo_group: String) -> bool:
	# Summary: Check whether an item database entry is ammo for a group.
	if item_data.is_empty():
		return false

	var group := normalize_ammo_group(str(item_data.get("ammo_group", "")))
	if group != ammo_group:
		return false

	var item_type := str(item_data.get("item_type", item_data.get("type", ""))).strip_edges().to_lower()
	if item_type == "ammo":
		return true

	var tags = item_data.get("tags", [])
	if typeof(tags) == TYPE_ARRAY and tags.has("ammo"):
		return true

	return false


func consume_ammo_group(ammo_group: String, amount: int, inventory_ref) -> bool:
	# Summary: Consume ammo stacks for one group from Inventory or the Battle V2 snapshot source.
	var group := normalize_ammo_group(ammo_group)
	var remaining: int = max(amount, 0)
	if remaining <= 0:
		return true

	if inventory_ref is Dictionary:
		return consume_ammo_group_from_snapshot(group, remaining, inventory_ref)

	if inventory_ref == null or not inventory_ref.has_method("consume_item"):
		return false

	for item_id in get_ammo_item_ids_for_group(group, inventory_ref):
		var available := get_inventory_item_count(inventory_ref, item_id)
		if available <= 0:
			continue
		var take: int = min(available, remaining)
		if take > 0 and not inventory_ref.consume_item(item_id, take):
			return false
		remaining -= take
		if remaining <= 0:
			return true

	return false


func get_inventory_item_count(inventory_ref, item_id: String) -> int:
	# Summary: Ask Inventory/snapshot for item count without owning the stack.
	if inventory_ref == null:
		return 0
	if inventory_ref is Dictionary:
		return get_snapshot_item_count(inventory_ref, item_id)
	if inventory_ref.has_method("count_item_anywhere"):
		return max(int(inventory_ref.count_item_anywhere(item_id)), 0)
	return 0


func get_inventory_item_handler(inventory_ref):
	# Summary: Read Inventory.item_handler safely.
	if inventory_ref == null:
		return null
	if inventory_ref is Dictionary:
		return null
	if inventory_ref is Object:
		return inventory_ref.get("item_handler")
	return null


func get_item_db_from_inventory_source(inventory_ref) -> Dictionary:
	# Summary: Read item metadata from a Battle V2 snapshot source or live Inventory.item_handler.
	if inventory_ref == null:
		return {}

	if inventory_ref is Dictionary:
		var snapshot_db = inventory_ref.get("item_db_snapshot", {})
		if typeof(snapshot_db) == TYPE_DICTIONARY:
			return snapshot_db
		return {}

	var item_handler = get_inventory_item_handler(inventory_ref)
	if item_handler == null:
		return {}

	var item_db = item_handler.get("item_db")
	if typeof(item_db) == TYPE_DICTIONARY:
		return item_db

	return {}


func get_item_data_from_inventory_source(inventory_ref, item_id: String) -> Dictionary:
	# Summary: Read one item metadata dictionary from either snapshot source or live item handler.
	if inventory_ref is Dictionary:
		var item_db := get_item_db_from_inventory_source(inventory_ref)
		var data = item_db.get(item_id, {})
		if typeof(data) == TYPE_DICTIONARY:
			return data
		return {}

	return get_item_data_from_handler(get_inventory_item_handler(inventory_ref), item_id)


func get_item_data_from_handler(item_handler, item_id: String) -> Dictionary:
	# Summary: Read item metadata through ItemHandler APIs or item_db fallback.
	if item_handler == null:
		return {}
	if item_handler.has_method("get_item_data"):
		var data = item_handler.get_item_data(item_id)
		if typeof(data) == TYPE_DICTIONARY:
			return data

	var item_db = item_handler.get("item_db")
	if typeof(item_db) == TYPE_DICTIONARY:
		return item_db.get(item_id, {})

	return {}


func get_item_damage_value(item_data: Dictionary, key: String, fallback: int) -> int:
	# Summary: Read numeric damage from flat fields or nested stats.
	if item_data.has(key):
		return int(item_data.get(key, fallback))
	var stats = item_data.get("stats", {})
	if typeof(stats) == TYPE_DICTIONARY and stats.has(key):
		return int(stats.get(key, fallback))
	return fallback


func get_inventory_save_data_from_source(inventory_ref) -> Dictionary:
	# Summary: Return updated save-data when AmmoHandler is operating on a snapshot source.
	if inventory_ref is Dictionary:
		var data = inventory_ref.get("inventory_save_data", {})
		if typeof(data) == TYPE_DICTIONARY:
			return data.duplicate(true)
	return {}


func get_inventory_snapshot_from_source(inventory_ref) -> Dictionary:
	# Summary: Read the mutable inventory save-data inside a Battle V2 snapshot source.
	if not (inventory_ref is Dictionary):
		return {}

	var data = inventory_ref.get("inventory_save_data", {})
	if typeof(data) != TYPE_DICTIONARY:
		return {}

	return data


func get_snapshot_item_count(inventory_ref, item_id: String) -> int:
	# Summary: Count matching item stacks in Inventory5 save-data shape.
	var inventory_data := get_inventory_snapshot_from_source(inventory_ref)
	if inventory_data.is_empty():
		return 0

	var total := 0
	for section_name in ["main", "drones"]:
		var section = inventory_data.get(section_name, {})
		if typeof(section) != TYPE_DICTIONARY:
			continue

		for slot_name in section.keys():
			var slot = section.get(slot_name, {})
			if typeof(slot) != TYPE_DICTIONARY:
				continue
			if str(slot.get("item_id", "")) == item_id:
				total += max(int(slot.get("count", 0)), 0)

	return total


func consume_ammo_group_from_snapshot(ammo_group: String, amount: int, inventory_ref: Dictionary) -> bool:
	# Summary: Spend ammo by mutating the Battle V2 inventory snapshot, not a freed main scene Inventory node.
	var inventory_data := get_inventory_snapshot_from_source(inventory_ref)
	if inventory_data.is_empty():
		return false

	var remaining: int = max(amount, 0)
	var ammo_item_ids := get_ammo_item_ids_for_group(ammo_group, inventory_ref)

	for section_name in ["main", "drones"]:
		var section = inventory_data.get(section_name, {})
		if typeof(section) != TYPE_DICTIONARY:
			continue

		for slot_name in section.keys():
			var slot = section.get(slot_name, {})
			if typeof(slot) != TYPE_DICTIONARY:
				continue

			var item_id := str(slot.get("item_id", ""))
			if not ammo_item_ids.has(item_id):
				continue

			var available = max(int(slot.get("count", 0)), 0)
			if available <= 0:
				continue

			var take: int = min(available, remaining)
			slot["count"] = available - take
			if int(slot["count"]) <= 0:
				slot["item_id"] = ""
				slot["count"] = 0

			section[slot_name] = slot
			remaining -= take

			if remaining <= 0:
				inventory_data[section_name] = section
				inventory_ref["inventory_save_data"] = inventory_data
				return true

		inventory_data[section_name] = section

	inventory_ref["inventory_save_data"] = inventory_data
	return false


func make_result(status: String, reason: String, labels: Array = [], data: Dictionary = {}) -> Dictionary:
	# Summary: Build a standard AmmoHandler result packet.
	var result_labels := labels.duplicate()
	for label_id in [
		"ammo_handler",
		"ammo_handler_no_todo_timing",
		"ammo_handler_no_damage_resolution",
		"ammo_handler_no_inventory_ownership"
	]:
		if not result_labels.has(label_id):
			result_labels.append(label_id)

	var result := {
		"status": status,
		"reason": reason,
		"labels": result_labels,
		"data": data.duplicate(true)
	}

	for key in data.keys():
		result[key] = data[key]

	return result
