extends Node2D

const BattleV2BattleManagerScript = preload("res://battle_v2/BattleManager.gd")
const EnemyBattleControllerScript = preload("res://battle_v2/Enemy/EnemyBattleController.gd")
const BattleV2ResultLogFormatterScript = preload("res://battle_v2/BattleV2ResultLogFormatter.gd")
const BattleV2UIHandlerScript = preload("res://battle_v2/BattleV2UIHandler.gd")
const BattleV2EffectLayerScript = preload("res://battle_v2/BattleV2EffectLayer.gd")
const BattleV2StatusBarHandlerScript = preload("res://battle_v2/BattleV2StatusBarHandler.gd")
const BattleV2StatusMirrorHandlerScript = preload("res://battle_v2/BattleV2StatusMirrorHandler.gd")
const BattleV2ProceduralLaneLayerScript = preload("res://battle_v2/BattleV2ProceduralLaneLayer.gd")
const BattleV2BackgroundDrawLayerScript = preload("res://battle_v2/BattleV2BackgroundDrawLayer.gd")
const BattleV3PipelineWidgetScript = preload("res://battle_v2/BattleV3PipelineWidget.gd")
const BattleV3ItemRefButtonScript = preload("res://battle_v2/BattleV3ItemRefButton.gd")
const BattleV3DropSlotScript = preload("res://battle_v2/BattleV3DropSlot.gd")
const UIHandlerHelpersScript = preload("res://UI/UIHandlerHelpers.gd")
const WidgetSpecUiScript = preload("res://UI/Widget_spec_UI.gd")
const WidgetsBuilder5Script = preload("res://Build/Widgets_Builder5.gd")
const LocalAIServerManagerScript = preload("res://local_ai/local_ai_server_manager.gd")
const MainAIScript = preload("res://local_ai/main_ai.gd")
const DecorativeUIScript = preload("res://UI/decorative_ui.gd")
const AuroraBrainBackgroundScript = preload("res://UI/arora_brain_background.gd")
const SaveManagerScript = preload("res://save/SaveManager.gd")
const ControllerFocusOverlayScript = preload("res://UI/Controller/ControllerFocusOverlay.gd")
const ControllerSceneListFocusScript = preload("res://UI/Controller/ControllerSceneListFocus.gd")
const ControllerBattleSupportUiScript = preload("res://UI/Controller/ControllerBattleSupportUi.gd")
const BATTLE_AURORA_TEXTURE = preload("res://images/blue_scifi_backing.png")


# ==========================================================
# BATTLE V2 SCENE
# ----------------------------------------------------------
# Starter scene for the future full-screen battle system.
# This scene is intentionally isolated from main_mode.gd.
# ==========================================================

const TAB_PRIMARY := "primary"
const TAB_SECONDARY := "secondary"
const TAB_CONSUMABLE := "consumable"
const TAB_SHIELDS := "shields"
const PLAYER_LOCK_REACQUIRE_DURATION_SECONDS := 1.5
const PRIMARY_WEAPON_SPAM_GATE_SECONDS := 3.0
const SECONDARY_WEAPON_SPAM_GATE_SECONDS := 0.0
const BATTLE_V2_PIPELINE_POS := Vector2(330, 420)
const BATTLE_V2_PIPELINE_SIZE := Vector2(330, 300)
const BATTLE_V2_ACTION_POS := Vector2(680, 475)
const BATTLE_V2_ACTION_SIZE := Vector2(285, 245)
const BATTLE_V2_ACTION_SHIELD_SLIDER_OFFSET := Vector2(55, 192)
const BATTLE_V2_ACTION_SHIELD_SLIDER_SIZE := Vector2(158, 24)
const BATTLE_V2_REFERENCE_POS := Vector2(975, 475)
const BATTLE_V2_REFERENCE_SIZE := Vector2(285, 245)
const BATTLE_V2_LOG_POS := Vector2(900, 500)
const BATTLE_V2_LOG_SIZE := Vector2(360, 240)
const BATTLE_V2_OVERHAUL_PROBE_POS := Vector2(930, 20)
const BATTLE_V2_OVERHAUL_PROBE_SIZE := Vector2(300, 62)
const BATTLE_V2_PLAYER_STATUS_MIRROR_POS := Vector2(40, 390)
const BATTLE_V2_ENEMY_STATUS_MIRROR_POS := Vector2(40, 575)
const BATTLE_V2_UNIT_STATUS_MIRROR_SIZE := Vector2(245, 145)
const BATTLE_V2_PLAYER_UI_LANE_POS := Vector2(40, 20)
const BATTLE_V2_PLAYER_UI_LANE_SIZE := Vector2(1220, 120)
const BATTLE_V2_AI_NEWS_POS := Vector2(420, 200)
const BATTLE_V2_AI_NEWS_SIZE := Vector2(460, 82)
const BATTLE_V2_AI_COMMENTARY_Z_INDEX := 900
const BATTLE_V2_AMMO_BAR_MAX := 99.0
const BATTLE_V2_PROCEDURAL_ACTOR_SIZE := Vector2(116, 116)
const BATTLE_V2_PROCEDURAL_ACTOR_EDGE_INSET := 82.0
const BATTLE_V2_ENDPOINT_SHIELD_COLOR := Color(0.12, 0.80, 1.0, 0.86)
const BATTLE_V2_ENDPOINT_HULL_COLOR := Color(1.0, 0.24, 0.10, 0.90)
const BATTLE_V2_ENDPOINT_HULL_CORE_COLOR := Color(1.0, 0.76, 0.26, 0.95)
const BATTLE_V2_ENDPOINT_REPAIR_COLOR := Color(0.24, 1.0, 0.36, 0.86)
const BATTLE_V2_ENDPOINT_RECHARGE_COLOR := Color(0.34, 0.86, 1.0, 0.88)
const BATTLE_V2_ENDPOINT_PATCH_COLOR := Color(0.70, 1.0, 0.36, 0.88)


var source_world_enemy: Variant = null
var source_enemy_id: String = ""

var battle_inventory_save_data: Dictionary = {}
var battle_item_db_snapshot: Dictionary = {}
var battle_ammo_inventory_source: Dictionary = {}
var battle_npc_save_data: Array = []
var battle_beacon_save_data: Array = []
var battle_space_object_save_data: Array = []

var battle_log_trace_fx: BattlePathTrail = null
var battle_widget_state: WidgetsState5 = null
var battle_widget_spec_ui: WidgetSpecUi = null
var battle_widget_builder: WidgetsBuilder5 = null
var battle_v2_overhaul_probe_root: Control = null
var battle_v2_overhaul_probe_enabled: bool = false
var battle_v2_player_status_mirror_root: Control = null
var battle_v2_enemy_status_mirror_root: Control = null
var battle_v2_status_mirror_widgets_enabled: bool = true
var battle_v2_player_ui_lane_root: Control = null
var battle_v2_ui_lane_widgets_enabled: bool = true
var battle_v2_hide_legacy_status_widgets_enabled: bool = true
var battle_v2_hide_legacy_header_widgets_enabled: bool = true
var battle_v2_hide_legacy_detail_widgets_enabled: bool = true
var battle_v2_show_legacy_lining_enabled: bool = false
var battle_local_ai_server_manager = LocalAIServerManagerScript.new()
var battle_main_ai = MainAIScript.new()
var battle_ai_news_root: Control = null
var battle_ai_initial_commentary_sent := false
var battle_ai_commentary_last_msec_by_kind: Dictionary = {}
var battle_ai_commentary_debug_prints := true
# The shield/hull backfield is safe behind the current widget layout and has its
# own switch so restoring it does not also restore legacy connection overlays.
var battle_v2_background_draw_layer_enabled: bool = true
var battle_v2_procedural_connections_enabled: bool = false
# BattleV2UIHandler draws legacy top-layer effects/frames/damage/event visuals.
# Disable it during the sandbox layout pass so only the new WidgetBuilder layout is visible.
var battle_v2_ui_handler_enabled: bool = false
var battle_decorative_ui: DecorativeUI = null
var battle_aurora_bg: AuroraBrainBackground = null
var battle_color_handler: Color_Handler = null
var battle_background_root: Control = null
var battle_background_texture: TextureRect = null
var battle_background_wash: ColorRect = null

const TEST_ITEMS := {
	#"xaelith_arc_lance": {
		#"item_id": "xaelith_arc_lance",
		#"display_name": "Xaelith Arc Lance",
		#"item_type": "weapon",
		#"group": "medium",
		#"slot": "primary",
		#"battle": {
			#"action_id": "fire_primary_weapon",
			#"event_type": "fire_primary_weapon",
			#"event_group": "weapon",
			#"same_type_key": "fire_primary_xaelith_arc_lance",
			#"duration": 3.0,
			#"requires_lock": true,
			#"is_state_change": false,
			#"is_damage_event": true,
			#"is_effect_event": false,
			#"is_visual_only": false
		#},
		#"stats": {
			#"damage_type": "energy",
			#"damage_value": 25,
			#"weapon_group": "medium"
		#},
		#"costs": {
			#"energy_cost": 25,
			#"ammo_group": "",
			#"ammo_cost": 0
		#},
		#"tags": ["energy_weapon", "primary_weapon", "medium_weapon", "alien_tech"],
		#"labels": ["primary_weapon_energy_based", "damage_type_energy"]
	#},
	#"vorrakai_sun_spitter": {
		#"item_id": "vorrakai_sun_spitter",
		#"display_name": "Vorrakai Sun Spitter",
		#"item_type": "weapon",
		#"group": "large",
		#"slot": "primary",
		#"battle": {
			#"action_id": "fire_primary_weapon",
			#"event_type": "fire_primary_weapon",
			#"event_group": "weapon",
			#"same_type_key": "fire_primary_vorrakai_sun_spitter",
			#"duration": 5.0,
			#"requires_lock": true,
			#"is_state_change": false,
			#"is_damage_event": true,
			#"is_effect_event": false,
			#"is_visual_only": false
		#},
		#"stats": {
			#"damage_type": "energy",
			#"damage_value": 40,
			#"weapon_group": "large"
		#},
		#"costs": {
			#"energy_cost": 45,
			#"ammo_group": "",
			#"ammo_cost": 0
		#},
		#"tags": ["energy_weapon", "primary_weapon", "large_weapon", "alien_tech"],
		#"labels": ["primary_weapon_energy_based", "damage_type_energy"]
	#},
	#"skarn_void_maul": {
		#"item_id": "skarn_void_maul",
		#"display_name": "Skarn Void Maul",
		#"item_type": "weapon",
		#"group": "medium",
		#"slot": "secondary",
		#"battle": {
			#"action_id": "fire_secondary_weapon",
			#"event_type": "fire_secondary_weapon",
			#"event_group": "weapon",
			#"same_type_key": "fire_secondary_skarn_void_maul",
			#"duration": 4.0,
			#"requires_lock": true,
			#"is_state_change": false,
			#"is_damage_event": true,
			#"is_effect_event": false,
			#"is_visual_only": false
		#},
		#"stats": {
			#"damage_type": "kinetic",
			#"damage_value": 40,
			#"weapon_group": "medium"
		#},
		#"costs": {
			#"energy_cost": 0,
			#"ammo_group": "medium",
			#"ammo_cost": 1
		#},
		#"tags": ["kinetic_weapon", "secondary_weapon", "uses_ammo", "medium_weapon", "alien_tech"],
		#"labels": ["secondary_weapon_kinetic_based", "damage_type_kinetic"]
	#},
	#"threxian_mass_driver": {
		#"item_id": "threxian_mass_driver",
		#"display_name": "Threxian Mass Driver",
		#"item_type": "weapon",
		#"group": "large",
		#"slot": "secondary",
		#"battle": {
			#"action_id": "fire_secondary_weapon",
			#"event_type": "fire_secondary_weapon",
			#"event_group": "weapon",
			#"same_type_key": "fire_secondary_threxian_mass_driver",
			#"duration": 5.0,
			#"requires_lock": true,
			#"is_state_change": false,
			#"is_damage_event": true,
			#"is_effect_event": false,
			#"is_visual_only": false
		#},
		#"stats": {
			#"damage_type": "kinetic",
			#"damage_value": 65,
			#"weapon_group": "large"
		#},
		#"costs": {
			#"energy_cost": 0,
			#"ammo_group": "large",
			#"ammo_cost": 1
		#},
		#"tags": ["kinetic_weapon", "secondary_weapon", "uses_ammo", "large_weapon", "alien_tech"],
		#"labels": ["secondary_weapon_kinetic_based", "damage_type_kinetic"]
	#},
	#"oruun_glass_shell": {
		#"item_id": "oruun_glass_shell",
		#"display_name": "Oruun Glass Shell",
		#"item_type": "shield",
		#"group": "small",
		#"slot": "shield",
		#"battle": {
			#"action_id": "switch_shield",
			#"event_type": "switch_shield",
			#"event_group": "shield",
			#"same_type_key": "shield_switch_oruun_glass_shell",
			#"duration": 1.5,
			#"requires_lock": false,
			#"is_state_change": true,
			#"is_damage_event": false,
			#"is_effect_event": false,
			#"is_visual_only": false
		#},
		#"stats": {
			#"shield_hp_max": 45,
			#"base_damage_resist": 0.20,
			#"regen_per_second": 2.0,
			#"regen_delay": 2.0,
			#"swap_time": 1.5
		#},
		#"costs": {
			#"steady_energy_drain": 3.0
		#},
		#"tags": ["shield", "small_shield", "energy_drain", "alien_tech"],
		#"labels": ["unit_shield_equipped", "shield_slider_scaling"]
	#},
	#"kaavari_star_bulwark": {
		#"item_id": "kaavari_star_bulwark",
		#"display_name": "Kaavari Star Bulwark",
		#"item_type": "shield",
		#"group": "large",
		#"slot": "shield",
		#"battle": {
			#"action_id": "switch_shield",
			#"event_type": "switch_shield",
			#"event_group": "shield",
			#"same_type_key": "shield_switch_kaavari_star_bulwark",
			#"duration": 3.0,
			#"requires_lock": false,
			#"is_state_change": true,
			#"is_damage_event": false,
			#"is_effect_event": false,
			#"is_visual_only": false
		#},
		#"stats": {
			#"shield_hp_max": 130,
			#"base_damage_resist": 0.50,
			#"regen_per_second": 6.0,
			#"regen_delay": 2.0,
			#"swap_time": 3.0
		#},
		#"costs": {
			#"steady_energy_drain": 10.0
		#},
		#"tags": ["shield", "large_shield", "energy_drain", "alien_tech"],
		#"labels": ["unit_shield_equipped", "shield_slider_scaling"]
	#}
}

const TEST_ITEM_TAB_ORDER := {
	"primary": ["xaelith_arc_lance", "vorrakai_sun_spitter"],
	"secondary": ["skarn_void_maul", "threxian_mass_driver"],
	"shields": ["oruun_glass_shell", "kaavari_star_bulwark"]
}

var title_label: Label
var status_label: Label
var enemy_label: Label
var log_label: RichTextLabel
var return_button: Button
var shield_slider: HSlider
var legacy_shield_slider: HSlider = null
var action_shield_slider: HSlider = null
var action_body_root: Control
var action_slot_labels: Dictionary = {}
var battle_v3_holder_root: Control = null
var battle_v3_reference_root: Control = null
var battle_v3_reference_list: VBoxContainer = null
var battle_v3_drop_slots: Dictionary = {}
var battle_v3_exec_buttons: Dictionary = {}
var battle_v3_reference_source_signature: String = "__unbuilt__"
var battle_v3_reference_refresh_pending: bool = false
var battle_v3_slot_overrides: Dictionary = {
	"primary": "",
	"secondary": "",
	"shields": "",
	"consumable": ""
}
var player_energy_bar_root: Control
var player_energy_bar_available: ColorRect
var player_energy_bar_queued: ColorRect
var player_energy_bar_spent: ColorRect
var enemy_energy_bar_root: Control
var enemy_energy_bar_available: ColorRect
var enemy_energy_bar_queued: ColorRect
var enemy_energy_bar_spent: ColorRect
var battle_context: Dictionary = {}
var battle_player_state_save_data: Dictionary = {}
var handoff_enemy: Variant = null
var active_enemy: Variant = null
var player_state_packet: BattleV2UnitAdapter
var player_handler_v2: PlayerHandler
var battle_event_manager: BattleV2EventManager
var battle_action_manager: ActionManager_battle
var battle_manager_v2: Variant = null
var energy_handler_v2: EnergyHandler
var enemy_energy_handler_v2: EnergyHandler
var ammo_handler_v2: AmmoHandler
var stat_effect_handler_v2: StatsEffectManager
var enemy_logic_v2: EnemyLogic
var enemy_battle_controller: EnemyBattleController
var battle_v2_ui_handler: Node = null
var battle_v2_endpoint_effect_layer: BattleV2EffectLayer = null
var battle_v2_endpoint_effects_enabled: bool = true
var battle_v2_status_bar_handler = null
var battle_v2_status_mirror_handler = null
var battle_v2_procedural_lane_layer: Control = null
var battle_v2_background_draw_layer: Control = null
var battle_v3_pipeline_widget: BattleV3PipelineWidget = null
var battle_id: String = ""
var selected_action_tab: String = TAB_PRIMARY
var battle_ui_labels: Dictionary = {}
var battle_action_tabs: Dictionary = {}
var battle_action_rows: Array = []
var latest_todo_status_text: String = ""
var latest_completed_event_ids: Array = []
var battle_v2_todo_active_signature: String = ""
var battle_v2_header_state_signature: String = ""
var battle_v2_ui_position_signature: String = ""
var battle_v2_ended: bool = false
var battle_v2_outcome: String = ""
var battle_v2_auto_return_started: bool = false
var battle_v2_result_log_formatter = null
var battle_v2_end_sequence_root: Control = null
var battle_v2_end_sequence_panel: ColorRect = null
var battle_v2_end_sequence_title_label: Label = null
var battle_v2_end_sequence_body_label: Label = null
var battle_v2_end_sequence_countdown_label: Label = null
var evade_cooldown_seconds: float = 25.0
var evade_todo_duration_seconds: float = 5.0
var evade_lock_reacquire_penalty_seconds: float = 8.0
var evade_energy_cost: float = 10.0
var evade_pipeline_disrupt_seconds: float = 2.0
var player_evade_cooldown_until_msec: int = 0
var enemy_evade_cooldown_until_msec_by_key: Dictionary = {}
var energy_shield_drain_signature: String = ""
var enemy_energy_shield_drain_signature: String = ""
var player_evade_button: Button = null
var weapon_spam_gate_until_msec: Dictionary = {
	"fire_primary_weapon": 0,
	"fire_secondary_weapon": 0
}
var weapon_spam_gate_refresh_signature: String = ""
var secondary_weapon_todo_lock_refresh_signature: String = ""
var latest_stat_effect_update_summary: Dictionary = {}
var latest_active_drone_update_summary: Dictionary = {}
var battle_v2_drone_runtime_signature: String = ""
var battle_v2_drone_ui_update_counter: int = 0
var latest_lane_intervention_result: Dictionary = {}
var controller_focus_overlay: ControllerFocusOverlay = null
var controller_scene_focus: ControllerSceneListFocus = null
var controller_battle_ui_handler: ControllerBattleSupportUi = null
var controller_l1_shield_was_pressed := false
var controller_r1_shield_was_pressed := false
var controller_l1_shield_pressed_msec := 0
var controller_r1_shield_pressed_msec := 0
var controller_l1_shield_hold_applied := false
var controller_r1_shield_hold_applied := false
var controller_shield_hold_threshold_msec := 450

# ==========================================================
# ENEMY THINK LOOP STATE
# ==========================================================
var enemy_think_timer: float = 0.0
var enemy_think_interval: float = 1.25
var enemy_think_paused: bool = false
var enemy_action_cooldown_until_msec: int = 0
var enemy_wait_cooldown_seconds: float = 0.75
var enemy_action_cooldown_seconds: float = 1.25


func _ready() -> void:
	# Summary: Build the starter battle-v2 scene UI without touching main-mode delta systems.
	if Globals.print_priority_5:
		print("Battle V2 scene loaded.")
	Globals.stop_main_mode_music(false)

	# ------------------------------------------------------
	# Claim battle state from the transition globals.
	# ------------------------------------------------------
	Globals.battle_pending = false
	Globals.battle_mode = true

	battle_context = Globals.battle_v2_context.duplicate(true)
	if Globals.print_priority_5:
		print("[battle_context_schema] ", battle_context.get("context_schema", "NO_SCHEMA"))
	handoff_enemy = battle_context.get("enemy", Globals.current_enemy)
	battle_id = "battle_v2_" + str(Time.get_ticks_msec())

	if Globals.print_priority_5:
		print("[battle_context_claimed] keys=", battle_context.keys())
		print("[battle_context_claimed] loadout_data=", battle_context.get("loadout_data", "MISSING"))
		print("[battle_context_claimed] inventory=", battle_context.get("inventory", null))
		print("[battle_context_claimed] action_manager=", battle_context.get("action_manager", null))
		print("[battle_context_claimed] energy_handler=", battle_context.get("energy_handler", null))

	# ------------------------------------------------------
	# Load safe plain data from the claimed context.
	# ------------------------------------------------------
	battle_inventory_save_data = get_battle_inventory_save_data_from_context()
	battle_item_db_snapshot = get_battle_item_db_snapshot_from_context()
	battle_npc_save_data = get_battle_npc_save_data_from_context()
	battle_beacon_save_data = get_battle_beacon_save_data_from_context()
	battle_space_object_save_data = get_battle_space_object_save_data_from_context()
	battle_player_state_save_data = get_battle_player_state_save_data_from_context()
	battle_ammo_inventory_source = build_battle_ammo_inventory_source()

	if Globals.print_priority_5:
		print("[battle_inventory_loaded] keys=", battle_inventory_save_data.keys())
		print("[battle_item_db_loaded] count=", battle_item_db_snapshot.size())
		print("[battle_npc_snapshot_loaded] count=", battle_npc_save_data.size())
		print("[battle_beacon_snapshot_loaded] count=", battle_beacon_save_data.size())
		print("[battle_space_object_snapshot_loaded] count=", battle_space_object_save_data.size())
		print("[battle_player_state_snapshot_loaded] keys=", battle_player_state_save_data.keys())

	# ------------------------------------------------------
	# Build isolated battle helpers before the UI rows route clicks.
	# ------------------------------------------------------
	setup_battle_v2_handlers()

	# ------------------------------------------------------
	# Build static UI, then fill it from context.
	# ------------------------------------------------------
	ensure_battle_widget_state()
	build_scene_shell()
	start_battle_log_trace_fx()
	setup_battle_v2_ui_handler()
	setup_battle_widget_spec_runtime()
	build_battle_v2_overhaul_probe_widget()
	build_battle_v2_unit_status_mirror_widgets()
	build_battle_v2_ui_lane_widgets()
	build_battle_v2_ai_news_widget("battle_v2_ready")
	setup_battle_local_ai_server_manager("battle_v2_boot")
	setup_battle_main_ai_handler("battle_v2_ready")
	build_battle_v2_procedural_lane_layer()
	apply_battle_v2_legacy_header_visibility_mode()
	apply_battle_v2_legacy_status_visibility_mode()
	apply_battle_v2_legacy_detail_visibility_mode()
	if enemy_battle_controller != null:
		enemy_battle_controller.refresh_refs({"log_label": log_label})
	refresh_battle_context_labels()
	refresh_battle_v2_ui_lane_widgets()
	apply_battle_v2_legacy_header_visibility_mode()
	apply_battle_v2_legacy_status_visibility_mode()
	apply_battle_v2_legacy_detail_visibility_mode()
	report_battle_v2_header_state_to_ui_handler()
	refresh_action_tab_visuals()
	refresh_action_body_rows()
	refresh_battle_v3_pipeline_from_event_manager()
	start_enemy_thinking()
	setup_battle_controller_focus_handler()
	force_battle_ai_news_widget_front("battle_ready_complete")


func _input(event: InputEvent) -> void:
	if controller_scene_focus != null and is_instance_valid(controller_scene_focus):
		if controller_scene_focus.handle_input(event):
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Summary: Tick Battle V2 TODO timing and refresh the prototype timeline display.
	process_battle_controller_shield_hold()
	if battle_event_manager == null:
		return
	if battle_v2_ended:
		return
	if battle_manager_v2 != null and battle_manager_v2.get("battle_active") == false:
		mark_battle_v2_ended("battle_ended")
		return

	update_battle_shared_visual_runtime(delta)
	sync_energy_handler_shield_drain_from_player_state()
	if energy_handler_v2 != null:
		energy_handler_v2.update_energy(delta)
	if enemy_energy_handler_v2 != null:
		sync_energy_handler_shield_drain_from_enemy_state()
		enemy_energy_handler_v2.update_energy(delta)
		sync_active_enemy_energy_from_handler()
	refresh_energy_status_values()
	refresh_enemy_energy_status_values()
	queue_player_lock_reacquire_if_needed()
	queue_enemy_lock_reacquire_if_needed()
	refresh_unit_status_values()
	refresh_player_evade_control_state()
	process_enemy_thinking(delta)
	refresh_weapon_spam_gate_rows_if_needed()
	refresh_secondary_weapon_todo_lock_rows_if_needed()
	flush_battle_v3_reference_refresh_if_pending()
	process_stat_effect_updates(delta)
	process_active_drone_runtime(delta)
	refresh_battle_v3_side_info_windows()
	refresh_battle_v3_pipeline_from_event_manager()
	refresh_battle_v2_ui_lane_widgets()
	if battle_v2_ended:
		return

	# ------------------------------------------------------
	# Stay quiet while no TODO is active. The timeline already
	# holds the latest displayed idle/completed state.
	# ------------------------------------------------------
	if battle_event_manager.active_events.is_empty():
		return

	# ------------------------------------------------------
	# EventManager owns countdown timing. The scene only asks
	# it to tick and then displays the timing state.
	# ------------------------------------------------------
	battle_event_manager.process_events(delta)

	if not battle_event_manager.completed_event_batch.is_empty():
		remember_completed_event_batch()

	refresh_todo_timeline_from_event_manager()


func process_stat_effect_updates(delta: float) -> void:
	# Summary: Tick Battle V2 stat effects so signal/drone protection durations expire outside the TODO queue.
	if stat_effect_handler_v2 == null:
		return
	if not stat_effect_handler_v2.has_method("update_effects"):
		return

	var update_summary = stat_effect_handler_v2.update_effects(delta)
	if typeof(update_summary) != TYPE_DICTIONARY:
		return

	latest_stat_effect_update_summary = update_summary

	var expired_effects: Array = update_summary.get("expired", [])
	if expired_effects.is_empty():
		return

	refresh_unit_status_values()
	refresh_action_body_rows()


func process_active_drone_runtime(delta: float) -> void:
	# Summary: Tick active Battle V2 drones that own HP, shield absorb, and autonomous attacks.
	if battle_manager_v2 == null:
		return
	if not battle_manager_v2.has_method("update_active_drones"):
		return

	var update_summary = battle_manager_v2.update_active_drones(delta)
	if typeof(update_summary) != TYPE_DICTIONARY:
		return

	latest_active_drone_update_summary = update_summary
	report_battle_v2_drone_runtime_to_ui_handler(update_summary)

	var attack_count := 0
	if typeof(update_summary.get("attacks", [])) == TYPE_ARRAY:
		attack_count = update_summary.get("attacks", []).size()
	var expired_count := 0
	if typeof(update_summary.get("expired", [])) == TYPE_ARRAY:
		expired_count = update_summary.get("expired", []).size()
	var destroyed_count := 0
	if typeof(update_summary.get("destroyed", [])) == TYPE_ARRAY:
		destroyed_count = update_summary.get("destroyed", []).size()

	if attack_count > 0 or expired_count > 0 or destroyed_count > 0:
		refresh_unit_status_values()

	var battle_outcome := str(update_summary.get("battle_outcome", "battle_continues"))
	if battle_outcome == "player_victory":
		queue_battle_v2_victory_result()
		mark_battle_v2_ended("player_victory")
	elif battle_outcome == "player_defeat":
		mark_battle_v2_ended("player_defeat")


func ensure_battle_widget_state() -> void:
	if battle_widget_state != null and is_instance_valid(battle_widget_state):
		return

	battle_widget_state = WidgetsState5.new()
	battle_widget_state.name = "Battle_V2_Widget_State"
	add_child(battle_widget_state)


func ensure_battle_widget_builder() -> void:
	# Summary: Create the shared widget builder bridge for Battle V2 visual-only overhaul widgets.
	ensure_battle_widget_state()

	if battle_widget_builder != null and is_instance_valid(battle_widget_builder):
		battle_widget_builder.state = battle_widget_state
		return

	battle_widget_builder = WidgetsBuilder5Script.new()
	battle_widget_builder.name = "Battle_V2_Widget_Builder"
	battle_widget_builder.state = battle_widget_state
	add_child(battle_widget_builder)


func build_battle_v2_overhaul_probe_widget() -> void:
	# Summary: First sandbox pass: prove Battle V2 can build a WidgetBuilder/WidgetSpec-tracked widget without touching battle truth.
	if not battle_v2_overhaul_probe_enabled:
		return
	if battle_v2_overhaul_probe_root != null and is_instance_valid(battle_v2_overhaul_probe_root):
		return

	ensure_battle_widget_state()
	ensure_battle_widget_builder()

	if battle_widget_builder == null or not is_instance_valid(battle_widget_builder):
		return
	if not battle_widget_builder.has_method("build_battle_v2_overhaul_probe_widget"):
		if Globals.print_priority_2:
			print("[BATTLE_V2_OVERHAUL_PROBE] Widgets_Builder5 missing build_battle_v2_overhaul_probe_widget().")
		return

	var root = battle_widget_builder.build_battle_v2_overhaul_probe_widget(
		battle_widget_state,
		BATTLE_V2_OVERHAUL_PROBE_POS,
		BATTLE_V2_OVERHAUL_PROBE_SIZE
	)

	if root == null or not (root is Control):
		return

	battle_v2_overhaul_probe_root = root
	if root.get_parent() == null:
		add_child(root)

	if battle_widget_spec_ui != null and is_instance_valid(battle_widget_spec_ui):
		battle_widget_spec_ui.build_onscreen_widget_runtime_data()

	if Globals.print_priority_3:
		var widget_count := -1
		if battle_widget_spec_ui != null and is_instance_valid(battle_widget_spec_ui):
			widget_count = int(battle_widget_spec_ui.onscreen_widget_runtime_data.get("widget_count", -1))
		print("[BATTLE_V2_OVERHAUL_PROBE] built=true widget_count=", widget_count)


func build_battle_v2_unit_status_mirror_widgets() -> void:
	# Summary: Build read-only WidgetBuilder status mirrors that can visually replace the legacy status panels while the old labels stay alive.
	if not battle_v2_status_mirror_widgets_enabled:
		return

	ensure_battle_widget_state()
	ensure_battle_widget_builder()

	if battle_widget_builder == null or not is_instance_valid(battle_widget_builder):
		return
	if not battle_widget_builder.has_method("build_battle_v2_unit_status_widget"):
		if Globals.print_priority_2:
			print("[BATTLE_V2_STATUS_MIRROR] Widgets_Builder5 missing build_battle_v2_unit_status_widget().")
		return

	if battle_v2_player_status_mirror_root == null or not is_instance_valid(battle_v2_player_status_mirror_root):
		var player_root = battle_widget_builder.build_battle_v2_unit_status_widget(
			battle_widget_state,
			"battle_v2_player_status_mirror",
			"PLAYER STATUS",
			"player",
			BATTLE_V2_PLAYER_STATUS_MIRROR_POS,
			BATTLE_V2_UNIT_STATUS_MIRROR_SIZE
		)
		if player_root is Control:
			battle_v2_player_status_mirror_root = player_root
			if player_root.get_parent() == null:
				add_child(player_root)

	if battle_v2_enemy_status_mirror_root == null or not is_instance_valid(battle_v2_enemy_status_mirror_root):
		var enemy_root = battle_widget_builder.build_battle_v2_unit_status_widget(
			battle_widget_state,
			"battle_v2_enemy_status_mirror",
			"ENEMY STATUS",
			"enemy",
			BATTLE_V2_ENEMY_STATUS_MIRROR_POS,
			BATTLE_V2_UNIT_STATUS_MIRROR_SIZE
		)
		if enemy_root is Control:
			battle_v2_enemy_status_mirror_root = enemy_root
			if enemy_root.get_parent() == null:
				add_child(enemy_root)

	bind_battle_v2_status_mirror_bars()
	refresh_battle_v2_unit_status_mirror_widgets()
	if battle_widget_spec_ui != null and is_instance_valid(battle_widget_spec_ui):
		battle_widget_spec_ui.build_onscreen_widget_runtime_data()

	if Globals.print_priority_3:
		print("[BATTLE_V2_STATUS_MIRROR] built player=", battle_v2_player_status_mirror_root != null, " enemy=", battle_v2_enemy_status_mirror_root != null)


func refresh_battle_v2_unit_status_mirror_widgets() -> void:
	# Summary: Mirror live Battle V2 state into the new WidgetBuilder read-only widgets.
	ensure_battle_v2_status_mirror_handler()
	battle_v2_status_mirror_handler.refresh_unit_status_mirror_widgets()


func ensure_battle_v2_status_bar_handler() -> void:
	if battle_v2_status_bar_handler != null:
		return
	battle_v2_status_bar_handler = BattleV2StatusBarHandlerScript.new()


func ensure_battle_v2_status_mirror_handler() -> void:
	if battle_v2_status_mirror_handler == null:
		battle_v2_status_mirror_handler = BattleV2StatusMirrorHandlerScript.new()
	battle_v2_status_mirror_handler.setup(self)


func bind_battle_v2_status_mirror_bars() -> void:
	# Summary: Bind all Battle V2 mirror bars to one small painter so text and fill remain stable.
	if battle_widget_state == null:
		return

	ensure_battle_v2_status_bar_handler()
	for bar_id in ["hull", "shield", "energy", "ammo"]:
		bind_battle_v2_status_bar("player", "battle_v2_player_status_mirror", bar_id)
		bind_battle_v2_status_bar("enemy", "battle_v2_enemy_status_mirror", bar_id)


func bind_battle_v2_status_bar(side_id: String, widget_id: String, bar_id: String) -> void:
	if battle_v2_status_bar_handler == null:
		return
	battle_v2_status_bar_handler.bind_bar(side_id + "_" + bar_id, {
		"root": get_battle_widget_control(widget_id + "_" + bar_id + "_bar_root"),
		"fill": get_battle_widget_color_rect(widget_id + "_" + bar_id + "_bar_fill"),
		"queued": get_battle_widget_color_rect(widget_id + "_" + bar_id + "_bar_queued"),
		"spent": get_battle_widget_color_rect(widget_id + "_" + bar_id + "_bar_spent"),
		"label": get_battle_widget_label(widget_id + "_" + bar_id)
	})


func get_battle_widget_control(control_key: String) -> Control:
	if battle_widget_state == null:
		return null
	if typeof(battle_widget_state.controls) != TYPE_DICTIONARY:
		return null
	var control = battle_widget_state.controls.get(control_key, null)
	if control is Control and is_instance_valid(control):
		return control as Control
	return null


func get_battle_widget_color_rect(rect_key: String) -> ColorRect:
	if battle_widget_state == null:
		return null
	if typeof(battle_widget_state.color_rects) != TYPE_DICTIONARY:
		return null
	var rect = battle_widget_state.color_rects.get(rect_key, null)
	if rect is ColorRect and is_instance_valid(rect):
		return rect as ColorRect
	return null


func get_battle_widget_label(label_key: String) -> Label:
	if battle_widget_state == null:
		return null
	if typeof(battle_widget_state.labels) != TYPE_DICTIONARY:
		return null
	var label = battle_widget_state.labels.get(label_key, null)
	if label is Label and is_instance_valid(label):
		return label as Label
	return null


func update_battle_v2_status_mirror_bars() -> void:
	ensure_battle_v2_status_mirror_handler()
	battle_v2_status_mirror_handler.update_status_mirror_bars()


func build_player_hull_bar_packet() -> Dictionary:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.build_player_hull_bar_packet()


func build_enemy_hull_bar_packet() -> Dictionary:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.build_enemy_hull_bar_packet()


func build_player_shield_bar_packet() -> Dictionary:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.build_player_shield_bar_packet()


func build_enemy_shield_bar_packet() -> Dictionary:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.build_enemy_shield_bar_packet()


func build_energy_bar_packet(handler) -> Dictionary:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.build_energy_bar_packet(handler)


func build_player_ammo_bar_packet() -> Dictionary:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.build_player_ammo_bar_packet()


func build_enemy_ammo_bar_packet() -> Dictionary:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.build_enemy_ammo_bar_packet()


func make_status_value_bar_packet(label_text: String, current: float, max_value: float, fill_color: Color, empty_text: String = "") -> Dictionary:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.make_status_value_bar_packet(label_text, current, max_value, fill_color, empty_text)


func make_ammo_bar_packet(total_ammo: int, override_text: String = "") -> Dictionary:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.make_ammo_bar_packet(total_ammo, override_text)


func make_ammo_bar_text(total_ammo: int) -> String:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.make_ammo_bar_text(total_ammo)


func get_player_total_ammo_count() -> int:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.get_player_total_ammo_count()


func get_enemy_total_ammo_count() -> int:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.get_enemy_total_ammo_count()


func build_player_status_mirror_lines() -> Dictionary:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.build_player_status_mirror_lines()


func build_enemy_status_mirror_lines() -> Dictionary:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.build_enemy_status_mirror_lines()


func get_player_hull_status_text() -> String:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.get_player_hull_status_text()


func get_enemy_hull_status_text() -> String:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.get_enemy_hull_status_text()


func get_player_energy_status_text() -> String:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.get_player_energy_status_text()


func get_enemy_energy_status_text() -> String:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.get_enemy_energy_status_text()


func get_energy_handler_status_text(handler) -> String:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.get_energy_handler_status_text(handler)


func get_player_lock_status_text() -> String:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.get_player_lock_status_text()


func get_enemy_lock_status_text() -> String:
	ensure_battle_v2_status_mirror_handler()
	return battle_v2_status_mirror_handler.get_enemy_lock_status_text()


func update_battle_v2_unit_status_mirror(widget_id: String, lines: Dictionary) -> void:
	# Summary: Safely update one read-only battle status mirror by WidgetState label keys.
	ensure_battle_v2_status_mirror_handler()
	battle_v2_status_mirror_handler.update_unit_status_mirror(widget_id, lines)


func set_battle_widget_label_text(label_key: String, text: String) -> void:
	# Summary: Update labels stored in WidgetsState without assuming the node is still alive.
	if battle_widget_state == null:
		return
	if typeof(battle_widget_state.labels) != TYPE_DICTIONARY:
		return
	if not battle_widget_state.labels.has(label_key):
		return
	var label = battle_widget_state.labels[label_key]
	if label is Label and is_instance_valid(label):
		(label as Label).text = text



func build_battle_v2_ui_lane_widgets() -> void:
	# Summary: Build the active top UI lane shell. Procedural anchors place both combatants on this one rail.
	if not battle_v2_ui_lane_widgets_enabled:
		return

	ensure_battle_widget_state()
	ensure_battle_widget_builder()

	if battle_widget_builder == null or not is_instance_valid(battle_widget_builder):
		return
	if not battle_widget_builder.has_method("build_battle_v2_lane_strip_widget"):
		if Globals.print_priority_2:
			print("[BATTLE_V2_UI_LANE] Widgets_Builder5 missing build_battle_v2_lane_strip_widget().")
		return

	if battle_v2_player_ui_lane_root == null or not is_instance_valid(battle_v2_player_ui_lane_root):
		var player_lane = battle_widget_builder.build_battle_v2_lane_strip_widget(
			battle_widget_state,
			"battle_v2_player_ui_lane",
			"",
			"player",
			BATTLE_V2_PLAYER_UI_LANE_POS,
			BATTLE_V2_PLAYER_UI_LANE_SIZE
		)
		if player_lane is Control:
			battle_v2_player_ui_lane_root = player_lane
			if player_lane.get_parent() == null:
				add_child(player_lane)

	refresh_battle_v2_ui_lane_widgets()
	if battle_widget_spec_ui != null and is_instance_valid(battle_widget_spec_ui):
		battle_widget_spec_ui.build_onscreen_widget_runtime_data()

	if Globals.print_priority_3:
		print("[BATTLE_V2_UI_LANE] built active=", battle_v2_player_ui_lane_root != null)


func build_battle_v2_ai_news_widget(reason: String = "manual") -> void:
	# Summary: Reuse the main-mode DRIFTWIRE ticker as Battle V2's local AI commentary lane.
	ensure_battle_widget_state()
	ensure_battle_widget_builder()
	debug_battle_ai_commentary("build widget requested reason=" + reason)

	if battle_ai_news_root != null and is_instance_valid(battle_ai_news_root):
		battle_ai_news_root.position = BATTLE_V2_AI_NEWS_POS
		battle_ai_news_root.size = BATTLE_V2_AI_NEWS_SIZE
		force_battle_ai_news_widget_front("existing_" + reason)
		return

	if battle_widget_builder == null or not is_instance_valid(battle_widget_builder):
		debug_battle_ai_commentary("build blocked: missing battle_widget_builder")
		return
	if not battle_widget_builder.has_method("build_main_ai_news_widget"):
		debug_battle_ai_commentary("build blocked: Widgets_Builder5 missing build_main_ai_news_widget()")
		return

	var root = battle_widget_builder.build_main_ai_news_widget(
		battle_widget_state,
		BATTLE_V2_AI_NEWS_POS,
		BATTLE_V2_AI_NEWS_SIZE
	)

	if root == null or not (root is Control):
		debug_battle_ai_commentary("build blocked: builder returned invalid root=" + str(root))
		return

	battle_ai_news_root = root
	battle_ai_news_root.z_index = BATTLE_V2_AI_COMMENTARY_Z_INDEX
	battle_ai_news_root.z_as_relative = false
	battle_ai_news_root.visible = true
	battle_ai_news_root.modulate = Color.WHITE
	if battle_ai_news_root.get_parent() != self:
		if battle_ai_news_root.get_parent() != null:
			battle_ai_news_root.get_parent().remove_child(battle_ai_news_root)
		add_child(battle_ai_news_root)

	var title = battle_widget_state.labels.get("main_ai_news_title", null)
	if title is Label:
		(title as Label).text = "AMI COMBAT"

	if battle_widget_spec_ui != null and is_instance_valid(battle_widget_spec_ui):
		battle_widget_spec_ui.build_onscreen_widget_runtime_data()

	force_battle_ai_news_widget_front("built_" + reason)
	debug_battle_ai_widget_visibility("built_" + reason)


func force_battle_ai_news_widget_front(reason: String = "manual") -> void:
	if battle_ai_news_root == null or not is_instance_valid(battle_ai_news_root):
		debug_battle_ai_commentary("front blocked: widget root missing reason=" + reason)
		return

	battle_ai_news_root.position = BATTLE_V2_AI_NEWS_POS
	battle_ai_news_root.size = BATTLE_V2_AI_NEWS_SIZE
	battle_ai_news_root.custom_minimum_size = BATTLE_V2_AI_NEWS_SIZE
	battle_ai_news_root.z_index = BATTLE_V2_AI_COMMENTARY_Z_INDEX
	battle_ai_news_root.z_as_relative = false
	battle_ai_news_root.visible = true
	battle_ai_news_root.modulate = Color.WHITE

	if battle_ai_news_root.get_parent() != self:
		if battle_ai_news_root.get_parent() != null:
			battle_ai_news_root.get_parent().remove_child(battle_ai_news_root)
		add_child(battle_ai_news_root)
	move_child(battle_ai_news_root, get_child_count() - 1)

	debug_battle_ai_widget_visibility("front_" + reason)


func debug_battle_ai_widget_visibility(reason: String) -> void:
	if not battle_ai_commentary_debug_prints:
		return
	var root_text := "null"
	if battle_ai_news_root != null and is_instance_valid(battle_ai_news_root):
		root_text = (
			"path=" + str(battle_ai_news_root.get_path() if battle_ai_news_root.is_inside_tree() else "not_in_tree")
			+ " parent=" + str(battle_ai_news_root.get_parent())
			+ " pos=" + str(battle_ai_news_root.position)
			+ " size=" + str(battle_ai_news_root.size)
			+ " visible=" + str(battle_ai_news_root.visible)
			+ " tree_visible=" + str(battle_ai_news_root.is_visible_in_tree())
			+ " z=" + str(battle_ai_news_root.z_index)
			+ " z_relative=" + str(battle_ai_news_root.z_as_relative)
		)
	debug_battle_ai_commentary("widget visibility reason=" + reason + " root={" + root_text + "} scene_children=" + str(get_child_count()))


func debug_battle_ai_commentary(message: String) -> void:
	if battle_ai_commentary_debug_prints:
		print("[BATTLE_AI_COMMENTARY] " + message)


func setup_battle_local_ai_server_manager(reason: String = "battle_v2_boot") -> void:
	if battle_local_ai_server_manager == null or not is_instance_valid(battle_local_ai_server_manager):
		battle_local_ai_server_manager = LocalAIServerManagerScript.new()
		debug_battle_ai_commentary("server manager recreated reason=" + reason)

	battle_local_ai_server_manager.name = "BattleLocalAIServerManager"
	if battle_local_ai_server_manager.get_parent() == null:
		add_child(battle_local_ai_server_manager)

	if not battle_local_ai_server_manager.status_changed.is_connected(_on_battle_local_ai_server_status_changed):
		battle_local_ai_server_manager.status_changed.connect(_on_battle_local_ai_server_status_changed)

	debug_battle_ai_commentary("server manager begin_startup reason=" + reason)
	battle_local_ai_server_manager.begin_startup(reason)


func _on_battle_local_ai_server_status_changed(packet: Dictionary) -> void:
	debug_battle_ai_commentary(
		"server status state=" + str(packet.get("state", ""))
		+ " message=" + str(packet.get("message", ""))
		+ " has_main_ai=" + str(battle_main_ai != null and is_instance_valid(battle_main_ai))
	)
	if battle_main_ai != null and is_instance_valid(battle_main_ai) and battle_main_ai.has_method("handle_server_status"):
		battle_main_ai.handle_server_status(packet)

	var state_text := str(packet.get("state", "")).strip_edges()
	if state_text.begins_with("ready") and not battle_ai_initial_commentary_sent:
		request_battle_ai_snapshot_commentary("local_ai_ready")


func setup_battle_main_ai_handler(reason: String = "battle_v2_ready") -> void:
	build_battle_v2_ai_news_widget(reason)
	if battle_main_ai == null or not is_instance_valid(battle_main_ai):
		battle_main_ai = MainAIScript.new()
		debug_battle_ai_commentary("main ai recreated reason=" + reason)

	battle_main_ai.name = "BattleMainAI"
	battle_main_ai.random_news_enabled = false
	if battle_main_ai.get_parent() == null:
		add_child(battle_main_ai)

	if battle_main_ai.has_method("setup"):
		battle_main_ai.setup(self, battle_widget_state)

	var title = battle_widget_state.labels.get("main_ai_news_title", null)
	if title is Label:
		(title as Label).text = "AMI COMBAT"
	if battle_main_ai.has_method("update_news_widget"):
		battle_main_ai.update_news_widget("STANDBY", "AMI combat commentary link is warming up.")
	force_battle_ai_news_widget_front("main_ai_setup_" + reason)

	if battle_local_ai_server_manager != null and is_instance_valid(battle_local_ai_server_manager):
		var last_status := {}
		if battle_local_ai_server_manager.has_method("get_last_status_packet"):
			last_status = battle_local_ai_server_manager.get_last_status_packet()
		if typeof(last_status) == TYPE_DICTIONARY and not last_status.is_empty():
			debug_battle_ai_commentary("main ai receives cached server status state=" + str(last_status.get("state", "")))
			battle_main_ai.handle_server_status(last_status)
		elif bool(battle_local_ai_server_manager.get("server_ready")):
			debug_battle_ai_commentary("main ai receives direct ready status from server manager")
			battle_main_ai.handle_server_status({
				"state": "ready",
				"message": "Local AI server ready.",
				"pid": int(battle_local_ai_server_manager.get("process_id")),
				"attempt": int(battle_local_ai_server_manager.get("health_attempt"))
			})

	debug_battle_ai_commentary("handler setup complete reason=" + reason + " random_news=" + str(battle_main_ai.random_news_enabled))


func refresh_battle_v2_ui_lane_widgets() -> void:
	# Summary: Keep the active top UI lane as a visual drawing rail only. Timing stays in the pipeline widget.
	if not battle_v2_ui_lane_widgets_enabled:
		return
	if battle_widget_state == null:
		return

	update_battle_v2_ui_lane_widget("battle_v2_player_ui_lane", "player")


func update_battle_v2_ui_lane_widget(widget_id: String, _side: String) -> void:
	# Summary: The lane is a visual rail for drawing/animation, not a text timing widget.
	set_battle_widget_label_text(widget_id + "_title", "")
	set_battle_widget_label_text(widget_id + "_body", "")
	set_battle_widget_label_text(widget_id + "_status", "")


func build_battle_v2_procedural_lane_layer() -> void:
	# Summary: Draw the battle-only procedural route anchors and idle unit avatars over the new lane rails.
	if battle_v2_procedural_lane_layer != null and is_instance_valid(battle_v2_procedural_lane_layer):
		return

	battle_v2_procedural_lane_layer = BattleV2ProceduralLaneLayerScript.new()
	battle_v2_procedural_lane_layer.name = "Battle_V2_Procedural_Lane_Layer"
	battle_v2_procedural_lane_layer.position = Vector2.ZERO
	battle_v2_procedural_lane_layer.size = Vector2(Globals.screen_w, Globals.screen_h)
	battle_v2_procedural_lane_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_v2_procedural_lane_layer.z_index = 35
	battle_v2_procedural_lane_layer.z_as_relative = false
	add_child(battle_v2_procedural_lane_layer)
	store_battle_control("Battle_V2_Procedural_Lane_Layer", battle_v2_procedural_lane_layer)

	if battle_v2_procedural_lane_layer.has_method("setup"):
		battle_v2_procedural_lane_layer.setup({
			"size": Vector2(Globals.screen_w, Globals.screen_h),
			"anchors": build_battle_v2_procedural_anchor_data()
		})

	sync_battle_v2_procedural_lane_layer()


func build_battle_v2_procedural_anchor_data() -> Dictionary:
	var screen_size := Vector2(Globals.screen_w, Globals.screen_h)
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		screen_size = Vector2(1280, 760)

	var player_lane := Rect2(BATTLE_V2_PLAYER_UI_LANE_POS, BATTLE_V2_PLAYER_UI_LANE_SIZE)
	var action_panel := Rect2(BATTLE_V2_ACTION_POS, BATTLE_V2_ACTION_SIZE)
	var pipeline := Rect2(BATTLE_V2_PIPELINE_POS, BATTLE_V2_PIPELINE_SIZE)
	var top_lane_center_y := player_lane.position.y + player_lane.size.y * 0.5
	var player_actor_center := Vector2(player_lane.position.x + BATTLE_V2_PROCEDURAL_ACTOR_EDGE_INSET, top_lane_center_y)
	var enemy_actor_center := Vector2(player_lane.position.x + player_lane.size.x - BATTLE_V2_PROCEDURAL_ACTOR_EDGE_INSET, top_lane_center_y)

	return {
		"screen": Rect2(Vector2.ZERO, screen_size),
		"player_lane": player_lane,
		"enemy_lane": player_lane,
		"player_actor": Rect2(player_actor_center - BATTLE_V2_PROCEDURAL_ACTOR_SIZE * 0.5, BATTLE_V2_PROCEDURAL_ACTOR_SIZE),
		"enemy_actor": Rect2(enemy_actor_center - BATTLE_V2_PROCEDURAL_ACTOR_SIZE * 0.5, BATTLE_V2_PROCEDURAL_ACTOR_SIZE),
		"player_action": Rect2(action_panel.position + Vector2(action_panel.size.x - 58, 40), Vector2(42, max(action_panel.size.y - 80, 72))),
		"todo": Rect2(pipeline.position + Vector2(0, 40), Vector2(pipeline.size.x, max(pipeline.size.y - 80, 80))),
		"player_execute": Rect2(player_actor_center - BATTLE_V2_PROCEDURAL_ACTOR_SIZE * 0.5, BATTLE_V2_PROCEDURAL_ACTOR_SIZE),
		"enemy_execute": Rect2(enemy_actor_center - BATTLE_V2_PROCEDURAL_ACTOR_SIZE * 0.5, BATTLE_V2_PROCEDURAL_ACTOR_SIZE)
	}


func sync_battle_v2_procedural_lane_layer(snapshot: Dictionary = {}) -> void:
	if battle_v2_procedural_lane_layer == null or not is_instance_valid(battle_v2_procedural_lane_layer):
		return

	if battle_v2_procedural_lane_layer.has_method("set_anchor_data"):
		battle_v2_procedural_lane_layer.set_anchor_data(build_battle_v2_procedural_anchor_data())

	var lane_snapshot := snapshot
	if lane_snapshot.is_empty():
		var active_events: Array = []
		if battle_event_manager != null:
			active_events = get_sorted_active_todo_events()
		lane_snapshot = build_battle_v3_pipeline_snapshot(active_events)

	if battle_v2_procedural_lane_layer.has_method("set_todo_snapshot"):
		battle_v2_procedural_lane_layer.set_todo_snapshot(lane_snapshot)

	if battle_v2_procedural_lane_layer.has_method("set_unit_state"):
		battle_v2_procedural_lane_layer.set_unit_state(build_battle_v2_procedural_unit_state())

	if battle_v2_procedural_lane_layer.has_method("set_drone_runtime_packet"):
		battle_v2_procedural_lane_layer.set_drone_runtime_packet(build_battle_v2_drone_runtime_lane_packet())


func pulse_battle_v2_procedural_action(packet: Dictionary) -> void:
	if battle_v2_procedural_lane_layer == null or not is_instance_valid(battle_v2_procedural_lane_layer):
		return
	if not battle_v2_procedural_lane_layer.has_method("pulse_action"):
		return
	battle_v2_procedural_lane_layer.pulse_action(packet)


func push_battle_v2_damage_packet_to_procedural_lane(event_packet: Dictionary, damage_result: Dictionary, explosive_hit: bool) -> void:
	# Summary: Forward resolved damage as a draw-only packet to the procedural lane layer.
	# BattleManager already resolved the truth before this point; the lane layer only paints the result.
	if battle_v2_procedural_lane_layer == null or not is_instance_valid(battle_v2_procedural_lane_layer):
		return
	if not battle_v2_procedural_lane_layer.has_method("pulse_damage"):
		return

	var packet := build_battle_v2_todo_ui_event_summary(event_packet)
	packet["owner_side"] = get_battle_v2_event_owner_side(event_packet)
	packet["source_side"] = get_battle_v2_event_owner_side(event_packet)
	packet["target_side"] = get_battle_v2_event_target_side(event_packet)
	packet["explosive_hit"] = explosive_hit
	packet["shield_damage"] = float(damage_result.get("shield_damage", 0.0))
	packet["hull_damage"] = float(damage_result.get("hull_damage", 0.0))
	packet["overflow_damage"] = float(damage_result.get("overflow_damage", 0.0))
	packet["damage_applied"] = bool(damage_result.get("damage_applied", true))
	packet["duration"] = 0.86 if explosive_hit else 0.62
	packet["tags"] = build_battle_v2_string_list([packet.get("tags", []), ["battle_v2_damage_packet", "procedural_lane_damage_pulse"]])
	packet["labels"] = build_battle_v2_string_list([packet.get("labels", []), ["battle_v2_damage_packet_forwarded_to_lane"]])
	battle_v2_procedural_lane_layer.pulse_damage(packet)


func push_battle_v2_drone_runtime_to_procedural_lane(packet: Dictionary) -> void:
	if battle_v2_procedural_lane_layer == null or not is_instance_valid(battle_v2_procedural_lane_layer):
		return
	if not battle_v2_procedural_lane_layer.has_method("set_drone_runtime_packet"):
		return
	battle_v2_procedural_lane_layer.set_drone_runtime_packet(packet)


func build_battle_v2_drone_runtime_lane_packet(extra_packet: Dictionary = {}) -> Dictionary:
	var drones: Array = []
	var attacks: Array = []
	var expired: Array = []
	var destroyed: Array = []

	if battle_manager_v2 != null and battle_manager_v2.has_method("get_active_drone_runtime_snapshot"):
		var snapshot: Dictionary = battle_manager_v2.get_active_drone_runtime_snapshot()
		drones = get_battle_v2_drone_ui_array(snapshot, "drones")

	if typeof(extra_packet.get("drones", [])) == TYPE_ARRAY and not extra_packet.get("drones", []).is_empty():
		drones = extra_packet.get("drones", [])
	if typeof(extra_packet.get("attacks", [])) == TYPE_ARRAY:
		attacks = extra_packet.get("attacks", [])
	if typeof(extra_packet.get("expired", [])) == TYPE_ARRAY:
		expired = extra_packet.get("expired", [])
	if typeof(extra_packet.get("destroyed", [])) == TYPE_ARRAY:
		destroyed = extra_packet.get("destroyed", [])

	return {
		"battle_id": battle_id,
		"active_count": drones.size(),
		"drones": drones,
		"attacks": attacks,
		"expired": expired,
		"destroyed": destroyed,
		"drone_ui_update_index": int(extra_packet.get("drone_ui_update_index", battle_v2_drone_ui_update_counter)),
		"tags": ["battle_v2_drone_runtime", "active_drone_runtime", "procedural_lane_drone_runtime"],
		"labels": ["battle_v2_drone_runtime_lane_packet"]
	}


func build_battle_v2_procedural_unit_state() -> Dictionary:
	var loaded_data := get_loaded_consumable_item_data()
	var loaded_consumable_id := ""
	if not loaded_data.is_empty():
		loaded_consumable_id = str(loaded_data.get("item_id", loaded_data.get("id", ""))).strip_edges()
	if loaded_consumable_id == "" and player_state_packet != null:
		loaded_consumable_id = get_loadout_item_id(player_state_packet.loaded_consumable)

	var player_loaded_state := get_player_loaded_consumable_state()
	if loaded_consumable_id == "":
		player_loaded_state = "none"
	elif player_loaded_state == "" or player_loaded_state == "none":
		player_loaded_state = "ready"

	var enemy_loaded_consumable_id := ""
	var enemy_loaded_consumable_state := "none"
	if active_enemy is BattleV2UnitAdapter:
		enemy_loaded_consumable_id = get_loadout_item_id(active_enemy.loaded_consumable)
		enemy_loaded_consumable_state = str(active_enemy.loaded_consumable_state).strip_edges().to_lower()
		if enemy_loaded_consumable_id == "":
			enemy_loaded_consumable_state = "none"

	var player_selected_shield_id := get_loadout_item_id(player_state_packet.selected_shield) if player_state_packet != null else ""
	var enemy_selected_shield_id := get_loadout_item_id(active_enemy.selected_shield) if active_enemy is BattleV2UnitAdapter else ""

	return {
		"player": {
			"shield_current": get_unit_float(player_state_packet, "shield_hp_current", 0.0),
			"shield_max": get_unit_shield_max(player_state_packet),
			"shield_power_level": int(player_state_packet.shield_power_level) if player_state_packet != null else 0,
			"shield_has_energy": energy_handler_has_current_energy(energy_handler_v2),
			"shield_state": get_player_shield_visual_state(),
			"selected_shield_id": player_selected_shield_id,
			"good_lock": bool(player_state_packet.player_good_lock) if player_state_packet != null else false,
			"lock_pending": bool(player_state_packet.player_lock_pending) if player_state_packet != null else false,
			"lock_disabled": bool(player_state_packet.player_lock_disabled) if player_state_packet != null else false,
			"loaded_consumable_id": loaded_consumable_id,
			"loaded_consumable_state": player_loaded_state
		},
		"enemy": {
			"shield_current": get_unit_float(active_enemy, "shield_hp_current", 0.0),
			"shield_max": get_unit_shield_max(active_enemy),
			"shield_power_level": int(active_enemy.shield_power_level) if active_enemy is BattleV2UnitAdapter else 0,
			"shield_has_energy": energy_handler_has_current_energy(enemy_energy_handler_v2),
			"shield_state": get_enemy_shield_visual_state(active_enemy),
			"selected_shield_id": enemy_selected_shield_id,
			"good_lock": get_unit_bool(active_enemy, "enemy_good_lock", false),
			"lock_pending": get_unit_bool(active_enemy, "enemy_lock_pending", false),
			"lock_disabled": get_unit_bool(active_enemy, "enemy_lock_disabled", false),
			"loaded_consumable_id": enemy_loaded_consumable_id,
			"loaded_consumable_state": enemy_loaded_consumable_state
		}
	}


func get_next_battle_v2_lane_event(active_events: Array) -> Dictionary:
	# Summary: Pick the soonest active event packet for a lane without mutating EventManager data.
	var best_event: Dictionary = {}
	var best_time := 999999999.0

	for event_packet in active_events:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		var remaining = max(float(event_packet.get("time_remaining", 0.0)), 0.0)
		if best_event.is_empty() or remaining < best_time:
			best_event = event_packet
			best_time = remaining

	return best_event


func apply_battle_v2_legacy_header_visibility_mode() -> void:
	# Summary: Hide the old title/status text now that the top lane widgets own that visual row. Nodes stay alive for existing readers/writers.
	if not battle_v2_hide_legacy_header_widgets_enabled:
		return

	set_battle_canvas_items_visible([
		"Battle_V2_Title",
		"Battle_V2_Status"
	], false)


func apply_battle_v2_legacy_status_visibility_mode() -> void:
	# Summary: Hide only the old root-level player/enemy status visuals after the WidgetBuilder mirrors are built.
	# The old nodes stay alive because other systems still update/read these labels and UI point refs.
	if not battle_v2_hide_legacy_status_widgets_enabled:
		return

	set_battle_canvas_items_visible([
		"Battle_V2_player_Panel",
		"Battle_V2_player_Title",
		"Battle_V2_player_Name",
		"Battle_V2_player_Hull",
		"Battle_V2_player_Shield",
		"Battle_V2_player_Shield_Energy",
		"Battle_V2_player_Lock",
		"Battle_V2_Player_Ammo",
		"Battle_V2_Player_Energy",
		"Battle_V2_Player_Energy_Bar",
		"Battle_V2_enemy_Panel",
		"Battle_V2_enemy_Title",
		"Battle_V2_enemy_Name",
		"Battle_V2_enemy_Hull",
		"Battle_V2_enemy_Shield",
		"Battle_V2_enemy_Shield_Energy",
		"Battle_V2_enemy_Lock",
		"Battle_V2_Enemy_Intent",
		"Battle_V2_Enemy_Energy",
		"Battle_V2_Enemy_Energy_Bar"
	], false)


func apply_battle_v2_legacy_detail_visibility_mode() -> void:
	# Summary: Hide legacy detail panels that are no longer part of the sketch layout. Nodes stay alive for safe logging/updates.
	if not battle_v2_hide_legacy_detail_widgets_enabled:
		return

	set_battle_canvas_items_visible([
		"Battle_V3_Player_Runtime_Panel",
		"Battle_V3_Player_Runtime_Title",
		"Battle_V3_Player_Runtime_1",
		"Battle_V3_Player_Runtime_2",
		"Battle_V3_Player_Runtime_3",
		"Battle_V3_Player_Stats_Panel",
		"Battle_V3_Player_Stats_Title",
		"Battle_V3_Player_Stats_1",
		"Battle_V3_Player_Stats_2",
		"Battle_V3_Player_Stats_3",
		"Battle_V3_Enemy_Runtime_Panel",
		"Battle_V3_Enemy_Runtime_Title",
		"Battle_V3_Enemy_Runtime_1",
		"Battle_V3_Enemy_Runtime_2",
		"Battle_V3_Enemy_Runtime_3",
		"Battle_V3_Enemy_Stats_Panel",
		"Battle_V3_Enemy_Stats_Title",
		"Battle_V3_Enemy_Stats_1",
		"Battle_V3_Enemy_Stats_2",
		"Battle_V3_Enemy_Stats_3",
		"Battle_V2_Log_Panel",
		"Battle_V2_Log_Title",
		"Battle_V2_Log",
		"Battle_V2_Shield_Panel",
		"Battle_V2_Shield_Title",
		"Battle_V2_Shield_Value",
		"Battle_V2_Shield_Meaning",
		"Battle_V2_Shield_Slider",
		"Battle_V2_Shield_Rule_1",
		"Battle_V2_Shield_Rule_2",
		"Battle_V2_Shield_Rule_3"
	], false)


func set_battle_canvas_items_visible(node_names: Array, value: bool) -> void:
	# Summary: Visibility helper for this scene's root-level UI items.
	for node_name in node_names:
		var node := get_node_or_null(str(node_name))
		if node is CanvasItem:
			(node as CanvasItem).visible = value


func store_battle_control(key: String, control: CanvasItem) -> void:
	if control == null or not is_instance_valid(control):
		return
	ensure_battle_widget_state()
	battle_widget_state.controls[key] = control


func store_battle_label(key: String, label: Label) -> void:
	if label == null or not is_instance_valid(label):
		return
	ensure_battle_widget_state()
	battle_widget_state.labels[key] = label
	battle_widget_state.controls[key] = label


func store_battle_button(key: String, button: BaseButton) -> void:
	if button == null or not is_instance_valid(button):
		return
	ensure_battle_widget_state()
	battle_widget_state.buttons[key] = button
	battle_widget_state.controls[key] = button


func store_battle_slider(key: String, slider: Range) -> void:
	if slider == null or not is_instance_valid(slider):
		return
	ensure_battle_widget_state()
	battle_widget_state.sliders[key] = slider
	battle_widget_state.controls[key] = slider


func store_battle_color_rect(key: String, color_rect: ColorRect) -> void:
	if color_rect == null or not is_instance_valid(color_rect):
		return
	ensure_battle_widget_state()
	battle_widget_state.color_rects[key] = color_rect
	battle_widget_state.controls[key] = color_rect


func store_battle_action_ref(key: String, control: CanvasItem) -> void:
	if control == null or not is_instance_valid(control):
		return
	ensure_battle_widget_state()
	battle_widget_state.action_storage[key] = control
	battle_widget_state.controls[key] = control


func store_battle_log_ref(key: String, control: CanvasItem) -> void:
	if control == null or not is_instance_valid(control):
		return
	ensure_battle_widget_state()
	battle_widget_state.log_storage[key] = control
	battle_widget_state.controls[key] = control


func setup_battle_controller_focus_handler() -> void:
	if controller_focus_overlay == null or not is_instance_valid(controller_focus_overlay):
		controller_focus_overlay = ControllerFocusOverlayScript.new()
	controller_focus_overlay.name = "BattleControllerFocusOverlay"
	controller_focus_overlay.z_index = ControllerFocusOverlay.TOP_LAYER_Z
	controller_focus_overlay.z_as_relative = false
	controller_focus_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if controller_focus_overlay.get_parent() == null:
		add_child(controller_focus_overlay)

	if controller_scene_focus == null or not is_instance_valid(controller_scene_focus):
		controller_scene_focus = ControllerSceneListFocusScript.new()
	controller_scene_focus.name = "BattleControllerSceneFocus"
	if controller_scene_focus.get_parent() == null:
		add_child(controller_scene_focus)

	controller_scene_focus.setup({
		"owner_scene": self,
		"overlay": controller_focus_overlay,
		"focus_root": battle_v3_reference_root,
		"focus_items_provider": Callable(self, "get_battle_controller_focus_items"),
		"direct_action_handler": Callable(self, "handle_battle_controller_action"),
		"direct_action_names": [
			"controller_battle_primary",
			"controller_battle_secondary",
			"controller_battle_consumable",
			"controller_battle_consumable_alt",
			"controller_battle_evade"
		]
	})

	if controller_battle_ui_handler == null or not is_instance_valid(controller_battle_ui_handler):
		controller_battle_ui_handler = ControllerBattleSupportUiScript.new()
	controller_battle_ui_handler.name = "BattleControllerSupportUi"
	controller_battle_ui_handler.z_index = 930
	controller_battle_ui_handler.z_as_relative = false
	controller_battle_ui_handler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if controller_battle_ui_handler.get_parent() == null:
		add_child(controller_battle_ui_handler)
	controller_battle_ui_handler.setup({"battle_scene": self})

	move_child(controller_battle_ui_handler, get_child_count() - 1)
	move_child(controller_focus_overlay, get_child_count() - 1)


func get_battle_controller_focus_items() -> Array:
	var items: Array = []
	append_battle_reference_controller_focus_items(items)
	return items


func append_battle_lane_controller_focus_item(items: Array, lane_id: String) -> void:
	var lane_button: Button = battle_v3_exec_buttons.get(lane_id, null) as Button
	append_battle_controller_focus_item(items, "battle_lane_" + lane_id, lane_button)


func append_battle_reference_controller_focus_items(items: Array) -> void:
	if battle_v3_reference_list == null or not is_instance_valid(battle_v3_reference_list):
		return
	for child in battle_v3_reference_list.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if not (child is BattleV3ItemRefButton):
			continue
		var item_button := child as BattleV3ItemRefButton
		var item_id := item_button.item_id.strip_edges()
		if item_id == "":
			continue
		append_battle_controller_focus_item(
			items,
			"battle_ref_" + item_id,
			item_button,
			"button",
			Callable(self, "activate_controller_battle_reference_item").bind(item_button)
		)


func append_battle_controller_focus_item(
	items: Array,
	item_id: String,
	node_value: Variant,
	kind: String = "button",
	activate_callable: Callable = Callable(),
	adjust_callable: Callable = Callable()
) -> void:
	if node_value == null or not is_instance_valid(node_value):
		return
	var item := {
		"item_id": item_id,
		"node": node_value,
		"kind": kind,
		"enabled": true
	}
	if activate_callable.is_valid():
		item["activate_callable"] = activate_callable
	if adjust_callable.is_valid():
		item["adjust_callable"] = adjust_callable
	items.append(item)


func activate_controller_battle_reference_item(item_button: Variant) -> void:
	if item_button == null or not is_instance_valid(item_button):
		return
	if not (item_button is BattleV3ItemRefButton):
		return

	var ref_button := item_button as BattleV3ItemRefButton
	var item_id := ref_button.item_id.strip_edges()
	var lane_id := ref_button.battle_tab.strip_edges().to_lower()
	if item_id == "" or lane_id == "":
		return

	_on_battle_v3_slot_item_dropped(lane_id, item_id, ref_button.item_data.duplicate(true))


func handle_battle_controller_action(action_name: String) -> void:
	match action_name:
		"controller_battle_primary":
			press_battle_controller_button(battle_v3_exec_buttons.get(TAB_PRIMARY, null))
		"controller_battle_secondary":
			press_battle_controller_button(battle_v3_exec_buttons.get(TAB_SECONDARY, null))
		"controller_battle_consumable":
			activate_controller_consumable_index(0)
		"controller_battle_consumable_alt":
			activate_controller_consumable_index(1)
		"controller_battle_evade":
			press_battle_controller_button(player_evade_button)


func activate_controller_consumable_index(index: int) -> void:
	var consumable_buttons := get_controller_consumable_reference_buttons()
	if index >= 0 and index < consumable_buttons.size():
		var consumable_button := consumable_buttons[index] as BattleV3ItemRefButton
		if should_controller_select_consumable_before_press(consumable_button):
			activate_controller_battle_reference_item(consumable_button)
	elif index > 0:
		return

	press_battle_controller_button(battle_v3_exec_buttons.get(TAB_CONSUMABLE, null))


func should_controller_select_consumable_before_press(item_button: BattleV3ItemRefButton) -> bool:
	if item_button == null or not is_instance_valid(item_button):
		return false

	var requested_id := item_button.item_id.strip_edges()
	if requested_id == "":
		return false

	var consumable_state := get_player_loaded_consumable_state()
	var loaded_id := get_player_loaded_consumable_id()
	if loaded_id == requested_id and consumable_state in ["ready", "loading", "executing"]:
		return false
	if consumable_state == "loading" or consumable_state == "executing":
		return false
	return true


func get_controller_consumable_reference_count() -> int:
	return get_controller_consumable_reference_buttons().size()


func get_controller_consumable_reference_buttons() -> Array:
	var buttons: Array = []
	if battle_v3_reference_list == null or not is_instance_valid(battle_v3_reference_list):
		return buttons
	for child in battle_v3_reference_list.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if not (child is BattleV3ItemRefButton):
			continue
		var item_button := child as BattleV3ItemRefButton
		if item_button.battle_tab.strip_edges().to_lower() != TAB_CONSUMABLE:
			continue
		buttons.append(item_button)
	return buttons


func process_battle_controller_shield_hold() -> void:
	process_battle_controller_shield_button(
		"controller_battle_shield_min",
		false
	)
	process_battle_controller_shield_button(
		"controller_battle_shield_max",
		true
	)


func process_battle_controller_shield_button(action_name: String, shield_up: bool) -> void:
	if not InputMap.has_action(action_name):
		return

	var pressed := Input.is_action_pressed(action_name)
	var now := Time.get_ticks_msec()
	if action_name == "controller_battle_shield_min":
		if pressed and not controller_l1_shield_was_pressed:
			controller_l1_shield_was_pressed = true
			controller_l1_shield_pressed_msec = now
			controller_l1_shield_hold_applied = false
		elif pressed and not controller_l1_shield_hold_applied and now - controller_l1_shield_pressed_msec >= controller_shield_hold_threshold_msec:
			set_battle_controller_shield_value(0)
			controller_l1_shield_hold_applied = true
		elif not pressed and controller_l1_shield_was_pressed:
			if not controller_l1_shield_hold_applied:
				adjust_battle_controller_shield_value(-1)
			controller_l1_shield_was_pressed = false
			controller_l1_shield_hold_applied = false
		return

	if action_name == "controller_battle_shield_max":
		if pressed and not controller_r1_shield_was_pressed:
			controller_r1_shield_was_pressed = true
			controller_r1_shield_pressed_msec = now
			controller_r1_shield_hold_applied = false
		elif pressed and not controller_r1_shield_hold_applied and now - controller_r1_shield_pressed_msec >= controller_shield_hold_threshold_msec:
			set_battle_controller_shield_value(4)
			controller_r1_shield_hold_applied = true
		elif not pressed and controller_r1_shield_was_pressed:
			if not controller_r1_shield_hold_applied:
				adjust_battle_controller_shield_value(1)
			controller_r1_shield_was_pressed = false
			controller_r1_shield_hold_applied = false


func press_battle_controller_button(button_value: Variant) -> bool:
	if button_value == null or not is_instance_valid(button_value):
		return false
	if not (button_value is BaseButton):
		return false
	var button := button_value as BaseButton
	if button.disabled or not button.is_visible_in_tree():
		return false
	button.emit_signal("pressed")
	return true


func set_battle_controller_shield_value(value: int) -> void:
	var slider_value := int(clamp(value, 0, 4))
	var target_slider: Range = action_shield_slider if action_shield_slider != null and is_instance_valid(action_shield_slider) else shield_slider
	if target_slider != null and is_instance_valid(target_slider):
		target_slider.set_value_no_signal(slider_value)
	on_shield_slider_changed(float(slider_value))


func adjust_battle_controller_shield_value(delta: int) -> void:
	var current_value := 0
	if action_shield_slider != null and is_instance_valid(action_shield_slider):
		current_value = int(action_shield_slider.value)
	elif player_state_packet != null:
		current_value = int(player_state_packet.shield_power_level)
	set_battle_controller_shield_value(current_value + delta)


func register_battle_v3_pipeline_widget_refs() -> void:
	# Summary: Register the existing keystone pipeline's static visual nodes with WidgetSpec without changing TODO timing or intervention logic.
	if battle_v3_pipeline_widget == null or not is_instance_valid(battle_v3_pipeline_widget):
		return
	ensure_battle_widget_state()
	store_battle_control("Battle_V3_Pipeline_Widget", battle_v3_pipeline_widget)

	if not battle_v3_pipeline_widget.has_method("get_widget_spec_refs"):
		return

	var refs = battle_v3_pipeline_widget.get_widget_spec_refs()
	if typeof(refs) != TYPE_DICTIONARY:
		return

	var controls = refs.get("controls", {})
	if typeof(controls) == TYPE_DICTIONARY:
		for key in controls.keys():
			var node = controls[key]
			if node is CanvasItem:
				store_battle_control(str(key), node)

	var color_rects = refs.get("color_rects", {})
	if typeof(color_rects) == TYPE_DICTIONARY:
		for key in color_rects.keys():
			var node = color_rects[key]
			if node is ColorRect:
				store_battle_color_rect(str(key), node)

	var labels = refs.get("labels", {})
	if typeof(labels) == TYPE_DICTIONARY:
		for key in labels.keys():
			var node = labels[key]
			if node is Label:
				store_battle_label(str(key), node)


func setup_battle_widget_spec_runtime() -> void:
	ensure_battle_widget_state()

	if battle_color_handler == null or not is_instance_valid(battle_color_handler):
		battle_color_handler = Color_Handler.new()
		battle_color_handler.name = "battle_v2_color_handler"
		add_child(battle_color_handler)
		battle_color_handler.setup(battle_widget_state)

	if battle_decorative_ui == null or not is_instance_valid(battle_decorative_ui):
		battle_decorative_ui = DecorativeUIScript.new()
		battle_decorative_ui.name = "battle_v2_decorative_ui"
		add_child(battle_decorative_ui)
		battle_decorative_ui.build_hostile_contact_alert()
		battle_decorative_ui.build_receiving_message_alert()
		build_battle_decorative_overlays()

	if battle_widget_spec_ui == null or not is_instance_valid(battle_widget_spec_ui):
		battle_widget_spec_ui = WidgetSpecUiScript.new()
		battle_widget_spec_ui.name = "battle_v2_widget_spec_ui"
		add_child(battle_widget_spec_ui)

	battle_widget_spec_ui.setup(
		null,
		null,
		energy_handler_v2,
		battle_widget_state,
		battle_decorative_ui,
		battle_aurora_bg,
		battle_color_handler
	)
	battle_widget_spec_ui.widget_runtime_enabled = true
	battle_widget_spec_ui.widget_runtime_test_mode = false
	battle_widget_spec_ui.build_onscreen_widget_runtime_data()


func build_battle_decorative_overlays() -> void:
	# Summary: Legacy decorative/procedural widget connection lining is disabled during the Battle V2 widget overhaul.
	# The new WidgetBuilder/WidgetSpec widgets own their own theme behavior; these old pulse wraps
	# are kept optional but hidden so they do not draw stale outlines over the new layout.
	if not battle_v2_procedural_connections_enabled:
		return
	if battle_decorative_ui == null or not is_instance_valid(battle_decorative_ui):
		return

	register_battle_pulse_overlay(
		"battle_player_living_overlay",
		battle_decorative_ui.create_pulse_overlay(
			BATTLE_V2_PLAYER_STATUS_MIRROR_POS,
			BATTLE_V2_UNIT_STATUS_MIRROR_SIZE,
			"battle_player_living_overlay",
			Color(0.0, 0.72, 1.0, 0.08)
		)
	)
	register_battle_pulse_overlay(
		"battle_enemy_living_overlay",
		battle_decorative_ui.create_pulse_overlay(
			BATTLE_V2_ENEMY_STATUS_MIRROR_POS,
			BATTLE_V2_UNIT_STATUS_MIRROR_SIZE,
			"battle_enemy_living_overlay",
			Color(1.0, 0.12, 0.08, 0.08)
		)
	)
	register_battle_pulse_overlay(
		"battle_pipeline_living_overlay",
		battle_decorative_ui.create_pulse_overlay(
			BATTLE_V2_PIPELINE_POS,
			BATTLE_V2_PIPELINE_SIZE,
			"battle_pipeline_living_overlay",
			Color(0.75, 0.24, 1.0, 0.07)
		)
	)
	register_battle_pulse_overlay(
		"battle_action_living_overlay",
		battle_decorative_ui.create_pulse_overlay(
			BATTLE_V2_ACTION_POS,
			BATTLE_V2_ACTION_SIZE,
			"battle_action_living_overlay",
			Color(0.18, 0.64, 1.0, 0.07)
		)
	)
	if battle_decorative_ui.has_method("set_pulse_overlays_visible"):
		battle_decorative_ui.set_pulse_overlays_visible(Globals.show_decorative_overlays and battle_v2_show_legacy_lining_enabled)


func register_battle_pulse_overlay(key: String, overlay: Control) -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	overlay.z_index = 120
	overlay.z_as_relative = false
	overlay.visible = battle_v2_show_legacy_lining_enabled
	store_battle_control(key, overlay)


func update_battle_shared_visual_runtime(delta: float) -> void:
	if battle_v2_procedural_connections_enabled and battle_decorative_ui != null and is_instance_valid(battle_decorative_ui):
		battle_decorative_ui.update_decorative_ui(delta)

	if battle_widget_spec_ui != null and is_instance_valid(battle_widget_spec_ui):
		battle_widget_spec_ui.process_onscreen_widget_runtime(delta)


func build_scene_shell() -> void:
	# Summary: Create the Battle V2 static UI shell, label lookup dictionary, and test action rows.
	if Globals.print_priority_3:
		print("Building Battle V2 scene shell.")

	# ------------------------------------------------------
	# Shared background stack: same family as main mode/NPC,
	# then the battle-only procedural layer above it.
	# ------------------------------------------------------
	build_battle_v2_shared_background()
	build_battle_v2_background_draw_layer()

	# ------------------------------------------------------
	# Scene title. Battle exit is now AMI-owned and automatic
	# after a terminal combat outcome; no player-facing return
	# button is created in battle mode.
	# ------------------------------------------------------
	title_label = make_label(
		"Battle_V2_Title",
		"Combat Link",
		Vector2(40, 25),
		Vector2(520, 34),
		26
	)

	status_label = make_label(
		"Battle_V2_Status",
		"AMI threat response channel active.",
		Vector2(40, 58),
		Vector2(740, 24),
		14
	)

	# ------------------------------------------------------
	# Main battle UI zones.
	# ------------------------------------------------------
	build_unit_status_panel(
		"player",
		"PLAYER",
		Vector2(40, 95),
		Vector2(370, 185)
	)
	build_unit_status_panel(
		"enemy",
		"ENEMY",
		Vector2(890, 95),
		Vector2(370, 185)
	)
	build_battle_v3_pipeline_widget(BATTLE_V2_PIPELINE_POS, BATTLE_V2_PIPELINE_SIZE)
	build_shield_slider_panel(Vector2(180, 300), Vector2(230, 190))
	build_battle_v3_runtime_window("player", "PLAYER RUNTIME", Vector2(40, 500), Vector2(230, 115))
	build_battle_v3_stats_window("player", "PLAYER STATS", Vector2(40, 625), Vector2(230, 115))
	build_battle_v3_runtime_window("enemy", "ENEMY RUNTIME", Vector2(900, 300), Vector2(360, 90))
	build_battle_v3_stats_window("enemy", "ENEMY STATS", Vector2(900, 400), Vector2(360, 90))
	build_action_widget(BATTLE_V2_ACTION_POS, BATTLE_V2_ACTION_SIZE)
	build_battle_v3_reference_widget(BATTLE_V2_REFERENCE_POS, BATTLE_V2_REFERENCE_SIZE)
	build_battle_log_panel(BATTLE_V2_LOG_POS, BATTLE_V2_LOG_SIZE)


func build_battle_v2_shared_background() -> void:
	# Summary: Use the same background family as main mode/NPC, with battle-specific aurora tuning.
	if battle_background_root != null and is_instance_valid(battle_background_root):
		return

	battle_background_root = Control.new()
	battle_background_root.name = "Battle_V2_Background_Root"
	battle_background_root.position = Vector2.ZERO
	battle_background_root.size = Vector2(Globals.screen_w, Globals.screen_h)
	battle_background_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_background_root.z_index = -120
	battle_background_root.z_as_relative = false
	add_child(battle_background_root)
	store_battle_control("battle_background_root", battle_background_root)

	battle_background_texture = TextureRect.new()
	battle_background_texture.name = "Battle_V2_Blue_Scifi_Background"
	battle_background_texture.texture = BATTLE_AURORA_TEXTURE
	battle_background_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	battle_background_texture.offset_left = 0.0
	battle_background_texture.offset_top = 0.0
	battle_background_texture.offset_right = 0.0
	battle_background_texture.offset_bottom = 0.0
	battle_background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	battle_background_texture.stretch_mode = TextureRect.STRETCH_SCALE
	battle_background_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_background_texture.modulate = Color(0.62, 0.78, 1.0, 0.72)
	battle_background_root.add_child(battle_background_texture)
	store_battle_control("battle_background_texture", battle_background_texture)

	battle_background_wash = ColorRect.new()
	battle_background_wash.name = "Battle_V2_Background_Wash"
	battle_background_wash.color = Color(0.005, 0.010, 0.030, 0.54)
	battle_background_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	battle_background_wash.size = battle_background_root.size
	battle_background_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_background_root.add_child(battle_background_wash)

	var aurora_container := Control.new()
	aurora_container.name = "Battle_V2_Aurora_Container"
	aurora_container.position = Globals.aurora_pos
	aurora_container.size = Globals.aurora_size
	aurora_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_background_root.add_child(aurora_container)
	store_battle_control("battle_aurora_container", aurora_container)

	battle_aurora_bg = AuroraBrainBackgroundScript.new()
	battle_aurora_bg.name = "Battle_V2_Aurora_Background"
	battle_aurora_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	battle_aurora_bg.node_count = 54
	# Procedural aurora connections are disabled for the sandbox layout pass.
	# Keep the background node alive, but prevent it from drawing connection lines.
	battle_aurora_bg.connection_distance = 0.0 if not battle_v2_procedural_connections_enabled else 205.0
	battle_aurora_bg.node_radius = 2.6
	battle_aurora_bg.pulse_speed = 2.6
	battle_aurora_bg.drift_speed = 15.0
	battle_aurora_bg.line_color = Color(0.12, 0.72, 1.0, 0.0 if not battle_v2_procedural_connections_enabled else 0.18)
	battle_aurora_bg.node_color = Color(0.48, 0.92, 1.0, 0.78)
	battle_aurora_bg.glow_color = Color(0.70, 0.20, 1.0, 0.055)
	battle_aurora_bg.modulation_speed = 1.08
	battle_aurora_bg.modulation_color_a = Color(0.30, 0.68, 1.0, 0.50)
	battle_aurora_bg.modulation_color_b = Color(1.0, 0.18, 0.12, 0.38)
	aurora_container.add_child(battle_aurora_bg)
	store_battle_control("battle_aurora_bg", battle_aurora_bg)


func build_battle_v2_background_draw_layer() -> void:
	# Summary: Build the procedural backfield layer that sits above the raw battle background and below widgets.
	if not battle_v2_background_draw_layer_enabled:
		if battle_v2_background_draw_layer != null and is_instance_valid(battle_v2_background_draw_layer):
			battle_v2_background_draw_layer.visible = false
		return
	if battle_v2_background_draw_layer != null and is_instance_valid(battle_v2_background_draw_layer):
		battle_v2_background_draw_layer.visible = true
		return
	battle_v2_background_draw_layer = null

	battle_v2_background_draw_layer = BattleV2BackgroundDrawLayerScript.new()
	battle_v2_background_draw_layer.name = "Battle_V2_Background_Draw_Layer"
	battle_v2_background_draw_layer.position = Vector2.ZERO
	battle_v2_background_draw_layer.size = Vector2(Globals.screen_w, Globals.screen_h)
	battle_v2_background_draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_v2_background_draw_layer.z_index = -20
	battle_v2_background_draw_layer.z_as_relative = false
	add_child(battle_v2_background_draw_layer)
	store_battle_control("battle_v2_background_draw_layer", battle_v2_background_draw_layer)

	if battle_v2_background_draw_layer.has_method("setup"):
		battle_v2_background_draw_layer.setup({
			"size": Vector2(Globals.screen_w, Globals.screen_h),
			"position_data": build_battle_v2_background_position_data()
		})


func sync_battle_v2_background_draw_layer(packet: Dictionary) -> void:
	# Summary: Feed visual-only header state into the procedural background layer.
	if not battle_v2_background_draw_layer_enabled:
		return
	if battle_v2_background_draw_layer == null or not is_instance_valid(battle_v2_background_draw_layer):
		return
	if battle_v2_background_draw_layer.has_method("set_position_data"):
		battle_v2_background_draw_layer.set_position_data(build_battle_v2_background_position_data())
	if battle_v2_background_draw_layer.has_method("set_header_state"):
		battle_v2_background_draw_layer.set_header_state(packet)


func build_battle_v2_background_position_data() -> Dictionary:
	# Summary: Scene-owned point map for visual-only background drawing.
	var screen_size := Vector2(Globals.screen_w, Globals.screen_h)
	var data := {
		"scene_top_layer": {
			"position": Vector2.ZERO,
			"size": screen_size,
			"purpose": "battle scene screen area"
		},
		"battle_background_draw_layer": {
			"position": Vector2.ZERO,
			"size": screen_size,
			"purpose": "behind-widgets procedural battle background"
		},
		"battle_background_root": {
			"position": Vector2.ZERO,
			"size": screen_size,
			"purpose": "shared blue-scifi and aurora backing"
		},
		"battle_aurora_background": {
			"position": Globals.aurora_pos,
			"size": Globals.aurora_size,
			"purpose": "animated aurora brain field"
		},
		"center_stage": {
			"position": BATTLE_V2_PIPELINE_POS,
			"size": BATTLE_V2_PIPELINE_SIZE,
			"purpose": "center conflict and entanglement field"
		}
	}

	add_battle_v2_background_control_point(data, "player_panel", get_node_or_null("Battle_V2_player_Panel"), Vector2(40, 95), Vector2(370, 185), "player-side widget field")
	add_battle_v2_background_control_point(data, "enemy_panel", get_node_or_null("Battle_V2_enemy_Panel"), Vector2(890, 95), Vector2(370, 185), "enemy-side widget field")
	return data


func add_battle_v2_background_control_point(
	data: Dictionary,
	point_id: String,
	node: Node,
	fallback_position: Vector2,
	fallback_size: Vector2,
	purpose: String
) -> void:
	# Summary: Store actual Control position/size when the node exists, with scene-owned fallback coordinates.
	if node is Control:
		var control := node as Control
		data[point_id] = {
			"position": control.position,
			"size": control.size,
			"purpose": purpose
		}
		return

	data[point_id] = {
		"position": fallback_position,
		"size": fallback_size,
		"purpose": purpose + " fallback"
	}


func build_battle_v2_ui_position_data() -> Dictionary:
	# Summary: Build the scene-owned point map used by top-layer battle UI decorations.
	var helper = UIHandlerHelpersScript.new()
	return helper.build_position_data_from_controls(
		get_battle_v2_ui_point_specs(),
		get_battle_v2_ui_control_refs()
	)


func refresh_battle_v2_ui_handler_points(force_refresh: bool = false) -> void:
	# Summary: Keep the UI event handler aligned to the current scene layout without resetting it every frame.
	if not battle_v2_ui_handler_enabled:
		return
	if battle_v2_ui_handler == null:
		return
	if not battle_v2_ui_handler.has_method("set_position_data"):
		return

	var position_data := build_battle_v2_ui_position_data()
	var new_signature := build_battle_v2_ui_position_signature(position_data)
	if not force_refresh and new_signature == battle_v2_ui_position_signature:
		return

	battle_v2_ui_position_signature = new_signature
	battle_v2_ui_handler.set_position_data(position_data)


func build_battle_v2_ui_position_signature(position_data: Dictionary) -> String:
	# Summary: Make a compact layout signature from point ids, positions, and sizes.
	var parts: Array = []
	var point_ids := position_data.keys()
	point_ids.sort()
	for point_id in point_ids:
		if typeof(position_data.get(point_id, {})) != TYPE_DICTIONARY:
			continue
		var point: Dictionary = position_data.get(point_id, {})
		var point_position: Vector2 = point.get("position", Vector2.ZERO)
		var point_size: Vector2 = point.get("size", Vector2.ZERO)
		parts.append(
			str(point_id)
			+ ":"
			+ str(int(round(point_position.x)))
			+ ","
			+ str(int(round(point_position.y)))
			+ ","
			+ str(int(round(point_size.x)))
			+ ","
			+ str(int(round(point_size.y)))
		)
	return "|".join(parts)


func get_battle_v2_ui_control_refs() -> Dictionary:
	# Summary: Gather actual Control refs so effects use current widget positions when available.
	return {
		"battle_background_root": battle_background_root,
		"battle_aurora_background": battle_aurora_bg,
		"battle_background_draw_layer": battle_v2_background_draw_layer,
		"player_panel": get_node_or_null("Battle_V2_player_Panel"),
		"player_hp_box": battle_ui_labels.get("player_hull", null),
		"player_shield_box": battle_ui_labels.get("player_shield", null),
		"player_energy_box": battle_ui_labels.get("player_energy", null),
		"player_energy_bar": player_energy_bar_root,
		"player_runtime_panel": get_node_or_null("Battle_V3_Player_Runtime_Panel"),
		"player_stats_panel": get_node_or_null("Battle_V3_Player_Stats_Panel"),
		"enemy_panel": get_node_or_null("Battle_V2_enemy_Panel"),
		"enemy_hp_box": battle_ui_labels.get("enemy_hull", null),
		"enemy_shield_box": battle_ui_labels.get("enemy_shield", null),
		"enemy_energy_box": battle_ui_labels.get("enemy_energy", null),
		"enemy_energy_bar": enemy_energy_bar_root,
		"enemy_runtime_panel": get_node_or_null("Battle_V3_Enemy_Runtime_Panel"),
		"enemy_stats_panel": get_node_or_null("Battle_V3_Enemy_Stats_Panel"),
		"center_stage": battle_v3_pipeline_widget,
		"battle_v3_pipeline": battle_v3_pipeline_widget,
		"todo_panel": battle_v3_pipeline_widget,
		"todo_next_row": battle_v3_pipeline_widget,
		"todo_stack": battle_v3_pipeline_widget,
		"shield_panel": get_node_or_null("Battle_V2_Shield_Panel"),
		"shield_slider": shield_slider,
		"action_panel": get_node_or_null("Battle_V2_Action_Panel"),
		"action_button_stack": action_body_root,
		"primary_action_button": battle_v3_exec_buttons.get(TAB_PRIMARY, null),
		"secondary_action_button": battle_v3_exec_buttons.get(TAB_SECONDARY, null),
		"consumable_action_button": battle_v3_exec_buttons.get(TAB_CONSUMABLE, null),
		"evade_button": player_evade_button,
		"battle_v3_reference_panel": battle_v3_reference_root,
		"battle_v3_reference_list": battle_v3_reference_list,
		"battle_log": get_node_or_null("Battle_V2_Log_Panel"),
		"battle_log_text": log_label
	}


func get_battle_v2_ui_point_specs() -> Dictionary:
	# Summary: Explicit decoration contract for Battle V2 UI effects and future initiates.
	var screen_size := Vector2(Globals.screen_w, Globals.screen_h)
	return {
		"scene_top_layer": make_battle_v2_ui_point(Vector2.ZERO, screen_size, "full-screen battle UI overlay root"),
		"battle_background_root": make_battle_v2_ui_point(Vector2.ZERO, screen_size, "shared blue-scifi and aurora backing", "battle_background_root"),
		"battle_aurora_background": make_battle_v2_ui_point(Globals.aurora_pos, Globals.aurora_size, "animated aurora brain field", "battle_aurora_background"),
		"battle_background_draw_layer": make_battle_v2_ui_point(Vector2.ZERO, screen_size, "behind-widgets procedural background", "battle_background_draw_layer"),
		"player_panel": make_battle_v2_ui_point(Vector2(40, 95), Vector2(370, 185), "player status widget", "player_panel"),
		"player_hp_box": make_battle_v2_ui_point(Vector2(54, 151), Vector2(342, 20), "player hull text and hp effects", "player_hp_box"),
		"player_shield_box": make_battle_v2_ui_point(Vector2(54, 172), Vector2(342, 20), "player shield text and shield effects", "player_shield_box"),
		"player_energy_box": make_battle_v2_ui_point(Vector2(54, 235), Vector2(342, 18), "player energy text", "player_energy_box"),
		"player_energy_bar": make_battle_v2_ui_point(Vector2(54, 271), Vector2(342, 7), "player energy bar", "player_energy_bar"),
		"player_damage_float": make_battle_v2_ui_point(Vector2(220, 146), Vector2(160, 44), "player damage or recovery float text", "player_panel"),
		"player_drone_anchor": make_battle_v2_ui_point(Vector2(430, 305), Vector2(72, 72), "player auto attack drone parking orbit", "player_drone_anchor"),
		"player_runtime_panel": make_battle_v2_ui_point(Vector2(40, 500), Vector2(230, 115), "player runtime status window", "player_runtime_panel"),
		"player_stats_panel": make_battle_v2_ui_point(Vector2(40, 625), Vector2(230, 115), "player stats status window", "player_stats_panel"),
		"enemy_panel": make_battle_v2_ui_point(Vector2(890, 95), Vector2(370, 185), "enemy status widget", "enemy_panel"),
		"enemy_hp_box": make_battle_v2_ui_point(Vector2(904, 151), Vector2(342, 20), "enemy hull text and hp effects", "enemy_hp_box"),
		"enemy_shield_box": make_battle_v2_ui_point(Vector2(904, 172), Vector2(342, 20), "enemy shield text and shield effects", "enemy_shield_box"),
		"enemy_energy_box": make_battle_v2_ui_point(Vector2(904, 254), Vector2(342, 18), "enemy energy text", "enemy_energy_box"),
		"enemy_energy_bar": make_battle_v2_ui_point(Vector2(904, 271), Vector2(342, 7), "enemy energy bar", "enemy_energy_bar"),
		"enemy_damage_float": make_battle_v2_ui_point(Vector2(920, 146), Vector2(160, 44), "enemy damage or recovery float text", "enemy_panel"),
		"enemy_drone_anchor": make_battle_v2_ui_point(Vector2(778, 305), Vector2(72, 72), "enemy auto attack drone parking orbit", "enemy_drone_anchor"),
		"enemy_runtime_panel": make_battle_v2_ui_point(Vector2(900, 300), Vector2(360, 90), "enemy runtime status window", "enemy_runtime_panel"),
		"enemy_stats_panel": make_battle_v2_ui_point(Vector2(900, 400), Vector2(360, 90), "enemy stats status window", "enemy_stats_panel"),
		"center_stage": make_battle_v2_ui_point(BATTLE_V2_PIPELINE_POS, BATTLE_V2_PIPELINE_SIZE, "center battle event stage", "center_stage"),
		"battle_v3_pipeline": make_battle_v2_ui_point(BATTLE_V2_PIPELINE_POS, BATTLE_V2_PIPELINE_SIZE, "Battle V3 pipeline widget", "battle_v3_pipeline"),
		"todo_panel": make_battle_v2_ui_point(BATTLE_V2_PIPELINE_POS, BATTLE_V2_PIPELINE_SIZE, "active and completed TODO display", "todo_panel"),
		"todo_next_row": make_battle_v2_ui_point(BATTLE_V2_PIPELINE_POS + Vector2(10, 30), Vector2(BATTLE_V2_PIPELINE_SIZE.x - 20, 45), "next completing TODO region", "todo_next_row"),
		"todo_stack": make_battle_v2_ui_point(BATTLE_V2_PIPELINE_POS + Vector2(10, 75), Vector2(BATTLE_V2_PIPELINE_SIZE.x - 20, max(BATTLE_V2_PIPELINE_SIZE.y - 105, 1)), "remaining TODO stack region", "todo_stack"),
		"shield_panel": make_battle_v2_ui_point(BATTLE_V2_ACTION_POS + Vector2(10, 186), Vector2(BATTLE_V2_ACTION_SIZE.x - 20, 48), "shield power control inside action widget", "shield_panel"),
		"shield_slider": make_battle_v2_ui_point(BATTLE_V2_ACTION_POS + BATTLE_V2_ACTION_SHIELD_SLIDER_OFFSET, BATTLE_V2_ACTION_SHIELD_SLIDER_SIZE, "shield power slider inside action widget", "shield_slider"),
		"action_panel": make_battle_v2_ui_point(BATTLE_V2_ACTION_POS, BATTLE_V2_ACTION_SIZE, "player action widget", "action_panel"),
		"action_button_stack": make_battle_v2_ui_point(BATTLE_V2_ACTION_POS + Vector2(10, 38), BATTLE_V2_ACTION_SIZE - Vector2(20, 48), "current action rows", "action_button_stack"),
		"primary_action_button": make_battle_v2_ui_point(BATTLE_V2_ACTION_POS + Vector2(182, 38), Vector2(93, 27), "primary execute button", "primary_action_button"),
		"secondary_action_button": make_battle_v2_ui_point(BATTLE_V2_ACTION_POS + Vector2(182, 69), Vector2(93, 27), "secondary execute button", "secondary_action_button"),
		"consumable_action_button": make_battle_v2_ui_point(BATTLE_V2_ACTION_POS + Vector2(182, 131), Vector2(93, 27), "consumable execute button", "consumable_action_button"),
		"evade_button": make_battle_v2_ui_point(BATTLE_V2_ACTION_POS + Vector2(10, 162), Vector2(265, 24), "player evade action", "evade_button"),
		"battle_v3_reference_panel": make_battle_v2_ui_point(BATTLE_V2_REFERENCE_POS, BATTLE_V2_REFERENCE_SIZE, "battle item reference panel", "battle_v3_reference_panel"),
		"battle_v3_reference_list": make_battle_v2_ui_point(BATTLE_V2_REFERENCE_POS + Vector2(10, 38), BATTLE_V2_REFERENCE_SIZE - Vector2(20, 48), "battle item reference list", "battle_v3_reference_list"),
		"battle_log": make_battle_v2_ui_point(BATTLE_V2_LOG_POS, BATTLE_V2_LOG_SIZE, "battle log widget", "battle_log"),
		"battle_log_text": make_battle_v2_ui_point(BATTLE_V2_LOG_POS + Vector2(12, 42), BATTLE_V2_LOG_SIZE - Vector2(24, 54), "battle log text area", "battle_log_text")
	}


func make_battle_v2_ui_point(position: Vector2, point_size: Vector2, purpose: String, control_key: String = "") -> Dictionary:
	var point := {
		"position": position,
		"size": point_size,
		"purpose": purpose
	}
	if control_key.strip_edges() != "":
		point["control_key"] = control_key.strip_edges()
	return point


func setup_battle_v2_ui_handler() -> void:
	# Summary: Create the top-layer Battle V2 UI event handler for future visual and sound routes.
	# Disabled during the sandbox UI overhaul because BattleV2UIHandler owns legacy
	# procedural top-layer play. Keep the report functions alive but no-op them.
	if not battle_v2_ui_handler_enabled:
		if battle_v2_ui_handler != null and is_instance_valid(battle_v2_ui_handler):
			battle_v2_ui_handler.visible = false
			battle_v2_ui_handler.set_process(false)
			battle_v2_ui_handler.set_physics_process(false)
		battle_v2_ui_handler = null
		battle_v2_ui_position_signature = ""
		return
	if battle_v2_ui_handler != null:
		return

	battle_v2_ui_handler = BattleV2UIHandlerScript.new()
	battle_v2_ui_handler.name = "Battle_V2_UI_Handler"
	add_child(battle_v2_ui_handler)
	var position_data := build_battle_v2_ui_position_data()
	battle_v2_ui_position_signature = build_battle_v2_ui_position_signature(position_data)
	if battle_v2_ui_handler.has_method("setup"):
		battle_v2_ui_handler.setup({
			"battle_id": battle_id,
			"battle_scene": self,
			"battle_ui_labels": battle_ui_labels,
			"battle_ui_points": position_data,
			"show_battle_hud_energy_frames": true
		})
	move_child(battle_v2_ui_handler, get_child_count() - 1)


func make_label(label_name: String, text: String, pos: Vector2, size: Vector2, font_size: int) -> Label:
	# Summary: Create a scene label using the Battle V2 visual defaults.
	var label: Label = Label.new()
	label.name = label_name
	label.text = text
	label.position = pos
	label.size = size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	store_battle_label(label_name, label)
	return label


func make_button(button_name: String, text: String, pos: Vector2, size: Vector2) -> Button:
	# Summary: Create a scene button using the Battle V2 visual defaults.
	var button: Button = Button.new()
	button.name = button_name
	button.text = text
	button.position = pos
	button.size = size
	button.add_theme_font_size_override("font_size", 13)
	add_child(button)
	store_battle_button(button_name, button)
	return button


func make_panel(panel_name: String, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	# Summary: Create a flat square-backed UI panel for Battle V2.
	var panel: ColorRect = ColorRect.new()
	panel.name = panel_name
	panel.position = pos
	panel.size = size
	panel.color = color
	add_child(panel)
	store_battle_color_rect(panel_name, panel)
	return panel


func build_unit_status_panel(unit_key: String, title: String, pos: Vector2, size: Vector2) -> void:
	# Summary: Build player or enemy status labels and store them in the UI lookup dictionary.
	if Globals.print_priority_3:
		print("Building Battle V2 unit panel: ", unit_key)

	# ------------------------------------------------------
	# Unit panel background.
	# ------------------------------------------------------
	make_panel(
		"Battle_V2_" + unit_key + "_Panel",
		pos,
		size,
		Color(0.05, 0.07, 0.11, 0.95)
	)

	# ------------------------------------------------------
	# Unit labels are stored by semantic key for later updates.
	# ------------------------------------------------------
	battle_ui_labels[unit_key + "_title"] = make_label(
		"Battle_V2_" + unit_key + "_Title",
		title,
		pos + Vector2(14, 10),
		Vector2(size.x - 28, 22),
		16
	)
	battle_ui_labels[unit_key + "_name"] = make_label(
		"Battle_V2_" + unit_key + "_Name",
		"Name: pending",
		pos + Vector2(14, 35),
		Vector2(size.x - 28, 20),
		14
	)
	battle_ui_labels[unit_key + "_hull"] = make_label(
		"Battle_V2_" + unit_key + "_Hull",
		"Hull: -- / --",
		pos + Vector2(14, 56),
		Vector2(size.x - 28, 20),
		14
	)
	battle_ui_labels[unit_key + "_shield"] = make_label(
		"Battle_V2_" + unit_key + "_Shield",
		"Shield: -- / --",
		pos + Vector2(14, 77),
		Vector2(size.x - 28, 20),
		14
	)
	battle_ui_labels[unit_key + "_shield_energy"] = make_label(
		"Battle_V2_" + unit_key + "_Shield_Energy",
		"Shield E: R --/s D --/s",
		pos + Vector2(14, 98),
		Vector2(size.x - 28, 18),
		12
	)
	battle_ui_labels[unit_key + "_lock"] = make_label(
		"Battle_V2_" + unit_key + "_Lock",
		"Lock: pending",
		pos + Vector2(14, 117),
		Vector2(size.x - 28, 20),
		14
	)

	if unit_key == "player":
		battle_ui_labels["player_ammo"] = make_label(
			"Battle_V2_Player_Ammo",
			"Ammo: placeholder",
			pos + Vector2(14, 138),
			Vector2(size.x - 28, 20),
			14
		)
		battle_ui_labels["player_energy"] = make_label(
			"Battle_V2_Player_Energy",
			"Energy: --/-- A-- Q-- S--",
			pos + Vector2(14, 159),
			Vector2(size.x - 28, 18),
			12
		)
		build_player_energy_bar(pos + Vector2(14, 176), Vector2(size.x - 28, 7))

	if unit_key == "enemy":
		enemy_label = battle_ui_labels[unit_key + "_name"] as Label
		battle_ui_labels["enemy_intent"] = make_label(
			"Battle_V2_Enemy_Intent",
			"Intent: placeholder",
			pos + Vector2(14, 138),
			Vector2(size.x - 28, 20),
			14
		)
		battle_ui_labels["enemy_energy"] = make_label(
			"Battle_V2_Enemy_Energy",
			"Energy: --/-- A-- Q-- S--",
			pos + Vector2(14, 159),
			Vector2(size.x - 28, 18),
			12
		)
		build_enemy_energy_bar(pos + Vector2(14, 176), Vector2(size.x - 28, 7))


func build_player_energy_bar(pos: Vector2, size: Vector2) -> void:
	# Summary: Build the Battle V2 visual energy bar using EnergyHandler's green, blue, and red model.
	player_energy_bar_root = Control.new()
	player_energy_bar_root.name = "Battle_V2_Player_Energy_Bar"
	player_energy_bar_root.position = pos
	player_energy_bar_root.size = size
	player_energy_bar_root.custom_minimum_size = size
	player_energy_bar_root.clip_contents = true
	player_energy_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player_energy_bar_root)
	store_battle_control("Battle_V2_Player_Energy_Bar", player_energy_bar_root)

	var energy_back: ColorRect = ColorRect.new()
	energy_back.name = "Battle_V2_Player_Energy_Bar_Back"
	energy_back.color = Color(0.08, 0.09, 0.11, 1.0)
	energy_back.position = Vector2.ZERO
	energy_back.size = size
	energy_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_energy_bar_root.add_child(energy_back)

	player_energy_bar_spent = ColorRect.new()
	player_energy_bar_spent.name = "Battle_V2_Player_Energy_Spent"
	player_energy_bar_spent.color = Color(0.82, 0.18, 0.17, 1.0)
	player_energy_bar_spent.position = Vector2.ZERO
	player_energy_bar_spent.size = Vector2.ZERO
	player_energy_bar_spent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_energy_bar_root.add_child(player_energy_bar_spent)

	player_energy_bar_available = ColorRect.new()
	player_energy_bar_available.name = "Battle_V2_Player_Energy_Available"
	player_energy_bar_available.color = Color(0.16, 0.72, 0.35, 1.0)
	player_energy_bar_available.position = Vector2.ZERO
	player_energy_bar_available.size = size
	player_energy_bar_available.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_energy_bar_root.add_child(player_energy_bar_available)

	player_energy_bar_queued = ColorRect.new()
	player_energy_bar_queued.name = "Battle_V2_Player_Energy_Queued"
	player_energy_bar_queued.color = Color(0.20, 0.43, 0.95, 1.0)
	player_energy_bar_queued.position = Vector2.ZERO
	player_energy_bar_queued.size = Vector2.ZERO
	player_energy_bar_queued.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_energy_bar_root.add_child(player_energy_bar_queued)
	update_player_energy_bar_segments(1.0, 0.0, 0.0)


func build_enemy_energy_bar(pos: Vector2, size: Vector2) -> void:
	# Summary: Build the enemy Battle V2 visual energy bar using the same segment model as the player.
	enemy_energy_bar_root = Control.new()
	enemy_energy_bar_root.name = "Battle_V2_Enemy_Energy_Bar"
	enemy_energy_bar_root.position = pos
	enemy_energy_bar_root.size = size
	enemy_energy_bar_root.custom_minimum_size = size
	enemy_energy_bar_root.clip_contents = true
	enemy_energy_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(enemy_energy_bar_root)
	store_battle_control("Battle_V2_Enemy_Energy_Bar", enemy_energy_bar_root)

	var energy_back: ColorRect = ColorRect.new()
	energy_back.name = "Battle_V2_Enemy_Energy_Bar_Back"
	energy_back.color = Color(0.08, 0.09, 0.11, 1.0)
	energy_back.position = Vector2.ZERO
	energy_back.size = size
	energy_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_energy_bar_root.add_child(energy_back)

	enemy_energy_bar_spent = ColorRect.new()
	enemy_energy_bar_spent.name = "Battle_V2_Enemy_Energy_Spent"
	enemy_energy_bar_spent.color = Color(0.82, 0.18, 0.17, 1.0)
	enemy_energy_bar_spent.position = Vector2.ZERO
	enemy_energy_bar_spent.size = Vector2.ZERO
	enemy_energy_bar_spent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_energy_bar_root.add_child(enemy_energy_bar_spent)

	enemy_energy_bar_available = ColorRect.new()
	enemy_energy_bar_available.name = "Battle_V2_Enemy_Energy_Available"
	enemy_energy_bar_available.color = Color(0.16, 0.72, 0.35, 1.0)
	enemy_energy_bar_available.position = Vector2.ZERO
	enemy_energy_bar_available.size = size
	enemy_energy_bar_available.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_energy_bar_root.add_child(enemy_energy_bar_available)

	enemy_energy_bar_queued = ColorRect.new()
	enemy_energy_bar_queued.name = "Battle_V2_Enemy_Energy_Queued"
	enemy_energy_bar_queued.color = Color(0.20, 0.43, 0.95, 1.0)
	enemy_energy_bar_queued.position = Vector2.ZERO
	enemy_energy_bar_queued.size = Vector2.ZERO
	enemy_energy_bar_queued.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_energy_bar_root.add_child(enemy_energy_bar_queued)
	update_enemy_energy_bar_segments(1.0, 0.0, 0.0)


func build_shield_slider_panel(pos: Vector2, size: Vector2) -> void:
	# Summary: Build the always-visible shield power control from the battle UI blueprint.
	if Globals.print_priority_3:
		print("Building Battle V2 shield slider panel.")

	make_panel(
		"Battle_V2_Shield_Panel",
		pos,
		size,
		Color(0.04, 0.08, 0.10, 0.95)
	)

	battle_ui_labels["shield_title"] = make_label(
		"Battle_V2_Shield_Title",
		"SHIELD POWER",
		pos + Vector2(12, 10),
		Vector2(size.x - 24, 22),
		14
	)
	var initial_shield_power := 0
	if player_state_packet != null:
		initial_shield_power = int(clamp(player_state_packet.shield_power_level, 0, 4))
	var initial_shield_percent := initial_shield_power * 25

	battle_ui_labels["shield_power_value"] = make_label(
		"Battle_V2_Shield_Value",
		"Power: " + str(initial_shield_power) + " / 4",
		pos + Vector2(12, 36),
		Vector2(size.x - 24, 22),
		13
	)
	battle_ui_labels["shield_power_meaning"] = make_label(
		"Battle_V2_Shield_Meaning",
		str(initial_shield_percent) + "% output",
		pos + Vector2(12, 60),
		Vector2(size.x - 24, 30),
		11
	)

	legacy_shield_slider = HSlider.new()
	legacy_shield_slider.name = "Battle_V2_Shield_Slider"
	legacy_shield_slider.position = pos + Vector2(12, 94)
	legacy_shield_slider.size = Vector2(size.x - 24, 32)
	legacy_shield_slider.min_value = 0
	legacy_shield_slider.max_value = 4
	legacy_shield_slider.step = 1
	legacy_shield_slider.value = initial_shield_power
	legacy_shield_slider.value_changed.connect(on_shield_slider_changed)
	add_child(legacy_shield_slider)
	shield_slider = legacy_shield_slider
	store_battle_slider("Battle_V2_Shield_Slider", legacy_shield_slider)

	battle_ui_labels["shield_rule_1"] = make_label(
		"Battle_V2_Shield_Rule_1",
		"Blueprint: always visible.",
		pos + Vector2(12, 132),
		Vector2(size.x - 24, 18),
		10
	)
	battle_ui_labels["shield_rule_2"] = make_label(
		"Battle_V2_Shield_Rule_2",
		"EnergyHandler linked.",
		pos + Vector2(12, 151),
		Vector2(size.x - 24, 18),
		10
	)
	battle_ui_labels["shield_rule_3"] = make_label(
		"Battle_V2_Shield_Rule_3",
		"Slider feeds support level.",
		pos + Vector2(12, 170),
		Vector2(size.x - 24, 18),
		10
	)


func build_battle_v3_runtime_window(unit_key: String, title: String, pos: Vector2, size: Vector2) -> void:
	# Summary: Build compact side runtime lines for drones, signals, and timed effects.
	make_panel(
		"Battle_V3_" + unit_key.capitalize() + "_Runtime_Panel",
		pos,
		size,
		Color(0.035, 0.06, 0.075, 0.95)
	)
	battle_ui_labels[unit_key + "_runtime_title"] = make_label(
		"Battle_V3_" + unit_key.capitalize() + "_Runtime_Title",
		title,
		pos + Vector2(10, 8),
		Vector2(size.x - 20, 18),
		12
	)
	for i in range(3):
		battle_ui_labels[unit_key + "_runtime_" + str(i + 1)] = make_label(
			"Battle_V3_" + unit_key.capitalize() + "_Runtime_" + str(i + 1),
			"--",
			pos + Vector2(10, 30 + (i * 24)),
			Vector2(size.x - 20, 22),
			10
		)


func build_battle_v3_stats_window(unit_key: String, title: String, pos: Vector2, size: Vector2) -> void:
	# Summary: Build compact side stats lines for ammo, active equipment, and damage values.
	make_panel(
		"Battle_V3_" + unit_key.capitalize() + "_Stats_Panel",
		pos,
		size,
		Color(0.055, 0.045, 0.075, 0.95)
	)
	battle_ui_labels[unit_key + "_stats_title"] = make_label(
		"Battle_V3_" + unit_key.capitalize() + "_Stats_Title",
		title,
		pos + Vector2(10, 8),
		Vector2(size.x - 20, 18),
		12
	)
	for i in range(3):
		battle_ui_labels[unit_key + "_stats_" + str(i + 1)] = make_label(
			"Battle_V3_" + unit_key.capitalize() + "_Stats_" + str(i + 1),
			"--",
			pos + Vector2(10, 30 + (i * 24)),
			Vector2(size.x - 20, 22),
			10
		)


func build_action_widget(pos: Vector2, size: Vector2) -> void:
	# Summary: Build the compact Battle V3 holder lanes while preserving existing action routes.
	if Globals.print_priority_3:
		print("Building Battle V2 action widget.")

	make_panel(
		"Battle_V2_Action_Panel",
		pos,
		size,
		Color(0.05, 0.05, 0.09, 0.95)
	)

	battle_ui_labels["action_title"] = make_label(
		"Battle_V2_Action_Title",
		"ACTIONS",
		pos + Vector2(12, 10),
		Vector2(size.x - 24, 22),
		15
	)

	action_slot_labels.clear()
	battle_v3_drop_slots.clear()
	battle_v3_exec_buttons.clear()
	battle_action_rows.clear()

	action_body_root = Control.new()
	action_body_root.name = "Battle_V2_Action_Body"
	action_body_root.position = pos + Vector2(10, 38)
	action_body_root.size = Vector2(size.x - 20, size.y - 48)
	battle_v3_holder_root = action_body_root
	add_child(action_body_root)
	store_battle_action_ref("Battle_V2_Action_Body", action_body_root)

	var lane_specs := [
		{
			"lane": TAB_PRIMARY,
			"tab": TAB_PRIMARY,
			"label": "PRI"
		},
		{
			"lane": TAB_SECONDARY,
			"tab": TAB_SECONDARY,
			"label": "SEC"
		},
		{
			"lane": TAB_SHIELDS,
			"tab": TAB_SHIELDS,
			"label": "SHD"
		},
		{
			"lane": TAB_CONSUMABLE,
			"tab": TAB_CONSUMABLE,
			"label": "CON"
		}
	]
	var lane_h := 27.0
	var lane_gap := 4.0
	var slot_w := 164.0
	var exec_w = max(action_body_root.size.x - slot_w - 8.0, 70.0)
	for i in range(lane_specs.size()):
		var lane_data: Dictionary = lane_specs[i]
		var lane_id := str(lane_data.get("lane", ""))
		var slot_button: BattleV3DropSlot = BattleV3DropSlotScript.new()
		slot_button.name = "Battle_V3_" + lane_id.capitalize() + "_Holder"
		slot_button.position = Vector2(0, i * (lane_h + lane_gap))
		slot_button.size = Vector2(slot_w, lane_h)
		slot_button.setup(lane_id, str(lane_data.get("tab", "")), str(lane_data.get("label", lane_id.to_upper())))
		slot_button.item_dropped.connect(_on_battle_v3_slot_item_dropped)
		action_body_root.add_child(slot_button)
		battle_v3_drop_slots[lane_id] = slot_button
		store_battle_action_ref("Battle_V3_" + lane_id.capitalize() + "_Holder", slot_button)

		var exec_button := Button.new()
		exec_button.name = "Battle_V3_" + lane_id.capitalize() + "_Exec"
		exec_button.position = Vector2(slot_w + 8.0, i * (lane_h + lane_gap))
		exec_button.size = Vector2(exec_w, lane_h)
		exec_button.add_theme_font_size_override("font_size", 10)
		exec_button.pressed.connect(_on_battle_v3_exec_pressed.bind(lane_id))
		action_body_root.add_child(exec_button)
		battle_v3_exec_buttons[lane_id] = exec_button
		battle_action_rows.append(exec_button)
		store_battle_button("Battle_V3_" + lane_id.capitalize() + "_Exec", exec_button)
		store_battle_action_ref("Battle_V3_" + lane_id.capitalize() + "_Exec", exec_button)

	player_evade_button = Button.new()
	player_evade_button.name = "Battle_V3_Evade_Exec"
	player_evade_button.position = Vector2(0, 4 * (lane_h + lane_gap))
	player_evade_button.size = Vector2(action_body_root.size.x, 24)
	player_evade_button.add_theme_font_size_override("font_size", 10)
	player_evade_button.pressed.connect(on_player_evade_pressed)
	action_body_root.add_child(player_evade_button)
	store_battle_button("Battle_V3_Evade_Exec", player_evade_button)
	store_battle_action_ref("Battle_V3_Evade_Exec", player_evade_button)

	build_action_widget_shield_power_slider()


func build_action_widget_shield_power_slider() -> void:
	# Summary: Add the player shield power slider into the action widget while preserving the existing shield route.
	if action_body_root == null or not is_instance_valid(action_body_root):
		return

	var initial_shield_power := 0
	if player_state_packet != null:
		initial_shield_power = int(clamp(player_state_packet.shield_power_level, 0, 4))
	var initial_percent := initial_shield_power * 25

	var power_label := Label.new()
	power_label.name = "Battle_V3_Action_Shield_Power_Label"
	power_label.text = "PWR"
	power_label.position = Vector2(0, 154)
	power_label.size = Vector2(42, 24)
	power_label.add_theme_font_size_override("font_size", 10)
	action_body_root.add_child(power_label)
	battle_ui_labels["action_shield_power_label"] = power_label
	store_battle_label("Battle_V3_Action_Shield_Power_Label", power_label)
	store_battle_action_ref("Battle_V3_Action_Shield_Power_Label", power_label)

	action_shield_slider = HSlider.new()
	action_shield_slider.name = "Battle_V3_Action_Shield_Slider"
	action_shield_slider.position = Vector2(45, 154)
	action_shield_slider.size = BATTLE_V2_ACTION_SHIELD_SLIDER_SIZE
	action_shield_slider.min_value = 0
	action_shield_slider.max_value = 4
	action_shield_slider.step = 1
	action_shield_slider.value = initial_shield_power
	action_shield_slider.value_changed.connect(on_shield_slider_changed)
	action_body_root.add_child(action_shield_slider)
	shield_slider = action_shield_slider
	store_battle_slider("Battle_V2_Shield_Slider", action_shield_slider)
	store_battle_slider("Battle_V3_Action_Shield_Slider", action_shield_slider)
	store_battle_action_ref("Battle_V3_Action_Shield_Slider", action_shield_slider)

	var power_value_label := Label.new()
	power_value_label.name = "Battle_V3_Action_Shield_Power_Value"
	power_value_label.text = str(initial_percent) + "%"
	power_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_value_label.position = Vector2(208, 154)
	power_value_label.size = Vector2(57, 24)
	power_value_label.add_theme_font_size_override("font_size", 10)
	action_body_root.add_child(power_value_label)
	battle_ui_labels["action_shield_power_value"] = power_value_label
	store_battle_label("Battle_V3_Action_Shield_Power_Value", power_value_label)
	store_battle_action_ref("Battle_V3_Action_Shield_Power_Value", power_value_label)


func build_battle_v3_reference_widget(pos: Vector2, size: Vector2) -> void:
	# Summary: Build a compact inventory-style battle item reference list for drag/drop lane selection.
	if Globals.print_priority_3:
		print("Building Battle V3 item reference widget.")

	battle_v3_reference_root = make_panel(
		"Battle_V3_Reference_Panel",
		pos,
		size,
		Color(0.045, 0.055, 0.085, 0.95)
	)

	battle_ui_labels["battle_v3_reference_title"] = make_label(
		"Battle_V3_Reference_Title",
		"BATTLE ITEMS",
		pos + Vector2(12, 10),
		Vector2(size.x - 24, 22),
		15
	)

	var scroll := ScrollContainer.new()
	scroll.name = "Battle_V3_Reference_Scroll"
	scroll.position = pos + Vector2(10, 38)
	scroll.size = Vector2(size.x - 20, size.y - 48)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	store_battle_control("Battle_V3_Reference_Scroll", scroll)

	battle_v3_reference_list = VBoxContainer.new()
	battle_v3_reference_list.name = "Battle_V3_Reference_List"
	battle_v3_reference_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_v3_reference_list.add_theme_constant_override("separation", 4)
	scroll.add_child(battle_v3_reference_list)
	store_battle_control("Battle_V3_Reference_List", battle_v3_reference_list)
	battle_v3_reference_source_signature = "__unbuilt__"
	battle_v3_reference_refresh_pending = false


func build_todo_timeline_panel(pos: Vector2, size: Vector2) -> void:
	# Summary: Build the placeholder TODO/timeline zone that future EventManager rows will populate.
	if Globals.print_priority_3:
		print("Building Battle V2 TODO timeline panel.")

	make_panel(
		"Battle_V2_Todo_Panel",
		pos,
		size,
		Color(0.04, 0.05, 0.08, 0.95)
	)

	battle_ui_labels["todo_title"] = make_label(
		"Battle_V2_Todo_Title",
		"TODO / FUTURE TIMELINE",
		pos + Vector2(12, 10),
		Vector2(size.x - 24, 22),
		15
	)
	battle_ui_labels["todo_row_1"] = make_label(
		"Battle_V2_Todo_Row_1",
		"No battle TODOs queued.",
		pos + Vector2(12, 45),
		Vector2(size.x - 24, 22),
		13
	)
	battle_ui_labels["todo_row_2"] = make_label(
		"Battle_V2_Todo_Row_2",
		"Inventory rows queue through EventManager for this slice.",
		pos + Vector2(12, 72),
		Vector2(size.x - 24, 42),
		13
	)


func build_player_evade_button(pos: Vector2, size: Vector2) -> void:
	# Summary: Keep player evade visible near the TODO panel without making it a normal action-row TODO entry.
	player_evade_button = make_button(
		"Battle_V2_Player_Evade_Button",
		"Evade",
		pos,
		size
	)
	player_evade_button.pressed.connect(on_player_evade_pressed)
	battle_ui_labels["player_evade_status"] = make_label(
		"Battle_V2_Player_Evade_Status",
		"Evade: ready",
		pos + Vector2(-10, 32),
		Vector2(size.x + 20, 28),
		11
	)
	refresh_player_evade_control_state()


func build_battle_log_panel(pos: Vector2, size: Vector2) -> void:
	# Summary: Build the scene-local Battle V2 log panel.
	if Globals.print_priority_3:
		print("Building Battle V2 log panel.")

	make_panel(
		"Battle_V2_Log_Panel",
		pos,
		size,
		Color(0.03, 0.04, 0.07, 0.95)
	)

	battle_ui_labels["log_title"] = make_label(
		"Battle_V2_Log_Title",
		"BATTLE LOG",
		pos + Vector2(12, 10),
		Vector2(size.x - 24, 22),
		15
	)

	log_label = RichTextLabel.new()
	log_label.name = "Battle_V2_Log"
	log_label.position = pos + Vector2(12, 42)
	log_label.size = Vector2(size.x - 24, size.y - 54)
	log_label.bbcode_enabled = false
	log_label.add_theme_font_size_override("normal_font_size", 13)
	add_child(log_label)
	store_battle_log_ref("Battle_V2_Log", log_label)


func build_battle_v3_pipeline_widget(pos: Vector2, widget_size: Vector2) -> void:
	# Summary: Build the first-pass Battle V3 queue display without changing EventManager ownership.
	battle_v3_pipeline_widget = BattleV3PipelineWidgetScript.new()
	battle_v3_pipeline_widget.name = "Battle_V3_Pipeline_Widget"
	battle_v3_pipeline_widget.position = pos
	battle_v3_pipeline_widget.size = widget_size
	battle_v3_pipeline_widget.custom_minimum_size = widget_size
	add_child(battle_v3_pipeline_widget)
	store_battle_control("Battle_V3_Pipeline_Widget", battle_v3_pipeline_widget)
	battle_v3_pipeline_widget.setup({
		"battle_id": battle_id,
		"battle_scene": self
	})
	register_battle_v3_pipeline_widget_refs()
	if battle_v3_pipeline_widget.has_method("set_lane_intervention_handler"):
		battle_v3_pipeline_widget.set_lane_intervention_handler(Callable(self, "_on_battle_v3_lane_intervention_requested"))
	if battle_widget_spec_ui != null and is_instance_valid(battle_widget_spec_ui):
		battle_widget_spec_ui.build_onscreen_widget_runtime_data()


func refresh_battle_context_labels() -> void:
	# Summary: Display player test data and enemy encounter context handed off from main mode.
	if Globals.print_priority_5:
		print("Refreshing Battle V2 context labels.")

	# ------------------------------------------------------
	# Player data is placeholder until PlayerState is merged.
	# ------------------------------------------------------
	set_lookup_label_text("player_name", "Name: Player Ship")
	set_lookup_label_text("player_hull", "Hull: " + str(int(player_state_packet.player_hull_current)) + " / " + str(int(player_state_packet.player_hull_max)))
	set_lookup_label_text("player_shield", get_player_shield_status_text())
	set_lookup_label_text("player_shield_energy", get_player_shield_energy_status_text())
	set_lookup_label_text("player_lock", "Lock: " + get_lock_status_text(player_state_packet.player_good_lock, player_state_packet.player_lock_disabled, player_state_packet.player_lock_pending))
	refresh_player_ammo_status_values()
	refresh_energy_status_values()

	# ------------------------------------------------------
	# Build safe enemy display values from Enemy objects or dictionaries.
	# ------------------------------------------------------
	var enemy_name: String = "Unknown enemy"
	var enemy_hp: String = "--"
	var enemy_max_hp: String = "--"
	var enemy_attack: String = "--"

	if active_enemy != null:
		if active_enemy is BattleV2UnitAdapter:
			enemy_name = active_enemy.display_name
			enemy_hp = str(int(active_enemy.enemy_hull_current))
			enemy_max_hp = str(int(active_enemy.enemy_hull_max))
			enemy_attack = str(get_handoff_enemy_attack())
		elif active_enemy is Enemy or active_enemy is BattleV2Enemy:
			enemy_name = active_enemy.enemy_name
			enemy_hp = str(active_enemy.hp)
			enemy_max_hp = str(active_enemy.max_hp)
			enemy_attack = str(active_enemy.attack)
		elif active_enemy is Dictionary:
			enemy_name = str(active_enemy.get("name", active_enemy.get("enemy_name", "Unknown enemy")))
			enemy_hp = str(active_enemy.get("hp", "--"))
			enemy_max_hp = str(active_enemy.get("max_hp", enemy_hp))
			enemy_attack = str(active_enemy.get("attack", "--"))

	set_lookup_label_text("enemy_name", "Name: " + enemy_name)
	set_lookup_label_text("enemy_hull", "Hull: " + enemy_hp + " / " + enemy_max_hp)
	set_lookup_label_text("enemy_shield", get_enemy_shield_status_text(active_enemy))
	set_lookup_label_text("enemy_shield_energy", get_enemy_shield_energy_status_text(active_enemy))
	if active_enemy is BattleV2UnitAdapter:
		var enemy_state_for_lock: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
		set_lookup_label_text("enemy_lock", "Lock: " + get_lock_status_text(enemy_state_for_lock.enemy_good_lock, enemy_state_for_lock.enemy_lock_disabled, enemy_state_for_lock.enemy_lock_pending))
	else:
		set_lookup_label_text("enemy_lock", "Lock: not locked")
	set_lookup_label_text("enemy_intent", "Intent: placeholder")
	refresh_enemy_energy_status_values()
	refresh_battle_v2_unit_status_mirror_widgets()

	log_label.text = (
		"Battle V2 scene handoff received.\n"
		+ "Entry: " + str(battle_context.get("entry_reason", "unknown")) + "\n"
		+ "Enemy: " + enemy_name + " | ATK: " + enemy_attack + "\n"
		+ "Loadout: " + get_battle_v2_loadout_log_text() + "\n"
		+ "UI shell is active. Inventory-backed action rows queue, count down, and resolve through BattleManager.\n"
	)


func set_lookup_label_text(label_key: String, text: String) -> void:
	# Summary: Safely update a Battle V2 label by semantic lookup key.
	if not battle_ui_labels.has(label_key):
		if Globals.print_priority_5:
			print("Battle V2 label lookup missing: ", label_key)
		return

	var label: Label = battle_ui_labels[label_key] as Label
	if label == null:
		if Globals.print_priority_5:
			print("Battle V2 label lookup was not a Label: ", label_key)
		return

	label.text = text


func on_battle_action_tab_pressed(tab_id: String) -> void:
	# Summary: Switch the visible action body tab without changing battle state or creating TODOs.
	if Globals.print_priority_3:
		print("Battle V2 action tab selected: ", tab_id)

	# ------------------------------------------------------
	# Tabs are UI only per the prototype blueprint.
	# ------------------------------------------------------
	selected_action_tab = tab_id
	refresh_action_tab_visuals()
	refresh_action_body_rows()


func refresh_action_tab_visuals() -> void:
	# Summary: Update action tab button labels so the selected tab is obvious.
	for tab_id in battle_action_tabs.keys():
		var button: Button = battle_action_tabs[tab_id] as Button
		var base_text: String = str(tab_id).to_upper()
		if tab_id == TAB_CONSUMABLE:
			base_text = "CONSUMABLE"

		if tab_id == selected_action_tab:
			button.text = "> " + base_text + " <"
		else:
			button.text = base_text


func refresh_action_body_rows() -> void:
	# Summary: Refresh the compact Battle V3 holder lanes and item reference list.
	if Globals.print_priority_5:
		print("Refreshing Battle V3 holder lanes.")

	if action_body_root == null:
		return

	sync_battle_inventory_save_data_from_ammo_source()
	prune_unowned_battle_v3_slot_overrides()
	refresh_battle_v3_holder_widget()
	refresh_battle_v3_reference_widget()
	refresh_player_evade_control_state()


func refresh_battle_v3_holder_widget() -> void:
	if battle_v3_holder_root == null:
		return

	for lane_id in [TAB_PRIMARY, TAB_SECONDARY, TAB_SHIELDS, TAB_CONSUMABLE]:
		var slot_button: BattleV3DropSlot = battle_v3_drop_slots.get(lane_id, null) as BattleV3DropSlot
		var exec_button: Button = battle_v3_exec_buttons.get(lane_id, null) as Button
		var row_data := get_battle_v3_lane_exec_row(lane_id)
		var display_name := get_battle_v3_lane_slot_display_name(lane_id)

		if slot_button != null:
			slot_button.set_slot_text(display_name)
			slot_button.disabled = battle_v2_ended
		if exec_button != null:
			exec_button.text = str(row_data.get("button_text", row_data.get("text", "EXEC")))
			exec_button.disabled = bool(row_data.get("disabled", false))


func refresh_battle_v3_reference_widget() -> void:
	if battle_v3_reference_list == null:
		return

	var source_signature := get_battle_v3_reference_source_signature()
	if source_signature == battle_v3_reference_source_signature:
		battle_v3_reference_refresh_pending = false
		return

	if is_battle_v3_reference_interaction_active():
		battle_v3_reference_refresh_pending = true
		return

	var items := get_battle_v3_reference_items()
	battle_v3_reference_source_signature = source_signature
	battle_v3_reference_refresh_pending = false

	for child in battle_v3_reference_list.get_children():
		child.queue_free()

	if items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No battle items found."
		empty_label.add_theme_font_size_override("font_size", 11)
		battle_v3_reference_list.add_child(empty_label)
		return

	for entry in items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_entry: Dictionary = entry
		var item_id := str(item_entry.get("item_id", "")).strip_edges()
		var tab_id := str(item_entry.get("battle_tab", "")).strip_edges().to_lower()
		var item_data: Dictionary = item_entry.get("item_data", {}) if typeof(item_entry.get("item_data", {})) == TYPE_DICTIONARY else {}
		var label_text := str(item_entry.get("label", item_id))
		var row_button: BattleV3ItemRefButton = BattleV3ItemRefButtonScript.new()
		row_button.name = "Battle_V3_Ref_" + item_id
		row_button.size = Vector2(max(battle_v3_reference_list.size.x, 250.0), 24)
		row_button.custom_minimum_size = Vector2(250, 24)
		row_button.setup(item_id, item_data, tab_id, label_text)
		battle_v3_reference_list.add_child(row_button)
		store_battle_button("Battle_V3_Ref_" + item_id, row_button)


func flush_battle_v3_reference_refresh_if_pending() -> void:
	if not battle_v3_reference_refresh_pending:
		return
	if is_battle_v3_reference_interaction_active():
		return

	battle_v3_reference_source_signature = ""
	refresh_battle_v3_reference_widget()


func get_battle_v3_reference_source_signature() -> String:
	var parts: Array = []
	for item_id in get_inventory_item_ids_in_slot_order():
		var item_key := str(item_id).strip_edges()
		if item_key == "":
			continue
		parts.append(item_key + "x" + str(count_battle_inventory_snapshot_item(item_key)))
	return ";".join(parts)


func is_battle_v3_reference_interaction_active() -> bool:
	var viewport := get_viewport()
	if viewport != null and viewport.has_method("gui_is_dragging") and bool(viewport.call("gui_is_dragging")):
		return true
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return true
	return false


func is_node_inside_battle_v3_reference(node: Node) -> bool:
	while node != null:
		if node == battle_v3_reference_list or node == battle_v3_reference_root:
			return true
		if node is BattleV3ItemRefButton:
			return true
		node = node.get_parent()
	return false


func get_battle_v3_reference_items() -> Array:
	var entries: Array = []
	var seen: Dictionary = {}
	for item_id in get_inventory_item_ids_in_slot_order():
		var item_key := str(item_id).strip_edges()
		if item_key == "" or seen.has(item_key):
			continue
		var item_data := get_battle_v3_reference_item_data(item_key)
		if item_data.is_empty():
			continue
		var tab_id := str(item_data.get("battle_tab", "")).strip_edges().to_lower()
		if tab_id == "":
			continue
		seen[item_key] = true
		var count := count_battle_inventory_snapshot_item(item_key)
		var prefix := get_battle_v3_reference_prefix_for_item(tab_id, item_data)
		var display_name := get_battle_v3_item_short_name(item_data, item_key)
		var label_text := prefix + " | " + display_name
		if count > 1:
			label_text += " x" + str(count)
		entries.append({
			"item_id": item_key,
			"battle_tab": tab_id,
			"item_data": item_data,
			"label": label_text
		})
	return entries


func get_battle_v3_reference_item_data(item_id: String) -> Dictionary:
	var source_item := get_main_project_item_data(item_id)
	if source_item.is_empty():
		return {}

	for tab_id in [TAB_PRIMARY, TAB_SECONDARY, TAB_CONSUMABLE, TAB_SHIELDS]:
		if not item_matches_battle_tab(source_item, tab_id):
			continue
		var item_data := get_normalized_loadout_item_data(item_id, tab_id)
		if item_data.is_empty():
			continue
		item_data["battle_tab"] = tab_id
		return item_data

	return {}


func get_battle_v3_reference_prefix(tab_id: String) -> String:
	match tab_id:
		TAB_PRIMARY:
			return "PRI"
		TAB_SECONDARY:
			return "SEC"
		TAB_CONSUMABLE:
			return "CON"
		TAB_SHIELDS:
			return "SHD"
	return "ITM"


func get_battle_v3_reference_prefix_for_item(tab_id: String, item_data: Dictionary) -> String:
	if tab_id == TAB_CONSUMABLE:
		if is_explosive_consumable_item_data(item_data):
			return "EXP"
		var group := get_consumable_group_text(item_data)
		if group == "drone":
			return "DRN"
		if group == "shield_repair":
			return "FIX"
	return get_battle_v3_reference_prefix(tab_id)


func get_battle_v3_lane_exec_row(lane_id: String) -> Dictionary:
	if battle_v2_ended:
		return {
			"text": "BATTLE ENDED",
			"button_text": "ENDED",
			"action_id": "battle_ended",
			"disabled": true
		}

	match lane_id:
		TAB_PRIMARY:
			return build_battle_v3_weapon_lane_exec_row(TAB_PRIMARY, "FIRE", "EMPTY")
		TAB_SECONDARY:
			return build_battle_v3_weapon_lane_exec_row(TAB_SECONDARY, "FIRE", "EMPTY")
		TAB_SHIELDS:
			return build_battle_v3_shield_lane_exec_row()
		TAB_CONSUMABLE:
			return build_battle_v3_consumable_lane_exec_row()

	return {
		"text": "EMPTY",
		"button_text": "EXEC",
		"action_id": "missing_inventory_action",
		"disabled": true
	}


func build_battle_v3_weapon_lane_exec_row(tab_id: String, command_text: String, empty_text: String) -> Dictionary:
	var selected_id := get_battle_v3_selected_item_id_for_lane(tab_id)
	if selected_id == "":
		return {
			"text": empty_text,
			"button_text": empty_text,
			"action_id": "missing_inventory_action",
			"disabled": true
		}

	var item_data := get_normalized_loadout_item_data(selected_id, tab_id)
	if item_data.is_empty():
		return {
			"text": empty_text,
			"button_text": empty_text,
			"action_id": "missing_inventory_action",
			"disabled": true
		}

	var row_data := {
		"text": command_text + " | " + get_battle_v3_item_short_name(item_data, selected_id),
		"button_text": command_text,
		"action_id": str(item_data.get("action_id", "")),
		"item_id": selected_id,
		"item_data": item_data,
		"source": "battle_v3_holder_lane",
		"selected_action_tab": tab_id,
		"disabled": false
	}
	var final_row := apply_action_population_rules(row_data)
	if bool(final_row.get("disabled", false)):
		final_row["button_text"] = get_battle_v3_short_block_text(final_row, command_text)
	return final_row


func build_battle_v3_shield_lane_exec_row() -> Dictionary:
	var selected_id := get_battle_v3_selected_item_id_for_lane(TAB_SHIELDS)
	if selected_id == "":
		return {
			"text": "No shield selected",
			"button_text": "EMPTY",
			"action_id": "missing_inventory_action",
			"disabled": true
		}
	if not battle_inventory_snapshot_has_item(selected_id):
		return {
			"text": "Shield no longer owned",
			"button_text": "MISSING",
			"action_id": "missing_inventory_action",
			"disabled": true
		}

	var item_data := get_normalized_loadout_item_data(selected_id, TAB_SHIELDS)
	if item_data.is_empty():
		return {
			"text": "Shield data missing",
			"button_text": "MISSING",
			"action_id": "missing_inventory_action",
			"disabled": true
		}

	if player_state_packet != null and bool(player_state_packet.shield_switching):
		return {
			"text": "Shield switching",
			"button_text": "SWAP...",
			"action_id": "shield_busy",
			"disabled": true
		}

	var active_shield_id := ""
	if player_state_packet != null:
		active_shield_id = get_loadout_item_id(player_state_packet.selected_shield)
	if active_shield_id == selected_id and get_unit_float(player_state_packet, "shield_hp_current", 0.0) > 0.0:
		return {
			"text": "Active | " + get_battle_v3_item_short_name(item_data, selected_id),
			"button_text": "ACTIVE",
			"action_id": "shield_active",
			"disabled": true
		}

	var row_data := {
		"text": "SWAP | " + get_battle_v3_item_short_name(item_data, selected_id),
		"button_text": "SWAP",
		"action_id": "switch_shield",
		"item_id": selected_id,
		"item_data": item_data,
		"source": "battle_v3_holder_shield",
		"selected_action_tab": TAB_SHIELDS,
		"disabled": false
	}
	return apply_action_population_rules(row_data)


func build_battle_v3_consumable_lane_exec_row() -> Dictionary:
	var state := get_player_loaded_consumable_state()
	var loaded_data := get_loaded_consumable_item_data()
	if state == "loading" or state == "executing":
		var busy_label := "ARM" if is_explosive_consumable_item_data(loaded_data) and state == "loading" else "PREP"
		if is_explosive_consumable_item_data(loaded_data) and state == "executing":
			busy_label = "BLAST"
		elif state == "executing":
			busy_label = "USE"
		return {
			"text": build_consumable_busy_row_text(loaded_data, state),
			"button_text": busy_label + "...",
			"action_id": "consumable_busy",
			"disabled": true
		}

	if state == "ready":
		if loaded_data.is_empty():
			return {
				"text": "Loaded item missing data",
				"button_text": "MISSING",
				"action_id": "missing_inventory_action",
				"disabled": true
			}
		var loaded_item_id := str(loaded_data.get("item_id", loaded_data.get("id", ""))).strip_edges()
		var execute_row := {
			"text": build_battle_v3_consumable_lane_text(loaded_data, loaded_item_id, true),
			"button_text": "DETONATE" if is_explosive_consumable_item_data(loaded_data) else "EXEC",
			"action_id": "execute_consumable",
			"item_id": loaded_item_id,
			"item_data": loaded_data,
			"source": "battle_v3_holder_loaded_consumable",
			"selected_action_tab": TAB_CONSUMABLE,
			"disabled": false
		}
		var final_execute := apply_action_population_rules(execute_row)
		final_execute = apply_shield_repair_action_availability(final_execute, loaded_data)
		if bool(final_execute.get("disabled", false)):
			final_execute["button_text"] = get_battle_v3_short_block_text(final_execute, "EXEC")
		return final_execute

	var selected_id := get_battle_v3_selected_item_id_for_lane(TAB_CONSUMABLE)
	if selected_id == "":
		return {
			"text": "No consumable",
			"button_text": "EMPTY",
			"action_id": "missing_inventory_action",
			"disabled": true
		}
	var item_data := get_normalized_loadout_item_data(selected_id, TAB_CONSUMABLE)
	if item_data.is_empty():
		return {
			"text": "No consumable",
			"button_text": "EMPTY",
			"action_id": "missing_inventory_action",
			"disabled": true
		}
	var load_row := {
		"text": build_battle_v3_consumable_lane_text(item_data, selected_id, false),
		"button_text": "LOAD" if not is_explosive_consumable_item_data(item_data) else "LOAD",
		"action_id": "load_consumable",
		"item_id": selected_id,
		"item_data": item_data,
		"source": "battle_v3_holder_consumable",
		"selected_action_tab": TAB_CONSUMABLE,
		"disabled": false
	}
	var final_load := apply_action_population_rules(load_row)
	final_load = apply_shield_repair_action_availability(final_load, item_data)
	if bool(final_load.get("disabled", false)):
		final_load["button_text"] = get_battle_v3_short_block_text(final_load, "LOAD")
	return final_load


func get_battle_v3_short_block_text(row_data: Dictionary, fallback: String) -> String:
	var reason := str(row_data.get("blocked_reason", "")).strip_edges()
	if reason == "":
		reason = str(row_data.get("reason", "")).strip_edges()
	if reason.findn("energy") >= 0:
		return "ENERGY"
	if reason.findn("ammo") >= 0:
		return "AMMO"
	if reason.findn("broken") >= 0:
		return "BROKEN"
	if reason.findn("full") >= 0 or reason.findn("not damaged") >= 0:
		return "FULL"
	if reason.findn("shield") >= 0:
		return "SHIELD"
	if reason.findn("burst") >= 0 or reason.findn("todo") >= 0:
		return "BUSY"
	if reason.findn("cool") >= 0 or reason.findn("gate") >= 0 or str(row_data.get("text", "")).findn("ready") >= 0:
		return "WAIT"
	return fallback


func get_battle_v3_lane_slot_display_name(lane_id: String) -> String:
	if lane_id == TAB_CONSUMABLE:
		var loaded_data := get_loaded_consumable_item_data()
		if not loaded_data.is_empty():
			return get_battle_v3_item_short_name(loaded_data, str(loaded_data.get("item_id", "item")))

	var item_id := get_battle_v3_selected_item_id_for_lane(lane_id)
	if item_id == "":
		return "empty"
	var item_data := get_normalized_loadout_item_data(item_id, lane_id)
	if item_data.is_empty():
		return item_id
	return get_battle_v3_item_short_name(item_data, item_id)


func get_battle_v3_selected_item_id_for_lane(lane_id: String) -> String:
	var clean_lane := lane_id.strip_edges().to_lower()
	var override_id := str(battle_v3_slot_overrides.get(clean_lane, "")).strip_edges()
	if override_id != "":
		return override_id

	if clean_lane == TAB_SHIELDS:
		if player_state_packet == null:
			return ""
		var active_shield_id := get_loadout_item_id(player_state_packet.selected_shield)
		if active_shield_id != "" and battle_inventory_snapshot_has_item(active_shield_id):
			return active_shield_id
		return ""

	for item_id in get_player_loadout_item_ids_for_tab(clean_lane):
		var item_key := str(item_id).strip_edges()
		if item_key != "":
			return item_key
	return ""


func _on_battle_v3_slot_item_dropped(lane_id: String, item_id: String, item_data: Dictionary) -> void:
	var clean_lane := lane_id.strip_edges().to_lower()
	var clean_item := item_id.strip_edges()
	if clean_item == "" or not battle_v3_slot_overrides.has(clean_lane):
		return
	if not battle_inventory_snapshot_has_item(clean_item):
		if log_label != null:
			log_label.text += "\nBattle lane rejected: item is no longer owned.\n"
		refresh_action_body_rows()
		return

	var verified_item_data := get_normalized_loadout_item_data(clean_item, clean_lane)
	if verified_item_data.is_empty() or not item_matches_battle_tab(get_main_project_item_data(clean_item), clean_lane):
		if log_label != null:
			log_label.text += "\nBattle lane rejected: item does not match " + clean_lane + ".\n"
		refresh_action_body_rows()
		return

	if clean_lane == TAB_CONSUMABLE:
		var consumable_state := get_player_loaded_consumable_state()

		if consumable_state == "loading" or consumable_state == "executing":
			if log_label != null:
				log_label.text += "\nBattle lane rejected: consumable is busy and cannot be changed yet.\n"
			refresh_action_body_rows()
			return

		if consumable_state == "ready":
			if get_player_loaded_consumable_id() == clean_item:
				battle_v3_slot_overrides[clean_lane] = clean_item
				refresh_action_body_rows()
				refresh_battle_v3_pipeline_from_event_manager()
				return
			clear_player_loaded_consumable_runtime_for_reselect()

		var context_loadout := get_battle_v2_context_loadout_data().duplicate(true)
		context_loadout["loaded_consumable"] = clean_item
		context_loadout["loaded_consumable_state"] = "none"
		battle_context["loadout_data"] = context_loadout

	battle_v3_slot_overrides[clean_lane] = clean_item
	if player_state_packet != null:
		if clean_lane == TAB_PRIMARY:
			player_state_packet.selected_primary_weapon = clean_item
		elif clean_lane == TAB_SECONDARY:
			player_state_packet.selected_secondary_weapon = clean_item

	if log_label != null:
		var display_name := get_battle_v3_item_short_name(verified_item_data, clean_item)
		log_label.text += "\nBattle lane selected: " + clean_lane + " -> " + display_name + "\n"

	refresh_action_body_rows()
	refresh_battle_v3_pipeline_from_event_manager()


func prune_unowned_battle_v3_slot_overrides() -> Array:
	# Summary: Clear holder selections after inventory spending removes the referenced item.
	var pruned: Array = []
	for lane_id in battle_v3_slot_overrides.keys():
		var item_id := str(battle_v3_slot_overrides.get(lane_id, "")).strip_edges()
		if item_id == "":
			continue
		if battle_inventory_snapshot_has_item(item_id):
			continue
		battle_v3_slot_overrides[lane_id] = ""
		pruned.append({
			"lane_id": lane_id,
			"item_id": item_id,
			"labels": [
				"battle_v3_slot_override_pruned",
				"battle_v3_consumed_item_depopulated"
			]
		})
	return pruned


func _on_battle_v3_exec_pressed(lane_id: String) -> void:
	var row_data := get_battle_v3_lane_exec_row(lane_id)
	if bool(row_data.get("disabled", false)):
		if log_label != null:
			log_label.text += "\nBattle lane unavailable: " + str(row_data.get("text", row_data.get("button_text", "blocked"))) + "\n"
		refresh_action_body_rows()
		return

	on_action_row_pressed(row_data)


func refresh_battle_v3_action_slot_labels() -> void:
	# Summary: Keep the action-panel slot labels aligned with the same auto-fill source as the V3 pipeline.
	set_action_slot_label_text("primary", "Primary Slot: " + get_battle_v3_slot_display_name(TAB_PRIMARY))
	set_action_slot_label_text("secondary", "Secondary Slot: " + get_battle_v3_slot_display_name(TAB_SECONDARY))
	set_action_slot_label_text("consumable", "Consumable: " + get_battle_v3_consumable_slot_display_name(false))
	set_action_slot_label_text("drone", "Drone: " + get_battle_v3_consumable_slot_display_name(true))


func set_action_slot_label_text(slot_id: String, text: String) -> void:
	if not action_slot_labels.has(slot_id):
		return
	var label: Label = action_slot_labels[slot_id] as Label
	if label == null:
		return
	label.text = text


func get_battle_v3_action_column_rows() -> Array:
	if battle_v2_ended:
		return [
			{
				"text": "BATTLE ENDED | " + battle_v2_outcome,
				"action_id": "battle_ended",
				"disabled": true
			}
		]

	return [
		build_battle_v3_weapon_action_row(TAB_PRIMARY, "FIRE PRIMARY", "No primary weapon"),
		build_battle_v3_weapon_action_row(TAB_SECONDARY, "FIRE SECONDARY", "No secondary weapon"),
		build_battle_v3_consumable_action_row(false),
		build_battle_v3_consumable_action_row(true),
		build_battle_v3_evade_action_row()
	]


func build_battle_v3_weapon_action_row(tab_id: String, command_text: String, empty_text: String) -> Dictionary:
	for item_id in get_player_loadout_item_ids_for_tab(tab_id):
		var item_key := str(item_id).strip_edges()
		if item_key == "":
			continue
		var item_data := get_normalized_loadout_item_data(item_key, tab_id)
		if item_data.is_empty():
			continue
		var row_data := {
			"text": command_text + " | " + get_battle_v3_item_short_name(item_data, item_key),
			"action_id": str(item_data.get("action_id", "")),
			"item_id": item_key,
			"item_data": item_data,
			"source": "battle_v3_action_column",
			"selected_action_tab": tab_id,
			"disabled": false
		}
		return apply_action_population_rules(row_data)

	return {
		"text": empty_text,
		"action_id": "missing_inventory_action",
		"disabled": true
	}


func build_battle_v3_consumable_action_row(wants_drone: bool) -> Dictionary:
	var command_ready := "DEPLOY DRONE" if wants_drone else "USE CONSUMABLE"
	var command_load := "LOAD DRONE" if wants_drone else "LOAD CONSUMABLE"
	var waiting_text := "Drone slot waiting" if wants_drone else "Consumable slot waiting"
	var busy_text := "Consumable slot busy"
	var state := get_player_loaded_consumable_state()
	var loaded_data := get_loaded_consumable_item_data()
	var loaded_matches := not loaded_data.is_empty() and battle_v3_consumable_matches_drone_filter(loaded_data, wants_drone)
	var loaded_name := get_battle_v3_item_short_name(loaded_data, str(loaded_data.get("item_id", "item"))) if not loaded_data.is_empty() else "item"

	if state == "loading" or state == "executing":
		if loaded_matches:
			return {
				"text": build_consumable_busy_row_text(loaded_data, state),
				"action_id": "consumable_busy",
				"disabled": true
			}
		return {
			"text": waiting_text + " | " + busy_text,
			"action_id": "consumable_busy",
			"disabled": true
		}

	if state == "ready":
		if loaded_matches:
			var loaded_item_id := str(loaded_data.get("item_id", loaded_data.get("id", ""))).strip_edges()
			var execute_row := {
				"text": build_battle_v3_consumable_column_text(loaded_data, loaded_item_id, command_ready, true),
				"action_id": "execute_consumable",
				"item_id": loaded_item_id,
				"item_data": loaded_data,
				"source": "battle_v3_loaded_consumable",
				"selected_action_tab": TAB_CONSUMABLE,
				"disabled": false
			}
			return apply_action_population_rules(execute_row)
		return {
			"text": waiting_text + " | " + busy_text,
			"action_id": "consumable_slot_occupied",
			"disabled": true
		}

	for item_id in find_inventory_items_for_battle_tab(TAB_CONSUMABLE, 12):
		var item_key := str(item_id).strip_edges()
		var item_data := get_normalized_loadout_item_data(item_key, TAB_CONSUMABLE)
		if item_data.is_empty():
			continue
		if not battle_v3_consumable_matches_drone_filter(item_data, wants_drone):
			continue
		var load_row := {
			"text": build_battle_v3_consumable_column_text(item_data, item_key, command_load, false),
			"action_id": "load_consumable",
			"item_id": item_key,
			"item_data": item_data,
			"source": "battle_v3_inventory_consumable",
			"selected_action_tab": TAB_CONSUMABLE,
			"disabled": false
		}
		return apply_action_population_rules(load_row)

	return {
		"text": "No drone available" if wants_drone else "No consumable available",
		"action_id": "missing_inventory_action",
		"disabled": true
	}


func build_battle_v3_evade_action_row() -> Dictionary:
	var availability := get_player_evade_availability()
	var status := str(availability.get("status", "blocked"))
	var row_text := "EVADE | " + format_battle_value(evade_energy_cost) + " energy"
	if status == "cooldown":
		row_text = "EVADE | ready " + format_battle_value(float(availability.get("cooldown_remaining", 0.0))) + "s"
	elif status != "ready":
		row_text = "EVADE | " + str(availability.get("reason", status))

	return {
		"text": row_text,
		"action_id": "player_evade",
		"item_id": "player_evade",
		"source": "battle_v3_action_column",
		"disabled": status != "ready",
		"tags": ["battle_v3_evade", "player_action"],
		"labels": ["battle_v3_action_column", "player_evade_availability"]
	}


func get_rows_for_selected_action_tab() -> Array:
	# Summary: Return item-backed action rows for the current visual tab.
	if battle_v2_ended:
		return [
			{
				"text": "Battle ended: " + battle_v2_outcome,
				"action_id": "battle_ended",
				"disabled": true
			}
		]

	match selected_action_tab:
		TAB_PRIMARY:
			var primary_rows := build_player_loadout_rows_for_tab(TAB_PRIMARY)
			if not primary_rows.is_empty():
				return primary_rows
			return [build_empty_action_row("No primary weapon in inventory")]
		TAB_SECONDARY:
			var secondary_rows := build_player_loadout_rows_for_tab(TAB_SECONDARY)
			if not secondary_rows.is_empty():
				return secondary_rows
			return [build_empty_action_row("No secondary weapon in inventory")]
		TAB_CONSUMABLE:
			var consumable_rows := build_player_loadout_rows_for_tab(TAB_CONSUMABLE)
			if not consumable_rows.is_empty():
				return consumable_rows
			return [build_empty_action_row("No consumable loaded")]
		TAB_SHIELDS:
			var shield_rows := build_player_loadout_rows_for_tab(TAB_SHIELDS)
			if not shield_rows.is_empty():
				return shield_rows
			return [build_empty_action_row("No shield in inventory")]

	return []


func build_empty_action_row(text: String) -> Dictionary:
	# Summary: Build a disabled row when no inventory-backed action is available.
	return {
		"text": text,
		"action_id": "missing_inventory_action",
		"disabled": true
	}


func build_player_loadout_rows_for_tab(tab_id: String) -> Array:
	if Globals.print_priority_5:
		print("BATTLE V2 SCENE | build_player_loadout_rows_for_tab")
	# Summary: Build Battle V2 action rows from PlayerHandler-prepped loadout and real inventory items.
	if tab_id == TAB_CONSUMABLE:
		return build_consumable_action_rows()

	var rows: Array = []

	for item_id in get_player_loadout_item_ids_for_tab(tab_id):
		var item_key: String = str(item_id).strip_edges()
		var item_data: Dictionary = get_normalized_loadout_item_data(item_key, tab_id)
		if item_data.is_empty():
			continue
		if Globals.print_priority_5:
			
			print("[action_row_item_normalize] tab=", tab_id, " item=", item_key, " item_data_empty=", item_data.is_empty())

		var row_data: Dictionary = {
			"text": build_test_item_row_text(item_data),
			"action_id": str(item_data.get("action_id", "")),
			"item_id": item_key,
			"item_data": item_data,
			"source": "player_loadout",
			"disabled": false
		}
		if tab_id == TAB_CONSUMABLE:
			row_data["disabled"] = true
			row_data["text"] = str(row_data.get("text", "Consumable")) + " | load route later"
		var final_row := apply_action_population_rules(row_data)

		if Globals.print_priority_5:
			print("[action_row_candidate] tab=", tab_id, " item=", item_key, " disabled=", final_row.get("disabled", false), " text=", final_row.get("text", ""))

		rows.append(final_row)
		

			

	return rows


func build_consumable_action_rows() -> Array:
	# Summary: Build the two-step consumable lane: load first, then execute only the loaded item.
	var rows: Array = []
	var state := get_player_loaded_consumable_state()

	if state == "loading":
		var loading_item_data := get_loaded_consumable_item_data()
		if not loading_item_data.is_empty():
			return [build_empty_action_row(build_consumable_busy_row_text(loading_item_data, state))]
		return [build_empty_action_row("Consumable loading...")]

	if state == "executing":
		var executing_item_data := get_loaded_consumable_item_data()
		if not executing_item_data.is_empty():
			return [build_empty_action_row(build_consumable_busy_row_text(executing_item_data, state))]
		return [build_empty_action_row("Consumable executing...")]

	if state == "ready":
		var loaded_item_data := get_loaded_consumable_item_data()
		if loaded_item_data.is_empty():
			return [build_empty_action_row("Loaded consumable missing item data")]

		var loaded_item_id := str(loaded_item_data.get("item_id", loaded_item_data.get("id", ""))).strip_edges()
		var execute_row := {
			"text": build_consumable_execute_row_text(loaded_item_data),
			"action_id": "execute_consumable",
			"item_id": loaded_item_id,
			"item_data": loaded_item_data,
			"source": "loaded_consumable",
			"disabled": false
		}
		var populated_execute_row := apply_action_population_rules(execute_row)
		return [apply_shield_repair_action_availability(populated_execute_row, loaded_item_data)]

	for item_id in find_inventory_items_for_battle_tab(TAB_CONSUMABLE, 6):
		var item_key := str(item_id).strip_edges()
		var item_data: Dictionary = get_normalized_loadout_item_data(item_key, TAB_CONSUMABLE)
		if item_data.is_empty():
			continue
		var load_row := {
			"text": build_consumable_load_row_text(item_data),
			"action_id": "load_consumable",
			"item_id": item_key,
			"item_data": item_data,
			"source": "inventory_consumable",
			"disabled": false
		}
		var populated_load_row := apply_action_population_rules(load_row)
		rows.append(apply_shield_repair_action_availability(populated_load_row, item_data))

	return rows


func apply_shield_repair_action_availability(row_data: Dictionary, item_data: Dictionary) -> Dictionary:
	# Summary: Block shield-patch load/execute rows unless an equipped shield is damaged and still above zero HP.
	var group := str(item_data.get("consumable_group", item_data.get("group", item_data.get("subtype", "")))).strip_edges().to_lower()
	if group != "shield_repair":
		return row_data
	if str(row_data.get("action_id", "")).strip_edges().to_lower() == "load_consumable":
		return row_data

	var blocked_reason := ""
	if player_state_packet == null or get_loadout_item_id(player_state_packet.selected_shield) == "":
		blocked_reason = "shield repair requires an equipped shield"
	elif player_state_packet.shield_switching:
		blocked_reason = "shield repair blocked while shield is switching"
	elif player_state_packet.shield_disabled:
		blocked_reason = "shield repair blocked while shield is disabled"
	elif player_state_packet.shield_hp_current <= 0.0:
		blocked_reason = "shield broken and cannot be repaired"
	else:
		var shield_max := float(player_state_packet.shield_hp_max)
		if shield_max <= 0.0 and typeof(player_state_packet.selected_shield) == TYPE_DICTIONARY:
			shield_max = float(player_state_packet.selected_shield.get("shield_hp_max", player_state_packet.selected_shield.get("hp_max", 0.0)))
		if shield_max > 0.0 and player_state_packet.shield_hp_current >= shield_max:
			blocked_reason = "shield is full and not damaged"

	if blocked_reason == "":
		return row_data

	row_data["disabled"] = true
	row_data["blocked_reason"] = blocked_reason
	row_data["text"] = str(row_data.get("text", "Shield repair")) + " | " + blocked_reason
	var labels: Array = []
	if typeof(row_data.get("labels", [])) == TYPE_ARRAY:
		labels = row_data.get("labels", [])
	if not labels.has("shield_repair_ui_gate"):
		labels.append("shield_repair_ui_gate")
	if blocked_reason.findn("broken") >= 0 and not labels.has("shield_broken_not_repairable"):
		labels.append("shield_broken_not_repairable")
	row_data["labels"] = labels
	return row_data


func get_player_loaded_consumable_state() -> String:
	# Summary: Read the Battle V2 player consumable state without touching inventory counts.
	if player_state_packet == null:
		return "none"
	return str(player_state_packet.loaded_consumable_state).strip_edges().to_lower()


func get_player_loaded_consumable_id() -> String:
	if player_state_packet == null:
		return ""

	var loaded_id := get_loadout_item_id(player_state_packet.loaded_consumable)
	if loaded_id != "":
		return loaded_id

	var loaded_data := get_loaded_consumable_item_data()
	if not loaded_data.is_empty():
		return get_loadout_item_id(loaded_data)
	return ""


func clear_player_loaded_consumable_runtime_for_reselect() -> void:
	# Summary: Let drag/drop replace a ready held consumable without letting the old loaded item keep owning the CON button.
	if player_state_packet == null:
		return

	player_state_packet.loaded_consumable = null
	player_state_packet.loaded_consumable_state = "none"


func get_loaded_consumable_item_data() -> Dictionary:
	# Summary: Return the loaded consumable packet, whether stored as a dictionary or id.
	if player_state_packet == null:
		return {}

	var loaded_value = player_state_packet.loaded_consumable
	if typeof(loaded_value) == TYPE_DICTIONARY:
		var loaded_packet: Dictionary = loaded_value as Dictionary
		return loaded_packet.duplicate(true)

	if _has_loadout_item_value(loaded_value):
		return get_normalized_loadout_item_data(str(loaded_value), TAB_CONSUMABLE)

	return {}


func get_consumable_group_text(item_data: Dictionary) -> String:
	return str(item_data.get("consumable_group", item_data.get("group", item_data.get("subtype", "consumable")))).strip_edges().to_lower()


func is_explosive_consumable_item_data(item_data: Dictionary) -> bool:
	if item_data.is_empty():
		return false
	if get_consumable_group_text(item_data) == "explosive":
		return true
	if str(item_data.get("damage_type", "")).strip_edges().to_lower() == "explosive":
		return true
	var labels_text := str(item_data.get("labels", [])).to_lower()
	return labels_text.find("consumable_group_explosive") >= 0 or labels_text.find("explosive_pass_damage") >= 0


func get_explosive_consumable_damage(item_data: Dictionary) -> float:
	return float(item_data.get("explosive_damage", item_data.get("damage_value", item_data.get("damage", 0.0))))


func get_explosive_consumable_pass_percent_text(item_data: Dictionary) -> String:
	return str(int(round(float(item_data.get("explosive_pass_percent", 0.0)) * 100.0))) + "%"


func build_explosive_consumable_brief(item_data: Dictionary) -> String:
	return (
		format_battle_value(get_explosive_consumable_damage(item_data))
		+ " exp | "
		+ get_explosive_consumable_pass_percent_text(item_data)
		+ " pass"
	)


func build_consumable_busy_row_text(item_data: Dictionary, state: String) -> String:
	var clean_state := state.strip_edges().to_lower()
	if item_data.is_empty():
		return "Consumable " + clean_state + "..."
	var display_name := str(item_data.get("display_name", item_data.get("name", "consumable")))
	if is_explosive_consumable_item_data(item_data):
		if clean_state == "loading":
			return "Arming charge | " + display_name + " | " + build_explosive_consumable_brief(item_data)
		if clean_state == "executing":
			return "Detonating | " + display_name + " | " + build_explosive_consumable_brief(item_data)
	return ("Preparing " if clean_state == "loading" else "Using ") + display_name + "..."


func build_battle_v3_consumable_lane_text(item_data: Dictionary, item_id: String, executing: bool) -> String:
	var display_name := get_battle_v3_item_short_name(item_data, item_id)
	if is_explosive_consumable_item_data(item_data):
		return ("DETONATE | " if executing else "LOAD CHARGE | ") + display_name + " | " + build_explosive_consumable_brief(item_data)
	return ("EXECUTE | " if executing else "LOAD | ") + display_name


func build_battle_v3_consumable_column_text(item_data: Dictionary, item_id: String, fallback_command: String, executing: bool) -> String:
	if is_explosive_consumable_item_data(item_data):
		var command := "DETONATE" if executing else "LOAD CHARGE"
		return command + " | " + get_battle_v3_item_short_name(item_data, item_id) + " | " + build_explosive_consumable_brief(item_data)
	return fallback_command + " | " + get_battle_v3_item_short_name(item_data, item_id)


func build_consumable_load_row_text(item_data: Dictionary) -> String:
	# Summary: Build the visible text for an inventory consumable that can be loaded.
	var display_name := str(item_data.get("display_name", item_data.get("name", "Consumable")))
	var group := get_consumable_group_text(item_data)
	var load_time := float(item_data.get("prep_time", item_data.get("load_time", item_data.get("duration", 0.0))))
	if is_explosive_consumable_item_data(item_data):
		return (
			"LOAD CHARGE | "
			+ display_name
			+ " | arm "
			+ format_battle_value(load_time)
			+ "s | "
			+ build_explosive_consumable_brief(item_data)
		)
	if group == "repair":
		return (
			display_name
			+ " | repair | prep "
			+ format_battle_value(load_time)
			+ "s | heal "
			+ format_battle_value(float(item_data.get("heal_amount", item_data.get("repair_amount", 0.0))))
		)
	if group == "shield_repair":
		return (
			display_name
			+ " | shield patch | prep "
			+ format_battle_value(load_time)
			+ "s | shield +"
			+ format_battle_value(float(item_data.get("shield_repair_amount", item_data.get("repair_amount", 0.0))))
		)
	if group == "recharge":
		return (
			display_name
			+ " | recharge | prep "
			+ format_battle_value(load_time)
			+ "s | energy full"
		)
	if group == "drone":
		var drone_type := str(item_data.get("drone_type", "support"))
		if drone_type == "auto_attack":
			var fire_count := int(item_data.get("drone_fire_count", item_data.get("drone_max_shots", item_data.get("drone_shot_count", 0))))
			return (
				display_name
				+ " | drone | prep "
				+ format_battle_value(load_time)
				+ "s | auto "
				+ format_battle_value(float(item_data.get("effect_duration", item_data.get("duration", 0.0))))
				+ "s"
				+ (" | x" + str(fire_count) if fire_count > 0 else "")
			)
		return (
			display_name
			+ " | drone | prep "
			+ format_battle_value(load_time)
			+ "s | "
			+ drone_type
		)
	return display_name + " | " + group + " | load " + format_battle_value(load_time) + "s"


func build_consumable_execute_row_text(item_data: Dictionary) -> String:
	# Summary: Build the visible text for the one loaded consumable that can be executed.
	var display_name := str(item_data.get("display_name", item_data.get("name", "Consumable")))
	var group := get_consumable_group_text(item_data)
	var execute_time := float(item_data.get("execute_time", item_data.get("duration", 0.0)))
	if is_explosive_consumable_item_data(item_data):
		return (
			"DETONATE | "
			+ display_name
			+ " | blast "
			+ format_battle_value(execute_time)
			+ "s | "
			+ build_explosive_consumable_brief(item_data)
		)
	if group == "repair":
		return (
			"Use "
			+ display_name
			+ " | heal "
			+ format_battle_value(float(item_data.get("heal_amount", item_data.get("repair_amount", 0.0))))
		)
	if group == "shield_repair":
		return (
			"Use "
			+ display_name
			+ " | shield +"
			+ format_battle_value(float(item_data.get("shield_repair_amount", item_data.get("repair_amount", 0.0))))
			+ " | active shield only"
		)
	if group == "recharge":
		return "Use " + display_name + " | fill energy"
	if group == "drone":
		var drone_type := str(item_data.get("drone_type", "support"))
		if drone_type == "auto_attack":
			var fire_count := int(item_data.get("drone_fire_count", item_data.get("drone_max_shots", item_data.get("drone_shot_count", 0))))
			return (
				"Deploy "
				+ display_name
				+ " | 1 dmg/"
				+ format_battle_value(float(item_data.get("drone_fire_interval", 0.2)))
				+ "s | HP "
				+ format_battle_value(float(item_data.get("drone_hull_max", 50.0)))
				+ (" | x" + str(fire_count) if fire_count > 0 else "")
			)
		return (
			"Deploy "
			+ display_name
			+ " | "
			+ drone_type
			+ " | "
			+ format_battle_value(float(item_data.get("effect_duration", item_data.get("duration", 0.0))))
			+ "s"
		)
	return "Execute " + display_name + " | " + group + " | " + format_battle_value(execute_time) + "s"


func get_player_loadout_item_ids_for_tab(tab_id: String) -> Array:
	# Summary: Read selected loadout ids from the current player battle-state adapter.
	var clean_tab := tab_id.strip_edges().to_lower()
	var override_id := str(battle_v3_slot_overrides.get(clean_tab, "")).strip_edges()
	if override_id != "":
		return [override_id]

	var availability := get_player_handler_action_availability()
	if Globals.print_priority_5:
		print("BATTLE V2 SCENE  | get_player_loadout_item_ids_for_tab")
		print("[loadout_ids_start] tab=", clean_tab)
		print("[loadout_ids_start] availability_primary=", availability.get("selected_primary_weapon", null))
		print("[loadout_ids_start] availability_secondary=", availability.get("selected_secondary_weapon", null))
		print("[loadout_ids_start] availability_shield=", availability.get("selected_shield", null))
		print("[loadout_ids_start] availability_consumable=", availability.get("loaded_consumable", null))

	match clean_tab:
		TAB_PRIMARY:
			if bool(availability.get("has_primary_weapon", false)) and not bool(availability.get("primary_disabled", false)):
				return [availability.get("selected_primary_weapon")]
		TAB_SECONDARY:
			var secondary_ids: Array = []
			if bool(availability.get("has_secondary_weapon", false)) and not bool(availability.get("secondary_disabled", false)):
				append_unique_loadout_item_id(secondary_ids, availability.get("selected_secondary_weapon"))
			for inventory_secondary_id in find_inventory_items_for_battle_tab(TAB_SECONDARY, 4):
				append_unique_loadout_item_id(secondary_ids, inventory_secondary_id)
			if not secondary_ids.is_empty():
				return secondary_ids
		TAB_SHIELDS:
			if bool(availability.get("has_shield", false)) and not bool(availability.get("shield_disabled", false)):
				var available_shield_id := get_loadout_item_id(availability.get("selected_shield"))
				if available_shield_id != "" and battle_inventory_snapshot_has_item(available_shield_id):
					return [available_shield_id]

	var loadout_data := get_battle_v2_context_loadout_data()

	match clean_tab:
		TAB_PRIMARY:
			if player_state_packet != null and _has_loadout_item_value(player_state_packet.selected_primary_weapon):
				return [player_state_packet.selected_primary_weapon]
			if _has_loadout_item_value(loadout_data.get("selected_primary_weapon", null)):
				return [loadout_data.get("selected_primary_weapon")]
			return find_inventory_items_for_battle_tab(TAB_PRIMARY, 1)
		TAB_SECONDARY:
			if player_state_packet != null and _has_loadout_item_value(player_state_packet.selected_secondary_weapon):
				var fallback_secondary_ids: Array = []
				append_unique_loadout_item_id(fallback_secondary_ids, player_state_packet.selected_secondary_weapon)
				for inventory_secondary_id in find_inventory_items_for_battle_tab(TAB_SECONDARY, 4):
					append_unique_loadout_item_id(fallback_secondary_ids, inventory_secondary_id)
				return fallback_secondary_ids
			if _has_loadout_item_value(loadout_data.get("selected_secondary_weapon", null)):
				var context_secondary_ids: Array = []
				append_unique_loadout_item_id(context_secondary_ids, loadout_data.get("selected_secondary_weapon"))
				for inventory_secondary_id in find_inventory_items_for_battle_tab(TAB_SECONDARY, 4):
					append_unique_loadout_item_id(context_secondary_ids, inventory_secondary_id)
				return context_secondary_ids
			return find_inventory_items_for_battle_tab(TAB_SECONDARY, 4)
		TAB_SHIELDS:
			if player_state_packet != null and _has_loadout_item_value(player_state_packet.selected_shield):
				var active_shield_id := get_loadout_item_id(player_state_packet.selected_shield)
				if active_shield_id != "" and battle_inventory_snapshot_has_item(active_shield_id):
					return [active_shield_id]
			if _has_loadout_item_value(loadout_data.get("selected_shield", null)):
				var loadout_shield_id := get_loadout_item_id(loadout_data.get("selected_shield"))
				if loadout_shield_id != "" and battle_inventory_snapshot_has_item(loadout_shield_id):
					return [loadout_shield_id]
			return []
		TAB_CONSUMABLE:
			if _has_loadout_item_value(availability.get("loaded_consumable", null)):
				return [availability.get("loaded_consumable")]
			if _has_loadout_item_value(loadout_data.get("loaded_consumable", null)):
				return [loadout_data.get("loaded_consumable")]
			return find_inventory_items_for_battle_tab(TAB_CONSUMABLE, 1)

	return []


func append_unique_loadout_item_id(target: Array, value: Variant) -> void:
	# Summary: Keep multi-row Battle V2 inventory tabs stable without duplicate selected/inventory ids.
	if not _has_loadout_item_value(value):
		return
	var item_id := str(value).strip_edges()
	if target.has(item_id):
		return
	target.append(item_id)


func get_player_handler_action_availability() -> Dictionary:
	# Summary: Ask PlayerHandler for player-side availability facts before ActionManager decides row population.
	if player_handler_v2 == null or not player_handler_v2.has_method("get_player_action_availability"):
		return {}

	var availability: Dictionary = player_handler_v2.get_player_action_availability()
	if Globals.print_priority_5:
		print("BATTLE V2 SCENE  | get_player_handler_action_availability")
		print("[action_availability_packet] ", availability)
	if typeof(availability) != TYPE_DICTIONARY:
		return {}

	return availability


func find_inventory_items_for_battle_tab(tab_id: String, max_count: int = 1) -> Array:
	# Summary: Find inventory-backed items from the Battle V2 inventory/item snapshots.
	var item_db = battle_item_db_snapshot
	if typeof(item_db) != TYPE_DICTIONARY:
		return []

	var results: Array = []
	var ordered_item_ids := get_inventory_item_ids_in_slot_order()
	for item_id in ordered_item_ids:
		var item_key := str(item_id).strip_edges()
		if item_key == "":
			continue
		if results.has(item_key):
			continue
		if not item_matches_battle_tab(item_db.get(item_key, {}), tab_id):
			continue

		results.append(item_key)
		if max_count > 0 and results.size() >= max_count:
			return results

	if not results.is_empty():
		return results

	for item_id in item_db.keys():
		var item_key := str(item_id).strip_edges()
		if item_key == "":
			continue
		if results.has(item_key):
			continue
		if not battle_inventory_snapshot_has_item(item_key):
			continue
		if not item_matches_battle_tab(item_db.get(item_id, {}), tab_id):
			continue

		results.append(item_key)
		if max_count > 0 and results.size() >= max_count:
			return results

	return results


func get_inventory_item_ids_in_slot_order() -> Array:
	# Summary: Return owned item ids in visible inventory order for predictable Battle V3 auto-fill.
	var entries: Array = []
	for section_name in ["main", "drones"]:
		var section = battle_inventory_save_data.get(section_name, {})
		if typeof(section) != TYPE_DICTIONARY:
			continue
		for slot_name in section.keys():
			var slot = section.get(slot_name, {})
			if typeof(slot) != TYPE_DICTIONARY:
				continue
			var item_id := str(slot.get("item_id", "")).strip_edges()
			if item_id == "":
				continue
			if int(slot.get("count", 0)) <= 0:
				continue
			entries.append({
				"item_id": item_id,
				"slot_key": get_inventory_slot_sort_key(section_name, str(slot_name))
			})

	entries.sort_custom(func(a, b): return int(a.get("slot_key", 0)) < int(b.get("slot_key", 0)))

	var item_ids: Array = []
	for entry in entries:
		var item_key := str(entry.get("item_id", "")).strip_edges()
		if item_key == "":
			continue
		item_ids.append(item_key)
	return item_ids


func get_inventory_slot_sort_key(section_name: String, slot_name: String) -> int:
	var clean_section := section_name.strip_edges().to_lower()
	var clean_slot := slot_name.strip_edges().to_lower()
	if clean_section == "main":
		var normalized := clean_slot.replace("row ", "").replace(" - col", "|")
		var parts := normalized.split("|")
		if parts.size() >= 2:
			return int(parts[0]) * 100 + int(parts[1])
		return 9999
	if clean_section == "drones":
		return 10000 + int(clean_slot.replace("drone bay - col", ""))
	return 20000


func build_battle_ammo_inventory_source() -> Dictionary:
	# Summary: Build the mutable snapshot source used by AmmoHandler during isolated Battle V2.
	return {
		"source_type": "battle_v2_inventory_snapshot",
		"inventory_save_data": battle_inventory_save_data.duplicate(true),
		"item_db_snapshot": battle_item_db_snapshot.duplicate(true)
	}


func battle_inventory_snapshot_has_item(item_id: String) -> bool:
	# Summary: Check Inventory5 save-data snapshot for an owned item without touching a main-scene Inventory node.
	return count_battle_inventory_snapshot_item(item_id) > 0


func count_battle_inventory_snapshot_item(item_id: String) -> int:
	# Summary: Count item stacks in the Battle V2 inventory snapshot.
	var clean_item_id := item_id.strip_edges()
	if clean_item_id == "":
		return 0

	var total := 0
	for section_name in ["main", "drones"]:
		var section = battle_inventory_save_data.get(section_name, {})
		if typeof(section) != TYPE_DICTIONARY:
			continue

		for slot_name in section.keys():
			var slot = section.get(slot_name, {})
			if typeof(slot) != TYPE_DICTIONARY:
				continue
			if str(slot.get("item_id", "")) == clean_item_id:
				total += max(int(slot.get("count", 0)), 0)

	return total


func item_matches_battle_tab(item_data: Dictionary, tab_id: String) -> bool:
	# Summary: Match real inventory item metadata to a Battle V2 tab.
	if item_data.is_empty():
		return false

	var item_type := str(item_data.get("item_type", item_data.get("type", ""))).strip_edges().to_lower()
	var subtype := str(item_data.get("subtype", "")).strip_edges().to_lower()
	var slot := str(item_data.get("slot", "")).strip_edges().to_lower()

	match tab_id:
		TAB_PRIMARY:
			return item_type == "weapon" and (slot == "primary" or subtype == "energy")
		TAB_SECONDARY:
			return item_type == "weapon" and (slot == "secondary" or subtype == "kinetic") and subtype != "explosive"
		TAB_SHIELDS:
			return item_type == "shield"
		TAB_CONSUMABLE:
			return item_type == "consumable"

	return false


func _get_player_loadout_item_ids_for_tab_legacy(tab_id: String) -> Array:
	# Summary: Legacy direct adapter read kept as a reference during the loadout handoff transition.
	if player_state_packet == null:
		return []

	match tab_id:
		TAB_PRIMARY:
			if _has_loadout_item_value(player_state_packet.selected_primary_weapon):
				return [player_state_packet.selected_primary_weapon]
		TAB_SECONDARY:
			if _has_loadout_item_value(player_state_packet.selected_secondary_weapon):
				return [player_state_packet.selected_secondary_weapon]
		TAB_SHIELDS:
			if _has_loadout_item_value(player_state_packet.selected_shield):
				return [player_state_packet.selected_shield]

	return []


func _has_loadout_item_value(value: Variant) -> bool:
	# Summary: Treat null and blank string loadout values as empty.
	if value == null:
		return false
	if typeof(value) == TYPE_STRING:
		var clean_value := str(value).strip_edges()
		return clean_value != "" and clean_value.to_lower() != "<null>" and clean_value.to_lower() != "null"
	return true


func build_test_item_rows_for_tab(tab_id: String) -> Array:
	# Summary: Build clickable Battle V2 action rows from the local test item table.
	var rows: Array = []
	var item_ids: Array = TEST_ITEM_TAB_ORDER.get(tab_id, []) as Array

	# ------------------------------------------------------
	# Each row keeps only display and routing data. The full
	# item packet is normalized when the row is clicked.
	# ------------------------------------------------------
	for item_id in item_ids:
		var item_key: String = str(item_id)
		var item_data: Dictionary = get_normalized_test_item_data(item_key)
		if item_data.is_empty():
			continue

		var row_data: Dictionary = {
			"text": build_test_item_row_text(item_data),
			"action_id": str(item_data.get("action_id", "")),
			"item_id": item_key,
			"item_data": item_data,
			"source": "test_item",
			"disabled": false
		}
		rows.append(apply_action_population_rules(row_data))

	return rows


func apply_action_population_rules(row_data: Dictionary) -> Dictionary:
	# Summary: Let ActionManager decide whether a row can populate under current reserved-energy pressure.
	if battle_action_manager == null or not battle_action_manager.has_method("get_battle_action_population_result"):
		return apply_weapon_spam_gate_to_row(row_data)

	var item_data = row_data.get("item_data", {})
	if typeof(item_data) != TYPE_DICTIONARY:
		return apply_weapon_spam_gate_to_row(row_data)

	var population_result: Dictionary = battle_action_manager.get_battle_action_population_result(
		str(row_data.get("action_id", "")),
		item_data
	)
	row_data["population_result"] = population_result

	if population_result.get("status", "") == "blocked":
		row_data["disabled"] = true
		row_data["blocked_reason"] = str(population_result.get("reason", ""))
		row_data["labels"] = population_result.get("labels", [])
		var block_label := "blocked"
		if str_array_has(population_result.get("labels", []), "battle_action_population_reserved_ammo_block"):
			block_label = "ammo blocked"
		elif str_array_has(population_result.get("labels", []), "battle_action_population_reserved_energy_block"):
			block_label = "energy blocked"
		row_data["text"] = str(row_data.get("text", "Unknown action")) + " | " + block_label

	return apply_weapon_spam_gate_to_row(row_data)


func apply_weapon_spam_gate_to_row(row_data: Dictionary) -> Dictionary:
	# Summary: Disable primary/secondary rows while their independent click gates are active.
	var action_id := str(row_data.get("action_id", "")).strip_edges()
	if is_secondary_weapon_todo_lock_active(action_id):
		row_data["disabled"] = true
		row_data["blocked_reason"] = "secondary burst TODO active"
		var labels: Array = []
		if typeof(row_data.get("labels", [])) == TYPE_ARRAY:
			labels = row_data.get("labels", [])
		if not labels.has("secondary_weapon_todo_lock"):
			labels.append("secondary_weapon_todo_lock")
		if not labels.has("battle_action_weapon_todo_active_gate"):
			labels.append("battle_action_weapon_todo_active_gate")
		row_data["labels"] = labels

		var remaining := get_active_player_secondary_weapon_todo_remaining_seconds()
		if remaining > 0.0:
			row_data["text"] = str(row_data.get("text", "Unknown action")) + " | burst " + format_battle_value(remaining) + "s"
		else:
			row_data["text"] = str(row_data.get("text", "Unknown action")) + " | burst active"
		return row_data

	var remaining := get_weapon_spam_gate_remaining_seconds(action_id)
	if remaining <= 0.0:
		return row_data

	row_data["disabled"] = true
	row_data["blocked_reason"] = "weapon spam gate active"
	var spam_gate_labels: Array = []
	if typeof(row_data.get("labels", [])) == TYPE_ARRAY:
		spam_gate_labels = row_data.get("labels", [])
	spam_gate_labels.append("battle_action_weapon_spam_gate")
	row_data["labels"] = spam_gate_labels

	var display_remaining = max(ceil(remaining * 10.0) / 10.0, 0.1)
	row_data["text"] = str(row_data.get("text", "Unknown action")) + " | ready " + format_battle_value(display_remaining) + "s"
	return row_data


func get_weapon_spam_gate_duration_seconds(action_id: String) -> float:
	var clean_action := action_id.strip_edges().to_lower()
	if clean_action == "fire_primary_weapon":
		return PRIMARY_WEAPON_SPAM_GATE_SECONDS
	if clean_action == "fire_secondary_weapon":
		return SECONDARY_WEAPON_SPAM_GATE_SECONDS
	return 0.0


func get_weapon_spam_gate_remaining_seconds(action_id: String) -> float:
	var clean_action := action_id.strip_edges().to_lower()
	if get_weapon_spam_gate_duration_seconds(clean_action) <= 0.0:
		return 0.0

	var until_msec := int(weapon_spam_gate_until_msec.get(clean_action, 0))
	return max(float(until_msec - Time.get_ticks_msec()) / 1000.0, 0.0)


func is_weapon_spam_gate_active(action_id: String) -> bool:
	return get_weapon_spam_gate_remaining_seconds(action_id) > 0.0


func is_secondary_weapon_todo_lock_active(action_id: String) -> bool:
	# Summary: Block secondary fire while any player secondary TODO is still active.
	var clean_action := action_id.strip_edges().to_lower()
	if clean_action != "fire_secondary_weapon":
		return false
	return has_active_player_secondary_weapon_todo()


func has_active_player_secondary_weapon_todo() -> bool:
	return get_active_player_secondary_weapon_todo_count() > 0


func get_active_player_secondary_weapon_todo_count() -> int:
	if battle_event_manager == null:
		return 0

	var count := 0
	for event_packet in battle_event_manager.active_events:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		if str(event_packet.get("lifecycle_state", "active")).strip_edges().to_lower() != "active":
			continue
		if str(event_packet.get("event_side", "")).strip_edges().to_lower() != "player":
			continue
		if str(event_packet.get("event_type", "")).strip_edges().to_lower() != "fire_secondary_weapon":
			continue
		count += 1
	return count


func get_active_player_secondary_weapon_todo_remaining_seconds() -> float:
	if battle_event_manager == null:
		return 0.0

	var latest_remaining := 0.0
	for event_packet in battle_event_manager.active_events:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		if str(event_packet.get("lifecycle_state", "active")).strip_edges().to_lower() != "active":
			continue
		if str(event_packet.get("event_side", "")).strip_edges().to_lower() != "player":
			continue
		if str(event_packet.get("event_type", "")).strip_edges().to_lower() != "fire_secondary_weapon":
			continue
		latest_remaining = max(latest_remaining, max(float(event_packet.get("time_remaining", 0.0)), 0.0))
	return latest_remaining


func refresh_secondary_weapon_todo_lock_rows_if_needed() -> void:
	# Summary: Repaint secondary execution rows when the active secondary TODO stack appears, ticks, or clears.
	var active_count := get_active_player_secondary_weapon_todo_count()
	var remaining_bucket := int(ceil(get_active_player_secondary_weapon_todo_remaining_seconds() * 10.0))
	var new_signature := str(active_count) + "|" + str(remaining_bucket)
	if secondary_weapon_todo_lock_refresh_signature == new_signature:
		return

	secondary_weapon_todo_lock_refresh_signature = new_signature
	refresh_action_body_rows()


func start_weapon_spam_gate_for_action(action_id: String) -> void:
	var clean_action := action_id.strip_edges().to_lower()
	var duration := get_weapon_spam_gate_duration_seconds(clean_action)
	if duration <= 0.0:
		return

	weapon_spam_gate_until_msec[clean_action] = Time.get_ticks_msec() + int(round(duration * 1000.0))
	weapon_spam_gate_refresh_signature = ""


func get_weapon_spam_gate_action_for_tab(tab_id: String) -> String:
	var clean_tab := tab_id.strip_edges().to_lower()
	if clean_tab == TAB_PRIMARY:
		return "fire_primary_weapon"
	if clean_tab == TAB_SECONDARY:
		return "fire_secondary_weapon"
	return ""


func refresh_weapon_spam_gate_rows_if_needed() -> void:
	# Summary: Keep visible primary/secondary buttons enabling themselves as their gates expire.
	var signature_parts: Array = []
	for action_id in ["fire_primary_weapon", "fire_secondary_weapon"]:
		var remaining := get_weapon_spam_gate_remaining_seconds(action_id)
		var bucket := int(ceil(max(remaining, 0.0) * 10.0))
		signature_parts.append(action_id + "|" + str(bucket))

	var new_signature := ";".join(signature_parts)
	if weapon_spam_gate_refresh_signature == new_signature:
		return

	weapon_spam_gate_refresh_signature = new_signature
	refresh_action_body_rows()


func str_array_has(value: Variant, needle: String) -> bool:
	# Summary: Check label arrays from result packets without assuming exact variant shape.
	if typeof(value) != TYPE_ARRAY:
		return false
	for entry in value:
		if str(entry) == needle:
			return true
	return false


func get_normalized_loadout_item_data(item_id: String, tab_id: String) -> Dictionary:
	# Summary: Normalize a real main-project loadout item into the BattleActionPacketBuilder item shape.
	if item_id.strip_edges() == "":
		return {}

	var source_item := get_main_project_item_data(item_id)

	if Globals.print_priority_5:
		print("[normalize_source_item] tab=", tab_id, " item=", item_id, " source_empty=", source_item.is_empty())

	if source_item.is_empty():
		return {}

	var normalized := {}

	match tab_id:
		TAB_PRIMARY:
			normalized = build_loadout_weapon_item_data(item_id, source_item, true)
		TAB_SECONDARY:
			normalized = build_loadout_weapon_item_data(item_id, source_item, false)
		TAB_SHIELDS:
			normalized = build_loadout_shield_item_data(item_id, source_item)
		TAB_CONSUMABLE:
			normalized = build_loadout_consumable_item_data(item_id, source_item)

	if Globals.print_priority_5:
		print("[normalize_result] tab=", tab_id, " item=", item_id, " normalized_empty=", normalized.is_empty(), " action_id=", normalized.get("action_id", ""))

	return normalized


func get_main_project_item_data(item_id: String) -> Dictionary:
	# Summary: Read item metadata from the safe Battle V2 snapshot first.
	var clean_item_id := item_id.strip_edges()

	if clean_item_id == "":
		return {}

	var snapshot_entry = battle_item_db_snapshot.get(clean_item_id, {})
	if typeof(snapshot_entry) == TYPE_DICTIONARY and not snapshot_entry.is_empty():
		if Globals.print_priority_5:
			print("[item_data_lookup_success] item=", clean_item_id, " source=battle_item_db_snapshot")
		return snapshot_entry.duplicate(true)

	var context_snapshot = battle_context.get("item_db_snapshot", {})
	if typeof(context_snapshot) == TYPE_DICTIONARY:
		var context_entry = context_snapshot.get(clean_item_id, {})
		if typeof(context_entry) == TYPE_DICTIONARY and not context_entry.is_empty():
			if Globals.print_priority_5:
				print("[item_data_lookup_success] item=", clean_item_id, " source=context_item_db_snapshot")
			return context_entry.duplicate(true)

	if Globals.print_priority_5:
		print("[item_data_lookup_failed] item=", clean_item_id, " reason=no_snapshot_item_data")

	return {}

func build_loadout_weapon_item_data(item_id: String, source_item: Dictionary, is_primary: bool) -> Dictionary:
	# Summary: Convert main-project weapon metadata into a flat Battle V2 weapon packet.
	var subtype := str(source_item.get("subtype", "")).strip_edges()
	var slot := TAB_PRIMARY if is_primary else TAB_SECONDARY
	var action_id := "fire_primary_weapon" if is_primary else "fire_secondary_weapon"
	var duration := 3.0 if is_primary else 4.0
	var damage_type := str(source_item.get("damage_type", subtype)).strip_edges()
	if damage_type == "":
		damage_type = "energy" if is_primary else "kinetic"
	if subtype == "explosive":
		damage_type = "explosive"
	var ammo_group := "" if is_primary else normalize_battle_ammo_group(
		str(source_item.get("ammo_group", source_item.get("weapon_group", source_item.get("group", "")))),
		source_item
	)
	var default_energy_cost := 25.0 if is_primary else 0.0
	var energy_cost := get_source_item_cost_float(source_item, "energy_cost", default_energy_cost)
	var ammo_per_burst := int(get_source_item_cost_float(source_item, "ammo_per_burst", get_source_item_cost_float(source_item, "ammo_cost", 0.0 if is_primary else 1.0)))
	var upgrade_meta := get_current_battle_upgrade_meta_totals()
	var equipped_upgrade_ids := get_current_battle_upgrade_ids()
	var base_damage_value := float(source_item.get("damage_value", source_item.get("damage", 0.0)))
	var damage_bonus := float(upgrade_meta.get("primary_damage_bonus" if is_primary else "secondary_damage_bonus", 0))
	var burst_bonus := 0 if is_primary else int(upgrade_meta.get("secondary_burst_bonus", 0))
	var damage_value = max(base_damage_value + damage_bonus, 0.0)
	var burst_count = max(int(source_item.get("burst_count", 1)) + burst_bonus, 1)
	var total_ammo_cost = max(ammo_per_burst * max(burst_count, 1), 0)

	var packet := {
		"shared_meta": source_item.get("shared_meta", {}),
		"item_id": item_id,
		"id": item_id,
		"display_name": str(source_item.get("name", item_id)),
		"name": str(source_item.get("name", item_id)),
		"item_type": "weapon",
		"type": "weapon",
		"group": subtype if subtype != "" else slot,
		"slot": slot,
		"action_id": action_id,
		"event_type": action_id,
		"event_group": "weapon",
		"same_type_key": action_id + "_" + item_id,
		"duration": float(source_item.get("duration", source_item.get("fire_time", source_item.get("cooldown", duration)))),
		"requires_lock": true,
		"is_state_change": false,
		"is_damage_event": true,
		"is_effect_event": false,
		"is_visual_only": false,
		"damage_type": damage_type,
		"damage_value": damage_value,
		"damage": damage_value,
		"base_damage_value": base_damage_value,
		"battle_upgrade_damage_bonus": damage_bonus,
		"battle_upgrade_burst_bonus": burst_bonus,
		"battle_upgrade_meta": upgrade_meta.duplicate(true),
		"equipped_upgrades": equipped_upgrade_ids.duplicate(true),
		"explosive_pass_percent": float(source_item.get("explosive_pass_percent", 0.0)),
		"weapon_group": subtype if subtype != "" else slot,
		"energy_cost": energy_cost,
		"ammo_group": ammo_group,
		"ammo_per_burst": ammo_per_burst,
		"burst_count": burst_count,
		"ammo_cost": total_ammo_cost,
		"total_ammo_cost": total_ammo_cost,
		"tags": ["player_loadout_action_row"],
		"labels": build_loadout_weapon_labels(source_item, damage_type),
		"source_main_project_item": source_item
	}

	return SharedObjectMeta.apply_to_dictionary(packet, item_id, "battle_item_weapon", str(packet.get("display_name", item_id)), Vector3i.ZERO, Vector3.ZERO)


func build_loadout_weapon_labels(source_item: Dictionary, damage_type: String) -> Array:
	# Summary: Preserve source labels and add the normalized Battle V2 weapon behavior labels.
	var labels: Array = ["player_loadout_bridge", "player_state_sync_on_battle_start"]
	var source_labels = source_item.get("labels", [])
	if typeof(source_labels) == TYPE_ARRAY:
		for label in source_labels:
			if not labels.has(str(label)):
				labels.append(str(label))
	var damage_label := "damage_type_" + damage_type
	if damage_type != "" and not labels.has(damage_label):
		labels.append(damage_label)
	if damage_type == "explosive" and not labels.has("explosive_pass_damage"):
		labels.append("explosive_pass_damage")
	return labels


func get_source_item_cost_float(source_item: Dictionary, key: String, fallback: float = 0.0) -> float:
	# Summary: Read real inventory costs whether the item stores them flat or inside a costs packet.
	if source_item.has(key):
		return float(source_item.get(key, fallback))

	var costs = source_item.get("costs", {})
	if typeof(costs) == TYPE_DICTIONARY and costs.has(key):
		return float(costs.get(key, fallback))

	return fallback


func normalize_battle_ammo_group(raw_group: String, source_item: Dictionary) -> String:
	# Summary: Map current main-project weapon metadata into official small/medium/large ammo groups.
	var group := raw_group.strip_edges().to_lower()
	if group.ends_with("_ammo"):
		group = group.replace("_ammo", "")
	if group == "small" or group == "medium" or group == "large":
		return group

	var subtype := str(source_item.get("subtype", "")).strip_edges().to_lower()
	if subtype == "explosive":
		return "large"
	return "medium"


func build_loadout_shield_item_data(item_id: String, source_item: Dictionary) -> Dictionary:
	# Summary: Convert main-project shield metadata into a flat Battle V2 shield packet.
	var steady_drain := get_source_item_cost_float(
		source_item,
		"steady_energy_drain",
		get_source_item_cost_float(
			source_item,
			"shield_drain_per_second",
			get_source_item_cost_float(
				source_item,
				"energy_drain_per_second",
				get_source_item_cost_float(
					source_item,
					"drain_per_second",
					get_source_item_cost_float(
						source_item,
						"energy_drain",
						get_source_item_cost_float(source_item, "energy_cost_per_second", 0.0)
					)
				)
			)
		)
	)

	var packet := {
		"shared_meta": source_item.get("shared_meta", {}),
		"item_id": item_id,
		"id": item_id,
		"display_name": str(source_item.get("name", item_id)),
		"name": str(source_item.get("name", item_id)),
		"item_type": "shield",
		"type": "shield",
		"group": str(source_item.get("subtype", "shield")),
		"slot": "shield",
		"action_id": "switch_shield",
		"event_type": "switch_shield",
		"event_group": "shield",
		"same_type_key": "shield_switch_" + item_id,
		"duration": float(source_item.get("swap_time", source_item.get("duration", 1.5))),
		"requires_lock": false,
		"is_state_change": true,
		"is_damage_event": false,
		"is_effect_event": false,
		"is_visual_only": false,
		"shield_hp_max": float(source_item.get("shield_hp_max", source_item.get("hp_max", 45.0))),
		"base_damage_resist": float(source_item.get("base_damage_resist", source_item.get("base_shield_resist", 0.2))),
		"base_shield_resist": float(source_item.get("base_shield_resist", source_item.get("base_damage_resist", 0.2))),
		"regen_per_second": float(source_item.get("regen_per_second", 0.0)),
		"regen_delay": float(source_item.get("regen_delay", 0.0)),
		"swap_time": float(source_item.get("swap_time", source_item.get("duration", 1.5))),
		"steady_energy_drain": steady_drain,
		"shield_drain_per_second": steady_drain,
		"energy_drain_per_second": steady_drain,
		"tags": ["player_loadout_action_row"],
		"labels": ["player_loadout_bridge", "player_state_sync_on_battle_start"],
		"source_main_project_item": source_item
	}

	return SharedObjectMeta.apply_to_dictionary(packet, item_id, "battle_item_shield", str(packet.get("display_name", item_id)), Vector3i.ZERO, Vector3.ZERO)


func build_loadout_consumable_item_data(item_id: String, source_item: Dictionary) -> Dictionary:
	# Summary: Convert main-project consumable metadata into a visible Battle V2 consumable row.
	var source_affects: Array = []
	if typeof(source_item.get("affects", [])) == TYPE_ARRAY:
		source_affects = source_item.get("affects", []).duplicate(true)

	var source_values: Dictionary = {}
	if typeof(source_item.get("values", {})) == TYPE_DICTIONARY:
		source_values = source_item.get("values", {}).duplicate(true)

	var source_flags: Dictionary = {}
	if typeof(source_item.get("flags", {})) == TYPE_DICTIONARY:
		source_flags = source_item.get("flags", {}).duplicate(true)

	var source_visual_labels: Array = []
	if typeof(source_item.get("visual_labels", [])) == TYPE_ARRAY:
		source_visual_labels = source_item.get("visual_labels", []).duplicate(true)

	var source_visual_labels_on_expire: Array = []
	if typeof(source_item.get("visual_labels_on_expire", [])) == TYPE_ARRAY:
		source_visual_labels_on_expire = source_item.get("visual_labels_on_expire", []).duplicate(true)

	var packet := {
		"shared_meta": source_item.get("shared_meta", {}),
		"item_id": item_id,
		"id": item_id,
		"display_name": str(source_item.get("name", item_id)),
		"name": str(source_item.get("name", item_id)),
		"item_type": "consumable",
		"type": "consumable",
		"group": str(source_item.get("consumable_group", source_item.get("subtype", "consumable"))),
		"slot": "consumable",
		"action_id": "load_consumable",
		"event_type": "load_consumable",
		"event_group": "consumable",
		"same_type_key": "load_" + item_id,
		"duration": float(source_item.get("prep_time", source_item.get("load_time", source_item.get("duration", 1.0)))),
		"effect_duration": float(source_item.get("effect_duration", source_item.get("duration", 0.0))),
		"prep_time": float(source_item.get("prep_time", source_item.get("load_time", source_item.get("duration", 1.0)))),
		"load_time": float(source_item.get("load_time", source_item.get("prep_time", source_item.get("duration", 1.0)))),
		"execute_time": float(source_item.get("execute_time", source_item.get("duration", 1.0))),
		"consumable_group": str(source_item.get("consumable_group", source_item.get("subtype", "consumable"))),
		"damage_type": str(source_item.get("damage_type", "")),
		"damage_value": float(source_item.get("damage_value", source_item.get("damage", 0.0))),
		"damage": float(source_item.get("damage", source_item.get("damage_value", 0.0))),
		"explosive_damage": float(source_item.get("explosive_damage", source_item.get("damage_value", source_item.get("damage", 0.0)))),
		"explosive_pass_percent": float(source_item.get("explosive_pass_percent", 0.0)),
		"heal_amount": float(source_item.get("heal_amount", source_item.get("repair_amount", source_item.get("hull_restore_amount", 0.0)))),
		"repair_amount": float(source_item.get("repair_amount", source_item.get("heal_amount", source_item.get("hull_restore_amount", 0.0)))),
		"hull_restore_amount": float(source_item.get("hull_restore_amount", source_item.get("heal_amount", source_item.get("repair_amount", 0.0)))),
		"shield_repair_amount": float(source_item.get("shield_repair_amount", source_item.get("repair_amount", 0.0))),
		"requires_equipped_shield": bool(source_item.get("requires_equipped_shield", false)),
		"requires_unbroken_shield": bool(source_item.get("requires_unbroken_shield", false)),
		"energy_restore_amount": float(source_item.get("energy_restore_amount", source_item.get("recharge_amount", 0.0))),
		"recharge_amount": float(source_item.get("recharge_amount", source_item.get("energy_restore_amount", 0.0))),
		"recharge_to_full": bool(source_item.get("recharge_to_full", false)),
		"drone_type": str(source_item.get("drone_type", "")),
		"drone_group": str(source_item.get("drone_group", source_item.get("subgroup", ""))),
		"applies_effect": bool(source_item.get("applies_effect", false)),
		"drone_auto_attack": bool(source_item.get("drone_auto_attack", false)),
		"drone_damage_type": str(source_item.get("drone_damage_type", "hull")),
		"drone_damage_value": float(source_item.get("drone_damage_value", 0.0)),
		"drone_fire_interval": float(source_item.get("drone_fire_interval", 0.0)),
		"drone_fire_count": int(source_item.get("drone_fire_count", source_item.get("drone_max_shots", source_item.get("drone_shot_count", 0)))),
		"drone_hull_current": float(source_item.get("drone_hull_current", source_item.get("drone_hull_max", 0.0))),
		"drone_hull_max": float(source_item.get("drone_hull_max", 0.0)),
		"drone_shield_active": bool(source_item.get("drone_shield_active", false)),
		"effect_id": str(source_item.get("effect_id", source_item.get("drone_type", source_item.get("signal_type", "")))),
		"effect_type": str(source_item.get("effect_type", "")),
		"stack_rule": str(source_item.get("stack_rule", "none")),
		"priority": int(source_item.get("priority", 0)),
		"affects": source_affects,
		"values": source_values,
		"flags": source_flags,
		"visual_labels": source_visual_labels,
		"visual_labels_on_expire": source_visual_labels_on_expire,
		"tags": source_item.get("tags", ["player_loadout_action_row"]),
		"enemy_logic_tags": source_item.get("enemy_logic_tags", []),
		"labels": build_loadout_consumable_labels(source_item),
		"source_main_project_item": source_item
	}

	return SharedObjectMeta.apply_to_dictionary(packet, item_id, "battle_item_consumable", str(packet.get("display_name", item_id)), Vector3i.ZERO, Vector3.ZERO)



func build_loadout_consumable_labels(source_item: Dictionary) -> Array:
	# Summary: Preserve source labels and add normalized consumable bridge labels.
	var labels: Array = ["player_loadout_bridge", "player_inventory_bridge"]
	var source_labels = source_item.get("labels", [])
	if typeof(source_labels) == TYPE_ARRAY:
		for label in source_labels:
			if not labels.has(str(label)):
				labels.append(str(label))
	var consumable_group := str(source_item.get("consumable_group", source_item.get("subtype", ""))).strip_edges()
	if consumable_group != "":
		var group_label := "consumable_group_" + consumable_group
		if not labels.has(group_label):
			labels.append(group_label)
	var damage_type := str(source_item.get("damage_type", "")).strip_edges()
	if damage_type != "":
		var damage_label := "damage_type_" + damage_type
		if not labels.has(damage_label):
			labels.append(damage_label)
	return labels


func build_test_item_row_text(item_data: Dictionary) -> String:
	# Summary: Convert a normalized test item packet into compact action-row text.
	var display_name: String = str(item_data.get("display_name", item_data.get("name", "Unknown item")))
	var slot: String = str(item_data.get("slot", ""))
	var group: String = str(item_data.get("group", ""))

	# ------------------------------------------------------
	# Weapon rows show damage. Shield rows show shield HP and
	# resist so the test values are visible without graphics.
	# ------------------------------------------------------
	if slot == "shield":
		return (
			display_name
			+ " | "
			+ group
			+ " | HP "
			+ str(int(item_data.get("shield_hp_max", 0)))
			+ " | RES "
			+ str(int(float(item_data.get("base_damage_resist", 0.0)) * 100.0))
			+ "%"
		)

	return (
		display_name
		+ " | "
		+ group
		+ " | "
		+ str(item_data.get("damage_type", ""))
		+ " "
		+ str(int(item_data.get("damage_value", 0)))
	)


func get_normalized_test_item_data(item_id: String) -> Dictionary:
	# Summary: Flatten nested test item data into the packet-builder item shape.
	if not TEST_ITEMS.has(item_id):
		return {}

	var source_item: Dictionary = TEST_ITEMS[item_id] as Dictionary
	var battle_data: Dictionary = source_item.get("battle", {}) as Dictionary
	var stats_data: Dictionary = source_item.get("stats", {}) as Dictionary
	var cost_data: Dictionary = source_item.get("costs", {}) as Dictionary

	# ------------------------------------------------------
	# BattleActionPacketBuilder currently reads flat keys.
	# Keep the original nested packets too for later handlers.
	# ------------------------------------------------------
	var packet := {
		"shared_meta": source_item.get("shared_meta", {}),
		"item_id": str(source_item.get("item_id", item_id)),
		"id": str(source_item.get("item_id", item_id)),
		"display_name": str(source_item.get("display_name", item_id)),
		"name": str(source_item.get("display_name", item_id)),
		"item_type": str(source_item.get("item_type", "")),
		"type": str(source_item.get("item_type", "")),
		"group": str(source_item.get("group", "")),
		"slot": str(source_item.get("slot", "")),
		"action_id": str(battle_data.get("action_id", "")),
		"event_type": str(battle_data.get("event_type", "")),
		"event_group": str(battle_data.get("event_group", "")),
		"same_type_key": str(battle_data.get("same_type_key", "")),
		"duration": float(battle_data.get("duration", stats_data.get("swap_time", 0.0))),
		"requires_lock": bool(battle_data.get("requires_lock", false)),
		"is_state_change": bool(battle_data.get("is_state_change", false)),
		"is_damage_event": bool(battle_data.get("is_damage_event", false)),
		"is_effect_event": bool(battle_data.get("is_effect_event", false)),
		"is_visual_only": bool(battle_data.get("is_visual_only", false)),
		"damage_type": str(stats_data.get("damage_type", "")),
		"damage_value": float(stats_data.get("damage_value", 0.0)),
		"weapon_group": str(stats_data.get("weapon_group", source_item.get("group", ""))),
		"energy_cost": float(cost_data.get("energy_cost", 0.0)),
		"ammo_group": str(cost_data.get("ammo_group", "")),
		"ammo_cost": int(cost_data.get("ammo_cost", 0)),
		"shield_hp_max": float(stats_data.get("shield_hp_max", 0.0)),
		"base_damage_resist": float(stats_data.get("base_damage_resist", 0.0)),
		"base_shield_resist": float(stats_data.get("base_damage_resist", 0.0)),
		"regen_per_second": float(stats_data.get("regen_per_second", 0.0)),
		"regen_delay": float(stats_data.get("regen_delay", 0.0)),
		"swap_time": float(stats_data.get("swap_time", battle_data.get("duration", 0.0))),
		"steady_energy_drain": float(cost_data.get("steady_energy_drain", 0.0)),
		"tags": source_item.get("tags", []),
		"labels": source_item.get("labels", []),
		"source_test_item": source_item
	}

	return SharedObjectMeta.apply_to_dictionary(packet, str(packet.get("item_id", item_id)), "battle_item_" + str(packet.get("item_type", "item")), str(packet.get("display_name", item_id)), Vector3i.ZERO, Vector3.ZERO)


func on_action_row_pressed(row_data: Dictionary) -> void:
	# Summary: Route a clicked Battle V2 action row into the prototype packet/event path.
	if Globals.print_priority_5:
		print("Battle V2 action row clicked: ", row_data)

	if battle_v2_ended:
		log_label.text += "\nBattle has ended. No new actions can be queued.\n"
		return

	# ------------------------------------------------------
	# Item-backed rows carry the action and item id needed
	# to create the correct packet-builder context.
	# ------------------------------------------------------
	var action_id: String = str(row_data.get("action_id", "")).strip_edges()
	var item_id: String = str(row_data.get("item_id", "")).strip_edges()
	var item_data: Dictionary = {}
	if typeof(row_data.get("item_data", {})) == TYPE_DICTIONARY:
		item_data = row_data.get("item_data", {})

	if item_data.is_empty():
		report_battle_v2_action_clicked_to_ui_handler(row_data, {}, "rejected", "missing_item_data")
		log_label.text += "\nSelected action row has no item data: " + str(row_data.get("text", "unknown"))
		return

	var packet_gate_result := run_battle_v3_packet_build_gate(action_id, row_data)
	if not bool(packet_gate_result.get("allowed", true)):
		report_battle_v2_action_clicked_to_ui_handler(row_data, packet_gate_result, "blocked", str(packet_gate_result.get("reason", "packet gate blocked")))
		log_label.text += "\nAction blocked: " + str(packet_gate_result.get("reason", "packet gate blocked")) + "\n"
		refresh_action_body_rows()
		return

	if not is_supported_test_action(action_id):
		report_battle_v2_action_clicked_to_ui_handler(row_data, {}, "ignored", "unsupported_action")
		log_label.text += "\nSelected action row: " + str(row_data.get("text", "unknown"))
		return

	if is_secondary_weapon_todo_lock_active(action_id):
		report_battle_v2_action_clicked_to_ui_handler(row_data, {
			"status": "blocked",
			"reason": "secondary burst TODO active"
		}, "blocked", "secondary burst TODO active")
		log_label.text += "\nSecondary busy: burst TODO stack still resolving.\n"
		refresh_action_body_rows()
		return

	if is_weapon_spam_gate_active(action_id):
		report_battle_v2_action_clicked_to_ui_handler(row_data, {
			"status": "blocked",
			"reason": "weapon spam gate active"
		}, "blocked", "weapon spam gate active")
		log_label.text += "\nAction cooling down: " + format_battle_value(get_weapon_spam_gate_remaining_seconds(action_id)) + "s"
		refresh_action_body_rows()
		return

	var action_data: Dictionary = {
		"item_data": item_data,
		"duration": get_action_row_duration(action_id, item_data),
		"same_type_key": str(item_data.get("same_type_key", ""))
	}
	var route_result: Dictionary = battle_action_manager.handle_battle_action_click(action_id, action_data)
	report_battle_v2_action_clicked_to_ui_handler(
		row_data,
		route_result,
		str(route_result.get("status", "clicked")),
		str(route_result.get("reason", ""))
	)
	refresh_todo_timeline_from_event_manager()
	refresh_energy_status_values()
	refresh_player_ammo_status_values()

	if route_result.get("status", "") == "queued":
		start_weapon_spam_gate_for_action(action_id)
		prepare_queued_test_item_state(action_id, item_data)

		var event_result: Dictionary = route_result.get("event_result", {})
		var energy_line: String = get_route_energy_log_line(route_result)
		var ammo_line: String = get_route_ammo_log_line(route_result)
		log_label.text += (
			"\nQueued: " + str(item_data.get("display_name", item_id))
			+ "\nEvent id: " + str(event_result.get("event_id", "pending"))
			+ energy_line
			+ ammo_line
			+ "\nPacket path: ActionManager -> PacketBuilder -> EventManager -> BattleManager"
			+ "\nResolution: waiting for TODO completion\n"
		)
	else:
		log_label.text += (
			"\nBattle test item route rejected."
			+ "\nReason: " + str(route_result.get("reason", "unknown"))
		)
	
	refresh_action_body_rows()
	

func get_action_row_duration(action_id: String, item_data: Dictionary) -> float:
	# Summary: Pick load vs execute timing without moving TODO ownership out of EventManager.
	var clean_action_id := action_id.strip_edges().to_lower()
	if clean_action_id == "load_consumable":
		return float(item_data.get("prep_time", item_data.get("load_time", item_data.get("duration", 0.0))))
	if clean_action_id == "execute_consumable":
		var execute_time := float(item_data.get("execute_time", item_data.get("duration", 0.0)))
		if execute_time <= 0.0:
			execute_time = 0.25
		return execute_time
	return float(item_data.get("duration", 0.0))


func on_player_evade_pressed() -> void:
	# Summary: Queue the always-visible player evade action when cooldown and weapon-free rules allow it.
	var evade_row_data := build_player_evade_action_ui_row_data()
	var availability := get_player_evade_availability()
	if str(availability.get("status", "")) != "ready":
		report_battle_v2_action_clicked_to_ui_handler(
			evade_row_data,
			{"status": "blocked", "reason": str(availability.get("reason", "not ready"))},
			"blocked",
			str(availability.get("reason", "not ready"))
		)
		if log_label != null:
			log_label.text += "\nEvade unavailable: " + str(availability.get("reason", "not ready")) + "\n"
		refresh_player_evade_control_state()
		return

	var packet_gate_result := run_battle_v3_packet_build_gate("player_evade", evade_row_data)
	if not bool(packet_gate_result.get("allowed", true)):
		report_battle_v2_action_clicked_to_ui_handler(evade_row_data, packet_gate_result, "blocked", str(packet_gate_result.get("reason", "packet gate blocked")))
		if log_label != null:
			log_label.text += "\nEvade blocked: " + str(packet_gate_result.get("reason", "packet gate blocked")) + "\n"
		refresh_player_evade_control_state()
		return

	var route_result: Dictionary = battle_action_manager.handle_battle_action_click("player_evade", {
		"duration": evade_todo_duration_seconds,
		"evade_duration": evade_todo_duration_seconds,
		"evade_cooldown_seconds": evade_cooldown_seconds,
		"evade_lock_reacquire_penalty_seconds": evade_lock_reacquire_penalty_seconds,
		"evade_pipeline_disrupt_seconds": evade_pipeline_disrupt_seconds,
		"energy_cost": evade_energy_cost
	})

	if str(route_result.get("status", "")) != "queued":
		report_battle_v2_action_clicked_to_ui_handler(
			evade_row_data,
			route_result,
			str(route_result.get("status", "rejected")),
			str(route_result.get("reason", "unknown"))
		)
		if log_label != null:
			log_label.text += "\nEvade rejected: " + str(route_result.get("reason", "unknown")) + "\n"
		refresh_player_evade_control_state()
		return

	var packet_result = route_result.get("packet_result", {})
	var event_packet: Dictionary = {}
	if typeof(packet_result) == TYPE_DICTIONARY:
		event_packet = packet_result.get("event_packet", {})
	report_battle_v2_action_clicked_to_ui_handler(
		evade_row_data,
		route_result,
		str(route_result.get("status", "queued")),
		str(route_result.get("reason", ""))
	)

	start_player_evade_cooldown()
	apply_evade_queue_effects(event_packet)
	var intervention_result := request_battle_v3_evade_lane_intervention(event_packet, str(route_result.get("event_result", {}).get("event_id", "")))
	refresh_todo_timeline_from_event_manager()
	refresh_unit_status_values()
	refresh_player_evade_control_state()

	if log_label != null:
		var event_result: Dictionary = route_result.get("event_result", {})
		log_label.text += (
			"\nEvade maneuver queued."
			+ "\nEvent id: " + str(event_result.get("event_id", "pending"))
			+ "\nCountdown: " + format_battle_value(evade_todo_duration_seconds) + "s"
			+ "\nEnergy: " + format_battle_value(evade_energy_cost)
			+ "\nOpposing lane gate: " + get_lane_intervention_log_text(intervention_result)
			+ "\nEvade cooldown: " + format_battle_value(evade_cooldown_seconds) + "s\n"
		)


func run_battle_v3_packet_build_gate(action_id: String, row_data: Dictionary) -> Dictionary:
	# Summary: Reusable pre-packet hook for future target/effect rules.
	return {
		"allowed": true,
		"action_id": action_id,
		"source": str(row_data.get("source", "")),
		"reason": "",
		"labels": ["battle_v3_packet_build_gate", "battle_v3_packet_gate_open"]
	}


func request_battle_v3_evade_lane_intervention(evade_event_packet: Dictionary, fallback_event_id: String = "") -> Dictionary:
	# Summary: Hand player Evade to the pipeline listener so the nearest opposing TODO can be null-gated.
	var source_event_id := str(evade_event_packet.get("event_id", fallback_event_id)).strip_edges()
	var source_side := str(evade_event_packet.get("event_side", "player")).strip_edges().to_lower()
	if source_side != "player" and source_side != "enemy":
		source_side = "player"
	var target_side := "enemy" if source_side == "player" else "player"
	var intervention_packet := {
		"intervention_type": "nullify",
		"source_action": "evade",
		"source_event_id": source_event_id,
		"source_side": source_side,
		"target_side": target_side,
		"excluded_event_id": source_event_id,
		"reason": "evade_lane_intervention",
		"target_strategy": "nearest_finish"
	}

	var result := {
		"accepted": false,
		"nullified": false,
		"blocked_reason": "missing_pipeline_listener",
		"labels": ["battle_v3_evade_lane_intervention"]
	}
	if battle_v3_pipeline_widget != null and battle_v3_pipeline_widget.has_method("listen_for_lane_intervention"):
		var listener_result = battle_v3_pipeline_widget.listen_for_lane_intervention(intervention_packet)
		if typeof(listener_result) == TYPE_DICTIONARY:
			result = listener_result
	else:
		result = _on_battle_v3_lane_intervention_requested(intervention_packet)

	latest_lane_intervention_result = result
	if bool(result.get("nullified", false)):
		mark_active_event_data_values(source_event_id, {
			"evade_lane_intervention_applied": true,
			"evade_pipeline_disrupt_seconds": 0.0
		})
	return result


func _on_battle_v3_lane_intervention_requested(intervention_packet: Dictionary) -> Dictionary:
	var target_side := str(intervention_packet.get("target_side", "")).strip_edges().to_lower()
	var source_event_id := str(intervention_packet.get("source_event_id", "")).strip_edges()
	var excluded_event_id := str(intervention_packet.get("excluded_event_id", source_event_id)).strip_edges()
	var reason := str(intervention_packet.get("reason", "lane_intervention")).strip_edges()
	var result := {
		"accepted": false,
		"nullified": false,
		"event_id": "",
		"blocked_reason": "",
		"labels": ["battle_v3_lane_intervention_listener"]
	}
	if battle_event_manager == null or not battle_event_manager.has_method("nullify_next_event_for_side"):
		result["blocked_reason"] = "missing_event_manager_null_gate"
		return result

	var null_result: Dictionary = battle_event_manager.nullify_next_event_for_side(target_side, reason, excluded_event_id, source_event_id)
	for key in null_result.keys():
		result[key] = null_result[key]
	result["accepted"] = bool(null_result.get("nullified", false))
	result["nullified"] = bool(null_result.get("nullified", false))
	return result


func mark_active_event_data_values(event_id: String, values: Dictionary) -> bool:
	var clean_event_id := event_id.strip_edges()
	if clean_event_id == "" or battle_event_manager == null:
		return false

	for i in range(battle_event_manager.active_events.size()):
		var event_packet = battle_event_manager.active_events[i]
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		if str(event_packet.get("event_id", "")) != clean_event_id:
			continue
		var data_payload: Dictionary = {}
		if typeof(event_packet.get("data", {})) == TYPE_DICTIONARY:
			data_payload = event_packet.get("data", {})
		for key in values.keys():
			data_payload[key] = values[key]
		event_packet["data"] = data_payload
		battle_event_manager.active_events[i] = event_packet
		return true
	return false


func get_lane_intervention_log_text(intervention_result: Dictionary) -> String:
	if bool(intervention_result.get("nullified", false)):
		return "null " + str(intervention_result.get("event_id", "target"))
	var reason := str(intervention_result.get("blocked_reason", "none")).strip_edges()
	if reason == "":
		reason = "none"
	return reason


func get_player_evade_availability() -> Dictionary:
	# Summary: Player evade is always visible but only clickable when cooldown and weapon TODO rules pass.
	var result := {
		"status": "ready",
		"reason": "",
		"cooldown_remaining": get_player_evade_cooldown_remaining_seconds(),
		"labels": ["evade_resolution_rule", "player_evade_availability"]
	}

	if battle_v2_ended:
		result["status"] = "blocked"
		result["reason"] = "battle ended"
		return result
	if battle_action_manager == null:
		result["status"] = "blocked"
		result["reason"] = "battle action manager missing"
		return result
	if has_active_weapon_todo("player"):
		result["status"] = "blocked"
		result["reason"] = "player weapon TODO active"
		result["labels"].append("evade_blocked_weapon_todo_active")
		return result
	if has_active_evade_todo_for_side("player"):
		result["status"] = "blocked"
		result["reason"] = "evade already active"
		result["labels"].append("evade_todo_active")
		return result
	if energy_handler_v2 != null and energy_handler_v2.has_method("can_reserve"):
		if not energy_handler_v2.can_reserve(evade_energy_cost):
			result["status"] = "blocked"
			result["reason"] = "not enough energy"
			result["labels"].append("evade_energy_unavailable")
			return result
	if float(result.get("cooldown_remaining", 0.0)) > 0.0:
		result["status"] = "cooldown"
		result["reason"] = "evade cooldown active"
		result["labels"].append("evade_cooldown_active")
		return result

	result["labels"].append("evade_cooldown_ready")
	return result


func refresh_player_evade_control_state() -> void:
	# Summary: Keep the evade control visible and disabled only by cooldown, energy, or weapon TODO rules.
	if player_evade_button == null:
		return

	var availability := get_player_evade_availability()
	var status := str(availability.get("status", "blocked"))
	var cooldown_remaining := float(availability.get("cooldown_remaining", 0.0))
	player_evade_button.disabled = status != "ready"

	if player_evade_button.get_parent() == action_body_root:
		if status == "cooldown":
			player_evade_button.text = "EVADE | ready " + format_battle_value(cooldown_remaining) + "s"
		elif status == "ready":
			player_evade_button.text = "EVADE | " + format_battle_value(evade_energy_cost) + " energy"
		else:
			player_evade_button.text = "EVADE | " + str(availability.get("reason", status))
	else:
		if status == "cooldown":
			player_evade_button.text = "Evade " + ("%0.1f" % cooldown_remaining)
		else:
			player_evade_button.text = "Evade"

	if battle_ui_labels.has("player_evade_status"):
		var status_text := "Evade: ready"
		if status != "ready":
			status_text = "Evade: " + str(availability.get("reason", status))
		set_lookup_label_text("player_evade_status", status_text)


func start_player_evade_cooldown() -> void:
	# Summary: Start the shared player-side evade cooldown at queue/use time.
	player_evade_cooldown_until_msec = Time.get_ticks_msec() + int(max(evade_cooldown_seconds, 0.0) * 1000.0)


func get_player_evade_cooldown_remaining_seconds() -> float:
	# Summary: Return remaining player evade cooldown seconds for UI.
	return max(float(player_evade_cooldown_until_msec - Time.get_ticks_msec()) / 1000.0, 0.0)



func get_route_energy_log_line(route_result: Dictionary) -> String:
	# Summary: Build short queue-time energy text from ActionManager's EnergyHandler reserve bridge.
	var energy_result = route_result.get("energy_result", {})
	if typeof(energy_result) != TYPE_DICTIONARY:
		return ""

	var energy_cost: float = float(energy_result.get("energy_cost", 0.0))
	if energy_cost <= 0.0:
		return ""

	return "\nEnergy: reserved expected use " + format_battle_value(energy_cost)


func get_route_ammo_log_line(route_result: Dictionary) -> String:
	# Summary: Build short queue-time ammo text from ActionManager's AmmoHandler reserve bridge.
	var ammo_result = route_result.get("ammo_result", {})
	if typeof(ammo_result) != TYPE_DICTIONARY:
		return ""

	var ammo_cost: int = int(ammo_result.get("ammo_cost", 0))
	if ammo_cost <= 0:
		return ""

	return "\nAmmo: reserved " + str(ammo_cost) + " " + str(ammo_result.get("ammo_group", "ammo"))


func is_supported_test_action(action_id: String) -> bool:
	# Summary: Check whether this scene currently routes the clicked Battle V2 action.
	return action_id == "fire_primary_weapon" or action_id == "fire_secondary_weapon" or action_id == "switch_shield" or action_id == "load_consumable" or action_id == "execute_consumable" or action_id == "player_evade"


func prepare_queued_test_item_state(action_id: String, item_data: Dictionary) -> void:
	# Summary: Apply queue-time state needed by delayed BattleManager completion.
	if action_id != "switch_shield" and action_id != "load_consumable" and action_id != "execute_consumable":
		return

	# ------------------------------------------------------
	# BattleManager completes shield switching by moving
	# pending_shield into selected_shield on the owner unit.
	# ------------------------------------------------------
	if player_state_packet == null:
		return

	if action_id == "load_consumable":
		player_state_packet.set_loaded_consumable(item_data, "loading")
		refresh_unit_status_values()
		return

	if action_id == "execute_consumable":
		player_state_packet.set_consumable_state("executing")
		refresh_unit_status_values()
		return

	player_state_packet.pending_shield = item_data
	player_state_packet.set_shield_switching(true)
	refresh_unit_status_values()


func get_battle_v2_context_loadout_data() -> Dictionary:
	# Summary: Return the loadout packet handed off by main-mode or a safe empty loadout fallback.
	var loadout_data = battle_context.get("loadout_data", {})
	if typeof(loadout_data) == TYPE_DICTIONARY:
		return loadout_data

	return {
		"selected_primary_weapon": null,
		"selected_secondary_weapon": null,
		"selected_shield": null,
		"loaded_consumable": null,
		"loaded_consumable_state": "none",
		"equipped_upgrades": []
	}


func get_battle_v2_loadout_log_text() -> String:
	# Summary: Build short battle-log text for the player loadout handed into PlayerHandler.
	var loadout_data := get_battle_v2_context_loadout_data()
	return (
		"primary=" + str(loadout_data.get("selected_primary_weapon", "none"))
		+ " | secondary=" + str(loadout_data.get("selected_secondary_weapon", "none"))
		+ " | shield=" + str(loadout_data.get("selected_shield", "none"))
		+ " | consumable=" + str(loadout_data.get("loaded_consumable", "none"))
		+ " | upgrades=" + ",".join(sanitize_battle_upgrade_ids(loadout_data.get("equipped_upgrades", [])))
	)


func sanitize_battle_upgrade_ids(value) -> Array:
	var clean: Array = []
	if typeof(value) != TYPE_ARRAY:
		return clean

	for raw_id in value:
		var upgrade_id := get_loadout_item_id(raw_id)
		if upgrade_id == "":
			continue
		if clean.has(upgrade_id):
			continue
		if not battle_inventory_snapshot_has_item(upgrade_id):
			continue
		if not is_battle_upgrade_item(get_main_project_item_data(upgrade_id)):
			continue
		clean.append(upgrade_id)
		if clean.size() >= 3:
			break

	return clean


func is_battle_upgrade_item(item_data: Dictionary) -> bool:
	if item_data.is_empty():
		return false
	return str(item_data.get("item_type", item_data.get("type", ""))).strip_edges().to_lower() == "upgrade"


func get_current_battle_upgrade_ids() -> Array:
	return sanitize_battle_upgrade_ids(get_battle_v2_context_loadout_data().get("equipped_upgrades", []))


func get_current_battle_upgrade_meta_totals() -> Dictionary:
	return build_battle_upgrade_meta_totals(get_current_battle_upgrade_ids())


func build_battle_upgrade_meta_totals(upgrade_ids: Array) -> Dictionary:
	var totals := get_empty_battle_upgrade_meta()
	for raw_id in upgrade_ids:
		var upgrade_id := get_loadout_item_id(raw_id)
		if upgrade_id == "":
			continue
		var item_data := get_main_project_item_data(upgrade_id)
		if not is_battle_upgrade_item(item_data):
			continue
		var meta = item_data.get("battle_upgrade_meta", {})
		if typeof(meta) != TYPE_DICTIONARY:
			continue
		for key in totals.keys():
			totals[key] = int(totals.get(key, 0)) + int(meta.get(key, 0))
	return totals


func get_empty_battle_upgrade_meta() -> Dictionary:
	return {
		"max_hull_bonus": 0,
		"max_energy_bonus": 0,
		"primary_damage_bonus": 0,
		"secondary_damage_bonus": 0,
		"secondary_burst_bonus": 0
	}


func get_saved_base_player_max_stat(key: String, fallback: float) -> float:
	var saved_value := fallback
	if typeof(battle_player_state_save_data) == TYPE_DICTIONARY and battle_player_state_save_data.has(key):
		saved_value = float(battle_player_state_save_data.get(key, fallback))
	if saved_value <= 0.0:
		saved_value = fallback
	return max(saved_value, 1.0)



func get_prepared_player_state_source(prepared_player_state = null):
	# Summary: Prefer the bridge snapshot for battle-start stats; fall back to PlayerHandler state.
	if typeof(battle_player_state_save_data) == TYPE_DICTIONARY and not battle_player_state_save_data.is_empty():
		return battle_player_state_save_data
	return prepared_player_state

func get_battle_v2_player_energy_config(source_player_state = null) -> Dictionary:
	# Summary: Seed Battle V2 EnergyHandler from PlayerState, with main EnergyHandler as the fallback.
	var context_energy = battle_context.get("energy_handler", null)
	var current_energy := get_energy_source_float(
		source_player_state,
		"player_energy_current",
		get_energy_source_float(source_player_state, "energy_current", get_energy_source_float(context_energy, "current_energy", 100.0))
	)
	var max_energy := get_energy_source_float(
		source_player_state,
		"player_energy_max",
		get_energy_source_float(source_player_state, "energy_max", get_energy_source_float(context_energy, "max_energy", 100.0))
	)
	if max_energy <= 0.0:
		max_energy = max(current_energy, 100.0)
	var base_max_energy = max(max_energy, 1.0)
	var upgrade_meta := get_current_battle_upgrade_meta_totals()
	max_energy = max(base_max_energy + float(upgrade_meta.get("max_energy_bonus", 0)), 1.0)
	var regen_per_second := get_energy_source_float(
		source_player_state,
		"player_energy_regen_per_second",
		get_energy_source_float(
			source_player_state,
			"energy_regen_per_second",
			get_energy_source_float(context_energy, "regen_per_second", get_energy_source_float(context_energy, "recharge_rate", 8.0))
		)
	)

	current_energy = clamp(current_energy, 0.0, max_energy)
	if regen_per_second < 0.0:
		regen_per_second = 0.0

	return {
		"current_energy": current_energy,
		"max_energy": max_energy,
		"base_max_energy": base_max_energy,
		"regen_per_second": regen_per_second
	}


func get_energy_source_float(source, field_name: String, fallback: float) -> float:
	if source == null:
		return fallback
	if typeof(source) == TYPE_DICTIONARY:
		var dictionary_source: Dictionary = source
		if dictionary_source.has(field_name):
			return float(dictionary_source.get(field_name, fallback))
		return fallback
	if source is Object:
		var value = source.get(field_name)
		if value != null:
			return float(value)
	return fallback


func get_player_state_float(source_player_state, field_name: String, fallback: float) -> float:
	# Summary: Read player-state values from either a live PlayerState object or plain snapshot dictionary.
	if source_player_state == null:
		return fallback
	if typeof(source_player_state) == TYPE_DICTIONARY:
		var dictionary_source: Dictionary = source_player_state
		if dictionary_source.has(field_name):
			return float(dictionary_source.get(field_name, fallback))
		return fallback
	if not (source_player_state is Object):
		return fallback

	var value = source_player_state.get(field_name)
	if value == null:
		return fallback

	return float(value)


func setup_battle_v2_handlers() -> void:
	# Summary: Create isolated Battle V2 helper handlers for packet building and TODO queue testing.
	if Globals.print_priority_5:
		print("Battle V2 setting up packet/event handlers.")

	# ------------------------------------------------------
	# PlayerHandler prepares player-owned starting state first.
	# EnergyHandler still owns runtime energy math after setup.
	# ------------------------------------------------------
	player_handler_v2 = PlayerHandler.new()
	player_handler_v2.name = "Battle_V2_PlayerHandler"
	add_child(player_handler_v2)
	player_handler_v2.setup({
		"inventory": battle_context.get("inventory", null),
		"inventory_handler": battle_context.get("inventory_handler", battle_context.get("inventory", null)),
		"energy_handler": battle_context.get("energy_handler", null),
		"action_manager": battle_context.get("action_manager", null),
		"battle_manager": battle_manager_v2,
		"battle_action_packet_builder": BattleActionPacketBuilder.new(),
		"event_manager": null,
		"stat_effect_handler": null
	})
	if Globals.print_priority_5:
		print("[player_handler_setup_refs] inventory=", battle_context.get("inventory", null))
		print("[player_handler_setup_refs] inventory_handler=", battle_context.get("inventory_handler", battle_context.get("inventory", null)))
		print("[player_handler_setup_refs] action_manager=", battle_context.get("action_manager", null))
		print("[player_handler_setup_refs] source_energy_handler=", battle_context.get("energy_handler", null))
	var player_prepare_result := player_handler_v2.prepare_player_for_battle({
		"battle_id": battle_id,
		"loadout_data": get_battle_v2_context_loadout_data(),
		"energy_handler": battle_context.get("energy_handler", null),
		"energy_handler_ref": battle_context.get("energy_handler", null),
		"player_state_save_data": battle_player_state_save_data.duplicate(true),
		"player_state_data": battle_player_state_save_data.duplicate(true),
		"player_save_data": battle_player_state_save_data.duplicate(true)
	})

	if Globals.print_priority_5:
		print("Battle V2 PlayerHandler prepare result: ", player_prepare_result)

	# ------------------------------------------------------
	# Local EnergyHandler starts from PlayerHandler/PlayerState,
	# then owns regen, reserve, spend, and shield drain in battle.
	# ------------------------------------------------------
	var player_energy_config := get_battle_v2_player_energy_config(get_prepared_player_state_source(player_handler_v2.get_player_state()))
	energy_handler_v2 = EnergyHandler.new()
	energy_handler_v2.name = "Battle_V2_EnergyHandler"
	energy_handler_v2.setup(
		null,
		float(player_energy_config.get("current_energy", 100.0)),
		float(player_energy_config.get("max_energy", 100.0)),
		float(player_energy_config.get("regen_per_second", 8.0))
	)
	add_child(energy_handler_v2)
	player_handler_v2.set_energy_handler_ref(energy_handler_v2)

	ammo_handler_v2 = AmmoHandler.new()
	ammo_handler_v2.name = "Battle_V2_AmmoHandler"
	add_child(ammo_handler_v2)

	player_state_packet = build_player_state_packet(player_handler_v2.get_player_state(), battle_player_state_save_data)
	active_enemy = build_enemy_state_packet(handoff_enemy)
	setup_enemy_energy_handler_from_active_enemy()
	sync_energy_handler_shield_drain_from_player_state()

	# ------------------------------------------------------
	# StatEffectManager is available for later signal/pulse
	# routes; no active effects are applied in this slice.
	# ------------------------------------------------------
	stat_effect_handler_v2 = StatsEffectManager.new()
	stat_effect_handler_v2.name = "Battle_V2_StatsEffectManager"
	add_child(stat_effect_handler_v2)

	# ------------------------------------------------------
	# EnemyLogic is available for the coming enemy intent slice.
	# ------------------------------------------------------
	enemy_logic_v2 = EnemyLogic.new()
	enemy_logic_v2.name = "Battle_V2_EnemyLogic"
	add_child(enemy_logic_v2)
	if enemy_logic_v2.has_method("set_enemy_evade_min_cooldown_seconds"):
		enemy_logic_v2.set_enemy_evade_min_cooldown_seconds(evade_cooldown_seconds)

	# ------------------------------------------------------
	# BattleManager owns completed TODO resolution.
	# ------------------------------------------------------
	battle_manager_v2 = BattleV2BattleManagerScript.new()
	battle_manager_v2.name = "Battle_V2_BattleManager"
	battle_manager_v2.battle_active = true
	battle_manager_v2.active_player_state = player_state_packet
	battle_manager_v2.active_enemy = active_enemy
	battle_manager_v2.energy_handler = energy_handler_v2
	battle_manager_v2.enemy_energy_handler = enemy_energy_handler_v2
	battle_manager_v2.ammo_handler = ammo_handler_v2
	battle_manager_v2.inventory = battle_ammo_inventory_source
	battle_manager_v2.stat_effect_handler = stat_effect_handler_v2
	add_child(battle_manager_v2 as Node)

	player_handler_v2.battle_manager = battle_manager_v2
	player_handler_v2.stat_effect_handler = stat_effect_handler_v2

	# ------------------------------------------------------
	# EventManager owns TODO packet validation and active queue storage.
	# ------------------------------------------------------
	battle_event_manager = BattleV2EventManager.new()
	battle_event_manager.name = "Battle_V2_EventManager"
	battle_event_manager.battle_manager = battle_manager_v2
	add_child(battle_event_manager)
	battle_manager_v2.event_manager = battle_event_manager

	player_handler_v2.event_manager = battle_event_manager

	# ------------------------------------------------------
	# ActionManager_battle routes action clicks to PacketBuilder,
	# then queues the built packet with EventManager.
	# ------------------------------------------------------
	battle_action_manager = ActionManager_battle.new()
	battle_action_manager.name = "Battle_V2_ActionManager"
	add_child(battle_action_manager)

	battle_action_manager.battle_active = true
	battle_action_manager.current_battle_id = battle_id
	battle_action_manager.player_state = player_state_packet
	battle_action_manager.active_enemy = active_enemy
	battle_action_manager.event_manager = battle_event_manager
	battle_action_manager.energy_handler = energy_handler_v2
	battle_action_manager.ammo_handler = ammo_handler_v2
	battle_action_manager.inventory_ref = battle_ammo_inventory_source
	battle_action_manager.battle_action_packet_builder = BattleActionPacketBuilder.new()
	player_handler_v2.action_manager = battle_action_manager
	player_handler_v2.battle_action_packet_builder = battle_action_manager.battle_action_packet_builder

	# ------------------------------------------------------
	# EnemyBattleController owns the active enemy think loop.
	# The scene still owns UI, cleanup, and battle end flow.
	# ------------------------------------------------------
	enemy_battle_controller = EnemyBattleControllerScript.new()
	enemy_battle_controller.name = "Battle_V2_EnemyBattleController"
	add_child(enemy_battle_controller)
	enemy_battle_controller.setup({
		"battle_scene": self,
		"battle_id": battle_id,
		"enemy_logic": enemy_logic_v2,
		"event_manager": battle_event_manager,
		"action_manager": battle_action_manager,
		"battle_manager": battle_manager_v2,
		"active_enemy": active_enemy,
		"player_state": player_state_packet,
		"enemy_energy_handler": enemy_energy_handler_v2,
		"item_db_snapshot": battle_item_db_snapshot,
		"log_label": log_label,
		"refresh_todo_callable": Callable(self, "refresh_todo_timeline_from_event_manager"),
		"refresh_unit_callable": Callable(self, "refresh_unit_status_values"),
		"think_interval": enemy_think_interval,
		"wait_cooldown_seconds": enemy_wait_cooldown_seconds,
		"action_cooldown_seconds": enemy_action_cooldown_seconds,
		"evade_cooldown_seconds": evade_cooldown_seconds,
		"evade_duration_seconds": evade_todo_duration_seconds,
		"primary_spam_gate_seconds": PRIMARY_WEAPON_SPAM_GATE_SECONDS,
		"secondary_spam_gate_seconds": SECONDARY_WEAPON_SPAM_GATE_SECONDS
	})


func build_player_state_packet(source_player_state = null, player_state_snapshot: Dictionary = {}) -> BattleV2UnitAdapter:
	# Summary: Build the temporary player adapter from bridge PlayerState save data, falling back to PlayerHandler-prepared state.
	var unit: BattleV2UnitAdapter = BattleV2UnitAdapter.new()
	unit.name = "Battle_V2_PlayerState"

	var loadout_data := get_battle_v2_context_loadout_data()
	var loadout_selected_primary = loadout_data.get("selected_primary_weapon", null)
	var loadout_selected_secondary = loadout_data.get("selected_secondary_weapon", null)
	var loadout_selected_shield = loadout_data.get("selected_shield", null)
	var loadout_loaded_consumable = loadout_data.get("loaded_consumable", null)
	var equipped_upgrades := sanitize_battle_upgrade_ids(loadout_data.get("equipped_upgrades", []))
	var upgrade_meta := build_battle_upgrade_meta_totals(equipped_upgrades)
	var selected_primary = loadout_selected_primary
	var selected_secondary = loadout_selected_secondary
	var selected_shield = loadout_selected_shield
	var loaded_consumable = loadout_loaded_consumable
	var loaded_consumable_state = loadout_data.get("loaded_consumable_state", "none")
	var player_hull_current := 100.0
	var player_hull_max := 100.0
	var base_player_hull_max := 100.0
	var shield_power_level := 0
	var shield_hp_current := 0.0

	var source = get_prepared_player_state_source(source_player_state)
	if typeof(player_state_snapshot) == TYPE_DICTIONARY and not player_state_snapshot.is_empty():
		source = player_state_snapshot

	if source != null:
		if typeof(source) == TYPE_DICTIONARY:
			var source_dict: Dictionary = source
			selected_primary = source_dict.get("selected_primary_weapon", selected_primary)
			selected_secondary = source_dict.get("selected_secondary_weapon", selected_secondary)
			selected_shield = source_dict.get("selected_shield", selected_shield)
			loaded_consumable = source_dict.get("loaded_consumable", loaded_consumable)
			loaded_consumable_state = str(source_dict.get("loaded_consumable_state", loaded_consumable_state))
		elif source is Object:
			selected_primary = source.get("selected_primary_weapon")
			selected_secondary = source.get("selected_secondary_weapon")
			selected_shield = source.get("selected_shield")
			loaded_consumable = source.get("loaded_consumable")
			loaded_consumable_state = str(source.get("loaded_consumable_state"))

		player_hull_current = get_player_state_float(source, "player_hull_current", get_player_state_float(source, "hull_current", player_hull_current))
		player_hull_max = get_player_state_float(source, "player_hull_max", get_player_state_float(source, "hull_max", player_hull_max))
		shield_power_level = int(get_player_state_float(source, "shield_power_level", float(shield_power_level)))
		shield_hp_current = get_player_state_float(source, "shield_hp_current", shield_hp_current)

	# Battle V2 loadout_data is the authoritative equipped-slice handoff.
	# PlayerState save snapshots often carry null / "<null>" selected slots, so do not let
	# those stale save values erase the battle loadout that the inventory slice just supplied.
	if _has_loadout_item_value(loadout_selected_primary):
		selected_primary = loadout_selected_primary
	if _has_loadout_item_value(loadout_selected_secondary):
		selected_secondary = loadout_selected_secondary
	if _has_loadout_item_value(loadout_selected_shield):
		selected_shield = loadout_selected_shield
	if _has_loadout_item_value(loadout_loaded_consumable):
		loaded_consumable = loadout_loaded_consumable
		loaded_consumable_state = str(loadout_data.get("loaded_consumable_state", loaded_consumable_state))

	if loadout_data.has("shield_power_level"):
		shield_power_level = int(clamp(int(loadout_data.get("shield_power_level", shield_power_level)), 0, 4))
	elif _has_loadout_item_value(selected_shield) and shield_power_level <= 0:
		shield_power_level = int(clamp(int(loadout_data.get("default_shield_power_level", 2)), 0, 4))

	if player_hull_max <= 0.0:
		player_hull_max = max(player_hull_current, 1.0)
	base_player_hull_max = player_hull_max
	player_hull_max = max(base_player_hull_max + float(upgrade_meta.get("max_hull_bonus", 0)), 1.0)
	player_hull_current = clamp(player_hull_current, 0.0, player_hull_max)
	var player_energy_config := get_battle_v2_player_energy_config(source)

	var selected_shield_id := get_loadout_item_id(selected_shield)
	if selected_shield_id != "" and not battle_inventory_snapshot_has_item(selected_shield_id):
		selected_shield = null
		shield_hp_current = 0.0
		shield_power_level = 0

	if _has_loadout_item_value(selected_shield) and typeof(selected_shield) != TYPE_DICTIONARY:
		var normalized_shield := get_normalized_loadout_item_data(str(selected_shield), TAB_SHIELDS)
		if not normalized_shield.is_empty():
			selected_shield = normalized_shield

	if shield_hp_current <= 0.0 and typeof(selected_shield) == TYPE_DICTIONARY:
		shield_hp_current = float(selected_shield.get("shield_hp_max", selected_shield.get("hp_max", 0.0)))

	unit.setup_from_packet({
		"object_id": "player_ship",
		"object_type": "battle_unit",
		"shared_meta": SharedObjectMeta.build_meta("player_ship", "battle_unit", "Player Ship", Vector3i.ZERO, Vector3.ZERO, {
			"labels": ["battle_v2_player_unit"]
		}),
		"unit_id": "player_ship",
		"display_name": "Player Ship",
		"unit_side": "player",
		"hull_current": player_hull_current,
		"hull_max": player_hull_max,
		"player_hull_current": player_hull_current,
		"player_hull_max": player_hull_max,
		"base_player_hull_max": base_player_hull_max,
		"energy_current": float(player_energy_config.get("current_energy", 100.0)),
		"energy_max": float(player_energy_config.get("max_energy", 100.0)),
		"energy_regen_per_second": float(player_energy_config.get("regen_per_second", 8.0)),
		"player_energy_current": float(player_energy_config.get("current_energy", 100.0)),
		"player_energy_max": float(player_energy_config.get("max_energy", 100.0)),
		"player_energy_regen_per_second": float(player_energy_config.get("regen_per_second", 8.0)),
		"base_player_energy_max": float(player_energy_config.get("base_max_energy", player_energy_config.get("max_energy", 100.0))),
		"player_good_lock": true,
		"player_lock_disabled": false,
		"selected_primary_weapon": selected_primary,
		"selected_secondary_weapon": selected_secondary,
		"selected_shield": selected_shield,
		"loaded_consumable": loaded_consumable,
		"loaded_consumable_state": loaded_consumable_state,
		"equipped_upgrades": equipped_upgrades.duplicate(true),
		"battle_upgrade_meta": upgrade_meta.duplicate(true),
		"shield_power_level": shield_power_level,
		"shield_hp_current": shield_hp_current,
		"shield_hp_max": float(selected_shield.get("shield_hp_max", 0.0)) if typeof(selected_shield) == TYPE_DICTIONARY else 0.0
	})
	add_child(unit)
	return unit


func build_enemy_state_packet(source_enemy) -> BattleV2UnitAdapter:
	# Summary: Build a temporary enemy battle-state object from the main scene handoff enemy.
	var enemy_name: String = get_handoff_enemy_name(source_enemy)
	var enemy_hp: float = get_handoff_enemy_hp(source_enemy)
	var enemy_primary_weapon := normalize_enemy_battle_item_id(str(get_handoff_enemy_meta_value(source_enemy, "primary", "enemy_light_laser")).strip_edges())
	var enemy_secondary_weapon := normalize_enemy_battle_item_id(str(get_handoff_enemy_meta_value(source_enemy, "secondary", "enemy_snap_missile")).strip_edges())
	var enemy_shield_id := normalize_enemy_battle_item_id(str(get_handoff_enemy_meta_value(source_enemy, "shield", "basic_shield_mk1")).strip_edges())
	var enemy_item_stacks := get_handoff_enemy_item_stacks(source_enemy)
	var enemy_shield_data := get_main_project_item_data(enemy_shield_id)
	if enemy_shield_id != "" and not enemy_shield_data.is_empty() and int(enemy_item_stacks.get(enemy_shield_id, 0)) <= 0:
		enemy_item_stacks[enemy_shield_id] = 1
	var enemy_energy_max := float(get_handoff_enemy_meta_value(source_enemy, "energy_max", 100.0))
	var enemy_shared_meta := get_handoff_enemy_shared_meta(source_enemy, enemy_name)
	if enemy_energy_max <= 0.0:
		enemy_energy_max = 100.0
	var unit: BattleV2UnitAdapter = BattleV2UnitAdapter.new()
	unit.name = "Battle_V2_EnemyState"
	unit.setup_from_packet({
		"object_id": str(enemy_shared_meta.get("object_id", get_source_enemy_id(source_enemy))),
		"object_type": str(enemy_shared_meta.get("object_type", "enemy")),
		"enemy_serial": str(enemy_shared_meta.get("enemy_serial", "")),
		"enemy_template_id": str(enemy_shared_meta.get("enemy_template_id", "")),
		"shared_meta": enemy_shared_meta,
		"unit_id": "enemy_target",
		"display_name": enemy_name,
		"unit_side": "enemy",
		"hull_current": enemy_hp,
		"hull_max": get_handoff_enemy_max_hp(source_enemy, enemy_hp),
		"attack": float(get_handoff_enemy_attack()),
		"behavior_profile": get_handoff_enemy_behavior_profile(source_enemy),
		"behavior_values": get_handoff_enemy_behavior_values(source_enemy),
		"selected_primary_weapon": enemy_primary_weapon,
		"selected_secondary_weapon": enemy_secondary_weapon,
		"selected_enemy_shield": enemy_shield_id,
		"primary_available": enemy_primary_weapon != "",
		"secondary_available": enemy_secondary_weapon != "",
		"can_evade": true,
		"enemy_energy_current": enemy_energy_max,
		"enemy_energy_max": enemy_energy_max,
		"enemy_reserved_energy": 0.0,
		"enemy_ammo_small": get_enemy_ammo_count_from_stacks(enemy_item_stacks, "small"),
		"enemy_ammo_medium": get_enemy_ammo_count_from_stacks(enemy_item_stacks, "medium"),
		"enemy_ammo_large": get_enemy_ammo_count_from_stacks(enemy_item_stacks, "large"),
		"loaded_consumable": null,
		"loaded_consumable_state": "none",
		"consumable_ready": false,
		"enemy_loaded_consumable": null,
		"enemy_consumable_ready": false,
		"enemy_good_lock": false,
		"enemy_lock_disabled": false,
		"shield_power_level": 2 if not enemy_shield_data.is_empty() else 0,
		"shield_hp_current": float(enemy_shield_data.get("shield_hp_max", 0.0)),
		"shield_hp_max": float(enemy_shield_data.get("shield_hp_max", 0.0)),
		"selected_shield": enemy_shield_data if not enemy_shield_data.is_empty() else null,
		"enemy_item_stacks": enemy_item_stacks,
		"enemy_signal_defense": 0.0
	})

	# Keep a reference to the original world enemy.
	# BattleManager damages this adapter, but EnemyHandler must remove the real enemy later.
	if unit.has_method("bind_world_enemy"):
		unit.bind_world_enemy(source_enemy, get_source_enemy_id(source_enemy))

	add_child(unit)
	return unit


func get_handoff_enemy_item_stacks(source_enemy) -> Dictionary:
	# Summary: Read enemy-held stackable items from direct meta or shared_meta, with ammo/consumable fallbacks.
	var raw_stacks = get_handoff_enemy_meta_value(source_enemy, "item_stacks", {})
	var stacks := {}
	if typeof(raw_stacks) == TYPE_DICTIONARY:
		stacks = raw_stacks.duplicate(true)

	var normalized_stacks := {}
	for stack_item_id in stacks.keys():
		var normalized_id := normalize_enemy_battle_item_id(str(stack_item_id))
		normalized_stacks[normalized_id] = int(normalized_stacks.get(normalized_id, 0)) + max(int(stacks.get(stack_item_id, 0)), 0)
	stacks = normalized_stacks

	for item_id in ["small_kinetic_rounds", "medium_kinetic_rounds", "large_kinetic_rounds", "repair_kit", "recharge_kit"]:
		if stacks.has(item_id):
			stacks[item_id] = max(int(stacks[item_id]), 0)

	var legacy_small := int(get_handoff_enemy_meta_value(source_enemy, "enemy_ammo_small", 0))
	var legacy_medium := int(get_handoff_enemy_meta_value(source_enemy, "enemy_ammo_medium", 0))
	var legacy_large := int(get_handoff_enemy_meta_value(source_enemy, "enemy_ammo_large", 0))
	if legacy_small > 0 and not stacks.has("small_kinetic_rounds"):
		stacks["small_kinetic_rounds"] = legacy_small
	if legacy_medium > 0 and not stacks.has("medium_kinetic_rounds"):
		stacks["medium_kinetic_rounds"] = legacy_medium
	if legacy_large > 0 and not stacks.has("large_kinetic_rounds"):
		stacks["large_kinetic_rounds"] = legacy_large

	var consumable_id := normalize_enemy_battle_item_id(str(get_handoff_enemy_meta_value(source_enemy, "consumable", "")).strip_edges())
	if consumable_id != "" and not stacks.has(consumable_id):
		stacks[consumable_id] = 1

	return stacks


func normalize_enemy_battle_item_id(item_id: String) -> String:
	# Summary: Keep older enemy meta aliases compatible with the current item database.
	var clean_id := item_id.strip_edges()
	match clean_id:
		"enemy_light_laser":
			return "e_basic_energy_pew_pew"
		"enemy_snap_missile":
			return "micro_torpedo_launcher"
		"enemy_rail_snap":
			return "railgun_mk1"
		"recovery_kit":
			return "repair_kit"
		_:
			return clean_id


func get_enemy_ammo_count_from_stacks(stacks: Dictionary, ammo_group: String) -> int:
	# Summary: Count enemy-held ammo stacks by item metadata group.
	var wanted_group := ammo_group.strip_edges().to_lower()
	var total := 0
	for item_id in stacks.keys():
		var item_data := get_main_project_item_data(str(item_id))
		if item_data.is_empty():
			continue
		if str(item_data.get("ammo_group", "")).strip_edges().to_lower() == wanted_group:
			total += max(int(stacks.get(item_id, 0)), 0)
	return total


func setup_enemy_energy_handler_from_active_enemy() -> void:
	# Summary: Give the active enemy its own Battle V2 energy reserve/regen handler.
	if enemy_energy_handler_v2 != null:
		enemy_energy_handler_v2.queue_free()
		enemy_energy_handler_v2 = null

	var enemy_max_energy := 100.0
	var enemy_current_energy := 100.0
	if active_enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
		enemy_max_energy = max(enemy_state.enemy_energy_max, 0.0)
		if enemy_max_energy <= 0.0:
			enemy_max_energy = 100.0
		enemy_current_energy = clamp(enemy_state.enemy_energy_current, 0.0, enemy_max_energy)

	enemy_energy_handler_v2 = EnergyHandler.new()
	enemy_energy_handler_v2.name = "Battle_V2_EnemyEnergyHandler"
	enemy_energy_handler_v2.setup(null, enemy_current_energy, enemy_max_energy, 8.0)
	add_child(enemy_energy_handler_v2)
	sync_active_enemy_energy_from_handler()


func sync_active_enemy_energy_from_handler() -> void:
	# Summary: Mirror enemy EnergyHandler state into the temporary enemy adapter for logic/UI snapshots.
	if enemy_energy_handler_v2 == null:
		return
	if not (active_enemy is BattleV2UnitAdapter):
		return

	var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
	enemy_state.enemy_energy_current = enemy_energy_handler_v2.current_energy
	enemy_state.enemy_energy_max = enemy_energy_handler_v2.max_energy
	enemy_state.enemy_reserved_energy = enemy_energy_handler_v2.reserved_energy


func get_handoff_enemy_name(source_enemy) -> String:
	# Summary: Read a display name from an Enemy object, BattleV2Enemy, dictionary, or fallback.
	if source_enemy is Enemy or source_enemy is BattleV2Enemy:
		return source_enemy.enemy_name
	if source_enemy is Dictionary:
		return str(source_enemy.get("name", source_enemy.get("enemy_name", "Unknown enemy")))
	return "Unknown enemy"


func get_handoff_enemy_hp(source_enemy) -> float:
	# Summary: Read current hull from an Enemy object, BattleV2Enemy, dictionary, or fallback.
	if source_enemy is Enemy or source_enemy is BattleV2Enemy:
		return float(source_enemy.hp)
	if source_enemy is Dictionary:
		return float(source_enemy.get("hp", 100.0))
	return 100.0


func get_handoff_enemy_max_hp(source_enemy, fallback: float = 100.0) -> float:
	# Summary: Read max hull from an Enemy object, BattleV2Enemy, dictionary, or fallback.
	if source_enemy is Enemy or source_enemy is BattleV2Enemy:
		return float(source_enemy.max_hp)
	if source_enemy is Dictionary:
		return float(source_enemy.get("max_hp", fallback))
	return fallback


func get_handoff_enemy_attack() -> int:
	# Summary: Read attack value from the original handoff enemy for display only.
	if handoff_enemy is Enemy or handoff_enemy is BattleV2Enemy:
		return int(handoff_enemy.attack)
	if handoff_enemy is Dictionary:
		return int(handoff_enemy.get("attack", 0))
	return 0


func get_handoff_enemy_behavior_profile(source_enemy) -> String:
	# Summary: Read a behavior profile from the handoff enemy, routing Smart Guy test aliases through smart_guy_3.
	var profile_id := "smart_guy_3"
	if source_enemy is Dictionary:
		profile_id = str(source_enemy.get("behavior_profile", "smart_guy_3"))
	elif source_enemy is Object:
		var profile_value = source_enemy.get("behavior_profile")
		if profile_value != null:
			profile_id = str(profile_value)
	return normalize_enemy_behavior_profile_for_battle_v2(profile_id)


func normalize_enemy_behavior_profile_for_battle_v2(profile_id: String) -> String:
	# Summary: s1.2 battle Smart Guy aliases use smart_guy_3 unless an explicit versioned profile is provided.
	var clean_id := profile_id.strip_edges().to_lower()
	if clean_id == "" or clean_id == "smart_guy" or clean_id == "test_smart_guy":
		return "smart_guy_3"
	return clean_id


func get_handoff_enemy_behavior_values(source_enemy) -> Dictionary:
	# Summary: Read optional enemy behavior tuning values from handoff meta.
	var values = get_handoff_enemy_meta_value(source_enemy, "behavior_values", {})
	if typeof(values) == TYPE_DICTIONARY:
		return values.duplicate(true)
	return {}


func get_handoff_enemy_meta_value(source_enemy, key: String, fallback):
	# Summary: Read optional enemy metadata from object or dictionary handoffs.
	if source_enemy == null:
		return fallback

	if source_enemy is Dictionary:
		if source_enemy.has("data_slice") and typeof(source_enemy.get("data_slice", {})) == TYPE_DICTIONARY:
			var data_slice: Dictionary = source_enemy.get("data_slice", {})
			if data_slice.has("shared_meta") and typeof(data_slice.get("shared_meta", {})) == TYPE_DICTIONARY:
				return data_slice.get("shared_meta", {}).get(key, source_enemy.get(key, fallback))
			return data_slice.get(key, source_enemy.get(key, fallback))
		if source_enemy.has("shared_meta") and typeof(source_enemy.get("shared_meta", {})) == TYPE_DICTIONARY:
			return source_enemy.get("shared_meta", {}).get(key, source_enemy.get(key, fallback))
		return source_enemy.get(key, fallback)

	if source_enemy is Object:
		var value = source_enemy.get(key)
		if value != null:
			return value

	return fallback


func get_handoff_enemy_shared_meta(source_enemy, fallback_name: String = "Enemy") -> Dictionary:
	# Summary: Read a shared object packet from enemy handoff data, or build one from old enemy fields.
	if source_enemy is Dictionary:
		var source = source_enemy.duplicate(true)
		if source_enemy.has("data_slice") and typeof(source_enemy.get("data_slice", {})) == TYPE_DICTIONARY:
			var data_slice: Dictionary = source_enemy.get("data_slice", {})
			for key in data_slice.keys():
				source[key] = data_slice[key]
		return SharedObjectMeta.build_meta(
			str(source.get("object_id", source.get("enemy_id", source.get("id", "")))),
			"enemy",
			str(source.get("display_name", source.get("enemy_name", source.get("name", fallback_name)))),
			source.get("sector_pos", source.get("sector", Vector3i.ZERO)),
			source.get("local_pos", source.get("local", Vector3.ZERO)),
			source
		)

	if source_enemy is Object:
		if source_enemy.has_method("sync_shared_meta"):
			return source_enemy.sync_shared_meta()
		if source_enemy.has_method("get_shared_meta_save_data"):
			var save_meta = source_enemy.get_shared_meta_save_data()
			if typeof(save_meta) == TYPE_DICTIONARY:
				return SharedObjectMeta.build_meta(
					str(save_meta.get("object_id", "")),
					str(save_meta.get("object_type", "enemy")),
					str(save_meta.get("display_name", fallback_name)),
					save_meta.get("sector_pos", Vector3i.ZERO),
					save_meta.get("local_pos", Vector3.ZERO),
					save_meta
				)
		var source := {
			"object_id": str(source_enemy.get("object_id")) if source_enemy.get("object_id") != null else "",
			"enemy_name": str(source_enemy.get("enemy_name")) if source_enemy.get("enemy_name") != null else fallback_name,
			"enemy_type": str(source_enemy.get("enemy_type")) if source_enemy.get("enemy_type") != null else "enemy",
			"sector_pos": source_enemy.get("sector_pos") if source_enemy.get("sector_pos") != null else Vector3i.ZERO,
			"local_pos": source_enemy.get("local_pos") if source_enemy.get("local_pos") != null else Vector3.ZERO,
			"tier": int(source_enemy.get("tier")) if source_enemy.get("tier") != null else 1,
			"has_event": bool(source_enemy.get("has_event")) if source_enemy.get("has_event") != null else false
		}
		var source_shared_meta = source_enemy.get("shared_meta")
		if typeof(source_shared_meta) == TYPE_DICTIONARY:
			for key in source_shared_meta.keys():
				source[key] = source_shared_meta[key]
		return SharedObjectMeta.build_meta(
			str(source.get("object_id", "")),
			"enemy",
			str(source.get("enemy_name", fallback_name)),
			source.get("sector_pos", Vector3i.ZERO),
			source.get("local_pos", Vector3.ZERO),
			source
		)

	return SharedObjectMeta.build_meta("", "enemy", fallback_name, Vector3i.ZERO, Vector3.ZERO, {})


func refresh_todo_timeline_from_event_manager() -> void:
	call_deferred("scroll_battle_log_to_bottom")
	# Summary: Display the current EventManager active TODO queue in the placeholder timeline labels.
	if battle_event_manager == null:
		set_lookup_label_text("todo_row_1", "EventManager missing.")
		set_lookup_label_text("todo_row_2", "No queue data available.")
		refresh_battle_v3_pipeline_from_event_manager([])
		return

	var active_events: Array = get_sorted_active_todo_events()
	report_battle_v2_todo_active_to_ui_handler(active_events)
	refresh_battle_v3_pipeline_from_event_manager(active_events)
	if active_events.is_empty():
		if latest_todo_status_text != "":
			set_lookup_label_text("todo_row_1", latest_todo_status_text)
			set_lookup_label_text("todo_row_2", "BattleManager handoff complete.")
		else:
			set_lookup_label_text("todo_row_1", "No battle TODOs queued.")
			set_lookup_label_text("todo_row_2", "EventManager active queue is empty.")
		return

	var next_event: Dictionary = active_events[0]
	set_lookup_label_text(
		"todo_row_1",
		"NEXT: " + build_todo_event_line(next_event)
	)

	var rest_lines: Array = []
	for i in range(1, active_events.size()):
		if rest_lines.size() >= 3:
			break
		rest_lines.append(build_todo_event_line(active_events[i]))

	if rest_lines.is_empty():
		set_lookup_label_text("todo_row_2", "Queue: no later events.")
		return

	var hidden_count: int = max(active_events.size() - 1 - rest_lines.size(), 0)
	var rest_text := "Queue:\n" + "\n".join(rest_lines)
	if hidden_count > 0:
		rest_text += "\n+" + str(hidden_count) + " more"
	set_lookup_label_text("todo_row_2", rest_text)
	call_deferred("scroll_battle_log_to_bottom")
	

func get_sorted_active_todo_events() -> Array:
	# Summary: Return active TODOs sorted by next completion time across player and enemy events.
	if battle_event_manager == null:
		return []

	var sorted_events: Array = battle_event_manager.active_events.duplicate(true)
	sorted_events.sort_custom(func(a, b): return float(a.get("time_remaining", 0.0)) < float(b.get("time_remaining", 0.0)))
	return sorted_events


func refresh_battle_v3_pipeline_from_event_manager(active_events_override: Array = []) -> void:
	# Summary: Feed Battle V3 display-only chips from the real EventManager TODO state.
	if battle_v3_pipeline_widget == null:
		sync_battle_v2_procedural_lane_layer()
		return

	var active_events: Array = active_events_override
	if active_events.is_empty() and battle_event_manager != null:
		active_events = get_sorted_active_todo_events()

	var snapshot := build_battle_v3_pipeline_snapshot(active_events)
	battle_v3_pipeline_widget.set_snapshot(snapshot)
	sync_battle_v2_procedural_lane_layer(snapshot)


func build_battle_v3_pipeline_snapshot(active_events: Array = []) -> Dictionary:
	var event_summaries: Array = []
	for event_packet in active_events:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		var summary := build_battle_v2_todo_ui_event_summary(event_packet)
		summary["progress"] = get_battle_v3_todo_progress(event_packet)
		event_summaries.append(summary)

	return {
		"title": "BATTLE V3 PIPELINE",
		"events": event_summaries,
		"slots": build_battle_v3_loadout_snapshot(),
		"drone_status": get_battle_v3_drone_status_text()
	}


func get_battle_v3_todo_progress(event_packet: Dictionary) -> float:
	var duration = max(float(event_packet.get("duration", 0.0)), 0.001)
	var raw_time_remaining = max(float(event_packet.get("time_remaining", 0.0)), 0.0)
	# Stacked TODOs can have time_remaining greater than their own duration. Keep them visible near the queue start
	# until their own countdown window begins, instead of incorrectly treating them like normal in-progress actions.
	if raw_time_remaining > duration:
		return 0.0
	var time_remaining = clamp(raw_time_remaining, 0.0, duration)
	return clamp((duration - time_remaining) / duration, 0.0, 1.0)


func build_battle_v3_loadout_snapshot() -> Dictionary:
	return {
		"primary": get_battle_v3_slot_display_name(TAB_PRIMARY),
		"secondary": get_battle_v3_slot_display_name(TAB_SECONDARY),
		"consumable": get_battle_v3_consumable_slot_display_name(false),
		"drone": get_battle_v3_consumable_slot_display_name(true),
		"upgrades": get_battle_v3_upgrade_slot_display_name()
	}


func get_battle_v3_slot_display_name(tab_id: String) -> String:
	for item_id in get_player_loadout_item_ids_for_tab(tab_id):
		var item_key := str(item_id).strip_edges()
		if item_key == "":
			continue
		var item_data := get_normalized_loadout_item_data(item_key, tab_id)
		if item_data.is_empty():
			continue
		return get_battle_v3_item_short_name(item_data, item_key)
	return "empty"


func get_battle_v3_consumable_slot_display_name(wants_drone: bool) -> String:
	var loaded_data := get_loaded_consumable_item_data()
	if not loaded_data.is_empty() and battle_v3_consumable_matches_drone_filter(loaded_data, wants_drone):
		return "ready " + get_battle_v3_item_short_name(loaded_data, str(loaded_data.get("item_id", "item")))

	var override_id := str(battle_v3_slot_overrides.get(TAB_CONSUMABLE, "")).strip_edges()
	if override_id != "":
		var override_data := get_normalized_loadout_item_data(override_id, TAB_CONSUMABLE)
		if not override_data.is_empty() and battle_v3_consumable_matches_drone_filter(override_data, wants_drone):
			return get_battle_v3_item_short_name(override_data, override_id)

	for item_id in find_inventory_items_for_battle_tab(TAB_CONSUMABLE, 12):
		var item_key := str(item_id).strip_edges()
		var item_data := get_normalized_loadout_item_data(item_key, TAB_CONSUMABLE)
		if item_data.is_empty():
			continue
		if not battle_v3_consumable_matches_drone_filter(item_data, wants_drone):
			continue
		return get_battle_v3_item_short_name(item_data, item_key)

	return "empty"


func battle_v3_consumable_matches_drone_filter(item_data: Dictionary, wants_drone: bool) -> bool:
	var group := str(item_data.get("consumable_group", item_data.get("group", ""))).strip_edges().to_lower()
	return (group == "drone") == wants_drone


func get_battle_v3_item_short_name(item_data: Dictionary, fallback: String) -> String:
	var name := str(item_data.get("display_name", item_data.get("name", fallback))).strip_edges()
	if name == "":
		name = fallback
	if name.length() > 22:
		name = name.substr(0, 21) + "."
	return name


func get_battle_v3_upgrade_slot_display_name() -> String:
	var names: Array = []
	for upgrade_id in get_current_battle_upgrade_ids():
		var item_key := str(upgrade_id).strip_edges()
		if item_key == "":
			continue
		var item_data := get_main_project_item_data(item_key)
		if item_data.is_empty():
			continue
		names.append(get_battle_v3_item_short_name(item_data, item_key))
	if names.is_empty():
		return "empty"
	return ", ".join(names)


func get_battle_v3_drone_status_text() -> String:
	if battle_manager_v2 == null or not battle_manager_v2.has_method("get_active_drone_runtime_snapshot"):
		return "none"
	var snapshot: Dictionary = battle_manager_v2.get_active_drone_runtime_snapshot()
	var active_count := int(snapshot.get("active_count", 0))
	if active_count <= 0:
		return "none"

	var drones: Array = []
	if typeof(snapshot.get("drones", [])) == TYPE_ARRAY:
		drones = snapshot.get("drones", [])
	if drones.is_empty():
		return str(active_count) + " active"

	var first: Dictionary = drones[0]
	var drone_type := str(first.get("drone_type", "drone")).replace("_", " ")
	var time_remaining := float(first.get("time_remaining", 0.0))
	var hull_current := float(first.get("hull_current", 0.0))
	var hull_max := float(first.get("hull_max", 0.0))
	var text := str(active_count) + " active | " + drone_type + " " + format_battle_value(time_remaining) + "s"
	if hull_max > 0.0:
		text += " HP " + format_battle_value(hull_current) + "/" + format_battle_value(hull_max)
	return text


func build_todo_event_line(event_packet: Dictionary) -> String:
	# Summary: Build compact TODO row text with owner side, event type, time, and id.
	var side := str(event_packet.get("event_side", "unknown")).to_upper()
	var time_remaining: float = max(float(event_packet.get("time_remaining", 0.0)), 0.0)
	var time_text: String = "%0.1f" % time_remaining
	return (
		side
		+ " "
		+ get_todo_event_display_text(event_packet)
		+ " | "
		+ time_text
		+ "s | "
		+ str(event_packet.get("event_id", ""))
	)


func get_todo_event_display_text(event_packet: Dictionary) -> String:
	# Summary: Show friendly consumable TODO text while preserving raw event packets underneath.
	var event_type := str(event_packet.get("event_type", "unknown"))
	var data_payload = event_packet.get("data", {})
	if typeof(data_payload) != TYPE_DICTIONARY:
		return event_type

	var item_data = data_payload.get("item_data", {})
	var item_name := str(data_payload.get("display_name", ""))
	if item_name == "" and typeof(item_data) == TYPE_DICTIONARY:
		item_name = str(item_data.get("display_name", item_data.get("name", "")))
	if item_name == "":
		item_name = str(data_payload.get("consumable_id", event_packet.get("item_id", event_type)))

	if event_type == "fire_secondary_weapon" and bool(data_payload.get("is_burst_todo", false)):
		var burst_index := int(data_payload.get("burst_index", event_packet.get("burst_index", 0)))
		var burst_total := int(data_payload.get("burst_total", event_packet.get("burst_total", 0)))
		var burst_name := str(data_payload.get("todo_display_name", "")).strip_edges()
		if burst_name == "" and burst_index > 0 and burst_total > 0:
			burst_name = item_name + " " + str(burst_index) + "/" + str(burst_total)
		if burst_name == "":
			burst_name = item_name
		return "firing " + burst_name

	var consumable_group := str(data_payload.get("consumable_group", "")).strip_edges().to_lower()
	if event_type == "player_evade":
		return "evading"
	if event_type == "enemy_evade":
		return "enemy evading"
	if bool(data_payload.get("evade_relock", false)):
		return "relocking after evade"
	if event_type == "load_consumable" and consumable_group == "explosive":
		return "arming " + item_name
	if event_type == "enemy_load_consumable" and consumable_group == "explosive":
		return "enemy arming " + item_name
	if event_type == "load_consumable":
		return "preparing " + item_name
	if event_type == "enemy_load_consumable":
		return "enemy preparing " + item_name
	if event_type == "execute_explosive" or (event_type.begins_with("execute_") and consumable_group == "explosive"):
		return ("enemy detonating " if side_is_enemy(event_packet) else "detonating ") + item_name
	if event_type == "execute_repair":
		return ("enemy using " if side_is_enemy(event_packet) else "using ") + item_name
	if event_type == "execute_recharge":
		return ("enemy using " if side_is_enemy(event_packet) else "using ") + item_name
	if event_type.begins_with("execute_") and consumable_group != "":
		return ("enemy using " if side_is_enemy(event_packet) else "using ") + item_name

	return event_type


func side_is_enemy(event_packet: Dictionary) -> bool:
	return str(event_packet.get("event_side", "")).strip_edges().to_lower() == "enemy"


func report_battle_v2_ui_match(match_id: String, packet: Dictionary) -> void:
	# Summary: Pass Battle V2 UI/sound-ready event packets into the top-layer handler.
	if not battle_v2_ui_handler_enabled:
		return
	if battle_v2_ui_handler == null:
		return
	if not battle_v2_ui_handler.has_method("receive_ui_event"):
		return
	battle_v2_ui_handler.receive_ui_event(match_id, packet)


func ensure_battle_v2_endpoint_effect_layer() -> void:
	if not battle_v2_endpoint_effects_enabled:
		return
	if battle_v2_endpoint_effect_layer != null and is_instance_valid(battle_v2_endpoint_effect_layer):
		battle_v2_endpoint_effect_layer.setup({
			"position_data": build_battle_v2_ui_position_data(),
			"size": Vector2(Globals.screen_w, Globals.screen_h),
			"z_index": 760
		})
		return

	battle_v2_endpoint_effect_layer = BattleV2EffectLayerScript.new()
	battle_v2_endpoint_effect_layer.name = "Battle_V2_Endpoint_Effects"
	battle_v2_endpoint_effect_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(battle_v2_endpoint_effect_layer)
	battle_v2_endpoint_effect_layer.setup({
		"position_data": build_battle_v2_ui_position_data(),
		"size": Vector2(Globals.screen_w, Globals.screen_h),
		"z_index": 760
	})
	move_child(battle_v2_endpoint_effect_layer, get_child_count() - 1)


func play_battle_v2_completed_endpoint_effects(completed_batch: Array, resolution_summary: Dictionary) -> void:
	if not battle_v2_endpoint_effects_enabled:
		return
	if completed_batch.is_empty():
		return

	var resolved_events: Array = []
	if typeof(resolution_summary.get("resolved_events", [])) == TYPE_ARRAY:
		resolved_events = resolution_summary.get("resolved_events", [])
	if resolved_events.is_empty():
		return

	ensure_battle_v2_endpoint_effect_layer()
	if battle_v2_endpoint_effect_layer == null:
		return

	for event_packet in completed_batch:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		var event_id := str(event_packet.get("event_id", "")).strip_edges()
		if event_id != "" and latest_completed_event_ids.has(event_id):
			continue

		var resolution_result := find_battle_v2_resolution_result_for_event(resolved_events, event_id)
		if resolution_result.is_empty() and resolved_events.size() == 1:
			var only_result = resolved_events[0]
			if typeof(only_result) == TYPE_DICTIONARY:
				resolution_result = only_result
		if resolution_result.is_empty():
			continue

		play_battle_v2_endpoint_result_effect(event_packet, resolution_result)


func play_battle_v2_endpoint_result_effect(event_packet: Dictionary, resolution_result: Dictionary) -> void:
	var result_type := str(resolution_result.get("type", "")).strip_edges().to_lower()
	if str(resolution_result.get("status", "")).strip_edges().to_lower() == "nullified":
		return
	if str(resolution_result.get("blocked_reason", "none")).strip_edges().to_lower() not in ["", "none"]:
		return

	if result_type == "weapon_damage" or result_type == "explosive":
		var damage_result = resolution_result.get("damage_result", {})
		if typeof(damage_result) == TYPE_DICTIONARY:
			play_battle_v2_damage_endpoint_effect(event_packet, damage_result, result_type == "explosive")
		return

	if result_type == "damage":
		play_battle_v2_damage_endpoint_effect(event_packet, resolution_result, false)
		return

	if result_type == "repair" and bool(resolution_result.get("repair_applied", false)):
		var repair_amount := float(resolution_result.get("hull_repaired", resolution_result.get("repair_amount", 0.0)))
		play_battle_v2_recovery_endpoint_effect(get_battle_v2_event_owner_side(event_packet), "repair", repair_amount)
		return

	if result_type == "shield_repair" and bool(resolution_result.get("repair_applied", false)):
		var shield_repaired := float(resolution_result.get("shield_repaired", resolution_result.get("shield_repair_amount", 0.0)))
		play_battle_v2_recovery_endpoint_effect(get_battle_v2_event_owner_side(event_packet), "patch", shield_repaired)
		return

	if result_type == "recharge" and bool(resolution_result.get("recharge_applied", false)):
		var energy_restored := float(resolution_result.get("energy_restored", 0.0))
		play_battle_v2_recovery_endpoint_effect(get_battle_v2_event_owner_side(event_packet), "recharge", energy_restored)


func play_battle_v2_damage_endpoint_effect(event_packet: Dictionary, damage_result: Dictionary, explosive_hit: bool) -> void:
	push_battle_v2_damage_packet_to_procedural_lane(event_packet, damage_result, explosive_hit)
	var target_side := get_battle_v2_event_target_side(event_packet)
	var shield_damage := float(damage_result.get("shield_damage", 0.0))
	var hull_damage := float(damage_result.get("hull_damage", 0.0)) + float(damage_result.get("overflow_damage", 0.0))
	if shield_damage <= 0.0 and hull_damage <= 0.0 and bool(damage_result.get("damage_applied", false)):
		play_battle_v2_default_hit_endpoint_effect(target_side)
		return

	if shield_damage > 0.0:
		play_battle_v2_shield_hit_endpoint_effect(target_side, shield_damage, explosive_hit)
	if hull_damage > 0.0:
		play_battle_v2_hull_hit_endpoint_effect(target_side, hull_damage, explosive_hit, shield_damage <= 0.0)


func play_battle_v2_default_hit_endpoint_effect(target_side: String) -> void:
	var float_point := get_battle_v2_endpoint_point(target_side, "float")
	battle_v2_endpoint_effect_layer.ring_pulse_around_box(
		float_point,
		Color(0.90, 0.92, 1.0, 0.58),
		0.42,
		1,
		18.0,
		2.0,
		0.04,
		3.0,
		"endpoint_default_hit_ring"
	)
	battle_v2_endpoint_effect_layer.float_text_at_point(
		float_point,
		"HIT",
		Color(0.92, 0.94, 1.0, 0.92),
		0.62,
		Vector2(0, -24),
		16,
		"endpoint_default_hit_text"
	)


func play_battle_v2_shield_hit_endpoint_effect(target_side: String, amount: float, explosive_hit: bool) -> void:
	var shield_point := get_battle_v2_endpoint_point(target_side, "shield")
	var float_point := get_battle_v2_endpoint_point(target_side, "float")
	var spark_count := 28 if explosive_hit else 18
	var thickness := 4.0 if explosive_hit else 3.0
	battle_v2_endpoint_effect_layer.flash_box(
		shield_point,
		BATTLE_V2_ENDPOINT_SHIELD_COLOR,
		0.32,
		thickness,
		22.0,
		5.0,
		"endpoint_shield_hit_flash"
	)
	battle_v2_endpoint_effect_layer.spark_burst_around_box(
		shield_point,
		BATTLE_V2_ENDPOINT_SHIELD_COLOR,
		spark_count,
		2.0,
		6.0,
		8.0,
		42.0,
		0.46,
		"endpoint_shield_hit_sparks"
	)
	battle_v2_endpoint_effect_layer.float_text_at_point(
		float_point,
		"SHIELD -" + format_battle_value(amount),
		BATTLE_V2_ENDPOINT_SHIELD_COLOR,
		0.78,
		Vector2(0, -32),
		16,
		"endpoint_shield_hit_text"
	)


func play_battle_v2_hull_hit_endpoint_effect(target_side: String, amount: float, explosive_hit: bool, direct_hull_hit: bool) -> void:
	var hull_point := get_battle_v2_endpoint_point(target_side, "hull")
	var float_point := get_battle_v2_endpoint_point(target_side, "float")
	var center := battle_v2_endpoint_effect_layer.get_point_center(hull_point)
	var burst_count := 34 if explosive_hit and direct_hull_hit else 22 if explosive_hit else 14
	var flash_duration := 0.48 if explosive_hit and direct_hull_hit else 0.34
	var hit_color := BATTLE_V2_ENDPOINT_HULL_CORE_COLOR if explosive_hit and direct_hull_hit else BATTLE_V2_ENDPOINT_HULL_COLOR
	battle_v2_endpoint_effect_layer.flash_box(
		hull_point,
		hit_color,
		flash_duration,
		5.0 if direct_hull_hit else 3.5,
		24.0,
		6.0,
		"endpoint_hull_hit_flash"
	)
	battle_v2_endpoint_effect_layer.particle_explosion(
		center,
		hit_color,
		burst_count,
		2.0,
		8.0,
		28.0,
		112.0 if direct_hull_hit else 84.0,
		0.50,
		"endpoint_hull_hit_pop"
	)
	battle_v2_endpoint_effect_layer.float_text_at_point(
		float_point,
		("DIRECT -" if explosive_hit and direct_hull_hit else "HULL -") + format_battle_value(amount),
		hit_color,
		0.82,
		Vector2(0, -42),
		17 if direct_hull_hit else 16,
		"endpoint_hull_hit_text"
	)


func play_battle_v2_recovery_endpoint_effect(owner_side: String, recovery_kind: String, amount: float) -> void:
	var target_point := get_battle_v2_endpoint_point(owner_side, "hull")
	var float_point := get_battle_v2_endpoint_point(owner_side, "float")
	var color := BATTLE_V2_ENDPOINT_REPAIR_COLOR
	var text := "REPAIR +" + format_battle_value(amount)
	if recovery_kind == "recharge":
		target_point = get_battle_v2_endpoint_point(owner_side, "energy")
		color = BATTLE_V2_ENDPOINT_RECHARGE_COLOR
		text = "RECHARGE +" + format_battle_value(amount)
	elif recovery_kind == "patch":
		target_point = get_battle_v2_endpoint_point(owner_side, "shield")
		color = BATTLE_V2_ENDPOINT_PATCH_COLOR
		text = "PATCH +" + format_battle_value(amount)

	battle_v2_endpoint_effect_layer.flash_box(
		target_point,
		color,
		0.42,
		3.5,
		18.0,
		5.0,
		"endpoint_recovery_flash"
	)
	battle_v2_endpoint_effect_layer.ring_pulse_around_box(
		target_point,
		color,
		0.62,
		2,
		24.0,
		3.0,
		0.08,
		4.0,
		"endpoint_recovery_ring"
	)
	battle_v2_endpoint_effect_layer.float_text_at_point(
		float_point,
		text,
		color,
		0.92,
		Vector2(0, -36),
		16,
		"endpoint_recovery_text"
	)


func get_battle_v2_endpoint_point(side_name: String, point_kind: String) -> String:
	var clean_side := side_name.strip_edges().to_lower()
	if clean_side != "enemy":
		clean_side = "player"

	match point_kind:
		"shield":
			return clean_side + "_shield_box"
		"energy":
			return clean_side + "_energy_box"
		"float":
			return clean_side + "_damage_float"
		_:
			return clean_side + "_hp_box"


func get_battle_v2_event_target_side(event_packet: Dictionary) -> String:
	var target_side := str(event_packet.get("target_side", "")).strip_edges().to_lower()
	if target_side == "player" or target_side == "enemy":
		return target_side
	var event_side := str(event_packet.get("event_side", "")).strip_edges().to_lower()
	if event_side == "enemy":
		return "player"
	return "enemy"


func get_battle_v2_event_owner_side(event_packet: Dictionary) -> String:
	var owner_side := str(event_packet.get("owner_side", "")).strip_edges().to_lower()
	if owner_side == "player" or owner_side == "enemy":
		return owner_side
	var event_side := str(event_packet.get("event_side", "")).strip_edges().to_lower()
	if event_side == "enemy":
		return "enemy"
	return "player"


func report_battle_v2_semantic_ui_event(event_family: String, point_id: String = "", extra_data: Dictionary = {}) -> Dictionary:
	# Summary: Small scene entry point for future decorated battle events and UI initiates.
	if not battle_v2_ui_handler_enabled:
		return {}
	if battle_v2_ui_handler == null:
		return {}
	refresh_battle_v2_ui_handler_points()
	if battle_v2_ui_handler.has_method("push_semantic_event"):
		return battle_v2_ui_handler.push_semantic_event(event_family, point_id, extra_data)

	var packet := extra_data.duplicate(true)
	packet["event_family"] = event_family.strip_edges()
	if point_id.strip_edges() != "":
		packet["position_hint"] = point_id.strip_edges()
	report_battle_v2_ui_match("battle_v2_semantic_event", packet)
	return packet


func report_battle_v2_action_clicked_to_ui_handler(row_data: Dictionary, route_result: Dictionary = {}, click_status: String = "", blocked_reason: String = "") -> void:
	var packet := build_battle_v2_action_clicked_ui_packet(row_data, route_result, click_status, blocked_reason)
	report_battle_v2_ui_match("battle_v2_action_button_clicked", packet)
	pulse_battle_v2_procedural_action(packet)


func build_battle_v2_action_clicked_ui_packet(row_data: Dictionary, route_result: Dictionary = {}, click_status: String = "", blocked_reason: String = "") -> Dictionary:
	var action_id := str(row_data.get("action_id", "")).strip_edges()
	var item_id := str(row_data.get("item_id", "")).strip_edges()
	var item_data: Dictionary = {}
	if typeof(row_data.get("item_data", {})) == TYPE_DICTIONARY:
		item_data = row_data.get("item_data", {})

	var event_packet := get_battle_v2_route_event_packet(route_result)
	var data_payload: Dictionary = {}
	if typeof(event_packet.get("data", {})) == TYPE_DICTIONARY:
		data_payload = event_packet.get("data", {})
	var event_result: Dictionary = {}
	if typeof(route_result.get("event_result", {})) == TYPE_DICTIONARY:
		event_result = route_result.get("event_result", {})
	var population_result: Dictionary = {}
	if typeof(row_data.get("population_result", {})) == TYPE_DICTIONARY:
		population_result = row_data.get("population_result", {})

	var tags := build_battle_v2_string_list([
		row_data.get("tags", []),
		item_data.get("tags", []),
		event_packet.get("tags", []),
		route_result.get("tags", [])
	])
	append_battle_v2_string_values(tags, ["battle_v2_action_click", "battle_v2_ui_handler_route"])

	var labels := build_battle_v2_string_list([
		row_data.get("labels", []),
		item_data.get("labels", []),
		event_packet.get("labels", []),
		event_result.get("labels", []),
		population_result.get("labels", []),
		route_result.get("labels", [])
	])
	append_battle_v2_string_values(labels, ["battle_v2_action_button_clicked"])
	if item_id == "pulse_laser_mk1":
		append_battle_v2_string_values(tags, ["pulse_laser", "primary_weapon", "energy_weapon"])
		append_battle_v2_string_values(labels, ["pulse_laser_clicked"])

	var route_status := str(route_result.get("status", ""))
	if click_status.strip_edges() == "":
		click_status = route_status if route_status != "" else "clicked"
	if blocked_reason.strip_edges() == "":
		blocked_reason = str(route_result.get("reason", ""))

	return {
		"battle_id": battle_id,
		"action_id": action_id,
		"item_id": item_id,
		"item_name": str(item_data.get("display_name", item_data.get("name", row_data.get("text", action_id)))),
		"row_text": str(row_data.get("text", "")),
		"selected_action_tab": str(row_data.get("selected_action_tab", selected_action_tab)),
		"click_status": click_status,
		"blocked_reason": blocked_reason,
		"route_status": route_status,
		"route_reason": str(route_result.get("reason", "")),
		"event_id": str(event_result.get("event_id", event_packet.get("event_id", ""))),
		"event_type": str(event_packet.get("event_type", event_result.get("event_type", ""))),
		"event_group": str(event_packet.get("event_group", "")),
		"event_side": str(event_packet.get("event_side", "")),
		"source_side": str(event_packet.get("source_side", "")),
		"target_side": str(event_packet.get("target_side", "")),
		"owner_side": str(event_packet.get("owner_side", "")),
		"duration": float(event_packet.get("duration", item_data.get("duration", row_data.get("duration", 0.0)))),
		"queued_event_count": int(route_result.get("queued_event_count", 0)),
		"event_ids": route_result.get("event_ids", []),
		"same_type_key": str(event_packet.get("same_type_key", item_data.get("same_type_key", ""))),
		"weapon_slot": str(data_payload.get("weapon_slot", item_data.get("slot", ""))),
		"damage_type": str(data_payload.get("damage_type", event_packet.get("damage_type", item_data.get("damage_type", "")))),
		"damage_value": float(data_payload.get("damage_value", event_packet.get("damage_value", item_data.get("damage_value", 0.0)))),
		"consumable_group": str(data_payload.get("consumable_group", item_data.get("consumable_group", item_data.get("group", "")))),
		"explosive_damage": float(data_payload.get("explosive_damage", event_packet.get("explosive_damage", item_data.get("explosive_damage", item_data.get("damage_value", 0.0))))),
		"explosive_pass_percent": float(data_payload.get("explosive_pass_percent", event_packet.get("explosive_pass_percent", item_data.get("explosive_pass_percent", 0.0)))),
		"is_burst_todo": bool(data_payload.get("is_burst_todo", false)),
		"burst_index": int(data_payload.get("burst_index", 0)),
		"burst_total": int(data_payload.get("burst_total", data_payload.get("original_burst_count", data_payload.get("burst_count", item_data.get("burst_count", 0))))),
		"burst_count": int(data_payload.get("burst_count", item_data.get("burst_count", 1))),
		"ammo_per_burst": int(data_payload.get("ammo_per_burst", item_data.get("ammo_per_burst", item_data.get("ammo_cost", 0)))),
		"ammo_cost": int(data_payload.get("ammo_cost", item_data.get("ammo_cost", 0))),
		"position_hint": get_battle_v2_action_position_hint(action_id, str(row_data.get("selected_action_tab", selected_action_tab))),
		"tags": tags,
		"labels": labels
	}


func get_battle_v2_route_event_packet(route_result: Dictionary) -> Dictionary:
	var packet_result = route_result.get("packet_result", {})
	if typeof(packet_result) == TYPE_DICTIONARY:
		var event_packet = packet_result.get("event_packet", {})
		if typeof(event_packet) == TYPE_DICTIONARY:
			return event_packet

	var event_result = route_result.get("event_result", {})
	if typeof(event_result) == TYPE_DICTIONARY:
		return event_result

	return {}


func get_battle_v2_action_position_hint(action_id: String, tab_id: String) -> String:
	var clean_action := action_id.strip_edges().to_lower()
	if clean_action == "player_evade":
		return "evade_button"
	if tab_id.strip_edges().to_lower() == TAB_SHIELDS:
		return "shield_panel"
	return "action_button_stack"


func build_player_evade_action_ui_row_data() -> Dictionary:
	return {
		"text": "Evade",
		"action_id": "player_evade",
		"item_id": "player_evade",
		"selected_action_tab": "evade",
		"tags": ["battle_v2_evade", "player_action", "manual_button"],
		"labels": ["battle_v2_evade_button", "player_evade_availability"]
	}


func report_battle_v2_todo_active_to_ui_handler(active_events: Array) -> void:
	var summaries: Array = []
	var event_ids: Array = []
	var signature_parts: Array = []

	for event_packet in active_events:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		var summary := build_battle_v2_todo_ui_event_summary(event_packet)
		summaries.append(summary)
		event_ids.append(str(summary.get("event_id", "")))
		signature_parts.append(
			str(summary.get("event_id", ""))
			+ ":"
			+ str(summary.get("time_bucket_tenth", 0))
			+ ":"
			+ str(summary.get("event_type", ""))
		)

	if signature_parts.is_empty():
		signature_parts.append("empty")

	var new_signature := "|".join(signature_parts)
	if new_signature == battle_v2_todo_active_signature:
		return

	battle_v2_todo_active_signature = new_signature
	report_battle_v2_ui_match("battle_v2_todo_active", {
		"battle_id": battle_id,
		"active_count": summaries.size(),
		"event_ids": event_ids,
		"events": summaries,
		"tags": ["battle_v2_todo", "todo_active"],
		"labels": ["battle_v2_todo_active_snapshot"]
	})


func report_battle_v2_todo_completed_to_ui_handler(completed_batch: Array, handoff_result: Dictionary) -> void:
	var summaries: Array = []
	var event_ids: Array = []
	var resolution_summary := get_battle_resolution_summary(handoff_result)
	var resolved_events: Array = []
	if typeof(resolution_summary.get("resolved_events", [])) == TYPE_ARRAY:
		resolved_events = resolution_summary.get("resolved_events", [])

	for event_packet in completed_batch:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		var event_id := str(event_packet.get("event_id", ""))
		if event_id != "" and latest_completed_event_ids.has(event_id):
			continue
		var summary := build_battle_v2_todo_ui_event_summary(event_packet)
		var resolution_result := find_battle_v2_resolution_result_for_event(resolved_events, event_id)
		if not resolution_result.is_empty():
			summary["resolution_result"] = resolution_result
			summary["hull_repaired"] = float(resolution_result.get("hull_repaired", 0.0))
			summary["hull_before"] = float(resolution_result.get("hull_before", 0.0))
			summary["hull_after"] = float(resolution_result.get("hull_after", 0.0))
		summaries.append(summary)
		event_ids.append(event_id)

	if summaries.is_empty():
		return

	report_battle_v2_ui_match("battle_v2_todo_completed", {
		"battle_id": battle_id,
		"completed_count": summaries.size(),
		"event_ids": event_ids,
		"events": summaries,
		"handoff": {
			"delivered": bool(handoff_result.get("delivered", false)),
			"acknowledged": bool(handoff_result.get("acknowledged", false)),
			"resolved_count": int(handoff_result.get("resolved_count", 0)),
			"failed_count": int(handoff_result.get("failed_count", 0)),
			"battle_outcome": str(handoff_result.get("battle_outcome", ""))
		},
		"tags": ["battle_v2_todo", "todo_completed"],
		"labels": ["battle_v2_todo_completed_snapshot"]
	})


func find_battle_v2_resolution_result_for_event(resolved_events: Array, event_id: String) -> Dictionary:
	for resolution_result in resolved_events:
		if typeof(resolution_result) != TYPE_DICTIONARY:
			continue
		if str(resolution_result.get("event_id", "")).strip_edges() == event_id.strip_edges():
			return resolution_result.duplicate(true)
	return {}


func report_battle_v2_drone_runtime_to_ui_handler(update_summary: Dictionary) -> void:
	if battle_manager_v2 == null:
		return
	if not battle_manager_v2.has_method("get_active_drone_runtime_snapshot"):
		return

	var snapshot: Dictionary = battle_manager_v2.get_active_drone_runtime_snapshot()
	var drones := get_battle_v2_drone_ui_array(snapshot, "drones")
	var expired := get_battle_v2_drone_ui_array(update_summary, "expired")
	var destroyed := get_battle_v2_drone_ui_array(update_summary, "destroyed")
	var attacks := build_battle_v2_drone_attack_ui_summaries(update_summary, drones)

	if not attacks.is_empty() or not expired.is_empty() or not destroyed.is_empty():
		battle_v2_drone_ui_update_counter += 1

	var lane_packet := build_battle_v2_drone_runtime_lane_packet({
		"drones": drones,
		"attacks": attacks,
		"expired": expired,
		"destroyed": destroyed,
		"drone_ui_update_index": battle_v2_drone_ui_update_counter
	})
	push_battle_v2_drone_runtime_to_procedural_lane(lane_packet)

	var signature := build_battle_v2_drone_runtime_signature(drones, attacks, expired, destroyed)
	if signature == battle_v2_drone_runtime_signature:
		return

	battle_v2_drone_runtime_signature = signature
	refresh_battle_v2_ui_handler_points()
	report_battle_v2_ui_match("battle_v2_drone_runtime", {
		"battle_id": battle_id,
		"active_count": drones.size(),
		"drones": drones,
		"attacks": attacks,
		"expired": expired,
		"destroyed": destroyed,
		"drone_ui_update_index": battle_v2_drone_ui_update_counter,
		"tags": ["battle_v2_drone_runtime", "active_drone_runtime"],
		"labels": ["battle_v2_drone_runtime_snapshot"]
	})


func get_battle_v2_drone_ui_array(source: Dictionary, key: String) -> Array:
	var results: Array = []
	if typeof(source.get(key, [])) != TYPE_ARRAY:
		return results

	for entry in source.get(key, []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		results.append(build_battle_v2_drone_ui_summary(entry))
	return results


func build_battle_v2_drone_ui_summary(drone_summary: Dictionary) -> Dictionary:
	return {
		"status": str(drone_summary.get("status", "active")),
		"runtime_id": str(drone_summary.get("runtime_id", "")),
		"source_item_id": str(drone_summary.get("source_item_id", "")),
		"owner_side": str(drone_summary.get("owner_side", "")),
		"target_side": str(drone_summary.get("target_side", "")),
		"drone_type": str(drone_summary.get("drone_type", "auto_attack")),
		"auto_attack": bool(drone_summary.get("auto_attack", true)),
		"duration": float(drone_summary.get("duration", drone_summary.get("time_remaining", 0.0))),
		"hull_current": float(drone_summary.get("hull_current", 0.0)),
		"hull_max": float(drone_summary.get("hull_max", 0.0)),
		"time_remaining": float(drone_summary.get("time_remaining", 0.0)),
		"fire_timer": float(drone_summary.get("fire_timer", 0.0)),
		"fire_interval": float(drone_summary.get("fire_interval", 0.0)),
		"drone_fire_count": int(drone_summary.get("drone_fire_count", drone_summary.get("max_shots", 0))),
		"max_shots": int(drone_summary.get("max_shots", drone_summary.get("drone_fire_count", 0))),
		"shots_fired": int(drone_summary.get("shots_fired", 0)),
		"shots_remaining": int(drone_summary.get("shots_remaining", drone_summary.get("max_shots", 0))),
		"damage_type": str(drone_summary.get("damage_type", "")),
		"damage_value": float(drone_summary.get("damage_value", 0.0)),
		"labels": build_battle_v2_string_list([drone_summary.get("labels", [])])
	}


func build_battle_v2_drone_attack_ui_summaries(update_summary: Dictionary, active_drones: Array) -> Array:
	var results: Array = []
	if typeof(update_summary.get("attacks", [])) != TYPE_ARRAY:
		return results

	var attack_index := 0
	for attack in update_summary.get("attacks", []):
		if typeof(attack) != TYPE_DICTIONARY:
			continue
		var runtime_id := str(attack.get("runtime_id", "")).strip_edges()
		var drone_summary := get_battle_v2_drone_summary_by_runtime_id(active_drones, runtime_id)
		var damage_result := build_battle_v2_drone_damage_ui_summary(attack)
		results.append({
			"ui_attack_key": str(battle_v2_drone_ui_update_counter + 1) + ":" + runtime_id + ":" + str(attack_index),
			"runtime_id": runtime_id,
			"owner_side": str(attack.get("owner_side", drone_summary.get("owner_side", "player"))),
			"target_side": str(attack.get("target_side", drone_summary.get("target_side", "enemy"))),
			"damage_applied": bool(attack.get("damage_applied", false)),
			"damage_value": float(attack.get("damage_value", drone_summary.get("damage_value", 0.0))),
			"shot_index": int(attack.get("shot_index", 0)),
			"shot_total": int(attack.get("shot_total", drone_summary.get("max_shots", 0))),
			"shots_remaining": int(attack.get("shots_remaining", drone_summary.get("shots_remaining", 0))),
			"damage_result": damage_result,
			"labels": build_battle_v2_string_list([attack.get("labels", [])])
		})
		attack_index += 1

	return results


func build_battle_v2_drone_damage_ui_summary(attack: Dictionary) -> Dictionary:
	var source: Dictionary = {}
	if typeof(attack.get("damage_result", {})) == TYPE_DICTIONARY:
		source = attack.get("damage_result", {})

	return {
		"damage_applied": bool(source.get("damage_applied", attack.get("damage_applied", false))),
		"shield_damage": float(source.get("shield_damage", 0.0)),
		"hull_damage": float(source.get("hull_damage", 0.0)),
		"overflow_damage": float(source.get("overflow_damage", 0.0)),
		"damage_type": str(source.get("damage_type", "")),
		"labels": build_battle_v2_string_list([source.get("labels", [])])
	}


func get_battle_v2_drone_summary_by_runtime_id(drones: Array, runtime_id: String) -> Dictionary:
	for drone in drones:
		if typeof(drone) != TYPE_DICTIONARY:
			continue
		if str(drone.get("runtime_id", "")).strip_edges() == runtime_id:
			return drone
	return {}


func build_battle_v2_drone_runtime_signature(drones: Array, attacks: Array, expired: Array, destroyed: Array) -> String:
	var parts: Array = [str(drones.size())]
	for drone in drones:
		if typeof(drone) != TYPE_DICTIONARY:
			continue
		parts.append(
			str(drone.get("runtime_id", ""))
			+ ":"
			+ str(int(ceil(max(float(drone.get("time_remaining", 0.0)), 0.0) * 10.0)))
			+ ":"
			+ str(int(ceil(max(float(drone.get("fire_timer", 0.0)), 0.0) * 10.0)))
			+ ":"
			+ str(int(round(float(drone.get("hull_current", 0.0)))))
			+ ":"
			+ str(int(drone.get("shots_remaining", drone.get("max_shots", 0))))
		)

	for attack in attacks:
		if typeof(attack) == TYPE_DICTIONARY:
			parts.append("attack:" + str(attack.get("ui_attack_key", "")))
	for drone in expired:
		if typeof(drone) == TYPE_DICTIONARY:
			parts.append("expired:" + str(drone.get("runtime_id", "")))
	for drone in destroyed:
		if typeof(drone) == TYPE_DICTIONARY:
			parts.append("destroyed:" + str(drone.get("runtime_id", "")))
	return "|".join(parts)


func build_battle_v2_todo_ui_event_summary(event_packet: Dictionary) -> Dictionary:
	var data_payload: Dictionary = {}
	if typeof(event_packet.get("data", {})) == TYPE_DICTIONARY:
		data_payload = event_packet.get("data", {})

	var item_data: Dictionary = {}
	if typeof(data_payload.get("item_data", {})) == TYPE_DICTIONARY:
		item_data = data_payload.get("item_data", {})

	var time_remaining = max(float(event_packet.get("time_remaining", 0.0)), 0.0)
	var time_bucket_tenth := int(ceil(time_remaining * 10.0))
	var tags := build_battle_v2_string_list([
		event_packet.get("tags", []),
		data_payload.get("tags", []),
		item_data.get("tags", [])
	])
	var labels := build_battle_v2_string_list([
		event_packet.get("labels", []),
		data_payload.get("labels", []),
		item_data.get("labels", [])
	])

	return {
		"event_id": str(event_packet.get("event_id", "")),
		"event_type": str(event_packet.get("event_type", "")),
		"event_group": str(event_packet.get("event_group", "")),
		"event_side": str(event_packet.get("event_side", "")),
		"source_side": str(event_packet.get("source_side", "")),
		"target_side": str(event_packet.get("target_side", "")),
		"owner_side": str(event_packet.get("owner_side", "")),
		"display_text": get_todo_event_display_text(event_packet),
		"duration": float(event_packet.get("duration", 0.0)),
		"time_remaining": time_remaining,
		"time_bucket_tenth": time_bucket_tenth,
		"same_type_key": str(event_packet.get("same_type_key", "")),
		"resolution_gate_state": str(event_packet.get("resolution_gate_state", "")),
		"resolution_gate_reason": str(event_packet.get("resolution_gate_reason", "")),
		"lane_intervention_type": str(event_packet.get("lane_intervention_type", "")),
		"source_unit_key": get_battle_v2_ui_unit_key(event_packet.get("source_unit", null)),
		"target_unit_key": get_battle_v2_ui_unit_key(event_packet.get("target_unit", null)),
		"owner_unit_key": get_battle_v2_ui_unit_key(event_packet.get("owner_unit", null)),
		"item_id": str(data_payload.get("item_id", item_data.get("item_id", event_packet.get("item_id", "")))),
		"item_name": str(data_payload.get("display_name", item_data.get("display_name", item_data.get("name", "")))),
		"consumable_id": str(data_payload.get("consumable_id", event_packet.get("item_id", ""))),
		"consumable_group": str(data_payload.get("consumable_group", item_data.get("consumable_group", item_data.get("group", "")))),
		"heal_amount": float(data_payload.get("heal_amount", data_payload.get("repair_amount", data_payload.get("hull_restore_amount", item_data.get("heal_amount", 0.0))))),
		"repair_amount": float(data_payload.get("repair_amount", data_payload.get("heal_amount", data_payload.get("hull_restore_amount", item_data.get("repair_amount", 0.0))))),
		"weapon_slot": str(data_payload.get("weapon_slot", item_data.get("slot", ""))),
		"damage_type": str(data_payload.get("damage_type", event_packet.get("damage_type", item_data.get("damage_type", "")))),
		"damage_value": float(data_payload.get("damage_value", event_packet.get("damage_value", item_data.get("damage_value", 0.0)))),
		"explosive_damage": float(data_payload.get("explosive_damage", event_packet.get("explosive_damage", item_data.get("explosive_damage", item_data.get("damage_value", 0.0))))),
		"explosive_pass_percent": float(data_payload.get("explosive_pass_percent", event_packet.get("explosive_pass_percent", item_data.get("explosive_pass_percent", 0.0)))),
		"is_burst_todo": bool(data_payload.get("is_burst_todo", false)),
		"burst_index": int(data_payload.get("burst_index", 0)),
		"burst_total": int(data_payload.get("burst_total", data_payload.get("original_burst_count", data_payload.get("burst_count", item_data.get("burst_count", 0))))),
		"burst_count": int(data_payload.get("burst_count", item_data.get("burst_count", 1))),
		"ammo_per_burst": int(data_payload.get("ammo_per_burst", item_data.get("ammo_per_burst", item_data.get("ammo_cost", 0)))),
		"ammo_cost": int(data_payload.get("ammo_cost", item_data.get("ammo_cost", 0))),
		"position_hint": get_battle_v2_todo_position_hint(event_packet),
		"tags": tags,
		"labels": labels
	}


func get_battle_v2_todo_position_hint(event_packet: Dictionary) -> String:
	if bool(event_packet.get("is_damage_event", false)):
		if side_is_enemy(event_packet):
			return "player_damage_float"
		return "enemy_damage_float"
	if bool(event_packet.get("is_state_change", false)):
		return "center_stage"
	return "todo_next_row"


func report_battle_v2_header_state_to_ui_handler() -> void:
	# The background consumes the same visual snapshot as the optional legacy UI
	# handler, but it must remain live while that top-layer handler is disabled.
	if not battle_v2_background_draw_layer_enabled and not battle_v2_ui_handler_enabled:
		return
	var packet := build_battle_v2_header_state_ui_packet()
	sync_battle_v2_background_draw_layer(packet)
	if not battle_v2_ui_handler_enabled:
		return

	refresh_battle_v2_ui_handler_points()
	var new_signature := (
		str(packet.get("player_hp_text", ""))
		+ "|"
		+ str(packet.get("enemy_hp_text", ""))
		+ "|"
		+ str(packet.get("player_shield_text", ""))
		+ "|"
		+ str(packet.get("enemy_shield_text", ""))
		+ "|"
		+ str(packet.get("player_energy_text", ""))
		+ "|"
		+ str(packet.get("enemy_energy_text", ""))
		+ "|"
		+ str(packet.get("player_shield_power_level", 0))
		+ "|"
		+ str(packet.get("enemy_shield_power_level", 0))
		+ "|"
		+ str(packet.get("player_shield_has_energy", true))
		+ "|"
		+ str(packet.get("enemy_shield_has_energy", true))
		+ "|"
		+ str(packet.get("player_shield_state", "active"))
		+ "|"
		+ str(packet.get("enemy_shield_state", "active"))
	)
	if new_signature == battle_v2_header_state_signature:
		return
	battle_v2_header_state_signature = new_signature
	report_battle_v2_ui_match("battle_v2_header_state", packet)


func build_battle_v2_header_state_ui_packet() -> Dictionary:
	return {
		"battle_id": battle_id,
		"player_hp_text": get_battle_v2_label_text("player_hull"),
		"enemy_hp_text": get_battle_v2_label_text("enemy_hull"),
		"player_shield_text": get_battle_v2_label_text("player_shield"),
		"enemy_shield_text": get_battle_v2_label_text("enemy_shield"),
		"player_energy_text": get_battle_v2_label_text("player_energy"),
		"enemy_energy_text": get_battle_v2_label_text("enemy_energy"),
		"player_ammo_text": get_battle_v2_label_text("player_ammo"),
		"enemy_intent_text": get_battle_v2_label_text("enemy_intent"),
		"player_hp_current": get_unit_float(player_state_packet, "player_hull_current", 0.0),
		"player_hp_max": get_unit_float(player_state_packet, "player_hull_max", 0.0),
		"enemy_hp_current": get_unit_float(active_enemy, "enemy_hull_current", 0.0),
		"enemy_hp_max": get_unit_float(active_enemy, "enemy_hull_max", 0.0),
		"player_shield_power_level": int(get_unit_float(player_state_packet, "shield_power_level", 0.0)),
		"enemy_shield_power_level": int(get_unit_float(active_enemy, "shield_power_level", 0.0)),
		"player_shield_current": get_unit_float(player_state_packet, "shield_hp_current", 0.0),
		"player_shield_max": get_unit_shield_max(player_state_packet),
		"enemy_shield_current": get_unit_float(active_enemy, "shield_hp_current", 0.0),
		"enemy_shield_max": get_unit_shield_max(active_enemy),
		"player_shield_max_count": 4,
		"enemy_shield_max_count": 4,
		"player_shield_has_energy": energy_handler_has_current_energy(energy_handler_v2),
		"enemy_shield_has_energy": energy_handler_has_current_energy(enemy_energy_handler_v2),
		"player_shield_state": get_player_shield_visual_state(),
		"enemy_shield_state": get_enemy_shield_visual_state(active_enemy),
		"position_hints": {
			"player_hp_box": "player_hp_box",
			"enemy_hp_box": "enemy_hp_box",
			"player_shield_box": "player_shield_box",
			"enemy_shield_box": "enemy_shield_box",
			"center_stage": "center_stage"
		},
		"tags": ["battle_v2_header_state"],
		"labels": ["battle_v2_ui_handler_header_state"]
	}


func get_unit_shield_max(unit_ref) -> float:
	# Summary: Read equipped shield max HP for visual-only UI summaries.
	if unit_ref == null:
		return 0.0
	if unit_ref is BattleV2UnitAdapter:
		var adapter: BattleV2UnitAdapter = unit_ref as BattleV2UnitAdapter
		if typeof(adapter.selected_shield) == TYPE_DICTIONARY:
			var shield_data: Dictionary = adapter.selected_shield as Dictionary
			return float(shield_data.get("shield_hp_max", shield_data.get("hp_max", adapter.shield_hp_current)))
		return max(float(adapter.shield_hp_current), 0.0)
	if typeof(unit_ref) == TYPE_DICTIONARY:
		var source: Dictionary = unit_ref
		if typeof(source.get("selected_shield", null)) == TYPE_DICTIONARY:
			var shield_dict: Dictionary = source.get("selected_shield", {})
			return float(shield_dict.get("shield_hp_max", shield_dict.get("hp_max", source.get("shield_hp_current", 0.0))))
		return float(source.get("shield_hp_max", source.get("shield_max", source.get("shield_hp_current", 0.0))))
	return 0.0

func energy_handler_has_current_energy(handler) -> bool:
	# Summary: Let visual shield rings dim only when a linked energy handler is actually empty.
	if handler == null:
		return true
	if handler.has_method("shield_has_energy"):
		return bool(handler.shield_has_energy())
	return float(handler.current_energy) > 0.0


func get_player_shield_visual_state() -> String:
	# Summary: Convert player shield state into the stable visual states consumed by BattleV2UIHandler.
	if player_state_packet == null:
		return "hidden"
	if player_state_packet.shield_switching:
		return "switching"
	if typeof(player_state_packet.selected_shield) != TYPE_DICTIONARY:
		return "inactive"
	if player_state_packet.shield_hp_current <= 0.0:
		return "broken"
	if not energy_handler_has_current_energy(energy_handler_v2):
		return "no_energy"
	return "active"


func get_enemy_shield_visual_state(enemy_ref) -> String:
	# Summary: Convert enemy shield state into the stable visual states consumed by BattleV2UIHandler.
	if not (enemy_ref is BattleV2UnitAdapter):
		return "hidden"

	var enemy_state: BattleV2UnitAdapter = enemy_ref as BattleV2UnitAdapter
	if enemy_state.shield_switching:
		return "switching"
	if typeof(enemy_state.selected_shield) != TYPE_DICTIONARY:
		return "inactive"
	if enemy_state.shield_hp_current <= 0.0:
		return "broken"
	if not energy_handler_has_current_energy(enemy_energy_handler_v2):
		return "no_energy"
	return "active"


func get_battle_v2_label_text(label_key: String) -> String:
	if not battle_ui_labels.has(label_key):
		return ""
	var label: Label = battle_ui_labels[label_key] as Label
	if label == null:
		return ""
	return str(label.text)


func get_battle_v2_ui_unit_key(unit_ref) -> String:
	if unit_ref == null:
		return ""

	if typeof(unit_ref) == TYPE_DICTIONARY:
		for key in ["unit_id", "enemy_id", "object_id", "id", "display_name", "name"]:
			var value = unit_ref.get(key, null)
			if value != null and str(value).strip_edges() != "":
				return str(value).strip_edges()
		return str(unit_ref)

	if unit_ref is Object:
		for key in ["unit_id", "enemy_id", "object_id", "id", "display_name", "name"]:
			var value = unit_ref.get(key)
			if value != null and str(value).strip_edges() != "":
				return str(value).strip_edges()

	return str(unit_ref)


func build_battle_v2_string_list(sources: Array) -> Array:
	var results: Array = []
	for source in sources:
		append_battle_v2_string_values(results, source)
	return results


func append_battle_v2_string_values(target: Array, source) -> void:
	if typeof(source) == TYPE_ARRAY:
		for entry in source:
			append_battle_v2_string_values(target, entry)
		return

	if source == null:
		return

	var clean_value := str(source).strip_edges()
	if clean_value == "":
		return
	if target.has(clean_value):
		return
	target.append(clean_value)


func remember_completed_event_batch() -> void:
	# Summary: Store and display completed TODO snapshots after BattleManager receives them.
	#
	# Ownership rule:
	# - EventManager owns TODO timing and completed batches.
	# - BattleManager owns battle resolution and outcome reporting.
	# - BattleV2 scene owns terminal outcome ordering.
	#
	# Terminal ordering rule:
	# If BattleManager reports player_victory, queue the defeated enemy result BEFORE
	# mark_battle_v2_ended() runs cleanup, because cleanup may clear active enemy refs.

	if battle_v2_ended:
		if Globals.print_priority_3:
			print("[BattleV2Scene.remember_completed_event_batch] BLOCKED | battle_v2_ended=true")
		return

	if battle_event_manager == null:
		if Globals.print_priority_5:
			print("[BattleV2Scene.remember_completed_event_batch] BLOCKED | battle_event_manager=null")
		return

	# ------------------------------------------------------
	# EventManager owns timing completion. BattleManager receives
	# the completed batch during EventManager.process_events().
	# ------------------------------------------------------
	var completed_batch: Array = battle_event_manager.get_completed_batch()

	if completed_batch.is_empty():
		if Globals.print_priority_3:
			print("[BattleV2Scene.remember_completed_event_batch] NO COMPLETED BATCH")
		return

	if Globals.print_priority_5:
		print(
			"[BattleV2Scene.remember_completed_event_batch] START",
			" | completed_count=", completed_batch.size()
		)

	# ------------------------------------------------------
	# BattleManager/EventManager handoff result.
	# This may be either an old wrapped shape or a newer direct
	# resolution summary shape, depending on current patch state.
	# ------------------------------------------------------
	var handoff_result: Dictionary = battle_event_manager.last_handoff_result
	var resolution_summary: Dictionary = get_battle_resolution_summary(handoff_result)
	var battle_outcome := str(resolution_summary.get("battle_outcome", get_handoff_battle_outcome(handoff_result)))
	var cleanup_required := bool(resolution_summary.get("cleanup_required", false))
	var battle_ended_from_result := bool(resolution_summary.get("battle_ended", false))
	apply_completed_shield_break_results(resolution_summary)
	report_battle_v2_todo_completed_to_ui_handler(completed_batch, handoff_result)
	play_battle_v2_completed_endpoint_effects(completed_batch, resolution_summary)
	request_battle_ai_resolution_commentary(completed_batch, handoff_result, resolution_summary, "todo_completed")

	if Globals.print_priority_5:
		print(
			"[BattleV2Scene.remember_completed_event_batch] HANDOFF",
			" | delivered=", handoff_result.get("delivered", false),
			" | acknowledged=", handoff_result.get("acknowledged", false),
			" | battle_outcome=", battle_outcome,
			" | battle_ended=", battle_ended_from_result,
			" | cleanup_required=", cleanup_required
		)

	# ------------------------------------------------------
	# Display each new completed event once.
	# ------------------------------------------------------
	for event_packet in completed_batch:
		if typeof(event_packet) != TYPE_DICTIONARY:
			if Globals.print_priority_5:
				print("[BattleV2Scene.remember_completed_event_batch] SKIP non-dictionary event | event=", event_packet)
			continue

		var event_id: String = str(event_packet.get("event_id", ""))

		if latest_completed_event_ids.has(event_id):
			if Globals.print_priority_3:
				print("[BattleV2Scene.remember_completed_event_batch] SKIP duplicate event_id=", event_id)
			continue

		latest_completed_event_ids.append(event_id)
		record_completed_enemy_evade_cooldown(event_packet)
		latest_todo_status_text = (
			"Completed: "
			+ str(event_packet.get("event_type", "unknown"))
			+ " | id: "
			+ event_id
		)

		var handoff_text: String = "BattleManager handoff: delivered=" + str(handoff_result.get("delivered", false))
		handoff_text += " acknowledged=" + str(handoff_result.get("acknowledged", false))

		if battle_outcome != "":
			handoff_text += " outcome=" + battle_outcome

		if str(handoff_result.get("blocked_reason", "")) != "":
			handoff_text += " blocked=" + str(handoff_result.get("blocked_reason", ""))

		if log_label != null:
			log_label.text += (
				"\nTODO completed timing: "
				+ str(event_packet.get("event_type", "unknown"))
				+ " | id: "
				+ event_id
				+ "\n" + handoff_text
				+ "\n" + build_battle_result_log_text(event_packet, handoff_result)
				+ "\n"
			)

	# ------------------------------------------------------
	# TERMINAL OUTCOME HANDOFF
	# This must happen after log display but before enemy response.
	# Victory result must be queued before cleanup clears refs.
	# ------------------------------------------------------
	if cleanup_required or battle_ended_from_result or battle_outcome == "player_victory" or battle_outcome == "player_defeat":
		if battle_outcome == "player_victory":
			if Globals.print_priority_5:
				print("[BattleV2Scene.remember_completed_event_batch] TERMINAL | player_victory | queue result then cleanup")

			queue_battle_v2_victory_result()
			mark_battle_v2_ended("player_victory")
			return

		if battle_outcome == "player_defeat":
			if Globals.print_priority_5:
				print("[BattleV2Scene.remember_completed_event_batch] TERMINAL | player_defeat | cleanup")

			mark_battle_v2_ended("player_defeat")
			return

		if Globals.print_priority_5:
			print(
				"[BattleV2Scene.remember_completed_event_batch] TERMINAL UNKNOWN",
				" | battle_outcome=", battle_outcome,
				" | cleanup_required=", cleanup_required
			)

	# ------------------------------------------------------
	# NON-TERMINAL REFRESH
	# Only refresh rows and queue enemy response if battle continues.
	# ------------------------------------------------------
	refresh_unit_status_values()
	queue_player_lock_reacquire_if_needed()
	queue_enemy_lock_reacquire_if_needed()
	refresh_unit_status_values()
	refresh_action_body_rows()

	for event_packet in completed_batch:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue

		var event_id_for_response: String = str(event_packet.get("event_id", ""))
		if event_id_for_response == "":
			continue

		# Player completion now wakes the active enemy thinker instead of directly queuing.
		# The enemy think loop owns when EnemyLogic is asked to act.
		wake_enemy_thinker_after_player_event(event_packet)

	if Globals.print_priority_5:
		print("[BattleV2Scene.remember_completed_event_batch] END | battle continues")


func get_handoff_battle_outcome(handoff_result: Dictionary) -> String:
	# Summary: Read a terminal BattleManager outcome from an EventManager handoff result.
	var outcome := str(handoff_result.get("battle_outcome", "")).strip_edges()
	if outcome == "player_victory" or outcome == "player_defeat":
		return outcome

	var summary = handoff_result.get("resolution_summary", {})
	if typeof(summary) == TYPE_DICTIONARY:
		outcome = str(summary.get("battle_outcome", "")).strip_edges()
		if outcome == "player_victory" or outcome == "player_defeat":
			return outcome

	return ""


func apply_completed_shield_break_results(resolution_summary: Dictionary) -> void:
	# Summary: Synchronize inventory and clear the active shield holder after a completed break transaction.
	var break_results: Array = []
	collect_shield_break_results(resolution_summary.get("resolved_events", []), break_results)
	if break_results.is_empty():
		return

	sync_battle_inventory_save_data_from_ammo_source()
	var seen: Dictionary = {}
	for break_result in break_results:
		if typeof(break_result) != TYPE_DICTIONARY:
			continue
		var item_id := str(break_result.get("shield_item_id", "")).strip_edges()
		var event_side := str(break_result.get("event_side", "")).strip_edges().to_lower()
		var signature := event_side + ":" + item_id
		if seen.has(signature):
			continue
		seen[signature] = true
		if event_side == "player":
			if str(battle_v3_slot_overrides.get(TAB_SHIELDS, "")).strip_edges() == item_id:
				battle_v3_slot_overrides[TAB_SHIELDS] = ""
			if log_label != null:
				log_label.text += "\nShield broken and consumed: " + item_id + "\n"
	prune_unowned_battle_v3_slot_overrides()


func collect_shield_break_results(value: Variant, output: Array) -> void:
	if typeof(value) == TYPE_ARRAY:
		for entry in value:
			collect_shield_break_results(entry, output)
		return
	if typeof(value) != TYPE_DICTIONARY:
		return

	var packet: Dictionary = value
	if bool(packet.get("shield_broken", false)) and packet.has("shield_item_id"):
		output.append(packet)
	if typeof(packet.get("shield_break_result", {})) == TYPE_DICTIONARY:
		var direct_break: Dictionary = packet.get("shield_break_result", {})
		if not direct_break.is_empty() and bool(direct_break.get("shield_broken", false)):
			output.append(direct_break)
	for key in packet.keys():
		if key == "shield_break_result":
			continue
		var child = packet.get(key)
		if typeof(child) == TYPE_ARRAY or typeof(child) == TYPE_DICTIONARY:
			collect_shield_break_results(child, output)


func get_loadout_item_id(value: Variant) -> String:
	# Summary: Store durable loadout slots as item IDs even when runtime battle state holds item packets.
	if value == null:
		return ""

	if typeof(value) == TYPE_DICTIONARY:
		var packet: Dictionary = value as Dictionary
		return str(packet.get("item_id", packet.get("id", ""))).strip_edges()

	var text := str(value).strip_edges()
	if text == "" or text == "<null>" or text.to_lower() == "null":
		return ""

	return text


func build_player_state_save_data_from_battle_packet() -> Dictionary:
	# Summary: Convert the runtime Battle V2 player adapter back into plain PlayerState save data.
	if player_state_packet == null:
		return battle_player_state_save_data.duplicate(true)

	var current_energy := get_unit_float(player_state_packet, "player_energy_current", get_unit_float(player_state_packet, "energy_current", 100.0))
	var max_energy := get_unit_float(player_state_packet, "player_energy_max", get_unit_float(player_state_packet, "energy_max", 100.0))
	var regen := get_unit_float(player_state_packet, "player_energy_regen_per_second", get_unit_float(player_state_packet, "energy_regen_per_second", 8.0))
	if energy_handler_v2 != null:
		current_energy = get_energy_source_float(energy_handler_v2, "current_energy", current_energy)
		max_energy = get_energy_source_float(energy_handler_v2, "max_energy", max_energy)
		regen = get_energy_source_float(energy_handler_v2, "regen_per_second", get_energy_source_float(energy_handler_v2, "recharge_rate", regen))

	var base_hull_max := get_unit_float(player_state_packet, "base_player_hull_max", get_saved_base_player_max_stat("hull_max", get_unit_float(player_state_packet, "player_hull_max", 1.0)))
	var base_energy_max := get_unit_float(player_state_packet, "base_player_energy_max", get_saved_base_player_max_stat("energy_max", max_energy))
	var saved_hull_current = clamp(get_unit_float(player_state_packet, "player_hull_current", get_unit_float(player_state_packet, "hull_current", 0.0)), 0.0, base_hull_max)
	current_energy = clamp(current_energy, 0.0, base_energy_max)
	max_energy = base_energy_max

	var data := battle_player_state_save_data.duplicate(true)
	data["unit_id"] = "player"
	data["unit_name"] = "Player"
	data["display_name"] = "Player Ship"
	data["unit_side"] = "player"
	data["hull_current"] = saved_hull_current
	data["hull_max"] = base_hull_max
	data["player_hull_current"] = data["hull_current"]
	data["player_hull_max"] = data["hull_max"]
	data["energy_current"] = current_energy
	data["energy_max"] = max_energy
	data["energy_regen_per_second"] = regen
	data["player_energy_current"] = current_energy
	data["player_energy_max"] = max_energy
	data["player_energy_regen_per_second"] = regen
	data["shield_hp_current"] = get_unit_float(player_state_packet, "shield_hp_current", 0.0)
	data["shield_hp_max"] = get_unit_float(player_state_packet, "shield_hp_max", 0.0)
	data["shield_disabled"] = bool(player_state_packet.shield_disabled)
	var shield_power := int(clamp(int(get_unit_float(player_state_packet, "shield_power_level", 0.0)), 0, 4))
	var selected_primary_id := get_loadout_item_id(player_state_packet.selected_primary_weapon)
	var selected_secondary_id := get_loadout_item_id(player_state_packet.selected_secondary_weapon)
	var selected_shield_id := get_loadout_item_id(player_state_packet.selected_shield)
	var loaded_consumable_id := get_loadout_item_id(player_state_packet.loaded_consumable)
	var equipped_upgrades := get_current_battle_upgrade_ids()
	if player_state_packet is BattleV2UnitAdapter:
		var adapter: BattleV2UnitAdapter = player_state_packet as BattleV2UnitAdapter
		equipped_upgrades = sanitize_battle_upgrade_ids(adapter.equipped_upgrades)
	var loaded_consumable_state := str(player_state_packet.loaded_consumable_state).strip_edges().to_lower()
	if loaded_consumable_id == "":
		loaded_consumable_state = "none"
	elif loaded_consumable_state == "" or loaded_consumable_state == "none":
		loaded_consumable_state = "ready"

	var default_shield_power := 2
	var existing_loadout = battle_player_state_save_data.get("battle_loadout", {})
	if typeof(existing_loadout) == TYPE_DICTIONARY:
		default_shield_power = int(clamp(int(existing_loadout.get("default_shield_power_level", default_shield_power)), 0, 4))

	data["shield_power_level"] = shield_power
	data["selected_primary_weapon"] = selected_primary_id
	data["selected_secondary_weapon"] = selected_secondary_id
	data["selected_shield"] = selected_shield_id
	data["loaded_consumable"] = loaded_consumable_id
	data["loaded_consumable_state"] = loaded_consumable_state
	data["default_shield_power_level"] = default_shield_power
	data["battle_loadout"] = {
		"selected_primary_weapon": selected_primary_id,
		"selected_secondary_weapon": selected_secondary_id,
		"selected_shield": selected_shield_id,
		"loaded_consumable": loaded_consumable_id,
		"loaded_consumable_state": loaded_consumable_state,
		"equipped_upgrades": equipped_upgrades.duplicate(true),
		"shield_power_level": shield_power,
		"default_shield_power_level": default_shield_power
	}
	data["is_destroyed"] = float(data["hull_current"]) <= 0.0
	data["is_alive"] = not bool(data["is_destroyed"])
	data["battle_active"] = false
	data["removed_from_battle"] = false
	data["labels"] = ["player_state_save_data", "battle_v2_result_snapshot"]
	return data


func get_active_enemy_shared_meta_save_data() -> Dictionary:
	# Summary: Preserve authored/event enemy identity even if the original world enemy ref is unavailable at victory.
	if not (active_enemy is BattleV2UnitAdapter):
		return {}

	var enemy_adapter: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
	if enemy_adapter.has_method("get_shared_meta_save_data"):
		var save_meta = enemy_adapter.get_shared_meta_save_data()
		if typeof(save_meta) == TYPE_DICTIONARY:
			return save_meta.duplicate(true)

	if typeof(enemy_adapter.shared_meta) == TYPE_DICTIONARY and not enemy_adapter.shared_meta.is_empty():
		return SharedObjectMeta.to_save_data(enemy_adapter.shared_meta)

	return {}


func build_battle_authored_event_context(defeated_shared_meta: Dictionary = {}) -> Dictionary:
	# Summary: Preserve authored event identity from the scene-entry context for main-mode result consumption.
	var context := {}
	if typeof(battle_context.get("authored_event_context", {})) == TYPE_DICTIONARY:
		context = battle_context.get("authored_event_context", {}).duplicate(true)

	for key in [
		"event_id",
		"active_event_id",
		"event_step",
		"current_step",
		"required_step",
		"object_id",
		"enemy_id",
		"target_object_id",
		"enemy_serial",
		"enemy_template_id",
		"display_name"
	]:
		if not defeated_shared_meta.has(key):
			continue
		if str(context.get(key, "")).strip_edges() == "":
			context[key] = defeated_shared_meta.get(key)

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


func merge_authored_context_into_shared_meta(shared_meta: Dictionary, authored_context: Dictionary) -> Dictionary:
	var merged := shared_meta.duplicate(true)

	# The battle-entry context is the authoritative event scope. Enemy shared meta can
	# legitimately be older than the live battle step when an enemy was installed earlier.
	for key in [
		"event_id",
		"active_event_id",
		"event_step",
		"current_step",
		"required_step"
	]:
		if not authored_context.has(key):
			continue
		if not is_shared_meta_value_missing(authored_context.get(key, null)):
			merged[key] = authored_context.get(key)

	for key in [
		"object_id",
		"enemy_serial",
		"enemy_template_id",
		"display_name"
	]:
		if not authored_context.has(key):
			continue
		if is_shared_meta_value_missing(merged.get(key, null)):
			merged[key] = authored_context.get(key)

	if is_shared_meta_value_missing(merged.get("object_id", null)):
		merged["object_id"] = str(authored_context.get("enemy_id", authored_context.get("target_object_id", "")))

	return merged


func is_enemy_cleanup_signature_empty(signature: Dictionary) -> bool:
	# Summary: Detect when defeated-enemy removal lacks enough world identity data.
	if signature.is_empty():
		return true
	if str(signature.get("name", "")).strip_edges() != "":
		return false
	if str(signature.get("type", "")).strip_edges() != "":
		return false
	if typeof(signature.get("sector", [])) == TYPE_ARRAY and not signature.get("sector", []).is_empty():
		return false
	if typeof(signature.get("local", [])) == TYPE_ARRAY and not signature.get("local", []).is_empty():
		return false
	return true


func build_enemy_cleanup_signature_from_shared_meta(shared_meta: Dictionary, fallback_name: String = "Enemy") -> Dictionary:
	# Summary: Build main-mode enemy removal data from adapter/event shared meta.
	if shared_meta.is_empty():
		return build_enemy_cleanup_signature(null)

	var normalized_meta := SharedObjectMeta.build_meta(
		str(shared_meta.get("object_id", "")),
		str(shared_meta.get("object_type", "enemy")),
		str(shared_meta.get("display_name", fallback_name)),
		shared_meta.get("sector_pos", Vector3i.ZERO),
		shared_meta.get("local_pos", Vector3.ZERO),
		shared_meta
	)
	var sector_pos: Vector3i = SharedObjectMeta.read_sector_pos(normalized_meta.get("sector_pos", Vector3i.ZERO))
	var local_pos: Vector3 = SharedObjectMeta.read_local_pos(normalized_meta.get("local_pos", Vector3.ZERO))
	return {
		"name": str(normalized_meta.get("display_name", fallback_name)),
		"type": str(normalized_meta.get("object_type", "enemy")),
		"enemy_serial": str(normalized_meta.get("enemy_serial", "")),
		"sector": vector3_to_array_safe(sector_pos),
		"local": vector3_to_array_safe(local_pos),
		"shared_meta": SharedObjectMeta.to_save_data(normalized_meta)
	}


func merge_shared_meta_missing_values(primary_meta: Dictionary, fallback_meta: Dictionary) -> Dictionary:
	# Summary: Preserve event ownership fields when a world enemy packet is missing them.
	if primary_meta.is_empty():
		return fallback_meta.duplicate(true)
	if fallback_meta.is_empty():
		return primary_meta.duplicate(true)

	var merged := primary_meta.duplicate(true)
	var keys_to_preserve := [
		"object_id",
		"object_type",
		"display_name",
		"enemy_serial",
		"enemy_template_id",
		"sector_pos",
		"local_pos",
		"has_event",
		"event_id",
		"event_ids",
		"active_event_id",
		"event_state",
		"event_step",
		"current_step",
		"required_step",
		"interaction_type",
		"labels"
	]
	for key in keys_to_preserve:
		if not fallback_meta.has(key):
			continue
		if is_shared_meta_value_missing(merged.get(key, null)):
			merged[key] = fallback_meta[key]

	return SharedObjectMeta.to_save_data(
		SharedObjectMeta.build_meta(
			str(merged.get("object_id", "")),
			str(merged.get("object_type", "enemy")),
			str(merged.get("display_name", "")),
			merged.get("sector_pos", Vector3i.ZERO),
			merged.get("local_pos", Vector3.ZERO),
			merged
		)
	)


func is_shared_meta_value_missing(value) -> bool:
	if value == null:
		return true
	if typeof(value) == TYPE_STRING:
		return str(value).strip_edges() == ""
	if typeof(value) == TYPE_ARRAY:
		return value.is_empty()
	return false


func queue_battle_v2_victory_result() -> void:
	# Summary: Stores the defeated enemy result so main_mode can remove it from the universe after scene return.
	sync_battle_inventory_save_data_from_ammo_source()
	var defeated_world_enemy = null
	var defeated_enemy_id := ""
	var defeated_enemy_name := ""
	var adapter_shared_meta := get_active_enemy_shared_meta_save_data()
	
	if active_enemy is BattleV2UnitAdapter:
		var enemy_adapter: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter

		if enemy_adapter.has_method("get_source_world_enemy"):
			defeated_world_enemy = enemy_adapter.get_source_world_enemy()

		if enemy_adapter.has_method("get_source_enemy_id"):
			defeated_enemy_id = enemy_adapter.get_source_enemy_id()

	defeated_enemy_name = get_handoff_enemy_name(defeated_world_enemy)
	if defeated_enemy_name == "Unknown enemy" and not adapter_shared_meta.is_empty():
		defeated_enemy_name = str(adapter_shared_meta.get("display_name", defeated_enemy_name))
	if defeated_enemy_id.strip_edges() == "" and not adapter_shared_meta.is_empty():
		defeated_enemy_id = str(adapter_shared_meta.get("object_id", ""))
	var defeated_signature := build_enemy_cleanup_signature(defeated_world_enemy)
	if is_enemy_cleanup_signature_empty(defeated_signature) and not adapter_shared_meta.is_empty():
		defeated_signature = build_enemy_cleanup_signature_from_shared_meta(adapter_shared_meta, defeated_enemy_name)
	var defeated_shared_meta := adapter_shared_meta.duplicate(true)
	if defeated_world_enemy != null:
		var world_shared_meta := SharedObjectMeta.to_save_data(get_handoff_enemy_shared_meta(defeated_world_enemy, defeated_enemy_name))
		defeated_shared_meta = merge_shared_meta_missing_values(world_shared_meta, adapter_shared_meta)
	elif defeated_shared_meta.is_empty():
		defeated_shared_meta = SharedObjectMeta.to_save_data(get_handoff_enemy_shared_meta(defeated_world_enemy, defeated_enemy_name))
	var authored_event_context := build_battle_authored_event_context(defeated_shared_meta)
	defeated_shared_meta = merge_authored_context_into_shared_meta(defeated_shared_meta, authored_event_context)
	var defeated_enemy_serial := str(defeated_shared_meta.get("enemy_serial", adapter_shared_meta.get("enemy_serial", ""))).strip_edges()
	Globals.battle_v2_result = {
		"pending": true,
		"outcome": "player_victory",
		"battle_id": battle_id,
		"authored_event_context": authored_event_context,
		"defeated_enemy": defeated_world_enemy,
		"defeated_enemy_serial": defeated_enemy_serial,
		"defeated_enemy_id": defeated_enemy_id,
		"defeated_enemy_name": defeated_enemy_name,
		"defeated_enemy_signature": defeated_signature,
		"defeated_enemy_shared_meta": defeated_shared_meta,
		"inventory_save_data": battle_inventory_save_data.duplicate(true),
		"item_db_snapshot": battle_item_db_snapshot.duplicate(true),
		"npc_save_data": battle_npc_save_data.duplicate(true),
		"beacon_save_data": battle_beacon_save_data.duplicate(true),
		"space_object_save_data": battle_space_object_save_data.duplicate(true),
		"player_state_save_data": build_player_state_save_data_from_battle_packet()
	}

	if log_label != null:
		log_label.text += "\nVictory result queued for main-mode cleanup: " + defeated_enemy_name + "\n"


func queue_battle_v2_inventory_result(outcome: String) -> void:
	# Summary: Stores non-victory Battle V2 inventory changes so ammo spends still persist after scene return.
	sync_battle_inventory_save_data_from_ammo_source()
	Globals.battle_v2_result = {
		"pending": true,
		"outcome": outcome,
		"battle_id": battle_id,
		"inventory_save_data": battle_inventory_save_data.duplicate(true),
		"item_db_snapshot": battle_item_db_snapshot.duplicate(true),
		"npc_save_data": battle_npc_save_data.duplicate(true),
		"beacon_save_data": battle_beacon_save_data.duplicate(true),
		"space_object_save_data": battle_space_object_save_data.duplicate(true),
		"player_state_save_data": build_player_state_save_data_from_battle_packet()
	}


func mark_battle_v2_ended(outcome: String) -> void:
	# Summary: Stop Battle V2 scene ticking and clear pending TODOs after a terminal battle outcome.
	if battle_v2_ended:
		return

	battle_v2_ended = true
	battle_v2_outcome = outcome

	if outcome == "player_victory" and not bool(Globals.battle_v2_result.get("pending", false)):
		queue_battle_v2_victory_result()
	elif not bool(Globals.battle_v2_result.get("pending", false)):
		queue_battle_v2_inventory_result(outcome)

	var cleanup_context := {
		"battle_id": battle_id,
		"outcome": outcome
	}
	var cleanup_log_lines: Array = []

	if battle_event_manager != null and battle_event_manager.has_method("clear_battle_events"):
		var event_cleanup: Dictionary = battle_event_manager.clear_battle_events(battle_id)
		cleanup_log_lines.append("Event cleanup cleared: " + str(event_cleanup.get("cleared_count", 0)))

	if battle_manager_v2 != null and battle_manager_v2.has_method("end_battle_cleanup"):
		var battle_cleanup: Dictionary = battle_manager_v2.end_battle_cleanup(outcome)
		cleanup_log_lines.append("BattleManager cleanup: " + str(battle_cleanup.get("status", "done")))

	if player_handler_v2 != null and player_handler_v2.has_method("cleanup_player_after_battle"):
		var player_cleanup: Dictionary = player_handler_v2.cleanup_player_after_battle(cleanup_context)
		cleanup_log_lines.append("PlayerHandler cleanup: " + str(player_cleanup.get("status", "unknown")))

	if energy_handler_v2 != null and energy_handler_v2.has_method("clear_active_shield_drain"):
		var energy_cleanup: Dictionary = energy_handler_v2.clear_active_shield_drain()
		energy_shield_drain_signature = ""
		cleanup_log_lines.append("Shield drain cleanup: " + str(energy_cleanup.get("status", "done")))

	if enemy_energy_handler_v2 != null and enemy_energy_handler_v2.has_method("clear_active_shield_drain"):
		var enemy_energy_cleanup: Dictionary = enemy_energy_handler_v2.clear_active_shield_drain()
		enemy_energy_shield_drain_signature = ""
		cleanup_log_lines.append("Enemy shield drain cleanup: " + str(enemy_energy_cleanup.get("status", "done")))

	refresh_unit_status_values()
	refresh_action_body_rows()
	refresh_todo_timeline_from_event_manager()

	if log_label != null:
		log_label.text += "\nBattle ended: " + outcome + "\n" + "\n".join(cleanup_log_lines) + "\n"

	begin_battle_v2_end_sequence(outcome)



func begin_battle_v2_end_sequence(outcome: String) -> void:
	# Summary: Show an in-world AMI closeout/countdown, then reuse the existing return-to-main handoff.
	if battle_v2_auto_return_started:
		return

	battle_v2_auto_return_started = true
	var countdown_seconds := 3
	if outcome == "player_defeat":
		countdown_seconds = 5
	show_battle_v2_end_sequence(outcome, countdown_seconds)

	if log_label != null:
		log_label.text += "\nAMI closeout started: " + outcome + "\n"

	for remaining in range(countdown_seconds, 0, -1):
		update_battle_v2_end_sequence_countdown(remaining)
		await get_tree().create_timer(1.0).timeout

	update_battle_v2_end_sequence_countdown(0)
	await get_tree().create_timer(0.25).timeout
	if outcome == "player_defeat":
		return_to_start_menu_after_game_over()
		return
	return_to_main_scene()


func show_battle_v2_end_sequence(outcome: String, countdown_seconds: int = 3) -> void:
	# Summary: Build/show the battle close UI without adding a player-clickable exit control.
	ensure_battle_v2_end_sequence_ui()
	if battle_v2_end_sequence_root == null:
		return

	battle_v2_end_sequence_root.visible = true

	var title_text := "AMI COMBAT LINK"
	var body_text := "Threat vector resolved.\nRejoining local space..."
	if outcome == "player_defeat":
		title_text = "GAME OVER"
		body_text = "Critical vessel failure recorded.\nAutosave will be removed."
	elif outcome == "battle_ended":
		body_text = "Combat channel closing.\nRejoining local space..."

	if battle_v2_end_sequence_title_label != null:
		battle_v2_end_sequence_title_label.text = title_text
	if battle_v2_end_sequence_body_label != null:
		battle_v2_end_sequence_body_label.text = body_text
	update_battle_v2_end_sequence_countdown(countdown_seconds)

	if status_label != null:
		status_label.text = body_text.replace("\n", " ")


func update_battle_v2_end_sequence_countdown(seconds_remaining: int) -> void:
	# Summary: Keep the AMI closeout countdown visible while the scene waits to return.
	if battle_v2_end_sequence_countdown_label == null:
		return

	if battle_v2_outcome == "player_defeat":
		if seconds_remaining <= 0:
			battle_v2_end_sequence_countdown_label.text = "Returning to start menu..."
			return
		battle_v2_end_sequence_countdown_label.text = "Start menu in " + str(seconds_remaining) + "..."
		return

	if seconds_remaining <= 0:
		battle_v2_end_sequence_countdown_label.text = "Rejoining local space..."
		return

	battle_v2_end_sequence_countdown_label.text = "Rejoining in " + str(seconds_remaining) + "..."


func ensure_battle_v2_end_sequence_ui() -> void:
	# Summary: Lazy-build the battle-end overlay so normal battle UI stays untouched until resolution.
	if battle_v2_end_sequence_root != null and is_instance_valid(battle_v2_end_sequence_root):
		return

	var screen_size := Vector2(Globals.screen_w, Globals.screen_h)
	battle_v2_end_sequence_root = Control.new()
	battle_v2_end_sequence_root.name = "Battle_V2_AMI_End_Sequence"
	battle_v2_end_sequence_root.position = Vector2.ZERO
	battle_v2_end_sequence_root.size = screen_size
	battle_v2_end_sequence_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_v2_end_sequence_root.z_index = 420
	battle_v2_end_sequence_root.z_as_relative = false
	battle_v2_end_sequence_root.visible = false
	add_child(battle_v2_end_sequence_root)
	store_battle_control("battle_v2_ami_end_sequence", battle_v2_end_sequence_root)

	var dim := ColorRect.new()
	dim.name = "Battle_V2_AMI_End_Dim"
	dim.position = Vector2.ZERO
	dim.size = screen_size
	dim.color = Color(0.0, 0.02, 0.06, 0.44)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_v2_end_sequence_root.add_child(dim)

	var panel_size := Vector2(560, 150)
	battle_v2_end_sequence_panel = ColorRect.new()
	battle_v2_end_sequence_panel.name = "Battle_V2_AMI_End_Panel"
	battle_v2_end_sequence_panel.position = Vector2((screen_size.x - panel_size.x) * 0.5, (screen_size.y - panel_size.y) * 0.5)
	battle_v2_end_sequence_panel.size = panel_size
	battle_v2_end_sequence_panel.color = Color(0.02, 0.08, 0.14, 0.92)
	battle_v2_end_sequence_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_v2_end_sequence_root.add_child(battle_v2_end_sequence_panel)

	battle_v2_end_sequence_title_label = Label.new()
	battle_v2_end_sequence_title_label.name = "Battle_V2_AMI_End_Title"
	battle_v2_end_sequence_title_label.position = battle_v2_end_sequence_panel.position + Vector2(24, 16)
	battle_v2_end_sequence_title_label.size = Vector2(panel_size.x - 48, 28)
	battle_v2_end_sequence_title_label.text = "AMI COMBAT LINK"
	battle_v2_end_sequence_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_v2_end_sequence_title_label.add_theme_font_size_override("font_size", 20)
	battle_v2_end_sequence_root.add_child(battle_v2_end_sequence_title_label)

	battle_v2_end_sequence_body_label = Label.new()
	battle_v2_end_sequence_body_label.name = "Battle_V2_AMI_End_Body"
	battle_v2_end_sequence_body_label.position = battle_v2_end_sequence_panel.position + Vector2(34, 52)
	battle_v2_end_sequence_body_label.size = Vector2(panel_size.x - 68, 54)
	battle_v2_end_sequence_body_label.text = "Threat vector resolved.\nRejoining local space..."
	battle_v2_end_sequence_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_v2_end_sequence_body_label.add_theme_font_size_override("font_size", 16)
	battle_v2_end_sequence_root.add_child(battle_v2_end_sequence_body_label)

	battle_v2_end_sequence_countdown_label = Label.new()
	battle_v2_end_sequence_countdown_label.name = "Battle_V2_AMI_End_Countdown"
	battle_v2_end_sequence_countdown_label.position = battle_v2_end_sequence_panel.position + Vector2(24, 111)
	battle_v2_end_sequence_countdown_label.size = Vector2(panel_size.x - 48, 24)
	battle_v2_end_sequence_countdown_label.text = "Rejoining in 3..."
	battle_v2_end_sequence_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_v2_end_sequence_countdown_label.add_theme_font_size_override("font_size", 15)
	battle_v2_end_sequence_root.add_child(battle_v2_end_sequence_countdown_label)


func ensure_battle_v2_result_log_formatter() -> void:
	if battle_v2_result_log_formatter == null:
		battle_v2_result_log_formatter = BattleV2ResultLogFormatterScript.new()
	battle_v2_result_log_formatter.setup(self)


func build_battle_result_log_text(event_packet: Dictionary, handoff_result: Dictionary) -> String:
	# Summary: Convert BattleManager handoff details into player-readable Battle V2 log text.
	ensure_battle_v2_result_log_formatter()
	return battle_v2_result_log_formatter.build_battle_result_log_text(event_packet, handoff_result)

func build_resolution_result_log_text(resolution_result: Dictionary) -> String:
	# Summary: Convert one BattleManager resolution result into a compact log line.
	ensure_battle_v2_result_log_formatter()
	return battle_v2_result_log_formatter.build_resolution_result_log_text(resolution_result)


func get_resolution_energy_log_suffix(resolution_result: Dictionary) -> String:
	# Summary: Build short completion-time energy text from BattleManager's EnergyHandler spend bridge.
	ensure_battle_v2_result_log_formatter()
	return battle_v2_result_log_formatter.get_resolution_energy_log_suffix(resolution_result)


func get_resolution_ammo_log_suffix(resolution_result: Dictionary) -> String:
	# Summary: Build short completion-time ammo text from BattleManager's AmmoHandler spend bridge.
	ensure_battle_v2_result_log_formatter()
	return battle_v2_result_log_formatter.get_resolution_ammo_log_suffix(resolution_result)


func get_resolution_consumable_log_suffix(resolution_result: Dictionary) -> String:
	# Summary: Build short completion-time consumable text from BattleManager's consumable spend bridge.
	ensure_battle_v2_result_log_formatter()
	return battle_v2_result_log_formatter.get_resolution_consumable_log_suffix(resolution_result)


func has_pending_enemy_response_event() -> bool:
	# Summary: Prevent the enemy side from stacking response TODOs while one is already active.
	if battle_event_manager == null:
		return false

	for event_packet in battle_event_manager.active_events:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		if str(event_packet.get("event_side", "")).strip_edges().to_lower() == "enemy":
			return true

	return false


func can_continue_enemy_response_loop() -> bool:
	# Summary: Keep the enemy response loop from running after either combatant has hit zero hull.
	if battle_v2_ended:
		return false

	if battle_manager_v2 != null and battle_manager_v2.get("battle_active") != null and not bool(battle_manager_v2.get("battle_active")):
		return false

	if active_enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
		if enemy_state.enemy_hull_max > 0.0 and enemy_state.enemy_hull_current <= 0.0:
			return false

	if player_state_packet is BattleV2UnitAdapter:
		var player_state: BattleV2UnitAdapter = player_state_packet as BattleV2UnitAdapter
		if player_state.player_hull_max > 0.0 and player_state.player_hull_current <= 0.0:
			return false

	return true


func start_enemy_thinking() -> void:
	# Summary: Start enemy initiative after Battle V2 has built handlers, state packets, and UI.
	if enemy_battle_controller != null:
		enemy_battle_controller.start()
		return

	if Globals.print_priority_5:
		print("Battle V2 enemy thinking could not start; EnemyBattleController is missing.")


func process_enemy_thinking(delta: float) -> void:
	# Summary:
	# Enemy active battle loop.
	# The scene/controller decides when the enemy may think.
	# EnemyLogic chooses intent.
	# PacketBuilder builds the TODO packet.
	# EventManager owns timing.
	# BattleManager owns resolution.
	if enemy_battle_controller != null:
		var controller_queue_result: Dictionary = enemy_battle_controller.process_enemy_thinking(delta)
		request_battle_ai_enemy_intent_commentary(controller_queue_result, "enemy_controller_think")
		return

	if enemy_think_paused:
		return

	if not can_enemy_think_now():
		return

	enemy_think_timer -= delta

	if enemy_think_timer > 0.0:
		return

	enemy_think_timer = enemy_think_interval

	var queue_result: Dictionary = queue_enemy_intent_from_logic()
	request_battle_ai_enemy_intent_commentary(queue_result, "enemy_scene_think")

	if Globals.print_priority_5:
		print("[enemy_think_result] ", queue_result)


func can_enemy_think_now() -> bool:
	# Summary: No-spam gate for the active enemy battle loop.

	if battle_v2_ended:
		return false

	if not Globals.battle_mode:
		return false

	if not can_continue_enemy_response_loop():
		return false

	if active_enemy == null:
		return false

	if player_state_packet == null:
		return false

	if battle_event_manager == null:
		return false

	if battle_action_manager == null:
		return false

	if battle_action_manager.battle_action_packet_builder == null:
		return false

	if enemy_logic_v2 == null:
		return false

	if Time.get_ticks_msec() < enemy_action_cooldown_until_msec:
		return false

	if has_active_enemy_event():
		return false

	return true


func has_active_enemy_event() -> bool:
	# Summary: True when EventManager already has an enemy-side TODO in flight.
	return not get_active_events_for_side("enemy").is_empty()


func get_active_events_for_side(side: String) -> Array:
	# Summary: Read active TODO packets for one side without mutating EventManager state.
	var output: Array = []

	if battle_event_manager == null:
		return output

	var clean_side := side.strip_edges().to_lower()
	if clean_side == "":
		return output

	for event_packet in battle_event_manager.active_events:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue

		if str(event_packet.get("lifecycle_state", "active")).strip_edges().to_lower() != "active":
			continue

		var event_side := str(event_packet.get("event_side", "")).strip_edges().to_lower()
		if event_side == clean_side:
			output.append(event_packet.duplicate(true))

	return output


func wake_enemy_thinker_after_player_event(completed_event: Dictionary) -> void:
	# Summary: Completed player events no longer directly queue enemy responses.
	# They wake the active enemy thinker so the timer loop owns the next enemy action.
	if enemy_battle_controller != null:
		enemy_battle_controller.wake_after_player_event(completed_event)
		return

	if typeof(completed_event) != TYPE_DICTIONARY:
		return

	if str(completed_event.get("event_side", "")).strip_edges().to_lower() != "player":
		return

	if battle_v2_ended:
		return

	enemy_think_paused = false
	enemy_think_timer = min(enemy_think_timer, 0.10)

	if Globals.print_priority_5:
		print("[enemy_thinker_wake] player event completed: ", completed_event.get("event_type", "unknown"))



func get_unit_float(unit_ref, key: String, fallback: float = 0.0) -> float:
	# Summary:
	# Read known battle-state float values from BattleV2UnitAdapter or Dictionary.
	# Keep this explicit so Battle V2 does not accidentally depend on mystery fields.

	if unit_ref == null:
		return fallback

	if unit_ref is BattleV2UnitAdapter:
		var adapter: BattleV2UnitAdapter = unit_ref

		# Enemy energy values used by build_enemy_energy_snapshot().
		if key == "enemy_energy_current":
			return float(adapter.enemy_energy_current)

		if key == "enemy_energy_max":
			return float(adapter.enemy_energy_max)

		if key == "enemy_reserved_energy":
			return float(adapter.enemy_reserved_energy)

		# Useful safe extras, already part of the adapter-style battle state.
		if key == "enemy_hull_current":
			return float(adapter.enemy_hull_current)

		if key == "enemy_hull_max":
			return float(adapter.enemy_hull_max)

		if key == "player_hull_current":
			return float(adapter.player_hull_current)

		if key == "player_hull_max":
			return float(adapter.player_hull_max)

		if key == "base_player_hull_max":
			return float(adapter.base_player_hull_max)

		if key == "player_energy_current":
			return float(adapter.player_energy_current)

		if key == "player_energy_max":
			return float(adapter.player_energy_max)

		if key == "player_energy_regen_per_second":
			return float(adapter.player_energy_regen_per_second)

		if key == "base_player_energy_max":
			return float(adapter.base_player_energy_max)

		if key == "attack":
			return float(adapter.attack)

		if key == "shield_power_level":
			return float(adapter.shield_power_level)

		if key == "shield_hp_current":
			return float(adapter.shield_hp_current)

		if key == "enemy_signal_defense":
			return float(adapter.enemy_signal_defense)

	if unit_ref is Dictionary:
		return float(unit_ref.get(key, fallback))

	return fallback
	
	
func build_enemy_logic_update_package() -> Dictionary:
	# Summary: Build the clean live-state snapshot passed into EnemyLogic.
	if enemy_battle_controller != null:
		return enemy_battle_controller.build_enemy_logic_update_package()

	var enemy_events: Array = get_active_events_for_side("enemy")
	var player_events: Array = get_active_events_for_side("player")
	var enemy_health_ratio := get_unit_health_ratio(active_enemy)
	var player_health_ratio := get_unit_health_ratio(player_state_packet)

	return {
		"enemy": active_enemy,
		"player_state": player_state_packet,
		"battle_id": battle_id,
		"battle_active": not battle_v2_ended,
		"battle_ended": battle_v2_ended,
		"battle_v2_ended": battle_v2_ended,

		"enemy_energy": build_enemy_energy_snapshot(),
		"enemy_ammo": build_enemy_ammo_snapshot(),
		"enemy_loadout": build_enemy_loadout_snapshot(),
		"enemy_shield": build_enemy_shield_snapshot(),
		"enemy_consumable": build_enemy_consumable_snapshot(),
		"enemy_health_ratio": enemy_health_ratio,
		"player_health_ratio": player_health_ratio,

		"enemy_has_good_lock": get_unit_bool(active_enemy, "enemy_good_lock", false),
		"enemy_lock_pending": get_unit_bool(active_enemy, "enemy_lock_pending", false),
		"enemy_lock_disabled": get_unit_bool(active_enemy, "enemy_lock_disabled", false),
		"player_has_good_lock": get_unit_bool(player_state_packet, "player_good_lock", false),

		"active_enemy_events": enemy_events,
		"active_player_events": player_events,

		"enemy_evade_cooldown_remaining_seconds": get_enemy_evade_cooldown_remaining_seconds(active_enemy),
		"time_now_msec": Time.get_ticks_msec(),

		"battle_manager": battle_manager_v2,
		"event_manager": battle_event_manager
	}


func build_enemy_loadout_snapshot() -> Dictionary:
	# Summary: Fallback enemy loadout snapshot when EnemyBattleController is not active.
	if active_enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
		return {
			"primary": enemy_state.selected_primary_weapon,
			"secondary": enemy_state.selected_secondary_weapon,
			"shield": enemy_state.selected_enemy_shield,
			"consumable": get_enemy_first_consumable_id_from_stacks(enemy_state.enemy_item_stacks),
			"consumable_item_data": get_main_project_item_data(get_enemy_first_consumable_id_from_stacks(enemy_state.enemy_item_stacks)),
			"usable_consumables": build_enemy_usable_consumables_snapshot_from_stacks(enemy_state.enemy_item_stacks),
			"item_stacks": enemy_state.enemy_item_stacks.duplicate(true)
		}
	return {}


func get_enemy_first_consumable_id_from_stacks(stacks: Dictionary) -> String:
	# Summary: Pick the first held enemy consumable id from stack data without treating it as already loaded.
	for raw_id in stacks.keys():
		var item_id := normalize_enemy_battle_item_id(str(raw_id).strip_edges())
		if item_id == "" or int(stacks.get(raw_id, 0)) <= 0:
			continue
		var item_data := get_main_project_item_data(item_id)
		if is_enemy_consumable_item_data(item_data):
			return item_id
	return ""


func build_enemy_usable_consumables_snapshot_from_stacks(stacks: Dictionary) -> Array:
	# Summary: Build held consumable packets for EnemyLogic when the controller fallback path is used.
	var usable: Array = []
	for raw_id in stacks.keys():
		var item_id := normalize_enemy_battle_item_id(str(raw_id).strip_edges())
		var count = max(int(stacks.get(raw_id, 0)), 0)
		if item_id == "" or count <= 0:
			continue
		var item_data := get_main_project_item_data(item_id)
		if not is_enemy_consumable_item_data(item_data):
			continue
		usable.append({
			"item_id": item_id,
			"stack_count": count,
			"consumable_group": str(item_data.get("consumable_group", item_data.get("group", item_data.get("subtype", "")))).strip_edges().to_lower(),
			"item_data": item_data
		})
	return usable


func is_enemy_consumable_item_data(item_data: Dictionary) -> bool:
	# Summary: True when item metadata describes a consumable-style item.
	if item_data.is_empty():
		return false
	var item_type := str(item_data.get("item_type", item_data.get("type", ""))).strip_edges().to_lower()
	var group := str(item_data.get("consumable_group", item_data.get("group", item_data.get("subtype", "")))).strip_edges().to_lower()
	return item_type == "consumable" or bool(item_data.get("consumable", false)) or is_enemy_consumable_group(group)


func is_enemy_consumable_group(group_id: String) -> bool:
	# Summary: Avoid treating ammo/weapon stack metadata as consumables just because they have a generic group field.
	var clean_group := group_id.strip_edges().to_lower()
	return clean_group == "repair" or clean_group == "shield_repair" or clean_group == "recharge" or clean_group == "explosive" or clean_group == "signal" or clean_group == "drone" or clean_group == "pulse" or clean_group == "override"


func build_enemy_shield_snapshot() -> Dictionary:
	# Summary: Fallback enemy shield snapshot when EnemyBattleController is not active.
	if active_enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
		return {
			"selected_shield": enemy_state.selected_shield,
			"selected_enemy_shield": enemy_state.selected_enemy_shield,
			"pending_shield": enemy_state.pending_shield,
			"shield_switching": enemy_state.shield_switching,
			"shield_power_level": enemy_state.shield_power_level,
			"shield_hp_current": enemy_state.shield_hp_current,
			"shield_hp_max": enemy_state.shield_hp_max,
			"shield_disabled": enemy_state.shield_disabled,
			"equipped_shield_item_id": enemy_state.get_shield_item_id(enemy_state.selected_shield),
			"equipped_shield_inventory_count": enemy_state.get_enemy_item_count(enemy_state.get_shield_item_id(enemy_state.selected_shield))
		}
	return {}


func build_enemy_consumable_snapshot() -> Dictionary:
	# Summary: Fallback enemy consumable snapshot when EnemyBattleController is not active.
	if active_enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
		return {
			"loaded_consumable": enemy_state.loaded_consumable,
			"loaded_consumable_state": enemy_state.loaded_consumable_state,
			"consumable_ready": enemy_state.consumable_ready,
			"enemy_loaded_consumable": enemy_state.enemy_loaded_consumable,
			"enemy_consumable_ready": enemy_state.enemy_consumable_ready
		}
	return {}


func build_enemy_energy_snapshot() -> Dictionary:
	# Summary: Enemy energy snapshot from the enemy EnergyHandler when available.
	if enemy_energy_handler_v2 != null:
		sync_active_enemy_energy_from_handler()
		return {
			"current": enemy_energy_handler_v2.current_energy,
			"max": enemy_energy_handler_v2.max_energy,
			"reserved": enemy_energy_handler_v2.reserved_energy,
			"available": enemy_energy_handler_v2.get_available_energy(),
			"handler_ready": true,
			"source": "enemy_energy_handler_v2"
		}

	return {
		"current": get_unit_float(active_enemy, "enemy_energy_current", 0.0),
		"max": get_unit_float(active_enemy, "enemy_energy_max", 0.0),
		"reserved": get_unit_float(active_enemy, "enemy_reserved_energy", 0.0),
		"available": max(get_unit_float(active_enemy, "enemy_energy_current", 0.0) - get_unit_float(active_enemy, "enemy_reserved_energy", 0.0), 0.0),
		"handler_ready": false,
		"source": "enemy_adapter_fallback"
	}


func build_enemy_ammo_snapshot() -> Dictionary:
	# Summary: Enemy ammo/item snapshot for EnemyLogic decisions.
	var item_stacks := {}
	if active_enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
		item_stacks = enemy_state.enemy_item_stacks.duplicate(true)

	return {
		"small": get_enemy_ammo_count_from_stacks(item_stacks, "small"),
		"medium": get_enemy_ammo_count_from_stacks(item_stacks, "medium"),
		"large": get_enemy_ammo_count_from_stacks(item_stacks, "large"),
		"item_stacks": item_stacks,
		"handler_ready": false,
		"source": "enemy_adapter_item_stacks"
	}


func get_unit_health_ratio(unit_ref) -> float:
	# Summary: Read BattleV2UnitAdapter hull safely for player or enemy.
	if unit_ref == null:
		return 0.0

	if unit_ref is BattleV2UnitAdapter:
		var adapter: BattleV2UnitAdapter = unit_ref

		if adapter == player_state_packet:
			if adapter.player_hull_max <= 0.0:
				return 0.0
			return clamp(adapter.player_hull_current / adapter.player_hull_max, 0.0, 1.0)

		if adapter == active_enemy:
			if adapter.enemy_hull_max <= 0.0:
				return 0.0
			return clamp(adapter.enemy_hull_current / adapter.enemy_hull_max, 0.0, 1.0)

	if unit_ref is Dictionary:
		var current := float(unit_ref.get("hull", unit_ref.get("hp", unit_ref.get("current_hp", 0.0))))
		var max_value := float(unit_ref.get("max_hull", unit_ref.get("max_hp", 1.0)))

		if max_value <= 0.0:
			return 0.0

		return clamp(current / max_value, 0.0, 1.0)

	return 0.0


func get_unit_bool(unit_ref, key: String, fallback: bool = false) -> bool:
	# Summary: Read known battle state bools from adapters or dictionaries without guessing new fields.
	if unit_ref == null:
		return fallback

	if unit_ref is BattleV2UnitAdapter:
		var adapter: BattleV2UnitAdapter = unit_ref

		if key == "enemy_good_lock":
			return bool(adapter.enemy_good_lock)
		if key == "enemy_lock_pending":
			return bool(adapter.enemy_lock_pending)
		if key == "enemy_lock_disabled":
			return bool(adapter.enemy_lock_disabled)
		if key == "player_good_lock":
			return bool(adapter.player_good_lock)
		if key == "player_lock_pending":
			return bool(adapter.player_lock_pending)
		if key == "player_lock_disabled":
			return bool(adapter.player_lock_disabled)

	if unit_ref is Dictionary:
		return bool(unit_ref.get(key, fallback))

	return fallback


func get_enemy_evade_cooldown_remaining_seconds(enemy_ref) -> float:
	# Summary: Read the existing enemy evade cooldown table as a snapshot value for EnemyLogic.
	if enemy_battle_controller != null:
		return enemy_battle_controller.get_enemy_evade_cooldown_remaining_seconds(enemy_ref)

	var enemy_key := get_enemy_evade_cooldown_key(enemy_ref)
	var cooldown_until_msec: int = int(enemy_evade_cooldown_until_msec_by_key.get(enemy_key, 0))
	var remaining_msec: int = cooldown_until_msec - Time.get_ticks_msec()

	if remaining_msec <= 0:
		return 0.0

	return float(remaining_msec) / 1000.0


func queue_enemy_intent_from_logic() -> Dictionary:
	# Summary:
	# Active enemy-think queue route.
	# This does not resolve combat. It only builds and queues an enemy TODO.
	if enemy_battle_controller != null:
		return enemy_battle_controller.queue_enemy_intent_from_logic()

	var update_package: Dictionary = build_enemy_logic_update_package()
	var attack_value: float = max(float(get_handoff_enemy_attack()), 8.0)

	var packet_result: Dictionary = battle_action_manager.battle_action_packet_builder.build_enemy_action_packet({
		"enemy_logic": enemy_logic_v2,
		"enemy": active_enemy,
		"player_state": player_state_packet,
		"source_unit": active_enemy,
		"owner_unit": active_enemy,
		"target_unit": player_state_packet,
		"event_side": "enemy",
		"battle_id": battle_id,
		"battle_active": not battle_v2_ended,
		"battle_ended": battle_v2_ended,
		"battle_v2_ended": battle_v2_ended,
		"battle_manager": battle_manager_v2,
		"event_manager": battle_event_manager,
		"enemy_update_package": update_package,
		"damage_type": "energy",
		"damage_value": attack_value,
		"signal_strength": attack_value,
		"intent_data": {
			"attack": attack_value,
			"damage_value": attack_value
		}
	})

	if packet_result.get("status", "") != "built":
		set_enemy_think_cooldown(enemy_wait_cooldown_seconds)

		var reason := str(packet_result.get("reason", "enemy intent did not build event"))

		if Globals.print_priority_5:
			print("[enemy_intent_not_queued] ", reason)

		return {
			"status": "not_queued",
			"reason": reason,
			"labels": packet_result.get("labels", [])
		}

	var enemy_event_packet: Dictionary = packet_result.get("event_packet", {})
	if enemy_event_packet.is_empty():
		set_enemy_think_cooldown(enemy_wait_cooldown_seconds)

		return {
			"status": "failed",
			"reason": "packet_result missing event_packet",
			"labels": ["enemy_logic_no_spam_gate", "enemy_packet_missing_event_packet"]
		}

	var cooldown_result: Dictionary = can_queue_enemy_evade_packet(enemy_event_packet)
	if str(cooldown_result.get("status", "")) != "success":
		set_enemy_think_cooldown(enemy_wait_cooldown_seconds)

		if log_label != null:
			log_label.text += "\nEnemy evade held: cooldown " + ("%0.1f" % float(cooldown_result.get("remaining_seconds", 0.0))) + "s remaining.\n"

		return {
			"status": "held",
			"reason": cooldown_result.get("reason", "enemy evade cooldown active"),
			"labels": cooldown_result.get("labels", [])
		}

	var event_result: Dictionary = battle_event_manager.add_event(enemy_event_packet)

	if not bool(event_result.get("accepted", false)):
		set_enemy_think_cooldown(enemy_wait_cooldown_seconds)

		if log_label != null:
			log_label.text += "\nEnemy intent queue rejected: " + str(event_result.get("blocked_reason", "unknown")) + "\n"

		return {
			"status": "rejected",
			"reason": event_result.get("blocked_reason", "EventManager rejected enemy event"),
			"labels": event_result.get("labels", [])
		}

	mark_enemy_lock_reacquire_pending_if_needed(enemy_event_packet)
	set_enemy_think_cooldown(get_enemy_decision_cooldown_seconds())
	refresh_todo_timeline_from_event_manager()

	if log_label != null:
		log_label.text += (
			"\nEnemy queued: "
			+ str(enemy_event_packet.get("event_type", "unknown"))
			+ "\nEvent id: "
			+ str(event_result.get("event_id", "pending"))
			+ "\nIntent path: EnemyThinkLoop -> EnemyLogic -> PacketBuilder -> EventManager\n"
		)

	return {
		"status": "queued",
		"event_id": event_result.get("event_id", ""),
		"event_type": enemy_event_packet.get("event_type", ""),
		"labels": [
			"enemy_logic_think_tick",
			"enemy_logic_state_snapshot",
			"enemy_logic_no_spam_gate",
			"enemy_action_queued_to_event_manager"
		]
	}


func set_enemy_think_cooldown(seconds: float) -> void:
	# Summary: Prevent the active enemy loop from asking for another action immediately.
	if enemy_battle_controller != null:
		enemy_battle_controller.set_enemy_think_cooldown(seconds)
		return

	var cooldown_msec := int(max(seconds, 0.0) * 1000.0)
	enemy_action_cooldown_until_msec = Time.get_ticks_msec() + cooldown_msec


func get_enemy_decision_cooldown_seconds() -> float:
	# Summary: Let behavior profiles slow or speed enemy response cadence without changing action rules.
	if enemy_logic_v2 != null and enemy_logic_v2.has_method("get_decision_cooldown_seconds"):
		return float(enemy_logic_v2.get_decision_cooldown_seconds(active_enemy, enemy_action_cooldown_seconds))
	return enemy_action_cooldown_seconds


func queue_enemy_intent_response(completed_event: Dictionary) -> void:
	# Summary: Queue one enemy response after a completed player event using EnemyLogic through PacketBuilder.
	if str(completed_event.get("event_side", "")) != "player":
		return
	if enemy_logic_v2 == null or battle_event_manager == null or battle_action_manager == null:
		return
	if active_enemy == null or player_state_packet == null:
		return
	if battle_action_manager.battle_action_packet_builder == null:
		return
	if not can_continue_enemy_response_loop():
		if log_label != null:
			log_label.text += "\nEnemy intent held: battle loop is no longer active.\n"
		return
	if has_pending_enemy_response_event():
		if log_label != null:
			log_label.text += "\nEnemy intent held: enemy response already pending.\n"
		refresh_todo_timeline_from_event_manager()
		return

	var attack_value: float = max(float(get_handoff_enemy_attack()), 8.0)
	var packet_result: Dictionary = battle_action_manager.battle_action_packet_builder.build_enemy_action_packet({
		"enemy_logic": enemy_logic_v2,
		"enemy": active_enemy,
		"player_state": player_state_packet,
		"source_unit": active_enemy,
		"owner_unit": active_enemy,
		"target_unit": player_state_packet,
		"event_side": "enemy",
		"battle_id": battle_id,
		"battle_active": not battle_v2_ended,
		"battle_ended": battle_v2_ended,
		"battle_v2_ended": battle_v2_ended,
		"battle_manager": battle_manager_v2,
		"event_manager": battle_event_manager,
		"duration": 2.0,
		"evade_duration": evade_todo_duration_seconds,
		"evade_cooldown_seconds": evade_cooldown_seconds,
		"damage_type": "energy",
		"damage_value": attack_value,
		"signal_strength": attack_value,
		"intent_data": {
			"duration": 2.0,
			"evade_duration": evade_todo_duration_seconds,
			"attack": attack_value,
			"damage_value": attack_value
		}
	})

	if packet_result.get("status", "") != "built":
		log_label.text += "\nEnemy intent held: " + str(packet_result.get("reason", "no queued action")) + "\n"
		return

	var enemy_event_packet: Dictionary = packet_result.get("event_packet", {})
	var cooldown_result: Dictionary = can_queue_enemy_evade_packet(enemy_event_packet)
	if str(cooldown_result.get("status", "")) != "success":
		if log_label != null:
			log_label.text += "\nEnemy evade held: " + str(cooldown_result.get("reason", "evade unavailable")) + " (" + ("%0.1f" % float(cooldown_result.get("remaining_seconds", 0.0))) + "s).\n"
		if Globals.print_priority_5:
			print("[enemy_evade_cooldown_block] key=", cooldown_result.get("enemy_key", ""), " remaining=", cooldown_result.get("remaining_seconds", 0.0))
		refresh_todo_timeline_from_event_manager()
		return

	var event_result: Dictionary = battle_event_manager.add_event(enemy_event_packet)
	if bool(event_result.get("accepted", false)):
		var event_packet: Dictionary = enemy_event_packet
		if is_enemy_evade_event_packet(event_packet):
			record_queued_enemy_evade_cooldown(event_packet)
			apply_evade_queue_effects(event_packet)
		mark_enemy_lock_reacquire_pending_if_needed(event_packet)
		log_label.text += (
			"\nEnemy queued: "
			+ str(event_packet.get("event_type", "unknown"))
			+ "\nEvent id: "
			+ str(event_result.get("event_id", "pending"))
			+ "\nIntent path: EnemyLogic -> PacketBuilder -> EventManager\n"
		)
	else:
		log_label.text += "\nEnemy intent queue rejected: " + str(event_result.get("blocked_reason", "unknown")) + "\n"


func mark_enemy_lock_reacquire_pending_if_needed(event_packet: Dictionary) -> void:
	# Summary: Mirror queued enemy lock-restore TODOs into the enemy pending lock flag for logic/UI.
	if typeof(event_packet) != TYPE_DICTIONARY:
		return
	if str(event_packet.get("event_type", "")).strip_edges().to_lower() != "enemy_reacquire_lock":
		return
	if active_enemy == null:
		return
	if active_enemy is Object and active_enemy.has_method("set_enemy_lock_pending"):
		active_enemy.set_enemy_lock_pending(true)
		refresh_unit_status_values()


func queue_player_lock_reacquire_if_needed() -> void:
	# Summary: Auto-queue a timed player lock restore when player lock is bad and no restore is pending.
	if battle_event_manager == null:
		return
	if player_state_packet == null:
		return
	if battle_v2_ended:
		return
	if player_state_packet.player_lock_disabled:
		return
	if player_state_packet.player_good_lock:
		return
	if player_state_packet.player_lock_pending:
		return
	if has_active_lock_restore_for_unit(player_state_packet, "player_reacquire_lock"):
		player_state_packet.set_player_lock_pending(true)
		return

	var event_packet: Dictionary = build_player_lock_reacquire_event_packet()
	var event_result: Dictionary = battle_event_manager.add_event(event_packet)
	if bool(event_result.get("accepted", false)):
		player_state_packet.set_player_lock_pending(true)
		if log_label != null:
			log_label.text += "\nPlayer lock reacquire queued: " + str(event_result.get("event_id", "pending")) + "\n"
		if Globals.print_priority_5:
			print("[player_lock_reacquire_queued] event_id=", event_result.get("event_id", ""))
	else:
		if log_label != null:
			log_label.text += "\nPlayer lock reacquire rejected: " + str(event_result.get("blocked_reason", "unknown")) + "\n"
		if Globals.print_priority_5:
			print("[player_lock_reacquire_rejected] reason=", event_result.get("blocked_reason", "unknown"))


func queue_enemy_lock_reacquire_if_needed() -> void:
	# Summary: Auto-queue a timed enemy lock restore when enemy lock is bad and no restore is pending.
	if battle_event_manager == null:
		return
	if active_enemy == null:
		return
	if battle_v2_ended:
		return
	if not (active_enemy is BattleV2UnitAdapter):
		return

	var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
	if enemy_state.enemy_lock_disabled:
		return
	if enemy_state.enemy_good_lock:
		return
	if enemy_state.enemy_lock_pending:
		return
	if has_active_lock_restore_for_unit(active_enemy, "enemy_reacquire_lock"):
		enemy_state.set_enemy_lock_pending(true)
		return

	queue_or_extend_lock_reacquire_for_unit(
		active_enemy,
		"enemy",
		"enemy_reacquire_lock",
		"enemy_reacquire_lock",
		PLAYER_LOCK_REACQUIRE_DURATION_SECONDS,
		[
			"enemy_lock_auto_reacquire",
			"timed_lock_restore"
		]
	)


func build_player_lock_reacquire_event_packet() -> Dictionary:
	# Summary: Build a system-owned TODO that restores player good lock when the timer completes.
	return {
		"event_id": "",
		"event_type": "player_reacquire_lock",
		"event_group": "lock",
		"event_subtype": "lock_restore",
		"source_unit": player_state_packet,
		"target_unit": player_state_packet,
		"owner_unit": player_state_packet,
		"event_side": "system",
		"duration": PLAYER_LOCK_REACQUIRE_DURATION_SECONDS,
		"time_remaining": PLAYER_LOCK_REACQUIRE_DURATION_SECONDS,
		"same_type_key": "player_reacquire_lock",
		"requires_lock": false,
		"is_state_change": true,
		"is_damage_event": false,
		"is_effect_event": false,
		"is_visual_only": false,
		"item_id": "",
		"action_id": "player_reacquire_lock",
		"damage_type": "",
		"damage_value": 0.0,
		"battle_id": battle_id,
		"data": {
			"lock_action": "restore",
			"auto_reacquire": true,
			"labels": [
				"player_lock_auto_reacquire",
				"timed_lock_restore"
			]
		}
	}


func has_active_lock_restore_for_unit(unit_ref, same_type_key: String) -> bool:
	# Summary: Avoid duplicate lock restore TODOs for the same unit/key.
	if battle_event_manager == null:
		return false

	for event_packet in battle_event_manager.active_events:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		if str(event_packet.get("same_type_key", "")) != same_type_key:
			continue
		if event_packet.get("owner_unit", null) == unit_ref:
			return true

	return false


func has_active_weapon_todo(side: String = "") -> bool:
	# Summary: Evade requires a weapon-free TODO lane only for the battler trying to evade.
	if battle_event_manager == null:
		return false

	var clean_side := side.strip_edges().to_lower()
	for event_packet in battle_event_manager.active_events:
		if is_weapon_todo_event(event_packet, clean_side):
			return true

	return false


func is_weapon_todo_event(event_packet, side: String = "") -> bool:
	# Summary: Identify active weapon TODOs that block evade.
	if typeof(event_packet) != TYPE_DICTIONARY:
		return false

	var clean_side := side.strip_edges().to_lower()
	if clean_side != "":
		var event_side := str(event_packet.get("event_side", "")).strip_edges().to_lower()
		if event_side == "":
			var inferred_type := str(event_packet.get("event_type", "")).strip_edges().to_lower()
			if inferred_type == "fire_primary_weapon" or inferred_type == "fire_secondary_weapon":
				event_side = "player"
			elif inferred_type == "enemy_primary_attack" or inferred_type == "enemy_secondary_attack":
				event_side = "enemy"
		if event_side != clean_side:
			return false

	var event_group := str(event_packet.get("event_group", "")).strip_edges().to_lower()
	if event_group == "weapon":
		return true

	var event_type := str(event_packet.get("event_type", "")).strip_edges().to_lower()
	return event_type == "fire_primary_weapon" or event_type == "fire_secondary_weapon" or event_type == "enemy_primary_attack" or event_type == "enemy_secondary_attack"


func has_active_evade_todo_for_side(side: String) -> bool:
	# Summary: Prevent duplicate active evade TODOs for a unit side.
	if battle_event_manager == null:
		return false

	var clean_side := side.strip_edges().to_lower()
	for event_packet in battle_event_manager.active_events:
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		if str(event_packet.get("event_side", "")).strip_edges().to_lower() != clean_side:
			continue
		if is_evade_event_packet(event_packet):
			return true

	return false


func is_evade_event_packet(event_packet: Dictionary) -> bool:
	# Summary: Identify player or enemy evade packets.
	var event_group := str(event_packet.get("event_group", "")).strip_edges().to_lower()
	var event_type := str(event_packet.get("event_type", "")).strip_edges().to_lower()
	var event_subtype := str(event_packet.get("event_subtype", "")).strip_edges().to_lower()
	return event_group == "evade" or event_type == "player_evade" or event_type == "enemy_evade" or event_subtype == "evade_complete"


func apply_evade_queue_effects(event_packet: Dictionary) -> void:
	# Summary: Mark evade as queued; lock disruption waits for the 5-second evade TODO completion.
	if typeof(event_packet) != TYPE_DICTIONARY or event_packet.is_empty():
		return
	if not is_evade_event_packet(event_packet):
		return

	var data_payload = event_packet.get("data", {})
	if typeof(data_payload) != TYPE_DICTIONARY:
		data_payload = {}
	data_payload["lock_loss_already_applied"] = false
	data_payload["evade_relock_duration_seconds"] = evade_todo_duration_seconds
	data_payload["evade_lock_reacquire_penalty_seconds"] = evade_lock_reacquire_penalty_seconds
	data_payload["labels"] = append_label_list(data_payload.get("labels", []), [
		"evade_todo_started",
		"evade_countdown_active",
		"evade_can_reduce_lock_quality"
	])
	event_packet["data"] = data_payload


func append_label_list(source_labels, new_labels: Array) -> Array:
	# Summary: Merge labels without assuming an existing array shape.
	var labels: Array = []
	if typeof(source_labels) == TYPE_ARRAY:
		for label in source_labels:
			labels.append(str(label))
	for label in new_labels:
		if not labels.has(str(label)):
			labels.append(str(label))
	return labels


func apply_lock_lost_for_scene_unit(unit_ref) -> void:
	# Summary: Apply immediate evade lock disruption without waiting for TODO completion.
	if unit_ref == null or not (unit_ref is Object):
		return

	var unit_side := get_scene_unit_side(unit_ref)
	if unit_side == "enemy" and unit_ref.has_method("set_enemy_lock_lost"):
		unit_ref.set_enemy_lock_lost()
		return
	if unit_side == "player" and unit_ref.has_method("set_player_lock_lost"):
		unit_ref.set_player_lock_lost()
		return
	if unit_ref.has_method("set_player_lock_lost"):
		unit_ref.set_player_lock_lost()
	elif unit_ref.has_method("set_enemy_lock_lost"):
		unit_ref.set_enemy_lock_lost()


func queue_evade_relock_for_unit(unit_ref) -> void:
	# Summary: Queue or extend the relock TODO that starts at the same moment as the evade maneuver.
	if unit_ref == null:
		return

	var unit_side := get_scene_unit_side(unit_ref)
	if unit_side != "player" and unit_side != "enemy":
		return

	var event_type := unit_side + "_reacquire_lock"
	var same_type_key := event_type
	queue_or_extend_lock_reacquire_for_unit(
		unit_ref,
		unit_side,
		event_type,
		same_type_key,
		evade_todo_duration_seconds,
		[
			"evade_relock_todo",
			"evade_penalty_relock_time",
			"timed_lock_restore"
		]
	)


func queue_or_extend_lock_reacquire_for_unit(unit_ref, unit_side: String, event_type: String, same_type_key: String, duration_seconds: float, labels: Array) -> void:
	# Summary: Ensure one relock TODO exists, extending it instead of stacking duplicate relock events.
	if battle_event_manager == null:
		return

	for active_event in battle_event_manager.active_events:
		if typeof(active_event) != TYPE_DICTIONARY:
			continue
		if str(active_event.get("same_type_key", "")) != same_type_key:
			continue
		if active_event.get("owner_unit", null) != unit_ref:
			continue
		active_event["duration"] = max(float(active_event.get("duration", 0.0)), duration_seconds)
		active_event["time_remaining"] = max(float(active_event.get("time_remaining", 0.0)), duration_seconds)
		mark_lock_pending_for_unit(unit_ref)
		return

	var event_packet: Dictionary = build_generic_lock_reacquire_event_packet(unit_ref, unit_side, event_type, same_type_key, duration_seconds, labels)
	var event_result: Dictionary = battle_event_manager.add_event(event_packet)
	if bool(event_result.get("accepted", false)):
		mark_lock_pending_for_unit(unit_ref)
		if Globals.print_priority_5:
			print("[evade_relock_queued] side=", unit_side, " event_id=", event_result.get("event_id", ""), " duration=", duration_seconds)
	elif log_label != null:
		log_label.text += "\nEvade relock rejected: " + str(event_result.get("blocked_reason", "unknown")) + "\n"


func build_generic_lock_reacquire_event_packet(unit_ref, unit_side: String, event_type: String, same_type_key: String, duration_seconds: float, labels: Array) -> Dictionary:
	# Summary: Build a timed lock restore TODO for player or enemy.
	var event_side := "system" if unit_side == "player" else "enemy"
	return {
		"event_id": "",
		"event_type": event_type,
		"event_group": "lock",
		"event_subtype": "lock_restore",
		"source_unit": unit_ref,
		"target_unit": unit_ref,
		"owner_unit": unit_ref,
		"event_side": event_side,
		"duration": duration_seconds,
		"time_remaining": duration_seconds,
		"same_type_key": same_type_key,
		"requires_lock": false,
		"is_state_change": true,
		"is_damage_event": false,
		"is_effect_event": false,
		"is_visual_only": false,
		"item_id": "",
		"action_id": event_type,
		"damage_type": "",
		"damage_value": 0.0,
		"battle_id": battle_id,
		"data": {
			"lock_action": "restore",
			"auto_reacquire": true,
			"evade_relock": true,
			"evade_relock_duration_seconds": duration_seconds,
			"evade_lock_reacquire_penalty_seconds": evade_lock_reacquire_penalty_seconds,
			"labels": labels
		}
	}


func mark_lock_pending_for_unit(unit_ref) -> void:
	# Summary: Mirror relock TODO state into the adapter/UI lock fields.
	if unit_ref == null or not (unit_ref is Object):
		return

	var unit_side := get_scene_unit_side(unit_ref)
	if unit_side == "enemy" and unit_ref.has_method("set_enemy_lock_pending"):
		unit_ref.set_enemy_lock_pending(true)
	elif unit_side == "player" and unit_ref.has_method("set_player_lock_pending"):
		unit_ref.set_player_lock_pending(true)


func get_scene_unit_side(unit_ref) -> String:
	# Summary: Read Battle V2 unit side for scene-level lock helpers.
	if unit_ref == null:
		return ""
	if unit_ref is Dictionary:
		return str(unit_ref.get("unit_side", "")).strip_edges().to_lower()
	if unit_ref is Object:
		var side_value = unit_ref.get("unit_side")
		if side_value != null:
			return str(side_value).strip_edges().to_lower()
	return ""


func can_queue_enemy_evade_packet(event_packet: Dictionary) -> Dictionary:
	# Summary: Enforce the enemy evade cooldown at the final queue boundary.
	if enemy_battle_controller != null:
		return enemy_battle_controller.can_queue_enemy_evade_packet(event_packet)

	if not is_enemy_evade_event_packet(event_packet):
		return {
			"status": "success",
			"reason": "",
			"labels": ["enemy_evade_queue_cooldown_check"]
		}

	if has_active_weapon_todo("enemy"):
		return {
			"status": "failed",
			"reason": "enemy weapon TODO active",
			"remaining_seconds": 0.0,
			"labels": [
				"enemy_evade_queue_cooldown_check",
				"evade_blocked_weapon_todo_active"
			]
		}

	if has_active_evade_todo_for_side("enemy"):
		return {
			"status": "failed",
			"reason": "enemy evade already active",
			"remaining_seconds": 0.0,
			"labels": [
				"enemy_evade_queue_cooldown_check",
				"evade_todo_active"
			]
		}

	var enemy_key := get_enemy_evade_cooldown_key(event_packet.get("owner_unit", event_packet.get("source_unit", active_enemy)))
	var now_msec: int = Time.get_ticks_msec()
	var cooldown_until_msec: int = int(enemy_evade_cooldown_until_msec_by_key.get(enemy_key, 0))

	if cooldown_until_msec > now_msec:
		return {
			"status": "failed",
			"reason": "enemy evade cooldown active",
			"enemy_key": enemy_key,
			"remaining_seconds": float(cooldown_until_msec - now_msec) / 1000.0,
			"labels": [
				"enemy_evade_queue_cooldown_check",
				"enemy_evade_cooldown_active"
			]
		}

	return {
		"status": "success",
		"reason": "",
		"enemy_key": enemy_key,
		"labels": [
			"enemy_evade_queue_cooldown_check",
			"enemy_evade_cooldown_ready"
		]
	}


func record_completed_enemy_evade_cooldown(event_packet: Dictionary) -> void:
	# Summary: Notify EnemyLogic of completed enemy evade without restarting the queue-time cooldown.
	if enemy_battle_controller != null:
		enemy_battle_controller.record_completed_enemy_evade_cooldown(event_packet)
		return

	if not is_enemy_evade_event_packet(event_packet):
		return

	if Globals.print_priority_5:
		print("[enemy_evade_completed] cooldown was started at queue time")


func record_queued_enemy_evade_cooldown(event_packet: Dictionary) -> void:
	# Summary: Start enemy evade cooldown at queue/use time in the scene fallback path.
	if not is_enemy_evade_event_packet(event_packet):
		return

	var enemy_ref = event_packet.get("owner_unit", event_packet.get("source_unit", active_enemy))
	var enemy_key = get_enemy_evade_cooldown_key(enemy_ref)
	var cooldown_msec := int(evade_cooldown_seconds * 1000.0)
	enemy_evade_cooldown_until_msec_by_key[enemy_key] = Time.get_ticks_msec() + cooldown_msec

	if enemy_logic_v2 != null and enemy_logic_v2.has_method("mark_enemy_evade_completed"):
		enemy_logic_v2.mark_enemy_evade_completed(enemy_ref)

	if Globals.print_priority_5:
		print("[enemy_evade_cooldown_started_on_queue] key=", enemy_key, " seconds=", evade_cooldown_seconds)


func is_enemy_evade_event_packet(event_packet: Dictionary) -> bool:
	# Summary: Identify enemy evade packets from either event type or completion subtype.
	if typeof(event_packet) != TYPE_DICTIONARY:
		return false
	if str(event_packet.get("event_side", "")).strip_edges().to_lower() != "enemy":
		return false

	var event_type := str(event_packet.get("event_type", "")).strip_edges().to_lower()
	var event_subtype := str(event_packet.get("event_subtype", "")).strip_edges().to_lower()
	return event_type == "enemy_evade" or event_subtype == "evade_complete"


func get_enemy_evade_cooldown_key(enemy_ref) -> String:
	# Summary: Build a stable key for scene-level enemy evade cooldown tracking.
	if enemy_ref == null:
		return "enemy_null"

	if typeof(enemy_ref) == TYPE_DICTIONARY:
		for key in ["unit_id", "enemy_id", "id", "display_name", "name"]:
			var value = enemy_ref.get(key, null)
			if value != null and str(value).strip_edges() != "":
				return str(value).strip_edges()
		return str(enemy_ref)

	if enemy_ref is Object:
		for key in ["unit_id", "enemy_id", "id", "display_name", "name"]:
			var value = enemy_ref.get(key)
			if value != null and str(value).strip_edges() != "":
				return str(value).strip_edges()

	return str(enemy_ref)


func refresh_unit_status_values() -> void:
	# Summary: Refresh visible unit hull and lock labels after BattleManager mutates battle-state adapters.
	if player_state_packet != null:
		set_lookup_label_text(
			"player_hull",
			"Hull: " + str(int(player_state_packet.player_hull_current)) + " / " + str(int(player_state_packet.player_hull_max))
		)
		set_lookup_label_text("player_shield", get_player_shield_status_text())
		set_lookup_label_text("player_shield_energy", get_player_shield_energy_status_text())
		set_lookup_label_text(
			"player_lock",
			"Lock: " + get_lock_status_text(player_state_packet.player_good_lock, player_state_packet.player_lock_disabled, player_state_packet.player_lock_pending)
		)

	if active_enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
		set_lookup_label_text(
			"enemy_hull",
			"Hull: " + str(int(enemy_state.enemy_hull_current)) + " / " + str(int(enemy_state.enemy_hull_max))
		)
		set_lookup_label_text("enemy_shield", get_enemy_shield_status_text(enemy_state))
		set_lookup_label_text("enemy_shield_energy", get_enemy_shield_energy_status_text(enemy_state))
		set_lookup_label_text(
			"enemy_lock",
			"Lock: " + get_lock_status_text(enemy_state.enemy_good_lock, enemy_state.enemy_lock_disabled, enemy_state.enemy_lock_pending)
		)

	refresh_player_ammo_status_values()
	set_lookup_label_text("enemy_intent", "Intent: placeholder")
	refresh_energy_status_values()
	refresh_enemy_energy_status_values()
	refresh_battle_v3_side_info_windows()
	refresh_battle_v2_unit_status_mirror_widgets()
	report_battle_v2_header_state_to_ui_handler()


func refresh_player_ammo_status_values() -> void:
	# Summary: Display current and reserved ammo from AmmoHandler without owning inventory counts.
	if ammo_handler_v2 == null:
		set_lookup_label_text("player_ammo", "Ammo: not linked")
		return

	sync_battle_inventory_save_data_from_ammo_source()
	var inventory_ref = battle_ammo_inventory_source
	var small_count: int = ammo_handler_v2.get_available_ammo("small", inventory_ref)
	var medium_count: int = ammo_handler_v2.get_available_ammo("medium", inventory_ref)
	var large_count: int = ammo_handler_v2.get_available_ammo("large", inventory_ref)
	var reserved_count: int = ammo_handler_v2.get_reserved_ammo("small") + ammo_handler_v2.get_reserved_ammo("medium") + ammo_handler_v2.get_reserved_ammo("large")
	set_lookup_label_text(
		"player_ammo",
		"Ammo: S" + str(small_count) + " M" + str(medium_count) + " L" + str(large_count) + " R" + str(reserved_count)
	)


func refresh_battle_v3_side_info_windows() -> void:
	refresh_battle_v3_runtime_window("player")
	refresh_battle_v3_runtime_window("enemy")
	refresh_battle_v3_stats_window("player")
	refresh_battle_v3_stats_window("enemy")


func refresh_battle_v3_runtime_window(side: String) -> void:
	var clean_side := side.strip_edges().to_lower()
	var lines := [
		get_battle_v3_drone_runtime_line(clean_side),
		get_battle_v3_effect_runtime_line(clean_side, "signal", "Signals"),
		get_battle_v3_other_runtime_line(clean_side)
	]
	for i in range(lines.size()):
		set_lookup_label_text(clean_side + "_runtime_" + str(i + 1), str(lines[i]))


func refresh_battle_v3_stats_window(side: String) -> void:
	var clean_side := side.strip_edges().to_lower()
	var lines: Array = []
	if clean_side == "enemy":
		lines = [
			get_battle_v3_enemy_ammo_stat_line(),
			get_battle_v3_enemy_weapon_stat_line("primary", "PRI"),
			get_battle_v3_enemy_weapon_stat_line("secondary", "SEC")
		]
	else:
		lines = [
			get_battle_v3_player_ammo_stat_line(),
			get_battle_v3_player_weapon_stat_line(TAB_PRIMARY, "PRI"),
			get_battle_v3_player_weapon_stat_line(TAB_SECONDARY, "SEC")
		]

	for i in range(lines.size()):
		set_lookup_label_text(clean_side + "_stats_" + str(i + 1), str(lines[i]))


func get_battle_v3_drone_runtime_line(side: String) -> String:
	if battle_manager_v2 == null or not battle_manager_v2.has_method("get_active_drone_runtime_snapshot"):
		return "Drones: none"

	var snapshot: Dictionary = battle_manager_v2.get_active_drone_runtime_snapshot()
	var drones: Array = []
	if typeof(snapshot.get("drones", [])) == TYPE_ARRAY:
		for drone in snapshot.get("drones", []):
			if typeof(drone) != TYPE_DICTIONARY:
				continue
			if str(drone.get("owner_side", "")).strip_edges().to_lower() == side:
				drones.append(drone)

	if drones.is_empty():
		return "Drones: none"

	var first: Dictionary = drones[0]
	var drone_type := str(first.get("drone_type", "drone")).replace("_", " ")
	var time_remaining := float(first.get("time_remaining", 0.0))
	var hull_current := float(first.get("hull_current", 0.0))
	var hull_max := float(first.get("hull_max", 0.0))
	var line := "Drones: " + str(drones.size()) + " | " + drone_type + " " + format_battle_value(time_remaining) + "s"
	if hull_max > 0.0:
		line += " HP " + format_battle_value(hull_current) + "/" + format_battle_value(hull_max)
	return line


func get_battle_v3_effect_runtime_line(side: String, effect_group: String, label_text: String) -> String:
	var effects := get_battle_v3_effects_for_side(side)
	var matching: Array = []
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		if str(effect.get("effect_group", "")).strip_edges().to_lower() == effect_group:
			matching.append(effect)
	if matching.is_empty():
		return label_text + ": none"
	return label_text + ": " + get_battle_v3_effect_short_text(matching[0], matching.size())


func get_battle_v3_other_runtime_line(side: String) -> String:
	var effects := get_battle_v3_effects_for_side(side)
	var matching: Array = []
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var group := str(effect.get("effect_group", "")).strip_edges().to_lower()
		if group == "" or group == "signal":
			continue
		matching.append(effect)
	if matching.is_empty():
		return "Other: none"
	return "Other: " + get_battle_v3_effect_short_text(matching[0], matching.size())


func get_battle_v3_effects_for_side(side: String) -> Array:
	if stat_effect_handler_v2 == null or not stat_effect_handler_v2.has_method("get_effects_for_unit"):
		return []
	var unit_ref = get_battle_v3_unit_ref_for_side(side)
	if unit_ref == null:
		return []
	var effects = stat_effect_handler_v2.get_effects_for_unit(unit_ref)
	if typeof(effects) != TYPE_ARRAY:
		return []
	return effects


func get_battle_v3_effect_short_text(effect: Dictionary, total_count: int) -> String:
	var name := str(effect.get("display_name", effect.get("effect_id", effect.get("effect_type", effect.get("effect_group", "effect"))))).strip_edges()
	if name == "":
		name = "effect"
	var time_remaining := float(effect.get("time_remaining", effect.get("duration", 0.0)))
	var text := name + " " + format_battle_value(time_remaining) + "s"
	if total_count > 1:
		text += " +" + str(total_count - 1)
	return text


func get_battle_v3_unit_ref_for_side(side: String):
	if side.strip_edges().to_lower() == "enemy":
		return active_enemy
	return player_state_packet


func get_battle_v3_player_ammo_stat_line() -> String:
	if ammo_handler_v2 == null:
		return "Ammo: not linked"
	sync_battle_inventory_save_data_from_ammo_source()
	var inventory_ref = battle_ammo_inventory_source
	var small_count: int = ammo_handler_v2.get_available_ammo("small", inventory_ref)
	var medium_count: int = ammo_handler_v2.get_available_ammo("medium", inventory_ref)
	var large_count: int = ammo_handler_v2.get_available_ammo("large", inventory_ref)
	var reserved_count: int = ammo_handler_v2.get_reserved_ammo("small") + ammo_handler_v2.get_reserved_ammo("medium") + ammo_handler_v2.get_reserved_ammo("large")
	return "Ammo: S" + str(small_count) + " M" + str(medium_count) + " L" + str(large_count) + " R" + str(reserved_count)


func get_battle_v3_enemy_ammo_stat_line() -> String:
	var ammo := build_enemy_ammo_snapshot()
	return "Ammo: S" + str(int(ammo.get("small", 0))) + " M" + str(int(ammo.get("medium", 0))) + " L" + str(int(ammo.get("large", 0)))


func get_battle_v3_player_weapon_stat_line(tab_id: String, prefix: String) -> String:
	var item_id := get_battle_v3_selected_item_id_for_lane(tab_id)
	if item_id == "":
		return prefix + ": empty"
	var item_data := get_normalized_loadout_item_data(item_id, tab_id)
	return get_battle_v3_item_damage_stat_line(prefix, item_id, item_data)


func get_battle_v3_enemy_weapon_stat_line(slot_name: String, prefix: String) -> String:
	var item_id := get_battle_v3_enemy_item_id_for_slot(slot_name)
	if item_id == "":
		return prefix + ": empty"
	var item_data := get_battle_v3_enemy_item_data(item_id, slot_name)
	return get_battle_v3_item_damage_stat_line(prefix, item_id, item_data)


func get_battle_v3_item_damage_stat_line(prefix: String, item_id: String, item_data: Dictionary) -> String:
	var display_name := item_id
	var damage := 0.0
	var damage_type := ""
	if not item_data.is_empty():
		display_name = get_battle_v3_item_short_name(item_data, item_id)
		damage = float(item_data.get("damage_value", item_data.get("damage", 0.0)))
		damage_type = str(item_data.get("damage_type", "")).strip_edges()
	if damage_type == "":
		damage_type = "dmg"
	return prefix + ": " + display_name + " " + format_battle_value(damage) + " " + damage_type


func get_battle_v3_enemy_item_id_for_slot(slot_name: String) -> String:
	if enemy_battle_controller != null and enemy_battle_controller.has_method("get_enemy_item_id_for_slot"):
		return str(enemy_battle_controller.get_enemy_item_id_for_slot(slot_name)).strip_edges()
	if active_enemy is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
		if slot_name == "secondary":
			return str(enemy_state.selected_secondary_weapon).strip_edges()
		if slot_name == "shield":
			return str(enemy_state.selected_enemy_shield).strip_edges()
		return str(enemy_state.selected_primary_weapon).strip_edges()
	return ""


func get_battle_v3_enemy_item_data(item_id: String, slot_name: String) -> Dictionary:
	if enemy_battle_controller != null and enemy_battle_controller.has_method("get_enemy_item_data_by_id"):
		var fallback_type := "kinetic" if slot_name == "secondary" else "energy"
		var fallback_damage = 6.0 if slot_name == "secondary" else max(float(get_handoff_enemy_attack()), 8.0)
		var data = enemy_battle_controller.get_enemy_item_data_by_id(item_id, fallback_type, fallback_damage)
		if typeof(data) == TYPE_DICTIONARY:
			return data
	var source := get_main_project_item_data(item_id)
	if source.is_empty():
		return {}
	return source


func sync_battle_inventory_save_data_from_ammo_source() -> void:
	# Summary: Keep the scene-level inventory snapshot in sync after AmmoHandler spends from the mutable source.
	if battle_ammo_inventory_source.is_empty():
		return

	var data = battle_ammo_inventory_source.get("inventory_save_data", {})
	if typeof(data) == TYPE_DICTIONARY:
		battle_inventory_save_data = data.duplicate(true)


func sync_energy_handler_shield_drain_from_player_state() -> void:
	# Summary: Send the currently equipped player shield drain rate into EnergyHandler.
	if energy_handler_v2 == null:
		return

	if player_state_packet == null:
		if energy_shield_drain_signature != "no_player_state":
			energy_handler_v2.clear_active_shield_drain()
			energy_shield_drain_signature = "no_player_state"
		return

	energy_handler_v2.set_shield_slider_value(player_state_packet.shield_power_level)

	if player_state_packet.shield_switching:
		if energy_shield_drain_signature != "shield_switching":
			energy_handler_v2.clear_active_shield_drain()
			energy_shield_drain_signature = "shield_switching"
		return

	if typeof(player_state_packet.selected_shield) != TYPE_DICTIONARY:
		if energy_shield_drain_signature != "no_selected_shield":
			energy_handler_v2.clear_active_shield_drain()
			energy_shield_drain_signature = "no_selected_shield"
		return

	var shield_data: Dictionary = player_state_packet.selected_shield as Dictionary
	if shield_data.is_empty():
		if energy_shield_drain_signature != "empty_selected_shield":
			energy_handler_v2.clear_active_shield_drain()
			energy_shield_drain_signature = "empty_selected_shield"
		return

	var shield_id: String = str(shield_data.get("item_id", shield_data.get("id", "")))
	var shield_name: String = str(shield_data.get("display_name", shield_data.get("name", shield_id)))
	var drain_value: float = 0.0
	if energy_handler_v2.has_method("get_shield_drain_value_from_packet"):
		drain_value = energy_handler_v2.get_shield_drain_value_from_packet(shield_data)
	else:
		drain_value = float(shield_data.get("steady_energy_drain", 0.0))

	var new_signature := shield_id + "|" + str(drain_value)
	if energy_shield_drain_signature == new_signature:
		return

	energy_handler_v2.set_active_shield_data(shield_data)
	energy_shield_drain_signature = new_signature

	if Globals.print_priority_5:
		print(
			"[BattleV2Scene.sync_energy_handler_shield_drain_from_player_state]",
			" shield=", shield_name,
			" id=", shield_id,
			" drain_per_second=", drain_value
		)


func sync_energy_handler_shield_drain_from_enemy_state() -> void:
	# Summary: Send the currently equipped enemy shield drain rate into the enemy EnergyHandler.
	if enemy_energy_handler_v2 == null:
		return

	if not (active_enemy is BattleV2UnitAdapter):
		if enemy_energy_shield_drain_signature != "no_enemy_state":
			enemy_energy_handler_v2.clear_active_shield_drain()
			enemy_energy_shield_drain_signature = "no_enemy_state"
		return

	var enemy_state: BattleV2UnitAdapter = active_enemy as BattleV2UnitAdapter
	enemy_energy_handler_v2.set_shield_slider_value(enemy_state.shield_power_level)

	if enemy_state.shield_switching:
		if enemy_energy_shield_drain_signature != "enemy_shield_switching":
			enemy_energy_handler_v2.clear_active_shield_drain()
			enemy_energy_shield_drain_signature = "enemy_shield_switching"
		return

	if typeof(enemy_state.selected_shield) != TYPE_DICTIONARY:
		if enemy_energy_shield_drain_signature != "enemy_no_selected_shield":
			enemy_energy_handler_v2.clear_active_shield_drain()
			enemy_energy_shield_drain_signature = "enemy_no_selected_shield"
		return

	var shield_data: Dictionary = enemy_state.selected_shield as Dictionary
	if shield_data.is_empty():
		if enemy_energy_shield_drain_signature != "enemy_empty_selected_shield":
			enemy_energy_handler_v2.clear_active_shield_drain()
			enemy_energy_shield_drain_signature = "enemy_empty_selected_shield"
		return

	var shield_id: String = str(shield_data.get("item_id", shield_data.get("id", enemy_state.selected_enemy_shield)))
	var shield_name: String = str(shield_data.get("display_name", shield_data.get("name", shield_id)))
	var drain_value: float = 0.0
	if enemy_energy_handler_v2.has_method("get_shield_drain_value_from_packet"):
		drain_value = enemy_energy_handler_v2.get_shield_drain_value_from_packet(shield_data)
	else:
		drain_value = float(shield_data.get("steady_energy_drain", 0.0))

	var new_signature := shield_id + "|" + str(drain_value) + "|" + str(enemy_state.shield_power_level)
	if enemy_energy_shield_drain_signature == new_signature:
		return

	enemy_energy_handler_v2.set_active_shield_data(shield_data)
	enemy_energy_shield_drain_signature = new_signature

	if Globals.print_priority_5:
		print(
			"[BattleV2Scene.sync_energy_handler_shield_drain_from_enemy_state]",
			" shield=", shield_name,
			" id=", shield_id,
			" power=", enemy_state.shield_power_level,
			" drain_per_second=", drain_value
		)


func refresh_energy_status_values() -> void:
	# Summary: Paint the Battle V2 player energy holder from EnergyHandler without owning energy math.
	if energy_handler_v2 == null:
		set_lookup_label_text("player_energy", "Energy: not linked")
		update_player_energy_bar_segments(0.0, 0.0, 0.0)
		return

	set_lookup_label_text("player_energy", get_player_energy_status_text())

	update_player_energy_bar_segments(
		energy_handler_v2.get_available_ratio(),
		energy_handler_v2.get_queued_ratio(),
		energy_handler_v2.get_spent_ratio()
	)


func update_player_energy_bar_segments(available_ratio: float, queued_ratio: float, spent_ratio: float) -> void:
	# Summary: Size the green, blue, and red energy bar slices from EnergyHandler ratios.
	if player_energy_bar_root == null:
		return
	if player_energy_bar_available == null or player_energy_bar_queued == null or player_energy_bar_spent == null:
		return

	var bar_width: float = player_energy_bar_root.size.x
	var bar_height: float = player_energy_bar_root.size.y
	if bar_width <= 0.0:
		bar_width = player_energy_bar_root.custom_minimum_size.x
	if bar_height <= 0.0:
		bar_height = player_energy_bar_root.custom_minimum_size.y
	if bar_width <= 0.0:
		bar_width = 272.0
	if bar_height <= 0.0:
		bar_height = 7.0

	var queued_width: float = clamp(queued_ratio, 0.0, 1.0) * bar_width
	var available_width: float = clamp(available_ratio, 0.0, 1.0) * bar_width
	var spent_width: float = clamp(spent_ratio, 0.0, 1.0) * bar_width
	var current_width: float = clamp(bar_width - spent_width, 0.0, bar_width)
	var usable_width: float = clamp(queued_width + available_width, 0.0, bar_width)
	if current_width < usable_width:
		current_width = usable_width
	available_width = min(available_width, max(bar_width - queued_width, 0.0))

	player_energy_bar_root.size = Vector2(bar_width, bar_height)

	# Red is the missing/spent baseline. Green fills available current energy after
	# the reserved slice. Blue is drawn last from the left edge as the top layer.
	player_energy_bar_spent.position = Vector2(current_width, 0.0)
	player_energy_bar_spent.size = Vector2(max(bar_width - current_width, 0.0), bar_height)
	player_energy_bar_available.position = Vector2(queued_width, 0.0)
	player_energy_bar_available.size = Vector2(max(min(available_width, current_width - queued_width), 0.0), bar_height)
	player_energy_bar_queued.position = Vector2(0.0, 0.0)
	player_energy_bar_queued.size = Vector2(queued_width, bar_height)
	player_energy_bar_available.visible = player_energy_bar_available.size.x > 0.0
	player_energy_bar_queued.visible = player_energy_bar_queued.size.x > 0.0
	player_energy_bar_spent.visible = player_energy_bar_spent.size.x > 0.0
	player_energy_bar_spent.queue_redraw()
	player_energy_bar_available.queue_redraw()
	player_energy_bar_queued.queue_redraw()
	player_energy_bar_root.move_child(player_energy_bar_queued, player_energy_bar_root.get_child_count() - 1)


func refresh_enemy_energy_status_values() -> void:
	# Summary: Paint the Battle V2 enemy energy holder from the enemy EnergyHandler.
	if enemy_energy_handler_v2 == null:
		set_lookup_label_text("enemy_energy", "Energy: not linked")
		update_enemy_energy_bar_segments(0.0, 0.0, 0.0)
		return

	sync_active_enemy_energy_from_handler()
	set_lookup_label_text("enemy_energy", get_enemy_energy_status_text())

	update_enemy_energy_bar_segments(
		enemy_energy_handler_v2.get_available_ratio(),
		enemy_energy_handler_v2.get_queued_ratio(),
		enemy_energy_handler_v2.get_spent_ratio()
	)


func update_enemy_energy_bar_segments(available_ratio: float, queued_ratio: float, spent_ratio: float) -> void:
	# Summary: Size the enemy green, blue, and red energy bar slices from its EnergyHandler ratios.
	if enemy_energy_bar_root == null:
		return
	if enemy_energy_bar_available == null or enemy_energy_bar_queued == null or enemy_energy_bar_spent == null:
		return

	var bar_width: float = enemy_energy_bar_root.size.x
	var bar_height: float = enemy_energy_bar_root.size.y
	if bar_width <= 0.0:
		bar_width = enemy_energy_bar_root.custom_minimum_size.x
	if bar_height <= 0.0:
		bar_height = enemy_energy_bar_root.custom_minimum_size.y
	if bar_width <= 0.0:
		bar_width = 272.0
	if bar_height <= 0.0:
		bar_height = 7.0

	var queued_width: float = clamp(queued_ratio, 0.0, 1.0) * bar_width
	var available_width: float = clamp(available_ratio, 0.0, 1.0) * bar_width
	var spent_width: float = clamp(spent_ratio, 0.0, 1.0) * bar_width
	var current_width: float = clamp(bar_width - spent_width, 0.0, bar_width)
	var usable_width: float = clamp(queued_width + available_width, 0.0, bar_width)
	if current_width < usable_width:
		current_width = usable_width
	available_width = min(available_width, max(bar_width - queued_width, 0.0))

	enemy_energy_bar_root.size = Vector2(bar_width, bar_height)
	enemy_energy_bar_spent.position = Vector2(current_width, 0.0)
	enemy_energy_bar_spent.size = Vector2(max(bar_width - current_width, 0.0), bar_height)
	enemy_energy_bar_available.position = Vector2(queued_width, 0.0)
	enemy_energy_bar_available.size = Vector2(max(min(available_width, current_width - queued_width), 0.0), bar_height)
	enemy_energy_bar_queued.position = Vector2(0.0, 0.0)
	enemy_energy_bar_queued.size = Vector2(queued_width, bar_height)
	enemy_energy_bar_available.visible = enemy_energy_bar_available.size.x > 0.0
	enemy_energy_bar_queued.visible = enemy_energy_bar_queued.size.x > 0.0
	enemy_energy_bar_spent.visible = enemy_energy_bar_spent.size.x > 0.0
	enemy_energy_bar_spent.queue_redraw()
	enemy_energy_bar_available.queue_redraw()
	enemy_energy_bar_queued.queue_redraw()
	enemy_energy_bar_root.move_child(enemy_energy_bar_queued, enemy_energy_bar_root.get_child_count() - 1)


func get_lock_status_text(good_lock: bool, lock_disabled: bool, lock_pending: bool = false) -> String:
	# Summary: Convert battle-state lock booleans into compact UI text.
	if lock_disabled:
		return "disabled"
	if good_lock:
		return "good"
	if lock_pending:
		return "reacquiring"
	return "not locked"


func get_player_shield_status_text() -> String:
	# Summary: Build player shield label text from the temporary Battle V2 player adapter.
	if player_state_packet == null:
		return "Shield: -- / --"

	if player_state_packet.shield_switching:
		return "Shield: switching"

	if typeof(player_state_packet.selected_shield) != TYPE_DICTIONARY:
		return "Shield: 0 / 0"

	var shield_data: Dictionary = player_state_packet.selected_shield as Dictionary
	var shield_name: String = str(shield_data.get("display_name", shield_data.get("name", "Shield")))
	var shield_max: float = float(shield_data.get("shield_hp_max", player_state_packet.shield_hp_current))
	return "Shield: " + shield_name + " " + str(int(player_state_packet.shield_hp_current)) + " / " + str(int(shield_max))


func get_enemy_shield_status_text(enemy_ref) -> String:
	# Summary: Build enemy shield label text from the temporary Battle V2 enemy adapter.
	if not (enemy_ref is BattleV2UnitAdapter):
		return "Shield: -- / --"

	var enemy_state: BattleV2UnitAdapter = enemy_ref as BattleV2UnitAdapter
	if enemy_state.shield_switching:
		return "Shield: switching"
	if typeof(enemy_state.selected_shield) != TYPE_DICTIONARY:
		return "Shield: 0 / 0"

	var shield_data: Dictionary = enemy_state.selected_shield as Dictionary
	var shield_name: String = str(shield_data.get("display_name", shield_data.get("name", "Shield")))
	var shield_max: float = float(shield_data.get("shield_hp_max", enemy_state.shield_hp_current))
	return "Shield: " + shield_name + " " + str(int(enemy_state.shield_hp_current)) + " / " + str(int(shield_max))


func get_player_shield_energy_status_text() -> String:
	# Summary: Display live shield energy support values from EnergyHandler for testing.
	if energy_handler_v2 == null:
		return "Shield E: not linked"

	var regen_value: float = 0.0
	if energy_handler_v2.regen_enabled:
		regen_value = energy_handler_v2.regen_per_second * energy_handler_v2.regen_multiplier

	var base_drain: float = 0.0
	if energy_handler_v2.shield_drain_active or energy_handler_v2.shield_drain_enabled:
		base_drain = energy_handler_v2.shield_drain_per_second

	var slider_percent: float = energy_handler_v2.get_shield_slider_percent()
	var live_drain: float = base_drain * slider_percent
	return (
		"Shield E: R "
		+ format_battle_value(regen_value)
		+ "/s D "
		+ format_battle_value(live_drain)
		+ "/s ("
		+ format_battle_value(base_drain)
		+ " @"
		+ str(int(round(slider_percent * 100.0)))
		+ "%)"
	)


func get_enemy_shield_energy_status_text(enemy_ref) -> String:
	# Summary: Mirror player shield energy debug text for the future enemy energy handler.
	var regen_value: float = 0.0
	var base_drain: float = 0.0
	var slider_percent: float = 0.0

	if enemy_energy_handler_v2 != null:
		if enemy_energy_handler_v2.regen_enabled:
			regen_value = enemy_energy_handler_v2.regen_per_second * enemy_energy_handler_v2.regen_multiplier
		if enemy_energy_handler_v2.shield_drain_active or enemy_energy_handler_v2.shield_drain_enabled:
			base_drain = enemy_energy_handler_v2.shield_drain_per_second
		slider_percent = enemy_energy_handler_v2.get_shield_slider_percent()
	elif enemy_ref is BattleV2UnitAdapter:
		var enemy_state: BattleV2UnitAdapter = enemy_ref as BattleV2UnitAdapter
		var values: Dictionary = enemy_state.behavior_values
		regen_value = float(values.get("shield_regen_per_second", values.get("energy_regen_per_second", values.get("regen_per_second", 0.0))))
		base_drain = float(values.get("shield_drain_per_second", values.get("steady_energy_drain", 0.0)))
		slider_percent = clamp(float(enemy_state.shield_power_level) * 0.25, 0.0, 1.0)

		if typeof(enemy_state.selected_shield) == TYPE_DICTIONARY:
			var shield_data: Dictionary = enemy_state.selected_shield as Dictionary
			regen_value = float(shield_data.get("regen_per_second", regen_value))
			base_drain = float(shield_data.get("steady_energy_drain", shield_data.get("shield_drain_per_second", base_drain)))

	var live_drain: float = base_drain * slider_percent
	return (
		"Shield E: R "
		+ format_battle_value(regen_value)
		+ "/s D "
		+ format_battle_value(live_drain)
		+ "/s ("
		+ format_battle_value(base_drain)
		+ " @"
		+ str(int(round(slider_percent * 100.0)))
		+ "%)"
	)


func get_selected_player_shield_name() -> String:
	# Summary: Return the selected player shield name for battle log text.
	if player_state_packet == null:
		return "none"
	if typeof(player_state_packet.selected_shield) != TYPE_DICTIONARY:
		return "none"

	var shield_data: Dictionary = player_state_packet.selected_shield as Dictionary
	return str(shield_data.get("display_name", shield_data.get("name", "Shield")))


func format_battle_value(value: float) -> String:
	# Summary: Format small battle result numbers without noisy decimals.
	var rounded_value: float = round(value)
	if abs(value - rounded_value) < 0.01:
		return str(int(rounded_value))
	return "%0.1f" % value


func format_battle_whole_value(value: float) -> String:
	return str(int(round(value)))


func on_shield_slider_changed(value: float) -> void:
	# Summary: Update shield slider display text and send the level to EnergyHandler.
	var slider_value: int = int(value)
	var percent: int = slider_value * 25
	set_lookup_label_text("shield_power_value", "Power: " + str(slider_value) + " / 4")
	set_lookup_label_text("shield_power_meaning", str(percent) + "% output")
	set_lookup_label_text("action_shield_power_value", str(percent) + "%")

	if legacy_shield_slider != null and is_instance_valid(legacy_shield_slider) and legacy_shield_slider.value != slider_value:
		legacy_shield_slider.set_value_no_signal(slider_value)
	if action_shield_slider != null and is_instance_valid(action_shield_slider) and action_shield_slider.value != slider_value:
		action_shield_slider.set_value_no_signal(slider_value)

	if player_state_packet != null:
		player_state_packet.shield_power_level = slider_value

	if energy_handler_v2 != null:
		energy_handler_v2.set_shield_slider_value(slider_value)
		refresh_energy_status_values()

	report_battle_v2_header_state_to_ui_handler()


func return_to_main_scene() -> void:
	# Summary: Leave the battle-v2 scene and return to the main project scene.
	if Globals.print_priority_5:
		print("Battle V2 returning to main scene.")

	# ------------------------------------------------------
	# Reset battle globals before leaving the isolated scene.
	# ------------------------------------------------------
	Globals.battle_mode = false
	Globals.battle_pending = false
	Globals.battle_v2_context = {}
	Globals.current_enemy = null

	# ------------------------------------------------------
	# Switch back to the existing main scene.
	# ------------------------------------------------------
	get_tree().change_scene_to_file("res://Scenes/main_mode.tscn")


func return_to_start_menu_after_game_over() -> void:
	# Summary: Player defeat is terminal for the active autosave lane. Named saves stay untouched.
	var save_manager = SaveManagerScript.new()
	var delete_result: Dictionary = save_manager.delete_active_autosave()
	if log_label != null:
		log_label.text += (
			"\nGame over cleanup: autosave deleted="
			+ str(bool(delete_result.get("deleted", false)))
			+ " path="
			+ str(delete_result.get("path", ""))
			+ "\n"
		)

	Globals.clear_battle_v2_transition_state(false)
	Globals.battle_mode = false
	Globals.battle_pending = false
	Globals.swap_battle_v2 = false
	Globals.current_enemy = null
	Globals.startup_mode = "load"

	get_tree().change_scene_to_file("res://Scenes/Start_Screen.tscn")


func bind_world_enemy(enemy_ref: Variant, enemy_id: String = "") -> void:
	# Summary: Stores the original world enemy reference so Battle V2 can clean up the correct enemy after victory.
	source_world_enemy = enemy_ref
	source_enemy_id = enemy_id


func get_source_world_enemy() -> Variant:
	# Summary: Returns the original world enemy reference used for post-battle cleanup.
	return source_world_enemy




func get_source_enemy_id(source_enemy) -> String:
	# Summary: Build a best-effort enemy source id for adapter binding and later world cleanup.
	if source_enemy == null:
		return ""

	if source_enemy is Dictionary:
		if source_enemy.has("shared_meta") and typeof(source_enemy.get("shared_meta", {})) == TYPE_DICTIONARY:
			var shared_meta: Dictionary = source_enemy.get("shared_meta", {})
			if str(shared_meta.get("object_id", "")).strip_edges() != "":
				return str(shared_meta.get("object_id", ""))
		return str(source_enemy.get("object_id", source_enemy.get("enemy_id", source_enemy.get("id", source_enemy.get("name", source_enemy.get("enemy_name", ""))))))

	if source_enemy is Object:
		var object_id_value = source_enemy.get("object_id")
		if object_id_value != null and str(object_id_value).strip_edges() != "":
			return str(object_id_value)

		var enemy_id_value = source_enemy.get("enemy_id")
		if enemy_id_value != null:
			return str(enemy_id_value)

		var enemy_name_value = source_enemy.get("enemy_name")
		if enemy_name_value != null:
			return str(enemy_name_value)

	return ""
	
	
	
	
func build_enemy_cleanup_signature(source_enemy) -> Dictionary:
	# Summary: Builds a battle-safe defeated enemy signature for main-mode removal after scene return.
	var signature := {
		"name": "",
		"type": "",
		"enemy_serial": "",
		"sector": [],
		"local": [],
		"shared_meta": {}
	}

	if source_enemy == null:
		return signature

	if source_enemy is Dictionary:
		signature["name"] = str(source_enemy.get("name", source_enemy.get("enemy_name", "")))
		signature["type"] = str(source_enemy.get("type", source_enemy.get("enemy_type", "")))
		signature["enemy_serial"] = str(source_enemy.get("enemy_serial", source_enemy.get("serial_number", "")))
		signature["sector"] = source_enemy.get("sector", source_enemy.get("sector_pos", []))
		signature["local"] = source_enemy.get("local", source_enemy.get("local_pos", []))
		signature["shared_meta"] = SharedObjectMeta.to_save_data(get_handoff_enemy_shared_meta(source_enemy, signature["name"]))
		return signature

	if source_enemy is Object:
		var name_value = source_enemy.get("enemy_name")
		if name_value == null:
			name_value = source_enemy.get("name")
		signature["name"] = str(name_value)

		var type_value = source_enemy.get("enemy_type")
		if type_value == null:
			type_value = source_enemy.get("type")
		signature["type"] = str(type_value)

		var serial_value = source_enemy.get("enemy_serial")
		if serial_value == null:
			serial_value = source_enemy.get("serial_number")
		signature["enemy_serial"] = str(serial_value)

		var sector_value = source_enemy.get("sector_pos")
		if sector_value != null:
			signature["sector"] = vector3_to_array_safe(sector_value)

		var local_value = source_enemy.get("local_pos")
		if local_value != null:
			signature["local"] = vector3_to_array_safe(local_value)

		signature["shared_meta"] = SharedObjectMeta.to_save_data(get_handoff_enemy_shared_meta(source_enemy, signature["name"]))

	return signature


func vector3_to_array_safe(value) -> Array:
	# Summary: Converts Vector3/Vector3i or array-like values into a simple array for cleanup matching.
	if value is Vector3 or value is Vector3i:
		return [value.x, value.y, value.z]

	if value is Array:
		return value

	return []
	
	
func get_battle_resolution_summary(handoff_result: Dictionary) -> Dictionary:
	# Summary: Normalizes old and new BattleManager handoff result shapes into one summary dictionary.
	var summary = handoff_result.get("resolution_summary", handoff_result)

	if typeof(summary) == TYPE_DICTIONARY:
		return summary

	return {}


func request_battle_ai_snapshot_commentary(reason: String = "battle_snapshot") -> void:
	if battle_ai_initial_commentary_sent:
		debug_battle_ai_commentary("snapshot commentary skipped: already sent reason=" + reason)
		return

	var context := build_battle_ai_commentary_context("battle_snapshot", {
		"snapshot_type": "battle_start",
		"message": "Battle V2 combat link is active."
	}, reason)
	if request_battle_ai_commentary("battle_snapshot", context, reason, 14.0):
		battle_ai_initial_commentary_sent = true
		debug_battle_ai_commentary("snapshot commentary accepted reason=" + reason)


func request_battle_ai_enemy_intent_commentary(queue_result: Dictionary, reason: String = "enemy_intent") -> void:
	if queue_result.is_empty():
		return
	if str(queue_result.get("status", "")).strip_edges().to_lower() != "queued":
		return

	var context := build_battle_ai_commentary_context("enemy_intent", {
		"enemy_intent": queue_result.duplicate(true)
	}, reason)
	context["enemy_intent"] = queue_result.duplicate(true)
	request_battle_ai_commentary("enemy_intent", context, reason, 12.0)


func request_battle_ai_resolution_commentary(completed_batch: Array, handoff_result: Dictionary, resolution_summary: Dictionary, reason: String = "battle_resolution") -> void:
	if completed_batch.is_empty():
		return

	var completed_summaries := build_battle_ai_completed_event_summaries(completed_batch, resolution_summary, 3)
	if completed_summaries.is_empty():
		return

	var resolved_events: Array = []
	if typeof(resolution_summary.get("resolved_events", [])) == TYPE_ARRAY:
		resolved_events = resolution_summary.get("resolved_events", [])

	var resolution_packet := {
		"battle_outcome": str(resolution_summary.get("battle_outcome", "battle_continues")),
		"battle_ended": bool(resolution_summary.get("battle_ended", false)),
		"cleanup_required": bool(resolution_summary.get("cleanup_required", false)),
		"cleanup_outcome": str(resolution_summary.get("cleanup_outcome", "")),
		"resolved_count": resolved_events.size(),
		"invalid_count": resolution_summary.get("invalid_events", []).size() if typeof(resolution_summary.get("invalid_events", [])) == TYPE_ARRAY else 0,
		"completed_events": completed_summaries,
		"handoff": {
			"delivered": bool(handoff_result.get("delivered", false)),
			"acknowledged": bool(handoff_result.get("acknowledged", false)),
			"blocked_reason": str(handoff_result.get("blocked_reason", ""))
		}
	}
	var context := build_battle_ai_commentary_context("battle_resolution", {
		"resolution": resolution_packet
	}, reason)
	context["resolution"] = resolution_packet
	request_battle_ai_commentary("battle_resolution", context, reason, 9.0)


func request_battle_ai_commentary(commentary_kind: String, context: Dictionary, reason: String, min_interval_seconds: float) -> bool:
	var clean_kind := commentary_kind.strip_edges().to_lower()
	if battle_main_ai == null or not is_instance_valid(battle_main_ai):
		debug_battle_ai_commentary("commentary skipped kind=" + clean_kind + " reason=" + reason + " cause=main_ai_missing")
		return false
	if battle_main_ai.get_parent() == null:
		debug_battle_ai_commentary("commentary skipped kind=" + clean_kind + " reason=" + reason + " cause=main_ai_not_in_tree")
		return false
	if not battle_main_ai.has_method("request_commentary"):
		debug_battle_ai_commentary("commentary skipped kind=" + clean_kind + " reason=" + reason + " cause=request_commentary_missing")
		return false
	if not bool(battle_main_ai.get("server_ready")):
		debug_battle_ai_commentary("commentary skipped kind=" + clean_kind + " reason=" + reason + " cause=server_not_ready")
		return false

	var now_msec := Time.get_ticks_msec()
	var last_msec := int(battle_ai_commentary_last_msec_by_kind.get(clean_kind, -1000000))
	if now_msec - last_msec < int(max(min_interval_seconds, 0.0) * 1000.0):
		debug_battle_ai_commentary(
			"commentary skipped kind=" + clean_kind
			+ " reason=" + reason
			+ " cause=cooldown elapsed_msec=" + str(now_msec - last_msec)
		)
		return false

	var safe_context = sanitize_battle_ai_value(context, 4, 10)
	if typeof(safe_context) != TYPE_DICTIONARY:
		debug_battle_ai_commentary("commentary skipped kind=" + clean_kind + " reason=" + reason + " cause=sanitize_failed")
		return false

	var accepted := bool(battle_main_ai.request_commentary(clean_kind, safe_context, reason))
	if accepted:
		battle_ai_commentary_last_msec_by_kind[clean_kind] = now_msec
	debug_battle_ai_commentary(
		"commentary request kind=" + clean_kind
		+ " reason=" + reason
		+ " accepted=" + str(accepted)
		+ " context_keys=" + str(safe_context.keys())
	)
	return accepted


func build_battle_ai_commentary_context(commentary_source: String, payload: Dictionary, reason: String) -> Dictionary:
	var context := {
		"scene": "battle_v2",
		"commentary_source": commentary_source,
		"reason": reason,
		"battle_id": battle_id,
		"battle_state": "ended" if battle_v2_ended else "active",
		"battle_outcome": battle_v2_outcome if battle_v2_outcome != "" else "battle_continues",
		"player": build_battle_ai_unit_summary(player_state_packet, "player"),
		"enemy": build_battle_ai_unit_summary(active_enemy, "enemy"),
		"active_events": build_battle_ai_active_event_summaries(4)
	}
	for key in payload.keys():
		context[str(key)] = payload[key]
	return context


func build_battle_ai_unit_summary(unit_ref, side: String) -> Dictionary:
	var clean_side := side.strip_edges().to_lower()
	var hull_current_key := "player_hull_current" if clean_side == "player" else "enemy_hull_current"
	var hull_max_key := "player_hull_max" if clean_side == "player" else "enemy_hull_max"
	var lock_good_key := "player_good_lock" if clean_side == "player" else "enemy_good_lock"
	var lock_pending_key := "player_lock_pending" if clean_side == "player" else "enemy_lock_pending"
	var lock_disabled_key := "player_lock_disabled" if clean_side == "player" else "enemy_lock_disabled"
	var energy_current_key := "player_energy_current" if clean_side == "player" else "enemy_energy_current"
	var energy_max_key := "player_energy_max" if clean_side == "player" else "enemy_energy_max"
	var hull_current := float(read_battle_ai_value(unit_ref, hull_current_key, 0.0))
	var hull_max = max(float(read_battle_ai_value(unit_ref, hull_max_key, hull_current)), 0.0)
	var energy_current := float(read_battle_ai_value(unit_ref, energy_current_key, 0.0))
	var energy_max = max(float(read_battle_ai_value(unit_ref, energy_max_key, energy_current)), 0.0)
	var shield_current := float(read_battle_ai_value(unit_ref, "shield_hp_current", 0.0))
	var shield_max = max(float(read_battle_ai_value(unit_ref, "shield_hp_max", shield_current)), 0.0)

	return {
		"side": clean_side,
		"name": get_battle_ai_unit_name(unit_ref, clean_side),
		"hull_current": hull_current,
		"hull_max": hull_max,
		"hull_ratio": hull_current / hull_max if hull_max > 0.0 else 0.0,
		"energy_current": energy_current,
		"energy_max": energy_max,
		"energy_ratio": energy_current / energy_max if energy_max > 0.0 else 0.0,
		"shield_current": shield_current,
		"shield_max": shield_max,
		"shield_ratio": shield_current / shield_max if shield_max > 0.0 else 0.0,
		"lock_good": bool(read_battle_ai_value(unit_ref, lock_good_key, false)),
		"lock_pending": bool(read_battle_ai_value(unit_ref, lock_pending_key, false)),
		"lock_disabled": bool(read_battle_ai_value(unit_ref, lock_disabled_key, false)),
		"primary": str(read_battle_ai_value(unit_ref, "selected_primary_weapon", "")),
		"secondary": str(read_battle_ai_value(unit_ref, "selected_secondary_weapon", "")),
		"shield": str(read_battle_ai_value(unit_ref, "selected_enemy_shield", read_battle_ai_value(unit_ref, "selected_shield", ""))),
		"loaded_consumable_state": str(read_battle_ai_value(unit_ref, "loaded_consumable_state", "")),
		"can_evade": bool(read_battle_ai_value(unit_ref, "can_evade", false))
	}


func get_battle_ai_unit_name(unit_ref, side: String) -> String:
	var fallback := "Player Ship" if side == "player" else "Enemy Contact"
	var name := str(read_battle_ai_value(unit_ref, "display_name", fallback)).strip_edges()
	if side == "enemy" and (name == "" or name == "Unknown Unit" or name == fallback):
		name = get_handoff_enemy_name(handoff_enemy)
	if name == "":
		name = fallback
	return name


func build_battle_ai_active_event_summaries(limit: int) -> Array:
	var result: Array = []
	var active_events := get_sorted_active_todo_events()
	var max_entries = min(active_events.size(), max(limit, 0))
	for i in range(max_entries):
		var event_packet = active_events[i]
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		result.append(build_battle_ai_event_summary(event_packet))
	return result


func build_battle_ai_completed_event_summaries(completed_batch: Array, resolution_summary: Dictionary, limit: int) -> Array:
	var result: Array = []
	var resolved_events: Array = []
	if typeof(resolution_summary.get("resolved_events", [])) == TYPE_ARRAY:
		resolved_events = resolution_summary.get("resolved_events", [])

	var max_entries = min(completed_batch.size(), max(limit, 0))
	for i in range(max_entries):
		var event_packet = completed_batch[i]
		if typeof(event_packet) != TYPE_DICTIONARY:
			continue
		var event_id := str(event_packet.get("event_id", ""))
		var summary := build_battle_ai_event_summary(event_packet)
		var resolution_result := find_battle_v2_resolution_result_for_event(resolved_events, event_id)
		if not resolution_result.is_empty():
			summary["resolution_result"] = sanitize_battle_ai_value(resolution_result, 2, 8)
		result.append(summary)
	return result


func build_battle_ai_event_summary(event_packet: Dictionary) -> Dictionary:
	var ui_summary := build_battle_v2_todo_ui_event_summary(event_packet)
	var data_payload = event_packet.get("data", {})
	var item_name := str(event_packet.get("item_id", ""))
	if typeof(data_payload) == TYPE_DICTIONARY:
		item_name = str(data_payload.get("display_name", data_payload.get("item_id", item_name)))

	return {
		"event_id": str(event_packet.get("event_id", "")),
		"event_type": str(event_packet.get("event_type", "")),
		"event_side": str(event_packet.get("event_side", "")),
		"display_text": str(ui_summary.get("display_text", get_todo_event_display_text(event_packet))),
		"item": item_name,
		"damage_value": float(event_packet.get("damage_value", 0.0)),
		"damage_type": str(event_packet.get("damage_type", "")),
		"time_remaining": float(event_packet.get("time_remaining", 0.0)),
		"duration": float(event_packet.get("duration", 0.0)),
		"labels": build_battle_v2_string_list([event_packet.get("labels", [])])
	}


func read_battle_ai_value(source, key: String, fallback = null):
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


func sanitize_battle_ai_value(value, depth: int = 3, max_entries: int = 8):
	if value == null:
		return null
	if value is Vector2 or value is Vector2i or value is Vector3 or value is Vector3i:
		return str(value)
	if value is Object:
		return {
			"object_class": value.get_class(),
			"name": str(read_battle_ai_value(value, "display_name", read_battle_ai_value(value, "name", "")))
		}
	if depth <= 0:
		return str(value)

	var value_type := typeof(value)
	if value_type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
		return value

	if value_type == TYPE_ARRAY:
		var source_array: Array = value
		var output_array: Array = []
		var count = min(source_array.size(), max(max_entries, 0))
		for i in range(count):
			output_array.append(sanitize_battle_ai_value(source_array[i], depth - 1, max_entries))
		return output_array

	if value_type == TYPE_DICTIONARY:
		var source_dict: Dictionary = value
		var output_dict := {}
		var blocked_keys := [
			"battle_manager",
			"event_manager",
			"source_unit",
			"owner_unit",
			"target_unit",
			"enemy",
			"player_state",
			"defeated_enemy",
			"inventory_save_data",
			"item_db_snapshot"
		]
		var copied := 0
		for key in source_dict.keys():
			if copied >= max_entries:
				break
			var clean_key := str(key)
			if blocked_keys.has(clean_key):
				continue
			output_dict[clean_key] = sanitize_battle_ai_value(source_dict[key], depth - 1, max_entries)
			copied += 1
		return output_dict

	return str(value)


func get_battle_player_state_save_data_from_context() -> Dictionary:
	# Summary: Read PlayerState save-data snapshot from Battle V2 context.
	var data = battle_context.get("player_state_save_data", battle_context.get("player_state_data", battle_context.get("player_save_data", {})))

	if typeof(data) == TYPE_DICTIONARY:
		return data.duplicate(true)

	return {}


func get_battle_inventory_save_data_from_context() -> Dictionary:
	# Summary: Read inventory save-data snapshot from Battle V2 context.
	var data = battle_context.get("inventory_save_data", {})

	if typeof(data) == TYPE_DICTIONARY:
		return data.duplicate(true)

	return {}


func get_battle_item_db_snapshot_from_context() -> Dictionary:
	# Summary: Read item metadata snapshot from Battle V2 context.
	var data = battle_context.get("item_db_snapshot", {})

	if typeof(data) == TYPE_DICTIONARY:
		return data.duplicate(true)

	return {}


func get_battle_npc_save_data_from_context() -> Array:
	# Summary: Read NPC save-data snapshot from Battle V2 context.
	var data = battle_context.get("npc_save_data", [])

	if typeof(data) == TYPE_ARRAY:
		return data.duplicate(true)

	return []


func get_battle_beacon_save_data_from_context() -> Array:
	# Summary: Read beacon save-data snapshot from Battle V2 context.
	var data = battle_context.get("beacon_save_data", [])

	if typeof(data) == TYPE_ARRAY:
		return data.duplicate(true)

	return []


func get_battle_space_object_save_data_from_context() -> Array:
	# Summary: Read space-object save-data snapshot from Battle V2 context.
	var data = battle_context.get("space_object_save_data", [])

	if typeof(data) == TYPE_ARRAY:
		return data.duplicate(true)

	return []


func scroll_battle_log_to_bottom() -> void:
	if log_label == null:
		return

	if not is_instance_valid(log_label):
		return

	log_label.scroll_to_line(log_label.get_line_count())


func start_battle_log_trace_fx() -> void:
	# Procedural trace connections are disabled for the sandbox layout pass.
	if not battle_v2_procedural_connections_enabled:
		return
	if battle_log_trace_fx != null:
		return

	var fx := BattlePathTrail.new()
	fx.name = "BattleLogTraceFX"
	fx.path_file = "res://data/battle_ui_paths/battle_log_wobble_trace.json"
	fx.loop_path = true
	fx.autostart = true
	fx.draw_debug_path = false

	add_child(fx)
	battle_log_trace_fx = fx
