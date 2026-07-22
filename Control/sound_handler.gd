extends Node
class_name SoundHandler


# Best first sound test:
# 1. Put a short .wav or .ogg under res://audio/ui/.
# 2. Replace the null below with a preload, for example:
#    var log_text_changed_stream: AudioStream = preload("res://audio/ui/log_text_changed.wav")
# 3. Do the same for button_hover_stream, button_clicked_stream, auto_pilot_start_burn_stream,
#    auto_pilot_cut_out_stream, and main_mode_startup_music_stream.
# 4. Keep new game sounds routed through this handler so main_mode only wires refs and calls process.
var log_text_changed_stream: AudioStream = preload("res://audio/ui/pepSound5.mp3")
var button_hover_stream: AudioStream = preload("res://audio/ui/lowRandom.mp3")
var button_clicked_stream: AudioStream = preload("res://audio/ui/zap1.mp3")
var auto_pilot_start_burn_stream: AudioStream = preload("res://audio/ui/spaceflight3.wav")
var auto_pilot_cut_out_stream: AudioStream = preload("res://audio/ui/MachinePowerOff.ogg")
var main_mode_startup_music_stream: AudioStream = preload("res://audio/ui/Blue Space v0_95.mp3")
var output_bus := "Master"
var music_bus := "Master"
var log_text_change_cooldown_seconds := 0.05
var button_hover_cooldown_seconds := 0.03
var button_click_cooldown_seconds := 0.02
var button_scan_interval_seconds := 0.35

var refs: Dictionary = {}
var main_mode_ref = null
var gui_state: WidgetsState5 = null
var gui_builder = null
var gui_controller = null
var eng = null
var map_ref = null
var star_field = null
var star_ui = null
var fools = null
var item_handler = null
var inventory = null
var star = null
var color_handler = null
var auto_pilot = null
var save_manager = null
var event_handler = null
var action_manager = null
var battle_manager = null
var enemy = null
var enemy_handler = null
var npc_handler = null
var battle_v2_bridge = null
var sonic_pi_music_director = null
var port_window_widget = null
var port_window_backdrop = null
var inv_radar_panel = null
var npc_scene_bridge = null
var widget_spec_ui = null
var game_event_handler = null
var energy_handler = null
var space_objects = null
var beacons = null
var decorative_ui = null
var aurora_bg = null

var ui_sound_player: AudioStreamPlayer = null
var button_sound_player: AudioStreamPlayer = null
var music_player: AudioStreamPlayer = null
var engine_sound_player: AudioStreamPlayer = null
var last_log_text := ""
var log_text_watch_primed := false
var auto_pilot_watch_primed := false
var last_auto_pilot_enabled := false
var auto_pilot_has_been_enabled := false
var button_scan_timer := 0.0
var tracked_button_ids: Dictionary = {}
var once_locks: Dictionary = {}
var once_tokens: Dictionary = {}
var last_play_msec_by_key: Dictionary = {}
var missing_stream_warnings: Dictionary = {}


func setup(new_refs: Dictionary) -> void:
	refs = new_refs.duplicate()
	main_mode_ref = refs.get("main_mode", null)
	gui_state = refs.get("gui_state", null)
	gui_builder = refs.get("gui_builder", null)
	gui_controller = refs.get("gui_controller", null)
	eng = refs.get("eng", null)
	map_ref = refs.get("map", null)
	star_field = refs.get("star_field", null)
	star_ui = refs.get("star_ui", null)
	fools = refs.get("fools", null)
	item_handler = refs.get("item_handler", null)
	inventory = refs.get("inventory", null)
	star = refs.get("star", null)
	color_handler = refs.get("color_handler", null)
	auto_pilot = refs.get("auto_pilot", null)
	save_manager = refs.get("save_manager", null)
	event_handler = refs.get("event_handler", null)
	action_manager = refs.get("action_manager", null)
	battle_manager = refs.get("battle_manager", null)
	enemy = refs.get("enemy", null)
	enemy_handler = refs.get("enemy_handler", null)
	npc_handler = refs.get("npc_handler", null)
	battle_v2_bridge = refs.get("battle_v2_bridge", null)
	sonic_pi_music_director = refs.get("sonic_pi_music_director", null)
	port_window_widget = refs.get("port_window_widget", null)
	port_window_backdrop = refs.get("port_window_backdrop", null)
	inv_radar_panel = refs.get("inv_radar_panel", null)
	npc_scene_bridge = refs.get("npc_scene_bridge", null)
	widget_spec_ui = refs.get("widget_spec_ui", null)
	game_event_handler = refs.get("game_event_handler", null)
	energy_handler = refs.get("energy_handler", null)
	space_objects = refs.get("space_objects", null)
	beacons = refs.get("beacons", null)
	decorative_ui = refs.get("decorative_ui", null)
	aurora_bg = refs.get("aurora_bg", null)

	ensure_audio_players()
	prime_log_text_watch()
	prime_auto_pilot_watch()
	register_known_buttons()
	play_main_mode_startup_music_once()


func process_sound_handler(delta: float) -> void:
	watch_log_text_change()
	watch_auto_pilot_enabled_change()
	update_button_registration(delta)


func ensure_audio_players() -> void:
	if ui_sound_player == null or not is_instance_valid(ui_sound_player):
		ui_sound_player = AudioStreamPlayer.new()
		ui_sound_player.name = "UISoundPlayer"
		ui_sound_player.bus = output_bus
		add_child(ui_sound_player)

	if button_sound_player == null or not is_instance_valid(button_sound_player):
		button_sound_player = AudioStreamPlayer.new()
		button_sound_player.name = "ButtonSoundPlayer"
		button_sound_player.bus = output_bus
		add_child(button_sound_player)

	if music_player == null or not is_instance_valid(music_player):
		music_player = AudioStreamPlayer.new()
		music_player.name = "MusicPlayer"
		music_player.bus = music_bus
		add_child(music_player)

	if engine_sound_player == null or not is_instance_valid(engine_sound_player):
		engine_sound_player = AudioStreamPlayer.new()
		engine_sound_player.name = "EngineSoundPlayer"
		engine_sound_player.bus = output_bus
		add_child(engine_sound_player)


func update_button_registration(delta: float) -> void:
	button_scan_timer += delta
	if button_scan_timer < button_scan_interval_seconds:
		return

	button_scan_timer = 0.0
	register_known_buttons()


func register_known_buttons() -> void:
	register_buttons_from_gui_state()
	if main_mode_ref != null and is_instance_valid(main_mode_ref):
		register_buttons_from_node(main_mode_ref)


func register_buttons_from_gui_state() -> void:
	if gui_state == null:
		return

	for button_key in gui_state.buttons.keys():
		register_button_source(gui_state.buttons[button_key])

	for control_key in gui_state.controls.keys():
		register_button_source(gui_state.controls[control_key])


func register_buttons_from_node(root_node: Node) -> void:
	for child in root_node.get_children():
		if child is Button:
			register_button(child)
		register_buttons_from_node(child)


func register_button_source(source) -> void:
	if source == null:
		return

	if source is Button:
		register_button(source)
		return

	if source is Dictionary:
		for key in source.keys():
			register_button_source(source[key])
		return

	if source is Array:
		for item in source:
			register_button_source(item)
		return


func register_button(button) -> void:
	if not button is Button:
		return
	if not is_instance_valid(button):
		return

	var button_id := str(button.get_instance_id())
	if tracked_button_ids.has(button_id):
		return

	tracked_button_ids[button_id] = true
	button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	button.pressed.connect(_on_button_pressed.bind(button))


func _on_button_mouse_entered(_button: Button) -> void:
	play_sound("button_hover", button_hover_stream, button_hover_cooldown_seconds)


func _on_button_pressed(_button: Button) -> void:
	play_sound("button_clicked", button_clicked_stream, button_click_cooldown_seconds)


func prime_auto_pilot_watch() -> void:
	last_auto_pilot_enabled = is_auto_pilot_enabled()
	auto_pilot_has_been_enabled = last_auto_pilot_enabled
	auto_pilot_watch_primed = true


func watch_auto_pilot_enabled_change() -> void:
	if not auto_pilot_watch_primed:
		prime_auto_pilot_watch()
		return

	var current_enabled := is_auto_pilot_enabled()
	if current_enabled == last_auto_pilot_enabled:
		return

	var previous_enabled := last_auto_pilot_enabled
	last_auto_pilot_enabled = current_enabled

	if current_enabled:
		auto_pilot_has_been_enabled = true
		play_sound("auto_pilot_start_burn", auto_pilot_start_burn_stream)
		return

	if previous_enabled and auto_pilot_has_been_enabled:
		if engine_sound_player != null and is_instance_valid(engine_sound_player):
			engine_sound_player.stop()
		play_sound("auto_pilot_cut_out", auto_pilot_cut_out_stream)


func is_auto_pilot_enabled() -> bool:
	if auto_pilot == null or not is_instance_valid(auto_pilot):
		return false
	return bool(auto_pilot.enabled)


func prime_log_text_watch() -> void:
	last_log_text = get_log_text()
	log_text_watch_primed = true


func watch_log_text_change() -> void:
	if not log_text_watch_primed:
		prime_log_text_watch()
		return

	var current_log_text := get_log_text()
	if current_log_text == last_log_text:
		return

	last_log_text = current_log_text
	var token := str(hash(current_log_text))
	play_once_for_token(
		"log_text_changed",
		token,
		log_text_changed_stream,
		log_text_change_cooldown_seconds
	)


func get_log_text() -> String:
	if gui_state == null:
		return ""
	if not gui_state.log_storage.has("log_text"):
		return ""

	var log_text_control = gui_state.log_storage["log_text"]
	if log_text_control == null or not is_instance_valid(log_text_control):
		return ""

	return str(log_text_control.get("text"))


func play_once(sound_key: String, stream: AudioStream = null, cooldown_seconds: float = 0.0) -> bool:
	if bool(once_locks.get(sound_key, false)):
		return false
	if not can_play_by_cooldown(sound_key, cooldown_seconds):
		return false

	var did_play := play_sound(sound_key, stream)
	if did_play:
		once_locks[sound_key] = true
	return did_play


func reset_once(sound_key: String) -> void:
	once_locks.erase(sound_key)


func play_once_for_token(
	sound_key: String,
	token: String,
	stream: AudioStream = null,
	cooldown_seconds: float = 0.0
) -> bool:
	if str(once_tokens.get(sound_key, "")) == token:
		return false
	if not can_play_by_cooldown(sound_key, cooldown_seconds):
		return false

	var did_play := play_sound(sound_key, stream)
	if did_play:
		once_tokens[sound_key] = token
	return did_play


func play_sound(sound_key: String, stream: AudioStream = null, cooldown_seconds: float = 0.0) -> bool:
	ensure_audio_players()
	if not can_play_by_cooldown(sound_key, cooldown_seconds):
		return false

	var stream_to_play := stream
	if stream_to_play == null:
		stream_to_play = get_stream_for_key(sound_key)

	if stream_to_play == null:
		warn_missing_stream_once(sound_key)
		return false

	var player := get_player_for_key(sound_key)
	if not can_play_with_player(player):
		return false

	player.stream = stream_to_play
	player.play()
	last_play_msec_by_key[sound_key] = Time.get_ticks_msec()
	return true


func can_play_with_player(player: AudioStreamPlayer) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if not is_inside_tree():
		return false
	if not player.is_inside_tree():
		return false
	return true


func get_player_for_key(sound_key: String) -> AudioStreamPlayer:
	if sound_key == "button_hover" or sound_key == "button_clicked":
		return button_sound_player
	if sound_key == "auto_pilot_start_burn" or sound_key == "auto_pilot_cut_out":
		return engine_sound_player
	if sound_key == "main_mode_startup_music":
		return music_player
	return ui_sound_player


func get_stream_for_key(sound_key: String) -> AudioStream:
	match sound_key:
		"log_text_changed":
			return log_text_changed_stream
		"button_hover":
			return button_hover_stream
		"button_clicked":
			return button_clicked_stream
		"auto_pilot_start_burn":
			return auto_pilot_start_burn_stream
		"auto_pilot_cut_out":
			return auto_pilot_cut_out_stream
		"main_mode_startup_music":
			return main_mode_startup_music_stream
		_:
			return null


func play_main_mode_startup_music_once() -> bool:
	if main_mode_startup_music_stream == null:
		warn_missing_stream_once("main_mode_startup_music")
		return false

	var did_play := Globals.play_main_mode_music(main_mode_startup_music_stream, true)
	if not did_play and not Globals.is_main_mode_music_playing():
		return false

	once_locks["main_mode_startup_music"] = true
	last_play_msec_by_key["main_mode_startup_music"] = Time.get_ticks_msec()
	return true


func can_play_by_cooldown(sound_key: String, cooldown_seconds: float) -> bool:
	if cooldown_seconds <= 0.0:
		return true

	var now_msec := Time.get_ticks_msec()
	var last_msec := int(last_play_msec_by_key.get(sound_key, -1000000000))
	var cooldown_msec := int(round(cooldown_seconds * 1000.0))
	return now_msec - last_msec >= cooldown_msec


func warn_missing_stream_once(sound_key: String) -> void:
	if bool(missing_stream_warnings.get(sound_key, false)):
		return

	missing_stream_warnings[sound_key] = true
	print("[SoundHandler] Missing stream for sound key: ", sound_key, ". Add a preload in sound_handler.gd.")
