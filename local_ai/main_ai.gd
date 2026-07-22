extends Node
class_name MainAI

signal news_updated(packet)

const LocalAITalkerScript = preload("res://local_ai/local_ai_talker.gd")
const DEBUG_PREFIX := "[MAIN_AI]"
const DEFAULT_MIN_DELAY_SECONDS := 10.0
const DEFAULT_MAX_DELAY_SECONDS := 20.0
const COMMENTARY_MIN_DELAY_SECONDS := 7.0
const TICKER_START_SYMBOL := ">>"
const TICKER_END_SYMBOL := "<<"

var main_mode_ref: Node = null
var gui_state: WidgetsState5 = null
var local_ai_talker: LocalAITalker = null
var cycle_timer: Timer = null
var rng := RandomNumberGenerator.new()

var enabled := true
var random_news_enabled := true
var debug_prints := true
var server_ready := false
var has_started := false
var pending := false
var cycle_index := 0
var min_delay_seconds := DEFAULT_MIN_DELAY_SECONDS
var max_delay_seconds := DEFAULT_MAX_DELAY_SECONDS
var ticker_speed_pixels_per_second := 55.0
var ticker_gap_pixels := 72.0
var ticker_text := ""
var ticker_offset_x := 0.0
var ticker_label_width := 0.0
var pending_request_kind := ""
var pending_commentary_context: Dictionary = {}
var commentary_index := 0
var last_commentary_request_msec := -1000000


func setup(new_main_mode_ref: Node, new_gui_state: WidgetsState5) -> void:
	main_mode_ref = new_main_mode_ref
	gui_state = new_gui_state
	rng.randomize()
	ensure_talker()
	ensure_timer()
	update_news_widget("STANDBY", "DRIFTWIRE local news link is warming up.")
	if random_news_enabled:
		schedule_next_cycle(6.0, "initial_bootstrap_probe")
	set_process(true)
	debug_print("setup complete")


func _process(delta: float) -> void:
	process_news_ticker(delta)


func ensure_talker() -> void:
	if local_ai_talker == null or not is_instance_valid(local_ai_talker):
		local_ai_talker = LocalAITalkerScript.new()
		local_ai_talker.name = "MainAILocalTalker"
		add_child(local_ai_talker)

	if not local_ai_talker.reply_received.is_connected(_on_ai_reply_received):
		local_ai_talker.reply_received.connect(_on_ai_reply_received)
	if not local_ai_talker.request_failed.is_connected(_on_ai_request_failed):
		local_ai_talker.request_failed.connect(_on_ai_request_failed)
	if not local_ai_talker.status_changed.is_connected(_on_ai_status_changed):
		local_ai_talker.status_changed.connect(_on_ai_status_changed)

	local_ai_talker.setup()


func ensure_timer() -> void:
	if cycle_timer != null and is_instance_valid(cycle_timer):
		return

	cycle_timer = Timer.new()
	cycle_timer.name = "MainAINewsCycleTimer"
	cycle_timer.one_shot = true
	add_child(cycle_timer)
	cycle_timer.timeout.connect(_on_cycle_timer_timeout)


func handle_server_status(packet: Dictionary) -> void:
	var state_text := str(packet.get("state", "")).strip_edges()
	var message := str(packet.get("message", "")).strip_edges()
	var data = packet.get("data", {})
	var inference_ready := false
	if typeof(data) == TYPE_DICTIONARY:
		inference_ready = bool(data.get("inference_ready", false))

	server_ready = state_text.begins_with("ready")
	if server_ready:
		var mode_text := ""
		if typeof(data) == TYPE_DICTIONARY:
			mode_text = str(data.get("mode", "")).strip_edges()
		if mode_text == "":
			mode_text = "local_ai"
		update_status_label("READY")
		debug_print("server ready | mode=" + mode_text + " inference_ready=" + str(inference_ready))
		if random_news_enabled and not has_started and not pending:
			schedule_next_cycle(1.5, "server_ready")
		return

	if state_text in ["starting", "checking"]:
		update_status_label("LINKING")
		return

	if state_text in ["failed", "disabled", "autostart_off"]:
		update_news_widget("OFFLINE", message if message != "" else "Local AI news link is offline.")


func schedule_next_cycle(delay_seconds: float, reason: String = "cycle") -> void:
	if not random_news_enabled:
		return
	ensure_timer()
	if cycle_timer == null:
		return

	var delay = max(delay_seconds, 0.1)
	cycle_timer.stop()
	cycle_timer.wait_time = delay
	cycle_timer.start()
	debug_print("next cycle scheduled | seconds=" + str(delay) + " reason=" + reason)


func schedule_random_cycle(reason: String = "reply") -> void:
	var low = min(min_delay_seconds, max_delay_seconds)
	var high = max(min_delay_seconds, max_delay_seconds)
	schedule_next_cycle(rng.randf_range(low, high), reason)


func _on_cycle_timer_timeout() -> void:
	if not random_news_enabled:
		return
	request_news_broadcast()


func request_news_broadcast() -> void:
	if not random_news_enabled:
		return
	if not enabled:
		return
	if pending:
		return
	if local_ai_talker == null:
		ensure_talker()
	if local_ai_talker == null:
		update_news_widget("OFFLINE", "DRIFTWIRE talker node is missing.")
		schedule_next_cycle(10.0, "missing_talker")
		return

	if not server_ready and not has_started:
		update_status_label("PROBING")

	var context := build_news_context_packet()
	var prompt := build_news_prompt(context)
	cycle_index += 1
	pending = true
	has_started = true
	update_status_label("COMPOSING")

	local_ai_talker.history.clear()
	local_ai_talker.conversation_id = "main_ai_news_" + str(Time.get_unix_time_from_system()) + "_" + str(cycle_index)
	var accepted := local_ai_talker.send_message(prompt, {
		"scene": "main_mode",
		"handler": "main_ai",
		"cycle_index": cycle_index,
		"snapshot_summary": context
	})

	if not accepted:
		pending = false
		update_status_label("SEND FAILED")
		schedule_next_cycle(8.0, "send_rejected")
		return

	debug_print("request sent | cycle=" + str(cycle_index) + " prompt_chars=" + str(prompt.length()))


func request_commentary(commentary_kind: String, context: Dictionary, reason: String = "") -> bool:
	var clean_kind := commentary_kind.strip_edges().to_lower()
	if clean_kind == "":
		debug_print("commentary skipped | reason=" + reason + " cause=empty_kind")
		return false
	if not enabled:
		debug_print("commentary skipped | kind=" + clean_kind + " reason=" + reason + " cause=disabled")
		return false
	if pending:
		debug_print("commentary skipped | kind=" + clean_kind + " reason=" + reason + " cause=pending_request pending_kind=" + pending_request_kind)
		return false
	if local_ai_talker == null:
		ensure_talker()
	if local_ai_talker == null:
		update_news_widget("OFFLINE", "DRIFTWIRE commentator link is missing.")
		schedule_next_cycle(10.0, "commentary_missing_talker")
		debug_print("commentary skipped | kind=" + clean_kind + " reason=" + reason + " cause=missing_talker")
		return false

	var now_msec := Time.get_ticks_msec()
	var elapsed_msec := now_msec - last_commentary_request_msec
	if elapsed_msec < int(COMMENTARY_MIN_DELAY_SECONDS * 1000.0):
		debug_print("commentary skipped | kind=" + clean_kind + " reason=" + reason + " cause=cooldown elapsed_msec=" + str(elapsed_msec))
		return false

	var clean_context := context.duplicate(true)
	var prompt := build_commentary_prompt(clean_kind, clean_context)
	commentary_index += 1
	pending = true
	has_started = true
	pending_request_kind = clean_kind
	pending_commentary_context = clean_context
	last_commentary_request_msec = now_msec
	if cycle_timer != null and is_instance_valid(cycle_timer):
		cycle_timer.stop()
	update_status_label(get_commentary_status_text(clean_kind))

	local_ai_talker.history.clear()
	local_ai_talker.conversation_id = "main_ai_commentary_" + clean_kind + "_" + str(Time.get_unix_time_from_system()) + "_" + str(commentary_index)
	var accepted := local_ai_talker.send_message(prompt, {
		"scene": str(clean_context.get("scene", "main_mode")),
		"handler": "main_ai",
		"request_kind": clean_kind,
		"reason": reason,
		"commentary_index": commentary_index,
		"snapshot_summary": clean_context,
		"local_ai_role": "shipboard tactical commentator"
	})

	if not accepted:
		pending = false
		pending_request_kind = ""
		pending_commentary_context.clear()
		update_status_label("SEND FAILED")
		schedule_next_cycle(8.0, "commentary_send_rejected")
		debug_print("commentary send rejected | kind=" + clean_kind + " reason=" + reason)
		return false

	debug_print("commentary request sent | kind=" + clean_kind + " reason=" + reason + " index=" + str(commentary_index) + " prompt_chars=" + str(prompt.length()))
	return true


func build_news_context_packet() -> Dictionary:
	var packet := {
		"sector": str(Globals.sector_pos),
		"local": str(Globals.local_pos),
		"universe": str(Globals.active_universe_display_name),
		"ship": build_ship_context(),
		"counts": {
			"stars": get_object_collection_count(get_main_ref("star_field"), "stars"),
			"space_objects": get_object_collection_count(get_main_ref("space_objects"), "objects"),
			"beacons": get_object_collection_count(get_main_ref("beacons"), "beacons"),
			"planets": get_object_collection_count(get_main_ref("planets"), "planets"),
			"enemies": get_object_collection_count(get_main_ref("enemy_handler"), "enemies"),
			"npcs": get_object_collection_count(get_main_ref("npc_handler"), "npcs"),
			"active_events": get_game_event_count("active_events"),
			"available_events": get_game_event_count("available_events")
		},
		"nearest_stars": build_nearest_star_context(3),
		"event_ids": build_event_id_context(3),
		"topic": choose_news_topic()
	}
	return packet


func build_ship_context() -> Dictionary:
	var engine = get_main_ref("eng")
	var auto_pilot = get_main_ref("auto_pilot")
	return {
		"engine_mode": str(get_value(engine, "mode", "unknown")),
		"speed": float(get_value(engine, "speed", 0.0)),
		"thrust": bool(get_value(engine, "thrust_on", false)),
		"autopilot_mode": str(get_value(auto_pilot, "mode", "manual"))
	}


func build_nearest_star_context(limit: int) -> Array:
	var result: Array = []
	var star_ui = get_main_ref("star_ui")
	var nearest = get_value(star_ui, "current_nearest_stars", [])
	if typeof(nearest) != TYPE_ARRAY:
		return result

	var count = min(limit, nearest.size())
	for i in range(count):
		var star = nearest[i]
		result.append({
			"name": str(get_value(star, "star_name", "unknown")),
			"type": str(get_value(star, "star_type", "unknown")),
			"sector": str(get_value(star, "sector_pos", "")),
			"local": str(get_value(star, "local_pos", ""))
		})
	return result


func build_event_id_context(limit: int) -> Array:
	var result: Array = []
	var game_events = get_main_ref("game_event_handler")
	var active_events = get_value(game_events, "active_events", {})
	if typeof(active_events) != TYPE_DICTIONARY:
		return result

	var keys = active_events.keys()
	var count = min(limit, keys.size())
	for i in range(count):
		result.append(str(keys[i]))
	return result


func choose_news_topic() -> String:
	var topics := [
		"navigation advisory",
		"station rumor",
		"deep-space traffic",
		"sensor weather",
		"merchant bulletin",
		"frontier safety notice",
		"cosmic oddity"
	]
	return str(topics[rng.randi_range(0, topics.size() - 1)])


func build_news_prompt(context: Dictionary) -> String:
	return (
		"You are The Driftwire, an in-universe shortwave news broadcaster inside Forever Space.\n"
		+ "Write a tiny news broadcast for the ship's main screen.\n"
		+ "Rules: 1 or 2 sentences only, maximum 45 words, no bullets, no labels, no direct orders to the player, no mention of prompts or AI.\n"
		+ "Use the factual data as inspiration. You may add small fake lore if it matches the data.\n"
		+ "Current game data: " + JSON.stringify(context)
	)


func build_commentary_prompt(commentary_kind: String, context: Dictionary) -> String:
	var mode_line := "Comment on the current tactical packet."
	if commentary_kind == "scan_enemy_awareness":
		mode_line = "Comment on the main-mode enemy scan packet."
	elif commentary_kind == "battle_snapshot":
		mode_line = "Comment on the current Battle V2 combat snapshot."
	elif commentary_kind == "enemy_intent":
		mode_line = "Comment on the enemy intent that was just queued."
	elif commentary_kind == "battle_resolution":
		mode_line = "Comment on the Battle V2 action that just resolved."

	return (
		"You are AMI, a shipboard tactical commentator inside Forever Space.\n"
		+ mode_line + "\n"
		+ "Rules: 1 or 2 sentences only, maximum 45 words, no bullets, no labels, no game-state changes, no invented rewards, no direct player orders, no mention of JSON or prompts.\n"
		+ "Use only the factual packet. If the packet is incomplete, sound uncertain instead of inventing details.\n"
		+ "Tactical packet: " + JSON.stringify(context)
	)


func _on_ai_reply_received(packet: Dictionary) -> void:
	var request_kind := pending_request_kind
	var commentary_context := pending_commentary_context.duplicate(true)
	pending = false
	pending_request_kind = ""
	pending_commentary_context.clear()
	server_ready = true
	var backend := str(packet.get("backend", "")).strip_edges()
	var raw_reply := str(packet.get("reply", "")).strip_edges()
	var clean_reply := ""
	if request_kind != "":
		clean_reply = clean_commentary_text(raw_reply)
		if backend == "echo":
			clean_reply = build_commentary_fallback_text(request_kind, commentary_context)
		if clean_reply == "":
			clean_reply = build_commentary_fallback_text(request_kind, commentary_context)

		update_news_widget(get_commentary_status_text(request_kind), clean_reply)
		news_updated.emit({
			"ok": true,
			"text": clean_reply,
			"backend": backend,
			"cycle_index": cycle_index,
			"commentary_index": commentary_index,
			"request_kind": request_kind
		})
		debug_print("commentary reply accepted | kind=" + request_kind + " index=" + str(commentary_index) + " chars=" + str(clean_reply.length()))
		schedule_random_cycle("commentary_received")
		return

	clean_reply = clean_broadcast_text(raw_reply)
	if backend == "echo":
		clean_reply = "DRIFTWIRE echo test is active; local model inference is not producing broadcasts yet."
	if clean_reply == "":
		clean_reply = "DRIFTWIRE carrier is open, but the bulletin arrived blank."

	update_news_widget("LIVE", clean_reply)
	news_updated.emit({
		"ok": true,
		"text": clean_reply,
		"backend": backend,
		"cycle_index": cycle_index
	})
	debug_print("reply accepted | cycle=" + str(cycle_index) + " chars=" + str(clean_reply.length()))
	schedule_random_cycle("reply_received")


func _on_ai_request_failed(packet: Dictionary) -> void:
	var request_kind := pending_request_kind
	var commentary_context := pending_commentary_context.duplicate(true)
	pending = false
	pending_request_kind = ""
	pending_commentary_context.clear()
	var reason := str(packet.get("reason", packet.get("error", "unknown"))).strip_edges()
	if request_kind != "":
		update_news_widget("COMMENTARY LOST", build_commentary_fallback_text(request_kind, commentary_context))
		debug_print("commentary request failed | kind=" + request_kind + " packet=" + str(packet))
		schedule_next_cycle(10.0, "commentary_request_failed")
		return
	update_news_widget("SIGNAL LOST", "DRIFTWIRE lost the local carrier. " + reason)
	debug_print("request failed | " + str(packet))
	schedule_next_cycle(10.0, "request_failed")


func _on_ai_status_changed(status_text: String) -> void:
	if pending:
		update_status_label("COMPOSING")
	debug_print("talker status | " + status_text)


func clean_broadcast_text(raw_text: String) -> String:
	var text := raw_text.strip_edges()
	text = text.replace("\r", " ")
	text = text.replace("\n", " ")
	while text.find("  ") >= 0:
		text = text.replace("  ", " ")

	var prefixes := ["Broadcast:", "News:", "DRIFTWIRE:", "The Driftwire:", "AI:"]
	for prefix in prefixes:
		if text.to_lower().begins_with(str(prefix).to_lower()):
			text = text.substr(str(prefix).length()).strip_edges()

	if text.length() > 260:
		text = text.substr(0, 257).strip_edges() + "..."
	return text


func clean_commentary_text(raw_text: String) -> String:
	var text := raw_text.strip_edges()
	text = text.replace("\r", " ")
	text = text.replace("\n", " ")
	while text.find("  ") >= 0:
		text = text.replace("  ", " ")

	var prefixes := ["AMI:", "Commentary:", "Tactical:", "Battle:", "Scan:", "AI:"]
	for prefix in prefixes:
		if text.to_lower().begins_with(str(prefix).to_lower()):
			text = text.substr(str(prefix).length()).strip_edges()

	if text.length() > 260:
		text = text.substr(0, 257).strip_edges() + "..."
	return text


func build_commentary_fallback_text(commentary_kind: String, context: Dictionary) -> String:
	if commentary_kind == "scan_enemy_awareness":
		var awareness = context.get("enemy_awareness", context)
		if typeof(awareness) != TYPE_DICTIONARY:
			return "AMI scan commentary is quiet; enemy awareness packet was unreadable."
		var found_count := int(awareness.get("found_enemy_count", awareness.get("enemy_count", 0)))
		var enemies: Array = []
		if typeof(awareness.get("enemies", [])) == TYPE_ARRAY:
			enemies = awareness.get("enemies", [])
		if found_count <= 0 or enemies.is_empty():
			return "AMI scan sweep reads no enemy signatures in local range."
		var lead_enemy := {}
		if typeof(enemies[0]) == TYPE_DICTIONARY:
			lead_enemy = enemies[0]
		var name := str(lead_enemy.get("name", lead_enemy.get("enemy_name", "enemy contact")))
		var distance := float(lead_enemy.get("distance", 0.0))
		return "AMI marks " + name + " as the nearest hostile return at " + str(round(distance)) + " units."

	if commentary_kind == "enemy_intent":
		var intent = context.get("enemy_intent", context)
		if typeof(intent) == TYPE_DICTIONARY:
			return "AMI reads enemy intent: " + str(intent.get("event_type", intent.get("status", "movement"))) + " is entering the combat lane."
		return "AMI reads a hostile action entering the combat lane."

	if commentary_kind == "battle_resolution":
		var resolution = context.get("resolution", context)
		if typeof(resolution) == TYPE_DICTIONARY:
			var outcome := str(resolution.get("battle_outcome", "battle_continues"))
			if outcome == "player_victory":
				return "AMI confirms the hostile contact is breaking apart. Combat resolution favors the player ship."
			if outcome == "player_defeat":
				return "AMI confirms player hull collapse. Combat resolution is terminal."
		return "AMI registers the combat exchange resolving through Battle V2 telemetry."

	if commentary_kind == "battle_snapshot":
		return "AMI has a live combat snapshot, but the model channel is unavailable."

	return "AMI commentary channel is quiet; tactical packet was received."


func get_commentary_status_text(commentary_kind: String) -> String:
	if commentary_kind == "scan_enemy_awareness":
		return "SCAN"
	if commentary_kind == "battle_snapshot":
		return "BATTLE"
	if commentary_kind == "enemy_intent":
		return "ENEMY"
	if commentary_kind == "battle_resolution":
		return "RESOLVE"
	return "COMMENTARY"


func update_news_widget(status_text: String, body_text: String) -> void:
	update_status_label(status_text)
	if gui_state == null:
		return
	set_ticker_text(body_text)


func set_ticker_text(body_text: String) -> void:
	if gui_state == null:
		return
	var body = gui_state.labels.get("main_ai_news_text", null)
	var clip = gui_state.controls.get("main_ai_news_ticker_clip", null)
	if not (body is Label) or not (clip is Control):
		return

	var clean_text := body_text.strip_edges()
	if clean_text == "":
		clean_text = "DRIFTWIRE carrier is quiet."

	ticker_text = TICKER_START_SYMBOL + " " + clean_text + " " + TICKER_END_SYMBOL
	var label := body as Label
	var ticker_clip := clip as Control
	label.text = ticker_text
	recalculate_ticker_width()
	ticker_offset_x = ticker_clip.size.x
	label.position = Vector2(ticker_offset_x, 0)


func process_news_ticker(delta: float) -> void:
	if gui_state == null:
		return
	var body = gui_state.labels.get("main_ai_news_text", null)
	var clip = gui_state.controls.get("main_ai_news_ticker_clip", null)
	if not (body is Label) or not (clip is Control):
		return

	var label := body as Label
	var ticker_clip := clip as Control
	if label.text == "":
		return
	if ticker_text == "":
		ticker_text = label.text
	if ticker_label_width <= 0.0:
		recalculate_ticker_width()

	ticker_offset_x -= ticker_speed_pixels_per_second * delta
	if ticker_offset_x < -ticker_label_width - ticker_gap_pixels:
		ticker_offset_x = ticker_clip.size.x + ticker_gap_pixels

	label.position = Vector2(ticker_offset_x, 0)


func recalculate_ticker_width() -> void:
	if gui_state == null:
		return
	var body = gui_state.labels.get("main_ai_news_text", null)
	var clip = gui_state.controls.get("main_ai_news_ticker_clip", null)
	if not (body is Label) or not (clip is Control):
		return

	var label := body as Label
	var ticker_clip := clip as Control
	var width := float(label.text.length()) * 7.5
	if width <= 4.0:
		width = ticker_clip.size.x
	ticker_label_width = max(width + 24.0, ticker_clip.size.x + 1.0)
	label.size = Vector2(ticker_label_width, ticker_clip.size.y)


func update_status_label(status_text: String) -> void:
	if gui_state == null:
		return
	var status = gui_state.labels.get("main_ai_news_status", null)
	if status is Label:
		(status as Label).text = status_text


func get_main_ref(property_name: String):
	if main_mode_ref == null:
		return null
	return main_mode_ref.get(property_name)


func get_value(source, key: String, fallback = null):
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


func get_object_collection_count(source, property_name: String) -> int:
	var value = get_value(source, property_name, [])
	if typeof(value) == TYPE_ARRAY:
		return value.size()
	if typeof(value) == TYPE_DICTIONARY:
		return value.size()
	return 0


func get_game_event_count(property_name: String) -> int:
	var game_events = get_main_ref("game_event_handler")
	var value = get_value(game_events, property_name, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value.size()
	if typeof(value) == TYPE_ARRAY:
		return value.size()
	return 0


func debug_print(message: String) -> void:
	if debug_prints:
		print(DEBUG_PREFIX + " " + message)
