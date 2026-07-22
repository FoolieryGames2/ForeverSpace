extends Node




#info i can use for if i change screen size later.  which i just did and wish i 
#already had these ...  lol  and humph...
#---------------------------------------------------------------------------
var screen_w = 1300
var screen_h = 800
var fullscreen_black_backing_layer: CanvasLayer = null
var fullscreen_black_backing_rect: ColorRect = null

var top_padding = 105
var bottom_padding = 25
var left_padding = 95
var right_padding = 25
var between_padding = 25

var pan_size := Vector2(0.0,0.0)

var full_screen = Vector2(1300,700)
var main_layout_preset_name := "fs_right_column_v1"
var main_top_padding = 15
var stacked_widget_gap = 20
var standard_widget_size = Vector2(300, 160)
var wide_widget_size = Vector2((standard_widget_size.x * 2.0) + stacked_widget_gap, standard_widget_size.y)
var layout_col_1_x = 25
var layout_col_2_x = layout_col_1_x + int(standard_widget_size.x) + stacked_widget_gap
var layout_col_3_x = layout_col_2_x + int(standard_widget_size.x) + stacked_widget_gap
var layout_col_4_x = layout_col_3_x + int(standard_widget_size.x) + stacked_widget_gap
var log_widg_pos = Vector2(layout_col_2_x, main_top_padding)
var star_dis_widg_pos = Vector2(layout_col_1_x, main_top_padding)
var eng_widg_pos = Vector2(layout_col_1_x, main_top_padding + int(standard_widget_size.y) + stacked_widget_gap)
var map_widg_pos = eng_widg_pos
var live_map_widg_pos = Vector2(layout_col_4_x, main_top_padding)
var inv_i_widg_pos = Vector2(layout_col_4_x, live_map_widg_pos.y + standard_widget_size.y + stacked_widget_gap)
var inv_d_widg_pos = inv_i_widg_pos
var stat_widg_pos = Vector2(525, 525)
var action_pos = Vector2(layout_col_1_x, 420)
var action_widget_size = standard_widget_size
var todo_widget_size = standard_widget_size
var event_widget_size = standard_widget_size
var nav_widget_size = standard_widget_size
var log_widget_size = standard_widget_size
var star_distance_widget_size = standard_widget_size
var inventory_widget_size = standard_widget_size
var port_window_widget_size = Vector2(300, 160)
var blueprint_widget_size = standard_widget_size
var port_window_drag_enabled := true
var port_window_drag_yaw_min := 0.0
var port_window_drag_yaw_max := 360.0
var port_window_drag_pitch_min := -89.0
var port_window_drag_pitch_max := 89.0
var port_window_drag_sensitivity := 0.45
# Add these lines to your real Globals.gd near your other widget globals.
# This is the only place you need to edit to move the compact AMI Star Chart.
var ami_star_chart_widget_pos := Vector2(650, 600)
var ami_star_chart_widget_size := Vector2(300, 160)

# =========================================================
# Main Mode Cockpit Layout V2
# One left workstation, center forward view, static right stack.
# =========================================================
var main_cockpit_v2_enabled := true

var main_top_strip_pos := Vector2(20, 20)
var main_top_strip_size := Vector2(1260, 42)

var main_left_panel_pos := Vector2(20, 80)
var main_left_panel_size := Vector2(350, 680)

var main_forward_view_pos := Vector2(390, 600)
var main_forward_view_size := Vector2(245, 160)
var main_bottom_log_pos := Vector2(645, 600)
var main_bottom_log_size := Vector2(245, 160)
var main_ai_news_widget_size := Vector2((main_bottom_log_pos.x + main_bottom_log_size.x) - main_forward_view_pos.x, main_forward_view_size.y * 0.5)
var main_ai_news_widget_pos := Vector2(main_forward_view_pos.x, main_forward_view_pos.y - main_ai_news_widget_size.y - 8.0)

var main_right_stack_pos := Vector2(915, 80)
var main_right_widget_size := Vector2(360, 150)
var main_right_stack_bottom := main_forward_view_pos.y + main_forward_view_size.y
var main_right_widget_gap := (main_right_stack_bottom - main_right_stack_pos.y - (main_right_widget_size.y * 4.0)) / 3.0

func get_main_event_widget_pos_v2() -> Vector2:
	return main_right_stack_pos


func get_main_action_widget_pos_v2() -> Vector2:
	return main_right_stack_pos + Vector2(0, main_right_widget_size.y + main_right_widget_gap)


func get_main_todo_widget_pos_v2() -> Vector2:
	return main_right_stack_pos + Vector2(0, (main_right_widget_size.y + main_right_widget_gap) * 2.0)


func get_main_player_stats_widget_pos_v2() -> Vector2:
	return main_right_stack_pos + Vector2(0, (main_right_widget_size.y + main_right_widget_gap) * 3.0)

var aurora_size = Vector2(screen_w , screen_h )
var aurora_pos = Vector2(0,0)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	ensure_fullscreen_black_backing()
	set_process(true)


func _process(_delta: float) -> void:
	sync_fullscreen_black_backing()


func ensure_fullscreen_black_backing() -> void:
	if fullscreen_black_backing_layer == null or not is_instance_valid(fullscreen_black_backing_layer):
		fullscreen_black_backing_layer = CanvasLayer.new()
		fullscreen_black_backing_layer.name = "Fullscreen_Black_Backing_Layer"
		fullscreen_black_backing_layer.layer = -128
		add_child(fullscreen_black_backing_layer)

	if fullscreen_black_backing_rect == null or not is_instance_valid(fullscreen_black_backing_rect):
		fullscreen_black_backing_rect = ColorRect.new()
		fullscreen_black_backing_rect.name = "Fullscreen_Black_Backing"
		fullscreen_black_backing_rect.color = Color.BLACK
		fullscreen_black_backing_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fullscreen_black_backing_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		fullscreen_black_backing_layer.add_child(fullscreen_black_backing_rect)

	sync_fullscreen_black_backing()


func sync_fullscreen_black_backing() -> void:
	if fullscreen_black_backing_rect == null or not is_instance_valid(fullscreen_black_backing_rect):
		return
	var backing_size := Vector2(float(screen_w), float(screen_h))
	var viewport := get_viewport()
	if viewport != null:
		backing_size = viewport.get_visible_rect().size
	fullscreen_black_backing_rect.position = Vector2.ZERO
	fullscreen_black_backing_rect.size = backing_size
	fullscreen_black_backing_rect.offset_left = 0.0
	fullscreen_black_backing_rect.offset_top = 0.0
	fullscreen_black_backing_rect.offset_right = 0.0
	fullscreen_black_backing_rect.offset_bottom = 0.0
#___________________________________________________________________________
var sector_size = 1000

var request_scene : String = ""
var swap_NPC_tran = false
var swap_battle_v2 = false
var swap_orbit = false
#___________________________________________________________________________
var debug = false
var debug_heat_1 = false
var print_priority_1 = false
var print_priority_2 = false
var print_priority_3 = false
var print_priority_4 = false
var print_priority_5 = false
var print_priority_6 = false
var print_priority_7 = false
var print_priority_8 = false
var print_priority_9 = false
var print_priority_controller_support = false
var show_controller_procedural_ui = false
var debug_battleManager = false
var debug_eventManager = false
var debug_statEff = false
var debug_radar = false
var debug_story_popup = false
var debug_story_popup_hide_aurora = false
var debug_story_popup_show_layout = false
var tutorial_story_popup_active := false
var popup_input_lock_sources := {}
var story_popup_text_log: Array = []
var story_popup_text_log_revision := 0
var story_popup_text_log_max_entries := 80
# Called when the node enters the scene tree for the first time.
var weight = 10000

var startup_mode = "new_game"

# ---------------------------------------------------------------------------
# PLAYABLE UNIVERSE LANE SELECTION
# ---------------------------------------------------------------------------
# Universe 1 is the current authored game lane. The start menu sets this once
# before entering main_mode. SaveManager, GameEventsHandler, and WorldSeedBuilder
# read these values so source JSON and saves stay in the selected lane.
var default_universe_id := "universe_1"
var active_universe_id := "universe_1"
var active_universe_display_name := "Universe 1"
var active_universe_description := "Current main Forever Space universe lane. Uses the authored story/events and world seeds."
var active_universe_events_dir := "res://data/universes/universe_1/events"
var active_universe_world_seeds_dir := "res://data/universes/universe_1/world_seeds"
var active_universe_save_lane := "universe_1"
var startup_universe_id := "universe_1"

var available_universe_lanes := [
	{
		"universe_id": "universe_1",
		"display_name": "Main Story",
		"description": "Demo Story Build.",
		"events_dir": "res://data/universes/universe_1/events",
		"world_seeds_dir": "res://data/universes/universe_1/world_seeds",
		"save_lane": "Main Story"
	},
	{
		"universe_id": "universe_2",
		"display_name": "Teir Climb",
		"description": "Enemys everywhere.  Can you beat the boss?.",
		"events_dir": "res://data/universes/universe_2/events",
		"world_seeds_dir": "res://data/universes/universe_2/world_seeds",
		"save_lane": "Teir Climb"
	},
	{
		"universe_id": "universe_3",
		"display_name": "Battle run",
		"description": "Enemys everywhere.  Can you beat the boss?.",
		"events_dir": "res://data/universes/universe_3/events",
		"world_seeds_dir": "res://data/universes/universe_3/world_seeds",
		"save_lane": "Battle run"
	}
]


func get_available_universe_lanes() -> Array:
	return available_universe_lanes.duplicate(true)


func get_default_universe_lane() -> Dictionary:
	return get_universe_lane_by_id(default_universe_id)


func get_universe_lane_by_id(universe_id: String) -> Dictionary:
	var clean_id := str(universe_id).strip_edges()
	for lane in available_universe_lanes:
		if typeof(lane) != TYPE_DICTIONARY:
			continue
		if str(lane.get("universe_id", "")).strip_edges() == clean_id:
			return lane.duplicate(true)

	if available_universe_lanes.size() > 0 and typeof(available_universe_lanes[0]) == TYPE_DICTIONARY:
		return available_universe_lanes[0].duplicate(true)

	return {
		"universe_id": "universe_1",
		"display_name": "Universe 1",
		"description": "Current main Forever Space universe lane.",
		"events_dir": "res://data/universes/universe_1/events",
		"world_seeds_dir": "res://data/universes/universe_1/world_seeds",
		"save_lane": "universe_1"
	}


func set_active_universe_lane(lane_data: Dictionary) -> Dictionary:
	var lane := lane_data.duplicate(true)
	if lane.is_empty():
		lane = get_default_universe_lane()

	var universe_id := str(lane.get("universe_id", default_universe_id)).strip_edges()
	if universe_id == "":
		universe_id = default_universe_id

	active_universe_id = universe_id
	startup_universe_id = universe_id
	active_universe_display_name = str(lane.get("display_name", universe_id)).strip_edges()
	active_universe_description = str(lane.get("description", "")).strip_edges()
	active_universe_events_dir = str(lane.get("events_dir", "res://data/universes/" + universe_id + "/events")).strip_edges()
	active_universe_world_seeds_dir = str(lane.get("world_seeds_dir", "res://data/universes/" + universe_id + "/world_seeds")).strip_edges()
	active_universe_save_lane = str(lane.get("save_lane", universe_id)).strip_edges()
	if active_universe_save_lane == "":
		active_universe_save_lane = universe_id

	if Globals.print_priority_2:
		print("[UNIVERSE_LANE] active id=", active_universe_id, " display=", active_universe_display_name, " save_lane=", active_universe_save_lane)
		print("[UNIVERSE_LANE] events_dir=", active_universe_events_dir)
		print("[UNIVERSE_LANE] world_seeds_dir=", active_universe_world_seeds_dir)

	return get_active_universe_lane_packet()


func set_active_universe_by_id(universe_id: String) -> Dictionary:
	return set_active_universe_lane(get_universe_lane_by_id(universe_id))


func get_active_universe_lane_packet() -> Dictionary:
	return {
		"universe_id": active_universe_id,
		"display_name": active_universe_display_name,
		"description": active_universe_description,
		"events_dir": active_universe_events_dir,
		"world_seeds_dir": active_universe_world_seeds_dir,
		"save_lane": active_universe_save_lane
	}

var sector_pos = Vector3i(0, 0, 0)
var local_pos = Vector3(0, 0, 0)

var yaw = 0.0
var pitch = 0.0
var roll = 0.0

var target_star_label = ''
var target_star_button = ''
var target_star_button_run = false

#var to store the defeated enemy to remove it form the rebuild when switching scenes
var battle_v2_result := {}
var battle_v2_result_pending := false
var last_battle_v2_result := {}

# Sonic Pi background music should only be requested once per game session.
var sonic_pi_music_started := false

# Main-mode music lives on Globals so it can keep playing through normal scene swaps
# like NPC chat. Battle scenes can stop it explicitly.
var main_mode_music_player: AudioStreamPlayer = null
var main_mode_music_stream: AudioStream = null
var main_mode_music_should_loop := false
var main_mode_music_started := false

# Globals.gd
var aurora := AuroraBrainBackground.new()

func ensure_main_mode_music_player() -> AudioStreamPlayer:
	if main_mode_music_player != null and is_instance_valid(main_mode_music_player):
		return main_mode_music_player

	main_mode_music_player = AudioStreamPlayer.new()
	main_mode_music_player.name = "MainModeMusicPlayer"
	main_mode_music_player.bus = "Master"
	add_child(main_mode_music_player)

	if not main_mode_music_player.finished.is_connected(_on_main_mode_music_finished):
		main_mode_music_player.finished.connect(_on_main_mode_music_finished)

	return main_mode_music_player


func play_main_mode_music(stream: AudioStream, should_loop: bool = true) -> bool:
	if stream == null:
		return false

	var player := ensure_main_mode_music_player()
	main_mode_music_stream = stream
	main_mode_music_should_loop = should_loop

	if player.stream != stream:
		player.stream = stream

	if player.playing:
		main_mode_music_started = true
		return false

	player.play()
	main_mode_music_started = true
	return true


func stop_main_mode_music(clear_stream: bool = false) -> void:
	main_mode_music_should_loop = false
	main_mode_music_started = false

	if main_mode_music_player != null and is_instance_valid(main_mode_music_player):
		main_mode_music_player.stop()
		if clear_stream:
			main_mode_music_player.stream = null

	if clear_stream:
		main_mode_music_stream = null


func is_main_mode_music_playing() -> bool:
	return (
		main_mode_music_player != null
		and is_instance_valid(main_mode_music_player)
		and main_mode_music_player.playing
	)


func _on_main_mode_music_finished() -> void:
	if not main_mode_music_should_loop:
		main_mode_music_started = false
		return
	if main_mode_music_stream == null:
		main_mode_music_started = false
		return

	var player := ensure_main_mode_music_player()
	player.stream = main_mode_music_stream
	player.play()
	main_mode_music_started = true

func get_stacked_todo_pos() -> Vector2:
	if main_cockpit_v2_enabled:
		return get_main_todo_widget_pos_v2()
	return Vector2(action_pos.x, action_pos.y + action_widget_size.y + stacked_widget_gap)

func get_event_widget_pos() -> Vector2:
	if main_cockpit_v2_enabled:
		return get_main_event_widget_pos_v2()
	return Vector2(layout_col_3_x, main_top_padding)

func get_port_window_widget_pos() -> Vector2:
	if main_cockpit_v2_enabled:
		return main_forward_view_pos
	var blueprint_pos := get_blueprint_widget_pos()
	return Vector2(blueprint_pos.x, blueprint_pos.y + blueprint_widget_size.y + stacked_widget_gap)

func get_blueprint_widget_pos() -> Vector2:
	if main_cockpit_v2_enabled:
		return main_left_panel_pos
	return Vector2(inv_i_widg_pos.x, inv_i_widg_pos.y + inventory_widget_size.y + stacked_widget_gap)

var star_name_prefix = [
	"Zor", "Vel", "Ar", "Xen", "Sol", "Cry", "Tal", "Vor", "Nyx", "Hel","Rax","Lez"
]

var star_name_core = [
	"a", "on", "aris", "ion", "ea", "os", "ara", "eth", "or", "is","aker", "ono", "az"
]

var star_name_suffix = [
	"", " Prime", " Major", " Minor", " IV", " VII", " IX" ,"Alpha","Beta","Steller"
]



var battle_mode := false
var Let_battle_v1 := false
var Let_battle_v2 := true
var battle_v2_scene_path := "res://Scenes/battle_v2_scene.tscn"
var battle_v2_context := {}
var current_enemy = null
var current_npc = null
var orbit_mode := false
var orbit_pending := false
var orbit_scene_path := "res://Scenes/Orbit.tscn"
var orbit_context := {}
var orbit_last_save_result := {}
var battle_pending := false   # 👈 NEW


var update_star_button_red = false
var engage_enemy = false
var scan_was_clicked = false
# =========================================================
# NPC CHAT RESULT HANDOFF
# ---------------------------------------------------------
# Used by NPC_tran/NPCMain to report changes back to main_mode
# after a full NPC scene switch.
# Example:
# - NPC trade completed
# - can_trade turned false
# - reward already claimed
# =========================================================
var npc_chat_result: Dictionary = {}

var hostile_contact_alert_needed = false
var show_decorative_overlays = false
# ==========================================================
# PLAYER BATTLE ENERGY
# ----------------------------------------------------------
# Energy is used during battle for weapons like pulse laser.
# max_player_energy is the cap.
# player_energy is the current amount available.
# ==========================================================
var max_player_energy := 100
var player_energy := 500

var live_map_target_pos := []
var live_map_is_guided = false

func generate_star_name() -> String:
	var p = star_name_prefix.pick_random()
	var c = star_name_core.pick_random()
	var s = star_name_suffix.pick_random()
	
	if Globals.debug:
		if Globals.print_priority_3:
			print(p + c + s)
	return p + c + s
	
	
	
	
# bool used in main script in auto pilot to togel the action buttons
var run_refresh_inventory = false


func set_popup_input_lock(source_id: String, active: bool) -> void:
	
	var source := source_id.strip_edges()
	if source == "":
		source = "popup"
		
	if print_priority_1:
		print("Globals | set_popup_input_lock | source_id = " + str(source) +"\n" + str(pan_size))

	if active:
		popup_input_lock_sources[source] = true
	else:
		popup_input_lock_sources.erase(source)

	tutorial_story_popup_active = not popup_input_lock_sources.is_empty()


func is_popup_input_locked() -> bool:
	return tutorial_story_popup_active


func record_story_popup_text(story_text: String, title: String = "", context: Dictionary = {}) -> void:
	var clean_text := story_text.strip_edges()
	if clean_text == "":
		return

	var entry := {
		"text": story_text,
		"title": title,
		"event_id": str(context.get("event_id", "")),
		"event_step": str(context.get("event_step", "")),
		"story_popup_token": str(context.get("story_popup_token", context.get("popup_token", ""))),
		"shown_at_unix": int(Time.get_unix_time_from_system()),
		"shown_at_ticks": int(Time.get_ticks_msec())
	}
	story_popup_text_log.append(entry)

	var max_entries = max(int(story_popup_text_log_max_entries), 1)
	while story_popup_text_log.size() > max_entries:
		story_popup_text_log.remove_at(0)

	story_popup_text_log_revision += 1


func get_story_popup_text_log() -> Array:
	return story_popup_text_log.duplicate(true)


func get_story_popup_text_log_revision() -> int:
	return story_popup_text_log_revision


func clear_story_popup_text_log() -> void:
	story_popup_text_log.clear()
	story_popup_text_log_revision += 1


func reset_popup_runtime(state: WidgetsState5, hide_popup: bool = false) -> void:
	set_popup_input_lock("story_popup", false)
	set_popup_input_lock("battle_loadout_popup", false)
	set_popup_input_lock("named_save_popup", false)

	if state == null:
		return
	if not state.controls.has("popup_root"):
		return

	var popup = state.controls["popup_root"]
	if popup == null or not is_instance_valid(popup):
		return

	release_popup_keyboard_focus(state)

	for child in popup.get_children():
		if child is Control and str(child.name).begins_with("story_popup_window_"):
			popup.remove_child(child)
			child.queue_free()

	var scrim = popup.get_node_or_null("story_popup_focus_scrim")
	if scrim != null and is_instance_valid(scrim):
		scrim.visible = false
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for timer_name in ["story_popup_auto_close_timer", "story_popup_countdown_timer"]:
		var timer = popup.get_node_or_null(timer_name)
		if timer != null and is_instance_valid(timer):
			timer.stop()
			popup.remove_child(timer)
			timer.queue_free()

	for meta_name in [
		"active_popup_kind",
		"story_popup_space_close_enabled",
		"story_popup_on_close_fired",
		"story_popup_on_close_callable",
		"story_popup_on_close_context",
		"shared_popup_space_close_enabled",
		"shared_popup_kind"
	]:
		if popup.has_meta(meta_name):
			popup.remove_meta(meta_name)

	resize_popup_root(popup)

	var panel = popup.get_node_or_null("popup_panel")
	if panel != null and is_instance_valid(panel):
		panel.visible = true
		var panel_runtime_names := [
			"story_popup_content",
			"settings_handler_root",
			"coord_auto_pilot_root",
			"battle_loadout_popup_root",
			"named_save_popup_root"
		]
		for child_name in panel_runtime_names:
			var child = panel.get_node_or_null(child_name)
			if child != null and is_instance_valid(child):
				panel.remove_child(child)
				child.queue_free()

		configure_popup_panel(state, Vector2(475, 350))

	var popup_runtime_names := [
		"coord_auto_pilot_root",
		"battle_loadout_popup_root",
		"named_save_popup_root"
	]
	for child_name in popup_runtime_names:
		var child = popup.get_node_or_null(child_name)
		if child != null and is_instance_valid(child):
			popup.remove_child(child)
			child.queue_free()

	clear_popup_state_refs(state)

	if state.labels.has("popup_text"):
		var popup_text = state.labels["popup_text"]
		if popup_text != null and is_instance_valid(popup_text):
			popup_text.clear()
			popup_text.visible = true

	if state.labels.has("popup_title"):
		var popup_title = state.labels["popup_title"]
		if popup_title != null and is_instance_valid(popup_title):
			popup_title.text = "INFO"
			popup_title.visible = true

	if state.buttons.has("popup_close"):
		var close_btn = state.buttons["popup_close"]
		if close_btn != null and is_instance_valid(close_btn):
			close_btn.text = "CLOSE"
			close_btn.size = Vector2(100, 30)
			if panel != null and is_instance_valid(panel):
				close_btn.position = Vector2(panel.size.x - 110, panel.size.y - 40)
			close_btn.z_index = 40
			close_btn.visible = true

	if hide_popup:
		popup.visible = false


func clear_popup_state_refs(state: WidgetsState5) -> void:
	var runtime_prefixes := [
		"coord_auto_",
		"settings_",
		"battle_loadout_",
		"named_save_",
		"story_popup_",
		"event_list_popup_"
	]
	var runtime_keys := [
		"coord_auto_pilot_root",
		"settings_handler_root",
		"battle_loadout_popup_root",
		"named_save_popup_root"
	]

	clear_state_dictionary_keys(state.controls, runtime_prefixes, runtime_keys)
	clear_state_dictionary_keys(state.labels, runtime_prefixes, runtime_keys)
	clear_state_dictionary_keys(state.buttons, runtime_prefixes, runtime_keys)
	clear_state_dictionary_keys(state.color_rects, runtime_prefixes, runtime_keys)
	clear_story_popup_runtime_state_keys(state.controls)
	clear_story_popup_runtime_state_keys(state.labels)
	clear_story_popup_runtime_state_keys(state.buttons)
	clear_story_popup_runtime_state_keys(state.color_rects)


func clear_story_popup_runtime_state_keys(dict: Dictionary) -> void:
	var keys_to_remove := []
	for key in dict.keys():
		var key_text := str(key)
		if key_text.begins_with("story_popup_window_") or key_text.find("_story_popup_") >= 0:
			keys_to_remove.append(key)

	for key in keys_to_remove:
		dict.erase(key)


func clear_state_dictionary_keys(dict: Dictionary, prefixes: Array, exact_keys: Array) -> void:
	var keys_to_remove := []
	for key in dict.keys():
		var key_text := str(key)
		var should_remove := exact_keys.has(key_text)
		if not should_remove:
			for prefix in prefixes:
				if key_text.begins_with(str(prefix)):
					should_remove = true
					break
		if should_remove:
			keys_to_remove.append(key)

	for key in keys_to_remove:
		dict.erase(key)




func get_popup_overlay_size() -> Vector2:
	return Vector2(float(screen_w), float(screen_h))


func resize_popup_root(popup: Control) -> void:
	if popup == null or not is_instance_valid(popup):
		return
	popup.position = Vector2.ZERO
	popup.size = get_popup_overlay_size()
	for child in popup.get_children():
		var child_name := str(child.name)
		if child is Control and (
			child_name == "popup_overlay_bg"
			or child_name == "popup_aurora_background"
			or child_name == "story_popup_focus_scrim"
		):
			child.position = Vector2.ZERO
			child.size = popup.size


func release_popup_keyboard_focus(state: WidgetsState5) -> void:
	if state == null or not state.controls.has("popup_root"):
		return
	var popup = state.controls["popup_root"]
	if popup == null or not is_instance_valid(popup):
		return
	var viewport = popup.get_viewport()
	if viewport == null:
		return
	var focused = viewport.gui_get_focus_owner()
	if focused != null and is_instance_valid(focused):
		focused.release_focus()


func set_shared_popup_space_close_enabled(state: WidgetsState5, enabled: bool, popup_kind: String = "info") -> void:
	if state == null or not state.controls.has("popup_root"):
		return
	var popup = state.controls["popup_root"]
	if popup == null or not is_instance_valid(popup):
		return

	popup.set_meta("shared_popup_space_close_enabled", enabled)
	popup.set_meta("shared_popup_kind", popup_kind if enabled else "")
	release_popup_keyboard_focus(state)


func configure_popup_panel(
	state: WidgetsState5,
	panel_size: Vector2,
	accent: Color = Color(0.30, 0.92, 1.0, 0.86),
	aurora_name: String = "popup_panel_aurora_background",
	frame_name: String = "popup_panel_theme_frame"
):
	if state == null:
		return null
	if not state.controls.has("popup_root"):
		return null

	var popup = state.controls["popup_root"]
	if popup == null or not is_instance_valid(popup):
		return null

	resize_popup_root(popup)

	var panel = popup.get_node_or_null("popup_panel")
	if panel == null or not is_instance_valid(panel):
		return null

	panel.size = panel_size
	pan_size = panel.size
	panel.position = (popup.size - panel.size) / 2
	clear_popup_panel_theme_siblings(panel, aurora_name, frame_name)
	apply_popup_panel_theme(panel, panel_size, accent, aurora_name, frame_name)

	if state.labels.has("popup_title"):
		var popup_title = state.labels["popup_title"]
		if popup_title != null and is_instance_valid(popup_title):
			popup_title.position = Vector2(18, 14)
			popup_title.size = Vector2(max(panel_size.x - 136.0, 140.0), 24)
			popup_title.z_index = 30
			popup_title.visible = true

	if state.labels.has("popup_text"):
		var popup_text = state.labels["popup_text"]
		if popup_text != null and is_instance_valid(popup_text):
			popup_text.position = Vector2(18, 48)
			popup_text.size = Vector2(max(panel_size.x - 36.0, 180.0), max(panel_size.y - 104.0, 90.0))
			popup_text.z_index = 30
			popup_text.visible = true

	if state.buttons.has("popup_close"):
		var close_btn = state.buttons["popup_close"]
		if close_btn != null and is_instance_valid(close_btn):
			close_btn.text = "CLOSE"
			close_btn.size = Vector2(100, 30)
			close_btn.position = Vector2(panel_size.x - 116, panel_size.y - 42)
			close_btn.z_index = 40
			close_btn.visible = true
			if close_btn.get_parent() == panel:
				panel.move_child(close_btn, panel.get_child_count() - 1)

	return panel


func clear_popup_panel_theme_siblings(panel: Control, aurora_name: String, frame_name: String) -> void:
	# Summary: Keep one themed frame/background on a reusable popup panel when popup types swap.
	if panel == null or not is_instance_valid(panel):
		return

	for child in panel.get_children():
		if child == null or not is_instance_valid(child):
			continue
		var child_name := str(child.name)
		var is_theme_frame := child_name.ends_with("_theme_frame") or child_name == "popup_panel_theme_frame"
		var is_panel_aurora := child_name.ends_with("_aurora_background") or child_name == "popup_panel_aurora_background"
		var should_remove := false
		if is_theme_frame and child_name != frame_name:
			should_remove = true
		if is_panel_aurora and child_name != aurora_name:
			should_remove = true
		if should_remove:
			panel.remove_child(child)
			child.queue_free()


func apply_popup_panel_theme(
	panel: Control,
	panel_size: Vector2,
	accent: Color = Color(0.30, 0.92, 1.0, 0.86),
	aurora_name: String = "popup_panel_aurora_background",
	frame_name: String = "popup_panel_theme_frame"
) -> void:
	if panel == null or not is_instance_valid(panel):
		return

	panel.clip_contents = true

	if panel is ColorRect:
		var rect := panel as ColorRect
		rect.color = Color(0.018, 0.034, 0.064, 0.86)

	var aurora = panel.get_node_or_null(aurora_name)
	if aurora == null or not is_instance_valid(aurora):
		aurora = AuroraBrainBackground.new()
		aurora.name = aurora_name
		aurora.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aurora.node_count = 28
		aurora.connection_distance = 120.0
		aurora.node_radius = 2.3
		panel.add_child(aurora)
		panel.move_child(aurora, 0)

	aurora.position = Vector2.ZERO
	aurora.size = panel_size
	aurora.z_index = 0
	aurora.modulate.a = 0.72

	var frame = panel.get_node_or_null(frame_name)
	if frame == null or not is_instance_valid(frame):
		frame = Panel.new()
		frame.name = frame_name
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(frame)

	frame.position = Vector2.ZERO
	frame.size = panel_size
	frame.z_index = 12

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = accent
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.48)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 5)
	frame.add_theme_stylebox_override("panel", style)


func show_popup(state: WidgetsState5, message: String):

	if Globals.print_priority_3:
		print("LABEL KEYS: ", state.labels.keys())

	var popup = state.controls["popup_root"]
	reset_popup_runtime(state)

	# ==========================================================
	# POPUP AURORA BACKGROUND
	# ----------------------------------------------------------
	# Create the animated background only once.
	# Do NOT make a new one every time the popup opens.
	# ==========================================================
	if not popup.has_node("popup_aurora_background"):

		var popup_aurora := AuroraBrainBackground.new()
		popup_aurora.name = "popup_aurora_background"
		popup_aurora.position = Vector2.ZERO
		popup_aurora.size = popup.size
		popup_aurora.z_index = 0
		popup_aurora.mouse_filter = Control.MOUSE_FILTER_IGNORE

		popup.add_child(popup_aurora)
		popup.move_child(popup_aurora, 0)

	# Keep the background matched to the popup size.
	var bg = popup.get_node("popup_aurora_background")
	bg.position = Vector2.ZERO
	bg.size = popup.size
	bg.z_index = 0

	var panel = popup.get_node_or_null("popup_panel")
	if panel != null and is_instance_valid(panel):
		configure_popup_panel(state, panel.size)

	state.labels["popup_text"].clear()
	state.labels["popup_text"].append_text(message)
	state.labels["popup_text"].visible = true
	state.labels["popup_text"].z_index = 30

	if state.controls.has("settings_handler_root"):
		var settings_root = state.controls["settings_handler_root"]
		if settings_root != null and is_instance_valid(settings_root):
			settings_root.visible = false

	popup.position = Vector2.ZERO
	popup.z_index = 999

	if popup.get_parent() != null:
		popup.get_parent().move_child(popup, popup.get_parent().get_child_count() - 1)

	set_shared_popup_space_close_enabled(state, true, "info")
	popup.visible = true
	
func setup_npc(npc):
	if npc == null:
		if Globals.print_priority_3:
			print("NO NPC DATA")
		return

	var name = "UNKNOWN"
	var sector = Vector3i.ZERO
	var local = Vector3.ZERO

	# 🟢 If it's a Dictionary
	if npc is Dictionary:
		name = npc.get("name", "UNKNOWN")
		sector = npc.get("sector", Vector3i.ZERO)
		local = npc.get("local", Vector3.ZERO)

	# 🔵 If it's an NPC Node
	elif npc is NPC:
		name = npc.npc_name
		sector = npc.sector_pos
		local = npc.local_pos

	else:
		if Globals.print_priority_1:
			print("UNKNOWN NPC TYPE:", typeof(npc))
		return

	if Globals.print_priority_2:
		print("NPC LOADED:")
	if Globals.print_priority_3:
		print("Name:", name)
	if Globals.print_priority_3:
		print("Sector:", sector)
	if Globals.print_priority_3:
		print("Local:", local)


func clear_battle_v2_transition_state(keep_result: bool = false) -> void:
	swap_battle_v2 = false
	battle_mode = false
	battle_pending = false

	if typeof(battle_v2_context) == TYPE_DICTIONARY:
		battle_v2_context.clear()
	else:
		battle_v2_context = {}

	if not keep_result:
		if typeof(battle_v2_result) == TYPE_DICTIONARY:
			battle_v2_result.clear()
		else:
			battle_v2_result = {}

		if typeof(last_battle_v2_result) == TYPE_DICTIONARY:
			last_battle_v2_result.clear()
		else:
			last_battle_v2_result = {}


func clear_orbit_transition_state(keep_last_result: bool = true) -> void:
	swap_orbit = false
	orbit_mode = false
	orbit_pending = false

	if typeof(orbit_context) == TYPE_DICTIONARY:
		orbit_context.clear()
	else:
		orbit_context = {}

	if not keep_last_result:
		if typeof(orbit_last_save_result) == TYPE_DICTIONARY:
			orbit_last_save_result.clear()
		else:
			orbit_last_save_result = {}
