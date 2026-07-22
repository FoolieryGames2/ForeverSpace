extends Control
class_name BattleV2UIHandler

signal battle_v2_ui_event_received(match_id: String, packet: Dictionary)

const BattleV2EffectLayerScript = preload("res://battle_v2/BattleV2EffectLayer.gd")
const BattleV2EffectRecipesScript = preload("res://battle_v2/BattleV2EffectRecipes.gd")
const UIHandlerHelpersScript = preload("res://UI/UIHandlerHelpers.gd")

const TOP_LAYER_Z_INDEX := 500
const HISTORY_LIMIT := 100

const MATCH_ACTION_BUTTON_CLICKED := "battle_v2_action_button_clicked"
const MATCH_TODO_ACTIVE := "battle_v2_todo_active"
const MATCH_TODO_COMPLETED := "battle_v2_todo_completed"
const MATCH_HEADER_STATE := "battle_v2_header_state"
const MATCH_SEMANTIC_EVENT := "battle_v2_semantic_event"
const MATCH_DRONE_RUNTIME := "battle_v2_drone_runtime"

const PULSE_LASER_PRE_FINISH_REMAINING_SEC := 0.25
const ENEMY_PRIMARY_PRE_FINISH_REMAINING_SEC := 0.25
const SECONDARY_WEAPON_PRE_FINISH_REMAINING_SEC := 0.16
const RECOVERY_PACK_PRE_FINISH_REMAINING_SEC := 0.35
const EXPLOSIVE_PRE_FINISH_REMAINING_SEC := 0.30
const RECOVERY_PACK_FLIGHT_DURATION := 0.28
const PLAYER_SHIELD_RING_COLOR := Color(0.15, 0.60, 1.0, 0.50)
const ENEMY_SHIELD_RING_COLOR := Color(1.0, 0.12, 0.08, 0.50)
const COLOR_PLAYER_ENERGY := Color(0.15, 0.60, 1.0, 0.85)
const COLOR_ENEMY_ENERGY := Color(1.0, 0.12, 0.08, 0.85)
const COLOR_SHIELD := Color(0.10, 0.90, 1.0, 0.80)
const COLOR_REPAIR := Color(0.25, 1.0, 0.35, 0.80)
const COLOR_RECHARGE_BLUE := Color(0.12, 0.58, 1.0, 0.88)
const COLOR_RECHARGE_CORE := Color(0.72, 0.94, 1.0, 1.0)
const COLOR_RECHARGE_ARC := Color(0.35, 0.82, 1.0, 0.78)
const COLOR_KINETIC := Color(0.95, 0.95, 0.82, 0.85)
const COLOR_EXPLOSIVE := Color(1.0, 0.55, 0.08, 0.90)
const COLOR_EXPLOSIVE_CORE := Color(1.0, 0.88, 0.38, 0.98)
const BATTLE_HUD_FRAME_REFRESH_INTERVAL := 0.35
const BATTLE_HUD_FRAME_POINTS := [
	"player_panel",
	"enemy_panel",
	"battle_v3_pipeline",
	"shield_panel",
	"action_panel",
	"battle_v3_reference_panel",
	"battle_log"
]

# Position data stays in the packet receiver. Recipes ask the effect layer for
# point IDs instead of hardcoding coordinates.
const DECORATION_POINTS := {
	"scene_top_layer": {
		"position": Vector2(0, 0),
		"size": Vector2(1280, 760),
		"purpose": "full-screen overlay root"
	},
	"player_panel": {
		"position": Vector2(40, 95),
		"size": Vector2(370, 185),
		"purpose": "player status widget"
	},
	"player_hp_box": {
		"position": Vector2(54, 151),
		"size": Vector2(342, 20),
		"purpose": "player hull text and future hp effects"
	},
	"player_shield_box": {
		"position": Vector2(54, 172),
		"size": Vector2(342, 20),
		"purpose": "player shield text and future shield effects"
	},
	"enemy_panel": {
		"position": Vector2(890, 95),
		"size": Vector2(370, 185),
		"purpose": "enemy status widget"
	},
	"enemy_hp_box": {
		"position": Vector2(904, 151),
		"size": Vector2(342, 20),
		"purpose": "enemy hull text and future hp effects"
	},
	"enemy_shield_box": {
		"position": Vector2(904, 172),
		"size": Vector2(342, 20),
		"purpose": "enemy shield text and future shield effects"
	},
	"center_stage": {
		"position": Vector2(430, 105),
		"size": Vector2(430, 175),
		"purpose": "large battle decorations between units"
	},
	"player_damage_float": {
		"position": Vector2(220, 146),
		"size": Vector2(160, 44),
		"purpose": "player damage or recovery float text"
	},
	"player_drone_anchor": {
		"position": Vector2(430, 305),
		"size": Vector2(72, 72),
		"purpose": "player auto attack drone parking orbit"
	},
	"enemy_damage_float": {
		"position": Vector2(920, 146),
		"size": Vector2(160, 44),
		"purpose": "enemy damage or recovery float text"
	},
	"enemy_drone_anchor": {
		"position": Vector2(790, 305),
		"size": Vector2(72, 72),
		"purpose": "enemy auto attack drone parking orbit"
	},
	"action_panel": {
		"position": Vector2(280, 300),
		"size": Vector2(590, 275),
		"purpose": "player action widget"
	},
	"action_button_stack": {
		"position": Vector2(292, 388),
		"size": Vector2(566, 175),
		"purpose": "current action rows"
	},
	"consumable_action_button": {
		"position": Vector2(452, 668),
		"size": Vector2(95, 35),
		"purpose": "consumable execute button and recovery pack launch point"
	},
	"todo_panel": {
		"position": Vector2(280, 600),
		"size": Vector2(590, 140),
		"purpose": "active and completed TODO timeline"
	},
	"todo_next_row": {
		"position": Vector2(292, 645),
		"size": Vector2(566, 22),
		"purpose": "next completing TODO"
	},
	"todo_stack": {
		"position": Vector2(292, 672),
		"size": Vector2(566, 42),
		"purpose": "remaining TODO list"
	},
	"evade_button": {
		"position": Vector2(752, 606),
		"size": Vector2(104, 28),
		"purpose": "player evade action"
	},
	"battle_log": {
		"position": Vector2(900, 300),
		"size": Vector2(360, 440),
		"purpose": "battle log widget"
	},
	"shield_panel": {
		"position": Vector2(40, 300),
		"size": Vector2(210, 275),
		"purpose": "shield power widget"
	}
}

var battle_id: String = ""
var battle_scene_ref = null
var label_refs: Dictionary = {}
var latest_by_match_id: Dictionary = {}
var event_history: Array = []
var action_click_history: Array = []
var todo_active_history: Array = []
var todo_completed_history: Array = []
var latest_action_click_packet: Dictionary = {}
var latest_todo_active_packet: Dictionary = {}
var latest_todo_completed_packet: Dictionary = {}
var latest_header_state_packet: Dictionary = {}
var latest_drone_runtime_packet: Dictionary = {}
var effect_layer: BattleV2EffectLayer = null
var effect_recipes = null
var ui_helpers = UIHandlerHelpersScript.new()
var decoration_points: Dictionary = DECORATION_POINTS.duplicate(true)

var fired_pre_finish_line_event_ids: Dictionary = {}
var fired_enemy_primary_charge_event_ids: Dictionary = {}
var fired_enemy_primary_pre_finish_line_event_ids: Dictionary = {}
var fired_secondary_weapon_load_event_ids: Dictionary = {}
var fired_secondary_weapon_pre_finish_event_ids: Dictionary = {}
var fired_recovery_pack_ready_event_ids: Dictionary = {}
var fired_recovery_pack_launch_event_ids: Dictionary = {}
var fired_recovery_pack_complete_event_ids: Dictionary = {}
var fired_explosive_load_event_ids: Dictionary = {}
var fired_explosive_ready_event_ids: Dictionary = {}
var fired_explosive_pre_finish_event_ids: Dictionary = {}
var fired_explosive_complete_event_ids: Dictionary = {}
var known_auto_attack_drone_runtime_ids: Dictionary = {}
var fired_auto_attack_drone_attack_keys: Dictionary = {}
var latest_semantic_event_packet: Dictionary = {}
var semantic_event_history: Array = []
var battle_hud_energy_frames_enabled: bool = false
var battle_hud_energy_frame_refresh_timer: float = 0.0


func _ready() -> void:
	name = "Battle_V2_UI_Handler"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = TOP_LAYER_Z_INDEX
	z_as_relative = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(Globals.screen_w, Globals.screen_h)
	set_process(true)
	ensure_effect_layer()


func _process(delta: float) -> void:
	if not battle_hud_energy_frames_enabled:
		return

	battle_hud_energy_frame_refresh_timer -= delta
	if battle_hud_energy_frame_refresh_timer > 0.0:
		return

	battle_hud_energy_frame_refresh_timer = BATTLE_HUD_FRAME_REFRESH_INTERVAL
	refresh_all_battle_hud_energy_frames()


func setup(refs: Dictionary) -> void:
	battle_id = str(refs.get("battle_id", battle_id))
	battle_scene_ref = refs.get("battle_scene", null)
	if refs.get("ui_helpers", null) != null:
		ui_helpers = refs.get("ui_helpers")
	if typeof(refs.get("battle_ui_labels", {})) == TYPE_DICTIONARY:
		label_refs = refs.get("battle_ui_labels", {})
	if typeof(refs.get("battle_ui_points", {})) == TYPE_DICTIONARY:
		set_position_data(refs.get("battle_ui_points", {}))
	elif typeof(refs.get("position_data", {})) == TYPE_DICTIONARY:
		set_position_data(refs.get("position_data", {}))
	ensure_effect_layer()
	receive_ui_event(MATCH_HEADER_STATE, get_current_header_state())
	if bool(refs.get("show_battle_hud_energy_frames", true)):
		show_all_battle_hud_energy_frames()


func ensure_effect_layer() -> void:
	if effect_recipes == null:
		effect_recipes = BattleV2EffectRecipesScript.new()

	if effect_layer != null:
		return

	effect_layer = BattleV2EffectLayerScript.new()
	effect_layer.name = "Battle_V2_Effect_Layer"
	effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effect_layer)
	effect_layer.setup({
		"position_data": get_position_data(),
		"size": Vector2(Globals.screen_w, Globals.screen_h),
		"z_index": TOP_LAYER_Z_INDEX + 100
	})


func set_position_data(new_position_data: Dictionary) -> void:
	# Summary: Accept scene-owned decoration points so effects track the real current layout.
	decoration_points = DECORATION_POINTS.duplicate(true)
	for point_id in new_position_data.keys():
		if typeof(new_position_data[point_id]) == TYPE_DICTIONARY:
			decoration_points[point_id] = new_position_data[point_id].duplicate(true)

	if effect_layer != null:
		effect_layer.setup({
			"position_data": get_position_data(),
			"size": Vector2(Globals.screen_w, Globals.screen_h),
			"z_index": TOP_LAYER_Z_INDEX + 100
		})
		if battle_hud_energy_frames_enabled:
			refresh_all_battle_hud_energy_frames()


func receive_ui_event(match_id: String, packet: Dictionary = {}) -> Dictionary:
	var normalized_packet := build_normalized_packet(match_id, packet)
	latest_by_match_id[match_id] = normalized_packet
	event_history.append(normalized_packet)
	trim_array_to_limit(event_history, HISTORY_LIMIT)

	match match_id:
		MATCH_ACTION_BUTTON_CLICKED:
			on_action_button_clicked(normalized_packet)
		MATCH_TODO_ACTIVE:
			on_todo_active(normalized_packet)
		MATCH_TODO_COMPLETED:
			on_todo_completed(normalized_packet)
		MATCH_HEADER_STATE:
			on_header_state(normalized_packet)
		MATCH_SEMANTIC_EVENT:
			on_semantic_event(normalized_packet)
		MATCH_DRONE_RUNTIME:
			on_drone_runtime(normalized_packet)
		_:
			on_unmatched_ui_event(normalized_packet)

	battle_v2_ui_event_received.emit(match_id, normalized_packet)
	return normalized_packet


func build_normalized_packet(match_id: String, packet: Dictionary) -> Dictionary:
	var normalized_packet = ui_helpers.build_normalized_packet(
		match_id,
		packet,
		battle_id,
		get_position_data(),
		get_current_header_state()
	)
	if str(normalized_packet.get("battle_id", "")).strip_edges() == "":
		normalized_packet["battle_id"] = battle_id
	return normalized_packet


func on_action_button_clicked(packet: Dictionary) -> void:
	latest_action_click_packet = packet
	action_click_history.append(packet)
	trim_array_to_limit(action_click_history, HISTORY_LIMIT)

	if is_player_pulse_laser_action_start(packet):
		if Globals.print_priority_2:
			print("[BattleV2UIHandler] Pulse Laser clicked | event_id=", packet.get("event_id", ""))
		ensure_effect_layer()
		effect_recipes.play_player_pulse_laser_start(effect_layer, packet)

	if is_player_secondary_weapon_action_start(packet):
		if Globals.print_priority_2:
			print("[BattleV2UIHandler] Secondary weapon clicked | event_id=", packet.get("event_id", ""))
		ensure_effect_layer()
		effect_recipes.play_player_secondary_weapon_start(effect_layer, packet)

	if is_recovery_execute_action_click(packet):
		var recovery_click_kind := get_recovery_consumable_kind(packet)
		if recovery_click_kind == "recharge":
			packet["recovery_kind"] = recovery_click_kind
			play_recharge_action_click(packet)

	if is_explosive_load_action_click(packet):
		play_explosive_load_action_click(packet)

	if is_explosive_execute_action_click(packet):
		play_explosive_execute_action_click(packet)


func on_todo_active(packet: Dictionary) -> void:
	latest_todo_active_packet = packet
	todo_active_history.append(packet)
	trim_array_to_limit(todo_active_history, HISTORY_LIMIT)

	var events: Array = []
	if typeof(packet.get("events", [])) == TYPE_ARRAY:
		events = packet.get("events", [])

	for event_summary in events:
		if typeof(event_summary) != TYPE_DICTIONARY:
			continue

		var event_id := str(event_summary.get("event_id", "")).strip_edges()
		var time_remaining := float(event_summary.get("time_remaining", 999.0))

		if is_player_pulse_laser_event(event_summary):
			if event_id != "" and not fired_pre_finish_line_event_ids.has(event_id) and time_remaining <= PULSE_LASER_PRE_FINISH_REMAINING_SEC:
				fired_pre_finish_line_event_ids[event_id] = true
				ensure_effect_layer()
				effect_recipes.play_player_pulse_laser_pre_finish(effect_layer, event_summary)

		if is_enemy_primary_attack_event(event_summary):
			if event_id != "" and not fired_enemy_primary_charge_event_ids.has(event_id):
				fired_enemy_primary_charge_event_ids[event_id] = true
				ensure_effect_layer()
				effect_recipes.play_enemy_primary_start(effect_layer, event_summary)

			if event_id != "" and not fired_enemy_primary_pre_finish_line_event_ids.has(event_id) and time_remaining <= ENEMY_PRIMARY_PRE_FINISH_REMAINING_SEC:
				fired_enemy_primary_pre_finish_line_event_ids[event_id] = true
				ensure_effect_layer()
				effect_recipes.play_enemy_primary_pre_finish(effect_layer, event_summary)

		if is_secondary_weapon_event(event_summary):
			if event_id != "" and not fired_secondary_weapon_load_event_ids.has(event_id):
				fired_secondary_weapon_load_event_ids[event_id] = true
				ensure_effect_layer()
				effect_recipes.play_secondary_weapon_load(effect_layer, event_summary)

			if event_id != "" and not fired_secondary_weapon_pre_finish_event_ids.has(event_id) and time_remaining <= SECONDARY_WEAPON_PRE_FINISH_REMAINING_SEC:
				fired_secondary_weapon_pre_finish_event_ids[event_id] = true
				ensure_effect_layer()
				effect_recipes.play_secondary_weapon_pre_finish(effect_layer, event_summary)

		var recovery_kind := ""
		if is_recovery_execute_todo_event(event_summary):
			recovery_kind = get_recovery_consumable_kind(event_summary)

		if recovery_kind != "":
			event_summary["recovery_kind"] = recovery_kind
			if event_id != "" and not fired_recovery_pack_ready_event_ids.has(event_id):
				fired_recovery_pack_ready_event_ids[event_id] = true
				ensure_effect_layer()
				if recovery_kind == "recharge":
					play_recharge_todo_ready(event_summary)
				else:
					effect_recipes.play_recovery_pack_ready(effect_layer, event_summary)

			if event_id != "" and not fired_recovery_pack_launch_event_ids.has(event_id) and time_remaining <= RECOVERY_PACK_PRE_FINISH_REMAINING_SEC:
				fired_recovery_pack_launch_event_ids[event_id] = true
				ensure_effect_layer()
				if recovery_kind == "recharge":
					play_recharge_pack_launch(event_summary)
				else:
					effect_recipes.play_recovery_pack_launch(effect_layer, event_summary)

		if is_explosive_load_todo_event(event_summary):
			if event_id != "" and not fired_explosive_load_event_ids.has(event_id):
				fired_explosive_load_event_ids[event_id] = true
				play_explosive_load_todo_ready(event_summary)

		if is_explosive_execute_todo_event(event_summary):
			if event_id != "" and not fired_explosive_ready_event_ids.has(event_id):
				fired_explosive_ready_event_ids[event_id] = true
				play_explosive_todo_ready(event_summary)

			if event_id != "" and not fired_explosive_pre_finish_event_ids.has(event_id) and time_remaining <= EXPLOSIVE_PRE_FINISH_REMAINING_SEC:
				fired_explosive_pre_finish_event_ids[event_id] = true
				play_explosive_pre_finish(event_summary)


func on_todo_completed(packet: Dictionary) -> void:
	latest_todo_completed_packet = packet
	todo_completed_history.append(packet)
	trim_array_to_limit(todo_completed_history, HISTORY_LIMIT)

	var events: Array = []
	if typeof(packet.get("events", [])) == TYPE_ARRAY:
		events = packet.get("events", [])

	for event_summary in events:
		if typeof(event_summary) != TYPE_DICTIONARY:
			continue

		if is_player_pulse_laser_event(event_summary):
			ensure_effect_layer()
			effect_recipes.play_player_pulse_laser_complete(effect_layer, event_summary)

		if is_enemy_primary_attack_event(event_summary):
			ensure_effect_layer()
			effect_recipes.play_enemy_primary_complete(effect_layer, event_summary)

		if is_secondary_weapon_event(event_summary):
			ensure_effect_layer()
			var event_id := str(event_summary.get("event_id", "")).strip_edges()
			if event_id != "" and not fired_secondary_weapon_load_event_ids.has(event_id):
				fired_secondary_weapon_load_event_ids[event_id] = true
				effect_recipes.play_secondary_weapon_load(effect_layer, event_summary)
			if event_id == "" or not fired_secondary_weapon_pre_finish_event_ids.has(event_id):
				if event_id != "":
					fired_secondary_weapon_pre_finish_event_ids[event_id] = true
				effect_recipes.play_secondary_weapon_pre_finish(effect_layer, event_summary)
			effect_recipes.play_secondary_weapon_complete(effect_layer, event_summary)

		var recovery_kind := ""
		if is_recovery_execute_todo_event(event_summary):
			recovery_kind = get_recovery_consumable_kind(event_summary)

		if recovery_kind != "":
			event_summary["recovery_kind"] = recovery_kind
			ensure_effect_layer()
			var recovery_event_id := str(event_summary.get("event_id", "")).strip_edges()
			if recovery_event_id != "" and fired_recovery_pack_complete_event_ids.has(recovery_event_id):
				continue

			var pack_was_launched := recovery_event_id != "" and fired_recovery_pack_launch_event_ids.has(recovery_event_id)
			if not pack_was_launched:
				if recovery_kind == "recharge":
					play_recharge_pack_launch(event_summary)
				else:
					effect_recipes.play_recovery_pack_launch(effect_layer, event_summary)
				if recovery_event_id != "":
					fired_recovery_pack_launch_event_ids[recovery_event_id] = true

			if recovery_event_id != "":
				fired_recovery_pack_complete_event_ids[recovery_event_id] = true
			if recovery_kind == "recharge":
				effect_layer.delayed_effect(
					0.08 if pack_was_launched else RECOVERY_PACK_FLIGHT_DURATION,
					Callable(self, "play_recharge_pack_complete"),
					[event_summary],
					"recharge_pack_complete_delay"
				)
			else:
				effect_layer.delayed_effect(
					0.08 if pack_was_launched else RECOVERY_PACK_FLIGHT_DURATION,
					Callable(effect_recipes, "play_recovery_pack_complete"),
					[effect_layer, event_summary],
					"recovery_pack_complete_delay"
				)

		if is_explosive_load_todo_event(event_summary):
			ensure_effect_layer()
			play_explosive_loaded_complete(event_summary)

		if is_explosive_execute_todo_event(event_summary):
			ensure_effect_layer()
			var explosive_event_id := str(event_summary.get("event_id", "")).strip_edges()
			if explosive_event_id != "" and fired_explosive_complete_event_ids.has(explosive_event_id):
				continue
			if explosive_event_id != "" and not fired_explosive_pre_finish_event_ids.has(explosive_event_id):
				fired_explosive_pre_finish_event_ids[explosive_event_id] = true
				play_explosive_pre_finish(event_summary)
			if explosive_event_id != "":
				fired_explosive_complete_event_ids[explosive_event_id] = true
			effect_layer.delayed_effect(
				0.08,
				Callable(self, "play_explosive_complete"),
				[event_summary],
				"explosive_complete_delay"
			)


func on_header_state(packet: Dictionary) -> void:
	latest_header_state_packet = packet
	sync_shield_ring_groups(packet)


func on_semantic_event(packet: Dictionary) -> void:
	latest_semantic_event_packet = packet
	semantic_event_history.append(packet)
	trim_array_to_limit(semantic_event_history, HISTORY_LIMIT)
	play_semantic_event_hint(packet)


func on_drone_runtime(packet: Dictionary) -> void:
	latest_drone_runtime_packet = packet
	ensure_effect_layer()

	var drones := get_dictionary_array(packet, "drones")
	var drone_by_runtime_id: Dictionary = {}
	for drone in drones:
		if typeof(drone) != TYPE_DICTIONARY:
			continue
		if not is_auto_attack_drone_summary(drone):
			continue
		var runtime_id := str(drone.get("runtime_id", "")).strip_edges()
		if runtime_id == "":
			continue
		drone_by_runtime_id[runtime_id] = drone
		if not known_auto_attack_drone_runtime_ids.has(runtime_id):
			known_auto_attack_drone_runtime_ids[runtime_id] = true
			effect_recipes.play_auto_attack_drone_spawn(effect_layer, drone)

	effect_recipes.play_auto_attack_drone_runtime(effect_layer, packet)

	var attacks := get_dictionary_array(packet, "attacks")
	for i in range(attacks.size()):
		var attack = attacks[i]
		if typeof(attack) != TYPE_DICTIONARY:
			continue
		var runtime_id := str(attack.get("runtime_id", "")).strip_edges()
		if runtime_id == "":
			continue
		var attack_key := str(attack.get("ui_attack_key", str(packet.get("drone_ui_update_index", "")) + ":" + runtime_id + ":" + str(i)))
		if fired_auto_attack_drone_attack_keys.has(attack_key):
			continue
		fired_auto_attack_drone_attack_keys[attack_key] = true
		var drone_summary := get_auto_drone_summary_for_runtime(runtime_id, drone_by_runtime_id, attack)
		effect_recipes.play_auto_attack_drone_fire(effect_layer, attack, drone_summary)

	play_auto_drone_end_batch(get_dictionary_array(packet, "expired"), "expired")
	play_auto_drone_end_batch(get_dictionary_array(packet, "destroyed"), "destroyed")


func play_auto_drone_end_batch(drone_batch: Array, status: String) -> void:
	for drone in drone_batch:
		if typeof(drone) != TYPE_DICTIONARY:
			continue
		var runtime_id := str(drone.get("runtime_id", "")).strip_edges()
		if runtime_id == "":
			continue
		effect_recipes.play_auto_attack_drone_end(effect_layer, drone, status)
		known_auto_attack_drone_runtime_ids.erase(runtime_id)


func get_dictionary_array(packet: Dictionary, key: String) -> Array:
	var results: Array = []
	if typeof(packet.get(key, [])) != TYPE_ARRAY:
		return results
	for entry in packet.get(key, []):
		if typeof(entry) == TYPE_DICTIONARY:
			results.append(entry)
	return results


func get_auto_drone_summary_for_runtime(runtime_id: String, drone_by_runtime_id: Dictionary, attack_summary: Dictionary) -> Dictionary:
	if drone_by_runtime_id.has(runtime_id):
		return drone_by_runtime_id[runtime_id]

	var fallback := {
		"runtime_id": runtime_id,
		"owner_side": str(attack_summary.get("owner_side", "player")),
		"target_side": str(attack_summary.get("target_side", "enemy")),
		"drone_type": "auto_attack",
		"damage_value": float(attack_summary.get("damage_value", 0.0)),
		"max_shots": int(attack_summary.get("shot_total", 0)),
		"shots_fired": int(attack_summary.get("shot_index", 0)),
		"shots_remaining": int(attack_summary.get("shots_remaining", 0)),
		"labels": ["active_drone_runtime_active"]
	}
	return fallback


func is_auto_attack_drone_summary(drone_summary: Dictionary) -> bool:
	var drone_type := str(drone_summary.get("drone_type", "")).strip_edges().to_lower()
	if drone_type == "auto_attack":
		return true
	if bool(drone_summary.get("auto_attack", false)):
		return true
	var labels_text := str(drone_summary.get("labels", [])).to_lower()
	return labels_text.find("active_drone") >= 0 or labels_text.find("auto_attack") >= 0


func play_semantic_event_hint(packet: Dictionary) -> void:
	var point_id := str(packet.get("position_hint", packet.get("point_id", ""))).strip_edges()
	if point_id == "":
		return

	var marker_text := get_semantic_marker_text(packet)
	if marker_text.find("ui_flash") < 0 and marker_text.find("ui_pulse") < 0 and marker_text.find("ui_float_text") < 0:
		return

	ensure_effect_layer()
	var color := get_semantic_event_color(packet)
	if marker_text.find("ui_flash") >= 0:
		effect_layer.flash_box(
			point_id,
			color,
			float(packet.get("duration", packet.get("duration_sec", 0.35))),
			float(packet.get("thickness", 4.0)),
			float(packet.get("pulse_speed", 18.0)),
			float(packet.get("padding", 4.0)),
			str(packet.get("effect_kind", "battle_v2_semantic_flash"))
		)

	if marker_text.find("ui_pulse") >= 0:
		effect_layer.ring_pulse_around_box(
			point_id,
			color,
			float(packet.get("duration", packet.get("duration_sec", 0.75))),
			int(packet.get("ring_count", 2)),
			float(packet.get("max_expand", 28.0)),
			float(packet.get("thickness", 4.0)),
			float(packet.get("pulse_gap_sec", 0.12)),
			float(packet.get("padding", 4.0)),
			str(packet.get("effect_kind", "battle_v2_semantic_pulse"))
		)

	if marker_text.find("ui_float_text") >= 0:
		var text := str(packet.get("float_text", packet.get("event_text", packet.get("event_name", "")))).strip_edges()
		if text != "":
			effect_layer.float_text_at_point(
				point_id,
				text,
				color,
				float(packet.get("duration", packet.get("duration_sec", 0.9))),
				ui_helpers.get_packet_vector2(packet, "drift_xy", Vector2(0, -34)),
				int(packet.get("font_size", 22)),
				str(packet.get("effect_kind", "battle_v2_semantic_float_text"))
			)


func get_semantic_marker_text(packet: Dictionary) -> String:
	return (
		str(packet.get("visual_hint", ""))
		+ " "
		+ str(packet.get("event_family", ""))
		+ " "
		+ str(packet.get("event_name", ""))
		+ " "
		+ str(packet.get("tags", []))
		+ " "
		+ str(packet.get("labels", []))
	).to_lower()


func get_semantic_event_color(packet: Dictionary) -> Color:
	var marker_text := get_semantic_marker_text(packet)
	if marker_text.find("enemy") >= 0:
		return COLOR_ENEMY_ENERGY
	if marker_text.find("shield") >= 0:
		return COLOR_SHIELD
	if marker_text.find("recharge") >= 0 or marker_text.find("energy_restore") >= 0 or marker_text.find("capacitor") >= 0:
		return COLOR_RECHARGE_BLUE
	if marker_text.find("repair") >= 0:
		return COLOR_REPAIR
	if marker_text.find("explosive") >= 0:
		return COLOR_EXPLOSIVE
	if marker_text.find("hull") >= 0 or marker_text.find("hit") >= 0 or marker_text.find("damage") >= 0:
		return COLOR_KINETIC
	return COLOR_PLAYER_ENERGY


func on_unmatched_ui_event(_packet: Dictionary) -> void:
	pass


func is_player_pulse_laser_action_start(packet: Dictionary) -> bool:
	return (
		str(packet.get("item_id", "")).strip_edges() == "pulse_laser_mk1"
		and str(packet.get("event_type", "")).strip_edges() == "fire_primary_weapon"
		and str(packet.get("click_status", "")).strip_edges() == "queued"
	)


func is_player_pulse_laser_event(event_summary: Dictionary) -> bool:
	return (
		str(event_summary.get("item_id", "")).strip_edges() == "pulse_laser_mk1"
		and str(event_summary.get("event_type", "")).strip_edges() == "fire_primary_weapon"
	)


func is_player_secondary_weapon_action_start(packet: Dictionary) -> bool:
	return (
		str(packet.get("action_id", "")).strip_edges() == "fire_secondary_weapon"
		and str(packet.get("click_status", "")).strip_edges() == "queued"
	)


func is_secondary_weapon_event(event_summary: Dictionary) -> bool:
	var event_type := str(event_summary.get("event_type", "")).strip_edges().to_lower()
	var event_group := str(event_summary.get("event_group", "")).strip_edges().to_lower()
	var weapon_slot := str(event_summary.get("weapon_slot", "")).strip_edges().to_lower()
	var labels_text := str(event_summary.get("labels", [])).to_lower()
	var tags_text := str(event_summary.get("tags", [])).to_lower()

	if event_type == "fire_secondary_weapon" or event_type == "enemy_secondary_attack" or event_type == "enemy_attack_secondary":
		return true
	if weapon_slot == "secondary":
		return true
	if event_group == "weapon" and event_type.find("secondary") != -1:
		return true
	if labels_text.find("secondary_weapon") != -1 or tags_text.find("secondary_weapon") != -1:
		return true
	return false


func is_recovery_consumable_event(event_summary: Dictionary) -> bool:
	return is_recovery_execute_todo_event(event_summary) and get_recovery_consumable_kind(event_summary) != ""


func is_recovery_execute_action_click(packet: Dictionary) -> bool:
	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	if action_id != "execute_consumable":
		return false
	return is_queued_action_click(packet)


func is_recovery_execute_todo_event(event_summary: Dictionary) -> bool:
	var event_type := str(event_summary.get("event_type", "")).strip_edges().to_lower()
	var event_group := str(event_summary.get("event_group", "")).strip_edges().to_lower()
	var action_id := str(event_summary.get("action_id", "")).strip_edges().to_lower()
	var subtype := str(event_summary.get("subtype", event_summary.get("event_subtype", ""))).strip_edges().to_lower()
	var state := str(event_summary.get("state", event_summary.get("status", ""))).strip_edges().to_lower()

	# Loaded/filled consumable packets can carry the full repair/recharge item dictionary.
	# Those packets are state/UI refreshes only; they must not launch procedural recovery effects.
	if bool(event_summary.get("is_state_change", false)):
		return false
	if action_id == "load_consumable":
		return false
	if event_type == "load_consumable" or event_type == "load_consumable_complete":
		return false
	if subtype == "load_consumable" or subtype == "load_consumable_complete":
		return false
	if state == "loaded" or state == "ready" or state == "filled":
		return false

	if action_id == "execute_consumable":
		return true
	if event_type == "execute_repair" or event_type == "execute_recharge" or event_type == "execute_shield_repair":
		return true
	if event_type == "execute_consumable":
		return true

	# BattleManager result/TODO summaries often preserve the semantic event_group
	# instead of the original action id. These are safe only after load-state guards above.
	if event_group == "repair" or event_group == "recharge" or event_group == "shield_repair":
		return true

	return false


func get_recovery_consumable_kind(packet: Dictionary) -> String:
	var event_type := str(packet.get("event_type", "")).strip_edges().to_lower()
	var event_group := str(packet.get("event_group", "")).strip_edges().to_lower()
	var consumable_group := str(packet.get("consumable_group", "")).strip_edges().to_lower()
	var item_id := str(packet.get("item_id", "")).strip_edges().to_lower()
	var subtype := str(packet.get("subtype", "")).strip_edges().to_lower()
	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	var labels_text := str(packet.get("labels", [])).to_lower()
	var tags_text := str(packet.get("tags", [])).to_lower()
	var button_text := str(packet.get("button_text", packet.get("text", packet.get("display_name", packet.get("name", ""))))).strip_edges().to_lower()
	var data_payload := get_nested_dictionary(packet, "data")
	var item_data := get_nested_dictionary(packet, "item_data")
	if item_data.is_empty() and not data_payload.is_empty():
		item_data = get_nested_dictionary(data_payload, "item_data")
	var packet_result := get_nested_dictionary(packet, "packet_result")
	var event_packet := get_nested_dictionary(packet_result, "event_packet")
	var event_result := get_nested_dictionary(packet, "event_result")

	var combined := (
		event_type + " " +
		event_group + " " +
		consumable_group + " " +
		item_id + " " +
		subtype + " " +
		action_id + " " +
		button_text + " " +
		labels_text + " " +
		tags_text + " " +
		str(data_payload).to_lower() + " " +
		str(item_data).to_lower() + " " +
		str(packet_result).to_lower() + " " +
		str(event_packet).to_lower() + " " +
		str(event_result).to_lower() + " " +
		str(packet).to_lower()
	)

	if event_type == "execute_shield_repair" or event_group == "shield_repair" or consumable_group == "shield_repair":
		return "shield_repair"
	if combined.find("shield_repair") != -1 or combined.find("repair_shield") != -1:
		return "shield_repair"

	if event_type == "execute_recharge" or event_group == "recharge" or consumable_group == "recharge":
		return "recharge"
	if combined.find("consumable_group_recharge") != -1 or combined.find("energy_restore") != -1 or combined.find("recharge") != -1 or combined.find("capacitor") != -1:
		return "recharge"

	if event_type == "execute_repair" or event_group == "repair" or consumable_group == "repair":
		return "repair"
	if combined.find("consumable_group_repair") != -1 or combined.find("repair_hull") != -1 or combined.find("repair") != -1:
		return "repair"

	return ""


func is_explosive_load_action_click(packet: Dictionary) -> bool:
	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	return action_id == "load_consumable" and is_queued_action_click(packet) and is_explosive_consumable_packet(packet)


func is_explosive_execute_action_click(packet: Dictionary) -> bool:
	var action_id := str(packet.get("action_id", "")).strip_edges().to_lower()
	return action_id == "execute_consumable" and is_queued_action_click(packet) and is_explosive_consumable_packet(packet)


func is_explosive_load_todo_event(event_summary: Dictionary) -> bool:
	var event_type := str(event_summary.get("event_type", "")).strip_edges().to_lower()
	if event_type != "load_consumable" and event_type != "enemy_load_consumable":
		return false
	return is_explosive_consumable_packet(event_summary)


func is_explosive_execute_todo_event(event_summary: Dictionary) -> bool:
	var event_type := str(event_summary.get("event_type", "")).strip_edges().to_lower()
	var event_group := str(event_summary.get("event_group", "")).strip_edges().to_lower()
	var action_id := str(event_summary.get("action_id", "")).strip_edges().to_lower()
	if event_type == "load_consumable" or event_type == "enemy_load_consumable" or action_id == "load_consumable":
		return false
	if event_type == "execute_explosive" or event_group == "explosive":
		return true
	if action_id == "execute_consumable" or event_type == "execute_consumable":
		return is_explosive_consumable_packet(event_summary)
	return false


func is_explosive_consumable_packet(packet: Dictionary) -> bool:
	var data_payload := get_nested_dictionary(packet, "data")
	var item_data := get_nested_dictionary(packet, "item_data")
	if item_data.is_empty() and not data_payload.is_empty():
		item_data = get_nested_dictionary(data_payload, "item_data")
	var packet_result := get_nested_dictionary(packet, "packet_result")
	var event_packet := get_nested_dictionary(packet_result, "event_packet")
	var event_result := get_nested_dictionary(packet, "event_result")

	var consumable_group := str(packet.get("consumable_group", data_payload.get("consumable_group", item_data.get("consumable_group", item_data.get("group", ""))))).strip_edges().to_lower()
	var event_group := str(packet.get("event_group", event_packet.get("event_group", ""))).strip_edges().to_lower()
	var damage_type := str(packet.get("damage_type", data_payload.get("damage_type", event_packet.get("damage_type", item_data.get("damage_type", ""))))).strip_edges().to_lower()
	if consumable_group == "explosive" or event_group == "explosive" or damage_type == "explosive":
		return true

	var combined := (
		str(packet.get("event_type", "")) + " " +
		str(packet.get("action_id", "")) + " " +
		str(packet.get("item_id", "")) + " " +
		str(packet.get("item_name", "")) + " " +
		str(packet.get("row_text", "")) + " " +
		str(packet.get("display_text", "")) + " " +
		str(packet.get("labels", [])) + " " +
		str(packet.get("tags", [])) + " " +
		str(data_payload) + " " +
		str(item_data) + " " +
		str(event_packet) + " " +
		str(event_result)
	).to_lower()
	return combined.find("consumable_group_explosive") >= 0 or combined.find("explosive_pass_damage") >= 0 or combined.find("execute_explosive") >= 0


func get_explosive_packet_damage(packet: Dictionary) -> float:
	var data_payload := get_nested_dictionary(packet, "data")
	var item_data := get_nested_dictionary(packet, "item_data")
	if item_data.is_empty() and not data_payload.is_empty():
		item_data = get_nested_dictionary(data_payload, "item_data")
	var resolution_result := get_nested_dictionary(packet, "resolution_result")
	var damage_result := get_nested_dictionary(resolution_result, "damage_result")
	var total_result_damage := float(damage_result.get("shield_damage", 0.0)) + float(damage_result.get("hull_damage", 0.0)) + float(damage_result.get("overflow_damage", 0.0))
	if total_result_damage > 0.0:
		return total_result_damage
	return get_first_float_from_dicts([packet, data_payload, item_data], ["explosive_damage", "damage_value", "damage"], 0.0)


func get_explosive_target_point(packet: Dictionary) -> String:
	var target_side := str(packet.get("target_side", "")).strip_edges().to_lower()
	if target_side == "player":
		return "player_damage_float"
	if target_side == "enemy":
		return "enemy_damage_float"
	var side_text := (
		str(packet.get("event_side", "")) + " " +
		str(packet.get("source_side", "")) + " " +
		str(packet.get("owner_side", ""))
	).strip_edges().to_lower()
	if side_text.find("enemy") != -1:
		return "player_damage_float"
	return "enemy_damage_float"


func get_explosive_float_text(packet: Dictionary) -> String:
	var damage_value := get_explosive_packet_damage(packet)
	if damage_value > 0.0:
		return "-" + str(int(round(damage_value))) + " BLAST"
	return "BLAST"


func play_explosive_load_action_click(packet: Dictionary) -> void:
	ensure_effect_layer()
	var duration_sec = clamp(float(packet.get("duration", 1.0)), 0.35, 2.5)
	effect_layer.flash_box(
		"consumable_action_button",
		Color(COLOR_EXPLOSIVE.r, COLOR_EXPLOSIVE.g, COLOR_EXPLOSIVE.b, 0.56),
		0.24,
		3.0,
		18.0,
		4.0,
		"explosive_load_charge_button_flash"
	)
	effect_layer.ring_pulse_around_box(
		"consumable_action_button",
		Color(COLOR_EXPLOSIVE_CORE.r, COLOR_EXPLOSIVE_CORE.g, COLOR_EXPLOSIVE_CORE.b, 0.58),
		0.46,
		2,
		16.0,
		2.6,
		0.08,
		3.0,
		"explosive_load_charge_button_ring"
	)
	effect_layer.particle_trail_between_points(
		"consumable_action_button",
		"todo_panel",
		COLOR_EXPLOSIVE_CORE,
		4.5,
		1050.0,
		7,
		0.22
	)
	effect_layer.set_breathing_energy_frame({
		"effect_match_id": "explosive_load_button_" + str(packet.get("event_id", packet.get("item_id", "charge"))),
		"point_id": "consumable_action_button",
		"duration_sec": duration_sec,
		"padding": 4.0,
		"thickness": 1.8,
		"glow_thickness": 8.0,
		"breath_speed": 2.4,
		"breath_amount": 0.020,
		"alpha_pulse_scale": 0.70,
		"particle_count": 3,
		"particle_speed": 0.65,
		"particle_size": 4.0,
		"base_color": Color(COLOR_EXPLOSIVE.r, COLOR_EXPLOSIVE.g, COLOR_EXPLOSIVE.b, 0.58),
		"state": "warning"
	})


func play_explosive_load_todo_ready(event_summary: Dictionary) -> void:
	ensure_effect_layer()
	var duration_sec = clamp(float(event_summary.get("duration", event_summary.get("time_remaining", 1.0))), 0.35, 2.6)
	effect_layer.flash_box(
		"todo_next_row",
		Color(COLOR_EXPLOSIVE.r, COLOR_EXPLOSIVE.g, COLOR_EXPLOSIVE.b, 0.42),
		0.28,
		3.0,
		16.0,
		4.0,
		"explosive_arming_todo_flash"
	)
	effect_layer.ring_pulse_around_box(
		"todo_next_row",
		Color(COLOR_EXPLOSIVE_CORE.r, COLOR_EXPLOSIVE_CORE.g, COLOR_EXPLOSIVE_CORE.b, 0.46),
		0.62,
		2,
		22.0,
		2.8,
		0.10,
		4.0,
		"explosive_arming_todo_ring"
	)
	effect_layer.spark_burst_around_box(
		"todo_next_row",
		Color(COLOR_EXPLOSIVE.r, COLOR_EXPLOSIVE.g, COLOR_EXPLOSIVE.b, 0.54),
		20,
		2.0,
		6.0,
		8.0,
		34.0,
		0.55,
		"explosive_arming_sparks"
	)
	effect_layer.set_breathing_energy_frame({
		"effect_match_id": "explosive_arming_todo_" + str(event_summary.get("event_id", "charge")),
		"point_id": "todo_next_row",
		"duration_sec": duration_sec,
		"padding": 5.0,
		"thickness": 1.6,
		"glow_thickness": 8.0,
		"breath_speed": 2.0,
		"breath_amount": 0.018,
		"alpha_pulse_scale": 0.62,
		"particle_count": 4,
		"particle_speed": 0.55,
		"particle_size": 3.5,
		"base_color": Color(COLOR_EXPLOSIVE.r, COLOR_EXPLOSIVE.g, COLOR_EXPLOSIVE.b, 0.50),
		"state": "warning"
	})


func play_explosive_loaded_complete(event_summary: Dictionary) -> void:
	ensure_effect_layer()
	effect_layer.flash_box(
		"consumable_action_button",
		Color(COLOR_EXPLOSIVE_CORE.r, COLOR_EXPLOSIVE_CORE.g, COLOR_EXPLOSIVE_CORE.b, 0.46),
		0.22,
		3.0,
		20.0,
		4.0,
		"explosive_charge_armed_button_flash"
	)
	effect_layer.ring_pulse_around_box(
		"consumable_action_button",
		Color(COLOR_EXPLOSIVE_CORE.r, COLOR_EXPLOSIVE_CORE.g, COLOR_EXPLOSIVE_CORE.b, 0.64),
		0.70,
		3,
		20.0,
		2.8,
		0.08,
		3.0,
		"explosive_charge_armed_button_ring"
	)
	effect_layer.float_text_at_point(
		"consumable_action_button",
		"ARMED",
		COLOR_EXPLOSIVE_CORE,
		0.82,
		Vector2(0, -30),
		17,
		"explosive_charge_armed_text"
	)


func play_explosive_execute_action_click(packet: Dictionary) -> void:
	ensure_effect_layer()
	var duration_sec = clamp(float(packet.get("duration", 1.0)), 0.35, 3.0)
	effect_layer.flash_box(
		"consumable_action_button",
		COLOR_EXPLOSIVE,
		0.28,
		4.0,
		24.0,
		4.0,
		"explosive_detonate_button_flash"
	)
	effect_layer.ring_pulse_around_box(
		"consumable_action_button",
		COLOR_EXPLOSIVE_CORE,
		0.50,
		3,
		22.0,
		3.2,
		0.065,
		4.0,
		"explosive_detonate_button_ring"
	)
	effect_layer.spark_burst_around_box(
		"consumable_action_button",
		COLOR_EXPLOSIVE,
		30,
		3.0,
		8.0,
		10.0,
		48.0,
		0.55,
		"explosive_detonate_button_sparks"
	)
	effect_layer.flash_line_between_points(
		"consumable_action_button",
		"todo_next_row",
		COLOR_EXPLOSIVE_CORE,
		3.2,
		0.20,
		"explosive_detonate_todo_snap"
	)
	effect_layer.set_breathing_energy_frame({
		"effect_match_id": "explosive_execute_button_" + str(packet.get("event_id", packet.get("item_id", "charge"))),
		"point_id": "consumable_action_button",
		"duration_sec": duration_sec,
		"padding": 5.0,
		"thickness": 2.0,
		"glow_thickness": 10.0,
		"breath_speed": 2.75,
		"breath_amount": 0.026,
		"alpha_pulse_scale": 0.82,
		"particle_count": 5,
		"particle_speed": 0.82,
		"particle_size": 4.5,
		"base_color": Color(COLOR_EXPLOSIVE.r, COLOR_EXPLOSIVE.g, COLOR_EXPLOSIVE.b, 0.68),
		"state": "warning"
	})


func play_explosive_todo_ready(event_summary: Dictionary) -> void:
	ensure_effect_layer()
	var duration_sec = clamp(float(event_summary.get("duration", event_summary.get("time_remaining", 1.0))), 0.35, 3.0)
	effect_layer.ring_pulse_around_box(
		"todo_next_row",
		Color(COLOR_EXPLOSIVE.r, COLOR_EXPLOSIVE.g, COLOR_EXPLOSIVE.b, 0.64),
		0.74,
		3,
		28.0,
		3.2,
		0.09,
		5.0,
		"explosive_todo_detonation_ring"
	)
	effect_layer.float_text_at_point(
		"todo_next_row",
		"DETONATE",
		COLOR_EXPLOSIVE_CORE,
		0.90,
		Vector2(0, -38),
		18,
		"explosive_todo_detonation_text"
	)
	effect_layer.set_breathing_energy_frame({
		"effect_match_id": "explosive_execute_todo_" + str(event_summary.get("event_id", "charge")),
		"point_id": "todo_next_row",
		"duration_sec": duration_sec,
		"padding": 6.0,
		"thickness": 2.0,
		"glow_thickness": 11.0,
		"breath_speed": 2.65,
		"breath_amount": 0.024,
		"alpha_pulse_scale": 0.72,
		"particle_count": 6,
		"particle_speed": 0.76,
		"particle_size": 4.0,
		"base_color": Color(COLOR_EXPLOSIVE.r, COLOR_EXPLOSIVE.g, COLOR_EXPLOSIVE.b, 0.62),
		"state": "warning"
	})


func play_explosive_pre_finish(event_summary: Dictionary) -> void:
	ensure_effect_layer()
	var target_point := get_explosive_target_point(event_summary)
	effect_layer.flash_line_between_points(
		"todo_next_row",
		target_point,
		COLOR_EXPLOSIVE_CORE,
		4.2,
		0.20,
		"explosive_pre_finish_target_line"
	)
	effect_layer.particle_trail_between_points(
		"todo_next_row",
		target_point,
		COLOR_EXPLOSIVE,
		7.5,
		1600.0,
		9,
		0.20
	)
	effect_layer.ring_pulse_around_box(
		target_point,
		Color(COLOR_EXPLOSIVE.r, COLOR_EXPLOSIVE.g, COLOR_EXPLOSIVE.b, 0.48),
		0.42,
		2,
		26.0,
		3.2,
		0.06,
		5.0,
		"explosive_pre_finish_target_ring"
	)


func play_explosive_complete(event_summary: Dictionary) -> void:
	ensure_effect_layer()
	var target_point := get_explosive_target_point(event_summary)
	var center := effect_layer.get_point_center(target_point)
	effect_layer.particle_explosion(
		center,
		COLOR_EXPLOSIVE,
		58,
		3.0,
		12.0,
		42.0,
		148.0,
		0.78,
		"explosive_final_particle_blast"
	)
	effect_layer.particle_explosion(
		center,
		COLOR_EXPLOSIVE_CORE,
		22,
		2.0,
		8.0,
		24.0,
		96.0,
		0.52,
		"explosive_final_core_pop"
	)
	effect_layer.ring_pulse_around_box(
		target_point,
		COLOR_EXPLOSIVE_CORE,
		0.82,
		4,
		46.0,
		3.8,
		0.075,
		8.0,
		"explosive_final_impact_rings"
	)
	effect_layer.spark_burst_around_box(
		target_point,
		Color(COLOR_EXPLOSIVE.r, COLOR_EXPLOSIVE.g, COLOR_EXPLOSIVE.b, 0.68),
		42,
		3.0,
		9.0,
		10.0,
		72.0,
		0.82,
		"explosive_final_impact_sparks"
	)
	effect_layer.float_text_at_point(
		target_point,
		get_explosive_float_text(event_summary),
		COLOR_EXPLOSIVE_CORE,
		1.05,
		Vector2(0, -46),
		23,
		"explosive_final_damage_text"
	)


func get_nested_dictionary(packet: Dictionary, key: String) -> Dictionary:
	var value = packet.get(key, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func is_queued_action_click(packet: Dictionary) -> bool:
	var click_status := str(packet.get("click_status", "")).strip_edges().to_lower()
	var status := str(packet.get("status", "")).strip_edges().to_lower()
	if click_status == "queued" or click_status == "accepted" or click_status == "success":
		return true
	return status == "queued" or status == "accepted" or status == "success"


func play_recharge_action_click(packet: Dictionary) -> void:
	ensure_effect_layer()
	effect_layer.spark_burst_around_box(
		"consumable_action_button",
		COLOR_RECHARGE_BLUE,
		46,
		4.0,
		11.0,
		10.0,
		64.0,
		0.58,
		"recharge_click_blue_capacitor_burst"
	)
	effect_layer.ring_pulse_around_box(
		"consumable_action_button",
		COLOR_RECHARGE_CORE,
		0.52,
		3,
		22.0,
		3.0,
		0.07,
		3.0,
		"recharge_click_capacitor_ring"
	)
	effect_layer.flash_line_between_points(
		"consumable_action_button",
		"todo_next_row",
		COLOR_RECHARGE_ARC,
		2.5,
		0.18,
		"recharge_click_todo_snap"
	)


func play_recharge_todo_ready(event_summary: Dictionary) -> void:
	ensure_effect_layer()
	effect_layer.ring_pulse_around_box(
		"todo_next_row",
		COLOR_RECHARGE_BLUE,
		0.82,
		3,
		28.0,
		3.0,
		0.10,
		2.0,
		"recharge_todo_blue_pulse"
	)
	effect_layer.spark_burst_around_box(
		"todo_next_row",
		COLOR_RECHARGE_CORE,
		28,
		3.0,
		8.0,
		6.0,
		36.0,
		0.70,
		"recharge_todo_capacitor_sparks"
	)
	effect_layer.flash_line_between_points(
		"consumable_action_button",
		"todo_next_row",
		COLOR_RECHARGE_ARC,
		2.5,
		0.22,
		"recharge_todo_feed_line"
	)
	effect_layer.delayed_effect(
		0.10,
		Callable(effect_layer, "flash_line_between_points"),
		["todo_next_row", get_recovery_target_point(event_summary), COLOR_RECHARGE_ARC, 2.0, 0.18, "recharge_todo_unit_return_arc"],
		"recharge_todo_delayed_return_arc"
	)


func play_recharge_pack_launch(event_summary: Dictionary) -> void:
	ensure_effect_layer()
	var target_point := get_recovery_target_point(event_summary)
	effect_layer.launch_square_pack_between_points(
		"consumable_action_button",
		target_point,
		COLOR_RECHARGE_BLUE,
		COLOR_RECHARGE_CORE,
		RECOVERY_PACK_FLIGHT_DURATION,
		26.0,
		42.0,
		"recharge_capacitor_pack_flight"
	)
	effect_layer.flash_line_between_points(
		"todo_next_row",
		target_point,
		COLOR_RECHARGE_ARC,
		3.0,
		0.20,
		"recharge_capacitor_arc_to_unit"
	)


func play_recharge_pack_complete(event_summary: Dictionary) -> void:
	ensure_effect_layer()
	var target_point := get_recovery_target_point(event_summary)
	var complete_text := get_recharge_complete_text(event_summary)
	effect_layer.launch_square_pack_between_points(
		target_point,
		target_point,
		COLOR_RECHARGE_BLUE,
		COLOR_RECHARGE_CORE,
		0.24,
		36.0,
		0.0,
		"recharge_blue_cross_complete"
	)
	effect_layer.ring_pulse_around_box(
		target_point,
		COLOR_RECHARGE_CORE,
		0.68,
		3,
		36.0,
		3.5,
		0.06,
		4.0,
		"recharge_complete_cross_ring"
	)
	effect_layer.spark_burst_around_box(
		target_point,
		COLOR_RECHARGE_BLUE,
		42,
		3.0,
		9.0,
		8.0,
		48.0,
		0.72,
		"recharge_complete_capacitor_burst"
	)
	effect_layer.particle_explosion(
		effect_layer.get_point_center(target_point),
		COLOR_RECHARGE_CORE,
		30,
		2.0,
		7.0,
		34.0,
		110.0,
		0.62,
		"recharge_complete_particle_pop"
	)
	effect_layer.float_text_at_point(
		target_point,
		complete_text,
		COLOR_RECHARGE_CORE,
		1.05,
		Vector2(0, -42),
		22,
		"recharge_complete_energy_text"
	)


func get_recovery_target_point(event_summary: Dictionary) -> String:
	var side_text := (
		str(event_summary.get("event_side", "")) + " " +
		str(event_summary.get("source_side", "")) + " " +
		str(event_summary.get("owner_side", "")) + " " +
		str(event_summary.get("target_side", ""))
	).strip_edges().to_lower()
	if side_text.find("enemy") != -1:
		return "enemy_damage_float"
	return "player_damage_float"


func get_recharge_complete_text(event_summary: Dictionary) -> String:
	var data_payload := get_nested_dictionary(event_summary, "data")
	var item_data := get_nested_dictionary(event_summary, "item_data")
	if item_data.is_empty() and not data_payload.is_empty():
		item_data = get_nested_dictionary(data_payload, "item_data")
	var sources := [event_summary, data_payload, item_data]
	if get_first_bool_from_dicts(sources, ["recharge_to_full", "fill_to_max", "energy_to_full"], false):
		return "FULL CHARGE"
	var restore_amount := get_first_float_from_dicts(sources, ["energy_restore_amount", "recharge_amount", "energy_amount"], 0.0)
	if restore_amount > 0.0:
		return "+" + str(int(round(restore_amount))) + " ENERGY"
	return "ENERGY RESTORED"


func get_first_float_from_dicts(sources: Array, keys: Array, fallback: float = 0.0) -> float:
	for source in sources:
		if typeof(source) != TYPE_DICTIONARY:
			continue
		for key in keys:
			if source.has(key):
				return max(float(source.get(key, fallback)), 0.0)
	return max(float(fallback), 0.0)


func get_first_bool_from_dicts(sources: Array, keys: Array, fallback: bool = false) -> bool:
	for source in sources:
		if typeof(source) != TYPE_DICTIONARY:
			continue
		for key in keys:
			if source.has(key):
				var value = source.get(key)
				if typeof(value) == TYPE_BOOL:
					return value
				var value_text := str(value).strip_edges().to_lower()
				return value_text == "true" or value_text == "1" or value_text == "yes"
	return fallback


func is_enemy_primary_attack_event(event_summary: Dictionary) -> bool:
	var event_side := str(event_summary.get("event_side", "")).strip_edges().to_lower()
	var event_type := str(event_summary.get("event_type", "")).strip_edges().to_lower()
	var event_group := str(event_summary.get("event_group", "")).strip_edges().to_lower()
	var labels_text := str(event_summary.get("labels", [])).to_lower()
	var tags_text := str(event_summary.get("tags", [])).to_lower()

	if event_side != "enemy":
		return false
	if event_type == "enemy_primary_attack" or event_type == "enemy_attack_primary":
		return true
	if event_type.find("primary") != -1 and event_type.find("secondary") == -1:
		return true
	if event_group.find("primary") != -1 and event_group.find("secondary") == -1:
		return true
	if labels_text.find("enemy_primary") != -1 or tags_text.find("enemy_primary") != -1:
		return true
	return false


func get_position_data() -> Dictionary:
	return decoration_points.duplicate(true)


func get_decoration_point(point_id: String) -> Dictionary:
	if not decoration_points.has(point_id):
		return {}
	return decoration_points[point_id].duplicate(true)


func get_current_header_state() -> Dictionary:
	return {
		"battle_id": battle_id,
		"player_hp_box": get_decoration_point("player_hp_box"),
		"enemy_hp_box": get_decoration_point("enemy_hp_box"),
		"player_hp_text": get_label_text("player_hull"),
		"enemy_hp_text": get_label_text("enemy_hull"),
		"player_shield_text": get_label_text("player_shield"),
		"enemy_shield_text": get_label_text("enemy_shield"),
		"player_energy_text": get_label_text("player_energy"),
		"enemy_energy_text": get_label_text("enemy_energy"),
		"player_ammo_text": get_label_text("player_ammo"),
		"enemy_intent_text": get_label_text("enemy_intent"),
		"player_shield_power_level": 0,
		"enemy_shield_power_level": 0,
		"player_shield_has_energy": true,
		"enemy_shield_has_energy": true
	}


func sync_shield_ring_groups(packet: Dictionary) -> void:
	ensure_effect_layer()
	if effect_layer == null or not effect_layer.has_method("set_shield_ring_group"):
		return

	effect_layer.set_shield_ring_group(
		build_shield_ring_group_packet(
			"player_shield_rings",
			"shield_panel",
			int(packet.get("player_shield_power_level", 0)),
			int(packet.get("player_shield_max_count", 4)),
			PLAYER_SHIELD_RING_COLOR,
			bool(packet.get("player_shield_has_energy", true)),
			str(packet.get("player_shield_state", "active"))
		)
	)

	effect_layer.set_shield_ring_group(
		build_shield_ring_group_packet(
			"enemy_shield_rings",
			"enemy_panel",
			int(packet.get("enemy_shield_power_level", 0)),
			int(packet.get("enemy_shield_max_count", 4)),
			ENEMY_SHIELD_RING_COLOR,
			bool(packet.get("enemy_shield_has_energy", true)),
			str(packet.get("enemy_shield_state", "active"))
		)
	)


func show_all_battle_hud_energy_frames() -> void:
	battle_hud_energy_frames_enabled = true
	battle_hud_energy_frame_refresh_timer = 0.0
	refresh_all_battle_hud_energy_frames()


func refresh_all_battle_hud_energy_frames() -> void:
	ensure_effect_layer()
	if effect_layer == null or not effect_layer.has_method("set_breathing_energy_frame"):
		return

	for point_id in BATTLE_HUD_FRAME_POINTS:
		refresh_breathing_energy_frame_for_point(str(point_id))


func refresh_breathing_energy_frame_for_point(point_id: String) -> Dictionary:
	var clean_point_id := point_id.strip_edges()
	if clean_point_id == "":
		return {}
	if get_decoration_point(clean_point_id).is_empty():
		return {}

	ensure_effect_layer()
	if effect_layer == null or not effect_layer.has_method("set_breathing_energy_frame"):
		return {}

	return effect_layer.set_breathing_energy_frame(
		build_battle_energy_frame_packet(clean_point_id)
	)


func build_battle_energy_frame_packet(point_id: String) -> Dictionary:
	var packet := {
		"effect_match_id": point_id + "_battle_hud_energy_frame",
		"point_id": point_id,
		"duration_sec": -1.0,
		"padding": 5.0,
		"thickness": 1.4,
		"glow_thickness": 8.0,
		"breath_speed": 1.05,
		"breath_amount": 0.010,
		"alpha_pulse_scale": 0.55,
		"particle_count": 2,
		"particle_speed": 0.20,
		"particle_size": 4.0,
		"base_color": COLOR_PLAYER_ENERGY,
		"state": "active"
	}
	apply_battle_hud_frame_style(packet, point_id)
	return packet


func apply_battle_hud_frame_style(packet: Dictionary, point_id: String) -> void:
	match point_id:
		"enemy_panel":
			packet["base_color"] = Color(1.0, 0.16, 0.10, 0.64)
			packet["breath_speed"] = 1.22
			packet["particle_speed"] = 0.26
		"battle_v3_pipeline":
			packet["base_color"] = Color(0.82, 0.30, 1.0, 0.58)
			packet["padding"] = 7.0
			packet["thickness"] = 1.7
			packet["glow_thickness"] = 11.0
			packet["breath_speed"] = 1.34
			packet["particle_count"] = 4
		"shield_panel":
			packet["base_color"] = Color(0.10, 0.90, 1.0, 0.62)
			packet["breath_speed"] = 1.42
			packet["particle_count"] = 3
		"action_panel":
			packet["base_color"] = Color(0.36, 0.72, 1.0, 0.52)
			packet["breath_speed"] = 1.16
			packet["particle_count"] = 3
		"battle_v3_reference_panel":
			packet["base_color"] = Color(0.45, 0.82, 1.0, 0.38)
			packet["breath_speed"] = 0.86
			packet["alpha_pulse_scale"] = 0.38
			packet["particle_count"] = 1
		"battle_log":
			packet["base_color"] = Color(0.30, 0.58, 1.0, 0.36)
			packet["breath_speed"] = 0.76
			packet["alpha_pulse_scale"] = 0.34
			packet["particle_count"] = 1
		_:
			packet["base_color"] = Color(0.16, 0.64, 1.0, 0.48)


func clear_all_battle_hud_energy_frames() -> void:
	battle_hud_energy_frames_enabled = false
	if effect_layer == null or not effect_layer.has_method("clear_breathing_energy_frame_by_id"):
		return

	for point_id in BATTLE_HUD_FRAME_POINTS:
		effect_layer.clear_breathing_energy_frame_by_id(str(point_id) + "_battle_hud_energy_frame")


func build_shield_ring_group_packet(
	match_id: String,
	point_id: String,
	active_count: int,
	max_count: int,
	base_color: Color,
	has_energy: bool,
	state: String
) -> Dictionary:
	var safe_state := state.strip_edges().to_lower()
	if safe_state == "":
		safe_state = "active"
	if not has_energy and safe_state == "active":
		safe_state = "no_energy"

	return {
		"match_id": match_id,
		"point_id": point_id,
		"active_count": active_count,
		"max_count": max_count,
		"base_color": base_color,
		"has_energy": has_energy,
		"state": safe_state
	}


func get_label_text(label_key: String) -> String:
	return ui_helpers.get_label_text(label_refs, label_key)


func get_latest(match_id: String) -> Dictionary:
	if not latest_by_match_id.has(match_id):
		return {}
	return latest_by_match_id[match_id].duplicate(true)


func get_history_for_match(match_id: String) -> Array:
	var results: Array = []
	for packet in event_history:
		if typeof(packet) != TYPE_DICTIONARY:
			continue
		if str(packet.get("match_id", "")) == match_id:
			results.append(packet.duplicate(true))
	return results


func push_action_button_clicked(action_id: String, item_id: String, button_text: String, extra_data: Dictionary = {}) -> Dictionary:
	var packet := extra_data.duplicate(true)
	packet["action_id"] = action_id
	packet["item_id"] = item_id
	packet["button_text"] = button_text
	packet["labels"] = packet.get("labels", [])
	packet["tags"] = packet.get("tags", [])

	if not packet["labels"].has("battle_ui_action_clicked"):
		packet["labels"].append("battle_ui_action_clicked")
	if not packet["tags"].has("ui"):
		packet["tags"].append("ui")
	if not packet["tags"].has("battle_v2"):
		packet["tags"].append("battle_v2")
	if not packet["tags"].has("action_button"):
		packet["tags"].append("action_button")

	return receive_ui_event(MATCH_ACTION_BUTTON_CLICKED, packet)


func push_semantic_event(event_family: String, point_id: String = "", extra_data: Dictionary = {}) -> Dictionary:
	# Summary: Easy entry point for future battle UI decorations driven by semantic tags.
	var packet := extra_data.duplicate(true)
	packet["event_family"] = event_family.strip_edges()
	if point_id.strip_edges() != "":
		packet["position_hint"] = point_id.strip_edges()

	var tags: Array = []
	if typeof(packet.get("tags", [])) == TYPE_ARRAY:
		tags = packet.get("tags", []).duplicate(true)
	var labels: Array = []
	if typeof(packet.get("labels", [])) == TYPE_ARRAY:
		labels = packet.get("labels", []).duplicate(true)

	ui_helpers.append_unique_string(tags, "battle_v2_semantic_event")
	ui_helpers.append_unique_string(tags, str(packet.get("event_family", "")))
	ui_helpers.append_unique_string(labels, "battle_v2_ui_semantic_packet")
	packet["tags"] = tags
	packet["labels"] = labels
	return receive_ui_event(MATCH_SEMANTIC_EVENT, packet)


func clear_ui_event_history() -> void:
	event_history.clear()
	action_click_history.clear()
	todo_active_history.clear()
	todo_completed_history.clear()
	semantic_event_history.clear()
	latest_by_match_id.clear()
	latest_action_click_packet.clear()
	latest_todo_active_packet.clear()
	latest_todo_completed_packet.clear()
	latest_drone_runtime_packet.clear()
	latest_semantic_event_packet.clear()
	fired_pre_finish_line_event_ids.clear()
	fired_enemy_primary_charge_event_ids.clear()
	fired_enemy_primary_pre_finish_line_event_ids.clear()
	fired_secondary_weapon_load_event_ids.clear()
	fired_secondary_weapon_pre_finish_event_ids.clear()
	fired_recovery_pack_ready_event_ids.clear()
	fired_recovery_pack_launch_event_ids.clear()
	fired_recovery_pack_complete_event_ids.clear()
	fired_explosive_load_event_ids.clear()
	fired_explosive_ready_event_ids.clear()
	fired_explosive_pre_finish_event_ids.clear()
	fired_explosive_complete_event_ids.clear()
	known_auto_attack_drone_runtime_ids.clear()
	fired_auto_attack_drone_attack_keys.clear()
	if effect_layer != null:
		effect_layer.clear_all_effects()


func trim_array_to_limit(target: Array, limit: int) -> void:
	ui_helpers.trim_array_to_limit(target, limit)


func play_primary_energy_zip_fx(
	from_pos: Vector2,
	to_pos: Vector2,
	total_laser_time: float = 0.28
) -> void:
	var fx := BattleV2EnergyZipFX.new()
	fx.name = "PrimaryEnergyZipFX"

	add_child(fx)

	# It waits until the final part of the laser draw, then zips fast.
	fx.play_zip(
		from_pos,
		to_pos,
		total_laser_time,
		0.10
	)
	
	
#func zip_particle_between_points(
	#from_point_id: String,
	#to_point_id: String,
	#color: Color,
	#total_window_duration: float,
	#zip_duration: float = 0.09,
	#effect_id: String = "zip_particle"
#) -> void:
	#var from_pos := _get_effect_point(from_point_id)
	#var to_pos := _get_effect_point(to_point_id)
#
	#var safe_zip_duration := max(zip_duration, 0.03)
	#var delay_before_zip := max(total_window_duration - safe_zip_duration, 0.0)
#
	#var packet := {
		#"kind": "zip_particle",
		#"effect_id": effect_id,
		#"from_pos": from_pos,
		#"to_pos": to_pos,
		#"color": color,
		#"age": 0.0,
		#"delay_before_zip": delay_before_zip,
		#"zip_duration": safe_zip_duration,
		#"head_pos": from_pos,
		#"trail": [],
		#"done": false
	#}
#
	#active_effects.append(packet)
	#set_process(true)
	#queue_redraw()
	
	
