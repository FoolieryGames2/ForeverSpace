extends Node


class_name StatsEffectManager


# Declares the primary active effect storage for StatEffectHandler ownership only.
var active_effects: Dictionary = {} # Stores active effects by target unit first, matching active_effects[target_unit_id][effect_instance_id].



# Tracks the next active effect instance number owned by StatEffectHandler.
var effect_instance_counter: int = 0 # Increments only when store_effect() officially stores a new active effect.





func _ready():
	# Summary: Keep the prototype stat effect manager idle until Battle V2 passes real effect packets into it.
	if Globals.print_priority_3:
		print("StatsEffectManager prototype loaded idle.")
# Validates a standardized effect packet before protection, stacking, or storage.
func validate_effect_packet(effect_packet: Dictionary) -> Dictionary: # Receives one effect packet and returns a standard effect_result-style validation result.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.validate_effect_packet() entered.") # Reports function entry for trace debugging.

	var required_fields: Array = [ # Defines every packet field that must exist before the effect can continue.
		"effect_id", # Requires the effect identity so later systems know what effect is being applied.
		"effect_group", # Requires the effect group so the packet can be checked against approved groups.
		"effect_type", # Requires the effect type so the packet can be checked against approved types.
		"source_unit", # Requires the source unit so ownership direction is not guessed.
		"target_unit", # Requires the target unit so storage and protection checks have a real target.
		"owner_unit", # Requires the owner unit so the effect has clear ownership.
		"event_side", # Requires event side so the packet direction remains explicit.
		"duration", # Requires duration so expiration behavior can be controlled.
		"time_remaining", # Requires time remaining so runtime countdown has a known starting value.
		"stack_rule", # Requires stack rule so stacking behavior is not guessed.
		"priority", # Requires priority so replacement rules can be evaluated later.
		"affects", # Requires affects so query systems know what the effect modifies.
		"values", # Requires values so numeric or payload data is always explicit.
		"flags" # Requires flags so special rules such as instant effects are explicit.
	] # Ends the required field list.

	var approved_effect_groups: Array = [ # Defines the approved effect groups from the blueprint.
		"signal", # Allows signal effects such as jamming or disruption.
		"drone", # Allows drone-applied effects such as protection or repair.
		"pulse", # Allows pulse timing effects such as N/V windows.
		"shield", # Allows shield modifier effects.
		"energy", # Allows energy modifier effects.
		"override" # Allows future rule-bending placeholder effects.
	] # Ends the approved effect group list.

	var approved_effect_types: Array = [ # Defines the approved effect types from the blueprint.
		"disable", # Allows effects that temporarily disable a system or lane.
		"buff", # Allows effects that improve a value or behavior.
		"debuff", # Allows effects that weaken a value or behavior.
		"over_time", # Allows effects that tick repeatedly across duration.
		"triggered", # Allows effects that fire from a condition or trigger.
		"timing_modifier", # Allows effects that modify timing windows.
		"protection", # Allows effects that block or filter incoming effects.
		"rule_bend" # Allows future override-style effects.
	] # Ends the approved effect type list.

	var approved_stack_rules: Array = [ # Defines the approved stack rules from the blueprint.
		"none", # Allows rejection when a matching effect already exists.
		"stack", # Allows storing another active instance.
		"refresh", # Allows resetting an existing effect timer.
		"replace", # Allows replacing an existing effect when priority permits it.
		"unique" # Allows only one matching group/type conflict on the target.
	] # Ends the approved stack rule list.

	var approved_affect_keys: Array = [ # Defines the approved affect keys from the blueprint.
		"energy", # Allows effects that affect energy systems.
		"shield", # Allows effects that affect shield systems.
		"hull", # Allows effects that affect hull systems.
		"weapon", # Allows effects that affect weapon systems.
		"lock", # Allows effects that affect target lock systems.
		"regen", # Allows effects that affect regeneration systems.
		"todo" # Allows effects that affect TODO timing or behavior without owning TODOs.
	] # Ends the approved affect key list.

	for required_field in required_fields: # Loops through every required field to confirm the packet is complete.
		if not effect_packet.has(required_field): # Checks whether the current required field is missing.
			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.validate_effect_packet() rejected packet: missing required field: " + str(required_field)) # Reports the missing-field rejection path.

			return { # Returns a standard rejected result because malformed packets cannot continue.
				"status": "rejected", # Marks the packet as rejected by validation.
				"effect_id": effect_packet.get("effect_id", ""), # Reports effect_id when present without assuming it exists.
				"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
				"target_unit": effect_packet.get("target_unit", null), # Reports target_unit when present without assuming it exists.
				"reason": "missing required field: " + str(required_field), # Explains exactly which required field failed.
				"labels": [ # Provides semantic labels for the rejection.
					"effect_packet_validation", # Marks that packet validation was performed.
					"effect_packet_required_fields", # Marks that required fields were checked.
					"effect_missing_required_field", # Marks that a required field was missing.
					"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
				] # Ends the result label list.
			} # Ends the rejected result packet.

	if effect_packet["source_unit"] == null: # Checks that source ownership is explicit and not missing.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.validate_effect_packet() rejected packet: source_unit is null.") # Reports the ownership rejection path.

		return { # Returns a standard rejected result because source ownership cannot be assumed.
			"status": "rejected", # Marks the packet as rejected by validation.
			"effect_id": effect_packet["effect_id"], # Reports the effect id from the validated required field set.
			"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
			"target_unit": effect_packet["target_unit"], # Reports the target unit from the validated required field set.
			"reason": "ownership field source_unit is null", # Explains the ownership failure.
			"labels": [ # Provides semantic labels for the rejection.
				"effect_packet_validation", # Marks that packet validation was performed.
				"effect_packet_ownership_check", # Marks that ownership fields were checked.
				"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
			] # Ends the result label list.
		} # Ends the rejected result packet.

	if effect_packet["target_unit"] == null: # Checks that target ownership is explicit and not missing.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.validate_effect_packet() rejected packet: target_unit is null.") # Reports the ownership rejection path.

		return { # Returns a standard rejected result because target ownership cannot be assumed.
			"status": "rejected", # Marks the packet as rejected by validation.
			"effect_id": effect_packet["effect_id"], # Reports the effect id from the validated required field set.
			"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
			"target_unit": effect_packet["target_unit"], # Reports the target unit from the validated required field set.
			"reason": "ownership field target_unit is null", # Explains the ownership failure.
			"labels": [ # Provides semantic labels for the rejection.
				"effect_packet_validation", # Marks that packet validation was performed.
				"effect_packet_ownership_check", # Marks that ownership fields were checked.
				"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
			] # Ends the result label list.
		} # Ends the rejected result packet.

	if effect_packet["owner_unit"] == null: # Checks that owner ownership is explicit and not missing.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.validate_effect_packet() rejected packet: owner_unit is null.") # Reports the ownership rejection path.

		return { # Returns a standard rejected result because owner ownership cannot be assumed.
			"status": "rejected", # Marks the packet as rejected by validation.
			"effect_id": effect_packet["effect_id"], # Reports the effect id from the validated required field set.
			"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
			"target_unit": effect_packet["target_unit"], # Reports the target unit from the validated required field set.
			"reason": "ownership field owner_unit is null", # Explains the ownership failure.
			"labels": [ # Provides semantic labels for the rejection.
				"effect_packet_validation", # Marks that packet validation was performed.
				"effect_packet_ownership_check", # Marks that ownership fields were checked.
				"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
			] # Ends the result label list.
		} # Ends the rejected result packet.

	if not approved_effect_groups.has(effect_packet["effect_group"]): # Checks whether the effect group is one of the approved groups.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.validate_effect_packet() rejected packet: unknown effect_group: " + str(effect_packet["effect_group"])) # Reports the group rejection path.

		return { # Returns a standard rejected result because unknown groups are not allowed.
			"status": "rejected", # Marks the packet as rejected by validation.
			"effect_id": effect_packet["effect_id"], # Reports the effect id from the validated required field set.
			"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
			"target_unit": effect_packet["target_unit"], # Reports the target unit from the validated required field set.
			"reason": "unknown effect group/type", # Uses the blueprint-approved reason for unknown group or type.
			"labels": [ # Provides semantic labels for the rejection.
				"effect_packet_validation", # Marks that packet validation was performed.
				"effect_packet_type_check", # Marks that effect group/type was checked.
				"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
			] # Ends the result label list.
		} # Ends the rejected result packet.

	if not approved_effect_types.has(effect_packet["effect_type"]): # Checks whether the effect type is one of the approved types.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.validate_effect_packet() rejected packet: unknown effect_type: " + str(effect_packet["effect_type"])) # Reports the type rejection path.

		return { # Returns a standard rejected result because unknown types are not allowed.
			"status": "rejected", # Marks the packet as rejected by validation.
			"effect_id": effect_packet["effect_id"], # Reports the effect id from the validated required field set.
			"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
			"target_unit": effect_packet["target_unit"], # Reports the target unit from the validated required field set.
			"reason": "unknown effect group/type", # Uses the blueprint-approved reason for unknown group or type.
			"labels": [ # Provides semantic labels for the rejection.
				"effect_packet_validation", # Marks that packet validation was performed.
				"effect_packet_type_check", # Marks that effect group/type was checked.
				"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
			] # Ends the result label list.
		} # Ends the rejected result packet.

	if typeof(effect_packet["duration"]) != TYPE_FLOAT and typeof(effect_packet["duration"]) != TYPE_INT: # Checks that duration is numeric.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.validate_effect_packet() rejected packet: duration is not numeric.") # Reports the duration rejection path.

		return { # Returns a standard rejected result because duration must be numeric.
			"status": "rejected", # Marks the packet as rejected by validation.
			"effect_id": effect_packet["effect_id"], # Reports the effect id from the validated required field set.
			"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
			"target_unit": effect_packet["target_unit"], # Reports the target unit from the validated required field set.
			"reason": "duration is not numeric", # Explains the duration type failure.
			"labels": [ # Provides semantic labels for the rejection.
				"effect_packet_validation", # Marks that packet validation was performed.
				"effect_packet_duration_check", # Marks that duration was checked.
				"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
			] # Ends the result label list.
		} # Ends the rejected result packet.

	if typeof(effect_packet["time_remaining"]) != TYPE_FLOAT and typeof(effect_packet["time_remaining"]) != TYPE_INT: # Checks that time_remaining is numeric.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.validate_effect_packet() rejected packet: time_remaining is not numeric.") # Reports the duration rejection path.

		return { # Returns a standard rejected result because time_remaining must be numeric.
			"status": "rejected", # Marks the packet as rejected by validation.
			"effect_id": effect_packet["effect_id"], # Reports the effect id from the validated required field set.
			"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
			"target_unit": effect_packet["target_unit"], # Reports the target unit from the validated required field set.
			"reason": "time_remaining is not numeric", # Explains the time_remaining type failure.
			"labels": [ # Provides semantic labels for the rejection.
				"effect_packet_validation", # Marks that packet validation was performed.
				"effect_packet_duration_check", # Marks that time_remaining was checked.
				"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
			] # Ends the result label list.
		} # Ends the rejected result packet.

	if effect_packet["duration"] <= 0 and effect_packet["flags"].get("instant", false) != true: # Checks the prototype duration rule for non-instant effects.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.validate_effect_packet() rejected packet: duration must be greater than zero unless instant flag is true.") # Reports the duration rejection path.

		return { # Returns a standard rejected result because non-instant effects require duration.
			"status": "rejected", # Marks the packet as rejected by validation.
			"effect_id": effect_packet["effect_id"], # Reports the effect id from the validated required field set.
			"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
			"target_unit": effect_packet["target_unit"], # Reports the target unit from the validated required field set.
			"reason": "duration must be > 0 unless flags[\"instant\"] == true", # Explains the prototype duration rule failure.
			"labels": [ # Provides semantic labels for the rejection.
				"effect_packet_validation", # Marks that packet validation was performed.
				"effect_packet_duration_check", # Marks that duration was checked.
				"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
			] # Ends the result label list.
		} # Ends the rejected result packet.

	if effect_packet["time_remaining"] < 0: # Checks that time_remaining does not start below zero.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.validate_effect_packet() rejected packet: time_remaining is below zero.") # Reports the duration rejection path.

		return { # Returns a standard rejected result because negative time_remaining is invalid.
			"status": "rejected", # Marks the packet as rejected by validation.
			"effect_id": effect_packet["effect_id"], # Reports the effect id from the validated required field set.
			"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
			"target_unit": effect_packet["target_unit"], # Reports the target unit from the validated required field set.
			"reason": "time_remaining must be >= 0", # Explains the time_remaining value failure.
			"labels": [ # Provides semantic labels for the rejection.
				"effect_packet_validation", # Marks that packet validation was performed.
				"effect_packet_duration_check", # Marks that time_remaining was checked.
				"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
			] # Ends the result label list.
		} # Ends the rejected result packet.

	if not approved_stack_rules.has(effect_packet["stack_rule"]): # Checks whether the stack rule is approved.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.validate_effect_packet() rejected packet: unknown stack_rule: " + str(effect_packet["stack_rule"])) # Reports the stack rule rejection path.

		return { # Returns a standard rejected result because unknown stack rules are not allowed.
			"status": "rejected", # Marks the packet as rejected by validation.
			"effect_id": effect_packet["effect_id"], # Reports the effect id from the validated required field set.
			"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
			"target_unit": effect_packet["target_unit"], # Reports the target unit from the validated required field set.
			"reason": "unknown stack_rule", # Explains the stack rule failure.
			"labels": [ # Provides semantic labels for the rejection.
				"effect_packet_validation", # Marks that packet validation was performed.
				"effect_packet_stack_rule_check", # Marks that stack rule was checked.
				"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
			] # Ends the result label list.
		} # Ends the rejected result packet.

	if typeof(effect_packet["affects"]) != TYPE_ARRAY: # Checks that affects is an Array as required by the blueprint.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.validate_effect_packet() rejected packet: affects is not an Array.") # Reports the affects rejection path.

		return { # Returns a standard rejected result because affects must be a list.
			"status": "rejected", # Marks the packet as rejected by validation.
			"effect_id": effect_packet["effect_id"], # Reports the effect id from the validated required field set.
			"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
			"target_unit": effect_packet["target_unit"], # Reports the target unit from the validated required field set.
			"reason": "affects must be a list", # Explains the affects type failure.
			"labels": [ # Provides semantic labels for the rejection.
				"effect_packet_validation", # Marks that packet validation was performed.
				"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
			] # Ends the result label list.
		} # Ends the rejected result packet.

	for affect_key in effect_packet["affects"]: # Loops through each affect key to confirm it is approved.
		if not approved_affect_keys.has(affect_key): # Checks whether the current affect key is allowed.
			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.validate_effect_packet() rejected packet: unknown affect key: " + str(affect_key)) # Reports the affects rejection path.

			return { # Returns a standard rejected result because unknown affect keys are not allowed.
				"status": "rejected", # Marks the packet as rejected by validation.
				"effect_id": effect_packet["effect_id"], # Reports the effect id from the validated required field set.
				"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
				"target_unit": effect_packet["target_unit"], # Reports the target unit from the validated required field set.
				"reason": "unknown affect key: " + str(affect_key), # Explains which affect key failed.
				"labels": [ # Provides semantic labels for the rejection.
					"effect_packet_validation", # Marks that packet validation was performed.
					"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
				] # Ends the result label list.
			} # Ends the rejected result packet.

	if typeof(effect_packet["values"]) != TYPE_DICTIONARY: # Checks that values is a Dictionary as required by the blueprint.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.validate_effect_packet() rejected packet: values is not a Dictionary.") # Reports the values rejection path.

		return { # Returns a standard rejected result because values must be a dictionary.
			"status": "rejected", # Marks the packet as rejected by validation.
			"effect_id": effect_packet["effect_id"], # Reports the effect id from the validated required field set.
			"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
			"target_unit": effect_packet["target_unit"], # Reports the target unit from the validated required field set.
			"reason": "values must be a dictionary", # Explains the values type failure.
			"labels": [ # Provides semantic labels for the rejection.
				"effect_packet_validation", # Marks that packet validation was performed.
				"effect_packet_type_check", # Marks that packet field types were checked.
				"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
			] # Ends the result label list.
		} # Ends the rejected result packet.

	if typeof(effect_packet["flags"]) != TYPE_DICTIONARY: # Checks that flags is a Dictionary as required by the blueprint.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.validate_effect_packet() rejected packet: flags is not a Dictionary.") # Reports the flags rejection path.

		return { # Returns a standard rejected result because flags must be a dictionary.
			"status": "rejected", # Marks the packet as rejected by validation.
			"effect_id": effect_packet["effect_id"], # Reports the effect id from the validated required field set.
			"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
			"target_unit": effect_packet["target_unit"], # Reports the target unit from the validated required field set.
			"reason": "flags must be a dictionary", # Explains the flags type failure.
			"labels": [ # Provides semantic labels for the rejection.
				"effect_packet_validation", # Marks that packet validation was performed.
				"effect_packet_type_check", # Marks that packet field types were checked.
				"effect_rejected_invalid_packet" # Marks that the packet was rejected as invalid.
			] # Ends the result label list.
		} # Ends the rejected result packet.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.validate_effect_packet() validated packet: " + str(effect_packet["effect_id"])) # Reports the successful validation path.

	return { # Returns a standard validation result that allows apply_effect to continue.
		"status": "validated", # Marks the packet as validated for the next apply_effect phase.
		"effect_id": effect_packet["effect_id"], # Reports the validated effect id.
		"effect_instance_id": null, # Keeps instance id empty because validation never stores effects.
		"target_unit": effect_packet["target_unit"], # Reports the validated target unit.
		"reason": "", # Leaves reason empty because validation passed.
		"labels": [ # Provides semantic labels for the validation pass.
			"effect_packet_validation" # Marks that packet validation was performed.
		] # Ends the result label list.
	} # Ends the validated result packet.
	
	
	
	
	# Stores an approved effect packet as an active runtime effect on the target unit.
func store_effect(effect_packet: Dictionary) -> Dictionary: # Receives one already-approved effect packet and returns a standard effect_result packet.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.store_effect() entered.") # Reports function entry for trace debugging.

	effect_instance_counter += 1 # Consumes one new instance number only because this effect is now being stored.

	var counter_text: String = str(effect_instance_counter) # Converts the numeric counter into text so it can be padded for the instance id.

	while counter_text.length() < 3: # Pads the counter until it reaches the approved three-character minimum.
		counter_text = "0" + counter_text # Adds one leading zero to match the approved padding rule.

	var effect_instance_id: String = str(effect_packet["effect_id"]) + "_instance_" + counter_text # Builds the approved runtime instance id format.

	var target_unit_id = effect_packet["target_unit"] # Reads the target unit because active_effects stores effects by target unit first.

	if not active_effects.has(target_unit_id): # Checks whether this target already has an active effect bucket.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.store_effect() creating target bucket for: " + str(target_unit_id)) # Reports the target-bucket creation branch.

		active_effects[target_unit_id] = {} # Creates the target bucket so this effect can be stored under the target unit.

	var effect_runtime_packet: Dictionary = effect_packet.duplicate(true) # Copies the approved packet so runtime state can be added without mutating the original input packet.

	effect_runtime_packet["effect_instance_id"] = effect_instance_id # Adds the unique runtime instance id used for active storage and removal.

	effect_runtime_packet["tick_timer"] = effect_runtime_packet.get("tick_rate", 0.0) # Adds runtime tick state using tick_rate as the starting timer value.

	effect_runtime_packet["battle_id"] = effect_runtime_packet.get("battle_id", "") # Ensures battle_id exists in runtime state even when the optional packet field was omitted.

	effect_runtime_packet["battle_only"] = effect_runtime_packet.get("battle_only", false) # Ensures battle_only exists in runtime state even when the optional packet field was omitted.

	effect_runtime_packet["source_event_id"] = effect_runtime_packet.get("source_event_id", "") # Ensures source_event_id exists in runtime state even when the optional packet field was omitted.

	effect_runtime_packet["visual_labels"] = effect_runtime_packet.get("visual_labels", []) # Ensures visual_labels exists in runtime state for downstream semantic reporting.

	effect_runtime_packet["visual_labels_on_expire"] = effect_runtime_packet.get("visual_labels_on_expire", []) # Ensures expire labels exist in runtime state for later expiration reporting.

	effect_runtime_packet["visual_labels_on_cleanup"] = effect_runtime_packet.get("visual_labels_on_cleanup", []) # Ensures cleanup labels exist in runtime state for later battle cleanup reporting.

	active_effects[target_unit_id][effect_instance_id] = effect_runtime_packet # Stores the runtime effect packet at active_effects[target_unit_id][effect_instance_id].

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.store_effect() stored effect: " + str(effect_instance_id)) # Reports the successful storage path.

	return { # Returns a standard effect_result packet for the stored effect.
		"status": "applied", # Marks the effect as successfully applied and stored.
		"effect_id": effect_packet["effect_id"], # Reports the effect type id that was stored.
		"effect_instance_id": effect_instance_id, # Reports the runtime instance id created during storage.
		"target_unit": target_unit_id, # Reports the target unit that received the effect.
		"reason": "", # Leaves reason empty because storage succeeded.
		"labels": [ # Provides semantic labels for the storage result.
			"active_stat_effects", # Marks that the active effect storage system was used.
			"effect_storage_by_target", # Marks that the effect was stored by target unit.
			"effect_instance_id", # Marks that a runtime instance id was generated.
			"effect_target_bucket", # Marks that the target bucket path was used.
			"effect_runtime_state", # Marks that runtime state was created.
			"effect_applied" # Marks that the effect was applied.
		] # Ends the result label list.
	} # Ends the applied result packet.
	
	
	
# Checks active protection effects on a target to determine whether an incoming effect is blocked.
func check_protection(target_unit, incoming_effect_packet: Dictionary) -> Dictionary: # Receives the target unit and incoming effect packet, then returns a standard effect_result-style packet.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.check_protection() entered.") # Reports function entry for trace debugging.

	if not active_effects.has(target_unit): # Checks whether the target has any active effects to inspect.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.check_protection() no active effects found for target.") # Reports the no-active-effects branch.

		return { # Returns a standard not-blocked result because there are no effects on the target.
			"status": "not_blocked", # Marks that no protection effect blocked the incoming effect.
			"effect_id": incoming_effect_packet.get("effect_id", "unknown"), # Reports the incoming effect id when available.
			"effect_instance_id": null, # Keeps instance id empty because protection checks never store effects.
			"target_unit": target_unit, # Reports the checked target unit.
			"reason": "", # Leaves reason empty because no block occurred.
			"labels": [ # Provides semantic labels for the no-match result.
				"effect_protection_check", # Marks that a protection check was performed.
				"protection_filter_no_match" # Marks that no protection filter matched the incoming effect.
			] # Ends the result label list.
		} # Ends the not-blocked result packet.

	var target_effect_bucket: Dictionary = active_effects[target_unit] # Reads only the target bucket approved for this protection check.

	var incoming_effect_id = incoming_effect_packet.get("effect_id", "unknown") # Reads the incoming effect id for exact protection matching.

	var incoming_effect_group = incoming_effect_packet.get("effect_group", "") # Reads the incoming effect group for group-based protection matching.

	var incoming_effect_type = incoming_effect_packet.get("effect_type", "") # Reads the incoming effect type for type-based protection matching.

	var incoming_affects: Array = incoming_effect_packet.get("affects", []) # Reads incoming affect keys, defaulting to an empty list for safe comparison.

	var incoming_flags: Dictionary = incoming_effect_packet.get("flags", {}) # Reads incoming flags, defaulting to an empty dictionary for safe comparison.

	var incoming_tags: Array = incoming_flags.get("tags", []) # Reads incoming tags from flags["tags"], defaulting to an empty list if missing.

	for effect_instance_id in target_effect_bucket.keys(): # Loops through each active effect instance on the target.
		var protection_effect: Dictionary = target_effect_bucket[effect_instance_id] # Reads the active runtime packet for the current effect instance.

		if protection_effect.get("effect_type", "") != "protection": # Skips any active effect that is not a protection effect.
			continue # Moves to the next active effect because only protection effects can block incoming effects here.

		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.check_protection() inspecting protection effect: " + str(effect_instance_id)) # Reports the protection inspection branch.

		var protection_flags: Dictionary = protection_effect.get("flags", {}) # Reads protection filter data from protection_effect["flags"].

		var blocked_effect_ids: Array = protection_flags.get("blocked_effect_ids", []) # Reads exact blocked effect ids, defaulting to an empty list if missing.

		var blocked_tags: Array = protection_flags.get("blocked_tags", []) # Reads blocked incoming tags, defaulting to an empty list if missing.

		var blocked_affects: Array = protection_flags.get("blocked_affects", []) # Reads blocked affect keys, defaulting to an empty list if missing.

		var blocked_groups: Array = protection_flags.get("blocked_groups", []) # Reads blocked effect groups, defaulting to an empty list if missing.

		var blocked_types: Array = protection_flags.get("blocked_types", []) # Reads blocked effect types, defaulting to an empty list if missing.

		if blocked_effect_ids.has(incoming_effect_id): # Checks protection match order step 1 using exact incoming effect id.
			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.check_protection() blocked by exact effect_id match.") # Reports the exact-id block branch.

			return { # Returns a standard blocked result because the exact effect id matched protection.
				"status": "blocked", # Marks that the incoming effect was blocked.
				"effect_id": incoming_effect_id, # Reports the blocked incoming effect id.
				"effect_instance_id": null, # Keeps instance id empty because protection checks never store effects.
				"target_unit": target_unit, # Reports the target unit protected from the incoming effect.
				"reason": "blocked by protection effect", # Explains that an active protection effect blocked the incoming effect.
				"labels": [ # Provides semantic labels for the blocked result.
					"effect_protection_check", # Marks that a protection check was performed.
					"protection_filter_match", # Marks that a protection filter matched.
					"effect_blocked_by_protection", # Marks that the effect was blocked by protection.
					"signal_filter_blocks_incoming_effect" # Marks that the signal-filter blocking path was used.
				] # Ends the result label list.
			} # Ends the blocked result packet.

		for incoming_tag in incoming_tags: # Loops through incoming tags for blocked-tags comparison.
			if blocked_tags.has(incoming_tag): # Checks protection match order step 2 using incoming flags["tags"].
				if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
					print("StatEffectHandler.check_protection() blocked by tag match: " + str(incoming_tag)) # Reports the blocked-tag branch.

				return { # Returns a standard blocked result because an incoming tag matched protection.
					"status": "blocked", # Marks that the incoming effect was blocked.
					"effect_id": incoming_effect_id, # Reports the blocked incoming effect id.
					"effect_instance_id": null, # Keeps instance id empty because protection checks never store effects.
					"target_unit": target_unit, # Reports the target unit protected from the incoming effect.
					"reason": "blocked by protection effect", # Explains that an active protection effect blocked the incoming effect.
					"labels": [ # Provides semantic labels for the blocked result.
						"effect_protection_check", # Marks that a protection check was performed.
						"protection_filter_match", # Marks that a protection filter matched.
						"effect_blocked_by_protection", # Marks that the effect was blocked by protection.
						"signal_filter_blocks_incoming_effect" # Marks that the signal-filter blocking path was used.
					] # Ends the result label list.
				} # Ends the blocked result packet.

		for incoming_affect in incoming_affects: # Loops through incoming affect keys for blocked-affects comparison.
			if blocked_affects.has(incoming_affect): # Checks protection match order step 3 using incoming affects.
				if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
					print("StatEffectHandler.check_protection() blocked by affect match: " + str(incoming_affect)) # Reports the blocked-affect branch.

				return { # Returns a standard blocked result because an incoming affect matched protection.
					"status": "blocked", # Marks that the incoming effect was blocked.
					"effect_id": incoming_effect_id, # Reports the blocked incoming effect id.
					"effect_instance_id": null, # Keeps instance id empty because protection checks never store effects.
					"target_unit": target_unit, # Reports the target unit protected from the incoming effect.
					"reason": "blocked by protection effect", # Explains that an active protection effect blocked the incoming effect.
					"labels": [ # Provides semantic labels for the blocked result.
						"effect_protection_check", # Marks that a protection check was performed.
						"protection_filter_match", # Marks that a protection filter matched.
						"effect_blocked_by_protection", # Marks that the effect was blocked by protection.
						"signal_filter_blocks_incoming_effect" # Marks that the signal-filter blocking path was used.
					] # Ends the result label list.
				} # Ends the blocked result packet.

		if blocked_groups.has(incoming_effect_group): # Checks protection match order step 4 using incoming effect group.
			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.check_protection() blocked by effect_group match: " + str(incoming_effect_group)) # Reports the blocked-group branch.

			return { # Returns a standard blocked result because the incoming group matched protection.
				"status": "blocked", # Marks that the incoming effect was blocked.
				"effect_id": incoming_effect_id, # Reports the blocked incoming effect id.
				"effect_instance_id": null, # Keeps instance id empty because protection checks never store effects.
				"target_unit": target_unit, # Reports the target unit protected from the incoming effect.
				"reason": "blocked by protection effect", # Explains that an active protection effect blocked the incoming effect.
				"labels": [ # Provides semantic labels for the blocked result.
					"effect_protection_check", # Marks that a protection check was performed.
					"protection_filter_match", # Marks that a protection filter matched.
					"effect_blocked_by_protection", # Marks that the effect was blocked by protection.
					"signal_filter_blocks_incoming_effect" # Marks that the signal-filter blocking path was used.
				] # Ends the result label list.
			} # Ends the blocked result packet.

		if blocked_types.has(incoming_effect_type): # Checks protection match order step 4 using incoming effect type.
			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.check_protection() blocked by effect_type match: " + str(incoming_effect_type)) # Reports the blocked-type branch.

			return { # Returns a standard blocked result because the incoming type matched protection.
				"status": "blocked", # Marks that the incoming effect was blocked.
				"effect_id": incoming_effect_id, # Reports the blocked incoming effect id.
				"effect_instance_id": null, # Keeps instance id empty because protection checks never store effects.
				"target_unit": target_unit, # Reports the target unit protected from the incoming effect.
				"reason": "blocked by protection effect", # Explains that an active protection effect blocked the incoming effect.
				"labels": [ # Provides semantic labels for the blocked result.
					"effect_protection_check", # Marks that a protection check was performed.
					"protection_filter_match", # Marks that a protection filter matched.
					"effect_blocked_by_protection", # Marks that the effect was blocked by protection.
					"signal_filter_blocks_incoming_effect" # Marks that the signal-filter blocking path was used.
				] # Ends the result label list.
			} # Ends the blocked result packet.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.check_protection() no protection filter matched.") # Reports the final no-block path.

	return { # Returns a standard not-blocked result because no protection filters matched.
		"status": "not_blocked", # Marks that no protection effect blocked the incoming effect.
		"effect_id": incoming_effect_id, # Reports the incoming effect id that was allowed to continue.
		"effect_instance_id": null, # Keeps instance id empty because protection checks never store effects.
		"target_unit": target_unit, # Reports the checked target unit.
		"reason": "", # Leaves reason empty because no block occurred.
		"labels": [ # Provides semantic labels for the no-match result.
			"effect_protection_check", # Marks that a protection check was performed.
			"protection_filter_no_match" # Marks that no protection filter matched the incoming effect.
		] # Ends the result label list.
	} # Ends the not-blocked result packet.
	
	
	
	
# Handles stack, refresh, replace, unique, or rejection behavior for an approved effect packet.
func handle_stacking(effect_packet: Dictionary) -> Dictionary: # Receives one approved effect packet and returns a standard effect_result packet.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.handle_stacking() entered.") # Reports function entry for trace debugging.

	var target_unit_id = effect_packet["target_unit"] # Reads the target unit because stacking checks only compare effects on the same target.

	var incoming_effect_id = effect_packet["effect_id"] # Reads the incoming effect id for exact-match stacking checks.

	var incoming_effect_group = effect_packet["effect_group"] # Reads the incoming effect group for broader conflict checks.

	var incoming_effect_type = effect_packet["effect_type"] # Reads the incoming effect type for broader conflict checks.

	var incoming_affects: Array = effect_packet["affects"] # Reads the incoming affects list for broader conflict checks.

	var incoming_stack_rule: String = effect_packet["stack_rule"] # Reads the approved stack rule that controls this function branch.

	var incoming_priority: int = int(effect_packet["priority"]) # Reads incoming priority as an integer for replace priority comparison.

	var exact_conflict_ids: Array = [] # Stores active effect instance ids that exactly match the incoming effect_id.

	var broader_conflict_ids: Array = [] # Stores active effect instance ids that match broader group/type/affects conflict rules.

	var all_conflict_ids: Array = [] # Stores all exact or broader conflict ids without duplicates.

	if active_effects.has(target_unit_id): # Checks whether the target has active effects that can conflict.
		var target_effect_bucket: Dictionary = active_effects[target_unit_id] # Reads the target bucket because active_effects is stored by target first.

		for effect_instance_id in target_effect_bucket.keys(): # Loops through every active effect instance on the same target.
			var active_effect: Dictionary = target_effect_bucket[effect_instance_id] # Reads the active runtime effect packet for comparison.

			var is_exact_conflict: bool = false # Starts exact conflict tracking as false for this active effect.

			var is_broader_conflict: bool = false # Starts broader conflict tracking as false for this active effect.

			if active_effect.get("effect_id", "") == incoming_effect_id: # Checks exact same effect match by effect_id on the same target.
				is_exact_conflict = true # Marks this active effect as an exact conflict.

			if active_effect.get("effect_group", "") == "signal" and incoming_effect_group == "signal": # Checks signal exclusivity where only one signal effect may exist per unit.
				is_broader_conflict = true # Marks this active signal effect as a broader conflict.

			if active_effect.get("effect_group", "") == incoming_effect_group and active_effect.get("effect_type", "") == incoming_effect_type: # Checks same group and same type for broader conflict comparison.
				var active_affects: Array = active_effect.get("affects", []) # Reads the active effect affects list for overlap comparison.

				for incoming_affect in incoming_affects: # Loops through each incoming affect key to find a shared affect.
					if active_affects.has(incoming_affect): # Checks whether the active effect affects the same key.
						is_broader_conflict = true # Marks this active effect as a broader conflict because group/type/affect matched.

			if is_exact_conflict: # Checks whether this active effect matched the exact conflict rule.
				exact_conflict_ids.append(effect_instance_id) # Stores the exact conflict instance id for stack-rule decisions.

			if is_broader_conflict: # Checks whether this active effect matched the broader conflict rule.
				broader_conflict_ids.append(effect_instance_id) # Stores the broader conflict instance id for stack-rule decisions.

			if is_exact_conflict or is_broader_conflict: # Checks whether this active effect belongs in the combined conflict list.
				if not all_conflict_ids.has(effect_instance_id): # Prevents duplicate instance ids when an effect is both exact and broader conflict.
					all_conflict_ids.append(effect_instance_id) # Stores the conflict instance id once for shared conflict handling.

	if all_conflict_ids.is_empty(): # Checks whether no exact or broader conflicts were found.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.handle_stacking() no conflicts found; storing new effect.") # Reports the no-conflict storage branch.

		return store_effect(effect_packet) # Stores the approved effect because no stacking conflict exists.

	if incoming_stack_rule == "none": # Handles stack_rule none where an exact matching effect rejects the new effect.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.handle_stacking() branch stack_rule none.") # Reports the none-rule branch.

		if not exact_conflict_ids.is_empty(): # Checks whether a matching effect already exists.
			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.handle_stacking() rejected: matching effect exists and stack_rule is none.") # Reports the none-rule rejection path.

			return { # Returns a standard rejected result because stack_rule none disallows duplicate exact matches.
				"status": "rejected", # Marks the incoming effect as rejected.
				"effect_id": incoming_effect_id, # Reports the rejected incoming effect id.
				"effect_instance_id": null, # Keeps instance id empty because rejected effects are not stored.
				"target_unit": target_unit_id, # Reports the target unit that already has the matching effect.
				"reason": "matching effect exists and stack_rule is none", # Explains the stacking rejection.
				"labels": [ # Provides semantic labels for the rejection.
					"effect_stack_rule_none", # Marks that stack_rule none was used.
					"effect_stacking_result", # Marks that stacking logic produced the result.
					"effect_rejected" # Marks that the effect was rejected.
				] # Ends the result label list.
			} # Ends the rejected result packet.

		return store_effect(effect_packet) # Stores the effect because stack_rule none only rejects exact matching duplicates.

	if incoming_stack_rule == "stack": # Handles stack_rule stack where a new active instance is allowed.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.handle_stacking() branch stack_rule stack; storing separate instance.") # Reports the stack-rule branch.

		var stack_result: Dictionary = store_effect(effect_packet) # Stores the incoming effect as a separate active instance.

		stack_result["status"] = "stacked" # Converts the storage success into the stack-specific result status.

		stack_result["labels"].append("effect_stack_rule_stack") # Adds the stack-rule semantic label to the result.

		stack_result["labels"].append("effect_stacked") # Adds the stacked-result semantic label to the result.

		stack_result["labels"].append("effect_stacking_result") # Adds the generic stacking-result label to the result.

		return stack_result # Returns the stacked result packet.

	if incoming_stack_rule == "refresh": # Handles stack_rule refresh where an existing matching effect timer is reset.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.handle_stacking() branch stack_rule refresh.") # Reports the refresh-rule branch.

		var refresh_target_id = null # Prepares the effect instance id that will be refreshed.

		if not exact_conflict_ids.is_empty(): # Prefers exact effect matches for refresh behavior.
			refresh_target_id = exact_conflict_ids[0] # Selects the first exact matching effect instance for timer refresh.

		elif not broader_conflict_ids.is_empty(): # Falls back to broader conflicts if no exact match exists.
			refresh_target_id = broader_conflict_ids[0] # Selects the first broader conflict effect instance for timer refresh.

		active_effects[target_unit_id][refresh_target_id]["time_remaining"] = effect_packet["duration"] # Resets the selected active effect timer to the incoming full duration.

		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.handle_stacking() refreshed effect: " + str(refresh_target_id)) # Reports the refreshed instance id.

		return { # Returns a standard refreshed result.
			"status": "refreshed", # Marks the existing effect as refreshed.
			"effect_id": incoming_effect_id, # Reports the incoming effect id that caused the refresh.
			"effect_instance_id": refresh_target_id, # Reports the active instance id that was refreshed.
			"target_unit": target_unit_id, # Reports the target unit that owns the refreshed effect.
			"reason": "matching effect refreshed", # Explains the refresh result.
			"labels": [ # Provides semantic labels for the refresh result.
				"effect_stack_rule_refresh", # Marks that stack_rule refresh was used.
				"effect_stacking_result", # Marks that stacking logic produced the result.
				"effect_refreshed" # Marks that the effect was refreshed.
			] # Ends the result label list.
		} # Ends the refreshed result packet.

	if incoming_stack_rule == "replace": # Handles stack_rule replace using approved priority conflict rules.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.handle_stacking() branch stack_rule replace.") # Reports the replace-rule branch.

		var highest_existing_priority: int = -999999 # Starts below normal priority values so any conflict priority can replace it.

		for conflict_id in all_conflict_ids: # Loops through all exact and broader conflicts to find the highest existing priority.
			var conflict_priority: int = int(active_effects[target_unit_id][conflict_id].get("priority", 0)) # Reads the conflict priority for comparison.

			if conflict_priority > highest_existing_priority: # Checks whether this conflict has the highest priority seen so far.
				highest_existing_priority = conflict_priority # Stores this conflict priority as the current highest existing priority.

		if incoming_priority > highest_existing_priority: # Checks the approved rule where higher incoming priority replaces all conflicts.
			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.handle_stacking() replacing all conflicting effects.") # Reports the higher-priority replace path.

			for conflict_id in all_conflict_ids: # Loops through all conflicting active effects for removal.
				active_effects[target_unit_id].erase(conflict_id) # Removes the conflicting active effect from the target bucket.

			var replace_result: Dictionary = store_effect(effect_packet) # Stores the incoming effect after all conflicts were removed.

			replace_result["status"] = "replaced" # Converts the storage success into the replace-specific result status.

			replace_result["labels"].append("effect_stack_rule_replace") # Adds the replace-rule semantic label to the result.

			replace_result["labels"].append("effect_conflict_priority_check") # Adds the priority-check semantic label to the result.

			replace_result["labels"].append("effect_replaced") # Adds the replaced-result semantic label to the result.

			replace_result["labels"].append("effect_stacking_result") # Adds the generic stacking-result label to the result.

			return replace_result # Returns the replaced result packet.

		if incoming_priority == highest_existing_priority: # Checks the approved equal-priority replace behavior.
			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.handle_stacking() equal priority conflict found.") # Reports the equal-priority branch.

			for conflict_id in all_conflict_ids: # Loops through conflicts to find a same-effect equal-priority target.
				var conflict_packet: Dictionary = active_effects[target_unit_id][conflict_id] # Reads the conflict packet for same-effect comparison.

				if conflict_packet.get("effect_id", "") == incoming_effect_id and int(conflict_packet.get("priority", 0)) == incoming_priority: # Checks equal priority plus same effect_id refresh rule.
					conflict_packet["time_remaining"] = effect_packet["duration"] # Refreshes the existing same-effect timer to full incoming duration.

					if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
						print("StatEffectHandler.handle_stacking() equal priority same effect_id refreshed: " + str(conflict_id)) # Reports the equal-priority refresh path.

					return { # Returns a standard refreshed result for equal priority plus same effect_id.
						"status": "refreshed", # Marks the existing effect as refreshed.
						"effect_id": incoming_effect_id, # Reports the incoming effect id that caused the refresh.
						"effect_instance_id": conflict_id, # Reports the existing active instance that was refreshed.
						"target_unit": target_unit_id, # Reports the target unit that owns the refreshed effect.
						"reason": "equal priority same effect_id refreshed", # Explains the approved equal-priority refresh result.
						"labels": [ # Provides semantic labels for the refresh result.
							"effect_stack_rule_replace", # Marks that this came from stack_rule replace.
							"effect_conflict_priority_check", # Marks that priority comparison was performed.
							"effect_refreshed", # Marks that the effect was refreshed.
							"effect_stacking_result" # Marks that stacking logic produced the result.
						] # Ends the result label list.
					} # Ends the refreshed result packet.

			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.handle_stacking() rejected: equal priority different effect_id.") # Reports the equal-priority rejection path.

			return { # Returns a standard rejected result because equal priority different effect_id cannot replace.
				"status": "rejected", # Marks the incoming effect as rejected.
				"effect_id": incoming_effect_id, # Reports the rejected incoming effect id.
				"effect_instance_id": null, # Keeps instance id empty because rejected effects are not stored.
				"target_unit": target_unit_id, # Reports the target unit that kept the existing conflict.
				"reason": "equal priority different effect_id rejected", # Explains the approved equal-priority rejection rule.
				"labels": [ # Provides semantic labels for the rejection.
					"effect_stack_rule_replace", # Marks that stack_rule replace was used.
					"effect_conflict_priority_check", # Marks that priority comparison was performed.
					"effect_stacking_result", # Marks that stacking logic produced the result.
					"effect_rejected" # Marks that the effect was rejected.
				] # Ends the result label list.
			} # Ends the rejected result packet.

		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.handle_stacking() rejected: lower priority incoming effect.") # Reports the lower-priority rejection path.

		return { # Returns a standard rejected result because lower priority cannot replace higher priority.
			"status": "rejected", # Marks the incoming effect as rejected.
			"effect_id": incoming_effect_id, # Reports the rejected incoming effect id.
			"effect_instance_id": null, # Keeps instance id empty because rejected effects are not stored.
			"target_unit": target_unit_id, # Reports the target unit that kept the stronger existing conflict.
			"reason": "lower priority rejected", # Explains the approved lower-priority rejection rule.
			"labels": [ # Provides semantic labels for the rejection.
				"effect_stack_rule_replace", # Marks that stack_rule replace was used.
				"effect_conflict_priority_check", # Marks that priority comparison was performed.
				"effect_stacking_result", # Marks that stacking logic produced the result.
				"effect_rejected" # Marks that the effect was rejected.
			] # Ends the result label list.
		} # Ends the rejected result packet.

	if incoming_stack_rule == "unique": # Handles stack_rule unique where any matching group/type conflict rejects the incoming effect.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.handle_stacking() branch stack_rule unique.") # Reports the unique-rule branch.

		if not broader_conflict_ids.is_empty(): # Checks whether any matching group/type conflict exists on the target.
			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.handle_stacking() rejected: unique conflict exists.") # Reports the unique rejection path.

			return { # Returns a standard rejected result because unique does not allow a matching group/type conflict.
				"status": "rejected", # Marks the incoming effect as rejected.
				"effect_id": incoming_effect_id, # Reports the rejected incoming effect id.
				"effect_instance_id": null, # Keeps instance id empty because rejected effects are not stored.
				"target_unit": target_unit_id, # Reports the target unit that already has a unique conflict.
				"reason": "unique conflict exists", # Explains the unique rejection.
				"labels": [ # Provides semantic labels for the rejection.
					"effect_stack_rule_unique", # Marks that stack_rule unique was used.
					"effect_stacking_result", # Marks that stacking logic produced the result.
					"effect_rejected" # Marks that the effect was rejected.
				] # Ends the result label list.
			} # Ends the rejected result packet.

		return store_effect(effect_packet) # Stores the unique effect because no matching group/type conflict exists.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.handle_stacking() failed: unknown stack_rule reached after validation.") # Reports the unexpected stack-rule failure path.

	return { # Returns a standard failed result if an unknown stack rule reaches this function unexpectedly.
		"status": "failed", # Marks the result as failed because this path should not occur after validation.
		"effect_id": incoming_effect_id, # Reports the incoming effect id.
		"effect_instance_id": null, # Keeps instance id empty because failed effects are not stored.
		"target_unit": target_unit_id, # Reports the target unit being processed.
		"reason": "unknown stack_rule reached handle_stacking", # Explains the unexpected failure.
		"labels": [ # Provides semantic labels for the failure.
			"effect_stacking_result" # Marks that stacking logic produced the result.
		] # Ends the result label list.
	} # Ends the failed result packet.
	
	
	
	
# Applies one standardized effect packet by validating it, checking protection, then routing it through stacking/storage logic.
func apply_effect(effect_packet: Dictionary) -> Dictionary: # Receives one incoming effect packet and returns a standard effect_result packet.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.apply_effect() entered.") # Reports function entry for trace debugging.

	var validation_result: Dictionary = validate_effect_packet(effect_packet) # Validates the packet before any protection, stacking, or storage behavior can occur.

	if validation_result["status"] == "rejected": # Checks whether validation rejected the incoming packet.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.apply_effect() rejected during validation: " + str(validation_result["reason"])) # Reports the validation rejection path.

		return validation_result # Returns the rejected validation result without checking protection or stacking.

	if validation_result["status"] != "validated": # Checks for any unexpected validation status before continuing.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.apply_effect() failed: unexpected validation status: " + str(validation_result["status"])) # Reports the unexpected validation-status failure path.

		return { # Returns a standard failed result because apply_effect cannot safely continue with an unknown validation status.
			"status": "failed", # Marks the result as failed because validation returned an unexpected status.
			"effect_id": effect_packet.get("effect_id", "unknown"), # Reports the incoming effect id when available.
			"effect_instance_id": null, # Keeps instance id empty because failed effects are not stored.
			"target_unit": effect_packet.get("target_unit", null), # Reports the target unit when available.
			"reason": "unexpected validation status", # Explains why apply_effect stopped.
			"labels": [ # Provides semantic labels for the failure.
				"effect_packet_validation", # Marks that validation was the phase involved in this failure.
				"effect_result" # Marks that this return packet follows the effect result shape.
			] # Ends the result label list.
		} # Ends the failed result packet.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.apply_effect() validation passed.") # Reports the successful validation branch.

	var target_unit = effect_packet["target_unit"] # Reads the validated target unit for the protection check.

	var protection_result: Dictionary = check_protection(target_unit, effect_packet) # Checks whether active protection effects on the target block this incoming effect.

	if protection_result["status"] == "blocked": # Checks whether protection blocked the incoming effect.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.apply_effect() blocked by protection: " + str(protection_result["reason"])) # Reports the protection-blocked path.

		return protection_result # Returns the blocked protection result without stacking or storage.

	if protection_result["status"] != "not_blocked": # Checks for any unexpected protection status before continuing.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.apply_effect() failed: unexpected protection status: " + str(protection_result["status"])) # Reports the unexpected protection-status failure path.

		return { # Returns a standard failed result because apply_effect cannot safely continue with an unknown protection status.
			"status": "failed", # Marks the result as failed because protection returned an unexpected status.
			"effect_id": effect_packet.get("effect_id", "unknown"), # Reports the incoming effect id when available.
			"effect_instance_id": null, # Keeps instance id empty because failed effects are not stored.
			"target_unit": target_unit, # Reports the target unit being processed.
			"reason": "unexpected protection status", # Explains why apply_effect stopped.
			"labels": [ # Provides semantic labels for the failure.
				"effect_protection_check", # Marks that protection checking was the phase involved in this failure.
				"effect_result" # Marks that this return packet follows the effect result shape.
			] # Ends the result label list.
		} # Ends the failed result packet.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.apply_effect() protection passed; routing to stacking.") # Reports the successful protection branch and stacking route.

	var stacking_result: Dictionary = handle_stacking(effect_packet) # Routes the approved packet through stack, refresh, replace, unique, or storage behavior.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.apply_effect() completed with status: " + str(stacking_result["status"])) # Reports the final apply result status for trace debugging.

	return stacking_result # Returns the final effect result from stacking/storage behavior.
	
	
	
	
# Returns a read-only list of active effects currently stored on one unit.
func get_effects_for_unit(unit) -> Array: # Receives one unit id/reference and returns an Array of duplicated active effect packets.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.get_effects_for_unit() entered.") # Reports function entry for trace debugging.

	if not active_effects.has(unit): # Checks whether the requested unit has an active effect bucket.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.get_effects_for_unit() no active effects found for unit: " + str(unit)) # Reports the no-effects branch.

		return [] # Returns an empty list because the unit has no active effects.

	var target_effect_bucket: Dictionary = active_effects[unit] # Reads the unit's active effect bucket without allowing outside mutation.

	var effect_list: Array = [] # Prepares the read-only return list for active effect copies.

	for effect_instance_id in target_effect_bucket.keys(): # Loops through each active effect instance stored on the unit.
		var effect_runtime_packet: Dictionary = target_effect_bucket[effect_instance_id] # Reads the active runtime packet for this effect instance.

		effect_list.append(effect_runtime_packet.duplicate(true)) # Adds a deep copy so callers cannot mutate active_effects directly.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.get_effects_for_unit() returned effect count: " + str(effect_list.size())) # Reports how many active effect copies were returned.

	return effect_list # Returns duplicated active effects for safe external reading.
	
	
	
	
# Checks whether one unit currently has an active effect with the requested effect_id.
func has_effect(unit, effect_id: String) -> bool: # Receives one unit and one effect_id, then returns true if that effect is active on the unit.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.has_effect() entered.") # Reports function entry for trace debugging.

	if not active_effects.has(unit): # Checks whether the requested unit has an active effect bucket.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.has_effect() no active effect bucket found for unit: " + str(unit)) # Reports the no-bucket branch.

		return false # Returns false because a unit with no bucket cannot have the requested effect.

	var target_effect_bucket: Dictionary = active_effects[unit] # Reads the unit's active effect bucket for read-only lookup.

	for effect_instance_id in target_effect_bucket.keys(): # Loops through each active effect instance stored on the unit.
		var effect_runtime_packet: Dictionary = target_effect_bucket[effect_instance_id] # Reads the active runtime packet for this effect instance.

		if effect_runtime_packet.get("effect_id", "") == effect_id: # Checks whether the active effect_id matches the requested effect_id.
			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.has_effect() found active effect: " + str(effect_id)) # Reports the found-effect branch.

			return true # Returns true because the requested effect is active on the unit.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.has_effect() effect not found: " + str(effect_id)) # Reports the no-match branch.

	return false # Returns false because no active effect matched the requested effect_id.
	
	
	
	
# Checks whether one unit currently has any active effect from the requested effect_group.
func has_effect_group(unit, effect_group: String) -> bool: # Receives one unit and one effect_group, then returns true if that group is active on the unit.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.has_effect_group() entered.") # Reports function entry for trace debugging.

	if not active_effects.has(unit): # Checks whether the requested unit has an active effect bucket.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.has_effect_group() no active effect bucket found for unit: " + str(unit)) # Reports the no-bucket branch.

		return false # Returns false because a unit with no bucket cannot have the requested effect group.

	var target_effect_bucket: Dictionary = active_effects[unit] # Reads the unit's active effect bucket for read-only lookup.

	for effect_instance_id in target_effect_bucket.keys(): # Loops through each active effect instance stored on the unit.
		var effect_runtime_packet: Dictionary = target_effect_bucket[effect_instance_id] # Reads the active runtime packet for this effect instance.

		if effect_runtime_packet.get("effect_group", "") == effect_group: # Checks whether the active effect_group matches the requested effect_group.
			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.has_effect_group() found active effect group: " + str(effect_group)) # Reports the found-group branch.

			return true # Returns true because at least one active effect from the requested group is active on the unit.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.has_effect_group() effect group not found: " + str(effect_group)) # Reports the no-match branch.

	return false # Returns false because no active effect matched the requested effect_group.
	
	
	
	
# Returns read-only copies of active effects on one unit that affect the requested affect_key.
func get_effects_affecting(unit, affect_key: String) -> Array: # Receives one unit and one affect key, then returns duplicated active effect packets that include that affect.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.get_effects_affecting() entered.") # Reports function entry for trace debugging.

	if not active_effects.has(unit): # Checks whether the requested unit has an active effect bucket.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.get_effects_affecting() no active effect bucket found for unit: " + str(unit)) # Reports the no-bucket branch.

		return [] # Returns an empty list because a unit with no bucket has no effects affecting the requested key.

	var target_effect_bucket: Dictionary = active_effects[unit] # Reads the unit's active effect bucket for read-only lookup.

	var matching_effects: Array = [] # Prepares the return list for duplicated effects that affect the requested key.

	for effect_instance_id in target_effect_bucket.keys(): # Loops through each active effect instance stored on the unit.
		var effect_runtime_packet: Dictionary = target_effect_bucket[effect_instance_id] # Reads the active runtime packet for this effect instance.

		var effect_affects: Array = effect_runtime_packet.get("affects", []) # Reads the active effect's affects list, defaulting to empty for safe lookup.

		if effect_affects.has(affect_key): # Checks whether this active effect affects the requested key.
			matching_effects.append(effect_runtime_packet.duplicate(true)) # Adds a deep copy so callers cannot mutate active_effects directly.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.get_effects_affecting() returned effect count: " + str(matching_effects.size())) # Reports how many matching effect copies were returned.

	return matching_effects # Returns duplicated matching effects for safe external reading.
	
	
	
	
# Returns read-only active modifier effect packets for one unit and one affect_key without calculating final gameplay math.
func get_modifiers(unit, affect_key: String) -> Array: # Receives one unit and one affect key, then returns duplicated matching runtime effect packets.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.get_modifiers() entered.") # Reports function entry for trace debugging.

	if not active_effects.has(unit): # Checks whether the requested unit has an active effect bucket.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.get_modifiers() no active effect bucket found for unit: " + str(unit)) # Reports the no-bucket branch.

		return [] # Returns an empty list because a unit with no active bucket has no modifiers.

	var target_effect_bucket: Dictionary = active_effects[unit] # Reads the unit's active effect bucket for read-only lookup.

	var matching_modifiers: Array = [] # Prepares the return list for duplicated modifier runtime packets.

	for effect_instance_id in target_effect_bucket.keys(): # Loops through each active effect instance stored on the unit.
		var effect_runtime_packet: Dictionary = target_effect_bucket[effect_instance_id] # Reads the active runtime packet for this effect instance.

		var effect_affects: Array = effect_runtime_packet.get("affects", []) # Reads the effect's affects list, defaulting to empty for safe lookup.

		if effect_affects.has(affect_key): # Checks whether this effect modifies or reports the requested affect key.
			matching_modifiers.append(effect_runtime_packet.duplicate(true)) # Adds a deep copy so callers cannot mutate active_effects directly.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.get_modifiers() returned modifier count: " + str(matching_modifiers.size())) # Reports how many modifier packets were returned.

	return matching_modifiers # Returns raw duplicated modifier packets without calculating final gameplay values.
	
	
	
	
# Returns the current pulse window state for one unit as "N", "V", or null.
# Returns the current pulse window state for one unit, preferring values["current_window_state"] as source of truth.
func get_pulse_window_state(unit): # Receives one unit and returns its current pulse window state for BattleManager read access.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.get_pulse_window_state() entered.") # Reports function entry for trace debugging.

	if not active_effects.has(unit): # Checks whether the requested unit has an active effect bucket.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.get_pulse_window_state() no active effect bucket found for unit: " + str(unit)) # Reports the no-bucket branch.

		return null # Returns null because no active pulse effect exists on a unit with no active effect bucket.

	var target_effect_bucket: Dictionary = active_effects[unit] # Reads the unit's active effect bucket for read-only pulse lookup.

	for effect_instance_id in target_effect_bucket.keys(): # Loops through each active effect instance stored on the unit.
		var effect_runtime_packet: Dictionary = target_effect_bucket[effect_instance_id] # Reads the active runtime packet for this effect instance.

		if effect_runtime_packet.get("effect_group", "") != "pulse": # Checks whether this active effect belongs to the pulse group.
			continue # Skips non-pulse effects because only pulse effects own N/V window state.

		var current_window_state = null # Prepares the pulse window state value before checking official and fallback locations.

		var values: Dictionary = effect_runtime_packet.get("values", {}) # Reads the pulse values bundle where official pulse runtime state belongs.

		if typeof(values) == TYPE_DICTIONARY and values.has("current_window_state"): # Checks the official source of truth first.
			current_window_state = values["current_window_state"] # Reads the current pulse state from values["current_window_state"].

		elif effect_runtime_packet.has("current_window_state"): # Checks the optional top-level compatibility/debug mirror only if values state is missing.
			current_window_state = effect_runtime_packet["current_window_state"] # Reads the fallback mirror without treating it as source of truth.

		else: # Handles pulse effects that have no readable pulse window state.
			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.get_pulse_window_state() pulse effect missing current_window_state: " + str(effect_instance_id)) # Reports the missing-state branch.

			continue # Skips malformed pulse runtime state instead of inventing a window value.

		if current_window_state == "N": # Checks whether the pulse window is normal.
			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.get_pulse_window_state() returning pulse state N.") # Reports the normal-window return path.

			return "N" # Returns normal pulse state for BattleManager read access.

		if current_window_state == "V": # Checks whether the pulse window is vulnerable.
			if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
				print("StatEffectHandler.get_pulse_window_state() returning pulse state V.") # Reports the vulnerable-window return path.

			return "V" # Returns vulnerable pulse state for BattleManager read access.

		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.get_pulse_window_state() ignored invalid pulse state: " + str(current_window_state)) # Reports an invalid pulse-state branch.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.get_pulse_window_state() no active valid pulse state found.") # Reports the final no-pulse-state branch.

	return null # Returns null because no valid active pulse effect state was found.
# Applies approved tick behavior for one active runtime effect, limited to pulse timing for version 1.
func apply_tick(effect_runtime_packet: Dictionary) -> Dictionary: # Receives one active runtime effect packet and returns a tick result packet.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.apply_tick() entered.") # Reports function entry for trace debugging.

	var effect_id = effect_runtime_packet.get("effect_id", "unknown") # Reads the effect id for result reporting without assuming it exists.

	var effect_instance_id = effect_runtime_packet.get("effect_instance_id", null) # Reads the runtime instance id for result reporting without generating one.

	var target_unit = effect_runtime_packet.get("target_unit", null) # Reads the target unit for result reporting without assuming it exists.

	if effect_runtime_packet.get("effect_group", "") != "pulse": # Checks whether this effect is outside the approved version 1 tick behavior.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.apply_tick() ignored non-pulse tick for effect: " + str(effect_id)) # Reports the non-pulse ignored branch.

		return { # Returns a standard tick ignored result for non-pulse effects.
			"status": "tick_ignored", # Marks that no approved tick behavior was applied.
			"effect_id": effect_id, # Reports the effect id whose tick was ignored.
			"effect_instance_id": effect_instance_id, # Reports the existing runtime instance id without creating one.
			"target_unit": target_unit, # Reports the target unit for the ignored tick.
			"reason": "no approved tick behavior for this effect", # Explains that version 1 only supports pulse timing ticks.
			"labels": [ # Provides semantic labels for the ignored tick result.
				"effect_tick_due" # Marks that a tick was due but no gameplay behavior was approved for this effect.
			] # Ends the result label list.
		} # Ends the tick ignored result packet.

	var values: Dictionary = effect_runtime_packet.get("values", {}) # Reads pulse runtime data from values as approved.

	if typeof(values) != TYPE_DICTIONARY: # Checks whether values is invalid for pulse runtime data.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.apply_tick() failed: pulse values is not a Dictionary.") # Reports the invalid pulse values branch.

		return { # Returns a standard failed result because pulse pattern data cannot be read safely.
			"status": "failed", # Marks the tick as failed.
			"effect_id": effect_id, # Reports the effect id that failed ticking.
			"effect_instance_id": effect_instance_id, # Reports the existing runtime instance id without creating one.
			"target_unit": target_unit, # Reports the target unit for the failed tick.
			"reason": "invalid or missing pulse pattern", # Explains the approved invalid pulse failure reason.
			"labels": [ # Provides semantic labels for the failed tick result.
				"effect_tick_due" # Marks that a tick was due but failed validation.
			] # Ends the result label list.
		} # Ends the failed tick result packet.

	if not values.has("pattern"): # Checks whether the required pulse pattern is missing.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.apply_tick() failed: pulse pattern missing.") # Reports the missing pattern branch.

		return { # Returns a standard failed result because pulse pattern is required.
			"status": "failed", # Marks the tick as failed.
			"effect_id": effect_id, # Reports the effect id that failed ticking.
			"effect_instance_id": effect_instance_id, # Reports the existing runtime instance id without creating one.
			"target_unit": target_unit, # Reports the target unit for the failed tick.
			"reason": "invalid or missing pulse pattern", # Explains the approved invalid pulse failure reason.
			"labels": [ # Provides semantic labels for the failed tick result.
				"effect_tick_due" # Marks that a tick was due but failed validation.
			] # Ends the result label list.
		} # Ends the failed tick result packet.

	if not values.has("pattern_index"): # Checks whether the required pulse pattern index is missing.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.apply_tick() failed: pulse pattern_index missing.") # Reports the missing pattern_index branch.

		return { # Returns a standard failed result because pulse pattern_index is required.
			"status": "failed", # Marks the tick as failed.
			"effect_id": effect_id, # Reports the effect id that failed ticking.
			"effect_instance_id": effect_instance_id, # Reports the existing runtime instance id without creating one.
			"target_unit": target_unit, # Reports the target unit for the failed tick.
			"reason": "invalid or missing pulse pattern", # Explains the approved invalid pulse failure reason.
			"labels": [ # Provides semantic labels for the failed tick result.
				"effect_tick_due" # Marks that a tick was due but failed validation.
			] # Ends the result label list.
		} # Ends the failed tick result packet.

	if not values.has("current_window_state"): # Checks whether the required current pulse window state is missing.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.apply_tick() failed: pulse current_window_state missing.") # Reports the missing current_window_state branch.

		return { # Returns a standard failed result because current_window_state is required.
			"status": "failed", # Marks the tick as failed.
			"effect_id": effect_id, # Reports the effect id that failed ticking.
			"effect_instance_id": effect_instance_id, # Reports the existing runtime instance id without creating one.
			"target_unit": target_unit, # Reports the target unit for the failed tick.
			"reason": "invalid or missing pulse pattern", # Explains the approved invalid pulse failure reason.
			"labels": [ # Provides semantic labels for the failed tick result.
				"effect_tick_due" # Marks that a tick was due but failed validation.
			] # Ends the result label list.
		} # Ends the failed tick result packet.

	var pattern = values["pattern"] # Reads the pulse pattern sequence from values.

	if typeof(pattern) != TYPE_STRING: # Checks whether the pulse pattern is a String sequence.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.apply_tick() failed: pulse pattern is not a String.") # Reports the invalid pattern type branch.

		return { # Returns a standard failed result because pulse pattern must be readable as text.
			"status": "failed", # Marks the tick as failed.
			"effect_id": effect_id, # Reports the effect id that failed ticking.
			"effect_instance_id": effect_instance_id, # Reports the existing runtime instance id without creating one.
			"target_unit": target_unit, # Reports the target unit for the failed tick.
			"reason": "invalid or missing pulse pattern", # Explains the approved invalid pulse failure reason.
			"labels": [ # Provides semantic labels for the failed tick result.
				"effect_tick_due" # Marks that a tick was due but failed validation.
			] # Ends the result label list.
		} # Ends the failed tick result packet.

	if pattern.length() <= 0: # Checks whether the pulse pattern is empty.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.apply_tick() failed: pulse pattern is empty.") # Reports the empty pattern branch.

		return { # Returns a standard failed result because an empty pattern cannot advance.
			"status": "failed", # Marks the tick as failed.
			"effect_id": effect_id, # Reports the effect id that failed ticking.
			"effect_instance_id": effect_instance_id, # Reports the existing runtime instance id without creating one.
			"target_unit": target_unit, # Reports the target unit for the failed tick.
			"reason": "invalid or missing pulse pattern", # Explains the approved invalid pulse failure reason.
			"labels": [ # Provides semantic labels for the failed tick result.
				"effect_tick_due" # Marks that a tick was due but failed validation.
			] # Ends the result label list.
		} # Ends the failed tick result packet.

	var pattern_index: int = int(values["pattern_index"]) # Reads the pulse pattern index as an integer for safe advancement.

	pattern_index += 1 # Advances the pulse pattern index by one tick as approved.

	if pattern_index >= pattern.length(): # Checks whether the pattern index moved beyond the end of the pattern.
		pattern_index = 0 # Wraps the pattern index back to the beginning as approved.

	var current_window_state: String = pattern.substr(pattern_index, 1) # Reads the current pulse window character from the wrapped pattern index.

	if current_window_state != "N" and current_window_state != "V": # Checks whether the new pulse window state is one of the approved states.
		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.apply_tick() failed: invalid pulse window state: " + str(current_window_state)) # Reports the invalid state branch.

		return { # Returns a standard failed result because pulse state must be N or V.
			"status": "failed", # Marks the tick as failed.
			"effect_id": effect_id, # Reports the effect id that failed ticking.
			"effect_instance_id": effect_instance_id, # Reports the existing runtime instance id without creating one.
			"target_unit": target_unit, # Reports the target unit for the failed tick.
			"reason": "invalid or missing pulse pattern", # Explains the approved invalid pulse failure reason.
			"labels": [ # Provides semantic labels for the failed tick result.
				"effect_tick_due" # Marks that a tick was due but failed validation.
			] # Ends the result label list.
		} # Ends the failed tick result packet.

	values["pattern_index"] = pattern_index # Stores the advanced pattern index back into the runtime values dictionary.

	values["current_window_state"] = current_window_state # Stores the new current pulse window state back into the runtime values dictionary.

	effect_runtime_packet["values"] = values # Updates the runtime packet values with the advanced pulse timing state.

	effect_runtime_packet["current_window_state"] = current_window_state # Mirrors current_window_state at the runtime packet top level for get_pulse_window_state() compatibility.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.apply_tick() pulse window advanced to: " + str(current_window_state)) # Reports the successful pulse advancement branch.

	return { # Returns a standard tick applied result for the pulse timing update.
		"status": "tick_applied", # Marks that approved tick behavior was applied.
		"effect_id": effect_id, # Reports the pulse effect id that ticked.
		"effect_instance_id": effect_instance_id, # Reports the runtime instance id that ticked.
		"target_unit": target_unit, # Reports the target unit whose pulse state advanced.
		"reason": "pulse window advanced", # Explains the successful pulse tick result.
		"labels": [ # Provides semantic labels for the pulse tick result.
			"pulse_pattern_tick", # Marks that the pulse pattern ticked.
			"pulse_window_advance", # Marks that the pulse window advanced.
			"pulse_timing_active" # Marks that pulse timing is active.
		] # Ends the result label list.
	} # Ends the tick applied result packet.
	
	
	
	
# Updates active effects by counting down duration, ticking approved tick behavior, removing expired effects, and returning a summary.
func update_effects(delta: float) -> Dictionary: # Receives frame/time delta and returns a summary of tick and expiration results.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.update_effects() entered.") # Reports function entry for trace debugging.

	var update_summary: Dictionary = { # Creates the standard update summary dictionary.
		"status": "updated", # Marks that the active effect update pass ran.
		"ticks": [], # Stores tick result packets returned by apply_tick().
		"expired": [], # Stores expired result packets for effects removed during this update.
		"labels": [ # Stores semantic labels for the update pass.
			"effect_tick_update", # Marks that active effect ticking was processed.
			"effect_duration_countdown" # Marks that active effect duration countdown was processed.
		] # Ends the summary label list.
	} # Ends the update summary dictionary.

	var target_units_to_remove: Array = [] # Tracks target buckets that become empty and need cleanup after iteration.

	for target_unit_id in active_effects.keys(): # Loops through each target unit bucket in active effect storage.
		var target_effect_bucket: Dictionary = active_effects[target_unit_id] # Reads the target unit's active effect bucket.

		var effect_instances_to_remove: Array = [] # Tracks expired effect instances so they can be removed safely after iteration.

		for effect_instance_id in target_effect_bucket.keys(): # Loops through each active effect instance on the current target.
			var effect_runtime_packet: Dictionary = target_effect_bucket[effect_instance_id] # Reads the active runtime effect packet for update.

			var current_time_remaining: float = float(effect_runtime_packet.get("time_remaining", 0.0)) # Reads current remaining duration as a float.

			current_time_remaining -= delta # Reduces the effect duration by the update delta.

			effect_runtime_packet["time_remaining"] = current_time_remaining # Stores the updated remaining duration back into the runtime packet.

			var tick_rate: float = float(effect_runtime_packet.get("tick_rate", 0.0)) # Reads the tick rate as a float, defaulting to zero for no-tick effects.

			if tick_rate > 0.0: # Checks whether this effect has tick-based behavior.
				var tick_timer: float = float(effect_runtime_packet.get("tick_timer", tick_rate)) # Reads the current tick timer, defaulting to tick_rate if missing.

				tick_timer -= delta # Reduces the tick timer by the update delta.

				effect_runtime_packet["tick_timer"] = tick_timer # Stores the updated tick timer back into the runtime packet.

				if tick_timer <= 0.0: # Checks whether the effect tick is due.
					if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
						print("StatEffectHandler.update_effects() tick due for effect: " + str(effect_instance_id)) # Reports the tick-due branch.

					var tick_result: Dictionary = apply_tick(effect_runtime_packet) # Runs the approved tick behavior for this runtime effect.

					update_summary["ticks"].append(tick_result) # Adds the tick result packet to the update summary.

					effect_runtime_packet["tick_timer"] = tick_rate # Resets the tick timer to the effect's tick rate after the tick attempt.

			if effect_runtime_packet["time_remaining"] <= 0.0: # Checks whether the effect duration has expired.
				if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
					print("StatEffectHandler.update_effects() expiring effect: " + str(effect_instance_id)) # Reports the expiration branch.

				var expired_labels: Array = [ # Creates the standard expired label list.
					"effect_expire_when_duration_zero", # Marks that the effect expired because duration reached zero.
					"effect_remove" # Marks that the effect is being removed from active storage.
				] # Ends the standard expired label list.

				var visual_expire_labels: Array = effect_runtime_packet.get("visual_labels_on_expire", []) # Reads optional expire visual labels, defaulting to an empty list.

				for visual_label in visual_expire_labels: # Loops through optional expire visual labels.
					expired_labels.append(visual_label) # Appends each visual expire label to the expired result labels.

				var expired_result: Dictionary = { # Creates a standard expired result packet.
					"status": "expired", # Marks the effect as expired.
					"effect_id": effect_runtime_packet.get("effect_id", "unknown"), # Reports the expired effect id when available.
					"effect_instance_id": effect_runtime_packet.get("effect_instance_id", null), # Reports the expired runtime instance id when available.
					"target_unit": effect_runtime_packet.get("target_unit", null), # Reports the target unit that owned the expired effect.
					"reason": "duration expired", # Explains why the effect was removed.
					"labels": expired_labels # Provides semantic labels for expiration and optional visuals.
				} # Ends the expired result packet.

				update_summary["expired"].append(expired_result) # Adds the expired result packet to the update summary.

				effect_instances_to_remove.append(effect_instance_id) # Queues the expired effect instance for safe removal after this loop.

		for effect_instance_id in effect_instances_to_remove: # Loops through expired effects after iteration to safely remove them.
			target_effect_bucket.erase(effect_instance_id) # Removes the expired effect from active_effects for this target.

		if target_effect_bucket.is_empty(): # Checks whether the target bucket has no active effects remaining.
			target_units_to_remove.append(target_unit_id) # Queues the empty target bucket for cleanup after target iteration.

	for target_unit_id in target_units_to_remove: # Loops through empty target buckets after iteration.
		active_effects.erase(target_unit_id) # Removes the empty target bucket from active effect storage.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.update_effects() complete. Ticks: " + str(update_summary["ticks"].size()) + " Expired: " + str(update_summary["expired"].size())) # Reports final tick and expiration counts.

	return update_summary # Returns the summary of ticks processed and effects expired.
	
	
	
	
# Removes one active effect by effect_instance_id and returns an expired or failed result packet.
func expire_effect(effect_instance_id: String) -> Dictionary: # Receives one active effect instance id and removes that effect if found.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.expire_effect() entered.") # Reports function entry for trace debugging.

	for target_unit_id in active_effects.keys(): # Loops through each target bucket because primary storage is organized by target first.
		var target_effect_bucket: Dictionary = active_effects[target_unit_id] # Reads the current target unit's active effect bucket.

		if not target_effect_bucket.has(effect_instance_id): # Checks whether this target bucket does not contain the requested instance id.
			continue # Skips this target bucket because the requested effect is not stored here.

		var effect_runtime_packet: Dictionary = target_effect_bucket[effect_instance_id] # Reads the runtime effect packet before removal so result data can be reported.

		var expired_labels: Array = [ # Creates the standard expiration/removal label list.
			"effect_remove", # Marks that an active effect is being removed.
			"effect_expire_cleanup" # Marks that expiration cleanup behavior is being performed.
		] # Ends the standard expiration/removal label list.

		var visual_expire_labels: Array = effect_runtime_packet.get("visual_labels_on_expire", []) # Reads optional expire visual labels, defaulting to an empty list.

		for visual_label in visual_expire_labels: # Loops through optional visual labels that should fire on expiration.
			expired_labels.append(visual_label) # Adds each optional expire visual label to the result packet.

		if not visual_expire_labels.is_empty(): # Checks whether any visual expire labels were added.
			expired_labels.append("effect_removed_visual") # Adds the removed-visual label because visual expiration labels were present.

		target_effect_bucket.erase(effect_instance_id) # Removes the active effect from active_effects[target_unit_id].

		if target_effect_bucket.is_empty(): # Checks whether this target bucket has no remaining active effects.
			active_effects.erase(target_unit_id) # Removes the empty target bucket to keep active effect storage clean.

		if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
			print("StatEffectHandler.expire_effect() removed effect: " + str(effect_instance_id)) # Reports the successful removal path.

		return { # Returns a standard expired result packet.
			"status": "expired", # Marks the effect as expired/removed.
			"effect_id": effect_runtime_packet.get("effect_id", "unknown"), # Reports the removed effect id when available.
			"effect_instance_id": effect_instance_id, # Reports the removed runtime instance id.
			"target_unit": effect_runtime_packet.get("target_unit", target_unit_id), # Reports the target unit that owned the removed effect.
			"reason": "effect expired", # Explains that the effect was removed through expire_effect().
			"labels": expired_labels # Provides semantic labels for removal, cleanup, and optional visuals.
		} # Ends the expired result packet.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.expire_effect() failed: effect_instance_id not found: " + str(effect_instance_id)) # Reports the not-found failure path.

	return { # Returns a standard failed result because the requested active effect instance could not be found.
		"status": "failed", # Marks the result as failed because no matching active effect was removed.
		"effect_id": "unknown", # Reports unknown because the effect packet was not found.
		"effect_instance_id": effect_instance_id, # Reports the requested instance id that could not be found.
		"target_unit": null, # Reports null because no owning target bucket was found.
		"reason": "effect_instance_id not found", # Explains why expiration failed.
		"labels": [ # Provides semantic labels for the failed removal attempt.
			"effect_remove" # Marks that removal was attempted.
		] # Ends the failed result label list.
	} # Ends the failed result packet.
	
	
	
	
# Removes battle-only active effects matching the cleanup battle_id while preserving persistent effects.
func clear_battle_effects(battle_id = null) -> Dictionary: # Receives an optional battle_id and returns a cleanup summary packet.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.clear_battle_effects() entered.") # Reports function entry for trace debugging.

	var cleanup_summary: Dictionary = { # Creates the standard cleanup summary dictionary.
		"status": "cleanup_complete", # Marks that battle effect cleanup finished.
		"battle_id": battle_id, # Reports the battle_id used for cleanup filtering.
		"removed": [], # Stores result packets for battle-only effects removed during cleanup.
		"preserved": [], # Stores read-only summary packets for persistent effects preserved during cleanup.
		"labels": [ # Stores semantic labels for the cleanup pass.
			"clear_battle_effects", # Marks that battle effect cleanup was performed.
			"effect_cleanup_complete" # Marks that cleanup completed.
		] # Ends the cleanup summary label list.
	} # Ends the cleanup summary dictionary.

	var target_units_to_remove: Array = [] # Tracks target buckets that become empty and need cleanup after iteration.

	for target_unit_id in active_effects.keys(): # Loops through each target unit bucket in active effect storage.
		var target_effect_bucket: Dictionary = active_effects[target_unit_id] # Reads the target unit's active effect bucket.

		var effect_instances_to_remove: Array = [] # Tracks effect instances to remove safely after bucket iteration.

		for effect_instance_id in target_effect_bucket.keys(): # Loops through each active effect instance on the current target.
			var effect_runtime_packet: Dictionary = target_effect_bucket[effect_instance_id] # Reads the active runtime effect packet for cleanup checks.

			var effect_battle_only: bool = bool(effect_runtime_packet.get("battle_only", false)) # Reads whether this effect is battle-only, defaulting to false for safety.

			var effect_battle_id = effect_runtime_packet.get("battle_id", null) # Reads the effect battle_id, defaulting to null if missing.

			if effect_battle_only == false: # Checks whether the effect is persistent and should be preserved.
				if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
					print("StatEffectHandler.clear_battle_effects() preserving persistent effect: " + str(effect_instance_id)) # Reports the persistent-preserved branch.

				cleanup_summary["preserved"].append({ # Adds a preserved summary packet for trace reporting.
					"status": "preserved", # Marks that this active effect was preserved.
					"effect_id": effect_runtime_packet.get("effect_id", "unknown"), # Reports the preserved effect id when available.
					"effect_instance_id": effect_instance_id, # Reports the preserved runtime instance id.
					"target_unit": effect_runtime_packet.get("target_unit", target_unit_id), # Reports the target unit that owns the preserved effect.
					"reason": "persistent effect preserved", # Explains why the effect was not removed.
					"labels": [ # Provides semantic labels for preservation.
						"persistent_effect_preserved" # Marks that a persistent effect was preserved.
					] # Ends the preserved packet label list.
				}) # Ends the preserved summary append.

				continue # Skips removal logic because persistent effects must remain active.

			if battle_id != null and effect_battle_id != battle_id: # Checks whether cleanup is limited to a specific battle_id and this effect does not match it.
				if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
					print("StatEffectHandler.clear_battle_effects() preserving battle_only effect from different battle_id: " + str(effect_instance_id)) # Reports the different-battle preservation branch.

				cleanup_summary["preserved"].append({ # Adds a preserved summary packet for a battle-only effect from another battle.
					"status": "preserved", # Marks that this active effect was preserved.
					"effect_id": effect_runtime_packet.get("effect_id", "unknown"), # Reports the preserved effect id when available.
					"effect_instance_id": effect_instance_id, # Reports the preserved runtime instance id.
					"target_unit": effect_runtime_packet.get("target_unit", target_unit_id), # Reports the target unit that owns the preserved effect.
					"reason": "battle_id did not match cleanup target", # Explains why the battle-only effect was not removed.
					"labels": [ # Provides semantic labels for battle_id preservation.
						"effect_cleanup_by_battle_id", # Marks that battle_id filtering was used.
						"persistent_effect_preserved" # Marks that this effect was preserved during cleanup.
					] # Ends the preserved packet label list.
				}) # Ends the preserved summary append.

				continue # Skips removal logic because this battle-only effect belongs to another battle.

			var removed_labels: Array = [ # Creates the standard cleanup removal label list.
				"battle_only_effect", # Marks that the removed effect was battle-only.
				"effect_removed_during_cleanup" # Marks that the effect was removed during cleanup.
			] # Ends the standard cleanup removal label list.

			if battle_id != null: # Checks whether cleanup was filtered by a specific battle_id.
				removed_labels.append("effect_cleanup_by_battle_id") # Adds the battle_id cleanup label because battle_id filtering was used.

			var visual_cleanup_labels: Array = effect_runtime_packet.get("visual_labels_on_cleanup", []) # Reads optional cleanup visual labels, defaulting to an empty list.

			for visual_label in visual_cleanup_labels: # Loops through optional cleanup visual labels.
				removed_labels.append(visual_label) # Appends each optional cleanup visual label to the removed result labels.

			cleanup_summary["removed"].append({ # Adds a removed result packet to the cleanup summary.
				"status": "removed", # Marks that the effect was removed during cleanup.
				"effect_id": effect_runtime_packet.get("effect_id", "unknown"), # Reports the removed effect id when available.
				"effect_instance_id": effect_instance_id, # Reports the removed runtime instance id.
				"target_unit": effect_runtime_packet.get("target_unit", target_unit_id), # Reports the target unit that owned the removed effect.
				"reason": "battle_only effect removed during cleanup", # Explains why the effect was removed.
				"labels": removed_labels # Provides semantic labels for cleanup removal and optional visuals.
			}) # Ends the removed result append.

			effect_instances_to_remove.append(effect_instance_id) # Queues this battle-only effect for safe removal after iteration.

		for effect_instance_id in effect_instances_to_remove: # Loops through queued cleanup removals after bucket iteration.
			target_effect_bucket.erase(effect_instance_id) # Removes the battle-only effect from active_effects[target_unit_id].

		if target_effect_bucket.is_empty(): # Checks whether the target bucket has no active effects remaining.
			target_units_to_remove.append(target_unit_id) # Queues the empty target bucket for cleanup after target iteration.

	for target_unit_id in target_units_to_remove: # Loops through target buckets that became empty.
		active_effects.erase(target_unit_id) # Removes the empty target bucket from active effect storage.

	if Globals.debug_statEff: # Checks whether StatEffectHandler debug output is enabled.
		print("StatEffectHandler.clear_battle_effects() complete. Removed: " + str(cleanup_summary["removed"].size()) + " Preserved: " + str(cleanup_summary["preserved"].size())) # Reports final cleanup counts.

	return cleanup_summary # Returns the cleanup summary packet.
	
	
	
	
var test_pulse_packet: Dictionary = {
	"effect_id": "pulse_window_mk1",
	"effect_group": "pulse",
	"effect_type": "timing_modifier",

	"source_unit": "player",
	"target_unit": "enemy",
	"owner_unit": "player",
	"event_side": "player",

	"duration": 10.0,
	"time_remaining": 10.0,
	"tick_rate": 1.0,

	"stack_rule": "refresh",
	"priority": 1,

	"affects": ["shield"],

	"values": {
		"pattern": "NNNNVNNNNV",
		"pattern_index": 0,
		"current_window_state": "N"
	},

	"flags": {
		"runs_without_lock": true,
		"no_damage_without_lock": true,
		"bypass_shield_on_v": true
	},

	"source_event_id": "test_event_001",
	"battle_id": "test_battle_001",
	"battle_only": true,

	"visual_labels": [],
	"visual_labels_on_expire": [],
	"visual_labels_on_cleanup": []
}
