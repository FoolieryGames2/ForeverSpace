extends Control
class_name BattleV2EnergyZipFX

var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO

var delay_before_zip: float = 0.0
var zip_duration: float = 0.12
var elapsed: float = 0.0

var active: bool = false
var finished_moving: bool = false

var head_pos: Vector2 = Vector2.ZERO
var trail_dots: Array[Dictionary] = []

var trail_life: float = 0.22
var spawn_timer: float = 0.0
var spawn_interval: float = 0.008

var head_radius: float = 4.5
var glow_radius: float = 15.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 950
	set_process(false)


func play_zip(
	from_pos: Vector2,
	to_pos: Vector2,
	total_laser_time: float = 0.28,
	final_zip_time: float = 0.10
) -> void:
	start_pos = from_pos
	end_pos = to_pos

	zip_duration = max(final_zip_time, 0.03)
	delay_before_zip = max(total_laser_time - zip_duration, 0.0)

	elapsed = 0.0
	active = true
	finished_moving = false
	head_pos = start_pos
	trail_dots.clear()

	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not active:
		return

	elapsed += delta

	if elapsed >= delay_before_zip and not finished_moving:
		var move_elapsed := elapsed - delay_before_zip
		var t = clamp(move_elapsed / max(zip_duration, 0.001), 0.0, 1.0)

		# Fast arrival curve: slow tiny start, then SNAP into the target.
		var eased_t := 1.0 - pow(1.0 - t, 3.0)

		head_pos = start_pos.lerp(end_pos, eased_t)

		_spawn_trail(delta)

		if t >= 1.0:
			head_pos = end_pos
			finished_moving = true
			_spawn_landing_puff()

	_update_trail(delta)

	if finished_moving and trail_dots.is_empty():
		queue_free()
		return

	queue_redraw()


func _draw() -> void:
	# Trail particles.
	for dot in trail_dots:
		var pos: Vector2 = dot.get("pos", Vector2.ZERO)
		var age: float = dot.get("age", 0.0)
		var life: float = dot.get("life", trail_life)
		var size: float = dot.get("size", 2.0)

		var t = clamp(age / max(life, 0.001), 0.0, 1.0)
		var alpha = 1.0 - t

		draw_circle(pos, size * 4.0, Color(0.55, 0.85, 1.0, alpha * 0.12))
		draw_circle(pos, size * 1.7, Color(0.85, 0.95, 1.0, alpha * 0.40))
		draw_circle(pos, size, Color(1.0, 1.0, 1.0, alpha * 0.80))

	# Do not draw the head before the zip starts.
	if elapsed < delay_before_zip or finished_moving:
		return

	# Energy head glow.
	draw_circle(head_pos, glow_radius, Color(0.45, 0.80, 1.0, 0.20))
	draw_circle(head_pos, glow_radius * 0.55, Color(0.80, 0.95, 1.0, 0.35))
	draw_circle(head_pos, head_radius, Color(1.0, 1.0, 1.0, 0.96))


func _spawn_trail(delta: float) -> void:
	spawn_timer += delta

	while spawn_timer >= spawn_interval:
		spawn_timer -= spawn_interval

		var jitter := Vector2(
			randf_range(-1.8, 1.8),
			randf_range(-1.8, 1.8)
		)

		trail_dots.append({
			"pos": head_pos + jitter,
			"age": 0.0,
			"life": trail_life,
			"size": randf_range(1.5, 3.2)
		})


func _spawn_landing_puff() -> void:
	for i in range(18):
		var angle := randf() * TAU
		var dist := randf_range(2.0, 14.0)

		trail_dots.append({
			"pos": end_pos + Vector2(cos(angle), sin(angle)) * dist,
			"age": 0.0,
			"life": randf_range(0.12, 0.28),
			"size": randf_range(1.4, 3.8)
		})


func _update_trail(delta: float) -> void:
	for i in range(trail_dots.size() - 1, -1, -1):
		var dot := trail_dots[i]
		dot["age"] = float(dot.get("age", 0.0)) + delta
		trail_dots[i] = dot

		if float(dot.get("age", 0.0)) >= float(dot.get("life", trail_life)):
			trail_dots.remove_at(i)
