extends RefCounted

class_name DroneOrbitUI

const PLAYER_DRONE_COLOR := Color(0.16, 0.82, 1.0, 0.92)
const PLAYER_DRONE_CORE := Color(0.78, 0.98, 1.0, 1.0)
const PLAYER_DRONE_HOT := Color(0.40, 0.92, 1.0, 0.90)

const ENEMY_DRONE_COLOR := Color(1.0, 0.18, 0.10, 0.92)
const ENEMY_DRONE_CORE := Color(1.0, 0.72, 0.36, 1.0)
const ENEMY_DRONE_HOT := Color(1.0, 0.08, 0.26, 0.90)

const ORBIT_SPEED_PLAYER := 1.35
const ORBIT_SPEED_ENEMY := -1.48
const ATTACK_VISUAL_DURATION := 0.46
const END_VISUAL_DURATION := 0.82

var active_drones: Array = []
var attack_pulses: Array = []
var ending_pulses: Array = []
var seen_attack_keys: Dictionary = {}
var seen_ending_keys: Dictionary = {}
var first_seen_anim_time: Dictionary = {}
var current_drone_centers: Dictionary = {}
var last_runtime_packet: Dictionary = {}


func set_runtime_packet(packet: Dictionary, anim_time: float = 0.0) -> void:
	last_runtime_packet = packet.duplicate(true)
	active_drones.clear()

	if typeof(packet.get("drones", [])) == TYPE_ARRAY:
		for drone in packet.get("drones", []):
			if typeof(drone) != TYPE_DICTIONARY:
				continue
			var clean_drone = drone.duplicate(true)
			var runtime_id := get_drone_runtime_id(clean_drone)
			if runtime_id == "":
				continue
			if not first_seen_anim_time.has(runtime_id):
				first_seen_anim_time[runtime_id] = anim_time
			clean_drone["runtime_id"] = runtime_id
			clean_drone["last_packet_anim_time"] = anim_time
			active_drones.append(clean_drone)

	if typeof(packet.get("attacks", [])) == TYPE_ARRAY:
		for attack in packet.get("attacks", []):
			if typeof(attack) != TYPE_DICTIONARY:
				continue
			var attack_key := get_attack_key(attack)
			if attack_key == "" or seen_attack_keys.has(attack_key):
				continue
			seen_attack_keys[attack_key] = true
			var attack_pulse = attack.duplicate(true)
			attack_pulse["ui_attack_key"] = attack_key
			attack_pulse["age"] = 0.0
			attack_pulse["duration"] = ATTACK_VISUAL_DURATION
			attack_pulses.append(attack_pulse)

	add_ending_pulses(packet, "expired", "expired", anim_time)
	add_ending_pulses(packet, "destroyed", "destroyed", anim_time)
	prune_seen_keys()


func process(delta: float) -> void:
	for i in range(attack_pulses.size() - 1, -1, -1):
		var pulse: Dictionary = attack_pulses[i]
		pulse["age"] = float(pulse.get("age", 0.0)) + delta
		if float(pulse.get("age", 0.0)) >= float(pulse.get("duration", ATTACK_VISUAL_DURATION)):
			attack_pulses.remove_at(i)
		else:
			attack_pulses[i] = pulse

	for i in range(ending_pulses.size() - 1, -1, -1):
		var ending: Dictionary = ending_pulses[i]
		ending["age"] = float(ending.get("age", 0.0)) + delta
		if float(ending.get("age", 0.0)) >= float(ending.get("duration", END_VISUAL_DURATION)):
			ending_pulses.remove_at(i)
		else:
			ending_pulses[i] = ending


func draw_runtime(canvas: Control, anchors: Dictionary, unit_state: Dictionary, anim_time: float) -> bool:
	current_drone_centers.clear()
	var did_draw := false

	var player_drones := get_drones_for_side("player")
	var enemy_drones := get_drones_for_side("enemy")

	for i in range(player_drones.size()):
		draw_drone(canvas, anchors, unit_state, player_drones[i], "player", i, player_drones.size(), anim_time)
		did_draw = true

	for i in range(enemy_drones.size()):
		draw_drone(canvas, anchors, unit_state, enemy_drones[i], "enemy", i, enemy_drones.size(), anim_time)
		did_draw = true

	for ending in ending_pulses:
		if typeof(ending) != TYPE_DICTIONARY:
			continue
		draw_ending_pulse(canvas, anchors, ending, anim_time)
		did_draw = true

	for attack in attack_pulses:
		if typeof(attack) != TYPE_DICTIONARY:
			continue
		draw_attack_pulse(canvas, anchors, attack, anim_time)
		did_draw = true

	return did_draw


func draw_drone(canvas: Control, anchors: Dictionary, _unit_state: Dictionary, drone: Dictionary, side: String, side_index: int, side_count: int, anim_time: float) -> void:
	var runtime_id := get_drone_runtime_id(drone)
	var actor_center := get_actor_center(canvas, anchors, side)
	if actor_center == Vector2.ZERO:
		return

	var colors := get_colors_for_side(side)
	var main_color: Color = colors.get("main", PLAYER_DRONE_COLOR)
	var core_color: Color = colors.get("core", PLAYER_DRONE_CORE)
	var hot_color: Color = colors.get("hot", PLAYER_DRONE_HOT)
	var first_seen := float(first_seen_anim_time.get(runtime_id, anim_time))
	var born_age = max(anim_time - first_seen, 0.0)
	var enter_t = clamp(born_age / 0.44, 0.0, 1.0)
	var side_phase := build_runtime_phase(runtime_id, side_index, side_count)
	var radius := build_orbit_radius(side_index, side_count)
	var speed := ORBIT_SPEED_ENEMY if side == "enemy" else ORBIT_SPEED_PLAYER
	var angle := anim_time * speed + side_phase
	var ellipse := Vector2(cos(angle) * radius, sin(angle) * (radius * 0.54))
	var sweep_center := actor_center + ellipse

	# Short spawn-in sweep from the owning actor into orbit. After that, never park; it keeps orbiting.
	var spawn_offset := Vector2(-70.0 if side == "player" else 70.0, 24.0 + float(side_index % 3) * 9.0)
	var spawn_point := actor_center + spawn_offset
	var center := spawn_point.lerp(sweep_center, 1.0 - pow(1.0 - enter_t, 3.0))
	current_drone_centers[runtime_id] = center

	var time_remaining := get_display_time_remaining(drone, anim_time)
	var duration = max(float(drone.get("duration", time_remaining)), 0.01)
	var life_ratio = clamp(time_remaining / duration, 0.0, 1.0)
	var fire_interval = max(float(drone.get("fire_interval", 1.0)), 0.01)
	var fire_timer := get_display_fire_timer(drone, anim_time, fire_interval)
	var charge_ratio = clamp(1.0 - fire_timer / fire_interval, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(anim_time * 5.4 + side_phase + charge_ratio * TAU)
	var end_fade = clamp(life_ratio * 4.0, 0.24, 1.0)
	var glow = 1.0 + charge_ratio * 0.32 + pulse * 0.08

	canvas.draw_circle(center, 31.0 + pulse * 5.0, Color(main_color.r, main_color.g, main_color.b, 0.070 * end_fade))
	canvas.draw_arc(center, 26.0 + pulse * 3.0, angle * 0.55, angle * 0.55 + PI * 1.35, 36, Color(main_color.r, main_color.g, main_color.b, 0.18 * end_fade), 1.4, true)
	canvas.draw_arc(center, 17.0 + charge_ratio * 4.0, -angle * 0.85, -angle * 0.85 + PI * 0.85, 24, Color(hot_color.r, hot_color.g, hot_color.b, 0.26 * end_fade), 1.2, true)

	var forward_sign := 1.0 if side == "player" else -1.0
	var wing_y := sin(anim_time * 7.0 + side_phase) * 2.5
	canvas.draw_circle(center, 11.5 * glow, Color(main_color.r, main_color.g, main_color.b, 0.70 * end_fade))
	canvas.draw_circle(center, 4.4 + charge_ratio * 1.8, Color(core_color.r, core_color.g, core_color.b, 0.94 * end_fade))
	canvas.draw_circle(center + Vector2(-9.0 * forward_sign, wing_y), 3.8, Color(main_color.r, main_color.g, main_color.b, 0.74 * end_fade))
	canvas.draw_circle(center + Vector2(9.0 * forward_sign, -wing_y), 3.8, Color(main_color.r, main_color.g, main_color.b, 0.74 * end_fade))
	canvas.draw_circle(center + Vector2(0.0, -8.5), 3.4 + charge_ratio * 1.4, Color(core_color.r, core_color.g, core_color.b, 0.88 * end_fade))

	# Charge bar under the drone. Multiple drones can overlap the actor, but these offsets/radii keep the bodies moving apart.
	var bar_width := 28.0
	var bar_pos := center + Vector2(-bar_width * 0.5, 16.0)
	canvas.draw_rect(Rect2(bar_pos, Vector2(bar_width, 2.4)), Color(0.02, 0.04, 0.07, 0.58 * end_fade), true)
	canvas.draw_rect(Rect2(bar_pos, Vector2(bar_width * charge_ratio, 2.4)), Color(core_color.r, core_color.g, core_color.b, 0.72 * end_fade), true)

	# Life ticks. This replaces the old timer label so the draw-only handler stays simple.
	var tick_count := 4
	for tick in range(tick_count):
		var tick_t := float(tick + 1) / float(tick_count)
		var tick_on = life_ratio >= tick_t - 0.02
		var tick_alpha := 0.34 if tick_on else 0.09
		var tick_x := -12.0 + float(tick) * 8.0
		canvas.draw_rect(Rect2(center + Vector2(tick_x, 21.0), Vector2(4.0, 2.0)), Color(main_color.r, main_color.g, main_color.b, tick_alpha * end_fade), true)


func draw_attack_pulse(canvas: Control, anchors: Dictionary, attack: Dictionary, anim_time: float) -> void:
	var side := clean_side(str(attack.get("owner_side", "player")))
	var target_side := clean_side(str(attack.get("target_side", get_opposite_side(side))))
	var runtime_id := str(attack.get("runtime_id", "")).strip_edges()
	var start: Vector2 = current_drone_centers.get(runtime_id, get_actor_center(canvas, anchors, side))
	var finish := get_actor_center(canvas, anchors, target_side)
	if start == Vector2.ZERO or finish == Vector2.ZERO:
		return

	var age := float(attack.get("age", 0.0))
	var duration = max(float(attack.get("duration", ATTACK_VISUAL_DURATION)), 0.01)
	var t = clamp(age / duration, 0.0, 1.0)
	var eased = t * t * (3.0 - 2.0 * t)
	var color := PLAYER_DRONE_HOT if side == "player" else ENEMY_DRONE_HOT
	var core := PLAYER_DRONE_CORE if side == "player" else ENEMY_DRONE_CORE
	var dir := (finish - start).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT if side == "player" else Vector2.LEFT
	var side_sweep := Vector2(-dir.y, dir.x) * (9.0 * sin(anim_time * 8.0 + t * PI))
	var pos := start.lerp(finish, eased) + side_sweep
	var alpha = 1.0 - t

	canvas.draw_line(start, pos, Color(color.r, color.g, color.b, 0.42 * alpha), 2.2, true)
	canvas.draw_line(start, finish, Color(color.r, color.g, color.b, 0.055 * alpha), 1.0, true)
	canvas.draw_circle(start, 7.0 + (1.0 - alpha) * 5.0, Color(core.r, core.g, core.b, 0.20 * alpha))
	canvas.draw_circle(pos, 4.5 + alpha * 2.5, Color(core.r, core.g, core.b, 0.88 * alpha))
	if t > 0.62:
		var impact_alpha = clamp((t - 0.62) / 0.38, 0.0, 1.0)
		canvas.draw_circle(finish, 12.0 + impact_alpha * 16.0, Color(color.r, color.g, color.b, 0.18 * (1.0 - impact_alpha)))


func draw_ending_pulse(canvas: Control, anchors: Dictionary, ending: Dictionary, _anim_time: float) -> void:
	var side := clean_side(str(ending.get("owner_side", "player")))
	var actor_center := get_actor_center(canvas, anchors, side)
	if actor_center == Vector2.ZERO:
		return
	var age := float(ending.get("age", 0.0))
	var duration = max(float(ending.get("duration", END_VISUAL_DURATION)), 0.01)
	var t = clamp(age / duration, 0.0, 1.0)
	var color := PLAYER_DRONE_COLOR if side == "player" else ENEMY_DRONE_COLOR
	var core := PLAYER_DRONE_CORE if side == "player" else ENEMY_DRONE_CORE
	var radius = 38.0 + t * 58.0
	var alpha = 1.0 - t
	var status := str(ending.get("status", "expired")).strip_edges().to_lower()
	var shard_count := 7 if status == "destroyed" else 4
	canvas.draw_circle(actor_center, radius, Color(color.r, color.g, color.b, 0.055 * alpha))
	for shard in range(shard_count):
		var a = float(shard) * TAU / float(shard_count) + t * TAU * 0.35
		var start = actor_center + Vector2(cos(a), sin(a)) * (radius * 0.55)
		var finish = actor_center + Vector2(cos(a), sin(a)) * radius
		canvas.draw_line(start, finish, Color(core.r, core.g, core.b, 0.28 * alpha), 1.4, true)


func add_ending_pulses(packet: Dictionary, key: String, status: String, anim_time: float) -> void:
	if typeof(packet.get(key, [])) != TYPE_ARRAY:
		return
	for entry in packet.get(key, []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var runtime_id := get_drone_runtime_id(entry)
		if runtime_id == "":
			continue
		var ending_key := status + ":" + runtime_id + ":" + str(int(anim_time * 10.0))
		if seen_ending_keys.has(ending_key):
			continue
		seen_ending_keys[ending_key] = true
		var ending = entry.duplicate(true)
		ending["runtime_id"] = runtime_id
		ending["status"] = status
		ending["age"] = 0.0
		ending["duration"] = END_VISUAL_DURATION
		ending_pulses.append(ending)
		first_seen_anim_time.erase(runtime_id)


func get_drones_for_side(side: String) -> Array:
	var results: Array = []
	for drone in active_drones:
		if typeof(drone) != TYPE_DICTIONARY:
			continue
		if clean_side(str(drone.get("owner_side", "player"))) == side:
			results.append(drone)
	return results


func build_orbit_radius(side_index: int, side_count: int) -> float:
	var ring := side_index % 4
	var band := int(side_index / 4)
	var spread_bonus = min(float(side_count), 6.0) * 1.8
	return 42.0 + float(ring) * 13.0 + float(band) * 7.0 + spread_bonus


func build_runtime_phase(runtime_id: String, side_index: int, side_count: int) -> float:
	var count = max(side_count, 1)
	var phase := float(side_index) * TAU / float(count)
	var hash_part := 0.0
	if runtime_id != "":
		hash_part = float(abs(runtime_id.hash() % 1000)) / 1000.0 * TAU * 0.18
	return phase + hash_part


func get_display_time_remaining(drone: Dictionary, anim_time: float) -> float:
	var base := float(drone.get("time_remaining", 0.0))
	var last_packet_time := float(drone.get("last_packet_anim_time", anim_time))
	return max(base - max(anim_time - last_packet_time, 0.0), 0.0)


func get_display_fire_timer(drone: Dictionary, anim_time: float, fire_interval: float) -> float:
	var base := float(drone.get("fire_timer", fire_interval))
	var last_packet_time := float(drone.get("last_packet_anim_time", anim_time))
	return max(base - max(anim_time - last_packet_time, 0.0), 0.0)


func get_actor_center(canvas: Control, anchors: Dictionary, side: String) -> Vector2:
	if canvas != null and canvas.has_method("get_actor_center"):
		var value = canvas.call("get_actor_center", side)
		if typeof(value) == TYPE_VECTOR2:
			return value
	var actor_rect := get_anchor_rect(anchors, side + "_actor")
	if actor_rect.size != Vector2.ZERO:
		return actor_rect.position + actor_rect.size * 0.5
	var lane_rect := get_anchor_rect(anchors, side + "_lane")
	if lane_rect.size == Vector2.ZERO:
		return Vector2.ZERO
	var x := lane_rect.position.x + 58.0
	if side == "enemy":
		x = lane_rect.position.x + lane_rect.size.x - 58.0
	return Vector2(x, lane_rect.position.y + lane_rect.size.y * 0.5)


func get_anchor_rect(anchors: Dictionary, key: String) -> Rect2:
	var value = anchors.get(key, Rect2())
	if typeof(value) == TYPE_RECT2:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		return Rect2(value.get("position", Vector2.ZERO), value.get("size", Vector2.ZERO))
	return Rect2()


func get_colors_for_side(side: String) -> Dictionary:
	if side == "enemy":
		return {
			"main": ENEMY_DRONE_COLOR,
			"core": ENEMY_DRONE_CORE,
			"hot": ENEMY_DRONE_HOT
		}
	return {
		"main": PLAYER_DRONE_COLOR,
		"core": PLAYER_DRONE_CORE,
		"hot": PLAYER_DRONE_HOT
	}


func get_drone_runtime_id(drone: Dictionary) -> String:
	var runtime_id := str(drone.get("runtime_id", drone.get("match_id", ""))).strip_edges()
	if runtime_id != "":
		return runtime_id
	var source_item_id := str(drone.get("source_item_id", "drone")).strip_edges()
	var side := clean_side(str(drone.get("owner_side", "player")))
	var time_key := str(int(round(float(drone.get("time_remaining", 0.0)) * 10.0)))
	return side + "_" + source_item_id + "_" + time_key


func get_attack_key(attack: Dictionary) -> String:
	var explicit_key := str(attack.get("ui_attack_key", "")).strip_edges()
	if explicit_key != "":
		return explicit_key
	var runtime_id := str(attack.get("runtime_id", "")).strip_edges()
	var shot_index := str(int(attack.get("shot_index", 0)))
	var shot_total := str(int(attack.get("shot_total", attack.get("max_shots", 0))))
	return runtime_id + ":" + shot_index + ":" + shot_total


func prune_seen_keys() -> void:
	# Prevent these dictionaries from growing forever during long battle tests.
	if seen_attack_keys.size() > 128:
		seen_attack_keys.clear()
	if seen_ending_keys.size() > 128:
		seen_ending_keys.clear()


func clean_side(value: String) -> String:
	var side := value.strip_edges().to_lower()
	if side == "enemy":
		return "enemy"
	return "player"


func get_opposite_side(side: String) -> String:
	return "player" if side == "enemy" else "enemy"
