extends Control
class_name BattleV2EffectLayer

const TOP_LAYER_Z_INDEX := 650
const DEFAULT_SCREEN_SIZE := Vector2(1280, 760)

var position_data: Dictionary = {}
var effect_id_counter: int = 0

var active_delayed_effects: Array = []
var active_flash_box_effects: Array = []
var active_particle_trail_effects: Array = []
var active_flash_line_effects: Array = []
var active_particle_explosion_effects: Array = []
var active_spark_burst_effects: Array = []

var active_ring_pulse_effects: Array = []
var active_float_text_effects: Array = []
var active_shield_ring_groups: Dictionary = {}
var active_breathing_energy_frames: Dictionary = {}
var active_drone_orbit_effects: Dictionary = {}
var active_recovery_pack_flights: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = TOP_LAYER_Z_INDEX
	z_as_relative = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if size == Vector2.ZERO:
		size = Vector2(Globals.screen_w, Globals.screen_h) if Globals.screen_w > 0 else DEFAULT_SCREEN_SIZE
	set_process(false)


func setup(refs: Dictionary = {}) -> void:
	if typeof(refs.get("position_data", {})) == TYPE_DICTIONARY:
		position_data = refs.get("position_data", {}).duplicate(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = int(refs.get("z_index", TOP_LAYER_Z_INDEX))
	z_as_relative = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = refs.get("size", Vector2(Globals.screen_w, Globals.screen_h))
	if size == Vector2.ZERO:
		size = DEFAULT_SCREEN_SIZE


func _process(delta: float) -> void:
	update_delayed_effects(delta)
	update_flash_box_effects(delta)
	update_particle_trail_effects(delta)
	update_flash_line_effects(delta)
	update_particle_explosion_effects(delta)
	update_spark_burst_effects(delta)
	update_ring_pulse_effects(delta)
	update_float_text_effects(delta)
	update_shield_ring_groups(delta)
	update_breathing_energy_frames(delta)
	update_drone_orbit_effects(delta)
	update_recovery_pack_flights(delta)
	update_processing_state()


func flash_box(
	point_id: String,
	color: Color,
	duration_sec: float = 0.3,
	thickness: float = 4.0,
	pulse_speed: float = 18.0,
	padding: float = 4.0,
	effect_kind: String = "flash_box"
) -> Dictionary:
	var point := get_point(point_id)
	if point.is_empty():
		return make_failed_effect(effect_kind, "missing point: " + point_id)

	var point_pos: Vector2 = point.get("position", Vector2.ZERO)
	var point_size: Vector2 = point.get("size", Vector2.ZERO)
	var pad = max(float(padding), 0.0)
	var line_thickness = max(float(thickness), 1.0)

	var root := Control.new()
	root.name = "Effect_" + effect_kind
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = point_pos - Vector2(pad, pad)
	root.size = point_size + Vector2(pad * 2.0, pad * 2.0)
	root.clip_contents = false
	add_child(root)

	var edge_color := color
	var edge_entries := [
		make_rect(root, Vector2.ZERO, Vector2(root.size.x, line_thickness), edge_color),
		make_rect(root, Vector2(0, root.size.y - line_thickness), Vector2(root.size.x, line_thickness), edge_color),
		make_rect(root, Vector2.ZERO, Vector2(line_thickness, root.size.y), edge_color),
		make_rect(root, Vector2(root.size.x - line_thickness, 0), Vector2(line_thickness, root.size.y), edge_color)
	]

	var effect := make_effect_packet(effect_kind, root, duration_sec, {
		"point_id": point_id,
		"color": color,
		"pulse_speed": pulse_speed,
		"edges": edge_entries
	})
	active_flash_box_effects.append(effect)
	set_process(true)
	return effect


func particle_trail(
	start_xy: Vector2,
	finish_xy: Vector2,
	color: Color,
	particle_size: float = 6.0,
	speed: float = 900.0,
	trail_length: int = 10,
	duration_sec: float = 0.2,
	effect_kind: String = "particle_trail"
) -> Dictionary:
	var root := Control.new()
	root.name = "Effect_" + effect_kind
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2.ZERO
	root.size = size
	root.clip_contents = false
	add_child(root)

	var particle_entries: Array = []
	var count = max(int(trail_length), 1)
	var diameter = max(float(particle_size), 1.0)
	for i in range(count):
		var alpha_scale := 1.0 - (float(i) / float(count + 1))
		var dot_color := Color(color.r, color.g, color.b, color.a * alpha_scale)
		var dot := make_circle(root, start_xy, diameter * max(alpha_scale, 0.35), dot_color)
		particle_entries.append({
			"node": dot,
			"index": i,
			"diameter": diameter * max(alpha_scale, 0.35),
			"base_color": dot_color
		})

	var distance = max(start_xy.distance_to(finish_xy), 1.0)
	var speed_duration = distance / max(float(speed), 1.0)
	var effect_duration = max(float(duration_sec), speed_duration, 0.05)
	var effect := make_effect_packet(effect_kind, root, effect_duration, {
		"start": start_xy,
		"finish": finish_xy,
		"particles": particle_entries,
		"trail_length": count,
		"speed": speed,
		"color": color
	})
	active_particle_trail_effects.append(effect)
	set_process(true)
	return effect


func particle_trail_between_points(
	from_point_id: String,
	to_point_id: String,
	color: Color,
	particle_size: float = 6.0,
	speed: float = 900.0,
	trail_length: int = 10,
	duration_sec: float = 0.2
) -> Dictionary:
	return particle_trail(
		get_point_center(from_point_id),
		get_point_center(to_point_id),
		color,
		particle_size,
		speed,
		trail_length,
		duration_sec,
		"particle_trail_between_points"
	)


func flash_line(
	start_xy: Vector2,
	finish_xy: Vector2,
	color: Color,
	width: float = 4.0,
	duration_sec: float = 0.22,
	glow_width: float = 18.0,
	effect_kind: String = "flash_line"
) -> Dictionary:
	var root := Node2D.new()
	root.name = "Effect_" + effect_kind
	root.z_index = TOP_LAYER_Z_INDEX + 10
	add_child(root)

	var glow_line := make_line(root, color, max(float(glow_width), float(width)), color.a * 0.18)
	var mid_line := make_line(root, color, max(float(width) * 2.0, float(width)), color.a * 0.48)
	var core_line := make_line(root, color, max(float(width), 1.0), color.a)

	var effect := make_effect_packet(effect_kind, root, duration_sec, {
		"start": start_xy,
		"finish": finish_xy,
		"color": color,
		"lines": [glow_line, mid_line, core_line]
	})
	active_flash_line_effects.append(effect)
	set_process(true)
	return effect


func flash_line_between_points(
	from_point_id: String,
	to_point_id: String,
	color: Color,
	width: float = 4.0,
	duration_sec: float = 0.22,
	effect_kind: String = "flash_line"
) -> Dictionary:
	return flash_line(
		get_point_center(from_point_id),
		get_point_center(to_point_id),
		color,
		width,
		duration_sec,
		18.0,
		effect_kind
	)


func particle_explosion(
	center_xy: Vector2,
	color: Color,
	count: int = 24,
	size_min: float = 4.0,
	size_max: float = 12.0,
	speed_min: float = 30.0,
	speed_max: float = 90.0,
	duration_sec: float = 1.0,
	effect_kind: String = "particle_explosion"
) -> Dictionary:
	var root := Control.new()
	root.name = "Effect_" + effect_kind
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2.ZERO
	root.size = size
	root.clip_contents = false
	add_child(root)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var particles: Array = []
	for i in range(max(int(count), 1)):
		var angle := rng.randf_range(0.0, TAU)
		var direction := Vector2(cos(angle), sin(angle)).normalized()
		var diameter := rng.randf_range(size_min, size_max)
		var speed_value := rng.randf_range(speed_min, speed_max)
		var dot := make_circle(root, center_xy, diameter, color)
		particles.append({
			"node": dot,
			"start": center_xy,
			"direction": direction,
			"speed": speed_value,
			"diameter": diameter,
			"base_color": color
		})

	var effect := make_effect_packet(effect_kind, root, duration_sec, {
		"center": center_xy,
		"particles": particles,
		"color": color
	})
	active_particle_explosion_effects.append(effect)
	set_process(true)
	return effect


func directional_particle_burst(
	center_xy: Vector2,
	spray_direction: Vector2,
	color: Color,
	count: int = 22,
	size_min: float = 3.0,
	size_max: float = 8.0,
	speed_min: float = 120.0,
	speed_max: float = 260.0,
	spread_radians: float = 0.55,
	duration_sec: float = 0.55,
	effect_kind: String = "directional_particle_burst"
) -> Dictionary:
	var root := Control.new()
	root.name = "Effect_" + effect_kind
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2.ZERO
	root.size = size
	root.clip_contents = false
	add_child(root)

	var base_direction := spray_direction.normalized()
	if base_direction == Vector2.ZERO:
		base_direction = Vector2.UP

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var particles: Array = []
	var safe_spread = max(float(spread_radians), 0.0)
	for i in range(max(int(count), 1)):
		var offset_angle := rng.randf_range(-safe_spread, safe_spread)
		var direction := base_direction.rotated(offset_angle).normalized()
		var diameter := rng.randf_range(size_min, size_max)
		var speed_value := rng.randf_range(speed_min, speed_max)
		var start_jitter := Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-4.0, 4.0))
		var dot := make_circle(root, center_xy + start_jitter, diameter, color)
		particles.append({
			"node": dot,
			"start": center_xy + start_jitter,
			"direction": direction,
			"speed": speed_value,
			"diameter": diameter,
			"base_color": color
		})

	var effect := make_effect_packet(effect_kind, root, duration_sec, {
		"center": center_xy,
		"spray_direction": base_direction,
		"particles": particles,
		"color": color
	})
	active_particle_explosion_effects.append(effect)
	set_process(true)
	return effect


func spark_burst_around_box(
	point_id: String,
	color: Color,
	count: int = 34,
	size_min: float = 5.0,
	size_max: float = 14.0,
	distance_min: float = 22.0,
	distance_max: float = 78.0,
	duration_sec: float = 1.5,
	effect_kind: String = "spark_burst_around_box"
) -> Dictionary:
	var point := get_point(point_id)
	if point.is_empty():
		return make_failed_effect(effect_kind, "missing point: " + point_id)

	var point_pos: Vector2 = point.get("position", Vector2.ZERO)
	var point_size: Vector2 = point.get("size", Vector2.ZERO)
	var root := Control.new()
	root.name = "Effect_" + effect_kind
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = point_pos
	root.size = point_size
	root.clip_contents = false
	add_child(root)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var sparks: Array = []
	for i in range(max(int(count), 1)):
		var edge := rng.randi_range(0, 3)
		var start_pos := Vector2.ZERO
		var outward_dir := Vector2.UP

		if edge == 0:
			start_pos = Vector2(rng.randf_range(0.0, point_size.x), rng.randf_range(-4.0, 6.0))
			outward_dir = Vector2(rng.randf_range(-0.35, 0.35), -1.0).normalized()
		elif edge == 1:
			start_pos = Vector2(rng.randf_range(0.0, point_size.x), point_size.y + rng.randf_range(-6.0, 4.0))
			outward_dir = Vector2(rng.randf_range(-0.35, 0.35), 1.0).normalized()
		elif edge == 2:
			start_pos = Vector2(rng.randf_range(-4.0, 6.0), rng.randf_range(0.0, point_size.y))
			outward_dir = Vector2(-1.0, rng.randf_range(-0.35, 0.35)).normalized()
		else:
			start_pos = Vector2(point_size.x + rng.randf_range(-6.0, 4.0), rng.randf_range(0.0, point_size.y))
			outward_dir = Vector2(1.0, rng.randf_range(-0.35, 0.35)).normalized()

		var diameter := rng.randf_range(size_min, size_max)
		var travel_distance := rng.randf_range(distance_min, distance_max)
		var phase := rng.randf_range(0.0, TAU)
		var sparkle_speed := rng.randf_range(14.0, 32.0)
		var spark := make_circle(root, start_pos, diameter, color)
		sparks.append({
			"node": spark,
			"start": start_pos,
			"direction": outward_dir,
			"diameter": diameter,
			"travel_distance": travel_distance,
			"phase": phase,
			"sparkle_speed": sparkle_speed,
			"base_color": color
		})

	var effect := make_effect_packet(effect_kind, root, duration_sec, {
		"point_id": point_id,
		"sparks": sparks,
		"color": color
	})
	active_spark_burst_effects.append(effect)
	set_process(true)
	return effect


func delayed_effect(
	delay_sec: float,
	effect_callable: Callable,
	args: Array = [],
	effect_kind: String = "delayed_effect"
) -> Dictionary:
	var effect := make_effect_packet(effect_kind, null, max(float(delay_sec), 0.0), {
		"ready_sec": get_now_sec() + max(float(delay_sec), 0.0),
		"effect_callable": effect_callable,
		"args": args
	})
	active_delayed_effects.append(effect)
	set_process(true)
	return effect


func set_shield_ring_group(packet: Dictionary) -> Dictionary:
	# Summary: Create or update one persistent nested shield ring HUD group.
	var match_id := str(packet.get("match_id", "shield_ring_group")).strip_edges()
	if match_id == "":
		match_id = "shield_ring_group"

	var point_id := str(packet.get("point_id", "shield_panel")).strip_edges()
	var point := get_point(point_id)
	if point.is_empty():
		return make_failed_effect("shield_ring_group", "missing point: " + point_id)

	var point_pos: Vector2 = point.get("position", Vector2.ZERO)
	var point_size: Vector2 = point.get("size", Vector2.ZERO)
	var max_count = max(int(packet.get("max_count", 4)), 1)
	var active_count = clamp(int(packet.get("active_count", 0)), 0, max_count)
	var base_color := get_packet_color(packet, "base_color", Color(0.4, 0.8, 1.0, 0.45))
	var has_energy := bool(packet.get("has_energy", true))
	var state := str(packet.get("state", "active")).strip_edges().to_lower()
	if state == "":
		state = "active"

	var group: Dictionary = active_shield_ring_groups.get(match_id, {})
	var root: Control = group.get("root", null)
	if root == null or not is_instance_valid(root):
		root = Control.new()
		root.name = "ShieldRingGroup_" + match_id
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.position = point_pos
		root.size = point_size
		root.clip_contents = false
		add_child(root)
		group = {
			"root": root,
			"rings": [],
			"started_sec": get_now_sec()
		}

	root.position = point_pos
	root.size = point_size
	root.visible = state != "hidden"

	var rings: Array = group.get("rings", [])
	if rings.size() != max_count:
		for child in root.get_children():
			child.queue_free()
		rings.clear()
		for i in range(max_count):
			rings.append({
				"node": make_shield_ring_circle(root),
				"index": i
			})

	group["root"] = root
	group["rings"] = rings
	group["point_id"] = point_id
	group["point_pos"] = point_pos
	group["point_size"] = point_size
	group["active_count"] = active_count
	group["max_count"] = max_count
	group["base_color"] = base_color
	group["has_energy"] = has_energy
	group["state"] = state
	group["smallest_radius"] = float(packet.get("smallest_radius", 24.0))
	group["largest_radius_scale"] = float(packet.get("largest_radius_scale", 0.42))
	group["pulse_speed"] = float(packet.get("pulse_speed", 3.6))
	active_shield_ring_groups[match_id] = group
	set_process(true)

	return {
		"ok": true,
		"match_id": match_id,
		"effect_kind": "shield_ring_group",
		"point_id": point_id
	}


func make_shield_ring_circle(parent: Control) -> Panel:
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ring)
	return ring


func clear_shield_ring_groups() -> void:
	for key in active_shield_ring_groups.keys():
		var group: Dictionary = active_shield_ring_groups[key]
		var root = group.get("root", null)
		if root != null and is_instance_valid(root):
			root.queue_free()
	active_shield_ring_groups.clear()


func clear_all_effects() -> void:
	clear_effect_bucket(active_flash_box_effects)
	clear_effect_bucket(active_particle_trail_effects)
	clear_effect_bucket(active_flash_line_effects)
	clear_effect_bucket(active_particle_explosion_effects)
	clear_effect_bucket(active_spark_burst_effects)
	clear_effect_bucket(active_ring_pulse_effects)
	clear_effect_bucket(active_float_text_effects)
	clear_breathing_energy_frames()
	clear_shield_ring_groups()
	clear_drone_orbits()
	clear_effect_bucket(active_recovery_pack_flights)
	active_delayed_effects.clear()
	set_process(false)


func update_delayed_effects(_delta: float) -> void:
	var now_sec := get_now_sec()
	for i in range(active_delayed_effects.size() - 1, -1, -1):
		var effect: Dictionary = active_delayed_effects[i]
		if now_sec < float(effect.get("ready_sec", now_sec)):
			continue

		var effect_callable = effect.get("effect_callable", Callable())
		var args: Array = effect.get("args", [])
		if typeof(effect_callable) == TYPE_CALLABLE and effect_callable.is_valid():
			effect_callable.callv(args)
		active_delayed_effects.remove_at(i)


func update_flash_box_effects(_delta: float) -> void:
	var now_sec := get_now_sec()
	for i in range(active_flash_box_effects.size() - 1, -1, -1):
		var effect: Dictionary = active_flash_box_effects[i]
		if effect_expired(effect, now_sec):
			remove_effect_at(active_flash_box_effects, i)
			continue

		var elapsed := now_sec - float(effect.get("started_sec", now_sec))
		var duration_sec = max(float(effect.get("duration_sec", 0.1)), 0.1)
		var t = clamp(elapsed / duration_sec, 0.0, 1.0)
		var fade := get_fade_out(t)
		var pulse_speed := float(effect.get("pulse_speed", 18.0))
		var color: Color = effect.get("color", Color.WHITE)
		var pulse := 0.45 + 0.55 * ((sin(elapsed * pulse_speed) + 1.0) * 0.5)

		for edge in effect.get("edges", []):
			if typeof(edge) != TYPE_DICTIONARY:
				continue
			var rect: ColorRect = edge.get("node", null)
			if rect == null or not is_instance_valid(rect):
				continue
			var c := color
			c.a = color.a * pulse * fade
			rect.color = c


func update_particle_trail_effects(_delta: float) -> void:
	var now_sec := get_now_sec()
	for i in range(active_particle_trail_effects.size() - 1, -1, -1):
		var effect: Dictionary = active_particle_trail_effects[i]
		if effect_expired(effect, now_sec):
			remove_effect_at(active_particle_trail_effects, i)
			continue

		var elapsed := now_sec - float(effect.get("started_sec", now_sec))
		var duration_sec= max(float(effect.get("duration_sec", 0.1)), 0.1)
		var base_t = clamp(elapsed / duration_sec, 0.0, 1.0)
		var start: Vector2 = effect.get("start", Vector2.ZERO)
		var finish: Vector2 = effect.get("finish", Vector2.ZERO)
		var trail_length = max(int(effect.get("trail_length", 1)), 1)

		for particle in effect.get("particles", []):
			if typeof(particle) != TYPE_DICTIONARY:
				continue
			var dot: Panel = particle.get("node", null)
			if dot == null or not is_instance_valid(dot):
				continue
			var index := int(particle.get("index", 0))
			var particle_t = clamp(base_t - (float(index) / float(trail_length + 3)) * 0.30, 0.0, 1.0)
			var center := start.lerp(finish, particle_t)
			var fade := get_fade_out(base_t) * (1.0 - float(index) / float(trail_length + 1))
			move_circle(dot, center, float(particle.get("diameter", 6.0)), particle.get("base_color", Color.WHITE), fade)


func update_flash_line_effects(_delta: float) -> void:
	var now_sec := get_now_sec()
	for i in range(active_flash_line_effects.size() - 1, -1, -1):
		var effect: Dictionary = active_flash_line_effects[i]
		if effect_expired(effect, now_sec):
			remove_effect_at(active_flash_line_effects, i)
			continue

		var elapsed := now_sec - float(effect.get("started_sec", now_sec))
		var duration_sec = max(float(effect.get("duration_sec", 0.05)), 0.05)
		var t = clamp(elapsed / duration_sec, 0.0, 1.0)
		var draw_t = clamp(t / 0.45, 0.0, 1.0)
		var fade := get_fade_out(t)
		var start: Vector2 = effect.get("start", Vector2.ZERO)
		var finish: Vector2 = effect.get("finish", Vector2.ZERO)
		var color: Color = effect.get("color", Color.WHITE)
		var current_finish := start.lerp(finish, draw_t)
		var jitter := Vector2(sin(elapsed * 70.0), cos(elapsed * 64.0)) * 2.0 * fade

		for line_node in effect.get("lines", []):
			if line_node == null or not is_instance_valid(line_node):
				continue
			var line: Line2D = line_node
			line.points = PackedVector2Array([start, current_finish + jitter])
			var c := color
			if line.width >= 18.0:
				c.a = color.a * 0.18 * fade
			elif line.width >= 8.0:
				c.a = color.a * 0.48 * fade
			else:
				c.a = color.a * fade
			line.default_color = c


func update_particle_explosion_effects(_delta: float) -> void:
	var now_sec := get_now_sec()
	for i in range(active_particle_explosion_effects.size() - 1, -1, -1):
		var effect: Dictionary = active_particle_explosion_effects[i]
		if effect_expired(effect, now_sec):
			remove_effect_at(active_particle_explosion_effects, i)
			continue

		var elapsed := now_sec - float(effect.get("started_sec", now_sec))
		var duration_sec = max(float(effect.get("duration_sec", 0.1)), 0.1)
		var t = clamp(elapsed / duration_sec, 0.0, 1.0)
		var fade = 1.0 - t

		for particle in effect.get("particles", []):
			if typeof(particle) != TYPE_DICTIONARY:
				continue
			var dot: Panel = particle.get("node", null)
			if dot == null or not is_instance_valid(dot):
				continue
			var center: Vector2 = particle.get("start", Vector2.ZERO)
			center += particle.get("direction", Vector2.UP) * float(particle.get("speed", 40.0)) * elapsed
			move_circle(dot, center, float(particle.get("diameter", 6.0)), particle.get("base_color", Color.WHITE), fade)


func update_spark_burst_effects(_delta: float) -> void:
	var now_sec := get_now_sec()
	for i in range(active_spark_burst_effects.size() - 1, -1, -1):
		var effect: Dictionary = active_spark_burst_effects[i]
		if effect_expired(effect, now_sec):
			remove_effect_at(active_spark_burst_effects, i)
			continue

		var elapsed := now_sec - float(effect.get("started_sec", now_sec))
		var duration_sec = max(float(effect.get("duration_sec", 0.1)), 0.1)
		var t = clamp(elapsed / duration_sec, 0.0, 1.0)
		var ease_out := 1.0 - pow(1.0 - t, 2.0)
		var fade = 1.0 - t

		for spark in effect.get("sparks", []):
			if typeof(spark) != TYPE_DICTIONARY:
				continue
			var dot: Panel = spark.get("node", null)
			if dot == null or not is_instance_valid(dot):
				continue
			var start: Vector2 = spark.get("start", Vector2.ZERO)
			var direction: Vector2 = spark.get("direction", Vector2.UP)
			var travel := float(spark.get("travel_distance", 40.0))
			var phase := float(spark.get("phase", 0.0))
			var sparkle_speed := float(spark.get("sparkle_speed", 18.0))
			var sparkle := 0.45 + 0.55 * ((sin((elapsed * sparkle_speed) + phase) + 1.0) * 0.5)
			var jitter = Vector2(sin((elapsed * 35.0) + phase), cos((elapsed * 31.0) + phase)) * 3.0 * fade
			var center = start + (direction * travel * ease_out) + jitter
			var diameter = float(spark.get("diameter", 8.0)) * (1.0 + sparkle * 0.45 * fade)
			move_circle(dot, center, diameter, spark.get("base_color", Color.WHITE), fade * sparkle)


func launch_square_pack_between_points(
	from_point_id: String,
	to_point_id: String,
	color: Color,
	core_color: Color,
	duration_sec: float = 0.28,
	pack_size: float = 28.0,
	arc_height: float = 46.0,
	effect_kind: String = "recovery_pack_flight"
) -> Dictionary:
	var from_point := get_point(from_point_id)
	var to_point := get_point(to_point_id)
	if from_point.is_empty():
		return make_failed_effect(effect_kind, "missing point: " + from_point_id)
	if to_point.is_empty():
		return make_failed_effect(effect_kind, "missing point: " + to_point_id)

	var start_xy := get_point_center(from_point_id)
	var finish_xy := get_point_center(to_point_id)
	var safe_size = max(float(pack_size), 12.0)
	var safe_duration = max(float(duration_sec), 0.08)

	var root := Control.new()
	root.name = "Effect_" + effect_kind
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2.ZERO
	root.size = size
	root.clip_contents = false
	add_child(root)

	var ghosts: Array = []
	for i in range(3):
		var ghost_alpha := 0.18 - float(i) * 0.04
		var ghost := make_recovery_pack_node(
			root,
			safe_size * (0.92 - float(i) * 0.08),
			Color(color.r, color.g, color.b, ghost_alpha),
			Color(core_color.r, core_color.g, core_color.b, ghost_alpha * 1.4),
			"RecoveryPackGhost" + str(i + 1)
		)
		ghosts.append(ghost)

	var pack := make_recovery_pack_node(
		root,
		safe_size,
		color,
		core_color,
		"RecoveryPack"
	)

	var effect := make_effect_packet(effect_kind, root, safe_duration, {
		"from_point_id": from_point_id,
		"to_point_id": to_point_id,
		"start": start_xy,
		"finish": finish_xy,
		"color": color,
		"core_color": core_color,
		"pack": pack,
		"ghosts": ghosts,
		"pack_size": safe_size,
		"arc_height": max(float(arc_height), 0.0),
		"spin_turns": 1.15
	})
	active_recovery_pack_flights.append(effect)
	set_process(true)
	return effect


func make_recovery_pack_node(
	parent: Control,
	pack_size: float,
	color: Color,
	core_color: Color,
	node_name: String
) -> Control:
	var pack := Control.new()
	pack.name = node_name
	pack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pack.size = Vector2(pack_size, pack_size)
	pack.pivot_offset = pack.size * 0.5
	parent.add_child(pack)

	var glow := Panel.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.position = Vector2(-4, -4)
	glow.size = pack.size + Vector2(8, 8)
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color(color.r, color.g, color.b, color.a * 0.16)
	glow_style.border_color = Color(color.r, color.g, color.b, color.a * 0.40)
	glow_style.set_border_width_all(2)
	glow_style.set_corner_radius_all(5)
	glow_style.shadow_color = Color(color.r, color.g, color.b, color.a * 0.55)
	glow_style.shadow_size = 10
	glow_style.shadow_offset = Vector2.ZERO
	glow.add_theme_stylebox_override("panel", glow_style)
	pack.add_child(glow)

	var body := Panel.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.position = Vector2.ZERO
	body.size = pack.size
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = Color(color.r * 0.18, color.g * 0.28, color.b * 0.18, color.a)
	body_style.border_color = color
	body_style.set_border_width_all(3)
	body_style.set_corner_radius_all(3)
	body.add_theme_stylebox_override("panel", body_style)
	pack.add_child(body)

	var bar_thickness = max(pack_size * 0.18, 3.0)
	var bar_length = max(pack_size * 0.62, 8.0)
	var horizontal := ColorRect.new()
	horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal.color = core_color
	horizontal.size = Vector2(bar_length, bar_thickness)
	horizontal.position = (pack.size - horizontal.size) * 0.5
	pack.add_child(horizontal)

	var vertical := ColorRect.new()
	vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical.color = core_color
	vertical.size = Vector2(bar_thickness, bar_length)
	vertical.position = (pack.size - vertical.size) * 0.5
	pack.add_child(vertical)
	return pack


func update_recovery_pack_flights(_delta: float) -> void:
	var now_sec := get_now_sec()
	for i in range(active_recovery_pack_flights.size() - 1, -1, -1):
		var effect: Dictionary = active_recovery_pack_flights[i]
		if effect_expired(effect, now_sec):
			remove_effect_at(active_recovery_pack_flights, i)
			continue

		var elapsed := now_sec - float(effect.get("started_sec", now_sec))
		var duration_sec = max(float(effect.get("duration_sec", 0.28)), 0.08)
		var t = clamp(elapsed / duration_sec, 0.0, 1.0)
		var eased_t = t * t * (3.0 - 2.0 * t)
		var start_xy: Vector2 = effect.get("start", Vector2.ZERO)
		var finish_xy: Vector2 = effect.get("finish", Vector2.ZERO)
		var arc_height := float(effect.get("arc_height", 46.0))
		var center := start_xy.lerp(finish_xy, eased_t) + Vector2(0, -sin(t * PI) * arc_height)
		var direction_sign := 1.0 if finish_xy.x >= start_xy.x else -1.0
		var rotation_value = direction_sign * t * TAU * float(effect.get("spin_turns", 1.15))
		var pulse_scale := 0.92 + sin(t * PI) * 0.18
		var fade := get_fade_out(t)

		var pack: Control = effect.get("pack", null)
		if pack != null and is_instance_valid(pack):
			pack.position = center - pack.size * 0.5
			pack.rotation = rotation_value
			pack.scale = Vector2.ONE * pulse_scale
			pack.modulate.a = fade

		var ghosts: Array = effect.get("ghosts", [])
		for ghost_index in range(ghosts.size()):
			var ghost: Control = ghosts[ghost_index]
			if ghost == null or not is_instance_valid(ghost):
				continue
			var ghost_delay := 0.07 * float(ghost_index + 1)
			var ghost_t = clamp(t - ghost_delay, 0.0, 1.0)
			var ghost_eased = ghost_t * ghost_t * (3.0 - 2.0 * ghost_t)
			var ghost_center := start_xy.lerp(finish_xy, ghost_eased) + Vector2(0, -sin(ghost_t * PI) * arc_height)
			ghost.position = ghost_center - ghost.size * 0.5
			ghost.rotation = direction_sign * ghost_t * TAU * float(effect.get("spin_turns", 1.15))
			ghost.scale = Vector2.ONE * (0.82 + sin(ghost_t * PI) * 0.10)
			ghost.modulate.a = (0.52 - float(ghost_index) * 0.12) * fade


func set_drone_orbit(packet: Dictionary) -> Dictionary:
	var match_id := str(packet.get("match_id", packet.get("runtime_id", ""))).strip_edges()
	if match_id == "":
		return make_failed_effect("auto_attack_drone_orbit", "missing drone match id")

	var anchor_point_id := str(packet.get("anchor_point_id", "center_stage")).strip_edges()
	if anchor_point_id == "":
		anchor_point_id = "center_stage"
	if get_point(anchor_point_id).is_empty():
		return make_failed_effect("auto_attack_drone_orbit", "missing point: " + anchor_point_id)

	var spawn_point_id := str(packet.get("spawn_point_id", anchor_point_id)).strip_edges()
	if spawn_point_id == "" or get_point(spawn_point_id).is_empty():
		spawn_point_id = anchor_point_id

	var now_sec := get_now_sec()
	var status := str(packet.get("status", "active")).strip_edges().to_lower()
	if status == "":
		status = "active"

	if active_drone_orbit_effects.has(match_id):
		var existing: Dictionary = active_drone_orbit_effects[match_id]
		update_drone_orbit_packet(existing, packet, now_sec, status)
		return existing

	var color: Color = packet.get("color", Color(0.25, 0.85, 1.0, 0.88))
	var core_color: Color = packet.get("core_color", Color(0.88, 0.98, 1.0, 0.96))
	var spawn_xy := get_point_center(spawn_point_id)
	var anchor_xy := get_point_center(anchor_point_id)

	var root := Control.new()
	root.name = "Effect_auto_attack_drone_orbit"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2.ZERO
	root.size = size
	root.clip_contents = false
	add_child(root)

	var label := Label.new()
	label.name = "DroneTimer"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(92, 24)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", core_color)
	root.add_child(label)

	var charge_back := ColorRect.new()
	charge_back.name = "DroneChargeBack"
	charge_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(charge_back)

	var charge_fill := ColorRect.new()
	charge_fill.name = "DroneChargeFill"
	charge_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(charge_fill)

	var effect := make_effect_packet("auto_attack_drone_orbit", root, -1.0, {
		"match_id": match_id,
		"runtime_id": str(packet.get("runtime_id", match_id)),
		"spawn_point_id": spawn_point_id,
		"anchor_point_id": anchor_point_id,
		"spawn_xy": spawn_xy,
		"anchor_xy": anchor_xy,
		"owner_side": str(packet.get("owner_side", "player")),
		"drone_type": str(packet.get("drone_type", "auto_attack")),
		"status": status,
		"color": color,
		"core_color": core_color,
		"time_remaining": float(packet.get("time_remaining", 0.0)),
		"duration": float(packet.get("duration", packet.get("time_remaining", 1.0))),
		"fire_timer": float(packet.get("fire_timer", packet.get("fire_interval", 1.0))),
		"fire_interval": max(float(packet.get("fire_interval", 1.0)), 0.01),
		"drone_fire_count": int(packet.get("drone_fire_count", packet.get("max_shots", 0))),
		"max_shots": int(packet.get("max_shots", packet.get("drone_fire_count", 0))),
		"shots_fired": int(packet.get("shots_fired", 0)),
		"shots_remaining": int(packet.get("shots_remaining", packet.get("max_shots", 0))),
		"migrate_duration": max(float(packet.get("migrate_duration", 0.45)), 0.05),
		"last_update_sec": now_sec,
		"outer": make_circle(root, spawn_xy, 58.0, Color(color.r, color.g, color.b, 0.10)),
		"halo": make_circle(root, spawn_xy, 42.0, Color(color.r, color.g, color.b, 0.18)),
		"body": make_circle(root, spawn_xy, 24.0, color),
		"core": make_circle(root, spawn_xy, 9.0, core_color),
		"left_wing": make_circle(root, spawn_xy, 7.0, Color(color.r, color.g, color.b, 0.72)),
		"right_wing": make_circle(root, spawn_xy, 7.0, Color(color.r, color.g, color.b, 0.72)),
		"nose": make_circle(root, spawn_xy, 5.0, core_color),
		"label": label,
		"charge_back": charge_back,
		"charge_fill": charge_fill
	})

	root.move_child(charge_back, root.get_child_count() - 1)
	root.move_child(charge_fill, root.get_child_count() - 1)
	root.move_child(label, root.get_child_count() - 1)
	active_drone_orbit_effects[match_id] = effect
	set_process(true)
	return effect


func update_drone_orbit_packet(effect: Dictionary, packet: Dictionary, now_sec: float, status: String) -> void:
	effect["time_remaining"] = float(packet.get("time_remaining", effect.get("time_remaining", 0.0)))
	effect["duration"] = float(packet.get("duration", effect.get("duration", effect.get("time_remaining", 1.0))))
	effect["fire_interval"] = max(float(packet.get("fire_interval", effect.get("fire_interval", 1.0))), 0.01)
	effect["fire_timer"] = float(packet.get("fire_timer", effect.get("fire_timer", effect.get("fire_interval", 1.0))))
	effect["drone_fire_count"] = int(packet.get("drone_fire_count", effect.get("drone_fire_count", packet.get("max_shots", 0))))
	effect["max_shots"] = int(packet.get("max_shots", effect.get("max_shots", effect.get("drone_fire_count", 0))))
	effect["shots_fired"] = int(packet.get("shots_fired", effect.get("shots_fired", 0)))
	effect["shots_remaining"] = int(packet.get("shots_remaining", effect.get("shots_remaining", effect.get("max_shots", 0))))
	effect["last_update_sec"] = now_sec
	effect["status"] = status
	effect["owner_side"] = str(packet.get("owner_side", effect.get("owner_side", "player")))
	effect["drone_type"] = str(packet.get("drone_type", effect.get("drone_type", "auto_attack")))
	if packet.has("color"):
		effect["color"] = packet.get("color")
	if packet.has("core_color"):
		effect["core_color"] = packet.get("core_color")
	if status != "active" and not effect.has("ending_sec"):
		effect["ending_sec"] = now_sec


func update_drone_orbit_effects(_delta: float) -> void:
	var now_sec := get_now_sec()
	var dead_keys: Array = []

	for match_id in active_drone_orbit_effects.keys():
		var effect: Dictionary = active_drone_orbit_effects[match_id]
		var root: Control = effect.get("root", null)
		if root == null or not is_instance_valid(root):
			dead_keys.append(match_id)
			continue

		var status := str(effect.get("status", "active")).strip_edges().to_lower()
		var last_update_sec := float(effect.get("last_update_sec", now_sec))
		if status == "active" and now_sec - last_update_sec > 1.6:
			status = "expired"
			effect["status"] = status
			effect["ending_sec"] = now_sec

		var end_fade := 1.0
		if status != "active":
			var ending_sec := float(effect.get("ending_sec", now_sec))
			var end_elapsed := now_sec - ending_sec
			if end_elapsed > 0.72:
				dead_keys.append(match_id)
				continue
			end_fade = clamp(1.0 - (end_elapsed / 0.72), 0.0, 1.0)

		var elapsed := now_sec - float(effect.get("started_sec", now_sec))
		var migrate_duration = max(float(effect.get("migrate_duration", 0.45)), 0.05)
		var migrate_t = clamp(elapsed / migrate_duration, 0.0, 1.0)
		var ease_t := 1.0 - pow(1.0 - migrate_t, 3.0)
		var spawn_xy: Vector2 = effect.get("spawn_xy", Vector2.ZERO)
		var anchor_xy: Vector2 = effect.get("anchor_xy", Vector2.ZERO)
		var center := spawn_xy.lerp(anchor_xy, ease_t)

		if migrate_t >= 1.0:
			var hover := Vector2(cos(elapsed * 2.5), sin(elapsed * 3.2)) * 5.0
			center += hover

		var color: Color = effect.get("color", Color(0.25, 0.85, 1.0, 0.88))
		var core_color: Color = effect.get("core_color", Color(0.88, 0.98, 1.0, 0.96))
		var fire_interval = max(float(effect.get("fire_interval", 1.0)), 0.01)
		var fire_timer = max(float(effect.get("fire_timer", fire_interval)) - max(now_sec - last_update_sec, 0.0), 0.0)
		var charge_ratio = clamp(1.0 - (fire_timer / fire_interval), 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin((elapsed * 5.2) + charge_ratio * TAU)
		var fire_glow = 1.0 + charge_ratio * 0.32 + pulse * 0.08

		move_drone_circle(effect, "outer", center, 56.0 + 8.0 * pulse, Color(color.r, color.g, color.b, 0.10), end_fade)
		move_drone_circle(effect, "halo", center, 40.0 + 4.0 * charge_ratio, Color(color.r, color.g, color.b, 0.20), end_fade)
		move_drone_circle(effect, "body", center, 23.0 * fire_glow, color, end_fade)
		move_drone_circle(effect, "core", center, 8.0 + 3.0 * charge_ratio, core_color, end_fade)

		var side_sign := -1.0 if str(effect.get("owner_side", "player")).strip_edges().to_lower() == "enemy" else 1.0
		var wing_y := sin(elapsed * 7.0) * 2.5
		move_drone_circle(effect, "left_wing", center + Vector2(-18.0 * side_sign, wing_y), 7.0, Color(color.r, color.g, color.b, 0.72), end_fade)
		move_drone_circle(effect, "right_wing", center + Vector2(18.0 * side_sign, -wing_y), 7.0, Color(color.r, color.g, color.b, 0.72), end_fade)
		move_drone_circle(effect, "nose", center + Vector2(0, -15.0), 5.0 + charge_ratio * 2.0, core_color, end_fade)

		update_drone_timer_label(effect, center, now_sec, end_fade)
		update_drone_charge_bar(effect, center, color, core_color, charge_ratio, end_fade)

	for match_id in dead_keys:
		clear_drone_orbit(str(match_id))


func move_drone_circle(effect: Dictionary, key: String, center: Vector2, diameter: float, color: Color, alpha_scale: float) -> void:
	var circle: Panel = effect.get(key, null)
	if circle == null or not is_instance_valid(circle):
		return
	move_circle(circle, center, diameter, color, alpha_scale)


func update_drone_timer_label(effect: Dictionary, center: Vector2, now_sec: float, alpha_scale: float) -> void:
	var label: Label = effect.get("label", null)
	if label == null or not is_instance_valid(label):
		return

	var last_update_sec := float(effect.get("last_update_sec", now_sec))
	var display_remaining = max(float(effect.get("time_remaining", 0.0)) - max(now_sec - last_update_sec, 0.0), 0.0)
	var status := str(effect.get("status", "active")).strip_edges().to_lower()
	if status == "destroyed":
		label.text = "DOWN"
	elif status == "expired":
		label.text = "DONE"
	else:
		label.text = "%0.1fs" % display_remaining
		var max_shots := int(effect.get("max_shots", effect.get("drone_fire_count", 0)))
		if max_shots > 0:
			label.text += " " + str(max(int(effect.get("shots_remaining", max_shots)), 0)) + "x"

	var core_color: Color = effect.get("core_color", Color.WHITE)
	var c := core_color
	c.a = clamp(core_color.a * alpha_scale, 0.0, 1.0)
	label.add_theme_color_override("font_color", c)
	label.position = center + Vector2(-46, 24)


func update_drone_charge_bar(effect: Dictionary, center: Vector2, color: Color, core_color: Color, charge_ratio: float, alpha_scale: float) -> void:
	var charge_back: ColorRect = effect.get("charge_back", null)
	var charge_fill: ColorRect = effect.get("charge_fill", null)
	if charge_back == null or charge_fill == null:
		return
	if not is_instance_valid(charge_back) or not is_instance_valid(charge_fill):
		return

	var bar_width := 38.0
	var bar_height := 3.0
	var bar_pos := center + Vector2(-bar_width * 0.5, 20.0)
	charge_back.position = bar_pos
	charge_back.size = Vector2(bar_width, bar_height)
	charge_back.color = Color(0.02, 0.04, 0.07, 0.58 * alpha_scale)

	charge_fill.position = bar_pos
	charge_fill.size = Vector2(bar_width * charge_ratio, bar_height)
	charge_fill.color = Color(core_color.r, core_color.g, core_color.b, clamp((0.42 + charge_ratio * 0.42) * alpha_scale, 0.0, 1.0))


func clear_drone_orbit(match_id: String) -> void:
	if not active_drone_orbit_effects.has(match_id):
		return
	var effect: Dictionary = active_drone_orbit_effects[match_id]
	var root = effect.get("root", null)
	if root != null and is_instance_valid(root):
		root.queue_free()
	active_drone_orbit_effects.erase(match_id)


func clear_drone_orbits() -> void:
	var keys := active_drone_orbit_effects.keys()
	for match_id in keys:
		clear_drone_orbit(str(match_id))
	active_drone_orbit_effects.clear()


func update_processing_state() -> void:
	var has_effects := false
	has_effects = has_effects or not active_delayed_effects.is_empty()
	has_effects = has_effects or not active_flash_box_effects.is_empty()
	has_effects = has_effects or not active_particle_trail_effects.is_empty()
	has_effects = has_effects or not active_flash_line_effects.is_empty()
	has_effects = has_effects or not active_particle_explosion_effects.is_empty()
	has_effects = has_effects or not active_spark_burst_effects.is_empty()
	has_effects = has_effects or not active_ring_pulse_effects.is_empty()
	has_effects = has_effects or not active_float_text_effects.is_empty()
	has_effects = has_effects or not active_shield_ring_groups.is_empty()
	has_effects = has_effects or not active_breathing_energy_frames.is_empty()
	has_effects = has_effects or not active_drone_orbit_effects.is_empty()
	has_effects = has_effects or not active_recovery_pack_flights.is_empty()
	set_process(has_effects)


func get_point(point_id: String) -> Dictionary:
	if not position_data.has(point_id):
		return {}
	return position_data[point_id].duplicate(true)


func get_point_center(point_id: String) -> Vector2:
	var point := get_point(point_id)
	if point.is_empty():
		return Vector2.ZERO
	return point.get("position", Vector2.ZERO) + point.get("size", Vector2.ZERO) * 0.5


func make_effect_packet(effect_kind: String, root, duration_sec: float, extra_data: Dictionary = {}) -> Dictionary:
	effect_id_counter += 1
	var effect := {
		"effect_id": "effect_" + str(effect_id_counter),
		"effect_kind": effect_kind,
		"root": root,
		"started_sec": get_now_sec(),
		"duration_sec": max(float(duration_sec), 0.0),
		"source_event_id": str(extra_data.get("source_event_id", "")),
		"source_item_id": str(extra_data.get("source_item_id", "")),
		"source_side": str(extra_data.get("source_side", "")),
		"target_side": str(extra_data.get("target_side", "")),
		"point_id": str(extra_data.get("point_id", "")),
		"data": extra_data.duplicate(true)
	}
	for key in extra_data.keys():
		effect[key] = extra_data[key]
	return effect


func make_failed_effect(effect_kind: String, reason: String) -> Dictionary:
	return {
		"effect_id": "",
		"effect_kind": effect_kind,
		"status": "failed",
		"reason": reason
	}


func make_rect(parent: Control, rect_position: Vector2, rect_size: Vector2, color: Color) -> Dictionary:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.position = rect_position
	rect.size = rect_size
	rect.color = color
	parent.add_child(rect)
	return {"node": rect}


func make_line(parent: Node, color: Color, width: float, alpha: float) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = Color(color.r, color.g, color.b, alpha)
	line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
	line.z_index = TOP_LAYER_Z_INDEX + 10
	parent.add_child(line)
	return line


func make_circle(parent: Control, center_position: Vector2, diameter: float, color: Color) -> Panel:
	var circle := Panel.new()
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(circle)
	move_circle(circle, center_position, diameter, color, 1.0)
	return circle


func move_circle(circle: Panel, center_position: Vector2, diameter: float, color: Color, alpha_scale: float) -> void:
	var safe_diameter = max(float(diameter), 1.0)
	circle.size = Vector2(safe_diameter, safe_diameter)
	circle.position = center_position - circle.size * 0.5

	var c := color
	c.a = clamp(color.a * alpha_scale, 0.0, 1.0)
	var style := StyleBoxFlat.new()
	style.bg_color = c
	style.corner_radius_top_left = int(safe_diameter)
	style.corner_radius_top_right = int(safe_diameter)
	style.corner_radius_bottom_left = int(safe_diameter)
	style.corner_radius_bottom_right = int(safe_diameter)
	style.shadow_color = Color(color.r, color.g, color.b, c.a * 0.45)
	style.shadow_size = int(max(safe_diameter * 0.6, 1.0))
	style.shadow_offset = Vector2.ZERO
	circle.add_theme_stylebox_override("panel", style)


func apply_shield_ring_style(
	ring: Panel,
	center: Vector2,
	diameter: float,
	color: Color,
	is_active: bool,
	has_energy: bool
) -> void:
	var safe_diameter = max(float(diameter), 4.0)
	ring.size = Vector2(safe_diameter, safe_diameter)
	ring.position = center - ring.size * 0.5

	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, color.a * 0.10)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = color
	style.corner_radius_top_left = int(safe_diameter)
	style.corner_radius_top_right = int(safe_diameter)
	style.corner_radius_bottom_left = int(safe_diameter)
	style.corner_radius_bottom_right = int(safe_diameter)

	if is_active and has_energy:
		style.shadow_color = Color(color.r, color.g, color.b, color.a * 0.55)
		style.shadow_size = 8
	else:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.0)
		style.shadow_size = 0

	style.shadow_offset = Vector2.ZERO
	ring.add_theme_stylebox_override("panel", style)


func get_packet_color(packet: Dictionary, key: String, fallback: Color) -> Color:
	var value = packet.get(key, fallback)
	if typeof(value) == TYPE_COLOR:
		return value
	return fallback


func effect_expired(effect: Dictionary, now_sec: float) -> bool:
	var root = effect.get("root", null)
	if root != null and not is_instance_valid(root):
		return true
	var started_sec := float(effect.get("started_sec", now_sec))
	var duration_sec = max(float(effect.get("duration_sec", 0.0)), 0.0)
	return now_sec - started_sec >= duration_sec


func remove_effect_at(bucket: Array, index: int) -> void:
	var effect: Dictionary = bucket[index]
	var root = effect.get("root", null)
	if root != null and is_instance_valid(root):
		root.queue_free()
	bucket.remove_at(index)


func clear_effect_bucket(bucket: Array) -> void:
	for i in range(bucket.size() - 1, -1, -1):
		remove_effect_at(bucket, i)


func get_fade_out(t: float) -> float:
	if t <= 0.80:
		return 1.0
	return clamp(1.0 - ((t - 0.80) / 0.20), 0.0, 1.0)


func get_now_sec() -> float:
	return Time.get_ticks_msec() / 1000.0

func ring_pulse_around_box(
	point_id: String,
	color: Color,
	duration_sec: float = 0.75,
	ring_count: int = 2,
	max_expand: float = 28.0,
	thickness: float = 4.0,
	pulse_gap_sec: float = 0.12,
	padding: float = 4.0,
	effect_kind: String = "ring_pulse_around_box"
) -> Dictionary:
	var point := get_point(point_id)
	if point.is_empty():
		return make_failed_effect(effect_kind, "missing point: " + point_id)

	var point_pos: Vector2 = point.get("position", Vector2.ZERO)
	var point_size: Vector2 = point.get("size", Vector2.ZERO)

	var root := Control.new()
	root.name = "Effect_" + effect_kind
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = point_pos
	root.size = point_size
	root.clip_contents = false
	add_child(root)

	var safe_ring_count = max(int(ring_count), 1)
	var safe_duration = max(float(duration_sec), 0.05)
	var safe_gap = max(float(pulse_gap_sec), 0.0)
	var safe_thickness = max(float(thickness), 1.0)
	var safe_expand = max(float(max_expand), 0.0)
	var safe_padding = max(float(padding), 0.0)

	var rings: Array = []
	for i in range(safe_ring_count):
		var edges = make_ring_edges(root, color)
		rings.append({
			"edges": edges,
			"delay_sec": float(i) * safe_gap
		})

	var total_duration = safe_duration + (float(safe_ring_count - 1) * safe_gap)

	var effect := make_effect_packet(effect_kind, root, total_duration, {
		"point_id": point_id,
		"box_size": point_size,
		"color": color,
		"rings": rings,
		"ring_life_sec": safe_duration,
		"max_expand": safe_expand,
		"thickness": safe_thickness,
		"padding": safe_padding
	})

	active_ring_pulse_effects.append(effect)
	set_process(true)
	return effect
	
	
func float_text(
	start_xy: Vector2,
	text: String,
	color: Color,
	duration_sec: float = 0.9,
	drift_xy: Vector2 = Vector2(0, -34),
	font_size: int = 22,
	effect_kind: String = "float_text"
) -> Dictionary:
	var root := Control.new()
	root.name = "Effect_" + effect_kind
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = Vector2.ZERO
	root.size = size
	root.clip_contents = false
	add_child(root)

	var label := Label.new()
	label.name = "FloatingText"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(260, max(float(font_size) * 2.2, 40.0))
	label.position = start_xy - (label.size * 0.5)
	label.add_theme_font_size_override("font_size", max(int(font_size), 8))
	label.add_theme_color_override("font_color", color)
	root.add_child(label)

	var effect := make_effect_packet(effect_kind, root, duration_sec, {
		"label": label,
		"start": start_xy,
		"drift": drift_xy,
		"color": color,
		"font_size": font_size,
		"text": text
	})

	active_float_text_effects.append(effect)
	set_process(true)
	return effect


func float_text_at_point(
	point_id: String,
	text: String,
	color: Color,
	duration_sec: float = 0.9,
	drift_xy: Vector2 = Vector2(0, -34),
	font_size: int = 22,
	effect_kind: String = "float_text_at_point"
) -> Dictionary:
	var point := get_point(point_id)
	if point.is_empty():
		return make_failed_effect(effect_kind, "missing point: " + point_id)

	return float_text(
		get_point_center(point_id),
		text,
		color,
		duration_sec,
		drift_xy,
		font_size,
		effect_kind
	)
	
	
func update_ring_pulse_effects(_delta: float) -> void:
	var now_sec := get_now_sec()

	for i in range(active_ring_pulse_effects.size() - 1, -1, -1):
		var effect: Dictionary = active_ring_pulse_effects[i]

		if effect_expired(effect, now_sec):
			remove_effect_at(active_ring_pulse_effects, i)
			continue

		var elapsed := now_sec - float(effect.get("started_sec", now_sec))
		var box_size: Vector2 = effect.get("box_size", Vector2.ZERO)
		var color: Color = effect.get("color", Color.WHITE)
		var ring_life_sec = max(float(effect.get("ring_life_sec", 0.75)), 0.05)
		var max_expand = max(float(effect.get("max_expand", 28.0)), 0.0)
		var thickness = max(float(effect.get("thickness", 4.0)), 1.0)
		var padding = max(float(effect.get("padding", 4.0)), 0.0)

		var rings: Array = effect.get("rings", [])
		for ring in rings:
			if typeof(ring) != TYPE_DICTIONARY:
				continue

			var delay_sec := float(ring.get("delay_sec", 0.0))
			var local_elapsed := elapsed - delay_sec

			if local_elapsed < 0.0:
				apply_ring_edges(
					ring.get("edges", {}),
					box_size,
					padding,
					thickness,
					0.0,
					color,
					0.0
				)
				continue

			var t = clamp(local_elapsed / ring_life_sec, 0.0, 1.0)
			var ease_out := 1.0 - pow(1.0 - t, 2.0)
			var fade = 1.0 - t
			var pulse := 0.65 + 0.35 * ((sin((local_elapsed * 16.0) + delay_sec) + 1.0) * 0.5)
			var alpha = color.a * fade * pulse
			var expand = max_expand * ease_out

			apply_ring_edges(
				ring.get("edges", {}),
				box_size,
				padding,
				thickness,
				expand,
				color,
				alpha
			)
			
func update_float_text_effects(_delta: float) -> void:
	var now_sec := get_now_sec()

	for i in range(active_float_text_effects.size() - 1, -1, -1):
		var effect: Dictionary = active_float_text_effects[i]

		if effect_expired(effect, now_sec):
			remove_effect_at(active_float_text_effects, i)
			continue

		var elapsed := now_sec - float(effect.get("started_sec", now_sec))
		var duration_sec = max(float(effect.get("duration_sec", 0.9)), 0.05)
		var t = clamp(elapsed / duration_sec, 0.0, 1.0)
		var ease_out := 1.0 - pow(1.0 - t, 2.0)
		var fade = 1.0 - t

		var label: Label = effect.get("label", null)
		if label == null or not is_instance_valid(label):
			continue

		var start: Vector2 = effect.get("start", Vector2.ZERO)
		var drift: Vector2 = effect.get("drift", Vector2(0, -34))
		var color: Color = effect.get("color", Color.WHITE)

		var center := start + (drift * ease_out)
		label.position = center - (label.size * 0.5)

		var c := color
		c.a = color.a * fade
		label.add_theme_color_override("font_color", c)

		var scale_value = lerp(1.18, 0.92, t)
		label.scale = Vector2(scale_value, scale_value)


func update_shield_ring_groups(_delta: float) -> void:
	var now_sec := get_now_sec()
	var dead_keys: Array = []

	for match_id in active_shield_ring_groups.keys():
		var group: Dictionary = active_shield_ring_groups[match_id]
		var root: Control = group.get("root", null)
		if root == null or not is_instance_valid(root):
			dead_keys.append(match_id)
			continue

		var point_size: Vector2 = group.get("point_size", Vector2.ZERO)
		var active_count := int(group.get("active_count", 0))
		var max_count = max(int(group.get("max_count", 4)), 1)
		var base_color: Color = group.get("base_color", Color(0.4, 0.8, 1.0, 0.45))
		var has_energy := bool(group.get("has_energy", true))
		var state := str(group.get("state", "active")).strip_edges().to_lower()
		var started_sec := float(group.get("started_sec", now_sec))
		var elapsed := now_sec - started_sec
		var pulse_speed = max(float(group.get("pulse_speed", 3.6)), 0.1)
		var smallest_radius = max(float(group.get("smallest_radius", 24.0)), 4.0)
		var largest_radius_scale = clamp(float(group.get("largest_radius_scale", 0.42)), 0.05, 1.0)

		var center := point_size * 0.5
		var min_dimension = max(min(point_size.x, point_size.y), 1.0)
		var largest_radius = max(min_dimension * largest_radius_scale, smallest_radius + 4.0)
		var rings: Array = group.get("rings", [])

		for ring_data in rings:
			if typeof(ring_data) != TYPE_DICTIONARY:
				continue

			var ring: Panel = ring_data.get("node", null)
			if ring == null or not is_instance_valid(ring):
				continue

			var index := int(ring_data.get("index", 0))
			var layer_number := index + 1
			var is_active := layer_number <= active_count
			var layer_t := 0.0
			if max_count > 1:
				layer_t = float(index) / float(max_count - 1)

			var radius = lerp(smallest_radius, largest_radius, layer_t)
			var pulse := 0.0
			if is_active and has_energy and state != "broken":
				pulse = (sin((elapsed * pulse_speed) + float(index) * 0.75) + 1.0) * 0.5

			var hit_expand := 0.0
			var hit_alpha_boost := 0.0
			if state == "hit":
				hit_expand = 5.0 + (sin(elapsed * 18.0) + 1.0) * 2.0
				hit_alpha_boost = 0.12

			var diameter = (radius + pulse * 4.0 + hit_expand) * 2.0
			var ring_color := Color(0.18, 0.18, 0.18, 0.18)

			if is_active:
				var light_boost := 0.18 * layer_t
				ring_color = Color(
					clamp(base_color.r + light_boost, 0.0, 1.0),
					clamp(base_color.g + light_boost, 0.0, 1.0),
					clamp(base_color.b + light_boost, 0.0, 1.0),
					0.18 + pulse * 0.16 + hit_alpha_boost
				)

				if not has_energy or state == "no_energy":
					ring_color.a = 0.08 + pulse * 0.04
				elif state == "broken":
					ring_color.a = 0.06

			apply_shield_ring_style(
				ring,
				center,
				diameter,
				ring_color,
				is_active,
				has_energy and state != "broken"
			)

	for key in dead_keys:
		active_shield_ring_groups.erase(key)
		
		
func make_ring_edges(parent: Control, color: Color) -> Dictionary:
	var top := ColorRect.new()
	var bottom := ColorRect.new()
	var left := ColorRect.new()
	var right := ColorRect.new()

	var edges := {
		"top": top,
		"bottom": bottom,
		"left": left,
		"right": right
	}

	for key in edges.keys():
		var rect: ColorRect = edges[key]
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.color = color
		parent.add_child(rect)

	return edges


func apply_ring_edges(
	edges: Dictionary,
	box_size: Vector2,
	padding: float,
	thickness: float,
	expand: float,
	color: Color,
	alpha: float
) -> void:
	var total_pad := padding + expand
	var x := -total_pad
	var y := -total_pad
	var w := box_size.x + (total_pad * 2.0)
	var h := box_size.y + (total_pad * 2.0)

	var c := color
	c.a = clamp(alpha, 0.0, 1.0)

	var top: ColorRect = edges.get("top", null)
	var bottom: ColorRect = edges.get("bottom", null)
	var left: ColorRect = edges.get("left", null)
	var right: ColorRect = edges.get("right", null)

	if top != null and is_instance_valid(top):
		top.position = Vector2(x, y)
		top.size = Vector2(w, thickness)
		top.color = c

	if bottom != null and is_instance_valid(bottom):
		bottom.position = Vector2(x, y + h - thickness)
		bottom.size = Vector2(w, thickness)
		bottom.color = c

	if left != null and is_instance_valid(left):
		left.position = Vector2(x, y)
		left.size = Vector2(thickness, h)
		left.color = c

	if right != null and is_instance_valid(right):
		right.position = Vector2(x + w - thickness, y)
		right.size = Vector2(thickness, h)
		right.color = c


func set_breathing_energy_frame(packet: Dictionary) -> Dictionary:
	# Summary: Create or update one persistent breathing frame with edge particles.
	if Globals.print_priority_3:
		print("DEBUG ENERGY FRAME | EffectLayer set_breathing_energy_frame called")
		print("DEBUG ENERGY FRAME | EffectLayer packet = ", packet)
	var match_id := str(packet.get("effect_match_id", "")).strip_edges()
	if match_id == "":
		match_id = str(packet.get("frame_id", "")).strip_edges()
	if match_id == "":
		match_id = str(packet.get("point_id", "breathing_energy_frame")).strip_edges() + "_breathing_energy_frame"

	var point_id := str(packet.get("point_id", "log_panel")).strip_edges()
	var point := get_point(point_id)
	
	if point.is_empty():
		return make_failed_effect("breathing_energy_frame", "missing point: " + point_id)
	if Globals.print_priority_3:
		print("DEBUG ENERGY FRAME | effect_match_id = ", match_id)
		print("DEBUG ENERGY FRAME | point_id = ", point_id)
	var point_pos: Vector2 = point.get("position", Vector2.ZERO)
	var point_size: Vector2 = point.get("size", Vector2.ZERO)
	var base_color := get_packet_color(packet, "base_color", Color(0.34, 0.88, 1.0, 0.86))
	var state := str(packet.get("state", "active")).strip_edges().to_lower()
	if state == "":
		state = "active"

	var particle_count = max(int(packet.get("particle_count", 1)), 0)
	var group: Dictionary = active_breathing_energy_frames.get(match_id, {})
	var root: Control = group.get("root", null)

	if root == null or not is_instance_valid(root):
		root = Control.new()
		root.name = "BreathingEnergyFrame_" + match_id
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.position = point_pos
		root.size = point_size
		root.clip_contents = false
		add_child(root)

		group = {
			"root": root,
			"edges": make_ring_edges(root, base_color),
			"glow_edges": make_ring_edges(root, base_color),
			"particles": [],
			"started_sec": get_now_sec()
		}

	remove_duplicate_breathing_energy_frame_roots(match_id, root)
	root.position = point_pos
	root.size = point_size
	root.visible = state != "hidden"

	var particles: Array = group.get("particles", [])
	if particles.size() != particle_count:
		for particle_data in particles:
			if typeof(particle_data) != TYPE_DICTIONARY:
				continue
			var old_particle = particle_data.get("node", null)
			if old_particle != null and is_instance_valid(old_particle):
				old_particle.queue_free()

		particles.clear()

		for i in range(particle_count):
			var particle := make_circle(root, Vector2.ZERO, float(packet.get("particle_size", 7.0)), base_color)
			particles.append({
				"node": particle,
				"index": i,
				"phase": float(i) / float(max(particle_count, 1))
			})

	group["root"] = root
	group["point_id"] = point_id
	group["point_pos"] = point_pos
	group["point_size"] = point_size
	group["base_color"] = base_color
	group["state"] = state
	group["duration_sec"] = float(packet.get("duration", packet.get("duration_sec", -1.0)))
	group["padding"] = float(packet.get("padding", 5.0))
	group["thickness"] = float(packet.get("thickness", 2.0))
	group["glow_thickness"] = float(packet.get("glow_thickness", 7.0))
	group["breath_speed"] = float(packet.get("breath_speed", 1.15))
	group["breath_amount"] = float(packet.get("breath_amount", 0.015))
	group["alpha_pulse_scale"] = clamp(float(packet.get("alpha_pulse_scale", 1.0)), 0.0, 1.0)
	group["particle_speed"] = float(packet.get("particle_speed", 0.28))
	group["particle_size"] = float(packet.get("particle_size", 7.0))
	group["particles"] = particles

	active_breathing_energy_frames[match_id] = group
	set_process(true)

	return {
		"ok": true,
		"match_id": match_id,
		"effect_kind": "breathing_energy_frame",
		"point_id": point_id
	}
	
	
func remove_duplicate_breathing_energy_frame_roots(match_id: String, keep_root: Control) -> void:
	var target_name := "BreathingEnergyFrame_" + match_id
	for child in get_children():
		if child == keep_root:
			continue
		if str(child.name) != target_name:
			continue
		child.queue_free()


func clear_breathing_energy_frame_by_id(match_id: String) -> Dictionary:
	var clean_match_id := match_id.strip_edges()
	if clean_match_id == "":
		return {
			"status": "failed",
			"reason": "missing match_id",
			"effect_kind": "breathing_energy_frame"
		}

	if not active_breathing_energy_frames.has(clean_match_id):
		return {
			"status": "missing",
			"match_id": clean_match_id,
			"effect_kind": "breathing_energy_frame"
		}

	var group: Dictionary = active_breathing_energy_frames[clean_match_id]
	var root = group.get("root", null)
	if root != null and is_instance_valid(root):
		root.queue_free()

	active_breathing_energy_frames.erase(clean_match_id)

	return {
		"status": "cleared",
		"match_id": clean_match_id,
		"effect_kind": "breathing_energy_frame"
	}
	
func update_breathing_energy_frames(_delta: float) -> void:
	var now_sec := get_now_sec()
	var dead_keys: Array = []

	for match_id in active_breathing_energy_frames.keys():
		var group: Dictionary = active_breathing_energy_frames[match_id]
		var root: Control = group.get("root", null)

		if root == null or not is_instance_valid(root):
			dead_keys.append(match_id)
			continue

		var started_sec := float(group.get("started_sec", now_sec))
		var elapsed := now_sec - started_sec
		var duration_sec := float(group.get("duration_sec", -1.0))

		if duration_sec > 0.0 and elapsed >= duration_sec:
			root.queue_free()
			dead_keys.append(match_id)
			continue

		var state := str(group.get("state", "active")).strip_edges().to_lower()
		root.visible = state != "hidden"

		if state == "hidden":
			continue

		var point_size: Vector2 = group.get("point_size", Vector2.ZERO)
		var base_color: Color = group.get("base_color", Color(0.34, 0.88, 1.0, 0.86))
		var padding = max(float(group.get("padding", 5.0)), 0.0)
		var thickness = max(float(group.get("thickness", 2.0)), 1.0)
		var glow_thickness = max(float(group.get("glow_thickness", 7.0)), thickness)
		var breath_speed = max(float(group.get("breath_speed", 1.15)), 0.01)
		var breath_amount = clamp(float(group.get("breath_amount", 0.015)), 0.0, 0.08)
		var alpha_pulse_scale = clamp(float(group.get("alpha_pulse_scale", 1.0)), 0.0, 1.0)
		var particle_speed = max(float(group.get("particle_speed", 0.28)), 0.0)
		var particle_size = max(float(group.get("particle_size", 7.0)), 1.0)

		var state_alpha_scale := 1.0
		var state_speed_scale := 1.0
		var state_breath_scale := 1.0
		var particles_enabled := true

		if state == "quiet":
			state_alpha_scale = 0.58
			state_speed_scale = 0.65
			state_breath_scale = 0.50
		elif state == "warning":
			state_alpha_scale = 1.10
			state_speed_scale = 1.65
			state_breath_scale = 1.45
		elif state == "critical":
			state_alpha_scale = 1.20
			state_speed_scale = 2.15
			state_breath_scale = 1.80
		elif state == "disabled":
			state_alpha_scale = 0.25
			state_speed_scale = 0.0
			state_breath_scale = 0.0
			particles_enabled = false

		var pulse := 0.5 + 0.5 * sin(elapsed * TAU * breath_speed)
		var min_dimension = max(min(point_size.x, point_size.y), 1.0)
		var breath_pixels = min_dimension * breath_amount * state_breath_scale
		var breath_expand = breath_pixels * pulse

		var edge_alpha = clamp(base_color.a * (0.52 + pulse * 0.34 * alpha_pulse_scale) * state_alpha_scale, 0.0, 1.0)
		var glow_alpha = clamp(base_color.a * (0.10 + pulse * 0.16 * alpha_pulse_scale) * state_alpha_scale, 0.0, 1.0)

		apply_ring_edges(
			group.get("glow_edges", {}),
			point_size,
			padding,
			glow_thickness,
			breath_expand + 2.0,
			base_color,
			glow_alpha
		)

		apply_ring_edges(
			group.get("edges", {}),
			point_size,
			padding,
			thickness,
			breath_expand,
			base_color,
			edge_alpha
		)

		var particles: Array = group.get("particles", [])
		for particle_data in particles:
			if typeof(particle_data) != TYPE_DICTIONARY:
				continue

			var particle: Panel = particle_data.get("node", null)
			if particle == null or not is_instance_valid(particle):
				continue

			particle.visible = particles_enabled

			if not particles_enabled:
				continue

			var phase := float(particle_data.get("phase", 0.0))
			var travel_t := fposmod((elapsed * particle_speed * state_speed_scale) + phase, 1.0)
			var particle_center := get_rect_perimeter_position(point_size, padding + breath_expand, travel_t)

			var particle_pulse = 0.65 + (0.35 * alpha_pulse_scale) * sin((elapsed * TAU * 2.0) + phase * TAU)
			var particle_alpha = clamp(base_color.a * particle_pulse * state_alpha_scale, 0.0, 1.0)
			var particle_color := base_color
			particle_color.a = particle_alpha

			move_circle(
				particle,
				particle_center,
				particle_size * (0.85 + pulse * 0.30 * alpha_pulse_scale),
				particle_color,
				1.0
			)

	for key in dead_keys:
		active_breathing_energy_frames.erase(key)
		
		
func get_rect_perimeter_position(box_size: Vector2, padding: float, t: float) -> Vector2:
	var safe_t = fposmod(t, 1.0)
	var x := -padding
	var y := -padding
	var w = max(box_size.x + padding * 2.0, 1.0)
	var h = max(box_size.y + padding * 2.0, 1.0)
	var perimeter = max((w * 2.0) + (h * 2.0), 1.0)
	var distance = safe_t * perimeter

	if distance <= w:
		return Vector2(x + distance, y)

	distance -= w
	if distance <= h:
		return Vector2(x + w, y + distance)

	distance -= h
	if distance <= w:
		return Vector2(x + w - distance, y + h)

	distance -= w
	return Vector2(x, y + h - distance)


func clear_breathing_energy_frames() -> void:
	for key in active_breathing_energy_frames.keys():
		var group: Dictionary = active_breathing_energy_frames[key]
		var root = group.get("root", null)

		if root != null and is_instance_valid(root):
			root.queue_free()

	active_breathing_energy_frames.clear()
