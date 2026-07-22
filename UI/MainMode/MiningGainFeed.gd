extends Control
class_name MiningGainFeed

const DEBUG_PREFIX := "[MINING_GAIN_FEED]"

var gui_state: WidgetsState5 = null
var rng := RandomNumberGenerator.new()
var active_entries: Array = []

var entry_lifetime_seconds := 3.2
var rise_distance := 138.0
var spawn_stagger_seconds := 0.12
var spread_x := 54.0
var row_gap := 20.0
var font_size := 14
var debug_prints := true


func setup(new_gui_state: WidgetsState5 = null) -> void:
	gui_state = new_gui_state
	name = "MiningGainFeed"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 245
	clip_contents = false
	refresh_screen_rect()
	rng.randomize()
	set_process(true)
	debug_print("setup complete")


func refresh_screen_rect() -> void:
	position = Vector2.ZERO
	var viewport_size := Vector2(float(Globals.screen_w), float(Globals.screen_h))
	if get_viewport() != null:
		viewport_size = get_viewport().get_visible_rect().size
	size = viewport_size
	custom_minimum_size = viewport_size


func queue_mining_rewards(packet: Dictionary) -> void:
	queue_reward_feed(packet, ["resource_rewards"], "resource_amounts", "mining")


func queue_craft_rewards(packet: Dictionary) -> void:
	queue_reward_feed(packet, ["craft_rewards", "item_rewards", "resource_rewards"], "craft_amounts", "craft")


func queue_reward_feed(packet: Dictionary, reward_keys: Array, amount_key: String, reason: String) -> void:
	refresh_screen_rect()
	var rewards := resolve_reward_packets(packet, reward_keys, amount_key)
	if rewards.is_empty():
		debug_print("queue skipped | no rewards in packet | reason=" + reason)
		return

	var anchor := resolve_spawn_anchor()
	for i in range(rewards.size()):
		var reward: Dictionary = rewards[i]
		spawn_reward_label(reward, anchor, i)

	debug_print("queued rewards | count=" + str(rewards.size()) + " reason=" + reason)


func resolve_reward_packets(packet: Dictionary, reward_keys: Array, amount_key: String) -> Array:
	for reward_key in reward_keys:
		var rewards = packet.get(str(reward_key), [])
		if typeof(rewards) == TYPE_ARRAY and not rewards.is_empty():
			return rewards.duplicate(true)

	var fallback := []
	var resource_amounts = packet.get(amount_key, {})
	if typeof(resource_amounts) != TYPE_DICTIONARY:
		resource_amounts = packet.get("resource_amounts", {})
	if typeof(resource_amounts) != TYPE_DICTIONARY:
		return fallback

	var item_ids := []
	for raw_item_id in resource_amounts.keys():
		item_ids.append(str(raw_item_id))
	item_ids.sort()

	for item_id in item_ids:
		var amount := int(resource_amounts.get(item_id, 0))
		if amount <= 0:
			continue
		fallback.append({
			"item_id": item_id,
			"display_name": item_id.replace("_", " ").capitalize(),
			"amount": amount
		})
	return fallback


func resolve_spawn_anchor() -> Vector2:
	var top_bottom := Globals.main_top_strip_pos.y + Globals.main_top_strip_size.y
	var news_top := Globals.main_ai_news_widget_pos.y
	var spawn_y = lerp(top_bottom, news_top, 0.5)
	var spawn_x = Globals.main_ai_news_widget_pos.x + (Globals.main_ai_news_widget_size.x * 0.5)
	return Vector2(spawn_x, spawn_y)


func spawn_reward_label(reward: Dictionary, anchor: Vector2, index: int) -> void:
	var display_name := str(reward.get("display_name", reward.get("item_id", "Resource"))).strip_edges()
	var amount := int(reward.get("amount", 0))
	if amount <= 0:
		return
	if display_name == "":
		display_name = "Resource"

	var label := Label.new()
	label.name = "mining_gain_" + str(Time.get_ticks_msec()) + "_" + str(index)
	label.text = "+" + str(amount) + " " + display_name
	label.size = Vector2(360, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.05, 0.08, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	if gui_state != null and gui_state.font != null:
		label.add_theme_font_override("font", gui_state.font)

	var x_jitter := rng.randf_range(-spread_x, spread_x)
	var start_pos := anchor + Vector2(x_jitter - (label.size.x * 0.5), float(index) * row_gap)
	var end_pos := start_pos + Vector2(rng.randf_range(-18.0, 18.0), -rise_distance - float(index) * 5.0)
	label.position = start_pos
	label.modulate = Color(1.0, 0.25, 0.18, 0.0)
	add_child(label)

	active_entries.append({
		"node": label,
		"elapsed": -float(index) * spawn_stagger_seconds,
		"duration": entry_lifetime_seconds,
		"start_pos": start_pos,
		"end_pos": end_pos,
		"color_offset": rng.randf_range(0.0, TAU)
	})


func _process(delta: float) -> void:
	if active_entries.is_empty():
		return

	for i in range(active_entries.size() - 1, -1, -1):
		var entry: Dictionary = active_entries[i]
		var node = entry.get("node", null)
		if not (node is Label) or not is_instance_valid(node):
			active_entries.remove_at(i)
			continue

		var label := node as Label
		var elapsed := float(entry.get("elapsed", 0.0)) + delta
		entry["elapsed"] = elapsed
		active_entries[i] = entry

		if elapsed < 0.0:
			label.visible = false
			continue

		label.visible = true
		var duration = max(float(entry.get("duration", entry_lifetime_seconds)), 0.1)
		var t = clamp(elapsed / duration, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 2.0)
		var start_pos: Vector2 = entry.get("start_pos", label.position)
		var end_pos: Vector2 = entry.get("end_pos", label.position)
		label.position = start_pos.lerp(end_pos, eased)
		label.scale = Vector2.ONE * lerp(1.04, 0.94, t)
		label.modulate = get_reward_color(t, float(entry.get("color_offset", 0.0)))

		if t >= 1.0:
			label.queue_free()
			active_entries.remove_at(i)


func get_reward_color(progress: float, offset: float) -> Color:
	var hot_red := Color(1.0, 0.22, 0.18, 1.0)
	var warm_gold := Color(1.0, 0.64, 0.24, 1.0)
	var theme_blue := Color(0.48, 0.86, 1.0, 1.0)
	var color := hot_red
	if progress < 0.28:
		color = hot_red.lerp(warm_gold, progress / 0.28)
	else:
		color = warm_gold.lerp(theme_blue, (progress - 0.28) / 0.72)

	var fade := 1.0
	if progress > 0.62:
		fade = 1.0 - ((progress - 0.62) / 0.38)
	var pulse := Fooliery_Color.pulse_alpha((Time.get_ticks_msec() / 1000.0) + offset, 4.0, 0.88, 1.0)
	color.a = clamp(fade * pulse, 0.0, 1.0)
	return color


func debug_print(message: String) -> void:
	if debug_prints:
		print(DEBUG_PREFIX + " " + message)
