extends Node2D


# ==========================================================
# 🧠 MAIN MODE — CENTRAL ORCHESTRATOR
# ----------------------------------------------------------
# This script is the *heart* of the game loop.
# It wires together:
# - GUI systems
# - Navigation & Autopilot
# - Star systems / Universe
# - Inventory & Actions
# - Background visuals
#
# Design Philosophy:
# - Build everything in stages
# - Keep systems modular
# - Maintain readability over cleverness
# ==========================================================



# ==========================================================
# 📦 CORE SYSTEM REFERENCES
# ----------------------------------------------------------
# These are the backbone systems used across the game.
# They are created once and shared everywhere.
# ==========================================================
@onready var gui_state : WidgetsState5
@onready var gui_builder : WidgetsBuilder5
@onready var gui_controller : WidgetsController5

@onready var eng = Impulse_Engine.new()
@onready var map = Map.new()
@onready var star_field = StarField.new()
@onready var star_ui = StarUIManager.new()
@onready var fools = Fooliery_Color.new()

const SaveManagerScript = preload("res://save/SaveManager.gd")
const EnemyHandlerScript = preload("res://Objects//enemy_handler.gd")
const NPCHandlerScript = preload("res://Objects//npc_handler.gd")
const LiveMapControlScript = preload("res://UI/LiveMap/live_map_control.gd")
const BattleV2MainBridgeScript = preload("res://battle_v2/battle_v2_main_bridge.gd")
const NPCSceneBridgeScript = preload("res://Scenes/Npc/npc_scene_bridge.gd")
const PortWindowWidgetScript = preload("res://UI/PortView/port_window_widget.gd")
const MainViewWindowScript = preload("res://UI/PortView/main_view_window.gd")
const SoundHandlerScript = preload("res://Control//sound_handler.gd")
const SettingsHandlerScript = preload("res://Build//settings_handler.gd")
const MainUIHandlerScript = preload("res://UI/MainUIHandler.gd")
const UIHandlerHelpersScript = preload("res://UI/UIHandlerHelpers.gd")
const BattleLoadoutPopupScript = preload("res://UI/BattleLoadout/BattleLoadoutPopup.gd")
const PlayerStateMainUIScript = preload("res://UI/PlayerStateMainUI.gd")
const FullFlatMapHandlerScript = preload("res://UI/FlatMap/FullFlatMapHandler.gd")
const MainCommandControllerScript = preload("res://UI/MainCommand/MainCommandController.gd")
const MainLeftPanelControllerScript = preload("res://UI/MainMode/MainLeftPanelController.gd")
const BlueprintWidgetControllerScript = preload("res://UI/Blueprints/BlueprintWidgetController.gd")
const SettingsPopupControllerScript = preload("res://UI/Settings/SettingsPopupController.gd")
const MainModeLoadScreenHandlerScript = preload("res://UI/Loading/MainModeLoadScreenHandler.gd")
const ControllerFocusManagerScript = preload("res://UI/Controller/ControllerFocusManager.gd")
const ControllerFocusOverlayScript = preload("res://UI/Controller/ControllerFocusOverlay.gd")
const LocalAIServerManagerScript = preload("res://local_ai/local_ai_server_manager.gd")
const MainAIScript = preload("res://local_ai/main_ai.gd")
const MiningGainFeedScript = preload("res://UI/MainMode/MiningGainFeed.gd")
const MAIN_COMMAND_MENU_DOC_PATH := "res://docs_v_s1.2/Main_Mode_Sub_Menu_Keycode_Map_s1.2.md"

const LIVE_MAP_REFRESH_INTERVAL := 0.35
const TIER_MAP_REFRESH_INTERVAL := 0.25
const TIER_MAP_TYPE_TABS := ["all", "star", "planet", "object", "beacon", "enemy", "npc"]
const TIER_MAP_TAB_LABELS := {
	"all": "ALL",
	"star": "STAR",
	"planet": "PLANET",
	"object": "OBJECT",
	"beacon": "BEACON",
	"enemy": "HOSTILE",
	"npc": "NPC"
}
const BLUEPRINT_INVENTORY_POLL_INTERVAL := 0.25
const STARTER_INVENTORY_MIGRATION_ID := "starter_inventory_v1"
const ORBIT_STARTER_INVENTORY_MIGRATION_ID := "orbit_starter_inventory_v1"
const ORBIT_VELA_RESOURCE_SITE_MIGRATION_ID := "orbit_vela_resource_site_v1"
const ORBIT_VELA_RESOURCE_SITE_SEED_PATH := "res://data/universes/universe_1/world_seeds/forever_space_30_planet_seed.json"
const ORBIT_VELA_PLANET_ID := "seed_planet_001_vela"
const ORBIT_CONTEXT_SCHEMA := "orbit_snapshot_context_v1"
const ORBIT_SNAPSHOT_SCHEMA := "orbit_snapshot_save_v1"
const ORBIT_SNAPSHOT_SAVE_VERSION := 3
const MAIN_MODE_PERF_WARN_MS := 24

var item_handler := ItemHandler.new()
var inventory := Inventory5.new()
var star := Star.new()
var color_handler := Color_Handler.new()
var auto_pilot : AutoPilot
var auto_scan_after_autopilot_armed := false
var save_manager = SaveManagerScript.new()
var event_handler = EventManager.new()



# --- ACTION SYSTEM ---
var action_manager := Action_Manager.new()

var enemy := Enemy
var enemy_handler = EnemyHandlerScript.new()
var npc_handler = NPCHandlerScript.new()

var battle_v2_bridge = BattleV2MainBridgeScript.new()
#var sonic_pi_music_director = SonicPiMusicDirectorScript.new()
var port_window_widget = PortWindowWidgetScript.new()
var port_window_backdrop = MainViewWindowScript.new()
var port_window_backdrop_enabled := false
var inv_radar_panel = InventoryRadarPanel.new()
var npc_scene_bridge = NPCSceneBridgeScript.new()
var widget_spec_ui = WidgetSpecUi.new()
var game_event_handler = GameEventsHandler.new()
var world_seed_builder = WorldSeedBuilder.new()
var sound_handler = SoundHandlerScript.new()
var settings_handler = SettingsHandlerScript.new()
var ui_helpers = UIHandlerHelpersScript.new()
var main_ui_handler = MainUIHandlerScript.new()
var battle_loadout_popup: BattleLoadoutPopup = null
var named_save_popup_root: Control = null
var main_command_controller = MainCommandControllerScript.new()
var blueprint_widget_controller = BlueprintWidgetControllerScript.new()
var settings_popup_controller = SettingsPopupControllerScript.new()
var player_state_main_ui = PlayerStateMainUIScript.new()
var full_flat_map_handler = FullFlatMapHandlerScript.new()
var main_command_menu_root: Panel = null
var main_command_menu_button: Button = null
var main_command_menu_action_by_id := {}
var main_left_panel_controller = MainLeftPanelControllerScript.new()
var main_mode_event_widget_poke_pending := false
var main_mode_event_widget_poke_done := false
var main_mode_event_widget_poke_wait_frames := 0
var main_command_left_root: Control = null
var inventory_craft_left_root: Control = null
var loadout_left_root: Control = null
var story_popup_log_left_root: Control = null
var story_popup_log_scroll: ScrollContainer = null
var story_popup_log_text: RichTextLabel = null
var story_popup_log_count_label: Label = null
var story_popup_log_last_revision := -1
var popup_input_lock_last := false
var tier_map_active_tab := "all"
var tier_map_refresh_timer := 0.0
var tier_map_last_signature := ""
var tier_map_last_packet: Dictionary = {}
var coord_auto_preloaded_target: Dictionary = {}
var main_mode_load_screen_handler = MainModeLoadScreenHandlerScript.new()
var controller_focus_manager = ControllerFocusManagerScript.new()
var controller_focus_overlay = ControllerFocusOverlayScript.new()
var local_ai_server_manager = LocalAIServerManagerScript.new()
var main_ai = MainAIScript.new()
var mining_gain_feed = MiningGainFeedScript.new()
var main_mode_boot_started := false
var main_mode_boot_complete := false
var main_mode_last_loading_stage := ""
var debug_saving_cover_visible := false
var quick_save_in_progress := false
var scene_switch_save_in_progress := false
# ==================================================
# ⚡ ENERGY HANDLER
# --------------------------------------------------
# Owns all energy math:
# BLUE  = queued / reserved energy
# GREEN = available energy
# RED   = spent / missing energy
# ==================================================
var energy_handler : EnergyHandler

# --- WORLD OBJECT SYSTEMS ---
var space_objects: Space_Objects = null
var beacons: Beacons
var planets: Planets
var player_state =  PlayerState.new()



# ==========================================================
# DECORATIVE UI
# ----------------------------------------------------------
# Visual-only screen effects.
# ==========================================================
var decorative_ui := DecorativeUI.new()



# --- BACKGROUND SYSTEM ---
var aurora_bg : AuroraBrainBackground
var aurora_holder = preload("res://images/blue_scifi_backing.png")
var scifi_background_root: Control = null
var navigation_widgets_hidden := false

var miniverse_sectors: Array = [
	Vector3(0, 0, 0),
	Vector3(10, 0, 0),
	Vector3(20, 0, 0),
	Vector3(30, 0, 0)
]


func _ready() -> void:
	main_mode_boot_started = true
	main_mode_boot_complete = false
	clear_transient_main_mode_popup_locks("main_mode_ready_start", null)
	setup_main_mode_load_screen_handler()
	await get_tree().process_frame
	await boot_main_mode_with_loading_screen()
	settings_handler.master_sound_value = 5.0


func clear_transient_main_mode_popup_locks(reason: String = "main_mode_boot", state: WidgetsState5 = null) -> void:
	# Main mode is a fresh scene entry; stale tutorial/story popup locks from an
	# abandoned previous scene must not keep actions, inventory, or maps disabled.
	if Globals.has_method("reset_popup_runtime"):
		Globals.reset_popup_runtime(state, true)

	if typeof(Globals.popup_input_lock_sources) == TYPE_DICTIONARY:
		Globals.popup_input_lock_sources.clear()
	Globals.tutorial_story_popup_active = false
	popup_input_lock_last = false

	if Globals.print_priority_2:
		print("Main mode cleared transient popup locks: ", reason)


func setup_main_mode_load_screen_handler() -> void:
	# Summary: Adds a simple full-screen boot overlay before the heavy main-mode startup chain.
	# This intentionally lives outside the normal widget system so it can appear before GUI build finishes.
	if main_mode_load_screen_handler == null:
		main_mode_load_screen_handler = MainModeLoadScreenHandlerScript.new()

	main_mode_load_screen_handler.name = "MainModeLoadScreenHandler"

	if main_mode_load_screen_handler.get_parent() == null:
		add_child(main_mode_load_screen_handler)

	main_mode_load_screen_handler.begin("Forever Space", "Opening main mode...")


func boot_main_mode_with_loading_screen() -> void:
	await main_mode_loading_stage(2, "Reading battle return flags...")
	print(
	"[S1.2_MAIN_READY_ENTER]",
	" battle_mode=", Globals.battle_mode,
	" battle_pending=", Globals.battle_pending,
	" swap_battle_v2=", Globals.swap_battle_v2,
	" has_battle_v2_result=", typeof(Globals.battle_v2_result) == TYPE_DICTIONARY and not Globals.battle_v2_result.is_empty(),
	" has_last_battle_v2_result=", typeof(Globals.last_battle_v2_result) == TYPE_DICTIONARY and not Globals.last_battle_v2_result.is_empty()
)
	var is_battle_return := false

	if typeof(Globals.battle_v2_result) == TYPE_DICTIONARY and not Globals.battle_v2_result.is_empty():
		is_battle_return = true

	if typeof(Globals.last_battle_v2_result) == TYPE_DICTIONARY and not Globals.last_battle_v2_result.is_empty():
		is_battle_return = true

	Globals.battle_mode = false
	Globals.swap_battle_v2 = false
	Globals.battle_pending = is_battle_return
	Globals.clear_orbit_transition_state(true)

	await main_mode_loading_stage(5, "Adding persistent player UI nodes...")
	add_child(player_state)
	add_child(player_state_main_ui)
	add_child(full_flat_map_handler)

	await main_mode_loading_stage(9, "Setting up settings and background...")
	setup_settings_handler()
	build_background()
	apply_main_cockpit_v2_boot_layout()

	await main_mode_loading_stage(12, "Starting local AI server...")
	setup_local_ai_server_manager("main_mode_boot")

	await main_mode_loading_stage(16, "Building core GUI systems...")
	build_gui_system()
	setup_player_state_main_ui("after_gui_build")
	build_static_systems()

	await main_mode_loading_stage(23, "Building inventory, navigation, and star systems...")
	build_inventory_system()
	build_navigation_system()
	build_star_system()

	await main_mode_loading_stage(35, "Loading or creating universe...")
	load_or_create_universe()

	await main_mode_loading_stage(42, "Checking AMI, item database, and starter inventory...")
	refresh_ami_report("after_load_or_create_universe")
	debug_export_item_boot_check("after_load_or_create_universe")
	validate_starter_inventory_for_demo_save()
	grant_orbit_starter_items_once()
	apply_authored_orbit_resource_site_migration_once()
	debug_export_item_boot_check("after_validate_starter_inventory")

	await main_mode_loading_stage(50, "Building action system...")
	build_action_system()

	await main_mode_loading_stage(60, "Finalizing startup references...")
	finalize_startup()

	await main_mode_loading_stage(67, "Refreshing actions, TODOs, blueprints, and startup popups...")
	debug_startup_prints()
	action_manager.refresh_actions_from_inventory()
	setup_todo()
	connect_blueprint_widget_refs()
	refresh_blueprint_widget()
	add_start_up_debug_events()
	gui_builder.build_info_popup(gui_state)
	clear_transient_main_mode_popup_locks("after_info_popup_build", gui_state)

	await main_mode_loading_stage(73, "Building live map and movement handlers...")
	build_live_map_widget()
	set_up_new_moves_and_handlers()

	await main_mode_loading_stage(80, "Connecting event and battle bridges...")
	setup_event_handler()
	process_pending_orbit_event_discoveries()
	setup_battle_v2_bridge()

	await main_mode_loading_stage(86, "Applying pending Battle V2 result if needed...")
	if battle_v2_bridge != null:
		print("[S1.2_MAIN_APPLY_BATTLE_AFTER_EVENT_SETUP]")
		battle_v2_bridge.apply_battle_v2_result_if_needed()
		refresh_ami_report("after_battle_v2_result_apply")

	await main_mode_loading_stage(89, "Processing pending event battle result...")
	if game_event_handler != null:
		print("[S1.2_MAIN_PROCESS_BATTLE_EVENT_RESULT_AFTER_APPLY]")
		game_event_handler.process_pending_battle_v2_result()
		refresh_ami_report("after_battle_event_result_process")

	await main_mode_loading_stage(91, "Applying pending NPC chat result if needed...")
	if npc_scene_bridge != null:
		if Globals.print_priority_2:
			print("calling apply_pending_npc_chat_result_if_needed")
		npc_scene_bridge.apply_pending_npc_chat_result_if_needed()

	await main_mode_loading_stage(93, "Clearing consumed transition state...")
	# s1.2:
	# Only now is battle return fully consumed.
	var keep_unconsumed_battle_result := typeof(Globals.last_battle_v2_result) == TYPE_DICTIONARY and not Globals.last_battle_v2_result.is_empty()
	Globals.clear_battle_v2_transition_state(keep_unconsumed_battle_result)

	await main_mode_loading_stage(95, "Wiring widget runtime, sound, and main UI...")
	widget_spec_ui.setup(
		inventory,
		inv_radar_panel,
		energy_handler,
		gui_state,
		decorative_ui,
		aurora_bg,
		color_handler
	)

	setup_sound_handler()
	setup_main_ui_handler()
	draw_main_ui()

	await main_mode_loading_stage(98, "Opening command systems and cockpit layout...")
	build_main_command_menu()
	setup_player_state_main_ui("final_main_ui_setup")
	setup_main_cockpit_v2()
	setup_controller_focus_handler()
	setup_main_ai_handler("main_mode_ready")

	await main_mode_loading_stage(100, "Main mode ready.")

	# Arm the main-mode entry pulse after the loading overlay is gone. The pulse is
	# consumed by the normal _process event-check pass, after UI/world updates have
	# had a real frame to settle.
	main_mode_boot_complete = true
	main_mode_boot_started = false
	if main_mode_load_screen_handler != null and is_instance_valid(main_mode_load_screen_handler):
		main_mode_load_screen_handler.force_hide()

	queue_event_widget_poke_after_main_mode_load()


func main_mode_loading_stage(percent: int, detail_text: String) -> void:
	main_mode_last_loading_stage = detail_text
	if should_print_main_loading_debug():
		print("[MAIN_MODE_LOAD] ", percent, "% | ", detail_text)

	if main_mode_load_screen_handler != null and is_instance_valid(main_mode_load_screen_handler):
		main_mode_load_screen_handler.set_stage(percent, detail_text)

	await get_tree().process_frame


func should_print_main_loading_debug() -> bool:
	# Uses Object.get() instead of a direct Globals.print_priority_loading_debug reference.
	# That keeps this patch safe if the flag has not been added to Globals yet.
	var loading_debug = Globals.get("print_priority_loading_debug")
	if typeof(loading_debug) == TYPE_BOOL:
		return loading_debug
	return false


func setup_local_ai_server_manager(reason: String = "main_mode_boot") -> void:
	if local_ai_server_manager == null or not is_instance_valid(local_ai_server_manager):
		local_ai_server_manager = LocalAIServerManagerScript.new()

	local_ai_server_manager.name = "LocalAIServerManager"
	if local_ai_server_manager.get_parent() == null:
		add_child(local_ai_server_manager)

	if not local_ai_server_manager.status_changed.is_connected(_on_local_ai_server_status_changed):
		local_ai_server_manager.status_changed.connect(_on_local_ai_server_status_changed)

	print("[MAIN_LOCAL_AI_SERVER] setup requested | reason=", reason)
	local_ai_server_manager.begin_startup(reason)


func _on_local_ai_server_status_changed(packet: Dictionary) -> void:
	print("[MAIN_LOCAL_AI_SERVER] status=", packet.get("state", ""), " message=", packet.get("message", ""), " pid=", packet.get("pid", -1), " attempt=", packet.get("attempt", 0))
	if main_ai != null and is_instance_valid(main_ai) and main_ai.has_method("handle_server_status"):
		main_ai.handle_server_status(packet)


func setup_main_ai_handler(reason: String = "main_mode_ready") -> void:
	if main_ai == null or not is_instance_valid(main_ai):
		main_ai = MainAIScript.new()

	main_ai.name = "MainAI"
	if main_ai.get_parent() == null:
		add_child(main_ai)

	if main_ai.has_method("setup"):
		main_ai.setup(self, gui_state)

	if local_ai_server_manager != null and is_instance_valid(local_ai_server_manager):
		var last_status := {}
		if local_ai_server_manager.has_method("get_last_status_packet"):
			last_status = local_ai_server_manager.get_last_status_packet()

		if typeof(last_status) == TYPE_DICTIONARY and not last_status.is_empty():
			main_ai.handle_server_status(last_status)
		elif bool(local_ai_server_manager.get("server_ready")):
			main_ai.handle_server_status({
				"state": "ready",
				"message": "Local AI server already ready.",
				"pid": int(local_ai_server_manager.get("process_id")),
				"attempt": int(local_ai_server_manager.get("health_attempt"))
			})

	print("[MAIN_AI] handler setup | reason=", reason)


func show_saving_cover_before_save(reason: String = "save", _stay_visible: bool = false) -> void:
	if main_ui_handler == null or not is_instance_valid(main_ui_handler):
		return
	if not main_ui_handler.has_method("show_saving_cover"):
		return
	main_ui_handler.show_saving_cover("Saving", reason)


func hide_saving_cover_after_save(reason: String = "save_done") -> void:
	if main_ui_handler == null or not is_instance_valid(main_ui_handler):
		return
	if not main_ui_handler.has_method("hide_saving_cover_deferred"):
		return
	main_ui_handler.hide_saving_cover_deferred(reason)


func handle_debug_saving_cover_input(event) -> bool:
	if not (event is InputEventKey):
		return false

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	if key_event.keycode != KEY_F10:
		return false
	if not OS.has_feature("editor"):
		return false

	var focus_owner = get_viewport().gui_get_focus_owner()
	if focus_owner is TextEdit or focus_owner is LineEdit:
		print("[SAVE_COVER_DEBUG] F10 ignored | text_input_focus=", focus_owner.name)
		return false

	debug_toggle_saving_cover("debug_key_f10")
	get_viewport().set_input_as_handled()
	return true


func debug_toggle_saving_cover(reason: String = "debug_key_f10") -> void:
	print("[SAVE_COVER_DEBUG] toggle requested | currently_visible=", debug_saving_cover_visible, " reason=", reason)

	if main_ui_handler == null or not is_instance_valid(main_ui_handler):
		print("[SAVE_COVER_DEBUG] failed | main_ui_handler_missing=true")
		return

	if debug_saving_cover_visible:
		if main_ui_handler.has_method("hide_saving_cover"):
			main_ui_handler.hide_saving_cover(reason)
		else:
			print("[SAVE_COVER_DEBUG] failed | missing hide_saving_cover")
			return
		debug_saving_cover_visible = false
		print("[SAVE_COVER_DEBUG] hide called | state=", get_saving_cover_debug_state())
		return

	if not main_ui_handler.has_method("show_saving_cover"):
		print("[SAVE_COVER_DEBUG] failed | missing show_saving_cover")
		return

	var result = main_ui_handler.show_saving_cover("Saving", reason)
	debug_saving_cover_visible = true
	print("[SAVE_COVER_DEBUG] show called | result=", result, " state=", get_saving_cover_debug_state())


func get_saving_cover_debug_state() -> Dictionary:
	if main_ui_handler == null or not is_instance_valid(main_ui_handler):
		return {"main_ui_handler_valid": false}
	if main_ui_handler.has_method("get_saving_cover_debug_state"):
		var state = main_ui_handler.get_saving_cover_debug_state()
		if typeof(state) == TYPE_DICTIONARY:
			state["main_ui_handler_valid"] = true
			return state
	return {
		"main_ui_handler_valid": true,
		"debug_state_available": false
	}


func save_scene_switch_truth(reason: String = "scene_switch") -> bool:
	# Scene transitions are allowed to write the universe truth. Runtime event
	# autosaves stay disabled elsewhere so TODO/event completion does not freeze.
	show_saving_cover_before_save(reason, true)
	return write_scene_switch_truth(reason)


func write_scene_switch_truth(reason: String = "scene_switch") -> bool:
	if save_manager == null or not save_manager.has_method("save_universe"):
		print("[SCENE_SWITCH_SAVE] skipped | reason=", reason, " save_manager_missing=true")
		return false

	var started_ms := Time.get_ticks_msec()
	var saved_ok := bool(save_manager.save_universe(
		star_field,
		map,
		space_objects,
		inventory,
		enemy_handler,
		npc_handler,
		beacons,
		game_event_handler,
		planets,
		player_state
	))
	var event_summary := build_scene_switch_event_summary()
	print(
		"[SCENE_SWITCH_SAVE] reason=",
		reason,
		" saved_ok=",
		saved_ok,
		" elapsed_ms=",
		Time.get_ticks_msec() - started_ms,
		" events=",
		event_summary
	)
	return saved_ok


func begin_scene_switch_after_cover_frame(reason: String, scene_path: String, stop_music_before_switch: bool = false, save_before_switch: bool = true) -> void:
	if scene_switch_save_in_progress:
		print("[SCENE_SWITCH_SAVE] deferred transition ignored | already_in_progress=true reason=", reason)
		return
	if not ResourceLoader.exists(scene_path):
		print("[SCENE_SWITCH_SAVE] transition blocked | missing scene_path=", scene_path, " reason=", reason)
		handle_scene_switch_failed(reason, scene_path, ERR_FILE_NOT_FOUND)
		return

	scene_switch_save_in_progress = true
	show_saving_cover_before_save(reason, true)
	call_deferred("_run_scene_switch_after_cover_frame", reason, scene_path, stop_music_before_switch, save_before_switch)


func _run_scene_switch_after_cover_frame(reason: String, scene_path: String, stop_music_before_switch: bool, save_before_switch: bool) -> void:
	await get_tree().process_frame

	if save_before_switch:
		write_scene_switch_truth(reason)

	if stop_music_before_switch:
		Globals.stop_main_mode_music(false)

	var change_result := get_tree().change_scene_to_file(scene_path)
	if change_result != OK:
		handle_scene_switch_failed(reason, scene_path, change_result)
		return

	scene_switch_save_in_progress = false


func handle_scene_switch_failed(reason: String, scene_path: String, error_code: int) -> void:
	scene_switch_save_in_progress = false
	if reason.find("orbit") >= 0:
		Globals.orbit_pending = false
		Globals.swap_orbit = false

	hide_saving_cover_after_save(reason + "_failed")
	print("[SCENE_SWITCH_SAVE] transition failed | reason=", reason, " scene_path=", scene_path, " error=", error_code)
	if gui_state != null and gui_state.log_storage.has("log_text"):
		gui_state.log_storage["log_text"].text = "Scene switch failed: " + scene_path + " error=" + str(error_code)


func build_scene_switch_event_summary() -> Dictionary:
	if game_event_handler == null or not game_event_handler.has_method("to_save_data"):
		return {}

	var data = game_event_handler.to_save_data()
	if typeof(data) != TYPE_DICTIONARY:
		return {}

	var active = data.get("active_events", {})
	var available = data.get("available_events", {})
	var completed = data.get("completed_events", {})
	return {
		"active": active.size() if typeof(active) == TYPE_DICTIONARY else -1,
		"available": available.size() if typeof(available) == TYPE_DICTIONARY else -1,
		"completed": completed.size() if typeof(completed) == TYPE_DICTIONARY else -1,
		"active_event_id": str(data.get("active_event_id", ""))
	}


# ==========================================================
# 🔁 PROCESS — MAIN LOOP
# ----------------------------------------------------------
# Runs every frame.
# Each function is isolated for clarity.
# ==========================================================

func add_scene_tree_swap_check():
	if Globals.print_priority_3:
		print("Checking deferred scene swap requests.")

	if scene_switch_save_in_progress:
		return

	if Globals.swap_NPC_tran:
		Globals.swap_NPC_tran = false
		begin_scene_switch_after_cover_frame("npc_transition", "res://Scenes/Npc/NPC_tran.tscn", false, true)
		return

	if Globals.swap_battle_v2:
		Globals.swap_battle_v2 = false
		begin_scene_switch_after_cover_frame("battle_v2_transition", Globals.battle_v2_scene_path, true, true)
		return

	if Globals.swap_orbit:
		if typeof(Globals.orbit_context) != TYPE_DICTIONARY or Globals.orbit_context.is_empty():
			Globals.orbit_context = build_orbit_snapshot_context("direct_swap")

		Globals.orbit_pending = true
		Globals.swap_orbit = false
		begin_scene_switch_after_cover_frame("orbit_transition", Globals.orbit_scene_path, false, false)
		return


func request_orbit_entry(entry_reason: String = "manual") -> bool:
	# Summary: Build Orbit's plain-data universe snapshot and request the scene swap.
	if scene_switch_save_in_progress:
		if Globals.print_priority_2:
			print("[ORBIT_ENTRY_BLOCKED] reason=scene_switch_in_progress")
		return false
	if Globals.orbit_mode or Globals.orbit_pending or Globals.swap_orbit:
		if Globals.print_priority_2:
			print("[ORBIT_ENTRY_BLOCKED] reason=orbit_already_active")
		return false

	var context := build_orbit_snapshot_context(entry_reason)
	if context.is_empty():
		hide_saving_cover_after_save("orbit_context_failed")
		if Globals.print_priority_2:
			print("[ORBIT_ENTRY_BLOCKED] reason=empty_context")
		return false

	Globals.orbit_context = context
	Globals.orbit_pending = true
	Globals.swap_orbit = false
	begin_scene_switch_after_cover_frame("orbit_transition_" + entry_reason, Globals.orbit_scene_path, false, false)
	return true


func build_orbit_snapshot_context(entry_reason: String = "manual") -> Dictionary:
	save_scene_switch_truth("orbit_snapshot_" + entry_reason)

	var snapshot := build_orbit_universe_snapshot(entry_reason)
	if snapshot.is_empty():
		return {}

	var summary := build_orbit_snapshot_summary(snapshot)
	var context := {
		"context_schema": ORBIT_CONTEXT_SCHEMA,
		"entry_reason": entry_reason,
		"created_at_unix": int(Time.get_unix_time_from_system()),
		"created_at_text": get_orbit_datetime_text(),
		"snapshot": snapshot,
		"snapshot_summary": summary
	}

	if Globals.print_priority_2:
		print("[ORBIT_CONTEXT_BUILT] summary=", summary)

	return context


func build_orbit_universe_snapshot(entry_reason: String = "manual") -> Dictionary:
	var existing_save := get_orbit_existing_save_data()
	var snapshot := {
		"save_version": int(existing_save.get("save_version", ORBIT_SNAPSHOT_SAVE_VERSION)),
		"stars": get_orbit_stars_save_data(existing_save),
		"map": get_orbit_map_save_data(existing_save),
		"space_objects": get_orbit_space_object_save_data(existing_save),
		"inventory": get_orbit_inventory_save_data(existing_save),
		"enemies": get_orbit_enemy_save_data(existing_save),
		"npcs": get_orbit_npc_save_data(existing_save),
		"beacons": get_orbit_beacon_save_data(existing_save),
		"planets": get_orbit_planet_save_data(existing_save),
		"game_events": get_orbit_game_events_save_data(existing_save),
		"scan_state": get_orbit_dictionary_section(existing_save, "scan_state"),
		"player_state": get_orbit_player_state_save_data(existing_save),
		"runtime_migrations": get_orbit_dictionary_section(existing_save, "runtime_migrations")
	}

	var universe_meta = existing_save.get("universe_meta", {})
	if typeof(universe_meta) == TYPE_DICTIONARY and not universe_meta.is_empty():
		snapshot["universe_meta"] = universe_meta.duplicate(true)

	snapshot["orbit_snapshot_meta"] = {
		"schema": ORBIT_SNAPSHOT_SCHEMA,
		"entry_reason": entry_reason,
		"created_at_unix": int(Time.get_unix_time_from_system()),
		"created_at_text": get_orbit_datetime_text(),
		"source": "main_mode.build_orbit_universe_snapshot",
		"summary": build_orbit_snapshot_summary(snapshot)
	}

	return snapshot


func get_orbit_existing_save_data() -> Dictionary:
	if save_manager != null and save_manager.has_method("read_universe_save_data"):
		var data = save_manager.read_universe_save_data()
		if typeof(data) == TYPE_DICTIONARY:
			return data.duplicate(true)
	return {}


func get_orbit_datetime_text() -> String:
	if save_manager != null and save_manager.has_method("get_current_datetime_text"):
		return str(save_manager.get_current_datetime_text())

	var date := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(date.get("year", 0)),
		int(date.get("month", 0)),
		int(date.get("day", 0)),
		int(date.get("hour", 0)),
		int(date.get("minute", 0)),
		int(date.get("second", 0))
	]


func get_orbit_stars_save_data(existing_save: Dictionary) -> Array:
	if star_field != null and star_field.has_method("to_save_data"):
		var data = star_field.to_save_data()
		if typeof(data) == TYPE_ARRAY:
			return data.duplicate(true)
	return get_orbit_array_section(existing_save, "stars")


func get_orbit_map_save_data(existing_save: Dictionary) -> Dictionary:
	if map != null and map.has_method("to_save_data"):
		var data = map.to_save_data()
		if typeof(data) == TYPE_DICTIONARY:
			return data.duplicate(true)
	return get_orbit_dictionary_section(existing_save, "map")


func get_orbit_space_object_save_data(existing_save: Dictionary) -> Array:
	if space_objects != null and space_objects.has_method("get_save_data"):
		var data = space_objects.get_save_data()
		if typeof(data) == TYPE_ARRAY:
			return data.duplicate(true)
	return get_orbit_array_section(existing_save, "space_objects")


func get_orbit_inventory_save_data(existing_save: Dictionary) -> Dictionary:
	if inventory != null and inventory.has_method("get_save_data"):
		var data = inventory.get_save_data()
		if typeof(data) == TYPE_DICTIONARY:
			return data.duplicate(true)
	return get_orbit_dictionary_section(existing_save, "inventory")


func get_orbit_enemy_save_data(existing_save: Dictionary) -> Dictionary:
	if enemy_handler != null and enemy_handler.has_method("to_save_data"):
		var data = enemy_handler.to_save_data()
		if typeof(data) == TYPE_DICTIONARY:
			return data.duplicate(true)

	var existing = existing_save.get("enemies", {})
	if typeof(existing) == TYPE_DICTIONARY:
		return existing.duplicate(true)
	if typeof(existing) == TYPE_ARRAY:
		return {"enemies": existing.duplicate(true)}
	return {"enemies": []}


func get_orbit_npc_save_data(existing_save: Dictionary) -> Array:
	if npc_handler != null and npc_handler.has_method("to_save_data"):
		var data = npc_handler.to_save_data()
		if typeof(data) == TYPE_ARRAY:
			return data.duplicate(true)
	return get_orbit_array_section(existing_save, "npcs")


func get_orbit_beacon_save_data(existing_save: Dictionary) -> Array:
	if beacons != null and beacons.has_method("get_save_data"):
		var data = beacons.get_save_data()
		if typeof(data) == TYPE_ARRAY:
			return data.duplicate(true)
	return get_orbit_array_section(existing_save, "beacons")


func get_orbit_planet_save_data(existing_save: Dictionary) -> Array:
	if planets != null and planets.has_method("get_save_data"):
		var data = planets.get_save_data()
		if typeof(data) == TYPE_ARRAY:
			return data.duplicate(true)
	return get_orbit_array_section(existing_save, "planets")


func get_orbit_game_events_save_data(existing_save: Dictionary) -> Dictionary:
	if game_event_handler != null and game_event_handler.has_method("to_save_data"):
		var data = game_event_handler.to_save_data()
		if typeof(data) == TYPE_DICTIONARY and not data.is_empty():
			return data.duplicate(true)
	return get_orbit_dictionary_section(existing_save, "game_events")


func get_orbit_player_state_save_data(existing_save: Dictionary) -> Dictionary:
	if player_state != null and player_state.has_method("get_save_data"):
		var data = player_state.get_save_data()
		if typeof(data) == TYPE_DICTIONARY:
			return data.duplicate(true)
	return get_orbit_dictionary_section(existing_save, "player_state")


func get_orbit_array_section(source: Dictionary, section_name: String) -> Array:
	var value = source.get(section_name, [])
	if typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return []


func get_orbit_dictionary_section(source: Dictionary, section_name: String) -> Dictionary:
	var value = source.get(section_name, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return {}


func build_orbit_snapshot_summary(snapshot: Dictionary) -> Dictionary:
	var enemies_packet = snapshot.get("enemies", {})
	var enemy_count := 0
	if typeof(enemies_packet) == TYPE_DICTIONARY:
		var enemies = enemies_packet.get("enemies", [])
		if typeof(enemies) == TYPE_ARRAY:
			enemy_count = enemies.size()
	elif typeof(enemies_packet) == TYPE_ARRAY:
		enemy_count = enemies_packet.size()

	return {
		"stars": get_orbit_array_section(snapshot, "stars").size(),
		"space_objects": get_orbit_array_section(snapshot, "space_objects").size(),
		"npcs": get_orbit_array_section(snapshot, "npcs").size(),
		"enemies": enemy_count,
		"beacons": get_orbit_array_section(snapshot, "beacons").size(),
		"planets": get_orbit_array_section(snapshot, "planets").size(),
		"has_map": not get_orbit_dictionary_section(snapshot, "map").is_empty(),
		"has_inventory": not get_orbit_dictionary_section(snapshot, "inventory").is_empty(),
		"has_player_state": not get_orbit_dictionary_section(snapshot, "player_state").is_empty()
	}

func _process(delta: float) -> void:
	if not main_mode_boot_complete:
		return

	add_scene_tree_swap_check()
	process_pending_main_mode_event_widget_poke(delta)
	update_battle_navigation_visibility()

	handle_autopilot_trigger()
	update_autopilot_ui()
	
	update_world(delta)
	update_engine_widget()
	handle_popup_input_lock_transition()
	update_ui(delta)
	update_ami_report(delta)
	process_blueprint_inventory_refresh(delta)

	# 👇 THIS IS THE MISSING LINK
	check_for_enemy_encounter()

	
	clear_scanned_results_after_ship_movement()
	
	decor_ui_and_energy_ui(delta)
	auto_pilot.update_autopilot_state(delta)
	handle_auto_scan_after_autopilot()
	
	
	#cross your fingers 
	
	if widget_spec_ui != null:
		widget_spec_ui.process_onscreen_widget_runtime(delta)
	
	if game_event_handler != null:
		game_event_handler.execute_event_checks(delta)

	process_story_popup_log_widget(delta)

	if sound_handler != null:
		sound_handler.process_sound_handler(delta)
	
	
	
	
func queue_event_widget_poke_after_main_mode_load() -> void:
	main_mode_event_widget_poke_pending = true
	main_mode_event_widget_poke_done = false
	main_mode_event_widget_poke_wait_frames = 1


func process_pending_main_mode_event_widget_poke(_delta: float) -> void:
	if not main_mode_event_widget_poke_pending or main_mode_event_widget_poke_done:
		return
	if game_event_handler == null:
		return
	if Globals.battle_mode or Globals.battle_pending or Globals.swap_battle_v2 or Globals.orbit_mode or Globals.orbit_pending or Globals.swap_orbit:
		return
	if main_mode_event_widget_poke_wait_frames > 0:
		main_mode_event_widget_poke_wait_frames -= 1
		return

	main_mode_event_widget_poke_pending = false
	main_mode_event_widget_poke_done = true

	if game_event_handler.has_method("poke_event_widget"):
		game_event_handler.poke_event_widget("main_mode_loaded")
	elif game_event_handler.has_method("request_event_pulse"):
		game_event_handler.request_event_pulse("main_mode_loaded")


#func build_music_system() -> void:
	#sonic_pi_music_director.name = "SonicPiMusicDirector"
	#add_child(sonic_pi_music_director)
	#sonic_pi_music_director.start_startup_music_once()


func decor_ui_and_energy_ui(delta):
	if Globals.hostile_contact_alert_needed:
		if Globals.print_priority_3:
			print("SHOULD SHOW ALERT \n SHOULD SHOW IT NOW \n################\n##############")

		Globals.hostile_contact_alert_needed = false

		decorative_ui.show_hostile_contact_alert()
		
	update_decorative_ui(delta)
	update_live_map_widget(delta)
	update_tier_map_widget(delta)
	
	energy_handler.update_energy_handler(delta)
	
	update_battle_navigation_visibility()
	
	
func update_decorative_ui(delta: float) -> void:

	decorative_ui.update_hostile_contact_alert(delta)
	decorative_ui.update_receiving_message_alert(delta)


func build_live_map_widget() -> void:
	# Summary: Build the Live Map V1 radar as its own right-column widget.
	if inv_radar_panel.live_map_control != null:
		return

	inv_radar_panel.live_map_control = LiveMapControlScript.new()
	inv_radar_panel.live_map_control.build(
		Globals.live_map_widg_pos,
		Globals.inventory_widget_size,
		gui_state,
		action_manager,
		auto_pilot
	)
	inv_radar_panel.live_map_control.visible = true
	map.live_map_inventory_mode = true
	if inv_radar_panel.live_map_control.has_method("set_clickable_enabled"):
		inv_radar_panel.live_map_control.set_clickable_enabled(true)
	inv_radar_panel.live_map_control.marker_selected.connect(map._on_live_map_marker_selected)
	add_child(inv_radar_panel.live_map_control)
	inv_radar_panel.live_map_control.refresh_from_packet(map.build_live_map_scan_packet())


func update_tier_map_widget(delta: float = 0.0) -> void:
	# Summary: Poll live world owners through Map.gd and redraw the tier widget only when changed.
	if gui_state == null or not gui_state.controls.has("tier_map"):
		return
	if not should_poll_tier_map_widget():
		tier_map_refresh_timer = 0.0
		return

	tier_map_refresh_timer += delta
	if tier_map_refresh_timer < TIER_MAP_REFRESH_INTERVAL:
		return

	tier_map_refresh_timer = 0.0
	refresh_tier_map_widget()


func should_poll_tier_map_widget() -> bool:
	if not Globals.main_cockpit_v2_enabled:
		return is_tier_map_control_visible()
	if main_left_panel_controller != null and main_left_panel_controller.has_method("get_active_panel_id"):
		return str(main_left_panel_controller.get_active_panel_id()) == "tier_map"
	return is_tier_map_control_visible()


func is_tier_map_control_visible() -> bool:
	if gui_state == null or not gui_state.controls.has("tier_map"):
		return false
	var root = gui_state.controls["tier_map"]
	return root is Control and (root as Control).is_visible_in_tree()


func refresh_tier_map_widget(force: bool = false) -> void:
	if gui_state == null or map == null:
		return
	if not gui_state.controls.has("tier_map"):
		return

	var packet: Dictionary = map.build_tier_map_packet()
	var signature := make_tier_map_signature(packet)
	if not force and signature == tier_map_last_signature:
		return

	tier_map_last_signature = signature
	tier_map_last_packet = packet
	apply_tier_map_packet_to_widget(packet)


func make_tier_map_signature(packet: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append(tier_map_active_tab)
	parts.append(str(packet.get("current_tier", 1)))
	parts.append(str(packet.get("tier_sector_min_x", 0)))
	parts.append(str(packet.get("tier_sector_max_x", 0)))
	parts.append(str(packet.get("center_sector", Vector3i.ZERO)))

	var markers: Array = packet.get("markers", [])
	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		parts.append(str(marker.get("id", "")))
		parts.append(str(marker.get("type", "")))
		parts.append(str(marker.get("display_name", "")))
		parts.append(str(marker.get("sector_pos", Vector3i.ZERO)))
		parts.append(str(marker.get("local_pos", Vector3.ZERO)))
		parts.append(str(marker.get("distance", 0.0)))

	var bridges: Array = packet.get("bridges", [])
	for bridge in bridges:
		if typeof(bridge) != TYPE_DICTIONARY:
			continue
		parts.append(str(bridge.get("id", "")))
		parts.append(str(bridge.get("target_tier", "")))
		parts.append(str(bridge.get("sector_pos", Vector3i.ZERO)))

	return "|".join(parts)


func apply_tier_map_packet_to_widget(packet: Dictionary) -> void:
	if gui_state == null:
		return

	var current_tier := int(packet.get("current_tier", 1))
	var max_tier := int(packet.get("max_tier", 8))
	var min_x := int(packet.get("tier_sector_min_x", 0))
	var max_x := int(packet.get("tier_sector_max_x", 0))
	var markers: Array = packet.get("markers", [])
	var bridges: Array = packet.get("bridges", [])

	var filtered_markers := filter_tier_map_markers_for_active_tab(markers)
	filtered_markers.sort_custom(func(a, b): return float(a.get("distance", 0.0)) < float(b.get("distance", 0.0)))

	var rows: Array = gui_state.labels.get("tier_map_rows", [])
	var display_count = min(filtered_markers.size(), rows.size())
	var tab_label := str(TIER_MAP_TAB_LABELS.get(tier_map_active_tab, tier_map_active_tab.to_upper()))
	var visibility_units := int(round(float(packet.get("visibility_world_units", 10000.0))))
	var visibility_sectors := int(round(float(packet.get("visibility_sector_radius", 10.0))))

	if gui_state.labels.has("tier_map_info"):
		gui_state.labels["tier_map_info"].text = "Tier " + str(current_tier) + " / " + str(max_tier) + "   Visible: " + str(markers.size()) + "   " + tab_label + ": " + str(filtered_markers.size())
	if gui_state.labels.has("tier_map_sector"):
		gui_state.labels["tier_map_sector"].text = "Gate " + str(visibility_units) + "u / " + str(visibility_sectors) + " sectors   X " + str(min_x) + "-" + str(max_x) + "   Ship " + str(packet.get("center_sector", Vector3i.ZERO))

	for i in range(rows.size()):
		var label = rows[i]
		if label == null:
			continue
		if i < display_count:
			var marker: Dictionary = filtered_markers[i]
			label.text = make_tier_map_marker_row_text(marker)
			label.visible = true
			if label is BaseButton:
				label.disabled = Globals.is_popup_input_locked()
				label.set_meta("tier_map_marker", marker)
		else:
			label.text = "---"
			label.visible = i < 3
			if label is BaseButton:
				label.disabled = true
				label.set_meta("tier_map_marker", {})

	update_tier_map_bridge_buttons(bridges)
	update_tier_map_tab_buttons()

func make_tier_map_marker_row_text(marker: Dictionary) -> String:
	var marker_type := get_tier_map_marker_row_type(marker)
	var display_name := str(marker.get("display_name", "Unknown"))
	var distance := int(round(float(marker.get("distance", 0.0))))
	return marker_type.to_upper() + " | " + display_name + " | " + str(distance) + "u"


func filter_tier_map_markers_for_active_tab(markers: Array) -> Array:
	var filtered: Array = []
	for marker in markers:
		if typeof(marker) != TYPE_DICTIONARY:
			continue
		if tier_map_active_tab == "all" or get_tier_map_marker_family(marker) == tier_map_active_tab:
			filtered.append(marker)
	return filtered


func get_tier_map_marker_family(marker: Dictionary) -> String:
	var marker_type := str(marker.get("type", "object")).strip_edges().to_lower()
	if marker_type in ["star", "planet", "beacon", "enemy", "npc"]:
		return marker_type
	return "object"


func get_tier_map_marker_row_type(marker: Dictionary) -> String:
	var marker_type := str(marker.get("type", "object")).strip_edges().to_lower()
	if marker_type == "object" and str(marker.get("object_type", "")).strip_edges() != "":
		return str(marker.get("object_type", "object")).strip_edges().to_lower()
	return get_tier_map_marker_family(marker)


func update_tier_map_bridge_buttons(bridges: Array) -> void:
	if gui_state == null or not gui_state.buttons.has("tier_map"):
		return

	if gui_state.buttons["tier_map"].has("bridge_previous"):
		var prev_button = gui_state.buttons["tier_map"]["bridge_previous"]
		prev_button.visible = false
		prev_button.disabled = true
		prev_button.text = ""

	if gui_state.buttons["tier_map"].has("bridge_next"):
		var next_button = gui_state.buttons["tier_map"]["bridge_next"]
		next_button.visible = false
		next_button.disabled = true
		next_button.text = ""


func update_tier_map_tab_buttons() -> void:
	if gui_state == null or not gui_state.buttons.has("tier_map"):
		return
	for tab_id in TIER_MAP_TYPE_TABS:
		var key := "tab_" + str(tab_id)
		if not gui_state.buttons["tier_map"].has(key):
			continue
		var tab_button = gui_state.buttons["tier_map"][key]
		if tab_button == null or not is_instance_valid(tab_button):
			continue
		tab_button.disabled = Globals.is_popup_input_locked()
		tab_button.modulate = Color(0.60, 1.0, 1.0, 1.0) if str(tab_id) == tier_map_active_tab else Color.WHITE


func find_tier_map_bridge(bridges: Array, direction: String) -> Dictionary:
	for bridge in bridges:
		if typeof(bridge) != TYPE_DICTIONARY:
			continue
		if str(bridge.get("direction", "")) == direction:
			return bridge
	return {}


func connect_tier_map_buttons() -> void:
	if gui_state == null or not gui_state.buttons.has("tier_map"):
		return
	for tab_id in TIER_MAP_TYPE_TABS:
		var key := "tab_" + str(tab_id)
		if gui_state.buttons["tier_map"].has(key):
			var tab_button = gui_state.buttons["tier_map"][key]
			if tab_button is BaseButton and not tab_button.pressed.is_connected(_on_tier_map_tab_pressed.bind(str(tab_id))):
				tab_button.pressed.connect(_on_tier_map_tab_pressed.bind(str(tab_id)))

	var rows: Array = gui_state.labels.get("tier_map_rows", [])
	for i in range(rows.size()):
		var row_button = rows[i]
		if row_button is BaseButton:
			if not row_button.pressed.is_connected(_on_tier_map_marker_row_pressed.bind(i)):
				row_button.pressed.connect(_on_tier_map_marker_row_pressed.bind(i))
	update_tier_map_tab_buttons()


func _on_tier_map_tab_pressed(tab_id: String) -> void:
	var clean_id := tab_id.strip_edges().to_lower()
	if not TIER_MAP_TYPE_TABS.has(clean_id):
		clean_id = "all"
	if tier_map_active_tab == clean_id:
		return
	tier_map_active_tab = clean_id
	tier_map_last_signature = ""
	if not tier_map_last_packet.is_empty():
		apply_tier_map_packet_to_widget(tier_map_last_packet)
	else:
		refresh_tier_map_widget(true)


func _on_tier_map_marker_row_pressed(row_index: int) -> void:
	# Summary: Open the existing coordinate auto-pilot popup with this tier-map marker preloaded.
	if Globals.is_popup_input_locked():
		if Globals.print_priority_2:
			print("Tier map marker click blocked while popup input is locked.")
		return
	if gui_state == null:
		return

	var rows: Array = gui_state.labels.get("tier_map_rows", [])
	if row_index < 0 or row_index >= rows.size():
		return

	var row_button = rows[row_index]
	if row_button == null or not is_instance_valid(row_button):
		return
	if not row_button.has_meta("tier_map_marker"):
		return

	var marker_variant = row_button.get_meta("tier_map_marker")
	if typeof(marker_variant) != TYPE_DICTIONARY:
		return

	var marker: Dictionary = marker_variant
	if marker.is_empty():
		return

	open_tier_map_marker_auto_popup(marker)


func open_tier_map_marker_auto_popup(marker: Dictionary) -> void:
	if gui_state == null:
		return

	var target_sector: Vector3i = SharedObjectMeta.read_sector_pos(marker.get("sector_pos", Vector3i.ZERO))
	var target_local: Vector3 = SharedObjectMeta.read_local_pos(marker.get("local_pos", Vector3.ZERO))
	var target_name := str(marker.get("display_name", "Tier Contact"))
	var target_type := str(marker.get("type", "object"))

	show_coord_auto_popup()
	preload_coord_auto_popup_target(target_sector, target_local, target_name, target_type, "tier_map_row")

	if gui_state.log_storage.has("log_text"):
		gui_state.log_storage["log_text"].text = (
			"Tier map target loaded.\n"
			+ "Target: " + target_name + " (" + target_type + ")\n"
			+ "Sector: " + str(target_sector) + "\n"
			+ "Local: " + str(target_local)
		)


func preload_coord_auto_popup_target(target_sector: Vector3i, target_local: Vector3, target_name: String, target_type: String = "object", target_source: String = "tier_map") -> void:
	# Summary: Fill the existing coord auto-pilot popup fields without engaging the route.
	# Important: tier-map targets keep a hidden payload so ENGAGE can use the precise
	# AutoPilot target route instead of the broad manual coordinate-warp route.
	if gui_state == null:
		return

	coord_auto_preloaded_target = {
		"active": true,
		"source": target_source,
		"sector_pos": target_sector,
		"local_pos": target_local,
		"display_name": target_name,
		"target_type": target_type
	}

	if gui_state.controls.has("coord_auto_pilot_root"):
		var root = gui_state.controls["coord_auto_pilot_root"]
		if root != null and is_instance_valid(root):
			root.set_meta("coord_auto_preloaded_target", coord_auto_preloaded_target.duplicate(true))

	var clean_local := Vector3(
		round(target_local.x * 100.0) / 100.0,
		round(target_local.y * 100.0) / 100.0,
		round(target_local.z * 100.0) / 100.0
	)

	var field_values := {
		"coord_auto_sector_x": str(target_sector.x),
		"coord_auto_sector_y": str(target_sector.y),
		"coord_auto_sector_z": str(target_sector.z),
		"coord_auto_local_x": str(clean_local.x),
		"coord_auto_local_y": str(clean_local.y),
		"coord_auto_local_z": str(clean_local.z)
	}

	for field_name in field_values.keys():
		if gui_state.controls.has(field_name):
			var field = gui_state.controls[field_name]
			if field is LineEdit:
				field.text = str(field_values[field_name])
				field.caret_column = field.text.length()

	if gui_state.labels.has("coord_auto_pilot_title"):
		var title = gui_state.labels["coord_auto_pilot_title"]
		if title != null and is_instance_valid(title):
			title.text = "AUTO TO TARGET"

	if gui_state.labels.has("coord_auto_hint"):
		var hint = gui_state.labels["coord_auto_hint"]
		if hint != null and is_instance_valid(hint):
			hint.text = "Target loaded: " + target_name + " (" + target_type + "). Press ENGAGE or CLOSE."

	if Globals.print_priority_2:
		print("[TIER_MAP_PRELOAD_COORD_AUTO] name=", target_name, " type=", target_type, " source=", target_source, " sector=", target_sector, " local=", target_local)


func _on_tier_map_bridge_pressed(direction: String) -> void:
	if Globals.is_popup_input_locked():
		if Globals.print_priority_2:
			print("Tier map bridge click blocked while popup input is locked.")
		return
	if map == null:
		return

	var packet: Dictionary = map.build_tier_map_packet()
	var bridge := find_tier_map_bridge(packet.get("bridges", []), direction)
	if bridge.is_empty():
		return

	var target_sector: Vector3i = SharedObjectMeta.read_sector_pos(bridge.get("sector_pos", Vector3i.ZERO))
	var target_local: Vector3 = SharedObjectMeta.read_local_pos(bridge.get("local_pos", Vector3.ZERO))
	var target_name := str(bridge.get("display_name", "Tier Bridge"))

	show_coord_auto_popup()
	preload_coord_auto_popup_target(target_sector, target_local, target_name, "tier_bridge", "tier_map_bridge")
	tier_map_last_signature = ""
	refresh_tier_map_widget(true)

	if gui_state.log_storage.has("log_text"):
		gui_state.log_storage["log_text"].text = (
			"Tier bridge target loaded.\n"
			+ "Target: " + target_name + "\n"
			+ "Sector: " + str(target_sector) + "\n"
			+ "Local: " + str(target_local)
		)


func build_port_window_widget() -> void:
	# Summary: Visual-only forward port that projects the same contact packet used by Live Map.
	if port_window_widget.get_parent() != null:
		return

	port_window_widget.name = "PortWindowWidget"
	port_window_widget.position = Globals.get_port_window_widget_pos()
	port_window_widget.setup(map, Globals.port_window_widget_size, gui_state, false, eng)
	add_child(port_window_widget)


func build_port_window_backdrop() -> void:
	# Summary: Fullscreen forward port used as a toggleable replacement for the sci-fi backing.
	if port_window_backdrop.get_parent() != null:
		return

	port_window_backdrop.name = "MainViewWindowBackdrop"
	port_window_backdrop.position = Vector2.ZERO
	port_window_backdrop.z_index = -9
	port_window_backdrop.setup(map, Vector2(Globals.screen_w, Globals.screen_h), null, true, eng)
	port_window_backdrop.visible = true
	add_child(port_window_backdrop)


func build_main_ai_news_widget(reason: String = "manual") -> void:
	if gui_state == null or gui_builder == null:
		print("[MAIN_AI] news widget build blocked | reason=", reason, " gui_state=", gui_state, " gui_builder=", gui_builder)
		return

	if gui_state.controls.has("main_ai_news_root") and gui_state.controls["main_ai_news_root"] is Control:
		var existing_root := gui_state.controls["main_ai_news_root"] as Control
		existing_root.position = Globals.main_ai_news_widget_pos
		existing_root.size = Globals.main_ai_news_widget_size
		existing_root.visible = true
		existing_root.z_index = 155
		return

	if not gui_builder.has_method("build_main_ai_news_widget"):
		print("[MAIN_AI] news widget build blocked | builder missing method")
		return

	var news_root = gui_builder.build_main_ai_news_widget(
		gui_state,
		Globals.main_ai_news_widget_pos,
		Globals.main_ai_news_widget_size
	)
	if news_root == null:
		print("[MAIN_AI] news widget build blocked | builder returned null")
		return

	if news_root.get_parent() == null:
		add_child(news_root)
	news_root.z_index = 155
	news_root.visible = true
	print("[MAIN_AI] news widget built | reason=", reason, " pos=", news_root.position, " size=", news_root.size)


func setup_mining_gain_feed(reason: String = "manual") -> void:
	if mining_gain_feed == null or not is_instance_valid(mining_gain_feed):
		mining_gain_feed = MiningGainFeedScript.new()

	mining_gain_feed.name = "MiningGainFeed"
	if mining_gain_feed.get_parent() == null:
		add_child(mining_gain_feed)

	if mining_gain_feed.has_method("setup"):
		mining_gain_feed.setup(gui_state)

	print("[MINING_GAIN_FEED] setup | reason=", reason)


func toggle_port_window_backdrop() -> void:
	build_port_window_backdrop()
	port_window_backdrop_enabled = not port_window_backdrop_enabled
	port_window_backdrop.visible = port_window_backdrop_enabled

	if scifi_background_root != null:
		scifi_background_root.visible = not port_window_backdrop_enabled
	if port_window_widget != null:
		port_window_widget.visible = true


func update_live_map_widget(delta: float = 0.0) -> void:
	# Summary: Refresh Live Map V1 from owner-built scan packets while the live map panel is visible.
	if inv_radar_panel.live_map_control == null:
		return
	if not inv_radar_panel.live_map_control.visible:
		inv_radar_panel.live_map_refresh_timer = 0.0
		return

	inv_radar_panel.live_map_refresh_timer += delta
	if inv_radar_panel.live_map_refresh_timer < LIVE_MAP_REFRESH_INTERVAL:
		return

	inv_radar_panel.live_map_refresh_timer = 0.0
	inv_radar_panel.live_map_control.refresh_from_packet(map.build_live_map_scan_packet())





# ==========================================================
# 🎨 BUILD: BACKGROUND
# ==========================================================
func build_background() -> void:
	# NOTE:
	# Original name preserved (help_arora_work)
	# but clearly this builds the animated sci-fi background
	help_arora_work()
	# ==========================================================
# DECORATIVE UI
# ==========================================================
	add_child(decorative_ui)
	decorative_ui.build_hostile_contact_alert()


func apply_main_cockpit_v2_boot_layout() -> void:
	if not Globals.main_cockpit_v2_enabled:
		return

	Globals.port_window_widget_size = Globals.main_forward_view_size
	Globals.log_widg_pos = Globals.main_bottom_log_pos
	Globals.log_widget_size = Globals.main_bottom_log_size
	Globals.main_ai_news_widget_size = Vector2(
		(Globals.main_bottom_log_pos.x + Globals.main_bottom_log_size.x) - Globals.main_forward_view_pos.x,
		Globals.main_forward_view_size.y * 0.5
	)
	Globals.main_ai_news_widget_pos = Vector2(
		Globals.main_forward_view_pos.x,
		Globals.main_forward_view_pos.y - Globals.main_ai_news_widget_size.y - 8.0
	)
	Globals.event_widget_size = Globals.main_right_widget_size
	Globals.action_widget_size = Globals.main_right_widget_size
	Globals.todo_widget_size = Globals.main_right_widget_size
	Globals.action_pos = Globals.get_main_action_widget_pos_v2()
	Globals.ami_star_chart_widget_pos = Globals.main_left_panel_pos
	Globals.ami_star_chart_widget_size = Globals.main_left_panel_size

	if Globals.print_priority_2:
		print("[MAIN_LAYOUT_V2] boot layout applied")


func setup_main_cockpit_v2() -> void:
	if not Globals.main_cockpit_v2_enabled:
		return
	if gui_state == null:
		return

	setup_main_left_panel_controller()
	apply_main_cockpit_v2_static_layout()
	hide_main_cockpit_v2_legacy_widgets()

	if Globals.print_priority_2:
		print("[MAIN_LAYOUT_V2] cockpit setup complete")


func setup_main_left_panel_controller() -> void:
	if main_left_panel_controller == null:
		main_left_panel_controller = MainLeftPanelControllerScript.new()

	main_left_panel_controller.setup(self, gui_state, {
		"left_panel_rect": Rect2(Globals.main_left_panel_pos, Globals.main_left_panel_size),
		"top_strip_rect": Rect2(Globals.main_top_strip_pos, Globals.main_top_strip_size)
	})
	main_left_panel_controller.build_shell()
	main_left_panel_controller.build_button_rail()
	register_main_left_panels()
	main_left_panel_controller.hide_all_panels()


func register_main_left_panels() -> void:
	if main_left_panel_controller == null:
		return

	main_command_left_root = build_main_command_left_panel_root()
	if main_command_left_root != null:
		main_left_panel_controller.register_panel(
			"command",
			main_command_left_root
		)

	if inv_radar_panel != null and inv_radar_panel.live_map_control != null:
		main_left_panel_controller.register_panel(
			"local_map",
			inv_radar_panel.live_map_control,
			Callable(self, "_on_main_left_local_map_open"),
			Callable(self, "_on_main_left_local_map_close")
		)

	if gui_state.controls.has("ami_star_chart_root") and gui_state.controls["ami_star_chart_root"] is Control:
		main_left_panel_controller.register_panel(
			"flat_map",
			gui_state.controls["ami_star_chart_root"],
			Callable(self, "_on_main_left_flat_map_open"),
			Callable(self, "_on_main_left_flat_map_close")
		)

	if gui_state.controls.has("tier_map") and gui_state.controls["tier_map"] is Control:
		layout_tier_map_for_left_panel()
		main_left_panel_controller.register_panel(
			"tier_map",
			gui_state.controls["tier_map"],
			Callable(self, "_on_main_left_tier_map_open"),
			Callable(self, "_on_main_left_tier_map_close")
		)

	inventory_craft_left_root = build_inventory_craft_left_panel_root()
	if inventory_craft_left_root != null:
		main_left_panel_controller.register_panel(
			"inventory_craft",
			inventory_craft_left_root,
			Callable(self, "_on_main_left_inventory_craft_open"),
			Callable(self, "_on_main_left_inventory_craft_close")
		)

	loadout_left_root = build_loadout_left_panel_root()
	if loadout_left_root != null:
		main_left_panel_controller.register_panel(
			"loadout",
			loadout_left_root
		)

	story_popup_log_left_root = build_story_popup_log_left_panel_root()
	if story_popup_log_left_root != null:
		main_left_panel_controller.register_panel(
			"story_log",
			story_popup_log_left_root,
			Callable(self, "_on_main_left_story_log_open")
		)


func build_main_command_left_panel_root() -> Control:
	if main_command_controller == null:
		main_command_controller = MainCommandControllerScript.new()
	main_command_controller.setup(self, gui_state, inv_radar_panel, map, star_field)
	if main_command_controller.has_method("build_left_panel_command_root"):
		return main_command_controller.build_left_panel_command_root(Globals.main_left_panel_size)
	return null


func build_inventory_craft_left_panel_root() -> Control:
	var root := Control.new()
	root.name = "inventory_craft_left_root"
	root.position = Vector2.ZERO
	root.size = Globals.main_left_panel_size
	root.custom_minimum_size = Globals.main_left_panel_size
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if gui_state != null:
		gui_state.controls["inventory_craft_left_root"] = root

	var title := Label.new()
	title.name = "inventory_craft_left_title"
	title.text = "INVENTORY / CRAFT"
	title.position = Vector2(14, 10)
	title.size = Vector2(max(root.size.x - 28.0, 120.0), 24)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.46, 0.95, 1.0, 0.88))
	if gui_state != null and gui_state.font != null:
		title.add_theme_font_override("font", gui_state.font)
	root.add_child(title)

	var label_root = inventory.label_inventory_root if inventory != null else null
	if label_root != null and is_instance_valid(label_root):
		reparent_control(label_root, root)
		label_root.position = Vector2(8, 42)
		if inventory.has_method("apply_label_inventory_widget_size"):
			inventory.apply_label_inventory_widget_size(Vector2(root.size.x - 16.0, 360.0))

	var blueprint_root = gui_state.controls.get("blueprint_root", null)
	if blueprint_root is Control:
		reparent_control(blueprint_root, root)
		layout_blueprint_widget_for_left_panel(blueprint_root as Control, Vector2(8, 415), Vector2(root.size.x - 16.0, root.size.y - 423.0))

	return root


func build_loadout_left_panel_root() -> Control:
	var root := Control.new()
	root.name = "loadout_left_root"
	root.position = Vector2.ZERO
	root.size = Globals.main_left_panel_size
	root.custom_minimum_size = Globals.main_left_panel_size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title := Label.new()
	title.name = "loadout_left_title"
	title.text = "BATTLE LOADOUT"
	title.position = Vector2(14, 12)
	title.size = Vector2(root.size.x - 28.0, 24)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.46, 0.95, 1.0, 0.88))
	if gui_state != null and gui_state.font != null:
		title.add_theme_font_override("font", gui_state.font)
	root.add_child(title)

	var note := Label.new()
	note.name = "loadout_left_note"
	note.text = "Loadout editing still uses the full editor while the left-panel version is being adapted."
	note.position = Vector2(14, 48)
	note.size = Vector2(root.size.x - 28.0, 64)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.78, 0.90, 0.96, 0.86))
	if gui_state != null and gui_state.font != null:
		note.add_theme_font_override("font", gui_state.font)
	root.add_child(note)

	var open_button := Button.new()
	open_button.name = "loadout_left_open_editor"
	open_button.text = "OPEN LOADOUT EDITOR"
	open_button.position = Vector2(14, 132)
	open_button.size = Vector2(root.size.x - 28.0, 40)
	open_button.focus_mode = Control.FOCUS_NONE
	open_button.pressed.connect(show_battle_loadout_popup)
	if gui_state != null and gui_state.font != null:
		open_button.add_theme_font_override("font", gui_state.font)
	root.add_child(open_button)

	if gui_state != null:
		gui_state.controls["loadout_left_root"] = root
		gui_state.buttons["loadout_left_open_editor"] = open_button

	return root


func build_story_popup_log_left_panel_root() -> Control:
	var root := Control.new()
	root.name = "story_popup_log_left_root"
	root.position = Vector2.ZERO
	root.size = Globals.main_left_panel_size
	root.custom_minimum_size = Globals.main_left_panel_size
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var title := Label.new()
	title.name = "story_popup_log_title"
	title.text = "STORY LOG"
	title.position = Vector2(14, 10)
	title.size = Vector2(max(root.size.x - 132.0, 120.0), 24)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.52, 0.96, 1.0, 0.92))
	if gui_state != null and gui_state.font != null:
		title.add_theme_font_override("font", gui_state.font)
	root.add_child(title)

	story_popup_log_count_label = Label.new()
	story_popup_log_count_label.name = "story_popup_log_count"
	story_popup_log_count_label.text = "0 captured"
	story_popup_log_count_label.position = Vector2(max(root.size.x - 112.0, 190.0), 11)
	story_popup_log_count_label.size = Vector2(96, 20)
	story_popup_log_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	story_popup_log_count_label.add_theme_font_size_override("font_size", 11)
	story_popup_log_count_label.add_theme_color_override("font_color", Color(0.73, 0.88, 0.96, 0.72))
	if gui_state != null and gui_state.font != null:
		story_popup_log_count_label.add_theme_font_override("font", gui_state.font)
	root.add_child(story_popup_log_count_label)

	var note := Label.new()
	note.name = "story_popup_log_note"
	note.text = "Captured story popup text for this session."
	note.position = Vector2(14, 34)
	note.size = Vector2(max(root.size.x - 28.0, 120.0), 20)
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(0.72, 0.84, 0.92, 0.68))
	if gui_state != null and gui_state.font != null:
		note.add_theme_font_override("font", gui_state.font)
	root.add_child(note)

	story_popup_log_scroll = ScrollContainer.new()
	story_popup_log_scroll.name = "story_popup_log_scroll"
	story_popup_log_scroll.position = Vector2(10, 60)
	story_popup_log_scroll.size = Vector2(max(root.size.x - 20.0, 120.0), max(root.size.y - 70.0, 120.0))
	story_popup_log_scroll.clip_contents = true
	story_popup_log_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	story_popup_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	story_popup_log_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(story_popup_log_scroll)

	story_popup_log_text = RichTextLabel.new()
	story_popup_log_text.name = "story_popup_log_text"
	story_popup_log_text.bbcode_enabled = true
	story_popup_log_text.scroll_active = false
	story_popup_log_text.fit_content = true
	story_popup_log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_popup_log_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_popup_log_text.add_theme_font_size_override("normal_font_size", 12)
	story_popup_log_text.add_theme_color_override("default_color", Color(0.84, 0.93, 1.0, 0.93))
	if gui_state != null and gui_state.font != null:
		story_popup_log_text.add_theme_font_override("normal_font", gui_state.font)
	story_popup_log_scroll.add_child(story_popup_log_text)

	if gui_state != null:
		gui_state.controls["story_popup_log_left_root"] = root
		gui_state.controls["story_popup_log_scroll"] = story_popup_log_scroll
		gui_state.controls["story_popup_log_text"] = story_popup_log_text
		gui_state.labels["story_popup_log_count"] = story_popup_log_count_label
		gui_state.labels["story_popup_log_text"] = story_popup_log_text

	refresh_story_popup_log_widget(true)
	return root


func _on_main_left_story_log_open() -> void:
	refresh_story_popup_log_widget(true)
	if controller_focus_manager != null and is_instance_valid(controller_focus_manager) and controller_focus_manager.has_method("request_left_panel_focus"):
		controller_focus_manager.request_left_panel_focus("story_log_open")
	call_deferred("scroll_story_popup_log_to_bottom")


func process_story_popup_log_widget(_delta: float = 0.0) -> void:
	if story_popup_log_left_root == null or not is_instance_valid(story_popup_log_left_root):
		return
	refresh_story_popup_log_widget(false)


func refresh_story_popup_log_widget(force: bool = false) -> void:
	if story_popup_log_text == null or not is_instance_valid(story_popup_log_text):
		return
	var revision := int(Globals.get_story_popup_text_log_revision()) if Globals.has_method("get_story_popup_text_log_revision") else 0
	if not force and revision == story_popup_log_last_revision:
		return

	story_popup_log_last_revision = revision
	var entries := Globals.get_story_popup_text_log() if Globals.has_method("get_story_popup_text_log") else []
	if story_popup_log_count_label != null and is_instance_valid(story_popup_log_count_label):
		story_popup_log_count_label.text = str(entries.size()) + " captured"

	story_popup_log_text.clear()
	story_popup_log_text.append_text(build_story_popup_log_bbcode(entries))
	update_story_popup_log_text_size()
	call_deferred("update_story_popup_log_text_size")
	call_deferred("scroll_story_popup_log_to_bottom")


func build_story_popup_log_bbcode(entries: Array) -> String:
	if entries.is_empty():
		return "[center][color=#7892a2]No story popup text captured yet.[/color][/center]"

	var lines: Array = []
	for i in range(entries.size()):
		var entry = entries[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var entry_data: Dictionary = entry
		var title := story_popup_log_escape_bbcode(str(entry_data.get("title", "MESSAGE")).strip_edges())
		if title == "":
			title = "MESSAGE"
		var context_bits: Array = []
		var time_text := format_story_popup_log_time(int(entry_data.get("shown_at_unix", 0)))
		if time_text != "":
			context_bits.append(time_text)
		var event_id := str(entry_data.get("event_id", "")).strip_edges()
		if event_id != "":
			context_bits.append("event " + event_id)
		var event_step := str(entry_data.get("event_step", "")).strip_edges()
		if event_step != "":
			context_bits.append("step " + event_step)

		lines.append("[color=#62e6ff][b]" + str(i + 1) + ". " + title + "[/b][/color]")
		if not context_bits.is_empty():
			lines.append("[color=#7892a2]" + story_popup_log_escape_bbcode(join_story_popup_log_strings(context_bits, "  |  ")) + "[/color]")
		lines.append(str(entry_data.get("text", "")))
		if i < entries.size() - 1:
			lines.append("\n[color=#24475d]------------------------------[/color]\n")

	return join_story_popup_log_strings(lines, "\n")


func update_story_popup_log_text_size() -> void:
	if story_popup_log_text == null or not is_instance_valid(story_popup_log_text):
		return
	if story_popup_log_scroll == null or not is_instance_valid(story_popup_log_scroll):
		return
	var content_width = max(story_popup_log_scroll.size.x - 20.0, 80.0)
	var content_height = max(story_popup_log_scroll.size.y, 80.0)
	if story_popup_log_text.has_method("get_content_height"):
		content_height = max(float(story_popup_log_text.get_content_height()) + 12.0, story_popup_log_scroll.size.y)
	story_popup_log_text.custom_minimum_size = Vector2(content_width, content_height)
	story_popup_log_text.size = story_popup_log_text.custom_minimum_size


func scroll_story_popup_log_to_bottom() -> void:
	if story_popup_log_scroll == null or not is_instance_valid(story_popup_log_scroll):
		return
	update_story_popup_log_text_size()
	var bar := story_popup_log_scroll.get_v_scroll_bar()
	if bar != null and is_instance_valid(bar):
		story_popup_log_scroll.scroll_vertical = int(max(0.0, bar.max_value - bar.page))


func format_story_popup_log_time(unix_time: int) -> String:
	if unix_time <= 0:
		return ""
	var datetime := Time.get_datetime_dict_from_unix_time(unix_time)
	return two_digit_story_log_time(int(datetime.get("hour", 0))) + ":" + two_digit_story_log_time(int(datetime.get("minute", 0))) + ":" + two_digit_story_log_time(int(datetime.get("second", 0)))


func two_digit_story_log_time(value: int) -> String:
	if value < 10:
		return "0" + str(value)
	return str(value)


func story_popup_log_escape_bbcode(value: String) -> String:
	return value.replace("[", "(").replace("]", ")")


func join_story_popup_log_strings(values: Array, separator: String) -> String:
	var output := ""
	for i in range(values.size()):
		if i > 0:
			output += separator
		output += str(values[i])
	return output


func apply_main_cockpit_v2_static_layout() -> void:
	place_control_from_state("log_root", Globals.main_bottom_log_pos, Globals.main_bottom_log_size, true)
	place_control_from_state("main_ai_news_root", Globals.main_ai_news_widget_pos, Globals.main_ai_news_widget_size, true)
	place_control_from_state("event_root", Globals.get_main_event_widget_pos_v2(), Globals.main_right_widget_size, true)
	place_control_from_action_storage("root", Globals.get_main_action_widget_pos_v2(), Globals.main_right_widget_size, true)
	place_control_from_state("todo_root", Globals.get_main_todo_widget_pos_v2(), Globals.main_right_widget_size, true)
	place_control_from_state("ami_report_root", Globals.get_main_player_stats_widget_pos_v2(), Globals.main_right_widget_size, true)

	if port_window_widget != null:
		port_window_widget.position = Globals.main_forward_view_pos
		port_window_widget.size = Globals.main_forward_view_size
		port_window_widget.visible = true


func hide_main_cockpit_v2_legacy_widgets() -> void:
	place_control_from_state("sd", Globals.star_dis_widg_pos, Globals.star_distance_widget_size, false)
	place_control_from_state("drive_root", Globals.eng_widg_pos, Globals.nav_widget_size, false)
	place_control_from_state("coords_root", Globals.map_widg_pos, Globals.nav_widget_size, false)

	if main_command_menu_root != null and is_instance_valid(main_command_menu_root):
		main_command_menu_root.visible = false


func reparent_control(control: Control, new_parent: Node) -> void:
	if control == null or not is_instance_valid(control) or new_parent == null:
		return
	if control.get_parent() == new_parent:
		return
	var old_parent = control.get_parent()
	if old_parent != null:
		old_parent.remove_child(control)
	new_parent.add_child(control)


func place_control_from_state(key: String, pos: Vector2, size: Vector2, visible: bool) -> void:
	if gui_state == null or not gui_state.controls.has(key):
		return
	var control = gui_state.controls[key]
	if control is Control:
		var c := control as Control
		c.position = pos
		c.size = size
		c.custom_minimum_size = size
		c.visible = visible


func place_control_from_action_storage(key: String, pos: Vector2, size: Vector2, visible: bool) -> void:
	if gui_state == null or not gui_state.action_storage.has(key):
		return
	var control = gui_state.action_storage[key]
	if control is Control:
		var c := control as Control
		c.position = pos
		c.size = size
		c.custom_minimum_size = size
		c.visible = visible


func layout_blueprint_widget_for_left_panel(root: Control, pos: Vector2, size: Vector2) -> void:
	if root == null:
		return

	root.position = pos
	root.size = size
	root.custom_minimum_size = size

	set_color_rect_layout("blueprint_bg", Vector2.ZERO, size)
	set_color_rect_layout("blueprint_header_bg", Vector2.ZERO, Vector2(size.x, 25))
	var footer_height := 62.0
	var footer_y = max(size.y - footer_height, 34.0)
	set_color_rect_layout("blueprint_footer_bg", Vector2(0, footer_y), Vector2(size.x, footer_height))

	if gui_state.labels.has("blueprint_header_label") and gui_state.labels["blueprint_header_label"] is Label:
		var header := gui_state.labels["blueprint_header_label"] as Label
		header.position = Vector2(10, 4)
		header.size = Vector2(size.x - 20.0, 18)

	if gui_state.controls.has("blueprint_scroll") and gui_state.controls["blueprint_scroll"] is ScrollContainer:
		var scroll := gui_state.controls["blueprint_scroll"] as ScrollContainer
		scroll.position = Vector2(8, 31)
		scroll.size = Vector2(size.x - 16.0, max(footer_y - 35.0, 32.0))

	if gui_state.labels.has("blueprint_status_label") and gui_state.labels["blueprint_status_label"] is Label:
		var status := gui_state.labels["blueprint_status_label"] as Label
		status.position = Vector2(8, footer_y + 6)
		status.size = Vector2(size.x - 16.0, 24)

	if gui_state.buttons.has("blueprint_build_button") and gui_state.buttons["blueprint_build_button"] is Button:
		var build_button := gui_state.buttons["blueprint_build_button"] as Button
		build_button.position = Vector2(size.x - 82.0, footer_y + 33.0)
		build_button.size = Vector2(74.0, 25.0)


func set_color_rect_layout(key: String, pos: Vector2, size: Vector2) -> void:
	if gui_state == null or not gui_state.color_rects.has(key):
		return
	var rect = gui_state.color_rects[key]
	if rect is ColorRect:
		var color_rect := rect as ColorRect
		color_rect.position = pos
		color_rect.size = size


func layout_tier_map_for_left_panel() -> void:
	if gui_state == null or not gui_state.controls.has("tier_map"):
		return
	var root = gui_state.controls["tier_map"]
	if not (root is Control):
		return

	var panel_size := Globals.main_left_panel_size
	var tier_root := root as Control
	tier_root.position = Vector2.ZERO
	tier_root.size = panel_size
	tier_root.custom_minimum_size = panel_size
	tier_root.clip_contents = true

	set_color_rect_layout("tier_map_back", Vector2.ZERO, panel_size)
	set_color_rect_layout("tier_map_header_back", Vector2.ZERO, Vector2(panel_size.x, 28.0))

	if gui_state.labels.has("tier_map_title") and gui_state.labels["tier_map_title"] is Label:
		var title := gui_state.labels["tier_map_title"] as Label
		title.text = "Sect-Nav"
		title.position = Vector2(10, 4)
		title.size = Vector2(panel_size.x - 20.0, 22.0)

	if gui_state.labels.has("tier_map_info") and gui_state.labels["tier_map_info"] is Label:
		var info := gui_state.labels["tier_map_info"] as Label
		info.visible = false
		info.position = Vector2.ZERO
		info.size = Vector2.ZERO

	if gui_state.labels.has("tier_map_sector") and gui_state.labels["tier_map_sector"] is Label:
		var sector := gui_state.labels["tier_map_sector"] as Label
		sector.visible = false
		sector.position = Vector2.ZERO
		sector.size = Vector2.ZERO

	layout_tier_map_tab_buttons(panel_size)

	if gui_state.controls.has("tier_map_scroll") and gui_state.controls["tier_map_scroll"] is ScrollContainer:
		var scroll := gui_state.controls["tier_map_scroll"] as ScrollContainer
		scroll.position = Vector2(6, 66)
		scroll.size = Vector2(panel_size.x - 12.0, max(panel_size.y - 74.0, 40.0))
		scroll.custom_minimum_size = scroll.size

	var rows: Array = gui_state.labels.get("tier_map_rows", [])
	for row in rows:
		if row is Control:
			var row_control := row as Control
			row_control.custom_minimum_size = Vector2(panel_size.x - 34.0, 22.0)
			row_control.size = Vector2(panel_size.x - 34.0, 22.0)


func layout_tier_map_tab_buttons(panel_size: Vector2) -> void:
	if gui_state == null or not gui_state.buttons.has("tier_map"):
		return
	var tab_gap := 4.0
	var tab_x := 6.0
	var tab_y := 36.0
	var tab_h := 22.0
	var tab_w = max((panel_size.x - 12.0 - tab_gap * float(TIER_MAP_TYPE_TABS.size() - 1)) / float(TIER_MAP_TYPE_TABS.size()), 28.0)
	for i in range(TIER_MAP_TYPE_TABS.size()):
		var tab_id := str(TIER_MAP_TYPE_TABS[i])
		var key := "tab_" + tab_id
		if not gui_state.buttons["tier_map"].has(key):
			continue
		var tab_button = gui_state.buttons["tier_map"][key]
		if tab_button is Control:
			var tab_control := tab_button as Control
			tab_control.position = Vector2(tab_x + (tab_w + tab_gap) * float(i), tab_y)
			tab_control.size = Vector2(tab_w, tab_h)


func _on_main_left_local_map_open() -> void:
	if inv_radar_panel == null or inv_radar_panel.live_map_control == null:
		return
	var local_map = inv_radar_panel.live_map_control
	if local_map.has_method("apply_external_rect"):
		local_map.apply_external_rect(Rect2(Vector2.ZERO, Globals.main_left_panel_size))
	if local_map.has_method("set_clickable_enabled"):
		local_map.set_clickable_enabled(true)
	if map != null and local_map.has_method("refresh_from_packet"):
		local_map.refresh_from_packet(map.build_live_map_scan_packet())


func _on_main_left_local_map_close() -> void:
	if inv_radar_panel == null or inv_radar_panel.live_map_control == null:
		return
	if inv_radar_panel.live_map_control.has_method("set_clickable_enabled"):
		inv_radar_panel.live_map_control.set_clickable_enabled(false)


func _on_main_left_flat_map_open() -> void:
	if full_flat_map_handler == null:
		return
	if full_flat_map_handler.has_method("apply_external_rect"):
		full_flat_map_handler.apply_external_rect(Rect2(Vector2.ZERO, Globals.main_left_panel_size), true)
	refresh_ami_star_chart_from_scan("left_panel_open")


func _on_main_left_flat_map_close() -> void:
	if full_flat_map_handler != null and full_flat_map_handler.has_method("release_expanded_input_capture"):
		full_flat_map_handler.release_expanded_input_capture()


func _on_main_left_tier_map_open() -> void:
	layout_tier_map_for_left_panel()
	connect_tier_map_buttons()
	refresh_tier_map_widget(true)


func _on_main_left_tier_map_close() -> void:
	pass


func _on_main_left_inventory_craft_open() -> void:
	if inventory != null and inventory.has_method("apply_label_inventory_widget_size"):
		inventory.apply_label_inventory_widget_size(Vector2(Globals.main_left_panel_size.x - 16.0, 360.0))
	if inventory != null:
		inventory.refresh_label_inventory_rows()
	refresh_blueprint_widget()


func _on_main_left_inventory_craft_close() -> void:
	pass




# ==========================================================
# A M I   R E P O R T   W I R I N G
# ----------------------------------------------------------
# PlayerStateMainUI is read-only. It displays PlayerState in
# main mode without owning stat mutation.
# ==========================================================
func resolve_ami_report_widget_size() -> Vector2:
	if Globals.main_cockpit_v2_enabled:
		return Globals.main_right_widget_size
	var base_height := 158.0
	if typeof(Globals.todo_widget_size) == TYPE_VECTOR2:
		base_height = clamp(float(Globals.todo_widget_size.y), 148.0, 178.0)
	return Vector2(292.0, base_height)


func resolve_ami_report_widget_pos(todo_widget_pos: Vector2) -> Vector2:
	if Globals.main_cockpit_v2_enabled:
		return Globals.get_main_player_stats_widget_pos_v2()
	var gap := 10.0
	var todo_size := Vector2(300.0, 150.0)
	if typeof(Globals.todo_widget_size) == TYPE_VECTOR2:
		todo_size = Globals.todo_widget_size
	return todo_widget_pos + Vector2(todo_size.x + gap, 0.0)


func setup_player_state_main_ui(reason: String = "") -> void:
	# Summary: Wire AMI Report to live player, inventory, item, and MainMode refs.
	# Early boot may call this before inventory UI is populated, but the object refs
	# already exist and later refreshes will see loaded slot data.
	if player_state_main_ui == null:
		return
	if not player_state_main_ui.has_method("setup"):
		return
	player_state_main_ui.setup(gui_state, player_state, inventory, item_handler, self)
	refresh_ami_report(reason)


func refresh_ami_report(reason: String = "") -> void:
	# Summary: Keep AMI Report refs hot across boot, battle return, save load,
	# and any future rebuilds before asking it to redraw.
	if player_state_main_ui == null:
		return
	if player_state_main_ui.has_method("set_inventory_refs"):
		player_state_main_ui.set_inventory_refs(inventory, item_handler, self)
	if player_state_main_ui.has_method("refresh"):
		player_state_main_ui.refresh(reason)


func update_ami_report(delta: float) -> void:
	if player_state_main_ui == null:
		return
	if player_state_main_ui.has_method("update_if_changed"):
		player_state_main_ui.update_if_changed(delta)


func request_inventory_recovery_use_item(item_id: String, source: String = "") -> Dictionary:
	# Summary: Main-mode endpoint for inventory recovery use.
	# Inventory owns item selection; MainMode owns inventory spend, player stat
	# mutation, refresh, and save.
	var clean_item_id := str(item_id).strip_edges()
	var result := {
		"ok": false,
		"item_id": clean_item_id,
		"source": source,
		"message": "Recovery use failed."
	}

	if clean_item_id == "":
		result["message"] = "Recovery use blocked: no item selected."
		return result

	if inventory == null:
		result["message"] = "Recovery use blocked: inventory unavailable."
		return result

	if player_state == null:
		result["message"] = "Recovery use blocked: player state unavailable."
		return result

	if not inventory.has_method("count_item_anywhere") or int(inventory.count_item_anywhere(clean_item_id)) <= 0:
		result["message"] = "Recovery use blocked: item not found in inventory."
		return result

	var item_data := {}
	if item_handler != null and item_handler.has_method("get_item_data"):
		item_data = item_handler.get_item_data(clean_item_id)

	var recovery_group := resolve_inventory_recovery_group(clean_item_id, item_data)
	match recovery_group:
		"repair":
			return apply_ami_report_hull_repair(clean_item_id, item_data, result)
		"recharge":
			return apply_ami_report_energy_recharge(clean_item_id, item_data, result)
		"shield_repair":
			return apply_ami_report_shield_patch(clean_item_id, item_data, result)

	result["message"] = "Recovery use blocked: unsupported recovery item."
	return result


func request_ami_report_use_item(item_id: String, source: String = "") -> Dictionary:
	# Summary: AMI Report no longer consumes recovery supplies in main mode.
	var clean_item_id := str(item_id).strip_edges()
	return {
		"ok": false,
		"item_id": clean_item_id,
		"source": source,
		"message": "Recovery items now live in Inventory > RECOV."
	}


func resolve_inventory_recovery_group(item_id: String, item_data: Dictionary) -> String:
	var group := str(item_data.get("consumable_group", "")).strip_edges().to_lower()
	var subtype := str(item_data.get("subtype", "")).strip_edges().to_lower()
	if group in ["repair", "shield_repair", "recharge"]:
		return group
	if subtype in ["repair", "shield_repair", "recharge"]:
		return subtype
	if item_data.has("shield_repair_amount"):
		return "shield_repair"
	if item_data.has("energy_restore_amount") or item_data.has("recharge_amount"):
		return "recharge"
	if item_data.has("hull_restore_amount") or item_data.has("heal_amount") or item_data.has("repair_amount"):
		return "repair"
	if item_id in ["repair_kit", "smart_guy_patch_cell"]:
		return "repair"
	if item_id in ["shield_patch_cell", "patch_cell"]:
		return "shield_repair"
	if item_id == "recharge_kit":
		return "recharge"
	return ""


func apply_ami_report_hull_repair(item_id: String, item_data: Dictionary, result: Dictionary) -> Dictionary:
	var hull_current := float(player_state.hull_current)
	var hull_max := float(player_state.hull_max)
	if hull_max <= 0.0:
		result["message"] = "Recovery use blocked: hull system unavailable."
		return result
	if hull_current >= hull_max:
		result["message"] = "Recovery use blocked: hull is already stable."
		return result

	var amount := float(item_data.get("hull_restore_amount", item_data.get("repair_amount", item_data.get("heal_amount", 25.0))))
	if amount <= 0.0:
		result["message"] = "Recovery use blocked: item has no hull repair value."
		return result

	if not inventory.consume_item(item_id, 1):
		result["message"] = "Recovery use failed: item consume failed."
		return result

	player_state.repair_hull(amount)
	result["ok"] = true
	result["message"] = "Recovery applied: hull +" + str(amount) + "."
	refresh_ami_report_after_field_item("repair_hull")
	return result


func apply_ami_report_energy_recharge(item_id: String, item_data: Dictionary, result: Dictionary) -> Dictionary:
	var energy_current := float(player_state.energy_current)
	var energy_max := float(player_state.energy_max)
	if energy_max <= 0.0:
		result["message"] = "Recovery use blocked: energy system unavailable."
		return result
	if energy_current >= energy_max:
		result["message"] = "Recovery use blocked: energy reserves are already full."
		return result

	var amount := float(item_data.get("energy_restore_amount", 100.0))
	if amount <= 0.0:
		result["message"] = "Recovery use blocked: item has no energy value."
		return result

	if not inventory.consume_item(item_id, 1):
		result["message"] = "Recovery use failed: item consume failed."
		return result

	var restore_result := {}
	if player_state.has_method("restore_energy"):
		restore_result = player_state.restore_energy(amount)
	else:
		player_state.energy_current = min(float(player_state.energy_current) + amount, float(player_state.energy_max))
		restore_result = {"status": "success", "energy_restored": amount}

	if str(restore_result.get("status", "success")) != "success":
		result["message"] = "Recovery use blocked: " + str(restore_result.get("blocked_reason", "unknown"))
		refresh_ami_report_after_field_item("recharge_blocked_after_consume")
		return result

	result["ok"] = true
	result["message"] = "Recovery applied: energy +" + str(restore_result.get("energy_restored", amount)) + "."
	refresh_ami_report_after_field_item("recharge_energy")
	return result


func apply_ami_report_shield_patch(item_id: String, item_data: Dictionary, result: Dictionary) -> Dictionary:
	var shield_current := float(player_state.shield_hp_current)
	var shield_max := float(player_state.shield_hp_max)
	if shield_max <= 0.0:
		result["message"] = "Recovery use blocked: no active shield system to patch."
		return result
	if shield_current <= 0.0:
		result["message"] = "Recovery use blocked: shield is broken."
		return result
	if shield_current >= shield_max:
		result["message"] = "Recovery use blocked: shield is already stable."
		return result

	var amount := float(item_data.get("shield_repair_amount", item_data.get("repair_amount", 30.0)))
	if amount <= 0.0:
		result["message"] = "Recovery use blocked: item has no shield repair value."
		return result

	if not inventory.consume_item(item_id, 1):
		result["message"] = "Recovery use failed: item consume failed."
		return result

	var patch_result := {}
	if player_state.has_method("repair_shield"):
		patch_result = player_state.repair_shield(amount)
	else:
		player_state.shield_hp_current = min(float(player_state.shield_hp_current) + amount, float(player_state.shield_hp_max))
		patch_result = {"status": "success", "shield_repaired": amount}

	if str(patch_result.get("status", "success")) != "success":
		result["message"] = "Recovery use blocked: " + str(patch_result.get("blocked_reason", "unknown"))
		refresh_ami_report_after_field_item("shield_patch_blocked_after_consume")
		return result

	result["ok"] = true
	result["message"] = "Recovery applied: shield +" + str(patch_result.get("shield_repaired", amount)) + "."
	refresh_ami_report_after_field_item("patch_shield")
	return result


func refresh_ami_report_after_field_item(reason: String = "field_item") -> void:
	# Summary: Refresh inventory-dependent UI and persist AMI field-kit use.
	if inventory != null and inventory.has_method("notify_inventory_changed"):
		inventory.notify_inventory_changed("ami_report_" + reason)

	if action_manager != null and action_manager.has_method("refresh_actions_from_inventory"):
		action_manager.refresh_actions_from_inventory()

	refresh_ami_report("ami_report_" + reason)
	save_ami_report_field_item_state(reason)


func save_ami_report_field_item_state(reason: String = "field_item") -> void:
	if save_manager == null or not save_manager.has_method("save_universe"):
		return

	var saved_ok := bool(save_manager.save_universe(
		star_field,
		map,
		space_objects,
		inventory,
		enemy_handler,
		npc_handler,
		beacons,
		game_event_handler,
		planets,
		player_state
	))

	if Globals.print_priority_3:
		print("[AMI_REPORT_FIELD_SAVE] reason=", reason, " saved_ok=", saved_ok)


# ==========================================================
# A M I   S T A R   C H A R T
# ----------------------------------------------------------
# Separate full-flat-map widget. It owns its own last-scan
# snapshot through FullFlatMapHandler and does not mutate
# story, save, events, or autopilot.
# ==========================================================
func resolve_ami_star_chart_widget_size() -> Vector2:
	# AMI Star Chart manual compact size.
	# Edit in Globals.gd:
	# var ami_star_chart_widget_size := Vector2(300, 160)
	var global_size = Globals.get("ami_star_chart_widget_size")
	if typeof(global_size) == TYPE_VECTOR2:
		return global_size
	return Vector2(300, 160)


func resolve_ami_star_chart_widget_pos() -> Vector2:
	# AMI Star Chart manual compact position.
	# Edit in Globals.gd:
	# var ami_star_chart_widget_pos := Vector2(490, 280)
	var widget_size := resolve_ami_star_chart_widget_size()
	var global_pos = Globals.get("ami_star_chart_widget_pos")
	var desired_pos := Vector2(490, 280)

	if typeof(global_pos) == TYPE_VECTOR2:
		desired_pos = global_pos

	# Keep a tiny safety clamp so a bad number cannot fully lose the widget.
	var viewport_size := Vector2(1280, 720)
	if get_viewport() != null:
		viewport_size = get_viewport().get_visible_rect().size

	var max_x = max(0.0, viewport_size.x - widget_size.x - 8.0)
	var max_y = max(0.0, viewport_size.y - widget_size.y - 8.0)
	var final_pos := Vector2(
		clamp(desired_pos.x, 8.0, max_x),
		clamp(desired_pos.y, 8.0, max_y)
	)

	print("[AMI_STAR_CHART_DEBUG] USING_SIMPLE_GLOBALS_XY desired=", desired_pos, " final=", final_pos, " size=", widget_size, " viewport=", viewport_size)
	return final_pos


func resolve_ami_star_chart_expanded_top_y() -> float:
	# Keep the top HUD/log band visible while the chart expands.
	var top_y := 170.0
	if typeof(Globals.log_widg_pos) == TYPE_VECTOR2 and typeof(Globals.log_widget_size) == TYPE_VECTOR2:
		top_y = max(top_y, Globals.log_widg_pos.y + Globals.log_widget_size.y + 8.0)
	return top_y


func build_ami_star_chart_widget(reason: String = "manual") -> void:
	if gui_state == null or gui_builder == null:
		print("[AMI_STAR_CHART_DEBUG] build blocked reason=", reason, " gui_state=", gui_state, " gui_builder=", gui_builder)
		return

	if gui_state.controls.has("ami_star_chart_root") and gui_state.controls["ami_star_chart_root"] is Control:
		var existing_root: Control = gui_state.controls["ami_star_chart_root"] as Control
		existing_root.position = resolve_ami_star_chart_widget_pos()
		existing_root.size = resolve_ami_star_chart_widget_size()
		existing_root.visible = true
		existing_root.z_index = 360
		existing_root.move_to_front()
		print("[AMI_STAR_CHART_DEBUG] build skipped existing reason=", reason, " pos=", existing_root.position, " size=", existing_root.size, " parent=", existing_root.get_parent())
		setup_ami_star_chart_handler("existing_" + reason)
		return

	var pos := resolve_ami_star_chart_widget_pos()
	var widget_size := resolve_ami_star_chart_widget_size()
	print("[AMI_STAR_CHART_DEBUG] build request reason=", reason, " pos=", pos, " size=", widget_size)

	var chart_root = null
	if gui_builder.has_method("build_ami_star_chart_widget"):
		chart_root = gui_builder.build_ami_star_chart_widget(gui_state, pos, widget_size)
	else:
		print("[AMI_STAR_CHART_DEBUG] builder missing build_ami_star_chart_widget")
		return

	if chart_root == null:
		print("[AMI_STAR_CHART_DEBUG] builder returned null")
		return

	if chart_root.get_parent() == null:
		add_child(chart_root)

	chart_root.visible = true
	chart_root.z_index = 360
	chart_root.move_to_front()

	print("[AMI_STAR_CHART_DEBUG] after_build_add_child root=", chart_root, " pos=", chart_root.position, " size=", chart_root.size, " visible=", chart_root.visible, " tree_visible=", chart_root.is_visible_in_tree(), " parent=", chart_root.get_parent(), " z=", chart_root.z_index)

	setup_ami_star_chart_handler("build_" + reason)


func setup_ami_star_chart_handler(reason: String = "setup") -> void:
	if full_flat_map_handler == null:
		print("[AMI_STAR_CHART_DEBUG] setup blocked missing full_flat_map_handler reason=", reason)
		return
	if gui_state == null:
		print("[AMI_STAR_CHART_DEBUG] setup blocked missing gui_state reason=", reason)
		return

	var root = gui_state.controls.get("ami_star_chart_root", null)
	var scroll = gui_state.controls.get("ami_star_chart_scroll", null)
	var canvas = gui_state.controls.get("ami_star_chart_canvas", null)
	var expand_button = gui_state.buttons.get("ami_star_chart_expand_button", null)
	var status_label = gui_state.labels.get("ami_star_chart_status", null)

	var log_text_node: Node = null
	if gui_state.log_storage.has("log_text") and gui_state.log_storage["log_text"] is Node:
		log_text_node = gui_state.log_storage["log_text"]

	print("[AMI_STAR_CHART_DEBUG] setup reason=", reason, " root=", root, " scroll=", scroll, " canvas=", canvas, " expand_button=", expand_button, " status_label=", status_label, " log_text_node=", log_text_node)

	if full_flat_map_handler.has_method("setup"):
		full_flat_map_handler.setup(gui_state, {
			"root": root,
			"scroll": scroll,
			"canvas": canvas,
			"expand_button": expand_button,
			"status_label": status_label,
			"log_node": log_text_node,
			"compact_rect": Rect2(resolve_ami_star_chart_widget_pos(), resolve_ami_star_chart_widget_size()),
			"expanded_top_reserved_y": resolve_ami_star_chart_expanded_top_y(),
			"expanded_padding": 18.0
		})


func connect_ami_star_chart_scan_signal(reason: String = "connect") -> void:
	if action_manager == null:
		print("[AMI_STAR_CHART_DEBUG] scan signal blocked missing action_manager reason=", reason)
		return
	if not action_manager.has_signal("scan_completed"):
		print("[AMI_STAR_CHART_DEBUG] action_manager missing scan_completed signal reason=", reason)
		return
	if not action_manager.scan_completed.is_connected(_on_action_scan_completed_for_star_chart):
		action_manager.scan_completed.connect(_on_action_scan_completed_for_star_chart)
		print("[AMI_STAR_CHART_DEBUG] scan_completed connected reason=", reason)


func _on_action_scan_completed_for_star_chart(scan_packet: Dictionary = {}) -> void:
	var started_ms := Time.get_ticks_msec()
	print("[AMI_STAR_CHART_DEBUG] scan_completed received packet=", scan_packet)
	refresh_ami_star_chart_from_scan("scan_completed")
	request_main_ai_scan_commentary(scan_packet, "scan_completed")
	print_main_mode_perf("ami_star_chart scan_completed listener", started_ms)


func request_main_ai_scan_commentary(scan_packet: Dictionary, reason: String = "scan_completed") -> void:
	if main_ai == null or not is_instance_valid(main_ai):
		return
	if not main_ai.has_method("request_commentary"):
		return

	var awareness = scan_packet.get("enemy_awareness", {})
	if typeof(awareness) != TYPE_DICTIONARY:
		return
	if int(awareness.get("found_enemy_count", awareness.get("enemy_count", 0))) <= 0:
		return

	main_ai.request_commentary("scan_enemy_awareness", {
		"scene": "main_mode",
		"commentary_source": "action_manager.scan_completed",
		"reason": reason,
		"sector": str(scan_packet.get("sector_pos", Globals.sector_pos)),
		"local": str(scan_packet.get("local_pos", Globals.local_pos)),
		"universe": str(Globals.active_universe_display_name),
		"enemy_awareness": awareness
	}, reason)


func connect_mining_visual_signal(reason: String = "connect") -> void:
	if action_manager == null:
		print("[MINING_VISUAL_DEBUG] connect blocked missing action_manager reason=", reason)
		return
	if not action_manager.has_signal("mining_visual_queued"):
		print("[MINING_VISUAL_DEBUG] action_manager missing mining_visual_queued signal reason=", reason)
		return
	if not action_manager.mining_visual_queued.is_connected(_on_action_mining_visual_queued):
		action_manager.mining_visual_queued.connect(_on_action_mining_visual_queued)
		print("[MINING_VISUAL_DEBUG] mining_visual_queued connected reason=", reason)

	if action_manager.has_signal("mining_completed"):
		if not action_manager.mining_completed.is_connected(_on_action_mining_completed):
			action_manager.mining_completed.connect(_on_action_mining_completed)
			print("[MINING_GAIN_FEED] mining_completed connected reason=", reason)


func _on_action_mining_visual_queued(packet: Dictionary = {}) -> void:
	print("[MINING_VISUAL_DEBUG] queued packet=", packet)

	if port_window_widget != null and port_window_widget.has_method("queue_mining_visual"):
		port_window_widget.queue_mining_visual(packet)

	if port_window_backdrop != null and port_window_backdrop.has_method("queue_mining_visual"):
		port_window_backdrop.queue_mining_visual(packet)


func _on_action_mining_completed(packet: Dictionary = {}) -> void:
	if mining_gain_feed == null or not is_instance_valid(mining_gain_feed):
		setup_mining_gain_feed("mining_completed_rebuild")
	if mining_gain_feed != null and is_instance_valid(mining_gain_feed) and mining_gain_feed.has_method("queue_mining_rewards"):
		mining_gain_feed.queue_mining_rewards(packet)


func connect_todo_completion_signals(reason: String = "setup_todo") -> void:
	if event_handler == null:
		print("[MINING_GAIN_FEED] craft signal blocked missing event_handler reason=", reason)
		return
	if not event_handler.has_signal("craft_completed"):
		print("[MINING_GAIN_FEED] event_handler missing craft_completed signal reason=", reason)
		return
	if not event_handler.craft_completed.is_connected(_on_todo_craft_completed):
		event_handler.craft_completed.connect(_on_todo_craft_completed)
		print("[MINING_GAIN_FEED] craft_completed connected reason=", reason)


func _on_todo_craft_completed(packet: Dictionary = {}) -> void:
	if mining_gain_feed == null or not is_instance_valid(mining_gain_feed):
		setup_mining_gain_feed("craft_completed_rebuild")
	if mining_gain_feed != null and is_instance_valid(mining_gain_feed) and mining_gain_feed.has_method("queue_craft_rewards"):
		mining_gain_feed.queue_craft_rewards(packet)


func refresh_ami_star_chart_from_scan(reason: String = "scan") -> void:
	var started_ms := Time.get_ticks_msec()
	if full_flat_map_handler == null:
		print("[AMI_STAR_CHART_DEBUG] refresh blocked missing handler reason=", reason)
		return
	if map == null or not map.has_method("build_full_flat_map_packet"):
		print("[AMI_STAR_CHART_DEBUG] refresh blocked map missing build_full_flat_map_packet reason=", reason, " map=", map)
		return

	var packet: Dictionary = map.build_full_flat_map_packet(reason)
	var markers = packet.get("markers", [])
	var marker_count = markers.size() if typeof(markers) == TYPE_ARRAY else -1
	print("[AMI_STAR_CHART_DEBUG] refresh_from_scan reason=", reason, " marker_count=", marker_count)

	full_flat_map_handler.refresh_from_scan(packet)
	print_main_mode_perf("refresh_ami_star_chart_from_scan reason=" + reason + " markers=" + str(marker_count), started_ms)


func print_main_mode_perf(label: String, started_ms: int) -> void:
	var elapsed_ms := Time.get_ticks_msec() - started_ms
	if elapsed_ms >= MAIN_MODE_PERF_WARN_MS:
		print("[MAIN_MODE_PERF] ", label, " | ", elapsed_ms, "ms")


# ==========================================================
# 🧱 BUILD: GUI SYSTEM
# ----------------------------------------------------------
# Creates:
# - GUI state (data storage)
# - Controller (logic handler)
# - Builder (UI construction)
# ==========================================================
func build_gui_system() -> void:
	# Summary: Build the shared GUI state, controller, builder, and starter widgets.
	if Globals.print_priority_3:
		print("Building main GUI system.")

	# -----------------------------
	# STATE (data backbone)
	# -----------------------------
	gui_state = WidgetsState5.new()
	add_child(gui_state)

	# -----------------------------
	# CONTROLLER (interaction layer)
	# -----------------------------
	gui_controller = WidgetsController5.new()
	gui_controller.state = gui_state
	add_child(gui_controller)

	# -----------------------------
	# BUILDER (visual creation)
	# -----------------------------
	gui_builder = WidgetsBuilder5.new()
	gui_builder.state = gui_state
	gui_builder.controller = gui_controller
	add_child(gui_builder)

	# -----------------------------
	# LOG WIDGET
	# -----------------------------
	var log_header_h := 25
	var log_body_h := int(Globals.log_widget_size.y) - log_header_h
	var c = gui_builder._create_log_root(
		Globals.log_widg_pos,
		int(Globals.log_widget_size.x),
		log_header_h,
		log_body_h
	)
	gui_builder._create_log_body(c, log_header_h, int(Globals.log_widget_size.x), log_body_h)

	# Initial log message
	gui_state.log_storage["log_text"].text = "Loading ...."

	add_child(c)

	var todo_widget_pos := Globals.get_stacked_todo_pos()
	gui_builder.build_todo_widget(gui_state, todo_widget_pos)
	add_child(gui_state.controls["todo_root"])

	var ami_report_widget_pos := resolve_ami_report_widget_pos(todo_widget_pos)
	var ami_report_widget_size := resolve_ami_report_widget_size()
	var ami_report_widget = gui_builder.build_ami_report_widget(gui_state, ami_report_widget_pos, ami_report_widget_size)
	if ami_report_widget != null:
		add_child(ami_report_widget)

	build_ami_star_chart_widget("build_gui_system")

	var event_widget_pos := Globals.get_event_widget_pos()
	gui_builder.build_event_widget(gui_state, event_widget_pos)
	add_child(gui_state.controls["event_root"])

	var blueprint_widget_pos := Globals.get_blueprint_widget_pos()
	gui_builder.build_blueprint_widget(gui_state, blueprint_widget_pos, Globals.blueprint_widget_size)
	add_child(gui_state.controls["blueprint_root"])

	build_port_window_widget()
	build_port_window_backdrop()
	build_main_ai_news_widget("build_gui_system")
	setup_mining_gain_feed("build_gui_system")
	
	
	
	
	# ==========================================================
	# DECORATIVE LIVING OVERLAYS
	# ----------------------------------------------------------
	# These overlays are visual-only.
	# They should not block buttons because DecorativeUI sets
	# mouse_filter = MOUSE_FILTER_IGNORE.
	# ==========================================================
	decorative_ui.create_pulse_overlay(
		Globals.log_widg_pos,
		Globals.log_widget_size,
		"log_living_overlay",
		Color(0.0, 0.75, 1.0, 0.12)
	)

	decorative_ui.create_pulse_overlay(
		Globals.action_pos,
		Globals.action_widget_size,
		"actions_living_overlay",
		Color(0.0, 1.0, 0.45, 0.10)
	)

	decorative_ui.create_pulse_overlay(
		todo_widget_pos,
		Globals.todo_widget_size,
		"todo_living_overlay",
		Color(1.0, 0.85, 0.15, 0.10)
	)

	decorative_ui.create_pulse_overlay(
		event_widget_pos,
		Globals.event_widget_size,
		"event_living_overlay",
		Color(0.35, 0.85, 1.0, 0.10)
	)

	decorative_ui.create_pulse_overlay(
		blueprint_widget_pos,
		Globals.blueprint_widget_size,
		"blueprint_living_overlay",
		Color(0.75, 0.95, 0.35, 0.10)
	)

	decorative_ui.create_pulse_overlay(
		Globals.get_port_window_widget_pos(),
		Globals.port_window_widget_size,
		"port_window_living_overlay",
		Color(0.20, 0.75, 1.0, 0.08)
	)
	
	decorative_ui.create_pulse_overlay(
		Globals.inv_i_widg_pos,
		Globals.inventory_widget_size,
		"inventory_living_overlay",
		Color(0.4, 0.85, 0.15, 0.10)
	)

	decorative_ui.create_pulse_overlay(
		Globals.live_map_widg_pos,
		Globals.inventory_widget_size,
		"radar_living_overlay",
		Color(0.35, 0.85, 1.0, 0.10)
	)
	
	decorative_ui.create_pulse_overlay(
		Globals.star_dis_widg_pos,
		Vector2(
			Globals.star_distance_widget_size.x,
			Globals.star_distance_widget_size.y + Globals.stacked_widget_gap + Globals.nav_widget_size.y
		),
		"top_systems_living_overlay",
		Color(0.9, 0.85, 0.9, 0.1)
	)
	decorative_ui.set_pulse_overlays_visible(
		Globals.show_decorative_overlays
		)
	# ==========================================================
	# ⚙️ BUILD: ACTION SYSTEM
	# ----------------------------------------------------------
	# Handles:
	# - Action UI
	# - Action routing (scan, etc)
	# ==========================================================
func build_action_system():
	if Globals.debug_heat_1:
		if Globals.print_priority_2:
			print("MAIN BEFORE SETUP beacons = ", beacons)
		if Globals.print_priority_2:
			print("MAIN BEFORE SETUP space_objects = ", space_objects)
		
	energy_handler = EnergyHandler.new()
	energy_handler.name = "EnergyHandler"
	
	add_child(energy_handler)

	energy_handler.setup(
		gui_state,
		100.0, # start energy
		100.0, # max energy
		10.0   # recharge per second
	)

	if Globals.print_priority_2:
		print("EnergyHandler created.")
	if Globals.print_priority_3:
		print("Energy current: ", energy_handler.current_energy)
	if Globals.print_priority_3:
		print("Energy max: ", energy_handler.max_energy)
	if Globals.print_priority_3:
		print("Energy expected use: ", energy_handler.expected_use)

	# Setup action manager dependencies
	action_manager.setup(gui_state, map, star_field, space_objects, beacons,planets, inventory,save_manager,auto_pilot,event_handler,enemy_handler,npc_handler,energy_handler,npc_scene_bridge,battle_v2_bridge)
	gui_state.action_manager = action_manager
	connect_ami_star_chart_scan_signal("build_action_system")
	connect_mining_visual_signal("build_action_system")

	# Build UI root
	var action_root = action_manager.create_action_root(Globals.action_pos)

	action_manager.create_action_background(action_root)
	action_manager._create_action_header(action_root)
	action_manager._create_action_scroll_body(action_root)

	add_child(action_root)
	
	
# ==================================================
# ⚡ CREATE ENERGY HANDLER
# --------------------------------------------------
# Step 2 only creates and initializes the handler.
# Nothing is using it yet.
# ==================================================
	



# ==========================================================
# 🧩 BUILD: STATIC SYSTEMS
# ----------------------------------------------------------
# Systems that do not depend on save/load state
# ==========================================================
func build_static_systems() -> void:

	# Build core UI panels
	build_systems()

	# Connect engine to GUI state
	eng.w = gui_state
	gui_state.map = map
	gui_state.engine = eng

	# Add core nodes to scene
	add_child(star_field)
	add_child(save_manager)
	add_child(npc_handler)



# ==========================================================
# 🎒 BUILD: INVENTORY SYSTEM
# ==========================================================
func build_inventory_system() -> void:
	# Summary: Build inventory data, legacy slot data, and the new label inventory widget.
	if Globals.print_priority_3:
		print("Building inventory system.")

	add_child(item_handler)

	add_child(inventory)

	# Setup dependencies
	inventory.setup(item_handler)
	if inventory.has_method("set_recovery_use_owner"):
		inventory.set_recovery_use_owner(self)

	# Build UI layouts
	inventory.buildit(Globals.inv_i_widg_pos, 10)
	inventory.build_drone_bay(Globals.inv_d_widg_pos, 10)

	# Connect shared state AFTER build
	inventory.state = gui_state
	inventory.item_handler = item_handler
	inventory.build_label_inventory_widget(Globals.inv_i_widg_pos)
	gui_state.inventory = inventory

	

# ==========================================================
# 🎁 LOAD STARTING INVENTORY
# ==========================================================

func setup_todo():
	
	add_child(event_handler)

	event_handler.state = gui_state
	
	event_handler.setup(map,star_field,space_objects,beacons,planets,inventory,gui_state,auto_pilot,save_manager,gui_builder,action_manager,enemy_handler,energy_handler)
	gui_state.task_manager = event_handler
	connect_todo_completion_signals("setup_todo")
	
	
	
	
func setup_blueprint_widget_controller() -> void:
	# Pass 3 extraction:
	# MainMode still owns boot order, but blueprint inventory watching and
	# blueprint packet/widget refresh now live in BlueprintWidgetController.gd.
	if blueprint_widget_controller == null:
		blueprint_widget_controller = BlueprintWidgetControllerScript.new()

	blueprint_widget_controller.setup(
		self,
		gui_state,
		gui_builder,
		inventory,
		item_handler,
		action_manager,
		event_handler,
		BLUEPRINT_INVENTORY_POLL_INTERVAL
	)


func connect_blueprint_widget_refs() -> void:
	setup_blueprint_widget_controller()
	blueprint_widget_controller.connect_blueprint_widget_refs()


func connect_inventory_change_refresh() -> void:
	setup_blueprint_widget_controller()
	blueprint_widget_controller.connect_inventory_change_refresh()


func _on_inventory_changed(reason: String = "changed") -> void:
	setup_blueprint_widget_controller()
	blueprint_widget_controller._on_inventory_changed(reason)


func queue_blueprint_widget_refresh(reason: String = "changed") -> void:
	setup_blueprint_widget_controller()
	blueprint_widget_controller.queue_blueprint_widget_refresh(reason)


func process_blueprint_inventory_refresh(delta: float) -> void:
	setup_blueprint_widget_controller()
	blueprint_widget_controller.process_blueprint_inventory_refresh(delta)


func refresh_inventory_dependent_widgets() -> void:
	setup_blueprint_widget_controller()
	blueprint_widget_controller.refresh_inventory_dependent_widgets()


func build_inventory_signature() -> String:
	setup_blueprint_widget_controller()
	return blueprint_widget_controller.build_inventory_signature()


func append_inventory_container_signature(parts: Array, container: Dictionary, prefix: String) -> void:
	setup_blueprint_widget_controller()
	blueprint_widget_controller.append_inventory_container_signature(parts, container, prefix)


func refresh_blueprint_widget() -> void:
	setup_blueprint_widget_controller()
	blueprint_widget_controller.refresh_blueprint_widget()


func restore_selected_blueprint_after_refresh(packet: Dictionary) -> void:
	setup_blueprint_widget_controller()
	blueprint_widget_controller.restore_selected_blueprint_after_refresh(packet)


func collect_inventory_blueprint_packets() -> Array:
	setup_blueprint_widget_controller()
	return blueprint_widget_controller.collect_inventory_blueprint_packets()


func collect_blueprint_counts_from_container(container: Dictionary, blueprint_counts: Dictionary) -> void:
	setup_blueprint_widget_controller()
	blueprint_widget_controller.collect_blueprint_counts_from_container(container, blueprint_counts)


func is_craft_blueprint_item(item_data: Dictionary) -> bool:
	setup_blueprint_widget_controller()
	return blueprint_widget_controller.is_craft_blueprint_item(item_data)


func build_blueprint_widget_packet(blueprint_id: String, owned_count: int) -> Dictionary:
	setup_blueprint_widget_controller()
	return blueprint_widget_controller.build_blueprint_widget_packet(blueprint_id, owned_count)


func read_blueprint_cost_map(item_data: Dictionary) -> Dictionary:
	setup_blueprint_widget_controller()
	return blueprint_widget_controller.read_blueprint_cost_map(item_data)


func read_blueprint_result_packet(item_data: Dictionary) -> Dictionary:
	setup_blueprint_widget_controller()
	return blueprint_widget_controller.read_blueprint_result_packet(item_data)


func build_blueprint_tooltip(display_name: String, cost: Dictionary, cost_names: Dictionary, result_name: String, result_count: int) -> String:
	setup_blueprint_widget_controller()
	return blueprint_widget_controller.build_blueprint_tooltip(display_name, cost, cost_names, result_name, result_count)


func add_start_up_debug_events():
	pass
	#event_handler.add_event(
		#"decoding encription...",
		#1,
		#"get_mail",
		#{ "mail": "New_Mail" }
	#)


	

func load_starting_inventory() -> void:
	inventory.give_starter_items()
	
	

	# NOTE:
	# Left intentionally commented to avoid slot overwrite
	# inventory.set_slot_item("row 0 / col0", "scout_drone", 1)


func validate_starter_inventory_for_demo_save() -> void:
	# Export-safe starter inventory migration.
	# Important: do not trust the migration marker by itself. A bad first exported
	# boot can write the marker while inventory insertion failed, then block all
	# future repair attempts. Only skip when the live inventory is already valid.
	if inventory == null or save_manager == null:
		print("[EXPORT_ITEM_REPAIR_BLOCKED] missing inventory or save_manager")
		return

	var required_item_ids := [
		"scan_module_mk1",
		"drone_controller_mk1",
		"miner_drone_mk1"
	]

	var migration_already_marked := false
	if save_manager.has_method("has_runtime_migration"):
		migration_already_marked = save_manager.has_runtime_migration(STARTER_INVENTORY_MIGRATION_ID)

	var item_db_count := debug_get_item_db_count()
	var item_db_ready := debug_required_items_exist(required_item_ids)

	# If the exported item DB is not ready, any repair attempt would be rejected
	# by Inventory5.set_slot_item()/add_item(). Do not mark the migration here.
	if not item_db_ready:
		print("[EXPORT_ITEM_REPAIR_BLOCKED]",
			" reason=item_db_not_ready",
			" migration_marked=", migration_already_marked,
			" item_db_count=", item_db_count,
			" missing_required=", debug_collect_missing_item_ids(required_item_ids),
			" save_path=", debug_get_save_path(),
			" user_dir=", OS.get_user_data_dir()
		)
		return

	var inventory_has_any := false
	if inventory.has_method("has_any_items"):
		inventory_has_any = inventory.has_any_items()

	var missing_required := debug_collect_missing_inventory_ids(required_item_ids)
	var live_inventory_valid := inventory_has_any and missing_required.is_empty()

	if migration_already_marked and live_inventory_valid:
		print("[EXPORT_ITEM_REPAIR_SKIP]",
			" reason=migration_marked_and_inventory_valid",
			" item_db_count=", item_db_count,
			" save_path=", debug_get_save_path(),
			" user_dir=", OS.get_user_data_dir()
		)
		return

	var repaired := false
	var repair_reason := "already_valid"

	if not inventory_has_any:
		load_starting_inventory()
		repaired = true
		repair_reason = "empty_inventory_or_bad_export_save"
	else:
		if not inventory.has_item_anywhere("scan_module_mk1"):
			repaired = inventory.add_item("scan_module_mk1", 1) or repaired
			repair_reason = "missing_scan_module"

		if not inventory.has_item_anywhere("drone_controller_mk1"):
			repaired = inventory.add_item("drone_controller_mk1", 1) or repaired
			repair_reason = "missing_drone_controller"

		if not inventory.has_item_anywhere("miner_drone_mk1"):
			inventory.set_drone_slot_item(inventory.make_drone_slot_name(1), "miner_drone_mk1", 1)
			repaired = inventory.has_item_anywhere("miner_drone_mk1") or repaired
			repair_reason = "missing_miner_drone"

	var final_missing_required := debug_collect_missing_inventory_ids(required_item_ids)
	var final_inventory_has_any := false
	if inventory.has_method("has_any_items"):
		final_inventory_has_any = inventory.has_any_items()

	var repair_valid := final_inventory_has_any and final_missing_required.is_empty()

	# Save only after proving the repair made a valid live inventory.
	if repaired and repair_valid and save_manager.has_method("save_inventory_section_from_data"):
		save_manager.save_inventory_section_from_data(inventory.get_save_data())

	# Mark migration only after the live inventory is valid. This prevents one bad
	# exported boot from permanently poisoning user://save/universe_save.json.
	if repair_valid and save_manager.has_method("mark_runtime_migration"):
		save_manager.mark_runtime_migration(STARTER_INVENTORY_MIGRATION_ID, {
			"repaired": repaired,
			"reason": repair_reason,
			"migration_was_already_marked": migration_already_marked,
			"item_db_count": item_db_count,
			"has_scan_module": inventory.has_item_anywhere("scan_module_mk1"),
			"has_drone_controller": inventory.has_item_anywhere("drone_controller_mk1"),
			"has_miner_drone": inventory.has_item_anywhere("miner_drone_mk1"),
			"user_dir": OS.get_user_data_dir()
		})

	print("[EXPORT_ITEM_REPAIR_DONE]",
		" repaired=", repaired,
		" valid=", repair_valid,
		" reason=", repair_reason,
		" migration_was_marked=", migration_already_marked,
		" item_db_count=", item_db_count,
		" final_missing_required=", final_missing_required,
		" save_path=", debug_get_save_path(),
		" user_dir=", OS.get_user_data_dir()
	)


func grant_orbit_starter_items_once() -> void:
	# Existing saves receive the authored Orbit test kit once. The migration marker
	# prevents consumed tools from being restored on later boots.
	if inventory == null or save_manager == null:
		print("[ORBIT_STARTER_ITEMS_BLOCKED] missing inventory or save_manager")
		return
	if save_manager.has_method("has_runtime_migration") and save_manager.has_runtime_migration(ORBIT_STARTER_INVENTORY_MIGRATION_ID):
		return

	var starter_item_ids := [
		"planetary_resource_rover",
		"planet_recovery_launcher",
		"planetary_resource_rover_blueprint",
		"planet_recovery_launcher_blueprint"
	]
	if not debug_required_items_exist(starter_item_ids):
		print("[ORBIT_STARTER_ITEMS_BLOCKED] missing item data=", debug_collect_missing_item_ids(starter_item_ids))
		return

	var added_item_ids := []
	for item_id in starter_item_ids:
		if inventory.has_item_anywhere(item_id):
			continue
		if inventory.add_item(item_id, 1, "orbit_starter_inventory_migration"):
			added_item_ids.append(item_id)

	var missing_item_ids := debug_collect_missing_inventory_ids(starter_item_ids)
	if not missing_item_ids.is_empty():
		print("[ORBIT_STARTER_ITEMS_BLOCKED] inventory full or add failed missing=", missing_item_ids)
		return

	var inventory_data := inventory.get_save_data()
	var universe_saved := true
	var runtime_saved := true
	if save_manager.has_method("save_inventory_section_from_data"):
		universe_saved = bool(save_manager.save_inventory_section_from_data(inventory_data))
	if save_manager.has_method("save_inventory_runtime_section_from_data"):
		runtime_saved = bool(save_manager.save_inventory_runtime_section_from_data(inventory_data))
	if not universe_saved or not runtime_saved:
		print("[ORBIT_STARTER_ITEMS_BLOCKED] save failed universe=", universe_saved, " runtime=", runtime_saved)
		return

	if save_manager.has_method("mark_runtime_migration"):
		save_manager.mark_runtime_migration(ORBIT_STARTER_INVENTORY_MIGRATION_ID, {
			"added_item_ids": added_item_ids.duplicate(),
			"granted_item_ids": starter_item_ids.duplicate(),
			"universe_saved": universe_saved,
			"inventory_runtime_saved": runtime_saved
		})

	print("[ORBIT_STARTER_ITEMS_DONE] added=", added_item_ids, " granted=", starter_item_ids)


func apply_authored_orbit_resource_site_migration_once() -> void:
	# Pull the first live resource site from its authored JSON into older Universe 1
	# saves without replacing the rest of the planet's accumulated runtime state.
	if planets == null or save_manager == null:
		return
	if str(Globals.active_universe_id) != "universe_1":
		return
	if save_manager.has_method("has_runtime_migration") and save_manager.has_runtime_migration(ORBIT_VELA_RESOURCE_SITE_MIGRATION_ID):
		return

	var seed_file := FileAccess.open(ORBIT_VELA_RESOURCE_SITE_SEED_PATH, FileAccess.READ)
	if seed_file == null:
		print("[ORBIT_RESOURCE_SITE_MIGRATION_BLOCKED] seed file unavailable")
		return
	var parsed = JSON.parse_string(seed_file.get_as_text())
	seed_file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		print("[ORBIT_RESOURCE_SITE_MIGRATION_BLOCKED] seed JSON invalid")
		return
	var objects = parsed.get("objects", {})
	if typeof(objects) != TYPE_DICTIONARY:
		return
	var source_planet = objects.get(ORBIT_VELA_PLANET_ID, {})
	if typeof(source_planet) != TYPE_DICTIONARY:
		return
	var source_sites = source_planet.get("orbit_resource_sites", [])
	if typeof(source_sites) != TYPE_ARRAY or source_sites.is_empty():
		return

	var live_planet_index := find_planet_index_by_id(planets.planets, ORBIT_VELA_PLANET_ID)
	if live_planet_index < 0:
		return
	var live_planet = planets.planets[live_planet_index]
	if typeof(live_planet) != TYPE_DICTIONARY:
		return
	var merged_sites := merge_orbit_resource_sites(live_planet.get("orbit_resource_sites", []), source_sites)
	live_planet["orbit_resource_sites"] = merged_sites
	planets.planets[live_planet_index] = live_planet

	var save_data = save_manager.read_universe_save_data()
	if typeof(save_data) != TYPE_DICTIONARY or save_data.is_empty():
		return
	var saved_planets = save_data.get("planets", [])
	if typeof(saved_planets) != TYPE_ARRAY:
		return
	var saved_planet_index := find_planet_index_by_id(saved_planets, ORBIT_VELA_PLANET_ID)
	if saved_planet_index < 0:
		return
	var saved_planet = saved_planets[saved_planet_index]
	if typeof(saved_planet) != TYPE_DICTIONARY:
		return
	saved_planet["orbit_resource_sites"] = merge_orbit_resource_sites(saved_planet.get("orbit_resource_sites", []), source_sites)
	saved_planets[saved_planet_index] = saved_planet
	save_data["planets"] = saved_planets

	if not save_manager.write_universe_save_data(save_data):
		print("[ORBIT_RESOURCE_SITE_MIGRATION_BLOCKED] universe save failed")
		return
	if save_manager.has_method("mark_runtime_migration"):
		save_manager.mark_runtime_migration(ORBIT_VELA_RESOURCE_SITE_MIGRATION_ID, {
			"planet_id": ORBIT_VELA_PLANET_ID,
			"source_path": ORBIT_VELA_RESOURCE_SITE_SEED_PATH,
			"resource_site_count": source_sites.size()
		})
	print("[ORBIT_RESOURCE_SITE_MIGRATION_DONE] planet=", ORBIT_VELA_PLANET_ID, " sites=", source_sites.size())


func find_planet_index_by_id(planet_list: Array, planet_id: String) -> int:
	for i in range(planet_list.size()):
		var planet_data = planet_list[i]
		if typeof(planet_data) != TYPE_DICTIONARY:
			continue
		if str(planet_data.get("object_id", planet_data.get("id", ""))).strip_edges() == planet_id:
			return i
	return -1


func merge_orbit_resource_sites(existing_value, authored_sites: Array) -> Array:
	var output := []
	if typeof(existing_value) == TYPE_ARRAY:
		output = existing_value.duplicate(true)
	var existing_ids := {}
	for raw_site in output:
		if typeof(raw_site) != TYPE_DICTIONARY:
			continue
		var site: Dictionary = raw_site
		var site_id := str(site.get("site_id", site.get("resource_site_id", site.get("id", "")))).strip_edges()
		if site_id != "":
			existing_ids[site_id] = true
	for raw_site in authored_sites:
		if typeof(raw_site) != TYPE_DICTIONARY:
			continue
		var authored_site: Dictionary = raw_site
		var authored_id := str(authored_site.get("site_id", authored_site.get("resource_site_id", authored_site.get("id", "")))).strip_edges()
		if authored_id == "" or existing_ids.has(authored_id):
			continue
		output.append(authored_site.duplicate(true))
		existing_ids[authored_id] = true
	return output


func debug_export_item_boot_check(where: String) -> void:
	# Temporary export diagnostic. Safe to leave during alpha testing; remove once
	# exported item loading is proven stable.
	var required_item_ids := [
		"scan_module_mk1",
		"drone_controller_mk1",
		"miner_drone_mk1"
	]

	var inventory_has_any := false
	var missing_inventory: Array = []
	if inventory != null:
		if inventory.has_method("has_any_items"):
			inventory_has_any = inventory.has_any_items()
		missing_inventory = debug_collect_missing_inventory_ids(required_item_ids)

	var migration_marked := false
	if save_manager != null and save_manager.has_method("has_runtime_migration"):
		migration_marked = save_manager.has_runtime_migration(STARTER_INVENTORY_MIGRATION_ID)

	print("[EXPORT_ITEM_BOOT_CHECK]",
		" where=", where,
		" item_db_count=", debug_get_item_db_count(),
		" missing_db_required=", debug_collect_missing_item_ids(required_item_ids),
		" inventory_has_any=", inventory_has_any,
		" missing_inventory_required=", missing_inventory,
		" migration_marked=", migration_marked,
		" save_path=", debug_get_save_path(),
		" user_dir=", OS.get_user_data_dir()
	)


func debug_get_item_db_count() -> int:
	if item_handler == null:
		return -1

	var raw_db = item_handler.get("item_db")
	if typeof(raw_db) == TYPE_DICTIONARY:
		return raw_db.size()

	return -1


func debug_required_items_exist(item_ids: Array) -> bool:
	return debug_collect_missing_item_ids(item_ids).is_empty()


func debug_collect_missing_item_ids(item_ids: Array) -> Array:
	var missing: Array = []
	if item_handler == null:
		return item_ids.duplicate()

	for item_id in item_ids:
		var clean_id := str(item_id).strip_edges()
		if clean_id == "":
			continue
		if not item_handler.has_item(clean_id):
			missing.append(clean_id)

	return missing


func debug_collect_missing_inventory_ids(item_ids: Array) -> Array:
	var missing: Array = []
	if inventory == null:
		return item_ids.duplicate()

	for item_id in item_ids:
		var clean_id := str(item_id).strip_edges()
		if clean_id == "":
			continue
		if not inventory.has_item_anywhere(clean_id):
			missing.append(clean_id)

	return missing


func debug_get_save_path() -> String:
	if save_manager != null and save_manager.has_method("get_readable_universe_save_path"):
		return save_manager.get_readable_universe_save_path()
	return ""



# ==========================================================
# 🚀 BUILD: NAVIGATION / AUTOPILOT
# ==========================================================
func build_navigation_system() -> void:

	# -----------------------------
	# AUTOPILOT CORE
	# -----------------------------
	auto_pilot = AutoPilot.new()
	add_child(auto_pilot)

	auto_pilot.map = map
	auto_pilot.engine = eng
	auto_pilot.star_field = star_field
	auto_pilot.set_target(star)
	gui_state.auto_pilot = auto_pilot

	# -----------------------------
	# STAR UI MANAGER
	# -----------------------------
	add_child(star_ui)
	star_ui.setup(gui_state, map, star_field, auto_pilot)

	# -----------------------------
	# COLOR HANDLER
	# -----------------------------
	add_child(color_handler)
	color_handler.setup(gui_state)

	# -----------------------------
	# SPACE OBJECT SYSTEM
	# -----------------------------
	space_objects = Space_Objects.new()
	add_child(space_objects)



# ==========================================================
# 🌌 BUILD: STAR SYSTEM (placeholder)
# ==========================================================
func build_star_system() -> void:
	pass



# ==========================================================
# 💾 LOAD OR CREATE UNIVERSE
# ----------------------------------------------------------
# Handles persistence of:
# - Star field
# - Map position
# - Beacons
# ==========================================================
func load_or_create_universe() -> void:
	# Summary: Load the saved universe or rebuild all universe-owned population data for test runs.
	beacons = Beacons.new()
	add_child(beacons)
	planets = Planets.new()
	add_child(planets)

	var startup_mode := str(Globals.startup_mode).strip_edges().to_lower()
	var has_existing_save := save_manager.has_save()
	var wants_new_universe := startup_mode == "new"
	var wants_load_universe := has_existing_save and not wants_new_universe

	if has_existing_save and wants_load_universe:
		print("[A2 main before load] player_state=", player_state)
		print("[A2 main before load data | player ", player_state.get_save_data())
		var loaded := save_manager.load_universe(star_field, map, space_objects, inventory, enemy_handler, npc_handler, beacons,planets,player_state)
		print("[A2 main after load loaded | player=", loaded, "] player_state=", player_state)
		print("[A2 main after load data | player] ", player_state.get_save_data())
		if not loaded:
			rebuild_universe_for_new_save()
			return
		Globals.startup_mode = "load"

		if beacons.beacons.is_empty():
			beacons.generate_from_stars(star_field, 35)
		if planets.planets.is_empty():
			planets.generate_from_stars(star_field,25)

	elif not has_existing_save or wants_new_universe:
		rebuild_universe_for_new_save()
		return

	if Globals.debug_heat_1:
		if Globals.print_priority_2:
			print("BEACONS READY: ", beacons)
		if Globals.print_priority_3:
			print("BEACON COUNT: ", beacons.beacons.size())
		if Globals.print_priority_3:
			print("SPACE OBJECT COUNT: ", space_objects.objects.size())


func rebuild_universe_for_new_save() -> void:
	# Summary: Build a fresh test universe through each system's owning population handler.
	if Globals.print_priority_2:
		print("Rebuilding universe from scratch.")

	wire_runtime_intel_handlers("fresh_universe_rebuild")
	setup_world_seed_builder()

	# ------------------------------------------------------
	# Star field is the population source for world objects.
	# ------------------------------------------------------
	star_field.generate_random_stars(miniverse_sectors, 5, Globals.sector_size)
	apply_world_seed_stage("stars")

	# ------------------------------------------------------
	# Rebuild each population through its owner.
	# ------------------------------------------------------
	#space_objects.generate_from_stars(star_field, 10)
	#npc_handler.generate_from_stars(star_field)
	#enemy_handler.generate_from_stars(star_field)
	#beacons.generate_from_stars(star_field, 35)
	#planets.generate_from_stars(star_field,100,3)
	#if Globals.print_priority_1:
		#print("main_mode | planet check" + "\n" + str(planets.planets))
	apply_world_seed_stage("objects")

	# ------------------------------------------------------
	# Fresh universe test runs also get starter inventory.
	# ------------------------------------------------------
	debug_export_item_boot_check("before_first_save_load_starting_inventory")
	load_starting_inventory()
	debug_export_item_boot_check("after_first_save_load_starting_inventory")
	save_manager.save_universe(star_field, map, space_objects, inventory, enemy_handler, npc_handler, beacons, game_event_handler,planets,player_state)
	debug_export_item_boot_check("after_first_save_save_universe")
	Globals.startup_mode = "load"

	if Globals.debug_heat_1:
		if Globals.print_priority_2:
			print("Fresh universe saved after rebuild.")

# ==========================================================
# ✅ FINAL STARTUP STEPS
# ==========================================================
func wire_runtime_intel_handlers(reason: String = "startup") -> void:
	# Loaded saves wire this through SaveManager.load_universe().
	# Fresh universe rebuilds need the same handoff before starter items or seeded enemies appear.
	if save_manager == null:
		return

	if inventory != null and inventory.has_method("set_intel_handler") and save_manager.has_method("get_intel_handler"):
		inventory.set_intel_handler(save_manager.get_intel_handler())

	if enemy_handler != null and enemy_handler.has_method("set_enemy_intel_handler") and save_manager.has_method("get_enemy_intel_handler"):
		enemy_handler.set_enemy_intel_handler(save_manager.get_enemy_intel_handler())

	if Globals.print_priority_2:
		print("[INTEL_RUNTIME_WIRED] reason=", reason)


func setup_world_seed_builder() -> void:
	world_seed_builder.setup({
		"star_field": star_field,
		"map": map,
		"space_objects": space_objects,
		"npc_handler": npc_handler,
		"beacons": beacons,
		"enemy_handler": enemy_handler,
		"planets": planets
		
	})


func apply_world_seed_stage(stage: String) -> void:
	if world_seed_builder == null:
		return
	if not world_seed_builder.has_method("apply_startup_seeds"):
		return

	var result: Dictionary = world_seed_builder.apply_startup_seeds(stage)
	if Globals.print_priority_2:
		print("World seed stage applied: ", stage, " | ", result)


func finalize_startup() -> void:
	star_ui.populate_nearest_stars(5)
	star_ui.connect_star_buttons()
	refresh_tier_map_widget(true)



# ==========================================================
# 🧪 DEBUG OUTPUT
# ==========================================================
func debug_startup_prints() -> void:
	if Globals.debug:

		# Star debug
		for s in star_ui.current_nearest_stars:
			if Globals.print_priority_3:
				print("name: " + str(s.star_name))
			if Globals.print_priority_3:
				print("type: " + str(s.star_type))
			if Globals.print_priority_3:
				print("sector: " + str(s.sector_pos))
			if Globals.print_priority_3:
				print("local: " + str(s.local_pos))
			if Globals.print_priority_3:
				print("---")

		# GUI debug
		for i in gui_state.controls:
			if Globals.print_priority_3:
				print(str(i))



# ==========================================================
# 🎯 AUTOPILOT TRIGGER
# ==========================================================
func handle_autopilot_trigger() -> void:
	if Globals.battle_mode or Globals.battle_pending:
		return

	if gui_state.use_auto_pilot:
		if has_task_navigation_lock():
			block_autopilot_for_task("Auto pilot")
			return

		auto_pilot.start()

		# Save progress immediately (design choice preserved)
		if Globals.debug:
			if Globals.print_priority_3:
				print('auto_pilot start.  save should be right now')
		save_manager.save_universe(star_field, map, space_objects, inventory, enemy_handler, npc_handler, beacons, game_event_handler)

		gui_state.use_auto_pilot = false


func has_task_navigation_lock() -> bool:
	if event_handler == null:
		return false
	if not event_handler.has_method("has_navigation_lock_todo"):
		return false
	return bool(event_handler.has_navigation_lock_todo())


func get_task_navigation_lock_text() -> String:
	if event_handler == null:
		return ""
	if not event_handler.has_method("get_navigation_lock_todo_text"):
		return ""
	return str(event_handler.get_navigation_lock_todo_text()).strip_edges()


func get_task_navigation_lock_message(action_label: String = "Auto pilot") -> String:
	var task_text := get_task_navigation_lock_text()
	if task_text == "":
		task_text = "the active task"
	return action_label + " unavailable while " + task_text + "."


func apply_task_navigation_lock() -> void:
	if gui_state != null:
		gui_state.use_auto_pilot = false

	if auto_pilot != null and auto_pilot.enabled:
		auto_pilot.stop()

	if eng != null:
		if eng.has_method("hard_stop_after_arrival"):
			eng.hard_stop_after_arrival()
		else:
			eng.stop()
			eng.speed = 0.0


func block_autopilot_for_task(action_label: String = "Auto pilot") -> void:
	apply_task_navigation_lock()

	if gui_state != null and gui_state.log_storage.has("log_text"):
		gui_state.log_storage["log_text"].text = get_task_navigation_lock_message(action_label)

	if Globals.print_priority_2:
		print(get_task_navigation_lock_message(action_label))



# ==========================================================
# 🎛️ AUTOPILOT UI UPDATE
# ==========================================================
func update_autopilot_ui() -> void:
	if Globals.battle_mode or Globals.battle_pending:
		return

	if has_task_navigation_lock():
		apply_task_navigation_lock()

	if auto_pilot.enabled:
		auto_scan_after_autopilot_armed = true
		if not Globals.run_refresh_inventory:
			action_manager.refresh_actions_from_inventory()
			Globals.run_refresh_inventory = true
		# Update labels
		gui_state.drive_value_labels["yaw"].text = "Yaw : " + str(int(round(auto_pilot.yaw_update)))
		gui_state.drive_value_labels["pitch"].text = "Pit : " + str(int(round(auto_pilot.pitch_update)))

		# Update sliders
		gui_state.sliders["yaw_slider"].value = auto_pilot.yaw_update
		gui_state.sliders["pitch_slider"].value = auto_pilot.pitch_update

		# Refresh visuals
		star_ui.refresh_star_distance_buttons()
		color_handler.alert_theme_engine(true)

		Globals.target_star_button_run = true

	else:
		color_handler.alert_theme_engine(false)
		Globals.target_star_button_run = false
		if Globals.run_refresh_inventory:
			action_manager.refresh_actions_from_inventory()
			Globals.run_refresh_inventory = false
		

func handle_auto_scan_after_autopilot() -> void:
	# Summary: When autopilot has been active, run one normal scan after it turns off.
	if Globals.battle_mode or Globals.battle_pending:
		auto_scan_after_autopilot_armed = false
		return

	if auto_pilot == null or action_manager == null:
		return

	if has_task_navigation_lock():
		auto_scan_after_autopilot_armed = false
		return

	if auto_pilot.enabled:
		auto_scan_after_autopilot_armed = true
		return

	if not auto_scan_after_autopilot_armed:
		return

	auto_scan_after_autopilot_armed = false

	if action_manager.scan_in_progress:
		if Globals.print_priority_2:
			print("AUTO SCAN AFTER AUTOPILOT skipped - scan already in progress.")
		return

	if inventory != null and not inventory.has_item_anywhere("scan_module_mk1"):
		if Globals.print_priority_2:
			print("AUTO SCAN AFTER AUTOPILOT skipped - scan module missing.")
		return

	if Globals.print_priority_2:
		print("AUTO SCAN AFTER AUTOPILOT queued.")

	action_manager.run_action("scan_local")






# ==========================================================
# 🌍 WORLD UPDATE
# ==========================================================
func update_world(delta: float) -> void:
	if has_task_navigation_lock():
		apply_task_navigation_lock()
		return

	# 1. Autopilot decides intent (thrust ON/OFF, mode)
	auto_pilot.update_autopilot(delta)

	# 2. Engine converts that into real speed (acceleration / braking)
	eng.update_engine(delta)

	# 3. Map moves the ship based on engine speed
	map.update_map(eng.speed, delta)


func update_engine_widget() -> void:
	# Codex edit: keep the drive widget reflecting the real engine state.
	# The widget is free-drive only; autopilot and battle both lock manual
	# access so their systems can own navigation without UI interference.
	var locked := false
	if gui_state.use_auto_pilot:
		locked = true
	if auto_pilot != null and auto_pilot.enabled:
		locked = true
	if Globals.battle_mode or Globals.battle_pending:
		locked = true
	if Globals.is_popup_input_locked():
		locked = true
	if has_task_navigation_lock():
		locked = true

	if gui_state.labels.has("drive_fuel"):
		gui_state.labels["drive_fuel"].text = "Mode"
	if gui_state.drive_value_labels.has("speed"):
		gui_state.drive_value_labels["speed"].text = str(int(round(eng.speed)))
	if gui_state.drive_value_labels.has("fuel"):
		var thrust_state := "ON" if eng.thrust_on else "OFF"
		gui_state.drive_value_labels["fuel"].text = eng.mode.capitalize() + " / " + thrust_state

	set_engine_widget_disabled(locked)


func set_engine_widget_disabled(disabled: bool) -> void:
	# Codex edit: disable both the top tabs and direct-flight controls
	# when free drive is not allowed.
	var button_keys := [
		"drive_warp",
		"drive_impulse",
		"drive_stop"
	]

	for key in button_keys:
		if gui_state.buttons.has(key):
			gui_state.buttons[key].disabled = disabled

	if gui_state.buttons.has("drive_thrust"):
		var thrust_buttons = gui_state.buttons["drive_thrust"]
		if thrust_buttons.has("thrust_on"):
			thrust_buttons["thrust_on"].disabled = disabled
		if thrust_buttons.has("thrust_off"):
			thrust_buttons["thrust_off"].disabled = disabled

	var slider_keys := [
		"yaw_slider",
		"pitch_slider",
		"roll_slider"
	]

	for key in slider_keys:
		if gui_state.sliders.has(key):
			gui_state.sliders[key].editable = not disabled
# ==========================================================
# 🖥️ UI UPDATE
# ==========================================================
func handle_popup_input_lock_transition() -> void:
	var locked := Globals.is_popup_input_locked()
	if locked == popup_input_lock_last:
		return

	popup_input_lock_last = locked

	if action_manager != null:
		action_manager.refresh_actions_from_inventory()

	if star_ui != null:
		star_ui.refresh_star_distance_buttons()

	if inv_radar_panel != null and inv_radar_panel.live_map_control != null and map != null:
		inv_radar_panel.live_map_control.set_clickable_enabled(not locked)

	if gui_state != null and gui_state.buttons.has("tier_map"):
		if tier_map_last_packet.is_empty():
			update_tier_map_tab_buttons()
		else:
			apply_tier_map_packet_to_widget(tier_map_last_packet)

	update_engine_widget()


func update_ui(delta: float) -> void:
	connect_map()

	# Time-based effects (kept for experimentation)
	var t = Time.get_ticks_msec() / 1000.0
	# ==================================================
# ⚡ RECHARGE BATTLE ENERGY
# ==================================================
	

func update_battle_navigation_visibility() -> void:
	var should_hide := Globals.battle_mode or Globals.battle_pending
	if navigation_widgets_hidden == should_hide:
		return

	navigation_widgets_hidden = should_hide

	var nav_roots := [
		"sd",
		"tier_map",
		"drive_root",
		"coords_root"
	]

	for key in nav_roots:
		if gui_state.controls.has(key):
			gui_state.controls[key].visible = not should_hide

	var battle_stat_roots := [
		"player_stats_root",
		"enemy_stats_root"
	]

	for key in battle_stat_roots:
		if gui_state.controls.has(key):
			gui_state.controls[key].visible = should_hide
			
func clear_scanned_results_after_ship_movement():
	if action_manager == null:
		return
	if auto_pilot != null and auto_pilot.enabled and auto_pilot.mode == "impulse":
		return
	action_manager.clear_scan_results_if_player_moved("ship_movement")



		
		

# ==========================================================
# 🔗 MAP → UI CONNECTION
# ==========================================================
func connect_map() -> void:

	# Local position
	if gui_state.labels.has("coords_local_pos"):
		gui_state.labels["coords_local_pos"].text = (
			str(int(map.local_pos.x)) + "," +
			str(int(map.local_pos.y)) + "," +
			str(int(map.local_pos.z))
		)

	# Sector position
	if gui_state.labels.has("coords_sector_pos"):
		gui_state.labels["coords_sector_pos"].text = (
			str(int(map.sector_pos.x)) + "," +
			str(int(map.sector_pos.y)) + "," +
			str(int(map.sector_pos.z))
		)

	if gui_state.labels.has("coords_speed_value"):
		gui_state.labels["coords_speed_value"].text = str(int(round(eng.speed)))

	var nav_mode := "Idle"
	if auto_pilot != null and auto_pilot.enabled:
		nav_mode = eng.mode.capitalize()
	elif eng != null and (eng.speed > 0.5 or eng.thrust_on):
		nav_mode = eng.mode.capitalize()

	if gui_state.labels.has("coords_mode_value"):
		gui_state.labels["coords_mode_value"].text = nav_mode
	if gui_state.labels.has("coords_thrust_value"):
		gui_state.labels["coords_thrust_value"].text = "On" if eng.thrust_on else "Off"
	if gui_state.labels.has("coords_autopilot_value"):
		gui_state.labels["coords_autopilot_value"].text = "On" if auto_pilot != null and auto_pilot.enabled else "Off"
	if gui_state.labels.has("coords_phase_value"):
		gui_state.labels["coords_phase_value"].text = auto_pilot.phase if auto_pilot != null else "idle"



# ==========================================================
# 🧱 GUI CONSTRUCTION HUB
# ==========================================================
func build_systems() -> void:

	var tier_map_pos = Vector2.ZERO if Globals.main_cockpit_v2_enabled else Globals.star_dis_widg_pos
	var tier_map_size = Globals.main_left_panel_size if Globals.main_cockpit_v2_enabled else Globals.star_distance_widget_size
	var tier_map_gui = gui_builder.tierMap(
		tier_map_pos,
		tier_map_size,
		24,
		12
	)
	connect_tier_map_buttons()

	var drive_gui = gui_builder.drive_1(Globals.eng_widg_pos)
	drive_gui.visible = false
	var player_stats_gui = gui_builder.stats_1(
		Globals.star_dis_widg_pos,
		3,
		Color(0.10, 0.16, 0.24, 1.0),
		Color(0.18, 0.26, 0.34, 1.0),
		Color(0.07, 0.10, 0.15, 1.0),
		"player_stats",
		"Player"
	)
	var enemy_stats_gui = gui_builder.stats_1(
		Globals.star_dis_widg_pos + Vector2(0, 135),
		3,
		Color(0.24, 0.10, 0.12, 1.0),
		Color(0.34, 0.18, 0.20, 1.0),
		Color(0.15, 0.07, 0.08, 1.0),
		"enemy_stats",
		"Enemy"
	)
	var position_gui = gui_builder.coords_1(
		Globals.map_widg_pos,
		int(Globals.nav_widget_size.x),
		int(Globals.nav_widget_size.y / 8.0)
	)
	player_stats_gui.visible = false
	enemy_stats_gui.visible = false
	


	add_child(tier_map_gui)
	add_child(drive_gui)
	add_child(player_stats_gui)
	add_child(enemy_stats_gui)
	add_child(position_gui)
	add_child(map)



# ==========================================================
# 💾 SAVE ON CLOSE
# ==========================================================
func _notification(what) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not main_mode_boot_complete:
			get_tree().quit()
			return

		if save_manager:
			save_manager.save_universe(star_field, map, space_objects, inventory, enemy_handler, npc_handler, beacons, game_event_handler)
		get_tree().quit()


# ==========================================================
# 🌌 AURORA BACKGROUND BUILDER
# ----------------------------------------------------------
# Creates:
# - Fullscreen sci-fi texture
# - Animated "brain" aurora overlay
#
# NOTE:
# Preserved original structure, but clarified intent
# ==========================================================
func help_arora_work() -> void:

	var c2 = Control.new()
	scifi_background_root = c2
	add_child(c2)

	# --- FULLSCREEN BACKGROUND TEXTURE ---
	var c2_texture := TextureRect.new()
	c2_texture.texture = aurora_holder
	c2_texture.set_anchors_preset(Control.PRESET_FULL_RECT)

	c2.add_child(c2_texture)

	c2_texture.z_index = -10
	c2_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	c2_texture.stretch_mode = TextureRect.STRETCH_SCALE

	c2.size = Vector2(Globals.screen_w, Globals.screen_h)
	c2.position = Vector2.ZERO

	# --- AURORA CONTAINER ---
	var c = Control.new()
	c.size = Globals.aurora_size
	c.position = Globals.aurora_pos
	c2.add_child(c)

	# --- AURORA EFFECT ---
	aurora_bg = AuroraBrainBackground.new()
	c.add_child(aurora_bg)

	aurora_bg.set_anchors_preset(Control.PRESET_CENTER)
	aurora_bg.z_index = -10

	aurora_bg.anchor_left = 0.0
	aurora_bg.anchor_top = 0.0
	aurora_bg.anchor_right = 1.0
	aurora_bg.anchor_bottom = 1.0

	aurora_bg.offset_left = 0
	aurora_bg.offset_top = 0
	aurora_bg.offset_right = 0
	aurora_bg.offset_bottom = 0
	
	
func check_for_enemy_encounter():
	if Globals.battle_mode or Globals.battle_pending:
		return
			
			



func start_combat_with_enemy(enemy: Enemy):
	# Summary: Request battle entry for a selected enemy using V2 scene swap when enabled.
	if Globals.print_priority_3:
		print("start_combat_with_enemy called.")

	# ------------------------------------------------------
	# Battle V2 path.
	# ------------------------------------------------------
	if Globals.Let_battle_v2:
		if battle_v2_bridge == null:
			if Globals.print_priority_2:
				print("[start_combat_with_enemy_failed] reason=no_battle_v2_bridge")
			return

		battle_v2_bridge.request_battle_v2_entry("start_combat_with_enemy", enemy)
		return

	# ------------------------------------------------------
	# Legacy Battle V1 path.
	# ------------------------------------------------------
	if not Globals.Let_battle_v1:
		if Globals.print_priority_2:
			print("Battle v1 entry is disabled.")
		return

	if Globals.battle_mode or Globals.battle_pending:
		return

	if Globals.print_priority_3:
		print("LOCKING TARGET:", enemy.enemy_name)

	Globals.current_enemy = enemy
	Globals.battle_pending = true

	event_handler.add_event(
		"Entering Combat Zone...",
		5.0,
		"enter_battle",
		{}
	)


func debug_force_battle_v2_enemy_encounter() -> void:
	# Summary: Debug key wrapper. Main still checks text focus because main owns input.
	if Globals.print_priority_2:
		print("Debug Battle V2 real-enemy encounter key pressed.")

	if is_text_input_focused():
		if Globals.print_priority_3:
			print("Debug Battle V2 encounter ignored - text input has focus.")
		return

	if battle_v2_bridge == null:
		if Globals.print_priority_2:
			print("[debug_battle_v2_real_enemy_failed] reason=no_battle_v2_bridge")
		return

	battle_v2_bridge.debug_force_real_enemy_encounter()

	
	
func build_coord_auto_widget_pop_up():

	if gui_state == null:
		if Globals.print_priority_2:
			print("Coord auto widget failed - gui_state is null")
		return

	if not gui_state.controls.has("popup_root"):
		if Globals.print_priority_2:
			print("Coord auto widget failed - popup_root missing")
		return

	var popup = gui_state.controls["popup_root"]

	if popup == null:
		if Globals.print_priority_2:
			print("Coord auto widget failed - popup_root is null")
		return


	var panel = popup.get_node_or_null("popup_panel")
	if panel == null or not is_instance_valid(panel):
		if Globals.print_priority_2:
			print("Coord auto widget failed - popup_panel missing")
		return

	var themed_panel = Globals.configure_popup_panel(
		gui_state,
		Vector2(430, 320),
		Color(0.34, 0.88, 1.0, 0.86),
		"coord_auto_popup_aurora_background",
		"coord_auto_popup_theme_frame"
	)
	if themed_panel != null:
		panel = themed_panel

	if panel.has_node("coord_auto_pilot_root"):
		if Globals.print_priority_2:
			print("Coord auto widget already exists")
		return

	var popup_text = gui_state.labels.get("popup_text", null)
	if popup_text != null and is_instance_valid(popup_text):
		popup_text.visible = false
	var popup_title = gui_state.labels.get("popup_title", null)
	if popup_title != null and is_instance_valid(popup_title):
		popup_title.visible = false

	var c := Control.new()
	c.name = "coord_auto_pilot_root"
	c.position = Vector2(18, 14)
	c.size = Vector2(394, 264)
	c.z_index = 30
	panel.add_child(c)
	gui_state.controls["coord_auto_pilot_root"] = c

	var title := Label.new()
	title.name = "coord_auto_pilot_title"
	title.position = Vector2.ZERO
	title.size = Vector2(c.size.x, 26)
	title.text = "COORD AUTO PILOT"
	title.add_theme_font_override("font", gui_state.font)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.68, 0.92, 1.0, 1.0))
	c.add_child(title)
	gui_state.labels["coord_auto_pilot_title"] = title

	var hint := Label.new()
	hint.name = "coord_auto_hint"
	hint.position = Vector2(0, 34)
	hint.size = Vector2(c.size.x, 36)
	hint.text = "Enter a sector and local target, then engage."
	hint.add_theme_font_override("font", gui_state.font)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0, 0.86))
	c.add_child(hint)
	gui_state.labels["coord_auto_hint"] = hint

	var axis_y := 78.0
	for i in range(3):
		var axis_label := Label.new()
		axis_label.name = "coord_auto_axis_" + str(i)
		axis_label.position = Vector2(92 + (84 * i), axis_y)
		axis_label.size = Vector2(72, 18)
		axis_label.text = ["X", "Y", "Z"][i]
		axis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		axis_label.add_theme_font_override("font", gui_state.font)
		axis_label.add_theme_font_size_override("font_size", 11)
		axis_label.add_theme_color_override("font_color", Color(0.68, 0.92, 1.0, 0.95))
		c.add_child(axis_label)
		gui_state.labels[axis_label.name] = axis_label

	var sector_label := Label.new()
	sector_label.name = "coord_auto_sector_label"
	sector_label.position = Vector2(0, 110)
	sector_label.size = Vector2(78, 28)
	sector_label.text = "Sector"
	sector_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sector_label.add_theme_font_override("font", gui_state.font)
	sector_label.add_theme_font_size_override("font_size", 12)
	c.add_child(sector_label)
	gui_state.labels["coord_auto_sector_label"] = sector_label

	var local_label := Label.new()
	local_label.name = "coord_auto_local_label"
	local_label.position = Vector2(0, 156)
	local_label.size = Vector2(78, 28)
	local_label.text = "Local"
	local_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	local_label.add_theme_font_override("font", gui_state.font)
	local_label.add_theme_font_size_override("font_size", 12)
	c.add_child(local_label)
	gui_state.labels["coord_auto_local_label"] = local_label

	var field_size := Vector2(72, 30)
	var field_x := [92.0, 176.0, 260.0]
	var sector_fields := ["coord_auto_sector_x", "coord_auto_sector_y", "coord_auto_sector_z"]
	var local_fields := ["coord_auto_local_x", "coord_auto_local_y", "coord_auto_local_z"]
	for i in range(3):
		var sector_edit := make_coord_auto_line_edit(sector_fields[i], Vector2(field_x[i], 110), field_size, "0")
		c.add_child(sector_edit)
		gui_state.controls[sector_fields[i]] = sector_edit

		var local_edit := make_coord_auto_line_edit(local_fields[i], Vector2(field_x[i], 156), field_size, "0")
		c.add_child(local_edit)
		gui_state.controls[local_fields[i]] = local_edit

	var engage := Button.new()
	engage.name = "coord_auto_engage"
	engage.position = Vector2(0, 232)
	engage.size = Vector2(154, 34)
	engage.text = "ENGAGE"
	engage.add_theme_font_override("font", gui_state.font)
	engage.add_theme_font_size_override("font_size", 12)
	c.add_child(engage)
	gui_state.buttons["coord_auto_engage"] = engage
	engage.pressed.connect(_on_coord_auto_engage_pressed)


	if Globals.print_priority_3:
		print("Coord auto pilot popup widget built")


func make_coord_auto_line_edit(field_name: String, field_pos: Vector2, field_size: Vector2, value: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.name = field_name
	edit.position = field_pos
	edit.size = field_size
	edit.text = value
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_font_override("font", gui_state.font)
	edit.add_theme_font_size_override("font_size", 12)
	return edit


func setup_settings_handler() -> void:
	settings_popup_controller.setup(self, gui_state, settings_handler)


func build_settings_popup_widget() -> void:
	settings_popup_controller.update_refs(self, gui_state, settings_handler)
	settings_popup_controller.build_widget()


func show_settings_popup() -> void:
	settings_popup_controller.update_refs(self, gui_state, settings_handler)
	settings_popup_controller.show_popup()


func get_shared_popup_panel() -> Control:
	if gui_state == null:
		return null
	if not gui_state.controls.has("popup_root"):
		return null

	var popup = gui_state.controls["popup_root"]
	if popup == null or not is_instance_valid(popup):
		return null

	var panel = popup.get_node_or_null("popup_panel")
	if panel is Control:
		return panel as Control

	return null


func hide_shared_popup_text_and_close() -> void:
	var popup_text = gui_state.labels.get("popup_text", null)
	if popup_text != null and is_instance_valid(popup_text):
		popup_text.visible = false

	var popup_title = gui_state.labels.get("popup_title", null)
	if popup_title != null and is_instance_valid(popup_title):
		popup_title.visible = false

	var close_btn = gui_state.buttons.get("popup_close", null)
	if close_btn != null and is_instance_valid(close_btn):
		close_btn.visible = false


func setup_battle_loadout_popup(panel: Control = null) -> void:
	if panel == null:
		panel = get_shared_popup_panel()
	if panel == null:
		if Globals.print_priority_2:
			print("Battle loadout popup failed - popup panel missing.")
		return

	if battle_loadout_popup != null and is_instance_valid(battle_loadout_popup):
		if battle_loadout_popup.get_parent() != panel:
			var old_parent = battle_loadout_popup.get_parent()
			if old_parent != null:
				old_parent.remove_child(battle_loadout_popup)
			panel.add_child(battle_loadout_popup)
	else:
		battle_loadout_popup = BattleLoadoutPopupScript.new()
		battle_loadout_popup.name = "battle_loadout_popup_root"
		panel.add_child(battle_loadout_popup)

	battle_loadout_popup.name = "battle_loadout_popup_root"
	battle_loadout_popup.position = Vector2(18, 16)
	battle_loadout_popup.size = Vector2(max(panel.size.x - 36.0, 560.0), max(panel.size.y - 76.0, 390.0))
	battle_loadout_popup.z_index = 30
	battle_loadout_popup.visible = false
	battle_loadout_popup.setup({
		"inventory": inventory,
		"item_handler": item_handler,
		"player_state": player_state,
		"gui_state": gui_state
	})

	if not battle_loadout_popup.save_requested.is_connected(_on_battle_loadout_save_requested):
		battle_loadout_popup.save_requested.connect(_on_battle_loadout_save_requested)
	if not battle_loadout_popup.cancel_requested.is_connected(_on_battle_loadout_cancel_requested):
		battle_loadout_popup.cancel_requested.connect(_on_battle_loadout_cancel_requested)


func show_battle_loadout_popup() -> void:
	if gui_state == null:
		return
	if not gui_state.controls.has("popup_root"):
		return

	Globals.show_popup(gui_state, "")
	Globals.set_shared_popup_space_close_enabled(gui_state, false, "battle_loadout_popup")
	var panel = Globals.configure_popup_panel(
		gui_state,
		Vector2(700, 520),
		Color(0.34, 0.88, 1.0, 0.86),
		"battle_loadout_popup_aurora_background",
		"battle_loadout_popup_theme_frame"
	)
	if panel == null:
		return

	hide_shared_popup_text_and_close()
	setup_battle_loadout_popup(panel)

	if battle_loadout_popup == null or not is_instance_valid(battle_loadout_popup):
		return

	Globals.set_popup_input_lock("battle_loadout_popup", true)
	battle_loadout_popup.open_from_player_state()
	panel.move_child(battle_loadout_popup, panel.get_child_count() - 1)


func _on_battle_loadout_save_requested(loadout_data: Dictionary) -> void:
	if player_state != null:
		if player_state.has_method("set_battle_loadout_save_data"):
			player_state.set_battle_loadout_save_data(loadout_data)
		else:
			player_state.set("battle_loadout", loadout_data.duplicate(true))

	var saved_ok := false
	if save_manager != null and save_manager.has_method("save_universe"):
		saved_ok = bool(save_manager.save_universe(
			star_field,
			map,
			space_objects,
			inventory,
			enemy_handler,
			npc_handler,
			beacons,
			game_event_handler,
			planets,
			player_state
		))

	write_loadout_summary_to_log(loadout_data, saved_ok)
	Globals.reset_popup_runtime(gui_state, true)
	battle_loadout_popup = null


func _on_battle_loadout_cancel_requested() -> void:
	Globals.reset_popup_runtime(gui_state, true)
	battle_loadout_popup = null


func write_loadout_summary_to_log(loadout_data: Dictionary, saved_ok: bool) -> void:
	if gui_state == null or not gui_state.log_storage.has("log_text"):
		return

	var status := "Battle loadout saved." if saved_ok else "Battle loadout updated. Save file write did not confirm."
	gui_state.log_storage["log_text"].text = (
		status
		+ "\nPrimary: " + get_loadout_display_name(loadout_data.get("selected_primary_weapon", ""))
		+ "\nSecondary: " + get_loadout_display_name(loadout_data.get("selected_secondary_weapon", ""))
		+ "\nShield: " + get_loadout_display_name(loadout_data.get("selected_shield", ""))
		+ "\nConsumable: " + get_loadout_display_name(loadout_data.get("loaded_consumable", ""))
		+ "\nShield Power: " + str(int(loadout_data.get("shield_power_level", 0))) + " / 4"
	)


func get_loadout_display_name(item_id_value: Variant) -> String:
	var item_id := str(item_id_value).strip_edges()
	if item_id == "":
		return "Empty"
	if item_handler != null and item_handler.has_method("get_item_name"):
		return item_handler.get_item_name(item_id)
	return item_id


func show_coord_auto_popup() -> void:
	coord_auto_preloaded_target = {}
	Globals.show_popup(
		gui_state,
		"COORD AUTO PILOT\nEnter target coordinates, then press ENGAGE."
	)
	build_coord_auto_widget_pop_up()
	Globals.set_shared_popup_space_close_enabled(gui_state, true, "coord_auto_pilot")


func show_named_saves_popup() -> void:
	if gui_state == null:
		return
	if not gui_state.controls.has("popup_root"):
		return

	Globals.show_popup(gui_state, "")
	Globals.set_shared_popup_space_close_enabled(gui_state, false, "named_save_popup")
	var panel = Globals.configure_popup_panel(
		gui_state,
		Vector2(620, 500),
		Color(0.34, 0.88, 1.0, 0.86),
		"named_save_popup_aurora_background",
		"named_save_popup_theme_frame"
	)
	if panel == null:
		return

	var popup_text = gui_state.labels.get("popup_text", null)
	if popup_text != null and is_instance_valid(popup_text):
		popup_text.visible = false
	var popup_title = gui_state.labels.get("popup_title", null)
	if popup_title != null and is_instance_valid(popup_title):
		popup_title.visible = false

	var existing = panel.get_node_or_null("named_save_popup_root")
	if existing != null and is_instance_valid(existing):
		panel.remove_child(existing)
		existing.queue_free()

	var root := Control.new()
	root.name = "named_save_popup_root"
	root.position = Vector2(18, 16)
	root.size = Vector2(max(panel.size.x - 36.0, 560.0), max(panel.size.y - 82.0, 360.0))
	root.z_index = 30
	panel.add_child(root)
	named_save_popup_root = root
	gui_state.controls["named_save_popup_root"] = root

	build_named_save_popup_contents(root)
	Globals.set_popup_input_lock("named_save_popup", true)


func build_named_save_popup_contents(root: Control) -> void:
	var title := make_named_save_label(
		"named_save_title",
		"NAMED SAVE SNAPSHOTS",
		Vector2.ZERO,
		Vector2(root.size.x, 26),
		16,
		Color(0.68, 0.92, 1.0, 1.0)
	)
	root.add_child(title)
	gui_state.labels["named_save_title"] = title

	var hint := make_named_save_label(
		"named_save_hint",
		"Save copies the current autosave into a frozen slot. Load promotes a slot back into autosave and reloads.",
		Vector2(0, 34),
		Vector2(root.size.x, 36),
		12,
		Color(0.82, 0.92, 1.0, 0.86)
	)
	root.add_child(hint)
	gui_state.labels["named_save_hint"] = hint

	var name_label := make_named_save_label(
		"named_save_name_label",
		"Name",
		Vector2(0, 73),
		Vector2(120, 18),
		11,
		Color(0.68, 0.92, 1.0, 0.95)
	)
	root.add_child(name_label)
	gui_state.labels["named_save_name_label"] = name_label

	var name_input := LineEdit.new()
	name_input.name = "named_save_name_input"
	name_input.position = Vector2(0, 94)
	name_input.size = Vector2(260, 30)
	name_input.placeholder_text = "checkpoint name"
	name_input.add_theme_font_override("font", gui_state.font)
	name_input.add_theme_font_size_override("font_size", 12)
	root.add_child(name_input)
	gui_state.controls["named_save_name_input"] = name_input

	var summary_label := make_named_save_label(
		"named_save_summary_label",
		"Note",
		Vector2(276, 73),
		Vector2(120, 18),
		11,
		Color(0.68, 0.92, 1.0, 0.95)
	)
	root.add_child(summary_label)
	gui_state.labels["named_save_summary_label"] = summary_label

	var summary_input := LineEdit.new()
	summary_input.name = "named_save_summary_input"
	summary_input.position = Vector2(276, 94)
	summary_input.size = Vector2(root.size.x - 276.0, 30)
	summary_input.placeholder_text = "optional short note"
	summary_input.add_theme_font_override("font", gui_state.font)
	summary_input.add_theme_font_size_override("font_size", 12)
	root.add_child(summary_input)
	gui_state.controls["named_save_summary_input"] = summary_input

	var save_button := make_named_save_button(
		"named_save_snapshot_button",
		"SAVE SNAPSHOT",
		Vector2(0, 138),
		Vector2(146, 34)
	)
	root.add_child(save_button)
	gui_state.buttons["named_save_snapshot_button"] = save_button

	var status_label := make_named_save_label(
		"named_save_status",
		"Ready.",
		Vector2(160, 136),
		Vector2(root.size.x - 160.0, 42),
		12,
		Color(0.90, 1.0, 1.0, 0.90)
	)
	root.add_child(status_label)
	gui_state.labels["named_save_status"] = status_label

	var slot_title := make_named_save_label(
		"named_save_slot_title",
		"SLOTS",
		Vector2(0, 188),
		Vector2(root.size.x, 18),
		11,
		Color(0.68, 0.92, 1.0, 0.95)
	)
	root.add_child(slot_title)
	gui_state.labels["named_save_slot_title"] = slot_title

	var scroll := ScrollContainer.new()
	scroll.name = "named_save_slot_scroll"
	scroll.position = Vector2(0, 212)
	scroll.size = Vector2(root.size.x, root.size.y - 212.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	gui_state.controls["named_save_slot_scroll"] = scroll

	var slot_box := VBoxContainer.new()
	slot_box.name = "named_save_slot_list"
	slot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(slot_box)
	gui_state.controls["named_save_slot_list"] = slot_box

	populate_named_save_slot_list(slot_box)
	save_button.pressed.connect(_on_named_save_snapshot_pressed.bind(name_input, summary_input, status_label, slot_box))


func make_named_save_label(label_name: String, text: String, label_pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.position = label_pos
	label.size = label_size
	label.add_theme_font_override("font", gui_state.font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func make_named_save_button(button_name: String, text: String, button_pos: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.position = button_pos
	button.size = button_size
	button.add_theme_font_override("font", gui_state.font)
	button.add_theme_font_size_override("font_size", 12)
	return button


func populate_named_save_slot_list(slot_box: VBoxContainer) -> void:
	for child in slot_box.get_children():
		slot_box.remove_child(child)
		child.queue_free()

	if save_manager == null or not save_manager.has_method("list_named_save_slots"):
		var unavailable := make_named_save_slot_text("Named save manager unavailable.")
		slot_box.add_child(unavailable)
		return

	var slots = save_manager.list_named_save_slots()
	if slots.is_empty():
		var empty := make_named_save_slot_text("No named snapshots yet.")
		slot_box.add_child(empty)
		return

	for slot in slots:
		if typeof(slot) != TYPE_DICTIONARY:
			continue

		var slot_id := str(slot.get("slot_id", ""))
		var row := HBoxContainer.new()
		row.name = "named_save_slot_row_" + slot_id
		row.custom_minimum_size = Vector2(slot_box.size.x, 58)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := make_named_save_slot_text(build_named_save_slot_display(slot))
		label.custom_minimum_size = Vector2(450, 54)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var load_button := Button.new()
		load_button.name = "named_save_load_" + slot_id
		load_button.text = "LOAD"
		load_button.custom_minimum_size = Vector2(82, 32)
		load_button.add_theme_font_override("font", gui_state.font)
		load_button.add_theme_font_size_override("font_size", 12)
		load_button.pressed.connect(_on_named_save_load_pressed.bind(slot_id))
		row.add_child(load_button)

		slot_box.add_child(row)


func make_named_save_slot_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", gui_state.font)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.86, 0.94, 1.0, 0.92))
	return label


func build_named_save_slot_display(slot: Dictionary) -> String:
	var display_name := str(slot.get("display_name", "Save"))
	var created := str(slot.get("created_at_text", ""))
	var summary := str(slot.get("summary", "")).strip_edges()
	var line := display_name
	if created != "":
		line += "  " + created
	if summary != "":
		line += "\n" + summary
	return line


func _on_named_save_snapshot_pressed(name_input: LineEdit, summary_input: LineEdit, status_label: Label, slot_box: VBoxContainer) -> void:
	status_label.text = "Saving named snapshot..."
	var result := request_save_with_name(name_input.text, summary_input.text)

	if bool(result.get("ok", false)):
		status_label.text = "Saved: " + str(result.get("display_name", name_input.text))
		write_named_save_status_to_log(status_label.text)
		populate_named_save_slot_list(slot_box)
		return

	status_label.text = "Save failed: " + str(result.get("reason", "unknown reason"))
	write_named_save_status_to_log(status_label.text)


func _on_named_save_load_pressed(slot_id: String) -> void:
	var status_label = gui_state.labels.get("named_save_status", null)
	if status_label != null and is_instance_valid(status_label):
		status_label.text = "Loading named snapshot..."

	var result := request_load_named_save(slot_id)
	if bool(result.get("ok", false)):
		write_named_save_status_to_log("Loading named snapshot: " + slot_id)
		return

	if status_label != null and is_instance_valid(status_label):
		status_label.text = "Load failed: " + str(result.get("reason", "unknown reason"))
	var fail_message := "Named save load failed."
	if status_label != null and is_instance_valid(status_label):
		fail_message = str(status_label.text)
	write_named_save_status_to_log(fail_message)


func request_save_with_name(display_name: String, summary: String = "") -> Dictionary:
	var block_reason := get_named_save_block_reason()
	if block_reason != "":
		return {
			"ok": false,
			"reason": block_reason
		}

	if save_manager == null:
		return {
			"ok": false,
			"reason": "Save manager is missing."
		}

	var saved_ok := bool(save_manager.save_universe(
		star_field,
		map,
		space_objects,
		inventory,
		enemy_handler,
		npc_handler,
		beacons,
		game_event_handler,
		planets,
		player_state
	))
	if not saved_ok:
		return {
			"ok": false,
			"reason": "Autosave failed before named snapshot."
		}

	if not save_manager.has_method("create_named_save_from_current_autosave"):
		return {
			"ok": false,
			"reason": "Named save support is not available."
		}

	return save_manager.create_named_save_from_current_autosave(display_name, summary)


func request_load_named_save(slot_id: String) -> Dictionary:
	var block_reason := get_named_save_block_reason()
	if block_reason != "":
		return {
			"ok": false,
			"reason": block_reason
		}

	if save_manager == null or not save_manager.has_method("promote_named_save_to_autosave"):
		return {
			"ok": false,
			"reason": "Named save support is not available."
		}

	var result: Dictionary = save_manager.promote_named_save_to_autosave(slot_id)
	if not bool(result.get("ok", false)):
		return result

	Globals.startup_mode = "load"
	call_deferred("_reload_current_scene_after_named_load")
	return result


func get_named_save_block_reason() -> String:
	if Globals.battle_mode or Globals.battle_pending or Globals.swap_battle_v2:
		return "Finish the battle transition before using named saves."
	if Globals.orbit_mode or Globals.orbit_pending or Globals.swap_orbit:
		return "Finish the Orbit transition before using named saves."
	if Globals.swap_NPC_tran:
		return "Finish the NPC transition before using named saves."
	return ""


func _reload_current_scene_after_named_load() -> void:
	if gui_state != null:
		Globals.reset_popup_runtime(gui_state, true)
	named_save_popup_root = null
	get_tree().reload_current_scene()


func write_named_save_status_to_log(message: String) -> void:
	if gui_state == null or not gui_state.log_storage.has("log_text"):
		return
	gui_state.log_storage["log_text"].text = message


func request_quick_save(reason: String = "manual") -> Dictionary:
	var block_reason := get_quick_save_block_reason()
	if block_reason != "":
		write_quick_save_status("Quick save blocked: " + block_reason)
		return {
			"ok": false,
			"reason": block_reason
		}

	if save_manager == null or not save_manager.has_method("save_universe"):
		write_quick_save_status("Quick save failed: save manager unavailable.")
		return {
			"ok": false,
			"reason": "Save manager unavailable."
		}

	if quick_save_in_progress:
		write_quick_save_status("Quick save already running.")
		return {
			"ok": false,
			"reason": "Quick save already running."
		}

	quick_save_in_progress = true
	show_saving_cover_before_save("quick_save_" + reason, false)
	call_deferred("_run_quick_save_after_cover_frame", reason)
	return {
		"ok": true,
		"reason": "Quick save scheduled."
	}


func _run_quick_save_after_cover_frame(reason: String = "manual") -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var saved_ok := bool(save_manager.save_universe(
		star_field,
		map,
		space_objects,
		inventory,
		enemy_handler,
		npc_handler,
		beacons,
		game_event_handler,
		planets,
		player_state
	))

	var message := "Quick save complete."
	if not saved_ok:
		message = "Quick save failed: save file write did not confirm."
	write_quick_save_status(message)
	hide_saving_cover_after_save("quick_save_" + reason)
	print("[QUICK_SAVE] reason=", reason, " saved_ok=", saved_ok)
	quick_save_in_progress = false


func get_quick_save_block_reason() -> String:
	if Globals.battle_mode or Globals.battle_pending or Globals.swap_battle_v2:
		return "finish the battle transition first."
	if Globals.orbit_mode or Globals.orbit_pending or Globals.swap_orbit:
		return "finish the Orbit transition first."
	if Globals.swap_NPC_tran:
		return "finish the NPC transition first."
	return ""


func write_quick_save_status(message: String) -> void:
	if gui_state != null and gui_state.log_storage.has("log_text"):
		gui_state.log_storage["log_text"].text = message


func build_main_command_menu() -> void:
	# Pass 2 extraction:
	# MainMode still owns the boot order, but the command-menu UI, hotkeys,
	# and command dispatch now live in MainCommandController.gd.
	if main_command_controller == null:
		main_command_controller = MainCommandControllerScript.new()

	main_command_controller.setup(self, gui_state, inv_radar_panel, map, star_field,)
	main_command_controller.build_menu()

	# Compatibility refs for older code / debug inspection.
	main_command_menu_root = main_command_controller.menu_root
	main_command_menu_button = main_command_controller.menu_toggle_button
	main_command_menu_action_by_id = main_command_controller.action_by_id


func get_main_command_actions() -> Array:
	if main_command_controller == null:
		main_command_controller = MainCommandControllerScript.new()
	return main_command_controller.get_main_command_actions()


func _on_main_command_menu_id_pressed(id: int) -> void:
	# Compatibility wrapper. New signal ownership lives in MainCommandController.gd.
	if main_command_controller == null:
		return
	main_command_controller.on_menu_id_pressed(id)


func run_main_command_from_key(action_id: String) -> bool:
	if main_command_controller == null:
		main_command_controller = MainCommandControllerScript.new()
	main_command_controller.setup(self, gui_state, inv_radar_panel, map, star_field)
	return main_command_controller.run_command_from_key(action_id)


func run_main_command(action_id: String) -> void:
	if main_command_controller == null:
		main_command_controller = MainCommandControllerScript.new()
	main_command_controller.setup(self, gui_state, inv_radar_panel, map, star_field)
	main_command_controller.run_command(action_id)


func _input(event):
	if not main_mode_boot_complete:
		return

	# Story popups can overlap during authored/test starts. Keyboard close already
	# follows the active popup path, but mouse click routing can hit a stale or
	# lower popup unless main gives the clicked popup priority first.
	if handle_story_popup_mouse_priority_input(event):
		return

	if handle_debug_saving_cover_input(event):
		return

	if controller_focus_manager != null and is_instance_valid(controller_focus_manager):
		if controller_focus_manager.handle_input(event):
			get_viewport().set_input_as_handled()
			return

	if main_command_controller == null:
		main_command_controller = MainCommandControllerScript.new()
	main_command_controller.setup(self, gui_state, inv_radar_panel, map, star_field)
	main_command_controller.handle_input(event)


func handle_story_popup_mouse_priority_input(event) -> bool:
	# Summary: Promote the story popup under the mouse before GUI/button dispatch.
	# If the click is on that popup's close button, manually emit the button so a
	# transparent/stale overlapped Control cannot steal the close click.
	if not (event is InputEventMouseButton):
		return false
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return false
	if gui_state == null or not gui_state.controls.has("popup_root"):
		return false

	var popup_root = gui_state.controls.get("popup_root", null)
	if popup_root == null or not is_instance_valid(popup_root):
		return false
	if not (popup_root is Control):
		return false
	if not popup_root.visible:
		return false

	var mouse_pos: Vector2 = event.position
	var story_window := find_story_popup_window_at_mouse(popup_root as Control, mouse_pos)
	if story_window == null:
		return false

	promote_story_popup_window(story_window, popup_root as Control)

	var close_button := find_story_popup_close_button_at(story_window, mouse_pos)
	if close_button == null:
		return false

	get_viewport().set_input_as_handled()
	dispatch_story_popup_close_button(close_button, story_window, popup_root as Control)
	return true


func find_story_popup_window_at_mouse(popup_root: Control, mouse_pos: Vector2) -> Control:
	var best_window: Control = null
	var best_score := -999999999.0

	for child in popup_root.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if not (child is Control):
			continue

		var control := child as Control
		if not is_story_popup_window_control(control):
			continue
		if not control.is_visible_in_tree():
			continue
		if not control.get_global_rect().has_point(mouse_pos):
			continue

		var score := get_popup_control_priority_score(control)
		if best_window == null or score >= best_score:
			best_window = control
			best_score = score

	return best_window


func is_story_popup_window_control(control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	var control_name := str(control.name)
	if control_name.begins_with("story_popup_window_"):
		return true
	if control.has_meta("story_popup_token") or control.has_meta("popup_token"):
		return true
	if control.has_meta("story_popup_on_close_callable") or control.has_meta("story_popup_on_close_context"):
		return true
	return false


func get_popup_control_priority_score(control: Control) -> float:
	if control == null or not is_instance_valid(control):
		return -999999999.0
	# z_index should dominate. Child index breaks ties for same z layer.
	return float(control.z_index) * 100000.0 + float(control.get_index())


func promote_story_popup_window(story_window: Control, popup_root: Control) -> void:
	if story_window == null or popup_root == null:
		return
	if not is_instance_valid(story_window) or not is_instance_valid(popup_root):
		return

	var highest_z := story_window.z_index
	for child in popup_root.get_children():
		if not (child is Control):
			continue
		var child_control := child as Control
		if is_story_popup_window_control(child_control):
			highest_z = max(highest_z, child_control.z_index)

	story_window.z_index = highest_z + 1
	if story_window.get_parent() == popup_root:
		popup_root.move_child(story_window, popup_root.get_child_count() - 1)

	# Mirror the clicked window's close metadata back to the shared root when it
	# exists. Space-close and older global close paths then follow the same popup
	# the player just selected.
	var selected_token := get_story_popup_token_from_window(story_window)
	var selected_path := str(popup_root.get_path_to(story_window))

	var meta_names := [
		"active_popup_kind",
		"story_popup_space_close_enabled",
		"story_popup_on_close_callable",
		"story_popup_on_close_context",
		"shared_popup_space_close_enabled",
		"shared_popup_kind",
		"story_popup_token",
		"popup_token",
		"event_id",
		"event_step"
	]
	for meta_name in meta_names:
		if story_window.has_meta(meta_name):
			popup_root.set_meta(meta_name, story_window.get_meta(meta_name))

	# The old shared root used one fired flag. With concurrent story popups, that
	# flag can be left true by a different popup and make mouse close appear dead.
	# Keep a window-owned fired flag when present; otherwise reset it when the
	# clicked popup becomes active. The event handler still token-guards close ops.
	if story_window.has_meta("story_popup_on_close_fired"):
		popup_root.set_meta("story_popup_on_close_fired", story_window.get_meta("story_popup_on_close_fired"))
	else:
		popup_root.set_meta("story_popup_on_close_fired", false)

	popup_root.set_meta("active_popup_kind", "story_popup")
	popup_root.set_meta("shared_popup_kind", "story_popup")
	popup_root.set_meta("active_story_popup_window_path", selected_path)
	if selected_token != "":
		popup_root.set_meta("active_story_popup_token", selected_token)


func get_story_popup_token_from_window(story_window: Control) -> String:
	if story_window == null or not is_instance_valid(story_window):
		return ""
	if story_window.has_meta("story_popup_token"):
		return str(story_window.get_meta("story_popup_token")).strip_edges()
	if story_window.has_meta("popup_token"):
		return str(story_window.get_meta("popup_token")).strip_edges()
	return ""


func find_story_popup_close_button_at(story_window: Control, mouse_pos: Vector2) -> Button:
	var best_button: Button = null
	var best_score := -999999999.0
	var stack: Array = [story_window]

	while not stack.is_empty():
		var node = stack.pop_back()
		if node == null or not is_instance_valid(node):
			continue

		for child in node.get_children():
			if child == null or not is_instance_valid(child):
				continue
			if not (child is Control):
				continue

			var control := child as Control
			if not control.is_visible_in_tree():
				continue

			var contains_mouse := control.get_global_rect().has_point(mouse_pos)
			if contains_mouse and control is Button:
				var button := control as Button
				if is_story_popup_close_button(button):
					var score := get_nested_popup_control_priority_score(control, story_window)
					if best_button == null or score >= best_score:
						best_button = button
						best_score = score

			if control.get_child_count() > 0 and (contains_mouse or not control.clip_contents):
				stack.append(control)

	return best_button


func is_story_popup_close_button(button: Button) -> bool:
	if button == null or not is_instance_valid(button):
		return false
	var name_text := str(button.name).to_lower()
	var button_text := str(button.text).strip_edges().to_lower()
	if name_text.find("close") >= 0:
		return true
	if button_text == "close" or button_text == "x" or button_text == "×":
		return true
	return false


func get_nested_popup_control_priority_score(control: Control, story_window: Control) -> float:
	var score := get_popup_control_priority_score(control)
	var node: Node = control
	var depth_weight := 1000.0
	while node != null and node != story_window:
		if node is Control:
			score += float((node as Control).z_index) * depth_weight
		if node.get_parent() != null:
			score += float(node.get_index())
		node = node.get_parent()
		depth_weight *= 0.1
	return score


func dispatch_story_popup_close_button(close_button: Button, story_window: Control, popup_root: Control) -> void:
	if close_button == null or not is_instance_valid(close_button):
		return
	if close_button.disabled:
		return

	promote_story_popup_window(story_window, popup_root)

	var connections := close_button.pressed.get_connections()
	if not connections.is_empty():
		close_button.emit_signal("pressed")
		return

	# Safety fallback for runtime-built story popups whose button connection was
	# lost. This still honors the token/context metadata before freeing the panel.
	close_story_popup_window_from_runtime_meta(story_window, close_button, popup_root, "mouse_close_button_fallback")


func close_story_popup_window_from_runtime_meta(story_window: Control, close_button: Button, popup_root: Control, close_source: String) -> void:
	if story_window == null or not is_instance_valid(story_window):
		return

	var callback = find_first_popup_meta_value([close_button, story_window, popup_root], [
		"story_popup_on_close_callable",
		"on_close_callable"
	])
	var context = find_first_popup_meta_value([close_button, story_window, popup_root], [
		"story_popup_on_close_context",
		"on_close_context"
	])

	if typeof(callback) == TYPE_CALLABLE:
		var close_callable: Callable = callback
		if close_callable.is_valid():
			var close_context: Dictionary = {}
			if typeof(context) == TYPE_DICTIONARY:
				close_context = context.duplicate(true)
			close_context["close_source"] = close_source
			close_callable.call(close_context)

	if is_instance_valid(story_window):
		story_window.queue_free()

	call_deferred("refresh_story_popup_lock_after_manual_close")


func find_first_popup_meta_value(nodes: Array, names: Array):
	for node in nodes:
		if node == null or not is_instance_valid(node):
			continue
		for meta_name in names:
			if node.has_meta(str(meta_name)):
				return node.get_meta(str(meta_name))
	return null


func refresh_story_popup_lock_after_manual_close() -> void:
	if gui_state == null or not gui_state.controls.has("popup_root"):
		return
	var popup_root = gui_state.controls.get("popup_root", null)
	if popup_root == null or not is_instance_valid(popup_root):
		return

	var has_story_popup := false
	for child in popup_root.get_children():
		if not (child is Control):
			continue
		var child_control := child as Control
		if is_story_popup_window_control(child_control) and child_control.is_visible_in_tree():
			has_story_popup = true
			break

	if not has_story_popup:
		Globals.set_popup_input_lock("story_popup", false)


func is_text_input_focused() -> bool:
	if main_command_controller == null:
		main_command_controller = MainCommandControllerScript.new()
	main_command_controller.setup(self, gui_state, inv_radar_panel, map, star_field)
	return main_command_controller.is_text_input_focused()


func get_active_coord_auto_preload_context() -> Dictionary:
	# Summary: Return hidden target context for tier-map/opened target popups.
	# Manual coord popup use returns an empty dictionary and keeps old behavior.
	if typeof(coord_auto_preloaded_target) == TYPE_DICTIONARY and bool(coord_auto_preloaded_target.get("active", false)):
		return coord_auto_preloaded_target.duplicate(true)

	if gui_state != null and gui_state.controls.has("coord_auto_pilot_root"):
		var root = gui_state.controls["coord_auto_pilot_root"]
		if root != null and is_instance_valid(root) and root.has_meta("coord_auto_preloaded_target"):
			var meta_target = root.get_meta("coord_auto_preloaded_target")
			if typeof(meta_target) == TYPE_DICTIONARY and bool(meta_target.get("active", false)):
				return meta_target.duplicate(true)

	return {}


# ==========================================================
# COORD AUTO PILOT ENGAGE
# ----------------------------------------------------------
# Reads the coordinate autopilot popup text boxes and sends
# the target to AutoPilot.gd.
# ==========================================================
func _on_coord_auto_engage_pressed():

	if auto_pilot == null:
		if Globals.print_priority_2:
			print("Coord autopilot failed - auto_pilot is null")
		return

	if gui_state == null:
		if Globals.print_priority_2:
			print("Coord autopilot failed - gui_state is null")
		return

	if has_task_navigation_lock():
		block_autopilot_for_task("Coordinate autopilot")
		return

	var sector_x_box = gui_state.controls["coord_auto_sector_x"]
	var sector_y_box = gui_state.controls["coord_auto_sector_y"]
	var sector_z_box = gui_state.controls["coord_auto_sector_z"]

	var local_x_box = gui_state.controls["coord_auto_local_x"]
	var local_y_box = gui_state.controls["coord_auto_local_y"]
	var local_z_box = gui_state.controls["coord_auto_local_z"]

	var target_sector := Vector3i(
		int(sector_x_box.text),
		int(sector_y_box.text),
		int(sector_z_box.text)
	)

	var target_local := Vector3(
		float(local_x_box.text),
		float(local_y_box.text),
		float(local_z_box.text)
	)

	if Globals.print_priority_3:
		print("COORD AUTO PILOT ENGAGE")
	if Globals.print_priority_3:
		print("Sector target: ", target_sector)
	if Globals.print_priority_3:
		print("Local target: ", target_local)

	var preloaded := get_active_coord_auto_preload_context()
	var is_preloaded_target := not preloaded.is_empty()
	var route_name := str(preloaded.get("display_name", "Manual Coordinate Target")) if is_preloaded_target else "Manual Coordinate Target"
	var route_type := str(preloaded.get("target_type", "coordinate")) if is_preloaded_target else "coordinate"

	if is_preloaded_target:
		# Tier-map rows are real world targets. Use the existing precise target route
		# instead of manual coordinate warp, whose 1000u stop envelope can look like
		# a spin-and-stop when the marker is nearby or inside the current sector.
		auto_pilot.set_impulse_target(
			target_sector,
			target_local,
			route_name,
			route_type
		)
	else:
		auto_pilot.go_to_coords(
			target_sector,
			target_local
		)

	if gui_state.log_storage.has("log_text"):
		var engage_header := "AUTO PILOT TARGET ENGAGED" if is_preloaded_target else "AUTO PILOT ENGAGED"
		gui_state.log_storage["log_text"].text = (
			engage_header + "\n"
			+ "Target: " + route_name + "\n"
			+ "Type: " + route_type + "\n"
			+ "Sector: " + str(target_sector) + "\n"
			+ "Local: " + str(target_local)
		)

	coord_auto_preloaded_target = {}
	Globals.reset_popup_runtime(gui_state, true)
#
func toggle_decorative_overlays() -> void:

	Globals.show_decorative_overlays = not Globals.show_decorative_overlays

	if Globals.print_priority_3:
		print("Decorative overlays visible: ", Globals.show_decorative_overlays)

	if decorative_ui == null:
		if Globals.print_priority_2:
			print("Toggle decorative overlays failed - decorative_ui is null")
		return

	decorative_ui.set_pulse_overlays_visible(
		Globals.show_decorative_overlays
	)


func set_up_new_moves_and_handlers():
	if Globals.print_priority_2:
		print("MAIN | set_up_map")

	map.map_setup(enemy_handler, npc_handler, star_field, space_objects, gui_state, inventory, beacons, planets)
	inv_radar_panel.setup(map, inventory, gui_state.controls.get("blueprint_root", null))
	setup_npc_scene_bridge()
	auto_pilot.setup(star_ui, gui_state)

	# s1.2:
	# Do NOT apply Battle V2 result here.
	# Event handler has not safely finished loading yet.
	

		
		
func setup_battle_v2_bridge() -> void:
	# Summary: Gives BattleV2MainBridge the main-owned references it needs.
	# s1.2: Must include game_event_handler so Battle V2 result saves do not wipe event state.

	battle_v2_bridge.setup({
		"action_manager": action_manager,
		"inventory": inventory,
		"item_handler": item_handler,
		"energy_handler": energy_handler,

		"enemy_handler": enemy_handler,
		"save_manager": save_manager,
		"player_state": player_state,
		"star_field": star_field,
		"map": map,
		"space_objects": space_objects,
		"npc_handler": npc_handler,
		"beacons": beacons,
		"game_event_handler": game_event_handler
	})

	print(
		"[S1.2_MAIN_BRIDGE_WIRED]",
		" game_event_handler=", game_event_handler,
		" active_events=", game_event_handler.active_events.keys() if game_event_handler != null else []
	)
	
func setup_npc_scene_bridge() -> void:
	# Summary: Gives NPCSceneBridge the main-owned references needed for NPC talk scene packets.
	npc_scene_bridge.setup({
		"inventory": inventory,
		"star_field": star_field,
		"map": map,
		"space_objects": space_objects,
		"save_manager": save_manager,
		"enemy_handler": enemy_handler,
		"npc_handler": npc_handler,
		"beacons": beacons,
		"game_event_handler": game_event_handler,
		"player_state": player_state
 	})
	
func find_tracked_npc_for_chat_packet(npc_data: Dictionary) -> NPC:
	# Summary: Find the real tracked NPC from a raw scan/contact packet.

	if npc_handler == null:
		return null

	var wanted_npc_id := str(npc_data.get("npc_id", ""))
	var wanted_blueprint_id := str(npc_data.get("blueprint_id", ""))
	var wanted_name := str(npc_data.get("name", ""))

	for npc in npc_handler.npcs:
		if npc == null:
			continue

		var current_npc_id := str(npc.get_meta("npc_id", ""))
		var current_blueprint_id := str(npc.get_meta("blueprint_id", ""))

		if wanted_npc_id != "" and current_npc_id == wanted_npc_id:
			return npc

		if wanted_blueprint_id != "" and current_blueprint_id == wanted_blueprint_id:
			return npc

		if wanted_name != "" and npc.npc_name == wanted_name:
			return npc

	return null


func setup_event_handler() -> void:
	
	add_child(game_event_handler)

	game_event_handler.setup({
		"star_field": star_field,
		"map": map,
		"space_objects": space_objects,
		"npc_handler": npc_handler,
		"beacons": beacons,
		"enemy_handler": enemy_handler,
		"inventory": inventory,
		"save_manager": save_manager,
		"auto_pilot": auto_pilot,
		"widget_state": gui_state,
		"widget_controller": gui_controller,
		"widget_builder": gui_builder,
		"action_manager": action_manager,
		"task_manager": event_handler,
		"battle_v2_bridge": battle_v2_bridge,
		"main_ui_handler": main_ui_handler,
		"planets": planets
	})
	gui_state.game_event_handler = game_event_handler
	if Globals.print_priority_2:
		print("EventHandler widget_builder = ", gui_builder)
		if gui_builder != null:
			print("EventHandler widget_builder has packet receiver = ", gui_builder.has_method("set_event_widget_packet"))


func process_pending_orbit_event_discoveries() -> Dictionary:
	if save_manager == null or not save_manager.has_method("read_universe_save_data"):
		return {"ok": false, "reason": "save_manager missing read_universe_save_data"}
	if game_event_handler == null or not game_event_handler.has_method("process_orbit_event_discovery_queue"):
		return {"ok": false, "reason": "game_event_handler missing process_orbit_event_discovery_queue"}

	var save_data: Dictionary = save_manager.read_universe_save_data()
	if save_data.is_empty():
		return {"ok": true, "reason": "no save data", "processed_count": 0}

	var queue = save_data.get("orbit_event_discovery_queue", [])
	if typeof(queue) != TYPE_ARRAY or queue.is_empty():
		return {"ok": true, "reason": "no pending orbit event discoveries", "processed_count": 0}

	var result: Dictionary = game_event_handler.process_orbit_event_discovery_queue(queue)
	if int(result.get("processed_count", 0)) <= 0:
		if Globals.print_priority_2:
			print("[ORBIT_EVENT_DISCOVERY] no packets processed | result=", result)
		return result

	var saved_ok := false
	if save_manager.has_method("save_universe"):
		saved_ok = bool(save_manager.save_universe(
			star_field,
			map,
			space_objects,
			inventory,
			enemy_handler,
			npc_handler,
			beacons,
			game_event_handler,
			planets,
			player_state
		))

	result["saved_after_processing"] = saved_ok
	if Globals.print_priority_2:
		print("[ORBIT_EVENT_DISCOVERY] processed=", result.get("processed_count", 0), " silent=", result.get("silent_count", 0), " visible=", result.get("visible_count", 0), " saved=", saved_ok)
	return result


func setup_sound_handler() -> void:
	sound_handler.name = "SoundHandler"
	if sound_handler.get_parent() == null:
		add_child(sound_handler)

	sound_handler.setup(build_sound_handler_refs())


func setup_main_ui_handler() -> void:
	main_ui_handler.name = "Main_UI_Handler"
	if main_ui_handler.get_parent() == null:
		add_child(main_ui_handler)
	main_ui_handler.setup(build_main_ui_handler_refs())
	move_child(main_ui_handler, get_child_count() - 1)


func setup_controller_focus_handler() -> void:
	if controller_focus_overlay == null or not is_instance_valid(controller_focus_overlay):
		controller_focus_overlay = ControllerFocusOverlayScript.new()
	controller_focus_overlay.name = "ControllerFocusOverlay"
	controller_focus_overlay.z_index = ControllerFocusOverlay.TOP_LAYER_Z
	controller_focus_overlay.z_as_relative = false
	controller_focus_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if controller_focus_overlay.get_parent() == null:
		add_child(controller_focus_overlay)

	if controller_focus_manager == null or not is_instance_valid(controller_focus_manager):
		controller_focus_manager = ControllerFocusManagerScript.new()
	controller_focus_manager.name = "ControllerFocusManager"
	if controller_focus_manager.get_parent() == null:
		add_child(controller_focus_manager)

	controller_focus_manager.setup({
		"main_scene": self,
		"gui_state": gui_state,
		"main_left_panel_controller": main_left_panel_controller,
		"action_manager": action_manager,
		"live_map_control": inv_radar_panel.live_map_control if inv_radar_panel != null else null,
		"map": map,
		"port_window": port_window_widget,
		"port_window_backdrop": port_window_backdrop,
		"overlay": controller_focus_overlay
	})

	move_child(controller_focus_overlay, get_child_count() - 1)
	if gui_state != null:
		gui_state.controls["controller_focus_overlay"] = controller_focus_overlay
		gui_state.controls["controller_focus_manager"] = controller_focus_manager


func build_main_ui_handler_refs() -> Dictionary:
	var live_map_control = null
	if inv_radar_panel != null:
		live_map_control = inv_radar_panel.live_map_control
	return {
		"main_scene": self,
		"gui_state": gui_state,
		"controls": gui_state.controls if gui_state != null else {},
		"log_storage": gui_state.log_storage if gui_state != null else {},
		"action_storage": gui_state.action_storage if gui_state != null else {},
		"live_map_control": live_map_control,
		"port_window": port_window_widget,
		"port_window_backdrop": port_window_backdrop,
		"main_command_menu_root": main_command_menu_root,
		"main_command_menu_button": main_command_menu_button,
		"inventory_root": inventory.inventory_root if inventory != null else null,
		"drone_bay_root": inventory.drone_bay_root if inventory != null else null,
		"label_inventory_root": inventory.label_inventory_root if inventory != null else null,
		"ui_helpers": ui_helpers,
		"autostart_guide_trail": true
	}


func show_main_ui_tutorial_prompt(packet: Dictionary) -> void:
	if main_ui_handler == null:
		return
	if not main_ui_handler.has_method("show_guidance_prompt"):
		return
	main_ui_handler.show_guidance_prompt(packet)


func debug_show_main_ui_tutorial_prompt() -> void:
	show_main_ui_tutorial_prompt({
		"title": "NAV TIP",
		"text": "Use the event and action panels together. The guide trail can point at any widget without blocking clicks.",
		"target_point_id": "event_panel",
		"line_to_point_id": "action_panel",
		"duration": 4.0,
		"popup_size": Vector2(300, 118),
		"popup_offset": Vector2(30, -22),
		"draw_line": true,
		"line_color": Color(0.30, 0.92, 1.0, 0.72),
		"circle_color": Color(0.30, 0.92, 1.0, 0.22),
		"circle_radius": 24.0,
		"accent_color": Color(0.30, 0.92, 1.0, 0.95)
	})


func build_sound_handler_refs() -> Dictionary:
	return {
		"main_mode": self,
		"gui_state": gui_state,
		"gui_builder": gui_builder,
		"gui_controller": gui_controller,
		"eng": eng,
		"map": map,
		"star_field": star_field,
		"star_ui": star_ui,
		"fools": fools,
		"item_handler": item_handler,
		"inventory": inventory,
		"star": star,
		"color_handler": color_handler,
		"auto_pilot": auto_pilot,
		"save_manager": save_manager,
		"event_handler": event_handler,
		"action_manager": action_manager,
		
		"enemy": enemy,
		"enemy_handler": enemy_handler,
		"npc_handler": npc_handler,
		"battle_v2_bridge": battle_v2_bridge,
		#"sonic_pi_music_director": sonic_pi_music_director,
		"port_window_widget": port_window_widget,
		"port_window_backdrop": port_window_backdrop,
		"inv_radar_panel": inv_radar_panel,
		"npc_scene_bridge": npc_scene_bridge,
		"widget_spec_ui": widget_spec_ui,
		"game_event_handler": game_event_handler,
		"energy_handler": energy_handler,
		"space_objects": space_objects,
		"beacons": beacons,
		"decorative_ui": decorative_ui,
		"aurora_bg": aurora_bg
	}


# ======================================================
# SMART GUY TEST ENEMY FACTORY
# Paste this near your enemy spawning / put_enemy helper area.
# Then pass the returned enemy into your existing put_enemy/add enemy path.
# ======================================================

func make_smart_guy_enemy(spawn_sector: Vector3i, spawn_local: Vector3) -> Enemy:
	# Summary: Build one predictable Smart Guy 2 enemy for Battle V2 enemy-logic consumable-priority testing.
	var e := Enemy.new()

	# Identity
	e.enemy_name = "Smart Guy 3"
	e.display_name = "Smart Guy 3"
	e.ship_name = "The Correct Answer"
	e.enemy_type = "smart_test_drone"
	e.object_id = "enemy_smart_guy_2_test_001"
	e.object_type = "enemy"
	e.section_id = "test_section"

	# Position
	e.sector_pos = spawn_sector
	e.local_pos = spawn_local

	# World / battle stats
	e.hp = 160
	e.max_hp = 160
	e.attack = 12
	e.energy_max = 0.0
	e.tier = 1

	# Loadout
	e.primary = "vayrax_needler_lance_mk1"
	e.secondary = "smart_guy_calculated_rail"
	e.shield = "smart_guy_mirror_shield"
	e.consumable = "auto_attack_drone_test_mk1"

	# Stackable items/ammo Smart Guy carries.
	# Calculated Rail uses medium ammo. Keep enough ammo for repeated tests.
	e.item_stacks = {
		"smart_guy_calculated_rounds": 0,
		"smart_guy_patch_cell": 1,
		"auto_attack_drone_test_mk1": 3
	}

	# Behavior profile link. This must match EnemyLogic._build_behavior_profiles().
	e.behavior_profile = "smart_guy_3"
	e.behavior_values = {
		"execute_player_threshold": 0.28,
		"explosive_player_threshold": 100.0,
		"repair_hull_threshold": 0.30,
		"critical_hull_evade_threshold": 0.22,
		"low_hull_evade_threshold": 0.45,
		"low_energy_secondary_threshold": 0.35,
		"decision_cooldown": 1.25
	}

	# Light reward and flavor.
	e.reward = ["iron", "cobalt", "smart_guy_calculated_rounds"]
	e.battle_comment = [
		"I calculated twelve endings. You dislike eleven.",
		"Your angle is brave. Not correct. Brave.",
		"Please hold still while I improve the odds."
	]

	# Discovery/event metadata stays simple for test spawning.
	e.is_visible = true
	e.is_discovered = true
	e.is_completed = false
	e.has_event = false
	e.events = []
	e.event_tags = ["test_enemy", "smart_guy_3"]
	e.labels = ["enemy", "test_enemy", "smart_guy_3", "battle_v2_test"]

	# Optional shared meta sync if this script has access to SharedObjectMeta.
	# Safe to comment out if your put_enemy path already handles shared meta.
	e.sync_shared_meta()
	enemy_handler.enemies.append(e)

	print("spawn smart guy 3 | " + str(e))
	for i in enemy_handler.enemies:
		if e.enemy_name == i.enemy_name:
			print("yes")

	return e

func draw_main_ui():
	if main_ui_handler != null:
		if Globals.print_priority_3:
			print("DEBUG ENERGY FRAME | main_ui_handler exists")
		main_ui_handler.show_all_main_hud_energy_frames()
	else:
		if Globals.print_priority_3:
			print("DEBUG ENERGY FRAME | main_ui_handler is NULL")
