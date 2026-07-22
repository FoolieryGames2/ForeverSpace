extends Node
class_name EnergyHandler


# ==========================================================
# ENERGY HANDLER
# ----------------------------------------------------------
# Owns battle energy math only.
#
# BLUE  = queued / reserved energy
# GREEN = available energy
# RED   = spent / missing energy
#
# This handler does NOT:
#   - fire weapons
#   - damage enemies
#   - create action buttons
#   - create TODO events
#   - resolve battle outcomes
#
# It only answers:
#   Can energy be reserved?
#   Can reserved energy be spent?
#   How much is reserved / available / spent?
#   Can shields currently receive energy support?
# ==========================================================
var state = WidgetsState5

# ==========================================================
# ENERGY STORAGE
# ==========================================================
var max_energy: float = 400.0
var current_energy: float = 200.0
var reserved_energy: float = 0.0

# Legacy mirror used by the current energy bar and older debug text.
var expected_use: float = 0.0


# ==========================================================
# ENERGY REGEN
# ==========================================================
var regen_per_second: float = 8.0
var regen_enabled: bool = true
var regen_multiplier: float = 1.0

# Legacy name preserved for current main_mode setup calls.
var recharge_rate: float = 8.0


# ==========================================================
# SHIELD ENERGY SUPPORT
# ==========================================================
var shield_drain_per_second: float = 0.0
var shield_drain_active: bool = false
var shield_slider_level: int = 0
var active_shield_id: String = ""
var active_shield_display_name: String = ""

# Legacy names preserved for existing scene calls.
var shield_slider_value: int = 0
var shield_drain_enabled: bool = false


func setup(new_state,start_energy := 100.0, cap := 100.0, recharge := 8.0) -> void:
	# Summary: Configure starting energy, max energy, and prototype regen speed.
	state = new_state
	if Globals.print_priority_3:
		print("EnergyHandler.setup | Configuring energy state.")

	# Store max energy first so the starting value can clamp correctly.
	max_energy = max(float(cap), 0.0)
	current_energy = clamp(float(start_energy), 0.0, max_energy)

	# Reset battle reservation state on setup.
	reserved_energy = 0.0
	expected_use = 0.0

	# Keep old recharge_rate and new regen_per_second names synchronized.
	regen_per_second = float(recharge)
	recharge_rate = regen_per_second

	# Reset default regen and shield support flags.
	regen_enabled = true
	regen_multiplier = 1.0
	shield_drain_active = false
	shield_drain_enabled = false
	shield_slider_level = 0
	shield_slider_value = 0
	active_shield_id = ""
	active_shield_display_name = ""


func get_available_energy() -> float:
	# Summary: Return non-reserved usable energy.
	if Globals.print_priority_3:
		print("EnergyHandler.get_available_energy | Checking available energy.")

	# Keep legacy expected_use mirrored before reporting available energy.
	_sync_expected_use_from_reserved()

	return max(current_energy - reserved_energy, 0.0)


func can_reserve(cost: float) -> bool:
	# Summary: Check whether an action can reserve energy for a queued TODO.
	if Globals.print_priority_3:
		print("EnergyHandler.can_reserve | Cost: ", cost)

	# Negative or zero costs do not need reserve space.
	if cost <= 0.0:
		return true

	# Energy actions cannot reserve while current energy is empty.
	if current_energy <= 0.0:
		return false

	return get_available_energy() >= cost


func reserve_energy(cost: float) -> Dictionary:
	# Summary: Reserve energy when an energy action queues.
	if Globals.print_priority_2:
		print("EnergyHandler.reserve_energy | Reserve request. Cost: ", cost)

	# Zero-cost actions succeed without changing energy state.
	if cost <= 0.0:
		return make_energy_result("success", "", ["energy_handler", "energy_reserved", "energy_reserve_success"])

	# Reject the reserve if available energy cannot cover it.
	if not can_reserve(cost):
		if Globals.print_priority_2:
			print("EnergyHandler.reserve_energy | Reserve failed. Available: ", get_available_energy())
		return make_energy_result(
			"failed",
			"not enough available energy",
			["energy_handler", "energy_reserve_failed"]
		)

	# Reserve happens when the TODO queues, not when it completes.
	reserved_energy += cost
	_clamp_energy_values()

	if Globals.print_priority_2:
		print("EnergyHandler.reserve_energy | Reserve succeeded. Reserved: ", reserved_energy)

	return make_energy_result("success", "", ["energy_handler", "energy_reserved", "energy_reserve_success"])


func release_reserved_energy(cost: float) -> Dictionary:
	# Summary: Release reserved energy without spending current energy.
	if Globals.print_priority_2:
		print("EnergyHandler.release_reserved_energy | Release request. Cost: ", cost)

	# Nothing changes for zero-cost releases.
	if cost <= 0.0:
		return make_energy_result("success", "", ["energy_handler", "energy_release_success"])

	# Release is used for cancel, cleanup, or battle end before TODO completion.
	reserved_energy -= cost
	_clamp_energy_values()

	if Globals.print_priority_2:
		print("EnergyHandler.release_reserved_energy | Reserved after release: ", reserved_energy)

	return make_energy_result("success", "", ["energy_handler", "energy_release_success"])


func spend_reserved_energy(cost: float) -> Dictionary:
	# Summary: Spend already-reserved energy when a TODO completes.
	if Globals.print_priority_2:
		print("EnergyHandler.spend_reserved_energy | Spend request. Cost: ", cost)

	# Zero-cost completion succeeds without changing energy state.
	if cost <= 0.0:
		return make_energy_result(
			"success",
			"",
			["energy_handler", "energy_spend", "energy_spend_success", "energy_spend_on_todo_complete"]
		)

	# Completion spending should come from reserved energy.
	if reserved_energy < cost:
		if Globals.print_priority_1:
			print("EnergyHandler.spend_reserved_energy | Spend failed - missing reserved energy. Reserved: ", reserved_energy)
		return make_energy_result(
			"failed",
			"missing reserved energy",
			["energy_handler", "energy_spend"]
		)

	# Spend happens when the TODO completes.
	current_energy -= cost
	reserved_energy -= cost
	_clamp_energy_values()

	if Globals.print_priority_2:
		print("EnergyHandler.spend_reserved_energy | Spend succeeded. Current: ", current_energy, " Reserved: ", reserved_energy)

	return make_energy_result(
		"success",
		"",
		["energy_handler", "energy_spend", "energy_spend_success", "energy_spend_on_todo_complete"]
	)


func clear_reserved_energy() -> Dictionary:
	# Summary: Clear all reserved energy during battle cleanup or emergency reset.
	if Globals.print_priority_2:
		print("EnergyHandler.clear_reserved_energy | Clearing reserved energy.")

	# Battle cleanup releases reserved energy without spending current energy.
	reserved_energy = 0.0
	_sync_expected_use_from_reserved()
	return make_energy_result("success", "reserved energy cleared", ["energy_handler", "energy_cleanup"])


func restore_energy(amount: float = 0.0, fill_to_max: bool = false) -> Dictionary:
	# Summary: Restore current energy from an approved support consumable without touching reservations.
	if Globals.print_priority_2:
		print("EnergyHandler.restore_energy | Restore request. Amount: ", amount, " fill_to_max: ", fill_to_max)

	var energy_before := current_energy
	if fill_to_max:
		current_energy = max_energy
	else:
		current_energy += max(float(amount), 0.0)

	_clamp_energy_values()

	var result := make_energy_result(
		"success",
		"",
		[
			"energy_handler",
			"energy_restore",
			"energy_recharge_kit_execute"
		]
	)
	result["energy_before"] = energy_before
	result["energy_after"] = current_energy
	result["energy_restored"] = max(current_energy - energy_before, 0.0)
	return result


func shield_has_energy(required_amount := 0.0) -> bool:
	# Summary: Report whether shield systems currently have energy support.
	if Globals.print_priority_3:
		print("EnergyHandler.shield_has_energy | Required amount: ", required_amount)

	# Prototype rule: current energy must be above the requested support amount.
	return current_energy > float(required_amount)


func update_energy(delta: float) -> Dictionary:
	# Summary: Apply per-frame energy regen and shield drain, then return a small state summary.
	if Globals.print_priority_3:
		print("EnergyHandler.update_energy | Updating energy. Delta: ", delta)

	var result := {
		"status": "updated",
		"energy_before": current_energy,
		"shield_drain_applied": 0.0,
		"regen_applied": 0.0,
		"energy_after": current_energy,
		"current_energy": current_energy,
		"reserved_energy": reserved_energy,
		"available_energy": get_available_energy(),
		"shield_has_energy": shield_has_energy(),
		"labels": [
			"energy_handler",
			"energy_handler_no_resolution"
		]
	}

	# Regen feeds the pool first; shield drain then consumes this tick's supply.
	var regen_amount := _apply_regen(delta)
	result["regen_applied"] = regen_amount
	if regen_enabled:
		result["labels"].append("energy_regen_tick")
	else:
		result["labels"].append("energy_regen_disabled")

	var shield_drain_amount := _apply_shield_drain(delta)
	result["shield_drain_applied"] = shield_drain_amount
	if shield_drain_amount > 0.0:
		result["labels"].append("shield_energy_drain_tick")

	# Clamp after both operations so battle math stays stable.
	_clamp_energy_values()

	result["energy_after"] = current_energy
	result["current_energy"] = current_energy
	result["reserved_energy"] = reserved_energy
	result["available_energy"] = get_available_energy()
	result["shield_has_energy"] = shield_has_energy()
	return result


func recharge(delta: float) -> void:
	# Summary: Legacy regen entry point preserved for current main_mode update calls.
	update_energy(delta)


func can_spend(cost: float) -> bool:
	# Summary: Legacy direct-spend check for older code paths.
	return current_energy >= cost


func spend_energy(cost: float) -> bool:
	# Summary: Legacy direct current-energy spend for non-reserved or old code paths.
	if Globals.print_priority_2:
		print("EnergyHandler.spend_energy | Direct spend request. Cost: ", cost)

	# Zero-cost spending succeeds without changing energy.
	if cost <= 0.0:
		return true

	# Direct spending is still available for older non-TODO paths.
	if not can_spend(cost):
		return false

	current_energy -= cost
	_clamp_energy_values()

	return true


func get_queued_energy() -> float:
	# Summary: Return reserved energy for the existing blue energy bar segment.
	_sync_expected_use_from_reserved()
	return clamp(reserved_energy, 0.0, max_energy)


func get_spent_energy() -> float:
	# Summary: Return missing energy for the existing red energy bar segment.
	return max(max_energy - current_energy, 0.0)


func get_queued_ratio() -> float:
	# Summary: Return reserved energy as a max-energy ratio for the UI bar.
	if max_energy <= 0.0:
		return 0.0

	return get_queued_energy() / max_energy


func get_available_ratio() -> float:
	# Summary: Return available energy as a max-energy ratio for the UI bar.
	if max_energy <= 0.0:
		return 0.0

	return get_available_energy() / max_energy


func get_spent_ratio() -> float:
	# Summary: Return spent/missing energy as a max-energy ratio for the UI bar.
	if max_energy <= 0.0:
		return 0.0

	return get_spent_energy() / max_energy


func set_shield_slider_value(value: int) -> void:
	# Summary: Store the shield slider level used by steady shield energy drain.
	shield_slider_level = int(clamp(value, 0, 4))
	shield_slider_value = shield_slider_level


func set_shield_drain_per_second(value: float) -> void:
	# Summary: Store the active shield drain rate used by update_energy.
	shield_drain_per_second = max(value, 0.0)


func set_shield_drain_enabled(enabled: bool) -> void:
	# Summary: Turn steady shield energy drain on or off.
	shield_drain_active = enabled
	shield_drain_enabled = enabled


func set_active_shield_data(shield_data: Variant) -> Dictionary:
	# Summary: Receive equipped shield data and use only its steady drain value.
	if typeof(shield_data) != TYPE_DICTIONARY:
		return clear_active_shield_drain()

	var shield_packet: Dictionary = shield_data as Dictionary
	if shield_packet.is_empty():
		return clear_active_shield_drain()

	active_shield_id = str(shield_packet.get("item_id", shield_packet.get("id", "")))
	active_shield_display_name = str(shield_packet.get("display_name", shield_packet.get("name", active_shield_id)))

	var drain_value := get_shield_drain_value_from_packet(shield_packet)
	set_shield_drain_per_second(drain_value)
	set_shield_drain_enabled(drain_value > 0.0)

	return make_energy_result(
		"success",
		"",
		["energy_handler", "shield_energy_available_check", "shield_energy_drain_equipped"]
	)


func clear_active_shield_drain() -> Dictionary:
	# Summary: Clear equipped shield drain without changing current or reserved energy.
	active_shield_id = ""
	active_shield_display_name = ""
	set_shield_drain_per_second(0.0)
	set_shield_drain_enabled(false)

	return make_energy_result(
		"success",
		"active shield drain cleared",
		["energy_handler", "shield_energy_drain_cleared"]
	)


func get_shield_drain_value_from_packet(shield_packet: Dictionary) -> float:
	# Summary: Read known shield drain keys from normalized or legacy item packets.
	var direct_drain := get_shield_drain_value_from_source(shield_packet)
	if direct_drain > 0.0:
		return direct_drain

	var source_item = shield_packet.get("source_main_project_item", {})
	if typeof(source_item) == TYPE_DICTIONARY:
		return get_shield_drain_value_from_source(source_item)

	return 0.0


func get_shield_drain_value_from_source(source_data: Dictionary) -> float:
	# Summary: Read shield drain from either flat item data or nested costs data.
	var drain_keys := [
		"steady_energy_drain",
		"shield_drain_per_second",
		"energy_drain_per_second",
		"drain_per_second",
		"energy_drain",
		"energy_cost_per_second"
	]

	for key in drain_keys:
		if source_data.has(key):
			return max(float(source_data.get(key, 0.0)), 0.0)

	var costs = source_data.get("costs", {})
	if typeof(costs) == TYPE_DICTIONARY:
		for key in drain_keys:
			if costs.has(key):
				return max(float(costs.get(key, 0.0)), 0.0)

	return 0.0


func get_shield_slider_percent() -> float:
	# Summary: Convert the approved 0-4 shield slider scale into a 0.0-1.0 percent.
	match shield_slider_level:
		0:
			return 0.0
		1:
			return 0.25
		2:
			return 0.50
		3:
			return 0.75
		4:
			return 1.0
		_:
			return 0.0


func reset_expected_use() -> void:
	# Summary: Legacy cleanup helper that now clears reserved energy.
	clear_reserved_energy()


func reset_full() -> void:
	# Summary: Reset energy to full and clear all reserved energy.
	current_energy = max_energy
	clear_reserved_energy()


func reset_empty() -> void:
	# Summary: Reset energy to empty and clear all reserved energy.
	current_energy = 0.0
	clear_reserved_energy()


func _apply_regen(delta: float) -> float:
	# Summary: Apply current-energy regen for this frame and return the amount added.
	if not regen_enabled:
		if Globals.print_priority_3:
			print("EnergyHandler._apply_regen | Regen disabled.")
		return 0.0

	# Regen uses prototype regen fields and clamps at max energy.
	var before := current_energy
	current_energy = min(current_energy + regen_per_second * regen_multiplier * delta, max_energy)
	return max(current_energy - before, 0.0)


func _apply_shield_drain(delta: float) -> float:
	# Summary: Apply steady shield energy drain for this frame and return the amount removed.
	if not shield_drain_active and not shield_drain_enabled:
		return 0.0

	# A zero slider or zero drain rate means no shield energy is consumed this frame.
	var slider_percent := get_shield_slider_percent()
	if slider_percent <= 0.0 or shield_drain_per_second <= 0.0:
		return 0.0

	if current_energy <= 0.0:
		current_energy = 0.0
		return 0.0

	# Drain can only remove energy that exists. No shield overdraft is allowed.
	var requested_drain = max(shield_drain_per_second * slider_percent * delta, 0.0)
	var applied_drain = min(requested_drain, current_energy)
	current_energy = max(current_energy - applied_drain, 0.0)

	return applied_drain


func _clamp_energy_values() -> void:
	# Summary: Clamp current and reserved energy into safe battle ranges.
	max_energy = max(max_energy, 0.0)
	current_energy = clamp(current_energy, 0.0, max_energy)
	reserved_energy = max(reserved_energy, 0.0)

	_sync_expected_use_from_reserved()


func _sync_expected_use_from_reserved() -> void:
	# Summary: Keep the legacy expected_use value mirrored to reserved_energy.
	expected_use = reserved_energy


func make_energy_result(status: String, reason: String, labels: Array) -> Dictionary:
	# Summary: Build the standard EnergyHandler result packet used by battle bridges.
	var result_labels: Array = labels.duplicate()
	if not result_labels.has("energy_handler"):
		result_labels.append("energy_handler")
	if not result_labels.has("energy_handler_no_resolution"):
		result_labels.append("energy_handler_no_resolution")

	return {
		"status": status,
		"reason": reason,
		"labels": result_labels,
		"current_energy": current_energy,
		"reserved_energy": reserved_energy,
		"available_energy": get_available_energy()
	}
	
	
func update_energy_bar(delta) -> void:

	

	if state == null:
		return

	if not state.controls.has("energy_bar_root"):
		return

	if not state.color_rects.has("energy_bar_blue"):
		return

	if not state.color_rects.has("energy_bar_green"):
		return

	if not state.color_rects.has("energy_bar_red"):
		return

	var root: Control = state.controls["energy_bar_root"]

	var blue: ColorRect = state.color_rects["energy_bar_blue"]
	var green: ColorRect = state.color_rects["energy_bar_green"]
	var red: ColorRect = state.color_rects["energy_bar_red"]

	var bar_width := root.size.x
	var bar_height := 24.0

	var blue_width := bar_width * get_queued_ratio()
	var green_width := bar_width * get_available_ratio()
	var red_width := bar_width * get_spent_ratio()

	# ==================================================
	# BLUE = QUEUED / RESERVED
	# --------------------------------------------------
	# Starts at the left edge.
	# ==================================================
	blue.position = Vector2(0, 0)
	blue.size = Vector2(blue_width, bar_height)

	# ==================================================
	# GREEN = AVAILABLE
	# --------------------------------------------------
	# Starts after blue.
	# ==================================================
	green.position = Vector2(blue_width, 0)
	green.size = Vector2(green_width, bar_height)

	# ==================================================
	# RED = SPENT
	# --------------------------------------------------
	# Starts after blue + green.
	# ==================================================
	red.position = Vector2(blue_width + green_width, 0)
	red.size = Vector2(red_width, bar_height)

	if state.labels.has("energy_bar_label"):
		state.labels["energy_bar_label"].text = (
			"ENERGY  "
			+ "B:" + str(int(get_queued_energy()))
			+ "  G:" + str(int(get_available_energy()))
			+ "  R:" + str(int(get_spent_energy()))
		)
func update_energy_handler(delta: float) -> void:

	

	# For now, only recharge during battle.
	if not Globals.battle_mode:
		return
	#update_energy_bar(delta)
	#update_energy_bar_visibility()
	recharge(delta)
func update_energy_bar_visibility() -> void:

	if state == null:
		return

	if not state.controls.has("energy_bar_root"):
		return

	state.controls["energy_bar_root"].visible = false
	
	
	
	
	
	#var energy_bar_widget = gui_builder.energy_bar(
		#Vector2(125, 225),
		#"energy_bar"
	#)
#
	#energy_bar_widget.z_index = 900
	#energy_bar_widget.show_behind_parent = false

	#add_child(energy_bar_widget)
	#move_child(energy_bar_widget, get_child_count() - 1)
